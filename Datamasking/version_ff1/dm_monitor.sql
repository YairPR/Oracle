clear columns
set echo off
set verify off
set feedback off
set define on
set linesize 220
set pagesize 200
set trimspool on
set tab off
set serveroutput on size unlimited

Rem ================================================================================
Rem dm_monitor.sql <ejecucion_id>
Rem Monitor de SOLO LECTURA (ningun UPDATE/DML) de una campana de ENMASCARAMIENTO
Rem (o DESCUBRIMIENTO, partes 1/2/5/6) en curso. AUTOCONTENIDO: detecta solo el
Rem esquema owner del motor (ASTSYSADMIN o ACC_ADMIN, mismo criterio que el resto
Rem de drivers) y se coloca en el con ALTER SESSION SET CURRENT_SCHEMA, asi que se
Rem puede correr igual como SYS que como un usuario DBA con sinonimos. Al terminar
Rem devuelve CURRENT_SCHEMA al usuario conectado.
Rem
Rem Uso:   @dm_monitor EJECUCION_ID
Rem
Rem Que muestra, en una sola pasada:
Rem   0) DIAGNOSTICO (pkg_dm_enmascarar.proc_dm_gestiona_tareas en modo INFORMAR, solo
Rem      lectura): si la ejecucion SIGUE EN CURSO, SE QUEDO SIN SESION PRINCIPAL
Rem      (huerfana: la fila dice EJECUTANDO pero la sesion ya no existe) o esta detenida;
Rem      cada tarea paralela con su columna, su clase (en curso / interrumpida /
Rem      terminada sin cerrar / de otra ejecucion / obsoleta) y su avance; DESDE DONDE se
Rem      reanudaria (tabla.columna, chunks hechos y filas aproximadas); cuantas columnas
Rem      faltan; y el SIGUIENTE PASO (@dm_enmascara_reanudar o @dm_enmascara_cancel).
Rem   1) Cabecera de TDM_EJECUCION (estado, progreso, ultimo objeto, heartbeat).
Rem   2) Vida de la sesion orquestadora: match EXACTO sid+serial#+inst_id (en RAC el
Rem      sid solo no identifica nada: Oracle lo recicla y cada instancia tiene los
Rem      suyos). 2b) contraprueba independiente de TDM_EJECUCION: sesiones con
Rem      MODULE=PKG_DM% (lo fija el propio motor al arrancar).
Rem   3) (integrado en el punto 0.)
Rem   3b) Rama completa tarea -> chunk -> job, una fila por chunk.
Rem   4) Detalle de cada worker en GV$SESSION: evento, segundos de espera, bloqueador.
Rem   5) Errores registrados para la ejecucion (TDM_EJECUCION_ERROR).
Rem   6) Ultimas trazas (TDM_MASK_TRACE).
Rem
Rem COMO LEERLO (aprendido contra datos reales, 05-07/10/26):
Rem  - ULTIMO_OBJETO es la ULTIMA columna COMPLETADA, no la que esta corriendo: el
Rem    motor la actualiza DESPUES de proc_dm_apl_col (05, bucle de proc_dm_mask_cat);
Rem    COLUMNAS_PROC / progreso cuentan columnas TERMINADAS. La columna en curso es
Rem    la siguiente y solo se reconoce por su tarea (paso 3).
Rem  - El task_name es DETERMINISTICO: 'TDM_'||GET_HASH_VALUE(OWNER.TABLA.COLUMNA,
Rem    1,1000000000) (ver 05, proc_dm_ejecuta_update_seguro). Por eso el paso 3 lo
Rem    resuelve a columna recalculando el hash de las columnas candidatas del
Rem    esquema (TDM_COLUMNA_FINAL + excepciones FORCE). No se usan TABLE_OWNER /
Rem    TABLE_NAME de DBA_PARALLEL_EXECUTE_TASKS: salen vacias si consulta
Rem    EYPURISACA y pobladas si consulta SYS (privilegios de quien consulta).
Rem  - El motor hace DROP_TASK de cada columna justo despues de validarla. Una
Rem    tarea FINISHED que sigue ahi es una tarea terminada sin cerrar (la sesion orquestadora murio
Rem    entre RUN_TASK y ese DROP_TASK). Sus chunks PROCESSED ya estan cifrados con FF1,
Rem    asi que esa columna NO se debe relanzar. Desde la Fase 1 (2026-10-07) el
Rem    PRE-FLIGHT de proc_dm_enmascaramiento detecta esa tarea al arrancar el
Rem    siguiente run y se detiene con ORA-20331 sin tocar datos; el detalle queda
Rem    en TDM_MASK_TRACE (paso PREFLIGHT_ORFANA).
Rem  - Un worker sano muestra CPU_PCT alto (>~70). CPU_PCT bajo con ELAPSED alto y
Rem    un EVENT de espera largo (paso 4) es la senal de un worker bloqueado; un
Rem    EVENT tipo 'gc ...' es contencion RAC entre instancias, no un cuelgue.
Rem ================================================================================

Rem --- Esquema del motor: se detecta solo (ASTSYSADMIN o ACC_ADMIN) ---
define esquemaast = '__NO_DETECTADO__'
column v_esquemaast noprint new_value esquemaast
set termout off
select username as v_esquemaast
  from (select username from dba_users
         where username in ('ASTSYSADMIN','ACC_ADMIN')
         order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
 where rownum = 1;
set termout on

declare
  l_ejec_id number;
begin
  if upper(trim('&&esquemaast')) = '__NO_DETECTADO__' then
    raise_application_error(-20601,
      'No se encontro ni ASTSYSADMIN ni ACC_ADMIN en DBA_USERS -- no se puede determinar el esquema del motor DATAMASKING en esta base.');
  end if;
  l_ejec_id := to_number('&1');
exception
  when value_error or invalid_number then
    raise_application_error(-20600,
      'Uso: @dm_monitor <ejecucion_id numerico>. Valor recibido: "&1".');
end;
/

alter session set current_schema = &&esquemaast;

prompt
prompt Esquema del motor: &&esquemaast
prompt
prompt *** 0) DIAGNOSTICO: sigue en ejecucion, quedo huerfana o esta detenida; desde donde se reanudaria ***
begin
  pkg_dm_enmascarar.proc_dm_gestiona_tareas(&1, 'INFORMAR');
exception
  when others then
    dbms_output.put_line('No se pudo generar el diagnostico: '||sqlerrm);
end;
/
prompt     (Con paralelismo 1 los chunks corren DENTRO de la sesion principal: no hay jobs worker que mostrar en 3b/4;
prompt      la tarea PROCESSING con la sesion principal muerta es una interrumpida, no una en curso.)

prompt
prompt *** 1) CABECERA DE LA EJECUCION ***
column ejecucion_id     format 99999   heading EJEC
column ora_esquema format a14     heading ESQUEMA
column fase_proceso     format a16     heading FASE
column estado           format a11
column progreso_pct     format 999.99  heading PCT
column tablas           format a7
column columnas         format a8
column ultimo_objeto    format a42     heading 'ULTIMO_OBJETO (completado)'
column ultimo_paso      format a12     heading PASO
column heartbeat_ts     format a19     heading HEARTBEAT
column sesion_sid       format 99999   heading SID
column sesion_serial    format 99999   heading SERIAL#
column sesion_inst_id   format 99      heading INST
select ejecucion_id, ora_esquema, fase_proceso, estado, progreso_pct,
       tablas_proc||'/'||tablas_total     as tablas,
       columnas_proc||'/'||columnas_total as columnas,
       ultimo_objeto, ultimo_paso,
       to_char(heartbeat_ts,'DD/MM HH24:MI:SS') as heartbeat_ts,
       sesion_sid, sesion_serial, sesion_inst_id
  from tdm_ejecucion
 where ejecucion_id = &1;

prompt
prompt *** 1b) INTENTOS DE LA EJECUCION (reintento_nro > 1 = reanudacion) ***
column solicitud_id   format 99999  heading SOLIC
column reintento_nro  format 999    heading INT
column sol_estado     format a11    heading ESTADO
column inicio         format a14
column fin            format a14
column sol_detalle    format a90 word_wrapped heading DETALLE
select solicitud_id, reintento_nro, estado as sol_estado,
       to_char(fecha_inicio,'DD/MM HH24:MI:SS') as inicio,
       to_char(fecha_fin,'DD/MM HH24:MI:SS')    as fin,
       substr(detalle,1,300) as sol_detalle
  from tdm_mask_solicitud
 where ejecucion_id = &1
 order by solicitud_id;
column ej_detalle format a120 word_wrapped heading 'DETALLE DE LA EJECUCION'
select substr(detalle,1,400) as ej_detalle
  from tdm_ejecucion
 where ejecucion_id = &1 and detalle is not null;

prompt
prompt *** 2) VIDA DE LA SESION ORQUESTADORA (match exacto sid+serial#+inst_id) ***
column sesion_sid     format 99999 heading SID
column sesion_serial  format 99999 heading SERIAL#
column sesion_inst_id format 99    heading INST
column status         format a9
column module         format a18
column last_call_et   format 9999999 heading LAST_CALL_ET
column diagnostico    format a60
select e.sesion_sid, e.sesion_serial, e.sesion_inst_id,
       s.status, s.module, s.last_call_et,
       case when s.sid is null
            then 'SESION NO ENCONTRADA -- probablemente muerta (kill / caida)'
            else 'SESION VIVA'
       end as diagnostico
  from tdm_ejecucion e
  left join gv$session s
    on s.sid = e.sesion_sid
   and s.serial# = e.sesion_serial
   and s.inst_id = e.sesion_inst_id
 where e.ejecucion_id = &1;

prompt
prompt *** 2b) CONTRAPRUEBA: sesiones con MODULE=PKG_DM% (lo marca el propio motor; no depende de TDM_EJECUCION) ***
column inst_id    format 99
column sid        format 99999
column serial#    format 99999
column username   format a10
column action     format a16
column logon_time format a19
column event      format a28
select s.inst_id, s.sid, s.serial#, s.username, s.status, s.module, s.action,
       to_char(s.logon_time,'DD/MM HH24:MI:SS') as logon_time, s.last_call_et, s.event
  from gv$session s
 where s.module like 'PKG_DM%'
 order by s.inst_id, s.sid;

column task_name format a30
prompt
prompt *** 3b) RAMA tarea -> chunk -> job (CPU_PCT = CPU_USED/ELAPSED del job; solo para chunks ASSIGNED) ***
column chunk_id format 99999
column chunk_status format a21
column job_name format a14
column inst format 99
column elapsed format a13
column cpu_pct format 999
select c.task_name, c.chunk_id, c.status as chunk_status, c.job_name,
       r.running_instance as inst,
       case when r.elapsed_time is not null
            then substr(to_char(r.elapsed_time),2,3)||'d '||substr(to_char(r.elapsed_time),6,8)
       end as elapsed,
       round(100 *
         (extract(day from r.cpu_used)*86400 + extract(hour from r.cpu_used)*3600
          + extract(minute from r.cpu_used)*60 + extract(second from r.cpu_used))
         / nullif(extract(day from r.elapsed_time)*86400 + extract(hour from r.elapsed_time)*3600
          + extract(minute from r.elapsed_time)*60 + extract(second from r.elapsed_time), 0)) as cpu_pct
  from dba_parallel_execute_chunks c
  left join dba_scheduler_running_jobs r
    on r.job_name = c.job_name
   and c.status = 'ASSIGNED'
 where c.task_owner = '&&esquemaast'
   and c.task_name in (select task_name from dba_parallel_execute_tasks
                        where task_owner = '&&esquemaast' and task_name like 'TDM_%' and status != 'FINISHED')
 order by c.task_name, c.chunk_id;

prompt
prompt *** 3c) RESUMEN: chunks por estado y tarea activa ***
column chunks format 99999
select c.task_name, c.status as chunk_status, count(*) as chunks
  from dba_parallel_execute_chunks c
 where c.task_owner = '&&esquemaast'
   and c.task_name in (select task_name from dba_parallel_execute_tasks
                        where task_owner = '&&esquemaast' and task_name like 'TDM_%' and status != 'FINISHED')
 group by c.task_name, c.status
 order by c.task_name, c.status;

prompt
prompt *** 4) WORKERS EN CURSO: que esta esperando cada sesion (GV$SESSION) ***
prompt     (event 'gc ...' = contencion RAC entre instancias; 'enq: TX ...' = bloqueo de filas; ON CPU = trabajo real)
column job_name  format a14
column wait_class format a14
column sec_wait  format 9999999
column b_inst    format 99
column b_sid     format 99999
column sql_id    format a13
column event     format a34
select r.job_name, r.running_instance as inst, r.session_id as sid, s.serial#, s.status,
       nvl(s.event,'?') as event, s.wait_class, s.seconds_in_wait as sec_wait,
       s.blocking_instance as b_inst, s.blocking_session as b_sid, s.sql_id
  from dba_scheduler_running_jobs r
  left join gv$session s
    on s.inst_id = r.running_instance
   and s.sid = r.session_id
 where r.job_name in (select c.job_name
                        from dba_parallel_execute_chunks c
                       where c.task_owner = '&&esquemaast'
                         and c.status = 'ASSIGNED'
                         and c.job_name is not null
                         and c.task_name in (select task_name from dba_parallel_execute_tasks
                                              where task_owner = '&&esquemaast' and task_name like 'TDM_%' and status != 'FINISHED'))
 order by r.job_name;

prompt
prompt *** 5) ERRORES REGISTRADOS PARA ESTA EJECUCION (TDM_EJECUCION_ERROR) -- vacio = ninguna columna ha fallado ***
column hora          format a8
column table_name    format a20
column column_name   format a20
column etapa         format a11
column codigo_error  format 999999
column mensaje_error format a100 word_wrapped
select to_char(fecha_error,'HH24:MI:SS') as hora, table_name, column_name, etapa, codigo_error,
       substr(mensaje_error,1,300) as mensaje_error
  from tdm_ejecucion_error
 where ejecucion_id = &1
 order by error_id;

prompt
prompt *** 6) ULTIMAS 8 TRAZAS (TDM_MASK_TRACE) ***
column fase    format a15
column paso    format a24
column detalle format a100 word_wrapped
select hora, fase, paso, detalle
  from (select trace_id, to_char(fecha_evento,'HH24:MI:SS') as hora, fase, paso,
               substr(detalle,1,300) as detalle
          from tdm_mask_trace
         where ejecucion_id = &1
         order by trace_id desc)
 where rownum <= 8
 order by trace_id;

prompt
prompt *** FIN DEL MONITOR -- vuelve a correr @dm_monitor &1 cuando quieras una foto nueva ***

alter session set current_schema = &_USER;
clear columns
undefine 1
undefine esquemaast
undefine v_esquemaast
set feedback 6
