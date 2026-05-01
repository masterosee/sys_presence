"""
Modèles SQLAlchemy - Toutes les tables
"""
import uuid
from datetime import datetime, date
from typing import Optional, List
from sqlalchemy import (
    String, Boolean, Integer, Date, DateTime, Time,
    Text, ForeignKey, DECIMAL, BigInteger
)
from sqlalchemy.dialects.postgresql import UUID, JSONB, ARRAY, INET
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base


def gen_uuid():
    return str(uuid.uuid4())


# ─────────────────────────────────────────────────────────────
# DÉPARTEMENT
# ─────────────────────────────────────────────────────────────
class Department(Base):
    __tablename__ = "departments"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text)
    manager_id: Mapped[Optional[str]] = mapped_column(UUID(as_uuid=False), ForeignKey("employees.id"), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    # Relations
    employees: Mapped[List["Employee"]] = relationship("Employee", back_populates="department", foreign_keys="Employee.department_id")
    positions: Mapped[List["Position"]] = relationship("Position", back_populates="department")


# ─────────────────────────────────────────────────────────────
# POSTE / FONCTION
# ─────────────────────────────────────────────────────────────
class Position(Base):
    __tablename__ = "positions"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    department_id: Mapped[Optional[str]] = mapped_column(UUID(as_uuid=False), ForeignKey("departments.id"))
    level: Mapped[Optional[str]] = mapped_column(String(50))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    # Relations
    department: Mapped[Optional["Department"]] = relationship("Department", back_populates="positions")
    employees: Mapped[List["Employee"]] = relationship("Employee", back_populates="position")


# ─────────────────────────────────────────────────────────────
# EMPLOYÉ
# ─────────────────────────────────────────────────────────────
class Employee(Base):
    __tablename__ = "employees"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    employee_code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    email: Mapped[str] = mapped_column(String(150), unique=True, nullable=False)
    phone: Mapped[Optional[str]] = mapped_column(String(20))
    department_id: Mapped[Optional[str]] = mapped_column(UUID(as_uuid=False), ForeignKey("departments.id"))
    position_id: Mapped[Optional[str]] = mapped_column(UUID(as_uuid=False), ForeignKey("positions.id"))
    hire_date: Mapped[date] = mapped_column(Date, nullable=False)
    contract_type: Mapped[str] = mapped_column(String(30), default="CDI")
    photo_url: Mapped[Optional[str]] = mapped_column(Text)
    pin_code: Mapped[Optional[str]] = mapped_column(String(255))  # hashé bcrypt
    is_remote: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    # Relations
    department: Mapped[Optional["Department"]] = relationship("Department", back_populates="employees", foreign_keys=[department_id])
    position: Mapped[Optional["Position"]] = relationship("Position", back_populates="employees")
    user: Mapped[Optional["User"]] = relationship("User", back_populates="employee", uselist=False)
    attendances: Mapped[List["Attendance"]] = relationship("Attendance", back_populates="employee", foreign_keys="Attendance.employee_id")
    leave_requests: Mapped[List["LeaveRequest"]] = relationship("LeaveRequest", back_populates="employee", foreign_keys="LeaveRequest.employee_id")
    schedules: Mapped[List["EmployeeSchedule"]] = relationship("EmployeeSchedule", back_populates="employee")

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"


# ─────────────────────────────────────────────────────────────
# UTILISATEUR (compte app)
# ─────────────────────────────────────────────────────────────
class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    employee_id: Mapped[str] = mapped_column(UUID(as_uuid=False), ForeignKey("employees.id", ondelete="CASCADE"), unique=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(20), default="employee")  # employee, manager, rh, admin
    last_login: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    # Relations
    employee: Mapped["Employee"] = relationship("Employee", back_populates="user")
    audit_logs: Mapped[List["AuditLog"]] = relationship("AuditLog", back_populates="user")


# ─────────────────────────────────────────────────────────────
# HORAIRE DE TRAVAIL
# ─────────────────────────────────────────────────────────────
class WorkSchedule(Base):
    __tablename__ = "work_schedules"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    start_time: Mapped[datetime] = mapped_column(Time, nullable=False)
    end_time: Mapped[datetime] = mapped_column(Time, nullable=False)
    break_duration: Mapped[int] = mapped_column(Integer, default=60)
    work_days: Mapped[List[int]] = mapped_column(ARRAY(Integer), default=[1,2,3,4,5])
    grace_minutes: Mapped[int] = mapped_column(Integer, default=15)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    employee_schedules: Mapped[List["EmployeeSchedule"]] = relationship("EmployeeSchedule", back_populates="schedule")


class EmployeeSchedule(Base):
    __tablename__ = "employee_schedules"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    employee_id: Mapped[str] = mapped_column(UUID(as_uuid=False), ForeignKey("employees.id", ondelete="CASCADE"))
    schedule_id: Mapped[str] = mapped_column(UUID(as_uuid=False), ForeignKey("work_schedules.id"))
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[Optional[date]] = mapped_column(Date)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    employee: Mapped["Employee"] = relationship("Employee", back_populates="schedules")
    schedule: Mapped["WorkSchedule"] = relationship("WorkSchedule", back_populates="employee_schedules")


# ─────────────────────────────────────────────────────────────
# ZONE GÉOGRAPHIQUE (Geofence)
# ─────────────────────────────────────────────────────────────
class Geofence(Base):
    __tablename__ = "geofences"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text)
    latitude: Mapped[float] = mapped_column(DECIMAL(10, 8), nullable=False)
    longitude: Mapped[float] = mapped_column(DECIMAL(11, 8), nullable=False)
    radius_meters: Mapped[int] = mapped_column(Integer, default=200)
    is_office: Mapped[bool] = mapped_column(Boolean, default=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    qr_sessions: Mapped[List["QRSession"]] = relationship("QRSession", back_populates="geofence")
    attendances: Mapped[List["Attendance"]] = relationship("Attendance", back_populates="geofence")


# ─────────────────────────────────────────────────────────────
# SESSION QR CODE
# ─────────────────────────────────────────────────────────────
class QRSession(Base):
    __tablename__ = "qr_sessions"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    token: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    geofence_id: Mapped[Optional[str]] = mapped_column(UUID(as_uuid=False), ForeignKey("geofences.id"))
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_used: Mapped[bool] = mapped_column(Boolean, default=False)

    geofence: Mapped[Optional["Geofence"]] = relationship("Geofence", back_populates="qr_sessions")


# ─────────────────────────────────────────────────────────────
# POINTAGE
# ─────────────────────────────────────────────────────────────
class Attendance(Base):
    __tablename__ = "attendances"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    employee_id: Mapped[str] = mapped_column(UUID(as_uuid=False), ForeignKey("employees.id", ondelete="CASCADE"))
    date: Mapped[date] = mapped_column(Date, nullable=False)
    check_in: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    check_out: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))

    check_in_method: Mapped[Optional[str]] = mapped_column(String(20))   # qr_code, gps, pin, nfc, biometric
    check_out_method: Mapped[Optional[str]] = mapped_column(String(20))

    check_in_lat: Mapped[Optional[float]] = mapped_column(DECIMAL(10, 8))
    check_in_lng: Mapped[Optional[float]] = mapped_column(DECIMAL(11, 8))
    check_out_lat: Mapped[Optional[float]] = mapped_column(DECIMAL(10, 8))
    check_out_lng: Mapped[Optional[float]] = mapped_column(DECIMAL(11, 8))
    geofence_id: Mapped[Optional[str]] = mapped_column(UUID(as_uuid=False), ForeignKey("geofences.id"))

    check_in_photo: Mapped[Optional[str]] = mapped_column(Text)
    check_out_photo: Mapped[Optional[str]] = mapped_column(Text)

    status: Mapped[str] = mapped_column(String(20), default="present")   # present, late, absent, remote, on_leave
    is_late: Mapped[bool] = mapped_column(Boolean, default=False)
    late_minutes: Mapped[int] = mapped_column(Integer, default=0)
    work_duration: Mapped[Optional[int]] = mapped_column(Integer)         # minutes

    notes: Mapped[Optional[str]] = mapped_column(Text)
    approved_by: Mapped[Optional[str]] = mapped_column(UUID(as_uuid=False), ForeignKey("employees.id"))

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    # Relations
    employee: Mapped["Employee"] = relationship("Employee", back_populates="attendances", foreign_keys=[employee_id])
    geofence: Mapped[Optional["Geofence"]] = relationship("Geofence", back_populates="attendances")


# ─────────────────────────────────────────────────────────────
# TYPES DE CONGÉ
# ─────────────────────────────────────────────────────────────
class LeaveType(Base):
    __tablename__ = "leave_types"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    max_days: Mapped[Optional[int]] = mapped_column(Integer)
    is_paid: Mapped[bool] = mapped_column(Boolean, default=True)
    color: Mapped[str] = mapped_column(String(7), default="#6366F1")

    requests: Mapped[List["LeaveRequest"]] = relationship("LeaveRequest", back_populates="leave_type")


# ─────────────────────────────────────────────────────────────
# DEMANDE DE CONGÉ
# ─────────────────────────────────────────────────────────────
class LeaveRequest(Base):
    __tablename__ = "leave_requests"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=gen_uuid)
    employee_id: Mapped[str] = mapped_column(UUID(as_uuid=False), ForeignKey("employees.id", ondelete="CASCADE"))
    leave_type_id: Mapped[str] = mapped_column(UUID(as_uuid=False), ForeignKey("leave_types.id"))
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    total_days: Mapped[int] = mapped_column(Integer, nullable=False)
    reason: Mapped[Optional[str]] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="pending")   # pending, approved, rejected
    reviewed_by: Mapped[Optional[str]] = mapped_column(UUID(as_uuid=False), ForeignKey("employees.id"))
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    review_comment: Mapped[Optional[str]] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    employee: Mapped["Employee"] = relationship("Employee", back_populates="leave_requests", foreign_keys=[employee_id])
    leave_type: Mapped["LeaveType"] = relationship("LeaveType", back_populates="requests")


# ─────────────────────────────────────────────────────────────
# AUDIT LOG
# ─────────────────────────────────────────────────────────────
class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[Optional[str]] = mapped_column(UUID(as_uuid=False), ForeignKey("users.id"))
    action: Mapped[str] = mapped_column(String(50), nullable=False)
    entity: Mapped[Optional[str]] = mapped_column(String(50))
    entity_id: Mapped[Optional[str]] = mapped_column(UUID(as_uuid=False))
    details: Mapped[Optional[dict]] = mapped_column(JSONB)
    ip_address: Mapped[Optional[str]] = mapped_column(String(45))
    device_info: Mapped[Optional[str]] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    user: Mapped[Optional["User"]] = relationship("User", back_populates="audit_logs")
    
    
