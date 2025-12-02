SET search_path TO car_app, public;

CREATE OR REPLACE FUNCTION car_app.fn_get_vehicle_odometer_entries(
    p_user_id uuid,
    p_vehicle_id uuid
)
RETURNS TABLE (
    id uuid,
    vehicle_id uuid,
    entry_date timestamptz,
    value_km numeric,
    note text
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM vehicles v
        LEFT JOIN vehicle_shares s ON s.vehicle_id = v.id AND s.user_id = p_user_id
        WHERE v.id = p_vehicle_id
          AND (v.owner_id = p_user_id OR s.user_id IS NOT NULL)
    ) THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT e.id, e.vehicle_id, e.entry_date, e.value_km, e.note
    FROM odometer_entries e
    WHERE e.vehicle_id = p_vehicle_id
    ORDER BY e.entry_date DESC;
END;
$$;


CREATE OR REPLACE FUNCTION car_app.fn_create_odometer_entry(
    p_user_id uuid,
    p_vehicle_id uuid,
    p_entry_date timestamptz,
    p_value_km numeric,
    p_note text
)
RETURNS TABLE (
    id uuid,
    vehicle_id uuid,
    entry_date timestamptz,
    value_km numeric,
    note text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner uuid;
    v_row odometer_entries%ROWTYPE;
BEGIN
    SELECT v.owner_id INTO v_owner FROM vehicles v WHERE v.id = p_vehicle_id;
    IF v_owner IS NULL THEN
        RETURN;
    END IF;

    IF v_owner <> p_user_id THEN
        IF NOT EXISTS (
            SELECT 1 FROM vehicle_shares s WHERE s.vehicle_id = p_vehicle_id AND s.user_id = p_user_id
        ) THEN
            RETURN;
        END IF;
    END IF;

    INSERT INTO odometer_entries (id, vehicle_id, entry_date, value_km, note)
    VALUES (gen_random_uuid(), p_vehicle_id, p_entry_date, p_value_km, p_note)
    RETURNING * INTO v_row;

    RETURN QUERY SELECT v_row.id, v_row.vehicle_id, v_row.entry_date, v_row.value_km, v_row.note;
END;
$$;


CREATE OR REPLACE FUNCTION car_app.fn_update_odometer_entry(
    p_user_id uuid,
    p_entry_id uuid,
    p_entry_date timestamptz DEFAULT NULL,
    p_value_km numeric DEFAULT NULL,
    p_note text DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    vehicle_id uuid,
    entry_date timestamptz,
    value_km numeric,
    note text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_row odometer_entries%ROWTYPE;
    v_owner uuid;
    v_vehicle_id uuid;
    v_allowed boolean := false;
BEGIN
    SELECT e.*
    INTO v_row
    FROM odometer_entries e
    WHERE e.id = p_entry_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    v_vehicle_id := v_row.vehicle_id;

    SELECT v.owner_id INTO v_owner FROM vehicles v WHERE v.id = v_vehicle_id;

    IF v_owner = p_user_id THEN
        v_allowed := true;
    ELSE
        IF EXISTS (
            SELECT 1 FROM vehicle_shares s WHERE s.vehicle_id = v_vehicle_id AND s.user_id = p_user_id AND s.role IN ('OWNER','EDITOR')
        ) THEN
            v_allowed := true;
        END IF;
    END IF;

    IF NOT v_allowed THEN
        RETURN;
    END IF;

    UPDATE odometer_entries e SET
        entry_date = COALESCE(p_entry_date, entry_date),
        value_km = COALESCE(p_value_km, value_km),
        note = COALESCE(p_note, note)
    WHERE e.id = p_entry_id
    RETURNING * INTO v_row;

    RETURN QUERY SELECT v_row.id, v_row.vehicle_id, v_row.entry_date, v_row.value_km, v_row.note;
END;
$$;


CREATE OR REPLACE FUNCTION car_app.fn_delete_odometer_entry(
    p_user_id uuid,
    p_entry_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_row odometer_entries%ROWTYPE;
    v_vehicle_id uuid;
    v_owner uuid;
    v_deleted int;
    v_allowed boolean := false;
BEGIN
    SELECT e.*
    INTO v_row
    FROM odometer_entries e
    WHERE e.id = p_entry_id;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    v_vehicle_id := v_row.vehicle_id;

    SELECT v.owner_id INTO v_owner FROM vehicles v WHERE v.id = v_vehicle_id;

    IF v_owner = p_user_id THEN
        v_allowed := true;
    ELSE
        IF EXISTS (
            SELECT 1 FROM vehicle_shares s WHERE s.vehicle_id = v_vehicle_id AND s.user_id = p_user_id AND s.role IN ('OWNER','EDITOR')
        ) THEN
            v_allowed := true;
        END IF;
    END IF;

    IF NOT v_allowed THEN
        RETURN FALSE;
    END IF;

    DELETE FROM odometer_entries e WHERE e.id = p_entry_id;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN v_deleted > 0;
END;
$$;


CREATE OR REPLACE FUNCTION car_app.fn_get_vehicle_odometer_history(
    p_user_id uuid,
    p_vehicle_id uuid,
    p_from timestamptz DEFAULT NULL,
    p_to timestamptz DEFAULT NULL,
    p_limit int DEFAULT 1000
)
RETURNS TABLE (
    event_id uuid,
    event_type text,
    source_id uuid,
    event_date timestamptz,
    odometer_km numeric,
    note text,
    source_user_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM vehicles v
        LEFT JOIN vehicle_shares s ON s.vehicle_id = v.id AND s.user_id = p_user_id
        WHERE v.id = p_vehicle_id
          AND (v.owner_id = p_user_id OR s.user_id IS NOT NULL)
    ) THEN
        RETURN;
    END IF;

    RETURN QUERY
    (
        SELECT f.id AS event_id, 'FUELING' AS event_type, f.id AS source_id, f.filled_at AS event_date, f.odometer_km AS odometer_km, f.note AS note, f.user_id AS source_user_id
        FROM fuelings f
        WHERE f.vehicle_id = p_vehicle_id
          AND (p_from IS NULL OR f.filled_at >= p_from)
          AND (p_to IS NULL OR f.filled_at <= p_to)

        UNION ALL

        SELECT s.id AS event_id, 'SERVICE' AS event_type, s.id AS source_id, (s.service_date::timestamptz) AS event_date, s.odometer_km AS odometer_km, s.note AS note, s.user_id AS source_user_id
        FROM services s
        WHERE s.vehicle_id = p_vehicle_id
          AND (p_from IS NULL OR (s.service_date::timestamptz) >= p_from)
          AND (p_to IS NULL OR (s.service_date::timestamptz) <= p_to)

        UNION ALL

        SELECT e.id AS event_id, 'MANUAL' AS event_type, e.id AS source_id, e.entry_date AS event_date, e.value_km AS odometer_km, e.note AS note, NULL::uuid AS source_user_id
        FROM odometer_entries e
        WHERE e.vehicle_id = p_vehicle_id
          AND (p_from IS NULL OR e.entry_date >= p_from)
          AND (p_to IS NULL OR e.entry_date <= p_to)
    )
    ORDER BY event_date DESC
    LIMIT p_limit;
END;
$$;
