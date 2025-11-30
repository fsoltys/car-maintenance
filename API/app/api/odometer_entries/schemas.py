from __future__ import annotations

from datetime import datetime
from typing import List
from uuid import UUID

from pydantic import BaseModel, Field


class OdometerEntryCreate(BaseModel):
    entry_date: datetime
    value_km: float = Field(..., ge=0)
    note: str | None = None


class OdometerEntryOut(BaseModel):
    id: UUID
    vehicle_id: UUID
    entry_date: datetime
    value_km: float
    note: str | None = None

    class Config:
        from_attributes = True


class OdometerHistoryItem(BaseModel):
    event_id: UUID
    event_type: str
    source_id: UUID
    event_date: datetime
    odometer_km: float
    note: str | None = None
    source_user_id: UUID | None = None

    class Config:
        from_attributes = True
