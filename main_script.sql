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
Declare
    CURSOR c_outer_txn IS 
    SELECT DISTINCT
        transaction_no,
        transaction_date,
        description
    from NEW_TRANSACTIONS
    ORDER BY transaction_no;

    CURSOR c_inner_detail (p_txn_no NUMBER) IS
    SELECT account_no, transaction_type, transaction_amount
    FROM NEW_TRANSACTIONS
    WHERE transaction_no = p_txn_no;
    FOR UPDATE;

    BEGIN

        FOR r_outer IN c_outer_txn LOOP
            INSERT INTO transaction_history (
                transaction_no,
                transaction_date,
                description
            ) VALUES ( 
                r_outer.transaction_no,
                r_outer.transaction_date,
                r_outer.description
            );

            FOR r_inner IN c_inner_detail(r_outer.transaction_no) LOOP
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
                
                DELETE FROM NEW_TRANSACTIONS
                WHERE CURRENT OF c_inner_detail;
                
        END LOOP;

        COMMIT;
    END LOOP;
END;
/

    BEGIN

        FOR r_outer IN c_outer_txn LOOP
            INSERT INTO transaction_history (
                transaction_no,
                transaction_date,
                description
            ) VALUES ( 
                r_outer.transaction,
                r_outer.transaction_date,
                r_outer.description
            );

        COMMIT;
    END LOOP;
END;
/


    -- --------------------------------------------------------
    -- Outer loop: process one transaction at a time
    -- --------------------------------------------------------



    -- ----------------------------------------------------
    -- Inner loop: process each detail line of this transaction
    -- ----------------------------------------------------