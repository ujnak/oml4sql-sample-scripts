-----------------------------------------------------------------------
--   Oracle Machine Learning for SQL (OML4SQL) 23ai
-- 
--   OML R Extensible - Association Rules Algorithm - dmrardemo.sql
--   
--   Copyright (c) 2024 Oracle Corporation and/or its affilitiates.
--
--  The Universal Permissive License (UPL), Version 1.0
--
--  https://oss.oracle.com/licenses/upl/
-----------------------------------------------------------------------
SET serveroutput ON
SET trimspool ON  
SET pages 10000
SET linesize 140
SET LONG 10000
SET echo ON


-----------------------------------------------------------------------
--                            SET UP THE DATA
-----------------------------------------------------------------------

-- Cleanup old training data view for repeat runs
BEGIN EXECUTE IMMEDIATE 'DROP VIEW ar_build_v';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Create a view for building association rules model
-- The data for this sample is composed from a small subset of
-- sales transactions in the SH schema - listing the (multiple)
-- items bought by a set of customers with ids in the range
-- 100001-104500.
--
CREATE VIEW ar_build_v AS
SELECT cust_id, prod_name, prod_category, amount_sold
FROM (SELECT a.cust_id, b.prod_name, b.prod_category,
             a.amount_sold
        FROM sh.sales a, sh.products b
       WHERE a.prod_id = b.prod_id AND
             a.cust_id between 100001 AND 104500);


--
-- We will build two separate models for rules and itemsets, respectively.
--
-----------------------------------------------------------------------
--                          BUILD THE MODEL for RULES
-----------------------------------------------------------------------

-- Cleanup old model with same name for repeat runs
BEGIN DBMS_DATA_MINING.DROP_MODEL('RAR_SH_AR_SAMPLE');
EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN 
sys.rqScriptDrop('RAR_BUILD');
sys.rqScriptDrop('RAR_DETAILS');
EXCEPTION WHEN OTHERS THEN NULL; END;
/

------------
-- R scripts
--
-- The R scripts are created by users using sys.rqScriptCreate to define
-- their own approaches in R for building Association Rules models in 
-- ODM framework.

BEGIN
  -- The BUILD script will be invoked during CREATE_MODEL
  -- Our script here uses the apriori algorithm in R's arules package 
  -- to mine rules
  sys.rqScriptCreate('RAR_BUILD', 
    'function(dat){
     library(arules)
     trans <- as(split(dat[["PROD_NAME"]], dat[["CUST_ID"]]), "transactions")
     r <- apriori(trans, parameter = list(minlen=2, supp=0.1, conf=0.5, target="rules"))
     as(r, "data.frame")}');

  -- The DETAILS script, along with the FORMAT script below will be 
  -- invoked during CREATE_MODEL. A model view will be generated with 
  -- the output of the DETAILS script. We deliver the mined rules through
  -- the model view                       
  sys.rqScriptCreate('RAR_DETAILS',
     'function(mod) {mod}');
END;
/

---------------
-- CREATE MODEL
--
-- let case_id_column_name be NULL, as the case_id_column_name should be
-- identified in the R BUILD script
DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
  v_data_query VARCHAR2(32767);
BEGIN 
  -- Model Settings ---------------------------------------------------
  v_setlst('ALGO_EXTENSIBLE_LANG')  := 'R';
  v_setlst('RALG_BUILD_FUNCTION')   := 'RAR_BUILD';
  v_setlst('RALG_DETAILS_FUNCTION') := 'RAR_DETAILS';
  v_setlst('RALG_DETAILS_FORMAT')   := 
    q'|select cast('a' as varchar2(100)) rules, 1 support, 1 confidence, 1 coverage, 1 lift, 1 count from dual|';

  v_data_query := q'|SELECT * FROM AR_BUILD_V|';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'RAR_SH_AR_SAMPLE',
    mining_function     => 'ASSOCIATION',
    data_query          => v_data_query,
    set_list            => v_setlst,
    case_id_column_name => NULL
  );
END;
/

------------------------
-- DISPLAY MODEL SETTINGS 
--
olumn setting_name format a30
column setting_value format a40
select setting_name, setting_value from user_mining_model_settings
where model_name = 'RAR_SH_AR_SAMPLE'
order by setting_name;

-------------------------
-- DISPLAY MODEL METADATA
--
column model_name format a20
column mining_function format a20
column algorithm format a20
select model_name, mining_function, algorithm from user_mining_models
where model_name = 'RAR_SH_AR_SAMPLE';

------------------------------------
-- DISPLAY THE RULES USING MODEL VIEW
-- The model view was generated during CREATE_MODEL
--
column partition_name format a5
column rules format A30
select * from DM$VDRAR_SH_AR_SAMPLE order by confidence desc;



-----------------------------------------------------------------------
--                          BUILD THE MODEL for ITEMSETS
-----------------------------------------------------------------------

-- Cleanup old model with same name for repeat runs
BEGIN DBMS_DATA_MINING.DROP_MODEL('RAR_SH_FI_SAMPLE');
EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN
-- Our script here uses the apriori algorithm in R's arules package to 
-- mine itemsets
  sys.rqScriptCreate('RAR_BUILD', 
    'function(dat){
     library(arules)
     trans <- as(split(dat[["PROD_NAME"]], dat[["CUST_ID"]]), "transactions")
     items <- apriori(trans, parameter = list(supp=0.1, target="frequent"))
     df <- as(items, "data.frame")
     df[, c("items", "support")]}', v_overwrite => TRUE);
            
  sys.rqScriptCreate('RAR_DETAILS',
     'function(mod) {mod}', v_overwrite => TRUE);
END;
/

---------------
-- CREATE MODEL
--
DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
  v_data_query VARCHAR2(32767);
BEGIN
  -- Model Settings ---------------------------------------------------
  v_setlst('ALGO_EXTENSIBLE_LANG')  := 'R';
  v_setlst('RALG_BUILD_FUNCTION')   := 'RAR_BUILD';
  v_setlst('RALG_DETAILS_FUNCTION') := 'RAR_DETAILS';
  v_setlst('RALG_DETAILS_FORMAT')   :=
    q'|select cast('a' as varchar2(100)) items, 1 support from dual|';

  v_data_query := q'|SELECT * FROM AR_BUILD_V|';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'RAR_SH_FI_SAMPLE',
    mining_function     => 'ASSOCIATION',
    data_query          => v_data_query,
    set_list            => v_setlst,
    case_id_column_name => NULL
  );
END;
/

-------------------------
-- DISPLAY MODEL SETTINGS
--
column setting_name format a30
column setting_value format a40
select setting_name, setting_value from user_mining_model_settings
where model_name = 'RAR_SH_FI_SAMPLE'
order by setting_name;

-------------------------
-- DISPLAY MODEL METADATA
--
column model_name format a20
column mining_function format a20
column algorithm format a20
select model_name, mining_function, algorithm from user_mining_models
where model_name = 'RAR_SH_FI_SAMPLE';

---------------------------------------
-- DISPLAY THE ITEMSETS USING MODEL VIEW
--
column partition_name format a5
column items format a50
select * from DM$VDRAR_SH_FI_SAMPLE order by support desc;

