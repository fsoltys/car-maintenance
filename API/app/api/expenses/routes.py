from __future__ import annotations

from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import text
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, DataError, DBAPIError

from app.api.deps import get_db, get_current_user_id
from .schemas import ExpenseCreate, ExpenseOut, ExpenseUpdate, ExpenseSummary


router = APIRouter(tags=["expenses"])


@router.get("/vehicles/{vehicle_id}/expenses", response_model=List[ExpenseOut])
def list_expenses(
    vehicle_id: UUID,
    from_date: str | None = Query(default=None),
    to_date: str | None = Query(default=None),
    category: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> list[ExpenseOut]:
    try:
        rows = db.execute(
            text(
                "SELECT * FROM car_app.fn_get_vehicle_expenses(:actor_id, :vehicle_id, :p_from::date, :p_to::date, :p_category)"
            ),
            {"actor_id": current_user_id, "vehicle_id": vehicle_id, "p_from": from_date, "p_to": to_date, "p_category": category},
        ).mappings().all()
    except DBAPIError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while listing expenses.") from exc
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    return [ExpenseOut.model_validate(row) for row in rows]


@router.post("/vehicles/{vehicle_id}/expenses", response_model=ExpenseOut, status_code=status.HTTP_201_CREATED)
def create_expense(
    vehicle_id: UUID,
    payload: ExpenseCreate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> ExpenseOut:
    params = {
        "p_user_id": current_user_id,
        "p_vehicle_id": vehicle_id,
        "p_expense_date": payload.expense_date,
        "p_category": payload.category.value,
        "p_amount": payload.amount,
        "p_vat_rate": payload.vat_rate,
        "p_note": payload.note,
    }

    try:
        row = db.execute(
            text(
                "SELECT * FROM car_app.fn_create_expense(:p_user_id, :p_vehicle_id, :p_expense_date, CAST(:p_category AS TEXT), CAST(:p_amount AS NUMERIC(12,2)), CAST(:p_vat_rate AS NUMERIC), CAST(:p_note AS TEXT))"
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation while creating expense.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while creating expense.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found or no permission")

    return ExpenseOut.model_validate(row)


@router.patch("/expenses/{expense_id}", response_model=ExpenseOut)
def update_expense(
    expense_id: UUID,
    payload: ExpenseUpdate,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> ExpenseOut:
    patch = payload.model_dump(exclude_unset=True)

    params = {
        "p_user_id": current_user_id,
        "p_expense_id": expense_id,
        "p_expense_date": patch.get("expense_date", None),
        "p_category": patch.get("category", None).value if patch.get("category", None) is not None else None,
        "p_amount": patch.get("amount", None),
        "p_vat_rate": patch.get("vat_rate", None),
        "p_note": patch.get("note", None),
    }

    try:
        row = db.execute(
            text(
                "SELECT * FROM car_app.fn_update_expense(:p_user_id, :p_expense_id, :p_expense_date, :p_category, :p_amount, :p_vat_rate, :p_note)"
            ),
            params,
        ).mappings().first()
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Constraint violation while updating expense.") from exc
    except DataError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid input data.") from exc
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while updating expense.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Expense not found or no permission")

    return ExpenseOut.model_validate(row)


@router.delete("/expenses/{expense_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_expense(
    expense_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> None:
    try:
        result = db.execute(
            text("SELECT car_app.fn_delete_expense(:p_user_id, :p_expense_id) AS deleted"),
            {"p_user_id": current_user_id, "p_expense_id": expense_id},
        ).mappings().first()
        db.commit()
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while deleting expense.") from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if not result or not result["deleted"]:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Expense not found or no permission")

    return None


@router.get("/vehicles/{vehicle_id}/expenses/summary", response_model=ExpenseSummary)
def get_expenses_summary(
    vehicle_id: UUID,
    from_date: str | None = Query(default=None),
    to_date: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> ExpenseSummary:
    try:
        row = db.execute(
            text(
                "SELECT * FROM car_app.fn_get_vehicle_expenses_summary(:actor_id, :vehicle_id, :p_from::date, :p_to::date)"
            ),
            {"actor_id": current_user_id, "vehicle_id": vehicle_id, "p_from": from_date, "p_to": to_date},
        ).mappings().first()
    except DBAPIError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Database error while fetching expenses summary.") from exc
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Unexpected server error.") from exc

    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found or no permission")

    # row contains columns: total_amount, period_km, cost_per_100km, per_category (jsonb), monthly_series (jsonb)
    return ExpenseSummary(
        total_amount=float(row["total_amount"]) if row["total_amount"] is not None else None,
        period_km=float(row["period_km"]) if row["period_km"] is not None else None,
        cost_per_100km=float(row["cost_per_100km"]) if row["cost_per_100km"] is not None else None,
        per_category=row["per_category"],
        monthly_series=row["monthly_series"],
    )
