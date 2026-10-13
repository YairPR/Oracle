Rem pkg_dm_enmascarar.sql
Rem
Rem    NOMBRE
Rem      pkg_dm_enmascarar.sql - Motor operativo de enmascaramiento
Rem
Rem    DESCRIPCIÓN
Rem      Ejecuta el enmascarado sobre las columnas aprobadas en tdm_columna_final, con las
Rem      funciones deterministas FF1 de pkg_dm_mask_ff1, respetando dependencias tecnicas,
Rem      reglas especiales y coherencia posterior entre tablas relacionadas.
Rem
Rem      Soporta: ejecucion completa, reproceso forzado, cancelacion controlada, reanudacion,
Rem      enmascarado selectivo por tabla o columna, y alcance por identificador o por set de tablas.
Rem
Rem    FLUJO
Rem      Lee:       tdm_columna_final, tdm_dependencia_final, tdm_excepcion_col,
Rem                 tdm_mask_regla_esp, tdm_mask_relacion_sync
Rem      Registra:  tdm_ejecucion, tdm_mask_solicitud, tdm_mask_trace, tdm_mask_dep_estado
Rem
Rem      1) Valida concurrencia y reclama la ejecucion.
Rem      2) Preflight de tareas DBMS_PARALLEL_EXECUTE huerfanas.
Rem      3) Deshabilita dependencias (FK, triggers) de las tablas a enmascarar.
Rem      4) Enmascara columna a columna (proc_dm_mask_cat -> pkg_dm_mask_columna).
Rem      5) Sincroniza tablas relacionadas sin FK, rehabilita dependencias, recompila y cierra.
Rem
Rem    CRITERIOS POR COLUMNA
Rem      Antes de enmascarar se valida el tipo y la longitud reales (DBA_TAB_COLUMNS), que haya
Rem      datos no nulos, que no exista un EXCLUDE y que la longitud admita el identificador.
Rem      Si no cumple, la columna se omite con traza SKIP (y puede quedar como EXCLUDE en
Rem      tdm_excepcion_col) sin abortar la tabla.
Rem
Rem    REGLAS ESPECIALES (tdm_mask_regla_esp)
Rem      DOC_SEGUN_TIPO, DOC_UNIFICADO_MANTENER_1_Y_ULTIMO e IBAN_ES_CONTINUO llaman a las
Rem      funciones especiales de pkg_dm_mask_ff1.
Rem
Rem    RELACIÓN CON EL DESCUBRIMIENTO
Rem      Este paquete no descubre columnas: parte del catalogo ya validado por pkg_dm_descubrimiento.
Rem      La reversion funcional se hace por import del dump original, no fila a fila (el export
Rem      Data Pump vive en pkg_dm_export).
Rem
Rem    NOTAS
Rem      - Oracle 11g en adelante. SQL dinamico controlado con DBMS_ASSERT.
Rem      - Seguimiento operativo con DBMS_APPLICATION_INFO y trazas de avisos, errores y checkpoints.
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    09/05/25 - Versión inicial del motor de enmascaramiento
Rem                           Basado en ejecución por columna y función semántica
Rem    epurisaca    10/11/25 - Control operativo de solicitud, trazabilidad técnica y gestión de
Rem                           dependencias
Rem    epurisaca    11/22/25 - Reglas especiales para documentos e IBAN y coherencia post-masking
Rem    epurisaca    01/28/26 - Validación de longitudes, exclusiones automáticas y tratamiento de errores
Rem    epurisaca    03/24/26 - Corrección de ORA-06502 y ORA-12899 con validación previa por tipo y
Rem                           longitud real; SKIP controlado de columnas incompatibles o sin datos;
Rem                           export integrado en el flujo PRE con reversión por import
Rem    epurisaca    03/28/26 - Se retira tdm_mask_resultado (duplicaba estados)
Rem    epurisaca    04/21/26 - Procesa tdm_columna_final.enmascarar='Y' como fuente principal; EXCLUDE
Rem                           omite y FORCE redefine el identificador; sin columnas en Y usa los
Rem                           FORCE activos de tdm_excepcion_col
Rem    epurisaca    07/14/26 - Sync de tdm_dependencia_final alineado con PRE/POST: conserva el estado
Rem                           real ENABLED/DISABLED; los objetos Oracle Text DR$ quedan en revisión
Rem    epurisaca    09/16/26 - Se extrae pkg_dm_trazabilidad (proc_dm_trace y proc_dm_log_ejec_error
Rem                           quedan como envoltorios); proc_dm_enmascara_tabla crea una ejecución real
Rem                           (antes ejecucion_id=-1, ORA-02291); la propagación de dominios FK falla cerrado
Rem    epurisaca    09/18/26 - DBMS_PARALLEL_EXECUTE: nombre de tarea con GUID (ORA-29497 por truncado);
Rem                           parallel_level=1 si la tabla tiene trigger de UPDATE (deadlock GES);
Rem                           ORA-06502 (-20321) distinto del fallo genérico (-20320) en chunks
Rem    epurisaca    09/21/26 - Recuperación tras caída de sesión (ORA-03113): reanudación selectiva
Rem                           validada sobre columnas ya confirmadas
Rem    epurisaca    09/22/26 - El marcador de reanudación de proc_dm_mask_cat filtra por ejecucion_id
Rem                           (antes solicitud_id): evita doble enmascarado en reanudaciones seguidas
Rem    epurisaca    09/23/26 - proc_dm_ejecuta_update_seguro: chunking por bloques con tamaño adaptativo
Rem                           y job_class opcional (JC_DATAMASKING) para afinidad RAC
Rem    epurisaca    09/27/26 - Fallo parcial de chunks: reintento en serie acotado a los rowid fallidos;
Rem                           ORA-00001 y ORA-12899 en chunks se propagan (-20322/-20323) para activar
Rem                           la auto-exclusión; proc_dm_enmascara_tabla con guarda de concurrencia y
Rem                           proc_dm_pre_dep con p_tablas_csv; autocancelación de huérfanas en
Rem                           pkg_dm_trazabilidad; autopurga del pepper en FINALIZADO y guarda de estado
Rem                           en proc_dm_pepper_purgar (ORA-20099/ORA-20100); FORCE "vivo" igual que
Rem                           EXCLUDE en proc_dm_mask_cat
Rem    epurisaca    09/28/26 - ORA-07445 [qctcopn_internal] en 19c con la CTE "objetivo" de
Rem                           proc_dm_mask_cat: se añade /*+ MATERIALIZE */ en sus tres usos
Rem    epurisaca    10/03/26 - Nombre de tarea DBMS_PARALLEL_EXECUTE determinista (hash de
Rem                           owner.tabla.columna) y CREATE_TASK falla cerrado (ORA-20330) si ya hay una
Rem                           tarea huérfana de esa columna: evita reenmascarar con FF1 lo ya hecho
Rem    epurisaca    10/04/26 - proc_dm_cancelar informa el resultado real; proc_dm_reanudar comprueba que
Rem                           la sesión original no siga viva (ORA-20017)
Rem    epurisaca    10/06/26 - proc_dm_reanudar rechaza ejecuciones que no están en fase ENMASCARAMIENTO
Rem    epurisaca    10/07/26 - Preflight de tareas huérfanas (ORA-20331); las columnas fallidas no cuentan
Rem                           como procesadas; proc_dm_upd_sol antepone 'Reanudacion: n | ' al detalle
Rem    epurisaca    10/09/26 - proc_dm_gestiona_tareas (INFORMAR / RECONCILIAR / DESCARTAR); ORA-20350
Rem                           indica la concesión que falta; una columna FORCE más corta que el mínimo del
Rem                           identificador conserva su FORCE y traza WARN SKIP_AUTO_LEN; la llamada a
Rem                           func_dm_espec_doc_segun_tipo usa un nombre de 30 caracteres (PLS-00114 en 11g)
Rem    epurisaca    10/10/26 - Modularización: preflight y post-check pasan a pkg_dm_mask_worker y
Rem                           pkg_dm_mask_dependencias; el bucle por columna a pkg_dm_mask_columna;
Rem                           desaparecen g_ruta, g_ejec_actual y g_resume_base_solicitud (la solicitud
Rem                           previa viaja en p_base_solicitud_id); func_dm_tareas_de_ejecucion;
Rem                           MASK/RESUMEN incluye las columnas omitidas
Rem    epurisaca    10/11/26 - Reclamo atómico de la ejecución antes de modificar estado; alcance del
Rem                           enmascarado alineado con el del descubrimiento; la sincronización de
Rem                           relaciones cuenta sus fallos como errores de la corrida
Rem    epurisaca    10/12/26 - proc_dm_resumen_no_mask: al cierre deja una linea WARN NO_ENMASCARADA por
Rem                           columna sin enmascarar (omitidas, auto-exclusiones y heredadas); solo informa
Rem    epurisaca    10/12/26 - Alcance por identificador en TDM_EJECUCION.MASK_IDENTIFICADOR (se elimina
Rem                           TDM_MASK_ALCANCE_ID); TDM_MASK_SOLICITUD.alcance_tipo (ID, SET, COMPLETO)
Rem    epurisaca    10/12/26 - Se retiran proc_dm_enmascara_tabla (el flujo es descubrir con dm_descubre_set y
Rem                           enmascarar con dm_enmascara) y el reenvio func_dm_norm; se quita APPLY_COL_COLLISION
create or replace PACKAGE pkg_dm_enmascarar AS

  PROCEDURE proc_dm_enmascaramiento(
    p_ejecucion_id IN NUMBER,
    p_reproceso    IN VARCHAR2 DEFAULT 'N',
    p_commit_lote  IN NUMBER DEFAULT 1000
  );

  PROCEDURE proc_dm_cancelar(
    p_ejecucion_id IN NUMBER
  );

  -- Diagnostica y gestiona las tareas DBMS_PARALLEL_EXECUTE (TDM_<hash>) que una
  -- ejecucion interrumpida deja detras. Es la unica logica de tareas huerfanas del
  -- motor: la usan dm_monitor (INFORMAR), dm_enmascara_reanudar (RECONCILIAR) y
  -- dm_enmascara_cancel (DESCARTAR). NO mata sesiones (eso exige ALTER SYSTEM y lo
  -- hacen los scripts con el privilegio de quien los ejecuta).
  --   INFORMAR    solo lectura: estado de la ejecucion, de cada tarea y desde donde se reanudaria.
  --   RECONCILIAR termina las tareas recuperables con RESUME_TASK (force si estan en
  --               PROCESSING), registra cada columna como hecha (APPLY_COL) y borra la
  --               tarea. Se niega (ORA-20342) si la sesion principal sigue viva y falla
  --               (ORA-20343) si alguna tarea no se pudo resolver.
  --   DESCARTAR   borra las tareas de la ejecucion SIN reanudarlas (anulacion total).
  PROCEDURE proc_dm_gestiona_tareas(
    p_ejecucion_id IN NUMBER,
    p_modo         IN VARCHAR2 DEFAULT 'INFORMAR'
  );

  -- func_dm_tareas_de_ejecucion: nombres (separados por coma, orden alfabetico) de las tareas
  --   DBMS_PARALLEL_EXECUTE (TDM_<hash>) de este esquema cuyo SQL de chunk lleva
  --   proc_dm_set_ejecucion(<p_ejecucion_id>). NULL si no hay ninguna. Solo lectura.
  FUNCTION func_dm_tareas_de_ejecucion(
    p_ejecucion_id IN NUMBER
  ) RETURN VARCHAR2;

  PROCEDURE proc_dm_reanudar(
    p_ejecucion_id IN NUMBER,
    p_commit_lote  IN NUMBER DEFAULT 1000
  );

  -- Purga la semilla efimera de la ejecucion. proc_dm_enmascaramiento la autopurga al llegar a FINALIZADO.
  -- p_confirma_abandono='Y' es obligatorio en ERROR/CANCELADO/ABORTADA (podrian reanudarse con el
  -- mismo pepper); sobre una ejecucion EJECUTANDO esta bloqueado siempre.
  PROCEDURE proc_dm_pepper_purgar(
    p_ejecucion_id      IN NUMBER,
    p_confirma_abandono IN VARCHAR2 DEFAULT 'N'
  );

  -- Seleccion de columnas por identificador (reenvio a pkg_dm_mask_estado; lo usa dm_enmascara_id.sql).
  PROCEDURE proc_dm_registra_alcance_id(
    p_ejecucion_id  IN  NUMBER,
    p_identificador IN  VARCHAR2,
    o_columnas      OUT NUMBER
  );

  PROCEDURE proc_dm_limpia_alcance_id(p_ejecucion_id IN NUMBER);

END pkg_dm_enmascarar;
/

create or replace PACKAGE BODY pkg_dm_enmascarar AS


  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_mask_cat
  -- PROPOSITO    : Recorre las columnas pendientes (clasificadas Y mas FORCE vivos, menos EXCLUDE y las ya
  --                confirmadas) llamando a proc_dm_apl_col y actualizando el progreso.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_esquema, p_reproceso, p_base_solicitud_id;
  --                OUT p_error_count (columnas fallidas).
  -- LEE          : TDM_COLUMNA_FINAL; TDM_EXCEPCION_COL; DBA_TAB_COLUMNS; TDM_MASK_TRACE (APPLY_COL*)
  -- ESCRIBE      : TDM_MASK_SOLICITUD (contadores); TDM_EJECUCION (latido, progreso, FINALIZADO en NOOP);
  --                TDM_MASK_TRACE (RESUMEN, NOOP, SKIP_TABLE)
  -- ERRORES      : Propaga ORA-20081 (cancelacion). El error de una columna se registra (MASK_APPLY), se
  --                cuenta en p_error_count y no avanza el progreso.
  -- LLAMADO DESDE: proc_dm_enmascaramiento_core.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_mask_cat(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_reproceso    IN VARCHAR2 DEFAULT 'N',
    p_base_solicitud_id IN NUMBER DEFAULT NULL,   -- solicitud previa si es reanudacion
    p_error_count  OUT NUMBER
  ) IS
    l_total_cols NUMBER;
    l_total_tabs NUMBER;
    l_av         pkg_dm_mask_columna.t_dm_avance;
    l_esquema    VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_reproceso  VARCHAR2(1) := UPPER(TRIM(NVL(p_reproceso,'N')));
    l_msg_noop   VARCHAR2(1900);
    l_total_rows NUMBER := 0;
    l_omitidas   NUMBER := 0;   -- columnas sensibles omitidas por longitud (SKIP_AUTO_LEN)
    l_has_final  NUMBER := 0;
  BEGIN
    p_error_count := 0;

    pkg_dm_mask_columna.proc_dm_cuenta_pendientes(p_ejecucion_id, l_esquema, l_reproceso, l_has_final, l_total_cols, l_total_tabs);
    l_av.total_cols := l_total_cols;
    l_av.total_tabs := l_total_tabs;

    -- Reanudacion visible: una linea en la traza (ligada a la NUEVA solicitud) y la marca en
    -- TDM_EJECUCION (ultimo_paso y detalle), con cuantas columnas se omiten y cuantas quedan.
    IF p_base_solicitud_id IS NOT NULL THEN
      DECLARE
        l_reint NUMBER;
        l_conf  NUMBER;
        l_txt   VARCHAR2(400);
      BEGIN
        SELECT reintento_nro INTO l_reint FROM tdm_mask_solicitud WHERE solicitud_id = p_solicitud_id;
        SELECT COUNT(DISTINCT REGEXP_SUBSTR(t.detalle,'^[^ ]+'))
          INTO l_conf
          FROM tdm_mask_trace t
         WHERE t.ejecucion_id = p_ejecucion_id
           AND t.fase = 'MASK'
           AND t.paso IN ('APPLY_COL','APPLY_COL_SAFE_FALLBACK');
        l_txt := 'Reanudacion '||TO_CHAR(l_reint-1)||' (intento '||TO_CHAR(l_reint)||', solicitud_id='||
                 TO_CHAR(p_solicitud_id)||' desde solicitud_id='||TO_CHAR(p_base_solicitud_id)||
                 '): columnas ya confirmadas='||TO_CHAR(l_conf)||', pendientes='||TO_CHAR(l_total_cols);
        pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'ENMASCARAMIENTO','REANUDACION',l_txt);
        pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'REANUDACION',l_txt);
      EXCEPTION
        WHEN OTHERS THEN NULL;   -- la marca es informativa: nunca debe frenar la reanudacion
      END;
    END IF;

    IF NVL(l_total_cols,0) = 0 THEN
      IF l_reproceso = 'Y' THEN
        l_msg_noop := 'No hay columnas configuradas/pendientes para enmascarar en reproceso completo.';
      ELSE
        l_msg_noop := 'No hay columnas pendientes por enmascarar para esta ejecución. '||
                      'Si deseas reproceso completo, ejecuta proc_dm_enmascaramiento('||TO_CHAR(p_ejecucion_id)||',''Y'').';
      END IF;

      pkg_dm_trazabilidad.proc_dm_trace(
        p_solicitud_id,
        p_ejecucion_id,
        'MASK',
        'NOOP',
        l_msg_noop
      );
      pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','FINALIZADO',100,0,0,0,0,NULL,'NOOP_MASK');
      -- Sin pendientes en la seleccion por identificador: la corrida esta completa, se vacia (ver FIN OK).
      BEGIN
        UPDATE tdm_ejecucion SET mask_identificador = NULL WHERE ejecucion_id = p_ejecucion_id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
      RETURN;
    END IF;

    IF l_has_final = 1 THEN
      pkg_dm_mask_columna.proc_dm_traza_tablas_omitidas(p_solicitud_id, p_ejecucion_id, l_esquema);
    END IF;

    pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',0,l_total_tabs,0,l_total_cols,0,NULL,'INICIO_MASK');

    IF l_has_final = 1 THEN
      -- Objetivo = columnas aprobadas en el descubrimiento mas FORCE vivos, igual que las consultas anteriores.
      FOR rc IN (
        -- MATERIALIZE evita el ORA-07445 [qctcopn_internal] del optimizador de 19c con esta CTE.
        WITH objetivo AS (
          SELECT /*+ MATERIALIZE */ ora_owner, table_name, column_name,
                 MAX(identificador) KEEP (DENSE_RANK FIRST ORDER BY origen) AS identificador
            FROM (
              SELECT f.ora_owner, f.table_name, f.column_name, f.identificador, 2 AS origen
                FROM tdm_columna_final f
               WHERE f.ora_owner = l_esquema
                 AND f.enmascarar = 'Y'
              UNION ALL
              SELECT pkg_dm_sql_seguro.func_dm_norm(e.ora_owner), pkg_dm_sql_seguro.func_dm_norm(e.table_name), pkg_dm_sql_seguro.func_dm_norm(e.column_name), e.identificador_forz, 1 AS origen
                FROM tdm_excepcion_col e
               WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = l_esquema
                 AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
                 AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'FORCE'
                 AND e.identificador_forz IS NOT NULL
                 AND EXISTS (
                       SELECT 1 FROM dba_tab_columns c
                        WHERE c.owner = pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)
                          AND c.table_name = pkg_dm_sql_seguro.func_dm_norm(e.table_name)
                          AND c.column_name = pkg_dm_sql_seguro.func_dm_norm(e.column_name)
                     )
            )
           GROUP BY ora_owner, table_name, column_name
        )
        SELECT ora_owner, table_name, column_name, identificador
          FROM objetivo f
         WHERE pkg_dm_mask_estado.func_dm_en_alcance(p_ejecucion_id, f.ora_owner, f.table_name, f.column_name) = 1   -- solo lo que esta dentro del alcance
           AND (
             l_reproceso = 'Y' OR
             NOT EXISTS (
               SELECT 1 FROM tdm_mask_trace t
                WHERE (
                        -- por ejecucion (no por solicitud): una segunda reanudacion no repite columnas
                        t.ejecucion_id = p_ejecucion_id
                      )
                  AND t.fase = 'MASK'
                  AND t.paso IN ('APPLY_COL','APPLY_COL_SAFE_FALLBACK','SKIP_AUTO_LEN')   -- SKIP_AUTO_LEN: omitida con aviso = resuelta
                  AND (t.detalle LIKE REPLACE(REPLACE(f.ora_owner||'.'||f.table_name||'.'||f.column_name,'_','\_'),'%','\%')||' filas=%' ESCAPE '\'   -- '_' y '%' del nombre se escapan para el LIKE
                       OR t.detalle LIKE REPLACE(REPLACE(f.ora_owner||'.'||f.table_name||'.'||f.column_name,'_','\_'),'%','\%')||' SIN ENMASCARAR%' ESCAPE '\')
             )
           )
           AND NOT EXISTS (
             SELECT 1 FROM tdm_excepcion_col e
              WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = f.ora_owner
                AND e.table_name = f.table_name
                AND e.column_name = f.column_name
                AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
                AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'EXCLUDE'
           )
         ORDER BY ora_owner, table_name, column_name
      ) LOOP
        pkg_dm_mask_columna.proc_dm_mask_una_col(p_solicitud_id, p_ejecucion_id, p_esquema,
          rc.ora_owner, rc.table_name, rc.column_name, rc.identificador, l_av);
      END LOOP;
    ELSE
      FOR rc IN (
        SELECT pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) as ora_owner, pkg_dm_sql_seguro.func_dm_norm(e.table_name) as table_name,
               pkg_dm_sql_seguro.func_dm_norm(e.column_name) as column_name, e.identificador_forz as identificador
          FROM tdm_excepcion_col e
         WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = l_esquema
           AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
           AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'FORCE'
           AND e.identificador_forz IS NOT NULL
           AND pkg_dm_mask_estado.func_dm_en_alcance(p_ejecucion_id, l_esquema, pkg_dm_sql_seguro.func_dm_norm(e.table_name), pkg_dm_sql_seguro.func_dm_norm(e.column_name)) = 1   -- solo lo que esta dentro del alcance
           AND (
             l_reproceso = 'Y' OR
             NOT EXISTS (
               SELECT 1 FROM tdm_mask_trace t
                WHERE (
                        -- por ejecucion (no por solicitud): una segunda reanudacion no repite columnas
                        t.ejecucion_id = p_ejecucion_id
                      )
                  AND t.fase = 'MASK'
                  AND t.paso IN ('APPLY_COL','APPLY_COL_SAFE_FALLBACK','SKIP_AUTO_LEN')   -- SKIP_AUTO_LEN: omitida con aviso = resuelta
                  AND (t.detalle LIKE REPLACE(REPLACE(pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.table_name)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.column_name),'_','\_'),'%','\%')||' filas=%' ESCAPE '\'   -- '_' y '%' del nombre se escapan para el LIKE
                       OR t.detalle LIKE REPLACE(REPLACE(pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.table_name)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.column_name),'_','\_'),'%','\%')||' SIN ENMASCARAR%' ESCAPE '\')
             )
           )
           AND EXISTS (
             SELECT 1 FROM dba_tab_columns c
              WHERE c.owner = pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)
                AND c.table_name = pkg_dm_sql_seguro.func_dm_norm(e.table_name)
                AND c.column_name = pkg_dm_sql_seguro.func_dm_norm(e.column_name)
           )
         ORDER BY ora_owner, table_name, column_name
      ) LOOP
        pkg_dm_mask_columna.proc_dm_mask_una_col(p_solicitud_id, p_ejecucion_id, p_esquema,
          rc.ora_owner, rc.table_name, rc.column_name, rc.identificador, l_av);
      END LOOP;
    END IF;

    p_error_count := l_av.errores;

    BEGIN
      SELECT NVL(SUM(TO_NUMBER(REGEXP_SUBSTR(t.detalle,'filas=([0-9]+)',1,1,NULL,1))),0)
        INTO l_total_rows
        FROM tdm_mask_trace t
       WHERE t.solicitud_id = p_solicitud_id
         AND t.fase = 'MASK'
         AND t.paso IN ('APPLY_COL','APPLY_COL_SAFE_FALLBACK')
         AND REGEXP_LIKE(t.detalle,'filas=[0-9]+');
    EXCEPTION
      WHEN OTHERS THEN
        l_total_rows := 0;
    END;

    -- Columnas omitidas: apl_col las cuenta como procesadas pero NO las enmascara (columna mas corta
    -- que el minimo del identificador, WARN SKIP_AUTO_LEN). Se cuentan por ejecucion en la traza
    -- para que sumen tambien tras una reanudacion (que abre otra solicitud).
    BEGIN
      SELECT COUNT(*) INTO l_omitidas
        FROM tdm_mask_trace t
       WHERE t.ejecucion_id = p_ejecucion_id
         AND t.fase = 'MASK'
         AND t.paso = 'SKIP_AUTO_LEN';
    EXCEPTION
      WHEN OTHERS THEN
        l_omitidas := 0;
    END;

    pkg_dm_trazabilidad.proc_dm_trace(
      p_solicitud_id,
      p_ejecucion_id,
      'MASK',
      'RESUMEN',
      'Columnas procesadas='||TO_CHAR(l_av.proc_cols)||
      ', columnas omitidas='||TO_CHAR(l_omitidas)||' (SKIP_AUTO_LEN: sin enmascarar, ver WARN)'||
      ', columnas fallidas='||TO_CHAR(l_av.cols_fallidas)||
      ', tablas procesadas='||TO_CHAR(l_av.proc_tabs)||
      ', total_registros_afectados='||TO_CHAR(NVL(l_total_rows,0))
    );

    BEGIN
      UPDATE tdm_mask_solicitud
         SET filas_procesadas     = NVL(l_total_rows,0),
             tablas_procesadas    = l_av.proc_tabs,
             columnas_procesadas  = l_av.proc_cols
       WHERE solicitud_id = p_solicitud_id;
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN NULL;
    END;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_resumen_no_mask  (privado)
  -- PROPOSITO    : Dejar en la traza, al cierre, UNA linea WARN NO_ENMASCARADA por cada columna que queda sin
  --                enmascarar por cualquier motivo, para decidir sin detener una corrida larga. Solo informa:
  --                no cambia estados ni bloquea.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_esquema.
  -- LEE          : TDM_MASK_TRACE (SKIP_AUTO_LEN, SKIP_ORA00001/12899/06502); TDM_EXCEPCION_COL (EXCLUDE
  --                automaticas vivas del esquema, heredadas de corridas anteriores).
  -- ESCRIBE      : TDM_MASK_TRACE (NO_ENMASCARADA y una linea de total).
  -- ERRORES      : Ninguno; cualquier fallo se ignora (es informativo). Tope 500 lineas + total.
  -- LLAMADO DESDE: proc_dm_enmascaramiento_core, antes del cierre.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_resumen_no_mask(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  ) IS
    l_n NUMBER := 0;
  BEGIN
    -- 1) Sin enmascarar en ESTA ejecucion (el detalle SKIP_* empieza por OWNER.TABLA.COLUMNA).
    FOR r IN (
      SELECT t.paso, t.detalle
        FROM tdm_mask_trace t
       WHERE t.ejecucion_id = p_ejecucion_id
         AND t.fase = 'MASK'
         AND t.paso IN ('SKIP_AUTO_LEN','SKIP_ORA00001','SKIP_ORA12899','SKIP_ORA06502')
       ORDER BY t.trace_id
    ) LOOP
      l_n := l_n + 1;
      IF l_n <= 500 THEN
        pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','NO_ENMASCARADA',
          SUBSTR(r.detalle,1,3700)||' [motivo='||r.paso||']');
      END IF;
    END LOOP;
    -- 2) Auto-exclusiones persistidas por corridas anteriores que siguen vivas y no se repitieron aqui.
    FOR r IN (
      SELECT e.ora_owner, e.table_name, e.column_name, SUBSTR(e.razon,1,300) razon
        FROM tdm_excepcion_col e
       WHERE e.ora_owner = UPPER(TRIM(p_esquema))
         AND e.accion = 'EXCLUDE'
         AND e.activa = 'Y'
         AND e.razon LIKE 'AUTO-EXCLUDE%'
         AND NOT EXISTS (
               SELECT 1 FROM tdm_mask_trace t
                WHERE t.ejecucion_id = p_ejecucion_id
                  AND t.fase = 'MASK'
                  AND t.paso IN ('SKIP_AUTO_LEN','SKIP_ORA00001','SKIP_ORA12899','SKIP_ORA06502')
                  AND INSTR(t.detalle, e.ora_owner||'.'||e.table_name||'.'||e.column_name||' ') = 1)
       ORDER BY e.table_name, e.column_name
    ) LOOP
      l_n := l_n + 1;
      IF l_n <= 500 THEN
        pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','NO_ENMASCARADA',
          r.ora_owner||'.'||r.table_name||'.'||r.column_name||' SIN ENMASCARAR [motivo=AUTO-EXCLUDE heredada: '||r.razon||']');
      END IF;
    END LOOP;
    IF l_n > 0 THEN
      pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','NO_ENMASCARADA',
        'TOTAL columnas sin enmascarar='||l_n||CASE WHEN l_n > 500 THEN ' (solo se detallan 500)' END||
        '. Consulta: select detalle from tdm_mask_trace where ejecucion_id='||p_ejecucion_id||' and paso=''NO_ENMASCARADA''');
    END IF;
  EXCEPTION
    WHEN OTHERS THEN NULL;   -- informativo: nunca debe tumbar el cierre
  END proc_dm_resumen_no_mask;

  ------------------------------------------------------------------------------
  -- Públicos del spec
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_enmascaramiento_core  (privado)
  -- PROPOSITO    : Orquesta el enmascarado de un esquema: preflight de tareas huerfanas, desactivacion de
  --                dependencias, pepper, columnas, sincronizacion, rehabilitacion, recompilacion y cierre.
  -- ENTRADAS     : p_ejecucion_id; p_reproceso (Y reprocesa todo); p_commit_lote (sin uso);
  --                p_base_solicitud_id (solicitud previa, solo en una reanudacion).
  -- LEE/ESCRIBE  : TDM_EJECUCION, TDM_MASK_SOLICITUD, TDM_MASK_TRACE, TDM_EJECUCION_ERROR, TDM_MASK_DEP_ESTADO,
  --                TDM_SECRETO; datos del esquema (via sub-rutinas); ALTER ... COMPILE de objetos invalidos.
  -- ERRORES      : ORA-20097/20098 concurrencia; ORA-20014 reingreso sin reproceso; ORA-20331 tareas huerfanas;
  --                ORA-20050..20056 y fallos de pepper o dominios (solicitud y ejecucion quedan en ERROR).
  --                El ORA-20203 de POST_CHECK se registra, no se levanta.
  -- LLAMADO DESDE: proc_dm_enmascaramiento (arranque) y proc_dm_reanudar.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_enmascaramiento_core(
    p_ejecucion_id IN NUMBER,
    p_reproceso    IN VARCHAR2 DEFAULT 'N',
    p_commit_lote  IN NUMBER DEFAULT 1000,
    p_base_solicitud_id IN NUMBER DEFAULT NULL    -- solicitud previa si es reanudacion
  ) IS
    l_solicitud_id NUMBER;
    l_esquema      VARCHAR2(128);
    l_alcance      VARCHAR2(600);
    l_alc_tipo     VARCHAR2(10);
    l_alc_det      VARCHAR2(500);
    l_n_alc        NUMBER;
    l_err          VARCHAR2(1900 CHAR);
    l_err_code     NUMBER;
    l_err_stack    VARCHAR2(1900 CHAR);
    l_err_bt       VARCHAR2(1900 CHAR);
    l_err_call     VARCHAR2(1900 CHAR);
    l_reproceso    VARCHAR2(1) := UPPER(TRIM(NVL(p_reproceso,'N')));
    l_mask_errors  NUMBER := 0;
    l_invalidos_pre NUMBER := 0;
    l_reclamada    BOOLEAN := FALSE;  -- TRUE solo cuando esta llamada reclamo la ejecucion
    l_sync_err     NUMBER := 0;       -- relaciones de sync con fallo o diferencias
    l_omitidas_fin NUMBER := 0;       -- columnas SKIP_AUTO_LEN de la corrida (aviso en el cierre)
  BEGIN
    pkg_dm_mask_validacion.proc_dm_validar_base;
    DBMS_APPLICATION_INFO.SET_MODULE('PKG_DM_ENMASCARAR','P_DM_ENMASCARA');
    -- El estado se modifica solo tras reclamar la ejecucion: una segunda llamada rechazada no debe alterar la viva.

    l_esquema := pkg_dm_mask_estado.func_dm_esquema(p_ejecucion_id);

    -- Capturar conteo baseline de objetos inválidos del esquema
    BEGIN
      SELECT COUNT(*)
        INTO l_invalidos_pre
        FROM dba_objects
       WHERE owner = l_esquema
         AND status = 'INVALID';
    EXCEPTION
      WHEN OTHERS THEN
        l_invalidos_pre := 0;
    END;
    -- Reingreso: una ejecucion FINALIZADA solo se rechaza si NO quedan columnas pendientes. Con
    -- pendientes (p. ej. tras un enmascarado por identificador) el default continua con el resto y
    -- salta lo ya confirmado; Y sigue siendo el unico modo de rehacer todo.
    DECLARE
      l_hf NUMBER; l_tc NUMBER; l_tt NUMBER;
    BEGIN
      l_tc := 0;
      IF l_reproceso <> 'Y' THEN
        pkg_dm_mask_columna.proc_dm_cuenta_pendientes(p_ejecucion_id, l_esquema, 'N', l_hf, l_tc, l_tt);
      END IF;
      IF NVL(l_tc,0) = 0 THEN
        pkg_dm_mask_validacion.proc_dm_validar_reingreso_mask(p_ejecucion_id,l_esquema,l_reproceso);
      END IF;
    END;
    pkg_dm_mask_validacion.proc_dm_validar_concurrencia(p_ejecucion_id,l_esquema);

    -- Reclamo de ejecución para evitar doble arranque en paralelo
    -- sobre el mismo ejecucion_id.
    BEGIN
       -- Reclamo de ejecución para evitar doble arranque en paralelo
       -- sobre el mismo ejecucion_id y sobre el mismo esquema.
       UPDATE tdm_ejecucion
          SET fase_proceso = 'ENMASCARAMIENTO',
              estado       = 'EJECUTANDO',
              fecha_inicio = SYSTIMESTAMP,
              fecha_fin    = NULL,
              ultimo_objeto = l_esquema,
              ultimo_paso   = 'INICIO',
              heartbeat_ts = SYSTIMESTAMP
        WHERE ejecucion_id = p_ejecucion_id
          AND NOT (
            UPPER(TRIM(NVL(fase_proceso,'?'))) = 'ENMASCARAMIENTO' AND
            UPPER(TRIM(NVL(estado,'?'))) = 'EJECUTANDO'
          );
     EXCEPTION
       WHEN DUP_VAL_ON_INDEX THEN
         RAISE_APPLICATION_ERROR(
           -20098,
           'ERROR CONCURRENCIA: Ya existe otra ejecución en estado EJECUTANDO para el esquema '||l_esquema||
           '. No se permite la ejecución concurrente sobre el mismo esquema.'
         );
     END;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(
        -20097,
        'Ya existe una ejecución ENMASCARAMIENTO en estado EJECUTANDO para ejecucion_id='||p_ejecucion_id||
        '. No se permite ejecución paralela.'
      );
    END IF;
    COMMIT;
    l_reclamada := TRUE;   -- a partir de aqui ESTA llamada es la propietaria de la ejecucion

    pkg_dm_mask_estado.proc_dm_close_sol_open(p_ejecucion_id);
    pkg_dm_trazabilidad.proc_dm_refresca_sesion(p_ejecucion_id);

    -- forzar_full se normaliza por fase ENMASCARAMIENTO:
    --   - 'Y' sólo cuando el llamado actual solicita reproceso completo.
    --   - 'N' en el resto de casos, evitando arrastre de forzado desde DESCUBRIMIENTO.
    BEGIN
      UPDATE tdm_ejecucion
         SET forzar_full = CASE WHEN l_reproceso = 'Y' THEN 'Y' ELSE 'N' END,
             cancel_requested = 'N',
             heartbeat_ts = SYSTIMESTAMP
       WHERE ejecucion_id = p_ejecucion_id;
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;

    -- El detalle distingue una reanudacion (p_base_solicitud_id) de un arranque normal.
    l_solicitud_id := pkg_dm_mask_estado.func_dm_crea_sol(
      p_ejecucion_id      => p_ejecucion_id,
      p_esquema           => l_esquema,
      p_detalle           => CASE
                                WHEN p_base_solicitud_id IS NOT NULL THEN
                                  'Reanudacion de ejecucion_id='||p_ejecucion_id||
                                  ' desde solicitud_id='||TO_CHAR(p_base_solicitud_id)
                                ELSE
                                  'Enmascaramiento final'
                              END,
      p_forzar_reproceso  => l_reproceso
    );
    -- Sesion Oracle y cancelacion de la corrida viven solo en TDM_EJECUCION
    -- (proc_dm_refresca_sesion y el reset de cancel_requested al arrancar).

    -- Alcance de la corrida: ID (por identificador), SET (grupo de tablas) o COMPLETO. Queda en la traza INICIO
    -- y en TDM_MASK_SOLICITUD.alcance_tipo; el identificador de TDM_EJECUCION se vacia al terminar.
    BEGIN
      SELECT e.mask_identificador INTO l_alc_det FROM tdm_ejecucion e WHERE e.ejecucion_id = p_ejecucion_id;
      IF l_alc_det IS NOT NULL THEN
        l_alc_det  := l_alc_det||' ('||pkg_dm_mask_estado.func_dm_cuenta_cols_id(p_ejecucion_id, l_alc_det)||' columnas)';
        l_alc_tipo := 'ID';
        l_alcance  := 'POR IDENTIFICADOR '||l_alc_det;
      ELSE
        SELECT COUNT(DISTINCT table_name) INTO l_n_alc FROM tdm_ejecucion_scope
         WHERE ejecucion_id = p_ejecucion_id AND table_name <> '*';
        IF l_n_alc > 0 THEN
          l_alc_tipo := 'SET';
          l_alc_det  := l_n_alc||' tablas (definidas en el descubrimiento)';
          l_alcance  := 'SET DE TABLAS ('||l_alc_det||')';
        ELSE
          l_alc_tipo := 'COMPLETO';
          l_alcance  := 'ESQUEMA COMPLETO';
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      l_alc_tipo := NULL;
      l_alcance  := 'NO DETERMINADO';
    END;
    IF l_alc_tipo IS NOT NULL THEN
      BEGIN
        UPDATE tdm_mask_solicitud
           SET alcance_tipo = l_alc_tipo
         WHERE solicitud_id = l_solicitud_id;
        COMMIT;
      EXCEPTION WHEN OTHERS THEN
        pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,p_ejecucion_id,'ENMASCARAMIENTO','ALCANCE_ERR',
          'No se pudo registrar el alcance en TDM_MASK_SOLICITUD: '||SQLERRM);
      END;
    END IF;

    pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,p_ejecucion_id,'ENMASCARAMIENTO','INICIO',
      'Esquema='||l_esquema||' - ALCANCE: '||l_alcance||' - reproceso='||l_reproceso||
      CASE WHEN p_base_solicitud_id IS NOT NULL
           THEN ' - REANUDACION desde solicitud_id='||TO_CHAR(p_base_solicitud_id) END);
    -- La ejecucion indica desde el inicio si es una reanudacion; proc_dm_mask_cat completa el detalle despues.
    pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',0,NULL,NULL,NULL,NULL,l_esquema,
      CASE WHEN p_base_solicitud_id IS NOT NULL THEN 'REANUDACION' ELSE 'INICIO' END,
      CASE WHEN p_base_solicitud_id IS NOT NULL
           THEN 'Reanudacion en curso (solicitud_id='||TO_CHAR(l_solicitud_id)||' desde solicitud_id='||
                TO_CHAR(p_base_solicitud_id)||'): calculando columnas pendientes'
           ELSE 'Enmascaramiento en curso (solicitud_id='||TO_CHAR(l_solicitud_id)||') - alcance: '||l_alcance
      END);

    -- Las columnas sin transformador para su tipo se rechazan antes de PRE y de tocar datos.
    pkg_dm_mask_columna.proc_dm_preflight_tipos(p_ejecucion_id, l_esquema);

    -- Preflight de tareas huerfanas (pkg_dm_mask_worker).
    pkg_dm_mask_worker.proc_dm_preflight_tareas(l_solicitud_id, p_ejecucion_id, l_esquema, l_reproceso);

    pkg_dm_mask_dependencias.proc_dm_pre_dep(l_solicitud_id,p_ejecucion_id,l_esquema);

    -- re-propaga los dominios referenciales antes de enmascarar. Falla cerrado: sin dominios FK
    -- consistentes no se continua.
    BEGIN
      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_START', 'Recalculando dominios FK con la validacion del cliente');
      pkg_dm_dominios.proc_dm_propaga_dominios(l_esquema, l_solicitud_id, p_ejecucion_id);
      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_END', 'Dominios FK propagados con exito');
    EXCEPTION
      WHEN OTHERS THEN
        pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_ERR', 'Error en propagacion referencial: '||SQLERRM);
        RAISE;   -- sin propagacion valida no se puede garantizar la integridad FK
    END;

    -- Generar la semilla efimera (pepper) ANTES de enmascarar. Idempotente y con
    -- COMMIT propio para que las sesiones paralelas lean la misma clave AES (FF1).
    BEGIN
      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PEPPER_START', 'Preparando semilla efimera.');
      pkg_dm_pepper.proc_dm_pepper_generar(p_ejecucion_id);
      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PEPPER_END', 'Semilla efimera lista.');
    EXCEPTION
      WHEN OTHERS THEN
        pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PEPPER_ERR', 'Error preparando semilla: '||SQLERRM);
        RAISE;   -- sin pepper no se puede enmascarar de forma segura
    END;

    BEGIN
      proc_dm_mask_cat(l_solicitud_id,p_ejecucion_id,l_esquema,l_reproceso,p_base_solicitud_id,l_mask_errors);
    EXCEPTION
      WHEN OTHERS THEN
        l_mask_errors := l_mask_errors + 1;
        pkg_dm_trazabilidad.proc_dm_log_ejec_error(p_ejecucion_id, l_esquema, NULL, NULL, 'MASK_CAT', SQLCODE, SQLERRM, NULL, l_solicitud_id);
    END;

    BEGIN
      pkg_dm_mask_sync.proc_dm_post_sync(l_solicitud_id,p_ejecucion_id,l_esquema,l_sync_err);
      l_mask_errors := l_mask_errors + l_sync_err;   -- una relacion sin sincronizar o con diferencias impide FINALIZADO
    EXCEPTION
      WHEN OTHERS THEN
        l_mask_errors := l_mask_errors + 1;
        pkg_dm_trazabilidad.proc_dm_log_ejec_error(p_ejecucion_id, l_esquema, NULL, NULL, 'POST_SYNC', SQLCODE, SQLERRM, NULL, l_solicitud_id);
    END;

    pkg_dm_mask_dependencias.proc_dm_post_dep(l_solicitud_id,p_ejecucion_id);

    -- control posterior (constraints, recompilacion, INVALID nuevos, PII sin enmascarar)
    pkg_dm_mask_dependencias.proc_dm_post_check(l_solicitud_id, p_ejecucion_id, l_esquema, l_invalidos_pre, l_mask_errors);

    -- Inventario informativo de lo que queda sin enmascarar (no detiene ni cambia el estado).
    proc_dm_resumen_no_mask(l_solicitud_id, p_ejecucion_id, l_esquema);

    IF l_mask_errors > 0 THEN
      pkg_dm_mask_estado.proc_dm_upd_sol(l_solicitud_id,'ERROR','FIN','ERROR','Proceso finalizado con '||l_mask_errors||' errores','Y');
      pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','ERROR',100,NULL,NULL,NULL,NULL,NULL,'CON_ERRORES');
      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','ERROR','Enmascaramiento finalizado con '||l_mask_errors||' errores');
    ELSE
      -- Las columnas que no caben en el formato (SKIP_AUTO_LEN) no detienen la corrida: se declaran en el cierre.
      BEGIN
        SELECT COUNT(*) INTO l_omitidas_fin
          FROM tdm_mask_trace t
         WHERE t.ejecucion_id = p_ejecucion_id
           AND t.fase = 'MASK'
           AND t.paso = 'SKIP_AUTO_LEN';
      EXCEPTION
        WHEN OTHERS THEN l_omitidas_fin := 0;
      END;
      pkg_dm_mask_estado.proc_dm_upd_sol(l_solicitud_id,'FINALIZADO','FIN','FINALIZADO',
        'Proceso finalizado correctamente'||CASE WHEN l_omitidas_fin > 0 THEN ' CON AVISOS: '||l_omitidas_fin||' columna(s) sin enmascarar (ver WARN SKIP_AUTO_LEN)' END,'Y');
      pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','FINALIZADO',100,NULL,NULL,NULL,NULL,NULL,'FINALIZADO',
        'Enmascaramiento finalizado'||CASE WHEN l_omitidas_fin > 0 THEN ' CON AVISOS: '||l_omitidas_fin||' columna(s) sin enmascarar' END);   -- antes quedaba "en curso"
      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','OK',
        'Enmascaramiento finalizado'||CASE WHEN l_omitidas_fin > 0 THEN ' CON AVISOS: '||l_omitidas_fin||' columna(s) sin enmascarar (SKIP_AUTO_LEN)' END);
      -- El identificador de la corrida (TDM_EJECUCION.MASK_IDENTIFICADOR) solo vale mientras la corrida esta en curso o
      -- interrumpida; al terminar FINALIZADO se vacia (el modo queda en TDM_MASK_SOLICITUD y en la traza).
      -- Si falla, no tumba un enmascarado finalizado: dm_enmascara la descarta igualmente al arrancar.
      BEGIN
        UPDATE tdm_ejecucion SET mask_identificador = NULL WHERE ejecucion_id = p_ejecucion_id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;

      -- Autopurga del pepper solo en FINALIZADO sin errores (ver proc_dm_pepper_purgar). Si falla, no tumba la corrida.
      BEGIN
        pkg_dm_pepper.proc_dm_pepper_purgar(p_ejecucion_id);
      EXCEPTION
        WHEN OTHERS THEN
          pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','PEPPER_PURGE_WARN',
            'Enmascaramiento FINALIZADO pero no se pudo autopurgar el pepper: '||SQLERRM||
            ' -- purgar manualmente con proc_dm_pepper_purgar('||p_ejecucion_id||').');
      END;
    END IF;

    DBMS_APPLICATION_INFO.SET_MODULE(NULL,NULL);
  EXCEPTION
    WHEN OTHERS THEN
      l_err_code := SQLCODE;
      l_err_stack := pkg_dm_sql_seguro.func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_STACK);
      l_err_bt    := pkg_dm_sql_seguro.func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      l_err_call  := pkg_dm_sql_seguro.func_dm_safe_err(DBMS_UTILITY.FORMAT_CALL_STACK);
      l_err := '['||TO_CHAR(l_err_code)||'] '||l_err_stack||' | BT='||l_err_bt;
      -- Una llamada que no llego a reclamar la ejecucion (validacion, reingreso o concurrencia rechazadas)
      -- no es duena de su estado: solo repropaga el error.
      IF NOT l_reclamada THEN
        DBMS_APPLICATION_INFO.SET_MODULE(NULL,NULL);
        RAISE;
      END IF;
      BEGIN
        IF l_solicitud_id IS NOT NULL THEN
          pkg_dm_mask_dependencias.proc_dm_post_dep(l_solicitud_id,p_ejecucion_id);
          pkg_dm_mask_estado.proc_dm_upd_sol(l_solicitud_id,
                          CASE WHEN l_err_code = -20081 THEN 'CANCELADO' ELSE 'ERROR' END,
                          'ERROR','ERROR',l_err,'Y');
        END IF;
      EXCEPTION WHEN OTHERS THEN
        -- Si el cierre de estado falla, queda en la traza sin ocultar el error original.
        BEGIN
          pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','ESTADO_FINAL_WARN',
            'No se pudo registrar el estado final tras el error: '||SUBSTR(SQLERRM,1,400));
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
      END;

      pkg_dm_trazabilidad.proc_dm_log_ejec_error(
        p_ejecucion_id => p_ejecucion_id,
        p_owner_name   => l_esquema,
        p_table_name   => NULL,
        p_column_name  => NULL,
        p_etapa        => 'ENMASCARAMIENTO/P_DM_ENMASCARA',
        p_codigo_error => l_err_code,
        p_mensaje      => l_err_stack,
        p_backtrace    => l_err_bt||' | CALL='||l_err_call,
        p_solicitud_id => l_solicitud_id
      );

      pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO',CASE WHEN l_err_code = -20081 THEN 'CANCELADO' ELSE 'ERROR' END,
                       NULL,NULL,NULL,NULL,NULL,NULL,'ERROR');
      BEGIN
        UPDATE tdm_mask_solicitud
           SET filas_error = NVL(filas_error,0) + 1
         WHERE solicitud_id = l_solicitud_id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
      DBMS_APPLICATION_INFO.SET_MODULE(NULL,NULL);
      RAISE;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_enmascaramiento  (publico)
  -- PROPOSITO    : Punto de entrada del enmascarado; delega en proc_dm_enmascaramiento_core (arranque normal).
  -- ENTRADAS     : las del nucleo.
  -- ERRORES      : los del nucleo.
  -- LLAMADO DESDE: dm_enmascara.sql, dm_enmascara_id.sql.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_enmascaramiento(
    p_ejecucion_id IN NUMBER,
    p_reproceso    IN VARCHAR2 DEFAULT 'N',
    p_commit_lote  IN NUMBER DEFAULT 1000
  ) IS
  BEGIN
    proc_dm_enmascaramiento_core(p_ejecucion_id, p_reproceso, p_commit_lote, NULL);
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_cancelar
  -- PROPOSITO    : Solicita la cancelacion cooperativa de una ejecucion en curso (cancel_requested) e
  --                informa el resultado.
  -- ENTRADAS     : p_ejecucion_id.
  -- LEE/ESCRIBE  : TDM_MASK_SOLICITUD (detalle); TDM_EJECUCION (cancel_requested = Y); DBMS_OUTPUT
  -- ERRORES      : No levanta errores; avisa por DBMS_OUTPUT si no habia solicitud abierta.
  -- LLAMADO DESDE: dm_enmascara_cancel.sql.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_cancelar(p_ejecucion_id IN NUMBER) IS
    l_n NUMBER;
  BEGIN
    -- La solicitud de cancelacion vive en TDM_EJECUCION; solo aplica si la corrida
    -- tiene un intento (solicitud) abierto.
    UPDATE tdm_ejecucion e
       SET e.cancel_requested = 'Y'
     WHERE e.ejecucion_id = p_ejecucion_id
       AND EXISTS (SELECT 1 FROM tdm_mask_solicitud s
                    WHERE s.ejecucion_id = e.ejecucion_id
                      AND s.estado IN ('EN_PROCESO','PENDIENTE','REPROCESANDO'));
    l_n := SQL%ROWCOUNT;

    UPDATE tdm_mask_solicitud
       SET detalle = SUBSTR(NVL(detalle,'')||' | Cancelacion solicitada manualmente',1,3900)
     WHERE ejecucion_id = p_ejecucion_id
       AND estado IN ('EN_PROCESO','PENDIENTE','REPROCESANDO');
    COMMIT;

    -- Informa por DBMS_OUTPUT si hubo algo que cancelar. La cancelacion es cooperativa: se detecta entre
    -- columnas y, en una columna grande por DBMS_PARALLEL_EXECUTE, puede tardar varios minutos.
    IF l_n > 0 THEN
      DBMS_OUTPUT.PUT_LINE('Cancelacion solicitada para ejecucion_id='||p_ejecucion_id||
                           ' (TDM_EJECUCION.cancel_requested=Y).');
      DBMS_OUTPUT.PUT_LINE('El motor es COOPERATIVO: la sesion activa solo lo detecta entre columna y');
      DBMS_OUTPUT.PUT_LINE('columna (proc_dm_chk_cancel) -- si esta a mitad de una columna grande via');
      DBMS_OUTPUT.PUT_LINE('DBMS_PARALLEL_EXECUTE, puede tardar varios minutos en detenerse de verdad.');
      DBMS_OUTPUT.PUT_LINE('Verifique con: SELECT estado FROM tdm_mask_solicitud WHERE ejecucion_id='||p_ejecucion_id||' ORDER BY solicitud_id DESC;');
    ELSE
      DBMS_OUTPUT.PUT_LINE('NO se solicito cancelacion: ejecucion_id='||p_ejecucion_id||' no tiene ninguna');
      DBMS_OUTPUT.PUT_LINE('solicitud en estado EN_PROCESO/PENDIENTE/REPROCESANDO ahora mismo (ya finalizo, ya');
      DBMS_OUTPUT.PUT_LINE('esta en ERROR/CANCELADO, o el ejecucion_id no existe). Nada que cancelar.');
    END IF;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_reanudar
  -- PROPOSITO    : Reanuda un enmascarado interrumpido sobre la misma ejecucion_id, tras verificar la fase y que
  --                la sesion original este muerta, saltando las columnas ya confirmadas.
  -- ENTRADAS     : p_ejecucion_id; p_commit_lote (solo se reenvia).
  -- LEE          : TDM_EJECUCION (SELECT FOR UPDATE); TDM_MASK_SOLICITUD; GV$SESSION (func_dm_sesion_viva)
  -- ESCRIBE      : lo que escribe proc_dm_enmascaramiento_core (p_reproceso = N, con la solicitud previa)
  -- ERRORES      : ORA-20058 la fase no es ENMASCARAMIENTO; ORA-20017 la sesion original sigue viva;
  --                ORA-01403 si la ejecucion no existe.
  -- LLAMADO DESDE: dm_enmascara_reanudar.sql.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_reanudar(
    p_ejecucion_id IN NUMBER,
    p_commit_lote  IN NUMBER DEFAULT 1000
  ) IS
    l_prev_solicitud NUMBER;
    l_estado         tdm_ejecucion.estado%TYPE;
    l_fase           tdm_ejecucion.fase_proceso%TYPE;
    l_sid            tdm_ejecucion.sesion_sid%TYPE;
    l_serial         tdm_ejecucion.sesion_serial%TYPE;
    l_inst_id        tdm_ejecucion.sesion_inst_id%TYPE;
    l_ejecutado_por  tdm_ejecucion.ora_usuario%TYPE;
  BEGIN
    -- Antes de tocar nada: la ejecucion debe estar en fase ENMASCARAMIENTO (si no, se indica el driver
    -- correcto) y la sesion original no debe seguir viva en gv$session, sea cual sea el ESTADO. Un DBA puede
    -- haber cerrado la fila con dm_enmascara_cancel.sql sin que la sesion haya muerto, y una
    -- segunda ejecucion en paralelo dejaria dependencias deshabilitadas.
    SELECT estado, fase_proceso, sesion_sid, sesion_serial, sesion_inst_id, ora_usuario
      INTO l_estado, l_fase, l_sid, l_serial, l_inst_id, l_ejecutado_por
      FROM tdm_ejecucion
     WHERE ejecucion_id = p_ejecucion_id
       FOR UPDATE;

    IF l_fase IS NOT NULL AND UPPER(TRIM(l_fase)) != 'ENMASCARAMIENTO' THEN
      RAISE_APPLICATION_ERROR(-20058,
        'No se reanuda ejecucion_id='||p_ejecucion_id||' con pkg_dm_enmascarar.proc_dm_reanudar: '||
        'su fase_proceso actual es '||l_fase||', no ENMASCARAMIENTO. '||
        CASE WHEN UPPER(TRIM(l_fase)) = 'DESCUBRIMIENTO'
             THEN 'Use @dm_descubre_reanudar '||p_ejecucion_id||' para reanudar el descubrimiento.'
             ELSE 'Revise TDM_EJECUCION.fase_proceso antes de continuar.'
        END);
    END IF;

    IF pkg_dm_trazabilidad.func_dm_sesion_viva(p_ejecucion_id) = 1 THEN
      RAISE_APPLICATION_ERROR(-20017,
        'No se reanuda ejecucion_id='||p_ejecucion_id||': la sesion original '||
        '(sid='||NVL(TO_CHAR(l_sid),'?')||', serial#='||NVL(TO_CHAR(l_serial),'?')||
        ', inst_id='||NVL(TO_CHAR(l_inst_id),'?')||', usuario='||NVL(l_ejecutado_por,'?')||
        ') SIGUE VIVA en gv$session (TDM_EJECUCION.ESTADO actual='||NVL(l_estado,'?')||
        '). No se reanuda para evitar una ejecucion duplicada en paralelo -- '||
        'verifique esa sesion y matela con ALTER SYSTEM KILL SESSION si procede, luego reintente.');
    END IF;

    SELECT MAX(solicitud_id)
      INTO l_prev_solicitud
      FROM tdm_mask_solicitud
     WHERE ejecucion_id = p_ejecucion_id;

    -- La reanudacion queda en la traza con la nueva solicitud (ENMASCARAMIENTO/INICIO y ENMASCARAMIENTO/REANUDACION).
    proc_dm_enmascaramiento_core(p_ejecucion_id => p_ejecucion_id, p_reproceso => 'N',
                                 p_commit_lote => p_commit_lote, p_base_solicitud_id => l_prev_solicitud);
  END;

  PROCEDURE proc_dm_limpia_alcance_id(p_ejecucion_id IN NUMBER) IS
  BEGIN
    pkg_dm_mask_estado.proc_dm_limpia_alcance_id(p_ejecucion_id);
  END;

  -- Reenvio a pkg_dm_mask_estado.
  PROCEDURE proc_dm_registra_alcance_id(
    p_ejecucion_id  IN  NUMBER,
    p_identificador IN  VARCHAR2,
    o_columnas      OUT NUMBER
  ) IS
  BEGIN
    pkg_dm_mask_estado.proc_dm_registra_alcance_id(p_ejecucion_id, p_identificador, o_columnas);
  END;

  -- Reenvio de compatibilidad: la logica vive en pkg_dm_pepper.
  PROCEDURE proc_dm_pepper_purgar(
    p_ejecucion_id      IN NUMBER,
    p_confirma_abandono IN VARCHAR2 DEFAULT 'N'
  ) IS
  BEGIN
    pkg_dm_pepper.proc_dm_pepper_purgar(p_ejecucion_id, p_confirma_abandono);
  END;

  -- Reenvio de compatibilidad: la logica vive en pkg_dm_mask_worker.
  PROCEDURE proc_dm_gestiona_tareas(
    p_ejecucion_id IN NUMBER,
    p_modo         IN VARCHAR2 DEFAULT 'INFORMAR'
  ) IS
  BEGIN
    pkg_dm_mask_worker.proc_dm_gestiona_tareas(p_ejecucion_id, p_modo);
  END;

  -- Reenvio de compatibilidad: la logica vive en pkg_dm_mask_worker.
  FUNCTION func_dm_tareas_de_ejecucion(
    p_ejecucion_id IN NUMBER
  ) RETURN VARCHAR2 IS
  BEGIN
    RETURN pkg_dm_mask_worker.func_dm_tareas_de_ejecucion(p_ejecucion_id);
  END;


END pkg_dm_enmascarar;
/
