from __future__ import annotations

from typing import List
from uuid import UUID
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import text
from sqlalchemy.orm import Session
from sqlalchemy.exc import DBAPIError

from app.api.deps import get_db, get_current_user_id
from .schemas import (
    MonthlyBudgetForecast,
    BudgetForecastResponse,
    BudgetStatistics,
    ScheduledServiceDetail,
)


router = APIRouter(prefix="/vehicles/{vehicle_id}/budget", tags=["budget"])


@router.get("/forecast", response_model=BudgetForecastResponse)
def get_budget_forecast(
    vehicle_id: UUID,
    months_ahead: int = Query(default=6, ge=1, le=24, description="Number of months to forecast"),
    include_irregular: bool = Query(default=False, description="Include buffer for irregular expenses"),
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> BudgetForecastResponse:
    """
    Get budget forecast for the vehicle.
    
    This endpoint predicts future monthly expenses based on:
    - Historical regular expenses (12-month average)
    - Scheduled maintenance from service rules
    - Optional buffer for irregular/unexpected expenses
    
    The forecast uses intelligent classification to exclude large one-time expenses
    from regular cost predictions while including them in the buffer calculation.
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
    
    # Get average monthly mileage for context
    try:
        avg_mileage = db.execute(
            text("SELECT car_app.fn_get_avg_monthly_mileage(:vehicle_id)"),
            {"vehicle_id": vehicle_id}
        ).scalar()
        avg_mileage = float(avg_mileage) if avg_mileage else 0.0
    except Exception:
        avg_mileage = 0.0
    
    # Get budget forecast
    try:
        rows = db.execute(
            text("""
                SELECT 
                    month,
                    regular_costs,
                    scheduled_maintenance,
                    scheduled_maintenance_details,
                    irregular_buffer,
                    total_predicted,
                    confidence_level
                FROM car_app.fn_predict_monthly_budget(
                    :vehicle_id,
                    :months_ahead,
                    :include_irregular
                )
            """),
            {
                "vehicle_id": vehicle_id,
                "months_ahead": months_ahead,
                "include_irregular": include_irregular,
            }
        ).mappings().all()
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Database error while fetching budget forecast: {str(exc)}"
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unexpected error: {str(exc)}"
        ) from exc
    
    # Parse results
    forecasts = []
    for row in rows:
        # Parse scheduled maintenance details from JSONB
        details_json = row['scheduled_maintenance_details']
        scheduled_details = []
        
        if details_json:
            for detail in details_json:
                scheduled_details.append(
                    ScheduledServiceDetail(
                        rule_id=detail['rule_id'],
                        name=detail['name'],
                        cost=float(detail['cost']),
                        date=detail['date'],
                        confidence=detail['confidence']
                    )
                )
        
        forecasts.append(
            MonthlyBudgetForecast(
                month=row['month'],
                regular_costs=float(row['regular_costs']),
                scheduled_maintenance=float(row['scheduled_maintenance']),
                scheduled_maintenance_details=scheduled_details,
                irregular_buffer=float(row['irregular_buffer']),
                total_predicted=float(row['total_predicted']),
                confidence_level=row['confidence_level']
            )
        )
    
    return BudgetForecastResponse(
        vehicle_id=vehicle_id,
        forecast_months=months_ahead,
        include_irregular=include_irregular,
        avg_monthly_mileage=avg_mileage,
        forecasts=forecasts
    )


@router.get("/statistics", response_model=BudgetStatistics)
def get_budget_statistics(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> BudgetStatistics:
    """
    Get budget statistics for the vehicle (last 12 months).
    
    Provides insights into spending patterns, including:
    - Total and average regular expenses
    - Total and average irregular expenses
    - Largest single expense
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
    
    # Get statistics
    try:
        stats = db.execute(
            text("""
                WITH monthly_stats AS (
                    SELECT 
                        DATE_TRUNC('month', expense_date) as month,
                        SUM(CASE WHEN expense_type = 'REGULAR' THEN amount ELSE 0 END) as monthly_regular,
                        SUM(CASE WHEN expense_type IN ('IRREGULAR_MEDIUM', 'IRREGULAR_LARGE') THEN amount ELSE 0 END) as monthly_irregular,
                        MAX(amount) as largest_amount
                    FROM car_app.expenses
                    WHERE vehicle_id = :vehicle_id
                      AND expense_date >= CURRENT_DATE - INTERVAL '12 months'
                    GROUP BY DATE_TRUNC('month', expense_date)
                )
                SELECT 
                    (SELECT COALESCE(SUM(amount), 0) FROM car_app.expenses 
                     WHERE vehicle_id = :vehicle_id 
                     AND expense_type = 'REGULAR' 
                     AND expense_date >= CURRENT_DATE - INTERVAL '12 months') as total_regular,
                    (SELECT COALESCE(SUM(amount), 0) FROM car_app.expenses 
                     WHERE vehicle_id = :vehicle_id 
                     AND expense_type IN ('IRREGULAR_MEDIUM', 'IRREGULAR_LARGE')
                     AND expense_date >= CURRENT_DATE - INTERVAL '12 months') as total_irregular,
                    ROUND(COALESCE(AVG(monthly_regular), 0)) as avg_regular,
                    ROUND(COALESCE(SUM(monthly_irregular) / GREATEST(COUNT(*) FILTER (WHERE monthly_irregular > 0), 1), 0) * 0.15) as avg_irregular,
                    MAX(largest_amount) as largest_expense,
                    (SELECT category FROM car_app.expenses e2 
                     WHERE e2.vehicle_id = :vehicle_id 
                     AND e2.expense_date >= CURRENT_DATE - INTERVAL '12 months'
                     ORDER BY amount DESC LIMIT 1) as largest_category
                FROM monthly_stats
            """),
            {"vehicle_id": vehicle_id}
        ).mappings().first()
        
        return BudgetStatistics(
            total_regular_last_12m=float(stats['total_regular']),
            total_irregular_last_12m=float(stats['total_irregular']),
            avg_monthly_regular=float(stats['avg_regular']),
            avg_monthly_irregular=float(stats['avg_irregular']),
            largest_expense_last_12m=float(stats['largest_expense']) if stats['largest_expense'] else None,
            largest_expense_category=stats['largest_category']
        )
    except DBAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while fetching statistics"
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unexpected error: {str(exc)}"
        ) from exc


@router.post("/classify-expenses", status_code=status.HTTP_200_OK)
def classify_vehicle_expenses(
    vehicle_id: UUID,
    db: Session = Depends(get_db),
    current_user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """
    Manually trigger classification of expenses for this vehicle.
    
    This endpoint runs the expense classification algorithm to categorize
    expenses as REGULAR, IRREGULAR_MEDIUM, or IRREGULAR_LARGE based on
    statistical analysis (3-sigma rule).
    
    Useful after importing bulk data or when you want to refresh classifications.
    """
    # Verify user has access to this vehicle (OWNER or EDITOR required for modifications)
    existing = db.execute(
        text("SELECT * FROM car_app.fn_get_vehicle(:user_id, :vehicle_id)"),
        {"user_id": current_user_id, "vehicle_id": vehicle_id},
    ).mappings().first()

    if existing is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or no permission",
        )
    
    # Run classification
    try:
        result = db.execute(
            text("""
                UPDATE car_app.expenses e
                SET expense_type = car_app.fn_classify_expense_type(e.vehicle_id, e.category, e.amount)
                WHERE e.vehicle_id = :vehicle_id
                RETURNING expense_id, expense_type
            """),
            {"vehicle_id": vehicle_id}
        ).mappings().all()
        
        db.commit()
        
        # Count by type
        regular_count = sum(1 for r in result if r['expense_type'] == 'REGULAR')
        irregular_medium_count = sum(1 for r in result if r['expense_type'] == 'IRREGULAR_MEDIUM')
        irregular_large_count = sum(1 for r in result if r['expense_type'] == 'IRREGULAR_LARGE')
        
        return {
            "message": "Expenses classified successfully",
            "total_classified": len(result),
            "regular": regular_count,
            "irregular_medium": irregular_medium_count,
            "irregular_large": irregular_large_count
        }
    except DBAPIError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Database error while classifying expenses"
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unexpected error: {str(exc)}"
        ) from exc
