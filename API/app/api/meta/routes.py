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

@router.get("/enums")
def get_enums(db: Session = Depends(get_db)):
    """
    Zwraca słowniki enumów z bazy danych, do użycia np. w dropdownach na froncie.

    Struktura odpowiedzi:
    {
      "fuel_type": [
        {"value": "PB95", "label": "PB95"},
        ...
      ],
      "service_type": [...],
      ...
    }
    """
    row = db.execute(
        text("SELECT car_app.fn_get_enums() AS enums")
    ).mappings().first()

    return row["enums"]