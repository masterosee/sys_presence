"""
Routes API - Authentification
Login, refresh token, profil connecté
"""
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from datetime import datetime, timezone
from pydantic import BaseModel
from typing import Optional

from app.core.database import get_db
from app.core.security import (
    verify_password, create_access_token,
    create_refresh_token, get_current_user, hash_password
)
from app.models import User, Employee, AuditLog
from app.core.config import settings
from jose import JWTError, jwt

router = APIRouter()


# ─── Schémas ──────────────────────────────────────────────────
class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    role: str
    employee_id: str
    full_name: str
    employee_code: str


class RefreshRequest(BaseModel):
    refresh_token: str


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str


class CreateUserRequest(BaseModel):
    employee_id: str
    username: str
    password: str
    role: str = "employee"


# ─── LOGIN ────────────────────────────────────────────────────
@router.post("/login", response_model=TokenResponse)
async def login(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    """
    Connexion avec nom d'utilisateur et mot de passe.
    Retourne un JWT valide 8 heures.
    """
    # 1. Trouver l'utilisateur
    result = await db.execute(
        select(User).where(
            User.username == form_data.username,
            User.is_active == True,
        )
    )
    user = result.scalar_one_or_none()

    if not user or not verify_password(form_data.password, user.password_hash):
        # Log tentative échouée
        await _log_action(db, None, "LOGIN_FAILED", details={
            "username": form_data.username,
            "ip": request.client.host if request.client else None,
        })
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Nom d'utilisateur ou mot de passe incorrect",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 2. Charger l'employé associé
    result = await db.execute(
        select(Employee).where(Employee.id == user.employee_id)
    )
    employee = result.scalar_one_or_none()
    if not employee or not employee.is_active:
        raise HTTPException(400, "Compte employé désactivé. Contactez le RH.")

    # 3. Créer les tokens
    token_data = {"sub": user.id, "role": user.role, "emp": user.employee_id}
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)

    # 4. Mettre à jour last_login
    await db.execute(
        update(User)
        .where(User.id == user.id)
        .values(last_login=datetime.now(timezone.utc))
    )

    # 5. Log succès
    await _log_action(db, user.id, "LOGIN_SUCCESS", entity="user", entity_id=user.id,
        details={"ip": request.client.host if request.client else None})
    await db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        role=user.role,
        employee_id=str(employee.id),
        full_name=employee.full_name,
        employee_code=employee.employee_code,
    )


# ─── REFRESH TOKEN ────────────────────────────────────────────
@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    body: RefreshRequest,
    db: AsyncSession = Depends(get_db),
):
    """Renouveler le token d'accès avec le refresh token"""
    credentials_exception = HTTPException(
        status_code=401, detail="Refresh token invalide ou expiré"
    )
    try:
        payload = jwt.decode(body.refresh_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id = payload.get("sub")
        token_type = payload.get("type")
        if not user_id or token_type != "refresh":
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    result = await db.execute(
        select(User).where(User.id == user_id, User.is_active == True)
    )
    user = result.scalar_one_or_none()
    if not user:
        raise credentials_exception

    result2 = await db.execute(
        select(Employee).where(Employee.id == user.employee_id)
    )
    employee = result2.scalar_one_or_none()

    token_data = {"sub": user.id, "role": user.role, "emp": user.employee_id}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        role=user.role,
        employee_id=str(employee.id),
        full_name=employee.full_name,
        employee_code=employee.employee_code,
    )


# ─── MON PROFIL ───────────────────────────────────────────────
@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Retourne les infos de l'utilisateur connecté"""
    result = await db.execute(
        select(Employee).where(Employee.id == current_user.employee_id)
    )
    employee = result.scalar_one_or_none()
    return {
        "user_id": current_user.id,
        "username": current_user.username,
        "role": current_user.role,
        "employee_id": str(employee.id),
        "employee_code": employee.employee_code,
        "full_name": employee.full_name,
        "email": employee.email,
        "phone": employee.phone,
        "photo_url": employee.photo_url,
        "department": employee.department.name if employee.department else None,
        "position": employee.position.title if employee.position else None,
        "is_remote": employee.is_remote,
        "last_login": current_user.last_login.isoformat() if current_user.last_login else None,
    }


# ─── CHANGER MOT DE PASSE ─────────────────────────────────────
@router.post("/change-password")
async def change_password(
    body: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Changer son mot de passe"""
    if not verify_password(body.old_password, current_user.password_hash):
        raise HTTPException(400, "Ancien mot de passe incorrect")

    if len(body.new_password) < 6:
        raise HTTPException(400, "Le nouveau mot de passe doit avoir au moins 6 caractères")

    await db.execute(
        update(User)
        .where(User.id == current_user.id)
        .values(password_hash=hash_password(body.new_password))
    )
    await _log_action(db, current_user.id, "PASSWORD_CHANGED", entity="user", entity_id=current_user.id)
    await db.commit()
    return {"message": "Mot de passe changé avec succès"}


# ─── CRÉER UTILISATEUR (admin seulement) ──────────────────────
@router.post("/create-user")
async def create_user(
    body: CreateUserRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Créer un compte utilisateur pour un employé (admin/RH uniquement)"""
    if current_user.role not in ["admin", "rh"]:
        raise HTTPException(403, "Accès réservé aux administrateurs et RH")

    # Vérifier que l'employé existe
    result = await db.execute(
        select(Employee).where(Employee.id == body.employee_id, Employee.is_active == True)
    )
    employee = result.scalar_one_or_none()
    if not employee:
        raise HTTPException(404, "Employé introuvable")

    # Vérifier doublon username
    result2 = await db.execute(select(User).where(User.username == body.username))
    if result2.scalar_one_or_none():
        raise HTTPException(400, f"Le nom d'utilisateur '{body.username}' est déjà pris")

    new_user = User(
        employee_id=body.employee_id,
        username=body.username,
        password_hash=hash_password(body.password),
        role=body.role,
    )
    db.add(new_user)
    await _log_action(db, current_user.id, "USER_CREATED", entity="user",
        details={"username": body.username, "role": body.role})
    await db.commit()
    await db.refresh(new_user)
    return {
        "message": f"Compte créé pour {employee.full_name}",
        "user_id": new_user.id,
        "username": new_user.username,
        "role": new_user.role,
    }


# ─── UTILITAIRE LOG ───────────────────────────────────────────
async def _log_action(db, user_id, action, entity=None, entity_id=None, details=None):
    log = AuditLog(
        user_id=user_id,
        action=action,
        entity=entity,
        entity_id=entity_id,
        details=details or {},
        ip_address=None,
    )
    db.add(log)
    
    
    