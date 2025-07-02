-----------------------------------------------------------------------
--   Oracle Machine Learning for SQL (OML4SQL) 23ai
-- 
--   Feature Extraction - Non-Negative Matrix Factorization Algorithm - dmnmdemo.sql
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
SET linesize 100
SET echo ON

-----------------------------------------------------------------------
--                            SAMPLE PROBLEM
-----------------------------------------------------------------------
-- Given demographic data about a set of customers, extract features
-- from the given dataset.
--

-----------------------------------------------------------------------
--                            BUILD THE MODEL
-----------------------------------------------------------------------
-- Cleanup old model with same name for repeat runs
BEGIN DBMS_DATA_MINING.DROP_MODEL('NMF_SH_sample');
EXCEPTION WHEN OTHERS THEN NULL; END;
/

---------------------
-- CREATE A NEW MODEL
--
-- Build NMF model
DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
  v_data_query VARCHAR2(32767);
BEGIN
  -- Model Settings ---------------------------------------------------
  --
  -- NMF is the default Feature Extraction algorithm. For this sample,
  -- we use Data Auto Preparation.
  --
  v_setlst('PREP_AUTO') := 'ON';

  -- Other examples of possible overrides are:
  -- v_setlst('FEAT_NUM_FEATURES')   := '10';
  -- v_setlst('NMFS_CONV_TOLERANCE') := '0.05';
  -- v_setlst('NMFS_NUM_ITERATIONS') := '50';
  -- v_setlst('NMFS_RANDOM_SEED')    := '-1';

  v_data_query := q'|SELECT * FROM mining_data_build_v|';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'NMF_SH_sample',
    mining_function     => 'FEATURE_EXTRACTION',
    data_query          => v_data_query,
    set_list            => v_setlst,
    case_id_column_name => 'CUST_ID'
  );
END;
/

-------------------------
-- DISPLAY MODEL SETTINGS
--
column setting_name format a30
column setting_value format a30
SELECT setting_name, setting_value
  FROM user_mining_model_settings
 WHERE model_name = 'NMF_SH_SAMPLE'
ORDER BY setting_name;

--------------------------
-- DISPLAY MODEL SIGNATURE
--
column attribute_name format a40
column attribute_type format a20
SELECT attribute_name, attribute_type
  FROM user_mining_model_attributes
 WHERE model_name = 'NMF_SH_SAMPLE'
ORDER BY attribute_name;

------------------------
-- DISPLAY MODEL DETAILS
--

-- Get a list of model views
col view_name format a30
col view_type format a50
SELECT view_name, view_type FROM user_mining_model_views
  WHERE model_name='NMF_SH_SAMPLE'
  ORDER BY view_name;

-- Each feature is a linear combination of the original attribute set; 
-- the coefficients of these linear combinations are non-negative.
-- The model details return for each feature the coefficients
-- associated with each one of the original attributes. Categorical 
-- attributes are described by (attribute_name, attribute_value) pairs.
-- That is, for a given feature, each distinct value of a categorical 
-- attribute has its own coefficient.
--
column attribute_name format a20;
column attribute_value format a60;
column coefficient format 9.99999
SELECT feature_id,
       attribute_name,
       attribute_value,
       coefficient
  FROM DM$VENMF_SH_Sample
WHERE feature_id = 1
  AND attribute_name in ('AFFINITY_CARD','AGE','COUNTRY_NAME')
ORDER BY feature_id,attribute_name,attribute_value;

-----------------------------------------------------------------------
--                               TEST THE MODEL
-----------------------------------------------------------------------
-- There is no specific set of testing parameters for feature extraction.
-- Examination and analysis of features is the main method to prove
-- the efficacy of an NMF model.
--

-----------------------------------------------------------------------
--                               APPLY THE MODEL
-----------------------------------------------------------------------
--
-- For a descriptive mining function like feature extraction, "Scoring"
-- involves providing the probability values for each feature.
-- During model apply, an NMF model maps the original data into the 
-- new set of attributes (features) discovered by the model.
-- 

-------------------------------------------------
-- SCORE NEW DATA USING SQL DATA MINING FUNCTIONS
--
------------------
-- BUSINESS CASE 1
-- List the features that correspond to customers in this dataset.
-- The feature that is returned for each row is the one with the
-- largest value based on the inputs for that row.
-- Count the number of rows that have the same "largest" feature value.
--
SELECT FEATURE_ID(nmf_sh_sample USING *) AS feat, COUNT(*) AS cnt
  FROM mining_data_apply_v
group by FEATURE_ID(NMF_SH_SAMPLE using *)
ORDER BY cnt DESC,FEAT DESC;

------------------
-- BUSINESS CASE 2
-- List top (largest) 3 features that represent a customer (100002).
-- Explain the attributes which most impact those features.
--
set line 120
column fid format 999
column val format 999.999
set long 20000
SELECT S.feature_id fid, value val,
       FEATURE_DETAILS(nmf_sh_sample, S.feature_id, 5 using T.*) det
FROM 
  (SELECT v.*, FEATURE_SET(nmf_sh_sample, 3 USING *) fset
    FROM mining_data_apply_v v
   WHERE cust_id = 100002) T, 
  TABLE(T.fset) S
order by 2 desc;
