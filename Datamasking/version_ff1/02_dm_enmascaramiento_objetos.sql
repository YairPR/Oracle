--------------------------------------------------------------------------------
-- Rediseño de objetos para proceso de enmascaramiento
--
-- Convención:
--   Tablas      : tdm_*
--   Secuencias  : seq_dm_*
--   Índices     : idm_*
--   PK          : pk_tdm_*
--   FK          : fk_tdm_*
--   CK          : ck_tdm_*
--
-- Alcance:
--   - Control operativo del masking
--   - Trazabilidad
--   - Estado de dependencias técnicas
--   - Resultado por tabla/columna
--   - Reglas especiales
--   - Sincronización/coherencia post-masking
--
-- Nota sobre tdm_mask_cache:
--   La cache NO es obligatoria para que el proceso sea determinista.
--   La determinística principal la da pkg_dm_func_mask a partir del valor origen.
--   Esta tabla solo se conserva como soporte opcional para casos de:
--     * alta repetición de valores
--     * dominios cortos y repetitivos
--     * optimización puntual
--   No debe usarse para textos libres, observaciones largas ni CLOB.
--------------------------------------------------------------------------------

-- 2026-10-05: esquema ya no va fijo -- se detecta solo. La tablespace ya NO
-- se detecta ni se usa: se quito la clausula TABLESPACE de todo CREATE TABLE/
-- INDEX de este archivo porque, sin ella, Oracle usa automaticamente la
-- tablespace por defecto del esquema actual (el mismo valor que antes se
-- calculaba a mano).
-- Normalmente este archivo lo incluye 99_install_datamasking.sql (que ya
-- hizo la deteccion y el ALTER SESSION antes de llegar aqui), pero se deja
-- la misma guardia por si se ejecuta este archivo suelto.
-- FIX 2026-10-05 (hallazgo real): la sustitucion &&var sin comillas (GRANT/
-- ALTER SESSION/TABLESPACE) resolvia a VACIO en el cliente SQL*Plus de este
-- entorno. Se usa una VARIABLE DE ENLACE real (bind, :g_esquemaast) en vez de
-- &&esquemaast -- un bind no depende de SET DEFINE/SCAN. Si este archivo se
-- ejecuta suelto (sin pasar por 99_install_datamasking.sql), VARIABLE vuelve a
-- declarar el bind sin problema (es idempotente).
variable g_esquemaast varchar2(30)
declare
  l_esquemaast dba_users.username%type;
begin
  select username into l_esquemaast
    from (select username from dba_users
           where username in ('ASTSYSADMIN','ACC_ADMIN')
           order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
   where rownum = 1;
  :g_esquemaast := l_esquemaast;
exception
  when no_data_found then
    raise_application_error(-20001,'No se encontro ni ASTSYSADMIN ni ACC_ADMIN en DBA_USERS -- no se puede determinar el esquema del motor DATAMASKING en esta base.');
end;
/
begin
  execute immediate 'ALTER SESSION SET CURRENT_SCHEMA = '||:g_esquemaast;
end;
/

--------------------------------------------------------------------------------
-- 0) TABLA DE SEGURIDAD (PEPPER / SEMILLA)
--------------------------------------------------------------------------------
CREATE TABLE tdm_secreto (
    clave  VARCHAR2(64)  NOT NULL,
    valor  VARCHAR2(128) NOT NULL,
    CONSTRAINT pk_tdm_secreto PRIMARY KEY (clave)
);

COMMENT ON TABLE tdm_secreto IS 'Semillas y secretos de enmascaramiento (pepper efimero por campana: clave = PEPPER_MASK:ejecucion_id).';
COMMENT ON COLUMN tdm_secreto.clave IS 'Identificador de la clave secreta.';
COMMENT ON COLUMN tdm_secreto.valor IS 'Valor de la clave secreta (Raw Hex o texto largo).';

--------------------------------------------------------------------------------
-- 0b) PARAMETROS Y CATALOGOS DEL MOTOR (TDM_PARAMETRO)
--     Una sola tabla clave/valor para todo lo que el motor consulta y que
--     conviene poder ajustar SIN recompilar paquetes.
--       grupo EVENTO  : catalogo de la linea de tiempo. clave = FASE.PASO,
--                       valor = nivel (INFO/WARN/ERROR), descripcion = que significa
--                       ese paso. pkg_dm_trazabilidad.proc_dm_trace lo consulta para
--                       fijar el nivel; un par que no este aqui se detecta con la
--                       consulta de auditoria del plan de pruebas (T-02).
--     Hoy solo existe el grupo EVENTO. Si mas adelante se decide tener
--     parametros por version o de entorno, se agrega el grupo al CHECK
--     ck_tdm_parametro_grupo; por ahora NO se captura version/undo/CPU/SGA/PGA.
--------------------------------------------------------------------------------
CREATE TABLE tdm_parametro (
    grupo               VARCHAR2(30)   NOT NULL,
    clave               VARCHAR2(100)  NOT NULL,
    valor               VARCHAR2(400),
    descripcion         VARCHAR2(200),
    fecha_modificacion  TIMESTAMP      DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_tdm_parametro PRIMARY KEY (grupo, clave),
    CONSTRAINT ck_tdm_parametro_grupo CHECK (grupo IN ('EVENTO'))
);

COMMENT ON TABLE tdm_parametro IS 'PREGUNTA: que valores o catalogos usa el motor y puedo ajustar sin recompilar. Grupo EVENTO = catalogo de pasos de la traza (FASE.PASO -> nivel y significado).';
COMMENT ON COLUMN tdm_parametro.grupo IS 'Familia del parametro. Hoy solo EVENTO (catalogo de pasos de la traza).';
COMMENT ON COLUMN tdm_parametro.clave IS 'Identificador dentro del grupo. En EVENTO: FASE.PASO tal como lo escribe proc_dm_trace.';
COMMENT ON COLUMN tdm_parametro.valor IS 'Valor. En EVENTO: nivel del paso (INFO, WARN o ERROR).';
COMMENT ON COLUMN tdm_parametro.descripcion IS 'Descripcion breve: de que es el parametro o que significa el paso.';
COMMENT ON COLUMN tdm_parametro.fecha_modificacion IS 'Fecha de la ultima modificacion del registro.';

-- Semilla del catalogo de eventos. Idempotente: si el paso ya existe solo se
-- refresca la descripcion; el NIVEL ajustado a mano por el operador se respeta.
MERGE INTO tdm_parametro p
USING (
      SELECT 'EVENTO' grupo, 'ENMASCARAMIENTO.INICIO' clave, 'INFO' valor, 'Arranque de proc_dm_enmascaramiento: esquema objetivo; en una reanudacion añade - REANUDACION desde solicitud_id=N.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'ENMASCARAMIENTO.REANUDACION' clave, 'INFO' valor, 'Reanudacion de una ejecucion interrumpida: intento, columnas ya confirmadas (se omiten) y pendientes.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'PRE.INICIO' clave, 'INFO' valor, 'Comienza la desactivacion de dependencias (FK, triggers) de las tablas a enmascarar.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'PRE.FK_JERARQUIA' clave, 'INFO' valor, 'Una FK hija->padre detectada en el alcance; documenta el orden de integridad antes de tocar nada.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'PRE.SKIP_DEP_POLICY' clave, 'INFO' valor, 'Dependencia NO tocada porque su accion PRE (SOLO_INFORMATIVO/SIN_ACCION) lo indica; decision de politica, no fallo.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'PRE.SKIP_DEP_NOT_FOUND' clave, 'WARN' valor, 'La dependencia del catalogo ya no existe en el diccionario; se omite. Revisar si el catalogo esta desactualizado.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'PRE.FIN' clave, 'INFO' valor, 'Terminada la desactivacion de dependencias.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'PROPAGACION.PROPAGA_START' clave, 'INFO' valor, 'Comienza el recalculo de dominios referenciales (FK) antes de enmascarar.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'PROPAGACION.PROPAGA_END' clave, 'INFO' valor, 'Dominios FK propagados con exito.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'PROPAGACION.PROPAGA_ERR' clave, 'ERROR' valor, 'Fallo propagando dominios FK; el enmascarado se aborta (sin propagacion valida no hay integridad).' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'PROPAGACION.RI_REINCLUYE' clave, 'INFO' valor, 'El descubrimiento re-incluyo una columna (Y) por integridad referencial de su dominio.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.PEPPER_START' clave, 'INFO' valor, 'Comienza la generacion del pepper efimero de la campana.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.PEPPER_END' clave, 'INFO' valor, 'Pepper efimero listo; los workers paralelos leen la misma clave.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.PEPPER_ERR' clave, 'ERROR' valor, 'Fallo preparando el pepper; el enmascarado se aborta (sin pepper no se enmascara).' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.PREFLIGHT_OK' clave, 'INFO' valor, 'Pre-flight de tareas DBMS_PARALLEL_EXECUTE: ninguna huerfana bloquea.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.PREFLIGHT_INFO' clave, 'INFO' valor, 'Tarea de otra corrida o fuera de alcance: se informa pero no bloquea.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.PREFLIGHT_ORFANA' clave, 'WARN' valor, 'Tarea huerfana de una columna a enmascarar: bloquea hasta decidir (reanudar o descartar).' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.PREFLIGHT_ABORT' clave, 'ERROR' valor, 'Pre-flight aborta la corrida (ORA-20331) por tareas huerfanas; no se toco ningun dato.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.COL_INICIO' clave, 'INFO' valor, 'Comienza el enmascarado de una columna (identificador y ruta elegidos).' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.EXCEPTION_FORCE' clave, 'INFO' valor, 'La columna usa el identificador forzado de TDM_EXCEPCION_COL.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.SKIP_EXCLUDE' clave, 'INFO' valor, 'Columna omitida porque TDM_EXCEPCION_COL la excluye.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.SKIP_TABLE' clave, 'INFO' valor, 'Tabla omitida: todas sus columnas estan excluidas.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.SKIP_TABLE_TABMODE' clave, 'INFO' valor, 'Tabla omitida en el modo por tabla de proc_dm_enmascara_tabla.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.SKIP_AUTO_LEN' clave, 'WARN' valor, 'Columna sensible SIN enmascarar: su longitud es menor que el minimo del identificador.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.SKIP_ORA00001' clave, 'WARN' valor, 'Columna auto-excluida tras colision de unicidad (ORA-00001): queda SIN enmascarar y bloquea FINALIZADO.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.SKIP_ORA12899' clave, 'WARN' valor, 'Columna auto-excluida tras ORA-12899 (valor mayor que la columna).' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.SKIP_ORA06502' clave, 'WARN' valor, 'Columna auto-excluida tras ORA-06502 sin fallback posible.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.APPLY_COL' clave, 'INFO' valor, 'Columna ENMASCARADA y confirmada: una linea por columna con filas, ruta (UPDATE o CHUNKS) y duracion. PUNTO DE CONTROL de la reanudacion: una columna con APPLY_COL no se vuelve a enmascarar.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.APPLY_COL_SAFE_FALLBACK' clave, 'WARN' valor, 'Columna enmascarada con la expresion de reserva tras ORA-06502; tambien es punto de control de reanudacion.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.APPLY_COL_COLLISION' clave, 'INFO' valor, 'Reservado: columna confirmada por una ruta de colision (compatibilidad con trazas antiguas).' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.TAREA_DESCARTADA' clave, 'WARN' valor, 'Una tarea interrumpida se descarto con proc_dm_gestiona_tareas DESCARTAR.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.NOOP' clave, 'INFO' valor, 'No habia columnas a enmascarar en esta corrida.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'MASK.RESUMEN' clave, 'INFO' valor, 'Resumen del bucle de columnas: procesadas, fallidas, tablas y filas afectadas.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'POST_SYNC.SYNC' clave, 'INFO' valor, 'Sincronizacion de una columna origen hacia su destino dependiente (filas).' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'POST_SYNC.SYNC_OK' clave, 'INFO' valor, 'Verificacion post-sincronizacion: sin diferencias.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'POST_SYNC.SYNC_MISMATCH' clave, 'WARN' valor, 'Verificacion post-sincronizacion: quedan diferencias entre origen y destino.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'POST_SYNC.WARN_SYNC' clave, 'WARN' valor, 'Fallo sincronizando un par origen-destino; se continua.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'POST_SYNC.WARN_SYNC_LEN' clave, 'WARN' valor, 'Par origen-destino omitido por longitud insuficiente del destino.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'POST_SYNC.WARN_SYNC_CHECK' clave, 'WARN' valor, 'Fallo al verificar un par sincronizado.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'POST.INICIO' clave, 'INFO' valor, 'Comienza la rehabilitacion de dependencias.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'POST.SKIP_POST_POLICY' clave, 'INFO' valor, 'Dependencia NO rehabilitada porque su accion POST (REVISAR/SIN_ACCION) exige revision manual.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'POST.POST_CHECK_INVALID' clave, 'WARN' valor, 'Tras rehabilitar quedan objetos INVALID nuevos o constraints no ENABLED.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'POST.FIN' clave, 'INFO' valor, 'Terminada la rehabilitacion de dependencias.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'FIN.OK' clave, 'INFO' valor, 'Enmascaramiento finalizado sin errores.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'FIN.ERROR' clave, 'ERROR' valor, 'Enmascaramiento terminado con errores (la corrida no queda FINALIZADA).' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'FIN.PII_SIN_ENMASCARAR' clave, 'ERROR' valor, 'Hay columnas sensibles auto-excluidas: no se permite FINALIZADO.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'FIN.PEPPER_PURGE_WARN' clave, 'WARN' valor, 'Corrida FINALIZADA pero no se pudo autopurgar el pepper; purgar a mano.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'ERROR.REGISTRADO' clave, 'ERROR' valor, 'Un error se registro en TDM_EJECUCION_ERROR; el detalle empieza por error_id=N para ubicarlo.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'CONTROL.UPD_EJEC_BLOQUEADO' clave, 'WARN' valor, 'Un ping de progreso no se aplico: la ejecucion ya estaba cerrada (no se resucita).' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'CONTROL.UPD_EJEC_FALLO' clave, 'ERROR' valor, 'Fallo actualizando el progreso en TDM_EJECUCION.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'CONTROL.CLOSE_SOL_OPEN_FALLO' clave, 'ERROR' valor, 'Fallo cerrando solicitudes abiertas de una corrida anterior.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'DESCUBRIMIENTO.TABLAS_OMITIDAS' clave, 'INFO' valor, 'Tablas sin filas que no se analizaron (solo aparece si hay alguna).' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'DESCUBRIMIENTO.FINAL_OBSOLETAS' clave, 'INFO' valor, 'Se retiraron de TDM_COLUMNA_FINAL columnas que ya no cumplen el descubrimiento o ya no existen.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'DESCUBRIMIENTO.FINAL_OBSOLETAS_ERR' clave, 'WARN' valor, 'Fallo retirando columnas obsoletas del catalogo final.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'DESCUBRIMIENTO.PROPAGA_DOMINIOS_ERR' clave, 'WARN' valor, 'Fallo propagando dominios FK durante la sincronizacion del catalogo.' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'DESCUBRIMIENTO.RESUMEN' clave, 'INFO' valor, 'Resumen unico del descubrimiento: tablas con columnas evaluadas, columnas evaluadas y columnas a enmascarar (Y).' descripcion FROM dual UNION ALL
      SELECT 'EVENTO' grupo, 'ADMIN.LIBERADA_MANUAL_DBA' clave, 'WARN' valor, 'Un DBA cerro a mano una ejecucion con dm_liberar_ejecucion_activa.' descripcion FROM dual
) s
ON (p.grupo = s.grupo AND p.clave = s.clave)
WHEN MATCHED THEN UPDATE SET p.descripcion = s.descripcion
WHEN NOT MATCHED THEN INSERT (grupo, clave, valor, descripcion)
     VALUES (s.grupo, s.clave, s.valor, s.descripcion);

COMMIT;

--------------------------------------------------------------------------------
-- 1) SOLICITUD DE ENMASCARAMIENTO
--------------------------------------------------------------------------------
-- Cancelacion, latido y sesion Oracle de la corrida viven SOLO en TDM_EJECUCION
-- (una corrida = una sesion). Esta tabla guarda unicamente lo propio de cada
-- INTENTO (reintento, punto de control, contadores del intento).
CREATE TABLE tdm_mask_solicitud (
    solicitud_id         NUMBER         NOT NULL,
    ejecucion_id         NUMBER         NOT NULL,
    ora_esquema          VARCHAR2(128)  NOT NULL,
    estado               VARCHAR2(30)   NOT NULL,
    fase_actual          VARCHAR2(30),
    checkpoint_paso      VARCHAR2(100),
    reintento_nro        NUMBER         DEFAULT 0,
    forzar_reproceso     CHAR(1)        DEFAULT 'N',
    fecha_inicio         TIMESTAMP      DEFAULT SYSTIMESTAMP,
    fecha_fin            TIMESTAMP,
    filas_procesadas     NUMBER         DEFAULT 0,
    filas_error          NUMBER         DEFAULT 0,
    tablas_procesadas    NUMBER         DEFAULT 0,
    columnas_procesadas  NUMBER         DEFAULT 0,
    ultima_tabla         VARCHAR2(128),
    ultima_columna       VARCHAR2(128),
    detalle              VARCHAR2(4000),
    CONSTRAINT pk_tdm_mask_solicitud PRIMARY KEY (solicitud_id),
    CONSTRAINT fk_tdm_mask_sol_ejec FOREIGN KEY (ejecucion_id)
        REFERENCES tdm_ejecucion (ejecucion_id),
    CONSTRAINT ck_tdm_mask_sol_forzar CHECK (forzar_reproceso IN ('Y','N')),
    CONSTRAINT ck_tdm_mask_sol_estado CHECK (
        estado IN ('PENDIENTE','EN_PROCESO','FINALIZADO','ERROR','CANCELADO','REPROCESANDO')
    )
);

CREATE INDEX idm_mask_sol_01 ON tdm_mask_solicitud (ejecucion_id, estado);

CREATE INDEX idm_mask_sol_02 ON tdm_mask_solicitud (ora_esquema, fecha_inicio);

-- B.1: Vincular tdm_ejecucion_error con tdm_mask_solicitud de forma diferida para respetar el orden de creación
ALTER TABLE tdm_ejecucion_error 
    ADD CONSTRAINT fk_tdm_ejec_err_sol FOREIGN KEY (solicitud_id) 
    REFERENCES tdm_mask_solicitud (solicitud_id);

COMMENT ON TABLE tdm_mask_solicitud IS 'PREGUNTA: que intentos de enmascarar hubo dentro de una corrida y como terminó cada uno. Una fila por intento (primer arranque o reanudación): estado, punto de control y contadores propios. Latido, sesión y cancelación están en TDM_EJECUCION.';

COMMENT ON COLUMN tdm_mask_solicitud.solicitud_id IS 'Identificador único de la solicitud de enmascaramiento.';

COMMENT ON COLUMN tdm_mask_solicitud.ejecucion_id IS 'Referencia a la ejecución maestra registrada en tdm_ejecucion.';

COMMENT ON COLUMN tdm_mask_solicitud.ora_esquema IS 'Esquema Oracle objetivo del enmascaramiento.';

COMMENT ON COLUMN tdm_mask_solicitud.estado IS 'Estado del intento: PENDIENTE, EN_PROCESO, FINALIZADO, ERROR, CANCELADO o REPROCESANDO.';

COMMENT ON COLUMN tdm_mask_solicitud.fase_actual IS 'Fase actual del flujo de masking.';

COMMENT ON COLUMN tdm_mask_solicitud.checkpoint_paso IS 'Punto de control del proceso.';

COMMENT ON COLUMN tdm_mask_solicitud.reintento_nro IS 'Número de reintento acumulado.';

COMMENT ON COLUMN tdm_mask_solicitud.forzar_reproceso IS 'Indica si la solicitud fue lanzada en modo reproceso forzado.';

COMMENT ON COLUMN tdm_mask_solicitud.filas_procesadas IS 'Contador acumulado de filas tratadas.';

COMMENT ON COLUMN tdm_mask_solicitud.filas_error IS 'Contador acumulado de errores.';

COMMENT ON COLUMN tdm_mask_solicitud.tablas_procesadas IS 'Contador acumulado de tablas tratadas.';

COMMENT ON COLUMN tdm_mask_solicitud.columnas_procesadas IS 'Contador acumulado de columnas evaluadas.';

COMMENT ON COLUMN tdm_mask_solicitud.ultima_tabla IS 'Última tabla procesada.';

COMMENT ON COLUMN tdm_mask_solicitud.ultima_columna IS 'Última columna evaluada o tratada.';

COMMENT ON COLUMN tdm_mask_solicitud.detalle IS 'Detalle técnico o funcional del subproceso.';

--------------------------------------------------------------------------------
-- 2) TRACE DE ENMASCARAMIENTO
--------------------------------------------------------------------------------
CREATE TABLE tdm_mask_trace (
    trace_id             NUMBER         NOT NULL,
    solicitud_id         NUMBER,
    ejecucion_id         NUMBER,
    nivel                VARCHAR2(10)   DEFAULT 'INFO',
    fase                 VARCHAR2(40),
    paso                 VARCHAR2(120),
    detalle              VARCHAR2(4000),
    fecha_evento         DATE           DEFAULT SYSDATE,
    duracion_seg         NUMBER(12,2),
    CONSTRAINT pk_tdm_mask_trace PRIMARY KEY (trace_id),
    CONSTRAINT fk_tdm_mask_trace_sol FOREIGN KEY (solicitud_id)
        REFERENCES tdm_mask_solicitud (solicitud_id),
    CONSTRAINT fk_tdm_mask_trace_ejec FOREIGN KEY (ejecucion_id)
        REFERENCES tdm_ejecucion (ejecucion_id),
    CONSTRAINT ck_tdm_mask_trace_nivel CHECK (nivel IN ('INFO','WARN','ERROR'))
);

CREATE INDEX idm_mask_trace_01  ON tdm_mask_trace (ejecucion_id, fase, paso, fecha_evento);

CREATE INDEX idm_mask_trace_02  ON tdm_mask_trace (solicitud_id, fase, paso, fecha_evento);

COMMENT ON TABLE tdm_mask_trace IS 'PREGUNTA: que paso, en que orden y cuanto tardo. Linea de tiempo de una corrida: una fila por paso del catalogo TDM_PARAMETRO (grupo EVENTO). El enmascaramiento deja todos sus pasos; el descubrimiento deja solo un resumen y, aparte, tablas omitidas, avisos o errores. Cada error queda ubicado aqui y su detalle completo esta en TDM_EJECUCION_ERROR. No guarda valores de datos.';

COMMENT ON COLUMN tdm_mask_trace.trace_id IS 'Identificador único del evento de trace.';

COMMENT ON COLUMN tdm_mask_trace.solicitud_id IS 'Referencia a la solicitud de enmascaramiento.';

COMMENT ON COLUMN tdm_mask_trace.ejecucion_id IS 'Referencia a la ejecución maestra.';

COMMENT ON COLUMN tdm_mask_trace.nivel IS 'Nivel del evento (INFO, WARN, ERROR), tomado del catalogo TDM_PARAMETRO grupo EVENTO.';

COMMENT ON COLUMN tdm_mask_trace.fase IS 'Fase funcional del evento (ENMASCARAMIENTO, PRE, PROPAGACION, MASK, POST_SYNC, POST, FIN, DESCUBRIMIENTO, CONTROL, ERROR, ADMIN). Ya NO codifica el nivel.';

COMMENT ON COLUMN tdm_mask_trace.paso IS 'Paso concreto; con la fase forma la clave del catalogo de eventos.';
COMMENT ON COLUMN tdm_mask_trace.duracion_seg IS 'Duracion del paso en segundos, con 2 decimales (NULL si no se midio).';

COMMENT ON COLUMN tdm_mask_trace.detalle IS 'Texto del evento. En los pasos por columna empieza por ESQUEMA.TABLA.COLUMNA; el formato ''ESQUEMA.TABLA.COLUMNA filas=N'' de MASK.APPLY_COL lo lee la reanudacion como punto de control: no cambiarlo. En ERROR.REGISTRADO empieza por error_id=N (clave en TDM_EJECUCION_ERROR).';

COMMENT ON COLUMN tdm_mask_trace.fecha_evento IS 'Fecha y hora del evento, al segundo (tipo DATE). Para verla como DD-MM-YYYY HH24:MI:SS: TO_CHAR(fecha_evento,''DD-MM-YYYY HH24:MI:SS''). Para ordenar eventos del mismo segundo usar trace_id.';

--------------------------------------------------------------------------------
-- 3) ESTADO PRE/POST DE DEPENDENCIAS
--------------------------------------------------------------------------------
CREATE TABLE tdm_mask_dep_estado (
    solicitud_id         NUMBER         NOT NULL,
    tipo_objeto          VARCHAR2(20)   NOT NULL,
    ora_owner            VARCHAR2(128)  NOT NULL,
    table_name           VARCHAR2(128),
    objeto_name          VARCHAR2(128)  NOT NULL,
    estado_previo        VARCHAR2(20),
    estado_posterior     VARCHAR2(30),
    deshabilitado_ok     CHAR(1)        DEFAULT 'N',
    habilitado_ok        CHAR(1)        DEFAULT 'N',
    orden_rehabilitacion NUMBER         DEFAULT 1,
    mensaje_error        VARCHAR2(4000),
    fecha_pre            TIMESTAMP,
    fecha_post           TIMESTAMP,
    CONSTRAINT pk_tdm_mask_dep_estado PRIMARY KEY (
        solicitud_id, tipo_objeto, ora_owner, table_name, objeto_name
    ),
    CONSTRAINT fk_tdm_mask_dep_sol FOREIGN KEY (solicitud_id)
        REFERENCES tdm_mask_solicitud (solicitud_id),
    CONSTRAINT ck_tdm_mask_dep_tipo CHECK (tipo_objeto IN ('CONSTRAINT','TRIGGER')),
    CONSTRAINT ck_tdm_mask_dep_desh CHECK (deshabilitado_ok IN ('Y','N')),
    CONSTRAINT ck_tdm_mask_dep_hab CHECK (habilitado_ok IN ('Y','N'))
);

CREATE INDEX idm_mask_dep_01 ON tdm_mask_dep_estado (solicitud_id, tipo_objeto, ora_owner);

COMMENT ON TABLE tdm_mask_dep_estado IS 'Estado previo y posterior de dependencias técnicas deshabilitadas/habilitadas durante el masking.';

COMMENT ON COLUMN tdm_mask_dep_estado.solicitud_id IS 'Referencia a la solicitud de enmascaramiento.';

COMMENT ON COLUMN tdm_mask_dep_estado.tipo_objeto IS 'Tipo de objeto gestionado en el pre/post: CONSTRAINT o TRIGGER.';

COMMENT ON COLUMN tdm_mask_dep_estado.ora_owner IS 'Owner del objeto dependiente.';

COMMENT ON COLUMN tdm_mask_dep_estado.table_name IS 'Tabla afectada, si aplica.';

COMMENT ON COLUMN tdm_mask_dep_estado.objeto_name IS 'Nombre del constraint o trigger.';

COMMENT ON COLUMN tdm_mask_dep_estado.estado_previo IS 'Estado original antes de deshabilitar.';

COMMENT ON COLUMN tdm_mask_dep_estado.estado_posterior IS 'Estado final tras rehabilitar.';

COMMENT ON COLUMN tdm_mask_dep_estado.deshabilitado_ok IS 'Indica si la operación de deshabilitado se ejecutó correctamente.';

COMMENT ON COLUMN tdm_mask_dep_estado.habilitado_ok IS 'Indica si la operación de rehabilitado se ejecutó correctamente.';

COMMENT ON COLUMN tdm_mask_dep_estado.orden_rehabilitacion IS 'Orden recomendado de rehabilitación.';

COMMENT ON COLUMN tdm_mask_dep_estado.mensaje_error IS 'Mensaje técnico asociado a la operación sobre la dependencia.';

COMMENT ON COLUMN tdm_mask_dep_estado.fecha_pre IS 'Fecha de operación pre.';

COMMENT ON COLUMN tdm_mask_dep_estado.fecha_post IS 'Fecha de operación post.';


--------------------------------------------------------------------------------
-- 8) SECUENCIAS
--------------------------------------------------------------------------------
CREATE SEQUENCE seq_dm_mask_solicitud START WITH 1  INCREMENT BY 1  NOCACHE;

CREATE SEQUENCE seq_dm_mask_trace  START WITH 1  INCREMENT BY 1  NOCACHE;

CREATE SEQUENCE seq_dm_mask_regla_esp  START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE SEQUENCE seq_dm_mask_relacion_sync START WITH 1 INCREMENT BY 1  NOCACHE;

--------------------------------------------------------------------------------
-- 5) REGLAS ESPECIALES DE TRATAMIENTO (mecanismo GENERICO del motor; sin
--    literales de ningun cliente en esta capa)
--------------------------------------------------------------------------------
-- FIX 2026-09-28 (peer review): esta seccion se titulaba "...SIGAD" aunque la
-- tabla es generica (cero literales de cliente aqui, ver nota de portabilidad
-- mas abajo). Es un mecanismo del motor para solicitudes de tratamiento
-- especial por columna (p.ej. mantener 1er/ultimo caracter, IBAN continuo,
-- documento segun tipo); SIGAD es el CASO DE USO que hoy la puebla via
-- SIGAD/config_sigad.sql (dato, no codigo), no el dueño del mecanismo.
CREATE TABLE tdm_mask_regla_esp (
    regla_id              NUMBER         NOT NULL,
    ora_esquema          VARCHAR2(128)  NOT NULL,
    ora_owner            VARCHAR2(128)  NOT NULL,
    table_name            VARCHAR2(128)  NOT NULL,
    column_name           VARCHAR2(128)  NOT NULL,
    tipo_regla            VARCHAR2(50)   NOT NULL,
    valor_regla           VARCHAR2(4000),
    activa                CHAR(1)        DEFAULT 'Y',
    observacion           VARCHAR2(4000),
    CONSTRAINT pk_tdm_mask_regla_esp PRIMARY KEY (regla_id),
    CONSTRAINT ck_tdm_mask_regla_act CHECK (activa IN ('Y','N'))
);

CREATE INDEX idm_mask_regla_01 ON tdm_mask_regla_esp (ora_esquema, ora_owner, table_name, column_name, activa);

COMMENT ON TABLE tdm_mask_regla_esp IS 'Reglas especiales de tratamiento por tabla/columna.';

COMMENT ON COLUMN tdm_mask_regla_esp.tipo_regla IS 'Tipo de regla especial: DOC_SEGUN_TIPO, DOC_UNIFICADO_MANTENER_1_Y_ULTIMO, IBAN_ES_CONTINUO, etc.';

COMMENT ON COLUMN tdm_mask_regla_esp.valor_regla IS 'Valor libre o metadata de la regla especial.';

COMMENT ON COLUMN tdm_mask_regla_esp.observacion IS 'Observación funcional o técnica asociada a la regla.';

--------------------------------------------------------------------------------
-- 6) RELACIONES DE SINCRONIZACION POST-MASKING (mecanismo GENERICO del motor;
--    sin literales de ningun cliente en esta capa)
--------------------------------------------------------------------------------
-- FIX 2026-09-28 (peer review): idem nota de la seccion 5 -- esta tabla es
-- generica (coherencia entre tablas relacionadas por join no expresado como
-- FK real); SIGAD es hoy el unico caso de uso que la puebla (13 filas en
-- SIGAD/config_sigad.sql, SEGUSUARIO como maestro hacia PERPROFESOR/
-- CENALUMNO/CENFAMILIAR), no el dueño del mecanismo.
CREATE TABLE tdm_mask_relacion_sync (
    sync_id               NUMBER         NOT NULL,
    ora_esquema          VARCHAR2(128)  NOT NULL,
    tabla_origen          VARCHAR2(128)  NOT NULL,
    columna_join_origen   VARCHAR2(128)  NOT NULL,
    tabla_destino         VARCHAR2(128)  NOT NULL,
    columna_join_destino  VARCHAR2(128)  NOT NULL,
    columna_origen        VARCHAR2(128)  NOT NULL,
    columna_destino       VARCHAR2(128)  NOT NULL,
    activa                CHAR(1)        DEFAULT 'Y',
    prioridad             NUMBER         DEFAULT 1,
    observacion           VARCHAR2(4000),
    CONSTRAINT pk_tdm_mask_relacion_sync PRIMARY KEY (sync_id),
    CONSTRAINT ck_tdm_mask_sync_act CHECK (activa IN ('Y','N'))
);

CREATE INDEX idm_mask_sync_01 ON tdm_mask_relacion_sync (ora_esquema, tabla_origen, tabla_destino, activa);

COMMENT ON TABLE tdm_mask_relacion_sync IS 'Relaciones de sincronización/coherencia entre tablas tras el masking.';

COMMENT ON COLUMN tdm_mask_relacion_sync.tabla_origen IS 'Tabla desde la cual se copiará el valor coherente.';

COMMENT ON COLUMN tdm_mask_relacion_sync.tabla_destino IS 'Tabla hacia la cual se propagará el valor coherente.';

COMMENT ON COLUMN tdm_mask_relacion_sync.columna_join_origen IS 'Columna de unión en la tabla origen.';

COMMENT ON COLUMN tdm_mask_relacion_sync.columna_join_destino IS 'Columna de unión en la tabla destino.';

COMMENT ON COLUMN tdm_mask_relacion_sync.columna_origen IS 'Columna origen cuyo valor ya enmascarado se propagará.';

COMMENT ON COLUMN tdm_mask_relacion_sync.columna_destino IS 'Columna destino que se sincronizará.';

COMMENT ON COLUMN tdm_mask_relacion_sync.prioridad IS 'Prioridad de ejecución para la sincronización.';

COMMENT ON COLUMN tdm_mask_relacion_sync.observacion IS 'Observación funcional o técnica de la sincronización.';




-- Limpieza (2026-09-16, hallazgo R-03): aqui habia un bloque comentado de
-- ~250 lineas que mezclaba dos cosas distintas:
--   1) INSERTs semilla especificos de SIGAD_ACAD_OWN (reglas especiales y
--      relaciones de sincronizacion). Esto violaba el criterio de
--      portabilidad del motor (cero literales de cliente en 01/02/03/04/05/06)
--      y ademas estaba DUPLICADO: la version completa y vigente vive en
--      SIGAD/config_sigad.sql (94 FORCE, 18 EXCLUDE, 16 keep-ends,
--      1 IBAN_ES_CONTINUO, 7 DOC_SEGUN_TIPO, 13 relacion_sync). Eliminado
--      aqui sin perdida: no era la fuente autoritativa.
--   2) La DDL de TDM_MASK_CACHE (cache determinista opcional). Esa parte se
--      conserva mas abajo, ahora activa y documentada por separado, ya que
--      es infraestructura generica (no especifica de cliente) pensada para
--      la Fase 2 de rendimiento (precifrado por valor distinto).

--------------------------------------------------------------------------------
-- 7) CACHE DETERMINISTA OPCIONAL
--------------------------------------------------------------------------------
-- Uso recomendado SOLO en casos específicos:
--   - dominios pequeños y muy repetitivos
--   - nombres / apellidos muy repetidos
--   - documentos repetidos en muchas tablas
-- No usar para:
--   - observaciones
--   - direcciones largas
--   - textos libres
--   - CLOB / NCLOB
--
-- SIGUE DESACTIVADA A PROPOSITO (2026-09-16): ningún paquete del motor lee
-- ni escribe esta tabla hoy (el mapa equivalente en pkg_dm_enmascarar,
-- TDM_MASK_KEY_MAP, se eliminó deliberadamente junto con su código muerto -
-- ver auditoría FF1). Activarla sin el código que la use sería crear
-- infraestructura huérfana. Se deja su DDL lista y documentada para cuando
-- se acometa la Fase 2 de rendimiento (precálculo por valor distinto);
-- descomentar entonces junto con el código de lectura/escritura en 05.
--------------------------------------------------------------------------------
/*
CREATE TABLE tdm_mask_cache (
    tipo         VARCHAR2(30)   NOT NULL,
    original     VARCHAR2(4000) NOT NULL,
    enmascarado  VARCHAR2(4000) NOT NULL,
    CONSTRAINT pk_tdm_mask_cache PRIMARY KEY (tipo, original)
);

CREATE INDEX idm_mask_cache_01
    ON tdm_mask_cache (tipo, enmascarado);

COMMENT ON TABLE tdm_mask_cache IS
'Cache determinista opcional de valores originales y enmascarados. No es obligatoria para la determinística del proceso.';

COMMENT ON COLUMN tdm_mask_cache.tipo IS
'Tipo lógico de dato enmascarado: EMAIL, NOMBRE, NIF, TELEFONO, etc.';

COMMENT ON COLUMN tdm_mask_cache.original IS
'Valor original detectado antes del enmascaramiento.';

COMMENT ON COLUMN tdm_mask_cache.enmascarado IS
'Valor enmascarado final utilizado para consistencia adicional, si se decide usar cache.';
*/