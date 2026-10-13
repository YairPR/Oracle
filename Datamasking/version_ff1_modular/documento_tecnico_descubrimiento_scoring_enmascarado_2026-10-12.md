#datamasking #oracle #ff1 #rgpd #nist #auditoria #19c #11g

**Documento técnico: descubrimiento, scoring y enmascarado por identificador, según RGPD y NIST SP 800-38G**

> [!note] Versión
> Válido para Oracle 11g R2 y 19c (el código es el mismo; solo cambia la función hash, ver apartado 5). Fecha: 2026-10-12. Contrasta el código fuente de la carpeta FF1 (archivos 03, 12, 20, 22, 35, 37) con el Reglamento (UE) 2016/679 y con NIST SP 800-38G Rev. 1, Second Public Draft (2pd, febrero 2025). Este es el análisis técnico único del motor; el catálogo de objetos y la documentación de rendimiento son sus anexos de consulta.

> [!warning] Dos precisiones que condicionan todo el documento
> 1. El PDF de NIST aportado es un **borrador** (2pd). No es una norma vigente: la norma en vigor es SP 800-38G de 2016 (con su Rev. 1 aún en revisión). Aquí se cita como borrador.
> 2. La implementación está **basada en FF1 y validada contra sus vectores**, pero no tiene certificación CAVP/CMVP. No debe presentarse ante una auditoría como "módulo certificado".

**1. Objetivo y alcance**

El motor copia datos de producción a entornos no productivos (PRE, DEV) sin exponer datos personales y manteniendo la integridad referencial. Tiene dos fases: **descubrimiento** (decide qué columnas contienen datos personales) y **enmascarado** (sustituye sus valores). Este documento explica cómo decide cada fase y qué identificadores cubre, y lo relaciona con las obligaciones del RGPD y con el algoritmo FF1.

**2. Marco normativo aplicado**

| Referencia | Qué exige o define | Cómo lo cubre el motor |
|---|---|---|
| RGPD art. 4(1) | Dato personal: toda información sobre una persona identificada o identificable | El descubrimiento clasifica columnas por clase de dato (nombre, identificación, localización, identidad económica) |
| RGPD art. 4(5) | Seudonimización: tratar datos de modo que no se atribuyan a una persona sin información adicional, que se mantiene aparte | FF1 con pepper efímero guardado en `tdm_secreto`, separado de los datos |
| RGPD art. 5(1)(b) y (c) | Limitación de la finalidad y minimización | Un entorno de desarrollo es una finalidad distinta de la original: solo se llevan datos enmascarados |
| RGPD art. 5(1)(e) | Limitación del plazo de conservación | El pepper se purga al finalizar la campaña (`proc_dm_pepper_purgar`) |
| RGPD art. 5(1)(f) | Integridad y confidencialidad | Cifrado en la base, sin sacar los datos; privilegios mínimos (rol `ROL_DATAMASKING`, secreto sin grants) |
| RGPD art. 5(2) | Responsabilidad proactiva: poder demostrarlo | Traza `tdm_mask_trace`, errores con backtrace, informe de columnas no enmascaradas |
| RGPD art. 9 y 10 | Categorías especiales y datos penales | Las columnas de texto libre se enmascaran con una constante (`func_dm_obs`) |
| RGPD art. 25 | Protección de datos desde el diseño y por defecto | El enmascarado es un paso del flujo, no un añadido manual |
| RGPD art. 32(1)(a) | Seudonimización y cifrado como medida técnica | FF1 (AES-128) para identidad y banca |
| RGPD art. 87 | Número nacional de identificación | DNI, NIE y CIF reciben el tratamiento más fuerte (FF1, biyectivo) |
| RGPD art. 89(1) | Garantías para fines de investigación y estadística | Aplica si el entorno se usa para esos fines; lo decide el DPD |
| RGPD considerando 26 | Un dato seudonimizado sigue siendo personal; solo el anónimo queda fuera | Ver apartado 9 |
| NIST SP 800-38G (2pd) | FF1 sobre AES, dominio mínimo de 10^6, tweaks, `BITLEN` entero | Ver apartado 8 |

**3. Descubrimiento: cómo decide qué es sensible**

El descubrimiento recorre un esquema o una lista de tablas (`dm_descubre` o `dm_descubre_set`). Para cada columna candidata calcula una puntuación contra cada identificador y se queda con el mejor.

**3.1 Qué columnas se evalúan**

Se evalúan columnas de texto. Las columnas `NUMBER` se ignoran salvo las que figuran en la regla de configuración `NUMBER_ADMITIDO`. Las tablas sin filas se omiten y se anotan en la traza (`TABLAS_OMITIDAS`). Una columna sin ningún dato se descarta con un sondeo de una fila antes de muestrearla.

**3.2 Las reglas**

Las reglas están en la tabla `tdm_regla` (129 filas cargadas por `03_dm_descubrimiento_carga_reglas.sql`). No hay lógica de negocio escondida en el código: añadir o apagar una regla es una fila.

| `tipo_regla` | Puntúa | Qué mira |
|---|---|---|
| `COLUMN_NAME` | Sí | Expresión regular sobre el nombre de la columna |
| `COLUMN_COMMENT` | Sí | Expresión regular sobre el comentario del diccionario |
| `TABLE_NAME` | Sí | Contexto: nombre de la tabla |
| `DATA_PATTERN` | Sí | Expresión regular sobre una muestra de filas reales |
| `ALIAS_NOMBRE`, `NUMBER_ADMITIDO`, `NOMBRE_CANDIDATO`, `NOMBRE_PERSONAL`, `NOMBRE_GENERICO`, `CTX_PERSONA`, `CTX_APELLIDO` | No (puntuación 0) | Listas de configuración: alias de nombres, contexto de persona, nombres genéricos que exigen evidencia de datos |

Del total, 116 reglas puntúan (66 suman y 50 restan) y 13 son configuración.

**3.3 Cómo se construye el score**

```text
score_total = score_nombre + score_comentario + score_tabla + score_patron
```

Cada componente es la suma de las reglas activas del identificador que coinciden. Las reglas que restan (descartes) valen entre -50 y -320 y existen para dejar fuera lo que no identifica a nadie: indicadores (`SW_DNI`), tipos (`TIPO_VIA`), catálogos, direcciones IP, nombres de banco. El patrón de datos se lee sobre una muestra acotada entre 10 y 500 filas con valor, y una regla de patrón solo cuenta si la proporción de filas que coinciden supera su `confianza_min` y hay al menos `muestra_min` filas con dato.

> [!tip] El dato manda sobre el nombre
> Un nombre de columna sugiere, el dato confirma. Una columna `NAME` no se acepta como nombre de persona sin evidencia en la muestra, y una columna llamada `DNI` cuyos valores son `S`/`N` se descarta por el patrón `^[SN]$`. El patrón de datos solo cuenta cuando la evidencia previa (nombre, comentario y tabla) no es claramente negativa.

**3.4 Bandas de decisión**

| Score | Estado final | ¿Se enmascara? |
|---|---|---|
| ≥ 85 | CONFIRMADO | Sí |
| ≥ 65 | PROBABLE | Sí |
| ≥ 45 | REVISAR | No (lo decide una persona) |
| < 45 | DESCARTADO | No |

Una columna en REVISAR no se enmascara sola. Si el cliente exige enmascararla, se declara con `FORCE` en `tdm_excepcion_col`; si es un falso positivo, con `EXCLUDE`. Las excepciones mandan sobre el score.

**3.5 Validaciones específicas**

- **DNI/NIE:** `func_dm_es_dni_nie_valido` comprueba formato y letra de control (módulo 23). Un valor con formato correcto pero letra errónea no cuenta como documento.
- **Dominios referenciales:** `proc_dm_propaga_dominios` agrupa por clave foránea (Union-Find) las columnas conectadas. Si una se marca para enmascarar, todas las del grupo reciben el mismo identificador y el mismo dominio. Así el mismo DNI queda igual en todas las tablas donde aparece.
- **Dependencias:** se catalogan las claves foráneas, restricciones y triggers de cada columna a enmascarar; el enmascarado los desactiva y los reactiva según su estado previo.

**3.6 Qué no puede saber el descubrimiento**

Detecta por nombre, comentario, tabla y formato de la muestra. No interpreta el contenido: un texto libre se trata entero. Una columna que contenga datos personales en un 1 % de sus filas y no pase la banda no se enmascarará; la muestra es de como máximo 500 filas. Por eso la lista de columnas descubiertas debe revisarla una persona antes de la campaña (art. 5(2)).

**4. Enmascarado: cómo se aplica cada identificador**

El enmascarado lee las columnas marcadas y aplica a cada una la función de su identificador. La expresión SQL se acota a la longitud de la columna (`SUBSTR`) para evitar `ORA-12899`.

| Identificador | Clase RGPD | Función | Algoritmo | Biyectivo | Dominio del tweak |
|---|---|---|---|---|---|
| IDENTIDAD | 4(1), 87 | `func_dm_nif` | DNI: FF1 sobre 8 dígitos, letra recalculada. NIE: FF1 sobre 3×10^7 valores, prefijo y letra recalculados. CIF: FF1 sobre 7 dígitos y dígito o letra de control recalculado. Otros formatos: FF1 sobre los dígitos y se conservan letras y separadores | Sí (con ≥ 6 dígitos) | `IDENTIDAD` |
| IDENTIDAD (especiales) | 4(1), 87 | `func_dm_espec_doc_segun_tipo`, `func_dm_especial_doc_keep_ends` | Igual que arriba; la segunda conserva el primer y último carácter | Sí (interior numérico ≥ 6 dígitos) | `IDENTIDAD` |
| BANCARIO (IBAN) | 4(1), 32 | `func_dm_iban` | `ES` + 22 dígitos: FF1 sobre los 20 dígitos del BBAN y control módulo 97 recalculado. Formato no estándar: semilla HMAC de 56 bits | Sí (IBAN español válido) | `IBAN` |
| BANCARIO (cuenta) | 4(1), 32 | `func_dm_cuenta` | De 6 a 20 dígitos: FF1; menos de 6 dígitos: HMAC | Sí (≥ 6 dígitos) | `CUENTA` |
| BANCARIO (IBAN continuo) | 4(1), 32 | `func_dm_especial_iban_continuo` | 24 caracteres, FF1 sobre los 20 primeros dígitos | Sí | `IBAN` |
| PERSONAL (nombre) | 4(1) | `func_dm_nombre` → `func_dm_mix_alpha` | Misma longitud, letras A-Z generadas por un generador congruencial con semilla HMAC del texto | No | No aplica |
| DIRECCION | 4(1) | `func_dm_direccion` | Dirección sintética de 21 a 32 caracteres elegida por semilla HMAC (unas 255 000 combinaciones) | No | No aplica |
| TELEFONO | 4(1) | `func_dm_telefono` | 9 dígitos que empiezan por 6, 7, 8 o 9, por semilla HMAC (espacio de 4×10^8) | No | No aplica |
| EMAIL | 4(1) | `func_dm_email` | Correo sintético de 21 a 24 caracteres por semilla HMAC | No | No aplica |
| OBS | 9, 10 | `func_dm_obs` | Constante fija de 28 caracteres | No (no conserva nada) | No aplica |

**Qué significa "biyectivo" en la práctica.** Una función biyectiva no produce dos salidas iguales para dos entradas distintas, de modo que las columnas con índice único (DNI, IBAN) no chocan. Las clases no biyectivas son deterministas (misma entrada, misma salida dentro de una campaña) pero dos valores distintos pueden dar el mismo resultado. Si una de ellas lleva índice único de una sola columna, el motor lo avisa (`UNICIDAD_RIESGO`) y, si falla con `ORA-00001`, auto-excluye la columna y la deja registrada como no enmascarada.

> [!warning] Alcance de FF1 en el motor
> Solo las clases IDENTIDAD y BANCARIO (con al menos 6 dígitos) son formalmente FF1 y biyectivas. Nombre, dirección, teléfono, correo y observaciones son sustitución determinista por HMAC: no son cifrado que preserve formato ni permiten recuperar el original con el pepper.

**5. Criptografía: lo que hay que poder defender**

| Elemento | Implementación | Observación |
|---|---|---|
| Algoritmo | FF1 (NIST SP 800-38G, algoritmo 7), 10 rondas Feistel, radix 10 | FF3 no se usa (el borrador la retira) |
| Cifrador base | AES-128 con CBC-MAC como PRF | Igual en 11g y 19c |
| Clave | Primeros 16 bytes de SHA-256(pepper) en 12c o superior; SHA-1 en 11g | `DBMS_CRYPTO` de 11g no ofrece SHA-256 |
| Tweak | Primeros 8 bytes de SHA-256(`'DOMINIO:'` + identificador), SHA-1 en 11g | Un tweak por dominio |
| Semillas de texto | HMAC-SHA256 del texto con el pepper, 56 bits (HMAC-SHA1 en 11g) | PRF, no firma |
| Pepper | 256 bits de `DBMS_CRYPTO.RANDOMBYTES`, uno por campaña, en `tdm_secreto` | Se purga al finalizar |

La función hash se elige **al compilar** el paquete (`$IF DBMS_DB_VERSION.VER_LE_11_2` en `func_dm_sha_hash` y `func_dm_sha_mac`). Una base que se actualiza de 11g a 19c debe reinstalar el paquete 12 para pasar a SHA-256. El resultado enmascarado no es comparable entre una base 11g y otra 19c: la misma clave de origen da salidas distintas.

**6. Pepper efímero y reversibilidad**

El pepper es la información adicional que menciona el art. 4(5). Mientras existe, quien lo tenga puede reproducir el cifrado y, en las clases FF1, descifrar. Por eso se genera por campaña, se confirma (`COMMIT`) antes de lanzar los workers, y se **purga al finalizar**. Tras la purga, el enmascarado de las clases FF1 no es reversible con los medios del motor, pero **no se declara anonimización**: se ha de valorar con el considerando 26 (ver apartado 9).

FF1 no es idempotente: cifrar dos veces un valor ya cifrado lo destruye en silencio. Por eso cada columna enmascarada deja una fila `MASK/APPLY_COL` en la traza, que es el punto de control de la reanudación, y una columna con esa fila no se vuelve a enmascarar. Tras escribirla, el motor la relee y, si no la encuentra, aborta con `CHECKPOINT_PERDIDO` (`ORA-20215`).

**7. Qué queda sin enmascarar y cómo se sabe**

El motor no se detiene en mitad de una campaña de millones de filas por una columna problemática. La deja sin enmascarar, la registra y sigue.

| Situación | Evento en la traza | Resultado |
|---|---|---|
| Longitud de columna menor que el mínimo del identificador | `SKIP_AUTO_LEN` | Sin enmascarar |
| Colisión de unicidad (`ORA-00001`) | `SKIP_ORA00001` | Auto-exclusión; sin enmascarar |
| Valor mayor que la columna (`ORA-12899`) | `SKIP_ORA12899` | Auto-exclusión |
| Desbordamiento de variable (`ORA-06502`) | `SKIP_ORA06502` | Auto-exclusión |
| Columna con tipo no tratable por el transformador | `ORA-20360` en el preflight | Aborta **antes** de tocar datos |

Al final de cada campaña, `proc_dm_resumen_no_mask` deja una línea `NO_ENMASCARADA` por columna, con el motivo, y un total. La consulta es:

```sql
select detalle
  from tdm_mask_trace
 where ejecucion_id = :id
   and paso = 'NO_ENMASCARADA'
 order by trace_id;
```

Una campaña con columnas sensibles auto-excluidas no pasa a FINALIZADO: queda registrada con `FIN.PII_SIN_ENMASCARAR`. Esta es la evidencia del art. 5(2) de que no se ocultan fallos.

**8. Conformidad con NIST SP 800-38G Rev. 1 (borrador 2pd)**

| Requisito del borrador | Estado en el motor | Nota |
|---|---|---|
| Dominio mínimo: radix^minlen ≥ 1 000 000 ("shall") | Cumple | Con 1 a 5 dígitos no se usa FF1: se sustituye por HMAC (`func_dm_digitos_min_dominio`) |
| FF1 sobre AES, radix 10, 10 rondas | Cumple | Validado con los vectores del NIST (`tests/pkg_dm_ff1_test.sql`) |
| FF3 y FF2 retirados | Cumple | No se usan |
| `b = ⌈BITLEN(radix^v − 1) / 8⌉` y sin coma flotante | **Conforme** | `func_dm_ff1_cifrar_raw` cuenta los bits de `10^v` con enteros (divisiones sucesivas entre 2) y calcula `b = CEIL(bits / 8)`. Da el mismo `b` que la fórmula decimal anterior para v = 1 a 37 (comprobado con `tests/dm_ff1_bitlen_check.sql`), por lo que las salidas no cambian |
| Tweaks que varíen por instancia | Decisión de diseño | Un tweak por dominio, para que el mismo DNI dé el mismo resultado en todas las tablas (integridad referencial). Es un compromiso consciente |
| Apéndice A.1: adivinación en dominios pequeños | Mitigado | Dominios de menos de 10^6 valores no pasan por FF1 |
| Entradas largas | Cumple | Hasta 70 dígitos exactos en un bloque; por encima se divide en bloques de 36 con un tweak por bloque |

> [!note] Cambio propuesto, no aplicado
> El cálculo de `b` usa solo aritmética entera, como exige el borrador. Una mitad de más de 37 dígitos se rechaza con ORA-20211; el motor nunca llega ahí porque cifra por bloques de 36 dígitos como máximo (mitad de 35 dígitos para 70).

**9. Posición jurídica honesta**

1. **Seudonimización, no anonimización.** Con el pepper vivo, el enmascarado FF1 es reversible; con el pepper purgado, solo el DPD puede calificar si el resultado es anónimo (considerando 26: ¿hay medios razonables de reidentificación?). Las clases por HMAC conservan relaciones (mismo origen, mismo destino dentro de la campaña) que podrían permitir inferencias.
2. **Sin certificación.** El algoritmo es FF1 del NIST; la implementación en PL/SQL sobre `DBMS_CRYPTO` no está certificada (CAVP/CMVP). Se defiende con vectores de prueba, no con un certificado.
3. **El borrador no es norma.** Se usa como referencia de buenas prácticas.
4. **Las reglas son criterio técnico.** Qué columnas son personales lo decide el responsable del tratamiento; el motor propone y registra.

**10. Trazabilidad: qué queda registrado y cómo consultarlo**

Cada tabla responde a una sola pregunta, para no duplicar información.

| Tabla | Pregunta que responde |
|---|---|
| `tdm_ejecucion` | Qué corrida es y en qué estado está (progreso, latido, sesión Oracle, petición de cancelación) |
| `tdm_mask_solicitud` | Qué intentos de enmascarar hubo dentro de la corrida y cómo terminó cada uno |
| `tdm_mask_trace` | Qué pasó, en qué orden y cuánto tardó (línea de tiempo; no guarda valores de datos) |
| `tdm_ejecucion_error` | Qué falló exactamente (código, mensaje, backtrace); cada error tiene su línea `ERROR.REGISTRADO` en la traza |
| `tdm_parametro` | Catálogo de eventos de la traza (nivel INFO, WARN o ERROR de cada paso) |

La traza se escribe en transacción autónoma, de modo que persiste aunque la transacción de trabajo haga rollback. Cada columna enmascarada deja una única línea `MASK.APPLY_COL` con las filas, la ruta (`UPDATE` o `CHUNKS`) y la duración; esa línea es también el punto de control de la reanudación. El descubrimiento deja solo un resumen (`DESCUBRIMIENTO.RESUMEN`) más las tablas omitidas y los avisos, porque el detalle por columna ya está en `tdm_columna_hist`.

```sql
-- Línea de tiempo completa de una corrida
select trace_id, to_char(fecha_evento,'DD-MM-YYYY HH24:MI:SS') fecha, nivel, fase, paso,
       duracion_seg, substr(detalle,1,140) detalle
  from tdm_mask_trace
 where ejecucion_id = :e
 order by trace_id;

-- Columnas que quedaron sin enmascarar y por qué
select detalle
  from tdm_mask_trace
 where ejecucion_id = :e and paso = 'NO_ENMASCARADA'
 order by trace_id;

-- Pasos que no están en el catálogo de eventos (esperado: ninguno)
select t.fase, t.paso, count(*) n
  from tdm_mask_trace t
 where t.ejecucion_id = :e
   and not exists (select 1 from tdm_parametro p
                    where p.grupo = 'EVENTO' and p.clave = t.fase || '.' || t.paso)
 group by t.fase, t.paso;

-- Rendimiento por columna (filas por minuto)
select regexp_substr(detalle, '^[^ ]+') columna,
       to_number(regexp_substr(detalle, 'filas=([0-9]+)', 1, 1, null, 1)) filas,
       duracion_seg
  from tdm_mask_trace
 where ejecucion_id = :e and paso = 'APPLY_COL' and duracion_seg is not null
 order by duracion_seg desc;
```

**11. Interrupción, reanudación y cancelación**

- **Reanudar:** `@dm_enmascara_reanudar N` detecta la sesión caída, cierra el intento anterior como abortado, conserva el pepper y salta las columnas que ya tienen `APPLY_COL`. Una tarea paralela cuyos chunks terminaron todos se registra como hecha sin reprocesarla. Las dependencias se vuelven a deshabilitar en cada intento (la operación es idempotente) y se rehabilitan todas al final.
- **Cancelar:** `@dm_enmascara_cancel N CONFIRMAR` detiene la corrida y la deja reanudable; con `DESCARTAR` abandona y borra las tareas (lo ya cifrado sigue cifrado). El cancel usa la lista de tareas del paquete, reintenta el kill de las sesiones y verifica al final que no quede ningún worker vivo; una sesión en estado `KILLED` no cuenta como viva.
- **Una sola corrida por esquema:** el índice único funcional `ui_dm_ejec_activo` impide dos corridas `EJECUTANDO` sobre el mismo esquema.
- **Columna forzada que no cabe:** si una columna `FORCE` es más corta que el mínimo de su identificador (por ejemplo 4 caracteres frente a 10 de un código bancario), se omite con `SKIP_AUTO_LEN`. Es deliberado: no se fuerza un formato que el dato no admite. Por eso "columnas marcadas" y "columnas aplicadas" pueden diferir en una unidad.

**12. Instalación**

El instalador (`99_install_datamasking.sql`) se ejecuta como SYS, detecta el esquema del motor (`ASTSYSADMIN` o `ACC_ADMIN`) y valida al final que todos los objetos estén `VALID`. Si algo queda mal, imprime el aviso y los errores de compilación y **deja la sesión abierta** para consultar `dba_errors` y volver a ejecutar solo el archivo afectado. El rol `ROL_DATAMASKING` solo se concede a los DBA y la instalación en PRE y DEV es manual, bajo su responsabilidad.

> [!tip] Al copiar archivos entre equipos
> Una versión antigua de un solo archivo basta para invalidar otro que depende de él (por ejemplo, el 35 llama a una función del 34). Antes de instalar conviene comprobar que los archivos de la carpeta son los mismos que se revisaron, con `certutil -hashfile <archivo> SHA256` o `sha256sum`.

**Referencias**

**Notas relacionadas**

- [[catalogo_objetos_datamasking]]
- [[documentacion_performance_datamasking]]
- [[incidente_ora07445_qctcopn_internal_y_mecanismo_reanudacion_2026-09-28]]

**Fuentes consultadas**

- Reglamento (UE) 2016/679 (RGPD), arts. 4, 5, 9, 10, 25, 32, 87 y 89; considerando 26 (PDF aportado).
- NIST SP 800-38G Rev. 1, Second Public Draft, febrero 2025 (PDF aportado).
- Código fuente del motor: archivos 03, 12, 20, 22, 35 y 37.
