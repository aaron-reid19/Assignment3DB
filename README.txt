================================================================
  WKIS Transaction Processor — README
  Assignment 3 Part 1 | CPRG307
  Authors: Aaron Reid, Amal Musse, Kaley Wood
  Date:    February 3, 2026
================================================================

OVERVIEW
--------
This project implements a PL/SQL anonymous block for the
We Keep It Storage (WKIS) double-entry accounting system.

The program reads pending transactions from NEW_TRANSACTIONS,
inserts records into TRANSACTION_HISTORY and TRANSACTION_DETAIL,
updates the corresponding ACCOUNT balances, and removes each
processed row from the holding table.


----------------------------------------------------------------
SCRIPT EXECUTION ORDER
----------------------------------------------------------------

Run the following scripts in Oracle SQL*Plus or Oracle APEX
in this exact order before executing the main program:

  1. create_wkis.sql
     Creates all tables and the WKIS sequence.
     NOTE: This script drops existing tables first —
     run this to reset the database to a clean state.

  2. constraints_wkis.sql
     Adds primary keys, foreign keys, and check constraints
     to the tables created in step 1.

  3. load_wkis.sql
     Populates the ACCOUNT_TYPE and ACCOUNT reference tables
     with baseline data required by the program.

  4. Load ONE of the following test datasets:

     a. A3_test_dataset_1_-_Clean.sql     [recommended first]
        Contains clean, valid transactions only.
        Use this to verify core logic is working correctly.

                        OR

     b. A3_test dataset_2 - Clean and Erroneous.sql
        Contains a mix of valid and erroneous transactions.
        Use this to verify exception handling behaviour.

  5. PLSQL-Script.sql
     The main program. Run this after loading a dataset.


----------------------------------------------------------------
RESETTING BETWEEN TEST RUNS
----------------------------------------------------------------

To re-run the program with fresh data:

  1. Re-run create_wkis.sql  (drops and recreates all tables)
  2. Re-run constraints_wkis.sql
  3. Re-run load_wkis.sql
  4. Re-run your chosen test dataset
  5. Re-run PLSQL-Script.sql

Do NOT skip step 1 between runs — leftover data from a
previous execution will cause constraint violations.


----------------------------------------------------------------
DATABASE TABLES
----------------------------------------------------------------

  ACCOUNT_TYPE      Reference table — account categories with
                    default transaction type (D = Debit, C = Credit)

  ACCOUNT           Chart of accounts with current balances.
                    Balances are updated by the main program.

  NEW_TRANSACTIONS  Holding table — staging area for incoming
                    transactions. Rows are removed after processing.

  TRANSACTION_HISTORY  One row per transaction (header record).

  TRANSACTION_DETAIL   One row per account line within a transaction.

  WKIS_ERROR_LOG    Captures transactions that fail during processing
                    (used in Part 2 with erroneous data).


----------------------------------------------------------------
NOTES
----------------------------------------------------------------

  - Do NOT modify any table structures or constraints.
  - The program assumes clean data (no exception handling in Part 1).
  - Do not code to the test dataset — the instructor will evaluate
    using a different dataset.
  - Submit PLSQL-Script.sql as a plain .sql text file (do not zip).


----------------------------------------------------------------
DISCLAIMER
----------------------------------------------------------------

  This README was generated with the assistance of Claude,
  an AI assistant by Anthropic. 
  
================================================================