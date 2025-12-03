from __future__ import annotations

from datetime import date
from uuid import UUID
from pydantic import BaseModel, Field


class ScheduledServiceDetail(BaseModel):
    """Detail of a scheduled service in budget forecast"""
    rule_id: UUID
    name: str
    cost: float
    date: date
    confidence: str = Field(
        description="Confidence level: LOW, MEDIUM, HIGH"
    )


class MonthlyBudgetForecast(BaseModel):
    """Budget forecast for a single month"""
    month: date
    regular_costs: float = Field(
        description="Average monthly costs for regular expenses"
    )
    scheduled_maintenance: float = Field(
        description="Total cost of scheduled maintenance services"
    )
    scheduled_maintenance_details: list[ScheduledServiceDetail] = Field(
        default_factory=list,
        description="Details of scheduled services for this month"
    )
    irregular_buffer: float = Field(
        description="Buffer for unexpected expenses"
    )
    total_predicted: float = Field(
        description="Total predicted cost for the month"
    )
    confidence_level: str = Field(
        description="Confidence level for this forecast: LOW, MEDIUM, HIGH"
    )


class BudgetForecastResponse(BaseModel):
    """Complete budget forecast response"""
    vehicle_id: UUID
    forecast_months: int
    include_irregular: bool
    avg_monthly_mileage: float
    forecasts: list[MonthlyBudgetForecast]


class BudgetStatistics(BaseModel):
    """Statistics about budget and expenses"""
    total_regular_last_12m: float
    total_irregular_last_12m: float
    avg_monthly_regular: float
    avg_monthly_irregular: float
    largest_expense_last_12m: float | None
    largest_expense_category: str | None
