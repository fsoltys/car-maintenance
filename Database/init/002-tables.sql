SET search_path TO car_app, public;

-- Enums

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'role_type') THEN
        CREATE TYPE role_type AS ENUM (
            'OWNER',
            'EDITOR',
            'VIEWER'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'driving_cycle') THEN
        CREATE TYPE driving_cycle AS ENUM (
            'CITY',
            'HIGHWAY',
            'MIX'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'service_type') THEN
        CREATE TYPE service_type AS ENUM (
            'INSPECTION',
            'OIL_CHANGE',
            'FILTERS',
            'BRAKES',
            'TIRES',
            'BATTERY',
            'ENGINE',
            'TRANSMISSION',
            'SUSPENSION',
            'OTHER'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'issue_priority') THEN
        CREATE TYPE issue_priority AS ENUM (
            'LOW',
            'MEDIUM',
            'HIGH',
            'CRITICAL'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'issue_status') THEN
        CREATE TYPE issue_status AS ENUM (
            'OPEN',
            'IN_PROGRESS',
            'DONE',
            'CANCELLED'
        );
    END IF;



    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'expense_category') THEN
        CREATE TYPE expense_category AS ENUM (
            'FUEL',
            'SERVICE',
            'INSURANCE',
            'TAX',
            'TOLLS',
            'PARKING',
            'ACCESSORIES',
            'WASH',
            'OTHER'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reminder_status') THEN
        CREATE TYPE reminder_status AS ENUM (
            'ACTIVE',
            'PAUSED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'fuel_type') THEN
        CREATE TYPE fuel_type AS ENUM (
            'Petrol',
            'Diesel',
            'LPG',
            'CNG',
            'EV',
            'H2'
        );
    END IF;
END
$$;

-- Users, RBAC

CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY,
    email           VARCHAR(255) NOT NULL UNIQUE,
    password_hash   TEXT NOT NULL,
    display_name    VARCHAR(120),
    created_at      TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS vehicles (
    id                      UUID PRIMARY KEY,
    owner_id                UUID NOT NULL REFERENCES users(id),
    name                    VARCHAR(120) NOT NULL,
    description             TEXT,
    vin                     VARCHAR(32) UNIQUE,
    plate                   VARCHAR(32),
    policy_number           VARCHAR(64),
    model                   VARCHAR(120),
    production_year         INT,
    dual_tank               BOOLEAN DEFAULT FALSE,
    tank_capacity_l         NUMERIC(8,2),
    secondary_tank_capacity NUMERIC(8,2),
    battery_capacity_kwh    NUMERIC(8,2),
    initial_odometer_km     NUMERIC(10,1),
    purchase_price          NUMERIC(12,2),
    purchase_date           DATE,
    last_inspection_date    DATE,
    created_at              TIMESTAMPTZ,
    updated_at              TIMESTAMPTZ,
    CONSTRAINT chk_production_year CHECK (production_year IS NULL OR (production_year >= 1900 AND production_year <= 2100)),
    CONSTRAINT chk_tank_capacity CHECK (tank_capacity_l IS NULL OR tank_capacity_l > 0),
    CONSTRAINT chk_secondary_tank_capacity CHECK (secondary_tank_capacity IS NULL OR secondary_tank_capacity > 0),
    CONSTRAINT chk_battery_capacity CHECK (battery_capacity_kwh IS NULL OR battery_capacity_kwh > 0),
    CONSTRAINT chk_initial_odometer CHECK (initial_odometer_km IS NULL OR initial_odometer_km >= 0),
    CONSTRAINT chk_purchase_price CHECK (purchase_price IS NULL OR purchase_price >= 0),
    CONSTRAINT chk_secondary_requires_dual CHECK (secondary_tank_capacity IS NULL OR dual_tank = TRUE)
);

CREATE INDEX IF NOT EXISTS idx_vehicles_owner_id
    ON vehicles(owner_id);

CREATE TABLE IF NOT EXISTS vehicle_fuels (
    vehicle_id  UUID NOT NULL REFERENCES vehicles(id),
    fuel        fuel_type NOT NULL,
    is_primary  BOOLEAN,
    PRIMARY KEY (vehicle_id, fuel)
);

CREATE TABLE IF NOT EXISTS vehicle_shares (
    vehicle_id  UUID NOT NULL REFERENCES vehicles(id),
    user_id     UUID NOT NULL REFERENCES users(id),
    role        role_type NOT NULL DEFAULT 'VIEWER',
    invited_at  TIMESTAMPTZ,
    PRIMARY KEY (vehicle_id, user_id)
);

-- Fueling & Consumption

CREATE TABLE IF NOT EXISTS fuelings (
    id              UUID PRIMARY KEY,
    vehicle_id      UUID NOT NULL REFERENCES vehicles(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    filled_at       TIMESTAMPTZ NOT NULL,
    price_per_unit  NUMERIC(10,3) NOT NULL,
    volume          NUMERIC(10,3) NOT NULL,
    odometer_km     NUMERIC(10,1) NOT NULL,
    full_tank       BOOLEAN NOT NULL,
    driving_cycle   driving_cycle,
    fuel            fuel_type NOT NULL,
    note            TEXT,
    fuel_level_before NUMERIC(5,2),  -- Tank level before fueling (0-100%)
    fuel_level_after  NUMERIC(5,2),  -- Tank level after fueling (0-100%)
    created_at      TIMESTAMPTZ,
    CONSTRAINT chk_fuel_level_before_range CHECK (fuel_level_before IS NULL OR (fuel_level_before >= 0 AND fuel_level_before <= 100)),
    CONSTRAINT chk_fuel_level_after_range CHECK (fuel_level_after IS NULL OR (fuel_level_after >= 0 AND fuel_level_after <= 100)),
    CONSTRAINT chk_price_per_unit_positive CHECK (price_per_unit > 0),
    CONSTRAINT chk_volume_positive CHECK (volume > 0),
    CONSTRAINT chk_odometer_positive CHECK (odometer_km >= 0)
);

CREATE INDEX IF NOT EXISTS idx_fuelings_vehicle_filled_at
    ON fuelings(vehicle_id, filled_at);

CREATE INDEX IF NOT EXISTS idx_fuelings_vehicle_odometer_km
    ON fuelings(vehicle_id, odometer_km);

CREATE INDEX IF NOT EXISTS idx_fuelings_vehicle_fuel
    ON fuelings(vehicle_id, fuel);

-- Service History & Parts

CREATE TABLE IF NOT EXISTS services (
    id              UUID PRIMARY KEY,
    vehicle_id      UUID NOT NULL REFERENCES vehicles(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    service_date    DATE NOT NULL,
    service_type    service_type NOT NULL,
    odometer_km     NUMERIC(10,1),
    total_cost      NUMERIC(12,2),
    reference       VARCHAR(64),
    note            TEXT,
    created_at      TIMESTAMPTZ,
    CONSTRAINT chk_service_odometer CHECK (odometer_km IS NULL OR odometer_km >= 0),
    CONSTRAINT chk_service_cost CHECK (total_cost IS NULL OR total_cost >= 0)
);

CREATE INDEX IF NOT EXISTS idx_services_vehicle_service_date
    ON services(vehicle_id, service_date);

CREATE INDEX IF NOT EXISTS idx_services_vehicle_odometer_km
    ON services(vehicle_id, odometer_km);

CREATE TABLE IF NOT EXISTS service_items (
    id              UUID PRIMARY KEY,
    service_id      UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    part_name       VARCHAR(160),
    part_number     VARCHAR(80),
    quantity        NUMERIC(10,2),
    unit_price      NUMERIC(12,2),
    CONSTRAINT chk_service_item_quantity CHECK (quantity IS NULL OR quantity > 0),
    CONSTRAINT chk_service_item_price CHECK (unit_price IS NULL OR unit_price >= 0)
);

-- Issues / TODOs

CREATE TABLE IF NOT EXISTS issues (
    id              UUID PRIMARY KEY,
    vehicle_id      UUID NOT NULL REFERENCES vehicles(id),
    title           VARCHAR(160) NOT NULL,
    description     TEXT,
    priority        issue_priority NOT NULL DEFAULT 'MEDIUM',
    status          issue_status NOT NULL DEFAULT 'OPEN',
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ,
    closed_at       TIMESTAMPTZ,
    error_codes     VARCHAR(255),
    CONSTRAINT chk_closed_after_created CHECK (closed_at IS NULL OR created_at IS NULL OR closed_at >= created_at)
);

CREATE INDEX IF NOT EXISTS idx_issues_vehicle_status
    ON issues(vehicle_id, status);

CREATE INDEX IF NOT EXISTS idx_issues_priority
    ON issues(priority);



-- Odometer History

CREATE TABLE IF NOT EXISTS odometer_entries (
    id              UUID PRIMARY KEY,
    vehicle_id      UUID NOT NULL REFERENCES vehicles(id),
    entry_date      TIMESTAMPTZ NOT NULL,
    value_km        NUMERIC(10,1) NOT NULL,
    note            TEXT,
    CONSTRAINT chk_odometer_value CHECK (value_km >= 0)
);

CREATE INDEX IF NOT EXISTS idx_odo_entries_vehicle_entry_date
    ON odometer_entries(vehicle_id, entry_date);

CREATE INDEX IF NOT EXISTS idx_odo_entries_vehicle_value_km
    ON odometer_entries(vehicle_id, value_km);

-- Expenses

CREATE TABLE IF NOT EXISTS expenses (
    id              UUID PRIMARY KEY,
    vehicle_id      UUID NOT NULL REFERENCES vehicles(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    expense_date    DATE NOT NULL,
    category        expense_category NOT NULL,
    amount          NUMERIC(12,2) NOT NULL,
    vat_rate        NUMERIC(5,2),
    note            TEXT,
    created_at      TIMESTAMPTZ,
    CONSTRAINT chk_expense_amount CHECK (amount > 0),
    CONSTRAINT chk_vat_rate CHECK (vat_rate IS NULL OR (vat_rate >= 0 AND vat_rate <= 100))
);

CREATE INDEX IF NOT EXISTS idx_expenses_vehicle_expense_date
    ON expenses(vehicle_id, expense_date);

CREATE INDEX IF NOT EXISTS idx_expenses_vehicle_category
    ON expenses(vehicle_id, category);

-- Reminders

CREATE TABLE IF NOT EXISTS reminder_rules (
    id                      UUID PRIMARY KEY,
    vehicle_id              UUID NOT NULL REFERENCES vehicles(id),
    name                    VARCHAR(160) NOT NULL,
    description             TEXT,
    category                VARCHAR(64),
    service_type            service_type,
    is_recurring            BOOLEAN NOT NULL DEFAULT TRUE,
    due_every_days          INT,
    due_every_km            INT,
    last_reset_at           TIMESTAMPTZ,
    last_reset_odometer_km  NUMERIC(10,1),
    next_due_date           DATE,
    next_due_odometer_km    NUMERIC(10,1),
    status                  reminder_status NOT NULL DEFAULT 'ACTIVE',
    auto_reset_on_service   BOOLEAN DEFAULT FALSE,
    created_at              TIMESTAMPTZ,
    updated_at              TIMESTAMPTZ,
    CONSTRAINT chk_reminder_has_due_condition CHECK (due_every_days IS NOT NULL OR due_every_km IS NOT NULL),
    CONSTRAINT chk_reminder_days CHECK (due_every_days IS NULL OR due_every_days > 0),
    CONSTRAINT chk_reminder_km CHECK (due_every_km IS NULL OR due_every_km > 0),
    CONSTRAINT chk_reminder_last_reset_odometer CHECK (last_reset_odometer_km IS NULL OR last_reset_odometer_km >= 0),
    CONSTRAINT chk_reminder_next_due_odometer CHECK (next_due_odometer_km IS NULL OR next_due_odometer_km >= 0)
);

CREATE INDEX IF NOT EXISTS idx_reminder_rules_vehicle_status
    ON reminder_rules(vehicle_id, status);

CREATE INDEX IF NOT EXISTS idx_reminder_rules_vehicle_next_due_date
    ON reminder_rules(vehicle_id, next_due_date);

CREATE INDEX IF NOT EXISTS idx_reminder_rules_vehicle_next_due_odo
    ON reminder_rules(vehicle_id, next_due_odometer_km);

COMMENT ON TABLE reminder_rules IS
    'Reminder definitions; if is_recurring=true, intervals represent "every X days/km"; if false, "due in X days/km" (one-time). Auto-reset applies only to recurring reminders.';

CREATE TABLE IF NOT EXISTS reminder_events (
    id              UUID PRIMARY KEY,
    rule_id         UUID NOT NULL REFERENCES reminder_rules(id) ON DELETE CASCADE,
    triggered_at    TIMESTAMPTZ NOT NULL,
    odometer_km     NUMERIC(10,1),
    reason          VARCHAR(64),
    CONSTRAINT chk_reminder_event_odometer CHECK (odometer_km IS NULL OR odometer_km >= 0)
);
