SET search_path TO car_app, public;


CREATE OR REPLACE FUNCTION car_app.fn_get_vehicle_documents(
    p_user_id uuid,
    p_vehicle_id uuid
)
RETURNS TABLE (
    id uuid,
    vehicle_id uuid,
    doc_type document_type,
    number varchar,
    provider varchar,
    issue_date date,
    valid_from date,
    valid_to date,
    note text,
    created_at timestamptz
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
        d.id,
        d.vehicle_id,
        d.doc_type,
        d.number,
        d.provider,
        d.issue_date,
        d.valid_from,
        d.valid_to,
        d.note,
        d.created_at
    FROM documents d
    WHERE d.vehicle_id = p_vehicle_id
    ORDER BY d.valid_to NULLS LAST, d.created_at DESC;
END;
$$;


CREATE OR REPLACE FUNCTION car_app.fn_create_document(
    p_user_id uuid,
    p_vehicle_id uuid,
    p_doc_type text,
    p_number text,
    p_provider text,
    p_issue_date date,
    p_valid_from date,
    p_valid_to date,
    p_note text
)
RETURNS TABLE (
    id uuid,
    vehicle_id uuid,
    doc_type document_type,
    number varchar,
    provider varchar,
    issue_date date,
    valid_from date,
    valid_to date,
    note text,
    created_at timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner uuid;
    v_row documents%ROWTYPE;
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

    INSERT INTO documents (id, vehicle_id, doc_type, number, provider, issue_date, valid_from, valid_to, note, created_at)
    VALUES (gen_random_uuid(), p_vehicle_id, p_doc_type::document_type, p_number, p_provider, p_issue_date, p_valid_from, p_valid_to, p_note, now())
    RETURNING * INTO v_row;

    RETURN QUERY SELECT v_row.id, v_row.vehicle_id, v_row.doc_type, v_row.number, v_row.provider, v_row.issue_date, v_row.valid_from, v_row.valid_to, v_row.note, v_row.created_at;
END;
$$;


CREATE OR REPLACE FUNCTION car_app.fn_update_document(
    p_user_id uuid,
    p_document_id uuid,
    p_doc_type text DEFAULT NULL,
    p_number text DEFAULT NULL,
    p_provider text DEFAULT NULL,
    p_issue_date date DEFAULT NULL,
    p_valid_from date DEFAULT NULL,
    p_valid_to date DEFAULT NULL,
    p_note text DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    vehicle_id uuid,
    doc_type document_type,
    number varchar,
    provider varchar,
    issue_date date,
    valid_from date,
    valid_to date,
    note text,
    created_at timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_row documents%ROWTYPE;
    v_owner uuid;
    v_vehicle_id uuid;
    v_allowed boolean := false;
BEGIN
    SELECT d.*
    INTO v_row
    FROM documents d
    WHERE d.id = p_document_id;

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

    UPDATE documents SET
        doc_type = COALESCE(p_doc_type::document_type, doc_type),
        number = COALESCE(p_number, number),
        provider = COALESCE(p_provider, provider),
        issue_date = COALESCE(p_issue_date, issue_date),
        valid_from = COALESCE(p_valid_from, valid_from),
        valid_to = COALESCE(p_valid_to, valid_to),
        note = COALESCE(p_note, note)
    WHERE id = p_document_id
    RETURNING * INTO v_row;

    RETURN QUERY SELECT v_row.id, v_row.vehicle_id, v_row.doc_type, v_row.number, v_row.provider, v_row.issue_date, v_row.valid_from, v_row.valid_to, v_row.note, v_row.created_at;
END;
$$;


CREATE OR REPLACE FUNCTION car_app.fn_delete_document(
    p_user_id uuid,
    p_document_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_row documents%ROWTYPE;
    v_vehicle_id uuid;
    v_owner uuid;
    v_deleted int;
    v_allowed boolean := false;
BEGIN
    SELECT d.*
    INTO v_row
    FROM documents d
    WHERE d.id = p_document_id;

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

    DELETE FROM documents WHERE id = p_document_id;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN v_deleted > 0;
END;
$$;
