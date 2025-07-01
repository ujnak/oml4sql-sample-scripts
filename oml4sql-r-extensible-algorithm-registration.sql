-----------------------------------------------------------------------
--   Oracle Machine Learning for SQL (OML4SQL) 23ai
-- 
--   OML R Extensible - Algorithm Registration - dmralgregdemo.sql
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
SET LONG 10000

column algorithm_name format a15;
column mining_function format a15;
column algorithm_type format a15;
column description format a11;
column algorithm_metadata format a20;

/*
connect sys/knl_test7 as sysdba;
GRANT rqadmin TO dmuser;
connect dmuser/dmuser
*/

-------------------------------------------------------------------------------
--                        R Algorithm Registration DEMO 1
-------------------------------------------------------------------------------
-- Explaination:
-- This demo shows how to register a new GLM algorithm and use it to create models.

-- Cleanup old output tables/scripts/models for repeat runs -------------------

BEGIN DBMS_DATA_MINING.DROP_MODEL('GLM_RDEMO_CLASSIFICATION');
EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN
  DBMS_DATA_MINING.drop_algorithm(
    ALGORITHM_NAME => 't1',
    CASCADE => TRUE);
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Algorithm Registration -----------------------------------------------------

BEGIN
  DBMS_DATA_MINING.register_algorithm(
    ALGORITHM_NAME         => 't1',
    algorithm_metadata     => 
    '{"function_language":"R",
      "mining_function" : { "mining_function_name" : "CLASSIFICATION",
                            "build_function" : {"function_body":
"function(dat, formula, keep.model) { set.seed(1234); mod <- glm(formula = formula(formula), data=dat, family=binomial(logit), model = as.logical(keep.model)); mod}"},
            
                            "score_function" : {"function_body":
"function(mod, dat) { res <- predict(mod, newdata = dat, type=''response''); res2=data.frame(1-res, res); names(res2) <- c(''0'', ''1''); res2}"}},
      "algo_setting" : [{"name" : "ralg_parameter_keep.model", "data_type" : "integer","value" : "0", "optional" : "TRUE", "min_value" : {"min_value": "0", "inclusive": "TRUE"}, "max_value" : {"max_value": "1", "inclusive": "TRUE"}}]
}',
    algorithm_description  => 't1');
END;
/

-------------------------------------------------------------------------------
--                              MODEL BUILD
-------------------------------------------------------------------------------
-- Explanation:
-- Build the model using the R build function script user has already registered. 
DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
BEGIN
  -- Model Settings -----------------------------------------------------------
  v_setlst('ALGO_EXTENSIBLE_LANG') := 'R';
  v_setlst('ALGO_NAME') := 't1';
  v_setlst('R_FORMULA') := 'AGE + EDUCATION + HOUSEHOLD_SIZE + OCCUPATION';
  v_setlst('ralg_parameter_keep.model') := '1';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'GLM_RDEMO_CLASSIFICATION',
    mining_function     => 'CLASSIFICATION',
    data_query          => 'select * from mining_data_build_v',
    case_id_column_name => 'CUST_ID',
    target_column_name  => 'AFFINITY_CARD',
    set_list            => v_setlst);
END;
/

-------------------------------------------------------------------------------
--                              MODEL SCORE
-------------------------------------------------------------------------------
-- Explanation:
-- Score the model using the R score function script user has already registered. 

SELECT CUST_ID, AFFINITY_CARD as AFFINITY_CARD_act, 
PREDICTION(GLM_RDEMO_CLASSIFICATION USING *) AFFINITY_CARD_pred,
round(PREDICTION_PROBABILITY(GLM_RDEMO_CLASSIFICATION USING *), 3) 
as AFFINITY_CARD_prob 
FROM mining_data_apply_v where CUST_ID <= 100010 
order by CUST_ID;


------------------------ Drop Models and Algorithms ---------------------------

BEGIN
  DBMS_DATA_MINING.drop_algorithm(
    ALGORITHM_NAME => 't1',
    CASCADE => TRUE);
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-------------------------------------------------------------------------------
--                        R Algorithm Registration DEMO 2
-------------------------------------------------------------------------------
-- Explaination:
-- This demo shows how to register a new DT algorithm and use it to create models.

-- Cleanup old output tables/scripts/models for repeat runs -------------------

BEGIN DBMS_DATA_MINING.DROP_MODEL('DT_RDEMO_CLASSIFICATION');
EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN
  DBMS_DATA_MINING.drop_algorithm(
    ALGORITHM_NAME => 't1');
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Algorithm Registration -----------------------------------------------------

BEGIN
  DBMS_DATA_MINING.register_algorithm(
    ALGORITHM_NAME         => 't1',
    algorithm_metadata     => 
    '{"function_language":"R",
      "mining_function" : { "mining_function_name" : "CLASSIFICATION",
                            "build_function" : {"function_body":
"function(dat, form) {require(rpart); set.seed(1234); mod <- rpart(formula = formula(form), method=''class'', data=dat); mod}"},
                            "weight_function" : {"function_body": 
"function(mod, dat, clas) {require(rpart); v0 <- as.data.frame(predict(mod, newdata=dat, type = ''prob''));res <- data.frame(lapply(seq_along(dat),function(x, dat) {if(is.numeric(dat[[x]])) dat[,x] <- as.numeric(NA) else dat[,x] <- as.factor(NA); vv <- as.data.frame(predict(mod, newdata = dat, type = ''prob'')); v0[[clas]] / vv[[clas]]}, dat = dat)); names(res) <- names(dat); res}"},
                            "detail_function" : [{"function_body":
"function(object, x) {mod.frm <- object$frame; data.frame(node = row.names(mod.frm), split = mod.frm$var, n = mod.frm$n,ln = mod.frm$yval2[,2], rn = mod.frm$yval2[,3])}",
                                                 "view_columns": [{"NAME": "node", "TYPE": "VARCHAR2(100)"}, {"NAME": "split", "TYPE": "VARCHAR2(2000)"}, {"NAME": "NodeCnt", "TYPE": "number"}, {"NAME": "LeftNodeCnt", "TYPE": "number"},{"NAME": "RightNodeCnt", "TYPE": "number"}]},
                                                 {"function_body":
"function(object, x) {mod.frm <- object$frame; data.frame(node = row.names(mod.frm), split = mod.frm$var, n = mod.frm$n,ln = mod.frm$yval2[,2], rn = mod.frm$yval2[,3])}",
                                                 "view_columns": [{"NAME": "node", "TYPE": "VARCHAR2(100)"}, {"NAME": "split", "TYPE": "VARCHAR2(2000)"}, {"NAME": "NodeCnt", "TYPE": "number"}, {"NAME": "LeftNodeCnt", "TYPE": "number"},{"NAME": "RightNodeCnt", "TYPE": "number"}]}],
                            "score_function" : {"function_body":
"function(mod, dat) {require(rpart);res <- data.frame(predict(mod, newdata=dat, type = ''prob'')); names(res) <- c(''0'', ''1''); res}"}}}',
    algorithm_description  => 't1');
END;
/

-------------------------------------------------------------------------------
--                              MODEL BUILD
-------------------------------------------------------------------------------
-- Explanation:
-- Build the model using the R build script user has already registered. 

DECLARE
  v_setlst DBMS_DATA_MINING.SETTING_LIST;
BEGIN
  -- Model Settings -----------------------------------------------------------
  v_setlst('ALGO_EXTENSIBLE_LANG') := 'R';
  v_setlst('ALGO_NAME') := 't1';
  v_setlst('R_FORMULA') := 'AGE + EDUCATION + HOUSEHOLD_SIZE + OCCUPATION';

  DBMS_DATA_MINING.CREATE_MODEL2(
    model_name          => 'DT_RDEMO_CLASSIFICATION',
    mining_function     => 'CLASSIFICATION',
    data_query          => 'select * from mining_data_build_v',
    case_id_column_name => 'CUST_ID',
    target_column_name  => 'AFFINITY_CARD',
    set_list            => v_setlst);
END;
/

-------------------------------------------------------------------------------
--                              MODEL DETAIL
-------------------------------------------------------------------------------
-- Explanation:
-- Display the model details using R detail function user has already registered

column SPLIT format a12;
select to_number(node) as node, split, nodecnt, leftnodecnt, rightnodecnt 
from DM$V0DT_RDEMO_CLASSIFICATION
order by node, split;

column SPLIT format a12;
select to_number(node) as node, split, nodecnt, leftnodecnt, rightnodecnt 
from DM$V1DT_RDEMO_CLASSIFICATION
order by node, split;

-------------------------------------------------------------------------------
--                              MODEL SCORE
-------------------------------------------------------------------------------
-- Explanation:
-- Score the model using the R score and weight function scripts user registered. 

column pred_det format a65;
SELECT CUST_ID, PREDICTION_DETAILS(DT_RDEMO_CLASSIFICATION, '1' USING *) pred_det
FROM mining_data_apply_v where EDUCATION = 'Bach.' and HOUSEHOLD_SIZE = '3'
and CUST_ID <= 100080 order by CUST_ID;

------------------------ Drop Models and Algorithms ---------------------------

BEGIN
  DBMS_DATA_MINING.drop_algorithm(
    ALGORITHM_NAME => 't1',
    CASCADE => TRUE);
EXCEPTION WHEN OTHERS THEN NULL; END;
/
