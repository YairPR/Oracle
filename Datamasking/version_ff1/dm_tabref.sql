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
alter session set current_schema = ASTSYSADMIN;

Rem =============================================================================
Rem dm_tabref.sql -- referencias (FK) de una columna vs. catalogo de enmascarado
Rem =============================================================================
Rem Uso:
Rem   @dm_tabref ESQUEMA TABLA COLUMNA
Rem Ejemplo:
Rem   @dm_tabref SRI2006 SRI_CONTRIBUYENTE NUMERO_RUC
Rem
Rem POR QUE EXISTE: antes de confiar en una corrida de enmascarado frente a una
Rem auditoria, hace falta poder responder, columna por columna: "si esta
Rem columna tiene FKs hacia/desde otras tablas, ¿el motor va a producir el
Rem MISMO valor enmascarado en ambos lados?" Este script responde eso sin
Rem adivinar.
Rem
Rem DE DONDE SALE LA RESPUESTA (importante, aclara una confusion valida):
Rem TDM_DEPENDENCIA_FINAL *no* es una matriz de columna-a-columna con pares
Rem padre/hijo -- es bookkeeping a nivel de TABLA+OBJETO (constraint_name o
Rem trigger_name) que usa proc_dm_pre_dep/proc_dm_dep_policy (paquete 05) solo
Rem para decidir que DISABLE/ENABLE hacer antes y despues de enmascarar. No
Rem dice nada sobre si dos columnas van a terminar con el mismo valor.
Rem
Rem La matriz real es TDM_COLUMNA_FINAL.DOMINIO. La calcula
Rem pkg_dm_descubrimiento.proc_dm_propaga_dominios (04) con un Union-Find
Rem sobre DBA_CONSTRAINTS (constraint_type='R') DENTRO DEL ESQUEMA: agrupa en
Rem un mismo "dominio" toda columna conectada por FK (directa o
Rem transitivamente), y fuerza a TODO el grupo a compartir el mismo
Rem IDENTIFICADOR (funcion de enmascarado) y el mismo ENMASCARAR. Como el
Rem enmascarado es determinista dentro de una ejecucion (mismo identificador +
Rem mismo pepper => mismo valor de entrada produce siempre el mismo valor de
Rem salida), dos columnas en el mismo dominio quedan garantizadas a enmascarar
Rem el mismo valor de origen igual. Esa es la propiedad que este script
Rem verifica -- no la reinventa.
Rem
Rem LIMITACION CONOCIDA DEL MOTOR que este script expone a proposito:
Rem proc_dm_propaga_dominios filtra "c.owner = l_esquema" -- una FK que cruza
Rem de esquema (esta tabla referencia, o es referenciada por, una tabla de
Rem OTRO esquema) nunca entra al Union-Find de esta corrida, por lo tanto
Rem nunca comparte dominio ni identificador forzado. Si ese otro esquema
Rem tambien se enmascara pero en una corrida separada, no hay garantia
Rem automatica de consistencia entre ambos lados. Este script detecta y
Rem marca ese caso como ATENCION en vez de dejarlo pasar en silencio.
Rem
Rem QUE HACE, EN ORDEN:
Rem   1) Estado de la columna en TDM_COLUMNA_FINAL (identificador/enmascarar/dominio).
Rem   2) Si tiene dominio: lista TODAS las columnas de ese dominio (la matriz).
Rem   3) FKs reales de esta columna ahora mismo en el diccionario (como hija
Rem      hacia un padre, y como padre referenciada por hijas), SIN restringir
Rem      por esquema -- para poder detectar el caso cruzado del punto anterior.
Rem   4) Para cada relacion encontrada, compara identificador/enmascarar contra
Rem      esta columna y marca OK o DESAJUSTE.
Rem   5) Excepciones manuales (TDM_EXCEPCION_COL) activas sobre esta columna.
Rem   6) TDM_DEPENDENCIA_FINAL de la tabla (contexto PRE/POST, no es la matriz).
Rem   7) Veredicto final.
Rem
Rem Solo lee -- no hace ningun UPDATE/MERGE/COMMIT.
Rem
Rem MODIFICADO   (MM/DD/YY)
Rem epurisaca    09/21/26 - Creacion, a pedido: verificar que columnas
Rem                         padre/hija enlazadas por FK terminen con el mismo
Rem                         valor enmascarado.
Rem =============================================================================

prompt Analizando referencias.....

set termout off

column "2" new_value 2 noprint
select null as "2" from dual where 1=2;
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
    v_esquema  varchar2(128) := upper(trim('&&V_ARG1'));
    v_tabla    varchar2(128) := upper(trim('&&V_ARG2'));
    v_columna  varchar2(128) := upper(trim('&&V_ARG3'));

    v_col_dbexists   number := 0;
    v_identificador  varchar2(50);
    v_enmascarar     varchar2(1);
    v_dominio        varchar2(128);
    v_en_catalogo    boolean := false;

    v_dom_cnt        number := 0;
    v_dom_distinct_id number := 0;
    v_dom_distinct_en number := 0;

    v_rel_cnt        number := 0;
    v_cross_cnt      number := 0;
    v_mismatch_cnt   number := 0;

    v_exc_accion     varchar2(10);
    v_exc_forz       varchar2(50);
    v_exc_razon      varchar2(1000);

    procedure p_linea is begin dbms_output.put_line('-----------------------------------------------------------------------'); end;
    procedure p_doble is begin dbms_output.put_line('========================================================================='); end;

    -- Compara la columna relacionada contra la nuestra e imprime OK/DESAJUSTE.
    procedure p_evaluar_relacion(
        p_rol        in varchar2,  -- 'PADRE de' o 'HIJA de'
        p_owner      in varchar2,
        p_tabla      in varchar2,
        p_col        in varchar2,
        p_constraint in varchar2,
        p_status     in varchar2
    ) is
        l_ident varchar2(50);
        l_enm   varchar2(1);
        l_dom   varchar2(128);
        l_found boolean := false;
    begin
        v_rel_cnt := v_rel_cnt + 1;

        dbms_output.put_line('  ' || p_rol || ' : ' || p_owner || '.' || p_tabla || '.' || p_col ||
                              '  (constraint ' || p_constraint || ', estado ' || p_status || ')');

        if p_owner <> v_esquema then
            v_cross_cnt := v_cross_cnt + 1;
            dbms_output.put_line('     ATENCION: cruza de esquema (' || v_esquema || ' -> ' || p_owner ||
                                  '). proc_dm_propaga_dominios NO recorre esta FK (filtra por esquema), ' ||
                                  'por lo tanto NO hay garantia automatica de mismo identificador/valor ' ||
                                  'salvo que se verifique manualmente en ambos esquemas.');
        end if;

        begin
            select identificador, enmascarar, dominio
              into l_ident, l_enm, l_dom
              from tdm_columna_final
             where owner_name = p_owner
               and table_name = p_tabla
               and column_name = p_col;
            l_found := true;
        exception
            when no_data_found then
                l_found := false;
        end;

        if not l_found then
            dbms_output.put_line('     No esta en TDM_COLUMNA_FINAL (no descubierta / no marcada para enmascarar).');
            if v_enmascarar = 'Y' then
                v_mismatch_cnt := v_mismatch_cnt + 1;
                dbms_output.put_line('     DESAJUSTE: nuestra columna SI enmascara pero esta relacionada NO -- revisar.');
            end if;
        else
            dbms_output.put_line('     TDM_COLUMNA_FINAL: identificador=' || nvl(l_ident,'(null)') ||
                                  ' enmascarar=' || nvl(l_enm,'(null)') ||
                                  ' dominio=' || nvl(l_dom,'(null)'));

            if nvl(l_enm,'N') <> nvl(v_enmascarar,'N')
               or nvl(l_ident,'~') <> nvl(v_identificador,'~') then
                v_mismatch_cnt := v_mismatch_cnt + 1;
                dbms_output.put_line('     DESAJUSTE: identificador/enmascarar distinto al de la columna consultada.');
            elsif v_dominio is not null and nvl(l_dom,'~') <> nvl(v_dominio,'~') then
                v_mismatch_cnt := v_mismatch_cnt + 1;
                dbms_output.put_line('     DESAJUSTE: mismo identificador pero dominio distinto (revisar propagacion).');
            else
                dbms_output.put_line('     OK: mismo identificador y enmascarar -- valor enmascarado sera consistente.');
            end if;
        end if;
        dbms_output.put_line(' ');
    end;

begin
    if v_esquema is null or v_tabla is null or v_columna is null then
        raise_application_error(-20601,
            'Uso: @dm_tabref ESQUEMA TABLA COLUMNA (los 3 argumentos son obligatorios)');
    end if;

    p_doble;
    dbms_output.put_line('dm_tabref -- ' || v_esquema || '.' || v_tabla || '.' || v_columna);
    p_doble;

    -- Sanity: la columna existe de verdad en el diccionario?
    begin
        select 1 into v_col_dbexists
          from dba_tab_columns
         where owner = v_esquema and table_name = v_tabla and column_name = v_columna;
    exception
        when no_data_found then
            v_col_dbexists := 0;
    end;

    if v_col_dbexists = 0 then
        dbms_output.put_line('ADVERTENCIA: ' || v_esquema || '.' || v_tabla || '.' || v_columna ||
                              ' no existe en DBA_TAB_COLUMNS (revise esquema/tabla/columna). Se continua igual.');
        p_linea;
    end if;

    ------------------------------------------------------------------
    -- 1) Estado en TDM_COLUMNA_FINAL
    ------------------------------------------------------------------
    dbms_output.put_line('1) Catalogo (TDM_COLUMNA_FINAL)');
    p_linea;
    begin
        select identificador, enmascarar, dominio
          into v_identificador, v_enmascarar, v_dominio
          from tdm_columna_final
         where owner_name = v_esquema
           and table_name = v_tabla
           and column_name = v_columna;
        v_en_catalogo := true;
        dbms_output.put_line('  identificador : ' || nvl(v_identificador,'(null)'));
        dbms_output.put_line('  enmascarar    : ' || nvl(v_enmascarar,'(null)'));
        dbms_output.put_line('  dominio       : ' || nvl(v_dominio,'(null, sin componente FK con enmascarado activo)'));
    exception
        when no_data_found then
            v_en_catalogo := false;
            dbms_output.put_line('  No esta en TDM_COLUMNA_FINAL (no paso por descubrimiento, o no calzo ninguna regla).');
    end;
    dbms_output.put_line(' ');

    ------------------------------------------------------------------
    -- 2) Matriz de dominio (todas las columnas del mismo componente FK)
    ------------------------------------------------------------------
    dbms_output.put_line('2) Matriz de dominio (columnas conectadas por FK que comparten dominio)');
    p_linea;
    if v_dominio is null then
        dbms_output.put_line('  (sin dominio asignado -- ver punto 1; no hay grupo que listar)');
    else
        for rc in (
            select owner_name, table_name, column_name, identificador, enmascarar
              from tdm_columna_final
             where dominio = v_dominio
             order by owner_name, table_name, column_name
        ) loop
            v_dom_cnt := v_dom_cnt + 1;
            dbms_output.put_line('  ' || rpad(rc.owner_name||'.'||rc.table_name||'.'||rc.column_name, 70) ||
                                  ' identificador=' || rpad(nvl(rc.identificador,'(null)'),22) ||
                                  ' enmascarar=' || rc.enmascarar ||
                                  case when rc.owner_name = v_esquema and rc.table_name = v_tabla
                                            and rc.column_name = v_columna
                                       then '   <-- esta columna' else '' end);
        end loop;

        select count(distinct identificador), count(distinct enmascarar)
          into v_dom_distinct_id, v_dom_distinct_en
          from tdm_columna_final
         where dominio = v_dominio;

        dbms_output.put_line(' ');
        if v_dom_distinct_id <= 1 and v_dom_distinct_en <= 1 then
            dbms_output.put_line('  OK: las ' || v_dom_cnt || ' columnas del dominio comparten identificador y enmascarar ' ||
                                  '-- el motor producira el mismo valor enmascarado para el mismo dato de origen.');
        else
            v_mismatch_cnt := v_mismatch_cnt + 1;
            dbms_output.put_line('  CRITICO: el dominio tiene identificador/enmascarar NO homogeneo (' ||
                                  v_dom_distinct_id || ' identificador(es) distinto(s), ' ||
                                  v_dom_distinct_en || ' valor(es) distinto(s) de enmascarar). Esto no deberia ' ||
                                  'pasar si proc_dm_propaga_dominios corrio limpio -- revisar si el catalogo quedo ' ||
                                  'desactualizado (tabla/FK nueva desde el ultimo descubrimiento).');
        end if;
    end if;
    dbms_output.put_line(' ');

    ------------------------------------------------------------------
    -- 3-4) FKs reales de esta columna ahora mismo (sin restringir esquema)
    ------------------------------------------------------------------
    dbms_output.put_line('3) FKs vigentes en el diccionario para esta columna (hija y padre)');
    p_linea;

    -- 3a) Nuestra columna como HIJA (tiene FK hacia un padre)
    for ch in (
        select con.constraint_name fk_name, con.status, cc.position fk_position,
               con.r_owner, con.r_constraint_name
          from dba_constraints con
          join dba_cons_columns cc on cc.owner = con.owner and cc.constraint_name = con.constraint_name
         where con.owner = v_esquema
           and con.table_name = v_tabla
           and con.constraint_type = 'R'
           and cc.column_name = v_columna
    ) loop
        for par in (
            select cc2.owner parent_owner, cc2.table_name parent_table, cc2.column_name parent_col
              from dba_cons_columns cc2
             where cc2.owner = ch.r_owner
               and cc2.constraint_name = ch.r_constraint_name
               and cc2.position = ch.fk_position
        ) loop
            p_evaluar_relacion('PADRE de', par.parent_owner, par.parent_table, par.parent_col,
                                ch.fk_name, ch.status);
        end loop;
    end loop;

    -- 3b) Nuestra columna como PADRE (es PK/UK referenciada por hijas)
    for pk in (
        select con.constraint_name pk_name, cc.position pk_position
          from dba_constraints con
          join dba_cons_columns cc on cc.owner = con.owner and cc.constraint_name = con.constraint_name
         where con.owner = v_esquema
           and con.table_name = v_tabla
           and con.constraint_type in ('P','U')
           and cc.column_name = v_columna
    ) loop
        for fk in (
            select c.owner child_owner, c.table_name child_table, c.constraint_name fk_name, c.status,
                   cc.column_name child_col, cc.position
              from dba_constraints c
              join dba_cons_columns cc on cc.owner = c.owner and cc.constraint_name = c.constraint_name
             where c.constraint_type = 'R'
               and c.r_owner = v_esquema
               and c.r_constraint_name = pk.pk_name
               and cc.position = pk.pk_position
        ) loop
            p_evaluar_relacion('HIJA de', fk.child_owner, fk.child_table, fk.child_col,
                                fk.fk_name, fk.status);
        end loop;
    end loop;

    if v_rel_cnt = 0 then
        dbms_output.put_line('  No se encontraron FKs (ni como hija ni como padre) para esta columna en el diccionario.');
        dbms_output.put_line(' ');
    end if;

    ------------------------------------------------------------------
    -- 5) Excepciones manuales activas sobre esta columna
    ------------------------------------------------------------------
    dbms_output.put_line('5) Excepciones manuales (TDM_EXCEPCION_COL) sobre esta columna');
    p_linea;
    -- NOTA 2026-09-22: la PK de tdm_excepcion_col es (owner_name, table_name,
    -- column_name), pero se confirmo en produccion (SRI2006.TMP_LIQUIDACION_
    -- MENSUAL.NIF) que puede haber MAS de una fila activa para esa misma
    -- combinacion -- por eso este bloque usa un LOOP (no SELECT INTO) y
    -- reporta el conteo en vez de asumir 0 o 1. Ver hallazgo relacionado:
    -- proc_dm_get_excepcion (05) ya se protegia con ROWNUM=1 para este mismo
    -- caso; proc_dm_aplica_excepcion (04) no lo hacia -- corregido aparte.
    declare
        v_exc_cnt number := 0;
    begin
        for rc in (
            select accion, identificador_forz, razon
              from tdm_excepcion_col
             where owner_name = v_esquema
               and table_name = v_tabla
               and column_name = v_columna
               and activa = 'Y'
        ) loop
            v_exc_cnt := v_exc_cnt + 1;
            dbms_output.put_line('  [' || v_exc_cnt || '] accion=' || rc.accion ||
                                  ' identificador_forz=' || nvl(rc.identificador_forz,'(null)') ||
                                  ' razon=' || nvl(rc.razon,'(sin razon registrada)'));
        end loop;

        if v_exc_cnt = 0 then
            dbms_output.put_line('  (ninguna excepcion activa para esta columna)');
        elsif v_exc_cnt = 1 then
            dbms_output.put_line('  Nota: una excepcion FORCE/EXCLUDE puede hacer que esta columna se procese distinto ' ||
                                  'a lo que indica su dominio -- si hay relaciones FK arriba, confirme que el mismo ' ||
                                  'FORCE (o uno equivalente) tambien este activo del otro lado.');
        else
            v_mismatch_cnt := v_mismatch_cnt + 1;
            dbms_output.put_line('  CRITICO: ' || v_exc_cnt || ' filas ACTIVAS para la misma columna en ' ||
                                  'TDM_EXCEPCION_COL (deberia ser a lo sumo 1 -- revisar la PK real de la tabla en ' ||
                                  'esta base, puede estar deshabilitada/NOVALIDATE). proc_dm_get_excepcion (05, motor ' ||
                                  'de enmascarado) usa ROWNUM=1 y toma UNA de estas de forma no determinista -- ' ||
                                  'depende del plan de ejecucion, no de cual "deberia" ganar.');
        end if;
    end;
    dbms_output.put_line(' ');

    ------------------------------------------------------------------
    -- 6) TDM_DEPENDENCIA_FINAL de la tabla (contexto PRE/POST, no es la matriz)
    ------------------------------------------------------------------
    dbms_output.put_line('6) TDM_DEPENDENCIA_FINAL para ' || v_esquema || '.' || v_tabla ||
                          ' (bookkeeping DISABLE/ENABLE a nivel tabla -- NO es matriz de valores)');
    p_linea;
    declare
        v_dep_cnt number := 0;
    begin
        for rc in (
            select tipo_dependencia, dependencia_owner, dependencia_objeto,
                   categoria_uso, accion_pre_mask, accion_post_mask, detalle
              from tdm_dependencia_final
             where owner_name = v_esquema
               and table_name = v_tabla
             order by tipo_dependencia, dependencia_objeto
        ) loop
            v_dep_cnt := v_dep_cnt + 1;
            dbms_output.put_line('  ' || rpad(rc.tipo_dependencia,10) ||
                                  rpad(rc.dependencia_owner||'.'||rc.dependencia_objeto, 45) ||
                                  ' categoria=' || rpad(rc.categoria_uso,11) ||
                                  ' pre=' || rpad(rc.accion_pre_mask,18) ||
                                  ' post=' || rc.accion_post_mask);
        end loop;
        if v_dep_cnt = 0 then
            dbms_output.put_line('  (sin filas para esta tabla)');
        end if;
    end;
    dbms_output.put_line(' ');

    ------------------------------------------------------------------
    -- 7) Veredicto
    ------------------------------------------------------------------
    p_doble;
    dbms_output.put_line('Veredicto');
    p_linea;
    dbms_output.put_line('  Relaciones FK evaluadas : ' || v_rel_cnt);
    dbms_output.put_line('  Cruces de esquema       : ' || v_cross_cnt);
    dbms_output.put_line('  Desajustes detectados   : ' || v_mismatch_cnt);

    if not v_en_catalogo then
        dbms_output.put_line('  RESULTADO: SIN_CATALOGAR -- la columna no esta en TDM_COLUMNA_FINAL, no se puede ' ||
                              'afirmar nada sobre consistencia de enmascarado.');
    elsif v_mismatch_cnt > 0 then
        dbms_output.put_line('  RESULTADO: ATENCION -- hay al menos un desajuste; revisar antes de auditoria.');
    elsif v_cross_cnt > 0 then
        dbms_output.put_line('  RESULTADO: ATENCION -- consistente dentro del esquema, pero hay FK(s) cruzando ' ||
                              'esquema que el motor no cubre automaticamente. Verificar manualmente el otro lado.');
    else
        dbms_output.put_line('  RESULTADO: OK -- sin desajustes; todas las relaciones FK conocidas quedan dentro ' ||
                              'del mismo dominio, mismo identificador, mismo enmascarar.');
    end if;
    p_doble;
end;
/

undefine 1
undefine 2
undefine 3
undefine V_ARG1
undefine V_ARG2
undefine V_ARG3
