CREATE TABLE payments (
    payment_id          UUID           PRIMARY KEY,
    state               VARCHAR(20)    NOT NULL,
    debtor_account_id   UUID           NOT NULL,
    biller_ref_number   VARCHAR(64)    NOT NULL,
    invoice_reference   VARCHAR(128)   NOT NULL,
    execution_date      DATE           NOT NULL,
    amount_value        NUMERIC(18, 2) NOT NULL,
    amount_ccy          VARCHAR(3)     NOT NULL,
    batch_id            UUID,
    external_status_code VARCHAR(255),
    reason              VARCHAR(255),
    idempotency_key     VARCHAR(80)    NOT NULL,
    created_at          TIMESTAMPTZ    NOT NULL,
    updated_at          TIMESTAMPTZ    NOT NULL,
    CONSTRAINT uk_idempotency_key UNIQUE (idempotency_key)
);

CREATE INDEX idx_batch_id ON payments (batch_id);
CREATE INDEX idx_state ON payments (state);

CREATE TABLE outbox (
    id           BIGSERIAL PRIMARY KEY,
    topic        VARCHAR(120) NOT NULL,
    "key"        UUID         NOT NULL,
    payload_json TEXT         NOT NULL,
    state        VARCHAR(20)  NOT NULL,
    created_at   TIMESTAMPTZ  NOT NULL,
    updated_at   TIMESTAMPTZ  NOT NULL
);

CREATE TABLE processed_events (
    id           BIGSERIAL PRIMARY KEY,
    handler      VARCHAR(80)  NOT NULL,
    event_id     VARCHAR(120) NOT NULL,
    processed_at TIMESTAMPTZ  NOT NULL,
    CONSTRAINT uk_handler_event UNIQUE (handler, event_id)
);

CREATE TABLE retries (
    id              BIGSERIAL PRIMARY KEY,
    batch_id        VARCHAR(64)  NOT NULL,
    attempt         INTEGER      NOT NULL,
    next_attempt_at TIMESTAMPTZ  NOT NULL,
    backoff_ms      BIGINT       NOT NULL,
    status          VARCHAR(20)  NOT NULL,
    reason          VARCHAR(256),
    CONSTRAINT pk_batch_attempt UNIQUE (batch_id, attempt)
);
