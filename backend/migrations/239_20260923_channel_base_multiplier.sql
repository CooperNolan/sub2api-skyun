ALTER TABLE channel_model_pricing
    ADD COLUMN IF NOT EXISTS base_multiplier NUMERIC(12,6);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'channel_model_pricing_base_multiplier_positive' AND conrelid = 'channel_model_pricing'::regclass) THEN
        ALTER TABLE channel_model_pricing
            ADD CONSTRAINT channel_model_pricing_base_multiplier_positive
            CHECK (base_multiplier IS NULL OR base_multiplier > 0);
    END IF;
END $$;

COMMENT ON COLUMN channel_model_pricing.base_multiplier IS
    'Model-level base multiplier applied on top of the channel unit prices before group/user/peak factors';
