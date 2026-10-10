set serveroutput on size unlimited

Rem 2026-10-05: esquema/tablespace ya no van fijos -- se detectan solos aqui
Rem mismo abajo (necesita set define on para resolver &&esquemaast)
set define on
Rem --- Esquema del motor: se detecta solo (ASTSYSADMIN o ACC_ADMIN), sin setear nada a mano ---
define esquemaast = '__NO_DETECTADO__'
define tbsast     = '__NO_DETECTADO__'
column v_esquemaast noprint new_value esquemaast
column v_tbsast      noprint new_value tbsast
select username as v_esquemaast, nvl(default_tablespace,username) as v_tbsast
  from (select username, default_tablespace from dba_users
         where username in ('ASTSYSADMIN','ACC_ADMIN')
         order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
 where rownum = 1;
declare
begin
  if upper(trim('&&esquemaast')) = '__NO_DETECTADO__' then
    raise_application_error(-20001,'No se encontro ni ASTSYSADMIN ni ACC_ADMIN en DBA_USERS -- no se puede determinar el esquema del motor DATAMASKING en esta base.');
  end if;
end;
/
alter session set current_schema = &&esquemaast;
set define off

Rem ================================================================================
Rem pkg_dm_export  -  EXPORT DEL DUMP ENMASCARADO (COMPANION, FUERA DEL MOTOR)
Rem ================================================================================
Rem La logica de Data Pump NO es parte del nucleo de enmascaramiento. Vive aqui
Rem como procedimiento alterno: el motor (pkg_dm_enmascarar) enmascara; este
Rem paquete exporta. Exige estado FINALIZADO de la ejecucion (respeta el fallo
Rem cerrado del motor). Requiere EXECUTE on DBMS_DATAPUMP y un DIRECTORY valido.
Rem ================================================================================
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    ...      - Versión inicial (companion de exportación vía Data Pump)
Rem
Rem    epurisaca    09/23/26 - Revisión de industrialización: paquete estable, exige
Rem                            p_ejecucion_id explícito en alcance selectivo, sin
Rem                            cambios funcionales requeridos en este ciclo
Rem
Rem    epurisaca    09/27/26 - Auditoría estricta (hallazgo Nivel 2 #14): se comprueba el
Rem                            estado final que devuelve DBMS_DATAPUMP.WAIT_FOR_JOB. Antes
Rem                            de este fix un job Data Pump terminado en STOPPED (espacio,
Rem                            permisos, STOP_JOB externo) se trataba como éxito silencioso
Rem                            -- riesgo real dado que este export es la vía de rollback
Rem                            funcional preferente del motor (ver 05, "EXPORT / IMPORT").
Rem
Rem    epurisaca    09/28/26 - CONVENCION DE NOMBRES (auditoria/orden estructural):
Rem                            p_export_mask -> proc_dm_export_mask, f_norm (local) ->
Rem                            func_dm_norm. Sin cambio de firma ni de logica, solo el
Rem                            identificador. Coordinado con 04, 05, 06 y los drivers .sql.
Rem                            Mapa completo en el proyecto Claude "Enmascaramiento".
Rem ================================================================================

create or replace PACKAGE pkg_dm_export AS

  PROCEDURE proc_dm_export_mask(
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
  FUNCTION func_dm_norm(p_txt IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN UPPER(TRIM(p_txt));
  END;

  PROCEDURE proc_dm_export_mask(
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
    l_esquema   VARCHAR2(128) := func_dm_norm(p_esquema);
    l_ejec_ref  NUMBER := p_ejecucion_id;
    l_ok        NUMBER;
    l_use_hist  CHAR(1) := 'N';
    l_fecha_fin TIMESTAMP;
    l_changed   NUMBER;
  BEGIN
    l_logfile := NVL(p_logfile, REGEXP_REPLACE(p_dumpfile, '\.dmp$', '.log', 1, 1, 'i'));

    -- En export selectivo exigimos ejecución explícita para evitar ambigüedad
    -- entre múltiples corridas del mismo esquema.
    IF func_dm_norm(p_alcance) = 'S' AND p_ejecucion_id IS NULL THEN
      RAISE_APPLICATION_ERROR(-20095, 'Para p_alcance=''S'' debe indicar p_ejecucion_id.');
    END IF;

    -- Validación funcional: exportar sólo sobre una ejecución finalizada.
    IF l_ejec_ref IS NOT NULL THEN
      l_use_hist := 'Y';
      SELECT COUNT(*)
        INTO l_ok
        FROM tdm_ejecucion
       WHERE ejecucion_id = l_ejec_ref
         AND UPPER(TRIM(ora_esquema)) = l_esquema
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
       WHERE UPPER(TRIM(ora_esquema)) = l_esquema
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

    IF func_dm_norm(p_alcance) = 'C' THEN
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
               AND ora_owner   = l_esquema
               AND NVL(vigente,'Y') = 'Y'
               AND enmascarar   = 'Y'
          );
      ELSE
        SELECT 'IN ('||LISTAGG(CHR(39)||table_name||CHR(39), ',') WITHIN GROUP (ORDER BY table_name)||')'
          INTO l_name_expr
          FROM (
            SELECT DISTINCT table_name
              FROM tdm_columna_final
             WHERE ora_owner = l_esquema
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

    -- FIX 2026-09-27 (auditoria estricta, Nivel 2 #14): WAIT_FOR_JOB devuelve
    -- en l_estado el resultado final del job ('COMPLETED', 'STOPPED' o
    -- 'COMPLETED_WITH_WARNINGS' entre otros) y, antes de este fix, nunca se
    -- comprobaba -- un job que terminaba en STOPPED (p.ej. por espacio en el
    -- DIRECTORY, permisos, o STOP_JOB externo) devolvia el control como si el
    -- export hubiera sido exitoso, sin ningun error ni traza. proc_dm_export_mask
    -- es la via de rollback funcional preferente de todo el motor (ver
    -- cabecera de 05_dm_pkg_enmascarar.sql, "EXPORT / IMPORT EN EL FLUJO"),
    -- asi que un dump incompleto reportado como bueno es un riesgo real de
    -- continuidad. Fallo cerrado: solo 'COMPLETED' (o con warnings, que el
    -- propio log de Data Pump ya detalla) se acepta como exito silencioso.
    IF l_estado NOT IN ('COMPLETED', 'COMPLETED_WITH_WARNINGS') THEN
      RAISE_APPLICATION_ERROR(-20199,
        'DBMS_DATAPUMP job para esquema='||l_esquema||' (ejecucion_id='||l_ejec_ref||
        ') no terminó en COMPLETED (estado final='||NVL(l_estado,'NULL')||
        '). Revise el logfile '||l_logfile||' en el DIRECTORY '||p_directorio||'.');
    END IF;
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
