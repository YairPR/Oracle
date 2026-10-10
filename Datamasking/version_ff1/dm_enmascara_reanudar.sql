undefine V_ARG1
undefine V_ARG2
undefine V_EJEC_ID

set serveroutput on size unlimited
set verify off
set feedback off
set define on
set linesize 220
set pagesize 200
set trimspool on
set tab off

Rem --- Esquema del motor: se detecta solo (ASTSYSADMIN o ACC_ADMIN), sin setear nada a mano
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

Rem =========================================================================
Rem dm_enmascara_reanudar.sql -- revisa, limpia y reanuda un enmascarado interrumpido
Rem =========================================================================
Rem Uso:
Rem   @dm_enmascara_reanudar EJECUCION_ID [commit_lote]
Rem Ejemplo:
Rem   @dm_enmascara_reanudar 2
Rem   @dm_enmascara_reanudar 2 1000
Rem
Rem QUE HACE, en 4 pasos que va narrando:
Rem   [1/4] REVISION: busca lo que dejo la ejecucion anterior -- sesion principal,
Rem         fila de control en TDM_EJECUCION, jobs worker (DBMS_SCHEDULER) y tareas /
Rem         chunks de DBMS_PARALLEL_EXECUTE -- y lo cuenta.
Rem   [2/4] LIMPIEZA (solo si hay restos): espera a los workers que sigan vivos y, si
Rem         no terminan, mata sus sesiones (cada chunk confirma UPDATE + estado
Rem         PROCESSED en UN solo commit, asi que el kill revierte el chunk entero y
Rem         nunca deja medio cifrado); cierra a ABORTADA la fila que quedo en
Rem         EJECUTANDO; y reconcilia cada tarea interrumpida con RESUME_TASK, que
Rem         NO reprocesa los chunks ya PROCESSED (FF1 no es idempotente: cifrar dos
Rem         veces rompe la reversibilidad).
Rem   [3/4] LIMPIEZA COMPLETADA: dice hasta donde habia llegado (tabla.columna, chunks
Rem         y filas aproximadas) y cuantas columnas quedan.
Rem   [4/4] REANUDANDO: pkg_dm_enmascarar.proc_dm_reanudar -- salta las columnas ya
Rem         confirmadas en TDM_MASK_TRACE y reutiliza el MISMO pepper.
Rem
Rem LO QUE NUNCA HACE: matar la sesion PRINCIPAL. Si sigue viva (aunque este colgada)
Rem se detiene y apunta a @dm_enmascara_cancel EJECUCION_ID CONFIRMAR, que es la unica
Rem puerta para abortar (incidente real ejecucion_id=5: reanudar sobre una sesion viva
Rem lanza una segunda ejecucion en paralelo).
Rem
Rem Si algo no se puede resolver con seguridad (tarea de otra ejecucion, tabla recargada,
Rem RESUME_TASK que falla) se detiene SIN reanudar: relanzar esa columna podria cifrar
Rem dos veces filas ya cifradas.
Rem
Rem PRIVILEGIOS: matar sesiones worker exige ALTER SYSTEM (conectar como SYS o un DBA);
Rem sin el, el script se detiene en ese punto y lo dice. Compatible 11g / 19c / 26ai.
Rem
Rem MODIFICADO   (MM/DD/YY)
Rem epurisaca    09/20/26 - Creacion, tras una caida real de sesion
Rem                         (ORA-03113) tras 41/77 columnas enmascaradas.
Rem epurisaca    10/09/26 - Pasa a ser la unica puerta de reanudacion: revisa sesiones,
Rem                         jobs, chunks y tareas, limpia, dice desde donde reanuda y
Rem                         reanuda (antes se detenia con ORA-20504 si la fila seguia
Rem                         EJECUTANDO y las tareas huerfanas se resolvian a mano).
Rem epurisaca    10/10/26 - La revision previa reconoce las tareas de la ejecucion con
Rem                         pkg_dm_enmascarar.func_dm_tareas_de_ejecucion (mismo criterio que la
Rem                         reconciliacion). Antes emparejaba por DBA_PARALLEL_EXECUTE_TASKS.SQL_STMT y en
Rem                         la primera reanudacion real conto 0 tareas de la ejecucion (habia 1), lo que
Rem                         habria dejado sin detectar workers vivos. Con un paquete 05 anterior sigue
Rem                         funcionando, pero avisa. Las lineas Rem que preceden a un DECLARE ya no
Rem                         terminan en guion (SQL*Plus no abria el bloque).
Rem =========================================================================

prompt Reanudando enmascaramiento.....

set termout off

column "2" new_value 2 noprint
select null as "2" from dual where 1=2;

column final_p1 new_value V_ARG1 noprint
column final_p2 new_value V_ARG2 noprint

select trim('&1') final_p1,
       trim('&2') final_p2
from dual;

set termout on

variable v_ok varchar2(1)
begin :v_ok := 'N'; end;
/

Rem ---------------------------------------------------------------------
Rem Bloque A: revisar y limpiar. Termina (y por tanto SE IMPRIME) antes de reanudar.
Rem =====================================================================

declare
    v_tok1               varchar2(4000) := trim('&&V_ARG1');
    v_tok2               varchar2(4000) := trim('&&V_ARG2');

    v_ejecucion_id       number;
    v_esquema            varchar2(128);
    v_estado             varchar2(30);
    v_fase               varchar2(30);
    v_sid                number;
    v_serial             number;
    v_inst_id            number;
    v_hb                 timestamp;
    v_viva               number;

    v_pred               varchar2(32767);   -- condicion SQL que dice "esta tarea (alias t) es de esta ejecucion"
    v_sql_workers        varchar2(32767);
    v_metodo             varchar2(10);     -- PAQUETE (func_dm_tareas_de_ejecucion) o SQL_STMT (respaldo)
    v_workers            pls_integer := 0;
    v_n_tareas           number := 0;
    v_n_chunks           number := 0;
    v_n_proc             number := 0;
    v_n_asg              number := 0;
    v_n_otras            number := 0;
    v_hallazgos          pls_integer := 0;
    v_i                  pls_integer := 0;

    c_espera_seg         constant number := 2;
    c_max_espera_nat     constant pls_integer := 15;   -- 15 x 2s = 30s dejando terminar a los workers
    c_max_espera_kill    constant pls_integer := 30;   -- 30 x 2s = 60s hasta confirmar que ya no estan

    procedure say(p_txt in varchar2) is
    begin
        dbms_output.put_line(p_txt);
    end;

    -- Decide como reconocer las tareas de ESTA ejecucion y arma el SQL de los workers.
    -- 1) Preferido: pkg_dm_enmascarar.func_dm_tareas_de_ejecucion, el mismo criterio que usa la
    --    reconciliacion (lee USER_PARALLEL_EXECUTE_TASKS con derechos del esquema del motor).
    -- 2) Respaldo (paquete 05 anterior a 2026-10-10, sin esa funcion): emparejar por
    --    DBA_PARALLEL_EXECUTE_TASKS.SQL_STMT. En la primera reanudacion real este respaldo NO vio
    --    la tarea (0 de 1), por eso solo se usa avisando.
    -- El id es numerico y los nombres de tarea se validan: se pueden concatenar en el SQL.
    procedure carga_tareas is
        l_lista varchar2(4000);
        l_n     pls_integer;
        l_nom   varchar2(128);
    begin
        begin
            execute immediate
                'begin :l := pkg_dm_enmascarar.func_dm_tareas_de_ejecucion(:e); end;'
                using out l_lista, in v_ejecucion_id;
            v_metodo := 'PAQUETE';
        exception
            when others then
                v_metodo := 'SQL_STMT';
                l_lista  := null;
        end;

        if v_metodo = 'PAQUETE' then
            if l_lista is null then
                v_pred := '1 = 0';
            else
                v_pred := null;
                l_n := regexp_count(l_lista, ',') + 1;
                for k in 1 .. l_n loop
                    l_nom := trim(regexp_substr(l_lista, '[^,]+', 1, k));
                    if not regexp_like(l_nom, '^[A-Za-z0-9_$#]+$') then
                        raise_application_error(-20508, 'Nombre de tarea no valido: ' || l_nom);
                    end if;
                    v_pred := v_pred || case when v_pred is not null then ',' end || '''' || l_nom || '''';
                end loop;
                v_pred := 't.task_name in (' || v_pred || ')';
            end if;
        else
            v_pred := 'dbms_lob.instr(t.sql_stmt, ''proc_dm_set_ejecucion(' || to_char(v_ejecucion_id) || ')'') > 0';
        end if;

        v_sql_workers :=
            'select r.job_name, r.session_id, s.serial#, r.running_instance, s.status '||
            '  from dba_scheduler_running_jobs r, gv$session s '||
            ' where r.owner = :own '||
            '   and s.inst_id = r.running_instance and s.sid = r.session_id '||
            '   and r.job_name in (select c.job_name '||
            '                        from dba_parallel_execute_chunks c, dba_parallel_execute_tasks t '||
            '                       where t.task_owner = :own2 '||
            '                         and t.task_name like ''TDM\_%'' escape ''\'' '||
            '                         and ' || v_pred || ' '||
            '                         and c.task_owner = t.task_owner and c.task_name = t.task_name '||
            '                         and c.job_name is not null)';
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

    -- Cuenta (y opcionalmente mata) los jobs worker vivos de las tareas de ESTA ejecucion.
    -- El id de ejecucion va como literal en el SQL de cada chunk (proc_dm_set_ejecucion(<id>)),
    -- asi no se toca el worker de ninguna otra ejecucion.
    procedure revisa_workers(p_matar in boolean, p_vivos out pls_integer) is
        c_cur   sys_refcursor;
        l_job   varchar2(128);
        l_sid   number;
        l_ser   number;
        l_inst  number;
        l_st    varchar2(20);
    begin
        p_vivos := 0;
        open c_cur for v_sql_workers using '&&esquemaast', '&&esquemaast';
        loop
            fetch c_cur into l_job, l_sid, l_ser, l_inst, l_st;
            exit when c_cur%notfound;
            if nvl(l_st,'?') <> 'KILLED' then
                p_vivos := p_vivos + 1;
                if p_matar then
                    say('    matando el worker '||l_job||' (sid='||l_sid||', serial#='||l_ser||', inst_id='||l_inst||')...');
                    begin
                        execute immediate
                            'alter system kill session '''||l_sid||','||l_ser||',@'||l_inst||''' immediate';
                    exception
                        when others then
                            if sqlcode in (-31, -30) then
                                null;   -- marcada para matar / ya no existe: respuesta normal de KILL IMMEDIATE
                            elsif sqlcode = -1031 then
                                raise_application_error(-20506,
                                    'ORA-01031: sin privilegio ALTER SYSTEM para matar el worker '||l_job||
                                    '. Conectese como SYS o un DBA con ese privilegio y repita @dm_enmascara_reanudar '||
                                    v_ejecucion_id||'.');
                            else
                                say('    NO se pudo matar: '||substr(sqlerrm,1,200));
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

    procedure cuenta_tareas is
    begin
        execute immediate
            'select count(distinct t.task_name), count(c.chunk_id), '||
            '       nvl(sum(case when c.status = ''PROCESSED'' then 1 else 0 end),0), '||
            '       nvl(sum(case when c.status = ''ASSIGNED''  then 1 else 0 end),0) '||
            '  from dba_parallel_execute_tasks t, dba_parallel_execute_chunks c '||
            ' where t.task_owner = :own '||
            '   and t.task_name like ''TDM\_%'' escape ''\'' '||
            '   and ' || v_pred || ' '||
            '   and c.task_owner(+) = t.task_owner and c.task_name(+) = t.task_name'
            into v_n_tareas, v_n_chunks, v_n_proc, v_n_asg
            using '&&esquemaast';
        select count(*) into v_n_otras
          from dba_parallel_execute_tasks
         where task_owner = '&&esquemaast'
           and task_name like 'TDM\_%' escape '\';
        v_n_otras := v_n_otras - v_n_tareas;
    end;
begin
    if v_tok1 is null or not regexp_like(v_tok1, '^[0-9]+$') then
        raise_application_error(-20501,
            'Uso: @dm_enmascara_reanudar EJECUCION_ID [commit_lote]');
    end if;
    v_ejecucion_id := to_number(v_tok1);

    if v_tok2 is not null then
        if not regexp_like(v_tok2, '^[0-9]+$') then
            raise_application_error(-20502, 'commit_lote debe ser numerico.');
        end if;
    end if;

    begin
        select ora_esquema, estado, fase_proceso,
               sesion_sid, sesion_serial, sesion_inst_id, heartbeat_ts
          into v_esquema, v_estado, v_fase,
               v_sid, v_serial, v_inst_id, v_hb
          from tdm_ejecucion
         where ejecucion_id = v_ejecucion_id;
    exception
        when no_data_found then
            raise_application_error(-20503,
                'No existe la ejecucion_id ' || v_ejecucion_id || ' en TDM_EJECUCION.');
    end;

    -- Mismo error humano que dm_descubre_reanudar corrido sobre una fila de otra fase.
    if upper(nvl(v_fase,'?')) <> 'ENMASCARAMIENTO' then
        raise_application_error(-20505,
            'TDM_EJECUCION.ejecucion_id=' || v_ejecucion_id || ' esta en fase ' || nvl(v_fase,'?') ||
            ', no ENMASCARAMIENTO -- este script reanuda enmascarado, no descubrimiento. ' ||
            case when upper(nvl(v_fase,'?')) = 'DESCUBRIMIENTO'
                 then 'Use @dm_descubre_reanudar ' || v_ejecucion_id || ' en su lugar.'
                 else 'Revise TDM_EJECUCION.fase_proceso antes de continuar.'
            end);
    end if;

    carga_tareas;

    say('=========================================');
    say('Reanudacion de enmascaramiento -- ejecucion_id=' || v_ejecucion_id || ' (esquema ' || v_esquema || ')');
    say('Estado en TDM_EJECUCION : ' || nvl(v_estado,'?') ||
        case when v_hb is not null
             then '   (ultimo latido ' || to_char(v_hb,'DD/MM HH24:MI:SS') || ')' end);
    say('=========================================');

    -- ------------------------------------------------------------------
    say('[1/4] REVISION de lo que dejo la ejecucion anterior...');
    -- ------------------------------------------------------------------
    v_viva := pkg_dm_trazabilidad.func_dm_sesion_viva(v_ejecucion_id);
    if v_viva = 1 then
        say('  Sesion principal   : VIVA (sid=' || nvl(to_char(v_sid),'?') || ', serial#=' || nvl(to_char(v_serial),'?') ||
            ', inst_id=' || nvl(to_char(v_inst_id),'?') || ')');
        raise_application_error(-20504,
            'La sesion principal de la ejecucion_id=' || v_ejecucion_id || ' sigue VIVA: esta ejecucion no esta '||
            'interrumpida, esta en marcha (o colgada). Desde aqui no se toca. Siga su avance con @dm_monitor ' ||
            v_ejecucion_id || '; si de verdad esta colgada o quiere abortarla use @dm_enmascara_cancel ' ||
            v_ejecucion_id || ' CONFIRMAR y despues vuelva a reanudar.');
    end if;
    say('  Sesion principal   : ' ||
        case when v_sid is null then 'no hay sesion registrada'
             else 'sid=' || v_sid || ', serial#=' || nvl(to_char(v_serial),'?') || ', inst_id=' ||
                  nvl(to_char(v_inst_id),'?') || ' -- ya NO existe' end);

    if upper(nvl(v_estado,'?')) = 'EJECUTANDO' then
        v_hallazgos := v_hallazgos + 1;
        say('  Fila de control    : sigue EJECUTANDO pero sin sesion (quedo huerfana: la sesion se cayo sin cerrarla)');
    else
        say('  Fila de control    : ' || nvl(v_estado,'?'));
    end if;

    if v_metodo = 'SQL_STMT' then
        say('  AVISO              : el paquete instalado no tiene func_dm_tareas_de_ejecucion (reinstale 05_dm_pkg_enmascarar.sql).');
        say('                       Se empareja por SQL_STMT, que puede NO ver las tareas ni los workers de esta ejecucion.');
        say('                       Verifique los workers con @dm_monitor ' || v_ejecucion_id || ' antes de seguir.');
    end if;

    revisa_workers(false, v_workers);
    if v_workers > 0 then v_hallazgos := v_hallazgos + 1; end if;
    say('  Jobs worker vivos  : ' || v_workers ||
        case when v_workers > 0 then '  (siguen procesando chunks de esta ejecucion)' end);

    cuenta_tareas;
    if v_n_tareas > 0 then v_hallazgos := v_hallazgos + 1; end if;
    say('  Tareas paralelas   : ' || v_n_tareas || '  (chunks: total=' || v_n_chunks || ', PROCESSED=' || v_n_proc ||
        ', ASSIGNED=' || v_n_asg || ')');
    if v_n_otras > 0 then
        say('  Otras tareas TDM_% : ' || v_n_otras || '  (de otras ejecuciones o versiones antiguas: no se tocan aqui)');
    end if;

    if v_hallazgos = 0 then
        say('  Resultado: no se encontraron sesiones, jobs, tareas ni chunks anteriores. Nada que limpiar.');
    else
        say('  Resultado: se encontraron restos de la ejecucion anterior. Se procede a limpiar.');

        -- --------------------------------------------------------------
        say('[2/4] LIMPIEZA...');
        -- --------------------------------------------------------------
        if v_workers > 0 then
            say('  Jobs worker: se esperan hasta ' || (c_max_espera_nat * c_espera_seg) || 's a que terminen sus chunks...');
            v_i := 0;
            loop
                revisa_workers(false, v_workers);
                exit when v_workers = 0 or v_i >= c_max_espera_nat;
                v_i := v_i + 1;
                espera(c_espera_seg);
            end loop;
            if v_workers > 0 then
                say('  Siguen ' || v_workers || ' worker(s) vivo(s): se matan sus sesiones. Cada chunk es atomico (UPDATE +');
                say('  PROCESSED en un solo commit): el chunk en curso se revierte entero y se rehace al reanudar.');
                revisa_workers(true, v_workers);
                v_i := 0;
                loop
                    revisa_workers(false, v_workers);
                    exit when v_workers = 0;
                    v_i := v_i + 1;
                    if v_i >= c_max_espera_kill then
                        raise_application_error(-20507,
                            'Siguen ' || v_workers || ' worker(s) vivo(s) tras ' || (c_max_espera_kill * c_espera_seg) ||
                            's desde el KILL SESSION. No se continua: verifiquelos con @dm_monitor ' || v_ejecucion_id || '.');
                    end if;
                    espera(c_espera_seg);
                end loop;
            end if;
            say('  Jobs worker: ninguno vivo.');
        end if;

        if upper(nvl(v_estado,'?')) = 'EJECUTANDO' then
            update tdm_ejecucion
               set estado = 'ABORTADA',
                   fecha_fin = systimestamp,
                   ultimo_paso = 'CERRADA_DM_ENMASCARA_REANUDAR_' || to_char(systimestamp,'YYYYMMDDHH24MISS')
             where ejecucion_id = v_ejecucion_id
               and estado = 'EJECUTANDO';
            commit;
            say('  Fila de control: cerrada a ABORTADA (el pepper se conserva para reanudar).');
        end if;
    end if;

    -- Siempre: reconciliar tareas (si no hay ninguna solo informa las columnas pendientes).
    if v_n_tareas > 0 then
        say('  Tareas paralelas: se reanuda cada columna interrumpida SIN reprocesar sus chunks PROCESSED...');
    end if;
    pkg_dm_enmascarar.proc_dm_gestiona_tareas(v_ejecucion_id, 'RECONCILIAR');

    say('[3/4] ' || case when v_hallazgos > 0 then 'LIMPIEZA COMPLETADA.' else 'NADA QUE LIMPIAR.' end);
    say('[4/4] REANUDANDO ejecucion_id=' || v_ejecucion_id || ': se omiten las columnas ya terminadas y se procesan las');
    say('      pendientes con el mismo pepper (pkg_dm_enmascarar.proc_dm_reanudar). Al terminar se imprime el resumen.');
    say('=========================================');
    :v_ok := 'Y';
exception
    when others then
        say('=========================================');
        say('NO SE REANUDA: ' || sqlerrm);
        say('Corrija lo indicado y repita @dm_enmascara_reanudar ' || nvl(to_char(v_ejecucion_id), '<ejecucion_id>') || '.');
        say('=========================================');
end;
/

Rem ---------------------------------------------------------------------
Rem Bloque B: reanudar de verdad y resumir.
Rem =====================================================================

declare
    v_ejecucion_id       number;
    v_commit_lote        number := 1000;

    v_solicitud_id       number := -1;

    v_estado_post        varchar2(30);
    v_progreso_post      number;
    v_columnas_proc_post number;
    v_ultimo_paso_post   varchar2(4000);
    v_ultimo_objeto_post varchar2(4000);
    v_fecha_fin_post     date;

    v_cnt_warns          number := 0;
    v_cnt_errs_trace     number := 0;
    v_cnt_errs_log       number := 0;
    v_reintento          number;
    v_detalle_ejec       varchar2(4000);
begin
    if :v_ok <> 'Y' then
        dbms_output.put_line('Reanudacion NO iniciada (ver el mensaje anterior).');
        return;
    end if;

    v_ejecucion_id := to_number('&&V_ARG1');
    if '&&V_ARG2' is not null then
        v_commit_lote := to_number('&&V_ARG2');
    end if;

    pkg_dm_enmascarar.proc_dm_reanudar(
        p_ejecucion_id => v_ejecucion_id,
        p_commit_lote  => v_commit_lote
    );

    begin
        select nvl(max(s.solicitud_id), -1)
          into v_solicitud_id
          from tdm_mask_solicitud s
         where s.ejecucion_id = v_ejecucion_id;
    exception
        when others then
            v_solicitud_id := -1;
    end;

    select estado,
           progreso_pct,
           columnas_proc,
           ultimo_paso,
           ultimo_objeto,
           cast(fecha_fin as date)
      into v_estado_post,
           v_progreso_post,
           v_columnas_proc_post,
           v_ultimo_paso_post,
           v_ultimo_objeto_post,
           v_fecha_fin_post
      from tdm_ejecucion
     where ejecucion_id = v_ejecucion_id;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Resumen final');
    dbms_output.put_line('Solicitud_id        : ' || case when v_solicitud_id = -1 then '(no encontrada)' else to_char(v_solicitud_id) end);
    if v_solicitud_id <> -1 then
        begin
            select reintento_nro into v_reintento from tdm_mask_solicitud where solicitud_id = v_solicitud_id;
            dbms_output.put_line('Intento             : ' || v_reintento || '  (reanudacion ' || (v_reintento - 1) || ')');
        exception when others then null;
        end;
    end if;
    begin
        select detalle into v_detalle_ejec from tdm_ejecucion where ejecucion_id = v_ejecucion_id;
        if v_detalle_ejec is not null then
            dbms_output.put_line('Detalle ejecucion   : ' || substr(v_detalle_ejec,1,200));
        end if;
    exception when others then null;
    end;
    dbms_output.put_line('Estado actual       : ' || v_estado_post);
    dbms_output.put_line('Progreso %          : ' || v_progreso_post);
    dbms_output.put_line('Columnas procesadas : ' || v_columnas_proc_post);

    if v_fecha_fin_post is not null then
        dbms_output.put_line('Fin ejecucion       : ' || to_char(v_fecha_fin_post, 'dd-mm-yyyy hh24:mi:ss'));
    end if;

    if v_ultimo_paso_post is not null then
        dbms_output.put_line('Ultimo paso         : ' || substr(v_ultimo_paso_post,1,200));
    end if;

    if v_ultimo_objeto_post is not null then
        dbms_output.put_line('Ultimo objeto       : ' || substr(v_ultimo_objeto_post,1,200));
    end if;

    if upper(nvl(v_estado_post,'?')) = 'ERROR' then
        dbms_output.put_line('ADVERTENCIA FINAL   : La ejecucion quedo en ERROR. Revisar TDM_EJECUCION_ERROR/TDM_MASK_TRACE.');
    end if;

    if v_solicitud_id <> -1 then
        begin
            select count(*) into v_cnt_warns
              from tdm_mask_trace where solicitud_id = v_solicitud_id and nivel = 'WARN';
        exception when others then null;
        end;
        begin
            select count(*) into v_cnt_errs_trace
              from tdm_mask_trace where solicitud_id = v_solicitud_id and nivel = 'ERROR';
        exception when others then null;
        end;
    end if;

    begin
        select count(*) into v_cnt_errs_log
          from tdm_ejecucion_error where ejecucion_id = v_ejecucion_id;
    exception when others then null;
    end;

    -- Fases de ESTE intento, en el orden en que ocurrieron (de TDM_MASK_TRACE).
    if v_solicitud_id <> -1 then
        dbms_output.put_line('=========================================');
        dbms_output.put_line('Fases de este intento (solicitud ' || v_solicitud_id || ')');
        dbms_output.put_line(rpad('FASE',17) || rpad('EVENTOS',9) || rpad('INICIO',10) || rpad('FIN',10) || rpad('WARN',6) || 'ERROR');
        for f in (select fase, count(*) n, min(fecha_evento) f_ini, max(fecha_evento) f_fin,
                         sum(case when nivel = 'WARN'  then 1 else 0 end) w,
                         sum(case when nivel = 'ERROR' then 1 else 0 end) e
                    from tdm_mask_trace
                   where solicitud_id = v_solicitud_id
                   group by fase
                   order by min(trace_id)) loop
            dbms_output.put_line(rpad(f.fase,17) || rpad(f.n,9) ||
                                 rpad(to_char(f.f_ini,'hh24:mi:ss'),10) ||
                                 rpad(to_char(f.f_fin,'hh24:mi:ss'),10) ||
                                 rpad(f.w,6) || f.e);
        end loop;
    end if;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Alertas en trace (WARN)  : ' || v_cnt_warns);
    dbms_output.put_line('Errores en trace (ERROR) : ' || v_cnt_errs_trace);
    dbms_output.put_line('Errores en log de fallas : ' || v_cnt_errs_log);
    dbms_output.put_line('=========================================');
end;
/

undefine 1
undefine 2
undefine V_ARG1
undefine V_ARG2
undefine V_EJEC_ID
