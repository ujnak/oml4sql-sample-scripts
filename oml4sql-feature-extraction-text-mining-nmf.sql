-----------------------------------------------------------------------
--   Oracle Machine Learning for SQL (OML4SQL) 23ai
-- 
--   Feature Extraction - NMF Algorithm with Text Mining - dmtxtnmf.sql
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
SET echo ON

-----------------------------------------------------------------------
--                            SAMPLE PROBLEM
-----------------------------------------------------------------------
-- Mine text features using NMF algorithm. 

-----------------------------------------------------------------------
--                            SET UP AND ANALYZE THE DATA
-----------------------------------------------------------------------
-- Create a policy for text feature extraction
-- The policy will include stemming
begin
  ctx_ddl.drop_policy('dmdemo_nmf_policy');
exception when others then null;
end;
/
begin
  ctx_ddl.drop_preference('dmdemo_nmf_lexer');
exception when others then null;
end;
/
begin
  ctx_ddl.create_preference('dmdemo_nmf_lexer', 'BASIC_LEXER');
  ctx_ddl.set_attribute('dmdemo_nmf_lexer', 'index_stems', 'ENGLISH');
--  ctx_ddl.set_attribute('dmdemo_nmf_lexer', 'index_themes', 'YES');
end;
/
begin
  ctx_ddl.create_policy('dmdemo_nmf_policy', lexer=>'dmdemo_nmf_lexer');
end;
/

-----------------------------------------------------------------------
--                            BUILD THE MODEL
-----------------------------------------------------------------------

-- Cleanup old model and objects for repeat runs
BEGIN DBMS_DATA_MINING.DROP_MODEL('T_NMF_Sample');
EXCEPTION WHEN OTHERS THEN NULL; END;
/

--------------------------------------------------------
-- CREATE A NEW MODEL USING V_SETLST (NO SETTINGS TABLE)
-- Note the transform makes the 'comments' attribute 
-- to be treated as unstructured text data
--
DECLARE
  v_xlst   dbms_data_mining_transform.TRANSFORM_LIST;
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
  v_data_query VARCHAR2(32767);
BEGIN
  dbms_data_mining_transform.SET_TRANSFORM(
    v_xlst, 'comments', null, 'comments', null, 'TEXT(TOKEN_TYPE:STEM)');
    -- v_xlst, 'comments', null, 'comments', null, 'TEXT(TOKEN_TYPE:THEME)');

  -- Model Settings ---------------------------------------------------
  v_setlst('ALGO_NAME') := 'ALGO_NONNEGATIVE_MATRIX_FACTOR';
  v_setlst('PREP_AUTO') := 'ON';
  v_setlst('ODMS_TEXT_POLICY_NAME') := 'DMDEMO_NMF_POLICY';

  v_data_query := q'|SELECT * FROM mining_build_text|';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'T_NMF_Sample',
    mining_function     =>'FEATURE_EXTRACTION',
    data_query          => v_data_query,
    set_list            => v_setlst,
    case_id_column_name => 'CUST_ID',
    xform_list          => v_xlst
  );
END;
/

-------------------------
-- DISPLAY MODEL SETTINGS
--
column setting_name format a30;
column setting_value format a30;
SELECT setting_name, setting_value
  FROM user_mining_model_settings
 WHERE model_name = 'T_NMF_SAMPLE'
ORDER BY setting_name;

--------------------------
-- DISPLAY MODEL SIGNATURE
--
column attribute_name format a40
column attribute_type format a20
SELECT attribute_name, attribute_type
  FROM user_mining_model_attributes
 WHERE model_name = 'T_NMF_SAMPLE'
ORDER BY attribute_name;

------------------------
-- DISPLAY MODEL DETAILS
--

-- Get a list of model views
col view_name format a30
col view_type format a50
SELECT view_name, view_type FROM user_mining_model_views
WHERE model_name='T_NMF_SAMPLE'
ORDER BY view_name;

column attribute_name format a30;
column attribute_value format a20;
column coefficient format 9.99999;
set pages 15;
SET line 120;
break ON feature_id;
SELECT * FROM (
SELECT feature_id,
       nvl2(attribute_subname,
            attribute_name||'.'||attribute_subname,
            attribute_name) attribute_name,
       attribute_value,
       coefficient
  FROM DM$VET_NMF_SAMPLE
WHERE feature_id < 3
ORDER BY 1,2,3,4)
WHERE ROWNUM < 21;

-----------------------------------------------------------------------
--                               APPLY THE MODEL
-----------------------------------------------------------------------
-- See dmnmdemo.sql for examples.
