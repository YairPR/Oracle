# MANIFEST — Datamasking versión FF1

**Fecha:** 2026-09-15
**Motor:** Oracle 11g+, esquema `ASTSYSADMIN`, rol `ROL_DATAMASKING`, sin wallet/TDE.
**Núcleo cripto:** FF1 (NIST SP 800-38G) sobre AES-128, tweak por dominio, pepper
efímero por campaña.
**Estado global:** apto para QA. **NO-GO para producción regulada** hasta cerrar
gobernanza (A-04), diseño (A-05) y ejecutar la evidencia (A-03, A-07) en instancia.

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
| `04_dm_pkg_descubrimiento.sql` | IGUAL | Paquete de descubrimiento |
| `05_dm_pkg_enmascarar.sql` | MODIF | Orquestador de enmascaramiento |
| `06_dm_pkg_func_mask.sql` | NUEVO/MODIF | Núcleo cripto FF1 + funciones de formato |
| `07_dm_pkg_export.sql` | NUEVO | Export Data Pump (companion, fuera del motor) |
| `97_configurar_excepciones.sql` | IGUAL | Plantillas de excepciones |
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
| A-02 | `DETERMINISTIC` impropio | **DOCUMENTADO** (06) |
| A-03 | Vectores NIST no en repo | **ARTEFACTO ENTREGADO** — falta ejecutar en 11g |
| A-04 | Custodia del pepper | **PENDIENTE** (gobernanza/DPO) |
| A-05 | Contrato de dominio FK / multiesquema | **PENDIENTE** (diseño) |
| A-06 | Auto-exclusión dejaba PII | **CERRADO** (05, fallo cerrado) |
| A-07 | Config SIGAD no portado | **CONFIG GENERADA** — falta ejecutar/validar |
| A-08 | Duplicados muertos en 05 | **CERRADO** (05) |
| 4.2.2 | `func_cuenta` fallback a hash | **CERRADO** (06) |
| M-01 | Benchmark sin medir | **PENDIENTE** (medición) |
| M-02 | Seudonimización, no anonimización | **PENDIENTE** (documentar) |
| M-03 | NLS afecta la semilla | **CERRADO** (06) |
| M-04 | KPIs no ven auto-exclusiones | **CERRADO indirecto** (A-06 bloquea antes) |

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
5. **M-02** documentar formalmente que el resultado es seudonimización.
6. Añadir `pkg_dm_export` y `pkg_dm_ff1_test` a `98_uninstall.sql`.
7. Reconciliar la copia de `05` con la de Antigravity (la de aquí trae C-02/A-06).
