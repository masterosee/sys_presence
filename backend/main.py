"""
CONATEL - Système de Présence
Backend FastAPI - Point d'entrée principal
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import os

from app.core.config import settings
from app.core.database import engine, Base
from app.api.v1 import auth, employees, attendances, qr_codes, departments, leaves, reports
from app.core.scheduler import start_scheduler, stop_scheduler


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Démarrage
    print("🚀 CONATEL Présence - Démarrage...")
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    start_scheduler()
    yield
    # Arrêt
    stop_scheduler()
    print("✅ Serveur arrêté proprement")


app = FastAPI(
    title="CONATEL - Système de Présence",
    description="API REST pour la gestion des présences des employés CONATEL",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS - permet à Flutter d'appeler l'API
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Fichiers uploadés (photos selfie)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

# Routes API v1
app.include_router(auth.router,        prefix="/api/v1/auth",        tags=["Authentification"])
app.include_router(employees.router,   prefix="/api/v1/employees",   tags=["Employés"])
app.include_router(attendances.router, prefix="/api/v1/attendances", tags=["Pointages"])
app.include_router(qr_codes.router,    prefix="/api/v1/qr",          tags=["QR Code"])
app.include_router(departments.router, prefix="/api/v1/departments", tags=["Départements"])
app.include_router(leaves.router,      prefix="/api/v1/leaves",      tags=["Congés"])
app.include_router(reports.router,     prefix="/api/v1/reports",     tags=["Rapports"])


@app.get("/", tags=["Santé"])
async def root():
    return {"message": "CONATEL Présence API", "status": "ok", "version": "1.0.0"}


@app.get("/health", tags=["Santé"])
async def health_check():
    return {"status": "healthy"}
  
  
