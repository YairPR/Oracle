Rem 03b_dm_pkg_trazabilidad.sql  (VERSION FF1 - NIST SP 800-38G)
Rem
Rem    NOMBRE
Rem      pkg_dm_trazabilidad.sql - Registro de traza y errores del motor
Rem
Rem    DESCRIPCION
Rem      Paquete minimo, SIN dependencias de otros paquetes del motor, que
Rem      centraliza dos operaciones de solo escritura: registrar un evento de
Rem      traza (tdm_mask_trace) y registrar un error de ejecucion
Rem      (tdm_ejecucion_error). Ambas rutinas usan AUTONOMOUS_TRANSACTION para
Rem      que su COMMIT nunca interfiera con la transaccion de negocio del
Rem      llamador.
Rem
Rem    MOTIVO DE ESTE PAQUETE (cierre de auditoria 2026-09-16, hallazgo Gemini
Rem    de "acoplamiento cruzado de paquetes"):
Rem      Antes de este cambio, pkg_dm_trace vivia dentro de pkg_dm_enmascarar
Rem      (05). Pero pkg_dm_descubrimiento (04) tambien necesita trazar eventos
Rem      (p.ej. re-inclusion de columnas por integridad referencial), y 04
Rem      compila ANTES que 05 en el orden de instalacion (ver 99_install:
Rem      04 -> 06 -> 05 -> 07). Una llamada ESTATICA de 04 hacia
Rem      pkg_dm_enmascarar.proc_dm_trace fallaria en una instalacion limpia
Rem      porque pkg_dm_enmascarar todavia no existe en el esquema en ese
Rem      punto del script. La solucion anterior evitaba esto con
Rem      EXECUTE IMMEDIATE ('begin pkg_dm_enmascarar.proc_dm_trace(...); end;'),
Rem      lo que difiere la resolucion del nombre a tiempo de ejecucion -
Rem      funciona, pero es fragil (un cambio de firma en proc_dm_trace no lo
Rem      detecta el compilador, solo revienta en produccion) y crea un ciclo
Rem      logico entre 04 y 05 dificil de razonar.
Rem
Rem      Extrayendo la trazabilidad a este paquete independiente, sin
Rem      dependencias de pepper, sesion ni de ningun otro paquete del motor,
Rem      se rompe el ciclo: pkg_dm_trazabilidad compila justo despues de las
Rem      tablas (02) y antes de 04, y tanto 04 como 05 lo llaman de forma
Rem      ESTATICA sin ningun EXECUTE IMMEDIATE.
Rem
Rem      Por compatibilidad hacia atras, pkg_dm_enmascarar.proc_dm_trace y
Rem      pkg_dm_enmascarar.proc_dm_log_ejec_error SIGUEN existiendo con la
Rem      misma firma publica (por si algun script externo o SIGAD los invoca
Rem      directamente), pero ahora son wrappers de una linea que delegan aqui.
Rem
Rem    COMPATIBILIDAD
Rem      Oracle 11g en adelante. No requiere wallet ni TDE.
Rem
Rem    ORDEN DE INSTALACION
Rem      Debe compilarse despues de 02_dm_enmascaramiento_objetos.sql (crea
Rem      tdm_mask_trace y sus secuencias) y ANTES de 04_dm_pkg_descubrimiento.sql
Rem      y de 05_dm_pkg_enmascarar.sql.
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    09/16/26 - Extraido de pkg_dm_enmascarar para romper el
Rem                            acoplamiento circular 04<->05 (auditoria Gemini).

create or replace PACKAGE pkg_dm_trazabilidad AS

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

END pkg_dm_trazabilidad;
/

create or replace PACKAGE BODY pkg_dm_trazabilidad AS

  PROCEDURE proc_dm_trace(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_fase         IN VARCHAR2,
    p_paso         IN VARCHAR2,
    p_detalle      IN VARCHAR2
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO tdm_mask_trace(
      trace_id, solicitud_id, ejecucion_id, fase, paso, detalle, fecha_evento
    ) VALUES (
      seq_dm_mask_trace.NEXTVAL,
      p_solicitud_id,
      p_ejecucion_id,
      SUBSTR(p_fase,1,40),
      SUBSTR(p_paso,1,120),
      SUBSTR(p_detalle,1,3900),
      SYSTIMESTAMP
    );
    COMMIT;
  EXCEPTION
    -- Silencio deliberado: esta ES la rutina de trazabilidad. Si el propio
    -- INSERT de traza falla (tablespace lleno, tabla bloqueada), no hay otro
    -- sitio donde registrar el fallo sin arriesgar recursion. Se deja una
    -- migaja en DBMS_OUTPUT (best-effort, nunca falla) en vez de silencio total.
    WHEN OTHERS THEN
      BEGIN
        DBMS_OUTPUT.PUT_LINE('[pkg_dm_trazabilidad.proc_dm_trace] fallo al trazar: '||SQLERRM);
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
  END;

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
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_cnt NUMBER;
    l_id  NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO l_cnt
      FROM user_tables
     WHERE table_name = 'TDM_EJECUCION_ERROR';

    IF l_cnt = 0 THEN
      RETURN;
    END IF;

    SELECT NVL(MAX(error_id),0)+1
      INTO l_id
      FROM tdm_ejecucion_error;

    INSERT INTO tdm_ejecucion_error(
      error_id, ejecucion_id, solicitud_id, owner_name, table_name, column_name, etapa,
      codigo_error, mensaje_error, backtrace, fecha_error
    ) VALUES (
      l_id,
      p_ejecucion_id,
      p_solicitud_id,
      SUBSTR(UPPER(TRIM(p_owner_name)),1,128),
      SUBSTR(UPPER(TRIM(p_table_name)),1,128),
      SUBSTR(UPPER(TRIM(p_column_name)),1,128),
      SUBSTR(p_etapa,1,100),
      p_codigo_error,
      SUBSTR(p_mensaje,1,3900),
      SUBSTR(p_backtrace,1,3900),
      SYSTIMESTAMP
    );
    COMMIT;
  EXCEPTION
    -- Silencio deliberado: esta ES la tabla de errores. Igual que en
    -- proc_dm_trace, si el propio INSERT de error falla no hay otro sitio
    -- seguro donde registrarlo sin arriesgar recursion; se deja constancia
    -- best-effort en DBMS_OUTPUT en vez de perder el rastro por completo.
    WHEN OTHERS THEN
      BEGIN
        DBMS_OUTPUT.PUT_LINE('[pkg_dm_trazabilidad.proc_dm_log_ejec_error] fallo al registrar error: '||SQLERRM);
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
  END;

END pkg_dm_trazabilidad;
/
