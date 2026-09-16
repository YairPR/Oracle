Rem pkg_dm_enmascarar.sql
Rem
Rem
Rem    NOMBRE
Rem      pkg_dm_enmascarar.sql - Motor operativo de enmascaramiento
Rem
Rem    DESCRIPCIÓN
Rem      Este paquete ejecuta el proceso de masking sobre tablas y columnas
Rem      definidas en tdm_columna_final, utilizando funciones deterministas
Rem      de pkg_dm_func_mask y respetando dependencias técnicas,
Rem      reglas especiales y coherencias post-masking.
Rem
Rem      El flujo soporta:
Rem        - Enmascaramiento por ejecución completa
Rem        - Reproceso forzado
Rem        - Cancelación controlada
Rem        - Reanudación de solicitudes
Rem        - Enmascaramiento selectivo por tabla o columna
Rem        - Export de esquema o subconjunto para PRE
Rem        - Trazabilidad del proceso
Rem        - Deshabilitado y rehabilitado de dependencias
Rem        - Reglas especiales por tabla/columna
Rem        - Sincronización post-masking entre tablas relacionadas
Rem
Rem    FLUJO:
Rem      El paquete toma como entrada principal:
Rem
Rem        - tdm_columna_final
Rem        - tdm_dependencia_final
Rem        - tdm_excepcion_col
Rem        - tdm_mask_regla_esp
Rem        - tdm_mask_relacion_sync
Rem
Rem      Y registra actividad en:
Rem
Rem        - tdm_mask_solicitud
Rem        - tdm_mask_trace
Rem        - tdm_mask_dep_estado
Rem        - tdm_ejecucion
Rem
Rem    CRITERIOS DE EJECUCIÓN
Rem      Antes de aplicar masking, el paquete valida por columna:
Rem
Rem        - Tipo de dato real desde DBA_TAB_COLUMNS
Rem        - Longitud disponible real
Rem        - Si la columna tiene datos no nulos
Rem        - Si existe EXCLUDE manual
Rem        - Si la longitud mínima es compatible con el identificador
Rem
Rem      Si una columna no cumple condiciones mínimas, el proceso:
Rem
Rem        - la omite
Rem        - la registra como SKIP en trazas
Rem        - puede consolidarla en tdm_excepcion_col como EXCLUDE
Rem        - continúa sin abortar la tabla completa
Rem
Rem    Reglas especiales (genericas, seleccionadas por tdm_mask_regla_esp):
Rem      DOC_KEEP_ENDS, DOC_SEGUN_TIPO, IBAN_CONTINUO -> pkg_dm_func_mask.func_especial_*
Rem        - Genera IBAN español continuo
Rem        - Mantiene formato ES + 22 dígitos
Rem        - Recalcula correctamente dígitos de control
Rem
Rem    COMPORTAMIENTO DEL PROCESO
Rem
Rem      p_dm_enmascara
Rem        - Ejecuta el masking completo de una ejecución
Rem        - Valida objetos base
Rem        - Crea solicitud operativa
Rem        - Deshabilita dependencias
Rem        - Aplica masking por catálogo
Rem        - Ejecuta sincronizaciones post-masking
Rem        - Rehabilita dependencias
Rem        - Actualiza estado final en control y trazas
Rem
Rem      p_mask_cancelar
Rem        - Marca una ejecución o solicitud para cancelación
Rem        - La cancelación se evalúa en puntos de control del proceso
Rem
Rem      p_mask_reanudar
Rem        - Relanza el proceso sobre una ejecución dada
Rem        - Aprovecha el mismo flujo operativo de enmascaramiento
Rem
Rem      p_mask_tab
Rem        - Ejecuta enmascaramiento selectivo
Rem        - Puede operar sobre una o varias tablas
Rem        - También puede dirigirse a una sola columna
Rem        - Requiere identificador semántico para resolver la función
Rem
Rem        - Exporta el alcance tratado o el esquema completo
Rem        - Soporta alcance:
Rem            S = solo tablas enmascaradas
Rem            C = esquema completo
Rem
Rem    EXPORT / IMPORT EN EL FLUJO
Rem      El modelo operativo contempla que el rollback funcional del masking
Rem      se realice preferentemente mediante importación del dump original
Rem      en lugar de un desenmascarado fila a fila.
Rem
Rem      Por ello:
Rem        - El export (Data Pump) se movio a pkg_dm_export (07)
Rem        - el import de reversión es la estrategia preferente
Rem        - no se depende de reconstrucción campo a campo para textos libres
Rem
Rem    CORRECCIONES Y AJUSTES RELEVANTES
Rem      - Corrección de ORA-06502 y ORA-12899 asociados a longitudes reales
Rem      - Validación previa de tipo y longitud antes de enmascarar
Rem      - Omisión controlada de columnas incompatibles
Rem      - Tratamiento especial para columnas bancarias de 10, 20 o 24 posiciones
Rem      - Refuerzo de trazabilidad por columna y por tabla
Rem      - Gestión de SKIP por:
Rem          * longitud insuficiente
Rem          * tipo no soportado
Rem          * todos los valores NULL
Rem          * exclusión manual
Rem      - Integración operativa con export Data Pump
Rem      - Preparación para estrategia de reversión por import
Rem
Rem    RELACIÓN CON EL DESCUBRIMIENTO
Rem      Este paquete no descubre columnas.
Rem      Parte del resultado ya validado del discovery, especialmente:
Rem
Rem        - tdm_columna_final
Rem        - tdm_dependencia_final
Rem        - tdm_excepcion_col
Rem
Rem      Por tanto, su responsabilidad es operativa y no semántica.
Rem
Rem    NOTAS
Rem      - Diseñado para Oracle 11g en adelante
Rem      - Usa SQL dinámico controlado con DBMS_ASSERT
Rem      - Utiliza tracking operativo vía DBMS_APPLICATION_INFO
Rem      - Integra trazabilidad de warnings, errores y checkpoints
Rem      - Respeta exclusiones manuales en tdm_excepcion_col
Rem      - Puede aplicar auto-exclusión de columnas incompatibles
Rem      - Está preparado para sincronización post-masking entre tablas
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    09/05/25 - Versión inicial del motor de enmascaramiento
Rem                           Basado en ejecución por columna y función semántica
Rem
Rem    epurisaca    10/11/25 - Se añade control operativo de solicitud
Rem                           trazabilidad técnica y gestión de dependencias
Rem
Rem    epurisaca    11/22/25 - Se incorporan reglas especiales para documentos
Rem                           IBAN y coherencia post-masking
Rem
Rem    epurisaca    01/28/26 - Se refuerza validación de longitudes
Rem                           exclusiones automáticas y tratamiento de errores
Rem
Rem    epurisaca    03/24/26 - Corrección de ORA-06502 y ORA-12899
Rem                           validación previa por tipo y longitud real
Rem
Rem    epurisaca    03/24/26 - Se incorpora lógica de SKIP controlado
Rem                           para columnas incompatibles o sin datos útiles
Rem
Rem    epurisaca    03/24/26 - Se integra export como parte del flujo PRE
Rem                           y reversión preferente vía import de dump
Rem
Rem    epurisaca    03/24/26 - Revisión funcional completa del paquete
Rem                           Alineado con flujo PRE, masking y post-sync
Rem    epurisaca    03/28/26 - Se retiró del fujo la tabla tdm_mask_resultado para 
Rem                            evitar duplicidad y ambigüedad de estados
Rem    epurisaca    04/21/26 - 
Rem                            1) Procesa tdm_columna_final.enmascarar='Y' como primera opción.
Rem                            2) Sobre esas columnas aplica prioridad de tdm_excepcion_col:
Rem                              - EXCLUDE omite
Rem                              - FORCE redefine identificador
Rem                            3) Solo si NO existen columnas en tdm_columna_final.enmascarar='Y'
Rem                               para el esquema, toma como fuente tdm_excepcion_col (FORCE activos).
Rem    epurisaca   14/07/26 - Ajuste de política operativa de dependencias
Rem                           Sync de tdm_dependencia_final alineado con PRE/POST
Rem                           Preserva estado real ENABLED/DISABLED en triggers y constraints
Rem                           FK/CONSTRAINT y TRIGGER normales con política automática
Rem                           Objetos Oracle Text DR$ se mantienen como revisión especial

create or replace PACKAGE pkg_dm_enmascarar AS

  FUNCTION f_norm(
    p_txt IN VARCHAR2
  ) RETURN VARCHAR2 DETERMINISTIC;

-- (reglas especiales muertas eliminadas: se usan pkg_dm_func_mask.func_especial_*)

  PROCEDURE p_dm_enmascara(
    p_ejecucion_id IN NUMBER,
    p_reproceso    IN VARCHAR2 DEFAULT 'N',
    p_commit_lote  IN NUMBER DEFAULT 1000
  );

  PROCEDURE p_mask_cancelar(
    p_ejecucion_id IN NUMBER
  );

  PROCEDURE p_mask_reanudar(
    p_ejecucion_id IN NUMBER,
    p_commit_lote  IN NUMBER DEFAULT 1000
  );

  PROCEDURE p_mask_tab(
    p_esquema       IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_identificador IN VARCHAR2,
    p_columna       IN VARCHAR2 DEFAULT NULL,
    p_commit_lote   IN NUMBER   DEFAULT 1000
  );

  -- Purga la semilla efimera de ESTA campana tras el export.
  PROCEDURE p_dm_pepper_purgar(p_ejecucion_id IN NUMBER);

  PROCEDURE proc_dm_trace(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_fase         IN VARCHAR2,
    p_paso         IN VARCHAR2,
    p_detalle      IN VARCHAR2
  );

  PROCEDURE proc_dm_log_ejec_error(
    p_ejecucion_id IN NUMBER,
    p_owner_name   IN VARCHAR2,
    p_table_name   IN VARCHAR2,
    p_column_name  IN VARCHAR2,
    p_etapa        IN VARCHAR2,
    p_codigo_error IN NUMBER,
    p_mensaje      IN VARCHAR2,
    p_backtrace    IN VARCHAR2,
    p_solicitud_id IN NUMBER DEFAULT NULL
  );

END pkg_dm_enmascarar;
/

create or replace PACKAGE BODY pkg_dm_enmascarar AS

  ------------------------------------------------------------------------------
  -- Estado para DBMS_APPLICATION_INFO.SET_SESSION_LONGOPS
  ------------------------------------------------------------------------------
  g_rindex BINARY_INTEGER;
  g_slno   BINARY_INTEGER;
  g_resume_base_solicitud NUMBER;
  g_dep_has_categoria_uso   NUMBER;
  g_dep_has_accion_pre_mask NUMBER;
  g_dep_has_accion_post_mask NUMBER;
  g_ejec_actual              NUMBER;   -- campana activa: se inyecta a cada worker paralelo

  ------------------------------------------------------------------------------
  -- Helpers seguros
  ------------------------------------------------------------------------------
  FUNCTION f_norm(p_txt IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    RETURN UPPER(TRIM(p_txt));
  END;

  FUNCTION f_safe_err(p_err IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    RETURN SUBSTR(REPLACE(REPLACE(NVL(p_err,'SIN_ERROR'), CHR(10), ' '), CHR(13), ' '), 1, 1800);
  END;

  FUNCTION f_safe_name(p_txt IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    RETURN SUBSTR(NVL(TRIM(p_txt), '?'), 1, 256);
  END;

  FUNCTION f_qname(p_name IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN DBMS_ASSERT.ENQUOTE_NAME(
             DBMS_ASSERT.SIMPLE_SQL_NAME(f_norm(p_name)),
             FALSE
           );
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20060, 'Nombre SQL invalido: '||SUBSTR(NVL(p_name,'NULL'),1,120));
  END;

  ------------------------------------------------------------------------------
  -- SEMILLA EFIMERA (PEPPER) POR CAMPANA (ejecucion_id)
  -- Cada campana usa su propia fila 'PEPPER_MASK:'||ejecucion_id, de modo que dos
  -- esquemas enmascarados a la vez tienen peppers independientes (sin carrera ni
  -- purga cruzada). Se genera al inicio (idempotente para el resume) con COMMIT
  -- antes del paralelo, y se purga por-campana tras el export.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_pepper_generar(p_ejecucion_id IN NUMBER) IS
    l_clave VARCHAR2(64) := 'PEPPER_MASK:'||TO_CHAR(p_ejecucion_id);
    l_cnt   NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_cnt FROM tdm_secreto WHERE clave = l_clave;
    IF l_cnt = 0 THEN
      BEGIN
        -- CSPRNG 256 bits -> 64 hex.
        INSERT INTO tdm_secreto (clave, valor)
        VALUES (l_clave, RAWTOHEX(DBMS_CRYPTO.RANDOMBYTES(32)));
        COMMIT;   -- imprescindible ANTES de lanzar los workers paralelos
      EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
          NULL;   -- carrera: otra sesion creo la fila de ESTE ejec; se conserva
      END;
    END IF;
    g_ejec_actual := p_ejecucion_id;                 -- para el wrap del chunk paralelo
    pkg_dm_func_mask.set_ejecucion(p_ejecucion_id);  -- para updates directos del coordinador
  END;

  PROCEDURE p_dm_pepper_purgar(p_ejecucion_id IN NUMBER) IS
  BEGIN
    -- Borra SOLO el secreto de esta campana. Llamar tras el export.
    DELETE FROM tdm_secreto WHERE clave = 'PEPPER_MASK:'||TO_CHAR(p_ejecucion_id);
    COMMIT;
  END;

  FUNCTION f_csv_item(p_lista IN VARCHAR2, p_pos IN PLS_INTEGER) RETURN VARCHAR2 IS
  BEGIN
    RETURN f_norm(REGEXP_SUBSTR(NVL(p_lista,''), '[^,]+', 1, p_pos));
  END;

  PROCEDURE proc_dm_ejecuta_update_seguro(
    p_owner    IN VARCHAR2,
    p_tabla    IN VARCHAR2,
    p_columna  IN VARCHAR2,
    p_sql_base IN VARCHAR2,
    p_rows_out OUT NUMBER
  ) IS
    l_row_count NUMBER;
    l_iot_type  VARCHAR2(30);
    l_task_name VARCHAR2(100);
    l_sql_chunk VARCHAR2(32767);
    l_stmt_check VARCHAR2(1000);
    l_estado_tarea  NUMBER;        -- C-02: estado terminal de la tarea paralela
    l_chunks_error  NUMBER;        -- C-02: nro de chunks PROCESSED_WITH_ERROR
    l_detalle_error VARCHAR2(400); -- C-02: ejemplo de error de chunk (diagnostico)
  BEGIN
    -- 1. Obtener número aproximado de filas e iot_type de la tabla
    l_stmt_check := 'SELECT num_rows, iot_type FROM dba_tables WHERE owner = :1 AND table_name = :2';
    BEGIN
      EXECUTE IMMEDIATE l_stmt_check INTO l_row_count, l_iot_type USING f_norm(p_owner), f_norm(p_tabla);
    EXCEPTION
      WHEN OTHERS THEN
        l_row_count := NULL;
        l_iot_type  := NULL;
    END;

    IF l_row_count IS NULL OR l_row_count = 0 THEN
      BEGIN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM '||f_qname(p_owner)||'.'||f_qname(p_tabla) INTO l_row_count;
      EXCEPTION
        WHEN OTHERS THEN
          l_row_count := 0;
      END;
    END IF;

    -- 2. Si la tabla supera el umbral (100,000 registros) y NO es una tabla IOT (Index-Organized), usar DBMS_PARALLEL_EXECUTE
    -- De lo contrario, usar EXECUTE IMMEDIATE estándar
    IF l_row_count > 100000 AND l_iot_type IS NULL THEN
      l_task_name := SUBSTR('TASK_DM_'||f_norm(p_tabla)||'_'||f_norm(p_columna)||'_'||TO_CHAR(DBMS_UTILITY.GET_TIME), 1, 30);
      
      -- Crear tarea
      DBMS_PARALLEL_EXECUTE.CREATE_TASK(task_name => l_task_name);
      
      -- Crear chunks por ROWID
      DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(
        task_name   => l_task_name,
        table_owner => f_norm(p_owner),
        table_name  => f_norm(p_tabla),
        by_row      => TRUE,
        chunk_size  => 50000
      );

      -- Construir sentencia SQL para el chunk
      -- Cada worker es una sesion propia: fija su ejecucion_id ANTES del UPDATE
      -- para leer el pepper de la campana correcta (el ejec es un literal numerico).
      l_sql_chunk := 'BEGIN pkg_dm_func_mask.set_ejecucion('||
                     CASE WHEN g_ejec_actual IS NULL THEN 'NULL' ELSE TO_CHAR(g_ejec_actual) END||
                     '); '||p_sql_base||' AND rowid BETWEEN :start_id AND :end_id; END;';

      -- Ejecutar tarea
      DBMS_PARALLEL_EXECUTE.RUN_TASK(
        task_name      => l_task_name,
        sql_stmt       => l_sql_chunk,
        language_flag  => DBMS_SQL.NATIVE,
        parallel_level => 2
      );

      -- C-02: FALLO CERRADO. No dar por buena la columna hasta confirmar que TODOS
      -- los chunks terminaron OK. Un reintento acotado cubre errores transitorios.
      l_estado_tarea := DBMS_PARALLEL_EXECUTE.TASK_STATUS(l_task_name);
      IF l_estado_tarea <> DBMS_PARALLEL_EXECUTE.FINISHED THEN
        DBMS_PARALLEL_EXECUTE.RESUME_TASK(l_task_name);          -- reintenta chunks fallidos
        l_estado_tarea := DBMS_PARALLEL_EXECUTE.TASK_STATUS(l_task_name);
      END IF;

      SELECT COUNT(*),
             MAX(TO_CHAR(error_code)||': '||SUBSTR(error_message,1,200))
        INTO l_chunks_error, l_detalle_error
        FROM user_parallel_execute_chunks
       WHERE task_name = l_task_name
         AND status    = 'PROCESSED_WITH_ERROR';

      IF l_estado_tarea <> DBMS_PARALLEL_EXECUTE.FINISHED OR NVL(l_chunks_error,0) > 0 THEN
        -- Se captura el diagnostico ANTES de limpiar la tarea, y se aborta la columna.
        DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => l_task_name);
        RAISE_APPLICATION_ERROR(-20320,
          'Enmascarado paralelo incompleto en '||p_owner||'.'||p_tabla||'.'||p_columna||
          ' (estado_tarea='||l_estado_tarea||', chunks_error='||NVL(l_chunks_error,0)||
          CASE WHEN l_detalle_error IS NOT NULL THEN ', ej='||l_detalle_error ELSE '' END||')');
      END IF;

      -- Tarea validada: limpiar.
      DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => l_task_name);
      -- Nota: p_rows_out es aproximado (num_rows de dba_tables); el conteo exacto
      -- por chunk no lo expone DBMS_PARALLEL_EXECUTE. Lo relevante es que, si algun
      -- chunk fallo, arriba ya se abortó (no se reporta exito con datos incompletos).
      p_rows_out := l_row_count;
    ELSE
      -- Ejecución original directa
      EXECUTE IMMEDIATE p_sql_base;
      p_rows_out := SQL%ROWCOUNT;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      -- Asegurar limpieza de la tarea si falla
      BEGIN
        DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => l_task_name);
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
      RAISE;
  END proc_dm_ejecuta_update_seguro;

  -- Wrapper de compatibilidad (2026-09-16): la implementacion real vive ahora
  -- en pkg_dm_trazabilidad, un paquete sin dependencias que tanto 04 como 05
  -- pueden llamar de forma ESTATICA (ver cabecera de 03b_dm_pkg_trazabilidad.sql
  -- para el porque). Se conserva esta firma publica identica para no romper
  -- a nadie que ya llame pkg_dm_enmascarar.proc_dm_trace directamente.
  PROCEDURE proc_dm_trace(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_fase         IN VARCHAR2,
    p_paso         IN VARCHAR2,
    p_detalle      IN VARCHAR2
  ) IS
  BEGIN
    pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id, p_ejecucion_id, p_fase, p_paso, p_detalle);
  END;

  PROCEDURE proc_dm_upd_sol(
    p_solicitud_id IN NUMBER,
    p_estado       IN VARCHAR2,
    p_fase         IN VARCHAR2,
    p_checkpoint   IN VARCHAR2,
    p_detalle      IN VARCHAR2 DEFAULT NULL,
    p_cerrar       IN VARCHAR2 DEFAULT 'N'
  ) IS
  BEGIN
    UPDATE tdm_mask_solicitud
       SET estado          = SUBSTR(p_estado,1,30),
           fase_actual     = SUBSTR(p_fase,1,30),
           checkpoint_paso = SUBSTR(p_checkpoint,1,100),
           heartbeat_ts    = SYSTIMESTAMP,
           fecha_fin       = CASE WHEN UPPER(NVL(p_cerrar,'N'))='Y' THEN SYSTIMESTAMP ELSE fecha_fin END,
           detalle         = CASE WHEN p_detalle IS NOT NULL THEN SUBSTR(p_detalle,1,3900) ELSE detalle END
     WHERE solicitud_id = p_solicitud_id;
    COMMIT;
  END;

  PROCEDURE proc_dm_upd_ejec(
    p_ejecucion_id IN NUMBER,
    p_fase         IN VARCHAR2 DEFAULT NULL,
    p_estado       IN VARCHAR2 DEFAULT NULL,
    p_pct          IN NUMBER   DEFAULT NULL,
    p_tab_tot      IN NUMBER   DEFAULT NULL,
    p_tab_proc     IN NUMBER   DEFAULT NULL,
    p_col_tot      IN NUMBER   DEFAULT NULL,
    p_col_proc     IN NUMBER   DEFAULT NULL,
    p_objeto       IN VARCHAR2 DEFAULT NULL,
    p_paso         IN VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    UPDATE tdm_ejecucion
       SET fase_proceso   = NVL(p_fase, fase_proceso),
           estado         = NVL(p_estado, estado),
           ejecutado_por  = USER,
           fecha_inicio   = CASE
                              WHEN UPPER(NVL(p_estado, estado)) = 'EJECUTANDO'
                                   AND (UPPER(NVL(estado,'?')) <> 'EJECUTANDO' OR fecha_inicio IS NULL)
                                THEN SYSTIMESTAMP
                              ELSE fecha_inicio
                            END,
           fecha_fin      = CASE
                              WHEN UPPER(NVL(p_estado, estado)) IN ('FINALIZADO','ERROR','CANCELADO')
                                THEN SYSTIMESTAMP
                              WHEN UPPER(NVL(p_estado, estado)) = 'EJECUTANDO'
                                THEN NULL
                              ELSE fecha_fin
                            END,
           progreso_pct   = NVL(p_pct, progreso_pct),
           tablas_total   = NVL(p_tab_tot, tablas_total),
           tablas_proc    = NVL(p_tab_proc, tablas_proc),
           columnas_total = NVL(p_col_tot, columnas_total),
           columnas_proc  = NVL(p_col_proc, columnas_proc),
           ultimo_objeto  = NVL(p_objeto, ultimo_objeto),
           ultimo_paso    = NVL(p_paso, ultimo_paso),
           heartbeat_ts   = SYSTIMESTAMP
     WHERE ejecucion_id = p_ejecucion_id;
    COMMIT;
  EXCEPTION
    -- No aborta (esta rutina la llaman tambien los propios manejadores de
    -- error, para no encadenar fallos), pero antes de este cambio el fallo
    -- desaparecia sin dejar rastro y el estado mostrado al operador podia
    -- quedar desactualizado sin ninguna pista. Ahora al menos queda trazado.
    WHEN OTHERS THEN
      proc_dm_trace(NULL, p_ejecucion_id, 'ERROR', 'UPD_EJEC_FALLO', f_safe_err(SQLERRM));
  END;

  PROCEDURE proc_dm_close_sol_open(p_ejecucion_id IN NUMBER) IS
  BEGIN
    UPDATE tdm_mask_solicitud
       SET estado          = 'ERROR',
           fase_actual     = 'FIN',
           checkpoint_paso = 'AUTO_CLOSE_REANUDAR',
           fecha_fin       = SYSTIMESTAMP,
           heartbeat_ts    = SYSTIMESTAMP,
           detalle         = SUBSTR(NVL(detalle,'')||' | Cerrada automáticamente por nueva ejecución/reanudación',1,3900)
     WHERE ejecucion_id = p_ejecucion_id
       AND estado IN ('EN_PROCESO','PENDIENTE','REANUDANDO')
       AND fecha_fin IS NULL;
    COMMIT;
  EXCEPTION
    -- Igual que en proc_dm_upd_ejec: housekeeping de solicitudes huerfanas,
    -- ahora con traza en vez de silencio total.
    WHEN OTHERS THEN
      proc_dm_trace(NULL, p_ejecucion_id, 'ERROR', 'CLOSE_SOL_OPEN_FALLO', f_safe_err(SQLERRM));
  END;

  PROCEDURE proc_dm_longops(
    p_opname IN VARCHAR2,
    p_target IN VARCHAR2,
    p_sofar  IN NUMBER,
    p_total  IN NUMBER,
    p_units  IN VARCHAR2
  ) IS
  BEGIN
    DBMS_APPLICATION_INFO.SET_SESSION_LONGOPS(
      rindex      => g_rindex,
      slno        => g_slno,
      op_name     => SUBSTR(p_opname,1,64),
      target_desc => SUBSTR(p_target,1,32),
      sofar       => NVL(p_sofar,0),
      totalwork   => NVL(p_total,0),
      units       => SUBSTR(p_units,1,32)
    );
  EXCEPTION
    -- Silencio deliberado: SET_SESSION_LONGOPS es telemetria de progreso para
    -- V$SESSION_LONGOPS (monitorizacion), no afecta al enmascarado ni a la
    -- integridad de los datos. Un fallo aqui nunca debe abortar la campana.
    WHEN OTHERS THEN NULL;
  END;

  PROCEDURE proc_dm_chk_cancel(p_solicitud_id IN NUMBER) IS
    l_cancel CHAR(1);
  BEGIN
    SELECT cancel_requested
      INTO l_cancel
      FROM tdm_mask_solicitud
     WHERE solicitud_id = p_solicitud_id;

    IF NVL(l_cancel,'N') = 'Y' THEN
      RAISE_APPLICATION_ERROR(-20081, 'Cancelación solicitada para solicitud_id='||p_solicitud_id);
    END IF;
  END;

  FUNCTION func_dm_esquema(p_ejecucion_id IN NUMBER) RETURN VARCHAR2 IS
    l_esquema VARCHAR2(128);
  BEGIN
    SELECT UPPER(TRIM(esquema_objetivo))
      INTO l_esquema
      FROM tdm_ejecucion
     WHERE ejecucion_id = p_ejecucion_id;
    RETURN l_esquema;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20056,'No existe tdm_ejecucion para ejecucion_id='||p_ejecucion_id);
  END;

  FUNCTION func_dm_crea_sol(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_detalle      IN VARCHAR2,
    p_forzar_reproceso IN VARCHAR2 DEFAULT 'N'
  ) RETURN NUMBER IS
    l_solicitud_id NUMBER;
    l_reintento    NUMBER;
    l_esquema      VARCHAR2(128) := UPPER(TRIM(p_esquema));
  BEGIN
    SELECT NVL(MAX(reintento_nro),0)+1
      INTO l_reintento
      FROM tdm_mask_solicitud
     WHERE ejecucion_id = p_ejecucion_id;

    l_solicitud_id := seq_dm_mask_solicitud.NEXTVAL;

    INSERT INTO tdm_mask_solicitud(
      solicitud_id, ejecucion_id, esquema_objetivo, estado, fase_actual,
      checkpoint_paso, reintento_nro, cancel_requested, fecha_inicio,
      heartbeat_ts, detalle, forzar_reproceso, filas_procesadas, filas_error,
      tablas_procesadas, columnas_procesadas, ultima_tabla, ultima_columna,
      sesion_sid, sesion_serial
    ) VALUES (
      l_solicitud_id, p_ejecucion_id, l_esquema, 'EN_PROCESO', 'INI',
      'INI', l_reintento, 'N', SYSTIMESTAMP, SYSTIMESTAMP, SUBSTR(p_detalle,1,3900),
      UPPER(TRIM(NVL(p_forzar_reproceso,'N'))), 0, 0, 0, 0, NULL, NULL, NULL, NULL
    );
    -- Limpieza (2026-09-16): aqui habia un EXECUTE IMMEDIATE que actualizaba
    -- TDM_MASK_SOLICITUD.FORZAR_FULL, columna que NO existe en esa tabla (la
    -- columna real es FORZAR_REPROCESO, ya fijada arriba en el INSERT). El
    -- UPDATE fallaba con ORA-00904 en cada llamada y el WHEN OTHERS lo
    -- silenciaba - codigo muerto que nunca hizo nada. Eliminado.

    COMMIT;
    RETURN l_solicitud_id;
  END;

  PROCEDURE proc_dm_validar_base IS
    l_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = 'TDM_MASK_SOLICITUD';
    IF l_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20050,'No existe TDM_MASK_SOLICITUD'); END IF;
    SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = 'TDM_MASK_TRACE';
    IF l_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20051,'No existe TDM_MASK_TRACE'); END IF;
    SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = 'TDM_MASK_DEP_ESTADO';
    IF l_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20052,'No existe TDM_MASK_DEP_ESTADO'); END IF;
    SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = 'TDM_COLUMNA_FINAL';
    IF l_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20053,'No existe TDM_COLUMNA_FINAL'); END IF;
    SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = 'TDM_DEPENDENCIA_FINAL';
    IF l_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20054,'No existe TDM_DEPENDENCIA_FINAL'); END IF;
    /*SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = 'TDM_MASK_CACHE';
    IF l_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20057,'No existe TDM_MASK_CACHE'); END IF;*/
  END;

  PROCEDURE proc_dm_refresca_sesion(
    p_ejecucion_id IN NUMBER
  ) IS
    l_sid    NUMBER;
    l_serial NUMBER;
    l_inst   NUMBER;
  BEGIN
    BEGIN
      SELECT s.sid, s.serial#, s.inst_id
        INTO l_sid, l_serial, l_inst
        FROM gv$session s
       WHERE s.audsid = SYS_CONTEXT('USERENV','SESSIONID')
         AND s.username = SYS_CONTEXT('USERENV','SESSION_USER')
         AND ROWNUM = 1;
    EXCEPTION
      WHEN OTHERS THEN
        l_sid := NULL;
        l_serial := NULL;
        l_inst := NULL;
    END;

    UPDATE tdm_ejecucion
       SET sesion_audsid  = SYS_CONTEXT('USERENV','SESSIONID'),
           sesion_sid     = l_sid,
           sesion_serial  = l_serial,
           sesion_inst_id = l_inst,
           heartbeat_ts   = SYSTIMESTAMP
     WHERE ejecucion_id = p_ejecucion_id;
    COMMIT;
  EXCEPTION
    -- Silencio deliberado: SID/SERIAL# de sesion son datos de monitorizacion
    -- (permiten a un DBA ver la sesion en V$SESSION); su ausencia no afecta
    -- al enmascarado. GV$SESSION puede fallar en RAC sin privilegio o en
    -- mitad de un failover, y no debe abortar la campana por eso.
    WHEN OTHERS THEN NULL;
  END;

  PROCEDURE proc_dm_validar_concurrencia(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  ) IS
    l_cnt NUMBER;
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
  BEGIN
    SELECT COUNT(*)
      INTO l_cnt
      FROM tdm_ejecucion e
     WHERE e.ejecucion_id = p_ejecucion_id
       AND UPPER(TRIM(NVL(e.fase_proceso,'?'))) = 'ENMASCARAMIENTO'
       AND UPPER(TRIM(NVL(e.estado,'?'))) = 'EJECUTANDO';

    IF l_cnt > 0 THEN
      RAISE_APPLICATION_ERROR(
        -20097,
        'Ya existe una ejecución ENMASCARAMIENTO en estado EJECUTANDO para ejecucion_id='||p_ejecucion_id||
        '. Reintente cuando finalice o cancele la sesión activa.'
      );
    END IF;

    SELECT COUNT(*)
      INTO l_cnt
      FROM tdm_ejecucion e
     WHERE UPPER(TRIM(e.esquema_objetivo)) = l_esquema
       AND e.ejecucion_id <> p_ejecucion_id
       AND UPPER(TRIM(NVL(e.fase_proceso,'?'))) = 'ENMASCARAMIENTO'
       AND UPPER(TRIM(NVL(e.estado,'?'))) = 'EJECUTANDO';

    IF l_cnt > 0 THEN
      RAISE_APPLICATION_ERROR(
        -20098,
        'Ya existe una ejecución ENMASCARAMIENTO en estado EJECUTANDO para el esquema '||l_esquema||
        '. Evite ejecutar dos sesiones en paralelo sobre el mismo esquema.'
      );
    END IF;
  END;

  -- Wrapper de compatibilidad (2026-09-16): ver nota de proc_dm_trace, misma
  -- razon. Implementacion real en pkg_dm_trazabilidad.
  PROCEDURE proc_dm_log_ejec_error(
    p_ejecucion_id IN NUMBER,
    p_owner_name   IN VARCHAR2,
    p_table_name   IN VARCHAR2,
    p_column_name  IN VARCHAR2,
    p_etapa        IN VARCHAR2,
    p_codigo_error IN NUMBER,
    p_mensaje      IN VARCHAR2,
    p_backtrace    IN VARCHAR2,
    p_solicitud_id IN NUMBER DEFAULT NULL
  ) IS
  BEGIN
    pkg_dm_trazabilidad.proc_dm_log_ejec_error(
      p_ejecucion_id, p_owner_name, p_table_name, p_column_name, p_etapa,
      p_codigo_error, p_mensaje, p_backtrace, p_solicitud_id
    );
  END;

  PROCEDURE proc_dm_validar_reingreso_mask(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_reproceso    IN VARCHAR2
  ) IS
    l_cnt NUMBER := 0;
    l_repro VARCHAR2(1) := UPPER(TRIM(NVL(p_reproceso,'N')));
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
  BEGIN
    IF l_repro = 'Y' THEN
      RETURN;
    END IF;

    SELECT COUNT(*)
      INTO l_cnt
      FROM tdm_mask_solicitud s
     WHERE s.ejecucion_id = p_ejecucion_id
       AND s.estado = 'FINALIZADO';

    IF l_cnt > 0 THEN
      RAISE_APPLICATION_ERROR(
        -20014,
        'La ejecución_id='||p_ejecucion_id||' del esquema '||l_esquema||
        ' ya fue ejecutada en enmascaramiento. Para re-ejecutar debe usar p_dm_enmascara('||
        TO_CHAR(p_ejecucion_id)||',''Y'').'
      );
    END IF;
  END;

  ------------------------------------------------------------------------------
  -- Catálogo y reglas
  ------------------------------------------------------------------------------
  FUNCTION func_dm_tiene_regla(
    p_esquema IN VARCHAR2,
    p_owner   IN VARCHAR2,
    p_tabla   IN VARCHAR2,
    p_columna IN VARCHAR2,
    p_tipo    IN VARCHAR2
  ) RETURN NUMBER IS
    l_cnt NUMBER;
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_owner   VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla   VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna VARCHAR2(128) := UPPER(TRIM(p_columna));
    l_tipo    VARCHAR2(128) := UPPER(TRIM(p_tipo));
  BEGIN
    SELECT COUNT(*) INTO l_cnt
      FROM tdm_mask_regla_esp
     WHERE esquema_objetivo = l_esquema
       AND owner_name       = l_owner
       AND table_name       = l_tabla
       AND column_name      = l_columna
       AND tipo_regla       = l_tipo
       AND activa           = 'Y';
    RETURN l_cnt;
  EXCEPTION
    -- Fail-closed (2026-09-16): un COUNT(*) sobre una tabla propia solo puede
    -- fallar por un problema real (tabla inaccesible, privilegio revocado,
    -- deadlock). Devolver 0 en ese caso hacia parecer "no hay regla especial"
    -- y el motor caia al tratamiento generico sin avisar - exactamente el
    -- tipo de fallback silencioso que el resto del motor evita. Se propaga.
    WHEN OTHERS THEN RAISE;
  END;

  FUNCTION func_dm_val_regla(
    p_esquema IN VARCHAR2,
    p_owner   IN VARCHAR2,
    p_tabla   IN VARCHAR2,
    p_columna IN VARCHAR2,
    p_tipo    IN VARCHAR2
  ) RETURN VARCHAR2 IS
    l_valor VARCHAR2(4000);
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_owner   VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla   VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna VARCHAR2(128) := UPPER(TRIM(p_columna));
    l_tipo    VARCHAR2(128) := UPPER(TRIM(p_tipo));
  BEGIN
    SELECT valor_regla INTO l_valor
      FROM tdm_mask_regla_esp
     WHERE esquema_objetivo = l_esquema
       AND owner_name       = l_owner
       AND table_name       = l_tabla
       AND column_name      = l_columna
       AND tipo_regla       = l_tipo
       AND activa           = 'Y'
       AND ROWNUM = 1;
    RETURN l_valor;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
  END;

  FUNCTION f_expr_gen_sql(
    p_identificador IN VARCHAR2,
    p_col_expr      IN VARCHAR2
  ) RETURN VARCHAR2 IS
    l_id VARCHAR2(100) := f_norm(p_identificador);
  BEGIN
    CASE l_id
      WHEN 'IDENTIFICADOR_PERSONAL'    THEN RETURN 'pkg_dm_func_mask.func_nombre('||p_col_expr||')';
      WHEN 'IDENTIFICADOR_NOMBRE'      THEN RETURN 'pkg_dm_func_mask.func_nombre('||p_col_expr||')';
      WHEN 'IDENTIFICADOR_DIRECCION'   THEN RETURN 'pkg_dm_func_mask.func_direccion('||p_col_expr||')';
      WHEN 'IDENTIFICADOR_TELEFONO'    THEN RETURN 'pkg_dm_func_mask.func_telefono('||p_col_expr||')';
      WHEN 'IDENTIFICADOR_EMAIL'       THEN RETURN 'pkg_dm_func_mask.func_email('||p_col_expr||')';
      WHEN 'IDENTIFICADOR_IDENTIDAD'   THEN RETURN 'pkg_dm_func_mask.func_nif('||p_col_expr||')';
      WHEN 'IDENTIFICADOR_BANCARIO'    THEN
        RETURN 'CASE WHEN REGEXP_LIKE(UPPER(TRIM('||p_col_expr||')), ''^ES[0-9]{22}$'') '||
               'THEN pkg_dm_func_mask.func_iban('||p_col_expr||') '||
               'ELSE pkg_dm_func_mask.func_cuenta('||p_col_expr||') END';
      ELSE
        RETURN 'pkg_dm_func_mask.func_obs('||p_col_expr||')';
    END CASE;
  END;

  FUNCTION f_expr_compatible(
    p_owner         IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_columna       IN VARCHAR2,
    p_identificador IN VARCHAR2
  ) RETURN VARCHAR2 IS
    l_data_type dba_tab_columns.data_type%TYPE;
    l_len       dba_tab_columns.data_length%TYPE;
    l_char_len  NUMBER;
    l_expr      VARCHAR2(4000);
    l_col       VARCHAR2(4000) := f_qname(p_columna);
    l_owner     VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla     VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna   VARCHAR2(128) := UPPER(TRIM(p_columna));
  BEGIN
    BEGIN
      SELECT data_type, data_length, NVL(char_col_decl_length, data_length)
        INTO l_data_type, l_len, l_char_len
        FROM dba_tab_columns
       WHERE owner = l_owner
         AND table_name = l_tabla
         AND column_name = l_columna;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_data_type := NULL;
        l_len       := NULL;
        l_char_len  := NULL;
    END;

    IF l_data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2') THEN
      l_expr := f_expr_gen_sql(p_identificador, l_col);
      RETURN 'SUBSTR('||l_expr||',1,'||TO_CHAR(NVL(l_char_len,l_len))||')';
    ELSE
      RETURN l_col;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      -- M-7: Envolver en SUBSTR con longitud de fallback prudente ante fallo de consulta de metadatos
      RETURN 'SUBSTR('||f_expr_gen_sql(p_identificador, l_col)||',1,4000)';
  END;

  ------------------------------------------------------------------------------
  -- Dependencias PRE/POST robustas (fix ORA-02431/02430 + ORA-06502)
  ------------------------------------------------------------------------------
  FUNCTION func_dm_dep_col_exists(
    p_col IN VARCHAR2
  ) RETURN NUMBER IS
    l_cnt NUMBER := 0;
    l_col VARCHAR2(128) := UPPER(TRIM(p_col));
  BEGIN
    IF l_col = 'CATEGORIA_USO' AND g_dep_has_categoria_uso IS NOT NULL THEN
      RETURN g_dep_has_categoria_uso;
    ELSIF l_col = 'ACCION_PRE_MASK' AND g_dep_has_accion_pre_mask IS NOT NULL THEN
      RETURN g_dep_has_accion_pre_mask;
    ELSIF l_col = 'ACCION_POST_MASK' AND g_dep_has_accion_post_mask IS NOT NULL THEN
      RETURN g_dep_has_accion_post_mask;
    END IF;

    BEGIN
      SELECT COUNT(*)
        INTO l_cnt
        FROM dba_tab_columns
       WHERE owner = SYS_CONTEXT('USERENV','CURRENT_USER')
         AND table_name = 'TDM_DEPENDENCIA_FINAL'
         AND column_name = l_col;
    EXCEPTION
      WHEN OTHERS THEN
        l_cnt := 0;
    END;

    IF l_col = 'CATEGORIA_USO' THEN
      g_dep_has_categoria_uso := CASE WHEN l_cnt > 0 THEN 1 ELSE 0 END;
      RETURN g_dep_has_categoria_uso;
    ELSIF l_col = 'ACCION_PRE_MASK' THEN
      g_dep_has_accion_pre_mask := CASE WHEN l_cnt > 0 THEN 1 ELSE 0 END;
      RETURN g_dep_has_accion_pre_mask;
    ELSIF l_col = 'ACCION_POST_MASK' THEN
      g_dep_has_accion_post_mask := CASE WHEN l_cnt > 0 THEN 1 ELSE 0 END;
      RETURN g_dep_has_accion_post_mask;
    END IF;

    RETURN 0;
  END;

  PROCEDURE proc_dm_dep_policy(
    p_owner_name      IN VARCHAR2,
    p_table_name      IN VARCHAR2,
    p_dep_owner       IN VARCHAR2,
    p_dep_objeto      IN VARCHAR2,
    p_tipo_dependencia IN VARCHAR2,
    p_categoria_uso   OUT VARCHAR2,
    p_accion_pre      OUT VARCHAR2,
    p_accion_post     OUT VARCHAR2
  ) IS
    l_tipo VARCHAR2(100) := UPPER(TRIM(NVL(p_tipo_dependencia,'')));
    l_val  VARCHAR2(100);
  BEGIN
    -- Defaults seguros (compatibles con comportamiento existente).
    IF l_tipo IN ('FK','R','FOREIGN KEY','CONSTRAINT') THEN
      p_categoria_uso := 'INTEGRIDAD';
      p_accion_pre    := 'DISABLE';
      p_accion_post   := 'ENABLE_VALIDATE';
    ELSIF l_tipo IN ('PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE') THEN
      p_categoria_uso := 'INTEGRIDAD';
      p_accion_pre    := 'SOLO_INFORMATIVO';
      p_accion_post   := 'REVISAR';
    ELSIF l_tipo = 'TRIGGER' THEN
      p_categoria_uso := 'OPERATIVA';
      p_accion_pre    := 'DISABLE';
      p_accion_post   := 'ENABLE';
    ELSE
      p_categoria_uso := 'OPERATIVA';
      p_accion_pre    := 'SOLO_INFORMATIVO';
      p_accion_post   := 'SIN_ACCION';
    END IF;

    IF func_dm_dep_col_exists('CATEGORIA_USO') = 1 THEN
      BEGIN
        EXECUTE IMMEDIATE
          'SELECT MAX(UPPER(TRIM(categoria_uso))) '||
          'FROM tdm_dependencia_final '||
          'WHERE owner_name = :1 '||
          '  AND table_name = :2 '||
          '  AND UPPER(TRIM(dependencia_owner)) = :3 '||
          '  AND UPPER(TRIM(dependencia_objeto)) = :4 '||
          '  AND UPPER(TRIM(tipo_dependencia)) = :5'
          INTO l_val
          USING UPPER(TRIM(p_owner_name)),
                UPPER(TRIM(p_table_name)),
                UPPER(TRIM(p_dep_owner)),
                UPPER(TRIM(p_dep_objeto)),
                UPPER(TRIM(p_tipo_dependencia));
        IF l_val IS NOT NULL THEN
          p_categoria_uso := l_val;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
    END IF;

    IF func_dm_dep_col_exists('ACCION_PRE_MASK') = 1 THEN
      BEGIN
        EXECUTE IMMEDIATE
          'SELECT MAX(UPPER(TRIM(accion_pre_mask))) '||
          'FROM tdm_dependencia_final '||
          'WHERE owner_name = :1 '||
          '  AND table_name = :2 '||
          '  AND UPPER(TRIM(dependencia_owner)) = :3 '||
          '  AND UPPER(TRIM(dependencia_objeto)) = :4 '||
          '  AND UPPER(TRIM(tipo_dependencia)) = :5'
          INTO l_val
          USING UPPER(TRIM(p_owner_name)),
                UPPER(TRIM(p_table_name)),
                UPPER(TRIM(p_dep_owner)),
                UPPER(TRIM(p_dep_objeto)),
                UPPER(TRIM(p_tipo_dependencia));
        IF l_val IS NOT NULL THEN
          p_accion_pre := l_val;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
    END IF;

    IF func_dm_dep_col_exists('ACCION_POST_MASK') = 1 THEN
      BEGIN
        EXECUTE IMMEDIATE
          'SELECT MAX(UPPER(TRIM(accion_post_mask))) '||
          'FROM tdm_dependencia_final '||
          'WHERE owner_name = :1 '||
          '  AND table_name = :2 '||
          '  AND UPPER(TRIM(dependencia_owner)) = :3 '||
          '  AND UPPER(TRIM(dependencia_objeto)) = :4 '||
          '  AND UPPER(TRIM(tipo_dependencia)) = :5'
          INTO l_val
          USING UPPER(TRIM(p_owner_name)),
                UPPER(TRIM(p_table_name)),
                UPPER(TRIM(p_dep_owner)),
                UPPER(TRIM(p_dep_objeto)),
                UPPER(TRIM(p_tipo_dependencia));
        IF l_val IS NOT NULL THEN
          p_accion_post := l_val;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
    END IF;
  END;

  FUNCTION func_dm_dep_post_action(
    p_owner_name IN VARCHAR2,
    p_table_name IN VARCHAR2,
    p_dep_owner  IN VARCHAR2,
    p_dep_objeto IN VARCHAR2,
    p_tipo_obj   IN VARCHAR2
  ) RETURN VARCHAR2 IS
    l_val VARCHAR2(100);
    l_def VARCHAR2(100);
  BEGIN
    IF UPPER(TRIM(p_tipo_obj)) = 'TRIGGER' THEN
      l_def := 'ENABLE';
    ELSE
      l_def := 'ENABLE_VALIDATE';
    END IF;

    IF func_dm_dep_col_exists('ACCION_POST_MASK') = 1 THEN
      BEGIN
        EXECUTE IMMEDIATE
          'SELECT MAX(UPPER(TRIM(accion_post_mask))) '||
          'FROM tdm_dependencia_final '||
          'WHERE owner_name = :1 '||
          '  AND table_name = :2 '||
          '  AND UPPER(TRIM(dependencia_owner)) = :3 '||
          '  AND UPPER(TRIM(dependencia_objeto)) = :4'
          INTO l_val
          USING UPPER(TRIM(p_owner_name)),
                UPPER(TRIM(p_table_name)),
                UPPER(TRIM(p_dep_owner)),
                UPPER(TRIM(p_dep_objeto));
        IF l_val IS NOT NULL THEN
          RETURN l_val;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
    END IF;

    RETURN l_def;
  END;

  PROCEDURE proc_dm_pre_dep(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  ) IS
    l_tabla_real VARCHAR2(261);
    l_exists NUMBER;
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_categoria_uso VARCHAR2(100);
    l_accion_pre    VARCHAR2(100);
    l_accion_post   VARCHAR2(100);
  BEGIN
    proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'INICIO', 'Deshabilitando dependencias definidas en TDM_DEPENDENCIA_FINAL');

    -- A.3: Enumerar y trazar la jerarquía FK (hija -> padre) de las tablas a enmascarar
    FOR fk IN (
      SELECT c.owner        child_owner,  c.table_name child_table,
             c.constraint_name fk_name,    c.status,
             pk.table_name    parent_table, c.r_owner parent_owner
        FROM dba_constraints c
        JOIN dba_constraints pk ON pk.owner = c.r_owner AND pk.constraint_name = c.r_constraint_name
       WHERE c.constraint_type = 'R'
         AND c.owner = l_esquema
         AND c.table_name IN (SELECT DISTINCT table_name FROM tdm_columna_final
                               WHERE owner_name = l_esquema AND enmascarar = 'Y')
       ORDER BY c.table_name, pk.table_name
    ) LOOP
      proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'FK_JERARQUIA',
         'hija: '||fk.child_owner||'.'||fk.child_table||
         ' -> padre: '||fk.parent_owner||'.'||fk.parent_table||
         ' (constraint '||fk.fk_name||', estado '||fk.status||')');
    END LOOP;

    FOR rc IN (
      SELECT tipo_dependencia, dependencia_owner, dependencia_objeto, table_name
        FROM (
          SELECT tipo_dependencia,
                 dependencia_owner,
                 dependencia_objeto,
                 table_name,
                 ROW_NUMBER() OVER (
                   PARTITION BY UPPER(TRIM(tipo_dependencia)),
                                UPPER(TRIM(dependencia_owner)),
                                UPPER(TRIM(dependencia_objeto))
                   ORDER BY table_name
                 ) rn
            FROM tdm_dependencia_final
           WHERE owner_name = l_esquema
        )
       WHERE rn = 1
       ORDER BY CASE
                  WHEN UPPER(TRIM(tipo_dependencia)) = 'TRIGGER' THEN 1
                  ELSE 2
                END,
                UPPER(TRIM(dependencia_owner)),
                UPPER(TRIM(table_name)),
                UPPER(TRIM(dependencia_objeto))
    ) LOOP
      BEGIN
        proc_dm_dep_policy(
          p_owner_name       => l_esquema,
          p_table_name       => rc.table_name,
          p_dep_owner        => rc.dependencia_owner,
          p_dep_objeto       => rc.dependencia_objeto,
          p_tipo_dependencia => rc.tipo_dependencia,
          p_categoria_uso    => l_categoria_uso,
          p_accion_pre       => l_accion_pre,
          p_accion_post      => l_accion_post
        );

        IF f_norm(rc.tipo_dependencia) IN ('FK','CONSTRAINT','R','FOREIGN KEY','PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE') THEN
          IF l_accion_pre <> 'DISABLE' THEN
            proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_POLICY',
              'CONSTRAINT '||f_safe_name(rc.dependencia_owner)||'.'||f_safe_name(rc.dependencia_objeto)||
              ' accion_pre='||f_safe_name(l_accion_pre)||' (SOLO_INFORMATIVO=solo traza, sin DDL; SIN_ACCION=no intervenir)'||
              ' categoria='||f_safe_name(l_categoria_uso)
            );
            CONTINUE;
          END IF;
          BEGIN
            SELECT c.table_name INTO l_tabla_real
              FROM dba_constraints c
             WHERE c.owner = UPPER(TRIM(rc.dependencia_owner))
               AND c.constraint_name = UPPER(TRIM(rc.dependencia_objeto))
               AND ROWNUM = 1;
          EXCEPTION
            WHEN OTHERS THEN
              l_tabla_real := rc.table_name;
          END;

          INSERT INTO tdm_mask_dep_estado(
            solicitud_id, tipo_objeto, owner_name, table_name, objeto_name, estado_previo, fecha_pre
          ) VALUES (
            p_solicitud_id, 'CONSTRAINT', UPPER(TRIM(rc.dependencia_owner)), UPPER(TRIM(l_tabla_real)), UPPER(TRIM(rc.dependencia_objeto)), 'ENABLED', SYSTIMESTAMP
          );
          BEGIN
            SELECT COUNT(*)
              INTO l_exists
              FROM dba_constraints c
             WHERE c.owner = UPPER(TRIM(rc.dependencia_owner))
               AND c.table_name = UPPER(TRIM(l_tabla_real))
               AND c.constraint_name = UPPER(TRIM(rc.dependencia_objeto));
          EXCEPTION
            WHEN OTHERS THEN
              l_exists := 0;
          END;

          IF l_exists > 0 THEN
            EXECUTE IMMEDIATE
              'ALTER TABLE '||f_qname(rc.dependencia_owner)||'.'||f_qname(l_tabla_real)||
              ' DISABLE CONSTRAINT '||f_qname(rc.dependencia_objeto);
            UPDATE tdm_mask_dep_estado
               SET deshabilitado_ok = 'Y'
             WHERE solicitud_id = p_solicitud_id
               AND tipo_objeto  = 'CONSTRAINT'
               AND owner_name   = UPPER(TRIM(rc.dependencia_owner))
               AND table_name   = UPPER(TRIM(l_tabla_real))
               AND objeto_name  = UPPER(TRIM(rc.dependencia_objeto));
          ELSE
            UPDATE tdm_mask_dep_estado
               SET deshabilitado_ok = 'N',
                   habilitado_ok = 'Y'
             WHERE solicitud_id = p_solicitud_id
               AND tipo_objeto  = 'CONSTRAINT'
               AND owner_name   = UPPER(TRIM(rc.dependencia_owner))
               AND table_name   = UPPER(TRIM(l_tabla_real))
               AND objeto_name  = UPPER(TRIM(rc.dependencia_objeto));
            proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_NOT_FOUND',
              'CONSTRAINT '||f_safe_name(rc.dependencia_owner)||'.'||f_safe_name(rc.dependencia_objeto)||' no existe'
            );
          END IF;

        ELSIF f_norm(rc.tipo_dependencia) = 'TRIGGER' THEN
          IF l_accion_pre <> 'DISABLE' THEN
            proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_POLICY',
              'TRIGGER '||f_safe_name(rc.dependencia_owner)||'.'||f_safe_name(rc.dependencia_objeto)||
              ' accion_pre='||f_safe_name(l_accion_pre)||' (SOLO_INFORMATIVO=solo traza, sin DDL; SIN_ACCION=no intervenir)'||
              ' categoria='||f_safe_name(l_categoria_uso)
            );
            CONTINUE;
          END IF;
          INSERT INTO tdm_mask_dep_estado(
            solicitud_id, tipo_objeto, owner_name, table_name, objeto_name, estado_previo, fecha_pre
          ) VALUES (
            p_solicitud_id, 'TRIGGER', UPPER(TRIM(rc.dependencia_owner)), UPPER(TRIM(rc.table_name)), UPPER(TRIM(rc.dependencia_objeto)), 'ENABLED', SYSTIMESTAMP
          );
          BEGIN
            SELECT COUNT(*)
              INTO l_exists
              FROM dba_triggers t
             WHERE t.owner = UPPER(TRIM(rc.dependencia_owner))
               AND t.trigger_name = UPPER(TRIM(rc.dependencia_objeto));
          EXCEPTION
            WHEN OTHERS THEN
              l_exists := 0;
          END;

          IF l_exists > 0 THEN
            EXECUTE IMMEDIATE 'ALTER TRIGGER '||f_qname(rc.dependencia_owner)||'.'||f_qname(rc.dependencia_objeto)||' DISABLE';
            UPDATE tdm_mask_dep_estado
               SET deshabilitado_ok = 'Y'
             WHERE solicitud_id = p_solicitud_id
               AND tipo_objeto  = 'TRIGGER'
               AND owner_name   = UPPER(TRIM(rc.dependencia_owner))
               AND objeto_name  = UPPER(TRIM(rc.dependencia_objeto));
          ELSE
            UPDATE tdm_mask_dep_estado
               SET deshabilitado_ok = 'N',
                   habilitado_ok = 'Y'
             WHERE solicitud_id = p_solicitud_id
               AND tipo_objeto  = 'TRIGGER'
               AND owner_name   = UPPER(TRIM(rc.dependencia_owner))
               AND objeto_name  = UPPER(TRIM(rc.dependencia_objeto));
            proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_NOT_FOUND',
              'TRIGGER '||f_safe_name(rc.dependencia_owner)||'.'||f_safe_name(rc.dependencia_objeto)||' no existe'
            );
          END IF;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'WARN_DEP',
                        f_safe_name(rc.tipo_dependencia)||' '||f_safe_name(rc.dependencia_owner)||'.'||f_safe_name(rc.dependencia_objeto)||' => '||f_safe_err(SQLERRM));
          -- B.2: Registrar error de dependencia PRE en tdm_ejecucion_error
          proc_dm_log_ejec_error(
            p_ejecucion_id => p_ejecucion_id,
            p_solicitud_id => p_solicitud_id,
            p_owner_name   => rc.dependencia_owner,
            p_table_name   => rc.table_name,
            p_column_name  => NULL,
            p_etapa        => 'PRE_DEP',
            p_codigo_error => SQLCODE,
            p_mensaje      => SQLERRM,
            p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
          );
      END;
    END LOOP;

    COMMIT;
    proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'FIN', 'Dependencias deshabilitadas');
  END;

  PROCEDURE proc_dm_post_dep(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER
  ) IS
    l_owner  VARCHAR2(261);
    l_objeto VARCHAR2(261);
    l_tabla  VARCHAR2(261);
    l_accion_post VARCHAR2(100);
  BEGIN
    proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'POST', 'INICIO', 'Rehabilitando dependencias');

    FOR rc IN (
      SELECT owner_name, objeto_name
        FROM tdm_mask_dep_estado
       WHERE solicitud_id = p_solicitud_id
         AND tipo_objeto = 'TRIGGER'
         AND deshabilitado_ok = 'Y'
       ORDER BY owner_name, objeto_name
    ) LOOP
      l_owner := rc.owner_name; l_objeto := rc.objeto_name;
      l_accion_post := func_dm_dep_post_action(l_owner, NULL, l_owner, l_objeto, 'TRIGGER');
      IF l_accion_post IN ('SIN_ACCION','REVISAR') THEN
        proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST','SKIP_POST_POLICY',
                      'TRIGGER '||f_safe_name(l_owner)||'.'||f_safe_name(l_objeto)||
                      ' accion_post='||f_safe_name(l_accion_post)||
                      ' (REVISAR/SIN_ACCION=requiere revisión manual, no se ejecuta ENABLE)');
        CONTINUE;
      END IF;
      BEGIN
        EXECUTE IMMEDIATE 'ALTER TRIGGER '||f_qname(l_owner)||'.'||f_qname(l_objeto)||' ENABLE';
        UPDATE tdm_mask_dep_estado
           SET estado_posterior = SUBSTR('ENABLED',1,30), fecha_post = SYSTIMESTAMP, habilitado_ok = 'Y'
         WHERE solicitud_id = p_solicitud_id AND tipo_objeto='TRIGGER'
           AND owner_name=l_owner AND objeto_name=l_objeto;
      EXCEPTION WHEN OTHERS THEN
        UPDATE tdm_mask_dep_estado
           SET estado_posterior = SUBSTR('ERROR',1,30), fecha_post = SYSTIMESTAMP, habilitado_ok = 'N'
         WHERE solicitud_id = p_solicitud_id AND tipo_objeto='TRIGGER'
           AND owner_name=l_owner AND objeto_name=l_objeto;
        proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST','WARN_TRIGGER',
                      f_safe_name(l_owner)||'.'||f_safe_name(l_objeto)||' => '||f_safe_err(SQLERRM));
        -- B.2: Registrar error de dependencia POST en tdm_ejecucion_error
        proc_dm_log_ejec_error(
          p_ejecucion_id => p_ejecucion_id,
          p_solicitud_id => p_solicitud_id,
          p_owner_name   => l_owner,
          p_table_name   => NULL,
          p_column_name  => NULL,
          p_etapa        => 'POST_DEP_TRIGGER',
          p_codigo_error => SQLCODE,
          p_mensaje      => SQLERRM,
          p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
      END;
    END LOOP;

    FOR rc IN (
      SELECT d.owner_name, d.table_name, d.objeto_name
        FROM tdm_mask_dep_estado d
        LEFT JOIN dba_constraints c
          ON c.owner = d.owner_name AND c.constraint_name = d.objeto_name
       WHERE d.solicitud_id = p_solicitud_id
         AND d.tipo_objeto = 'CONSTRAINT'
         AND d.deshabilitado_ok = 'Y'
       ORDER BY CASE NVL(c.constraint_type, 'P')
                  WHEN 'P' THEN 1
                  WHEN 'U' THEN 2
                  WHEN 'C' THEN 3
                  ELSE 4
                END,
                d.owner_name, d.table_name, d.objeto_name
    ) LOOP
      l_owner := rc.owner_name; l_tabla := rc.table_name; l_objeto := rc.objeto_name;
      l_accion_post := func_dm_dep_post_action(l_owner, l_tabla, l_owner, l_objeto, 'CONSTRAINT');
      IF l_accion_post IN ('SIN_ACCION','REVISAR') THEN
        proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST','SKIP_POST_POLICY',
                      'CONSTRAINT '||f_safe_name(l_owner)||'.'||f_safe_name(l_tabla)||'.'||f_safe_name(l_objeto)||
                      ' accion_post='||f_safe_name(l_accion_post)||
                      ' (REVISAR/SIN_ACCION=requiere revisión manual, no se ejecuta ENABLE)');
        CONTINUE;
      END IF;
      BEGIN
        IF l_accion_post = 'ENABLE_VALIDATE' THEN
          EXECUTE IMMEDIATE 'ALTER TABLE '||f_qname(l_owner)||'.'||f_qname(l_tabla)||
                            ' ENABLE VALIDATE CONSTRAINT '||f_qname(l_objeto);
        ELSIF l_accion_post = 'ENABLE' THEN
          EXECUTE IMMEDIATE 'ALTER TABLE '||f_qname(l_owner)||'.'||f_qname(l_tabla)||
                            ' ENABLE CONSTRAINT '||f_qname(l_objeto);
        ELSE
          EXECUTE IMMEDIATE 'ALTER TABLE '||f_qname(l_owner)||'.'||f_qname(l_tabla)||
                            ' ENABLE NOVALIDATE CONSTRAINT '||f_qname(l_objeto);
        END IF;
        UPDATE tdm_mask_dep_estado
           SET estado_posterior = SUBSTR(l_accion_post,1,30), fecha_post = SYSTIMESTAMP, habilitado_ok = 'Y'
         WHERE solicitud_id = p_solicitud_id AND tipo_objeto='CONSTRAINT'
           AND owner_name=l_owner AND table_name=l_tabla AND objeto_name=l_objeto;
      EXCEPTION WHEN OTHERS THEN
        UPDATE tdm_mask_dep_estado
           SET estado_posterior = SUBSTR('ERROR',1,30), fecha_post = SYSTIMESTAMP, habilitado_ok = 'N'
         WHERE solicitud_id = p_solicitud_id AND tipo_objeto='CONSTRAINT'
           AND owner_name=l_owner AND table_name=l_tabla AND objeto_name=l_objeto;
        proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST','WARN_CONSTRAINT',
                      f_safe_name(l_owner)||'.'||f_safe_name(l_tabla)||'.'||f_safe_name(l_objeto)||' => '||f_safe_err(SQLERRM));
        -- B.2: Registrar error de dependencia POST en tdm_ejecucion_error
        proc_dm_log_ejec_error(
          p_ejecucion_id => p_ejecucion_id,
          p_solicitud_id => p_solicitud_id,
          p_owner_name   => l_owner,
          p_table_name   => l_tabla,
          p_column_name  => NULL,
          p_etapa        => 'POST_DEP_CONSTRAINT',
          p_codigo_error => SQLCODE,
          p_mensaje      => SQLERRM,
          p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
      END;
    END LOOP;

    COMMIT;
    proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'POST', 'FIN', 'Dependencias rehabilitadas');
  END;

  ------------------------------------------------------------------------------
  -- Máscara de una columna
  ------------------------------------------------------------------------------
  FUNCTION func_dm_min_len_identificador(p_identificador IN VARCHAR2) RETURN NUMBER DETERMINISTIC IS
    l_id VARCHAR2(100) := f_norm(p_identificador);
  BEGIN
    CASE l_id
      WHEN 'IDENTIFICADOR_IDENTIDAD' THEN RETURN 8; -- DNI/NIF/NIE mínimo útil
      WHEN 'IDENTIFICADOR_TELEFONO'  THEN RETURN 7;
      WHEN 'IDENTIFICADOR_EMAIL'     THEN RETURN 5; -- a@b.c
      WHEN 'IDENTIFICADOR_BANCARIO'  THEN RETURN 10;
      WHEN 'IDENTIFICADOR_NOMBRE'    THEN RETURN 2;
      WHEN 'IDENTIFICADOR_PERSONAL'  THEN RETURN 2;
      WHEN 'IDENTIFICADOR_DIRECCION' THEN RETURN 3;
      ELSE RETURN 1;
    END CASE;
  END;

  PROCEDURE proc_dm_upsert_excepcion_col(
    p_owner         IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_columna       IN VARCHAR2,
    p_accion        IN VARCHAR2,
    p_ident_forz    IN VARCHAR2,
    p_razon         IN VARCHAR2
  ) IS
    l_owner       VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla       VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna     VARCHAR2(128) := UPPER(TRIM(p_columna));
    l_ident_forz  VARCHAR2(50)  := CASE WHEN p_ident_forz IS NULL THEN NULL ELSE UPPER(TRIM(p_ident_forz)) END;
  BEGIN
    MERGE INTO tdm_excepcion_col t
    USING (
      SELECT l_owner owner_name,
             l_tabla table_name,
             l_columna column_name
        FROM dual
    ) s
    ON (
      t.owner_name = s.owner_name AND
      t.table_name = s.table_name AND
      t.column_name = s.column_name
    )
    WHEN MATCHED THEN UPDATE SET
      t.accion = SUBSTR(UPPER(NVL(p_accion,'EXCLUDE')),1,10),
      t.identificador_forz = CASE WHEN l_ident_forz IS NULL THEN t.identificador_forz ELSE SUBSTR(l_ident_forz,1,50) END,
      t.razon = SUBSTR(p_razon,1,1000),
      t.activa = 'Y'
    WHEN NOT MATCHED THEN INSERT (
      owner_name, table_name, column_name, accion, identificador_forz, razon, activa
    ) VALUES (
      l_owner, l_tabla, l_columna,
      SUBSTR(UPPER(NVL(p_accion,'EXCLUDE')),1,10),
      CASE WHEN l_ident_forz IS NULL THEN NULL ELSE SUBSTR(l_ident_forz,1,50) END,
      SUBSTR(p_razon,1,1000),
      'Y'
    );
    COMMIT;
  -- Sin EXCEPTION propio (2026-09-16): esta es la API con la que el DBA fija
  -- una excepcion EXCLUDE/FORCE por columna. Un WHEN OTHERS THEN NULL aqui
  -- devolvia "exito" aunque el MERGE no hubiera grabado nada - el DBA podia
  -- creer protegida (o forzada a un identificador) una columna que en
  -- realidad seguia con el tratamiento por defecto. Se deja propagar.
  END;

  PROCEDURE proc_dm_get_excepcion(
    p_owner         IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_columna       IN VARCHAR2,
    p_accion        OUT VARCHAR2,
    p_ident_forzado OUT VARCHAR2
  ) IS
    l_owner   VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla   VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna VARCHAR2(128) := UPPER(TRIM(p_columna));
  BEGIN
    p_accion := NULL;
    p_ident_forzado := NULL;
    SELECT accion, identificador_forz
      INTO p_accion, p_ident_forzado
      FROM tdm_excepcion_col
     WHERE owner_name = l_owner
       AND table_name = l_tabla
       AND column_name = l_columna
       AND activa = 'Y'
       AND ROWNUM = 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_accion := NULL;
      p_ident_forzado := NULL;
    WHEN OTHERS THEN
      p_accion := NULL;
      p_ident_forzado := NULL;
  END;

  PROCEDURE proc_dm_apl_col(
    p_solicitud_id  IN NUMBER,
    p_ejecucion_id  IN NUMBER,
    p_esquema       IN VARCHAR2,
    p_owner         IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_columna       IN VARCHAR2,
    p_identificador IN VARCHAR2
  ) IS
    l_sql      CLOB;
    l_rows     NUMBER;
    l_target   VARCHAR2(512);
    l_col_tipo VARCHAR2(128);
    l_expr     VARCHAR2(4000);
    l_accion   VARCHAR2(10);
    l_ident_forzado VARCHAR2(50);
    l_ident_final VARCHAR2(100);
    l_data_type dba_tab_columns.data_type%TYPE;
    l_char_len NUMBER;
    l_min_len  NUMBER;
    l_rows_retry NUMBER;
    l_owner    VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla    VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna  VARCHAR2(128) := UPPER(TRIM(p_columna));
  BEGIN
    l_target := f_norm(p_owner)||'.'||f_norm(p_tabla)||'.'||f_norm(p_columna);
    l_ident_final := f_norm(p_identificador);

    proc_dm_get_excepcion(p_owner,p_tabla,p_columna,l_accion,l_ident_forzado);
    IF l_ident_forzado IS NOT NULL THEN
      l_ident_final := f_norm(l_ident_forzado);
      proc_dm_trace(
        p_solicitud_id,
        p_ejecucion_id,
        'MASK',
        'EXCEPTION_FORCE',
        l_target||' identificador_forzado='||l_ident_final
      );
    END IF;

    IF f_norm(l_accion) = 'EXCLUDE' THEN
      proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','SKIP_EXCLUDE',l_target||' excluida por tdm_excepcion_col');
      RETURN;
    END IF;

    BEGIN
      -- 1) Priorizar metadata del snapshot analítico (tdm_columna_hist)
      SELECT data_type, data_length
        INTO l_data_type, l_char_len
        FROM tdm_columna_hist
       WHERE ejecucion_id = p_ejecucion_id
         AND owner_name   = l_owner
         AND table_name   = l_tabla
         AND column_name  = l_columna
         AND NVL(vigente,'Y') = 'Y'
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        BEGIN
          -- 2) Fallback al diccionario DBA_TAB_COLUMNS
          SELECT data_type, NVL(char_col_decl_length, data_length)
            INTO l_data_type, l_char_len
            FROM dba_tab_columns
           WHERE owner = l_owner
             AND table_name = l_tabla
             AND column_name = l_columna;
        EXCEPTION
          WHEN OTHERS THEN
            l_data_type := NULL;
            l_char_len := NULL;
        END;
      WHEN OTHERS THEN
        l_data_type := NULL;
        l_char_len := NULL;
    END;

    l_min_len := func_dm_min_len_identificador(l_ident_final);
    IF l_data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2')
       AND NVL(l_char_len,0) < l_min_len THEN
      proc_dm_upsert_excepcion_col(
        p_owner      => p_owner,
        p_tabla      => p_tabla,
        p_columna    => p_columna,
        p_accion     => 'EXCLUDE',
        p_ident_forz => NULL,
        p_razon      => 'AUTO-EXCLUDE: longitud columna ('||NVL(l_char_len,0)||') menor al mínimo para '||l_ident_final||' ('||l_min_len||')'
      );
      UPDATE tdm_columna_final
         SET enmascarar = 'N'
       WHERE owner_name = l_owner
         AND table_name = l_tabla
         AND column_name = l_columna;
      COMMIT;
      proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','SKIP_AUTO_LEN',l_target||' auto-excluida por longitud incompatible');
      RETURN;
    END IF;

    IF func_dm_tiene_regla(p_esquema,p_owner,p_tabla,p_columna,'DOC_SEGUN_TIPO') > 0 THEN
      l_col_tipo := func_dm_val_regla(p_esquema,p_owner,p_tabla,p_columna,'DOC_SEGUN_TIPO');
      l_sql := 'UPDATE '||f_qname(p_owner)||'.'||f_qname(p_tabla)||
               ' SET '||f_qname(p_columna)||' = pkg_dm_func_mask.func_especial_doc_segun_tipo('||f_qname(p_columna)||','||f_qname(l_col_tipo)||')' ||
               ' WHERE '||f_qname(p_columna)||' IS NOT NULL';
      proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, l_rows);

    ELSIF func_dm_tiene_regla(p_esquema,p_owner,p_tabla,p_columna,'DOC_UNIFICADO_MANTENER_1_Y_ULTIMO') > 0 THEN
      l_sql := 'UPDATE '||f_qname(p_owner)||'.'||f_qname(p_tabla)||
               ' SET '||f_qname(p_columna)||' = pkg_dm_func_mask.func_especial_doc_keep_ends('||f_qname(p_columna)||')' ||
               ' WHERE '||f_qname(p_columna)||' IS NOT NULL';
      proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, l_rows);

    ELSIF func_dm_tiene_regla(p_esquema,p_owner,p_tabla,p_columna,'IBAN_ES_CONTINUO') > 0 THEN
      -- C-01: NO truncar. func_especial_iban_continuo devuelve 24 chars exactos;
      -- si la columna fuera mas corta, ORA-12899 (fallo cerrado) mejor que corromper.
      l_sql := 'UPDATE '||f_qname(p_owner)||'.'||f_qname(p_tabla)||
               ' SET '||f_qname(p_columna)||' = pkg_dm_func_mask.func_especial_iban_continuo('||f_qname(p_columna)||')' ||
               ' WHERE '||f_qname(p_columna)||' IS NOT NULL';
      proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, l_rows);

    ELSE
      l_expr := f_expr_compatible(p_owner,p_tabla,p_columna,l_ident_final);
      l_sql := 'UPDATE '||f_qname(p_owner)||'.'||f_qname(p_tabla)||
               ' SET '||f_qname(p_columna)||' = '||l_expr||
               ' WHERE '||f_qname(p_columna)||' IS NOT NULL';
      proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, l_rows);
    END IF;

    COMMIT;

    proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','APPLY_COL',l_target||' filas='||l_rows);
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -1 THEN
        -- Colision de unicidad (ORA-00001). Con FF1 los dominios numericos son
        -- biyectivos y NO llegan aqui; si ocurre es una columna de TEXTO unica.
        -- Se auto-excluye (no se fabrica sufijo ORA_HASH, que rompia la FK).
        proc_dm_upsert_excepcion_col(
          p_owner      => p_owner,
          p_tabla      => p_tabla,
          p_columna    => p_columna,
          p_accion     => 'EXCLUDE',
          p_ident_forz => NULL,
          p_razon      => 'AUTO-EXCLUDE ORA-00001 (colision en dominio no biyectivo): '||SUBSTR(SQLERRM,1,820)
        );
        UPDATE tdm_columna_final
           SET enmascarar = 'N'
         WHERE owner_name = l_owner
           AND table_name = l_tabla
           AND column_name = l_columna;
        COMMIT;
        proc_dm_trace(
          p_solicitud_id, p_ejecucion_id, 'MASK', 'SKIP_ORA00001',
          l_target||' auto-excluida tras ORA-00001 (sin sufijo ORA_HASH)'
        );
      ELSIF SQLCODE = -12899 THEN
        proc_dm_upsert_excepcion_col(
          p_owner      => p_owner,
          p_tabla      => p_tabla,
          p_columna    => p_columna,
          p_accion     => 'EXCLUDE',
          p_ident_forz => NULL,
          p_razon      => 'AUTO-EXCLUDE ORA-12899 en enmascaramiento: '||SUBSTR(SQLERRM,1,850)
        );
        UPDATE tdm_columna_final
           SET enmascarar = 'N'
         WHERE owner_name = l_owner
           AND table_name = l_tabla
           AND column_name = l_columna;
        COMMIT;
        proc_dm_trace(
          p_solicitud_id,
          p_ejecucion_id,
          'MASK',
          'SKIP_ORA12899',
          l_target||' auto-excluida tras ORA-12899'
        );
      ELSIF SQLCODE = -6502 THEN
        IF l_data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2') AND NVL(l_char_len,0) > 0 THEN
          BEGIN
            -- Primer fallback: reutilizar librería oficial de enmascarado
            l_expr := 'SUBSTR(pkg_dm_func_mask.func_generico('''||
                      REPLACE(l_ident_final,'''','''''')||''','||f_qname(p_columna)||'),1,'||TO_CHAR(l_char_len)||')';
            l_sql := 'UPDATE '||f_qname(p_owner)||'.'||f_qname(p_tabla)||
                     ' SET '||f_qname(p_columna)||' = '||l_expr||
                     ' WHERE '||f_qname(p_columna)||' IS NOT NULL';
            BEGIN
              proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, l_rows_retry);
            EXCEPTION
              WHEN OTHERS THEN
                -- Segundo fallback: expresión SQL ultra-segura por tipo de identificador
                IF l_ident_final IN ('IDENTIFICADOR_PERSONAL','IDENTIFICADOR_NOMBRE') THEN
                  l_expr := 'SUBSTR(TRANSLATE(UPPER('||f_qname(p_columna)||'),'||
                            '''ABCDEFGHIJKLMNOPQRSTUVWXYZ'','||
                            '''QWERTYUIOPASDFGHJKLZXCVBNM''),1,'||TO_CHAR(l_char_len)||')';
                ELSIF l_ident_final = 'IDENTIFICADOR_DIRECCION' THEN
                  l_expr := 'SUBSTR(''Calle Ficticia N ''||TO_CHAR(MOD(ORA_HASH('||f_qname(p_columna)||'),999))||'', Zaragoza'',1,'||TO_CHAR(l_char_len)||')';
                ELSIF l_ident_final = 'IDENTIFICADOR_EMAIL' THEN
                  l_expr := 'SUBSTR(''usuario''||TO_CHAR(MOD(ORA_HASH('||f_qname(p_columna)||'),1000000))||''@correo.com'',1,'||TO_CHAR(l_char_len)||')';
                ELSIF l_ident_final = 'IDENTIFICADOR_TELEFONO' THEN
                  l_expr := 'SUBSTR(''6''||LPAD(TO_CHAR(MOD(ORA_HASH('||f_qname(p_columna)||'),100000000)),8,''0''),1,'||TO_CHAR(l_char_len)||')';
                ELSE
                  l_expr := 'SUBSTR(TRANSLATE(UPPER('||f_qname(p_columna)||'),'||
                            '''ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'','||
                            '''QWERTYUIOPASDFGHJKLZXCVBNM9876543210''),1,'||TO_CHAR(l_char_len)||')';
                END IF;
                l_sql := 'UPDATE '||f_qname(p_owner)||'.'||f_qname(p_tabla)||
                         ' SET '||f_qname(p_columna)||' = '||l_expr||
                         ' WHERE '||f_qname(p_columna)||' IS NOT NULL';
                proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, l_rows_retry);
            END;
            COMMIT;
            proc_dm_trace(
              p_solicitud_id,
              p_ejecucion_id,
              'MASK',
              'APPLY_COL_SAFE_FALLBACK',
              l_target||' filas='||l_rows_retry||' (fallback seguro tras ORA-06502)'
            );
          EXCEPTION
            WHEN OTHERS THEN
              proc_dm_upsert_excepcion_col(
                p_owner      => p_owner,
                p_tabla      => p_tabla,
                p_columna    => p_columna,
                p_accion     => 'EXCLUDE',
                p_ident_forz => NULL,
                p_razon      => 'AUTO-EXCLUDE ORA-06502 en enmascaramiento: '||SUBSTR(f_safe_err(SQLERRM),1,850)
              );
              UPDATE tdm_columna_final
                 SET enmascarar = 'N'
               WHERE owner_name = l_owner
                 AND table_name = l_tabla
                 AND column_name = l_columna;
              COMMIT;
              proc_dm_trace(
                p_solicitud_id,
                p_ejecucion_id,
                'MASK',
                'SKIP_ORA06502',
                l_target||' auto-excluida tras ORA-06502'
              );
          END;
        ELSE
          proc_dm_upsert_excepcion_col(
            p_owner      => p_owner,
            p_tabla      => p_tabla,
            p_columna    => p_columna,
            p_accion     => 'EXCLUDE',
            p_ident_forz => NULL,
            p_razon      => 'AUTO-EXCLUDE ORA-06502 en enmascaramiento: '||SUBSTR(f_safe_err(SQLERRM),1,850)
          );
          UPDATE tdm_columna_final
             SET enmascarar = 'N'
           WHERE owner_name = l_owner
             AND table_name = l_tabla
             AND column_name = l_columna;
          COMMIT;
          proc_dm_trace(
            p_solicitud_id,
            p_ejecucion_id,
            'MASK',
            'SKIP_ORA06502',
            l_target||' auto-excluida tras ORA-06502'
          );
        END IF;
      ELSE
        RAISE;
      END IF;
  END;

  PROCEDURE proc_dm_post_sync(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  ) IS
    l_sql CLOB;
    l_rows NUMBER;
    l_diff NUMBER;
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_dest_data_type VARCHAR2(30);
    l_dest_len       NUMBER;
    l_len_conflicts  NUMBER;
    l_max_src_len    NUMBER;
  BEGIN
    FOR rc IN (
      SELECT tabla_origen, columna_join_origen, tabla_destino, columna_join_destino,
             columna_origen, columna_destino, prioridad
        FROM tdm_mask_relacion_sync
       WHERE esquema_objetivo = l_esquema
         AND activa = 'Y'
       ORDER BY prioridad
    ) LOOP
      BEGIN
        BEGIN
          SELECT c.data_type, c.data_length
            INTO l_dest_data_type, l_dest_len
            FROM dba_tab_columns c
           WHERE c.owner = l_esquema
             AND c.table_name = rc.tabla_destino
             AND c.column_name = rc.columna_destino;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            l_dest_data_type := NULL;
            l_dest_len       := NULL;
        END;

        IF l_dest_data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2') AND NVL(l_dest_len,0) > 0 THEN
          l_sql :=
            'SELECT COUNT(*), NVL(MAX(LENGTH(TO_CHAR(s.'||f_qname(rc.columna_origen)||'))),0) '||
            '  FROM '||f_qname(p_esquema)||'.'||f_qname(rc.tabla_destino)||' d '||
            '  JOIN '||f_qname(p_esquema)||'.'||f_qname(rc.tabla_origen)||' s '||
            '    ON s.'||f_qname(rc.columna_join_origen)||' = d.'||f_qname(rc.columna_join_destino)||' '||
            ' WHERE s.'||f_qname(rc.columna_origen)||' IS NOT NULL '||
            '   AND LENGTH(TO_CHAR(s.'||f_qname(rc.columna_origen)||')) > '||TO_CHAR(l_dest_len);
          EXECUTE IMMEDIATE l_sql INTO l_len_conflicts, l_max_src_len;

          IF NVL(l_len_conflicts,0) > 0 THEN
            proc_dm_trace(
              p_solicitud_id,p_ejecucion_id,'POST_SYNC','WARN_SYNC_LEN',
              rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||
              ' skip por longitud. filas_conflictivas='||l_len_conflicts||
              ' max_len_origen='||NVL(l_max_src_len,0)||
              ' max_len_destino='||l_dest_len
            );
            CONTINUE;
          END IF;
        END IF;

        l_sql :=
          'UPDATE '||f_qname(p_esquema)||'.'||f_qname(rc.tabla_destino)||' d '||
          'SET '||f_qname(rc.columna_destino)||' = ('||
          '  SELECT s.'||f_qname(rc.columna_origen)||' FROM '||f_qname(p_esquema)||'.'||f_qname(rc.tabla_origen)||' s '||
          '   WHERE s.'||f_qname(rc.columna_join_origen)||' = d.'||f_qname(rc.columna_join_destino)||' ) '||
          'WHERE EXISTS (SELECT 1 FROM '||f_qname(p_esquema)||'.'||f_qname(rc.tabla_origen)||' s '||
          '               WHERE s.'||f_qname(rc.columna_join_origen)||' = d.'||f_qname(rc.columna_join_destino)||')';
        proc_dm_ejecuta_update_seguro(p_esquema, rc.tabla_destino, rc.columna_destino, l_sql, l_rows);
        COMMIT;
        proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST_SYNC','SYNC',
                      rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' filas='||l_rows);
      EXCEPTION
        WHEN OTHERS THEN
          proc_dm_trace(
            p_solicitud_id,p_ejecucion_id,'POST_SYNC','WARN_SYNC',
            rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' => '||f_safe_err(SQLERRM)
          );
          CONTINUE;
      END;

      BEGIN
        -- Verificación de consistencia padre/hijo según la relación definida
        l_sql :=
          'SELECT COUNT(*) FROM '||f_qname(p_esquema)||'.'||f_qname(rc.tabla_destino)||' d '||
          'JOIN '||f_qname(p_esquema)||'.'||f_qname(rc.tabla_origen)||' s '||
          '  ON s.'||f_qname(rc.columna_join_origen)||' = d.'||f_qname(rc.columna_join_destino)||' '||
          'WHERE NVL(TO_CHAR(d.'||f_qname(rc.columna_destino)||'),''#NULL#'') '||
          '   <> NVL(TO_CHAR(s.'||f_qname(rc.columna_origen)||'),''#NULL#'')';
        EXECUTE IMMEDIATE l_sql INTO l_diff;
        IF NVL(l_diff,0) = 0 THEN
          proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST_SYNC','SYNC_OK',
                        rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' diferencias=0');
        ELSE
          proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST_SYNC','SYNC_MISMATCH',
                        rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' diferencias='||l_diff);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          proc_dm_trace(
            p_solicitud_id,p_ejecucion_id,'POST_SYNC','WARN_SYNC_CHECK',
            rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' => '||f_safe_err(SQLERRM)
          );
      END;
    END LOOP;
  END;

  PROCEDURE proc_dm_mask_cat(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_reproceso    IN VARCHAR2 DEFAULT 'N',
    p_error_count  OUT NUMBER
  ) IS
    l_total_cols NUMBER;
    l_proc_cols  NUMBER := 0;
    l_total_tabs NUMBER;
    l_proc_tabs  NUMBER := 0;
    l_last_tab   VARCHAR2(128);
    l_pct        NUMBER;
    l_esquema    VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_reproceso  VARCHAR2(1) := UPPER(TRIM(NVL(p_reproceso,'N')));
    l_msg_noop   VARCHAR2(1900);
    l_total_rows NUMBER := 0;
    l_has_final  NUMBER := 0;
  BEGIN
    p_error_count := 0;

    SELECT CASE WHEN EXISTS (
             SELECT 1 FROM tdm_columna_final WHERE owner_name = l_esquema AND enmascarar = 'Y'
           ) THEN 1 ELSE 0 END
      INTO l_has_final
      FROM dual;

    IF l_has_final = 1 THEN
      SELECT COUNT(*), COUNT(DISTINCT table_name)
        INTO l_total_cols, l_total_tabs
        FROM tdm_columna_final f
       WHERE owner_name = l_esquema
         AND enmascarar = 'Y'
         AND (
           l_reproceso = 'Y' OR
           NOT EXISTS (
             SELECT 1 FROM tdm_mask_trace t
              WHERE (
                      (g_resume_base_solicitud IS NOT NULL AND t.solicitud_id = g_resume_base_solicitud) OR
                      (g_resume_base_solicitud IS NULL AND t.ejecucion_id = p_ejecucion_id)
                    )
                AND t.fase = 'MASK'
                AND t.paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
                AND t.detalle LIKE f.owner_name||'.'||f.table_name||'.'||f.column_name||' filas=%'
           )
         )
         AND NOT EXISTS (
           SELECT 1 FROM tdm_excepcion_col e
            WHERE f_norm(e.owner_name) = f.owner_name
              AND e.table_name = f.table_name
              AND e.column_name = f.column_name
              AND f_norm(e.activa) = 'Y'
              AND f_norm(e.accion) = 'EXCLUDE'
         );
    ELSE
      SELECT COUNT(*), COUNT(DISTINCT table_name)
        INTO l_total_cols, l_total_tabs
        FROM tdm_excepcion_col e
       WHERE f_norm(e.owner_name) = l_esquema
         AND f_norm(e.activa) = 'Y'
         AND f_norm(e.accion) = 'FORCE'
         AND e.identificador_forz IS NOT NULL
         AND (
           l_reproceso = 'Y' OR
           NOT EXISTS (
             SELECT 1 FROM tdm_mask_trace t
              WHERE (
                      (g_resume_base_solicitud IS NOT NULL AND t.solicitud_id = g_resume_base_solicitud) OR
                      (g_resume_base_solicitud IS NULL AND t.ejecucion_id = p_ejecucion_id)
                    )
                AND t.fase = 'MASK'
                AND t.paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
                AND t.detalle LIKE f_norm(e.owner_name)||'.'||f_norm(e.table_name)||'.'||f_norm(e.column_name)||' filas=%'
           )
         )
         AND EXISTS (
           SELECT 1 FROM dba_tab_columns c
            WHERE c.owner = f_norm(e.owner_name)
              AND c.table_name = f_norm(e.table_name)
              AND c.column_name = f_norm(e.column_name)
         );
    END IF;

    IF NVL(l_total_cols,0) = 0 THEN
      IF l_reproceso = 'Y' THEN
        l_msg_noop := 'No hay columnas configuradas/pendientes para enmascarar en reproceso completo.';
      ELSE
        l_msg_noop := 'No hay columnas pendientes por enmascarar para esta ejecución. '||
                      'Si deseas reproceso completo, ejecuta p_dm_enmascara('||TO_CHAR(p_ejecucion_id)||',''Y'').';
      END IF;

      proc_dm_trace(
        p_solicitud_id,
        p_ejecucion_id,
        'MASK',
        'NOOP',
        l_msg_noop
      );
      proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','FINALIZADO',100,0,0,0,0,NULL,'NOOP_MASK');
      RETURN;
    END IF;

    IF l_has_final = 1 THEN
      FOR tskip IN (
        SELECT owner_name, table_name
          FROM tdm_columna_final f
         WHERE owner_name = l_esquema
           AND enmascarar = 'Y'
         GROUP BY owner_name, table_name
        HAVING COUNT(*) = SUM(
                 CASE WHEN EXISTS (
                   SELECT 1 FROM tdm_excepcion_col e
                    WHERE f_norm(e.owner_name) = f.owner_name
                      AND e.table_name = f.table_name
                      AND e.column_name = f.column_name
                      AND f_norm(e.activa) = 'Y'
                      AND f_norm(e.accion) = 'EXCLUDE'
                 ) THEN 1 ELSE 0 END
               )
      ) LOOP
        proc_dm_trace(
          p_solicitud_id,
          p_ejecucion_id,
          'MASK',
          'SKIP_TABLE',
          tskip.owner_name||'.'||tskip.table_name||' omitida: todas las columnas están EXCLUDE'
        );
      END LOOP;
    END IF;

    proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',0,l_total_tabs,0,l_total_cols,0,NULL,'INICIO_MASK');

    IF l_has_final = 1 THEN
      FOR rc IN (
        SELECT owner_name, table_name, column_name, identificador
          FROM tdm_columna_final f
         WHERE owner_name = l_esquema
           AND enmascarar = 'Y'
           AND (
             l_reproceso = 'Y' OR
             NOT EXISTS (
               SELECT 1 FROM tdm_mask_trace t
                WHERE (
                        (g_resume_base_solicitud IS NOT NULL AND t.solicitud_id = g_resume_base_solicitud) OR
                        (g_resume_base_solicitud IS NULL AND t.ejecucion_id = p_ejecucion_id)
                      )
                  AND t.fase = 'MASK'
                  AND t.paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
                  AND t.detalle LIKE f.owner_name||'.'||f.table_name||'.'||f.column_name||' filas=%'
             )
           )
           AND NOT EXISTS (
             SELECT 1 FROM tdm_excepcion_col e
              WHERE f_norm(e.owner_name) = f.owner_name
                AND e.table_name = f.table_name
                AND e.column_name = f.column_name
                AND f_norm(e.activa) = 'Y'
                AND f_norm(e.accion) = 'EXCLUDE'
           )
         ORDER BY owner_name, table_name, column_name
      ) LOOP
        proc_dm_chk_cancel(p_solicitud_id);

        IF l_last_tab IS NULL OR l_last_tab <> rc.table_name THEN
          l_last_tab := rc.table_name;
          l_proc_tabs := l_proc_tabs + 1;
        END IF;

        BEGIN
          proc_dm_apl_col(p_solicitud_id,p_ejecucion_id,p_esquema,rc.owner_name,rc.table_name,rc.column_name,rc.identificador);
        EXCEPTION
          WHEN OTHERS THEN
            p_error_count := p_error_count + 1;
            proc_dm_log_ejec_error(p_ejecucion_id, rc.owner_name, rc.table_name, rc.column_name, 'MASK_APPLY', SQLCODE, SQLERRM, NULL);
            proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'MASK', 'ERROR_COL', rc.table_name||'.'||rc.column_name||' falló: '||SQLERRM);
        END;

        l_proc_cols := l_proc_cols + 1;
        l_pct := CASE WHEN l_total_cols > 0 THEN ROUND((l_proc_cols*100)/l_total_cols,2) ELSE 0 END;

        proc_dm_upd_sol(p_solicitud_id,'EN_PROCESO','MASK',rc.table_name||'.'||rc.column_name,'Aplicando enmascaramiento');
        BEGIN
          UPDATE tdm_mask_solicitud
             SET tablas_procesadas   = l_proc_tabs,
                 columnas_procesadas = l_proc_cols,
                 ultima_tabla        = rc.table_name,
                 ultima_columna      = rc.column_name,
                 heartbeat_ts        = SYSTIMESTAMP
           WHERE solicitud_id = p_solicitud_id;
          COMMIT;
        EXCEPTION
          WHEN OTHERS THEN NULL;
        END;
        proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',l_pct,l_total_tabs,l_proc_tabs,l_total_cols,l_proc_cols,
                         rc.owner_name||'.'||rc.table_name||'.'||rc.column_name,'MASK');
      END LOOP;
    ELSE
      FOR rc IN (
        SELECT f_norm(e.owner_name) as owner_name, f_norm(e.table_name) as table_name,
               f_norm(e.column_name) as column_name, e.identificador_forz as identificador
          FROM tdm_excepcion_col e
         WHERE f_norm(e.owner_name) = l_esquema
           AND f_norm(e.activa) = 'Y'
           AND f_norm(e.accion) = 'FORCE'
           AND e.identificador_forz IS NOT NULL
           AND (
             l_reproceso = 'Y' OR
             NOT EXISTS (
               SELECT 1 FROM tdm_mask_trace t
                WHERE (
                        (g_resume_base_solicitud IS NOT NULL AND t.solicitud_id = g_resume_base_solicitud) OR
                        (g_resume_base_solicitud IS NULL AND t.ejecucion_id = p_ejecucion_id)
                      )
                  AND t.fase = 'MASK'
                  AND t.paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
                  AND t.detalle LIKE f_norm(e.owner_name)||'.'||f_norm(e.table_name)||'.'||f_norm(e.column_name)||' filas=%'
             )
           )
           AND EXISTS (
             SELECT 1 FROM dba_tab_columns c
              WHERE c.owner = f_norm(e.owner_name)
                AND c.table_name = f_norm(e.table_name)
                AND c.column_name = f_norm(e.column_name)
           )
         ORDER BY owner_name, table_name, column_name
      ) LOOP
        proc_dm_chk_cancel(p_solicitud_id);

        IF l_last_tab IS NULL OR l_last_tab <> rc.table_name THEN
          l_last_tab := rc.table_name;
          l_proc_tabs := l_proc_tabs + 1;
        END IF;

        BEGIN
          proc_dm_apl_col(p_solicitud_id,p_ejecucion_id,p_esquema,rc.owner_name,rc.table_name,rc.column_name,rc.identificador);
        EXCEPTION
          WHEN OTHERS THEN
            p_error_count := p_error_count + 1;
            proc_dm_log_ejec_error(p_ejecucion_id, rc.owner_name, rc.table_name, rc.column_name, 'MASK_APPLY', SQLCODE, SQLERRM, NULL);
            proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'MASK', 'ERROR_COL', rc.table_name||'.'||rc.column_name||' falló: '||SQLERRM);
        END;

        l_proc_cols := l_proc_cols + 1;
        l_pct := CASE WHEN l_total_cols > 0 THEN ROUND((l_proc_cols*100)/l_total_cols,2) ELSE 0 END;

        proc_dm_upd_sol(p_solicitud_id,'EN_PROCESO','MASK',rc.table_name||'.'||rc.column_name,'Aplicando enmascaramiento');
        BEGIN
          UPDATE tdm_mask_solicitud
             SET tablas_procesadas   = l_proc_tabs,
                 columnas_procesadas = l_proc_cols,
                 ultima_tabla        = rc.table_name,
                 ultima_columna      = rc.column_name,
                 heartbeat_ts        = SYSTIMESTAMP
           WHERE solicitud_id = p_solicitud_id;
          COMMIT;
        EXCEPTION
          WHEN OTHERS THEN NULL;
        END;
        proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',l_pct,l_total_tabs,l_proc_tabs,l_total_cols,l_proc_cols,
                         rc.owner_name||'.'||rc.table_name||'.'||rc.column_name,'MASK');
      END LOOP;
    END IF;

    BEGIN
      SELECT NVL(SUM(TO_NUMBER(REGEXP_SUBSTR(t.detalle,'filas=([0-9]+)',1,1,NULL,1))),0)
        INTO l_total_rows
        FROM tdm_mask_trace t
       WHERE t.solicitud_id = p_solicitud_id
         AND t.fase = 'MASK'
         AND t.paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
         AND REGEXP_LIKE(t.detalle,'filas=[0-9]+');
    EXCEPTION
      WHEN OTHERS THEN
        l_total_rows := 0;
    END;

    proc_dm_trace(
      p_solicitud_id,
      p_ejecucion_id,
      'MASK',
      'RESUMEN',
      'Columnas procesadas='||TO_CHAR(l_proc_cols)||
      ', tablas procesadas='||TO_CHAR(l_proc_tabs)||
      ', total_registros_afectados='||TO_CHAR(NVL(l_total_rows,0))
    );

    BEGIN
      UPDATE tdm_mask_solicitud
         SET filas_procesadas     = NVL(l_total_rows,0),
             tablas_procesadas    = l_proc_tabs,
             columnas_procesadas  = l_proc_cols,
             heartbeat_ts         = SYSTIMESTAMP
       WHERE solicitud_id = p_solicitud_id;
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN NULL;
    END;
  END;

  ------------------------------------------------------------------------------
  -- Públicos del spec
  ------------------------------------------------------------------------------
  PROCEDURE p_dm_enmascara(
    p_ejecucion_id IN NUMBER,
    p_reproceso    IN VARCHAR2 DEFAULT 'N',
    p_commit_lote  IN NUMBER DEFAULT 1000
  ) IS
    l_solicitud_id NUMBER;
    l_esquema      VARCHAR2(128);
    l_err          VARCHAR2(1900 CHAR);
    l_err_code     NUMBER;
    l_err_stack    VARCHAR2(1900 CHAR);
    l_err_bt       VARCHAR2(1900 CHAR);
    l_err_call     VARCHAR2(1900 CHAR);
    l_reproceso    VARCHAR2(1) := UPPER(TRIM(NVL(p_reproceso,'N')));
    l_mask_errors  NUMBER := 0;
    l_invalidos_pre NUMBER := 0;
    l_invalidos_post NUMBER := 0;
    l_invalidos_nuevos NUMBER := 0;
    l_cons_mal       NUMBER := 0;
  BEGIN
    proc_dm_validar_base;
    DBMS_APPLICATION_INFO.SET_MODULE('PKG_DM_ENMASCARAR','P_DM_ENMASCARA');
    proc_dm_close_sol_open(p_ejecucion_id);
    proc_dm_refresca_sesion(p_ejecucion_id);

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

    l_esquema := func_dm_esquema(p_ejecucion_id);

    -- B.3: Capturar conteo baseline de objetos inválidos del esquema
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
    proc_dm_validar_reingreso_mask(p_ejecucion_id,l_esquema,l_reproceso);
    proc_dm_validar_concurrencia(p_ejecucion_id,l_esquema);

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

    l_solicitud_id := func_dm_crea_sol(
      p_ejecucion_id      => p_ejecucion_id,
      p_esquema           => l_esquema,
      p_detalle           => 'Enmascaramiento final; rollback via import',
      p_forzar_reproceso  => l_reproceso
    );
    BEGIN
      UPDATE tdm_mask_solicitud s
         SET (s.sesion_sid, s.sesion_serial) = (
               SELECT e.sesion_sid, e.sesion_serial
                 FROM tdm_ejecucion e
                WHERE e.ejecucion_id = p_ejecucion_id
             )
       WHERE s.solicitud_id = l_solicitud_id;
      -- Limpieza (2026-09-16): igual que en func_dm_crea_sol, aqui habia un
      -- EXECUTE IMMEDIATE contra TDM_MASK_SOLICITUD.FORZAR_FULL (columna
      -- inexistente; la real es FORZAR_REPROCESO). Fallaba con ORA-00904 en
      -- cada llamada y quedaba silenciado - codigo muerto eliminado. El
      -- flag de reproceso ya se fija correctamente via
      -- p_forzar_reproceso=>l_reproceso al crear la solicitud, arriba.
      UPDATE tdm_mask_solicitud
         SET cancel_requested = 'N'
       WHERE solicitud_id = l_solicitud_id;
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN NULL;   -- actualizacion de sesion/telemetria, no bloquea el enmascarado
    END;

    proc_dm_trace(l_solicitud_id,p_ejecucion_id,'INI','INICIO','Esquema='||l_esquema);
    proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',0,NULL,NULL,NULL,NULL,l_esquema,'INICIO');

    proc_dm_pre_dep(l_solicitud_id,p_ejecucion_id,l_esquema);

    -- A.1: Re-propagar dominios referenciales con la validación final del cliente antes de enmascarar
    --
    -- Fail-open corregido (auditoria 2026-09-16): este bloque solo trazaba el
    -- error y dejaba que el flujo siguiera hacia pepper y masking aunque la
    -- propagacion de dominios FK hubiera fallado por completo. La garantia
    -- de integridad referencial es tan critica como el pepper (que si hace
    -- RAISE unas lineas mas abajo) - un fallo aqui debe abortar la campana,
    -- no continuar en silencio con dominios FK potencialmente inconsistentes.
    BEGIN
      proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_START', 'Recalculando dominios FK con la validacion del cliente');
      pkg_dm_descubrimiento.proc_dm_propaga_dominios(l_esquema, l_solicitud_id, p_ejecucion_id);
      proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_END', 'Dominios FK propagados con exito');
    EXCEPTION
      WHEN OTHERS THEN
        proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_ERR', 'Error en propagacion referencial: '||SQLERRM);
        RAISE;   -- sin propagacion valida no se puede garantizar la integridad FK
    END;

    -- Generar la semilla efimera (pepper) ANTES de enmascarar. Idempotente y con
    -- COMMIT propio para que las sesiones paralelas lean la misma clave AES (FF1).
    BEGIN
      proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PEPPER_START', 'Preparando semilla efimera.');
      proc_dm_pepper_generar(p_ejecucion_id);
      proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PEPPER_END', 'Semilla efimera lista.');
    EXCEPTION
      WHEN OTHERS THEN
        proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PEPPER_ERR', 'Error preparando semilla: '||SQLERRM);
        RAISE;   -- sin pepper no se puede enmascarar de forma segura
    END;

    BEGIN
      proc_dm_mask_cat(l_solicitud_id,p_ejecucion_id,l_esquema,l_reproceso,l_mask_errors);
    EXCEPTION
      WHEN OTHERS THEN
        l_mask_errors := l_mask_errors + 1;
        proc_dm_log_ejec_error(p_ejecucion_id, l_esquema, NULL, NULL, 'MASK_CAT', SQLCODE, SQLERRM, NULL, l_solicitud_id);
        proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'ERROR_CAT', 'Error en proc_dm_mask_cat: '||SQLERRM);
    END;

    BEGIN
      proc_dm_post_sync(l_solicitud_id,p_ejecucion_id,l_esquema);
    EXCEPTION
      WHEN OTHERS THEN
        l_mask_errors := l_mask_errors + 1;
        proc_dm_log_ejec_error(p_ejecucion_id, l_esquema, NULL, NULL, 'POST_SYNC', SQLCODE, SQLERRM, NULL, l_solicitud_id);
        proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'POST_SYNC', 'ERROR_SYNC', 'Error en proc_dm_post_sync: '||SQLERRM);
    END;

    proc_dm_post_dep(l_solicitud_id,p_ejecucion_id);

    -- B.3: Control de dependencias no rehabilitadas e invalidación de objetos (con baseline)
    BEGIN
      SELECT COUNT(*)
        INTO l_cons_mal
        FROM tdm_mask_dep_estado d
        JOIN dba_constraints c
          ON c.owner = d.owner_name AND c.constraint_name = d.objeto_name
       WHERE d.solicitud_id = l_solicitud_id
         AND d.tipo_objeto  = 'CONSTRAINT'
         AND d.estado_previo = 'ENABLED'
         AND c.status <> 'ENABLED';
    EXCEPTION
      WHEN OTHERS THEN
        l_cons_mal := 0;
        proc_dm_log_ejec_error(
          p_ejecucion_id => p_ejecucion_id,
          p_solicitud_id => l_solicitud_id,
          p_owner_name   => l_esquema,
          p_table_name   => NULL,
          p_column_name  => NULL,
          p_etapa        => 'POST_CHECK_CONSTRAINTS',
          p_codigo_error => SQLCODE,
          p_mensaje      => 'Error consultando constraints no rehabilitadas: '||SQLERRM,
          p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
    END;

    -- Recompilar esquema de manera silenciosa para restaurar estado de objetos dependientes
    DECLARE
      l_invalid_count NUMBER := 9999;
      l_prev_invalid_count NUMBER := 9999;
      l_sql_recomp VARCHAR2(1000);
    BEGIN
      LOOP
        SELECT COUNT(*) INTO l_invalid_count
          FROM dba_objects
         WHERE owner = l_esquema
           AND status = 'INVALID';
           
        EXIT WHEN l_invalid_count = 0 OR l_invalid_count = l_prev_invalid_count;
        l_prev_invalid_count := l_invalid_count;
        
        FOR r IN (
          SELECT object_type, object_name
            FROM dba_objects
           WHERE owner = l_esquema
             AND status = 'INVALID'
           ORDER BY CASE object_type
                      WHEN 'PACKAGE' THEN 1
                      WHEN 'TYPE' THEN 2
                      WHEN 'VIEW' THEN 3
                      WHEN 'PACKAGE BODY' THEN 4
                      WHEN 'PROCEDURE' THEN 5
                      WHEN 'FUNCTION' THEN 6
                      WHEN 'TRIGGER' THEN 7
                      ELSE 8
                    END, object_name
        ) LOOP
          BEGIN
            IF r.object_type = 'PACKAGE BODY' THEN
              l_sql_recomp := 'ALTER PACKAGE "'||l_esquema||'"."'||r.object_name||'" COMPILE BODY';
            ELSIF r.object_type = 'TYPE BODY' THEN
              l_sql_recomp := 'ALTER TYPE "'||l_esquema||'"."'||r.object_name||'" COMPILE BODY';
            ELSE
              l_sql_recomp := 'ALTER '||r.object_type||' "'||l_esquema||'"."'||r.object_name||'" COMPILE';
            END IF;
            EXECUTE IMMEDIATE l_sql_recomp;
          EXCEPTION
            WHEN OTHERS THEN
              NULL;
          END;
        END LOOP;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;

    BEGIN
      SELECT COUNT(*)
        INTO l_invalidos_post
        FROM dba_objects
       WHERE owner = l_esquema
         AND status = 'INVALID';
      l_invalidos_nuevos := GREATEST(l_invalidos_post - l_invalidos_pre, 0);
    EXCEPTION
      WHEN OTHERS THEN
        l_invalidos_nuevos := 0;
        proc_dm_log_ejec_error(
          p_ejecucion_id => p_ejecucion_id,
          p_solicitud_id => l_solicitud_id,
          p_owner_name   => l_esquema,
          p_table_name   => NULL,
          p_column_name  => NULL,
          p_etapa        => 'POST_CHECK_INVALIDOS',
          p_codigo_error => SQLCODE,
          p_mensaje      => 'Error consultando delta de objetos invalidos: '||SQLERRM,
          p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
    END;

    IF l_invalidos_nuevos > 0 OR l_cons_mal > 0 THEN
      l_mask_errors := l_mask_errors + l_invalidos_nuevos + l_cons_mal;
      proc_dm_trace(
        l_solicitud_id,
        p_ejecucion_id,
        'POST',
        'POST_CHECK_INVALID',
        'Nuevos objetos INVALID='||l_invalidos_nuevos||' (pre='||l_invalidos_pre||', post='||l_invalidos_post||') ; constraints no ENABLED='||l_cons_mal
      );
      proc_dm_log_ejec_error(
        p_ejecucion_id => p_ejecucion_id,
        p_solicitud_id => l_solicitud_id,
        p_owner_name   => l_esquema,
        p_table_name   => NULL,
        p_column_name  => NULL,
        p_etapa        => 'POST_CHECK',
        p_codigo_error => -20203,
        p_mensaje      => 'Invalidez tras rehabilitar: nuevos INVALID='||l_invalidos_nuevos||' cons_no_enabled='||l_cons_mal,
        p_backtrace    => NULL
      );
    END IF;

    -- A-06 (fallo cerrado): una columna sensible auto-excluida por colision es PII
    -- SIN enmascarar. Se cuenta como error para IMPEDIR FINALIZADO y, por dependencia
    -- (pkg_dm_export.p_export_mask exige estado FINALIZADO), tambien el export.
    DECLARE
      l_pii_sin_masc NUMBER;
    BEGIN
      SELECT COUNT(*) INTO l_pii_sin_masc
        FROM tdm_mask_trace
       WHERE solicitud_id = l_solicitud_id
         AND paso = 'SKIP_ORA00001';
      IF NVL(l_pii_sin_masc,0) > 0 THEN
        l_mask_errors := NVL(l_mask_errors,0) + l_pii_sin_masc;
        proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','PII_SIN_ENMASCARAR',
          l_pii_sin_masc||' columna(s) sensible(s) auto-excluida(s) por colision (ORA-00001): '||
          'NO se permite FINALIZADO ni export. Reclasificar a identificador biyectivo y reprocesar.');
      END IF;
    END;

    IF l_mask_errors > 0 THEN
      proc_dm_upd_sol(l_solicitud_id,'ERROR','FIN','ERROR','Proceso finalizado con '||l_mask_errors||' errores','Y');
      proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','ERROR',100,NULL,NULL,NULL,NULL,NULL,'CON_ERRORES');
      proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','ERROR','Enmascaramiento finalizado con '||l_mask_errors||' errores');
    ELSE
      proc_dm_upd_sol(l_solicitud_id,'FINALIZADO','FIN','FINALIZADO','Proceso finalizado correctamente','Y');
      proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','FINALIZADO',100,NULL,NULL,NULL,NULL,NULL,'FINALIZADO');
      proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','OK','Enmascaramiento finalizado');
    END IF;

    DBMS_APPLICATION_INFO.SET_MODULE(NULL,NULL);
  EXCEPTION
    WHEN OTHERS THEN
      l_err_code := SQLCODE;
      l_err_stack := f_safe_err(DBMS_UTILITY.FORMAT_ERROR_STACK);
      l_err_bt    := f_safe_err(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      l_err_call  := f_safe_err(DBMS_UTILITY.FORMAT_CALL_STACK);
      l_err := '['||TO_CHAR(l_err_code)||'] '||l_err_stack||' | BT='||l_err_bt;
      BEGIN
        IF l_solicitud_id IS NOT NULL THEN
          proc_dm_post_dep(l_solicitud_id,p_ejecucion_id);
          proc_dm_upd_sol(l_solicitud_id,
                          CASE WHEN l_err_code = -20081 THEN 'CANCELADO' ELSE 'ERROR' END,
                          'ERROR','ERROR',l_err,'Y');
          proc_dm_trace(l_solicitud_id,p_ejecucion_id,'ERROR','ERROR',l_err);
        END IF;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;

      proc_dm_log_ejec_error(
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

      proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO',CASE WHEN l_err_code = -20081 THEN 'CANCELADO' ELSE 'ERROR' END,
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

  PROCEDURE p_mask_cancelar(p_ejecucion_id IN NUMBER) IS
  BEGIN
    UPDATE tdm_mask_solicitud
       SET cancel_requested = 'Y',
           heartbeat_ts = SYSTIMESTAMP,
           detalle = SUBSTR(NVL(detalle,'')||' | Cancelacion solicitada manualmente',1,3900)
     WHERE ejecucion_id = p_ejecucion_id
       AND estado IN ('EN_PROCESO','PENDIENTE','REANUDANDO');
    COMMIT;
  END;

  PROCEDURE p_mask_reanudar(
    p_ejecucion_id IN NUMBER,
    p_commit_lote  IN NUMBER DEFAULT 1000
  ) IS
    l_prev_solicitud NUMBER;
  BEGIN
    SELECT MAX(solicitud_id)
      INTO l_prev_solicitud
      FROM tdm_mask_solicitud
     WHERE ejecucion_id = p_ejecucion_id;

    g_resume_base_solicitud := l_prev_solicitud;
    p_dm_enmascara(p_ejecucion_id => p_ejecucion_id, p_reproceso => 'N', p_commit_lote => p_commit_lote);
    g_resume_base_solicitud := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      g_resume_base_solicitud := NULL;
      RAISE;
  END;

  PROCEDURE p_mask_tab(
    p_esquema       IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_identificador IN VARCHAR2,
    p_columna       IN VARCHAR2 DEFAULT NULL,
    p_commit_lote   IN NUMBER   DEFAULT 1000
  ) IS
    l_esquema      VARCHAR2(128) := f_norm(p_esquema);
    l_solicitud_id NUMBER;
    l_idx          PLS_INTEGER := 1;
    l_col_idx      PLS_INTEGER;
    l_columna      VARCHAR2(128);
    l_tabla        VARCHAR2(128);
    l_ejecucion_id NUMBER;
    l_err_code     NUMBER;
    l_err_stack    VARCHAR2(1800);
    l_err_bt       VARCHAR2(1800);
  BEGIN
    proc_dm_validar_base;

    -- B-01 (auditoria 2026-09-16): esta rutina creaba la solicitud con
    -- ejecucion_id=-1, un valor que nunca se siembra en tdm_ejecucion. Tanto
    -- fk_tdm_mask_sol_ejec (tdm_mask_solicitud) como fk_tdm_mask_trace_ejec
    -- (tdm_mask_trace) violaban ORA-02291 en la primera llamada real: la
    -- funcion estaba rota de origen, no solo "sin documentar". Ademas, -1 es
    -- un literal fijo, asi que TODAS las invocaciones de p_mask_tab a lo
    -- largo del tiempo habrian compartido el mismo pepper
    -- (clave='PEPPER_MASK:-1'), nunca purgado: justo el secreto
    -- compartido/no rotado que el diseno de pepper por campana busca evitar.
    --
    -- Correccion: se crea una ejecucion real y minima ("ad-hoc"), con su
    -- propia fila en tdm_ejecucion, para que el modo selectivo viva dentro
    -- del mismo modelo de trazabilidad, pepper efimero y purga que una
    -- campana completa.
    l_ejecucion_id := seq_dm_ejecucion.NEXTVAL;
    INSERT INTO tdm_ejecucion(
      ejecucion_id, esquema_objetivo, ejecutado_por, fase_proceso, estado, fecha_inicio
    ) VALUES (
      l_ejecucion_id, l_esquema, USER, 'ENMASCARAMIENTO', 'EJECUTANDO', SYSTIMESTAMP
    );
    COMMIT;   -- visible para los workers paralelos antes de generar el pepper

    proc_dm_pepper_generar(l_ejecucion_id);
    l_solicitud_id := func_dm_crea_sol(l_ejecucion_id,l_esquema,'Enmascaramiento selectivo (p_mask_tab)');

    proc_dm_pre_dep(l_solicitud_id,l_ejecucion_id,l_esquema);

    LOOP
      l_tabla := f_csv_item(p_tabla, l_idx);
      EXIT WHEN l_tabla IS NULL;

      DECLARE
        l_cols_total NUMBER := 0;
        l_cols_excl  NUMBER := 0;
      BEGIN
        SELECT COUNT(*) INTO l_cols_total
          FROM dba_tab_columns
         WHERE owner = l_esquema
           AND table_name = l_tabla
           AND data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2');

        SELECT COUNT(*) INTO l_cols_excl
          FROM tdm_excepcion_col e
         WHERE f_norm(e.owner_name) = l_esquema
           AND e.table_name = l_tabla
           AND f_norm(e.activa) = 'Y'
           AND f_norm(e.accion) = 'EXCLUDE';

        IF l_cols_total > 0 AND l_cols_excl >= l_cols_total THEN
          proc_dm_trace(
            l_solicitud_id,
            l_ejecucion_id,
            'MASK',
            'SKIP_TABLE_TABMODE',
            l_esquema||'.'||l_tabla||' omitida en p_mask_tab: todas las columnas tipo texto están EXCLUDE'
          );
          l_idx := l_idx + 1;
          CONTINUE;
        END IF;
      END;

      IF p_columna IS NOT NULL THEN
        l_col_idx := 1;
        LOOP
          l_columna := f_csv_item(p_columna, l_col_idx);
          EXIT WHEN l_columna IS NULL;
          proc_dm_apl_col(l_solicitud_id,l_ejecucion_id,l_esquema,l_esquema,l_tabla,l_columna,p_identificador);
          l_col_idx := l_col_idx + 1;
        END LOOP;
      ELSE
        FOR rc IN (
          SELECT column_name
            FROM dba_tab_columns
           WHERE owner = l_esquema
             AND table_name = l_tabla
             AND data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2')
        ) LOOP
          proc_dm_apl_col(l_solicitud_id,l_ejecucion_id,l_esquema,l_esquema,l_tabla,rc.column_name,p_identificador);
        END LOOP;
      END IF;

      l_idx := l_idx + 1;
    END LOOP;

    proc_dm_post_sync(l_solicitud_id,l_ejecucion_id,l_esquema);
    proc_dm_post_dep(l_solicitud_id,l_ejecucion_id);
    proc_dm_upd_sol(l_solicitud_id,'FINALIZADO','FIN','FINALIZADO','Enmascaramiento selectivo finalizado','Y');
    proc_dm_upd_ejec(l_ejecucion_id,'ENMASCARAMIENTO','FINALIZADO',100,NULL,NULL,NULL,NULL,NULL,'FINALIZADO');

    -- Ejecucion ad-hoc sin fase de export posterior: el pepper no debe
    -- sobrevivir a esta llamada.
    p_dm_pepper_purgar(l_ejecucion_id);
  EXCEPTION
    WHEN OTHERS THEN
      l_err_code  := SQLCODE;
      l_err_stack := f_safe_err(DBMS_UTILITY.FORMAT_ERROR_STACK);
      l_err_bt    := f_safe_err(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      BEGIN
        IF l_solicitud_id IS NOT NULL THEN
          proc_dm_upd_sol(l_solicitud_id,'ERROR','ERROR','ERROR',l_err_stack,'Y');
          proc_dm_trace(l_solicitud_id,l_ejecucion_id,'ERROR','ERROR',l_err_stack);
        END IF;
        IF l_ejecucion_id IS NOT NULL THEN
          proc_dm_upd_ejec(l_ejecucion_id,'ENMASCARAMIENTO','ERROR',NULL,NULL,NULL,NULL,NULL,NULL,'ERROR');
        END IF;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
      proc_dm_log_ejec_error(
        p_ejecucion_id => l_ejecucion_id,
        p_owner_name   => l_esquema,
        p_table_name   => l_tabla,
        p_column_name  => NULL,
        p_etapa        => 'P_MASK_TAB',
        p_codigo_error => l_err_code,
        p_mensaje      => l_err_stack,
        p_backtrace    => l_err_bt,
        p_solicitud_id => l_solicitud_id
      );
      -- El pepper se purga tambien en fallo: un secreto de campana ad-hoc a
      -- medias no debe persistir indefinidamente en tdm_secreto.
      IF l_ejecucion_id IS NOT NULL THEN
        p_dm_pepper_purgar(l_ejecucion_id);
      END IF;
      RAISE;
  END;

END pkg_dm_enmascarar;
/