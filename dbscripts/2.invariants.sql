CREATE OR REPLACE FUNCTION prevent_mutation()
    RETURNS trigger AS
$$
BEGIN
    RAISE EXCEPTION 'ledger is immutable: update/delete not allowed';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_update_journal_entries
    BEFORE UPDATE OR DELETE
    ON journal_entries
    FOR EACH ROW
EXECUTE FUNCTION prevent_mutation();


CREATE TRIGGER trg_no_update_journal_entry_lines
    BEFORE UPDATE OR DELETE
    ON journal_entry_lines
    FOR EACH ROW
EXECUTE FUNCTION prevent_mutation();

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
