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
alter session set current_schema = ASTSYSADMIN;

Rem =========================================================================
Rem dm_enmascara_reanudar.sql -- reanuda un enmascarado interrumpido
Rem =========================================================================
Rem Uso:
Rem   @dm_enmascara_reanudar EJECUCION_ID [commit_lote]
Rem Ejemplo:
Rem   @dm_enmascara_reanudar 2
Rem   @dm_enmascara_reanudar 2 1000
Rem
Rem POR QUE EXISTE: si la sesion SQL*Plus que corria @dm_enmascara se cae a
Rem mitad de camino (ORA-03113/03114 por caida de red, cierre de ventana,
Rem timeout, etc.), las columnas YA enmascaradas quedan comprometidas sin
Rem problema (cada columna se confirma via DBMS_PARALLEL_EXECUTE/COMMIT antes
Rem de pasar a la siguiente) -- lo unico que queda huerfano es la fila de
Rem control en TDM_EJECUCION (estado='EJECUTANDO' para siempre, nadie la
Rem cerro). Sin este script, la unica forma de continuar seria
Rem @dm_enmascara EJECUCION_ID Y -- pero el 'Y' fuerza p_reproceso='Y', que
Rem REPROCESA LAS 77 COLUMNAS DESDE CERO, incluidas las que ya estaban
Rem enmascaradas (horas de trabajo tirado).
Rem
Rem COMO REANUDA SIN REPETIR TRABAJO: llama a
Rem pkg_dm_enmascarar.p_mask_reanudar(ejecucion_id, commit_lote) -- punto de
Rem entrada publico ya incluido en el motor (paquete 05, protegido; ver su
Rem encabezado, seccion de API publica) que:
Rem   1. Ubica la ultima solicitud_id de esta ejecucion_id (la que quedo a
Rem      medias) y la enlaza como base de reanudacion.
Rem   2. Llama a p_dm_enmascara con p_reproceso='N' (el default) -- que hace
Rem      que proc_dm_mask_cat, columna por columna, salte cualquiera que YA
Rem      tenga un registro de exito en TDM_MASK_TRACE para esta
Rem      ejecucion_id (paso APPLY_COL/APPLY_COL_COLLISION/
Rem      APPLY_COL_SAFE_FALLBACK), y solo procese las que faltan.
Rem   3. Reutiliza el MISMO pepper (proc_dm_pepper_generar es idempotente
Rem      por ejecucion_id) -- no hay inconsistencia entre lo ya enmascarado
Rem      y lo que falta.
Rem
Rem PRECONDICION: TDM_EJECUCION para esta ejecucion_id NO debe estar ya en
Rem estado='EJECUTANDO' (justo el estado en que la deja una sesion caida).
Rem Si lo esta, este script se detiene y senala el remedio: libere esa fila
Rem primero con @dm_liberar_ejecucion_activa ESQUEMA (revisa antes de
Rem cerrar -- por diseno no se encadena automaticamente aqui).
Rem
Rem MODIFICADO   (MM/DD/YY)
Rem epurisaca    09/20/26 - Creacion, tras una caida real de sesion
Rem                         (ORA-03113) tras 41/77 columnas enmascaradas.
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

declare
    v_tok1               varchar2(4000) := trim('&&V_ARG1');
    v_tok2               varchar2(4000) := trim('&&V_ARG2');

    v_ejecucion_id       number;
    v_commit_lote        number := 1000;
    v_esquema            varchar2(128);

    v_estado_pre         varchar2(30);
    v_fase_pre           varchar2(30);
    v_progreso_pre       number;
    v_tablas_proc_pre    number;
    v_tablas_total_pre   number;
    v_columnas_proc_pre  number;
    v_columnas_total_pre number;

    v_solicitud_id       number := -1;

    v_estado_post        varchar2(30);
    v_progreso_post      number;
    v_tablas_proc_post   number;
    v_columnas_proc_post number;
    v_ultimo_paso_post   varchar2(4000);
    v_ultimo_objeto_post varchar2(4000);
    v_fecha_fin_post     date;

    v_cnt_warns          number := 0;
    v_cnt_errs_trace     number := 0;
    v_cnt_errs_log       number := 0;
begin
    if v_tok1 is null or not regexp_like(v_tok1, '^[0-9]+$') then
        raise_application_error(-20501,
            'Uso: @dm_enmascara_reanudar EJECUCION_ID [commit_lote]');
    end if;

    v_ejecucion_id := to_number(v_tok1);

    if v_tok2 is not null and v_tok2 <> '' then
        if not regexp_like(v_tok2, '^[0-9]+$') then
            raise_application_error(-20502, 'commit_lote debe ser numerico.');
        end if;
        v_commit_lote := to_number(v_tok2);
    end if;

    begin
        select esquema_objetivo,
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
            raise_application_error(-20503,
                'No existe la ejecucion_id ' || v_ejecucion_id || ' en TDM_EJECUCION.');
    end;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Reanudacion de enmascaramiento');
    dbms_output.put_line('Ejecucion_id       : ' || v_ejecucion_id);
    dbms_output.put_line('Esquema            : ' || v_esquema);
    dbms_output.put_line('Estado previo       : ' || nvl(v_estado_pre,'?') || ' / fase ' || nvl(v_fase_pre,'?'));
    dbms_output.put_line('Progreso previo (%) : ' || nvl(to_char(v_progreso_pre),'?'));
    dbms_output.put_line('Tablas procesadas   : ' || nvl(to_char(v_tablas_proc_pre),'?') || ' / ' || nvl(to_char(v_tablas_total_pre),'?'));
    dbms_output.put_line('Columnas procesadas : ' || nvl(to_char(v_columnas_proc_pre),'?') || ' / ' || nvl(to_char(v_columnas_total_pre),'?'));
    dbms_output.put_line('=========================================');

    -- Precondicion: si la fila sigue EJECUTANDO (tipico de una sesion caida
    -- que nunca la cerro), p_dm_enmascara la va a rechazar de todas formas
    -- (ORA-20097/-20098 via proc_dm_validar_concurrencia) -- se falla aqui
    -- primero con un mensaje que apunta directo al remedio, en vez de dejar
    -- que el operador se encuentre con el error generico del motor.
    if upper(nvl(v_estado_pre,'?')) = 'EJECUTANDO' then
        raise_application_error(-20504,
            'TDM_EJECUCION.ejecucion_id=' || v_ejecucion_id || ' sigue en estado EJECUTANDO ' ||
            '(probable sesion anterior caida sin cerrar). Libere esa fila primero con ' ||
            '@dm_liberar_ejecucion_activa ' || v_esquema || ' (revise la lista que muestra antes ' ||
            'de continuar) y vuelva a correr este script.');
    end if;

    dbms_output.put_line('Reanudando via pkg_dm_enmascarar.p_mask_reanudar (' ||
                          'salta columnas ya confirmadas en TDM_MASK_TRACE, reutiliza el mismo pepper)...');

    pkg_dm_enmascarar.p_mask_reanudar(
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

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Resumen final');
    dbms_output.put_line('Solicitud_id        : ' || case when v_solicitud_id = -1 then '(no encontrada)' else to_char(v_solicitud_id) end);
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
