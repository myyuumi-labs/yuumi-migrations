CREATE TABLE account (
    id                  UUID PRIMARY KEY,
    customer_id         VARCHAR(255)   NOT NULL,
    account_number      VARCHAR(20)    NOT NULL,
    account_type        VARCHAR(255)   NOT NULL,
    account_sub_type    VARCHAR(255)   NOT NULL,
    status              VARCHAR(255)   NOT NULL,
    currency            VARCHAR(3)     NOT NULL,
    nickname            VARCHAR(64),
    display_name        VARCHAR(64),
    balance             NUMERIC(19, 2) NOT NULL,
    version             INTEGER,
    request_fingerprint VARCHAR(128),
    created_at          TIMESTAMP,
    updated_at          TIMESTAMP,
    CONSTRAINT account_account_number_key UNIQUE (account_number),
    CONSTRAINT account_request_fingerprint_key UNIQUE (request_fingerprint)
);

CREATE INDEX idx_account_customer ON account (customer_id);
CREATE INDEX idx_account_status ON account (status);
CREATE UNIQUE INDEX idx_account_fingerprint ON account (request_fingerprint);

CREATE TABLE account_hold (
    id                  UUID PRIMARY KEY,
    account_id          UUID           NOT NULL,
    amount              NUMERIC(19, 2) NOT NULL,
    status              VARCHAR(255)   NOT NULL,
    reason              VARCHAR(255),
    created_at          TIMESTAMP,
    updated_at          TIMESTAMP,
    release_at          TIMESTAMP,
    request_fingerprint VARCHAR(128),
    CONSTRAINT account_hold_request_fingerprint_key UNIQUE (request_fingerprint)
);

CREATE INDEX idx_hold_account ON account_hold (account_id);
CREATE INDEX idx_hold_status ON account_hold (status);

CREATE TABLE account_transaction (
    id                  BIGSERIAL PRIMARY KEY,
    transaction_id      UUID           NOT NULL,
    account_id          UUID           NOT NULL,
    type                VARCHAR(32)    NOT NULL,
    status              VARCHAR(32)    NOT NULL,
    amount              NUMERIC(19, 2) NOT NULL,
    currency            VARCHAR(3)     NOT NULL,
    reason              VARCHAR(256),
    balance_after       NUMERIC(19, 2),
    occurred_at         TIMESTAMPTZ    NOT NULL,
    request_fingerprint VARCHAR(100),
    created_at          TIMESTAMPTZ,
    updated_at          TIMESTAMPTZ,
    version             INTEGER,
    CONSTRAINT account_transaction_transaction_id_key UNIQUE (transaction_id),
    CONSTRAINT uk_tx_account_idem UNIQUE (account_id, request_fingerprint)
);

CREATE INDEX idx_tx_account ON account_transaction (account_id);
CREATE INDEX idx_tx_occurred ON account_transaction (occurred_at);
CREATE INDEX idx_tx_type ON account_transaction (type);
CREATE INDEX idx_tx_status ON account_transaction (status);
