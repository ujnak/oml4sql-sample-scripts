-----------------------------------------------------------------------
--   Oracle Machine Learning for SQL (OML4SQL) 23ai
-- 
--   Regression - Neural Networks Algorithm - dmnnrdem.sql
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
-- Given demographic, purchase, and affinity card membership data for a 
-- set of customers, predict customer's age. Since age is a continuous 
-- variable, this is a regression problem.

-----------------------------------------------------------------------
--                            SET UP AND ANALYZE DATA
-----------------------------------------------------------------------

-- The data for this sample is composed from base tables in the SH Schema
-- (See Sample Schema Documentation) and presented through these views:
-- mining_data_build_v (build data)
-- mining_data_test_v  (test data)
-- mining_data_apply_v (apply data)
-- (See dmsh.sql for view definitions).
--
-----------
-- ANALYSIS
-----------
-- For regression using NN, perform the following on mining data.
--
-- 1. Use Auto Data Preparation
--

-----------------------------------------------------------------------
--                            BUILD THE MODEL
-----------------------------------------------------------------------

-- Cleanup old model with same name (if any)
BEGIN DBMS_DATA_MINING.DROP_MODEL('NNR_SH_Regr_sample');
EXCEPTION WHEN OTHERS THEN NULL; END;
/

---------------------
-- CREATE A NEW MODEL
--
DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
BEGIN
  -- specify settings
  v_setlst('ALGO_NAME')        := 'ALGO_NEURAL_NETWORK';
  v_setlst('PREP_AUTO')        := 'ON';
  v_setlst('ODMS_RANDOM_SEED') := '12';

  -- Examples of other possible settings are:
  --v_setlst('NNET_HIDDEN_LAYERS')       := '2';
  --v_setlst('NNET_NODES_PER_LAYER')     := '10, 30';
  --v_setlst('NNET_ITERATIONS')          := '100';
  --v_setlst('NNET_TOLERANCE')           := '0.0001';
  --v_setlst('NNET_ACTIVATIONS')         := 'NNET_ACTIVATIONS_LOG_SIG';
  --v_setlst('NNET_REGULARIZER')         := 'NNET_REGULARIZER_HELDASIDE';
  --v_setlst('NNET_HELDASIDE_RATIO')     := '0.3';
  --v_setlst('NNET_HELDASIDE_MAX_FAIL')  := '5';
  --v_setlst('NNET_REGULARIZER')         := 'NNET_REGULARIZER_L2';
  --v_setlst('NNET_REG_LAMBDA')          := '0.5';
  --v_setlst('NNET_WEIGHT_UPPER_BOUND')  := '0.7';
  --v_setlst('NNET_WEIGHT_LOWER_BOUND')  := '-0.6';
  --v_setlst('LBFGS_HISTORY_DEPTH')      := '20';
  --v_setlst('LBFGS_SCALE_HESSIAN')      := 'LBFGS_SCALE_HESSIAN_DISABLE';
  --v_setlst('LBFGS_GRADIENT_TOLERANCE') := '0.0001';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'NNR_SH_Regr_sample',
    mining_function     => 'REGRESSION',
    data_query          => 'SELECT * FROM mining_data_build_v',
    set_list            => v_setlst,
    case_id_column_name => 'cust_id',
    target_column_name  => 'age');
END;
/

-------------------------
-- DISPLAY MODEL SETTINGS
--
column setting_name format a30
column setting_value format a30
SELECT setting_name, setting_value
  FROM user_mining_model_settings
 WHERE model_name = 'NNR_SH_REGR_SAMPLE'
ORDER BY setting_name;

--------------------------
-- DISPLAY MODEL SIGNATURE
--
col attribute_name format a30
column attribute_type format a20
SELECT attribute_name, attribute_type
  FROM user_mining_model_attributes
 WHERE model_name = 'NNR_SH_REGR_SAMPLE'
ORDER BY attribute_name;

------------------------
-- DISPLAY MODEL DETAILS
--
-- Get a list of model views
col view_name format a30
col view_type format a50
SELECT view_name, view_type FROM user_mining_model_views
WHERE model_name='NNR_SH_REGR_SAMPLE'
ORDER BY view_name;

-----------------------------------------------------------------------
--                               TEST THE MODEL
-----------------------------------------------------------------------

------------------------------------
-- COMPUTE METRICS TO TEST THE MODEL
--

-- 1. Root Mean Square Error - Sqrt(Mean((y - y')^2))
--
column rmse format 9999.99
SELECT SQRT(AVG((prediction - age) * (prediction - age))) rmse
  FROM (select age, PREDICTION(nnr_sh_regr_sample USING *) prediction
        from mining_data_test_v);

-- 2. Mean Absolute Error - Mean(|(y - y')|)
--
column mae format 9999.99
SELECT AVG(ABS(prediction - age)) mae
  FROM (select age, PREDICTION(nnr_sh_regr_sample USING *) prediction
        from mining_data_test_v);

-- 3. Residuals
--    If the residuals show substantial variance between
--    the predicted value and the actual, you can consider
--    changing the algorithm parameters.
--
column prediction format 99.9999
SELECT prediction, (prediction - age) residual
  FROM (select age, PREDICTION(nnr_sh_regr_sample USING *) prediction
        from mining_data_test_v)
 WHERE prediction < 17.5
 ORDER BY prediction;

-----------------------------------------------------------------------
--                               APPLY THE MODEL
-----------------------------------------------------------------------
-------------------------------------------------
-- SCORE NEW DATA USING SQL DATA MINING FUNCTIONS
--
------------------
-- BUSINESS CASE 1
-- Predict the average age of customers, broken out by gender.
--
column cust_gender format a12
SELECT A.cust_gender,
       COUNT(*) AS cnt,
       ROUND(
       AVG(PREDICTION(nnr_sh_regr_sample USING A.*)),4)
       AS avg_age
  FROM mining_data_apply_v A
GROUP BY cust_gender
ORDER BY cust_gender;

------------------
-- BUSINESS CASE 2
-- Create a 10 bucket histogram of customers from Italy based on their age
-- and return each customer's age group.
--
column pred_age format 999.99
SELECT cust_id,
       PREDICTION(nnr_sh_regr_sample USING *) pred_age,
       WIDTH_BUCKET(
        PREDICTION(nnr_sh_regr_sample USING *), 10, 100, 10) "Age Group"
  FROM mining_data_apply_v
 WHERE country_name = 'Italy'
ORDER BY pred_age;

------------------
-- BUSINESS CASE 3
-- Find the reasons (8 attributes with the most impact) for the
-- predicted age of customer 100001.
--
set long 2000
set line 200
set pagesize 100
SELECT PREDICTION_DETAILS(nnr_sh_regr_sample, null, 8 USING *) prediction_details
  FROM mining_data_apply_v
 WHERE cust_id = 100001;

