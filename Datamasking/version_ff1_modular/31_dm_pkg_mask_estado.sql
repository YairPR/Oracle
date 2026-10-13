set define off

Rem ================================================================================
Rem pkg_dm_mask_estado  --  31_dm_pkg_mask_estado.sql
Rem ================================================================================
Rem Unica puerta de escritura del estado de la ejecucion y de la solicitud de enmascarado.
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    10/10/26 - Rutinas movidas desde pkg_dm_enmascarar sin cambiar su logica
Rem ================================================================================

create or replace PACKAGE pkg_dm_mask_estado AS

  PROCEDURE proc_dm_upd_sol(
    p_solicitud_id IN NUMBER,
    p_estado       IN VARCHAR2,
    p_fase         IN VARCHAR2,
    p_checkpoint   IN VARCHAR2,
    p_detalle      IN VARCHAR2 DEFAULT NULL,
    p_cerrar       IN VARCHAR2 DEFAULT 'N'
  );

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
    p_paso         IN VARCHAR2 DEFAULT NULL,
    p_detalle      IN VARCHAR2 DEFAULT NULL
  );

  PROCEDURE proc_dm_close_sol_open(p_ejecucion_id IN NUMBER);

  PROCEDURE proc_dm_chk_cancel(p_solicitud_id IN NUMBER);

  FUNCTION func_dm_esquema(p_ejecucion_id IN NUMBER) RETURN VARCHAR2;

  -- 1 si la tabla (y columna, si se indica) esta dentro del alcance registrado para la ejecucion.
  FUNCTION func_dm_en_alcance(
    p_ejecucion_id IN NUMBER,
    p_owner        IN VARCHAR2,
    p_tabla        IN VARCHAR2,
    p_columna      IN VARCHAR2 DEFAULT NULL
  ) RETURN NUMBER;

  -- Cuenta las columnas que procesa un enmascarado por identificador: aprobadas (enmascarar=Y) mas FORCE activas.
  FUNCTION func_dm_cuenta_cols_id(
    p_ejecucion_id  IN NUMBER,
    p_identificador IN VARCHAR2
  ) RETURN NUMBER;

  -- Fija el identificador cuyas columnas procesara la ejecucion (TDM_EJECUCION.MASK_IDENTIFICADOR).
  PROCEDURE proc_dm_registra_alcance_id(
    p_ejecucion_id  IN  NUMBER,
    p_identificador IN  VARCHAR2,
    o_columnas      OUT NUMBER
  );

  -- Retira la seleccion por identificador de la ejecucion (vuelve el alcance normal).
  PROCEDURE proc_dm_limpia_alcance_id(p_ejecucion_id IN NUMBER);

  FUNCTION func_dm_crea_sol(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_detalle      IN VARCHAR2,
    p_forzar_reproceso IN VARCHAR2 DEFAULT 'N'
  ) RETURN NUMBER;

END pkg_dm_mask_estado;
/

create or replace PACKAGE BODY pkg_dm_mask_estado AS


  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_upd_sol
  -- PROPOSITO    : Actualiza estado, fase, checkpoint y detalle de una solicitud de enmascarado, y
  --                opcionalmente la cierra con fecha_fin.
  -- ENTRADAS     : p_solicitud_id, p_estado, p_fase, p_checkpoint, p_detalle, p_cerrar (Y cierra).
  -- LEE          : ninguno
  -- ESCRIBE      : TDM_MASK_SOLICITUD (UPDATE + COMMIT)
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento y proc_dm_mask_cat.
  ------------------------------------------------------------------------------
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
           fecha_fin       = CASE WHEN UPPER(NVL(p_cerrar,'N'))='Y' THEN SYSTIMESTAMP ELSE fecha_fin END,
           -- Una solicitud con reintento_nro > 1 antepone siempre 'Reanudacion: <n> | ' al detalle,
           -- para que la marca no se pierda con las actualizaciones posteriores.
           detalle         = CASE WHEN p_detalle IS NOT NULL THEN
                                    SUBSTR(CASE WHEN NVL(reintento_nro,0) > 1
                                                THEN 'Reanudacion: '||TO_CHAR(reintento_nro-1)||' | ' END
                                           ||p_detalle,1,3900)
                                  ELSE detalle END
     WHERE solicitud_id = p_solicitud_id;
    COMMIT;
  END;


  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_upd_ejec
  -- PROPOSITO    : Actualiza fase, estado, progreso, contadores, ultimo objeto y latido de la fila de
  --                TDM_EJECUCION, sin permitir resucitar una ejecucion ya cerrada.
  -- ENTRADAS     : p_ejecucion_id y opcionales fase, estado, pct, tablas/columnas total y procesadas,
  --                objeto, paso y detalle (texto libre de la ejecucion; hoy lo usa la reanudacion).
  -- LEE          : ninguno
  -- ESCRIBE      : TDM_EJECUCION (UPDATE + COMMIT); TDM_MASK_TRACE (traza UPD_EJEC_BLOQUEADO /
  --                UPD_EJEC_FALLO via proc_dm_trace)
  -- ERRORES      : No levanta errores: cualquier fallo se traza (UPD_EJEC_FALLO) y se ignora.; Si la
  --                fila ya esta ABORTADA/CANCELADO/ERROR/FINALIZADO, un intento de volver a
  --                EJECUTANDO no tiene efecto y se traza UPD_EJEC_BLOQUEADO.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento y proc_dm_mask_cat.
  ------------------------------------------------------------------------------
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
    p_paso         IN VARCHAR2 DEFAULT NULL,
    p_detalle      IN VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    -- Este "ping" de progreso se llama tras cada columna con p_estado='EJECUTANDO'. La guarda del
    -- WHERE evita que reabra una fila ya cerrada por otra sesion (p.ej. ABORTADA por
    -- dm_enmascara_cancel). La unica entrada legitima a EJECUTANDO es el reclamo de
    -- proc_dm_enmascaramiento.
    UPDATE tdm_ejecucion
       SET fase_proceso   = NVL(p_fase, fase_proceso),
           estado         = NVL(p_estado, estado),
           ora_usuario  = USER,
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
           detalle        = NVL(SUBSTR(p_detalle,1,4000), detalle),
           error_count    = CASE
                              WHEN UPPER(NVL(p_estado, estado)) IN ('FINALIZADO','ERROR','CANCELADO')
                                THEN (SELECT COUNT(*) FROM tdm_ejecucion_error e WHERE e.ejecucion_id = p_ejecucion_id)
                              ELSE error_count
                            END,
           heartbeat_ts   = SYSTIMESTAMP
     WHERE ejecucion_id = p_ejecucion_id
       AND NOT (
             UPPER(NVL(p_estado, estado)) = 'EJECUTANDO'
             AND UPPER(NVL(estado,'?')) IN ('ABORTADA','CANCELADO','ERROR','FINALIZADO')
           );

    IF SQL%ROWCOUNT = 0 THEN
      -- No es un error: o bien ejecucion_id no existe, o bien la guarda de
      -- arriba bloqueo a proposito un intento de resucitar EJECUTANDO sobre
      -- una fila que alguien mas ya habia cerrado. Se traza para que quede
      -- visible en tdm_mask_trace (sin solicitud_id propio, igual que el
      -- manejador de abajo), nunca para abortar el llamador.
      pkg_dm_trazabilidad.proc_dm_trace(NULL, p_ejecucion_id, 'CONTROL', 'UPD_EJEC_BLOQUEADO',
        'Ping de progreso ('||NVL(p_paso,'?')||'/'||NVL(p_objeto,'?')||') sin efecto para ejecucion_id='||
        p_ejecucion_id||': la fila no existe o ya estaba cerrada (no EJECUTANDO) cuando se intento '||
        'reclamar EJECUTANDO. No se resucita.');
    END IF;

    COMMIT;
  EXCEPTION
    -- No aborta (esta rutina la llaman tambien los propios manejadores de
    -- error, para no encadenar fallos), pero antes de este cambio el fallo
    -- desaparecia sin dejar rastro y el estado mostrado al operador podia
    -- quedar desactualizado sin ninguna pista. Ahora al menos queda trazado.
    WHEN OTHERS THEN
      pkg_dm_trazabilidad.proc_dm_trace(NULL, p_ejecucion_id, 'CONTROL', 'UPD_EJEC_FALLO', pkg_dm_sql_seguro.func_dm_safe_err(SQLERRM));
  END;


  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_close_sol_open
  -- PROPOSITO    : Cierra como ERROR las solicitudes de la ejecucion que quedaron abiertas por un
  --                intento anterior, antes de abrir una nueva.
  -- ENTRADAS     : p_ejecucion_id.
  -- LEE          : ninguno
  -- ESCRIBE      : TDM_MASK_SOLICITUD (UPDATE a ERROR/FIN/AUTO_CLOSE_REANUDAR + COMMIT)
  -- ERRORES      : No levanta errores: los fallos se trazan como CLOSE_SOL_OPEN_FALLO.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento (al arrancar).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_close_sol_open(p_ejecucion_id IN NUMBER) IS
  BEGIN
    UPDATE tdm_mask_solicitud
       SET estado          = 'ERROR',
           fase_actual     = 'FIN',
           checkpoint_paso = 'AUTO_CLOSE_REANUDAR',
           fecha_fin       = SYSTIMESTAMP,
           detalle         = SUBSTR(NVL(detalle,'')||' | Cerrada automáticamente por nueva ejecución/reanudación',1,3900)
     WHERE ejecucion_id = p_ejecucion_id
       AND estado IN ('EN_PROCESO','PENDIENTE','REPROCESANDO')
       AND fecha_fin IS NULL;
    COMMIT;
  EXCEPTION
    -- Igual que en proc_dm_upd_ejec: housekeeping de solicitudes huerfanas,
    -- ahora con traza en vez de silencio total.
    WHEN OTHERS THEN
      pkg_dm_trazabilidad.proc_dm_trace(NULL, p_ejecucion_id, 'CONTROL', 'CLOSE_SOL_OPEN_FALLO', pkg_dm_sql_seguro.func_dm_safe_err(SQLERRM));
  END;


  -- Se elimino proc_dm_longops (telemetria V$SESSION_LONGOPS que nunca se conecto a ninguna llamada).

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_chk_cancel
  -- PROPOSITO    : Comprueba si se ha pedido cancelar la ejecucion y, en ese caso, aborta el flujo
  --                con un error de cancelacion cooperativa.
  -- ENTRADAS     : p_solicitud_id.
  -- LEE          : TDM_MASK_SOLICITUD; TDM_EJECUCION (cancel_requested)
  -- ESCRIBE      : ninguno
  -- ERRORES      : ORA-20081 si cancel_requested = Y.; NO_DATA_FOUND (ORA-01403) si la solicitud no
  --                existe.
  -- LLAMADO DESDE: Interno: proc_dm_mask_cat (una vez por columna, antes de procesarla).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_chk_cancel(p_solicitud_id IN NUMBER) IS
    l_cancel CHAR(1);
  BEGIN
    -- La solicitud de cancelacion vive solo en TDM_EJECUCION (una corrida = una sesion).
    SELECT e.cancel_requested
      INTO l_cancel
      FROM tdm_mask_solicitud s
      JOIN tdm_ejecucion e ON e.ejecucion_id = s.ejecucion_id
     WHERE s.solicitud_id = p_solicitud_id;

    IF NVL(l_cancel,'N') = 'Y' THEN
      RAISE_APPLICATION_ERROR(-20081, 'Cancelación solicitada para solicitud_id='||p_solicitud_id);
    END IF;
  END;


  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_esquema
  -- PROPOSITO    : Obtiene el esquema objetivo de una ejecucion, normalizado.
  -- ENTRADAS     : p_ejecucion_id; retorna esquema en mayusculas.
  -- LEE          : TDM_EJECUCION
  -- ESCRIBE      : ninguno
  -- ERRORES      : ORA-20056 si no existe la ejecucion.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_esquema(p_ejecucion_id IN NUMBER) RETURN VARCHAR2 IS
    l_esquema VARCHAR2(128);
  BEGIN
    SELECT UPPER(TRIM(ora_esquema))
      INTO l_esquema
      FROM tdm_ejecucion
     WHERE ejecucion_id = p_ejecucion_id;
    RETURN l_esquema;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20056,'No existe tdm_ejecucion para ejecucion_id='||p_ejecucion_id);
  END;


  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_crea_sol
  -- PROPOSITO    : Crea una solicitud de enmascarado en estado EN_PROCESO con el numero de reintento
  --                siguiente para la ejecucion.
  -- ENTRADAS     : p_ejecucion_id, p_esquema, p_detalle, p_forzar_reproceso; retorna solicitud_id.
  -- LEE          : TDM_MASK_SOLICITUD; SEQ_DM_MASK_SOLICITUD
  -- ESCRIBE      : TDM_MASK_SOLICITUD (INSERT + COMMIT)
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento.
  ------------------------------------------------------------------------------
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
      solicitud_id, ejecucion_id, ora_esquema, estado, fase_actual,
      checkpoint_paso, reintento_nro, fecha_inicio,
      detalle, forzar_reproceso, filas_procesadas, filas_error,
      tablas_procesadas, columnas_procesadas, ultima_tabla, ultima_columna
    ) VALUES (
      l_solicitud_id, p_ejecucion_id, l_esquema, 'EN_PROCESO', 'INI',
      'INI', l_reintento, SYSTIMESTAMP, SUBSTR(p_detalle,1,3900),
      UPPER(TRIM(NVL(p_forzar_reproceso,'N'))), 0, 0, 0, 0, NULL, NULL
    );
    -- Se elimino un UPDATE sobre TDM_MASK_SOLICITUD.FORZAR_FULL (columna inexistente; la real es
    -- FORZAR_REPROCESO, ya fijada en el INSERT).

    COMMIT;
    RETURN l_solicitud_id;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_cuenta_cols_id
  -- PROPOSITO    : Cuenta las columnas que procesa un enmascarado por identificador: las APROBADAS en
  --                TDM_COLUMNA_FINAL (enmascarar=Y) con ese identificador mas las FORCE activas de
  --                TDM_EXCEPCION_COL con ese identificador (cada columna una sola vez). Es la misma
  --                regla que aplica func_dm_en_alcance fila a fila.
  -- ENTRADAS     : p_ejecucion_id (de ahi sale el esquema), p_identificador.
  -- LEE          : TDM_EJECUCION; TDM_COLUMNA_FINAL; TDM_EXCEPCION_COL; DBA_TAB_COLUMNS
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno propio.
  -- LLAMADO DESDE: proc_dm_registra_alcance_id; pkg_dm_enmascarar (texto ALCANCE de la traza).
  ------------------------------------------------------------------------------
  FUNCTION func_dm_cuenta_cols_id(
    p_ejecucion_id  IN NUMBER,
    p_identificador IN VARCHAR2
  ) RETURN NUMBER IS
    l_esquema VARCHAR2(128) := func_dm_esquema(p_ejecucion_id);
    l_ident   VARCHAR2(50)  := UPPER(TRIM(p_identificador));
    l_n       NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_n
      FROM (SELECT f.table_name, f.column_name
              FROM tdm_columna_final f
             WHERE f.ora_owner = l_esquema
               AND f.enmascarar = 'Y'
               AND UPPER(f.identificador) = l_ident
            UNION
            SELECT pkg_dm_sql_seguro.func_dm_norm(e.table_name),
                   pkg_dm_sql_seguro.func_dm_norm(e.column_name)
              FROM tdm_excepcion_col e
             WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = l_esquema
               AND pkg_dm_sql_seguro.func_dm_norm(e.activa)    = 'Y'
               AND pkg_dm_sql_seguro.func_dm_norm(e.accion)    = 'FORCE'
               AND UPPER(e.identificador_forz) = l_ident
               AND EXISTS (SELECT 1 FROM dba_tab_columns c
                            WHERE c.owner       = pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)
                              AND c.table_name  = pkg_dm_sql_seguro.func_dm_norm(e.table_name)
                              AND c.column_name = pkg_dm_sql_seguro.func_dm_norm(e.column_name)));
    RETURN l_n;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_registra_alcance_id
  -- PROPOSITO    : Fija el identificador cuyas columnas procesara la ejecucion
  --                (TDM_EJECUCION.MASK_IDENTIFICADOR): las APROBADAS en TDM_COLUMNA_FINAL
  --                (enmascarar=Y) mas las FORCE activas con ese identificador. No modifica el
  --                catalogo. func_dm_en_alcance calcula la seleccion a partir de ese identificador, igual
  --                que el modo normal lee el catalogo vivo. Sustituye un identificador anterior de la
  --                misma ejecucion salvo que haya una solicitud en curso.
  -- ENTRADAS     : p_ejecucion_id, p_identificador; SALIDA o_columnas (columnas que procesara).
  -- LEE          : TDM_MASK_SOLICITUD; via func_dm_cuenta_cols_id: TDM_COLUMNA_FINAL, TDM_EXCEPCION_COL
  -- ESCRIBE      : TDM_EJECUCION.MASK_IDENTIFICADOR (UPDATE + COMMIT)
  -- ERRORES      : ORA-20305 solicitud en curso; ORA-20307 el identificador no tiene columnas aprobadas ni FORCE.
  -- LLAMADO DESDE: pkg_dm_enmascarar.proc_dm_registra_alcance_id (dm_enmascara_id.sql).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_registra_alcance_id(
    p_ejecucion_id  IN  NUMBER,
    p_identificador IN  VARCHAR2,
    o_columnas      OUT NUMBER
  ) IS
    l_ident   VARCHAR2(50) := UPPER(TRIM(p_identificador));
    l_n       NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_n
      FROM tdm_mask_solicitud s
     WHERE s.ejecucion_id = p_ejecucion_id
       AND s.estado IN ('PENDIENTE','EN_PROCESO','REPROCESANDO');
    IF l_n > 0 THEN
      RAISE_APPLICATION_ERROR(-20305,
        'Ya existe una solicitud de enmascaramiento en curso para la ejecucion '||p_ejecucion_id||
        ': no se cambia la seleccion.');
    END IF;

    o_columnas := func_dm_cuenta_cols_id(p_ejecucion_id, l_ident);
    IF o_columnas = 0 THEN
      RAISE_APPLICATION_ERROR(-20307,
        'No hay columnas aprobadas (enmascarar=Y) ni FORCE con identificador '||l_ident||' para el esquema '||
        func_dm_esquema(p_ejecucion_id));
    END IF;

    UPDATE tdm_ejecucion
       SET mask_identificador = l_ident
     WHERE ejecucion_id = p_ejecucion_id;
    COMMIT;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_limpia_alcance_id
  -- PROPOSITO    : Quita el identificador de la ejecucion (TDM_EJECUCION.MASK_IDENTIFICADOR = NULL) para
  --                que un enmascarado posterior (p. ej. "el resto") vuelva a usar el alcance normal. Lo llama
  --                dm_enmascara antes de un enmascarado completo (por si una corrida por
  --                identificador quedo interrumpida). Al terminar FINALIZADO una corrida por
  --                identificador lo vacia el propio pkg_dm_enmascarar. Si la corrida se interrumpio,
  --                NO se llama: la reanudacion necesita el identificador.
  -- ERRORES      : ORA-20305 si hay una solicitud en curso (no se cambia la seleccion bajo una corrida viva).
  -- ESCRIBE      : TDM_EJECUCION.MASK_IDENTIFICADOR (UPDATE + COMMIT)
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_limpia_alcance_id(p_ejecucion_id IN NUMBER) IS
    l_n NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_n
      FROM tdm_mask_solicitud s
     WHERE s.ejecucion_id = p_ejecucion_id
       AND s.estado IN ('PENDIENTE','EN_PROCESO','REPROCESANDO');
    IF l_n > 0 THEN
      RAISE_APPLICATION_ERROR(-20305,
        'Ya existe una solicitud de enmascaramiento en curso para la ejecucion '||p_ejecucion_id||
        ': no se cambia la seleccion.');
    END IF;
    UPDATE tdm_ejecucion SET mask_identificador = NULL WHERE ejecucion_id = p_ejecucion_id;
    COMMIT;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_en_alcance
  -- PROPOSITO    : Aplica al enmascarado el mismo alcance que registro el descubrimiento en
  --                TDM_EJECUCION_SCOPE: sin filas para (ejecucion, esquema) = todo el esquema; con filas,
  --                solo las tablas listadas (o '*') y, si la fila trae columna, solo esa.
  -- ENTRADAS     : p_ejecucion_id, p_owner, p_tabla, p_columna (NULL = decision a nivel de tabla).
  -- LEE          : TDM_EJECUCION (MASK_IDENTIFICADOR); TDM_COLUMNA_FINAL; TDM_EXCEPCION_COL; TDM_EJECUCION_SCOPE
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno; ante cualquier fallo devuelve 1 (no restringe) para no cambiar el
  --                comportamiento previo, salvo en modo identificador, donde devuelve 0 (la columna
  --                queda fuera, nunca se amplia el alcance).
  -- LLAMADO DESDE: pkg_dm_mask_dependencias, pkg_dm_mask_columna y pkg_dm_enmascarar (bucle de columnas).
  ------------------------------------------------------------------------------
  FUNCTION func_dm_en_alcance(
    p_ejecucion_id IN NUMBER,
    p_owner        IN VARCHAR2,
    p_tabla        IN VARCHAR2,
    p_columna      IN VARCHAR2 DEFAULT NULL
  ) RETURN NUMBER IS
    l_hay   NUMBER;
    l_ok    NUMBER;
    l_ident tdm_ejecucion.mask_identificador%TYPE;
    l_own   VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tab   VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_col   VARCHAR2(128) := UPPER(TRIM(p_columna));
  BEGIN
    -- Enmascarado por identificador (dm_enmascara_id): manda sobre el alcance de descubrimiento. Procesa
    -- las columnas aprobadas del identificador (TDM_COLUMNA_FINAL, enmascarar=Y) y las FORCE activas con
    -- ese identificador; es la misma regla de func_dm_cuenta_cols_id, evaluada para esta tabla/columna.
    BEGIN
      SELECT e.mask_identificador INTO l_ident
        FROM tdm_ejecucion e
       WHERE e.ejecucion_id = p_ejecucion_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN l_ident := NULL;
    END;
    IF l_ident IS NOT NULL THEN
     BEGIN
      SELECT COUNT(*) INTO l_ok FROM dual
       WHERE EXISTS (SELECT 1 FROM tdm_columna_final f
                      WHERE f.ora_owner  = l_own
                        AND f.table_name = l_tab
                        AND (p_columna IS NULL OR f.column_name = l_col)
                        AND f.enmascarar = 'Y'
                        AND UPPER(f.identificador) = l_ident)
          OR EXISTS (SELECT 1 FROM tdm_excepcion_col x
                      WHERE pkg_dm_sql_seguro.func_dm_norm(x.ora_owner)   = l_own
                        AND pkg_dm_sql_seguro.func_dm_norm(x.table_name)  = l_tab
                        AND (p_columna IS NULL OR pkg_dm_sql_seguro.func_dm_norm(x.column_name) = l_col)
                        AND pkg_dm_sql_seguro.func_dm_norm(x.activa)      = 'Y'
                        AND pkg_dm_sql_seguro.func_dm_norm(x.accion)      = 'FORCE'
                        AND UPPER(x.identificador_forz) = l_ident
                        AND EXISTS (SELECT 1 FROM dba_tab_columns c
                                     WHERE c.owner       = pkg_dm_sql_seguro.func_dm_norm(x.ora_owner)
                                       AND c.table_name  = pkg_dm_sql_seguro.func_dm_norm(x.table_name)
                                       AND c.column_name = pkg_dm_sql_seguro.func_dm_norm(x.column_name)));
      RETURN CASE WHEN l_ok > 0 THEN 1 ELSE 0 END;
     EXCEPTION
       WHEN OTHERS THEN
         -- En modo identificador un fallo NO ensancha el alcance: la columna queda fuera (se ve y se reintenta).
         RETURN 0;
     END;
    END IF;
    SELECT COUNT(*) INTO l_hay
      FROM tdm_ejecucion_scope sc
     WHERE sc.ejecucion_id = p_ejecucion_id
       AND sc.ora_owner    = UPPER(TRIM(p_owner));
    IF l_hay = 0 THEN
      RETURN 1;
    END IF;
    SELECT COUNT(*) INTO l_ok
      FROM tdm_ejecucion_scope sc
     WHERE sc.ejecucion_id = p_ejecucion_id
       AND sc.ora_owner    = UPPER(TRIM(p_owner))
       AND sc.table_name IN ('*', UPPER(TRIM(p_tabla)))
       AND (p_columna IS NULL OR sc.column_name IS NULL OR sc.column_name = UPPER(TRIM(p_columna)));
    RETURN CASE WHEN l_ok > 0 THEN 1 ELSE 0 END;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 1;
  END;

END pkg_dm_mask_estado;
/
