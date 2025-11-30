SET search_path TO car_app, public;

-- 1) Lista pojazdów użytkownika (OWNER + shares)

CREATE OR REPLACE FUNCTION fn_get_user_vehicles(
    p_user_id uuid
)
RETURNS TABLE (
    id                     uuid,
    owner_id               uuid,
    name                   varchar,
    description            text,
    vin                    varchar,
    plate                  varchar,
    policy_number          varchar,
    model                  varchar,
    production_year        integer,
    tank_capacity_l        numeric(8,2),
    battery_capacity_kwh   numeric(8,2),
    initial_odometer_km    numeric(10,1),
    purchase_price         numeric(12,2),
    purchase_date          date,
    last_inspection_date   date,
    created_at             timestamptz,
    updated_at             timestamptz
)
LANGUAGE sql
AS $$
    SELECT DISTINCT
        v.id,
        v.owner_id,
        v.name,
        v.description,
        v.vin,
        v.plate,
        v.policy_number,
        v.model,
        v.production_year,
        v.tank_capacity_l,
        v.battery_capacity_kwh,
        v.initial_odometer_km,
        v.purchase_price,
        v.purchase_date,
        v.last_inspection_date,
        v.created_at,
        v.updated_at
    FROM vehicles v
    LEFT JOIN vehicle_shares s
      ON s.vehicle_id = v.id
     AND s.user_id = p_user_id
    WHERE v.owner_id = p_user_id
       OR s.user_id IS NOT NULL
    ORDER BY v.created_at DESC NULLS LAST
$$;

-- 2) Pobranie pojedynczego pojazdu
--    (OWNER lub dowolna rola w vehicle_shares)

CREATE OR REPLACE FUNCTION fn_get_vehicle(
    p_user_id    uuid,
    p_vehicle_id uuid
)
RETURNS TABLE (
    id                     uuid,
    owner_id               uuid,
    name                   varchar,
    description            text,
    vin                    varchar,
    plate                  varchar,
    policy_number          varchar,
    model                  varchar,
    production_year        integer,
    tank_capacity_l        numeric(8,2),
    battery_capacity_kwh   numeric(8,2),
    initial_odometer_km    numeric(10,1),
    purchase_price         numeric(12,2),
    purchase_date          date,
    last_inspection_date   date,
    created_at             timestamptz,
    updated_at             timestamptz
)
LANGUAGE sql
AS $$
    SELECT
        v.id,
        v.owner_id,
        v.name,
        v.description,
        v.vin,
        v.plate,
        v.policy_number,
        v.model,
        v.production_year,
        v.tank_capacity_l,
        v.battery_capacity_kwh,
        v.initial_odometer_km,
        v.purchase_price,
        v.purchase_date,
        v.last_inspection_date,
        v.created_at,
        v.updated_at
    FROM vehicles v
    LEFT JOIN vehicle_shares s
      ON s.vehicle_id = v.id
     AND s.user_id = p_user_id
    WHERE v.id = p_vehicle_id
      AND (
            v.owner_id = p_user_id
         OR s.user_id IS NOT NULL 
      )
$$;

-- 3) Utworzenie pojazdu (tylko owner)

CREATE OR REPLACE FUNCTION car_app.fn_create_vehicle(
    p_vehicle_id            uuid,
    p_owner_id              uuid,
    p_name                  text,
    p_description           text DEFAULT NULL,
    p_vin                   text DEFAULT NULL,
    p_plate                 text DEFAULT NULL,
    p_policy_number         text DEFAULT NULL,
    p_model                 text DEFAULT NULL,
    p_production_year       integer DEFAULT NULL,
    p_tank_capacity_l       double precision DEFAULT NULL,
    p_battery_capacity_kwh  double precision DEFAULT NULL,
    p_initial_odometer_km   double precision DEFAULT NULL,
    p_purchase_price        double precision DEFAULT NULL,
    p_purchase_date         date DEFAULT NULL,
    p_last_inspection_date  date DEFAULT NULL
)
RETURNS TABLE (
    id                     uuid,
    owner_id               uuid,
    name                   varchar,
    description            text,
    vin                    varchar,
    plate                  varchar,
    policy_number          varchar,
    model                  varchar,
    production_year        integer,
    tank_capacity_l        numeric(8,2),
    battery_capacity_kwh   numeric(8,2),
    initial_odometer_km    numeric(10,1),
    purchase_price         numeric(12,2),
    purchase_date          date,
    last_inspection_date   date,
    created_at             timestamptz,
    updated_at             timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_row vehicles%ROWTYPE;
BEGIN
    INSERT INTO vehicles (
        id,
        owner_id,
        name,
        description,
        vin,
        plate,
        policy_number,
        model,
        production_year,
        tank_capacity_l,
        battery_capacity_kwh,
        initial_odometer_km,
        purchase_price,
        purchase_date,
        last_inspection_date,
        created_at,
        updated_at
    )
    VALUES (
        p_vehicle_id,
        p_owner_id,
        p_name,
        p_description,
        p_vin,
        p_plate,
        p_policy_number,
        p_model,
        p_production_year,
        p_tank_capacity_l,
        p_battery_capacity_kwh,
        p_initial_odometer_km,
        p_purchase_price,
        p_purchase_date,
        p_last_inspection_date,
        now(),
        now()
    )
    RETURNING * INTO v_row;

    RETURN QUERY
    SELECT
        v_row.id,
        v_row.owner_id,
        v_row.name,
        v_row.description,
        v_row.vin,
        v_row.plate,
        v_row.policy_number,
        v_row.model,
        v_row.production_year,
        v_row.tank_capacity_l,
        v_row.battery_capacity_kwh,
        v_row.initial_odometer_km,
        v_row.purchase_price,
        v_row.purchase_date,
        v_row.last_inspection_date,
        v_row.created_at,
        v_row.updated_at;
END;
$$;

-- 4) Aktualizacja pojazdu
--    OWNER lub EDITOR (VIEWER tylko read)

CREATE OR REPLACE FUNCTION car_app.fn_update_vehicle(
    p_user_id               uuid,
    p_vehicle_id            uuid,
    p_name                  text,
    p_description           text,
    p_vin                   text,
    p_plate                 text,
    p_policy_number         text,
    p_model                 text,
    p_production_year       integer,
    p_tank_capacity_l       double precision,
    p_battery_capacity_kwh  double precision,
    p_initial_odometer_km   double precision,
    p_purchase_price        double precision,
    p_purchase_date         date,
    p_last_inspection_date  date
)
RETURNS TABLE (
    id                     uuid,
    owner_id               uuid,
    name                   varchar,
    description            text,
    vin                    varchar,
    plate                  varchar,
    policy_number          varchar,
    model                  varchar,
    production_year        integer,
    tank_capacity_l        numeric(8,2),
    battery_capacity_kwh   numeric(8,2),
    initial_odometer_km    numeric(10,1),
    purchase_price         numeric(12,2),
    purchase_date          date,
    last_inspection_date   date,
    created_at             timestamptz,
    updated_at             timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_row     vehicles%ROWTYPE;
    v_owner_id uuid;
BEGIN
    -- sprawdzamy, czy user ma prawo edytować (OWNER lub EDITOR)
    SELECT v.owner_id
    INTO v_owner_id
    FROM vehicles v
    WHERE v.id = p_vehicle_id;

    IF v_owner_id IS NULL THEN

        RETURN;
    END IF;

    IF v_owner_id <> p_user_id THEN
        IF NOT EXISTS (
            SELECT 1
            FROM vehicle_shares s
            WHERE s.vehicle_id = p_vehicle_id
              AND s.user_id = p_user_id
              AND s.role IN ('OWNER','EDITOR')
        ) THEN
            RETURN;
        END IF;
    END IF;

    UPDATE vehicles v
    SET
        name                  = p_name,
        description           = p_description,
        vin                   = p_vin,
        plate                 = p_plate,
        policy_number         = p_policy_number,
        model                 = p_model,
        production_year       = p_production_year,
        tank_capacity_l       = p_tank_capacity_l,
        battery_capacity_kwh  = p_battery_capacity_kwh,
        initial_odometer_km   = p_initial_odometer_km,
        purchase_price        = p_purchase_price,
        purchase_date         = p_purchase_date,
        last_inspection_date  = p_last_inspection_date,
        updated_at            = now()
    WHERE v.id = p_vehicle_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        v_row.id,
        v_row.owner_id,
        v_row.name,
        v_row.description,
        v_row.vin,
        v_row.plate,
        v_row.policy_number,
        v_row.model,
        v_row.production_year,
        v_row.tank_capacity_l,
        v_row.battery_capacity_kwh,
        v_row.initial_odometer_km,
        v_row.purchase_price,
        v_row.purchase_date,
        v_row.last_inspection_date,
        v_row.created_at,
        v_row.updated_at;
END;
$$;

-- 5) Usunięcie pojazdu
--    tylko OWNER 

CREATE OR REPLACE FUNCTION fn_delete_vehicle(
    p_user_id    uuid,
    p_vehicle_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted int;
BEGIN
    DELETE FROM vehicles v
    WHERE v.id = p_vehicle_id
      AND v.owner_id = p_user_id;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN v_deleted > 0;
END;
$$;
