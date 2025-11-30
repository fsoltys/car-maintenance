from __future__ import annotations

from typing import List
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user_id
from .schemas import (
    VehicleCreate,
    VehicleUpdate,
    VehicleOut,
    VehicleShareOut,
    VehicleShareCreate,
    VehicleShareUpdate,
)


router = APIRouter(prefix="/vehicles", tags=["vehicles"])


@router.get("/", response_model=List[VehicleOut])
def list_vehicles(
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[VehicleOut]:
    """
    Lista pojazdów zalogowanego użytkownika (owner + shared).
    """
    rows = db.execute(
        text("SELECT * FROM fn_get_user_vehicles(:user_id)"),
        {"user_id": current_user_id},
    ).mappings().all()

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
        "tank_capacity_l": data.get("tank_capacity_l"),
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
                    :tank_capacity_l,
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
    except Exception as exc:
        db.rollback()
        # TODO (optional): bardziej szczegółowe błędy (np. unikalność VIN/plate)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not create vehicle",
        ) from exc

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
        "tank_capacity_l": base.get("tank_capacity_l"),
        "battery_capacity_kwh": base.get("battery_capacity_kwh"),
        "initial_odometer_km": base.get("initial_odometer_km"),
        "purchase_price": base.get("purchase_price"),
        "purchase_date": base.get("purchase_date"),
        "last_inspection_date": base.get("last_inspection_date"),
    }

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
                :tank_capacity_l,
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
    result = db.execute(
        text("SELECT fn_delete_vehicle(:user_id, :vehicle_id) AS deleted"),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().first()

    db.commit()

    if not result or not result["deleted"]:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found",
        )

# ======= SHARES / ROLES =======

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
    rows = db.execute(
        text("SELECT * FROM fn_get_vehicle_shares(:actor_id, :vehicle_id)"),
        {"actor_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().all()

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
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not add or update vehicle share",
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

    if not result or not result["deleted"]:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Share not found or no permission",
        )