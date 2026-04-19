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

    -- =========================================================================
    -- CUSTOM EXCEPTION DECLARATIONS (Members 2 & 3)
    -- =========================================================================

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

        -- =====================================================================
        -- BEGIN inner block for per-transaction exception handling
        -- (errors in one transaction must NOT kill the others)
        -- =====================================================================

            -- =================================================================
            -- ERROR 1 — NULL Transaction Number (Member 2)
            -- Check if the transaction number is NULL before doing anything else.
            -- If it is, raise the custom exception — don't process this one.
            -- =================================================================


            -- =================================================================
            -- ERROR 2 — Debits Not Equal to Credits (Member 2)
            -- Sum up all debit amounts and all credit amounts for this transaction.
            -- If they don't balance, raise the error BEFORE inserting anything.
            -- =================================================================


            -- =================================================================
            -- INNER CURSOR LOOP — one iteration per detail row (Member 1)
            -- This is where we walk through each line of the transaction.
            -- =================================================================

            -- open inner cursor for the current transaction number

                -- =============================================================
                -- ERROR 3 — Invalid Account Number (Member 2)
                -- Verify the account number exists in the ACCOUNT table.
                -- If it doesn't, raise the error — skip the whole transaction.
                -- =============================================================


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


                -- =============================================================
                -- UPDATE ACCOUNT BALANCE (Member 1)
                -- Adjust the account balance based on transaction type (D/C)
                -- and the account's default type:
                --   Debit accounts:  add for D, subtract for C
                --   Credit accounts: subtract for D, add for C
                -- =============================================================


            -- close inner cursor

            -- =================================================================
            -- INSERT INTO TRANSACTION_HISTORY (Member 1)
            -- One row per transaction (not per detail row).
            -- Only reaches here if no errors were raised above.
            -- =================================================================


            -- =================================================================
            -- DELETE FROM NEW_TRANSACTIONS (Member 1)
            -- Remove the processed transaction rows — they've been moved
            -- into TRANSACTION_HISTORY and TRANSACTION_DETAIL successfully.
            -- =================================================================


        -- =====================================================================
        -- EXCEPTION BLOCK — per-transaction error handling (Members 2 & 3)
        -- Only the FIRST error per transaction gets recorded.
        -- Once caught, we skip remaining checks for this transaction number.
        -- =====================================================================

        EXCEPTION

            -- Member 2: WHEN null_transaction_number
            -- log to WKIS_ERROR_LOG with a descriptive custom message
            -- leave the row(s) in NEW_TRANSACTIONS

            -- Member 2: WHEN debits_not_equal_credits
            -- log to WKIS_ERROR_LOG with a descriptive custom message
            -- leave the transaction in NEW_TRANSACTIONS

            -- Member 2: WHEN invalid_account_number
            -- log to WKIS_ERROR_LOG with a descriptive custom message
            -- leave the transaction in NEW_TRANSACTIONS

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

    -- =========================================================================
    -- COMMIT — one single commit AFTER all processing is done (Member 1)
    -- NOT inside any loop. This is intentional and required.
    -- =========================================================================

    COMMIT;

END;
/