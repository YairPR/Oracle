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
  proc_drop('drop package pkg_dm_enmascarar');
  proc_drop('drop package pkg_dm_descubrimiento');
  proc_drop('drop package pkg_dm_func_mask');
  
  --------------------------------------------------------------------------
  -- 3) TABLAS HIJAS DE ENMASCARAMIENTO
  --------------------------------------------------------------------------
  proc_drop('drop table tdm_mask_trace purge');
 -- proc_drop('drop table tdm_mask_resultado purge');
  proc_drop('drop table tdm_mask_dep_estado purge');
  proc_drop('drop table tdm_mask_relacion_sync purge');
  proc_drop('drop table tdm_mask_regla_esp purge');
  proc_drop('drop table tdm_mask_solicitud purge');
 --- proc_drop('drop table tdm_mask_cache purge');

  --------------------------------------------------------------------------
  -- 4) TABLAS HIJAS DE DESCUBRIMIENTO
  --------------------------------------------------------------------------
  proc_drop('drop table tdm_dependencia_final purge');
  proc_drop('drop table tdm_columna_final purge');
  proc_drop('drop table tdm_dependencia_hist purge');
  proc_drop('drop table tdm_columna_hist purge');
  proc_drop('drop table tdm_ejecucion_scope purge');
  proc_drop('drop table tdm_ejecucion_error purge');

  --------------------------------------------------------------------------
  -- 5) TABLAS INDEPENDIENTES
  --------------------------------------------------------------------------
  proc_drop('drop table tdm_objeto_ctrl purge');
  proc_drop('drop table tdm_excepcion_col purge');
  proc_drop('drop table tdm_regla purge');

  --------------------------------------------------------------------------
  -- 6) TABLA PADRE
  --------------------------------------------------------------------------
  proc_drop('drop table tdm_ejecucion purge');

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