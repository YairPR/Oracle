--------------------------------------------------------------------------------
-- DATAMASKING DESCUBRIMIENTO
-- Tablas, secuencias, índices, checks y comentarios
-- Estandard:
--   Tablas     : tdm_*
--   Secuencias : seq_dm_*
--   Índices    : idm_*
--   PK         : pk_tdm_*
--   FK         : fk_tdm_*
--   UK         : uk_tdm_*
--   CK         : ck_tdm_*
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 1) TABLA MAESTRA DE EJECUCIONES
--    Cabecera única para descubrimiento y enmascaramiento.
--------------------------------------------------------------------------------


CREATE TABLE tdm_ejecucion (
    ejecucion_id         NUMBER         NOT NULL,
    esquema_objetivo     VARCHAR2(128)  NOT NULL,
    ejecutado_por        VARCHAR2(128)  NOT NULL,
    fase_proceso         VARCHAR2(30)   NOT NULL,
    estado               VARCHAR2(20)   NOT NULL,
    fecha_inicio         TIMESTAMP      NOT NULL,
    fecha_fin            TIMESTAMP,
    progreso_pct         NUMBER(5,2)    DEFAULT 0,
    tablas_total         NUMBER         DEFAULT 0,
    tablas_proc          NUMBER         DEFAULT 0,
    columnas_total       NUMBER         DEFAULT 0,
    columnas_proc        NUMBER         DEFAULT 0,
    ultimo_objeto        VARCHAR2(400),
    ultimo_paso          VARCHAR2(200),
	detalle              VARCHAR2(4000),
    error_count          NUMBER         DEFAULT 0,
    forzar_full          CHAR(1)        DEFAULT 'N',
	cancel_requested     CHAR(1)        DEFAULT 'N',
    sesion_audsid        NUMBER,
    sesion_sid           NUMBER,
    sesion_serial        NUMBER,
    sesion_inst_id       NUMBER,
    heartbeat_ts         TIMESTAMP,
    CONSTRAINT pk_tdm_ejecucion PRIMARY KEY (ejecucion_id),
    CONSTRAINT ck_tdm_ejec_forzar CHECK (forzar_full IN ('Y','N')),
    CONSTRAINT ck_tdm_ejec_fase CHECK (fase_proceso IN ('DESCUBRIMIENTO','ENMASCARAMIENTO')),
    CONSTRAINT ck_tdm_ejec_estado CHECK ( estado IN ('PENDIENTE','EJECUTANDO','PAUSADO','ABORTADA','FINALIZADO','CANCELADO','ERROR')),
	CONSTRAINT ck_tdm_ejec_cancel CHECK (cancel_requested IN ('Y','N'))
    ) tablespace ASTSYSADMIN ;

CREATE INDEX idm_ejecucion_01 ON tdm_ejecucion (esquema_objetivo, fecha_inicio) tablespace ASTSYSADMIN online;
CREATE INDEX idm_ejecucion_02 ON tdm_ejecucion (fase_proceso, estado) tablespace ASTSYSADMIN online;

COMMENT ON TABLE tdm_ejecucion IS 'Cabecera de ejecución de los procesos de descubrimiento y enmascaramiento.';
COMMENT ON COLUMN tdm_ejecucion.ejecucion_id IS 'Identificador único de la ejecución.';
COMMENT ON COLUMN tdm_ejecucion.esquema_objetivo IS 'Esquema objetivo del proceso.';
COMMENT ON COLUMN tdm_ejecucion.ejecutado_por IS 'Usuario bbdd que lanzó la ejecución.';
COMMENT ON COLUMN tdm_ejecucion.fase_proceso IS 'Fase del motor: descubrimiento o enmascaramiento.';
COMMENT ON COLUMN tdm_ejecucion.estado IS 'Estado de la ejecución.';
COMMENT ON COLUMN tdm_ejecucion.progreso_pct IS 'Porcentaje estimado de avance.';
COMMENT ON COLUMN tdm_ejecucion.tablas_total IS 'Cantidad total de tablas consideradas en la ejecución.';
COMMENT ON COLUMN tdm_ejecucion.tablas_proc IS 'Cantidad de tablas procesadas hasta el momento.';
COMMENT ON COLUMN tdm_ejecucion.columnas_total IS 'Cantidad total de columnas consideradas en la ejecución.';
COMMENT ON COLUMN tdm_ejecucion.columnas_proc IS 'Cantidad de columnas procesadas hasta el momento.';
COMMENT ON COLUMN tdm_ejecucion.ultimo_objeto IS 'Último objeto procesado.';
COMMENT ON COLUMN tdm_ejecucion.ultimo_paso IS 'Último paso ejecutado por el proceso.';
COMMENT ON COLUMN tdm_ejecucion.error_count IS 'Contador acumulado de errores asociados a la ejecución.';
COMMENT ON COLUMN tdm_ejecucion.forzar_full IS 'Marca que indica si la ejecución forzó procesamiento completo.';
COMMENT ON COLUMN tdm_ejecucion.heartbeat_ts IS 'Marca de vida usada para monitoreo operativo de procesos largos.';



--------------------------------------------------------------------------------
-- 2) DETALLE DE ERRORES DE EJECUCION
--    Guarda errores por objeto y etapa. Debe ser usado por ambos procesos.
--------------------------------------------------------------------------------
CREATE TABLE tdm_ejecucion_error (
    error_id             NUMBER         NOT NULL,
    ejecucion_id         NUMBER         NOT NULL,
    owner_name           VARCHAR2(128),
    table_name           VARCHAR2(128),
    column_name          VARCHAR2(128),
    etapa                VARCHAR2(100),
    codigo_error         NUMBER,
    mensaje_error        VARCHAR2(4000),
    backtrace            VARCHAR2(4000),
    fecha_error          TIMESTAMP      DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_tdm_ejec_error PRIMARY KEY (error_id),
    CONSTRAINT fk_tdm_ejec_err_eje FOREIGN KEY (ejecucion_id)
        REFERENCES tdm_ejecucion (ejecucion_id)
) tablespace ASTSYSADMIN;

CREATE INDEX idm_ejec_error_01 ON tdm_ejecucion_error (ejecucion_id, fecha_error) tablespace ASTSYSADMIN online;
CREATE INDEX idm_ejec_error_02 ON tdm_ejecucion_error (etapa, codigo_error) tablespace ASTSYSADMIN online;

COMMENT ON TABLE tdm_ejecucion_error IS 'Detalle de errores registrados por ejecución, etapa y objeto afectado.';
COMMENT ON COLUMN tdm_ejecucion_error.etapa IS 'Etapa lógica o procedimiento donde ocurrió el error.';
COMMENT ON COLUMN tdm_ejecucion_error.codigo_error IS 'Código Oracle o código funcional registrado.';
COMMENT ON COLUMN tdm_ejecucion_error.mensaje_error IS 'Mensaje descriptivo del error.';
COMMENT ON COLUMN tdm_ejecucion_error.backtrace IS 'trace para soporte y diagnóstico.';

-------------------------------------------------------------------------------
-- 3) ALCANCE DE EJECUCION
--    Permite registrar el subconjunto de objetos incluidos en una ejecucion.
--------------------------------------------------------------------------------
CREATE TABLE tdm_ejecucion_scope (
    scope_id             NUMBER         NOT NULL,
    ejecucion_id         NUMBER         NOT NULL,
    owner_name           VARCHAR2(128)  NOT NULL,
    table_name           VARCHAR2(128)  NOT NULL,
    column_name          VARCHAR2(128),
    CONSTRAINT pk_tdm_ejec_scope PRIMARY KEY (scope_id),
    CONSTRAINT fk_tdm_scope_ejec FOREIGN KEY (ejecucion_id)
        REFERENCES tdm_ejecucion (ejecucion_id)
) tablespace ASTSYSADMIN ;

CREATE INDEX idm_ejec_scope_01 ON tdm_ejecucion_scope (ejecucion_id, owner_name, table_name, column_name) tablespace ASTSYSADMIN online;

COMMENT ON TABLE tdm_ejecucion_scope IS 'Subconjunto de objetos incluidos en una ejecución concreta.';
COMMENT ON COLUMN tdm_ejecucion_scope.column_name IS 'Columna específica incluida en el alcance; null si el alcance es a nivel tabla.';

--------------------------------------------------------------------------------
-- 4) CONTROL INCREMENTAL DE OBJETOS -checkpoint
--    Mantiene huella de tablas ya analizadas para procesos incrementales.
--------------------------------------------------------------------------------
CREATE TABLE tdm_objeto_ctrl (
    owner_name           VARCHAR2(128)  NOT NULL,
    table_name           VARCHAR2(128)  NOT NULL,
    object_id            NUMBER,
    last_ddl_time        DATE,
    column_count         NUMBER,
    firma_txt            VARCHAR2(2000),
    ultimo_run_id        NUMBER,
    estado_objeto        VARCHAR2(20)   DEFAULT 'PENDIENTE',
    motivo_estado        VARCHAR2(1000),
    fecha_ult_analisis   TIMESTAMP,
    CONSTRAINT pk_tdm_objeto_ctrl PRIMARY KEY (owner_name, table_name),
    CONSTRAINT ck_tdm_obj_estado CHECK (
        estado_objeto IN ('PENDIENTE','PROCESADO','OMITIDO','ERROR')
    )
) tablespace ASTSYSADMIN;

CREATE INDEX idm_objeto_ctrl_01 ON tdm_objeto_ctrl (owner_name, estado_objeto) tablespace ASTSYSADMIN online;

COMMENT ON TABLE tdm_objeto_ctrl IS 'Control incremental de tablas y metadatos analizados por el proceso de descubrimiento.';
COMMENT ON COLUMN tdm_objeto_ctrl.firma_txt IS 'Huella lógica del objeto para detectar cambios entre ejecuciones.';
COMMENT ON COLUMN tdm_objeto_ctrl.ultimo_run_id IS 'Última ejecución de descubrimiento que evaluó el objeto.';
COMMENT ON COLUMN tdm_objeto_ctrl.estado_objeto IS 'Estado operativo del objeto en el control incremental.';


--------------------------------------------------------------------------------
-- 5) CATALOGO DE REGLAS
--    Reglas de descubrimiento por nombre, comentario, patrón o tabla.
--------------------------------------------------------------------------------
CREATE TABLE tdm_regla (
    regla_id             NUMBER         NOT NULL,
    identificador        VARCHAR2(50)   NOT NULL,
    tipo_regla           VARCHAR2(20)   NOT NULL,
    expresion            VARCHAR2(500)  NOT NULL,
    puntuacion           NUMBER(8,2)    NOT NULL,
    prioridad            NUMBER         DEFAULT 100,
    confianza_min        NUMBER(5,2),
    muestra_min          NUMBER,
    activa               CHAR(1)        DEFAULT 'Y',
    descripcion          VARCHAR2(1000),
    CONSTRAINT pk_tdm_regla PRIMARY KEY (regla_id),
    CONSTRAINT ck_tdm_regla_activa CHECK (activa IN ('Y','N')),
    CONSTRAINT ck_tdm_regla_tipo CHECK (
        tipo_regla IN ('COLUMN_NAME','COLUMN_COMMENT','DATA_PATTERN','TABLE_NAME')
    )
) tablespace ASTSYSADMIN;

CREATE INDEX idm_regla_01 ON tdm_regla (activa, tipo_regla, identificador, prioridad) tablespace ASTSYSADMIN online;

COMMENT ON TABLE tdm_regla IS 'Catálogo de reglas utilizadas por el motor semántico de descubrimiento.';
COMMENT ON COLUMN tdm_regla.identificador IS 'Identificador de dato sensible asignado por la regla.';
COMMENT ON COLUMN tdm_regla.tipo_regla IS 'Tipo de regla: nombre de columna, comentario, patrón de datos o nombre de tabla.';
COMMENT ON COLUMN tdm_regla.expresion IS 'Expresión o patrón evaluado por la regla.';
COMMENT ON COLUMN tdm_regla.puntuacion IS 'Puntuación aportada por la regla al scoring final.';
COMMENT ON COLUMN tdm_regla.confianza_min IS 'Umbral mínimo de ratio para activar reglas por patrón de datos.';


--------------------------------------------------------------------------------
-- 6) HISTORICO DE COLUMNAS ANALIZADAS
--    Resultado detallado por columna y por ejecución.
--------------------------------------------------------------------------------
CREATE TABLE tdm_columna_hist (
    hist_id              NUMBER         NOT NULL,
    ejecucion_id         NUMBER         NOT NULL,
    owner_name           VARCHAR2(128)  NOT NULL,
    table_name           VARCHAR2(128)  NOT NULL,
    column_name          VARCHAR2(128)  NOT NULL,
    data_type            VARCHAR2(128),
    data_length          NUMBER,
    data_precision       NUMBER,
    data_scale           NUMBER,
    column_comment       VARCHAR2(4000),
    identificador        VARCHAR2(50),
    score_nombre         NUMBER(8,2),
    score_comentario     NUMBER(8,2),
    score_patron         NUMBER(8,2),
    score_tabla          NUMBER(8,2),
    score_total          NUMBER(8,2),
    sample_rows          NUMBER,
    matched_rows         NUMBER,
    ratio_match          NUMBER(8,5),
    ratio_null           NUMBER(8,5),
    estado_final         VARCHAR2(20),
    motivo_descarte      VARCHAR2(2000),
    enmascarar           CHAR(1),
    vigente              CHAR(1)        DEFAULT 'Y',
    hash_reglas          VARCHAR2(64),
    fecha_creacion       TIMESTAMP      DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_tdm_col_hist PRIMARY KEY (hist_id),
    CONSTRAINT uk_tdm_col_hist UNIQUE (
        ejecucion_id, owner_name, table_name, column_name
    ),
    CONSTRAINT fk_tdm_col_hist_eje FOREIGN KEY (ejecucion_id)
        REFERENCES tdm_ejecucion (ejecucion_id),
    CONSTRAINT ck_tdm_col_hist_vig CHECK (vigente IN ('Y','N')),
    CONSTRAINT ck_tdm_col_hist_enm CHECK (enmascarar IN ('Y','N')),
    CONSTRAINT ck_tdm_col_hist_est CHECK (estado_final IN ('CONFIRMADO','PROBABLE','REVISAR','DESCARTADO')
    )
) tablespace ASTSYSADMIN ;

CREATE INDEX idm_col_hist_01 ON tdm_columna_hist (owner_name, table_name, estado_final, identificador) tablespace ASTSYSADMIN online;
CREATE INDEX idm_col_hist_02 ON tdm_columna_hist (ejecucion_id, enmascarar) tablespace ASTSYSADMIN online;

COMMENT ON TABLE tdm_columna_hist IS 'Histórico del resultado de análisis por columna y por ejecución.';
COMMENT ON COLUMN tdm_columna_hist.identificador IS 'Identificador lógico finalmente asignado a la columna.';
COMMENT ON COLUMN tdm_columna_hist.score_total IS 'Score total acumulado para la clasificación de la columna.';
COMMENT ON COLUMN tdm_columna_hist.enmascarar IS 'Marca final de inclusión para el proceso de enmascaramiento.';
COMMENT ON COLUMN tdm_columna_hist.hash_reglas IS 'Huella de la combinación de reglas aplicada al resultado.';
COMMENT ON COLUMN tdm_columna_hist.motivo_descarte IS 'Motivo funcional por el que la columna fue descartada.';


--------------------------------------------------------------------------------
-- 7) HISTORICO DE DEPENDENCIAS
--    Dependencias detectadas para columnas candidatas.
--------------------------------------------------------------------------------
CREATE TABLE tdm_dependencia_hist (
    dependencia_id       NUMBER         NOT NULL,
    ejecucion_id         NUMBER         NOT NULL,
    owner_name           VARCHAR2(128)  NOT NULL,
    table_name           VARCHAR2(128)  NOT NULL,
    column_name          VARCHAR2(128)  NOT NULL,
    tipo_dependencia     VARCHAR2(30)   NOT NULL,
    dependencia_owner    VARCHAR2(128),
    dependencia_objeto   VARCHAR2(128),
    detalle              VARCHAR2(4000),
    fecha_creacion       TIMESTAMP      DEFAULT SYSTIMESTAMP,
    CONSTRAINT pk_tdm_dep_hist PRIMARY KEY (dependencia_id),
    CONSTRAINT fk_tdm_dep_hist_eje FOREIGN KEY (ejecucion_id)
        REFERENCES tdm_ejecucion (ejecucion_id)
) tablespace ASTSYSADMIN ;

CREATE INDEX idm_dep_hist_01 ON tdm_dependencia_hist (ejecucion_id, owner_name, table_name, column_name) tablespace ASTSYSADMIN online;

COMMENT ON TABLE tdm_dependencia_hist IS 'Histórico de dependencias detectadas por ejecución.';
COMMENT ON COLUMN tdm_dependencia_hist.tipo_dependencia IS 'Tipo de dependencia detectada: FK, TRIGGER, INDEX, VIEW, PROCEDURE, etc.';
COMMENT ON COLUMN tdm_dependencia_hist.detalle IS 'Detalle ampliado de la dependencia detectada.';



--------------------------------------------------------------------------------
-- 8) CATALOGO DE COLUMNAS
--    Listado para exportar a excel para validacion de usuario.
--------------------------------------------------------------------------------


CREATE TABLE tdm_columna_final (
    owner_name           VARCHAR2(128)  NOT NULL,
    table_name           VARCHAR2(128)  NOT NULL,
    column_name          VARCHAR2(128)  NOT NULL,
    identificador        VARCHAR2(50),
    enmascarar           CHAR(1),
    CONSTRAINT pk_tdm_col_final PRIMARY KEY (
        owner_name, table_name, column_name
    ),
    CONSTRAINT ck_tdm_col_final_enm CHECK (enmascarar IN ('Y','N'))
) tablespace ASTSYSADMIN;

CREATE INDEX idm_col_final_01 ON tdm_columna_final (enmascarar, identificador) tablespace ASTSYSADMIN online;
CREATE INDEX idm_col_final_02 ON tdm_columna_final(owner_name, enmascarar, table_name, column_name) TABLESPACE ASTSYSADMIN ONLINE;

COMMENT ON TABLE tdm_columna_final IS 'Catálogo de columnas analizadas, utilizado por el proceso de enmascaramiento.';
COMMENT ON COLUMN tdm_columna_final.identificador IS 'Identificador lógico vigente asociado a la columna.';
COMMENT ON COLUMN tdm_columna_final.enmascarar IS 'Marca definitiva que habilita la columna para el flujo de enmascaramiento.';


--------------------------------------------------------------------------------
-- 9) CATALOGO DE DEPENDENCIAS
--    Listado de dependencias final, las cuales serviran para el pre (disable) y post(enable)
--    del enmascaramiento
--------------------------------------------------------------------------------

CREATE TABLE tdm_dependencia_final (
    owner_name           VARCHAR2(128 CHAR)  NOT NULL,
    table_name           VARCHAR2(128 CHAR)  NOT NULL,
    column_name          VARCHAR2(128 CHAR)  NOT NULL,
    tipo_dependencia     VARCHAR2(30 CHAR)   NOT NULL,
    dependencia_owner    VARCHAR2(128 CHAR)  NOT NULL,
    dependencia_objeto   VARCHAR2(128 CHAR)  NOT NULL,
    categoria_uso        VARCHAR2(30 CHAR)   DEFAULT 'OPERATIVA' NOT NULL,
    accion_pre_mask      VARCHAR2(30 CHAR)   DEFAULT 'SOLO_INFORMATIVO' NOT NULL,
    accion_post_mask     VARCHAR2(30 CHAR)   DEFAULT 'SIN_ACCION' NOT NULL,
    detalle              VARCHAR2(4000 CHAR),
    CONSTRAINT pk_tdm_dep_final PRIMARY KEY (
        owner_name, table_name, column_name,
        tipo_dependencia, dependencia_owner, dependencia_objeto
    ),
    CONSTRAINT ck_tdm_dep_final_categoria    CHECK (categoria_uso IN ('INTEGRIDAD','OPERATIVA')),
    CONSTRAINT ck_tdm_dep_final_pre    CHECK (accion_pre_mask IN ('DISABLE','VALIDAR','SOLO_INFORMATIVO','SIN_ACCION')),
    CONSTRAINT ck_tdm_dep_final_post   CHECK (accion_post_mask IN ('ENABLE_VALIDATE','ENABLE_NOVALIDATE','ENABLE','REVISAR','SIN_ACCION'))
) TABLESPACE ASTSYSADMIN;

CREATE INDEX idm_dep_final_01  ON tdm_dependencia_final (owner_name, table_name, column_name) TABLESPACE ASTSYSADMIN ONLINE;  
CREATE INDEX idm_dep_final_02 ON tdm_dependencia_final (owner_name, tipo_dependencia, dependencia_owner, dependencia_objeto) TABLESPACE ASTSYSADMIN ONLINE;

COMMENT ON TABLE tdm_dependencia_final IS 'Catálogo final de dependencias para controlar el flujo PRE/POST del enmascaramiento.';
COMMENT ON COLUMN tdm_dependencia_final.tipo_dependencia IS 'Tipo de dependencia: FK/PK/UK/TRIGGER/otras, usado para estrategia de ejecución.';
COMMENT ON COLUMN tdm_dependencia_final.categoria_uso IS 'Naturaleza de la dependencia: INTEGRIDAD u OPERATIVA.';
COMMENT ON COLUMN tdm_dependencia_final.accion_pre_mask IS 'Política PRE: DISABLE, VALIDAR, SOLO_INFORMATIVO o SIN_ACCION.';
COMMENT ON COLUMN tdm_dependencia_final.accion_post_mask IS 'Política POST: ENABLE_VALIDATE, ENABLE_NOVALIDATE, ENABLE, REVISAR o SIN_ACCION.';
COMMENT ON COLUMN tdm_dependencia_final.detalle IS 'Detalle funcional complementario de la dependencia.';

--------------------------------------------------------------------------------
-- 10) EXCEPCIONES DE NEGOCIO
--     Permite forzar o excluir columnas del motor de descubrimiento.
--------------------------------------------------------------------------------
CREATE TABLE tdm_excepcion_col (
    owner_name           VARCHAR2(128)  NOT NULL,
    table_name           VARCHAR2(128)  NOT NULL,
    column_name          VARCHAR2(128)  NOT NULL,
    accion               VARCHAR2(10)   NOT NULL,
    identificador_forz   VARCHAR2(50),
    razon                VARCHAR2(1000),
    activa               CHAR(1)        DEFAULT 'Y',
    CONSTRAINT pk_tdm_exc_col PRIMARY KEY (
        owner_name, table_name, column_name
    ),
    CONSTRAINT ck_tdm_exc_accion CHECK (accion IN ('EXCLUDE','FORCE')),
    CONSTRAINT ck_tdm_exc_activa CHECK (activa IN ('Y','N'))
) tablespace ASTSYSADMIN;

CREATE INDEX idm_exc_col_01 ON tdm_excepcion_col (activa, accion) tablespace ASTSYSADMIN online;

COMMENT ON TABLE tdm_excepcion_col IS 'Excepciones manuales del proceso de descubrimiento para excluir o forzar columnas.';
COMMENT ON COLUMN tdm_excepcion_col.identificador_forz IS 'Identificador forzado cuando la acción manual es FORCE.';
COMMENT ON COLUMN tdm_excepcion_col.razon IS 'Justificación funcional de la excepción.';


--------------------------------------------------------------------------------
-- 11) SECUENCIAS
--
--------------------------------------------------------------------------------
CREATE SEQUENCE seq_dm_ejecucion START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_dm_ejecucion_err START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_dm_ejecucion_scope START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_dm_regla START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_dm_columna_hist START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_dm_dependencia_hist START WITH 1 INCREMENT BY 1 NOCACHE;
