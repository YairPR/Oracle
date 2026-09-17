undefine V_ARG1
undefine V_ESQUEMA

set serveroutput on size unlimited
set verify off
set feedback off
set define on
set linesize 220
set pagesize 200
set trimspool on
set tab off

Rem =========================================================================
Rem dm_enmascara_force.sql -- enmascarado FORCE-only en UNA sola ejecucion_id
Rem =========================================================================
Rem Uso:
Rem   @dm_enmascara_force ESQUEMA
Rem
Rem Que hace: para esquemas SIN descubrimiento (TDM_COLUMNA_FINAL vacio para
Rem el esquema) y que dependen 100% de columnas FORCE en TDM_EXCEPCION_COL,
Rem crea UNA fila ad-hoc en TDM_EJECUCION y llama UNA vez a
Rem pkg_dm_enmascarar.p_dm_enmascara(p_ejecucion_id). proc_dm_mask_cat (motor,
Rem paquete 05, protegido) trae de fabrica un fallback: si no hay filas
Rem enmascarar='Y' en TDM_COLUMNA_FINAL para el esquema, enmascara en su lugar
Rem TODAS las columnas activas con accion=FORCE de TDM_EXCEPCION_COL, bajo el
Rem mismo ejecucion_id/solicitud_id/pepper compartido. Resultado: UNA fila en
Rem TDM_EJECUCION y UNA fila de pepper en TDM_SECRETO para todo el esquema,
Rem en vez de una por tabla.
Rem
Rem Historial (para no repetir versiones anteriores):
Rem   v1-v2: driver que llamaba pkg_dm_enmascarar.p_mask_tab tabla por tabla,
Rem          en un solo bloque PL/SQL -> DBMS_OUTPUT no hacia flush hasta que
Rem          terminaba el bloque completo (parecia colgado sin estarlo).
Rem   v3-v4: se genero un .sql intermedio con un bloque PL/SQL por tabla
Rem          (via SPOOL + @@), para que cada tabla fuera su propia sentencia y
Rem          el progreso se viera en tiempo real. Arreglo correcto para el
Rem          "cuelgue visual", pero cada llamada a p_mask_tab crea su propio
Rem          ejecucion_id y su propio pepper efimero: 56 tablas = 56 filas en
Rem          TDM_EJECUCION y 56 peppers en TDM_SECRETO por corrida completa.
Rem          Seguro (aislamiento fuerte), pero no es "una ejecucion por
Rem          esquema" y generaba peppers huerfanos si se cancelaba a mitad.
Rem   v5 (este): en vez de reinventar el control de ejecucion, se usa el
Rem          camino YA soportado por el motor para consolidar en una sola
Rem          ejecucion_id: pkg_dm_enmascarar.p_dm_enmascara, con el fallback
Rem          FORCE-only de proc_dm_mask_cat cuando TDM_COLUMNA_FINAL esta
Rem          vacio para el esquema (confirmado leyendo 04 y 05 completos).
Rem          El progreso en vivo ya no se ve por DBMS_OUTPUT tabla-a-tabla:
Rem          se consulta desde OTRA sesion contra TDM_EJECUCION (progreso_pct,
Rem          heartbeat_ts, tablas_proc, columnas_proc), que el motor actualiza
Rem          internamente tras cada columna via proc_dm_upd_ejec.
Rem =========================================================================

variable v_ejec_id number

column final_p1 new_value V_ARG1 noprint
select trim('&1') final_p1 from dual;

prompt
prompt --- Paso 0: validaciones previas ---

Rem --- Paso 0a: el esquema no debe tener ya una ejecucion EJECUTANDO huerfana.
Rem Sin esto, p_dm_enmascara igual lo detecta (proc_dm_validar_concurrencia,
Rem ORA-20098), pero fallar aqui evita gastar un ejecucion_id/pepper para nada
Rem y senala directo el script de remedio.
declare
  v_esquema varchar2(128) := upper(trim('&&V_ARG1'));
  v_cnt     pls_integer;
begin
  if v_esquema is null then
    raise_application_error(-20401, 'Uso: @dm_enmascara_force ESQUEMA');
  end if;

  select count(*) into v_cnt
    from tdm_ejecucion
   where esquema_objetivo = v_esquema
     and estado = 'EJECUTANDO';

  if v_cnt > 0 then
    raise_application_error(-20403,
      'Hay '||v_cnt||' ejecucion(es) EJECUTANDO para '||v_esquema||' en TDM_EJECUCION '||
      '(activa de verdad, o huerfana de una corrida cancelada). Revise y libere con '||
      '@dm_liberar_ejecucion_activa '||v_esquema||' antes de reintentar.');
  end if;
end;
/

Rem --- Paso 0b: tareas DBMS_PARALLEL_EXECUTE huerfanas (TASK_DM_%).
Rem proc_dm_apl_col (motor, paquete 05, protegido) genera el nombre de tarea
Rem con SUBSTR(...,1,30) sin verificar unicidad real: para tablas/columnas
Rem con nombres largos (>=21 caracteres combinados) el nombre queda truncado
Rem y determinista -> ORA-29497 si ya existe una tarea con ese mismo nombre
Rem de una corrida anterior. No se puede arreglar en 05 (protegido); se
Rem previene limpiando tareas huerfanas antes de cada corrida. Solo se
Rem limpia si NINGUN esquema tiene una ejecucion ENMASCARAMIENTO EJECUTANDO
Rem de verdad (si la hubiera, esas tareas podrian ser suyas, no huerfanas).
declare
  v_otras_activas pls_integer;
  v_n             pls_integer := 0;
begin
  select count(*) into v_otras_activas
    from tdm_ejecucion
   where fase_proceso = 'ENMASCARAMIENTO'
     and estado = 'EJECUTANDO';

  if v_otras_activas > 0 then
    raise_application_error(-20404,
      'Hay '||v_otras_activas||' ejecucion(es) ENMASCARAMIENTO EJECUTANDO en algun esquema. '||
      'No se limpian las tareas TASK_DM_% huerfanas mientras eso siga asi (podrian ser de esa '||
      'corrida activa). Espere a que termine, o libere la que corresponda con '||
      '@dm_liberar_ejecucion_activa ESQUEMA si esta huerfana.');
  end if;

  for r in (select task_name from user_parallel_execute_tasks where task_name like 'TASK_DM_%') loop
    begin
      dbms_parallel_execute.drop_task(r.task_name);
      v_n := v_n + 1;
    exception
      when others then
        dbms_output.put_line('AVISO: no se pudo eliminar la tarea '||r.task_name||': '||substr(sqlerrm,1,200));
    end;
  end loop;

  if v_n > 0 then
    dbms_output.put_line(v_n||' tarea(s) DBMS_PARALLEL_EXECUTE huerfana(s) (TASK_DM_%) eliminada(s) antes de iniciar.');
  end if;
end;
/

Rem --- Paso 0c: debe haber al menos una columna FORCE activa y valida para el
Rem esquema, con la MISMA condicion exacta que usa el fallback de
Rem proc_dm_mask_cat (via pkg_dm_enmascarar.f_norm, PUBLICA), para que el
Rem conteo de aqui coincida con lo que el motor va a procesar de verdad.
declare
  v_esquema varchar2(128) := upper(trim('&&V_ARG1'));
  v_cnt     pls_integer;
begin
  select count(*) into v_cnt
    from tdm_excepcion_col e
   where pkg_dm_enmascarar.f_norm(e.owner_name) = v_esquema
     and pkg_dm_enmascarar.f_norm(e.activa)     = 'Y'
     and pkg_dm_enmascarar.f_norm(e.accion)     = 'FORCE'
     and e.identificador_forz is not null
     and exists (
           select 1 from dba_tab_columns c
            where c.owner       = pkg_dm_enmascarar.f_norm(e.owner_name)
              and c.table_name  = pkg_dm_enmascarar.f_norm(e.table_name)
              and c.column_name = pkg_dm_enmascarar.f_norm(e.column_name)
         );

  if v_cnt = 0 then
    raise_application_error(-20402,
      'No hay columnas activas con accion=FORCE, identificador_forz definido y que existan '||
      'realmente en DBA_TAB_COLUMNS para el esquema '||v_esquema||' en TDM_EXCEPCION_COL. '||
      'Nada que enmascarar.');
  end if;

  dbms_output.put_line(v_cnt||' columna(s) FORCE activa(s) encontrada(s) para '||v_esquema||'.');
end;
/

prompt
prompt --- Paso 1: creando la ejecucion ad-hoc (una sola fila en TDM_EJECUCION) ---

Rem Se deja fase_proceso/estado en ('DESCUBRIMIENTO','FINALIZADO'): mismo
Rem estado en el que quedaria la fila si hubiera pasado por un descubrimiento
Rem real y ya hubiese terminado. Asi p_dm_enmascara la reconoce como una
Rem ejecucion valida para transicionar a ENMASCARAMIENTO (su UPDATE de
Rem reclamo exige que la fila NO este ya en fase_proceso='ENMASCARAMIENTO' y
Rem estado='EJECUTANDO' a la vez), sin tocar TDM_COLUMNA_FINAL -- que se deja
Rem vacio a proposito para el esquema, y es justo lo que activa el fallback
Rem FORCE-only de proc_dm_mask_cat. El campo DETALLE deja constancia expresa,
Rem para auditoria, de que esta fila es ad-hoc y no vino de un descubrimiento
Rem real.
declare
  v_esquema varchar2(128) := upper(trim('&&V_ARG1'));
begin
  select seq_dm_ejecucion.nextval into :v_ejec_id from dual;

  insert into tdm_ejecucion (
    ejecucion_id, esquema_objetivo, ejecutado_por, fase_proceso, estado,
    fecha_inicio, fecha_fin, ultimo_objeto, ultimo_paso, detalle
  ) values (
    :v_ejec_id, v_esquema, user, 'DESCUBRIMIENTO', 'FINALIZADO',
    systimestamp, systimestamp, v_esquema, 'AD_HOC_FORCE_SIN_DESCUBRIMIENTO',
    'Fila creada por dm_enmascara_force.sql (no por pkg_dm_descubrimiento): '||
    'no hubo descubrimiento real para este esquema. El enmascarado se basa '||
    '100% en TDM_EXCEPCION_COL con accion=FORCE, via el fallback nativo de '||
    'proc_dm_mask_cat cuando TDM_COLUMNA_FINAL esta vacio para el esquema.'
  );
  commit;

  dbms_output.put_line('Ejecucion ad-hoc creada: ejecucion_id='||:v_ejec_id||' para esquema '||v_esquema||'.');
end;
/

prompt
prompt --- Paso 2: pkg_dm_enmascarar.p_dm_enmascara (una sola llamada, todo el esquema) ---
prompt Progreso en vivo (desde OTRA sesion, mientras esto corre): consulte
prompt   select estado, progreso_pct, tablas_proc, columnas_proc, heartbeat_ts,
prompt          ultimo_objeto, ultimo_paso
prompt     from tdm_ejecucion where ejecucion_id = <el numero impreso arriba>;
prompt

declare
  v_err varchar2(4000);
begin
  pkg_dm_enmascarar.p_dm_enmascara(
    p_ejecucion_id => :v_ejec_id,
    p_reproceso    => 'N',
    p_commit_lote  => 1000
  );
  dbms_output.put_line('p_dm_enmascara termino sin excepcion (ver estado final abajo: puede ser FINALIZADO o ERROR con detalle en TDM_EJECUCION_ERROR).');
exception
  when others then
    v_err := substr(sqlerrm,1,4000);
    dbms_output.put_line('p_dm_enmascara lanzo una excepcion: '||v_err);
    dbms_output.put_line('El detalle ya quedo registrado por el motor en TDM_EJECUCION / TDM_MASK_SOLICITUD / TDM_EJECUCION_ERROR para ejecucion_id='||:v_ejec_id||'.');
end;
/

prompt
prompt --- Paso 3: higiene del pepper (TDM_SECRETO) ---

Rem p_dm_enmascara (a diferencia de p_mask_tab) NO purga el pepper al
Rem terminar: una campana completa normal deja el pepper vivo para una fase
Rem de export posterior. Esta corrida ad-hoc no tiene export despues, asi que
Rem si la ejecucion quedo FINALIZADO se purga aqui mismo, para no dejar la
Rem clave efimera dando vueltas en TDM_SECRETO. Si NO quedo FINALIZADO, se
Rem deja el pepper vivo a proposito (por si hace falta diagnosticar o
Rem reprocesar) y se avisa como purgarlo a mano cuando ya no se necesite.
declare
  v_estado varchar2(20);
begin
  select estado into v_estado from tdm_ejecucion where ejecucion_id = :v_ejec_id;

  if v_estado = 'FINALIZADO' then
    pkg_dm_enmascarar.p_dm_pepper_purgar(:v_ejec_id);
    dbms_output.put_line('Ejecucion FINALIZADA: pepper de TDM_SECRETO (clave PEPPER_MASK:'||:v_ejec_id||') purgado.');
  else
    dbms_output.put_line('Ejecucion en estado '||v_estado||' (no FINALIZADO): el pepper de TDM_SECRETO '||
      '(clave PEPPER_MASK:'||:v_ejec_id||') NO se purga a proposito, por si hace falta diagnosticar o '||
      'reprocesar. Purguelo a mano con pkg_dm_enmascarar.p_dm_pepper_purgar('||:v_ejec_id||') solo '||
      'cuando confirme que ya no lo necesita.');
  end if;
exception
  when others then
    dbms_output.put_line('AVISO: no se pudo verificar/purgar el pepper: '||sqlerrm);
end;
/

column ejecucion_id    format 999999999
column estado          format a12
column progreso_pct    format 999.99
column tablas_proc     format 9999999
column columnas_proc   format 9999999
column error_count     format 9999999
column fecha_inicio    format a20
column fecha_fin       format a20

prompt
prompt =========================================================
prompt Resumen de la ejecucion
prompt =========================================================

select ejecucion_id,
       estado,
       progreso_pct,
       tablas_proc,
       columnas_proc,
       error_count,
       to_char(fecha_inicio,'YYYY-MM-DD HH24:MI:SS') as fecha_inicio,
       to_char(fecha_fin,'YYYY-MM-DD HH24:MI:SS')    as fecha_fin
  from tdm_ejecucion
 where ejecucion_id = :v_ejec_id;

column owner_name    format a25
column table_name    format a28
column column_name   format a22
column etapa         format a20
column codigo_error  format 9999999
column mensaje_error format a60 word_wrapped

prompt
prompt --- Detalle de errores (vacio si error_count = 0) ---

select owner_name, table_name, column_name, etapa, codigo_error, mensaje_error
  from tdm_ejecucion_error
 where ejecucion_id = :v_ejec_id
 order by fecha_error;

prompt
prompt Tablas para mas detalle:
prompt   1. TDM_EJECUCION         - Estado macro del proceso (esta ejecucion_id)
prompt   2. TDM_MASK_SOLICITUD    - Checkpoints y contadores operativos
prompt   3. TDM_EJECUCION_ERROR   - Historial de errores con backtrace PL/SQL
prompt   4. TDM_MASK_TRACE        - Bitacora de eventos paso a paso
prompt   5. TDM_MASK_DEP_ESTADO   - Estado de FKs, indices y triggers
prompt =========================================================

undefine 1
undefine V_ARG1
undefine V_ESQUEMA
