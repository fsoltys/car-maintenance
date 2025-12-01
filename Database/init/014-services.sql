SET search_path TO car_app, public;

-- Get all services for a vehicle
-- Returns services if user has access to the vehicle (OWNER/EDITOR/VIEWER)
CREATE OR REPLACE FUNCTION fn_get_vehicle_services(
    p_user_id UUID,
    p_vehicle_id UUID
)
RETURNS TABLE (
    id UUID,
    vehicle_id UUID,
    user_id UUID,
    service_date DATE,
    service_type service_type,
    odometer_km NUMERIC(10,1),
    total_cost NUMERIC(12,2),
    reference VARCHAR(64),
    note TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user has access to vehicle
    IF NOT EXISTS (
        SELECT 1 FROM vehicles v
        LEFT JOIN vehicle_shares vs ON v.id = vs.vehicle_id
        WHERE v.id = p_vehicle_id
          AND (v.owner_id = p_user_id OR vs.user_id = p_user_id)
    ) THEN
        -- Return empty set (404 will be handled by API)
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        s.id,
        s.vehicle_id,
        s.user_id,
        s.service_date,
        s.service_type,
        s.odometer_km,
        s.total_cost,
        s.reference,
        s.note,
        s.created_at
    FROM services s
    WHERE s.vehicle_id = p_vehicle_id
    ORDER BY s.service_date DESC, s.created_at DESC;
END;
$$;

-- Get single service by ID
-- Returns service if user has access to the vehicle
CREATE OR REPLACE FUNCTION fn_get_service(
    p_user_id UUID,
    p_service_id UUID
)
RETURNS TABLE (
    id UUID,
    vehicle_id UUID,
    user_id UUID,
    service_date DATE,
    service_type service_type,
    odometer_km NUMERIC(10,1),
    total_cost NUMERIC(12,2),
    reference VARCHAR(64),
    note TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id,
        s.vehicle_id,
        s.user_id,
        s.service_date,
        s.service_type,
        s.odometer_km,
        s.total_cost,
        s.reference,
        s.note,
        s.created_at
    FROM services s
    INNER JOIN vehicles v ON s.vehicle_id = v.id
    LEFT JOIN vehicle_shares vs ON v.id = vs.vehicle_id
    WHERE s.id = p_service_id
      AND (v.owner_id = p_user_id OR vs.user_id = p_user_id);
END;
$$;

-- Create new service
-- Only OWNER or EDITOR can create services
CREATE OR REPLACE FUNCTION fn_create_service(
    p_user_id UUID,
    p_vehicle_id UUID,
    p_service_date DATE,
    p_service_type service_type,
    p_odometer_km NUMERIC(10,1) DEFAULT NULL,
    p_total_cost NUMERIC(12,2) DEFAULT NULL,
    p_reference VARCHAR(64) DEFAULT NULL,
    p_note TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    vehicle_id UUID,
    user_id UUID,
    service_date DATE,
    service_type service_type,
    odometer_km NUMERIC(10,1),
    total_cost NUMERIC(12,2),
    reference VARCHAR(64),
    note TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
    v_service_id UUID;
    v_is_owner BOOLEAN;
    v_role role_type;
BEGIN
    -- Check if user is OWNER
    SELECT (owner_id = p_user_id) INTO v_is_owner
    FROM vehicles
    WHERE vehicles.id = p_vehicle_id;

    -- If not owner, check if user is EDITOR
    IF v_is_owner IS NULL THEN
        -- Vehicle doesn't exist
        RETURN;
    END IF;

    IF NOT v_is_owner THEN
        SELECT role INTO v_role
        FROM vehicle_shares
        WHERE vehicle_id = p_vehicle_id AND user_id = p_user_id;

        IF v_role IS NULL OR v_role = 'VIEWER' THEN
            -- No permission (not owner, not editor)
            RETURN;
        END IF;
    END IF;

    -- Create service
    v_service_id := gen_random_uuid();

    INSERT INTO services (
        id,
        vehicle_id,
        user_id,
        service_date,
        service_type,
        odometer_km,
        total_cost,
        reference,
        note,
        created_at
    ) VALUES (
        v_service_id,
        p_vehicle_id,
        p_user_id,
        p_service_date,
        p_service_type,
        p_odometer_km,
        p_total_cost,
        p_reference,
        p_note,
        NOW()
    );

    RETURN QUERY
    SELECT
        s.id,
        s.vehicle_id,
        s.user_id,
        s.service_date,
        s.service_type,
        s.odometer_km,
        s.total_cost,
        s.reference,
        s.note,
        s.created_at
    FROM services s
    WHERE s.id = v_service_id;
END;
$$;

-- Update service
-- Only OWNER or EDITOR can update services
CREATE OR REPLACE FUNCTION fn_update_service(
    p_user_id UUID,
    p_service_id UUID,
    p_service_date DATE,
    p_service_type service_type,
    p_odometer_km NUMERIC(10,1) DEFAULT NULL,
    p_total_cost NUMERIC(12,2) DEFAULT NULL,
    p_reference VARCHAR(64) DEFAULT NULL,
    p_note TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    vehicle_id UUID,
    user_id UUID,
    service_date DATE,
    service_type service_type,
    odometer_km NUMERIC(10,1),
    total_cost NUMERIC(12,2),
    reference VARCHAR(64),
    note TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
    v_vehicle_id UUID;
    v_is_owner BOOLEAN;
    v_role role_type;
BEGIN
    -- Get vehicle_id for this service
    SELECT s.vehicle_id INTO v_vehicle_id
    FROM services s
    WHERE s.id = p_service_id;

    IF v_vehicle_id IS NULL THEN
        -- Service doesn't exist
        RETURN;
    END IF;

    -- Check if user is OWNER
    SELECT (owner_id = p_user_id) INTO v_is_owner
    FROM vehicles
    WHERE id = v_vehicle_id;

    IF NOT v_is_owner THEN
        -- Check if user is EDITOR
        SELECT role INTO v_role
        FROM vehicle_shares
        WHERE vehicle_id = v_vehicle_id AND user_id = p_user_id;

        IF v_role IS NULL OR v_role = 'VIEWER' THEN
            -- No permission
            RETURN;
        END IF;
    END IF;

    -- Update service
    UPDATE services
    SET
        service_date = p_service_date,
        service_type = p_service_type,
        odometer_km = p_odometer_km,
        total_cost = p_total_cost,
        reference = p_reference,
        note = p_note
    WHERE id = p_service_id;

    RETURN QUERY
    SELECT
        s.id,
        s.vehicle_id,
        s.user_id,
        s.service_date,
        s.service_type,
        s.odometer_km,
        s.total_cost,
        s.reference,
        s.note,
        s.created_at
    FROM services s
    WHERE s.id = p_service_id;
END;
$$;

-- Delete service
-- Only OWNER or EDITOR can delete services
CREATE OR REPLACE FUNCTION fn_delete_service(
    p_user_id UUID,
    p_service_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
    v_vehicle_id UUID;
    v_is_owner BOOLEAN;
    v_role role_type;
    v_deleted BOOLEAN := FALSE;
BEGIN
    -- Get vehicle_id for this service
    SELECT s.vehicle_id INTO v_vehicle_id
    FROM services s
    WHERE s.id = p_service_id;

    IF v_vehicle_id IS NULL THEN
        -- Service doesn't exist
        RETURN FALSE;
    END IF;

    -- Check if user is OWNER
    SELECT (owner_id = p_user_id) INTO v_is_owner
    FROM vehicles
    WHERE id = v_vehicle_id;

    IF NOT v_is_owner THEN
        -- Check if user is EDITOR
        SELECT role INTO v_role
        FROM vehicle_shares
        WHERE vehicle_id = v_vehicle_id AND user_id = p_user_id;

        IF v_role IS NULL OR v_role = 'VIEWER' THEN
            -- No permission
            RETURN FALSE;
        END IF;
    END IF;

    -- Delete service
    DELETE FROM services
    WHERE id = p_service_id;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted > 0;
END;
$$;

-- Service Items Functions

-- Get all items for a service
-- Returns items if user has access to the service's vehicle
CREATE OR REPLACE FUNCTION fn_get_service_items(
    p_user_id UUID,
    p_service_id UUID
)
RETURNS TABLE (
    id UUID,
    service_id UUID,
    part_name VARCHAR(160),
    part_number VARCHAR(80),
    quantity NUMERIC(10,2),
    unit_price NUMERIC(12,2)
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user has access to the service
    IF NOT EXISTS (
        SELECT 1 FROM services s
        INNER JOIN vehicles v ON s.vehicle_id = v.id
        LEFT JOIN vehicle_shares vs ON v.id = vs.vehicle_id
        WHERE s.id = p_service_id
          AND (v.owner_id = p_user_id OR vs.user_id = p_user_id)
    ) THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        si.id,
        si.service_id,
        si.part_name,
        si.part_number,
        si.quantity,
        si.unit_price
    FROM service_items si
    WHERE si.service_id = p_service_id
    ORDER BY si.part_name;
END;
$$;

-- Add or update service items (batch operation)
-- Only OWNER or EDITOR can modify service items
-- Accepts JSONB array of items, replaces all existing items
CREATE OR REPLACE FUNCTION fn_set_service_items(
    p_user_id UUID,
    p_service_id UUID,
    p_items JSONB
)
RETURNS TABLE (
    id UUID,
    service_id UUID,
    part_name VARCHAR(160),
    part_number VARCHAR(80),
    quantity NUMERIC(10,2),
    unit_price NUMERIC(12,2)
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
    v_vehicle_id UUID;
    v_is_owner BOOLEAN;
    v_role role_type;
    v_item JSONB;
    v_item_id UUID;
BEGIN
    -- Get vehicle_id for this service
    SELECT s.vehicle_id INTO v_vehicle_id
    FROM services s
    WHERE s.id = p_service_id;

    IF v_vehicle_id IS NULL THEN
        RETURN;
    END IF;

    -- Check if user is OWNER
    SELECT (owner_id = p_user_id) INTO v_is_owner
    FROM vehicles
    WHERE id = v_vehicle_id;

    IF NOT v_is_owner THEN
        SELECT role INTO v_role
        FROM vehicle_shares
        WHERE vehicle_id = v_vehicle_id AND user_id = p_user_id;

        IF v_role IS NULL OR v_role = 'VIEWER' THEN
            RETURN;
        END IF;
    END IF;

    -- Delete existing items
    DELETE FROM service_items WHERE service_id = p_service_id;

    -- Insert new items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_item_id := gen_random_uuid();
        
        INSERT INTO service_items (
            id,
            service_id,
            part_name,
            part_number,
            quantity,
            unit_price
        ) VALUES (
            v_item_id,
            p_service_id,
            (v_item->>'part_name')::VARCHAR(160),
            (v_item->>'part_number')::VARCHAR(80),
            (v_item->>'quantity')::NUMERIC(10,2),
            (v_item->>'unit_price')::NUMERIC(12,2)
        );
    END LOOP;

    RETURN QUERY
    SELECT
        si.id,
        si.service_id,
        si.part_name,
        si.part_number,
        si.quantity,
        si.unit_price
    FROM service_items si
    WHERE si.service_id = p_service_id
    ORDER BY si.part_name;
END;
$$;

-- Delete a single service item
-- Only OWNER or EDITOR can delete service items
CREATE OR REPLACE FUNCTION fn_delete_service_item(
    p_user_id UUID,
    p_item_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
    v_service_id UUID;
    v_vehicle_id UUID;
    v_is_owner BOOLEAN;
    v_role role_type;
    v_deleted BOOLEAN := FALSE;
BEGIN
    -- Get service_id and vehicle_id for this item
    SELECT si.service_id, s.vehicle_id 
    INTO v_service_id, v_vehicle_id
    FROM service_items si
    INNER JOIN services s ON si.service_id = s.id
    WHERE si.id = p_item_id;

    IF v_vehicle_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Check if user is OWNER
    SELECT (owner_id = p_user_id) INTO v_is_owner
    FROM vehicles
    WHERE id = v_vehicle_id;

    IF NOT v_is_owner THEN
        SELECT role INTO v_role
        FROM vehicle_shares
        WHERE vehicle_id = v_vehicle_id AND user_id = p_user_id;

        IF v_role IS NULL OR v_role = 'VIEWER' THEN
            RETURN FALSE;
        END IF;
    END IF;

    -- Delete item
    DELETE FROM service_items
    WHERE id = p_item_id;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted > 0;
END;
$$;
