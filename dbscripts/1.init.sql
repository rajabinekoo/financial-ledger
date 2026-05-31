CREATE TYPE asset_type AS ENUM (
    'GOLD',
    'IRR',
    'SILVER',
    'USDT'
    );

CREATE TYPE journal_entry_type AS ENUM (
    'BUY_GOLD',
    'SELL_GOLD',
    'BUY_SILVER',
    'SELL_SILVER',
    'DEPOSIT_IRR',
    'WITHDRAW_IRR',
    'DEPOSIT_USDT',
    'WITHDRAW_USDT',
    'MINT_GOLD',
    'BURN_GOLD',
    'MINT_SILVER',
    'BURN_SILVER'
    );

CREATE TYPE account_type AS ENUM (
    'USER',
    'TREASURY',
    'SYSTEM'
    );

CREATE TABLE ledger_accounts
(
    id           UUID PRIMARY KEY,
    account_type account_type NOT NULL
);

INSERT INTO ledger_accounts (id, account_type)
VALUES ('00000000-0000-0000-0000-000000000000', 'TREASURY'),
-- Fee system
       ('00000000-0000-0000-0000-000000000001', 'SYSTEM'),
-- Treasury adjustment system
       ('00000000-0000-0000-0000-000000000002', 'SYSTEM');

CREATE TABLE journal_entries
(
    id              UUID PRIMARY KEY,
    ledger_sequence BIGSERIAL          NOT NULL UNIQUE,
    type            journal_entry_type NOT NULL,
    reference_id    TEXT, -- External service like bank reference id
    idempotency_key TEXT               NOT NULL UNIQUE,
    created_at      TIMESTAMPTZ        NOT NULL DEFAULT now()
);

CREATE TABLE journal_entry_lines
(
    id         UUID PRIMARY KEY,
    entry_id   UUID        NOT NULL REFERENCES journal_entries (id) ON DELETE RESTRICT,
    account_id UUID        NOT NULL REFERENCES ledger_accounts (id) ON DELETE RESTRICT,
    asset      asset_type  NOT NULL,
    -- Positive = Credit
    -- Negative = Debit
    amount     BIGINT      NOT NULL CHECK ( amount <> 0 ),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_entry_account_asset UNIQUE (entry_id, account_id, asset)
);

CREATE TABLE journal_entry_type_assets
(
    entry_type journal_entry_type,
    asset      asset_type,
    PRIMARY KEY (entry_type, asset)
);

INSERT INTO journal_entry_type_assets (entry_type, asset)
VALUES
-- Mint / Burn GOLD
('MINT_GOLD', 'GOLD'),
('BURN_GOLD', 'GOLD'),

-- Mint / Burn SILVER
('MINT_SILVER', 'SILVER'),
('BURN_SILVER', 'SILVER'),

-- Buy Gold
('BUY_GOLD', 'GOLD'),
('BUY_GOLD', 'IRR'),
('BUY_GOLD', 'USDT'),

-- Sell Gold
('SELL_GOLD', 'GOLD'),
('SELL_GOLD', 'IRR'),
('SELL_GOLD', 'USDT'),

-- Buy SILVER
('BUY_SILVER', 'SILVER'),
('BUY_SILVER', 'IRR'),
('BUY_SILVER', 'USDT'),

-- Sell SILVER
('SELL_SILVER', 'SILVER'),
('SELL_SILVER', 'IRR'),
('SELL_SILVER', 'USDT'),

-- Fiat
('DEPOSIT_IRR', 'IRR'),
('WITHDRAW_IRR', 'IRR'),

-- Crypto
('DEPOSIT_USDT', 'USDT'),
('WITHDRAW_USDT', 'USDT');

CREATE TABLE account_balances
(
    account_id UUID        NOT NULL REFERENCES ledger_accounts (id) ON DELETE RESTRICT,
    asset      asset_type  NOT NULL,
    balance    BIGINT      NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, asset)
);

CREATE TABLE ledger_projection_state
(
    id                      BOOLEAN PRIMARY KEY DEFAULT TRUE,
    last_processed_sequence BIGINT NOT NULL     DEFAULT 0,
    last_committed_sequence BIGINT NOT NULL     DEFAULT 0
);

INSERT INTO ledger_projection_state (id, last_processed_sequence, last_committed_sequence)
VALUES (TRUE, 0, 0)
ON CONFLICT (id) DO NOTHING;

CREATE INDEX idx_journal_entries_type
    ON journal_entries (type);

CREATE INDEX idx_journal_entries_reference_id
    ON journal_entries (reference_id);

CREATE INDEX idx_journal_entry_lines_entry_id
    ON journal_entry_lines (entry_id);

CREATE INDEX idx_journal_entry_lines_account_asset
    ON journal_entry_lines (account_id, asset);

CREATE UNIQUE INDEX
    uq_journal_reference_id
    ON journal_entries (reference_id)
    WHERE reference_id IS NOT NULL;
