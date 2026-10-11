Rem 10_dm_pkg_trazabilidad.sql  (VERSION FF1 - NIST SP 800-38G)
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
Rem    MOTIVO DE ESTE PAQUETE (cierre de auditoria 2026-09-16, hallazgo
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
Rem      Hasta el 10/10/26 pkg_dm_enmascarar.proc_dm_trace y proc_dm_log_ejec_error
Rem      siguieron existiendo como wrappers de una linea que delegaban aqui. Se
Rem      retiraron (R14): ningun script ni SIGAD los invocaba; el unico punto de
Rem      entrada es este paquete.
Rem
Rem    COMPATIBILIDAD
Rem      Oracle 11g en adelante. No requiere wallet ni TDE.
Rem
Rem    ORDEN DE INSTALACION
Rem      Debe compilarse despues de 02_dm_enmascaramiento_objetos.sql (crea
Rem      tdm_mask_trace y sus secuencias) y ANTES de 22_dm_pkg_descubrimiento.sql
Rem      y de 37_dm_pkg_enmascarar.sql.
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    09/16/26 - Extraido de pkg_dm_enmascarar para romper el
Rem                            acoplamiento circular 04<->05 (auditoria Gemini).
Rem
Rem    epurisaca    10/09/26 - proc_dm_trace ahora escribe NIVEL (WARN/ERROR derivado de
Rem                            fase/paso). Antes siempre INFO: contadores y KPI-03 sobre
Rem                            traza eran vacuamente 0.
Rem
Rem    epurisaca    10/09/26 - TRAZA ORDENADA (una pregunta, una tabla):
Rem                            * proc_dm_trace toma el NIVEL del catalogo TDM_PARAMETRO
Rem                              (grupo EVENTO, clave FASE.PASO) y acepta claves de objeto
Rem                              (owner/tabla/columna), filas, duracion_seg y error_id.
Rem                            * proc_dm_log_ejec_error es el UNICO escritor de errores
Rem                              (04 delega aqui) y deja siempre la linea de tiempo
Rem                              ERROR.REGISTRADO enlazada por error_id.
Rem                            * func_dm_seg_desde: segundos desde un instante, para duracion_seg.
Rem
Rem    epurisaca    10/10/26 - fecha_evento pasa a DATE (al segundo, SYSDATE) y la duracion
Rem                            se registra en SEGUNDOS con 2 decimales (duracion_ms -> duracion_seg;
Rem                            func_dm_ms_desde -> func_dm_seg_desde).
Rem
Rem    epurisaca    09/27/26 - Se incorporan proc_dm_refresca_sesion,
Rem                            func_dm_sesion_viva y proc_dm_autocancel_huerfanas,
Rem                            movidas desde pkg_dm_descubrimiento (04), donde
Rem                            eran privadas y no las podia usar pkg_dm_enmascarar
Rem                            (05), que se quedaba sin autocancelacion de
Rem                            ejecuciones huerfanas en ENMASCARAMIENTO. Mismo
Rem                            motivo que la extraccion del 09/16: es
Rem                            infraestructura sobre TDM_EJECUCION compartida
Rem                            por ambas fases, no logica de negocio de ninguna.
Rem

create or replace PACKAGE pkg_dm_trazabilidad AS

  -- Linea de tiempo (TDM_MASK_TRACE). El nivel sale del catalogo TDM_PARAMETRO.
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

  -- 2026-09-27: control de vida de TDM_EJECUCION (sesion/heartbeat/huerfanas).
  -- Vive aqui por el mismo motivo que proc_dm_trace: es infraestructura
  -- compartida por DESCUBRIMIENTO (04) y ENMASCARAMIENTO (05) sobre una
  -- tabla comun (TDM_EJECUCION), no logica de negocio de ninguno de los dos.
  -- Antes vivia duplicada/privada dentro de 04, y 05 no tenia equivalente
  -- (ver hallazgo "gap_autocancelacion_enmascarado" del proyecto).
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

  -- Movido desde 04 (modularizacion 2026-10-10): error de descubrimiento con backtrace.
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
  -- Catalogo de eventos en memoria (TDM_PARAMETRO, grupo EVENTO). Se carga una
  -- vez por sesion; un cambio de nivel hecho a mano rige desde la sesion
  -- siguiente. Si la tabla no existe o esta vacia, se usa la regla heredada.
  ------------------------------------------------------------------------------
  TYPE t_cat IS TABLE OF VARCHAR2(10) INDEX BY VARCHAR2(200);
  g_cat            t_cat;
  g_cat_cargado    BOOLEAN := FALSE;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_nivel
  -- PROPOSITO    : Devuelve el nivel (INFO, WARN, ERROR) de un evento de traza a partir del catalogo
  --                TDM_PARAMETRO (grupo EVENTO); si el par fase/paso no esta en el catalogo aplica la
  --                regla heredada.
  -- ENTRADAS     : p_fase, p_paso; retorna el nivel en VARCHAR2.
  -- LEE          : TDM_PARAMETRO (una vez por sesion, cache en memoria)
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
        FOR r IN (SELECT clave, valor FROM tdm_parametro WHERE grupo = 'EVENTO') LOOP
          g_cat(r.clave) := UPPER(r.valor);
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
  -- LLAMADO DESDE: pkg_dm_enmascarar.proc_dm_apl_col y pkg_dm_descubrimiento.proc_dm_procesa_desc.
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
  -- LEE          : TDM_PARAMETRO (via func_dm_nivel)
  -- ESCRIBE      : TDM_MASK_TRACE (INSERT)
  -- ERRORES      : Ninguno: transaccion autonoma que nunca propaga el fallo (deja una migaja en
  --                DBMS_OUTPUT).
  -- LLAMADO DESDE: pkg_dm_enmascarar (wrapper proc_dm_trace), pkg_dm_descubrimiento,
  --                pkg_dm_trazabilidad.proc_dm_log_ejec_error y dm_liberar_ejecucion_activa.sql.
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
    -- El NIVEL ya no se deduce del texto de la fase: lo fija el catalogo
    -- TDM_PARAMETRO (grupo EVENTO). Historia: hasta el 10/09/26 la columna NIVEL
    -- no se escribia y los contadores WARN/ERROR de dm_enmascara, dm_enmascara_reanudar
    -- y KPI-03 de dm_validar_flujo eran siempre 0.
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

  -- FIX 2026-09-27 (auditoria estricta): SELECT MAX(error_id)+1 seguido de
  -- INSERT no es atomico -- dos llamadas concurrentes (dos sesiones logueando
  -- un error casi al mismo tiempo, escenario real bajo volumen con varios
  -- workers fallando cerca en el tiempo) pueden leer el mismo MAX antes de que
  -- ninguna confirme, generar el mismo error_id, y la segunda INSERT violaba
  -- el PK -- perdiendose en silencio (solo DBMS_OUTPUT), justo en la tabla
  -- cuyo proposito es sostener la trazabilidad de auditoria. No se vuelve a
  -- SEQ_DM_EJECUCION_ERR (podria seguir desincronizada de MAX(error_id) tras
  -- el incidente SRI2006) ni se anade una secuencia nueva (requeriria DDL
  -- adicional en el esquema). En su lugar: reintento optimista -- ante
  -- ORA-00001 especificamente, se recalcula el MAX y se reintenta el INSERT,
  -- hasta 5 veces. Una colision real bajo concurrencia es transitoria; el
  -- reintento la resuelve sin necesitar bloqueos ni objetos nuevos.
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
  -- LLAMADO DESDE: pkg_dm_enmascarar (wrapper) y pkg_dm_descubrimiento.proc_dm_log_error.
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
  -- Captura datos de sesion Oracle (sid/serial#/inst_id) de quien esta
  -- corriendo esta ejecucion_id, y refresca el heartbeat. Best-effort: la
  -- ausencia de SID/SERIAL# (permiso, RAC en failover) no debe abortar el
  -- proceso que la invoca, por eso el WHEN OTHERS exterior es silencioso.
  -- 2026-09-27: movida aqui desde pkg_dm_descubrimiento (04), que la tenia
  -- privada y duplicada palabra por palabra en pkg_dm_enmascarar (05).
  -- FIX 2026-09-27 (auditoria estricta): le faltaba PRAGMA
  -- AUTONOMOUS_TRANSACTION -- su COMMIT confirmaba directamente la
  -- transaccion del llamador, violando el principio de diseno que este mismo
  -- paquete declara en su cabecera ("el COMMIT nunca interfiere con la
  -- transaccion de negocio del llamador"). Con los 3 puntos de llamada
  -- actuales (inicio de proc_dm_enmascaramiento/proc_dm_descubrimiento/proc_dm_reanudar,
  -- siempre antes de tocar datos) esto no causaba dano hoy, pero es una bomba
  -- de tiempo ante cualquier futura llamada a mitad de un lote sin darse
  -- cuenta. Ahora es autonoma como el resto del paquete.
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
      -- FIX 2026-10-05 (hallazgo en vivo, ejecucion_id=1): el self-lookup
      -- anterior identificaba "mi propia sesion" por (audsid, username)
      -- contra GV$SESSION. Para conexiones SYS/AS SYSDBA eso no sirve:
      -- Oracle asigna el AUDSID centinela 4294967295 (2**32-1) a TODAS las
      -- sesiones SYS por igual, asi que con varias ventanas SYS abiertas a
      -- la vez (patron real de uso de este motor) el WHERE no distinguia
      -- nada y ROWNUM=1 se quedaba con cualquiera de ellas. Confirmado en
      -- vivo: ejecucion_id=1 quedo con sid=1088/serial#=29559 (una sesion
      -- SYS totalmente distinta, ya muerta) en vez del sid/serial# real del
      -- orquestador (visible en el titulo de su propia ventana SQL*Plus).
      -- SYS_CONTEXT('USERENV','SID')/('USERENV','INSTANCE') identifican la
      -- sesion ACTUAL sin ambiguedad para cualquier tipo de cuenta (no
      -- dependen de audsid ni username), y PRAGMA AUTONOMOUS_TRANSACTION no
      -- cambia este contexto -- es de sesion, no de transaccion. serial# no
      -- esta expuesto en USERENV, asi que se resuelve con un lookup local
      -- (V$SESSION, no GV$SESSION) por SID -- unico dentro de la instancia
      -- local, sin la ambiguedad de audsid/username del metodo anterior.
      -- Verificado contra los 3 puntos de llamada reales de este
      -- procedimiento (inicio de proc_dm_descubrimiento_core/proc_dm_reanudar
      -- en 04, proc_dm_enmascaramiento en 05): los tres lo invocan de forma
      -- sincrona, en la propia sesion orquestadora, nunca desde un job de
      -- DBMS_SCHEDULER ni un worker paralelo -- asi que SID/INSTANCE aqui
      -- siempre corresponden a la sesion real que arranco o reanudo la
      -- ejecucion_id.
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
    -- 2026-10-10 (auditoria industrial G8): no se propaga (el motor no debe caer por un
    -- latido), pero deja una migaja como el resto del paquete en vez de silencio total.
    WHEN OTHERS THEN
      BEGIN
        DBMS_OUTPUT.PUT_LINE('[pkg_dm_trazabilidad.proc_dm_refresca_sesion] no se pudo refrescar la sesion de ejecucion_id='||
                             p_ejecucion_id||': '||SQLERRM);
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
  END proc_dm_refresca_sesion;

  ------------------------------------------------------------------------------
  -- Verifica si la sesion Oracle que registro esta ejecucion_id sigue viva.
  -- 2026-09-27: movida aqui desde pkg_dm_descubrimiento (04); antes era
  -- privada y pkg_dm_enmascarar (05) no tenia equivalente propio.
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_sesion_viva
  -- PROPOSITO    : Indica si la sesion que lanzo una corrida sigue viva en GV$SESSION.
  -- ENTRADAS     : p_ejecucion_id; retorna 1 si hay sesion viva (no KILLED/SNIPED), 0 si no.
  -- LEE          : TDM_EJECUCION; GV$SESSION
  -- ESCRIBE      : ninguno
  -- ERRORES      : Ninguno: ante cualquier error devuelve 0.
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
        l_cnt := 0;
    END;

    RETURN CASE WHEN l_cnt > 0 THEN 1 ELSE 0 END;
  END func_dm_sesion_viva;

  ------------------------------------------------------------------------------
  -- Auto-cancelacion de ejecuciones huerfanas: barre TODAS las filas
  -- TDM_EJECUCION.ESTADO='EJECUTANDO' (cualquier esquema, cualquier
  -- FASE_PROCESO -- DESCUBRIMIENTO o ENMASCARAMIENTO) y las pasa a ABORTADA
  -- SOLO cuando la sesion Oracle que las origino esta confirmada como NO viva,
  -- o esta viva pero inactiva (sin ejecutar nada) durante mas de
  -- p_minutos_inactividad. No es un job de fondo: se invoca de forma
  -- perezosa desde los puntos de entrada de 04 y 05.
  --
  -- FIX CRITICO 2026-09-27 (auditoria estricta del motor completo): el diseno
  -- anterior autocancelaba por heartbeat obsoleto INCLUSO cuando gv$session
  -- confirmaba la sesion viva -- una unica sentencia larga (un UPDATE/chunk de
  -- DBMS_PARALLEL_EXECUTE sobre una columna de millones de filas) no vuelve a
  -- PL/SQL para llamar proc_dm_refresca_sesion hasta que termina, y ya se ha
  -- observado en produccion que UNA SOLA columna puede tardar 1-2 horas (ej.
  -- TBL_CUENTA_VOL.IBAN, 10.8M filas, ~31 min en la prueba del 27/09). Con el
  -- umbral por defecto de 15 min, cualquier ejecucion legitima de tablas
  -- grandes se marcaba ABORTADA mientras seguia corriendo de verdad -- el
  -- aborto es solo una bandera en TDM_EJECUCION (no mata la sesion Oracle), asi
  -- que el trabajo real continuaba mientras el motor creia el esquema libre,
  -- abriendo la puerta a que otra ejecucion arrancara en paralelo sobre las
  -- mismas tablas (func_dm_conflicto_running ya no veria la fila EJECUTANDO).
  --
  -- Nuevo criterio, usando gv$session.status ademas de la mera existencia de
  -- la sesion:
  --   * Sesion NO encontrada (l_cnt=0)            -> huerfana real. ABORTADA.
  --   * Sesion encontrada y ACTIVE (l_activos>0)   -> esta ejecutando SQL
  --                                                    AHORA MISMO (Oracle
  --                                                    marca ACTIVE mientras
  --                                                    el servidor sigue
  --                                                    dentro de la misma
  --                                                    llamada de usuario, ya
  --                                                    sea un UPDATE directo o
  --                                                    bloqueada esperando a
  --                                                    RUN_TASK). NUNCA se
  --                                                    autocancela, sea cual
  --                                                    sea el heartbeat.
  --   * Sesion encontrada pero INACTIVE (ociosa) y
  --     heartbeat obsoleto                         -> SI es sospechoso
  --                                                    (proceso colgado entre
  --                                                    pasos, o el cliente
  --                                                    abandono la sesion sin
  --                                                    cerrarla). Se conserva
  --                                                    el autosanado original.
  --   * Sesion encontrada, INACTIVE pero heartbeat
  --     todavia dentro del margen                  -> no se toca.
  -- El fallback cuando gv$session no se puede consultar (permiso, RAC) sigue
  -- siendo best-effort y solo actua si p_forzar_sin_vsession='Y' (default
  -- 'N' = no hacer nada), pero ahora TAMBIEN exige heartbeat obsoleto -- antes
  -- cancelaba de inmediato sin comprobar el heartbeat en absoluto.
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
  -- LLAMADO DESDE: pkg_dm_enmascarar.proc_dm_validar_concurrencia y la validacion de concurrencia del
  --                descubrimiento.
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

  -- Movido desde 04 (modularizacion 2026-10-10, R1d): misma logica, ahora compartida.

-- =========================================================
-- REVERSION COMPLETA 2026-10-03 (vespertino): se retira TODO el mecanismo
-- "el dato manda sobre el nombre" para IDENTIFICADOR_PERSONAL introducido el
-- 02/10/26 y ajustado el 03/10/26 (funciones func_dm_es_nombre_persona_valido,
-- func_dm_contiene_doc_identidad_valido y func_dm_contenido_parece_persona,
-- mas la regla sentinela __CONTENIDO_NOMBRE_PERSONA__ en 03_...carga_reglas).
-- Motivo (evaluacion solicitada por el usuario sobre los resultados reales de
-- @dm_descubre en DM_DUMMY y DATAM_ARCA_OWN el mismo dia):
--   1) REGRESION REAL CONFIRMADA: DATAM_ARCA_OWN.PRESTAMOS.EDIFICIO y
--      PRESTAMOS_BK.EDIFICIO (direcciones tipo "Paseo Maria Agustin, 36
--      (Pignatelli)") empezaron a clasificar PROBABLE/ENMASCARAR=Y. Causa
--      raiz: el regex de forma de nombre, al quitarle el ancla '$' el mismo
--      dia para intentar resolver PROMOTOR, pasa a aceptar como "nombre" el
--      PREFIJO de cualquier valor con 2 a 4 tokens capitalizados -- y un
--      nombre de calle/edificio en castellano tiene exactamente esa forma
--      lexica. Confirmado fila por fila contra TDM_COLUMNA_HIST real
--      (score_patron=67,4 = 100*0,674; ratio_match=337/500=0,674) y contra el
--      mismo regex ejecutado en Python sobre la muestra real.
--   2) EL FIX NUNCA CUMPLIO SU PROPIO OBJETIVO: el score_patron real de
--      EXPEDIENTES.PROMOTOR en produccion fue 46,8 (100*0,468), por debajo
--      del umbral PROBABLE (65) -- sigue en REVISAR/ENMASCARAR=N, igual que
--      antes de todo este cambio. La estimacion de ~73% de ratio citada en el
--      changelog del mismo dia (basada en combinar nombre+documento) NO se
--      corresponde con lo que el bucle de scoring realmente evalua (solo la
--      señal de nombre, tras simplificarse por costo mas temprano ese mismo
--      dia) -- un error de medicion propio, detectado al re-verificar con el
--      archivo real de 1000 filas: nombre-solo-sin-ancla=41,4%,
--      nombre-con-ancla=7,6%, documento-solo=25,2%, con-ancla-OR-documento=
--      32,8% -- ninguna combinacion realista alcanza 65 ni siquiera 45.
--   3) CONCLUSION: el mecanismo no logra enmascarar PROMOTOR (sigue N en
--      cualquier variante evaluada) y SI introduce un falso positivo real y
--      peligroso sobre datos de direccion/edificio -- a escala SRI2006 (79
--      tablas, ~100M filas) el mismo patron lexico (calle+numero+parentesis)
--      aparece en cualquier columna de domicilio/emplazamiento del esquema,
--      no solo en DM_DUMMY.EDIFICIO. Coste sin beneficio y con riesgo real:
--      se revierte por completo, no se parchea. El gate de
--      IDENTIFICADOR_PERSONAL vuelve a ser el simple chequeo por nombre de
--      columna (NOMBRE|APELLIDO|...) que existia antes del 02/10/26.
-- PROMOTOR queda, de forma deliberada, sin clasificacion automatica: es un
-- caso genuinamente mixto (persona fisica o entidad segun la fila) que un
-- heuristico de contenido generico no puede resolver con seguridad a esta
-- escala. Via correcta si el negocio confirma que debe enmascararse: FORCE
-- manual en TDM_EXCEPCION_COL (ya soportado por el motor), no un regex mas
-- permisivo evaluado sobre las 500 filas de muestra de cada columna de los
-- 79 tablas de SRI2006.
-- =========================================================

------------------------------------------------------------------------------
-- LOG DE ERRORES
-- 2026-10-09 (limpieza de duplicidad): ya NO escribe en TDM_EJECUCION_ERROR por su
-- cuenta. El unico escritor es pkg_dm_trazabilidad.proc_dm_log_ejec_error, que
-- ademas deja la linea ERROR.REGISTRADO en la linea de tiempo (TDM_MASK_TRACE)
-- enlazada por error_id. Esta rutina se conserva solo como atajo con la firma
-- historica del descubrimiento (7 llamadores) y como red de seguridad: NUNCA debe
-- poder abortar el proceso que esta protegiendo (historia: incidente SRI2006,
-- ORA-00001 en el PK del error escalaba un fallo de una columna a un aborto total;
-- la proteccion contra colision de error_id con reintento vive ahora en este paquete).
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
