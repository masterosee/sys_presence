# app/models/user.py
import uuid
from sqlalchemy import Column, String, Boolean, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.core.database import Base

class User(Base):
    __tablename__ = "users"
    id            = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    employee_id   = Column(UUID(as_uuid=True), ForeignKey("employees.id"), unique=True)
    username      = Column(String(50), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role          = Column(String(20), default="employee")
    last_login    = Column(DateTime(timezone=True))
    is_active     = Column(Boolean, default=True)
    employee      = relationship("Employee", back_populates="user")
    
    