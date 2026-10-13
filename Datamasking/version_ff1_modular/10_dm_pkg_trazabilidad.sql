Rem 10_dm_pkg_trazabilidad.sql  (VERSION FF1 - NIST SP 800-38G)
Rem
Rem    NOMBRE
Rem      pkg_dm_trazabilidad.sql - Registro de traza y errores del motor
Rem
Rem    DESCRIPCION
Rem      Paquete minimo, sin dependencias de otros paquetes del motor, que centraliza la
Rem      escritura de la traza (tdm_mask_trace) y de los errores de ejecucion
Rem      (tdm_ejecucion_error). Usa AUTONOMOUS_TRANSACTION para que su COMMIT no interfiera con
Rem      la transaccion de negocio del llamador.
Rem
Rem      Tambien aloja el control de vida de TDM_EJECUCION compartido por descubrimiento y
Rem      enmascarado: sesion, latido y autocancelacion de ejecuciones huerfanas.
Rem
Rem    COMPATIBILIDAD
Rem      Oracle 11g en adelante. No requiere wallet ni TDE.
Rem
Rem    ORDEN DE INSTALACION
Rem      Despues de 02_dm_enmascaramiento_objetos.sql (crea tdm_mask_trace y sus secuencias) y
Rem      antes de 22_dm_pkg_descubrimiento.sql y 37_dm_pkg_enmascarar.sql.
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    09/16/26 - Extraido de pkg_dm_enmascarar para romper el acoplamiento circular
Rem                            entre descubrimiento y enmascarado
Rem    epurisaca    09/27/26 - Se incorporan proc_dm_refresca_sesion, func_dm_sesion_viva y
Rem                            proc_dm_autocancel_huerfanas, compartidas por ambas fases
Rem    epurisaca    10/09/26 - proc_dm_trace toma el NIVEL del catalogo TDM_MASK_TRACE_EVENTO y
Rem                            acepta objeto, filas, duracion_seg y error_id;
Rem                            proc_dm_log_ejec_error es el unico escritor de errores
Rem    epurisaca    10/10/26 - fecha_evento pasa a DATE y la duracion se registra en segundos
Rem                            (func_dm_ms_desde -> func_dm_seg_desde)
Rem

create or replace PACKAGE pkg_dm_trazabilidad AS

  -- Linea de tiempo (TDM_MASK_TRACE). El nivel sale del catalogo TDM_MASK_TRACE_EVENTO.
  PROCEDURE proc_dm_trace(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_fase         IN VARCHAR2,
    p_paso         IN VARCHAR2,
    p_detalle      IN VARCHAR2,
    p_duracion_seg  IN NUMBER   DEFAULT NULL
  );

  -- Registro de errores (TDM_EJECUCION_ERROR). Deja siempre ademas la linea
  -- ERROR.REGISTRADO en la linea de tiempo (TDM_MASK_TRACE), con error_id=N en el detalle.
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

  -- Segundos (2 decimales) transcurridos desde p_t0 (para p_duracion_seg de proc_dm_trace).
  FUNCTION func_dm_seg_desde(p_t0 IN TIMESTAMP WITH TIME ZONE) RETURN NUMBER;

  -- Control de vida de TDM_EJECUCION (sesion, latido, huerfanas), compartido por descubrimiento
  -- y enmascarado.
  PROCEDURE proc_dm_refresca_sesion(
    p_ejecucion_id IN NUMBER
  );

  FUNCTION func_dm_sesion_viva(
    p_ejecucion_id IN NUMBER
  ) RETURN NUMBER;

  PROCEDURE proc_dm_autocancel_huerfanas(
    p_minutos_inactividad IN NUMBER DEFAULT 15,
    p_forzar_sin_vsession IN VARCHAR2 DEFAULT 'N'
  );

  -- Error de descubrimiento con backtrace.
  procedure proc_dm_log_error(
      p_ejecucion_id in number,
      p_owner        in varchar2,
      p_tabla        in varchar2,
      p_columna      in varchar2,
      p_etapa        in varchar2,
      p_code         in number,
      p_msg          in varchar2
  );

END pkg_dm_trazabilidad;
/

create or replace PACKAGE BODY pkg_dm_trazabilidad AS

  ------------------------------------------------------------------------------
  -- Catalogo de eventos en memoria (TDM_MASK_TRACE_EVENTO). Se carga una
  -- vez por sesion; un cambio de nivel hecho a mano rige desde la sesion
  -- siguiente. Si la tabla no existe o esta vacia, se usa la regla heredada.
  ------------------------------------------------------------------------------
  TYPE t_cat IS TABLE OF VARCHAR2(10) INDEX BY VARCHAR2(200);
  g_cat            t_cat;
  g_cat_cargado    BOOLEAN := FALSE;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_nivel
  -- PROPOSITO    : Devuelve el nivel (INFO, WARN, ERROR) de un evento de traza a partir del catalogo
  --                TDM_MASK_TRACE_EVENTO; si el par fase/paso no esta en el catalogo aplica la
  --                regla heredada.
  -- ENTRADAS     : p_fase, p_paso; retorna el nivel en VARCHAR2.
  -- LEE          : TDM_MASK_TRACE_EVENTO (una vez por sesion, cache en memoria)
  -- ESCRIBE      : ninguno
  -- ERRORES      : Ninguno: si la tabla no existe usa la regla heredada.
  -- LLAMADO DESDE: proc_dm_trace.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_nivel(p_fase IN VARCHAR2, p_paso IN VARCHAR2) RETURN VARCHAR2 IS
    l_k VARCHAR2(200) := UPPER(p_fase)||'.'||UPPER(p_paso);
  BEGIN
    IF NOT g_cat_cargado THEN
      g_cat_cargado := TRUE;      -- aunque falle la carga: no se reintenta en cada evento
      BEGIN
        FOR r IN (SELECT fase, paso, nivel FROM tdm_mask_trace_evento) LOOP
          g_cat(UPPER(r.fase)||'.'||UPPER(r.paso)) := UPPER(r.nivel);
        END LOOP;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
    END IF;
    IF g_cat.EXISTS(l_k) THEN
      RETURN g_cat(l_k);
    END IF;
    -- Paso fuera de catalogo: regla heredada (fase WARN/ERROR o paso ERROR).
    RETURN CASE WHEN UPPER(p_fase) IN ('WARN','ERROR') THEN UPPER(p_fase)
                WHEN UPPER(p_paso) = 'ERROR'           THEN 'ERROR'
                ELSE 'INFO' END;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_seg_desde
  -- PROPOSITO    : Calcula los segundos (2 decimales) transcurridos desde un instante, para rellenar
  --                duracion_seg en la traza.
  -- ENTRADAS     : p_t0 TIMESTAMP WITH TIME ZONE; retorna NUMBER (NULL si p_t0 es NULL).
  -- LEE          : ninguno
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: pkg_dm_mask_columna, pkg_dm_mask_worker, pkg_dm_enmascarar y pkg_dm_descubrimiento.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_seg_desde(p_t0 IN TIMESTAMP WITH TIME ZONE) RETURN NUMBER IS
    l_d INTERVAL DAY(9) TO SECOND(6);
  BEGIN
    IF p_t0 IS NULL THEN RETURN NULL; END IF;
    l_d := SYSTIMESTAMP - p_t0;
    RETURN ROUND((EXTRACT(DAY FROM l_d)*86400 + EXTRACT(HOUR FROM l_d)*3600 +
                  EXTRACT(MINUTE FROM l_d)*60 + EXTRACT(SECOND FROM l_d)), 2);
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_trace
  -- PROPOSITO    : Escribe un evento en la linea de tiempo TDM_MASK_TRACE (fase, paso, nivel del
  --                catalogo, detalle y duracion). El objeto afectado va dentro del detalle
  --                (ESQUEMA.TABLA.COLUMNA ...), no en columnas aparte.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_fase, p_paso, p_detalle y opcional p_duracion_seg.
  -- LEE          : TDM_MASK_TRACE_EVENTO (via func_dm_nivel)
  -- ESCRIBE      : TDM_MASK_TRACE (INSERT)
  -- ERRORES      : Ninguno: transaccion autonoma que nunca propaga el fallo (deja una migaja en
  --                DBMS_OUTPUT).
  -- LLAMADO DESDE: los paquetes de enmascaramiento (31 a 37), pkg_dm_descubrimiento y
  --                pkg_dm_trazabilidad.proc_dm_log_ejec_error.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_trace(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_fase         IN VARCHAR2,
    p_paso         IN VARCHAR2,
    p_detalle      IN VARCHAR2,
    p_duracion_seg  IN NUMBER   DEFAULT NULL
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_nivel VARCHAR2(10);
  BEGIN
    l_nivel := func_dm_nivel(p_fase, p_paso);
    -- El NIVEL lo fija el catalogo TDM_MASK_TRACE_EVENTO; de el dependen los contadores WARN/ERROR
    -- de dm_enmascara, dm_enmascara_reanudar y el KPI-03 de dm_validar_flujo.
    INSERT INTO tdm_mask_trace(
      trace_id, solicitud_id, ejecucion_id, nivel, fase, paso, detalle, fecha_evento,
      duracion_seg
    ) VALUES (
      seq_dm_mask_trace.NEXTVAL,
      p_solicitud_id,
      p_ejecucion_id,
      l_nivel,
      SUBSTR(p_fase,1,40),
      SUBSTR(p_paso,1,120),
      SUBSTR(p_detalle,1,3900),
      SYSDATE,
      p_duracion_seg
    );
    COMMIT;
  EXCEPTION
    -- Silencio deliberado: esta ES la rutina de trazabilidad. Si el propio
    -- INSERT de traza falla (tablespace lleno, tabla bloqueada), no hay otro
    -- sitio donde registrar el fallo sin arriesgar recursion. Se deja una
    -- migaja en DBMS_OUTPUT (best-effort, nunca falla) en vez de silencio total.
    WHEN OTHERS THEN
      BEGIN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('[pkg_dm_trazabilidad.proc_dm_trace] fallo al trazar: '||SQLERRM);
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
  END;

  -- El error_id se calcula con MAX+1 y, ante ORA-00001 por concurrencia, se recalcula y se
  -- reintenta el INSERT (hasta 5 veces), sin bloqueos ni objetos nuevos.
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_log_ejec_error
  -- PROPOSITO    : Unico escritor de errores: registra un error con codigo, mensaje y backtrace en
  --                TDM_EJECUCION_ERROR y deja su linea ERROR.REGISTRADO en la traza, enlazada por
  --                error_id.
  -- ENTRADAS     : p_ejecucion_id, p_owner_name, p_table_name, p_column_name, p_etapa,
  --                p_codigo_error, p_mensaje, p_backtrace, p_solicitud_id (opcional).
  -- LEE          : TDM_EJECUCION_ERROR (MAX(error_id)); USER_TABLES
  -- ESCRIBE      : TDM_EJECUCION_ERROR (INSERT); TDM_MASK_TRACE (via proc_dm_trace)
  -- ERRORES      : Ninguno: transaccion autonoma; reintenta hasta 5 veces ante colision del error_id.
  -- LLAMADO DESDE: pkg_dm_mask_dependencias, pkg_dm_mask_columna y pkg_dm_enmascarar.
  ------------------------------------------------------------------------------
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
    l_cnt      NUMBER;
    l_id       NUMBER;
    l_intentos PLS_INTEGER := 0;
  BEGIN
    SELECT COUNT(*)
      INTO l_cnt
      FROM user_tables
     WHERE table_name = 'TDM_EJECUCION_ERROR';

    IF l_cnt = 0 THEN
      RETURN;
    END IF;

    LOOP
      l_intentos := l_intentos + 1;

      SELECT NVL(MAX(error_id),0)+1
        INTO l_id
        FROM tdm_ejecucion_error;

      BEGIN
        INSERT INTO tdm_ejecucion_error(
          error_id, ejecucion_id, solicitud_id, ora_owner, table_name, column_name, etapa,
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
        EXIT; -- insert ok
      EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
          IF l_intentos >= 5 THEN
            RAISE;
          END IF;
          -- colision transitoria: recalcula MAX y reintenta
      END;
    END LOOP;

    COMMIT;

    -- Linea de tiempo: el error queda ubicado en la secuencia de la corrida; su
    -- detalle empieza por error_id=N, que es la clave en TDM_EJECUCION_ERROR.
    proc_dm_trace(
      p_solicitud_id, p_ejecucion_id, 'ERROR', 'REGISTRADO',
      'error_id='||l_id||' '||SUBSTR(p_etapa,1,100)||' ['||p_codigo_error||'] '||SUBSTR(p_mensaje,1,600)
    );
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

  ------------------------------------------------------------------------------
  -- Captura la sesion Oracle (sid/serial#/inst_id) de la ejecucion y refresca el latido.
  -- Mejor esfuerzo: si no se puede leer, no debe abortar al proceso que la llama. Es autonoma
  -- para que su COMMIT no confirme la transaccion del llamador.
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_refresca_sesion
  -- PROPOSITO    : Captura la sesion Oracle (audsid, sid, serial#, instancia) que ejecuta la corrida
  --                y refresca su latido en TDM_EJECUCION.
  -- ENTRADAS     : p_ejecucion_id.
  -- LEE          : V$SESSION
  -- ESCRIBE      : TDM_EJECUCION (UPDATE de sesion y heartbeat_ts)
  -- ERRORES      : Ninguno: best-effort, transaccion autonoma.
  -- LLAMADO DESDE: proc_dm_enmascaramiento, proc_dm_reanudar y el descubrimiento al arrancar o
  --                reanudar.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_refresca_sesion(
    p_ejecucion_id IN NUMBER
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_sid    NUMBER;
    l_serial NUMBER;
    l_inst   NUMBER;
  BEGIN
    BEGIN
      -- La sesion propia se identifica con SYS_CONTEXT('USERENV','SID'/'INSTANCE'), no por
      -- audsid/username: las sesiones SYS comparten el AUDSID centinela 4294967295 y el lookup
      -- podia tomar otra ventana. El serial# se resuelve en V$SESSION por SID. Solo se invoca desde
      -- la sesion orquestadora, nunca desde un job o worker.
      l_sid  := TO_NUMBER(SYS_CONTEXT('USERENV','SID'));
      l_inst := TO_NUMBER(SYS_CONTEXT('USERENV','INSTANCE'));

      SELECT serial#
        INTO l_serial
        FROM v$session
       WHERE sid = l_sid;
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
    -- No se propaga (el motor no debe caer por un latido), pero deja una traza minima.
    WHEN OTHERS THEN
      BEGIN
        DBMS_OUTPUT.PUT_LINE('[pkg_dm_trazabilidad.proc_dm_refresca_sesion] no se pudo refrescar la sesion de ejecucion_id='||
                             p_ejecucion_id||': '||SQLERRM);
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
  END proc_dm_refresca_sesion;

  ------------------------------------------------------------------------------
  -- Verifica si la sesion Oracle que registro esta ejecucion_id sigue viva.
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_sesion_viva
  -- PROPOSITO    : Indica si la sesion que lanzo una corrida sigue viva en GV$SESSION.
  -- ENTRADAS     : p_ejecucion_id; retorna 1 si hay sesion viva (no KILLED/SNIPED), 0 si no.
  -- LEE          : TDM_EJECUCION; GV$SESSION
  -- ESCRIBE      : ninguno
  -- ERRORES      : Ninguno: si no puede leer GV$SESSION devuelve 1 (asume viva; evita reanudar en paralelo).
  -- LLAMADO DESDE: proc_dm_gestiona_tareas, pkg_dm_descubrimiento.proc_dm_reanudar y los scripts de
  --                monitor/cancel/reanudar.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_sesion_viva(
    p_ejecucion_id IN NUMBER
  ) RETURN NUMBER IS
    l_cnt NUMBER := 0;
  BEGIN
    BEGIN
      SELECT COUNT(*)
        INTO l_cnt
        FROM tdm_ejecucion e
        JOIN gv$session s
          ON (
               (e.sesion_inst_id IS NOT NULL AND e.sesion_sid IS NOT NULL AND e.sesion_serial IS NOT NULL
                AND s.inst_id = e.sesion_inst_id AND s.sid = e.sesion_sid AND s.serial# = e.sesion_serial)
               OR
               (e.sesion_inst_id IS NULL AND e.sesion_sid IS NULL AND e.sesion_serial IS NULL
                AND e.sesion_audsid IS NOT NULL AND s.audsid = e.sesion_audsid)
             )
       WHERE e.ejecucion_id = p_ejecucion_id
         AND NVL(s.status,'ACTIVE') NOT IN ('KILLED','SNIPED');
    EXCEPTION
      WHEN OTHERS THEN
        -- Si GV$SESSION no se puede leer se asume que la sesion vive: darla por muerta permitiria
        -- reanudar y enmascarar dos veces (FF1 no es idempotente).
        BEGIN
          DBMS_OUTPUT.PUT_LINE('[func_dm_sesion_viva] no se pudo leer GV$SESSION para ejecucion_id='||p_ejecucion_id||
                               ': se asume sesion viva. '||SQLERRM);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        RETURN 1;
    END;

    RETURN CASE WHEN l_cnt > 0 THEN 1 ELSE 0 END;
  END func_dm_sesion_viva;

  ------------------------------------------------------------------------------
  -- Auto-cancelacion de ejecuciones huerfanas: barre las filas TDM_EJECUCION en EJECUTANDO (cualquier
  -- fase) y las pasa a ABORTADA solo si:
  --   * la sesion que las origino ya no existe, o
  --   * la sesion esta INACTIVE y el latido supera p_minutos_inactividad.
  -- Una sesion ACTIVE nunca se cancela: una sola sentencia larga (UPDATE o chunks de una columna de
  -- millones de filas) no refresca el latido hasta terminar. Si gv$session no se puede consultar, solo
  -- actua con p_forzar_sin_vsession='Y' y heartbeat obsoleto. No es un job: se invoca desde los puntos
  -- de entrada de descubrimiento y enmascarado.
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_autocancel_huerfanas
  -- PROPOSITO    : Marca como ABORTADA las corridas EJECUTANDO cuya sesion ya no existe o lleva
  --                inactiva mas del limite sin latido, para liberar el bloqueo de ejecucion unica por
  --                esquema.
  -- ENTRADAS     : p_minutos_inactividad (15 por defecto), p_forzar_sin_vsession (Y permite abortar
  --                por latido si no se puede leer GV$SESSION).
  -- LEE          : TDM_EJECUCION; GV$SESSION
  -- ESCRIBE      : TDM_EJECUCION (estado ABORTADA, fecha_fin, ultimo_paso)
  -- ERRORES      : Ninguno: nunca aborta una sesion viva y activa.
  -- LLAMADO DESDE: pkg_dm_mask_validacion.proc_dm_validar_concurrencia y pkg_dm_descubrimiento.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_autocancel_huerfanas(
    p_minutos_inactividad IN NUMBER DEFAULT 15,
    p_forzar_sin_vsession IN VARCHAR2 DEFAULT 'N'
  ) IS
    l_cnt     NUMBER;
    l_activos NUMBER;
    l_limite  INTERVAL DAY TO SECOND := NUMTODSINTERVAL(GREATEST(NVL(p_minutos_inactividad,15),1), 'MINUTE');
  BEGIN
    FOR e IN (
      SELECT ejecucion_id, ora_usuario, fecha_inicio, sesion_audsid, sesion_sid, sesion_serial, sesion_inst_id, heartbeat_ts
        FROM tdm_ejecucion
       WHERE estado = 'EJECUTANDO'
    ) LOOP
      BEGIN
        IF e.sesion_inst_id IS NOT NULL AND e.sesion_sid IS NOT NULL AND e.sesion_serial IS NOT NULL THEN
          SELECT COUNT(*), SUM(CASE WHEN NVL(s.status,'ACTIVE')='ACTIVE' THEN 1 ELSE 0 END)
            INTO l_cnt, l_activos
            FROM gv$session s
           WHERE s.inst_id = e.sesion_inst_id
             AND s.sid = e.sesion_sid
             AND s.serial# = e.sesion_serial
             AND NVL(s.status,'ACTIVE') NOT IN ('KILLED','SNIPED');
        ELSIF e.sesion_audsid IS NOT NULL THEN
          SELECT COUNT(*), SUM(CASE WHEN NVL(s.status,'ACTIVE')='ACTIVE' THEN 1 ELSE 0 END)
            INTO l_cnt, l_activos
            FROM gv$session s
           WHERE s.audsid = e.sesion_audsid
             AND NVL(s.status,'ACTIVE') NOT IN ('KILLED','SNIPED');
        ELSE
          -- Fallback por username (sin sid/serial/audsid capturados aun):
          -- senal mas debil en una cuenta de servicio compartida, pero se le
          -- aplica el mismo criterio ACTIVE/INACTIVE para consistencia.
          SELECT COUNT(*), SUM(CASE WHEN NVL(s.status,'ACTIVE')='ACTIVE' THEN 1 ELSE 0 END)
            INTO l_cnt, l_activos
            FROM gv$session s
           WHERE s.username = e.ora_usuario
             AND NVL(s.status,'ACTIVE') NOT IN ('KILLED','SNIPED');
        END IF;

        IF l_cnt = 0 THEN
          UPDATE tdm_ejecucion
             SET estado = 'ABORTADA',
                 fecha_fin = SYSTIMESTAMP,
                 ultimo_paso = 'AUTO_ABORTADA_SESION_NO_VIVA'
           WHERE ejecucion_id = e.ejecucion_id
             AND estado = 'EJECUTANDO';
        ELSIF NVL(l_activos,0) > 0 THEN
          NULL; -- viva y ejecutando activamente: nunca autocancelar.
        ELSIF NVL(e.heartbeat_ts, e.fecha_inicio) < SYSTIMESTAMP - l_limite THEN
          UPDATE tdm_ejecucion
             SET estado = 'ABORTADA',
                 fecha_fin = SYSTIMESTAMP,
                 ultimo_paso = 'AUTO_ABORTADA_INACTIVA_HEARTBEAT_TIMEOUT'
           WHERE ejecucion_id = e.ejecucion_id
             AND estado = 'EJECUTANDO';
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IF UPPER(NVL(p_forzar_sin_vsession,'N')) = 'Y'
             AND NVL(e.heartbeat_ts, e.fecha_inicio) < SYSTIMESTAMP - l_limite THEN
            UPDATE tdm_ejecucion
               SET estado = 'ABORTADA',
                   fecha_fin = SYSTIMESTAMP,
                   ultimo_paso = 'AUTO_ABORTADA_SIN_VSESSION_HEARTBEAT_TIMEOUT'
             WHERE ejecucion_id = e.ejecucion_id
               AND estado = 'EJECUTANDO';
          END IF;
      END;
    END LOOP;

    COMMIT;
  END proc_dm_autocancel_huerfanas;

  -- Logica compartida por descubrimiento y enmascarado.

-- Nota de diseno: el gate de IDENTIFICADOR_PERSONAL es el chequeo por nombre de columna
-- (NOMBRE|APELLIDO|...). Se descarto clasificar por el contenido de la muestra porque confundia
-- direcciones con nombres. PROMOTOR (persona o entidad segun la fila) queda sin clasificacion
-- automatica: si el negocio confirma que debe enmascararse, se fuerza en TDM_EXCEPCION_COL.

------------------------------------------------------------------------------
-- LOG DE ERRORES
-- No escribe en TDM_EJECUCION_ERROR por su cuenta: delega en
-- pkg_dm_trazabilidad.proc_dm_log_ejec_error (unico escritor, enlaza la traza por error_id).
-- Es un atajo con la firma del descubrimiento y red de seguridad: nunca debe abortar el proceso
-- que protege.
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_log_error
-- PROPOSITO    : Registra un error del descubrimiento delegando en pkg_dm_trazabilidad sin poder
--                abortar nunca al proceso que protege.
-- ENTRADAS     : p_ejecucion_id, p_owner, p_tabla, p_columna, p_etapa, p_code (codigo SQL), p_msg
--                (mensaje). Sin OUT.
-- LEE          : ninguno
-- ESCRIBE      : TDM_EJECUCION_ERROR y TDM_MASK_TRACE (indirecto, via
--                pkg_dm_trazabilidad.proc_dm_log_ejec_error, autonomous transaction)
-- ERRORES      : No levanta ORA-2xxxx; ante cualquier fallo escribe WARN por DBMS_OUTPUT y continua
-- LLAMADO DESDE: func_dm_score_patron; proc_dm_recolecta_dep; proc_dm_aplica_excepcion;
--                proc_dm_procesa_desc
------------------------------------------------------------------------------
procedure proc_dm_log_error(
    p_ejecucion_id in number,
    p_owner        in varchar2,
    p_tabla        in varchar2,
    p_columna      in varchar2,
    p_etapa        in varchar2,
    p_code         in number,
    p_msg          in varchar2
) is
begin
  pkg_dm_trazabilidad.proc_dm_log_ejec_error(
    p_ejecucion_id => p_ejecucion_id,
    p_owner_name   => p_owner,
    p_table_name   => p_tabla,
    p_column_name  => p_columna,
    p_etapa        => p_etapa,
    p_codigo_error => p_code,
    p_mensaje      => p_msg,
    p_backtrace    => dbms_utility.format_error_backtrace
  );
exception
  when others then
    begin
      dbms_output.put_line('WARN proc_dm_log_error no pudo registrar: '||
        p_etapa||' code='||p_code||' -- fallo interno: '||sqlerrm);
    exception
      when others then null;
    end;
end proc_dm_log_error;

END pkg_dm_trazabilidad;
/
