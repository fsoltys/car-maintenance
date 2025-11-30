from __future__ import annotations

from datetime import datetime
from typing import List
from uuid import UUID
from enum import Enum

from pydantic import BaseModel, Field


class IssuePriority(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class IssueStatus(str, Enum):
    OPEN = "OPEN"
    IN_PROGRESS = "IN_PROGRESS"
    DONE = "DONE"
    CANCELLED = "CANCELLED"


class IssueBase(BaseModel):
    title: str = Field(..., max_length=255)
    description: str | None = None
    priority: IssuePriority = IssuePriority.MEDIUM
    status: IssueStatus = IssueStatus.OPEN
    error_codes: List[str] | None = None


class IssueCreate(IssueBase):
    pass


class IssueUpdate(BaseModel):
    title: str | None = Field(default=None, max_length=255)
    description: str | None = None
    priority: IssuePriority | None = None
    status: IssueStatus | None = None
    error_codes: List[str] | None = None


class IssueOut(BaseModel):
    id: UUID
    vehicle_id: UUID
    created_by: UUID
    title: str
    description: str | None = None
    priority: IssuePriority
    status: IssueStatus
    error_codes: str | None = None
    created_at: datetime | None = None
    closed_at: datetime | None = None

    class Config:
        from_attributes = True
