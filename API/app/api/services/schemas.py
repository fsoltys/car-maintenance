from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from uuid import UUID
from typing import List

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


class ServiceItemBase(BaseModel):
    part_name: str | None = Field(default=None, max_length=160)
    part_number: str | None = Field(default=None, max_length=80)
    quantity: float | None = Field(default=None, ge=0)
    unit_price: float | None = Field(default=None, ge=0)


class ServiceItemCreate(ServiceItemBase):
    pass


class ServiceItemOut(BaseModel):
    id: UUID
    service_id: UUID
    part_name: str | None = None
    part_number: str | None = None
    quantity: float | None = None
    unit_price: float | None = None

    class Config:
        from_attributes = True


class ServiceBase(BaseModel):
    service_date: date
    service_type: ServiceType
    odometer_km: float | None = Field(default=None, ge=0)
    total_cost: float | None = Field(default=None, ge=0)
    reference: str | None = Field(default=None, max_length=64)
    note: str | None = None


class ServiceCreate(ServiceBase):
    pass


class ServiceUpdate(BaseModel):
    service_date: date | None = None
    service_type: ServiceType | None = None
    odometer_km: float | None = Field(default=None, ge=0)
    total_cost: float | None = Field(default=None, ge=0)
    reference: str | None = Field(default=None, max_length=64)
    note: str | None = None


class ServiceOut(BaseModel):
    id: UUID
    vehicle_id: UUID
    user_id: UUID
    service_date: date
    service_type: ServiceType
    odometer_km: float | None = None
    total_cost: float | None = None
    reference: str | None = None
    note: str | None = None
    created_at: datetime | None = None

    class Config:
        from_attributes = True
