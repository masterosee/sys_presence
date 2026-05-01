"""
Routes API - QR Code Dynamique
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User
from app.models import Geofence
from app.services.qr_service import QRCodeService
from pydantic import BaseModel

router = APIRouter()


class QRResponse(BaseModel):
    token: str
    qr_image_base64: str
    geofence_id: str
    geofence_name: str
    expires_at: str
    expires_in_seconds: int


# -------------------------------------------------------
# Générer un QR Code pour une zone (affiché sur l'écran kiosque)
# -------------------------------------------------------
@router.get("/generate/{geofence_id}", response_model=QRResponse)
async def generate_qr(
    geofence_id: str,
    db: AsyncSession = Depends(get_db),
):
    """
    Génère un QR Code dynamique pour une zone.
    Cet endpoint est appelé par l'écran kiosque toutes les 30 secondes.
    Pas besoin d'être connecté (c'est l'écran qui appelle, pas l'employé).
    """
    try:
        result = await QRCodeService.create_new_session(db, geofence_id)
        return result
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# -------------------------------------------------------
# Liste des zones disponibles (pour le kiosque)
# -------------------------------------------------------
@router.get("/geofences")
async def list_geofences(
    db: AsyncSession = Depends(get_db),
):
    """Liste toutes les zones géographiques actives"""
    result = await db.execute(
        select(Geofence).where(Geofence.is_active == True)
    )
    geofences = result.scalars().all()
    return [
        {
            "id": str(g.id),
            "name": g.name,
            "description": g.description,
            "latitude": float(g.latitude),
            "longitude": float(g.longitude),
            "radius_meters": g.radius_meters,
            "is_office": g.is_office,
        }
        for g in geofences
    ]


# -------------------------------------------------------
# Créer une zone géographique (admin/RH)
# -------------------------------------------------------
class GeofenceCreate(BaseModel):
    name: str
    description: Optional[str] = None
    latitude: float
    longitude: float
    radius_meters: int = 200
    is_office: bool = True


@router.post("/geofences")
async def create_geofence(
    data: GeofenceCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Créer une nouvelle zone autorisée (admin/RH seulement)"""
    if current_user.role not in ["admin", "rh"]:
        raise HTTPException(403, "Accès réservé aux administrateurs et RH")

    geofence = Geofence(
        name=data.name,
        description=data.description,
        latitude=data.latitude,
        longitude=data.longitude,
        radius_meters=data.radius_meters,
        is_office=data.is_office,
    )
    db.add(geofence)
    await db.commit()
    await db.refresh(geofence)
    return {"id": str(geofence.id), "message": f"Zone '{data.name}' créée avec succès"}

