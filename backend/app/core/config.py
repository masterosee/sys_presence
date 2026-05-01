# app/core/config.py

from pydantic_settings import BaseSettings
from typing import List

class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    QR_SECRET_KEY: str = 'conatel-qr-secret'
    QR_CODE_EXPIRE_SECONDS: int = 30
    UPLOAD_DIR: str = "uploads"
    MAX_PHOTO_SIZE_MB: int = 5
    #ALLOWED_ORIGINS: List[str] = ["http://localhost:8080"]
    ALLOWED_ORIGINS: List[str] = ["*"]

    class Config:
        env_file = ".env"

settings = Settings()



