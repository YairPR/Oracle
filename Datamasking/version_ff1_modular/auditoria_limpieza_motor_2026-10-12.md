#datamasking #ff1 #auditoria #limpieza

**Auditoria de limpieza del motor de enmascaramiento (2026-10-12)**

> [!info] Alcance
> Analisis estatico de todos los .sql del motor (paquetes 10 a 40, scripts dm_*, instalador 98/99, DDL 01/02/03, guion de uso y tests). Cada hallazgo indica evidencia, riesgo y accion. La seccion **Estado de la limpieza** al final recoge lo ejecutado el 2026-10-12 tras las decisiones del DBA.

**Metodo**

- Inventario de rutinas y grafo de llamadas por paquete (spec, body, privadas).
- Variables, parametros y rutinas sin uso.
- Referencias `pkg.rutina` y `@script` inexistentes.
- Tablas y columnas referenciadas frente al DDL.
- Catalogo TDM_MASK_TRACE_EVENTO frente a eventos emitidos.
- Bloques duplicados (ventanas de 7 lineas), literales de estado, `WHEN OTHERS`, `COMMIT`, SQL dinamico.

**Resumen**

| Prioridad | Hallazgos | Naturaleza |
|---|---|---|
| Alta | 5 | Logica duplicada o fallback inseguro que puede divergir |
| Media | 8 | Codigo muerto, eventos sin catalogo, referencias rotas |
| Baja | 9 | Etiquetas de ticket, umbrales, documentacion obsoleta |

**Prioridad alta**

> [!warning] A1. Fallback legacy del pepper (12_dm_pkg_mask_ff1, lineas ~104 a 160)
> Si `g_ejecucion_id` es NULL se lee la clave antigua `PEPPER_MASK`. Con pepper efimero por ejecucion es una puerta trasera: una sesion sin `proc_dm_set_ejecucion` enmascararia con un secreto distinto al de la ejecucion. Accion: eliminar el fallback y fallar cerrado con error explicito. Es el punto mas defendible ante auditoria.

> [!warning] A2. Conjunto "objetivo" duplicado en tres sitios
> La misma CTE (enmascarar='Y' mas FORCE activas, menos EXCLUDE, menos confirmadas APPLY_COL*, filtrada por `func_dm_en_alcance`) existe en 37:278 y 37:325, 35:734 y 35:841, y 34:~1109. Tambien el EXCLUDE (37:976, 35:783 y 875, 34:1109). Cualquier cambio de regla debe aplicarse en cinco lugares. Accion: una unica funcion o vista de objetivo en `pkg_dm_mask_estado` y que 34, 35 y 37 la consuman. Requiere prueba de regresion (ID, SET y COMPLETO).

> [!warning] A3. Compatibilidad de columnas muerta en 33_dm_pkg_mask_dependencias (lineas ~14 a 115 y ~160 a 270)
> `func_dm_dep_col_exists`, `g_dep_has_*` y cuatro SELECT dinamicos con `WHEN OTHERS NULL` comprueban si existen columnas que en 01:344 a 346 son `NOT NULL DEFAULT`. Siempre existen. Ademas `WHEN OTHERS NULL` puede ocultar errores reales. Accion: sustituir por SQL estatico y borrar la compatibilidad.

> [!warning] A4. Lookup APPLY_COL duplicado y lista de pasos repetida
> La lista `('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK'[,'SKIP_AUTO_LEN'])` se repite en 34:695 y 1117, 35:772 y 804, 37:231, 314, 351 y 377. `APPLY_COL_COLLISION` no lo emite ningun codigo (solo se lee): es logica antigua. Accion: funcion unica `func_dm_col_confirmada` y retirar COLLISION de las listas y del catalogo (02:115).

> [!warning] A5. Eventos emitidos sin catalogo y eventos de catalogo sin emisor
> Faltan en 02 cuatro eventos (por ejemplo los de 37:597 y 37:1062). Sobra `ADMIN.LIBERADA_MANUAL_DBA` (02:145), sin emisor. Como `func_dm_nivel` se alimenta del catalogo, un evento ausente cae al nivel por defecto y puede quedar fuera de la traza. Accion: alta de los cuatro y baja del huerfano.

**Prioridad media**

> [!note] M1. Variables sin uso en 34
> `l_estado_t` (~525) y `l_detalle` (~545). Borrar.

> [!note] M2. Referencias a scripts inexistentes
> 37:852, dm_descubre_reanudar.sql:50 y :190 (mensaje en tiempo de ejecucion), dm_enmascara_cancel.sql:59, :70 y :393, y 00_guion_uso_datamasking.sql:74, 122, 159, 167 (`dm_liberar_ejecucion_activa`, `dm_pepper_purgar`). El DBA recibiria instrucciones imposibles de ejecutar. Accion: apuntar a los scripts reales (`dm_enmascara_cancel`, `@dm_...` existentes) o retirar la frase.

> [!note] M3. Grant sin justificacion en 99_install_datamasking.sql (~104 a 111)
> `ADM_PARALLEL_EXECUTE_TASK` a `ROL_DATAMASKING` se justifica con un script que no existe. Antes de quitarlo, confirmar si algun flujo ejecutado por el rol llama a DBMS_PARALLEL_EXECUTE; si no, retirarlo (minimo privilegio, argumento de auditoria).

> [!note] M4. Nota obsoleta del pepper en 99 (~157 a 162) y linea `crea_sinonimos` (122)
> Describe el modelo anterior. Reescribir al modelo efimero; revisar si `crea_sinonimos` sigue siendo parte del instalador exclusivo del motor.

> [!note] M5. Fachadas en 37 (~1074 a 1118)
> Forwarders que solo delegan a los paquetes modulares. Decidir: mantenerlos como API estable (documentados como tal) o eliminarlos y que los scripts llamen al paquete real. Recomendacion: mantener solo los que usan los scripts dm_*; borrar el resto.

> [!note] M6. proc_dm_enmascara_tabla (37:149 y 903) sin llamador en scripts
> Es punto de entrada publico del modo por tabla; no lo invoca ningun dm_*.sql y el catalogo lo menciona (02:108, SKIP_TABLE_TABMODE). Decision: o se publica un script `dm_enmascara_tabla` o se retira la rutina y su evento. No se debe dejar una ruta de enmascaramiento sin script ni prueba.

> [!note] M7. Tests que replican funciones privadas
> tests/pkg_dm_test.sql y tests/pkg_dm_ff1_debug.sql copian logica privada del motor; pueden divergir silenciosamente. Accion: probar solo por la API publica o regenerarlos desde el paquete.

> [!note] M8. Nombres de documentacion obsoletos en 10_dm_pkg_trazabilidad.sql (144, 222, 431)
> Comentarios que citan nombres antiguos. Corregir.

**Prioridad baja**

- Umbrales literales en 34 (205, 233, 269 a 274: 100000, 10000000, 1000000). Pasarlos a constantes con nombre al inicio del body, sin cambiar valores.
- Etiquetas de ticket residuales en comentarios: B.1, M-03, M-1, A.2, A.3, B.2, B.3, P2, C-02, M-7, A.1, R-01, KPI-03. Quitar la etiqueta y dejar la explicacion.
- Estado PAUSADO: confirmar si algun flujo lo asigna; si no, retirarlo de las comprobaciones.
- Revision de `WHEN OTHERS` restantes: dejar solo los que registran y relanzan o los de limpieza deliberada; los que hacen `NULL` sin traza, documentarlos o acotarlos.
- `proc_dm_dep_policy` (33) solo se usa internamente: confirmar que puede ser privada.
- Documentos .md de la carpeta con nombres de herramientas de IA: se tratan en el bloque de cierre.

**Verificado y descartado como huerfano**

- `proc_dm_close_sol_open`: usada en 37:532.
- `proc_dm_validar_reingreso_mask`: usada en 37:490.
- `proc_dm_validar_concurrencia`, `proc_dm_prepara_objetos`, `proc_dm_descubrimiento_set`: con llamadores.

**Orden de limpieza recomendado**

1. Lote 1, sin riesgo funcional: M1, M2, M4, M8, etiquetas de ticket, catalogo (A5). Verificable por igualdad de codigo.
2. Lote 2, codigo muerto: A3 (33), A4 parcial (retirar COLLISION), PAUSADO, M3.
3. Lote 3, seguridad: A1 (fallar cerrado sin pepper). Prueba: ejecucion normal, reanudacion tras kill, sesion sin ejecucion.
4. Lote 4, consolidacion: A2 y A4 (objetivo y confirmadas en una sola fuente), M5, M6. Es el unico lote con riesgo; exige reinstalar 98 y 99 en 11g y 19c y repetir `dm_enmascara_id`, modo SET y COMPLETO.

> [!tip] Decisiones que necesito
> 1. proc_dm_enmascara_tabla: publicar script o retirar.
> 2. Fachadas de 37: cuales se mantienen.
> 3. Grant ADM_PARALLEL_EXECUTE_TASK: confirmar que ningun flujo del rol lo usa.
> 4. Autorizar el lote 4 (consolidacion) o dejarlo para despues de la campana de pruebas.

**Estado de la limpieza (2026-10-12)**

> [!success] Decisiones del DBA
> 1. No se publica `dm_enmascara_tabla`: el flujo es descubrir con `dm_descubre_set` (fija las tablas por integridad referencial) y enmascarar con `dm_enmascara`. Se retira `proc_dm_enmascara_tabla`.
> 2. Fachadas de `pkg_dm_enmascarar`: solo las que usan los scripts `dm_*`.
> 3. El grant `ADM_PARALLEL_EXECUTE_TASK` se mantiene en `ROL_DATAMASKING`: cada DBA recibe el rol y la instalacion se ejecuta con SYS.
> 4. Los cambios se hacen sin tocar la logica ni el funcionamiento.

| Hallazgo | Estado | Detalle |
|---|---|---|
| A1 pepper de reserva | Hecho | `func_dm_get_pepper` falla cerrado con ORA-20210 si no hay campana activa; ya no existe la clave `PEPPER_MASK` sin sufijo |
| A2 objetivo duplicado | No ejecutado | Se deja como esta: la consulta lleva el workaround `MATERIALIZE` del ORA-07445 y unificarla cambia el plan; requiere prueba en 19c antes de tocarla |
| A3 compatibilidad en 33 | Hecho | Tres SELECT dinamicos con `WHEN OTHERS NULL` sustituidos por una consulta estatica; se elimina `func_dm_dep_col_exists` |
| A4 `APPLY_COL_COLLISION` | Hecho | Retirado de las 8 listas de pasos y del catalogo |
| A5 catalogo de eventos | Hecho | Altas: `ALCANCE_ERR`, `HEREDA_DEP`, `SKIP_DEP_YA_DESHAB`. Bajas: `LIBERADA_MANUAL_DBA`, `SKIP_TABLE_TABMODE`, `APPLY_COL_COLLISION` |
| M1 variables sin uso en 34 | Hecho | `l_estado_t` y `l_detalle` |
| M2 scripts inexistentes | Hecho | Se apunta a `dm_enmascara_cancel` y a `proc_dm_pepper_purgar(<EJEC>,'Y')`; `dm_creasyn` en lugar de `crea_sinonimos` |
| M3 grant | Mantenido | Solo se corrige la justificacion en 99 |
| M4 nota del pepper en 99 | Hecho | Reescrita al modelo efimero |
| M5 fachadas de 37 | Hecho | Se elimina `func_dm_norm`; se mantienen las que usan los scripts |
| M6 `proc_dm_enmascara_tabla` | Hecho | Retirada, junto con `func_dm_csv_item` (11) y el parametro `p_tablas_csv` de `proc_dm_pre_dep` (33), que solo existian para ella |
| M7 tests con espejos | Pendiente | Solo se corrigen los nombres citados en comentarios |
| M8 nombres en 10 | Hecho | Llamadores reales en la documentacion |
| Estado `PAUSADO` | Hecho | Quitado del CHECK de `TDM_EJECUCION` y de las comprobaciones; ninguna rutina lo asignaba |
| Etiquetas de ticket | Hecho | Eliminadas de los comentarios; `KPI-03` de `dm_validar_flujo` se conserva porque es el identificador de la comprobacion |

> [!warning] Efecto a tener en cuenta al reinstalar
> El CHECK de `ck_tdm_ejec_estado` cambia (sin `PAUSADO`) y el catalogo de eventos pierde tres pasos: la reinstalacion con 98 y 99 los aplica. Una ejecucion iniciada con la version anterior y reanudada con esta no reconoceria `APPLY_COL_COLLISION`, que ya no se emitia.

**Verificacion realizada**

- Cada rutina de la especificacion tiene cuerpo en los 16 paquetes; no quedan rutinas sin llamadas ni referencias `paquete.rutina` rotas.
- Todos los eventos emitidos estan en el catalogo y 02 conserva 60 filas con la sintaxis de la semilla intacta.
- Todos los `@script` citados existen, salvo `dm_creasyn`, que vive solo en la carpeta del DBA.
- Sin Oracle disponible en este entorno no se ha compilado: la reinstalacion y las pruebas siguen siendo necesarias antes de dar el lote por cerrado.

**Referencias**

**Notas relacionadas**

- [[auditoria_industrial_motor_2026-10-10]]
- [[mapa_hardcode_motor_2026-10-10]]
- [[mapa_paquetes_motor_modular_2026-10-10]]
- [[correcciones_auditoria_estricta_nivel1_2026-09-27]]

**Fuentes consultadas**

- Codigo del motor (paquetes 10 a 40, scripts dm_*, 01, 02, 98, 99, 00_guion) en su estado del 2026-10-12.

> [!warning] Nota MATERIALIZE
> Las consultas "objetivo" con `/*+ MATERIALIZE */` (35 x5, 37 x3) evitan ORA-07445 qctcopn_internal y contencion. No unificar ni reestructurar sin prueba en 19c (A2 diferido por esto). No son duplicacion.
