"""
Service QR Code Dynamique
- Génère un nouveau token toutes les 30 secondes
- Chaque token est lié à une zone géographique (geofence)
- Un token ne peut être utilisé qu'une seule fois
"""
import secrets
import hashlib
import qrcode
import io
import base64
from datetime import datetime, timedelta, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.core.config import settings
from app.models import QRSession
from app.models import Geofence


class QRCodeService:

    @staticmethod
    def generate_token() -> str:
        """Génère un token aléatoire sécurisé"""
        return secrets.token_urlsafe(32)

    @staticmethod
    def generate_qr_image(token: str, geofence_name: str) -> str:
        """
        Crée l'image QR Code encodée en base64
        Le QR contient : token + geofence pour vérification côté serveur
        """
        # Contenu du QR : token à envoyer à l'API
        qr_data = f"CONATEL:CHECKIN:{token}"

        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=10,
            border=4,
        )
        qr.add_data(qr_data)
        qr.make(fit=True)

        img = qr.make_image(fill_color="black", back_color="white")
        buffer = io.BytesIO()
        img.save(buffer, format="PNG")
        buffer.seek(0)
        return base64.b64encode(buffer.getvalue()).decode()

    @staticmethod
    async def create_new_session(
        db: AsyncSession,
        geofence_id: str
    ) -> dict:
        """
        Crée une nouvelle session QR Code (expire dans 30 sec)
        Appelé automatiquement par le scheduler toutes les 30 secondes
        """
        token = QRCodeService.generate_token()
        expires_at = datetime.now(timezone.utc) + timedelta(
            seconds=settings.QR_CODE_EXPIRE_SECONDS
        )

        # Récupérer la geofence
        result = await db.execute(
            select(Geofence).where(Geofence.id == geofence_id, Geofence.is_active == True)
        )
        geofence = result.scalar_one_or_none()
        if not geofence:
            raise ValueError(f"Geofence {geofence_id} introuvable")

        # Sauvegarder en BD
        session = QRSession(
            token=token,
            geofence_id=geofence_id,
            expires_at=expires_at,
        )
        db.add(session)
        await db.commit()
        await db.refresh(session)

        # Générer l'image QR
        qr_image = QRCodeService.generate_qr_image(token, geofence.name)

        return {
            "token": token,
            "qr_image_base64": qr_image,
            "geofence_id": geofence_id,
            "geofence_name": geofence.name,
            "expires_at": expires_at.isoformat(),
            "expires_in_seconds": settings.QR_CODE_EXPIRE_SECONDS,
        }

    @staticmethod
    async def validate_token(db: AsyncSession, token: str) -> QRSession:
        """
        Valide un token QR scanné par un employé
        - Vérifie qu'il n'est pas expiré
        - Vérifie qu'il n'a pas déjà été utilisé
        - Le marque comme utilisé (usage unique)
        """
        now = datetime.now(timezone.utc)

        result = await db.execute(
            select(QRSession).where(
                QRSession.token == token,
                QRSession.expires_at > now,
                QRSession.is_used == False,
            )
        )
        session = result.scalar_one_or_none()

        if not session:
            raise ValueError("QR Code invalide, expiré ou déjà utilisé")

        # Marquer comme utilisé (usage unique - anti-fraude)
        session.is_used = True
        await db.commit()

        return session

    @staticmethod
    async def cleanup_expired(db: AsyncSession):
        """Nettoie les anciennes sessions expirées (appelé par scheduler)"""
        from sqlalchemy import delete
        cutoff = datetime.now(timezone.utc) - timedelta(hours=1)
        await db.execute(
            delete(QRSession).where(QRSession.expires_at < cutoff)
        )
        await db.commit()

