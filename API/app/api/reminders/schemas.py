from __future__ import annotations

from datetime import datetime, date
from enum import Enum
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class ServiceType(str, Enum):
    INSPECTION = "INSPECTION"
    OIL_CHANGE = "OIL_CHANGE"
    FILTERS = "FILTERS"
    BRAKES = "BRAKES"
    TIRES = "TIRES"
    BATTERY = "BATTERY"
    ENGINE = "ENGINE"
    TRANSMISSION = "TRANSMISSION"
    SUSPENSION = "SUSPENSION"
    OTHER = "OTHER"


class ReminderBase(BaseModel):
    name: str = Field(..., max_length=160)
    description: Optional[str] = None
    category: Optional[str] = None
    service_type: Optional[ServiceType] = None
    is_recurring: Optional[bool] = True
    due_every_days: Optional[int] = None
    due_every_km: Optional[int] = None
    auto_reset_on_service: Optional[bool] = False


class ReminderCreate(ReminderBase):
    pass


class ReminderUpdate(BaseModel):
    name: Optional[str] = Field(default=None, max_length=160)
    description: Optional[str] = None
    category: Optional[str] = None
    service_type: Optional[ServiceType] = None
    is_recurring: Optional[bool] = None
    due_every_days: Optional[int] = None
    due_every_km: Optional[int] = None
    status: Optional[str] = None
    auto_reset_on_service: Optional[bool] = None


class ReminderOut(BaseModel):
    id: UUID
    vehicle_id: UUID
    name: str
    description: Optional[str] = None
    category: Optional[str] = None
    service_type: Optional[ServiceType] = None
    is_recurring: Optional[bool] = True
    due_every_days: Optional[int] = None
    due_every_km: Optional[int] = None
    last_reset_at: Optional[datetime] = None
    last_reset_odometer_km: Optional[float] = None
    next_due_date: Optional[date] = None
    next_due_odometer_km: Optional[float] = None
    status: Optional[str] = None
    auto_reset_on_service: Optional[bool] = False
    estimated_days_until_due: Optional[int] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ReminderTrigger(BaseModel):
    reason: Optional[str] = None
    odometer: Optional[float] = None
