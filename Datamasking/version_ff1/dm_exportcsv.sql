-- =========================================================
-- dm_exportcsv.sql
-- Uso:
--   @dm_exportcsv ruta_salida esquema
--
-- Ejemplo:
--   @dm_exportcsv C:\ruta\export ESQUEMA
-- =========================================================

undefine 1
undefine 2
undefine V_RUTA
undefine V_ESQUEMA
undefine V_DBNAME
undefine V_FECHA
undefine V_FILE

set echo off
set verify off
set feedback off
set heading off
set termout off
set pagesize 0
set linesize 32767
set trimspool on
set serveroutput on size unlimited
set define on
set tab off

whenever sqlerror continue none

column 1_col new_value 1 noprint
column 2_col new_value 2 noprint
select null as 1_col, null as 2_col from dual where 1=2;

column final_ruta    new_value V_RUTA    noprint
column final_esquema new_value V_ESQUEMA noprint
column v_dbname      new_value V_DBNAME      noprint
column v_fecha       new_value V_FECHA       noprint
column v_file        new_value V_FILE        noprint

select replace(replace(nvl(trim('&1'), '.'),'\','/'), '"', '') final_ruta,
       upper(trim('&2')) final_esquema
from dual;

select upper(value) v_dbname
from v$parameter
where name = 'db_unique_name';

select to_char(sysdate,'YYYYMMDD_HH24MISS') v_fecha
from dual;

select '&&V_RUTA/' || '&&V_DBNAME' || '_' || '&&V_ESQUEMA' || '_DESCUB_' || '&&V_FECHA' || '.csv' v_file
from dual;

set termout on
set heading on
set pagesize 100

prompt Resumen por identificador:
set heading on
set pagesize 200
column identificador format a35
column total format 999999999

select identificador,
       count(*) total
from tdm_columna_final
where owner_name = '&&V_ESQUEMA'
group by identificador
order by total desc, identificador;

set heading off
set pagesize 0

set termout off
spool "&&V_FILE"

prompt OWNER_NAME,TABLE_NAME,COLUMN_NAME,IDENTIFICADOR,ENMASCARAR

select
    '"' || replace(nvl(owner_name,''), '"', '""') || '",' ||
    '"' || replace(nvl(table_name,''), '"', '""') || '",' ||
    '"' || replace(nvl(column_name,''), '"', '""') || '",' ||
    '"' || replace(nvl(identificador,''), '"', '""') || '",' ||
    '"' || replace(nvl(enmascarar,''), '"', '""') || '"'
from tdm_columna_final
where owner_name = '&&V_ESQUEMA'
order by owner_name, table_name, column_name;

spool off
set termout on

declare
    v_tabla_existe      number := 0;
    v_esquema_existe    number := 0;
    v_total_columnas    number := 0;
    v_total_tablas      number := 0;
    v_total_y           number := 0;
begin
    if trim('&&V_ESQUEMA') is null or trim('&&V_ESQUEMA') = '' then
        raise_application_error(
            -20000,
            'Uso: @dm_exportcsv RUTA_SALIDA ESQUEMA'
        );
    end if;
    select count(*)
      into v_tabla_existe
      from dba_tables
     where owner = 'ASTSYSADMIN'
       and table_name = 'TDM_COLUMNA_FINAL';

    if v_tabla_existe = 0 then
        raise_application_error(
            -20001,
            'No existe la tabla ASTSYSADMIN.TDM_COLUMNA_FINAL'
        );
    end if;

    select count(*)
      into v_esquema_existe
      from tdm_columna_final
     where owner_name = '&&V_ESQUEMA';

    if v_esquema_existe = 0 then
        raise_application_error(
            -20002,
            'No existe el esquema [' || '&&V_ESQUEMA' || '] dentro de TDM_COLUMNA_FINAL'
        );
    end if;

    select count(*),
           count(distinct table_name),
           sum(case when nvl(enmascarar,'N') = 'Y' then 1 else 0 end)
      into v_total_columnas,
           v_total_tablas,
           v_total_y
      from tdm_columna_final
     where owner_name = '&&V_ESQUEMA';

    dbms_output.put_line('====================================================');
    dbms_output.put_line('Export CSV Descubrimiento');
	dbms_output.put_line('Base                    : &&V_DBNAME');
    dbms_output.put_line('Esquema                 : &&V_ESQUEMA');
    dbms_output.put_line('Ruta salida             : &&V_FILE');
    dbms_output.put_line('Columnas a exportar     : ' || v_total_columnas);
    dbms_output.put_line('Tablas afectadas        : ' || v_total_tablas);
    dbms_output.put_line('Con ENMASCARAR = Y      : ' || nvl(v_total_y,0));
    dbms_output.put_line('====================================================');
end;
/
prompt
prompt Archivo generado correctamente:
prompt
undefine 1
undefine 2
undefine V_RUTA
undefine V_ESQUEMA
undefine V_DBNAME
undefine V_FECHA
undefine V_FILE