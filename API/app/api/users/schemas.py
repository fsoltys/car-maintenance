from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


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


class TokenPayload(BaseModel):
    """
    Reprezentacja payloadu z JWT.
    """
    sub: str | None = None