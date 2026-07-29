CREATE TABLE billers (
    id               UUID PRIMARY KEY,
    customer_id      VARCHAR(255) NOT NULL,
    name             VARCHAR(255) NOT NULL,
    reference_number VARCHAR(255) NOT NULL,
    category         VARCHAR(255) NOT NULL,
    status           VARCHAR(255) NOT NULL DEFAULT 'ACTIVE',
    created_at       TIMESTAMPTZ  NOT NULL,
    updated_at       TIMESTAMPTZ  NOT NULL,
    CONSTRAINT uk_biller_owner_ref UNIQUE (customer_id, reference_number)
);

CREATE INDEX idx_biller_customer ON billers (customer_id);
