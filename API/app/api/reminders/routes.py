from __future__ import annotations

from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, DataError, DBAPIError

from app.api.deps import get_db, get_current_user_id
from .schemas import ReminderCreate, ReminderOut, ReminderUpdate, ReminderTrigger

router = APIRouter(tags=["reminders"])


@router.get("/vehicles/{vehicle_id}/reminders", response_model=List[ReminderOut])
def list_vehicle_reminders(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[ReminderOut]:
    """
    Lista reguł przypomnień dla pojazdu.
    """
    existing = db.execute(
        text("SELECT * FROM car_app.fn_get_vehicle(:user_id, :vehicle_id)"),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().first()

    if existing is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found or no permission")

    try:
        rows = db.execute(
            text("SELECT * FROM car_app.fn_get_vehicle_reminder_rules(:user_id, :vehicle_id)"),
            {"user_id": current_user_id, "vehicle_id": vehicle_id},
        ).mappings().all()
    except DBAPIError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while listing reminders.") from exc

    return [ReminderOut.model_validate(row) for row in rows]


@router.post("/vehicles/{vehicle_id}/reminders", response_model=ReminderOut, status_code=status.HTTP_201_CREATED)
def create_reminder(
    vehicle_id: UUID,
    payload: ReminderCreate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> ReminderOut:
    params = {
        "p_user_id": current_user_id,
        "p_vehicle_id": vehicle_id,
        "p_name": payload.name,
        "p_description": payload.description,
        "p_category": payload.category,
        "p_service_type": payload.service_type.value if payload.service_type is not None else None,
        "p_is_recurring": payload.is_recurring,
        "p_due_every_days": payload.due_every_days,
        "p_due_every_km": payload.due_every_km,
        "p_auto_reset": payload.auto_reset_on_service,
    }

    try:
        row = db.execute(
            text(
                "SELECT * FROM car_app.fn_create_reminder_rule(:p_user_id, :p_vehicle_id, :p_name, :p_description, :p_category, :p_service_type, :p_is_recurring, :p_due_every_days, :p_due_every_km, :p_auto_reset)"
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation while creating reminder.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while creating reminder.") from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found or no permission")

    return ReminderOut.model_validate(row)


@router.patch("/reminders/{reminder_id}", response_model=ReminderOut)
def update_reminder(
    reminder_id: UUID,
    payload: ReminderUpdate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> ReminderOut:
    patch = payload.model_dump(exclude_unset=True)

    params = {
        "p_user_id": current_user_id,
        "p_rule_id": reminder_id,
        "p_name": patch.get("name"),
        "p_description": patch.get("description"),
        "p_category": patch.get("category"),
        "p_service_type": patch.get("service_type").value if patch.get("service_type") is not None else None,
        "p_is_recurring": patch.get("is_recurring"),
        "p_due_every_days": patch.get("due_every_days"),
        "p_due_every_km": patch.get("due_every_km"),
        "p_status": patch.get("status"),
        "p_auto_reset": patch.get("auto_reset_on_service"),
    }

    try:
        row = db.execute(
            text(
                "SELECT * FROM car_app.fn_update_reminder_rule(:p_user_id, :p_rule_id, :p_name, :p_description, :p_category, :p_service_type, :p_is_recurring, :p_due_every_days, :p_due_every_km, :p_status, :p_auto_reset)"
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation while updating reminder.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while updating reminder.") from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reminder not found or no permission")

    return ReminderOut.model_validate(row)


@router.get("/reminders/{reminder_id}/estimate-days-until-due")
def estimate_days_until_km_reminder(
    reminder_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """
    Estimate how many days until a kilometer-based reminder is due.
    Returns estimated days based on historical odometer usage patterns.
    """
    # First verify the user has access to this reminder
    reminder = db.execute(
        text("""
            SELECT r.* FROM car_app.reminder_rules r
            JOIN car_app.vehicles v ON v.id = r.vehicle_id
            LEFT JOIN car_app.vehicle_shares s ON s.vehicle_id = v.id AND s.user_id = :user_id
            WHERE r.id = :reminder_id
              AND (v.owner_id = :user_id OR s.user_id IS NOT NULL)
        """),
        {"user_id": current_user_id, "reminder_id": reminder_id},
    ).mappings().first()

    if reminder is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reminder not found or no permission")

    if reminder["next_due_odometer_km"] is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This reminder does not have a kilometer-based interval"
        )

    try:
        result = db.execute(
            text("""
                SELECT car_app.fn_estimate_days_until_km_reminder(
                    :vehicle_id,
                    :next_due_odometer_km
                ) as estimated_days
            """),
            {
                "vehicle_id": reminder["vehicle_id"],
                "next_due_odometer_km": reminder["next_due_odometer_km"],
            },
        ).mappings().first()
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while estimating days until due."
        ) from exc

    estimated_days = result["estimated_days"] if result else None

    return {
        "reminder_id": str(reminder_id),
        "next_due_odometer_km": float(reminder["next_due_odometer_km"]),
        "estimated_days": estimated_days,
    }


@router.post("/reminders/{reminder_id}/check-due-soon")
def check_reminder_due_soon(
    reminder_id: UUID,
    days_threshold: int = 7,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """
    Check if a reminder is due soon (within days_threshold).
    Considers both date-based and kilometer-based (estimated) reminders.
    Use days_threshold=7 for DUE status, days_threshold=30 for upcoming reminders.
    """
    # First verify the user has access to this reminder
    reminder = db.execute(
        text("""
            SELECT r.* FROM car_app.reminder_rules r
            JOIN car_app.vehicles v ON v.id = r.vehicle_id
            LEFT JOIN car_app.vehicle_shares s ON s.vehicle_id = v.id AND s.user_id = :user_id
            WHERE r.id = :reminder_id
              AND (v.owner_id = :user_id OR s.user_id IS NOT NULL)
        """),
        {"user_id": current_user_id, "reminder_id": reminder_id},
    ).mappings().first()

    if reminder is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reminder not found or no permission")

    try:
        result = db.execute(
            text("""
                SELECT car_app.fn_is_reminder_due_soon(
                    :reminder_id,
                    :days_threshold
                ) as is_due_soon
            """),
            {
                "reminder_id": reminder_id,
                "days_threshold": days_threshold,
            },
        ).mappings().first()
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while checking reminder due status."
        ) from exc

    is_due_soon = result["is_due_soon"] if result else False

    return {
        "reminder_id": str(reminder_id),
        "is_due_soon": is_due_soon,
        "days_threshold": days_threshold,
    }


@router.delete("/reminders/{reminder_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_reminder(
    reminder_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> None:
    try:
        result = db.execute(
            text("SELECT car_app.fn_delete_reminder_rule(:p_user_id, :p_rule_id) AS deleted"),
            {"p_user_id": current_user_id, "p_rule_id": reminder_id},
        ).mappings().first()
        db.commit()
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while deleting reminder.") from exc

    if not result or not result["deleted"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reminder not found or no permission")

    return None


@router.post("/reminders/{reminder_id}/renew", response_model=ReminderOut)
def renew_reminder(
    reminder_id: UUID,
    payload: ReminderTrigger,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> ReminderOut:
    """
    Wywołuje `fn_trigger_reminder` — loguje zdarzenie przypomnienia i przesuwa wartości next_due_*.
    Użyte do akcji "Renew" z powiadomień push.
    """
    params = {
        "p_user_id": current_user_id,
        "p_rule_id": reminder_id,
        "p_reason": payload.reason,
        "p_odometer": payload.odometer,
    }

    try:
        row = db.execute(
            text("SELECT * FROM car_app.fn_trigger_reminder(:p_user_id, :p_rule_id, CAST(:p_reason AS VARCHAR), CAST(:p_odometer AS NUMERIC))"),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation while triggering reminder.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while triggering reminder.") from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reminder not found or no permission")

    return ReminderOut.model_validate(row)
