set define off

Rem ================================================================================
Rem pkg_dm_pepper  --  30_dm_pkg_pepper.sql
Rem ================================================================================
Rem Ciclo de vida del pepper efimero de una ejecucion (generar y purgar).
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    10/10/26 - Rutinas movidas desde pkg_dm_enmascarar sin cambiar su logica
Rem    epurisaca    10/12/26 - Se quita el estado PAUSADO (nadie lo asigna) y referencias a rutinas retiradas
Rem ================================================================================

create or replace PACKAGE pkg_dm_pepper AS

  PROCEDURE proc_dm_pepper_generar(p_ejecucion_id IN NUMBER);

  PROCEDURE proc_dm_pepper_purgar(
    p_ejecucion_id      IN NUMBER,
    p_confirma_abandono IN VARCHAR2 DEFAULT 'N'
  );

END pkg_dm_pepper;
/

create or replace PACKAGE BODY pkg_dm_pepper AS


  ------------------------------------------------------------------------------
  -- SEMILLA EFIMERA (PEPPER) POR ejecución (ejecucion_id)
  -- Cada ejecución usa su propia fila 'PEPPER_MASK:'||ejecucion_id, de modo que dos
  -- esquemas enmascarados a la vez tienen peppers independientes (sin carrera ni
  -- purga cruzada). Se genera al inicio (idempotente para el resume) con COMMIT
  -- antes del paralelo, y se purga por-ejecución tras el export.
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_pepper_generar
  -- PROPOSITO    : Crea (si no existe) la semilla efimera PEPPER_MASK:<ejecucion_id> con 256 bits
  --                aleatorios y fija la ejecucion activa para los workers y el coordinador.
  -- ENTRADAS     : p_ejecucion_id.
  -- LEE          : TDM_SECRETO
  -- ESCRIBE      : TDM_SECRETO (INSERT + COMMIT); contexto de
  --                pkg_dm_mask_ff1.proc_dm_set_ejecucion
  -- ERRORES      : Sin RAISE_APPLICATION_ERROR; DUP_VAL_ON_INDEX (carrera) se ignora y se conserva la
  --                fila existente; cualquier otro error se propaga.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento (tras proc_dm_propaga_dominios).
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
    pkg_dm_mask_ff1.proc_dm_set_ejecucion(p_ejecucion_id);  -- para updates directos del coordinador
  END;


  -- Guarda de estado: EJECUTANDO bloquea la purga; ERROR/CANCELADO/ABORTADA exige
  -- p_confirma_abandono='Y' (decision explicita de no reanudar, porque reanudar reutiliza el pepper);
  -- FINALIZADO o ejecucion inexistente: purga libre.
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_pepper_purgar
  -- PROPOSITO    : Borra la semilla efimera de UNA ejecucion, con guarda de estado para no destruir
  --                un pepper que aun puede necesitarse.
  -- ENTRADAS     : p_ejecucion_id; p_confirma_abandono (Y obligatorio si la ejecucion esta en
  --                ERROR/CANCELADO/ABORTADA).
  -- LEE          : TDM_EJECUCION
  -- ESCRIBE      : TDM_SECRETO (DELETE de la clave PEPPER_MASK:<id> + COMMIT)
  -- ERRORES      : ORA-20099 si la ejecucion esta EJECUTANDO (bloqueo duro).; ORA-20100 si esta en
  --                ERROR/CANCELADO/ABORTADA sin p_confirma_abandono=Y.; Ejecucion inexistente
  --                o FINALIZADA: purga libre.
  -- LLAMADO DESDE: pkg_dm_enmascarar.proc_dm_enmascaramiento (autopurga al FINALIZAR, best-effort)
  --                y en fallo (con Y). Externo: el DBA, para abandonar una ejecucion (con Y).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_pepper_purgar(
    p_ejecucion_id      IN NUMBER,
    p_confirma_abandono IN VARCHAR2 DEFAULT 'N'
  ) IS
    l_estado tdm_ejecucion.estado%TYPE;
  BEGIN
    BEGIN
      SELECT estado INTO l_estado FROM tdm_ejecucion WHERE ejecucion_id = p_ejecucion_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_estado := NULL;   -- sin fila que proteger: se permite purgar
    END;

    IF pkg_dm_sql_seguro.func_dm_norm(l_estado) = 'EJECUTANDO' THEN
      RAISE_APPLICATION_ERROR(-20099,
        'No se puede purgar el pepper de ejecucion_id='||p_ejecucion_id||
        ': la ejecución sigue EJECUTANDO. Cancele o espere a que finalice.');
    ELSIF pkg_dm_sql_seguro.func_dm_norm(l_estado) IN ('ERROR','CANCELADO','ABORTADA')
          AND pkg_dm_sql_seguro.func_dm_norm(NVL(p_confirma_abandono,'N')) <> 'Y' THEN
      RAISE_APPLICATION_ERROR(-20100,
        'ejecucion_id='||p_ejecucion_id||' esta en estado '||l_estado||
        ' y podria reanudarse con proc_dm_reanudar reutilizando el mismo pepper. '||
        'Llame proc_dm_pepper_purgar('||p_ejecucion_id||',''Y'') solo si confirma que NO se reanudara.');
    END IF;

    -- Borra SOLO el secreto de esta ejecución.
    DELETE FROM tdm_secreto WHERE clave = 'PEPPER_MASK:'||TO_CHAR(p_ejecucion_id);
    COMMIT;
  END;

END pkg_dm_pepper;
/
