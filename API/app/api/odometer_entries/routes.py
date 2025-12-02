from __future__ import annotations

from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import text
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, DataError, DBAPIError

from app.api.deps import get_db, get_current_user_id
from .schemas import OdometerEntryCreate, OdometerEntryUpdate, OdometerEntryOut, OdometerHistoryItem


router = APIRouter(tags=["odometer_entries"])


@router.get("/vehicles/{vehicle_id}/odometer-entries", response_model=List[OdometerEntryOut])
def list_odometer_entries(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[OdometerEntryOut]:
    """
    Lista ręcznych wpisów przebiegu dla pojazdu.
    """
    # sprawdź uprawnienia poprzez funkcję car_app.fn_get_vehicle
    existing = db.execute(
        text("SELECT * FROM car_app.fn_get_vehicle(:user_id, :vehicle_id)"),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().first()

    if existing is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found or no permission")

    try:
        rows = db.execute(
            text("SELECT * FROM car_app.fn_get_vehicle_odometer_entries(:actor_id, :vehicle_id)"),
            {"actor_id": current_user_id, "vehicle_id": vehicle_id},
        ).mappings().all()
    except DBAPIError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while listing odometer entries.") from exc
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    return [OdometerEntryOut.model_validate(row) for row in rows]


@router.post(
    "/vehicles/{vehicle_id}/odometer-entries",
    response_model=OdometerEntryOut,
    status_code=status.HTTP_201_CREATED,
)
def create_odometer_entry(
    vehicle_id: UUID,
    payload: OdometerEntryCreate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> OdometerEntryOut:
    """
    Dodaje ręczny wpis przebiegu (odometer_entries).
    """
    params = {
        "actor_id": current_user_id,
        "vehicle_id": vehicle_id,
        "entry_date": payload.entry_date,
        "value_km": payload.value_km,
        "note": payload.note,
    }

    try:
        row = db.execute(
            text(
                "SELECT * FROM car_app.fn_create_odometer_entry(:actor_id, :vehicle_id, :entry_date, :value_km, :note)"
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation while creating entry.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while creating odometer entry.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found or no permission")

    return OdometerEntryOut.model_validate(row)


@router.patch("/odometer-entries/{entry_id}", response_model=OdometerEntryOut)
def update_odometer_entry(
    entry_id: UUID,
    payload: OdometerEntryUpdate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> OdometerEntryOut:
    """
    Aktualizuje ręczny wpis przebiegu.
    """
    params = {
        "actor_id": current_user_id,
        "entry_id": entry_id,
        "entry_date": payload.entry_date,
        "value_km": payload.value_km,
        "note": payload.note,
    }

    try:
        row = db.execute(
            text(
                "SELECT * FROM car_app.fn_update_odometer_entry(:actor_id, :entry_id, :entry_date, :value_km, :note)"
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation while updating entry.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while updating odometer entry.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Odometer entry not found or no permission")

    return OdometerEntryOut.model_validate(row)


@router.delete("/odometer-entries/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_odometer_entry(
    entry_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> None:
    """
    Usuwa ręczny wpis przebiegu.
    """
    try:
        result = db.execute(
            text("SELECT car_app.fn_delete_odometer_entry(:actor_id, :entry_id)"),
            {"actor_id": current_user_id, "entry_id": entry_id},
        ).scalar()
        db.commit()
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while deleting odometer entry.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if not result:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Odometer entry not found or no permission")


@router.get("/vehicles/{vehicle_id}/odometer-graph", response_model=List[OdometerHistoryItem])
def get_odometer_graph(
    vehicle_id: UUID,
    from_date: str | None = Query(default=None),
    to_date: str | None = Query(default=None),
    limit: int = Query(default=1000, ge=1, le=10000),
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[OdometerHistoryItem]:
    """
    Zwraca zaggregowane punkty przebiegu (fuelings, services, manual entries) do wykresu.
    Parametry `from_date` i `to_date` są opcjonalne.
    """
    try:
        rows = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_get_vehicle_odometer_history(
                    :actor_id,
                    :vehicle_id,
                    CAST(:p_from AS timestamptz),
                    CAST(:p_to AS timestamptz),
                    :p_limit
                )
                """
            ),
            {
                "actor_id": current_user_id,
                "vehicle_id": vehicle_id,
                "p_from": from_date,
                "p_to": to_date,
                "p_limit": limit,
            },
        ).mappings().all()
    except DBAPIError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while fetching odometer history.") from exc
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    return [OdometerHistoryItem.model_validate(row) for row in rows]
