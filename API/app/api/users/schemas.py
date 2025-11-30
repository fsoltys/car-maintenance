from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field
from enum import Enum


class UserBase(BaseModel):
    email: EmailStr


class UserCreate(UserBase):
    password: str = Field(min_length=8)
    display_name: str | None = Field(default=None, max_length=120)


class UserLogin(UserBase):
    password: str


class UserOut(UserBase):
    id: UUID
    display_name: str | None = None
    created_at: datetime | None = None

    class Config:
        from_attributes = True


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    refresh_token: str | None = None


class TokenPayload(BaseModel):
    sub: UUID
    exp: int

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class UnitSystem(str, Enum):
    METRIC = "METRIC"
    IMPERIAL = "IMPERIAL"

class UserSettingsOut(BaseModel):
    unit_pref: UnitSystem
    currency: str | None = Field(default=None, max_length=3, min_length=3)
    timezone: str | None = None


class UserSettingsUpdate(BaseModel):
    unit_pref: UnitSystem
    currency: str | None = Field(default=None, max_length=3, min_length=3)
    timezone: str | None = None

class UserProfileUpdate(BaseModel):
    display_name: str | None = Field(default=None, max_length=120)


class PasswordChangeRequest(BaseModel):
    old_password: str
    new_password: str