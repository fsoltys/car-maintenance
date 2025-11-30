from __future__ import annotations

from datetime import date, datetime
from uuid import uuid4

from sqlalchemy import Date, DateTime, Integer, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Vehicle(Base):
    __tablename__ = "vehicles"

    id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    owner_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
    )

    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)

    vin: Mapped[str | None] = mapped_column(String(32), unique=True)
    plate: Mapped[str | None] = mapped_column(String(32))
    policy_number: Mapped[str | None] = mapped_column(String(64))
    model: Mapped[str | None] = mapped_column(String(120))

    production_year: Mapped[int | None] = mapped_column(Integer)
    tank_capacity_l: Mapped[float | None] = mapped_column(Numeric(8, 2))
    battery_capacity_kwh: Mapped[float | None] = mapped_column(Numeric(8, 2))
    initial_odometer_km: Mapped[float | None] = mapped_column(Numeric(10, 1))

    purchase_price: Mapped[float | None] = mapped_column(Numeric(12, 2))
    purchase_date: Mapped[date | None] = mapped_column(Date)
    last_inspection_date: Mapped[date | None] = mapped_column(Date)

    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
