SET search_path TO car_app, public;

-- Functions for reminders (tables/types already declared in 002-tables.sql)

-- Helper function to get the most recent odometer reading for a vehicle
CREATE OR REPLACE FUNCTION car_app.fn_get_latest_odometer(
	p_vehicle_id uuid
)
RETURNS numeric(10,1)
LANGUAGE plpgsql
AS $$
DECLARE
	v_latest_odometer numeric(10,1);
BEGIN
	-- Get the most recent odometer reading from services, fuelings, or odometer_entries
	SELECT MAX(odometer_km) INTO v_latest_odometer
	FROM (
		SELECT odometer_km FROM services WHERE vehicle_id = p_vehicle_id AND odometer_km IS NOT NULL
		UNION ALL
		SELECT odometer_km FROM fuelings WHERE vehicle_id = p_vehicle_id AND odometer_km IS NOT NULL
		UNION ALL
		SELECT odometer_km FROM odometer_entries WHERE vehicle_id = p_vehicle_id
	) combined_odometers;
	
	RETURN COALESCE(v_latest_odometer, 0);
END;
$$;

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
	is_recurring boolean,
	due_every_days int,
	due_every_km int,
	last_reset_at timestamptz,
	last_reset_odometer_km numeric(10,1),
	next_due_date date,
	next_due_odometer_km numeric(10,1),
	status reminder_status,
	auto_reset_on_service boolean,
	estimated_days_until_due int,
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
	SELECT 
		r.id, 
		r.vehicle_id, 
		r.name, 
		r.description, 
		r.category, 
		r.service_type, 
		r.is_recurring,
		r.due_every_days, 
		r.due_every_km, 
		r.last_reset_at, 
		r.last_reset_odometer_km, 
		r.next_due_date, 
		r.next_due_odometer_km, 
		r.status, 
		r.auto_reset_on_service,
		-- Calculate estimated days for km-based reminders on the fly
		CASE 
			WHEN r.next_due_odometer_km IS NOT NULL THEN
				car_app.fn_estimate_days_until_km_reminder(r.vehicle_id, r.next_due_odometer_km)
			ELSE NULL
		END as estimated_days_until_due,
		r.created_at, 
		r.updated_at
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
	p_is_recurring boolean DEFAULT TRUE,
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
	is_recurring boolean,
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
DECLARE v_row reminder_rules%ROWTYPE; v_owner uuid; v_current_odometer numeric(10,1);
BEGIN
	SELECT v.owner_id INTO v_owner FROM vehicles v WHERE v.id = p_vehicle_id;
	IF v_owner IS NULL THEN RETURN; END IF;
	IF v_owner <> p_user_id THEN
		IF NOT EXISTS (SELECT 1 FROM vehicle_shares s WHERE s.vehicle_id = p_vehicle_id AND s.user_id = p_user_id AND s.role IN ('OWNER','EDITOR')) THEN RETURN; END IF;
	END IF;

	-- Get current odometer reading
	v_current_odometer := fn_get_latest_odometer(p_vehicle_id);

	INSERT INTO reminder_rules (id, vehicle_id, name, description, category, service_type, is_recurring, due_every_days, due_every_km, next_due_date, next_due_odometer_km, status, auto_reset_on_service, created_at, updated_at)
	VALUES (
		gen_random_uuid(), 
		p_vehicle_id, 
		p_name, 
		p_description, 
		p_category, 
		p_service_type, 
		p_is_recurring,
		p_due_every_days, 
		p_due_every_km, 
		CASE WHEN p_due_every_days IS NOT NULL THEN (now()::date + p_due_every_days) ELSE NULL END,
		CASE WHEN p_due_every_km IS NOT NULL THEN (v_current_odometer + p_due_every_km) ELSE NULL END,
		'ACTIVE', 
		p_auto_reset, 
		now(), 
		now()
	)
	RETURNING * INTO v_row;

	RETURN QUERY SELECT v_row.id, v_row.vehicle_id, v_row.name, v_row.description, v_row.category, v_row.service_type, v_row.is_recurring, v_row.due_every_days, v_row.due_every_km, v_row.last_reset_at, v_row.last_reset_odometer_km, v_row.next_due_date, v_row.next_due_odometer_km, v_row.status, v_row.auto_reset_on_service, v_row.created_at, v_row.updated_at;
END;
$$;

CREATE OR REPLACE FUNCTION car_app.fn_update_reminder_rule(
	p_user_id uuid,
	p_rule_id uuid,
	p_name varchar DEFAULT NULL,
	p_description text DEFAULT NULL,
	p_category varchar DEFAULT NULL,
	p_service_type service_type DEFAULT NULL,
	p_is_recurring boolean DEFAULT NULL,
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
	is_recurring boolean,
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
DECLARE 
	v_row reminder_rules%ROWTYPE; 
	v_owner uuid; 
	v_allowed boolean := false;
	v_current_odometer numeric(10,1);
	v_new_due_km int;
BEGIN
	SELECT r.* INTO v_row FROM reminder_rules r WHERE r.id = p_rule_id; IF NOT FOUND THEN RETURN; END IF;
	SELECT v.owner_id INTO v_owner FROM vehicles v WHERE v.id = v_row.vehicle_id;
	IF v_owner = p_user_id OR EXISTS (SELECT 1 FROM vehicle_shares s WHERE s.vehicle_id = v_row.vehicle_id AND s.user_id = p_user_id AND s.role IN ('OWNER','EDITOR')) THEN v_allowed := true; END IF;
	IF NOT v_allowed THEN RETURN; END IF;

	-- Determine the new due_every_km value
	v_new_due_km := COALESCE(p_due_every_km, v_row.due_every_km);

	-- If due_every_km is being updated and there's no last_reset, recalculate next_due_odometer_km from current odometer
	IF p_due_every_km IS NOT NULL AND v_row.last_reset_odometer_km IS NULL THEN
		v_current_odometer := fn_get_latest_odometer(v_row.vehicle_id);
	END IF;

	UPDATE reminder_rules rr SET
		name = COALESCE(p_name, rr.name),
		description = COALESCE(p_description, rr.description),
		category = COALESCE(p_category, rr.category),
		service_type = COALESCE(p_service_type, rr.service_type),
		is_recurring = COALESCE(p_is_recurring, rr.is_recurring),
		due_every_days = COALESCE(p_due_every_days, rr.due_every_days),
		due_every_km = v_new_due_km,
		next_due_odometer_km = CASE 
			WHEN p_due_every_km IS NOT NULL AND v_row.last_reset_odometer_km IS NULL THEN v_current_odometer + p_due_every_km
			WHEN p_due_every_km IS NOT NULL AND v_row.last_reset_odometer_km IS NOT NULL THEN v_row.last_reset_odometer_km + p_due_every_km
			WHEN p_due_every_km IS NULL THEN NULL
			ELSE rr.next_due_odometer_km
		END,
		status = COALESCE(p_status, rr.status),
		auto_reset_on_service = COALESCE(p_auto_reset, rr.auto_reset_on_service),
		updated_at = now()
	WHERE rr.id = p_rule_id
	RETURNING * INTO v_row;

	RETURN QUERY SELECT v_row.id, v_row.vehicle_id, v_row.name, v_row.description, v_row.category, v_row.service_type, v_row.is_recurring, v_row.due_every_days, v_row.due_every_km, v_row.last_reset_at, v_row.last_reset_odometer_km, v_row.next_due_date, v_row.next_due_odometer_km, v_row.status, v_row.auto_reset_on_service, v_row.created_at, v_row.updated_at;
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
	is_recurring boolean,
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
	IF NOT v_allowed THEN RETURN; END IF;

	INSERT INTO reminder_events (id, rule_id, triggered_at, odometer_km, reason) VALUES (gen_random_uuid(), p_rule_id, now(), p_odometer, p_reason) RETURNING * INTO v_event;

	v_rule.last_reset_at := now();
	v_rule.last_reset_odometer_km := p_odometer;

	-- Only recalculate next due dates if reminder is recurring
	IF v_rule.is_recurring THEN
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
	ELSE
		-- For non-recurring reminders, archive after trigger
		v_rule.status := 'ARCHIVED';
	END IF;

	UPDATE reminder_rules rr SET last_reset_at = v_rule.last_reset_at, last_reset_odometer_km = v_rule.last_reset_odometer_km, next_due_date = v_rule.next_due_date, next_due_odometer_km = v_rule.next_due_odometer_km, status = v_rule.status, updated_at = now() WHERE rr.id = p_rule_id RETURNING * INTO v_rule;

	RETURN QUERY SELECT v_rule.id, v_rule.vehicle_id, v_rule.name, v_rule.description, v_rule.category, v_rule.service_type, v_rule.is_recurring, v_rule.due_every_days, v_rule.due_every_km, v_rule.last_reset_at, v_rule.last_reset_odometer_km, v_rule.next_due_date, v_rule.next_due_odometer_km, v_rule.status, v_rule.auto_reset_on_service, v_rule.created_at, v_rule.updated_at;
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

-- Function to estimate days until a kilometer-based reminder is triggered
-- Uses recent historical odometer data to calculate average km/day and predict when the next_due_odometer_km will be reached
-- Prioritizes recent data (last 90 days) to adapt to changes in driving patterns
CREATE OR REPLACE FUNCTION car_app.fn_estimate_days_until_km_reminder(
	p_vehicle_id uuid,
	p_next_due_odometer_km numeric(10,1)
)
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
	v_current_odometer numeric(10,1);
	v_km_remaining numeric(10,1);
	v_avg_km_per_day numeric(10,2);
	v_days_estimated int;
	v_earliest_date timestamptz;
	v_latest_date timestamptz;
	v_earliest_km numeric(10,1);
	v_latest_km numeric(10,1);
	v_days_span int;
	v_km_span numeric(10,1);
	v_lookback_days int;
BEGIN
	-- Get current odometer reading
	v_current_odometer := car_app.fn_get_latest_odometer(p_vehicle_id);
	
	-- If we're already past the due point, return 0
	IF v_current_odometer >= p_next_due_odometer_km THEN
		RETURN 0;
	END IF;
	
	v_km_remaining := p_next_due_odometer_km - v_current_odometer;
	
	-- Try different lookback periods to find recent data
	-- Start with 90 days (prioritize recent patterns), fall back to 180, then 365 days
	FOREACH v_lookback_days IN ARRAY ARRAY[90, 180, 365] LOOP
		-- Calculate average km/day based on recent historical data
		-- This adapts to changes in driving patterns
		WITH all_odometer_data AS (
			SELECT odometer_km, service_date::timestamptz as entry_date
			FROM services
			WHERE vehicle_id = p_vehicle_id 
			  AND odometer_km IS NOT NULL
			  AND service_date >= (now() - (v_lookback_days || ' days')::interval)
			UNION ALL
			SELECT odometer_km, filled_at as entry_date
			FROM fuelings
			WHERE vehicle_id = p_vehicle_id 
			  AND odometer_km IS NOT NULL
			  AND filled_at >= (now() - (v_lookback_days || ' days')::interval)
			UNION ALL
			SELECT value_km as odometer_km, entry_date
			FROM odometer_entries
			WHERE vehicle_id = p_vehicle_id
			  AND entry_date >= (now() - (v_lookback_days || ' days')::interval)
		),
		date_range AS (
			SELECT 
				MIN(entry_date) as earliest_date,
				MAX(entry_date) as latest_date,
				MIN(odometer_km) as earliest_km,
				MAX(odometer_km) as latest_km
			FROM all_odometer_data
		)
		SELECT 
			earliest_date, latest_date, earliest_km, latest_km,
			EXTRACT(EPOCH FROM (latest_date - earliest_date))::int / 86400 as days_span,
			latest_km - earliest_km as km_span
		INTO v_earliest_date, v_latest_date, v_earliest_km, v_latest_km, v_days_span, v_km_span
		FROM date_range;
		
		-- If we have at least 7 days of data with positive km usage, use it
		IF v_days_span IS NOT NULL AND v_days_span >= 7 AND v_km_span IS NOT NULL AND v_km_span > 0 THEN
			EXIT; -- Found sufficient recent data, stop looking
		END IF;
	END LOOP;
	
	-- If we still don't have enough data after trying all periods, return NULL
	IF v_days_span IS NULL OR v_days_span < 7 OR v_km_span IS NULL OR v_km_span <= 0 THEN
		RETURN NULL;
	END IF;
	
	-- Calculate average km per day from the most recent available period
	v_avg_km_per_day := v_km_span / v_days_span::numeric;
	
	-- If average is 0 or negative (vehicle not being used), return NULL
	IF v_avg_km_per_day <= 0 THEN
		RETURN NULL;
	END IF;
	
	-- Calculate estimated days until reminder is due
	v_days_estimated := CEIL(v_km_remaining / v_avg_km_per_day)::int;
	
	RETURN v_days_estimated;
END;
$$;

-- Function to check if a reminder should be marked as DUE based on a time threshold
-- Returns TRUE if the reminder is due within p_days_threshold days
-- Considers both date-based reminders and kilometer-based reminders (estimated)
CREATE OR REPLACE FUNCTION car_app.fn_is_reminder_due_soon(
	p_reminder_id uuid,
	p_days_threshold int DEFAULT 7
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
	v_reminder reminder_rules%ROWTYPE;
	v_days_until_due int;
	v_days_until_date int;
	v_estimated_days_until_km int;
BEGIN
	-- Get the reminder
	SELECT * INTO v_reminder
	FROM reminder_rules
	WHERE id = p_reminder_id;
	
	-- If reminder doesn't exist or is not ACTIVE, return FALSE
	IF v_reminder IS NULL OR v_reminder.status != 'ACTIVE' THEN
		RETURN FALSE;
	END IF;
	
	-- Check date-based reminder
	IF v_reminder.next_due_date IS NOT NULL THEN
		v_days_until_date := (v_reminder.next_due_date - now()::date);
		
		-- If date is overdue or due within threshold, return TRUE
		IF v_days_until_date <= p_days_threshold THEN
			RETURN TRUE;
		END IF;
	END IF;
	
	-- Check kilometer-based reminder
	IF v_reminder.next_due_odometer_km IS NOT NULL THEN
		v_estimated_days_until_km := car_app.fn_estimate_days_until_km_reminder(
			v_reminder.vehicle_id,
			v_reminder.next_due_odometer_km
		);
		
		-- If we have an estimate and it's within threshold, return TRUE
		IF v_estimated_days_until_km IS NOT NULL AND v_estimated_days_until_km <= p_days_threshold THEN
			RETURN TRUE;
		END IF;
	END IF;
	
	RETURN FALSE;
END;
$$;



