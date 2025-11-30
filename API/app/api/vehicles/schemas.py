from __future__ import annotations

from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, Field

from enum import Enum
from pydantic import EmailStr



class VehicleBase(BaseModel):
    name: str = Field(max_length=120)
    description: str | None = None

    vin: str | None = Field(default=None, max_length=32)
    plate: str | None = Field(default=None, max_length=32)
    policy_number: str | None = Field(default=None, max_length=64)
    model: str | None = Field(default=None, max_length=120)

    production_year: int | None = None
    tank_capacity_l: float | None = None
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
    tank_capacity_l: float | None = None
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

class VehicleShareRole(str, Enum):
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
    PB95 = "PB95"
    PB98 = "PB98"
    ON = "ON"
    LPG = "LPG"
    CNG = "CNG"
    EV = "EV"
    H2 = "H2"


class VehicleFuelConfigItem(BaseModel):
    fuel: FuelType
    is_primary: bool = False