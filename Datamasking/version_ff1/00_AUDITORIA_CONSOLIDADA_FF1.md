# Auditoría consolidada — migración Feistel → FF1

**Fecha de consolidación:** 2026-09-14
**Fuentes fusionadas:** auditoría técnica estática (Antigravity/Codex), aclaración
de cobertura y trazabilidad (Codex, commit 9a26896) y verificación independiente
de Claude sobre el código de `version_ff1`.
**Naturaleza:** revisión **estática** del repositorio. No hubo instancia Oracle
11g, datos reales del cliente, grants efectivos ni métricas AWR/ASH.

## 1. Veredicto

**NO-GO para producción regulada** hasta cerrar los hallazgos críticos y altos y
generar evidencia ejecutable. La primitiva criptográfica está bien construida
(FF1 de 10 rondas sobre AES-128, tweak estable por dominio, pepper CSPRNG por
campaña), pero hay defectos de borde en normalización, atomicidad del paralelo y
fail-closed que pueden entregar datos incoherentes o PII sin enmascarar.

Descripción defendible mientras tanto: *"implementación propia basada en
FF1/AES-128 para seudonimización determinista, pendiente de validación de
conformidad y cierre de controles operativos"*. **No usar "certificado" ni
"conforme NIST".**

## 2. Alcance y trazabilidad (qué se revisó y con qué profundidad)

| Componente | Archivo | Profundidad |
|---|---|---|
| Núcleo FF1, AES, tweak, clave, semilla textual | `06_dm_pkg_func_mask.sql` | Revisión profunda |
| Pepper efímero + wrappers paralelos | `05`, `dm_pepper_purgar.sql` | Revisión profunda |
| Propagación Union-Find FK | `04_dm_pkg_descubrimiento.sql` | Revisión profunda |
| Constraints, commits, autoexclusión, POST, export | `05_dm_pkg_enmascarar.sql` | Revisión profunda |
| KPI de validación | `dm_validar_flujo.sql` | Revisión profunda |
| Orden de campaña | `00_guion_uso_datamasking.sql` | Revisión profunda |
| Modelo_Feistel 01..06, runbook, handoffs, SIGAD | versión anterior | Contexto evolutivo |
| Modelo_Afin, version_sin_biyeccion | versiones previas | Contexto histórico |

**No verificable solo con el repositorio (requiere ejecución):** que los paquetes
compilen en 11g; coincidencia byte a byte con vectores NIST; ausencia de
colisiones sobre datos reales; preservación de todas las FK reales; rendimiento a
volumen; que el pepper quede fuera de backups/redo/UNDO/flashback; y adecuación
de grants efectivos y separación de funciones.

## 3. Hallazgos consolidados

Estado de verificación de Claude: **[C]** confirmado en código (autor o
inspección directa) · **[C*]** confirmado con matiz de riesgo práctico ·
**[G]** válido, es control de gobernanza · **[E]** correcto: el algoritmo es
válido pero falta evidencia empaquetada.

| ID | Sev. | Componente | Descripción | Verif. | Cierre |
|---|---|---|---|---|---|
| **C-01** | Crítico | `06` `func_especial_iban_continuo` | Trunca la salida a la longitud de entrada → pierde dígitos del criptograma → biyección rota | **[C]** autor | Código |
| **C-02** | Crítico | `05` `proc_dm_ejecuta_update_seguro` | Tras `RUN_TASK` hace `DROP_TASK` sin comprobar estado terminal ni chunks `PROCESSED_WITH_ERROR`; usa `num_rows` estimado como procesado | **[C]** inspección directa | Código |
| **A-01** | Alto | `06` `func_nif`, `func_especial_doc_segun_tipo` | Normalización no inyectiva: control no validado; `doc_segun_tipo` elimina no-dígitos y lanza excepción con cero dígitos; **NIE diverge entre `func_nif` (prefijo conservado) y `doc_segun_tipo` (prefijo por HMAC)**; formatos no reconocidos caen a hash | **[C]** | Código |
| **A-02** | Alto | `06` spec | `DETERMINISTIC` es promesa falsa: la función depende de `g_ejecucion_id` y de `tdm_secreto` | **[C*]** riesgo bajo en uso actual (solo en UPDATE), real si hay FBI/MV | Código |
| **A-03** | Alto | conjunto | Conformidad NIST no demostrada en el repo: sin fixture de vectores, sin decrypt round-trip, sin evidencia de compilación | **[E]** algoritmo verificado en sandbox (2 vectores NIST + equivalente PL/SQL + biyección 200k); falta empaquetarlo | Test |
| **A-04** | Alto | `02`/`05`/`99`/`dm_pepper_purgar` | Custodia del secreto: hex en tabla ordinaria; sin wallet/HSM/auditoría; purga manual (`p_export_mask` no la ejecuta); `DELETE` no prueba irrecuperabilidad; `DUP_VAL_ON_INDEX` sin `ROLLBACK` explícito | **[G]** + algo de código | Gobernanza + Código |
| **A-05** | Alto | `04`/`05`/`06`/`00_guion` | Propagación FK necesaria pero no suficiente: el tweak usa constantes `IDENTIDAD/CUENTA/IBAN`, no el `dominio` persistido; la igualdad exige además mismo parser/longitud/función; **la API recibe un solo esquema, lo que contradice el invariante multiesquema del runbook** | **[C]** | Código + Diseño |
| **A-06** | Alto | `05` handler colisión | El auto-`EXCLUDE` ante `ORA-00001` revierte el UPDATE → la columna sensible queda con **PII original** y la campaña avanza | **[C]** autor | Código |
| **A-07** | Alto | `SIGAD/` + config | El kit operativo SIGAD (reglas, coherencias, caso, reportes) no está portado a FF1. El motor **no** tiene nombres SIGAD hardcodeados: la especialidad se expresa como datos en `tdm_excepcion_col`, `tdm_mask_regla_esp` y `tdm_mask_relacion_sync`. Falta el conjunto de filas (config) y su ejecución; `IBAN_ES_CONTINUO` está afectado por C-01 | **[C]** ausente en la entrega | Config (datos) + Probar |
| **A-08** | Alto | `05` funciones `func_dm_doc_tsk_keep_ends` / `func_dm_doc_tipo` / `func_dm_iban_sigad` | Duplicados **muertos** de la era Feistel (usan `GET_HASH_VALUE`, no FF1, no biyectivos), declarados **públicos** pero no invocados por el orquestador (usa los `func_especial_*` de `06`). Trampa de corrección: pueden llamarse y saltarse FF1. Naming acoplado a "SIGAD" | **[C]** inspección directa | Código (borrar + de-brand) |
| **M-01** | Medio | `05` | Coste/atomicidad sin medir: un `UPDATE`+`COMMIT` por columna (k pasadas); "~5×" es estimación, no benchmark | **[C*]** | Benchmark + Código |
| **M-02** | Medio | diseño | FPE determinista conserva longitud, igualdad y frecuencias (seudonimización, no anonimización); DNI/NIE/CIF comparten `IDENTIDAD` y conservan prefijos | **[C]** por diseño | Documentar |
| **M-03** | Medio | `06` | Clave = SHA-1 del **hex** del pepper; tweak = SHA-1 sin clave; sin versionado de KDF; `CAST_TO_RAW` depende del charset para texto no ASCII (acentos) → semillas textuales no reproducibles entre entornos | **[C]** | Código + NLS |
| **M-04** | Medio | `dm_validar_flujo` | KPIs miran estado final, no prueban inyectividad ni detectan una columna autoexcluida con PII; sin manifiesto firmado de entrega | **[C]** | Test + Proceso |

## 3.1 Arquitectura SIGAD y portabilidad (análisis y decisión)

**Análisis.** SIGAD es un esquema grande con **relaciones no referenciadas** (sin
FK). Sus tratamientos especiales, según su documento, son de dos naturalezas:

- **A — tratamiento por columna** (qué función aplicar): OFUSCAR S/N, NIF/NIE/
  Pasaporte según `IDTIPODOCUMENTO`, keep-ends en `TSKPCRUNIFICARALUMNOS/
  FAMILIARES`, IBAN continuo en `CENCUENTABANCO.NUMEROCUENTA`.
- **B — coherencia entre tablas por relación lógica sin FK**: copiar e-mail y
  nombre/apellidos/documento desde `SEGUSUARIO` hacia `PERPROFESOR`, `CENALUMNO`
  y `CENFAMILIAR` por `IDUSUARIO`.

La categoría A se resuelve con `tdm_excepcion_col` (selección) y
`tdm_mask_regla_esp` (tratamiento). La categoría B **no** es expresable con
excepciones (una excepción no puede ordenar "copia el valor enmascarado de T1
sobre T2 por una clave de join"): requiere la **pasada de sincronización**
`tdm_mask_relacion_sync`. Por eso existe el "sync": es la herramienta correcta
para relaciones que el Union-Find no ve por carecer de FK, y no se puede sustituir
por excepciones ni eliminar.

**Verificación:** el motor (`04`/`05`/`06`) **no** contiene nombres de tablas ni
columnas de SIGAD. La especialidad ya vive como **datos** en las tres tablas de
config. Las funciones `func_especial_*` son algoritmos **genéricos**
(doc-por-tipo, keep-ends, IBAN continuo), seleccionados por configuración; no son
código de SIGAD.

**Decisión de diseño (acordada) — motor genérico, config intercambiable:**

1. **El motor se queda genérico y portable.** El *core* real es genérico
   (descubrimiento, propagación FK, tratamientos, sync, trazabilidad). Lo que
   cambia entre clientes/empresas son **las reglas (datos)**, no el código. Debe
   poder presentarse en otra organización cambiando solo la configuración.
2. **La pasada de sync (`tdm_mask_relacion_sync`) se conserva como capacidad
   genérica del motor, pero DOCUMENTADA y EXTRAÍBLE**, para poder aislarla o
   retirarla en el futuro si un despliegue no la necesita.
3. **SIGAD = solo datos.** Todo lo específico de SIGAD se entrega como
   `SIGAD/config_sigad.sql`: `INSERT` en `tdm_excepcion_col`,
   `tdm_mask_regla_esp` y `tdm_mask_relacion_sync`. Esto cierra A-07 sin meter
   código de cliente en el motor.
4. **Se elimina el acoplamiento residual** (A-08): borrar los tres duplicados
   hash muertos de `05` y de-brandear el naming (`IBAN_CONTINUO`, no
   `IBAN_SIGAD`; sin comentarios "para SIGAD").
5. **Desajustes función↔documento a corregir** (los descubre el propio doc):
   - **Pasaporte**: el doc pide sustituir cada dígito por otro; hoy se reemplaza
     por `'9'` fijo (colisiona). Debe ser sustitución determinista por dígito.
   - **NIE (resuelve A-01)**: la letra X/Y/Z sale del **primer dígito del número
     generado** (0/1/2), no de un HMAC ni del prefijo de entrada. Aplicándolo
     igual en `func_nif` y `doc_segun_tipo` desaparece la divergencia entre rutas.
   - **IBAN continuo (C-01)**: 24 caracteres exactos, sin truncar.

**Criterio de portabilidad (nuevo gate de aceptación):** cero literales de
cliente en `04`/`05`/`06`; toda regla de negocio en tablas de config; un despliegue
en otra organización debe consistir en cargar un `config_<cliente>.sql` distinto
sin recompilar el motor. La documentación debe marcar `tdm_mask_relacion_sync`
como módulo separable.



La auditoría acierta al corregir varios enunciados que yo había dado por buenos:

- **"Certificado / conforme NIST"** → incorrecto. Es una implementación *basada en*
  FF1; verifiqué vectores en sandbox, no en el repo.
- **"Biyección garantizada en todo lo numérico"** → solo en núcleos canónicos
  válidos. Control/normalización/truncado introducen colisiones (C-01, A-01).
- **"`doc_segun_tipo` coincide con `func_nif`"** → cierto solo para **DNI**; en
  **NIE** el prefijo diverge (A-01).
- **"Semilla textual 60 bits"** → son **56 bits** (14 hex en el código).
- **"Tras purgar, el dato es irreversible"** → un `DELETE` no lo demuestra
  (redo/UNDO/flashback/backups) (A-04).
- **"Invariante: dos esquemas con FK van en la misma ejecución"** → no aplicable:
  la API recibe un solo esquema (A-05).
- **"`DETERMINISTIC` ayuda al caché"** → declaración semánticamente incorrecta;
  no es una garantía de memoización (A-02).
- **"~5× CPU"** → estimación sin benchmark (M-01).

## 5. Plan de remediación priorizado

**Fase 0 — Código, fail-closed (bloqueante para GO):**
1. C-01: formato admitido explícito (BBAN 20 / IBAN ES 24), extraer BBAN exacto,
   **nunca truncar**; rechazar (no normalizar) entradas inválidas.
2. C-02: exigir estado terminal de la tarea, bloquear si hay
   `PROCESSED_WITH_ERROR`, contar filas reales por chunk, persistir diagnóstico
   antes de `DROP_TASK`, y **fallar cerrado** antes de POST/export.
3. A-06: auto-exclusión de columna sensible = **error fatal** que impide
   `FINALIZADO` y export.
4. A-01: parser canónico único por tipo; validar control y formato antes de
   enmascarar; unificar la ruta padre/hija (misma función para NIE); cuarentena
   para inválidos; guardar la excepción de cero dígitos.
5. A-05 (parte código): que el tweak/función/longitud coincidan por extremo FK;
   detectar y bloquear FK fuera de alcance.
6. A-04 (parte código): `ROLLBACK` explícito en la carrera `DUP_VAL_ON_INDEX`;
   runbook/export que falle cerrado si el pepper quedó sin purgar.
7. M-03: fijar UTF-8 explícito en entradas textuales; versionar KDF/tweak.

**Fase 1 — Paquete de pruebas (cierra A-03 y parte de M-04):**
vectores oficiales FF1 encrypt **y decrypt**, round-trip `decrypt(encrypt(x))=x`,
property tests (determinismo intra-campaña, separación entre campañas),
negative tests (caracteres inválidos, control incorrecto, cero dígitos, Unicode,
límites, NULL, ceros a la izquierda), biyección exhaustiva en dominios pequeños
permitidos y `DBA_ERRORS` vacío por versión Oracle.

**Fase 2 — Rendimiento (cierra M-01):**
agrupar columnas por tabla en un solo `UPDATE`; precifrar valores distintos donde
compense; checkpoint idempotente que no recifre columnas confirmadas; benchmark
A/B Feistel vs FF1 (1M y 10M filas; cardinalidades 1/50/100 %; CPU, elapsed,
logical reads, redo, undo, waits).

**Fase 3 — Gobernanza (Riesgo/DPO, no solo Desarrollo):**
custodia del secreto (wallet/HSM/servicio de secretos, KDF documentada, auditoría
de accesos, TTL, inventario de copias, política de destrucción/escrow); contrato
de dominio por componente FK `(parser, formato, radix, longitud, tweak-id,
key-version)`; plan multiesquema o exclusión explícita de FK cross-schema;
manifiesto firmado de entrega (commit, ejecución, config, hash de log/dump);
clasificar el resultado como **seudonimización** (M-02).

**SIGAD (A-07/A-08) — motor genérico + config:**
- Borrar los duplicados hash muertos de `05` y de-brandear naming (A-08).
- Corregir Pasaporte (sustitución por dígito), NIE (letra desde el 1er dígito
  generado; resuelve A-01) e IBAN continuo (C-01, 24 chars sin truncar).
- Entregar `SIGAD/config_sigad.sql` = solo `INSERT` de reglas/coherencias/
  exclusiones; ejecutarlo y validar **después** de C-01. Requiere el Excel de
  columnas (`OFUSCAR`/`CONDICIONES ESPECIALES`) para completarlo.
- Verificar portabilidad: cero literales de cliente en el motor; `relacion_sync`
  documentado como módulo separable.

## 6. Gates de aceptación para producción

- **Cripto:** compilación limpia por versión soportada; vectores oficiales
  encrypt/decrypt reproducibles en CI; property/negative tests en verde.
- **Funcional/RI:** matriz por función con entrada canónica/no canónica; FK
  simples, compuestas, cadenas, ciclos, self-FK, disabled y cross-schema;
  `ENABLE VALIDATE` de todas las constraints originales; cero huérfanos; prueba
  explícita de IBAN continuo 20/24; cualquier fallo impide `FINALIZADO` y export.
- **Operativo/rendimiento:** fallo inyectado en un chunk hace fallar campaña y
  export; interrupción/resume sin doble cifrado; dos campañas concurrentes con
  claves distintas y sin contaminación de caché; benchmark aprobado a volumen;
  ensayo de expiración/purga y verificación en backups/flashback.
- **Portabilidad:** cero literales de cliente en `04`/`05`/`06`; toda regla de
  negocio en tablas de config; despliegue en otra organización = cargar un
  `config_<cliente>.sql` distinto sin recompilar; `tdm_mask_relacion_sync`
  documentado como módulo separable.
- **Entrega:** cero errores/chunks/autoexclusiones sensibles, constraints
  restauradas y validadas, mismo recuento, manifiesto firmado.

## 7. Evidencia disponible hoy vs. pendiente

- **Disponible (sandbox externo, no en repo):** FF1 encrypt coincide con los dos
  vectores oficiales del NIST; una reimplementación con la misma lógica de
  bytes/hex del PL/SQL coincide igual; biyección sin colisiones en 200k DNI con
  clave y tweak reales. — Sirve como indicio fuerte de corrección del algoritmo,
  **no** como conformidad del entregable.
- **Pendiente (para pasar de "validado por inspección" a "probado por
  ejecución"):** todo lo del gate cripto en el propio repo/CI y una instancia
  Oracle 11g, más el decrypt round-trip que hoy no existe en el paquete.

## 8. Estado tras iteración de correcciones (2026-09-15, cierre de bloqueantes)

Cerrados en esta iteración, con peer-review y verificación estática:

- **C-02 — CERRADO.** `proc_dm_ejecuta_update_seguro` ya valida el estado terminal:
  `TASK_STATUS`, `RESUME_TASK` para transitorios, consulta de
  `user_parallel_execute_chunks` con `PROCESSED_WITH_ERROR`, y `RAISE`
  (ORA-20320) capturando diagnóstico **antes** de `DROP_TASK`. Variables
  declaradas correctamente. **Nota:** la copia auditada por Antigravity era
  anterior; hay que reconciliar cuál 05 es la autoritativa (esta lo tiene).
- **A-06 — CERRADO (fallo cerrado).** Una columna sensible auto-excluida por
  `ORA-00001` deja traza `SKIP_ORA00001`; en la finalización se cuenta como error
  ⇒ el estado pasa a `ERROR` (no `FINALIZADO`) ⇒ `p_export_mask` (que exige
  `FINALIZADO`) queda bloqueado. Ya no hay skip silencioso con PII exportable.
- **func_cuenta (hallazgo 4.2.2 de Antigravity) — CERRADO.** Eliminado el
  `WHEN OTHERS` que caía a hash (rompía biyección). Se acota la entrada a
  `target_len` (≤20) antes de `TO_NUMBER`, por lo que FF1 siempre aplica y es
  biyectivo; sin dígitos, se conserva el valor.
- **M-03 — CERRADO.** `f_hash` normaliza el texto con
  `UTL_I18N.STRING_TO_RAW(..., 'AL32UTF8')`: la semilla textual ya no depende del
  `NLS_CHARACTERSET` del entorno (acentos reproducibles entre bases).
- **A-02 — DOCUMENTADO.** Nota de restricción en la cabecera de `06`: no crear
  FBI ni MV sobre estas funciones (son DETERMINISTIC solo dentro de una campaña).

Pendientes (no defectos de código bloqueantes): **A-03** (empaquetar vectores
NIST + decrypt round-trip como test en repo/CI), **A-04** (custodia del secreto —
gobernanza), **A-05** (contrato de dominio por componente FK / multiesquema —
diseño), **M-01** (benchmark), **M-02** (documentar seudonimización), **A-07**
(ejecutar y validar `config_sigad.sql` en instancia). La compilación real en 11g
sigue siendo la prueba definitiva.

## 9. A-03 — evidencia de conformidad FF1 (artefacto entregado, 2026-09-15)

Se cierra el **artefacto reproducible** que pedía A-03 (queda su ejecución en una
instancia real como último paso de evidencia):

- **Refactor sin duplicar el algoritmo:** el núcleo FF1 de cifrado se expuso como
  primitivo `pkg_dm_func_mask.f_ff1_cifrar_raw(digitos, clave, tweak)` (fuente
  única de verdad). El wrapper de producción `f_ff1_cifra` lo llama con la clave
  derivada del pepper. Así el test valida el **código real**, no una copia.
- **Seguridad preservada:** el **descifrado NO viaja en el motor de producción**.
  Vive solo en `tests/pkg_dm_ff1_test.sql` (paquete `pkg_dm_ff1_test`), que **no**
  se instala con `99`. La irreversibilidad operativa sigue basándose en destruir
  el pepper; el test usa las **claves conocidas del NIST**, nunca el pepper real.
- **Batería (`pkg_dm_ff1_test.p_run_all`):** (1) vectores oficiales NIST
  SP 800-38G byte a byte —muestras 1 y 2—; (2) round-trip
  `descifrar(cifrar(x))=x` sobre 2000 valores + descifrado de los propios
  vectores; (3) biyección exhaustiva en `10^4` (0000..9999, cero colisiones,
  imagen completa); (4) determinismo y separación por tweak. Falla ⇒ `ORA-20900`
  (CI en rojo).
- **Evidencia de compilación:** `tests/00_run_tests_ff1.sql` deja
  `test_ff1_<fecha>.log` con el estado `VALID` de los paquetes y `DBA_ERRORS`
  vacío, además del resultado de la batería.
- El descifrado del test fue verificado fuera de banda contra los vectores NIST y
  con round-trip (30k) antes del port; incluye la normalización de `MOD` negativo
  de Oracle en la resta modular.

Pendiente de A-03: **ejecutar** `@@tests/00_run_tests_ff1.sql` en una instancia
Oracle 11g y archivar el `.log` como evidencia versionada (no reproducible desde
aquí por no haber instancia).
