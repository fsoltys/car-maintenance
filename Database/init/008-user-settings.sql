SET search_path TO car_app, public;

-- 1) Pobranie ustawień użytkownika
--    Jeśli brak rekordu -> tworzymy z domyślnym unit_pref='METRIC'

CREATE OR REPLACE FUNCTION car_app.fn_get_user_settings(
    p_user_id uuid
)
RETURNS TABLE (
    user_id    uuid,
    unit_pref  unit_system,
    currency   char(3),
    timezone   varchar(64),
    created_at timestamptz,
    updated_at timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_row user_settings%ROWTYPE;
BEGIN
    SELECT *
    INTO v_row
    FROM user_settings
    WHERE user_id = p_user_id;

    -- Jeśli brak ustawień, tworzymy domyślne
    IF NOT FOUND THEN
        INSERT INTO user_settings (
            user_id,
            unit_pref,
            currency,
            timezone,
            created_at,
            updated_at
        )
        VALUES (
            p_user_id,
            'METRIC',
            NULL,
            NULL,
            now(),
            now()
        )
        RETURNING *
        INTO v_row;
    END IF;

    RETURN QUERY
    SELECT
        v_row.user_id,
        v_row.unit_pref,
        v_row.currency,
        v_row.timezone,
        v_row.created_at,
        v_row.updated_at;
END;
$$;

-- 2) Aktualizacja ustawień użytkownika
--    - p_unit_pref: 'METRIC' / 'IMPERIAL' (wymagane)
--    - p_currency: może być NULL lub 3-literowy kod ISO
--    - p_timezone: dowolny niepusty string lub NULL

CREATE OR REPLACE FUNCTION car_app.fn_update_user_settings(
    p_user_id    uuid,
    p_unit_pref  text,
    p_currency   text,
    p_timezone   text
)
RETURNS TABLE (
    user_id    uuid,
    unit_pref  unit_system,
    currency   char(3),
    timezone   varchar(64),
    created_at timestamptz,
    updated_at timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_row        user_settings%ROWTYPE;
    v_unit_pref  unit_system;
    v_currency   char(3);
    v_timezone   varchar(64);
BEGIN
    IF p_unit_pref IS NULL OR btrim(p_unit_pref) = '' THEN
        RAISE EXCEPTION 'unit_pref is required'
            USING ERRCODE = '22023';
    END IF;

    BEGIN
        v_unit_pref := (upper(btrim(p_unit_pref)))::unit_system;
    EXCEPTION
        WHEN others THEN
            RAISE EXCEPTION 'Invalid unit_pref value: %', p_unit_pref
                USING ERRCODE = '22023';
    END;

    IF p_currency IS NULL OR btrim(p_currency) = '' THEN
        v_currency := NULL;
    ELSE
        v_currency := upper(btrim(p_currency));
        IF length(v_currency) <> 3 THEN
            RAISE EXCEPTION 'Currency must be a 3-letter code'
                USING ERRCODE = '22023';
        END IF;
    END IF;

    IF p_timezone IS NULL OR btrim(p_timezone) = '' THEN
        v_timezone := NULL;
    ELSE
        v_timezone := btrim(p_timezone);
    END IF;

    INSERT INTO user_settings (
        user_id,
        unit_pref,
        currency,
        timezone,
        created_at,
        updated_at
    )
    VALUES (
        p_user_id,
        v_unit_pref,
        v_currency,
        v_timezone,
        now(),
        now()
    )
    ON CONFLICT (user_id)
    DO UPDATE SET
        unit_pref  = EXCLUDED.unit_pref,
        currency   = EXCLUDED.currency,
        timezone   = EXCLUDED.timezone,
        updated_at = now()
    RETURNING *
    INTO v_row;

    RETURN QUERY
    SELECT
        v_row.user_id,
        v_row.unit_pref,
        v_row.currency,
        v_row.timezone,
        v_row.created_at,
        v_row.updated_at;
END;
$$;