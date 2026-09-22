set serveroutput on size unlimited
set verify off
set feedback on
set define off
alter session set current_schema = ASTSYSADMIN;

Rem =============================================================================
Rem dm_proteger_auditoria.sql -- bloquea TRUNCATE/DROP sobre las tablas de
Rem control/traza/secreto del motor de enmascarado, salvo mantenimiento
Rem autorizado explicitamente para la sesion.
Rem =============================================================================
Rem POR QUE EXISTE: se confirmo en produccion (2026-09-22) que fue posible
Rem hacer TRUNCATE de TDM_MASK_TRACE en medio de una ejecucion. Investigado:
Rem   - Las tablas de este motor SOLO otorgan a ROL_DATAMASKING (99_install,
Rem     seccion 2.9) SELECT/INSERT/UPDATE puntuales -- NUNCA DELETE, DROP ni
Rem     nada que permita TRUNCATE. TDM_SECRETO (el pepper) no tiene NINGUN
Rem     grant a ROL_DATAMASKING: solo el propietario del esquema (o alguien
Rem     con privilegio de sistema tipo DBA/ALTER ANY TABLE) puede leerla.
Rem   - Un TRUNCATE es DDL, no DML: NUNCA dispara un trigger normal
Rem     (BEFORE/AFTER ... ON tabla), y GRANT/REVOKE de objeto no lo puede
Rem     restringir para quien ya tiene un privilegio de SISTEMA (DBA, ALTER
Rem     ANY TABLE, DROP ANY TABLE) o para el propietario del esquema -- por
Rem     diseno de Oracle, ningun GRANT a nivel de objeto puede cerrarle esa
Rem     puerta a una cuenta con privilegio de sistema. Por eso el gap no es
Rem     un error de GRANT que faltara: es que TRUNCATE/DROP en Oracle solo se
Rem     puede interceptar con un TRIGGER DE DDL (evento TRUNCATE/DROP), nunca
Rem     con privilegios de objeto.
Rem
Rem QUE INSTALA:
Rem   1) Un contexto de aplicacion (CTX_DM_MANTENIMIENTO), de ambito SESION
Rem      (se pierde al desconectar -- no persiste como una fila en una tabla
Rem      que a su vez podria ser manipulada).
Rem   2) Paquete PKG_DM_MANTENIMIENTO con dos procedimientos publicos:
Rem      proc_activar_mantenimiento(motivo) / proc_desactivar_mantenimiento.
Rem      Activar mantenimiento queda registrado en TDM_MASK_TRACE (quien,
Rem      cuando, por que) -- la propia excepcion al bloqueo deja rastro.
Rem   3) Un trigger de DDL A NIVEL DE BASE DE DATOS (ON DATABASE, no ON
Rem      SCHEMA): se eligio ON DATABASE a proposito porque el disparo de un
Rem      trigger ON SCHEMA depende del CURRENT_SCHEMA de la sesion en el
Rem      momento del DDL, y varios scripts de este proyecto (p.ej.
Rem      dm_reset_ejecuciones.sql) truncan con el owner calificado
Rem      (astsysadmin.tabla) SIN fijar current_schema=ASTSYSADMIN -- un
Rem      trigger ON SCHEMA no los habria visto. ON DATABASE se evalua sobre
Rem      el OWNER REAL del objeto (ORA_DICT_OBJ_OWNER), sin ambiguedad, y NO
Rem      afecta a ningun otro esquema de la instancia (el IF adentro filtra
Rem      explicitamente por ORA_DICT_OBJ_OWNER='ASTSYSADMIN'; para cualquier
Rem      otro esquema el trigger no hace nada, el DDL sigue normal).
Rem
Rem REQUIERE dos privilegios de sistema para instalar (no para usarlo despues):
Rem   GRANT ADMINISTER DATABASE TRIGGER TO <su_usuario>;  -- para el trigger ON DATABASE
Rem   GRANT CREATE ANY CONTEXT           TO <su_usuario>;  -- para el CREATE CONTEXT
Rem Si su usuario ya puede hacer TRUNCATE sobre tablas de ASTSYSADMIN sin ser
Rem su propietario (como en el caso que motivo este script), es muy probable
Rem que ya tenga privilegio DBA y por tanto ambos.
Rem
Rem QUE NO CUBRE (honestidad, no es Database Vault): SYS esta exento de TODO
Rem trigger de Oracle por diseno -- esto es un control razonable y de costo
Rem cero contra un error humano o una cuenta de aplicacion mal usada, no una
Rem barrera absoluta contra un insider con acceso SYS. Para eso, la
Rem recomendacion de mas peso es Oracle Database Vault o, como minimo,
Rem activar una politica de Unified Audit sobre TRUNCATE/DROP TABLE (registro,
Rem no bloqueo -- complementario a esto, no sustituto).
Rem
Rem COMO PROBARLO (en un momento sin campana activa):
Rem   TRUNCATE TABLE astsysadmin.tdm_mask_trace;  -- debe fallar con ORA-20900
Rem   EXEC pkg_dm_mantenimiento.proc_activar_mantenimiento('prueba manual');
Rem   TRUNCATE TABLE astsysadmin.tdm_mask_trace;  -- ahora SI debe permitir
Rem   EXEC pkg_dm_mantenimiento.proc_desactivar_mantenimiento;
Rem
Rem PARA QUITARLO (si alguna vez hace falta):
Rem   DROP TRIGGER trg_dm_proteger_ddl;
Rem
Rem MODIFICADO   (MM/DD/YY)
Rem epurisaca    09/22/26 - Creacion, tras confirmar que TDM_MASK_TRACE se
Rem                         pudo truncar durante una ejecucion real.
Rem =============================================================================

prompt --- Paso 1: contexto de aplicacion ---

CREATE OR REPLACE CONTEXT ctx_dm_mantenimiento USING pkg_dm_mantenimiento;

prompt --- Paso 2: paquete pkg_dm_mantenimiento ---

CREATE OR REPLACE PACKAGE pkg_dm_mantenimiento IS
  -- Activa la ventana de mantenimiento para ESTA sesion (se pierde sola al
  -- desconectar). Deja rastro en TDM_MASK_TRACE con el motivo indicado.
  PROCEDURE proc_activar_mantenimiento(p_motivo IN VARCHAR2);
  PROCEDURE proc_desactivar_mantenimiento;
END pkg_dm_mantenimiento;
/
show errors package pkg_dm_mantenimiento

CREATE OR REPLACE PACKAGE BODY pkg_dm_mantenimiento IS

  PROCEDURE proc_activar_mantenimiento(p_motivo IN VARCHAR2) IS
  BEGIN
    DBMS_SESSION.SET_CONTEXT('CTX_DM_MANTENIMIENTO', 'ACTIVO', 'Y');
    BEGIN
      pkg_dm_trazabilidad.proc_dm_trace(NULL, NULL, 'MANTENIMIENTO', 'ACTIVADO',
        'Ventana de mantenimiento DDL activada por '||
        SYS_CONTEXT('USERENV','SESSION_USER')||' (sesion audsid='||
        SYS_CONTEXT('USERENV','SESSIONID')||') motivo: '||
        SUBSTR(NVL(p_motivo,'(sin motivo indicado)'),1,300));
    EXCEPTION
      WHEN OTHERS THEN NULL;  -- no bloquear la activacion por un fallo de traza
    END;
    DBMS_OUTPUT.PUT_LINE('Mantenimiento DDL ACTIVADO para esta sesion. Recuerde desactivarlo al terminar.');
  END;

  PROCEDURE proc_desactivar_mantenimiento IS
  BEGIN
    DBMS_SESSION.SET_CONTEXT('CTX_DM_MANTENIMIENTO', 'ACTIVO', 'N');
    DBMS_OUTPUT.PUT_LINE('Mantenimiento DDL DESACTIVADO para esta sesion.');
  END;

END pkg_dm_mantenimiento;
/
show errors package body pkg_dm_mantenimiento

prompt --- Paso 3: trigger de DDL a nivel de base de datos ---

CREATE OR REPLACE TRIGGER trg_dm_proteger_ddl
  BEFORE TRUNCATE OR DROP ON DATABASE
DECLARE
  c_protegidas CONSTANT SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
    'TDM_SECRETO','TDM_MASK_TRACE','TDM_EJECUCION','TDM_EJECUCION_ERROR',
    'TDM_MASK_SOLICITUD','TDM_MASK_DEP_ESTADO','TDM_EJECUCION_SCOPE',
    'TDM_COLUMNA_HIST','TDM_DEPENDENCIA_HIST','TDM_COLUMNA_FINAL',
    'TDM_DEPENDENCIA_FINAL'
  );
  l_activo VARCHAR2(1);
  l_es_protegida BOOLEAN := FALSE;
BEGIN
  IF ORA_DICT_OBJ_OWNER = 'ASTSYSADMIN' THEN
    FOR i IN 1 .. c_protegidas.COUNT LOOP
      IF ORA_DICT_OBJ_NAME = c_protegidas(i) THEN
        l_es_protegida := TRUE;
        EXIT;
      END IF;
    END LOOP;

    IF l_es_protegida THEN
      BEGIN
        l_activo := SYS_CONTEXT('CTX_DM_MANTENIMIENTO','ACTIVO');
      EXCEPTION
        WHEN OTHERS THEN l_activo := NULL;
      END;

      IF NVL(l_activo,'N') <> 'Y' THEN
        RAISE_APPLICATION_ERROR(-20900,
          ORA_DICT_OBJ_TYPE||' bloqueado sobre '||ORA_DICT_OBJ_OWNER||'.'||ORA_DICT_OBJ_NAME||
          ' -- tabla de control/traza/secreto del motor de enmascarado (auditoria). '||
          'Si esto es un mantenimiento autorizado, ejecute primero '||
          'EXEC pkg_dm_mantenimiento.proc_activar_mantenimiento(''motivo'') y reintente.');
      END IF;
    END IF;
  END IF;
END;
/
show errors trigger trg_dm_proteger_ddl

prompt =========================================================
prompt Instalado. Pruebe con el bloque "COMO PROBARLO" del encabezado de este
prompt script antes de confiar en la proteccion. Recuerde actualizar
prompt dm_reset_ejecuciones.sql para que active mantenimiento antes de sus
prompt propios TRUNCATE (ya aplicado en la version entregada junto con este
prompt script).
prompt =========================================================
