set define off

Rem ================================================================================
Rem pkg_dm_mask_validacion  --  32_dm_pkg_mask_validacion.sql
Rem ================================================================================
Rem Compuertas de solo lectura antes de enmascarar (base, concurrencia, reingreso).
Rem
Rem Modularizacion 2026-10-10 (R2-R9): rutinas MOVIDAS desde pkg_dm_enmascarar sin cambiar su
Rem logica. Lo unico distinto es el prefijo de paquete en las llamadas a rutinas que viven en
Rem otro paquete. Las firmas y los textos de traza/error no cambian.
Rem ================================================================================

create or replace PACKAGE pkg_dm_mask_validacion AS

  PROCEDURE proc_dm_validar_base;

  PROCEDURE proc_dm_validar_concurrencia(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  );

  PROCEDURE proc_dm_validar_reingreso_mask(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_reproceso    IN VARCHAR2
  );

END pkg_dm_mask_validacion;
/

create or replace PACKAGE BODY pkg_dm_mask_validacion AS


  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_validar_base
  -- PROPOSITO    : Verifica que existen las tablas base del motor antes de empezar a enmascarar.
  -- ENTRADAS     : Sin parametros.
  -- LEE          : USER_TABLES
  -- ESCRIBE      : ninguno
  -- ERRORES      : ORA-20050 falta TDM_MASK_SOLICITUD.; ORA-20051 falta TDM_MASK_TRACE.; ORA-20052
  --                falta TDM_MASK_DEP_ESTADO.; ORA-20053 falta TDM_COLUMNA_FINAL.; ORA-20054 falta
  --                TDM_DEPENDENCIA_FINAL.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento y proc_dm_enmascara_tabla.
  ------------------------------------------------------------------------------
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
  END;


  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_validar_concurrencia
  -- PROPOSITO    : Impide arrancar un enmascarado si ya hay otra ejecucion ENMASCARAMIENTO en curso
  --                para la misma ejecucion_id o para el mismo esquema.
  -- ENTRADAS     : p_ejecucion_id, p_esquema.
  -- LEE          : TDM_EJECUCION
  -- ESCRIBE      : TDM_EJECUCION (indirecto: pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas pasa a
  --                ABORTADA las EJECUTANDO huerfanas)
  -- ERRORES      : ORA-20097 ya hay una ejecucion ENMASCARAMIENTO EJECUTANDO con ese ejecucion_id.;
  --                ORA-20098 ya hay otra EJECUTANDO sobre el mismo esquema.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento y proc_dm_enmascara_tabla.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_validar_concurrencia(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  ) IS
    l_cnt NUMBER;
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
  BEGIN
    -- 2026-09-27: barrido global de huerfanas ANTES de bloquear. Si la fila
    -- EJECUTANDO que estorba viene de una sesion muerta (caida, kill) o de un
    -- heartbeat parado hace mas de 15 min, se autocorrige aqui a ABORTADA y
    -- las dos comprobaciones de abajo dejan de encontrarla -- proc_dm_enmascaramiento
    -- puede entonces reclamar la fila con su propio UPDATE de abajo, sin
    -- exigir una intervencion manual previa. Mismo mecanismo que ya usa
    -- pkg_dm_descubrimiento para DESCUBRIMIENTO (ver 10_dm_pkg_trazabilidad.sql).
    pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(15, 'Y');

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
     WHERE UPPER(TRIM(e.ora_esquema)) = l_esquema
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


  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_validar_reingreso_mask
  -- PROPOSITO    : Impide re-ejecutar un enmascarado sobre una ejecucion ya FINALIZADA salvo que se
  --                pida reproceso explicito.
  -- ENTRADAS     : p_ejecucion_id, p_esquema, p_reproceso (Y omite la validacion).
  -- LEE          : TDM_MASK_SOLICITUD
  -- ESCRIBE      : ninguno
  -- ERRORES      : ORA-20014 si existe una solicitud FINALIZADO para la ejecucion y p_reproceso no es
  --                Y.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento.
  ------------------------------------------------------------------------------
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
        ' ya fue ejecutada en enmascaramiento. Para re-ejecutar debe usar proc_dm_enmascaramiento('||
        TO_CHAR(p_ejecucion_id)||',''Y'').'
      );
    END IF;
  END;

END pkg_dm_mask_validacion;
/
