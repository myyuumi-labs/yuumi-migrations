CREATE TABLE customers (
    id              BIGSERIAL PRIMARY KEY,
    version         INTEGER      NOT NULL,
    first_name      VARCHAR(255) NOT NULL,
    last_name       VARCHAR(255) NOT NULL,
    email           VARCHAR(255) NOT NULL,
    phone           VARCHAR(255),
    address         VARCHAR(255) NOT NULL,
    external_id     VARCHAR(255) NOT NULL,
    kyc_status      VARCHAR(255) NOT NULL,
    active          BOOLEAN      NOT NULL,
    request_fingerprint VARCHAR(255) NOT NULL,
    created_at      TIMESTAMP    NOT NULL,
    updated_at      TIMESTAMP    NOT NULL,
    CONSTRAINT uniq_customers_email UNIQUE (email),
    CONSTRAINT uniq_customers_external_id UNIQUE (external_id)
);
