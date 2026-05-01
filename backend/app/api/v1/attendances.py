"""
Routes API - Pointages (Attendances)
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from typing import Optional
from datetime import date
import uuid, os, shutil

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User
from app.models import Attendance
from app.services.attendance_service import AttendanceService
from app.core.config import settings
from pydantic import BaseModel


router = APIRouter()


# --- Schémas Pydantic ---
class CheckinQRRequest(BaseModel):
    qr_token: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class CheckinGPSRequest(BaseModel):
    latitude: float
    longitude: float


class CheckinPINRequest(BaseModel):
    employee_code: str
    pin: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    geofence_id: Optional[str] = None


class CheckoutRequest(BaseModel):
    method: str = "qr_code"  # qr_code, gps, pin
    qr_token: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class AttendanceResponse(BaseModel):
    id: str
    employee_id: str
    date: date
    check_in: Optional[str]
    check_out: Optional[str]
    check_in_method: Optional[str]
    check_out_method: Optional[str]
    status: str
    is_late: bool
    late_minutes: int
    work_duration: Optional[int]
    message: str

    class Config:
        from_attributes = True


# -------------------------------------------------------
# ENTRÉE - QR Code
# -------------------------------------------------------
@router.post("/checkin/qr", response_model=AttendanceResponse)
async def checkin_qr(
    request: CheckinQRRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Pointer son entrée en scannant le QR Code affiché au bureau"""
    try:
        attendance = await AttendanceService.checkin_qr(
            db=db,
            employee_id=str(current_user.employee_id),
            qr_token=request.qr_token,
            latitude=request.latitude,
            longitude=request.longitude,
        )
        return _format_response(attendance, "✅ Entrée enregistrée avec succès !")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# -------------------------------------------------------
# ENTRÉE - GPS (employé distant)
# -------------------------------------------------------
@router.post("/checkin/gps", response_model=AttendanceResponse)
async def checkin_gps(
    request: CheckinGPSRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Pointer son entrée via GPS (pour employés à distance)"""
    try:
        attendance = await AttendanceService.checkin_gps(
            db=db,
            employee_id=str(current_user.employee_id),
            latitude=request.latitude,
            longitude=request.longitude,
        )
        return _format_response(attendance, "✅ Présence à distance enregistrée !")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# -------------------------------------------------------
# ENTRÉE - PIN (kiosque)
# -------------------------------------------------------
@router.post("/checkin/pin", response_model=AttendanceResponse)
async def checkin_pin(
    request: CheckinPINRequest,
    db: AsyncSession = Depends(get_db),
):
    """Pointer son entrée avec code PIN (pas besoin d'être connecté)"""
    try:
        attendance = await AttendanceService.checkin_pin(
            db=db,
            employee_code=request.employee_code,
            pin=request.pin,
            geofence_id=request.geofence_id,
            latitude=request.latitude,
            longitude=request.longitude,
        )
        return _format_response(attendance, "✅ Entrée enregistrée !")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# -------------------------------------------------------
# SORTIE
# -------------------------------------------------------
@router.post("/checkout", response_model=AttendanceResponse)
async def checkout(
    request: CheckoutRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Pointer sa sortie"""
    try:
        attendance = await AttendanceService.checkout(
            db=db,
            employee_id=str(current_user.employee_id),
            method=request.method,
            qr_token=request.qr_token,
            latitude=request.latitude,
            longitude=request.longitude,
        )
        hours = (attendance.work_duration or 0) // 60
        minutes = (attendance.work_duration or 0) % 60
        return _format_response(
            attendance,
            f"✅ Sortie enregistrée ! Vous avez travaillé {hours}h{minutes:02d}."
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# -------------------------------------------------------
# MON POINTAGE DU JOUR
# -------------------------------------------------------
@router.get("/today")
async def get_today_attendance(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Récupérer son pointage du jour"""
    today = date.today()
    result = await db.execute(
        select(Attendance).where(
            and_(
                Attendance.employee_id == current_user.employee_id,
                Attendance.date == today,
            )
        )
    )
    attendance = result.scalar_one_or_none()
    if not attendance:
        return {"status": "not_checked_in", "date": str(today)}
    return _format_response(attendance, "")


# -------------------------------------------------------
# HISTORIQUE (pour l'employé connecté)
# -------------------------------------------------------
@router.get("/history")
async def get_my_history(
    month: Optional[int] = None,
    year: Optional[int] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Récupérer l'historique de présence du mois"""
    from sqlalchemy import extract
    today = date.today()
    target_month = month or today.month
    target_year = year or today.year

    result = await db.execute(
        select(Attendance).where(
            and_(
                Attendance.employee_id == current_user.employee_id,
                extract("month", Attendance.date) == target_month,
                extract("year", Attendance.date) == target_year,
            )
        ).order_by(Attendance.date.desc())
    )
    attendances = result.scalars().all()
    return [_format_response(a, "") for a in attendances]


# -------------------------------------------------------
# UPLOAD PHOTO SELFIE
# -------------------------------------------------------
@router.post("/upload-photo")
async def upload_photo(
    photo: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    """Upload photo selfie pour pointage distant"""
    if photo.content_type not in ["image/jpeg", "image/png"]:
        raise HTTPException(400, "Format accepté : JPG ou PNG uniquement")

    content = await photo.read()
    if len(content) > settings.MAX_PHOTO_SIZE_MB * 1024 * 1024:
        raise HTTPException(400, f"Photo trop grande (max {settings.MAX_PHOTO_SIZE_MB}MB)")

    filename = f"{current_user.employee_id}_{uuid.uuid4().hex[:8]}.jpg"
    filepath = os.path.join(settings.UPLOAD_DIR, filename)
    with open(filepath, "wb") as f:
        f.write(content)

    return {"photo_url": f"/uploads/{filename}"}


# -------------------------------------------------------
# UTILITAIRE
# -------------------------------------------------------
def _format_response(attendance: Attendance, message: str) -> dict:
    return {
        "id": str(attendance.id),
        "employee_id": str(attendance.employee_id),
        "date": str(attendance.date),
        "check_in": attendance.check_in.isoformat() if attendance.check_in else None,
        "check_out": attendance.check_out.isoformat() if attendance.check_out else None,
        "check_in_method": attendance.check_in_method,
        "check_out_method": attendance.check_out_method,
        "status": attendance.status,
        "is_late": attendance.is_late,
        "late_minutes": attendance.late_minutes or 0,
        "work_duration": attendance.work_duration,
        "message": message,
    }
    
    
