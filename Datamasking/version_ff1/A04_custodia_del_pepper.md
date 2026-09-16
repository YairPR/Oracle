# A-04 — Custodia del secreto criptográfico (pepper)

**Estado:** Recomendación de gobernanza (cierre parcial del hallazgo A-04 de la
auditoría consolidada FF1)
**Fecha:** 2026-09-16
**Ámbito:** custodia, acceso y destrucción del secreto de campaña (pepper) del
que se deriva la clave AES-128 usada por FF1.
**Destinatarios:** DBA responsable del motor, responsable de ciberseguridad y/o
DPO del organismo, para decidir la inversión y el proceso a adoptar.

## 1. Por qué importa este documento

Todo el argumento de seudonimización (frente a anonimización) del proyecto —
desarrollado en `M02_seudonimizacion_vs_anonimizacion.md` — descansa en una
premisa: que el pepper de cada campaña se destruye de forma efectiva tras el
export. Este documento examina qué tan sólida es esa premisa hoy y qué se
puede hacer para reforzarla, con opciones ordenadas de menor a mayor esfuerzo
y con sus contrapartidas explícitas, para que la decisión de cuánto invertir
sea informada y no una promesa sin respaldo operativo.

## 2. Estado actual

| Aspecto | Situación hoy |
|---|---|
| Formato de almacenamiento | El pepper se guarda como texto claro hexadecimal en la tabla `tdm_secreto`, bajo la clave `'PEPPER_MASK:'||ejecucion_id`. |
| Mecanismo de protección | Ninguno específico: es una tabla Oracle ordinaria, sin wallet, sin HSM, sin KMS externo. |
| Separación de funciones | No existe separación entre quien opera el proceso de enmascarado (ejecuta las campañas, con acceso de lectura/escritura al esquema del motor) y quien custodia el secreto: son, en la práctica, el mismo rol/usuario de base de datos. |
| Generación | `DBMS_CRYPTO.RANDOMBYTES(32)` — un generador criptográficamente seguro (CSPRNG), esto es correcto y no requiere cambio. |
| Purga | Manual, mediante un procedimiento de purga separado (`dm_pepper_purgar`); el procedimiento de exportación (`p_export_mask`) **no** la ejecuta automáticamente. |
| Naturaleza de la purga | Un `DELETE` sobre la fila de `tdm_secreto`. Un `DELETE` en Oracle **no** garantiza destrucción física del dato: puede persistir en redo logs, en segmentos de undo, en snapshots de flashback, en backups (RMAN, exports lógicos) ya tomados mientras el pepper existía, o en réplicas de Data Guard. |
| Manejo de errores en escritura | Un `DUP_VAL_ON_INDEX` al insertar el pepper no fuerza un `ROLLBACK` explícito, lo que puede dejar el estado de la sesión en una condición ambigua respecto a qué pepper quedó realmente vigente (aspecto ya señalado como parte de A-04 en la auditoría de código). |

## 3. Riesgo concreto que esto representa

El riesgo no es hipotético ni depende de errores exóticos: se deriva
directamente del diseño descrito arriba.

- **Durante la ventana en que el pepper existe** (desde que se genera hasta
  que se purga, y mientras persista en cualquier copia derivada de la base:
  backup, redo/undo, flashback, réplica), **cualquier cuenta o proceso con
  permiso de lectura (`SELECT`) sobre `tdm_secreto`** puede leer el pepper en
  claro, derivar la misma clave AES-128 que usó el motor
  (`SHA-1(pepper)` truncado a 16 bytes) y, con esa clave, **descifrar los
  identificadores numéricos ya enmascarados de esa campaña** (DNI/NIE/CIF,
  cuentas, IBAN), porque FF1 es biyectivo y el algoritmo de descifrado ya
  existe y está verificado (vive fuera del motor de producción, en el paquete
  de pruebas, pero el algoritmo en sí es público y estándar — NIST
  SP 800-38G — por lo que cualquiera con la clave puede reimplementarlo).
- Esto significa que la seguridad del enmascarado numérico de una campaña
  **completa** depende, en la práctica, de quién tuvo acceso de lectura a una
  sola tabla durante la ventana de vida del pepper. No depende de la fortaleza
  del algoritmo FF1/AES-128, que es sólido, sino de un control de acceso a
  nivel de tabla que hoy no está reforzado ni auditado específicamente para
  este propósito.
- El **`DELETE` de purga no es una garantía criptográfica de irrecuperabilidad**.
  Un pepper purgado por `DELETE` puede seguir siendo recuperable por alguien
  con acceso a:
  - los **redo logs** generados durante el `INSERT` original (si no han sido
    reciclados/archivados y purgados a su vez),
  - segmentos de **undo** todavía activos poco después del `DELETE`,
  - un **flashback query** o **flashback table** ejecutado dentro de la
    ventana de retención de flashback de la base,
  - un **backup RMAN o export lógico** tomado en cualquier momento entre la
    generación del pepper y su purga,
  - una **réplica de Data Guard** (física o lógica) que haya recibido el
    `INSERT` antes de que el `DELETE` se propague, o cuyo propio historial de
    redo aplicado conserve el dato.

  En ninguno de estos casos hace falta "romper" ningún cifrado: basta con leer
  el pepper donde quedó, en claro.

En resumen: el riesgo no es que FF1/AES-128 sea débil — no lo es —, sino que
**el secreto del que depende toda la seguridad del esquema numérico se
custodia hoy con el mismo nivel de protección que cualquier tabla de
configuración ordinaria**, y su borrado se apoya en una operación de base de
datos (`DELETE`) que no fue diseñada para dar garantías criptográficas de
destrucción.

## 4. Opciones de mejora, en orden de esfuerzo creciente

### 4.1 Opción (a) — Mínimo esfuerzo: control de acceso y TTL automático

**Qué implica:**

- Separar el rol que **genera y purga** el pepper del rol que **opera** el
  resto del proceso de enmascarado (descubrimiento, propagación, ejecución de
  `UPDATE`s). El motor ya usa `AUTHID`/definer rights en sus paquetes PL/SQL;
  la recomendación es apoyarse en ese mecanismo existente:
  - **Revocar `SELECT` directo** sobre `tdm_secreto` a cualquier rol/usuario
    que no sea estrictamente necesario, incluidos los roles operativos del
    día a día.
  - Forzar que el acceso al pepper ocurra **únicamente** a través de las
    funciones PL/SQL del motor que ya tienen definer rights (es decir, el
    código puede leer la tabla porque el paquete se ejecuta con los
    privilegios de su propietario, pero un usuario que se conecte
    directamente y haga `SELECT * FROM tdm_secreto` no debería poder).
- Añadir un **job de purga automática por TTL** (tiempo de vida máximo) que
  elimine peppers de campañas cerradas hace más de N días, **aunque el
  operador olvide ejecutar la purga manual**. Esto convierte la purga de un
  paso manual (que ya la auditoría señala que `p_export_mask` no ejecuta
  automáticamente) en una garantía de fondo que no depende de que nadie se
  acuerde de invocarla.

**Trade-offs:**

- Esfuerzo bajo: son cambios de `GRANT`/`REVOKE` y un job programado
  (`DBMS_SCHEDULER`), no requieren nueva infraestructura ni licencias.
- No resuelve el problema de fondo de que el pepper sigue viviendo en texto
  claro en un datafile ordinario, ni protege contra quien tenga acceso a nivel
  de sistema operativo, backup o redo/undo.
- Es la mejora con mejor relación coste/beneficio dado que el proyecto corre
  hoy en Oracle 11g+ sin wallet.

### 4.2 Opción (b) — Esfuerzo intermedio: TDE a nivel de columna

**Qué implica:**

- Envolver el pepper con **Oracle Transparent Data Encryption (TDE) a nivel de
  columna**, aplicado específicamente sobre `tdm_secreto.valor` (la columna
  que contiene el pepper en hexadecimal).
- Con TDE column encryption, el valor se almacena cifrado en el datafile, en
  los backups tomados con RMAN y, según configuración, en redo/undo. Un acceso
  directo al datafile, a un backup, o a una copia física de los ficheros de la
  base **no expone el pepper en claro**, aunque el acceso lógico vía `SELECT`
  con los privilegios correctos sigue mostrando el valor descifrado (TDE
  protege el dato en reposo, no sustituye el control de acceso lógico de la
  opción (a); ambas son complementarias, no alternativas).

**Nota importante:** esto **no requiere** desplegar un Oracle Wallet completo
para todo el esquema ni migrar todas las tablas del motor a TDE. Basta con
habilitar TDE column encryption sobre esa columna concreta, lo cual sí exige
un wallet mínimo (TDE en Oracle siempre se apoya en un wallet para custodiar
la clave maestra de cifrado de columna), pero su alcance puede limitarse
estrictamente a esa columna sin tocar el resto del esquema.

**Trade-offs:**

- Esfuerzo medio: requiere crear y gestionar un wallet (aunque sea de alcance
  reducido), coordinarlo con el ciclo de vida de la base (apertura del wallet
  al arrancar la instancia, procedimiento de rotación de la clave maestra), y
  probar que no introduce fricción operativa en el arranque de la base.
  Además, TDE de columna añade una capa de gestión de claves (la propia clave
  maestra de TDE) que a su vez debe custodiarse con cuidado, aunque de forma
  centralizada por Oracle y no por el propio motor.
- Reduce significativamente el riesgo de exposición por acceso a backups o al
  sistema de archivos, que es precisamente uno de los vectores señalados en la
  sección 3 (backups, redo/undo, flashback).
- Es un paso razonable **después** de (a), no un sustituto: (a) cierra el
  acceso lógico indebido; (b) cierra la exposición del dato en reposo.

### 4.3 Opción (c) — Esfuerzo avanzado: Wallet / KMS externo

**Qué implica:**

- Usar **Oracle Wallet** de alcance completo, o un **gestor de claves externo**
  (KMS) como Azure Key Vault, AWS KMS, o un HSM si el organismo ya dispone de
  uno, de forma que **el pepper nunca resida como texto plano en ninguna
  tabla de la base de datos**. El pepper se generaría y usaría únicamente
  dentro de llamadas a la API del KMS externo: el motor pediría al KMS que
  genere y entregue el secreto para una operación de derivación de clave, sin
  persistirlo nunca en `tdm_secreto` ni en ninguna otra tabla propia.

**Trade-offs:**

- Esfuerzo alto: requiere integración de red entre la base de datos Oracle y
  el servicio de KMS (o hardware HSM), gestión de credenciales de acceso al
  propio KMS (que a su vez hay que custodiar), y probablemente cambios más
  profundos en el flujo del motor (llamadas HTTP/API desde PL/SQL, o un
  componente intermedio) para no romper el patrón actual de sesión/campaña.
- Es el nivel de protección más sólido: elimina por completo la superficie de
  ataque de "leer una tabla" o "leer un backup", porque el secreto nunca vive
  ahí.
- Solo tiene sentido si el organismo **ya tiene gobernanza de KMS establecida**
  para otros sistemas: montar un KMS o HSM exclusivamente para este proceso de
  enmascarado de entornos no productivos sería sobre-ingeniería
  desproporcionada al riesgo real que se está mitigando.

## 5. Recomendación pragmática de por dónde empezar

El motor corre hoy sobre Oracle 11g en adelante, **sin wallet desplegado
actualmente**. Dado ese punto de partida y que el proceso protege datos en
entornos de **desarrollo/preproducción** (no producción con datos vivos en
producción continua), la recomendación pragmática es:

1. **Ahora mismo — Opción (a).** Es de bajo coste, no requiere nueva
   infraestructura y cierra la parte más importante del riesgo práctico: que
   cualquier cuenta con acceso de lectura al esquema pueda leer el pepper
   directamente, y que una purga manual olvidada deje un pepper vivo
   indefinidamente.
2. **Siguiente paso razonable — Opción (b).** Una vez la opción (a) esté
   operativa y estable, evaluar TDE de columna sobre `tdm_secreto.valor` como
   endurecimiento adicional frente a exposición vía backups o acceso a nivel
   de sistema de archivos, que es un vector realista dado que los backups de
   la base son un activo que circula fuera del control directo del DBA del
   motor.
3. **Solo si el organismo ya tiene gobernanza de KMS — Opción (c).** No
   iniciar un proyecto de Wallet/KMS/HSM específicamente para este propósito
   si no existe ya esa capacidad en el organismo para otros sistemas. Adoptar
   (c) de forma aislada sería una inversión desproporcionada frente al riesgo
   real de un proceso que protege datos de entornos no productivos, y
   retrasaría innecesariamente el cierre de las mejoras (a) y (b), que ya
   suponen una mejora sustancial y proporcionada.

Esta recomendación evita tanto la complacencia (dejar el pepper como está hoy)
como la sobre-ingeniería (exigir un KMS completo para un proceso de
desarrollo/preproducción), y da un camino de mejora incremental y verificable.

## 6. Fuentes y contexto

Este documento desarrolla la parte de gobernanza del hallazgo **A-04** de la
auditoría consolidada `00_AUDITORIA_CONSOLIDADA_FF1.md` ("Custodia del
secreto: hex en tabla ordinaria; sin wallet/HSM/auditoría; purga manual
(`p_export_mask` no la ejecuta); `DELETE` no prueba irrecuperabilidad;
`DUP_VAL_ON_INDEX` sin `ROLLBACK` explícito"), severidad Alta, clasificado en
dicha auditoría como hallazgo mixto de gobernanza y código. La parte de código
de A-04 (`ROLLBACK` explícito ante `DUP_VAL_ON_INDEX`, runbook que falle
cerrado si el pepper quedó sin purgar) está prevista en la Fase 0 del plan de
remediación de dicha auditoría; este documento cubre la parte de gobernanza
(custodia, separación de funciones, TTL, TDE, KMS) que la Fase 3 asigna a
Riesgo/DPO.
