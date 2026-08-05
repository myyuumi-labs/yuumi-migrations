CREATE TABLE users (
    id                UUID PRIMARY KEY,
    keycloak_sub      VARCHAR(255) NOT NULL,
    email             VARCHAR(255) NOT NULL,
    state             VARCHAR(32)  NOT NULL,
    first_name        VARCHAR(255),
    last_name         VARCHAR(255),
    tenant_id         UUID,
    role              VARCHAR(32),
    is_super_admin    BOOLEAN      NOT NULL DEFAULT FALSE,
    email_verified_at TIMESTAMPTZ,
    created_at        TIMESTAMPTZ  NOT NULL,
    updated_at        TIMESTAMPTZ  NOT NULL,
    CONSTRAINT uniq_users_keycloak_sub UNIQUE (keycloak_sub),
    CONSTRAINT uniq_users_email UNIQUE (email),
    CONSTRAINT fk_users_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (id)
);

CREATE INDEX idx_users_tenant_id ON users (tenant_id);
CREATE INDEX idx_users_state ON users (state);
