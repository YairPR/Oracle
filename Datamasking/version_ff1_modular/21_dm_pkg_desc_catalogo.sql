set define off

Rem ================================================================================
Rem pkg_dm_desc_catalogo  --  21_dm_pkg_desc_catalogo.sql
Rem ================================================================================
Rem Publicar el resultado del descubrimiento en el catalogo final y en las dependencias.
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    10/10/26 - Rutinas movidas desde pkg_dm_enmascarar sin cambiar su logica
Rem ================================================================================

create or replace PACKAGE pkg_dm_desc_catalogo AS

procedure proc_dm_recolecta_dep(
    p_ejecucion_id in number,
    p_owner        in varchar2,
    p_tabla        in varchar2,
    p_columna      in varchar2
);

procedure proc_dm_aplica_excepcion(
    p_ejecucion_id  in number,
    p_owner         in varchar2,
    p_tabla         in varchar2,
    p_columna       in varchar2,
    p_identificador in out nocopy varchar2,
    p_score_total   in out nocopy number,
    p_forzar_mask   in out nocopy char
);

procedure proc_dm_sync_col_final(
    p_ejecucion_id in number
);

procedure proc_dm_sync_dep_final(
    p_ejecucion_id in number
);

END pkg_dm_desc_catalogo;
/

create or replace PACKAGE BODY pkg_dm_desc_catalogo AS


------------------------------------------------------------------------------
-- Recolecta dependencias
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_recolecta_dep
-- PROPOSITO    : Registra en TDM_DEPENDENCIA_HIST las constraints (P/R/U/C) de la columna
--                enmascarable y los triggers de su tabla.
-- ENTRADAS     : p_ejecucion_id, p_owner, p_tabla, p_columna. Sin OUT.
-- LEE          : DBA_CONS_COLUMNS; DBA_CONSTRAINTS; DBA_TRIGGERS
-- ESCRIBE      : TDM_DEPENDENCIA_HIST (INSERT)
-- ERRORES      : No levanta ORA-2xxxx; cualquier error se registra con etapa DEPENDENCIAS y se
--                continua
-- LLAMADO DESDE: proc_dm_procesa_desc (solo para columnas con enmascarar = Y)
------------------------------------------------------------------------------
procedure proc_dm_recolecta_dep(
    p_ejecucion_id in number,
    p_owner        in varchar2,
    p_tabla        in varchar2,
    p_columna      in varchar2
) is
begin
  insert into tdm_dependencia_hist(
    dependencia_id, ejecucion_id, ora_owner, table_name, column_name,
    tipo_dependencia, dependencia_owner, dependencia_objeto, detalle
  )
  select seq_dm_dependencia_hist.nextval, p_ejecucion_id, p_owner, p_tabla, p_columna,
         case when c.constraint_type = 'R' then 'FK' else 'CONSTRAINT' end,
         c.owner,
         c.constraint_name,
         'Constraint/FK sobre columna'
    from dba_cons_columns cc
    join dba_constraints c
      on c.owner = cc.owner
     and c.constraint_name = cc.constraint_name
   where cc.owner = p_owner
     and cc.table_name = p_tabla
     and cc.column_name = p_columna
     and c.constraint_type in ('P','R','U','C');

  insert into tdm_dependencia_hist(
    dependencia_id, ejecucion_id, ora_owner, table_name, column_name,
    tipo_dependencia, dependencia_owner, dependencia_objeto, detalle
  )
  select seq_dm_dependencia_hist.nextval, p_ejecucion_id, p_owner, p_tabla, p_columna,
         'TRIGGER', t.owner, t.trigger_name,
         'Trigger asociado a la tabla'
    from dba_triggers t
   where t.table_owner = p_owner
     and t.table_name = p_tabla;

exception
  when others then
    pkg_dm_trazabilidad.proc_dm_log_error(p_ejecucion_id, p_owner, p_tabla, p_columna, 'DEPENDENCIAS', sqlcode, sqlerrm);
end proc_dm_recolecta_dep;


------------------------------------------------------------------------------
-- Excepción manual
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_aplica_excepcion
-- PROPOSITO    : Aplica la excepcion manual vigente (EXCLUDE o FORCE) de TDM_EXCEPCION_COL a una
--                columna modificando identificador, score y marca.
-- ENTRADAS     : p_ejecucion_id, p_owner, p_tabla, p_columna; IN OUT p_identificador, p_score_total,
--                p_forzar_mask. EXCLUDE: score -999 y mask N. FORCE: identificador forzado, score
--                minimo 95 y mask Y.
-- LEE          : TDM_EXCEPCION_COL
-- ESCRIBE      : Indirecto: TDM_EJECUCION_ERROR / TDM_MASK_TRACE via proc_dm_log_error
-- ERRORES      : No levanta ORA-2xxxx; too_many_rows y otros errores se registran con etapa
--                APLICA_EXCEPCION y la columna sigue sin modificar; Sin excepcion activa: no hace
--                nada
-- LLAMADO DESDE: proc_dm_procesa_desc (2 llamadas: lineas 2379 y 2420)
------------------------------------------------------------------------------
procedure proc_dm_aplica_excepcion(
    p_ejecucion_id  in number,
    p_owner         in varchar2,
    p_tabla         in varchar2,
    p_columna       in varchar2,
    p_identificador in out nocopy varchar2,
    p_score_total   in out nocopy number,
    p_forzar_mask   in out nocopy char
) is
  l_accion        tdm_excepcion_col.accion%type;
  l_ident_forzado tdm_excepcion_col.identificador_forz%type;
begin
  -- ROWNUM=1 y WHEN OTHERS defensivo: TDM_EXCEPCION_COL puede traer mas de una fila activa para la
  -- misma columna (PK deshabilitada o datos duplicados) y ORA-01422 dejaria la columna sin clasificar.
  -- La causa (filas duplicadas) debe limpiarse en los datos.
  select accion, identificador_forz
    into l_accion, l_ident_forzado
    from tdm_excepcion_col
   where ora_owner = p_owner
     and table_name = p_tabla
     and column_name = p_columna
     and activa = 'Y'
     and rownum = 1;

  if l_accion = 'EXCLUDE' then
    p_score_total := -999;
    p_forzar_mask := 'N';
  elsif l_accion = 'FORCE' then
    p_identificador := nvl(l_ident_forzado, p_identificador);
    p_score_total := greatest(p_score_total, 95);
    p_forzar_mask := 'Y';
  end if;
exception
  when no_data_found then
    null;
  when too_many_rows then
    -- Con rownum=1 no deberia ocurrir; si reaparece se registra en vez de perderse.
    pkg_dm_trazabilidad.proc_dm_log_error(p_ejecucion_id, p_owner, p_tabla, p_columna, 'APLICA_EXCEPCION', sqlcode, sqlerrm);
  when others then
    -- Se registra el error (autonomo, no aborta el descubrimiento) y la columna continua sin
    -- excepcion aplicada.
    pkg_dm_trazabilidad.proc_dm_log_error(p_ejecucion_id, p_owner, p_tabla, p_columna, 'APLICA_EXCEPCION', sqlcode, sqlerrm);
end proc_dm_aplica_excepcion;


------------------------------------------------------------------------------
-- Sync catálogo final
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_sync_col_final
-- PROPOSITO    : Sincroniza TDM_COLUMNA_FINAL con lo descubierto en TDM_COLUMNA_HIST de la ejecucion,
--                retira columnas obsoletas y propaga dominios por FK.
-- ENTRADAS     : p_ejecucion_id. Sin OUT.
-- LEE          : TDM_COLUMNA_HIST; TDM_EJECUCION; TDM_OBJETO_CTRL; DBA_TAB_COLUMNS; TDM_COLUMNA_FINAL
-- ESCRIBE      : TDM_COLUMNA_FINAL (MERGE, DELETE e inserciones/updates via
--                proc_dm_propaga_dominios); Indirecto: TDM_MASK_TRACE (FINAL_OBSOLETAS,
--                FINAL_OBSOLETAS_ERR, PROPAGA_DOMINIOS_ERR)
-- ERRORES      : Errores del bloque de obsoletas y de la propagacion se trazan y se ignoran; el MERGE
--                y el DELETE iniciales no tienen handler y propagan el error
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
procedure proc_dm_sync_col_final(
    p_ejecucion_id in number
) is
begin
  merge into tdm_columna_final u
  using (
    select ora_owner, table_name, column_name, identificador, enmascarar
      from tdm_columna_hist
     where ejecucion_id = p_ejecucion_id
       and enmascarar = 'Y'
  ) h
     on (u.ora_owner = h.ora_owner and u.table_name = h.table_name and u.column_name = h.column_name)
  when matched then
    update set u.identificador = h.identificador,
               u.enmascarar    = h.enmascarar
  when not matched then
    insert (ora_owner, table_name, column_name, identificador, enmascarar)
    values (h.ora_owner, h.table_name, h.column_name, h.identificador, h.enmascarar);

  delete from tdm_columna_final u
   where exists (
         select 1
           from tdm_columna_hist h
          where h.ejecucion_id = p_ejecucion_id
            and h.ora_owner = u.ora_owner
            and h.table_name = u.table_name
            and h.column_name = u.column_name
            and nvl(h.enmascarar,'N') <> 'Y'
   );

  -- Se retira de TDM_COLUMNA_FINAL toda columna que:
  --   a) pertenece a una tabla analizada en esta ejecucion (PROCESADO con ultimo_run_id = esta
  --      ejecucion) y no quedo en Y en el HIST de esta ejecucion, o
  --   b) ya no existe en el diccionario (columna o tabla borrada).
  -- Asi una fila Y antigua no sobrevive cuando la regla o el dato cambian. Va antes de
  -- proc_dm_propaga_dominios, que re-incluye despues (RI_REINCLUYE) las columnas hijas.
  declare
    l_esq_sync varchar2(128);
    l_borradas number;
  begin
    select upper(ora_esquema) into l_esq_sync
      from tdm_ejecucion
     where ejecucion_id = p_ejecucion_id;

    delete from tdm_columna_final u
     where u.ora_owner = l_esq_sync
       and (
             (exists (select 1 from tdm_objeto_ctrl o
                       where o.ora_owner    = u.ora_owner
                         and o.table_name    = u.table_name
                         and o.estado_objeto = 'PROCESADO'
                         and o.ultimo_run_id = p_ejecucion_id)
              and not exists (select 1 from tdm_columna_hist h
                               where h.ejecucion_id = p_ejecucion_id
                                 and h.ora_owner   = u.ora_owner
                                 and h.table_name   = u.table_name
                                 and h.column_name  = u.column_name
                                 and h.enmascarar   = 'Y'))
          or not exists (select 1 from dba_tab_columns d
                          where d.owner       = u.ora_owner
                            and d.table_name  = u.table_name
                            and d.column_name = u.column_name)
           );
    l_borradas := sql%rowcount;
    if l_borradas > 0 then
      pkg_dm_trazabilidad.proc_dm_trace(
        NULL, p_ejecucion_id, 'DESCUBRIMIENTO', 'FINAL_OBSOLETAS',
        'Retiradas de TDM_COLUMNA_FINAL '||l_borradas||' columnas que ya no cumplen el descubrimiento de esta ejecucion o ya no existen en el diccionario'
      );
    end if;
  exception
    when others then
      begin
        pkg_dm_trazabilidad.proc_dm_trace(
          NULL, p_ejecucion_id, 'DESCUBRIMIENTO', 'FINAL_OBSOLETAS_ERR', substr(sqlerrm,1,500)
        );
      exception when others then null;
      end;
  end;

  -- Resolver componentes conexos por FK y propagar dominios lógicos
  declare
    l_esquema varchar2(128);
  begin
    select ora_esquema into l_esquema
      from tdm_ejecucion
     where ejecucion_id = p_ejecucion_id;
    pkg_dm_dominios.proc_dm_propaga_dominios(l_esquema);
  exception
    when others then
      -- No silenciar el fallo de propagacion en la sincronizacion del catalogo.
      begin
        pkg_dm_trazabilidad.proc_dm_trace(
          NULL, p_ejecucion_id, 'DESCUBRIMIENTO', 'PROPAGA_DOMINIOS_ERR',
          'Fallo propagando dominios FK para '||l_esquema||': '||sqlerrm
        );
      exception
        when others then null;
      end;
  end;
end proc_dm_sync_col_final;


------------------------------------------------------------------------------
-- Sync dependencias final
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_sync_dep_final
-- PROPOSITO    : Consolida TDM_DEPENDENCIA_HIST de la ejecucion en TDM_DEPENDENCIA_FINAL con la
--                categoria de uso y las acciones pre y post enmascarado (DISABLE/ENABLE segun estado
--                actual).
-- ENTRADAS     : p_ejecucion_id. Sin OUT.
-- LEE          : TDM_DEPENDENCIA_HIST; DBA_CONSTRAINTS; DBA_TRIGGERS
-- ESCRIBE      : TDM_DEPENDENCIA_FINAL (MERGE + purga de dependencias cuyo objeto ya no existe)
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
procedure proc_dm_sync_dep_final(
    p_ejecucion_id in number
) is
begin
  merge into tdm_dependencia_final u
  using (
    with dep_base as (
      select ora_owner,
             table_name,
             column_name,
             tipo_dependencia,
             nvl(dependencia_owner,'-') dependencia_owner,
             nvl(dependencia_objeto,'-') dependencia_objeto,
             max(detalle) detalle
        from tdm_dependencia_hist
       where ejecucion_id = p_ejecucion_id
         and tipo_dependencia in ('FK','CONSTRAINT','TRIGGER')
       group by ora_owner, table_name, column_name, tipo_dependencia,
                nvl(dependencia_owner,'-'), nvl(dependencia_objeto,'-')
    )
    select b.ora_owner,
           b.table_name,
           b.column_name,
           b.tipo_dependencia,
           b.dependencia_owner,
           b.dependencia_objeto,
           case
             when upper(trim(b.tipo_dependencia)) in ('FK','CONSTRAINT','R','FOREIGN KEY')
               then 'INTEGRIDAD'
             when upper(trim(b.tipo_dependencia)) in ('PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE')
               then 'INTEGRIDAD'
             else 'OPERATIVA'
           end categoria_uso,
           case
             when upper(trim(b.tipo_dependencia)) in ('FK','CONSTRAINT','R','FOREIGN KEY')
               then case when nvl(c.status,'ENABLED') = 'ENABLED' then 'DISABLE' else 'SIN_ACCION' end
             when upper(trim(b.tipo_dependencia)) = 'TRIGGER'
               then case when nvl(t.status,'ENABLED') = 'ENABLED' then 'DISABLE' else 'SIN_ACCION' end
             when upper(trim(b.tipo_dependencia)) in ('PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE')
               then 'SOLO_INFORMATIVO'
             else 'SOLO_INFORMATIVO'
           end accion_pre_mask,
           case
             when upper(trim(b.tipo_dependencia)) in ('FK','CONSTRAINT','R','FOREIGN KEY')
               then case when nvl(c.status,'ENABLED') = 'ENABLED' then 'ENABLE_NOVALIDATE' else 'SIN_ACCION' end
             when upper(trim(b.tipo_dependencia)) = 'TRIGGER'
               then case when nvl(t.status,'ENABLED') = 'ENABLED' then 'ENABLE' else 'SIN_ACCION' end
             when upper(trim(b.tipo_dependencia)) in ('PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE')
               then 'REVISAR'
             else 'SIN_ACCION'
           end accion_post_mask,
           b.detalle
      from dep_base b
      left join dba_constraints c
        on upper(trim(b.tipo_dependencia)) in ('FK','CONSTRAINT','R','FOREIGN KEY')
       and c.owner = b.dependencia_owner
       and c.constraint_name = b.dependencia_objeto
      left join dba_triggers t
        on upper(trim(b.tipo_dependencia)) = 'TRIGGER'
       and t.owner = b.dependencia_owner
       and t.trigger_name = b.dependencia_objeto
  ) d
     on (u.ora_owner = d.ora_owner
         and u.table_name = d.table_name
         and u.column_name = d.column_name
         and u.tipo_dependencia = d.tipo_dependencia
         and nvl(u.dependencia_owner,'-') = d.dependencia_owner
         and nvl(u.dependencia_objeto,'-') = d.dependencia_objeto)
  when matched then
    update set u.categoria_uso    = d.categoria_uso,
               u.accion_pre_mask  = d.accion_pre_mask,
               u.accion_post_mask = d.accion_post_mask,
               u.detalle          = d.detalle
  when not matched then
    insert (
      ora_owner, table_name, column_name, tipo_dependencia,
      dependencia_owner, dependencia_objeto,
      categoria_uso, accion_pre_mask, accion_post_mask, detalle
    )
    values (
      d.ora_owner, d.table_name, d.column_name, d.tipo_dependencia,
      d.dependencia_owner, d.dependencia_objeto,
      d.categoria_uso, d.accion_pre_mask, d.accion_post_mask, d.detalle
    );

  -- Purga de dependencias huerfanas: el MERGE solo inserta/actualiza, asi que si el esquema se
  -- recrea (DDL nuevo, constraints SYS_Cxxxx con otro nombre) o se elimina un constraint/trigger,
  -- las filas antiguas quedarian en el catalogo y el PRE/POST avisaria "no existe" en cada
  -- enmascarado. Solo se borran las que apuntan a un objeto que YA NO existe en el diccionario,
  -- y solo de los propietarios tratados en esta ejecucion, por lo que es seguro tambien en
  -- descubrimientos parciales (no depende de que la ejecucion haya visto todas las tablas).
  delete from tdm_dependencia_final u
   where u.tipo_dependencia in ('FK','CONSTRAINT','TRIGGER')
     and u.ora_owner in (select h.ora_owner
                           from tdm_dependencia_hist h
                          where h.ejecucion_id = p_ejecucion_id)
     and u.dependencia_objeto is not null
     and ( (u.tipo_dependencia in ('FK','CONSTRAINT')
            and not exists (select 1 from dba_constraints c
                             where c.owner = u.dependencia_owner
                               and c.constraint_name = u.dependencia_objeto))
        or (u.tipo_dependencia = 'TRIGGER'
            and not exists (select 1 from dba_triggers t
                             where t.owner = u.dependencia_owner
                               and t.trigger_name = u.dependencia_objeto)) );
end proc_dm_sync_dep_final;

END pkg_dm_desc_catalogo;
/
