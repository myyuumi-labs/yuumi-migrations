CREATE TABLE bill_batch_settlement (
    id                  BIGSERIAL PRIMARY KEY,
    batch_id            UUID         NOT NULL,
    status              VARCHAR(255) NOT NULL,
    retry_count         INTEGER      NOT NULL DEFAULT 0,
    pain001_file_name   VARCHAR(255),
    central_reference   VARCHAR(255),
    last_error          VARCHAR(255),
    created_at          TIMESTAMPTZ  NOT NULL,
    updated_at          TIMESTAMPTZ,
    CONSTRAINT bill_batch_settlement_batch_id_key UNIQUE (batch_id)
);
