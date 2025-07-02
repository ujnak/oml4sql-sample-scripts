-----------------------------------------------------------------------
--   Oracle Machine Learning for SQL (OML4SQL) 23ai
--
--   Time Series Regression - Using Exponential Smoothing with 
--      Generalized Linear Model and Extreme Gradient Boosting
--
--   Copyright (c) 2024 Oracle Corporation and/or its affilitiates.
--
--   The Universal Permissive License (UPL), Version 1.0
--
--   https://oss.oracle.com/licenses/upl
-----------------------------------------------------------------------

SET ECHO ON 
SET FEEDBACK 1
SET NUMWIDTH 10
SET LINESIZE 80
SET TRIMSPOOL ON
SET TAB OFF
SET PAGESIZE 100

SET echo off;  

col setting_name format a30
col setting_value format a45
col setting_type format a15  
col data_type format a15
column model_name format a20
col numeric_value format 9990.9999    
col string_value format a10  
  
column mining_function format a15
column attribute_name format a15
column attribute_type format a15 
  
col target format 990.99999
col x1 format 990.99999
col x2 format 990.99999

-----------------------------------------------------------------------
--                            SAMPLE PROBLEM
-----------------------------------------------------------------------
-- Perform Time Series Regression using a combination of ESM and GLM algorithms.
-- See documentation on "Multiple Time Seriess Models" at 
-- https://docs.oracle.com/en/database/oracle/machine-learning/oml4sql/23/dmcon/exponential-smoothing.html
-----------------------------------------------------------------------
--                            EXAMPLE IN THIS SCRIPT
-----------------------------------------------------------------------
-- Create the time series dataset
-- Build an ESM model using multiple time series forecasting
-- Build a GLM model using the ESM result
-- Explore the model views
-- Compare the regression forecast to the baseline (ESM) forecast
-- Build an XGBOOST model and compare to ESM forecast
-----------------------------------------------------------------------
-- Create Time Series Dataset-- Invoke this script 
--

@oml4sql-time-series-regression-dataset.sql
/
-----------------------------------------------------------------------
--                            BUILD THE MODEL
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- Multiple time series model (MSDEMO_MODEL) is built using an interval 
-- of days, which corresponds to the dataset interval. By specifying
-- a series list (parameter EXSM_SERIES_LIST), we can include additional 
-- "target" columns, i.e., columns for which ESM should create backcasts.
--

-------------------------
-- BUILD ESM MODEL
--

SET echo OFF;
BEGIN DBMS_DATA_MINING.DROP_MODEL('MSDEMO_MODEL'); 
EXCEPTION WHEN OTHERS THEN NULL; END;
/
SET echo ON;
DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
  v_data_query VARCHAR2(32767);
BEGIN
  -- Model Settings ---------------------------------------------------
  v_setlst('ALGO_NAME')            := 'ALGO_EXPONENTIAL_SMOOTHING';
  v_setlst('EXSM_INTERVAL')        := 'EXSM_INTERVAL_DAY';
  v_setlst('EXSM_MODEL')           := 'EXSM_ADDWINTERS_DAMPED';
  v_setlst('EXSM_SEASONALITY')     := '7';
  v_setlst('EXSM_PREDICTION_STEP') := '1';
  v_setlst('EXSM_SERIES_LIST')     := 'SMI,CAC,FTSE';

  v_data_query := q'|SELECT * FROM EUSTOCK|';
	 
  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'MSDEMO_MODEL',
    mining_function     => 'TIME_SERIES',
    data_query          => v_data_query,
    set_list            => v_setlst,
    case_id_column_name => 'DATES',
    target_column_name  => 'DAX'
  );
END;
/

-------------------------
-- Model Results:
-- DM$VRNSDEMO compares the actuals to the prediction
--

SELECT * FROM DM$VRMSDEMO_MODEL 
FETCH FIRST 10 ROWS ONLY;
/

-------------------------
-- Create Trianing, Actual, and Test Datasets:
-- DM models show the forcast for the target column
--

BEGIN EXECUTE IMMEDIATE 'DROP TABLE tmesm_ms_train';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE TABLE tmesm_ms_train as
SELECT CASE_ID, DAX, DM$DAX, DM$SMI, DM$CAC, DM$FTSE, 
       CASE WHEN case_id < to_date('1998-02-03','YYYY-MM-DD') 
       THEN 0 ELSE 1 END AS prod 
FROM DM$VRMSDEMO_Model order by 1;
 
-------------------------
-- By inserting the actual values into the prediction dataset, 
-- a comparison of the accuracy for the ESM and regression
-- models can be possible.
--

BEGIN EXECUTE IMMEDIATE 'DROP TABLE tmesm_ms_actual';
EXCEPTION WHEN OTHERS THEN NULL; END; 
/
CREATE TABLE tmesm_ms_actual (case_id DATE, DAX binary_double);
INSERT INTO tmesm_ms_actual VALUES(DATE '1998-02-04', 4633.008);
commit;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE tmesm_ms_test';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
CREATE TABLE tmesm_ms_test as 
SELECT a.case_id, b.DAX, DM$DAX, DM$SMI, DM$CAC, DM$FTSE, 1 prod 
FROM   DM$VTMSDEMO_model a, tmesm_ms_actual b
WHERE  a.case_id=b.case_id;
 
-------------------------
-- Column 'prod' is a binary variable indicating a change in the environment,
-- e.g., the introduction of a new product.
-- It is an example of an auxillary, or flag, variable that is used by the regression
-- to improve accuracy. It may represent the presence of a holiday, or encodw
-- an alternate seasonality (multi-seasonal model)
--

-------------------------
-- BUILD GLM MODEL
--

SET echo OFF;
BEGIN DBMS_DATA_MINING.DROP_MODEL('MS_GLM_MODEL');
EXCEPTION WHEN OTHERS THEN NULL; END;
/
SET echo ON;
DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
  v_data_query VARCHAR2(32767);
BEGIN
  -- Model Settings ---------------------------------------------------
  v_setlst('ALGO_NAME')          := 'ALGO_GENERALIZED_LINEAR_MODEL';

  v_data_query := q'|SELECT * FROM tmesm_ms_train|';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'MS_GLM_MODEL',
    mining_function     => 'REGRESSION',
    data_query          => v_data_query,
    set_list            => v_setlst,
    case_id_column_name => 'CASE_ID',
    target_column_name  => 'DAX'
  );
END;
/

-----------------------------------------------------------------------
--                            ANALYZE THE MODEL
-----------------------------------------------------------------------

-------------------------
-- DISPLAY MODEL VIEWS
--

SELECT VIEW_NAME, VIEW_TYPE 
FROM   USER_MINING_MODEL_VIEWS
WHERE  MODEL_NAME='MSDEMO_MODEL'
ORDER BY VIEW_NAME;
/
-------------------------
-- DISPLAY BACKCASTS
--

SELECT * 
FROM   DM$VRMSDEMO_MODEL
ORDER BY CASE_ID
FETCH FIRST 10 ROWS ONLY;
/
-------------------------
-- DISPLAY FORECASTS
--

SELECT * 
FROM DM$VTMSDEMO_MODEL
ORDER BY CASE_ID 
FETCH FIRST 10 ROWS ONLY;
/
-------------------------
-- COMPARE REGRESSION FORECAST (GLM) TO BASELINE (EXPONENTIAL SMOOTHING) FORECAST
--

SELECT CASE_ID, DAX, regression_forecast, baseline_forecast,
       DAX - regression_forecast AS regression_error,
       DAX - baseline_forecast AS baseline_error 
FROM (SELECT CASE_ID, DAX, 
             PREDICTION(MS_GLM_model using *) regression_forecast, 
             DM$DAX baseline_forecast
      FROM   tmesm_ms_test 
      ORDER BY CASE_ID);
/
-------------------------
-- BUILD XGBOOST MODEL
--

SET echo OFF;
BEGIN DBMS_DATA_MINING.DROP_MODEL('MS_XGB_MODEL');
EXCEPTION WHEN OTHERS THEN NULL; END;
/
SET echo ON;
DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
  v_data_query VARCHAR2(32767);
BEGIN
  -- Model Settings ---------------------------------------------------
  v_setlst('ALGO_NAME')          := 'ALGO_XGBOOST';

  v_data_query := q'|SELECT * FROM tmesm_ms_train|';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'MS_XGB_MODEL',
    mining_function     => 'REGRESSION', 
    data_query          => v_data_query,
    set_list            => v_setlst,
    case_id_column_name => 'CASE_ID',
    target_column_name  => 'DAX'
  );
END;
/
	  
-------------------------
-- COMPARE REGRESSION FORECAST (XGB) TO BASELINE (EXPONENTIAL SMOOTHING) FORECAST
--

SELECT CASE_ID, DAX, regression_forecast, baseline_forecast,
       DAX - regression_forecast AS regression_error,
       DAX - baseline_forecast AS baseline_error 
FROM (SELECT CASE_ID, DAX, 
             PREDICTION(MS_XGB_model using *) regression_forecast, 
             DM$DAX baseline_forecast
      FROM   tmesm_ms_test 
      ORDER BY CASE_ID);
/
-----------------------------------------------------------------------
--   End of script
-------------------------------------------------------------------------
