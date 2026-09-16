# Plan de Cierre — Triple Auditoría del Motor FF1

**Fecha:** 2026-09-16
**Base de verificación:** inspección directa del código en `C:\Users\yair.purisaca\Documents\Claude\FF1` (copia vigente, la misma que auditó Antigravity)
**Insumos:** auditoría Gemini, auditoría Antigravity/Claude Opus 4.6, auditoría Codex, más el historial de la sesión anterior (`00_AUDITORIA_CONSOLIDADA_FF1.md`)

---

## 0. Hallazgo previo, antes de leer las tres auditorías: hay dos copias distintas en tu disco

Antes de reconciliar nada tuve que resolver esto, porque cambia la lectura de las tres auditorías:

| Carpeta | Contenido | Estado |
|---|---|---|
| `...\DATAMASKING\Scripts\instalacion\version_biyeccion\FF1` (la que estaba conectada a esta sesión) | 05 y 06 sin `07_dm_pkg_export.sql`, sin carpeta `tests/`, sin `MANIFEST.md`. `05` **todavía tiene** las 3 funciones muertas con `GET_HASH_VALUE` y **no tiene** la validación `TASK_STATUS`/`PROCESSED_WITH_ERROR` antes de `DROP_TASK`. | **Desactualizada** — es una foto de antes del cierre de Fase 0 |
| `...\Documents\Claude\FF1` | 23 archivos + `SIGAD/` + `tests/`, incluye `07_dm_pkg_export.sql`, `MANIFEST.md`, `00_AUDITORIA_CONSOLIDADA_FF1.md` | **Vigente** — es la que auditó Antigravity y la que uso como base de este informe |

Esto explica por qué **Codex** reporta como "bloqueante" cosas que **Antigravity** da por cerradas: Codex auditó `version_ff1` en un commit padre de GitHub (con el proxy bloqueado, según su propio informe), es decir, una instantánea distinta y más vieja del repo. No es que uno de los dos audite mal — auditaron código distinto.

> [!IMPORTANT]
> **Acción inmediata, antes de cualquier otra cosa:** sincroniza `version_biyeccion\FF1` reemplazándola por el contenido de `Claude\FF1` (o elimina la copia vieja y trabaja solo desde `Claude\FF1`, subiéndola tú mismo a `version_biyeccion` cuando quieras congelar una entrega). Mientras existan dos copias con el mismo nombre de carpeta, cualquier auditoría futura (tuya, de Oracle, o de otra IA) corre el riesgo de repetir este mismo malentendido.

---

## 1. Reconciliación verificada — qué está realmente cerrado y qué no

Verifiqué cada punto contra el código de `Claude\FF1`, no contra lo que dicen las auditorías entre sí.

### 1.1 Cerrado y confirmado por inspección

| Hallazgo | Reportado por | Evidencia verificada |
|---|---|---|
| C-01 — IBAN continuo truncaba el criptograma | Codex (aún abierto en su copia) | `func_especial_iban_continuo`, L699: `'ES'\|\|l_cc\|\|l_bban` sin `SUBSTR` posterior → 24 caracteres exactos |
| C-02 — chunks paralelos sin validar antes de `DROP_TASK` | Codex (aún abierto en su copia) | L383-406 de `05`: `TASK_STATUS` + `RESUME_TASK` + conteo de `PROCESSED_WITH_ERROR` + `RAISE_APPLICATION_ERROR(-20320,...)` antes del `DROP_TASK` |
| A-06 — auto-exclusión de columna sensible no bloqueaba el export | Codex (aún abierto en su copia) | L2485-2494: cuenta `SKIP_ORA00001`, lo suma a `l_mask_errors` → el estado final no llega a `FINALIZADO` → `pkg_dm_export.p_export_mask` (exige `FINALIZADO`) queda bloqueado |
| A-08 — duplicados con `GET_HASH_VALUE` (era pre-FF1) en `05` | Codex (aún abierto en su copia) | `grep GET_HASH_VALUE` → 0 resultados en `Claude\FF1` |
| A-03 (parcial) — primitivo FF1 parametrizable + vectores NIST | Gemini/Codex (piden evidencia) | `f_ff1_cifrar_raw(digitos, clave RAW, tweak RAW)` público (spec L84, body L191); `tests/pkg_dm_ff1_test.sql` existe y llama al primitivo real |

### 1.2 Abierto y confirmado — esto es lo que realmente falta

Estos cinco puntos los verifiqué yo mismo en el código vigente; no dependen de qué auditoría los mencione.

**B-01 (Codex) — `p_mask_tab` está roto por violación de FK, no solo "sin documentar".**
`tdm_mask_solicitud.ejecucion_id` es `NOT NULL` con `CONSTRAINT fk_tdm_mask_sol_ejec FOREIGN KEY (ejecucion_id) REFERENCES tdm_ejecucion(ejecucion_id)` (02, L71-73). `p_mask_tab` usa `l_dummy_ejec := -1` y llama a `func_dm_crea_sol(-1, ...)`, que hace `INSERT INTO tdm_mask_solicitud(..., ejecucion_id, ...) VALUES(..., -1, ...)`. No existe en ningún script de instalación una fila sembrada con `ejecucion_id = -1` en `tdm_ejecucion`. **Resultado: cualquier llamada a `p_mask_tab` lanza `ORA-02291` hoy mismo.** Esto es nuevo respecto a lo que veníamos cerrando — no estaba en la lista de pendientes de la sesión anterior — y es bloqueante para dar el motor por terminado, porque `p_mask_tab` es la API de enmascarado selectivo (una tabla suelta, sin pasar por una campaña completa).

**Fail-open en la propagación de dominios FK (Codex, sección 8.1) — confirmado en `p_dm_enmascara`.**
```sql
BEGIN
  proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_START', '...');
  pkg_dm_descubrimiento.proc_dm_propaga_dominios(l_esquema, l_solicitud_id, p_ejecucion_id);
  proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_END', '...');
EXCEPTION
  WHEN OTHERS THEN
    proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_ERR', 'Error en propagacion referencial: '||SQLERRM);
    -- sin RAISE: el flujo sigue hacia pepper y masking
END;
```
Compáralo con el bloque de pepper, 15 líneas más abajo, que sí hace `RAISE;` con el comentario *"sin pepper no se puede enmascarar de forma segura"*. La propagación de dominios FK es exactamente igual de crítica para la integridad referencial y hoy solo deja traza. Si esa propagación falla a mitad de camino, el enmascarado continúa igual y puede terminar `FINALIZADO` con columnas hijas desincronizadas de sus padres.

**Acoplamiento circular 04↔05 (Gemini) — sigue ahí, y ahora sé por qué existe.**
`04_dm_pkg_descubrimiento` invoca a `05_dm_pkg_enmascarar.proc_dm_trace` mediante `EXECUTE IMMEDIATE` con binds (L1242, L1322) en lugar de una llamada estática. Es la salida técnica al problema real: `05` necesita `04.proc_dm_propaga_dominios` (llamada estática, L2319) y `04` necesita trazar en la tabla de `05`, y el orden de compilación (`04` antes que `05`, ver `99_install`) no permite una referencia estática en el sentido inverso. Funciona, pero es frágil: un cambio de firma en `proc_dm_trace` no lo detecta el compilador, solo en tiempo de ejecución.

**Tipos `CHAR` obsoletos (Gemini) — 3 parámetros públicos.**
`p_cerrar IN CHAR DEFAULT 'N'`, `p_forzar_reproceso IN CHAR DEFAULT 'N'`, `p_reproceso IN CHAR DEFAULT 'N'` en `05`. `CHAR` rellena con blancos (`'N'` se compara internamente como `'N                            '`), lo que ya te ha mordido antes en este proyecto (el drift `reproceso_flag`→`forzar_reproceso` que resolviste en otra sesión fue justo este tipo de problema).

**R-01 (Antigravity) — SQL dinámico sin `DBMS_ASSERT` en `dm_validar_flujo.sql`, confirmado en 3 puntos.**
Las tres construcciones de `EXECUTE IMMEDIATE` (recompilación L211, KPI de duplicados L524, KPI-08 de huérfanos FK L659) concatenan `v_esquema`, `r.table_name`, `r.col_list`, `fk.child_owner/table` directo desde el diccionario de datos, sin pasar ninguno por `DBMS_ASSERT.ENQUOTE_NAME`/`SIMPLE_SQL_NAME`. El riesgo práctico es bajo porque los valores vienen de `dba_*`, no de input de usuario — pero es exactamente el mismo patrón que Gemini marcó como "punto ciego" en `04.func_dm_score_patron`, y este script corre con privilegios de validación/recompilación.

### 1.3 Documentado, no resuelto — decisión pendiente, no bug

**A-02 — `DETERMINISTIC` en las 13 funciones públicas de `06`.** Sigue declarado. Hay una nota en cabecera (L32-34) que documenta la restricción operativa ("no crear FBI ni MV sobre estas funciones"). Codex insiste en quitarlo del todo porque la promesa es técnicamente falsa (depende de `g_ejecucion_id`/`tdm_secreto`, no solo de los parámetros). Es una decisión de riesgo aceptado, no un olvido — pero como el proyecto se va a defender ante auditoría de Oracle/ciberseguridad, lo más limpio es **quitar la palabra clave** en vez de documentar la excepción: `DETERMINISTIC` no aporta nada aquí (no se está optimizando con FBI/MV) y es una afirmación que un auditor externo puede señalar sin que tengas una defensa mejor que "no lo usamos así".

**`WHEN OTHERS THEN NULL`** — 20 bloques solo en `05` (57 `WHEN OTHERS` en total ahí, 0 en `04`). Gemini y Codex coinciden en el diagnóstico aunque difieran en el conteo exacto (Codex cuenta sobre todo el árbol de archivos, no solo `05`). El de `A-06` y el de `pepper` ya están bien resueltos (trazan y/o relanzan); quedan los genéricos en rutinas de soporte (`proc_dm_longops`, `proc_dm_refresca_sesion`, `proc_dm_close_sol_open`, según Gemini) que conviene revisar uno por uno, no en bloque — algunos sí son limpieza legítima de sesión donde tragarse el error es correcto.

---

## 2. Plan de cierre propuesto

Orden por severidad real (bloqueante → gobernanza), no por el orden en que llegaron las auditorías.

### Fase 0 — Bloqueantes de corrección (esta iteración)

1. **B-01**: decidir el diseño correcto para `p_mask_tab` en vez de parchear el `-1`. Dos opciones limpias:
   - (a) Crear una ejecución real: `func_dm_crea_sol` recibe una `ejecucion_id` obtenida de `seq_dm_ejecucion.NEXTVAL` con un `INSERT INTO tdm_ejecucion` mínimo (estado `AD_HOC` o similar) antes de generar el pepper — así `p_mask_tab` queda dentro del mismo modelo de trazabilidad que una campaña completa.
   - (b) Si de verdad se quiere un modo "fuera de campaña", crear la fila sentinela `-1` en `tdm_ejecucion` desde `99_install` con un estado que la marque como no-campaña (y documentar que nunca se purga).
   Recomiendo (a): mantiene un solo modelo de datos y no necesitas una excepción especial en ningún KPI ni en `dm_validar_flujo`.
2. **Fail-open de propagación de dominios**: cambiar el `WHEN OTHERS` de ese bloque a `RAISE;` (igual que el de pepper), o si se decide que ciertos errores de propagación sí son recuperables, distinguirlos explícitamente en vez de un `WHEN OTHERS` genérico.
3. **R-01**: envolver `v_esquema`, `r.table_name`, `fk.child_owner/table`, etc. con `DBMS_ASSERT.SIMPLE_SQL_NAME` (o `ENQUOTE_NAME` si van entre comillas) en los 3 puntos de `dm_validar_flujo.sql`. Es una hora de trabajo y cierra la última observación de seguridad abierta en SQL dinámico.
4. **A-02**: quitar `DETERMINISTIC` de las 13 funciones públicas de `06` (spec y body); no cambia comportamiento, solo la promesa declarada al optimizador.

### Fase 1 — Limpieza de mantenibilidad (terminar el proyecto)

5. **Acoplamiento 04↔05**: no hace falta romperlo ya mismo (funciona), pero sí dejarlo explícito: mover `proc_dm_trace` a un tercer paquete pequeño (`pkg_dm_log` o similar) del que dependan tanto `04` como `05` sin ciclo. Esto también destraba poder llamar a `proc_dm_trace` de forma estática desde `04`, eliminando el `EXECUTE IMMEDIATE` con binds que hoy existe solo para esquivar el ciclo.
6. **Tipos `CHAR` obsoletos**: migrar `p_cerrar`, `p_forzar_reproceso`, `p_reproceso` a `VARCHAR2(1)`. Cambio mecánico, sin riesgo, pero conviene hacerlo antes de que otro parámetro nuevo copie el patrón por costumbre.
7. **`WHEN OTHERS THEN NULL` restantes**: pasar uno por uno los de `proc_dm_longops`, `proc_dm_refresca_sesion`, `proc_dm_close_sol_open` (y los que aparezcan al buscar `WHEN OTHERS THEN\s*NULL` en `05`) y decidir para cada uno: ¿de verdad es limpieza de sesión sin consecuencia, o está enmascarando un fallo que debería, como mínimo, ir a `proc_dm_trace`?
8. **Sincronizar `version_biyeccion\FF1`** con `Claude\FF1` (punto 0) — para que la próxima vez que alguien (tú, otra IA, un auditor) mire esa carpeta, vea el estado real del proyecto.

### Fase 2 — Evidencia y gobernanza (ya identificado en la sesión anterior, sigue vigente)

Esto no cambió con las tres auditorías nuevas — siguen abiertos y son los que corresponde atacar después de Fase 0/1:
- **A-03**: ejecutar `tests/00_run_tests_ff1.sql` en una instancia Oracle 11g real y archivar el `.log` como evidencia versionada (es el "próximo paso bloqueante" que señala la propia Antigravity).
- **A-04**: custodia del pepper (Wallet/HSM/KMS vs. tabla en claro), TTL, evidencia de destrucción.
- **A-05**: contrato de dominio explícito por componente FK (`canonicalizador + tipo + radix + longitud + tweak-id + key-version`) y postura documentada sobre multiesquema.
- **M-01**: benchmark reproducible (Feistel vs. FF1, UPDATE por columna vs. por tabla) a volumen real.
- **M-02**: documentar formalmente que el motor produce **seudonimización determinista**, no anonimización — FF1 determinista conserva igualdad, frecuencia y longitud dentro del dominio.
- **A-07**: ejecutar y validar `SIGAD/config_sigad.sql` contra el esquema real.

---

## 3. Qué se hizo (histórico de la propuesta original)

Este plan se ejecutó completo — Fase 0 y Fase 1 — en la misma sesión en la que
se escribió. Se dejó el texto original de arriba sin tocar porque documenta
correctamente el diagnóstico contra el que se verificó cada cierre; el
detalle de qué se cambió y dónde está en la sección 4 de este documento y,
con más profundidad técnica (línea por línea, código antes/después), en la
sección 3 y 6 de `MANIFEST.md`.

---

## 4. Cierre — 2026-09-16

**Fase 0 (bloqueantes de corrección) — CERRADA:**

1. **B-01**: implementada la opción **(a)** recomendada arriba. `p_mask_tab`
   ahora obtiene `l_ejecucion_id := seq_dm_ejecucion.NEXTVAL`, inserta una fila
   real en `tdm_ejecucion` (fase `ENMASCARAMIENTO`, estado `EJECUTANDO`) antes
   de generar el pepper, y sigue el mismo modelo de trazabilidad que una
   campaña completa (incluye purga del pepper en el handler de excepción, que
   la versión `-1` original nunca hacía). No quedó ninguna excepción especial
   para KPIs ni `dm_validar_flujo`.
2. **Fail-open de propagación**: añadido `RAISE;` tras el `proc_dm_trace(...,
   'PROPAGA_ERR', ...)` en `p_dm_enmascara`. Un fallo de propagación de
   dominios FK ahora detiene el flujo igual que un fallo de pepper, en vez de
   continuar hacia el masking con la integridad referencial en duda.
3. **R-01**: `dm_validar_flujo.sql` sanitizado en los 3 puntos señalados
   (recompilación, KPI de duplicados, KPI-08 de huérfanos FK) más KPI-04/05
   (DNI/NIE, IBAN) que aparecieron al revisar el archivo completo —
   `DBMS_ASSERT.SIMPLE_SQL_NAME`/`ENQUOTE_NAME` según corresponde en cada
   concatenación dinámica.
4. **A-02**: eliminado (no solo documentado) el `DETERMINISTIC` de las 12
   funciones públicas de `06` (spec + body, 24 sitios). Se optó por quitar la
   promesa falsa al optimizador en vez de mantenerla con nota al margen, tal
   como razona el propio punto 1.3 de arriba.

**Fase 1 (mantenibilidad) — CERRADA:**

5. **Acoplamiento 04↔05**: resuelto con un paquete nuevo,
   `03b_dm_pkg_trazabilidad.sql`, sin dependencias de `04` ni `05`, que
   compila antes que ambos. `04` y `05` ahora llaman a
   `pkg_dm_trazabilidad.proc_dm_trace`/`proc_dm_log_ejec_error` de forma
   estática; se eliminaron los dos `EXECUTE IMMEDIATE` con binds que existían
   solo para esquivar el ciclo de compilación.
6. **Tipos `CHAR` obsoletos**: `p_cerrar`, `p_forzar_reproceso`,
   `p_reproceso` (y sus variables locales `l_repro`/`l_reproceso`) migrados a
   `VARCHAR2(1)` en los 9 sitios donde aparecían.
7. **`WHEN OTHERS THEN NULL` restantes**: revisados uno por uno como se
   propuso. Resultado de la clasificación:
   - `func_dm_tiene_regla` y `proc_dm_upsert_excepcion_col` → **eran
     enmascaramiento real de errores** (el primero devolvía "sin regla" ante
     cualquier fallo, el segundo tragaba errores de una API de configuración
     usada por DBA) → cambiados a `RAISE`.
   - Dos bloques de `EXECUTE IMMEDIATE 'UPDATE tdm_mask_solicitud SET
     forzar_full = ...'` → **eran código muerto**: la columna `forzar_full`
     no existe en `tdm_mask_solicitud`, así que siempre fallaban con
     `ORA-00904` y el error se tragaba sin que nadie lo notara → eliminados.
   - `proc_dm_longops`, `proc_dm_refresca_sesion` → confirmados como
     **limpieza de sesión legítima** (best-effort, sin impacto si fallan) →
     se dejaron igual, con un comentario que explica por qué es intencional.
   - `proc_dm_upd_ejec`, `proc_dm_close_sol_open` → les faltaba traza →
     añadida llamada a `proc_dm_trace` en sus handlers de excepción para que
     un fallo ahí quede como evidencia, aunque no se relance.
8. **Sincronización de `version_biyeccion\FF1`**: hecha. Se confirmó que no
   había divergencia de *contenido* real entre lo que auditó Antigravity y lo
   que Codex/Gemini vieron aparte del problema de snapshot — el problema era
   que `version_biyeccion\FF1` en disco era una copia vieja de antes del
   cierre de la Fase 0 de la sesión anterior. Se sobrescribió completa con el
   contenido de `Claude\FF1` (fuente de verdad).

**Además, aparecieron y se cerraron durante la Fase 1** (no estaban en el
diagnóstico original de este plan): R-03 (bloque comentado obsoleto de
semillas duplicadas en `02_dm_enmascaramiento_objetos.sql`), R-04 (3 líneas
sin prefijo `--` en `97_configurar_excepciones.sql` que rompían la ejecución
literal del script), R-05 (`pkg_dm_export` y `pkg_dm_trazabilidad` ausentes en
`98_uninstall.sql`), y un hardcodeo `-1, -1` en una llamada de traza de `04`
que se corrigió de paso al migrarla a `pkg_dm_trazabilidad`.

**Fase 2 (evidencia y gobernanza) — solo la parte documental:** M-02, A-05 y
A-04 (que eran de diseño/gobernanza, no de código) tienen ahora su documento
correspondiente (`M02_seudonimizacion_vs_anonimizacion.md`,
`A05_contrato_de_dominio_FK.md`, `A04_custodia_del_pepper.md`). **A-03, A-07 y
M-01 siguen sin ejecutar** porque requieren una instancia Oracle real en
marcha (correr tests, correr `config_sigad.sql` contra un esquema, medir
tiempos) — no son tareas que se puedan completar sin ese entorno.

**Advertencia que aplica a todo lo anterior:** ningún cambio de código de esta
sesión se compiló contra una instancia Oracle real (no hay una disponible en
este entorno). La verificación hecha fue lectura línea por línea contra el
contexto de cada paquete y un chequeo mecánico de balance `BEGIN`/`END` — no
sustituye a compilar los 6 paquetes en un 11g+ de desarrollo y confirmar
`STATUS='VALID'` sin filas en `DBA_ERRORS`, paso que sigue siendo obligatorio
antes de promover esto a QA/PRE.
