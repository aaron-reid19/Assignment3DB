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
    -- (must be explicit cursor — no SELECT INTO on NEW_TRANSACTIONS)

    -- inner cursor: grabs all detail rows for a given transaction number

    -- variables to hold fetched cursor values and running totals
    -- e.g. transaction number, description, date, debit/credit sums, etc.

    CURSOR c_outer_transaction IS
        SELECT transaction_no,
               MIN(transaction_date) AS transaction_date,
               MIN(description) AS description
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
    -- e.g. transaction number, description, date, debit/credit sums, etc.
    v_transaction_no        new_transactions.transaction_no%TYPE;
    v_transaction_date      new_transactions.transaction_date%TYPE;
    v_description           new_transactions.description%TYPE;
    v_account_no            new_transactions.account_no%TYPE;
    v_transaction_type      new_transactions.transaction_type%TYPE;
    v_transaction_amount    new_transactions.transaction_amount%TYPE;
    v_total_debits          NUMBER := 0;
    v_total_credits         NUMBER := 0;
    v_default_trans_type    account_type.default_trans_type%TYPE;
    -- =========================================================================
    -- CUSTOM EXCEPTION DECLARATIONS (Members 2 & 3)
    -- =========================================================================

    -- Custom exception for rows missing a transaction number
    e_null_transaction_no EXCEPTION;

    -- Custom exception for accounting unbalanced transactions (debits not equal to credits)
    e_unbalanced_transaction EXCEPTION;

    -- Custom exception for account numbers not found in charts of accounts
    e_invalid_account_no EXCEPTION;
    -- Member 2: exception for NULL transaction number

    -- Member 2: exception for debits not equal to credits

    -- Member 2: exception for invalid account number (doesn't exist in ACCOUNT)

    -- can't have negative dollar amounts - use D/C to express direction 
    negative_amount EXCEPTION;

    -- only D and C are legit transaction types
    invalid_transaction_type EXCEPTION;

BEGIN

    -- =========================================================================
    -- OUTER CURSOR LOOP — one iteration per distinct transaction (Member 1)
    -- =========================================================================

    -- open outer cursor and loop through each transaction number

    OPEN c_outer_transaction;

    LOOP
        FETCH c_outer_transaction
        INTO v_transaction_no, v_transaction_date, v_description;

        EXIT WHEN c_outer_transaction%NOTFOUND;

        v_total_debits := 0;
        v_total_credits := 0;

        -- =====================================================================
        -- BEGIN inner block for per-transaction exception handling
        -- (errors in one transaction must NOT kill the others)
        -- =====================================================================

        BEGIN
            -- =================================================================
            -- ERROR 1 — NULL Transaction Number (Member 2)
            -- Check if the transaction number is NULL before doing anything else.
            -- If it is, raise the custom exception — don't process this one.
            -- =================================================================
            IF r_outer.transaction_no IS NULL THEN
                RAISE e_null_transaction_no;
            END IF;


            -- =================================================================
            -- ERROR 2 — Debits Not Equal to Credits (Member 2)
            -- Sum up all debit amounts and all credit amounts for this transaction.
            -- If they don't balance, raise the error BEFORE inserting anything.
            -- =================================================================
            SELECT 
                SUM(CASE WHEN transaction_type = 'D' THEN transaction_amount ELSE 0 END),
                SUM(CASE WHEN transaction_type = 'C' THEN transaction_amount ELSE 0 END)
            INTO v_debit_total, v_credit_total
            FROM NEW_TRANSACTIONS
            WHERE transaction_no = r_outer.transaction_no;

            IF v_debit_total != v_credit_total THEN
                RAISE e_unbalanced_transaction;
            END IF;


            -- =================================================================
            -- INNER CURSOR LOOP — one iteration per detail row (Member 1)
            -- This is where we walk through each line of the transaction.
            -- =================================================================

            -- open inner cursor for the current transaction number

            OPEN c_inner_transaction(v_transaction_no);

            LOOP
                FETCH c_inner_transaction
                INTO v_account_no, v_transaction_type, v_transaction_amount;

                EXIT WHEN c_inner_transaction%NOTFOUND;
                -- =============================================================
                -- ERROR 3 — Invalid Account Number (Member 2)
                -- Verify the account number exists in the ACCOUNT table.
                -- If it doesn't, raise the error — skip the whole transaction.
                -- =============================================================
                SELECT COUNT(*) INTO v_account_count
                FROM ACCOUNT
                WHERE account_no = r_inner.account_no; 

                IF v_account_count = 0 THEN
                    RAISE e_invalid_account_no;
                END IF;


                -- =============================================================
                -- ERROR 4 — Negative Amount?
                -- dollar value should always be positive
                -- flip the direction with D or C
                -- =============================================================
                
                IF v_transaction_amount < 0 THEN
                    RAISE negative_amount;
                END IF;

                -- =============================================================
                -- ERROR 5 — Valid transaction type? 
                -- D and C are the only options - anything else is bad data
                -- =============================================================
                
                IF v_transaction_type NOT IN ('D', 'C') THEN
                    RAISE invalid_transaction_type;
                END IF;

                -- =============================================================
                -- INSERT INTO TRANSACTION_DETAIL (Member 1)
                -- One row per detail line — mirrors the NEW_TRANSACTIONS row.
                -- =============================================================


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
                -- =============================================================
                -- UPDATE ACCOUNT BALANCE (Member 1)
                -- Adjust the account balance based on transaction type (D/C)
                -- and the account's default type:
                --   Debit accounts:  add for D, subtract for C
                --   Credit accounts: subtract for D, add for C
                -- =============================================================


            -- close inner cursor

                SELECT at.default_trans_type
                INTO v_default_trans_type
                FROM account a
                JOIN account_type at
                    ON a.account_type_code = at.account_type_code
                WHERE a.account_no = v_account_no;

                UPDATE account
                SET account_balance =
                    account_balance +
                    CASE
                        WHEN v_default_trans_type = 'D' AND v_transaction_type = 'D' THEN v_transaction_amount
                        WHEN v_default_trans_type = 'D' AND v_transaction_type = 'C' THEN -v_transaction_amount
                        WHEN v_default_trans_type = 'C' AND v_transaction_type = 'D' THEN -v_transaction_amount
                        ELSE v_transaction_amount
                    END
                WHERE account_no = v_account_no;

            -- close inner cursor
            END LOOP;

            CLOSE c_inner_transaction;
            -- =================================================================
            -- INSERT INTO TRANSACTION_HISTORY (Member 1)
            -- One row per transaction (not per detail row).
            -- Only reaches here if no errors were raised above.
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
            -- DELETE FROM NEW_TRANSACTIONS (Member 1)
            -- Remove the processed transaction rows — they've been moved
            -- into TRANSACTION_HISTORY and TRANSACTION_DETAIL successfully.
            -- =================================================================

            DELETE FROM new_transactions
            WHERE transaction_no = v_transaction_no;

        -- =====================================================================
        -- EXCEPTION BLOCK — per-transaction error handling (Members 2 & 3)
        -- Only the FIRST error per transaction gets recorded.
        -- Once caught, we skip remaining checks for this transaction number.
        -- =====================================================================
        

        EXCEPTION

            -- Member 2: WHEN null_transaction_number
            -- log to WKIS_ERROR_LOG with a descriptive custom message
            -- leave the row(s) in NEW_TRANSACTIONS
            WHEN e_null_transaction_no THEN
                INSERT INTO WKIS_ERROR_LOG 
                    (transaction_no, error_msg)
                VALUES 
                    (r_outer.transaction_no, 'Validation Error: Transaction ID is NULL. ');
            
            -- Member 2: WHEN debits_not_equal_credits
            -- log to WKIS_ERROR_LOG with a descriptive custom message
            -- leave the transaction in NEW_TRANSACTIONS
            WHEN e_unbalanced_transaction THEN
                INSERT INTO WKIS_ERROR_LOG 
                    (transaction_no, error_msg)
                VALUES 
                    (r_outer.transaction_no, 'Accounting Error: Unbalanced entry Debits: ' || v_debit_total || ' Credits: ' || v_credit_total);

            -- Member 2: WHEN debits_not_equal_credits
            -- log to WKIS_ERROR_LOG with a descriptive custom message
            -- leave the transaction in NEW_TRANSACTIONS

            -- Member 2: WHEN invalid_account_number
            -- log to WKIS_ERROR_LOG with a descriptive custom message
            -- leave the transaction in NEW_TRANSACTIONS
            WHEN e_invalid_account_no THEN
                INSERT INTO WKIS_ERROR_LOG 
                    (transaction_no, error_msg)
                VALUES 
                    (r_outer.transaction_no, 'Account Error: The account number does not exist. ');

            -- negative dollar amount - shouldn't happen - log it
            -- log to WKIS_ERROR_LOG with a descriptive custom message
            -- leave the transaction in NEW_TRANSACTIONS
            
            WHEN negative_amount THEN
            	INSERT INTO WKIS_ERROR_LOG 
            	    (transaction_no, transaction_date, description, error_msg)
            	VALUES 
                    (v_transaction_no, v_transaction_date, v_description, 
                    'Negative Transaction Amount: transaction amounts should be positive.');

            -- WHEN invalid_transaction_type
            -- log to WKIS_ERROR_LOG with a descriptive custom message
            -- leave the transaction in NEW_TRANSACTIONS
            
            WHEN invalid_transaction_type THEN
                INSERT INTO WKIS_ERROR_LOG 
                    (transaction_no, transaction_date, description, error_msg)
                VALUES 
                    (v_transaction_no, v_transaction_date, v_description, 
                    'Invalid Transaction Type: only D (debit) and C are accepted.');

            -- Something unexpected - let Oracle tell us what went wrong
            -- use SQLERRM for the message — no custom message needed here
            -- log to WKIS_ERROR_LOG
            
            WHEN OTHERS THEN
                INSERT INTO WKIS_ERROR_LOG 
                    (transaction_no, transaction_date, description, error_msg)
                VALUES 
                    (v_transaction_no, v_transaction_date, v_description, SQLERRM);

        -- =====================================================================
        -- END inner block
        -- =====================================================================

    -- close outer cursor / end outer loop

        END;
    -- close outer cursor / end outer loop
    END LOOP;

    CLOSE c_outer_transaction;
    -- =========================================================================
    -- COMMIT — one single commit AFTER all processing is done (Member 1)
    -- NOT inside any loop. This is intentional and required.
    -- =========================================================================

    COMMIT;

END;
/