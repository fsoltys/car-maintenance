from __future__ import annotations

from typing import Literal
from uuid import UUID
from datetime import date
import csv
from io import StringIO

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user_id

router = APIRouter(prefix="/vehicles/{vehicle_id}/export", tags=["export"])


@router.get("/{data_type}")
def export_vehicle_data(
    vehicle_id: UUID,
    data_type: Literal["fuelings", "services", "expenses", "odometer"],
    start_date: date,
    end_date: date,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """
    Export vehicle data as CSV.
    
    Supported data types:
    - fuelings: Fuel entries with consumption, price, odometer
    - services: Service records with type, cost, odometer
    - expenses: All expenses with category, amount, date
    - odometer: Odometer readings history
    """
    # Verify user has access to this vehicle
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
        if data_type == "fuelings":
            csv_data = _export_fuelings(db, vehicle_id, start_date, end_date)
        elif data_type == "services":
            csv_data = _export_services(db, vehicle_id, start_date, end_date)
        elif data_type == "expenses":
            csv_data = _export_expenses(db, vehicle_id, start_date, end_date)
        elif data_type == "odometer":
            csv_data = _export_odometer(db, vehicle_id, start_date, end_date)
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported data type: {data_type}",
            )

        return {"csv_data": csv_data}

    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Export failed: {str(exc)}",
        ) from exc


def _export_fuelings(db: Session, vehicle_id: UUID, start_date: date, end_date: date) -> str:
    """Export fuel entries to CSV"""
    rows = db.execute(
        text("""
            SELECT 
                filled_at AT TIME ZONE 'UTC' as "Date & Time",
                odometer_km as "Odometer (km)",
                volume as "Volume (L)",
                price_per_unit as "Price per Unit",
                (volume * price_per_unit) as "Total Cost",
                fuel::text as "Fuel Type",
                driving_cycle::text as "Driving Cycle",
                full_tank as "Full Tank",
                note as "Note"
            FROM car_app.fuelings
            WHERE vehicle_id = :vehicle_id
              AND filled_at::date BETWEEN :start_date AND :end_date
            ORDER BY filled_at DESC
        """),
        {"vehicle_id": vehicle_id, "start_date": start_date, "end_date": end_date}
    ).mappings().all()

    return _rows_to_csv(rows)


def _export_services(db: Session, vehicle_id: UUID, start_date: date, end_date: date) -> str:
    """Export service records to CSV"""
    rows = db.execute(
        text("""
            SELECT 
                service_date as "Service Date",
                service_type::text as "Service Type",
                odometer_km as "Odometer (km)",
                total_cost as "Total Cost",
                reference as "Reference/Invoice",
                note as "Note"
            FROM car_app.services
            WHERE vehicle_id = :vehicle_id
              AND service_date BETWEEN :start_date AND :end_date
            ORDER BY service_date DESC
        """),
        {"vehicle_id": vehicle_id, "start_date": start_date, "end_date": end_date}
    ).mappings().all()

    return _rows_to_csv(rows)


def _export_expenses(db: Session, vehicle_id: UUID, start_date: date, end_date: date) -> str:
    """Export expenses to CSV"""
    rows = db.execute(
        text("""
            SELECT 
                expense_date as "Expense Date",
                category::text as "Category",
                amount as "Amount",
                expense_type as "Type",
                note as "Note"
            FROM car_app.expenses
            WHERE vehicle_id = :vehicle_id
              AND expense_date BETWEEN :start_date AND :end_date
            ORDER BY expense_date DESC
        """),
        {"vehicle_id": vehicle_id, "start_date": start_date, "end_date": end_date}
    ).mappings().all()

    return _rows_to_csv(rows)


def _export_odometer(db: Session, vehicle_id: UUID, start_date: date, end_date: date) -> str:
    """Export odometer history to CSV"""
    rows = db.execute(
        text("""
            SELECT 
                filled_at AT TIME ZONE 'UTC' as "Date & Time",
                odometer_km as "Odometer (km)",
                fuel::text as "Source"
            FROM car_app.fuelings
            WHERE vehicle_id = :vehicle_id
              AND filled_at::date BETWEEN :start_date AND :end_date
            ORDER BY filled_at DESC
        """),
        {"vehicle_id": vehicle_id, "start_date": start_date, "end_date": end_date}
    ).mappings().all()

    return _rows_to_csv(rows)


def _rows_to_csv(rows: list) -> str:
    """Convert database rows to CSV string"""
    if not rows:
        return ""

    output = StringIO()
    writer = csv.DictWriter(output, fieldnames=rows[0].keys())
    
    writer.writeheader()
    for row in rows:
        # Convert any non-string values to strings
        row_dict = {k: str(v) if v is not None else '' for k, v in row.items()}
        writer.writerow(row_dict)
    
    return output.getvalue()
