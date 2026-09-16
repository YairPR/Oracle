# A-05 — Contrato de dominio para componentes de integridad referencial (FK)

**Estado:** Diseño propuesto (cierre parcial del hallazgo A-05 de la auditoría
consolidada FF1; la parte de código ya cerrada se referencia en la sección 6)
**Fecha:** 2026-09-16
**Ámbito:** definición explícita y verificable de qué debe coincidir entre dos
columnas relacionadas por una clave foránea (FK) para que el motor las
enmascare de forma coherente.

## 1. Problema

El motor garantiza hoy la consistencia de FK principalmente porque el ajuste
(*tweak*) de FF1 depende **solo** del identificador semántico del dominio
(`IDENTIDAD`, `CUENTA`, `IBAN` — constantes fijadas en el código), no de la
tabla, columna, ROWID o fila. Esto hace que dos columnas que comparten
identificador reciban el mismo ajuste y, si además reciben la misma longitud y
la misma función de enmascarado, produzcan el mismo valor de salida para el
mismo valor de entrada.

El problema, señalado en la auditoría consolidada, es que esta coincidencia es
**necesaria pero no suficiente**, y hoy **no existe ningún contrato escrito y
verificable** que declare explícitamente qué debe coincidir entre los dos
extremos de una FK para que el enmascarado sea coherente. En concreto:

- El ajuste (`tweak`) es una constante de código (`IDENTIDAD`/`CUENTA`/`IBAN`),
  no el valor de `dominio` persistido en las tablas de configuración del
  motor. Dos columnas podrían compartir el `dominio` lógico en la
  configuración y sin embargo no compartir el mismo *tweak* real si alguien
  modifica el código sin actualizar ambos sitios a la vez.
- La igualdad de resultado exige, además del *tweak*, que ambas columnas usen
  el **mismo parser/canonicalizador**, la **misma longitud** y la **misma
  función** de enmascarado. Nada en el diseño actual valida esto de forma
  automática antes de enmascarar: dos columnas conectadas por FK podrían tener
  configuraciones distintas (por ejemplo, una tratada como `NIF` con guiones y
  la otra como texto plano de 9 caracteres) y el motor no lo detectaría hasta
  que aparecieran huérfanos de integridad referencial, o peor, no lo
  detectaría en absoluto si las longitudes coincidieran por casualidad.
- La auditoría señala también que la API del motor recibe un solo esquema por
  ejecución, lo cual es relevante para el caso de FK que cruzan esquemas (ver
  sección 5).

Este documento propone la estructura de un **contrato de dominio** explícito,
versionado y persistido, que resuelva esta ambigüedad.

## 2. Objetivo del contrato de dominio

Un contrato de dominio es un registro declarativo que dice, para un tipo de
dato lógico dado (DNI, CUENTA, IBAN, texto, etc.), **exactamente** qué reglas
se aplican para canonicalizar, cifrar y validar los valores de ese dominio, de
forma que:

1. Cualquier columna que declare pertenecer a ese contrato es, por definición,
   coherente con cualquier otra columna que declare el mismo contrato.
2. El motor puede **validar automáticamente**, en tiempo de descubrimiento o
   de propagación, que dos columnas unidas por FK comparten el mismo
   contrato, y bloquear con un error explícito si no es así, en vez de
   enmascarar en silencio con configuraciones divergentes.
3. El contrato queda versionado, de forma que un cambio futuro (por ejemplo,
   rotar el esquema de derivación de clave) no rompe silenciosamente la
   coherencia de campañas antiguas ni mezcla contratos incompatibles dentro de
   una misma ejecución.

## 3. Campos mínimos del contrato

| Campo | Descripción | Por qué es necesario |
|---|---|---|
| `dominio_id` | Identificador único y estable del contrato (p. ej. `IDENTIDAD`, `CUENTA`, `IBAN_BBAN`, `TEXTO_NOMBRE`). | Es la clave que dos columnas deben compartir para considerarse del mismo contrato. Debe ser estable en el tiempo: renombrarlo invalidaría la comparación entre campañas. |
| `canonicalizador` | Función o regla de normalización aplicada al valor **antes** de cifrar (p. ej. quitar guiones y espacios, pasar a mayúsculas, extraer solo dígitos, validar dígito de control). | Dos valores que representan la misma entidad pero llegan con formato distinto (`12345678Z` vs `12345678-Z`) deben producir el mismo resultado. Si el canonicalizador difiere entre las dos columnas de una FK, el cifrado producirá resultados distintos aunque el resto del contrato coincida. Es, junto con el `tweak`, la causa más probable de incoherencia silenciosa hoy. |
| `tipo_dato_logico` | Clasificación semántica del valor: `DNI`, `NIE`, `CIF`, `CUENTA`, `IBAN`, `TEXTO_LIBRE`, etc. | Determina qué algoritmo aplica (FF1 numérico vs. HMAC+síntesis textual) y qué reglas de validación de formato corresponden. |
| `radix` | Base numérica del alfabeto FF1 (10 para dominios numéricos decimales). | FF1 exige declarar explícitamente el radix; dos columnas con radix distinto no pueden compartir tweak/clave de forma coherente, y el radix debe quedar fijado por contrato, no inferido en tiempo de ejecución. |
| `longitud_fija` | Longitud exacta esperada del valor canonicalizado (p. ej. 9 para DNI/NIE, 20 para BBAN español, 24 para IBAN español completo). | FF1 opera sobre cadenas de longitud fija; una discrepancia de longitud entre dos columnas del mismo dominio produce salidas distintas de forma determinista (no es un error aleatorio, es sistemático), lo que ya fue causa de C-01 en la auditoría (truncado del IBAN continuo). Fijar la longitud en el contrato hace que esa clase de error sea detectable antes de enmascarar, no después. |
| `tweak_id` (identificador de ajuste / dominio semántico) | El valor exacto usado como *tweak* de FF1 o como semilla de dominio del HMAC. | Es el campo que hoy vive como constante de código. Persistirlo en el contrato permite comparar explícitamente si dos columnas comparten el mismo ajuste, en vez de confiar en que dos partes del código usen la misma constante por convención. |
| `key_version` | Versión del esquema de derivación de clave (hoy: SHA-1 del pepper hexadecimal; en el futuro podría cambiar el KDF). | Permite rotar el esquema de derivación de clave sin invalidar retroactivamente contratos ya usados en campañas pasadas, y evita mezclar, dentro de una misma comparación FK, columnas cifradas bajo dos derivaciones de clave incompatibles. |
| `algoritmo_version` | Identificador y versión del algoritmo de enmascarado aplicado (p. ej. `FF1_v1`, `HMAC_SINT_v1`). | Si en el futuro el núcleo cambia (por ejemplo, una FF1 v2 con distinto número de rondas, o un cambio del canonicalizador de un tipo de documento tras corregir un hallazgo como A-01), el contrato antiguo debe seguir siendo identificable y no confundirse con el nuevo. |

Campos adicionales recomendados (no mínimos, pero convenientes):

| Campo | Descripción |
|---|---|
| `activo` | Indica si el contrato puede usarse en nuevas campañas o está deprecado. |
| `fecha_alta` / `fecha_baja` | Trazabilidad de cuándo se creó o dejó de usar un contrato. |
| `descripcion` | Texto libre explicando el propósito del dominio, para lectura humana en auditoría. |
| `hash_definicion` | Hash calculado sobre los campos anteriores, para detectar si el contrato fue modificado sin cambiar `algoritmo_version` (protección contra edición accidental). |

## 4. Propuesta de estructura como tabla

Esta es una propuesta de diseño, no código final ni una DDL destinada a
ejecutarse tal cual; su objetivo es fijar la forma del contrato para discutirlo
y, en su momento, implementarlo con el estilo y convenciones ya establecidas
en el resto del esquema `tdm_*`.

```sql
-- PROPUESTA DE DISEÑO (no ejecutar sin revisión del equipo de desarrollo)
CREATE TABLE tdm_contrato_dominio (
    dominio_id          VARCHAR2(60)  NOT NULL,  -- PK: 'IDENTIDAD', 'CUENTA', 'IBAN_BBAN', ...
    tipo_dato_logico     VARCHAR2(30)  NOT NULL,  -- 'DNI','NIE','CIF','CUENTA','IBAN','TEXTO_LIBRE',...
    canonicalizador      VARCHAR2(60)  NOT NULL,  -- nombre lógico de la función de normalización
    radix                NUMBER(3)     NOT NULL,  -- 10 para numérico decimal
    longitud_fija        NUMBER(5)     NOT NULL,
    tweak_id             VARCHAR2(60)  NOT NULL,
    key_version          VARCHAR2(20)  NOT NULL,  -- p.ej. 'KDF_SHA1_V1'
    algoritmo_version    VARCHAR2(30)  NOT NULL,  -- p.ej. 'FF1_V1', 'HMAC_SINT_V1'
    activo               CHAR(1)       DEFAULT 'S' NOT NULL,
    fecha_alta           DATE          DEFAULT SYSDATE NOT NULL,
    fecha_baja           DATE,
    descripcion          VARCHAR2(400),
    hash_definicion      VARCHAR2(64),             -- hash de los campos de definición
    CONSTRAINT pk_tdm_contrato_dominio PRIMARY KEY (dominio_id),
    CONSTRAINT ck_tdm_contrato_dominio_activo CHECK (activo IN ('S','N'))
);

-- Cada columna descubierta/enmascarada referenciaría su contrato, p. ej. como
-- columna adicional en la tabla de configuración de columnas del motor
-- (tdm_excepcion_col o equivalente):
--   ALTER TABLE tdm_excepcion_col ADD (dominio_id VARCHAR2(60)
--     CONSTRAINT fk_excepcion_col_dominio REFERENCES tdm_contrato_dominio(dominio_id));
```

Notas de diseño:

- `dominio_id` es intencionadamente el mismo concepto que hoy se llama
  "identificador semántico" en el código (`IDENTIDAD`, `CUENTA`, `IBAN`), pero
  persistido y con reglas explícitas, no como literal repetido en varios
  puntos del código.
- La FK desde la tabla de configuración de columnas hacia
  `tdm_contrato_dominio` asegura que cada columna que el motor descubre y
  enmascara declare su contrato, y que ese contrato exista y esté vigente
  (`activo = 'S'`).

## 5. Validación automática en descubrimiento/propagación

Se propone que el motor, en la fase de descubrimiento y propagación de FK
(hoy resuelta con Union-Find sobre las relaciones declaradas), incorpore un
paso de validación explícito:

1. Para cada relación de FK detectada entre columna padre y columna hija,
   resolver el `dominio_id` configurado para cada una.
2. Si ambos extremos declaran el **mismo** `dominio_id`, continuar (caso
   esperado y correcto).
3. Si los extremos declaran `dominio_id` **distintos**, o uno de los dos no
   tiene contrato configurado, **bloquear con un error explícito** que
   identifique la tabla, columna y los dos contratos en conflicto (o la
   ausencia de contrato), en lugar de:
   - enmascarar en silencio con configuraciones distintas (lo que produciría
     huérfanos de integridad referencial sin que nadie lo note hasta la
     validación de constraints, si es que se valida), o
   - asumir un valor por defecto sin dejar rastro de que la coincidencia fue
     "adivinada" y no verificada.
4. El resultado de esta validación debe formar parte de la trazabilidad de la
   campaña (log/reporte de campaña), de forma que un auditor pueda ver, por
   cada componente de FK, qué contrato se aplicó y que la coincidencia fue
   verificada, no supuesta.

Esta validación convierte una condición hoy implícita ("el tweak es una
constante de código, así que en la práctica coincide") en una condición
explícita, persistida y comprobada en cada ejecución, cerrando la brecha
señalada por A-05: coincidencia *necesaria pero no verificada* pasa a ser
coincidencia *necesaria y verificada, o bloqueo con diagnóstico*.

## 6. Caso multiesquema (FK cruzando dos esquemas Oracle)

La auditoría consolidada señala que la API del motor procesa un único esquema
por invocación, lo que en principio contradice la idea de que una FK que
cruza dos esquemas pueda enmascararse de forma coherente en ambos lados: si
cada esquema se procesara en una ejecución separada, cada una generaría (o
podría generar) su propio pepper de campaña, y dos peppers distintos producen
dos claves AES distintas, rompiendo la coherencia del valor enmascarado entre
ambos esquemas.

**Postura operativa recomendada mientras la API siga operando sobre un
esquema a la vez:**

- Exigir explícitamente que, cuando existan FK entre dos esquemas Oracle
  distintos, **ambos esquemas se procesen dentro de la misma ejecución /
  campaña**, de forma que compartan el mismo `ejecucion_id` y, por tanto, el
  mismo pepper y la misma clave AES derivada.
- Esta restricción debe quedar **documentada explícitamente** como requisito
  operativo del runbook de la campaña (por ejemplo, en el guion de uso o en el
  procedimiento de preparación de campaña), no dejarse implícita ni asumida
  por quien opera el proceso.
- El motor debería, idealmente, poder **detectar** en descubrimiento cuándo
  una FK cruza esquemas y verificar que ambos esquemas pertenecen a la misma
  ejecución declarada; si no es así, debe bloquear con el mismo criterio de
  fail-closed descrito en la sección 5 (error explícito, no enmascarado
  parcial en silencio), en vez de limitarse a advertir.
- Si en un despliegue concreto no es operativamente viable procesar ambos
  esquemas en la misma campaña (por ejemplo, por separación organizativa de
  quién administra cada esquema), la alternativa aceptable es declarar esa FK
  cross-schema **explícitamente fuera de alcance** del enmascarado
  automático y tratarla como excepción documentada, nunca dejarla enmascarar
  de forma parcial o incoherente sin que quede registrado.

## 7. Resumen de la propuesta

| Elemento | Estado hoy | Propuesta |
|---|---|---|
| Coincidencia de ajuste (tweak) | Constante de código, implícita | Campo `tweak_id` persistido y comparable en `tdm_contrato_dominio` |
| Coincidencia de canonicalización | No verificada explícitamente | Campo `canonicalizador` obligatorio en el contrato, comparado antes de enmascarar |
| Coincidencia de longitud | No verificada explícitamente | Campo `longitud_fija` obligatorio, comparado antes de enmascarar |
| Versión de derivación de clave | Fija, sin versionado | Campo `key_version`, permite rotación futura sin romper campañas antiguas |
| Versión de algoritmo | Fija, sin versionado explícito por columna | Campo `algoritmo_version`, permite evolución (FF1 v2, correcciones de canonicalizador) sin ambigüedad |
| Validación de FK entre columnas | Implícita, no bloqueante | Paso explícito en descubrimiento/propagación: mismo contrato obligatorio, error si difiere |
| FK cross-schema | Contradice el invariante asumido (API de un solo esquema) | Requisito operativo explícito: mismo esquema de ejecución, o exclusión documentada |

## 8. Fuentes y contexto

Este documento desarrolla la parte de diseño/gobernanza del hallazgo **A-05**
de la auditoría consolidada `00_AUDITORIA_CONSOLIDADA_FF1.md` ("Propagación FK
necesaria pero no suficiente: el tweak usa constantes `IDENTIDAD/CUENTA/IBAN`,
no el `dominio` persistido; la igualdad exige además mismo parser/longitud/
función; la API recibe un solo esquema, lo que contradice el invariante
multiesquema del runbook"), severidad Alta, verificación **[C]** confirmado en
código. La parte de corrección de código de A-05 (que el tweak/función/
longitud coincidan por extremo de FK y que se detecte y bloquee FK fuera de
alcance) está prevista en la Fase 0 del plan de remediación de dicha
auditoría; este documento cubre específicamente la parte de diseño de
gobernanza (contrato de dominio y postura multiesquema) que la Fase 3 asigna a
Riesgo/DPO.
