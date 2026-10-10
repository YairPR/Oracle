# Primera corrida real con TDM_PARAMETRO y rediseño de TDM_MASK_TRACE (2026-10-09 noche / 2026-10-10)

Complementa `claude/hallazgos_correcciones_y_estado_pruebas_2026-10-09.md` (estado de pruebas) y `claude/traza_ordenada_y_catalogo_funcional_2026-10-09.md` (descripción vigente de la traza).

## 1. Corrida real (DM_DUMMY, PREFORM, tras recompilar sin errores)

| Paso | Resultado |
|---|---|
| `@dm_descubre DM_DUMMY` (ejecución 1) | FINALIZADO. 22 tablas, 67 columnas evaluadas, 55 Y (L-01, línea base) |
| `@dm_enmascara 1` | FINALIZADO. 55 columnas, 31/31 dependencias, 0 ERROR, 1 WARN (SKIP_AUTO_LEN), 37 min, 23,2 M filas |

Observaciones (ninguna bloqueante, todas de este día):
- La traza de la corrida tenía 243 filas, 56 de 57 del descubrimiento eran una línea por tabla sin valor de auditoría -> motivo del rediseño (sección 2).
- Evento RUTA: se escribe cuando termina el UPDATE de la columna (misma marca de tiempo que APPLY_COL), no cuando se decide la ruta. Corregirlo exigiría pasar ids a `proc_dm_ejecuta_update_seguro`. Documentado, no cambiado.
- Columna FORCE COD_ACCESO_CORTO (4 caracteres, mínimo 10 de IDENTIFICADOR_BANCARIO) queda en claro y la ejecución termina FINALIZADO con 1 WARN. Decisión pendiente del usuario: ¿es lo que se quiere con "FORCE = siempre enmascara"? Está declarado como limitación conocida.
- Rendimiento: NIF 1,5 M filas 186 s frente a ~27-33 s del resto de columnas comparables; CUENTA_VOL 5,4 M filas ≈ 13,7 min por columna; total 37 min / 23,2 M filas.

## 2. Rediseño de TDM_MASK_TRACE

Motivo: la tabla se diseñó para el enmascaramiento; el descubrimiento es un proceso de exploración y su traza no debe ser una bitácora por tabla.

Decisiones:
- Descubrimiento deja una sola línea resumen: fase `DESCUBRIMIENTO`, paso `RESUMEN`, detalle `tablas=x columnas=y enmascarar=z` (+ duración). Solo hay líneas adicionales para excepción: `TABLAS_OMITIDAS`, `FINAL_OBSOLETAS`, `FINAL_OBSOLETAS_ERR`, `PROPAGA_DOMINIOS_ERR`. `RI_REINCLUYE` (fase PROPAGACION) se mantiene.
- `solicitud_id` NULL en descubrimiento es correcto (no hay solicitud de enmascaramiento).
- Columnas eliminadas: `ora_owner`, `table_name`, `column_name`, `filas`, `error_id`. Quedan 9: trace_id, solicitud_id, ejecucion_id, nivel, fase, paso, detalle, fecha_evento, duracion_seg. Índice `idm_mask_trace_03` eliminado.
- `error_id` pasa a la forma `error_id=N` dentro de `detalle` del evento ERROR.REGISTRADO; el objeto (OWNER.TABLA.COLUMNA) ya viaja en `detalle` en APPLY_COL, SKIP_*, RUTA y APPLY_COL_SAFE_FALLBACK.
- `proc_dm_trace` pasa de 11 a 6 parámetros: `(p_solicitud_id, p_ejecucion_id, p_fase, p_paso, p_detalle, p_duracion_seg DEFAULT NULL)`.
- Catálogo TDM_PARAMETRO: 58 eventos (DISCOVERY.* sustituidos por DESCUBRIMIENTO.*); quedan 57 tras retirar RUTA (sección 5).

Análisis de consumidores (por qué es seguro):
- La reanudación lee solo `detalle LIKE 'OWNER.TABLE.COLUMN filas=%'` de los pasos APPLY_COL*: el formato de `detalle` no cambió.
- Ningún script del motor ni de tests lee las columnas eliminadas (escaneo de todos los .sql). Las consultas T-01..T-05 del documento de traza se reescribieron con `detalle LIKE`/`REGEXP`.
- El escritor `proc_dm_log_ejec_error` sigue siendo único; TDM_EJECUCION_ERROR conserva su `error_id`.

Verificación hecha: estática (balance de paréntesis frente al respaldo, escaneo de llamadas a `proc_dm_trace` con ≤6 argumentos, catálogo 58 filas igual en SQL, documento y código). Un defecto detectado en la revisión del diff (se había perdido `p_duracion_seg` en la llamada del wrapper de 05) se corrigió.
**No se ha compilado ni ejecutado nada después de este rediseño.** Requiere `98_uninstall.sql` + `99_install_datamasking.sql`, revisar INVALID, repetir DM_DUMMY (descubrir + enmascarar) y T-01..T-05.

## 3. Pendientes vigentes
- Cancelación cooperativa: ORA-20081 se traga en el `WHEN OTHERS` de mask_cat (arreglo de una línea propuesto, esperando aprobación).
- IBAN continuo: posible pérdida de los 2 últimos dígitos del BBAN cuando la entrada incluye ES + dígitos de control (sin verificar).
- `dm_reset_ejecuciones.sql` consulta `user_parallel_execute_tasks` (debe ser dba_). Reemplazar `dbms_session.sleep` en `tests/E02*.sql` (11.2).
- Supuestos sin verificar: SQL_STMT en DBA_PARALLEL_EXECUTE_TASKS, `func_dm_generico` == expresión del motor, vectores NIST.
- Precomprobación de recursos (dba_free_space, v$recovery_file_dest, dba_segments, log_mode, undo_retention) para `tests/campana_cierre.sql`.
- Acordar métricas de descubrimiento (propuesta: recall ≥ 95 % CONFIRMADO+PROBABLE, falsos positivos ≤ 2 % de las Y).
- Dividir paquetes grandes (05, 04) por responsabilidad solo después de la campaña.

## 4. Segunda ronda (2026-10-10): formato de fecha y duración, instaladores

**TDM_MASK_TRACE.** `fecha_evento` pasa de TIMESTAMP a DATE (`DEFAULT SYSDATE`, al segundo) y `duracion_ms` pasa a `duracion_seg NUMBER(12,2)` (segundos con 2 decimales). `func_dm_ms_desde` se renombra `func_dm_seg_desde` y devuelve segundos; el parámetro de `proc_dm_trace` es `p_duracion_seg`. Un DATE se muestra según NLS_DATE_FORMAT; para verlo como `DD-MM-YYYY HH24:MI:SS` se usa `TO_CHAR` (así ya lo hacen `dm_enmascara_id.sql` y las consultas del documento de traza). Eventos del mismo segundo se ordenan por `trace_id`. Efecto colateral corregido: la consulta de línea de tiempo usaba `TO_CHAR(fecha_evento,'HH24:MI:SS.FF3')`, que da ORA-01821 sobre un DATE.

**Auditoría de instalación y desinstalación.** Método: inventario automático de lo que crean 01, 02 y los paquetes (sin contar bloques comentados) cruzado con 98 y 99, y escaneo de todos los scripts buscando objetos o subprogramas de paquete inexistentes.

| Hallazgo | Corrección |
|---|---|
| 98 intentaba borrar `seq_dm_ejecucion_err`, que ya no existe (se retiró el 28/09) | Eliminado del 98 |
| 98 tenía el esquema fijo `ASTSYSADMIN`; 99 detecta ASTSYSADMIN o ACC_ADMIN | 98 detecta el esquema igual que 99 |
| Las tareas `DBMS_PARALLEL_EXECUTE` TDM_* sobreviven a la desinstalación y la siguiente corrida real aborta por OBSOLETA | 98 las borra con `ADM_DROP_TASK` (avisa si falta el rol) |
| 98 no comprobaba el resultado | 98 termina listando REMANENTES (TDM_%, PKG_DM_%, SEQ_DM_%) y el rol |
| 99 validaba `TDM_MASK_RESULTADO` y `TDM_MASK_CACHE`, que no existen (la DDL de CACHE está comentada) y omitía `TDM_SECRETO`, `PKG_DM_TRAZABILIDAD`, `PKG_DM_EXPORT` y las 9 secuencias | 4.1 compara esperado contra real (17 tablas, 9 secuencias, 5 paquetes y 5 cuerpos) y solo imprime fallas; 4.2 lista objetos sobrantes que 98 no conoce |
| El `spool off` de 99 quedaba antes de la validación (el log no la recogía) | `spool off` movido después de 4.6 |
| Grants comentados a objetos inexistentes (`tdm_mask_cache`, `seq_dm_mask_resultado`) | Sustituidos por una nota; `TDM_SECRETO` sin grant al rol es a propósito |
| Sin comprobación de EXECUTE sobre paquetes de SYS | Nueva 1.1c, solo informa (DBMS_CRYPTO, DBMS_PARALLEL_EXECUTE, DBMS_SCHEDULER, DBMS_LOCK, DBMS_DATAPUMP) |
| `dm_reset_ejecuciones.sql` consultaba `user_parallel_execute_tasks` (tareas del DBA, no del motor) y llamaba estáticamente a `pkg_dm_mantenimiento`, inexistente en el instalador | Usa `dba_parallel_execute_tasks` + `ADM_DROP_TASK`; llamadas a `pkg_dm_mantenimiento` dinámicas |
| `dm_validar_flujo.sql` mostraba el nombre inexistente `tdm_ejec_error` en un mensaje | Corregido a `tdm_ejecucion_error` |

Orden de compilación verificado por referencias: 03b (sin dependencias) -> 04 (usa 03b) -> 06 (sin dependencias de paquete) -> 05 (usa 03b, 04 y 06) -> 07 (solo tablas); coincide con el orden de 99.
Regla de mantenimiento: al agregar o retirar un objeto del motor se actualizan las tres listas a la vez (98, 4.1 de 99 y los GRANT de 2.9).
Sin ejecutar: todo lo anterior es revisión estática; falta correr 98 y 99 en una base real.

## 5. Tercera ronda (2026-10-10): una reanudación que "no deja rastro"

**Qué pasó.** Con DM_DUMMY enmascarando (ejecución 1) se mató la sesión con `kill` y se corrió `@dm_descubre_reanudar 1`: ese script reanuda el DESCUBRIMIENTO, no el enmascarado. Mostró solo "Reanudando descubrimiento....." y no volvió. Causa: el script lee `&1 &2 &3` pero solo definía `"2"`; con un único argumento SQL*Plus pedía el valor de `&3` y, por el `SET TERMOUT OFF` previo, el aviso no se veía (la sesión esperaba en silencio; con Enter continúa y termina en ORA-20516 que indica `@dm_enmascara_reanudar 1`). Por eso la solicitud seguía con `reintento_nro = 1`, `TDM_EJECUCION` sin cambios y sin eventos nuevos: nunca se llegó a reanudar. El comando correcto es `@dm_enmascara_reanudar 1`.

**Estado real del monitor en ese momento.** Sesión principal (sid 401) muerta, pero un job worker (`TASK$_19012_1`) seguía vivo procesando el chunk 9 de 9 de `TBL_CUENTA_VOL.CUENTA_CCC` (8 PROCESSED, ~89 %), con la tarea en PROCESSING. Es el caso de nivel 2 de la sección 5 de `hallazgos_correcciones_y_estado_pruebas`. `@dm_enmascara_reanudar` espera 30 s a que terminen los workers y, si siguen, los mata: el chunk en curso se revierte entero y se rehace. Para no repetir ese chunk conviene esperar a que pase a PROCESSED (sección 3b de `@dm_monitor`) y reanudar después.

**Cambios.**

| Archivo | Cambio |
|---|---|
| `dm_descubre_reanudar.sql` | Define `"3"` (ya no se cuelga con un argumento). La comprobación de fase va antes que la de estado: una ejecución de ENMASCARAMIENTO ahora indica `@dm_enmascara_reanudar` y no "libere la fila" |
| `05_dm_pkg_enmascarar.sql` | Primer evento del enmascarado: fase `ENMASCARAMIENTO`, paso `INICIO` (antes `INI`). Una línea `APPLY_COL` por columna con `filas=N ruta=...` (RUTA se funde en ella). Reanudación: `ENMASCARAMIENTO.INICIO` lleva `- REANUDACION desde solicitud_id=N`; nuevo `ENMASCARAMIENTO.REANUDACION` (intento, confirmadas, pendientes) ligado a la NUEVA solicitud (el viejo `MASK.REANUDACION_INICIO` iba con solicitud NULL); `TDM_EJECUCION.ultimo_paso = REANUDACION` y `detalle` con el texto. `proc_dm_upd_ejec` gana el parámetro opcional `p_detalle` (al final, por defecto NULL) |
| `02_dm_enmascaramiento_objetos.sql` | Catálogo: 57 eventos (alta de `ENMASCARAMIENTO.INICIO` y `.REANUDACION`; baja de `INI.INICIO`, `MASK.RUTA`, `MASK.REANUDACION_INICIO`) |
| `dm_monitor.sql` | Sección 1b: intentos de la ejecución (solicitud, `reintento_nro`, detalle) y detalle de `TDM_EJECUCION`. Las "últimas 8 trazas" se ordenaban por hora y paso (mezclaba eventos del mismo segundo); ahora por `trace_id`. Columnas `fase` y `paso` más anchas |
| `dm_enmascara_reanudar.sql` | El resumen final añade intento, detalle de la ejecución y una tabla de fases del intento (eventos, inicio, fin, WARN, ERROR) |

Formato de la línea por columna (normalizado a un solo estilo; el ejemplo pedido mezclaba ` - ` y espacio):
`DM_DUMMY.TBL_CLIENTES.DNI_REF filas=110 ruta=UPDATE [max 100000 filas] - filas_estimadas=110`
`DM_DUMMY.TBL_AUDIT_LOG_VOL.NIF_USUARIO filas=450000 ruta=CHUNKS [> 100k filas] - filas_estimadas=450000, bloques_por_chunk=2000, chunks=3, nivel_paralelismo=2`

**Sin ejecutar.** Revisión estática (catálogo SQL = documento = código, 57 eventos; ningún script lee `RUTA`, `REANUDACION_INICIO` ni la fase `INI`). Falta reinstalar y probar: matar a mitad, `@dm_monitor`, `@dm_enmascara_reanudar`, y comprobar la línea REANUDACION, `reintento_nro = 2` y `TDM_EJECUCION.detalle`.

**Ajuste posterior (misma ronda).** Al reanudar, `TDM_EJECUCION` solo recibía la marca en `proc_dm_mask_cat`, después de pre-flight, dependencias y pepper. Ahora `proc_dm_enmascaramiento` la escribe en el arranque (`ultimo_paso = REANUDACION`, `detalle = 'Reanudacion en curso (solicitud_id=N desde solicitud_id=M): calculando columnas pendientes'`) y `proc_dm_mask_cat` la completa con intento, columnas confirmadas y pendientes. Una corrida normal escribe `Enmascaramiento en curso (solicitud_id=N)`, así un texto de una reanudación anterior no queda como modo actual. Fuente de verdad de "está reanudando": `TDM_MASK_SOLICITUD.REINTENTO_NRO > 1` en la solicitud más reciente; el resto (trace, `TDM_EJECUCION.DETALLE`/`ULTIMO_PASO`, monitor) son vistas de lo mismo.

**Sesión 401.** `TDM_EJECUCION` conserva (401, 60708), la sesión orquestadora muerta; la sesión SQL*Plus donde se corrió el script equivocado es (401, 64599): el SID se reutilizó con otro SERIAL#. Por eso el motor compara sid + serial# + instancia. Esa sesión estaba INACTIVE (más de 17 min sin llamada, módulo SQL*Plus, sin módulo PKG_DM_*): esperaba el valor de `&3`, no reanudaba nada. `TDM_EJECUCION` solo cambia sus campos de sesión cuando arranca `proc_dm_enmascaramiento`, y eso no ocurrió.

## 6. Primera reanudación real (ejecucion_id=1) — resultado y hallazgos

**Resultado.** Tras matar la sesión principal con 5 columnas terminadas y un worker aún vivo en `TBL_CUENTA_VOL.CUENTA_CCC`, `@dm_enmascara_reanudar 1` (sesión nueva) terminó bien: el worker acabó su tarea (`TDM_726400669`, 9/9 chunks PROCESSED, ~5,4 M filas), el script la reconcilió sin reprocesar ningún chunk (columna 6), cerró la fila a ABORTADA y reanudó con el mismo pepper. Quedaron 47 columnas procesadas, FINALIZADO 100 %, intento 2 (reanudación 1), 0 WARN, 0 ERROR, 22 min de reanudación (10:42 a 11:04).

**Incidente de SQL*Plus (corregido).** La primera invocación imprimió decenas de SP2-0734: SQL*Plus no abrió los bloques `declare` de A y B y ejecutó cada línea como comando (las líneas `c_...` se interpretaron como el comando CHANGE, de ahí SP2-0023). En ambos bloques el `declare` iba justo después de una línea `Rem ----…----` terminada en guion. Causa probable (no demostrada: no hay SQL*Plus en el entorno de desarrollo): el guion final se toma como continuación de línea. Corrección: esas líneas terminan en `=` y hay una línea en blanco antes de cada `declare` (`dm_enmascara_reanudar.sql`, `98_uninstall.sql`, `99_install_datamasking.sql`). Tras el cambio la reanudación funcionó. Queda la contradicción de que el instalador ya tenía `Rem ---` antes de `@@01` y ese script sí se ejecutaba; no se ha aclarado. Pendiente por la misma causa probable: ~12 scripts tienen `Rem ---…---` antes de `define esquemaast`; no se tocaron porque, si se tragara el `define`, el efecto solo se vería en el caso extremo de no encontrar ni ASTSYSADMIN ni ACC_ADMIN.

**Hallazgo y corrección.** En [1/4] REVISION el script contó `Tareas paralelas : 0` y `Otras tareas TDM_% : 1`, pero la reconciliación del paquete atribuyó esa misma tarea a la ejecución 1. El script emparejaba con `dbms_lob.instr(dba_parallel_execute_tasks.sql_stmt, 'proc_dm_set_ejecucion(<id>)')`; el paquete lee `user_parallel_execute_tasks.sql_stmt` con REGEXP. Si hubiera habido workers vivos, el paso de espera/kill del script no los habría visto (el paquete era la segunda barrera). La causa exacta de que la vista DBA no coincida no está verificada. Corrección (2026-10-10): nueva función `pkg_dm_enmascarar.func_dm_tareas_de_ejecucion(p_ejecucion_id)` (lista de tareas separada por comas, mismo criterio que `proc_dm_gestiona_tareas`) y `dm_enmascara_reanudar.sql` la usa para contar tareas/chunks y localizar workers. Si el paquete instalado es anterior (sin la función), el script sigue funcionando con el emparejado antiguo pero imprime un AVISO. **Pendiente:** `dm_enmascara_cancel.sql` (línea ~111) tiene el mismo emparejado por `SQL_STMT` y puede no ver workers de la ejecución; no se tocó. Requiere reinstalar 05 y probarlo con un kill con worker vivo.

**Observación.** La tabla "Fases de este intento" mostró aún `INI` (1 evento) porque el paquete 05 con la fase ENMASCARAMIENTO y las marcas de reanudación no estaba reinstalado en esa corrida.
