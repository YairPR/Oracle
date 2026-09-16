set serveroutput on size unlimited
set feedback on
set verify off

prompt =========================================================
prompt LIMPIEZA TOTAL DESCUBRIMIENTO + ENMASCARAMIENTO
prompt =========================================================

alter session set current_schema = ASTSYSADMIN;

declare
  procedure proc_drop(p_sql varchar2) is
  begin
    dbms_output.put_line('Intentando: ' || p_sql);
    execute immediate p_sql;
    dbms_output.put_line('OK');
  exception
    when others then
      dbms_output.put_line('ERROR: ' || sqlerrm);
  end;
begin

  --------------------------------------------------------------------------
  -- 2) PAQUETES
  --------------------------------------------------------------------------
  proc_drop('drop package pkg_dm_export');
  proc_drop('drop package pkg_dm_enmascarar');
  proc_drop('drop package pkg_dm_descubrimiento');
  proc_drop('drop package pkg_dm_func_mask');
  proc_drop('drop package pkg_dm_trazabilidad');
  
  --------------------------------------------------------------------------
  -- 3) TABLAS HIJAS DE ENMASCARAMIENTO
  --------------------------------------------------------------------------
  proc_drop('drop table tdm_mask_trace cascade constraints purge');
  proc_drop('drop table tdm_mask_dep_estado cascade constraints purge');
  proc_drop('drop table tdm_mask_relacion_sync cascade constraints purge');
  proc_drop('drop table tdm_mask_regla_esp cascade constraints purge');
  proc_drop('drop table tdm_mask_solicitud cascade constraints purge');
  proc_drop('drop table tdm_secreto cascade constraints purge');
  -- Legacy (versiones previas a FF1): se ignora si no existe
  proc_drop('drop table tdm_mask_key_map cascade constraints purge');

  --------------------------------------------------------------------------
  -- 4) TABLAS HIJAS DE DESCUBRIMIENTO
  --------------------------------------------------------------------------
  proc_drop('drop table tdm_dependencia_final cascade constraints purge');
  proc_drop('drop table tdm_columna_final cascade constraints purge');
  proc_drop('drop table tdm_dependencia_hist cascade constraints purge');
  proc_drop('drop table tdm_columna_hist cascade constraints purge');
  proc_drop('drop table tdm_ejecucion_scope cascade constraints purge');
  proc_drop('drop table tdm_ejecucion_error cascade constraints purge');

  --------------------------------------------------------------------------
  -- 5) TABLAS INDEPENDIENTES
  --------------------------------------------------------------------------
  proc_drop('drop table tdm_objeto_ctrl cascade constraints purge');
  proc_drop('drop table tdm_excepcion_col cascade constraints purge');
  proc_drop('drop table tdm_regla cascade constraints purge');

  --------------------------------------------------------------------------
  -- 6) TABLA PADRE
  --------------------------------------------------------------------------
  proc_drop('drop table tdm_ejecucion cascade constraints purge');

  --------------------------------------------------------------------------
  -- 7) SECUENCIAS MASKING
  --------------------------------------------------------------------------
  proc_drop('drop sequence seq_dm_mask_trace');
  proc_drop('drop sequence seq_dm_mask_relacion_sync');
  proc_drop('drop sequence seq_dm_mask_regla_esp');
  proc_drop('drop sequence seq_dm_mask_solicitud');

  --------------------------------------------------------------------------
  -- 8) SECUENCIAS DISCOVERY
  --------------------------------------------------------------------------
  proc_drop('drop sequence seq_dm_dependencia_hist');
  proc_drop('drop sequence seq_dm_columna_hist');
  proc_drop('drop sequence seq_dm_ejecucion_scope');
  proc_drop('drop sequence seq_dm_ejecucion_err');
  proc_drop('drop sequence seq_dm_regla');
  proc_drop('drop sequence seq_dm_ejecucion');
 
  --------------------------------------------------------------------------
  -- 9) ROL
  --------------------------------------------------------------------------
  proc_drop('drop role ROL_DATAMASKING');
end;
/