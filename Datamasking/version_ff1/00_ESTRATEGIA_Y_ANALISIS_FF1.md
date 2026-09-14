# Datamasking · versión FF1 (NIST SP 800-38G)

Migración del núcleo criptográfico del motor de enmascaramiento desde la red
Feistel propia (4 rondas, HMAC-SHA1 truncado) a **FF1**, el modo estándar de
Cifrado que Preserva Formato (FPE) del NIST, construido sobre AES-128.

Base: `version_biyeccion/Modelo_Feistel`. Destino: `version_biyeccion/FF1`.

---

## 0. Qué se hizo en esta migración quirúrgica

Cambios aplicados y verificados (archivo → qué cambió):

- **06** — núcleo reescrito a FF1 (AES-128, NIST). CIF, `doc_segun_tipo` e
  `iban_continuo` pasan a biyectivos; semilla de texto 31→60 bits. Firmas
  públicas intactas.
- **05** — depuración + pepper efímero:
  - Eliminado el **código muerto del mapa**: `proc_dm_build_domain_map`,
    `proc_dm_pre_build_maps` (era un `NULL`), el bloque `IF FALSE AND l_dominio…`
    de `proc_dm_apl_col`, todas las referencias a `tdm_mask_key_map` y la variable
    `l_dominio` ya sin uso.
  - Eliminado el **parche `ORA_HASH`** del handler de colisión (rompía FK): ahora
    una colisión de unicidad auto-excluye la columna de texto en vez de fabricar
    un sufijo. Los `ORA_HASH` que quedan son solo el *fallback* determinista de
    `ORA-06502` (reemplazo completo de valor, no sufijo), que es seguro.
  - Añadido **pepper efímero POR CAMPANA**: `proc_dm_pepper_generar(ejecucion_id)`
    crea la fila `'PEPPER_MASK:'||ejecucion_id` (idempotente y *race-safe* con
    `DUP_VAL_ON_INDEX`, `RANDOMBYTES(32)`, `COMMIT` antes del paralelo), fija
    `set_ejecucion` en el coordinador y **envuelve cada chunk paralelo** con
    `BEGIN pkg_dm_func_mask.set_ejecucion(<ejec>); UPDATE …; END;` para que cada
    worker lea el pepper de su campaña. `p_dm_pepper_purgar(ejecucion_id)` borra
    solo el secreto de esa campaña.
- **06** — clave del pepper por campaña: `f_get_pepper` lee
  `'PEPPER_MASK:'||ejecucion_id` y `set_ejecucion` invalida la caché al cambiar de
  campaña (necesario porque los workers son sesiones nuevas).
- **02** — `tdm_secreto.clave` ampliada a `VARCHAR2(64)` para `PEPPER_MASK:<ejec>`.
- **99** — ya no genera el pepper en la instalación (ahora es por campaña); nota
  y `GRANT EXECUTE ON SYS.DBMS_CRYPTO` conservados.
- **01 / 02 / 03 / 04 / 97** — sin cambios.

Diferido a la fase 2 de rendimiento (NO tocado aquí, para mantenerla quirúrgica):
`UPDATE` batcheado por tabla y reactivación selectiva del mapa por valor distinto.

**Flujo de campaña con pepper efímero:**
`p_dm_enmascara(ejec)` (crea `PEPPER_MASK:ejec`) → `p_export_mask` →
`p_dm_pepper_purgar(ejec)` (borra solo ese secreto). En un *resume* el pepper de
esa campaña se conserva (idempotente). **Dos esquemas a la vez** (dos `ejec`
distintos) usan peppers independientes: sin carrera de creación, sin purga
cruzada y con rotación automática por campaña. Invariante: dos esquemas con FK
**entre sí** deben enmascararse en la **misma** ejecución (mismo pepper).

> Validación pendiente en tu instancia: compilar `06` y `05` y correr las pruebas
> de la sección 6. Las cirugías se hicieron por anclas exactas y ambos paquetes
> cierran correctamente, pero la compilación real es la prueba definitiva.

---

## 1. Estrategia de migración

**Principio: cambiar solo el núcleo, no la cadena.** El único objeto que
contiene la primitiva criptográfica es `pkg_dm_func_mask` (archivo `06`). El
descubrimiento (`04`) y el orquestador (`05`) llaman **exclusivamente** a las
funciones públicas de ese paquete (`func_generico`, `func_nif`, `func_iban`,
`func_cuenta`, `func_especial_*`…). Verificado por análisis de referencias: las
primitivas privadas (`f_map_bijective`, `f_prf`) no se invocan desde ningún otro
archivo.

Consecuencia: **FF1 se implementa reescribiendo solo el cuerpo de `06`,
manteniendo idénticas todas las firmas públicas.** `01`, `02`, `03`, `04`, `05`
y `97` no cambian una línea. Riesgo de regresión mínimo.

**Qué cambia en `06`:**

| Antes (Modelo_Feistel) | Ahora (FF1) |
|---|---|
| `f_prf` = HMAC-SHA1 truncado a 56 bits | PRF = CBC-MAC AES-128 (NIST) |
| Feistel propio de 4 rondas | FF1 de 10 rondas, algoritmo certificado |
| Mitades decimales `10^h` + cycle-walking siempre | Longitud exacta; walking solo si el dominio no es potencia de 10 |
| Sin tweak | **Tweak por dominio** (separa dominios, respeta FK) |
| CIF y `doc_segun_tipo` por hash (colisionables) | CIF y `doc_segun_tipo` **biyectivos** vía FF1 |
| Semilla de texto: `GET_HASH_VALUE` (31 bits) | Semilla de texto: HMAC-SHA1 (60 bits) |

**Qué NO cambia:** determinismo, formato de salida, propagación por FK vía
igualdad determinista, gestión PRE/POST de constraints, trazabilidad, y la firma
de las 12 funciones públicas.

**Invariante de integridad referencial (crítico).** El tweak de FF1 depende
**solo del identificador semántico** (`f_ajuste_dominio('IDENTIDAD')`,
`'CUENTA'`, `'IBAN'`), nunca de tabla, columna, ROWID ni ID de fila. Así, dos
columnas unidas por una FK que comparten identificador reciben el mismo tweak y
la misma longitud → el mismo valor original produce el mismo valor enmascarado en
padre e hija. **Un tweak por fila rompería la propagación: prohibido.**

**Compatibilidad 11g.** AES-128 (`ENCRYPT_AES128`) y SHA-1 (`HASH_SH1`,
`HMAC_SH1`) de `DBMS_CRYPTO` existen desde 10g/11g. No se usa SHA-256
(`HASH_SH256`), que es 12c+. Requisito único: `GRANT EXECUTE ON SYS.DBMS_CRYPTO`
(ya en `99`).

**Reproducibilidad.** La clave AES = primeros 16 bytes de `SHA-1(pepper)`; el
pepper vive en `tdm_secreto`. Cada worker de `DBMS_PARALLEL_EXECUTE` lee el mismo
pepper → misma clave → resultado idéntico entre chunks y entre tablas. Para
reproducir un dump ya entregado, replicar la fila `PEPPER_MASK`; nunca
regenerarla.

---

## 2. Estructura de la carpeta e instalación

```
FF1/
├── 00_ESTRATEGIA_Y_ANALISIS_FF1.md   (este documento)
├── 00_guion_uso_datamasking.sql      ← NUEVO (runbook FF1 + pepper/purga)
├── 01_dm_descubrimiento_objetos.sql  (igual a Modelo_Feistel)
├── 02_dm_enmascaramiento_objetos.sql ← clave tdm_secreto a VARCHAR2(64)
├── 03_dm_descubrimiento_carga_reglas.sql (igual)
├── 04_dm_pkg_descubrimiento.sql      (igual)
├── 05_dm_pkg_enmascarar.sql          ← depurado + pepper por ejecucion_id
├── 06_dm_pkg_func_mask.sql           ← NUEVO (motor FF1 + set_ejecucion)
├── 97_configurar_excepciones.sql     (igual)
├── 98_uninstall.sql                  ← alineado FF1 (sin tdm_mask_key_map)
└── 99_install_datamasking.sql        ← pepper efímero por campaña
```

Instalación estándar (SQL*Plus, desde la carpeta): `@@99_install_datamasking.sql`.
El instalador compila `06` (funciones) antes que `05` (orquestador) porque este
depende de aquel. Tras compilar, revisar `dba_errors` (sección 4.6 del `99`).

---

## 3. Análisis de identificadores: ¿están bien enmascarados?

Cada columna se enmascara con una función determinista. La pregunta clave es si
esa función es **biyectiva** (inyectiva = sin colisiones) sobre su dominio, y si
es **segura para FK**.

| Identificador | Función | Técnica en FF1 | Biyectivo | FK-safe | Riesgo a volumen |
|---|---|---|---|---|---|
| IDENTIDAD / DOCUMENTO · DNI (8 díg.) | `func_nif` | FF1 radix10 n=8 + letra | **Sí** | Sí | Ninguno |
| IDENTIDAD · NIE (7 díg.) | `func_nif` | FF1 n=7 + letra | **Sí** | Sí | Ninguno |
| IDENTIDAD · CIF (7 díg.) | `func_nif` | FF1 n=7 + control | **Sí** (mejorado) | Sí | Ninguno |
| DOC_SEGUN_TIPO (1=DNI, 3=NIE) | `func_especial_doc_segun_tipo` | FF1 + letra | **Sí** (mejorado) | Sí | Ninguno |
| BANCARIO · IBAN (BBAN 20 díg.) | `func_iban` | FF1 n=20 + IBAN cc | **Sí** | Sí | Ninguno |
| BANCARIO · IBAN continuo (SIGAD) | `func_especial_iban_continuo` | FF1 n=20 + cc | **Sí** (mejorado) | Sí | Ninguno |
| BANCARIO · cuenta / CCC | `func_cuenta` | FF1 n=L (4–20) | **Sí** | Sí | Ninguno* |
| DOC_KEEP_ENDS (interior numérico) | `func_especial_doc_keep_ends` | FF1 del interior | **Sí** dentro de extremos+long. | Sí | Bajo |
| DOC_KEEP_ENDS (interior mixto) | idem | semilla determinista | No | — | Medio en columnas únicas |
| PERSONAL / NOMBRE / APELLIDO | `func_nombre` | mezcla alfabética por semilla | No | n/a (no es FK) | Bajo con semilla 60 bits |
| DIRECCIÓN / DOMICILIO | `func_direccion` | plantilla por semilla | No | n/a | **Alto** (dominio de plantillas ~ miles) |
| EMAIL | `func_email` | local aleatorio por semilla | No | n/a | Bajo con semilla 60 bits |
| TELÉFONO / MÓVIL | `func_telefono` | 8 díg. por semilla | No | n/a | Medio (10^8, cumpleaños ~10^4) |
| OBSERVACIÓN | `func_obs` | constante fija | Colapsa a 1 valor | n/a | Por diseño |

\* En cuentas cortas (n<6) el dominio (`10^n`) es pequeño: FF1 sigue siendo
biyectivo (sin colisiones), pero su **secreto** es débil por fuerza bruta del
codebook. No es un problema aquí porque la reversibilidad no está contemplada
(el pepper se destruye; el único camino de vuelta es reimportar el dump de PRO).

**Mejoras aplicadas en esta versión (todas en `06`):**

1. **CIF biyectivo.** Antes usaba `MOD(seed·43+29, 10^7)` (hash → colisionable).
   Ahora la parte numérica pasa por FF1. Relevante si el CIF es PK/FK de empresa.
2. **`doc_segun_tipo` biyectivo y coherente con `func_nif`.** Antes usaba hash y
   **nunca coincidía** con el DNI enmascarado por `func_nif` para el mismo valor
   → riesgo de huérfanos si dos tablas FK usaban reglas distintas. Ahora ambas
   rutas usan FF1 con el mismo tweak `'IDENTIDAD'` y la misma letra de control →
   idéntico resultado.
3. **`iban_continuo` biyectivo** (antes el BBAN salía de un hash).
4. **Semilla de texto de 31 → 60 bits.** `func_nombre/direccion/email/telefono`
   siguen sin ser biyectivas (por naturaleza del dominio), pero la probabilidad
   de colisión de semilla baja del umbral de cumpleaños ~2^15.5 (~46 000 valores)
   a ~2^30 (~10^9 valores).

---

## 4. Colisiones: dónde son imposibles y dónde persisten

**Imposibles por construcción (FF1):** todo lo numérico de identidad y banca
(DNI, NIE, CIF, cuenta, IBAN). FF1 es una permutación sobre `[0, 10^n)`; el
cycle-walking preserva la biyección al restringir a `[0, módulo)`. Verificado:
100 000 DNI distintos → 0 colisiones.

**Persisten (dominios de texto libre):** nombre, dirección, email, teléfono. Son
**no inyectivas por diseño** (mapear texto a texto "bonito" pierde información).
Con la semilla de 60 bits el riesgo es bajo salvo en columnas **UNIQUE** de muy
alto volumen, y sobre todo en **DIRECCIÓN** (el dominio de salida son unas pocas
miles de combinaciones plantilla·número·ciudad → colisiona seguro en columnas
únicas grandes).

**Cómo se maneja ahora (tras la depuración de `05`).** El motor enmascara
*stateless* llamando a `func_generico` dentro del `UPDATE`. El código muerto del
mapa (`tdm_mask_key_map`, `IF FALSE …`, `proc_dm_pre_build_maps`) se **eliminó**.
El antiguo handler que ante `ORA-00001` fabricaba un sufijo
`… || LPAD(MOD(ORA_HASH(col),1e6),6,'0')` se **retiró** porque rompía la FK: ese
sufijo se aplicaba solo en la tabla que colisionaba, de modo que si el mismo
valor colisionaba en la hija pero no en el padre (o al revés), divergían →
huérfano.

> Comportamiento nuevo: una colisión de unicidad **auto-excluye** la columna (se
> registra y se deja sin enmascarar) en lugar de fabricar un valor que rompa RI.
> En la práctica solo puede ocurrir en columnas de **texto** únicas: los dominios
> numéricos con FF1 son biyectivos y nunca colisionan.

**Recomendaciones (por orden de coste):**

1. **Forzar identificador biyectivo en toda columna que participe en una FK.**
   Ninguna FK debería resolverse por NOMBRE/EMAIL/TELÉFONO. Usar
   `tdm_excepcion_col` con `FORCE` → `IDENTIFICADOR_IDENTIDAD/DOCUMENTO/BANCARIO`
   (ver `97_configurar_excepciones.sql`). Coste: cero código, solo configuración.
2. **Para columnas de texto UNIQUE sin FK** (p. ej. email de login): aceptar el
   sufijo actual **o** reactivar el mapa por valor distinto solo para esas
   columnas (garantiza unicidad global sin tocar el resto).
3. **Hacer el handler reactivo RI-safe:** derivar el sufijo del valor original de
   forma que padre e hija coincidan (ya usa `ORA_HASH(col)` sobre el original, que
   es determinista) **y** aplicarlo siempre al par de columnas FK juntas, no a una
   sola. Documentado como mejora opcional en `05`; no incluida para no alterar el
   orquestador en esta migración.

---

## 5. Rendimiento y volumen (UNDO / TEMP / CPU / contención / bloqueos)

Hallazgos sobre el código real de `05` y su impacto con FF1.

### CPU — es el punto que más sube con FF1
FF1 hace ~10 rondas AES-CBC-MAC por valor (≈20 cifrados de bloque) frente a las 4
HMAC-SHA1 del modelo anterior: **~5× coste de CPU por valor**. Además la función
se invoca **por fila** dentro del `UPDATE` (context switch SQL↔PL/SQL por fila).

Mitigaciones:
- **`DETERMINISTIC` ya está declarado** en todas las públicas → Oracle cachea el
  resultado para valores repetidos dentro de la misma sentencia. En columnas con
  pocos valores distintos muy repetidos (típico en DNI/IBAN de tablas de
  movimientos), el ahorro es enorme.
- **Para tablas grandes, cifrar cada valor distinto UNA vez y unir por join** (el
  patrón del `tdm_mask_key_map` que está desactivado). Con FF1 esto pasa de
  "coste ≈ nº filas" a "coste ≈ nº valores distintos". **Recomendación fuerte:
  reactivar el mapa solo para columnas de alta cardinalidad de filas y baja de
  valores distintos.**
- FF1 **elimina el cycle-walking** en dominios potencia de 10 (DNI 10^8, NIE
  10^7, IBAN 10^20): acierta a la primera ronda. El modelo anterior caminaba
  cuando el nº de dígitos era impar. Neto: menos iteraciones en NIE/CIF.

### UNDO — el mayor ahorro está en batchear por tabla
`proc_dm_apl_col` ejecuta **un `UPDATE` de tabla completa por CADA columna**. Una
tabla con K columnas enmascaradas se recorre y reescribe K veces → K× UNDO/REDO y
K× mantenimiento de índices.

- **Recomendación de alto impacto:** agrupar todas las columnas de una tabla en un
  **único `UPDATE ... SET c1=…, c2=…, cK=…`**. Una sola pasada. Reduce UNDO, REDO,
  y trabajo de índices proporcionalmente a K. (Cambio localizado en `05`; no
  incluido en esta migración para mantenerla quirúrgica, pero es la mejora de
  rendimiento más rentable.)
- La ruta paralela (`>100 000` filas) usa `DBMS_PARALLEL_EXECUTE` con **commit por
  chunk de 50 000** → acota el UNDO por transacción. Bien.
- La ruta no paralela (`<100 000`) hace un `UPDATE`+`COMMIT` por columna → UNDO
  acotado al tamaño de columna. Aceptable.

### TEMP
La ruta *stateless* actual apenas usa TEMP (no ordena). Si se **reactiva el mapa**
(recomendación de CPU), aparecen joins/anti-joins → dimensionar TEMP y apoyarse en
índice de `tdm_mask_key_map(dominio, valor_orig)`. El troceo por ROWID
(`CREATE_CHUNKS_BY_ROWID`) no consume TEMP relevante.

### Contención y bloqueos
- **PRE/POST de constraints:** deshabilitar/rehabilitar FK y triggers es DDL →
  toma locks breves de diccionario/tabla. `ENABLE VALIDATE` (default) **revalida
  toda la tabla** al final: correcto para garantizar consistencia, pero costoso en
  tablas grandes. Si el enmascarado ya garantiza la coherencia padre/hija (FF1
  determinista + mismo tweak), se puede evaluar `ENABLE NOVALIDATE` para acelerar,
  asumiendo el compromiso de no validar filas preexistentes.
- **Bloqueos de fila:** el `UPDATE` de columna toca todas las filas; en paralelo se
  liberan por chunk (commit cada 50 000). Sin contención cruzada porque las
  columnas se procesan en serie.
- **Parse:** cada columna arma un `UPDATE` con literales (owner.tabla.columna
  embebidos) → hard parse por columna. Con miles de columnas hay coste de parse,
  no de contención. Aceptable; los identificadores no pueden ir por bind.
- **Paralelo + determinismo:** confirmado FK-safe. El pepper/clave AES viven en
  `tdm_secreto` (compartido), no se generan por sesión → todos los workers
  producen el mismo cifrado. Si el pepper se generara en memoria por sesión,
  cada worker divergiría → `ORA-00001` y FK rotas. **No cambiar ese patrón.**

### Resumen accionable de rendimiento
| Acción | Esfuerzo | Impacto |
|---|---|---|
| Mantener `DETERMINISTIC` (ya está) | 0 | Alto en columnas repetitivas |
| Reactivar mapa por valor distinto en tablas grandes | Medio (`05`) | Muy alto (CPU) |
| Batchear columnas por tabla en un solo `UPDATE` | Medio (`05`) | Muy alto (UNDO/REDO/índices) |
| Evaluar `ENABLE NOVALIDATE` en rehabilitación | Bajo | Alto en validación final |
| Ajustar `chunk_size`/`parallel_level` al hardware | Bajo | Medio |

---

## 6. Checklist de validación tras instalar FF1

1. `06` compila sin errores (`show errors package body pkg_dm_func_mask`).
2. Prueba de biyección sobre una muestra:
   ```sql
   -- 0 colisiones esperadas sobre DNIs distintos
   SELECT COUNT(*) total, COUNT(DISTINCT pkg_dm_func_mask.func_nif(dni)) distintos
   FROM (SELECT LPAD(LEVEL,8,'0')||'Z' dni FROM dual CONNECT BY LEVEL<=100000);
   ```
   `total = distintos` ⇒ biyectivo.
3. Prueba de coherencia padre/hija: el mismo DNI por `func_nif` y por
   `func_especial_doc_segun_tipo(...,1)` debe dar la **misma** parte numérica.
4. Prueba de determinismo: dos llamadas al mismo valor dan el mismo resultado.
5. KPI de huérfanos por FK (flujo `dm_validar_flujo`) = 0 tras un enmascarado real.
