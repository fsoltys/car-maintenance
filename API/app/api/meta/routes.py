from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.api.deps import get_db
from app.config import settings

router = APIRouter(prefix="/meta", tags=["meta"])


@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    """
    Sprawdza połączenie z bazą oraz zwraca środowisko API.
    """
    # Minimalny test DB
    db.execute(text("SELECT 1"))

    return {
        "status": "ok",
        "environment": settings.environment,
        "db": "connected"
    }


@router.get("/version")
def version():
    """
    Zwraca metadane o wersji backendu.
    """
    return {
        "service": "Car Maintenance API",
        "version": "0.1.0",
        "description": "API meta information"
    }