CREATE TABLE tenants (
    id          UUID PRIMARY KEY,
    slug        VARCHAR(63)  NOT NULL,
    name        VARCHAR(255) NOT NULL,
    status      VARCHAR(32)  NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL,
    created_by  VARCHAR(255),
    updated_at  TIMESTAMPTZ  NOT NULL,
    updated_by  VARCHAR(255),
    CONSTRAINT uniq_tenants_slug UNIQUE (slug)
);

CREATE INDEX idx_tenants_status ON tenants (status);
