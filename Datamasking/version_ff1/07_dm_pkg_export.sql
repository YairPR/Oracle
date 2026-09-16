set define off
set serveroutput on size unlimited
alter session set current_schema = ASTSYSADMIN;

Rem ================================================================================
Rem pkg_dm_export  -  EXPORT DEL DUMP ENMASCARADO (COMPANION, FUERA DEL MOTOR)
Rem ================================================================================
Rem La logica de Data Pump NO es parte del nucleo de enmascaramiento. Vive aqui
Rem como procedimiento alterno: el motor (pkg_dm_enmascarar) enmascara; este
Rem paquete exporta. Exige estado FINALIZADO de la ejecucion (respeta el fallo
Rem cerrado del motor). Requiere EXECUTE on DBMS_DATAPUMP y un DIRECTORY valido.
Rem ================================================================================

create or replace PACKAGE pkg_dm_export AS

  PROCEDURE p_export_mask(
    p_esquema      IN VARCHAR2,
    p_directorio   IN VARCHAR2,
    p_dumpfile     IN VARCHAR2,
    p_alcance      IN VARCHAR2 DEFAULT 'S',
    p_logfile      IN VARCHAR2 DEFAULT NULL,
    p_ejecucion_id IN NUMBER   DEFAULT NULL
  );

END pkg_dm_export;
/

create or replace PACKAGE BODY pkg_dm_export AS

  -- Normalizador local (mismo comportamiento que el del motor).
  FUNCTION f_norm(p_txt IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN UPPER(TRIM(p_txt));
  END;

  PROCEDURE p_export_mask(
    p_esquema      IN VARCHAR2,
    p_directorio   IN VARCHAR2,
    p_dumpfile     IN VARCHAR2,
    p_alcance      IN VARCHAR2 DEFAULT 'S',
    p_logfile      IN VARCHAR2 DEFAULT NULL,
    p_ejecucion_id IN NUMBER   DEFAULT NULL
  ) IS
    l_job       NUMBER;
    l_estado    VARCHAR2(30);
    l_logfile   VARCHAR2(256);
    l_name_expr VARCHAR2(32767);
    l_esquema   VARCHAR2(128) := f_norm(p_esquema);
    l_ejec_ref  NUMBER := p_ejecucion_id;
    l_ok        NUMBER;
    l_use_hist  CHAR(1) := 'N';
    l_fecha_fin TIMESTAMP;
    l_changed   NUMBER;
  BEGIN
    l_logfile := NVL(p_logfile, REGEXP_REPLACE(p_dumpfile, '\.dmp$', '.log', 1, 1, 'i'));

    -- En export selectivo exigimos ejecución explícita para evitar ambigüedad
    -- entre múltiples corridas del mismo esquema.
    IF f_norm(p_alcance) = 'S' AND p_ejecucion_id IS NULL THEN
      RAISE_APPLICATION_ERROR(-20095, 'Para p_alcance=''S'' debe indicar p_ejecucion_id.');
    END IF;

    -- Validación funcional: exportar sólo sobre una ejecución finalizada.
    IF l_ejec_ref IS NOT NULL THEN
      l_use_hist := 'Y';
      SELECT COUNT(*)
        INTO l_ok
        FROM tdm_ejecucion
       WHERE ejecucion_id = l_ejec_ref
         AND UPPER(TRIM(esquema_objetivo)) = l_esquema
         AND fase_proceso = 'ENMASCARAMIENTO'
         AND estado = 'FINALIZADO';
      IF l_ok = 0 THEN
        RAISE_APPLICATION_ERROR(-20092, 'La ejecución '||l_ejec_ref||' no está FINALIZADA para esquema='||l_esquema||'.');
      END IF;

      SELECT COUNT(*)
        INTO l_ok
        FROM tdm_mask_solicitud
       WHERE ejecucion_id = l_ejec_ref
         AND estado = 'FINALIZADO';
      IF l_ok = 0 THEN
        RAISE_APPLICATION_ERROR(-20093, 'La ejecución '||l_ejec_ref||' no tiene solicitud FINALIZADA. Export bloqueado.');
      END IF;
    ELSE
      SELECT MAX(ejecucion_id), COUNT(*)
        INTO l_ejec_ref, l_ok
        FROM tdm_ejecucion
       WHERE UPPER(TRIM(esquema_objetivo)) = l_esquema
         AND fase_proceso = 'ENMASCARAMIENTO'
         AND estado = 'FINALIZADO';
      IF l_ok = 0 THEN
        RAISE_APPLICATION_ERROR(-20092, 'No existe ejecución FINALIZADA de enmascaramiento para esquema='||l_esquema||'.');
      END IF;
    END IF;

    -- Verificación anti-“falso finalizado”: si el esquema fue recreado/importado
    -- después del enmascarado, forzamos nueva ejecución antes de exportar.
    SELECT fecha_fin
      INTO l_fecha_fin
      FROM tdm_ejecucion
     WHERE ejecucion_id = l_ejec_ref;

    SELECT COUNT(*)
      INTO l_changed
      FROM dba_objects o
     WHERE o.owner = l_esquema
       AND o.object_type = 'TABLE'
       AND o.last_ddl_time > l_fecha_fin;

    IF l_changed > 0 THEN
      RAISE_APPLICATION_ERROR(
        -20096,
        'Se detectaron '||l_changed||' tablas alteradas/recreadas tras el enmascarado (ejecucion_id='||l_ejec_ref||'). Re-ejecute enmascarado antes de exportar.'
      );
    END IF;

    IF f_norm(p_alcance) = 'C' THEN
      l_job := DBMS_DATAPUMP.OPEN('EXPORT', 'SCHEMA', NULL);
      DBMS_DATAPUMP.ADD_FILE(l_job, p_dumpfile, p_directorio, NULL, DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE);
      DBMS_DATAPUMP.ADD_FILE(l_job, l_logfile,  p_directorio, NULL, DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE);
      DBMS_DATAPUMP.METADATA_FILTER(l_job, 'SCHEMA_EXPR', '= '''||l_esquema||'''');
    ELSE
      IF l_use_hist = 'Y' THEN
        SELECT 'IN ('||LISTAGG(CHR(39)||table_name||CHR(39), ',') WITHIN GROUP (ORDER BY table_name)||')'
          INTO l_name_expr
          FROM (
            SELECT DISTINCT table_name
              FROM tdm_columna_hist
             WHERE ejecucion_id = l_ejec_ref
               AND owner_name   = l_esquema
               AND NVL(vigente,'Y') = 'Y'
               AND enmascarar   = 'Y'
          );
      ELSE
        SELECT 'IN ('||LISTAGG(CHR(39)||table_name||CHR(39), ',') WITHIN GROUP (ORDER BY table_name)||')'
          INTO l_name_expr
          FROM (
            SELECT DISTINCT table_name
              FROM tdm_columna_final
             WHERE owner_name = l_esquema
               AND enmascarar = 'Y'
          );
      END IF;
      IF l_name_expr IS NULL THEN
        IF l_use_hist = 'Y' THEN
          RAISE_APPLICATION_ERROR(-20094, 'No hay tablas en tdm_columna_hist para export selectivo (ejecucion_id='||l_ejec_ref||').');
        ELSE
          RAISE_APPLICATION_ERROR(-20094, 'No hay tablas marcadas en tdm_columna_final para export selectivo (esquema='||l_esquema||').');
        END IF;
      END IF;

      l_job := DBMS_DATAPUMP.OPEN('EXPORT', 'TABLE', NULL);
      DBMS_DATAPUMP.ADD_FILE(l_job, p_dumpfile, p_directorio, NULL, DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE);
      DBMS_DATAPUMP.ADD_FILE(l_job, l_logfile,  p_directorio, NULL, DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE);
      DBMS_DATAPUMP.METADATA_FILTER(l_job, 'SCHEMA_EXPR', '= '''||l_esquema||'''');
      DBMS_DATAPUMP.METADATA_FILTER(l_job, 'NAME_EXPR', l_name_expr, 'TABLE');
    END IF;

    DBMS_DATAPUMP.START_JOB(l_job);
    DBMS_DATAPUMP.WAIT_FOR_JOB(l_job, l_estado);
    DBMS_DATAPUMP.DETACH(l_job);
  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        IF l_job IS NOT NULL THEN
          DBMS_DATAPUMP.STOP_JOB(l_job, 1, 0);
          DBMS_DATAPUMP.DETACH(l_job);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
      RAISE;
  END;

END pkg_dm_export;
/
