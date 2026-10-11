#datamasking #oracle #auditoria #ff1 #seguridad #11g

**Auditoría del motor frente al estándar de un motor industrial**

Fecha: 2026-10-10. Alcance: los 16 paquetes (10 a 40), las 17 tablas, el instalador 99 y el desinstalador 98, los scripts de uso `dm_*`, las reglas de `03` y el directorio `tests/`. Método: lectura del código y barridos sistemáticos (excepciones, SQL dinámico, privilegios, algoritmos, nombres en duro, construcciones 12c). Contrasta además lo que las auditorías del 27/09 y del 10/10 dejaron como hallazgo con el código actual.

> [!note] Versión
> Válido para Oracle 11g R2 en adelante. Ninguna construcción de 12c o posterior detectada en el barrido. Esta auditoría es **estática**: no se compiló ni se ejecutó nada, y no sustituye una instalación limpia en una 11g real.

**1. Veredicto**

El motor es **sólido en lo que más se audita primero** (criptografía, trazabilidad, recuperación ante fallos, SQL dinámico) y tiene **brechas de gobierno** que un auditor de seguridad o de cumplimiento va a pedir antes de dar por cerrado un motor que toca datos de personas: no hay guarda de entorno, no hay auditoría nativa de Oracle sobre el propio motor, la versión instalada no queda registrada en la base y no hay verificación automática posterior al enmascarado. Ninguna de las cuatro exige rediseñar nada; son controles que se añaden alrededor del núcleo.

| Dimensión | Estado | Resumen |
|---|---|---|
| Criptografía | Cumple, con una observación | FF1 conforme a NIST SP 800-38G, mínimo de dominio aplicado, pepper con CSPRNG. Observación: SHA-1 en derivación de clave y HMAC |
| Seguridad del SQL dinámico | Cumple | Los identificadores pasan por `pkg_dm_sql_seguro`; sin puntos de inyección encontrados |
| Control de acceso y privilegios | Parcial | Rol y grants correctos, pero privilegios de sistema muy amplios y sin límite sobre qué esquema puede enmascarar un usuario del rol |
| Guarda de entorno (no producción) | No cumple | No existe ninguna comprobación |
| Auditoría nativa de Oracle | No cumple | El instalador no define políticas de auditoría sobre el motor |
| Trazabilidad propia | Cumple | Traza, errores, usuario de sesión, hash de reglas en el histórico |
| Registro de versión instalada | No cumple | La base no sabe qué versión del motor se instaló |
| Robustez y recuperación | Cumple, con 4 puntos a endurecer | Cancelación, reanudación, mutex, reintento acotado de chunks |
| Verificación posterior al enmascarado | No cumple | Las validaciones existentes son previas, no de resultado |
| Calidad de las reglas (descubrimiento) | Cumple en el caso medido | GPT3_OWN: lo esperado en Y, sin falsos positivos de cargos o texto libre |
| Portabilidad funcional (otros países) | Parcial | Las funciones de enmascarado son de formatos españoles |
| Mantenibilidad | Parcial | Tabla de identificadores duplicada en dos paquetes; listas de palabras en el código |
| Pruebas | Parcial | Vectores NIST existentes, fuera del instalador; ficheros con nombres antiguos |
| Rendimiento | Documentado, con pendientes | Ver `documentacion_performance_datamasking` |

**2. Lo que está bien resuelto (verificado en el código actual)**

- **FF1 conforme.** Diez rondas, PRF por CBC-MAC con AES-128, ajuste por dominio. El mínimo de dominio del NIST (radix elevado a la longitud mínima mayor o igual a un millón, es decir seis dígitos en radix 10) ya está aplicado en `12`; el hallazgo de nivel 2 de la auditoría del 27/09 quedó cerrado.
- **Sin fuga de identidad sin dígitos.** El caso de un documento sin dígitos o con uno solo ya produce un reemplazo sintético determinista, no el valor original.
- **Pepper.** 256 bits con `DBMS_CRYPTO.RANDOMBYTES`, uno por ejecución, sin materializarse en trazas, con guarda de estado antes de purgar (ORA-20099 y ORA-20100).
- **SQL dinámico.** El barrido localizó 7 `EXECUTE IMMEDIATE` que concatenan en la misma línea: 6 pasan por `func_dm_qname` y la séptima (`34`, línea 465) ejecuta el UPDATE base que construye el propio motor con identificadores ya entrecomillados. Las sentencias armadas en variables antes de ejecutarse no se rastrearon una a una en esta ronda; la auditoría del 27/09 ya las revisó en los paquetes de entonces y el uso de `pkg_dm_sql_seguro` es sistemático (188 líneas lo invocan entre los paquetes 20 a 40).
- **Recuperación.** Autocancelación que no toca sesiones vivas y activas, `proc_dm_refresca_sesion` autónoma, reintento acotado al rowid de los chunks fallidos, mutex por reclamo atómico, cancelación y reanudación probadas en DM_DUMMY.
- **Sin 12c.** Ninguna construcción posterior a 11g en los 16 paquetes.
- **Instalador y desinstalador simétricos**, con verificación de errores de compilación y de grants al final del 99.

**3. Hallazgos priorizados**

> [!warning] Alcance de la prioridad
> P0 significa que conviene resolverlo antes de congelar la versión y presentarla. No significa que el motor sea inseguro hoy: significa que un auditor lo va a pedir.

*P0. Antes de congelar*

| # | Hallazgo | Evidencia | Qué hacer |
|---|---|---|---|
| G1 | **No hay guarda de entorno.** Nada impide lanzar el enmascarado contra una base de producción | Búsqueda de nombre de base, instancia, servicio o parámetro de entorno en los 16 paquetes y en los drivers: sin resultados | Parámetro de configuración con la lista de bases permitidas y comprobación al arrancar el descubrimiento y el enmascarado, con ORA específico. Requiere tu decisión: qué identifica una base como no productiva |
| G2 | **Sin auditoría nativa de Oracle sobre el motor.** Nadie queda registrado por Oracle si lee `TDM_SECRETO`, ejecuta el paquete o cambia el rol | `99` no contiene `AUDIT` ni políticas; la trazabilidad es solo la propia del motor, que escribe el mismo esquema que se audita | Auditar con `AUDIT` por acceso sobre `TDM_SECRETO` y los cinco paquetes públicos (en 11g) o política unificada (12c en adelante), y auditar el `GRANT` del rol. Documentar dónde se guarda el rastro |
| G3 | **Privilegios amplios y alcance sin límite.** El dueño del motor tiene `SELECT ANY TABLE`, `UPDATE ANY TABLE`, `ALTER ANY TABLE`, `ALTER ANY TRIGGER`, `SELECT ANY DICTIONARY` y `CREATE JOB`; los paquetes corren con derechos del dueño | `99`, líneas 98 y 128 | No son evitables con este diseño, pero deben justificarse por escrito y compensarse: lista de esquemas autorizados como objetivo (parámetro) y revisión periódica de los miembros del rol |
| G4 | **La versión instalada no consta en la base.** No se puede demostrar qué código enmascaró unos datos | `tdm_parametro` solo tiene el grupo `EVENTO`; el comentario de la tabla dice que no se captura versión | Tabla o grupo de parámetros `VERSION` que el 99 rellene con la etiqueta de la versión y el SHA-256 del MANIFEST |
| G5 | **Sin verificación posterior al enmascarado.** `pkg_dm_mask_validacion` solo hace comprobaciones previas (base, concurrencia, reingreso) | `32`, tres procedimientos | Informe de resultado por ejecución: columnas aplicadas frente a previstas, filas con valor igual al original en una muestra, coherencia de claves ajenas |

*P1. Defendible ante auditoría*

| # | Hallazgo | Evidencia | Qué hacer |
|---|---|---|---|
| G6 | **SHA-1** en derivación de clave AES y en HMAC | `12`, líneas 246, 274 y 325 | Dejar la posición escrita: SHA-1 como PRF/HMAC y como derivación única de una clave de 128 bits no tiene ataque práctico conocido, pero NIST lo marca como obsoleto. Decidir si se migra a SHA-256 en una ronda propia con vectores, porque cambia longitudes y todo el dominio ya enmascarado |
| G7 | **Pepper en claro en una tabla** (`TDM_SECRETO`) mientras dura la ejecución | `30` | Aceptable por ser efímero y no estar en el rol. Documentar como riesgo aceptado, con TDE y protección de copias; custodia en wallet o HSM queda como mejora futura |
| G8 | **26 manejadores `WHEN OTHERS THEN NULL`.** Los revisé uno a uno: 22 son legítimos (último recurso dentro de un registrador de errores, limpieza de tarea, latido, contador informativo, traza de la traza). Cuatro merecen trazarse | `37`, líneas 935 y 1318: el manejador final no consigue actualizar el estado y el fallo queda mudo, con riesgo de dejar la solicitud en `EJECUTANDO`; `33`, líneas 775 a 781: la recompilación de objetos tras rehabilitar dependencias no avisa si algo queda inválido; `10`, línea 451: `proc_dm_refresca_sesion` | Registrar cada uno con la rutina autónoma de errores o, como mínimo, con `DBMS_OUTPUT`. Cambio pequeño y localizado |
| G9 | **Tabla de identificador a función duplicada** en dos paquetes, más un tercer mapa de longitudes mínimas | `12` líneas 1204 a 1225 (valor) y `35` líneas 218 a 224 (expresión SQL) y 305 a 311 | Una sola definición. Un identificador nuevo añadido solo en un sitio se enmascara distinto según la ruta |
| G10 | **Formatos específicos de España** en las funciones de enmascarado: DNI/NIE/CIF y IBAN `^ES[0-9]{22}$` | `12`, línea 1219 y funciones de documento | Para "todas las bases" de otros países hay que poder cambiar el formato por datos. Se trata en la sección 5 |
| G11 | **Pruebas desalineadas.** El runner fija `ALTER SESSION SET CURRENT_SCHEMA = ASTSYSADMIN` (no contempla ACC_ADMIN); `pkg_dm_test.sql` cita el nombre antiguo `pkg_dm_func_mask`; los vectores NIST viven fuera del instalador | `tests/00_run_tests_ff1.sql`, `tests/pkg_dm_test.sql` | Actualizar en la purga y ejecutar el runner como paso previo a cada versión congelada |
| G12 | **Sin ejecución en 11g real.** La portabilidad es solo estática | Todo el barrido | Instalación limpia y corrida de DM_DUMMY en una 11g, con log guardado |

*P2. Limpieza*

El resto ya está inventariado y no cambia el veredicto: scripts citados que no existen (`dm_liberar_ejecucion_activa`, `dm_pepper_purgar`, `dm_proteger_auditoria`), `func_dm_norm` sin llamadores en `pkg_dm_enmascarar`, las 17 rutinas públicas que solo usa su propio paquete, los comentarios de reversión y la lista de DBA repetida en tres puntos del 99 (ocho usuarios en los grants y en la verificación; **corrijo aquí el mapa de código en duro, que decía seis y ocho por error**).

**4. El flujo: primero el barrido, después las reglas, después el enmascarado**

Comprobé el flujo extremo a extremo contra el código.

| Etapa | Qué existe | Evaluación |
|---|---|---|
| Barrido | `pkg_dm_descubrimiento` puntúa cada columna por nombre, comentario, tabla y muestra de datos; deja el detalle por columna en `TDM_COLUMNA_HIST` (puntuación de cada señal, muestra, ratio, motivo de descarte, hash de reglas) | Evidencia de decisión completa y reproducible por hash de reglas |
| Revisión humana | La zona `REVISAR` (puntuación 45 a 64) no se enmascara y queda a la vista; `TDM_EXCEPCION_COL` con `FORCE` o `EXCLUDE` aplica la decisión explícita | Correcto: la decisión humana se registra y manda sobre la automática |
| Publicación | `pkg_dm_desc_catalogo` pasa el resultado a `TDM_COLUMNA_FINAL` y `TDM_DEPENDENCIA_FINAL`, y propaga dominios por clave ajena | Correcto |
| Enmascarado | `pkg_dm_enmascarar` lee el catálogo final y aplica la función por identificador | Correcto |

Dos huecos del flujo, ambos de **gobierno** y no de funcionamiento:

1. **No queda registro de quién aprobó el conjunto de reglas.** El histórico guarda el hash de reglas, pero no hay un acto de aprobación (quién, cuándo, qué versión del catálogo) entre el barrido y el enmascarado.
2. **El catálogo no se congela por ejecución.** El enmascarado lee el catálogo vivo; si alguien edita `TDM_COLUMNA_FINAL` o `TDM_EXCEPCION_COL` entre dos intentos, la reanudación aplica reglas distintas a las del primer intento. Ya estaba anotado como fuera de alcance; para auditoría se recomienda guardar en la solicitud un hash del catálogo aplicado y compararlo al reanudar.

> [!tip] Cómo se resuelven ambos con poco código
> Una columna de hash de catálogo en `TDM_MASK_SOLICITUD`, calculada al arrancar y comprobada en la reanudación, y una fila de aprobación (usuario de sesión y fecha) que el enmascarado exija. No modifican el descubrimiento ni el núcleo FF1.

**5. Código embebido en los paquetes: cuáles son y si quitarlo afecta**

Los 16 paquetes agrupados por función, y cuáles contienen código en duro que importa:

| Grupo | Paquete | Función | Código embebido relevante |
|---|---|---|---|
| Base | `pkg_dm_trazabilidad` (10) | Traza y errores | No |
| Base | `pkg_dm_sql_seguro` (11) | Entrecomillado y normalización | No |
| Base | `pkg_dm_mask_ff1` (12) | FF1 y funciones de enmascarado | **Sí**: formatos españoles y tabla de identificadores |
| Base | `pkg_dm_dominios` (13) | Propagación de dominios por clave ajena | Lista de identificadores de dominio |
| Descubrimiento | `pkg_dm_desc_puntuacion` (20) | Señales y puntuación | **Sí**: listas de palabras de contexto |
| Descubrimiento | `pkg_dm_desc_catalogo` (21) | Publicación al catálogo final | No |
| Descubrimiento | `pkg_dm_descubrimiento` (22) | Orquestador del barrido y compuertas | **Sí**: compuertas con puntuaciones |
| Enmascarado | `pkg_dm_pepper` (30) | Ciclo de vida del pepper | No |
| Enmascarado | `pkg_dm_mask_estado` (31) | Única puerta de escritura del estado | No |
| Enmascarado | `pkg_dm_mask_validacion` (32) | Validaciones previas | No |
| Enmascarado | `pkg_dm_mask_dependencias` (33) | Deshabilita y rehabilita restricciones y triggers | Valores por defecto de política |
| Enmascarado | `pkg_dm_mask_worker` (34) | Tareas paralelas y chunks | No |
| Enmascarado | `pkg_dm_mask_columna` (35) | Decide y aplica la función por columna | **Sí**: segundo mapa de identificadores y longitudes mínimas |
| Enmascarado | `pkg_dm_mask_sync` (36) | Coherencia entre tablas sin clave ajena | No |
| Enmascarado | `pkg_dm_enmascarar` (37) | Orquestador del enmascarado | No |
| Utilidad | `pkg_dm_export` (40) | Exportación con Data Pump | Detecta ASTSYSADMIN o ACC_ADMIN |

Para cada elemento, qué pasa si se quita o se mueve a datos:

| Elemento | Dónde | Si se mueve a datos | Veredicto |
|---|---|---|---|
| Alias de columnas del cliente (A1) | `20` | Ya movido a `tdm_regla` (tipo `ALIAS_NOMBRE`). Sin esa fila, las compuertas de nombre dejan de reconocer esas columnas | Hecho; necesita la fila en `03` |
| Contexto de persona y apellidos con inglés (A3, A4) | `20` | Mover a datos es seguro **si** la lista inicial reproduce la actual, porque la compuerta solo suma o resta según existan | Mover, con regresión de las 59 columnas |
| Filtro de columnas NUMBER (A7) | `22` | Seguro: solo amplía qué se evalúa | Hecho en ampliación; mover a datos es opcional |
| Regex técnica duplicada (A5) | `20` y `22` | **Afecta**: las dos no son iguales (`PK` y `FK` solo en una) y se usan con semánticas distintas | No unificar sin regresión |
| Compuertas con puntuación (A6) | `22` | **Afecta**: dependen del ratio de datos y del identificador a la vez; no son una regla de nombre | Mantener en el código |
| Tabla identificador a función | `12` y `35` | No se puede quitar: es el contrato entre las reglas y el enmascarado. Lo que sí procede es **unificar** los dos mapas | Mantener, una sola definición |
| Constantes de DNI, NIE y CIF | `12`, `20` | No se pueden quitar: son la norma | Mantener |
| Formatos de país (IBAN ES, DNI) | `12` | Quitarlos deja sin enmascarar ese dato en España; moverlos a datos exige una tabla de formatos por país y una función genérica | Mantener hoy; rediseño si se despliega fuera de España |
| Lista de DBA | `99` | Seguro de mover a un fichero o tabla de configuración | Mover (R-02 del propio script) |
| Detección de ASTSYSADMIN o ACC_ADMIN | `40`, `97`, `99` | Ya es una detección por datos del diccionario | Correcto; el runner de pruebas aún no la usa |

> [!note] Conclusión sobre el código embebido
> Hay tres clases. Lo que **no puede salir** (constantes de las normas y el contrato identificador a función). Lo que **se puede mover con regresión** (listas de contexto y de columnas). Lo que **parece movible pero no lo es** (A5 y A6, porque su semántica depende del dato). El criterio de seguridad del cambio es el mismo ya acordado: las 59 columnas y las 14 en Y de GPT3_OWN no deben cambiar de decisión.

**6. Orden de trabajo propuesto**

Cada paso es independiente. Ninguno toca el núcleo FF1.

| Paso | Contenido | Esfuerzo |
|---|---|---|
| 1 | G4 y G12: registro de versión en la base y corrida limpia en 11g real | Bajo / depende de acceso a una 11g |
| 2 | G8: trazar los cuatro manejadores mudos | Bajo |
| 3 | G9: unificar el mapa identificador a función | Medio; requiere regresión de enmascarado en DM_DUMMY |
| 4 | G1 y G3: parámetro de entornos y esquemas permitidos | Medio; necesita tu decisión |
| 5 | G2: políticas de auditoría en el instalador | Medio; coordinar con el equipo de seguridad |
| 6 | G5: informe de verificación posterior | Medio |
| 7 | Hash de catálogo por solicitud y registro de aprobación | Medio |
| 8 | G11 y purga | Bajo |
| 9 | G6: decisión sobre SHA-1 | Alto; ronda propia con vectores |

**7. Cómo presentarlo**

Dos matices de redacción que conviene mantener ante un auditor o ante el cliente:

- El motor está **basado en y validado contra FF1 (NIST SP 800-38G)**; no hay certificación CAVP o CMVP de la implementación, y no debe decirse "certificado NIST".
- Mientras exista el pepper, el cifrado es reversible; tras la purga, la reversión práctica solo es posible por la vía del export previo. Qué categoría jurídica le corresponde (seudonimización o anonimización) es una calificación para el delegado de protección de datos, no una afirmación técnica de este documento.

**8. Estado tras las correcciones de la misma noche**

| # | Hallazgo | Estado |
|---|---|---|
| G1 | Guarda de entorno | **Descartado por decision de Yair**: el operador sabe en que base trabaja. Queda como riesgo aceptado y documentado |
| G8 | Manejadores mudos | **Corregido**: `37` (dos) deja `FIN.ESTADO_FINAL_WARN` en la traza; `10` deja una migaja en `DBMS_OUTPUT`. En `33` la revision posterior mostro que no era un hueco (el delta de invalidos que se mide justo despues registra `POST_CHECK_INVALID`), asi que solo se documento por que es intencional. De los 26 manejadores, 3 se cambiaron y 1 se comento |
| G9 | Tabla identificador a funcion duplicada | **Corregido**: `pkg_dm_mask_ff1.func_dm_clase_identificador` es ahora la unica definicion; la usan `func_dm_generico` (12) y `func_dm_expr_gen_sql` y `func_dm_min_len_identificador` (35). Resultado identico para los siete identificadores de las reglas |
| G11 | Pruebas desalineadas | **Corregido** en la carpeta `tests/`: detectan ASTSYSADMIN o ACC_ADMIN, `pkg_dm_test.sql` sin `TABLESPACE` y con los nombres vigentes, el inventario PL/Scope compila los 16 paquetes y el runner verifica los 16 |
| G6 | SHA-1 en derivacion de clave y HMAC | **Corregido con compilacion condicional**: `12` usa dos primitivas (`func_dm_sha_hash`, `func_dm_sha_mac`); SHA-256 en 12c o superior, SHA-1 en 11g porque `DBMS_CRYPTO` de 11.2 no trae SHA-2. Las pruebas con vectores NIST no cambian (clave explicita). Cambian las salidas de dominios de texto y los ajustes por dominio; el invariante FK se mantiene dentro de una ejecucion. Reinstalar 98 + 99 |
| Codigo embebido | Listas de descubrimiento y lista de DBA | **Movido a datos** con la misma logica; ver `codigo_embeb_motor.md`, seccion 6. Lo que queda en codigo son formatos de España, algoritmos oficiales y umbrales |
| G12 | Corrida en 11g real | Lo hara Yair |

> [!warning] Alcance real de G6 en 11g
> En una base 11g el motor sigue usando SHA-1. Solo se endurece donde hay 12c o superior. Para defender el piso 11g ante un auditor: el pepper es aleatorio de 32 bytes, efimero y se purga al final; SHA-1 solo deriva una clave de 128 bits y actua como HMAC con clave secreta, usos en los que no existe ataque practico conocido.

> [!note] Un matiz de G9
> Antes, un identificador no canonico en `pkg_dm_mask_columna` (por ejemplo `IDENTIFICADOR_DOCUMENTO` en una excepcion FORCE) caia en el enmascarado de observaciones, mientras que `func_dm_generico` lo enrutaba como documento. Ahora los dos caminos lo tratan como documento. No afecta a ningun identificador de las reglas ni a los que usa SIGAD.

**Referencias**

**Notas relacionadas**

- [[analisis_brechas_industrializacion_2026-10-10]]
- [[auditoria_estricta_motor_completo_2026-09-27]]
- [[correcciones_auditoria_estricta_nivel1_2026-09-27]]
- [[revision_codex_estado_y_decisiones_2026-10-10]]
- [[mapa_hardcode_motor_2026-10-10]]
- [[catalogo_objetos_datamasking]]
- [[documentacion_performance_datamasking]]
