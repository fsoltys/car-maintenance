from __future__ import annotations

from typing import List
from uuid import UUID
import json

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, DataError, DBAPIError

from app.api.deps import get_db, get_current_user_id
from .schemas import (
    ServiceCreate,
    ServiceUpdate,
    ServiceOut,
    ServiceItemCreate,
    ServiceItemOut,
)

router = APIRouter(prefix="/services", tags=["services"])


@router.get(
    "/vehicles/{vehicle_id}/services",
    response_model=List[ServiceOut],
)
def list_vehicle_services(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[ServiceOut]:
    """
    List all services for a vehicle.
    Available to OWNER, EDITOR, and VIEWER.
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
        rows = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_get_vehicle_services(
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
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while fetching services.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    return [ServiceOut.model_validate(row) for row in rows]


@router.get("/services/{service_id}", response_model=ServiceOut)
def get_service(
    service_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> ServiceOut:
    """
    Get a single service by ID.
    Available to users with access to the vehicle.
    """
    try:
        row = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_get_service(
                    :user_id,
                    :service_id
                )
                """
            ),
            {
                "user_id": current_user_id,
                "service_id": service_id,
            },
        ).mappings().first()
    except DataError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid service identifier.",
        ) from exc
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while fetching service.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Service not found or no permission.",
        )

    return ServiceOut.model_validate(row)


@router.post(
    "/vehicles/{vehicle_id}/services",
    response_model=ServiceOut,
    status_code=status.HTTP_201_CREATED,
)
def create_service(
    vehicle_id: UUID,
    payload: ServiceCreate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> ServiceOut:
    """
    Create a new service record for a vehicle.
    Only OWNER or EDITOR can create services.
    """
    # Check vehicle access
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
        "service_date": data["service_date"],
        "service_type": data["service_type"].value,
        "odometer_km": data.get("odometer_km"),
        "total_cost": data.get("total_cost"),
        "reference": data.get("reference"),
        "note": data.get("note"),
    }

    try:
        row = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_create_service(
                    :user_id,
                    :vehicle_id,
                    :service_date,
                    CAST(:service_type AS car_app.service_type),
                    CAST(:odometer_km AS NUMERIC),
                    CAST(:total_cost AS NUMERIC),
                    CAST(:reference AS VARCHAR),
                    CAST(:note AS TEXT)
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
                detail="Invalid service data or constraint violation.",
            ) from exc

        if pgcode == "40001":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Transaction conflict, please retry.",
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid service data or constraint violation.",
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
            detail="Database error while creating service.",
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
            detail="No permission to add service for this vehicle.",
        )

    return ServiceOut.model_validate(row)


@router.patch(
    "/services/{service_id}",
    response_model=ServiceOut,
)
def update_service(
    service_id: UUID,
    payload: ServiceUpdate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> ServiceOut:
    """
    Update a service record.
    Only OWNER or EDITOR can update services.
    """
    # Get existing service
    existing = db.execute(
        text("SELECT * FROM car_app.fn_get_service(:user_id, :service_id)"),
        {"user_id": current_user_id, "service_id": service_id},
    ).mappings().first()

    if existing is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Service not found or no permission",
        )

    # Merge with patch data
    base = dict(existing)
    patch = payload.model_dump(exclude_unset=True)
    base.update(patch)

    params = {
        "user_id": current_user_id,
        "service_id": service_id,
        "service_date": base["service_date"],
        "service_type": base["service_type"]
        if isinstance(base["service_type"], str)
        else base["service_type"].value,
        "odometer_km": base.get("odometer_km"),
        "total_cost": base.get("total_cost"),
        "reference": base.get("reference"),
        "note": base.get("note"),
    }

    try:
        row = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_update_service(
                    :user_id,
                    :service_id,
                    :service_date,
                    :service_type,
                    :odometer_km,
                    :total_cost,
                    :reference,
                    :note
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
                detail="Invalid service data or constraint violation.",
            ) from exc

        if pgcode == "40001":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Transaction conflict, please retry.",
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid service data or constraint violation.",
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
            detail="Database error while updating service.",
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
            detail="No permission to update this service.",
        )

    return ServiceOut.model_validate(row)


@router.delete(
    "/services/{service_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_service(
    service_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> None:
    """
    Delete a service record.
    Only OWNER or EDITOR can delete services.
    """
    try:
        result = db.execute(
            text(
                "SELECT car_app.fn_delete_service(:user_id, :service_id) AS deleted"
            ),
            {"user_id": current_user_id, "service_id": service_id},
        ).mappings().first()
        db.commit()
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while deleting service.",
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
            detail="Service not found or no permission",
        )


# ============================================================================
# Service Items Endpoints
# ============================================================================

@router.get(
    "/services/{service_id}/items",
    response_model=List[ServiceItemOut],
)
def list_service_items(
    service_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[ServiceItemOut]:
    """
    List all items for a service.
    Available to users with access to the service's vehicle.
    """
    try:
        rows = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_get_service_items(
                    :user_id,
                    :service_id
                )
                """
            ),
            {
                "user_id": current_user_id,
                "service_id": service_id,
            },
        ).mappings().all()
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while fetching service items.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    return [ServiceItemOut.model_validate(row) for row in rows]


@router.put(
    "/services/{service_id}/items",
    response_model=List[ServiceItemOut],
)
def set_service_items(
    service_id: UUID,
    items: List[ServiceItemCreate],
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[ServiceItemOut]:
    """
    Set service items (replaces all existing items).
    Only OWNER or EDITOR can modify service items.
    """
    # Convert items to JSON
    items_data = [item.model_dump() for item in items]
    items_json = json.dumps(items_data)

    try:
        rows = db.execute(
            text(
                """
                SELECT * FROM car_app.fn_set_service_items(
                    :user_id,
                    :service_id,
                    :items::jsonb
                )
                """
            ),
            {
                "user_id": current_user_id,
                "service_id": service_id,
                "items": items_json,
            },
        ).mappings().all()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        pgcode = getattr(getattr(exc, "orig", None), "pgcode", None)

        if pgcode == "23503":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid service reference.",
            ) from exc

        if pgcode in ("23502", "23514"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid service item data or constraint violation.",
            ) from exc

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid service item data.",
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
            detail="Database error while setting service items.",
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unexpected server error.",
        ) from exc

    if not rows:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No permission to modify service items.",
        )

    return [ServiceItemOut.model_validate(row) for row in rows]


@router.delete(
    "/services/items/{item_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_service_item(
    item_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> None:
    """
    Delete a single service item.
    Only OWNER or EDITOR can delete service items.
    """
    try:
        result = db.execute(
            text(
                "SELECT car_app.fn_delete_service_item(:user_id, :item_id) AS deleted"
            ),
            {"user_id": current_user_id, "item_id": item_id},
        ).mappings().first()
        db.commit()
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while deleting service item.",
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
            detail="Service item not found or no permission",
        )
