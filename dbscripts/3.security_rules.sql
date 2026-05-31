-- CLEAN SLATE: SECURITY HARDENING

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- OWNER MODEL (CRITICAL)
-- postgres = migration/admin only

ALTER TYPE asset_type OWNER TO postgres;
ALTER TYPE journal_entry_type OWNER TO postgres;
ALTER TYPE account_type OWNER TO postgres;

ALTER TABLE ledger_accounts
    OWNER TO postgres;
ALTER TABLE account_balances
    OWNER TO postgres;
ALTER TABLE ledger_projection_state
    OWNER TO postgres;

ALTER TABLE journal_entries
    OWNER TO postgres;
ALTER TABLE journal_entry_lines
    OWNER TO postgres;

-- APP ROLE

DO
$$
    BEGIN
        IF NOT EXISTS (SELECT 1
                       FROM pg_roles
                       WHERE rolname = 'ledger_app_user') THEN
            CREATE ROLE ledger_app_user
                WITH LOGIN PASSWORD 'strong_password_here';
        END IF;
    END
$$;

GRANT CONNECT ON DATABASE ledger_db TO ledger_app_user;

GRANT USAGE ON SCHEMA public TO ledger_app_user;

-- DEFAULT PRIVILEGES (IMPORTANT)

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON TABLES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON TABLES FROM ledger_app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON SEQUENCES FROM ledger_app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON FUNCTIONS FROM ledger_app_user;

-- MUTABLE STATE (business data)

GRANT SELECT, INSERT, UPDATE
    ON ledger_accounts
    TO ledger_app_user;

GRANT SELECT, INSERT, UPDATE, DELETE
    ON account_balances
    TO ledger_app_user;

GRANT SELECT, INSERT, UPDATE
    ON ledger_projection_state
    TO ledger_app_user;


-- IMMUTABLE LEDGER (CRITICAL)

GRANT SELECT, INSERT
    ON journal_entries
    TO ledger_app_user;

GRANT SELECT, INSERT
    ON journal_entry_lines
    TO ledger_app_user;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ledger_app_user;

-- DO NOT grant ANY of these to app:
-- - CREATE on schema
-- - ALTER / DROP privileges
-- - ownership of any table
-- - superuser / replication roles