undefine V_ARG1
undefine V_CONFIRMA

set serveroutput on size unlimited
set verify off
set feedback off
set define on
set linesize 200
set pagesize 100
set tab off
Rem 2026-09-22: se fija current_schema al esquema del motor (antes este
Rem script no lo hacia -- nunca lo necesito, todo ya iba con owner
Rem calificado) porque la
Rem nueva llamada a pkg_dm_mantenimiento.* (ver mas abajo) va SIN calificar y
Rem necesita resolver contra ese esquema.
Rem --- Esquema del motor: se detecta solo (ASTSYSADMIN o ACC_ADMIN), sin setear nada a mano ---
define esquemaast = '__NO_DETECTADO__'
define tbsast     = '__NO_DETECTADO__'
column v_esquemaast noprint new_value esquemaast
column v_tbsast      noprint new_value tbsast
select username as v_esquemaast, nvl(default_tablespace,username) as v_tbsast
  from (select username, default_tablespace from dba_users
         where username in ('ASTSYSADMIN','ACC_ADMIN')
         order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
 where rownum = 1;
declare
begin
  if upper(trim('&&esquemaast')) = '__NO_DETECTADO__' then
    raise_application_error(-20001,'No se encontro ni ASTSYSADMIN ni ACC_ADMIN en DBA_USERS -- no se puede determinar el esquema del motor DATAMASKING en esta base.');
  end if;
end;
/
alter session set current_schema = &&esquemaast;

prompt =========================================================
prompt dm_reset_ejecuciones - RESET COMPLETO de historico de ejecuciones
prompt Uso:
prompt   @dm_reset_ejecuciones CONFIRMAR
prompt =========================================================
prompt PELIGRO: este script hace TRUNCATE de TODAS las tablas de control
prompt de ejecucion (TDM_EJECUCION y sus hijas), TDM_SECRETO (peppers), y
prompt limpia las tareas DBMS_PARALLEL_EXECUTE huerfanas (TDM_%).
prompt
prompt Estas tablas NO estan filtradas por esquema -- un TRUNCATE aqui
prompt borra el historico de TODOS los esquemas que se hayan probado con
prompt este motor, no solo el que estas probando ahora. Es para entornos
prompt de prueba/desarrollo, nunca para un ambiente cuyo historico de
prompt ejecuciones deba conservarse para auditoria.
prompt
prompt NO toca los datos ya enmascarados en las tablas de negocio (esos
prompt quedan como quedaron), ni TDM_EXCEPCION_COL, TDM_REGLA, ni ningun
prompt catalogo de configuracion -- solo el historico operativo de
prompt ejecuciones/solicitudes/trazas/peppers.
prompt
prompt Orden de TRUNCATE (de hija a padre, para no chocar con ORA-02266):
prompt   1) TDM_MASK_DEP_ESTADO
prompt   2) TDM_MASK_TRACE
prompt   3) TDM_EJECUCION_ERROR
prompt   4) TDM_MASK_SOLICITUD
prompt   5) TDM_EJECUCION_SCOPE
prompt   6) TDM_COLUMNA_HIST
prompt   7) TDM_DEPENDENCIA_HIST
prompt   8) TDM_EJECUCION
prompt   9) TDM_SECRETO (sin FK, pero se limpia al final por prudencia)
prompt
prompt Como salvaguarda, debe escribir la palabra CONFIRMAR como argumento.
prompt =========================================================

column final_p1 new_value V_ARG1 noprint
select trim('&1') final_p1 from dual;

declare
  v_confirma varchar2(30) := upper(trim('&&V_ARG1'));
begin
  if v_confirma is null or v_confirma <> 'CONFIRMAR' then
    raise_application_error(-20501,
      'Uso: @dm_reset_ejecuciones CONFIRMAR  (debe escribir la palabra CONFIRMAR, en mayusculas, para proceder).');
  end if;
end;
/

prompt
prompt --- Tareas DBMS_PARALLEL_EXECUTE (TDM_%) antes de truncar ---

-- FIX 2026-09-29 (hallazgo real, pregunta directa del usuario sobre tareas
-- "zombie"): el patron 'TASK_DM_%' nunca coincidio con el nombre de tarea
-- que realmente genera proc_dm_ejecuta_update_seguro en 05_dm_pkg_enmascarar.sql
-- desde el fix del 09/18/26 (GUID-based: 'TDM_'||SUBSTR(RAWTOHEX(SYS_GUID()),1,26)).
-- Esta limpieza llevaba desde entonces reportando "0 tareas eliminadas" de
-- forma silenciosa incluso cuando SI habia tareas huerfanas reales en
-- USER_PARALLEL_EXECUTE_TASKS (p.ej. tras una caida de sesion real que dejo
-- una tarea creada sin llegar nunca a su DROP_TASK). Corregido al prefijo real.
-- FIX 2026-10-10: user_parallel_execute_tasks muestra las tareas del CURRENT_USER (el DBA que
-- ejecuta este script), no las del esquema del motor: current_schema no cambia el usuario.
-- Se consulta DBA_PARALLEL_EXECUTE_TASKS filtrando por el dueño y se borra con ADM_DROP_TASK
-- (rol ADM_PARALLEL_EXECUTE_TASK, el mismo que ya concede 99 a ROL_DATAMASKING).
select task_name, status from dba_parallel_execute_tasks
 where task_owner = upper('&&esquemaast') and task_name like 'TDM\_%' escape '\' order by task_name;

prompt
prompt --- Limpiando tareas TDM_% (si las hay) ---

declare
  v_n pls_integer := 0;
begin
  for r in (select task_name from dba_parallel_execute_tasks
             where task_owner = upper('&&esquemaast') and task_name like 'TDM\_%' escape '\') loop
    begin
      execute immediate
        'begin dbms_parallel_execute.adm_drop_task(task_owner => :o, task_name => :t); end;'
        using upper('&&esquemaast'), r.task_name;
      v_n := v_n + 1;
    exception
      when others then
        dbms_output.put_line('AVISO: no se pudo eliminar la tarea ' || r.task_name || ': ' || substr(sqlerrm,1,200));
    end;
  end loop;
  dbms_output.put_line(v_n || ' tarea(s) TDM_% eliminada(s).');
end;
/

prompt
prompt --- Autorizando mantenimiento DDL (si dm_proteger_auditoria.sql esta instalado) ---
Rem 2026-09-22: dm_proteger_auditoria.sql instala un trigger de DDL que
Rem bloquea TRUNCATE/DROP sobre estas mismas tablas salvo mantenimiento
Rem activo para la sesion. Este bloque activa esa ventana antes de truncar
Rem y la cierra al final del script (ver mas abajo). Si ese script de
Rem proteccion NO esta instalado todavia, PKG_DM_MANTENIMIENTO no existe y
Rem esta llamada falla -- se envuelve para no bloquear el reset en ese caso.

begin
  -- Llamada dinamica: PKG_DM_MANTENIMIENTO no forma parte del instalador del motor; con una
  -- llamada estatica y el paquete ausente el bloque entero no compilaba (PLS-00201) y el
  -- WHEN OTHERS de abajo nunca se alcanzaba.
  execute immediate 'begin pkg_dm_mantenimiento.proc_activar_mantenimiento(:1); end;'
    using 'dm_reset_ejecuciones CONFIRMAR por '||user;
exception
  when others then
    dbms_output.put_line('AVISO: no se pudo activar mantenimiento (pkg_dm_mantenimiento no instalado o sin permiso) -- ' ||
                          'si dm_proteger_auditoria.sql esta instalado, los TRUNCATE que siguen fallaran con ORA-20900.');
end;
/

prompt
prompt --- Truncando TDM_EJECUCION y su jerarquia (hija -> padre) ---

truncate table &&esquemaast..tdm_mask_dep_estado;
truncate table &&esquemaast..tdm_mask_trace;
truncate table &&esquemaast..tdm_ejecucion_error;
truncate table &&esquemaast..tdm_mask_solicitud;
truncate table &&esquemaast..tdm_ejecucion_scope;
truncate table &&esquemaast..tdm_columna_hist;
truncate table &&esquemaast..tdm_dependencia_hist;
truncate table &&esquemaast..tdm_ejecucion;

prompt
prompt --- Truncando TDM_SECRETO (peppers) ---

truncate table &&esquemaast..tdm_secreto;

prompt
prompt --- Cerrando la ventana de mantenimiento DDL ---

begin
  execute immediate 'begin pkg_dm_mantenimiento.proc_desactivar_mantenimiento; end;';
exception
  when others then null;
end;
/

prompt
prompt =========================================================
prompt Reset completo. TDM_EJECUCION y su jerarquia, y TDM_SECRETO, quedaron
prompt vacios. Las secuencias (SEQ_DM_EJECUCION y demas) NO se reinician
prompt con TRUNCATE -- los proximos ejecucion_id/solicitud_id/etc. seguiran
prompt la numeracion donde iban (en 11g no hay ALTER SEQUENCE RESTART; si
prompt de verdad necesita que vuelvan a arrancar en 1, hay que hacer DROP +
prompt CREATE de cada secuencia, aparte de este script).
prompt =========================================================

undefine 1
undefine V_ARG1
undefine V_CONFIRMA
