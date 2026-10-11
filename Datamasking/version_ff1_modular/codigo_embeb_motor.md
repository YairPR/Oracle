#datamasking #oracle #portabilidad #auditoria #11g

**Inventario del codigo embebido en el motor de enmascaramiento**

> [!note] Versión
> Valido para Oracle 11g R2 en adelante. Inventario estatico del 2026-10-10 sobre los archivos 01 a 40, 97, 98 y 99, con las lineas del codigo vigente tras la migracion a SHA-256 y las correcciones de esa noche. Las lineas se desplazan con cada edicion: el ancla estable es el nombre de la funcion. Sustituye en la parte de codigo al [[mapa_hardcode_motor_2026-10-10]], que sigue siendo el historial de los pasos ya ejecutados.

**1. Veredicto**

El motor esta listo para industrializarse en el sentido funcional: descubre, decide con reglas en datos, enmascara con FF1 y deja traza. Lo que queda escrito en duro no rompe nada, pero **ata el motor a España y a DGA** en cuatro sitios concretos:

| Tipo de atadura | Donde | Gravedad al migrar a otra empresa |
|---|---|---|
| Formatos de salida españoles (DNI/NIE/CIF, IBAN ES, telefono de 9 digitos, calles y ciudades españolas, dominios `correo.com`/`correo.es`) | `12` | Alta si la empresa no es española: el dato enmascarado seguiria teniendo forma española |
| Vocabulario de columnas en español dentro de la logica de descubrimiento | `20`, `22` | Media: ya hay equivalentes en ingles, pero la lista vive en codigo |
| Lista de personas autorizadas del instalador | `99` | Alta pero trivial: tres listas iguales en un script |
| Resultado de emergencia con texto de cliente (`Zaragoza`, `correo.com`) | `35` | Baja: solo se ejecuta si falla el enmascarado normal |

Lo que **no** es basura y debe quedarse: los algoritmos oficiales (letra del DNI, control del NIE y CIF, calculo del IBAN, FF1) y las constantes tecnicas del propio motor.

> [!warning] Qué se entiende por embebido
> Todo literal de negocio dentro de un paquete: listas de columnas o palabras, formatos de un pais, nombres de usuarios o esquemas, umbrales de decision y textos de salida. No cuentan los nombres de las tablas `tdm_*` ni los de los paquetes `pkg_dm_*`, que son el propio motor.

**2. Criterio de clasificacion**

| Clase | Significado | Que hacer al migrar |
|---|---|---|
| **MOVER** | Es configuracion de negocio. Debe vivir en `tdm_regla`, `tdm_parametro` o un fichero por organizacion | Mover a datos antes de publicar la version generica |
| **LOCALE** | Es un formato de un pais. Depende de la jurisdiccion | Encapsular en un unico bloque por pais y cambiarlo por el de la empresa nueva |
| **NORMA** | Algoritmo o formato definido por un estandar oficial | Dejar. Solo se sustituye si se añade otro pais |
| **TECNICO** | Constante del propio motor (limites, tamaños, claves de tabla) | Dejar |
| **DECISION** | Umbral o penalizacion que ata el motor al criterio de calidad | Dejar documentado; mover solo si se quiere ajustar por cliente |

**3. Inventario por paquete**

*Paquete 12 `pkg_dm_mask_ff1` (formatos de salida y rutas)*

| # | Lineas | Funcion | Que esta en duro | Clase | Retirar afecta a |
|---|---|---|---|---|---|
| 12-1 | 676 a 684 | `func_dm_direccion` | Tipos de via `Calle Avenida Plaza Camino`, nombres de calle y ciudades `Zaragoza Bilbao Malaga Valladolid` | LOCALE | Solo el aspecto del dato enmascarado |
| 12-2 | 701 | `func_dm_obs` | Texto fijo `***OBSERVACION ENMASCARADA***` | LOCALE (idioma) | Aspecto del dato |
| 12-3 | 722 | `func_dm_telefono` | Prefijo `6789` y 9 digitos (movil y fijo de España) | LOCALE | Longitud y forma del telefono |
| 12-4 | 752 | `func_dm_email` | Dominios `correo.com` y `correo.es` | LOCALE | Aspecto del correo |
| 12-5 | 774 | `func_dm_nif` (letra) | `TRWAGMYFPDXBNJZSQVHLCKE` | NORMA | Validez del DNI generado |
| 12-6 | 793 | `func_dm_nif` (NIE) | `JABCDEFGHI` | NORMA | Validez del NIE |
| 12-7 | 838 | `func_dm_nif` (NIE) | Prefijo `XYZ` | NORMA | Formato del NIE |
| 12-8 | 944 | `func_dm_nif` (CIF) | `ABCDEFGHJKLMNPQRSUVW` | NORMA | Reconocimiento del CIF |
| 12-9 | 951, 957, 963 | `func_dm_nif` | Regex `^[0-9]{8}[A-Z]$`, `^[XYZ][0-9]{7}[A-Z]$`, CIF `^[0-9]{7}[A-Z0-9]$` | NORMA | Rutas DNI, NIE y CIF |
| 12-10 | 873 | `func_dm_especial_doc_keep_ends` | Alfabeto `A-Z0-9` | TECNICO | Salida alfanumerica |
| 12-11 | 1028, 1065, 1069, 1075, 1224, 1319 | `func_dm_iban`, `func_dm_cuenta`, rutas IBAN | Pais `ES`, `142800` (ES en numerico), regex `^ES[0-9]{22}$` | LOCALE | Solo IBAN españoles; otros paises caen en `func_dm_cuenta` |
| 12-12 | 1246 a 1283 | `func_dm_clase_identificador` | Los 15 identificadores `IDENTIFICADOR_*` y las palabras clave `NOMBRE PERSON APELL DIREC DOMIC VIA EMAIL MAIL TELEF MOVIL NIF NIE DOC IDENT IBAN CUENTA BANC` | NORMA del motor (contrato) | Rompe el enrutado de todo el enmascarado |
| 12-13 | 180 | cabecera | `c_max_txt = 1000` | TECNICO | Truncado de texto |

*Paquete 13 `pkg_dm_dominios`*

| # | Lineas | Funcion | Que esta en duro | Clase | Retirar afecta a |
|---|---|---|---|---|---|
| 13-1 | 102 a 112 | `f_rank_ident` | Prioridad por identificador: IDENTIDAD y DOCUMENTO 10, IBAN y BANCARIO 20, PERSONAL 50, resto 90 | DECISION | Que identificador manda cuando se une un dominio por FK |

*Paquete 20 `pkg_dm_desc_puntuacion` (vocabulario del descubrimiento)*

| # | Lineas | Funcion | Que esta en duro | Clase | Retirar afecta a |
|---|---|---|---|---|---|
| 20-1 | 194 a 201 | `func_dm_es_nombre_candidato` | Regex `NOMBRE NOMBRE_ALT NOMBRE_USUARIO US_NOMBRE NOM APELLIDOS_NOMBRE NOMBRE_COMPLETO` mas los alias leidos de `tdm_regla` | MOVER | Compuertas de nombre del descubrimiento |
| 20-2 | 213 a 219 | `func_dm_es_nombre_generico` | Solo la columna `NAME` | MOVER | Compuerta de dos niveles de `NAME` |
| 20-3 | 242, 250, 256 | `func_dm_es_dni_nie_valido` | Tabla de letras y regex de DNI y NIE | NORMA | Validacion de datos en descubrimiento |
| 20-4 | 517 a 520 | `func_dm_score_texto` | Regex de campos tecnicos `ID COD CODIGO TIPO FLAG ESTADO IND SEQ ORDEN VERSION HASH TOKEN UUID PK FK` y excepciones `NIF NIE DNI DOC DOCUMENTO NDOCUMENTO NUM_DOCUMENTO NRO_DOCUMENTO IBAN CUENTA EMAIL MAIL TFNO TELEF MOVIL DOMICILIO DIRECCION OBS NOTA DESCRIPCION CONSULTA RESPUESTA` | MOVER | Falsos positivos en columnas de codigo |
| 20-5 | 532 | `func_dm_score_texto` (PERSONAL) | Regex `NOMBRE APE1 APE2 APELLIDO... TITULAR SOLICITANTE INTERESAD BENEFICIARI DECLARANTE REPRESENTANTE...` | MOVER | Que columnas pueden ser IDENTIFICADOR_PERSONAL |
| 20-6 | 953 a 996 | `func_dm_tiene_ctx_persona` | Unos 40 nombres y patrones `LIKE`: `APE1 NIF DNI EMAIL TFNO TELEF MOVIL DOMICILIO SURNAME PHONE ADDRESS...` | MOVER | Contexto de persona para la compuerta de nombres |
| 20-7 | 1032 a 1046 | `func_dm_tiene_apellidos` | 11 nombres y patrones de apellido en español e ingles | MOVER | Compuerta de apellidos por tabla |

*Paquete 22 `pkg_dm_descubrimiento`*

| # | Lineas | Funcion | Que esta en duro | Clase | Retirar afecta a |
|---|---|---|---|---|---|
| 22-1 | 990 | `proc_dm_procesa_desc` | Regex tecnica `ID COD CODIGO TIPO FLAG ESTADO IND SEQ ORDEN VERSION HASH TOKEN UUID` (sin `PK FK`) | MOVER (duplicada con 20-4) | Evaluacion de patrones en columnas tecnicas |
| 22-2 | 1108 a 1111 | idem | Regex `TIPO COD CODIGO CLASE ENUM FLAG ESTADO` junto a `NIF NIE DNI CIF` y penalizacion de 250 puntos | DECISION | Falsos positivos de campos de tipo de documento |
| 22-3 | 1116 a 1118 | idem | Regex `CODIGO_VIA NUMERO_VIA CODIGO NUMERO` y penalizacion de 220 puntos | DECISION | Falsos positivos de numeros de via |
| 22-4 | 1132, 1171 | idem | Penalizacion de 220 puntos en compuertas de nombre | DECISION | Nombres sin semantica |
| 22-5 | 1165, 1167, 1168 | idem | Umbrales de `NAME`: ratio de 0.70 con apellido, 0.90 sin apellido, minimo 10 filas | DECISION | Compuerta de `NAME` |
| 22-6 | 1179, 1187, 1190, 1192, 1227, 1235, 1249, 1266 | idem | Cortes 85 CONFIRMADO, 65 PROBABLE, 55 de rescate, y 70 o 90 de puntuacion de nombre para telefono y otros | DECISION | Estado final de cada columna |
| 22-7 | 1478 a 1480 | `proc_dm_procesa_tabla` | Columnas **NUMBER** que se evaluan: `CUENTA IBAN CCC SWIFT NIF NIE DNI DOC DOCUMENTO TELEFONO TFNO MOVIL TEL CP CODIGO_POSTAL PHONE TELEPHONE MOBILE CELL CELLPHONE IDNUMBER ID_NUMBER` | MOVER | **Falso negativo silencioso** si falta un nombre: la columna ni se evalua |
| 22-8 | 824 | seleccion de tablas | `tb.temporary = 'N'` | TECNICO | Tablas temporales |

*Paquete 35 `pkg_dm_mask_columna`*

| # | Lineas | Funcion | Que esta en duro | Clase | Retirar afecta a |
|---|---|---|---|---|---|
| 35-1 | 225 a 240 | `func_dm_expr_gen_sql` | Expresion `^ES[0-9]{22}$` y mapa clase a funcion | LOCALE y contrato | Ruta bancaria |
| 35-2 | 310 a 320 | `func_dm_min_len_identificador` | Longitudes minimas por clase: IDENTIDAD 8, TELEFONO 7, EMAIL 5, BANCARIO 10, NOMBRE 2, DIRECCION 3 | DECISION | Que columnas se saltan por ser demasiado cortas |
| 35-3 | 657 a 670 | segundo fallback | `Calle Ficticia N`, `, Zaragoza`, `usuario...@correo.com`, prefijo `6` en telefono, alfabeto de `TRANSLATE` | LOCALE (texto de cliente) | Solo si fallan FF1 y el primer fallback |

*Otros paquetes y scripts*

| # | Lineas | Donde | Que esta en duro | Clase | Retirar afecta a |
|---|---|---|---|---|---|
| 30-1 | 49, 118 | `30` pepper | Clave `PEPPER_MASK:` en `tdm_secreto` | TECNICO | Alta y purga del pepper |
| 34-1 | 392, 405, 953, 965 | `34` worker | Nombre de la clase de job `JC_DATAMASKING` (opcional, afinidad RAC) | TECNICO | Solo afinidad de nodos |
| 34-2 | 365, 367 | `34` worker | Paralelismo 1 o 2 segun riesgo de trigger | DECISION | Rendimiento |
| 37-1 | 387, 419, 427, 716, 985, 1064, 1176 | `37` | `p_commit_lote DEFAULT 1000` | TECNICO | Frecuencia de commit |
| 10-1 | 125, 568 | `10` | `p_minutos_inactividad DEFAULT 15` | TECNICO | Deteccion de ejecuciones colgadas |
| 40-1 | 11 a 19 | `40` export | Esquemas `ASTSYSADMIN` y `ACC_ADMIN` | MOVER | Deteccion del esquema del motor |
| 99-1 | 73 a 79 | `99` instalador | Mismos dos esquemas | MOVER | Instalacion |
| 99-2 | 415 a 422 | `99` instalador | `grant ROL_DATAMASKING` a ocho usuarios nominales | MOVER | Quien puede ejecutar el motor |
| 99-3 | 546 a 553 y 567 a 574 | `99` verificacion | La misma lista de ocho usuarios, repetida dos veces | MOVER | Verificacion posterior al grant |
| 99-4 | 363 a 367 | `99` | Cinco paquetes fachada con `execute` al rol | NORMA del motor | Superficie publica |

*Configuracion de cliente en su sitio correcto (no es basura, solo se sustituye)*

| Donde | Contenido |
|---|---|
| `03` bloque B | Alias `NOMSO NOMSOL NOMARR NOMUEC ACU_NOMBRE USU_LT_USU UNIFAM_APENU`, convenciones `PNCSS ICSS PCSS SIGAD` |
| `97_configurar_excepciones.sql` | FORCE y EXCLUDE de `PNCSS_OWN` y `DM_PCSS_OWN` |
| `SIGAD/config_sigad.sql` | Reglas, relaciones y excepciones de SIGAD |

**4. Resumen cuantitativo**

| Clase | Puntos | Comentario |
|---|---|---|
| MOVER | 20-1, 20-2, 20-4, 20-5, 20-6, 20-7, 22-1, 22-7, 40-1, 99-1, 99-2, 99-3 | Es lo que hay que evaluar para dejar el motor sin ataduras de cliente |
| LOCALE | 12-1, 12-2, 12-3, 12-4, 12-11, 35-1, 35-3 | Es lo que hay que cambiar por pais, no por cliente |
| NORMA | 12-5 a 12-9, 12-12, 20-3, 99-4 | No se toca |
| DECISION | 13-1, 22-2 a 22-6, 35-2, 34-2 | Criterio del motor, documentado |
| TECNICO | 12-10, 12-13, 22-8, 30-1, 34-1, 37-1, 10-1 | No se toca |

**5. Como retirarlo sin dejar basura (para evaluar despues)**

> [!warning] Orden obligatorio
> Cada paso se valida con la regresion de las columnas ya descubiertas (las 59 de GPT3_OWN y las del esquema anterior): ninguna decision debe cambiar. El INSERT de `03` sigue siendo solo INSERT.

| Paso | Que hacer | Riesgo |
|---|---|---|
| 1 | Bloque unico de **perfil de pais** en `12` (12-1 a 12-4, 12-11) que agrupe todo lo LOCALE en una sola funcion o tabla `tdm_parametro`. El motor no cambia; solo se sabe donde tocar | Bajo |
| 2 | 99-2 y 99-3: una sola lista de usuarios autorizados (tabla o fichero de organizacion) leida por el grant y por las dos verificaciones | Bajo |
| 3 | 40-1 y 99-1: esquema del motor como parametro del instalador en vez de la pareja fija | Bajo |
| 4 | 22-7: leer de `tdm_regla` la lista de columnas NUMBER evaluadas (tipo nuevo) | Medio: es el unico punto con falso negativo posible |
| 5 | 20-4, 22-1 y 20-5: una sola regex tecnica en datos, resolviendo la diferencia `PK FK` con regresion | Medio: cambia decisiones si se hace sin regresion |
| 6 | 20-6, 20-7, 20-1, 20-2: listas de contexto, apellidos y nombres como reglas de tipo nuevo | Medio |
| 7 | 35-3: sustituir el texto de cliente del segundo fallback por la salida de las funciones del paquete `12` | Bajo |

> [!note] Lo que se decidio dejar
> Codigo que no se puede eliminar porque cumple un papel en la logica queda en duro y documentado aqui. Los puntos A5 y A6 del mapa anterior (reglas tecnicas dependientes del dato) siguen en esa categoria: se mantienen como DECISION porque la condicion de la penalizacion incluye el ratio de datos y no se puede expresar como regla de nombre.

**6. Estado tras la migracion a reglas (2026-10-10, noche)**

Se movieron a `tdm_regla` (tipos que no puntuan, sembrados en `03`) las listas de la clase MOVER con equivalencia comprobable. La logica es la misma: solo cambia donde vive la lista.

| Punto | Estado | Detalle |
|---|---|---|
| 22-7 columnas NUMBER | Hecho | Tipo `NUMBER_ADMITIDO`; `22` lee la lista con `func_dm_lista_regla` |
| 20-1 nombres candidatos | Hecho | Tipo `NOMBRE_CANDIDATO` (mas los `ALIAS_NOMBRE` que ya existian) |
| 20-2 columna `NAME` | Hecho | Tipo `NOMBRE_GENERICO` |
| 20-5 compuerta de IDENTIFICADOR_PERSONAL | Hecho | Tipo `NOMBRE_PERSONAL` |
| 20-6 contexto de persona | Hecho | Tipo `CTX_PERSONA`, tres expresiones (exacto, sufijo, prefijo) |
| 20-7 apellidos | Hecho | Tipo `CTX_APELLIDO`, tres expresiones |
| 99-2 y 99-3 usuarios del rol | Hecho | Una sola lista en la variable `g_dba_csv` de `99`; el grant y la verificacion la leen |
| 20-4 y 22-1 regex tecnica | No se hizo | Las dos listas no son equivalentes (`PK`/`FK` solo en una); unificarlas cambia decisiones |
| 40-1 y 99-1 esquema del motor | No se hizo | Es la deteccion `ASTSYSADMIN`/`ACC_ADMIN` propia del entorno; se queda documentada |
| 22-2 a 22-6, 35-2 | Se quedan | Umbrales y penalizaciones que dependen del dato (clase DECISION) |
| Clase LOCALE y NORMA | Se quedan | Formatos de salida de España y algoritmos oficiales |

> [!warning] Correccion incluida
> En la lista anterior de columnas NUMBER, un salto de linea dentro de la cadena hacia que `PHONE` exigiera espacios en el nombre y no coincidiera nunca. Con la regla nueva `PHONE`, `TELEPHONE`, `MOBILE`, `CELL`, `CELLPHONE`, `IDNUMBER` e `ID_NUMBER` si admiten columnas NUMBER. `CELULAR` sigue sin admitirse, igual que antes; añadirla es una fila.

> [!note] Como se cambia ahora
> Para añadir un nombre basta una fila `INSERT` en `tdm_regla` con puntuacion 0 y el tipo correspondiente. Las listas se leen una vez por sesion: el cambio se ve al abrir una sesion nueva.

**Verificacion sin Oracle.** Se compararon los codigos anteriores con las reglas nuevas con un script que lee los archivos reales: 516 nombres de columna sinteticos para cada una de las dos funciones de contexto, sin diferencias; en DM_DUMMY (27 tablas, 185 columnas) el recuento de contexto por tabla y las 4 columnas NUMBER admitidas (`DOC_ID`, `CUENTA_ID` x2, `DOCUMENTO_ID`) salen identicos. Falta correr en Oracle real: reinstalar con 98 y 99 y repetir el descubrimiento de DM_DUMMY y GPT3_OWN.

**Referencias**

**Notas relacionadas**

- [[mapa_hardcode_motor_2026-10-10]]
- [[auditoria_industrial_motor_2026-10-10]]
- [[analisis_brechas_industrializacion_2026-10-10]]
- [[revision_portabilidad_reglas_negocio_2026-09-28]]
- [[catalogo_objetos_datamasking]]
