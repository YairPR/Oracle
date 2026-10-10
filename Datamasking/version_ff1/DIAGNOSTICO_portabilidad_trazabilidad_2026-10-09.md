# Diagnostico: portabilidad (piso 11.2) y orden de las tablas de trazabilidad

Fecha: 2026-10-09. Origen: indicacion del usuario de que el motor debe poder ejecutarse en cualquier base 10g o superior (el usuario decidio despues mantener 11.2 como piso, ver seccion 1), con tuning para gran escala, y que las tablas de rastro (`TDM_EJECUCION_ERROR`, `TDM_MASK_SOLICITUD`, `TDM_MASK_TRACE`) necesitan un orden claro de funcion, igual que cada procedimiento y funcion. Todo lo de abajo sale de leer el codigo actual (auditoria estatica); nada esta probado en una base anterior a 19c.

## 1. Portabilidad: piso declarado 11.2 en adelante (decision del usuario)

El usuario decide mantener el motor como esta: **Oracle 11gR2 (11.2) en adelante**, con `DBMS_PARALLEL_EXECUTE` como ruta de gran volumen. No se baja a 10g ni se reemplaza el ejecutor de chunks. Auditoria estatica contra ese piso:

| Elemento | Desde | Estado frente al piso 11.2 |
|---|---|---|
| `DBMS_PARALLEL_EXECUTE` | 11.2 | Es la razon del piso. Sin cambios |
| `CONTINUE`, `:= secuencia.NEXTVAL` en PL/SQL | 11.1 | Compatible con 11.2 |
| `LISTAGG` (`dm_descubre_set.sql`) | 11.2 | Compatible |
| `DBMS_CRYPTO.HMAC_SH1`, `DBMS_ASSERT.ENQUOTE_NAME` | 10.2 | Compatible |
| `DBMS_SESSION.SLEEP` | 18c | Resuelto con llamada dinamica y `DBMS_LOCK.SLEEP` de reserva |
| Identificadores PL/SQL de mas de 30 caracteres | 12.2 | Resuelto (limite comun de 30 respetado) |
| `CREATE INDEX ... ONLINE` | solo Enterprise Edition | 23 apariciones en `01_` y `02_`: en Standard Edition falla con ORA-00439. **Resuelto el 2026-10-09:** se quito `ONLINE` de los 23 indices (se crean al instalar, sin trafico); el motor ya no exige Enterprise por esto |

Sin uso en el codigo: `SIMPLE_INTEGER`, `PIVOT`, `FETCH FIRST`, `IDENTITY`, `RESULT_CACHE`, `REGEXP_COUNT`, compound triggers.

Verificacion real: solo se ha ejecutado en 19c (PREFORM) y en las bases de desarrollo del usuario. El piso 11.2 se defiende con esta auditoria estatica y con la compilacion limpia en 19c; no hay prueba ejecutada en una 11.2 real. Dejarlo asi es una decision del usuario y se declara como limitacion.

## 2. Mapa funcional de las tablas de rastro

Principio propuesto: una pregunta, una tabla.

| Capa | Tabla | Pregunta que responde | Quien escribe | Quien lee |
|---|---|---|---|---|
| Configuracion | `TDM_REGLA` | que reglas usa el descubrimiento | carga de reglas (03) | descubrimiento |
| Configuracion | `TDM_EXCEPCION_COL` | que columnas el usuario fuerza o excluye | el usuario (loader) | descubrimiento y enmascarado |
| Resultado del descubrimiento | `TDM_COLUMNA_HIST` | que decidi sobre cada columna en cada ejecucion y por que (puntuaciones) | descubrimiento | auditoria, `dm_validar_flujo` |
| Resultado del descubrimiento | `TDM_DEPENDENCIA_HIST` | que dependencias (FK, triggers, constraints) detecte en cada ejecucion | descubrimiento | auditoria |
| Resultado del descubrimiento | `TDM_COLUMNA_FINAL` / `TDM_DEPENDENCIA_FINAL` | cual es el catalogo vigente que el enmascarado debe obedecer | sincronizacion tras descubrir | enmascarado |
| Resultado del descubrimiento | `TDM_EJECUCION_SCOPE` | que subconjunto de objetos abarca una ejecucion | descubrimiento | descubrimiento |
| Control de la corrida | `TDM_EJECUCION` | que corrida es y en que estado esta (esquema, fase, estado, progreso, latido, sesion, cancelacion) | descubrimiento y enmascarado | monitor, cancel, reanudar |
| Control de la corrida | `TDM_MASK_SOLICITUD` | que intento de enmascarar hubo dentro de esa corrida (reintentos, punto de control, contadores) | enmascarado | enmascarado, monitor |
| Control de la corrida | `TDM_MASK_DEP_ESTADO` | que dependencias desactive y tengo que restaurar | pre y post dependencias | enmascarado, auditoria |
| Control de la corrida | `TDM_SECRETO` | pepper efimero de cada campana | enmascarado | funciones de enmascarado |
| Observabilidad | `TDM_MASK_TRACE` | que paso, en que orden (linea de tiempo) | `proc_dm_trace` | operador, auditoria |
| Observabilidad | `TDM_EJECUCION_ERROR` | que fallo exactamente, con codigo, mensaje y traza, para diagnosticar | `proc_dm_log_ejec_error` y `proc_dm_log_error` | operador, `dm_validar_flujo` |

## 3. Problemas encontrados en el rastro

1. **Dos escritores de errores para la misma tabla.** `pkg_dm_trazabilidad.proc_dm_log_ejec_error` (03b) y `pkg_dm_descubrimiento.proc_dm_log_error` (04, 7 llamadas) hacen lo mismo con codigo duplicado. El propio 03b declara que la infraestructura comun vive ahi, y 04 conserva su copia. Ademas ambos usan `MAX(error_id)+1` con reintento porque la secuencia `SEQ_DM_EJECUCION_ERR` se retiro; cada error cuesta una lectura del maximo y bajo concurrencia hay que reintentar.
2. **El error se registra en dos sitios sin vinculo.** Un fallo deja una fila estructurada en `TDM_EJECUCION_ERROR` y, aparte, un evento de texto libre en `TDM_MASK_TRACE` con nivel ERROR, mas `error_count` y `detalle` en `TDM_EJECUCION`. No hay `error_id` en la traza para enlazarlos.
3. **`TDM_MASK_TRACE` mezcla nivel y fase.** El campo `fase` toma valores `PRE`, `POST`, `MASK`, `PROPAGACION`, `POST_SYNC`, `FIN`, `INI` y tambien `WARN` y `ERROR`, y el nivel se deduce de la fase. Hay unos 40 pares (fase, paso) distintos, sin catalogo documentado.
4. **La traza no tiene claves de objeto.** Tabla y columna van dentro de `detalle` en texto libre, asi que preguntar "que paso con la tabla X" obliga a buscar texto. Tampoco guarda tiempo ni filas por paso, que es justo lo que hace falta para analizar el rendimiento a escala.
5. **Solapamiento entre `TDM_EJECUCION` y `TDM_MASK_SOLICITUD`.** Ambas guardan latido, solicitud de cancelacion, sesion (sid/serial) y detalle. El rediseno de reanudar/cancel/monitor ya se apoya en `TDM_EJECUCION`; la duplicacion invita a que se desincronicen. `fecha_cancelacion` no se usa en ningun sitio.
6. **La traza del descubrimiento es casi inexistente** (4 llamadas frente a 65 en el enmascarado); el descubrimiento deja su rastro en `TDM_COLUMNA_HIST`, lo que es correcto como evidencia pero hace que el nombre `TDM_MASK_TRACE` sea engañoso para quien mire el descubrimiento.

## 4. Propuesta (aplicada en el codigo el 2026-10-09, sin compilar aun; ver `TRAZA_ordenada_y_catalogo_funcional_2026-10-09.md`)

1. **Un solo escritor de errores** (el de 03b) y que 04 lo llame; con secuencia propia otra vez, o `MAX+1` solo como reserva documentada.
2. **Vocabulario controlado** de (fase, paso) con una tabla de referencia o, como minimo, un catalogo documentado en el codigo, y separar `nivel` de `fase`.
3. **Columnas nuevas en `TDM_MASK_TRACE`:** se propusieron `ora_owner`, `table_name`, `column_name`, `filas`, `duracion_seg` y `error_id`. **Actualizacion 2026-10-10:** solo se conserva `duracion_seg`. Las otras cinco se retiraron por decision del propietario del proyecto tras la primera corrida: ningun consumidor las leia y el objeto ya va al inicio de `detalle`. La consulta T-03 pasa a usar `LIKE` sobre `detalle`.
4. **Regla de uso:** todo error = una fila en `TDM_EJECUCION_ERROR` (detalle completo) + una linea corta en la traza cuyo detalle empieza por `error_id=N`.
5. **Propiedad de campos:** el latido, la cancelacion y la sesion viven en `TDM_EJECUCION`; `TDM_MASK_SOLICITUD` guarda solo lo propio de cada intento (reintento, punto de control, contadores). Se retiran o se dejan sin uso los campos duplicados tras verificar quien los lee.
6. **Comentarios de tabla y de columna** completos en el DDL (hoy los de tabla son de una linea), con la pregunta que responde cada tabla.

## 5. Documentacion de procedimientos y funciones

Recuento aproximado por paquete (cuerpos): `03b` 5 unidades, `04` 33, `05` 44, `06` 29. Con comentario previo o interior: 5, 33, 18 y 23. **Sin ningun comentario:** 26 en `05` (entre ellas `proc_dm_ejecuta_update_seguro`, `proc_dm_apl_col`, `proc_dm_mask_cat`, `proc_dm_pre_dep`, `proc_dm_post_dep`, `proc_dm_reanudar`, `proc_dm_enmascara_tabla`, `proc_dm_cancelar`) y 6 en `06`. Ademas, en muchas unidades con comentario, el texto es la historia de un FIX y no una descripcion de para que existe.

Propuesta: cabecera estandar en cada unidad: Proposito (una frase), Entradas y salidas, Tablas que lee y que escribe, Errores propios (codigos), Llamada desde. Se genera primero un catalogo automatico (nombre, firma, paquete, linea, comentario existente) para ver los huecos, se redactan los propositos leyendo el codigo, y la cabecera queda dentro del propio paquete. Es un cambio solo de comentarios, sin efecto funcional, pero hay que reinstalar y recompilar los paquetes.
