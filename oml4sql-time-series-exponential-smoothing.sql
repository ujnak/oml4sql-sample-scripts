-----------------------------------------------------------------------
--   Oracle Machine Learning for SQL (OML4SQL) 23ai
-- 
--   Time Series - Exponential Smoothing Algorithm - dmesmdemo.sql
--   
--   Copyright (c) 2024 Oracle Corporation and/or its affilitiates.
--
--  The Universal Permissive License (UPL), Version 1.0
--
--  https://oss.oracle.com/licenses/upl/
-----------------------------------------------------------------------
SET ECHO ON
SET FEEDBACK 1
SET NUMWIDTH 10
SET LINESIZE 80
SET TRIMSPOOL ON
SET TAB OFF
SET PAGESIZE 100

-----------------------------------------------------------------------
--                            SET UP THE DATA
-----------------------------------------------------------------------
-- Cleanup old model with the same name
BEGIN DBMS_DATA_MINING.DROP_MODEL('ESM_SH_SAMPLE');
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Create input time series
create or replace view esm_sh_data 
       as select time_id, amount_sold 
       from sh.sales;

-- Build the ESM model
DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
  v_data_query VARCHAR2(32767);
BEGIN
  -- Model Settings ---------------------------------------------------
  --
  -- Select ESM as the algorithm
  v_setlst('ALGO_NAME') := 'ALGO_EXPONENTIAL_SMOOTHING';
  -- Set accumulation interval to be quarter
  v_setlst('EXSM_INTERVAL') := 'EXSM_INTERVAL_QTR';
  -- Set prediction step to be 4 quarters (one year)
  v_setlst('EXSM_PREDICTION_STEP') := '4';
  -- Set ESM model to be Holt-Winters
  v_setlst('EXSM_MODEL') := 'EXSM_WINTERS';
  -- Set seasonal cycle to be 4 quarters
  v_setlst('EXSM_SEASONALITY') := '4';

  v_data_query := q'|SELECT * FROM ESM_SH_DATA|';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'ESM_SH_SAMPLE',
    mining_function     => 'TIME_SERIES',
    data_query          => v_data_query,
    set_list            => v_setlst,
    case_id_column_name => 'TIME_ID',
    target_column_name  => 'AMOUNT_SOLD'
  );
END;
/

-- output setting table
column setting_name format a30
column setting_value format a30
SELECT setting_name, setting_value
  FROM user_mining_model_settings
 WHERE model_name = upper('ESM_SH_SAMPLE')
ORDER BY setting_name;

-- get signature
column attribute_name format a40
column attribute_type format a20
SELECT attribute_name, attribute_type
FROM   user_mining_model_attributes
  WHERE  model_name=upper('ESM_SH_SAMPLE')
  ORDER BY attribute_name;


-- get global diagnostics
column name format a20
column numeric_value format a20
column string_value format a15
SELECT name, 
to_char(numeric_value, '99999.99EEEE') numeric_value, 
string_value FROM DM$VGESM_SH_SAMPLE
  ORDER BY name;

-- get predictions
set heading on
SET LINES 100
SET PAGES 105
COLUMN CASE_ID FORMAT A30
COLUMN VALUE FORMAT 9999999
COLUMN PREDICTION FORMAT 99999999
COLUMN LOWER FORMAT 99999999
COLUMN UPPER FORMAT 99999999
select case_id, value, prediction, lower, upper 
from DM$VPESM_SH_SAMPLE
ORDER BY case_id;
