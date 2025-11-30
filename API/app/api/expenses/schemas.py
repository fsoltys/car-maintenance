from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from typing import List
from uuid import UUID

from pydantic import BaseModel, Field


class ExpenseCategory(str, Enum):
    FUEL = "FUEL"
    SERVICE = "SERVICE"
    INSURANCE = "INSURANCE"
    TAX = "TAX"
    TOLLS = "TOLLS"
    PARKING = "PARKING"
    ACCESSORIES = "ACCESSORIES"
    WASH = "WASH"
    OTHER = "OTHER"


class ExpenseBase(BaseModel):
    expense_date: date
    category: ExpenseCategory
    amount: float
    vat_rate: float | None = None
    note: str | None = None


class ExpenseCreate(ExpenseBase):
    pass


class ExpenseUpdate(BaseModel):
    expense_date: date | None = None
    category: ExpenseCategory | None = None
    amount: float | None = None
    vat_rate: float | None = None
    note: str | None = None


class ExpenseOut(BaseModel):
    id: UUID
    vehicle_id: UUID
    user_id: UUID
    expense_date: date
    category: ExpenseCategory
    amount: float
    vat_rate: float | None = None
    note: str | None = None
    created_at: datetime | None = None

    class Config:
        from_attributes = True


class ExpenseSummary(BaseModel):
    total_amount: float | None = None
    period_km: float | None = None
    cost_per_100km: float | None = None
    per_category: dict | None = None
    monthly_series: list | None = None
