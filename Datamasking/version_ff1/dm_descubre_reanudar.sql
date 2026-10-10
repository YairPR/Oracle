undefine V_ARG1
undefine V_ARG2
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

Rem =========================================================================
Rem dm_descubre_reanudar.sql -- reanuda un DESCUBRIMIENTO interrumpido
Rem =========================================================================
Rem Uso:
Rem   @dm_descubre_reanudar EJECUCION_ID [sample_rows] [commit_lote]
Rem Ejemplo:
Rem   @dm_descubre_reanudar 7
Rem   @dm_descubre_reanudar 7 500
Rem   @dm_descubre_reanudar 7 500 100
Rem
Rem POR QUE EXISTE: pkg_dm_descubrimiento.proc_dm_reanudar (04) ya existia
Rem como punto de entrada publico -- misma idea que pkg_dm_enmascarar.proc_dm_reanudar,
Rem resuelve por donde se quedo via TDM_EJECUCION_SCOPE/TDM_COLUMNA_HIST -- pero
Rem ningun script .sql lo invocaba: si una sesion de @dm_descubre caia a mitad
Rem de camino (ORA-03113/caida de red/Ctrl+C), la unica forma de continuar era
Rem relanzar @dm_descubre desde cero (reescaneando todo el esquema de nuevo),
Rem o llamar al procedimiento a mano con EXEC sin ninguna de las comprobaciones
Rem ni el resumen que este script da.
Rem
Rem FIX 2026-10-05 incluido junto con la creacion de este driver: antes de
Rem publicarlo se reviso pkg_dm_descubrimiento.proc_dm_reanudar y se le porto el
Rem mismo fix critico que ya tiene pkg_dm_enmascarar.proc_dm_reanudar desde el
Rem 2026-10-04 (incidente real ejecucion_id=5, 7 constraints deshabilitadas):
Rem la comprobacion de sesion viva (gv$session) es ahora INCONDICIONAL, no
Rem depende de que ESTADO siga marcado como EJECUTANDO. Sin ese fix, publicar
Rem este driver habria dejado abierta la misma clase de incidente pero para
Rem DESCUBRIMIENTO en vez de ENMASCARAMIENTO -- se corrigio antes de exponerlo.
Rem
Rem PRECONDICION: TDM_EJECUCION para esta ejecucion_id NO debe estar ya en
Rem estado='EJECUTANDO'. Si lo esta, este script se detiene y señala el
Rem remedio: libere esa fila primero con @dm_liberar_ejecucion_activa ESQUEMA
Rem (revise la lista que muestra antes de cerrar -- por diseno no se encadena
Rem automaticamente aqui). El propio pkg_dm_descubrimiento.proc_dm_reanudar
Rem vuelve a comprobar esto por su cuenta (defensa en profundidad) aunque esta
Rem precondicion no se salte.
Rem =========================================================================

prompt Reanudando descubrimiento.....

set termout off

column "2" new_value 2 noprint
select null as "2" from dual where 1=2;
-- FIX 2026-10-10: faltaba definir "3". Con un solo argumento (@dm_descubre_reanudar 1) el
-- SELECT de abajo lee &3, SQL*Plus pedia su valor y, con SET TERMOUT OFF, el aviso no se veia:
-- la sesion se quedaba esperando en silencio despues de "Reanudando descubrimiento.....".
column "3" new_value 3 noprint
select null as "3" from dual where 1=2;

column final_p1 new_value V_ARG1 noprint
column final_p2 new_value V_ARG2 noprint
column final_p3 new_value V_ARG3 noprint

select trim('&1') final_p1,
       trim('&2') final_p2,
       trim('&3') final_p3
from dual;

set termout on

declare
    v_tok1               varchar2(4000) := trim('&&V_ARG1');
    v_tok2               varchar2(4000) := trim('&&V_ARG2');
    v_tok3               varchar2(4000) := trim('&&V_ARG3');

    v_ejecucion_id       number;
    v_sample_rows        number := 500;
    v_commit_lote        number := 100;
    v_esquema            varchar2(128);

    v_estado_pre         varchar2(30);
    v_fase_pre           varchar2(30);
    v_progreso_pre       number;
    v_tablas_proc_pre    number;
    v_tablas_total_pre   number;
    v_columnas_proc_pre  number;
    v_columnas_total_pre number;

    v_estado_post        varchar2(30);
    v_progreso_post      number;
    v_tablas_proc_post   number;
    v_columnas_proc_post number;
    v_ultimo_paso_post   varchar2(4000);
    v_ultimo_objeto_post varchar2(4000);
    v_fecha_fin_post     date;

    v_total_columnas     number := 0;
    v_total_enmascarar_y number := 0;
    v_total_tablas       number := 0;

    v_total_excepciones  number := 0;
    v_total_excl         number := 0;
    v_total_force        number := 0;
begin
    if v_tok1 is null or not regexp_like(v_tok1, '^[0-9]+$') then
        raise_application_error(-20511,
            'Uso: @dm_descubre_reanudar EJECUCION_ID [sample_rows] [commit_lote]');
    end if;

    v_ejecucion_id := to_number(v_tok1);

    if v_tok2 is not null and v_tok2 <> '' then
        if not regexp_like(v_tok2, '^[0-9]+$') then
            raise_application_error(-20512, 'sample_rows debe ser numerico.');
        end if;
        v_sample_rows := to_number(v_tok2);
    end if;

    if v_tok3 is not null and v_tok3 <> '' then
        if not regexp_like(v_tok3, '^[0-9]+$') then
            raise_application_error(-20513, 'commit_lote debe ser numerico.');
        end if;
        v_commit_lote := to_number(v_tok3);
    end if;

    begin
        select ora_esquema,
               estado,
               fase_proceso,
               progreso_pct,
               tablas_proc,
               tablas_total,
               columnas_proc,
               columnas_total
          into v_esquema,
               v_estado_pre,
               v_fase_pre,
               v_progreso_pre,
               v_tablas_proc_pre,
               v_tablas_total_pre,
               v_columnas_proc_pre,
               v_columnas_total_pre
          from tdm_ejecucion
         where ejecucion_id = v_ejecucion_id;
    exception
        when no_data_found then
            raise_application_error(-20514,
                'No existe la ejecucion_id ' || v_ejecucion_id || ' en TDM_EJECUCION.');
    end;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Reanudacion de descubrimiento');
    dbms_output.put_line('Ejecucion_id       : ' || v_ejecucion_id);
    dbms_output.put_line('Esquema            : ' || v_esquema);
    dbms_output.put_line('Estado previo       : ' || nvl(v_estado_pre,'?') || ' / fase ' || nvl(v_fase_pre,'?'));
    dbms_output.put_line('Progreso previo (%) : ' || nvl(to_char(v_progreso_pre),'?'));
    dbms_output.put_line('Tablas procesadas   : ' || nvl(to_char(v_tablas_proc_pre),'?') || ' / ' || nvl(to_char(v_tablas_total_pre),'?'));
    dbms_output.put_line('Columnas procesadas : ' || nvl(to_char(v_columnas_proc_pre),'?') || ' / ' || nvl(to_char(v_columnas_total_pre),'?'));
    dbms_output.put_line('=========================================');

    -- FIX 2026-10-10: la fase se comprueba ANTES que el estado. Con una ejecucion de
    -- ENMASCARAMIENTO en estado EJECUTANDO, el aviso de estado mandaba a liberar la fila
    -- (dm_liberar_ejecucion_activa) cuando lo correcto era usar dm_enmascara_reanudar.
    -- FIX 2026-10-06 (incidente real, ejecucion_id=1: este script se corrio
    -- por error sobre una fila cuya fase_proceso real era ENMASCARAMIENTO,
    -- recien abortada por un ALTER SYSTEM KILL SESSION de prueba y liberada
    -- con dm_liberar_ejecucion_activa.sql -- ESTADO quedo en ABORTADA, que es
    -- resumible, asi que el chequeo de arriba no lo frenaba). Mismo criterio
    -- que esa comprobacion: aviso amigable aqui con el remedio directo, antes
    -- de que pkg_dm_descubrimiento.proc_dm_reanudar lo rechace de todas
    -- formas con el ORA-20019 generico (ver su comentario del mismo dia en 04
    -- -- esta comprobacion de aqui no sustituye esa defensa, solo la
    -- adelanta con un mensaje mas claro).
    if upper(nvl(v_fase_pre,'?')) not in ('DESCUBRIMIENTO') then
        raise_application_error(-20516,
            'TDM_EJECUCION.ejecucion_id=' || v_ejecucion_id || ' esta en fase ' || nvl(v_fase_pre,'?') ||
            ', no DESCUBRIMIENTO -- este script reanuda descubrimiento, no enmascarado. ' ||
            case when upper(nvl(v_fase_pre,'?')) = 'ENMASCARAMIENTO'
                 then 'Use @dm_enmascara_reanudar ' || v_ejecucion_id || ' en su lugar.'
                 else 'Revise TDM_EJECUCION.fase_proceso antes de continuar.'
            end);
    end if;

    -- Precondicion: igual criterio que dm_enmascara_reanudar.sql -- si la fila
    -- sigue EJECUTANDO, se falla aqui primero con el remedio directo en vez de
    -- dejar que el operador vea solo el ORA-20017 generico del paquete (que de
    -- todas formas se dispararia igual si la sesion original resultara estar
    -- viva de verdad; esta comprobacion de aqui es un aviso mas amigable, no un
    -- sustituto de esa defensa).
    if upper(nvl(v_estado_pre,'?')) = 'EJECUTANDO' then
        raise_application_error(-20515,
            'TDM_EJECUCION.ejecucion_id=' || v_ejecucion_id || ' sigue en estado EJECUTANDO ' ||
            '(probable sesion anterior caida sin cerrar). Libere esa fila primero con ' ||
            '@dm_liberar_ejecucion_activa ' || v_esquema || ' (revise la lista que muestra antes ' ||
            'de continuar) y vuelva a correr este script.');
    end if;

    dbms_output.put_line('Reanudando via pkg_dm_descubrimiento.proc_dm_reanudar (' ||
                          'retoma por TDM_EJECUCION_SCOPE/TDM_COLUMNA_HIST donde se quedo)...');

    pkg_dm_descubrimiento.proc_dm_reanudar(
        p_ejecucion_id => v_ejecucion_id,
        p_sample_rows  => v_sample_rows,
        p_commit_lote  => v_commit_lote
    );

    select estado,
           progreso_pct,
           tablas_proc,
           columnas_proc,
           ultimo_paso,
           ultimo_objeto,
           cast(fecha_fin as date)
      into v_estado_post,
           v_progreso_post,
           v_tablas_proc_post,
           v_columnas_proc_post,
           v_ultimo_paso_post,
           v_ultimo_objeto_post,
           v_fecha_fin_post
      from tdm_ejecucion
     where ejecucion_id = v_ejecucion_id;

    -- Mismo bloque de resumen que @dm_descubre al terminar, para que el
    -- operador vea exactamente lo mismo tanto si el descubrimiento corrio de
    -- una sola vez como si se reanudo en dos (o mas) tramos.
    begin
        select count(*),
               sum(case when nvl(enmascarar,'N') = 'Y' then 1 else 0 end)
          into v_total_columnas,
               v_total_enmascarar_y
          from tdm_columna_hist
         where ejecucion_id = v_ejecucion_id;
    exception
        when others then
            v_total_columnas     := 0;
            v_total_enmascarar_y := 0;
    end;

    v_total_enmascarar_y := nvl(v_total_enmascarar_y, 0);

    begin
        select count(distinct table_name)
          into v_total_tablas
          from tdm_columna_hist
         where ejecucion_id = v_ejecucion_id;
    exception
        when others then
            v_total_tablas := 0;
    end;

    begin
        select count(*),
               sum(case when accion = 'EXCLUDE' then 1 else 0 end),
               sum(case when accion = 'FORCE'   then 1 else 0 end)
          into v_total_excepciones,
               v_total_excl,
               v_total_force
          from tdm_excepcion_col
         where ora_owner = v_esquema
           and activa = 'Y';
    exception
        when others then
            v_total_excepciones := 0;
            v_total_excl        := 0;
            v_total_force       := 0;
    end;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Resumen final');
    dbms_output.put_line('Estado actual       : ' || v_estado_post);
    dbms_output.put_line('Progreso %          : ' || v_progreso_post);
    dbms_output.put_line('Tablas procesadas   : ' || v_tablas_proc_post);
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

    dbms_output.put_line('-----------------------------------------');
    dbms_output.put_line('Tablas descubiertas y mapeadas : ' || v_total_tablas);
    dbms_output.put_line('Columnas descubiertas  : ' || v_total_columnas);
    dbms_output.put_line('Con enmascarar = Y     : ' || v_total_enmascarar_y);
    dbms_output.put_line('Excepciones activas (TDM_EXCEPCION_COL): ' || nvl(v_total_excepciones,0) ||
                          ' (EXCLUDE=' || nvl(v_total_excl,0) || ', FORCE=' || nvl(v_total_force,0) || ')');
    dbms_output.put_line('=========================================');
end;
/

undefine 1
undefine 2
undefine 3
undefine V_ARG1
undefine V_ARG2
undefine V_ARG3
