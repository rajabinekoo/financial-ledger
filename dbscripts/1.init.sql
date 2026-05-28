CREATE TYPE asset_type AS ENUM (
    'GOLD',
    'IRR'
    );

CREATE TYPE journal_entry_type AS ENUM (
    'BUY_GOLD',
    'SELL_GOLD',
    'DEPOSIT_IRR',
    'WITHDRAW_IRR',
    'MINT_GOLD',
    'BURN_GOLD'
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

CREATE TABLE block_builder_state
(
    id                      BOOLEAN PRIMARY KEY DEFAULT TRUE,
    last_processed_sequence BIGINT NOT NULL     DEFAULT 0,
    last_committed_sequence BIGINT NOT NULL     DEFAULT 0
);

INSERT INTO block_builder_state (id, last_processed_sequence, last_committed_sequence)
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

CREATE FUNCTION immutable_prevention()
    RETURNS trigger
AS
$$
BEGIN
    RAISE EXCEPTION 'ledger is append only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER no_update_entries
    BEFORE UPDATE
    ON journal_entries
    FOR EACH ROW
EXECUTE FUNCTION immutable_prevention();

CREATE TRIGGER no_update_lines
    BEFORE UPDATE
    ON journal_entry_lines
    FOR EACH ROW
EXECUTE FUNCTION immutable_prevention();

CREATE TRIGGER no_delete_entries
    BEFORE DELETE
    ON journal_entries
    FOR EACH ROW
EXECUTE FUNCTION immutable_prevention();

CREATE TRIGGER no_delete_lines
    BEFORE DELETE
    ON journal_entry_lines
    FOR EACH ROW
EXECUTE FUNCTION immutable_prevention();

CREATE FUNCTION validate_entry_has_multiple_lines()
    RETURNS trigger
AS
$$
DECLARE
    line_count integer;
BEGIN
    SELECT COUNT(*)
    INTO line_count
    FROM journal_entry_lines
    WHERE entry_id = NEW.id;

    IF line_count < 2 THEN
        RAISE EXCEPTION
            'journal entry % must contain at least two lines',
            NEW.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_entry_lines
    AFTER INSERT
    ON journal_entries
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE FUNCTION validate_entry_has_multiple_lines();

CREATE FUNCTION validate_entry_balanced()
    RETURNS trigger
AS
$$
DECLARE
    bad_asset text;
BEGIN
    SELECT asset
    INTO bad_asset
    FROM journal_entry_lines
    WHERE entry_id = NEW.id
    GROUP BY asset
    HAVING SUM(amount) <> 0
    LIMIT 1;

    IF bad_asset IS NOT NULL THEN
        RAISE EXCEPTION
            'entry % is not balanced for asset %',
            NEW.id,
            bad_asset;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_entry_balanced
    AFTER INSERT
    ON journal_entries
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE FUNCTION validate_entry_balanced();

INSERT INTO journal_entry_type_assets (entry_type, asset)
VALUES
-- Mint / Burn
('MINT_GOLD', 'GOLD'),
('BURN_GOLD', 'GOLD'),

-- Buy Gold
('BUY_GOLD', 'GOLD'),
('BUY_GOLD', 'IRR'),

-- Sell Gold
('SELL_GOLD', 'GOLD'),
('SELL_GOLD', 'IRR'),

-- Fiat
('DEPOSIT_IRR', 'IRR'),
('WITHDRAW_IRR', 'IRR');

CREATE FUNCTION validate_entry_assets()
    RETURNS trigger
AS
$$
DECLARE
    invalid_asset asset_type;
BEGIN

    SELECT jel.asset
    INTO invalid_asset
    FROM journal_entry_lines jel
    WHERE jel.entry_id = NEW.id
      AND NOT EXISTS (SELECT 1
                      FROM journal_entry_type_assets eta
                      WHERE eta.entry_type = NEW.type
                        AND eta.asset = jel.asset)
    LIMIT 1;

    IF invalid_asset IS NOT NULL THEN
        RAISE EXCEPTION
            'asset % is not allowed for entry type %',
            invalid_asset,
            NEW.type;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_entry_assets
    AFTER INSERT
    ON journal_entries
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE FUNCTION validate_entry_assets();
