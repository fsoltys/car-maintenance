SET search_path TO car_app, public;

-- Functions for reminders (tables/types already declared in 002-tables.sql)

CREATE OR REPLACE FUNCTION car_app.fn_get_vehicle_reminder_rules(
	p_user_id uuid,
	p_vehicle_id uuid
)
RETURNS TABLE (
	id uuid,
	vehicle_id uuid,
	name varchar,
	description text,
	category varchar,
	service_type service_type,
	due_every_days int,
	due_every_km int,
	last_reset_at timestamptz,
	last_reset_odometer_km numeric(10,1),
	next_due_date date,
	next_due_odometer_km numeric(10,1),
	status reminder_status,
	auto_reset_on_service boolean,
	created_at timestamptz,
	updated_at timestamptz
)
LANGUAGE plpgsql
AS $$
BEGIN
	IF NOT EXISTS (
		SELECT 1 FROM vehicles v LEFT JOIN vehicle_shares s ON s.vehicle_id = v.id AND s.user_id = p_user_id
		WHERE v.id = p_vehicle_id AND (v.owner_id = p_user_id OR s.user_id IS NOT NULL)
	) THEN
		RETURN;
	END IF;

	RETURN QUERY
	SELECT r.id, r.vehicle_id, r.name, r.description, r.category, r.service_type, r.due_every_days, r.due_every_km, r.last_reset_at, r.last_reset_odometer_km, r.next_due_date, r.next_due_odometer_km, r.status, r.auto_reset_on_service, r.created_at, r.updated_at
	FROM reminder_rules r
	WHERE r.vehicle_id = p_vehicle_id
	ORDER BY r.next_due_date NULLS LAST, r.next_due_odometer_km NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_create_reminder_rule(
	p_user_id uuid,
	p_vehicle_id uuid,
	p_name varchar,
	p_description text DEFAULT NULL,
	p_category varchar DEFAULT NULL,
	p_service_type service_type DEFAULT NULL,
	p_due_every_days int DEFAULT NULL,
	p_due_every_km int DEFAULT NULL,
	p_auto_reset boolean DEFAULT FALSE
)
RETURNS TABLE (
	id uuid,
	vehicle_id uuid,
	name varchar,
	description text,
	category varchar,
	service_type service_type,
	due_every_days int,
	due_every_km int,
	last_reset_at timestamptz,
	last_reset_odometer_km numeric(10,1),
	next_due_date date,
	next_due_odometer_km numeric(10,1),
	status reminder_status,
	auto_reset_on_service boolean,
	created_at timestamptz,
	updated_at timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE v_row reminder_rules%ROWTYPE; v_owner uuid;
BEGIN
	SELECT v.owner_id INTO v_owner FROM vehicles v WHERE v.id = p_vehicle_id;
	IF v_owner IS NULL THEN RETURN; END IF;
	IF v_owner <> p_user_id THEN
		IF NOT EXISTS (SELECT 1 FROM vehicle_shares s WHERE s.vehicle_id = p_vehicle_id AND s.user_id = p_user_id AND s.role IN ('OWNER','EDITOR')) THEN RETURN; END IF;
	END IF;

	INSERT INTO reminder_rules (id, vehicle_id, name, description, category, service_type, due_every_days, due_every_km, next_due_date, next_due_odometer_km, status, auto_reset_on_service, created_at, updated_at)
	VALUES (gen_random_uuid(), p_vehicle_id, p_name, p_description, p_category, p_service_type, p_due_every_days, p_due_every_km, CASE WHEN p_due_every_days IS NOT NULL THEN (now()::date + p_due_every_days) ELSE NULL END, NULL, 'ACTIVE', p_auto_reset, now(), now())
	RETURNING * INTO v_row;

	RETURN QUERY SELECT v_row.id, v_row.vehicle_id, v_row.name, v_row.description, v_row.category, v_row.service_type, v_row.due_every_days, v_row.due_every_km, v_row.last_reset_at, v_row.last_reset_odometer_km, v_row.next_due_date, v_row.next_due_odometer_km, v_row.status, v_row.auto_reset_on_service, v_row.created_at, v_row.updated_at;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_update_reminder_rule(
	p_user_id uuid,
	p_rule_id uuid,
	p_name varchar DEFAULT NULL,
	p_description text DEFAULT NULL,
	p_category varchar DEFAULT NULL,
	p_service_type service_type DEFAULT NULL,
	p_due_every_days int DEFAULT NULL,
	p_due_every_km int DEFAULT NULL,
	p_status reminder_status DEFAULT NULL,
	p_auto_reset boolean DEFAULT NULL
)
RETURNS TABLE (
	id uuid,
	vehicle_id uuid,
	name varchar,
	description text,
	category varchar,
	service_type service_type,
	due_every_days int,
	due_every_km int,
	last_reset_at timestamptz,
	last_reset_odometer_km numeric(10,1),
	next_due_date date,
	next_due_odometer_km numeric(10,1),
	status reminder_status,
	auto_reset_on_service boolean,
	created_at timestamptz,
	updated_at timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE v_row reminder_rules%ROWTYPE; v_owner uuid; v_allowed boolean := false;
BEGIN
	SELECT r.* INTO v_row FROM reminder_rules r WHERE r.id = p_rule_id; IF NOT FOUND THEN RETURN; END IF;
	SELECT v.owner_id INTO v_owner FROM vehicles v WHERE v.id = v_row.vehicle_id;
	IF v_owner = p_user_id OR EXISTS (SELECT 1 FROM vehicle_shares s WHERE s.vehicle_id = v_row.vehicle_id AND s.user_id = p_user_id AND s.role IN ('OWNER','EDITOR')) THEN v_allowed := true; END IF;
	IF NOT v_allowed THEN RETURN; END IF;

	UPDATE reminder_rules rr SET
		name = COALESCE(p_name, rr.name),
		description = COALESCE(p_description, rr.description),
		category = COALESCE(p_category, rr.category),
		service_type = COALESCE(p_service_type, rr.service_type),
		due_every_days = COALESCE(p_due_every_days, rr.due_every_days),
		due_every_km = COALESCE(p_due_every_km, rr.due_every_km),
		status = COALESCE(p_status, rr.status),
		auto_reset_on_service = COALESCE(p_auto_reset, rr.auto_reset_on_service),
		updated_at = now()
	WHERE rr.id = p_rule_id
	RETURNING * INTO v_row;

	RETURN QUERY SELECT v_row.id, v_row.vehicle_id, v_row.name, v_row.description, v_row.category, v_row.service_type, v_row.due_every_days, v_row.due_every_km, v_row.last_reset_at, v_row.last_reset_odometer_km, v_row.next_due_date, v_row.next_due_odometer_km, v_row.status, v_row.auto_reset_on_service, v_row.created_at, v_row.updated_at;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_delete_reminder_rule(
	p_user_id uuid,
	p_rule_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE v_row reminder_rules%ROWTYPE; v_owner uuid; v_allowed boolean := false; v_deleted int;
BEGIN
	SELECT r.* INTO v_row FROM reminder_rules r WHERE r.id = p_rule_id; IF NOT FOUND THEN RETURN FALSE; END IF;
	SELECT v.owner_id INTO v_owner FROM vehicles v WHERE v.id = v_row.vehicle_id;
	IF v_owner = p_user_id OR EXISTS (SELECT 1 FROM vehicle_shares s WHERE s.vehicle_id = v_row.vehicle_id AND s.user_id = p_user_id AND s.role = 'OWNER') THEN v_allowed := true; END IF;
	IF NOT v_allowed THEN RETURN FALSE; END IF;

	DELETE FROM reminder_rules rr WHERE rr.id = p_rule_id; GET DIAGNOSTICS v_deleted = ROW_COUNT; RETURN v_deleted > 0;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_trigger_reminder(
	p_user_id uuid,
	p_rule_id uuid,
	p_reason varchar DEFAULT NULL,
	p_odometer numeric DEFAULT NULL
)
RETURNS TABLE (
	id uuid,
	vehicle_id uuid,
	name varchar,
	description text,
	category varchar,
	service_type service_type,
	due_every_days int,
	due_every_km int,
	last_reset_at timestamptz,
	last_reset_odometer_km numeric(10,1),
	next_due_date date,
	next_due_odometer_km numeric(10,1),
	status reminder_status,
	auto_reset_on_service boolean,
	created_at timestamptz,
	updated_at timestamptz
)
LANGUAGE plpgsql
AS $$
DECLARE v_rule reminder_rules%ROWTYPE; v_event reminder_events%ROWTYPE; v_owner uuid; v_allowed boolean := false;
BEGIN
	SELECT r.* INTO v_rule FROM reminder_rules r WHERE r.id = p_rule_id; IF NOT FOUND THEN RETURN; END IF;
	SELECT v.owner_id INTO v_owner FROM vehicles v WHERE v.id = v_rule.vehicle_id;
	IF v_owner = p_user_id OR EXISTS (SELECT 1 FROM vehicle_shares s WHERE s.vehicle_id = v_rule.vehicle_id AND s.user_id = p_user_id) THEN v_allowed := true; END IF;
	IF NOT v_allowed OR v_rule.status <> 'ACTIVE' THEN RETURN; END IF;

	INSERT INTO reminder_events (id, rule_id, triggered_at, odometer_km, reason) VALUES (gen_random_uuid(), p_rule_id, now(), p_odometer, p_reason) RETURNING * INTO v_event;

	v_rule.last_reset_at := now();
	v_rule.last_reset_odometer_km := p_odometer;

	IF v_rule.due_every_days IS NOT NULL THEN
		v_rule.next_due_date := (now()::date + v_rule.due_every_days);
	END IF;

	IF v_rule.due_every_km IS NOT NULL THEN
		IF p_odometer IS NOT NULL THEN
			v_rule.next_due_odometer_km := p_odometer + v_rule.due_every_km;
		ELSE
			v_rule.next_due_odometer_km := COALESCE(v_rule.next_due_odometer_km, 0) + v_rule.due_every_km;
		END IF;
	END IF;

	UPDATE reminder_rules rr SET last_reset_at = v_rule.last_reset_at, last_reset_odometer_km = v_rule.last_reset_odometer_km, next_due_date = v_rule.next_due_date, next_due_odometer_km = v_rule.next_due_odometer_km, updated_at = now() WHERE rr.id = p_rule_id RETURNING * INTO v_rule;

	RETURN QUERY SELECT v_rule.id, v_rule.vehicle_id, v_rule.name, v_rule.description, v_rule.category, v_rule.service_type, v_rule.due_every_days, v_rule.due_every_km, v_rule.last_reset_at, v_rule.last_reset_odometer_km, v_rule.next_due_date, v_rule.next_due_odometer_km, v_rule.status, v_rule.auto_reset_on_service, v_rule.created_at, v_rule.updated_at;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_get_upcoming_reminders(
	p_user_id uuid,
	p_vehicle_id uuid DEFAULT NULL,
	p_days_ahead int DEFAULT 30
)
RETURNS TABLE (
	id uuid,
	vehicle_id uuid,
	name varchar,
	description text,
	next_due_date date,
	next_due_odometer_km numeric(10,1)
)
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY
	SELECT r.id, r.vehicle_id, r.name, r.description, r.next_due_date, r.next_due_odometer_km
	FROM reminder_rules r
	JOIN vehicles v ON v.id = r.vehicle_id
	LEFT JOIN vehicle_shares s ON s.vehicle_id = v.id AND s.user_id = p_user_id
	WHERE (p_vehicle_id IS NULL OR r.vehicle_id = p_vehicle_id)
	  AND (v.owner_id = p_user_id OR s.user_id IS NOT NULL)
	  AND r.status = 'ACTIVE'
	  AND (
			(r.next_due_date IS NOT NULL AND r.next_due_date <= (now()::date + p_days_ahead))
		 OR (r.next_due_odometer_km IS NOT NULL)
	  )
	ORDER BY r.next_due_date NULLS LAST;
END;
$$;


