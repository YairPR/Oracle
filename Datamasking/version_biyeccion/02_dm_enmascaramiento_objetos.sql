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

ALTER SESSION SET CURRENT_SCHEMA = ASTSYSADMIN;

--------------------------------------------------------------------------------
-- 0) TABLA DE SEGURIDAD (PEPPER / SEMILLA)
--------------------------------------------------------------------------------
CREATE TABLE tdm_secreto (
    clave  VARCHAR2(30)  NOT NULL,
    valor  VARCHAR2(128) NOT NULL,
    CONSTRAINT pk_tdm_secreto PRIMARY KEY (clave)
) tablespace ASTSYSADMIN;

COMMENT ON TABLE tdm_secreto IS 'Semillas y secretos de enmascaramiento.';
COMMENT ON COLUMN tdm_secreto.clave IS 'Identificador de la clave secreta.';
COMMENT ON COLUMN tdm_secreto.valor IS 'Valor de la clave secreta (Raw Hex o texto largo).';

--------------------------------------------------------------------------------
-- 1) SOLICITUD DE ENMASCARAMIENTO
--------------------------------------------------------------------------------
CREATE TABLE tdm_mask_solicitud (
    solicitud_id         NUMBER         NOT NULL,
    ejecucion_id         NUMBER         NOT NULL,
    esquema_objetivo     VARCHAR2(128)  NOT NULL,
    estado               VARCHAR2(30)   NOT NULL,
    fase_actual          VARCHAR2(30),
    checkpoint_paso      VARCHAR2(100),
    reintento_nro        NUMBER         DEFAULT 0,
    forzar_reproceso     CHAR(1)        DEFAULT 'N',
    cancel_requested     CHAR(1)        DEFAULT 'N',
    fecha_inicio         TIMESTAMP      DEFAULT SYSTIMESTAMP,
    fecha_fin            TIMESTAMP,
    fecha_cancelacion    TIMESTAMP,
    heartbeat_ts         TIMESTAMP,
    filas_procesadas     NUMBER         DEFAULT 0,
    filas_error          NUMBER         DEFAULT 0,
    tablas_procesadas    NUMBER         DEFAULT 0,
    columnas_procesadas  NUMBER         DEFAULT 0,
    ultima_tabla         VARCHAR2(128),
    ultima_columna       VARCHAR2(128),
    sesion_sid           NUMBER,
    sesion_serial        NUMBER,
    detalle              VARCHAR2(4000),
    CONSTRAINT pk_tdm_mask_solicitud PRIMARY KEY (solicitud_id),
    CONSTRAINT fk_tdm_mask_sol_ejec FOREIGN KEY (ejecucion_id)
        REFERENCES tdm_ejecucion (ejecucion_id),
    CONSTRAINT ck_tdm_mask_sol_cancel CHECK (cancel_requested IN ('Y','N')),
    CONSTRAINT ck_tdm_mask_sol_forzar CHECK (forzar_reproceso IN ('Y','N')),
    CONSTRAINT ck_tdm_mask_sol_estado CHECK (
        estado IN ('PENDIENTE','EN_PROCESO','FINALIZADO','ERROR','CANCELADO','REPROCESANDO')
    )
) TABLESPACE ASTSYSADMIN;

CREATE INDEX idm_mask_sol_01 ON tdm_mask_solicitud (ejecucion_id, estado) TABLESPACE ASTSYSADMIN ONLINE;

CREATE INDEX idm_mask_sol_02 ON tdm_mask_solicitud (esquema_objetivo, fecha_inicio) TABLESPACE ASTSYSADMIN ONLINE;

-- B.1: Vincular tdm_ejecucion_error con tdm_mask_solicitud de forma diferida para respetar el orden de creación
ALTER TABLE tdm_ejecucion_error 
    ADD CONSTRAINT fk_tdm_ejec_err_sol FOREIGN KEY (solicitud_id) 
    REFERENCES tdm_mask_solicitud (solicitud_id);

COMMENT ON TABLE tdm_mask_solicitud IS 'Solicitud o subproceso de enmascaramiento asociado a una ejecución.';

COMMENT ON COLUMN tdm_mask_solicitud.solicitud_id IS 'Identificador único de la solicitud de enmascaramiento.';

COMMENT ON COLUMN tdm_mask_solicitud.ejecucion_id IS 'Referencia a la ejecución maestra registrada en tdm_ejecucion.';

COMMENT ON COLUMN tdm_mask_solicitud.esquema_objetivo IS 'Esquema Oracle objetivo del enmascaramiento.';

COMMENT ON COLUMN tdm_mask_solicitud.estado IS 'Estado del subproceso de enmascaramiento.';

COMMENT ON COLUMN tdm_mask_solicitud.fase_actual IS 'Fase actual del flujo de masking.';

COMMENT ON COLUMN tdm_mask_solicitud.checkpoint_paso IS 'Punto de control del proceso.';

COMMENT ON COLUMN tdm_mask_solicitud.reintento_nro IS 'Número de reintento acumulado.';

COMMENT ON COLUMN tdm_mask_solicitud.forzar_reproceso IS 'Indica si la solicitud fue lanzada en modo reproceso forzado.';

COMMENT ON COLUMN tdm_mask_solicitud.cancel_requested IS 'Marca de solicitud de cancelación.';

COMMENT ON COLUMN tdm_mask_solicitud.fecha_cancelacion IS 'Fecha en que se solicitó o consolidó la cancelación.';

COMMENT ON COLUMN tdm_mask_solicitud.heartbeat_ts IS 'Marca de vida del proceso.';

COMMENT ON COLUMN tdm_mask_solicitud.filas_procesadas IS 'Contador acumulado de filas tratadas.';

COMMENT ON COLUMN tdm_mask_solicitud.filas_error IS 'Contador acumulado de errores.';

COMMENT ON COLUMN tdm_mask_solicitud.tablas_procesadas IS 'Contador acumulado de tablas tratadas.';

COMMENT ON COLUMN tdm_mask_solicitud.columnas_procesadas IS 'Contador acumulado de columnas evaluadas.';

COMMENT ON COLUMN tdm_mask_solicitud.ultima_tabla IS 'Última tabla procesada.';

COMMENT ON COLUMN tdm_mask_solicitud.ultima_columna IS 'Última columna evaluada o tratada.';

COMMENT ON COLUMN tdm_mask_solicitud.sesion_sid IS 'SID Oracle asociado al proceso, si aplica.';

COMMENT ON COLUMN tdm_mask_solicitud.sesion_serial IS 'SERIAL# Oracle asociado al proceso, si aplica.';

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
    fecha_evento         TIMESTAMP      DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_tdm_mask_trace PRIMARY KEY (trace_id),
    CONSTRAINT fk_tdm_mask_trace_sol FOREIGN KEY (solicitud_id)
        REFERENCES tdm_mask_solicitud (solicitud_id),
    CONSTRAINT fk_tdm_mask_trace_ejec FOREIGN KEY (ejecucion_id)
        REFERENCES tdm_ejecucion (ejecucion_id),
    CONSTRAINT ck_tdm_mask_trace_nivel CHECK (nivel IN ('INFO','WARN','ERROR'))
) TABLESPACE ASTSYSADMIN;

CREATE INDEX idm_mask_trace_01  ON tdm_mask_trace (ejecucion_id, fase, paso, fecha_evento)  TABLESPACE ASTSYSADMIN ONLINE;

CREATE INDEX idm_mask_trace_02  ON tdm_mask_trace (solicitud_id, fase, paso, fecha_evento)  TABLESPACE ASTSYSADMIN ONLINE;

COMMENT ON TABLE tdm_mask_trace IS 'Trazabilidad detallada del proceso de enmascaramiento.';

COMMENT ON COLUMN tdm_mask_trace.trace_id IS 'Identificador único del evento de trace.';

COMMENT ON COLUMN tdm_mask_trace.solicitud_id IS 'Referencia a la solicitud de enmascaramiento.';

COMMENT ON COLUMN tdm_mask_trace.ejecucion_id IS 'Referencia a la ejecución maestra.';

COMMENT ON COLUMN tdm_mask_trace.nivel IS 'Nivel del evento: INFO, WARN o ERROR.';

COMMENT ON COLUMN tdm_mask_trace.fase IS 'Fase funcional del proceso de masking.';

COMMENT ON COLUMN tdm_mask_trace.paso IS 'Paso concreto ejecutado.';

COMMENT ON COLUMN tdm_mask_trace.detalle IS 'Detalle ampliado del evento de trazabilidad.';

COMMENT ON COLUMN tdm_mask_trace.fecha_evento IS 'Fecha y hora del evento.';

--------------------------------------------------------------------------------
-- 3) ESTADO PRE/POST DE DEPENDENCIAS
--------------------------------------------------------------------------------
CREATE TABLE tdm_mask_dep_estado (
    solicitud_id         NUMBER         NOT NULL,
    tipo_objeto          VARCHAR2(20)   NOT NULL,
    owner_name           VARCHAR2(128)  NOT NULL,
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
        solicitud_id, tipo_objeto, owner_name, table_name, objeto_name
    ),
    CONSTRAINT fk_tdm_mask_dep_sol FOREIGN KEY (solicitud_id)
        REFERENCES tdm_mask_solicitud (solicitud_id),
    CONSTRAINT ck_tdm_mask_dep_tipo CHECK (tipo_objeto IN ('CONSTRAINT','TRIGGER')),
    CONSTRAINT ck_tdm_mask_dep_desh CHECK (deshabilitado_ok IN ('Y','N')),
    CONSTRAINT ck_tdm_mask_dep_hab CHECK (habilitado_ok IN ('Y','N'))
) TABLESPACE ASTSYSADMIN;

CREATE INDEX idm_mask_dep_01 ON tdm_mask_dep_estado (solicitud_id, tipo_objeto, owner_name)  TABLESPACE ASTSYSADMIN ONLINE;

COMMENT ON TABLE tdm_mask_dep_estado IS 'Estado previo y posterior de dependencias técnicas deshabilitadas/habilitadas durante el masking.';

COMMENT ON COLUMN tdm_mask_dep_estado.solicitud_id IS 'Referencia a la solicitud de enmascaramiento.';

COMMENT ON COLUMN tdm_mask_dep_estado.tipo_objeto IS 'Tipo de objeto gestionado en el pre/post: CONSTRAINT o TRIGGER.';

COMMENT ON COLUMN tdm_mask_dep_estado.owner_name IS 'Owner del objeto dependiente.';

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
-- 5) REGLAS ESPECIALES DE TRATAMIENTO SIGAD
--------------------------------------------------------------------------------
CREATE TABLE tdm_mask_regla_esp (
    regla_id              NUMBER         NOT NULL,
    esquema_objetivo      VARCHAR2(128)  NOT NULL,
    owner_name            VARCHAR2(128)  NOT NULL,
    table_name            VARCHAR2(128)  NOT NULL,
    column_name           VARCHAR2(128)  NOT NULL,
    tipo_regla            VARCHAR2(50)   NOT NULL,
    valor_regla           VARCHAR2(4000),
    activa                CHAR(1)        DEFAULT 'Y',
    observacion           VARCHAR2(4000),
    CONSTRAINT pk_tdm_mask_regla_esp PRIMARY KEY (regla_id),
    CONSTRAINT ck_tdm_mask_regla_act CHECK (activa IN ('Y','N'))
) TABLESPACE ASTSYSADMIN;

CREATE INDEX idm_mask_regla_01 ON tdm_mask_regla_esp (esquema_objetivo, owner_name, table_name, column_name, activa) TABLESPACE ASTSYSADMIN ONLINE;

COMMENT ON TABLE tdm_mask_regla_esp IS 'Reglas especiales de tratamiento por tabla/columna.';

COMMENT ON COLUMN tdm_mask_regla_esp.tipo_regla IS 'Tipo de regla especial: DOC_SEGUN_TIPO, DOC_UNIFICADO_MANTENER_1_Y_ULTIMO, IBAN_ES_CONTINUO, etc.';

COMMENT ON COLUMN tdm_mask_regla_esp.valor_regla IS 'Valor libre o metadata de la regla especial.';

COMMENT ON COLUMN tdm_mask_regla_esp.observacion IS 'Observación funcional o técnica asociada a la regla.';

--------------------------------------------------------------------------------
-- 6) RELACIONES DE SINCRONIZACION POST-MASKING SIGAD
--------------------------------------------------------------------------------
CREATE TABLE tdm_mask_relacion_sync (
    sync_id               NUMBER         NOT NULL,
    esquema_objetivo      VARCHAR2(128)  NOT NULL,
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
) TABLESPACE ASTSYSADMIN;

CREATE INDEX idm_mask_sync_01 ON tdm_mask_relacion_sync (esquema_objetivo, tabla_origen, tabla_destino, activa) TABLESPACE ASTSYSADMIN ONLINE;

COMMENT ON TABLE tdm_mask_relacion_sync IS 'Relaciones de sincronización/coherencia entre tablas tras el masking.';

COMMENT ON COLUMN tdm_mask_relacion_sync.tabla_origen IS 'Tabla desde la cual se copiará el valor coherente.';

COMMENT ON COLUMN tdm_mask_relacion_sync.tabla_destino IS 'Tabla hacia la cual se propagará el valor coherente.';

COMMENT ON COLUMN tdm_mask_relacion_sync.columna_join_origen IS 'Columna de unión en la tabla origen.';

COMMENT ON COLUMN tdm_mask_relacion_sync.columna_join_destino IS 'Columna de unión en la tabla destino.';

COMMENT ON COLUMN tdm_mask_relacion_sync.columna_origen IS 'Columna origen cuyo valor ya enmascarado se propagará.';

COMMENT ON COLUMN tdm_mask_relacion_sync.columna_destino IS 'Columna destino que se sincronizará.';

COMMENT ON COLUMN tdm_mask_relacion_sync.prioridad IS 'Prioridad de ejecución para la sincronización.';

COMMENT ON COLUMN tdm_mask_relacion_sync.observacion IS 'Observación funcional o técnica de la sincronización.';




/*
--------------------------------------------------------------------------------
--  DATOS SEMILLA PARA SIGAD_ACAD_OWN
--    Comentar si no aplica
--------------------------------------------------------------------------------

-- Documento según tipo en tablas con NDOCUMENTO + IDTIPODOCUMENTO
INSERT INTO tdm_mask_regla_esp (
    regla_id, esquema_objetivo, owner_name, table_name, column_name,
    tipo_regla, valor_regla, activa, observacion
) VALUES (
    seq_dm_mask_regla_esp.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO',
    'NDOCUMENTO',
    'DOC_SEGUN_TIPO',
    'IDTIPODOCUMENTO',
    'Y',
    'NIF/NIE/PASAPORTE según IDTIPODOCUMENTO'
);

-- Documento unificado: mantener primer y último carácter
INSERT INTO tdm_mask_regla_esp (
    regla_id, esquema_objetivo, owner_name, table_name, column_name,
    tipo_regla, valor_regla, activa, observacion
) VALUES (
    seq_dm_mask_regla_esp.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SIGAD_ACAD_OWN',
    'TSKPCRUNIFICARALUMNOS',
    'NDOCUMENTO',
    'DOC_UNIFICADO_MANTENER_1_Y_ULTIMO',
    NULL,
    'Y',
    'Mantener primer y último carácter del documento'
);

INSERT INTO tdm_mask_regla_esp (
    regla_id, esquema_objetivo, owner_name, table_name, column_name,
    tipo_regla, valor_regla, activa, observacion
) VALUES (
    seq_dm_mask_regla_esp.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SIGAD_ACAD_OWN',
    'TSKPCRUNIFICARFAMILIARES',
    'NDOCUMENTO',
    'DOC_UNIFICADO_MANTENER_1_Y_ULTIMO',
    NULL,
    'Y',
    'Mantener primer y último carácter del documento'
);

-- IBAN continuo ES + 22 dígitos con control válido
INSERT INTO tdm_mask_regla_esp (
    regla_id, esquema_objetivo, owner_name, table_name, column_name,
    tipo_regla, valor_regla, activa, observacion
) VALUES (
    seq_dm_mask_regla_esp.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SIGAD_ACAD_OWN',
    'CENCUENTABANCO',
    'NUMEROCUENTA',
    'IBAN_ES_CONTINUO',
    NULL,
    'Y',
    'IBAN continuo de 24 caracteres'
);

-- Coherencia post-masking: email usuario -> profesor
INSERT INTO tdm_mask_relacion_sync (
    sync_id, esquema_objetivo,
    tabla_origen, columna_join_origen, tabla_destino, columna_join_destino,
    columna_origen, columna_destino, activa, prioridad, observacion
) VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'PERPROFESOR', 'IDUSUARIO',
    'EMAIL', 'EMAIL',
    'Y', 10,
    'Coherencia email usuario-profesor'
);

-- Coherencia nombre/apellidos/documento usuario -> profesor
INSERT INTO tdm_mask_relacion_sync VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'PERPROFESOR', 'IDUSUARIO',
    'NOMBRE', 'NOMBRE',
    'Y', 20,
    'Coherencia nombre usuario-profesor'
);

INSERT INTO tdm_mask_relacion_sync VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'PERPROFESOR', 'IDUSUARIO',
    'APELLIDO1', 'APELLIDO1',
    'Y', 21,
    'Coherencia apellido1 usuario-profesor'
);

INSERT INTO tdm_mask_relacion_sync VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'PERPROFESOR', 'IDUSUARIO',
    'APELLIDO2', 'APELLIDO2',
    'Y', 22,
    'Coherencia apellido2 usuario-profesor'
);

INSERT INTO tdm_mask_relacion_sync VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'PERPROFESOR', 'IDUSUARIO',
    'NDOCUMENTO', 'NDOCUMENTO',
    'Y', 23,
    'Coherencia documento usuario-profesor'
);

-- Coherencia usuario -> alumno
INSERT INTO tdm_mask_relacion_sync VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'CENALUMNO', 'IDUSUARIO',
    'NOMBRE', 'NOMBRE',
    'Y', 30,
    'Coherencia nombre usuario-alumno'
);

INSERT INTO tdm_mask_relacion_sync VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'CENALUMNO', 'IDUSUARIO',
    'APELLIDO1', 'APELLIDO1',
    'Y', 31,
    'Coherencia apellido1 usuario-alumno'
);

INSERT INTO tdm_mask_relacion_sync VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'CENALUMNO', 'IDUSUARIO',
    'APELLIDO2', 'APELLIDO2',
    'Y', 32,
    'Coherencia apellido2 usuario-alumno'
);

INSERT INTO tdm_mask_relacion_sync VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'CENALUMNO', 'IDUSUARIO',
    'NDOCUMENTO', 'NDOCUMENTO',
    'Y', 33,
    'Coherencia documento usuario-alumno'
);

-- Coherencia usuario -> familiar
INSERT INTO tdm_mask_relacion_sync VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'CENFAMILIAR', 'IDUSUARIO',
    'NOMBRE', 'NOMBRE',
    'Y', 40,
    'Coherencia nombre usuario-familiar'
);

INSERT INTO tdm_mask_relacion_sync VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'CENFAMILIAR', 'IDUSUARIO',
    'APELLIDO1', 'APELLIDO1',
    'Y', 41,
    'Coherencia apellido1 usuario-familiar'
);

INSERT INTO tdm_mask_relacion_sync VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'CENFAMILIAR', 'IDUSUARIO',
    'APELLIDO2', 'APELLIDO2',
    'Y', 42,
    'Coherencia apellido2 usuario-familiar'
);

INSERT INTO tdm_mask_relacion_sync VALUES (
    seq_dm_mask_relacion_sync.NEXTVAL,
    'SIGAD_ACAD_OWN',
    'SEGUSUARIO', 'IDUSUARIO',
    'CENFAMILIAR', 'IDUSUARIO',
    'NDOCUMENTO', 'NDOCUMENTO',
    'Y', 43,
    'Coherencia documento usuario-familiar'
);


COMMIT;


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
--------------------------------------------------------------------------------
CREATE TABLE tdm_mask_cache (
    tipo         VARCHAR2(30)   NOT NULL,
    original     VARCHAR2(4000) NOT NULL,
    enmascarado  VARCHAR2(4000) NOT NULL,
    CONSTRAINT pk_tdm_mask_cache PRIMARY KEY (tipo, original)
) TABLESPACE ASTSYSADMIN;

CREATE INDEX idm_mask_cache_01
    ON tdm_mask_cache (tipo, enmascarado)
    TABLESPACE ASTSYSADMIN ONLINE;

COMMENT ON TABLE tdm_mask_cache IS
'Cache determinista opcional de valores originales y enmascarados. No es obligatoria para la determinística del proceso.';

COMMENT ON COLUMN tdm_mask_cache.tipo IS
'Tipo lógico de dato enmascarado: EMAIL, NOMBRE, NIF, TELEFONO, etc.';

COMMENT ON COLUMN tdm_mask_cache.original IS
'Valor original detectado antes del enmascaramiento.';

COMMENT ON COLUMN tdm_mask_cache.enmascarado IS
'Valor enmascarado final utilizado para consistencia adicional, si se decide usar cache.';

*/