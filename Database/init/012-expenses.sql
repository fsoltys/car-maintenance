SET search_path TO car_app, public;

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_expenses_monthly AS
SELECT
    vehicle_id,
    date_trunc('month', expense_date)::date AS month,
    category,
    SUM(amount) AS total_amount,
    COUNT(*) AS cnt
FROM expenses
GROUP BY vehicle_id, month, category;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_expenses_vehicle_month_cat ON mv_expenses_monthly(vehicle_id, month, category);

CREATE OR REPLACE FUNCTION car_app.fn_refresh_mv_expenses_monthly()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE 'REFRESH MATERIALIZED VIEW CONCURRENTLY car_app.mv_expenses_monthly';
EXCEPTION WHEN SQLSTATE '42P07' THEN
    EXECUTE 'REFRESH MATERIALIZED VIEW car_app.mv_expenses_monthly';
END;
$$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron') THEN
        CREATE EXTENSION IF NOT EXISTS pg_cron;
        PERFORM cron.schedule(
            'daily_refresh_mv_expenses_monthly',
            '0 3 * * *',
            $SQL$SELECT car_app.fn_refresh_mv_expenses_monthly();$SQL$
        );
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_get_vehicle_expenses(
    p_user_id uuid,
    p_vehicle_id uuid,
    p_from date DEFAULT NULL,
    p_to date DEFAULT NULL,
    p_category text DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    vehicle_id uuid,
    user_id uuid,
    expense_date date,
    category expense_category,
    amount numeric,
    vat_rate numeric,
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
    SELECT e.id, e.vehicle_id, e.user_id, e.expense_date, e.category, e.amount, e.vat_rate, e.note, e.created_at
    FROM expenses e
    WHERE e.vehicle_id = p_vehicle_id
      AND (p_from IS NULL OR e.expense_date >= p_from)
      AND (p_to IS NULL OR e.expense_date <= p_to)
      AND (p_category IS NULL OR e.category::text = p_category)
    ORDER BY e.expense_date DESC;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_create_expense(
    p_user_id uuid,
    p_vehicle_id uuid,
    p_expense_date date,
    p_category text,
    p_amount numeric,
    p_vat_rate numeric DEFAULT NULL,
    p_note text DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    vehicle_id uuid,
    user_id uuid,
    expense_date date,
    category expense_category,
    amount numeric,
    vat_rate numeric,
    note text,
    created_at timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner uuid;
    v_row expenses%ROWTYPE;
BEGIN
    SELECT v.owner_id INTO v_owner FROM vehicles v WHERE v.id = p_vehicle_id;
    IF v_owner IS NULL THEN
        RETURN;
    END IF;

    IF v_owner <> p_user_id THEN
        IF NOT EXISTS (SELECT 1 FROM vehicle_shares s WHERE s.vehicle_id = p_vehicle_id AND s.user_id = p_user_id AND s.role IN ('OWNER','EDITOR')) THEN
            RETURN;
        END IF;
    END IF;

    INSERT INTO expenses (id, vehicle_id, user_id, expense_date, category, amount, vat_rate, note, created_at)
    VALUES (gen_random_uuid(), p_vehicle_id, p_user_id, p_expense_date, p_category::expense_category, p_amount, p_vat_rate, p_note, now())
    RETURNING * INTO v_row;

    RETURN QUERY SELECT v_row.id, v_row.vehicle_id, v_row.user_id, v_row.expense_date, v_row.category, v_row.amount, v_row.vat_rate, v_row.note, v_row.created_at;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_update_expense(
    p_user_id uuid,
    p_expense_id uuid,
    p_expense_date date DEFAULT NULL,
    p_category text DEFAULT NULL,
    p_amount numeric DEFAULT NULL,
    p_vat_rate numeric DEFAULT NULL,
    p_note text DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    vehicle_id uuid,
    user_id uuid,
    expense_date date,
    category expense_category,
    amount numeric,
    vat_rate numeric,
    note text,
    created_at timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_row expenses%ROWTYPE;
    v_vehicle_id uuid;
    v_owner uuid;
    v_allowed boolean := false;
BEGIN
    SELECT e.* INTO v_row FROM expenses e WHERE e.id = p_expense_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    v_vehicle_id := v_row.vehicle_id;
    SELECT v.owner_id INTO v_owner FROM vehicles v WHERE v.id = v_vehicle_id;

    IF v_row.user_id = p_user_id THEN
        v_allowed := true;
    ELSE
        IF v_owner = p_user_id THEN
            v_allowed := true;
        ELSE
            IF EXISTS (SELECT 1 FROM vehicle_shares s WHERE s.vehicle_id = v_vehicle_id AND s.user_id = p_user_id AND s.role IN ('OWNER','EDITOR')) THEN
                v_allowed := true;
            END IF;
        END IF;
    END IF;

    IF NOT v_allowed THEN
        RETURN;
    END IF;

    UPDATE expenses SET
        expense_date = COALESCE(p_expense_date, expense_date),
        category = COALESCE(p_category::expense_category, category),
        amount = COALESCE(p_amount, amount),
        vat_rate = COALESCE(p_vat_rate, vat_rate),
        note = COALESCE(p_note, note)
    WHERE id = p_expense_id
    RETURNING * INTO v_row;

    RETURN QUERY SELECT v_row.id, v_row.vehicle_id, v_row.user_id, v_row.expense_date, v_row.category, v_row.amount, v_row.vat_rate, v_row.note, v_row.created_at;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_delete_expense(
    p_user_id uuid,
    p_expense_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_row expenses%ROWTYPE;
    v_vehicle_id uuid;
    v_owner uuid;
    v_deleted int;
    v_allowed boolean := false;
BEGIN
    SELECT e.* INTO v_row FROM expenses e WHERE e.id = p_expense_id;
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    v_vehicle_id := v_row.vehicle_id;
    SELECT v.owner_id INTO v_owner FROM vehicles v WHERE v.id = v_vehicle_id;

    IF v_row.user_id = p_user_id THEN
        v_allowed := true;
    ELSE
        IF v_owner = p_user_id THEN
            v_allowed := true;
        END IF;
    END IF;

    IF NOT v_allowed THEN
        RETURN FALSE;
    END IF;

    DELETE FROM expenses WHERE id = p_expense_id;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN v_deleted > 0;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_get_vehicle_expenses_summary(
    p_user_id uuid,
    p_vehicle_id uuid,
    p_from date DEFAULT NULL,
    p_to date DEFAULT NULL
)
RETURNS TABLE (
    total_amount numeric,
    period_km numeric,
    cost_per_100km numeric,
    per_category jsonb,
    monthly_series jsonb
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total numeric := 0;
    v_min_k numeric;
    v_max_k numeric;
    v_period_k numeric := NULL;
    v_cost_per_100 numeric := NULL;
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

    SELECT COALESCE(SUM(amount),0) INTO v_total
    FROM expenses e
    WHERE e.vehicle_id = p_vehicle_id
      AND (p_from IS NULL OR e.expense_date >= p_from)
      AND (p_to IS NULL OR e.expense_date <= p_to);

    SELECT jsonb_agg(row_to_json(t)) INTO STRICT per_category
    FROM (
        SELECT category::text AS category, SUM(amount) AS total_amount, COUNT(*) AS cnt
        FROM expenses
        WHERE vehicle_id = p_vehicle_id
          AND (p_from IS NULL OR expense_date >= p_from)
          AND (p_to IS NULL OR expense_date <= p_to)
        GROUP BY category
    ) t;

    SELECT jsonb_agg(row_to_json(t)) INTO STRICT monthly_series
    FROM (
        SELECT month::date AS month, category::text AS category, total_amount, cnt
        FROM mv_expenses_monthly m
        WHERE m.vehicle_id = p_vehicle_id
          AND (p_from IS NULL OR m.month >= date_trunc('month', p_from)::date)
          AND (p_to IS NULL OR m.month <= date_trunc('month', p_to)::date)
        ORDER BY m.month ASC
    ) t;

    SELECT MIN(h.odometer_km), MAX(h.odometer_km) INTO v_min_k, v_max_k
    FROM car_app.fn_get_vehicle_odometer_history(p_user_id, p_vehicle_id, (p_from::timestamptz), (p_to::timestamptz), 10000) h;

    IF v_min_k IS NOT NULL AND v_max_k IS NOT NULL THEN
        v_period_k := v_max_k - v_min_k;
    END IF;

    IF v_period_k IS NOT NULL AND v_period_k > 0 THEN
        v_cost_per_100 := v_total / (v_period_k / 100.0);
    ELSE
        v_cost_per_100 := NULL;
    END IF;

    total_amount := v_total;
    period_km := v_period_k;
    cost_per_100km := v_cost_per_100;

    RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_fueling_to_expense()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM
    INSERT INTO expenses (id, vehicle_id, user_id, expense_date, category, amount, note, created_at)
    VALUES (gen_random_uuid(), NEW.vehicle_id, NEW.user_id, NEW.filled_at::date, 'FUEL'::expense_category, (NEW.price_per_unit * NEW.volume), NEW.note, now());

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_fueling_to_expense
AFTER INSERT ON fuelings
FOR EACH ROW
EXECUTE FUNCTION car_app.fn_fueling_to_expense();

CREATE OR REPLACE FUNCTION car_app.fn_service_to_expense()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM
    INSERT INTO expenses (id, vehicle_id, user_id, expense_date, category, amount, note, created_at)
    VALUES (gen_random_uuid(), NEW.vehicle_id, NEW.user_id, NEW.service_date, 'SERVICE'::expense_category, NEW.total_cost, NEW.note, now());

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_service_to_expense
AFTER INSERT ON services
FOR EACH ROW
EXECUTE FUNCTION car_app.fn_service_to_expense();
