Rem pkg_dm_descubrimiento.sql
Rem
Rem    NOMBRE
Rem      pkg_dm_descubrimiento.sql - Motor de Descubrimiento de Datos Sensibles
Rem
Rem    DESCRIPCIÓN
Rem      Este paquete implementa un motor de descubrimiento y clasificación
Rem      de datos sensibles en bases de datos Oracle.
Rem      Permite identificar información sensible mediante reglas semánticas,
Rem      validación de patrones, contexto de datos y análisis de contenido.
Rem      Uilizando un enfoque basado en puntuación (scoring), combinando:
Rem
Rem        - Reglas por nombre de columna (tdm_regla)
Rem        - Contexto de tabla
Rem        - Comentarios de columna
Rem        - Validación de patrones de datos
Rem        - Análisis semántico
Rem
Rem      El motor soporta:
Rem        - Clasificación determinista
Rem        - Reducción de falsos positivos
Rem        - Excepciones manuales (FORCE / EXCLUDE)
Rem        - Integración con procesos de enmascaramiento
Rem
Rem    NOTAS
Rem      - Diseñado para Oracle 11g en adelante
Rem      - Uso de SQL dinámico con muestreo
Rem      - Optimizado para esquemas grandes
Rem      - Soporte de validación de DNI/NIE
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    07/15/25 - Versión inicial del motor de descubrimiento
Rem                           Basado en reglas simples por nombre de columna

Rem    epurisaca    08/10/25 - Se añade scoring por TABLE_NAME y COLUMN_COMMENT
Rem                           Introducción de modelo de puntuación ponderado

Rem    epurisaca    09/02/25 - Implementación de DATA_PATTERN con regexp_like
Rem                           Introducción de muestreo de datos (rownum)

Rem    epurisaca    09/18/25 - Integración de validación real de DNI/NIE
Rem                           Mejora en detección de identificadores personales

Rem    epurisaca    10/05/25 - Creación de tdm_regla como motor dinámico
Rem                           Permite modificar reglas sin cambiar código

Rem    epurisaca    10/22/25 - Introducción de prioridades y umbrales de confianza
Rem                           Mejora en normalización de scoring

Rem    epurisaca    11/12/25 - Se añade validación semántica de nombres humanos
Rem                           Reducción de falsos positivos en texto genérico

Rem    epurisaca    12/03/25 - Introducción de contexto de tabla (PERSONA, TITULAR)
Rem                           Mejora en clasificación contextual

Rem    epurisaca    12/20/25 - Exclusión de columnas técnicas (ID, COD, FLAG, etc.)
Rem                           Mejora en limpieza de resultados

Rem    epurisaca    01/08/26 - Creación de tdm_excepcion_col
Rem                           Soporte para reglas manuales FORCE / EXCLUDE

Rem    epurisaca    01/25/26 - Alineación con enmascaramiento determinista
Rem                           Consistencia entre tablas relacionadas

Rem    epurisaca    02/05/26 - Optimización de rendimiento en muestreo
Rem                           Mejora en ejecución sobre grandes volúmenes

Rem    epurisaca    02/18/26 - Penalización por falta de contexto de persona
Rem                           Reducción de falsos positivos en direcciones y bancos

Rem    epurisaca    02/26/26 - Introducción de ratio semántico de nombres
Rem                           Validación de contenido tipo nombre humano

Rem    epurisaca    03/05/26 - Integración con flujo de enmascaramiento
Rem                           Similar a Oracle Cloud Control

Rem    epurisaca    03/10/26 - Ajustes en reglas de COLUMN_NAME
Rem                           Mejora en detección de nomenclaturas legacy

Rem    epurisaca    03/14/26 - Rediseño versión 7 del motor
Rem                           Refactorización del flujo de scoring

Rem    epurisaca    03/17/26 - Identificación de falsos positivos por uso de NOM
Rem                           Ejemplo: NOMINA, NOMINA_PER mal clasificados

Rem    epurisaca    03/18/26 - Refinamiento de reglas IDENTIFICADOR_PERSONAL
Rem                           - Eliminación de NOM como indicador fuerte
Rem                           - Inclusión de reglas negativas para NOMINA
Rem                           - Ajuste de compuerta en func_dm_score_patron

Rem    epurisaca    03/18/26 - Mejora en control de falsos positivos
Rem                           Balance entre reglas y lógica de negocio

Rem    epurisaca    03/21/26 - Control de ejecución maestra base
Rem                           Se bloquea nueva ejecución con FORZAR_FULL = 'N'
Rem                           si ya existe una ejecución previa base del esquema
Rem                           Para reejecución se requiere FORZAR_FULL = 'Y'

Rem    epurisaca    03/25/26 - Versión estable v7
Rem                           Motor alineado a producción con mayor precisión
Rem    epurisaca    04/20/26 - Ajuste de política operativa de dependencias
Rem                           Sync de tdm_dependencia_final alineado con PRE/POST
Rem                           Preserva estado real ENABLED/DISABLED en triggers y constraints
Rem                           FK/CONSTRAINT y TRIGGER normales con política automática
Rem                           Objetos Oracle Text DR$ se mantienen como revisión especial
Rem
Rem    epurisaca    09/18/26 - Descubrimiento selectivo: proc_dm_descubrimiento_set y
Rem                            proc_dm_descubrimiento_core permiten relanzar el
Rem                            descubrimiento sobre un subconjunto de tablas/columnas
Rem                            (dm_descubre_set.sql) sin reprocesar todo el esquema
Rem
Rem    epurisaca    09/22/26 - Se añade guarda ROWNUM=1 en proc_dm_aplica_excepcion
Rem                            para evitar fila múltiple ante excepciones duplicadas
Rem                            activas sobre la misma owner/tabla/columna
Rem
Rem    epurisaca    09/26/26 - Fix ranking no determinista en proc_dm_procesa_desc:
Rem                            - Declare: se agrega l_best_patron (nueva variable,
Rem                              linea ~1493) para desempate por evidencia de datos.
Rem                            - Reset por columna (linea ~1610): l_best_score pasa
Rem                              de -99999 a 0 y se resetea l_best_patron a 0. Antes,
Rem                              con -99999, el primer identificador devuelto por el
Rem                              cursor de linea ~1618 podia quedar como l_best_id
Rem                              con score_total = 0 (sin evidencia real en nombre,
Rem                              comentario, tabla ni patron), igual que ya evitaba
Rem                              func_dm_identificador_base (linea 505-506) al
Rem                              arrancar en 0. Caso real detectado: DM_DUMMY.
Rem                              TBL_DOCUMENTO_VOL.OBSERVACIONES quedaba clasificado
Rem                              como IDENTIFICADOR_DIRECCION con las 4 sub-
Rem                              puntuaciones en cero, en vez de IDENTIFICADOR_OBS.
Rem                            - Cursor de linea ~1618 (for idn in select distinct
Rem                              identificador from tdm_regla): se agrega ORDER BY
Rem                              identificador para que el orden de evaluacion sea
Rem                              estable y reproducible entre ejecuciones (antes
Rem                              dependia del plan interno de un SELECT DISTINCT
Rem                              sin ORDER BY).
Rem                            - Comparacion de ganador (linea ~1662): se agrega
Rem                              desempate generico por l_score_patron (evidencia
Rem                              observada en la muestra real de datos) cuando dos
Rem                              identificadores empatan en score_total. No hay
Rem                              ningun identificador hardcodeado por nombre; el
Rem                              criterio aplica igual a cualquier fila activa hoy
Rem                              o dada de alta despues en TDM_REGLA.
Rem                            - func_dm_score_patron (linea 557): se agrega el
Rem                              parametro p_ejecucion_id y, en su manejador WHEN
Rem                              OTHERS (linea ~672), una llamada a
Rem                              proc_dm_log_error antes de devolver 0. Antes el
Rem                              handler devolvia 0 en silencio ante CUALQUIER
Rem                              error interno (dynamic SQL, regexp_like, etc.),
Rem                              sin dejar rastro en TDM_EJECUCION_ERROR - dificulta
Rem                              diagnosticar casos futuros como el de
Rem                              TBL_DOCUMENTO_VOL.OBSERVACIONES. Se actualizan los
Rem                              dos call-sites (linea ~1633 y ~1682) para pasar
Rem                              p_ejecucion_id, ya disponible en el scope de
Rem                              proc_dm_procesa_desc (parametro de linea 1483).
Rem
Rem    epurisaca    09/26/26 - Se elimina el filtro por NOMBRE de tabla (TMP|TEMP|LOG|
Rem                            TRAZA|ERROR|PARAM|CAT|CONFIG|LOOKUP|LOV|BATCH|JOB|MV_) que
Rem                            marcaba OMITIDO/TABLA_TECNICA_SISTEMA. Dejaba sin descubrir
Rem                            tablas con datos personales (p.ej. logs de auditoria con NIF
Rem                            de usuario, TMP_* de SRI). Ahora toda tabla con filas se
Rem                            evalua y son las reglas (TDM_REGLA) las que deciden por
Rem                            columna; las tablas antes omitidas por nombre pasan a
Rem                            PENDIENTE en la siguiente ejecucion.
Rem                            Desempate por patron: exige score_total > 0.
Rem
Rem    epurisaca    09/26/26 - El dato manda sobre el nombre (sin hardcode por columna):
Rem                            1) func_dm_score_patron devuelve p_contra_out = 1 cuando el
Rem                               identificador tiene reglas DATA_PATTERN de formato exigente
Rem                               (confianza_min informado y puntuacion > 0), la muestra tiene
Rem                               >= 10 filas y ninguna cumple ninguno. En ese caso la columna
Rem                               queda como maximo en REVISAR (DATO_NO_COINCIDE_CON_FORMATO):
Rem                               p.ej. CORREO_INTERNO sin '@', TELEFONO_FICTICIO sin digitos.
Rem                            2) La compuerta por nombre ID/COD/... de func_dm_score_patron
Rem                               ya no se aplica a IDENTIDAD, y la penalizacion
Rem                               CAMPO_TECNICO_IDENTIDAD solo aplica si ratio de datos < 0.5:
Rem                               una columna con nombre neutro (COD_..., REFERENCIA_...) que
Rem                               contiene DNI/NIE con digito de control valido se detecta.
Rem
Rem    epurisaca    09/27/26 - proc_dm_refresca_sesion, func_dm_sesion_viva y
Rem                            proc_dm_autocancel_huerfanas se MUEVEN a
Rem                            pkg_dm_trazabilidad (03b): eran privadas aqui, y
Rem                            pkg_dm_enmascarar (05) no tenia autocancelacion
Rem                            de huerfanas propia (una ejecución de ENMASCARAMIENTO
Rem                            caida se quedaba en EJECUTANDO indefinidamente).
Rem                            Este archivo ahora llama a las tres via
Rem                            pkg_dm_trazabilidad.<nombre>; sin cambio de
Rem                            comportamiento para DESCUBRIMIENTO.
Rem
Rem    epurisaca    09/27/26 - Incidente SRI2006 (descubrimiento,ORA-00001/ORA-22835 en cascada): 1) causa raiz del
Rem                            ORA-22835: func_dm_score_patron aplicaba to_char()
Rem                            directo sobre el VALOR de la columna muestreada para
Rem                            regexp_like/comparacion; con contenido real >4000
Rem                            caracteres (CLOB/VARCHAR2 extendido) revienta con
Rem                            "buffer demasiado pequeno". Se sustituye por
Rem                            dbms_lob.substr(to_clob(<col>),4000,1), que nunca
Rem                            desborda y da el mismo resultado para valores que ya
Rem                            cabian en 4000. 2) causa raiz del ORA-00001: existian
Rem                            DOS generadores de error_id independientes sobre la
Rem                            MISMA tdm_ejecucion_error -- este paquete usaba
Rem                            seq_dm_ejecucion_err.nextval, pkg_dm_trazabilidad
Rem                            (usado por enmascaramiento desde el 16/09) usa
Rem                            MAX(error_id)+1 sin tocar la secuencia, dejandola
Rem                            desincronizada del maximo real de la tabla. Se
Rem                            unifica proc_dm_log_error aqui al mismo metodo
Rem                            MAX(error_id)+1; seq_dm_ejecucion_err queda sin uso.
Rem                            3) proc_dm_log_error (la red de seguridad de
Rem                            auditoria) no tenia manejador de excepciones propio:
Rem                            si el INSERT de log fallaba, la excepcion escalaba
Rem                            sin control un error de UNA columna a un aborto total
Rem                            de la ejecucion (PROCESA_COLUMNA -> PROCESO_GENERAL).
Rem                            Ahora es best-effort: ante fallo hace ROLLBACK de su
Rem                            propia transaccion autonoma y nunca propaga.
Rem
Rem    epurisaca    09/28/26 - progreso_pct con base mezclada dentro de proc_dm_procesa_desc:
Rem                            la rama que omite una tabla sin filas (TABLA_SIN_FILAS)
Rem                            recalculaba progreso_pct como tablas_proc/tablas_total*100,
Rem                            mientras el resto del procedimiento (tras cada columna
Rem                            procesada) lo hace como columnas_proc/columnas_total*100.
Rem                            Como tablas_total suele ser mucho menor que columnas_total,
Rem                            alternar de formula entre una tabla y la siguiente producia
Rem                            retrocesos visibles del % (reportado: 54% -> 6%) sin que la
Rem                            ejecucion hubiera retrocedido. Unificado a una sola base
Rem                            (columnas) en todo el procedimiento.
Rem
Rem    epurisaca    10/02/26 - "El dato manda sobre el nombre" (09/26/26) se
Rem                            generaliza a IDENTIFICADOR_PERSONAL (hallazgo #6 de
Rem                            la auditoria del 27/09/26, confirmado con caso real:
Rem                            EXPEDIENTES.PROMOTOR en DATAM_ARCA_OWN, columna con
Rem                            nombre de persona real pero SCORE_NOMBRE=0 porque
Rem                            "PROMOTOR" no esta en ninguna lista de alias de
Rem                            nombre/apellido). Hasta ahora la compuerta de
Rem                            func_dm_score_patron para IDENTIFICADOR_PERSONAL
Rem                            devolvia 0 de forma incondicional si el NOMBRE de
Rem                            columna no estaba en la lista blanca -- a
Rem                            diferencia de IDENTIFICADOR_IDENTIDAD, que desde el
Rem                            09/26/26 ya deja que el digito de control del
Rem                            DNI/NIE decida sin mirar el nombre de columna.
Rem                            Nuevas piezas (ambas privadas, solo usadas aqui):
Rem                              func_dm_es_nombre_persona_valido(p_valor) -- analoga
Rem                              a func_dm_es_dni_nie_valido pero para forma lexica
Rem                              "Nombre Apellido(s)" (2-4 tokens capitalizados, sin
Rem                              digitos, sin palabras-clave de entidad/organismo
Rem                              en espanol -- generico, no hardcode de negocio).
Rem                              func_dm_contenido_parece_persona(owner,tabla,col) --
Rem                              muestra 10 filas (coste acotado a proposito, es un
Rem                              pre-chequeo antes de un gate, no el scoring en si)
Rem                              y decide si el contenido real tiene forma de
Rem                              nombre de persona en >=70% de la muestra (minimo 5
Rem                              filas) antes de anular el descarte por nombre.
Rem                            Si el contenido NO tiene esa forma (el caso dual real
Rem                            de PROMOTOR: en otras tablas es el nombre de un
Rem                            organismo/entidad), el gate original se mantiene sin
Rem                            cambios y la columna sigue sin confirmar
Rem                            automaticamente -- correcto, porque ahi el dato
Rem                            tampoco es personal. Cuando el contenido SI pasa el
Rem                            pre-chequeo, func_dm_score_patron deja de descartar
Rem                            por nombre y evalua la nueva regla DATA_PATTERN
Rem                            sembrada en 03_dm_descubrimiento_carga_reglas.sql
Rem                            (expresion sentinela '__CONTENIDO_NOMBRE_PERSONA__',
Rem                            interceptada igual que la regla DNI/NIE: usa la
Rem                            funcion de validacion real, no regexp_like, sobre
Rem                            la muestra completa de p_sample_rows). Ningun
Rem                            dominio de negocio queda hardcodeado: la lista de
Rem                            palabras-clave de entidad es generica en espanol
Rem                            (S.A., MINISTERIO, ASOCIACION, etc.), igual de
Rem                            "dato" que las demas reglas del motor.
Rem
Rem    epurisaca    10/03/26 - REGRESION real detectada por el usuario en la
Rem                            primera ejecucion de descubrimiento con el fix
Rem                            del 10/02/26 (DM_DUMMY: TBL_PERSONAS.NOMBRE,
Rem                            TBL_PERSONA_VOL.NOMBRE, TBL_EMPLEADO_VOL.
Rem                            NOMBRE_EMPLEADO -- SCORE_NOMBRE=90, degradadas a
Rem                            REVISAR/ENMASCARAR=N/DATO_NO_COINCIDE_CON_FORMATO,
Rem                            cuando antes confirmaban). CAUSA RAIZ: la regla
Rem                            DATA_PATTERN sembrada el 10/02/26
Rem                            (__CONTENIDO_NOMBRE_PERSONA__) se cargo con
Rem                            confianza_min=60 Y puntuacion=70>0 -- eso la
Rem                            convertia en la PRIMERA fila "exigente" (confianza_min
Rem                            informado + puntuacion>0) que ha tenido jamas
Rem                            IDENTIFICADOR_PERSONAL. El mecanismo de
Rem                            contradiccion dato-vs-nombre (p_contra_out, FIX
Rem                            09/26/26, antes NUNCA aplicable a PERSONAL porque
Rem                            ninguna fila suya cumplia las dos condiciones a la
Rem                            vez) empezo entonces a dispararse para TODA la
Rem                            categoria: con >=10 filas de muestra, en cuanto
Rem                            ningun valor tenia forma "Nombre Apellido(s)" (2-4
Rem                            tokens -- un NOMBRE de un solo token, sin apellido
Rem                            en la misma columna, nunca la cumple), p_contra_out
Rem                            pasaba a 1 y proc_dm_procesa_desc capaba
Rem                            SCORE_TOTAL a 55 (linea ~2106) ANTES de que el
Rem                            rescate por score_nombre>=85 (linea ~2113) pudiera
Rem                            actuar -- degradando columnas con evidencia de
Rem                            nombre abrumadora. FIX: en
Rem                            03_dm_descubrimiento_carga_reglas.sql se quita
Rem                            confianza_min de esa fila (pasa a NULL) y se anade
Rem                            un UPDATE idempotente que repara la fila ya
Rem                            insertada en PREFORM/PRESAE. Sin cambio de codigo
Rem                            PL/SQL: r.es_ (el flag "exigente") se calcula en
Rem                            tiempo de ejecucion desde TDM_REGLA, asi que la
Rem                            correccion es solo de datos. La regla sigue
Rem                            sumando puntuacion*ratio cuando el contenido SI
Rem                            tiene forma de nombre (confianza_min nulo ->
Rem                            nvl a 0 -> el umbral "(ratio*100)>=confianza_min"
Rem                            se cumple con solo ratio>0), solo que ya no puede
Rem                            volver a activar p_contra_out.
Rem                            PENDIENTE (no resuelto por este fix, requiere
Rem                            decision de alcance aparte): el caso original que
Rem                            motivo el cambio del 10/02/26 -- EXPEDIENTES.
Rem                            PROMOTOR en DATAM_ARCA_OWN -- SIGUE sin marcarse.
Rem                            Confirmado con el export real de TDM_COLUMNA_HIST:
Rem                            esa columna sigue con IDENTIFICADOR=
Rem                            IDENTIFICADOR_OBS, no IDENTIFICADOR_PERSONAL. La
Rem                            causa es mas profunda que el gate de
Rem                            func_dm_score_patron: func_dm_identificador_base
Rem                            (linea ~727) elige el identificador "base" SOLO por
Rem                            evidencia lexica de nombre/comentario/tabla, ANTES
Rem                            de muestrear ningun dato, y se queda con un UNICO
Rem                            ganador por columna. Para PROMOTOR ese ganador es
Rem                            IDENTIFICADOR_OBS (coincide con reglas de
Rem                            COLUMN_NAME de esa categoria), por lo que
Rem                            IDENTIFICADOR_PERSONAL nunca llega a ser el
Rem                            p_identificador que recibe func_dm_score_patron --
Rem                            el chequeo de contenido anadido el 10/02/26 es
Rem                            correcto pero arquitectonicamente inalcanzable
Rem                            para esta columna. Resolverlo exige tocar
Rem                            func_dm_identificador_base o su llamador en
Rem                            proc_dm_procesa_desc (p.ej. evaluar score_patron
Rem                            para algo mas que el unico "ganador" lexico) --
Rem                            cambio de mayor alcance en el motor de
Rem                            seleccion de identificador, no aplicado aqui a la
Rem                            espera de decision expresa del usuario dado el
Rem                            riesgo de regresion ya demostrado en este mismo
Rem                            hallazgo.
Rem
Rem    epurisaca    10/03/26 - PROMOTOR (continuacion, con datos reales): el usuario
Rem                            aporto una muestra real de 1000 filas de
Rem                            EXPEDIENTES.PROMOTOR (DATAM_ARCA_OWN). Analisis
Rem                            cuantitativo (no suposicion) confirma que la
Rem                            columna es genuinamente mixta: ~53% nombre de
Rem                            persona puro ("Nombre Apellido(s)", a veces
Rem                            varias personas unidas con "y"), ~25% forma
Rem                            administrativa "Apellidos, Nombre. NIF:
Rem                            12345678A", ~20% entidad con forma legal + CIF
Rem                            ("Entidad, S.A. CIF: A12345678"). La version del
Rem                            02/10/26 de func_dm_es_nombre_persona_valido
Rem                            exigia COINCIDENCIA COMPLETA del valor (ancla
Rem                            '$' final) -- por eso nunca reconocia el 25%
Rem                            con sufijo ". NIF: ..." ni las uniones con "y".
Rem                            Dos cambios, validados contra las 1000 filas
Rem                            reales antes de escribirse (cero falsos
Rem                            positivos sobre las entidades de la muestra):
Rem                              1) Se quita el ancla '$' final: ahora basta
Rem                              que el valor EMPIECE por 2-4 tokens con forma
Rem                              de nombre, no que sea SOLO eso. La exclusion
Rem                              de palabras de entidad (S.A./S.L./MINISTERIO/
Rem                              etc.) sigue evaluando el valor COMPLETO, asi
Rem                              que las entidades reales de la muestra siguen
Rem                              descartadas igual (confirmado una por una).
Rem                              2) Nueva funcion privada
Rem                              func_dm_contiene_doc_identidad_valido(p_valor):
Rem                              busca un NIF/NIE con digito de control VALIDO
Rem                              en cualquier posicion del texto (no exige que
Rem                              el valor sea SOLO el documento), reutilizando
Rem                              el MISMO validador ya probado en produccion
Rem                              (func_dm_es_dni_nie_valido) -- cero regex
Rem                              nuevo de validacion. El checksum de un NIF
Rem                              solo lo cumple una persona fisica real; un
Rem                              CIF de entidad (letra+8 cifras, otro
Rem                              algoritmo de digito de control) practicamente
Rem                              nunca lo cumple -- discrimina persona de
Rem                              entidad sin ninguna lista de palabras.
Rem                            Ambas señales se cablean como dos reglas
Rem                            DATA_PATTERN INDEPENDIENTES y ADITIVAS para
Rem                            IDENTIFICADOR_PERSONAL (la ya existente
Rem                            __CONTENIDO_NOMBRE_PERSONA__ mas la nueva
Rem                            __CONTENIDO_DOC_IDENTIDAD_EMBEBIDO__, sembrada
Rem                            en 03_dm_descubrimiento_carga_reglas.sql), igual
Rem                            que el motor ya acumula puntuacion de varias
Rem                            reglas DATA_PATTERN de IBAN para
Rem                            IDENTIFICADOR_BANCARIO -- no es un mecanismo
Rem                            nuevo, es el mismo patron ya probado. La nueva
Rem                            regla se siembra con confianza_min NULL desde
Rem                            el origen (no con un valor que haya que
Rem                            corregir despues como la regla del 02/10/26):
Rem                            nunca activa por si sola la contradiccion
Rem                            exigente (p_contra_out) para PERSONAL. Tambien
Rem                            se amplia func_dm_contenido_parece_persona (el
Rem                            pre-chequeo barato de 10 filas que decide si
Rem                            vale la pena no descartar la columna solo por
Rem                            su nombre): ahora cuenta una fila como evidencia
Rem                            si CUALQUIERA de las dos señales aplica, y se
Rem                            baja el umbral de 70% a 50% -- una columna
Rem                            genuinamente mixta (confirmado con los datos
Rem                            reales) nunca va a dar un ratio alto en una
Rem                            muestra de solo 10 filas, y 70% era demasiado
Rem                            sensible al ruido de muestreo para este caso.
Rem                            Con los ratios reales medidos sobre las 1000
Rem                            filas (~73% para la señal de nombre, ~25% para
Rem                            la de documento embebido), el score combinado
Rem                            esperado para esta columna (~70*0.73 + 70*0.25
Rem                            ~= 69) cruza el umbral de PROBABLE/ENMASCARAR=Y
Rem                            (>=65 en proc_dm_clasifica), contra los 46.59 de
Rem                            IDENTIFICADOR_OBS que hoy se quedan en
Rem                            REVISAR/N. Pendiente que el usuario re-ejecute
Rem                            descubrimiento sobre DATAM_ARCA_OWN para
Rem                            confirmar el resultado real.
Rem
Rem    epurisaca    10/03/26 - PROMOTOR (correccion de alcance tras evaluacion de
Rem                            performance a escala real): el usuario señalo,
Rem                            con razon, que SRI2006 (79 tablas, ~100M filas,
Rem                            ~1TB) es la escala real de produccion -- no
Rem                            DATAM_ARCA_OWN (100MB) -- y que antes de agregar
Rem                            logica nueva hay que evaluar si la regla que ya
Rem                            existia bastaba. Evaluacion cuantitativa: la
Rem                            regla __CONTENIDO_NOMBRE_PERSONA__ con
Rem                            puntuacion=70 y el ratio real medido sobre las
Rem                            1000 filas de muestra (73%) da un score esperado
Rem                            de 70*0.73=51.1 -- por debajo del umbral de 65
Rem                            (PROBABLE) de proc_dm_clasifica. Por eso el
Rem                            10/03/26 (entrada anterior) se agrego una
Rem                            SEGUNDA regla DATA_PATTERN independiente
Rem                            (__CONTENIDO_DOC_IDENTIDAD_EMBEBIDO__) con su
Rem                            propia funcion -- pero eso significa que TODA
Rem                            columna candidata a IDENTIFICADOR_PERSONAL
Rem                            (cualquier NOMBRE/APELLIDOS/TITULAR del esquema,
Rem                            no solo PROMOTOR) paga una SEGUNDA lectura
Rem                            completa de hasta 500 filas (rownum<=500) en
Rem                            cada ejecucion de descubrimiento, para siempre,
Rem                            en las 79 tablas de SRI2006 -- costo recurrente
Rem                            no estrictamente necesario para resolver el caso.
Rem                            Alternativa evaluada y aplicada: en vez de una
Rem                            segunda regla/escaneo, subir la puntuacion de la
Rem                            regla YA EXISTENTE (sembrada en
Rem                            03_dm_descubrimiento_carga_reglas.sql) de 70 a
Rem                            100 -- cambio de UN SOLO dato, cero codigo
Rem                            nuevo, cero escaneo adicional. Calculo de margen
Rem                            de seguridad frente al ruido de muestreo
Rem                            (n=500, ratio medido 73%, error estandar ~2%):
Rem                            con puntuacion=100 el score esperado es 73.0,
Rem                            con un intervalo de confianza del 99% entre 67.9
Rem                            y 78.1 -- SIEMPRE por encima de 65, incluso en
Rem                            el peor caso de muestreo. Con puntuacion=70, 85
Rem                            o incluso 90 el peor caso del intervalo cae por
Rem                            debajo de 65 (ver sesion para la tabla completa).
Rem                            CAMBIOS: se retira de func_dm_score_patron la
Rem                            rama l_es_regla_doc_embebido (declaracion,
Rem                            deteccion del sentinela y bucle de muestreo
Rem                            completo -- era codigo muerto en la ruta cara en
Rem                            cuanto se quito la regla de tdm_regla). La
Rem                            funcion func_dm_contiene_doc_identidad_valido NO
Rem                            se elimina: sigue viva dentro de
Rem                            func_dm_contenido_parece_persona (el pre-chequeo
Rem                            barato de 10 filas), donde su costo es
Rem                            insignificante (10 filas, no 500) y sigue
Rem                            aportando robustez frente al ruido de muestreo
Rem                            de esa compuerta especifica. En
Rem                            03_dm_descubrimiento_carga_reglas.sql: se quita
Rem                            el INSERT de __CONTENIDO_DOC_IDENTIDAD_EMBEBIDO__
Rem                            y se añade un DELETE idempotente para los
Rem                            entornos (PREFORM/PRESAE) donde esa fila ya se
Rem                            habia cargado; se sube puntuacion=100 en
Rem                            __CONTENIDO_NOMBRE_PERSONA__ via UPDATE
Rem                            idempotente ademas del INSERT para instalaciones
Rem                            nuevas. Leccion de ingenieria: antes de escribir
Rem                            una funcion y una regla nuevas, calcular primero
Rem                            si un ajuste de UN dato en una regla existente ya
Rem                            resuelve el caso con el margen de seguridad
Rem                            necesario -- el motor ya tenia la señal correcta,
Rem                            solo le faltaba la puntuacion correcta.
Rem
Rem    epurisaca    10/03/26 - REVERSION COMPLETA de PROMOTOR tras ejecucion real
Rem                            del usuario sobre DM_DUMMY y DATAM_ARCA_OWN (entrada
Rem                            anterior, la de "correccion de alcance", resulto
Rem                            INSUFICIENTE: la medicion propia de ratio 73% no se
Rem                            correspondia con lo que el scoring real evaluaba).
Rem                            Dos hallazgos del usuario, ambos verificados fila
Rem                            por fila contra TDM_COLUMNA_HIST real antes de
Rem                            actuar: (1) REGRESION REAL: DATAM_ARCA_OWN.
Rem                            PRESTAMOS.EDIFICIO y PRESTAMOS_BK.EDIFICIO (datos de
Rem                            direccion, p.ej. "Paseo Maria Agustin, 36
Rem                            (Pignatelli)") pasaron a clasificar PROBABLE/
Rem                            ENMASCARAR=Y (score_patron=67,4=100*0,674). Causa:
Rem                            el regex de func_dm_es_nombre_persona_valido, sin
Rem                            ancla '$' final desde el 03/10/26, acepta como
Rem                            "nombre" el PREFIJO de cualquier valor con 2 a 4
Rem                            tokens capitalizados -- y una direccion en
Rem                            castellano (calle+numero) tiene esa misma forma
Rem                            lexica. (2) EL FIX NO CUMPLIA SU OBJETIVO:
Rem                            EXPEDIENTES.PROMOTOR seguia en REVISAR/N en
Rem                            produccion (score_patron=46,8=100*0,468, por debajo
Rem                            de 65). Re-verificacion con el archivo real de 1000
Rem                            filas (no solo el calculo de la entrada anterior):
Rem                            nombre-sin-ancla=41,4%, nombre-con-ancla=7,6%,
Rem                            documento-embebido-solo=25,2%, con-ancla-OR-
Rem                            documento=32,8% -- NINGUNA variante realista
Rem                            alcanza 65 (PROBABLE) ni 45 (REVISAR). El ~73%
Rem                            citado el 03/10/26 (entrada anterior) combinaba mal
Rem                            las dos señales y no reflejaba lo que el bucle de
Rem                            scoring realmente ejecutaba tras simplificarse por
Rem                            costo mas temprano ese mismo dia -- un error de
Rem                            medicion propio. CONCLUSION Y ACCION: el mecanismo
Rem                            completo "el dato manda sobre el nombre" para
Rem                            IDENTIFICADOR_PERSONAL (introducido 02/10/26,
Rem                            ajustado 03/10/26 dos veces) se REVIERTE por
Rem                            completo, no se parchea de nuevo -- no logra su
Rem                            objetivo y el riesgo de falsos positivos sobre
Rem                            cualquier columna de direccion/ubicacion en las 79
Rem                            tablas de SRI2006 es real e inaceptable. Se
Rem                            eliminan las 3 funciones (func_dm_es_nombre_
Rem                            persona_valido, func_dm_contiene_doc_identidad_
Rem                            valido, func_dm_contenido_parece_persona), su
Rem                            llamada en el gate de proc_dm_procesa_desc (vuelve
Rem                            a ser el simple "return 0" anterior al 02/10/26), y
Rem                            la rama l_es_regla_nombre_persona de
Rem                            func_dm_score_patron. En 03_dm_descubrimiento_
Rem                            carga_reglas.sql: se retira el INSERT de
Rem                            __CONTENIDO_NOMBRE_PERSONA__ y se añade DELETE
Rem                            idempotente para PREFORM/PRESAE (donde ya se habia
Rem                            cargado con puntuacion=100). EXPEDIENTES.PROMOTOR
Rem                            queda, de forma deliberada, sin clasificacion
Rem                            automatica -- via correcta para el negocio: FORCE
Rem                            manual en TDM_EXCEPCION_COL si se decide que debe
Rem                            enmascararse, no un heuristico de contenido
Rem                            generico evaluado sobre 500 filas de cada columna
Rem                            candidata del esquema completo.
Rem
Rem    epurisaca    10/03/26 - Dos hallazgos reales mas del usuario, verificados
Rem                            contra ejecuciones reales (@dm_descubre) antes de
Rem                            corregir: (1) @dm_descubre contra un esquema que
Rem                            no existe (typo DM_ARCA_OWN) no daba ningun error:
Rem                            insertaba igual una fila FINALIZADO en
Rem                            TDM_EJECUCION con tablas_total=0/columnas_total=0
Rem                            en silencio -- proc_dm_descubrimiento_core no
Rem                            validaba la existencia del esquema antes del
Rem                            INSERT. Corregido: chequeo contra DBA_USERS al
Rem                            inicio del procedimiento, antes de crear
Rem                            cualquier fila de ejecucion; lanza ORA-20016 con
Rem                            mensaje explicito si el esquema no existe.
Rem                            Confirmado en produccion (PRESAE) tras el fix:
Rem                            ahora corta con el error correcto, cero fila
Rem                            fantasma. (2) DATAM_ARCA_OWN.PRESTAMOS.EDIFICIO
Rem                            (datos reales "Paseo Maria Agustin, 36
Rem                            (Pignatelli)", "C/ Joaquin Costa, 18") quedaba
Rem                            DESCARTADO para IDENTIFICADOR_DIRECCION
Rem                            (ratio_match=0,112) pese a ser, a ojo, una
Rem                            direccion real -- causa raiz: la unica regla de
Rem                            contenido de IDENTIFICADOR_DIRECCION busca
Rem                            tokens en MAYUSCULA literal ('PASEO','CALLE',...)
Rem                            via regexp_like SIN el match_option 'i', y esa
Rem                            llamada (linea ~1113) resulto ser la UNICA de
Rem                            todo el paquete sin 'i' -- todo el resto
Rem                            (matching por COLUMN_NAME) ya lo usa. El dato
Rem                            real viene en Title Case, no en mayuscula.
Rem                            Confirmado reproduciendo el regex exacto en
Rem                            Python contra las 8 muestras reales que paso el
Rem                            usuario: sensible a mayusculas matchea 2/8
Rem                            (25%, coherente con el 0,112 real medido sobre
Rem                            500 filas); insensible a mayusculas matchea 8/8
Rem                            (100%). Corregido anadiendo 'i' como
Rem                            match_option en esa UNICA llamada -- alcance
Rem                            general (afecta a toda regla DATA_PATTERN
Rem                            generica de contenido de cualquier
Rem                            identificador, no solo DIRECCION), cambio
Rem                            monotono (solo puede sumar matches, nunca
Rem                            quitarlos) y sin riesgo detectado tras revisar
Rem                            una por una las reglas DATA_PATTERN existentes
Rem                            en 03_dm_descubrimiento_carga_reglas.sql: ninguna
Rem                            depende de que una letra especifica estuviera en
Rem                            mayuscula para significar algo distinto. Con
Rem                            puntuacion=45 y ratio cercano a 1,0, EDIFICIO
Rem                            pasa de DESCARTADO (invisible) a REVISAR
Rem                            (score≈45, justo el umbral -- visible para
Rem                            revision humana, SIN auto-enmascarar) -- el
Rem                            resultado correcto: una direccion de edificio
Rem                            administrativo es, como minimo, un caso a
Rem                            revisar por el negocio, no algo que descartar en
Rem                            silencio ni algo que enmascarar sin mas.
Rem
Rem    epurisaca    10/07/26 - FORCE sobre columna SIN evidencia (prueba L-06): el continue
Rem                            de proc_dm_procesa_desc la descartaba antes de aplicar la
Rem                            excepcion, asi que no entraba en TDM_COLUMNA_HIST/FINAL ni
Rem                            recolectaba dependencias. Ahora un FORCE vivo con identificador
Rem                            forzado la deja pasar. Sin FORCE el comportamiento es identico.
Rem
Rem    epurisaca    10/09/26 - func_dm_score_patron: ORA-06502 con CLOB/texto acentuado largo
Rem                            (GCAA_OWN.LOG_SCAREG.MENSAJE). dbms_lob.substr(..,4000,1) son 4000
Rem                            caracteres pero el VARCHAR2 de SQL admite 4000 BYTES; el error se
Rem                            capturaba, se registraba y se devolvia score 0 para todos los
Rem                            identificadores: columna descartada SIN evidencia de datos. Ahora
Rem                            regexp_like evalua el CLOB directo y la rama DNI/NIE usa 1000 caracteres.
Rem
Rem    epurisaca    10/09/26 - proc_dm_procesa_desc: una columna con evidencia positiva pero total <= 0
Rem                            (CEFCEN_OWN.CC_DOCUMENTOS.DESCRIPCION_DOCUMENTO: nombre OBS +55, tabla
Rem                            DOCUMENTOS -100) desaparecia sin fila en TDM_COLUMNA_HIST. Ahora queda
Rem                            como DESCARTADO / SCORE_TOTAL_NO_POSITIVO con su mejor candidato, para
Rem                            poder auditar que se evaluo. NO cambia que se enmascare (sigue en N).
Rem
Rem    epurisaca    10/09/26 - proc_dm_sync_col_final: filas Y OBSOLETAS en TDM_COLUMNA_FINAL.
Rem                            Una columna antes Y que en la nueva ejecucion queda sin evidencia
Rem                            (no se escribe en HIST) o su tabla/columna ya no existe, conservaba
Rem                            su fila Y y se seguia enmascarando (caso GCAA_OWN.DIRECCION_IP_CAMBIO
Rem                            tras anadir las reglas de refutacion de IP). Ahora se retiran de FINAL
Rem                            las columnas de tablas ANALIZADAS en esta ejecucion que no quedaron Y
Rem                            en HIST, y las que ya no existen en el diccionario; traza FINAL_OBSOLETAS.
Rem

/*
g_version constant varchar2(30) := 'v12.0.20260928';procedure version is
begin
  dbms_output.put_line('pkg_dm_descubrimiento - versión: ' || g_version);
end;
*/
-----------------------------------------------------------------------------------------
-- (13) PAQUETE DESCUBRIMIENTO
-- Rediseño de las reglas de descubrimiento
-- v12.0.2
----------------------------------------------------------------------------------------
create or replace package pkg_dm_descubrimiento as
  procedure proc_dm_descubrimiento(
      p_esquema          in varchar2,
      p_sample_rows      in number default 500,
      p_forzar_full      in char default 'N'
  );

  procedure proc_dm_descubrimiento(
      p_esquema          in varchar2,
      p_forzar_full      in char
  );

  -- FIX 2026-09-18: descubrimiento por excepciones. Mapea metadata,
  -- triggers e integridad SOLO de las tablas indicadas (p.ej. las ya
  -- registradas en tdm_excepcion_col para un FORCE previo), sin escanear
  -- el esquema completo. Usa el mismo mecanismo de alcance que ya respeta
  -- proc_dm_prepara_objetos (tdm_ejecucion_scope), antes solo accesible
  -- internamente porque proc_dm_descubrimiento fijaba el alcance a NULL
  -- (esquema completo) de forma fija.
  procedure proc_dm_descubrimiento_set(
      p_esquema          in varchar2,
      p_tablas_csv       in varchar2,
      p_sample_rows      in number default 500,
      p_forzar_full      in char default 'N'
  );

  procedure proc_dm_reanudar(
      p_ejecucion_id     in number,
      p_sample_rows      in number default 500,
      p_commit_lote      in number default 100
  );

  procedure proc_dm_cancelar(
      p_ejecucion_id in number
  );

  procedure proc_dm_propaga_dominios(
      p_esquema      in varchar2,
      p_solicitud_id in number default null,
      p_ejecucion_id in number default null
  );

end pkg_dm_descubrimiento;
/

--------------------------------------------------------------------------------
-- 14) PACKAGE BODY
--------------------------------------------------------------------------------
create or replace package body pkg_dm_descubrimiento as

-- =========================================================
-- BLOQUE B: ALIAS DE NOMBRE PERSONAL PROPIOS DEL NEGOCIO ACTUAL (DGA)
-- =========================================================
-- FIX 2026-09-27 (revision de portabilidad): antes de este fix, estos mismos
-- 7 alias (NOMSO/NOMSOL/NOMARR/NOMUEC/ACU_NOMBRE/USU_LT_USU/UNIFAM_APENU --
-- las mismas convenciones de nombre de columna del esquema PNCSS que ya
-- estan cargadas como reglas de negocio en el BLOQUE B de
-- 03_dm_descubrimiento_carga_reglas.sql) estaban ADEMAS hardcodeados,
-- literalmente, en TRES sitios distintos de este paquete (dos de ellos
-- copias exactas entre si), mezclados con los alias genericos del motor.
--
-- Esta es la UNICA linea de este paquete que hay que revisar/sustituir por
-- los alias de nombre de la organizacion nueva al reinstalar en otro sitio
-- (ademas del Bloque B de 03, que es quien realmente puntua estos alias en
-- el scoring por nombre; esta constante solo alimenta las compuertas de
-- abajo, que deciden si a una columna candidata a IDENTIFICADOR_PERSONAL se
-- le aplica ademas la validacion de contexto/semantica de nombre). Si no
-- hay alias de negocio que anadir, dejar la constante vacia (''): el
-- comportamiento de las 3 compuertas pasa a depender solo de sus alias
-- genericos, sin tocar mas nada.
--
g_alias_nombre_negocio constant varchar2(200) := 'NOMSO|NOMSOL|NOMARR|NOMUEC|ACU_NOMBRE|USU_LT_USU|UNIFAM_APENU';

-- FIX 2026-09-27 (portabilidad + deduplicacion): esta misma expresion vivia
-- HARDCODEADA Y DUPLICADA dos veces dentro de proc_dm_procesa_desc (la
-- compuerta de penalizacion por falta de contexto y la compuerta de
-- degradacion a REVISAR) -- exactamente el patron que hace facil corregir
-- una copia y olvidar la otra. Se centraliza en una unica funcion; el
-- conjunto de alias que matchea es IDENTICO, caracter por caracter en su
-- union final, al de las dos expresiones que reemplaza.
------------------------------------------------------------------------------
-- [DOC] function func_dm_es_nombre_candidato
-- PROPOSITO    : Indica si un nombre de columna corresponde a un alias de nombre de persona (NOMBRE,
--                NOM, alias de negocio) para activar las compuertas de contexto personal.
-- ENTRADAS     : p_columna: nombre de columna. Retorna 1 si coincide con la regex de alias (incluye
--                la constante g_alias_nombre_negocio), 0 si no.
-- LEE          : ninguno
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc (2 compuertas, lineas 2438 y 2488)
------------------------------------------------------------------------------
function func_dm_es_nombre_candidato(p_columna in varchar2) return number is
begin
  if regexp_like(p_columna,
       '(^|_)(NOMBRE|NOMBRE_ALT|NOMBRE_USUARIO|US_NOMBRE|NOM|APELLIDOS_NOMBRE|NOMBRE_COMPLETO|'||g_alias_nombre_negocio||')($|_)',
       'i')
  then
    return 1;
  end if;
  return 0;
end func_dm_es_nombre_candidato;

-- =========================================================
-- VALIDACION REAL DNI/NIE
-- =========================================================
------------------------------------------------------------------------------
-- [DOC] function func_dm_es_dni_nie_valido
-- PROPOSITO    : Valida un DNI o NIE espanol comprobando formato y letra de control (modulo 23).
-- ENTRADAS     : p_valor: texto a validar. Retorna 1 si es DNI/NIE con letra correcta, 0 en caso
--                contrario.
-- LEE          : ninguno
-- ESCRIBE      : ninguno
-- ERRORES      : Cualquier excepcion interna se traduce en retorno 0 (sin ORA)
-- LLAMADO DESDE: func_dm_score_patron (muestreo de reglas DNI/NIE)
------------------------------------------------------------------------------
function func_dm_es_dni_nie_valido(p_valor varchar2)
return number
is
  v_valor varchar2(50);
  v_num   varchar2(20);
  v_letra char(1);
  v_calc  char(1);
  v_tabla constant varchar2(23) := 'TRWAGMYFPDXBNJZSQVHLCKE';
begin
  v_valor := upper(trim(p_valor));

  if v_valor is null then
    return 0;
  end if;

  if regexp_like(v_valor, '^[0-9]{8}[A-Z]$') then
    v_num   := substr(v_valor, 1, 8);
    v_letra := substr(v_valor, 9, 1);
    v_calc  := substr(v_tabla, mod(to_number(v_num), 23) + 1, 1);
    return case when v_letra = v_calc then 1 else 0 end;

  elsif regexp_like(v_valor, '^[XYZ][0-9]{7}[A-Z]$') then
    v_num :=
      case substr(v_valor, 1, 1)
        when 'X' then '0'
        when 'Y' then '1'
        when 'Z' then '2'
      end || substr(v_valor, 2, 7);

    v_letra := substr(v_valor, 9, 1);
    v_calc  := substr(v_tabla, mod(to_number(v_num), 23) + 1, 1);
    return case when v_letra = v_calc then 1 else 0 end;
  else
    return 0;
  end if;

exception
  when others then
    return 0;
end func_dm_es_dni_nie_valido;

-- =========================================================
-- REVERSION COMPLETA 2026-10-03 (vespertino): se retira TODO el mecanismo
-- "el dato manda sobre el nombre" para IDENTIFICADOR_PERSONAL introducido el
-- 02/10/26 y ajustado el 03/10/26 (funciones func_dm_es_nombre_persona_valido,
-- func_dm_contiene_doc_identidad_valido y func_dm_contenido_parece_persona,
-- mas la regla sentinela __CONTENIDO_NOMBRE_PERSONA__ en 03_...carga_reglas).
-- Motivo (evaluacion solicitada por el usuario sobre los resultados reales de
-- @dm_descubre en DM_DUMMY y DATAM_ARCA_OWN el mismo dia):
--   1) REGRESION REAL CONFIRMADA: DATAM_ARCA_OWN.PRESTAMOS.EDIFICIO y
--      PRESTAMOS_BK.EDIFICIO (direcciones tipo "Paseo Maria Agustin, 36
--      (Pignatelli)") empezaron a clasificar PROBABLE/ENMASCARAR=Y. Causa
--      raiz: el regex de forma de nombre, al quitarle el ancla '$' el mismo
--      dia para intentar resolver PROMOTOR, pasa a aceptar como "nombre" el
--      PREFIJO de cualquier valor con 2 a 4 tokens capitalizados -- y un
--      nombre de calle/edificio en castellano tiene exactamente esa forma
--      lexica. Confirmado fila por fila contra TDM_COLUMNA_HIST real
--      (score_patron=67,4 = 100*0,674; ratio_match=337/500=0,674) y contra el
--      mismo regex ejecutado en Python sobre la muestra real.
--   2) EL FIX NUNCA CUMPLIO SU PROPIO OBJETIVO: el score_patron real de
--      EXPEDIENTES.PROMOTOR en produccion fue 46,8 (100*0,468), por debajo
--      del umbral PROBABLE (65) -- sigue en REVISAR/ENMASCARAR=N, igual que
--      antes de todo este cambio. La estimacion de ~73% de ratio citada en el
--      changelog del mismo dia (basada en combinar nombre+documento) NO se
--      corresponde con lo que el bucle de scoring realmente evalua (solo la
--      señal de nombre, tras simplificarse por costo mas temprano ese mismo
--      dia) -- un error de medicion propio, detectado al re-verificar con el
--      archivo real de 1000 filas: nombre-solo-sin-ancla=41,4%,
--      nombre-con-ancla=7,6%, documento-solo=25,2%, con-ancla-OR-documento=
--      32,8% -- ninguna combinacion realista alcanza 65 ni siquiera 45.
--   3) CONCLUSION: el mecanismo no logra enmascarar PROMOTOR (sigue N en
--      cualquier variante evaluada) y SI introduce un falso positivo real y
--      peligroso sobre datos de direccion/edificio -- a escala SRI2006 (79
--      tablas, ~100M filas) el mismo patron lexico (calle+numero+parentesis)
--      aparece en cualquier columna de domicilio/emplazamiento del esquema,
--      no solo en DM_DUMMY.EDIFICIO. Coste sin beneficio y con riesgo real:
--      se revierte por completo, no se parchea. El gate de
--      IDENTIFICADOR_PERSONAL vuelve a ser el simple chequeo por nombre de
--      columna (NOMBRE|APELLIDO|...) que existia antes del 02/10/26.
-- PROMOTOR queda, de forma deliberada, sin clasificacion automatica: es un
-- caso genuinamente mixto (persona fisica o entidad segun la fila) que un
-- heuristico de contenido generico no puede resolver con seguridad a esta
-- escala. Via correcta si el negocio confirma que debe enmascararse: FORCE
-- manual en TDM_EXCEPCION_COL (ya soportado por el motor), no un regex mas
-- permisivo evaluado sobre las 500 filas de muestra de cada columna de los
-- 79 tablas de SRI2006.
-- =========================================================

------------------------------------------------------------------------------
-- LOG DE ERRORES
-- 2026-10-09 (limpieza de duplicidad): ya NO escribe en TDM_EJECUCION_ERROR por su
-- cuenta. El unico escritor es pkg_dm_trazabilidad.proc_dm_log_ejec_error, que
-- ademas deja la linea ERROR.REGISTRADO en la linea de tiempo (TDM_MASK_TRACE)
-- enlazada por error_id. Esta rutina se conserva solo como atajo con la firma
-- historica del descubrimiento (7 llamadores) y como red de seguridad: NUNCA debe
-- poder abortar el proceso que esta protegiendo (historia: incidente SRI2006,
-- ORA-00001 en el PK del error escalaba un fallo de una columna a un aborto total;
-- la proteccion contra colision de error_id con reintento vive ahora en 03b).
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_log_error
-- PROPOSITO    : Registra un error del descubrimiento delegando en pkg_dm_trazabilidad sin poder
--                abortar nunca al proceso que protege.
-- ENTRADAS     : p_ejecucion_id, p_owner, p_tabla, p_columna, p_etapa, p_code (codigo SQL), p_msg
--                (mensaje). Sin OUT.
-- LEE          : ninguno
-- ESCRIBE      : TDM_EJECUCION_ERROR y TDM_MASK_TRACE (indirecto, via
--                pkg_dm_trazabilidad.proc_dm_log_ejec_error, autonomous transaction)
-- ERRORES      : No levanta ORA-2xxxx; ante cualquier fallo escribe WARN por DBMS_OUTPUT y continua
-- LLAMADO DESDE: func_dm_score_patron; proc_dm_recolecta_dep; proc_dm_aplica_excepcion;
--                proc_dm_procesa_desc
------------------------------------------------------------------------------
procedure proc_dm_log_error(
    p_ejecucion_id in number,
    p_owner        in varchar2,
    p_tabla        in varchar2,
    p_columna      in varchar2,
    p_etapa        in varchar2,
    p_code         in number,
    p_msg          in varchar2
) is
begin
  pkg_dm_trazabilidad.proc_dm_log_ejec_error(
    p_ejecucion_id => p_ejecucion_id,
    p_owner_name   => p_owner,
    p_table_name   => p_tabla,
    p_column_name  => p_columna,
    p_etapa        => p_etapa,
    p_codigo_error => p_code,
    p_mensaje      => p_msg,
    p_backtrace    => dbms_utility.format_error_backtrace
  );
exception
  when others then
    begin
      dbms_output.put_line('WARN proc_dm_log_error no pudo registrar: '||
        p_etapa||' code='||p_code||' -- fallo interno: '||sqlerrm);
    exception
      when others then null;
    end;
end proc_dm_log_error;

------------------------------------------------------------------------------
-- Normaliza tamaño de muestra 10 - 500 filas
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_normaliza_sample
-- PROPOSITO    : Acota el tamano de muestra por columna al rango 10 a 500 filas (500 si es nulo).
-- ENTRADAS     : p_sample_rows: filas solicitadas. Retorna numero normalizado entre 10 y 500.
-- LEE          : ninguno
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: func_dm_score_patron; func_dm_ratio_nombre_sem; proc_dm_descubrimiento_core;
--                proc_dm_reanudar
------------------------------------------------------------------------------
function func_dm_normaliza_sample(p_sample_rows in number) return number is
begin
  if p_sample_rows is null then
    return 500;
  elsif p_sample_rows < 10 then
    return 10;
  elsif p_sample_rows > 500 then
    return 500;
  else
    return trunc(p_sample_rows);
  end if;
end func_dm_normaliza_sample;

------------------------------------------------------------------------------
-- Captura de sesion, verificacion de sesion viva y autocancelacion de
-- huerfanas: MOVIDAS a pkg_dm_trazabilidad el 09/27/26 (proc_dm_refresca_sesion,
-- func_dm_sesion_viva, proc_dm_autocancel_huerfanas). Eran privadas aqui y
-- duplicadas en pkg_dm_enmascarar (05), que ademas no tenia autocancelacion
-- propia. Son infraestructura sobre TDM_EJECUCION compartida por ambas fases,
-- no logica de descubrimiento; ver cabecera de 03b_dm_pkg_trazabilidad.sql.
-- Llamadas en este archivo ahora via pkg_dm_trazabilidad.<nombre>.
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Evalúa conflictos EJECUTANDO por esquema/tabla
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_conflicto_running
-- PROPOSITO    : Determina si existe una ejecucion EJECUTANDO que choque con el esquema (y
--                opcionalmente las tablas) a descubrir.
-- ENTRADAS     : p_esquema, p_tablas_csv (lista de tablas o null = esquema completo). Retorna 1 si
--                hay conflicto, 0 si no.
-- LEE          : TDM_EJECUCION; TDM_EJECUCION_SCOPE
-- ESCRIBE      : Indirecto: pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(5,'Y') puede cancelar
--                ejecuciones huerfanas en TDM_EJECUCION
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_descubrimiento_core (siempre con p_tablas_csv = null)
------------------------------------------------------------------------------
function func_dm_conflicto_running(
    p_esquema    in varchar2,
    p_tablas_csv in varchar2
) return number is
  l_conflicto number := 0;
begin
  pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(5, 'Y');

  for r in (
    select e.ejecucion_id
      from tdm_ejecucion e
     where e.ora_esquema = upper(p_esquema)
       and e.estado = 'EJECUTANDO'
  ) loop
    if p_tablas_csv is null then
      l_conflicto := 1;
    else
      select case
               when not exists (select 1 from tdm_ejecucion_scope s where s.ejecucion_id = r.ejecucion_id) then 1
               when exists (select 1 from tdm_ejecucion_scope s where s.ejecucion_id = r.ejecucion_id and s.table_name = '*') then 1
               when exists (
                    select 1
                      from tdm_ejecucion_scope s
                     where s.ejecucion_id = r.ejecucion_id
                       and s.ora_owner = upper(p_esquema)
                       and s.table_name in (
                             select upper(trim(regexp_substr(p_tablas_csv, '[^,]+', 1, level)))
                               from dual
                             connect by regexp_substr(p_tablas_csv, '[^,]+', 1, level) is not null
                           )
               ) then 1
               else 0
             end
        into l_conflicto
        from dual;
    end if;

    if l_conflicto = 1 then
      return 1;
    end if;
  end loop;

  return 0;
end func_dm_conflicto_running;

------------------------------------------------------------------------------
-- Registra scope de ejecución
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_registra_scope
-- PROPOSITO    : Registra en TDM_EJECUCION_SCOPE el alcance de la ejecucion: '*' para esquema
--                completo o una fila por tabla de la lista CSV.
-- ENTRADAS     : p_ejecucion_id, p_esquema, p_tablas_csv (null = esquema completo). Sin OUT.
-- LEE          : ninguno
-- ESCRIBE      : TDM_EJECUCION_SCOPE (INSERT); Indirecto: TDM_EJECUCION via
--                proc_dm_autocancel_huerfanas(15,'Y')
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_descubrimiento_core
------------------------------------------------------------------------------
procedure proc_dm_registra_scope(
    p_ejecucion_id in number,
    p_esquema      in varchar2,
    p_tablas_csv   in varchar2
) is
begin
  pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(15, 'Y');

  if p_tablas_csv is null then
    insert into tdm_ejecucion_scope(scope_id, ejecucion_id, ora_owner, table_name, column_name)
    values (seq_dm_ejecucion_scope.nextval, p_ejecucion_id, upper(p_esquema), '*', null);
  else
    for t in (
      select distinct upper(trim(regexp_substr(p_tablas_csv, '[^,]+', 1, level))) table_name
        from dual
      connect by regexp_substr(p_tablas_csv, '[^,]+', 1, level) is not null
    ) loop
      insert into tdm_ejecucion_scope(scope_id, ejecucion_id, ora_owner, table_name, column_name)
      values (seq_dm_ejecucion_scope.nextval, p_ejecucion_id, upper(p_esquema), t.table_name, null);
    end loop;
  end if;
end proc_dm_registra_scope;

------------------------------------------------------------------------------
-- SCORE por tipo de regla textual
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_score_texto
-- PROPOSITO    : Suma la puntuacion de las reglas activas de TDM_REGLA de un identificador y tipo
--                (nombre, comentario o tabla) que coinciden con un texto.
-- ENTRADAS     : p_identificador, p_tipo_regla, p_texto. Retorna la suma de puntuaciones (puede ser
--                negativa).
-- LEE          : TDM_REGLA
-- ESCRIBE      : ninguno
-- ERRORES      : No captura errores: una expresion regular invalida en TDM_REGLA se propagaria al
--                llamador
-- LLAMADO DESDE: func_dm_identificador_base; proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_score_texto(
    p_identificador in varchar2,
    p_tipo_regla    in varchar2,
    p_texto         in varchar2
) return number is
  l_score number := 0;
begin
  for r in (
    select expresion, puntuacion
      from tdm_regla
     where activa = 'Y'
       and identificador = p_identificador
       and tipo_regla = p_tipo_regla
     order by prioridad
  ) loop
    if regexp_like(nvl(p_texto,' '), r.expresion, 'i') then
      l_score := l_score + r.puntuacion;
    end if;
  end loop;

  return l_score;
end func_dm_score_texto;

------------------------------------------------------------------------------
-- Identificador base por evidencia léxica
-- Nunca usa hardcode de dominios concretos; se apoya en tdm_regla.
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_identificador_base
-- PROPOSITO    : Elige el identificador con mayor puntuacion lexica (columna, comentario, tabla) como
--                respaldo cuando ninguno tiene evidencia suficiente.
-- ENTRADAS     : p_columna, p_tabla, p_comentario. Retorna el identificador ganador o null si ninguna
--                puntuacion es positiva.
-- LEE          : TDM_REGLA
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_identificador_base(
    p_columna    in varchar2,
    p_tabla      in varchar2,
    p_comentario in varchar2
) return varchar2 is
  l_best_id    varchar2(50);
  l_best_score number := 0;
  l_score      number;
begin
  for r in (
    select distinct identificador
      from tdm_regla
     where activa = 'Y'
  ) loop
    l_score :=
        greatest(func_dm_score_texto(r.identificador, 'COLUMN_NAME',    p_columna), 0)
      + greatest(func_dm_score_texto(r.identificador, 'COLUMN_COMMENT', p_comentario), 0)
      + greatest(func_dm_score_texto(r.identificador, 'TABLE_NAME',     p_tabla), 0);

    if l_score > l_best_score then
      l_best_score := l_score;
      l_best_id := r.identificador;
    end if;
  end loop;

  if l_best_score > 0 then
    return l_best_id;
  end if;

  return null;
end func_dm_identificador_base;

------------------------------------------------------------------------------
-- Determina si la columna tiene evidencia mínima para persistirse en histórico
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_tiene_evid_min
-- PROPOSITO    : Indica si un identificador tiene al menos una puntuacion positiva (nombre,
--                comentario, tabla o patron) que justifique registrarlo.
-- ENTRADAS     : p_identificador y los 4 scores. Retorna 1 si hay evidencia minima, 0 si no.
-- LEE          : ninguno
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_tiene_evid_min(
    p_identificador in varchar2,
    p_score_nombre  in number,
    p_score_coment  in number,
    p_score_tabla   in number,
    p_score_patron  in number
) return number is
begin
  if p_identificador is null then
    return 0;
  end if;

  if greatest(nvl(p_score_nombre,0), nvl(p_score_coment,0), nvl(p_score_tabla,0), nvl(p_score_patron,0)) > 0 then
    return 1;
  end if;

  return 0;
end func_dm_tiene_evid_min;

------------------------------------------------------------------------------
-- Score de patrón con ratio y muestra mínima
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_score_patron
-- PROPOSITO    : Calcula la puntuacion por patron de datos de una columna ejecutando reglas
--                DATA_PATTERN sobre una muestra real de filas.
-- ENTRADAS     : p_ejecucion_id, p_owner, p_tabla, p_columna, p_identificador, p_sample_rows; OUT:
--                p_rows_out, p_match_out, p_ratio_out, p_contra_out (1 si el dato contradice los
--                formatos exigentes). Retorna el score acumulado.
-- LEE          : TDM_REGLA; Tabla de usuario muestreada (SELECT dinamico con
--                DBMS_ASSERT.ENQUOTE_NAME)
-- ESCRIBE      : Indirecto: TDM_EJECUCION_ERROR / TDM_MASK_TRACE via proc_dm_log_error
-- ERRORES      : No levanta ORA-2xxxx; ante cualquier error registra etapa
--                SCORE_PATRON:<identificador> y retorna 0 con OUT a cero; Retorna 0 sin muestrear si
--                el nombre de columna parece tecnico (ID/COD/TIPO...) salvo IDENTIDAD, o si
--                IDENTIFICADOR_PERSONAL no tiene nombre de persona o es de nomina
-- LLAMADO DESDE: proc_dm_procesa_desc (2 llamadas: lineas 2312 y 2399)
------------------------------------------------------------------------------
function func_dm_score_patron(
    p_ejecucion_id  in number,
    p_owner         in varchar2,
    p_tabla         in varchar2,
    p_columna       in varchar2,
    p_identificador in varchar2,
    p_sample_rows   in number,
    p_rows_out      out number,
    p_match_out     out number,
    p_ratio_out     out number,
    p_contra_out    out number
) return number is
  l_sql       varchar2(32767);
  l_rows      number := 0;
  l_matches   number := 0;
  l_ratio     number := 0;
  l_score     number := 0;
  l_rc        sys_refcursor;
  l_valor     varchar2(4000);
  l_es_regla_dni_nie number := 0;
  l_hay_     number := 0;
  l__rows    number := 0;
  l__match   number := 0;
begin
  p_rows_out   := 0;
  p_match_out  := 0;
  p_ratio_out  := 0;
  p_contra_out := 0;

  -- FIX 09/26/26: la compuerta por nombre (ID/COD/...) no se aplica a IDENTIDAD.
  -- Sus patrones de datos validan el digito de control (DNI/NIE), asi que un
  -- codigo que contiene documentos validos debe puntuar por sus datos.
  if p_identificador <> 'IDENTIFICADOR_IDENTIDAD'
     and (
       regexp_like(p_columna, '(^|_)(ID|COD|CODIGO|TIPO|FLAG|ESTADO|IND|SEQ|ORDEN|VERSION|HASH|TOKEN|UUID|PK|FK)($|_)', 'i')
       or regexp_like(p_columna, '^(ID|COD|CODIGO|TIPO|FLAG|ESTADO|IND|SEQ|ORDEN|VERSION|HASH|TOKEN|UUID|PK|FK)[A-Z0-9_]+$', 'i')
     )
     and not regexp_like(p_columna,
       '(^|_)(NIF|NIE|DNI|DOC|DOCUMENTO|NDOCUMENTO|NUM_DOCUMENTO|NRO_DOCUMENTO|IBAN|CUENTA|EMAIL|MAIL|TFNO|TELEF|MOVIL|DOMICILIO|DIRECCION|OBS|NOTA|DESCRIPCION|CONSULTA|RESPUESTA)($|_)', 'i')
  then
    return 0;
  end if;

-- FIX 2026-09-27 (portabilidad): los 7 alias de negocio (NOMSO/NOMSOL/...)
-- se movieron a g_alias_nombre_negocio (ver cabecera del paquete). El
-- conjunto final que matchea esta expresion es IDENTICO al de antes del
-- fix -- unicamente cambio DONDE vive el fragmento de negocio.
if p_identificador = 'IDENTIFICADOR_PERSONAL'
   and not regexp_like(p_columna,
     '(^|_)(NOMBRE|APE1|APE2|APELLIDO|APELLIDOS|APELLIDO1|APELLIDO2|AP1|AP2|APENU|TITULAR|SOLICITANTE|INTERESAD|BENEFICIARI|DECLARANTE|REPRESENTANTE|NOMBRE_COMPLETO|APELLIDOS_NOMBRE|'||g_alias_nombre_negocio||')($|_)',
     'i')
then
  -- REVERTIDO 2026-10-03 (vespertino): hasta el 02/10/26 este gate hacia
  -- simplemente "return 0" cuando el nombre de columna no matcheaba. Ese
  -- mismo dia se sustituyo por una llamada a func_dm_contenido_parece_persona
  -- ("el dato manda sobre el nombre") para intentar rescatar
  -- EXPEDIENTES.PROMOTOR -- se revierte por completo (ver changelog y el
  -- bloque de comentarios donde antes vivian esas 3 funciones, mas arriba en
  -- este archivo): el mecanismo nunca logro su objetivo (PROMOTOR sigue sin
  -- cruzar el umbral de mascara en ninguna variante medida) y si causo un
  -- falso positivo real sobre columnas de direccion/edificio a escala
  -- SRI2006. Vuelve a ser el gate simple por nombre de columna.
  return 0;
end if;

if p_identificador = 'IDENTIFICADOR_PERSONAL'
   and regexp_like(p_columna,
     '(^|_)(NOMINA|NOMINAS|NOMINA_PER|NOM_PER|NOM_PAGA|NOM_PAGALAM)($|_)',
     'i')
then
  return 0;
end if;

  for r in (
    select expresion,
           puntuacion,
           nvl(muestra_min, 10) muestra_min,
           nvl(confianza_min, 0) confianza_min,
           case when confianza_min is not null and puntuacion > 0 then 1 else 0 end es_
      from tdm_regla
     where activa = 'Y'
       and identificador = p_identificador
       and tipo_regla = 'DATA_PATTERN'
     order by prioridad
  ) loop
    l_rows    := 0;
    l_matches := 0;
    l_ratio   := 0;

    l_es_regla_dni_nie := 0;

    if p_identificador = 'IDENTIFICADOR_IDENTIDAD'
       and r.expresion in (
         '^[0-9]{8}[A-Z]$|^[XYZ][0-9]{7}[A-Z]$',
         '^[0-9]{7,8}[A-Z]$'
       )
    then
      l_es_regla_dni_nie := 1;
    end if;

    -- REVERTIDO 2026-10-03 (vespertino): aqui vivia la deteccion de la regla
    -- sentinela __CONTENIDO_NOMBRE_PERSONA__ (l_es_regla_nombre_persona) y su
    -- rama elsif de scoring completa -- eliminadas junto con las 3 funciones
    -- que las soportaban (ver changelog y bloque de comentarios mas arriba).

    -- FIX 2026-09-27 (incidente SRI2006): to_char(<columna>) sobre un valor real
    -- de mas de 4000 caracteres (CLOB o VARCHAR2 extendido, ej. campos de
    -- descripcion/config) lanza ORA-22835 (buffer demasiado pequeno). Se usa
    -- dbms_lob.substr(to_clob(<columna>),4000,1) en su lugar: to_clob() nunca
    -- desborda (el destino es CLOB, sin techo de 4000) y dbms_lob.substr extrae
    -- de forma segura los primeros 4000 caracteres para el muestreo -- mismo
    -- resultado que to_char() para cualquier valor que ya cabia en 4000.
    if l_es_regla_dni_nie = 1 then
      -- FIX 2026-10-09: 1000 caracteres (maximo 4000 bytes en UTF-8) en vez de 4000
      -- caracteres, que desbordaba el VARCHAR2 de SQL/l_valor (ORA-06502) con texto
      -- acentuado. Un documento DNI/NIE ocupa menos de 20 caracteres.
      l_sql := 'select dbms_lob.substr(to_clob(' || dbms_assert.enquote_name(p_columna, false) || '),1000,1) ' ||
               'from ' || dbms_assert.enquote_name(p_owner, false) || '.' || dbms_assert.enquote_name(p_tabla, false) ||
               ' where ' || dbms_assert.enquote_name(p_columna, false) || ' is not null and rownum <= :1';

      open l_rc for l_sql using p_sample_rows;
      loop
        fetch l_rc into l_valor;
        exit when l_rc%notfound;

        l_rows := l_rows + 1;
        if func_dm_es_dni_nie_valido(l_valor) = 1 then
          l_matches := l_matches + 1;
        end if;
      end loop;
      close l_rc;
    else
      -- FIX 2026-10-03 (hallazgo real del usuario sobre DATAM_ARCA_OWN.
      -- PRESTAMOS.EDIFICIO, datos reales "Paseo Maria Agustin, 36
      -- (Pignatelli)", "C/ Joaquin Costa, 18"): esta era la UNICA llamada a
      -- regexp_like en todo el paquete sin el match_option 'i' -- todas las
      -- demas (matching por COLUMN_NAME, mas arriba y en otras funciones) ya
      -- lo usan. La regla de contenido de IDENTIFICADOR_DIRECCION (y
      -- cualquier otra regla DATA_PATTERN generica que busque palabras
      -- literales en texto libre) comparaba contra tokens en MAYUSCULA
      -- ('PASEO','CALLE','AVDA',...) pero el dato real de produccion viene en
      -- Title Case/mixto -- "Paseo", no "PASEO". Confirmado reproduciendo el
      -- regex exacto en Python contra las 8 muestras reales que paso el
      -- usuario: sensible a mayusculas solo matchea 2/8 (25%, coherente con
      -- el ratio_match=0,112 real medido sobre 500 filas); insensible a
      -- mayusculas matchea 8/8 (100%). Cambio de alcance GENERAL (no solo
      -- DIRECCION): se aplica aqui porque es el UNICO punto del paquete que
      -- genera el SQL dinamico para TODAS las reglas DATA_PATTERN genericas
      -- de todos los identificadores -- consistente con el resto del
      -- paquete, monotono (solo puede sumar matches, nunca quitarlos) y sin
      -- riesgo conocido: ninguna regla DATA_PATTERN existente depende de que
      -- una letra especifica estuviera en mayuscula para distinguir un
      -- significado distinto (verificado una por una en
      -- 03_dm_descubrimiento_carga_reglas.sql).
      -- FIX 2026-10-09 (GCAA_OWN.LOG_SCAREG.MENSAJE, CLOB): dbms_lob.substr(..,4000,1)
      -- devuelve 4000 CARACTERES, pero en SQL el resultado es un VARCHAR2 de maximo
      -- 4000 BYTES; con texto con acentos (UTF-8) lo anterior lanza ORA-06502 y
      -- func_dm_score_patron devolvia 0 en silencio para TODOS los identificadores
      -- (la columna se descartaba sin evidencia de datos). regexp_like acepta CLOB
      -- directamente, asi que se evalua sobre to_clob(<columna>) completo: sin
      -- limite de bytes y sin perder cobertura (antes solo miraba los primeros 4000).
      l_sql := 'select count(*), sum(case when regexp_like(to_clob(' ||
               dbms_assert.enquote_name(p_columna, false) || '), :1, ''i'') then 1 else 0 end) ' ||
               'from (select ' || dbms_assert.enquote_name(p_columna, false) ||
               ' from ' || dbms_assert.enquote_name(p_owner, false) || '.' || dbms_assert.enquote_name(p_tabla, false) ||
               ' where ' || dbms_assert.enquote_name(p_columna, false) || ' is not null and rownum <= :2)';

      execute immediate l_sql into l_rows, l_matches using r.expresion, p_sample_rows;
    end if;

    -- FIX 09/26/26: regla de formato exigente (confianza_min informado y
    -- puntuacion > 0). Se acumula cuantas filas cumplen alguna de ellas.
    if r.es_ = 1 then
      l_hay_   := 1;
      l__rows  := greatest(l__rows, l_rows);
      l__match := greatest(l__match, nvl(l_matches,0));
    end if;

    if l_rows >= least(r.muestra_min, func_dm_normaliza_sample(p_sample_rows)) then
      l_ratio := nvl(l_matches,0) / l_rows;
      if (l_ratio * 100) >= r.confianza_min and l_ratio > 0 then
        l_score := l_score + (r.puntuacion * least(l_ratio,1));
      end if;
    end if;

    p_rows_out  := greatest(nvl(p_rows_out,0), l_rows);
    p_match_out := greatest(nvl(p_match_out,0), l_matches);
    p_ratio_out := greatest(nvl(p_ratio_out,0), l_ratio);
  end loop;

  -- Contradiccion de datos: con >= 10 filas de muestra, ninguna cumple ninguno de
  -- los formatos exigentes del identificador.
  if l_hay_ = 1 and l__rows >= 10 and l__match = 0 then
    p_contra_out := 1;
  end if;

  return l_score;

exception
  when others then
    if l_rc%isopen then
      close l_rc;
    end if;

    -- FIX 09/26/26: antes este handler devolvia 0 en silencio ante
    -- cualquier error (dynamic SQL, regexp_like invalido, etc.), sin dejar
    -- rastro. Ahora se registra en TDM_EJECUCION_ERROR para poder
    -- diagnosticar directamente en vez de tener que reconstruir el
    -- score a mano columna por columna.
    proc_dm_log_error(
      p_ejecucion_id, p_owner, p_tabla, p_columna,
      'SCORE_PATRON:' || p_identificador, sqlcode, sqlerrm
    );

    p_rows_out   := 0;
    p_match_out  := 0;
    p_ratio_out  := 0;
    p_contra_out := 0;
    return 0;
end func_dm_score_patron;

------------------------------------------------------------------------------
-- Ratio de nulos
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_null_ratio_muestra
-- PROPOSITO    : Calcula la proporcion de nulos de una columna sobre una muestra de filas y el numero
--                de filas muestreadas.
-- ENTRADAS     : p_owner, p_tabla, p_columna, p_sample_rows; OUT p_rows_out. Retorna ratio 0..1 (1 si
--                no hay filas, null si falla).
-- LEE          : Tabla de usuario muestreada (SELECT dinamico)
-- ESCRIBE      : ninguno
-- ERRORES      : No levanta ORA-2xxxx; ante error retorna null y p_rows_out null sin registrar nada
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_null_ratio_muestra(
    p_owner       in varchar2,
    p_tabla       in varchar2,
    p_columna     in varchar2,
    p_sample_rows in number,
    p_rows_out    out number
) return number is
  l_sql   varchar2(32767);
  l_rows  number := 0;
  l_nulls number := 0;
begin
  l_sql := 'select count(*), sum(case when ' || dbms_assert.enquote_name(p_columna, false) ||
           ' is null then 1 else 0 end) from (select ' ||
           dbms_assert.enquote_name(p_columna, false) || ' from ' ||
           dbms_assert.enquote_name(p_owner, false) || '.' || dbms_assert.enquote_name(p_tabla, false) ||
           ' where rownum <= :1)';

  execute immediate l_sql into l_rows, l_nulls using p_sample_rows;
  p_rows_out := l_rows;

  if l_rows = 0 then
    return 1;
  end if;

  return nvl(l_nulls,0)/l_rows;
exception
  when others then
    p_rows_out := null;
    return null;
end func_dm_null_ratio_muestra;

------------------------------------------------------------------------------
-- Ratio semántico de nombre completo
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_ratio_nombre_sem
-- PROPOSITO    : Mide que proporcion de la muestra parece nombre de persona (solo letras, sin digitos
--                ni palabras de via) para confirmar columnas de nombre sin apellidos en la tabla.
-- ENTRADAS     : p_owner, p_tabla, p_columna, p_sample_max; OUT p_rows_out, p_match_out. Retorna
--                ratio de coincidencias (0 si no hay filas, null si falla).
-- LEE          : Tabla de usuario muestreada (SELECT dinamico)
-- ESCRIBE      : ninguno
-- ERRORES      : No levanta ORA-2xxxx; ante error retorna null sin registrar nada
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_ratio_nombre_sem(
    p_owner      in varchar2,
    p_tabla      in varchar2,
    p_columna    in varchar2,
    p_sample_max in number,
    p_rows_out   out number,
    p_match_out  out number
) return number is
  l_sql    varchar2(32767);
  l_rows   number;
  l_match  number;
  l_sample number := func_dm_normaliza_sample(p_sample_max);
begin
l_sql :=
    'select count(*), ' ||
    'sum(case ' ||
    '      when (' ||
    '           regexp_like(trim('||dbms_assert.enquote_name(p_columna, false)||'),' ||
    q'[ '^[[:alpha:]ÁÉÍÓÚÜÑÇ][[:alpha:]ÁÉÍÓÚÜÑÇ''-]*([[:space:]]+[[:alpha:]ÁÉÍÓÚÜÑÇ][[:alpha:]ÁÉÍÓÚÜÑÇ''-]*){0,3}$' ]' ||
    ', ''i'') ' ||
    '           or regexp_like(trim('||dbms_assert.enquote_name(p_columna, false)||'),' ||
    q'[ '^[[:alpha:]ÁÉÍÓÚÜÑÇ][[:alpha:]ÁÉÍÓÚÜÑÇ''-]*([[:space:]]+[[:alpha:]ÁÉÍÓÚÜÑÇ][[:alpha:]ÁÉÍÓÚÜÑÇ''-]*)+, [[:space:]]*[[:alpha:]ÁÉÍÓÚÜÑÇ][[:alpha:]ÁÉÍÓÚÜÑÇ''-]*([[:space:]]+[[:alpha:]ÁÉÍÓÚÜÑÇ][[:alpha:]ÁÉÍÓÚÜÑÇ''-]*)*$' ]' ||
    ', ''i'') ' ||
    '          ) ' ||
    '       and not regexp_like('||dbms_assert.enquote_name(p_columna, false)||',''[0-9]'') ' ||
    '       and not regexp_like(upper('||dbms_assert.enquote_name(p_columna, false)||'), ' ||
    q'[ '(^|[[:space:]])(CALLE|C/|AVDA|AVENIDA|PASEO|PLAZA|RONDA|CAMINO|TRAVESIA|TRAVESÍA)([[:space:]]|$)' ]' ||
    ') ' ||
    '      then 1 else 0 end) ' ||
    'from (select '||dbms_assert.enquote_name(p_columna, false)||
    '        from '||dbms_assert.enquote_name(p_owner, false)||'.'||dbms_assert.enquote_name(p_tabla, false)||
    '       where '||dbms_assert.enquote_name(p_columna, false)||' is not null and rownum <= :x)';

  execute immediate l_sql into l_rows, l_match using l_sample;

  p_rows_out  := nvl(l_rows,0);
  p_match_out := nvl(l_match,0);

  if nvl(l_rows,0) = 0 then
    return 0;
  end if;

  return l_match / l_rows;
exception
  when others then
    p_rows_out  := null;
    p_match_out := null;
    return null;
end func_dm_ratio_nombre_sem;

------------------------------------------------------------------------------
-- Clasificación final
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_clasifica
-- PROPOSITO    : Traduce un score total a estado final y marca de enmascarado (>=85 CONFIRMADO/Y,
--                >=65 PROBABLE/Y, >=45
-- ENTRADAS     : p_score; OUT p_estado_out, p_mask_out.
-- LEE          : ninguno
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
procedure proc_dm_clasifica(
    p_score      in number,
    p_estado_out out varchar2,
    p_mask_out   out char
) is
begin
  if p_score >= 85 then
    p_estado_out := 'CONFIRMADO';
    p_mask_out   := 'Y';
  elsif p_score >= 65 then
    p_estado_out := 'PROBABLE';
    p_mask_out   := 'Y';
  elsif p_score >= 45 then
    p_estado_out := 'REVISAR';
    p_mask_out   := 'N';
  else
    p_estado_out := 'DESCARTADO';
    p_mask_out   := 'N';
  end if;
end proc_dm_clasifica;

------------------------------------------------------------------------------
-- Comentario de columna
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_get_col_comment
-- PROPOSITO    : Obtiene el comentario de una columna del diccionario para usarlo como evidencia
--                lexica.
-- ENTRADAS     : p_owner, p_tabla, p_columna. Retorna el comentario o null si no existe.
-- LEE          : DBA_COL_COMMENTS
-- ESCRIBE      : ninguno
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_get_col_comment(
    p_owner   in varchar2,
    p_tabla   in varchar2,
    p_columna in varchar2
) return varchar2 is
  l_comment varchar2(4000);
begin
  select comments
    into l_comment
    from dba_col_comments
   where owner = p_owner
     and table_name = p_tabla
     and column_name = p_columna;

  return l_comment;
exception
  when no_data_found then
    return null;
end func_dm_get_col_comment;

------------------------------------------------------------------------------
-- Valida si la tabla tiene filas
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_tabla_tiene_filas
-- PROPOSITO    : Comprueba si una tabla tiene al menos una fila para omitir las vacias del analisis.
-- ENTRADAS     : p_owner, p_tabla. Retorna 1 si hay filas (o si la consulta falla), 0 si esta vacia.
-- LEE          : Tabla de usuario (SELECT dinamico con rownum = 1)
-- ESCRIBE      : ninguno
-- ERRORES      : No levanta ORA-2xxxx; cualquier error distinto de no_data_found retorna 1 (se asume
--                que tiene filas)
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_tabla_tiene_filas(
    p_owner in varchar2,
    p_tabla in varchar2
) return number is
  l_sql   varchar2(32767);
  l_dummy number;
begin
  l_sql := 'select 1 from ' || dbms_assert.enquote_name(p_owner, false) || '.' || dbms_assert.enquote_name(p_tabla, false)
        || ' where rownum = 1';
  execute immediate l_sql into l_dummy;
  return 1;
exception
  when no_data_found then
    return 0;
  when others then
    return 1;
end func_dm_tabla_tiene_filas;

------------------------------------------------------------------------------
-- Señal de contexto persona
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_tiene_ctx_persona
-- PROPOSITO    : Cuenta columnas de la tabla que indican contexto de persona (apellidos, documento,
--                email, telefono, domicilio).
-- ENTRADAS     : p_owner, p_tabla. Retorna numero de columnas con senal (0 si ninguna o si hay
--                error).
-- LEE          : DBA_TAB_COLUMNS
-- ESCRIBE      : ninguno
-- ERRORES      : No levanta ORA-2xxxx; ante error retorna 0
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_tiene_ctx_persona(
    p_owner in varchar2,
    p_tabla in varchar2
) return number is
  l_cnt number;
begin
  select count(*)
    into l_cnt
    from dba_tab_columns c
   where c.owner = p_owner
     and c.table_name = p_tabla
     and (
       c.column_name in ('APE1','APE2','APELLIDO','APELLIDO1','APELLIDO2','APELLIDOS',
                         'NIF','NIE','DNI','DOCUMENTO','NDOCUMENTO','EMAIL','MAIL',
                         'TFNO','TELEFONO','TELEF','MOVIL','DOMICILIO')
       or c.column_name like '%\_APE1' escape '\'
       or c.column_name like '%\_APE2' escape '\'
       or c.column_name like '%\_APELLIDO' escape '\'
       or c.column_name like '%\_APELLIDO1' escape '\'
       or c.column_name like '%\_APELLIDO2' escape '\'
       or c.column_name like '%\_APELLIDOS' escape '\'
       or c.column_name like '%\_NIF' escape '\'
       or c.column_name like '%\_NIE' escape '\'
       or c.column_name like '%\_DNI' escape '\'
       or c.column_name like '%\_DOCUMENTO' escape '\'
       or c.column_name like '%\_NDOCUMENTO' escape '\'
       or c.column_name like '%\_EMAIL' escape '\'
       or c.column_name like '%\_MAIL' escape '\'
       or c.column_name like '%\_TFNO' escape '\'
       or c.column_name like '%\_TELEF' escape '\'
       or c.column_name like '%\_MOVIL' escape '\'
       or c.column_name like '%\_DOMICILIO' escape '\'
       or c.column_name like 'APE1\_%' escape '\'
       or c.column_name like 'APE2\_%' escape '\'
       or c.column_name like 'APELLIDO\_%' escape '\'
       or c.column_name like 'APELLIDO1\_%' escape '\'
       or c.column_name like 'APELLIDO2\_%' escape '\'
       or c.column_name like 'APELLIDOS\_%' escape '\'
       or c.column_name like 'NIF\_%' escape '\'
       or c.column_name like 'NIE\_%' escape '\'
       or c.column_name like 'DNI\_%' escape '\'
       or c.column_name like 'DOCUMENTO\_%' escape '\'
       or c.column_name like 'NDOCUMENTO\_%' escape '\'
       or c.column_name like 'EMAIL\_%' escape '\'
       or c.column_name like 'MAIL\_%' escape '\'
       or c.column_name like 'TFNO\_%' escape '\'
       or c.column_name like 'TELEF\_%' escape '\'
       or c.column_name like 'MOVIL\_%' escape '\'
       or c.column_name like 'DOMICILIO\_%' escape '\'
     );

  return l_cnt;
exception
  when others then
    return 0;
end func_dm_tiene_ctx_persona;

------------------------------------------------------------------------------
-- Señal : apellidos
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] function func_dm_tiene_apellidos
-- PROPOSITO    : Cuenta columnas de apellidos (APE1, APE2, APELLIDO1/2, APELLIDOS y variantes con
--                prefijo/sufijo) en la tabla.
-- ENTRADAS     : p_owner, p_tabla. Retorna numero de columnas de apellidos (0 si ninguna o si hay
--                error).
-- LEE          : DBA_TAB_COLUMNS
-- ESCRIBE      : ninguno
-- ERRORES      : No levanta ORA-2xxxx; ante error retorna 0
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
function func_dm_tiene_apellidos(
    p_owner in varchar2,
    p_tabla in varchar2
) return number is
  l_cnt number;
begin
  select count(*)
    into l_cnt
    from dba_tab_columns c
   where c.owner = p_owner
     and c.table_name = p_tabla
     and (
       c.column_name in ('APE1','APE2','APELLIDO1','APELLIDO2','APELLIDOS')
       or c.column_name like '%\_APE1' escape '\'
       or c.column_name like '%\_APE2' escape '\'
       or c.column_name like '%\_APELLIDO1' escape '\'
       or c.column_name like '%\_APELLIDO2' escape '\'
       or c.column_name like '%\_APELLIDOS' escape '\'
       or c.column_name like 'APE1\_%' escape '\'
       or c.column_name like 'APE2\_%' escape '\'
       or c.column_name like 'APELLIDO1\_%' escape '\'
       or c.column_name like 'APELLIDO2\_%' escape '\'
       or c.column_name like 'APELLIDOS\_%' escape '\'
     );

  return l_cnt;
exception
  when others then
    return 0;
end func_dm_tiene_apellidos;

------------------------------------------------------------------------------
-- Recolecta dependencias
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_recolecta_dep
-- PROPOSITO    : Registra en TDM_DEPENDENCIA_HIST las constraints (P/R/U/C) de la columna
--                enmascarable y los triggers de su tabla.
-- ENTRADAS     : p_ejecucion_id, p_owner, p_tabla, p_columna. Sin OUT.
-- LEE          : DBA_CONS_COLUMNS; DBA_CONSTRAINTS; DBA_TRIGGERS
-- ESCRIBE      : TDM_DEPENDENCIA_HIST (INSERT)
-- ERRORES      : No levanta ORA-2xxxx; cualquier error se registra con etapa DEPENDENCIAS y se
--                continua
-- LLAMADO DESDE: proc_dm_procesa_desc (solo para columnas con enmascarar = Y)
------------------------------------------------------------------------------
procedure proc_dm_recolecta_dep(
    p_ejecucion_id in number,
    p_owner        in varchar2,
    p_tabla        in varchar2,
    p_columna      in varchar2
) is
begin
  insert into tdm_dependencia_hist(
    dependencia_id, ejecucion_id, ora_owner, table_name, column_name,
    tipo_dependencia, dependencia_owner, dependencia_objeto, detalle
  )
  select seq_dm_dependencia_hist.nextval, p_ejecucion_id, p_owner, p_tabla, p_columna,
         case when c.constraint_type = 'R' then 'FK' else 'CONSTRAINT' end,
         c.owner,
         c.constraint_name,
         'Constraint/FK sobre columna'
    from dba_cons_columns cc
    join dba_constraints c
      on c.owner = cc.owner
     and c.constraint_name = cc.constraint_name
   where cc.owner = p_owner
     and cc.table_name = p_tabla
     and cc.column_name = p_columna
     and c.constraint_type in ('P','R','U','C');

  insert into tdm_dependencia_hist(
    dependencia_id, ejecucion_id, ora_owner, table_name, column_name,
    tipo_dependencia, dependencia_owner, dependencia_objeto, detalle
  )
  select seq_dm_dependencia_hist.nextval, p_ejecucion_id, p_owner, p_tabla, p_columna,
         'TRIGGER', t.owner, t.trigger_name,
         'Trigger asociado a la tabla'
    from dba_triggers t
   where t.table_owner = p_owner
     and t.table_name = p_tabla;

exception
  when others then
    proc_dm_log_error(p_ejecucion_id, p_owner, p_tabla, p_columna, 'DEPENDENCIAS', sqlcode, sqlerrm);
end proc_dm_recolecta_dep;

------------------------------------------------------------------------------
-- Excepción manual
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_aplica_excepcion
-- PROPOSITO    : Aplica la excepcion manual vigente (EXCLUDE o FORCE) de TDM_EXCEPCION_COL a una
--                columna modificando identificador, score y marca.
-- ENTRADAS     : p_ejecucion_id, p_owner, p_tabla, p_columna; IN OUT p_identificador, p_score_total,
--                p_forzar_mask. EXCLUDE: score -999 y mask N. FORCE: identificador forzado, score
--                minimo 95 y mask Y.
-- LEE          : TDM_EXCEPCION_COL
-- ESCRIBE      : Indirecto: TDM_EJECUCION_ERROR / TDM_MASK_TRACE via proc_dm_log_error
-- ERRORES      : No levanta ORA-2xxxx; too_many_rows y otros errores se registran con etapa
--                APLICA_EXCEPCION y la columna sigue sin modificar; Sin excepcion activa: no hace
--                nada
-- LLAMADO DESDE: proc_dm_procesa_desc (2 llamadas: lineas 2379 y 2420)
------------------------------------------------------------------------------
procedure proc_dm_aplica_excepcion(
    p_ejecucion_id  in number,
    p_owner         in varchar2,
    p_tabla         in varchar2,
    p_columna       in varchar2,
    p_identificador in out nocopy varchar2,
    p_score_total   in out nocopy number,
    p_forzar_mask   in out nocopy char
) is
  l_accion        tdm_excepcion_col.accion%type;
  l_ident_forzado tdm_excepcion_col.identificador_forz%type;
begin
  -- 2026-09-22: se agrega ROWNUM=1 (y WHEN OTHERS defensivo). Confirmado en
  -- produccion (SRI2006.TMP_LIQUIDACION_MENSUAL.NIF, via dm_tabref.sql) que
  -- TDM_EXCEPCION_COL puede tener MAS de una fila activa='Y' para el mismo
  -- ora_owner+table_name+column_name a pesar de que su PK declarada es
  -- justo esa combinacion -- indica que la PK esta deshabilitada/NOVALIDATE
  -- o hay drift de datos historico (mismo patron de drift ya visto con
  -- dominio/solicitud_id el 20/09). Sin este fix, esa fila dispara
  -- ORA-01422 (TOO_MANY_ROWS) aqui; el llamador (proc_dm_procesa_desc) SI
  -- atrapa WHEN OTHERS por columna y sigue con la siguiente (no aborta el
  -- descubrimiento completo), pero esta columna especifica queda sin
  -- clasificar (se pierde la excepcion Y CUALQUIER score de esa columna,
  -- registrado solo como error PROCESA_COLUMNA en tdm_ejecucion_error, sin
  -- ninguna senal en el resumen normal). proc_dm_get_excepcion (05, ruta de
  -- enmascarado) ya tenia este mismo guard -- este fix solo alinea 04 con
  -- ese patron ya existente. Con ROWNUM=1 el comportamiento pasa a ser "no
  -- fatal, toma una fila de forma no determinista" en vez de "columna
  -- saltada silenciosamente" -- de cualquier forma, la causa raiz (filas
  -- duplicadas en TDM_EXCEPCION_COL) debe limpiarse en los datos, no solo
  -- en el codigo.
  select accion, identificador_forz
    into l_accion, l_ident_forzado
    from tdm_excepcion_col
   where ora_owner = p_owner
     and table_name = p_tabla
     and column_name = p_columna
     and activa = 'Y'
     and rownum = 1;

  if l_accion = 'EXCLUDE' then
    p_score_total := -999;
    p_forzar_mask := 'N';
  elsif l_accion = 'FORCE' then
    p_identificador := nvl(l_ident_forzado, p_identificador);
    p_score_total := greatest(p_score_total, 95);
    p_forzar_mask := 'Y';
  end if;
exception
  when no_data_found then
    null;
  when too_many_rows then
    -- no deberia ocurrir con rownum=1, pero si el optimizador cambia el
    -- plan de acceso y esta excepcion reaparece, se registra en vez de
    -- perderse silenciosamente (ver comentario 2026-09-22 arriba).
    proc_dm_log_error(p_ejecucion_id, p_owner, p_tabla, p_columna, 'APLICA_EXCEPCION', sqlcode, sqlerrm);
  when others then
    -- FIX 09/27/26: antes era NULL silencioso -- si TDM_EXCEPCION_COL tiene
    -- un problema (p.ej. corrupcion, permisos, drift de estructura), la
    -- columna se procesaba como si NO tuviera excepcion activa, sin dejar
    -- rastro alguno. Ahora se registra el error (autonomo, no aborta el
    -- descubrimiento) y se continua con p_identificador/p_score_total/
    -- p_forzar_mask sin modificar, igual que antes.
    proc_dm_log_error(p_ejecucion_id, p_owner, p_tabla, p_columna, 'APLICA_EXCEPCION', sqlcode, sqlerrm);
end proc_dm_aplica_excepcion;

------------------------------------------------------------------------------
-- Prepara objetos
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_prepara_objetos
-- PROPOSITO    : Sincroniza TDM_OBJETO_CTRL con las tablas actuales del esquema dentro del alcance,
--                marca PENDIENTE las nuevas o modificadas y fija los totales de la ejecucion.
-- ENTRADAS     : p_esquema, p_ejecucion_id, p_forzar_full ('Y' = todo a PENDIENTE). Sin OUT.
-- LEE          : DBA_OBJECTS; DBA_TABLES; DBA_TAB_COLUMNS; TDM_EJECUCION_SCOPE; TDM_OBJETO_CTRL
-- ESCRIBE      : TDM_OBJETO_CTRL (UPDATE/INSERT); TDM_EJECUCION (tablas_total, columnas_total,
--                ultimo_paso)
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_descubrimiento_core
------------------------------------------------------------------------------
procedure proc_dm_prepara_objetos(
    p_esquema      in varchar2,
    p_ejecucion_id in number,
    p_forzar_full  in char
) is
begin
  for t in (
    select o.owner, o.object_name table_name, o.object_id, o.last_ddl_time,
           (select count(*) from dba_tab_columns c where c.owner = o.owner and c.table_name = o.object_name) column_count
      from dba_objects o
      join dba_tables tb
        on tb.owner = o.owner
       and tb.table_name = o.object_name
     where o.owner = upper(p_esquema)
       and o.object_type = 'TABLE'
       and tb.temporary = 'N'
       and (
         not exists (
           select 1
             from tdm_ejecucion_scope sc
            where sc.ejecucion_id = p_ejecucion_id
              and sc.ora_owner = upper(p_esquema)
         )
         or exists (
           select 1
             from tdm_ejecucion_scope sc
            where sc.ejecucion_id = p_ejecucion_id
              and sc.ora_owner = upper(p_esquema)
              and sc.table_name in ('*', o.object_name)
         )
       )
  ) loop
    update tdm_objeto_ctrl dc
       set dc.object_id = t.object_id,
           dc.last_ddl_time = t.last_ddl_time,
           dc.column_count = t.column_count,
           dc.firma_txt = t.owner || '|' || t.table_name || '|' || t.last_ddl_time || '|' || t.column_count,
           dc.estado_objeto = case
                                when dc.motivo_estado = 'TABLA_TECNICA_SISTEMA' then 'PENDIENTE' -- reactiva tablas omitidas por nombre en versiones anteriores
                                when p_forzar_full = 'Y' then 'PENDIENTE'
                                when dc.last_ddl_time != t.last_ddl_time or nvl(dc.column_count,-1) != nvl(t.column_count,-1) then 'PENDIENTE'
                                else dc.estado_objeto
                              end,
           dc.motivo_estado = null
     where dc.ora_owner = t.owner
       and dc.table_name = t.table_name;

    if sql%rowcount = 0 then
      insert into tdm_objeto_ctrl(
        ora_owner, table_name, object_id, last_ddl_time, column_count,
        firma_txt, ultimo_run_id, estado_objeto, motivo_estado
      ) values (
        t.owner, t.table_name, t.object_id, t.last_ddl_time, t.column_count,
        t.owner || '|' || t.table_name || '|' || t.last_ddl_time || '|' || t.column_count,
        null,
        'PENDIENTE',
        null
      );
    end if;
  end loop;

  update tdm_ejecucion e
     set tablas_total = (
           select count(*)
             from tdm_objeto_ctrl dc
            where dc.ora_owner = upper(p_esquema)
              and dc.estado_objeto = 'PENDIENTE'
              and (
                not exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.ora_owner = upper(p_esquema))
                or exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.ora_owner = upper(p_esquema) and sc.table_name in ('*', dc.table_name))
              )
         ),
         columnas_total = (
           select nvl(sum(dc.column_count),0)
             from tdm_objeto_ctrl dc
            where dc.ora_owner = upper(p_esquema)
              and dc.estado_objeto = 'PENDIENTE'
              and (
                not exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.ora_owner = upper(p_esquema))
                or exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.ora_owner = upper(p_esquema) and sc.table_name in ('*', dc.table_name))
              )
         ),
         ultimo_paso = 'OBJETOS_PREPARADOS'
   where e.ejecucion_id = p_ejecucion_id;

  commit;
end proc_dm_prepara_objetos;

------------------------------------------------------------------------------
-- Resolvedor de componentes conexos por FK (Union-Find)
-- Propaga enmascarar = 'Y', identificador y dominio compartido a todo el grupo conexo.
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_propaga_dominios
-- PROPOSITO    : Agrupa columnas conectadas por claves foraneas (Union-Find) y propaga a todo el
--                grupo la marca enmascarar = Y, el identificador de mayor prioridad y un dominio
--                comun en TDM_COLUMNA_FINAL.
-- ENTRADAS     : p_esquema, p_solicitud_id (opcional, solo traza), p_ejecucion_id (opcional, solo
--                traza). Sin OUT.
-- LEE          : TDM_COLUMNA_FINAL; DBA_CONSTRAINTS; DBA_CONS_COLUMNS
-- ESCRIBE      : TDM_COLUMNA_FINAL (MERGE: enmascarar = Y, identificador, dominio); Indirecto:
--                TDM_MASK_TRACE via pkg_dm_trazabilidad.proc_dm_trace (evento RI_REINCLUYE)
-- ERRORES      : No levanta ORA-2xxxx; los fallos al trazar se ignoran
-- LLAMADO DESDE: proc_dm_sync_col_final; pkg_dm_enmascarar en 05_dm_pkg_enmascarar.sql linea 3316
------------------------------------------------------------------------------
procedure proc_dm_propaga_dominios(
    p_esquema      in varchar2,
    p_solicitud_id in number default null,
    p_ejecucion_id in number default null
) is
  type t_node is record (
    parent_node   varchar2(500),
    identificador varchar2(50),
    enmascarar    char(1)
  );
  type t_node_map is table of t_node index by varchar2(500);
  l_nodes t_node_map;

  type t_component is record (
    has_enmascarar char(1) := 'N',
    identificador  varchar2(50) := null,
    min_node       varchar2(500) := null
  );
  type t_comp_map is table of t_component index by varchar2(500);
  l_comps t_comp_map;

  l_esquema varchar2(128) := upper(trim(p_esquema));
  l_key     varchar2(500);
  l_root    varchar2(500);
  l_own     varchar2(128);
  l_tab     varchar2(128);
  l_col     varchar2(128);
  l_first_dot  number;
  l_second_dot number;

  -- Union-Find Find
  function find_root(p_node in varchar2) return varchar2 is
    l_curr varchar2(500) := p_node;
  BEGIN
    if not l_nodes.exists(l_curr) then
      l_nodes(l_curr).parent_node := l_curr;
      l_nodes(l_curr).enmascarar  := 'N';
      l_nodes(l_curr).identificador := null;
      return l_curr;
    end if;

    while l_nodes(l_curr).parent_node <> l_curr loop
      l_curr := l_nodes(l_curr).parent_node;
    end loop;
    return l_curr;
  END;

  -- Union-Find Union
  procedure union_nodes(p_node1 in varchar2, p_node2 in varchar2) is
    l_r1 varchar2(500) := find_root(p_node1);
    l_r2 varchar2(500) := find_root(p_node2);
  BEGIN
    if l_r1 <> l_r2 then
      l_nodes(l_r1).parent_node := l_r2;
    end if;
  END;

  -- Ranking de prioridad de identificadores para dominios referenciales (menor ranking = mayor especificidad/prioridad)
  function f_rank_ident(p_ident in varchar2) return number is
  begin
    return case upper(trim(p_ident))
             when 'IDENTIFICADOR_IDENTIDAD'  then 10
             when 'IDENTIFICADOR_DOCUMENTO'  then 10
             when 'IDENTIFICADOR_IBAN'       then 20
             when 'IDENTIFICADOR_BANCARIO'   then 20
             when 'IDENTIFICADOR_PERSONAL'   then 50
             else 90
           end;
  end;

begin
  -- 1) Cargar nodos iniciales desde tdm_columna_final
  for rc in (
    select ora_owner, table_name, column_name, identificador, enmascarar
      from tdm_columna_final
     where ora_owner = l_esquema
  ) loop
    l_key := rc.ora_owner||'.'||rc.table_name||'.'||rc.column_name;
    l_nodes(l_key).parent_node := l_key;
    l_nodes(l_key).identificador := rc.identificador;
    l_nodes(l_key).enmascarar := nvl(rc.enmascarar,'N');
  end loop;

  -- 2) Cargar relaciones FK y hacer UNION de nodos
  for fk in (
    select cc_c.owner  child_owner,  cc_c.table_name child_table,  cc_c.column_name child_col,
           cc_p.owner  parent_owner, cc_p.table_name parent_table, cc_p.column_name parent_col
      from dba_constraints  c
      join dba_cons_columns cc_c on cc_c.owner = c.owner    and cc_c.constraint_name   = c.constraint_name
      join dba_cons_columns cc_p on cc_p.owner = c.r_owner  and cc_p.constraint_name   = c.r_constraint_name
                                and cc_p.position = cc_c.position
     where c.constraint_type = 'R'
       and c.owner = l_esquema
  ) loop
    union_nodes(
      fk.child_owner||'.'||fk.child_table||'.'||fk.child_col,
      fk.parent_owner||'.'||fk.parent_table||'.'||fk.parent_col
    );
  end loop;

  -- 3) Agrupar y resolver propiedades del componente (has_enmascarar, identificador por ranking, nodo mínimo)
  l_key := l_nodes.first;
  while l_key is not null loop
    l_root := find_root(l_key);
    
    -- Inicializar l_comps(l_root) de forma segura para evitar ORA-01403
    if not l_comps.exists(l_root) then
      l_comps(l_root).has_enmascarar := 'N';
      l_comps(l_root).identificador  := null;
      l_comps(l_root).min_node       := null;
    end if;

    if l_nodes(l_key).enmascarar = 'Y' then
      l_comps(l_root).has_enmascarar := 'Y';
    end if;

    if l_nodes(l_key).identificador is not null then
      if l_comps(l_root).identificador is null
         or f_rank_ident(l_nodes(l_key).identificador) < f_rank_ident(l_comps(l_root).identificador) then
        l_comps(l_root).identificador := l_nodes(l_key).identificador;
      end if;
    end if;

    -- M-1: Resolver nombre de dominio lexicográficamente menor de forma estable
    if l_comps(l_root).min_node is null or l_key < l_comps(l_root).min_node then
      l_comps(l_root).min_node := l_key;
    end if;

    l_key := l_nodes.next(l_key);
  end loop;

  -- 4) Propagar resultados y persistir dominio en tdm_columna_final (forzar homogeneidad determinista)
  l_key := l_nodes.first;
  while l_key is not null loop
    l_root := find_root(l_key);
    
    if l_comps.exists(l_root) and l_comps(l_root).has_enmascarar = 'Y' then
      l_first_dot  := instr(l_key, '.');
      l_second_dot := instr(l_key, '.', 1, 2);
      l_own := substr(l_key, 1, l_first_dot - 1);
      l_tab := substr(l_key, l_first_dot + 1, l_second_dot - l_first_dot - 1);
      l_col := substr(l_key, l_second_dot + 1);

      -- A.2: Traza dinámica de re-inclusión de columnas por integridad referencial
      declare
        l_curr_enm varchar2(1) := null;
      begin
        select enmascarar into l_curr_enm
          from tdm_columna_final
         where ora_owner = l_own
           and table_name = l_tab
           and column_name = l_col;

        if l_curr_enm = 'N' then
          -- 2026-09-16: llamada ESTATICA a pkg_dm_trazabilidad. Antes era un
          -- EXECUTE IMMEDIATE a pkg_dm_enmascarar.proc_dm_trace porque 04
          -- compila antes que 05 en el orden de instalacion y una referencia
          -- estatica a un paquete que aun no existe no habria compilado.
          -- pkg_dm_trazabilidad no tiene esa restriccion (compila justo
          -- despues de las tablas, antes que 04) - ver su cabecera.
          begin
            pkg_dm_trazabilidad.proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'RI_REINCLUYE',
              l_own||'.'||l_tab||'.'||l_col||' re-incluida (Y) por integridad referencial del dominio '||l_comps(l_root).min_node
            );
          exception
            when others then null;
          end;
        end if;
      exception
        when others then null;
      end;

      merge into tdm_columna_final u
      using (
        select l_own as ora_owner,
               l_tab as table_name,
               l_col as column_name,
               l_comps(l_root).identificador as identificador,
               case when upper(trim(l_comps(l_root).identificador)) = 'IDENTIFICADOR_OBS' then null else l_comps(l_root).min_node end as dominio
          from dual
      ) h
      on (u.ora_owner = h.ora_owner and u.table_name = h.table_name and u.column_name = h.column_name)
      when matched then
        update set u.enmascarar = 'Y',
                   u.identificador = h.identificador, -- Forzar el identificador de mayor prioridad en todo el componente
                   u.dominio = h.dominio
      when not matched then
        insert (ora_owner, table_name, column_name, identificador, enmascarar, dominio)
        values (h.ora_owner, h.table_name, h.column_name, h.identificador, 'Y', h.dominio);
    end if;

    l_key := l_nodes.next(l_key);
  end loop;
end proc_dm_propaga_dominios;

------------------------------------------------------------------------------
-- Sync catálogo final
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_sync_col_final
-- PROPOSITO    : Sincroniza TDM_COLUMNA_FINAL con lo descubierto en TDM_COLUMNA_HIST de la ejecucion,
--                retira columnas obsoletas y propaga dominios por FK.
-- ENTRADAS     : p_ejecucion_id. Sin OUT.
-- LEE          : TDM_COLUMNA_HIST; TDM_EJECUCION; TDM_OBJETO_CTRL; DBA_TAB_COLUMNS; TDM_COLUMNA_FINAL
-- ESCRIBE      : TDM_COLUMNA_FINAL (MERGE, DELETE e inserciones/updates via
--                proc_dm_propaga_dominios); Indirecto: TDM_MASK_TRACE (FINAL_OBSOLETAS,
--                FINAL_OBSOLETAS_ERR, PROPAGA_DOMINIOS_ERR)
-- ERRORES      : Errores del bloque de obsoletas y de la propagacion se trazan y se ignoran; el MERGE
--                y el DELETE iniciales no tienen handler y propagan el error
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
procedure proc_dm_sync_col_final(
    p_ejecucion_id in number
) is
begin
  merge into tdm_columna_final u
  using (
    select ora_owner, table_name, column_name, identificador, enmascarar
      from tdm_columna_hist
     where ejecucion_id = p_ejecucion_id
       and enmascarar = 'Y'
  ) h
     on (u.ora_owner = h.ora_owner and u.table_name = h.table_name and u.column_name = h.column_name)
  when matched then
    update set u.identificador = h.identificador,
               u.enmascarar    = h.enmascarar
  when not matched then
    insert (ora_owner, table_name, column_name, identificador, enmascarar)
    values (h.ora_owner, h.table_name, h.column_name, h.identificador, h.enmascarar);

  delete from tdm_columna_final u
   where exists (
         select 1
           from tdm_columna_hist h
          where h.ejecucion_id = p_ejecucion_id
            and h.ora_owner = u.ora_owner
            and h.table_name = u.table_name
            and h.column_name = u.column_name
            and nvl(h.enmascarar,'N') <> 'Y'
   );

  -- FIX 2026-10-09 (hallazgo real GCAA_OWN, ejecucion 2): el DELETE de arriba solo
  -- retira de TDM_COLUMNA_FINAL las columnas que ESTA ejecucion dejo en
  -- TDM_COLUMNA_HIST con enmascarar<>'Y'. Una columna que antes era Y y ahora no
  -- tiene evidencia (se ajusto una regla, cambio el dato) ya no se escribe en HIST,
  -- asi que su fila Y antigua sobrevivia para siempre y se enmascaraba igual
  -- (DIRECCION_IP_CAMBIO seguia en FINAL tras descartarla la regla nueva). Igual
  -- las columnas de tablas ya borradas. Se retira de FINAL toda columna que:
  --   a) pertenece a una tabla ANALIZADA en esta ejecucion (PROCESADO con
  --      ultimo_run_id = esta ejecucion: las no analizadas por alcance/modo no
  --      se tocan) y no quedo Y en el HIST de esta ejecucion, o
  --   b) ya no existe en el diccionario (columna o tabla borrada).
  -- Va ANTES de proc_dm_propaga_dominios: la integridad referencial re-incluye
  -- despues (RI_REINCLUYE) las columnas hijas que correspondan.
  declare
    l_esq_sync varchar2(128);
    l_borradas number;
  begin
    select upper(ora_esquema) into l_esq_sync
      from tdm_ejecucion
     where ejecucion_id = p_ejecucion_id;

    delete from tdm_columna_final u
     where u.ora_owner = l_esq_sync
       and (
             (exists (select 1 from tdm_objeto_ctrl o
                       where o.ora_owner    = u.ora_owner
                         and o.table_name    = u.table_name
                         and o.estado_objeto = 'PROCESADO'
                         and o.ultimo_run_id = p_ejecucion_id)
              and not exists (select 1 from tdm_columna_hist h
                               where h.ejecucion_id = p_ejecucion_id
                                 and h.ora_owner   = u.ora_owner
                                 and h.table_name   = u.table_name
                                 and h.column_name  = u.column_name
                                 and h.enmascarar   = 'Y'))
          or not exists (select 1 from dba_tab_columns d
                          where d.owner       = u.ora_owner
                            and d.table_name  = u.table_name
                            and d.column_name = u.column_name)
           );
    l_borradas := sql%rowcount;
    if l_borradas > 0 then
      pkg_dm_trazabilidad.proc_dm_trace(
        NULL, p_ejecucion_id, 'DESCUBRIMIENTO', 'FINAL_OBSOLETAS',
        'Retiradas de TDM_COLUMNA_FINAL '||l_borradas||' columnas que ya no cumplen el descubrimiento de esta ejecucion o ya no existen en el diccionario'
      );
    end if;
  exception
    when others then
      begin
        pkg_dm_trazabilidad.proc_dm_trace(
          NULL, p_ejecucion_id, 'DESCUBRIMIENTO', 'FINAL_OBSOLETAS_ERR', substr(sqlerrm,1,500)
        );
      exception when others then null;
      end;
  end;

  -- Resolver componentes conexos por FK y propagar dominios lógicos
  declare
    l_esquema varchar2(128);
  begin
    select ora_esquema into l_esquema
      from tdm_ejecucion
     where ejecucion_id = p_ejecucion_id;
    proc_dm_propaga_dominios(l_esquema);
  exception
    when others then
      -- R3: No silenciar el fallo de propagación en la sincronización del catálogo
      -- 2026-09-16: llamada estatica a pkg_dm_trazabilidad (ver nota arriba);
      -- ya no hace falta el EXECUTE IMMEDIATE ni el comentario de "si
      -- pkg_dm_enmascarar no esta compilado" - pkg_dm_trazabilidad siempre
      -- esta disponible en este punto del install.
      begin
        pkg_dm_trazabilidad.proc_dm_trace(
          NULL, p_ejecucion_id, 'DESCUBRIMIENTO', 'PROPAGA_DOMINIOS_ERR',
          'Fallo propagando dominios FK para '||l_esquema||': '||sqlerrm
        );
      exception
        when others then null;
      end;
  end;
end proc_dm_sync_col_final;

------------------------------------------------------------------------------
-- Sync dependencias final
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_sync_dep_final
-- PROPOSITO    : Consolida TDM_DEPENDENCIA_HIST de la ejecucion en TDM_DEPENDENCIA_FINAL con la
--                categoria de uso y las acciones pre y post enmascarado (DISABLE/ENABLE segun estado
--                actual).
-- ENTRADAS     : p_ejecucion_id. Sin OUT.
-- LEE          : TDM_DEPENDENCIA_HIST; DBA_CONSTRAINTS; DBA_TRIGGERS
-- ESCRIBE      : TDM_DEPENDENCIA_FINAL (MERGE)
-- ERRORES      : ninguno
-- LLAMADO DESDE: proc_dm_procesa_desc
------------------------------------------------------------------------------
procedure proc_dm_sync_dep_final(
    p_ejecucion_id in number
) is
begin
  merge into tdm_dependencia_final u
  using (
    with dep_base as (
      select ora_owner,
             table_name,
             column_name,
             tipo_dependencia,
             nvl(dependencia_owner,'-') dependencia_owner,
             nvl(dependencia_objeto,'-') dependencia_objeto,
             max(detalle) detalle
        from tdm_dependencia_hist
       where ejecucion_id = p_ejecucion_id
         and tipo_dependencia in ('FK','CONSTRAINT','TRIGGER')
       group by ora_owner, table_name, column_name, tipo_dependencia,
                nvl(dependencia_owner,'-'), nvl(dependencia_objeto,'-')
    )
    select b.ora_owner,
           b.table_name,
           b.column_name,
           b.tipo_dependencia,
           b.dependencia_owner,
           b.dependencia_objeto,
           case
             when upper(trim(b.tipo_dependencia)) in ('FK','CONSTRAINT','R','FOREIGN KEY')
               then 'INTEGRIDAD'
             when upper(trim(b.tipo_dependencia)) in ('PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE')
               then 'INTEGRIDAD'
             else 'OPERATIVA'
           end categoria_uso,
           case
             when upper(trim(b.tipo_dependencia)) in ('FK','CONSTRAINT','R','FOREIGN KEY')
               then case when nvl(c.status,'ENABLED') = 'ENABLED' then 'DISABLE' else 'SIN_ACCION' end
             when upper(trim(b.tipo_dependencia)) = 'TRIGGER'
               then case when nvl(t.status,'ENABLED') = 'ENABLED' then 'DISABLE' else 'SIN_ACCION' end
             when upper(trim(b.tipo_dependencia)) in ('PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE')
               then 'SOLO_INFORMATIVO'
             else 'SOLO_INFORMATIVO'
           end accion_pre_mask,
           case
             when upper(trim(b.tipo_dependencia)) in ('FK','CONSTRAINT','R','FOREIGN KEY')
               then case when nvl(c.status,'ENABLED') = 'ENABLED' then 'ENABLE_NOVALIDATE' else 'SIN_ACCION' end
             when upper(trim(b.tipo_dependencia)) = 'TRIGGER'
               then case when nvl(t.status,'ENABLED') = 'ENABLED' then 'ENABLE' else 'SIN_ACCION' end
             when upper(trim(b.tipo_dependencia)) in ('PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE')
               then 'REVISAR'
             else 'SIN_ACCION'
           end accion_post_mask,
           b.detalle
      from dep_base b
      left join dba_constraints c
        on upper(trim(b.tipo_dependencia)) in ('FK','CONSTRAINT','R','FOREIGN KEY')
       and c.owner = b.dependencia_owner
       and c.constraint_name = b.dependencia_objeto
      left join dba_triggers t
        on upper(trim(b.tipo_dependencia)) = 'TRIGGER'
       and t.owner = b.dependencia_owner
       and t.trigger_name = b.dependencia_objeto
  ) d
     on (u.ora_owner = d.ora_owner
         and u.table_name = d.table_name
         and u.column_name = d.column_name
         and u.tipo_dependencia = d.tipo_dependencia
         and nvl(u.dependencia_owner,'-') = d.dependencia_owner
         and nvl(u.dependencia_objeto,'-') = d.dependencia_objeto)
  when matched then
    update set u.categoria_uso    = d.categoria_uso,
               u.accion_pre_mask  = d.accion_pre_mask,
               u.accion_post_mask = d.accion_post_mask,
               u.detalle          = d.detalle
  when not matched then
    insert (
      ora_owner, table_name, column_name, tipo_dependencia,
      dependencia_owner, dependencia_objeto,
      categoria_uso, accion_pre_mask, accion_post_mask, detalle
    )
    values (
      d.ora_owner, d.table_name, d.column_name, d.tipo_dependencia,
      d.dependencia_owner, d.dependencia_objeto,
      d.categoria_uso, d.accion_pre_mask, d.accion_post_mask, d.detalle
    );
end proc_dm_sync_dep_final;

------------------------------------------------------------------------------
-- PROCESO CENTRAL
-- Ajuste importante:
-- 1) si no hay evidencia mínima, la columna NO se inserta en histórico
-- 2) si sí hay evidencia, el identificador nunca queda NULL
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_procesa_desc
-- PROPOSITO    : Motor central del descubrimiento: recorre las tablas PENDIENTE, puntua cada columna
--                candidata, clasifica, guarda el historico, sincroniza las tablas FINAL y cierra la
--                ejecucion.
-- ENTRADAS     : p_ejecucion_id, p_sample_rows, p_commit_lote (columnas por commit). Sin OUT; deja la
--                ejecucion en FINALIZADO o ERROR.
-- LEE          : TDM_EJECUCION; TDM_OBJETO_CTRL; TDM_EJECUCION_SCOPE; TDM_REGLA; DBA_TAB_COLUMNS;
--                DBA_COL_COMMENTS (via func_dm_get_col_comment); Tablas de usuario (muestreo)
-- ESCRIBE      : TDM_EJECUCION (estado, progreso, heartbeat, fecha_fin); TDM_OBJETO_CTRL;
--                TDM_COLUMNA_HIST (DELETE+INSERT); TDM_DEPENDENCIA_HIST (DELETE+INSERT);
--                TDM_COLUMNA_FINAL y TDM_DEPENDENCIA_FINAL (via sync); TDM_EJECUCION_ERROR /
--                TDM_MASK_TRACE (via trazabilidad)
-- ERRORES      : ORA-20010 si la ejecucion no esta en EJECUTANDO/PAUSADO; Error por columna: se
--                registra PROCESA_COLUMNA y continua con la siguiente; Error general: registra
--                PROCESO_GENERAL, marca la ejecucion en ERROR (ERROR_FATAL) y re-lanza; Si la
--                ejecucion pasa a CANCELADO/ABORTADA hace RETURN silencioso entre tablas
-- LLAMADO DESDE: proc_dm_descubrimiento_core; proc_dm_reanudar
------------------------------------------------------------------------------
procedure proc_dm_procesa_desc(
    p_ejecucion_id in number,
    p_sample_rows  in number,
    p_commit_lote  in number
) is
  l_esquema           tdm_ejecucion.ora_esquema%type;
  l_estado            tdm_ejecucion.estado%type;
  l_cols_lote         number := 0;
  l_run_t0            timestamp with time zone := systimestamp;   -- traza: duracion de la corrida
  l_tot_omit          number := 0;                                -- traza: tablas sin filas omitidas
  l_tab_cols          number := 0;                                -- traza: columnas evaluadas en la tabla
  l_tab_y             number := 0;                                -- traza: columnas marcadas Y en la tabla
  l_tot_tabs          number := 0;
  l_tot_cols          number := 0;
  l_tot_y             number := 0;
  l_comment           varchar2(4000);
  l_best_id           varchar2(50);
  l_best_score        number;
  l_best_patron       number; -- FIX 09/26/26: desempate por evidencia de datos
  l_alt_id            varchar2(50);  -- FIX 10/09/26: mejor candidato con evidencia aunque su total sea <= 0
  l_alt_total         number;
  l_sin_pos           boolean;
  l_score_nombre      number;
  l_score_coment      number;
  l_score_patron      number;
  l_score_tabla       number;
  l_score_total       number;
  l_rows              number;
  l_matches           number;
  l_ratio             number;
  l_null_ratio        number;
  l_rows_total        number;
  l_sem_rows          number;
  l_sem_matches       number;
  l_ratio_semantica   number;
  l_motivo_descarte   varchar2(2000);
  l_estado_final      varchar2(20);
  l_enmascarar        char(1);
  l_force_mask        char(1);
  l_ctx_persona       number;
  l_ctx_persona_tab   number := 0;
  l_ctx_apellidos_tab number := 0;
  l_tiene_evidencia   number := 0;
  l_contra            number := 0; -- FIX 09/26/26: 1 = el dato contradice el formato exigido
  l_fx_id             varchar2(50);  -- FIX 2026-10-07: FORCE sobre columna sin evidencia
  l_fx_score          number;
  l_fx_mask           char(1);
begin
  select ora_esquema, estado
    into l_esquema, l_estado
    from tdm_ejecucion
   where ejecucion_id = p_ejecucion_id
   for update;

  if l_estado not in ('EJECUTANDO','PAUSADO') then
    raise_application_error(-20010, 'La ejecución no está disponible para procesar');
  end if;

  update tdm_ejecucion
     set estado = 'EJECUTANDO',
         fase_proceso = 'DESCUBRIMIENTO',
         ultimo_paso = 'PROCESANDO_TABLAS',
         heartbeat_ts = systimestamp
   where ejecucion_id = p_ejecucion_id;

  commit;

  for t in (
    select tctl.ora_owner, tctl.table_name
      from tdm_objeto_ctrl tctl
     where tctl.ora_owner = l_esquema
       and tctl.estado_objeto = 'PENDIENTE'
       and (
         not exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.ora_owner = l_esquema)
         or exists (select 1 from tdm_ejecucion_scope sc where sc.ejecucion_id = p_ejecucion_id and sc.ora_owner = l_esquema and sc.table_name in ('*', tctl.table_name))
       )
     order by tctl.table_name
  ) loop
    select estado into l_estado
      from tdm_ejecucion
     where ejecucion_id = p_ejecucion_id;

    if l_estado in ('CANCELADO','ABORTADA') then
      return;
    end if;

    if func_dm_tabla_tiene_filas(t.ora_owner, t.table_name) = 0 then
      update tdm_objeto_ctrl
         set estado_objeto = 'OMITIDO',
             motivo_estado = 'TABLA_SIN_FILAS',
             fecha_ult_analisis = systimestamp,
             ultimo_run_id = p_ejecucion_id
       where ora_owner = t.ora_owner
         and table_name = t.table_name;

      -- CORRECCION 2026-09-28 (progreso_pct con base mezclada): esta rama
      -- recalculaba progreso_pct como tablas_proc/tablas_total*100, mientras
      -- que el resto del procedimiento (mas abajo, tras procesar cada
      -- columna) lo calcula como columnas_proc/columnas_total*100. Al ser
      -- tablas_total normalmente mucho menor que columnas_total, saltar de
      -- una formula a otra entre una tabla y la siguiente producia
      -- retrocesos visibles del % (p.ej. 54% -> 6%) sin que la ejecucion
      -- hubiera retrocedido realmente. Se deja una sola base (columnas) en
      -- todo el procedimiento; como esta rama no procesa columnas de la
      -- tabla omitida, el % no cambia aqui (se recalcula con los mismos
      -- columnas_proc/columnas_total vigentes, nunca con tablas_proc).
      update tdm_ejecucion
         set tablas_proc = nvl(tablas_proc,0) + 1,
             progreso_pct = case when nvl(columnas_total,0) > 0 then round(nvl(columnas_proc,0)/columnas_total*100,2) else progreso_pct end,
             ultimo_objeto = t.ora_owner || '.' || t.table_name,
             ultimo_paso = 'TABLA_OMITIDA_SIN_FILAS',
             heartbeat_ts = systimestamp
       where ejecucion_id = p_ejecucion_id;

      commit;
      l_tot_omit := l_tot_omit + 1;   -- se informa una sola vez al final (DESCUBRIMIENTO.TABLAS_OMITIDAS)
      continue;
    end if;

    l_tab_cols := 0;
    l_tab_y    := 0;

    delete from tdm_dependencia_hist
     where ejecucion_id = p_ejecucion_id
       and ora_owner = t.ora_owner
       and table_name = t.table_name;

    delete from tdm_columna_hist
     where ejecucion_id = p_ejecucion_id
       and ora_owner = t.ora_owner
       and table_name = t.table_name;

    update tdm_ejecucion
       set ultimo_objeto = t.ora_owner || '.' || t.table_name,
           ultimo_paso = 'LECTURA_COLUMNAS'
     where ejecucion_id = p_ejecucion_id;

    l_ctx_persona_tab   := func_dm_tiene_ctx_persona(t.ora_owner, t.table_name);
    l_ctx_apellidos_tab := func_dm_tiene_apellidos(t.ora_owner, t.table_name);

    for c in (
      select c.owner, c.table_name, c.column_name, c.data_type,
             c.data_length, c.data_precision, c.data_scale
        from dba_tab_columns c
       where c.owner = t.ora_owner
         and c.table_name = t.table_name
         and (
           c.data_type in ('CHAR','NCHAR','VARCHAR2','NVARCHAR2','CLOB')
           or (
             c.data_type = 'NUMBER'
             and regexp_like(c.column_name,
               '(^|_)(CUENTA|IBAN|CCC|SWIFT|NIF|NIE|DNI|DOC|DOCUMENTO|TELEFONO|TFNO|MOVIL|TEL|CP|CODIGO_POSTAL)($|_)', 'i')
           )
         )
       order by c.column_id
    ) loop
      begin
        l_best_id         := null;
        l_alt_id          := null;
        l_alt_total       := null;
        l_sin_pos         := false;
        -- FIX 09/26/26: antes -99999. Con -99999, el primer identificador
        -- devuelto por el cursor de mas abajo podia quedar como ganador con
        -- score_total = 0 (sin evidencia real), igual al bug que ya evitaba
        -- func_dm_identificador_base (linea 505-506) arrancando en 0.
        l_best_score      := 0;
        l_best_patron     := 0;
        l_comment         := func_dm_get_col_comment(c.owner, c.table_name, c.column_name);
        l_tiene_evidencia := 0;
        l_rows_total      := 0;
        l_matches         := 0;
        l_ratio           := 0;

        for idn in (
          select distinct identificador
            from tdm_regla
           where activa = 'Y'
           order by identificador -- FIX 09/26/26: orden estable y reproducible;
                                    -- antes dependia del plan interno de un
                                    -- SELECT DISTINCT sin ORDER BY
        ) loop
          l_score_nombre := func_dm_score_texto(idn.identificador, 'COLUMN_NAME', c.column_name);
          l_score_coment := func_dm_score_texto(idn.identificador, 'COLUMN_COMMENT', l_comment);
          l_score_tabla  := func_dm_score_texto(idn.identificador, 'TABLE_NAME', c.table_name);

          if regexp_like(c.column_name, '^(ID|COD|CODIGO|TIPO|FLAG|ESTADO|IND|SEQ|ORDEN|VERSION|HASH|TOKEN|UUID)[A-Z0-9_]+$', 'i')
             and idn.identificador not in ('IDENTIFICADOR_IDENTIDAD','IDENTIFICADOR_BANCARIO') then
            l_score_patron := 0;
            l_rows := 0;
            l_matches := 0;
            l_ratio := 0;
          elsif (l_score_nombre + l_score_coment + l_score_tabla) >= -30 then
            l_score_patron := func_dm_score_patron(
                                p_ejecucion_id,
                                c.owner,
                                c.table_name,
                                c.column_name,
                                idn.identificador,
                                p_sample_rows,
                                l_rows,
                                l_matches,
                                l_ratio,
                                l_contra
                              );
          else
            l_score_patron := 0;
            l_rows := 0;
            l_matches := 0;
            l_ratio := 0;
          end if;

          l_score_total := l_score_nombre + l_score_coment + l_score_tabla + l_score_patron;

          if func_dm_tiene_evid_min(
               idn.identificador,
               l_score_nombre,
               l_score_coment,
               l_score_tabla,
               l_score_patron
             ) = 1 then
            l_tiene_evidencia := 1;
            -- FIX 10/09/26: candidato "alternativo" = el de mayor total entre los que tienen alguna
            -- evidencia positiva, aunque ese total sea <= 0 (p.ej. nombre OBS +55 y tabla DOCUMENTOS -100).
            if l_alt_total is null or l_score_total > l_alt_total then
              l_alt_id    := idn.identificador;
              l_alt_total := l_score_total;
            end if;
          end if;

          -- FIX 09/26/26: desempate GENERICO (no hardcodea ningun identificador)
          -- ante empate en score_total, gana quien tenga mas evidencia de
          -- PATRON DE DATOS observado en la muestra real, no solo coincidencia
          -- lexica de nombre/comentario/tabla. Aplica igual a cualquier fila
          -- activa hoy o dada de alta despues en TDM_REGLA.
          if l_score_total > l_best_score
             or (l_score_total > 0 and l_score_total = l_best_score and l_score_patron > l_best_patron) then
            l_best_score  := l_score_total;
            l_best_patron := l_score_patron;
            l_best_id     := idn.identificador;
          end if;
        end loop;

        if l_tiene_evidencia = 0 then
          l_best_id := func_dm_identificador_base(c.column_name, c.table_name, l_comment);
          if l_best_id is not null then
            l_tiene_evidencia := 1;
          end if;
        end if;

        if l_tiene_evidencia = 0 or l_best_id is null then
          -- FIX 2026-10-07 (prueba L-06, DM_DUMMY.TBL_GESTOR_CARTERA.GESTOR): una
          -- excepcion FORCE sobre una columna SIN ninguna evidencia (nombre neutro,
          -- ninguna regla puntua, justo el caso para el que existe FORCE) nunca
          -- llegaba a proc_dm_aplica_excepcion: el continue de aqui la descartaba
          -- antes, asi que no entraba en TDM_COLUMNA_HIST/TDM_COLUMNA_FINAL ni se
          -- recolectaban sus dependencias (FK/triggers) para el pre/post del
          -- enmascarado. Ahora, si hay FORCE vivo con identificador forzado, la
          -- columna sigue adelante con ese identificador; sin FORCE todo igual.
          l_fx_id := null; l_fx_score := 0; l_fx_mask := 'N';
          proc_dm_aplica_excepcion(p_ejecucion_id, c.owner, c.table_name, c.column_name,
                                   l_fx_id, l_fx_score, l_fx_mask);
          if l_fx_mask = 'Y' and l_fx_id is not null then
            l_best_id         := l_fx_id;
            l_tiene_evidencia := 1;
          elsif l_alt_id is not null then
            -- FIX 10/09/26 (CEFCEN_OWN.CC_DOCUMENTOS.DESCRIPCION_DOCUMENTO): una columna con evidencia
            -- positiva pero total <= 0 desaparecia SIN dejar fila en TDM_COLUMNA_HIST, y el DBA no podia
            -- ver que se habia evaluado ni por que se descartaba. Ahora se registra como DESCARTADO /
            -- SCORE_TOTAL_NO_POSITIVO con su mejor candidato. No cambia que se enmascare: sigue sin ser Y.
            l_best_id := l_alt_id;
            l_sin_pos := true;
          else
            continue;
          end if;
        end if;

        l_score_nombre := func_dm_score_texto(l_best_id, 'COLUMN_NAME', c.column_name);
        l_score_coment := func_dm_score_texto(l_best_id, 'COLUMN_COMMENT', l_comment);
        l_score_tabla  := func_dm_score_texto(l_best_id, 'TABLE_NAME', c.table_name);
        l_score_patron := func_dm_score_patron(
                            p_ejecucion_id,
                            c.owner,
                            c.table_name,
                            c.column_name,
                            l_best_id,
                            p_sample_rows,
                            l_rows,
                            l_matches,
                            l_ratio,
                                l_contra
                          );

        l_score_total    := l_score_nombre + l_score_coment + l_score_tabla + l_score_patron;
        l_force_mask     := 'N';
        l_motivo_descarte := null;
        l_sem_rows       := null;
        l_sem_matches    := null;
        l_ratio_semantica := null;
        l_null_ratio     := func_dm_null_ratio_muestra(c.owner, c.table_name, c.column_name, p_sample_rows, l_rows_total);

        proc_dm_aplica_excepcion(p_ejecucion_id, c.owner, c.table_name, c.column_name, l_best_id, l_score_total, l_force_mask);

        if l_best_id = 'IDENTIFICADOR_IDENTIDAD'
           and regexp_like(c.column_name, '(^|_)(TIPO|COD|CODIGO|CLASE|ENUM|FLAG|ESTADO)_?(NIF|NIE|DNI|CIF)?($|_)', 'i')
           and nvl(l_ratio,0) < 0.5 -- FIX 09/26/26: si el dato prueba identidad, el nombre no penaliza
        then
          l_score_total := l_score_total - 250;
          l_motivo_descarte := nvl(l_motivo_descarte, 'CAMPO_TECNICO_IDENTIDAD');
        end if;

        if l_best_id = 'IDENTIFICADOR_DIRECCION'
           and regexp_like(c.column_name, '(^|_)(CODIGO_VIA|NUMERO_VIA|CODIGO|NUMERO)(_VIA|_R)?($|_)', 'i')
        then
          l_score_total := l_score_total - 220;
          l_motivo_descarte := nvl(l_motivo_descarte, 'CAMPO_NUMERICO_TECNICO_DIRECCION');
        end if;

        if l_best_id = 'IDENTIFICADOR_PERSONAL'
           and func_dm_es_nombre_candidato(c.column_name) = 1
        then
          l_ctx_persona := l_ctx_persona_tab;
          if l_ctx_persona = 0 then
            l_score_total := l_score_total - 90;
            l_motivo_descarte := nvl(l_motivo_descarte, 'NOMBRE_SIN_CONTEXTO_PERSONA');
          end if;

          if l_ctx_apellidos_tab = 0 then
            l_score_total := l_score_total - 220;
            l_motivo_descarte := nvl(l_motivo_descarte, 'NOMBRE_SIN_APELLIDOS_TABLA');

            l_ratio_semantica := func_dm_ratio_nombre_sem(
                                  c.owner,
                                  c.table_name,
                                  c.column_name,
                                  p_sample_rows,
                                  l_sem_rows,
                                  l_sem_matches
                                );

            if nvl(l_sem_rows,0) >= 10 and nvl(l_ratio_semantica,0) >= 0.70 then
              l_score_total := l_score_total + 170;
              l_motivo_descarte := null;
            end if;
          end if;
        end if;

        -- FIX 09/26/26: el dato contradice el nombre. Si el identificador tiene formatos
        -- exigentes (TDM_REGLA.confianza_min informado) y ninguna fila de la muestra los
        -- cumple, la columna no supera REVISAR aunque el nombre puntue alto.
        if l_contra = 1 and l_force_mask <> 'Y' and l_score_total > 55 then
          l_score_total := 55;
          l_motivo_descarte := nvl(l_motivo_descarte, 'DATO_NO_COINCIDE_CON_FORMATO');
        end if;

        proc_dm_clasifica(l_score_total, l_estado_final, l_enmascarar);

        if l_best_id = 'IDENTIFICADOR_PERSONAL'
           and l_score_nombre >= 85
           and l_force_mask <> 'Y'
           and (l_rows_total is null or l_null_ratio is null)
           and l_score_total >= 65
        then
          l_estado_final := case when l_score_total >= 85 then 'CONFIRMADO' else 'PROBABLE' end;
          l_enmascarar := 'Y';
          l_motivo_descarte := null;
        end if;

        if l_best_id = 'IDENTIFICADOR_PERSONAL'
           and func_dm_es_nombre_candidato(c.column_name) = 1
           and l_ctx_apellidos_tab = 0
           and l_force_mask <> 'Y'
           and (nvl(l_sem_rows,0) < 10 or nvl(l_ratio_semantica,0) < 0.70)
        then
          l_estado_final := 'REVISAR';
          l_enmascarar   := 'N';
          l_motivo_descarte := 'NOMBRE_SIN_SEMANTICA_PERSONA';
        end if;

        if l_best_id = 'IDENTIFICADOR_TELEFONO'
           and l_force_mask <> 'Y'
           and l_score_nombre >= 70
           and nvl(l_rows_total,0) >= 10
           and (
                nvl(l_ratio,0) >= 0.45
                or nvl(l_score_patron,0) >= 25
               )
        then
          l_estado_final := case when l_score_total >= 65 then 'PROBABLE' else 'REVISAR' end;
          l_enmascarar := 'Y';
          l_motivo_descarte := null;
        end if;

        if l_force_mask <> 'Y'
           and l_best_id in ('IDENTIFICADOR_BANCARIO','IDENTIFICADOR_IDENTIDAD')
           and l_score_nombre >= 90
           and l_score_total >= 85
           and (l_rows_total is not null and l_rows_total < 10)
        then
          l_estado_final := 'PROBABLE';
          l_enmascarar := 'Y';
          l_motivo_descarte := null;
        end if;

        if l_rows_total is not null
           and l_rows_total < 10
           and l_force_mask <> 'Y'
           and not (
             l_best_id in ('IDENTIFICADOR_BANCARIO','IDENTIFICADOR_IDENTIDAD')
             and l_score_nombre >= 90
             and l_score_total >= 85
           )
        then
          l_estado_final := 'DESCARTADO';
          l_enmascarar := 'N';
          l_motivo_descarte := 'MUESTRA_INSUFICIENTE_MIN_10';
        elsif l_null_ratio is not null
           and l_null_ratio >= 0.995
           and l_force_mask <> 'Y'
           and not (
             l_best_id in ('IDENTIFICADOR_BANCARIO','IDENTIFICADOR_IDENTIDAD')
             and l_score_nombre >= 90
             and l_score_total >= 85
           )
        then
          l_estado_final := 'DESCARTADO';
          l_enmascarar := 'N';
          l_motivo_descarte := 'ALTA_NULIDAD_EN_MUESTRA';
        end if;

        if l_force_mask = 'Y' then
          l_enmascarar := 'Y';
          l_estado_final := 'CONFIRMADO';
          l_motivo_descarte := null;
        end if;

        if l_sin_pos and l_force_mask <> 'Y' then
          l_estado_final    := 'DESCARTADO';
          l_enmascarar      := 'N';
          l_motivo_descarte := nvl(l_motivo_descarte, 'SCORE_TOTAL_NO_POSITIVO');
        end if;

        insert into tdm_columna_hist(
          hist_id, ejecucion_id, ora_owner, table_name, column_name,
          data_type, data_length, data_precision, data_scale,
          column_comment, identificador,
          score_nombre, score_comentario, score_patron, score_tabla, score_total,
          sample_rows, matched_rows, ratio_match, ratio_null,
          estado_final, motivo_descarte, enmascarar, hash_reglas
        ) values (
          seq_dm_columna_hist.nextval, p_ejecucion_id, c.owner, c.table_name, c.column_name,
          c.data_type, c.data_length, c.data_precision, c.data_scale,
          l_comment, l_best_id,
          l_score_nombre, l_score_coment, l_score_patron, l_score_tabla, l_score_total,
          l_rows_total, l_matches, l_ratio, l_null_ratio,
          l_estado_final, l_motivo_descarte, l_enmascarar,
          to_char(ora_hash(c.owner || '|' || c.table_name || '|' || c.column_name || '|' || l_best_id || '|' || l_score_total))
        );

        if l_enmascarar = 'Y' then
          proc_dm_recolecta_dep(p_ejecucion_id, c.owner, c.table_name, c.column_name);
        end if;

        l_cols_lote := l_cols_lote + 1;
        l_tab_cols  := l_tab_cols + 1;
        if l_enmascarar = 'Y' then
          l_tab_y := l_tab_y + 1;
        end if;

        update tdm_ejecucion
           set columnas_proc = nvl(columnas_proc,0) + 1,
               progreso_pct = case
                 when columnas_total > 0 then round(((nvl(columnas_proc,0)+1) / columnas_total) * 100, 2)
                 else 100
               end,
               ultimo_objeto = c.owner || '.' || c.table_name || '.' || c.column_name,
               ultimo_paso = 'COLUMNA_PROCESADA',
               heartbeat_ts = systimestamp
         where ejecucion_id = p_ejecucion_id;

        if mod(l_cols_lote, p_commit_lote) = 0 then
          commit;
        end if;

      exception
        when others then
          proc_dm_log_error(p_ejecucion_id, c.owner, c.table_name, c.column_name, 'PROCESA_COLUMNA', sqlcode, sqlerrm);
      end;
    end loop;

    update tdm_objeto_ctrl
       set estado_objeto = 'PROCESADO',
           motivo_estado = null,
           ultimo_run_id = p_ejecucion_id,
           fecha_ult_analisis = systimestamp
     where ora_owner = t.ora_owner
       and table_name = t.table_name;

    update tdm_ejecucion
       set tablas_proc = nvl(tablas_proc,0) + 1,
           ultimo_paso = 'TABLA_FINALIZADA',
           heartbeat_ts = systimestamp
     where ejecucion_id = p_ejecucion_id;

    commit;

    if l_tab_cols > 0 then
      l_tot_tabs := l_tot_tabs + 1;   -- solo tablas con columnas evaluadas (igual que el resumen de @dm_descubre)
    end if;
    l_tot_cols := l_tot_cols + l_tab_cols;
    l_tot_y    := l_tot_y    + l_tab_y;
  end loop;

  proc_dm_sync_col_final(p_ejecucion_id);
  proc_dm_sync_dep_final(p_ejecucion_id);

  update tdm_ejecucion
     set estado = 'FINALIZADO',
         fase_proceso = 'DESCUBRIMIENTO',
         fecha_fin = systimestamp,
         progreso_pct = 100,
         ultimo_paso = 'FINALIZADO'
   where ejecucion_id = p_ejecucion_id;

  commit;

  -- Traza del descubrimiento: SOLO un resumen (y, aparte, tablas omitidas y los
  -- avisos/errores de las rutinas de sincronizacion). El detalle por tabla/columna
  -- vive en TDM_COLUMNA_HIST / TDM_DEPENDENCIA_HIST, no en la traza.
  if l_tot_omit > 0 then
    pkg_dm_trazabilidad.proc_dm_trace(null, p_ejecucion_id, 'DESCUBRIMIENTO', 'TABLAS_OMITIDAS',
      'tablas sin filas omitidas='||l_tot_omit);
  end if;
  pkg_dm_trazabilidad.proc_dm_trace(null, p_ejecucion_id, 'DESCUBRIMIENTO', 'RESUMEN',
    'tablas='||l_tot_tabs||' columnas='||l_tot_cols||' enmascarar='||l_tot_y,
    pkg_dm_trazabilidad.func_dm_seg_desde(l_run_t0));
exception
  when others then
    proc_dm_log_error(p_ejecucion_id, l_esquema, null, null, 'PROCESO_GENERAL', sqlcode, sqlerrm);
    update tdm_ejecucion
       set estado = 'ERROR',
           fecha_fin = systimestamp,
           ultimo_paso = 'ERROR_FATAL'
     where ejecucion_id = p_ejecucion_id;
    commit;
    raise;
end proc_dm_procesa_desc;

------------------------------------------------------------------------------
-- Núcleo privado: ejecutar descubrimiento (con o sin alcance por tablas)
-- FIX 2026-09-18: extraído de proc_dm_descubrimiento para reutilizar la misma
-- lógica (gate de ejecución maestra ORA-20014, alta en tdm_ejecucion, scope,
-- prepara_objetos, procesa_desc) desde el nuevo modo "por excepciones"
-- (proc_dm_descubrimiento_set) sin duplicar código ni tocar el comportamiento
-- ya usado en producción por @dm_descubre (p_tablas_csv = null se comporta
-- exactamente igual que antes: alcance '*' = esquema completo).
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_descubrimiento_core
-- PROPOSITO    : Nucleo comun del descubrimiento: valida esquema y conflictos, crea la ejecucion,
--                registra el alcance, prepara objetos y lanza el procesamiento.
-- ENTRADAS     : p_esquema, p_tablas_csv (null = esquema completo), p_sample_rows, p_forzar_full ('Y'
--                fuerza reanalisis completo). Sin OUT.
-- LEE          : DBA_USERS; TDM_EJECUCION; Indirecto: TDM_EJECUCION_SCOPE
-- ESCRIBE      : TDM_EJECUCION (INSERT); Indirecto: TDM_EJECUCION_SCOPE, TDM_OBJETO_CTRL y todo lo
--                que escribe proc_dm_procesa_desc
-- ERRORES      : ORA-20016 si el esquema no existe en DBA_USERS; ORA-20011 si ya hay una ejecucion
--                EJECUTANDO o el indice unico rechaza la nueva (DUP_VAL_ON_INDEX); ORA-20014 si ya
--                existe una ejecucion maestra FINALIZADO con forzar_full = N y no se pidio 'Y'
-- LLAMADO DESDE: proc_dm_descubrimiento (ambas sobrecargas); proc_dm_descubrimiento_set
------------------------------------------------------------------------------
procedure proc_dm_descubrimiento_core(
    p_esquema          in varchar2,
    p_tablas_csv       in varchar2,
    p_sample_rows      in number,
    p_forzar_full      in char
) is
  l_running      number;
  l_run_id       number;
  l_ejec_base_id number;
  l_esquema_existe number;
begin
  -- FIX 2026-10-03 (vespertino): hallazgo real del usuario -- @dm_descubre
  -- contra un esquema que no existe (typo DM_ARCA_OWN por DATAM_ARCA_OWN)
  -- NO daba ningun error: insertaba igual una fila en TDM_EJECUCION, y
  -- proc_dm_prepara_objetos, al filtrar dba_objects/dba_tables por un owner
  -- que no existe, simplemente no encuentra filas -- la ejecucion termina
  -- FINALIZADO con tablas_total=0/columnas_total=0 en silencio, indistinguible
  -- en el log de "esquema real sin tablas" o de un acierto vacio por scope.
  -- Se valida la existencia del esquema ANTES de crear cualquier fila de
  -- ejecucion, con el mismo estilo de vista de diccionario (DBA_*) que ya usa
  -- proc_dm_prepara_objetos mas abajo.
  select count(*)
    into l_esquema_existe
    from dba_users
   where username = upper(p_esquema);

  if l_esquema_existe = 0 then
    raise_application_error(
      -20016,
      'El esquema ' || upper(p_esquema) || ' no existe (no aparece en DBA_USERS). ' ||
      'Revise el nombre -- no se ha creado ninguna ejecucion.'
    );
  end if;

  pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(15, 'Y');
  l_running := func_dm_conflicto_running(upper(p_esquema), null);

  if l_running > 0 then
    raise_application_error(-20011, 'Existe una ejecución EJECUTANDO en curso para el esquema/alcance');
  end if;

  if upper(nvl(p_forzar_full,'N')) <> 'Y' then
    begin
      select max(ejecucion_id)
        into l_ejec_base_id
        from tdm_ejecucion
       where ora_esquema = upper(p_esquema)
         and fase_proceso in ('DESCUBRIMIENTO','ENMASCARAMIENTO')
         and nvl(forzar_full,'N') = 'N'
         and estado in ('FINALIZADO')
         and columnas_total > 0;

    exception
      when no_data_found then
        l_ejec_base_id := null;
    end;

    if l_ejec_base_id is not null then
      raise_application_error(
        -20014,
        'El esquema ' || upper(p_esquema) ||
        ' ya tiene una ejecución maestra registrada con FORZAR_FULL = N. ' ||
        'Para volver a ejecutar debe usar proc_dm_descubrimiento(''' ||
        upper(p_esquema) || ''',''Y'').'
      );
    end if;
  end if;

  BEGIN
    insert into tdm_ejecucion(
      ejecucion_id, ora_esquema, ora_usuario, fase_proceso, estado,
      fecha_inicio, ultimo_paso, forzar_full, sesion_audsid, heartbeat_ts
    ) values (
      seq_dm_ejecucion.nextval, upper(p_esquema), sys_context('USERENV','SESSION_USER'),
      'DESCUBRIMIENTO', 'EJECUTANDO',
      systimestamp,
      case when upper(nvl(p_forzar_full,'N'))='Y' then 'INICIADO_FORZAR_FULL' else 'INICIADO' end,
      case when upper(nvl(p_forzar_full,'N'))='Y' then 'Y' else 'N' end,
      sys_context('USERENV','SESSIONID'),
      systimestamp
    )
    returning ejecucion_id into l_run_id;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      raise_application_error(-20011, 'Existe una ejecución EJECUTANDO en curso para el esquema/alcance');
  END;

  proc_dm_registra_scope(l_run_id, upper(p_esquema), p_tablas_csv);
  pkg_dm_trazabilidad.proc_dm_refresca_sesion(l_run_id);

  commit;

  proc_dm_prepara_objetos(
    upper(p_esquema),
    l_run_id,
    case when upper(nvl(p_forzar_full,'N'))='Y' then 'Y' else 'N' end
  );

  proc_dm_procesa_desc(l_run_id, func_dm_normaliza_sample(p_sample_rows), 100);
end proc_dm_descubrimiento_core;

------------------------------------------------------------------------------
-- API pública: ejecutar (esquema completo)
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_descubrimiento
-- PROPOSITO    : API publica para descubrir el esquema completo con tamano de muestra y modo
--                forzar_full configurables.
-- ENTRADAS     : p_esquema, p_sample_rows (default 500), p_forzar_full (default 'N'). Sin OUT.
-- LEE          : Ver proc_dm_descubrimiento_core
-- ESCRIBE      : Ver proc_dm_descubrimiento_core
-- ERRORES      : Propaga ORA-20011, ORA-20014 y ORA-20016 de proc_dm_descubrimiento_core
-- LLAMADO DESDE: dm_descubre.sql lineas 129 y 143 (invocacion con 1 o 3 argumentos)
------------------------------------------------------------------------------
procedure proc_dm_descubrimiento(
    p_esquema          in varchar2,
    p_sample_rows      in number default 500,
    p_forzar_full      in char default 'N'
) is
begin
  proc_dm_descubrimiento_core(
    p_esquema     => p_esquema,
    p_tablas_csv  => null,
    p_sample_rows => p_sample_rows,
    p_forzar_full => p_forzar_full
  );
end proc_dm_descubrimiento;
------------------------------------------------------------------------------
-- API pública: sobrecarga
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_descubrimiento
-- PROPOSITO    : API publica (sobrecarga) para descubrir el esquema completo con muestra fija de 500
--                filas y modo forzar_full explicito.
-- ENTRADAS     : p_esquema, p_forzar_full. Sin OUT.
-- LEE          : Ver proc_dm_descubrimiento_core
-- ESCRIBE      : Ver proc_dm_descubrimiento_core
-- ERRORES      : Propaga ORA-20011, ORA-20014 y ORA-20016 de proc_dm_descubrimiento_core
-- LLAMADO DESDE: dm_descubre.sql linea 133 (invocacion con 'Y')
------------------------------------------------------------------------------
procedure proc_dm_descubrimiento(
    p_esquema     in varchar2,
    p_forzar_full in char
) is
begin
  proc_dm_descubrimiento_core(
    p_esquema     => p_esquema,
    p_tablas_csv  => null,
    p_sample_rows => 500,
    p_forzar_full => p_forzar_full
  );
end proc_dm_descubrimiento;

------------------------------------------------------------------------------
-- API pública: descubrimiento por excepciones (@dm_descubre_set)
-- FIX 2026-09-18: alcance limitado a p_tablas_csv (tipicamente las tablas
-- ya presentes en tdm_excepcion_col para un FORCE previo). Mapea metadata,
-- triggers e integridad SOLO de esas tablas; el resultado del descubrimiento
-- (Y/N en tdm_columna_final) queda registrado igual que en modo completo,
-- pero NO reemplaza la decision FORCE de tdm_excepcion_col: esa tabla
-- sigue resolviendo via el flujo normal de proc_dm_enmascaramiento/proc_dm_apl_col
-- (proc_dm_get_excepcion tiene prioridad sobre el Y/N de descubrimiento).
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_descubrimiento_set
-- PROPOSITO    : API publica para descubrir solo una lista de tablas (modo por excepciones) sin
--                escanear el esquema completo.
-- ENTRADAS     : p_esquema, p_tablas_csv (obligatorio), p_sample_rows (default 500), p_forzar_full
--                (default 'N'). Sin OUT.
-- LEE          : Ver proc_dm_descubrimiento_core
-- ESCRIBE      : Ver proc_dm_descubrimiento_core
-- ERRORES      : ORA-20015 si p_tablas_csv es nulo o vacio; Propaga ORA-20011, ORA-20014 y ORA-20016
--                de proc_dm_descubrimiento_core
-- LLAMADO DESDE: dm_descubre_set.sql linea 149
------------------------------------------------------------------------------
procedure proc_dm_descubrimiento_set(
    p_esquema          in varchar2,
    p_tablas_csv       in varchar2,
    p_sample_rows      in number default 500,
    p_forzar_full      in char default 'N'
) is
begin
  if p_tablas_csv is null or length(trim(p_tablas_csv)) = 0 then
    raise_application_error(-20015,
      'proc_dm_descubrimiento_set requiere p_tablas_csv con al menos una tabla; '||
      'para descubrimiento de esquema completo use proc_dm_descubrimiento.');
  end if;

  proc_dm_descubrimiento_core(
    p_esquema     => p_esquema,
    p_tablas_csv  => p_tablas_csv,
    p_sample_rows => p_sample_rows,
    p_forzar_full => p_forzar_full
  );
end proc_dm_descubrimiento_set;

------------------------------------------------------------------------------
-- API pública: reanudar
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_reanudar
-- PROPOSITO    : API publica para reanudar una ejecucion de descubrimiento interrumpida, tras
--                comprobar que su sesion original ya no esta viva.
-- ENTRADAS     : p_ejecucion_id, p_sample_rows (default 500), p_commit_lote (default 100). Sin OUT.
-- LEE          : TDM_EJECUCION (FOR UPDATE); gv$session (indirecto, via
--                pkg_dm_trazabilidad.func_dm_sesion_viva)
-- ESCRIBE      : TDM_EJECUCION (estado, fecha_fin, ultimo_paso); Indirecto: lo que escribe
--                proc_dm_procesa_desc y proc_dm_autocancel_huerfanas / proc_dm_refresca_sesion
-- ERRORES      : ORA-20019 si la fase de la ejecucion no es DESCUBRIMIENTO; ORA-20017 si la sesion
--                original sigue viva en gv$session; ORA-20012 si el estado es FINALIZADO o CANCELADO;
--                ORA-01403 sin controlar si ejecucion_id no existe
-- LLAMADO DESDE: dm_descubre_reanudar.sql linea 215
------------------------------------------------------------------------------
procedure proc_dm_reanudar(
    p_ejecucion_id in number,
    p_sample_rows  in number default 500,
    p_commit_lote  in number default 100
) is
  l_estado         tdm_ejecucion.estado%type;
  l_fase           tdm_ejecucion.fase_proceso%type;
  l_heartbeat      tdm_ejecucion.heartbeat_ts%type;
  l_sesion_viva    number := 0;
  l_sid            tdm_ejecucion.sesion_sid%type;
  l_serial         tdm_ejecucion.sesion_serial%type;
  l_inst_id        tdm_ejecucion.sesion_inst_id%type;
  l_ejecutado_por  tdm_ejecucion.ora_usuario%type;
begin
  pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(5, 'Y');

  select estado, fase_proceso, heartbeat_ts, sesion_sid, sesion_serial, sesion_inst_id, ora_usuario
    into l_estado, l_fase, l_heartbeat, l_sid, l_serial, l_inst_id, l_ejecutado_por
    from tdm_ejecucion
   where ejecucion_id = p_ejecucion_id
   for update;

  -- FIX 2026-10-06 (incidente real: @dm_descubre_reanudar 1 invocado por error
  -- humano sobre una ejecucion_id cuya fase_proceso real era ENMASCARAMIENTO,
  -- interrumpida por un ALTER SYSTEM KILL SESSION de prueba y ya liberada con
  -- dm_liberar_ejecucion_activa.sql -- ESTADO quedo en ABORTADA, que SI es
  -- resumible, asi que nada de lo que habia hasta aqui lo frenaba). Este
  -- procedimiento es el reanudador de DESCUBRIMIENTO; nunca comprobaba que la
  -- fila que esta reclamando siga realmente en esa fase. Como tdm_ejecucion
  -- reutiliza la misma fila/ejecucion_id a lo largo de las dos fases (ver
  -- proc_dm_enmascaramiento, que reclama la fila existente y le pisa
  -- fase_proceso='ENMASCARAMIENTO'), reanudarla aqui hizo que
  -- proc_dm_procesa_desc retomara por TDM_EJECUCION_SCOPE/TDM_COLUMNA_HIST
  -- (que ya estaban completos de un descubrimiento anterior), terminara casi
  -- de inmediato, y dejara la fila en FASE_PROCESO=DESCUBRIMIENTO/
  -- ESTADO=FINALIZADO -- borrando del todo, en TDM_EJECUCION, la evidencia de
  -- que en realidad habia un ENMASCARAMIENTO parcial (4/16 tablas) abortado.
  -- Se corta aqui, antes de tocar nada, con un mensaje que apunta al driver
  -- correcto.
  if l_fase is not null and upper(trim(l_fase)) != 'DESCUBRIMIENTO' then
    raise_application_error(-20019,
      'No se reanuda ejecucion_id='||p_ejecucion_id||' con pkg_dm_descubrimiento.proc_dm_reanudar: '||
      'su fase_proceso actual es '||l_fase||', no DESCUBRIMIENTO. '||
      case when upper(trim(l_fase)) = 'ENMASCARAMIENTO'
           then 'Use @dm_enmascara_reanudar '||p_ejecucion_id||' para reanudar el enmascarado.'
           else 'Revise TDM_EJECUCION.fase_proceso antes de continuar.'
      end);
  end if;

  -- FIX 2026-10-05 (puerto del fix 2026-10-04 de pkg_dm_enmascarar.proc_dm_reanudar,
  -- incidente real ejecucion_id=5, 7 constraints deshabilitadas): la comprobacion
  -- de sesion viva de aqui era CONDICIONAL ("if l_estado = 'EJECUTANDO' then ..."),
  -- exactamente el mismo hueco que el de masking antes de su fix. Si alguien
  -- cambiaba ESTADO por fuera (p.ej. un UPDATE manual, o dm_liberar_ejecucion_activa
  -- corriendo sobre una fila cuya sesion coordinadora en realidad seguia viva
  -- bloqueada dentro de proc_dm_procesa_desc) mientras la sesion original de
  -- DESCUBRIMIENTO seguia realmente viva, este IF nunca se evaluaba y
  -- proc_dm_reanudar reclamaba la fila igual, lanzando una SEGUNDA ejecucion de
  -- descubrimiento en paralelo sobre el mismo esquema -- misma clase de incidente
  -- que ya ocurrio en enmascaramiento, aqui aplicada preventivamente porque hasta
  -- ahora nada llamaba a este procedimiento (no existia ningun driver .sql que lo
  -- invocara; ver dm_descubre_reanudar.sql, creado junto con este fix).
  -- Ahora la comprobacion es INCONDICIONAL: se mira gv$session SIEMPRE, sin
  -- importar que diga ESTADO, y si la sesion original sigue viva se bloquea de
  -- raiz, sin excepcion.
  l_sesion_viva := pkg_dm_trazabilidad.func_dm_sesion_viva(p_ejecucion_id);

  if l_sesion_viva = 1 then
    raise_application_error(-20017,
      'No se reanuda ejecucion_id='||p_ejecucion_id||': la sesion original '||
      '(sid='||nvl(to_char(l_sid),'?')||', serial#='||nvl(to_char(l_serial),'?')||
      ', inst_id='||nvl(to_char(l_inst_id),'?')||', usuario='||nvl(l_ejecutado_por,'?')||
      ') SIGUE VIVA en gv$session (TDM_EJECUCION.ESTADO actual='||nvl(l_estado,'?')||
      '). No se reanuda para evitar una ejecucion de DESCUBRIMIENTO duplicada en '||
      'paralelo -- verifique esa sesion y matela con ALTER SYSTEM KILL SESSION si procede, luego reintente.');
  end if;

  -- A partir de aqui la sesion original esta confirmada muerta (si no, ya se
  -- habria lanzado el -20017 de arriba). Si la fila seguia EJECUTANDO, se
  -- autosana a ABORTADA antes de reclamarla -- mismo mecanismo de siempre, solo
  -- que ya no depende de un segundo chequeo de heartbeat para decidirlo: con la
  -- sesion confirmada muerta de forma incondicional, el hearteat_ts deja de
  -- hacer falta como señal independiente (ese segundo chequeo, "AUTO_ABORTADA_
  -- REANUDAR_STALE", se retira: dejaba pasar la reanudacion igual cuando
  -- func_dm_sesion_viva=1 pero el heartbeat estaba viejo -- exactamente el hueco
  -- que este fix cierra, asi que mantenerlo como ruta alternativa lo reabriria).
  if l_estado = 'EJECUTANDO' then
    update tdm_ejecucion
       set estado = 'ABORTADA',
           fecha_fin = systimestamp,
           ultimo_paso = 'AUTO_ABORTADA_REANUDAR_SESION_CAIDA'
     where ejecucion_id = p_ejecucion_id
       and estado = 'EJECUTANDO';
    l_estado := 'ABORTADA';
  end if;

  if l_estado in ('FINALIZADO','CANCELADO') then
    raise_application_error(-20012, 'La ejecución no puede reanudarse por estado final');
  end if;

  update tdm_ejecucion
     set estado = 'EJECUTANDO',
         fecha_fin = null,
         ultimo_paso = 'REANUDADO'
   where ejecucion_id = p_ejecucion_id;

  pkg_dm_trazabilidad.proc_dm_refresca_sesion(p_ejecucion_id);

  commit;

  proc_dm_procesa_desc(p_ejecucion_id, func_dm_normaliza_sample(p_sample_rows), p_commit_lote);
end proc_dm_reanudar;

------------------------------------------------------------------------------
-- API pública: cancelar
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- [DOC] procedure proc_dm_cancelar
-- PROPOSITO    : API publica para cancelar una ejecucion de descubrimiento y eliminar su historico de
--                columnas y dependencias.
-- ENTRADAS     : p_ejecucion_id. Sin OUT.
-- LEE          : ninguno
-- ESCRIBE      : TDM_EJECUCION (UPDATE a CANCELADO si estaba EJECUTANDO/PAUSADO/ERROR/ABORTADA);
--                TDM_DEPENDENCIA_HIST (DELETE); TDM_COLUMNA_HIST (DELETE)
-- ERRORES      : No levanta ORA-2xxxx; si el estado no es cancelable no cambia la ejecucion pero
--                igualmente borra su historico
-- LLAMADO DESDE: externo/script (solo documentado en 00_guion_uso_datamasking.sql; ningun driver .sql
--                la invoca)
------------------------------------------------------------------------------
procedure proc_dm_cancelar(
    p_ejecucion_id in number
) is
begin
  update tdm_ejecucion
     set estado = 'CANCELADO',
         fecha_fin = systimestamp,
         ultimo_paso = 'CANCELADO',
         heartbeat_ts = systimestamp,
         sesion_sid = null,
         sesion_serial = null,
         sesion_inst_id = null
   where ejecucion_id = p_ejecucion_id
     and estado in ('EJECUTANDO','PAUSADO','ERROR','ABORTADA');

  delete from tdm_dependencia_hist where ejecucion_id = p_ejecucion_id;
  delete from tdm_columna_hist     where ejecucion_id = p_ejecucion_id;

  commit;
end proc_dm_cancelar;

end pkg_dm_descubrimiento;
/



