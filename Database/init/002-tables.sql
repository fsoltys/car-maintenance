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

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'unit_system') THEN
        CREATE TYPE unit_system AS ENUM (
            'METRIC',
            'IMPERIAL'
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

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_type') THEN
        CREATE TYPE document_type AS ENUM (
            'INSURANCE_OC',
            'INSURANCE_AC',
            'TECH_INSPECTION',
            'OTHER'
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

-- Users, RBAC, Settings

CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY,
    email           VARCHAR(255) NOT NULL UNIQUE,
    password_hash   TEXT NOT NULL,
    display_name    VARCHAR(120),
    created_at      TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS user_settings (
    user_id         UUID PRIMARY KEY REFERENCES users(id),
    unit_pref       unit_system NOT NULL DEFAULT 'METRIC',
    currency        CHAR(3),
    timezone        VARCHAR(64),
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
    updated_at              TIMESTAMPTZ
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
    CONSTRAINT chk_fuel_level_after_range CHECK (fuel_level_after IS NULL OR (fuel_level_after >= 0 AND fuel_level_after <= 100))
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
    created_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_services_vehicle_service_date
    ON services(vehicle_id, service_date);

CREATE INDEX IF NOT EXISTS idx_services_vehicle_odometer_km
    ON services(vehicle_id, odometer_km);

CREATE TABLE IF NOT EXISTS service_items (
    id              UUID PRIMARY KEY,
    service_id      UUID NOT NULL REFERENCES services(id),
    part_name       VARCHAR(160),
    part_number     VARCHAR(80),
    quantity        NUMERIC(10,2),
    unit_price      NUMERIC(12,2)
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
    error_codes     VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS idx_issues_vehicle_status
    ON issues(vehicle_id, status);

CREATE INDEX IF NOT EXISTS idx_issues_priority
    ON issues(priority);

-- Documents (OC/AC, przegląd)

CREATE TABLE IF NOT EXISTS documents (
    id              UUID PRIMARY KEY,
    vehicle_id      UUID NOT NULL REFERENCES vehicles(id),
    doc_type        document_type NOT NULL,
    number          VARCHAR(64),
    provider        VARCHAR(160),
    issue_date      DATE,
    valid_from      DATE,
    valid_to        DATE,
    note            TEXT,
    created_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_documents_vehicle_doc_type
    ON documents(vehicle_id, doc_type);

CREATE INDEX IF NOT EXISTS idx_documents_vehicle_valid_to
    ON documents(vehicle_id, valid_to);

-- Odometer History

CREATE TABLE IF NOT EXISTS odometer_entries (
    id              UUID PRIMARY KEY,
    vehicle_id      UUID NOT NULL REFERENCES vehicles(id),
    entry_date      TIMESTAMPTZ NOT NULL,
    value_km        NUMERIC(10,1) NOT NULL,
    note            TEXT
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
    created_at      TIMESTAMPTZ
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
    due_every_days          INT,
    due_every_km            INT,
    last_reset_at           TIMESTAMPTZ,
    last_reset_odometer_km  NUMERIC(10,1),
    next_due_date           DATE,
    next_due_odometer_km    NUMERIC(10,1),
    status                  reminder_status NOT NULL DEFAULT 'ACTIVE',
    auto_reset_on_service   BOOLEAN DEFAULT FALSE,
    created_at              TIMESTAMPTZ,
    updated_at              TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_reminder_rules_vehicle_status
    ON reminder_rules(vehicle_id, status);

CREATE INDEX IF NOT EXISTS idx_reminder_rules_vehicle_next_due_date
    ON reminder_rules(vehicle_id, next_due_date);

CREATE INDEX IF NOT EXISTS idx_reminder_rules_vehicle_next_due_odo
    ON reminder_rules(vehicle_id, next_due_odometer_km);

COMMENT ON TABLE reminder_rules IS
    'Definicje przypomnień; jeśli service_type ustawione, reguła automatycznie resetuje się po serwisie tego typu.';

CREATE TABLE IF NOT EXISTS reminder_events (
    id              UUID PRIMARY KEY,
    rule_id         UUID NOT NULL REFERENCES reminder_rules(id),
    triggered_at    TIMESTAMPTZ NOT NULL,
    odometer_km     NUMERIC(10,1),
    reason          VARCHAR(64)
);
