from __future__ import annotations

from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, Field, EmailStr

from enum import Enum



class VehicleBase(BaseModel):
    name: str = Field(max_length=120)
    description: str | None = None

    vin: str | None = Field(default=None, max_length=32)
    plate: str | None = Field(default=None, max_length=32)
    policy_number: str | None = Field(default=None, max_length=64)
    model: str | None = Field(default=None, max_length=120)

    production_year: int | None = None
    dual_tank: bool = False
    tank_capacity_l: float | None = None
    secondary_tank_capacity: float | None = None
    battery_capacity_kwh: float | None = None
    initial_odometer_km: float | None = None

    purchase_price: float | None = None
    purchase_date: date | None = None
    last_inspection_date: date | None = None


class VehicleCreate(VehicleBase):
    """Payload do tworzenia pojazdu."""


class VehicleUpdate(BaseModel):
    """
    Partial update - wszystkie pola opcjonalne.
    """
    name: str | None = Field(default=None, max_length=120)
    description: str | None = None

    vin: str | None = Field(default=None, max_length=32)
    plate: str | None = Field(default=None, max_length=32)
    policy_number: str | None = Field(default=None, max_length=64)
    model: str | None = Field(default=None, max_length=120)

    production_year: int | None = None
    dual_tank: bool | None = None
    tank_capacity_l: float | None = None
    secondary_tank_capacity: float | None = None
    battery_capacity_kwh: float | None = None
    initial_odometer_km: float | None = None

    purchase_price: float | None = None
    purchase_date: date | None = None
    last_inspection_date: date | None = None


class VehicleOut(VehicleBase):
    id: UUID
    owner_id: UUID
    created_at: datetime | None = None
    updated_at: datetime | None = None
    user_role: str | None = None  # OWNER, EDITOR, VIEWER


class VehicleShareRole(str, Enum):
    OWNER = "OWNER"
    EDITOR = "EDITOR"
    VIEWER = "VIEWER"


class VehicleShareOut(BaseModel):
    user_id: UUID
    email: EmailStr
    display_name: str | None = None
    role: VehicleShareRole
    invited_at: datetime | None = None
    is_owner: bool = False


class VehicleShareCreate(BaseModel):
    email: EmailStr
    role: VehicleShareRole


class VehicleShareUpdate(BaseModel):
    role: VehicleShareRole


class FuelType(str, Enum):
    Petrol = "Petrol"
    Diesel = "Diesel"
    LPG = "LPG"
    CNG = "CNG"
    EV = "EV"
    H2 = "H2"


class VehicleFuelConfigItem(BaseModel):
    fuel: FuelType
    is_primary: bool = False


class DrivingCycle(str, Enum):
    CITY = "CITY"
    HIGHWAY = "HIGHWAY"
    MIX = "MIX"


class FuelingBase(BaseModel):
    filled_at: datetime
    price_per_unit: float = Field(gt=0)
    volume: float = Field(gt=0)
    odometer_km: float = Field(gt=0)
    full_tank: bool
    driving_cycle: DrivingCycle | None = None
    fuel: FuelType
    note: str | None = None
    fuel_level_before: float | None = Field(default=None, ge=0, le=100)
    fuel_level_after: float | None = Field(default=None, ge=0, le=100)


class FuelingCreate(FuelingBase):
    """Payload tworzenia tankowania."""


class FuelingUpdate(BaseModel):
    """Partial update - wszystkie pola opcjonalne."""
    filled_at: datetime | None = None
    price_per_unit: float | None = Field(default=None, gt=0)
    volume: float | None = Field(default=None, gt=0)
    odometer_km: float | None = Field(default=None, gt=0)
    full_tank: bool | None = None
    driving_cycle: DrivingCycle | None = None
    fuel: FuelType | None = None
    note: str | None = None
    fuel_level_before: float | None = Field(default=None, ge=0, le=100)
    fuel_level_after: float | None = Field(default=None, ge=0, le=100)


class FuelingOut(FuelingBase):
    id: UUID
    vehicle_id: UUID
    user_id: UUID
    created_at: datetime | None = None
