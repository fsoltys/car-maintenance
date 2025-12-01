SET search_path TO car_app, public;

-- Zwraca słownik wszystkich enumów używanych w aplikacji.
-- Struktura:
-- {
--   "fuel_type": [ { "value": "Petrol", "label": "Petrol" }, ... ],
--   "service_type": [ ... ],
--   ...
-- }

CREATE OR REPLACE FUNCTION car_app.fn_get_enums()
RETURNS jsonb
LANGUAGE sql
AS $$
    SELECT jsonb_build_object(

        'fuel_type',
        (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'value', e.enumlabel,
                           'label', e.enumlabel
                       )
                   ORDER BY e.enumsortorder
            )
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'fuel_type'
        ),

        'service_type',
        (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'value', e.enumlabel,
                           'label', e.enumlabel
                       )
                   ORDER BY e.enumsortorder
            )
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'service_type'
        ),

        'issue_priority',
        (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'value', e.enumlabel,
                           'label', e.enumlabel
                       )
                   ORDER BY e.enumsortorder
            )
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'issue_priority'
        ),

        'issue_status',
        (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'value', e.enumlabel,
                           'label', e.enumlabel
                       )
                   ORDER BY e.enumsortorder
            )
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'issue_status'
        ),

        'document_type',
        (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'value', e.enumlabel,
                           'label', e.enumlabel
                       )
                   ORDER BY e.enumsortorder
            )
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'document_type'
        ),

        'expense_category',
        (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'value', e.enumlabel,
                           'label', e.enumlabel
                       )
                   ORDER BY e.enumsortorder
            )
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'expense_category'
        ),

        'reminder_status',
        (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'value', e.enumlabel,
                           'label', e.enumlabel
                       )
                   ORDER BY e.enumsortorder
            )
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'reminder_status'
        ),

        'unit_system',
        (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'value', e.enumlabel,
                           'label', e.enumlabel
                       )
                   ORDER BY e.enumsortorder
            )
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'unit_system'
        ),

        'driving_cycle',
        (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'value', e.enumlabel,
                           'label', e.enumlabel
                       )
                   ORDER BY e.enumsortorder
            )
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'driving_cycle'
        ),

        'role_type',
        (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'value', e.enumlabel,
                           'label', e.enumlabel
                       )
                   ORDER BY e.enumsortorder
            )
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'role_type'
        ),

        'fuel_type',
        (
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'value', e.enumlabel,
                           'label', e.enumlabel
                       )
                   ORDER BY e.enumsortorder
            )
            FROM pg_type t
            JOIN pg_enum e ON t.oid = e.enumtypid
            WHERE t.typname = 'fuel_type'
        )
    );
$$;