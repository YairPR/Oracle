undefine V_ARG1
undefine V_ESQUEMA

set verify off
set feedback off
set define on
set trimspool on
set tab off

Rem =========================================================================
Rem dm_conteo_real.sql -- SELECT COUNT(*) real, tabla por tabla, para TODAS
Rem las tablas de un esquema. Cada fila del resultado muestra TABLA y
Rem REGISTROS juntos (sin PL/SQL, sin estimaciones: un
Rem "select 'ESQUEMA.TABLA' as tabla, count(*) as registros from
Rem ESQUEMA.TABLA;" por tabla, uno detras de otro).
Rem =========================================================================
Rem Uso:
Rem   @dm_conteo_real ESQUEMA
Rem Ejemplo:
Rem   @dm_conteo_real SRI2006
Rem =========================================================================
Rem v2 (corrige v1): v1 dejaba PAGESIZE/HEADING en sus valores normales
Rem durante la generacion del sub-script. SQL*Plus repite el encabezado de
Rem columna (el alias, mas la linea de guiones) cada PAGESIZE filas, y esas
Rem repeticiones quedaban escritas DENTRO del .sql generado, partiendolo a
Rem la mitad cada ~25 tablas (de ahi el "SP2-0042: comando desconocido
Rem GEN_SQL" intercalado). v2 apaga heading y pagesize SOLO mientras se
Rem genera el archivo, y los deja normales para la ejecucion real.
Rem =========================================================================

column final_p1 new_value V_ARG1 noprint
select trim('&1') final_p1 from dual;

declare
  v_esquema varchar2(128) := upper(trim('&&V_ARG1'));
begin
  if v_esquema is null then
    raise_application_error(-20501, 'Uso: @dm_conteo_real ESQUEMA');
  end if;
end;
/

column c_esquema new_value V_ESQUEMA noprint
select upper(trim('&&V_ARG1')) as c_esquema from dual;

set termout off
set heading off
set pagesize 0
set linesize 32767

spool _dm_conteo_real_gen.sql

select 'select ' || chr(39) || owner || '.' || table_name || chr(39) ||
       ' as tabla, count(*) as registros from ' || owner || '.' || table_name || ';'
  from dba_tables
 where owner = '&&V_ESQUEMA'
 order by table_name;

spool off

set pagesize 100
set heading on
set linesize 150
set termout on

column tabla     format a40
column registros format 999,999,999,999

prompt
prompt =========================================================
prompt Conteo real por tabla -- esquema &&V_ESQUEMA
prompt =========================================================
prompt

@@_dm_conteo_real_gen.sql

undefine 1
undefine V_ARG1
undefine V_ESQUEMA
