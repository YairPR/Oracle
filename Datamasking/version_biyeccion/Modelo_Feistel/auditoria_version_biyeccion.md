# Auditoría de código — Motor de Data Masking (`version_biyeccion`)

**Repositorio:** `YairPR/Oracle` · `Datamasking/version_biyeccion` · **Fecha auditoría:** 31/07/2026
**Alcance:** paquetes `04/05/06`, DDL `01/02`, reglas `03`, validador, scripts de comando, README.
**Propósito del motor:** alternativa nativa PL/SQL a Oracle DMS; descubrimiento por reglas/regex + score; enmascarado determinista por identificador (DNI, IBAN, nombre, teléfono…); propagación referencial padre→hija; soporte paralelo, cancelar, continuar e incremental.

---

## 0. Veredicto ejecutivo

El motor está **bien construido y maduro**. El diseño de descubrimiento incremental, propagación por Union-Find, control de dependencias y trazabilidad es sólido y correcto. Las colisiones —el punto débil histórico— están **resueltas**.

Hay **un hallazgo crítico** que nace justo del cambio a biyección: el método afín (`f_map_bijective`) es **matemáticamente reversible**. Se ganó unicidad (biyección, sin colisiones) pero se perdió irreversibilidad. Para el objetivo declarado (anonimización RGPD, dumps a cliente) esto importa y hay que decidirlo conscientemente.

| Área | Estado |
|---|---|
| Determinismo | ✅ Correcto (pepper fail-loud) |
| Colisiones | ✅ Resueltas (biyección + entropía corregida) |
| **Irreversibilidad del método** | 🔴 **Regresión: la afín es reversible con known-plaintext** |
| Propagación referencial | ✅ Correcta (Union-Find + mapa + prioridad) |
| Deshabilitar/rehabilitar dependencias | ✅ Correcto (solo enabled, restaura estado real) |
| Descubrimiento incremental | ✅ Bien diseñado |
| Paralelo | 🟠 Sin verificación de `TASK_STATUS` |
| Cancelar / continuar | ✅ Cancelar bien; ⚠️ reanudar con un borde a validar |
| Trazabilidad / logs | ✅ Handoff previo implementado (con baseline de invalidez) |
| Redundancia / cobertura | 🟡 Menores |
| Documentación | 🟡 README vende irreversibilidad que el método no tiene |

---

## 1. Método de enmascaramiento y biyección (hallazgo central)

### 1.1 ✅ La biyección es correcta y resuelve las colisiones
`f_map_bijective(x, m) = (a·x + c) mod m`, con `a = hash(pepper)·2+1` (siempre impar → coprimo con 2) y ajuste `IF MOD(a,5)=0 THEN a:=a+2` (coprimo con 5). Para módulos `10^k` (NIF `10⁸`, teléfono `10⁷`, IBAN BBAN `10²⁰`), `gcd(a, 10^k)=1` **está garantizado**, luego la transformación **es biyectiva → sin colisiones**. Esto elimina el problema de la versión `sin_biyeccion` y las exclusiones manuales por `UNIQUE`. Bien resuelto.

### 1.2 🔴 CRÍTICO — La afín es reversible (regresión de irreversibilidad)
`f(x) = (a·x + c) mod m` es un **cifrado afín**, trivialmente invertible:
- Con **dos** pares conocidos `(x₁,y₁),(x₂,y₂)`: `a = (y₁−y₂)·(x₁−x₂)⁻¹ mod m`, y `c = (y₁−a·x₁) mod m`. Con `a` y `c` se revierte **todo** el dominio.
- Peor aún: `a` y `c` dependen **solo del pepper** (`hash(pepper)` y `hash(pepper||'_c')`), no del dominio ni del módulo. Son **globales**: los mismos para NIF, teléfono, cuenta e IBAN. Así que **dos pares NIF conocidos revierten también teléfonos, cuentas e IBANs**.
- El secreto del pepper **no protege**: el atacante no necesita el pepper, solo dos correspondencias original→enmascarado (su propio registro, una figura pública, un registro de prueba plantado).

Para RGPD esto **no es anonimización**: es pseudonimización reversible con clave recuperable. Si el dump llega a alguien con cualquier par conocido, se reidentifica el conjunto entero. Es una **regresión** frente a `version_sin_biyeccion` (hash de una vía, no invertible desde pares).

**El dilema real de arquitectura:**
| | Colisiones | Reversibilidad |
|---|---|---|
| `sin_biyeccion` (hash+pepper) | ❌ colisiona en UNIQUE | ✅ irreversible |
| `biyeccion` (afín) | ✅ sin colisiones | ❌ reversible (known-plaintext) |
| **FPE / permutación con clave** | ✅ sin colisiones | ✅ irreversible-sin-clave |

**Recomendación:** si el modelo de amenaza contempla que el receptor intente reidentificar, sustituir la afín por una **permutación pseudoaleatoria con clave sobre el dominio de dígitos** — FPE (FF1/FF3-1) o una **red Feistel** de pocas rondas con el pepper como clave y una PRF (p.ej. SHA-256 vía `DBMS_CRYPTO`) como función de ronda. Da biyección (sin colisiones) **y** resistencia a known-plaintext. Es el primitivo correcto para "único + irreversible" a la vez. Si el dump nunca sale a un adversario con pares conocidos (uso interno estricto D/PRE), la afín es tolerable, pero **el README y el motor deben documentarlo como pseudonimización reversible, no como anonimización**.

### 1.3 🟡 Coprimalidad para el módulo de CUENTA
`func_cuenta` usa `f_map_bijective(x, l_mod)` con `l_mod` variable. La coprimalidad solo está garantizada para factores 2 y 5. **Verificar que `l_mod` sea siempre `10^k`**; si pudiera tomar un valor con otros factores primos, la biyección se rompe y reaparecen colisiones en esa columna.

---

## 2. ¿Por qué no `DBMS_CRYPTO`? (evaluación)

La decisión original (no usarlo, quedarse con `GET_HASH_VALUE`) era **correcta para el enfoque hash**: `DBMS_CRYPTO` no consume licencia pero no aportaba —el problema era ancho de salida, no el hash— y añadía un grant y coste por fila.

**Con la afín reversible (1.2), la respuesta cambia:** si se adopta FPE/Feistel para lograr biyección **irreversible**, entonces sí conviene `DBMS_CRYPTO.HASH` (SHA-256) como función de ronda/PRF con clave secreta. Es decir: no lo necesitas para el hash actual, pero **lo necesitarías para arreglar la reversibilidad** manteniendo la unicidad. Sigue sin requerir licencia (solo `GRANT EXECUTE ON SYS.DBMS_CRYPTO TO ASTSYSADMIN`).

---

## 3. Colisiones por función (mejoradas)

- ✅ **Numéricas** (NIF/teléfono/cuenta/IBAN): biyección afín → sin colisiones.
- ✅ **`func_email`**: antes colapsaba entropía (módulo 26); ahora avanza el seed con módulo `4294967291` (~2³²) y toma un carácter por iteración → **entropía recuperada**, colisiones despreciables. Corregido.
- ✅ **`f_mix_alpha`** (nombres): igual, módulo 2³². Buena entropía.
- 🟡 `f_mix_alpha` sigue emitiendo solo `A–Z` ASCII (mayúsculas), sin `Ñ` ni acentos → nombres ficticios pierden caracteres españoles o los dejan pasar según NLS. Definir alfabeto de salida explícito.
- ✅ Documentos con dígito de control válido (`f_cif_ctrl`), IBAN con checksum módulo 97 (`f_iban_cc_es`) reutilizado (DRY correcto).

---

## 4. Determinismo
✅ Todo pasa por `f_hash`/`f_map_bijective`, ambos derivados del pepper. `f_get_pepper` **falla en alto** (`ORA-20210`) si no existe, sin literal en la fuente. Funciones `DETERMINISTIC`. Reproducible dentro del mismo pepper. Correcto.

---

## 5. Propagación referencial
✅ **Union-Find** de componentes FK (empareja compuestas por `position`), asigna **dominio estable** (`min_node` lexicográfico), elige **identificador por prioridad** (`f_rank_ident`) y lo fuerza en todos los miembros. **Mapa biyectivo compartido** (`tdm_mask_key_map`, `UNIQUE(dominio,valor_masc)`) → padre e hija reciben idéntico valor. Se **re-propaga al inicio del enmascarado** respetando la validación del cliente, con traza `RI_REINCLUYE` (vía `EXECUTE IMMEDIATE`, sin dependencia circular) y `FK_JERARQUIA` (padre←hija) en PRE. Todo el diseño de propagación es correcto y trazado.

---

## 6. Deshabilitar / rehabilitar dependencias
✅ Solo actúa sobre triggers/constraints **ENABLED** y **existentes** de las tablas a enmascarar (`dep_policy` devuelve `DISABLE`/`SIN_ACCION` según `status`), y en POST **restaura el estado real** (`ENABLE_VALIDATE`), no altera lo que ya venía disabled. Orden hija→padre no aplicado en el enmascarado (irrelevante con FK deshabilitadas) pero **sí trazado** por jerarquía. Correcto.

---

## 7. Descubrimiento incremental
✅ **Bien diseñado.** `proc_dm_prepara_objetos` + `tdm_objeto_ctrl` guardan `object_id`, `last_ddl_time`, `column_count` y `firma_txt` por tabla. Solo se marca `PENDIENTE` (reevaluar) una tabla si: es nueva, cambió `last_ddl_time`, cambió `column_count`, o `p_forzar_full='Y'`. Tablas técnicas (`TMP/LOG/CAT/CONFIG/…`) → `OMITIDO` por regex. Soporta `scope` (`tdm_ejecucion_scope`). Esto cumple exactamente el requisito de esquemas gigantes: **reevalúa solo lo nuevo/cambiado, no todo**.

Observaciones menores:
- 🟡 Las filas de `tdm_objeto_ctrl` de tablas **dropeadas** no se limpian (persisten obsoletas). Añadir un marcado `ELIMINADO` para tablas que ya no existen, y purgar sus columnas de `tdm_columna_final`.
- 🟡 `firma_txt` se guarda pero la comparación usa los campos sueltos (`last_ddl_time`, `column_count`) → la firma es redundante. O se usa la firma como criterio único, o se elimina.
- 🟡 Cambios que **no** tocan DDL ni recuento (p.ej. solo más datos) no re-clasifican. Aceptable, porque la clasificación es por nombre/patrón; documentarlo.

---

## 8. Paralelo, cancelar, continuar

### 8.1 🟠 Paralelo — sin verificación de resultado
`proc_dm_ejecuta_update_seguro`: tablas > 100.000 filas (no IOT) → `DBMS_PARALLEL_EXECUTE` con chunks por ROWID (`parallel_level=2`). **Tras `RUN_TASK` hace `DROP_TASK` sin comprobar `TASK_STATUS`** → los chunks `FINISHED_WITH_ERROR` se descartan en silencio (enmascarado parcial no detectado). Y `p_rows_out := l_row_count` reporta el **estimado**, no `SQL%ROWCOUNT` real. **Fix:** comprobar `DBMS_PARALLEL_EXECUTE.TASK_STATUS`, reprocesar/registrar los chunks fallidos antes de `DROP_TASK`, y devolver filas reales.

### 8.2 ✅ Cancelación
Cooperativa por checkpoint: `p_mask_cancelar` marca `cancel_requested='Y'`, y `proc_dm_chk_cancel` lo evalúa en puntos de control lanzando `ORA-20081`. Diseño correcto.

### 8.3 ⚠️ Reanudación — borde a validar
La reanudación reabre la solicitud desde checkpoint. **Riesgo a comprobar:** si una columna paralela quedó **a medias** (unos chunks aplicados, otros no) y se reintenta, el pre-chequeo fail-closed de C-1 cuenta las filas **ya enmascaradas** como "sin mapeo" (su valor ya no es un `valor_orig` del mapa) y podría abortar con `ORA-20202` en falso. Es seguro si el checkpoint salta **columnas completas**; es problemático si reintenta una columna paralela interrumpida. **Verificar la granularidad del checkpoint** y, si hace falta, marcar completitud por tabla/columna antes del commit por chunk.

---

## 9. Redundancia y cobertura de columnas

- ✅ **Cobertura:** el descubrimiento escanea **todas** las columnas vía `dba_tab_columns` (líneas 826/886/1539); ninguna se omite salvo por regla/patrón explícito. Correcto.
- 🟡 **Redundancia de rendimiento:** `f_map_bijective` recalcula `a` y `c` (dos `GET_HASH_VALUE` del pepper) **en cada llamada → por fila**. Cachearlos en variables de paquete (como `g_pepper`) una vez por sesión. En tablas grandes es coste real.
- ✅ DRY mejorado: `func_iban` reutiliza `f_iban_cc_es`, `f_cif_ctrl` reutilizado. Revisar solo que `func_especial_iban_continuo` no reimplemente el checksum que ya está en `f_iban_cc_es`.

---

## 10. Trazabilidad y logs
✅ El handoff previo **está implementado**: `solicitud_id` en `tdm_ejecucion_error` (nullable), errores de dependencia PRE/POST al log, `POST_CHECK_INVALID` con **baseline de invalidez** (`l_invalidos_pre/post/nuevos` → solo tumba por invalidez **nueva**, no preexistente — tal como se recomendó), y la jerarquía `tdm_ejecucion → error/solicitud → trace/dep_estado` respetada. Bien.

---

## 11. Documentación e higiene del repo

- 🟡 **README engañoso en el eje seguridad.** Afirma que la biyección "garantiza el cumplimiento normativo" y anonimización; el método es **reversible** (1.2). Corregir para no prometer irreversibilidad que no existe; describirlo como unicidad determinista (pseudonimización), y si se adopta FPE, entonces sí anonimización.
- 🟡 El README dice "8 KPIs" pero el validador ya incluye el KPI de PII residual (KPI-09) — actualizar el conteo.
- 🟡 **Ficheros que no deberían versionarse:** `install_datamasking_*.log` (5 logs) y `who_can_access.lis` están commiteados. Los `.lis`/`.log` pueden contener nombres de usuario/estructura operativa. Añadir a `.gitignore` y sacarlos del historial.

---

## 12. Mejoras priorizadas

| # | Prioridad | Mejora |
|---|---|---|
| 1 | 🔴 Alta | **Decidir el modelo de amenaza.** Si el dump puede llegar a alguien con pares conocidos → sustituir la afín por **FPE/Feistel con clave** (biyección irreversible). Si es uso interno estricto → documentar que es pseudonimización reversible y **corregir el README**. |
| 2 | 🟠 Media | **Paralelo:** verificar `TASK_STATUS`, reprocesar chunks fallidos, devolver filas reales. |
| 3 | 🟠 Media | **Reanudación:** validar/blindar el borde de columna paralela a medias vs el fail-closed C-1. |
| 4 | 🟡 Media | **Coprimalidad de `func_cuenta`:** garantizar `l_mod = 10^k`. |
| 5 | 🟡 Baja | **Rendimiento:** cachear `a`,`c` de `f_map_bijective` por sesión. |
| 6 | 🟡 Baja | **Incremental:** limpiar `tdm_objeto_ctrl`/`tdm_columna_final` de tablas dropeadas; resolver redundancia de `firma_txt`. |
| 7 | 🟡 Baja | **Nombres:** alfabeto de salida con `Ñ`/acentos en `f_mix_alpha`. |
| 8 | 🟢 Higiene | Sacar `.log`/`.lis` del repo; actualizar README (KPIs, seguridad). |

**Conclusión:** la lógica y la aplicación de los métodos son correctas y sin redundancia relevante; todas las columnas se procesan; el incremental, la propagación y el control de dependencias están bien. El único punto que cambia la clasificación del motor —de "anonimizador" a "pseudonimizador reversible"— es la naturaleza afín del método biyectivo. Resolver eso (mejora #1) es lo que llevaría el motor a cumplir de verdad su objetivo RGPD sin renunciar a la unicidad que acabas de ganar.
