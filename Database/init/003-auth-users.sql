SET search_path TO car_app, public;

-- 1) Rejestracja użytkownika

CREATE OR REPLACE FUNCTION fn_register_user(
    p_user_id        uuid,
    p_email          varchar,
    p_password_hash  text,
    p_display_name   varchar DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing_id      uuid;
    v_email_normalized varchar;
BEGIN
    v_email_normalized := lower(trim(p_email));

    SELECT u.id
    INTO v_existing_id
    FROM users u
    WHERE u.email = v_email_normalized;

    IF v_existing_id IS NOT NULL THEN
        RAISE EXCEPTION 'Email % is already registered', v_email_normalized
            USING ERRCODE = '23505',  
                  HINT = 'Use a different email address.';
    END IF;

    INSERT INTO users (id, email, password_hash, display_name, created_at, updated_at)
    VALUES (
        p_user_id,
        v_email_normalized,
        p_password_hash,
        p_display_name,
        now(),
        now()
    );

    RETURN p_user_id;
END;
$$;

-- 2) Pobranie użytkownika po emailu na potrzeby logowania

CREATE OR REPLACE FUNCTION fn_get_user_for_login(
    p_email varchar
)
RETURNS TABLE (
    id            uuid,
    email         varchar,
    password_hash text,
    display_name  varchar,
    created_at    timestamptz,
    updated_at    timestamptz
)
LANGUAGE sql
AS $$
    SELECT
        u.id,
        u.email,
        u.password_hash,
        u.display_name,
        u.created_at,
        u.updated_at
    FROM users u
    WHERE lower(u.email) = lower(trim(p_email))
$$;

-- 3) Pobranie profilu użytkownika (bez hasła)

CREATE OR REPLACE FUNCTION fn_get_user_profile(
    p_user_id uuid
)
RETURNS TABLE (
    id           uuid,
    email        varchar,
    display_name varchar,
    created_at   timestamptz,
    updated_at   timestamptz
)
LANGUAGE sql
AS $$
    SELECT
        u.id,
        u.email,
        u.display_name,
        u.created_at,
        u.updated_at
    FROM users u
    WHERE u.id = p_user_id
$$;

SET search_path TO car_app, public;


-- 4) Aktualizacja profilu użytkownika (display_name)


CREATE OR REPLACE FUNCTION car_app.fn_update_user_profile(
    p_user_id       uuid,
    p_display_name  text
)
RETURNS TABLE (
    id           uuid,
    email        varchar(255),
    display_name varchar(120),
    created_at   timestamptz,
    updated_at   timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_row users%ROWTYPE;
BEGIN
    UPDATE users u
    SET
        display_name = p_display_name,
        updated_at   = now()
    WHERE u.id = p_user_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
        -- użytkownik nie istnieje
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        v_row.id,
        v_row.email,
        v_row.display_name,
        v_row.created_at,
        v_row.updated_at;
END;
$$;


-- 5) Aktualizacja hasła użytkownika


CREATE OR REPLACE FUNCTION car_app.fn_update_user_password(
    p_user_id       uuid,
    p_password_hash text
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_affected int;
BEGIN
    UPDATE users u
    SET
        password_hash = p_password_hash,
        updated_at    = now()
    WHERE u.id = p_user_id;

    GET DIAGNOSTICS v_affected = ROW_COUNT;

    RETURN v_affected > 0;
END;
$$;

