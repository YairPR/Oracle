undefine V_ARG1
undefine V_ESQUEMA

set serveroutput on size unlimited
set verify off
set feedback off
set define on
set linesize 200
set pagesize 100
set trimspool on
set tab off

column ejecucion_id    format 999999999
column fase_proceso    format a16
column estado          format a12
column fecha_inicio    format a20
column edad_minutos    format 999999.0
column ultimo_objeto   format a30
column ultimo_paso     format a24
column error_count     format 9999999

prompt =========================================================
prompt dm_liberar_ejecucion_activa - Libera ejecuciones EJECUTANDO obsoletas
prompt Uso:
prompt   @dm_liberar_ejecucion_activa ESQUEMA
prompt Ejemplo:
prompt   @dm_liberar_ejecucion_activa SRI2006
prompt =========================================================
prompt Por que existe: TDM_EJECUCION tiene un indice unico funcional
prompt (UQ_TDM_EJEC_ESQ_ACTIVO) que solo permite UNA fila con
prompt estado=EJECUTANDO por esquema a la vez. Si un cliente SQL*Plus se
prompt corta a mitad de un enmascarado (Ctrl+C, cierre de la ventana, caida
prompt de red) DESPUES de que la ejecucion ad-hoc quedo insertada (y
prompt comprometida con COMMIT) pero ANTES de que el proceso la cerrara
prompt como FINALIZADO/ERROR, esa fila queda EJECUTANDO para siempre.
prompt A partir de ahi, CUALQUIER intento nuevo de enmascarar ese mismo
prompt esquema (incluido dm_enmascara_force) choca con ORA-00001 contra
prompt esa misma restriccion -- en TODAS las tablas, no solo en una.
prompt
prompt Este script NO borra nada ni toca datos ya enmascarados: solo
prompt cierra (estado=ABORTADA) la(s) fila(s) de control EJECUTANDO que
prompt hayan quedado huerfanas, para liberar el esquema. Revise la lista
prompt de abajo ANTES de continuar -- si alguna fila corresponde a un
prompt proceso que sabe que sigue vivo de verdad (otra sesion, un job),
prompt NO la cierre: cancele este script (Ctrl+C aqui SI es seguro, no se
prompt ha hecho ningun cambio todavia) y espere a que termine sola.
prompt =========================================================

column final_p1 new_value V_ARG1 noprint
select trim('&1') final_p1 from dual;

prompt
prompt --- Ejecuciones EJECUTANDO encontradas para el esquema indicado ---

declare
  v_esquema varchar2(128) := upper(trim('&&V_ARG1'));
begin
  if v_esquema is null then
    raise_application_error(-20401, 'Uso: @dm_liberar_ejecucion_activa ESQUEMA');
  end if;
end;
/

select ejecucion_id,
       fase_proceso,
       estado,
       to_char(fecha_inicio,'YYYY-MM-DD HH24:MI:SS') as fecha_inicio,
       round((sysdate - cast(fecha_inicio as date)) * 1440, 1) as edad_minutos,
       ultimo_objeto,
       ultimo_paso,
       error_count
  from tdm_ejecucion
 where esquema_objetivo = upper(trim('&&V_ARG1'))
   and estado = 'EJECUTANDO'
 order by fecha_inicio;

prompt
prompt --- Cerrando (ABORTADA) las filas de arriba ---

declare
  v_esquema varchar2(128) := upper(trim('&&V_ARG1'));
  v_n       pls_integer;
begin
  select count(*) into v_n
    from tdm_ejecucion
   where esquema_objetivo = v_esquema
     and estado = 'EJECUTANDO';

  if v_n = 0 then
    dbms_output.put_line('No hay ejecuciones EJECUTANDO para ' || v_esquema || ' -- nada que liberar.');
  else
    update tdm_ejecucion
       set estado    = 'ABORTADA',
           fecha_fin = systimestamp,
           ultimo_paso = 'CERRADA_MANUAL_DBA_' || to_char(systimestamp,'YYYYMMDDHH24MISS')
     where esquema_objetivo = v_esquema
       and estado = 'EJECUTANDO';
    commit;
    dbms_output.put_line(v_n || ' ejecucion(es) EJECUTANDO de ' || v_esquema || ' marcada(s) como ABORTADA.');
    dbms_output.put_line('El esquema queda libre: ya puede volver a correr @dm_enmascara_force ' || v_esquema || '.');
  end if;
end;
/

undefine 1
undefine V_ARG1
undefine V_ESQUEMA
