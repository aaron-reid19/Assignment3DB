-- ============================================================
-- Assignment 3 Part 1: WKIS Transaction Processor
-- Course:   CPRG307
-- Authors:  Aaron Reid, Amal Musse, Kaley Wood
-- Date:     February 3, 2026
-- Purpose:  Reads transactions from NEW_TRANSACTIONS, inserts
--           into TRANSACTION_HISTORY and TRANSACTION_DETAIL,
--           updates ACCOUNT balances, and removes processed
--           rows from NEW_TRANSACTIONS.
-- ============================================================
DECLARE
    -- outer cursor: one row per unique transaction, ordered so processing is predictable
    CURSOR c_outer_txn IS 
    SELECT DISTINCT
        transaction_no,
        transaction_date,
        description
    FROM NEW_TRANSACTIONS
    ORDER BY transaction_no;

    -- inner cursor: all detail lines for one transaction, parameterized on the outer transaction number
    -- FOR UPDATE is required because we use WHERE CURRENT OF to delete rows inside the loop
    CURSOR c_inner_detail (p_txn_no NUMBER) IS
    SELECT account_no, transaction_type, transaction_amount
    FROM NEW_TRANSACTIONS
    WHERE transaction_no = p_txn_no
    FOR UPDATE;

    -- holds the default transaction type (D or C) for the account currently being processed
    v_default_type CHAR(1);

BEGIN

    -- outer loop: one full pass per transaction
    FOR r_outer IN c_outer_txn LOOP
        -- write the transaction header once — before processing any detail lines
        INSERT INTO transaction_history (
            transaction_no,
            transaction_date,
            description
        ) VALUES ( 
            r_outer.transaction_no,
            r_outer.transaction_date,
            r_outer.description
        );

        -- inner loop: one pass per detail line within this transaction
        FOR r_inner IN c_inner_detail(r_outer.transaction_no) LOOP
            -- record this detail line in the permanent table
            INSERT INTO transaction_detail (
                transaction_no,
                account_no,
                transaction_type,
                transaction_amount
            ) VALUES (
                r_outer.transaction_no,
                r_inner.account_no,
                r_inner.transaction_type,
                r_inner.transaction_amount     
            );
            
            -- look up the default transaction type for this account
            -- needed to decide whether this entry adds or subtracts from the balance
            SELECT at.default_trans_type INTO v_default_type
            FROM account a
            JOIN account_type at ON a.account_type_code = at.account_type_code
            WHERE a.account_no = r_inner.account_no;

            -- if the transaction type matches the account default, the balance increases
            -- if it's the opposite side, the balance decreases
            UPDATE account
            SET account_balance =
                CASE WHEN r_inner.transaction_type = v_default_type
                    THEN account_balance + r_inner.transaction_amount
                    ELSE account_balance - r_inner.transaction_amount
            END
            WHERE account_no = r_inner.account_no;

            -- row is fully processed — remove it from the staging table
            DELETE FROM NEW_TRANSACTIONS
            WHERE CURRENT OF c_inner_detail;
            
        END LOOP;
        -- commit after every complete transaction so each one succeeds or fails as a unit
        COMMIT;

    END LOOP;

END;
/