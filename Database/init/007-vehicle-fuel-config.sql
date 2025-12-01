SET search_path TO car_app, public;

-- Funkcja do dodawania paliw do pojazdu (bez sprawdzania uprawnień - użytkownik jest właścicielem)
-- Używana przy tworzeniu pojazdu

CREATE OR REPLACE FUNCTION car_app.fn_add_vehicle_fuels(
    p_vehicle_id uuid,
    p_config     jsonb
)
RETURNS TABLE (
    vehicle_id uuid,
    fuel       fuel_type,
    is_primary boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_item          jsonb;
    v_primary_count int := 0;
    v_fuel          fuel_type;
    v_is_primary    boolean;
BEGIN
    -- 1) Walidacja formatu JSON
    IF p_config IS NULL OR jsonb_typeof(p_config) <> 'array' THEN
        RAISE EXCEPTION 'Config must be a JSON array'
            USING ERRCODE = '22023';
    END IF;

    -- 2) Walidacja paliw & liczenie primary
    FOR v_item IN
        SELECT jsonb_array_elements(p_config)
    LOOP
        v_fuel := (v_item->>'fuel')::fuel_type;
        v_is_primary := COALESCE((v_item->>'is_primary')::boolean, false);

        IF v_is_primary THEN
            v_primary_count := v_primary_count + 1;
        END IF;
    END LOOP;

    IF v_primary_count > 1 THEN
        RAISE EXCEPTION 'At most one primary fuel is allowed'
            USING ERRCODE = '22023';
    END IF;

    -- 3) Wstawianie paliw
    FOR v_item IN
        SELECT jsonb_array_elements(p_config)
    LOOP
        v_fuel := (v_item->>'fuel')::fuel_type;
        v_is_primary := COALESCE((v_item->>'is_primary')::boolean, false);

        INSERT INTO vehicle_fuels (vehicle_id, fuel, is_primary)
        VALUES (p_vehicle_id, v_fuel, v_is_primary)
        ON CONFLICT (vehicle_id, fuel) DO UPDATE
        SET is_primary = EXCLUDED.is_primary;
    END LOOP;

    -- 4) Zwracamy aktualną konfigurację
    RETURN QUERY
    SELECT
        vf.vehicle_id,
        vf.fuel,
        vf.is_primary
    FROM vehicle_fuels vf
    WHERE vf.vehicle_id = p_vehicle_id
    ORDER BY vf.is_primary DESC, vf.fuel;
END;
$$;


-- 1) Lista dozwolonych paliw dla pojazdu
--    OWNER + każdy, kto ma share (VIEWER/EDITOR/OWNER)


CREATE OR REPLACE FUNCTION car_app.fn_get_vehicle_fuels(
    p_user_id    uuid,
    p_vehicle_id uuid
)
RETURNS TABLE (
    vehicle_id uuid,
    fuel       fuel_type,
    is_primary boolean
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- sprawdzamy, czy użytkownik ma dostęp do pojazdu
    IF NOT EXISTS (
        SELECT 1
        FROM vehicles v
        LEFT JOIN vehicle_shares s
          ON s.vehicle_id = v.id
         AND s.user_id = p_user_id
        WHERE v.id = p_vehicle_id
          AND (v.owner_id = p_user_id OR s.user_id IS NOT NULL)
    ) THEN
        -- brak pojazdu lub brak dostępu
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        vf.vehicle_id,
        vf.fuel,
        vf.is_primary
    FROM vehicle_fuels vf
    WHERE vf.vehicle_id = p_vehicle_id
    ORDER BY vf.is_primary DESC, vf.fuel;
END;
$$;


-- 2) Nadpisanie konfiguracji paliw
--    Tylko OWNER lub EDITOR
--    p_config: jsonb = [
--      { "fuel": "PB95", "is_primary": true },
--      { "fuel": "LPG",  "is_primary": false }
--    ]

CREATE OR REPLACE FUNCTION car_app.fn_replace_vehicle_fuels(
    p_user_id    uuid,
    p_vehicle_id uuid,
    p_config     jsonb
)
RETURNS TABLE (
    vehicle_id uuid,
    fuel       fuel_type,
    is_primary boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id      uuid;
    v_item          jsonb;
    v_primary_count int := 0;
    v_fuel          fuel_type;
    v_is_primary    boolean;
BEGIN
    -- 1) Sprawdzenie istnienia pojazdu
    SELECT v.owner_id
    INTO v_owner_id
    FROM vehicles v
    WHERE v.id = p_vehicle_id;

    IF v_owner_id IS NULL THEN
        -- pojazd nie istnieje
        RETURN;
    END IF;

    -- 2) Sprawdzenie uprawnień (OWNER / EDITOR)
    IF v_owner_id <> p_user_id THEN
        IF NOT EXISTS (
            SELECT 1
            FROM vehicle_shares s
            WHERE s.vehicle_id = p_vehicle_id
              AND s.user_id = p_user_id
              AND s.role IN ('OWNER','EDITOR')
        ) THEN
            -- brak uprawnień
            RETURN;
        END IF;
    END IF;

    -- 3) Walidacja formatu JSON
    IF p_config IS NULL OR jsonb_typeof(p_config) <> 'array' THEN
        RAISE EXCEPTION 'Config must be a JSON array'
            USING ERRCODE = '22023';
    END IF;

    -- 4) Walidacja paliw & liczenie primary
    FOR v_item IN
        SELECT jsonb_array_elements(p_config)
    LOOP
        v_fuel := (v_item->>'fuel')::fuel_type;
        v_is_primary := COALESCE((v_item->>'is_primary')::boolean, false);

        IF v_is_primary THEN
            v_primary_count := v_primary_count + 1;
        END IF;
    END LOOP;

    IF v_primary_count > 1 THEN
        RAISE EXCEPTION 'At most one primary fuel is allowed'
            USING ERRCODE = '22023';
    END IF;

    -- 5) Podmiana konfiguracji
    DELETE FROM vehicle_fuels vf
    WHERE vf.vehicle_id = p_vehicle_id;

    FOR v_item IN
        SELECT jsonb_array_elements(p_config)
    LOOP
        v_fuel := (v_item->>'fuel')::fuel_type;
        v_is_primary := COALESCE((v_item->>'is_primary')::boolean, false);

        INSERT INTO vehicle_fuels (vehicle_id, fuel, is_primary)
        VALUES (p_vehicle_id, v_fuel, v_is_primary);
    END LOOP;

    -- 6) Zwracamy aktualną konfigurację
    RETURN QUERY
    SELECT
        vf.vehicle_id,
        vf.fuel,
        vf.is_primary
    FROM vehicle_fuels vf
    WHERE vf.vehicle_id = p_vehicle_id
    ORDER BY vf.is_primary DESC, vf.fuel;
END;
$$;