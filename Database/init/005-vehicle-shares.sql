SET search_path TO car_app, public;

-- 1) Lista współdzielących pojazd (tylko OWNER)

CREATE OR REPLACE FUNCTION fn_get_vehicle_shares(
    p_actor_id   uuid,
    p_vehicle_id uuid
)
RETURNS TABLE (
    user_id     uuid,
    email       varchar,
    display_name varchar,
    role        role_type,
    invited_at  timestamptz,
    is_owner    boolean
)
LANGUAGE sql
AS $$
    SELECT
        COALESCE(s.user_id, v.owner_id)               AS user_id,
        u.email,
        u.display_name,
        COALESCE(s.role, 'OWNER'::role_type)          AS role,
        s.invited_at,
        (COALESCE(s.user_id, v.owner_id) = v.owner_id) AS is_owner
    FROM vehicles v
    JOIN users u_owner
      ON u_owner.id = v.owner_id
    LEFT JOIN vehicle_shares s
      ON s.vehicle_id = v.id
    LEFT JOIN users u
      ON u.id = COALESCE(s.user_id, v.owner_id)
    WHERE v.id = p_vehicle_id
      AND v.owner_id = p_actor_id      -- tylko owner może zobaczyć listę
    ORDER BY is_owner DESC, u.email
$$;

-- 2) Dodanie / nadpisanie udziału (tylko OWNER)

CREATE OR REPLACE FUNCTION fn_add_vehicle_share(
    p_actor_id     uuid,
    p_vehicle_id   uuid,
    p_target_email varchar,
    p_role         role_type
)
RETURNS TABLE (
    user_id     uuid,
    email       varchar,
    display_name varchar,
    role        role_type,
    invited_at  timestamptz,
    is_owner    boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id       uuid;
    v_target_user_id uuid;
BEGIN
    -- sprawdzenie, czy actor jest właścicielem pojazdu
    SELECT owner_id
    INTO v_owner_id
    FROM vehicles
    WHERE id = p_vehicle_id;

    IF v_owner_id IS NULL OR v_owner_id <> p_actor_id THEN
        RETURN;
    END IF;

    -- rola tylko EDITOR / VIEWER (OWNER jest trzymany w vehicles.owner_id)
    IF p_role NOT IN ('EDITOR','VIEWER') THEN
        RAISE EXCEPTION 'Only EDITOR or VIEWER roles are allowed for shares'
            USING ERRCODE = '22023';
    END IF;

    -- lookup usera po emailu
    SELECT u.id
    INTO v_target_user_id
    FROM users u
    WHERE lower(u.email) = lower(trim(p_target_email));

    IF v_target_user_id IS NULL THEN
        RAISE EXCEPTION 'User with email % not found', p_target_email
            USING ERRCODE = 'P0002';
    END IF;

    -- nie tworzymy share dla ownera
    IF v_target_user_id = v_owner_id THEN
        RAISE EXCEPTION 'Cannot share vehicle with its owner'
            USING ERRCODE = '22023';
    END IF;

    -- upsert udziału
    INSERT INTO vehicle_shares (vehicle_id, user_id, role, invited_at)
    VALUES (p_vehicle_id, v_target_user_id, p_role, now())
    ON CONFLICT (vehicle_id, user_id)
    DO UPDATE SET
        role = EXCLUDED.role
    ;

    -- zwracamy aktualny stan udziału
    RETURN QUERY
    SELECT
        s.user_id,
        u.email,
        u.display_name,
        s.role,
        s.invited_at,
        false AS is_owner
    FROM vehicle_shares s
    JOIN users u
      ON u.id = s.user_id
    WHERE s.vehicle_id = p_vehicle_id
      AND s.user_id = v_target_user_id;
END;
$$;

-- 3) Zmiana roli użytkownika (tylko OWNER)

CREATE OR REPLACE FUNCTION fn_update_vehicle_share_role(
    p_actor_id       uuid,
    p_vehicle_id     uuid,
    p_target_user_id uuid,
    p_role           role_type
)
RETURNS TABLE (
    user_id     uuid,
    email       varchar,
    display_name varchar,
    role        role_type,
    invited_at  timestamptz,
    is_owner    boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id uuid;
    v_row      vehicle_shares%ROWTYPE;
BEGIN
    SELECT owner_id
    INTO v_owner_id
    FROM vehicles
    WHERE id = p_vehicle_id;

    IF v_owner_id IS NULL OR v_owner_id <> p_actor_id THEN
        RETURN;
    END IF;

    IF p_role NOT IN ('EDITOR','VIEWER') THEN
        RAISE EXCEPTION 'Only EDITOR or VIEWER roles are allowed for shares'
            USING ERRCODE = '22023';
    END IF;

    IF p_target_user_id = v_owner_id THEN
        RAISE EXCEPTION 'Cannot change owner role through shares'
            USING ERRCODE = '22023';
    END IF;

    UPDATE vehicle_shares s
    SET role = p_role
    WHERE s.vehicle_id = p_vehicle_id
      AND s.user_id = p_target_user_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        v_row.user_id,
        u.email,
        u.display_name,
        v_row.role,
        v_row.invited_at,
        false AS is_owner
    FROM users u
    WHERE u.id = v_row.user_id;
END;
$$;

-- 4) Usunięcie udziału (tylko OWNER)

CREATE OR REPLACE FUNCTION fn_remove_vehicle_share(
    p_actor_id       uuid,
    p_vehicle_id     uuid,
    p_target_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id uuid;
    v_deleted  int;
BEGIN
    SELECT owner_id
    INTO v_owner_id
    FROM vehicles
    WHERE id = p_vehicle_id;

    IF v_owner_id IS NULL OR v_owner_id <> p_actor_id THEN
        RETURN FALSE;
    END IF;

    IF p_target_user_id = v_owner_id THEN
        RAISE EXCEPTION 'Cannot remove owner from shares'
            USING ERRCODE = '22023';
    END IF;

    DELETE FROM vehicle_shares s
    WHERE s.vehicle_id = p_vehicle_id
      AND s.user_id = p_target_user_id;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN v_deleted > 0;
END;
$$;
