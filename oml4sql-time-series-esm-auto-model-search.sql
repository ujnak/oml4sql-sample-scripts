-----------------------------------------------------------------------
--   Oracle Machine Learning for SQL (OML4SQL) 23ai
--
--   Automated Model Search- Time Series Algorithm ESM
--
--   Copyright (c) 2024 Oracle Corporation and/or its affilitiates.
--
--   The Universal Permissive License (UPL), Version 1.0
--
--   https://oss.oracle.com/licenses/upl
-----------------------------------------------------------------------


-----------------------------------------------------------------------
--                            SAMPLE PROBLEM
-----------------------------------------------------------------------
-- Create an ESM Time Series Model with Automated Model Search, which is
--   also the default behavior when no ESM model type is specified

-----------------------------------------------------------------------
--                            EXAMPLE IN THIS SCRIPT
-----------------------------------------------------------------------
-- Create an ESM model with CREATE_MODEL2 and Model Search Enabled
-- Evaluate the model 

-----------------------------------------------------------------------
--                            BUILD THE MODEL
-----------------------------------------------------------------------

-------------------------
-- CREATE VIEW
--

CREATE OR REPLACE VIEW ESM_SH_DATA AS 
SELECT TIME_ID, AMOUNT_SOLD 
FROM   SH.SALES;


-------------------------
-- CREATE MODEL
--

BEGIN DBMS_DATA_MINING.DROP_MODEL('ESM_SALES_FORECAST_1');
EXCEPTION WHEN OTHERS THEN NULL; END;
/
DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
  v_data_query VARCHAR2(32767);
BEGIN 
  -- Model Settings ---------------------------------------------------
  v_setlst('ALGO_NAME')            := 'ALGO_EXPONENTIAL_SMOOTHING';
  v_setlst('EXSM_INTERVAL')       := 'EXSM_INTERVAL_DAY';

  v_data_query := q'|SELECT * FROM ESM_SH_DATA|';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'ESM_SALES_FORECAST_1',
    mining_function     => 'TIME_SERIES',
    data_query          => v_data_query,
    set_list            => v_setlst,
    case_id_column_name => 'TIME_ID',
    target_column_name  => 'AMOUNT_SOLD'
  );
END;
/

-----------------------------------------------------------------------
--                            ANALYZE THE MODEL
-----------------------------------------------------------------------
-------------------------
-- GET MODEL DETAILS
--

SELECT setting_name, setting_value, setting_type
FROM   user_mining_model_settings
WHERE  (setting_type != 'DEFAULT' or setting_name like 'EXSM%') 
AND    model_name = upper('ESM_SALES_FORECAST_1')
ORDER BY setting_name;
/


-------------------------
-- COMPUTED SETTINGS AND OTHER GLOBAL STATISTICS
--

SELECT name, ROUND(numeric_value,3) numeric_value, string_value 
FROM DM$VGESM_SALES_FORECAST_1
ORDER BY name;
/

-----------------------------------------------------------------------
--   End of script
-----------------------------------------------------------------------
