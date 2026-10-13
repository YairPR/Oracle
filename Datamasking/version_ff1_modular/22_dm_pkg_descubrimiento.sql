Rem pkg_dm_descubrimiento.sql
Rem
Rem    NOMBRE
Rem      pkg_dm_descubrimiento.sql - Motor de descubrimiento de datos sensibles
Rem
Rem    DESCRIPCIÓN
Rem      Identifica y clasifica datos sensibles en esquemas Oracle mediante un modelo de
Rem      puntuación (scoring) que combina:
Rem        - Reglas por nombre de columna, contexto de tabla y comentarios (tdm_regla)
Rem        - Validación de patrones sobre una muestra de datos (incluye dígito de control DNI/NIE)
Rem        - Análisis semántico de nombres humanos
Rem        - Excepciones manuales FORCE / EXCLUDE (tdm_excepcion_col)
Rem
Rem      Guarda el detalle por columna en tdm_columna_hist y publica el resultado en
Rem      tdm_columna_final / tdm_dependencia_final, que consume pkg_dm_enmascarar.
Rem
Rem    NOTAS
Rem      - Oracle 11g en adelante. SQL dinámico con muestreo.
Rem      - Alcance completo del esquema o por set de tablas (tdm_ejecucion_scope).
Rem      - Reanudable: tras una caída continúa con las tablas pendientes.
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    07/15/25 - Versión inicial del motor de descubrimiento
Rem                           Basado en reglas simples por nombre de columna
Rem    epurisaca    08/10/25 - Se añade scoring por TABLE_NAME y COLUMN_COMMENT
Rem                           Introducción de modelo de puntuación ponderado
Rem    epurisaca    09/02/25 - Implementación de DATA_PATTERN con regexp_like
Rem                           Introducción de muestreo de datos (rownum)
Rem    epurisaca    09/18/25 - Integración de validación real de DNI/NIE
Rem                           Mejora en detección de identificadores personales
Rem    epurisaca    10/05/25 - Creación de tdm_regla como motor dinámico
Rem                           Permite modificar reglas sin cambiar código
Rem    epurisaca    10/22/25 - Introducción de prioridades y umbrales de confianza
Rem                           Mejora en normalización de scoring
Rem    epurisaca    11/12/25 - Se añade validación semántica de nombres humanos
Rem                           Reducción de falsos positivos en texto genérico
Rem    epurisaca    12/03/25 - Introducción de contexto de tabla (PERSONA, TITULAR)
Rem                           Mejora en clasificación contextual
Rem    epurisaca    12/20/25 - Exclusión de columnas técnicas (ID, COD, FLAG, etc.)
Rem                           Mejora en limpieza de resultados
Rem    epurisaca    01/08/26 - Creación de tdm_excepcion_col
Rem                           Soporte para reglas manuales FORCE / EXCLUDE
Rem    epurisaca    01/25/26 - Alineación con enmascaramiento determinista
Rem                           Consistencia entre tablas relacionadas
Rem    epurisaca    02/05/26 - Optimización de rendimiento en muestreo
Rem                           Mejora en ejecución sobre grandes volúmenes
Rem    epurisaca    02/18/26 - Penalización por falta de contexto de persona
Rem                           Reducción de falsos positivos en direcciones y bancos
Rem    epurisaca    02/26/26 - Introducción de ratio semántico de nombres
Rem                           Validación de contenido tipo nombre humano
Rem    epurisaca    03/05/26 - Integración con flujo de enmascaramiento
Rem    epurisaca    03/10/26 - Ajustes en reglas de COLUMN_NAME
Rem                           Mejora en detección de nomenclaturas legacy
Rem    epurisaca    03/14/26 - Rediseño versión 7 del motor
Rem                           Refactorización del flujo de scoring
Rem    epurisaca    03/18/26 - Refinamiento de IDENTIFICADOR_PERSONAL: NOM deja de ser indicador
Rem                           fuerte (falsos positivos con NOMINA), reglas negativas y ajuste de la
Rem                           compuerta de func_dm_score_patron
Rem    epurisaca    03/21/26 - Control de ejecución maestra: una nueva ejecución con FORZAR_FULL = 'N'
Rem                           se bloquea si ya existe una base del esquema; se requiere 'Y'
Rem    epurisaca    03/25/26 - Versión estable v7
Rem    epurisaca    04/20/26 - Sync de tdm_dependencia_final alineado con PRE/POST: conserva el estado
Rem                           real ENABLED/DISABLED; los objetos Oracle Text DR$ quedan en revisión
Rem    epurisaca    09/18/26 - Descubrimiento selectivo (proc_dm_descubrimiento_set y
Rem                           proc_dm_descubrimiento_core) sobre un subconjunto de tablas
Rem    epurisaca    09/22/26 - ROWNUM=1 en proc_dm_aplica_excepcion ante excepciones duplicadas
Rem    epurisaca    09/26/26 - Ranking determinista en proc_dm_procesa_desc (score inicial 0, ORDER BY
Rem                           identificador y desempate por evidencia de datos); func_dm_score_patron
Rem                           registra sus errores en lugar de devolver 0 en silencio; se elimina el
Rem                           filtro por nombre de tabla (TMP, LOG, ...): toda tabla con filas se evalúa;
Rem                           el dato manda sobre el nombre (p_contra_out cuando el dato no cumple el
Rem                           formato; DNI/NIE con dígito válido se detecta aunque el nombre sea neutro)
Rem    epurisaca    09/27/26 - proc_dm_refresca_sesion, func_dm_sesion_viva y
Rem                           proc_dm_autocancel_huerfanas pasan a pkg_dm_trazabilidad; ORA-22835 con
Rem                           contenido mayor de 4000 caracteres; un único generador de error_id
Rem                           (MAX+1) y proc_dm_log_error sin propagar errores
Rem    epurisaca    09/28/26 - progreso_pct con una sola base (columnas) en todo el procedimiento
Rem    epurisaca    10/03/26 - Se revierte el heurístico de contenido "nombre de persona" (daba falsos
Rem                           positivos en direcciones); el esquema se valida antes de crear la
Rem                           ejecución (ORA-20016); el regexp_like de contenido es insensible a
Rem                           mayúsculas
Rem    epurisaca    10/07/26 - Un FORCE sobre una columna sin evidencia ya entra en el catálogo
Rem    epurisaca    10/09/26 - func_dm_score_patron evalúa el CLOB directo (ORA-06502 con texto largo);
Rem                           una columna con evidencia pero total <= 0 queda como DESCARTADO /
Rem                           SCORE_TOTAL_NO_POSITIVO; proc_dm_sync_col_final retira de FINAL las
Rem                           columnas Y obsoletas
Rem    epurisaca    10/10/26 - proc_dm_evalua_columna separa la evaluación de cada columna; la lista de
Rem                           columnas NUMBER admitidas pasa a tdm_regla (NUMBER_ADMITIDO)
Rem    epurisaca    10/11/26 - Una tabla con columnas sin evaluar queda en ERROR y se reintenta
Rem                           (no se retira su catálogo FINAL); se omiten columnas virtuales; la
Rem                           cancelación se atiende por columna; la sesión se registra tras confirmar
Rem                           la ejecución y en proc_dm_reanudar en el mismo reclamo
Rem    epurisaca    10/12/26 - Una columna con EXCLUDE queda como DESCARTADO con motivo
Rem                           EXCLUDE_TDM_EXCEPCION_COL y traza DESCUBRIMIENTO/EXCEPCION_EXCLUDE
Rem
/*
g_version constant varchar2(30) := 'v12.0.20260928';procedure version is
begin
  dbms_output.put_line('pkg_dm_descubrimiento - versión: ' || g_version);
end;
*/
-----------------------------------------------------------------------------------------
-- (13) PAQUETE DESCUBRIMIENTO
-- Rediseño de las reglas de descubrimiento
-- v12.0.2
----------------------------------------------------------------------------------------
create or replace package pkg_dm_descubrimiento as
  procedure proc_dm_descubrimiento(
      p_esquema          in varchar2,
      p_sample_rows      in number default 500,
      p_forzar_full      in char default 'N'
  );

  procedure proc_dm_descubrimiento(
      p_esquema          in varchar2,
      p_forzar_full      in char
  );

  -- Descubrimiento por excepciones: mapea metadata, triggers e integridad solo de las tablas indicadas
  -- (p.ej. las de un FORCE previo), con el mismo mecanismo de alcance (tdm_ejecucion_scope).
  procedure proc_dm_descubrimiento_set(
      p_esquema          in varchar2,
      p_tablas_csv       in varchar2,
      p_sample_rows      in number default 500,
      p_forzar_full      in char default 'N'
  );

  procedure proc_dm_reanudar(
      p_ejecucion_id     in number,
      p_sample_rows      in number default 500,
      p_commit_lote      in number default 100
  );

  procedure proc_dm_cancelar(
      p_ejecucion_id in number
  );

  procedure proc_dm_propaga_dominios(
      p_esquema      in varchar2,
      p_solicitud_id in number default null,
      p_ejecucion_id in number default null
  );

end pkg_dm_descubrimiento;
/

--------------------------------------------------------------------------------
-- 14) PACKAGE BODY
--------------------------------------------------------------------------------
create or replace package body pkg_dm_descubrimiento as

------------------------------------------------------------------------------
-- Tipo privado: columna candidata que recibe proc_dm_evalua_columna.
-- PL/SQL exige declarar los tipos ANTES de la primera subrutina del cuerpo.
------------------------------------------------------------------------------
type t_dm_col_rec is record (
  owner          varchar2(128),
  table_name     varchar2(128),
  column_name    varchar2(128),
  data_type      varchar2(106),
  data_length    number,
  data_precision number,
  data_scale     number
);



------------------------------------------------------------------------------
-- La captura de sesion, la verificacion de sesion viva y la autocancelacion de huerfanas
-- viven en pkg_dm_trazabilidad (infraestructura compartida por ambas fases).
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Evalúa conflictos EJECUTANDO por esquema/tabla
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_conflicto_running
-- PROPOSITO    : Determina si existe una ejecucion EJECUTANDO que choque con el esquema (y
--                opcionalmente las tablas) a descubrir.
-- ENTRADAS     : p_esquema, p_tablas_csv (lista de tablas o null = esquema completo). Retorna 1 si
--                hay conflicto, 0 si no.
-- LEE          : TDM_EJECUCION; TDM_EJECUCION_SCOPE
-- ESCRIBE      : Indirecto: pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(5,'N') puede cancelar
--                ejecuciones huerfanas en TDM_EJECUCION
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_descubrimiento_core (siempre con p_tablas_csv = null)
------------------------------------------------------------------------------
function func_dm_conflicto_running(
    p_esquema    in varchar2,
    p_tablas_csv in varchar2
) return number is
  l_conflicto number := 0;
begin
  pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(5, 'N');

  for r in (
    select e.ejecucion_id
      from tdm_ejecucion e
     where e.ora_esquema = upper(p_esquema)
       and e.estado = 'EJECUTANDO'
  ) loop
    if p_tablas_csv is null then
      l_conflicto := 1;
    else
      select case
               when not exists (select 1 from tdm_ejecucion_scope s where s.ejecucion_id = r.ejecucion_id) then 1
               when exists (select 1 from tdm_ejecucion_scope s where s.ejecucion_id = r.ejecucion_id and s.table_name = '*') then 1
               when exists (
                    select 1
                      from tdm_ejecucion_scope s
                     where s.ejecucion_id = r.ejecucion_id
                       and s.ora_owner = upper(p_esquema)
                       and s.table_name in (
                             select upper(trim(regexp_substr(p_tablas_csv, '[^,]+', 1, level)))
                               from dual
                             connect by regexp_substr(p_tablas_csv, '[^,]+', 1, level) is not null
                           )
               ) then 1
               else 0
             end
        into l_conflicto
        from dual;
    end if;

    if l_conflicto = 1 then
      return 1;
    end if;
  end loop;

  return 0;
end func_dm_conflicto_running;

------------------------------------------------------------------------------
-- Registra scope de ejecución
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_registra_scope
-- PROPOSITO    : Registra en TDM_EJECUCION_SCOPE el alcance de la ejecucion: '*' para esquema
--                completo o una fila por tabla de la lista CSV.
-- ENTRADAS     : p_ejecucion_id, p_esquema, p_tablas_csv (null = esquema completo). Sin OUT.
-- LEE          : ninguno
-- ESCRIBE      : TDM_EJECUCION_SCOPE (INSERT); Indirecto: TDM_EJECUCION via
--                proc_dm_autocancel_huerfanas(15,'N')
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_descubrimiento_core
------------------------------------------------------------------------------
procedure proc_dm_registra_scope(
    p_ejecucion_id in number,
    p_esquema      in varchar2,
    p_tablas_csv   in varchar2
) is
begin
  pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(15, 'N');

  if p_tablas_csv is null then
    insert into tdm_ejecucion_scope(scope_id, ejecucion_id, ora_owner, table_name, column_name)
    values (seq_dm_ejecucion_scope.nextval, p_ejecucion_id, upper(p_esquema), '*', null);
  else
    for t in (
      select distinct upper(trim(regexp_substr(p_tablas_csv, '[^,]+', 1, level))) table_name
        from dual
      connect by regexp_substr(p_tablas_csv, '[^,]+', 1, level) is not null
    ) loop
      insert into tdm_ejecucion_scope(scope_id, ejecucion_id, ora_owner, table_name, column_name)
      values (seq_dm_ejecucion_scope.nextval, p_ejecucion_id, upper(p_esquema), t.table_name, null);
    end loop;
  end if;
end proc_dm_registra_scope;

------------------------------------------------------------------------------
-- Prepara objetos
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_prepara_objetos
-- PROPOSITO    : Sincroniza TDM_OBJETO_CTRL con las tablas actuales del esquema dentro del alcance,
--                marca PENDIENTE las nuevas o modificadas y fija los totales de la ejecucion.
-- ENTRADAS     : p_esquema, p_ejecucion_id, p_forzar_full ('Y' = todo a PENDIENTE). Sin OUT.
-- LEE          : DBA_OBJECTS; DBA_TABLES; DBA_TAB_COLUMNS; TDM_EJECUCION_SCOPE; TDM_OBJETO_CTRL
-- ESCRIBE      : TDM_OBJETO_CTRL (UPDATE/INSERT); TDM_EJECUCION (tablas_total, columnas_total,
--                ultimo_paso)
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_descubrimiento_core
------------------------------------------------------------------------------
procedure proc_dm_prepara_objetos(
    p_esquema      in varchar2,
    p_ejecucion_id in number,
    p_forzar_full  in char
) is
begin
  for t in (
    select o.owner, o.object_name table_name, o.object_id, o.last_ddl_time,
           (select count(*) from dba_tab_columns c where c.owner = o.owner and c.table_name = o.object_name) column_count
      from dba_objects o
      join dba_tables tb
        on tb.owner = o.owner
       and tb.table_name = o.object_name
     where o.owner = upper(p_esquema)
       and o.object_type = 'TABLE'
       and tb.temporary = 'N'
       and (
         not exists (
           select 1
             from tdm_ejecucion_scope sc
            where sc.ejecucion_id = p_ejecucion_id
              and sc.ora_owner = upper(p_esquema)
         )
         or exists (
           select 1
             from tdm_ejecucion_scope sc
            where sc.ejecucion_id = p_ejecucion_id
              and sc.ora_owner = upper(p_esquema)
              and sc.table_name in ('*', o.object_name)
         )
       )
  ) loop
    update tdm_objeto_ctrl dc
       set dc.object_id = t.object_id,
           dc.last_ddl_time = t.last_ddl_time,
           dc.column_count = t.column_count,
           dc.firma_txt = t.owner || '|' || t.table_name || '|' || t.last_ddl_time || '|' || t.column_count,
           dc.estado_objeto = case
                                when dc.motivo_estado = 'TABLA_TECNICA_SISTEMA' then 'PENDIENTE' -- reactiva tablas omitidas por nombre en versiones anteriores
                                when p_forzar_full = 'Y' then 'PENDIENTE'
                                when dc.estado_objeto = 'ERROR' then 'PENDIENTE'   -- tabla con columnas no evaluadas: se reintenta
                                when dc.last_ddl_time != t.last_ddl_time or nvl(dc.column_count,-1) != nvl(t.column_count,-1) then 'PENDIENTE'
                                else dc.estado_objeto
                              end,
           dc.motivo_estado = null
     where dc.ora_owner = t.owner
       and dc.table_name = t.table_name;

    if sql%rowcount = 0 then
      insert into tdm_objeto_ctrl(
        ora_owner, table_name, object_id, last_ddl_time, column_count,
        firma_txt, ultimo_run_id, estado_objeto, motivo_estado
      ) values (
        t.owner, t.table_name, t.object_id, t.last_ddl_time, t.column_count,
        t.owner || '|' || t.table_name || '|' || t.last_ddl_time || '|' || t.column_count,
        null,
        'PENDIENTE',
        null
      );
    end if;
  end loop;

  update tdm_ejecucion e
     set tablas_total = (
           select count(*)
             from tdm_objeto_ctrl dc
            where dc.ora_owner = upper(p_esquema)
              and dc.estado_objeto = 'PENDIENTE'
              and (
                not exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.ora_owner = upper(p_esquema))
                or exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.ora_owner = upper(p_esquema) and sc.table_name in ('*', dc.table_name))
              )
         ),
         columnas_total = (
           select nvl(sum(dc.column_count),0)
             from tdm_objeto_ctrl dc
            where dc.ora_owner = upper(p_esquema)
              and dc.estado_objeto = 'PENDIENTE'
              and (
                not exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.ora_owner = upper(p_esquema))
                or exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.ora_owner = upper(p_esquema) and sc.table_name in ('*', dc.table_name))
              )
         ),
         ultimo_paso = 'OBJETOS_PREPARADOS'
   where e.ejecucion_id = p_ejecucion_id;

  commit;
end proc_dm_prepara_objetos;

------------------------------------------------------------------------------
-- PROCESO CENTRAL
-- Sin evidencia minima la columna no se inserta en el historico; con evidencia, el
-- identificador nunca queda NULL.
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_evalua_columna
-- PROPOSITO    : Evaluar UNA columna candidata del descubrimiento: puntuar contra cada identificador
--                activo, elegir el mejor, aplicar excepciones FORCE/EXCLUDE y los ajustes de
--                contexto, clasificar y guardar la fila en TDM_COLUMNA_HIST (y dependencias si Y).
-- ENTRADAS     : p_ejecucion_id, p_sample_rows, p_commit_lote, c (columna de DBA_TAB_COLUMNS),
--                p_ctx_persona_tab / p_ctx_apellidos_tab (contexto de la tabla).
-- SALIDA       : p_cols_lote, p_tab_cols, p_tab_y (IN OUT): contadores del run y de la tabla.
-- ERRORES      : un error en la columna se registra como PROCESA_COLUMNA y NO se propaga
--                (el descubrimiento sigue con la columna siguiente).
-- LLAMADO DESDE: proc_dm_procesa_desc (una vez por columna).
------------------------------------------------------------------------------
procedure proc_dm_evalua_columna(
    p_ejecucion_id      in number,
    p_sample_rows       in number,
    p_commit_lote       in number,
    c                   in t_dm_col_rec,
    p_ctx_persona_tab   in number,
    p_ctx_apellidos_tab in number,
    p_cols_lote         in out number,
    p_tab_cols          in out number,
    p_tab_y             in out number
) is
  l_ctx_persona_tab   number := p_ctx_persona_tab;
  l_ctx_apellidos_tab number := p_ctx_apellidos_tab;
  l_comment           varchar2(4000);
  l_best_id           varchar2(50);
  l_best_score        number;
  l_best_patron       number; -- desempate por evidencia de datos
  l_alt_id            varchar2(50);  -- mejor candidato con evidencia aunque su total sea <= 0
  l_alt_total         number;
  l_sin_pos           boolean;
  l_score_nombre      number;
  l_score_coment      number;
  l_score_patron      number;
  l_score_tabla       number;
  l_score_total       number;
  l_rows              number;
  l_matches           number;
  l_ratio             number;
  l_null_ratio        number;
  l_rows_total        number;
  l_sem_rows          number;
  l_sem_matches       number;
  l_ratio_semantica   number;
  l_nombre_gen_ok     boolean;
  l_motivo_descarte   varchar2(2000);
  l_excl              boolean;
  l_estado_final      varchar2(20);
  l_enmascarar        char(1);
  l_force_mask        char(1);
  l_ctx_persona       number;
  l_tiene_evidencia   number := 0;
  l_contra            number := 0; -- 1 = el dato contradice el formato exigido
  l_fx_id             varchar2(50);  -- FORCE sobre columna sin evidencia
  l_fx_score          number;
  l_fx_mask           char(1);
begin
        l_best_id         := null;
        l_alt_id          := null;
        l_alt_total       := null;
        l_sin_pos         := false;
        -- Se parte de 0 (no de -99999): sin evidencia real ningun identificador debe quedar como ganador.
        l_best_score      := 0;
        l_best_patron     := 0;
        l_comment         := pkg_dm_desc_puntuacion.func_dm_get_col_comment(c.owner, c.table_name, c.column_name);
        l_tiene_evidencia := 0;
        l_rows_total      := 0;
        l_matches         := 0;
        l_ratio           := 0;

        for idn in (
          select distinct identificador
            from tdm_regla
           where activa = 'Y'
           order by identificador -- orden estable y reproducible
        ) loop
          l_score_nombre := pkg_dm_desc_puntuacion.func_dm_score_texto(idn.identificador, 'COLUMN_NAME', c.column_name);
          l_score_coment := pkg_dm_desc_puntuacion.func_dm_score_texto(idn.identificador, 'COLUMN_COMMENT', l_comment);
          l_score_tabla  := pkg_dm_desc_puntuacion.func_dm_score_texto(idn.identificador, 'TABLE_NAME', c.table_name);

          if regexp_like(c.column_name, '^(ID|COD|CODIGO|TIPO|FLAG|ESTADO|IND|SEQ|ORDEN|VERSION|HASH|TOKEN|UUID)[A-Z0-9_]+$', 'i')
             and idn.identificador not in ('IDENTIFICADOR_IDENTIDAD','IDENTIFICADOR_BANCARIO') then
            l_score_patron := 0;
            l_rows := 0;
            l_matches := 0;
            l_ratio := 0;
          elsif (l_score_nombre + l_score_coment + l_score_tabla) >= -30 then
            l_score_patron := pkg_dm_desc_puntuacion.func_dm_score_patron(
                                p_ejecucion_id,
                                c.owner,
                                c.table_name,
                                c.column_name,
                                idn.identificador,
                                p_sample_rows,
                                l_rows,
                                l_matches,
                                l_ratio,
                                l_contra
                              );
          else
            l_score_patron := 0;
            l_rows := 0;
            l_matches := 0;
            l_ratio := 0;
          end if;

          l_score_total := l_score_nombre + l_score_coment + l_score_tabla + l_score_patron;

          if pkg_dm_desc_puntuacion.func_dm_tiene_evid_min(
               idn.identificador,
               l_score_nombre,
               l_score_coment,
               l_score_tabla,
               l_score_patron
             ) = 1 then
            l_tiene_evidencia := 1;
            -- Candidato alternativo: el de mayor total entre los que tienen evidencia positiva, aunque sea <= 0.
            if l_alt_total is null or l_score_total > l_alt_total then
              l_alt_id    := idn.identificador;
              l_alt_total := l_score_total;
            end if;
          end if;

          -- Empate en score_total: gana quien tenga mas evidencia de patron de datos en la muestra.
          if l_score_total > l_best_score
             or (l_score_total > 0 and l_score_total = l_best_score and l_score_patron > l_best_patron) then
            l_best_score  := l_score_total;
            l_best_patron := l_score_patron;
            l_best_id     := idn.identificador;
          end if;
        end loop;

        if l_tiene_evidencia = 0 then
          l_best_id := pkg_dm_desc_puntuacion.func_dm_identificador_base(c.column_name, c.table_name, l_comment);
          if l_best_id is not null then
            l_tiene_evidencia := 1;
          end if;
        end if;

        if l_tiene_evidencia = 0 or l_best_id is null then
          -- Un FORCE sobre una columna sin evidencia (nombre neutro, ninguna regla puntua) debe entrar
          -- en el catalogo con su identificador forzado y recolectar sus dependencias. Sin FORCE, igual que antes.
          l_fx_id := null; l_fx_score := 0; l_fx_mask := 'N';
          pkg_dm_desc_catalogo.proc_dm_aplica_excepcion(p_ejecucion_id, c.owner, c.table_name, c.column_name,
                                   l_fx_id, l_fx_score, l_fx_mask);
          if l_fx_mask = 'Y' and l_fx_id is not null then
            l_best_id         := l_fx_id;
            l_tiene_evidencia := 1;
          elsif l_alt_id is not null then
            -- Evidencia positiva con total <= 0: se registra como DESCARTADO / SCORE_TOTAL_NO_POSITIVO para
            -- poder auditar que se evaluo. No cambia que se enmascare.
            l_best_id := l_alt_id;
            l_sin_pos := true;
          else
            return;
          end if;
        end if;

        l_score_nombre := pkg_dm_desc_puntuacion.func_dm_score_texto(l_best_id, 'COLUMN_NAME', c.column_name);
        l_score_coment := pkg_dm_desc_puntuacion.func_dm_score_texto(l_best_id, 'COLUMN_COMMENT', l_comment);
        l_score_tabla  := pkg_dm_desc_puntuacion.func_dm_score_texto(l_best_id, 'TABLE_NAME', c.table_name);
        l_score_patron := pkg_dm_desc_puntuacion.func_dm_score_patron(
                            p_ejecucion_id,
                            c.owner,
                            c.table_name,
                            c.column_name,
                            l_best_id,
                            p_sample_rows,
                            l_rows,
                            l_matches,
                            l_ratio,
                                l_contra
                          );

        l_score_total    := l_score_nombre + l_score_coment + l_score_tabla + l_score_patron;
        l_force_mask     := 'N';
        l_motivo_descarte := null;
        l_sem_rows       := null;
        l_sem_matches    := null;
        l_ratio_semantica := null;
        l_null_ratio     := pkg_dm_desc_puntuacion.func_dm_null_ratio_muestra(c.owner, c.table_name, c.column_name, p_sample_rows, l_rows_total);

        pkg_dm_desc_catalogo.proc_dm_aplica_excepcion(p_ejecucion_id, c.owner, c.table_name, c.column_name, l_best_id, l_score_total, l_force_mask);
        -- Un EXCLUDE de TDM_EXCEPCION_COL deja score -999: se fija el resultado y se deja motivo y traza.
        l_excl := (l_score_total = -999);

        if l_best_id = 'IDENTIFICADOR_IDENTIDAD'
           and regexp_like(c.column_name, '(^|_)(TIPO|COD|CODIGO|CLASE|ENUM|FLAG|ESTADO)_?(NIF|NIE|DNI|CIF)?($|_)', 'i')
           and nvl(l_ratio,0) < 0.5 -- si el dato prueba identidad, el nombre no penaliza
        then
          l_score_total := l_score_total - 250;
          l_motivo_descarte := nvl(l_motivo_descarte, 'CAMPO_TECNICO_IDENTIDAD');
        end if;

        if l_best_id = 'IDENTIFICADOR_DIRECCION'
           and regexp_like(c.column_name, '(^|_)(CODIGO_VIA|NUMERO_VIA|CODIGO|NUMERO)(_VIA|_R)?($|_)', 'i')
        then
          l_score_total := l_score_total - 220;
          l_motivo_descarte := nvl(l_motivo_descarte, 'CAMPO_NUMERICO_TECNICO_DIRECCION');
        end if;

        if l_best_id = 'IDENTIFICADOR_PERSONAL'
           and pkg_dm_desc_puntuacion.func_dm_es_nombre_candidato(c.column_name) = 1
        then
          l_ctx_persona := l_ctx_persona_tab;
          if l_ctx_persona = 0 then
            l_score_total := l_score_total - 90;
            l_motivo_descarte := nvl(l_motivo_descarte, 'NOMBRE_SIN_CONTEXTO_PERSONA');
          end if;

          if l_ctx_apellidos_tab = 0 then
            l_score_total := l_score_total - 220;
            l_motivo_descarte := nvl(l_motivo_descarte, 'NOMBRE_SIN_APELLIDOS_TABLA');

            l_ratio_semantica := pkg_dm_desc_puntuacion.func_dm_ratio_nombre_sem(
                                  c.owner,
                                  c.table_name,
                                  c.column_name,
                                  p_sample_rows,
                                  l_sem_rows,
                                  l_sem_matches
                                );

            if nvl(l_sem_rows,0) >= 10 and nvl(l_ratio_semantica,0) >= 0.70 then
              l_score_total := l_score_total + 170;
              l_motivo_descarte := null;
            end if;
          end if;
        end if;

        -- NAME a secas (columna generica): no es candidato de nombre por si sola. Se acepta
        -- como dato personal solo si el dato lo demuestra. Dos niveles:
        --   Nivel 1: la tabla tiene columna de apellido -> basta ratio semantico >= 0.70.
        --   Nivel 2: sin apellido -> exige contexto de persona y ratio >= 0.90 (NAME puede
        --            englobar nombre y apellido, pero tambien cargos o textos libres).
        l_nombre_gen_ok := true;
        if l_best_id = 'IDENTIFICADOR_PERSONAL'
           and pkg_dm_desc_puntuacion.func_dm_es_nombre_generico(c.column_name) = 1
           and l_force_mask <> 'Y'
        then
          l_ratio_semantica := pkg_dm_desc_puntuacion.func_dm_ratio_nombre_sem(
                                 c.owner, c.table_name, c.column_name,
                                 p_sample_rows, l_sem_rows, l_sem_matches);
          if l_ctx_apellidos_tab > 0 then
            l_nombre_gen_ok := nvl(l_sem_rows,0) >= 10 and nvl(l_ratio_semantica,0) >= 0.70;
          else
            l_nombre_gen_ok := l_ctx_persona_tab > 0 and nvl(l_sem_rows,0) >= 10
                               and nvl(l_ratio_semantica,0) >= 0.90;
          end if;
          if not l_nombre_gen_ok then
            l_score_total := l_score_total - 220;
            l_motivo_descarte := nvl(l_motivo_descarte, 'NOMBRE_GENERICO_SIN_SEMANTICA');
          end if;
        end if;

        -- El dato contradice el nombre: con formatos exigentes (TDM_REGLA.confianza_min) y ninguna fila de la
        -- muestra que los cumpla, la columna no supera REVISAR aunque el nombre puntue alto.
        if l_contra = 1 and l_force_mask <> 'Y' and l_score_total > 55 then
          l_score_total := 55;
          l_motivo_descarte := nvl(l_motivo_descarte, 'DATO_NO_COINCIDE_CON_FORMATO');
        end if;

        pkg_dm_desc_puntuacion.proc_dm_clasifica(l_score_total, l_estado_final, l_enmascarar);

        if l_best_id = 'IDENTIFICADOR_PERSONAL'
           and l_score_nombre >= 85
           and l_force_mask <> 'Y'
           and (l_rows_total is null or l_null_ratio is null)
           and l_score_total >= 65
        then
          l_estado_final := case when l_score_total >= 85 then 'CONFIRMADO' else 'PROBABLE' end;
          l_enmascarar := 'Y';
          l_motivo_descarte := null;
        end if;

        if l_best_id = 'IDENTIFICADOR_PERSONAL'
           and pkg_dm_desc_puntuacion.func_dm_es_nombre_candidato(c.column_name) = 1
           and l_ctx_apellidos_tab = 0
           and l_force_mask <> 'Y'
           and (nvl(l_sem_rows,0) < 10 or nvl(l_ratio_semantica,0) < 0.70)
        then
          l_estado_final := 'REVISAR';
          l_enmascarar   := 'N';
          l_motivo_descarte := 'NOMBRE_SIN_SEMANTICA_PERSONA';
        end if;

        if l_best_id = 'IDENTIFICADOR_PERSONAL'
           and pkg_dm_desc_puntuacion.func_dm_es_nombre_generico(c.column_name) = 1
           and l_force_mask <> 'Y'
           and not l_nombre_gen_ok
        then
          l_estado_final := 'REVISAR';
          l_enmascarar   := 'N';
          l_motivo_descarte := 'NOMBRE_GENERICO_SIN_SEMANTICA';
        end if;

        if l_best_id = 'IDENTIFICADOR_TELEFONO'
           and l_force_mask <> 'Y'
           and l_score_nombre >= 70
           and nvl(l_rows_total,0) >= 10
           and (
                nvl(l_ratio,0) >= 0.45
                or nvl(l_score_patron,0) >= 25
               )
        then
          l_estado_final := case when l_score_total >= 65 then 'PROBABLE' else 'REVISAR' end;
          l_enmascarar := 'Y';
          l_motivo_descarte := null;
        end if;

        if l_force_mask <> 'Y'
           and l_best_id in ('IDENTIFICADOR_BANCARIO','IDENTIFICADOR_IDENTIDAD')
           and l_score_nombre >= 90
           and l_score_total >= 85
           and (l_rows_total is not null and l_rows_total < 10)
        then
          l_estado_final := 'PROBABLE';
          l_enmascarar := 'Y';
          l_motivo_descarte := null;
        end if;

        if l_rows_total is not null
           and l_rows_total < 10
           and l_force_mask <> 'Y'
           and not (
             l_best_id in ('IDENTIFICADOR_BANCARIO','IDENTIFICADOR_IDENTIDAD')
             and l_score_nombre >= 90
             and l_score_total >= 85
           )
        then
          l_estado_final := 'DESCARTADO';
          l_enmascarar := 'N';
          l_motivo_descarte := 'MUESTRA_INSUFICIENTE_MIN_10';
        elsif l_null_ratio is not null
           and l_null_ratio >= 0.995
           -- El ratio de nulos mira las primeras filas fisicas: una columna dispersa salia 100 % nula aunque el
           -- muestreo encontrara datos. Solo es "alta nulidad" si el muestreo no encontro datos suficientes.
           and nvl(l_rows,0) < 10
           and l_force_mask <> 'Y'
           and not (
             l_best_id in ('IDENTIFICADOR_BANCARIO','IDENTIFICADOR_IDENTIDAD')
             and l_score_nombre >= 90
             and l_score_total >= 85
           )
        then
          l_estado_final := 'DESCARTADO';
          l_enmascarar := 'N';
          l_motivo_descarte := 'ALTA_NULIDAD_EN_MUESTRA';
        end if;

        if l_force_mask = 'Y' then
          l_enmascarar := 'Y';
          l_estado_final := 'CONFIRMADO';
          l_motivo_descarte := null;
        end if;

        if l_excl then
          l_estado_final    := 'DESCARTADO';
          l_enmascarar      := 'N';
          l_motivo_descarte := 'EXCLUDE_TDM_EXCEPCION_COL';
          pkg_dm_trazabilidad.proc_dm_trace(null, p_ejecucion_id, 'DESCUBRIMIENTO', 'EXCEPCION_EXCLUDE',
            c.owner||'.'||c.table_name||'.'||c.column_name||' excluida por TDM_EXCEPCION_COL (identificador evaluado='||l_best_id||')');
        end if;

        if l_sin_pos and l_force_mask <> 'Y' then
          l_estado_final    := 'DESCARTADO';
          l_enmascarar      := 'N';
          l_motivo_descarte := nvl(l_motivo_descarte, 'SCORE_TOTAL_NO_POSITIVO');
        end if;

        insert into tdm_columna_hist(
          hist_id, ejecucion_id, ora_owner, table_name, column_name,
          data_type, data_length, data_precision, data_scale,
          column_comment, identificador,
          score_nombre, score_comentario, score_patron, score_tabla, score_total,
          sample_rows, matched_rows, ratio_match, ratio_null,
          estado_final, motivo_descarte, enmascarar, hash_reglas
        ) values (
          seq_dm_columna_hist.nextval, p_ejecucion_id, c.owner, c.table_name, c.column_name,
          c.data_type, c.data_length, c.data_precision, c.data_scale,
          l_comment, l_best_id,
          l_score_nombre, l_score_coment, l_score_patron, l_score_tabla, l_score_total,
          l_rows_total, l_matches, l_ratio, l_null_ratio,
          l_estado_final, l_motivo_descarte, l_enmascarar,
          to_char(ora_hash(c.owner || '|' || c.table_name || '|' || c.column_name || '|' || l_best_id || '|' || l_score_total))
        );

        if l_enmascarar = 'Y' then
          pkg_dm_desc_catalogo.proc_dm_recolecta_dep(p_ejecucion_id, c.owner, c.table_name, c.column_name);
        end if;

        p_cols_lote := p_cols_lote + 1;
        p_tab_cols  := p_tab_cols + 1;
        if l_enmascarar = 'Y' then
          p_tab_y := p_tab_y + 1;
        end if;

        update tdm_ejecucion
           set columnas_proc = nvl(columnas_proc,0) + 1,
               progreso_pct = case
                 when columnas_total > 0 then round(((nvl(columnas_proc,0)+1) / columnas_total) * 100, 2)
                 else 100
               end,
               ultimo_objeto = c.owner || '.' || c.table_name || '.' || c.column_name,
               ultimo_paso = 'COLUMNA_PROCESADA',
               heartbeat_ts = systimestamp
         where ejecucion_id = p_ejecucion_id;

        if mod(p_cols_lote, p_commit_lote) = 0 then
          commit;
        end if;

      exception
        when others then
          pkg_dm_trazabilidad.proc_dm_log_error(p_ejecucion_id, c.owner, c.table_name, c.column_name, 'PROCESA_COLUMNA', sqlcode, sqlerrm);
end proc_dm_evalua_columna;

------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_procesa_desc
-- PROPOSITO    : Motor central del descubrimiento: recorre las tablas PENDIENTE, puntua cada columna
--                candidata, clasifica, guarda el historico, sincroniza las tablas FINAL y cierra la
--                ejecucion.
-- ENTRADAS     : p_ejecucion_id, p_sample_rows, p_commit_lote (columnas por commit). Sin OUT; deja la
--                ejecucion en FINALIZADO o ERROR.
-- LEE          : TDM_EJECUCION; TDM_OBJETO_CTRL; TDM_EJECUCION_SCOPE; TDM_REGLA; DBA_TAB_COLUMNS;
--                DBA_COL_COMMENTS (via func_dm_get_col_comment); Tablas de usuario (muestreo)
-- ESCRIBE      : TDM_EJECUCION (estado, progreso, heartbeat, fecha_fin); TDM_OBJETO_CTRL;
--                TDM_COLUMNA_HIST (DELETE+INSERT); TDM_DEPENDENCIA_HIST (DELETE+INSERT);
--                TDM_COLUMNA_FINAL y TDM_DEPENDENCIA_FINAL (via sync); TDM_EJECUCION_ERROR /
--                TDM_MASK_TRACE (via trazabilidad)
-- ERRORES      : ORA-20010 si la ejecucion no esta en EJECUTANDO; Error por columna: se
--                registra PROCESA_COLUMNA y continua con la siguiente; Error general: registra
--                PROCESO_GENERAL, marca la ejecucion en ERROR (ERROR_FATAL) y re-lanza; Si la
--                ejecucion pasa a CANCELADO/ABORTADA hace RETURN silencioso entre tablas
-- LLAMADO DESDE: proc_dm_descubrimiento_core; proc_dm_reanudar
------------------------------------------------------------------------------
procedure proc_dm_procesa_desc(
    p_ejecucion_id in number,
    p_sample_rows  in number,
    p_commit_lote  in number
) is
  l_esquema           tdm_ejecucion.ora_esquema%type;
  l_estado            tdm_ejecucion.estado%type;
  l_cols_lote         number := 0;
  l_run_t0            timestamp with time zone := systimestamp;   -- traza: duracion de la corrida
  l_tot_omit          number := 0;                                -- traza: tablas sin filas omitidas
  l_tot_err           number := 0;                                -- tablas con columnas sin evaluar
  l_err_tab           number;
  l_tab_cols          number := 0;                                -- traza: columnas evaluadas en la tabla
  l_tab_y             number := 0;                                -- traza: columnas marcadas Y en la tabla
  l_tot_tabs          number := 0;
  l_tot_cols          number := 0;
  l_tot_y             number := 0;
  l_alcance           varchar2(200);
  l_ctx_persona_tab   number := 0;
  l_ctx_apellidos_tab number := 0;
  l_num_admitido      varchar2(2100);                             -- expresion de columnas NUMBER admitidas (reglas NUMBER_ADMITIDO)
  l_c                 t_dm_col_rec;
begin
  select ora_esquema, estado
    into l_esquema, l_estado
    from tdm_ejecucion
   where ejecucion_id = p_ejecucion_id
   for update;

  if l_estado <> 'EJECUTANDO' then
    raise_application_error(-20010, 'La ejecución no está disponible para procesar');
  end if;

  update tdm_ejecucion
     set estado = 'EJECUTANDO',
         fase_proceso = 'DESCUBRIMIENTO',
         ultimo_paso = 'PROCESANDO_TABLAS',
         heartbeat_ts = systimestamp
   where ejecucion_id = p_ejecucion_id;

  commit;

  for t in (
    select tctl.ora_owner, tctl.table_name
      from tdm_objeto_ctrl tctl
     where tctl.ora_owner = l_esquema
       and tctl.estado_objeto = 'PENDIENTE'
       and (
         not exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.ora_owner = l_esquema)
         or exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.ora_owner = l_esquema and sc.table_name in ('*', tctl.table_name))
       )
     order by tctl.table_name
  ) loop
    select estado into l_estado
      from tdm_ejecucion
     where ejecucion_id = p_ejecucion_id;

    if l_estado in ('CANCELADO','ABORTADA') then
      return;
    end if;

    if pkg_dm_desc_puntuacion.func_dm_tabla_tiene_filas(t.ora_owner, t.table_name) = 0 then
      update tdm_objeto_ctrl
         set estado_objeto = 'OMITIDO',
             motivo_estado = 'TABLA_SIN_FILAS',
             fecha_ult_analisis = systimestamp,
             ultimo_run_id = p_ejecucion_id
       where ora_owner = t.ora_owner
         and table_name = t.table_name;

      -- Una tabla omitida no procesa columnas: el progreso se calcula siempre sobre columnas_proc/columnas_total.
      update tdm_ejecucion
         set tablas_proc = nvl(tablas_proc,0) + 1,
             progreso_pct = case when nvl(columnas_total,0) > 0 then round(nvl(columnas_proc,0)/columnas_total*100,2) else progreso_pct end,
             ultimo_objeto = t.ora_owner || '.' || t.table_name,
             ultimo_paso = 'TABLA_OMITIDA_SIN_FILAS',
             heartbeat_ts = systimestamp
       where ejecucion_id = p_ejecucion_id;

      commit;
      l_tot_omit := l_tot_omit + 1;   -- se informa una sola vez al final (DESCUBRIMIENTO.TABLAS_OMITIDAS)
      continue;
    end if;

    l_tab_cols := 0;
    l_tab_y    := 0;

    delete from tdm_dependencia_hist
     where ejecucion_id = p_ejecucion_id
       and ora_owner = t.ora_owner
       and table_name = t.table_name;

    delete from tdm_columna_hist
     where ejecucion_id = p_ejecucion_id
       and ora_owner = t.ora_owner
       and table_name = t.table_name;

    -- Se confirma al empezar la tabla para que el monitor muestre cual es la que esta en curso.
    update tdm_ejecucion
       set ultimo_objeto = t.ora_owner || '.' || t.table_name,
           ultimo_paso = 'LECTURA_COLUMNAS',
           heartbeat_ts = systimestamp
     where ejecucion_id = p_ejecucion_id;
    commit;

    l_ctx_persona_tab   := pkg_dm_desc_puntuacion.func_dm_tiene_ctx_persona(t.ora_owner, t.table_name);
    l_ctx_apellidos_tab := pkg_dm_desc_puntuacion.func_dm_tiene_apellidos(t.ora_owner, t.table_name);

    -- Las columnas NUMBER solo se evaluan si su nombre coincide con las reglas NUMBER_ADMITIDO de TDM_REGLA.
    l_num_admitido := '(^|_)(' || pkg_dm_desc_puntuacion.func_dm_lista_regla('NUMBER_ADMITIDO') || ')($|_)';

    for c in (
      select c.owner, c.table_name, c.column_name, c.data_type,
             c.data_length, c.data_precision, c.data_scale
        from dba_tab_columns c
       where c.owner = t.ora_owner
         and c.table_name = t.table_name
         -- una columna virtual no se puede actualizar (ORA-54017): no es candidata
         and not exists (select 1 from dba_tab_cols v
                          where v.owner = c.owner and v.table_name = c.table_name
                            and v.column_name = c.column_name and v.virtual_column = 'YES')
         and (
           c.data_type in ('CHAR','NCHAR','VARCHAR2','NVARCHAR2','CLOB')
           or (
             c.data_type = 'NUMBER'
             and regexp_like(c.column_name, l_num_admitido, 'i')
           )
         )
       order by c.column_id
    ) loop
      l_c.owner          := c.owner;
      l_c.table_name     := c.table_name;
      l_c.column_name    := c.column_name;
      l_c.data_type      := c.data_type;
      l_c.data_length    := c.data_length;
      l_c.data_precision := c.data_precision;
      l_c.data_scale     := c.data_scale;
      -- La columna en evaluacion queda visible (con latido) antes de leerla: en una tabla grande puede tardar minutos.
      update tdm_ejecucion
         set ultimo_objeto = c.owner || '.' || c.table_name || '.' || c.column_name,
             ultimo_paso = 'EVALUANDO_COLUMNA',
             heartbeat_ts = systimestamp
       where ejecucion_id = p_ejecucion_id;
      commit;
      -- La cancelacion se atiende por columna (una tabla grande puede tardar horas): se retira el historico
      -- parcial de la corrida y se sale sin sincronizar ni finalizar.
      select estado into l_estado from tdm_ejecucion where ejecucion_id = p_ejecucion_id;
      if l_estado in ('CANCELADO','ABORTADA') then
        delete from tdm_dependencia_hist where ejecucion_id = p_ejecucion_id;
        delete from tdm_columna_hist     where ejecucion_id = p_ejecucion_id;
        commit;
        return;
      end if;
      proc_dm_evalua_columna(p_ejecucion_id, p_sample_rows, p_commit_lote, l_c,
                             l_ctx_persona_tab, l_ctx_apellidos_tab, l_cols_lote, l_tab_cols, l_tab_y);
    end loop;

    -- Una columna fallida (privilegios, conversion, lectura) es ausencia de evidencia, no descarte: la tabla pasa
    -- a ERROR, el sync conserva sus columnas en FINAL y la proxima ejecucion la reintenta.
    select count(*) into l_err_tab
      from tdm_ejecucion_error
     where ejecucion_id = p_ejecucion_id
       and ora_owner    = t.ora_owner
       and table_name   = t.table_name
       and etapa        = 'PROCESA_COLUMNA';
    if l_err_tab > 0 then
      l_tot_err := l_tot_err + 1;
      update tdm_objeto_ctrl
         set estado_objeto = 'ERROR',
             motivo_estado = 'COLUMNAS_SIN_EVALUAR='||l_err_tab,
             ultimo_run_id = p_ejecucion_id,
             fecha_ult_analisis = systimestamp
       where ora_owner = t.ora_owner
         and table_name = t.table_name;
    else
      update tdm_objeto_ctrl
         set estado_objeto = 'PROCESADO',
             motivo_estado = null,
             ultimo_run_id = p_ejecucion_id,
             fecha_ult_analisis = systimestamp
       where ora_owner = t.ora_owner
         and table_name = t.table_name;
    end if;

    update tdm_ejecucion
       set tablas_proc = nvl(tablas_proc,0) + 1,
           ultimo_paso = 'TABLA_FINALIZADA',
           heartbeat_ts = systimestamp
     where ejecucion_id = p_ejecucion_id;

    commit;

    if l_tab_cols > 0 then
      l_tot_tabs := l_tot_tabs + 1;   -- solo tablas con columnas evaluadas (igual que el resumen de @dm_descubre)
    end if;
    l_tot_cols := l_tot_cols + l_tab_cols;
    l_tot_y    := l_tot_y    + l_tab_y;
  end loop;

  -- Si la corrida se cancelo o aborto durante la ultima tabla no se publica el catalogo ni se pisa CANCELADO.
  select estado into l_estado from tdm_ejecucion where ejecucion_id = p_ejecucion_id;
  if l_estado in ('CANCELADO','ABORTADA') then
    delete from tdm_dependencia_hist where ejecucion_id = p_ejecucion_id;
    delete from tdm_columna_hist     where ejecucion_id = p_ejecucion_id;
    commit;
    return;
  end if;

  pkg_dm_desc_catalogo.proc_dm_sync_col_final(p_ejecucion_id);
  pkg_dm_desc_catalogo.proc_dm_sync_dep_final(p_ejecucion_id);

  update tdm_ejecucion
     set estado = 'FINALIZADO',
         fase_proceso = 'DESCUBRIMIENTO',
         fecha_fin = systimestamp,
         progreso_pct = 100,
         error_count = (select count(*) from tdm_ejecucion_error e where e.ejecucion_id = p_ejecucion_id),
         ultimo_paso = 'FINALIZADO'
   where ejecucion_id = p_ejecucion_id
     and estado = 'EJECUTANDO';

  commit;

  -- La traza del descubrimiento es un resumen (mas tablas omitidas y avisos); el detalle esta en TDM_COLUMNA_HIST.
  if l_tot_omit > 0 then
    pkg_dm_trazabilidad.proc_dm_trace(null, p_ejecucion_id, 'DESCUBRIMIENTO', 'TABLAS_OMITIDAS',
      'tablas sin filas omitidas='||l_tot_omit);
  end if;
  if l_tot_err > 0 then
    pkg_dm_trazabilidad.proc_dm_trace(null, p_ejecucion_id, 'DESCUBRIMIENTO', 'TABLAS_CON_ERROR',
      'tablas con columnas sin evaluar='||l_tot_err||' (catalogo FINAL conservado; ver TDM_EJECUCION_ERROR)');
  end if;
  -- Modo de alcance del descubrimiento (set de tablas o esquema completo), para que la
  -- traza diga que se ejecuto y no solo cuantas columnas salieron.
  declare
    l_n_alc number;
  begin
    select count(distinct table_name) into l_n_alc from tdm_ejecucion_scope
     where ejecucion_id = p_ejecucion_id and table_name <> '*';
    l_alcance := case when l_n_alc > 0 then 'SET DE TABLAS ('||l_n_alc||' tablas)' else 'ESQUEMA COMPLETO' end;
  exception when others then
    l_alcance := 'NO DETERMINADO';
  end;
  pkg_dm_trazabilidad.proc_dm_trace(null, p_ejecucion_id, 'DESCUBRIMIENTO', 'RESUMEN',
    'alcance='||l_alcance||' tablas='||l_tot_tabs||' columnas='||l_tot_cols||' enmascarar='||l_tot_y,
    pkg_dm_trazabilidad.func_dm_seg_desde(l_run_t0));
exception
  when others then
    pkg_dm_trazabilidad.proc_dm_log_error(p_ejecucion_id, l_esquema, null, null, 'PROCESO_GENERAL', sqlcode, sqlerrm);
    update tdm_ejecucion
       set estado = 'ERROR',
           fecha_fin = systimestamp,
           ultimo_paso = 'ERROR_FATAL'
     where ejecucion_id = p_ejecucion_id;
    commit;
    raise;
end proc_dm_procesa_desc;

------------------------------------------------------------------------------
-- Nucleo privado: descubrimiento con o sin alcance por tablas (p_tablas_csv = null es el esquema completo).
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_descubrimiento_core
-- PROPOSITO    : Nucleo comun del descubrimiento: valida esquema y conflictos, crea la ejecucion,
--                registra el alcance, prepara objetos y lanza el procesamiento.
-- ENTRADAS     : p_esquema, p_tablas_csv (null = esquema completo), p_sample_rows, p_forzar_full ('Y'
--                fuerza reanalisis completo). Sin OUT.
-- LEE          : DBA_USERS; TDM_EJECUCION; Indirecto: TDM_EJECUCION_SCOPE
-- ESCRIBE      : TDM_EJECUCION (INSERT); Indirecto: TDM_EJECUCION_SCOPE, TDM_OBJETO_CTRL y todo lo
--                que escribe proc_dm_procesa_desc
-- ERRORES      : ORA-20016 si el esquema no existe en DBA_USERS; ORA-20011 si ya hay una ejecucion
--                EJECUTANDO o el indice unico rechaza la nueva (DUP_VAL_ON_INDEX); ORA-20014 si ya
--                existe una ejecucion maestra FINALIZADO con forzar_full = N y no se pidio 'Y'
-- LLAMADO DESDE: proc_dm_descubrimiento (ambas sobrecargas); proc_dm_descubrimiento_set
------------------------------------------------------------------------------
procedure proc_dm_descubrimiento_core(
    p_esquema          in varchar2,
    p_tablas_csv       in varchar2,
    p_sample_rows      in number,
    p_forzar_full      in char
) is
  l_running      number;
  l_run_id       number;
  l_ejec_base_id number;
  l_esquema_existe number;
begin
  -- Valida que el esquema exista antes de crear la ejecucion (antes terminaba FINALIZADO con 0 tablas).
  select count(*)
    into l_esquema_existe
    from dba_users
   where username = upper(p_esquema);

  if l_esquema_existe = 0 then
    raise_application_error(
      -20016,
      'El esquema ' || upper(p_esquema) || ' no existe (no aparece en DBA_USERS). ' ||
      'Revise el nombre -- no se ha creado ninguna ejecucion.'
    );
  end if;

  pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(15, 'N');
  l_running := func_dm_conflicto_running(upper(p_esquema), null);

  if l_running > 0 then
    raise_application_error(-20011, 'Existe una ejecución EJECUTANDO en curso para el esquema/alcance');
  end if;

  if upper(nvl(p_forzar_full,'N')) <> 'Y' then
    begin
      select max(ejecucion_id)
        into l_ejec_base_id
        from tdm_ejecucion
       where ora_esquema = upper(p_esquema)
         and fase_proceso in ('DESCUBRIMIENTO','ENMASCARAMIENTO')
         and nvl(forzar_full,'N') = 'N'
         and estado in ('FINALIZADO')
         and columnas_total > 0;

    exception
      when no_data_found then
        l_ejec_base_id := null;
    end;

    if l_ejec_base_id is not null then
      raise_application_error(
        -20014,
        'El esquema ' || upper(p_esquema) ||
        ' ya tiene una ejecución maestra registrada con FORZAR_FULL = N. ' ||
        'Para volver a ejecutar debe usar proc_dm_descubrimiento(''' ||
        upper(p_esquema) || ''',''Y'').'
      );
    end if;
  end if;

  BEGIN
    insert into tdm_ejecucion(
      ejecucion_id, ora_esquema, ora_usuario, fase_proceso, estado,
      fecha_inicio, ultimo_paso, forzar_full, sesion_audsid, heartbeat_ts
    ) values (
      seq_dm_ejecucion.nextval, upper(p_esquema), sys_context('USERENV','SESSION_USER'),
      'DESCUBRIMIENTO', 'EJECUTANDO',
      systimestamp,
      case when upper(nvl(p_forzar_full,'N'))='Y' then 'INICIADO_FORZAR_FULL' else 'INICIADO' end,
      case when upper(nvl(p_forzar_full,'N'))='Y' then 'Y' else 'N' end,
      sys_context('USERENV','SESSIONID'),
      systimestamp
    )
    returning ejecucion_id into l_run_id;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      raise_application_error(-20011, 'Existe una ejecución EJECUTANDO en curso para el esquema/alcance');
  END;

  proc_dm_registra_scope(l_run_id, upper(p_esquema), p_tablas_csv);

  -- Se confirma antes de refrescar la sesion: la rutina es autonoma y no veria la fila recien insertada.
  commit;
  pkg_dm_trazabilidad.proc_dm_refresca_sesion(l_run_id);

  proc_dm_prepara_objetos(
    upper(p_esquema),
    l_run_id,
    case when upper(nvl(p_forzar_full,'N'))='Y' then 'Y' else 'N' end
  );

  proc_dm_procesa_desc(l_run_id, pkg_dm_desc_puntuacion.func_dm_normaliza_sample(p_sample_rows), 100);
end proc_dm_descubrimiento_core;

------------------------------------------------------------------------------
-- API pública: ejecutar (esquema completo)
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_descubrimiento
-- PROPOSITO    : API publica para descubrir el esquema completo con tamano de muestra y modo
--                forzar_full configurables.
-- ENTRADAS     : p_esquema, p_sample_rows (default 500), p_forzar_full (default 'N'). Sin OUT.
-- LEE          : Ver proc_dm_descubrimiento_core
-- ESCRIBE      : Ver proc_dm_descubrimiento_core
-- ERRORES      : Propaga ORA-20011, ORA-20014 y ORA-20016 de proc_dm_descubrimiento_core
-- LLAMADO DESDE: dm_descubre.sql
------------------------------------------------------------------------------
procedure proc_dm_descubrimiento(
    p_esquema          in varchar2,
    p_sample_rows      in number default 500,
    p_forzar_full      in char default 'N'
) is
begin
  proc_dm_descubrimiento_core(
    p_esquema     => p_esquema,
    p_tablas_csv  => null,
    p_sample_rows => p_sample_rows,
    p_forzar_full => p_forzar_full
  );
end proc_dm_descubrimiento;
------------------------------------------------------------------------------
-- API pública: sobrecarga
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_descubrimiento
-- PROPOSITO    : API publica (sobrecarga) para descubrir el esquema completo con muestra fija de 500
--                filas y modo forzar_full explicito.
-- ENTRADAS     : p_esquema, p_forzar_full. Sin OUT.
-- LEE          : Ver proc_dm_descubrimiento_core
-- ESCRIBE      : Ver proc_dm_descubrimiento_core
-- ERRORES      : Propaga ORA-20011, ORA-20014 y ORA-20016 de proc_dm_descubrimiento_core
-- LLAMADO DESDE: dm_descubre.sql (con 'Y')
------------------------------------------------------------------------------
procedure proc_dm_descubrimiento(
    p_esquema     in varchar2,
    p_forzar_full in char
) is
begin
  proc_dm_descubrimiento_core(
    p_esquema     => p_esquema,
    p_tablas_csv  => null,
    p_sample_rows => 500,
    p_forzar_full => p_forzar_full
  );
end proc_dm_descubrimiento;

------------------------------------------------------------------------------
-- API pública: descubrimiento por excepciones (@dm_descubre_set)
-- Alcance limitado a p_tablas_csv (tipicamente las tablas de un FORCE previo). El resultado (Y/N en
-- tdm_columna_final) se registra como en modo completo, pero no reemplaza la decision FORCE de tdm_excepcion_col.
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_descubrimiento_set
-- PROPOSITO    : API publica para descubrir solo una lista de tablas (modo por excepciones) sin
--                escanear el esquema completo.
-- ENTRADAS     : p_esquema, p_tablas_csv (obligatorio), p_sample_rows (default 500), p_forzar_full
--                (default 'N'). Sin OUT.
-- LEE          : Ver proc_dm_descubrimiento_core
-- ESCRIBE      : Ver proc_dm_descubrimiento_core
-- ERRORES      : ORA-20015 si p_tablas_csv es nulo o vacio; Propaga ORA-20011, ORA-20014 y ORA-20016
--                de proc_dm_descubrimiento_core
-- LLAMADO DESDE: dm_descubre_set.sql
------------------------------------------------------------------------------
procedure proc_dm_descubrimiento_set(
    p_esquema          in varchar2,
    p_tablas_csv       in varchar2,
    p_sample_rows      in number default 500,
    p_forzar_full      in char default 'N'
) is
begin
  if p_tablas_csv is null or length(trim(p_tablas_csv)) = 0 then
    raise_application_error(-20015,
      'proc_dm_descubrimiento_set requiere p_tablas_csv con al menos una tabla; '||
      'para descubrimiento de esquema completo use proc_dm_descubrimiento.');
  end if;

  proc_dm_descubrimiento_core(
    p_esquema     => p_esquema,
    p_tablas_csv  => p_tablas_csv,
    p_sample_rows => p_sample_rows,
    p_forzar_full => p_forzar_full
  );
end proc_dm_descubrimiento_set;

------------------------------------------------------------------------------
-- API pública: reanudar
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_reanudar
-- PROPOSITO    : API publica para reanudar una ejecucion de descubrimiento interrumpida, tras
--                comprobar que su sesion original ya no esta viva.
-- ENTRADAS     : p_ejecucion_id, p_sample_rows (default 500), p_commit_lote (default 100). Sin OUT.
-- LEE          : TDM_EJECUCION (FOR UPDATE); gv$session (indirecto, via
--                pkg_dm_trazabilidad.func_dm_sesion_viva)
-- ESCRIBE      : TDM_EJECUCION (estado, fecha_fin, ultimo_paso); Indirecto: lo que escribe
--                proc_dm_procesa_desc y proc_dm_autocancel_huerfanas / proc_dm_refresca_sesion
-- ERRORES      : ORA-20019 si la fase de la ejecucion no es DESCUBRIMIENTO; ORA-20017 si la sesion
--                original sigue viva en gv$session; ORA-20012 si el estado es FINALIZADO o CANCELADO;
--                ORA-01403 sin controlar si ejecucion_id no existe
-- LLAMADO DESDE: dm_descubre_reanudar.sql
------------------------------------------------------------------------------
procedure proc_dm_reanudar(
    p_ejecucion_id in number,
    p_sample_rows  in number default 500,
    p_commit_lote  in number default 100
) is
  l_estado         tdm_ejecucion.estado%type;
  l_fase           tdm_ejecucion.fase_proceso%type;
  l_heartbeat      tdm_ejecucion.heartbeat_ts%type;
  l_sesion_viva    number := 0;
  l_sid            tdm_ejecucion.sesion_sid%type;
  l_serial         tdm_ejecucion.sesion_serial%type;
  l_inst_id        tdm_ejecucion.sesion_inst_id%type;
  l_ejecutado_por  tdm_ejecucion.ora_usuario%type;
begin
  pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(5, 'N');

  select estado, fase_proceso, heartbeat_ts, sesion_sid, sesion_serial, sesion_inst_id, ora_usuario
    into l_estado, l_fase, l_heartbeat, l_sid, l_serial, l_inst_id, l_ejecutado_por
    from tdm_ejecucion
   where ejecucion_id = p_ejecucion_id
   for update;

  -- Este es el reanudador de DESCUBRIMIENTO: la fila debe seguir en esa fase. Si estaba en ENMASCARAMIENTO, se
  -- corta aqui, antes de tocar nada, indicando el driver correcto.
  if l_fase is not null and upper(trim(l_fase)) != 'DESCUBRIMIENTO' then
    raise_application_error(-20019,
      'No se reanuda ejecucion_id='||p_ejecucion_id||' con pkg_dm_descubrimiento.proc_dm_reanudar: '||
      'su fase_proceso actual es '||l_fase||', no DESCUBRIMIENTO. '||
      case when upper(trim(l_fase)) = 'ENMASCARAMIENTO'
           then 'Use @dm_enmascara_reanudar '||p_ejecucion_id||' para reanudar el enmascarado.'
           else 'Revise TDM_EJECUCION.fase_proceso antes de continuar.'
      end);
  end if;

  -- La sesion original no debe seguir viva en gv$session, sea cual sea el ESTADO: si no, se lanzaria una segunda
  -- ejecucion en paralelo sobre el mismo esquema.
  l_sesion_viva := pkg_dm_trazabilidad.func_dm_sesion_viva(p_ejecucion_id);

  if l_sesion_viva = 1 then
    raise_application_error(-20017,
      'No se reanuda ejecucion_id='||p_ejecucion_id||': la sesion original '||
      '(sid='||nvl(to_char(l_sid),'?')||', serial#='||nvl(to_char(l_serial),'?')||
      ', inst_id='||nvl(to_char(l_inst_id),'?')||', usuario='||nvl(l_ejecutado_por,'?')||
      ') SIGUE VIVA en gv$session (TDM_EJECUCION.ESTADO actual='||nvl(l_estado,'?')||
      '). No se reanuda para evitar una ejecucion de DESCUBRIMIENTO duplicada en '||
      'paralelo -- verifique esa sesion y matela con ALTER SYSTEM KILL SESSION si procede, luego reintente.');
  end if;

  -- Con la sesion original confirmada muerta, una fila que siguiera EJECUTANDO se autosana a ABORTADA antes de
  -- reclamarla; ya no hace falta mirar el latido.
  if l_estado = 'EJECUTANDO' then
    update tdm_ejecucion
       set estado = 'ABORTADA',
           fecha_fin = systimestamp,
           ultimo_paso = 'AUTO_ABORTADA_REANUDAR_SESION_CAIDA'
     where ejecucion_id = p_ejecucion_id
       and estado = 'EJECUTANDO';
    l_estado := 'ABORTADA';
  end if;

  if l_estado in ('FINALIZADO','CANCELADO') then
    raise_application_error(-20012, 'La ejecución no puede reanudarse por estado final');
  end if;

  -- El reclamo y el registro de la sesion nueva van en la misma sentencia y el mismo COMMIT: un segundo
  -- reanudador, al liberarse el bloqueo, ve la sesion nueva viva y recibe ORA-20017.
  update tdm_ejecucion
     set estado = 'EJECUTANDO',
         fecha_fin = null,
         ultimo_paso = 'REANUDADO',
         sesion_audsid  = sys_context('USERENV','SESSIONID'),
         sesion_sid     = to_number(sys_context('USERENV','SID')),
         sesion_serial  = (select s.serial# from v$session s where s.sid = to_number(sys_context('USERENV','SID'))),
         sesion_inst_id = to_number(sys_context('USERENV','INSTANCE')),
         heartbeat_ts   = systimestamp
   where ejecucion_id = p_ejecucion_id;

  commit;

  proc_dm_procesa_desc(p_ejecucion_id, pkg_dm_desc_puntuacion.func_dm_normaliza_sample(p_sample_rows), p_commit_lote);
end proc_dm_reanudar;

------------------------------------------------------------------------------
-- API pública: cancelar
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_cancelar
-- PROPOSITO    : API publica para cancelar una ejecucion de descubrimiento y eliminar su historico de
--                columnas y dependencias.
-- ENTRADAS     : p_ejecucion_id. Sin OUT.
-- LEE          : ninguno
-- ESCRIBE      : TDM_EJECUCION (UPDATE a CANCELADO si estaba EJECUTANDO/ERROR/ABORTADA);
--                TDM_DEPENDENCIA_HIST (DELETE); TDM_COLUMNA_HIST (DELETE)
-- ERRORES      : No levanta ORA-2xxxx; si el estado no es cancelable no cambia la ejecucion pero
--                igualmente borra su historico
-- LLAMADO DESDE: externo/script (solo documentado en 00_guion_uso_datamasking.sql; ningun driver .sql
--                la invoca)
------------------------------------------------------------------------------
procedure proc_dm_cancelar(
    p_ejecucion_id in number
) is
begin
  update tdm_ejecucion
     set estado = 'CANCELADO',
         fecha_fin = systimestamp,
         ultimo_paso = 'CANCELADO',
         heartbeat_ts = systimestamp,
         sesion_sid = null,
         sesion_serial = null,
         sesion_inst_id = null
   where ejecucion_id = p_ejecucion_id
     and estado in ('EJECUTANDO','ERROR','ABORTADA');

  delete from tdm_dependencia_hist where ejecucion_id = p_ejecucion_id;
  delete from tdm_columna_hist     where ejecucion_id = p_ejecucion_id;

  commit;
end proc_dm_cancelar;
  -- Reenvio de compatibilidad: la logica vive en pkg_dm_dominios.
  procedure proc_dm_propaga_dominios(
    p_esquema      in varchar2,
    p_solicitud_id in number default null,
    p_ejecucion_id in number default null
) IS
  BEGIN
    pkg_dm_dominios.proc_dm_propaga_dominios(p_esquema, p_solicitud_id, p_ejecucion_id);
  END;


end pkg_dm_descubrimiento;
/
