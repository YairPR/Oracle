set define off

Rem ================================================================================
Rem pkg_dm_dominios  --  13_dm_pkg_dominios.sql
Rem ================================================================================
Rem Propagacion de dominios de enmascarado por FK (Union-Find). Lo usan descubrimiento y enmascarado.
Rem
Rem Modularizacion 2026-10-10 (R2-R9): rutinas MOVIDAS desde pkg_dm_enmascarar sin cambiar su
Rem logica. Lo unico distinto es el prefijo de paquete en las llamadas a rutinas que viven en
Rem otro paquete. Las firmas y los textos de traza/error no cambian.
Rem ================================================================================

create or replace PACKAGE pkg_dm_dominios AS

procedure proc_dm_propaga_dominios(
    p_esquema      in varchar2,
    p_solicitud_id in number default null,
    p_ejecucion_id in number default null
);

END pkg_dm_dominios;
/

create or replace PACKAGE BODY pkg_dm_dominios AS


------------------------------------------------------------------------------
-- Resolvedor de componentes conexos por FK (Union-Find)
-- Propaga enmascarar = 'Y', identificador y dominio compartido a todo el grupo conexo.
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_propaga_dominios
-- PROPOSITO    : Agrupa columnas conectadas por claves foraneas (Union-Find) y propaga a todo el
--                grupo la marca enmascarar = Y, el identificador de mayor prioridad y un dominio
--                comun en TDM_COLUMNA_FINAL.
-- ENTRADAS     : p_esquema, p_solicitud_id (opcional, solo traza), p_ejecucion_id (opcional, solo
--                traza). Sin OUT.
-- LEE          : TDM_COLUMNA_FINAL; DBA_CONSTRAINTS; DBA_CONS_COLUMNS
-- ESCRIBE      : TDM_COLUMNA_FINAL (MERGE: enmascarar = Y, identificador, dominio); Indirecto:
--                TDM_MASK_TRACE via pkg_dm_trazabilidad.proc_dm_trace (evento RI_REINCLUYE)
-- ERRORES      : No levanta ORA-2xxxx; los fallos al trazar se ignoran
-- LLAMADO DESDE: proc_dm_sync_col_final; pkg_dm_enmascarar en 37_dm_pkg_enmascarar.sql linea 3316
------------------------------------------------------------------------------
procedure proc_dm_propaga_dominios(
    p_esquema      in varchar2,
    p_solicitud_id in number default null,
    p_ejecucion_id in number default null
) is
  type t_node is record (
    parent_node   varchar2(500),
    identificador varchar2(50),
    enmascarar    char(1)
  );
  type t_node_map is table of t_node index by varchar2(500);
  l_nodes t_node_map;

  type t_component is record (
    has_enmascarar char(1) := 'N',
    identificador  varchar2(50) := null,
    min_node       varchar2(500) := null
  );
  type t_comp_map is table of t_component index by varchar2(500);
  l_comps t_comp_map;

  l_esquema varchar2(128) := upper(trim(p_esquema));
  l_key     varchar2(500);
  l_root    varchar2(500);
  l_own     varchar2(128);
  l_tab     varchar2(128);
  l_col     varchar2(128);
  l_first_dot  number;
  l_second_dot number;

  -- Union-Find Find
  function find_root(p_node in varchar2) return varchar2 is
    l_curr varchar2(500) := p_node;
  BEGIN
    if not l_nodes.exists(l_curr) then
      l_nodes(l_curr).parent_node := l_curr;
      l_nodes(l_curr).enmascarar  := 'N';
      l_nodes(l_curr).identificador := null;
      return l_curr;
    end if;

    while l_nodes(l_curr).parent_node <> l_curr loop
      l_curr := l_nodes(l_curr).parent_node;
    end loop;
    return l_curr;
  END;

  -- Union-Find Union
  procedure union_nodes(p_node1 in varchar2, p_node2 in varchar2) is
    l_r1 varchar2(500) := find_root(p_node1);
    l_r2 varchar2(500) := find_root(p_node2);
  BEGIN
    if l_r1 <> l_r2 then
      l_nodes(l_r1).parent_node := l_r2;
    end if;
  END;

  -- Ranking de prioridad de identificadores para dominios referenciales (menor ranking = mayor especificidad/prioridad)
  function f_rank_ident(p_ident in varchar2) return number is
  begin
    return case upper(trim(p_ident))
             when 'IDENTIFICADOR_IDENTIDAD'  then 10
             when 'IDENTIFICADOR_DOCUMENTO'  then 10
             when 'IDENTIFICADOR_IBAN'       then 20
             when 'IDENTIFICADOR_BANCARIO'   then 20
             when 'IDENTIFICADOR_PERSONAL'   then 50
             else 90
           end;
  end;

begin
  -- 1) Cargar nodos iniciales desde tdm_columna_final
  for rc in (
    select ora_owner, table_name, column_name, identificador, enmascarar
      from tdm_columna_final
     where ora_owner = l_esquema
  ) loop
    l_key := rc.ora_owner||'.'||rc.table_name||'.'||rc.column_name;
    l_nodes(l_key).parent_node := l_key;
    l_nodes(l_key).identificador := rc.identificador;
    l_nodes(l_key).enmascarar := nvl(rc.enmascarar,'N');
  end loop;

  -- 2) Cargar relaciones FK y hacer UNION de nodos
  for fk in (
    select cc_c.owner  child_owner,  cc_c.table_name child_table,  cc_c.column_name child_col,
           cc_p.owner  parent_owner, cc_p.table_name parent_table, cc_p.column_name parent_col
      from dba_constraints  c
      join dba_cons_columns cc_c on cc_c.owner = c.owner    and cc_c.constraint_name   = c.constraint_name
      join dba_cons_columns cc_p on cc_p.owner = c.r_owner  and cc_p.constraint_name   = c.r_constraint_name
                                and cc_p.position = cc_c.position
     where c.constraint_type = 'R'
       and c.owner = l_esquema
  ) loop
    union_nodes(
      fk.child_owner||'.'||fk.child_table||'.'||fk.child_col,
      fk.parent_owner||'.'||fk.parent_table||'.'||fk.parent_col
    );
  end loop;

  -- 3) Agrupar y resolver propiedades del componente (has_enmascarar, identificador por ranking, nodo mínimo)
  l_key := l_nodes.first;
  while l_key is not null loop
    l_root := find_root(l_key);
    
    -- Inicializar l_comps(l_root) de forma segura para evitar ORA-01403
    if not l_comps.exists(l_root) then
      l_comps(l_root).has_enmascarar := 'N';
      l_comps(l_root).identificador  := null;
      l_comps(l_root).min_node       := null;
    end if;

    if l_nodes(l_key).enmascarar = 'Y' then
      l_comps(l_root).has_enmascarar := 'Y';
    end if;

    if l_nodes(l_key).identificador is not null then
      if l_comps(l_root).identificador is null
         or f_rank_ident(l_nodes(l_key).identificador) < f_rank_ident(l_comps(l_root).identificador) then
        l_comps(l_root).identificador := l_nodes(l_key).identificador;
      end if;
    end if;

    -- M-1: Resolver nombre de dominio lexicográficamente menor de forma estable
    if l_comps(l_root).min_node is null or l_key < l_comps(l_root).min_node then
      l_comps(l_root).min_node := l_key;
    end if;

    l_key := l_nodes.next(l_key);
  end loop;

  -- 4) Propagar resultados y persistir dominio en tdm_columna_final (forzar homogeneidad determinista)
  l_key := l_nodes.first;
  while l_key is not null loop
    l_root := find_root(l_key);
    
    if l_comps.exists(l_root) and l_comps(l_root).has_enmascarar = 'Y' then
      l_first_dot  := instr(l_key, '.');
      l_second_dot := instr(l_key, '.', 1, 2);
      l_own := substr(l_key, 1, l_first_dot - 1);
      l_tab := substr(l_key, l_first_dot + 1, l_second_dot - l_first_dot - 1);
      l_col := substr(l_key, l_second_dot + 1);

      -- A.2: Traza dinámica de re-inclusión de columnas por integridad referencial
      declare
        l_curr_enm varchar2(1) := null;
      begin
        select enmascarar into l_curr_enm
          from tdm_columna_final
         where ora_owner = l_own
           and table_name = l_tab
           and column_name = l_col;

        if l_curr_enm = 'N' then
          -- 2026-09-16: llamada ESTATICA a pkg_dm_trazabilidad. Antes era un
          -- EXECUTE IMMEDIATE a pkg_dm_enmascarar.proc_dm_trace porque 04
          -- compila antes que 05 en el orden de instalacion y una referencia
          -- estatica a un paquete que aun no existe no habria compilado.
          -- pkg_dm_trazabilidad no tiene esa restriccion (compila justo
          -- despues de las tablas, antes que 04) - ver su cabecera.
          begin
            pkg_dm_trazabilidad.proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'RI_REINCLUYE',
              l_own||'.'||l_tab||'.'||l_col||' re-incluida (Y) por integridad referencial del dominio '||l_comps(l_root).min_node
            );
          exception
            when others then null;
          end;
        end if;
      exception
        when others then null;
      end;

      merge into tdm_columna_final u
      using (
        select l_own as ora_owner,
               l_tab as table_name,
               l_col as column_name,
               l_comps(l_root).identificador as identificador,
               case when upper(trim(l_comps(l_root).identificador)) = 'IDENTIFICADOR_OBS' then null else l_comps(l_root).min_node end as dominio
          from dual
      ) h
      on (u.ora_owner = h.ora_owner and u.table_name = h.table_name and u.column_name = h.column_name)
      when matched then
        update set u.enmascarar = 'Y',
                   u.identificador = h.identificador, -- Forzar el identificador de mayor prioridad en todo el componente
                   u.dominio = h.dominio
      when not matched then
        insert (ora_owner, table_name, column_name, identificador, enmascarar, dominio)
        values (h.ora_owner, h.table_name, h.column_name, h.identificador, 'Y', h.dominio);
    end if;

    l_key := l_nodes.next(l_key);
  end loop;
end proc_dm_propaga_dominios;

END pkg_dm_dominios;
/
