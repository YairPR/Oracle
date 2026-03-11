Rem 
Rem dsg_exec_pkg.sql
Rem This package is not created on the repos.
Rem this package is loaded on to the target for subetting.
Rem
Rem Copyright (c) 2010, 2018, Oracle and/or its affiliates. 
Rem All rights reserved.
Rem
Rem    NAME
Rem      dsg_exec_pkg.sql - <one-line expansion of the name>
Rem
Rem    DESCRIPTION
Rem      <short description of component this file declares/defines>
Rem
Rem    NOTES
Rem      <other useful comments, qualifications, etc.>
Rem
Rem    MODIFIED   (MM/DD/YY)
Rem    haprpras    07/16/18 - Bug #28324110 - Sub-setting job fails with
Rem                           ORA-06502 character string buffer too small
Rem    haprpras    03/06/18 - Bug #26381191 - DATA SUBSETTING FAILS WITH
Rem                           ORA-00918 error
Rem    haprpras    04/12/17 - Bug #23575590 - ORA-01007 when subsetting based
Rem                           on partitions/subpartitions without ances & desc
Rem    haprpras    03/14/17 - Bug #21800919 - Subsetting fails with ORA-00972
Rem                           while appending dsg suffix to the table name
Rem    haprpras    12/05/16 - Bug #24788568 - Running datamask on a large data
Rem                           volume generates ORA-39095 after 99 dmp files
Rem    ddsingha    08/09/16 - Bug-20453099, 22746491: Raise exception to
Rem                           upper stack
Rem    ddsingha    06/16/16 - Project 60908: Provides support for long
Rem                           identifiers in DMS repository tables
Rem    jkati       06/13/16 - bug#21075111: Create individual row_id tables per
Rem                           node table instead of a single partitioned
Rem                           DB_DSG_ROW_IDS table
Rem    apkulshr    05/02/16 - Project 60844 : Full database import/export with
Rem                           masking and subsetting
Rem    pradeshm    04/04/16 - Changes for project 60815
Rem    aramappa    04/21/16 - Bug 23035784: Change data_remap to pass ROWID to
Rem                           remap function
Rem    ddsingha    04/20/16 - Project 65926: Global rule ER and Percentage rule
Rem                           for all tables ER
Rem    haprpras    03/17/16 - Bug #22915757 - subset job fails to create shadow
Rem                           tables
Rem    apkulshr    09/21/15 - bug#21840240 - Generate Subset(in-db) is failing 
Rem                           for 10.1 DB target 
Rem    jkati       09/15/15 - bug#21831276 : use distinct keyword while
Rem                           selecting from parent table too as parent table
Rem                           can have non-unique values in application
Rem                           schemas where relationships are application
Rem                           defined and not dictionary defined
Rem    jkati       08/17/15 - bug#18258129 : During subsetting disable only
Rem                           those constraints which are currently enabled
Rem    jkati       08/17/15 - bug#21491255 : In-Export masking should not
Rem                           create DB_DSG_ROW_ID table
Rem    jkati       08/03/15 - bug#21368683 : drop tables with purge option
Rem    jkati       08/03/15 - bug#21324599: create DBMS_DSM_DSG_IM_DM package
Rem                           for encrypt format during run time
Rem    pradeshm    07/22/15 - Fix bug 17410148 : Get custom directory path and
Rem                           create a directory
Rem    aramappa    07/17/15 - Bug 21213545: Check user option before dropping
Rem                           mapping tables
Rem    amikhare    07/10/15 - The tables are renamed for EBRification of EM
Rem                           Repository in 13.1. The original table name is
Rem                           taken by an Editioning view. All your business
Rem                           logic would access the table via Editioning view.
Rem    jkati       07/03/15 - bug#21354404: Due to EBS changes to repos tables,
Rem                           appropriate changes need to be done to make the
Rem                           graph tables to be _E tables
Rem    amikhare    06/19/15 - The tables are renamed for EBRification of EM
Rem                           Repository in 13.1. The original table name is
Rem                           taken by an Editioning view. All your business
Rem                           logic would access the table via Editioning view.
Rem    jkati       02/09/15 - bug#20099726 : update the DML for some rows for
Rem                           in-place delete
Rem    jkati       02/03/15 - bug#20178178 : directly update the columns for
Rem                           in-database subsetting with column rules instead
Rem                           of updating from package function
Rem    jkati       11/03/14 - er-16665272 : support subset based on partition
Rem    pradeshm    10/16/14 - Fix Bug 19632931 : add enable_parallel_dml hint
Rem                           in IAS
Rem    shmahaja    09/10/13 - Bug 17414742 - GEN SUBSET FAILS ON 10.2 DB WITH
Rem                           COMPONENT 'SET_TABLE_PREFS' MUST BE DECLARED
Rem                           this is being caused due to dbms_stats.set_table_prefs
Rem    shmahaja    09/04/13 - Bug 17400545 - SUBSET DOES NOT EXPORT SCHEMAS
Rem                           WITH NO TABLES
Rem    shmahaja    08/14/13 - Bug 17218228 - TABLES WITHOUT STATISTICS ARE
Rem                           IMPORTED WTIH ZERO ROWS OR NOT INCLUDED IN DUMP
Rem    pkaliren    08/12/13 - Renaming subset_import to tdm_import
Rem    shmahaja    07/05/13 - Bug 16813196 - PERFORMANCE ISSUE WITH ROWSCN IN SUBSET
Rem    shmahaja    07/04/13 - bug-16977685 perf improvement by updating stats
Rem    shmahaja    06/17/13 - adding support for enabling and disabling edges
Rem                           in subset processing
Rem    shmahaja    04/09/13 - Bug 16620267 - SUBSET SHOULD EXPORT 0 ROWS FROM
Rem                           TABLES EXCLUDED FROM ADM
Rem    shmahaja    04/02/13 - Bug 16586401 - SUBSET EXEC FAILED WITH ORU-10027:
Rem                           BUFFER OVERFLOW, LIMIT OF 1000000 BYTES
Rem    prakgupt    11/28/12 - Bug 15893126 - subset should prompt for
Rem                           dump file password in the command line
Rem    shmahaja    11/20/12 - bug 15893473 - ora-39001: invalid argument value
Rem                           error for truncate inline mask job
Rem    shmahaja    11/20/12 - bug 14829448 - dbms_datapump.data_remap does not
Rem                           exist in db version < 11
Rem    gkhakare    11/16/12 - Changes for solving Bug-13640749 (in place delete
Rem                           subset job threw ora-00955: name is already used
Rem                           by an existing )
Rem    shmahaja    09/21/12 - Bug 14478238 - inline mask truncate, preserve,
Rem                           timestamp masking support
Rem    prakgupt    05/31/12 - Add support for compression and encryption
Rem    shmahaja    05/16/12 - bug-12854253 case sensitive object names
Rem    prakgupt    04/30/12 - column rules support
Rem    shmahaja    02/29/12 - inline_mask
Rem    shmahaja    12/16/11 - changing remainder to mod
Rem    shmahaja    12/06/11 - cleanup after subset execution
Rem    shmahaja    11/16/11 - support for 12.1 db
Rem    shmahaja    10/17/11 - null index in dsg_comput_subset
Rem    shmahaja    09/01/11 - creating individual shadow tables
Rem    shmahaja    08/31/11 - making inplace replace faster by using ctas like
Rem                           method
Rem    shmahaja    05/25/11 - subset performance improvement
Rem    shmahaja    03/31/11 - % row implementation
Rem    shmahaja    03/15/11 - bug 11656271 compatibility with 10. DB
Rem    shmahaja    11/26/10 - fixing procedure is_graph_exists
Rem    shmahaja    05/10/10 - simple subset computation optimization
Rem    shmahaja    01/09/10 - added ctas method for inplace 
Rem    bkuchibh    03/16/10 - Created
Rem

SET ECHO OFF
SET FEEDBACK 1
SET NUMWIDTH 10
SET LINESIZE 80
SET TRIMSPOOL ON
SET TAB OFF
SET PAGESIZE 100
set serveroutput on

Rem
Rem Data Subset Modeler package declaration
Rem

CREATE OR REPLACE PACKAGE dbms_dsm_dsg
AUTHID CURRENT_USER
IS

-------------------------------------------------------------------------------
-- DSM names and ids
--
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- DSM common constants
--
-------------------------------------------------------------------------------

-- method options
DSG_EXEC_OPTION_EXPORT           constant number := 1;
DSG_EXEC_OPTION_INPLACE          constant number := 2;

-- export options
DSG_EXPORT_OPTION_SUBSET_ONLY    constant number := 1;
DSG_EXPORT_OPTION_FULL           constant number := 2;
DSG_EXPORT_OPTION_UNDEFINED      constant number := 3;

--table rule scope
DSG_RULE_SCOPE_RI_ONLY           constant number := 1;
DSG_RULE_SCOPE_RI_AND_CHILDREN   constant number := 2;
DSG_RULE_SCOPE_TABLE_ONLY        constant number := 3;

-- column rule options 
DSG_NULL_FORMAT                  constant integer := 1;
DSG_FIXED_STRING                 constant integer := 2;
DSG_FIXED_NUMBER                 constant integer := 3;

-- edge types
DSG_DB_DEFINED_REF  constant number := 0;
DSG_USER_DEFINED_REF  constant number := 1;

DSG_ENABLE_CONS     constant number := 1;
DSG_DISABLE_CONS     constant number := 2;
DSG_DISABLE_IND	    constant number := 2;
DSG_ENABLE_IND     constant number := 1;
DSG_ENABLE_TRG     constant number := 1;
DSG_DISABLE_TRG     constant number := 2;

-- DRV TBL relation
DRV_NODE_CHILD      constant number := 1;
DRV_NODE_PARENT     constant number := 2;

-- output levels
DSG_ERROR          constant number := 2;
DSG_INFO           constant number := 1;
DSG_DEBUG          constant number := 0;

--errors
DSG_INVALIED_KEY_COLUMN constant number := -20001;
DSG_EDGE_NAME_ALREADY_EXISTS constant number := -20002;
DSG_EDGE_C_CT_ALREADY_EXISTS constant number := -20003;
DSG_EDGE_P_CT_ALREADY_EXISTS constant number := -20004;
DSG_EDGE_WITH_IDENTICAL_KEYS constant number := -20005;
DSG_MISMATCHED_KEY_COLUMN    constant number := -20006;
DSG_EDGE_INVALID             constant number := -20007;
DSG_MISMATCHED_KEY_TYPE      constant number := -20008;
DSG_PARENT_KEY_NOT_UNIQUE    constant number := -20009;
DSG_IDENTICAL_SUBSET_OWNER   constant number := -20010;
DSG_NULL_TS_NAME             constant number := -20011;
DSG_RULE_ADDITION_INVALID    constant number := -20012;
DSG_TYPE_MATCH_LIMITATION    constant number := -20013;
DSG_INTERNAL_ERROR           constant number := -20014;
DSG_DFK_INVALIED_INPUTS      constant number := -20015;
DSG_APPL_SCHEMA_DOESNOT_EXISTS constant number := -20016;
DSG_INVALID_INPUTS             constant number := -20017;
DSG_EDGE_ALREADY_EXISTS        constant number := -20018;

-- exec errors
DSG_INVALID_EXEC_METHOD        constant number := -20019;
DSG_GRAPH_ALREADY_EXITS        constant number := -20010;
DSG_INVALID_EXPORT_TYPE        constant number := -20021;


-- types
TYPE keyinfo_t IS TABLE OF VARCHAR2(138); 

TYPE key_tl_t IS TABLE OF NUMBER;


--set the graph owner
procedure dsg_set_graph_owner (graph_owner varchar2 := null);

--set the execution method
procedure dsg_set_exec_method (exec_method in number);

--set the type of in-export subsetting
procedure dsg_set_export_type (export_type in number);

-- get
function dsg_get_exec_method return number;

-- set the rentrant mode
procedure dsg_set_reentrant_mode (reentrant_mode in boolean);

-- get
function dsg_get_reentrant_mode return boolean;


--set the export directory 
procedure dsg_set_export_dir (export_dir in varchar2);

--get
function dsg_get_export_dir return varchar2;

--set the export dumpfile name
procedure dsg_set_export_dumpfile (export_dumpfile in varchar2);

--get
function dsg_get_export_dumpfile return varchar2;

--set the export dumfile size
procedure dsg_set_dump_size (dump_size in varchar2);

--get
function dsg_get_dump_size return varchar2;


--set the subset graph dumpfile name
procedure dsg_set_graph_dumpfile (graph_dump in varchar2);

--get
function dsg_get_graph_dumpfile return varchar2; 

-- set the force cleaning option
procedure dsg_set_force_clean (force_clean in boolean);
--get
function dsg_get_force_clean  return boolean;

-- set the logging option
procedure dsg_set_logging_option(logging_off in boolean);

-- get
function dsg_get_logging_option return boolean;

-- set the global_rule option
procedure dsg_set_global_rule(global_rule in boolean);

-- get
function dsg_get_global_rule return boolean;

-- set option for dropping extra tables in subset 
procedure dsg_set_drop_tables_option(drop_tables in boolean);

-- set export log file name
procedure dsg_set_export_log(log_name in varchar2);

function dsg_get_export_log return varchar2;

procedure dsg_set_export_log_dir( log_dir in varchar2);

function dsg_get_export_log_dir return varchar2;

-- Fix Bug 17410148 : get/set custom directory path specified in parameter file
procedure dsg_set_custom_dir_path(path in varchar2 default null);

function dsg_get_custom_dir_path return varchar2;

-- get
function dsg_get_drop_tables_option return boolean;

-- drop the subset graph
procedure drop_subset_graph;

-- drop a table
procedure drop_table (table_name in varchar2);

--reset the graph
procedure dsg_reset_graph ( dsm_id        integer,
                            tgt_id        raw );
-- does graph exists
function graph_exists return boolean;

-- create execution tracking and tracing/debugging info tables
procedure create_exec_track_tables;

procedure create_ddl_table;

-- refresh graph stats
procedure dsg_refresh_graph_stats ( dsm_id        integer,
                                    tgt_id        raw );

-- adjust seq counters of the graph to account for imported entries
-- Note: i don't anticipate any new content addition to graph at the target
--       however, in the event we need it, following routine need to be invoked 
--       as part of graph loading and initialization.
procedure dsg_adjust_seq_counters;

-- TBD: re-eval existing rules


-- compute process node
procedure dsg_process_node ( dsm_id      integer,
                             tgt_id      raw,
                             as_name     varchar2,
                             table_name  varchar2 );
-- compute subset
procedure dsg_compute_subset;

-- put trace
procedure dsg_put_trace ( dsm_id        integer,
                          tgt_id        raw,
                          operation     varchar2,
                          sub_operation varchar2,
                          trace_out     clob,
                          output_level  integer );

procedure dsg_exec_export ( dsm_id	integer,
			    tgt_id	raw );

procedure dsg_execute_subset;

procedure dsg_drop_table_indexes (l_table_id    in number,
				  l_owner       in varchar2,
                                  l_table_name  in varchar2 );
                                    

procedure dsg_drop_indexes ( dsm_id in integer,
			     tgt_id in raw);

procedure dsg_enable_ict(dsm_id 	in integer, 
                         exec_state 	in integer);

procedure dsg_inplace_replace ( dsm_id          in integer,
                                tgt_id          in raw );

procedure dsg_manage_constraints ( dsm_id in integer,
				   op_code in number);

procedure dsg_store_ddl(table_id in number,
			object_type in varchar2, 
                        object_name in varchar2,
                        object_owner in varchar2,
                        table_name in varchar2,
                        otype in varchar2, 
                        validated in varchar2,
			object_ddl in clob);

procedure dsg_create_indexes;

procedure dsg_create_shadow_tables;

procedure dsg_remap_schemas;

procedure dsg_refresh_pk_names;

procedure dsg_get_table_stats ( schema_name      in varchar2,
                                table_name       in varchar2,
                                src_num_rows    out number,
                                avg_row_size    out number,
                                pkc_name        out varchar2,
                                is_iot          out varchar2,
                                is_row_movement out varchar2 );

function dsg_get_keys_byid ( key_id integer ) return keyinfo_t;

procedure dsg_generate_import_script;

procedure dsg_compute_percent_rules;

procedure dsg_set_dsm_id(dsm_id in integer);

function dsg_get_dsm_id return integer;

procedure dsg_set_tgt_id(tgt_id in raw);

function dsg_get_tgt_id return raw;

procedure dsg_set_create_import_script(create_import_script in boolean);

function dsg_get_create_import_script return boolean;

procedure dsg_set_max_threads(max_threads in number);

function dsg_get_max_threads return number;

procedure dsg_set_create_export_log(create_export_log in boolean);

function dsg_get_create_export_log return boolean;

procedure dsg_set_cleanup (do_cleanup in boolean);

function dsg_get_cleanup return boolean;

procedure dsg_set_do_inline_mask(do_inline_mask in boolean);

function dsg_get_do_inline_mask return boolean;

procedure dsg_set_apply_column_rules(apply_column_rules in boolean);

function dsg_get_apply_column_rules return boolean;

procedure dsg_set_enable_compression(enable_compression in boolean);

function dsg_get_enable_compression return boolean;

procedure dsg_set_enable_encryption(enable_encryption in boolean);

function dsg_get_enable_encryption return boolean;

procedure dsg_set_encrypt_password(encrypt_password in varchar2);

function dsg_get_filter_excluded_tbls return boolean;

procedure dsg_set_filter_excluded_tbls(filter_excluded_tbls in boolean);

function dsg_get_output_level return integer;

procedure dsg_set_output_level(output_level in integer);

procedure dsg_do_cleanup;

procedure dsg_create_im_dm_package(dsm_id        integer,
                                   tgt_id        raw, 
                                   seed          number);

END dbms_dsm_dsg;
/
show errors;

CREATE OR REPLACE PACKAGE BODY dbms_dsm_dsg
IS

-- private globals that have set/get methods
dsg_dsm_id	      integer := null;
dsg_tgt_id	      raw(16) := null;
dsg_exec_option       number := null;
dsg_export_type       number := null;
dsg_export_dir        varchar2(4000) := null;
dsg_export_dumpfile   varchar2(255) := null;
dsg_dump_size	      varchar2(10):= null;
dsg_graph_dump        varchar2(100) := null;
dsg_export_log        varchar2(40) := null;
dsg_export_log_dir    varchar2(100) := null;
dsg_custom_dir_path   varchar2(4000) := null;
dsg_create_export_log boolean := TRUE;
dsg_reentrant_mode    boolean := FALSE;
dsg_force_clean       boolean := FALSE;
dsg_output_to_stdout  boolean := TRUE;
dsg_logging_off	      boolean := TRUE;
dsg_global_rule       boolean := FALSE;
dsg_drop_tables       boolean := TRUE;
dsg_create_import_script boolean := TRUE;
dsg_max_threads	      number := 1;
dsg_cleanup	      boolean := TRUE;
dsg_do_inline_mask    boolean := FALSE;
dsg_apply_column_rules boolean := FALSE;
dsg_enable_compression boolean := FALSE;
dsg_enable_encryption boolean := FALSE;
dsg_encrypt_password varchar2(100) := null;
dsg_filter_excluded_tbls boolean := TRUE;
dsg_output_level      integer := DSG_INFO;
-- private variables
dsg_track_tbl_name      varchar2(30) := 'DB_DSG_EXEC_TRACK_E';
dsg_trace_tbl_name      varchar2(30) := 'DB_DSG_EXEC_TRACE_E';
dsg_ddl_tbl_name        varchar2(30) := 'DB_DSG_DDLS_E';
dsg_schema_map_tbl_name varchar2(30) := 'DB_DSG_SCHEMA_MAP_E';
dsg_dynamic_scripts_tbl_name varchar2(30) := 'DB_DSG_DYNAMIC_SCRIPTS_E';
dsg_app_tbl_name      varchar2(30) := 'DB_DSG_APPS_E';
dsg_node_tbl_name     varchar2(30) := 'DB_DSG_NODE_E';
dsg_edge_tbl_name     varchar2(30) := 'DB_DSG_EDGES_E';
dsg_kc_tbl_name       varchar2(30) := 'DB_DSG_KEY_COLS_E';
dsg_impt_tbl_name     varchar2(30) := 'DB_DSG_IMPTS_E';
dsg_row_id_tbl_name   varchar2(30) := 'DB_DSG_ROW_IDS_';
dsg_col_rule_tbl_name varchar2(30) := 'DB_DSG_COLUMN_RULES_E';
dsg_mask_map_tbl_name varchar2(30) := 'DB_DSG_MAP_TABLE';
dsg_se_tbl_name       varchar2(30) := 'DB_DSG_SPL_EDGES_E';
dsg_pchain_tbl_name   varchar2(30) := 'DB_DSG_PROCESSING_CHAIN_E';
dsg_tbl_id_seq_name   varchar2(30) := 'DB_DSG_TBLID_SEQ';
dsg_key_id_seq_name   varchar2(30) := 'DB_DSG_KEY_ID_SEQ';
dsg_edge_id_seq_name  varchar2(30) := 'DB_DSG_EDGEID_SEQ';
dsg_owner             varchar2(128) := null;
dsg_use_shadow_tbl_global boolean := TRUE;
type dsg_processed_table_array is table of varchar2(1) index by varchar2(257);
dsg_processed_tables dsg_processed_table_array;
type dsg_part_table_array is table of varchar2(128);
type dsg_table_array is table of varchar2(257) index by varchar2(257);
dsg_tables dsg_table_array;
--this variable will store the rule id of the rule being processed
--this is to support the exclusion of edges from subset processing
dsg_rule_id           number := 0;

procedure dsg_send_msg (msg in clob)
is
  msg1 varchar2(1020);
  len integer := length(msg);
  i integer := 1;
begin
  dbms_output.enable(null);
  loop
    msg1 := substr(msg, i, 255);
    dbms_output.put_line(msg1);
    len := len - 255;
    i := i + 255;
  exit when len <= 0;
  end loop;
end dsg_send_msg;

--    PROCEDURE DSG_ADD_TO_SQL_TBL
--    PURPOSE: inserts a clob into a variable of type dbms_sql.varcahr2a
--    PARAMETERS:
--         sql_tbl dbms_sql.varchar2a - variable of type varchar2a
--         v_sql clob - the clob to be inserted
--    RETURNS:
--         NONE
procedure dsg_add_to_sql_tbl(sql_tbl out dbms_sql.varchar2a,
                             v_sql   in clob)
is
  MAX_SIZE constant integer := 32767;
  lob_size          integer;
  offset            integer := 1;
  tbl_index         integer := 1;
  amount            integer := MAX_SIZE;
begin
  lob_size := dbms_lob.getlength(v_sql);
  loop
    if(MAX_SIZE > lob_size) then
      amount := lob_size;
    end if;
    sql_tbl(tbl_index) := dbms_lob.substr(v_sql, amount, offset);
    tbl_index := tbl_index + 1;
    offset := offset + amount;
    lob_size := lob_size - amount;
    if(lob_size <= 0) then
      exit;
    end if;
  end loop;
end dsg_add_to_sql_tbl;

procedure dsg_put_trace ( dsm_id        integer,
                          tgt_id        raw,
                          operation     varchar2,
                          sub_operation varchar2,
                          trace_out     clob,
                          output_level  integer )
is
  trace_ts date;
  query varchar2(32767);
  table_not_found exception;
  pragma exception_init(table_not_found, -942);

  l_sql_table DBMS_SQL.VARCHAR2a;
  l_ds_cursor integer;
  l_ret_val      integer;
  row_count    number := 0;  

begin
  select sysdate into trace_ts from dual;
  query := 'insert into ' ||
           '"' || dsg_owner || '"' || '.' || dsg_trace_tbl_name ||
           ' values (:1, :2, :3, :4, :5, :6)';
  if dsg_output_to_stdout then
    if output_level >= dsg_get_output_level
    then
      dsg_send_msg(trace_out);
    end if;
  end if;

  begin
       dsg_add_to_sql_tbl(l_sql_table,query);
       l_ds_cursor := DBMS_SQL.OPEN_CURSOR;
       DBMS_SQL.PARSE(l_ds_cursor,
                      l_sql_table,
                      l_sql_table.FIRST,
                      l_sql_table.LAST,
                      FALSE,
                      DBMS_SQL.NATIVE);
       DBMS_SQL.BIND_VARIABLE(l_ds_cursor,':1',dsm_id);
       DBMS_SQL.BIND_VARIABLE(l_ds_cursor,':2',tgt_id);
       DBMS_SQL.BIND_VARIABLE(l_ds_cursor,':3',operation);
       DBMS_SQL.BIND_VARIABLE(l_ds_cursor,':4',sub_operation);
       DBMS_SQL.BIND_VARIABLE(l_ds_cursor,':5',trace_ts);
       DBMS_SQL.BIND_VARIABLE(l_ds_cursor,':6',trace_out);

       l_ret_val := DBMS_SQL.EXECUTE(l_ds_cursor);
       DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
       l_sql_table.DELETE;
       row_count := l_ret_val;
  exception
    when table_not_found then
      dsg_send_msg('trace table does not exist');
      DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
      l_sql_table.DELETE;
    when others then
      if DBMS_SQL.IS_OPEN(l_ds_cursor) then 
         DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
      end if;
      l_sql_table.DELETE;
      raise;
  end;
exception
  when others then
  dsg_send_msg('Error while logging'||chr(13)||chr(10)||sqlerrm(sqlcode));
  raise;
end dsg_put_trace;

procedure dsg_checkpoint ( dsm_id     integer,
                           tgt_id     raw,
                           operation  varchar2,
                           schema     varchar2,
                           as_name    varchar2,
                           table_name varchar2,
                           drv_table  varchar2,
                           detail_1   varchar2,
                           detail_2   varchar2)
is
  operation_ts date;
  query varchar2(32767);
  table_not_found exception;
  pragma exception_init(table_not_found, -942);
begin
  select sysdate into operation_ts from dual;
  query := 'insert into ' ||
           '"' || dsg_owner || '"' || '.' || dsg_track_tbl_name ||
           ' values (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10)';
  if dsg_output_to_stdout then
    dsg_send_msg(detail_1);
  end if;
  execute immediate query
  using	dsm_id,
	tgt_id,
	operation,
	operation_ts,
	schema,
	as_name,
	table_name,
	drv_table,
	detail_1,
	detail_2;
  exception
    when table_not_found then
      dsg_send_msg('track table is not present');
    when others then
      raise;
end dsg_checkpoint;

procedure dsg_set_output_level(output_level in integer)
is
begin
  dsg_output_level := output_level;
end dsg_set_output_level;

function dsg_get_output_level
return integer
is
begin
  return(nvl(dsg_output_level, DSG_INFO));
end dsg_get_output_level;

procedure dsg_do_cleanup
is
custom_db_dir_name varchar2(4000);
custom_dir_path varchar2(4000);
begin
  if dsg_get_cleanup then
    if graph_exists then
      drop_subset_graph;
    end if;

     -- Fix Bug 17410148 : Drop the DB directory created on custom OS path
     begin
       custom_db_dir_name := dsg_get_export_dir;
       custom_dir_path := dsg_get_custom_dir_path;
       if custom_dir_path is not null then
          execute immediate 'drop directory '||custom_db_dir_name;
       end if;
     exception
       when others then
         null;
     end;
  end if;
end dsg_do_cleanup;

--    FUNCTION DSG_COMPARE_VERSION
--    PURPOSE: 	compares the given version to the db version where the script
--              is running
--    PARAMETERS:
--         version - version to be compared
--	         should in the form of dd.*
--    RETURNS:
--         1 if current version is greater,
--	   -1 if current version is smaller,
--	   0 if equal
function dsg_compare_db_version(version in varchar2)
return integer
is
  cur_version varchar2(20);
  cur_comp varchar2(20);
begin
  dbms_utility.db_version(cur_version, cur_comp);
  cur_version := lpad(cur_version, 10, '0');
  if(cur_version = version) then
    return 0;
  end if;
  if(cur_version > version) then
    return 1;
  end if;
  if(cur_version < version) then
    return -1;
  end if;
end dsg_compare_db_version;

--    PROCEDURE DSG_USE_SHADOW_TBLS
--    PURPOSE: checks if there is a need to use the shadow tables based on the
--             rules on the tables
--    PARAMETERS:
--         NONE
--    RETURNS:
--         USE_SHADOW_TBLS
--	     true is shodow tables to be used
procedure dsg_use_shadow_tbls
is
  no_of_rules number;
  query varchar2(32767);
begin
  query := 'select count(*) from ' ||
	   '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
	   ' where PULL_PARENTS = ''Y'' OR PULL_CHILDREN = ''Y''';
  execute immediate query into no_of_rules;
  if no_of_rules  = 0 then
    dsg_use_shadow_tbl_global := FALSE;
  else
    dsg_use_shadow_tbl_global := TRUE;
  end if;
end dsg_use_shadow_tbls;

--    PROCEDURE DSG_SET_GRAPH_OWNER
--    PURPOSE: sets the subset graph owner, by default session user
--    PARAMETERS:
--         GRAPH_OWNER
--           Owner of subset graph tables
--
--    RETURNS:
--         NONE
procedure dsg_set_graph_owner (graph_owner varchar2 := null)
is
  l_user_id number;
  query varchar2(32767);
  user_dollar varchar2(20) := 'SYS.USER$';
begin
  if graph_owner is not null then
    dsg_owner := graph_owner;
  else
    if(dsg_compare_db_version('12.1.0.0.0') >= 0) then
      user_dollar := '"SYS"."_BASE_USER"';
    end if;
    l_user_id := SYS_CONTEXT('USERENV', 'SESSION_USERID');
    query := 'select name from ' || user_dollar ||
             ' where user# = ' || l_user_id;
    execute immediate query into dsg_owner;
  end if;
end dsg_set_graph_owner;

procedure dsg_set_dsm_id(dsm_id in integer)
is
begin
  dsg_dsm_id := dsm_id;
end dsg_set_dsm_id;

function dsg_get_dsm_id
return integer
is
begin
  return dsg_dsm_id;
end dsg_get_dsm_id;

procedure dsg_set_tgt_id(tgt_id in raw)
is
begin
  dsg_tgt_id := tgt_id;
end dsg_set_tgt_id;

function dsg_get_tgt_id
return raw
is
begin
  return dsg_tgt_id;
end dsg_get_tgt_id;

procedure dsg_set_create_import_script(create_import_script in boolean)
is
begin
  dsg_create_import_script := create_import_script;
end dsg_set_create_import_Script;

function dsg_get_create_import_script
return boolean
is
begin
  return nvl(dsg_create_import_script, false);
end dsg_get_create_import_script;

procedure dsg_set_max_threads(max_threads in number)
is
begin
  dsg_max_threads := max_threads;
end dsg_set_max_threads;

function dsg_get_max_threads
return number
is
begin
  return nvl(dsg_max_threads, 1);
end dsg_get_max_threads;

--    PROCEDURE DSG_SET_EXEC_METHOD
--    PURPOSE: sets the subset execution method
--    PARAMETERS:
--         METHOD
--           method of the subset execution
--
--    RETURNS:
--         NONE
procedure dsg_set_exec_method (exec_method in number)
is
begin
  if exec_method = DSG_EXEC_OPTION_EXPORT or
     exec_method = DSG_EXEC_OPTION_INPLACE then
    dsg_exec_option := exec_method;
  else
    dbms_standard.raise_application_error(DSG_INVALID_EXEC_METHOD,
                               'Invalid execution method: ' || exec_method);
  end if;
end dsg_set_exec_method;

--    PROCEDURE DSG_SET_EXPORT_TYPE
--    PURPOSE: sets the type of subset export
--    PARAMETERS:
--          TYPE
--             type of in-export subsetting
--    RETURNS:
--          NONE
procedure dsg_set_export_type(export_type in number)
is
begin
   if export_type = DSG_EXPORT_OPTION_SUBSET_ONLY or
      export_type = DSG_EXPORT_OPTION_FULL or
      export_type = DSG_EXPORT_OPTION_UNDEFINED then
         dsg_export_type := export_type;
   else
    dbms_standard.raise_application_error(DSG_INVALID_EXPORT_TYPE,
                               'Invalid export type: ' || export_type);
   end if;
end dsg_set_export_type;

-- set the re-entrant mode
procedure dsg_set_reentrant_mode (reentrant_mode in boolean)
is
begin
  dsg_reentrant_mode := reentrant_mode;
end dsg_set_reentrant_mode;

-- set the  force clean option
procedure dsg_set_force_clean (force_clean in boolean)
is
begin
  dsg_force_clean := force_clean;
end dsg_set_force_clean;

--get
function dsg_get_force_clean
return boolean
is
begin
  return nvl(dsg_force_clean, true);
end dsg_get_force_clean;


-- FUNCTION DSG_GET_EXEC_METHOD
function dsg_get_exec_method
return number
is
begin
  return dsg_exec_option;
end dsg_get_exec_method;

-- FUNCTION DSG_GET_EXPORT_DIR
function dsg_get_export_dir
return varchar2
is
begin
  return dsg_export_dir;
end dsg_get_export_dir;

--FUNCTION DSG_GET_EXPORT_DUMPFILE
function dsg_get_export_dumpfile
return varchar2
is
  t_date varchar2(20);
begin
  if dsg_export_dumpfile is null
  then
    select to_char(sysdate, 'Mondd') into t_date from dual;
    dsg_export_dumpfile := 'subset_dump_%U_' || t_date || '.dmp';
  end if;
  return dsg_export_dumpfile;
end dsg_get_export_dumpfile;

--FUNCTION DSG_GET_DUMP_SIZE
function dsg_get_dump_size
return varchar2
is
begin
  return nvl(dsg_dump_size, '1G');
end dsg_get_dump_size;

-- FUNCTION DSG_GET_REENTRANT_MODE
function dsg_get_reentrant_mode
return boolean
is
begin
  return nvl(dsg_reentrant_mode, false);
end dsg_get_reentrant_mode;

-- FUNCTION DSG_GET_GRAPH_DUMPFILE
function dsg_get_graph_dumpfile
return varchar2
is
begin
  return dsg_graph_dump;
end dsg_get_graph_dumpfile;

function dsg_get_logging_option
return boolean
is
begin
  return nvl(dsg_logging_off, false);
end dsg_get_logging_option;

function dsg_get_global_rule
return boolean
is
begin
  return nvl(dsg_global_rule, false);
end dsg_get_global_rule;

function dsg_get_drop_tables_option
return boolean
is
begin
  return nvl(dsg_drop_tables, true);
end dsg_get_drop_tables_option;

function dsg_get_export_log
return varchar2
is
begin
  return nvl(dsg_export_log, 'subset_dump.log');
end dsg_get_export_log;

function dsg_get_export_log_dir
return varchar2
is
begin
  return nvl(dsg_export_log_dir, dsg_get_export_dir);
end dsg_get_export_log_dir;


function graph_exists
return boolean
is
  graph_obj_list varchar2(4000) := '(''DB_DSG_APPS_E'', ''DB_DSG_NODE_E'',
                                     ''DB_DSG_EDGES_E'', ''DB_DSG_KEY_COLS_E'',
                                     ''DB_DSG_IMPTS_E'',
                                     ''DB_DSG_DDLS_E'', ''DB_DSG_EXEC_TRACK_E'',
                                     ''DB_DSG_EXEC_TRACE_E'',
                                     ''DB_DSG_MAP_TABLE'', ''DBMS_DSM_DSG_IM'',
                                     ''DBMS_DSM_DSG_CR'', ''DB_DSM_SEED_TABLE'',
                                     ''DB_DSG_SPL_EDGES_E'',
                                     ''DBMS_DSM_DSG_IM_DM'',
                                     ''DB_DSG_PROCESSING_CHAIN_E'')';
  graph_object_count integer := 0;
  graph_rowid_tbl_count integer := 0;
  query varchar2(32767);
begin
  query := 'select count(*) from dba_objects
	    where owner = ' || '''' || dsg_owner || '''' ||
	    ' and object_name in ' || graph_obj_list;
  execute immediate query into graph_object_count;

  query := 'select count(*) from dba_objects where owner=' ||
           '''' || dsg_owner || '''' || ' and object_name like ' ||
           '''' || dsg_row_id_tbl_name || '%''';

  execute immediate query into graph_rowid_tbl_count;

  -- for now we just check for at least one object
  if graph_object_count > 0 OR graph_rowid_tbl_count > 0 then
      return TRUE;
  else
    return FALSE;
  end if;

end graph_exists;



--    PROCEDURE DSG_SET_EXPORT_DIR
--    PURPOSE: sets the subset export directory
--    PARAMETERS:
--         EXPORT_DIR
--           export directory to which subset contentet will uploaded
--
--    RETURNS:
--         NONE
procedure dsg_set_export_dir (export_dir in varchar2)
is
begin
  -- TBD: shatanu error check for proper directory name

  -- set
  dsg_export_dir := export_dir;
end dsg_set_export_dir;

--    PROCEDURE DSG_SET_EXPORT_DUMPFILE
--    PURPOSE: sets the subset export dumpfile name
--    PARAMETERS:
--	   EXPORT_DUMPFILE
--	     the name of the dumpfile that will contain the subset
--    RETURNS:
--	   NONE
procedure dsg_set_export_dumpfile (export_dumpfile in varchar2)
is
begin
  dsg_export_dumpfile := export_dumpfile;
end dsg_set_export_dumpfile;

--    PROCEDURE DSG_SET_DUMP_SIZE
--    PURPOSE: sets the subset export dumpfile size
--    PARAMETERS:
--         DUMP_SIZE
--           the size of the export dumpfiles
--    RETURNS:
--         NONE
procedure dsg_set_dump_size (dump_size in varchar2)
is
begin
  dsg_dump_size := dump_size;
end dsg_set_dump_size;


--    PROCEDURE DSG_SET_GRAPH_DUMPFILE
--    PURPOSE: sets the subset graph dumpfile name
--    PARAMETERS:
--         GRAPH_DUMP
--           the name of the subset graph dumpfile
--    RETURNS:
--         NONE
procedure dsg_set_graph_dumpfile (graph_dump in varchar2)
is
begin
  dsg_graph_dump := graph_dump;
end dsg_set_graph_dumpfile;

procedure dsg_set_logging_option(logging_off in boolean)
is
begin
  dsg_logging_off := logging_off;
end dsg_set_logging_option;

procedure dsg_set_global_rule(global_rule in boolean)
is
begin
  dsg_global_rule := global_rule;
end dsg_set_global_rule;

procedure dsg_set_drop_tables_option(drop_tables in boolean)
is
begin
  if drop_tables is null then
    dsg_drop_tables := TRUE;
  else
    dsg_drop_tables :=drop_tables;
  end if;
end dsg_set_drop_tables_option;

procedure dsg_set_export_log ( log_name in varchar2)
is
begin
  dsg_export_log := log_name;
end dsg_set_export_log;

procedure dsg_set_export_log_dir (log_dir in varchar2)
is
begin
  dsg_export_log_dir := log_dir;
end dsg_set_export_log_dir;

procedure dsg_set_create_export_log (create_export_log in boolean)
is
begin
  dsg_create_export_log := create_export_log;
end dsg_set_create_export_log;

-- Fix Bug 17410148 : set custom directory path specified in parameter file
procedure dsg_set_custom_dir_path (path in varchar2 default null)
is
begin
  dsg_custom_dir_path := path;
end dsg_set_custom_dir_path;

-- Fix Bug 17410148 : get custom directory path
function dsg_get_custom_dir_path
return varchar2
is
begin
 return dsg_custom_dir_path;
end dsg_get_custom_dir_path;

function dsg_get_create_export_log
return boolean
is
begin
  return nvl(dsg_create_export_log, true);
end dsg_get_create_export_log;

procedure dsg_set_cleanup(do_cleanup in boolean)
is
begin
  dsg_cleanup := do_cleanup;
end dsg_set_cleanup;

function dsg_get_cleanup
return boolean
is
begin
  return nvl(dsg_cleanup, TRUE);
end dsg_get_cleanup;

procedure dsg_set_do_inline_mask(do_inline_mask in boolean)
is
begin
  dsg_do_inline_mask := do_inline_mask;
end dsg_set_do_inline_mask;

function dsg_get_do_inline_mask
return boolean
is
begin
  return nvl(dsg_do_inline_mask, FALSE);
end;

procedure dsg_set_apply_column_rules(apply_column_rules in boolean)
is
begin
  dsg_apply_column_rules := apply_column_rules;
end dsg_set_apply_column_rules;

function dsg_get_apply_column_rules
return boolean
is
begin
  return nvl(dsg_apply_column_rules, FALSE);
end dsg_get_apply_column_rules;

procedure dsg_set_enable_compression(enable_compression in boolean)
is
begin
  dsg_enable_compression := enable_compression;
end dsg_set_enable_compression;

function dsg_get_enable_compression
return boolean
is
begin
  return nvl(dsg_enable_compression, FALSE);
end dsg_get_enable_compression;

procedure dsg_set_enable_encryption(enable_encryption in boolean)
is
begin
  dsg_enable_encryption := enable_encryption ;
end dsg_set_enable_encryption;

function dsg_get_enable_encryption
return boolean
is
begin
  return nvl(dsg_enable_encryption , FALSE);
end dsg_get_enable_encryption;

procedure dsg_set_encrypt_password(encrypt_password in varchar2)
is
begin
  dsg_encrypt_password := encrypt_password;
end dsg_set_encrypt_password;

function dsg_get_encrypt_password
return varchar2
is
begin
  return dsg_encrypt_password;
end dsg_get_encrypt_password;

procedure dsg_set_filter_excluded_tbls(filter_excluded_tbls in boolean)
is
begin
  dsg_filter_excluded_tbls := filter_excluded_tbls;
end dsg_set_filter_excluded_tbls;

function dsg_get_filter_excluded_tbls
return boolean
is
begin
  return nvl(dsg_filter_excluded_tbls, TRUE);
end dsg_get_filter_excluded_tbls;

--    PROCEDURE CREATE_EXEC_TRACK_TABLES
--    PURPOSE: Create execution tracking and tracing, debugging info tables
--    PARAMETERS:
--
--    RETURNS:
--         NONE
procedure create_exec_track_tables
is
  ct_command          varchar2(4000);
  it_command          varchar2(4000);
  track_tbl           varchar2(30);
  trace_tbl           varchar2(30);
  object_exists       exception;
  pragma exception_init(object_exists, -955);
begin

  -- create execution tracking table
  begin
    track_tbl := 'DB_DSG_EXEC_TRACK_E';
    ct_command := ' create table ' ||
                  '"' || dsg_owner || '"' || '.' || track_tbl ||
                  ' ( ' ||
                  ' DSM_ID           NUMBER, ' ||
                  ' TGT_ID           RAW(16), ' ||
                  ' OPERATION        VARCHAR2(256), ' ||
                  ' OPERATION_TS     DATE, ' ||
                  ' SCHEMA           VARCHAR2(128), ' ||
                  ' AS_NAME          VARCHAR2(128), ' ||
                  ' TABLE_NAME       VARCHAR2(128), ' ||
                  ' DRV_TABLE        VARCHAR2(128), ' ||
                  ' DETAIL_1         VARCHAR2(4000), ' ||
                  ' DETAIL_2         VARCHAR2(4000) ' ||
                  ' ) ';

    execute immediate ct_command;
  exception
    when object_exists then
      dsg_send_msg(ct_command||chr(13)||chr(10)||sqlerrm(sqlcode));
    when others then
      dsg_send_msg(ct_command||chr(13)||chr(10)||sqlerrm(sqlcode));
      raise;
  end;

  -- create execution tracing table
  begin
    trace_tbl := 'DB_DSG_EXEC_TRACE_E';
    ct_command := ' create table ' ||
                  '"' || dsg_owner || '"' || '.' || trace_tbl ||
                  ' ( ' ||
                  ' DSM_ID           NUMBER, ' ||
                  ' TGT_ID           RAW(16), ' ||
                  ' OPERATION        VARCHAR2(256), ' ||
                  ' SUB_OPERATION    VARCHAR2(256), ' ||
                  ' TRACE_TS         DATE, ' ||
                  ' TRACE_OUT        CLOB ' ||
                  ' ) ';

    execute immediate ct_command;
  exception
    when object_exists then
      dsg_send_msg(ct_command||chr(13)||chr(10)||sqlerrm(sqlcode));
    when others then
      dsg_send_msg(ct_command||chr(13)||chr(10)||sqlerrm(sqlcode));
      raise;
  end;

end create_exec_track_tables;

--    PROCEDURE DSG_DROP_SHADOW_TABLES
--    PURPOSE: Helper routine to drop the shadow tables
--    PARAMETERS:
--         DSM_ID   : subset model id
--         TGT_ID   : Target id
--
--    RETURNS:
--         NONE

procedure dsg_drop_shadow_tables (dsm_id integer, tgt_id raw)
is
  qt_command      varchar2(4000);
  tbl_cursor      sys_refcursor;
  tbl_id             integer;
  table_not_found    exception;
  pragma exception_init (table_not_found, -942);
  pk_tbl_name     varchar2(128);
begin
  -- drop pk shadow tables
  -- build the query to iterate through node table
  qt_command := ' select PK_ROW_TBL from ' ||
                '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
                ' where  DSM_ID = ' || dsm_id || ' AND ' ||
                ' TGT_ID = ' || '''' || tgt_id || '''' ||
                ' AND PK_ROW_TBL is not NULL';

  OPEN tbl_cursor for qt_command;
  LOOP
    fetch tbl_cursor into pk_tbl_name;
    EXIT WHEN tbl_cursor%NOTFOUND;

    dsg_put_trace(dsm_id, tgt_id, 'DROP PK TABLE',
                  'PK_ROW_TBL is: ' || pk_tbl_name,
		  'drop table ' ||
                  '"' || dsg_owner || '"' || '.' || pk_tbl_name, DSG_INFO);
    drop_table(pk_tbl_name);

  END LOOP;
  close tbl_cursor;

  -- drop row_id tables
  -- build the query to iterate through node table
  qt_command := 'select distinct (table_id) ' ||
              ' from ' || '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
              ' where dsm_id = ' || dsm_id || ' AND ' ||
              ' TGT_ID = ' || '''' || tgt_id || '''' ||
              ' AND PK_ROW_TBL is NULL' ;
  OPEN tbl_cursor for qt_command;
  LOOP
    fetch tbl_cursor into tbl_id;
    EXIT WHEN tbl_cursor%NOTFOUND;

    dsg_put_trace(dsm_id, tgt_id, 'DROP ROWID TABLE',
                  'ROWID_TBL is: ' || dsg_row_id_tbl_name || tbl_id,
		  'drop table ' ||
                  '"' || dsg_owner || '"' || '.' || dsg_row_id_tbl_name||tbl_id,
                  DSG_INFO);
    drop_table(dsg_row_id_tbl_name || tbl_id);

  END LOOP;
  close tbl_cursor;
  exception
    when table_not_found then
      dsg_put_trace('', '', 'DROP SHADOW TABLE', 'ERROR',
                   'table: ' || dsg_node_tbl_name || ' not present',
                   DSG_DEBUG);
    when others then
      raise;
end dsg_drop_shadow_tables;

-- drop sequence
procedure drop_sequence (sequence_name in varchar2)
is
  qt_command varchar2(32767);
  sequence_not_found exception;
  pragma exception_init (sequence_not_found, -2289);
begin
  --error check to ensure it is one of the graph tables, not user private tables
  -- drop the impt table
  qt_command := ' drop sequence ' ||
                '"' || dsg_owner || '"' || '.' || sequence_name ;
  execute immediate qt_command;

exception
  when sequence_not_found then
    --dbms_output.put_line ('sequence: ' || sequence_name || 'not present');
    dsg_put_trace('', '', 'DROP SEQUENCE', 'ERROR', 'sequence: ' ||
			sequence_name || ' not present', DSG_ERROR);
  when others then
    raise;
end drop_sequence;

-- drop table
procedure drop_table (table_name in varchar2)
is
  qt_command varchar2(32767);
  table_not_found exception;
  pragma exception_init (table_not_found, -942);
begin
  --error check to ensure it is one of the graph tables, not user private tables
  -- drop the impt table
  -- bug#21368683 : drop the tables with PURGE option to reclaim space
  -- immediately
  qt_command := ' drop table ' ||
                '"' || dsg_owner || '"' || '.' ||  '"' || table_name || '"' ||
                ' purge';
  execute immediate qt_command;

exception
  when table_not_found then
    --dbms_output.put_line ('table: ' || table_name || 'not present');
    dsg_put_trace('', '', 'DROP TABLE', 'ERROR',
                  'table: ' || table_name || ' not present', DSG_DEBUG);
  when others then
    raise;
end drop_table;

--    PROCEDURE DSG_ADJUST_SEQ_COUNTERS
--    PURPOSE:
--         Sets the sequences counters to the max value used from tables.
--         This is mainly a helper function.
--         Hopefully we don't need to use the procedure in actual execution
--         If a ref-relation need to be added after importing the sugset graph
--         from EM repository, the new ref-relation has to use sequence values
--         which should not conflict with ids that are already imported.
--    PARAMETERS:
--         DSM_ID       : subset model id
--         TGT_ID       : Target id
--
--    RETURNS:
--         NONE
--
procedure dsg_adjust_seq_counters
is
  qt_command varchar2(400);
  max_seq_number integer;
  cur_seq_number integer;
begin
  -- 1. Table id sequence
  qt_command := ' select MAX(TABLE_ID) from ' ||
                '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name;

  execute immediate qt_command
  into max_seq_number;

  qt_command  := 'select ' ||
                 '"' || dsg_owner || '"' || '.' ||
                 dsg_tbl_id_seq_name ||'.nextval from dual';
  execute immediate qt_command
  into cur_seq_number;

  -- alter sequence
  qt_command := ' alter sequence ' ||
                '"' || dsg_owner || '"' || '.' || dsg_tbl_id_seq_name ||
                ' increment by ' || (max_seq_number - cur_seq_number + 1);

  execute immediate qt_command;

  -- 2. Edge id sequence
  qt_command := ' select MAX(TABLE_ID) from ' ||
                '"' || dsg_owner || '"' || '.' || dsg_edge_tbl_name;

  execute immediate qt_command
  into max_seq_number;

  qt_command  := 'select ' ||
                 '"' || dsg_owner || '"' || '.' ||
                 dsg_edge_id_seq_name || '.nextval from dual';
  execute immediate qt_command
  into cur_seq_number;

  -- alter sequence
  qt_command := ' alter sequence ' ||
                '"' || dsg_owner || '"' || '.' || dsg_edge_id_seq_name ||
                ' increment by ' || (max_seq_number - cur_seq_number + 1);

  execute immediate qt_command;

  -- 3. Key(column group) id sequence
  qt_command := ' select MAX(TABLE_ID) from ' ||
                '"' || dsg_owner || '"' || '.' || dsg_kc_tbl_name;

  execute immediate qt_command
  into max_seq_number;

  qt_command  := 'select ' || '"' || dsg_owner || '"' || '.' ||
                 dsg_key_id_seq_name || '.nextval from dual';
  execute immediate qt_command
  into cur_seq_number;

  -- alter sequence
  qt_command := ' alter sequence ' ||
                '"' || dsg_owner || '"' || '.' || dsg_key_id_seq_name ||
                ' increment by ' || (max_seq_number - cur_seq_number + 1);

  execute immediate qt_command;

end dsg_adjust_seq_counters;

--    PROCEDURE DSG_GET_TABLE_STATS
--    PURPOSE:
--             Get the table stats
--    PARAMETERS:
--         SCHEMA_NAME    IN  : schema name
--         TABLE_NAME     IN  : table name
--
--    RETURNS:
--         NONE
--
procedure dsg_get_table_stats ( schema_name      in varchar2,
                                table_name       in varchar2,
                                src_num_rows    out number,
                                avg_row_size    out number,
                                pkc_name        out varchar2,
                                is_iot          out varchar2,
                                is_row_movement out varchar2 )
is
  qt_command         varchar2(32767);
--  d_table            dba_tables%rowtype; making dynamic
  iot_type varchar2(12);
  row_movement varchar2(8);
  num_rows number;
  avg_row_len number;

begin
  qt_command := ' select iot_type, row_movement, num_rows, avg_row_len ' ||
		' from dba_tables ' ||
                ' where owner = ' || '''' || schema_name || '''' ||
                ' and table_name = ' || '''' || table_name || '''';

  execute immediate qt_command
  into iot_type, row_movement, num_rows, avg_row_len;

  -- iot type
  if iot_type = 'IOT' then
    is_iot := 'Y';
  else
    is_iot := 'N';
  end if;

  --row movement
  if row_movement = 'DISABLED' then
      is_row_movement := 'N';
    else
      is_row_movement := 'Y';
  end if;

  -- number of src rows
  if num_rows is not null then
    src_num_rows := num_rows;
  else
    src_num_rows := 0;
  end if;

  -- average row size
  if avg_row_len is not null then
    avg_row_size := avg_row_len;
  else
    avg_row_size := 0;
  end if;

  -- primary key constraint, if any
  qt_command := ' select constraint_name from dba_constraints ' ||
               ' where table_name = ' || '''' || table_name || '''' ||
               ' and constraint_type = ' || '''' || 'P' || '''' ||
               ' and owner = ' || '''' || schema_name || '''';

  begin
    execute immediate qt_command
      into pkc_name;
  exception
    when others then
      pkc_name := NULL;
  end;

exception
  when others then
    --dbms_output.put_line('dbms_dsm_dsg: dsg_get_table_stats failed for : ' ||
--                         schema_name || '.' || table_name);
  dsg_put_trace('','', 'GET TABLE STATS', 'FAILED', 'dbms_dsm_dsg: ' ||
			'dsg_get_table_stats failed for : ' ||
                        schema_name || '.' || table_name, DSG_ERROR);

end dsg_get_table_stats;

--    PROCEDURE DSG_RESET_GRAPH
--    PURPOSE:
--             deletes all the rules
--             deletes the impt tables rows
--             sets all the source stats of node and appl tables to zero
--             resets the processed flags
--    PARAMETERS:
--         DSM_ID       : subset model id
--         TGT_ID       : Target id
--
--    RETURNS:
--         NONE
--
--    NOTE: This is just reset of the graph
--          There will be another routine 'refresh' to refetch the stats
--          re-evaluate the rules.
--          In the reset, we keep the rules on nodes as it is.
--          This function will be useful both design time analysis @emrepository
--          and execution time @target
procedure dsg_reset_graph ( dsm_id        integer,
                            tgt_id        raw )
is
  qt_command         varchar2(32767);
  l_dsg_app_tbl      varchar2(30);
  l_dsg_node_tbl     varchar2(30);
  l_dsg_edge_tbl     varchar2(30);
  l_dsg_rowid_tbl    varchar2(30);
  l_dsg_imptid_tbl   varchar2(30);
  l_dsg_tblid_seq    varchar2(30);
  l_as_name          varchar2(128);
  l_sch_name         varchar2(128);
  l_table_name       varchar2(128);
  l_table_type       varchar2(30);
  node_cursor        sys_refcursor;
  app_cursor         sys_refcursor;

begin

  --TBD: error checks

  --delete th impt table
  qt_command := ' delete ' ||
                '"' || dsg_owner || '"' || '.' || dsg_impt_tbl_name ||
                ' where DSM_ID = ' || dsm_id ||
                ' AND TGT_ID = ' || '''' || tgt_id || '''';
  execute immediate qt_command;

  -- drop the shadow tables
  dsg_drop_shadow_tables(dsm_id, tgt_id);

  -- reset the node tables
  qt_command := ' update ' ||
              '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
              ' set SRC_NUM_ROWS = 0, EXPT_NUM_ROWS = 0, ACT_NUM_ROWS = 0, ' ||
              ' AVG_ROW_SIZE = 0, IS_ACTIVE = ' || '''' || 'N' || '''' || ',' ||
              ' IS_RULE_PROCESSED = ' || '''' || 'N' || '''' ||
              ' where DSM_ID = ' || dsm_id ||
              ' AND TGT_ID = ' || '''' || tgt_id || '''';
  execute immediate qt_command;

  -- reset app level rollup stats
  qt_command := ' update ' ||
                '"' || dsg_owner || '"' || '.' || dsg_app_tbl_name  ||
                ' set ACTUAL_DATA = 0, DERIVED_DATA = 0, ' ||
                ' EXP_ACTUAL_DATA = 0, EXP_DERIVED_DATA = 0, '   ||
                ' IS_IA_PROCESSED = ' || '''' || 'N' || '''' ||
                ' where DSM_ID = ' || dsm_id ||
                ' AND TGT_ID = ' || '''' || tgt_id || '''';

  execute immediate qt_command;

end dsg_reset_graph;

--    PROCEDURE DSG_REFRESH_GRAPH_STATS
--    PURPOSE:
--             Refreshes the node and application rollup status
--             Always gets called after 'reset_graph'.
--             Only useful to be invoked  @target, design time time we have a
--             Java service that queries the target and refreshes the graph
--             that resides in the emrepo
--    PARAMETERS:
--         DSM_ID       : subset model id
--         TGT_ID       : Target id
--
--    RETURNS:
--         NONE
--
--    NOTE: Only useful @target where the tables need to be subsetted

procedure dsg_refresh_graph_stats ( dsm_id        integer,
                                    tgt_id        raw )
is
  qt_command         varchar2(32767);
  ut_command         varchar2(32767);
  app_ut_command     varchar2(32767);
  l_as_name          varchar2(128);
  l_sch_name         varchar2(128);
  l_table_name       varchar2(128);
  l_table_type       varchar2(30);
  l_src_num_rows     number;
  l_avg_row_size     number;
  l_pkc_name         varchar2(128) := null;
  l_is_iot           varchar2(1);
  l_is_row_movement  varchar2(1);
  act_tbl_size       number;
  node_cursor        sys_refcursor;

begin
  -- error check on dsm_id and tgt_id

  -- go through every node and re-build the stuff
  qt_command := ' select APPL_SHORT_NAME, RUNTIME_SCHEMA_NAME, TABLE_NAME, ' ||
                ' TABLE_TYPE from ' ||
                '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
                ' where DSM_ID = ' || dsm_id ||
                ' AND TGT_ID = ' || '''' || tgt_id || '''';

  ut_command := ' update ' ||
                '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
                ' set SRC_NUM_ROWS = :l_src_num_rows , ' ||
                '     AVG_ROW_SIZE = :l_avg_row_size  '  ||
                ' where DSM_ID = ' || dsm_id ||
                ' AND TGT_ID = ' || '''' || tgt_id || '''' ||
                ' and APPL_SHORT_NAME = :l_as_name ' ||
                ' and TABLE_NAME = :l_table_name ';

  -- node table cursor
  OPEN node_cursor for qt_command;

  LOOP
    fetch node_cursor into l_as_name, l_sch_name, l_table_name, l_table_type;
    EXIT WHEN node_cursor%NOTFOUND;

    dsg_get_table_stats ( l_sch_name, l_table_name,
                          l_src_num_rows, l_avg_row_size, l_pkc_name,
                          l_is_iot, l_is_row_movement );

    execute immediate ut_command
    using l_src_num_rows, l_avg_row_size, l_as_name, l_table_name;

    act_tbl_size := ((l_src_num_rows * l_avg_row_size)/(1024*1024));

    app_ut_command := ' update ' ||
                     '"' || dsg_owner || '"' || '.' || dsg_app_tbl_name ||
                     ' set ACTUAL_DATA = ACTUAL_DATA' || '+' ||  act_tbl_size ||
                     ' where APPL_SHORT_NAME = ' || '''' || l_as_name || '''' ||
                     ' and SCHEMA_NAME = ' || '''' || l_sch_name || '''' ;

    execute immediate app_ut_command;

  END LOOP;
  close node_cursor;
  commit;
exception
  when others then
    dsg_put_trace(dsm_id, tgt_id, 'REFRESH GRAPH STATS', 'ERROR',
			'dsg_refresh_graph_stats failed for : ' ||
                        l_sch_name || '.' || l_table_name, DSG_ERROR);
end dsg_refresh_graph_stats;

--    PROCEDURE DROP_MASKING_OBJECTS
--    PURPOSE:
--             drops all masking objects created by the subet code
--    PARAMETERS:
--
--    RETURNS:
--         NONE
--
procedure drop_masking_objects
is
  qt_command            varchar2(32767);
  c1                    sys_refcursor;
  mask_mapping_tbl      varchar2(30) := 'MGMT_DM_TT_';
  seed_table		varchar2(30) := 'DB_DSG_SEED_TABLE';
  map_tbl_id            number;
  drop_mapping_tbl      varchar2(1)  := 'N';
  table_not_found       exception;
  pragma exception_init (table_not_found, -942);
  package_not_found     exception;
  pragma exception_init (package_not_found, -4043);
begin
  begin
    qt_command := 'select distinct mask_map_table_id, drop_mapping_table ' ||
                  'from ' || dsg_mask_map_tbl_name;
    open c1 for qt_command;
    loop
      fetch c1 into map_tbl_id, drop_mapping_tbl;
      exit when c1%notfound;

      -- bug 21213545: Check user option before dropping mapping tables
      if drop_mapping_tbl = 'Y'
      then
        dsg_put_trace(null, null,
                      'DROP MASK TABLES', '',
                      'Dropping old mapping tables', DSG_INFO);
        drop_table(mask_mapping_tbl || map_tbl_id);
      end if;
    end loop;
    close c1;
    drop_table(dsg_mask_map_tbl_name);
  exception
    when table_not_found then
      null;
    when others then
      raise;
  end;
  drop_table(seed_table);
  begin
    execute immediate 'drop package dbms_dsm_dsg_im';
  exception
    when package_not_found then
      null;
    when others then
      raise;
  end;
  begin
    execute immediate 'drop package dbms_dsm_dsg_im_dm';
  exception
    when package_not_found then
      null;
    when others then
      raise;
  end;
  begin
    execute immediate 'drop package dbms_dsm_dsg_cr';
  exception
  when package_not_found then
    null;
  when others then
    raise;
  end;
end drop_masking_objects;

--    PROCEDURE DROP_SUBSET_GRAPH
--    PURPOSE:
--             drops all existing subset objects: tables and sequences etc.
--    PARAMETERS:
--
--    RETURNS:
--         NONE
--
procedure drop_subset_graph
is
  qt_command         varchar2(32767);
  node_cursor	     sys_refcursor;
  shadow_tbl	     varchar2(30);
  tbl_id             integer;
  dsm_id             integer;
  tgt_id             raw(16);
  table_not_found    exception;
  pragma exception_init (table_not_found, -942);
begin
  dsg_put_trace(null, null, 'DROP GRAPH', '',
                'Dropping subset graph from target', DSG_INFO);
  dsm_id := dsg_get_dsm_id;
  tgt_id := dsg_get_tgt_id;

  drop_table(dsg_impt_tbl_name);
  drop_table(dsg_kc_tbl_name);
  drop_table(dsg_edge_tbl_name);
  drop_table(dsg_app_tbl_name);
  drop_table(dsg_ddl_tbl_name);
  drop_table(dsg_schema_map_tbl_name);
  drop_table(dsg_dynamic_scripts_tbl_name);
  drop_table(dsg_se_tbl_name);
  drop_table(dsg_pchain_tbl_name);

  if dsg_use_shadow_tbl_global = true then
    dsg_drop_shadow_tables(dsm_id, tgt_id);
  end if; --dsg_use_shadow_tbl_global = true

  drop_table(dsg_node_tbl_name);
  drop_sequence(dsg_tbl_id_seq_name);
  drop_sequence(dsg_key_id_seq_name);
  drop_sequence(dsg_edge_id_seq_name);
  drop_masking_objects;
  drop_table(dsg_track_tbl_name);
  drop_table(dsg_trace_tbl_name);
end drop_subset_graph;

--    FUNCTION DSG_GET_KEYS
--    PURPOSE: Get the columns of a given key
--    PARAMETERS:
--         SCH_NAME   : schema name
--         TAB_NAME   : table name
--         CON_NAME   : constraint name
--
--    RETURNS:
--         KEYIINFO_T
function dsg_get_keys ( sch_name    varchar2,
                       tab_name    varchar2,
                       con_name    varchar2 )
return keyinfo_t
is
  kt_info   keyinfo_t := keyinfo_t();
  column_name varchar2(4000);
  query varchar2(32767);
  type cursor is ref cursor;
  c1 cursor;
begin
  query := 'select column_name from dba_cons_columns where ' ||
	   ' constraint_name = :1 and owner = :2 order by position';
  open c1 for query using con_name, sch_name;
  loop
    fetch c1 into column_name;
    exit when c1%notfound;
    kt_info.extend;
    kt_info(kt_info.LAST) := '"' || column_name || '"';
  end loop;
  close c1;
  return kt_info;
end dsg_get_keys;

--    FUNCTION DSG_GET_KEYS_BYID
--    PURPOSE: Get the columns of a given key
--    PARAMETERS:
--         KEY_ID   : KEY_ID  (a.k.a Columng group id)
--
--    RETURNS:
--         KEYIINFO_T
function dsg_get_keys_byid ( key_id       integer )
return keyinfo_t
is
  kt_info           keyinfo_t := keyinfo_t();
  kc_cursor         sys_refcursor;
  qt_command        varchar2(32767);
  l_col_name        varchar2(128);

begin
  qt_command  :=
    ' select COLUMN_NAME  from ' ||
    '"' || dsg_owner || '"' || '.' || dsg_kc_tbl_name ||
    ' where KEY_ID = :key_id  order by position';

  OPEN kc_cursor for qt_command
  using key_id;

  LOOP
    FETCH kc_cursor
    into l_col_name;

    -- exit loop when last row is fetched
    EXIT WHEN kc_cursor%NOTFOUND OR kc_cursor%NOTFOUND IS NULL;

    -- process the col name
    kt_info.extend;
    -- dbms_output.put_line('dsg_get_keys_byid: col name' || l_col_name);
    kt_info(kt_info.LAST) := '"' || l_col_name || '"';
  END LOOP;
  close kc_cursor;
  return kt_info;
end dsg_get_keys_byid;

-- get the comma seperated text of columns for a given key
--    FUNCTION DSG_GET_KEY_TXT
--    PURPOSE: Get the columns of a given key
--    PARAMETERS:
--         KT_INFO   : KEY info record
--
--    RETURNS:
--         VARCHAR2 (comman seperated text of key columns)
function dsg_get_key_txt (kt_info   keyinfo_t, prefix varchar2)
return varchar2
is
  key_txt   varchar2(32767);

begin
  for element in 1..kt_info.count
  loop
    if element = 1 then
      if prefix is not null then
        key_txt := prefix || '.' || kt_info(element);
      else
        key_txt :=  kt_info(element);
      end if;
    else
      if prefix is not null then
        key_txt := key_txt || ',' || prefix || '.' || kt_info(element);
      else
        key_txt := key_txt || ',' || kt_info(element);
      end if;
    end if;
  end loop;

  if key_txt is null then
    dbms_standard.raise_application_error(DSG_INTERNAL_ERROR,
                                          ' Null key info');
  end if;

  return key_txt;
end dsg_get_key_txt;

procedure dsg_manage_triggers (dsm_id in integer,
			       op_code in number)
is
  query varchar2(32767);
  query1 varchar2(32767);
  query2 varchar2(32767);
  table_name varchar2(128);
  table_owner varchar2(128);
  trigger_owner varchar2(128);
  trigger_name varchar2(128);
  table_id number;
  dsg_node_cursor sys_refcursor;
  dsg_trigger_cursor sys_refcursor;
begin
  if (op_code = DSG_DISABLE_TRG) then
    query1 := 'select table_id, table_name, runtime_schema_name ' ||
             'from ' || '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
             ' where dsm_id = :1 and act_num_rows != 0';
    query2 := 'select owner, trigger_name ' ||
	      'from dba_triggers ' ||
	      'where table_owner = :1 ' ||
  	      'and table_name = :2 and '||
              ' status = ''ENABLED''';
    open dsg_node_cursor for query1 using dsm_id;
    loop
      fetch dsg_node_cursor into table_id, table_name, table_owner;
      exit when dsg_node_cursor%notfound;
      open dsg_trigger_cursor for query2 using table_owner, table_name;
      loop
        fetch dsg_trigger_cursor into trigger_owner, trigger_name;
        exit when dsg_trigger_cursor%notfound;
        query := 'alter trigger ' || '"' || trigger_owner || '"' || '.' ||
                 '"' || trigger_name || '"' || ' disable';
        begin
  	  execute immediate query;
        exception
          when others then
            dsg_put_trace('',
                          '',
                          'MANAGE TRIGGERS',
                          'SQL ERROR',
                          query || CHR(13) || CHR(10) || sqlerrm(sqlcode),
                          DSG_ERROR);
            raise;
        end;
        -- store the trigger name to be re-enabled after subset
        dsg_store_ddl(table_id, 'TRIGGER', trigger_name,
                      trigger_owner, null,null, null, null);
      end loop;
      close dsg_trigger_cursor;
    end loop;
    close dsg_node_cursor;
  elsif (op_code = DSG_ENABLE_TRG) then
    query1 := 'select object_name, object_owner  '||
             ' from ' ||'"' || dsg_owner || '"' || '.' || dsg_ddl_tbl_name ||
             ' where object_type = ''TRIGGER''';
    open dsg_node_cursor for query1;
    loop
      fetch dsg_node_cursor into trigger_name, trigger_owner;
      exit when dsg_node_cursor%notfound;
      begin
        query := 'alter trigger ' || '"' || trigger_owner || '"' || '.' ||
                 '"' || trigger_name || '"' || ' enable';
	execute immediate query;
      exception
      when others then
         dsg_put_trace('',
                       '',
                       'MANAGE TRIGGERS',
                       'SQL ERROR',
                       query || CHR(13) || CHR(10) || sqlerrm(sqlcode),
                       DSG_ERROR);
         raise;
      end;
    end loop;
    close dsg_node_cursor;
  end if;
end dsg_manage_triggers;

function dsg_is_queuetable( owner in varchar2,
				table_name in varchar2 )
return boolean
is
  query varchar2(32767);
  flag number;
begin
  query := 'select count(*) ' ||
           'from dba_queue_tables ' ||
           'where owner = :1 ' ||
           'and queue_table = :2';
  execute immediate query
  into flag
  using owner, table_name;

  if (flag = 0) then
    return false;
  else
    return true;
  end if;
end dsg_is_queuetable;

-- dsg_manage_constraints - disable constraints before
-- deleting data from table and later enable the constraints back.
-- The procedure does 2 loops, first to disable
-- non-primary key constraints and later disable primary key
-- /unique key constraints. While enabling them back we first enable
-- all primary key/unique key constraints and later enable non-primary key
-- constraints.

procedure dsg_manage_constraints(dsm_id in integer,
				 op_code in number)
is
  query1 varchar2(32767);
  query2 varchar2(32767);
  query3 varchar2(32767);
  query varchar2(32767);
  dsg_node_cursor sys_refcursor;
  dsg_cons_cursor sys_refcursor;
  table_name varchar2(128);
  table_owner varchar2(128);
  table_id number;
  is_iot varchar2(1);
  constraint_name varchar2(128);
  constraint_type varchar2(1);
  validated varchar2(13);
begin
 if (op_code = DSG_DISABLE_CONS) then
    -- bug#18258129 : disable only the constraints which are currently enabled
    -- To distinguish between the constraints which are already disabled
    -- and those which subsetting disables, store the constraints
    -- which subsetting disables in DB_DSG_DDLS_E table and
    -- while enabling the constraints back fetch the constraints from
    -- DB_DSG_DDLS_E table and enable them.
    query1 := 'select table_id, table_name, runtime_schema_name, is_iot_table '
              || 'from ' || '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name
              || ' where dsm_id = :1 and table_name not like ''AQ$%''';
    query2 := 'select constraint_name, constraint_type, validated ' ||
              ' from dba_constraints ' ||
              'where owner = :1 and table_name = :2 and ' ||
              ' constraint_type in (''P'', ''U'') and '||
              ' status=''ENABLED''';
    query3 := 'select constraint_name, constraint_type, validated ' ||
              ' from dba_constraints ' ||
              'where owner = :1 and table_name = :2 and ' ||
              ' constraint_type not in (''P'', ''U'') and '||
              ' status=''ENABLED''';
    open dsg_node_cursor for query1 using dsm_id;
    loop
      fetch dsg_node_cursor into table_id, table_name, table_owner, is_iot;
      exit when dsg_node_cursor%notfound;
      if (not (dsg_is_queuetable(table_owner, table_name))) then
        query := null;
        open dsg_cons_cursor for query3 using table_owner, table_name;
        loop
          fetch dsg_cons_cursor into constraint_name, constraint_type, validated;
          exit when dsg_cons_cursor%notfound;
          begin
            -- disable only those constraints and store them whose status
            -- has been enabled before subsetting
            query := 'alter table ' || '"' || table_owner || '"' ||
                     '.' || '"' || table_name || '"' || ' disable constraint '
                     || '"' || constraint_name || '"';
	    execute immediate query;
            -- we don't store the DDL of the constraint as we don't drop and
            -- re-create the constraints, we just disable and enable them back.
            -- we need to store 'validated' flag as we optimize the enabling
            -- of constraints using 'enable novalidate' followed by 'validate'.
            -- if the constraint is initially in 'novalidate' state, we should
            -- maintain the same property after subsetting.
          exception
          when others then
            dsg_put_trace('',
                          '',
                          'MANAGE CONSTRAINTS',
                          'SQL ERROR',
                          query || CHR(13) || CHR(10) || sqlerrm(sqlcode),
                          DSG_ERROR);
  	    raise;
          end;
          dsg_store_ddl(table_id, 'CONSTRAINT', constraint_name,
                        table_owner, table_name,
                        constraint_type, validated, null);
        end loop;
        close dsg_cons_cursor;
      end if;
    end loop;
    close dsg_node_cursor;

    open dsg_node_cursor for query1 using dsm_id;
    loop
      fetch dsg_node_cursor into table_id, table_name, table_owner, is_iot;
      exit when dsg_node_cursor%notfound;
      if (not (dsg_is_queuetable(table_owner, table_name))) then
        query := null;

        open dsg_cons_cursor for query2 using table_owner, table_name;
        loop
          fetch dsg_cons_cursor into constraint_name,
                                     constraint_type,
                                     validated;
          exit when dsg_cons_cursor%notfound;
          if (is_iot = 'N') then
            begin
	      query := 'alter table ' ||
                       '"' || table_owner || '"' ||  '.' || '"' || table_name ||
                       '"' || ' disable constraint ' ||
                       '"' || constraint_name || '"';
              execute immediate query;
            exception
              when others then
              dsg_put_trace('',
                            '',
                            'MANAGE CONSTRAINTS',
                            'SQL ERROR',
                            query || CHR(13) || CHR(10) || sqlerrm(sqlcode),
                            DSG_ERROR);
              raise;
            end;
            dsg_store_ddl(table_id, 'CONSTRAINT', constraint_name,
                          table_owner, table_name,
                          constraint_type, validated, null);
          end if;
        end loop;
        close dsg_cons_cursor;
      end if;
    end loop;
    close dsg_node_cursor;
 else    -- DSG_ENABLE_CONS
    -- go over all constraints stored in DB_DSG_DDLS_E during disable
    -- phase and enable them back
    -- to optimize enabling constraints we first enable them in novalidate
    -- followed by validate.

    -- enable primary key, unique key constraints
    query1 := 'select object_name, object_owner, table_name, '||
              ' validated from ' ||
              '"' || dsg_owner || '"' || '.' || dsg_ddl_tbl_name ||
              ' where object_type = ''CONSTRAINT''' ||
              ' and otype in (''P'', ''U'')';
    open dsg_node_cursor for query1;
    loop
      fetch dsg_node_cursor into constraint_name, table_owner, table_name,
                                 validated;
      exit when dsg_node_cursor%notfound;
      begin
        query := 'alter table ' || '"' || table_owner || '"' ||
                 '.' || '"' || table_name || '"' ||
                 ' enable novalidate constraint ' ||
                 '"' || constraint_name || '"';
	execute immediate query;
        if validated = 'VALIDATED' then
  	   query := 'alter table ' || '"' || table_owner || '"' ||
                    '.' || '"' || table_name || '"' || ' modify constraint ' ||
                    '"' || constraint_name || '"' || ' validate';
           execute immediate query;
        end if;
      exception
      when others then
         dsg_put_trace('',
                       '',
                       'MANAGE CONSTRAINTS',
                       'SQL ERROR',
                       query || CHR(13) || CHR(10) || sqlerrm(sqlcode),
                       DSG_ERROR);
      raise;
      end;
    end loop;
    close dsg_node_cursor;

    -- enable non primary, non unique key constraints
    query1 := 'select object_name, object_owner, table_name, '||
              ' validated from ' ||
              '"' || dsg_owner || '"' || '.' || dsg_ddl_tbl_name ||
              ' where object_type = ''CONSTRAINT''' ||
              ' and otype not in (''P'', ''U'')';
    open dsg_node_cursor for query1;
    loop
      fetch dsg_node_cursor into constraint_name, table_owner, table_name,
                                 validated;
      exit when dsg_node_cursor%notfound;
      begin
        query := 'alter table ' || '"' || table_owner || '"' ||
                 '.' || '"' || table_name || '"' ||
                 ' enable novalidate constraint ' ||
                 '"' || constraint_name || '"';
	execute immediate query;
        if validated = 'VALIDATED' then
  	   query := 'alter table ' ||
                    '"' || table_owner || '"' || '.' || '"' || table_name ||
                    '"' || ' modify constraint ' ||
                    '"' || constraint_name || '"' || ' validate';
           execute immediate query;
        end if;
      exception
      when others then
         dsg_put_trace('',
                       '',
                       'MANAGE CONSTRAINTS',
                       'SQL ERROR',
                       query || CHR(13) || CHR(10) || sqlerrm(sqlcode),
                       DSG_ERROR);
      raise;
      end;
    end loop;
    close dsg_node_cursor;
 end if; -- op_code = DSG_DISABLE_CONS
end dsg_manage_constraints;

-- FUNCTION DSG_TABLE_PROCESSED_AS_PARENT
-- PURPOSE: check if table has been processed as parent
--          list of such tables in contained in global variable
--	    dsg_processed_tables
-- PARAMETERS:
--	schema_name : table owner
-- 	table_name  : table name
--
-- RETURNS:
--	boolean
--
function dsg_table_processed_as_parent (schema_name in varchar2,
					table_name  in varchar2)
return boolean
is
begin
  return dsg_processed_tables.exists(schema_name || '.' || table_name);
end dsg_table_processed_as_parent;

procedure dsg_update_shadow_tbl_stats(table_name in varchar2)
is
begin
  dsg_put_trace('', '', 'GATHER STATS', '',
                'Gather stats for shadow table: ' || table_name,
                DSG_DEBUG);
  dbms_stats.gather_table_stats(
                ownname => '"' || dsg_owner || '"',
                tabname => table_name,
                no_invalidate => false);
exception
    when others then
       dsg_put_trace('',
                     '',
                     'GATHER_STATS',
                     'SQL ERROR',
                     sqlerrm(sqlcode),
                     DSG_ERROR);
    raise;
end dsg_update_shadow_tbl_stats;

--  PROCEDURE DSG_CHECK_TBL_DATA
--  PURPOSE:
--    checks if the src_num_rows column for this table is 0.
--    This can be because the table has no data or
--      the stats are not updated.
--    This procedure will update the src_num_rows column to 1
--      if there are rows in the table.
--    This is being done because for all rows rules src_num_rows
--      column is relied for generating subset.
--  PARAMETERS:
--    TABLE_ID - id of the table in dsg_node table
--  RETURNS:
--    NONE
--
procedure dsg_check_tbl_data (table_id integer)
is
  l_table_owner  varchar2(128);
  l_table_name   varchar2(128);
  l_src_num_rows integer;
  l_num_rows     integer;
  dsm_id         integer;
  tgt_id         raw(16);
  v_sql          varchar2(32767);
begin
  dsm_id := dsg_get_dsm_id;
  tgt_id := dsg_get_tgt_id;
  v_sql := ' select runtime_schema_name,' ||
           '        table_name,' ||
           '        src_num_rows' ||
           ' from ' || '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
           ' where dsm_id = :1' ||
           '   and tgt_id = :2' ||
           '   and table_id = :3';
  execute immediate v_sql
               into l_table_owner,
                    l_table_name,
                    l_src_num_rows
              using dsm_id,
                    tgt_id,
                    table_id;
  if l_src_num_rows = 0
  then
    v_sql := ' select count(*) ' ||
             ' from "' || l_table_owner || '"."' || l_table_name || '"' ||
             ' where rownum < 2';
    execute immediate v_sql
                 into l_num_rows;
    if l_num_rows != 0
    then
      v_sql := ' update' ||
               '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
               ' set src_num_rows = 1' ||
               ' where dsm_id = :1' ||
               '   and tgt_id = :2' ||
               '   and table_id = :3';
      execute immediate v_sql
                  using dsm_id,
                        tgt_id,
                        table_id;
    end if;
  end if;
end dsg_check_tbl_data;

procedure print_part(ptab in dsg_part_table_array) is
begin
  for i in ptab.first .. ptab.last loop
    dbms_output.put_line(ptab(i));
  end loop;
end print_part;

-- split a comma separated list of partition/sub-partitions
-- strings into a array
function dsg_split_partition_clause(part_clause in clob)
return dsg_part_table_array
is
i integer := 0;
pclause clob := part_clause;
dsg_partitions dsg_part_table_array := dsg_part_table_array();
begin
  loop
    i := instr(pclause, ',');
    if i > 0 then
       dsg_partitions.extend(1);
       dsg_partitions(dsg_partitions.last) := substr(pclause, 1, i-1);
       pclause := substr(pclause, i+ length(','));
    else
       dsg_partitions.extend(1);
       dsg_partitions(dsg_partitions.last) := pclause;
       return dsg_partitions;
    end if;
  end loop;
end dsg_split_partition_clause;

--    PROCEDURE DSG_INTERNAL_PROCESS_NODE
--    PURPOSE: Process node (internal)
--    PARAMETERS:
--         DSM_ID       : subset model id
--         TGT_ID       : Target id
--         L_TBL_ID     : Table id
--         PR_OTHER_UCS : Process other user defined clauses
--         DRV_TBL_ID   : Driving Table ID
--         DRV_TBL_REL  : Driving Table relationship
--         L_EDGE_ID    : Edge id
--         DEPTH        : Depth
--         PULL_PARENTS : Pull Parents
--         PULL_CHILDREN : Pull Children
--
--    RETURNS:
--         NONE
--
procedure dsg_internal_process_node ( dsm_id         integer,
                                      tgt_id         varchar2,
                                      l_tbl_id       integer,
                                      pr_other_ucs   boolean := FALSE,
                                      drv_tbl_id     number := 0,
                                      drv_tbl_rel    number := null,
                                      l_edge_id      number := 0,
                                      depth          number := 0,
                                      pull_parents   varchar2 := 'N',
                                      pull_children  varchar2 := 'N' )
is
  l_tbl_as_name            varchar2(128);
  l_tbl_owner              varchar2(128);
  l_tbl_name               varchar2(128);
  l_tbl_type               varchar2(30);
  l_tbl_pk_cname           varchar2(128);
  l_tbl_pk_row_tbl         varchar2(30);
  l_tbl_row_id_tbl         varchar2(30) := dsg_row_id_tbl_name;
  l_tbl_is_iot             varchar2(1);
  l_tbl_is_ud_rule         varchar2(1);
  l_tbl_inc_full           varchar2(1);
  l_tbl_is_active          varchar2(1);
  l_tbl_is_rule_processed  varchar2(1);
  l_tbl_src_num_rows       number;
  l_tbl_expt_num_rows      number;
  l_tbl_act_num_rows       number := 0;
  l_tbl_max_num_rows       number;
  l_tbl_avg_row_size       number;
  l_tbl_rule_id            number;
  l_tbl_keyinfo            keyinfo_t := keyinfo_t();
  l_tbl_pkeyinfo           keyinfo_t := keyinfo_t();
  l_tbl_ud_clause          varchar2(4000);
  l_tbl_p_clause           CLOB;
  l_tbl_sp_clause          CLOB;
  l_tbl_key_id             number;
  l_tbl_pkey_text          varchar2(32767);
  l_tbl_pkey_text_plain    varchar2(32767);
  l_tbl_pull_parents       varchar(1);
  l_tbl_pull_children      varchar(1);

  drv_tbl_name       varchar2(128);
  drv_tbl_owner      varchar2(128);
  drv_tbl_keyinfo    keyinfo_t := keyinfo_t();
  drv_tbl_clause     varchar2(4000);
  drv_tbl_key_id     number;
  drv_tbl_pk_row_tbl varchar2(30);
  drv_tbl_row_id_tbl varchar2(30) := dsg_row_id_tbl_name;
  drv_tbl_inc_full   varchar2(1);
  drv_tbl_use_shadow_table   varchar2(1);
  drv_tbl_pkeyinfo   keyinfo_t := keyinfo_t();
  drv_tbl_pkey_txt_plain varchar2(32767);
  drv_tbl_pk_cname   varchar2(128);

  qt_command         varchar2(32767);
  ref_key_id         number := 0;
  pri_key_id         number := 0;

  insert_dml_part1   varchar2(32767);
  insert_dml_part2   varchar2(32767);
  insert_dml_part3   clob;
  insert_dml_part3_2   varchar2(32767);
  insert_dml_part4   varchar2(32767);
  final_insert_dml   clob;
  query              clob;
  child_fkey_text    varchar2(32767);
  child_fkey_text_plain    varchar2(32767);
  parent_pkey_text   varchar2(32767);
  parent_pkey_text_plain varchar2(32767);
  max_rows           number;
  p_edge_id          number;
  p_edge_table_id    number;
  p_edge_as_name     varchar2(128);
  p_edge_sch_name    varchar2(128);
  p_edge_tbl_name    varchar2(128);
  c_edge_id          number;
  c_edge_table_id    number;
  c_edge_as_name     varchar2(128);
  c_edge_sch_name    varchar2(128);
  c_edge_tbl_name    varchar2(128);
  is_pp              boolean := FALSE;
  is_pc              boolean := FALSE;
  use_shadow_table   boolean := FALSE;
  row_count          number := 0;
  row_count_1        number := 0;
  parent_cursor      sys_refcursor;
  child_cursor       sys_refcursor;
  got_some_rows      boolean := FALSE;
  l_expl_popu        boolean := FALSE;
  print_info         clob;
  i                  number := 0;
  is_selected_app    varchar2(1) := 'N';
  is_bulk_rule	     varchar2(1) := 'N';

  l_sql_table DBMS_SQL.VARCHAR2a;
  l_ds_cursor integer;
  l_ret_val   integer;

  qry_spl_edges      varchar2(32767);
  spl_edges_num      integer := 0;
  node_partitions dsg_part_table_array := dsg_part_table_array();
  node_sub_partitions dsg_part_table_array := dsg_part_table_array();
begin
  dsg_use_shadow_tbls;
  -- fetch the table info
  qt_command := ' select APPL_SHORT_NAME, RUNTIME_SCHEMA_NAME, TABLE_NAME, ' ||
                ' TABLE_TYPE, PKEY_CNAME, PK_ROW_TBL, IS_IOT_TABLE, ' ||
                ' SRC_NUM_ROWS, EXPT_NUM_ROWS, ACT_NUM_ROWS, MAX_NUM_ROWS, '||
                ' AVG_ROW_SIZE, IS_INCLUDE_ALL, IS_UD_RULE, IS_ACTIVE, ' ||
                ' IS_RULE_PROCESSED, RUNTIME_UD_CLAUSE, PULL_PARENTS, ' ||
                ' PULL_CHILDREN, RULE_ID, PCLAUSE,SPCLAUSE from ' ||
                '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
                ' where TABLE_ID = :1';

  execute immediate qt_command
  into l_tbl_as_name, l_tbl_owner, l_tbl_name, l_tbl_type, l_tbl_pk_cname,
         l_tbl_pk_row_tbl, l_tbl_is_iot, l_tbl_src_num_rows,
         l_tbl_expt_num_rows, l_tbl_act_num_rows, l_tbl_max_num_rows,
         l_tbl_avg_row_size, l_tbl_inc_full, l_tbl_is_ud_rule, l_tbl_is_active,
         l_tbl_is_rule_processed, l_tbl_ud_clause, l_tbl_pull_parents,
         l_tbl_pull_children, l_tbl_rule_id, l_tbl_p_clause, l_tbl_sp_clause
  using l_tbl_id;


  -- fetch the driver table info
  if drv_tbl_id != 0 then
    qt_command := ' select RUNTIME_SCHEMA_NAME, TABLE_NAME, ' ||
                ' PK_ROW_TBL, ' ||
                ' IS_INCLUDE_ALL, USE_SHADOW_TBL, PKEY_CNAME  from ' ||
                '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
                ' where TABLE_ID = :1';

    execute immediate qt_command
    into drv_tbl_owner, drv_tbl_name,
         drv_tbl_pk_row_tbl, drv_tbl_inc_full,
         drv_tbl_use_shadow_table, drv_tbl_pk_cname
    using drv_tbl_id;
  end if;

  -- fetch the edge info
  if l_edge_id != 0 then
    qt_command := ' select REF_KEY_ID, PRI_KEY_ID from ' ||
                    '"' || dsg_owner || '"' || '.' || dsg_edge_tbl_name ||
                  ' where EDGE_ID = :1';

    execute immediate qt_command
    into ref_key_id, pri_key_id
    using l_edge_id;
  end if;

  -- build the key info
  if drv_tbl_rel = DRV_NODE_PARENT and drv_tbl_id != 0  then
    drv_tbl_keyinfo  := dsg_get_keys_byid(pri_key_id);
    l_tbl_keyinfo    := dsg_get_keys_byid(ref_key_id);
  elsif drv_tbl_rel = DRV_NODE_CHILD and drv_tbl_id != 0 then
    l_tbl_keyinfo    := dsg_get_keys_byid(pri_key_id);
    drv_tbl_keyinfo  := dsg_get_keys_byid(ref_key_id);
  end if;

  -- fill the l_tbl pkey info if needed
  if l_tbl_pk_cname is not null then
    l_tbl_pkeyinfo    := dsg_get_keys(l_tbl_owner,
                                      l_tbl_name,
                                      l_tbl_pk_cname);
    l_tbl_pkey_text   := dsg_get_key_txt(l_tbl_pkeyinfo, 'A');
    l_tbl_pkey_text_plain := dsg_get_key_txt(l_tbl_pkeyinfo, null);
  end if;

  -- fill the drv_tbl pkey info if drv tbl is iot
  if drv_tbl_pk_cname is not null then
    drv_tbl_pkeyinfo := dsg_get_keys(drv_tbl_owner,
                                     drv_tbl_name,
                                     drv_tbl_pk_cname);
    drv_tbl_pkey_txt_plain := dsg_get_key_txt(drv_tbl_pkeyinfo, null);
  end if;

  use_shadow_table := FALSE;
  -- check if we have to use shadow table even in case of full include.
  if l_tbl_inc_full = 'Y' and drv_tbl_id != 0 then
    -- check if rule scopes vary
    if l_tbl_pull_parents = pull_parents and
       l_tbl_pull_children = pull_children then
      use_shadow_table := FALSE;
    else
      use_shadow_table := TRUE;
    end if;
  end if;

  --build the partition table
  if l_tbl_p_clause is not null then
  node_partitions := dsg_split_partition_clause(l_tbl_p_clause);
  --print_part(node_partitions);
  end if;
  if l_tbl_sp_clause is not null then
  node_sub_partitions := dsg_split_partition_clause(l_tbl_sp_clause);
  --print_part(node_sub_partitions);
  end if;

  -- start building the query for the subset collection
  -- Fix bug 19632931 : Add enable_parallel_dml hint to make DML parallel.
  --   this issue is only when sys owned objects referred in DMLs and DMLs
  --   executed from plsql stored procedure. enable_parallel_dml is a new
  --   hint introduced in 12c, please refer bug#13588521.

  -- Bug 22915757 : if dsg_use_shadow_tbl_global is false, not populating the 
  --                shadow tables.

  if dsg_use_shadow_tbl_global = true then
   if l_tbl_inc_full != 'Y' or use_shadow_table = TRUE then
    if l_tbl_pk_row_tbl is not null then
      if depth = 0 then
	insert_dml_part1 := ' insert /*+ enable_parallel_dml append */ into ' || 
                        '"' || dsg_owner || '"' || '.' || l_tbl_pk_row_tbl ||
                        ' select  ' || l_tbl_pkey_text_plain ||
                        ' from "' || l_tbl_owner || '"."' || l_tbl_name || '"';
      else
	insert_dml_part1 := ' insert /*+ enable_parallel_dml append */ into ' || 
                           '"' || dsg_owner || '"' || '.' || l_tbl_pk_row_tbl ||
                           ' select  ' ||
        '/*+ OPT_PARAM(''_optimizer_sortmerge_join_enabled'', ''FALSE'') */ ' || 
			    l_tbl_pkey_text ||
                            ' from "' || 
                            l_tbl_owner || '"."' || l_tbl_name || '" A';
      end if;
    else
      if depth = 0 then
	insert_dml_part1 := ' insert /*+ enable_parallel_dml append */ into '|| 
                            '"' || dsg_owner || '"' || '.' || 
                            l_tbl_row_id_tbl || l_tbl_id ||
                            ' select  ROWID from "' || 
                            l_tbl_owner || '"."' || l_tbl_name || '"';
      else
	insert_dml_part1 := ' insert /*+ enable_parallel_dml append */ into ' 
                            || '"' || dsg_owner || '"' || '.' 
                            || l_tbl_row_id_tbl || l_tbl_id ||
                            ' select  ' ||
       '/*+ OPT_PARAM(''_optimizer_sortmerge_join_enabled'', ''FALSE'') */ ' || 
                            'A.ROWID from "' || 
                            l_tbl_owner || '"."' || l_tbl_name || '" A';
      end if;
    end if; --if l_tbl_pk_row_tbl is not null
    -- part 2
    insert_dml_part2 := ' where ';

    -- part 3
    if l_tbl_is_ud_rule = 'Y' and l_tbl_is_rule_processed != 'Y' then
      if depth = 0 or pr_other_ucs = TRUE then
        if l_tbl_p_clause is not null or l_tbl_sp_clause is not null then  
          if l_tbl_p_clause is not null then
            insert_dml_part2 := ' ';
            for i in node_partitions.first .. node_partitions.last - 1 loop
              if l_tbl_pk_row_tbl is not null then
                insert_dml_part3 := insert_dml_part3 || 
                                    'partition('||node_partitions(i)||')';
                if l_tbl_ud_clause is not null then 
                  insert_dml_part3 := insert_dml_part3 || 
                                      ' where '|| l_tbl_ud_clause;
                end if;  
                insert_dml_part3 := insert_dml_part3 ||
                                 ' union all select  distinct '||
                                 l_tbl_pkey_text_plain ||
                                 ' from "' || 
                                 l_tbl_owner || '"."' || l_tbl_name || '"';
              else
                insert_dml_part3 := insert_dml_part3 || 
                                    ' partition('||node_partitions(i)||')';
                if l_tbl_ud_clause is not null then 
                  insert_dml_part3 := insert_dml_part3 || 
                                      ' where '|| l_tbl_ud_clause;
                end if;  
                insert_dml_part3 := insert_dml_part3 ||
                                   ' union all select  ROWID' ||
                                   ' from "' ||
                                   l_tbl_owner || '"."' || l_tbl_name || '"';
              end if;
            end loop;
            insert_dml_part3 := insert_dml_part3 || 
                                ' partition('||
                                node_partitions(node_partitions.count)||
                                ')';
            if l_tbl_ud_clause is not null then 
               insert_dml_part3 := insert_dml_part3 || 
                                   ' where '|| l_tbl_ud_clause;
            end if;  

            if node_sub_partitions.count > 0 then
               if l_tbl_pk_row_tbl is not null then
                 insert_dml_part3 := insert_dml_part3 || 
                                ' union all select  distinct '||
                                l_tbl_pkey_text_plain ||
                                ' from "' ||
                                l_tbl_owner || '"."' || l_tbl_name || '"';
               else
                 insert_dml_part3 := insert_dml_part3 || 
                                   ' union all select  ROWID' ||
                                   ' from "' ||
                                   l_tbl_owner || '"."' || l_tbl_name || '"';
               end if;  
           end if;        
          end if; -- if tbl_p_clause not null
          
          if l_tbl_sp_clause is not null then 
            insert_dml_part2 := ' ';
          
            for i in node_sub_partitions.first .. node_sub_partitions.last - 1 
            loop
              if l_tbl_pk_row_tbl is not null then
                insert_dml_part3 := insert_dml_part3 || 
                                  'subpartition('||
                                  node_sub_partitions(i)||
                                  ')';
                if l_tbl_ud_clause is not null then 
                 insert_dml_part3 := insert_dml_part3 || 
                                     ' where '|| l_tbl_ud_clause;
                end if;  
                insert_dml_part3 := insert_dml_part3 ||
                                ' union all select  distinct ' ||
                                l_tbl_pkey_text_plain ||
                                ' from "' ||
                                l_tbl_owner || '"."' || l_tbl_name || '"';
              else
                insert_dml_part3 := insert_dml_part3 || 
                                    ' subpartition('||
                                    node_sub_partitions(i)||
                                    ')';
                if l_tbl_ud_clause is not null then 
                 insert_dml_part3 := insert_dml_part3 || 
                                     ' where '|| l_tbl_ud_clause;
                end if;  
                insert_dml_part3 := insert_dml_part3 || 
                                   ' union all select  ' ||
                                   'ROWID from "' ||
                                   l_tbl_owner || '"."' || l_tbl_name || '"';
              end if;
            end loop;
            insert_dml_part3 := insert_dml_part3 || 
                                ' subpartition('||
                                node_sub_partitions(node_sub_partitions.count)||
                                ')';
            if l_tbl_ud_clause is not null then 
               insert_dml_part3 := insert_dml_part3 || 
                                   ' where '|| l_tbl_ud_clause;
            end if;  
          end if;  -- if l_tbl_sp_clause not null
        elsif l_tbl_ud_clause is not null then       
          insert_dml_part3  := l_tbl_ud_clause;
        end if; --if l_tbl_p_clause/l_tbl_sp_clause not null
       l_expl_popu := TRUE;
      end if;
    end if;

    if (drv_tbl_id != 0 and drv_tbl_rel = DRV_NODE_PARENT) then
      child_fkey_text := dsg_get_key_txt(l_tbl_keyinfo, 'A');
      parent_pkey_text := dsg_get_key_txt(drv_tbl_keyinfo, 'B');
      parent_pkey_text_plain := dsg_get_key_txt(drv_tbl_keyinfo, null);

      -- build the dml part 3 further
      if insert_dml_part3 is null then
        if drv_tbl_inc_full = 'Y'  and drv_tbl_use_shadow_table = 'N' then
          insert_dml_part3 := '(' || child_fkey_text || ') '|| 
                              'in ( select  distinct ' || 
                              parent_pkey_text || ' from "' || 
                              drv_tbl_owner || '"."' || drv_tbl_name || '" B )';
        elsif drv_tbl_pk_row_tbl is not null then
          insert_dml_part3 := '(' || child_fkey_text || ') '||
                              'in ( select  distinct ' ||
                              parent_pkey_text_plain || ' from "' ||
                              drv_tbl_owner || '"."' || drv_tbl_name ||
                              '" where (' || drv_tbl_pkey_txt_plain || ') ' || 
                              ' in (select * from ' || 
                              '"' || dsg_owner || '"' || '.' || 
                              drv_tbl_pk_row_tbl || ' ) )';
        else
          insert_dml_part1 := insert_dml_part1 || ',' ||
                           '( select  distinct C.' ||
                           parent_pkey_text_plain || ' from "' ||
                           drv_tbl_owner || '"."' || drv_tbl_name || '" C, ' ||
                           '"' || dsg_owner || '"' || '.' ||
                           drv_tbl_row_id_tbl || drv_tbl_id || ' D ' ||
                           ' where C.ROWID=D.ROW_ID ) B';

          for i in 1..l_tbl_keyinfo.count
          loop
            if i = 1 then
              insert_dml_part3 := 'A.' || l_tbl_keyinfo(i) ||
                                 ' = B.' || drv_tbl_keyinfo(i) ;
            else
              insert_dml_part3 := insert_dml_part3 || 
                                  ' and ' ||
                                  'A.' || l_tbl_keyinfo(i) || 
                                  ' = B.' || drv_tbl_keyinfo(i);
            end if;
          end loop;
        end if;
      else
        if drv_tbl_inc_full = 'Y'  and drv_tbl_use_shadow_table = 'N' then
          insert_dml_part3 := '(' || child_fkey_text || ') ' || 
                              ' in ( select  distinct ' ||
                              parent_pkey_text || ' from "' ||
                              drv_tbl_owner || '"."' || drv_tbl_name || '" B )';
        elsif drv_tbl_pk_row_tbl is not null then
          insert_dml_part3 := '( ' || insert_dml_part3 || 
                              ' OR ( ' || child_fkey_text || ' ) ' || 
                              ' in ( select  distinct ' || 
                              parent_pkey_text_plain || ' from "'  || 
                              drv_tbl_owner || '"."' || drv_tbl_name || 
                              '" where (' || drv_tbl_pkey_txt_plain || ') ' || 
                              ' in (select * from ' ||
                              '"' || dsg_owner || '"' || '.' || 
                              drv_tbl_pk_row_tbl || ' ) ) )';
        else
          insert_dml_part1 := insert_dml_part1 || ','|| 
                            '( select  distinct C.' ||
                            parent_pkey_text_plain || ' from "' ||
                            drv_tbl_owner || '"."' || drv_tbl_name || '" C, ' || 
                            '"' || dsg_owner || '"' || '.' ||
                            drv_tbl_row_id_tbl || drv_tbl_id || ' D ' || 
                            'where C.ROWID=D.ROW_ID) B ' ;
          for i in 1..l_tbl_keyinfo.count
          loop
            if i = 1 then
              insert_dml_part3_2 := 'A.' || l_tbl_keyinfo(i) ||
                                   '=B.' || drv_tbl_keyinfo(i);
            else
              insert_dml_part3_2 := insert_dml_part3 || ' and ' ||
                                    'A.' || l_tbl_keyinfo(i) || 
                                    ' = B.' || drv_tbl_keyinfo(i) ;
            end if;
          end loop;
          insert_dml_part3 := '( ' || insert_dml_part3 || ' OR ( ' ||
                               insert_dml_part3_2 || ' ) )';
        end if;
      end if;
    elsif (drv_tbl_id != 0 and drv_tbl_rel = DRV_NODE_CHILD) then
    --adding table to the list of tables processed as a parent
      dsg_processed_tables(l_tbl_owner || '.' || l_tbl_name) := 'Y';
      child_fkey_text := dsg_get_key_txt(drv_tbl_keyinfo, 'B');
      child_fkey_text_plain := dsg_get_key_txt(drv_tbl_keyinfo, null);
      parent_pkey_text := dsg_get_key_txt(l_tbl_keyinfo, 'A');

      -- build the dml part 3 further
      if insert_dml_part3 is null then
        if drv_tbl_inc_full = 'Y'  and drv_tbl_use_shadow_table = 'N' then
          insert_dml_part3 := '(' || parent_pkey_text ||  ') ' || 
                             'in ( select  distinct ' ||
                             child_fkey_text || ' from "' || 
                             drv_tbl_owner || '"."' || drv_tbl_name || '" B ) ';
        elsif drv_tbl_pk_row_tbl is not null then
          insert_dml_part3 := '(' || parent_pkey_text || ') '|| 
                              ' in ( select  distinct ' || 
                              child_fkey_text_plain || ' from "' || 
                              drv_tbl_owner || '"."' || drv_tbl_name || 
                              '" where ' || 
                              '(' || drv_tbl_pkey_txt_plain || ') ' || 
                              ' in (select  * from ' ||
                              '"' || dsg_owner || '"'  || '.' ||
                              drv_tbl_pk_row_tbl || ') )';
        else
	  insert_dml_part1 := insert_dml_part1 || ','  ||
                           '( select  distinct C.'  ||
                           child_fkey_text_plain || ' from "' ||
                           drv_tbl_owner || '"."' || drv_tbl_name || '" C, ' ||
                           '"' || dsg_owner || '"' || '.' ||
                           drv_tbl_row_id_tbl || drv_tbl_id || ' D ' ||
                           'where C.ROWID = D.ROW_ID ) B ';

          -- build dml part3
          for i in 1..l_tbl_keyinfo.count
          loop
            if i = 1 then
              insert_dml_part3 := 'A.' || l_tbl_keyinfo(i) ||
                                 '=B.' || drv_tbl_keyinfo(i) ;
            else
              insert_dml_part3 := insert_dml_part3 || ' and ' ||
                                  'A.' || l_tbl_keyinfo(i) || 
                                  ' = B.' || drv_tbl_keyinfo(i);
            end if;
          end loop;
        end if;
      else 
        if drv_tbl_inc_full = 'Y'  and drv_tbl_use_shadow_table = 'N' then
          insert_dml_part3 := '( ' || insert_dml_part3 || 
                              ' OR ( ' || parent_pkey_text || ' ) ' || 
                              ' in ( select  distinct ' ||
                              child_fkey_text || ' from "' ||
                              drv_tbl_owner || '"."' ||
                              drv_tbl_name || '" B ) )';
        elsif drv_tbl_pk_row_tbl is not null then
          insert_dml_part3 := '( ' || insert_dml_part3 || 
                              ' OR ( ' || parent_pkey_text || ' ) ' || 
                              ' in ( select  distinct' ||
                              child_fkey_text_plain || ' from "' ||
                              drv_tbl_owner || '"."' || drv_tbl_name ||
                              '" where ' ||
                              '(' || drv_tbl_pkey_txt_plain || ') '|| 
                              ' in (select  * from ' ||
                              '"' || dsg_owner || '"' || '.' || 
                              drv_tbl_pk_row_tbl || ' ) ) )';
        else
          insert_dml_part1 := insert_dml_part1 || ',' || 
                           '( select  distinct C.' ||
                           child_fkey_text_plain || ' from "' ||
                           drv_tbl_owner || '"."' || drv_tbl_name || '" C, ' ||
                           '"' || dsg_owner || '"' || '.' ||
                           drv_tbl_row_id_tbl || drv_tbl_id || ' D ' ||
                           'where C.ROWID = D.ROW_ID ) B ';

          -- build dml part3
          for i in 1..l_tbl_keyinfo.count
          loop
            if i = 1 then
              insert_dml_part3_2 := 'A.' || l_tbl_keyinfo(i) ||
                                    ' = B.' || drv_tbl_keyinfo(i);
            else
              insert_dml_part3_2 := insert_dml_part3 || ' and ' ||
                                    'A.' || l_tbl_keyinfo(i) || 
                                    ' = B.' || drv_tbl_keyinfo(i) ;
            end if;
          end loop;
          insert_dml_part3 := '( ' || insert_dml_part3 || ' OR ( ' ||
                               insert_dml_part3_2 || ' ) )';
        end if;
      end if;
    end if;
    
    -- build the dml part 4 (to skip the duplicates)
    if l_tbl_act_num_rows != 0 then
      if l_tbl_pk_row_tbl is not null then
        insert_dml_part4 := ' AND ( ' || l_tbl_pkey_text || ' ) not in ' ||
                              ' ( select * from ' ||
                              '"' || dsg_owner || '"' || '.' || 
                              l_tbl_pk_row_tbl || ' )';
      else
        if depth = 0 then
	  insert_dml_part4 := ' AND ( ROWID ) ';
	else
	  insert_dml_part4 := ' AND ( A.ROWID ) ';
	end if;
	insert_dml_part4 := insert_dml_part4 ||
			    ' not in ( select ROW_ID from ' ||
			    '"' || dsg_owner || '"' || '.' || 
                            l_tbl_row_id_tbl || l_tbl_id || ' )';
      end if;
    else
      insert_dml_part4 := null;
    end if;

    -- restrict the rows (only in some cases: parent driving children)
    if (l_tbl_act_num_rows <= l_tbl_max_num_rows and
        l_tbl_max_num_rows != 0 and
          drv_tbl_rel != DRV_NODE_CHILD) then
        max_rows := l_tbl_max_num_rows - l_tbl_act_num_rows + 1;
        if depth = 0 then
	  insert_dml_part4 := insert_dml_part4 || ' AND ROWNUM ';
	else
	  insert_dml_part4 := insert_dml_part4 || ' AND A.ROWNUM ';
	end if;
	insert_dml_part4 := insert_dml_part4 || ' < ' || max_rows;
    end if;


    final_insert_dml := insert_dml_part1 || insert_dml_part2 || 
                        insert_dml_part3 || insert_dml_part4;

    dsg_put_trace(dsm_id, tgt_id, 'COMPUTE SUBSET', 'INSERT DML', 
                  final_insert_dml, DSG_DEBUG);
    -- fire the dml
    begin
         dsg_add_to_sql_tbl(l_sql_table,final_insert_dml);
         l_ds_cursor := DBMS_SQL.OPEN_CURSOR;
         DBMS_SQL.PARSE(l_ds_cursor,
                        l_sql_table,
                        l_sql_table.FIRST,
                        l_sql_table.LAST,
                        FALSE,
                        DBMS_SQL.NATIVE);
         l_ret_val := DBMS_SQL.EXECUTE(l_ds_cursor);
         DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
         l_sql_table.DELETE;
         row_count := l_ret_val;
    exception
      when others then
        dsg_put_trace(dsm_id,tgt_id , '', '', sqlerrm(sqlcode), DSG_ERROR);
        DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
        l_sql_table.DELETE;
    end;
      --adding commit here for tpch
      commit;
      execute immediate  'alter system checkpoint';
    dsg_put_trace(dsm_id, tgt_id, 'COMPUTE SUBSET', '', 
                  'rows added: '|| row_count, DSG_INFO);

    -- update the NODE table
    if row_count != 0 then
      qt_command := ' update ' || '"' || dsg_owner || '"' || '.' ||
                    dsg_node_tbl_name || 
                    ' set ACT_NUM_ROWS = ACT_NUM_ROWS + :1, ' || 
                    ' IS_ACTIVE = :2, USE_SHADOW_TBL = :3' ||
                    ' where TABLE_ID = :4';
      execute immediate qt_command using row_count, 'Y', 'Y', l_tbl_id;
      
      --update shadow table stats if rows inserted
      if l_tbl_pk_row_tbl is not null then
        dsg_update_shadow_tbl_stats(l_tbl_pk_row_tbl);     
      else 
        dsg_update_shadow_tbl_stats(dsg_row_id_tbl_name || l_tbl_id);
      end if;

      got_some_rows := TRUE;
    end if;
   end if; -- end if l_tbl_inc_full != 'Y' or use_shadow_table = TRUE
  else -- else of if dsg_use_shadow_tbl_global = true
   if l_tbl_inc_full != 'Y' then
    if l_tbl_is_ud_rule = 'Y' then
        -- partition or subpartition clause
        if l_tbl_p_clause is not null or l_tbl_sp_clause is not null then
          if l_tbl_p_clause is not null then
            for i in node_partitions.first .. node_partitions.last loop
               query := 'select  count(*) from "' ||
                        l_tbl_owner || '"."' || l_tbl_name ||
                        '" partition('||node_partitions(i)||')';
               if l_tbl_ud_clause is not null then 
                 query := query ||' where '||l_tbl_ud_clause;
               end if;
               begin
                  dsg_add_to_sql_tbl(l_sql_table,query);
                  l_ds_cursor := DBMS_SQL.OPEN_CURSOR;
                  DBMS_SQL.PARSE(l_ds_cursor,
                                 l_sql_table,
                                 l_sql_table.FIRST,
                                 l_sql_table.LAST,
                                 FALSE,
                                 DBMS_SQL.NATIVE);
                  -- Bug #23575590 - ORA-01007 when subsetting based on partitions/subpartitions
                  -- without ancestors and descendants
                  DBMS_SQL.DEFINE_COLUMN(l_ds_cursor, 1, row_count_1);
                  l_ret_val := DBMS_SQL.EXECUTE(l_ds_cursor);
                  l_ret_val := DBMS_SQL.FETCH_ROWS(l_ds_cursor);
                  DBMS_SQL.COLUMN_VALUE(l_ds_cursor, 1, row_count_1);
                  DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
                  l_sql_table.DELETE;
               exception
                  when others then       
	             dsg_put_trace(dsm_id, tgt_id, '', '', 
                                   sqlerrm(sqlcode), DSG_ERROR);
                  DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
                  l_sql_table.DELETE;
               end;
            
               row_count := row_count + row_count_1;
            end loop;
          end if;  
          if l_tbl_sp_clause is not null then 
            for i in node_sub_partitions.first .. node_sub_partitions.last loop
               query := 'select  count(*) from "' ||
                        l_tbl_owner || '"."' || l_tbl_name ||
                        '" subpartition('||node_sub_partitions(i)||')';
               if l_tbl_ud_clause is not null then 
                 query := query ||' where '||l_tbl_ud_clause;
               end if;
               begin
                  dsg_add_to_sql_tbl(l_sql_table,query);
                  l_ds_cursor := DBMS_SQL.OPEN_CURSOR;
                  DBMS_SQL.PARSE(l_ds_cursor,
                                 l_sql_table,
                                 l_sql_table.FIRST,
                                 l_sql_table.LAST,
                                 FALSE,
                                 DBMS_SQL.NATIVE);
                  -- Bug #23575590 - ORA-01007 when subsetting based on partitions/subpartitions
                  -- without ancestors and descendants
                  DBMS_SQL.DEFINE_COLUMN(l_ds_cursor, 1, row_count_1);
                  l_ret_val := DBMS_SQL.EXECUTE(l_ds_cursor);
                  l_ret_val := DBMS_SQL.FETCH_ROWS(l_ds_cursor);
                  DBMS_SQL.COLUMN_VALUE(l_ds_cursor, 1, row_count_1);
                  DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
                  l_sql_table.DELETE;
               exception
                  when others then       
	             dsg_put_trace(dsm_id,tgt_id, '', '', 
                                   sqlerrm(sqlcode), DSG_ERROR);
                  DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
                  l_sql_table.DELETE;
               end;

               row_count := row_count + row_count_1;
            end loop;
          end if; 
        else --bug#20099726: where clause or some rows
          execute immediate 'select  count(*) from "' ||
	            	  l_tbl_owner || '"."' || l_tbl_name ||
	          	  '" where ' || l_tbl_ud_clause
	          	  into row_count;
        end if;
      end if;  
    dsg_put_trace(dsm_id, tgt_id, 'COMPUTE SUBSET', '', 
                  'rows added: '|| row_count, DSG_INFO);

    -- update the NODE table
    if row_count != 0 then
      qt_command := ' update ' || '"' || dsg_owner || '"' || '.' || 
                    dsg_node_tbl_name ||
                    ' set ACT_NUM_ROWS = ACT_NUM_ROWS + :1' ||
                    ' , IS_ACTIVE = :2, USE_SHADOW_TBL = :3' ||
                    ' where TABLE_ID = :4';
      execute immediate qt_command using row_count, 'Y', 'Y', l_tbl_id;
      got_some_rows := TRUE;
    end if;
    --commit..?? TBD
   end if; -- end if l_tbl_inc_full != 'Y' 
  end if;  -- end if dsg_use_shadow_tbl_global = true
  if l_tbl_inc_full = 'Y' then
    if drv_tbl_id = 0 then
      if l_tbl_src_num_rows = 0
      then
        dsg_check_tbl_data(l_tbl_id);
      end if;
      qt_command := ' update ' || '"' || dsg_owner || '"' || '.' ||
                    dsg_node_tbl_name ||
                    ' set ACT_NUM_ROWS = SRC_NUM_ROWS ' ||
                    ' , IS_ACTIVE = :1, USE_SHADOW_TBL = :2' ||
                    ' where TABLE_ID = :3';
      execute immediate qt_command using 'Y', 'N', l_tbl_id;
      got_some_rows := TRUE;
    end if;
  end if; -- end if l_tbl_inc_full = 'Y'

  begin
    commit;
  end;

  -- process the parents and children
  if got_some_rows = TRUE then

    if drv_tbl_id = 0 then
      if l_tbl_pull_parents = 'Y' then
        is_pp := TRUE;
      end if;
    else
      if pull_parents = 'Y' then
        is_pp := TRUE;
      end if;
    end if;

    if is_pp = TRUE then
      -- go through parent edges and balance them
     qt_command := ' select EDGE_ID, PRI_AS_NAME, PRI_SCH_NAME, ' || 
                  ' PRI_TABLE_NAME from ' || 
                  '"' || dsg_owner || '"' || '.' || dsg_edge_tbl_name ||
                  ' where REF_AS_NAME = :1 and  REF_SCH_NAME = :2' ||
                  ' and   REF_TABLE_NAME  = :3 ' ||
                  ' and EDGE_ID not in ' ||
                  ' (select EDGE_ID ' ||
                  ' from "' ||
                  dsg_owner || '".' || dsg_se_tbl_name ||
                  ' where RULE_ID = :4 ' ||
                  ' and PROCESSING_TYPE = 1)' ||
                  ' order by pri_sch_name, pri_table_name';

      open parent_cursor for qt_command
      using l_tbl_as_name, l_tbl_owner, l_tbl_name, dsg_rule_id;
      LOOP
      FETCH parent_cursor
      into p_edge_id, p_edge_as_name , p_edge_sch_name, p_edge_tbl_name;

      -- exit loop when last row is fetched
      EXIT WHEN parent_cursor%NOTFOUND;

      qt_command := ' select TABLE_ID from ' || 
                    '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
                    ' where APPL_SHORT_NAME = :1 and SCHEMA_NAME = :2' ||
                    ' and TABLE_NAME = :3';
      
      execute immediate qt_command
      into p_edge_table_id
      using p_edge_as_name, p_edge_sch_name, p_edge_tbl_name;

      -- reset print_info
      print_info := null;

      if ( not(l_expl_popu = FALSE and
           drv_tbl_rel = DRV_NODE_PARENT and
           p_edge_table_id = drv_tbl_id)) then
        if drv_tbl_id = 0 then
          for i in 0..depth
          loop
            print_info := print_info || '---|';
          end loop;
          dsg_put_trace(dsm_id,
                        tgt_id,
                        'COMPUTE SUBSET',
                        'PROCESS PARENT',
                        print_info || 
                        'parent: ' || p_edge_sch_name || '.' || p_edge_tbl_name,
                        DSG_INFO);


          dsg_internal_process_node(dsm_id, tgt_id, p_edge_table_id,
                                    pr_other_ucs, l_tbl_id, DRV_NODE_CHILD, 
                                    p_edge_id, depth+1, 
                                    l_tbl_pull_parents, l_tbl_pull_children);
        else
          for i in 0..depth
          loop
            print_info := print_info || '---|';
          end loop;
          dsg_put_trace(dsm_id,
                        tgt_id,
                        'COMPUTE SUBSET',
                        'PROCESS PARENT',
                        print_info || 
                        'parent: ' || p_edge_sch_name || '.' || p_edge_tbl_name,
                        DSG_INFO);
          dsg_internal_process_node(dsm_id, tgt_id, p_edge_table_id,
                                    pr_other_ucs, l_tbl_id, DRV_NODE_CHILD, 
                                    p_edge_id, depth+1, 
                                    pull_parents, pull_children);
        end if;
      else
	dsg_put_trace(dsm_id, tgt_id, 'COMPUTE SUBSET', 'SKIP PARENT BALANCES',
			   'skipping the parent balances for :' ||
                           l_tbl_owner || ',' || l_tbl_name || '-----' ||
                           p_edge_sch_name || ',' || p_edge_tbl_name, DSG_INFO);
      end if;

      END LOOP;
      if (parent_cursor%isopen) then
        close parent_cursor;
      end if;
    end if;
  end if; -- got some rows parent process

  -- checking if extra children have to be included.
  -- additional descendants can only be added on a table
  --   if child processing never happens on the table.
  -- in that case the sql to get edges will be modified
  --   to get only those edges that are there in spl_edges table.
  -- And internal processing method will be called for the new edge
  --   after setting the pull children flag to false.
  qry_spl_edges := 'select count(e.edge_id) ' ||
                   'from "' || 
                   dsg_owner || '".' || dsg_edge_tbl_name || ' e, ' ||
                   ' "' || dsg_owner || '".' || dsg_se_tbl_name || ' se ' ||
                   'where e.edge_id = se.edge_id ' ||
                   ' and e.pri_as_name = :1 ' ||
                   ' and e.pri_sch_name = :2 ' ||
                   ' and e.pri_table_name = :3 ' ||
                   ' and se.rule_id = :4 ' ||
                   ' and se.processing_type = 2 ' ||
                   ' and rownum < 2';
  execute immediate qry_spl_edges
                  into spl_edges_num
                  using l_tbl_as_name,
                        l_tbl_owner,
                        l_tbl_name,
                        dsg_rule_id;
  if got_some_rows = TRUE OR 
     dsg_table_processed_as_parent(l_tbl_owner, l_tbl_name) then

    if drv_tbl_id = 0 then
      if l_tbl_pull_children = 'Y' then
        is_pc := TRUE;
      end if;
	else
      if pull_children = 'Y' then
        is_pc := TRUE;
      end if;
    end if;

    if (is_pc = TRUE and
       ((drv_tbl_rel = DRV_NODE_PARENT or drv_tbl_rel is null) or 
        (dsg_get_global_rule = TRUE and drv_tbl_rel = DRV_NODE_CHILD)))
        or spl_edges_num > 0 then
      dsg_processed_tables.delete(l_tbl_owner || '.' || l_tbl_name);

      -- go through parent edges and balance them
     qt_command := ' select EDGE_ID, REF_AS_NAME, REF_SCH_NAME, ' || 
                   '        REF_TABLE_NAME from ' ||
                   '"' || dsg_owner || '"' || '.' || dsg_edge_tbl_name ||
                   ' where PRI_AS_NAME = :1 and  PRI_SCH_NAME = :2' ||
                   ' and   PRI_TABLE_NAME  = :3 ' ||
                   ' and EDGE_ID not in ' ||
                   ' (select EDGE_ID ' ||
                   '    from "' ||
                   dsg_owner || '".' || dsg_se_tbl_name ||
                   ' where RULE_ID = :4 ' ||
                   ' and PROCESSING_TYPE = 1) ' ||
                   ' order by ref_sch_name, ref_table_name';

      if spl_edges_num > 0
      then
        qt_command := 'select e.edge_id, ' ||
                      '       e.ref_as_name, ' ||
                      '       e.ref_sch_name, ' ||
                      '       e.ref_table_name ' ||
                      'from "' || 
                      dsg_owner || '".' || dsg_edge_tbl_name || ' e, ' ||
                      ' "' || dsg_owner || '".' || dsg_se_tbl_name || ' se ' ||
                      'where e.edge_id = se.edge_id ' ||
                      '  and e.pri_as_name = :1 ' ||
                      '  and e.pri_sch_name = :2 ' ||
                      '  and e.pri_table_name = :3 ' ||
                      '  and se.rule_id = :4 ' ||
                      '  and se.processing_type = 2'; 
      end if;
      open child_cursor for qt_command
      using l_tbl_as_name, l_tbl_owner, l_tbl_name, dsg_rule_id;
      LOOP
      FETCH child_cursor
      into c_edge_id, c_edge_as_name , c_edge_sch_name, c_edge_tbl_name;
      -- exit loop when last row is fetched
      EXIT WHEN child_cursor%NOTFOUND OR child_cursor%NOTFOUND IS NULL;

      qt_command := ' select IS_SELECTED from ' || 
                    '"' || dsg_owner || '"' || '.' || dsg_app_tbl_name ||
                    ' where APPL_SHORT_NAME = :1';
      execute immediate qt_command
      into is_selected_app
      using c_edge_as_name;

      qt_command := 'select IS_INCLUDE_ALL from ' ||
		    '"' || dsg_owner || '"' || '.' || dsg_app_tbl_name ||
		    ' where APPL_SHORT_NAME = :1';

      execute immediate qt_command
      into is_bulk_rule
      using l_tbl_as_name;

      qt_command := ' select TABLE_ID from ' || 
                    '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
                    ' where APPL_SHORT_NAME = :1 and SCHEMA_NAME = :2' ||
                    ' and TABLE_NAME = :3';

      execute immediate qt_command
      into c_edge_table_id
      using c_edge_as_name, c_edge_sch_name, c_edge_tbl_name;

      -- reset print_info
      print_info := null;

      -- one can't be a child to it self ( it can be parent !!)
      if c_edge_table_id != l_tbl_id  and is_selected_app = 'Y' then
        if drv_tbl_id = 0 then
          for i in 0..depth
          loop
            print_info := print_info || '---|';
          end loop;
          dsg_put_trace(dsm_id,
                        tgt_id,
                        'COMPUTE SUBSET',
                        'PROCESS CHILD',
                        print_info || 
                        'child: ' || c_edge_sch_name || '.' || c_edge_tbl_name,
                        DSG_INFO);
          dsg_internal_process_node(dsm_id, tgt_id, c_edge_table_id,
                                    pr_other_ucs, l_tbl_id, DRV_NODE_PARENT, 
                                    c_edge_id, depth+1, 
                                    l_tbl_pull_parents, l_tbl_pull_children);
        else
         if (c_edge_table_id != drv_tbl_id or dsg_get_global_rule = FALSE) then
          for i in 0..depth
          loop
            print_info := print_info || '---|';
          end loop;
          dsg_put_trace(dsm_id,
                        tgt_id,
                        'COMPUTE SUBSET',
                        'PROCESS CHILD',
                        print_info || 
                        'child: ' || c_edge_sch_name || '.' || c_edge_tbl_name,
                        DSG_INFO);
          dsg_internal_process_node(dsm_id, tgt_id, c_edge_table_id,
                                    pr_other_ucs, l_tbl_id, DRV_NODE_PARENT, 
                                    c_edge_id, depth+1, 
                                    pull_parents, pull_children);
         end if;
        end if;
      end if;

      END LOOP;
      if (child_cursor%isopen) then
        close child_cursor;
      end if;
    end if;

  end if; -- got some rows..??

end dsg_internal_process_node;

--    PROCEDURE DSG_PROCESS_NODE
--    PURPOSE: Process node for the subset consumption 
--    PARAMETERS:
--         DSM_ID       : subset model id
--         TGT_ID       : Target id
--         AS_NAME      : Application  short name
--         TABLE_NAME   : Table Name
--
--    RETURNS:
--         NONE
--
procedure dsg_process_node ( dsm_id      integer,
                             tgt_id      raw,
                             as_name     varchar2,
                             table_name  varchar2 )
is
  l_tbl_id           number := 0;
  qt_command         varchar2(32767);
  pr_other_ucs       boolean := FALSE;
begin

  qt_command := ' select TABLE_ID from ' || 
                '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
                ' where DSM_ID = :1 AND TGT_ID = :2' || 
                ' AND APPL_SHORT_NAME = :3 AND TABLE_NAME = :4';

  execute immediate qt_command
  into l_tbl_id
  using dsm_id, tgt_id, as_name, table_name;

  dsg_internal_process_node (dsm_id, tgt_id, l_tbl_id, pr_other_ucs,
                             0, null, 0, 0, null, null);

  -- set the rule processed flag
  qt_command := ' update ' || 
                '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
                ' set IS_RULE_PROCESSED = :1 where TABLE_ID = :2';
  execute immediate qt_command using 'Y', l_tbl_id;

end dsg_process_node;

--    PROCEDURE DSG_COMPUTE_SUBSET
--    PURPOSE:  compute the subset
--              process every table for which user defined a rule 
--              we track subset content in shadow tables either in the form of RIDs
--              primary keys of the tables
--    PARAMETERS:
--         DSM_ID       : subset model id
--         TGT_ID       : Target id
--
--    RETURNS:
--         NONE
--
procedure dsg_compute_subset
is
  qt_command         varchar2(32767);
  qt_command_node    varchar2(32767);
  query_get_rule_id  varchar2(32767);
  l_dsg_app_tbl      varchar2(30);
  l_dsg_node_tbl     varchar2(30);
  l_dsg_impt_tbl     varchar2(30);
  l_dsg_edge_tbl     varchar2(30);
  l_dsg_kc_tbl       varchar2(30);
  l_dsg_edgeid_seq   varchar2(30);
  l_dsg_keyid_seq    varchar2(30);
  l_is_selected_app  varchar2(1);
  l_is_include_all   varchar2(1) := null;
  l_rule_id          number := 0;
  query_rs           number := 0;
  dsg_app_cursor     sys_refcursor;
  dsg_node_cursor    sys_refcursor;
  table_name         varchar2(128);
  TYPE ARRAY is table of varchar2(128);
  a_table_name ARRAY;
  as_name            varchar2(128);
  dsm_id	     integer;
  tgt_id	     raw(16);
  loop_count	     integer := 1;
begin
  dsm_id := dsg_get_dsm_id;
  tgt_id := dsg_get_tgt_id;
  dsg_checkpoint(dsm_id, tgt_id, 'COMPUTE SUBSET', '', '', '', '', 
		'Beginning subset computation', ''); 
  -- open app cursor for selected applications
  qt_command := ' select APPL_SHORT_NAME from ' || 
                '"' || dsg_owner || '"' || '.' || dsg_app_tbl_name ||
                ' where  DSM_ID = :1 and TGT_ID= :2' || 
		' and IS_SELECTED = :3';

  OPEN dsg_app_cursor for qt_command using dsm_id, tgt_id, 'Y';
  
  LOOP
    fetch dsg_app_cursor into as_name;
    EXIT WHEN dsg_app_cursor%NOTFOUND;
    -- for each selected application go through all the nodes for which
    -- there are user defined rules OR to be included fully to process the table
    qt_command_node := ' select TABLE_NAME from ' ||
               '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
               ' where APPL_SHORT_NAME = :1 AND ' ||
               ' ( IS_INCLUDE_ALL = :2 OR IS_UD_RULE = :3 )' ||
     	       ' AND IS_RULE_PROCESSED = :4 order by appl_short_name, table_name';
    
    OPEN dsg_node_cursor for qt_command_node using as_name, 'Y', 'Y', 'N';
    fetch dsg_node_cursor bulk collect into a_table_name;
    if (dsg_node_cursor%isopen) then
      close dsg_node_cursor;
    end if;
    for indx in nvl(a_table_name.first, 1)..nvl(a_table_name.last, 0) LOOP
      query_get_rule_id := ' select RULE_ID ' ||
                          '  from ' || 
                          '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
                          ' where APPL_SHORT_NAME = :1 ' ||
                          '   and TABLE_NAME = :2 ' ||
                          '   and DSM_ID = :3 ' ||
                          '   and TGT_ID = :4';
      execute immediate query_get_rule_id
                           into dsg_rule_id
                           using as_name,
                                 a_table_name(indx),
                                 dsm_id,
                                 tgt_id;
    -- get rule_id here and then go in to internal_process_node and add code to skip edges  
     -- fetch dsg_node_cursor into table_name;
     -- EXIT WHEN dsg_node_cursor%NOTFOUND;
      dsg_checkpoint(dsm_id, tgt_id, 'COMPUTE SUBSET', '', 
                     as_name, a_table_name(indx), '', 
  		     'Beginning subset computation for table ' || 
                     as_name || '.' || a_table_name(indx), ''); 
      dsg_put_trace(dsm_id, tgt_id, 'COMPUTE SUBSET', '', 
                    'table:'||as_name||'.'||a_table_name(indx), 
                    DSG_INFO);
      dsg_process_node (dsm_id, tgt_id, as_name, a_table_name(indx));
      dsg_checkpoint(dsm_id, tgt_id, 'COMPUTE SUBSET', '', 
                     as_name, a_table_name(indx), '',
   		     'Subset computation for table ' || 
                     as_name || '.' || a_table_name(indx) || ' complete', '');
      dsg_rule_id := -1;
      commit;
    END LOOP;
  END LOOP;

  if (dsg_app_cursor%isopen) then
    close dsg_app_cursor;
  end if;
  commit;
end dsg_compute_subset;

procedure dsg_delete_dump_file (dump_name varchar2)
is
  is_present boolean;
  file_length number;
  block_size number;
  temp varchar2(255);
  ind number;
  dump_dir varchar2(100);
  log_name varchar2(200);
begin
  log_name := dsg_get_export_log;
  dump_dir := dsg_get_export_dir;
  ind := instr(dump_name, '%U');
  if ind <> 0 then
    for i in 1..99 loop
      temp := replace(dump_name, '%U', trim(to_char(i, '09')));
      utl_file.fgetattr(dump_dir, temp, is_present, file_length, block_size);
      if is_present then
        utl_file.fremove(dump_dir, temp);
      end if;
    end loop;
  else
    utl_file.fgetattr(dump_dir, dump_name, is_present, file_length, block_size);
    if is_present then
      utl_file.fremove(dump_dir, dump_name);
    end if;
  end if;
  utl_file.fgetattr(dump_dir, log_name, is_present, file_length, block_size);
  if is_present then
    utl_file.fremove(dump_dir, log_name);
  end if;
end dsg_delete_dump_file;

procedure dsg_delete_old_dump
is
  dump_name varchar2(255);
  l_index pls_integer := 1;
  l_comma_index  pls_integer;

begin
  dump_name := dsg_get_export_dumpfile;

  if instr(dump_name, ',') <> 0 then
     dump_name := replace(rtrim(dump_name,','),' ','');
     loop
        l_comma_index := instr( dump_name||',' , ',' , l_index);
        exit when l_comma_index = 0;
        dsg_delete_dump_file(substr(dump_name, l_index, l_comma_index - l_index));
        l_index := l_comma_index + 1;
     end loop;
  else
     dsg_delete_dump_file(dump_name);
  end if;

end dsg_delete_old_dump;

procedure dsg_exec_export ( dsm_id	integer,
			    tgt_id	raw)
is
  type cursor is REF CURSOR;
  c1 cursor;
  
  --handle number
  h number;
  
  --job status variables
  job_state VARCHAR2(30);
  le ku$_LogEntry;
  sts ku$_Status;
  ind NUMBER;
    
  t_date varchar2(20);
  dump_name varchar2(255);
  log_name varchar2(200);
  dump_dir varchar2(100);
  log_dir varchar2(100);  
  custom_dir_path varchar2(4000);
  dump_size varchar2(10);
  table_list varchar2(32767) := '''';
  len number;
  query varchar2(32767);
  kt_info keyinfo_t;
  pk_row_text varchar2(32767);
  l_index pls_integer := 1;
  l_comma_index  pls_integer;
  
  --node table columns  
  node_table_id number;
  node_table_name varchar2(128);
  node_schema_name varchar2(128);
  node_pkey_cname varchar2(128);
  node_pk_row_tbl varchar2(30);
  node_is_include_all varchar2(1);
  node_is_iot_table varchar2(1);
  node_ud_clause varchar2(4000);
  node_p_clause  clob;
  node_sp_clause  clob;
  part_names clob;
  node_partitions dsg_part_table_array := dsg_part_table_array();
  node_sub_partitions dsg_part_table_array := dsg_part_table_array();
  no_of_tbls number;
  node_act_num_rows number;
  dsg_owner_for_data_filter varchar2(138);

  --variables for doin inline mask
  sql_get_mask_col varchar2(32767);
  sql_get_mask_tr_tbl varchar2(32767);
  sql_data_remap_call varchar2(32767);
  sql_get_dm_isdm varchar2(32767); --sql for getting deterministic masking count
  map_column_name varchar2(128);
  map_func_name varchar2(100);
  map_tbl_id number;
  map_rule_type number;
  map_is_dm varchar2(1);
  map_truncate_table number;
  map_table_missing boolean := false;
  mask_col_cursor sys_refcursor;
  do_data_remap boolean;
  dm_count number := 0;
  seed number; -- encrypt seed value
  map_pass_rid varchar2(1);
  data_remap_flg number := 0;

  --variables for putting filter on schema tables not in adm
  sql_excluded_tbl_list varchar2(32767);
  cursor_excluded_tbl_list sys_refcursor;
  excluded_tbl_owner varchar2(128);
  excluded_tbl_name varchar2(128);

BEGIN
  execute immediate 'select count(*) from ' || 
                    '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name || 
                    ' where ACT_NUM_ROWS != 0 and DSM_ID = :1' 
                    into no_of_tbls using dsm_id;
  if no_of_tbls = 0 then
    dsg_put_trace(dsm_id, tgt_id, 'EXPORT', '', 
                  'No tables selected in the subset', DSG_INFO);
    return;
  end if;

--deleting old dump files
  dsg_delete_old_dump;  

--opening a new datapump handle for the job
if dsg_export_type = DSG_EXPORT_OPTION_SUBSET_ONLY then
  h := dbms_datapump.open('EXPORT','SCHEMA',NULL, NULL,'COMPATIBLE');
elsif dsg_export_type = DSG_EXPORT_OPTION_FULL then
  h := dbms_datapump.open('EXPORT','FULL',NULL, NULL,'COMPATIBLE');
end if;  
  --setting dumpfile and log files
  dump_name := dsg_get_export_dumpfile;
  dump_dir := dsg_get_export_dir;
  log_name := dsg_get_export_log;
  log_dir := dsg_get_export_log_dir;
  dump_size := dsg_get_dump_size;

  -- Fix Bug 17410148 : OS Directory path specified in parameter 
  -- file as custom directory. Use this path to create a DB directory
  -- needed for datapump.
  custom_dir_path := dsg_get_custom_dir_path;

  -- dump_dir would be the name of DB directory we create internally
  -- custom_dir_path is the OS path on which DB directory object will be created
  if custom_dir_path is not null then
    execute immediate 'create or replace directory '||
                      dump_dir||' as '''||custom_dir_path||'''';
  end if;

  --Bug #24788568 - Running datamask on a large data volume 
  --   generates ORA-39095 after 99 dmp files

  if instr(dump_name, ',') <> 0 then
     dump_name := replace(rtrim(dump_name,','),' ','');
     loop
        l_comma_index := instr( dump_name||',' , ',' , l_index);
        exit when l_comma_index = 0;
        dbms_datapump.add_file(h,
                      substr(dump_name, l_index, l_comma_index - l_index),
                      dump_dir,dump_size, DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE);
        l_index := l_comma_index + 1;
     end loop;
  else
      dbms_datapump.add_file(h, dump_name, dump_dir, dump_size,
                                  DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE);
  end if;

  if dsg_get_create_export_log then
    dbms_datapump.add_file(h, log_name, log_dir, NULL, 
                          DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE);
  end if;

  --selecting node table columns
  query := 'select table_id, table_name, runtime_schema_name, pkey_cname,' ||
           ' pk_row_tbl, is_include_all, is_iot_table, runtime_ud_clause' ||
	   ', act_num_rows, pclause, spclause' ||
           ' from '|| '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
	   ' where DSM_ID = :1 and TGT_ID = :2';
  
  --this sql will get the column name and mask info for a particular table
  --except tables with truncate maksing format defined.
  --this is a common table for column rules and masking rules.
  --rule type 1 is from masking, 2 from column rules.
  sql_get_mask_col := 'select column_name, mask_map_table_id, rule_type, ' ||
                      ' is_dm, pass_rid_in_remap from ' || 
                      dsg_mask_map_tbl_name ||
		      ' where schema_name = :1 and table_name = :2 ' ||
		      'and nvl(truncate_table, ''N'') = ''N''';
  --sql to check for truncate mask format
  sql_get_mask_tr_tbl := 'select count(*) from ' ||
		         dsg_mask_map_tbl_name ||
		         ' where schema_name = :1 and table_name = :2 ' ||
			 'and truncate_table = ''Y'' and rule_type = 1 ' ||
			 'and rownum < 2';
 
  if (dsg_get_do_inline_mask or dsg_get_apply_column_rules) then
    do_data_remap := true;
    if dsg_compare_db_version('11') < 0 then
      dsg_put_trace(dsm_id,
                    tgt_id,
                    'EXPORT',
                    'INFO',
                    '#'||chr(13)||chr(10)||
                    '#Warning:'||chr(13)||chr(10)||
                    '#Inline mask not supported on database version < 11,'||
                    chr(13)||chr(10)||
                    '#data will not be masked'||chr(13)||chr(10)||
                    '#',
                    DSG_INFO);
      do_data_remap := false;
    end if;
  end if;

  -- create the DBMS_DSM_DSG_IM_DM package and remap functions
  -- for encrypt format columns
  if dsg_get_do_inline_mask and do_data_remap then
     sql_get_dm_isdm := 'select count(*) from ' || dsg_mask_map_tbl_name
                       || ' where rule_type = 1 '|| ' and is_dm = ''Y''';
     begin 
       execute immediate sql_get_dm_isdm into dm_count;
     exception 
     when others then
       if SQLCODE = -00942 then
         dsg_put_trace(dsm_id,
     	          tgt_id,
     		  'EXPORT',
     		  'ERROR',
     		  'Global mapping table missing, skipping masking',
                       DSG_INFO);
       else
         raise;
       end if;  
     end;

    -- there is atleast one column defined with deterministic masking format
    -- get the seed value from DB_DSG_SEED_TABLE table
    if dm_count > 0 then 
       execute immediate 'select seed from DB_DSG_SEED_TABLE ' into seed;
       --create the DBMS_DSM_DSG_IM_DM package
       dsg_create_im_dm_package(dsm_id, tgt_id, seed);
    end if; 
  end if; -- check for encrypt format    

  open c1 for query using dsm_id, tgt_id;
  loop
    fetch c1 into node_table_id, node_table_name, node_schema_name,
                  node_pkey_cname, node_pk_row_tbl, node_is_include_all,
                  node_is_iot_table, node_ud_clause, node_act_num_rows, 
                  node_p_clause, node_sp_clause;
    exit when c1%notfound;
    --putting the data rempa bits here will also prevent masking rules to be applied
    --to tables with no rows in the subset.
    if node_act_num_rows != 0 then
      map_truncate_table := 0;
      if do_data_remap then
	begin
	  execute immediate sql_get_mask_tr_tbl
		  into map_truncate_table
		  using node_schema_name, node_table_name;
	exception
        when others then
          if SQLCODE = -00942 then
            dsg_put_trace(dsm_id,
		          tgt_id,
			  'EXPORT',
			  'ERROR',
			  'Global mapping table missing, skipping masking',
                          DSG_INFO);
	    map_truncate_table := 0;
	    map_table_missing := true;
          else
            raise;
	  end if;
	end;
      end if; --inline mask or column rule
      --if mask truncate is defined truncate table and ignore subset rows retrieved.
      --this can cause ref relation problems and the user should be aware of it
      if map_truncate_table > 0 then
	dbms_datapump.data_filter(h, 
			    'SUBQUERY',
			    'where 1=2',
			    node_table_name,
			    node_schema_name);
      else
        if node_is_include_all = 'N' then
          if dsg_use_shadow_tbl_global = FALSE then
            if node_ud_clause is not null then       
              dbms_datapump.data_filter(h,'SUBQUERY',
            	                        'where ' || node_ud_clause, 
                                        node_table_name, node_schema_name);
            end if;
            if node_p_clause is not null or node_sp_clause is not null then  
              part_names := 'IN (';
              if node_p_clause is not null then 
                node_partitions := dsg_split_partition_clause(node_p_clause);
                print_part(node_partitions);
                for i in node_partitions.first .. node_partitions.last -1 loop
                  part_names := part_names ||
                                ''''||upper(node_partitions(i))||''''||',';
                end loop; 
                part_names:= part_names ||
                             ''''|| 
                             upper(node_partitions(node_partitions.count))||
                             '''';
                dbms_output.put_line('part_names '||part_names);

                if node_sp_clause is null  then
                   part_names:= part_names  ||')';
                   dbms_datapump.data_filter(h, 'PARTITION_EXPR', part_names);
                else
                   part_names:= part_names || ',';
                end if;   
              end if;  
              if node_sp_clause is not null then 
                node_sub_partitions := 
                          dsg_split_partition_clause(node_sp_clause);
                print_part(node_sub_partitions);
                for i in node_sub_partitions.first .. node_sub_partitions.last-1 
                loop
                  part_names := part_names ||
                                ''''||upper(node_sub_partitions(i))||''''||',';
                end loop; 
                part_names:= part_names ||
                         ''''|| 
                         upper(node_sub_partitions(node_sub_partitions.count))||
                         ''''||')';
                dbms_output.put_line('part_names '||part_names);
                dbms_datapump.data_filter(h, 'PARTITION_EXPR', part_names);
              end if;  
            end if;  
          else
	    --this bit of code will check if db version is less than 11.2
	    --and remove the double qoutes from the dsg owner.
	    --this is done because double quotes in the where clause in 
            -- data_filter causes ORA-06502: PL/SQL: numeric or value error
	    -- and causes datapump export to fail.
	    dsg_owner_for_data_filter := '"' || dsg_owner || '".';
	    if dsg_compare_db_version('11.2') < 0 then
	      if UPPER(dsg_owner) = dsg_owner then
		dsg_owner_for_data_filter := dsg_owner || '.';
	      else
		dsg_owner_for_data_filter := '';
	      end if;
	    end if;
            if node_is_iot_table = 'N' then
        
              --adding a filter on rows depending on rows in row_id table
              dbms_datapump.data_filter(h,'SUBQUERY',
                          'where rowid in ' ||
                          '(select row_id from ' || 
                          dsg_owner_for_data_filter || 
                          dsg_row_id_tbl_name || node_table_id || ')',
                          node_table_name, node_schema_name);
            else
        
              kt_info := dsg_get_keys(node_schema_name,
                                      node_table_name, 
                                      node_pkey_cname);
              pk_row_text := dsg_get_key_txt(kt_info, null);
	      -- same as above double quotes causing problems.
       	      if dsg_compare_db_version('11.2') < 0 then
		pk_row_text := replace(pk_row_text, '"');
	      end if; 
              --adding a filter on rows when table is iot table
              dbms_datapump.data_filter(h,'SUBQUERY',
                          'where (' || pk_row_text || ') in (select ' ||
                          pk_row_text || ' from ' ||
                          dsg_owner_for_data_filter || node_pk_row_tbl || 
                          ')', node_table_name, node_schema_name);
            end if; --iot or not
          end if; --global shadow table use
        end if; --if not include all
      end if; --truncate because of masking?
      if do_data_remap then
	if not(map_table_missing) then
	  open mask_col_cursor for sql_get_mask_col
				using node_schema_name, node_table_name;
	  loop
	    fetch mask_col_cursor into map_column_name,
				       map_tbl_id,
				       map_rule_type,
                                       map_is_dm,
                                       map_pass_rid;
	    exit when mask_col_cursor%notfound;
            
            -- inline masking
            if map_rule_type = 1 then
              -- use the remap functions created in DBMS_DSM_DSG_IM_DM package
              -- for columns having encrypt format
              if map_is_dm = 'Y' then
                map_func_name := 'DBMS_DSM_DSG_IM_DM.DSG_REMAP_' || map_tbl_id;
              else 
                map_func_name := 'DBMS_DSM_DSG_IM.DSG_REMAP_' || map_tbl_id;
              end if; 
            end if;  
            if map_rule_type = 2 then -- subsetting with column rules
              map_func_name := 'DBMS_DSM_DSG_CR.DSG_REMAP_' || map_tbl_id;
            end if;

            -- Bug 23035784: localize fix to in-export masking plus SQL 
            -- expressions. This piece of code can fail if the user does
            -- not have the right RDBMS patch for bug 13851032 where DP
            -- enhanced remap to pass ROWID. To use SQL Expressions with
            -- In-Export customers require the original fix for bug 
            -- 18089223, this current fix for bug 23035784, and the RDBMS
            -- fix.
            if dsg_get_do_inline_mask and map_pass_rid = 'Y' then
            
             -- Bug 23035784: Change data_remap to pass ROWID to remap function.
             -- This fix is not required for the original issue reported in bug
             -- 23035784, but if the remap function does not look for ROWIDs
             -- then we could potentially have ORA-01422 errors from the remap
             -- function
             data_remap_flg := 1;

             sql_data_remap_call := 'begin ' ||
          			    'dbms_datapump.data_remap('||
				    h || ', ' ||
				    '''COLUMN_FUNCTION''' || ', ' ||
				    '''' || node_table_name || '''' || ', ' ||
				    '''' || map_column_name || '''' || ', ' ||
				    '''' || map_func_name || '''' || ', ' ||
				    '''' || node_schema_name || '''' || ','||
                                    data_remap_flg ||');' ||
			            'end;';
            else
             sql_data_remap_call := 'begin ' ||
			            'dbms_datapump.data_remap('||
       				    h || ', ' ||
  				    '''COLUMN_FUNCTION''' || ', ' ||
				    '''' || node_table_name || '''' || ', ' ||
   				    '''' || map_column_name || '''' || ', ' ||
				    '''' || map_func_name || '''' || ', ' ||
 				    '''' || node_schema_name || '''' || ');'||
			            'end;';
            end if; 
              
	    execute immediate sql_data_remap_call; 
	  end loop;
	  close mask_col_cursor;
	end if; --version >= 11 and map table exists
      end if; --inline mask or column rule
    else --number of rows in not 0
      dbms_datapump.data_filter(h, 'SUBQUERY', 'where 1=2', 
                                node_table_name, node_schema_name);
    end if; 
  end loop;
  close c1;

  /*fetching the list of tables that were excluded
    from the adm.
    Putting a filter on these tables to include 0 rows.
  */
  if dsg_get_filter_excluded_tbls then
    sql_excluded_tbl_list := 'select ' ||
		'd.owner, d.table_name ' ||
		'from dba_tables d, ' ||
		'"' || dsg_owner || '"' || '.' || dsg_node_tbl_name || ' n ' ||
		'where d.owner = n.schema_name ' ||
		'and d.nested != ''YES'' ' ||
		'and d.temporary != ''Y'' ' ||
		'minus ' ||
		'select ' ||
		'schema_name, table_name ' ||
		'from ' || '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name;
    open cursor_excluded_tbl_list for sql_excluded_tbl_list;
    loop
      fetch cursor_excluded_tbl_list into
			excluded_tbl_owner,
			excluded_tbl_name;
      exit when cursor_excluded_tbl_list%notfound;
      dbms_datapump.data_filter(h,
			'SUBQUERY',
			'where 1=2',
			excluded_tbl_name,
			excluded_tbl_owner);
    end loop;
    close cursor_excluded_tbl_list;
  end if;
  
  --adding a filter for the schemas to be exported

  -- branching here based on full export or not
  if dsg_export_type = DSG_EXPORT_OPTION_SUBSET_ONLY then
    dbms_datapump.metadata_filter(
                h,
                'SCHEMA_EXPR',
                ' in (' ||
                '   select distinct(schema_name)' ||
                '   from "' || dsg_owner || '".' || dsg_app_tbl_name ||
                '   where dsm_id = ' || dsm_id ||
                '     and tgt_id = ''' || tgt_id || ''')');
  end if;

                               
  dbms_datapump.set_parallel(h, dsg_get_max_threads);
  if(dsg_get_enable_compression) then
     dbms_datapump.set_parameter(handle => h, 
                                 name => 'COMPRESSION', 
                                 value => 'ALL');
  end if;  
  if(dsg_get_enable_encryption) then
     dbms_datapump.set_parameter(handle => h, 
                                 name => 'ENCRYPTION', 
                                 value => 'ALL'); 
     dbms_datapump.set_parameter(handle => h,
                                 name => 'ENCRYPTION_PASSWORD', 
                                 value => dsg_get_encrypt_password); 
  end if;  


  dbms_datapump.start_job(h);

  job_state := 'UNDEFINED';
  while (job_state != 'COMPLETED') and (job_state != 'STOPPED') loop
    dbms_datapump.get_status(h,
           dbms_datapump.ku$_status_job_error +
           dbms_datapump.ku$_status_job_status +
           dbms_datapump.ku$_status_wip,-1,job_state,sts);
    
-- If any work-in-progress (WIP) or error messages were received for the job,
-- trace them.
    if (bitand(sts.mask,dbms_datapump.ku$_status_wip) != 0) then
      le := sts.wip;
    else
      if (bitand(sts.mask,dbms_datapump.ku$_status_job_error) != 0) then
        le := sts.error;
      else
        le := null;
      end if;
    end if;
    if le is not null then
      ind := le.FIRST;
      while ind is not null loop
        dsg_put_trace(dsm_id, tgt_id, 'EXPORT', '', le(ind).logText, DSG_INFO);
        ind := le.NEXT(ind);
      end loop;
    end if;
  end loop;

  dbms_datapump.detach(h);
 
exception
when others then
  dbms_datapump.get_status(h, 8, 0, job_state, sts);
    le := sts.error;
    ind := le.first;
    while ind is not null loop
      dsg_put_trace(dsm_id, tgt_id, 'EXPORT', '', le(ind).logText, DSG_ERROR);
      ind := le.next(ind);
    end loop;
    dbms_datapump.detach(h);
    raise;
end dsg_exec_export;

procedure dsg_execute_subset
is
  dsm_id integer;
  tgt_id raw(16);
begin
  dsm_id := dsg_get_dsm_id;
  tgt_id := dsg_get_tgt_id;
  dsg_use_shadow_tbls;
  if dsg_exec_option = DSG_EXEC_OPTION_EXPORT then
    dsg_exec_export(dsm_id, tgt_id);
  elsif dsg_exec_option = DSG_EXEC_OPTION_INPLACE then
    dsg_inplace_replace(dsm_id, tgt_id);
  else
    dsg_put_trace(dsm_id, tgt_id, 'EXECUTING SUBSET', 'ERROR', 
			'Invalid subset exec option: ' || dsg_exec_option,
                        DSG_ERROR);
  end if;
end dsg_execute_subset;  

procedure dsg_drop_table_indexes (l_table_id in number,
				  l_owner in varchar2,
                                  l_table_name in varchar2)
is
  query varchar2(32767);
  index_ddl clob;
  owner varchar2(128);
  index_name varchar2(128);
  type cursor is ref cursor;
  c1 cursor;
begin
  query := 'select index_name, owner ' ||
           'from dba_indexes ' ||
           'where table_owner = :1 and table_name = :2' ||
           ' and index_type != ''LOB''' ||
           ' and index_name not in ' ||
           '(select index_name ' ||
           'from dba_constraints ' ||
           'where owner = :3 and table_name = :4' ||
           ' and index_name is not null)';
  open c1 for query using l_owner, l_table_name, l_owner, l_table_name;
  loop
    fetch c1 into index_name, owner;
    exit when c1%notfound;
    begin
      index_ddl := dbms_metadata.get_ddl('INDEX', index_name, owner);
      exception
	when others then
	  dsg_put_trace('', '', 'RETRIEVE INDEX DDL', 
                        owner || '.' || index_name, 
                        sqlerrm(sqlcode), DSG_ERROR);
                        
        -- Fix Bug 22746491: Raise exception to upper stack
        raise;
    end;
    
    dsg_store_ddl(l_table_id, 'INDEX', index_name, 
                  l_owner, l_table_name, null, null, index_ddl);
    
    begin
      execute immediate 'drop index ' || owner || '.' || index_name;
      exception
	when others then
	  dsg_put_trace('', '', 'DROP INDEX', 
                        owner || '.' || index_name, 
                        sqlerrm(sqlcode), DSG_ERROR);
    	  raise;
    end;
  end loop;
  close c1;
end dsg_drop_table_indexes;

procedure dsg_drop_indexes ( dsm_id in integer,
			       tgt_id in raw )
is
dsg_app_cursor sys_refcursor;
dsg_node_cursor sys_refcursor;
as_name varchar2(128);
node_table_id number;
node_table_name varchar2(128);
node_schema_name varchar2(128);
query_1 varchar2(32767);
query_2 varchar2(32767);
begin
  query_1 := 'select appl_short_name from ' || '"' || dsg_owner || '"' || 
	     '.' || dsg_app_tbl_name || ' where dsm_id = :1' ||
	     ' and tgt_id = :2';
  open dsg_app_cursor for query_1 using dsm_id, tgt_id;
  loop
    fetch dsg_app_cursor into as_name;
    exit when dsg_app_cursor%notfound;
    
    query_2 := 'select table_id, runtime_schema_name, table_name from ' ||
	       '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
	       ' where appl_short_name = :1 and act_num_rows != 0';
    open dsg_node_cursor for query_2 using as_name;
    loop
      fetch dsg_node_cursor into node_table_id, 
                                 node_schema_name, 
                                 node_table_name;
      exit when dsg_node_cursor%notfound;
      dsg_drop_table_indexes(node_table_id, node_schema_name, node_table_name);
    end loop;
    close dsg_node_cursor;
  end loop;
  close dsg_app_cursor;
end dsg_drop_indexes;

-- Concatenate suffix to the object name, but make sure the
-- resulting name is not longer than max_obj_name_bytes
function get_int_name (obj_name varchar2,temp_suffix varchar2,max_obj_name_bytes integer)
return VARCHAR2
is
str_length NUMBER :=0;
byte_length NUMBER :=0;
suffix_length NUMBER :=0;

begin

  str_length := LENGTH(obj_name);
  if str_length > max_obj_name_bytes then
    str_length := max_obj_name_bytes;
  end if;
  -- Get the byte length of string
  byte_length := LENGTHB(SUBSTR(obj_name,0,str_length));
  -- Now make sure we account for any multibyte characters.
  -- So test the byte length of the object name
  while byte_length  > max_obj_name_bytes loop
  str_length := str_length -1;
  byte_length := LENGTHB(SUBSTR(0,str_length));
  end loop;
  suffix_length := 30 - byte_length;
 -- we know that suffix contains only single byte characters.
  if suffix_length > LENGTH(temp_suffix) then
  suffix_length :=  LENGTH(temp_suffix);
  end if;

  return SUBSTR(obj_name,0,str_length)||SUBSTR(temp_suffix,0,suffix_length);
end;

-- function to support name clash detection
function gen_name_in_use (gen_name varchar2, owner varchar2)
return boolean is

found_owner boolean := false;

begin

  if dsg_tables.exists(gen_name) then
    found_owner := true;
  end if;

  return found_owner;
end;

-- For compatibility, returns a generated name with a maximum length
-- of 30 characters.
function get_generated_name (obj_name varchar2,tag varchar2, max_length number)
return VARCHAR2
is
  last_index NUMBER;
  new_num  NUMBER;
  prefix  VARCHAR2(30);
  aftertag  VARCHAR2(30);
  postfix     VARCHAR2(30);
begin
  last_index := INSTR(obj_name,tag,-1);

-- Set the prefix to the objname.  If the tag isn't found then
-- the prefix is the object name.  If the tag is found, the
-- prefix is the object name less the tag.
  prefix := obj_name;

-- Initially, a newly postfixed name will start with an integer
-- part of 0.  After than, the int part will be incremented.
  new_num :=0;

-- If last_index !=0 then the tag was found.
  if last_index != 0 then
    prefix := SUBSTR(obj_name,1,last_index-1);
    aftertag := SUBSTR(obj_name, last_index + LENGTH(tag));
    if aftertag is not null then
      new_num := to_number(aftertag);
      new_num := new_num + 1;
    else
      new_num :=0;
    end if;
  end if;

 --The postfix is the tag concatenated with the integer.
 postfix := tag || new_num;

return get_int_name(prefix, postfix, max_length - LENGTH(postfix));

end;

procedure add_gen_name (gen_name varchar2, owner varchar2) is
begin
dsg_tables (gen_name) := owner;
end;

-- function to return interim object name
function dsg_interim_obj_name (schema_name varchar2, obj_name varchar2,max_len NUMBER,dsg_suffix varchar2)
return VARCHAR2
is

  int_name VARCHAR2(30);
  interim_object_name VARCHAR2(30);
begin
  int_name := get_int_name(obj_name, dsg_suffix, 30 - LENGTH(dsg_suffix));
  while gen_name_in_use (schema_name||'.'||int_name,obj_name) loop
    int_name := get_generated_name(int_name, dsg_suffix,30);
  end loop;
  interim_object_name := int_name;
  add_gen_name (schema_name||'.'||int_name,obj_name);
  return interim_object_name;
end;

procedure dsg_process_table_del(table_id in number,
				dsm_id in integer)
is
  node_table_name varchar2(128);
  node_table_dsg_name varchar2(30);
  node_schema_name varchar2(128);
  node_pkey_cname varchar2(128);
  node_pk_row_tbl varchar2(30);
  node_row_id_tbl varchar2(30) := dsg_row_id_tbl_name;
  node_is_iot_table varchar2(1);
  node_ud_clause varchar2(4000);
  node_logging varchar2(3);
  node_parallel varchar2(10);
  node_instances varchar2(10);
  query varchar2(32767);
  query_1 varchar2(32767);
  query_2 varchar2(32767);
  query_3 varchar2(32767);
  query_4 varchar2(32767);
  query_5 varchar2(32767);
  kt_info keyinfo_t;
  pk_row_text varchar2(32767);
  table_missing exception;
  pragma exception_init (table_missing, -00942);
begin
  query := 'select table_name, runtime_schema_name, pkey_cname, ' ||
	   'pk_row_tbl, is_iot_table from ' || 
	   '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
	   ' where table_id = :1';
  execute immediate query
  into node_table_name, node_schema_name, node_pkey_cname,
       node_pk_row_tbl, node_is_iot_table
  using table_id;
  query := 'select logging, degree, instances ' ||
	   'from dba_tables ' ||
	   'where owner = :1 and table_name = :2';
  execute immediate query
  into node_logging, node_parallel, node_instances
  using node_schema_name, node_table_name;

  node_table_dsg_name :=
   dsg_interim_obj_name (node_schema_name,node_table_name,30,'$DSG');

  query_1 := 'truncate table ' || '"' || node_schema_name || '"' ||
		'.' || '"' || node_table_name || '"';
  query_2 := 'alter table ' || '"' || node_schema_name || '"' ||
		'.' || '"' || node_table_name || '"' || 
                ' parallel nologging';
  query_3 := 'insert /*+ ENABLE_PARALLEL_DML APPEND  */ into ' || 
             '"' || node_schema_name || '"' || '.' || '"' || node_table_name ||
             '"' || ' select * from ' ||
             '"' || dsg_owner || '"' || '.' || '"' ||
             node_table_dsg_name || '"';
  query_5 := 'alter table ' || '"' || node_schema_name || '"' ||
		'.' || '"' || node_table_name || '"' ||
		' parallel (degree ' || node_parallel || 
                ' instances ' || node_instances || ')';
  if node_logging is not null and node_logging = 'YES' then
    query_5 := query_5 || ' logging';
  end if;
  if node_is_iot_table = 'N' then
    dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
                  'DELETING DATA', 
                  'Deleting rows from table: '    
                  || node_schema_name || '.' || node_table_name, DSG_INFO);
    --checking if old staged still exists due to some error
    drop_table(node_table_dsg_name);

    -- add COMPRESS clause to compress the $DSG table
    query := 'create table ' || '"' || dsg_owner || '"' || '.' ||
             '"' || node_table_dsg_name || '"' || ' PARALLEL NOLOGGING ' ||
	     ' COMPRESS as ( select A.* from ' ||
             '"' || node_schema_name || '"' || '.' || '"' || node_table_name || 
             '"' || ' A, ' || 
             '"' || dsg_owner || '"' || '.' || node_row_id_tbl || table_id ||
             ' B ' || 'where A.rowid = B.row_id) ';
    begin
      dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
                    'DELETING DATA', query, DSG_DEBUG);
      execute immediate query;
      dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
                    'DELETING DATA', query_1, DSG_DEBUG);
      execute immediate query_1;
      dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
                    'DELETING DATA', query_2, DSG_DEBUG);
      execute immediate query_2;
      dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
                    'DELETING DATA', query_3, DSG_DEBUG);
      execute immediate query_3;
      dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
                    'DELETING DATA', query_4, DSG_DEBUG);
      drop_table(node_table_dsg_name);
      dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
                    'DELETING DATA', query_5, DSG_DEBUG);
      execute immediate query_5;
      commit;
      exception 
	when others then
	  dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
                        'DELETING DATA', sqlerrm(sqlcode), DSG_ERROR);
          raise;
    end;
  else
    kt_info := dsg_get_keys(node_schema_name, node_table_name, node_pkey_cname);
    pk_row_text := dsg_get_key_txt(kt_info, null);
    query := 'delete from ' || '"' || node_schema_name || '"' || '.' ||
	     '"' || node_table_name ||  '"' ||
             ' where (' || pk_row_text || ') not in (select ' || 
	     pk_row_text || ' from ' || 
             '"' || dsg_owner || '"' || '.' || node_pk_row_tbl || ')';
    dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
                  'DELETING DATA', 'Deleting rows from table: ' 
                  || node_schema_name || '.' || node_table_name, DSG_INFO);
    dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
                  'DELETING DATA', query, DSG_DEBUG);
    begin
      execute immediate query;
      exception
        when others then
          dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
               'ERROR EXECUTING QUERY: ' || query, sqlerrm(sqlcode), DSG_ERROR);
               
        -- Fix Bug 20453099: Raise exception to upper stack
        raise;
    end;
  end if;
end dsg_process_table_del;



procedure dsg_process_table_no_shadow(table_id number,
				      dsm_id integer)
is
  node_table_name varchar2(128);
  node_table_dsgp_name varchar2(30);
  node_schema_name varchar2(128);
  node_ud_clause varchar2(4000);
  node_p_clause  clob;
  node_sp_clause  clob;
  query clob;
  query1 varchar2(32767);
  query2 varchar2(32767);
  query3 varchar2(32767);
  query4 varchar2(32767);
  query5 varchar2(32767);
  node_partitions dsg_part_table_array := dsg_part_table_array();
  node_sub_partitions dsg_part_table_array := dsg_part_table_array();
  node_logging varchar2(3);
  node_parallel varchar2(10);
  node_instances varchar2(10);
  table_missing exception;
  pragma exception_init (table_missing, -00942);
  l_sql_table DBMS_SQL.VARCHAR2a;
  l_ds_cursor integer;
  l_ret_val   integer;

begin
   query1 := 'select table_name, runtime_schema_name, ' ||
           'runtime_ud_clause, pclause, spclause from ' ||
           '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
           ' where table_id = :1';

   execute immediate query1
   into node_table_name, node_schema_name, node_ud_clause, 
        node_p_clause, node_sp_clause using table_id;

  if node_p_clause is not null or node_sp_clause is not null then 
   -- Taking a copy truncate approach
   -- other approach is to go over all the partitions in a table other than 
   -- the specified ones and truncate each of those partitions
   query1 := 'select logging, degree, instances ' ||
            'from dba_tables ' || 'where owner = :1 and table_name = :2';
   execute immediate query1
   into node_logging, node_parallel, node_instances
   using node_schema_name, node_table_name;

   node_table_dsgp_name :=
     dsg_interim_obj_name (node_schema_name,node_table_name,30,'$DSGP');
   
   query2 := 'truncate table ' || '"' || node_schema_name || '"' ||
                 '.' || '"' || node_table_name || '"';
   query3 := 'alter table ' || '"' || node_schema_name || '"' ||
                 '.' || '"' || node_table_name || '"' || ' parallel nologging';
   query4 := 'insert /*+ enable_parallel_dml append */ into ' ||
              '"' || node_schema_name || '"' || '.' || 
              '"' || node_table_name || '"' ||
              ' select * from ' ||
              '"' || dsg_owner || '"' || '.' ||
              '"' || node_table_dsgp_name || '"';
   query5 := 'alter table ' || '"' || node_schema_name || '"' ||
                 '.' || '"' || node_table_name || '"' ||
                 ' parallel (degree ' || node_parallel || 
                 ' instances ' || node_instances || ')';
   if node_logging is not null and node_logging = 'YES' then
       query5 := query5 || ' logging';     
   end if;    

    -- add COMPRESS clause to compress the $DSGP table
   query := 'create table ' || '"' || dsg_owner || '"' || '.' ||
            '"' || node_table_dsgp_name || '"' || ' PARALLEL NOLOGGING ' ||
            ' COMPRESS as (';
   if node_p_clause is not null then 
     node_partitions := dsg_split_partition_clause(node_p_clause);
     print_part(node_partitions);
     for i in node_partitions.first .. node_partitions.last - 1 loop
         query := query || 'select  * from '|| 
                  '"' || node_schema_name || '"' || '.' || 
                  '"' || node_table_name || '"' || 
                  ' partition('|| node_partitions(i)||')';
         if node_ud_clause is not null then
           query := query ||' where '||node_ud_clause;
         end if;
         query := query || ' union all ';
     end loop;        
     query := query || 'select  * from ' || 
              '"' || node_schema_name || '"' || '.' || 
              '"' || node_table_name || '"'  || 
              ' partition('|| node_partitions(node_partitions.count)||')';
     if node_ud_clause is not null then
         query := query ||' where '||node_ud_clause;
     end if;
     if node_sp_clause is not null then
        query := query || ' union all ';
     else
        query := query || ')';     
     end if;        
   end if;         
   if node_sp_clause is not null then  
     node_sub_partitions := dsg_split_partition_clause(node_sp_clause);
     print_part(node_sub_partitions);
     for i in node_sub_partitions.first .. node_sub_partitions.last - 1 loop
       query := query || 'select  * from '|| 
                '"' || node_schema_name || '"' || '.' || 
                '"' || node_table_name || '"' || 
                ' subpartition(' ||
                node_sub_partitions(i)||')';
       if node_ud_clause is not null then
         query := query ||' where '||node_ud_clause;
       end if;
       query := query || ' union all ';
     end loop;        
     query := query || 'select  * from ' || 
              '"' || node_schema_name || '"' || '.' || 
              '"' || node_table_name || '"'  || 
              ' subpartition(' || 
              node_sub_partitions(node_sub_partitions.count)||')';
     if node_ud_clause is not null then
       query := query ||' where '||node_ud_clause;
     end if;
     query := query || ')';
   end if;
   
   drop_table(node_table_dsgp_name);  

   begin
      begin
         dsg_add_to_sql_tbl(l_sql_table,query);
         l_ds_cursor := DBMS_SQL.OPEN_CURSOR;
         DBMS_SQL.PARSE(l_ds_cursor,
                        l_sql_table,
                        l_sql_table.FIRST,
                        l_sql_table.LAST,
                        FALSE,
                        DBMS_SQL.NATIVE);
         l_ret_val := DBMS_SQL.EXECUTE(l_ds_cursor);
         DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
         l_sql_table.DELETE;
      exception
        when others then       
          dsg_put_trace(dsm_id,'' , '', '', sqlerrm(sqlcode), DSG_ERROR);
           DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
           l_sql_table.DELETE;
      end;
      execute immediate query2;
      execute immediate query3;
      execute immediate query4;
      execute immediate query5;
   exception
      when others then
        dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
                      'DELETING DATA', sqlerrm(sqlcode), DSG_ERROR);
        raise;
   end;
  elsif node_ud_clause is not null then 
    -- bug#20099726: DML for some rows
    -- runtime user defined clause will be of the form rownum <= 50
    if substr(node_ud_clause, 1, 6) = 'rownum' then 
      query1 := 'delete from ' || '"' || node_schema_name || '"' || '.' ||
               '"' || node_table_name || '"' || ' where rowid not in ('||
               'select  rowid from '||
               '"' || node_schema_name || '"' || '.' ||
               '"' || node_table_name || '"' || ' where '||node_ud_clause||')';
    else -- DML for where_clause
      query1 := 'delete from ' || '"' || node_schema_name || '"' || '.' ||
               '"' || node_table_name || '"' || 
               ' where not(' || node_ud_clause || ')';
    end if;           
    begin
      execute immediate query1;
    exception
      when others then
        dsg_put_trace(dsm_id, '', 'INPLACE REPLACE', 
                      'DELETING DATA', sqlerrm(sqlcode), DSG_ERROR);
        raise;
    end;
  end if;
end dsg_process_table_no_shadow;

procedure dsg_inprep_process_tables(dsm_id in integer,
				    tgt_id in raw)
is
  node_table_id number;
  node_table_name varchar2(128);
  node_schema_name varchar2(128);
  node_act_num_rows number;
  node_is_include_all varchar2(1);
  as_name varchar2(128);
  dsg_app_cursor sys_refcursor;
  dsg_node_cursor sys_refcursor;
  query_1 varchar2(32767);
  query_2 varchar2(32767);
  query varchar2(32767);
  po dbms_aqadm.aq$_purge_options_t;
  external_table exception;
  pragma exception_init(external_table, -30657);
begin
  po.block := true;
  query_1 := 'select appl_short_name from ' ||
	     '"' || dsg_owner || '"' || '.' || dsg_app_tbl_name ||
	     ' where dsm_id = :1 and tgt_id = :2';
  open dsg_app_cursor for query_1 using dsm_id, tgt_id;
  loop
    fetch dsg_app_cursor into as_name;
    exit when dsg_app_cursor%notfound;
    
    query_2 := 'select table_id, table_name, runtime_schema_name, ' ||
	       'act_num_rows, is_include_all ' ||
               'from '|| '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
               ' where appl_short_name = :1 and table_name not like ''AQ$%''';
    open dsg_node_cursor for query_2 using as_name;
    loop
      fetch dsg_node_cursor into
			node_table_id, node_table_name, node_schema_name,
			node_act_num_rows, node_is_include_all;
      exit when dsg_node_cursor%notfound;
      
      if node_act_num_rows = 0 then
        if dsg_drop_tables = true then
          dsg_put_trace(dsm_id, tgt_id, 'INPLACE REPLACE', 
                        'truncating table ', 'truncating: ' || 
			node_schema_name || '.' || node_table_name, DSG_INFO);
	  if (dsg_is_queuetable(node_schema_name, node_table_name)) then
	    dbms_aqadm.purge_queue_table(node_schema_name||'.'||node_table_name, 
					 null, po);
	  else
	    query := 'truncate table ' || '"' || node_schema_name || '"' ||
		     '.' || '"' || node_table_name || '"';
            begin
              execute immediate query;
            exception
	      when external_table then
		dsg_put_trace(dsm_id, tgt_id, 'INPLACE REPLACE', 
                              'TRUNCATE TABLE ERROR', 
                              node_schema_name || '.' || node_table_name || 
                              ' is an external table', DSG_ERROR);
              when others then
                dsg_put_trace(dsm_id, tgt_id, 'INPLACE REPLACE', 
                              'TRUNCATE TABLE ERROR', 
                              node_schema_name || '.' || node_table_name 
                              || sqlerrm(sqlcode), DSG_ERROR);
                              
              -- Fix Bug 20453099: Raise exception to upper stack
              -- Not raising exception to the upper stack, causing job status
              -- is shown as succeeded.
              raise;
	    end;
          end if;
        end if;
      else
	if node_is_include_all = 'N' then
	  if dsg_use_shadow_tbl_global = FALSE then
	    dsg_process_table_no_shadow(node_table_id, dsm_id);
	  else
	    dsg_process_table_del(node_table_id, dsm_id);
	  end if;
	end if;
      end if;
    end loop;
    close dsg_node_cursor;
  end loop;
  close dsg_app_cursor;
end dsg_inprep_process_tables;

procedure dsg_inprep_col_rules
is
  query varchar2(32767);
  remap_sql varchar2(32767);
  c1 sys_refcursor;
  map_schema_name varchar2(128);
  map_table_name varchar2(128);
  map_column_name varchar2(128);
  map_column_type varchar2(50);
  map_tbl_id integer;
  map_func_name varchar2(100);
  map_format_type integer;
  map_format_text varchar2(4000);
  table_missing exception;
  pragma exception_init(table_missing, -942);
begin
  if (dsg_get_apply_column_rules)
  then
    query := 'select schema_name, ' ||
		'table_name, ' ||
		'column_name, ' ||
		'mask_map_table_id, ' ||
                'column_type, '||
                'format_type, '||
                'format_text '||
		'from ' || dsg_mask_map_tbl_name;
    open c1 for query;
    loop
      fetch c1 into map_schema_name, map_table_name, map_column_name, 
                    map_tbl_id, map_column_type, 
                    map_format_type, map_format_text;
      exit when c1%notfound;

      -- bug#20178178 : Directly update the columns for 
      -- in-database subsetting when column rules are present 
      -- instead of depending on package remap function
      if map_format_type = DSG_NULL_FORMAT then 
         if substr(map_column_type, 1, 4) = 'BLOB' then 
           map_format_text := 'TO_BLOB(NULL)';
         elsif substr(map_column_type, 1, 4) = 'CLOB' then 
           map_format_text := 'TO_CLOB(NULL)';
         elsif substr(map_column_type, 1, 5) = 'NCLOB' then 
           map_format_text := 'TO_NCLOB(NULL)';
         else 
           map_format_text := 'NULL';
         end if;
      elsif map_format_type = DSG_FIXED_STRING then 
         map_format_text := ''''||map_format_text||'''';     
         if substr(map_column_type, 1, 4) = 'BLOB' then 
           map_format_text := 
              'TO_BLOB(UTL_RAW.CAST_TO_RAW('|| map_format_text||'))';
         elsif substr(map_column_type, 1, 4) = 'CLOB' then 
           map_format_text := 'TO_CLOB('||map_format_text||')';
         elsif substr(map_column_type, 1, 5) = 'NCLOB' then 
           map_format_text := 'TO_NCLOB('||map_format_text||')';
         end if;
      elsif map_format_type = DSG_FIXED_NUMBER then
         if instr(map_column_type, 'CHAR') > 0 then 
           map_format_text := ''''||map_format_text||'''';      
         elsif substr(map_column_type, 1, 4) = 'BLOB' then 
           map_format_text := 
              'TO_BLOB(UTL_RAW.CAST_FROM_NUMBER('|| map_format_text||'))';
         elsif substr(map_column_type, 1, 4) = 'CLOB' then 
           map_format_text := 'TO_CLOB('||map_format_text||')';
         elsif substr(map_column_type, 1, 5) = 'NCLOB' then 
           map_format_text := 'TO_NCLOB('||map_format_text||')';
         end if;
      end if;          

      remap_sql := 'update /*+ enable_parallel_dml */ "' || 
                   map_schema_name || '"."' || map_table_name || 
                   '" set "' || map_column_name || '" = '|| map_format_text;

      dsg_put_trace('', '', 'INPLACE REPLACE', 'COLUMN RULES',
		'remapping ' || map_schema_name || '.' ||
                map_table_name || '.' || map_column_name, DSG_INFO);
      begin
	execute immediate remap_sql;
      exception
	when others
	then
	  dsg_put_trace('', '', 'INPLACE REPLACE', 'COLUMN RULES',
			remap_sql || chr(13) || chr(10) || sqlerrm(sqlcode),
                        DSG_ERROR);
	  raise;
      end;
      commit;
    end loop;
    close c1;
  end if;
exception
  when table_missing
  then
    dsg_put_trace('', '', 'INPLACE REPLACE', 'COLUMN RULES', 
                 'Global mapping table missing, skipping column rules',
                 DSG_ERROR);
  when others
  then
    raise;
end dsg_inprep_col_rules;
    


procedure dsg_inprep_del(dsm_id in integer,
			 tgt_id in raw)
is
 
  exec_state integer;

begin
  exec_state := 1;
  dsg_drop_indexes(dsm_id, tgt_id);

  exec_state := 2;
  dsg_manage_constraints(dsm_id, DSG_DISABLE_CONS);

  exec_state := 3;
  dsg_manage_triggers(dsm_id, DSG_DISABLE_TRG);

  dsg_inprep_process_tables(dsm_id, tgt_id);
  dsg_inprep_col_rules;

  dsg_enable_ict(dsm_id, exec_state);

  exception
    when others then
      dsg_enable_ict(dsm_id, exec_state);
      raise;

end dsg_inprep_del;


-- PROCEDURE dsg_enable_ict
-- PURPOSE: Adds indexes and enable constraints and triggers after subset 
--         execution is completed or failed 
-- PARAMETERS:
--   dsm_id    	:   subset model id
--   exec_state :   State of subset execution.
--  	1. Indexes are successfully removed or exception occurred while 
--           removing them.
--      2. Constraints are successfully disabled or exception occurred while 
--           disabling them.
--	3. Triggers are successfully disabled or exception occurred while 
--         disabling them. Subset execution is successful or exception 
--         occurred while executing it.
-- RETURNS:
--     NONE
procedure dsg_enable_ict(dsm_id in integer, exec_state in integer)
is
  begin
     if exec_state >= 2 then
        dsg_manage_constraints(dsm_id, DSG_ENABLE_CONS);
     end if;

     if exec_state >= 1 then
        dsg_create_indexes;
     end if;

     if exec_state >= 3 then
        dsg_manage_triggers(dsm_id, DSG_ENABLE_TRG);
     end if;
end dsg_enable_ict;
procedure dsg_inplace_replace(dsm_id in integer,
			      tgt_id in raw)
is
begin
  execute immediate 'alter session enable parallel dml';
  dsg_inprep_del(dsm_id, tgt_id);
end dsg_inplace_replace;

-- db_dsg_ddls_e table stores the DDLs of dependent objects 
-- like constraints, indexes and triggers 
--
-- Following are the columns in this table 
--    table_id      - Table ID whose dependents we are storing
--    object_type   - INDEX/CONSTRAINT/TRIGGER
--    object_name   - Name of the index/constraint/trigger
--    object_owner  - Owner of the object (index/constraint/trigger)
--    table_name    - Table on which the object exist 
--    otype         - type of index/constraint/trigger ex : domain index
--    validated     - status of trigger/constraint (enabled/disabled)
--    object_ddl    - DDL of the object
procedure create_ddl_table
is
begin
  execute immediate 'create table ' || '"' || dsg_owner || '"' || '.' ||
		    'db_dsg_ddls_e ' ||
		    '( ' ||
		    'table_id number, ' ||
		    'object_type varchar2(20), ' || 
                    'object_name varchar2(128), '||
                    'object_owner varchar2(128), '||
                    'table_name varchar2(128), '||
                    'otype varchar2(27), '||
                    'validated varchar2(13), '||
		    'object_ddl clob ' ||
		    ')';
end create_ddl_table;

procedure dsg_store_ddl(table_id in number,
			object_type in varchar2,
                        object_name in varchar2,
                        object_owner in varchar2,
                        table_name in varchar2,
                        otype in varchar2,
                        validated in varchar2,
			object_ddl in clob)
is
  v_cursor binary_integer;
  no_rows integer;
  ins_sql varchar2(32767);
begin
  ins_sql := 'insert into ' || '"' || 
             dsg_owner || '"' || '.' || dsg_ddl_tbl_name ||
	     ' values (:tbl_id, :obj_type, :obj_name, '||
             ' :obj_owner, :tbl_name, '||
             ' :o_type, :validated, :obj_ddl)';
  v_cursor := dbms_sql.open_cursor;
  dbms_sql.parse(v_cursor, ins_sql, dbms_sql.native);
  dbms_sql.bind_variable(v_cursor, ':tbl_id', table_id);
  dbms_sql.bind_variable(v_cursor, ':obj_type', object_type);
  dbms_sql.bind_variable(v_cursor, ':obj_name', object_name);
  dbms_sql.bind_variable(v_cursor, ':obj_owner', object_owner);
  dbms_sql.bind_variable(v_cursor, ':tbl_name', table_name);
  dbms_sql.bind_variable(v_cursor, ':o_type', otype);
  dbms_sql.bind_variable(v_cursor, ':validated', validated);
  dbms_sql.bind_variable(v_cursor, ':obj_ddl', object_ddl);
  no_rows := dbms_sql.execute(v_cursor);
  dbms_sql.close_cursor(v_cursor);
  exception
    when others then
      dbms_sql.close_cursor(v_cursor);
      raise;
end dsg_store_ddl;

procedure dsg_create_indexes
is
  index_ddl clob;
  dsg_ddl_cursor sys_refcursor;
  query varchar2(32767);
  sql_tbl dbms_sql.varchar2a;
  v_cursor binary_integer;
  no_rows integer;
begin
  query := 'select object_ddl from ' ||
	   '"' || dsg_owner || '"' || '.' || dsg_ddl_tbl_name ||
	   ' where object_type = ''INDEX''';
  open dsg_ddl_cursor for query;
  loop
    fetch dsg_ddl_cursor into index_ddl;
    exit when dsg_ddl_cursor%notfound;
    begin
      sql_tbl.delete;
      dsg_add_to_sql_tbl(sql_tbl, index_ddl);
      v_cursor := dbms_sql.open_cursor;
      dbms_sql.parse(v_cursor, sql_tbl, sql_tbl.first,
		     sql_tbl.last, false, dbms_sql.native);
      no_rows := dbms_sql.execute(v_cursor);
      dbms_sql.close_cursor(v_cursor);
      exception
	when others then
	  dsg_put_trace('', '', 'CREATE INDEX', '', sqlerrm(sqlcode),
                       DSG_ERROR);
	  dbms_sql.close_cursor(v_cursor);
    end;
  end loop;
  close dsg_ddl_cursor;
end dsg_create_indexes;

procedure dsg_create_pk_shadow_tables
is
  query varchar2(32767);
  node_table_id number;
  node_schema_name varchar2(128);
  node_table_name varchar2(128);
  node_pkey_cname varchar2(128);
  node_pk_row_tbl varchar2(30);
  kt_info keyinfo_t;
  pk_row_text varchar2(32767);
  table_exists exception;
  pragma exception_init(table_exists, -955);
  dsg_node_cursor sys_refcursor;
  dsm_id integer;
  tgt_id raw(16);
begin
  dsm_id := dsg_get_dsm_id;
  tgt_id := dsg_get_tgt_id;
  query := 'select table_id, runtime_schema_name, table_name, ' || 
           'pkey_cname, pk_row_tbl from ' || 
           '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name || 
           ' where ' || ' dsm_id = ' || dsm_id || 
           ' and tgt_id = ' || '''' || tgt_id || '''' || 
           ' and is_iot_table = ''Y''';
  open dsg_node_cursor for query;
  loop
    fetch dsg_node_cursor into 
		node_table_id, node_schema_name, node_table_name, 
                node_pkey_cname, node_pk_row_tbl;
    exit when dsg_node_cursor%notfound;
    kt_info := dsg_get_keys(node_schema_name, node_table_name, node_pkey_cname);
    pk_row_text := dsg_get_key_txt(kt_info, null);
    
    -- add PCTFREE 0 clause to utilize complete space in blocks.
    -- DB_DSG_PK_TBL_* tables we create from the primary key column
    -- data of table taking part in subsetting, hence there wont be any 
    -- duplicates in this table. To avoid check for duplicates in IAS op
    -- we will use PCTFREE clause.
    query := 'create table ' || 
             '"' || dsg_owner || '"' || '.DB_DSG_PK_TBL_' || node_table_id ||
	     ' nologging PARALLEL PCTFREE 0 as select ' || 
             pk_row_text || ' from "' || 
             node_schema_name ||'"."' || node_table_name || '" where 1 = 2';
    begin
      execute immediate query;
    exception
      when table_exists then
	dsg_put_trace(dsm_id, 
                      tgt_id,
                      'CREATE SHADOW TABLE',
                      '',
                      'shadow table for ' || 
                      node_schema_name || '.' || node_table_name || 
                      ' already exists',
                      DSG_ERROR);
    end;
    
    query := 'update ' || '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name || 
             ' set pk_row_tbl = ''DB_DSG_PK_TBL_' || node_table_id ||
             ''' where table_id = ' || node_table_id;
    execute immediate query;
  end loop;
  close dsg_node_cursor;
end dsg_create_pk_shadow_tables;


procedure dsg_create_rowid_shadow_tables 
is 
  query varchar2(32767);
  query_1 varchar2(32767);
  sql_set_inc_stats varchar2(32767);
  dsm_id integer;
  tbl_id integer;
  tbl_id_cursor sys_refcursor;
  tbl_name varchar2(128);
  table_missing exception;
  pragma exception_init (table_missing, -00942);
  tgt_id raw(16);
begin
  dsm_id := dsg_get_dsm_id;
  tgt_id := dsg_get_tgt_id;
  
  query := 'select distinct (table_id) ' ||
	   'from ' || '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
	   ' where dsm_id = ' || dsm_id || 
           ' and tgt_id = ' || '''' || tgt_id || '''' || 
           ' and is_iot_table != ''Y''';
  open tbl_id_cursor for query;
  loop
    fetch tbl_id_cursor into tbl_id;
    exit when tbl_id_cursor%NOTFOUND;
    tbl_name := dsg_row_id_tbl_name || tbl_id;
    -- dsg_row_id_tbl_name will have all rows unique, no need to compress
    -- this table, instead we will just put pctfree 0, so we will not leave
    -- any space in the block.
    query_1 := 'create table ' || 
               '"' || dsg_owner || '"'|| '.' || tbl_name ||
               ' (ROW_ID  ROWID)  PARALLEL NOLOGGING PCTFREE 0';
    execute immediate query_1;
    
    --setting up stats for row_id table
    if dsg_compare_db_version('11') >= 0
    then
      sql_set_inc_stats := ' begin' ||
                           ' dbms_stats.set_table_prefs(' ||
                           '         ownname => ''"' || dsg_owner || '"'',' ||
                           '         tabname => ''' || tbl_name || ''',' ||
                           '         pname   => ''CASCADE'',' ||
                           '         pvalue  => ''TRUE'');' ||
                           ' end;';
      execute immediate sql_set_inc_stats;
    end if;
  end loop;
  close tbl_id_cursor;
 
end dsg_create_rowid_shadow_tables; 

procedure dsg_create_shadow_tables
is
begin
  -- bug#21491255 : shadow tables are not required for in-export masking
  dsg_use_shadow_tbls;
  if dsg_use_shadow_tbl_global = false then
    return;
  end if;        
  
  -- create rowid shadow tables 
  dsg_create_rowid_shadow_tables;
  
  -- create pk shadow tables for IOT tables
  dsg_create_pk_shadow_tables;
end dsg_create_shadow_tables;

procedure dsg_remap_schemas
is
  query varchar2(32767);
  dsm_id integer;
  tgt_id raw(16);
begin
  dsm_id := dsg_get_dsm_id;
  tgt_id := dsg_get_tgt_id;

  query := 'update ' || 
           '"' || dsg_owner || '"' || '.' || dsg_kc_tbl_name || ' A ' ||
	   'set A.SCH_NAME = (select B.RUNTIME_SCHEMA_NAME from ' || 
	   '"' || dsg_owner || '"' || '.' || dsg_schema_map_tbl_name || ' B' ||
	   ' where A.AS_NAME = B.APPL_SHORT_NAME and A.DSM_ID = B.DSM_ID ' ||
	   'and A.TGT_ID = B.TGT_ID and B.RUNTIME_SCHEMA_NAME is not null) ' ||
	   ' where A.DSM_ID =  :1 and A.TGT_ID = :2';
  execute immediate query using dsm_id, tgt_id;

  query := 'update ' || 
           '"' || dsg_owner || '"' || '.' || dsg_edge_tbl_name || ' A ' ||
           'set A.REF_SCH_NAME = (select B.RUNTIME_SCHEMA_NAME from ' ||
           '"' || dsg_owner || '"' || '.' || dsg_schema_map_tbl_name || ' B ' ||
           'where A.REF_AS_NAME = B.APPL_SHORT_NAME and A.DSM_ID = B.DSM_ID ' ||
           'and A.TGT_ID = B.TGT_ID and B.RUNTIME_SCHEMA_NAME is not null) ' ||
           ' where A.DSM_ID = :1 and A.TGT_ID = :2';
  execute immediate query using dsm_id, tgt_id;

  query := 'update ' || 
           '"' || dsg_owner || '"' || '.' || dsg_edge_tbl_name || ' A ' ||
           'set A.PRI_SCH_NAME = (select B.RUNTIME_SCHEMA_NAME from ' ||
           '"' || dsg_owner || '"' || '.' || dsg_schema_map_tbl_name || ' B ' ||
           'where A.PRI_AS_NAME = B.APPL_SHORT_NAME and A.DSM_ID = B.DSM_ID ' ||
           'and A.TGT_ID = B.TGT_ID and B.RUNTIME_SCHEMA_NAME is not null) ' ||
           ' where A.DSM_ID =  :1 and A.TGT_ID = :2';
  execute immediate query using dsm_id, tgt_id;

  query := 'update ' || 
       '"' || dsg_owner || '"' || '.' || dsg_app_tbl_name || ' A ' ||
       'set A.SCHEMA_NAME = (select B.RUNTIME_SCHEMA_NAME from ' ||
       '"' || dsg_owner || '"' || '.' || dsg_schema_map_tbl_name || ' B ' ||
       'where A.APPL_SHORT_NAME = B.APPL_SHORT_NAME and A.DSM_ID = B.DSM_ID ' ||
       ' and A.TGT_ID = B.TGT_ID and B.RUNTIME_SCHEMA_NAME is not null) ' ||
       ' where A.DSM_ID = :1 and A.TGT_ID = :2';
  execute immediate query using dsm_id, tgt_id;
  
  query := 'update ' || 
           '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name || ' A ' ||
	   'set A.RUNTIME_SCHEMA_NAME = (select B.RUNTIME_SCHEMA_NAME from ' ||
	   '"' || dsg_owner || '"' || '.' || dsg_schema_map_tbl_name || ' B ' ||
   'where A.APPL_SHORT_NAME = B.APPL_SHORT_NAME and A.DSM_ID = B.DSM_ID ' ||
           'and A.TGT_ID = B.TGT_ID and B.RUNTIME_SCHEMA_NAME is not null) ' ||
           ' where A.DSM_ID = :1 and A.TGT_ID = :2';
  execute immediate query using dsm_id, tgt_id;
  
  query := 'update ' || '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
	   ' set RUNTIME_SCHEMA_NAME = SCHEMA_NAME ' ||
	   'where RUNTIME_SCHEMA_NAME is null ' ||
	   'and dsm_id = :1 and tgt_id = :2';
  execute immediate query using dsm_id, tgt_id;

end dsg_remap_schemas;

procedure dsg_refresh_pk_names
is
  query_1 varchar2(32767);
  dsm_id integer;
  tgt_id raw(16);
begin
  dsm_id := dsg_get_dsm_id;
  tgt_id := dsg_get_tgt_id;
  query_1 := 'UPDATE ' || 
             '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name || ' A ' ||
	     ' SET A.PKEY_CNAME = ' ||
	     '(SELECT B.CONSTRAINT_NAME ' ||
	     'FROM DBA_CONSTRAINTS B ' ||
	     'WHERE A.RUNTIME_SCHEMA_NAME = B.OWNER ' ||
	     'AND A.TABLE_NAME = B.TABLE_NAME '||
	     'AND CONSTRAINT_TYPE = ''P'') ' ||
	     'WHERE A.DSM_ID = :1';
  dsg_put_trace(dsm_Id, tgt_id, 'REFRESHING PK NAMES', '', 
                'REFRESHING PK INFO IN GRAPH TABLES', DSG_INFO);
  begin
    execute immediate query_1 using dsm_id;
  exception
    when others then
      dsg_put_trace(dsm_Id, tgt_id, 'REFRESHING PK NAMES', '', 
                    'ERROR REFRESHING GRAPH TABLES', DSG_ERROR);
      raise;
  end;
end dsg_refresh_pk_names;

procedure dsg_compute_percent_rules
is
  query_1 		varchar2(32767);
  query_2		varchar2(32767);
  query_3		varchar2(32767);
  table_id		number;
  schema_name 		varchar2(128);
  table_name 		varchar2(128);
  ud_clause 		varchar2(4000);
  row_percent 		number;
  no_rows_total 	integer;
  no_rows_limit 	integer;
  node_tbl_cursor 	sys_refcursor;
  dsm_id 		integer;
  tgt_id		raw(16);
  pclause               clob;
  spclause              clob;
begin
  dsm_id := dsg_get_dsm_id;
  tgt_id := dsg_get_tgt_id;
  query_1 := 'select table_id, table_name, runtime_schema_name, ' ||
	     'runtime_ud_clause, row_percent, pclause, spclause ' ||
	     'from ' || '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
	     ' where is_ud_rule = ''Y'' and is_include_all = ''N'' ' ||
	     'and dsm_id = :1 and tgt_id = :2' ;
  open node_tbl_cursor for query_1 using dsm_id, tgt_id;
  loop
    no_rows_total := 0;
    no_rows_limit := 0;
    query_2 := null;
    fetch node_tbl_cursor into
	table_id, table_name, schema_name, ud_clause, row_percent, 
        pclause, spclause;
    exit when node_tbl_cursor%notfound;
    --If it is a Some rows rule
    if (ud_clause is null and pclause is null and spclause is null) or 
       (ud_clause = 'Some Rows') then
      query_2 := 'select  count(*) ' ||
		 'from "' || schema_name || '"."' || table_name || '"';
      execute immediate query_2 into no_rows_total;
      --bug#20099726 : pl/sql integer by default rounds the value to ceil
      no_rows_limit := floor((no_rows_total * row_percent) / 100) + 1;
      -- using rownnum <= to handle cases where 1% is given which will 
      -- return atleast 1 row using rownum<=1
      ud_clause := 'rownum <= ' || no_rows_limit;
      query_3 := 'update ' || 
                 '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
                 ' set runtime_ud_clause = :1' ||
                 ' where table_id = :2';
      execute immediate query_3 using ud_clause, table_id;
    --If it is a where clause rule with percent defined
    else
      --do nothing is percent of rows is 100
      if (row_percent > 0 and row_percent < 100) then
      --if row_percent != 100 then 
	query_2 := 'select  count(*) ' ||
		   'from "' || schema_name || '"."' || table_name ||
		   '" where ' || ud_clause;
	execute immediate query_2 into no_rows_total;
	no_rows_limit := ((no_rows_total * row_percent) / 100) + 1;
	ud_clause := ud_clause || ' and rownum < ' || no_rows_limit;
	ud_clause := replace(ud_clause, '''', '''''');
	query_3 := 'update ' || 
                   '"' || dsg_owner || '"' || '.' || dsg_node_tbl_name ||
		   ' set runtime_ud_clause = :1' ||
		   ' where table_id = :2';
	execute immediate query_3 using ud_clause, table_id;
      end if;
    end if;
  end loop;
  close node_tbl_cursor;   
end dsg_compute_percent_rules;

-- procedure to create DBMS_DSM_DSG_IM_DM package and remap functions
-- required for datapump export of encrypt format columns
procedure dsg_create_im_dm_package(dsm_id        integer,
                                   tgt_id        raw,
                                   seed          number)
is
pkgdef clob;                            -- clob for package definition
pkgbody clob;                           -- clob for package body
newline varchar2(1) := chr(10);         -- newline
sql_get_dm_mask_col varchar2(32767);    -- sql for getting the masking columns
mask_col_cursor sys_refcursor;          -- cursor for sql_get_dm_mask_col
mask_map_table_id number;               -- mapping function id
column_type varchar2(50);               -- column data type
column_length number;                   -- column data length
column_precision number;                -- column data precision
column_scale number;                    -- column data scale
column_char_length number;              -- character column length
column_char_used varchar2(1);           -- if char semantics are used
format_text clob;                       -- fixed string format text
column_ret_type varchar2(128);          -- return type of remap function
l_sql_table DBMS_SQL.VARCHAR2a;
l_ds_cursor integer;
l_ret_val integer;
begin

--go over all columns present in DB_DSG_MAP_TABLE for which isDM = Y(encrypt)
--and create DBMS_DSM_DSG_IM_DM package definition, body and the remap functions
sql_get_dm_mask_col := 'select mask_map_table_id, '||
                       'column_type, column_length, column_precision, '||
                       'column_scale, column_char_length, column_char_used, '||
                       'format_text from '||dsg_mask_map_tbl_name ||
                       ' where rule_type = 1 '||
                       ' and nvl(truncate_table, ''N'') = ''N''' ||
                       ' and nvl(is_dm, ''Y'') = ''Y''';

pkgdef := 'CREATE OR REPLACE PACKAGE DBMS_DSM_DSG_IM_DM' || newline;
pkgdef := pkgdef || 'AS' || newline;

pkgbody := 'CREATE OR REPLACE PACKAGE BODY DBMS_DSM_DSG_IM_DM' || newline;
pkgbody := pkgbody || 'AS' || newline;

open mask_col_cursor for sql_get_dm_mask_col;
loop
  fetch mask_col_cursor into mask_map_table_id, column_type,
                             column_length, column_precision, column_scale,
                             column_char_length, column_char_used, format_text;
  exit when mask_col_cursor%notfound;

  column_ret_type := column_type;
  --Handle timestamp column type
  if substr(column_type, 1, 9) = 'TIMESTAMP' then
    column_ret_type := 'TIMESTAMP';
    if instr(column_type, 'LOCAL TIME ZONE') > 0 then
      column_ret_type := column_ret_type || 'WITH LOCAL TIME ZONE';
    elsif instr(column_type, 'TIME ZONE') > 0 then
      column_ret_type := column_ret_type || 'WITH TIME ZONE';
    end if;
  end if; --TIMESTAMP

  -- create remap functions specifications in package definition
  pkgdef := pkgdef || 'FUNCTION DSG_REMAP_' || mask_map_table_id
            || '(old_val IN '|| column_ret_type ||') RETURN '
            || column_ret_type || ' DETERMINISTIC PARALLEL_ENABLE;'
            || newline;
  -- create remap functions body in package body
  pkgbody := pkgbody || 'FUNCTION DSG_REMAP_' || mask_map_table_id
             || '(old_val IN '|| column_ret_type ||') RETURN '
             || column_ret_type ||  ' DETERMINISTIC PARALLEL_ENABLE'
             || newline;
  pkgbody := pkgbody || 'IS' || newline;
  pkgbody := pkgbody || 'new_val '||column_type;

  -- check for specific column types like number, char to create
  -- the exact type for new_val

  -- check for NUMBER datatype
  if substr(column_type, 1, 6) = 'NUMBER' then
   if column_precision is not null or column_scale is not null then
     if column_precision is null then
       column_precision := 38;
     end if;
     pkgbody := pkgbody || '(' || column_precision || ', ' || column_scale
                || ')';
   end if; -- precision or scale
  -- check for CHAR, VARCHAR2, NCHAR, NVARCHAR2 datatypes
  elsif instr(column_type, 'CHAR') > 0 then
   -- use the exact char length like varchar2(40)
   if column_char_length is not null then
     pkgbody := pkgbody || '(' || column_char_length;
     -- check if the column is using byte/char semantics and use it.
     -- This check is done only for char, varchar2 and not for nchar, varchar2
     -- as by default nchar, nvarchar2 use only char semantics
     if (column_type = 'CHAR' or column_type = 'VARCHAR2') and
        (column_char_used = 'C') then
      pkgbody := pkgbody || ' CHAR';
     end if; -- char or varchar2
     pkgbody := pkgbody || ')';
   end if; -- column_char_len
  elsif column_type = 'FLOAT' then
     if column_precision is not null then
       pkgbody := pkgbody || '(' || column_precision || ')';
     end if;
  -- datatypes having length
  elsif (column_type != 'DATE' and substr(column_type, 1, 9) != 'TIMESTAMP
  '       and column_type != 'BINARY_FLOAT' and column_type != 'BINARY_DOUBLE'
          and instr(column_type, 'LOB') = 0) then
   if column_length is not null then
     pkgbody := pkgbody || '(' || column_length;
     if column_precision is not null then
       pkgbody := pkgbody || ', ' || column_precision;
     end if; -- column_precision
     pkgbody := pkgbody || ')';
   end if; -- column_length
  end if;  -- check for specific column types

  --begin and end block of the remap function
  pkgbody := pkgbody ||';' || newline;
  pkgbody := pkgbody || 'BEGIN' || newline;

  format_text := replace(format_text, 'arg_hsd', seed);
  pkgbody := pkgbody || 'new_val := '
               || replace(format_text, '%COL_ID%', mask_map_table_id) ||';'
               || newline;
  pkgbody := pkgbody || 'RETURN new_val;' || newline;
  pkgbody := pkgbody || 'END DSG_REMAP_' || mask_map_table_id ||';'|| newline;

end loop; --mask_col_cursor

pkgdef := pkgdef || 'END DBMS_DSM_DSG_IM_DM;'|| newline;
pkgbody := pkgbody || 'END DBMS_DSM_DSG_IM_DM;' || newline;

-- actual creation of package def and body
begin
   dsg_add_to_sql_tbl(l_sql_table,pkgdef);
   l_ds_cursor := DBMS_SQL.OPEN_CURSOR;
   DBMS_SQL.PARSE(l_ds_cursor,
                  l_sql_table,
                  l_sql_table.FIRST,
                  l_sql_table.LAST,
                  FALSE,
                  DBMS_SQL.NATIVE);
   l_ret_val := DBMS_SQL.EXECUTE(l_ds_cursor);
   DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
   l_sql_table.DELETE;
exception
    when others then       
     dsg_put_trace(dsm_id,tgt_id , '', '', sqlerrm(sqlcode), DSG_ERROR);
     DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
     l_sql_table.DELETE;
end;
begin
   dsg_add_to_sql_tbl(l_sql_table,pkgbody);
   l_ds_cursor := DBMS_SQL.OPEN_CURSOR;
   DBMS_SQL.PARSE(l_ds_cursor,
                  l_sql_table,
                  l_sql_table.FIRST,
                  l_sql_table.LAST,
                  FALSE,
                  DBMS_SQL.NATIVE);
   l_ret_val := DBMS_SQL.EXECUTE(l_ds_cursor);
   DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
   l_sql_table.DELETE;
exception
   when others then       
    dsg_put_trace(dsm_id,tgt_id , '', '', sqlerrm(sqlcode), DSG_ERROR);
    DBMS_SQL.CLOSE_CURSOR(l_ds_cursor);
    l_sql_table.DELETE;
end;

end dsg_create_im_dm_package;

procedure dsg_generate_import_script
is
  dir_name varchar2(30);
  dump_name varchar2(255);
  f_handle utl_file.file_type;
  query_text varchar2(32767);
  dsg_app_cursor sys_refcursor;
  schema_name varchar2(128);
  dsm_id integer;
  tgt_id raw(16);
  tablespace_cursor sys_refcursor;
  tablespace_name varchar2(30);
  type tablespace_list is table of integer index by varchar2(30);
  tablespaces tablespace_list;
begin
  dsm_id := dsg_get_dsm_id;
  tgt_id := dsg_get_tgt_id;
  if dsg_get_create_import_script = false 
	or dsg_exec_option = DSG_EXEC_OPTION_INPLACE then
    return;
  end if;
  dump_name := dsg_get_export_dumpfile;
  dir_name := dsg_get_export_dir;
  f_handle := utl_file.fopen(dir_name, 'tdm_import.sql', 'w', 32767);
  utl_file.put_line(f_handle, 'SET SERVEROUTPUT ON', true);
  utl_file.put_line(f_handle, 'SET TIMING ON', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, 'create table ', true); 
  utl_file.put_line(f_handle, '   DSM$DB_DSG_DDLS_E ', true);
  utl_file.put_line(f_handle, '   (object_type varchar2(20), ', true);
  utl_file.put_line(f_handle, '   object_name varchar2(128), ', true);
  utl_file.put_line(f_handle, '   object_owner varchar2(128), ', true);
  utl_file.put_line(f_handle, '   table_name varchar2(128), ', true);
  utl_file.put_line(f_handle, '   otype varchar2(27), ', true);
  utl_file.put_line(f_handle, '   validated varchar2(13), ', true);
  utl_file.put_line(f_handle, '   object_ddl clob) ', true);
  utl_file.put_line(f_handle, '/', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, 'create or replace procedure DSM$DSG_STORE_DDL',true);
  utl_file.put_line(f_handle, '(object_type in varchar2,',true);
  utl_file.put_line(f_handle, ' object_name in varchar2, ',true);
  utl_file.put_line(f_handle, ' object_owner in varchar2, ', true);
  utl_file.put_line(f_handle, ' table_name in varchar2, ', true);
  utl_file.put_line(f_handle, ' otype in varchar2, ', true);
  utl_file.put_line(f_handle, ' validated in varchar2, ', true);
  utl_file.put_line(f_handle, ' object_ddl in clob) ',true);
  utl_file.put_line(f_handle, ' is ', true);
  utl_file.put_line(f_handle, ' v_cursor binary_integer; ', true);
  utl_file.put_line(f_handle, ' no_rows integer; ', true);
  utl_file.put_line(f_handle, ' ins_sql varchar2(32767); ', true);
  utl_file.put_line(f_handle, 'begin ', true);
  utl_file.put_line(f_handle, 'ins_sql:=''insert into DSM$DB_DSG_DDLS_E''||',true);
  utl_file.put_line(f_handle, ' '' values (:obj_type,'' ||', true);
  utl_file.put_line(f_handle, ' '':obj_name, :obj_owner, :tbl_name, ''||', true);
  utl_file.put_line(f_handle, ' '' :o_type, :validated, :obj_ddl)'';', true);
  utl_file.put_line(f_handle, 'v_cursor := dbms_sql.open_cursor;', true);
  utl_file.put_line(f_handle, 'dbms_sql.parse(v_cursor, ins_sql, dbms_sql.native);', true);
  utl_file.put_line(f_handle, 'dbms_sql.bind_variable(v_cursor, '':obj_type'', object_type);', true);
  utl_file.put_line(f_handle, 'dbms_sql.bind_variable(v_cursor, '':obj_name'', object_name);', true);
  utl_file.put_line(f_handle, 'dbms_sql.bind_variable(v_cursor, '':obj_owner'', object_owner);', true);
  utl_file.put_line(f_handle, 'dbms_sql.bind_variable(v_cursor, '':tbl_name'', table_name);', true);
  utl_file.put_line(f_handle, 'dbms_sql.bind_variable(v_cursor, '':o_type'', otype);', true);
  utl_file.put_line(f_handle, 'dbms_sql.bind_variable(v_cursor, '':validated'', validated);', true);
  utl_file.put_line(f_handle, 'dbms_sql.bind_variable(v_cursor, '':obj_ddl'', object_ddl);', true);
  utl_file.put_line(f_handle, 'no_rows := dbms_sql.execute(v_cursor);', true);
  utl_file.put_line(f_handle, 'dbms_sql.close_cursor(v_cursor);', true);
  utl_file.put_line(f_handle, 'exception ', true);
  utl_file.put_line(f_handle, '  when others then', true);
  utl_file.put_line(f_handle, '    dbms_sql.close_cursor(v_cursor);', true);
  utl_file.put_line(f_handle, '    raise;', true);
  utl_file.put_line(f_handle, 'end DSM$DSG_STORE_DDL;', true);
  utl_file.put_line(f_handle, '/', true);
  utl_file.put_line(f_handle, 'show errors;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, 'create or replace function DSM$IS_QUEUETABLE(owner in varchar2,', true);
  utl_file.put_line(f_handle, '                                              table_name in varchar2)', true);
  utl_file.put_line(f_handle, 'return boolean', true);
  utl_file.put_line(f_handle, 'AUTHID CURRENT_USER', true);
  utl_file.put_line(f_handle, 'as', true);
  utl_file.put_line(f_handle, ' query varchar2(32767);', true);
  utl_file.put_line(f_handle, ' flag number;', true);
  utl_file.put_line(f_handle, 'begin', true);
  utl_file.put_line(f_handle, ' query := ''select count(*) '' ||', true);
  utl_file.put_line(f_handle, '          ''from dba_queue_tables '' ||', true);
  utl_file.put_line(f_handle, '          ''where owner = '''''' || owner || '''''''' ||', true);
  utl_file.put_line(f_handle, '          '' and queue_table = '''''' || table_name || '''''''';', true);
  utl_file.put_line(f_handle, ' execute immediate query into flag;', true);
  utl_file.put_line(f_handle, ' if (flag = 0) then', true);
  utl_file.put_line(f_handle, '   return false;', true);
  utl_file.put_line(f_handle, ' else', true);
  utl_file.put_line(f_handle, '   return true;', true);
  utl_file.put_line(f_handle, ' end if;', true);
  utl_file.put_line(f_handle, ' end DSM$IS_QUEUETABLE;', true);
  utl_file.put_line(f_handle, '/', true);
  utl_file.put_line(f_handle, 'show errors;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, 'create or replace procedure DSM$MANAGE_TRIGGERS(l_owner varchar2,', true);
  utl_file.put_line(f_handle, '                                                opcode integer)', true);
  utl_file.put_line(f_handle, 'AUTHID CURRENT_USER', true);
  utl_file.put_line(f_handle, 'as', true);
  utl_file.put_line(f_handle, ' query_text varchar2(32767);', true);
  utl_file.put_line(f_handle, ' query_text1 varchar2(32767);', true);
  utl_file.put_line(f_handle, ' trigger_name varchar2(128);', true);
  utl_file.put_line(f_handle, ' trigger_owner varchar2(128);', true);
  utl_file.put_line(f_handle, ' type cursor is ref cursor;', true);
  utl_file.put_line(f_handle, ' c1 cursor;', true);
  utl_file.put_line(f_handle, 'begin', true);
  utl_file.put_line(f_handle, ' if opcode = 1 then', true);
  utl_file.put_line(f_handle, '    query_text1 := ''select trigger_name'' ||', true);
  utl_file.put_line(f_handle, '                  '' from dba_triggers '' ||', true);
  utl_file.put_line(f_handle, '                  ''where owner = '''''' || ', true);
  utl_file.put_line(f_handle, '                  ''l_owner || ''''''||', true);
  utl_file.put_line(f_handle, '                  ''and status = ''''ENABLED'''''';', true);
  utl_file.put_line(f_handle, '    open c1 for query_text1;', true);
  utl_file.put_line(f_handle, '    loop', true);
  utl_file.put_line(f_handle, '    fetch c1 into trigger_name;', true);
  utl_file.put_line(f_handle, '    exit when c1%notfound;', true);
  utl_file.put_line(f_handle, '    query_text := ''alter trigger '' ||', true);
  utl_file.put_line(f_handle, '                    l_owner || ''.'' ||', true);
  utl_file.put_line(f_handle, '          trigger_name || '' disable'';', true);
  utl_file.put_line(f_handle, '    begin', true);
  utl_file.put_line(f_handle, '      execute immediate query_text;', true);
  utl_file.put_line(f_handle, '    exception', true);
  utl_file.put_line(f_handle, '    when others then', true);
  utl_file.put_line(f_handle, '       dbms_output.put_line(query_text||'' ''||sqlerrm(sqlcode));', true);
  utl_file.put_line(f_handle, '    end;', true);
  utl_file.put_line(f_handle, '    DSM$DSG_STORE_DDL(''TRIGGER'',', true);
  utl_file.put_line(f_handle, '                      trigger_name, l_owner, null,null,', true);
  utl_file.put_line(f_handle, '                      null, null);', true);
  utl_file.put_line(f_handle, '    end loop;', true);
  utl_file.put_line(f_handle, '    close c1;', true);
  utl_file.put_line(f_handle, ' elsif opcode = 2 then ', true);
  utl_file.put_line(f_handle, '   query_text1 := ''select object_name, ''||', true);
  utl_file.put_line(f_handle, '                  ''object_owner from  DSM$DB_DSG_DDLS_E ''||', true);
  utl_file.put_line(f_handle, '                  ''where object_type =''''TRIGGER'''' '';', true);
  utl_file.put_line(f_handle, '   open c1 for query_text1;', true);
  utl_file.put_line(f_handle, '   loop', true);
  utl_file.put_line(f_handle, '   fetch c1 into trigger_name, trigger_owner;', true);
  utl_file.put_line(f_handle, '   exit when c1%notfound;', true);
  utl_file.put_line(f_handle, '   query_text := ''alter trigger '' || trigger_owner || ''.'' ||', true);
  utl_file.put_line(f_handle, '                   trigger_name || '' enable'';', true);
  utl_file.put_line(f_handle, '   begin', true);
  utl_file.put_line(f_handle, '     execute immediate query_text;', true);
  utl_file.put_line(f_handle, '   exception', true);
  utl_file.put_line(f_handle, '   when others then', true);
  utl_file.put_line(f_handle, '      dbms_output.put_line(query_text||'' ''||sqlerrm(sqlcode));', true);
  utl_file.put_line(f_handle, '   end;', true);
  utl_file.put_line(f_handle, '   end loop;', true);
  utl_file.put_line(f_handle, '   close c1;', true);
  utl_file.put_line(f_handle, ' end if;', true);
  utl_file.put_line(f_handle, 'end DSM$MANAGE_TRIGGERS;', true);
  utl_file.put_line(f_handle, '/', true);
  utl_file.put_line(f_handle, 'show errors;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, 'create or replace procedure DSM$MANAGE_CONSTRAINTS(l_owner varchar2,', true);
  utl_file.put_line(f_handle, '                                                   opcode integer,', true);
  utl_file.put_line(f_handle, '                                                   is_pri boolean)', true);
  utl_file.put_line(f_handle, 'AUTHID CURRENT_USER', true);
  utl_file.put_line(f_handle, 'as', true);
  utl_file.put_line(f_handle, ' query_text varchar2(32767);', true);
  utl_file.put_line(f_handle, ' query_text1 varchar2(32767);', true);
  utl_file.put_line(f_handle, ' query_text2 varchar2(32767);', true);
  utl_file.put_line(f_handle, ' iot_type varchar2(12);', true);
  utl_file.put_line(f_handle, ' object_owner varchar2(128);', true);
  utl_file.put_line(f_handle, ' table_name varchar2(128);', true);
  utl_file.put_line(f_handle, ' constraint_name varchar2(128);', true);
  utl_file.put_line(f_handle, ' otype varchar2(27);', true);
  utl_file.put_line(f_handle, ' validated varchar2(13);', true);
  utl_file.put_line(f_handle, ' type cursor is ref cursor;', true);
  utl_file.put_line(f_handle, ' c1 cursor;', true);
  utl_file.put_line(f_handle, ' c2 cursor;', true);
  utl_file.put_line(f_handle, 'begin', true);
  utl_file.put_line(f_handle, 'if opcode = 1 then', true);
  utl_file.put_line(f_handle, ' query_text1 := ''select table_name, iot_type '' ||', true);
  utl_file.put_line(f_handle, '                ''from dba_tables '' ||', true);
  utl_file.put_line(f_handle, '                ''where owner = ''''''  || l_owner || '''''''' ||', true);
  utl_file.put_line(f_handle, '		       '' and table_name not like ''''AQ$%'''''';', true);
  utl_file.put_line(f_handle, ' open c1 for query_text1;', true);
  utl_file.put_line(f_handle, ' loop', true);
  utl_file.put_line(f_handle, '   fetch c1 into table_name, iot_type;', true);
  utl_file.put_line(f_handle, '   exit when c1%notfound;', true);
  utl_file.put_line(f_handle, '   if(not (DSM$IS_QUEUETABLE(l_owner, table_name))) then', true);
  utl_file.put_line(f_handle, '     if(is_pri = TRUE) then', true);
  utl_file.put_line(f_handle, '       query_text2 := ''select constraint_name, constraint_type, validated '' ||', true);
  utl_file.put_line(f_handle, '                      ''from dba_constraints '' ||', true);
  utl_file.put_line(f_handle, '                      ''where owner = '''''' || l_owner || '''''''' ||', true);
  utl_file.put_line(f_handle, '                      '' and table_name = '''''' || table_name || '''''''' ||', true);
  utl_file.put_line(f_handle, '                      '' and constraint_type in (''''P'''', ''''U'''')''||', true);
  utl_file.put_line(f_handle, '                      '' and status=''''ENABLED'''''';', true);
  utl_file.put_line(f_handle, '       open c2 for query_text2;', true);
  utl_file.put_line(f_handle, '       loop', true);
  utl_file.put_line(f_handle, '         fetch c2 into constraint_name, otype, validated;', true);
  utl_file.put_line(f_handle, '         exit when c2%notfound;', true);
  utl_file.put_line(f_handle, '         if iot_type is null then', true);
  utl_file.put_line(f_handle, '           query_text := ''alter table '' || l_owner || ''.'' || table_name ||', true);
  utl_file.put_line(f_handle, '                         '' disable constraint '' || constraint_name;', true);
  utl_file.put_line(f_handle, '           begin', true);
  utl_file.put_line(f_handle, '             execute immediate query_text;', true);
  utl_file.put_line(f_handle, '           exception', true);
  utl_file.put_line(f_handle, '             when others then', true);
  utl_file.put_line(f_handle, '               dbms_output.put_line(query_text || '' '' || sqlerrm(sqlcode));', true);
  utl_file.put_line(f_handle, '           end;', true);
  utl_file.put_line(f_handle, '           DSM$DSG_STORE_DDL(''CONSTRAINT'',', true);
  utl_file.put_line(f_handle, '                             constraint_name, l_owner, table_name, otype,', true);
  utl_file.put_line(f_handle, '                             validated, null);', true);
  utl_file.put_line(f_handle, '         end if;', true);
  utl_file.put_line(f_handle, '         query_text := null;', true);
  utl_file.put_line(f_handle, '       end loop;', true);
  utl_file.put_line(f_handle, '       close c2;', true);
  utl_file.put_line(f_handle, '     else', true);
  utl_file.put_line(f_handle, '       query_text2 := ''select constraint_name, constraint_type, validated '' ||', true);
  utl_file.put_line(f_handle, '                      ''from dba_constraints '' ||', true);
  utl_file.put_line(f_handle, '                      ''where owner = '''''' || l_owner || '''''''' ||', true);
  utl_file.put_line(f_handle, '                      '' and table_name = '''''' || table_name || '''''''' ||', true);
  utl_file.put_line(f_handle, '                      '' and constraint_type not in (''''P'''', ''''U'''')''||', true);
  utl_file.put_line(f_handle, '                      '' and status=''''ENABLED'''''';', true);
  utl_file.put_line(f_handle, '       open c2 for query_text2;', true);
  utl_file.put_line(f_handle, '       loop', true);
  utl_file.put_line(f_handle, '         fetch c2 into constraint_name, otype, validated;', true);
  utl_file.put_line(f_handle, '         exit when c2%notfound;', true);
  utl_file.put_line(f_handle, '           query_text := ''alter table '' || l_owner || ''.'' || table_name ||', true);
  utl_file.put_line(f_handle, '                         '' disable constraint '' || constraint_name;', true);
  utl_file.put_line(f_handle, '         begin', true);
  utl_file.put_line(f_handle, '           execute immediate query_text;', true);
  utl_file.put_line(f_handle, '         exception', true);
  utl_file.put_line(f_handle, '           when others then', true);
  utl_file.put_line(f_handle, '             dbms_output.put_line(query_text || '' '' || sqlerrm(sqlcode));', true);
  utl_file.put_line(f_handle, '         end;', true);
  utl_file.put_line(f_handle, '           DSM$DSG_STORE_DDL(''CONSTRAINT'',', true);
  utl_file.put_line(f_handle, '                             constraint_name, l_owner, table_name, otype,', true);
  utl_file.put_line(f_handle, '                             validated, null);', true);
  utl_file.put_line(f_handle, '       end loop;', true);
  utl_file.put_line(f_handle, '       close c2;', true);
  utl_file.put_line(f_handle, '     end if;', true);
  utl_file.put_line(f_handle, '   end if;', true);
  utl_file.put_line(f_handle, ' end loop;', true);
  utl_file.put_line(f_handle, ' close c1;', true);
  utl_file.put_line(f_handle, 'elsif opcode = 2 then', true);
  utl_file.put_line(f_handle, '     if(is_pri = TRUE) then', true);
  utl_file.put_line(f_handle, '       query_text2 := ''select object_name, object_owner, table_name, '' ||', true);
  utl_file.put_line(f_handle, '                      ''validated from DSM$DB_DSG_DDLS_E '' ||', true);
  utl_file.put_line(f_handle, '                      ''where object_type=''''CONSTRAINT'''''' ||', true);
  utl_file.put_line(f_handle, '                      '' and otype in (''''P'''', ''''U'''')'';', true);
  utl_file.put_line(f_handle, '       open c2 for query_text2;', true);
  utl_file.put_line(f_handle, '       loop', true);
  utl_file.put_line(f_handle, '         fetch c2 into constraint_name, object_owner, table_name, validated;', true);
  utl_file.put_line(f_handle, '         exit when c2%notfound;', true);
  utl_file.put_line(f_handle, '           query_text := ''alter table '' || object_owner || ''.'' || table_name ||', true);
  utl_file.put_line(f_handle, '                         '' enable novalidate constraint '' || constraint_name;', true);
  utl_file.put_line(f_handle, '           begin', true);
  utl_file.put_line(f_handle, '             execute immediate query_text;', true);
  utl_file.put_line(f_handle, '             if validated = ''VALIDATED'' then ', true);
  utl_file.put_line(f_handle, '           query_text := ''alter table '' || object_owner || ''.'' || table_name ||', true);
  utl_file.put_line(f_handle, '                         '' modify constraint '' || constraint_name ||', true);
  utl_file.put_line(f_handle, '                         '' validate'';', true);
  utl_file.put_line(f_handle, '              execute immediate query_text;', true);
  utl_file.put_line(f_handle, '             end if;', true);
  utl_file.put_line(f_handle, '           exception', true);
  utl_file.put_line(f_handle, '             when others then', true);
  utl_file.put_line(f_handle, '               dbms_output.put_line(query_text || '' '' || sqlerrm(sqlcode));', true);
  utl_file.put_line(f_handle, '           end;', true);
  utl_file.put_line(f_handle, '         query_text := null;', true);
  utl_file.put_line(f_handle, '       end loop;', true);
  utl_file.put_line(f_handle, '       close c2;', true);
  utl_file.put_line(f_handle, '     else', true);
  utl_file.put_line(f_handle, '       query_text2 := ''select object_name, object_owner, table_name, '' ||', true);
  utl_file.put_line(f_handle, '                      ''validated from DSM$DB_DSG_DDLS_E '' ||', true);
  utl_file.put_line(f_handle, '                      ''where object_type=''''CONSTRAINT'''''' ||', true);
  utl_file.put_line(f_handle, '                      '' and otype not in (''''P'''', ''''U'''')'';', true);
  utl_file.put_line(f_handle, '       open c2 for query_text2;', true);
  utl_file.put_line(f_handle, '       loop', true);
  utl_file.put_line(f_handle, '         fetch c2 into constraint_name, object_owner, table_name, validated;', true);
  utl_file.put_line(f_handle, '         exit when c2%notfound;', true);
  utl_file.put_line(f_handle, '           query_text := ''alter table '' || object_owner || ''.'' || table_name ||', true);
  utl_file.put_line(f_handle, '                         '' enable novalidate constraint '' || constraint_name;', true);
  utl_file.put_line(f_handle, '           begin', true);
  utl_file.put_line(f_handle, '             execute immediate query_text;', true);
  utl_file.put_line(f_handle, '             if validated = ''VALIDATED'' then ', true);
  utl_file.put_line(f_handle, '           query_text := ''alter table '' || object_owner || ''.'' || table_name ||', true);
  utl_file.put_line(f_handle, '                         '' modify constraint '' || constraint_name ||', true);
  utl_file.put_line(f_handle, '                         '' validate'';', true);
  utl_file.put_line(f_handle, '              execute immediate query_text;', true);
  utl_file.put_line(f_handle, '             end if;', true);
  utl_file.put_line(f_handle, '           exception', true);
  utl_file.put_line(f_handle, '             when others then', true);
  utl_file.put_line(f_handle, '               dbms_output.put_line(query_text || '' '' || sqlerrm(sqlcode));', true);
  utl_file.put_line(f_handle, '           end;', true);
  utl_file.put_line(f_handle, '         query_text := null;', true);
  utl_file.put_line(f_handle, '       end loop;', true);
  utl_file.put_line(f_handle, '       close c2;', true);
  utl_file.put_line(f_handle, '     end if;', true);
  utl_file.put_line(f_handle, 'end if;', true);
  utl_file.put_line(f_handle, 'end DSM$MANAGE_CONSTRAINTS;', true);
  utl_file.put_line(f_handle, '/', true);
  utl_file.put_line(f_handle, 'show errors;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, 'define user_choice=2', true);
  utl_file.put_line(f_handle, 'define dump_dir_object=' || dir_name, true);
  utl_file.put_line(f_handle, 'prompt Chose the state of the schemas from below:', true);
  utl_file.put_line(f_handle, 'prompt 1 - None of the schemas exist.', true);
  utl_file.put_line(f_handle, 'prompt 2 - A part or all of the schemas exist.', true);
  utl_file.put_line(f_handle, 'prompt 3 - The schemas exist with complete metadata but no data.', true);
  utl_file.put_line(f_handle, 'accept user_choice number prompt ''enter choice (1/2/3): '';', true);
  utl_file.put_line(f_handle, 'accept dump_dir_object char prompt ''Enter directory object name: '';', true);
  if(dsg_get_enable_encryption) then
    utl_file.put_line(f_handle, 'accept encryptpassword char prompt ''Enter encrypt password: '';', true);
  end if;          
  utl_file.put_line(f_handle, 'declare', true);
  utl_file.put_line(f_handle, ' h number;', true);
  utl_file.put_line(f_handle, ' sts ku$_Status;', true);
  utl_file.put_line(f_handle, ' le ku$_LogEntry;', true);
  utl_file.put_line(f_handle, ' job_state varchar2(30);', true);
  utl_file.put_line(f_handle, ' ind number;', true);
  utl_file.put_line(f_handle, ' user_choice number := '||'&'||'user_choice;', true);
  utl_file.put_line(f_handle, ' type schema_list is table of varchar2(128);', true);
  utl_file.put_line(f_handle, ' schemas schema_list := schema_list();', true);
  utl_file.put_line(f_handle, ' type tablespace_list is table of varchar2(30);', true);
  utl_file.put_line(f_handle, ' tablespaces tablespace_list := tablespace_list();', true);
  utl_file.put_line(f_handle, ' default_tablespace varchar2(30);', true);
  utl_file.put_line(f_handle, ' tablespace_flag integer;', true);
  utl_file.put_line(f_handle, ' dump_name varchar2(255) := '||''''||dump_name||''';', true);
  utl_file.put_line(f_handle, ' l_index  pls_integer := 1;', true);
  utl_file.put_line(f_handle, ' l_comma_index pls_integer;', true);
  utl_file.put_line(f_handle, ' dump_dir varchar2(200) := '||'''&'||'dump_dir_object'||''';', true);
  if(dsg_get_enable_encryption) then
    utl_file.put_line(f_handle, ' encrypt_password varchar2(50) := '||'''&'||'encryptpassword'||''';', true);
  end if;          
  utl_file.put_line(f_handle, ' user_missing exception;', true);
  utl_file.put_line(f_handle, ' pragma exception_init(user_missing, -01918);', true);
  utl_file.put_line(f_handle, 'begin', true);
  query_text := 'select distinct(schema_name) ' ||
                'from ' || '"' || dsg_owner || '"' || '.' || dsg_app_tbl_name ||
                ' where dsm_id = ' || dsm_id ||
                ' and tgt_id = ''' || tgt_id || '''';
  open dsg_app_cursor for query_text;
  loop
    fetch dsg_app_cursor into schema_name;
    exit when dsg_app_cursor%notfound;
    utl_file.put_line(f_handle, ' schemas.extend;', true);
    utl_file.put_line(f_handle, ' schemas(schemas.last) := ' || '''' || schema_name || ''';', true);
  end loop;
  close dsg_app_cursor;
  
  query_text := 'select distinct default_tablespace ' ||
		'from dba_users ' ||
		'where username in ' ||
		'(select distinct schema_name ' ||
		'from ' || '"' || dsg_owner || '"' || '.' || dsg_app_tbl_name || ')';
  open tablespace_cursor for query_text;
  loop
    fetch tablespace_cursor into tablespace_name;
    exit when tablespace_cursor%notfound;
    tablespaces(tablespace_name) := 1;
  end loop;
  close tablespace_cursor;
  
  query_text := 'select distinct tablespace_name ' ||
                'from dba_tables ' ||
                'where owner in ' ||
                '(select distinct schema_name ' ||
                'from ' || '"' || dsg_owner || '"' || '.' || dsg_app_tbl_name || ') ' ||
		'and tablespace_name is not null';
  open tablespace_cursor for query_text;
  loop
    fetch tablespace_cursor into tablespace_name;
    exit when tablespace_cursor%notfound;
    tablespaces(tablespace_name) := 1;
  end loop;
  close tablespace_cursor;
  
  query_text := 'select distinct tablespace_name ' ||
                'from dba_indexes ' ||
                'where table_owner in ' ||
                '(select distinct schema_name ' ||
                'from ' || '"' || dsg_owner || '"' || '.' || dsg_app_tbl_name || ') ' ||
		'and tablespace_name is not null';
  open tablespace_cursor for query_text;
  loop
    fetch tablespace_cursor into tablespace_name;
    exit when tablespace_cursor%notfound;
    tablespaces(tablespace_name) := 1;   
  end loop;
  close tablespace_cursor;

  query_text := 'select distinct tablespace_name ' ||
                'from dba_lobs ' ||
                'where owner in ' ||
                '(select distinct schema_name ' ||
                'from ' || '"' || dsg_owner || '"' || '.' || dsg_app_tbl_name || ')';
  open tablespace_cursor for query_text;
  loop
    fetch tablespace_cursor into tablespace_name;
    exit when tablespace_cursor%notfound;
    tablespaces(tablespace_name) := 1;   end loop;
  close tablespace_cursor;  

  utl_file.put_line(f_handle, '', true);  
  tablespace_name := tablespaces.first;
  loop
    exit when tablespace_name is null;
    utl_file.put_line(f_handle, ' tablespaces.extend;', true);
    utl_file.put_line(f_handle, ' tablespaces(tablespaces.last) := ''' || tablespace_name || ''';', true);
    tablespace_name := tablespaces.next(tablespace_name);
  end loop;
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, ' execute immediate ''select default_tablespace from user_users'' into default_tablespace;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, ' if user_choice < 1 or user_choice > 3 then', true);
  utl_file.put_line(f_handle, '   dbms_output.put_line(''Invalid choice for state of schemas, going with option 2'');', true);
  utl_file.put_line(f_handle, '   user_choice := 2;', true);
  utl_file.put_line(f_handle, ' end if;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, ' if user_choice = 2 then', true);
  utl_file.put_line(f_handle, '   for ind in 1..schemas.last loop', true);
  utl_file.put_line(f_handle, '     begin', true);
  utl_file.put_line(f_handle, '       execute immediate ''drop user '' || schemas(ind) || '' cascade'';', true);
  utl_file.put_line(f_handle, '     exception', true);
  utl_file.put_line(f_handle, '       when user_missing then', true);
  utl_file.put_line(f_handle, '         dbms_output.put_line(''user '' || schemas(ind) || '' already dropped or missing'');', true);
  utl_file.put_line(f_handle, '     end;', true);
  utl_file.put_line(f_handle, '   end loop;', true);
  utl_file.put_line(f_handle, '     dbms_output.put_line(''schemas dropped'');', true);
  utl_file.put_line(f_handle, ' end if;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, ' if user_choice = 3 then', true);
  utl_file.put_line(f_handle, '   begin', true);
  utl_file.put_line(f_handle, '     for ind in 1..schemas.last loop', true);
  utl_file.put_line(f_handle, '       DSM$MANAGE_CONSTRAINTS(schemas(ind), 1, FALSE);', true);
  utl_file.put_line(f_handle, '     end loop;', true);
  utl_file.put_line(f_handle, '     for ind in 1..schemas.last loop', true);
  utl_file.put_line(f_handle, '       DSM$MANAGE_CONSTRAINTS(schemas(ind), 1, TRUE);', true);
  utl_file.put_line(f_handle, '     end loop;', true);
  utl_file.put_line(f_handle, '	    commit;', true);
  utl_file.put_line(f_handle, '     dbms_output.put_line(''constraints disabled'');', true);
  utl_file.put_line(f_handle, '   end;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, '   begin', true);
  utl_file.put_line(f_handle, '     for ind in 1..schemas.last loop', true);
  utl_file.put_line(f_handle, '       DSM$MANAGE_TRIGGERS(schemas(ind), 1);', true);
  utl_file.put_line(f_handle, '     end loop;', true);
  utl_file.put_line(f_handle, '     commit;', true);
  utl_file.put_line(f_handle, '     dbms_output.put_line(''triggers disabled'');', true);
  utl_file.put_line(f_handle, '   end;', true);
  utl_file.put_line(f_handle, ' end if;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, ' begin', true);
  utl_file.put_line(f_handle, '   h := dbms_datapump.open(''IMPORT'', ''FULL'');', true);
  --Bug# 24788568 - Running datamask on a large data volume generates ORA-39095 after 99 dmp files
  utl_file.put_line(f_handle, '   if instr(dump_name, '','') <> 0 then', true);
  utl_file.put_line(f_handle, '      dump_name := replace(rtrim(dump_name,'',''),'' '','''');', true);
  utl_file.put_line(f_handle, '      loop', true);
  utl_file.put_line(f_handle, '          l_comma_index := instr( dump_name||'','' , '','', l_index);', true);
  utl_file.put_line(f_handle, '          exit when l_comma_index = 0;', true);
  utl_file.put_line(f_handle, '          dbms_datapump.add_file(h, ', true);
  utl_file.put_line(f_handle, '                        substr(dump_name, l_index, l_comma_index - l_index),', true);
  utl_file.put_line(f_handle, '                        dump_dir, null, 1);', true);
  utl_file.put_line(f_handle, '          l_index := l_comma_index + 1;', true);
  utl_file.put_line(f_handle, '      end loop;', true);
  utl_file.put_line(f_handle, '   else', true);
  utl_file.put_line(f_handle, '      dbms_datapump.add_file(h, dump_name, dump_dir, null, 1);', true);
  utl_file.put_line(f_handle, '   end if;', true);
  utl_file.put_line(f_handle, '   dbms_datapump.add_file(h, ''tdm_import.log'', dump_dir, null, 3);', true);
  utl_file.put_line(f_handle, '   if user_choice = 3 then', true);
  utl_file.put_line(f_handle, '     dbms_datapump.set_parameter(h, ''INCLUDE_METADATA'', 0);', true);
  utl_file.put_line(f_handle, '   end if;', true);
  utl_file.put_line(f_handle, '--dbms_datapump.set_parameter(h, ''TABLE_EXISTS_ACTION'', ''REPLACE'');', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, '   for ind in 1..tablespaces.last loop', true);
  utl_file.put_line(f_handle, '     execute immediate ''select count(*) '' ||', true);
  utl_file.put_line(f_handle, '                       ''from dba_tablespaces '' ||', true);
  utl_file.put_line(f_handle, '                       ''where tablespace_name = '''''' ||', true);
  utl_file.put_line(f_handle, '                       tablespaces(ind) || '''''''' into tablespace_flag;', true);
  utl_file.put_line(f_handle, '     if tablespace_flag = 0 then', true);
  utl_file.put_line(f_handle, '       dbms_datapump.metadata_remap(h, ''REMAP_TABLESPACE'', tablespaces(ind), default_tablespace);', true);
  utl_file.put_line(f_handle, '     end if;', true);
  utl_file.put_line(f_handle, '   end loop;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, '   dbms_datapump.metadata_transform(h, ''STORAGE'', 1, ''TABLE'');', true);
  utl_file.put_line(f_handle, '', true);
  if(dsg_get_enable_encryption) then
   utl_file.put_line(f_handle, '   dbms_datapump.set_parameter(handle => h, name => ''ENCRYPTION_PASSWORD'', value => encrypt_password);', true);
  end if;
  utl_file.put_line(f_handle, '   dbms_datapump.start_job(h);', true);
  utl_file.put_line(f_handle, '   job_state := ''UNDEFINED'';', true);
  utl_file.put_line(f_handle, '   while (job_state != ''COMPLETED'') and (job_state != ''STOPPED'') loop', true);
  utl_file.put_line(f_handle, '     dbms_datapump.get_status(h, 13, -1, job_state, sts);', true);
  utl_file.put_line(f_handle, '   end loop;', true);
  utl_file.put_line(f_handle, '   dbms_datapump.detach(h);', true);
  utl_file.put_line(f_handle, ' exception', true);
  utl_file.put_line(f_handle, '   when others then', true);
  utl_file.put_line(f_handle, '     dbms_datapump.get_status(h, 8, 0, job_state, sts);', true);
  utl_file.put_line(f_handle, '     le := sts.error;', true);
  utl_file.put_line(f_handle, '     ind := le.first;', true);
  utl_file.put_line(f_handle, '     while ind is not null loop', true);
  utl_file.put_line(f_handle, '       dbms_output.put_line(le(ind).logText);', true);
  utl_file.put_line(f_handle, '       ind := le.next(ind);', true);
  utl_file.put_line(f_handle, '     end loop;', true);
  utl_file.put_line(f_handle, '     dbms_datapump.detach(h);', true);
  utl_file.put_line(f_handle, ' end;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, ' if user_choice = 3 then', true);
  utl_file.put_line(f_handle, '   begin', true);
  utl_file.put_line(f_handle, '     for ind in 1..schemas.last loop', true);
  utl_file.put_line(f_handle, '       DSM$MANAGE_CONSTRAINTS(schemas(ind), 2, TRUE);', true);
  utl_file.put_line(f_handle, '     end loop;', true);
  utl_file.put_line(f_handle, '     for ind in 1..schemas.last loop', true);
  utl_file.put_line(f_handle, '       DSM$MANAGE_CONSTRAINTS(schemas(ind), 2, FALSE);', true);
  utl_file.put_line(f_handle, '     end loop;', true);
  utl_file.put_line(f_handle, '     commit;', true);
  utl_file.put_line(f_handle, '     dbms_output.put_line(''constraints enabled'');', true);
  utl_file.put_line(f_handle, '   end;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, '   begin', true);
  utl_file.put_line(f_handle, '     for ind in 1..schemas.last loop', true);
  utl_file.put_line(f_handle, '       DSM$MANAGE_TRIGGERS(schemas(ind), 2);', true);
  utl_file.put_line(f_handle, '     end loop;', true);
  utl_file.put_line(f_handle, '     commit;', true);
  utl_file.put_line(f_handle, '     dbms_output.put_line(''triggers enabled'');', true);
  utl_file.put_line(f_handle, '   end;', true);
  utl_file.put_line(f_handle, ' end if;', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, 'end;', true);
  utl_file.put_line(f_handle, '/', true);
  utl_file.put_line(f_handle, '', true);
  utl_file.put_line(f_handle, 'DROP TABLE DSM$DB_DSG_DDLS_E PURGE;', true);
  utl_file.put_line(f_handle, 'DROP PROCEDURE DSM$DSG_STORE_DDL;', true);
  utl_file.put_line(f_handle, 'DROP FUNCTION DSM$IS_QUEUETABLE;', true);
  utl_file.put_line(f_handle, 'DROP PROCEDURE DSM$MANAGE_CONSTRAINTS;', true);
  utl_file.put_line(f_handle, 'DROP PROCEDURE DSM$MANAGE_TRIGGERS;', true);
  utl_file.fclose(f_handle);
end dsg_generate_import_script;

end dbms_dsm_dsg;
/
show errors;
