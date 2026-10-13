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
--------------------------------------------------------------------------------

-- El esquema del motor se detecta solo. No se usa TABLESPACE en los CREATE: Oracle toma la del
-- esquema actual. Normalmente lo incluye 99_install_datamasking.sql (que ya hizo la deteccion);
-- se deja la misma guardia por si se ejecuta suelto.
-- Se usa una variable de enlace (:g_esquemaast) en vez de &&esquemaast sin comillas, que algunos
-- clientes SQL*Plus resuelven a vacio; VARIABLE es idempotente.
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
-- 0b) CATALOGO DE EVENTOS DE LA TRAZA (TDM_MASK_TRACE_EVENTO)
--     Diccionario de TDM_MASK_TRACE: para cada par FASE/PASO que escribe proc_dm_trace fija el
--     nivel (INFO/WARN/ERROR) y explica el paso. pkg_dm_trazabilidad.proc_dm_trace lo consulta
--     para fijar el nivel. No guarda parametros de ejecucion: los umbrales y constantes del
--     motor viven en el codigo.
--------------------------------------------------------------------------------
CREATE TABLE tdm_mask_trace_evento (
    fase                VARCHAR2(30)   NOT NULL,
    paso                VARCHAR2(70)   NOT NULL,
    nivel               VARCHAR2(5)    NOT NULL,
    descripcion         VARCHAR2(400),
    CONSTRAINT pk_tdm_mask_trace_evento PRIMARY KEY (fase, paso),
    CONSTRAINT ck_tdm_mask_trace_evento_niv CHECK (nivel IN ('INFO','WARN','ERROR'))
);

COMMENT ON TABLE tdm_mask_trace_evento IS 'PREGUNTA: que significa cada paso de la traza y con que nivel se registra. Catalogo de TDM_MASK_TRACE: FASE + PASO -> nivel y significado.';
COMMENT ON COLUMN tdm_mask_trace_evento.fase IS 'Fase tal como la escribe proc_dm_trace (ENMASCARAMIENTO, PRE, MASK, DESCUBRIMIENTO...).';
COMMENT ON COLUMN tdm_mask_trace_evento.paso IS 'Paso dentro de la fase tal como lo escribe proc_dm_trace.';
COMMENT ON COLUMN tdm_mask_trace_evento.nivel IS 'Nivel del paso: INFO, WARN o ERROR. Es el que copia TDM_MASK_TRACE.NIVEL.';
COMMENT ON COLUMN tdm_mask_trace_evento.descripcion IS 'Que significa el paso y que debe hacer el DBA si aparece.';

-- Semilla del catalogo de eventos. Idempotente: si el paso ya existe solo se
-- refresca la descripcion; el NIVEL ajustado a mano por el operador se respeta.
MERGE INTO tdm_mask_trace_evento p
USING (
      SELECT 'ENMASCARAMIENTO' fase, 'INICIO' paso, 'INFO' nivel, 'Arranque de proc_dm_enmascaramiento: esquema objetivo; en una reanudacion añade - REANUDACION desde solicitud_id=N.' descripcion FROM dual UNION ALL
      SELECT 'ENMASCARAMIENTO' fase, 'REANUDACION' paso, 'INFO' nivel, 'Reanudacion de una ejecucion interrumpida: intento, columnas ya confirmadas (se omiten) y pendientes.' descripcion FROM dual UNION ALL
      SELECT 'PRE' fase, 'INICIO' paso, 'INFO' nivel, 'Comienza la desactivacion de dependencias (FK, triggers) de las tablas a enmascarar.' descripcion FROM dual UNION ALL
      SELECT 'PRE' fase, 'FK_JERARQUIA' paso, 'INFO' nivel, 'Una FK hija->padre detectada en el alcance; documenta el orden de integridad antes de tocar nada.' descripcion FROM dual UNION ALL
      SELECT 'PRE' fase, 'SKIP_DEP_POLICY' paso, 'INFO' nivel, 'Dependencia NO tocada porque su accion PRE (SOLO_INFORMATIVO/SIN_ACCION) lo indica; decision de politica, no fallo.' descripcion FROM dual UNION ALL
      SELECT 'PRE' fase, 'HEREDA_DEP' paso, 'INFO' nivel, 'Dependencias que una solicitud anterior interrumpida dejo deshabilitadas: se heredan para rehabilitarlas al final.' descripcion FROM dual UNION ALL
      SELECT 'PRE' fase, 'SKIP_DEP_YA_DESHAB' paso, 'INFO' nivel, 'Dependencia ya deshabilitada antes de empezar: no se toca y no se rehabilita.' descripcion FROM dual UNION ALL
      SELECT 'PRE' fase, 'SKIP_DEP_NOT_FOUND' paso, 'WARN' nivel, 'La dependencia del catalogo ya no existe en el diccionario; se omite. Revisar si el catalogo esta desactualizado.' descripcion FROM dual UNION ALL
      SELECT 'PRE' fase, 'FIN' paso, 'INFO' nivel, 'Terminada la desactivacion de dependencias.' descripcion FROM dual UNION ALL
      SELECT 'PROPAGACION' fase, 'PROPAGA_START' paso, 'INFO' nivel, 'Comienza el recalculo de dominios referenciales (FK) antes de enmascarar.' descripcion FROM dual UNION ALL
      SELECT 'PROPAGACION' fase, 'PROPAGA_END' paso, 'INFO' nivel, 'Dominios FK propagados con exito.' descripcion FROM dual UNION ALL
      SELECT 'PROPAGACION' fase, 'PROPAGA_ERR' paso, 'ERROR' nivel, 'Fallo propagando dominios FK; el enmascarado se aborta (sin propagacion valida no hay integridad).' descripcion FROM dual UNION ALL
      SELECT 'PROPAGACION' fase, 'RI_REINCLUYE' paso, 'INFO' nivel, 'El descubrimiento re-incluyo una columna (Y) por integridad referencial de su dominio.' descripcion FROM dual UNION ALL
      SELECT 'ENMASCARAMIENTO' fase, 'ALCANCE_ERR' paso, 'WARN' nivel, 'No se pudo registrar el alcance (ID, SET o COMPLETO) en TDM_MASK_SOLICITUD; la corrida continua.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'PEPPER_START' paso, 'INFO' nivel, 'Comienza la generacion del pepper efimero de la campana.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'PEPPER_END' paso, 'INFO' nivel, 'Pepper efimero listo; los workers paralelos leen la misma clave.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'PEPPER_ERR' paso, 'ERROR' nivel, 'Fallo preparando el pepper; el enmascarado se aborta (sin pepper no se enmascara).' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'PREFLIGHT_OK' paso, 'INFO' nivel, 'Pre-flight de tareas DBMS_PARALLEL_EXECUTE: ninguna huerfana bloquea.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'PREFLIGHT_INFO' paso, 'INFO' nivel, 'Tarea de otra corrida o fuera de alcance: se informa pero no bloquea.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'PREFLIGHT_ORFANA' paso, 'WARN' nivel, 'Tarea huerfana de una columna a enmascarar: bloquea hasta decidir (reanudar o descartar).' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'PREFLIGHT_ABORT' paso, 'ERROR' nivel, 'Pre-flight aborta la corrida (ORA-20331) por tareas huerfanas; no se toco ningun dato.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'COL_INICIO' paso, 'INFO' nivel, 'Comienza el enmascarado de una columna (identificador y ruta elegidos).' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'EXCEPTION_FORCE' paso, 'INFO' nivel, 'La columna usa el identificador forzado de TDM_EXCEPCION_COL.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'SKIP_EXCLUDE' paso, 'INFO' nivel, 'Columna omitida porque TDM_EXCEPCION_COL la excluye.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'SKIP_TABLE' paso, 'INFO' nivel, 'Tabla omitida: todas sus columnas estan excluidas.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'SKIP_AUTO_LEN' paso, 'WARN' nivel, 'Columna sensible SIN enmascarar: su longitud es menor que el minimo del identificador.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'CHECKPOINT_PERDIDO' paso, 'ERROR' nivel, 'La columna se enmascaro pero su punto de control APPLY_COL no quedo registrado: NO reanudar sin revisar (FF1 no es idempotente).' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'UNICIDAD_RIESGO' paso, 'WARN' nivel, 'Columna con indice unico enmascarada con una funcion no inyectiva (nombre, direccion, telefono, email, observacion): puede dar ORA-00001 y auto-excluirse.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'SKIP_ORA00001' paso, 'WARN' nivel, 'Columna auto-excluida tras colision de unicidad (ORA-00001): queda SIN enmascarar y bloquea FINALIZADO.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'NO_ENMASCARADA' paso, 'WARN' nivel, 'Resumen de cierre: columna que queda SIN enmascarar por cualquier motivo (omision por longitud, auto-exclusion ORA-00001/12899/06502 o auto-exclusion heredada de una corrida anterior). No detiene el proceso.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'SKIP_ORA12899' paso, 'WARN' nivel, 'Columna auto-excluida tras ORA-12899 (valor mayor que la columna).' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'SKIP_ORA06502' paso, 'WARN' nivel, 'Columna auto-excluida tras ORA-06502 sin fallback posible.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'APPLY_COL' paso, 'INFO' nivel, 'Columna ENMASCARADA y confirmada: una linea por columna con filas, ruta (UPDATE o CHUNKS) y duracion. PUNTO DE CONTROL de la reanudacion: una columna con APPLY_COL no se vuelve a enmascarar.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'APPLY_COL_SAFE_FALLBACK' paso, 'WARN' nivel, 'Columna enmascarada con la expresion de reserva tras ORA-06502; tambien es punto de control de reanudacion.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'TAREA_DESCARTADA' paso, 'WARN' nivel, 'Una tarea interrumpida se descarto con proc_dm_gestiona_tareas DESCARTAR.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'NOOP' paso, 'INFO' nivel, 'No habia columnas a enmascarar en esta corrida.' descripcion FROM dual UNION ALL
      SELECT 'MASK' fase, 'RESUMEN' paso, 'INFO' nivel, 'Resumen del bucle de columnas: procesadas, fallidas, tablas y filas afectadas.' descripcion FROM dual UNION ALL
      SELECT 'POST_SYNC' fase, 'SYNC' paso, 'INFO' nivel, 'Sincronizacion de una columna origen hacia su destino dependiente (filas).' descripcion FROM dual UNION ALL
      SELECT 'POST_SYNC' fase, 'SYNC_OK' paso, 'INFO' nivel, 'Verificacion post-sincronizacion: sin diferencias.' descripcion FROM dual UNION ALL
      SELECT 'POST_SYNC' fase, 'SYNC_MISMATCH' paso, 'WARN' nivel, 'Verificacion post-sincronizacion: quedan diferencias entre origen y destino.' descripcion FROM dual UNION ALL
      SELECT 'POST_SYNC' fase, 'WARN_SYNC' paso, 'WARN' nivel, 'Fallo sincronizando un par origen-destino; se continua.' descripcion FROM dual UNION ALL
      SELECT 'POST_SYNC' fase, 'WARN_SYNC_LEN' paso, 'WARN' nivel, 'Par origen-destino omitido por longitud insuficiente del destino.' descripcion FROM dual UNION ALL
      SELECT 'POST_SYNC' fase, 'WARN_SYNC_CHECK' paso, 'WARN' nivel, 'Fallo al verificar un par sincronizado.' descripcion FROM dual UNION ALL
      SELECT 'POST' fase, 'INICIO' paso, 'INFO' nivel, 'Comienza la rehabilitacion de dependencias.' descripcion FROM dual UNION ALL
      SELECT 'POST' fase, 'SKIP_POST_POLICY' paso, 'INFO' nivel, 'Dependencia NO rehabilitada porque su accion POST (REVISAR/SIN_ACCION) exige revision manual.' descripcion FROM dual UNION ALL
      SELECT 'POST' fase, 'POST_CHECK_INVALID' paso, 'WARN' nivel, 'Tras rehabilitar quedan objetos INVALID nuevos o constraints no ENABLED.' descripcion FROM dual UNION ALL
      SELECT 'POST' fase, 'FIN' paso, 'INFO' nivel, 'Terminada la rehabilitacion de dependencias.' descripcion FROM dual UNION ALL
      SELECT 'FIN' fase, 'OK' paso, 'INFO' nivel, 'Enmascaramiento finalizado sin errores.' descripcion FROM dual UNION ALL
      SELECT 'FIN' fase, 'ERROR' paso, 'ERROR' nivel, 'Enmascaramiento terminado con errores (la corrida no queda FINALIZADA).' descripcion FROM dual UNION ALL
      SELECT 'FIN' fase, 'PII_SIN_ENMASCARAR' paso, 'ERROR' nivel, 'Hay columnas sensibles auto-excluidas: no se permite FINALIZADO.' descripcion FROM dual UNION ALL
      SELECT 'FIN' fase, 'ESTADO_FINAL_WARN' paso, 'WARN' nivel, 'El manejador de errores no pudo registrar el estado final de la solicitud o de la ejecucion; revisar que no quede en EJECUTANDO.' descripcion FROM dual UNION ALL
      SELECT 'FIN' fase, 'PEPPER_PURGE_WARN' paso, 'WARN' nivel, 'Corrida FINALIZADA pero no se pudo autopurgar el pepper; purgar a mano.' descripcion FROM dual UNION ALL
      SELECT 'ERROR' fase, 'REGISTRADO' paso, 'ERROR' nivel, 'Un error se registro en TDM_EJECUCION_ERROR; el detalle empieza por error_id=N para ubicarlo.' descripcion FROM dual UNION ALL
      SELECT 'CONTROL' fase, 'UPD_EJEC_BLOQUEADO' paso, 'WARN' nivel, 'Un ping de progreso no se aplico: la ejecucion ya estaba cerrada (no se resucita).' descripcion FROM dual UNION ALL
      SELECT 'CONTROL' fase, 'UPD_EJEC_FALLO' paso, 'ERROR' nivel, 'Fallo actualizando el progreso en TDM_EJECUCION.' descripcion FROM dual UNION ALL
      SELECT 'CONTROL' fase, 'CLOSE_SOL_OPEN_FALLO' paso, 'ERROR' nivel, 'Fallo cerrando solicitudes abiertas de una corrida anterior.' descripcion FROM dual UNION ALL
      SELECT 'DESCUBRIMIENTO' fase, 'EXCEPCION_EXCLUDE' paso, 'INFO' nivel, 'Columna descartada en el descubrimiento por una excepcion EXCLUDE de TDM_EXCEPCION_COL (una fila por columna).' descripcion FROM dual UNION ALL
      SELECT 'DESCUBRIMIENTO' fase, 'TABLAS_OMITIDAS' paso, 'INFO' nivel, 'Tablas sin filas que no se analizaron (solo aparece si hay alguna).' descripcion FROM dual UNION ALL
      SELECT 'DESCUBRIMIENTO' fase, 'TABLAS_CON_ERROR' paso, 'WARN' nivel, 'Tablas con columnas que no se pudieron evaluar: no se retira su catalogo FINAL y se reintentan.' descripcion FROM dual UNION ALL
      SELECT 'DESCUBRIMIENTO' fase, 'FINAL_OBSOLETAS' paso, 'INFO' nivel, 'Se retiraron de TDM_COLUMNA_FINAL columnas que ya no cumplen el descubrimiento o ya no existen.' descripcion FROM dual UNION ALL
      SELECT 'DESCUBRIMIENTO' fase, 'FINAL_OBSOLETAS_ERR' paso, 'WARN' nivel, 'Fallo retirando columnas obsoletas del catalogo final.' descripcion FROM dual UNION ALL
      SELECT 'DESCUBRIMIENTO' fase, 'PROPAGA_DOMINIOS_ERR' paso, 'WARN' nivel, 'Fallo propagando dominios FK durante la sincronizacion del catalogo.' descripcion FROM dual UNION ALL
      SELECT 'DESCUBRIMIENTO' fase, 'RESUMEN' paso, 'INFO' nivel, 'Resumen unico del descubrimiento: tablas con columnas evaluadas, columnas evaluadas y columnas a enmascarar (Y).' descripcion FROM dual
) s
ON (p.fase = s.fase AND p.paso = s.paso)
WHEN MATCHED THEN UPDATE SET p.descripcion = s.descripcion
WHEN NOT MATCHED THEN INSERT (fase, paso, nivel, descripcion)
     VALUES (s.fase, s.paso, s.nivel, s.descripcion);

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
    alcance_tipo         VARCHAR2(10),
    CONSTRAINT pk_tdm_mask_solicitud PRIMARY KEY (solicitud_id),
    CONSTRAINT fk_tdm_mask_sol_ejec FOREIGN KEY (ejecucion_id)
        REFERENCES tdm_ejecucion (ejecucion_id),
    CONSTRAINT ck_tdm_mask_sol_forzar CHECK (forzar_reproceso IN ('Y','N')),
    CONSTRAINT ck_tdm_mask_sol_alcance CHECK (alcance_tipo IN ('ID','SET','COMPLETO')),
    CONSTRAINT ck_tdm_mask_sol_estado CHECK (
        estado IN ('PENDIENTE','EN_PROCESO','FINALIZADO','ERROR','CANCELADO','REPROCESANDO')
    )
);

CREATE INDEX idm_mask_sol_01 ON tdm_mask_solicitud (ejecucion_id, estado);

CREATE INDEX idm_mask_sol_02 ON tdm_mask_solicitud (ora_esquema, fecha_inicio);

-- Se vincula tdm_ejecucion_error con tdm_mask_solicitud aqui para respetar el orden de creacion.
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

COMMENT ON COLUMN tdm_mask_solicitud.alcance_tipo IS 'Modo de alcance de la corrida: ID (por identificador), SET (grupo de tablas) o COMPLETO (esquema entero). Independiente de forzar_reproceso (default/Y).';


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

COMMENT ON TABLE tdm_mask_trace IS 'PREGUNTA: que paso, en que orden y cuanto tardo. Linea de tiempo de una corrida: una fila por paso del catalogo TDM_MASK_TRACE_EVENTO. El enmascaramiento deja todos sus pasos; el descubrimiento deja solo un resumen y, aparte, tablas omitidas, avisos o errores. Cada error queda ubicado aqui y su detalle completo esta en TDM_EJECUCION_ERROR. No guarda valores de datos.';

COMMENT ON COLUMN tdm_mask_trace.trace_id IS 'Identificador único del evento de trace.';

COMMENT ON COLUMN tdm_mask_trace.solicitud_id IS 'Referencia a la solicitud de enmascaramiento.';

COMMENT ON COLUMN tdm_mask_trace.ejecucion_id IS 'Referencia a la ejecución maestra.';

COMMENT ON COLUMN tdm_mask_trace.nivel IS 'Nivel del evento (INFO, WARN, ERROR), tomado del catalogo TDM_MASK_TRACE_EVENTO.';

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
-- 5) REGLAS ESPECIALES DE TRATAMIENTO (mecanismo generico del motor)
--------------------------------------------------------------------------------
-- Tratamiento especial por columna (mantener 1er/ultimo caracter, IBAN continuo, documento
-- segun tipo). La puebla el DBA con datos propios; esta capa no lleva literales de ningun cliente.
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
-- 6) RELACIONES DE SINCRONIZACION POST-MASKING (mecanismo generico del motor)
--------------------------------------------------------------------------------
-- Coherencia entre tablas relacionadas por un join que no es FK real. La puebla el DBA con datos
-- propios; esta capa no lleva literales de ningun cliente.
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
