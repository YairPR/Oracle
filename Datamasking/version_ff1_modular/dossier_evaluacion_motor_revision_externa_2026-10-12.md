#datamasking #ff1 #auditoria #evaluacion-externa #19c #11g

**Dossier de evaluación del motor de enmascaramiento (versión FF1) para revisión externa, 2026-10-12**

> [!info] Cómo usar este documento
> Está escrito para quien revisa el motor sin acceso a la base de datos. Contiene qué hace el motor, qué decisiones son deliberadas, qué evidencia hay de que funciona, qué se encontró en la última auditoría y qué se pide al revisor. Todo lo que dice "verificado" se ha comprobado leyendo el código o con una ejecución real indicada; lo que dice "deducido" es análisis estático sin ejecutar.

**1. Alcance y reglas de la evaluación**

- Material a revisar: los 23 scripts numerados (01 a 99), los scripts de usuario `dm_*.sql`, `97_configurar_excepciones.sql` y la carpeta `tests/`.
- No hay conexión a Oracle para el revisor. El responsable instala, ejecuta lo que se le indique y devuelve los resultados.
- Versión objetivo: 19c; piso de portabilidad 11.2.0.4. Esto implica identificadores de 30 bytes como máximo y sin SHA-2 en `DBMS_CRYPTO` en 11g.
- Esquema del motor: `ASTSYSADMIN`. Rol de uso: `ROL_DATAMASKING`. Esquema de prueba: `DM_DUMMY` (35 tablas, 12 claves foráneas, 1 trigger, 4 índices únicos, una tabla IOT, una tabla vacía).

> [!warning] No marcar como defecto (decisiones deliberadas)
> 1. Las consultas CTE "objetivo" con `/*+ MATERIALIZE */` (35 en cinco sitios, 37 en tres) evitan el ORA-07445 `qctcopn_internal` y la contención. No son duplicación ni se unifican sin prueba en 19c y 11g.
> 2. Todos los paquetes son de derechos del definidor. La instalación es manual con SYS en entornos de desarrollo y preproducción, bajo responsabilidad del DBA.
> 3. `ROL_DATAMASKING` conserva `EXECUTE` sobre `pkg_dm_mask_ff1` y el privilegio `ADM_PARALLEL_EXECUTE_TASK`. Solo lo reciben los DBA.
> 4. Las columnas auto-excluidas por longitud, ORA-12899 u ORA-06502 no bloquean `FINALIZADO`: no se detiene un proceso de millones de filas. Todo lo no enmascarado queda en la traza (`NO_ENMASCARADA`).
> 5. No se enmascara por la columna con índice único mediante UPDATE paralelo: esas columnas usan un único UPDATE sin trozos.
> 6. Los privilegios `SELECT ANY TABLE`, `UPDATE ANY TABLE`, `ALTER ANY TABLE`, `ALTER ANY TRIGGER` y `CREATE JOB` del esquema del motor los concede el DBA a mano; el instalador solo los verifica.

**2. Qué hace el motor**

El motor descubre columnas sensibles de un esquema, decide con qué tratamiento enmascarar cada una y las enmascara en entornos no productivos sin romper la integridad referencial. Tiene dos fases independientes.

| Fase | Entrada | Salida | Script |
|---|---|---|---|
| Descubrimiento | Esquema objetivo | `tdm_columna_final` (columnas listas), `tdm_dependencia_final` (restricciones y triggers) | `dm_descubre`, `dm_descubre_set` |
| Enmascarado | Identificador de ejecución | Datos modificados en el esquema, traza en `tdm_mask_trace` | `dm_enmascara`, `dm_enmascara_id`, `dm_enmascara_reanudar`, `dm_enmascara_cancel` |
| Validación | Esquema y ejecución | Veredicto de 8 KPI | `dm_validar_flujo` |

**Descubrimiento y puntuación.** Cada columna suma puntos por reglas de nombre y de contenido (muestra de filas). Bandas: 85 o más confirmado, 65 o más probable (se enmascara), 45 o más a revisar (no se enmascara). Principio de diseño: el dato manda sobre el nombre. Si una regla de contenido exige un porcentaje de coincidencia y la muestra no lo alcanza, la puntuación se limita a 55 (`DATO_NO_COINCIDE_CON_FORMATO`), salvo excepción FORCE. Las columnas NUMBER solo se evalúan si su nombre figura en la lista admitida. Las tablas sin filas se omiten.

**Excepciones y reglas especiales (datos, no código).** El motor es genérico: lo que cambia entre clientes son filas en tres tablas.

| Tabla | Función |
|---|---|
| `tdm_excepcion_col` | FORCE (enmascarar siempre, con identificador) o EXCLUDE (nunca) |
| `tdm_mask_regla_esp` | `DOC_SEGUN_TIPO`, `DOC_UNIFICADO_MANTENER_1_Y_ULTIMO`, `IBAN_ES_CONTINUO` |
| `tdm_mask_relacion_sync` | Coherencia entre tablas sin clave foránea (copia del valor enmascarado de origen a destino) |

**Orden del enmascarado.** Validaciones previas, deshabilitar claves foráneas y triggers (con CASCADE ordenado), enmascarar columna a columna, reactivar y validar, sincronizar relaciones, resumen de lo no enmascarado, cierre. El punto de control de cada columna es la fila `MASK/APPLY_COL` de la traza, porque FF1 no es idempotente: reaplicarlo cifraría de nuevo.

**Rutas de ejecución por columna** (texto exacto en la traza): trozos con `DBMS_PARALLEL_EXECUTE` por encima de 100.000 filas, UPDATE único hasta 100.000 filas, UPDATE único en tablas IOT, y UPDATE único en columnas con índice único propio.

**3. Arquitectura de paquetes**

| Archivo | Paquete | Líneas | Responsabilidad |
|---|---|---|---|
| 10 | `pkg_dm_trazabilidad` | 564 | Traza autónoma, catálogo de eventos, errores |
| 11 | `pkg_dm_sql_seguro` | 111 | Normalizar y entrecomillar identificadores (`DBMS_ASSERT`) |
| 12 | `pkg_dm_mask_ff1` | 1275 | Núcleo FF1, hash, funciones de formato, reglas especiales |
| 13 | `pkg_dm_dominios` | 235 | Propagación de dominios por componente de claves foráneas |
| 20 | `pkg_dm_desc_puntuacion` | 976 | Señales y puntuación de sensibilidad |
| 21 | `pkg_dm_desc_catalogo` | 404 | Publicación en catálogo final y dependencias |
| 22 | `pkg_dm_descubrimiento` | 1420 | Orquestador de descubrimiento |
| 30 | `pkg_dm_pepper` | 115 | Ciclo de vida del secreto por ejecución |
| 31 | `pkg_dm_mask_estado` | 530 | Estado de ejecución y solicitud |
| 32 | `pkg_dm_mask_validacion` | 158 | Compuertas previas de solo lectura |
| 33 | `pkg_dm_mask_dependencias` | 855 | Deshabilitar y rehabilitar restricciones y triggers |
| 34 | `pkg_dm_mask_worker` | 1259 | Tareas paralelas y UPDATE de una columna |
| 35 | `pkg_dm_mask_columna` | 1087 | Decidir y aplicar una columna |
| 36 | `pkg_dm_mask_sync` | 157 | Coherencia entre tablas sin clave foránea |
| 37 | `pkg_dm_enmascarar` | 991 | Fachada y orquestador |
| 40 | `pkg_dm_export` | 207 | Exportación Data Pump (fuera del motor; no se evalúa) |

Totales: 17 tablas, 9 secuencias, 16 paquetes, catálogo de 63 eventos de traza. `98_uninstall.sql` cubre todas las tablas, secuencias y paquetes (comprobado).

**4. Criptografía**

**FF1.** Implementación propia en PL/SQL de FF1 (NIST SP 800-38G) sobre AES-128 con `DBMS_CRYPTO`, solo sobre dominios decimales (radix 10). Diez rondas, cifrado de bloque con AES-CBC y vector cero para la función de ronda, y cycle-walking cuando el módulo no es potencia de 10. La longitud del bloque se calcula con aritmética entera exacta (`b = CEIL(BITLEN(10^v)/8)`), equivalente a la fórmula decimal para todo v entre 1 y 37.

**Límites del dominio.** Cada mitad admite hasta 37 dígitos (ORA-20211 por encima). El núcleo es exacto hasta 70 dígitos; por encima se cifra por bloques de 36.

**Clave y secreto.** La clave AES-128 son los primeros 16 bytes de SHA-256 del pepper (SHA-1 en 11g, por compilación condicional sobre `DBMS_DB_VERSION`). El pepper son 32 bytes de `RANDOMBYTES`, uno por ejecución, guardado en `tdm_secreto` (sin permiso para el rol) y purgado al finalizar. Sin pepper el motor falla cerrado (ORA-20210). No hay almacén externo de claves ni HSM.

**Tweak.** Depende solo del dominio semántico (identidad, cuenta, IBAN), nunca de la fila. Así una clave foránea y su padre dan el mismo valor enmascarado.

**Clases de enmascarado.**

| Clase | Algoritmo | Inyectiva | Salida |
|---|---|---|---|
| DNI, NIE, CIF | FF1 sobre 8, 8 y 7 dígitos; letra de control recalculada | Sí | 9 caracteres |
| Cuenta de 6 a 20 dígitos | FF1 | Sí | misma longitud, entre 4 y 20 |
| IBAN ES | FF1 sobre 20 dígitos; control recalculado (módulo 97) | Sí | 24 |
| IBAN continuo | FF1 sobre 20 dígitos, sin espacios | Sí | 24 |
| Menos de 6 dígitos | HMAC (exigencia NIST de dominio mínimo) | No | misma longitud |
| Nombre | HMAC más generador congruencial, solo letras, conserva longitud y no alfabéticos | No | misma longitud |
| Dirección | Elección en listas fijas por semilla HMAC | No (unas 255.000 combinaciones) | 21 a 32 |
| Teléfono | Semilla HMAC, 9 dígitos | No (unos 4 por 10 a la 8) | 9 |
| Correo | Semilla HMAC | Casi | 21 a 24 |
| Observación | Constante | No | 28 |

Postura defendible, y la única que se afirma: implementación basada en FF1 sobre AES-128 para seudonimización determinista, verificada contra vectores oficiales. No se declara certificación ni conformidad formal. Con el pepper en la mano el cifrado numérico es reversible; la irreversibilidad descansa en destruir el pepper, y un `DELETE` no demuestra irrecuperabilidad.

**5. Evidencia de funcionamiento**

| Prueba | Resultado | Evidencia |
|---|---|---|
| Vectores NIST (muestras 1 y 2), ida y vuelta, biyección exhaustiva en 10 a la 4, determinismo y separación por tweak | 9 de 9 superadas, 34 objetos válidos, `DBA_ERRORS` vacío | `tests/00_run_tests_ff1.sql` y su registro |
| Equivalencia de la longitud de bloque entera y decimal | 37 valores comprobados, 0 diferencias | `tests/dm_ff1_bitlen_check.sql` |
| Descubrimiento sobre DM_DUMMY recargado (ejecución 5) | 29 tablas, 84 columnas, 67 con enmascarar, 8 excepciones, 0 errores | resumen de `dm_descubre` |
| Enmascarado (ejecución 5) | FINALIZADO en 6 min 27 s, 39 dependencias deshabilitadas y 39 reactivadas, 0 errores | resumen de `dm_enmascara` |
| Validador de 8 KPI (ejecución 5) | 8 de 8 superados | `dm_validar_flujo DM_DUMMY 5` |
| Traza frente a la previsión (ejecución 4, repetida en 5) | 66 `APPLY_COL`, 1 `SKIP_AUTO_LEN`, 2 `NO_ENMASCARADA`, 2 `UNICIDAD_RIESGO`, 1 `SYNC`, 1 `SYNC_OK`; coincide exactamente | `tdm_mask_trace` |
| Corrida a volumen sobre otro esquema de prueba | FINALIZADO, 35 de 35 tablas, 46 de 46 columnas, 0 errores, 6 h 13 min (septiembre) | informe anterior; no certifica rendimiento |

Los 8 KPI del validador son: objetos inválidos, restauración de dependencias, errores en logs, dígito de control de DNI/NIE/CIF, suma de control de IBAN, unicidad, ejecuciones duplicadas e integridad referencial padre-hija. El KPI de dígito de control descuenta como "no verificables por configuración" las columnas con regla `DOC_UNIFICADO_MANTENER_1_Y_ULTIMO` o excepción FORCE vigentes; los valores con formato DNI/NIE/CIF de esas columnas se siguen validando.

Cobertura de DM_DUMMY: 212 columnas (59 enmascaradas por descubrimiento, 7 FORCE, 1 EXCLUDE, 2 en el límite, 143 sin tratamiento), con casos de documento por tipo, documento unificado (incluida una cadena de 102 caracteres), IBAN con espacios, sincronización sin clave foránea, columnas con índice único, tabla organizada por índice, tabla vacía, 150.000 filas con clave primaria de DNI y 120.000 filas en la tabla organizada por índice.

**6. Hallazgos de esta auditoría**

Método: inventario de identificadores y su longitud, sintaxis y paquetes propios de versiones posteriores a 11g, SQL dinámico y concatenación, excepciones tragadas, integridad del instalador y desinstalador, catálogo de eventos frente a eventos emitidos, privilegios y reglas de nombre. Revisión estática.

**Corregido durante la auditoría**

| Id | Severidad | Hallazgo | Corrección |
|---|---|---|---|
| H1 | Alta en 11g | `proc_dm_resumen_no_enmascaradas` en `37_dm_pkg_enmascarar.sql` tenía 31 caracteres; el límite en 11g y 12.1 es 30 y el paquete no compilaría (ORA-00972). Pasó inadvertido porque la prueba fue en 19c. | Renombrada a `proc_dm_resumen_no_mask` (privada, tres referencias). Pendiente de compilar en 11g |
| H2 | Media | Los registros de dependencias del catálogo final no se purgaban si el esquema se recreaba o se eliminaba una restricción: el `MERGE` de `proc_dm_sync_dep_final` solo inserta y actualiza. Cada enmascarado avisaba de 56 restricciones "no existe". | Tras el `MERGE`, borrar las dependencias FK, CONSTRAINT y TRIGGER cuyo objeto ya no existe en el diccionario, limitado a los propietarios de la ejecución. Pendiente de probar en Oracle |
| H3 | Baja | El validador marcaba fallo por columnas de prueba con pasaportes o documentos propios (3,4 % frente al límite del 5 %). | Descuento por configuración, descrito en la sección 5 |

**Observaciones abiertas (sin cambio de código)**

| Id | Severidad | Observación | Recomendación |
|---|---|---|---|
| O1 | Media | `pkg_dm_mask_sync` actualiza con subconsulta correlacionada por fila. Sin índice en la columna de unión del origen, el coste crece de forma cuadrática en tablas grandes. No se comprueba la existencia del índice. | Aviso previo en la traza si falta el índice, o reescribir con `MERGE` |
| O2 | Media | Las clases no inyectivas (teléfono, dirección, nombre, observación) pueden producir ORA-00001 en columnas con índice único. El motor avisa de antemano (`UNICIDAD_RIESGO`) y cuando ocurre auto-excluye la columna, que queda sin enmascarar, y bloquea `FINALIZADO` (`PII_SIN_ENMASCARAR`). | Documentar como límite conocido. Para teléfono único, 25.000 valores distintos dan cerca del 50 % de colisión |
| O3 | Media | La clave AES se obtiene truncando un hash del pepper, sin función de derivación de claves. Es adecuado con 32 bytes aleatorios, pero un auditor lo señalará. | Documentar; opcionalmente derivar con HMAC y etiqueta de contexto |
| O4 | Media | En 11g el hash es SHA-1 y HMAC-SHA1, más débil que SHA-256 de 12c en adelante. | Documentar como compromiso de portabilidad |
| O5 | Baja | El nombre de tarea paralela es `DBMS_UTILITY.GET_HASH_VALUE` de propietario, tabla y columna con rango de 10 a la 9: no inyectivo. La probabilidad de choque es del orden de 5 por 10 a la -4 con 1.000 columnas. | Sustituir por una secuencia más tabla de correspondencia, o ampliar el nombre |
| O6 | Baja | Hay unos 50 `WHEN OTHERS THEN NULL`. La mayoría están en caminos informativos de traza o limpieza (justificados en el comentario). Los de consulta de estado de restricciones o triggers (33) dejan el estado en NULL si falla. | Que falle cerrado o deje traza |
| O7 | Baja | El instalador ignora el fallo de `GRANT SELECT ANY DICTIONARY` y de `EXECUTE` sobre `DBMS_CRYPTO` y delega en una validación final. | Aceptable; confirmar que la validación final falla de forma visible |
| O8 | Baja | `MANIFEST.md` está desactualizado y cita ficheros que ya no existen. | Regenerar |
| O9 | Baja | Nombres con dígitos de origen pasan sin cambiar los dígitos (los no alfabéticos se conservan por diseño). Con datos reales apenas ocurre. | Documentar el comportamiento |

**7. Límites de lo verificado**

- Nada de esta auditoría se ha compilado. En particular H1 y H2 no se han ejecutado, y la corrección de H1 debe compilarse también en 11g.
- No se ha ejecutado nunca el motor completo en 11g real; el piso 11.2.0.4 está asegurado solo por revisión estática del código.
- La purga de H2 no se ha ejercitado: la recarga limpia de DM_DUMMY dejó el catálogo vacío de huérfanos y, por tanto, no probó nada.
- El rendimiento a volumen no está certificado. No hay prueba A/B del coste de FF1.
- Quedan pruebas de datos tras el enmascarado sin ejecutar: cadena de 102 caracteres, IBAN con espacios a 24 continuos, NULL conservados, sincronización sin diferencias.

**8. Qué se pide al revisor**

Para cada punto, indicar si es **verificado en código** (con archivo y línea) o **deducido**, y proponer una prueba concreta que el responsable pueda ejecutar.

1. Corrección de FF1: contrastar `func_dm_ff1_cifrar_raw` y `func_dm_ff1_cifra` con el algoritmo 7 de NIST SP 800-38G (bloque P, relleno de Q, cifrado de la ronda, intercambio, cycle-walking) y señalar cualquier desviación, sobre todo con módulos que no son potencia de 10.
2. Compatibilidad 11g: buscar cualquier construcción, paquete, función o longitud de identificador que no compile o no funcione en 11.2.0.4, además de H1.
3. Propagación de integridad: revisar que el tweak por dominio y `pkg_dm_dominios` garanticen el mismo valor enmascarado a ambos lados de una clave foránea, incluida la sincronización sin clave.
4. Atomicidad y reanudación: confirmar que ninguna ruta de fallo, cancelación o reanudación puede cifrar una columna dos veces o dejarla en claro sin traza. Revisar `34`, `35` y `37` y la lógica de `APPLY_COL`.
5. Concurrencia: guarda de ejecuciones activas por esquema, tareas paralelas huérfanas y nombre de tarea (O5).
6. Seguridad: SQL dinámico, derechos del definidor, privilegios concedidos, custodia del pepper, y si el diseño soporta el argumento de seudonimización ante una auditoría.
7. Descubrimiento: falsos positivos y negativos probables de las reglas de `03_dm_descubrimiento_carga_reglas.sql` y del tope de 55 por contradicción de contenido.
8. Pruebas: huecos de cobertura en `tests/` y en el validador, y cualquier KPI que se cumpla por construcción en vez de comprobarse.
9. Verificar H1, H2 y H3 y valorar las observaciones O1 a O9, indicando si alguna merece subir de severidad.

**Formato de respuesta pedido:** tabla con identificador, severidad, archivo y línea, evidencia, estado (verificado o deducido), impacto y propuesta; después una lista de lo que se ha comprobado y se da por correcto.

**9. Orden de instalación y prueba**

```sql
-- Como SYS (el rol de DBA se concede a mano):
@98_uninstall
@99_install_datamasking

-- Tests del núcleo, con el esquema del motor:
@tests\00_run_tests_ff1.sql
@tests\dm_ff1_bitlen_check.sql

-- Esquema de prueba y flujo completo:
@tests\dm_dummy_01_ddl.sql
@tests\dm_dummy_02_dml.sql 0.5
@dm_descubre DM_DUMMY Y
@dm_enmascara <ejecucion_id>
@dm_validar_flujo DM_DUMMY <ejecucion_id>
```

> [!tip] Sustitución de variables
> `21_dm_pkg_desc_catalogo.sql` y otros scripts de paquetes empiezan con `set define off`. Si se ejecuta un `dm_*` en la misma sesión, hay que volver a `set define on` o abrir una sesión nueva.

**Referencias**

**Notas relacionadas**

- [[documento_tecnico_descubrimiento_scoring_enmascarado_2026-10-12]]
- [[peer_review_logica_errores_2026-10-12]]
- [[peer_review_motor_2026-10-12]]
- [[auditoria_limpieza_motor_2026-10-12]]
- [[README_DM_DUMMY]]

**Fuentes consultadas**

- [NIST SP 800-38G Rev. 1, Methods for Format-Preserving Encryption](https://csrc.nist.gov/pubs/sp/800/38/g/r1/2pd)
- Código del motor en su estado del 2026-10-12 (paquetes 10 a 40, scripts `dm_*`, 01, 02, 03, 97, 98, 99).
