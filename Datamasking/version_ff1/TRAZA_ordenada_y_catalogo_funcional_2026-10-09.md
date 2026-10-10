# Traza ordenada, limpieza de duplicidad y catalogo funcional del motor

Fecha: 2026-10-09, revisado 2026-10-10 (traza sin columnas de objeto y descubrimiento reducido a resumen; ver secciones 2 y 4). Cambios aplicados en `01`, `02`, `03b`, `04`, `05`, `99_install` y `dm_liberar_ejecucion_activa.sql`; sin migracion (se reinstala). Verificado solo de forma estatica (revision de cada diferencia, balance de parentesis, coherencia del catalogo contra el codigo); **no se ha compilado ni ejecutado en una base Oracle**: la primera compilacion real es el primer paso de la campana de pruebas.

## 1. Una pregunta, una tabla

| Tabla | Pregunta que responde | Quien la escribe | Quien la lee |
|---|---|---|---|
| `TDM_EJECUCION` | Que corrida es y en que estado esta ahora (estado, progreso, latido, sesion Oracle, solicitud de cancelacion) | descubrimiento y enmascarado | monitor, cancel, reanudar, autocancelacion |
| `TDM_MASK_SOLICITUD` | Que intentos de enmascarar hubo dentro de la corrida y como termino cada uno | enmascarado | monitor, validador, export |
| `TDM_MASK_TRACE` | Que paso, en que orden y cuanto tardo (linea de tiempo) | `pkg_dm_trazabilidad.proc_dm_trace` | operador, auditoria; la reanudacion lee los `APPLY_COL` |
| `TDM_EJECUCION_ERROR` | Que fallo exactamente y por que (codigo, mensaje, backtrace) | `pkg_dm_trazabilidad.proc_dm_log_ejec_error` (unico escritor) | operador, `dm_validar_flujo` |
| `TDM_PARAMETRO` | Que catalogos y valores usa el motor sin recompilar (hoy: catalogo de eventos de la traza) | instalacion / operador | `proc_dm_trace` |

## 2. Que cambio

**Duplicidad eliminada**

- `TDM_MASK_SOLICITUD` pierde `cancel_requested`, `fecha_cancelacion`, `heartbeat_ts`, `sesion_sid`, `sesion_serial`: eran copias de `TDM_EJECUCION`. La cancelacion cooperativa (`proc_dm_cancelar`, `proc_dm_chk_cancel`) ahora lee y escribe solo `TDM_EJECUCION.cancel_requested`; el latido de una columna fallida tambien se refresca en `TDM_EJECUCION`.
- Un solo escritor de errores: `pkg_dm_descubrimiento.proc_dm_log_error` ya no inserta por su cuenta, delega en `pkg_dm_trazabilidad.proc_dm_log_ejec_error` (con el mismo reintento ante colision de `error_id`).
- Se retiran trazas de texto libre que repetian un error ya registrado: `ERROR_COL`, `ERROR_CAT`, `ERROR_SYNC`, `ERROR/ERROR` (x2), `WARN_DEP`, `WARN_TRIGGER`, `WARN_CONSTRAINT`. Su lugar lo ocupa una unica linea `ERROR.REGISTRADO` por error, cuyo detalle empieza por `error_id=N` (la clave en `TDM_EJECUCION_ERROR`); el objeto que fallo esta en el mensaje del error y en las columnas de esa tabla.
- Se quita `ONLINE` de los 23 `CREATE INDEX` (solo Enterprise Edition): los indices se crean al instalar, sin trafico. El motor ya no exige Enterprise por este motivo.

**Traza con estructura**

- `TDM_MASK_TRACE` tiene 9 columnas: `trace_id`, `solicitud_id`, `ejecucion_id`, `nivel`, `fase`, `paso`, `detalle`, `fecha_evento` y `duracion_seg`. `fecha_evento` es de tipo `DATE` (al segundo; para verla como `DD-MM-YYYY HH24:MI:SS` usar `TO_CHAR`; los eventos del mismo segundo se ordenan por `trace_id`) y `duracion_seg` va en segundos con 2 decimales. El objeto afectado va dentro de `detalle`, siempre al inicio (`ESQUEMA.TABLA.COLUMNA ...`). Se probaron columnas aparte para propietario, tabla, columna, filas y `error_id` y se retiraron el 2026-10-10: ningun consumidor las leia (la reanudacion, el monitor, `dm_validar_flujo` y los resumenes leen solo `ejecucion_id`, `solicitud_id`, `nivel`, `fase`, `paso`, `detalle` y `fecha_evento`), repetian lo que ya dice el texto y cada una era un campo mas que mantener coherente. Tampoco hay indice por tabla/columna.
- El **nivel** ya no se deduce del texto de la fase: sale del catalogo `TDM_PARAMETRO` (grupo `EVENTO`, clave `FASE.PASO`). Las fases `WARN` y `ERROR` desaparecen como fase (pasan a `MASK`, `CONTROL` o `DESCUBRIMIENTO`). Un paso fuera de catalogo cae a la regla heredada y la consulta T-02 lo delata.
- Enmascarado: `COL_INICIO` (la columna empieza) y **una sola linea `APPLY_COL` por columna** con filas, ruta y duracion. Formato del detalle: `ESQUEMA.TABLA.COLUMNA filas=N ruta=UPDATE [max 100000 filas] - filas_estimadas=E` o `ESQUEMA.TABLA.COLUMNA filas=N ruta=CHUNKS [> 100k filas] - filas_estimadas=E, bloques_por_chunk=B, chunks=C, nivel_paralelismo=P`. El evento `RUTA` aparte se retiro el 2026-10-10 (llegaba al terminar la columna, con la hora de `APPLY_COL`, y duplicaba la linea). La reanudacion solo lee el prefijo `ESQUEMA.TABLA.COLUMNA filas=N`.
- **Fase inicial `ENMASCARAMIENTO`** (antes `INI`): `ENMASCARAMIENTO.INICIO` abre cada intento. Una reanudacion lo marca con `- REANUDACION desde solicitud_id=N` y deja ademas `ENMASCARAMIENTO.REANUDACION` (intento, columnas ya confirmadas y pendientes), ligado a la NUEVA solicitud. `TDM_EJECUCION` queda con `ultimo_paso = REANUDACION` y `detalle` con el mismo texto; `dm_monitor` muestra los intentos (seccion 1b).
- **Descubrimiento: solo un resumen.** Una linea `DESCUBRIMIENTO.RESUMEN` (`tablas=X columnas=Y enmascarar=Z`, con la duracion total) y, aparte y solo si ocurren: `TABLAS_OMITIDAS` (tablas sin filas, un conteo), `FINAL_OBSOLETAS`, y los avisos `FINAL_OBSOLETAS_ERR` y `PROPAGA_DOMINIOS_ERR`; los errores van a `TDM_EJECUCION_ERROR` con su `ERROR.REGISTRADO`. Se retiraron `INICIO`, `TABLA_INICIO`, `TABLA_FIN`, `TABLA_OMITIDA` (por tabla), `SYNC_FINAL` y `FIN`: con 27 tablas eran 56 de las 57 filas del descubrimiento y repetian lo que ya guardan `TDM_COLUMNA_HIST` y `TDM_DEPENDENCIA_HIST`. `tablas` cuenta las tablas con al menos una columna evaluada (igual que el resumen de `@dm_descubre`). La fase se llama `DESCUBRIMIENTO` (antes `DISCOVERY`), igual que `fase_proceso` de `TDM_EJECUCION`.
- **No se toco** el formato de `detalle` de `APPLY_COL` (`ESQUEMA.TABLA.COLUMNA filas=N`): es lo que lee la reanudacion como punto de control.

**Comentarios y cabeceras**

- Comentarios de tabla y de columna reescritos con la pregunta que responde cada tabla (`01`, `02`).
- Las 107 unidades de primer nivel de `03b`, `04`, `05` y `06` llevan una cabecera estandar `-- [DOC]` (proposito, entradas, lee, escribe, errores, llamado desde). Sin efecto funcional: solo comentarios.

## 3. Como aplicarlo

- **Instalacion nueva:** nada especial; `99_install_datamasking.sql` ya trae todo.
- **Base ya instalada:** no se migra. Mientras todo sea prueba, se desinstala (`98_uninstall.sql`) y se reinstala con `99_install_datamasking.sql`; por eso se retiro `dm_migra_traza.sql`. Las trazas y ejecuciones antiguas se pierden y los scripts `dm_*.sql` nuevos no funcionan contra tablas viejas (usan los nombres de columna nuevos).
- Comprobacion posterior: ningun objeto `INVALID` del esquema del motor.

### Nombres de columna (convencion)

Cambio acotado: solo se renombraron tres columnas (mas `fecha_mod` de `TDM_PARAMETRO`). `dependencia_owner`, `table_name`, `column_name` y los nombres de parametros y variables PL/SQL no cambian.

| Antes | Ahora | Que guarda |
|---|---|---|
| `ejecutado_por` | `ora_usuario` | Usuario de base de datos que lanzo la corrida (`USER`). |
| `esquema_objetivo` | `ora_esquema` | Esquema al que se aplica la corrida o la regla. |
| `owner_name` | `ora_owner` | Propietario (esquema) del objeto de la terna owner.tabla.columna. |
| `TDM_PARAMETRO.fecha_mod` | `fecha_modificacion` | Fecha de la ultima modificacion del parametro. |

`ora_usuario` y `ora_esquema` son columnas distintas en `TDM_EJECUCION` (quien lanza y sobre que esquema se actua), por eso no comparten nombre. Los parametros y variables PL/SQL (`p_owner_name`, `l_ejecutado_por`) conservan su nombre original.

## 4. Consultas de las pruebas de trazabilidad (T-01 a T-06)

Sustituir `:e` por el `ejecucion_id` de una corrida posterior a la migracion.

```sql
-- T-01: cada error tiene su linea de tiempo, y viceversa (esperado: 0 filas en las dos)
select e.error_id from tdm_ejecucion_error e
 where e.ejecucion_id = :e
   and not exists (select 1 from tdm_mask_trace t
                    where t.ejecucion_id = e.ejecucion_id and t.fase = 'ERROR' and t.paso = 'REGISTRADO'
                      and t.detalle like 'error_id=' || e.error_id || ' %');
select t.trace_id from tdm_mask_trace t
 where t.ejecucion_id = :e and t.fase = 'ERROR' and t.paso = 'REGISTRADO'
   and not exists (select 1 from tdm_ejecucion_error e
                    where e.ejecucion_id = t.ejecucion_id
                      and t.detalle like 'error_id=' || e.error_id || ' %');

-- T-02: pasos fuera del catalogo (esperado: 0 filas)
select t.fase, t.paso, count(*) n
  from tdm_mask_trace t
 where t.ejecucion_id = :e
   and not exists (select 1 from tdm_parametro p
                    where p.grupo = 'EVENTO' and p.clave = t.fase || '.' || t.paso)
 group by t.fase, t.paso;

-- T-03: historia de una tabla en el enmascarado (el objeto va al inicio del detalle).
-- Para la clasificacion y los errores de esa tabla: TDM_COLUMNA_HIST y TDM_EJECUCION_ERROR.
select t.trace_id, to_char(t.fecha_evento,'DD-MM-YYYY HH24:MI:SS') fecha, t.nivel, t.paso, t.duracion_seg, t.detalle
  from tdm_mask_trace t
 where t.ejecucion_id = :e and t.fase = 'MASK'
   and t.detalle like upper(:esquema) || '.' || upper(:tabla) || '.%'
 order by t.trace_id;

-- T-04: desde donde reanuda (columnas confirmadas por la traza = las que se saltan)
select regexp_substr(t.detalle, '^[^ ]+') columna,
       to_number(regexp_substr(t.detalle, 'filas=([0-9]+)', 1, 1, null, 1)) filas,
       t.duracion_seg
  from tdm_mask_trace t
 where t.ejecucion_id = :e and t.fase = 'MASK'
   and t.paso in ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
 order by t.trace_id;

-- T-05: toda columna Y tiene su tiempo medido (esperado: 0 filas)
select f.ora_owner || '.' || f.table_name || '.' || f.column_name columna
  from tdm_columna_final f
 where f.enmascarar = 'Y'
   and not exists (select 1 from tdm_mask_trace t
                    where t.ejecucion_id = :e and t.fase = 'MASK' and t.paso = 'APPLY_COL'
                      and t.duracion_seg is not null
                      and t.detalle like f.ora_owner || '.' || f.table_name || '.' || f.column_name || ' filas=%');

-- Resumen del descubrimiento y sus excepciones
select trace_id, to_char(fecha_evento,'DD-MM-YYYY HH24:MI:SS') fecha, nivel, paso, duracion_seg, detalle
  from tdm_mask_trace
 where ejecucion_id = :e and fase = 'DESCUBRIMIENTO'
 order by trace_id;

-- Linea de tiempo completa de una corrida, en orden
select trace_id, to_char(fecha_evento,'DD-MM-YYYY HH24:MI:SS') fecha, nivel, fase, paso,
       duracion_seg, substr(detalle,1,140) detalle
  from tdm_mask_trace where ejecucion_id = :e order by trace_id;

-- Rendimiento por columna (pilar S): filas por minuto de las columnas medidas
select regexp_substr(detalle, '^[^ ]+') columna,
       to_number(regexp_substr(detalle, 'filas=([0-9]+)', 1, 1, null, 1)) filas,
       duracion_seg,
       round(to_number(regexp_substr(detalle, 'filas=([0-9]+)', 1, 1, null, 1))
             / nullif(duracion_seg, 0) * 60) filas_por_min
  from tdm_mask_trace
 where ejecucion_id = :e and paso = 'APPLY_COL' and duracion_seg is not null
 order by duracion_seg desc;
```

T-06 (ningun valor original en las tablas de rastro) se comprueba en el oraculo `VERIFICAR` de la campana: ahi se dispone de la copia dorada para contrastar.

## 5. Catalogo de eventos de la traza (`TDM_PARAMETRO`, grupo `EVENTO`)

| Clave `FASE.PASO` | Nivel | Significa |
|---|---|---|
| `ENMASCARAMIENTO.INICIO` | INFO | Arranque de proc_dm_enmascaramiento: esquema objetivo; en una reanudacion añade - REANUDACION desde solicitud_id=N. |
| `ENMASCARAMIENTO.REANUDACION` | INFO | Reanudacion de una ejecucion interrumpida: intento, columnas ya confirmadas (se omiten) y pendientes. |
| `PRE.INICIO` | INFO | Comienza la desactivacion de dependencias (FK, triggers) de las tablas a enmascarar. |
| `PRE.FK_JERARQUIA` | INFO | Una FK hija->padre detectada en el alcance; documenta el orden de integridad antes de tocar nada. |
| `PRE.SKIP_DEP_POLICY` | INFO | Dependencia NO tocada porque su accion PRE (SOLO_INFORMATIVO/SIN_ACCION) lo indica; decision de politica, no fallo. |
| `PRE.SKIP_DEP_NOT_FOUND` | WARN | La dependencia del catalogo ya no existe en el diccionario; se omite. Revisar si el catalogo esta desactualizado. |
| `PRE.FIN` | INFO | Terminada la desactivacion de dependencias. |
| `PROPAGACION.PROPAGA_START` | INFO | Comienza el recalculo de dominios referenciales (FK) antes de enmascarar. |
| `PROPAGACION.PROPAGA_END` | INFO | Dominios FK propagados con exito. |
| `PROPAGACION.PROPAGA_ERR` | ERROR | Fallo propagando dominios FK; el enmascarado se aborta (sin propagacion valida no hay integridad). |
| `PROPAGACION.RI_REINCLUYE` | INFO | El descubrimiento re-incluyo una columna (Y) por integridad referencial de su dominio. |
| `MASK.PEPPER_START` | INFO | Comienza la generacion del pepper efimero de la campana. |
| `MASK.PEPPER_END` | INFO | Pepper efimero listo; los workers paralelos leen la misma clave. |
| `MASK.PEPPER_ERR` | ERROR | Fallo preparando el pepper; el enmascarado se aborta (sin pepper no se enmascara). |
| `MASK.PREFLIGHT_OK` | INFO | Pre-flight de tareas DBMS_PARALLEL_EXECUTE: ninguna huerfana bloquea. |
| `MASK.PREFLIGHT_INFO` | INFO | Tarea de otra corrida o fuera de alcance: se informa pero no bloquea. |
| `MASK.PREFLIGHT_ORFANA` | WARN | Tarea huerfana de una columna a enmascarar: bloquea hasta decidir (reanudar o descartar). |
| `MASK.PREFLIGHT_ABORT` | ERROR | Pre-flight aborta la corrida (ORA-20331) por tareas huerfanas; no se toco ningun dato. |
| `MASK.COL_INICIO` | INFO | Comienza el enmascarado de una columna (identificador y ruta elegidos). |
| `MASK.EXCEPTION_FORCE` | INFO | La columna usa el identificador forzado de TDM_EXCEPCION_COL. |
| `MASK.SKIP_EXCLUDE` | INFO | Columna omitida porque TDM_EXCEPCION_COL la excluye. |
| `MASK.SKIP_TABLE` | INFO | Tabla omitida: todas sus columnas estan excluidas. |
| `MASK.SKIP_TABLE_TABMODE` | INFO | Tabla omitida en el modo por tabla de proc_dm_enmascara_tabla. |
| `MASK.SKIP_AUTO_LEN` | WARN | Columna sensible SIN enmascarar: su longitud es menor que el minimo del identificador. |
| `MASK.SKIP_ORA00001` | WARN | Columna auto-excluida tras colision de unicidad (ORA-00001): queda SIN enmascarar y bloquea FINALIZADO. |
| `MASK.SKIP_ORA12899` | WARN | Columna auto-excluida tras ORA-12899 (valor mayor que la columna). |
| `MASK.SKIP_ORA06502` | WARN | Columna auto-excluida tras ORA-06502 sin fallback posible. |
| `MASK.APPLY_COL` | INFO | Columna ENMASCARADA y confirmada: una linea por columna con filas, ruta (UPDATE o CHUNKS) y duracion. PUNTO DE CONTROL de la reanudacion: una columna con APPLY_COL no se vuelve a enmascarar. |
| `MASK.APPLY_COL_SAFE_FALLBACK` | WARN | Columna enmascarada con la expresion de reserva tras ORA-06502; tambien es punto de control de reanudacion. |
| `MASK.APPLY_COL_COLLISION` | INFO | Reservado: columna confirmada por una ruta de colision (compatibilidad con trazas antiguas). |
| `MASK.TAREA_DESCARTADA` | WARN | Una tarea interrumpida se descarto con proc_dm_gestiona_tareas DESCARTAR. |
| `MASK.NOOP` | INFO | No habia columnas a enmascarar en esta corrida. |
| `MASK.RESUMEN` | INFO | Resumen del bucle de columnas: procesadas, fallidas, tablas y filas afectadas. |
| `POST_SYNC.SYNC` | INFO | Sincronizacion de una columna origen hacia su destino dependiente (filas). |
| `POST_SYNC.SYNC_OK` | INFO | Verificacion post-sincronizacion: sin diferencias. |
| `POST_SYNC.SYNC_MISMATCH` | WARN | Verificacion post-sincronizacion: quedan diferencias entre origen y destino. |
| `POST_SYNC.WARN_SYNC` | WARN | Fallo sincronizando un par origen-destino; se continua. |
| `POST_SYNC.WARN_SYNC_LEN` | WARN | Par origen-destino omitido por longitud insuficiente del destino. |
| `POST_SYNC.WARN_SYNC_CHECK` | WARN | Fallo al verificar un par sincronizado. |
| `POST.INICIO` | INFO | Comienza la rehabilitacion de dependencias. |
| `POST.SKIP_POST_POLICY` | INFO | Dependencia NO rehabilitada porque su accion POST (REVISAR/SIN_ACCION) exige revision manual. |
| `POST.POST_CHECK_INVALID` | WARN | Tras rehabilitar quedan objetos INVALID nuevos o constraints no ENABLED. |
| `POST.FIN` | INFO | Terminada la rehabilitacion de dependencias. |
| `FIN.OK` | INFO | Enmascaramiento finalizado sin errores. |
| `FIN.ERROR` | ERROR | Enmascaramiento terminado con errores (la corrida no queda FINALIZADA). |
| `FIN.PII_SIN_ENMASCARAR` | ERROR | Hay columnas sensibles auto-excluidas: no se permite FINALIZADO. |
| `FIN.PEPPER_PURGE_WARN` | WARN | Corrida FINALIZADA pero no se pudo autopurgar el pepper; purgar a mano. |
| `ERROR.REGISTRADO` | ERROR | Un error se registro en TDM_EJECUCION_ERROR; el detalle empieza por error_id=N para ubicarlo. |
| `CONTROL.UPD_EJEC_BLOQUEADO` | WARN | Un ping de progreso no se aplico: la ejecucion ya estaba cerrada (no se resucita). |
| `CONTROL.UPD_EJEC_FALLO` | ERROR | Fallo actualizando el progreso en TDM_EJECUCION. |
| `CONTROL.CLOSE_SOL_OPEN_FALLO` | ERROR | Fallo cerrando solicitudes abiertas de una corrida anterior. |
| `DESCUBRIMIENTO.TABLAS_OMITIDAS` | INFO | Tablas sin filas que no se analizaron (solo aparece si hay alguna). |
| `DESCUBRIMIENTO.FINAL_OBSOLETAS` | INFO | Se retiraron de TDM_COLUMNA_FINAL columnas que ya no cumplen el descubrimiento o ya no existen. |
| `DESCUBRIMIENTO.FINAL_OBSOLETAS_ERR` | WARN | Fallo retirando columnas obsoletas del catalogo final. |
| `DESCUBRIMIENTO.PROPAGA_DOMINIOS_ERR` | WARN | Fallo propagando dominios FK durante la sincronizacion del catalogo. |
| `DESCUBRIMIENTO.RESUMEN` | INFO | Resumen unico del descubrimiento: tablas con columnas evaluadas, columnas evaluadas y columnas a enmascarar (Y). |
| `ADMIN.LIBERADA_MANUAL_DBA` | WARN | Un DBA cerro a mano una ejecucion con dm_liberar_ejecucion_activa. |

El nivel de un paso se puede ajustar con un `UPDATE` sobre `TDM_PARAMETRO` (rige desde la sesion siguiente). La carga del catalogo no es parte del camino critico: si la tabla no existe, la traza sigue funcionando con la regla heredada.

## 6. Catalogo funcional de procedimientos y funciones

Resumen de una linea por unidad; la cabecera completa (entradas, tablas que lee y escribe, errores, quien la llama) esta dentro del propio paquete, justo encima de cada definicion (`-- [DOC]`).


### pkg_dm_trazabilidad (03b)

| Unidad | Visib. | Proposito | Escribe |
|---|---|---|---|
| `func_nivel` | privada | Devuelve el nivel (INFO, WARN, ERROR) de un evento de traza a partir del catalogo TDM_PARAMETRO (grupo EVENTO); si el par fase/paso no esta en el catalogo aplica la regla heredada. | ninguno |
| `func_dm_seg_desde` | publica | Calcula los segundos (2 decimales) transcurridos desde un instante, para rellenar duracion_seg en la traza. | ninguno |
| `proc_dm_trace` | publica | Escribe un evento en la linea de tiempo TDM_MASK_TRACE (fase, paso, nivel del catalogo, detalle y duracion). | TDM_MASK_TRACE (INSERT) |
| `proc_dm_log_ejec_error` | publica | Unico escritor de errores: registra un error con codigo, mensaje y backtrace en TDM_EJECUCION_ERROR y deja su linea ERROR.REGISTRADO en la traza, con error_id=N en el detalle. | TDM_EJECUCION_ERROR (INSERT); TDM_MASK_TRACE (via proc_dm_trace) |
| `proc_dm_refresca_sesion` | publica | Captura la sesion Oracle (audsid, sid, serial#, instancia) que ejecuta la corrida y refresca su latido en TDM_EJECUCION. | TDM_EJECUCION (UPDATE de sesion y heartbeat_ts) |
| `func_dm_sesion_viva` | publica | Indica si la sesion que lanzo una corrida sigue viva en GV$SESSION. | ninguno |
| `proc_dm_autocancel_huerfanas` | publica | Marca como ABORTADA las corridas EJECUTANDO cuya sesion ya no existe o lleva inactiva mas del limite sin latido, para liberar el bloqueo de ejecucion unica por esquema. | TDM_EJECUCION (estado ABORTADA, fecha_fin, ultimo_paso) |

### pkg_dm_descubrimiento (04)

| Unidad | Visib. | Proposito | Escribe |
|---|---|---|---|
| `func_dm_es_nombre_candidato` | privada | Indica si un nombre de columna corresponde a un alias de nombre de persona (NOMBRE, NOM, alias de negocio) para activar las compuertas de contexto personal. | ninguno |
| `func_dm_es_dni_nie_valido` | privada | Valida un DNI o NIE espanol comprobando formato y letra de control (modulo 23). | ninguno |
| `proc_dm_log_error` | privada | Registra un error del descubrimiento delegando en pkg_dm_trazabilidad sin poder abortar nunca al proceso que protege. | TDM_EJECUCION_ERROR y TDM_MASK_TRACE (indirecto, via pkg_dm_trazabilidad.proc_dm_log_ejec_error, autonomous... |
| `func_dm_normaliza_sample` | privada | Acota el tamano de muestra por columna al rango 10 a 500 filas (500 si es nulo). | ninguno |
| `func_dm_conflicto_running` | privada | Determina si existe una ejecucion EJECUTANDO que choque con el esquema (y opcionalmente las tablas) a descubrir. | Indirecto: pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(5,'Y') puede cancelar ejecuciones huerfanas en ... |
| `proc_dm_registra_scope` | privada | Registra en TDM_EJECUCION_SCOPE el alcance de la ejecucion: '*' para esquema completo o una fila por tabla de la lista CSV. | TDM_EJECUCION_SCOPE (INSERT); Indirecto: TDM_EJECUCION via proc_dm_autocancel_huerfanas(15,'Y') |
| `func_dm_score_texto` | privada | Suma la puntuacion de las reglas activas de TDM_REGLA de un identificador y tipo (nombre, comentario o tabla) que coinciden con un texto. | ninguno |
| `func_dm_identificador_base` | privada | Elige el identificador con mayor puntuacion lexica (columna, comentario, tabla) como respaldo cuando ninguno tiene evidencia suficiente. | ninguno |
| `func_dm_tiene_evid_min` | privada | Indica si un identificador tiene al menos una puntuacion positiva (nombre, comentario, tabla o patron) que justifique registrarlo. | ninguno |
| `func_dm_score_patron` | privada | Calcula la puntuacion por patron de datos de una columna ejecutando reglas DATA_PATTERN sobre una muestra real de filas. | Indirecto: TDM_EJECUCION_ERROR / TDM_MASK_TRACE via proc_dm_log_error |
| `func_dm_null_ratio_muestra` | privada | Calcula la proporcion de nulos de una columna sobre una muestra de filas y el numero de filas muestreadas. | ninguno |
| `func_dm_ratio_nombre_sem` | privada | Mide que proporcion de la muestra parece nombre de persona (solo letras, sin digitos ni palabras de via) para confirmar columnas de nombre sin apellidos en la tabla. | ninguno |
| `proc_dm_clasifica` | privada | Traduce un score total a estado final y marca de enmascarado (>=85 CONFIRMADO/Y, >=65 PROBABLE/Y, >=45 REVISAR/N, resto DESCARTADO/N). | ninguno |
| `func_dm_get_col_comment` | privada | Obtiene el comentario de una columna del diccionario para usarlo como evidencia lexica. | ninguno |
| `func_dm_tabla_tiene_filas` | privada | Comprueba si una tabla tiene al menos una fila para omitir las vacias del analisis. | ninguno |
| `func_dm_tiene_ctx_persona` | privada | Cuenta columnas de la tabla que indican contexto de persona (apellidos, documento, email, telefono, domicilio). | ninguno |
| `func_dm_tiene_apellidos` | privada | Cuenta columnas de apellidos (APE1, APE2, APELLIDO1/2, APELLIDOS y variantes con prefijo/sufijo) en la tabla. | ninguno |
| `proc_dm_recolecta_dep` | privada | Registra en TDM_DEPENDENCIA_HIST las constraints (P/R/U/C) de la columna enmascarable y los triggers de su tabla. | TDM_DEPENDENCIA_HIST (INSERT) |
| `proc_dm_aplica_excepcion` | privada | Aplica la excepcion manual vigente (EXCLUDE o FORCE) de TDM_EXCEPCION_COL a una columna modificando identificador, score y marca. | Indirecto: TDM_EJECUCION_ERROR / TDM_MASK_TRACE via proc_dm_log_error |
| `proc_dm_prepara_objetos` | privada | Sincroniza TDM_OBJETO_CTRL con las tablas actuales del esquema dentro del alcance, marca PENDIENTE las nuevas o modificadas y fija los totales de la ejecucion. | TDM_OBJETO_CTRL (UPDATE/INSERT); TDM_EJECUCION (tablas_total, columnas_total, ultimo_paso) |
| `proc_dm_propaga_dominios` | publica | Agrupa columnas conectadas por claves foraneas (Union-Find) y propaga a todo el grupo la marca enmascarar = Y, el identificador de mayor prioridad y un dominio comun en TDM_COLUMNA_FINAL. | TDM_COLUMNA_FINAL (MERGE: enmascarar = Y, identificador, dominio); Indirecto: TDM_MASK_TRACE via pkg_dm_tra... |
| `proc_dm_sync_col_final` | privada | Sincroniza TDM_COLUMNA_FINAL con lo descubierto en TDM_COLUMNA_HIST de la ejecucion, retira columnas obsoletas y propaga dominios por FK. | TDM_COLUMNA_FINAL (MERGE, DELETE e inserciones/updates via proc_dm_propaga_dominios); Indirecto: TDM_MASK_T... |
| `proc_dm_sync_dep_final` | privada | Consolida TDM_DEPENDENCIA_HIST de la ejecucion en TDM_DEPENDENCIA_FINAL con la categoria de uso y las acciones pre y post enmascarado (DISABLE/ENABLE segun estado actual). | TDM_DEPENDENCIA_FINAL (MERGE) |
| `proc_dm_procesa_desc` | privada | Motor central del descubrimiento: recorre las tablas PENDIENTE, puntua cada columna candidata, clasifica, guarda el historico, sincroniza las tablas FINAL y cierra la ejecucion. | TDM_EJECUCION (estado, progreso, heartbeat, fecha_fin); TDM_OBJETO_CTRL; TDM_COLUMNA_HIST (DELETE+INSERT); ... |
| `proc_dm_descubrimiento_core` | privada | Nucleo comun del descubrimiento: valida esquema y conflictos, crea la ejecucion, registra el alcance, prepara objetos y lanza el procesamiento. | TDM_EJECUCION (INSERT); Indirecto: TDM_EJECUCION_SCOPE, TDM_OBJETO_CTRL y todo lo que escribe proc_dm_proce... |
| `proc_dm_descubrimiento` | publica | API publica para descubrir el esquema completo con tamano de muestra y modo forzar_full configurables. | Ver proc_dm_descubrimiento_core |
| `proc_dm_descubrimiento` | publica | API publica (sobrecarga) para descubrir el esquema completo con muestra fija de 500 filas y modo forzar_full explicito. | Ver proc_dm_descubrimiento_core |
| `proc_dm_descubrimiento_set` | publica | API publica para descubrir solo una lista de tablas (modo por excepciones) sin escanear el esquema completo. | Ver proc_dm_descubrimiento_core |
| `proc_dm_reanudar` | publica | API publica para reanudar una ejecucion de descubrimiento interrumpida, tras comprobar que su sesion original ya no esta viva. | TDM_EJECUCION (estado, fecha_fin, ultimo_paso); Indirecto: lo que escribe proc_dm_procesa_desc y proc_dm_au... |
| `proc_dm_cancelar` | publica | API publica para cancelar una ejecucion de descubrimiento y eliminar su historico de columnas y dependencias. | TDM_EJECUCION (UPDATE a CANCELADO si estaba EJECUTANDO/PAUSADO/ERROR/ABORTADA); TDM_DEPENDENCIA_HIST (DELET... |

### pkg_dm_enmascarar (05)

| Unidad | Visib. | Proposito | Escribe |
|---|---|---|---|
| `func_dm_norm` | publica | Normaliza un texto a mayusculas y sin espacios laterales para comparar identificadores de forma uniforme. | ninguno |
| `func_dm_safe_err` | privada | Aplana un mensaje de error (quita saltos de linea, lo acota a 1800 caracteres) para guardarlo en trazas y columnas de error. | ninguno |
| `func_dm_safe_name` | privada | Devuelve un nombre de objeto acotado a 256 caracteres (o ? si es nulo) para componer mensajes de traza sin romper longitudes. | ninguno |
| `func_dm_qname` | privada | Valida y entrecomilla un identificador SQL con DBMS_ASSERT para poder concatenarlo con seguridad en SQL dinamico. | ninguno |
| `proc_dm_pepper_generar` | privada | Crea (si no existe) la semilla efimera PEPPER_MASK:<ejecucion_id> con 256 bits aleatorios y fija la ejecucion activa para los workers y el coordinador. | TDM_SECRETO (INSERT + COMMIT); variable de paquete g_ejec_actual; contexto de pkg_dm_func_mask.proc_dm_set_... |
| `proc_dm_pepper_purgar` | publica | Borra la semilla efimera de UNA ejecucion, con guarda de estado para no destruir un pepper que aun puede necesitarse. | TDM_SECRETO (DELETE de la clave PEPPER_MASK:<id> + COMMIT) |
| `func_dm_csv_item` | privada | Extrae el elemento N de una lista separada por comas, normalizado, para iterar tablas y columnas pasadas como CSV. | ninguno |
| `func_dm_tabla_tiene_trig_upd` | privada | Indica si una tabla tiene triggers de UPDATE habilitados, para forzar ejecucion en serie y evitar deadlocks GES en RAC. | ninguno |
| `proc_dm_ejecuta_update_seguro` | privada | Ejecuta el UPDATE de enmascarado de una columna: directo si la tabla es pequena o IOT, y con DBMS_PARALLEL_EXECUTE por chunks si supera 100000 filas. | UPDATE sobre la tabla/columna objetivo (directo o por chunks de rowid); DBMS_PARALLEL_EXECUTE: CREATE_TASK,... |
| `proc_dm_trace` | publica | Registra una linea de traza del flujo delegando en pkg_dm_trazabilidad (wrapper de compatibilidad con la firma historica). | TDM_MASK_TRACE (INSERT en transaccion autonoma, via pkg_dm_trazabilidad.proc_dm_trace) |
| `proc_dm_upd_sol` | privada | Actualiza estado, fase, checkpoint y detalle de una solicitud de enmascarado, y opcionalmente la cierra con fecha_fin. | TDM_MASK_SOLICITUD (UPDATE + COMMIT) |
| `proc_dm_upd_ejec` | privada | Actualiza fase, estado, progreso, contadores, ultimo objeto y latido de la fila de TDM_EJECUCION, sin permitir resucitar una ejecucion ya cerrada. | TDM_EJECUCION (UPDATE + COMMIT); TDM_MASK_TRACE (traza UPD_EJEC_BLOQUEADO / UPD_EJEC_FALLO via proc_dm_trace) |
| `proc_dm_close_sol_open` | privada | Cierra como ERROR las solicitudes de la ejecucion que quedaron abiertas por un intento anterior, antes de abrir una nueva. | TDM_MASK_SOLICITUD (UPDATE a ERROR/FIN/AUTO_CLOSE_REANUDAR + COMMIT) |
| `proc_dm_chk_cancel` | privada | Comprueba si se ha pedido cancelar la ejecucion y, en ese caso, aborta el flujo con un error de cancelacion cooperativa. | ninguno |
| `func_dm_esquema` | privada | Obtiene el esquema objetivo de una ejecucion, normalizado. | ninguno |
| `func_dm_crea_sol` | privada | Crea una solicitud de enmascarado en estado EN_PROCESO con el numero de reintento siguiente para la ejecucion. | TDM_MASK_SOLICITUD (INSERT + COMMIT) |
| `proc_dm_validar_base` | privada | Verifica que existen las tablas base del motor antes de empezar a enmascarar. | ninguno |
| `proc_dm_refresca_sesion` | privada | Registra en TDM_EJECUCION la sesion Oracle actual (sid, serial, instancia, audsid) y el latido, delegando en pkg_dm_trazabilidad. | TDM_EJECUCION (UPDATE sesion_* y heartbeat_ts, transaccion autonoma, via pkg_dm_trazabilidad.proc_dm_refres... |
| `proc_dm_validar_concurrencia` | privada | Impide arrancar un enmascarado si ya hay otra ejecucion ENMASCARAMIENTO en curso para la misma ejecucion_id o para el mismo esquema. | TDM_EJECUCION (indirecto: pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas pasa a ABORTADA las EJECUTANDO h... |
| `proc_dm_log_ejec_error` | publica | Registra un error de ejecucion en TDM_EJECUCION_ERROR delegando en pkg_dm_trazabilidad (wrapper de compatibilidad con la firma historica). | TDM_EJECUCION_ERROR (INSERT, transaccion autonoma); TDM_MASK_TRACE (linea ERROR.REGISTRADO via proc_dm_trace) |
| `proc_dm_validar_reingreso_mask` | privada | Impide re-ejecutar un enmascarado sobre una ejecucion ya FINALIZADA salvo que se pida reproceso explicito. | ninguno |
| `func_dm_tiene_regla` | privada | Cuenta las reglas especiales activas de un tipo dado para una columna. | ninguno |
| `func_dm_val_regla` | privada | Devuelve el valor parametrico (valor_regla) de la regla especial activa de un tipo para una columna. | ninguno |
| `func_dm_expr_gen_sql` | privada | Traduce un identificador de dato sensible a la expresion SQL de la funcion de enmascarado de pkg_dm_func_mask que le corresponde. | ninguno |
| `func_dm_expr_compatible` | privada | Construye la expresion de SET del UPDATE segun el tipo real de la columna, acotada a su longitud para evitar ORA-12899. | ninguno |
| `func_dm_dep_col_exists` | privada | Comprueba (con cache en variables de paquete) si TDM_DEPENDENCIA_FINAL tiene las columnas opcionales de politica CATEGORIA_USO, ACCION_PRE_MASK y ACCION_POST_MASK. | variables de paquete g_dep_has_* (cache) |
| `proc_dm_dep_policy` | privada | Determina la categoria de uso y las acciones pre y post enmascarado de una dependencia (FK, PK/UK, trigger u otra), con defaults por tipo y sobreescritura desde TDM_DEPENDENCIA_FINAL. | ninguno |
| `func_dm_dep_post_action` | privada | Devuelve la accion de rehabilitacion post enmascarado de una dependencia (por defecto ENABLE para trigger, ENABLE_VALIDATE para el resto). | ninguno |
| `proc_dm_pre_dep` | privada | Deshabilita (DDL) las FK, claves y triggers definidos en TDM_DEPENDENCIA_FINAL y deja constancia en TDM_MASK_DEP_ESTADO para poder rehabilitarlos tras enmascarar. | TDM_MASK_DEP_ESTADO (INSERT/UPDATE); DDL: ALTER TABLE ... DISABLE CONSTRAINT ... CASCADE; DDL: ALTER TRIGGE... |
| `proc_dm_post_dep` | privada | Rehabilita (DDL) los triggers y constraints que proc_dm_pre_dep dejo deshabilitados, segun la accion post configurada, y registra el resultado. | TDM_MASK_DEP_ESTADO (UPDATE estado_posterior, habilitado_ok); DDL: ALTER TRIGGER ... ENABLE; DDL: ALTER TAB... |
| `func_dm_min_len_identificador` | privada | Devuelve la longitud minima de columna necesaria para poder enmascarar un tipo de identificador. | ninguno |
| `proc_dm_upsert_excepcion_col` | privada | Crea o actualiza una excepcion EXCLUDE/FORCE activa para una columna en TDM_EXCEPCION_COL. | TDM_EXCEPCION_COL (MERGE + COMMIT) |
| `proc_dm_get_excepcion` | privada | Lee la excepcion activa (accion e identificador forzado) de una columna. | ninguno |
| `proc_dm_apl_col` | privada | Enmascara una columna: resuelve excepcion y longitud minima, elige regla especial o expresion por identificador, ejecuta el UPDATE y anota APPLY_COL como punto de control. | UPDATE de la columna objetivo (via proc_dm_ejecuta_update_seguro); TDM_EXCEPCION_COL (MERGE de auto-exclusi... |
| `proc_dm_post_sync` | privada | Propaga el valor ya enmascarado de columnas origen a columnas destino segun TDM_MASK_RELACION_SYNC y verifica que quedan iguales. | UPDATE de la columna destino (via proc_dm_ejecuta_update_seguro); TDM_MASK_TRACE (SYNC, SYNC_OK, SYNC_MISMA... |
| `proc_dm_mask_cat` | privada | Recorre las columnas pendientes (clasificadas Y mas FORCE vivos, menos EXCLUDE y las ya confirmadas) llamando a proc_dm_apl_col y actualizando el progreso. | TDM_MASK_SOLICITUD (contadores y ultima tabla/columna); TDM_EJECUCION (heartbeat_ts y, via proc_dm_upd_ejec... |
| `proc_dm_enmascaramiento` | publica | Orquesta el enmascarado completo de un esquema: preflight de tareas huerfanas, desactivacion de dependencias, pepper, enmascarado de columnas, sincronizacion, rehabilitacion, recompilacion y cierre de estado. | TDM_EJECUCION (reclamo EJECUTANDO, estado final); TDM_MASK_SOLICITUD (alta y cierre); TDM_MASK_TRACE y TDM_... |
| `proc_dm_cancelar` | publica | Solicita la cancelacion cooperativa de una ejecucion en curso marcando cancel_requested y avisando al operador del resultado. | TDM_EJECUCION (cancel_requested = Y); TDM_MASK_SOLICITUD (detalle); COMMIT; DBMS_OUTPUT |
| `proc_dm_gestiona_tareas` | publica | Diagnostica, reconcilia o descarta las tareas DBMS_PARALLEL_EXECUTE (TDM_<hash>) que una ejecucion interrumpida dejo atras. | DBMS_PARALLEL_EXECUTE: RESUME_TASK (reejecuta el UPDATE de los chunks pendientes sobre la tabla objetivo) y... |
| `proc_dm_reanudar` | publica | Reanuda un enmascarado interrumpido sobre la misma ejecucion_id, tras verificar fase correcta y sesion original muerta, saltando las columnas ya confirmadas. | TDM_MASK_TRACE (REANUDACION_INICIO); variable de paquete g_resume_base_solicitud; todo lo que escribe proc_... |
| `proc_dm_enmascara_tabla` | publica | Enmascara de forma selectiva una o varias tablas (o columnas) con un identificador dado, creando una ejecucion ad hoc con su propio pepper efimero. | TDM_EJECUCION (INSERT de ejecucion ad hoc y cambios de estado); TDM_MASK_SOLICITUD; TDM_SECRETO (alta y pur... |

### pkg_dm_func_mask (06)

| Unidad | Visib. | Proposito | Escribe |
|---|---|---|---|
| `proc_dm_set_ejecucion` | publica | Fija en la sesion la campana (ejecucion_id) activa para que el pepper y la clave AES se lean de esa campana, invalidando las caches si cambia. | ninguno |
| `func_dm_get_pepper` | privada | Devuelve el pepper (secreto base) de la campana activa leyendolo de TDM_SECRETO y cacheandolo en la sesion; aborta si no existe. | ninguno |
| `func_dm_clave_aes` | privada | Deriva la clave AES-128 de FF1 (primeros 16 bytes de SHA-1 del pepper) y la cachea por sesion. | ninguno |
| `func_dm_hash` | privada | Genera una semilla numerica determinista de 56 bits (HMAC-SHA1 con el pepper como clave) para los dominios de texto y para los sustitutos de dominio pequeno. | ninguno |
| `func_dm_num_hex` | privada | Convierte un entero no negativo a su cadena hexadecimal big-endian de longitud fija (p_bytes bytes), como pide el formato de bloques de FF1. | ninguno |
| `func_dm_ajuste_dominio` | privada | Calcula el ajuste (tweak) FF1 de 8 bytes a partir del nombre del dominio (SHA-1 de 'DOMINIO:'//identificador) para que un mismo dominio siempre cifre igual. | ninguno |
| `func_dm_ff1_cifrar_raw` | publica | Implementa FF1.Encrypt (NIST SP 800-38G, radix 10, 10 rondas Feistel con AES-128 CBC-MAC) sobre una cadena de digitos con clave y ajuste explicitos; produce una cadena de digitos de igual longitud, determinista, para validar contra vectores NIST. | ninguno |
| `func_dm_ff1_cifra` | privada | Wrapper de produccion de FF1: cifra una cadena de digitos con la clave AES derivada del pepper de la campana y el ajuste indicado. | ninguno |
| `func_dm_digitos_min_dominio` | privada | Genera un reemplazo numerico de n digitos (con ceros a la izquierda) via HMAC-SHA1 para dominios de 1 a 5 digitos, donde NIST prohibe usar FF1 (minimo radix^minlen >= 1.000.000). | ninguno |
| `func_dm_fpe_num` | privada | Cifra un numero dentro del rango [0, modulo) con FF1 y cycle-walking conservando la biyeccion; si el dominio tiene menos de 6 digitos usa el sustituto HMAC en lugar de FF1. | ninguno |
| `func_dm_txt_seguro` | privada | Limita un texto a 1000 caracteres (semantica de caracteres, no bytes) para evitar ORA-06502 por cortes de multibyte. | ninguno |
| `func_dm_mix_alpha` | privada | Sustituye cada letra de un texto por una letra mayuscula A-Z generada por un generador congruencial a partir de una semilla, conservando longitud y caracteres no alfabeticos. | ninguno |
| `func_dm_nombre` | publica | Enmascara nombres y apellidos: produce un VARCHAR2 de la misma longitud con letras A-Z sinteticas, determinista por campana (semilla HMAC del texto en mayusculas), no biyectivo. | ninguno |
| `func_dm_direccion` | publica | Enmascara direcciones: produce un VARCHAR2 sintetico del tipo 'Calle Mayor N 12, Madrid' elegido de listas fijas segun una semilla HMAC del texto; determinista por campana, no biyectivo ni conserva la forma original. | ninguno |
| `func_dm_obs` | publica | Enmascara observaciones o texto libre sustituyendolo por una constante fija; produce VARCHAR2 y es determinista (no depende de la entrada ni del pepper). | ninguno |
| `func_dm_telefono` | publica | Enmascara telefonos: produce un VARCHAR2 de 9 digitos que empieza por 6, 7, 8 o 9 derivado de una semilla HMAC de los digitos del original; determinista por campana, no biyectivo. | ninguno |
| `func_dm_email` | publica | Enmascara correos electronicos: produce un VARCHAR2 con 10 letras minusculas, un numero y dominio correo.com o correo.es, derivado de una semilla HMAC del correo en minusculas; determinista por campana, no biyectivo. | ninguno |
| `func_dm_letra_dni` | privada | Calcula la letra de control oficial del DNI/NIE (resto modulo 23 sobre la tabla TRWAGMYFPDXBNJZSQVHLCKE). | ninguno |
| `func_dm_cif_ctrl` | privada | Calcula el digito o letra de control de un CIF segun la letra de tipo de organizacion y sus 7 digitos numericos. | ninguno |
| `func_dm_enmascara_nie` | privada | Enmascara el numero de un NIE con FF1 (dominio 10^7) y compone un NIE valido: prefijo X/Y/Z derivado del numero generado, 7 digitos y letra de control; determinista por campana. | ninguno |
| `func_dm_cifra_digitos_en_texto` | privada | Enmascara documentos de formato libre (pasaporte, extranjero): cifra los digitos con FF1 conservando letras y separadores en su posicion, y si no hay digitos genera un texto alfanumerico sintetico de igual longitud; salida VARCHAR2 determinista por campana. | ninguno |
| `func_dm_nif` | publica | Enmascara identificadores de persona o empresa (DNI, NIE, CIF y otros formatos): produce un VARCHAR2 con la misma estructura donde la parte numerica se cifra con FF1 y la letra o digito de control se recalcula; determinista por campana. | ninguno |
| `func_dm_cuenta` | publica | Enmascara numeros de cuenta bancaria no IBAN: produce un VARCHAR2 de digitos (entre 4 y 20) cifrando con FF1 los digitos del original; determinista por campana. | ninguno |
| `func_dm_iban_cc_es` | privada | Calcula los 2 digitos de control (modulo 97) de un IBAN espanol a partir de su BBAN de 20 digitos. | ninguno |
| `func_dm_iban` | publica | Enmascara IBAN: produce un VARCHAR2 'ES'+control+20 digitos, cifrando el BBAN con FF1 si el original es un IBAN espanol valido o generandolo por HMAC en otro caso; determinista por campana. | ninguno |
| `func_dm_especial_doc_keep_ends` | publica | Enmascara un documento conservando su primer y ultimo caracter: cifra con FF1 el interior si es numerico (>= 6 digitos) o genera un interior sintetico por semilla HMAC; produce VARCHAR2 en mayusculas, determinista por campana. | ninguno |
| `func_dm_espec_doc_segun_tipo` | publica | Enmascara un documento segun su tipo (1 = DNI, 3 = NIE, otro = pasaporte): produce un VARCHAR2 con la misma estructura que func_dm_nif, con parte numerica cifrada por FF1 y mismo ajuste IDENTIDAD; determinista por campana. | ninguno |
| `func_dm_especial_iban_continuo` | publica | Enmascara un IBAN espanol en formato continuo: produce un VARCHAR2 de 24 caracteres 'ES'+control+BBAN, con 20 digitos tomados de la entrada cifrados con FF1; determinista por campana. | ninguno |
| `func_dm_generico` | publica | Enruta un valor a la funcion de enmascarado adecuada segun un identificador semantico (exacto o por palabras clave) y devuelve su VARCHAR2 enmascarado; si no reconoce el identificador usa la constante de func_dm_obs. | ninguno |

## 7. Observaciones de la revision que hay que verificar

Salieron de la lectura del codigo para redactar las cabeceras. **Ninguna esta probada**; la primera y la segunda las comprobe leyendo el codigo, el resto es lectura del revisor sin ejecucion.

1. **Cancelacion cooperativa termina en ERROR, no en CANCELADO** (leido en `proc_dm_enmascaramiento`): el `ORA-20081` que lanza `proc_dm_chk_cancel` dentro del bucle de columnas lo captura el bloque que envuelve `proc_dm_mask_cat` (`WHEN OTHERS`), que suma un error y sigue con `proc_dm_post_sync` y `proc_dm_post_dep`. El manejador final que mapea `-20081` a `CANCELADO` nunca lo ve por esa via. Efecto: una cancelacion cooperativa deja la corrida en ERROR y ejecuta la sincronizacion posterior sobre datos a medias. El flujo de cancelacion real del proyecto (`dm_enmascara_cancel`) mata la sesion y no usa este camino. Correccion propuesta (una linea: relanzar `-20081` en ese bloque) pendiente de que la apruebes y de una prueba.
2. **`proc_dm_especial_iban_continuo`** (`06`): toma los 20 primeros digitos de la entrada tras quitar lo que no es digito. Si el valor trae el prefijo `ES` mas los 2 digitos de control (22 digitos), se pierden los 2 ultimos digitos del BBAN antes de cifrar; dos IBAN que solo difieran en esos dos digitos darian el mismo resultado. Leido en el codigo; no probado con datos reales.
3. `proc_dm_pre_dep` usa `DISABLE CONSTRAINT ... CASCADE`: puede deshabilitar FK hijas que no esten en `TDM_DEPENDENCIA_FINAL`, y `proc_dm_post_dep` solo rehabilita las registradas en `TDM_MASK_DEP_ESTADO`. Hay que comprobar tras una corrida que no queda ninguna constraint DISABLED (la verificacion `VERIFICAR` ya lo cubre).
4. `func_dm_generico` evalua las palabras clave de forma que `IDENT` precede a `CUENTA`/`BANC`: un identificador del estilo `IDENTIFICADOR_CUENTA` caeria en `func_dm_nif`. Revisar si esa combinacion existe en `TDM_REGLA`.
5. `pkg_dm_descubrimiento.proc_dm_cancelar` borra el historico de columnas y dependencias de forma incondicional, tambien sobre una ejecucion FINALIZADA, y ningun script la invoca. `proc_dm_reanudar` del descubrimiento lanza `ORA-01403` sin controlar si el `ejecucion_id` no existe.
6. Funciones de `06` sin guardas de longitud (entradas muy largas o NULL pueden dar `ORA-06502` o perdida de exactitud en la aritmetica `NUMBER`): `func_dm_num_hex`, `func_dm_ff1_cifrar_raw`, `func_dm_cifra_digitos_en_texto`, `func_dm_especial_doc_keep_ends`, `func_dm_espec_doc_segun_tipo`. Los valores de 1 o 2 caracteres en `doc_keep_ends` y las cuentas sin digitos (`func_dm_cuenta`) se devuelven sin enmascarar.

## 8. Sobre `TDM_PARAMETRO` y las versiones por paquete

- **Ahora:** `TDM_PARAMETRO` sostiene el catalogo de eventos. Es lo unico que el motor lee de ahi y no recarga nada: una consulta por sesion.
- **Despues (evolucion):** solo existe el grupo `EVENTO`. La captura de version, undo, CPU, SGA y PGA **no se implementa ahora**: solo tiene sentido si luego se decide tener rutas por version, y hasta entonces seria una tabla con datos que nadie lee. Cuando se decida, se agrega el grupo al `CHECK` de la tabla. Tambien para que el tuning (tamano de chunk, umbral de 100 000 filas, nivel de paralelismo) deje de estar fijo en el codigo.
- **Un paquete por version (`pkg_dm_enmascara11`, `19`, `26`) es mas costoso de lo que parece:** se mantendrian N copias de la logica de FF1 y de la propagacion, y cada correccion habria que aplicarla N veces y probarla N veces, que es justo lo contrario de defenderlo ante una auditoria. Oracle ofrece **compilacion condicional** (`$IF DBMS_DB_VERSION.VERSION >= 19 $THEN ... $ELSE ... $END`): un solo archivo fuente, y al instalar el compilador deja solo la rama de la version real. Solo la parte que de verdad cambia (por ejemplo `DBMS_SESSION.SLEEP` frente a `DBMS_LOCK.SLEEP`, o una ruta de lectura mas rapida en 19c) iria en ramas; el resto es comun. Los datos de infraestructura de `TDM_PARAMETRO` alimentarian el tuning, no la eleccion de paquete. Mi recomendacion es dejarlo como evolucion posterior, con compilacion condicional sobre un unico codigo, y no abrir una familia de paquetes.
