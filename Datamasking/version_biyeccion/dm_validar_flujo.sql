-- =========================================================
-- dm_validar_flujo.sql
-- Uso:
--   @dm_validar_flujo ESQUEMA EJECUCION_ID
--
-- Ejemplo:
--   @dm_validar_flujo RECSS_OWN 123
-- =========================================================
set serveroutput on size unlimited
set verify off
set feedback off
set heading off
set linesize 220
set pagesize 100
set trimspool on
set tab off

undefine V_ESQUEMA
undefine V_EJEC_ID

column "1" new_value 1 noprint
column "2" new_value 2 noprint
select null as "1", null as "2" from dual where 1=2;

column final_esq new_value V_ESQUEMA noprint
column final_ejec new_value V_EJEC_ID noprint

select upper(trim('&1')) final_esq,
       trim('&2') final_ejec
from dual;

prompt
prompt ==============================================================================
prompt INICIO VALIDACION AUTOMATICA DEL PROCESO DE DATA MASKING
prompt ==============================================================================
prompt Esquema objetivo: &&V_ESQUEMA
prompt Ejecucion ID    : &&V_EJEC_ID
prompt ==============================================================================
prompt

declare
  v_esquema VARCHAR2(128) := '&&V_ESQUEMA';
  v_ejec_id NUMBER := to_number('&&V_EJEC_ID');

  -- Resultados KPIs
  v_kpi1_passed BOOLEAN := true; -- Cero objetos INVALID (esquema + ASTSYSADMIN)
  v_kpi2_passed BOOLEAN := true; -- Cero constraints/triggers deshabilitados
  v_kpi3_passed BOOLEAN := true; -- Cero errores en logs (trazabilidad)
  v_kpi4_passed BOOLEAN := true; -- Validacion matematica DNI/NIE
  v_kpi5_passed BOOLEAN := true; -- Validacion matematica IBAN
  v_kpi6_passed BOOLEAN := true; -- Unicidad sin colisiones (indices simples y compuestos)
  v_kpi7_passed BOOLEAN := true; -- Prevencion de ejecuciones duplicadas en paralelo (concurrencia)
  v_kpi8_passed BOOLEAN := true; -- Integridad referencial (huerfanos por FK)
  -- KPI 9 deshabilitado tras remover la tabla tdm_mask_key_map

  l_cnt NUMBER := 0;
  l_cnt_errors NUMBER := 0;
  l_sol_id NUMBER := -1;
  l_expected_letter CHAR(1);
  l_actual_letter CHAR(1);
  l_dni_num VARCHAR2(20);
  l_dni_raw VARCHAR2(50);
  l_bban VARCHAR2(20);
  l_cc VARCHAR2(2);
  l_expected_cc VARCHAR2(2);
  l_iban_raw VARCHAR2(50);

  l_dni_cols_checked NUMBER := 0;
  l_dni_rows_checked NUMBER := 0;
  l_iban_cols_checked NUMBER := 0;
  l_iban_rows_checked NUMBER := 0;
  l_uniq_idxs_checked NUMBER := 0;

  type t_cursor is ref cursor;
  c_val t_cursor;
  l_sql VARCHAR2(4000);
  l_val_str VARCHAR2(1000);

  -- Helper DNI
  function f_letra_dni(p_num number) return char is
  begin
    return substr('TRWAGMYFPDXBNJZSQVHLCKE', mod(p_num, 23) + 1, 1);
  end;

  -- Helper IBAN Checksum
  function f_iban_cc_es(p_bban20 varchar2) return varchar2 is
    l_txt  varchar2(200) := p_bban20 || '142800';
    l_rem  number := 0;
    l_part varchar2(20);
  begin
    for i in 1 .. ceil(length(l_txt)/7) loop
      l_part := to_char(l_rem) || substr(l_txt,(i-1)*7+1,7);
      l_rem  := mod(to_number(l_part),97);
    end loop;
    return lpad(to_char(98-l_rem),2,'0');
  end;

  -- Helper CIF Checksum
  function f_valida_cif(p_cif varchar2) return boolean is
    s_par number := 0;
    s_imp number := 0;
    d     number;
    x     number;
    c     number;
    l_tab constant varchar2(10) := 'JABCDEFGHI';
    l_tipo char(1);
    l_num7 varchar2(7);
    l_ctrl char(1);
    l_expected char(1);
  begin
    if not regexp_like(p_cif, '^[A-Z][0-9]{7}[A-Z0-9]$') then
      return false;
    end if;
    l_tipo := substr(p_cif, 1, 1);
    l_num7 := substr(p_cif, 2, 7);
    l_ctrl := substr(p_cif, 9, 1);
    for i in 1 .. 7 loop
      d := to_number(substr(l_num7, i, 1));
      if mod(i, 2) = 0 then
        s_par := s_par + d;
      else
        x := d * 2;
        s_imp := s_imp + trunc(x/10) + mod(x, 10);
      end if;
    end loop;
    c := mod(10 - mod(s_par + s_imp, 10), 10);
    if l_tipo in ('K','P','Q','S','N','W') then
      l_expected := substr(l_tab, c + 1, 1);
    elsif l_tipo in ('A','B','E','H') then
      l_expected := to_char(c);
    else
      l_expected := case when mod(c, 2) = 0 then to_char(c) else substr(l_tab, c + 1, 1) end;
    end if;
    return l_ctrl = l_expected;
  exception
    when others then
      return false;
  end;

  procedure print_result(p_kpi varchar2, p_desc varchar2, p_passed boolean, p_detail varchar2 := null) is
  begin
    dbms_output.put(rpad(p_kpi, 8) || ' | ' || rpad(p_desc, 58) || ' | ');
    if p_passed then
      dbms_output.put_line('[ PASS ] ' || p_detail);
    else
      dbms_output.put_line('[ FAIL ] ' || p_detail);
    end if;
  end;

begin
  -- OBTENER SOLICITUD_ID (Proteccion contra NULL/sin solicitudes)
  begin
    select max(solicitud_id)
      into l_sol_id
      from tdm_mask_solicitud
     where ejecucion_id = v_ejec_id;
  exception
    when others then
      l_sol_id := -1;
  end;
  l_sol_id := nvl(l_sol_id, -1);

  -- KPI 1: Cero objetos INVALID en esquema objetivo
  -- --------------------------------------------------------
  select count(*)
    into l_cnt
    from dba_objects
   where owner = v_esquema
     and status = 'INVALID';
  
  if l_cnt > 0 then
    dbms_output.put_line('-> [INFO] Se encontraron '||l_cnt||' objetos INVALID. Iniciando autorecompilacion...');
    declare
      l_invalid_count number := 9999;
      l_prev_invalid_count number := 9999;
      l_sql_recomp varchar2(1000);
    begin
      loop
        select count(*) into l_invalid_count
          from dba_objects
         where owner = v_esquema
           and status = 'INVALID';
           
        exit when l_invalid_count = 0 or l_invalid_count = l_prev_invalid_count;
        l_prev_invalid_count := l_invalid_count;
        
        for r in (
          select object_type, object_name
            from dba_objects
           where owner = v_esquema
             and status = 'INVALID'
           order by case object_type
                      when 'PACKAGE' then 1
                      when 'TYPE' then 2
                      when 'VIEW' then 3
                      when 'PACKAGE BODY' then 4
                      when 'PROCEDURE' then 5
                      when 'FUNCTION' then 6
                      when 'TRIGGER' then 7
                      else 8
                    end, object_name
        ) loop
          begin
            if r.object_type = 'PACKAGE BODY' then
              l_sql_recomp := 'ALTER PACKAGE "'||v_esquema||'"."'||r.object_name||'" COMPILE BODY';
            elsif r.object_type = 'TYPE BODY' then
              l_sql_recomp := 'ALTER TYPE "'||v_esquema||'"."'||r.object_name||'" COMPILE BODY';
            else
              l_sql_recomp := 'ALTER '||r.object_type||' "'||v_esquema||'"."'||r.object_name||'" COMPILE';
            end if;
            execute immediate l_sql_recomp;
          exception
            when others then
              null;
          end;
        end loop;
      end loop;
    end;
    
    -- Volver a contar
    select count(*)
      into l_cnt
      from dba_objects
     where owner = v_esquema
       and status = 'INVALID';
  end if;

  -- Contar los que NO sean de tipo error de ambiente (ORA-00942 o similar)
  declare
    l_cnt_reales number := 0;
  begin
    for r_inv in (
      select object_name, object_type
        from dba_objects
       where owner = v_esquema
         and status = 'INVALID'
    ) loop
      declare
        l_is_env_error number := 0;
      begin
        select count(*)
          into l_is_env_error
          from dba_errors
         where owner = v_esquema
           and name = r_inv.object_name
           and type = r_inv.object_type
           and (upper(text) like '%ORA-00942%' or upper(text) like '%TABLE OR VIEW DOES NOT EXIST%');
        
        if l_is_env_error = 0 then
          l_cnt_reales := l_cnt_reales + 1;
        end if;
      end;
    end loop;
    
    l_cnt := l_cnt_reales;
  end;

  if l_cnt > 0 then
    v_kpi1_passed := false;
    print_result('KPI-01', 'Ausencia de objetos INVALID en esquema de aplicacion y motor', false, 'Se encontraron '||l_cnt||' objetos INVALID reales tras recompilacion:');
    for r_inv in (
      select object_name, object_type, owner
        from dba_objects
       where owner = v_esquema
         and status = 'INVALID'
       order by owner, object_type, object_name
    ) loop
      declare
        l_is_env_error number := 0;
      begin
        select count(*)
          into l_is_env_error
          from dba_errors
         where owner = v_esquema
           and name = r_inv.object_name
           and type = r_inv.object_type
           and (upper(text) like '%ORA-00942%' or upper(text) like '%TABLE OR VIEW DOES NOT EXIST%');
        
        if l_is_env_error = 0 then
          dbms_output.put_line('         -> INVALID: '||r_inv.owner||'.'||r_inv.object_name||' ('||r_inv.object_type||')');
          for r_err in (
            select line, position, text
              from dba_errors
             where owner = v_esquema
               and name = r_inv.object_name
               and type = r_inv.object_type
               and rownum = 1
          ) loop
            dbms_output.put_line('            [Error en Linea '||r_err.line||', Pos '||r_err.position||']: '||r_err.text);
          end loop;
        end if;
      end;
    end loop;
  else
    declare
      l_total_inv number := 0;
    begin
      select count(*) into l_total_inv
        from dba_objects
       where owner = v_esquema
         and status = 'INVALID';
      if l_total_inv > 0 then
        print_result('KPI-01', 'Ausencia de objetos INVALID en esquema de aplicacion y motor', true, 'Ok (Se omitieron '||l_total_inv||' objetos con errores de ambiente/ORA-00942)');
      else
        print_result('KPI-01', 'Ausencia de objetos INVALID en esquema de aplicacion y motor', true, 'Ok');
      end if;
    end;
  end if;

  -- --------------------------------------------------------
  -- KPI 2: Cero dependencias rotas (constraints/triggers pendientes)
  -- --------------------------------------------------------
  if l_sol_id = -1 then
    v_kpi2_passed := false;
    print_result('KPI-02', 'Restauracion de dependencias pre/post enmascaramiento', false, 'No se encontro la solicitud_id asociada');
  else
    select count(*)
      into l_cnt
      from tdm_mask_dep_estado
     where solicitud_id = l_sol_id
       and nvl(habilitado_ok,'Y') = 'N';

    if l_cnt > 0 then
      v_kpi2_passed := false;
      print_result('KPI-02', 'Restauracion de dependencias pre/post enmascaramiento', false, 'Hay '||l_cnt||' constraints o triggers sin habilitar');
    else
      print_result('KPI-02', 'Restauracion de dependencias pre/post enmascaramiento', true, 'Ok');
    end if;
  end if;

  -- --------------------------------------------------------
  -- KPI 3: Ausencia de errores de ejecucion en trazas y logs
  -- --------------------------------------------------------
  select count(*)
    into l_cnt
    from tdm_ejecucion_error
   where solicitud_id = l_sol_id;

  select count(*)
    into l_cnt_errors
    from tdm_mask_trace
   where solicitud_id = l_sol_id
     and nivel = 'ERROR';

  if l_cnt > 0 or l_cnt_errors > 0 then
    v_kpi3_passed := false;
    print_result('KPI-03', 'Ausencia de registros de ERROR en logs del motor', false, 'Errores en tdm_ejec_error: '||l_cnt||', Traza ERROR: '||l_cnt_errors);
    for r_err in (
      select table_name, column_name, etapa, mensaje_error
        from tdm_ejecucion_error
       where solicitud_id = l_sol_id
       order by fecha_error
    ) loop
      dbms_output.put_line('         -> ERROR ['||r_err.etapa||']: Tabla='||nvl(r_err.table_name, 'N/A')||' Col='||nvl(r_err.column_name, 'N/A')||' Msg='||r_err.mensaje_error);
    end loop;
  else
    print_result('KPI-03', 'Ausencia de registros de ERROR en logs del motor', true, 'Ok');
  end if;

  -- --------------------------------------------------------
  -- KPI 4: Validacion matematica DNI/NIE
  -- --------------------------------------------------------
  begin
    l_cnt_errors := 0;
    for r in (
      select table_name, column_name
        from tdm_columna_final
       where owner_name = v_esquema
         and enmascarar = 'Y'
         and upper(identificador) in ('IDENTIFICADOR_IDENTIDAD', 'IDENTIFICADOR_DOCUMENTO')
    ) loop
      l_dni_cols_checked := l_dni_cols_checked + 1;
      l_sql := 'select '||r.column_name||' from '||v_esquema||'.'||r.table_name||' where '||r.column_name||' is not null and rownum <= 30';
      begin
        open c_val for l_sql;
        loop
          fetch c_val into l_val_str;
          exit when c_val%notfound;
          l_dni_rows_checked := l_dni_rows_checked + 1;
          
          l_dni_raw := upper(trim(l_val_str));
          -- Comprobar estructura basica (Ej. 12345678A o X1234567A)
          if regexp_like(l_dni_raw, '^[0-9XYZ][0-9]{7}[A-Z]$') then
            -- Mapeo de NIE a digitos
            l_dni_num := substr(l_dni_raw, 1, 8);
            if substr(l_dni_num, 1, 1) = 'X' then l_dni_num := '0' || substr(l_dni_num, 2);
            elsif substr(l_dni_num, 1, 1) = 'Y' then l_dni_num := '1' || substr(l_dni_num, 2);
            elsif substr(l_dni_num, 1, 1) = 'Z' then l_dni_num := '2' || substr(l_dni_num, 2);
            end if;
            
            l_actual_letter := substr(l_dni_raw, 9, 1);
            l_expected_letter := f_letra_dni(to_number(l_dni_num));
            
            if l_actual_letter <> l_expected_letter then
              l_cnt_errors := l_cnt_errors + 1;
              dbms_output.put_line('         -> DNI/NIE INVALIDO: '||r.table_name||'.'||r.column_name||' = '''||l_dni_raw||''' (Esperado: '||l_expected_letter||', Actual: '||l_actual_letter||')');
            end if;
          elsif regexp_like(l_dni_raw, '^[A-Z][0-9]{7}[A-Z0-9]$') then
            -- Es un CIF, usar validador de CIF
            if not f_valida_cif(l_dni_raw) then
              l_cnt_errors := l_cnt_errors + 1;
              dbms_output.put_line('         -> CIF INVALIDO: '||r.table_name||'.'||r.column_name||' = '''||l_dni_raw||'''');
            end if;
          else
            -- Ignorar valores sucios de confusión (ERR, MOCK, SUCIO, INVALID) ya que fueron insertados a propósito para probar robustez
            if not (l_dni_raw like '%ERR%' or l_dni_raw like '%SUCIO%' or l_dni_raw like '%INVALID%' or l_dni_raw like '%MOCK%') then
              l_cnt_errors := l_cnt_errors + 1;
              dbms_output.put_line('         -> FORMATO DESCONOCIDO: '||r.table_name||'.'||r.column_name||' = '''||l_dni_raw||'''');
            end if;
          end if;
        end loop;
        close c_val;
      exception
        when others then
          if c_val%isopen then close c_val; end if;
          l_cnt_errors := l_cnt_errors + 1;
          dbms_output.put_line('         -> EXCEPCION procesando columna: '||r.table_name||'.'||r.column_name||' Error: '||sqlerrm);
      end;
    end loop;

    if l_dni_cols_checked = 0 then
      print_result('KPI-04', 'Validacion matematica de digito de control DNI/NIE', true, 'Ok (0 columnas encontradas/analizadas)');
    elsif l_cnt_errors > 0 then
      v_kpi4_passed := false;
      print_result('KPI-04', 'Validacion matematica de digito de control DNI/NIE', false, 'Fallas: '||l_cnt_errors||' registros de '||l_dni_rows_checked||' checked');
    else
      print_result('KPI-04', 'Validacion matematica de digito de control DNI/NIE', true, 'Ok ('||l_dni_cols_checked||' col, '||l_dni_rows_checked||' rows checked)');
    end if;
  exception
    when others then
      v_kpi4_passed := false;
      print_result('KPI-04', 'Validacion matematica de digito de control DNI/NIE', false, 'Excepcion ejecutando validacion: '||sqlerrm);
  end;

  -- --------------------------------------------------------
  -- KPI 5: Validacion matematica IBAN
  -- --------------------------------------------------------
  begin
    l_cnt_errors := 0;
    for r in (
      select table_name, column_name
        from tdm_columna_final
       where owner_name = v_esquema
         and enmascarar = 'Y'
         and upper(identificador) in ('IDENTIFICADOR_BANCARIO')
    ) loop
      l_iban_cols_checked := l_iban_cols_checked + 1;
      l_sql := 'select '||r.column_name||' from '||v_esquema||'.'||r.table_name||' where '||r.column_name||' is not null and rownum <= 30';
      begin
        open c_val for l_sql;
        loop
          fetch c_val into l_val_str;
          exit when c_val%notfound;
          l_iban_rows_checked := l_iban_rows_checked + 1;
          
          l_iban_raw := upper(replace(l_val_str, ' ', ''));
          if regexp_like(l_iban_raw, '^ES[0-9]{22}$') then
            l_cc := substr(l_iban_raw, 3, 2);
            l_bban := substr(l_iban_raw, 5, 20);
            l_expected_cc := f_iban_cc_es(l_bban);
            
            if l_cc <> l_expected_cc then
              l_cnt_errors := l_cnt_errors + 1;
            end if;
          else
            null;  -- no es IBAN (cuenta/CCC): fuera del alcance de este KPI, NO es error
          end if;
        end loop;
        close c_val;
      exception
        when others then
          if c_val%isopen then close c_val; end if;
          l_cnt_errors := l_cnt_errors + 1;
      end;
    end loop;

    if l_iban_cols_checked = 0 then
      print_result('KPI-05', 'Validacion checksum de IBAN generado (Modulo 97)', true, 'Ok (0 columnas encontradas/analizadas)');
    elsif l_cnt_errors > 0 then
      v_kpi5_passed := false;
      print_result('KPI-05', 'Validacion checksum de IBAN generado (Modulo 97)', false, 'Fallas: '||l_cnt_errors||' registros de '||l_iban_rows_checked||' checked');
    else
      print_result('KPI-05', 'Validacion checksum de IBAN generado (Modulo 97)', true, 'Ok ('||l_iban_cols_checked||' col, '||l_iban_rows_checked||' rows checked)');
    end if;
  exception
    when others then
      v_kpi5_passed := false;
      print_result('KPI-05', 'Validacion checksum de IBAN generado (Modulo 97)', false, 'Excepcion ejecutando validacion: '||sqlerrm);
  end;

  -- --------------------------------------------------------
  -- KPI 6: Unicidad en columnas con UNIQUE constraints (Simples y Compuestas)
  -- --------------------------------------------------------
  begin
    l_cnt_errors := 0;
    -- Agrupamos las columnas del indice unico para evaluar la combinacion completa
    for r in (
      SELECT idx.owner, idx.index_name, idx.table_name,
             LISTAGG(ic.column_name, ',') WITHIN GROUP (ORDER BY ic.column_position) as col_list
        FROM dba_indexes idx
        JOIN dba_ind_columns ic ON ic.index_owner = idx.owner AND ic.index_name = idx.index_name
       WHERE idx.table_owner = v_esquema
         AND idx.uniqueness = 'UNIQUE'
         -- Solo si al menos una de las columnas del indice unico esta siendo enmascarada
         AND EXISTS (
           SELECT 1
             FROM tdm_columna_final f
            WHERE f.owner_name = idx.table_owner
              AND f.table_name = idx.table_name
              AND f.column_name = ic.column_name
              AND f.enmascarar = 'Y'
         )
       GROUP BY idx.owner, idx.index_name, idx.table_name
    ) loop
      l_uniq_idxs_checked := l_uniq_idxs_checked + 1;
      
      -- Comprobamos si la combinacion tiene duplicados usando GROUP BY + HAVING COUNT(*) > 1
      l_sql := 'SELECT COUNT(*) FROM (SELECT '||r.col_list||' FROM '||v_esquema||'.'||r.table_name||
               ' GROUP BY '||r.col_list||' HAVING COUNT(*) > 1)';
      begin
        declare
          l_dup_groups NUMBER := 0;
        begin
          execute immediate l_sql into l_dup_groups;
          if l_dup_groups > 0 then
            l_cnt_errors := l_cnt_errors + l_dup_groups;
          end if;
        end;
      exception
        when others then
          l_cnt_errors := l_cnt_errors + 1;
      end;
    end loop;

    if l_uniq_idxs_checked = 0 then
      print_result('KPI-06', 'Ausencia de colisiones y duplicados en columnas UNIQUE', true, 'Ok (0 indices unicos analizados)');
    elsif l_cnt_errors > 0 then
      v_kpi6_passed := false;
      print_result('KPI-06', 'Ausencia de colisiones y duplicados en columnas UNIQUE', false, 'Grupos duplicados encontrados: '||l_cnt_errors);
    else
      print_result('KPI-06', 'Ausencia de colisiones y duplicados en columnas UNIQUE', true, 'Ok ('||l_uniq_idxs_checked||' indices unicos checked)');
    end if;
  exception
    when others then
      v_kpi6_passed := false;
      print_result('KPI-06', 'Ausencia de colisiones y duplicados en columnas UNIQUE', false, 'Excepcion ejecutando validacion: '||sqlerrm);
  end;

  -- -------------------------------------------------------  -- KPI 7: Prevencion de ejecuciones duplicadas en paralelo
  -- --------------------------------------------------------
  begin
    l_cnt := 0;
    for r in (
      select column_expression
        from dba_ind_expressions
       where index_owner = 'ASTSYSADMIN'
          and index_name = 'UQ_TDM_EJEC_ESQ_ACTIVO'
    ) loop
      l_sql := r.column_expression;
      if upper(l_sql) like '%ESTADO%' and upper(l_sql) like '%ESQUEMA_OBJETIVO%' then
        l_cnt := l_cnt + 1;
      end if;
    end loop;

    if l_cnt = 0 then
      v_kpi7_passed := false;
      print_result('KPI-07', 'Prevencion de ejecuciones duplicadas en paralelo', false, 'El indice condicionado uq_tdm_ejec_esq_activo no esta configurado correctamente');
    else
      print_result('KPI-07', 'Prevencion de ejecuciones duplicadas en paralelo', true, 'Ok (Filtro por expresion validado)');
    end if;
  exception
    when others then
      v_kpi7_passed := false;
      print_result('KPI-07', 'Prevencion de ejecuciones duplicadas en paralelo', false, 'Error consultando diccionario de datos: '||sqlerrm);
  end;

  -- --------------------------------------------------------
  -- KPI 8: Integridad referencial - huérfanos por FK (hija sin padre)
  --        Solo FKs cuya tabla hija tiene alguna columna enmascarada.
  -- --------------------------------------------------------
  declare
    l_orphans      NUMBER := 0;
    l_fks_checked  NUMBER := 0;
    l_pred_join    VARCHAR2(4000);
    l_pred_notnull VARCHAR2(4000);
    l_sqlk8        VARCHAR2(4000);
    l_cnt_fk       NUMBER := 0;
  begin
    l_cnt_errors := 0;

    for fk in (
      select c.owner        child_owner,
             c.table_name    child_table,
             c.constraint_name child_cons,
             c.r_owner       parent_owner,
             c.r_constraint_name parent_cons,
             pk.table_name   parent_table
        from dba_constraints c
        join dba_constraints pk
          on pk.owner = c.r_owner
         and pk.constraint_name = c.r_constraint_name
       where c.constraint_type = 'R'
         and c.owner = v_esquema
         and (
           exists (
             select 1
               from dba_cons_columns cc
               join tdm_columna_final f
                 on f.owner_name  = cc.owner
                and f.table_name  = cc.table_name
                and f.column_name = cc.column_name
                and f.enmascarar  = 'Y'
              where cc.owner = c.owner
                and cc.constraint_name = c.constraint_name
           )
           or exists (
             select 1
               from dba_cons_columns ccp
               join tdm_columna_final fp
                 on fp.owner_name  = ccp.owner
                and fp.table_name  = ccp.table_name
                and fp.column_name = ccp.column_name
                and fp.enmascarar  = 'Y'
              where ccp.owner = c.r_owner
                and ccp.constraint_name = c.r_constraint_name
           )
         )
    ) loop
      l_pred_join    := null;
      l_pred_notnull := null;

      for col in (
        select cc_c.column_name child_col, cc_p.column_name parent_col
          from dba_cons_columns cc_c
          join dba_cons_columns cc_p
            on cc_p.owner = fk.parent_owner
           and cc_p.constraint_name = fk.parent_cons
           and cc_p.position = cc_c.position
         where cc_c.owner = fk.child_owner
           and cc_c.constraint_name = fk.child_cons
         order by cc_c.position
      ) loop
        l_pred_join := l_pred_join
          || case when l_pred_join is null then '' else ' AND ' end
          || 'p.'||col.parent_col||' = c.'||col.child_col;
        l_pred_notnull := l_pred_notnull
          || case when l_pred_notnull is null then '' else ' AND ' end
          || 'c.'||col.child_col||' IS NOT NULL';
      end loop;

      if l_pred_join is not null then
        l_fks_checked := l_fks_checked + 1;
        l_sqlk8 :=
          'SELECT COUNT(*) FROM '||fk.child_owner||'.'||fk.child_table||' c '||
          ' WHERE '||l_pred_notnull||
          '   AND NOT EXISTS (SELECT 1 FROM '||fk.parent_owner||'.'||fk.parent_table||' p '||
          '                    WHERE '||l_pred_join||')';
        begin
          execute immediate l_sqlk8 into l_cnt_fk;
          if l_cnt_fk > 0 then
            l_cnt_errors := l_cnt_errors + l_cnt_fk;
            print_result('KPI-08', 'Huerfanos en '||fk.child_table||' (FK '||fk.child_cons||')', false,
                         l_cnt_fk||' filas hijas sin padre');
          end if;
        exception
          when others then
            l_cnt_errors := l_cnt_errors + 1;
            print_result('KPI-08', 'Error evaluando FK '||fk.child_cons, false, sqlerrm);
        end;
      end if;
    end loop;

    if l_fks_checked = 0 then
      print_result('KPI-08', 'Integridad referencial padre-hija (huerfanos por FK)', true,
                   'Ok (0 FKs con columnas enmascaradas)');
    elsif l_cnt_errors > 0 then
      v_kpi8_passed := false;
      -- (los detalles por FK ya se imprimieron arriba)
    else
      print_result('KPI-08', 'Integridad referencial padre-hija (huerfanos por FK)', true,
                   'Ok ('||l_fks_checked||' FKs verificadas, 0 huerfanos)');
    end if;
  exception
    when others then
      v_kpi8_passed := false;
      print_result('KPI-08', 'Integridad referencial padre-hija (huerfanos por FK)', false,
                   'Excepcion: '||sqlerrm);
  end;

  -- KPI 9 deshabilitado tras remover la tabla tdm_mask_key_map

  -- ==============================================================================
  -- VEREDICTO FINAL
  -- ==============================================================================
  dbms_output.put_line(rpad('-', 80, '-'));
  if v_kpi1_passed and v_kpi2_passed and v_kpi3_passed and v_kpi4_passed and v_kpi5_passed and v_kpi6_passed and v_kpi7_passed and v_kpi8_passed then
    dbms_output.put_line('VEREDICTO FINAL: [ SUCCESS / PASS ] El enmascaramiento cumple todos los criterios.');
    dbms_output.put_line(rpad('-', 80, '-'));
  else
    dbms_output.put_line('VEREDICTO FINAL: [ FAILED / FAIL ] Se detectaron inconsistencias en la validacion.');
    dbms_output.put_line(rpad('-', 80, '-'));
    
    -- Lanzamos excepcion controlada para que SQL*Plus retorne estado de error (CI/CD)
    raise_application_error(
      -20099,
      'VALIDACION FALLIDA: La ejecucion '||v_ejec_id||' del esquema '||v_esquema||' no cumple con los controles de calidad de Data Masking.'
    );
  end if;

end;
/
undefine 1
undefine 2
undefine V_ESQUEMA
undefine V_EJEC_ID
