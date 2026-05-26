-- Asset Units (smallest):
-- Gold = milligram
-- Rial = rial
-- USDT = micro unit === digits: 10^6 | ex: 1 USDT === 1000000 USDT

-- *********************************************************************
-- 0. Init
-- *********************************************************************

INSERT INTO ledger_accounts (id, account_type)
VALUES ('d20cee23-50c0-4872-872f-5507cfa47c45', 'USER');

-- *********************************************************************
-- 1. Mint 5 Grams Gold
-- *********************************************************************
ROLLBACK;
BEGIN;

-- lock ledger globally (mutual exclusion prevention of concurrency)
SELECT pg_advisory_xact_lock(1);

INSERT INTO journal_entries (id, type, idempotency_key)
VALUES ('a09158e3-2e86-4c20-bbf7-6e2cecd3d077',
        'MINT_GOLD',
        'req-110');

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        'a09158e3-2e86-4c20-bbf7-6e2cecd3d077',
        '00000000-0000-0000-0000-000000000002',
        'GOLD',
        -5_000);

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        'a09158e3-2e86-4c20-bbf7-6e2cecd3d077',
        '00000000-0000-0000-0000-000000000000',
        'GOLD',
        5_000);

COMMIT;

-- *********************************************************************
-- 2. Rial conversion to Gold and Rial deposit scenario
-- *********************************************************************

BEGIN;

SELECT pg_advisory_xact_lock(1);

INSERT INTO journal_entries (id, type, idempotency_key, reference_id)
VALUES ('d51c2d40-534d-4bec-804c-5dc2703ee4bd',
        'DEPOSIT_IRR',
        'req-111',
        'bank-ref-1');

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        'd51c2d40-534d-4bec-804c-5dc2703ee4bd',
        'd20cee23-50c0-4872-872f-5507cfa47c45',
        'IRR',
        18_000_000);

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        'd51c2d40-534d-4bec-804c-5dc2703ee4bd',
        '00000000-0000-0000-0000-000000000000',
        'IRR',
        -18_000_000);

COMMIT;

BEGIN;

SELECT pg_advisory_xact_lock(1);

INSERT INTO journal_entries (id, type, idempotency_key)
VALUES ('89e81ff9-f370-4d25-80d0-73bd37a80e80',
        'BUY_GOLD',
        'req-114');

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        '89e81ff9-f370-4d25-80d0-73bd37a80e80',
        'd20cee23-50c0-4872-872f-5507cfa47c45',
        'IRR',
        -18_000_000);

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        '89e81ff9-f370-4d25-80d0-73bd37a80e80',
        '00000000-0000-0000-0000-000000000000',
        'IRR',
        18_000_000);

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        '89e81ff9-f370-4d25-80d0-73bd37a80e80',
        'd20cee23-50c0-4872-872f-5507cfa47c45',
        'GOLD',
        10);

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        '89e81ff9-f370-4d25-80d0-73bd37a80e80',
        '00000000-0000-0000-0000-000000000000',
        'GOLD',
        -10);

COMMIT;

-- *********************************************************************
-- 3. Gold converting to Rial and Rial withdrawal scenario
-- *********************************************************************

BEGIN;

SELECT pg_advisory_xact_lock(1);

INSERT INTO journal_entries (id, type, idempotency_key)
VALUES ('30c06840-e321-4022-a132-a2e4dd53161e',
        'SELL_GOLD',
        'req-115');

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        '30c06840-e321-4022-a132-a2e4dd53161e',
        'd20cee23-50c0-4872-872f-5507cfa47c45',
        'GOLD',
        -10);

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        '30c06840-e321-4022-a132-a2e4dd53161e',
        '00000000-0000-0000-0000-000000000000',
        'GOLD',
        10);

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        '30c06840-e321-4022-a132-a2e4dd53161e',
        'd20cee23-50c0-4872-872f-5507cfa47c45',
        'IRR',
        18_000_200);

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        '30c06840-e321-4022-a132-a2e4dd53161e',
        '00000000-0000-0000-0000-000000000000',
        'IRR',
        -18_000_200);

COMMIT;

BEGIN;

SELECT pg_advisory_xact_lock(1);

INSERT INTO journal_entries (id, type, idempotency_key, reference_id)
VALUES ('d963fca8-0a43-49ec-bc5c-2ef98934ba24',
        'WITHDRAW_IRR',
        'req-117',
        'bank-ref-2');

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        'd963fca8-0a43-49ec-bc5c-2ef98934ba24',
        'd20cee23-50c0-4872-872f-5507cfa47c45',
        'IRR',
        17_999_200);

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        'd963fca8-0a43-49ec-bc5c-2ef98934ba24',
        '00000000-0000-0000-0000-000000000001',
        'IRR',
        1_000);

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        'd963fca8-0a43-49ec-bc5c-2ef98934ba24',
        '00000000-0000-0000-0000-000000000000',
        'IRR',
        -18_000_200);

COMMIT;

-- *********************************************************************
-- 4. Burn 100 Milligrams Gold
-- *********************************************************************

BEGIN;

SELECT pg_advisory_xact_lock(1);

INSERT INTO journal_entries (id, type, idempotency_key)
VALUES ('50db5396-2faa-450b-a95a-4c147b603924',
        'BURN_GOLD',
        'req-118');

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        '50db5396-2faa-450b-a95a-4c147b603924',
        '00000000-0000-0000-0000-000000000002',
        'GOLD',
        100);

INSERT INTO journal_entry_lines (id, entry_id, account_id, asset, amount)
VALUES (gen_random_uuid(),
        '50db5396-2faa-450b-a95a-4c147b603924',
        '00000000-0000-0000-0000-000000000000',
        'GOLD',
        -100);

COMMIT;

-- *********************************************************************
-- 5. Calculate Invariant
-- *********************************************************************

SELECT entry_id,
       asset,
       SUM(amount)
FROM journal_entry_lines
GROUP BY entry_id, asset
HAVING SUM(amount) <> 0;
