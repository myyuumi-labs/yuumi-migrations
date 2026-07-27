CREATE TABLE batches (
    batch_id   UUID        PRIMARY KEY,
    status     VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE batch_lines (
    id         BIGSERIAL PRIMARY KEY,
    batch_id   UUID        NOT NULL,
    payment_id UUID        NOT NULL,
    line_no    INTEGER     NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);
