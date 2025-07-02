-----------------------------------------------------------------------
--   Oracle Machine Learning for SQL (OML4SQL) 23ai
-- 
--   OML R Extensible - Attribute Importance via RF Algorithm - dmraidemo.sql
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

-------------------------------------------------------------------------------
--                         ATTRIBUTE IMPORTANCE DEMO
-------------------------------------------------------------------------------
-- Explaination:
-- This demo shows how to implement the attribute importance algorithm in 
-- Oracle Data Mining using R randomForest algorithm

BEGIN
  sys.rqScriptDrop('AI_RDEMO_BUILD_FUNCTION', v_silent => TRUE);
  sys.rqScriptDrop('AI_RDEMO_DETAILS_FUNCTION', v_silent => TRUE);
END;
/

BEGIN DBMS_DATA_MINING.DROP_MODEL('AI_RDEMO');
EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN
-- Build R Function -----------------------------------------------------------
-- Explanation:
-- User can define their own R script function to build the model they want. 
-- For example, here a script named AI_RDEMO_BUILD_FUNCTION is defined. This 
-- function builds and returns a random forest model using R randomForest 
-- algorithm. User can also choose other R algorithm to get the attribute 
-- importance.

  sys.rqScriptCreate('AI_RDEMO_BUILD_FUNCTION', 'function(dat) {
    require(randomForest); 
    set.seed(1234);
    mod <- randomForest(AFFINITY_CARD ~ ., data=dat, na.action=na.omit);
    mod}');

-- Detail R Function ----------------------------------------------------------
-- Explanation:
-- User can define their own R script function to show the model details they
-- want to display. For example, here a script named AI_RDEMO_DETAILS_FUNCTION 
-- is defined. This function creates and returns an R data.frame containing the 
-- attribute importance of the built model. User can also display other details.

  sys.rqScriptCreate('AI_RDEMO_DETAILS_FUNCTION', 'function(object, x)
   {require(randomForest); 
   mod <- object;
   data.frame(row_name=row.names(mod$importance), importance=mod$importance)}');
END;
/

-------------------------------------------------------------------------------
--                              MODEL BUILD
-------------------------------------------------------------------------------
-- Explanation:
-- Build the model using the R script user defined. Here R script 
-- AI_RDEMO_BUILD_FUNCTION will be used to create the model AI_RDEMO, using 
-- dataset mining_data_build_v.

DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
  v_data_query VARCHAR2(32767);
BEGIN
  -- Model Settings ---------------------------------------------------
  v_setlst('ALGO_EXTENSIBLE_LANG')  := 'R';
  v_setlst('RALG_BUILD_FUNCTION')   := 'AI_RDEMO_BUILD_FUNCTION';
  v_setlst('RALG_DETAILS_FUNCTION') := 'AI_RDEMO_DETAILS_FUNCTION';

  -- Once this setting is specified, a model view will be created. This model
  -- view will be generated to display the model details, which contains the
  -- attribute names and the corresponding importance.

  v_setlst('RALG_DETAILS_FORMAT') :=
    q'|select cast('a' as varchar2(100)) name, 1 importance from dual|';

  v_data_query := q'|SELECT * FROM mining_data_build_v|';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'AI_RDEMO',
    mining_function     => 'REGRESSION',
    data_query          => v_data_query,
    set_list            => v_setlst,
    case_id_column_name => 'CUST_ID',
    target_column_name  => 'AFFINITY_CARD'
  );
END;
/

-------------------------------------------------------------------------------
--                           ATTRIBUTE IMPORTANCE
-------------------------------------------------------------------------------

-- Attribute Importance
-- Explanation:
-- Display the model details using the R script user defined. Here R script 
-- AI_RDEMO_DETAIL_FUNCTION will be used to provide the attribute importance.

column name format a30;
select name, round(importance, 3) as importance, 
rank() OVER (ORDER BY importance DESC) rank 
from DM$VDAI_RDEMO order by importance desc, name;
