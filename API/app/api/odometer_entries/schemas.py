from __future__ import annotations

from datetime import datetime
from typing import List
from uuid import UUID

from pydantic import BaseModel, Field, field_serializer


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
        # Use custom field names for JSON serialization
        populate_by_name = True

    @field_serializer('event_date')
    def serialize_event_date(self, value: datetime, _info):
        # Rename event_date to timestamp in JSON
        return value

    @field_serializer('event_type')
    def serialize_event_type(self, value: str, _info):
        # Convert to lowercase for JSON
        return value.lower()

    def model_dump(self, **kwargs):
        """Custom serialization to match Flutter expectations"""
        data = super().model_dump(**kwargs)
        # Rename fields for Flutter
        return {
            'timestamp': data['event_date'],
            'source': data['event_type'],  # Already lowercased by field_serializer
            'source_id': str(data['source_id']),
            'odometer_km': data['odometer_km'],
        }

