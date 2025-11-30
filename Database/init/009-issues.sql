SET search_path TO car_app, public;


CREATE OR REPLACE FUNCTION car_app.fn_get_vehicle_issues(
    p_user_id uuid,
    p_vehicle_id uuid,
    p_status text DEFAULT NULL,
    p_priority text DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    vehicle_id uuid,
    created_by uuid,
    title text,
    description text,
    priority issue_priority,
    status issue_status,
    created_at timestamptz,
    closed_at timestamptz,
    error_codes varchar
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
    SELECT
        i.id,
        i.vehicle_id,
        i.created_by,
        i.title,
        i.description,
        i.priority,
        i.status,
        i.created_at,
        i.closed_at,
        i.error_codes
    FROM issues i
    WHERE i.vehicle_id = p_vehicle_id
      AND (p_status IS NULL OR i.status::text = p_status)
      AND (p_priority IS NULL OR i.priority::text = p_priority)
    ORDER BY i.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_create_issue(
    p_user_id uuid,
    p_vehicle_id uuid,
    p_title text,
    p_description text,
    p_priority text,
    p_status text,
    p_error_codes text
)
RETURNS TABLE (
    id uuid,
    vehicle_id uuid,
    created_by uuid,
    title text,
    description text,
    priority issue_priority,
    status issue_status,
    created_at timestamptz,
    closed_at timestamptz,
    error_codes varchar
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner uuid;
    v_row issues%ROWTYPE;
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

    INSERT INTO issues (id, vehicle_id, created_by, title, description, priority, status, created_at, closed_at, error_codes)
    VALUES (gen_random_uuid(), p_vehicle_id, p_user_id, p_title, p_description, COALESCE(p_priority::issue_priority, 'MEDIUM'::issue_priority), COALESCE(p_status::issue_status, 'OPEN'::issue_status), now(), NULL, p_error_codes)
    RETURNING * INTO v_row;

    RETURN QUERY SELECT v_row.id, v_row.vehicle_id, v_row.created_by, v_row.title, v_row.description, v_row.priority, v_row.status, v_row.created_at, v_row.closed_at, v_row.error_codes;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_update_issue(
    p_user_id uuid,
    p_issue_id uuid,
    p_title text DEFAULT NULL,
    p_description text DEFAULT NULL,
    p_priority text DEFAULT NULL,
    p_status text DEFAULT NULL,
    p_error_codes text DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    vehicle_id uuid,
    created_by uuid,
    title text,
    description text,
    priority issue_priority,
    status issue_status,
    created_at timestamptz,
    closed_at timestamptz,
    error_codes varchar
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_row issues%ROWTYPE;
    v_vehicle_id uuid;
    v_owner uuid;
    v_allowed boolean := false;
BEGIN
    SELECT i.*
    INTO v_row
    FROM issues i
    WHERE i.id = p_issue_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT v.owner_id
    INTO v_owner
    FROM vehicles v
    WHERE v.id = v_row.vehicle_id;

    v_vehicle_id := v_row.vehicle_id;

    IF v_row.created_by = p_user_id THEN
        v_allowed := true;
    END IF;

    IF NOT v_allowed THEN
        IF v_owner = p_user_id THEN
            v_allowed := true;
        ELSE
            IF EXISTS (
                SELECT 1 FROM vehicle_shares s WHERE s.vehicle_id = v_vehicle_id AND s.user_id = p_user_id AND s.role IN ('OWNER','EDITOR')
            ) THEN
                v_allowed := true;
            END IF;
        END IF;
    END IF;

    IF NOT v_allowed THEN
        RETURN;
    END IF;

    UPDATE issues i SET
        title = COALESCE(p_title, title),
        description = COALESCE(p_description, description),
        priority = COALESCE(p_priority::issue_priority, priority),
        status = COALESCE(p_status::issue_status, status),
        error_codes = COALESCE(p_error_codes, error_codes),
        closed_at = CASE
            WHEN p_status IS NOT NULL AND p_status::text IN ('DONE','CANCELLED') THEN now()
            WHEN p_status IS NOT NULL AND p_status::text = 'OPEN' THEN NULL
            ELSE closed_at
        END
    WHERE i.id = p_issue_id
    RETURNING * INTO v_row;

    RETURN QUERY SELECT v_row.id, v_row.vehicle_id, v_row.created_by, v_row.title, v_row.description, v_row.priority, v_row.status, v_row.created_at, v_row.closed_at, v_row.error_codes;
END;
$$;


CREATE OR REPLACE FUNCTION car_app.fn_delete_issue(
    p_user_id uuid,
    p_issue_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_row issues%ROWTYPE;
    v_vehicle_id uuid;
    v_owner uuid;
    v_deleted int;
    v_allowed boolean := false;
BEGIN

    SELECT i.*
    INTO v_row
    FROM issues i
    WHERE i.id = p_issue_id;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    SELECT v.owner_id
    INTO v_owner
    FROM vehicles v
    WHERE v.id = v_row.vehicle_id;

    v_vehicle_id := v_row.vehicle_id;

    IF v_row.created_by = p_user_id THEN
        v_allowed := true;
    END IF;

    IF NOT v_allowed THEN
        IF v_owner = p_user_id THEN
            v_allowed := true;
        END IF;
    END IF;

    IF NOT v_allowed THEN
        RETURN FALSE;
    END IF;

    DELETE FROM issues i WHERE i.id = p_issue_id;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN v_deleted > 0;
END;
$$;