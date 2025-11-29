from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.api.deps import get_db
from app.config import settings


app = FastAPI(
    title="Car Maintenance API",
    version="0.1.0",
)


@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    """
    Prosty endpoint zdrowia:
    - sprawdza połączenie z DB (SELECT 1)
    - zwraca aktualne środowisko
    """
    db.execute(text("SELECT 1"))

    return {
        "status": "ok",
        "environment": settings.environment,
    }