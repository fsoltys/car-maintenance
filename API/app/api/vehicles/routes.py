from __future__ import annotations

from typing import List
from uuid import UUID, uuid4
import json

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, DataError, DBAPIError

from app.api.deps import get_db, get_current_user_id
from .schemas import (
    VehicleCreate,
    VehicleUpdate,
    VehicleOut,
    VehicleShareOut,
    VehicleShareCreate,
    VehicleShareUpdate,
    VehicleFuelConfigItem,
)


router = APIRouter(prefix="/vehicles", tags=["vehicles"])

# vehicle CRUD

@router.get("/", response_model=List[VehicleOut])
def list_vehicles(
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[VehicleOut]:
    """
    Lista pojazdów zalogowanego użytkownika (owner + shared).
    """
    try:
        rows = db.execute(
            text("SELECT * FROM fn_get_user_vehicles(:user_id)"),
            {"user_id": current_user_id},
        ).mappings().all()
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while listing vehicles.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    return [VehicleOut.model_validate(row) for row in rows]


@router.post(
    "/",
    response_model=VehicleOut,
    status_code=status.HTTP_201_CREATED,
)
def create_vehicle(
    payload: VehicleCreate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> VehicleOut:
    """
    Tworzy nowy pojazd przypisany do bieżącego użytkownika.
    """
    vehicle_id = uuid4()
    data = payload.model_dump()

    params = {
        "vehicle_id": vehicle_id,
        "owner_id": current_user_id,
        "name": data["name"],
        "description": data.get("description"),
        "vin": data.get("vin"),
        "plate": data.get("plate"),
        "policy_number": data.get("policy_number"),
        "model": data.get("model"),
        "production_year": data.get("production_year"),
        "dual_tank": data.get("dual_tank", False),
        "tank_capacity_l": data.get("tank_capacity_l"),
        "secondary_tank_capacity": data.get("secondary_tank_capacity"),
        "battery_capacity_kwh": data.get("battery_capacity_kwh"),
        "initial_odometer_km": data.get("initial_odometer_km"),
        "purchase_price": data.get("purchase_price"),
        "purchase_date": data.get("purchase_date"),
        "last_inspection_date": data.get("last_inspection_date"),
    }

    try:
        row = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_create_vehicle(
                    :vehicle_id,
                    :owner_id,
                    :name,
                    :description,
                    :vin,
                    :plate,
                    :policy_number,
                    :model,
                    :production_year,
                    :dual_tank,
                    :tank_capacity_l,
                    :secondary_tank_capacity,
                    :battery_capacity_kwh,
                    :initial_odometer_km,
                    :purchase_price,
                    :purchase_date,
                    :last_inspection_date
                )
                """
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)
        constraint = getattr(getattr(getattr(exc, "orig", None), "diag", None), "constraint_name", None)
        if pgcode == "23505":
            # unique violation — spróbuj dopasować do pola
            if constraint and "vin" in constraint.lower():
                detail = "VIN already exists."
            elif constraint and ("plate" in constraint.lower() or "licence" in constraint.lower()):
                detail = "Plate number already exists."
            else:
                detail = "Unique constraint violation."
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail) from exc
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid data or constraint violation.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while creating vehicle.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Vehicle creation failed",
        )

    return VehicleOut.model_validate(row)


@router.get("/{vehicle_id}", response_model=VehicleOut)
def get_vehicle(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> VehicleOut:
    """
    Szczegóły pojazdu (owner + shared).
    """
    row = db.execute(
        text("SELECT * FROM fn_get_vehicle(:user_id, :vehicle_id)"),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().first()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found",
        )

    return VehicleOut.model_validate(row)


@router.get("/{vehicle_id}/latest-odometer")
def get_latest_odometer(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """
    Get the most recent odometer reading for a vehicle.
    """
    # Verify user has access to this vehicle
    vehicle = db.execute(
        text("SELECT * FROM fn_get_vehicle(:user_id, :vehicle_id)"),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().first()

    if vehicle is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or no permission",
        )

    try:
        result = db.execute(
            text("SELECT car_app.fn_get_latest_odometer(:vehicle_id) as odometer_km"),
            {"vehicle_id": vehicle_id},
        ).mappings().first()
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while fetching latest odometer.",
        ) from exc

    return {
        "vehicle_id": str(vehicle_id),
        "odometer_km": float(result["odometer_km"]) if result and result["odometer_km"] else 0.0,
    }


@router.patch("/{vehicle_id}", response_model=VehicleOut)
def update_vehicle(
    vehicle_id: UUID,
    payload: VehicleUpdate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> VehicleOut:
    """
    Partial update:
    """
    existing = db.execute(
        text("SELECT * FROM fn_get_vehicle(:user_id, :vehicle_id)"),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().first()

    if existing is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found",
        )

    base = dict(existing)
    patch = payload.model_dump(exclude_unset=True)
    base.update(patch)

    params = {
        "user_id": current_user_id,
        "vehicle_id": vehicle_id,
        "name": base["name"],
        "description": base.get("description"),
        "vin": base.get("vin"),
        "plate": base.get("plate"),
        "policy_number": base.get("policy_number"),
        "model": base.get("model"),
        "production_year": base.get("production_year"),
        "dual_tank": base.get("dual_tank", False),
        "tank_capacity_l": base.get("tank_capacity_l"),
        "secondary_tank_capacity": base.get("secondary_tank_capacity"),
        "battery_capacity_kwh": base.get("battery_capacity_kwh"),
        "initial_odometer_km": base.get("initial_odometer_km"),
        "purchase_price": base.get("purchase_price"),
        "purchase_date": base.get("purchase_date"),
        "last_inspection_date": base.get("last_inspection_date"),
    }

    try:
        row = db.execute(
            text(
                """
                SELECT * FROM fn_update_vehicle(
                    :user_id,
                    :vehicle_id,
                    :name,
                    :description,
                    :vin,
                    :plate,
                    :policy_number,
                    :model,
                    :production_year,
                    :dual_tank,
                    :tank_capacity_l,
                    :secondary_tank_capacity,
                    :battery_capacity_kwh,
                    :initial_odometer_km,
                    :purchase_price,
                    :purchase_date,
                    :last_inspection_date
                )
                """
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)
        constraint = getattr(getattr(getattr(exc, "orig", None), "diag", None), "constraint_name", None)
        if pgcode == "23505":
            # unique violation
            if constraint and "vin" in constraint.lower():
                detail = "VIN already exists."
            elif constraint and ("plate" in constraint.lower() or "licence" in constraint.lower()):
                detail = "Plate number already exists."
            else:
                detail = "Unique constraint violation."
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail) from exc
        if pgcode in ("23502", "23514", "23503"):
            # not null / check / foreign key violations
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid data or constraint violation.") from exc
        if pgcode == "40001":
            # serialization failure — transient
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Transaction conflict, please retry.") from exc
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid data or constraint violation.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while updating vehicle.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if row is None:
        # ktoś usunął / zmienił ownera między SELECT a UPDATE
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or no permission",
        )

    return VehicleOut.model_validate(row)


@router.delete(
    "/{vehicle_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_vehicle(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> None:
    """
    Usuwa pojazd użytkownika (twarde DELETE).
    """
    try:
        result = db.execute(
            text("SELECT fn_delete_vehicle(:user_id, :vehicle_id) AS deleted"),
            {"user_id": current_user_id, "vehicle_id": vehicle_id},
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)
        if pgcode == "23503":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Cannot delete vehicle because related records exist.",
            ) from exc
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Constraint violation while deleting vehicle.",
        ) from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while deleting vehicle.",
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
            detail="Vehicle not found",
        )

# vehicle roles config

@router.get(
    "/{vehicle_id}/shares",
    response_model=List[VehicleShareOut],
)
def list_vehicle_shares(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[VehicleShareOut]:
    """
    Lista użytkowników współdzielących pojazd.
    Tylko OWNER danego pojazdu może ją zobaczyć.
    """
    try:
        rows = db.execute(
            text("SELECT * FROM fn_get_vehicle_shares(:actor_id, :vehicle_id)"),
            {"actor_id": current_user_id, "vehicle_id": vehicle_id},
        ).mappings().all()
    except DBAPIError as exc:
        # Database-level error
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while listing vehicle shares.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if not rows:
        # brak dostępu albo brak pojazdu – celowo 404
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or no permission",
        )

    return [VehicleShareOut.model_validate(row) for row in rows]


@router.post(
    "/{vehicle_id}/shares",
    response_model=VehicleShareOut,
    status_code=status.HTTP_201_CREATED,
)
def add_or_update_vehicle_share(
    vehicle_id: UUID,
    payload: VehicleShareCreate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> VehicleShareOut:
    """
    Dodaje nowego współdzielącego lub aktualizuje jego rolę.
    Tylko OWNER może wywołać - sprawdzane w fn_add_vehicle_share().
    """
    try:
        row = db.execute(
            text(
                """
                SELECT * FROM fn_add_vehicle_share(
                    :actor_id,
                    :vehicle_id,
                    :email,
                    :role
                )
                """
            ),
            {
                "actor_id": current_user_id,
                "vehicle_id": vehicle_id,
                "email": payload.email,
                "role": payload.role.value,
            },
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)
        # unique violation
        if pgcode == "23505":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Resource already exists or duplicate value.",
            ) from exc
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Constraint violation while adding/updating share.",
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
            detail="Database error while adding/updating share.",
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or no permission",
        )

    return VehicleShareOut.model_validate(row)


@router.patch(
    "/{vehicle_id}/shares/{user_id}",
    response_model=VehicleShareOut,
)
def update_vehicle_share_role(
    vehicle_id: UUID,
    user_id: UUID,
    payload: VehicleShareUpdate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> VehicleShareOut:
    """
    Zmiana roli współdzielącego (VIEWER <-> EDITOR).
    Tylko OWNER pojazdu.
    """
    try:
        row = db.execute(
            text(
                """
                SELECT * FROM fn_update_vehicle_share_role(
                    :actor_id,
                    :vehicle_id,
                    :target_user_id,
                    :role
                )
                """
            ),
            {
                "actor_id": current_user_id,
                "vehicle_id": vehicle_id,
                "target_user_id": user_id,
                "role": payload.role.value,
            },
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)
        if pgcode == "23505":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Duplicate value or unique constraint violation.",
            ) from exc
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while updating share.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Share not found or no permission",
        )

    return VehicleShareOut.model_validate(row)


@router.delete(
    "/{vehicle_id}/shares/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def remove_vehicle_share(
    vehicle_id: UUID,
    user_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> None:
    """
    Usunięcie użytkownika z współdzielenia.
    Tylko OWNER pojazdu.
    """
    try:
        result = db.execute(
            text(
                "SELECT fn_remove_vehicle_share(:actor_id, :vehicle_id, :target_user_id) AS deleted"
            ),
            {
                "actor_id": current_user_id,
                "vehicle_id": vehicle_id,
                "target_user_id": user_id,
            },
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)
        if pgcode == "23503":
            # foreign key violation or related records preventing delete
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Cannot remove share because related records exist.") from exc
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation while removing share.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while removing share.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if not result or not result["deleted"]:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Share not found or no permission",
        )

# vehicle fuel config

@router.get(
    "/{vehicle_id}/fuels",
    response_model=List[VehicleFuelConfigItem],
)
def get_vehicle_fuels(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[VehicleFuelConfigItem]:
    """
    Lista dozwolonych paliw dla pojazdu.
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

    rows = db.execute(
        text(
            """
            SELECT * FROM car_app.fn_get_vehicle_fuels(
                :user_id,
                :vehicle_id
            )
            """
        ),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().all()

    return [
        VehicleFuelConfigItem(
            fuel=row["fuel"],
            is_primary=row["is_primary"],
        )
        for row in rows
    ]

@router.post(
    "/{vehicle_id}/fuels",
    response_model=List[VehicleFuelConfigItem],
    status_code=status.HTTP_201_CREATED,
)
def add_vehicle_fuels(
    vehicle_id: UUID,
    payload: List[VehicleFuelConfigItem],
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[VehicleFuelConfigItem]:
    """
    Dodanie/aktualizacja konfiguracji paliw pojazdu.
    
    - body: lista obiektów { fuel, is_primary }
    - używane przy tworzeniu pojazdu lub dodawaniu nowych paliw
    """

    # Sprawdzamy czy pojazd istnieje i czy user ma do niego dostęp
    existing = db.execute(
        text("SELECT * FROM car_app.fn_get_vehicle(:user_id, :vehicle_id)"),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().first()

    if existing is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or no permission",
        )

    config = [item.model_dump() for item in payload]
    config_json = json.dumps(config)

    try:
        rows = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_add_vehicle_fuels(
                    CAST(:vehicle_id AS uuid),
                    CAST(:config AS jsonb)
                )
                """
            ),
            {
                "vehicle_id": str(vehicle_id),
                "config": config_json,
            },
        ).mappings().all()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)

        if pgcode == "23505":
            detail = "Duplicate fuel configuration."
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=detail,
            ) from exc

        if pgcode in ("23502", "23514", "23503"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid fuel configuration or constraint violation.",
            ) from exc

        if pgcode == "40001":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Transaction conflict, please retry.",
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid fuel configuration or constraint violation.",
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
            detail="Database error while adding vehicle fuels.",
        ) from exc

    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    return [
        VehicleFuelConfigItem(
            fuel=row["fuel"],
            is_primary=row["is_primary"],
        )
        for row in rows
    ]

@router.put(
    "/{vehicle_id}/fuels",
    response_model=List[VehicleFuelConfigItem],
)
def replace_vehicle_fuels(
    vehicle_id: UUID,
    payload: List[VehicleFuelConfigItem],
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[VehicleFuelConfigItem]:
    """
    Nadpisanie konfiguracji paliw pojazdu.

    - body: lista obiektów { fuel, is_primary }
    - tylko OWNER lub EDITOR (logika w fn_replace_vehicle_fuels)
    """

    # Na początek — upewniamy się, że pojazd istnieje & user ma do niego dostęp
    existing = db.execute(
        text("SELECT * FROM car_app.fn_get_vehicle(:user_id, :vehicle_id)"),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().first()

    if existing is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or no permission",
        )

    config = [item.model_dump() for item in payload]
    config_json = json.dumps(config)

    try:
        rows = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_replace_vehicle_fuels(
                    CAST(:user_id AS uuid),
                    CAST(:vehicle_id AS uuid),
                    CAST(:config AS jsonb)
                )
                """
            ),
            {
                "user_id": str(current_user_id),
                "vehicle_id": str(vehicle_id),
                "config": config_json,
            },
        ).mappings().all()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)

        if pgcode == "23505":
            # unique violation – teoretycznie vehicle_id+fuel, ale my i tak nadpisujemy
            detail = "Duplicate fuel configuration."
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=detail,
            ) from exc

        if pgcode in ("23502", "23514", "23503"):
            # not null / check / foreign key violations
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid fuel configuration or constraint violation.",
            ) from exc

        if pgcode == "40001":
            # serialization failure — transient
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Transaction conflict, please retry.",
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid fuel configuration or constraint violation.",
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
            detail="Database error while updating vehicle fuels.",
        ) from exc

    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if not rows:
        # funkcja zwróci 0 wierszy jeśli:
        # - pojazd nie istnieje (sprawdzone wyżej)
        # - lub user nie ma uprawnień (nie OWNER/EDITOR)
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No permission to modify fuels.",
        )

    return [
        VehicleFuelConfigItem(
            fuel=row["fuel"],
            is_primary=row["is_primary"],
        )
        for row in rows
    ]