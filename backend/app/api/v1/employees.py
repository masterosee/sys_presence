"""
Routes API - Employés
CRUD complet + stats dashboard
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, cast, Date
from typing import Optional, List
from datetime import date, datetime, timezone
from pydantic import BaseModel, EmailStr

from app.core.database import get_db
from app.core.security import get_current_user, hash_pin
from app.models import (
    Employee, User, Department, Position,
    Attendance, EmployeeSchedule, WorkSchedule
)

router = APIRouter()


# ─── Schémas ──────────────────────────────────────────────────
class EmployeeCreate(BaseModel):
    employee_code: str
    first_name: str
    last_name: str
    email: EmailStr
    phone: Optional[str] = None
    department_id: Optional[str] = None
    position_id: Optional[str] = None
    hire_date: date
    contract_type: str = "CDI"
    is_remote: bool = False
    pin_code: Optional[str] = None
    schedule_id: Optional[str] = None


class EmployeeUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    department_id: Optional[str] = None
    position_id: Optional[str] = None
    contract_type: Optional[str] = None
    is_remote: Optional[bool] = None
    pin_code: Optional[str] = None
    is_active: Optional[bool] = None


# ─── LISTE EMPLOYÉS ────────────────────────────────────────────
@router.get("/")
async def list_employees(
    search: Optional[str] = Query(None, description="Chercher par nom ou code"),
    department_id: Optional[str] = None,
    is_active: bool = True,
    page: int = 1,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Liste tous les employés avec pagination et filtres"""
    if current_user.role not in ["admin", "rh", "manager"]:
        raise HTTPException(403, "Accès non autorisé")

    query = select(Employee).where(Employee.is_active == is_active)

    if search:
        query = query.where(
            (Employee.first_name.ilike(f"%{search}%")) |
            (Employee.last_name.ilike(f"%{search}%")) |
            (Employee.employee_code.ilike(f"%{search}%")) |
            (Employee.email.ilike(f"%{search}%"))
        )
    if department_id:
        query = query.where(Employee.department_id == department_id)

    # Total
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()

    # Pagination
    query = query.offset((page - 1) * limit).limit(limit).order_by(Employee.last_name)
    result = await db.execute(query)
    employees = result.scalars().all()

    return {
        "total": total,
        "page": page,
        "limit": limit,
        "pages": (total + limit - 1) // limit,
        "employees": [await _format_employee(db, emp) for emp in employees],
    }


# ─── CRÉER EMPLOYÉ ─────────────────────────────────────────────
@router.post("/", status_code=201)
async def create_employee(
    data: EmployeeCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Créer un nouvel employé"""
    if current_user.role not in ["admin", "rh"]:
        raise HTTPException(403, "Accès réservé aux RH et administrateurs")

    # Vérifier code unique
    existing = await db.execute(
        select(Employee).where(Employee.employee_code == data.employee_code)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(400, f"Le code '{data.employee_code}' est déjà utilisé")

    # Vérifier email unique
    existing_email = await db.execute(
        select(Employee).where(Employee.email == data.email)
    )
    if existing_email.scalar_one_or_none():
        raise HTTPException(400, f"L'email '{data.email}' est déjà utilisé")

    employee = Employee(
        employee_code=data.employee_code,
        first_name=data.first_name,
        last_name=data.last_name,
        email=data.email,
        phone=data.phone,
        department_id=data.department_id,
        position_id=data.position_id,
        hire_date=data.hire_date,
        contract_type=data.contract_type,
        is_remote=data.is_remote,
        pin_code=hash_pin(data.pin_code) if data.pin_code else None,
    )
    db.add(employee)
    await db.flush()  # Obtenir l'ID avant de créer le schedule

    # Assigner l'horaire si fourni
    if data.schedule_id:
        emp_schedule = EmployeeSchedule(
            employee_id=str(employee.id),
            schedule_id=data.schedule_id,
            start_date=date.today(),
        )
        db.add(emp_schedule)

    await db.commit()
    await db.refresh(employee)
    return {
        "message": f"Employé {employee.full_name} créé avec succès",
        "employee_id": str(employee.id),
        "employee_code": employee.employee_code,
    }


# ─── DÉTAIL EMPLOYÉ ────────────────────────────────────────────
@router.get("/{employee_id}")
async def get_employee(
    employee_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Détails d'un employé"""
    # Un employé peut voir son propre profil
    if current_user.role == "employee" and str(current_user.employee_id) != employee_id:
        raise HTTPException(403, "Accès non autorisé")

    result = await db.execute(
        select(Employee).where(Employee.id == employee_id)
    )
    employee = result.scalar_one_or_none()
    if not employee:
        raise HTTPException(404, "Employé introuvable")

    return await _format_employee(db, employee, detailed=True)


# ─── MODIFIER EMPLOYÉ ──────────────────────────────────────────
@router.patch("/{employee_id}")
async def update_employee(
    employee_id: str,
    data: EmployeeUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Modifier un employé"""
    if current_user.role not in ["admin", "rh"]:
        raise HTTPException(403, "Accès réservé aux RH et administrateurs")

    result = await db.execute(select(Employee).where(Employee.id == employee_id))
    employee = result.scalar_one_or_none()
    if not employee:
        raise HTTPException(404, "Employé introuvable")

    update_data = data.model_dump(exclude_none=True)
    if "pin_code" in update_data:
        update_data["pin_code"] = hash_pin(update_data["pin_code"])

    for field, value in update_data.items():
        setattr(employee, field, value)

    employee.updated_at = datetime.now(timezone.utc)
    await db.commit()
    return {"message": f"Employé {employee.full_name} mis à jour"}


# ─── STATS DASHBOARD ───────────────────────────────────────────
@router.get("/stats/dashboard")
async def get_dashboard_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Statistiques pour le dashboard RH"""
    if current_user.role not in ["admin", "rh", "manager"]:
        raise HTTPException(403, "Accès non autorisé")

    today = date.today()

    # Total employés actifs
    total_result = await db.execute(
        select(func.count(Employee.id)).where(Employee.is_active == True)
    )
    total = total_result.scalar()

    # Pointages du jour
    att_result = await db.execute(
        select(Attendance).where(Attendance.date == today)
    )
    attendances = att_result.scalars().all()

    present = len([a for a in attendances if a.check_in is not None])
    late = len([a for a in attendances if a.is_late])
    remote = len([a for a in attendances if a.status == "remote"])
    absent = total - present

    # Moyenne heures travaillées ce mois
    from datetime import datetime as dt
    month_start = date(today.year, today.month, 1)
    avg_result = await db.execute(
        select(func.avg(Attendance.work_duration)).where(
            and_(
                Attendance.date >= month_start,
                Attendance.work_duration.isnot(None)
            )
        )
    )
    avg_minutes = avg_result.scalar() or 0

    return {
        "total_employees": total,
        "present_today": present,
        "late_today": late,
        "absent_today": max(0, absent),
        "remote_today": remote,
        "avg_work_hours_month": round((avg_minutes or 0) / 60, 1),
        "date": str(today),
    }


# ─── LISTE PRÉSENCES DU JOUR (pour dashboard) ─────────────────
@router.get("/stats/today-all")
async def get_today_all(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Liste tous les employés avec leur statut du jour"""
    if current_user.role not in ["admin", "rh", "manager"]:
        raise HTTPException(403, "Accès non autorisé")

    today = date.today()

    # Tous les employés actifs
    emp_result = await db.execute(
        select(Employee).where(Employee.is_active == True).order_by(Employee.last_name)
    )
    employees = emp_result.scalars().all()

    # Pointages du jour
    att_result = await db.execute(
        select(Attendance).where(Attendance.date == today)
    )
    attendances = {str(a.employee_id): a for a in att_result.scalars().all()}

    rows = []
    for emp in employees:
        att = attendances.get(str(emp.id))
        dept_name = emp.department.name if emp.department else "--"

        rows.append({
            "employee_id": str(emp.id),
            "employee_code": emp.employee_code,
            "employee_name": emp.full_name,
            "department": dept_name,
            "photo_url": emp.photo_url,
            "check_in": att.check_in.isoformat() if att and att.check_in else None,
            "check_out": att.check_out.isoformat() if att and att.check_out else None,
            "check_in_method": att.check_in_method if att else None,
            "status": att.status if att and att.check_in else "absent",
            "is_late": att.is_late if att else False,
            "late_minutes": att.late_minutes if att else 0,
            "work_duration": att.work_duration if att else None,
        })

    return rows


# ─── Utilitaire formatage ──────────────────────────────────────
async def _format_employee(db: AsyncSession, emp: Employee, detailed: bool = False) -> dict:
    dept = None
    if emp.department_id:
        r = await db.execute(select(Department).where(Department.id == emp.department_id))
        d = r.scalar_one_or_none()
        dept = {"id": str(d.id), "name": d.name} if d else None

    pos = None
    if emp.position_id:
        r = await db.execute(select(Position).where(Position.id == emp.position_id))
        p = r.scalar_one_or_none()
        pos = {"id": str(p.id), "title": p.title} if p else None

    data = {
        "id": str(emp.id),
        "employee_code": emp.employee_code,
        "first_name": emp.first_name,
        "last_name": emp.last_name,
        "full_name": emp.full_name,
        "email": emp.email,
        "phone": emp.phone,
        "department": dept,
        "position": pos,
        "hire_date": str(emp.hire_date),
        "contract_type": emp.contract_type,
        "is_remote": emp.is_remote,
        "is_active": emp.is_active,
        "photo_url": emp.photo_url,
    }

    if detailed:
        # Ajouter stats de présence
        from sqlalchemy import extract
        today = date.today()
        month_result = await db.execute(
            select(func.count(Attendance.id)).where(
                and_(
                    Attendance.employee_id == emp.id,
                    extract("month", Attendance.date) == today.month,
                    extract("year", Attendance.date) == today.year,
                )
            )
        )
        late_result = await db.execute(
            select(func.count(Attendance.id)).where(
                and_(
                    Attendance.employee_id == emp.id,
                    Attendance.is_late == True,
                    extract("month", Attendance.date) == today.month,
                    extract("year", Attendance.date) == today.year,
                )
            )
        )
        data["stats_this_month"] = {
            "days_present": month_result.scalar(),
            "days_late": late_result.scalar(),
        }

    return data



