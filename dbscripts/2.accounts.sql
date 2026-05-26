-- Step 1: advance committed (critical fix)
UPDATE ledger_projection_state
SET last_committed_sequence = (SELECT COALESCE(MAX(ledger_sequence), last_committed_sequence)
                               FROM journal_entries
                               group by last_committed_sequence)
WHERE id = TRUE;

-- Step 2: projection
WITH state AS (SELECT last_processed_sequence, last_committed_sequence
               FROM ledger_projection_state
               WHERE id = TRUE),

     batch AS (SELECT je.ledger_sequence,
                      jel.account_id,
                      jel.asset,
                      jel.amount
               FROM journal_entries je
                        JOIN journal_entry_lines jel ON je.id = jel.entry_id
                        CROSS JOIN state s
               WHERE je.ledger_sequence > s.last_processed_sequence
                 AND je.ledger_sequence <= s.last_committed_sequence),

     agg AS (SELECT account_id,
                    asset,
                    SUM(amount)          AS delta,
                    MAX(ledger_sequence) AS max_seq
             FROM batch
             GROUP BY account_id, asset)

INSERT
INTO account_balances (account_id, asset, balance)
SELECT account_id, asset, delta
FROM agg
ON CONFLICT (account_id, asset)
    DO UPDATE SET balance    = account_balances.balance + EXCLUDED.balance,
                  updated_at = now();

-- Step 3: advance processed
UPDATE ledger_projection_state s
SET last_processed_sequence = s.last_committed_sequence
WHERE id = TRUE;