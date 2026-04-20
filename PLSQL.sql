-- =============================================================================
-- Authors: Aaron Reid, Amal Musse, and Kaley Wood
-- Southern Alberta Institute of Technology: CPRG307-[Section]
-- Assignment 3 Part 2: PL/SQL Exception Handling — WKIS Accounting System
-- Created: April 19, 2026
--
-- Processes transactions from NEW_TRANSACTIONS into TRANSACTION_HISTORY,
-- TRANSACTION_DETAIL, and updates ACCOUNT balances. Invalid transactions
-- get caught, logged to WKIS_ERROR_LOG, and left in NEW_TRANSACTIONS.
-- =============================================================================

SET SERVEROUTPUT ON;

DECLARE

    -- =========================================================================
    -- CURSOR & VARIABLE DECLARATIONS (Member 1)
    -- =========================================================================

    -- outer cursor: grabs each distinct transaction number from NEW_TRANSACTIONS
    -- (explicit cursor — SELECT INTO not allowed against NEW_TRANSACTIONS)
    CURSOR c_outer_transaction IS
        SELECT transaction_no,
               MIN(transaction_date) AS transaction_date,
               MIN(description)      AS description
        FROM new_transactions
        GROUP BY transaction_no
        ORDER BY transaction_no NULLS FIRST;

    -- inner cursor: grabs all detail rows for a given transaction number
    CURSOR c_inner_transaction (p_transaction_no new_transactions.transaction_no%TYPE) IS
        SELECT account_no,
               transaction_type,
               transaction_amount
        FROM new_transactions
        WHERE transaction_no = p_transaction_no
        ORDER BY account_no;

    -- variables to hold fetched cursor values and running totals
    v_transaction_no        new_transactions.transaction_no%TYPE;
    v_transaction_date      new_transactions.transaction_date%TYPE;
    v_description           new_transactions.description%TYPE;
    v_account_no            new_transactions.account_no%TYPE;
    v_transaction_type      new_transactions.transaction_type%TYPE;
    v_transaction_amount    new_transactions.transaction_amount%TYPE;
    v_total_debits          NUMBER := 0;
    v_total_credits         NUMBER := 0;
    v_account_count         NUMBER := 0;
    v_default_trans_type    account_type.default_trans_type%TYPE;

    -- =========================================================================
    -- CUSTOM EXCEPTION DECLARATIONS (Members 2 & 3)
    -- =========================================================================

    e_null_transaction_no       EXCEPTION;
    e_unbalanced_transaction    EXCEPTION;
    e_invalid_account_no        EXCEPTION;
    e_negative_amount           EXCEPTION;
    e_invalid_transaction_type  EXCEPTION;

BEGIN

    -- =========================================================================
    -- OUTER CURSOR LOOP — one iteration per distinct transaction (Member 1)
    -- =========================================================================
    OPEN c_outer_transaction;

    LOOP
        FETCH c_outer_transaction
        INTO v_transaction_no, v_transaction_date, v_description;

        EXIT WHEN c_outer_transaction%NOTFOUND;

        v_total_debits  := 0;
        v_total_credits := 0;

        -- =====================================================================
        -- Per-transaction BEGIN/EXCEPTION block — errors in one transaction
        -- must NOT kill the others.
        -- =====================================================================
        BEGIN

            -- =================================================================
            -- ERROR 1 — NULL Transaction Number (Member 2)
            -- =================================================================
            IF v_transaction_no IS NULL THEN
                RAISE e_null_transaction_no;
            END IF;

            -- =================================================================
            -- VALIDATION PASS — walk every detail row, catch row-level errors
            -- and accumulate debit/credit totals. No inserts/updates yet, so a
            -- mid-transaction failure leaves the DB untouched (no SAVEPOINTs
            -- allowed per spec).
            -- =================================================================
            OPEN c_inner_transaction(v_transaction_no);
            LOOP
                FETCH c_inner_transaction
                INTO v_account_no, v_transaction_type, v_transaction_amount;

                EXIT WHEN c_inner_transaction%NOTFOUND;

                -- ERROR 3 — Invalid Account Number (Member 2)
                SELECT COUNT(*)
                INTO   v_account_count
                FROM   account
                WHERE  account_no = v_account_no;

                IF v_account_count = 0 THEN
                    RAISE e_invalid_account_no;
                END IF;

                -- ERROR 4 — Negative Transaction Amount (Member 3)
                IF v_transaction_amount < 0 THEN
                    RAISE e_negative_amount;
                END IF;

                -- ERROR 5 — Invalid Transaction Type (Member 3)
                -- NULL handled explicitly: `NULL NOT IN (...)` evaluates to NULL
                -- and would not fire the RAISE otherwise.
                IF v_transaction_type IS NULL
                   OR v_transaction_type NOT IN ('D', 'C') THEN
                    RAISE e_invalid_transaction_type;
                END IF;

                -- running totals for the balance check
                IF v_transaction_type = 'D' THEN
                    v_total_debits := v_total_debits + v_transaction_amount;
                ELSE
                    v_total_credits := v_total_credits + v_transaction_amount;
                END IF;
            END LOOP;
            CLOSE c_inner_transaction;

            -- =================================================================
            -- ERROR 2 — Debits Not Equal to Credits (Member 2)
            -- Raised after validation pass so totals are known.
            -- =================================================================
            IF v_total_debits != v_total_credits THEN
                RAISE e_unbalanced_transaction;
            END IF;

            -- =================================================================
            -- INSERT INTO TRANSACTION_HISTORY — one row per transaction.
            -- Must precede TRANSACTION_DETAIL inserts: the detail table's FK
            -- to transaction_history.transaction_no is checked immediately.
            -- =================================================================
            INSERT INTO transaction_history (
                transaction_no,
                transaction_date,
                description
            ) VALUES (
                v_transaction_no,
                v_transaction_date,
                v_description
            );

            -- =================================================================
            -- APPLY PASS — transaction is valid, so write detail rows and
            -- update account balances (Member 1).
            -- =================================================================
            OPEN c_inner_transaction(v_transaction_no);
            LOOP
                FETCH c_inner_transaction
                INTO v_account_no, v_transaction_type, v_transaction_amount;

                EXIT WHEN c_inner_transaction%NOTFOUND;

                INSERT INTO transaction_detail (
                    transaction_no,
                    account_no,
                    transaction_type,
                    transaction_amount
                ) VALUES (
                    v_transaction_no,
                    v_account_no,
                    v_transaction_type,
                    v_transaction_amount
                );

                -- account's default type decides whether D adds or subtracts
                SELECT at.default_trans_type
                INTO   v_default_trans_type
                FROM   account a
                JOIN   account_type at
                    ON a.account_type_code = at.account_type_code
                WHERE  a.account_no = v_account_no;

                UPDATE account
                SET    account_balance = account_balance +
                       CASE
                           WHEN v_default_trans_type = v_transaction_type
                               THEN v_transaction_amount
                           ELSE -v_transaction_amount
                       END
                WHERE  account_no = v_account_no;
            END LOOP;
            CLOSE c_inner_transaction;

            -- =================================================================
            -- DELETE FROM NEW_TRANSACTIONS — processed rows removed.
            -- =================================================================
            DELETE FROM new_transactions
            WHERE  transaction_no = v_transaction_no;

        -- =====================================================================
        -- EXCEPTION BLOCK — per-transaction error handling (Members 2 & 3).
        -- Every handler closes the inner cursor if it was left open by the
        -- validation pass, logs a descriptive message to WKIS_ERROR_LOG, and
        -- lets the outer loop continue. Erroneous rows stay in NEW_TRANSACTIONS.
        -- =====================================================================
        EXCEPTION
            WHEN e_null_transaction_no THEN
                INSERT INTO wkis_error_log
                    (transaction_no, transaction_date, description, error_msg)
                VALUES
                    (v_transaction_no, v_transaction_date, v_description,
                     'Validation Error: Transaction number is NULL.');

            WHEN e_unbalanced_transaction THEN
                INSERT INTO wkis_error_log
                    (transaction_no, transaction_date, description, error_msg)
                VALUES
                    (v_transaction_no, v_transaction_date, v_description,
                     'Accounting Error: Debits (' || v_total_debits ||
                     ') do not equal credits (' || v_total_credits || ').');

            WHEN e_invalid_account_no THEN
                IF c_inner_transaction%ISOPEN THEN
                    CLOSE c_inner_transaction;
                END IF;
                INSERT INTO wkis_error_log
                    (transaction_no, transaction_date, description, error_msg)
                VALUES
                    (v_transaction_no, v_transaction_date, v_description,
                     'Account Error: Account number ' || v_account_no ||
                     ' does not exist in ACCOUNT.');

            WHEN e_negative_amount THEN
                IF c_inner_transaction%ISOPEN THEN
                    CLOSE c_inner_transaction;
                END IF;
                INSERT INTO wkis_error_log
                    (transaction_no, transaction_date, description, error_msg)
                VALUES
                    (v_transaction_no, v_transaction_date, v_description,
                     'Amount Error: Transaction amount ' || v_transaction_amount ||
                     ' is negative - amounts must be positive; use D/C for direction.');

            WHEN e_invalid_transaction_type THEN
                IF c_inner_transaction%ISOPEN THEN
                    CLOSE c_inner_transaction;
                END IF;
                INSERT INTO wkis_error_log
                    (transaction_no, transaction_date, description, error_msg)
                VALUES
                    (v_transaction_no, v_transaction_date, v_description,
                     'Type Error: Transaction type ''' || v_transaction_type ||
                     ''' is invalid - only D (debit) and C (credit) are accepted.');

            WHEN OTHERS THEN
                IF c_inner_transaction%ISOPEN THEN
                    CLOSE c_inner_transaction;
                END IF;
                INSERT INTO wkis_error_log
                    (transaction_no, transaction_date, description, error_msg)
                VALUES
                    (v_transaction_no, v_transaction_date, v_description, SQLERRM);
        END;
    END LOOP;

    CLOSE c_outer_transaction;

    -- =========================================================================
    -- COMMIT — single commit after all processing (Member 1). Not inside any
    -- loop; intentional and required.
    -- =========================================================================
    COMMIT;

END;
/
