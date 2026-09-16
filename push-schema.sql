-- Architecture reference for PostgreSQL. Apply only when deploying the push backend.
CREATE TABLE installations (
    id UUID PRIMARY KEY,
    owner_subject TEXT NOT NULL,
    token_ciphertext BYTEA NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    environment TEXT NOT NULL CHECK (environment IN ('sandbox', 'production')),
    country CHAR(2) NOT NULL,
    categories TEXT[] NOT NULL DEFAULT '{}',
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    timezone TEXT NOT NULL DEFAULT 'America/Costa_Rica',
    preferences_version BIGINT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE notification_deliveries (
    installation_id UUID NOT NULL REFERENCES installations(id) ON DELETE CASCADE,
    article_id TEXT NOT NULL,
    canonical_url_hash TEXT NOT NULL,
    preferences_version BIGINT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('queued', 'sending', 'accepted', 'failed', 'cancelled')),
    attempt_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    accepted_at TIMESTAMPTZ,
    next_attempt_at TIMESTAMPTZ,
    apns_id UUID,
    PRIMARY KEY (installation_id, article_id),
    UNIQUE (installation_id, canonical_url_hash)
);
CREATE INDEX notification_daily_limit ON notification_deliveries (installation_id, accepted_at);
