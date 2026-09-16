# MANIFEST — Datamasking versión FF1

**Fecha:** 2026-09-15 (última actualización de contenido: 2026-09-16 — cierre
de triple auditoría Gemini/Antigravity/Codex, ver sección 6; instalación y
tests FF1 ejecutados y en verde contra instancia real, ver sección 7)
**Motor:** Oracle 11g+, esquema `ASTSYSADMIN`, rol `ROL_DATAMASKING`, sin wallet/TDE.
**Núcleo cripto:** FF1 (NIST SP 800-38G) sobre AES-128, tweak por dominio, pepper
efímero por campaña.
**Estado global:** apto para QA, con los bloqueantes de código de la triple
auditoría del 2026-09-16 cerrados (ver sección 6) y con evidencia real de
instalación limpia + conformidad FF1 (A-03 CERRADO, ver sección 7). **NO-GO
para producción regulada** hasta cerrar gobernanza (A-04), diseño (A-05) y
ejecutar el flujo funcional completo + `config_sigad` (A-07) en el esquema
real — esto sigue pendiente, en curso a la fecha de esta actualización.

Leyenda de estado por archivo:
**NUEVO** creado en esta línea de trabajo · **MODIF** modificado respecto a
Modelo_Feistel · **IGUAL** copiado sin cambios · **TEST** solo QA (no producción).

---

## 1. Índice de objetos

| Archivo | Estado | Rol |
|---|---|---|
| `00_ESTRATEGIA_Y_ANALISIS_FF1.md` | NUEVO | Estrategia de migración + análisis |
| `00_AUDITORIA_CONSOLIDADA_FF1.md` | NUEVO | Auditoría consolidada + estado de hallazgos |
| `00_guion_uso_datamasking.sql` | MODIF | Runbook del flujo FF1 |
| `01_dm_descubrimiento_objetos.sql` | IGUAL | DDL descubrimiento |
| `02_dm_enmascaramiento_objetos.sql` | MODIF | DDL enmascaramiento |
| `03_dm_descubrimiento_carga_reglas.sql` | IGUAL | Semilla de reglas de descubrimiento |
| `03b_dm_pkg_trazabilidad.sql` | NUEVO | Paquete independiente de trazabilidad/errores (2026-09-16) |
| `04_dm_pkg_descubrimiento.sql` | MODIF | Paquete de descubrimiento |
| `05_dm_pkg_enmascarar.sql` | MODIF | Orquestador de enmascaramiento |
| `06_dm_pkg_func_mask.sql` | NUEVO/MODIF | Núcleo cripto FF1 + funciones de formato |
| `07_dm_pkg_export.sql` | NUEVO | Export Data Pump (companion, fuera del motor) |
| `97_configurar_excepciones.sql` | MODIF | Plantillas de excepciones |
| `98_uninstall.sql` | MODIF | Desinstalador |
| `99_install_datamasking.sql` | MODIF | Instalador ordenado |
| `crear_sinonimos.sql` | MODIF | Sinónimos privados por DBA |
| `dm_descubre.sql` | IGUAL | Wrapper: descubrimiento |
| `dm_enmascara.sql` | IGUAL | Wrapper: enmascaramiento por ejecución |
| `dm_enmascara_id.sql` | IGUAL | Wrapper: enmascaramiento por identificador |
| `dm_exportcsv.sql` | IGUAL | Export CSV de la clasificación |
| `dm_recompilar.sql` | IGUAL | Recompilador de inválidos |
| `dm_validar_flujo.sql` | IGUAL | KPIs de validación post-mask |
| `dm_pepper_purgar.sql` | NUEVO | Wrapper: purga del pepper por ejecución |
| `SIGAD/config_sigad.sql` | NUEVO | Configuración (datos) del cliente SIGAD |
| `tests/pkg_dm_ff1_test.sql` | NUEVO/TEST | Conformidad FF1 (vectores NIST + decrypt) |
| `tests/00_run_tests_ff1.sql` | NUEVO/TEST | Runner de pruebas + evidencia de compilación |

---

## 2. Detalle técnico por objeto

### 06_dm_pkg_func_mask.sql — núcleo cripto (NUEVO/MODIF)
**Hecho:**
- Migrado el primitivo numérico de la red Feistel propia (4 rondas, HMAC-SHA1
  truncado 56 bits) a **FF1** (10 rondas, AES-128 CBC-MAC), verificado contra los
  dos vectores oficiales del NIST.
- **Tweak por dominio** vía `f_ajuste_dominio(identificador)` (SHA-1, 8 bytes),
  dependiente solo del identificador → coherente con la propagación FK.
- **Clave AES** = primeros 16 bytes de `SHA-1(pepper)` (`f_clave_aes`), cacheada
  por sesión.
- Reducción modular por **Horner** byte a byte → exacta en `NUMBER` sin desbordar.
- **CIF, `doc_segun_tipo`, `iban_continuo`** ahora **biyectivos** vía FF1.
- **NIE coherente** entre rutas (`f_enmascara_nie`): prefijo X/Y/Z derivado del
  número generado; misma salida por `func_nif` y `func_especial_doc_segun_tipo`
  (cierra A-01).
- **Pasaporte** por `f_cifra_digitos_en_texto`: sustituye cada dígito (FF1
  conjunto) y conserva letras/separadores (antes ponía `'9'` fijo).
- **C-01**: `func_especial_iban_continuo` y el fallback de `func_iban` ya **no
  truncan** → 24 caracteres exactos.
- **`func_cuenta`**: eliminado el `WHEN OTHERS` que caía a hash; acota dígitos a
  `target_len` (≤20) → FF1 siempre aplica, biyectivo.
- **M-03**: `f_hash` usa `UTL_I18N.STRING_TO_RAW(..., 'AL32UTF8')` → semilla de
  texto independiente del `NLS_CHARACTERSET`.
- **A-03**: expuesto el primitivo `f_ff1_cifrar_raw(digitos, clave, tweak)` como
  fuente única; `f_ff1_cifra` es su wrapper con la clave del pepper.
- **A-02** (documentado): nota en cabecera — no crear FBI ni MV sobre estas
  funciones (`DETERMINISTIC` solo dentro de una campaña).

**No hecho / límites:** dominios de texto (nombre, dirección, email, teléfono)
siguen **no biyectivos por diseño** (seudonimización, no anonimización); AES-128
(no 256) por compatibilidad 11g y vectores de referencia; dominios numéricos
`< 10^6` son biyectivos pero criptográficamente débiles por fuerza bruta
(inherente al FPE).

### 05_dm_pkg_enmascarar.sql — orquestador (MODIF)
**Hecho:**
- **Pepper efímero por `ejecucion_id`**: `proc_dm_pepper_generar` (idempotente,
  `RANDOMBYTES(32)`, `COMMIT` antes del paralelo, *race-safe*) y
  `p_dm_pepper_purgar(ejecucion_id)`. Cada worker fija su `ejecucion_id` en el
  chunk (`set_ejecucion`) → dos esquemas concurrentes no colisionan.
- **C-02**: tras `RUN_TASK`, valida `TASK_STATUS`, reintenta con `RESUME_TASK`,
  consulta `user_parallel_execute_chunks` por `PROCESSED_WITH_ERROR` y hace
  `RAISE`-20320 (fallo cerrado) capturando diagnóstico antes de `DROP_TASK`.
- **A-06**: una columna sensible auto-excluida por `ORA-00001` cuenta como error
  → estado `ERROR` (no `FINALIZADO`) → bloquea el export.
- Depurado el **código muerto del mapa** (`tdm_mask_key_map`, `IF FALSE`,
  `proc_dm_build_domain_map`, `proc_dm_pre_build_maps`, `l_dominio`).
- **A-08**: eliminados los 3 duplicados hash de la era Feistel
  (`func_dm_doc_tipo`, `func_dm_iban_sigad`, `func_dm_doc_tsk_keep_ends`) y
  de-brandeado el naming; el orquestador usa `pkg_dm_func_mask.func_especial_*`.
- **DataPump extraído**: `p_export_mask` movido a `pkg_dm_export` (ver 07).

**No hecho / pendiente:** las mejoras de **rendimiento** (M-01) NO están
implementadas — `UPDATE` batcheado por tabla y precifrado por valor distinto
siguen como recomendación; el `A-05` (contrato de dominio por componente FK,
multiesquema) no está resuelto en el orquestador.

### 07_dm_pkg_export.sql — export (NUEVO)
**Hecho:** `pkg_dm_export.p_export_mask` (Data Pump) sacado del motor como
companion; solo dependía de `f_norm` (replicado local). Exige estado
`FINALIZADO` (respeta el fallo cerrado). **No hecho:** no cambia la lógica de
export; requiere `DIRECTORY` Oracle y privilegios de Data Pump del entorno.

### 02_dm_enmascaramiento_objetos.sql — DDL (MODIF)
**Hecho:** `tdm_secreto.clave` ampliada a `VARCHAR2(64)` para
`PEPPER_MASK:<ejecucion_id>`. **No hecho:** sin otros cambios de esquema; el
pepper sigue en tabla ordinaria (ver A-04).

### 99_install_datamasking.sql — instalador (MODIF)
**Hecho:** compila `06`→`05`→`07`; grants a `ROL_DATAMASKING` incluyendo
`pkg_dm_export`; pepper ya **no** se crea en instalación (es por campaña);
`GRANT EXECUTE ON SYS.DBMS_CRYPTO` conservado; validación de objetos.
**No hecho:** no instala `tests/` (deliberado, es solo QA).

### 98_uninstall.sql — desinstalador (MODIF)
**Hecho:** conserva la versión real (borra `tdm_secreto`) y añade *drop*
defensivo legacy de `tdm_mask_key_map`. **No hecho:** no elimina `pkg_dm_export`
ni `pkg_dm_ff1_test` — **pendiente añadirlos** si se quiere limpieza total.

### crear_sinonimos.sql (MODIF)
**Hecho:** excluye `TDM_SECRETO` de la creación de sinónimos (no exponer la tabla
del pepper). **No hecho:** no crea sinónimo de `pkg_dm_export` de forma explícita
(lo detecta el patrón dinámico `PKG_DM_%`, así que queda cubierto).

### 00_guion_uso_datamasking.sql — runbook (MODIF)
**Hecho:** flujo con wrappers reales, columnas correctas (`esquema_objetivo`,
`tdm_columna_hist`/`final`), `pkg_dm_export.p_export_mask` y
`dm_pepper_purgar`. **No hecho:** no cubre el caso multiesquema (A-05).

### dm_pepper_purgar.sql (NUEVO)
**Hecho:** wrapper que valida el `ejecucion_id` y llama
`pkg_dm_enmascarar.p_dm_pepper_purgar`. Paso final tras el export.

### SIGAD/config_sigad.sql — configuración de cliente (NUEVO)
**Hecho:** generado desde el Excel v3 + doc: 18 EXCLUDE, 94 FORCE, 16 keep-ends,
1 IBAN continuo, 7 doc-por-tipo, 13 coherencias sync (SEGUSUARIO → tablas por
`IDUSUARIO`). Idempotente (MERGE/NOT EXISTS). **No hecho / pendiente:** **no
ejecutado ni validado** en instancia (A-07); solo cubre reglas especiales de
columnas `NDOCUMENTO` (si hay otras columnas de documento, ampliar).

### tests/pkg_dm_ff1_test.sql (NUEVO/TEST)
**Hecho:** vectores NIST byte a byte, **descifrado** FF1 (solo aquí, no en
producción), round-trip, biyección exhaustiva `10^4`, determinismo/tweak; falla
⇒ `ORA-20900`. **No hecho:** no se instala en producción; **no ejecutado** en
instancia real.

### tests/00_run_tests_ff1.sql (NUEVO/TEST)
**Hecho:** compila el paquete de test, deja evidencia (`VALID` + `DBA_ERRORS`
vacío) y corre la batería a `test_ff1_<fecha>.log`. **No hecho:** requiere
ejecutarse en 11g para producir el log (evidencia de A-03).

### 01 / 03 / 04 / 97 / dm_descubre / dm_enmascara / dm_enmascara_id / dm_exportcsv / dm_recompilar / dm_validar_flujo — (IGUAL)
Sin cambios de código. Validados como compatibles con FF1:
`dm_validar_flujo` ya estaba alineado (KPI del mapa deshabilitado); los wrappers
usan la API pública y nombres de columna reales (`esquema_objetivo`).

---

## 3. Estado de hallazgos de auditoría

| ID | Título | Estado |
|---|---|---|
| C-01 | IBAN continuo truncaba | **CERRADO** (06/05) |
| C-02 | Chunks paralelos sin validar | **CERRADO** (05) |
| A-01 | NIE divergía entre rutas | **CERRADO** (06) |
| A-02 | `DETERMINISTIC` impropio | **CERRADO** (06, 2026-09-16: keyword eliminado de las 12 funciones públicas, ya no solo documentado) |
| A-03 | Vectores NIST no en repo | **CERRADO** (2026-09-16: `tests/00_run_tests_ff1.sql` ejecutado en instancia real, 9/9 pruebas PASAN — ver sección 7) |
| A-04 | Custodia del pepper | **DOCUMENTADO** (2026-09-16: `A04_custodia_del_pepper.md`) — decisión operativa (wallet/HSM) sigue pendiente de Riesgo/DPO |
| A-05 | Contrato de dominio FK / multiesquema | **DOCUMENTADO** (2026-09-16: `A05_contrato_de_dominio_FK.md`) — implementación multiesquema en el orquestador sigue pendiente |
| A-06 | Auto-exclusión dejaba PII | **CERRADO** (05, fallo cerrado) |
| A-07 | Config SIGAD no portado | **CONFIG GENERADA** — falta ejecutar/validar |
| A-08 | Duplicados muertos en 05 | **CERRADO** (05) |
| 4.2.2 | `func_cuenta` fallback a hash | **CERRADO** (06) |
| M-01 | Benchmark sin medir | **PENDIENTE** (medición) |
| M-02 | Seudonimización, no anonimización | **DOCUMENTADO** (2026-09-16: `M02_seudonimizacion_vs_anonimizacion.md`) |
| M-03 | NLS afecta la semilla | **CERRADO** (06) |
| M-04 | KPIs no ven auto-exclusiones | **CERRADO indirecto** (A-06 bloquea antes) |
| B-01 | `p_mask_tab` violaba FK de `tdm_ejecucion` (Codex) | **CERRADO** (2026-09-16, 05: crea `ejecucion_id` real vía secuencia en vez de sentinela) |
| — | Acoplamiento cruzado 04↔05 vía `EXECUTE IMMEDIATE` (Gemini) | **CERRADO** (2026-09-16: extraído a `pkg_dm_trazabilidad`, paquete 03b sin dependencias, compila antes que 04/05) |
| — | Propagación de dominio "fail-open" (silenciaba error y seguía) (Codex/Gemini) | **CERRADO** (2026-09-16, 05: añadido `RAISE` tras traza en el handler de propagación) |
| — | Tipos `CHAR` obsoletos en flags de `p_mask_tab`/`p_dm_enmascara` (Gemini) | **CERRADO** (2026-09-16: `CHAR`→`VARCHAR2(1)` en params y locales) |
| — | Código muerto: 2 bloques `EXECUTE IMMEDIATE 'UPDATE tdm_mask_solicitud SET forzar_full...'` (siempre fallaban ORA-00904) | **CERRADO** (2026-09-16: eliminados de `func_dm_crea_sol` y `p_dm_enmascara`) |
| — | `func_dm_tiene_regla` y `proc_dm_upsert_excepcion_col` tragaban errores silenciosamente | **CERRADO** (2026-09-16: `RAISE` en vez de swallow) |
| R-01 | DBMS_ASSERT insuficiente en SQL dinámico de `dm_validar_flujo.sql` (Antigravity) | **CERRADO** (2026-09-16: sanitización en 6 puntos — recompilación, KPI-04/05/06/08) |
| R-02 | Usuarios DBA hardcodeados en instalador | **DOCUMENTADO** (comentario Rem en `99_install_datamasking.sql`) — mejora futura, no bloqueante |
| R-03 | Bloque comentado obsoleto (semillas SIGAD_ACAD_OWN duplicadas) en `02` | **CERRADO** (2026-09-16: eliminado; `tdm_mask_cache` opcional reaislado y documentado, sigue sin activar) |
| R-04 | Líneas sin prefijo `--` en `97_configurar_excepciones.sql` (rompían la ejecución literal del script) | **CERRADO** (2026-09-16) |
| R-05 | `pkg_dm_export` y `pkg_dm_trazabilidad` ausentes en `98_uninstall.sql` | **CERRADO** (2026-09-16) |

---

## 4. Orden de instalación y prueba

**Producción (QA/PRE):**
1. `@@99_install_datamasking.sql` (SYS y luego ASTSYSADMIN, según el propio script).
2. `@crear_sinonimos <USUARIO>` por cada DBA.
3. `@@SIGAD/config_sigad.sql` (solo entorno SIGAD).

**Flujo de campaña:** `@dm_descubre <ESQ>` → revisar → `@@97…` (excepciones) →
`@dm_enmascara <EJEC>` → `@dm_validar_flujo <ESQ> <EJEC>` →
`pkg_dm_export.p_export_mask(...)` → `@dm_pepper_purgar <EJEC>`.

**QA (no producción):** `@@tests/00_run_tests_ff1.sql` → revisar
`test_ff1_<fecha>.log` (todo `VALID`, `DBA_ERRORS` vacío, batería sin FALLAN).

---

## 5. Pendientes globales (para GO regulado)

1. **Ejecutar en 11g** y archivar evidencia: compilación limpia, `tests/` en
   verde (A-03), y `config_sigad.sql` ejecutado + `dm_validar_flujo` con KPIs OK
   (A-07).
2. **A-04** custodia del secreto: wallet/HSM o servicio de secretos, KDF
   versionada, auditoría de accesos, política de destrucción — decisión de
   Riesgo/DPO.
3. **A-05** contrato de dominio por componente FK y manejo multiesquema.
4. **M-01** benchmark A/B (1M/10M filas) + `UPDATE` batcheado por tabla.
5. **M-02** documentado (`M02_seudonimizacion_vs_anonimizacion.md`); queda solo
   la aprobación/firma formal por Legal/DPO como parte del expediente de
   auditoría.

~~6. Añadir `pkg_dm_export` y `pkg_dm_ff1_test` a `98_uninstall.sql`.~~ →
**CERRADO 2026-09-16** (`pkg_dm_export` añadido; `pkg_dm_ff1_test` es un
paquete de test que se instala/desinstala aparte y no forma parte de la
limpieza del motor).

~~7. Reconciliar la copia de `05` con la de Antigravity.~~ → **CERRADO
2026-09-16**: no había divergencia de contenido real, sino dos carpetas
(`Claude\FF1` y `version_biyeccion\FF1`) desincronizadas en disco;
`version_biyeccion\FF1` se sincronizó completa contra `Claude\FF1` (fuente de
verdad, confirmada contra las rutas y contenidos citados por la auditoría de
Antigravity).

---

## 6. Cierre de triple auditoría (Gemini / Antigravity / Codex) — 2026-09-16

Se recibieron 3 auditorías independientes sobre el estado del motor. Antigravity
confirmó que C-01, C-02, A-01, A-06 y A-08 ya estaban cerrados en el código
vigente. Gemini y Codex auditaron una instantánea con hallazgos adicionales de
bajo nivel (algunos de Codex correspondían a una copia desactualizada de `05`,
ya resueltos en la copia vigente; se verificaron uno a uno contra el código
real antes de tocar nada). El detalle completo de la reconciliación de las 3
auditorías, con cita de código y clasificación (ya cerrado / falso positivo por
snapshot desactualizado / real y accionable) está en
`01_PLAN_CIERRE_TRIPLE_AUDITORIA_FF1.md`.

**Hallazgos reales cerrados en esta sesión** (ver detalle y ubicación exacta en
la tabla de la sección 3): B-01 (FK de `p_mask_tab`), acoplamiento cruzado
04↔05, propagación fail-open en `p_dm_enmascara`, tipos `CHAR` obsoletos,
`DETERMINISTIC` en `06` (A-02, ahora cerrado del todo), R-01 (DBMS_ASSERT en
`dm_validar_flujo.sql`), R-03 (bloque comentado obsoleto en `02`), R-04
(líneas sueltas sin comentar en `97`), R-05 (`98` incompleto).

**Bugs adicionales encontrados y corregidos que ninguna de las 3 auditorías
había señalado explícitamente:**
- Dos bloques de código muerto (`EXECUTE IMMEDIATE` a una columna
  `forzar_full` inexistente en `tdm_mask_solicitud`, siempre fallaba
  `ORA-00904` y el error se tragaba) en `func_dm_crea_sol` y `p_dm_enmascara`.
- `func_dm_tiene_regla` devolvía `0` (silenciosamente "sin regla") ante
  cualquier error, incluidos errores reales de la propia consulta — cambiado a
  `RAISE`.
- `proc_dm_upsert_excepcion_col` (API de configuración usada por DBA) tragaba
  cualquier error sin más — eliminado el swallow.
- `04_dm_pkg_descubrimiento.sql` invocaba la traza con `-1, -1` fijos en vez
  de `NULL, p_ejecucion_id` en un punto — corregido de paso al migrar la
  llamada a `pkg_dm_trazabilidad`.

**Documentación de gobernanza generada** (hallazgos M-02, A-05, A-04 — estos
tres eran de diseño/gobernanza, no de código, así que su "cierre" en esta
sesión es documental, no ejecutable):
- `M02_seudonimizacion_vs_anonimizacion.md`
- `A05_contrato_de_dominio_FK.md`
- `A04_custodia_del_pepper.md`

**Paquete nuevo:** `03b_dm_pkg_trazabilidad.sql` — extrae `proc_dm_trace` y
`proc_dm_log_ejec_error` a un paquete sin dependencias de `04`/`05`, que
compila antes que ambos en `99_install_datamasking.sql`. Elimina la necesidad
de `EXECUTE IMMEDIATE` para resolver la referencia circular 04↔05 que señalaba
Gemini.

**Verificación realizada — y su límite honesto:** se revisó balance
`BEGIN`/`END` y estructura de cada paquete tocado (comprobación mecánica,
tipo `grep`/conteo), y se releyó cada cambio en contexto contra el código
circundante. **No se compiló el código contra una instancia Oracle real**
(este entorno no dispone de una) — es la verificación pendiente obligatoria
antes de promover a QA/PRE: compilar los 6 paquetes (`03b`→`04`→`05`→`06`→
`07`, orden de `99_install_datamasking.sql`) en una instancia 11g+ de
desarrollo y confirmar `STATUS='VALID'` sin errores en `DBA_ERRORS`, además de
correr `tests/00_run_tests_ff1.sql` (A-03) y `SIGAD/config_sigad.sql` seguido
de `dm_validar_flujo.sql` (A-07).

**Qué queda genuinamente pendiente y por qué no se hizo aquí:** A-03
(ejecutar los tests FF1 en Oracle real), A-07 (ejecutar `config_sigad.sql`
contra un esquema real y validar con KPIs), y M-01 (benchmark de rendimiento
1M/10M filas) requieren una instancia Oracle en ejecución — no son tareas de
edición de código y no se pueden completar desde este entorno. A-04 y A-05
tienen ya su documento de diseño/gobernanza, pero la implementación
multiesquema (A-05) y la decisión operativa de custodia del secreto (A-04,
wallet/HSM vs. tabla) siguen abiertas como trabajo de diseño e infraestructura,
no de código.

---

## 7. Instalación y pruebas en instancia real — 2026-09-16

Ejecutado por el usuario en `BEV-PDRAC0304.PRESAE` (usuario `eypurisaca`, esquema
`ASTSYSADMIN`).

**Bug real encontrado en el primer intento de instalación** (no detectado por
ninguna de las 3 auditorías ni por la revisión de código de la sección 6,
porque solo se manifiesta al compilar contra un motor Oracle real): al migrar
`CHAR`→`VARCHAR2(1)` en la Fase 1 (punto 6 de la sección 4), la corrección se
aplicó por error también a 6 **parámetros** `IN`/`OUT` de procedimientos y
funciones (`p_dm_enmascara`, `proc_dm_upd_sol`, `func_dm_crea_sol`,
`proc_dm_validar_reingreso_mask`, `proc_dm_mask_cat` — todos en `05`). En
PL/SQL un parámetro no admite restricción de longitud (`VARCHAR2(1)` es
inválido ahí; solo es válido en una variable local), lo que hizo que
`PKG_DM_ENMASCARAR` fallara con `PLS-00103` en cascada en la primera
instalación. Corregido a `VARCHAR2` sin longitud en los 6 parámetros
(las 3 variables locales `l_repro`/`l_reproceso VARCHAR2(1)` quedaron igual,
esas sí son válidas). Este es exactamente el límite de verificación que se
advirtió arriba: la lectura de código y el balance BEGIN/END no sustituyen
una compilación real, y aquí lo confirmó la práctica.

**Segundo intento — instalación limpia:**
- Los 5 paquetes (`PKG_DM_DESCUBRIMIENTO`, `PKG_DM_ENMASCARAR`,
  `PKG_DM_EXPORT`, `PKG_DM_FUNC_MASK`, `PKG_DM_FF1_TEST`) + sus bodies,
  10/10 en `VALID`, `dba_errors` vacío.
- `tests/00_run_tests_ff1.sql`: **9/9 pruebas PASAN** — vectores NIST
  (muestras 1 y 2), round-trip de invertibilidad sobre 2000 valores,
  descifrado de ambas muestras NIST, biyección exhaustiva sin colisiones
  sobre el dominio `10^4` completo, determinismo y separación por tweak.
  Esto es la evidencia real que cierra **A-03**.
- Nota operativa aparte (no de código): el primer intento también falló en
  `grant execute on SYS.DBMS_CRYPTO to ASTSYSADMIN` por `ORA-01031`
  (privilegios insuficientes de la sesión que corrió el instalador) — se
  resolvió ejecutando ese grant puntual conectado como `SYS`. Queda como
  recordatorio operativo para instalaciones futuras en otros entornos: ese
  grant específico necesita una sesión con privilegio de `SYS` o
  `GRANT ANY OBJECT PRIVILEGE`, el resto del instalador no.

**Siguiente paso, en curso:** probar el flujo funcional completo
(descubrimiento → excepciones → enmascarado → `dm_validar_flujo` → export)
sobre un esquema real. Esto es lo que falta para poder marcar A-07 y dar
evidencia de extremo a extremo, más allá de la conformidad criptográfica ya
confirmada en A-03.
