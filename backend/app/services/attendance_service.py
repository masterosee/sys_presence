"""
Service Pointage (Attendance)
Gère la logique métier pour les entrées/sorties
"""
from datetime import datetime, date, timezone
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from geopy.distance import geodesic

from app.models import Attendance
from app.models import Employee
from app.models import Geofence
from app.models import EmployeeSchedule
from app.models import WorkSchedule
from app.services.qr_service import QRCodeService


class AttendanceService:

    # -------------------------------------------------------
    # POINTAGE ENTRÉE via QR Code
    # -------------------------------------------------------
    @staticmethod
    async def checkin_qr(
        db: AsyncSession,
        employee_id: str,
        qr_token: str,
        photo_url: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
    ) -> Attendance:
        """Pointer l'entrée avec QR Code dynamique"""

        # 1. Valider le QR token
        qr_session = await QRCodeService.validate_token(db, qr_token)

        # 2. Vérifier qu'il n'y a pas déjà un pointage aujourd'hui
        today = date.today()
        existing = await AttendanceService._get_today_attendance(db, employee_id, today)
        if existing and existing.check_in:
            raise ValueError("Vous avez déjà pointé votre entrée aujourd'hui")

        # 3. Calculer le retard
        is_late, late_minutes = await AttendanceService._calculate_lateness(
            db, employee_id
        )

        # 4. Créer ou mettre à jour le pointage
        now = datetime.now(timezone.utc)
        if existing:
            existing.check_in = now
            existing.check_in_method = "qr_code"
            existing.check_in_lat = latitude
            existing.check_in_lng = longitude
            existing.check_in_photo = photo_url
            existing.geofence_id = qr_session.geofence_id
            existing.is_late = is_late
            existing.late_minutes = late_minutes
            existing.status = "late" if is_late else "present"
            await db.commit()
            return existing
        else:
            attendance = Attendance(
                employee_id=employee_id,
                date=today,
                check_in=now,
                check_in_method="qr_code",
                check_in_lat=latitude,
                check_in_lng=longitude,
                check_in_photo=photo_url,
                geofence_id=qr_session.geofence_id,
                is_late=is_late,
                late_minutes=late_minutes,
                status="late" if is_late else "present",
            )
            db.add(attendance)
            await db.commit()
            await db.refresh(attendance)
            return attendance

    # -------------------------------------------------------
    # POINTAGE ENTRÉE via GPS (employé distant)
    # -------------------------------------------------------
    @staticmethod
    async def checkin_gps(
        db: AsyncSession,
        employee_id: str,
        latitude: float,
        longitude: float,
        photo_url: Optional[str] = None,
    ) -> Attendance:
        """Pointer l'entrée via GPS pour employé à distance"""

        # 1. Vérifier que l'employé est dans une zone autorisée
        geofence = await AttendanceService._verify_geofence(
            db, employee_id, latitude, longitude
        )
        if not geofence:
            raise ValueError(
                "Vous n'êtes pas dans une zone autorisée pour pointer. "
                "Contactez votre superviseur."
            )

        # 2. Vérifier doublon
        today = date.today()
        existing = await AttendanceService._get_today_attendance(db, employee_id, today)
        if existing and existing.check_in:
            raise ValueError("Vous avez déjà pointé votre entrée aujourd'hui")

        # 3. Calculer retard
        is_late, late_minutes = await AttendanceService._calculate_lateness(db, employee_id)

        # 4. Créer pointage
        now = datetime.now(timezone.utc)
        attendance = Attendance(
            employee_id=employee_id,
            date=today,
            check_in=now,
            check_in_method="gps",
            check_in_lat=latitude,
            check_in_lng=longitude,
            check_in_photo=photo_url,
            geofence_id=geofence.id,
            is_late=is_late,
            late_minutes=late_minutes,
            status="remote" if True else ("late" if is_late else "present"),
        )
        db.add(attendance)
        await db.commit()
        await db.refresh(attendance)
        return attendance

    # -------------------------------------------------------
    # POINTAGE ENTRÉE via PIN
    # -------------------------------------------------------
    @staticmethod
    async def checkin_pin(
        db: AsyncSession,
        employee_code: str,
        pin: str,
        geofence_id: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
    ) -> Attendance:
        """Pointer l'entrée avec code PIN (kiosque ou app)"""
        from app.core.security import verify_pin

        # 1. Trouver l'employé par code
        result = await db.execute(
            select(Employee).where(
                Employee.employee_code == employee_code,
                Employee.is_active == True
            )
        )
        employee = result.scalar_one_or_none()
        if not employee:
            raise ValueError("Code employé introuvable")

        # 2. Vérifier PIN
        if not employee.pin_code or not verify_pin(pin, employee.pin_code):
            raise ValueError("Code PIN incorrect")

        # 3. Doublon check
        today = date.today()
        existing = await AttendanceService._get_today_attendance(db, str(employee.id), today)
        if existing and existing.check_in:
            raise ValueError("Entrée déjà enregistrée aujourd'hui")

        is_late, late_minutes = await AttendanceService._calculate_lateness(
            db, str(employee.id)
        )
        now = datetime.now(timezone.utc)
        attendance = Attendance(
            employee_id=employee.id,
            date=today,
            check_in=now,
            check_in_method="pin",
            check_in_lat=latitude,
            check_in_lng=longitude,
            geofence_id=geofence_id,
            is_late=is_late,
            late_minutes=late_minutes,
            status="late" if is_late else "present",
        )
        db.add(attendance)
        await db.commit()
        await db.refresh(attendance)
        return attendance

    # -------------------------------------------------------
    # POINTAGE SORTIE
    # -------------------------------------------------------
    @staticmethod
    async def checkout(
        db: AsyncSession,
        employee_id: str,
        method: str = "qr_code",
        qr_token: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
        photo_url: Optional[str] = None,
    ) -> Attendance:
        """Pointer la sortie"""

        # Valider QR si méthode QR
        if method == "qr_code" and qr_token:
            await QRCodeService.validate_token(db, qr_token)

        today = date.today()
        attendance = await AttendanceService._get_today_attendance(db, employee_id, today)

        if not attendance or not attendance.check_in:
            raise ValueError("Aucune entrée enregistrée aujourd'hui")
        if attendance.check_out:
            raise ValueError("Sortie déjà enregistrée aujourd'hui")

        now = datetime.now(timezone.utc)
        duration_minutes = int((now - attendance.check_in).total_seconds() / 60)

        attendance.check_out = now
        attendance.check_out_method = method
        attendance.check_out_lat = latitude
        attendance.check_out_lng = longitude
        attendance.check_out_photo = photo_url
        attendance.work_duration = duration_minutes

        await db.commit()
        await db.refresh(attendance)
        return attendance

    # -------------------------------------------------------
    # MÉTHODES PRIVÉES UTILITAIRES
    # -------------------------------------------------------
    @staticmethod
    async def _get_today_attendance(
        db: AsyncSession, employee_id: str, today: date
    ) -> Optional[Attendance]:
        result = await db.execute(
            select(Attendance).where(
                and_(
                    Attendance.employee_id == employee_id,
                    Attendance.date == today,
                )
            )
        )
        return result.scalar_one_or_none()

    @staticmethod
    async def _verify_geofence(
        db: AsyncSession, employee_id: str, lat: float, lng: float
    ) -> Optional[Geofence]:
        """Vérifie si les coordonnées sont dans une zone autorisée"""
        # Récupérer toutes les geofences actives
        result = await db.execute(
            select(Geofence).where(Geofence.is_active == True)
        )
        geofences = result.scalars().all()

        employee_location = (lat, lng)
        for geofence in geofences:
            geofence_center = (float(geofence.latitude), float(geofence.longitude))
            distance = geodesic(employee_location, geofence_center).meters
            if distance <= geofence.radius_meters:
                return geofence
        return None

    @staticmethod
    async def _calculate_lateness(
        db: AsyncSession, employee_id: str
    ) -> tuple[bool, int]:
        """Calcule si l'employé est en retard et de combien de minutes"""
        from datetime import time as dtime
        now = datetime.now(timezone.utc)
        now_local = now  # Adaptez selon le fuseau horaire Haiti (UTC-5)

        # Récupérer l'horaire de l'employé
        result = await db.execute(
            select(WorkSchedule)
            .join(EmployeeSchedule, EmployeeSchedule.schedule_id == WorkSchedule.id)
            .where(
                EmployeeSchedule.employee_id == employee_id,
                EmployeeSchedule.end_date.is_(None)
            )
        )
        schedule = result.scalar_one_or_none()

        if not schedule:
            return False, 0  # Pas d'horaire défini = pas de retard calculé

        # Heure limite avec tolérance
        scheduled_hour = schedule.start_time.hour
        scheduled_minute = schedule.start_time.minute + schedule.grace_minutes

        scheduled_start = now_local.replace(
            hour=scheduled_hour,
            minute=scheduled_minute % 60,
            second=0,
            microsecond=0
        )

        if now_local > scheduled_start:
            late_minutes = int((now_local - scheduled_start).total_seconds() / 60)
            return True, late_minutes
        return False, 0

