-----------------------------------------------------------------------
--   Oracle Machine Learning for SQL (OML4SQL) 23ai
-- 
--   Feature and Row Extraction - CUR Decomposition Algorithm - dmcurdemo.sql
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
--                            SAMPLE PROBLEMS
-----------------------------------------------------------------------
-- Perform CUR decomposition-based attribute and row importance for:
-- Selecting top attributes and rows with highest importance scores
-- (Select approximately top 10 attributes and top 50 rows)
--
-- Cleanup old model with the same name
BEGIN DBMS_DATA_MINING.DROP_MODEL('CUR_SH_SAMPLE');
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Build a CUR model
DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
BEGIN
  -- Select CUR Decomposition as the Attribute Importance algorithm
  v_setlst('ALGO_NAME')            := 'ALGO_CUR_DECOMPOSITION';
  -- Set row importance to be enabled (disabled by default)
  v_setlst('CURS_ROW_IMPORTANCE')  := 'CURS_ROW_IMP_ENABLE';
  -- Set approximate number of attributes to be selected
  v_setlst('CURS_APPROX_ATTR_NUM') := '10';
  -- Set approximate number of rows to be selected
  v_setlst('CURS_APPROX_ROW_NUM')  := '50';
  -- Set SVD rank parameter
  v_setlst('CURS_SVD_RANK')        := '5';
  -- Examples of possible overrides are:
  -- v_setlst('ODMS_RANDOM_SEED') := '1';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'CUR_SH_SAMPLE',
    mining_function     => 'ATTRIBUTE_IMPORTANCE',
    data_query          => 'SELECT * FROM MINING_DATA_BUILD_V',
    set_list            => v_setlst,
    case_id_column_name => 'cust_id');
END;
/

-- Display model settings
column setting_name format a30
column setting_value format a30
SELECT setting_name, setting_value
  FROM user_mining_model_settings
 WHERE model_name = 'CUR_SH_SAMPLE'
ORDER BY setting_name;

-- Display model signature
column attribute_name format a40
column attribute_type format a20
SELECT attribute_name, attribute_type
  FROM user_mining_model_attributes
 WHERE model_name = 'CUR_SH_SAMPLE'
ORDER BY attribute_name;

-- Get a list of model views
col view_name format a30
col view_type format a50
SELECT view_name, view_type FROM user_mining_model_views
  WHERE model_name='CUR_SH_SAMPLE'
  ORDER BY view_name;

-- Display global model details
column name format a30
column numeric_value format 9999999999
SELECT name, numeric_value
  FROM DM$VGCUR_SH_SAMPLE
ORDER BY name;

-- Attribute importance and ranks
column attribute_name format a15
column attribute_subname format a18
column attribute_value format a15
column attribute_importance format 9.99999999
column attribute_rank format 999999

SELECT attribute_name, attribute_subname, attribute_value, 
       attribute_importance, attribute_rank
FROM   DM$VCCUR_SH_SAMPLE
ORDER BY attribute_rank, attribute_name, attribute_subname,
         attribute_value;

-- Row importance and ranks
column case_id format 999999999
column row_importance format 9.99999999
column row_rank format 999999999

SELECT case_id, row_importance, row_rank
  FROM DM$VRCUR_SH_SAMPLE
ORDER BY row_rank, case_id;
