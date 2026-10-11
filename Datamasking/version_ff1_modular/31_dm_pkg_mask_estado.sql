set define off

Rem ================================================================================
Rem pkg_dm_mask_estado  --  31_dm_pkg_mask_estado.sql
Rem ================================================================================
Rem Unica puerta de escritura del estado de la ejecucion y de la solicitud de enmascarado.
Rem
Rem Modularizacion 2026-10-10 (R2-R9): rutinas MOVIDAS desde pkg_dm_enmascarar sin cambiar su
Rem logica. Lo unico distinto es el prefijo de paquete en las llamadas a rutinas que viven en
Rem otro paquete. Las firmas y los textos de traza/error no cambian.
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
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento, proc_dm_mask_cat, proc_dm_enmascara_tabla.
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
           -- FIX 2026-10-07: cada actualizacion de detalle pisaba el texto 'Reanudacion de
           -- ejecucion_id=N desde solicitud_id=M' con 'Aplicando enmascaramiento' y luego
           -- 'Proceso finalizado correctamente', y la marca se perdia. Ahora una solicitud
           -- con reintento_nro > 1 antepone siempre 'Reanudacion: <n> | ' (n = reintento_nro-1).
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
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento, proc_dm_mask_cat, proc_dm_enmascara_tabla.
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
    -- FIX 2026-10-04 (incidente real ejecucion_id=8, auditoria de fuerza
    -- bruta E-01/E-02): esta rutina es el "ping" de progreso que el loop de
    -- columnas llama tras CADA columna (ver proc_dm_mask_cat, rama con y sin
    -- TDM_COLUMNA_FINAL), siempre con p_estado='EJECUTANDO', sin saber si
    -- alguien mas (p.ej. dm_enmascara_cancel.sql, forzando ABORTADA) ya
    -- cerro la fila por fuera mientras la columna en curso (chunked via
    -- DBMS_PARALLEL_EXECUTE, no interrumpible a mitad) terminaba de
    -- procesarse. Sin la guarda del WHERE de abajo, el CASE de
    -- fecha_inicio/estado/fecha_fin "resucitaba" la fila: volvia a poner
    -- estado=EJECUTANDO, refrescaba fecha_inicio a SYSTIMESTAMP y vaciaba
    -- fecha_fin, pisando un ABORTADA/CANCELADO/ERROR/FINALIZADO ya cerrado
    -- por otra sesion -- exactamente lo que le paso a ejecucion_id=8: la
    -- cancelacion forzo ABORTADA a las 17:24:55 y este mismo ping, al
    -- terminar IBAN, la revivio a las 17:35:48 sin que nadie lo pidiera. La
    -- unica via legitima para ENTRAR a EJECUTANDO es el "reclamo de
    -- ejecucion" de proc_dm_enmascaramiento (UPDATE dedicado, mas arriba en
    -- este mismo paquete, con su propia guarda anti-doble-arranque) --
    -- proc_dm_upd_ejec nunca debe reclamar EJECUTANDO por su cuenta.
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
       AND estado IN ('EN_PROCESO','PENDIENTE','REANUDANDO')
       AND fecha_fin IS NULL;
    COMMIT;
  EXCEPTION
    -- Igual que en proc_dm_upd_ejec: housekeeping de solicitudes huerfanas,
    -- ahora con traza en vez de silencio total.
    WHEN OTHERS THEN
      pkg_dm_trazabilidad.proc_dm_trace(NULL, p_ejecucion_id, 'CONTROL', 'CLOSE_SOL_OPEN_FALLO', pkg_dm_sql_seguro.func_dm_safe_err(SQLERRM));
  END;


  -- LIMPIEZA 2026-09-18: se elimina proc_dm_longops (junto con los globales
  -- g_rindex/g_slno, tambien retirados). Era telemetria para
  -- V$SESSION_LONGOPS que nunca llego a conectarse a ninguna llamada real
  -- (g_rindex/g_slno jamas se inicializaban con
  -- DBMS_APPLICATION_INFO.SET_SESSION_LONGOPS_NOHINT, y ningun punto del
  -- paquete invocaba proc_dm_longops) - codigo muerto sin efecto en el
  -- enmascarado, confirmado por grep antes de retirarlo.

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
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento y proc_dm_enmascara_tabla.
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
    -- Limpieza (2026-09-16): aqui habia un EXECUTE IMMEDIATE que actualizaba
    -- TDM_MASK_SOLICITUD.FORZAR_FULL, columna que NO existe en esa tabla (la
    -- columna real es FORZAR_REPROCESO, ya fijada arriba en el INSERT). El
    -- UPDATE fallaba con ORA-00904 en cada llamada y el WHEN OTHERS lo
    -- silenciaba - codigo muerto que nunca hizo nada. Eliminado.

    COMMIT;
    RETURN l_solicitud_id;
  END;

END pkg_dm_mask_estado;
/
