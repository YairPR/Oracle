# M-02 — Seudonimización determinista vs. anonimización

**Estado:** Documentado (cierre de hallazgo M-02 de la auditoría consolidada FF1)
**Fecha:** 2026-09-16
**Ámbito:** clasificación jurídico-técnica del resultado producido por el motor
de enmascaramiento (núcleo FF1/AES-128 sobre dominios numéricos + HMAC-SHA1 y
generación sintética sobre dominios de texto libre).
**Destinatarios:** DPO / delegado de protección de datos, responsable de
ciberseguridad, auditoría interna u oracle, y cualquier interlocutor externo
(Oracle, auditoría del organismo, inspección).

## 1. Resumen ejecutivo

El motor descrito en este proyecto produce **seudonimización determinista**,
no **anonimización**. Esta distinción no es semántica: determina el régimen
jurídico aplicable a la base de datos destino (entorno de desarrollo o
preproducción) mientras exista, en cualquier parte, el secreto de campaña
("pepper") que permitió generar los valores enmascarados.

Este documento fija la posición oficial del proyecto para que quede citable
ante el DPO, ante Oracle o ante cualquier auditoría de ciberseguridad o
gubernamental, evitando afirmaciones que no se pueden sostener técnicamente.

## 2. Marco conceptual (RGPD / LOPDGDD)

El Reglamento General de Protección de Datos (RGPD) y su desarrollo en España
(LOPDGDD) distinguen dos conceptos que no son intercambiables:

| Concepto | Definición operativa (RGPD art. 4.5 y considerando 26) | Consecuencia jurídica |
|---|---|---|
| **Seudonimización** | El tratamiento de datos personales de manera que ya no puedan atribuirse a un interesado sin utilizar información adicional, siempre que dicha información adicional figure por separado y esté sujeta a medidas técnicas y organizativas destinadas a garantizar que los datos personales no se atribuyan a una persona física identificada o identificable. | **Los datos seudonimizados SIGUEN SIENDO datos personales.** El RGPD sigue aplicando en su totalidad al conjunto seudonimizado. |
| **Anonimización** | Proceso irreversible que impide, de forma permanente e incondicional, volver a identificar al interesado, incluso combinando la información con cualquier otro dato razonablemente disponible, para cualquier persona, en cualquier momento futuro. | Los datos dejan de ser datos personales. El RGPD deja de aplicar sobre ese conjunto. |

La diferencia clave para este proyecto es la cláusula **"información adicional
que se mantiene por separado y de forma segura"**: eso es, exactamente, lo que
hace el pepper de campaña respecto a los valores numéricos enmascarados.

## 3. Por qué el motor produce seudonimización y no anonimización

Se argumenta con las propiedades técnicas reales del motor, verificadas en la
auditoría consolidada (`00_AUDITORIA_CONSOLIDADA_FF1.md`) y en el código
(`06_dm_pkg_func_mask.sql`):

### 3.1 Determinismo dentro de campaña

El motor está diseñado para que el mismo valor de entrada produzca siempre el
mismo valor de salida mientras dura la campaña de ejecución (mismo pepper):

- **Dominios numéricos de longitud fija** (DNI/NIE/CIF, número de cuenta, BBAN
  del IBAN): cifrados con FF1 (FPE, NIST SP 800-38G) sobre AES-128. El ajuste
  (*tweak*) depende del identificador semántico del dominio (`IDENTIDAD`,
  `CUENTA`, `IBAN`), no de la fila ni de la tabla, precisamente para que la
  integridad referencial (FK) se conserve entre columnas relacionadas.
- **Dominios de texto libre** (nombre, dirección, email, teléfono): usan
  HMAC-SHA1 + generación sintética. No preservan igualdad exacta con la misma
  fidelidad que los numéricos, pero también son deterministas dentro de la
  misma campaña/pepper.

Este determinismo es exactamente la propiedad que la anonimización prohíbe: un
proceso de anonimización real puede (y a menudo debe) introducir ruido o
generalización no reversible que rompa la correspondencia 1:1 entre entrada y
salida. Aquí la correspondencia 1:1 es una característica **buscada
intencionalmente**, porque sin ella se rompería la integridad referencial que
el proyecto necesita para que los entornos no productivos sigan siendo
funcionalmente coherentes.

### 3.2 Biyectividad numérica

FF1 es, por construcción, biyectivo dentro de cada combinación (longitud,
dominio semántico): cero colisiones, cada valor de entrada tiene una imagen
única y cada imagen corresponde a un único valor de entrada. Esta propiedad,
deseable para preservar la unicidad de claves primarias/candidatas, implica
matemáticamente que **la transformación es invertible dado el par
(clave, ajuste)**. No es un hash de un solo sentido: es un cifrado.

### 3.3 Reversibilidad teórica condicionada a la posesión del secreto

La clave AES-128 usada por FF1 se deriva del pepper de campaña
(`SHA-1(pepper)` truncado a 16 bytes, ver `06_dm_pkg_func_mask.sql`,
`f_clave_aes`). El pepper se genera con `DBMS_CRYPTO.RANDOMBYTES(32)` (CSPRNG)
y se almacena, mientras la campaña está activa, en la tabla `tdm_secreto`
bajo la clave `'PEPPER_MASK:'||ejecucion_id`.

Esto significa que **mientras el pepper exista en algún sitio** (la tabla
`tdm_secreto`, una copia de seguridad, un volcado de redo/undo, un snapshot de
flashback, una réplica de Data Guard), cualquiera que lo obtenga puede derivar
la misma clave AES y, en teoría, invertir la transformación FF1 sobre los
identificadores numéricos de esa campaña. El propio código del proyecto lo
reconoce en la cabecera de `06_dm_pkg_func_mask.sql`: *"Irreversible en la
práctica -> sin la clave AES (derivada del pepper)"* — es decir, la
irreversibilidad es una propiedad **operativa** (depende de que el secreto se
destruya y no queden copias recuperables), no una propiedad **matemática**
del algoritmo (que sí es invertible con la clave).

Esto es, letra por letra, el escenario que el RGPD describe como
seudonimización: "no puedan atribuirse a un interesado sin utilizar
información adicional, siempre que dicha información adicional figure por
separado y esté sujeta a medidas técnicas de seguridad". El pepper es esa
información adicional. La solidez de la separación depende de la custodia del
pepper, tratada en detalle en el documento `A04_custodia_del_pepper.md`, no del
diseño del algoritmo de enmascarado en sí.

### 3.4 Conclusión formal

| Propiedad exigida por la anonimización (RGPD, considerando 26) | ¿La cumple el motor? |
|---|---|
| Irreversibilidad permanente e incondicional | **No.** Reversible en teoría mientras exista el pepper de campaña. |
| Ninguna información adicional permite reidentificar, en ningún momento futuro | **No.** El pepper es exactamente esa información adicional, y su destrucción es un proceso operativo (`DELETE`), no una garantía criptográfica de borrado físico. |
| Determinismo/igualdad no debería preservarse (para evitar reidentificación por correlación) | **No aplica igual.** El motor preserva determinismo intencionalmente, para no romper FK. |

Por tanto: **el resultado del motor es seudonimización determinista, no
anonimización**, y debe tratarse como tal en cualquier documento de
gobernanza, comunicación externa o respuesta a auditoría.

## 4. Implicaciones para la base de datos destino

La base de datos destino (el entorno de desarrollo o preproducción donde caen
los datos ya "enmascarados") **sigue tratando datos personales bajo RGPD**
mientras el pepper de esa campaña no se haya destruido de forma verificable.
Esto tiene consecuencias prácticas:

- El entorno destino no queda automáticamente fuera del alcance del RGPD por
  el mero hecho de haber pasado por el motor de enmascaramiento.
- Los controles de acceso, retención y seguridad exigibles a un entorno con
  datos personales (control de acceso, cifrado en tránsito/reposo, registro de
  accesos, minimización, etc.) siguen siendo aplicables al entorno destino
  hasta que se pueda demostrar la destrucción efectiva del pepper de esa
  campaña (ver documento A-04 para el estado actual y las mejoras propuestas
  de custodia y purga).
- Una vez el pepper de una campaña queda destruido de forma verificable y sin
  copias recuperables (backups, redo/undo, flashback, réplicas), el riesgo de
  reidentificación de los identificadores numéricos de esa campaña baja
  drásticamente, aunque los dominios de texto libre generados por HMAC-SHA1 +
  síntesis nunca alcanzan el mismo nivel de garantía formal que el análisis
  criptográfico de FF1, por no ser el objeto de esta migración.
- Cada campaña tiene su propio pepper; la destrucción de una campaña no
  garantiza nada sobre campañas anteriores o futuras cuyos peppers puedan
  seguir existiendo en el sistema.

## 5. Qué decir y qué no decir

Esta sección es de uso directo para comunicaciones con Oracle, con el equipo
de ciberseguridad, con el DPO o con cualquier auditoría externa o
gubernamental.

### 5.1 Evitar

- "Datos anonimizados."
- "Proceso irreversible."
- "Ya no son datos personales."
- "Los datos destino no están sujetos a RGPD."
- "Certificado NIST" o "conforme NIST" (la auditoría consolidada ya señala que
  esto tampoco es correcto: es una implementación *basada en* FF1, validada por
  vectores de prueba, no una certificación formal).

### 5.2 Usar

> "Los datos se han **seudonimizado de forma determinista mediante cifrado
> FF1/AES-128** (para identificadores numéricos de longitud fija) y HMAC-SHA1
> con generación sintética (para texto libre), **con reversibilidad
> condicionada a la posesión del secreto de campaña (pepper)**, el cual se
> genera de forma aleatoria criptográfica por cada ejecución y se **destruye
> tras cada exportación**. Mientras ese secreto exista, el entorno destino
> sigue sujeto a las obligaciones de protección de datos personales que
> corresponden a un tratamiento de datos seudonimizados."

Esta formulación es defendible porque describe con precisión lo que el motor
hace y no afirma ninguna propiedad que no se pueda sostener ante un análisis
técnico.

## 6. Fuentes y contexto

Este documento cierra el hallazgo **M-02** de la auditoría consolidada
`00_AUDITORIA_CONSOLIDADA_FF1.md` ("FPE determinista conserva longitud,
igualdad y frecuencias (seudonimización, no anonimización); DNI/NIE/CIF
comparten `IDENTIDAD` y conservan prefijos"), clasificado en dicha auditoría
como severidad Media, verificación **[C]** confirmado por diseño, con cierre
recomendado mediante documentación (Fase 3 — Gobernanza). Las propiedades
técnicas citadas (FF1/AES-128, tweak por dominio semántico, pepper CSPRNG por
campaña, ausencia de `DETERMINISTIC` tras el cierre de A-02) están descritas en
la cabecera y el cuerpo de `06_dm_pkg_func_mask.sql`.
