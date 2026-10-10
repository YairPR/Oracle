undefine V_ARG1
undefine V_ARG2
undefine V_CONFIRMA
undefine V_ARG3

set serveroutput on size unlimited
set verify off
set feedback off
set define on
set linesize 220
set pagesize 200
set trimspool on
set tab off

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
prompt dm_enmascara_cancel.sql -- ABORTA toda una ejecucion: sesion, jobs, chunks y tareas
prompt Uso:
prompt   @dm_enmascara_cancel EJECUCION_ID CONFIRMAR              (aborta y deja todo limpio y reanudable)
prompt   @dm_enmascara_cancel EJECUCION_ID CONFIRMAR DESCARTAR    (aborta y ademas BORRA las tareas/chunks)
prompt Ejemplo:
prompt   @dm_enmascara_cancel 6 CONFIRMAR
prompt =========================================================
prompt Es la UNICA puerta para abortar una ejecucion (viva, colgada o a medias). Hace,
prompt en orden, y va diciendo lo que encuentra:
prompt   1. proc_dm_cancelar: marca cancel_requested=Y (cortesia y rastro de auditoria).
prompt   2. Mata la sesion PRINCIPAL si sigue viva (ALTER SYSTEM KILL SESSION con el
prompt      sid/serial#/inst_id de TDM_EJECUCION) y espera a confirmarlo.
prompt   3. Mata los jobs WORKER (DBMS_SCHEDULER) de las tareas de esa ejecucion. Cada
prompt      chunk confirma UPDATE + PROCESSED en un solo commit, asi que el kill revierte
prompt      el chunk en curso entero: nunca queda un chunk a medio cifrar.
prompt   4. Tareas/chunks DBMS_PARALLEL_EXECUTE: por defecto las deja intactas y
prompt      REANUDABLES (@dm_enmascara_reanudar las termina sin reprocesar lo ya
prompt      cifrado) y muestra hasta donde llego cada una. Con DESCARTAR las borra.
prompt   5. Cierra a ABORTADA la fila de TDM_EJECUCION si seguia EJECUTANDO.
prompt
prompt OJO con DESCARTAR: las filas que ya estaban cifradas SIGUEN cifradas. Abandonar de
prompt verdad exige restaurar antes el dato original (y despues @dm_pepper_purgar).
prompt Requiere ALTER SYSTEM (SYS o un DBA); sin el, se detiene y lo dice.
prompt Compatible 11g / 19c / 26ai (espera portable, identificadores <= 30).
prompt
prompt MODIFICADO   (MM/DD/YY)
prompt epurisaca    10/04/26 - Creacion (cancelar + matar sesion + cerrar fila en un solo paso).
prompt epurisaca    10/09/26 - Pasa a abortar la ejecucion COMPLETA: mata tambien los workers,
prompt                         opcion DESCARTAR y espera portable (DBMS_SESSION.SLEEP no existe
prompt                         en 11g). dm_liberar_ejecucion_activa queda redundante.
prompt =========================================================

set termout off

column "2" new_value 2 noprint
select null as "2" from dual where 1=2;
column "3" new_value 3 noprint
select null as "3" from dual where 1=2;

column final_p1 new_value V_ARG1 noprint
column final_p2 new_value V_CONFIRMA noprint
column final_p3 new_value V_ARG3 noprint
select trim('&1') final_p1, upper(trim('&2')) final_p2, upper(trim('&3')) final_p3 from dual;

set termout on

declare
  v_ejecucion_id   number;
  v_confirma       varchar2(30) := upper(trim('&&V_CONFIRMA'));
  v_descartar      boolean      := (nvl(upper(trim('&&V_ARG3')),'-') = 'DESCARTAR');

  v_esquema        tdm_ejecucion.ora_esquema%type;
  v_fase           tdm_ejecucion.fase_proceso%type;
  v_estado         tdm_ejecucion.estado%type;
  v_sid            tdm_ejecucion.sesion_sid%type;
  v_serial         tdm_ejecucion.sesion_serial%type;
  v_inst_id        tdm_ejecucion.sesion_inst_id%type;
  v_ejecutado_por  tdm_ejecucion.ora_usuario%type;
  v_ultimo_objeto  tdm_ejecucion.ultimo_objeto%type;

  v_viva           number;
  v_pat            varchar2(100);
  v_workers        pls_integer := 0;
  v_intentos       pls_integer := 0;
  c_max_intentos   constant pls_integer := 30;   -- 30 x 2s = 60s maximo
  c_espera_seg     constant number := 2;

  c_sql_workers    constant varchar2(2000) :=
    'select r.job_name, r.session_id, s.serial#, r.running_instance, s.status '||
    '  from dba_scheduler_running_jobs r, gv$session s '||
    ' where r.owner = :own '||
    '   and s.inst_id = r.running_instance and s.sid = r.session_id '||
    '   and r.job_name in (select c.job_name '||
    '                        from dba_parallel_execute_chunks c, dba_parallel_execute_tasks t '||
    '                       where t.task_owner = :own2 '||
    '                         and t.task_name like ''TDM\_%'' escape ''\'' '||
    '                         and dbms_lob.instr(t.sql_stmt, :pat) > 0 '||
    '                         and c.task_owner = t.task_owner and c.task_name = t.task_name '||
    '                         and c.job_name is not null)';

  procedure say(p_txt in varchar2) is
  begin
    dbms_output.put_line(p_txt);
  end;

  -- Espera portable: DBMS_SESSION.SLEEP existe desde 18c, DBMS_LOCK.SLEEP desde 8i.
  procedure espera(p_seg in number) is
  begin
    begin
      execute immediate 'begin dbms_session.sleep(:s); end;' using p_seg;
    exception
      when others then
        begin
          execute immediate 'begin dbms_lock.sleep(:s); end;' using p_seg;
        exception
          when others then null;
        end;
    end;
  end;

  -- Cuenta (y opcionalmente mata) los jobs worker vivos de las tareas de ESTA ejecucion
  -- (el id va como literal en el SQL de cada chunk: no se toca ninguna otra ejecucion).
  procedure revisa_workers(p_matar in boolean, p_vivos out pls_integer) is
    c_cur   sys_refcursor;
    l_job   varchar2(128);
    l_sid   number;
    l_ser   number;
    l_inst  number;
    l_st    varchar2(20);
  begin
    p_vivos := 0;
    open c_cur for c_sql_workers using '&&esquemaast', '&&esquemaast', v_pat;
    loop
      fetch c_cur into l_job, l_sid, l_ser, l_inst, l_st;
      exit when c_cur%notfound;
      if nvl(l_st,'?') <> 'KILLED' then
        p_vivos := p_vivos + 1;
        if p_matar then
          say('  matando el worker '||l_job||' (sid='||l_sid||', serial#='||l_ser||', inst_id='||l_inst||')...');
          begin
            execute immediate
              'alter system kill session '''||l_sid||','||l_ser||',@'||l_inst||''' immediate';
          exception
            when others then
              if sqlcode in (-31, -30) then
                null;   -- marcada para matar / ya no existe: respuesta normal de KILL IMMEDIATE
              elsif sqlcode = -1031 then
                raise_application_error(-20604,
                  'ORA-01031 (privilegios insuficientes) al matar el worker '||l_job||'. Conectese con un '||
                  'usuario que tenga ALTER SYSTEM (p.ej. AS SYSDBA) y reintente.');
              else
                say('  NO se pudo matar: '||substr(sqlerrm,1,200));
              end if;
          end;
        end if;
      end if;
    end loop;
    close c_cur;
  exception
    when others then
      if c_cur%isopen then close c_cur; end if;
      raise;
  end;

begin
  if '&&V_ARG1' is null or not regexp_like('&&V_ARG1', '^[0-9]+$') then
    raise_application_error(-20601,
      'Uso: @dm_enmascara_cancel EJECUCION_ID CONFIRMAR [DESCARTAR]');
  end if;
  v_ejecucion_id := to_number('&&V_ARG1');

  if v_confirma is null or v_confirma <> 'CONFIRMAR' then
    raise_application_error(-20602,
      'Este script ABORTA la ejecucion y PUEDE matar sesiones Oracle con ALTER SYSTEM KILL '||
      'SESSION. Debe escribir la palabra CONFIRMAR como segundo argumento para '||
      'proceder: @dm_enmascara_cancel '||v_ejecucion_id||' CONFIRMAR');
  end if;
  if '&&V_ARG3' is not null and not v_descartar then
    raise_application_error(-20608,
      'Tercer argumento "&&V_ARG3" no reconocido. Solo se admite DESCARTAR: '||
      '@dm_enmascara_cancel '||v_ejecucion_id||' CONFIRMAR DESCARTAR');
  end if;

  begin
    select ora_esquema, fase_proceso, estado,
           sesion_sid, sesion_serial, sesion_inst_id, ora_usuario, ultimo_objeto
      into v_esquema, v_fase, v_estado,
           v_sid, v_serial, v_inst_id, v_ejecutado_por, v_ultimo_objeto
      from tdm_ejecucion
     where ejecucion_id = v_ejecucion_id;
  exception
    when no_data_found then
      raise_application_error(-20603, 'No existe ejecucion_id='||v_ejecucion_id||' en TDM_EJECUCION.');
  end;

  v_pat := 'proc_dm_set_ejecucion(' || v_ejecucion_id || ')';

  say('=========================================');
  say('dm_enmascara_cancel'||case when v_descartar then ' (con DESCARTAR)' end);
  say('Ejecucion_id  : '||v_ejecucion_id);
  say('Esquema       : '||v_esquema);
  say('Fase/Estado   : '||v_fase||' / '||v_estado);
  say('Ultimo objeto : '||v_ultimo_objeto||'   (ultima columna COMPLETADA, no la que estaba en curso)');
  say('Sesion origen : sid='||nvl(to_char(v_sid),'?')||
                        ', serial#='||nvl(to_char(v_serial),'?')||
                        ', inst_id='||nvl(to_char(v_inst_id),'?')||
                        ', usuario='||nvl(v_ejecutado_por,'?'));
  say('=========================================');

  -- Paso 1: cancelacion cooperativa (cortesia; rastro de auditoria).
  say('Paso 1/5: solicitando cancelacion cooperativa...');
  pkg_dm_enmascarar.proc_dm_cancelar(v_ejecucion_id);

  -- Paso 2: matar la sesion principal si sigue viva.
  v_viva := pkg_dm_trazabilidad.func_dm_sesion_viva(v_ejecucion_id);
  if v_viva = 1 and v_sid is not null and v_serial is not null and v_inst_id is not null then
    say('Paso 2/5: la sesion principal sigue viva -- ALTER SYSTEM KILL SESSION...');
    begin
      execute immediate
        'ALTER SYSTEM KILL SESSION '''||v_sid||','||v_serial||',@'||v_inst_id||''' IMMEDIATE';
      say('  KILL SESSION emitido para sid='||v_sid||', serial#='||v_serial||', inst_id='||v_inst_id||'.');
    exception
      -- ORA-00031 (marcada para matar) y ORA-00030 (ya no existe) son respuestas NORMALES
      -- de KILL IMMEDIATE sobre una sesion dentro de una llamada no interrumpible
      -- (RUN_TASK): Oracle lo deja pendiente. Solo -1031 (privilegio) y -27 (matarse a si
      -- mismo) son fallo real; lo demas pasa al paso de confirmacion con gv$session.
      when others then
        if sqlcode in (-31, -30) then
          say('  KILL SESSION respondio '||sqlcode||' ('||substr(sqlerrm,1,200)||
              ') -- normal para una sesion bloqueada en una llamada no interrumpible; '||
              'se confirma con gv$session en vez de asumir nada.');
        elsif sqlcode = -1031 then
          raise_application_error(-20604,
            'ORA-01031 (privilegios insuficientes) al intentar ALTER SYSTEM KILL SESSION. Conectese con un '||
            'usuario que tenga el privilegio ALTER SYSTEM (p.ej. AS SYSDBA) y reintente.');
        elsif sqlcode = -27 then
          raise_application_error(-20607,
            'ORA-00027: el sid/serial#/inst_id grabado en TDM_EJECUCION ('||v_sid||','||v_serial||',@'||v_inst_id||
            ') es el de ESTA MISMA sesion que esta corriendo este script -- algo no cuadra en los datos de '||
            'sesion de ejecucion_id='||v_ejecucion_id||'. Revise a mano antes de continuar.');
        else
          say('  NO se pudo matar la sesion: '||substr(sqlerrm,1,300));
          raise_application_error(-20604,
            'ALTER SYSTEM KILL SESSION fallo con un error no reconocido (ver arriba). No se continua: no se '||
            'puede confirmar que la sesion original este muerta.');
        end if;
    end;
  elsif v_viva = 1 then
    -- Solo hay sesion_audsid (fallback debil de func_dm_sesion_viva): KILL SESSION necesita
    -- sid/serial#, no audsid. Mejor parar que armar un KILL con datos inventados.
    raise_application_error(-20606,
      'La sesion original parece viva (via sesion_audsid) pero TDM_EJECUCION no tiene sid/serial#/inst_id '||
      'grabados para construir el KILL SESSION con certeza. Identifiquela a mano: '||
      'SELECT sid, serial#, inst_id FROM gv$session WHERE audsid = (SELECT sesion_audsid FROM tdm_ejecucion '||
      'WHERE ejecucion_id = '||v_ejecucion_id||'); matela y vuelva a correr este script.');
  else
    say('Paso 2/5: la sesion principal ya no esta viva -- no hace falta matarla.');
  end if;

  say('  Verificando que la sesion principal ya no aparece en gv$session...');
  loop
    v_viva := pkg_dm_trazabilidad.func_dm_sesion_viva(v_ejecucion_id);
    exit when v_viva = 0;
    v_intentos := v_intentos + 1;
    if v_intentos >= c_max_intentos then
      raise_application_error(-20605,
        'La sesion original (sid='||v_sid||', serial#='||v_serial||', inst_id='||v_inst_id||
        ') sigue apareciendo viva en gv$session tras '||(c_max_intentos*c_espera_seg)||'s de espera '||
        'desde el KILL SESSION. No se continua -- verifiquela a mano.');
    end if;
    espera(c_espera_seg);
  end loop;
  say('  Confirmado: sin sesion principal viva ('||(v_intentos*c_espera_seg)||'s de espera).');

  -- Paso 3: workers. Con nivel de paralelismo 1 no hay (los chunks corrian en la sesion
  -- principal, ya muerta); con 2 o mas son jobs de DBMS_SCHEDULER que sobreviven al orquestador.
  say('Paso 3/5: buscando jobs worker de las tareas de esta ejecucion...');
  revisa_workers(false, v_workers);
  if v_workers = 0 then
    say('  Ninguno vivo.');
  else
    say('  Encontrados '||v_workers||' worker(s) vivo(s): se matan (cada chunk es atomico, el que estaba en curso se revierte entero).');
    revisa_workers(true, v_workers);
    v_intentos := 0;
    loop
      revisa_workers(false, v_workers);
      exit when v_workers = 0;
      v_intentos := v_intentos + 1;
      if v_intentos >= c_max_intentos then
        raise_application_error(-20609,
          'Siguen '||v_workers||' worker(s) vivo(s) tras '||(c_max_intentos*c_espera_seg)||'s desde el KILL SESSION. '||
          'No se continua: verifiquelos con @dm_monitor '||v_ejecucion_id||'.');
      end if;
      espera(c_espera_seg);
    end loop;
    say('  Confirmado: ningun worker vivo.');
  end if;

  -- Paso 4: tareas y chunks. Con la sesion y los workers muertos ya no hay ejecutores:
  -- INFORMAR deja las tareas reanudables; DESCARTAR las borra.
  say('Paso 4/5: tareas DBMS_PARALLEL_EXECUTE y chunks'||
      case when v_descartar then ' -- se DESCARTAN (DROP_TASK)...' else ' -- se dejan intactas y reanudables...' end);
  pkg_dm_enmascarar.proc_dm_gestiona_tareas(v_ejecucion_id,
    case when v_descartar then 'DESCARTAR' else 'INFORMAR' end);

  -- Paso 5: cerrar la fila a ABORTADA si se quedo colgada en EJECUTANDO.
  say('Paso 5/5: verificando estado de TDM_EJECUCION...');
  update tdm_ejecucion
     set estado = 'ABORTADA',
         fecha_fin = systimestamp,
         ultimo_paso = 'CERRADA_DM_ENMASCARA_CANCEL_'||to_char(systimestamp,'YYYYMMDDHH24MISS')
   where ejecucion_id = v_ejecucion_id
     and estado = 'EJECUTANDO';
  if sql%rowcount > 0 then
    say('  Fila cerrada a ABORTADA (seguia en EJECUTANDO tras matar la sesion).');
    commit;
  else
    say('  La fila ya habia pasado a otro estado final por su cuenta (CANCELADO/ERROR) -- no hace falta forzarla.');
  end if;

  say('=========================================');
  say('Cancelacion completada: ejecucion_id='||v_ejecucion_id||' abortada, sin sesion ni workers vivos.');
  if v_descartar then
    say('Tareas descartadas. Las filas que ya estaban cifradas SIGUEN cifradas: restaure el dato original');
    say('antes de relanzar. Si abandona la ejecucion para siempre: @dm_pepper_purgar '||v_ejecucion_id||'.');
  else
    say('Las tareas quedan intactas y reanudables. Para continuar sin reprocesar lo ya cifrado:');
    say('  @dm_enmascara_reanudar '||v_ejecucion_id);
    say('Para abandonarla del todo: repita con DESCARTAR (y restaure el dato) y luego @dm_pepper_purgar '||v_ejecucion_id||'.');
  end if;
  say('=========================================');
end;
/

undefine 1
undefine 2
undefine 3
undefine V_ARG1
undefine V_ARG2
undefine V_ARG3
undefine V_CONFIRMA
