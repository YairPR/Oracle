DECLARE

  l_dp_handle NUMBER;
  l_last_job_state VARCHAR2(30) := 'UNDEFINED';
  l_job_state VARCHAR2(30) := 'UNDEFINED';
  EXCLUDE_USERS VARCHAR2(30) := 'ACADEMICO';
  l_sts  KU$_STATUS;
  v_logs ku$_LogEntry;
  v_row  PLS_INTEGER;
  v_job_state varchar2(4000);

BEGIN

  l_dp_handle := DBMS_DATAPUMP.open(operation => 'IMPORT', job_mode => 'SCHEMA', job_name => null, version => 'COMPATIBLE');

  DBMS_DATAPUMP.add_file(handle => l_dp_handle,filename  => '&2',directory => 'DATA_PUMP_DIR');

  DBMS_DATAPUMP.add_file(handle => l_dp_handle, filename => 'IMPORT-'||'&3'||'.LOG', directory => 'DATA_PUMP_DIR', filetype => 3);

  DBMS_DATAPUMP.set_debug(debug_flags  => to_number('1FF0300','XXXXXXXXXXXXX'),version_flag => 1);

  DBMS_DATAPUMP.metadata_filter(l_dp_handle,'NAME_EXPR','NOT IN (SELECT NAME FROM sys.OBJ$ WHERE TYPE# IN (47,48,49,50,66,67,68,69,71,72,74))',object_path => 'PROCOBJ');
  dbms_datapump.metadata_filter(l_dp_handle,'EXCLUDE_PATH_EXPR','IN (''JOB'')');

  DBMS_DATAPUMP.METADATA_FILTER(l_dp_handle,'SCHEMA_EXPR','IN (''UTEC'',''ACADEMICO'',''COMERCIAL'',''CONFIGURACION'',''ENOTIFICA'',''GENERAL'',''PROGRAMACION'',''SEGURIDAD'',''AUDITORIA'',''MATRICULA'',''PREMATRICULA'',''TIMETABLE'',''CALENDAR'',''FINANZAS'',''EGRESADO'',''TRAMITE'',''RESERVA'',''WORKFLOW'')');

  DBMS_DATAPUMP.start_job(l_dp_handle);
  DBMS_DATAPUMP.WAIT_FOR_JOB(l_dp_handle, v_job_state);

  DBMS_OUTPUT.PUT_LINE(v_job_state);

EXCEPTION
  WHEN OTHERS THEN
    DBMS_DATAPUMP.get_status(NULL, 8, 0, v_job_state, l_sts);
    v_logs := l_sts.error;

    v_row := v_logs.FIRST;
    LOOP
      EXIT WHEN v_row IS NULL;
      dbms_output.put_line('logLineNumber=' || v_logs(v_row).logLineNumber);
      dbms_output.put_line('errorNumber=' || v_logs(v_row).errorNumber);
      dbms_output.put_line('LogText=' || v_logs(v_row).LogText);
      v_row := v_logs.NEXT(v_row);
    END LOOP;
    RAISE;
END;
/
 
