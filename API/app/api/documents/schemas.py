from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from typing import List
from uuid import UUID

from pydantic import BaseModel, Field


class DocumentType(str, Enum):
    INSURANCE_OC = "INSURANCE_OC"
    INSURANCE_AC = "INSURANCE_AC"
    TECH_INSPECTION = "TECH_INSPECTION"
    OTHER = "OTHER"


class DocumentBase(BaseModel):
    doc_type: DocumentType
    number: str | None = Field(default=None, max_length=64)
    provider: str | None = Field(default=None, max_length=160)
    issue_date: date | None = None
    valid_from: date | None = None
    valid_to: date | None = None
    note: str | None = None


class DocumentCreate(DocumentBase):
    pass


class DocumentUpdate(BaseModel):
    doc_type: DocumentType | None = None
    number: str | None = Field(default=None, max_length=64)
    provider: str | None = Field(default=None, max_length=160)
    issue_date: date | None = None
    valid_from: date | None = None
    valid_to: date | None = None
    note: str | None = None


class DocumentOut(BaseModel):
    id: UUID
    vehicle_id: UUID
    doc_type: DocumentType
    number: str | None = None
    provider: str | None = None
    issue_date: date | None = None
    valid_from: date | None = None
    valid_to: date | None = None
    note: str | None = None
    created_at: datetime | None = None

    class Config:
        from_attributes = True
