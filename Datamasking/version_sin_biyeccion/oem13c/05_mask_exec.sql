Rem
Rem $Header: emdb/source/oracle/sysman/emdrep/sql/db/latest/subset/subset_exec.sql /main/15 2017/02/08 02:47:45 gmeikand Exp $
Rem
Rem subset_exec.sql
Rem This script is not run on the repos.
Rem This script is the top level script that executes subsetting on the target.
Rem
Rem Copyright (c) 2010, 2017, Oracle and/or its affiliates. 
Rem All rights reserved.
Rem
Rem    NAME
Rem      subset_exec.sql - <one-line expansion of the name>
Rem
Rem    DESCRIPTION
Rem      <short description of component this file declares/defines>
Rem
Rem    NOTES
Rem      <other useful comments, qualifications, etc.>
Rem
Rem    MODIFIED   (MM/DD/YY)
Rem    haprpras    12/16/16 - Bug #24788568 - Running datamask on a large data
Rem                           volume generates ORA-39095 after 99 dmp files
Rem    ddsingha    05/05/16 - Project 65926: Global rule ER and Percentage rule
Rem                           for all tables ER
Rem    apkulshr    05/02/16 - Project 60844 : Full database import/export with
Rem                           masking and subsetting
Rem    pradeshm    07/22/15 - Fix bug 17410148 : Get custom directory path and
Rem                           create a directory
Rem    ddsingha    05/06/15 - XbranchMerge ddsingha_bug-20099692 from
Rem                           st_emgc_pt-13.1mstr
Rem    ddsingha    05/04/15 - Fix Bug 20099692: set escape \ is added to avoid
Rem                           adding escape character in format text before
Rem                           special characters
Rem    pkaliren    08/06/13 - Params file renaming
Rem    shmahaja    06/17/13 - adding spool file support
Rem    prakgupt    11/28/12 - Bug 15893126 - subset should prompt for dump file
Rem                           password in the command line
Rem    prakgupt    05/31/12 - Add support for dump file compression and
Rem                           encryption
Rem    shmahaja    03/19/12 - column rules
Rem    shmahaja    02/29/12 - adding inline mask support
Rem    shmahaja    12/15/11 - adding stub function to support 9i
Rem    shmahaja    12/14/11 - removing sqlldr call, instead calling
Rem			      the sql file for loading data
Rem    shmahaja    11/23/11 - dropping graph after subset execution
Rem    shmahaja    09/28/11 - the method is_graph_exists changed to
Rem                           graph_exists
Rem    shmahaja    09/03/11 - changing the method that creates shadow tables
Rem    shmahaja    08/31/11 - Enable parallel dml
Rem    shmahaja    04/01/11 - % row processing
Rem    shmahaja    01/13/11 - Changing the way the graph tables are moved
Rem    shmahaja    10/27/10 - adding generate import script support
Rem    bkuchibh    05/24/10 - Created
Rem

SET ECHO OFF
SET FEEDBACK 1
SET NUMWIDTH 10
SET LINESIZE 80
SET TRIMSPOOL ON
SET TAB OFF
SET PAGESIZE 100
SET TIMING ON
set serveroutput on
set verify off
set escape \

--this procedure will drop the objects required for compiling the subset package in 9i
--dropping here incase there is an error and subset ends before drop these objects
DECLARE
  v_sql varchar2(32767);
  v_version varchar2(17);
  obj_not_exist exception;
  syn_not_exist exception;
  pragma exception_init (obj_not_exist, -04043);
  pragma exception_init (syn_not_exist, -01432);
BEGIN
  v_sql := 'select version from v$instance';
  execute immediate v_sql into v_version;
  if v_version like '9.%' then
begin
v_sql := 'drop function ora_rowscn';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop package dbms_aqadm';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop package dbms_datapump';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop public synonym ku$_status';
execute immediate v_sql;
exception
when syn_not_exist then
null;
end;
begin
v_sql := 'drop type ku$_status';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop public synonym ku$_jobstatus';
execute immediate v_sql;
exception
when syn_not_exist then
null;
end;
begin
v_sql := 'drop type ku$_jobstatus';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop public synonym ku$_jobdesc';
execute immediate v_sql;
exception
when syn_not_exist then
null;
end;
begin
v_sql := 'drop type ku$_jobdesc';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop public synonym ku$_logentry';
execute immediate v_sql;
exception
when syn_not_exist then
null;
end;
begin
v_sql := 'drop type ku$_logentry';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop public synonym ku$_logline';
execute immediate v_sql;
exception
when syn_not_exist then
null;
end;
begin
v_sql := 'drop type ku$_logline';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
end if;
end;
/

--this procedure will create the objects required for compiling the subset package on 9i
DECLARE
  v_sql varchar2(32767);
  v_version varchar2(17);
  dp_pkgdef dbms_sql.varchar2s;
  dp_pkgbody dbms_sql.varchar2s;
  aqadm_pkgdef dbms_sql.varchar2s;
  aqadm_pkgbody dbms_sql.varchar2s;
  ddl_type dbms_sql.varchar2s;
  ddl_func dbms_sql.varchar2s;
  ddl_syn varchar2(32767);
  v_cur integer;
  ret_val integer;
BEGIN
  v_sql := 'select version from v$instance';
  execute immediate v_sql into v_version;
  if v_version like '9.%' then
    dbms_output.put_line('CREATING DUMMY OBJECTS FOR 9i');
    v_cur := dbms_sql.open_cursor();
    ddl_type.delete;
    ddl_type(nvl(ddl_type.last, 0) + 1) := 'CREATE OR REPLACE TYPE KU$_LOGLINE AS OBJECT (';
    ddl_type(nvl(ddl_type.last, 0) + 1) := '    logLineNumber NUMBER,';
    ddl_type(nvl(ddl_type.last, 0) + 1) := '    errorNumber NUMBER,';
    ddl_type(nvl(ddl_type.last, 0) + 1) := '    LogText VARCHAR2(2000))';
    dbms_sql.parse(v_cur, ddl_type, ddl_type.first, ddl_type.last, true, dbms_sql.native);
    ret_val := dbms_sql.execute(v_cur);

    ddl_syn := 'CREATE OR REPLACE PUBLIC SYNONYM KU$_LOGLINE FOR KU$_LOGLINE';
    execute immediate ddl_syn;

    ddl_type.delete;
    ddl_type(nvl(ddl_type.last, 0) + 1) := 'CREATE OR REPLACE TYPE KU$_LOGENTRY AS TABLE OF KU$_LOGLINE';
    dbms_sql.parse(v_cur, ddl_type, ddl_type.first, ddl_type.last, true, dbms_sql.native);
    ret_val := dbms_sql.execute(v_cur);

    ddl_syn := 'CREATE OR REPLACE PUBLIC SYNONYM KU$_LOGENTRY FOR KU$_LOGENTRY';
    execute immediate ddl_syn;

    ddl_type.delete;
    ddl_type(nvl(ddl_type.last, 0) + 1) := 'CREATE OR REPLACE TYPE KU$_JOBDESC AS OBJECT (';
    ddl_type(nvl(ddl_type.last, 0) + 1) := '    dummy_object NUMBER)';
    dbms_sql.parse(v_cur, ddl_type, ddl_type.first, ddl_type.last, true, dbms_sql.native);
    ret_val := dbms_sql.execute(v_cur);

    ddl_syn := 'CREATE OR REPLACE PUBLIC SYNONYM KU$_JOBDESC FOR KU$_JOBDESC';
    execute immediate ddl_syn;

    ddl_type.delete;
    ddl_type(nvl(ddl_type.last, 0) + 1) := 'CREATE OR REPLACE TYPE KU$_JOBSTATUS AS OBJECT (';
    ddl_type(nvl(ddl_type.last, 0) + 1) := '    dummy_object NUMBER)';
    dbms_sql.parse(v_cur, ddl_type, ddl_type.first, ddl_type.last, true, dbms_sql.native);
    ret_val := dbms_sql.execute(v_cur);

    ddl_syn := 'CREATE OR REPLACE PUBLIC SYNONYM KU$_JOBSTATUS FOR KU$_JOBSTATUS';
    execute immediate ddl_syn;

    ddl_type.delete;
    ddl_type(nvl(ddl_type.last, 0) + 1) := 'CREATE OR REPLACE TYPE KU$_STATUS AS OBJECT (';
    ddl_type(nvl(ddl_type.last, 0) + 1) := '    mask NUMBER,';
    ddl_type(nvl(ddl_type.last, 0) + 1) := '    wip KU$_LOGENTRY,';
    ddl_type(nvl(ddl_type.last, 0) + 1) := '    job_description KU$_JOBDESC,';
    ddl_type(nvl(ddl_type.last, 0) + 1) := '    job_status KU$_JOBSTATUS,';
    ddl_type(nvl(ddl_type.last, 0) + 1) := '    error KU$_LOGENTRY)';
    dbms_sql.parse(v_cur, ddl_type, ddl_type.first, ddl_type.last, true, dbms_sql.native);
    ret_val := dbms_sql.execute(v_cur);

    ddl_syn := 'CREATE OR REPLACE PUBLIC SYNONYM KU$_STATUS FOR KU$_STATUS';
    execute immediate ddl_syn;

    dp_pkgdef.delete;
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'create or replace package dbms_datapump';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'AS';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'KU$_FILE_TYPE_DUMP_FILE CONSTANT BINARY_INTEGER := 1;';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'KU$_FILE_TYPE_LOG_FILE CONSTANT BINARY_INTEGER := 3;';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'KU$_STATUS_WIP CONSTANT BINARY_INTEGER := 1;';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'KU$_STATUS_JOB_DESC CONSTANT BINARY_INTEGER := 2;';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'KU$_STATUS_JOB_STATUS CONSTANT BINARY_INTEGER := 4;';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'KU$_STATUS_JOB_ERROR CONSTANT BINARY_INTEGER := 8;';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'function open (';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  op in varchar2,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  v_mode in varchar2,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  remote_link in varchar2 default null,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  job_name in varchar2 default null,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  version in varchar2 default ''COMPATIBLE'',';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  compression in number default 1)';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'return number;';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'PROCEDURE DATA_FILTER (';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  handle IN NUMBER,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  name IN VARCHAR2,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  value IN NUMBER,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  table_name IN VARCHAR2 DEFAULT NULL,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  schema_name IN VARCHAR2 DEFAULT NULL);';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'PROCEDURE DATA_FILTER (';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  handle IN NUMBER,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  name IN VARCHAR2,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  value IN VARCHAR2,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  table_name IN VARCHAR2 DEFAULT NULL,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  schema_name IN VARCHAR2 DEFAULT NULL);';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'PROCEDURE METADATA_FILTER (';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  handle IN NUMBER,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  name IN VARCHAR2,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  value IN VARCHAR2,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  object_path IN VARCHAR2 DEFAULT NULL);';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'PROCEDURE SET_PARALLEL (';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  handle IN NUMBER,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  degree IN NUMBER);';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'PROCEDURE START_JOB (';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  handle IN NUMBER,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  skip_current IN NUMBER DEFAULT 0);';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'PROCEDURE DETACH (';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  handle IN NUMBER);';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'PROCEDURE ADD_FILE (';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  handle IN NUMBER,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  filename IN VARCHAR2,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  directory IN VARCHAR2,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  filesize IN VARCHAR2 DEFAULT NULL,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  filetype IN NUMBER DEFAULT 1);';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'PROCEDURE GET_STATUS (';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  handle IN NUMBER,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  mask IN BINARY_INTEGER,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  timeout IN NUMBER DEFAULT NULL,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  job_state OUT VARCHAR2,';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := '  status OUT KU$_STATUS);';
    dp_pkgdef(nvl(dp_pkgdef.last, 0) + 1) := 'end dbms_datapump;';
    dbms_sql.parse(v_cur, dp_pkgdef, dp_pkgdef.first, dp_pkgdef.last, true, dbms_sql.native);
    ret_val := dbms_sql.execute(v_cur);

    dp_pkgbody.delete;
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'create or replace package body dbms_datapump';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'AS';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'function open (';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        op in varchar2,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        v_mode in varchar2,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        remote_link in varchar2 default null,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        job_name in varchar2 default null,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        version in varchar2 default ''COMPATIBLE'',';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        compression in number default 1)';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'RETURN NUMBER';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'IS';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'BEGIN';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '  return 0;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'end open;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'PROCEDURE DATA_FILTER (';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        handle IN NUMBER,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        name IN VARCHAR2,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        value IN NUMBER,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        table_name IN VARCHAR2 DEFAULT NULL,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        schema_name IN VARCHAR2 DEFAULT NULL)';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'IS';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'BEGIN';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '  NULL;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'END DATA_FILTER;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'PROCEDURE DATA_FILTER (';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        handle IN NUMBER,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        name IN VARCHAR2,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        value IN VARCHAR2,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        table_name IN VARCHAR2 DEFAULT NULL,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        schema_name IN VARCHAR2 DEFAULT NULL)';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'IS';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'BEGIN';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '  NULL;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'END DATA_FILTER;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'PROCEDURE METADATA_FILTER (';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        handle IN NUMBER,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        name IN VARCHAR2,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        value IN VARCHAR2,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        object_path IN VARCHAR2 DEFAULT NULL)';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'IS';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'BEGIN';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '  NULL;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'END METADATA_FILTER;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'PROCEDURE SET_PARALLEL (';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        handle IN NUMBER,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        degree IN NUMBER)';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'IS';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'BEGIN';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '  NULL;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'END SET_PARALLEL;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'PROCEDURE START_JOB (';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        handle IN NUMBER,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        skip_current IN NUMBER DEFAULT 0)';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'IS';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'BEGIN';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '  NULL;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'END START_JOB;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'PROCEDURE DETACH (';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        handle IN NUMBER)';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'IS';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'BEGIN';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '  NULL;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'END DETACH;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'PROCEDURE ADD_FILE (';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        handle IN NUMBER,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        filename IN VARCHAR2,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        directory IN VARCHAR2,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        filesize IN VARCHAR2 DEFAULT NULL,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        filetype IN NUMBER DEFAULT 1)';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'IS';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'BEGIN';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '  NULL;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'END ADD_FILE;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'PROCEDURE GET_STATUS (';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        handle IN NUMBER,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        mask IN BINARY_INTEGER,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        timeout IN NUMBER DEFAULT NULL,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        job_state OUT VARCHAR2,';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '        status OUT KU$_STATUS)';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'IS';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'BEGIN';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := '  NULL;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'END GET_STATUS;';
    dp_pkgbody(nvl(dp_pkgbody.last, 0) + 1) := 'end dbms_datapump;';
    dbms_sql.parse(v_cur, dp_pkgbody, dp_pkgbody.first, dp_pkgbody.last, true, dbms_sql.native);
    ret_val := dbms_sql.execute(v_cur);

    aqadm_pkgdef.delete;
    aqadm_pkgdef(nvl(aqadm_pkgdef.last, 0) + 1) := 'CREATE OR REPLACE PACKAGE DBMS_AQADM';
    aqadm_pkgdef(nvl(aqadm_pkgdef.last, 0) + 1) := 'AS';
    aqadm_pkgdef(nvl(aqadm_pkgdef.last, 0) + 1) := 'TYPE AQ$_PURGE_OPTIONS_T IS RECORD (';
    aqadm_pkgdef(nvl(aqadm_pkgdef.last, 0) + 1) := '    block BOOLEAN DEFAULT FALSE,';
    aqadm_pkgdef(nvl(aqadm_pkgdef.last, 0) + 1) := '    delivery_mode PLS_INTEGER DEFAULT 0);';
    aqadm_pkgdef(nvl(aqadm_pkgdef.last, 0) + 1) := 'PROCEDURE PURGE_QUEUE_TABLE (';
    aqadm_pkgdef(nvl(aqadm_pkgdef.last, 0) + 1) := '    queue_table IN VARCHAR2,';
    aqadm_pkgdef(nvl(aqadm_pkgdef.last, 0) + 1) := '    purge_condition IN VARCHAR2,';
    aqadm_pkgdef(nvl(aqadm_pkgdef.last, 0) + 1) := '    purge_options IN AQ$_PURGE_OPTIONS_T);';
    aqadm_pkgdef(nvl(aqadm_pkgdef.last, 0) + 1) := 'END DBMS_AQADM;';
    dbms_sql.parse(v_cur, aqadm_pkgdef, aqadm_pkgdef.first, aqadm_pkgdef.last, true, dbms_sql.native);
    ret_val := dbms_sql.execute(v_cur);

    aqadm_pkgbody.delete;
    aqadm_pkgbody(nvl(aqadm_pkgbody.last, 0) + 1) := 'CREATE OR REPLACE PACKAGE BODY DBMS_AQADM';
    aqadm_pkgbody(nvl(aqadm_pkgbody.last, 0) + 1) := 'AS';
    aqadm_pkgbody(nvl(aqadm_pkgbody.last, 0) + 1) := 'PROCEDURE PURGE_QUEUE_TABLE (';
    aqadm_pkgbody(nvl(aqadm_pkgbody.last, 0) + 1) := '  queue_table IN VARCHAR2,';
    aqadm_pkgbody(nvl(aqadm_pkgbody.last, 0) + 1) := '  purge_condition IN VARCHAR2,';
    aqadm_pkgbody(nvl(aqadm_pkgbody.last, 0) + 1) := '  purge_options IN AQ$_PURGE_OPTIONS_T)';
    aqadm_pkgbody(nvl(aqadm_pkgbody.last, 0) + 1) := 'IS';
    aqadm_pkgbody(nvl(aqadm_pkgbody.last, 0) + 1) := 'BEGIN';
    aqadm_pkgbody(nvl(aqadm_pkgbody.last, 0) + 1) := '  NULL;';
    aqadm_pkgbody(nvl(aqadm_pkgbody.last, 0) + 1) := 'END PURGE_QUEUE_TABLE;';
    aqadm_pkgbody(nvl(aqadm_pkgbody.last, 0) + 1) := 'END DBMS_AQADM;';
    dbms_sql.parse(v_cur, aqadm_pkgbody, aqadm_pkgbody.first, aqadm_pkgbody.last, true, dbms_sql.native);
    ret_val := dbms_sql.execute(v_cur);

    ddl_func.delete;
    ddl_func(nvl(ddl_func.last, 0) + 1) := 'CREATE OR REPLACE FUNCTION ORA_ROWSCN';
    ddl_func(nvl(ddl_func.last, 0) + 1) := 'RETURN NUMBER';
    ddl_func(nvl(ddl_func.last, 0) + 1) := 'AS';
    ddl_func(nvl(ddl_func.last, 0) + 1) := 'BEGIN';
    ddl_func(nvl(ddl_func.last, 0) + 1) := 'RETURN 1;';
    ddl_func(nvl(ddl_func.last, 0) + 1) := 'END ORA_ROWSCN;';
    dbms_sql.parse(v_cur, ddl_func, ddl_func.first, ddl_func.last, true, dbms_sql.native);
    ret_val := dbms_sql.execute(v_cur);
  end if;
END;
/

ALTER SESSION ENABLE PARALLEL DML;
--running pre script even if empty
@@subset_pre_script.sql

--loading package
@@dsg_exec_pkg.sql

--defining parameters
@@tdm_exec_params.lst

spool &spool_file
-- set the subset execution options
begin
  dbms_dsm_dsg.dsg_set_graph_owner;

  dbms_dsm_dsg.dsg_set_dsm_id(&dsm_id);
  dbms_dsm_dsg.dsg_set_tgt_id(&tgt_id);
  dbms_dsm_dsg.dsg_set_exec_method(&exec_method);
  dbms_dsm_dsg.dsg_set_export_type(&export_type);
  dbms_dsm_dsg.dsg_set_export_dir(&export_dir);

  -- Bug #24788568 - Running datamask on a large data volume 
  --  generates ORA-39095 after 99 dmp files
  dbms_dsm_dsg.dsg_set_export_dumpfile(:export_dumpfile);
  dbms_dsm_dsg.dsg_set_export_log(&log_name);
  dbms_dsm_dsg.dsg_set_export_log_dir(&log_dir);

  -- Fix Bug 17410148 : Set directory path   
  dbms_dsm_dsg.dsg_set_custom_dir_path(&custom_dir_path);
  dbms_dsm_dsg.dsg_set_create_export_log(&generate_export_log);
  dbms_dsm_dsg.dsg_set_dump_size(&dump_size);
  dbms_dsm_dsg.dsg_set_graph_dumpfile(&graph_dump);
  dbms_dsm_dsg.dsg_set_create_import_script(&generate_import_script);
  dbms_dsm_dsg.dsg_set_max_threads(&max_threads);
  dbms_dsm_dsg.dsg_set_reentrant_mode(&reentrant_mode);
  dbms_dsm_dsg.dsg_set_force_clean(&force_clean_existing_tables);
  dbms_dsm_dsg.dsg_set_logging_option(&turn_logging_off);
  dbms_dsm_dsg.dsg_set_global_rule(&global_rule);
  dbms_dsm_dsg.dsg_set_drop_tables_option(&delete_tables_with_no_rows);
  dbms_dsm_dsg.dsg_set_do_inline_mask(&do_inline_mask);  
  dbms_dsm_dsg.dsg_set_output_level(&output_level);
  dbms_dsm_dsg.dsg_set_apply_column_rules(&apply_column_rules);
  dbms_dsm_dsg.dsg_set_enable_compression(&enable_compression);  
  dbms_dsm_dsg.dsg_set_enable_encryption(&enable_encryption);  
  dbms_dsm_dsg.dsg_set_encrypt_password(:encrypt_password);  
  
  --if dbms_dsm_dsg.dsg_get_reentrant_mode = TRUE then 
  --  dbms_output.put_line('Value of reentrant is '|| 'TRUE');
  --else
  --  dbms_output.put_line('Value of reentrant is '|| 'FALSE');
  --end if;
end;
/

-- error checks
-- error check simple execution vs re-entrant execution
   -- in the simple mode, if we see any remains of the graph we throw an error 
   -- and ask the user to clean the mess and run the script
   -- methods will be provided to cleanup the mess
   -- users can also chose force clean in the simple method: existing data will be dropped. 

   -- in the re-entrant mode, the user wants us to start from where we left over last time
   -- here we check the existing data/graph/status tracking tables before proceeding..
   -- routine to check whether subset graph and all its tables exists, status tables exist..
   -- to be developed as an independent function/procedure
begin
  if dbms_dsm_dsg.dsg_get_reentrant_mode = FALSE then
    if dbms_dsm_dsg.dsg_get_force_clean = FALSE then
      if  dbms_dsm_dsg.graph_exists = TRUE then
        dbms_standard.raise_application_error(dbms_dsm_dsg.DSG_GRAPH_ALREADY_EXITS,
        ' Prior subset execution graph tables exists, unable to proceed further');
      end if;
    else
      if  dbms_dsm_dsg.graph_exists = TRUE then
        dbms_dsm_dsg.drop_subset_graph;
      end if;
    end if;
  else
    dbms_output.put_line('validating the existing graph integrity');
    -- TBD
    --dbms_dsm_dsg.validate_graph_integrity;
  end if;
end;
/

-- create the exec progress and tracing/debugging tables
-- if they are already there this step will be a no-op

begin
  dbms_dsm_dsg.create_exec_track_tables;
  dbms_dsm_dsg.create_ddl_table;
end;
/

-- Log the variables that are driving the subset execution
-- Operation: CAPTURE_EXEC_OPTIONS -- Name=value pairs.



  
-- create or read from status tracking tables
   -- should be re-entrant
   -- ** all top interfaces are wrappers to internal interfaces
   -- if the execution is in re-entrant mode, they check to see if the step needs to be
   -- performed or not, if not they simply return.

-- load the subset graph
   -- should be re-entrant safe...

--creating graph tables on the target
@@graph_tables

--loading data into the graph tables
--host sqlldr \'&1\' control=&2/subset_graph.ctl data=&2/subset_graph.dmp log=&2/subset_graph.log
@@graph_data

-- refresh the stats -- optional
   -- should be re-entrant safe...
 
-- prepare for subset execution
   -- should be re-entrant safe...
begin
  dbms_dsm_dsg.dsg_remap_schemas;
end;
/

begin
  dbms_dsm_dsg.dsg_refresh_pk_names;
end;
/

begin
  dbms_dsm_dsg.dsg_create_shadow_tables;
end;
/
begin
  dbms_dsm_dsg.dsg_compute_percent_rules;
end;
/

-- compute the subset rows
   -- should be re-entrant safe...
   -- for each node we call process_node...
   -- this process node has to be re-entrant, if processed it will skip...
begin
  dbms_dsm_dsg.dsg_compute_subset;
end;
/

--calling the masking file just before calling export
  --will be empty is there is nothing to mask
@@inline_mask.sql

-- execute the subset
   -- gets executed every time: no fine granualrity 
   -- either success or failure as one unit.
begin
  dbms_dsm_dsg.dsg_execute_subset;
end;
/

--running post script even if empty
@@subset_post_script.sql

-- generate the import script
   -- only if exec method is export 
   -- and if generate_import_script option is true
begin
    dbms_dsm_dsg.dsg_generate_import_script;
end;
/

begin
  dbms_dsm_dsg.dsg_do_cleanup;
end;
/

--drop the temp objects created for 9i
DECLARE
  v_sql varchar2(32767);
  v_version varchar2(17);
  obj_not_exist exception;
  syn_not_exist exception;
  pragma exception_init (obj_not_exist, -04043);
  pragma exception_init (syn_not_exist, -01432);
BEGIN
  v_sql := 'select version from v$instance';
  execute immediate v_sql into v_version;
  if v_version like '9.%' then
begin
dbms_output.put_line('DROPPING DUMMY OBJECTS CREATED FOR 9i');
v_sql := 'drop function ora_rowscn';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop package dbms_aqadm';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop package dbms_datapump';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop public synonym ku$_status';
execute immediate v_sql;
exception
when syn_not_exist then
null;
end;
begin
v_sql := 'drop type ku$_status';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop public synonym ku$_jobstatus';
execute immediate v_sql;
exception
when syn_not_exist then
null;
end;
begin
v_sql := 'drop type ku$_jobstatus';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop public synonym ku$_jobdesc';
execute immediate v_sql;
exception
when syn_not_exist then
null;
end;
begin
v_sql := 'drop type ku$_jobdesc';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop public synonym ku$_logentry';
execute immediate v_sql;
exception
when syn_not_exist then
null;
end;
begin
v_sql := 'drop type ku$_logentry';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
begin
v_sql := 'drop public synonym ku$_logline';
execute immediate v_sql;
exception
when syn_not_exist then
null;
end;
begin
v_sql := 'drop type ku$_logline';
execute immediate v_sql;
exception
when obj_not_exist then
null;
end;
end if;
end;
/
