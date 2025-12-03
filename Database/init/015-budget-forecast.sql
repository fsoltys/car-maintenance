-- Add expense_type column to expenses table
ALTER TABLE car_app.expenses 
ADD COLUMN IF NOT EXISTS expense_type VARCHAR(20) DEFAULT 'REGULAR';

COMMENT ON COLUMN car_app.expenses.expense_type IS 
'Classification of expense: REGULAR, IRREGULAR_MEDIUM, IRREGULAR_LARGE, SCHEDULED_MAINTENANCE';

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_expenses_type ON car_app.expenses(expense_type);
CREATE INDEX IF NOT EXISTS idx_expenses_vehicle_date ON car_app.expenses(vehicle_id, expense_date);

-- Function: Classify expense type based on statistics
CREATE OR REPLACE FUNCTION car_app.fn_classify_expense_type(
    p_vehicle_id UUID,
    p_category expense_category,
    p_amount NUMERIC
)
RETURNS VARCHAR(20) AS $$
DECLARE
    v_mean NUMERIC;
    v_stddev NUMERIC;
    v_count INT;
BEGIN
    -- Get statistics for ALL expenses (not per-category) in the past 12 months
    -- This allows detection of unusually large expenses across all categories
    SELECT 
        AVG(amount),
        STDDEV(amount),
        COUNT(*)
    INTO v_mean, v_stddev, v_count
    FROM car_app.expenses
    WHERE vehicle_id = p_vehicle_id
      AND expense_date >= CURRENT_DATE - INTERVAL '12 months'
      AND expense_type != 'IRREGULAR_LARGE'; -- Exclude previous outliers
    
    -- If not enough data, default to REGULAR
    IF v_count < 3 OR v_stddev IS NULL THEN
        RETURN 'REGULAR';
    END IF;
    
    -- 3-sigma rule: classify outliers
    IF p_amount > v_mean + (3 * v_stddev) THEN
        RETURN 'IRREGULAR_LARGE';
    ELSIF p_amount > v_mean + (2 * v_stddev) THEN
        RETURN 'IRREGULAR_MEDIUM';
    ELSE
        RETURN 'REGULAR';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger function: Auto-classify expense on insert/update
CREATE OR REPLACE FUNCTION car_app.fn_expense_auto_classify()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-classify the expense type based on historical data
    NEW.expense_type := car_app.fn_classify_expense_type(NEW.vehicle_id, NEW.category, NEW.amount);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Classify expense before insert/update
CREATE TRIGGER trg_expense_auto_classify
BEFORE INSERT OR UPDATE ON car_app.expenses
FOR EACH ROW
EXECUTE FUNCTION car_app.fn_expense_auto_classify();

-- Function: Auto-classify all existing expenses
CREATE OR REPLACE FUNCTION car_app.fn_auto_classify_expenses()
RETURNS TABLE(
    expense_id UUID,
    old_type VARCHAR(20),
    new_type VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    UPDATE car_app.expenses e
    SET expense_type = car_app.fn_classify_expense_type(e.vehicle_id, e.category, e.amount)
    WHERE e.expense_type = 'REGULAR' -- Only update unclassified
    RETURNING e.id, 'REGULAR'::VARCHAR(20), e.expense_type;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Function: Calculate average monthly mileage
-- =====================================================
CREATE OR REPLACE FUNCTION car_app.fn_get_avg_monthly_mileage(p_vehicle_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_avg_mileage NUMERIC;
    v_months NUMERIC;
BEGIN
    -- Calculate average from fuelings in the past 12 months
    SELECT 
        (MAX(odometer_km) - MIN(odometer_km)) / 
        GREATEST(
            EXTRACT(EPOCH FROM (MAX(filled_at) - MIN(filled_at))) / (60 * 60 * 24 * 30.44), 
            1
        )
    INTO v_avg_mileage
    FROM car_app.fuelings
    WHERE vehicle_id = p_vehicle_id
      AND filled_at >= CURRENT_DATE - INTERVAL '12 months';
    
    RETURN COALESCE(v_avg_mileage, 0);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Function: Predict scheduled maintenance costs
-- Uses existing reminder_rules and historical service costs
-- =====================================================
CREATE OR REPLACE FUNCTION car_app.fn_predict_scheduled_maintenance(
    p_vehicle_id UUID,
    p_target_date DATE,
    p_avg_monthly_km NUMERIC
)
RETURNS TABLE(
    rule_id UUID,
    rule_name VARCHAR(160),
    estimated_cost NUMERIC,
    estimated_date DATE,
    confidence VARCHAR(10)
) AS $$
DECLARE
    v_current_odometer NUMERIC;
    v_predicted_odometer NUMERIC;
    v_months_ahead NUMERIC;
    v_rule RECORD;
    v_last_reset_date DATE;
    v_last_reset_km NUMERIC;
    v_estimated_date DATE;
    v_avg_cost NUMERIC;
BEGIN
    -- Get current odometer
    v_current_odometer := car_app.fn_get_latest_odometer(p_vehicle_id);
    
    -- Calculate months ahead (convert days to interval first)
    v_months_ahead := EXTRACT(EPOCH FROM (p_target_date - CURRENT_DATE) * INTERVAL '1 day') / (60 * 60 * 24 * 30.44);
    
    -- Calculate predicted odometer at target date
    v_predicted_odometer := v_current_odometer + (v_months_ahead * p_avg_monthly_km);
    
    -- Iterate through active recurring reminder rules for this vehicle
    FOR v_rule IN 
        SELECT 
            rr.id,
            rr.name,
            rr.service_type,
            rr.due_every_days,
            rr.due_every_km,
            rr.last_reset_at,
            rr.last_reset_odometer_km,
            rr.next_due_date,
            rr.next_due_odometer_km
        FROM car_app.reminder_rules rr
        WHERE rr.vehicle_id = p_vehicle_id
          AND rr.status = 'ACTIVE'
          AND rr.is_recurring = TRUE
          AND (rr.due_every_days IS NOT NULL OR rr.due_every_km IS NOT NULL)
    LOOP
        v_estimated_date := NULL;
        
        -- Use last_reset values if available, otherwise use current values
        v_last_reset_date := COALESCE(v_rule.last_reset_at::DATE, CURRENT_DATE);
        v_last_reset_km := COALESCE(v_rule.last_reset_odometer_km, v_current_odometer);
        
        -- Calculate estimated date based on time interval
        IF v_rule.due_every_days IS NOT NULL THEN
            v_estimated_date := v_last_reset_date + v_rule.due_every_days;
        END IF;
        
        -- Calculate estimated date based on mileage interval (if more restrictive)
        IF v_rule.due_every_km IS NOT NULL AND p_avg_monthly_km > 0 THEN
            DECLARE
                v_km_based_date DATE;
                v_km_until_due NUMERIC;
            BEGIN
                v_km_until_due := (v_last_reset_km + v_rule.due_every_km) - v_current_odometer;
                
                IF v_km_until_due > 0 THEN
                    v_km_based_date := CURRENT_DATE + (v_km_until_due / p_avg_monthly_km * 30.44)::INTEGER;
                    
                    -- Take the earlier date (whichever comes first)
                    IF v_estimated_date IS NULL OR v_km_based_date < v_estimated_date THEN
                        v_estimated_date := v_km_based_date;
                    END IF;
                END IF;
            END;
        END IF;
        
        -- If service is due within the target month, include it in forecast
        IF v_estimated_date IS NOT NULL 
           AND v_estimated_date >= DATE_TRUNC('month', p_target_date)::DATE
           AND v_estimated_date < (DATE_TRUNC('month', p_target_date) + INTERVAL '1 month')::DATE THEN
            
            -- Get average cost for this service_type from historical services
            -- Round to whole numbers for clearer estimates
            v_avg_cost := 0;
            IF v_rule.service_type IS NOT NULL THEN
                SELECT ROUND(AVG(s.total_cost))
                INTO v_avg_cost
                FROM car_app.services s
                WHERE s.vehicle_id = p_vehicle_id
                  AND s.service_type = v_rule.service_type
                  AND s.total_cost IS NOT NULL
                  AND s.service_date >= CURRENT_DATE - INTERVAL '24 months'; -- Last 2 years
                
                v_avg_cost := COALESCE(v_avg_cost, 0);
            END IF;
            
            rule_id := v_rule.id;
            rule_name := v_rule.name;
            estimated_cost := v_avg_cost;
            estimated_date := v_estimated_date;
            
            -- Confidence based on how far in the future
            confidence := CASE
                WHEN EXTRACT(MONTH FROM AGE(v_estimated_date, CURRENT_DATE)) <= 3 THEN 'HIGH'
                WHEN EXTRACT(MONTH FROM AGE(v_estimated_date, CURRENT_DATE)) <= 6 THEN 'MEDIUM'
                ELSE 'LOW'
            END;
            
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Function: Main budget forecast function
-- =====================================================
CREATE OR REPLACE FUNCTION car_app.fn_predict_monthly_budget(
    p_vehicle_id UUID,
    p_months_ahead INT DEFAULT 6,
    p_include_irregular BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
    month DATE,
    regular_costs NUMERIC,
    scheduled_maintenance NUMERIC,
    scheduled_maintenance_details JSONB,
    irregular_buffer NUMERIC,
    total_predicted NUMERIC,
    confidence_level VARCHAR(10)
) AS $$
DECLARE
    v_avg_monthly_regular NUMERIC;
    v_irregular_reserve NUMERIC;
    v_avg_mileage_per_month NUMERIC;
    v_scheduled_services JSONB;
    v_scheduled_total NUMERIC;
    v_service RECORD;
    v_services_array JSONB;
BEGIN
    -- 1. Calculate average monthly regular costs (excluding outliers)
    -- Average of months that had expenses (not zero months)
    SELECT ROUND(COALESCE(AVG(monthly_total), 0)) INTO v_avg_monthly_regular
    FROM (
        SELECT 
            DATE_TRUNC('month', expense_date) as month, 
            SUM(amount) as monthly_total
        FROM car_app.expenses
        WHERE vehicle_id = p_vehicle_id
          AND expense_type = 'REGULAR'
          AND expense_date >= CURRENT_DATE - INTERVAL '12 months'
        GROUP BY DATE_TRUNC('month', expense_date)
    ) monthly_costs;
    
    -- 2. Calculate average monthly mileage
    v_avg_mileage_per_month := car_app.fn_get_avg_monthly_mileage(p_vehicle_id);
    
    -- 3. Calculate irregular expense buffer (average per month with expenses)
    -- Round to whole numbers for clearer budget estimates
    SELECT ROUND(COALESCE(SUM(amount) / GREATEST(COUNT(DISTINCT DATE_TRUNC('month', expense_date)), 1), 0) * 0.15)
    INTO v_irregular_reserve
    FROM car_app.expenses
    WHERE vehicle_id = p_vehicle_id
      AND expense_type IN ('IRREGULAR_MEDIUM', 'IRREGULAR_LARGE')
      AND expense_date >= CURRENT_DATE - INTERVAL '12 months';
    
    -- 4. Generate forecast for each month
    FOR i IN 1..p_months_ahead LOOP
        month := DATE_TRUNC('month', CURRENT_DATE) + (i || ' months')::INTERVAL;
        regular_costs := v_avg_monthly_regular;
        
        -- Get scheduled maintenance for this month
        v_scheduled_total := 0;
        v_services_array := '[]'::JSONB;
        
        FOR v_service IN 
            SELECT * FROM car_app.fn_predict_scheduled_maintenance(
                p_vehicle_id,
                month::DATE,
                v_avg_mileage_per_month
            )
        LOOP
            v_scheduled_total := v_scheduled_total + v_service.estimated_cost;
            v_services_array := v_services_array || jsonb_build_object(
                'rule_id', v_service.rule_id,
                'name', v_service.rule_name,
                'cost', v_service.estimated_cost,
                'date', v_service.estimated_date,
                'confidence', v_service.confidence
            );
        END LOOP;
        
        scheduled_maintenance := v_scheduled_total;
        scheduled_maintenance_details := v_services_array;
        
        irregular_buffer := CASE 
            WHEN p_include_irregular THEN v_irregular_reserve 
            ELSE 0 
        END;
        
        total_predicted := regular_costs + scheduled_maintenance + irregular_buffer;
        
        -- Determine confidence level
        confidence_level := CASE
            WHEN i <= 3 THEN 'HIGH'
            WHEN i <= 6 THEN 'MEDIUM'
            ELSE 'LOW'
        END;
        
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Grant permissions
-- =====================================================
GRANT EXECUTE ON FUNCTION car_app.fn_classify_expense_type TO car_user;
GRANT EXECUTE ON FUNCTION car_app.fn_auto_classify_expenses TO car_user;
GRANT EXECUTE ON FUNCTION car_app.fn_get_avg_monthly_mileage TO car_user;
GRANT EXECUTE ON FUNCTION car_app.fn_predict_scheduled_maintenance TO car_user;
GRANT EXECUTE ON FUNCTION car_app.fn_predict_monthly_budget TO car_user;

-- =====================================================
-- Auto-classify existing expenses (run once)
-- =====================================================
-- Uncomment to classify existing expenses:
-- SELECT * FROM car_app.fn_auto_classify_expenses();
