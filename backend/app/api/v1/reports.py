"""
Routes API - Rapports
Statistiques mensuelles, export des données
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func, extract
from typing import Optional
from datetime import date
import io, csv

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User, Attendance, Employee, Department

router = APIRouter()


# ─── RAPPORT MENSUEL ──────────────────────────────────────────
@router.get("/monthly")
async def monthly_report(
    month: int = Query(default=None),
    year: int = Query(default=None),
    department_id: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Rapport de présence mensuel avec statistiques par employé"""
    if current_user.role not in ["admin", "rh", "manager"]:
        raise HTTPException(403, "Accès non autorisé")

    today = date.today()
    target_month = month or today.month
    target_year  = year  or today.year

    # Récupérer tous les pointages du mois
    query = (
        select(Attendance, Employee)
        .join(Employee, Attendance.employee_id == Employee.id)
        .where(
            and_(
                extract("month", Attendance.date) == target_month,
                extract("year",  Attendance.date) == target_year,
                Employee.is_active == True,
            )
        )
    )
    if department_id:
        query = query.where(Employee.department_id == department_id)

    result = await db.execute(query.order_by(Employee.last_name, Attendance.date))
    rows = result.all()

    # Grouper par employé
    by_employee: dict = {}
    for att, emp in rows:
        eid = str(emp.id)
        if eid not in by_employee:
            by_employee[eid] = {
                "employee_id": eid,
                "employee_code": emp.employee_code,
                "full_name": emp.full_name,
                "department": emp.department.name if emp.department else "--",
                "days_present": 0,
                "days_late": 0,
                "days_absent": 0,
                "days_remote": 0,
                "days_on_leave": 0,
                "total_minutes": 0,
                "total_late_minutes": 0,
                "records": [],
            }
        e = by_employee[eid]
        if att.status == "present" or (att.check_in and att.status != "on_leave"):
            e["days_present"] += 1
        if att.is_late:
            e["days_late"] += 1
            e["total_late_minutes"] += att.late_minutes or 0
        if att.status == "absent":
            e["days_absent"] += 1
        if att.status == "remote":
            e["days_remote"] += 1
        if att.status == "on_leave":
            e["days_on_leave"] += 1
        e["total_minutes"] += att.work_duration or 0
        e["records"].append({
            "date": str(att.date),
            "check_in": att.check_in.isoformat() if att.check_in else None,
            "check_out": att.check_out.isoformat() if att.check_out else None,
            "status": att.status,
            "is_late": att.is_late,
            "late_minutes": att.late_minutes,
            "work_duration": att.work_duration,
        })

    # Totaux globaux
    summary = {
        "month": target_month,
        "year": target_year,
        "total_employees": len(by_employee),
        "total_days_present": sum(e["days_present"] for e in by_employee.values()),
        "total_days_late":    sum(e["days_late"]    for e in by_employee.values()),
        "total_days_absent":  sum(e["days_absent"]  for e in by_employee.values()),
        "avg_work_hours": round(
            sum(e["total_minutes"] for e in by_employee.values()) /
            max(len(by_employee), 1) / 60, 1
        ),
    }

    return {
        "summary": summary,
        "employees": list(by_employee.values()),
    }


# ─── EXPORT CSV ───────────────────────────────────────────────
@router.get("/export/csv")
async def export_csv(
    month: int = Query(default=None),
    year: int = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Exporter les présences du mois en CSV"""
    if current_user.role not in ["admin", "rh"]:
        raise HTTPException(403, "Accès réservé aux RH et administrateurs")

    today = date.today()
    target_month = month or today.month
    target_year  = year  or today.year

    result = await db.execute(
        select(Attendance, Employee)
        .join(Employee, Attendance.employee_id == Employee.id)
        .where(
            and_(
                extract("month", Attendance.date) == target_month,
                extract("year",  Attendance.date) == target_year,
            )
        )
        .order_by(Employee.last_name, Attendance.date)
    )
    rows = result.all()

    # Générer CSV en mémoire
    output = io.StringIO()
    writer = csv.writer(output, delimiter=';')

    # En-tête
    writer.writerow([
        "Code", "Nom Complet", "Département",
        "Date", "Entrée", "Sortie", "Durée (min)",
        "Statut", "Retard", "Minutes retard", "Méthode"
    ])

    for att, emp in rows:
        dept = emp.department.name if emp.department else "--"
        check_in  = att.check_in.strftime("%H:%M")  if att.check_in  else "--"
        check_out = att.check_out.strftime("%H:%M") if att.check_out else "--"
        writer.writerow([
            emp.employee_code, emp.full_name, dept,
            str(att.date), check_in, check_out,
            att.work_duration or 0, att.status,
            "Oui" if att.is_late else "Non",
            att.late_minutes or 0, att.check_in_method or "--",
        ])

    output.seek(0)
    filename = f"presences_{target_year}_{target_month:02d}.csv"

    return StreamingResponse(
        iter([output.getvalue().encode("utf-8-sig")]),  # utf-8-sig pour Excel
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


# ─── RAPPORT PAR EMPLOYÉ ──────────────────────────────────────
@router.get("/employee/{employee_id}")
async def employee_report(
    employee_id: str,
    month: Optional[int] = None,
    year: Optional[int] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Rapport détaillé pour un employé spécifique"""
    # Un employé peut voir son propre rapport
    if current_user.role == "employee" and str(current_user.employee_id) != employee_id:
        raise HTTPException(403, "Accès non autorisé")

    today = date.today()
    target_month = month or today.month
    target_year  = year  or today.year

    result = await db.execute(
        select(Attendance).where(
            and_(
                Attendance.employee_id == employee_id,
                extract("month", Attendance.date) == target_month,
                extract("year",  Attendance.date) == target_year,
            )
        ).order_by(Attendance.date)
    )
    attendances = result.scalars().all()

    days_present  = len([a for a in attendances if a.check_in])
    days_late     = len([a for a in attendances if a.is_late])
    days_on_leave = len([a for a in attendances if a.status == "on_leave"])
    total_minutes = sum(a.work_duration or 0 for a in attendances)

    return {
        "employee_id": employee_id,
        "month": target_month,
        "year": target_year,
        "summary": {
            "days_present": days_present,
            "days_late": days_late,
            "days_on_leave": days_on_leave,
            "total_hours_worked": round(total_minutes / 60, 1),
            "total_late_minutes": sum(a.late_minutes or 0 for a in attendances),
        },
        "records": [
            {
                "date": str(a.date),
                "check_in": a.check_in.isoformat() if a.check_in else None,
                "check_out": a.check_out.isoformat() if a.check_out else None,
                "status": a.status,
                "is_late": a.is_late,
                "late_minutes": a.late_minutes or 0,
                "work_duration": a.work_duration,
                "check_in_method": a.check_in_method,
            }
            for a in attendances
        ],
    }
    
    
