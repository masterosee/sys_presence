"""
Routes API - Congés et absences
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from typing import Optional
from datetime import date, datetime, timezone
from pydantic import BaseModel

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User, LeaveRequest, LeaveType, Employee, Attendance

router = APIRouter()


# ─── Schémas ──────────────────────────────────────────────────
class LeaveRequestCreate(BaseModel):
    leave_type_id: str
    start_date: date
    end_date: date
    reason: Optional[str] = None


class LeaveReview(BaseModel):
    status: str        # approved | rejected
    comment: Optional[str] = None


# ─── TYPES DE CONGÉ ───────────────────────────────────────────
@router.get("/types")
async def get_leave_types(db: AsyncSession = Depends(get_db)):
    """Liste les types de congé disponibles"""
    result = await db.execute(select(LeaveType))
    types = result.scalars().all()
    return [
        {
            "id": str(t.id), "name": t.name, "code": t.code,
            "max_days": t.max_days, "is_paid": t.is_paid, "color": t.color,
        }
        for t in types
    ]


# ─── MES DEMANDES ─────────────────────────────────────────────
@router.get("/my")
async def get_my_leaves(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mes demandes de congé"""
    result = await db.execute(
        select(LeaveRequest)
        .where(LeaveRequest.employee_id == current_user.employee_id)
        .order_by(LeaveRequest.created_at.desc())
    )
    leaves = result.scalars().all()
    return [await _format_leave(db, lv) for lv in leaves]


# ─── DEMANDES EN ATTENTE (RH/Manager) ─────────────────────────
@router.get("/pending")
async def get_pending_leaves(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Demandes en attente d'approbation"""
    if current_user.role not in ["admin", "rh", "manager"]:
        raise HTTPException(403, "Accès non autorisé")

    result = await db.execute(
        select(LeaveRequest)
        .where(LeaveRequest.status == "pending")
        .order_by(LeaveRequest.created_at)
    )
    leaves = result.scalars().all()
    return [await _format_leave(db, lv, with_employee=True) for lv in leaves]


# ─── CRÉER UNE DEMANDE ────────────────────────────────────────
@router.post("/request")
async def request_leave(
    data: LeaveRequestCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Soumettre une demande de congé"""
    if data.end_date < data.start_date:
        raise HTTPException(400, "La date de fin doit être après la date de début")

    # Calculer les jours ouvrables
    total_days = _count_working_days(data.start_date, data.end_date)
    if total_days == 0:
        raise HTTPException(400, "Aucun jour ouvrable dans cette période")

    # Vérifier chevauchement avec une demande existante
    overlap = await db.execute(
        select(LeaveRequest).where(
            and_(
                LeaveRequest.employee_id == current_user.employee_id,
                LeaveRequest.status.in_(["pending", "approved"]),
                LeaveRequest.start_date <= data.end_date,
                LeaveRequest.end_date >= data.start_date,
            )
        )
    )
    if overlap.scalar_one_or_none():
        raise HTTPException(400, "Une demande existe déjà pour cette période")

    leave = LeaveRequest(
        employee_id=current_user.employee_id,
        leave_type_id=data.leave_type_id,
        start_date=data.start_date,
        end_date=data.end_date,
        total_days=total_days,
        reason=data.reason,
        status="pending",
    )
    db.add(leave)
    await db.commit()
    await db.refresh(leave)

    return {
        "message": f"Demande soumise pour {total_days} jour(s). En attente d'approbation.",
        "leave_id": str(leave.id),
        "total_days": total_days,
    }


# ─── APPROUVER / REJETER (RH/Manager) ─────────────────────────
@router.patch("/{leave_id}/review")
async def review_leave(
    leave_id: str,
    data: LeaveReview,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Approuver ou rejeter une demande de congé"""
    if current_user.role not in ["admin", "rh", "manager"]:
        raise HTTPException(403, "Accès non autorisé")

    if data.status not in ["approved", "rejected"]:
        raise HTTPException(400, "Statut invalide. Utilisez 'approved' ou 'rejected'")

    result = await db.execute(
        select(LeaveRequest).where(LeaveRequest.id == leave_id)
    )
    leave = result.scalar_one_or_none()
    if not leave:
        raise HTTPException(404, "Demande introuvable")
    if leave.status != "pending":
        raise HTTPException(400, "Cette demande a déjà été traitée")

    leave.status = data.status
    leave.reviewed_by = current_user.employee_id
    leave.reviewed_at = datetime.now(timezone.utc)
    leave.review_comment = data.comment

    # Si approuvé → marquer les jours comme congé dans attendances
    if data.status == "approved":
        current = leave.start_date
        while current <= leave.end_date:
            if current.weekday() < 5:  # Lundi à Vendredi
                existing = await db.execute(
                    select(Attendance).where(
                        and_(
                            Attendance.employee_id == leave.employee_id,
                            Attendance.date == current,
                        )
                    )
                )
                att = existing.scalar_one_or_none()
                if not att:
                    att = Attendance(
                        employee_id=leave.employee_id,
                        date=current,
                        status="on_leave",
                    )
                    db.add(att)
            from datetime import timedelta
            current += timedelta(days=1)

    await db.commit()

    action = "approuvée ✅" if data.status == "approved" else "rejetée ❌"
    return {"message": f"Demande {action}", "leave_id": leave_id, "status": data.status}


# ─── ANNULER UNE DEMANDE (employé) ────────────────────────────
@router.delete("/{leave_id}")
async def cancel_leave(
    leave_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Annuler sa propre demande (si encore en attente)"""
    result = await db.execute(select(LeaveRequest).where(LeaveRequest.id == leave_id))
    leave = result.scalar_one_or_none()

    if not leave:
        raise HTTPException(404, "Demande introuvable")
    if str(leave.employee_id) != str(current_user.employee_id):
        raise HTTPException(403, "Vous ne pouvez annuler que vos propres demandes")
    if leave.status != "pending":
        raise HTTPException(400, "Impossible d'annuler une demande déjà traitée")

    leave.status = "cancelled"
    await db.commit()
    return {"message": "Demande annulée"}


# ─── Utilitaires ──────────────────────────────────────────────
def _count_working_days(start: date, end: date) -> int:
    """Compte les jours ouvrables (Lundi-Vendredi) entre deux dates"""
    from datetime import timedelta
    count = 0
    current = start
    while current <= end:
        if current.weekday() < 5:
            count += 1
        current += timedelta(days=1)
    return count


async def _format_leave(
    db: AsyncSession, leave: LeaveRequest, with_employee: bool = False
) -> dict:
    # Charger le type
    type_result = await db.execute(
        select(LeaveType).where(LeaveType.id == leave.leave_type_id)
    )
    lt = type_result.scalar_one_or_none()

    data = {
        "id": str(leave.id),
        "leave_type_name": lt.name if lt else "--",
        "leave_type_color": lt.color if lt else "#6366F1",
        "leave_type_code": lt.code if lt else "--",
        "start_date": str(leave.start_date),
        "end_date": str(leave.end_date),
        "total_days": leave.total_days,
        "reason": leave.reason,
        "status": leave.status,
        "review_comment": leave.review_comment,
        "created_at": leave.created_at.isoformat(),
    }

    if with_employee:
        emp_result = await db.execute(
            select(Employee).where(Employee.id == leave.employee_id)
        )
        emp = emp_result.scalar_one_or_none()
        data["employee_name"] = emp.full_name if emp else "--"
        data["employee_code"] = emp.employee_code if emp else "--"

    return data
