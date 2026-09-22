undefine P1
undefine P2

set serveroutput on size unlimited
set verify off
set feedback off
set define on
set termout on
alter session set current_schema = ASTSYSADMIN;

prompt Descubrimiento en ejecucion.....

set termout off

column "2" new_value 2 noprint
select null as "2" from dual where 1=2;

column final_p1 new_value P1 noprint
column final_p2 new_value P2 noprint

select upper(trim('&1')) final_p1,
       upper(trim(nvl('&2', '%'))) final_p2
from dual;

set termout on

declare
    v_esquema             varchar2(128) := upper(trim('&&P1'));
    v_param               varchar2(50)  := upper(trim('&&P2'));

    v_num                 number;

    v_ejec_en_curso_id    number;
    v_last_ejec_id_after  number;

    v_estado              varchar2(30);
    v_fecha_inicio        date;
    v_fecha_fin           date;
    v_ultimo_paso         varchar2(4000);
    v_ultimo_objeto       varchar2(4000);
    v_progreso            number;

    v_total_columnas      number := 0;
    v_total_enmascarar_y  number := 0;

    v_total_excepciones   number := 0;
    v_total_excl          number := 0;
    v_total_force         number := 0;
    v_excl_mostradas      number := 0;

    function es_numero(p_txt varchar2) return number is
        v_dummy number;
    begin
        v_dummy := to_number(p_txt);
        return 1;
    exception
        when others then
            return 0;
    end;
begin
    if v_esquema is null or v_esquema = '' then
        raise_application_error(
            -20001,
            'Uso: @dm_descubre ESQUEMA % | @dm_descubre ESQUEMA Y | @dm_descubre ESQUEMA 200'
        );
    end if;

    -- % significa modo default
    if v_param = '%' then
        v_param := null;
    end if;

    if v_param is not null
       and v_param <> ''
       and v_param <> 'Y'
       and es_numero(v_param) = 0 then
        raise_application_error(
            -20011,
            'Parametro invalido: usar %, Y o numero entre 10 y 500'
        );
    end if;

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Ejecucion DM Descubrimiento');
    dbms_output.put_line('Esquema   : ' || v_esquema);
    dbms_output.put_line('Parametro : ' || case when v_param is null or v_param = '' then '(default)' else v_param end);
    dbms_output.put_line('=========================================');

    begin
        select max(ejecucion_id)
          into v_ejec_en_curso_id
          from tdm_ejecucion
         where esquema_objetivo = v_esquema
           and estado = 'EJECUTANDO';
    exception
        when others then
            v_ejec_en_curso_id := null;
    end;

    if v_ejec_en_curso_id is not null then
        dbms_output.put_line('Ya existe una ejecucion en curso para el mismo esquema.');
        dbms_output.put_line('Ejecucion_id : ' || v_ejec_en_curso_id);
        dbms_output.put_line('No se lanzara una nueva ejecucion.');
        dbms_output.put_line('=========================================');
        return;
    end if;

    if v_param is null or v_param = '' then
        dbms_output.put_line('Modo: DEFAULT');
        pkg_dm_descubrimiento.p_dm_descubrimiento(v_esquema);

    elsif v_param = 'Y' then
        dbms_output.put_line('Modo: FORZAR FULL');
        pkg_dm_descubrimiento.p_dm_descubrimiento(v_esquema, 'Y');

    else
        v_num := to_number(v_param);

        if v_num < 10 or v_num > 500 then
            raise_application_error(-20010, 'Sample debe estar entre 10 y 500');
        end if;

        dbms_output.put_line('Modo: SAMPLE_ROWS = ' || v_num);
        pkg_dm_descubrimiento.p_dm_descubrimiento(v_esquema, v_num);
    end if;

    begin
        select max(ejecucion_id)
          into v_last_ejec_id_after
          from tdm_ejecucion
         where esquema_objetivo = v_esquema;
    exception
        when others then
            v_last_ejec_id_after := null;
    end;

    if v_last_ejec_id_after is null then
        raise_application_error(-20030, 'No se pudo identificar la ejecucion generada en tdm_ejecucion');
    end if;

    begin
        select estado,
               fecha_inicio,
               fecha_fin,
               ultimo_paso,
               ultimo_objeto,
               progreso_pct
          into v_estado,
               v_fecha_inicio,
               v_fecha_fin,
               v_ultimo_paso,
               v_ultimo_objeto,
               v_progreso
          from tdm_ejecucion
         where ejecucion_id = v_last_ejec_id_after;
    exception
        when no_data_found then
            null;
    end;

    begin
        select count(*),
               sum(case when nvl(enmascarar,'N') = 'Y' then 1 else 0 end)
          into v_total_columnas,
               v_total_enmascarar_y
          from tdm_columna_hist
         where ejecucion_id = v_last_ejec_id_after;
    exception
        when no_data_found then
            v_total_columnas     := 0;
            v_total_enmascarar_y := 0;
        when others then
            v_total_columnas     := 0;
            v_total_enmascarar_y := 0;
    end;

    v_total_enmascarar_y := nvl(v_total_enmascarar_y, 0);

    dbms_output.put_line('=========================================');
    dbms_output.put_line('Resumen de la ejecucion');
    dbms_output.put_line('Ejecucion_id           : ' || v_last_ejec_id_after);

    if v_estado is not null then
        dbms_output.put_line('Estado                 : ' || v_estado);
    end if;

    if v_fecha_inicio is not null then
        dbms_output.put_line('Fecha inicio           : ' || to_char(v_fecha_inicio, 'dd-mm-yyyy hh24:mi:ss'));
    end if;

    if v_fecha_fin is not null then
        dbms_output.put_line('Fecha fin              : ' || to_char(v_fecha_fin, 'dd-mm-yyyy hh24:mi:ss'));
    end if;

    if v_progreso is not null then
        dbms_output.put_line('Progreso %             : ' || v_progreso);
    end if;

    if v_ultimo_paso is not null then
        dbms_output.put_line('Ultimo paso            : ' || substr(v_ultimo_paso, 1, 200));
    end if;

    if v_ultimo_objeto is not null then
        dbms_output.put_line('Ultimo objeto          : ' || substr(v_ultimo_objeto, 1, 200));
    end if;

    dbms_output.put_line('Columnas descubiertas  : ' || v_total_columnas);
    dbms_output.put_line('Con enmascarar = Y     : ' || v_total_enmascarar_y);

    -- FIX 2026-09-20: excepciones vigentes del esquema (TDM_EXCEPCION_COL).
    -- El descubrimiento clasifica Y/N por heuristica propia, pero
    -- proc_dm_apl_col SIEMPRE respeta primero una excepcion activa
    -- (FORCE/EXCLUDE) sobre esa clasificacion al momento de enmascarar. Sin
    -- este bloque el operador no tenia forma de ver, en la misma salida del
    -- descubrimiento, si el esquema tiene excepciones vigentes que van a
    -- pisar el resultado Y/N de arriba.
    begin
        select count(*),
               sum(case when accion = 'EXCLUDE' then 1 else 0 end),
               sum(case when accion = 'FORCE'   then 1 else 0 end)
          into v_total_excepciones,
               v_total_excl,
               v_total_force
          from tdm_excepcion_col
         where owner_name = v_esquema
           and activa = 'Y';
    exception
        when others then
            v_total_excepciones := 0;
            v_total_excl        := 0;
            v_total_force       := 0;
    end;

    v_total_excepciones := nvl(v_total_excepciones, 0);
    v_total_excl         := nvl(v_total_excl, 0);
    v_total_force         := nvl(v_total_force, 0);

    dbms_output.put_line('-----------------------------------------');
    dbms_output.put_line('Excepciones activas (TDM_EXCEPCION_COL): ' || v_total_excepciones);

    if v_total_excepciones > 0 then
        dbms_output.put_line('  EXCLUDE (fuerza N, nunca enmascara)  : ' || v_total_excl);
        dbms_output.put_line('  FORCE   (fuerza Y, siempre enmascara): ' || v_total_force);
        dbms_output.put_line('  Detalle (maximo 50 filas):');

        for r in (
            select table_name, column_name, accion, identificador_forz
              from tdm_excepcion_col
             where owner_name = v_esquema
               and activa = 'Y'
             order by table_name, column_name
        )
        loop
            exit when v_excl_mostradas >= 50;
            dbms_output.put_line('    ' || r.table_name || '.' || r.column_name ||
                                  ' [' || r.accion || ']' ||
                                  case when r.identificador_forz is not null
                                       then ' -> ' || r.identificador_forz
                                       else ''
                                  end);
            v_excl_mostradas := v_excl_mostradas + 1;
        end loop;

        if v_total_excepciones > 50 then
            dbms_output.put_line('    ... (' || (v_total_excepciones - 50) || ' adicionales no mostradas, ver TDM_EXCEPCION_COL)');
        end if;
    else
        dbms_output.put_line('  No hay excepciones activas para ' || v_esquema || '.');
    end if;

    dbms_output.put_line('=========================================');
end;
/

undefine 1
undefine 2
undefine P1
undefine P2