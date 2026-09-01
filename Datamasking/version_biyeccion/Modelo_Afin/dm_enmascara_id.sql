undefine 1
undefine 2
undefine 3
undefine V_ARG1
undefine V_ARG2
undefine V_ARG3
undefine V_EJEC_ID
undefine V_SOL_ID

set serveroutput on size unlimited
set verify off
set feedback off
set define on
set linesize 220
set pagesize 200
set trimspool on
set tab off

column c_estado         format a18
column c_fase           format a25
column c_fecha          format a19
column c_detalle        format a100 word_wrapped
column c_objeto         format a45
column c_paso           format a35
column c_total          format 999999999
column c_trace_id       format 999999999
column c_nivel          format a8
column c_tipo_objeto    format a12
column c_owner          format a30
column c_table          format a35
column c_objname        format a35
column c_identificador  format a35
column c_column_name    format a35
column c_table_name     format a35

prompt =========================================================
prompt dm_enmascara_id - Masking por identificador
prompt Uso:
prompt   @dm_enmascara_id EJECUCION_ID IDENTIFICADOR %
prompt   @dm_enmascara_id EJECUCION_ID IDENTIFICADOR Y
prompt Ejemplo:
prompt   @dm_enmascara_id 1 IDENTIFICADOR_BANCARIO %
prompt   @dm_enmascara_id 1 IDENTIFICADOR_BANCARIO Y
prompt =========================================================

column 1_col new_value 1 noprint
column 2_col new_value 2 noprint
column 3_col new_value 3 noprint
select null as 1_col, null as 2_col, null as 3_col from dual where 1=2;

column final_p1 new_value V_ARG1 noprint
column final_p2 new_value V_ARG2 noprint
column final_p3 new_value V_ARG3 noprint

select trim('&1') final_p1,
       upper(trim('&2')) final_p2,
       upper(trim(nvl('&3', '%'))) final_p3
from dual;

column c_ejecucion_id new_value V_EJEC_ID noprint
column c_solicitud_id new_value V_SOL_ID  noprint

declare
    v_tok1                  varchar2(4000) := trim('&&V_ARG1');
    v_identificador         varchar2(128)  := upper(trim('&&V_ARG2'));
    v_param                 varchar2(10)   := upper(trim('&&V_ARG3'));

    v_ejecucion_id          number;
    v_esquema               varchar2(128);
    v_en_curso              number := 0;

    v_total_final           number := 0;
    v_total_final_y         number := 0;
    v_total_hist_y          number := 0;
    v_total_identificador   number := 0;
    v_solicitud_id          number := -1;

    v_estado_pre            varchar2(30);
    v_fase_pre              varchar2(30);
    v_fecha_ini_pre         date;
    v_fecha_fin_pre         date;
    v_ultimo_paso_pre       varchar2(4000);
    v_ultimo_objeto_pre     varchar2(4000);
    v_progreso_pre          number;

    v_estado_post           varchar2(30);
    v_fase_post             varchar2(30);
    v_fecha_ini_post        date;
    v_fecha_fin_post        date;
    v_ultimo_paso_post      varchar2(4000);
    v_ultimo_objeto_post    varchar2(4000);
    v_progreso_post         number;

    v_warn_pre_error        varchar2(1) := 'N';
    v_warn_post_error       varchar2(1) := 'N';

    -- R7: Backup y restauración del catálogo original en ejecuciones parciales
    type t_col_state is record (
      owner_name   varchar2(128),
      table_name   varchar2(128),
      column_name  varchar2(128),
      enmascarar   char(1)
    );
    type t_col_list is table of t_col_state index by pls_integer;
    l_backup_final t_col_list;
    l_backup_hist  t_col_list;

begin
    if v_tok1 is null or not regexp_like(v_tok1, '^[0-9]+$') then
        raise_application_error(-20301,
            'Uso: @dm_enmascara_id EJECUCION_ID IDENTIFICADOR % | @dm_enmascara_id EJECUCION_ID IDENTIFICADOR Y');
    end if;

    v_ejecucion_id := to_number(v_tok1);

    if v_identificador is null or v_identificador = '' then
        raise_application_error(-20302,
            'Debe indicar identificador. Ejemplo: IDENTIFICADOR_BANCARIO');
    end if;

    if v_param = '%' then
        v_param := 'N';
    end if;

    if v_param not in ('N','Y') then
        raise_application_error(-20303,
            'Parametro invalido. Usar % para default o Y para reproceso forzado.');
    end if;

    begin
        select esquema_objetivo,
               estado,
               fase_proceso,
               cast(fecha_inicio as date),
               cast(fecha_fin as date),
               ultimo_paso,
               ultimo_objeto,
               progreso_pct
          into v_esquema,
               v_estado_pre,
               v_fase_pre,
               v_fecha_ini_pre,
               v_fecha_fin_pre,
               v_ultimo_paso_pre,
               v_ultimo_objeto_pre,
               v_progreso_pre
          from tdm_ejecucion
         where ejecucion_id = v_ejecucion_id;
    exception
        when no_data_found then
            raise_application_error(-20304,
                'No existe la ejecucion_id ' || v_ejecucion_id || ' en TDM_EJECUCION');
    end;

    if upper(nvl(v_estado_pre,'?')) = 'ERROR' then
        v_warn_pre_error := 'Y';
    end if;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Ejecucion DM Enmascaramiento por ID');
    dbms_output.put_line('Ejecucion_id  : ' || v_ejecucion_id);
    dbms_output.put_line('Esquema       : ' || v_esquema);
    dbms_output.put_line('Identificador : ' || v_identificador);
    dbms_output.put_line('Parametro     : ' || case when v_param = 'Y' then 'Y' else '(default)' end);
    dbms_output.put_line('=========================================');

    begin
        select count(*)
          into v_en_curso
          from tdm_mask_solicitud
         where ejecucion_id = v_ejecucion_id
           and estado in ('PENDIENTE','EN_PROCESO','REPROCESANDO');
    exception
        when others then
            v_en_curso := 0;
    end;

    if v_en_curso > 0 then
        raise_application_error(-20305,
            'Ya existe una solicitud de enmascaramiento en curso para la ejecucion ' || v_ejecucion_id);
    end if;

    select count(*)
      into v_total_final
      from tdm_columna_final
     where owner_name = v_esquema;

    if v_total_final = 0 then
        raise_application_error(-20306,
            'No existen columnas en TDM_COLUMNA_FINAL para el esquema ' || v_esquema || '. Ejecute discovery primero.');
    end if;

    select count(*)
      into v_total_identificador
      from tdm_columna_final
     where owner_name = v_esquema
       and upper(identificador) = v_identificador;

    if v_total_identificador = 0 then
        raise_application_error(-20307,
            'No existen columnas con identificador ' || v_identificador || ' para el esquema ' || v_esquema);
    end if;

    dbms_output.put_line('Configurando catalogo operativo...');
    dbms_output.put_line('Total columnas catalogadas : ' || v_total_final);
    dbms_output.put_line('Columnas del identificador : ' || v_total_identificador);

    -- R7: Respaldar configuración original de enmascarar antes de aplicar filtro
    declare
      l_idx pls_integer := 0;
    begin
      for r in (select owner_name, table_name, column_name, enmascarar 
                  from tdm_columna_final 
                 where owner_name = v_esquema) loop
        l_idx := l_idx + 1;
        l_backup_final(l_idx).owner_name := r.owner_name;
        l_backup_final(l_idx).table_name := r.table_name;
        l_backup_final(l_idx).column_name := r.column_name;
        l_backup_final(l_idx).enmascarar := r.enmascarar;
      end loop;
    end;

    declare
      l_idx pls_integer := 0;
    begin
      for r in (select owner_name, table_name, column_name, enmascarar 
                  from tdm_columna_hist 
                 where ejecucion_id = v_ejecucion_id) loop
        l_idx := l_idx + 1;
        l_backup_hist(l_idx).owner_name := r.owner_name;
        l_backup_hist(l_idx).table_name := r.table_name;
        l_backup_hist(l_idx).column_name := r.column_name;
        l_backup_hist(l_idx).enmascarar := r.enmascarar;
      end loop;
    end;

    update tdm_columna_final
       set enmascarar = 'N'
     where owner_name = v_esquema;

    update tdm_columna_final
       set enmascarar = 'Y'
     where owner_name = v_esquema
       and upper(identificador) = v_identificador;

    v_total_final_y := sql%rowcount;

    update tdm_columna_hist
       set enmascarar = 'N'
     where ejecucion_id = v_ejecucion_id
       and owner_name = v_esquema
       and nvl(vigente,'Y') = 'Y';

    update tdm_columna_hist
       set enmascarar = 'Y'
     where ejecucion_id = v_ejecucion_id
       and owner_name = v_esquema
       and nvl(vigente,'Y') = 'Y'
       and upper(identificador) = v_identificador;

    v_total_hist_y := sql%rowcount;

    commit;

    dbms_output.put_line('Catalogo actualizado.');
    dbms_output.put_line('TDM_COLUMNA_FINAL Y : ' || v_total_final_y);
    dbms_output.put_line('TDM_COLUMNA_HIST  Y : ' || v_total_hist_y);

    if v_warn_pre_error = 'Y' then
        dbms_output.put_line('ADVERTENCIA: la ejecucion venia previamente en estado ERROR.');
        dbms_output.put_line('Se intentara una nueva ejecucion con los parametros indicados.');
        dbms_output.put_line('-----------------------------------------');
    end if;

    if v_param = 'Y' then
        dbms_output.put_line('Modo: FORZAR / REPROCESO');
        pkg_dm_enmascarar.p_dm_enmascara(
            p_ejecucion_id => v_ejecucion_id,
            p_reproceso    => 'Y',
            p_commit_lote  => 1000
        );
    else
        dbms_output.put_line('Modo: DEFAULT');
        pkg_dm_enmascarar.p_dm_enmascara(
            p_ejecucion_id => v_ejecucion_id,
            p_reproceso    => 'N',
            p_commit_lote  => 1000
        );
    end if;

    begin
        select nvl(max(s.solicitud_id), -1)
          into v_solicitud_id
          from tdm_mask_solicitud s
         where s.ejecucion_id = v_ejecucion_id;
    exception
        when others then
            v_solicitud_id := -1;
    end;

    begin
        select esquema_objetivo,
               estado,
               fase_proceso,
               cast(fecha_inicio as date),
               cast(fecha_fin as date),
               ultimo_paso,
               ultimo_objeto,
               progreso_pct
          into v_esquema,
               v_estado_post,
               v_fase_post,
               v_fecha_ini_post,
               v_fecha_fin_post,
               v_ultimo_paso_post,
               v_ultimo_objeto_post,
               v_progreso_post
          from tdm_ejecucion
         where ejecucion_id = v_ejecucion_id;
    exception
        when no_data_found then
            v_estado_post := null;
    end;

    if upper(nvl(v_estado_post,'?')) = 'ERROR' then
        v_warn_post_error := 'Y';
    end if;

    -- R7: Restaurar catálogo original al finalizar la ejecución
    if l_backup_final.count > 0 then
      for i in 1..l_backup_final.count loop
        update tdm_columna_final
           set enmascarar = l_backup_final(i).enmascarar
         where owner_name = l_backup_final(i).owner_name
           and table_name = l_backup_final(i).table_name
           and column_name = l_backup_final(i).column_name;
      end loop;
    end if;
    if l_backup_hist.count > 0 then
      for i in 1..l_backup_hist.count loop
        update tdm_columna_hist
           set enmascarar = l_backup_hist(i).enmascarar
         where ejecucion_id = v_ejecucion_id
           and owner_name = l_backup_hist(i).owner_name
           and table_name = l_backup_hist(i).table_name
           and column_name = l_backup_hist(i).column_name;
      end loop;
    end if;
    commit;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Resumen final');
    dbms_output.put_line('Esquema                : ' || v_esquema);
    dbms_output.put_line('Identificador          : ' || v_identificador);
    dbms_output.put_line('Solicitud_id           : ' || case when v_solicitud_id = -1 then '(no encontrada)' else to_char(v_solicitud_id) end);
    dbms_output.put_line('Columnas seleccionadas : ' || v_total_final_y);

    if v_estado_pre is not null then
        dbms_output.put_line('Estado previo          : ' || v_estado_pre);
    end if;

    if v_estado_post is not null then
        dbms_output.put_line('Estado actual          : ' || v_estado_post);
    end if;

    if v_fecha_ini_post is not null then
        dbms_output.put_line('Inicio ejecucion       : ' || to_char(v_fecha_ini_post, 'dd-mm-yyyy hh24:mi:ss'));
    end if;

    if v_fecha_fin_post is not null then
        dbms_output.put_line('Fin ejecucion          : ' || to_char(v_fecha_fin_post, 'dd-mm-yyyy hh24:mi:ss'));
    end if;

    if v_progreso_post is not null then
        dbms_output.put_line('Progreso %             : ' || v_progreso_post);
    end if;

    if v_ultimo_paso_post is not null then
        dbms_output.put_line('Ultimo paso            : ' || substr(v_ultimo_paso_post,1,200));
    end if;

    if v_ultimo_objeto_post is not null then
        dbms_output.put_line('Ultimo objeto          : ' || substr(v_ultimo_objeto_post,1,200));
    end if;

    if v_warn_post_error = 'Y' then
        dbms_output.put_line('ADVERTENCIA FINAL      : La ejecucion quedo en ERROR. Revisar trazas y errores.');
    end if;

    dbms_output.put_line('=========================================');
exception
    when others then
        -- R7: Garantizar restauración ante cualquier excepción no controlada
        if l_backup_final.count > 0 then
          for i in 1..l_backup_final.count loop
            update tdm_columna_final
               set enmascarar = l_backup_final(i).enmascarar
             where owner_name = l_backup_final(i).owner_name
               and table_name = l_backup_final(i).table_name
               and column_name = l_backup_final(i).column_name;
          end loop;
        end if;
        if l_backup_hist.count > 0 then
          for i in 1..l_backup_hist.count loop
            update tdm_columna_hist
               set enmascarar = l_backup_hist(i).enmascarar
             where ejecucion_id = v_ejecucion_id
               and owner_name = l_backup_hist(i).owner_name
               and table_name = l_backup_hist(i).table_name
               and column_name = l_backup_hist(i).column_name;
          end loop;
        end if;
        commit;
        raise;
end;
/

select &&V_ARG1 as c_ejecucion_id from dual;

select nvl(max(s.solicitud_id), -1) as c_solicitud_id
from tdm_mask_solicitud s
where s.ejecucion_id = &V_EJEC_ID;

prompt
prompt =========================================================
prompt 1. COLUMNAS SELECCIONADAS POR IDENTIFICADOR
prompt =========================================================

select table_name as c_table_name,
       column_name as c_column_name,
       identificador as c_identificador,
       enmascarar
from tdm_columna_final
where owner_name = (
        select esquema_objetivo
          from tdm_ejecucion
         where ejecucion_id = &V_EJEC_ID
      )
  and enmascarar = 'Y'
order by table_name, column_name;

prompt
prompt =========================================================
prompt 2. SOLICITUD DE MASKING
prompt =========================================================

select s.solicitud_id,
       s.ejecucion_id,
       s.estado,
       s.forzar_reproceso,
       s.filas_procesadas,
       to_char(s.fecha_inicio,'dd-mm-yyyy hh24:mi:ss') as fecha_inicio,
       case when s.fecha_fin is not null
            then to_char(s.fecha_fin,'dd-mm-yyyy hh24:mi:ss')
       end as fecha_fin
from tdm_mask_solicitud s
where s.solicitud_id = &V_SOL_ID;

prompt
prompt =========================================================
prompt 3. TRAZABILIDAD DETALLADA DE LA EJECUCION
prompt =========================================================

select *
from (
    select t.trace_id                    as c_trace_id,
           t.solicitud_id,
           t.nivel                       as c_nivel,
           t.fase                        as c_fase,
           t.paso                        as c_paso,
           substr(t.detalle,1,100)       as c_detalle,
           to_char(cast(t.fecha_evento as date),'dd-mm-yyyy hh24:mi:ss') as c_fecha
    from tdm_mask_trace t
    where t.ejecucion_id = &V_EJEC_ID
    order by t.solicitud_id desc, t.fecha_evento, t.trace_id
)
where rownum <= 200;

prompt
prompt =========================================================
prompt 4. RESUMEN DE DEPENDENCIAS PRE/POST
prompt =========================================================

select d.tipo_objeto                  as c_tipo_objeto,
       count(*)                       as c_total,
       sum(case when d.deshabilitado_ok = 'Y' then 1 else 0 end) as deshabilitado_ok,
       sum(case when d.habilitado_ok   = 'Y' then 1 else 0 end) as habilitado_ok
from tdm_mask_dep_estado d
where d.solicitud_id = &V_SOL_ID
  and &V_SOL_ID <> -1
group by d.tipo_objeto
order by d.tipo_objeto;

prompt
prompt =========================================================
prompt FIN dm_enmascara_id
prompt =========================================================

undefine 1
undefine 2
undefine 3
undefine V_ARG1
undefine V_ARG2
undefine V_ARG3
undefine V_EJEC_ID
undefine V_SOL_ID
