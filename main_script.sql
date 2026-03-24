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



    -- --------------------------------------------------------
    -- Outer loop: process one transaction at a time
    -- --------------------------------------------------------



    -- ----------------------------------------------------
    -- Inner loop: process each detail line of this transaction
    -- ----------------------------------------------------