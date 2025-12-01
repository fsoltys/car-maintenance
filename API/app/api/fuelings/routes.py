from __future__ import annotations

from typing import List
from uuid import UUID
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, DataError, DBAPIError

from app.api.deps import get_db, get_current_user_id
from app.api.vehicles.schemas import (
    FuelingCreate,
    FuelingUpdate,
    FuelingOut,
    DrivingCycle,
    FuelType,
)

router = APIRouter(tags=["fuelings"])


@router.get(
    "/vehicles/{vehicle_id}/fuelings",
    response_model=List[FuelingOut],
)
def list_fuelings_for_vehicle(
    vehicle_id: UUID,
    from_datetime: datetime | None = None,
    to_datetime: datetime | None = None,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[FuelingOut]:
    """
    Lista tankowań dla pojazdu.

    Opcjonalne parametry zapytania:
    - from_datetime: początek zakresu (filled_at >= from_datetime)
    - to_datetime:   koniec zakresu   (filled_at <= to_datetime)
    """

    existing = db.execute(
        text("SELECT * FROM car_app.fn_get_vehicle(:user_id, :vehicle_id)"),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().first()

    if existing is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or no permission",
        )

    try:
        if from_datetime is None and to_datetime is None:
            # bez zakresu dat
            rows = db.execute(
                text(
                    """
                    SELECT * FROM car_app.fn_get_vehicle_fuelings(
                        :user_id,
                        :vehicle_id
                    )
                    """
                ),
                {
                    "user_id": current_user_id,
                    "vehicle_id": vehicle_id,
                },
            ).mappings().all()
        else:
            # z zakresem dat
            rows = db.execute(
                text(
                    """
                    SELECT * FROM car_app.fn_get_vehicle_fuelings_range(
                        :user_id,
                        :vehicle_id,
                        :from_ts,
                        :to_ts
                    )
                    """
                ),
                {
                    "user_id": current_user_id,
                    "vehicle_id": vehicle_id,
                    "from_ts": from_datetime,
                    "to_ts": to_datetime,
                },
            ).mappings().all()
    except DataError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date range.",
        ) from exc
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while fetching fuelings.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    return [FuelingOut.model_validate(row) for row in rows]


@router.get("/fuelings/{fueling_id}", response_model=FuelingOut)
def get_fueling(
    fueling_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> FuelingOut:
    """
    Zwraca pojedyncze tankowanie, jeśli użytkownik ma dostęp do pojazdu
    (OWNER / VIEWER / EDITOR).
    """
    try:
        row = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_get_fueling(
                    :user_id,
                    :fueling_id
                )
                """
            ),
            {
                "user_id": current_user_id,
                "fueling_id": fueling_id,
            },
        ).mappings().first()
    except DataError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid fueling identifier.",
        ) from exc
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while fetching fueling.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fueling not found or no permission.",
        )

    return FuelingOut.model_validate(row)


@router.post(
    "/vehicles/{vehicle_id}/fuelings",
    response_model=FuelingOut,
    status_code=status.HTTP_201_CREATED,
)
def create_fueling(
    vehicle_id: UUID,
    payload: FuelingCreate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> FuelingOut:
    """
    Tworzy nowe tankowanie dla pojazdu.
    Tylko OWNER/EDITOR (pilnowane w fn_create_fueling).
    """

    # Sprawdzenie dostępu do pojazdu (dla czytelnego 404)
    existing = db.execute(
        text("SELECT * FROM car_app.fn_get_vehicle(:user_id, :vehicle_id)"),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().first()

    if existing is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or no permission",
        )

    data = payload.model_dump()

    params = {
        "user_id": current_user_id,
        "vehicle_id": vehicle_id,
        "filled_at": data["filled_at"],
        "price_per_unit": data["price_per_unit"],
        "volume": data["volume"],
        "odometer_km": data["odometer_km"],
        "full_tank": data["full_tank"],
        "driving_cycle": data["driving_cycle"].value
        if data.get("driving_cycle")
        else None,
        "fuel": data["fuel"].value,
        "note": data.get("note"),
        "fuel_level_before": data.get("fuel_level_before"),
        "fuel_level_after": data.get("fuel_level_after"),
    }

    try:
        row = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_create_fueling(
                    :user_id,
                    :vehicle_id,
                    :filled_at,
                    :price_per_unit,
                    :volume,
                    :odometer_km,
                    :full_tank,
                    :driving_cycle,
                    :fuel,
                    :note,
                    :fuel_level_before,
                    :fuel_level_after
                )
                """
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)

        if pgcode == "23503":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid vehicle or user reference.",
            ) from exc

        if pgcode in ("23502", "23514"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid fueling data or constraint violation.",
            ) from exc

        if pgcode == "40001":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Transaction conflict, please retry.",
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid fueling data or constraint violation.",
        ) from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid input data.",
        ) from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while creating fueling.",
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if row is None:
        # brak uprawnień (funkcja zwróciła 0 wierszy)
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No permission to add fueling for this vehicle.",
        )

    return FuelingOut.model_validate(row)


@router.patch(
    "/fuelings/{fueling_id}",
    response_model=FuelingOut,
)
def update_fueling(
    fueling_id: UUID,
    payload: FuelingUpdate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> FuelingOut:
    """
    Partial update:
    """
    existing = db.execute(
        text(
            "SELECT * FROM car_app.fn_get_fueling(:user_id, :fueling_id)"
        ),
        {"user_id": current_user_id, "fueling_id": fueling_id},
    ).mappings().first()

    if existing is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fueling not found or no permission",
        )

    base = dict(existing)
    patch = payload.model_dump(exclude_unset=True)
    base.update(patch)

    driving_cycle = None
    if base.get("driving_cycle") is not None:
        if isinstance(base["driving_cycle"], str):
            driving_cycle = base["driving_cycle"]
        else:
            driving_cycle = base["driving_cycle"].value

    params = {
        "user_id": current_user_id,
        "fueling_id": fueling_id,
        "filled_at": base["filled_at"],
        "price_per_unit": base["price_per_unit"],
        "volume": base["volume"],
        "odometer_km": base["odometer_km"],
        "full_tank": base["full_tank"],
        "driving_cycle": driving_cycle,
        "fuel": base["fuel"]
        if isinstance(base["fuel"], str)
        else base["fuel"].value,
        "note": base.get("note"),
        "fuel_level_before": base.get("fuel_level_before"),
        "fuel_level_after": base.get("fuel_level_after"),
    }

    try:
        row = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_update_fueling(
                    :user_id,
                    :fueling_id,
                    :filled_at,
                    :price_per_unit,
                    :volume,
                    :odometer_km,
                    :full_tank,
                    :driving_cycle,
                    :fuel,
                    :note,
                    :fuel_level_before,
                    :fuel_level_after
                )
                """
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)

        if pgcode in ("23502", "23514"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid fueling data or constraint violation.",
            ) from exc

        if pgcode == "40001":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Transaction conflict, please retry.",
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid fueling data or constraint violation.",
        ) from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid input data.",
        ) from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while updating fueling.",
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No permission to update this fueling.",
        )

    return FuelingOut.model_validate(row)


@router.delete(
    "/fuelings/{fueling_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_fueling(
    fueling_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> None:
    """
    Usunięcie tankowania — OWNER/EDITOR.
    """
    try:
        result = db.execute(
            text(
                "SELECT car_app.fn_delete_fueling(:user_id, :fueling_id) AS deleted"
            ),
            {"user_id": current_user_id, "fueling_id": fueling_id},
        ).mappings().first()
        db.commit()
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while deleting fueling.",
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if not result or not result["deleted"]:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fueling not found or no permission",
        )
