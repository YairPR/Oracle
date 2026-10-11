#datamasking #oracle #catalogo #ff1 #11g

**Catalogo de objetos del motor DATAMASKING**

> [!note] Versión
> Valido para Oracle 11g R2 en adelante (piso de portabilidad del motor). Generado el 2026-10-10 a partir del codigo fuente de la carpeta FF1 (archivos 01, 02, 10 a 40, 98 y 99). Esta nota es el inventario de referencia: que existe, por que existe y con que proceso se enlaza.

**Como leer este catalogo**

El motor se divide en dos fases que comparten infraestructura. La fase de **descubrimiento** recorre un esquema, puntua cada columna con reglas (nombre, comentario, patron de datos) y deja el resultado en un catalogo (`tdm_columna_final`). La fase de **enmascaramiento** lee ese catalogo, desactiva dependencias, cifra los valores con FF1 y las reactiva. Todo lo demas (trazas, errores, secretos, parametros) soporta a las dos. Cada objeto se documenta con tres preguntas: **que es**, **por que existe** y **con que proceso se enlaza**.

Convencion de nombres: `tdm_*` tablas, `idm_*` indices, `ui_*` indice unico, `pk_/fk_/uk_/ck_` restricciones, `seq_dm_*` secuencias, `pkg_dm_*` paquetes, `proc_dm_*` procedimientos y `func_dm_*` funciones.

**Indice**

1. Tablas (17) con sus columnas, restricciones y procesos que las usan
2. Indices (22) con la consulta que sirven y su estado
3. Secuencias (9)
4. Paquetes (16) y sus subprogramas
5. Scripts de operacion
6. Mapa de enlaces entre procesos

**1. Tablas**

**1.1 Grupo Descubrimiento**

**tdm_ejecucion**

Por que existe: PREGUNTA: que corrida es y en que estado esta ahora. Una fila por corrida de DESCUBRIMIENTO o ENMASCARAMIENTO: estado, progreso, latido, sesion Oracle y solicitud de cancelacion. Es la fuente unica para monitor, cancel y reanudar.

- Escriben: dm_enmascara_cancel.sql, dm_enmascara_reanudar.sql, `pkg_dm_descubrimiento`, `pkg_dm_enmascarar`, `pkg_dm_mask_columna`, `pkg_dm_mask_estado`, `pkg_dm_trazabilidad`
- Solo leen: dm_enmascara.sql, `pkg_dm_desc_catalogo`, `pkg_dm_export`, `pkg_dm_mask_validacion`, `pkg_dm_mask_worker`, `pkg_dm_pepper`

| Columna | Tipo | Por que existe |
|---|---|---|
| `ejecucion_id` | NUMBER NOT NULL | Identificador único de la ejecución. |
| `ora_esquema` | VARCHAR2(128) NOT NULL | Esquema objetivo del proceso. |
| `ora_usuario` | VARCHAR2(128) NOT NULL | Usuario bbdd que lanzó la ejecución. |
| `fase_proceso` | VARCHAR2(30) NOT NULL | Fase del motor: descubrimiento o enmascaramiento. |
| `estado` | VARCHAR2(20) NOT NULL | Estado de la ejecución. |
| `fecha_inicio` | TIMESTAMP NOT NULL | Momento en que arranca el proceso (base de duraciones y de orden cronologico). |
| `fecha_fin` | TIMESTAMP | Momento en que termina; NULL mientras sigue abierto. |
| `progreso_pct` | NUMBER(5,2) DEFAULT 0 | Porcentaje estimado de avance. |
| `tablas_total` | NUMBER DEFAULT 0 | Cantidad total de tablas consideradas en la ejecución. |
| `tablas_proc` | NUMBER DEFAULT 0 | Cantidad de tablas procesadas hasta el momento. |
| `columnas_total` | NUMBER DEFAULT 0 | Cantidad total de columnas consideradas en la ejecución. |
| `columnas_proc` | NUMBER DEFAULT 0 | Cantidad de columnas procesadas hasta el momento. |
| `ultimo_objeto` | VARCHAR2(400) | Último objeto procesado. |
| `ultimo_paso` | VARCHAR2(200) | Último paso ejecutado por el proceso. |
| `detalle` | VARCHAR2(4000) | Texto libre de contexto de la corrida; la historia paso a paso esta en TDM_MASK_TRACE. |
| `error_count` | NUMBER DEFAULT 0 | Contador acumulado de errores asociados a la ejecución. |
| `forzar_full` | CHAR(1) DEFAULT 'N' | Marca que indica si la ejecución forzó procesamiento completo. |
| `cancel_requested` | CHAR(1) DEFAULT 'N' | Y = se pidio cancelar la corrida (proc_dm_cancelar); el motor lo detecta entre columna y columna. Unico lugar donde vive la solicitud de cancelacion. |
| `sesion_audsid` | NUMBER | AUDSID de la sesion orquestadora que lanzo la corrida. |
| `sesion_sid` | NUMBER | SID de la sesion orquestadora (para saber si sigue viva y poder matarla). |
| `sesion_serial` | NUMBER | SERIAL# de la sesion orquestadora. |
| `sesion_inst_id` | NUMBER | Instancia RAC de la sesion orquestadora. |
| `heartbeat_ts` | TIMESTAMP | Marca de vida usada para monitoreo operativo de procesos largos. |

Restricciones: `pk_tdm_ejecucion` PRIMARY KEY (ejecucion_id); `ck_tdm_ejec_forzar` CHECK (forzar_full IN ('Y','N'); `ck_tdm_ejec_fase` CHECK (fase_proceso IN ('DESCUBRIMIENTO','ENMASCARAMIENTO'); `ck_tdm_ejec_estado` CHECK ( estado IN ('PENDIENTE','EJECUTANDO','PAUSADO','ABORTADA','FINALIZADO','CANCELADO','ERROR'); `ck_tdm_ejec_cancel` CHECK (cancel_requested IN ('Y','N')

**tdm_ejecucion_scope**

Por que existe: Subconjunto de objetos incluidos en una ejecución concreta.

- Escriben: `pkg_dm_descubrimiento`
- Solo leen: ninguno

| Columna | Tipo | Por que existe |
|---|---|---|
| `scope_id` | NUMBER NOT NULL | Clave tecnica de la fila de alcance. |
| `ejecucion_id` | NUMBER NOT NULL | Corrida del motor a la que pertenece la fila (FK a tdm_ejecucion). |
| `ora_owner` | VARCHAR2(128) NOT NULL | Esquema propietario del objeto analizado (el esquema de datos, no el del motor). |
| `table_name` | VARCHAR2(128) NOT NULL | Tabla analizada. |
| `column_name` | VARCHAR2(128) | Columna específica incluida en el alcance; null si el alcance es a nivel tabla. |

Restricciones: `pk_tdm_ejec_scope` PRIMARY KEY (scope_id); `fk_tdm_scope_ejec` FOREIGN KEY (ejecucion_id) REFERENCES tdm_ejecucion (ejecucion_id)

**tdm_objeto_ctrl**

Por que existe: Control incremental de tablas y metadatos analizados por el proceso de descubrimiento.

- Escriben: `pkg_dm_descubrimiento`
- Solo leen: `pkg_dm_desc_catalogo`

| Columna | Tipo | Por que existe |
|---|---|---|
| `ora_owner` | VARCHAR2(128) NOT NULL | Esquema propietario del objeto analizado (el esquema de datos, no el del motor). |
| `table_name` | VARCHAR2(128) NOT NULL | Tabla analizada. |
| `object_id` | NUMBER | OBJECT_ID de la tabla al analizarla: junto con last_ddl_time y firma detecta que la tabla cambio. |
| `last_ddl_time` | DATE | Ultimo DDL de la tabla al analizarla; si cambia, se reanaliza. |
| `column_count` | NUMBER | Numero de columnas al analizar; parte de la firma de cambio y base del progreso. |
| `firma_txt` | VARCHAR2(2000) | Huella lógica del objeto para detectar cambios entre ejecuciones. |
| `ultimo_run_id` | NUMBER | Última ejecución de descubrimiento que evaluó el objeto. |
| `estado_objeto` | VARCHAR2(20) DEFAULT 'PENDIENTE' | Estado operativo del objeto en el control incremental. |
| `motivo_estado` | VARCHAR2(1000) | Texto del por que la tabla quedo OMITIDO o ERROR. |
| `fecha_ult_analisis` | TIMESTAMP | Cuando se analizo por ultima vez. |
| `estado_objeto` | IN ('PENDIENTE','PROCESADO','OMITIDO','ERROR') | Estado operativo del objeto en el control incremental. |

Restricciones: `pk_tdm_objeto_ctrl` PRIMARY KEY (ora_owner, table_name); `ck_tdm_obj_estado` CHECK ( estado_objeto IN ('PENDIENTE','PROCESADO','OMITIDO','ERROR')

**tdm_regla**

Por que existe: Catálogo de reglas utilizadas por el motor semántico de descubrimiento.

- Escriben: 03_dm_descubrimiento_carga_reglas.sql
- Solo leen: `pkg_dm_desc_puntuacion`, `pkg_dm_descubrimiento`

| Columna | Tipo | Por que existe |
|---|---|---|
| `regla_id` | NUMBER NOT NULL | Clave tecnica de la regla (seq_dm_regla). |
| `identificador` | VARCHAR2(50) NOT NULL | Identificador de dato sensible asignado por la regla. |
| `tipo_regla` | VARCHAR2(20) NOT NULL | Tipo de regla: nombre de columna, comentario, patrón de datos o nombre de tabla. |
| `expresion` | VARCHAR2(500) NOT NULL | Expresión o patrón evaluado por la regla. |
| `puntuacion` | NUMBER(8,2) NOT NULL | Puntuación aportada por la regla al scoring final. |
| `prioridad` | NUMBER DEFAULT 100 | Orden de evaluacion dentro de un identificador y tipo (menor primero). |
| `confianza_min` | NUMBER(5,2) | Umbral mínimo de ratio para activar reglas por patrón de datos. |
| `muestra_min` | NUMBER | Minimo de filas con dato que debe tener la muestra para que una regla DATA_PATTERN cuente. |
| `activa` | CHAR(1) DEFAULT 'Y' | Y/N: la fila solo se aplica si esta activa; permite apagar sin borrar. |
| `descripcion` | VARCHAR2(1000) | Por que existe la regla (criterio funcional, para auditoria). |
| `tipo_regla` | IN ('COLUMN_NAME','COLUMN_COMMENT','DATA_PATTERN','TABLE_NAME') | Tipo de regla: nombre de columna, comentario, patrón de datos o nombre de tabla. |

Restricciones: `pk_tdm_regla` PRIMARY KEY (regla_id); `ck_tdm_regla_activa` CHECK (activa IN ('Y','N'); `ck_tdm_regla_tipo` CHECK ( tipo_regla IN ('COLUMN_NAME','COLUMN_COMMENT','DATA_PATTERN','TABLE_NAME')

**tdm_columna_hist**

Por que existe: Histórico del resultado de análisis por columna y por ejecución.

- Escriben: 97_configurar_excepciones.sql, `pkg_dm_descubrimiento`
- Solo leen: `pkg_dm_desc_catalogo`, `pkg_dm_export`, `pkg_dm_mask_columna`

| Columna | Tipo | Por que existe |
|---|---|---|
| `hist_id` | NUMBER NOT NULL | Clave tecnica de la fila de historico. |
| `ejecucion_id` | NUMBER NOT NULL | Corrida del motor a la que pertenece la fila (FK a tdm_ejecucion). |
| `ora_owner` | VARCHAR2(128) NOT NULL | Esquema propietario del objeto analizado (el esquema de datos, no el del motor). |
| `table_name` | VARCHAR2(128) NOT NULL | Tabla analizada. |
| `column_name` | VARCHAR2(128) NOT NULL | Columna analizada. |
| `data_type` | VARCHAR2(128) | Tipo de dato de la columna al evaluarla. |
| `data_length` | NUMBER | Longitud declarada; decide si cabe el valor enmascarado. |
| `data_precision` | NUMBER | Precision numerica. |
| `data_scale` | NUMBER | Escala numerica. |
| `column_comment` | VARCHAR2(4000) | Comentario del diccionario usado por las reglas COLUMN_COMMENT. |
| `identificador` | VARCHAR2(50) | Identificador lógico finalmente asignado a la columna. |
| `score_nombre` | NUMBER(8,2) | Puntos aportados por las reglas COLUMN_NAME. |
| `score_comentario` | NUMBER(8,2) | Puntos aportados por las reglas COLUMN_COMMENT. |
| `score_patron` | NUMBER(8,2) | Puntos aportados por las reglas DATA_PATTERN sobre la muestra de datos. |
| `score_tabla` | NUMBER(8,2) | Puntos aportados por las reglas TABLE_NAME (contexto de la tabla). |
| `score_total` | NUMBER(8,2) | Score total acumulado para la clasificación de la columna. |
| `sample_rows` | NUMBER | Filas realmente leidas en la muestra. |
| `matched_rows` | NUMBER | Filas de la muestra que cumplen el patron. |
| `ratio_match` | NUMBER(8,5) | matched_rows / sample_rows. |
| `ratio_null` | NUMBER(8,5) | Proporcion de nulos en la muestra. |
| `estado_final` | VARCHAR2(20) | CONFIRMADO >=85, PROBABLE >=65, REVISAR >=45, DESCARTADO. |
| `motivo_descarte` | VARCHAR2(2000) | Motivo funcional por el que la columna fue descartada. |
| `enmascarar` | CHAR(1) | Marca final de inclusión para el proceso de enmascaramiento. |
| `vigente` | CHAR(1) DEFAULT 'Y' | Y/N de vigencia. HALLAZGO: nadie la escribe en N (siempre Y por defecto); se lee como NVL(vigente,Y)=Y en pkg_dm_mask_columna y pkg_dm_export. Columna sin uso real. |
| `hash_reglas` | VARCHAR2(64) | Huella de la combinación de reglas aplicada al resultado. |
| `fecha_creacion` | TIMESTAMP DEFAULT SYSTIMESTAMP | Momento de insercion; auditoria. |

Restricciones: `pk_tdm_col_hist` PRIMARY KEY (hist_id); `uk_tdm_col_hist` UNIQUE ( ejecucion_id, ora_owner, table_name, column_name ); `fk_tdm_col_hist_eje` FOREIGN KEY (ejecucion_id) REFERENCES tdm_ejecucion (ejecucion_id); `ck_tdm_col_hist_vig` CHECK (vigente IN ('Y','N'); `ck_tdm_col_hist_enm` CHECK (enmascarar IN ('Y','N'); `ck_tdm_col_hist_est` CHECK (estado_final IN ('CONFIRMADO','PROBABLE','REVISAR','DESCARTADO')

**tdm_dependencia_hist**

Por que existe: Histórico de dependencias detectadas por ejecución.

- Escriben: `pkg_dm_desc_catalogo`, `pkg_dm_descubrimiento`
- Solo leen: ninguno

| Columna | Tipo | Por que existe |
|---|---|---|
| `dependencia_id` | NUMBER NOT NULL | Clave tecnica de la dependencia historica. |
| `ejecucion_id` | NUMBER NOT NULL | Corrida del motor a la que pertenece la fila (FK a tdm_ejecucion). |
| `ora_owner` | VARCHAR2(128) NOT NULL | Esquema propietario del objeto analizado (el esquema de datos, no el del motor). |
| `table_name` | VARCHAR2(128) NOT NULL | Tabla analizada. |
| `column_name` | VARCHAR2(128) NOT NULL | Columna analizada. |
| `tipo_dependencia` | VARCHAR2(30) NOT NULL | Tipo de dependencia detectada: FK, TRIGGER, INDEX, VIEW, PROCEDURE, etc. |
| `dependencia_owner` | VARCHAR2(128) | Esquema del objeto dependiente (constraint o trigger). |
| `dependencia_objeto` | VARCHAR2(128) | Nombre del constraint o trigger dependiente. |
| `detalle` | VARCHAR2(4000) | Detalle ampliado de la dependencia detectada. |
| `fecha_creacion` | TIMESTAMP DEFAULT SYSTIMESTAMP | Momento de insercion; auditoria. |

Restricciones: `pk_tdm_dep_hist` PRIMARY KEY (dependencia_id); `fk_tdm_dep_hist_eje` FOREIGN KEY (ejecucion_id) REFERENCES tdm_ejecucion (ejecucion_id)

**tdm_columna_final**

Por que existe: Catálogo de columnas analizadas, utilizado por el proceso de enmascaramiento.

- Escriben: `pkg_dm_desc_catalogo`, `pkg_dm_dominios`, `pkg_dm_mask_columna`
- Solo leen: dm_enmascara.sql, `pkg_dm_enmascarar`, `pkg_dm_export`, `pkg_dm_mask_dependencias`, `pkg_dm_mask_worker`

| Columna | Tipo | Por que existe |
|---|---|---|
| `ora_owner` | VARCHAR2(128) NOT NULL | Esquema de la columna a enmascarar. |
| `table_name` | VARCHAR2(128) NOT NULL | Tabla analizada. |
| `column_name` | VARCHAR2(128) NOT NULL | Columna analizada. |
| `identificador` | VARCHAR2(50) | Identificador lógico vigente asociado a la columna. |
| `enmascarar` | CHAR(1) | Marca definitiva que habilita la columna para el flujo de enmascaramiento. |
| `dominio` | VARCHAR2(128) | Dominio o componente referencial al que pertenece la columna (derivado de FKs conexas). |

Restricciones: `pk_tdm_col_final` PRIMARY KEY ( ora_owner, table_name, column_name ); `ck_tdm_col_final_enm` CHECK (enmascarar IN ('Y','N')

**tdm_dependencia_final**

Por que existe: Catálogo final de dependencias para controlar el flujo PRE/POST del enmascaramiento.

- Escriben: `pkg_dm_desc_catalogo`
- Solo leen: `pkg_dm_mask_dependencias`

| Columna | Tipo | Por que existe |
|---|---|---|
| `ora_owner` | VARCHAR2(128 CHAR) NOT NULL | Esquema propietario del objeto analizado (el esquema de datos, no el del motor). |
| `table_name` | VARCHAR2(128 CHAR) NOT NULL | Tabla analizada. |
| `column_name` | VARCHAR2(128 CHAR) NOT NULL | Columna analizada. |
| `tipo_dependencia` | VARCHAR2(30 CHAR) NOT NULL | Tipo de dependencia: FK/PK/UK/TRIGGER/otras, usado para estrategia de ejecución. |
| `dependencia_owner` | VARCHAR2(128 CHAR) NOT NULL | Esquema del constraint o trigger dependiente. |
| `dependencia_objeto` | VARCHAR2(128 CHAR) NOT NULL | Nombre del constraint o trigger dependiente. |
| `categoria_uso` | VARCHAR2(30 CHAR) DEFAULT 'OPERATIVA' NOT NULL | Naturaleza de la dependencia: INTEGRIDAD u OPERATIVA. |
| `accion_pre_mask` | VARCHAR2(30 CHAR) DEFAULT 'SOLO_INFORMATIVO' NOT NULL | Política PRE: DISABLE, VALIDAR, SOLO_INFORMATIVO o SIN_ACCION. |
| `accion_post_mask` | VARCHAR2(30 CHAR) DEFAULT 'SIN_ACCION' NOT NULL | Política POST: ENABLE_VALIDATE, ENABLE_NOVALIDATE, ENABLE, REVISAR o SIN_ACCION. |
| `detalle` | VARCHAR2(4000 CHAR) | Detalle funcional complementario de la dependencia. |

Restricciones: `pk_tdm_dep_final` PRIMARY KEY ( ora_owner, table_name, column_name, tipo_dependencia, dependencia_owner, dependencia_objeto ); `ck_tdm_dep_final_categoria` CHECK (categoria_uso IN ('INTEGRIDAD','OPERATIVA'); `ck_tdm_dep_final_pre` CHECK (accion_pre_mask IN ('DISABLE','VALIDAR','SOLO_INFORMATIVO','SIN_ACCION'); `ck_tdm_dep_final_post` CHECK (accion_post_mask IN ('ENABLE_VALIDATE','ENABLE_NOVALIDATE','ENABLE','REVISAR','SIN_ACCION')

**tdm_excepcion_col**

Por que existe: Excepciones manuales del proceso de descubrimiento para excluir o forzar columnas.

- Escriben: 97_configurar_excepciones.sql, `pkg_dm_mask_columna`
- Solo leen: dm_enmascara.sql, `pkg_dm_desc_catalogo`, `pkg_dm_enmascarar`, `pkg_dm_mask_worker`

| Columna | Tipo | Por que existe |
|---|---|---|
| `ora_owner` | VARCHAR2(128) NOT NULL | Esquema propietario del objeto analizado (el esquema de datos, no el del motor). |
| `table_name` | VARCHAR2(128) NOT NULL | Tabla analizada. |
| `column_name` | VARCHAR2(128) NOT NULL | Columna analizada. |
| `accion` | VARCHAR2(10) NOT NULL | FORCE (enmascarar si o si con identificador_forz) o EXCLUDE (nunca enmascarar). |
| `identificador_forz` | VARCHAR2(50) | Identificador forzado cuando la acción manual es FORCE. |
| `razon` | VARCHAR2(1000) | Justificación funcional de la excepción. |
| `activa` | CHAR(1) DEFAULT 'Y' | Y/N: la fila solo se aplica si esta activa; permite apagar sin borrar. |

Restricciones: `pk_tdm_exc_col` PRIMARY KEY ( ora_owner, table_name, column_name ); `ck_tdm_exc_accion` CHECK (accion IN ('EXCLUDE','FORCE'); `ck_tdm_exc_activa` CHECK (activa IN ('Y','N')

**1.2 Grupo Transversal**

**tdm_ejecucion_error**

Por que existe: PREGUNTA: que fallo exactamente y por que. Una fila por error con codigo, mensaje completo y backtrace, para diagnosticar. Unico escritor: pkg_dm_trazabilidad.proc_dm_log_ejec_error, que ademas deja la linea de tiempo en TDM_MASK_TRACE con error_id=N al inicio del detalle.

- Escriben: `pkg_dm_trazabilidad`
- Solo leen: dm_enmascara.sql, dm_enmascara_reanudar.sql

| Columna | Tipo | Por que existe |
|---|---|---|
| `error_id` | NUMBER NOT NULL | Clave tecnica del error; la traza lo cita (error_id=N). |
| `ejecucion_id` | NUMBER NOT NULL | Corrida del motor a la que pertenece la fila (FK a tdm_ejecucion). |
| `solicitud_id` | NUMBER | Referencia a la solicitud de enmascaramiento si ocurrió en esa etapa (NULL para discovery). |
| `ora_owner` | VARCHAR2(128) | Esquema propietario del objeto analizado (el esquema de datos, no el del motor). |
| `table_name` | VARCHAR2(128) | Tabla analizada. |
| `column_name` | VARCHAR2(128) | Columna analizada. |
| `etapa` | VARCHAR2(100) | Etapa lógica o procedimiento donde ocurrió el error. |
| `codigo_error` | NUMBER | Código Oracle o código funcional registrado. |
| `mensaje_error` | VARCHAR2(4000) | Mensaje descriptivo del error. |
| `backtrace` | VARCHAR2(4000) | trace para soporte y diagnóstico. |
| `fecha_error` | TIMESTAMP DEFAULT SYSTIMESTAMP | Momento exacto del error. |

Restricciones: `pk_tdm_ejec_error` PRIMARY KEY (error_id); `fk_tdm_ejec_err_eje` FOREIGN KEY (ejecucion_id) REFERENCES tdm_ejecucion (ejecucion_id)

**tdm_parametro**

Por que existe: PREGUNTA: que valores o catalogos usa el motor y puedo ajustar sin recompilar. Grupo EVENTO = catalogo de pasos de la traza (FASE.PASO -> nivel y significado).

- Escriben: ninguno (solo carga manual/script)
- Solo leen: `pkg_dm_trazabilidad`

| Columna | Tipo | Por que existe |
|---|---|---|
| `grupo` | VARCHAR2(30) NOT NULL | Familia del parametro. Hoy solo EVENTO (catalogo de pasos de la traza). |
| `clave` | VARCHAR2(100) NOT NULL | Identificador dentro del grupo. En EVENTO: FASE.PASO tal como lo escribe proc_dm_trace. |
| `valor` | VARCHAR2(400) | Valor. En EVENTO: nivel del paso (INFO, WARN o ERROR). |
| `descripcion` | VARCHAR2(200) | Descripcion breve: de que es el parametro o que significa el paso. |
| `fecha_modificacion` | TIMESTAMP DEFAULT SYSTIMESTAMP | Fecha de la ultima modificacion del registro. |

Restricciones: `pk_tdm_parametro` PRIMARY KEY (grupo, clave); `ck_tdm_parametro_grupo` CHECK (grupo IN ('EVENTO')

**tdm_secreto**

Por que existe: Semillas y secretos de enmascaramiento (pepper efimero por campana: clave = PEPPER_MASK:ejecucion_id).

- Escriben: `pkg_dm_pepper`
- Solo leen: `pkg_dm_mask_ff1`

| Columna | Tipo | Por que existe |
|---|---|---|
| `clave` | VARCHAR2(64) NOT NULL | Identificador de la clave secreta. |
| `valor` | VARCHAR2(128) NOT NULL | Valor de la clave secreta (Raw Hex o texto largo). |

Restricciones: `pk_tdm_secreto` PRIMARY KEY (clave)

**1.3 Grupo Enmascaramiento**

**tdm_mask_solicitud**

Por que existe: PREGUNTA: que intentos de enmascarar hubo dentro de una corrida y como terminó cada uno. Una fila por intento (primer arranque o reanudación): estado, punto de control y contadores propios. Latido, sesión y cancelación están en TDM_EJECUCION.

- Escriben: `pkg_dm_enmascarar`, `pkg_dm_mask_columna`, `pkg_dm_mask_estado`
- Solo leen: dm_enmascara.sql, dm_enmascara_reanudar.sql, `pkg_dm_export`, `pkg_dm_mask_validacion`, `pkg_dm_mask_worker`

| Columna | Tipo | Por que existe |
|---|---|---|
| `solicitud_id` | NUMBER NOT NULL | Identificador único de la solicitud de enmascaramiento. |
| `ejecucion_id` | NUMBER NOT NULL | Referencia a la ejecución maestra registrada en tdm_ejecucion. |
| `ora_esquema` | VARCHAR2(128) NOT NULL | Esquema Oracle objetivo del enmascaramiento. |
| `estado` | VARCHAR2(30) NOT NULL | Estado del intento: PENDIENTE, EN_PROCESO, FINALIZADO, ERROR, CANCELADO o REPROCESANDO. |
| `fase_actual` | VARCHAR2(30) | Fase actual del flujo de masking. |
| `reintento_nro` | NUMBER DEFAULT 0 | Número de reintento acumulado. |
| `forzar_reproceso` | CHAR(1) DEFAULT 'N' | Indica si la solicitud fue lanzada en modo reproceso forzado. |
| `fecha_inicio` | TIMESTAMP DEFAULT SYSTIMESTAMP | Momento en que arranca el proceso (base de duraciones y de orden cronologico). |
| `fecha_fin` | TIMESTAMP | Momento en que termina; NULL mientras sigue abierto. |
| `filas_procesadas` | NUMBER DEFAULT 0 | Contador acumulado de filas tratadas. |
| `filas_error` | NUMBER DEFAULT 0 | Contador acumulado de errores. |
| `tablas_procesadas` | NUMBER DEFAULT 0 | Contador acumulado de tablas tratadas. |
| `columnas_procesadas` | NUMBER DEFAULT 0 | Contador acumulado de columnas evaluadas. |
| `ultima_tabla` | VARCHAR2(128) | Última tabla procesada. |
| `ultima_columna` | VARCHAR2(128) | Última columna evaluada o tratada. |
| `detalle` | VARCHAR2(4000) | Detalle técnico o funcional del subproceso. |
| `estado` | IN ('PENDIENTE','EN_PROCESO','FINALIZADO','ERROR','CANCELADO','REPROCESANDO') | Estado del intento: PENDIENTE, EN_PROCESO, FINALIZADO, ERROR, CANCELADO o REPROCESANDO. |

Restricciones: `pk_tdm_mask_solicitud` PRIMARY KEY (solicitud_id); `fk_tdm_mask_sol_ejec` FOREIGN KEY (ejecucion_id) REFERENCES tdm_ejecucion (ejecucion_id); `ck_tdm_mask_sol_forzar` CHECK (forzar_reproceso IN ('Y','N'); `ck_tdm_mask_sol_estado` CHECK ( estado IN ('PENDIENTE','EN_PROCESO','FINALIZADO','ERROR','CANCELADO','REPROCESANDO')

**tdm_mask_trace**

Por que existe: PREGUNTA: que paso, en que orden y cuanto tardo. Linea de tiempo de una corrida: una fila por paso del catalogo TDM_PARAMETRO (grupo EVENTO). El enmascaramiento deja todos sus pasos; el descubrimiento deja solo un resumen y, aparte, tablas omitidas, avisos o errores. Cada error queda ubicado aqui y su detalle completo esta en TDM_EJECUCION_ERROR. No guarda valores de datos.

- Escriben: `pkg_dm_trazabilidad`
- Solo leen: dm_enmascara.sql, dm_enmascara_reanudar.sql, `pkg_dm_enmascarar`, `pkg_dm_mask_columna`, `pkg_dm_mask_dependencias`, `pkg_dm_mask_worker`

| Columna | Tipo | Por que existe |
|---|---|---|
| `trace_id` | NUMBER NOT NULL | Identificador único del evento de trace. |
| `solicitud_id` | NUMBER | Referencia a la solicitud de enmascaramiento. |
| `ejecucion_id` | NUMBER | Referencia a la ejecución maestra. |
| `nivel` | VARCHAR2(10) DEFAULT 'INFO' | Nivel del evento (INFO, WARN, ERROR), tomado del catalogo TDM_PARAMETRO grupo EVENTO. |
| `fase` | VARCHAR2(40) | Fase funcional del evento (ENMASCARAMIENTO, PRE, PROPAGACION, MASK, POST_SYNC, POST, FIN, DESCUBRIMIENTO, CONTROL, ERROR, ADMIN). Ya NO codifica el nivel. |
| `paso` | VARCHAR2(120) | Paso concreto; con la fase forma la clave del catalogo de eventos. |
| `detalle` | VARCHAR2(4000) | Texto del evento. En los pasos por columna empieza por ESQUEMA.TABLA.COLUMNA; el formato 'ESQUEMA.TABLA.COLUMNA filas=N' de MASK.APPLY_COL lo lee la reanudacion como punto de control: no cambiarlo. En ERROR.REGISTRADO empieza por error_id=N (clave en TDM_EJECUCION_ERROR). |
| `fecha_evento` | DATE DEFAULT SYSDATE | Fecha y hora del evento, al segundo (tipo DATE). Para verla como DD-MM-YYYY HH24:MI:SS: TO_CHAR(fecha_evento,'DD-MM-YYYY HH24:MI:SS'). Para ordenar eventos del mismo segundo usar trace_id. |
| `duracion_seg` | NUMBER(12,2) | Duracion del paso en segundos, con 2 decimales (NULL si no se midio). |

Restricciones: `pk_tdm_mask_trace` PRIMARY KEY (trace_id); `fk_tdm_mask_trace_sol` FOREIGN KEY (solicitud_id) REFERENCES tdm_mask_solicitud (solicitud_id); `fk_tdm_mask_trace_ejec` FOREIGN KEY (ejecucion_id) REFERENCES tdm_ejecucion (ejecucion_id); `ck_tdm_mask_trace_nivel` CHECK (nivel IN ('INFO','WARN','ERROR')

**tdm_mask_dep_estado**

Por que existe: Estado previo y posterior de dependencias técnicas deshabilitadas/habilitadas durante el masking.

- Escriben: `pkg_dm_mask_dependencias`
- Solo leen: dm_enmascara.sql

| Columna | Tipo | Por que existe |
|---|---|---|
| `solicitud_id` | NUMBER NOT NULL | Referencia a la solicitud de enmascaramiento. |
| `tipo_objeto` | VARCHAR2(20) NOT NULL | Tipo de objeto gestionado en el pre/post: CONSTRAINT o TRIGGER. |
| `ora_owner` | VARCHAR2(128) NOT NULL | Owner del objeto dependiente. |
| `table_name` | VARCHAR2(128) | Tabla afectada, si aplica. |
| `objeto_name` | VARCHAR2(128) NOT NULL | Nombre del constraint o trigger. |
| `estado_previo` | VARCHAR2(20) | Estado original antes de deshabilitar. |
| `estado_posterior` | VARCHAR2(30) | Estado final tras rehabilitar. |
| `deshabilitado_ok` | CHAR(1) DEFAULT 'N' | Indica si la operación de deshabilitado se ejecutó correctamente. |
| `habilitado_ok` | CHAR(1) DEFAULT 'N' | Indica si la operación de rehabilitado se ejecutó correctamente. |
| `orden_rehabilitacion` | NUMBER DEFAULT 1 | Orden recomendado de rehabilitación. |
| `mensaje_error` | VARCHAR2(4000) | Mensaje técnico asociado a la operación sobre la dependencia. |
| `fecha_pre` | TIMESTAMP | Fecha de operación pre. |
| `fecha_post` | TIMESTAMP | Fecha de operación post. |

Restricciones: `pk_tdm_mask_dep_estado` PRIMARY KEY ( solicitud_id, tipo_objeto, ora_owner, table_name, objeto_name ); `fk_tdm_mask_dep_sol` FOREIGN KEY (solicitud_id) REFERENCES tdm_mask_solicitud (solicitud_id); `ck_tdm_mask_dep_tipo` CHECK (tipo_objeto IN ('CONSTRAINT','TRIGGER'); `ck_tdm_mask_dep_desh` CHECK (deshabilitado_ok IN ('Y','N'); `ck_tdm_mask_dep_hab` CHECK (habilitado_ok IN ('Y','N')

**tdm_mask_regla_esp**

Por que existe: Reglas especiales de tratamiento por tabla/columna.

- Escriben: ninguno (solo carga manual/script)
- Solo leen: `pkg_dm_mask_columna`

| Columna | Tipo | Por que existe |
|---|---|---|
| `regla_id` | NUMBER NOT NULL | Clave tecnica (seq_dm_mask_regla_esp). |
| `ora_esquema` | VARCHAR2(128) NOT NULL | Esquema de datos sobre el que se configura o ejecuta. |
| `ora_owner` | VARCHAR2(128) NOT NULL | Esquema propietario del objeto analizado (el esquema de datos, no el del motor). |
| `table_name` | VARCHAR2(128) NOT NULL | Tabla analizada. |
| `column_name` | VARCHAR2(128) NOT NULL | Columna analizada. |
| `tipo_regla` | VARCHAR2(50) NOT NULL | Tipo de regla especial: DOC_SEGUN_TIPO, DOC_UNIFICADO_MANTENER_1_Y_ULTIMO, IBAN_ES_CONTINUO, etc. |
| `valor_regla` | VARCHAR2(4000) | Valor libre o metadata de la regla especial. |
| `activa` | CHAR(1) DEFAULT 'Y' | Y/N: la fila solo se aplica si esta activa; permite apagar sin borrar. |
| `observacion` | VARCHAR2(4000) | Observación funcional o técnica asociada a la regla. |

Restricciones: `pk_tdm_mask_regla_esp` PRIMARY KEY (regla_id); `ck_tdm_mask_regla_act` CHECK (activa IN ('Y','N')

**tdm_mask_relacion_sync**

Por que existe: Relaciones de sincronización/coherencia entre tablas tras el masking.

- Escriben: ninguno (solo carga manual/script)
- Solo leen: `pkg_dm_mask_sync`

| Columna | Tipo | Por que existe |
|---|---|---|
| `sync_id` | NUMBER NOT NULL | Clave tecnica (seq_dm_mask_relacion_sync). |
| `ora_esquema` | VARCHAR2(128) NOT NULL | Esquema de datos sobre el que se configura o ejecuta. |
| `tabla_origen` | VARCHAR2(128) NOT NULL | Tabla desde la cual se copiará el valor coherente. |
| `columna_join_origen` | VARCHAR2(128) NOT NULL | Columna de unión en la tabla origen. |
| `tabla_destino` | VARCHAR2(128) NOT NULL | Tabla hacia la cual se propagará el valor coherente. |
| `columna_join_destino` | VARCHAR2(128) NOT NULL | Columna de unión en la tabla destino. |
| `columna_origen` | VARCHAR2(128) NOT NULL | Columna origen cuyo valor ya enmascarado se propagará. |
| `columna_destino` | VARCHAR2(128) NOT NULL | Columna destino que se sincronizará. |
| `activa` | CHAR(1) DEFAULT 'Y' | Y/N: la fila solo se aplica si esta activa; permite apagar sin borrar. |
| `prioridad` | NUMBER DEFAULT 1 | Prioridad de ejecución para la sincronización. |
| `observacion` | VARCHAR2(4000) | Observación funcional o técnica de la sincronización. |

Restricciones: `pk_tdm_mask_relacion_sync` PRIMARY KEY (sync_id); `ck_tdm_mask_sync_act` CHECK (activa IN ('Y','N')

**2. Indices**

Criterio de revision: cada indice se contrasta con las consultas reales del codigo (predicados `where`). Estado **Imprescindible** = sin el hay barrido completo en una ruta caliente; **Util** = acelera una consulta real; **Redundante** = ya cubierto por el prefijo de una PK/UK.

| Indice | Columnas | Consulta que sirve | Estado |
|---|---|---|---|
| `idm_ejecucion_01` sobre `tdm_ejecucion` | `(ora_esquema, fecha_inicio)` | Listar/ordenar corridas de un esquema; ultima corrida del esquema | Util |
| `idm_ejecucion_02` sobre `tdm_ejecucion` | `(fase_proceso, estado)` | Buscar corridas por fase y estado (monitor, reanudar, cancelar) | Util; tabla pequena |
| `ui_dm_ejec_activo` sobre `tdm_ejecucion` | `UNIQUE (CASE WHEN estado='EJECUTANDO' THEN ora_esquema END)` | Garantiza UNA sola corrida EJECUTANDO por esquema (control de concurrencia) | Imprescindible |
| `idm_ejec_error_01` sobre `tdm_ejecucion_error` | `(ejecucion_id, fecha_error)` | FK a tdm_ejecucion + listado cronologico de errores de una corrida | Util |
| `idm_ejec_error_02` sobre `tdm_ejecucion_error` | `(etapa, codigo_error)` | Estadistica de errores por etapa/codigo | Poco usado; tabla pequena |
| `idm_ejec_scope_01` sobre `tdm_ejecucion_scope` | `(ejecucion_id, ora_owner, table_name, column_name)` | FK + filtro de alcance (descubrimiento por tablas) | Util |
| `idm_objeto_ctrl_01` sobre `tdm_objeto_ctrl` | `(ora_owner, estado_objeto)` | Tablas PENDIENTE de un esquema (cola de trabajo del descubrimiento) | Util |
| `idm_regla_01` sobre `tdm_regla` | `(activa, tipo_regla, identificador, prioridad)` | Lectura de reglas activas por tipo/identificador ordenadas por prioridad | Util; 109 filas |
| `idm_col_hist_01` sobre `tdm_columna_hist` | `(ora_owner, table_name, estado_final, identificador)` | Consulta de resultado por tabla | Util |
| `idm_col_hist_02` sobre `tdm_columna_hist` | `(ejecucion_id, enmascarar)` | Sincronizar el catalogo final (columnas Y de una corrida) | Util |
| `idm_dep_hist_01` sobre `tdm_dependencia_hist` | `(ejecucion_id, ora_owner, table_name, column_name)` | FK + dependencias de una columna en una corrida | Util |
| `idm_col_final_01` sobre `tdm_columna_final` | `(enmascarar, identificador)` | Resumen por identificador (informes) | Candidato a retirar: ninguna consulta del motor filtra sin ora_owner |
| `idm_col_final_02` sobre `tdm_columna_final` | `(ora_owner, enmascarar, table_name, column_name)` | Bucle de masking: columnas Y del esquema ordenadas por tabla | Imprescindible (cubre el acceso caliente) |
| `idm_dep_final_01` sobre `tdm_dependencia_final` | `(ora_owner, table_name, column_name)` | Dependencias de una columna | REDUNDANTE: es prefijo de la PK |
| `idm_dep_final_02` sobre `tdm_dependencia_final` | `(ora_owner, tipo_dependencia, dependencia_owner, dependencia_objeto)` | Busqueda inversa por objeto dependiente | Verificar uso real antes de mantener |
| `idm_exc_col_01` sobre `tdm_excepcion_col` | `(activa, accion)` | Lectura de excepciones activas por accion | Marginal; tabla pequena |
| `idm_mask_sol_01` sobre `tdm_mask_solicitud` | `(ejecucion_id, estado)` | FK + solicitud abierta de una corrida | Util |
| `idm_mask_sol_02` sobre `tdm_mask_solicitud` | `(ora_esquema, fecha_inicio)` | Ultimas solicitudes de un esquema | Util |
| `idm_mask_trace_01` sobre `tdm_mask_trace` | `(ejecucion_id, fase, paso, fecha_evento)` | FK + lectura de pasos APPLY_COL/SKIP_* de una corrida (punto de control de reanudacion) | Imprescindible |
| `idm_mask_trace_02` sobre `tdm_mask_trace` | `(solicitud_id, fase, paso, fecha_evento)` | FK + trazas por solicitud | Util |
| `idm_mask_dep_01` sobre `tdm_mask_dep_estado` | `(solicitud_id, tipo_objeto, ora_owner)` | Dependencias deshabilitadas de una solicitud | REDUNDANTE: prefijo de la PK; mejor (solicitud_id, tipo_objeto, ora_owner, objeto_name) |
| `idm_mask_regla_01` sobre `tdm_mask_regla_esp` | `(ora_esquema, ora_owner, table_name, column_name, activa)` | Regla especial de una columna (consulta por columna en masking) | Imprescindible |
| `idm_mask_sync_01` sobre `tdm_mask_relacion_sync` | `(ora_esquema, tabla_origen, tabla_destino, activa)` | Relaciones de sincronizacion del esquema | Util |

Las claves primarias y unicas generan su propio indice implicito (no listado arriba).

**3. Secuencias**

| Secuencia | Alimenta | Quien la usa | Cache |
|---|---|---|---|
| `seq_dm_ejecucion` | `tdm_ejecucion.ejecucion_id` | pkg_dm_descubrimiento / pkg_dm_enmascarar | NOCACHE |
| `seq_dm_ejecucion_scope` | `tdm_ejecucion_scope.scope_id` | pkg_dm_descubrimiento | NOCACHE |
| `seq_dm_regla` | `tdm_regla.regla_id` | 03_dm_descubrimiento_carga_reglas.sql (INSERT de reglas) | NOCACHE |
| `seq_dm_columna_hist` | `tdm_columna_hist.hist_id` | pkg_dm_descubrimiento | NOCACHE |
| `seq_dm_dependencia_hist` | `tdm_dependencia_hist.dependencia_id` | pkg_dm_desc_catalogo | NOCACHE |
| `seq_dm_mask_solicitud` | `tdm_mask_solicitud.solicitud_id` | pkg_dm_mask_estado | NOCACHE |
| `seq_dm_mask_trace` | `tdm_mask_trace.trace_id` | pkg_dm_trazabilidad | NOCACHE |
| `seq_dm_mask_regla_esp` | `tdm_mask_regla_esp.regla_id` | Configuracion por cliente (p. ej. SIGAD/config_sigad.sql); NO es codigo muerto | NOCACHE |
| `seq_dm_mask_relacion_sync` | `tdm_mask_relacion_sync.sync_id` | Configuracion por cliente (config_sigad.sql); NO es codigo muerto | NOCACHE |


**4. Paquetes**

Todos usan derechos de definidor (sin `AUTHID`): el motor corre con los privilegios de su esquema y los usuarios solo necesitan `EXECUTE` sobre los 5 paquetes de fachada. Visibilidad: **P** = publico (en la especificacion), **I** = interno (solo en el cuerpo).

| Orden | Archivo | Paquete | Fase | Rol |
|---|---|---|---|---|
| 10 | `10_dm_pkg_trazabilidad.sql` | `pkg_dm_trazabilidad` | Transversal | Trazas, errores, ejecucion activa, heartbeat |
| 11 | `11_dm_pkg_sql_seguro.sql` | `pkg_dm_sql_seguro` | Base | Normalizacion y quoting seguro de identificadores |
| 12 | `12_dm_pkg_mask_ff1.sql` | `pkg_dm_mask_ff1` | Masking (motor FF1) | Primitivas FF1 (NIST SP 800-38G) y formatos de dato |
| 13 | `13_dm_pkg_dominios.sql` | `pkg_dm_dominios` | Descubrimiento | Dominios referenciales por FK (Union-Find) |
| 20 | `20_dm_pkg_desc_puntuacion.sql` | `pkg_dm_desc_puntuacion` | Descubrimiento | Motor de puntuacion por reglas y muestreo |
| 21 | `21_dm_pkg_desc_catalogo.sql` | `pkg_dm_desc_catalogo` | Descubrimiento | Publicar resultado: catalogo final, dependencias, excepciones |
| 22 | `22_dm_pkg_descubrimiento.sql` | `pkg_dm_descubrimiento` | Descubrimiento | Orquestador del descubrimiento |
| 30 | `30_dm_pkg_pepper.sql` | `pkg_dm_pepper` | Masking | Ciclo de vida del pepper efimero |
| 31 | `31_dm_pkg_mask_estado.sql` | `pkg_dm_mask_estado` | Masking | Solicitud y estado de la corrida de masking |
| 32 | `32_dm_pkg_mask_validacion.sql` | `pkg_dm_mask_validacion` | Masking | Validaciones previas y posteriores |
| 33 | `33_dm_pkg_mask_dependencias.sql` | `pkg_dm_mask_dependencias` | Masking | Desactivar/reactivar FK, constraints y triggers |
| 34 | `34_dm_pkg_mask_worker.sql` | `pkg_dm_mask_worker` | Masking | DBMS_PARALLEL_EXECUTE: chunks, tareas, reconciliar |
| 35 | `35_dm_pkg_mask_columna.sql` | `pkg_dm_mask_columna` | Masking | Aplicar el enmascaramiento a una columna |
| 36 | `36_dm_pkg_mask_sync.sql` | `pkg_dm_mask_sync` | Masking | Sincronizar columnas duplicadas entre tablas |
| 37 | `37_dm_pkg_enmascarar.sql` | `pkg_dm_enmascarar` | Masking (orquestador) | Orquestador del enmascaramiento |
| 40 | `40_dm_pkg_export.sql` | `pkg_dm_export` | Satelite | Exportacion CSV (satelite) |

**4.1 pkg_dm_trazabilidad** (10_dm_pkg_trazabilidad.sql)

Fase: Transversal. Trazas, errores, ejecucion activa, heartbeat. Subprogramas: 8 (7 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `proc_dm_trace` | P | Escribe un evento en la linea de tiempo TDM_MASK_TRACE (fase, paso, nivel del catalogo, detalle y duracion). El objeto afectado va dentro del detalle (ESQUEMA.TABLA.COLUMNA ...), no en columnas aparte. | TDM_PARAMETRO (via func_dm_nivel) | TDM_MASK_TRACE (INSERT) | pkg_dm_enmascarar (wrapper proc_dm_trace), pkg_dm_descubrimiento, pkg_dm_trazabilidad.proc_dm_log_ejec_error y dm_liberar_ejecucion_activa.s |
| `proc_dm_log_ejec_error` | P | Unico escritor de errores: registra un error con codigo, mensaje y backtrace en TDM_EJECUCION_ERROR y deja su linea ERROR.REGISTRADO en la traza, enlazada por error_id. | TDM_EJECUCION_ERROR (MAX(error_id)); USER_TABLES | TDM_EJECUCION_ERROR (INSERT); TDM_MASK_TRACE (via proc_dm_trace) | pkg_dm_enmascarar (wrapper) y pkg_dm_descubrimiento.proc_dm_log_error. |
| `func_dm_seg_desde` | P | Calcula los segundos (2 decimales) transcurridos desde un instante, para rellenar duracion_seg en la traza. | ninguno | ninguno | pkg_dm_enmascarar.proc_dm_apl_col y pkg_dm_descubrimiento.proc_dm_procesa_desc. |
| `proc_dm_refresca_sesion` | P | Captura la sesion Oracle (audsid, sid, serial#, instancia) que ejecuta la corrida y refresca su latido en TDM_EJECUCION. | V$SESSION | TDM_EJECUCION (UPDATE de sesion y heartbeat_ts) | proc_dm_enmascaramiento, proc_dm_reanudar y el descubrimiento al arrancar o reanudar. |
| `func_dm_sesion_viva` | P | Indica si la sesion que lanzo una corrida sigue viva en GV$SESSION. | TDM_EJECUCION; GV$SESSION | ninguno | proc_dm_gestiona_tareas, pkg_dm_descubrimiento.proc_dm_reanudar y los scripts de monitor/cancel/reanudar. |
| `proc_dm_autocancel_huerfanas` | P | Marca como ABORTADA las corridas EJECUTANDO cuya sesion ya no existe o lleva inactiva mas del limite sin latido, para liberar el bloqueo de ejecucion unica por esquema. | TDM_EJECUCION; GV$SESSION | TDM_EJECUCION (estado ABORTADA, fecha_fin, ultimo_paso) | pkg_dm_enmascarar.proc_dm_validar_concurrencia y la validacion de concurrencia del descubrimiento. |
| `proc_dm_log_error` | P | Registra un error del descubrimiento delegando en pkg_dm_trazabilidad sin poder abortar nunca al proceso que protege. | ninguno | TDM_EJECUCION_ERROR y TDM_MASK_TRACE (indirecto, via pkg_dm_trazabilidad.proc_dm_log_ejec_error, autonomous transaction) | func_dm_score_patron; proc_dm_recolecta_dep; proc_dm_aplica_excepcion; proc_dm_procesa_desc |
| `func_dm_nivel` | I | Devuelve el nivel (INFO, WARN, ERROR) de un evento de traza a partir del catalogo TDM_PARAMETRO (grupo EVENTO); si el par fase/paso no esta en el catalogo aplica la regla heredada. | TDM_PARAMETRO (una vez por sesion, cache en memoria) | ninguno | proc_dm_trace. |

**4.2 pkg_dm_sql_seguro** (11_dm_pkg_sql_seguro.sql)

Fase: Base. Normalizacion y quoting seguro de identificadores. Subprogramas: 5 (5 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `func_dm_norm` | P | Normaliza un texto a mayusculas y sin espacios laterales para comparar identificadores de forma uniforme. | ninguno | ninguno | Interno: helper usado por casi todas las unidades del paquete (csv_item, qname, expr_gen_sql, apl_col, mask_cat, enmascaramiento, gestiona_t |
| `func_dm_safe_err` | P | Aplana un mensaje de error (quita saltos de linea, lo acota a 1800 caracteres) para guardarlo en trazas y columnas de error. | ninguno | ninguno | Interno: proc_dm_enmascaramiento, proc_dm_enmascara_tabla, proc_dm_mask_cat, proc_dm_apl_col, proc_dm_post_sync, proc_dm_upd_ejec, proc_dm_c |
| `func_dm_safe_name` | P | Devuelve un nombre de objeto acotado a 256 caracteres (o ? si es nulo) para componer mensajes de traza sin romper longitudes. | ninguno | ninguno | Interno: proc_dm_pre_dep y proc_dm_post_dep (mensajes de traza). |
| `func_dm_qname` | P | Valida y entrecomilla un identificador SQL con DBMS_ASSERT para poder concatenarlo con seguridad en SQL dinamico. | ninguno | ninguno | Interno: proc_dm_apl_col, proc_dm_ejecuta_update_seguro, proc_dm_post_sync, proc_dm_pre_dep, proc_dm_post_dep, func_dm_expr_compatible. Otro |
| `func_dm_csv_item` | P | Extrae el elemento N de una lista separada por comas, normalizado, para iterar tablas y columnas pasadas como CSV. | ninguno | ninguno | Interno: proc_dm_enmascara_tabla (listas p_tabla y p_columna). |

**4.3 pkg_dm_mask_ff1** (12_dm_pkg_mask_ff1.sql)

Fase: Masking (motor FF1). Primitivas FF1 (NIST SP 800-38G) y formatos de dato. Subprogramas: 29 (14 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `func_dm_nombre` | P | Enmascara nombres y apellidos: produce un VARCHAR2 de la misma longitud con letras A-Z sinteticas, determinista por campana (semilla HMAC del texto en mayusculas), no biyectivo. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | 37_dm_pkg_enmascarar.sql-1411 (regla IDENTIFICADOR_PERSONAL/NOMBRE en SQL dinamico); func_dm_generico |
| `func_dm_direccion` | P | Enmascara direcciones: produce un VARCHAR2 sintetico del tipo 'Calle Mayor N 12, Madrid' elegido de listas fijas segun una semilla HMAC del texto; determinista por campana, no biyectivo ni conserva la forma original. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | 37_dm_pkg_enmascarar.sql (regla IDENTIFICADOR_DIRECCION); func_dm_generico |
| `func_dm_telefono` | P | Enmascara telefonos: produce un VARCHAR2 de 9 digitos que empieza por 6, 7, 8 o 9 derivado de una semilla HMAC de los digitos del original; determinista por campana, no biyectivo. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | 37_dm_pkg_enmascarar.sql (regla IDENTIFICADOR_TELEFONO); func_dm_generico |
| `func_dm_email` | P | Enmascara correos electronicos: produce un VARCHAR2 con 10 letras minusculas, un numero y dominio correo.com o correo.es, derivado de una semilla HMAC del correo en minusculas; determinista por campana, no biyectivo. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | 37_dm_pkg_enmascarar.sql (regla IDENTIFICADOR_EMAIL); func_dm_generico |
| `func_dm_nif` | P | Enmascara identificadores de persona o empresa (DNI, NIE, CIF y otros formatos): produce un VARCHAR2 con la misma estructura donde la parte numerica se cifra con FF1 y la letra o digito de control se recalcula; determinista por campana. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | 37_dm_pkg_enmascarar.sql (regla IDENTIFICADOR_IDENTIDAD); func_dm_generico; tests/pkg_dm_ff1_debug.sql |
| `func_dm_iban` | P | Enmascara IBAN: produce un VARCHAR2 'ES'+control+20 digitos, cifrando el BBAN con FF1 si el original es un IBAN espanol valido o generandolo por HMAC en otro caso; determinista por campana. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | 37_dm_pkg_enmascarar.sql (regla IDENTIFICADOR_BANCARIO, rama IBAN); func_dm_generico; tests/pkg_dm_ff1_debug.sql |
| `func_dm_cuenta` | P | Enmascara numeros de cuenta bancaria no IBAN: produce un VARCHAR2 de digitos (entre 4 y 20) cifrando con FF1 los digitos del original; determinista por campana. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | 37_dm_pkg_enmascarar.sql (regla IDENTIFICADOR_BANCARIO, rama no IBAN); func_dm_generico; tests/pkg_dm_ff1_debug.sql |
| `func_dm_obs` | P | Enmascara observaciones o texto libre sustituyendolo por una constante fija; produce VARCHAR2 y es determinista (no depende de la entrada ni del pepper). | ninguno | ninguno | 37_dm_pkg_enmascarar.sql (regla por defecto en SQL dinamico); func_dm_generico |
| `func_dm_generico` | P | Enruta un valor a la funcion de enmascarado adecuada segun un identificador semantico (exacto o por palabras clave) y devuelve su VARCHAR2 enmascarado; si no reconoce el identificador usa la constante de func_dm_obs. | tdm_secreto (indirecto, salvo en la rama func_dm_obs) | ninguno | 37_dm_pkg_enmascarar.sql (SQL dinamico de reglas con identificador generico, con SUBSTR a la longitud de la columna) |
| `func_dm_espec_doc_segun_tipo` | P | Enmascara un documento segun su tipo (1 = DNI, 3 = NIE, otro = pasaporte): produce un VARCHAR2 con la misma estructura que func_dm_nif, con parte numerica cifrada por FF1 y mismo ajuste IDENTIDAD; determinista por campana. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | 37_dm_pkg_enmascarar.sql (regla especial de documento por tipo, SQL dinamico); comentarios en 37_dm_pkg_enmascarar.sql, 309 |
| `func_dm_especial_doc_keep_ends` | P | Enmascara un documento conservando su primer y ultimo caracter: cifra con FF1 el interior si es numerico (>= 6 digitos) o genera un interior sintetico por semilla HMAC; produce VARCHAR2 en mayusculas, determinista por campana. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | 37_dm_pkg_enmascarar.sql (regla especial de documento, SQL dinamico) |
| `func_dm_especial_iban_continuo` | P | Enmascara un IBAN espanol en formato continuo: produce un VARCHAR2 de 24 caracteres 'ES'+control+BBAN, con 20 digitos tomados de la entrada cifrados con FF1; determinista por campana. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | 37_dm_pkg_enmascarar.sql (regla especial de IBAN continuo, SQL dinamico) |
| `proc_dm_set_ejecucion` | P | Fija en la sesion la campana (ejecucion_id) activa para que el pepper y la clave AES se lean de esa campana, invalidando las caches si cambia. | ninguno | ninguno | 37_dm_pkg_enmascarar.sql (coordinador, SQL dinamico de cada chunk/worker paralelo); tests/pkg_dm_ff1_debug.sql; los scripts dm_enmascara_can |
| `func_dm_ff1_cifrar_raw` | P | Implementa FF1.Encrypt (NIST SP 800-38G, radix 10, 10 rondas Feistel con AES-128 CBC-MAC) sobre una cadena de digitos con clave y ajuste explicitos; produce una cadena de digitos de igual longitud, determinista, para validar contra vectores NIST. | ninguno | ninguno | func_dm_ff1_cifra; tests/pkg_dm_ff1_test.sql (vectores NIST) y tests/pkg_dm_ff1_debug.sql |
| `func_dm_get_pepper` | I | Devuelve el pepper (secreto base) de la campana activa leyendolo de TDM_SECRETO y cacheandolo en la sesion; aborta si no existe. | tdm_secreto | ninguno | func_dm_clave_aes, func_dm_hash |
| `func_dm_clave_aes` | I | Deriva la clave AES-128 de FF1 (primeros 16 bytes de SHA-1 del pepper) y la cachea por sesion. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | func_dm_ff1_cifra |
| `func_dm_hash` | I | Genera una semilla numerica determinista de 56 bits (HMAC-SHA1 con el pepper como clave) para los dominios de texto y para los sustitutos de dominio pequeno. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | func_dm_digitos_min_dominio, func_dm_nombre, func_dm_direccion, func_dm_telefono, func_dm_email, func_dm_cifra_digitos_en_texto, func_dm_iba |
| `func_dm_num_hex` | I | Convierte un entero no negativo a su cadena hexadecimal big-endian de longitud fija (p_bytes bytes), como pide el formato de bloques de FF1. | ninguno | ninguno | func_dm_ff1_cifrar_raw |
| `func_dm_ajuste_dominio` | I | Calcula el ajuste (tweak) FF1 de 8 bytes a partir del nombre del dominio (SHA-1 de 'DOMINIO:'//identificador) para que un mismo dominio siempre cifre igual. | ninguno | ninguno | func_dm_nif, func_dm_cuenta, func_dm_iban, func_dm_especial_doc_keep_ends, func_dm_espec_doc_segun_tipo, func_dm_especial_iban_continuo; tes |
| `func_dm_ff1_cifra` | I | Wrapper de produccion de FF1: cifra una cadena de digitos con la clave AES derivada del pepper de la campana y el ajuste indicado. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | func_dm_fpe_num, func_dm_cifra_digitos_en_texto, func_dm_especial_doc_keep_ends, func_dm_especial_iban_continuo |
| `func_dm_digitos_min_dominio` | I | Genera un reemplazo numerico de n digitos (con ceros a la izquierda) via HMAC-SHA1 para dominios de 1 a 5 digitos, donde NIST prohibe usar FF1 (minimo radix^minlen >= 1.000.000). | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | func_dm_fpe_num, func_dm_cifra_digitos_en_texto, func_dm_especial_doc_keep_ends |
| `func_dm_fpe_num` | I | Cifra un numero dentro del rango [0, modulo) con FF1 y cycle-walking conservando la biyeccion; si el dominio tiene menos de 6 digitos usa el sustituto HMAC en lugar de FF1. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | func_dm_enmascara_nie, func_dm_nif, func_dm_cuenta, func_dm_iban, func_dm_espec_doc_segun_tipo |
| `func_dm_txt_seguro` | I | Limita un texto a 1000 caracteres (semantica de caracteres, no bytes) para evitar ORA-06502 por cortes de multibyte. | ninguno | ninguno | func_dm_mix_alpha, func_dm_nombre, func_dm_direccion, func_dm_email |
| `func_dm_mix_alpha` | I | Sustituye cada letra de un texto por una letra mayuscula A-Z generada por un generador congruencial a partir de una semilla, conservando longitud y caracteres no alfabeticos. | ninguno | ninguno | func_dm_nombre |
| `func_dm_letra_dni` | I | Calcula la letra de control oficial del DNI/NIE (resto modulo 23 sobre la tabla TRWAGMYFPDXBNJZSQVHLCKE). | ninguno | ninguno | func_dm_enmascara_nie, func_dm_nif, func_dm_espec_doc_segun_tipo; tests/pkg_dm_ff1_debug.sql replica la logica |
| `func_dm_cif_ctrl` | I | Calcula el digito o letra de control de un CIF segun la letra de tipo de organizacion y sus 7 digitos numericos. | ninguno | ninguno | func_dm_nif |
| `func_dm_enmascara_nie` | I | Enmascara el numero de un NIE con FF1 (dominio 10^7) y compone un NIE valido: prefijo X/Y/Z derivado del numero generado, 7 digitos y letra de control; determinista por campana. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | func_dm_nif, func_dm_espec_doc_segun_tipo |
| `func_dm_cifra_digitos_en_texto` | I | Enmascara documentos de formato libre (pasaporte, extranjero): cifra los digitos con FF1 conservando letras y separadores en su posicion, y si no hay digitos genera un texto alfanumerico sintetico de igual longitud; salida VARCHAR2 determinista por campana. | tdm_secreto (indirecto, via func_dm_get_pepper) | ninguno | func_dm_nif, func_dm_espec_doc_segun_tipo |
| `func_dm_iban_cc_es` | I | Calcula los 2 digitos de control (modulo 97) de un IBAN espanol a partir de su BBAN de 20 digitos. | ninguno | ninguno | func_dm_iban; tests/pkg_dm_ff1_debug.sql replica la logica |

**4.4 pkg_dm_dominios** (13_dm_pkg_dominios.sql)

Fase: Descubrimiento. Dominios referenciales por FK (Union-Find). Subprogramas: 4 (1 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `proc_dm_propaga_dominios` | P | Agrupa columnas conectadas por claves foraneas (Union-Find) y propaga a todo el grupo la marca enmascarar = Y, el identificador de mayor prioridad y un dominio comun en TDM_COLUMNA_FINAL. | TDM_COLUMNA_FINAL; DBA_CONSTRAINTS; DBA_CONS_COLUMNS | TDM_COLUMNA_FINAL (MERGE: enmascarar = Y, identificador, dominio); Indirecto: TDM_MASK_TRACE via pkg_dm_trazabilidad.pro | proc_dm_sync_col_final; pkg_dm_enmascarar en 37_dm_pkg_enmascarar.sql linea 3316 |
| `find_root` | I | Union-Find: raiz del grupo de columnas conectadas por FK. |  |  |  |
| `union_nodes` | I | Union-Find: une dos columnas en el mismo dominio referencial. |  |  |  |
| `f_rank_ident` | I | Prioridad entre identificadores cuando un dominio mezcla varios (menor numero = mas especifico). |  |  |  |

**4.5 pkg_dm_desc_puntuacion** (20_dm_pkg_desc_puntuacion.sql)

Fase: Descubrimiento. Motor de puntuacion por reglas y muestreo. Subprogramas: 15 (14 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `func_dm_es_nombre_candidato` | P | Indica si un nombre de columna corresponde a un alias de nombre de persona (NOMBRE, NOM, alias de negocio) para activar las compuertas de contexto personal. | ninguno | ninguno | proc_dm_procesa_desc (2 compuertas, lineas 2438 y 2488) |
| `func_dm_es_dni_nie_valido` | P | Valida un DNI o NIE espanol comprobando formato y letra de control (modulo 23). | ninguno | ninguno | func_dm_score_patron (muestreo de reglas DNI/NIE) |
| `func_dm_normaliza_sample` | P | Acota el tamano de muestra por columna al rango 10 a 500 filas (500 si es nulo). | ninguno | ninguno | func_dm_score_patron; func_dm_ratio_nombre_sem; proc_dm_descubrimiento_core; proc_dm_reanudar |
| `func_dm_score_texto` | P | Suma la puntuacion de las reglas activas de TDM_REGLA de un identificador y tipo (nombre, comentario o tabla) que coinciden con un texto. | TDM_REGLA | ninguno | func_dm_identificador_base; proc_dm_procesa_desc |
| `func_dm_identificador_base` | P | Elige el identificador con mayor puntuacion lexica (columna, comentario, tabla) como respaldo cuando ninguno tiene evidencia suficiente. | TDM_REGLA | ninguno | proc_dm_procesa_desc |
| `func_dm_tiene_evid_min` | P | Indica si un identificador tiene al menos una puntuacion positiva (nombre, comentario, tabla o patron) que justifique registrarlo. | ninguno | ninguno | proc_dm_procesa_desc |
| `func_dm_score_patron` | P | Calcula la puntuacion por patron de datos de una columna ejecutando reglas DATA_PATTERN sobre una muestra real de filas. | TDM_REGLA; Tabla de usuario muestreada (SELECT dinamico con DBMS_ASSERT.ENQUOTE_NAME) | Indirecto: TDM_EJECUCION_ERROR / TDM_MASK_TRACE via proc_dm_log_error | proc_dm_procesa_desc (2 llamadas: lineas 2312 y 2399) |
| `func_dm_null_ratio_muestra` | P | Calcula la proporcion de nulos de una columna sobre una muestra de filas y el numero de filas muestreadas. | Tabla de usuario muestreada (SELECT dinamico) | ninguno | proc_dm_procesa_desc |
| `func_dm_ratio_nombre_sem` | P | Mide que proporcion de la muestra parece nombre de persona (solo letras, sin digitos ni palabras de via) para confirmar columnas de nombre sin apellidos en la tabla. | Tabla de usuario muestreada (SELECT dinamico) | ninguno | proc_dm_procesa_desc |
| `proc_dm_clasifica` | P | Traduce un score total a estado final y marca de enmascarado (>=85 CONFIRMADO/Y, >=65 PROBABLE/Y, >=45 | ninguno | ninguno | proc_dm_procesa_desc |
| `func_dm_get_col_comment` | P | Obtiene el comentario de una columna del diccionario para usarlo como evidencia lexica. | DBA_COL_COMMENTS | ninguno | proc_dm_procesa_desc |
| `func_dm_tabla_tiene_filas` | P | Comprueba si una tabla tiene al menos una fila para omitir las vacias del analisis. | Tabla de usuario (SELECT dinamico con rownum = 1) | ninguno | proc_dm_procesa_desc |
| `func_dm_tiene_ctx_persona` | P | Cuenta columnas de la tabla que indican contexto de persona (apellidos, documento, email, telefono, domicilio). | DBA_TAB_COLUMNS | ninguno | proc_dm_procesa_desc |
| `func_dm_tiene_apellidos` | P | Cuenta columnas de apellidos (APE1, APE2, APELLIDO1/2, APELLIDOS y variantes con prefijo/sufijo) en la tabla. | DBA_TAB_COLUMNS | ninguno | proc_dm_procesa_desc |
| `func_dm_columna_con_datos` | I | Sondeo ROWNUM<=1: indica si la columna tiene algun dato antes de muestrearla (evita lecturas completas de columnas vacias). |  |  |  |

**4.6 pkg_dm_desc_catalogo** (21_dm_pkg_desc_catalogo.sql)

Fase: Descubrimiento. Publicar resultado: catalogo final, dependencias, excepciones. Subprogramas: 4 (4 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `proc_dm_recolecta_dep` | P | Registra en TDM_DEPENDENCIA_HIST las constraints (P/R/U/C) de la columna enmascarable y los triggers de su tabla. | DBA_CONS_COLUMNS; DBA_CONSTRAINTS; DBA_TRIGGERS | TDM_DEPENDENCIA_HIST (INSERT) | proc_dm_procesa_desc (solo para columnas con enmascarar = Y) |
| `proc_dm_aplica_excepcion` | P | Aplica la excepcion manual vigente (EXCLUDE o FORCE) de TDM_EXCEPCION_COL a una columna modificando identificador, score y marca. | TDM_EXCEPCION_COL | Indirecto: TDM_EJECUCION_ERROR / TDM_MASK_TRACE via proc_dm_log_error | proc_dm_procesa_desc (2 llamadas: lineas 2379 y 2420) |
| `proc_dm_sync_col_final` | P | Sincroniza TDM_COLUMNA_FINAL con lo descubierto en TDM_COLUMNA_HIST de la ejecucion, retira columnas obsoletas y propaga dominios por FK. | TDM_COLUMNA_HIST; TDM_EJECUCION; TDM_OBJETO_CTRL; DBA_TAB_COLUMNS; TDM_COLUMNA_FINAL | TDM_COLUMNA_FINAL (MERGE, DELETE e inserciones/updates via proc_dm_propaga_dominios); Indirecto: TDM_MASK_TRACE (FINAL_O | proc_dm_procesa_desc |
| `proc_dm_sync_dep_final` | P | Consolida TDM_DEPENDENCIA_HIST de la ejecucion en TDM_DEPENDENCIA_FINAL con la categoria de uso y las acciones pre y post enmascarado (DISABLE/ENABLE segun estado actual). | TDM_DEPENDENCIA_HIST; DBA_CONSTRAINTS; DBA_TRIGGERS | TDM_DEPENDENCIA_FINAL (MERGE) | proc_dm_procesa_desc |

**4.7 pkg_dm_descubrimiento** (22_dm_pkg_descubrimiento.sql)

Fase: Descubrimiento. Orquestador del descubrimiento. Subprogramas: 11 (5 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `proc_dm_descubrimiento` | P | API publica (sobrecarga) para descubrir el esquema completo con muestra fija de 500 filas y modo forzar_full explicito. | Ver proc_dm_descubrimiento_core | Ver proc_dm_descubrimiento_core | dm_descubre.sql linea 133 (invocacion con 'Y') |
| `proc_dm_descubrimiento_set` | P | API publica para descubrir solo una lista de tablas (modo por excepciones) sin escanear el esquema completo. | Ver proc_dm_descubrimiento_core | Ver proc_dm_descubrimiento_core | dm_descubre_set.sql linea 149 |
| `proc_dm_reanudar` | P | API publica para reanudar una ejecucion de descubrimiento interrumpida, tras comprobar que su sesion original ya no esta viva. | TDM_EJECUCION (FOR UPDATE); gv$session (indirecto, via pkg_dm_trazabilidad.func_dm_sesion_viva) | TDM_EJECUCION (estado, fecha_fin, ultimo_paso); Indirecto: lo que escribe proc_dm_procesa_desc y proc_dm_autocancel_huer | dm_descubre_reanudar.sql linea 215 |
| `proc_dm_cancelar` | P | API publica para cancelar una ejecucion de descubrimiento y eliminar su historico de columnas y dependencias. | ninguno | TDM_EJECUCION (UPDATE a CANCELADO si estaba EJECUTANDO/PAUSADO/ERROR/ABORTADA); TDM_DEPENDENCIA_HIST (DELETE); TDM_COLUM | externo/script (solo documentado en 00_guion_uso_datamasking.sql; ningun driver .sql la invoca) |
| `proc_dm_propaga_dominios` | P | Agrupa columnas unidas por FK y propaga enmascarar=Y, identificador y dominio a todo el grupo, para que padre e hijas se enmascaren igual. |  |  |  |
| `func_dm_conflicto_running` | I | Determina si existe una ejecucion EJECUTANDO que choque con el esquema (y opcionalmente las tablas) a descubrir. | TDM_EJECUCION; TDM_EJECUCION_SCOPE | Indirecto: pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(5,'Y') puede cancelar ejecuciones huerfanas en TDM_EJECUCION | proc_dm_descubrimiento_core (siempre con p_tablas_csv = null) |
| `proc_dm_registra_scope` | I | Registra en TDM_EJECUCION_SCOPE el alcance de la ejecucion: '*' para esquema completo o una fila por tabla de la lista CSV. | ninguno | TDM_EJECUCION_SCOPE (INSERT); Indirecto: TDM_EJECUCION via proc_dm_autocancel_huerfanas(15,'Y') | proc_dm_descubrimiento_core |
| `proc_dm_prepara_objetos` | I | Sincroniza TDM_OBJETO_CTRL con las tablas actuales del esquema dentro del alcance, marca PENDIENTE las nuevas o modificadas y fija los totales de la ejecucion. | DBA_OBJECTS; DBA_TABLES; DBA_TAB_COLUMNS; TDM_EJECUCION_SCOPE; TDM_OBJETO_CTRL | TDM_OBJETO_CTRL (UPDATE/INSERT); TDM_EJECUCION (tablas_total, columnas_total, ultimo_paso) | proc_dm_descubrimiento_core |
| `proc_dm_evalua_columna` | I | Evaluar UNA columna candidata del descubrimiento: puntuar contra cada identificador activo, elegir el mejor, aplicar excepciones FORCE/EXCLUDE y los ajustes de contexto, clasificar y guardar la fila en TDM_COLUMNA_HIST (y dependencias si Y). |  |  | proc_dm_procesa_desc (una vez por columna). |
| `proc_dm_procesa_desc` | I | Motor central del descubrimiento: recorre las tablas PENDIENTE, puntua cada columna candidata, clasifica, guarda el historico, sincroniza las tablas FINAL y cierra la ejecucion. | TDM_EJECUCION; TDM_OBJETO_CTRL; TDM_EJECUCION_SCOPE; TDM_REGLA; DBA_TAB_COLUMNS; DBA_COL_COMMENTS (via func_dm_get_col_c | TDM_EJECUCION (estado, progreso, heartbeat, fecha_fin); TDM_OBJETO_CTRL; TDM_COLUMNA_HIST (DELETE+INSERT); TDM_DEPENDENC | proc_dm_descubrimiento_core; proc_dm_reanudar |
| `proc_dm_descubrimiento_core` | I | Nucleo comun del descubrimiento: valida esquema y conflictos, crea la ejecucion, registra el alcance, prepara objetos y lanza el procesamiento. | DBA_USERS; TDM_EJECUCION; Indirecto: TDM_EJECUCION_SCOPE | TDM_EJECUCION (INSERT); Indirecto: TDM_EJECUCION_SCOPE, TDM_OBJETO_CTRL y todo lo que escribe proc_dm_procesa_desc | proc_dm_descubrimiento (ambas sobrecargas); proc_dm_descubrimiento_set |

**4.8 pkg_dm_pepper** (30_dm_pkg_pepper.sql)

Fase: Masking. Ciclo de vida del pepper efimero. Subprogramas: 2 (2 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `proc_dm_pepper_generar` | P | Crea (si no existe) la semilla efimera PEPPER_MASK:<ejecucion_id> con 256 bits aleatorios y fija la ejecucion activa para los workers y el coordinador. | TDM_SECRETO | TDM_SECRETO (INSERT + COMMIT); contexto de pkg_dm_mask_ff1.proc_dm_set_ejecucion | Interno: proc_dm_enmascaramiento (tras proc_dm_propaga_dominios) y proc_dm_enmascara_tabla. |
| `proc_dm_pepper_purgar` | P | Borra la semilla efimera de UNA ejecucion, con guarda de estado para no destruir un pepper que aun puede necesitarse. | TDM_EJECUCION | TDM_SECRETO (DELETE de la clave PEPPER_MASK:<id> + COMMIT) | Interno: proc_dm_enmascaramiento (autopurga al FINALIZAR, best-effort) y proc_dm_enmascara_tabla (con Y, en exito y en fallo). Externo: dm_p |

**4.9 pkg_dm_mask_estado** (31_dm_pkg_mask_estado.sql)

Fase: Masking. Solicitud y estado de la corrida de masking. Subprogramas: 6 (6 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `proc_dm_upd_sol` | P | Actualiza estado, fase, checkpoint y detalle de una solicitud de enmascarado, y opcionalmente la cierra con fecha_fin. | ninguno | TDM_MASK_SOLICITUD (UPDATE + COMMIT) | Interno: proc_dm_enmascaramiento, proc_dm_mask_cat, proc_dm_enmascara_tabla. |
| `proc_dm_upd_ejec` | P | Actualiza fase, estado, progreso, contadores, ultimo objeto y latido de la fila de TDM_EJECUCION, sin permitir resucitar una ejecucion ya cerrada. | ninguno | TDM_EJECUCION (UPDATE + COMMIT); TDM_MASK_TRACE (traza UPD_EJEC_BLOQUEADO / UPD_EJEC_FALLO via proc_dm_trace) | Interno: proc_dm_enmascaramiento, proc_dm_mask_cat, proc_dm_enmascara_tabla. |
| `proc_dm_close_sol_open` | P | Cierra como ERROR las solicitudes de la ejecucion que quedaron abiertas por un intento anterior, antes de abrir una nueva. | ninguno | TDM_MASK_SOLICITUD (UPDATE a ERROR/FIN/AUTO_CLOSE_REANUDAR + COMMIT) | Interno: proc_dm_enmascaramiento (al arrancar). |
| `proc_dm_chk_cancel` | P | Comprueba si se ha pedido cancelar la ejecucion y, en ese caso, aborta el flujo con un error de cancelacion cooperativa. | TDM_MASK_SOLICITUD; TDM_EJECUCION (cancel_requested) | ninguno | Interno: proc_dm_mask_cat (una vez por columna, antes de procesarla). |
| `func_dm_esquema` | P | Obtiene el esquema objetivo de una ejecucion, normalizado. | TDM_EJECUCION | ninguno | Interno: proc_dm_enmascaramiento. |
| `func_dm_crea_sol` | P | Crea una solicitud de enmascarado en estado EN_PROCESO con el numero de reintento siguiente para la ejecucion. | TDM_MASK_SOLICITUD; SEQ_DM_MASK_SOLICITUD | TDM_MASK_SOLICITUD (INSERT + COMMIT) | Interno: proc_dm_enmascaramiento y proc_dm_enmascara_tabla. |

**4.10 pkg_dm_mask_validacion** (32_dm_pkg_mask_validacion.sql)

Fase: Masking. Validaciones previas y posteriores. Subprogramas: 3 (3 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `proc_dm_validar_base` | P | Verifica que existen las tablas base del motor antes de empezar a enmascarar. | USER_TABLES | ninguno | Interno: proc_dm_enmascaramiento y proc_dm_enmascara_tabla. |
| `proc_dm_validar_concurrencia` | P | Impide arrancar un enmascarado si ya hay otra ejecucion ENMASCARAMIENTO en curso para la misma ejecucion_id o para el mismo esquema. | TDM_EJECUCION | TDM_EJECUCION (indirecto: pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas pasa a ABORTADA las EJECUTANDO huerfanas) | Interno: proc_dm_enmascaramiento y proc_dm_enmascara_tabla. |
| `proc_dm_validar_reingreso_mask` | P | Impide re-ejecutar un enmascarado sobre una ejecucion ya FINALIZADA salvo que se pida reproceso explicito. | TDM_MASK_SOLICITUD | ninguno | Interno: proc_dm_enmascaramiento. |

**4.11 pkg_dm_mask_dependencias** (33_dm_pkg_mask_dependencias.sql)

Fase: Masking. Desactivar/reactivar FK, constraints y triggers. Subprogramas: 6 (6 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `func_dm_dep_col_exists` | P | Comprueba (con cache en variables de paquete) si TDM_DEPENDENCIA_FINAL tiene las columnas opcionales de politica CATEGORIA_USO, ACCION_PRE_MASK y ACCION_POST_MASK. | DBA_TAB_COLUMNS | variables de paquete g_dep_has_* (cache) | Interno: proc_dm_dep_policy y func_dm_dep_post_action. |
| `proc_dm_dep_policy` | P | Determina la categoria de uso y las acciones pre y post enmascarado de una dependencia (FK, PK/UK, trigger u otra), con defaults por tipo y sobreescritura desde TDM_DEPENDENCIA_FINAL. | TDM_DEPENDENCIA_FINAL (SQL dinamico) | ninguno | Interno: proc_dm_pre_dep. |
| `func_dm_dep_post_action` | P | Devuelve la accion de rehabilitacion post enmascarado de una dependencia (por defecto ENABLE para trigger, ENABLE_VALIDATE para el resto). | TDM_DEPENDENCIA_FINAL (SQL dinamico) | ninguno | Interno: proc_dm_post_dep. |
| `proc_dm_pre_dep` | P | Deshabilita (DDL) las FK, claves y triggers definidos en TDM_DEPENDENCIA_FINAL y deja constancia en TDM_MASK_DEP_ESTADO para poder rehabilitarlos tras enmascarar. | DBA_CONSTRAINTS; DBA_TRIGGERS; TDM_COLUMNA_FINAL; TDM_DEPENDENCIA_FINAL | TDM_MASK_DEP_ESTADO (INSERT/UPDATE); DDL: ALTER TABLE ... DISABLE CONSTRAINT ... CASCADE; DDL: ALTER TRIGGER ... DISABLE | Interno: proc_dm_enmascaramiento (esquema completo) y proc_dm_enmascara_tabla (acotado a sus tablas). |
| `proc_dm_post_dep` | P | Rehabilita (DDL) los triggers y constraints que proc_dm_pre_dep dejo deshabilitados, segun la accion post configurada, y registra el resultado. | TDM_MASK_DEP_ESTADO; DBA_CONSTRAINTS; TDM_DEPENDENCIA_FINAL (via func_dm_dep_post_action) | TDM_MASK_DEP_ESTADO (UPDATE estado_posterior, habilitado_ok); DDL: ALTER TRIGGER ... ENABLE; DDL: ALTER TABLE ... ENABLE | Interno: proc_dm_enmascaramiento (flujo normal y manejador de error) y proc_dm_enmascara_tabla. |
| `proc_dm_post_check` | P | Tras rehabilitar dependencias, detecta objetos nuevos INVALID y constraints que no quedaron ENABLED. |  |  |  |

**4.12 pkg_dm_mask_worker** (34_dm_pkg_mask_worker.sql)

Fase: Masking. DBMS_PARALLEL_EXECUTE: chunks, tareas, reconciliar. Subprogramas: 8 (8 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `func_dm_nombre_tarea` | P | Nombre estable de la tarea DBMS_PARALLEL_EXECUTE: TDM_ + hash de esquema.tabla.columna (permite reconocer huerfanas). |  |  |  |
| `func_dm_chunk_sql` | P | Construye el SQL de cada chunk: fija la ejecucion (pepper) y aplica el UPDATE por rango de ROWID. |  |  |  |
| `func_dm_ejecucion_de_sql` | P | Lee de vuelta el id de ejecucion del texto SQL de una tarea; par inverso de func_dm_chunk_sql. |  |  |  |
| `func_dm_tabla_tiene_trig_upd` | P | Indica si una tabla tiene triggers de UPDATE habilitados, para forzar ejecucion en serie y evitar deadlocks GES en RAC. | DBA_TRIGGERS | ninguno | Interno: proc_dm_ejecuta_update_seguro (nivel de paralelismo) y proc_dm_gestiona_tareas (modo RECONCILIAR). |
| `proc_dm_ejecuta_update_seguro` | P | Ejecuta el UPDATE de enmascarado de una columna: directo si la tabla es pequena o IOT, y con DBMS_PARALLEL_EXECUTE por chunks si supera 100000 filas. | DBA_TABLES; DBA_TRIGGERS (via func_dm_tabla_tiene_trig_upd); USER_PARALLEL_EXECUTE_CHUNKS; DBA_SCHEDULER_JOB_CLASSES; ta | UPDATE sobre la tabla/columna objetivo (directo o por chunks de rowid); DBMS_PARALLEL_EXECUTE: CREATE_TASK, CREATE_CHUNK | Interno: proc_dm_apl_col y proc_dm_post_sync. |
| `proc_dm_gestiona_tareas` | P | Diagnostica, reconcilia o descarta las tareas DBMS_PARALLEL_EXECUTE (TDM_<hash>) que una ejecucion interrumpida dejo atras. | TDM_EJECUCION; TDM_MASK_SOLICITUD; TDM_COLUMNA_FINAL; TDM_EXCEPCION_COL; TDM_MASK_TRACE; USER_PARALLEL_EXECUTE_TASKS; US | DBMS_PARALLEL_EXECUTE: RESUME_TASK (reejecuta el UPDATE de los chunks pendientes sobre la tabla objetivo) y DROP_TASK; T | Externo/script: dm_enmascara_cancel.sql (DESCARTAR), dm_enmascara_reanudar.sql (RECONCILIAR), dm_monitor.sql (INFORMAR). |
| `func_dm_tareas_de_ejecucion` | P | Decir que tareas DBMS_PARALLEL_EXECUTE pertenecen a una ejecucion, con el mismo criterio que proc_dm_gestiona_tareas (id literal en el SQL del chunk). | USER_PARALLEL_EXECUTE_TASKS (esquema del motor: corre con derechos del definidor). |  | dm_enmascara_reanudar.sql (revision previa). |
| `proc_dm_preflight_tareas` | P | Antes de enmascarar, busca tareas huerfanas de columnas en alcance y aborta (ORA-20331) si podrian causar doble cifrado. |  |  |  |

**4.13 pkg_dm_mask_columna** (35_dm_pkg_mask_columna.sql)

Fase: Masking. Aplicar el enmascaramiento a una columna. Subprogramas: 11 (11 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `func_dm_tiene_regla` | P | Cuenta las reglas especiales activas de un tipo dado para una columna. | TDM_MASK_REGLA_ESP | ninguno | Interno: proc_dm_apl_col (DOC_SEGUN_TIPO, DOC_UNIFICADO_MANTENER_1_Y_ULTIMO, IBAN_ES_CONTINUO). |
| `func_dm_val_regla` | P | Devuelve el valor parametrico (valor_regla) de la regla especial activa de un tipo para una columna. | TDM_MASK_REGLA_ESP | ninguno | Interno: proc_dm_apl_col (regla DOC_SEGUN_TIPO: nombre de la columna que indica el tipo de documento). |
| `func_dm_expr_gen_sql` | P | Traduce un identificador de dato sensible a la expresion SQL de la funcion de enmascarado de pkg_dm_mask_ff1 que le corresponde. | ninguno | ninguno | Interno: func_dm_expr_compatible. |
| `func_dm_expr_compatible` | P | Construye la expresion de SET del UPDATE segun el tipo real de la columna, acotada a su longitud para evitar ORA-12899. | DBA_TAB_COLUMNS | ninguno | Interno: proc_dm_apl_col (rama sin regla especial). |
| `func_dm_min_len_identificador` | P | Devuelve la longitud minima de columna necesaria para poder enmascarar un tipo de identificador. | ninguno | ninguno | Interno: proc_dm_apl_col. |
| `proc_dm_upsert_excepcion_col` | P | Crea o actualiza una excepcion EXCLUDE/FORCE activa para una columna en TDM_EXCEPCION_COL. | ninguno | TDM_EXCEPCION_COL (MERGE + COMMIT) | Interno: proc_dm_apl_col (auto-exclusiones). |
| `proc_dm_get_excepcion` | P | Lee la excepcion activa (accion e identificador forzado) de una columna. | TDM_EXCEPCION_COL | ninguno | Interno: proc_dm_apl_col. |
| `proc_dm_apl_col` | P | Enmascara una columna: resuelve excepcion y longitud minima, elige regla especial o expresion por identificador, ejecuta el UPDATE y anota APPLY_COL como punto de control. | TDM_EXCEPCION_COL; TDM_COLUMNA_HIST; DBA_TAB_COLUMNS; TDM_MASK_REGLA_ESP (via func_dm_tiene_regla / func_dm_val_regla) | UPDATE de la columna objetivo (via proc_dm_ejecuta_update_seguro); TDM_EXCEPCION_COL (MERGE de auto-exclusion); TDM_COLU | Interno: proc_dm_mask_cat (flujo de esquema) y proc_dm_enmascara_tabla (modo por tabla). |
| `proc_dm_cuenta_pendientes` | P | Cuenta columnas pendientes de enmascarar para progreso y reanudacion. |  |  |  |
| `proc_dm_traza_tablas_omitidas` | P | Deja una sola traza con las tablas sin filas que el descubrimiento no analizo. |  |  |  |
| `proc_dm_mask_una_col` | P | Enmascara una columna completa: resuelve excepcion, regla especial, expresion FF1, longitud y ruta UPDATE/CHUNKS; traza APPLY_COL. |  |  |  |

**4.14 pkg_dm_mask_sync** (36_dm_pkg_mask_sync.sql)

Fase: Masking. Sincronizar columnas duplicadas entre tablas. Subprogramas: 1 (1 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `proc_dm_post_sync` | P | Propaga el valor ya enmascarado de columnas origen a columnas destino segun TDM_MASK_RELACION_SYNC y verifica que quedan iguales. | TDM_MASK_RELACION_SYNC; DBA_TAB_COLUMNS; tablas origen y destino del esquema (SELECT dinamico de verificacion) | UPDATE de la columna destino (via proc_dm_ejecuta_update_seguro); TDM_MASK_TRACE (SYNC, SYNC_OK, SYNC_MISMATCH, WARN_SYN | Interno: proc_dm_enmascaramiento y proc_dm_enmascara_tabla. |

**4.15 pkg_dm_enmascarar** (37_dm_pkg_enmascarar.sql)

Fase: Masking (orquestador). Orquestador del enmascaramiento. Subprogramas: 10 (8 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `func_dm_norm` | P | ZOMBIE: duplicado publico sin llamadores; la version viva es pkg_dm_sql_seguro.func_dm_norm. |  |  |  |
| `proc_dm_enmascaramiento` | P | Entrada publica del enmascaramiento: envuelve al nucleo para arranque y reanudacion. |  |  |  |
| `proc_dm_cancelar` | P | Solicita la cancelacion cooperativa de una ejecucion en curso marcando cancel_requested y avisando al operador del resultado. | TDM_MASK_SOLICITUD | TDM_EJECUCION (cancel_requested = Y); TDM_MASK_SOLICITUD (detalle); COMMIT; DBMS_OUTPUT | Externo/script: dm_enmascara_cancel.sql (y guion de uso 00_guion_uso_datamasking.sql). |
| `proc_dm_gestiona_tareas` | P | Operacion sobre tareas interrumpidas: INFORMAR, RECONCILIAR (reanudar de forma segura) o DESCARTAR. |  |  |  |
| `func_dm_tareas_de_ejecucion` | P | Lista las tareas DBMS_PARALLEL_EXECUTE que pertenecen a una ejecucion (lee USER_PARALLEL_EXECUTE_TASKS con derechos de definidor). |  |  |  |
| `proc_dm_reanudar` | P | Reanuda un enmascarado interrumpido sobre la misma ejecucion_id, tras verificar fase correcta y sesion original muerta, saltando las columnas ya confirmadas. | TDM_EJECUCION (SELECT FOR UPDATE); TDM_MASK_SOLICITUD; GV$SESSION (via pkg_dm_trazabilidad.func_dm_sesion_viva) | nada propio; pasa la solicitud previa como parametro al nucleo (R15, ya no hay variable de paquete); todo lo que escribe | Externo/script: dm_enmascara_reanudar.sql. |
| `proc_dm_enmascara_tabla` | P | Enmascara de forma selectiva una o varias tablas (o columnas) con un identificador dado, creando una ejecucion ad hoc con su propio pepper efimero. | DBA_TAB_COLUMNS; TDM_EXCEPCION_COL; SEQ_DM_EJECUCION | TDM_EJECUCION (INSERT de ejecucion ad hoc y cambios de estado); TDM_MASK_SOLICITUD; TDM_SECRETO (alta y purga del pepper | externo/script (sin llamadas en los archivos del motor; solo mencionada en comentarios y descripciones de eventos). |
| `proc_dm_pepper_purgar` | P | Borra el pepper efimero de una ejecucion (autopurga al FINALIZAR; exige confirmacion si la corrida no termino). |  |  |  |
| `proc_dm_mask_cat` | I | Recorre las columnas pendientes (clasificadas Y mas FORCE vivos, menos EXCLUDE y las ya confirmadas) llamando a proc_dm_apl_col y actualizando el progreso. | TDM_COLUMNA_FINAL; TDM_EXCEPCION_COL; DBA_TAB_COLUMNS; TDM_MASK_TRACE (APPLY_COL* para saltar columnas ya hechas) | TDM_MASK_SOLICITUD (contadores y ultima tabla/columna); TDM_EJECUCION (heartbeat_ts y, via proc_dm_upd_ejec, progreso y  | Interno: proc_dm_enmascaramiento. |
| `proc_dm_enmascaramiento_core` | I | Nucleo: pepper, propagacion de dominios, preflight, desactivar dependencias, bucle de columnas, sync, reactivar, resumen y cierre. |  |  |  |

**4.16 pkg_dm_export** (40_dm_pkg_export.sql)

Fase: Satelite. Exportacion CSV (satelite). Subprogramas: 1 (1 publicos).

| Subprograma | Vis. | Para que existe | Lee | Escribe | Llamado desde |
|---|---|---|---|---|---|
| `proc_dm_export_mask` | P | Exporta a CSV las columnas enmascaradas de una corrida FINALIZADA. |  |  |  |

**5. Scripts de operacion**

| Script | Quien lo corre | Para que existe | Enlaza con |
|---|---|---|---|
| `99_install_datamasking.sql` | DBA | Instala todo: esquema del motor, rol, objetos 01/02, paquetes 10-40, reglas 03, grants y verificacion final | 01, 02, 03, 10-40 |
| `98_uninstall.sql` | DBA | Desinstala todo en orden de dependencia y informa si queda algo | Simetrico de 99 |
| `00_guion_uso_datamasking.sql` | Cualquiera | Guia de uso (no ejecuta nada) | Todos los dm_* |
| `dm_descubre.sql` | DBA/rol | Descubre un esquema completo | pkg_dm_descubrimiento |
| `dm_descubre_set.sql` | DBA/rol | Descubre solo las tablas con excepciones activas (flujo de lista del cliente) | proc_dm_descubrimiento_set |
| `dm_descubre_reanudar.sql` | DBA/rol | Reanuda un descubrimiento interrumpido | pkg_dm_descubrimiento |
| `97_configurar_excepciones.sql` | DBA | Carga FORCE/EXCLUDE por cliente en tdm_excepcion_col (MERGE idempotente; detecta el esquema del motor) | tdm_excepcion_col |
| `03_dm_descubrimiento_carga_reglas.sql` | Instalador | INSERT de las 109 reglas de puntuacion (solo INSERT) | tdm_regla |
| `dm_enmascara.sql` | DBA/rol | Lanza el enmascaramiento de una ejecucion | pkg_dm_enmascarar |
| `dm_enmascara_id.sql` | DBA/rol | Enmascara por identificador | pkg_dm_enmascarar |
| `dm_enmascara_reanudar.sql` | DBA/rol | Reanuda de forma segura (reconcilia tareas paralelas) | pkg_dm_mask_worker |
| `dm_enmascara_cancel.sql` | DBA/rol | Cancela y verifica que no queden jobs vivos | pkg_dm_mask_worker, tdm_ejecucion |
| `dm_monitor.sql` | DBA/rol | Monitor de solo lectura de una corrida en curso (descubrimiento o enmascaramiento) | tdm_ejecucion, tdm_mask_trace, tareas paralelas |
| `dm_validar_flujo.sql` | DBA/rol | KPIs de validacion posterior | tdm_columna_final, tdm_mask_trace |
| `dm_exportcsv.sql` | DBA/rol | Exporta CSV | pkg_dm_export |
| `dm_reset_ejecuciones.sql` | DBA | Limpia ejecuciones (a revisar en la purga: el usuario indica que no le sirve) | tdm_* |
| `dm_creasyn.sql` | DBA | Crea sinonimos privados para un usuario | Objetos del motor |
| `dm_tabref.sql` | DBA/rol | Muestra las referencias (FK) de una columna frente al catalogo de enmascarado, para revisar integridad | tdm_columna_final, diccionario |

**6. Mapa de enlaces entre procesos**

Lectura de arriba a abajo: cada flecha textual indica que el paquete de la izquierda invoca al de la derecha.

| Proceso | Cadena de paquetes |
|---|---|
| Descubrimiento | dm_descubre.sql -> pkg_dm_descubrimiento -> pkg_dm_desc_puntuacion (reglas y muestreo) -> pkg_dm_desc_catalogo (excepciones, dependencias, catalogo final) -> pkg_dm_dominios (dominios FK) ; todos trazan con pkg_dm_trazabilidad y escriben tdm_columna_hist / tdm_columna_final |
| Enmascaramiento | dm_enmascara.sql -> pkg_dm_enmascarar (orquestador) -> pkg_dm_pepper (semilla) -> pkg_dm_mask_validacion -> pkg_dm_mask_dependencias (desactivar) -> pkg_dm_mask_columna -> pkg_dm_mask_worker (DBMS_PARALLEL_EXECUTE) -> pkg_dm_mask_ff1 (FF1) -> pkg_dm_mask_sync -> pkg_dm_mask_dependencias (reactivar) -> pkg_dm_mask_estado (cierre) |
| Reanudacion / cancelacion | dm_enmascara_reanudar.sql y dm_enmascara_cancel.sql -> pkg_dm_mask_worker.proc_dm_gestiona_tareas / func_dm_tareas_de_ejecucion -> tdm_ejecucion |
| Exportacion | dm_exportcsv.sql -> pkg_dm_export -> tdm_columna_final / tdm_columna_hist |
| Transversal | pkg_dm_trazabilidad (trazas, errores, heartbeat, ejecucion activa) y pkg_dm_sql_seguro (quoting y normalizacion) los usan todos los paquetes |

**7. Hallazgos de documentacion detectados al catalogar**

| Hallazgo | Detalle | Accion sugerida |
|---|---|---|
| Referencias a scripts que ya no existen | `dm_liberar_ejecucion_activa.sql` (citado en 99, 10, 22 y 37), `dm_pepper_purgar.sql` (citado en 30), `dm_proteger_auditoria.sql` (citado en dm_reset_ejecuciones) | Decidir: restaurar el script o corregir el comentario. Hoy un DBA que lea el instalador buscara un script inexistente |
| Referencias en el MANIFEST a `dm_enmascara_force`, `dm_recompilar`, `dm_medir_ejecucion`, `dm_descubre_tablas`, `crear_sinonimos` | No estan en la carpeta | Depurar el MANIFEST en la fase de purga |
| Columna `tdm_columna_hist.vigente` sin uso real | Nadie la escribe en N | Retirar o implementar |
| 20 subprogramas sin bloque `[DOC]` propio (descritos aqui desde su codigo) | Ver tablas del apartado 4 | Completar `[DOC]` en la fase de documentacion |
| 77 columnas sin `COMMENT ON COLUMN` (descritas aqui por su nombre y uso) | Sobre todo identificadores, fechas y marcas Y/N | Añadir los comentarios al DDL en la fase de documentacion |
| Comentario con numero de linea fijo en `pkg_dm_dominios` ("linea 3316" de 37) | Queda obsoleto con cada cambio | Sustituir por el nombre del subprograma |
| Pruebas en `tests/` con el nombre antiguo `pkg_dm_func_mask` | El paquete hoy se llama `pkg_dm_mask_ff1` | Actualizar o archivar en la purga |

**Referencias**

**Notas relacionadas**

- [[documentacion_performance_datamasking]]
- [[analisis_brechas_industrializacion_2026-10-10]]
- [[mapa_paquetes_motor_modular_2026-10-10]]
- [[mapa_tecnico_jerarquico_motor_2026-09-28]]
