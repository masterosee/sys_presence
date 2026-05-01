"""
Routes API - Départements
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import Optional
from pydantic import BaseModel

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User, Department, Employee, Position

router = APIRouter()


class DepartmentCreate(BaseModel):
    name: str
    code: str
    description: Optional[str] = None


@router.get("/")
async def list_departments(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Department).where(Department.is_active == True).order_by(Department.name)
    )
    departments = result.scalars().all()

    output = []
    for dept in departments:
        # Compter les employés
        count_r = await db.execute(
            select(func.count(Employee.id)).where(
                Employee.department_id == dept.id,
                Employee.is_active == True
            )
        )
        count = count_r.scalar()
        output.append({
            "id": str(dept.id),
            "name": dept.name,
            "code": dept.code,
            "description": dept.description,
            "employee_count": count,
        })
    return output


@router.post("/")
async def create_department(
    data: DepartmentCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role not in ["admin", "rh"]:
        raise HTTPException(403, "Accès réservé aux administrateurs")

    existing = await db.execute(select(Department).where(Department.code == data.code))
    if existing.scalar_one_or_none():
        raise HTTPException(400, f"Le code '{data.code}' est déjà utilisé")

    dept = Department(name=data.name, code=data.code, description=data.description)
    db.add(dept)
    await db.commit()
    await db.refresh(dept)
    return {"message": f"Département '{data.name}' créé", "id": str(dept.id)}


