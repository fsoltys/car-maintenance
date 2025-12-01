SET search_path TO car_app, public;

-- 1) Lista tankowań dla pojazdu (OWNER + shares: VIEWER/EDITOR)

CREATE OR REPLACE FUNCTION car_app.fn_get_vehicle_fuelings(
    p_user_id    uuid,
    p_vehicle_id uuid
)
RETURNS TABLE (
    id              uuid,
    vehicle_id      uuid,
    user_id         uuid,
    filled_at       timestamptz,
    price_per_unit  numeric(10,3),
    volume          numeric(10,3),
    odometer_km     numeric(10,1),
    full_tank       boolean,
    driving_cycle   driving_cycle,
    fuel            fuel_type,
    note            text,
    fuel_level_before numeric(5,2),
    fuel_level_after  numeric(5,2),
    created_at      timestamptz
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- sprawdzenie dostępu do pojazdu (OWNER + dowolny share)
    IF NOT EXISTS (
        SELECT 1
        FROM vehicles v
        LEFT JOIN vehicle_shares s
          ON s.vehicle_id = v.id
         AND s.user_id = p_user_id
        WHERE v.id = p_vehicle_id
          AND (v.owner_id = p_user_id OR s.user_id IS NOT NULL)
    ) THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        f.id,
        f.vehicle_id,
        f.user_id,
        f.filled_at,
        f.price_per_unit,
        f.volume,
        f.odometer_km,
        f.full_tank,
        f.driving_cycle,
        f.fuel,
        f.note,
        f.fuel_level_before,
        f.fuel_level_after,
        f.created_at
    FROM fuelings f
    WHERE f.vehicle_id = p_vehicle_id
    ORDER BY f.filled_at DESC, f.created_at DESC;
END;
$$;

-- 1a) Lista tankowań dla pojazdu w zakresie dat (OWNER + shares: VIEWER/EDITOR)

CREATE OR REPLACE FUNCTION car_app.fn_get_vehicle_fuelings_range(
    p_user_id    uuid,
    p_vehicle_id uuid,
    p_from       timestamptz,
    p_to         timestamptz
)
RETURNS TABLE (
    id              uuid,
    vehicle_id      uuid,
    user_id         uuid,
    filled_at       timestamptz,
    price_per_unit  numeric(10,3),
    volume          numeric(10,3),
    odometer_km     numeric(10,1),
    full_tank       boolean,
    driving_cycle   driving_cycle,
    fuel            fuel_type,
    note            text,
    fuel_level_before numeric(5,2),
    fuel_level_after  numeric(5,2),
    created_at      timestamptz
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- sprawdzenie dostępu do pojazdu (OWNER + dowolny share)
    IF NOT EXISTS (
        SELECT 1
        FROM vehicles v
        LEFT JOIN vehicle_shares s
          ON s.vehicle_id = v.id
         AND s.user_id = p_user_id
        WHERE v.id = p_vehicle_id
          AND (v.owner_id = p_user_id OR s.user_id IS NOT NULL)
    ) THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        f.id,
        f.vehicle_id,
        f.user_id,
        f.filled_at,
        f.price_per_unit,
        f.volume,
        f.odometer_km,
        f.full_tank,
        f.driving_cycle,
        f.fuel,
        f.note,
        f.fuel_level_before,
        f.fuel_level_after,
        f.created_at
    FROM fuelings f
    WHERE f.vehicle_id = p_vehicle_id
      AND (p_from IS NULL OR f.filled_at >= p_from)
      AND (p_to   IS NULL OR f.filled_at <= p_to)
    ORDER BY f.filled_at DESC, f.created_at DESC;
END;
$$;

-- 2) Pojedyncze tankowanie (OWNER + shares: VIEWER/EDITOR)

CREATE OR REPLACE FUNCTION car_app.fn_get_fueling(
    p_user_id    uuid,
    p_fueling_id uuid
)
RETURNS TABLE (
    id              uuid,
    vehicle_id      uuid,
    user_id         uuid,
    filled_at       timestamptz,
    price_per_unit  numeric(10,3),
    volume          numeric(10,3),
    odometer_km     numeric(10,1),
    full_tank       boolean,
    driving_cycle   driving_cycle,
    fuel            fuel_type,
    note            text,
    fuel_level_before numeric(5,2),
    fuel_level_after  numeric(5,2),
    created_at      timestamptz
)
LANGUAGE sql
AS $$
    SELECT
        f.id,
        f.vehicle_id,
        f.user_id,
        f.filled_at,
        f.price_per_unit,
        f.volume,
        f.odometer_km,
        f.full_tank,
        f.driving_cycle,
        f.fuel,
        f.note,
        f.fuel_level_before,
        f.fuel_level_after,
        f.created_at
    FROM fuelings f
    JOIN vehicles v
      ON v.id = f.vehicle_id
    LEFT JOIN vehicle_shares s
      ON s.vehicle_id = v.id
     AND s.user_id = p_user_id
    WHERE f.id = p_fueling_id
      AND (v.owner_id = p_user_id OR s.user_id IS NOT NULL)
$$;

-- 3) Utworzenie tankowania (OWNER/EDITOR)

CREATE OR REPLACE FUNCTION car_app.fn_create_fueling(
    p_user_id         uuid,
    p_vehicle_id      uuid,
    p_filled_at       timestamptz,
    p_price_per_unit  double precision,
    p_volume          double precision,
    p_odometer_km     double precision,
    p_full_tank       boolean,
    p_driving_cycle   driving_cycle,
    p_fuel            fuel_type,
    p_note            text,
    p_fuel_level_before double precision DEFAULT NULL,
    p_fuel_level_after  double precision DEFAULT NULL
)
RETURNS TABLE (
    id              uuid,
    vehicle_id      uuid,
    user_id         uuid,
    filled_at       timestamptz,
    price_per_unit  numeric(10,3),
    volume          numeric(10,3),
    odometer_km     numeric(10,1),
    full_tank       boolean,
    driving_cycle   driving_cycle,
    fuel            fuel_type,
    note            text,
    fuel_level_before numeric(5,2),
    fuel_level_after  numeric(5,2),
    created_at      timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id uuid;
    v_row      fuelings%ROWTYPE;
    v_cfg_cnt  int;
BEGIN
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

    IF p_price_per_unit <= 0 OR p_volume <= 0 OR p_odometer_km <= 0 THEN
        RAISE EXCEPTION 'Price, volume and odometer must be positive'
            USING ERRCODE = '22023';
    END IF;

    SELECT COUNT(*) INTO v_cfg_cnt
    FROM vehicle_fuels vf
    WHERE vf.vehicle_id = p_vehicle_id;

    IF v_cfg_cnt > 0 THEN
        IF NOT EXISTS (
            SELECT 1
            FROM vehicle_fuels vf
            WHERE vf.vehicle_id = p_vehicle_id
              AND vf.fuel = p_fuel
        ) THEN
            RAISE EXCEPTION 'Fuel % is not allowed for this vehicle', p_fuel
                USING ERRCODE = '22023';
        END IF;
    END IF;

    INSERT INTO fuelings (
        id,
        vehicle_id,
        user_id,
        filled_at,
        price_per_unit,
        volume,
        odometer_km,
        full_tank,
        driving_cycle,
        fuel,
        note,
        fuel_level_before,
        fuel_level_after,
        created_at
    )
    VALUES (
        gen_random_uuid(),
        p_vehicle_id,
        p_user_id,
        p_filled_at,
        p_price_per_unit,
        p_volume,
        p_odometer_km,
        p_full_tank,
        p_driving_cycle,
        p_fuel,
        p_note,
        p_fuel_level_before,
        p_fuel_level_after,
        now()
    )
    RETURNING * INTO v_row;

    RETURN QUERY
    SELECT
        v_row.id,
        v_row.vehicle_id,
        v_row.user_id,
        v_row.filled_at,
        v_row.price_per_unit,
        v_row.volume,
        v_row.odometer_km,
        v_row.full_tank,
        v_row.driving_cycle,
        v_row.fuel,
        v_row.note,
        v_row.fuel_level_before,
        v_row.fuel_level_after,
        v_row.created_at;
END;
$$;

-- 4) Aktualizacja tankowania (OWNER/EDITOR)

CREATE OR REPLACE FUNCTION car_app.fn_update_fueling(
    p_user_id         uuid,
    p_fueling_id      uuid,
    p_filled_at       timestamptz,
    p_price_per_unit  double precision,
    p_volume          double precision,
    p_odometer_km     double precision,
    p_full_tank       boolean,
    p_driving_cycle   driving_cycle,
    p_fuel            fuel_type,
    p_note            text,
    p_fuel_level_before double precision DEFAULT NULL,
    p_fuel_level_after  double precision DEFAULT NULL
)
RETURNS TABLE (
    id              uuid,
    vehicle_id      uuid,
    user_id         uuid,
    filled_at       timestamptz,
    price_per_unit  numeric(10,3),
    volume          numeric(10,3),
    odometer_km     numeric(10,1),
    full_tank       boolean,
    driving_cycle   driving_cycle,
    fuel            fuel_type,
    note            text,
    fuel_level_before numeric(5,2),
    fuel_level_after  numeric(5,2),
    created_at      timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_row       fuelings%ROWTYPE;
    v_vehicle_id uuid;
    v_owner_id   uuid;
    v_cfg_cnt    int;
BEGIN
    SELECT f.*
    INTO v_row
    FROM fuelings f
    WHERE f.id = p_fueling_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- get owner of the vehicle
    SELECT v.owner_id
    INTO v_owner_id
    FROM vehicles v
    WHERE v.id = v_row.vehicle_id;

    v_vehicle_id := v_row.vehicle_id;

    IF v_owner_id <> p_user_id THEN
        IF NOT EXISTS (
            SELECT 1
            FROM vehicle_shares s
            WHERE s.vehicle_id = v_vehicle_id
              AND s.user_id = p_user_id
              AND s.role IN ('OWNER','EDITOR')
        ) THEN
            RETURN;
        END IF;
    END IF;

    IF p_price_per_unit <= 0 OR p_volume <= 0 OR p_odometer_km <= 0 THEN
        RAISE EXCEPTION 'Price, volume and odometer must be positive'
            USING ERRCODE = '22023';
    END IF;

    SELECT COUNT(*) INTO v_cfg_cnt
    FROM vehicle_fuels vf
    WHERE vf.vehicle_id = v_vehicle_id;

    IF v_cfg_cnt > 0 THEN
        IF NOT EXISTS (
            SELECT 1
            FROM vehicle_fuels vf
            WHERE vf.vehicle_id = v_vehicle_id
              AND vf.fuel = p_fuel
        ) THEN
            RAISE EXCEPTION 'Fuel % is not allowed for this vehicle', p_fuel
                USING ERRCODE = '22023';
        END IF;
    END IF;

    UPDATE fuelings f
    SET
        filled_at      = p_filled_at,
        price_per_unit = p_price_per_unit,
        volume         = p_volume,
        odometer_km    = p_odometer_km,
        full_tank      = p_full_tank,
        driving_cycle  = p_driving_cycle,
        fuel           = p_fuel,
        note           = p_note,
        fuel_level_before = p_fuel_level_before,
        fuel_level_after  = p_fuel_level_after
    WHERE f.id = p_fueling_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        v_row.id,
        v_row.vehicle_id,
        v_row.user_id,
        v_row.filled_at,
        v_row.price_per_unit,
        v_row.volume,
        v_row.odometer_km,
        v_row.full_tank,
        v_row.driving_cycle,
        v_row.fuel,
        v_row.note,
        v_row.fuel_level_before,
        v_row.fuel_level_after,
        v_row.created_at;
END;
$$;

-- 5) Usunięcie tankowania (OWNER/EDITOR)

CREATE OR REPLACE FUNCTION car_app.fn_delete_fueling(
    p_user_id    uuid,
    p_fueling_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_vehicle_id uuid;
    v_owner_id   uuid;
    v_deleted    int;
BEGIN
    SELECT f.vehicle_id, v.owner_id
    INTO v_vehicle_id, v_owner_id
    FROM fuelings f
    JOIN vehicles v ON v.id = f.vehicle_id
    WHERE f.id = p_fueling_id;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    IF v_owner_id <> p_user_id THEN
        IF NOT EXISTS (
            SELECT 1
            FROM vehicle_shares s
            WHERE s.vehicle_id = v_vehicle_id
              AND s.user_id = p_user_id
              AND s.role IN ('OWNER','EDITOR')
        ) THEN
            RETURN FALSE;
        END IF;
    END IF;

    DELETE FROM fuelings f
    WHERE f.id = p_fueling_id;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN v_deleted > 0;
END;
$$;
