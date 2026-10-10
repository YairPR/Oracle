Rem pkg_dm_enmascarar.sql
Rem
Rem
Rem    NOMBRE
Rem      pkg_dm_enmascarar.sql - Motor operativo de enmascaramiento
Rem
Rem    DESCRIPCIÓN
Rem      Este paquete ejecuta el proceso de masking sobre tablas y columnas
Rem      definidas en tdm_columna_final, utilizando funciones deterministas
Rem      de pkg_dm_func_mask y respetando dependencias técnicas,
Rem      reglas especiales y coherencias post-masking.
Rem
Rem      El flujo soporta:
Rem        - Enmascaramiento por ejecución completa
Rem        - Reproceso forzado
Rem        - Cancelación controlada
Rem        - Reanudación de solicitudes
Rem        - Enmascaramiento selectivo por tabla o columna
Rem        - Export de esquema o subconjunto para PRE
Rem        - Trazabilidad del proceso
Rem        - Deshabilitado y rehabilitado de dependencias
Rem        - Reglas especiales por tabla/columna
Rem        - Sincronización post-masking entre tablas relacionadas
Rem
Rem    FLUJO:
Rem      El paquete toma como entrada principal:
Rem
Rem        - tdm_columna_final
Rem        - tdm_dependencia_final
Rem        - tdm_excepcion_col
Rem        - tdm_mask_regla_esp
Rem        - tdm_mask_relacion_sync
Rem
Rem      Y registra actividad en:
Rem
Rem        - tdm_mask_solicitud
Rem        - tdm_mask_trace
Rem        - tdm_mask_dep_estado
Rem        - tdm_ejecucion
Rem
Rem    CRITERIOS DE EJECUCIÓN
Rem      Antes de aplicar masking, el paquete valida por columna:
Rem
Rem        - Tipo de dato real desde DBA_TAB_COLUMNS
Rem        - Longitud disponible real
Rem        - Si la columna tiene datos no nulos
Rem        - Si existe EXCLUDE manual
Rem        - Si la longitud mínima es compatible con el identificador
Rem
Rem      Si una columna no cumple condiciones mínimas, el proceso:
Rem
Rem        - la omite
Rem        - la registra como SKIP en trazas
Rem        - puede consolidarla en tdm_excepcion_col como EXCLUDE
Rem        - continúa sin abortar la tabla completa
Rem
Rem    Reglas especiales (mecanismo GENERICO del motor; los tipo_regla son
Rem    nombres de mecanismo, no logica de cliente -- el caso de uso que los
Rem    puebla hoy es SIGAD via tdm_mask_regla_esp, ver 02 seccion 5):
Rem      DOC_SEGUN_TIPO, DOC_UNIFICADO_MANTENER_1_Y_ULTIMO, IBAN_ES_CONTINUO
Rem      -> pkg_dm_func_mask.func_dm_espec_doc_segun_tipo /
Rem         func_dm_especial_doc_keep_ends / func_dm_especial_iban_continuo
Rem        - Genera IBAN español continuo
Rem        - Mantiene formato ES + 22 dígitos
Rem        - Recalcula correctamente dígitos de control
Rem
Rem    COMPORTAMIENTO DEL PROCESO
Rem
Rem      proc_dm_enmascaramiento
Rem        - Ejecuta el masking completo de una ejecución
Rem        - Valida objetos base
Rem        - Crea solicitud operativa
Rem        - Deshabilita dependencias
Rem        - Aplica masking por catálogo
Rem        - Ejecuta sincronizaciones post-masking
Rem        - Rehabilita dependencias
Rem        - Actualiza estado final en control y trazas
Rem
Rem      proc_dm_cancelar
Rem        - Marca una ejecución o solicitud para cancelación
Rem        - La cancelación se evalúa en puntos de control del proceso
Rem
Rem      proc_dm_gestiona_tareas
Rem        - Diagnostica (INFORMAR), termina (RECONCILIAR) o descarta (DESCARTAR) las tareas
Rem          DBMS_PARALLEL_EXECUTE que deja una ejecucion interrumpida
Rem
Rem
Rem      func_dm_tareas_de_ejecucion
Rem        - Lista (separada por comas) las tareas DBMS_PARALLEL_EXECUTE del motor que pertenecen a
Rem          una ejecucion; la usa dm_enmascara_reanudar.sql para su revision previa
Rem
Rem      proc_dm_reanudar
Rem        - Relanza el proceso sobre una ejecución dada
Rem        - Aprovecha el mismo flujo operativo de enmascaramiento
Rem
Rem      proc_dm_enmascara_tabla
Rem        - Ejecuta enmascaramiento selectivo
Rem        - Puede operar sobre una o varias tablas
Rem        - También puede dirigirse a una sola columna
Rem        - Requiere identificador semántico para resolver la función
Rem
Rem        - Exporta el alcance tratado o el esquema completo
Rem        - Soporta alcance:
Rem            S = solo tablas enmascaradas
Rem            C = esquema completo
Rem
Rem    EXPORT / IMPORT EN EL FLUJO
Rem      El modelo operativo contempla que el rollback funcional del masking
Rem      se realice preferentemente mediante importación del dump original
Rem      en lugar de un desenmascarado fila a fila.
Rem
Rem      Por ello:
Rem        - El export (Data Pump) se movio a pkg_dm_export (07)
Rem        - el import de reversión es la estrategia preferente
Rem        - no se depende de reconstrucción campo a campo para textos libres
Rem
Rem    CORRECCIONES Y AJUSTES RELEVANTES
Rem      - Corrección de ORA-06502 y ORA-12899 asociados a longitudes reales
Rem      - Validación previa de tipo y longitud antes de enmascarar
Rem      - Omisión controlada de columnas incompatibles
Rem      - Tratamiento especial para columnas bancarias de 10, 20 o 24 posiciones
Rem      - Refuerzo de trazabilidad por columna y por tabla
Rem      - Gestión de SKIP por:
Rem          * longitud insuficiente
Rem          * tipo no soportado
Rem          * todos los valores NULL
Rem          * exclusión manual
Rem      - Integración operativa con export Data Pump
Rem      - Preparación para estrategia de reversión por import
Rem
Rem    RELACIÓN CON EL DESCUBRIMIENTO
Rem      Este paquete no descubre columnas.
Rem      Parte del resultado ya validado del discovery, especialmente:
Rem
Rem        - tdm_columna_final
Rem        - tdm_dependencia_final
Rem        - tdm_excepcion_col
Rem
Rem      Por tanto, su responsabilidad es operativa y no semántica.
Rem
Rem    NOTAS
Rem      - Diseñado para Oracle 11g en adelante
Rem      - Usa SQL dinámico controlado con DBMS_ASSERT
Rem      - Utiliza tracking operativo vía DBMS_APPLICATION_INFO
Rem      - Integra trazabilidad de warnings, errores y checkpoints
Rem      - Respeta exclusiones manuales en tdm_excepcion_col
Rem      - Puede aplicar auto-exclusión de columnas incompatibles
Rem      - Está preparado para sincronización post-masking entre tablas
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    09/05/25 - Versión inicial del motor de enmascaramiento
Rem                           Basado en ejecución por columna y función semántica
Rem
Rem    epurisaca    10/11/25 - Se añade control operativo de solicitud
Rem                           trazabilidad técnica y gestión de dependencias
Rem
Rem    epurisaca    11/22/25 - Se incorporan reglas especiales para documentos
Rem                           IBAN y coherencia post-masking
Rem
Rem    epurisaca    01/28/26 - Se refuerza validación de longitudes
Rem                           exclusiones automáticas y tratamiento de errores
Rem
Rem    epurisaca    03/24/26 - Corrección de ORA-06502 y ORA-12899
Rem                           validación previa por tipo y longitud real
Rem
Rem    epurisaca    03/24/26 - Se incorpora lógica de SKIP controlado
Rem                           para columnas incompatibles o sin datos útiles
Rem
Rem    epurisaca    03/24/26 - Se integra export como parte del flujo PRE
Rem                           y reversión preferente vía import de dump
Rem
Rem    epurisaca    03/24/26 - Revisión funcional completa del paquete
Rem                            Alineado con flujo PRE, masking y post-sync
Rem    epurisaca    03/28/26 - Se retiró del fujo la tabla tdm_mask_resultado para 
Rem                            evitar duplicidad y ambigüedad de estados
Rem    epurisaca    04/21/26 - 
Rem                            1) Procesa tdm_columna_final.enmascarar='Y' como primera opción.
Rem                            2) Sobre esas columnas aplica prioridad de tdm_excepcion_col:
Rem                              - EXCLUDE omite
Rem                              - FORCE redefine identificador
Rem                            3) Solo si NO existen columnas en tdm_columna_final.enmascarar='Y'
Rem                               para el esquema, toma como fuente tdm_excepcion_col (FORCE activos).
Rem    epurisaca   14/07/26 - Ajuste de política operativa de dependencias
Rem                           Sync de tdm_dependencia_final alineado con PRE/POST
Rem                           Preserva estado real ENABLED/DISABLED en triggers y constraints
Rem                           FK/CONSTRAINT y TRIGGER normales con política automática
Rem                           Objetos Oracle Text DR$ se mantienen como revisión especial
Rem
Rem    epurisaca    09/16/26 - Auditoría: se extrae pkg_dm_trazabilidad para romper acoplamiento
Rem                            (proc_dm_trace/proc_dm_log_ejec_error quedan como wrappers);
Rem                            proc_dm_enmascara_tabla crea una fila de ejecución real en vez de usar
Rem                            ejecucion_id=-1 (evita ORA-02291); propagación de dominios
Rem                            por FK pasa de fail-open a fail-closed (RAISE ante error)
Rem
Rem    epurisaca    09/18/26 - Prueba de volumen SRI2006: nombre de tarea
Rem                            DBMS_PARALLEL_EXECUTE basado en GUID (SUBSTR truncaba antes
Rem                            del sufijo único y colisionaba con ORA-29497); detección
Rem                            dinámica de riesgo de deadlock GES por trigger ENABLED de
Rem                            UPDATE (func_dm_tabla_tiene_trig_upd) que fuerza
Rem                            parallel_level=1 cuando aplica; distinción de ORA-06502 puro
Rem                            (-20321) frente a fallo genérico/deadlock (-20320) en chunks
Rem
Rem    epurisaca    09/20/26 - 09/21/26 - Recuperación real tras caída de sesión (ORA-03113)
Rem                            con 41/77 columnas ya enmascaradas; validada la reanudación
Rem                            selectiva (proc_dm_reanudar) sobre columnas ya confirmadas
Rem
Rem    epurisaca    09/22/26 - Corrección del marcador de traza de reanudación: el filtro
Rem                            de las 4 consultas de proc_dm_mask_cat que deciden qué
Rem                            columnas ya están confirmadas pasa de solicitud_id a
Rem                            ejecucion_id, evitando doble enmascarado en una segunda
Rem                            reanudación consecutiva sobre la misma solicitud
Rem
Rem    epurisaca    09/23/26 - Industrialización de proc_dm_ejecuta_update_seguro (validado
Rem                            contra producción real, hallazgos ): chunking por
Rem                            BLOQUES en vez de filas (by_row=>FALSE) con tamaño adaptativo
Rem                            al volumen de la tabla; soporte opcional de job_class
Rem                            (JC_DATAMASKING) para afinidad de instancia RAC, sin romper
Rem                            compatibilidad si el DBA aún no ha creado el servicio/clase
Rem
Rem    epurisaca    09/27/26 - Auditoría  (hallazgos Nivel 1): 1) proc_dm_ejecuta_update_seguro
Rem                            ya no se rinde ante un fallo PARCIAL de chunks paralelos -- antes de
Rem                            reportar error a proc_dm_apl_col (que reintentaría sobre TODA la tabla,
Rem                            re-tocando filas de chunks ya exitosos y comprometidos con FF1, perdiendo
Rem                            su reversibilidad sin dejar rastro), reintenta en serie, en la propia
Rem                            sesión orquestadora, acotado EXCLUSIVAMENTE al rowid de los chunks que
Rem                            fallaron; 2) homogeneización de errores en la ruta paralela: ORA-00001 y
Rem                            ORA-12899 (antes solo ORA-06502) que fallan en TODOS los chunks de una
Rem                            columna ahora se propagan con código propio (-20322/-20323) para que
Rem                            proc_dm_apl_col dispare su auto-exclusión también en tablas grandes
Rem                            (>100k filas, antes solo lo hacía en la ruta serie/directa); 3) proc_dm_enmascara_tabla
Rem                            gana guarda de concurrencia (proc_dm_validar_concurrencia, mismo patrón que
Rem                            proc_dm_enmascaramiento: fila ad-hoc se inserta en PENDIENTE, se valida y solo
Rem                            entonces se reclama a EJECUTANDO) y proc_dm_pre_dep acepta p_tablas_csv
Rem                            opcional para acotar qué dependencias deshabilita a las tablas realmente
Rem                            afectadas (antes deshabilitaba TODA dependencia del esquema aunque solo se
Rem                            enmascarara 1 tabla) -- proc_dm_enmascaramiento sigue sin pasar este parámetro y su
Rem                            comportamiento de esquema completo queda idéntico.
Rem
Rem    epurisaca    09/27/26 - Análisis de puntos críticos (autocancelación de huérfanas,
Rem                            purga de pepper, precedencia FORCE/EXCLUDE): 1) autocancelación
Rem                            de sesiones huérfanas ahora es responsabilidad global de
Rem                            pkg_dm_trazabilidad; proc_dm_refresca_sesion delega en ella y
Rem                            proc_dm_validar_concurrencia dispara el barrido al iniciar
Rem                            proc_dm_reanudar, igualando la cobertura que ya tenía descubrimiento;
Rem                            2) proc_dm_enmascaramiento purga automáticamente el pepper efímero
Rem                            (tdm_secreto) al llegar a FINALIZADO -- el export (07) no lo lee,
Rem                            así que no influye en esta decisión; proc_dm_pepper_purgar añade un
Rem                            guarda de estado (bloquea sobre EJECUTANDO con ORA-20099; exige
Rem                            p_confirma_abandono='Y' sobre ERROR/CANCELADO/PAUSADO/ABORTADA con
Rem                            ORA-20100; libre sobre FINALIZADO) para evitar borrar por error la
Rem                            semilla de una campaña aún reanudable; proc_dm_enmascara_tabla pasa
Rem                            p_confirma_abandono='Y' explícito en sus dos purgas (no tiene
Rem                            mecanismo de reanudación); 3) proc_dm_mask_cat: FORCE pasa a ser
Rem                            "vivo" igual que EXCLUDE en las 3 consultas de la rama
Rem                            l_has_final=1 (conteo, detección de SKIP_TABLE y cursor principal)
Rem                            mediante una CTE "objetivo" que une tdm_columna_final(Y) con las
Rem                            excepciones FORCE activas -- antes un FORCE nuevo sobre una columna
Rem                            aún en 'N' solo se recogía si el esquema no tenía ninguna columna en
Rem                            Y (caso casi inexistente tras el primer descubrimiento), obligando a
Rem                            re-descubrir para que el FORCE surtiera efecto
Rem
Rem    epurisaca    09/28/26 - Incidente en PREFORM (incident/incdir_175305, PID 50933):
Rem                            ORA-07445 [qctcopn_internal()+40] SIGSEGV -- el compilador de
Rem                            consultas de Oracle 19.28 revienta la sesion (ORA-03113 visto por
Rem                            el cliente SQL*Plus) al intentar transformar la CTE "objetivo"
Rem                            introducida el 09/27/26 en proc_dm_mask_cat (WITH... UNION ALL...
Rem                            func_dm_norm() dentro de un EXISTS correlado, fusionada con la consulta
Rem                            externa). Reproducido dos veces seguidas (ejecucion_id 7 y 8),
Rem                            siempre al arrancar, antes de tocar ninguna columna -- coincide con
Rem                            el trace: PL/SQL stack P_MASK_REANUDAR -> P_DM_ENMASCARA ->
Rem                            PROC_DM_MASK_CAT, SQL_ID de la consulta de conteo/skip. No es un
Rem                            error de nuestra logica (la consulta es semanticamente correcta;
Rem                            discovery, que no usa este patron, nunca falla) -- es un bug del
Rem                            optimizador ante esta forma concreta de SQL. Se añade /*+ MATERIALIZE */
Rem                            a las 3 apariciones de "WITH objetivo AS (...)" en proc_dm_mask_cat
Rem                            (conteo, deteccion SKIP_TABLE, cursor principal) para forzar la
Rem                            materializacion del CTE como segmento real y evitar la ruta de
Rem                            transformacion que provoca el volcado -- no cambia ningun resultado,
Rem                            solo la estrategia de ejecucion. Pendiente de que el usuario confirme
Rem                            en PREFORM que el hint evita el crash.
Rem
Rem    epurisaca    10/03/26 - Peer review seccion 8.1 ("doble-enmascarado en reanudacion de
Rem                            tablas/columnas grandes/chunked"), cierre: proc_dm_ejecuta_update_seguro
Rem                            generaba un GUID aleatorio distinto en CADA invocacion para el
Rem                            task_name de DBMS_PARALLEL_EXECUTE (fix 09/18/26, pensado solo para
Rem                            evitar el ORA-29497 de nombres truncados colisionando ENTRE columnas
Rem                            distintas) -- de paso, un GUID aleatorio hace que el motor nunca pueda
Rem                            detectar que una tarea anterior sobre esa MISMA columna quedo huerfana
Rem                            (sesion orquestadora muerta -- kill -9, caida de red, caida de instancia --
Rem                            entre RUN_TASK y el DROP_TASK final; cada chunk exitoso ya commiteo su
Rem                            parte de forma independiente). Al reanudar, se relanzaba sobre TODA la
Rem                            tabla y se reenmascaraba con FF1 lo que la tarea huerfana ya habia hecho.
Rem                            Se evaluaron las dos soluciones pedidas: (1) reutilizar automaticamente la
Rem                            tarea huerfana via RUN_TASK nativo -- descartada: un chunk cuyo worker
Rem                            moria con la caida puede quedar ASSIGNED de forma permanente, estado que
Rem                            DBMS_PARALLEL_EXECUTE no retoma solo y que solo un humano puede diagnosticar
Rem                            con certeza mirando USER_PARALLEL_EXECUTE_CHUNKS; (2) aplicada: task_name
Rem                            pasa a ser DETERMINISTICO (hash de owner.tabla.columna via
Rem                            DBMS_UTILITY.GET_HASH_VALUE, sin truncar -- no repite el bug de 09/18/26) y
Rem                            CREATE_TASK ahora falla cerrado (ORA-20330 propio) si choca con una tarea ya
Rem                            existente de esa misma columna, exigiendo que el DBA la inspeccione y la
Rem                            libere a mano (DROP_TASK) antes de que el motor la vuelva a tocar. Se añade
Rem                            tambien el flag l_tarea_propia: el EXCEPTION final del procedimiento solo
Rem                            limpia (DROP_TASK) la tarea si ESTA invocacion la creo, para que ese mismo
Rem                            manejador no borrase por "limpieza" la tarea huerfana que el fix anterior
Rem                            acaba de dejar visible a proposito. No se crea tabla ni flag de confirmacion
Rem                            nuevo: USER_PARALLEL_EXECUTE_TASKS/_CHUNKS ya son la fuente de verdad.
Rem                            Pendiente de validar en PREFORM/PRESAE: no reproducible en banco (requiere
Rem                            matar la sesion orquestadora a mitad de un chunking real >100k filas).
Rem 2026-10-07 (Reanudacion)   proc_dm_upd_sol: una solicitud con reintento_nro > 1 antepone siempre
Rem                            'Reanudacion: <n> | ' a TDM_MASK_SOLICITUD.DETALLE. Antes cada update de
Rem                            detalle ('Aplicando enmascaramiento', 'Proceso finalizado...') pisaba el texto
Rem                            'Reanudacion de ejecucion_id=N desde solicitud_id=M' y la marca se perdia.
Rem 2026-10-09 (Portabilidad 11g) llamada dinamica a pkg_dm_func_mask.func_dm_espec_doc_segun_tipo
Rem                            (antes func_dm_especial_doc_segun_tipo, 31 caracteres, PLS-00114 en 11g).
Rem 2026-10-10 (Reanudar) NUEVO func_dm_tareas_de_ejecucion. En la primera reanudacion real, la revision
Rem                            previa de dm_enmascara_reanudar.sql (que emparejaba tareas con DBA_PARALLEL_EXECUTE_TASKS.
Rem                            SQL_STMT) conto 0 tareas de la ejecucion mientras proc_dm_gestiona_tareas si la
Rem                            reconocio (leyendo USER_PARALLEL_EXECUTE_TASKS). Ahora el script pregunta aqui, con
Rem                            el mismo criterio que la reconciliacion.
Rem 2026-10-09 (Gestion de tareas) NUEVO proc_dm_gestiona_tareas (INFORMAR / RECONCILIAR / DESCARTAR): unica
Rem                            logica de tareas DBMS_PARALLEL_EXECUTE huerfanas. Resultado de las pruebas de
Rem                            kill E-02 (cada chunk confirma UPDATE+PROCESSED en un solo commit; reanudar no
Rem                            reprocesa PROCESSED; nivel 1 exige force, nivel 2 no). Los textos de ORA-20330 y
Rem                            ORA-20331 apuntan ahora a @dm_enmascara_reanudar / @dm_enmascara_cancel.
Rem 2026-10-09 (Privilegios)   ORA-01031 al modificar una tabla del esquema destino ahora dice la tabla y la concesion que
Rem                            falta (ORA-20350), y los errores MASK_APPLY guardan el backtrace (antes quedaba vacio).
Rem 2026-10-09 (Forzada corta) proc_dm_apl_col: una columna FORZADA cuyo largo es menor al minimo del
Rem                            identificador ya NO reescribe su FORCE como EXCLUDE (la regla del DBA se
Rem                            conserva) y deja traza WARN SKIP_AUTO_LEN (antes INFO): dato sensible que
Rem                            queda sin enmascarar debe verse en el resumen. Hallazgo L-07 (COD_ACCESO_CORTO).
Rem 2026-10-07 (Obsoleta)      PRE-FLIGHT: clasifica como OBSOLETA una tarea huerfana cuyos chunks apuntan
Rem                            a otro data_object_id que la tabla actual (esquema recargado / tabla recreada,
Rem                            truncada o movida): ya no dice "YA HAY FILAS CIFRADAS" cuando no es cierto.
Rem                            Solo clasifica; sigue bloqueando (CREATE_TASK chocaria por nombre igual).
Rem 2026-10-07 (Fase 1)        PRE-FLIGHT de tareas huerfanas + columnas fallidas no cuentan como
Rem                            procesadas (incidente real DM_DUMMY ejecucion_id=1: CUENTA_CCC fallo con
Rem                            ORA-20330 por una reliquia TDM_<hash> y aun asi sumo a columnas_procesadas /
Rem                            ULTIMO_OBJETO; el run quedo contaminado con el resto del esquema ya
Rem                            enmascarado). (1) proc_dm_enmascaramiento, antes de proc_dm_pre_dep y del
Rem                            pepper, recorre USER_PARALLEL_EXECUTE_TASKS (TDM_%), correlaciona por hash
Rem                            cada tarea con las columnas objetivo del esquema (TDM_COLUMNA_FINAL Y +
Rem                            FORCE vivos) y, si alguna es una huerfana que este run tocaria (no EXCLUDE,
Rem                            no ya confirmada en la ejecucion), aborta con ORA-20331 SIN tocar datos,
Rem                            listando estado de tarea y conteo de chunks (PROCESSED/ASSIGNED/UNASSIGNED/
Rem                            CON_ERROR); traza PREFLIGHT_ORFANA/ABORT/INFO/OK. Solo diagnostica: no
Rem                            reanuda ni borra (la reconciliacion automatica queda para una fase posterior
Rem                            tras las pruebas de kill E-01/E-02). (2) proc_dm_mask_cat: una columna cuyo
Rem                            proc_dm_apl_col lanza excepcion (cualquier error, no solo ORA-20330) ya no
Rem                            avanza l_proc_cols/porcentaje/columnas_procesadas/ULTIMO_OBJETO; se sigue
Rem                            registrando en TDM_EJECUCION_ERROR/TDM_MASK_TRACE, p_error_count>0 fuerza
Rem                            ERROR/CON_ERRORES, y el RESUMEN informa 'columnas fallidas'. No cambia que
Rem                            columnas se reintentan al reanudar (solo depende de APPLY_COL en el trace).


create or replace PACKAGE pkg_dm_enmascarar AS

  FUNCTION func_dm_norm(
    p_txt IN VARCHAR2
  ) RETURN VARCHAR2 DETERMINISTIC;

-- (reglas especiales muertas eliminadas: se usan pkg_dm_func_mask.func_especial_*)

  PROCEDURE proc_dm_enmascaramiento(
    p_ejecucion_id IN NUMBER,
    p_reproceso    IN VARCHAR2 DEFAULT 'N',
    p_commit_lote  IN NUMBER DEFAULT 1000
  );

  PROCEDURE proc_dm_cancelar(
    p_ejecucion_id IN NUMBER
  );

  -- Diagnostica y gestiona las tareas DBMS_PARALLEL_EXECUTE (TDM_<hash>) que una
  -- ejecucion interrumpida deja detras. Es la unica logica de tareas huerfanas del
  -- motor: la usan dm_monitor (INFORMAR), dm_enmascara_reanudar (RECONCILIAR) y
  -- dm_enmascara_cancel (DESCARTAR). NO mata sesiones (eso exige ALTER SYSTEM y lo
  -- hacen los scripts con el privilegio de quien los ejecuta).
  --   INFORMAR    solo lectura: estado de la ejecucion, de cada tarea y desde donde se reanudaria.
  --   RECONCILIAR termina las tareas recuperables con RESUME_TASK (force si estan en
  --               PROCESSING), registra cada columna como hecha (APPLY_COL) y borra la
  --               tarea. Se niega (ORA-20342) si la sesion principal sigue viva y falla
  --               (ORA-20343) si alguna tarea no se pudo resolver.
  --   DESCARTAR   borra las tareas de la ejecucion SIN reanudarlas (anulacion total).
  PROCEDURE proc_dm_gestiona_tareas(
    p_ejecucion_id IN NUMBER,
    p_modo         IN VARCHAR2 DEFAULT 'INFORMAR'
  );

  -- func_dm_tareas_de_ejecucion: nombres (separados por coma, orden alfabetico) de las tareas
  --   DBMS_PARALLEL_EXECUTE (TDM_<hash>) de este esquema cuyo SQL de chunk lleva
  --   proc_dm_set_ejecucion(<p_ejecucion_id>). NULL si no hay ninguna. Solo lectura.
  FUNCTION func_dm_tareas_de_ejecucion(
    p_ejecucion_id IN NUMBER
  ) RETURN VARCHAR2;

  PROCEDURE proc_dm_reanudar(
    p_ejecucion_id IN NUMBER,
    p_commit_lote  IN NUMBER DEFAULT 1000
  );

  PROCEDURE proc_dm_enmascara_tabla(
    p_esquema       IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_identificador IN VARCHAR2,
    p_columna       IN VARCHAR2 DEFAULT NULL,
    p_commit_lote   IN NUMBER   DEFAULT 1000
  );

  -- Purga la semilla efimera de ESTA ejecución. Desde el 09/27/26, proc_dm_enmascaramiento
  -- la autopurga al llegar a FINALIZADO (ni la validacion ni el export, paquete
  -- 07 y fuera del flujo, necesitan el pepper). p_confirma_abandono='Y'
  -- es obligatorio para purgar una ejecución en ERROR/CANCELADO/PAUSADO/ABORTADA
  -- (podria reanudarse con proc_dm_reanudar reutilizando el mismo pepper);
  -- purgar una EJECUTANDO esta bloqueado siempre, sin excepcion.
  PROCEDURE proc_dm_pepper_purgar(
    p_ejecucion_id      IN NUMBER,
    p_confirma_abandono IN VARCHAR2 DEFAULT 'N'
  );

  PROCEDURE proc_dm_trace(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_fase         IN VARCHAR2,
    p_paso         IN VARCHAR2,
    p_detalle      IN VARCHAR2,
    p_duracion_seg  IN NUMBER   DEFAULT NULL
  );

  PROCEDURE proc_dm_log_ejec_error(
    p_ejecucion_id IN NUMBER,
    p_owner_name   IN VARCHAR2,
    p_table_name   IN VARCHAR2,
    p_column_name  IN VARCHAR2,
    p_etapa        IN VARCHAR2,
    p_codigo_error IN NUMBER,
    p_mensaje      IN VARCHAR2,
    p_backtrace    IN VARCHAR2,
    p_solicitud_id IN NUMBER DEFAULT NULL
  );

END pkg_dm_enmascarar;
/

create or replace PACKAGE BODY pkg_dm_enmascarar AS

  g_resume_base_solicitud NUMBER;
  g_dep_has_categoria_uso   NUMBER;
  g_dep_has_accion_pre_mask NUMBER;
  g_dep_has_accion_post_mask NUMBER;
  g_ejec_actual              NUMBER;   -- ejecución activa: se inyecta a cada worker paralelo
  g_ruta                     VARCHAR2(400);   -- traza: ruta elegida por proc_dm_ejecuta_update_seguro para la ultima columna

  ------------------------------------------------------------------------------
  -- Helpers seguros
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_norm
  -- PROPOSITO    : Normaliza un texto a mayusculas y sin espacios laterales para comparar
  --                identificadores de forma uniforme.
  -- ENTRADAS     : p_txt; retorna UPPER(TRIM(p_txt), DETERMINISTIC).
  -- LEE          : ninguno
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: helper usado por casi todas las unidades del paquete (csv_item, qname,
  --                expr_gen_sql, apl_col, mask_cat, enmascaramiento, gestiona_tareas, pre_dep,
  --                pepper_purgar, etc.); sin llamadas externas (07_dm_pkg_export tiene su propia
  --                copia).
  ------------------------------------------------------------------------------
  FUNCTION func_dm_norm(p_txt IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    RETURN UPPER(TRIM(p_txt));
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_safe_err
  -- PROPOSITO    : Aplana un mensaje de error (quita saltos de linea, lo acota a 1800 caracteres)
  --                para guardarlo en trazas y columnas de error.
  -- ENTRADAS     : p_err; retorna texto de una linea, o SIN_ERROR si es nulo.
  -- LEE          : ninguno
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento, proc_dm_enmascara_tabla, proc_dm_mask_cat,
  --                proc_dm_apl_col, proc_dm_post_sync, proc_dm_upd_ejec, proc_dm_close_sol_open.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_safe_err(p_err IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    RETURN SUBSTR(REPLACE(REPLACE(NVL(p_err,'SIN_ERROR'), CHR(10), ' '), CHR(13), ' '), 1, 1800);
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_safe_name
  -- PROPOSITO    : Devuelve un nombre de objeto acotado a 256 caracteres (o ? si es nulo) para
  --                componer mensajes de traza sin romper longitudes.
  -- ENTRADAS     : p_txt; retorna texto acotado.
  -- LEE          : ninguno
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_pre_dep y proc_dm_post_dep (mensajes de traza).
  ------------------------------------------------------------------------------
  FUNCTION func_dm_safe_name(p_txt IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    RETURN SUBSTR(NVL(TRIM(p_txt), '?'), 1, 256);
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_qname
  -- PROPOSITO    : Valida y entrecomilla un identificador SQL con DBMS_ASSERT para poder concatenarlo
  --                con seguridad en SQL dinamico.
  -- ENTRADAS     : p_name; retorna el nombre en mayusculas entre comillas dobles.
  -- LEE          : ninguno
  -- ESCRIBE      : ninguno
  -- ERRORES      : ORA-20060 si el nombre no es un identificador SQL simple valido (cualquier error
  --                de DBMS_ASSERT se convierte a este codigo).
  -- LLAMADO DESDE: Interno: proc_dm_apl_col, proc_dm_ejecuta_update_seguro, proc_dm_post_sync,
  --                proc_dm_pre_dep, proc_dm_post_dep, func_dm_expr_compatible. Otros archivos
  --                (dm_validar_flujo.sql, tests) solo lo citan en comentarios como convencion.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_qname(p_name IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN DBMS_ASSERT.ENQUOTE_NAME(
             DBMS_ASSERT.SIMPLE_SQL_NAME(func_dm_norm(p_name)),
             FALSE
           );
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20060, 'Nombre SQL invalido: '||SUBSTR(NVL(p_name,'NULL'),1,120));
  END;

  ------------------------------------------------------------------------------
  -- SEMILLA EFIMERA (PEPPER) POR ejecución (ejecucion_id)
  -- Cada ejecución usa su propia fila 'PEPPER_MASK:'||ejecucion_id, de modo que dos
  -- esquemas enmascarados a la vez tienen peppers independientes (sin carrera ni
  -- purga cruzada). Se genera al inicio (idempotente para el resume) con COMMIT
  -- antes del paralelo, y se purga por-ejecución tras el export.
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_pepper_generar
  -- PROPOSITO    : Crea (si no existe) la semilla efimera PEPPER_MASK:<ejecucion_id> con 256 bits
  --                aleatorios y fija la ejecucion activa para los workers y el coordinador.
  -- ENTRADAS     : p_ejecucion_id.
  -- LEE          : TDM_SECRETO
  -- ESCRIBE      : TDM_SECRETO (INSERT + COMMIT); variable de paquete g_ejec_actual; contexto de
  --                pkg_dm_func_mask.proc_dm_set_ejecucion
  -- ERRORES      : Sin RAISE_APPLICATION_ERROR; DUP_VAL_ON_INDEX (carrera) se ignora y se conserva la
  --                fila existente; cualquier otro error se propaga.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento (tras proc_dm_propaga_dominios) y
  --                proc_dm_enmascara_tabla.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_pepper_generar(p_ejecucion_id IN NUMBER) IS
    l_clave VARCHAR2(64) := 'PEPPER_MASK:'||TO_CHAR(p_ejecucion_id);
    l_cnt   NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_cnt FROM tdm_secreto WHERE clave = l_clave;
    IF l_cnt = 0 THEN
      BEGIN
        -- CSPRNG 256 bits -> 64 hex.
        INSERT INTO tdm_secreto (clave, valor)
        VALUES (l_clave, RAWTOHEX(DBMS_CRYPTO.RANDOMBYTES(32)));
        COMMIT;   -- imprescindible ANTES de lanzar los workers paralelos
      EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
          NULL;   -- carrera: otra sesion creo la fila de ESTE ejec; se conserva
      END;
    END IF;
    g_ejec_actual := p_ejecucion_id;                 -- para el wrap del chunk paralelo
    pkg_dm_func_mask.proc_dm_set_ejecucion(p_ejecucion_id);  -- para updates directos del coordinador
  END;

  -- 2026-09-27: guarda de estado. Antes de este cambio se borraba el pepper
  -- sin comprobar nada -- una purga mal sincronizada sobre una ejecución viva
  -- o reanudable rompia el dominio FF1 (filas ya enmascaradas con el pepper
  -- viejo, filas pendientes con uno nuevo tras un proc_dm_reanudar posterior).
  -- EJECUTANDO: bloqueo duro, nunca se purga una ejecución con workers activos.
  -- ERROR/CANCELADO/PAUSADO/ABORTADA: reanudable en teoria (proc_dm_reanudar
  -- reutiliza el pepper); exige p_confirma_abandono='Y' como decision
  -- explicita y trazable de que esa ejecución NO se va a reanudar.
  -- FINALIZADO (o ejecucion_id ya inexistente): purga libre.
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_pepper_purgar
  -- PROPOSITO    : Borra la semilla efimera de UNA ejecucion, con guarda de estado para no destruir
  --                un pepper que aun puede necesitarse.
  -- ENTRADAS     : p_ejecucion_id; p_confirma_abandono (Y obligatorio si la ejecucion esta en
  --                ERROR/CANCELADO/PAUSADO/ABORTADA).
  -- LEE          : TDM_EJECUCION
  -- ESCRIBE      : TDM_SECRETO (DELETE de la clave PEPPER_MASK:<id> + COMMIT)
  -- ERRORES      : ORA-20099 si la ejecucion esta EJECUTANDO (bloqueo duro).; ORA-20100 si esta en
  --                ERROR/CANCELADO/PAUSADO/ABORTADA sin p_confirma_abandono=Y.; Ejecucion inexistente
  --                o FINALIZADA: purga libre.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento (autopurga al FINALIZAR, best-effort) y
  --                proc_dm_enmascara_tabla (con Y, en exito y en fallo). Externo:
  --                dm_pepper_purgar.sql.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_pepper_purgar(
    p_ejecucion_id      IN NUMBER,
    p_confirma_abandono IN VARCHAR2 DEFAULT 'N'
  ) IS
    l_estado tdm_ejecucion.estado%TYPE;
  BEGIN
    BEGIN
      SELECT estado INTO l_estado FROM tdm_ejecucion WHERE ejecucion_id = p_ejecucion_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_estado := NULL;   -- sin fila que proteger: se permite purgar
    END;

    IF func_dm_norm(l_estado) = 'EJECUTANDO' THEN
      RAISE_APPLICATION_ERROR(-20099,
        'No se puede purgar el pepper de ejecucion_id='||p_ejecucion_id||
        ': la ejecución sigue EJECUTANDO. Cancele o espere a que finalice.');
    ELSIF func_dm_norm(l_estado) IN ('ERROR','CANCELADO','PAUSADO','ABORTADA')
          AND func_dm_norm(NVL(p_confirma_abandono,'N')) <> 'Y' THEN
      RAISE_APPLICATION_ERROR(-20100,
        'ejecucion_id='||p_ejecucion_id||' esta en estado '||l_estado||
        ' y podria reanudarse con proc_dm_reanudar reutilizando el mismo pepper. '||
        'Llame proc_dm_pepper_purgar('||p_ejecucion_id||',''Y'') solo si confirma que NO se reanudara.');
    END IF;

    -- Borra SOLO el secreto de esta ejecución.
    DELETE FROM tdm_secreto WHERE clave = 'PEPPER_MASK:'||TO_CHAR(p_ejecucion_id);
    COMMIT;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_csv_item
  -- PROPOSITO    : Extrae el elemento N de una lista separada por comas, normalizado, para iterar
  --                tablas y columnas pasadas como CSV.
  -- ENTRADAS     : p_lista, p_pos; retorna el elemento normalizado o NULL si no existe.
  -- LEE          : ninguno
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_enmascara_tabla (listas p_tabla y p_columna).
  ------------------------------------------------------------------------------
  FUNCTION func_dm_csv_item(p_lista IN VARCHAR2, p_pos IN PLS_INTEGER) RETURN VARCHAR2 IS
  BEGIN
    RETURN func_dm_norm(REGEXP_SUBSTR(NVL(p_lista,''), '[^,]+', 1, p_pos));
  END;

  -- FIX 2026-09-18 (prueba de volumen SRI2006): deteccion conservadora de
  -- riesgo de deadlock GES en RAC. Un trigger ENABLED de UPDATE puede
  -- recalcular agregados de negocio por CLAVE DE NEGOCIO (no por rowid/PK),
  -- lo cual es incompatible con el supuesto de independencia por fila de
  -- DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID: dos workers pueden acabar
  -- bloqueandose mutuamente vía el mismo trigger sobre filas "hermanas" de
  -- negocio aunque sus rangos de rowid no se solapen. Confirmado en
  -- produccion (trace LMD0 preform1_lmd0_55892.trc, 77 deadlocks GES sobre
  -- SRI_DEUDAS_DETALLE / SRI_CARTAS_PAGO_DEUDA). Fallo cerrado: ante
  -- cualquier duda o error de metadata, se asume riesgo (RETURN 'Y') y el
  -- llamador fuerza ejecucion en serie — mas lento en el peor caso, nunca
  -- corrompe datos ni bloquea instancias RAC.
  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_tabla_tiene_trig_upd
  -- PROPOSITO    : Indica si una tabla tiene triggers de UPDATE habilitados, para forzar ejecucion en
  --                serie y evitar deadlocks GES en RAC.
  -- ENTRADAS     : p_owner, p_tabla; retorna Y o N.
  -- LEE          : DBA_TRIGGERS
  -- ESCRIBE      : ninguno
  -- ERRORES      : Fallo cerrado: ante cualquier error devuelve Y (asume riesgo).
  -- LLAMADO DESDE: Interno: proc_dm_ejecuta_update_seguro (nivel de paralelismo) y
  --                proc_dm_gestiona_tareas (modo RECONCILIAR).
  ------------------------------------------------------------------------------
  FUNCTION func_dm_tabla_tiene_trig_upd(
    p_owner IN VARCHAR2,
    p_tabla IN VARCHAR2
  ) RETURN VARCHAR2 IS
    l_cnt NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO l_cnt
      FROM dba_triggers
     WHERE table_owner = func_dm_norm(p_owner)
       AND table_name  = func_dm_norm(p_tabla)
       AND status       = 'ENABLED'
       AND UPPER(triggering_event) LIKE '%UPDATE%';

    RETURN CASE WHEN l_cnt > 0 THEN 'Y' ELSE 'N' END;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'Y';
  END func_dm_tabla_tiene_trig_upd;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_ejecuta_update_seguro
  -- PROPOSITO    : Ejecuta el UPDATE de enmascarado de una columna: directo si la tabla es pequena o
  --                IOT, y con DBMS_PARALLEL_EXECUTE por chunks si supera 100000 filas.
  -- ENTRADAS     : p_owner, p_tabla, p_columna, p_sql_base (UPDATE ya construido, sin rowid);
  --                p_rows_out OUT (filas, aproximado en ruta paralela).
  -- LEE          : DBA_TABLES; DBA_TRIGGERS (via func_dm_tabla_tiene_trig_upd);
  --                USER_PARALLEL_EXECUTE_CHUNKS; DBA_SCHEDULER_JOB_CLASSES; tabla objetivo (COUNT(*)
  --                solo si faltan estadisticas)
  -- ESCRIBE      : UPDATE sobre la tabla/columna objetivo (directo o por chunks de rowid);
  --                DBMS_PARALLEL_EXECUTE: CREATE_TASK, CREATE_CHUNKS_BY_ROWID, RUN_TASK, RESUME_TASK,
  --                DROP_TASK (tarea TDM_<hash>); variable de paquete g_ruta
  -- ERRORES      : ORA-20330 tarea paralela huerfana (ORA-29497 en CREATE_TASK): no reanuda
  --                automaticamente.; ORA-20321 / ORA-20322 / ORA-20323 si TODOS los chunks fallidos
  --                son ORA-06502 / ORA-00001 / ORA-12899.; ORA-20320 enmascarado paralelo incompleto
  --                (cualquier otro patron de fallo).; ORA-20350 si el UPDATE falla con ORA-01031 (el
  --                duenio del motor carece de UPDATE directo sobre la tabla).; Reintento en serie
  --                acotado a los chunks fallidos antes de abortar; limpia la tarea solo si la creo
  --                esta invocacion.
  -- LLAMADO DESDE: Interno: proc_dm_apl_col y proc_dm_post_sync.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_ejecuta_update_seguro(
    p_owner    IN VARCHAR2,
    p_tabla    IN VARCHAR2,
    p_columna  IN VARCHAR2,
    p_sql_base IN VARCHAR2,
    p_rows_out OUT NUMBER
  ) IS
    l_row_count NUMBER;
    l_iot_type  VARCHAR2(30);
    l_task_name VARCHAR2(100);
    l_sql_chunk VARCHAR2(32767);
    l_stmt_check VARCHAR2(1000);
    l_parallel_level NUMBER;       -- FIX 2026-09-18: dinamico segun riesgo de trigger UPDATE
    l_estado_tarea  NUMBER;        -- C-02: estado terminal de la tarea paralela
    l_chunks_error  NUMBER;        -- C-02: nro de chunks PROCESSED_WITH_ERROR
    l_chunks_error_6502 NUMBER;    -- FIX 2026-09-18: nro de esos chunks cuyo error es ORA-06502
    l_chunks_error_1    NUMBER;    -- FIX 2026-09-27: nro de esos chunks cuyo error es ORA-00001
    l_chunks_error_12899 NUMBER;   -- FIX 2026-09-27: nro de esos chunks cuyo error es ORA-12899
    l_detalle_error VARCHAR2(400); -- C-02: ejemplo de error de chunk (diagnostico)
    l_chunk_blocks  NUMBER;        -- FIX 2026-09-23: tamaño de chunk adaptativo (en BLOQUES, by_row=>FALSE)
    l_job_class_exists NUMBER;     -- FIX 2026-09-23: JC_DATAMASKING es OPCIONAL (afinidad RAC), nunca bloqueante
    l_retry_all_ok  BOOLEAN;       -- FIX 2026-09-27: reintento serie acotado a chunks fallidos (ver mas abajo)
    l_tarea_propia  BOOLEAN := FALSE; -- FIX 2026-10-03 (8.1): TRUE solo si ESTA invocacion creo la tarea (ver EXCEPTION final)
    l_chunks_total  NUMBER;        -- traza: nro de chunks de la tarea
  BEGIN
    g_ruta := NULL;
    -- 1. Obtener número aproximado de filas e iot_type de la tabla
    l_stmt_check := 'SELECT num_rows, iot_type FROM dba_tables WHERE owner = :1 AND table_name = :2';
    BEGIN
      EXECUTE IMMEDIATE l_stmt_check INTO l_row_count, l_iot_type USING func_dm_norm(p_owner), func_dm_norm(p_tabla);
    EXCEPTION
      WHEN OTHERS THEN
        l_row_count := NULL;
        l_iot_type  := NULL;
    END;

    IF l_row_count IS NULL OR l_row_count = 0 THEN
      BEGIN
        -- HINT 2026-09-18: PARALLEL aqui es seguro porque es una sola consulta
        -- diagnostica en la sesion orquestadora (decide si activar
        -- DBMS_PARALLEL_EXECUTE), NUNCA dentro de un worker paralelo -
        -- distinto del UPDATE por chunk, donde SI se evita a proposito
        -- (ver comentario en RUN_TASK) para no multiplicar procesos
        -- paralelos dentro de sesiones ya paralelas. Solo se alcanza este
        -- fallback cuando dba_tables no tiene num_rows (stats ausentes o en
        -- 0), tipicamente tablas grandes recien cargadas sin ANALYZE.
        EXECUTE IMMEDIATE 'SELECT /*+ PARALLEL(4) */ COUNT(*) FROM '||func_dm_qname(p_owner)||'.'||func_dm_qname(p_tabla) INTO l_row_count;
      EXCEPTION
        WHEN OTHERS THEN
          l_row_count := 0;
      END;
    END IF;

    -- 2. Si la tabla supera el umbral (100,000 registros) y NO es una tabla IOT (Index-Organized), usar DBMS_PARALLEL_EXECUTE
    -- De lo contrario, usar EXECUTE IMMEDIATE estándar
    IF l_row_count > 100000 AND l_iot_type IS NULL THEN
      -- FIX 2026-09-18 (ver tambien FIX 2026-10-03 inmediatamente abajo):
      -- nombre de tarea basado en GUID. La version anterior (SUBSTR con
      -- nombre de tabla/columna + GET_TIME truncado a 30 chars) cortaba ANTES
      -- del sufijo temporal unico para tablas/columnas largas, provocando
      -- colisiones ORA-29497 con tareas homonimas (incl. tareas huerfanas de
      -- una ejecucion previa interrumpida). El contexto tabla/columna ya queda
      -- trazado en tdm_ejecucion_error/proc_dm_trace, asi que el nombre
      -- interno de la tarea Oracle solo necesita ser unico.
      --
      -- FIX 2026-10-03 (peer review seccion 8.1, "doble-enmascarado en
      -- reanudacion de tablas/columnas grandes/chunked"): el GUID aleatorio
      -- de arriba resolvio el ORA-29497 de 2026-09-18, pero de paso elimino
      -- la UNICA señal que el motor tenia (por accidente) para detectar una
      -- tarea huerfana: con nombre aleatorio, CREATE_TASK nunca vuelve a
      -- chocar con una tarea anterior, pase lo que pase. Si la sesion
      -- orquestadora moria entre RUN_TASK y el DROP_TASK final de este mismo
      -- procedimiento (kill -9, caida de red, caida de instancia -- el
      -- EXCEPTION WHEN OTHERS de mas abajo nunca llega a ejecutarse en ese
      -- escenario porque la sesion completa deja de existir), la tarea
      -- quedaba huerfana en USER_PARALLEL_EXECUTE_TASKS con parte de sus
      -- chunks ya PROCESSED (cada chunk exitoso commitea de forma
      -- independiente al terminar, ver comentario de RUN_TASK mas abajo). Al
      -- reanudar, este procedimiento se volvia a invocar para la MISMA
      -- columna, generaba OTRO GUID aleatorio distinto y relanzaba
      -- CREATE_CHUNKS_BY_ROWID sobre TODA la tabla desde cero -- reenmascarando
      -- con FF1 las filas que la tarea huerfana ya habia completado (doble
      -- cifrado, se pierde la reversibilidad del dominio FF1 sin dejar
      -- rastro de que ocurrio).
      --
      -- Se evaluaron las dos soluciones pedidas explicitamente:
      -- (1) Detectar la tarea huerfana y REUTILIZARLA de forma automatica
      --     (RUN_TASK nativo de Oracle ya salta los chunks PROCESSED y solo
      --     reprocesa UNASSIGNED/PROCESSED_WITH_ERROR). Se descarta como
      --     automatismo: si el worker de un chunk moria junto con la caida
      --     (no solo el coordinador), ese chunk puede quedar en estado
      --     ASSIGNED de forma permanente -- DBMS_PARALLEL_EXECUTE no lo trata
      --     ni como pendiente ni como error, por diseño, y RUN_TASK no lo
      --     retoma solo. Decidir si eso ocurrio (y resetear ese chunk a mano)
      --     exige que un humano mire USER_PARALLEL_EXECUTE_CHUNKS del
      --     task_name concreto -- automatizarlo a ciegas aqui seria abrir un
      --     riesgo nuevo para cerrar el que ya existe.
      -- (2) Por eso se implementa esta alternativa: nombre de tarea
      --     DETERMINISTICO (hash estable de owner.tabla.columna -- NUNCA
      --     truncado, para no repetir el bug de colision de 2026-09-18 entre
      --     columnas DISTINTAS; aqui la "colision" es intencional y consigo
      --     misma) + fallo cerrado si CREATE_TASK choca con ese nombre: solo
      --     puede significar que una invocacion anterior para esta MISMA
      --     columna hizo CREATE_TASK pero nunca llego al DROP_TASK final --
      --     la firma exacta de una sesion muerta a mitad. Se exige entonces
      --     confirmacion manual explicita: el DBA debe inspeccionar
      --     USER_PARALLEL_EXECUTE_CHUNKS para ese task_name, decidir el
      --     camino seguro (reanudar a mano con DBMS_PARALLEL_EXECUTE.RUN_TASK/
      --     RESUME_TASK si los chunks estan limpios, o resetear a mano los que
      --     quedaron ASSIGNED) y el propio DBMS_PARALLEL_EXECUTE.DROP_TASK
      --     manual que haga al terminar es lo que libera el nombre para que
      --     el motor pueda volver a tomar esta columna. No se crea ninguna
      --     tabla ni flag nuevo: USER_PARALLEL_EXECUTE_TASKS ya es la fuente
      --     de verdad; el nombre deterministico es lo unico que faltaba para
      --     poder consultarla por columna, y se reutiliza el propio
      --     ORA-29497 de Oracle (el mismo codigo que ya aparecia en
      --     produccion en 2026-09-18, ahora REINTERPRETADO como señal util en
      --     vez de ruido a evitar) en vez de un SELECT propio contra
      --     USER_PARALLEL_EXECUTE_TASKS, para no introducir una ventana de
      --     carrera entre ese SELECT y el CREATE_TASK.
      --
      -- Supuesto que se apoya en este fix (ya garantizado por los controles
      -- de exclusividad existentes en el motor, no nuevo aqui): no puede
      -- haber dos invocaciones LEGITIMAS y simultaneas de este procedimiento
      -- sobre la misma owner.tabla.columna -- por eso una colision de nombre
      -- solo puede ser una huerfana, nunca una concurrencia valida.
      l_task_name := 'TDM_'||TO_CHAR(DBMS_UTILITY.GET_HASH_VALUE(
                        UPPER(p_owner)||'.'||UPPER(p_tabla)||'.'||UPPER(p_columna),
                        1, 1000000000));

      -- Crear tarea. ORA-29497 aqui ya NO es ruido a esconder (ver FIX
      -- 2026-10-03 arriba): con nombre deterministico, solo puede significar
      -- una tarea huerfana de esta misma columna de una ejecucion anterior
      -- interrumpida.
      BEGIN
        DBMS_PARALLEL_EXECUTE.CREATE_TASK(task_name => l_task_name);
      EXCEPTION
        WHEN OTHERS THEN
          IF SQLCODE = -29497 THEN
            RAISE_APPLICATION_ERROR(-20330,
              'Tarea paralela pendiente detectada para '||p_owner||'.'||p_tabla||'.'||p_columna||
              ' (task_name='||l_task_name||'). Esto indica que una ejecucion anterior sobre esta '||
              'misma columna NO finalizo de forma limpia (la sesion orquestadora murio antes del '||
              'DROP_TASK final; parte de los chunks puede ya estar enmascarada con FF1). Para '||
              'evitar un doble enmascarado, el motor NO reanuda esta columna de forma automatica. '||
              'Diagnostico: @dm_monitor <ejecucion_id>. Para continuar sin reprocesar los chunks ya '||
              'cifrados use @dm_enmascara_reanudar <ejecucion_id> (reconcilia esta tarea, task_name='||
              l_task_name||'); para abandonar la ejecucion use @dm_enmascara_cancel <ejecucion_id> '||
              'CONFIRMAR DESCARTAR (restaure antes el dato).');
          ELSE
            RAISE;
          END IF;
      END;
      -- A partir de aqui la tarea SI es propia de esta invocacion (CREATE_TASK
      -- no choco con ninguna huerfana) -- el EXCEPTION final de este
      -- procedimiento puede limpiarla sin riesgo si algo falla mas adelante.
      l_tarea_propia := TRUE;

      -- FIX 2026-09-23 (industrializacion, hallazgo  validado contra
      -- produccion real): by_row=>TRUE obliga a Oracle a ESTIMAR cuantas filas
      -- caen en cada rango de rowid (escaneo/estadistica adicional por chunk) y
      -- el chunk_size=50000 fijo anterior no se adaptaba al volumen real de cada
      -- tabla (mismo tamaño para una tabla de 200k filas que para una de 80M).
      -- by_row=>FALSE trocea por BLOQUES fisicos de datos (mas barato: no
      -- requiere esa estimacion de filas) y chunk_size pasa a interpretarse en
      -- BLOQUES, no en filas. El tamaño se adapta con l_row_count (ya calculado
      -- arriba) para no generar ni chunks pequeños de más (overhead de
      -- coordinacion DBMS_PARALLEL_EXECUTE) ni chunks grandes de menos
      -- (paralelismo real insuficiente) segun el volumen de la tabla.
      IF l_row_count > 10000000 THEN
        l_chunk_blocks := 20000;
      ELSIF l_row_count > 1000000 THEN
        l_chunk_blocks := 8000;
      ELSE
        l_chunk_blocks := 2000;
      END IF;

      -- Crear chunks por BLOQUES (no por filas estimadas), tamaño adaptativo
      DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(
        task_name   => l_task_name,
        table_owner => func_dm_norm(p_owner),
        table_name  => func_dm_norm(p_tabla),
        by_row      => FALSE,
        chunk_size  => l_chunk_blocks
      );

      -- Construir sentencia SQL para el chunk
      -- Cada worker es una sesion propia: fija su ejecucion_id ANTES del UPDATE
      -- para leer el pepper de la ejecución correcta (el ejec es un literal numerico).
      l_sql_chunk := 'BEGIN pkg_dm_func_mask.proc_dm_set_ejecucion('||
                     CASE WHEN g_ejec_actual IS NULL THEN 'NULL' ELSE TO_CHAR(g_ejec_actual) END||
                     '); '||p_sql_base||' AND rowid BETWEEN :start_id AND :end_id; END;';

      -- FIX 2026-09-18: parallel_level dinamico. Con 2 workers fijos, dos
      -- chunks de una tabla con trigger de UPDATE por clave de negocio
      -- pueden deadlockear entre si (GES) aunque sus rangos de rowid no se
      -- solapen. Si se detecta ese riesgo se fuerza serie (1); si no, se
      -- mantiene el paralelismo original de 2 (uno por instancia RAC).
      IF func_dm_tabla_tiene_trig_upd(p_owner, p_tabla) = 'Y' THEN
        l_parallel_level := 1;
      ELSE
        l_parallel_level := 2;
      END IF;

      -- FIX 2026-09-23 (industrializacion, hallazgo ): soporte OPCIONAL
      -- de job_class para afinidad de instancia RAC. Si existe una job_class
      -- llamada JC_DATAMASKING (creada FUERA de este motor, por el DBA, via
      -- srvctl add/start service + DBMS_SCHEDULER.CREATE_JOB_CLASS ligada a ese
      -- servicio; ver plan de servicio RAC), los workers paralelos se ejecutan
      -- en esa clase y quedan afines a la instancia del servicio (menos
      -- "gc current block/grant" de RAC, ver AWR report_datamasking_biy.txt).
      -- Es un REQUISITO RECOMENDADO, NO obligatorio: si la job_class no existe
      -- (caso por defecto, ningun servicio RAC creado todavia), se cae de forma
      -- transparente al RUN_TASK original sin job_class. Nunca bloquea la
      -- ejecucion por falta de infraestructura RAC opcional.
      SELECT COUNT(*) INTO l_chunks_total
        FROM user_parallel_execute_chunks
       WHERE task_name = l_task_name;
      g_ruta := 'CHUNKS [> 100k filas] - filas_estimadas='||l_row_count||', bloques_por_chunk='||l_chunk_blocks||
                ', chunks='||l_chunks_total||', nivel_paralelismo='||l_parallel_level||
                CASE WHEN l_parallel_level = 1 THEN ' (tabla con trigger UPDATE: corre en la sesion orquestadora)' ELSE '' END;

      l_job_class_exists := 0;
      BEGIN
        SELECT COUNT(*) INTO l_job_class_exists
          FROM dba_scheduler_job_classes
         WHERE job_class_name = 'JC_DATAMASKING';
      EXCEPTION
        WHEN OTHERS THEN
          l_job_class_exists := 0;
      END;

      -- Ejecutar tarea
      IF l_job_class_exists > 0 THEN
        DBMS_PARALLEL_EXECUTE.RUN_TASK(
          task_name      => l_task_name,
          sql_stmt       => l_sql_chunk,
          language_flag  => DBMS_SQL.NATIVE,
          parallel_level => l_parallel_level,
          job_class      => 'JC_DATAMASKING'
        );
      ELSE
        DBMS_PARALLEL_EXECUTE.RUN_TASK(
          task_name      => l_task_name,
          sql_stmt       => l_sql_chunk,
          language_flag  => DBMS_SQL.NATIVE,
          parallel_level => l_parallel_level
        );
      END IF;

      -- C-02: FALLO CERRADO. No dar por buena la columna hasta confirmar que TODOS
      -- los chunks terminaron OK. Un reintento acotado cubre errores transitorios.
      l_estado_tarea := DBMS_PARALLEL_EXECUTE.TASK_STATUS(l_task_name);
      IF l_estado_tarea <> DBMS_PARALLEL_EXECUTE.FINISHED THEN
        DBMS_PARALLEL_EXECUTE.RESUME_TASK(l_task_name);          -- reintenta chunks fallidos
        l_estado_tarea := DBMS_PARALLEL_EXECUTE.TASK_STATUS(l_task_name);
      END IF;

      SELECT COUNT(*),
             COUNT(CASE WHEN error_code = -6502 THEN 1 END),
             COUNT(CASE WHEN error_code = -1 THEN 1 END),
             COUNT(CASE WHEN error_code = -12899 THEN 1 END),
             MAX(TO_CHAR(error_code)||': '||SUBSTR(error_message,1,200))
        INTO l_chunks_error, l_chunks_error_6502, l_chunks_error_1, l_chunks_error_12899, l_detalle_error
        FROM user_parallel_execute_chunks
       WHERE task_name = l_task_name
         AND status    = 'PROCESSED_WITH_ERROR';

      -- FIX 2026-09-27 (auditoria , Nivel 1 #1 - "doble cifrado/doble
      -- enmascarado"): antes de este fix, si SOLO parte de los chunks fallaba,
      -- el codigo de abajo tiraba la tarea entera (DROP_TASK, se pierde el
      -- detalle de que rowid exactos fallaron) y el llamador (proc_dm_apl_col)
      -- reintentaba la MISMA columna con un UPDATE sobre TODA la tabla
      -- (WHERE columna IS NOT NULL) -- incluidas las filas de los chunks que
      -- YA habian terminado bien y cuyo commit ya establecio DBMS_PARALLEL_EXECUTE
      -- (cada chunk exitoso commitea de forma independiente al terminar). Ese
      -- reintento sobre toda la tabla lee el valor de columna ya enmascarado
      -- por FF1 en esas filas exitosas y lo vuelve a transformar (con la
      -- expresion original en un proc_dm_reanudar posterior, o con la expresion
      -- de fallback si -6502 mas abajo) -- perdiendo la reversibilidad del
      -- dominio FF1 sin dejar ningun rastro de que ocurrio.
      --
      -- Ahora, antes de rendirse, se reintenta UNA vez en serie, en la propia
      -- sesion orquestadora, acotado EXCLUSIVAMENTE al rowid de los chunks que
      -- fallaron (misma p_sql_base, sin tocar las filas de los chunks ya
      -- exitosos). Si los reintentos serie resuelven TODOS los chunks
      -- fallidos, la tarea se da por buena aqui mismo y ni siquiera se llega a
      -- lanzar una excepcion hacia el llamador. Si algun chunk sigue fallando,
      -- se seguye exactamente el mismo camino que antes (clasificacion por
      -- error_code original, ya capturado arriba, sin alterar).
      IF NVL(l_chunks_error,0) > 0 THEN
        l_retry_all_ok := TRUE;
        FOR rc IN (
          SELECT start_rowid, end_rowid
            FROM user_parallel_execute_chunks
           WHERE task_name = l_task_name
             AND status    = 'PROCESSED_WITH_ERROR'
        ) LOOP
          BEGIN
            EXECUTE IMMEDIATE p_sql_base||' AND ROWID BETWEEN :b1 AND :b2'
              USING rc.start_rowid, rc.end_rowid;
          EXCEPTION
            WHEN OTHERS THEN
              l_retry_all_ok := FALSE;
              EXIT;
          END;
        END LOOP;

        IF l_retry_all_ok THEN
          l_chunks_error := 0;
        END IF;
      END IF;

      IF l_estado_tarea <> DBMS_PARALLEL_EXECUTE.FINISHED OR NVL(l_chunks_error,0) > 0 THEN
        -- Se captura el diagnostico ANTES de limpiar la tarea, y se aborta la columna.
        DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => l_task_name);

        -- FIX 2026-09-18: distinguir ORA-06502 puro (buffer insuficiente en
        -- TODOS los chunks fallidos) de cualquier otro patron de fallo
        -- (deadlock GES, mezcla de errores, tarea que no llego a FINISHED,
        -- etc). proc_dm_apl_col ya tiene un fallback de 3 niveles para
        -- -6502, pero antes de este fix esa ruta era codigo muerto para
        -- tablas grandes (>100k filas): el error real quedaba absorbido por
        -- el framework paralelo y homogeneizado aqui a -20320 generico.
        -- -20320 se conserva para todo lo demas (deadlocks incluidos:
        -- fallo cerrado, sin reintento ciego ni perdida de severidad).
        IF l_estado_tarea = DBMS_PARALLEL_EXECUTE.FINISHED
           AND NVL(l_chunks_error,0) > 0
           AND l_chunks_error_6502 = l_chunks_error THEN
          RAISE_APPLICATION_ERROR(-20321,
            'ORA-06502 (buffer insuficiente) en TODOS los chunks paralelos de '||
            p_owner||'.'||p_tabla||'.'||p_columna||' (chunks_error='||l_chunks_error||
            '). Requiere fallback de longitud segura.');
        END IF;

        -- FIX 2026-09-27 (auditoria , Nivel 1 #2): mismo razonamiento que
        -- -20321 arriba, pero para ORA-00001 y ORA-12899. Antes de este fix, una
        -- tabla >100k filas (ruta DBMS_PARALLEL_EXECUTE) que fallaba por colision
        -- de unicidad (dominio no biyectivo, texto) o por longitud insuficiente
        -- perdia ese codigo especifico -- quedaba homogeneizado al -20320 generico
        -- de abajo, que el handler de proc_dm_apl_col NO reconoce (solo mira -1,
        -- -12899, -6502/-20321), asi que la columna terminaba en RAISE crudo en vez
        -- del auto-exclude gracioso que ya funciona en la ruta serie/directa para
        -- esos mismos dos errores. Se distingue igual: solo cuando TODOS los chunks
        -- fallidos comparten el mismo codigo puro (nunca ante mezcla de errores,
        -- que sigue cayendo en el -20320 fail-closed de abajo).
        IF l_estado_tarea = DBMS_PARALLEL_EXECUTE.FINISHED
           AND NVL(l_chunks_error,0) > 0
           AND l_chunks_error_1 = l_chunks_error THEN
          RAISE_APPLICATION_ERROR(-20322,
            'ORA-00001 (colision de unicidad) en TODOS los chunks paralelos de '||
            p_owner||'.'||p_tabla||'.'||p_columna||' (chunks_error='||l_chunks_error||
            '). Dominio no biyectivo, requiere auto-exclusion.');
        END IF;

        IF l_estado_tarea = DBMS_PARALLEL_EXECUTE.FINISHED
           AND NVL(l_chunks_error,0) > 0
           AND l_chunks_error_12899 = l_chunks_error THEN
          RAISE_APPLICATION_ERROR(-20323,
            'ORA-12899 (valor demasiado grande) en TODOS los chunks paralelos de '||
            p_owner||'.'||p_tabla||'.'||p_columna||' (chunks_error='||l_chunks_error||
            '). Requiere auto-exclusion.');
        END IF;

        RAISE_APPLICATION_ERROR(-20320,
          'Enmascarado paralelo incompleto en '||p_owner||'.'||p_tabla||'.'||p_columna||
          ' (estado_tarea='||l_estado_tarea||', chunks_error='||NVL(l_chunks_error,0)||
          CASE WHEN l_detalle_error IS NOT NULL THEN ', ej='||l_detalle_error ELSE '' END||')');
      END IF;

      -- Tarea validada: limpiar.
      DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => l_task_name);
      -- Nota: p_rows_out es aproximado (num_rows de dba_tables); el conteo exacto
      -- por chunk no lo expone DBMS_PARALLEL_EXECUTE. Lo relevante es que, si algun
      -- chunk fallo, arriba ya se abortó (no se reporta exito con datos incompletos).
      p_rows_out := l_row_count;
    ELSE
      -- Ejecución original directa
      g_ruta := CASE WHEN l_iot_type IS NOT NULL THEN 'UPDATE [tabla IOT: sin chunks]' ELSE 'UPDATE [max 100000 filas]' END||
                ' - filas_estimadas='||NVL(l_row_count,0);
      EXECUTE IMMEDIATE p_sql_base;
      p_rows_out := SQL%ROWCOUNT;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      -- Asegurar limpieza de la tarea si falla -- PERO solo si ESTA
      -- invocacion fue quien la creo (l_tarea_propia). FIX 2026-10-03 (8.1):
      -- antes de esta guarda, un fallo en CUALQUIER punto (incluido el
      -- ORA-20330 nuevo de mas arriba, que señala una tarea huerfana de OTRA
      -- invocacion anterior interrumpida) llegaba hasta aqui y este DROP_TASK
      -- la borraba igual como "limpieza" -- destruyendo exactamente la
      -- evidencia (chunks PROCESSED vs ASSIGNED vs UNASSIGNED) que el DBA
      -- necesita inspeccionar para decidir como reanudar sin doble
      -- enmascarado. Con la guarda, una tarea que esta invocacion NO creo
      -- nunca se toca aqui.
      IF l_tarea_propia THEN
        BEGIN
          DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => l_task_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
      END IF;
      -- 2026-10-09 (DESSIGAD, CEFCEN_OWN): ORA-01031 sin mas dato dejaba las 11 columnas
      -- fallidas sin decir QUE falta. Este procedimiento corre con derechos del DEFINIDOR
      -- (el dueño del motor): sus ROLES no cuentan, solo los privilegios concedidos
      -- directamente. Se dice cual es el objeto y que concesion falta.
      IF SQLCODE = -1031 THEN
        RAISE_APPLICATION_ERROR(-20350,
          'ORA-01031 al modificar '||p_owner||'.'||p_tabla||' (columna '||p_columna||'): el dueño del motor ('||
          SYS_CONTEXT('USERENV','CURRENT_USER')||') no tiene UPDATE sobre esa tabla. En PL/SQL de derechos del '||
          'definidor los roles (DBA incluido) no cuentan: necesita UPDATE ANY TABLE o UPDATE sobre la tabla '||
          'concedido DIRECTAMENTE a ese usuario. Compruebe con DBA_SYS_PRIVS / DBA_TAB_PRIVS (grantee = dueño del motor).');
      END IF;
      RAISE;
  END proc_dm_ejecuta_update_seguro;

  -- Wrapper de compatibilidad (2026-09-16): la implementacion real vive ahora
  -- en pkg_dm_trazabilidad, un paquete sin dependencias que tanto 04 como 05
  -- pueden llamar de forma ESTATICA (ver cabecera de 03b_dm_pkg_trazabilidad.sql
  -- para el porque). Se conserva esta firma publica identica para no romper
  -- a nadie que ya llame pkg_dm_enmascarar.proc_dm_trace directamente.
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_trace
  -- PROPOSITO    : Registra una linea de traza del flujo delegando en pkg_dm_trazabilidad (wrapper de
  --                compatibilidad con la firma historica).
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_fase, p_paso, p_detalle y opcional p_duracion_seg.
  -- LEE          : ninguno
  -- ESCRIBE      : TDM_MASK_TRACE (INSERT en transaccion autonoma, via
  --                pkg_dm_trazabilidad.proc_dm_trace)
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: practicamente todas las unidades del paquete. Sin llamadas externas vivas
  --                (03b y 04 solo lo mencionan en comentarios; llaman directo a pkg_dm_trazabilidad).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_trace(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_fase         IN VARCHAR2,
    p_paso         IN VARCHAR2,
    p_detalle      IN VARCHAR2,
    p_duracion_seg  IN NUMBER   DEFAULT NULL
  ) IS
  BEGIN
    pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id, p_ejecucion_id, p_fase, p_paso, p_detalle,
                                      p_duracion_seg);
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_upd_sol
  -- PROPOSITO    : Actualiza estado, fase, checkpoint y detalle de una solicitud de enmascarado, y
  --                opcionalmente la cierra con fecha_fin.
  -- ENTRADAS     : p_solicitud_id, p_estado, p_fase, p_checkpoint, p_detalle, p_cerrar (Y cierra).
  -- LEE          : ninguno
  -- ESCRIBE      : TDM_MASK_SOLICITUD (UPDATE + COMMIT)
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento, proc_dm_mask_cat, proc_dm_enmascara_tabla.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_upd_sol(
    p_solicitud_id IN NUMBER,
    p_estado       IN VARCHAR2,
    p_fase         IN VARCHAR2,
    p_checkpoint   IN VARCHAR2,
    p_detalle      IN VARCHAR2 DEFAULT NULL,
    p_cerrar       IN VARCHAR2 DEFAULT 'N'
  ) IS
  BEGIN
    UPDATE tdm_mask_solicitud
       SET estado          = SUBSTR(p_estado,1,30),
           fase_actual     = SUBSTR(p_fase,1,30),
           checkpoint_paso = SUBSTR(p_checkpoint,1,100),
           fecha_fin       = CASE WHEN UPPER(NVL(p_cerrar,'N'))='Y' THEN SYSTIMESTAMP ELSE fecha_fin END,
           -- FIX 2026-10-07: cada actualizacion de detalle pisaba el texto 'Reanudacion de
           -- ejecucion_id=N desde solicitud_id=M' con 'Aplicando enmascaramiento' y luego
           -- 'Proceso finalizado correctamente', y la marca se perdia. Ahora una solicitud
           -- con reintento_nro > 1 antepone siempre 'Reanudacion: <n> | ' (n = reintento_nro-1).
           detalle         = CASE WHEN p_detalle IS NOT NULL THEN
                                    SUBSTR(CASE WHEN NVL(reintento_nro,0) > 1
                                                THEN 'Reanudacion: '||TO_CHAR(reintento_nro-1)||' | ' END
                                           ||p_detalle,1,3900)
                                  ELSE detalle END
     WHERE solicitud_id = p_solicitud_id;
    COMMIT;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_upd_ejec
  -- PROPOSITO    : Actualiza fase, estado, progreso, contadores, ultimo objeto y latido de la fila de
  --                TDM_EJECUCION, sin permitir resucitar una ejecucion ya cerrada.
  -- ENTRADAS     : p_ejecucion_id y opcionales fase, estado, pct, tablas/columnas total y procesadas,
  --                objeto, paso y detalle (texto libre de la ejecucion; hoy lo usa la reanudacion).
  -- LEE          : ninguno
  -- ESCRIBE      : TDM_EJECUCION (UPDATE + COMMIT); TDM_MASK_TRACE (traza UPD_EJEC_BLOQUEADO /
  --                UPD_EJEC_FALLO via proc_dm_trace)
  -- ERRORES      : No levanta errores: cualquier fallo se traza (UPD_EJEC_FALLO) y se ignora.; Si la
  --                fila ya esta ABORTADA/CANCELADO/ERROR/FINALIZADO, un intento de volver a
  --                EJECUTANDO no tiene efecto y se traza UPD_EJEC_BLOQUEADO.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento, proc_dm_mask_cat, proc_dm_enmascara_tabla.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_upd_ejec(
    p_ejecucion_id IN NUMBER,
    p_fase         IN VARCHAR2 DEFAULT NULL,
    p_estado       IN VARCHAR2 DEFAULT NULL,
    p_pct          IN NUMBER   DEFAULT NULL,
    p_tab_tot      IN NUMBER   DEFAULT NULL,
    p_tab_proc     IN NUMBER   DEFAULT NULL,
    p_col_tot      IN NUMBER   DEFAULT NULL,
    p_col_proc     IN NUMBER   DEFAULT NULL,
    p_objeto       IN VARCHAR2 DEFAULT NULL,
    p_paso         IN VARCHAR2 DEFAULT NULL,
    p_detalle      IN VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    -- FIX 2026-10-04 (incidente real ejecucion_id=8, auditoria de fuerza
    -- bruta E-01/E-02): esta rutina es el "ping" de progreso que el loop de
    -- columnas llama tras CADA columna (ver proc_dm_mask_cat, rama con y sin
    -- TDM_COLUMNA_FINAL), siempre con p_estado='EJECUTANDO', sin saber si
    -- alguien mas (p.ej. dm_enmascara_cancel.sql, forzando ABORTADA) ya
    -- cerro la fila por fuera mientras la columna en curso (chunked via
    -- DBMS_PARALLEL_EXECUTE, no interrumpible a mitad) terminaba de
    -- procesarse. Sin la guarda del WHERE de abajo, el CASE de
    -- fecha_inicio/estado/fecha_fin "resucitaba" la fila: volvia a poner
    -- estado=EJECUTANDO, refrescaba fecha_inicio a SYSTIMESTAMP y vaciaba
    -- fecha_fin, pisando un ABORTADA/CANCELADO/ERROR/FINALIZADO ya cerrado
    -- por otra sesion -- exactamente lo que le paso a ejecucion_id=8: la
    -- cancelacion forzo ABORTADA a las 17:24:55 y este mismo ping, al
    -- terminar IBAN, la revivio a las 17:35:48 sin que nadie lo pidiera. La
    -- unica via legitima para ENTRAR a EJECUTANDO es el "reclamo de
    -- ejecucion" de proc_dm_enmascaramiento (UPDATE dedicado, mas arriba en
    -- este mismo paquete, con su propia guarda anti-doble-arranque) --
    -- proc_dm_upd_ejec nunca debe reclamar EJECUTANDO por su cuenta.
    UPDATE tdm_ejecucion
       SET fase_proceso   = NVL(p_fase, fase_proceso),
           estado         = NVL(p_estado, estado),
           ora_usuario  = USER,
           fecha_inicio   = CASE
                              WHEN UPPER(NVL(p_estado, estado)) = 'EJECUTANDO'
                                   AND (UPPER(NVL(estado,'?')) <> 'EJECUTANDO' OR fecha_inicio IS NULL)
                                THEN SYSTIMESTAMP
                              ELSE fecha_inicio
                            END,
           fecha_fin      = CASE
                              WHEN UPPER(NVL(p_estado, estado)) IN ('FINALIZADO','ERROR','CANCELADO')
                                THEN SYSTIMESTAMP
                              WHEN UPPER(NVL(p_estado, estado)) = 'EJECUTANDO'
                                THEN NULL
                              ELSE fecha_fin
                            END,
           progreso_pct   = NVL(p_pct, progreso_pct),
           tablas_total   = NVL(p_tab_tot, tablas_total),
           tablas_proc    = NVL(p_tab_proc, tablas_proc),
           columnas_total = NVL(p_col_tot, columnas_total),
           columnas_proc  = NVL(p_col_proc, columnas_proc),
           ultimo_objeto  = NVL(p_objeto, ultimo_objeto),
           ultimo_paso    = NVL(p_paso, ultimo_paso),
           detalle        = NVL(SUBSTR(p_detalle,1,4000), detalle),
           heartbeat_ts   = SYSTIMESTAMP
     WHERE ejecucion_id = p_ejecucion_id
       AND NOT (
             UPPER(NVL(p_estado, estado)) = 'EJECUTANDO'
             AND UPPER(NVL(estado,'?')) IN ('ABORTADA','CANCELADO','ERROR','FINALIZADO')
           );

    IF SQL%ROWCOUNT = 0 THEN
      -- No es un error: o bien ejecucion_id no existe, o bien la guarda de
      -- arriba bloqueo a proposito un intento de resucitar EJECUTANDO sobre
      -- una fila que alguien mas ya habia cerrado. Se traza para que quede
      -- visible en tdm_mask_trace (sin solicitud_id propio, igual que el
      -- manejador de abajo), nunca para abortar el llamador.
      proc_dm_trace(NULL, p_ejecucion_id, 'CONTROL', 'UPD_EJEC_BLOQUEADO',
        'Ping de progreso ('||NVL(p_paso,'?')||'/'||NVL(p_objeto,'?')||') sin efecto para ejecucion_id='||
        p_ejecucion_id||': la fila no existe o ya estaba cerrada (no EJECUTANDO) cuando se intento '||
        'reclamar EJECUTANDO. No se resucita.');
    END IF;

    COMMIT;
  EXCEPTION
    -- No aborta (esta rutina la llaman tambien los propios manejadores de
    -- error, para no encadenar fallos), pero antes de este cambio el fallo
    -- desaparecia sin dejar rastro y el estado mostrado al operador podia
    -- quedar desactualizado sin ninguna pista. Ahora al menos queda trazado.
    WHEN OTHERS THEN
      proc_dm_trace(NULL, p_ejecucion_id, 'CONTROL', 'UPD_EJEC_FALLO', func_dm_safe_err(SQLERRM));
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_close_sol_open
  -- PROPOSITO    : Cierra como ERROR las solicitudes de la ejecucion que quedaron abiertas por un
  --                intento anterior, antes de abrir una nueva.
  -- ENTRADAS     : p_ejecucion_id.
  -- LEE          : ninguno
  -- ESCRIBE      : TDM_MASK_SOLICITUD (UPDATE a ERROR/FIN/AUTO_CLOSE_REANUDAR + COMMIT)
  -- ERRORES      : No levanta errores: los fallos se trazan como CLOSE_SOL_OPEN_FALLO.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento (al arrancar).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_close_sol_open(p_ejecucion_id IN NUMBER) IS
  BEGIN
    UPDATE tdm_mask_solicitud
       SET estado          = 'ERROR',
           fase_actual     = 'FIN',
           checkpoint_paso = 'AUTO_CLOSE_REANUDAR',
           fecha_fin       = SYSTIMESTAMP,
           detalle         = SUBSTR(NVL(detalle,'')||' | Cerrada automáticamente por nueva ejecución/reanudación',1,3900)
     WHERE ejecucion_id = p_ejecucion_id
       AND estado IN ('EN_PROCESO','PENDIENTE','REANUDANDO')
       AND fecha_fin IS NULL;
    COMMIT;
  EXCEPTION
    -- Igual que en proc_dm_upd_ejec: housekeeping de solicitudes huerfanas,
    -- ahora con traza en vez de silencio total.
    WHEN OTHERS THEN
      proc_dm_trace(NULL, p_ejecucion_id, 'CONTROL', 'CLOSE_SOL_OPEN_FALLO', func_dm_safe_err(SQLERRM));
  END;

  -- LIMPIEZA 2026-09-18: se elimina proc_dm_longops (junto con los globales
  -- g_rindex/g_slno, tambien retirados). Era telemetria para
  -- V$SESSION_LONGOPS que nunca llego a conectarse a ninguna llamada real
  -- (g_rindex/g_slno jamas se inicializaban con
  -- DBMS_APPLICATION_INFO.SET_SESSION_LONGOPS_NOHINT, y ningun punto del
  -- paquete invocaba proc_dm_longops) - codigo muerto sin efecto en el
  -- enmascarado, confirmado por grep antes de retirarlo.

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_chk_cancel
  -- PROPOSITO    : Comprueba si se ha pedido cancelar la ejecucion y, en ese caso, aborta el flujo
  --                con un error de cancelacion cooperativa.
  -- ENTRADAS     : p_solicitud_id.
  -- LEE          : TDM_MASK_SOLICITUD; TDM_EJECUCION (cancel_requested)
  -- ESCRIBE      : ninguno
  -- ERRORES      : ORA-20081 si cancel_requested = Y.; NO_DATA_FOUND (ORA-01403) si la solicitud no
  --                existe.
  -- LLAMADO DESDE: Interno: proc_dm_mask_cat (una vez por columna, antes de procesarla).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_chk_cancel(p_solicitud_id IN NUMBER) IS
    l_cancel CHAR(1);
  BEGIN
    -- La solicitud de cancelacion vive solo en TDM_EJECUCION (una corrida = una sesion).
    SELECT e.cancel_requested
      INTO l_cancel
      FROM tdm_mask_solicitud s
      JOIN tdm_ejecucion e ON e.ejecucion_id = s.ejecucion_id
     WHERE s.solicitud_id = p_solicitud_id;

    IF NVL(l_cancel,'N') = 'Y' THEN
      RAISE_APPLICATION_ERROR(-20081, 'Cancelación solicitada para solicitud_id='||p_solicitud_id);
    END IF;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_esquema
  -- PROPOSITO    : Obtiene el esquema objetivo de una ejecucion, normalizado.
  -- ENTRADAS     : p_ejecucion_id; retorna esquema en mayusculas.
  -- LEE          : TDM_EJECUCION
  -- ESCRIBE      : ninguno
  -- ERRORES      : ORA-20056 si no existe la ejecucion.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_esquema(p_ejecucion_id IN NUMBER) RETURN VARCHAR2 IS
    l_esquema VARCHAR2(128);
  BEGIN
    SELECT UPPER(TRIM(ora_esquema))
      INTO l_esquema
      FROM tdm_ejecucion
     WHERE ejecucion_id = p_ejecucion_id;
    RETURN l_esquema;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20056,'No existe tdm_ejecucion para ejecucion_id='||p_ejecucion_id);
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_crea_sol
  -- PROPOSITO    : Crea una solicitud de enmascarado en estado EN_PROCESO con el numero de reintento
  --                siguiente para la ejecucion.
  -- ENTRADAS     : p_ejecucion_id, p_esquema, p_detalle, p_forzar_reproceso; retorna solicitud_id.
  -- LEE          : TDM_MASK_SOLICITUD; SEQ_DM_MASK_SOLICITUD
  -- ESCRIBE      : TDM_MASK_SOLICITUD (INSERT + COMMIT)
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento y proc_dm_enmascara_tabla.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_crea_sol(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_detalle      IN VARCHAR2,
    p_forzar_reproceso IN VARCHAR2 DEFAULT 'N'
  ) RETURN NUMBER IS
    l_solicitud_id NUMBER;
    l_reintento    NUMBER;
    l_esquema      VARCHAR2(128) := UPPER(TRIM(p_esquema));
  BEGIN
    SELECT NVL(MAX(reintento_nro),0)+1
      INTO l_reintento
      FROM tdm_mask_solicitud
     WHERE ejecucion_id = p_ejecucion_id;

    l_solicitud_id := seq_dm_mask_solicitud.NEXTVAL;

    INSERT INTO tdm_mask_solicitud(
      solicitud_id, ejecucion_id, ora_esquema, estado, fase_actual,
      checkpoint_paso, reintento_nro, fecha_inicio,
      detalle, forzar_reproceso, filas_procesadas, filas_error,
      tablas_procesadas, columnas_procesadas, ultima_tabla, ultima_columna
    ) VALUES (
      l_solicitud_id, p_ejecucion_id, l_esquema, 'EN_PROCESO', 'INI',
      'INI', l_reintento, SYSTIMESTAMP, SUBSTR(p_detalle,1,3900),
      UPPER(TRIM(NVL(p_forzar_reproceso,'N'))), 0, 0, 0, 0, NULL, NULL
    );
    -- Limpieza (2026-09-16): aqui habia un EXECUTE IMMEDIATE que actualizaba
    -- TDM_MASK_SOLICITUD.FORZAR_FULL, columna que NO existe en esa tabla (la
    -- columna real es FORZAR_REPROCESO, ya fijada arriba en el INSERT). El
    -- UPDATE fallaba con ORA-00904 en cada llamada y el WHEN OTHERS lo
    -- silenciaba - codigo muerto que nunca hizo nada. Eliminado.

    COMMIT;
    RETURN l_solicitud_id;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_validar_base
  -- PROPOSITO    : Verifica que existen las tablas base del motor antes de empezar a enmascarar.
  -- ENTRADAS     : Sin parametros.
  -- LEE          : USER_TABLES
  -- ESCRIBE      : ninguno
  -- ERRORES      : ORA-20050 falta TDM_MASK_SOLICITUD.; ORA-20051 falta TDM_MASK_TRACE.; ORA-20052
  --                falta TDM_MASK_DEP_ESTADO.; ORA-20053 falta TDM_COLUMNA_FINAL.; ORA-20054 falta
  --                TDM_DEPENDENCIA_FINAL.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento y proc_dm_enmascara_tabla.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_validar_base IS
    l_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = 'TDM_MASK_SOLICITUD';
    IF l_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20050,'No existe TDM_MASK_SOLICITUD'); END IF;
    SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = 'TDM_MASK_TRACE';
    IF l_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20051,'No existe TDM_MASK_TRACE'); END IF;
    SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = 'TDM_MASK_DEP_ESTADO';
    IF l_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20052,'No existe TDM_MASK_DEP_ESTADO'); END IF;
    SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = 'TDM_COLUMNA_FINAL';
    IF l_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20053,'No existe TDM_COLUMNA_FINAL'); END IF;
    SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = 'TDM_DEPENDENCIA_FINAL';
    IF l_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20054,'No existe TDM_DEPENDENCIA_FINAL'); END IF;
    /*SELECT COUNT(*) INTO l_cnt FROM user_tables WHERE table_name = 'TDM_MASK_CACHE';
    IF l_cnt = 0 THEN RAISE_APPLICATION_ERROR(-20057,'No existe TDM_MASK_CACHE'); END IF;*/
  END;

  -- 2026-09-27: wrapper de compatibilidad, mismo patron que proc_dm_trace /
  -- proc_dm_log_ejec_error (ver nota del 09/16 mas abajo). La implementacion
  -- real vive ahora en pkg_dm_trazabilidad (compartida con pkg_dm_descubrimiento,
  -- 04), que ya no la tenia duplicada palabra por palabra en los dos paquetes.
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_refresca_sesion
  -- PROPOSITO    : Registra en TDM_EJECUCION la sesion Oracle actual (sid, serial, instancia, audsid)
  --                y el latido, delegando en pkg_dm_trazabilidad.
  -- ENTRADAS     : p_ejecucion_id.
  -- LEE          : V$SESSION (via pkg_dm_trazabilidad)
  -- ESCRIBE      : TDM_EJECUCION (UPDATE sesion_* y heartbeat_ts, transaccion autonoma, via
  --                pkg_dm_trazabilidad.proc_dm_refresca_sesion)
  -- ERRORES      : Sin errores visibles: el delegado ignora cualquier fallo.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento (al arrancar).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_refresca_sesion(
    p_ejecucion_id IN NUMBER
  ) IS
  BEGIN
    pkg_dm_trazabilidad.proc_dm_refresca_sesion(p_ejecucion_id);
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_validar_concurrencia
  -- PROPOSITO    : Impide arrancar un enmascarado si ya hay otra ejecucion ENMASCARAMIENTO en curso
  --                para la misma ejecucion_id o para el mismo esquema.
  -- ENTRADAS     : p_ejecucion_id, p_esquema.
  -- LEE          : TDM_EJECUCION
  -- ESCRIBE      : TDM_EJECUCION (indirecto: pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas pasa a
  --                ABORTADA las EJECUTANDO huerfanas)
  -- ERRORES      : ORA-20097 ya hay una ejecucion ENMASCARAMIENTO EJECUTANDO con ese ejecucion_id.;
  --                ORA-20098 ya hay otra EJECUTANDO sobre el mismo esquema.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento y proc_dm_enmascara_tabla.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_validar_concurrencia(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  ) IS
    l_cnt NUMBER;
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
  BEGIN
    -- 2026-09-27: barrido global de huerfanas ANTES de bloquear. Si la fila
    -- EJECUTANDO que estorba viene de una sesion muerta (caida, kill) o de un
    -- heartbeat parado hace mas de 15 min, se autocorrige aqui a ABORTADA y
    -- las dos comprobaciones de abajo dejan de encontrarla -- proc_dm_enmascaramiento
    -- puede entonces reclamar la fila con su propio UPDATE de abajo, sin
    -- exigir una intervencion manual previa. Mismo mecanismo que ya usa
    -- pkg_dm_descubrimiento para DESCUBRIMIENTO (ver 03b_dm_pkg_trazabilidad.sql).
    pkg_dm_trazabilidad.proc_dm_autocancel_huerfanas(15, 'Y');

    SELECT COUNT(*)
      INTO l_cnt
      FROM tdm_ejecucion e
     WHERE e.ejecucion_id = p_ejecucion_id
       AND UPPER(TRIM(NVL(e.fase_proceso,'?'))) = 'ENMASCARAMIENTO'
       AND UPPER(TRIM(NVL(e.estado,'?'))) = 'EJECUTANDO';

    IF l_cnt > 0 THEN
      RAISE_APPLICATION_ERROR(
        -20097,
        'Ya existe una ejecución ENMASCARAMIENTO en estado EJECUTANDO para ejecucion_id='||p_ejecucion_id||
        '. Reintente cuando finalice o cancele la sesión activa.'
      );
    END IF;

    SELECT COUNT(*)
      INTO l_cnt
      FROM tdm_ejecucion e
     WHERE UPPER(TRIM(e.ora_esquema)) = l_esquema
       AND e.ejecucion_id <> p_ejecucion_id
       AND UPPER(TRIM(NVL(e.fase_proceso,'?'))) = 'ENMASCARAMIENTO'
       AND UPPER(TRIM(NVL(e.estado,'?'))) = 'EJECUTANDO';

    IF l_cnt > 0 THEN
      RAISE_APPLICATION_ERROR(
        -20098,
        'Ya existe una ejecución ENMASCARAMIENTO en estado EJECUTANDO para el esquema '||l_esquema||
        '. Evite ejecutar dos sesiones en paralelo sobre el mismo esquema.'
      );
    END IF;
  END;

  -- Wrapper de compatibilidad (2026-09-16): ver nota de proc_dm_trace, misma
  -- razon. Implementacion real en pkg_dm_trazabilidad.
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_log_ejec_error
  -- PROPOSITO    : Registra un error de ejecucion en TDM_EJECUCION_ERROR delegando en
  --                pkg_dm_trazabilidad (wrapper de compatibilidad con la firma historica).
  -- ENTRADAS     : p_ejecucion_id, p_owner_name, p_table_name, p_column_name, p_etapa,
  --                p_codigo_error, p_mensaje, p_backtrace, p_solicitud_id.
  -- LEE          : USER_TABLES; TDM_EJECUCION_ERROR (via pkg_dm_trazabilidad)
  -- ESCRIBE      : TDM_EJECUCION_ERROR (INSERT, transaccion autonoma); TDM_MASK_TRACE
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento, proc_dm_enmascara_tabla, proc_dm_mask_cat,
  --                proc_dm_pre_dep, proc_dm_post_dep. Sin llamadas externas vivas.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_log_ejec_error(
    p_ejecucion_id IN NUMBER,
    p_owner_name   IN VARCHAR2,
    p_table_name   IN VARCHAR2,
    p_column_name  IN VARCHAR2,
    p_etapa        IN VARCHAR2,
    p_codigo_error IN NUMBER,
    p_mensaje      IN VARCHAR2,
    p_backtrace    IN VARCHAR2,
    p_solicitud_id IN NUMBER DEFAULT NULL
  ) IS
  BEGIN
    pkg_dm_trazabilidad.proc_dm_log_ejec_error(
      p_ejecucion_id, p_owner_name, p_table_name, p_column_name, p_etapa,
      p_codigo_error, p_mensaje, p_backtrace, p_solicitud_id
    );
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_validar_reingreso_mask
  -- PROPOSITO    : Impide re-ejecutar un enmascarado sobre una ejecucion ya FINALIZADA salvo que se
  --                pida reproceso explicito.
  -- ENTRADAS     : p_ejecucion_id, p_esquema, p_reproceso (Y omite la validacion).
  -- LEE          : TDM_MASK_SOLICITUD
  -- ESCRIBE      : ninguno
  -- ERRORES      : ORA-20014 si existe una solicitud FINALIZADO para la ejecucion y p_reproceso no es
  --                Y.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_validar_reingreso_mask(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_reproceso    IN VARCHAR2
  ) IS
    l_cnt NUMBER := 0;
    l_repro VARCHAR2(1) := UPPER(TRIM(NVL(p_reproceso,'N')));
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
  BEGIN
    IF l_repro = 'Y' THEN
      RETURN;
    END IF;

    SELECT COUNT(*)
      INTO l_cnt
      FROM tdm_mask_solicitud s
     WHERE s.ejecucion_id = p_ejecucion_id
       AND s.estado = 'FINALIZADO';

    IF l_cnt > 0 THEN
      RAISE_APPLICATION_ERROR(
        -20014,
        'La ejecución_id='||p_ejecucion_id||' del esquema '||l_esquema||
        ' ya fue ejecutada en enmascaramiento. Para re-ejecutar debe usar proc_dm_enmascaramiento('||
        TO_CHAR(p_ejecucion_id)||',''Y'').'
      );
    END IF;
  END;

  ------------------------------------------------------------------------------
  -- Catálogo y reglas
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_tiene_regla
  -- PROPOSITO    : Cuenta las reglas especiales activas de un tipo dado para una columna.
  -- ENTRADAS     : p_esquema, p_owner, p_tabla, p_columna, p_tipo; retorna numero de reglas activas.
  -- LEE          : TDM_MASK_REGLA_ESP
  -- ESCRIBE      : ninguno
  -- ERRORES      : Fallo cerrado: cualquier error se propaga (no se interpreta como no hay regla).
  -- LLAMADO DESDE: Interno: proc_dm_apl_col (DOC_SEGUN_TIPO, DOC_UNIFICADO_MANTENER_1_Y_ULTIMO,
  --                IBAN_ES_CONTINUO).
  ------------------------------------------------------------------------------
  FUNCTION func_dm_tiene_regla(
    p_esquema IN VARCHAR2,
    p_owner   IN VARCHAR2,
    p_tabla   IN VARCHAR2,
    p_columna IN VARCHAR2,
    p_tipo    IN VARCHAR2
  ) RETURN NUMBER IS
    l_cnt NUMBER;
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_owner   VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla   VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna VARCHAR2(128) := UPPER(TRIM(p_columna));
    l_tipo    VARCHAR2(128) := UPPER(TRIM(p_tipo));
  BEGIN
    SELECT COUNT(*) INTO l_cnt
      FROM tdm_mask_regla_esp
     WHERE ora_esquema = l_esquema
       AND ora_owner       = l_owner
       AND table_name       = l_tabla
       AND column_name      = l_columna
       AND tipo_regla       = l_tipo
       AND activa           = 'Y';
    RETURN l_cnt;
  EXCEPTION
    -- Fail-closed (2026-09-16): un COUNT(*) sobre una tabla propia solo puede
    -- fallar por un problema real (tabla inaccesible, privilegio revocado,
    -- deadlock). Devolver 0 en ese caso hacia parecer "no hay regla especial"
    -- y el motor caia al tratamiento generico sin avisar - exactamente el
    -- tipo de fallback silencioso que el resto del motor evita. Se propaga.
    WHEN OTHERS THEN RAISE;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_val_regla
  -- PROPOSITO    : Devuelve el valor parametrico (valor_regla) de la regla especial activa de un tipo
  --                para una columna.
  -- ENTRADAS     : p_esquema, p_owner, p_tabla, p_columna, p_tipo; retorna valor_regla o NULL.
  -- LEE          : TDM_MASK_REGLA_ESP
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_apl_col (regla DOC_SEGUN_TIPO: nombre de la columna que indica el
  --                tipo de documento).
  ------------------------------------------------------------------------------
  FUNCTION func_dm_val_regla(
    p_esquema IN VARCHAR2,
    p_owner   IN VARCHAR2,
    p_tabla   IN VARCHAR2,
    p_columna IN VARCHAR2,
    p_tipo    IN VARCHAR2
  ) RETURN VARCHAR2 IS
    l_valor VARCHAR2(4000);
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_owner   VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla   VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna VARCHAR2(128) := UPPER(TRIM(p_columna));
    l_tipo    VARCHAR2(128) := UPPER(TRIM(p_tipo));
  BEGIN
    SELECT valor_regla INTO l_valor
      FROM tdm_mask_regla_esp
     WHERE ora_esquema = l_esquema
       AND ora_owner       = l_owner
       AND table_name       = l_tabla
       AND column_name      = l_columna
       AND tipo_regla       = l_tipo
       AND activa           = 'Y'
       AND ROWNUM = 1;
    RETURN l_valor;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_expr_gen_sql
  -- PROPOSITO    : Traduce un identificador de dato sensible a la expresion SQL de la funcion de
  --                enmascarado de pkg_dm_func_mask que le corresponde.
  -- ENTRADAS     : p_identificador, p_col_expr (columna ya entrecomillada); retorna fragmento SQL.
  -- LEE          : ninguno
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: func_dm_expr_compatible.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_expr_gen_sql(
    p_identificador IN VARCHAR2,
    p_col_expr      IN VARCHAR2
  ) RETURN VARCHAR2 IS
    l_id VARCHAR2(100) := func_dm_norm(p_identificador);
  BEGIN
    CASE l_id
      WHEN 'IDENTIFICADOR_PERSONAL'    THEN RETURN 'pkg_dm_func_mask.func_dm_nombre('||p_col_expr||')';
      WHEN 'IDENTIFICADOR_NOMBRE'      THEN RETURN 'pkg_dm_func_mask.func_dm_nombre('||p_col_expr||')';
      WHEN 'IDENTIFICADOR_DIRECCION'   THEN RETURN 'pkg_dm_func_mask.func_dm_direccion('||p_col_expr||')';
      WHEN 'IDENTIFICADOR_TELEFONO'    THEN RETURN 'pkg_dm_func_mask.func_dm_telefono('||p_col_expr||')';
      WHEN 'IDENTIFICADOR_EMAIL'       THEN RETURN 'pkg_dm_func_mask.func_dm_email('||p_col_expr||')';
      WHEN 'IDENTIFICADOR_IDENTIDAD'   THEN RETURN 'pkg_dm_func_mask.func_dm_nif('||p_col_expr||')';
      WHEN 'IDENTIFICADOR_BANCARIO'    THEN
        RETURN 'CASE WHEN REGEXP_LIKE(UPPER(TRIM('||p_col_expr||')), ''^ES[0-9]{22}$'') '||
               'THEN pkg_dm_func_mask.func_dm_iban('||p_col_expr||') '||
               'ELSE pkg_dm_func_mask.func_dm_cuenta('||p_col_expr||') END';
      ELSE
        RETURN 'pkg_dm_func_mask.func_dm_obs('||p_col_expr||')';
    END CASE;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_expr_compatible
  -- PROPOSITO    : Construye la expresion de SET del UPDATE segun el tipo real de la columna, acotada
  --                a su longitud para evitar ORA-12899.
  -- ENTRADAS     : p_owner, p_tabla, p_columna, p_identificador; retorna expresion SQL.
  -- LEE          : DBA_TAB_COLUMNS
  -- ESCRIBE      : ninguno
  -- ERRORES      : Si falla la lectura de metadatos devuelve la expresion con SUBSTR de 4000
  --                caracteres.
  -- LLAMADO DESDE: Interno: proc_dm_apl_col (rama sin regla especial).
  ------------------------------------------------------------------------------
  FUNCTION func_dm_expr_compatible(
    p_owner         IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_columna       IN VARCHAR2,
    p_identificador IN VARCHAR2
  ) RETURN VARCHAR2 IS
    l_data_type dba_tab_columns.data_type%TYPE;
    l_len       dba_tab_columns.data_length%TYPE;
    l_char_len  NUMBER;
    l_expr      VARCHAR2(4000);
    l_col       VARCHAR2(4000) := func_dm_qname(p_columna);
    l_owner     VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla     VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna   VARCHAR2(128) := UPPER(TRIM(p_columna));
  BEGIN
    BEGIN
      SELECT data_type, data_length, NVL(char_col_decl_length, data_length)
        INTO l_data_type, l_len, l_char_len
        FROM dba_tab_columns
       WHERE owner = l_owner
         AND table_name = l_tabla
         AND column_name = l_columna;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_data_type := NULL;
        l_len       := NULL;
        l_char_len  := NULL;
    END;

    IF l_data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2') THEN
      l_expr := func_dm_expr_gen_sql(p_identificador, l_col);
      RETURN 'SUBSTR('||l_expr||',1,'||TO_CHAR(NVL(l_char_len,l_len))||')';
    ELSE
      RETURN l_col;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      -- M-7: Envolver en SUBSTR con longitud de fallback prudente ante fallo de consulta de metadatos
      RETURN 'SUBSTR('||func_dm_expr_gen_sql(p_identificador, l_col)||',1,4000)';
  END;

  ------------------------------------------------------------------------------
  -- Dependencias PRE/POST robustas (fix ORA-02431/02430 + ORA-06502)
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_dep_col_exists
  -- PROPOSITO    : Comprueba (con cache en variables de paquete) si TDM_DEPENDENCIA_FINAL tiene las
  --                columnas opcionales de politica CATEGORIA_USO, ACCION_PRE_MASK y ACCION_POST_MASK.
  -- ENTRADAS     : p_col; retorna 1 si existe, 0 si no.
  -- LEE          : DBA_TAB_COLUMNS
  -- ESCRIBE      : variables de paquete g_dep_has_* (cache)
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_dep_policy y func_dm_dep_post_action.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_dep_col_exists(
    p_col IN VARCHAR2
  ) RETURN NUMBER IS
    l_cnt NUMBER := 0;
    l_col VARCHAR2(128) := UPPER(TRIM(p_col));
  BEGIN
    IF l_col = 'CATEGORIA_USO' AND g_dep_has_categoria_uso IS NOT NULL THEN
      RETURN g_dep_has_categoria_uso;
    ELSIF l_col = 'ACCION_PRE_MASK' AND g_dep_has_accion_pre_mask IS NOT NULL THEN
      RETURN g_dep_has_accion_pre_mask;
    ELSIF l_col = 'ACCION_POST_MASK' AND g_dep_has_accion_post_mask IS NOT NULL THEN
      RETURN g_dep_has_accion_post_mask;
    END IF;

    BEGIN
      SELECT COUNT(*)
        INTO l_cnt
        FROM dba_tab_columns
       WHERE owner = SYS_CONTEXT('USERENV','CURRENT_USER')
         AND table_name = 'TDM_DEPENDENCIA_FINAL'
         AND column_name = l_col;
    EXCEPTION
      WHEN OTHERS THEN
        l_cnt := 0;
    END;

    IF l_col = 'CATEGORIA_USO' THEN
      g_dep_has_categoria_uso := CASE WHEN l_cnt > 0 THEN 1 ELSE 0 END;
      RETURN g_dep_has_categoria_uso;
    ELSIF l_col = 'ACCION_PRE_MASK' THEN
      g_dep_has_accion_pre_mask := CASE WHEN l_cnt > 0 THEN 1 ELSE 0 END;
      RETURN g_dep_has_accion_pre_mask;
    ELSIF l_col = 'ACCION_POST_MASK' THEN
      g_dep_has_accion_post_mask := CASE WHEN l_cnt > 0 THEN 1 ELSE 0 END;
      RETURN g_dep_has_accion_post_mask;
    END IF;

    RETURN 0;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_dep_policy
  -- PROPOSITO    : Determina la categoria de uso y las acciones pre y post enmascarado de una
  --                dependencia (FK, PK/UK, trigger u otra), con defaults por tipo y sobreescritura
  --                desde TDM_DEPENDENCIA_FINAL.
  -- ENTRADAS     : p_owner_name, p_table_name, p_dep_owner, p_dep_objeto, p_tipo_dependencia; OUT
  --                p_categoria_uso, p_accion_pre, p_accion_post.
  -- LEE          : TDM_DEPENDENCIA_FINAL (SQL dinamico)
  -- ESCRIBE      : ninguno
  -- ERRORES      : Sin errores: los fallos de lectura se ignoran y se mantienen los defaults.
  -- LLAMADO DESDE: Interno: proc_dm_pre_dep.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_dep_policy(
    p_owner_name      IN VARCHAR2,
    p_table_name      IN VARCHAR2,
    p_dep_owner       IN VARCHAR2,
    p_dep_objeto      IN VARCHAR2,
    p_tipo_dependencia IN VARCHAR2,
    p_categoria_uso   OUT VARCHAR2,
    p_accion_pre      OUT VARCHAR2,
    p_accion_post     OUT VARCHAR2
  ) IS
    l_tipo VARCHAR2(100) := UPPER(TRIM(NVL(p_tipo_dependencia,'')));
    l_val  VARCHAR2(100);
  BEGIN
    -- Defaults seguros (compatibles con comportamiento existente).
    IF l_tipo IN ('FK','R','FOREIGN KEY','CONSTRAINT') THEN
      p_categoria_uso := 'INTEGRIDAD';
      p_accion_pre    := 'DISABLE';
      p_accion_post   := 'ENABLE_VALIDATE';
    ELSIF l_tipo IN ('PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE') THEN
      p_categoria_uso := 'INTEGRIDAD';
      p_accion_pre    := 'SOLO_INFORMATIVO';
      p_accion_post   := 'REVISAR';
    ELSIF l_tipo = 'TRIGGER' THEN
      p_categoria_uso := 'OPERATIVA';
      p_accion_pre    := 'DISABLE';
      p_accion_post   := 'ENABLE';
    ELSE
      p_categoria_uso := 'OPERATIVA';
      p_accion_pre    := 'SOLO_INFORMATIVO';
      p_accion_post   := 'SIN_ACCION';
    END IF;

    IF func_dm_dep_col_exists('CATEGORIA_USO') = 1 THEN
      BEGIN
        EXECUTE IMMEDIATE
          'SELECT MAX(UPPER(TRIM(categoria_uso))) '||
          'FROM tdm_dependencia_final '||
          'WHERE ora_owner = :1 '||
          '  AND table_name = :2 '||
          '  AND UPPER(TRIM(dependencia_owner)) = :3 '||
          '  AND UPPER(TRIM(dependencia_objeto)) = :4 '||
          '  AND UPPER(TRIM(tipo_dependencia)) = :5'
          INTO l_val
          USING UPPER(TRIM(p_owner_name)),
                UPPER(TRIM(p_table_name)),
                UPPER(TRIM(p_dep_owner)),
                UPPER(TRIM(p_dep_objeto)),
                UPPER(TRIM(p_tipo_dependencia));
        IF l_val IS NOT NULL THEN
          p_categoria_uso := l_val;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
    END IF;

    IF func_dm_dep_col_exists('ACCION_PRE_MASK') = 1 THEN
      BEGIN
        EXECUTE IMMEDIATE
          'SELECT MAX(UPPER(TRIM(accion_pre_mask))) '||
          'FROM tdm_dependencia_final '||
          'WHERE ora_owner = :1 '||
          '  AND table_name = :2 '||
          '  AND UPPER(TRIM(dependencia_owner)) = :3 '||
          '  AND UPPER(TRIM(dependencia_objeto)) = :4 '||
          '  AND UPPER(TRIM(tipo_dependencia)) = :5'
          INTO l_val
          USING UPPER(TRIM(p_owner_name)),
                UPPER(TRIM(p_table_name)),
                UPPER(TRIM(p_dep_owner)),
                UPPER(TRIM(p_dep_objeto)),
                UPPER(TRIM(p_tipo_dependencia));
        IF l_val IS NOT NULL THEN
          p_accion_pre := l_val;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
    END IF;

    IF func_dm_dep_col_exists('ACCION_POST_MASK') = 1 THEN
      BEGIN
        EXECUTE IMMEDIATE
          'SELECT MAX(UPPER(TRIM(accion_post_mask))) '||
          'FROM tdm_dependencia_final '||
          'WHERE ora_owner = :1 '||
          '  AND table_name = :2 '||
          '  AND UPPER(TRIM(dependencia_owner)) = :3 '||
          '  AND UPPER(TRIM(dependencia_objeto)) = :4 '||
          '  AND UPPER(TRIM(tipo_dependencia)) = :5'
          INTO l_val
          USING UPPER(TRIM(p_owner_name)),
                UPPER(TRIM(p_table_name)),
                UPPER(TRIM(p_dep_owner)),
                UPPER(TRIM(p_dep_objeto)),
                UPPER(TRIM(p_tipo_dependencia));
        IF l_val IS NOT NULL THEN
          p_accion_post := l_val;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
    END IF;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_dep_post_action
  -- PROPOSITO    : Devuelve la accion de rehabilitacion post enmascarado de una dependencia (por
  --                defecto ENABLE para trigger, ENABLE_VALIDATE para el resto).
  -- ENTRADAS     : p_owner_name, p_table_name, p_dep_owner, p_dep_objeto, p_tipo_obj; retorna accion.
  -- LEE          : TDM_DEPENDENCIA_FINAL (SQL dinamico)
  -- ESCRIBE      : ninguno
  -- ERRORES      : Sin errores: ante fallo devuelve el default.
  -- LLAMADO DESDE: Interno: proc_dm_post_dep.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_dep_post_action(
    p_owner_name IN VARCHAR2,
    p_table_name IN VARCHAR2,
    p_dep_owner  IN VARCHAR2,
    p_dep_objeto IN VARCHAR2,
    p_tipo_obj   IN VARCHAR2
  ) RETURN VARCHAR2 IS
    l_val VARCHAR2(100);
    l_def VARCHAR2(100);
  BEGIN
    IF UPPER(TRIM(p_tipo_obj)) = 'TRIGGER' THEN
      l_def := 'ENABLE';
    ELSE
      l_def := 'ENABLE_VALIDATE';
    END IF;

    IF func_dm_dep_col_exists('ACCION_POST_MASK') = 1 THEN
      BEGIN
        EXECUTE IMMEDIATE
          'SELECT MAX(UPPER(TRIM(accion_post_mask))) '||
          'FROM tdm_dependencia_final '||
          'WHERE ora_owner = :1 '||
          '  AND table_name = :2 '||
          '  AND UPPER(TRIM(dependencia_owner)) = :3 '||
          '  AND UPPER(TRIM(dependencia_objeto)) = :4'
          INTO l_val
          USING UPPER(TRIM(p_owner_name)),
                UPPER(TRIM(p_table_name)),
                UPPER(TRIM(p_dep_owner)),
                UPPER(TRIM(p_dep_objeto));
        IF l_val IS NOT NULL THEN
          RETURN l_val;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
    END IF;

    RETURN l_def;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_pre_dep
  -- PROPOSITO    : Deshabilita (DDL) las FK, claves y triggers definidos en TDM_DEPENDENCIA_FINAL y
  --                deja constancia en TDM_MASK_DEP_ESTADO para poder rehabilitarlos tras enmascarar.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_esquema, p_tablas_csv (opcional: acota a esas
  --                tablas).
  -- LEE          : DBA_CONSTRAINTS; DBA_TRIGGERS; TDM_COLUMNA_FINAL; TDM_DEPENDENCIA_FINAL
  -- ESCRIBE      : TDM_MASK_DEP_ESTADO (INSERT/UPDATE); DDL: ALTER TABLE ... DISABLE CONSTRAINT ...
  --                CASCADE; DDL: ALTER TRIGGER ... DISABLE; COMMIT
  -- ERRORES      : Sin RAISE_APPLICATION_ERROR: el error de cada dependencia se registra con etapa
  --                PRE_DEP y el bucle continua.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento (esquema completo) y proc_dm_enmascara_tabla
  --                (acotado a sus tablas).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_pre_dep(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_tablas_csv   IN VARCHAR2 DEFAULT NULL
  ) IS
    l_tabla_real VARCHAR2(261);
    l_exists NUMBER;
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_tablas_csv VARCHAR2(4000) := UPPER(TRIM(p_tablas_csv));
    l_categoria_uso VARCHAR2(100);
    l_accion_pre    VARCHAR2(100);
    l_accion_post   VARCHAR2(100);
  BEGIN
    -- FIX 2026-09-27 (auditoria , Nivel 1 #5): p_tablas_csv es opcional
    -- y por defecto NULL -- proc_dm_enmascaramiento (enmascarado de ESQUEMA completo)
    -- sigue llamando sin este parametro y su comportamiento queda IDENTICO al
    -- de siempre (deshabilita TODA dependencia de tdm_dependencia_final del
    -- esquema). Solo proc_dm_enmascara_tabla (enmascarado SELECTIVO de 1 o varias tablas)
    -- pasa aqui su lista de tablas, para no deshabilitar FK/triggers de tablas
    -- que no va a tocar -- antes de este fix, proc_dm_enmascara_tabla sobre 1 sola tabla
    -- deshabilitaba dependencias del ESQUEMA COMPLETO, con el riesgo real de
    -- interferir con otra operacion concurrente sobre el mismo esquema
    -- (ver tambien el guarda de concurrencia añadido en proc_dm_enmascara_tabla).
    proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'INICIO', 'Deshabilitando dependencias definidas en TDM_DEPENDENCIA_FINAL'||
                  CASE WHEN l_tablas_csv IS NOT NULL THEN ' (acotado a tablas: '||l_tablas_csv||')' ELSE '' END);

    -- A.3: Enumerar y trazar la jerarquía FK (hija -> padre) de las tablas a enmascarar
    FOR fk IN (
      SELECT c.owner        child_owner,  c.table_name child_table,
             c.constraint_name fk_name,    c.status,
             pk.table_name    parent_table, c.r_owner parent_owner
        FROM dba_constraints c
        JOIN dba_constraints pk ON pk.owner = c.r_owner AND pk.constraint_name = c.r_constraint_name
       WHERE c.constraint_type = 'R'
         AND c.owner = l_esquema
         AND c.table_name IN (SELECT DISTINCT table_name FROM tdm_columna_final
                               WHERE ora_owner = l_esquema AND enmascarar = 'Y')
         AND (l_tablas_csv IS NULL OR ','||l_tablas_csv||',' LIKE '%,'||c.table_name||',%')
       ORDER BY c.table_name, pk.table_name
    ) LOOP
      proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'FK_JERARQUIA',
         'hija: '||fk.child_owner||'.'||fk.child_table||
         ' -> padre: '||fk.parent_owner||'.'||fk.parent_table||
         ' (constraint '||fk.fk_name||', estado '||fk.status||')');
    END LOOP;

    FOR rc IN (
      SELECT tipo_dependencia, dependencia_owner, dependencia_objeto, table_name
        FROM (
          SELECT tipo_dependencia,
                 dependencia_owner,
                 dependencia_objeto,
                 table_name,
                 ROW_NUMBER() OVER (
                   PARTITION BY UPPER(TRIM(tipo_dependencia)),
                                UPPER(TRIM(dependencia_owner)),
                                UPPER(TRIM(dependencia_objeto))
                   ORDER BY table_name
                 ) rn
            FROM tdm_dependencia_final
           WHERE ora_owner = l_esquema
             AND (l_tablas_csv IS NULL OR ','||l_tablas_csv||',' LIKE '%,'||UPPER(table_name)||',%')
        )
       WHERE rn = 1
       ORDER BY CASE
                  WHEN UPPER(TRIM(tipo_dependencia)) = 'TRIGGER' THEN 1
                  ELSE 2
                END,
                UPPER(TRIM(dependencia_owner)),
                UPPER(TRIM(table_name)),
                UPPER(TRIM(dependencia_objeto))
    ) LOOP
      BEGIN
        proc_dm_dep_policy(
          p_owner_name       => l_esquema,
          p_table_name       => rc.table_name,
          p_dep_owner        => rc.dependencia_owner,
          p_dep_objeto       => rc.dependencia_objeto,
          p_tipo_dependencia => rc.tipo_dependencia,
          p_categoria_uso    => l_categoria_uso,
          p_accion_pre       => l_accion_pre,
          p_accion_post      => l_accion_post
        );

        IF func_dm_norm(rc.tipo_dependencia) IN ('FK','CONSTRAINT','R','FOREIGN KEY','PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE') THEN
          IF l_accion_pre <> 'DISABLE' THEN
            proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_POLICY',
              'CONSTRAINT '||func_dm_safe_name(rc.dependencia_owner)||'.'||func_dm_safe_name(rc.dependencia_objeto)||
              ' accion_pre='||func_dm_safe_name(l_accion_pre)||' (SOLO_INFORMATIVO=solo traza, sin DDL; SIN_ACCION=no intervenir)'||
              ' categoria='||func_dm_safe_name(l_categoria_uso)
            );
            CONTINUE;
          END IF;
          BEGIN
            SELECT c.table_name INTO l_tabla_real
              FROM dba_constraints c
             WHERE c.owner = UPPER(TRIM(rc.dependencia_owner))
               AND c.constraint_name = UPPER(TRIM(rc.dependencia_objeto))
               AND ROWNUM = 1;
          EXCEPTION
            WHEN OTHERS THEN
              l_tabla_real := rc.table_name;
          END;

          INSERT INTO tdm_mask_dep_estado(
            solicitud_id, tipo_objeto, ora_owner, table_name, objeto_name, estado_previo, fecha_pre
          ) VALUES (
            p_solicitud_id, 'CONSTRAINT', UPPER(TRIM(rc.dependencia_owner)), UPPER(TRIM(l_tabla_real)), UPPER(TRIM(rc.dependencia_objeto)), 'ENABLED', SYSTIMESTAMP
          );
          BEGIN
            SELECT COUNT(*)
              INTO l_exists
              FROM dba_constraints c
             WHERE c.owner = UPPER(TRIM(rc.dependencia_owner))
               AND c.table_name = UPPER(TRIM(l_tabla_real))
               AND c.constraint_name = UPPER(TRIM(rc.dependencia_objeto));
          EXCEPTION
            WHEN OTHERS THEN
              l_exists := 0;
          END;

          IF l_exists > 0 THEN
            -- FIX 2026-10-04 (hallazgo real, no artefacto del incidente de
            -- concurrencia): este bucle ordena el DISABLE por
            -- ora_owner/table_name/objeto_name (ver ORDER BY arriba), NO
            -- por profundidad real de dependencia FK. Eso deja una PK/UK
            -- "atrapada": si tiene un hijo FK en una tabla cuyo nombre
            -- ordena DESPUES alfabeticamente (p.ej. PK_TBL_PERSONAS en
            -- TBL_PERSONAS vs su hijo SYS_C00125502 en
            -- TBL_RENOVACION_CONSTRAINT, 'R' > 'P'), el DISABLE de la PK se
            -- intenta ANTES de que ese hijo se haya deshabilitado, y Oracle
            -- lo rechaza con ORA-02297 ("existen dependencias") -- visto de
            -- verdad en produccion (ejecucion_id=5, WARN_DEP sobre
            -- PK_TBL_PERSONAS). CASCADE resuelve esto sin reescribir el
            -- orden: para un hijo FK sin dependientes propios es un no-op
            -- inofensivo (nada que cascadear); para una PK/UK con hijos
            -- ENABLED los deshabilita a todos de una vez, sea cual sea el
            -- orden en que este bucle los visite despues (un DISABLE
            -- posterior sobre un hijo ya deshabilitado por la cascada
            -- tampoco da error, es idempotente).
            EXECUTE IMMEDIATE
              'ALTER TABLE '||func_dm_qname(rc.dependencia_owner)||'.'||func_dm_qname(l_tabla_real)||
              ' DISABLE CONSTRAINT '||func_dm_qname(rc.dependencia_objeto)||' CASCADE';
            UPDATE tdm_mask_dep_estado
               SET deshabilitado_ok = 'Y'
             WHERE solicitud_id = p_solicitud_id
               AND tipo_objeto  = 'CONSTRAINT'
               AND ora_owner   = UPPER(TRIM(rc.dependencia_owner))
               AND table_name   = UPPER(TRIM(l_tabla_real))
               AND objeto_name  = UPPER(TRIM(rc.dependencia_objeto));
          ELSE
            UPDATE tdm_mask_dep_estado
               SET deshabilitado_ok = 'N',
                   habilitado_ok = 'Y'
             WHERE solicitud_id = p_solicitud_id
               AND tipo_objeto  = 'CONSTRAINT'
               AND ora_owner   = UPPER(TRIM(rc.dependencia_owner))
               AND table_name   = UPPER(TRIM(l_tabla_real))
               AND objeto_name  = UPPER(TRIM(rc.dependencia_objeto));
            proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_NOT_FOUND',
              'CONSTRAINT '||func_dm_safe_name(rc.dependencia_owner)||'.'||func_dm_safe_name(rc.dependencia_objeto)||' no existe'
            );
          END IF;

        ELSIF func_dm_norm(rc.tipo_dependencia) = 'TRIGGER' THEN
          IF l_accion_pre <> 'DISABLE' THEN
            proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_POLICY',
              'TRIGGER '||func_dm_safe_name(rc.dependencia_owner)||'.'||func_dm_safe_name(rc.dependencia_objeto)||
              ' accion_pre='||func_dm_safe_name(l_accion_pre)||' (SOLO_INFORMATIVO=solo traza, sin DDL; SIN_ACCION=no intervenir)'||
              ' categoria='||func_dm_safe_name(l_categoria_uso)
            );
            CONTINUE;
          END IF;
          INSERT INTO tdm_mask_dep_estado(
            solicitud_id, tipo_objeto, ora_owner, table_name, objeto_name, estado_previo, fecha_pre
          ) VALUES (
            p_solicitud_id, 'TRIGGER', UPPER(TRIM(rc.dependencia_owner)), UPPER(TRIM(rc.table_name)), UPPER(TRIM(rc.dependencia_objeto)), 'ENABLED', SYSTIMESTAMP
          );
          BEGIN
            SELECT COUNT(*)
              INTO l_exists
              FROM dba_triggers t
             WHERE t.owner = UPPER(TRIM(rc.dependencia_owner))
               AND t.trigger_name = UPPER(TRIM(rc.dependencia_objeto));
          EXCEPTION
            WHEN OTHERS THEN
              l_exists := 0;
          END;

          IF l_exists > 0 THEN
            EXECUTE IMMEDIATE 'ALTER TRIGGER '||func_dm_qname(rc.dependencia_owner)||'.'||func_dm_qname(rc.dependencia_objeto)||' DISABLE';
            UPDATE tdm_mask_dep_estado
               SET deshabilitado_ok = 'Y'
             WHERE solicitud_id = p_solicitud_id
               AND tipo_objeto  = 'TRIGGER'
               AND ora_owner   = UPPER(TRIM(rc.dependencia_owner))
               AND objeto_name  = UPPER(TRIM(rc.dependencia_objeto));
          ELSE
            UPDATE tdm_mask_dep_estado
               SET deshabilitado_ok = 'N',
                   habilitado_ok = 'Y'
             WHERE solicitud_id = p_solicitud_id
               AND tipo_objeto  = 'TRIGGER'
               AND ora_owner   = UPPER(TRIM(rc.dependencia_owner))
               AND objeto_name  = UPPER(TRIM(rc.dependencia_objeto));
            proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_NOT_FOUND',
              'TRIGGER '||func_dm_safe_name(rc.dependencia_owner)||'.'||func_dm_safe_name(rc.dependencia_objeto)||' no existe'
            );
          END IF;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          -- B.2: Registrar error de dependencia PRE en tdm_ejecucion_error (deja tambien
          -- la linea ERROR.REGISTRADO en la linea de tiempo)
          proc_dm_log_ejec_error(
            p_ejecucion_id => p_ejecucion_id,
            p_solicitud_id => p_solicitud_id,
            p_owner_name   => rc.dependencia_owner,
            p_table_name   => rc.table_name,
            p_column_name  => NULL,
            p_etapa        => 'PRE_DEP',
            p_codigo_error => SQLCODE,
            p_mensaje      => func_dm_safe_name(rc.tipo_dependencia)||' '||func_dm_safe_name(rc.dependencia_owner)||'.'||
                              func_dm_safe_name(rc.dependencia_objeto)||' => '||SQLERRM,
            p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
          );
      END;
    END LOOP;

    COMMIT;
    proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'FIN', 'Dependencias deshabilitadas');
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_post_dep
  -- PROPOSITO    : Rehabilita (DDL) los triggers y constraints que proc_dm_pre_dep dejo
  --                deshabilitados, segun la accion post configurada, y registra el resultado.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id.
  -- LEE          : TDM_MASK_DEP_ESTADO; DBA_CONSTRAINTS; TDM_DEPENDENCIA_FINAL (via
  --                func_dm_dep_post_action)
  -- ESCRIBE      : TDM_MASK_DEP_ESTADO (UPDATE estado_posterior, habilitado_ok); DDL: ALTER TRIGGER
  --                ... ENABLE; DDL: ALTER TABLE ... ENABLE [VALIDATE|NOVALIDATE] CONSTRAINT; COMMIT
  -- ERRORES      : Sin RAISE_APPLICATION_ERROR: los fallos se registran con etapa POST_DEP_TRIGGER o
  --                POST_DEP_CONSTRAINT y se sigue.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento (flujo normal y manejador de error) y
  --                proc_dm_enmascara_tabla.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_post_dep(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER
  ) IS
    l_owner  VARCHAR2(261);
    l_objeto VARCHAR2(261);
    l_tabla  VARCHAR2(261);
    l_accion_post VARCHAR2(100);
  BEGIN
    proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'POST', 'INICIO', 'Rehabilitando dependencias');

    FOR rc IN (
      SELECT ora_owner, objeto_name
        FROM tdm_mask_dep_estado
       WHERE solicitud_id = p_solicitud_id
         AND tipo_objeto = 'TRIGGER'
         AND deshabilitado_ok = 'Y'
       ORDER BY ora_owner, objeto_name
    ) LOOP
      l_owner := rc.ora_owner; l_objeto := rc.objeto_name;
      l_accion_post := func_dm_dep_post_action(l_owner, NULL, l_owner, l_objeto, 'TRIGGER');
      IF l_accion_post IN ('SIN_ACCION','REVISAR') THEN
        proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST','SKIP_POST_POLICY',
                      'TRIGGER '||func_dm_safe_name(l_owner)||'.'||func_dm_safe_name(l_objeto)||
                      ' accion_post='||func_dm_safe_name(l_accion_post)||
                      ' (REVISAR/SIN_ACCION=requiere revisión manual, no se ejecuta ENABLE)');
        CONTINUE;
      END IF;
      BEGIN
        EXECUTE IMMEDIATE 'ALTER TRIGGER '||func_dm_qname(l_owner)||'.'||func_dm_qname(l_objeto)||' ENABLE';
        UPDATE tdm_mask_dep_estado
           SET estado_posterior = SUBSTR('ENABLED',1,30), fecha_post = SYSTIMESTAMP, habilitado_ok = 'Y'
         WHERE solicitud_id = p_solicitud_id AND tipo_objeto='TRIGGER'
           AND ora_owner=l_owner AND objeto_name=l_objeto;
      EXCEPTION WHEN OTHERS THEN
        UPDATE tdm_mask_dep_estado
           SET estado_posterior = SUBSTR('ERROR',1,30), fecha_post = SYSTIMESTAMP, habilitado_ok = 'N'
         WHERE solicitud_id = p_solicitud_id AND tipo_objeto='TRIGGER'
           AND ora_owner=l_owner AND objeto_name=l_objeto;
        -- B.2: Registrar error de dependencia POST en tdm_ejecucion_error (deja tambien
        -- la linea ERROR.REGISTRADO en la linea de tiempo)
        proc_dm_log_ejec_error(
          p_ejecucion_id => p_ejecucion_id,
          p_solicitud_id => p_solicitud_id,
          p_owner_name   => l_owner,
          p_table_name   => NULL,
          p_column_name  => NULL,
          p_etapa        => 'POST_DEP_TRIGGER',
          p_codigo_error => SQLCODE,
          p_mensaje      => 'TRIGGER '||func_dm_safe_name(l_owner)||'.'||func_dm_safe_name(l_objeto)||' => '||SQLERRM,
          p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
      END;
    END LOOP;

    FOR rc IN (
      SELECT d.ora_owner, d.table_name, d.objeto_name
        FROM tdm_mask_dep_estado d
        LEFT JOIN dba_constraints c
          ON c.owner = d.ora_owner AND c.constraint_name = d.objeto_name
       WHERE d.solicitud_id = p_solicitud_id
         AND d.tipo_objeto = 'CONSTRAINT'
         AND d.deshabilitado_ok = 'Y'
       ORDER BY CASE NVL(c.constraint_type, 'P')
                  WHEN 'P' THEN 1
                  WHEN 'U' THEN 2
                  WHEN 'C' THEN 3
                  ELSE 4
                END,
                d.ora_owner, d.table_name, d.objeto_name
    ) LOOP
      l_owner := rc.ora_owner; l_tabla := rc.table_name; l_objeto := rc.objeto_name;
      l_accion_post := func_dm_dep_post_action(l_owner, l_tabla, l_owner, l_objeto, 'CONSTRAINT');
      IF l_accion_post IN ('SIN_ACCION','REVISAR') THEN
        proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST','SKIP_POST_POLICY',
                      'CONSTRAINT '||func_dm_safe_name(l_owner)||'.'||func_dm_safe_name(l_tabla)||'.'||func_dm_safe_name(l_objeto)||
                      ' accion_post='||func_dm_safe_name(l_accion_post)||
                      ' (REVISAR/SIN_ACCION=requiere revisión manual, no se ejecuta ENABLE)');
        CONTINUE;
      END IF;
      BEGIN
        IF l_accion_post = 'ENABLE_VALIDATE' THEN
          EXECUTE IMMEDIATE 'ALTER TABLE '||func_dm_qname(l_owner)||'.'||func_dm_qname(l_tabla)||
                            ' ENABLE VALIDATE CONSTRAINT '||func_dm_qname(l_objeto);
        ELSIF l_accion_post = 'ENABLE' THEN
          EXECUTE IMMEDIATE 'ALTER TABLE '||func_dm_qname(l_owner)||'.'||func_dm_qname(l_tabla)||
                            ' ENABLE CONSTRAINT '||func_dm_qname(l_objeto);
        ELSE
          EXECUTE IMMEDIATE 'ALTER TABLE '||func_dm_qname(l_owner)||'.'||func_dm_qname(l_tabla)||
                            ' ENABLE NOVALIDATE CONSTRAINT '||func_dm_qname(l_objeto);
        END IF;
        UPDATE tdm_mask_dep_estado
           SET estado_posterior = SUBSTR(l_accion_post,1,30), fecha_post = SYSTIMESTAMP, habilitado_ok = 'Y'
         WHERE solicitud_id = p_solicitud_id AND tipo_objeto='CONSTRAINT'
           AND ora_owner=l_owner AND table_name=l_tabla AND objeto_name=l_objeto;
      EXCEPTION WHEN OTHERS THEN
        UPDATE tdm_mask_dep_estado
           SET estado_posterior = SUBSTR('ERROR',1,30), fecha_post = SYSTIMESTAMP, habilitado_ok = 'N'
         WHERE solicitud_id = p_solicitud_id AND tipo_objeto='CONSTRAINT'
           AND ora_owner=l_owner AND table_name=l_tabla AND objeto_name=l_objeto;
        -- B.2: Registrar error de dependencia POST en tdm_ejecucion_error (deja tambien
        -- la linea ERROR.REGISTRADO en la linea de tiempo)
        proc_dm_log_ejec_error(
          p_ejecucion_id => p_ejecucion_id,
          p_solicitud_id => p_solicitud_id,
          p_owner_name   => l_owner,
          p_table_name   => l_tabla,
          p_column_name  => NULL,
          p_etapa        => 'POST_DEP_CONSTRAINT',
          p_codigo_error => SQLCODE,
          p_mensaje      => 'CONSTRAINT '||func_dm_safe_name(l_owner)||'.'||func_dm_safe_name(l_tabla)||'.'||func_dm_safe_name(l_objeto)||' => '||SQLERRM,
          p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
      END;
    END LOOP;

    COMMIT;
    proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'POST', 'FIN', 'Dependencias rehabilitadas');
  END;

  ------------------------------------------------------------------------------
  -- Máscara de una columna
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_min_len_identificador
  -- PROPOSITO    : Devuelve la longitud minima de columna necesaria para poder enmascarar un tipo de
  --                identificador.
  -- ENTRADAS     : p_identificador; retorna numero (p. ej. 8 identidad, 7 telefono, 5 email, 10
  --                bancario, por defecto 1).
  -- LEE          : ninguno
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno
  -- LLAMADO DESDE: Interno: proc_dm_apl_col.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_min_len_identificador(p_identificador IN VARCHAR2) RETURN NUMBER DETERMINISTIC IS
    l_id VARCHAR2(100) := func_dm_norm(p_identificador);
  BEGIN
    CASE l_id
      WHEN 'IDENTIFICADOR_IDENTIDAD' THEN RETURN 8; -- DNI/NIF/NIE mínimo útil
      WHEN 'IDENTIFICADOR_TELEFONO'  THEN RETURN 7;
      WHEN 'IDENTIFICADOR_EMAIL'     THEN RETURN 5; -- a@b.c
      WHEN 'IDENTIFICADOR_BANCARIO'  THEN RETURN 10;
      WHEN 'IDENTIFICADOR_NOMBRE'    THEN RETURN 2;
      WHEN 'IDENTIFICADOR_PERSONAL'  THEN RETURN 2;
      WHEN 'IDENTIFICADOR_DIRECCION' THEN RETURN 3;
      ELSE RETURN 1;
    END CASE;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_upsert_excepcion_col
  -- PROPOSITO    : Crea o actualiza una excepcion EXCLUDE/FORCE activa para una columna en
  --                TDM_EXCEPCION_COL.
  -- ENTRADAS     : p_owner, p_tabla, p_columna, p_accion, p_ident_forz, p_razon.
  -- LEE          : ninguno
  -- ESCRIBE      : TDM_EXCEPCION_COL (MERGE + COMMIT)
  -- ERRORES      : Sin captura de errores: un fallo del MERGE se propaga al llamador.
  -- LLAMADO DESDE: Interno: proc_dm_apl_col (auto-exclusiones).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_upsert_excepcion_col(
    p_owner         IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_columna       IN VARCHAR2,
    p_accion        IN VARCHAR2,
    p_ident_forz    IN VARCHAR2,
    p_razon         IN VARCHAR2
  ) IS
    l_owner       VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla       VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna     VARCHAR2(128) := UPPER(TRIM(p_columna));
    l_ident_forz  VARCHAR2(50)  := CASE WHEN p_ident_forz IS NULL THEN NULL ELSE UPPER(TRIM(p_ident_forz)) END;
  BEGIN
    MERGE INTO tdm_excepcion_col t
    USING (
      SELECT l_owner ora_owner,
             l_tabla table_name,
             l_columna column_name
        FROM dual
    ) s
    ON (
      t.ora_owner = s.ora_owner AND
      t.table_name = s.table_name AND
      t.column_name = s.column_name
    )
    WHEN MATCHED THEN UPDATE SET
      t.accion = SUBSTR(UPPER(NVL(p_accion,'EXCLUDE')),1,10),
      t.identificador_forz = CASE WHEN l_ident_forz IS NULL THEN t.identificador_forz ELSE SUBSTR(l_ident_forz,1,50) END,
      t.razon = SUBSTR(p_razon,1,1000),
      t.activa = 'Y'
    WHEN NOT MATCHED THEN INSERT (
      ora_owner, table_name, column_name, accion, identificador_forz, razon, activa
    ) VALUES (
      l_owner, l_tabla, l_columna,
      SUBSTR(UPPER(NVL(p_accion,'EXCLUDE')),1,10),
      CASE WHEN l_ident_forz IS NULL THEN NULL ELSE SUBSTR(l_ident_forz,1,50) END,
      SUBSTR(p_razon,1,1000),
      'Y'
    );
    COMMIT;
  -- Sin EXCEPTION propio (2026-09-16): esta es la API con la que el DBA fija
  -- una excepcion EXCLUDE/FORCE por columna. Un WHEN OTHERS THEN NULL aqui
  -- devolvia "exito" aunque el MERGE no hubiera grabado nada - el DBA podia
  -- creer protegida (o forzada a un identificador) una columna que en
  -- realidad seguia con el tratamiento por defecto. Se deja propagar.
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_get_excepcion
  -- PROPOSITO    : Lee la excepcion activa (accion e identificador forzado) de una columna.
  -- ENTRADAS     : p_owner, p_tabla, p_columna; OUT p_accion, p_ident_forzado.
  -- LEE          : TDM_EXCEPCION_COL
  -- ESCRIBE      : ninguno
  -- ERRORES      : Cualquier error devuelve NULL en ambos OUT (sin excepcion).
  -- LLAMADO DESDE: Interno: proc_dm_apl_col.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_get_excepcion(
    p_owner         IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_columna       IN VARCHAR2,
    p_accion        OUT VARCHAR2,
    p_ident_forzado OUT VARCHAR2
  ) IS
    l_owner   VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla   VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna VARCHAR2(128) := UPPER(TRIM(p_columna));
  BEGIN
    p_accion := NULL;
    p_ident_forzado := NULL;
    SELECT accion, identificador_forz
      INTO p_accion, p_ident_forzado
      FROM tdm_excepcion_col
     WHERE ora_owner = l_owner
       AND table_name = l_tabla
       AND column_name = l_columna
       AND activa = 'Y'
       AND ROWNUM = 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_accion := NULL;
      p_ident_forzado := NULL;
    WHEN OTHERS THEN
      p_accion := NULL;
      p_ident_forzado := NULL;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_apl_col
  -- PROPOSITO    : Enmascara una columna: resuelve excepcion y longitud minima, elige regla especial
  --                o expresion por identificador, ejecuta el UPDATE y anota APPLY_COL como punto de
  --                control.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_esquema, p_owner, p_tabla, p_columna,
  --                p_identificador.
  -- LEE          : TDM_EXCEPCION_COL; TDM_COLUMNA_HIST; DBA_TAB_COLUMNS; TDM_MASK_REGLA_ESP (via
  --                func_dm_tiene_regla / func_dm_val_regla)
  -- ESCRIBE      : UPDATE de la columna objetivo (via proc_dm_ejecuta_update_seguro);
  --                TDM_EXCEPCION_COL (MERGE de auto-exclusion); TDM_COLUMNA_FINAL (enmascarar = N en
  --                auto-exclusion); TDM_MASK_TRACE (COL_INICIO, RUTA, APPLY_COL y pasos SKIP_*);
  --                COMMIT
  -- ERRORES      : No levanta ORA-2xxxx propio.; Auto-excluye (sin error) ante ORA-00001/ORA-20322,
  --                ORA-12899/ORA-20323 y ORA-06502/ORA-20321 sin fallback valido, y por longitud
  --                menor al minimo.; Cualquier otro error se re-propaga (incluye ORA-20320,
  --                ORA-20330, ORA-20350).
  -- LLAMADO DESDE: Interno: proc_dm_mask_cat (flujo de esquema) y proc_dm_enmascara_tabla (modo por
  --                tabla).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_apl_col(
    p_solicitud_id  IN NUMBER,
    p_ejecucion_id  IN NUMBER,
    p_esquema       IN VARCHAR2,
    p_owner         IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_columna       IN VARCHAR2,
    p_identificador IN VARCHAR2
  ) IS
    l_sql      CLOB;
    l_rows     NUMBER;
    l_target   VARCHAR2(512);
    l_col_tipo VARCHAR2(128);
    l_expr     VARCHAR2(4000);
    l_accion   VARCHAR2(10);
    l_ident_forzado VARCHAR2(50);
    l_ident_final VARCHAR2(100);
    l_data_type dba_tab_columns.data_type%TYPE;
    l_char_len NUMBER;
    l_min_len  NUMBER;
    l_rows_retry NUMBER;
    l_owner    VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla    VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna  VARCHAR2(128) := UPPER(TRIM(p_columna));
    l_t0       TIMESTAMP WITH TIME ZONE := SYSTIMESTAMP;   -- traza: duracion de la columna
  BEGIN
    l_target := func_dm_norm(p_owner)||'.'||func_dm_norm(p_tabla)||'.'||func_dm_norm(p_columna);
    l_ident_final := func_dm_norm(p_identificador);

    proc_dm_get_excepcion(p_owner,p_tabla,p_columna,l_accion,l_ident_forzado);
    IF l_ident_forzado IS NOT NULL THEN
      l_ident_final := func_dm_norm(l_ident_forzado);
      proc_dm_trace(
        p_solicitud_id,
        p_ejecucion_id,
        'MASK',
        'EXCEPTION_FORCE',
        l_target||' identificador_forzado='||l_ident_final);
    END IF;

    IF func_dm_norm(l_accion) = 'EXCLUDE' THEN
      proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','SKIP_EXCLUDE',l_target||' excluida por tdm_excepcion_col');
      RETURN;
    END IF;

    BEGIN
      -- 1) Priorizar metadata del snapshot analítico (tdm_columna_hist)
      SELECT data_type, data_length
        INTO l_data_type, l_char_len
        FROM tdm_columna_hist
       WHERE ejecucion_id = p_ejecucion_id
         AND ora_owner   = l_owner
         AND table_name   = l_tabla
         AND column_name  = l_columna
         AND NVL(vigente,'Y') = 'Y'
         AND ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        BEGIN
          -- 2) Fallback al diccionario DBA_TAB_COLUMNS
          SELECT data_type, NVL(char_col_decl_length, data_length)
            INTO l_data_type, l_char_len
            FROM dba_tab_columns
           WHERE owner = l_owner
             AND table_name = l_tabla
             AND column_name = l_columna;
        EXCEPTION
          WHEN OTHERS THEN
            l_data_type := NULL;
            l_char_len := NULL;
        END;
      WHEN OTHERS THEN
        l_data_type := NULL;
        l_char_len := NULL;
    END;

    l_min_len := func_dm_min_len_identificador(l_ident_final);
    IF l_data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2')
       AND NVL(l_char_len,0) < l_min_len THEN
      -- FIX 2026-10-09: un FORCE del negocio NO se reescribe como EXCLUDE (antes
      -- el MERGE pisaba la regla del DBA sin avisar). Solo se auto-excluye
      -- (y persiste) cuando la columna NO tenia FORCE explicito.
      IF l_ident_forzado IS NULL THEN
        proc_dm_upsert_excepcion_col(
          p_owner      => p_owner,
          p_tabla      => p_tabla,
          p_columna    => p_columna,
          p_accion     => 'EXCLUDE',
          p_ident_forz => NULL,
          p_razon      => 'AUTO-EXCLUDE: longitud columna ('||NVL(l_char_len,0)||') menor al mínimo para '||l_ident_final||' ('||l_min_len||')'
        );
      END IF;
      UPDATE tdm_columna_final
         SET enmascarar = 'N'
       WHERE ora_owner = l_owner
         AND table_name = l_tabla
         AND column_name = l_columna;
      COMMIT;
      -- FIX 2026-10-09: nivel WARN (antes INFO): es un dato clasificado como
      -- sensible que queda SIN enmascarar; debe verse en el resumen final.
      proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','SKIP_AUTO_LEN',
        l_target||' SIN ENMASCARAR: longitud columna ('||NVL(l_char_len,0)||') < minimo '||l_min_len||
        ' para '||l_ident_final||CASE WHEN l_ident_forzado IS NOT NULL THEN ' (columna FORZADA por tdm_excepcion_col; la regla se conserva)' ELSE '' END);
      RETURN;
    END IF;

    proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','COL_INICIO',
                  l_target||' identificador='||l_ident_final);

    IF func_dm_tiene_regla(p_esquema,p_owner,p_tabla,p_columna,'DOC_SEGUN_TIPO') > 0 THEN
      l_col_tipo := func_dm_val_regla(p_esquema,p_owner,p_tabla,p_columna,'DOC_SEGUN_TIPO');
      l_sql := 'UPDATE '||func_dm_qname(p_owner)||'.'||func_dm_qname(p_tabla)||
               ' SET '||func_dm_qname(p_columna)||' = pkg_dm_func_mask.func_dm_espec_doc_segun_tipo('||func_dm_qname(p_columna)||','||func_dm_qname(l_col_tipo)||')' ||
               ' WHERE '||func_dm_qname(p_columna)||' IS NOT NULL';
      proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, l_rows);

    ELSIF func_dm_tiene_regla(p_esquema,p_owner,p_tabla,p_columna,'DOC_UNIFICADO_MANTENER_1_Y_ULTIMO') > 0 THEN
      l_sql := 'UPDATE '||func_dm_qname(p_owner)||'.'||func_dm_qname(p_tabla)||
               ' SET '||func_dm_qname(p_columna)||' = pkg_dm_func_mask.func_dm_especial_doc_keep_ends('||func_dm_qname(p_columna)||')' ||
               ' WHERE '||func_dm_qname(p_columna)||' IS NOT NULL';
      proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, l_rows);

    ELSIF func_dm_tiene_regla(p_esquema,p_owner,p_tabla,p_columna,'IBAN_ES_CONTINUO') > 0 THEN
      -- C-01: NO truncar. func_dm_especial_iban_continuo devuelve 24 chars exactos;
      -- si la columna fuera mas corta, ORA-12899 (fallo cerrado) mejor que corromper.
      l_sql := 'UPDATE '||func_dm_qname(p_owner)||'.'||func_dm_qname(p_tabla)||
               ' SET '||func_dm_qname(p_columna)||' = pkg_dm_func_mask.func_dm_especial_iban_continuo('||func_dm_qname(p_columna)||')' ||
               ' WHERE '||func_dm_qname(p_columna)||' IS NOT NULL';
      proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, l_rows);

    ELSE
      l_expr := func_dm_expr_compatible(p_owner,p_tabla,p_columna,l_ident_final);
      l_sql := 'UPDATE '||func_dm_qname(p_owner)||'.'||func_dm_qname(p_tabla)||
               ' SET '||func_dm_qname(p_columna)||' = '||l_expr||
               ' WHERE '||func_dm_qname(p_columna)||' IS NOT NULL';
      proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, l_rows);
    END IF;

    COMMIT;

    -- UNA linea por columna: ruta y filas juntas (antes RUTA iba aparte, con la misma hora que APPLY_COL).
    -- La reanudacion lee solo el prefijo 'OWNER.TABLA.COLUMNA filas=N' (punto de control): el texto
    -- de la ruta va DESPUES de filas=N y no puede cambiar ese prefijo.
    proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','APPLY_COL',
      l_target||' filas='||l_rows||CASE WHEN g_ruta IS NOT NULL THEN ' ruta='||g_ruta END,
      pkg_dm_trazabilidad.func_dm_seg_desde(l_t0));
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE IN (-1, -20322) THEN
        -- Colision de unicidad (ORA-00001), directo o vía -20322 (mismo error
        -- homogeneizado desde TODOS los chunks paralelos, FIX 2026-09-27 en
        -- proc_dm_ejecuta_update_seguro). Con FF1 los dominios numericos son
        -- biyectivos y NO llegan aqui; si ocurre es una columna de TEXTO unica.
        -- Se auto-excluye (no se fabrica sufijo ORA_HASH, que rompia la FK).
        proc_dm_upsert_excepcion_col(
          p_owner      => p_owner,
          p_tabla      => p_tabla,
          p_columna    => p_columna,
          p_accion     => 'EXCLUDE',
          p_ident_forz => NULL,
          p_razon      => 'AUTO-EXCLUDE ORA-00001 (colision en dominio no biyectivo): '||SUBSTR(SQLERRM,1,820)
        );
        UPDATE tdm_columna_final
           SET enmascarar = 'N'
         WHERE ora_owner = l_owner
           AND table_name = l_tabla
           AND column_name = l_columna;
        COMMIT;
        proc_dm_trace(
          p_solicitud_id, p_ejecucion_id, 'MASK', 'SKIP_ORA00001',
          l_target||' auto-excluida tras ORA-00001 (sin sufijo ORA_HASH)', pkg_dm_trazabilidad.func_dm_seg_desde(l_t0));
      ELSIF SQLCODE IN (-12899, -20323) THEN
        -- -20323: mismo ORA-12899 pero homogeneizado desde TODOS los chunks
        -- paralelos (FIX 2026-09-27, ver comentario en proc_dm_ejecuta_update_seguro).
        proc_dm_upsert_excepcion_col(
          p_owner      => p_owner,
          p_tabla      => p_tabla,
          p_columna    => p_columna,
          p_accion     => 'EXCLUDE',
          p_ident_forz => NULL,
          p_razon      => 'AUTO-EXCLUDE ORA-12899 en enmascaramiento: '||SUBSTR(SQLERRM,1,850)
        );
        UPDATE tdm_columna_final
           SET enmascarar = 'N'
         WHERE ora_owner = l_owner
           AND table_name = l_tabla
           AND column_name = l_columna;
        COMMIT;
        proc_dm_trace(
          p_solicitud_id,
          p_ejecucion_id,
          'MASK',
          'SKIP_ORA12899',
          l_target||' auto-excluida tras ORA-12899', pkg_dm_trazabilidad.func_dm_seg_desde(l_t0));
      ELSIF SQLCODE IN (-6502, -20321) THEN
        -- FIX 2026-09-18: -20321 es el ORA-06502 puro detectado por
        -- proc_dm_ejecuta_update_seguro cuando la columna se proceso via
        -- DBMS_PARALLEL_EXECUTE (>100k filas). Antes de este fix, ese caso
        -- llegaba aqui como -20320 generico y NUNCA activaba el fallback de
        -- abajo (que ya funcionaba correctamente para la ruta serie/directa).
        IF l_data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2') AND NVL(l_char_len,0) > 0 THEN
          BEGIN
            -- Primer fallback: reutilizar librería oficial de enmascarado
            l_expr := 'SUBSTR(pkg_dm_func_mask.func_dm_generico('''||
                      REPLACE(l_ident_final,'''','''''')||''','||func_dm_qname(p_columna)||'),1,'||TO_CHAR(l_char_len)||')';
            l_sql := 'UPDATE '||func_dm_qname(p_owner)||'.'||func_dm_qname(p_tabla)||
                     ' SET '||func_dm_qname(p_columna)||' = '||l_expr||
                     ' WHERE '||func_dm_qname(p_columna)||' IS NOT NULL';
            BEGIN
              proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, l_rows_retry);
            EXCEPTION
              WHEN OTHERS THEN
                -- Segundo fallback: expresión SQL ultra-segura por tipo de identificador
                IF l_ident_final IN ('IDENTIFICADOR_PERSONAL','IDENTIFICADOR_NOMBRE') THEN
                  l_expr := 'SUBSTR(TRANSLATE(UPPER('||func_dm_qname(p_columna)||'),'||
                            '''ABCDEFGHIJKLMNOPQRSTUVWXYZ'','||
                            '''QWERTYUIOPASDFGHJKLZXCVBNM''),1,'||TO_CHAR(l_char_len)||')';
                ELSIF l_ident_final = 'IDENTIFICADOR_DIRECCION' THEN
                  l_expr := 'SUBSTR(''Calle Ficticia N ''||TO_CHAR(MOD(ORA_HASH('||func_dm_qname(p_columna)||'),999))||'', Zaragoza'',1,'||TO_CHAR(l_char_len)||')';
                ELSIF l_ident_final = 'IDENTIFICADOR_EMAIL' THEN
                  l_expr := 'SUBSTR(''usuario''||TO_CHAR(MOD(ORA_HASH('||func_dm_qname(p_columna)||'),1000000))||''@correo.com'',1,'||TO_CHAR(l_char_len)||')';
                ELSIF l_ident_final = 'IDENTIFICADOR_TELEFONO' THEN
                  l_expr := 'SUBSTR(''6''||LPAD(TO_CHAR(MOD(ORA_HASH('||func_dm_qname(p_columna)||'),100000000)),8,''0''),1,'||TO_CHAR(l_char_len)||')';
                ELSE
                  l_expr := 'SUBSTR(TRANSLATE(UPPER('||func_dm_qname(p_columna)||'),'||
                            '''ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'','||
                            '''QWERTYUIOPASDFGHJKLZXCVBNM9876543210''),1,'||TO_CHAR(l_char_len)||')';
                END IF;
                l_sql := 'UPDATE '||func_dm_qname(p_owner)||'.'||func_dm_qname(p_tabla)||
                         ' SET '||func_dm_qname(p_columna)||' = '||l_expr||
                         ' WHERE '||func_dm_qname(p_columna)||' IS NOT NULL';
                proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, l_rows_retry);
            END;
            COMMIT;
            proc_dm_trace(
              p_solicitud_id,
              p_ejecucion_id,
              'MASK',
              'APPLY_COL_SAFE_FALLBACK',
              l_target||' filas='||l_rows_retry||' (fallback seguro tras ORA-06502)', pkg_dm_trazabilidad.func_dm_seg_desde(l_t0));
          EXCEPTION
            WHEN OTHERS THEN
              proc_dm_upsert_excepcion_col(
                p_owner      => p_owner,
                p_tabla      => p_tabla,
                p_columna    => p_columna,
                p_accion     => 'EXCLUDE',
                p_ident_forz => NULL,
                p_razon      => 'AUTO-EXCLUDE ORA-06502 en enmascaramiento: '||SUBSTR(func_dm_safe_err(SQLERRM),1,850)
              );
              UPDATE tdm_columna_final
                 SET enmascarar = 'N'
               WHERE ora_owner = l_owner
                 AND table_name = l_tabla
                 AND column_name = l_columna;
              COMMIT;
              proc_dm_trace(
                p_solicitud_id,
                p_ejecucion_id,
                'MASK',
                'SKIP_ORA06502',
                l_target||' auto-excluida tras ORA-06502', pkg_dm_trazabilidad.func_dm_seg_desde(l_t0));
          END;
        ELSE
          proc_dm_upsert_excepcion_col(
            p_owner      => p_owner,
            p_tabla      => p_tabla,
            p_columna    => p_columna,
            p_accion     => 'EXCLUDE',
            p_ident_forz => NULL,
            p_razon      => 'AUTO-EXCLUDE ORA-06502 en enmascaramiento: '||SUBSTR(func_dm_safe_err(SQLERRM),1,850)
          );
          UPDATE tdm_columna_final
             SET enmascarar = 'N'
           WHERE ora_owner = l_owner
             AND table_name = l_tabla
             AND column_name = l_columna;
          COMMIT;
          proc_dm_trace(
            p_solicitud_id,
            p_ejecucion_id,
            'MASK',
            'SKIP_ORA06502',
            l_target||' auto-excluida tras ORA-06502', pkg_dm_trazabilidad.func_dm_seg_desde(l_t0));
        END IF;
      ELSE
        RAISE;
      END IF;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_post_sync
  -- PROPOSITO    : Propaga el valor ya enmascarado de columnas origen a columnas destino segun
  --                TDM_MASK_RELACION_SYNC y verifica que quedan iguales.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_esquema.
  -- LEE          : TDM_MASK_RELACION_SYNC; DBA_TAB_COLUMNS; tablas origen y destino del esquema
  --                (SELECT dinamico de verificacion)
  -- ESCRIBE      : UPDATE de la columna destino (via proc_dm_ejecuta_update_seguro); TDM_MASK_TRACE
  --                (SYNC, SYNC_OK, SYNC_MISMATCH, WARN_SYNC*); COMMIT
  -- ERRORES      : Sin errores propagados: todo fallo por relacion se traza como WARN_SYNC /
  --                WARN_SYNC_CHECK y continua.; Si la longitud origen supera la del destino se omite
  --                la relacion (WARN_SYNC_LEN).
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento y proc_dm_enmascara_tabla.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_post_sync(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  ) IS
    l_sql CLOB;
    l_rows NUMBER;
    l_diff NUMBER;
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_dest_data_type VARCHAR2(30);
    l_dest_len       NUMBER;
    l_len_conflicts  NUMBER;
    l_max_src_len    NUMBER;
  BEGIN
    FOR rc IN (
      SELECT tabla_origen, columna_join_origen, tabla_destino, columna_join_destino,
             columna_origen, columna_destino, prioridad
        FROM tdm_mask_relacion_sync
       WHERE ora_esquema = l_esquema
         AND activa = 'Y'
       ORDER BY prioridad
    ) LOOP
      BEGIN
        BEGIN
          SELECT c.data_type, c.data_length
            INTO l_dest_data_type, l_dest_len
            FROM dba_tab_columns c
           WHERE c.owner = l_esquema
             AND c.table_name = rc.tabla_destino
             AND c.column_name = rc.columna_destino;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            l_dest_data_type := NULL;
            l_dest_len       := NULL;
        END;

        IF l_dest_data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2') AND NVL(l_dest_len,0) > 0 THEN
          l_sql :=
            'SELECT COUNT(*), NVL(MAX(LENGTH(TO_CHAR(s.'||func_dm_qname(rc.columna_origen)||'))),0) '||
            '  FROM '||func_dm_qname(p_esquema)||'.'||func_dm_qname(rc.tabla_destino)||' d '||
            '  JOIN '||func_dm_qname(p_esquema)||'.'||func_dm_qname(rc.tabla_origen)||' s '||
            '    ON s.'||func_dm_qname(rc.columna_join_origen)||' = d.'||func_dm_qname(rc.columna_join_destino)||' '||
            ' WHERE s.'||func_dm_qname(rc.columna_origen)||' IS NOT NULL '||
            '   AND LENGTH(TO_CHAR(s.'||func_dm_qname(rc.columna_origen)||')) > '||TO_CHAR(l_dest_len);
          EXECUTE IMMEDIATE l_sql INTO l_len_conflicts, l_max_src_len;

          IF NVL(l_len_conflicts,0) > 0 THEN
            proc_dm_trace(
              p_solicitud_id,p_ejecucion_id,'POST_SYNC','WARN_SYNC_LEN',
              rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||
              ' skip por longitud. filas_conflictivas='||l_len_conflicts||
              ' max_len_origen='||NVL(l_max_src_len,0)||
              ' max_len_destino='||l_dest_len
            );
            CONTINUE;
          END IF;
        END IF;

        l_sql :=
          'UPDATE '||func_dm_qname(p_esquema)||'.'||func_dm_qname(rc.tabla_destino)||' d '||
          'SET '||func_dm_qname(rc.columna_destino)||' = ('||
          '  SELECT s.'||func_dm_qname(rc.columna_origen)||' FROM '||func_dm_qname(p_esquema)||'.'||func_dm_qname(rc.tabla_origen)||' s '||
          '   WHERE s.'||func_dm_qname(rc.columna_join_origen)||' = d.'||func_dm_qname(rc.columna_join_destino)||' ) '||
          'WHERE EXISTS (SELECT 1 FROM '||func_dm_qname(p_esquema)||'.'||func_dm_qname(rc.tabla_origen)||' s '||
          '               WHERE s.'||func_dm_qname(rc.columna_join_origen)||' = d.'||func_dm_qname(rc.columna_join_destino)||')';
        proc_dm_ejecuta_update_seguro(p_esquema, rc.tabla_destino, rc.columna_destino, l_sql, l_rows);
        COMMIT;
        proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST_SYNC','SYNC',
                      rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' filas='||l_rows);
      EXCEPTION
        WHEN OTHERS THEN
          proc_dm_trace(
            p_solicitud_id,p_ejecucion_id,'POST_SYNC','WARN_SYNC',
            rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' => '||func_dm_safe_err(SQLERRM)
          );
          CONTINUE;
      END;

      BEGIN
        -- Verificación de consistencia padre/hijo según la relación definida
        -- HINT 2026-09-18: PARALLEL aqui es seguro (consulta diagnostica de
        -- verificacion post-sync en la sesion orquestadora, no en un worker
        -- paralelo) y util: es un JOIN + comparacion NVL(TO_CHAR(..)) entre
        -- dos tablas potencialmente grandes, sin indices utilizables por la
        -- comparacion por texto.
        l_sql :=
          'SELECT /*+ PARALLEL(d,4) PARALLEL(s,4) */ COUNT(*) FROM '||func_dm_qname(p_esquema)||'.'||func_dm_qname(rc.tabla_destino)||' d '||
          'JOIN '||func_dm_qname(p_esquema)||'.'||func_dm_qname(rc.tabla_origen)||' s '||
          '  ON s.'||func_dm_qname(rc.columna_join_origen)||' = d.'||func_dm_qname(rc.columna_join_destino)||' '||
          'WHERE NVL(TO_CHAR(d.'||func_dm_qname(rc.columna_destino)||'),''#NULL#'') '||
          '   <> NVL(TO_CHAR(s.'||func_dm_qname(rc.columna_origen)||'),''#NULL#'')';
        EXECUTE IMMEDIATE l_sql INTO l_diff;
        IF NVL(l_diff,0) = 0 THEN
          proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST_SYNC','SYNC_OK',
                        rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' diferencias=0');
        ELSE
          proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST_SYNC','SYNC_MISMATCH',
                        rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' diferencias='||l_diff);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          proc_dm_trace(
            p_solicitud_id,p_ejecucion_id,'POST_SYNC','WARN_SYNC_CHECK',
            rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' => '||func_dm_safe_err(SQLERRM)
          );
      END;
    END LOOP;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_mask_cat
  -- PROPOSITO    : Recorre las columnas pendientes (clasificadas Y mas FORCE vivos, menos EXCLUDE y
  --                las ya confirmadas) llamando a proc_dm_apl_col y actualizando el progreso.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_esquema, p_reproceso; OUT p_error_count
  --                (columnas fallidas).
  -- LEE          : TDM_COLUMNA_FINAL; TDM_EXCEPCION_COL; DBA_TAB_COLUMNS; TDM_MASK_TRACE (APPLY_COL*
  --                para saltar columnas ya hechas)
  -- ESCRIBE      : TDM_MASK_SOLICITUD (contadores y ultima tabla/columna); TDM_EJECUCION
  --                (heartbeat_ts y, via proc_dm_upd_ejec, progreso y FINALIZADO en NOOP);
  --                TDM_MASK_TRACE (RESUMEN, NOOP, SKIP_TABLE)
  -- ERRORES      : No levanta ORA-2xxxx propio; propaga ORA-20081 de proc_dm_chk_cancel.; El error de
  --                cada columna se registra (etapa MASK_APPLY), se cuenta en p_error_count y no
  --                avanza el progreso.
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_mask_cat(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_reproceso    IN VARCHAR2 DEFAULT 'N',
    p_error_count  OUT NUMBER
  ) IS
    l_total_cols NUMBER;
    l_proc_cols  NUMBER := 0;
    l_total_tabs NUMBER;
    l_proc_tabs  NUMBER := 0;
    l_last_tab   VARCHAR2(128);
    l_pct        NUMBER;
    l_esquema    VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_reproceso  VARCHAR2(1) := UPPER(TRIM(NVL(p_reproceso,'N')));
    l_msg_noop   VARCHAR2(1900);
    l_total_rows NUMBER := 0;
    l_has_final  NUMBER := 0;
    l_col_fallida   BOOLEAN := FALSE;
    l_cols_fallidas NUMBER  := 0;
  BEGIN
    p_error_count := 0;

    SELECT CASE WHEN EXISTS (
             SELECT 1 FROM tdm_columna_final WHERE ora_owner = l_esquema AND enmascarar = 'Y'
           ) THEN 1 ELSE 0 END
      INTO l_has_final
      FROM dual;

    IF l_has_final = 1 THEN
      -- 2026-09-27: FORCE pasa a ser "vivo" igual que EXCLUDE. Antes, con
      -- l_has_final=1 (caso normal: el esquema ya tiene clasificacion),
      -- un FORCE nuevo sobre una columna que seguia en enmascarar='N' en
      -- TDM_COLUMNA_FINAL NUNCA se recogia aqui -- la rama FORCE-only de
      -- abajo (ELSE) solo se activa cuando el esquema no tiene NINGUNA
      -- columna en Y, que tras el primer descubrimiento casi nunca ocurre.
      -- La UNION ALL de "objetivo" incorpora esas columnas FORCE igual que
      -- ya hace EXCLUDE (via NOT EXISTS, sin tocar TDM_COLUMNA_FINAL); si la
      -- misma columna esta en ambas fuentes, origen=1 (FORCE) gana sobre
      -- origen=2 (descubrimiento) para el identificador, igual que ya gana
      -- FORCE en proc_dm_aplica_excepcion (04) y en proc_dm_get_excepcion/
      -- proc_dm_apl_col (05, live en tiempo de aplicar).
      -- FIX 2026-09-28 (ORA-07445 [qctcopn_internal], incidente real en
      -- produccion -- ver incident/incdir_175305): el optimizador de Oracle
      -- 19.28 revienta con SIGSEGV al intentar transformar/mezclar este WITH
      -- (UNION ALL + funcion PL/SQL func_dm_norm() dentro de un EXISTS correlado)
      -- con la consulta externa. No es un bug de nuestra logica SQL -- el
      -- resultado es identico -- es un crash del compilador de consultas al
      -- reescribir el plan. /*+ MATERIALIZE */ obliga a materializar el CTE
      -- como un segmento real antes de evaluarlo, evitando la ruta de
      -- transformacion que provoca el volcado de memoria. No cambia el
      -- resultado, solo la estrategia de ejecucion.
      WITH objetivo AS (
        SELECT /*+ MATERIALIZE */ ora_owner, table_name, column_name,
               MAX(identificador) KEEP (DENSE_RANK FIRST ORDER BY origen) AS identificador
          FROM (
            SELECT f.ora_owner, f.table_name, f.column_name, f.identificador, 2 AS origen
              FROM tdm_columna_final f
             WHERE f.ora_owner = l_esquema
               AND f.enmascarar = 'Y'
            UNION ALL
            SELECT func_dm_norm(e.ora_owner), func_dm_norm(e.table_name), func_dm_norm(e.column_name), e.identificador_forz, 1 AS origen
              FROM tdm_excepcion_col e
             WHERE func_dm_norm(e.ora_owner) = l_esquema
               AND func_dm_norm(e.activa) = 'Y'
               AND func_dm_norm(e.accion) = 'FORCE'
               AND e.identificador_forz IS NOT NULL
               AND EXISTS (
                     SELECT 1 FROM dba_tab_columns c
                      WHERE c.owner = func_dm_norm(e.ora_owner)
                        AND c.table_name = func_dm_norm(e.table_name)
                        AND c.column_name = func_dm_norm(e.column_name)
                   )
          )
         GROUP BY ora_owner, table_name, column_name
      )
      SELECT COUNT(*), COUNT(DISTINCT table_name)
        INTO l_total_cols, l_total_tabs
        FROM objetivo f
       WHERE (
           l_reproceso = 'Y' OR
           NOT EXISTS (
             SELECT 1 FROM tdm_mask_trace t
              WHERE (
                      -- 2026-09-22: filtro simplificado a ejecucion_id (ya no a la
                      -- solicitud_id previa via g_resume_base_solicitud). Motivo: un
                      -- SEGUNDO reanudo consecutivo sobre la misma ejecucion_id (dos
                      -- caidas seguidas) solo veia el historico de la ULTIMA solicitud,
                      -- no el de la primera -- re-enmascaraba (doble cifrado, corrompe
                      -- FF1 y rompe el dominio referencial) columnas ya confirmadas en un
                      -- intento anterior al mas reciente. Con ejecucion_id se ve TODO el
                      -- historico de la ejecución sin importar cuantos intentos tuvo.
                      t.ejecucion_id = p_ejecucion_id
                    )
                AND t.fase = 'MASK'
                AND t.paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
                AND t.detalle LIKE f.ora_owner||'.'||f.table_name||'.'||f.column_name||' filas=%'
           )
         )
         AND NOT EXISTS (
           SELECT 1 FROM tdm_excepcion_col e
            WHERE func_dm_norm(e.ora_owner) = f.ora_owner
              AND e.table_name = f.table_name
              AND e.column_name = f.column_name
              AND func_dm_norm(e.activa) = 'Y'
              AND func_dm_norm(e.accion) = 'EXCLUDE'
         );
    ELSE
      SELECT COUNT(*), COUNT(DISTINCT table_name)
        INTO l_total_cols, l_total_tabs
        FROM tdm_excepcion_col e
       WHERE func_dm_norm(e.ora_owner) = l_esquema
         AND func_dm_norm(e.activa) = 'Y'
         AND func_dm_norm(e.accion) = 'FORCE'
         AND e.identificador_forz IS NOT NULL
         AND (
           l_reproceso = 'Y' OR
           NOT EXISTS (
             SELECT 1 FROM tdm_mask_trace t
              WHERE (
                      -- 2026-09-22: filtro simplificado a ejecucion_id (ya no a la
                      -- solicitud_id previa via g_resume_base_solicitud). Motivo: un
                      -- SEGUNDO reanudo consecutivo sobre la misma ejecucion_id (dos
                      -- caidas seguidas) solo veia el historico de la ULTIMA solicitud,
                      -- no el de la primera -- re-enmascaraba (doble cifrado, corrompe
                      -- FF1 y rompe el dominio referencial) columnas ya confirmadas en un
                      -- intento anterior al mas reciente. Con ejecucion_id se ve TODO el
                      -- historico de la ejecución sin importar cuantos intentos tuvo.
                      t.ejecucion_id = p_ejecucion_id
                    )
                AND t.fase = 'MASK'
                AND t.paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
                AND t.detalle LIKE func_dm_norm(e.ora_owner)||'.'||func_dm_norm(e.table_name)||'.'||func_dm_norm(e.column_name)||' filas=%'
           )
         )
         AND EXISTS (
           SELECT 1 FROM dba_tab_columns c
            WHERE c.owner = func_dm_norm(e.ora_owner)
              AND c.table_name = func_dm_norm(e.table_name)
              AND c.column_name = func_dm_norm(e.column_name)
         );
    END IF;

    -- Reanudacion visible: una linea en la traza (ligada a la NUEVA solicitud) y la marca en
    -- TDM_EJECUCION (ultimo_paso y detalle), con cuantas columnas se omiten y cuantas quedan.
    IF g_resume_base_solicitud IS NOT NULL THEN
      DECLARE
        l_reint NUMBER;
        l_conf  NUMBER;
        l_txt   VARCHAR2(400);
      BEGIN
        SELECT reintento_nro INTO l_reint FROM tdm_mask_solicitud WHERE solicitud_id = p_solicitud_id;
        SELECT COUNT(DISTINCT REGEXP_SUBSTR(t.detalle,'^[^ ]+'))
          INTO l_conf
          FROM tdm_mask_trace t
         WHERE t.ejecucion_id = p_ejecucion_id
           AND t.fase = 'MASK'
           AND t.paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK');
        l_txt := 'Reanudacion '||TO_CHAR(l_reint-1)||' (intento '||TO_CHAR(l_reint)||', solicitud_id='||
                 TO_CHAR(p_solicitud_id)||' desde solicitud_id='||TO_CHAR(g_resume_base_solicitud)||
                 '): columnas ya confirmadas='||TO_CHAR(l_conf)||', pendientes='||TO_CHAR(l_total_cols);
        proc_dm_trace(p_solicitud_id,p_ejecucion_id,'ENMASCARAMIENTO','REANUDACION',l_txt);
        proc_dm_upd_ejec(p_ejecucion_id,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'REANUDACION',l_txt);
      EXCEPTION
        WHEN OTHERS THEN NULL;   -- la marca es informativa: nunca debe frenar la reanudacion
      END;
    END IF;

    IF NVL(l_total_cols,0) = 0 THEN
      IF l_reproceso = 'Y' THEN
        l_msg_noop := 'No hay columnas configuradas/pendientes para enmascarar en reproceso completo.';
      ELSE
        l_msg_noop := 'No hay columnas pendientes por enmascarar para esta ejecución. '||
                      'Si deseas reproceso completo, ejecuta proc_dm_enmascaramiento('||TO_CHAR(p_ejecucion_id)||',''Y'').';
      END IF;

      proc_dm_trace(
        p_solicitud_id,
        p_ejecucion_id,
        'MASK',
        'NOOP',
        l_msg_noop
      );
      proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','FINALIZADO',100,0,0,0,0,NULL,'NOOP_MASK');
      RETURN;
    END IF;

    IF l_has_final = 1 THEN
      -- 2026-09-27: usa el mismo conjunto "objetivo" (descubrimiento + FORCE
      -- vivo) que la consulta de conteo de arriba, para que una tabla que solo
      -- tiene columnas por FORCE no se reporte aqui como omitida por error.
      FOR tskip IN (
        -- FIX 2026-09-28 (ORA-07445 [qctcopn_internal]): mismo workaround que
        -- en la consulta de conteo de arriba -- ver comentario ahi.
        WITH objetivo AS (
          SELECT /*+ MATERIALIZE */ ora_owner, table_name, column_name
            FROM (
              SELECT f.ora_owner, f.table_name, f.column_name
                FROM tdm_columna_final f
               WHERE f.ora_owner = l_esquema
                 AND f.enmascarar = 'Y'
              UNION ALL
              SELECT func_dm_norm(e.ora_owner), func_dm_norm(e.table_name), func_dm_norm(e.column_name)
                FROM tdm_excepcion_col e
               WHERE func_dm_norm(e.ora_owner) = l_esquema
                 AND func_dm_norm(e.activa) = 'Y'
                 AND func_dm_norm(e.accion) = 'FORCE'
                 AND e.identificador_forz IS NOT NULL
                 AND EXISTS (
                       SELECT 1 FROM dba_tab_columns c
                        WHERE c.owner = func_dm_norm(e.ora_owner)
                          AND c.table_name = func_dm_norm(e.table_name)
                          AND c.column_name = func_dm_norm(e.column_name)
                     )
            )
           GROUP BY ora_owner, table_name, column_name
        )
        SELECT ora_owner, table_name
          FROM objetivo f
         GROUP BY ora_owner, table_name
        HAVING COUNT(*) = SUM(
                 CASE WHEN EXISTS (
                   SELECT 1 FROM tdm_excepcion_col e
                    WHERE func_dm_norm(e.ora_owner) = f.ora_owner
                      AND e.table_name = f.table_name
                      AND e.column_name = f.column_name
                      AND func_dm_norm(e.activa) = 'Y'
                      AND func_dm_norm(e.accion) = 'EXCLUDE'
                 ) THEN 1 ELSE 0 END
               )
      ) LOOP
        proc_dm_trace(
          p_solicitud_id,
          p_ejecucion_id,
          'MASK',
          'SKIP_TABLE',
          tskip.ora_owner||'.'||tskip.table_name||' omitida: todas las columnas están EXCLUDE'
        );
      END LOOP;
    END IF;

    proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',0,l_total_tabs,0,l_total_cols,0,NULL,'INICIO_MASK');

    IF l_has_final = 1 THEN
      -- 2026-09-27: mismo "objetivo" (descubrimiento + FORCE vivo) que las
      -- dos consultas anteriores de esta rama; ver comentario en el conteo
      -- inicial. El cuerpo del LOOP (proc_dm_apl_col, progreso, etc.) no cambia.
      FOR rc IN (
        -- FIX 2026-09-28 (ORA-07445 [qctcopn_internal]): mismo workaround que
        -- en la consulta de conteo de arriba -- ver comentario ahi.
        WITH objetivo AS (
          SELECT /*+ MATERIALIZE */ ora_owner, table_name, column_name,
                 MAX(identificador) KEEP (DENSE_RANK FIRST ORDER BY origen) AS identificador
            FROM (
              SELECT f.ora_owner, f.table_name, f.column_name, f.identificador, 2 AS origen
                FROM tdm_columna_final f
               WHERE f.ora_owner = l_esquema
                 AND f.enmascarar = 'Y'
              UNION ALL
              SELECT func_dm_norm(e.ora_owner), func_dm_norm(e.table_name), func_dm_norm(e.column_name), e.identificador_forz, 1 AS origen
                FROM tdm_excepcion_col e
               WHERE func_dm_norm(e.ora_owner) = l_esquema
                 AND func_dm_norm(e.activa) = 'Y'
                 AND func_dm_norm(e.accion) = 'FORCE'
                 AND e.identificador_forz IS NOT NULL
                 AND EXISTS (
                       SELECT 1 FROM dba_tab_columns c
                        WHERE c.owner = func_dm_norm(e.ora_owner)
                          AND c.table_name = func_dm_norm(e.table_name)
                          AND c.column_name = func_dm_norm(e.column_name)
                     )
            )
           GROUP BY ora_owner, table_name, column_name
        )
        SELECT ora_owner, table_name, column_name, identificador
          FROM objetivo f
         WHERE (
             l_reproceso = 'Y' OR
             NOT EXISTS (
               SELECT 1 FROM tdm_mask_trace t
                WHERE (
                        -- 2026-09-22: ver comentario equivalente en la rama l_has_final=1
                        -- arriba -- mismo fix, misma razon (multi-reanudo consecutivo).
                        t.ejecucion_id = p_ejecucion_id
                      )
                  AND t.fase = 'MASK'
                  AND t.paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
                  AND t.detalle LIKE f.ora_owner||'.'||f.table_name||'.'||f.column_name||' filas=%'
             )
           )
           AND NOT EXISTS (
             SELECT 1 FROM tdm_excepcion_col e
              WHERE func_dm_norm(e.ora_owner) = f.ora_owner
                AND e.table_name = f.table_name
                AND e.column_name = f.column_name
                AND func_dm_norm(e.activa) = 'Y'
                AND func_dm_norm(e.accion) = 'EXCLUDE'
           )
         ORDER BY ora_owner, table_name, column_name
      ) LOOP
        proc_dm_chk_cancel(p_solicitud_id);

        IF l_last_tab IS NULL OR l_last_tab <> rc.table_name THEN
          l_last_tab := rc.table_name;
          l_proc_tabs := l_proc_tabs + 1;
        END IF;

        l_col_fallida := FALSE;
        BEGIN
          proc_dm_apl_col(p_solicitud_id,p_ejecucion_id,p_esquema,rc.ora_owner,rc.table_name,rc.column_name,rc.identificador);
        EXCEPTION
          WHEN OTHERS THEN
            l_col_fallida   := TRUE;
            l_cols_fallidas := l_cols_fallidas + 1;
            p_error_count := p_error_count + 1;
            -- El registro de error deja tambien la linea ERROR.REGISTRADO en la linea de tiempo.
            proc_dm_log_ejec_error(p_ejecucion_id, rc.ora_owner, rc.table_name, rc.column_name, 'MASK_APPLY', SQLCODE, SQLERRM, func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE), p_solicitud_id);
        END;

        -- FIX 2026-10-07 (Fase 1, incidente real ejecucion_id=1 DM_DUMMY: CUENTA_CCC
        -- fallo con ORA-20330 y aun asi se contaba como "procesada"): una columna
        -- cuyo proc_dm_apl_col lanzo excepcion NO esta enmascarada (o lo esta solo
        -- a medias). Antes, el contador l_proc_cols, el porcentaje, columnas_procesadas
        -- y ULTIMO_OBJETO avanzaban igual que en una columna exitosa -- el monitor
        -- mostraba progreso falso y ULTIMO_OBJETO apuntaba a una columna que seguia
        -- en claro. Ahora una columna fallida NO avanza el progreso: solo se
        -- refresca el latido y la ultima tabla/columna intentada; el error ya
        -- quedo en TDM_EJECUCION_ERROR y en TDM_MASK_TRACE (ERROR_COL), y
        -- p_error_count>0 garantiza estado final ERROR/CON_ERRORES (nunca FINALIZADO,
        -- sin purga de pepper ni export). No cambia que columnas se reintentan al
        -- reanudar: eso depende solo de los APPLY_COL en TDM_MASK_TRACE.
        IF l_col_fallida THEN
          BEGIN
            UPDATE tdm_mask_solicitud
               SET ultima_tabla   = rc.table_name,
                   ultima_columna = rc.column_name
             WHERE solicitud_id = p_solicitud_id;
            -- el latido de la corrida vive en TDM_EJECUCION (una columna fallida no pasa por proc_dm_upd_ejec)
            UPDATE tdm_ejecucion
               SET heartbeat_ts = SYSTIMESTAMP
             WHERE ejecucion_id = p_ejecucion_id
               AND estado = 'EJECUTANDO';
            COMMIT;
          EXCEPTION
            WHEN OTHERS THEN NULL;
          END;
          CONTINUE;
        END IF;

        l_proc_cols := l_proc_cols + 1;
        l_pct := CASE WHEN l_total_cols > 0 THEN ROUND((l_proc_cols*100)/l_total_cols,2) ELSE 0 END;

        proc_dm_upd_sol(p_solicitud_id,'EN_PROCESO','MASK',rc.table_name||'.'||rc.column_name,'Aplicando enmascaramiento');
        BEGIN
          UPDATE tdm_mask_solicitud
             SET tablas_procesadas   = l_proc_tabs,
                 columnas_procesadas = l_proc_cols,
                 ultima_tabla        = rc.table_name,
                 ultima_columna      = rc.column_name
           WHERE solicitud_id = p_solicitud_id;
          COMMIT;
        EXCEPTION
          WHEN OTHERS THEN NULL;
        END;
        proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',l_pct,l_total_tabs,l_proc_tabs,l_total_cols,l_proc_cols,
                         rc.ora_owner||'.'||rc.table_name||'.'||rc.column_name,'MASK');
      END LOOP;
    ELSE
      FOR rc IN (
        SELECT func_dm_norm(e.ora_owner) as ora_owner, func_dm_norm(e.table_name) as table_name,
               func_dm_norm(e.column_name) as column_name, e.identificador_forz as identificador
          FROM tdm_excepcion_col e
         WHERE func_dm_norm(e.ora_owner) = l_esquema
           AND func_dm_norm(e.activa) = 'Y'
           AND func_dm_norm(e.accion) = 'FORCE'
           AND e.identificador_forz IS NOT NULL
           AND (
             l_reproceso = 'Y' OR
             NOT EXISTS (
               SELECT 1 FROM tdm_mask_trace t
                WHERE (
                        -- 2026-09-22: ver comentario equivalente en la rama l_has_final=1
                        -- arriba -- mismo fix, misma razon (multi-reanudo consecutivo).
                        t.ejecucion_id = p_ejecucion_id
                      )
                  AND t.fase = 'MASK'
                  AND t.paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
                  AND t.detalle LIKE func_dm_norm(e.ora_owner)||'.'||func_dm_norm(e.table_name)||'.'||func_dm_norm(e.column_name)||' filas=%'
             )
           )
           AND EXISTS (
             SELECT 1 FROM dba_tab_columns c
              WHERE c.owner = func_dm_norm(e.ora_owner)
                AND c.table_name = func_dm_norm(e.table_name)
                AND c.column_name = func_dm_norm(e.column_name)
           )
         ORDER BY ora_owner, table_name, column_name
      ) LOOP
        proc_dm_chk_cancel(p_solicitud_id);

        IF l_last_tab IS NULL OR l_last_tab <> rc.table_name THEN
          l_last_tab := rc.table_name;
          l_proc_tabs := l_proc_tabs + 1;
        END IF;

        l_col_fallida := FALSE;
        BEGIN
          proc_dm_apl_col(p_solicitud_id,p_ejecucion_id,p_esquema,rc.ora_owner,rc.table_name,rc.column_name,rc.identificador);
        EXCEPTION
          WHEN OTHERS THEN
            l_col_fallida   := TRUE;
            l_cols_fallidas := l_cols_fallidas + 1;
            p_error_count := p_error_count + 1;
            -- El registro de error deja tambien la linea ERROR.REGISTRADO en la linea de tiempo.
            proc_dm_log_ejec_error(p_ejecucion_id, rc.ora_owner, rc.table_name, rc.column_name, 'MASK_APPLY', SQLCODE, SQLERRM, func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE), p_solicitud_id);
        END;

        -- FIX 2026-10-07 (Fase 1, incidente real ejecucion_id=1 DM_DUMMY: CUENTA_CCC
        -- fallo con ORA-20330 y aun asi se contaba como "procesada"): una columna
        -- cuyo proc_dm_apl_col lanzo excepcion NO esta enmascarada (o lo esta solo
        -- a medias). Antes, el contador l_proc_cols, el porcentaje, columnas_procesadas
        -- y ULTIMO_OBJETO avanzaban igual que en una columna exitosa -- el monitor
        -- mostraba progreso falso y ULTIMO_OBJETO apuntaba a una columna que seguia
        -- en claro. Ahora una columna fallida NO avanza el progreso: solo se
        -- refresca el latido y la ultima tabla/columna intentada; el error ya
        -- quedo en TDM_EJECUCION_ERROR y en TDM_MASK_TRACE (ERROR_COL), y
        -- p_error_count>0 garantiza estado final ERROR/CON_ERRORES (nunca FINALIZADO,
        -- sin purga de pepper ni export). No cambia que columnas se reintentan al
        -- reanudar: eso depende solo de los APPLY_COL en TDM_MASK_TRACE.
        IF l_col_fallida THEN
          BEGIN
            UPDATE tdm_mask_solicitud
               SET ultima_tabla   = rc.table_name,
                   ultima_columna = rc.column_name
             WHERE solicitud_id = p_solicitud_id;
            -- el latido de la corrida vive en TDM_EJECUCION (una columna fallida no pasa por proc_dm_upd_ejec)
            UPDATE tdm_ejecucion
               SET heartbeat_ts = SYSTIMESTAMP
             WHERE ejecucion_id = p_ejecucion_id
               AND estado = 'EJECUTANDO';
            COMMIT;
          EXCEPTION
            WHEN OTHERS THEN NULL;
          END;
          CONTINUE;
        END IF;

        l_proc_cols := l_proc_cols + 1;
        l_pct := CASE WHEN l_total_cols > 0 THEN ROUND((l_proc_cols*100)/l_total_cols,2) ELSE 0 END;

        proc_dm_upd_sol(p_solicitud_id,'EN_PROCESO','MASK',rc.table_name||'.'||rc.column_name,'Aplicando enmascaramiento');
        BEGIN
          UPDATE tdm_mask_solicitud
             SET tablas_procesadas   = l_proc_tabs,
                 columnas_procesadas = l_proc_cols,
                 ultima_tabla        = rc.table_name,
                 ultima_columna      = rc.column_name
           WHERE solicitud_id = p_solicitud_id;
          COMMIT;
        EXCEPTION
          WHEN OTHERS THEN NULL;
        END;
        proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',l_pct,l_total_tabs,l_proc_tabs,l_total_cols,l_proc_cols,
                         rc.ora_owner||'.'||rc.table_name||'.'||rc.column_name,'MASK');
      END LOOP;
    END IF;

    BEGIN
      SELECT NVL(SUM(TO_NUMBER(REGEXP_SUBSTR(t.detalle,'filas=([0-9]+)',1,1,NULL,1))),0)
        INTO l_total_rows
        FROM tdm_mask_trace t
       WHERE t.solicitud_id = p_solicitud_id
         AND t.fase = 'MASK'
         AND t.paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
         AND REGEXP_LIKE(t.detalle,'filas=[0-9]+');
    EXCEPTION
      WHEN OTHERS THEN
        l_total_rows := 0;
    END;

    proc_dm_trace(
      p_solicitud_id,
      p_ejecucion_id,
      'MASK',
      'RESUMEN',
      'Columnas procesadas='||TO_CHAR(l_proc_cols)||
      ', columnas fallidas='||TO_CHAR(l_cols_fallidas)||
      ', tablas procesadas='||TO_CHAR(l_proc_tabs)||
      ', total_registros_afectados='||TO_CHAR(NVL(l_total_rows,0))
    );

    BEGIN
      UPDATE tdm_mask_solicitud
         SET filas_procesadas     = NVL(l_total_rows,0),
             tablas_procesadas    = l_proc_tabs,
             columnas_procesadas  = l_proc_cols
       WHERE solicitud_id = p_solicitud_id;
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN NULL;
    END;
  END;

  ------------------------------------------------------------------------------
  -- Públicos del spec
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_enmascaramiento
  -- PROPOSITO    : Orquesta el enmascarado completo de un esquema: preflight de tareas huerfanas,
  --                desactivacion de dependencias, pepper, enmascarado de columnas, sincronizacion,
  --                rehabilitacion, recompilacion y cierre de estado.
  -- ENTRADAS     : p_ejecucion_id; p_reproceso (Y reprocesa todo); p_commit_lote (sin uso en el
  --                cuerpo).
  -- LEE          : TDM_EJECUCION; TDM_COLUMNA_FINAL; TDM_EXCEPCION_COL; TDM_MASK_TRACE;
  --                TDM_MASK_DEP_ESTADO; DBA_OBJECTS; DBA_CONSTRAINTS; USER_PARALLEL_EXECUTE_TASKS;
  --                USER_PARALLEL_EXECUTE_CHUNKS
  -- ESCRIBE      : TDM_EJECUCION (reclamo EJECUTANDO, estado final); TDM_MASK_SOLICITUD (alta y
  --                cierre); TDM_MASK_TRACE y TDM_EJECUCION_ERROR (via helpers); TDM_SECRETO (alta y
  --                autopurga del pepper); datos del esquema objetivo (via sub-rutinas); DDL: ALTER
  --                <tipo> ... COMPILE sobre objetos INVALID del esquema objetivo
  -- ERRORES      : ORA-20097 ya hay una ejecucion ENMASCARAMIENTO EJECUTANDO con ese id.; ORA-20098
  --                concurrencia sobre el mismo esquema.; ORA-20014 reingreso sin reproceso (via
  --                proc_dm_validar_reingreso_mask).; ORA-20331 preflight: tareas
  --                DBMS_PARALLEL_EXECUTE huerfanas bloquean el enmascarado.; Codigo -20203 se
  --                registra como error POST_CHECK (objetos nuevos INVALID o constraints no ENABLED),
  --                no se levanta.; Propaga ORA-20050..20056 y errores de pepper o propagacion de
  --                dominios, tras marcar solicitud y ejecucion en ERROR.
  -- LLAMADO DESDE: Externo/script: dm_enmascara.sql, dm_enmascara_id.sql; tambien proc_dm_reanudar
  --                (interno) y 99_install_datamasking.sql (referencia en comentario).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_enmascaramiento(
    p_ejecucion_id IN NUMBER,
    p_reproceso    IN VARCHAR2 DEFAULT 'N',
    p_commit_lote  IN NUMBER DEFAULT 1000
  ) IS
    l_solicitud_id NUMBER;
    l_esquema      VARCHAR2(128);
    l_err          VARCHAR2(1900 CHAR);
    l_err_code     NUMBER;
    l_err_stack    VARCHAR2(1900 CHAR);
    l_err_bt       VARCHAR2(1900 CHAR);
    l_err_call     VARCHAR2(1900 CHAR);
    l_reproceso    VARCHAR2(1) := UPPER(TRIM(NVL(p_reproceso,'N')));
    l_mask_errors  NUMBER := 0;
    l_invalidos_pre NUMBER := 0;
    l_invalidos_post NUMBER := 0;
    l_invalidos_nuevos NUMBER := 0;
    l_cons_mal       NUMBER := 0;
  BEGIN
    proc_dm_validar_base;
    DBMS_APPLICATION_INFO.SET_MODULE('PKG_DM_ENMASCARAR','P_DM_ENMASCARA');
    proc_dm_close_sol_open(p_ejecucion_id);
    proc_dm_refresca_sesion(p_ejecucion_id);

    -- forzar_full se normaliza por fase ENMASCARAMIENTO:
    --   - 'Y' sólo cuando el llamado actual solicita reproceso completo.
    --   - 'N' en el resto de casos, evitando arrastre de forzado desde DESCUBRIMIENTO.
    BEGIN
      UPDATE tdm_ejecucion
         SET forzar_full = CASE WHEN l_reproceso = 'Y' THEN 'Y' ELSE 'N' END,
             cancel_requested = 'N',
             heartbeat_ts = SYSTIMESTAMP
       WHERE ejecucion_id = p_ejecucion_id;
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;

    l_esquema := func_dm_esquema(p_ejecucion_id);

    -- B.3: Capturar conteo baseline de objetos inválidos del esquema
    BEGIN
      SELECT COUNT(*)
        INTO l_invalidos_pre
        FROM dba_objects
       WHERE owner = l_esquema
         AND status = 'INVALID';
    EXCEPTION
      WHEN OTHERS THEN
        l_invalidos_pre := 0;
    END;
    proc_dm_validar_reingreso_mask(p_ejecucion_id,l_esquema,l_reproceso);
    proc_dm_validar_concurrencia(p_ejecucion_id,l_esquema);

    -- Reclamo de ejecución para evitar doble arranque en paralelo
    -- sobre el mismo ejecucion_id.
    BEGIN
       -- Reclamo de ejecución para evitar doble arranque en paralelo
       -- sobre el mismo ejecucion_id y sobre el mismo esquema.
       UPDATE tdm_ejecucion
          SET fase_proceso = 'ENMASCARAMIENTO',
              estado       = 'EJECUTANDO',
              fecha_inicio = SYSTIMESTAMP,
              fecha_fin    = NULL,
              ultimo_objeto = l_esquema,
              ultimo_paso   = 'INICIO',
              heartbeat_ts = SYSTIMESTAMP
        WHERE ejecucion_id = p_ejecucion_id
          AND NOT (
            UPPER(TRIM(NVL(fase_proceso,'?'))) = 'ENMASCARAMIENTO' AND
            UPPER(TRIM(NVL(estado,'?'))) = 'EJECUTANDO'
          );
     EXCEPTION
       WHEN DUP_VAL_ON_INDEX THEN
         RAISE_APPLICATION_ERROR(
           -20098,
           'ERROR CONCURRENCIA: Ya existe otra ejecución en estado EJECUTANDO para el esquema '||l_esquema||
           '. No se permite la ejecución concurrente sobre el mismo esquema.'
         );
     END;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(
        -20097,
        'Ya existe una ejecución ENMASCARAMIENTO en estado EJECUTANDO para ejecucion_id='||p_ejecucion_id||
        '. No se permite ejecución paralela.'
      );
    END IF;
    COMMIT;

    -- 2026-09-22: p_detalle ahora distingue una solicitud de REANUDACION (via
    -- proc_dm_reanudar, g_resume_base_solicitud no nulo) de una de arranque
    -- normal -- antes usaba el mismo texto fijo ('Enmascaramiento final;
    -- rollback via import', residuo sin relacion aparente con este flujo)
    -- para ambos casos, asi que TDM_MASK_SOLICITUD.DETALLE tampoco distinguia
    -- una reanudacion de un arranque normal (solo reintento_nro>1 lo insinuaba).
    l_solicitud_id := func_dm_crea_sol(
      p_ejecucion_id      => p_ejecucion_id,
      p_esquema           => l_esquema,
      p_detalle           => CASE
                                WHEN g_resume_base_solicitud IS NOT NULL THEN
                                  'Reanudacion de ejecucion_id='||p_ejecucion_id||
                                  ' desde solicitud_id='||TO_CHAR(g_resume_base_solicitud)
                                ELSE
                                  'Enmascaramiento final'
                              END,
      p_forzar_reproceso  => l_reproceso
    );
    -- Sesion Oracle y cancelacion de la corrida viven solo en TDM_EJECUCION
    -- (proc_dm_refresca_sesion y el reset de cancel_requested al arrancar).

    proc_dm_trace(l_solicitud_id,p_ejecucion_id,'ENMASCARAMIENTO','INICIO',
      'Esquema='||l_esquema||
      CASE WHEN g_resume_base_solicitud IS NOT NULL
           THEN ' - REANUDACION desde solicitud_id='||TO_CHAR(g_resume_base_solicitud) END);
    -- TDM_EJECUCION debe decir desde el primer segundo si esta corrida es una reanudacion
    -- (antes de pre-flight, dependencias y pepper, que pueden tardar). El detalle se reescribe
    -- siempre al arrancar, para que un texto de una reanudacion anterior no quede como si fuera
    -- el modo actual. proc_dm_mask_cat lo completa con las columnas confirmadas y pendientes.
    proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',0,NULL,NULL,NULL,NULL,l_esquema,
      CASE WHEN g_resume_base_solicitud IS NOT NULL THEN 'REANUDACION' ELSE 'INICIO' END,
      CASE WHEN g_resume_base_solicitud IS NOT NULL
           THEN 'Reanudacion en curso (solicitud_id='||TO_CHAR(l_solicitud_id)||' desde solicitud_id='||
                TO_CHAR(g_resume_base_solicitud)||'): calculando columnas pendientes'
           ELSE 'Enmascaramiento en curso (solicitud_id='||TO_CHAR(l_solicitud_id)||')'
      END);

    -- FIX 2026-10-07 (Fase 1, PRE-FLIGHT de tareas DBMS_PARALLEL_EXECUTE huerfanas).
    -- Incidente real (DM_DUMMY, ejecucion_id=1): una tarea TDM_<hash> quedo viva
    -- en USER_PARALLEL_EXECUTE_TASKS (reliquia de una corrida anterior, o de la
    -- propia corrida cuya sesion orquestadora fue matada: los workers de
    -- DBMS_SCHEDULER siguen procesando chunks y la tarea termina FINISHED sin
    -- DROP_TASK). El motor solo se enteraba al llegar a esa columna
    -- (ORA-20330 en proc_dm_ejecuta_update_seguro), con el resto del esquema ya
    -- enmascarado y el run contaminado. Aqui se detecta ANTES de tocar ningun
    -- dato (antes de proc_dm_pre_dep y del pepper): si alguna tarea
    -- TDM_<hash> del esquema que ejecuta el motor corresponde a una columna que
    -- ESTE run enmascararia, se aborta cerrado con un mensaje accionable.
    --
    -- Solo DIAGNOSTICA y se detiene: NO reanuda, NO borra, NO hace RESUME_TASK
    -- ni SET_CHUNK_STATUS -- decidir si una tarea con chunks PROCESSED se
    -- reconcilia o se descarta exige evidencia (doble cifrado FF1 = perdida de
    -- reversibilidad e integridad FK). La reconciliacion automatica queda para
    -- una fase posterior, tras validar con pruebas de kill (E-01/E-02).
    --
    -- Correlacion tarea->columna: el task_name es DETERMINISTICO (hash de
    -- OWNER.TABLA.COLUMNA, ver proc_dm_ejecuta_update_seguro). Se construye en
    -- memoria el mapa hash->columna con DOS consultas simples (columnas Y de
    -- TDM_COLUMNA_FINAL y FORCE vivos de TDM_EXCEPCION_COL; sin CTE/UNION/EXISTS
    -- correlado para no rozar el ORA-07445 [qctcopn_internal] ya visto en
    -- proc_dm_mask_cat) y se recorre USER_PARALLEL_EXECUTE_TASKS. Quedan fuera,
    -- y solo se informan: tareas sin columna objetivo (nombres antiguos tipo
    -- GUID, columnas ya fuera de alcance), columnas con EXCLUDE vivo y columnas
    -- ya confirmadas (APPLY_COL) en ESTA ejecucion cuando no es reproceso
    -- completo -- este run no las toca, asi que no pueden contaminarlo.
    DECLARE
      TYPE t_mapa_cols IS TABLE OF VARCHAR2(300) INDEX BY VARCHAR2(60);
      l_mapa     t_mapa_cols;
      l_col      VARCHAR2(300);
      l_n_excl   NUMBER;
      l_n_hecha  NUMBER;
      l_c_total  NUMBER;
      l_c_unass  NUMBER;
      l_c_asg    NUMBER;
      l_c_proc   NUMBER;
      l_c_err    NUMBER;
      l_n_bloq   PLS_INTEGER := 0;
      l_n_info   PLS_INTEGER := 0;
      l_n_omit   PLS_INTEGER := 0;
      l_lineas   VARCHAR2(1000);
      l_linea    VARCHAR2(600);
      l_obj_chunk NUMBER;
      l_obj_tab   NUMBER;
      l_obsoleta  BOOLEAN;
    BEGIN
      FOR f IN (
        SELECT table_name, column_name
          FROM tdm_columna_final
         WHERE ora_owner = l_esquema
           AND enmascarar = 'Y'
      ) LOOP
        l_mapa('TDM_'||TO_CHAR(DBMS_UTILITY.GET_HASH_VALUE(
                 UPPER(l_esquema)||'.'||UPPER(f.table_name)||'.'||UPPER(f.column_name),
                 1, 1000000000))) := f.table_name||'.'||f.column_name;
      END LOOP;

      FOR fx IN (
        SELECT func_dm_norm(e.table_name)  AS table_name,
               func_dm_norm(e.column_name) AS column_name
          FROM tdm_excepcion_col e
         WHERE func_dm_norm(e.ora_owner) = l_esquema
           AND func_dm_norm(e.activa)  = 'Y'
           AND func_dm_norm(e.accion)  = 'FORCE'
           AND e.identificador_forz IS NOT NULL
      ) LOOP
        l_mapa('TDM_'||TO_CHAR(DBMS_UTILITY.GET_HASH_VALUE(
                 UPPER(l_esquema)||'.'||UPPER(fx.table_name)||'.'||UPPER(fx.column_name),
                 1, 1000000000))) := fx.table_name||'.'||fx.column_name;
      END LOOP;

      FOR t IN (
        SELECT task_name, status
          FROM user_parallel_execute_tasks
         WHERE task_name LIKE 'TDM\_%' ESCAPE '\'
         ORDER BY task_name
      ) LOOP
        IF NOT l_mapa.EXISTS(t.task_name) THEN
          l_n_info := l_n_info + 1;
          proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PREFLIGHT_INFO',
            'Tarea '||t.task_name||' (estado='||t.status||') no corresponde a ninguna columna objetivo de '||
            l_esquema||' (nombre antiguo o columna fuera de alcance): NO bloquea este run.');
        ELSE
          l_col := l_mapa(t.task_name);

          SELECT COUNT(*) INTO l_n_excl
            FROM tdm_excepcion_col e
           WHERE func_dm_norm(e.ora_owner) = l_esquema
             AND func_dm_norm(e.table_name)||'.'||func_dm_norm(e.column_name) = l_col
             AND func_dm_norm(e.activa) = 'Y'
             AND func_dm_norm(e.accion) = 'EXCLUDE';

          l_n_hecha := 0;
          IF l_reproceso <> 'Y' THEN
            SELECT COUNT(*) INTO l_n_hecha
              FROM tdm_mask_trace tr
             WHERE tr.ejecucion_id = p_ejecucion_id
               AND tr.fase = 'MASK'
               AND tr.paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
               AND tr.detalle LIKE l_esquema||'.'||l_col||' filas=%';
          END IF;

          IF l_n_excl > 0 OR l_n_hecha > 0 THEN
            l_n_omit := l_n_omit + 1;
            proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PREFLIGHT_INFO',
              'Tarea '||t.task_name||' ('||l_col||', estado='||t.status||') existe pero este run no toca esa columna ('||
              CASE WHEN l_n_excl > 0 THEN 'EXCLUDE vivo' ELSE 'ya confirmada en esta ejecucion' END||
              '): NO bloquea. Conviene limpiarla a mano mas tarde.');
          ELSE
            SELECT COUNT(*),
                   NVL(SUM(CASE WHEN status = 'UNASSIGNED'           THEN 1 ELSE 0 END),0),
                   NVL(SUM(CASE WHEN status = 'ASSIGNED'             THEN 1 ELSE 0 END),0),
                   NVL(SUM(CASE WHEN status = 'PROCESSED'            THEN 1 ELSE 0 END),0),
                   NVL(SUM(CASE WHEN status = 'PROCESSED_WITH_ERROR' THEN 1 ELSE 0 END),0)
              INTO l_c_total, l_c_unass, l_c_asg, l_c_proc, l_c_err
              FROM user_parallel_execute_chunks
             WHERE task_name = t.task_name;

            -- FIX 2026-10-07 (recarga de DM_DUMMY + reinstalacion del motor): las tareas
            -- DBMS_PARALLEL_EXECUTE viven en el diccionario del dueño del motor, no en
            -- sus tablas, asi que sobreviven a reinstalar el motor y a recargar el
            -- esquema objetivo. Su nombre es deterministico, por lo que una tarea de la
            -- version ANTERIOR de la tabla bloqueaba el run con "YA HAY FILAS CIFRADAS"
            -- aunque sus chunks describan una tabla que ya no existe. El rowid de cada
            -- chunk lleva el data_object_id de la tabla: si no coincide con el actual,
            -- la tabla fue recreada/recargada/truncada/movida. Solo se CLASIFICA (sigue
            -- bloqueando, porque CREATE_TASK chocaria igual y un MOVE no prueba que los
            -- datos esten sin cifrar): el DBA decide con el dato correcto delante.
            l_obsoleta := FALSE;
            BEGIN
              SELECT DBMS_ROWID.ROWID_OBJECT(start_rowid)
                INTO l_obj_chunk
                FROM user_parallel_execute_chunks
               WHERE task_name = t.task_name
                 AND ROWNUM = 1;
              SELECT o.data_object_id
                INTO l_obj_tab
                FROM dba_objects o
               WHERE o.owner       = l_esquema
                 AND o.object_name = SUBSTR(l_col, 1, INSTR(l_col, '.') - 1)
                 AND o.object_type = 'TABLE';
              l_obsoleta := (l_obj_chunk IS NOT NULL AND l_obj_tab IS NOT NULL
                             AND l_obj_chunk <> l_obj_tab);
            EXCEPTION
              WHEN OTHERS THEN l_obsoleta := FALSE;
            END;

            l_n_bloq := l_n_bloq + 1;
            l_linea := t.task_name||' ('||l_col||') estado='||t.status||
                       ' chunks: total='||l_c_total||' PROCESSED='||l_c_proc||
                       ' ASSIGNED='||l_c_asg||' UNASSIGNED='||l_c_unass||
                       ' CON_ERROR='||l_c_err||
                       CASE
                         WHEN l_obsoleta THEN
                           ' -> OBSOLETA: sus chunks apuntan a OTRA version de la tabla (recreada, recargada, truncada o movida) y no describen los datos actuales; si la tabla se recargo desde cero se puede descartar con ADM_DROP_TASK'
                         WHEN l_c_proc > 0 THEN ' -> YA HAY FILAS CIFRADAS con FF1'
                         ELSE ''
                       END;
            proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PREFLIGHT_ORFANA', l_linea);

            IF LENGTH(l_lineas) IS NULL OR LENGTH(l_lineas) + LENGTH(l_linea) + 4 <= 800 THEN
              l_lineas := l_lineas||CHR(10)||'  - '||l_linea;
            END IF;
          END IF;
        END IF;
      END LOOP;

      IF l_n_bloq > 0 THEN
        proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PREFLIGHT_ABORT',
          l_n_bloq||' tarea(s) huerfana(s) bloquean el enmascarado (informativas aparte: '||
          (l_n_info + l_n_omit)||'). No se ha tocado ningun dato.');
        RAISE_APPLICATION_ERROR(-20331,
          'PRE-FLIGHT: '||l_n_bloq||' tarea(s) DBMS_PARALLEL_EXECUTE huerfana(s) de columnas a enmascarar '||
          '(ejecucion_id='||p_ejecucion_id||', esquema '||l_esquema||'). NO se ha tocado ningun dato.'||
          l_lineas||CHR(10)||
          'Si alguna tiene chunks PROCESSED, esa columna YA esta (total o parcialmente) cifrada con FF1: '||
          'NO borre la tarea ni relance esa columna sin decidir (doble cifrado = perdida de reversibilidad y '||
          'ruptura FK). Si todos sus chunks estan UNASSIGNED/sin PROCESSED, no hay datos cifrados y se puede '||
          'descartar. Detalle completo: TDM_MASK_TRACE paso PREFLIGHT_ORFANA; diagnostico: @dm_monitor '||
          p_ejecucion_id||'. Para continuar sin reprocesar use @dm_enmascara_reanudar '||p_ejecucion_id||
          ' (reconcilia las tareas interrumpidas); para abandonar, @dm_enmascara_cancel '||p_ejecucion_id||
          ' CONFIRMAR DESCARTAR.');
      END IF;

      proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PREFLIGHT_OK',
        'Sin tareas huerfanas que bloqueen (informativas: '||(l_n_info + l_n_omit)||').');
    END;

    proc_dm_pre_dep(l_solicitud_id,p_ejecucion_id,l_esquema);

    -- A.1: Re-propagar dominios referenciales con la validación final del cliente antes de enmascarar
    --
    -- Fail-open corregido (auditoria 2026-09-16): este bloque solo trazaba el
    -- error y dejaba que el flujo siguiera hacia pepper y masking aunque la
    -- propagacion de dominios FK hubiera fallado por completo. La garantia
    -- de integridad referencial es tan  como el pepper (que si hace
    -- RAISE unas lineas mas abajo) - un fallo aqui debe abortar la ejecución,
    -- no continuar en silencio con dominios FK potencialmente inconsistentes.
    BEGIN
      proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_START', 'Recalculando dominios FK con la validacion del cliente');
      pkg_dm_descubrimiento.proc_dm_propaga_dominios(l_esquema, l_solicitud_id, p_ejecucion_id);
      proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_END', 'Dominios FK propagados con exito');
    EXCEPTION
      WHEN OTHERS THEN
        proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_ERR', 'Error en propagacion referencial: '||SQLERRM);
        RAISE;   -- sin propagacion valida no se puede garantizar la integridad FK
    END;

    -- Generar la semilla efimera (pepper) ANTES de enmascarar. Idempotente y con
    -- COMMIT propio para que las sesiones paralelas lean la misma clave AES (FF1).
    BEGIN
      proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PEPPER_START', 'Preparando semilla efimera.');
      proc_dm_pepper_generar(p_ejecucion_id);
      proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PEPPER_END', 'Semilla efimera lista.');
    EXCEPTION
      WHEN OTHERS THEN
        proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PEPPER_ERR', 'Error preparando semilla: '||SQLERRM);
        RAISE;   -- sin pepper no se puede enmascarar de forma segura
    END;

    BEGIN
      proc_dm_mask_cat(l_solicitud_id,p_ejecucion_id,l_esquema,l_reproceso,l_mask_errors);
    EXCEPTION
      WHEN OTHERS THEN
        l_mask_errors := l_mask_errors + 1;
        proc_dm_log_ejec_error(p_ejecucion_id, l_esquema, NULL, NULL, 'MASK_CAT', SQLCODE, SQLERRM, NULL, l_solicitud_id);
    END;

    BEGIN
      proc_dm_post_sync(l_solicitud_id,p_ejecucion_id,l_esquema);
    EXCEPTION
      WHEN OTHERS THEN
        l_mask_errors := l_mask_errors + 1;
        proc_dm_log_ejec_error(p_ejecucion_id, l_esquema, NULL, NULL, 'POST_SYNC', SQLCODE, SQLERRM, NULL, l_solicitud_id);
    END;

    proc_dm_post_dep(l_solicitud_id,p_ejecucion_id);

    -- B.3: Control de dependencias no rehabilitadas e invalidación de objetos (con baseline)
    BEGIN
      SELECT COUNT(*)
        INTO l_cons_mal
        FROM tdm_mask_dep_estado d
        JOIN dba_constraints c
          ON c.owner = d.ora_owner AND c.constraint_name = d.objeto_name
       WHERE d.solicitud_id = l_solicitud_id
         AND d.tipo_objeto  = 'CONSTRAINT'
         AND d.estado_previo = 'ENABLED'
         AND c.status <> 'ENABLED';
    EXCEPTION
      WHEN OTHERS THEN
        l_cons_mal := 0;
        proc_dm_log_ejec_error(
          p_ejecucion_id => p_ejecucion_id,
          p_solicitud_id => l_solicitud_id,
          p_owner_name   => l_esquema,
          p_table_name   => NULL,
          p_column_name  => NULL,
          p_etapa        => 'POST_CHECK_CONSTRAINTS',
          p_codigo_error => SQLCODE,
          p_mensaje      => 'Error consultando constraints no rehabilitadas: '||SQLERRM,
          p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
    END;

    -- Recompilar esquema de manera silenciosa para restaurar estado de objetos dependientes
    DECLARE
      l_invalid_count NUMBER := 9999;
      l_prev_invalid_count NUMBER := 9999;
      l_sql_recomp VARCHAR2(1000);
    BEGIN
      LOOP
        SELECT COUNT(*) INTO l_invalid_count
          FROM dba_objects
         WHERE owner = l_esquema
           AND status = 'INVALID';
           
        EXIT WHEN l_invalid_count = 0 OR l_invalid_count = l_prev_invalid_count;
        l_prev_invalid_count := l_invalid_count;
        
        FOR r IN (
          SELECT object_type, object_name
            FROM dba_objects
           WHERE owner = l_esquema
             AND status = 'INVALID'
           ORDER BY CASE object_type
                      WHEN 'PACKAGE' THEN 1
                      WHEN 'TYPE' THEN 2
                      WHEN 'VIEW' THEN 3
                      WHEN 'PACKAGE BODY' THEN 4
                      WHEN 'PROCEDURE' THEN 5
                      WHEN 'FUNCTION' THEN 6
                      WHEN 'TRIGGER' THEN 7
                      ELSE 8
                    END, object_name
        ) LOOP
          BEGIN
            IF r.object_type = 'PACKAGE BODY' THEN
              l_sql_recomp := 'ALTER PACKAGE "'||l_esquema||'"."'||r.object_name||'" COMPILE BODY';
            ELSIF r.object_type = 'TYPE BODY' THEN
              l_sql_recomp := 'ALTER TYPE "'||l_esquema||'"."'||r.object_name||'" COMPILE BODY';
            ELSE
              l_sql_recomp := 'ALTER '||r.object_type||' "'||l_esquema||'"."'||r.object_name||'" COMPILE';
            END IF;
            EXECUTE IMMEDIATE l_sql_recomp;
          EXCEPTION
            WHEN OTHERS THEN
              NULL;
          END;
        END LOOP;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;

    BEGIN
      SELECT COUNT(*)
        INTO l_invalidos_post
        FROM dba_objects
       WHERE owner = l_esquema
         AND status = 'INVALID';
      l_invalidos_nuevos := GREATEST(l_invalidos_post - l_invalidos_pre, 0);
    EXCEPTION
      WHEN OTHERS THEN
        l_invalidos_nuevos := 0;
        proc_dm_log_ejec_error(
          p_ejecucion_id => p_ejecucion_id,
          p_solicitud_id => l_solicitud_id,
          p_owner_name   => l_esquema,
          p_table_name   => NULL,
          p_column_name  => NULL,
          p_etapa        => 'POST_CHECK_INVALIDOS',
          p_codigo_error => SQLCODE,
          p_mensaje      => 'Error consultando delta de objetos invalidos: '||SQLERRM,
          p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
    END;

    IF l_invalidos_nuevos > 0 OR l_cons_mal > 0 THEN
      l_mask_errors := l_mask_errors + l_invalidos_nuevos + l_cons_mal;
      proc_dm_trace(
        l_solicitud_id,
        p_ejecucion_id,
        'POST',
        'POST_CHECK_INVALID',
        'Nuevos objetos INVALID='||l_invalidos_nuevos||' (pre='||l_invalidos_pre||', post='||l_invalidos_post||') ; constraints no ENABLED='||l_cons_mal
      );
      proc_dm_log_ejec_error(
        p_ejecucion_id => p_ejecucion_id,
        p_solicitud_id => l_solicitud_id,
        p_owner_name   => l_esquema,
        p_table_name   => NULL,
        p_column_name  => NULL,
        p_etapa        => 'POST_CHECK',
        p_codigo_error => -20203,
        p_mensaje      => 'Invalidez tras rehabilitar: nuevos INVALID='||l_invalidos_nuevos||' cons_no_enabled='||l_cons_mal,
        p_backtrace    => NULL
      );
    END IF;

    -- A-06 (fallo cerrado): una columna sensible auto-excluida por colision es PII
    -- SIN enmascarar. Se cuenta como error para IMPEDIR FINALIZADO y, por dependencia
    -- (pkg_dm_export.proc_dm_export_mask exige estado FINALIZADO), tambien el export.
    DECLARE
      l_pii_sin_masc NUMBER;
    BEGIN
      SELECT COUNT(*) INTO l_pii_sin_masc
        FROM tdm_mask_trace
       WHERE solicitud_id = l_solicitud_id
         AND paso = 'SKIP_ORA00001';
      IF NVL(l_pii_sin_masc,0) > 0 THEN
        l_mask_errors := NVL(l_mask_errors,0) + l_pii_sin_masc;
        proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','PII_SIN_ENMASCARAR',
          l_pii_sin_masc||' columna(s) sensible(s) auto-excluida(s) por colision (ORA-00001): '||
          'NO se permite FINALIZADO ni export. Reclasificar a identificador biyectivo y reprocesar.');
      END IF;
    END;

    IF l_mask_errors > 0 THEN
      proc_dm_upd_sol(l_solicitud_id,'ERROR','FIN','ERROR','Proceso finalizado con '||l_mask_errors||' errores','Y');
      proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','ERROR',100,NULL,NULL,NULL,NULL,NULL,'CON_ERRORES');
      proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','ERROR','Enmascaramiento finalizado con '||l_mask_errors||' errores');
    ELSE
      proc_dm_upd_sol(l_solicitud_id,'FINALIZADO','FIN','FINALIZADO','Proceso finalizado correctamente','Y');
      proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','FINALIZADO',100,NULL,NULL,NULL,NULL,NULL,'FINALIZADO');
      proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','OK','Enmascaramiento finalizado');

      -- 2026-09-27: autopurga del pepper efimero SOLO en FINALIZADO sin
      -- errores. Ni la validacion (paso 5 del runbook) ni el export (paso 6,
      -- pkg_dm_export/07, adicional y fuera del flujo critico) leen el
      -- pepper, asi que no hay razon para conservarlo mas alla de este punto
      -- -- ver guarda de estado en proc_dm_pepper_purgar. Best-effort: si la
      -- purga falla no debe tumbar un enmascarado ya finalizado con exito.
      BEGIN
        proc_dm_pepper_purgar(p_ejecucion_id);
      EXCEPTION
        WHEN OTHERS THEN
          proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','PEPPER_PURGE_WARN',
            'Enmascaramiento FINALIZADO pero no se pudo autopurgar el pepper: '||SQLERRM||
            ' -- purgar manualmente con proc_dm_pepper_purgar('||p_ejecucion_id||').');
      END;
    END IF;

    DBMS_APPLICATION_INFO.SET_MODULE(NULL,NULL);
  EXCEPTION
    WHEN OTHERS THEN
      l_err_code := SQLCODE;
      l_err_stack := func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_STACK);
      l_err_bt    := func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      l_err_call  := func_dm_safe_err(DBMS_UTILITY.FORMAT_CALL_STACK);
      l_err := '['||TO_CHAR(l_err_code)||'] '||l_err_stack||' | BT='||l_err_bt;
      BEGIN
        IF l_solicitud_id IS NOT NULL THEN
          proc_dm_post_dep(l_solicitud_id,p_ejecucion_id);
          proc_dm_upd_sol(l_solicitud_id,
                          CASE WHEN l_err_code = -20081 THEN 'CANCELADO' ELSE 'ERROR' END,
                          'ERROR','ERROR',l_err,'Y');
        END IF;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;

      proc_dm_log_ejec_error(
        p_ejecucion_id => p_ejecucion_id,
        p_owner_name   => l_esquema,
        p_table_name   => NULL,
        p_column_name  => NULL,
        p_etapa        => 'ENMASCARAMIENTO/P_DM_ENMASCARA',
        p_codigo_error => l_err_code,
        p_mensaje      => l_err_stack,
        p_backtrace    => l_err_bt||' | CALL='||l_err_call,
        p_solicitud_id => l_solicitud_id
      );

      proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO',CASE WHEN l_err_code = -20081 THEN 'CANCELADO' ELSE 'ERROR' END,
                       NULL,NULL,NULL,NULL,NULL,NULL,'ERROR');
      BEGIN
        UPDATE tdm_mask_solicitud
           SET filas_error = NVL(filas_error,0) + 1
         WHERE solicitud_id = l_solicitud_id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;
      DBMS_APPLICATION_INFO.SET_MODULE(NULL,NULL);
      RAISE;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_cancelar
  -- PROPOSITO    : Solicita la cancelacion cooperativa de una ejecucion en curso marcando
  --                cancel_requested y avisando al operador del resultado.
  -- ENTRADAS     : p_ejecucion_id.
  -- LEE          : TDM_MASK_SOLICITUD
  -- ESCRIBE      : TDM_EJECUCION (cancel_requested = Y); TDM_MASK_SOLICITUD (detalle); COMMIT;
  --                DBMS_OUTPUT
  -- ERRORES      : No levanta errores; informa por DBMS_OUTPUT si no habia solicitud abierta que
  --                cancelar.
  -- LLAMADO DESDE: Externo/script: dm_enmascara_cancel.sql (y guion de uso
  --                00_guion_uso_datamasking.sql).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_cancelar(p_ejecucion_id IN NUMBER) IS
    l_n NUMBER;
  BEGIN
    -- La solicitud de cancelacion vive en TDM_EJECUCION; solo aplica si la corrida
    -- tiene un intento (solicitud) abierto.
    UPDATE tdm_ejecucion e
       SET e.cancel_requested = 'Y'
     WHERE e.ejecucion_id = p_ejecucion_id
       AND EXISTS (SELECT 1 FROM tdm_mask_solicitud s
                    WHERE s.ejecucion_id = e.ejecucion_id
                      AND s.estado IN ('EN_PROCESO','PENDIENTE','REANUDANDO'));
    l_n := SQL%ROWCOUNT;

    UPDATE tdm_mask_solicitud
       SET detalle = SUBSTR(NVL(detalle,'')||' | Cancelacion solicitada manualmente',1,3900)
     WHERE ejecucion_id = p_ejecucion_id
       AND estado IN ('EN_PROCESO','PENDIENTE','REANUDANDO');
    COMMIT;

    -- 2026-10-04 FIX CRITICO (incidente real ejecucion_id=5): antes de este
    -- fix esta llamada no daba NINGUNA señal al operador de si realmente
    -- cancelo algo -- un EXEC directo (este procedimiento no tiene script
    -- envoltorio propio, se invoca ad-hoc) mostraba siempre el mismo
    -- "Procedimiento PL/SQL terminado correctamente" tanto si afecto 1 fila
    -- como si no afecto ninguna (ejecucion_id inexistente, ya FINALIZADO, ya
    -- en ERROR/CANCELADO, etc.). Se imprime aqui el resultado real via
    -- DBMS_OUTPUT. El cancel sigue siendo COOPERATIVO por diseno (ver
    -- proc_dm_chk_cancel): la sesion activa solo lo detecta entre columna y
    -- columna, asi que para una columna muy grande via DBMS_PARALLEL_EXECUTE
    -- puede tardar varios minutos en detenerse -- se avisa de esto tambien,
    -- en vez de dejar al operador asumiendo que "no paso nada".
    IF l_n > 0 THEN
      DBMS_OUTPUT.PUT_LINE('Cancelacion solicitada para ejecucion_id='||p_ejecucion_id||
                           ' (TDM_EJECUCION.cancel_requested=Y).');
      DBMS_OUTPUT.PUT_LINE('El motor es COOPERATIVO: la sesion activa solo lo detecta entre columna y');
      DBMS_OUTPUT.PUT_LINE('columna (proc_dm_chk_cancel) -- si esta a mitad de una columna grande via');
      DBMS_OUTPUT.PUT_LINE('DBMS_PARALLEL_EXECUTE, puede tardar varios minutos en detenerse de verdad.');
      DBMS_OUTPUT.PUT_LINE('Verifique con: SELECT estado FROM tdm_mask_solicitud WHERE ejecucion_id='||p_ejecucion_id||' ORDER BY solicitud_id DESC;');
    ELSE
      DBMS_OUTPUT.PUT_LINE('NO se solicito cancelacion: ejecucion_id='||p_ejecucion_id||' no tiene ninguna');
      DBMS_OUTPUT.PUT_LINE('solicitud en estado EN_PROCESO/PENDIENTE/REANUDANDO ahora mismo (ya finalizo, ya');
      DBMS_OUTPUT.PUT_LINE('esta en ERROR/CANCELADO, o el ejecucion_id no existe). Nada que cancelar.');
    END IF;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_gestiona_tareas
  -- PROPOSITO    : Diagnostica, reconcilia o descarta las tareas DBMS_PARALLEL_EXECUTE (TDM_<hash>)
  --                que una ejecucion interrumpida dejo atras.
  -- ENTRADAS     : p_ejecucion_id; p_modo INFORMAR (solo lectura), RECONCILIAR (reanuda y cierra) o
  --                DESCARTAR (borra sin reanudar); salida por DBMS_OUTPUT.
  -- LEE          : TDM_EJECUCION; TDM_MASK_SOLICITUD; TDM_COLUMNA_FINAL; TDM_EXCEPCION_COL;
  --                TDM_MASK_TRACE; USER_PARALLEL_EXECUTE_TASKS; USER_PARALLEL_EXECUTE_CHUNKS;
  --                DBA_SCHEDULER_RUNNING_JOBS; DBA_SCHEDULER_JOB_CLASSES; DBA_OBJECTS; DBA_TABLES;
  --                GV$SESSION (via pkg_dm_trazabilidad.func_dm_sesion_viva)
  -- ESCRIBE      : DBMS_PARALLEL_EXECUTE: RESUME_TASK (reejecuta el UPDATE de los chunks pendientes
  --                sobre la tabla objetivo) y DROP_TASK; TDM_MASK_TRACE (TAREA_DESCARTADA y APPLY_COL
  --                via proc_dm_trace); DBMS_OUTPUT
  -- ERRORES      : ORA-20340 modo no valido.; ORA-20341 ejecucion inexistente.; ORA-20342 la sesion
  --                principal sigue viva (solo INFORMAR se permite).; ORA-20343 alguna tarea no se
  --                pudo resolver en RECONCILIAR.; ORA-20344 sin SQL guardado (capturado internamente:
  --                cae a RESUME_TASK en forma corta).
  -- LLAMADO DESDE: Externo/script: dm_enmascara_cancel.sql (DESCARTAR), dm_enmascara_reanudar.sql
  --                (RECONCILIAR), dm_monitor.sql (INFORMAR).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_gestiona_tareas(
    p_ejecucion_id IN NUMBER,
    p_modo         IN VARCHAR2 DEFAULT 'INFORMAR'
  ) IS
    -- FIX 2026-10-09 (resultado de las pruebas de kill E-02, ver
    -- claude/hallazgos_correcciones_y_estado_pruebas_2026-10-09.md, seccion 5):
    --  * cada chunk confirma UPDATE + estado PROCESSED en UN solo commit: un kill revierte el
    --    chunk entero y reanudar NO reprocesa los chunks PROCESSED (medido con un UPDATE no
    --    idempotente, n = n + 1, nivel 1 y nivel 2);
    --  * parallel_level 1 ejecuta los chunks en la propia sesion orquestadora; con 2 hay jobs;
    --  * tras matar un job la tarea pasa sola a CRASHED y RESUME_TASK basta; tras matar la
    --    sesion orquestadora (nivel 1) la tarea queda en PROCESSING y hace falta force => TRUE.
    -- El unico peligro de force es un ejecutor vivo: por eso aqui se exige que no quede ninguno.
    TYPE t_mapa IS TABLE OF VARCHAR2(300) INDEX BY VARCHAR2(300);
    l_hash_col   t_mapa;   -- TDM_<hash>      -> TABLA.COLUMNA
    l_col_hash   t_mapa;   -- TABLA.COLUMNA   -> TDM_<hash>
    l_hechas     t_mapa;   -- TABLA.COLUMNA   -> filas (APPLY_COL de esta ejecucion)
    l_nota       t_mapa;   -- TABLA.COLUMNA   -> texto de avance de su tarea interrumpida
    l_punto      VARCHAR2(600);   -- columna/tarea desde la que se continua
    l_diag       VARCHAR2(12);    -- EN_CURSO / HUERFANA / ATENCION / SIN_SESION
    l_modo       VARCHAR2(20) := UPPER(TRIM(p_modo));
    l_esquema    tdm_ejecucion.ora_esquema%TYPE;
    l_estado     tdm_ejecucion.estado%TYPE;
    l_hb         tdm_ejecucion.heartbeat_ts%TYPE;
    l_viva       NUMBER;
    l_solicitud  NUMBER;
    l_edad_min   NUMBER;
    l_k          VARCHAR2(300);
    l_col        VARCHAR2(300);
    l_tab        VARCHAR2(128);
    l_total      NUMBER;
    l_proc       NUMBER;
    l_asg        NUMBER;
    l_unas       NUMBER;
    l_err        NUMBER;
    l_jobs       NUMBER;
    l_estado_t   VARCHAR2(30);
    l_stmt       CLOB;
    l_lang       NUMBER;
    l_ej_tarea   NUMBER;
    l_clase      VARCHAR2(12);
    l_filas_tab  NUMBER;
    l_filas_hechas NUMBER;
    l_obj_chunk  NUMBER;
    l_obj_tab    NUMBER;
    l_nivel      NUMBER;
    l_clase_job  NUMBER;
    l_force      BOOLEAN;
    l_resuelta   BOOLEAN;
    l_n_tareas   PLS_INTEGER := 0;
    l_n_resuel   PLS_INTEGER := 0;
    l_n_sinres   PLS_INTEGER := 0;
    l_n_pend     PLS_INTEGER := 0;
    l_n_cand     PLS_INTEGER := 0;
    l_i          PLS_INTEGER;
    l_visto      PLS_INTEGER;
    l_detalle    VARCHAR2(600);

    PROCEDURE say(p_txt IN VARCHAR2) IS
    BEGIN
      DBMS_OUTPUT.PUT_LINE(p_txt);
    END;

    -- Espera portable: DBMS_SESSION.SLEEP existe desde 18c; DBMS_LOCK.SLEEP desde 8i.
    -- Llamada dinamica para que el paquete compile igual en 11g, 19c y 26ai.
    PROCEDURE espera(p_seg IN NUMBER) IS
    BEGIN
      BEGIN
        EXECUTE IMMEDIATE 'BEGIN DBMS_SESSION.SLEEP(:s); END;' USING p_seg;
      EXCEPTION
        WHEN OTHERS THEN
          BEGIN
            EXECUTE IMMEDIATE 'BEGIN DBMS_LOCK.SLEEP(:s); END;' USING p_seg;
          EXCEPTION
            WHEN OTHERS THEN NULL;
          END;
      END;
    END;

    PROCEDURE cuenta_chunks(p_task IN VARCHAR2) IS
    BEGIN
      SELECT COUNT(*),
             NVL(SUM(CASE WHEN status = 'PROCESSED'            THEN 1 ELSE 0 END),0),
             NVL(SUM(CASE WHEN status = 'ASSIGNED'             THEN 1 ELSE 0 END),0),
             NVL(SUM(CASE WHEN status = 'UNASSIGNED'           THEN 1 ELSE 0 END),0),
             NVL(SUM(CASE WHEN status = 'PROCESSED_WITH_ERROR' THEN 1 ELSE 0 END),0)
        INTO l_total, l_proc, l_asg, l_unas, l_err
        FROM user_parallel_execute_chunks
       WHERE task_name = p_task;
    END;
  BEGIN
    IF l_modo NOT IN ('INFORMAR','RECONCILIAR','DESCARTAR') THEN
      RAISE_APPLICATION_ERROR(-20340,
        'proc_dm_gestiona_tareas: modo "'||p_modo||'" no valido (INFORMAR, RECONCILIAR o DESCARTAR).');
    END IF;

    BEGIN
      SELECT UPPER(ora_esquema), estado, heartbeat_ts
        INTO l_esquema, l_estado, l_hb
        FROM tdm_ejecucion
       WHERE ejecucion_id = p_ejecucion_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20341, 'No existe ejecucion_id='||p_ejecucion_id||' en TDM_EJECUCION.');
    END;

    SELECT MAX(solicitud_id) INTO l_solicitud
      FROM tdm_mask_solicitud
     WHERE ejecucion_id = p_ejecucion_id;

    l_viva := pkg_dm_trazabilidad.func_dm_sesion_viva(p_ejecucion_id);

    IF l_hb IS NOT NULL THEN
      l_edad_min := ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(l_hb AS DATE)) * 1440, 1);
    END IF;

    say('=========================================');
    say('Ejecucion '||p_ejecucion_id||' (esquema '||l_esquema||') -- modo '||l_modo);
    say('Estado en TDM_EJECUCION : '||NVL(l_estado,'?')||
        CASE WHEN l_edad_min IS NOT NULL THEN '   (ultimo latido hace '||l_edad_min||' min)' END);
    IF UPPER(NVL(l_estado,'?')) = 'EJECUTANDO' AND l_viva = 1 THEN
      l_diag := 'EN_CURSO';
      say('Diagnostico             : EN CURSO. La sesion principal esta viva.');
    ELSIF UPPER(NVL(l_estado,'?')) = 'EJECUTANDO' THEN
      l_diag := 'HUERFANA';
      say('Diagnostico             : SE QUEDO SIN SESION PRINCIPAL. La fila sigue EJECUTANDO pero la sesion que la lanzo ya no existe.');
    ELSIF l_viva = 1 THEN
      l_diag := 'ATENCION';
      say('Diagnostico             : ATENCION. Estado '||l_estado||' pero hay una sesion viva con los datos de esta ejecucion.');
    ELSE
      l_diag := 'SIN_SESION';
      say('Diagnostico             : sin sesion viva (estado '||NVL(l_estado,'?')||').');
    END IF;

    IF l_modo <> 'INFORMAR' AND l_viva = 1 THEN
      RAISE_APPLICATION_ERROR(-20342,
        'La sesion principal de ejecucion_id='||p_ejecucion_id||' sigue VIVA: no se toca ninguna tarea. '||
        'Si de verdad quiere abortar esa ejecucion use @dm_enmascara_cancel '||p_ejecucion_id||' CONFIRMAR.');
    END IF;

    -- Columnas objetivo (Y de TDM_COLUMNA_FINAL + FORCE vivos): dos consultas simples,
    -- sin CTE/UNION/EXISTS correlado (ORA-07445 qctcopn_internal ya visto en proc_dm_mask_cat).
    FOR f IN (
      SELECT table_name, column_name
        FROM tdm_columna_final
       WHERE ora_owner = l_esquema
         AND enmascarar = 'Y'
    ) LOOP
      l_col := f.table_name||'.'||f.column_name;
      l_k   := 'TDM_'||TO_CHAR(DBMS_UTILITY.GET_HASH_VALUE(
                 l_esquema||'.'||UPPER(f.table_name)||'.'||UPPER(f.column_name), 1, 1000000000));
      l_hash_col(l_k) := l_col;
      l_col_hash(l_col) := l_k;
    END LOOP;
    FOR fx IN (
      SELECT func_dm_norm(e.table_name)  AS table_name,
             func_dm_norm(e.column_name) AS column_name
        FROM tdm_excepcion_col e
       WHERE func_dm_norm(e.ora_owner) = l_esquema
         AND func_dm_norm(e.activa) = 'Y'
         AND func_dm_norm(e.accion) = 'FORCE'
         AND e.identificador_forz IS NOT NULL
    ) LOOP
      l_col := fx.table_name||'.'||fx.column_name;
      l_k   := 'TDM_'||TO_CHAR(DBMS_UTILITY.GET_HASH_VALUE(
                 l_esquema||'.'||UPPER(fx.table_name)||'.'||UPPER(fx.column_name), 1, 1000000000));
      l_hash_col(l_k) := l_col;
      l_col_hash(l_col) := l_k;
    END LOOP;

    -- Columnas ya terminadas en esta ejecucion (misma clave que usa proc_dm_mask_cat para saltarlas).
    FOR tr IN (
      SELECT detalle
        FROM tdm_mask_trace
       WHERE ejecucion_id = p_ejecucion_id
         AND fase = 'MASK'
         AND paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
    ) LOOP
      l_i := INSTR(tr.detalle, ' filas=');
      IF l_i > 0 THEN
        l_k := SUBSTR(tr.detalle, 1, l_i - 1);
        IF SUBSTR(l_k, 1, LENGTH(l_esquema) + 1) = l_esquema||'.' THEN
          l_hechas(SUBSTR(l_k, LENGTH(l_esquema) + 2)) := TO_CHAR(NVL(TO_NUMBER(REGEXP_SUBSTR(
            SUBSTR(tr.detalle, l_i + 7), '^[0-9]+')), 0));
        END IF;
      END IF;
    END LOOP;

    say('-----------------------------------------');
    say('TAREAS PARALELAS DEL MOTOR (DBMS_PARALLEL_EXECUTE) de este esquema:');

    FOR t IN (
      SELECT task_name, status
        FROM user_parallel_execute_tasks
       WHERE task_name LIKE 'TDM\_%' ESCAPE '\'
       ORDER BY task_name
    ) LOOP
      IF NOT l_hash_col.EXISTS(t.task_name) THEN
        CONTINUE;   -- no es de este esquema o su columna ya no es objetivo; no se toca
      END IF;
      l_n_tareas := l_n_tareas + 1;
      l_col := l_hash_col(t.task_name);
      l_tab := SUBSTR(l_col, 1, INSTR(l_col, '.') - 1);

      cuenta_chunks(t.task_name);

      -- Ejecutores vivos de esta tarea: jobs en ejecucion que figuran en sus chunks. La sesion
      -- orquestadora (nivel 1) se cubre con l_viva.
      SELECT COUNT(*) INTO l_jobs
        FROM dba_scheduler_running_jobs r
       WHERE r.job_name IN (SELECT c.job_name FROM user_parallel_execute_chunks c
                             WHERE c.task_name = t.task_name AND c.job_name IS NOT NULL);

      -- Ejecucion a la que pertenece la tarea: el SQL del chunk lleva el id como literal
      -- (proc_dm_set_ejecucion(<id>)) y con el sale el pepper con el que se cifro.
      l_stmt := NULL; l_lang := NULL; l_ej_tarea := NULL;
      BEGIN
        EXECUTE IMMEDIATE 'SELECT sql_stmt, language_flag FROM user_parallel_execute_tasks WHERE task_name = :1'
          INTO l_stmt, l_lang USING t.task_name;
        l_ej_tarea := TO_NUMBER(REGEXP_SUBSTR(DBMS_LOB.SUBSTR(l_stmt, 1000, 1),
                        'proc_dm_set_ejecucion\(([0-9]+)\)', 1, 1, 'i', 1));
      EXCEPTION
        WHEN OTHERS THEN l_ej_tarea := NULL;
      END;

      -- OBSOLETA: el rowid de los chunks lleva el data_object_id de la tabla.
      l_obj_chunk := NULL; l_obj_tab := NULL;
      BEGIN
        SELECT DBMS_ROWID.ROWID_OBJECT(start_rowid) INTO l_obj_chunk
          FROM user_parallel_execute_chunks
         WHERE task_name = t.task_name AND start_rowid IS NOT NULL AND ROWNUM = 1;
        SELECT o.data_object_id INTO l_obj_tab
          FROM dba_objects o
         WHERE o.owner = l_esquema AND o.object_name = l_tab AND o.object_type = 'TABLE';
      EXCEPTION
        WHEN OTHERS THEN l_obj_chunk := NULL;
      END;

      IF l_obj_chunk IS NOT NULL AND l_obj_tab IS NOT NULL AND l_obj_chunk <> l_obj_tab THEN
        l_clase := 'OBSOLETA';
      ELSIF l_ej_tarea IS NULL OR l_ej_tarea <> p_ejecucion_id THEN
        l_clase := 'AJENA';
      ELSIF l_jobs > 0 OR (l_viva = 1 AND t.status <> 'FINISHED') THEN
        l_clase := 'EN_CURSO';
      ELSIF l_total = 0 THEN
        l_clase := 'VACIA';
      ELSIF t.status = 'FINISHED' AND l_proc = l_total THEN
        l_clase := 'CERRADA';
      ELSE
        l_clase := 'RECUPERABLE';
      END IF;

      BEGIN
        SELECT num_rows INTO l_filas_tab FROM dba_tables WHERE owner = l_esquema AND table_name = l_tab;
      EXCEPTION
        WHEN OTHERS THEN l_filas_tab := NULL;
      END;

      say('  '||t.task_name||'  '||l_col||'  tarea='||t.status||'  clase='||l_clase);
      say('    chunks: total='||l_total||' PROCESSED='||l_proc||' ASSIGNED='||l_asg||' UNASSIGNED='||l_unas||
          ' CON_ERROR='||l_err||'   ejecutores vivos (jobs)='||l_jobs||
          CASE WHEN l_total > 0 AND l_filas_tab IS NOT NULL
               THEN '   avance='||ROUND(100 * l_proc / l_total)||'% (~'||ROUND(l_filas_tab * l_proc / l_total)||
                    ' de ~'||l_filas_tab||' filas)'
          END);
      IF l_clase IN ('RECUPERABLE','EN_CURSO') THEN
        l_nota(l_col) := 'tarea '||t.task_name||' con '||l_proc||' de '||l_total||' chunks hechos'||
                         CASE WHEN l_total > 0 AND l_filas_tab IS NOT NULL
                              THEN ' (~'||ROUND(l_filas_tab * l_proc / l_total)||' de ~'||l_filas_tab||' filas)' END;
        IF l_punto IS NULL THEN
          l_punto := l_esquema||'.'||l_col||': '||l_nota(l_col);
        END IF;
      END IF;
      IF l_clase = 'OBSOLETA' THEN
        say('    -> sus chunks apuntan a OTRA version de la tabla (recargada, recreada, truncada o movida). '||
            'No describen los datos actuales: no se reanuda. Restaure/valide el dato y descarte la tarea con '||
            '@dm_enmascara_cancel '||p_ejecucion_id||' CONFIRMAR DESCARTAR.');
      ELSIF l_clase = 'AJENA' THEN
        say('    -> '||CASE WHEN l_ej_tarea IS NULL THEN 'no se pudo determinar a que ejecucion pertenece'
                           ELSE 'pertenece a la ejecucion '||l_ej_tarea END||
            ': reanudarla con la semilla de otra ejecucion mezclaria dos semillas en la misma columna. No se toca'||
            CASE WHEN l_ej_tarea IS NOT NULL
                 THEN '; resuelvala con @dm_enmascara_reanudar '||l_ej_tarea||
                      ' o descartela con @dm_enmascara_cancel '||l_ej_tarea||' CONFIRMAR DESCARTAR'
            END||'.');
      ELSIF l_clase = 'VACIA' THEN
        say('    -> sin chunks (la preparacion se interrumpio antes de repartir el trabajo): no hay nada cifrado por esta tarea.');
      ELSIF l_clase = 'EN_CURSO' THEN
        say('    -> hay ejecutores vivos (jobs) o la sesion principal sigue activa. Si la sesion principal ya no existe (ver el');
        say('       Diagnostico de arriba), los jobs terminan el chunk que tienen en curso y se detienen. @dm_enmascara_reanudar');
        say('       espera 30 s y, si siguen vivos, los mata: ese chunk se revierte entero y se rehace. Para no rehacerlo,');
        say('       espere a que su chunk pase a PROCESSED (3b del monitor) y reanude despues.');
      ELSIF l_clase = 'CERRADA' THEN
        say('    -> terminada y sin borrar: todos sus chunks estan PROCESSED. Solo falta registrarla y cerrarla.');
      ELSE
        say('    -> interrumpida: se puede reanudar sin reprocesar los '||l_proc||' chunks PROCESSED'||
            CASE WHEN l_asg > 0 THEN ' (los '||l_asg||' ASSIGNED quedaron revertidos por el kill)' END||'.');
      END IF;

      l_resuelta := FALSE;

      IF l_modo = 'DESCARTAR' AND l_clase IN ('AJENA','EN_CURSO') THEN
        say('    ** NO se descarta (clase '||l_clase||'): no es de esta ejecucion o aun tiene ejecutores vivos.');
      ELSIF l_modo = 'DESCARTAR' THEN
        BEGIN
          DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => t.task_name);
          l_resuelta := TRUE;
          say('    ** DESCARTADA. Sus '||l_proc||' chunks PROCESSED siguen cifrados en la tabla: restaure el dato antes de relanzar.');
          proc_dm_trace(l_solicitud, p_ejecucion_id, 'MASK', 'TAREA_DESCARTADA',
            t.task_name||' ('||l_esquema||'.'||l_col||') descartada sin reanudar; chunks PROCESSED='||l_proc||'.');
        EXCEPTION
          WHEN OTHERS THEN
            say('    ** NO se pudo borrar la tarea: '||SUBSTR(SQLERRM,1,200));
        END;

      ELSIF l_modo = 'RECONCILIAR' THEN
        IF l_clase = 'VACIA' THEN
          BEGIN
            DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => t.task_name);
            l_resuelta := TRUE;
            say('    ** borrada (no tenia chunks); la columna se procesara completa al reanudar.');
          EXCEPTION
            WHEN OTHERS THEN
              say('    ** NO se pudo borrar la tarea: '||SUBSTR(SQLERRM,1,200));
          END;
        END IF;
        IF l_clase = 'RECUPERABLE' THEN
          l_nivel := CASE WHEN func_dm_tabla_tiene_trig_upd(l_esquema, l_tab) = 'Y' THEN 1 ELSE 2 END;
          l_force := (t.status = 'PROCESSING');
          l_clase_job := 0;
          BEGIN
            SELECT COUNT(*) INTO l_clase_job FROM dba_scheduler_job_classes WHERE job_class_name = 'JC_DATAMASKING';
          EXCEPTION
            WHEN OTHERS THEN l_clase_job := 0;
          END;
          say('    ** reanudando (nivel de paralelismo '||l_nivel||
              CASE WHEN l_force THEN ', force porque la tarea quedo en PROCESSING sin ejecutores' END||')...');
          BEGIN
            IF l_stmt IS NULL THEN
              RAISE_APPLICATION_ERROR(-20344, 'sin SQL guardado');
            END IF;
            IF l_clase_job > 0 THEN
              DBMS_PARALLEL_EXECUTE.RESUME_TASK(task_name => t.task_name, sql_stmt => l_stmt,
                language_flag => l_lang, parallel_level => l_nivel, job_class => 'JC_DATAMASKING', force => l_force);
            ELSE
              DBMS_PARALLEL_EXECUTE.RESUME_TASK(task_name => t.task_name, sql_stmt => l_stmt,
                language_flag => l_lang, parallel_level => l_nivel, force => l_force);
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              -- forma corta: reutiliza el SQL y el paralelismo que la propia tarea guardo
              BEGIN
                DBMS_PARALLEL_EXECUTE.RESUME_TASK(task_name => t.task_name, force => l_force);
              EXCEPTION
                WHEN OTHERS THEN
                  say('    ** RESUME_TASK fallo: '||SUBSTR(SQLERRM,1,200));
              END;
          END;
          l_i := 0;
          LOOP
            EXIT WHEN DBMS_PARALLEL_EXECUTE.TASK_STATUS(t.task_name) NOT IN
              (DBMS_PARALLEL_EXECUTE.PROCESSING, DBMS_PARALLEL_EXECUTE.CHUNKING);
            l_i := l_i + 1;
            EXIT WHEN l_i > 30;
            espera(2);
          END LOOP;
          cuenta_chunks(t.task_name);
          IF DBMS_PARALLEL_EXECUTE.TASK_STATUS(t.task_name) = DBMS_PARALLEL_EXECUTE.FINISHED
             AND l_total > 0 AND l_proc = l_total THEN
            l_clase := 'CERRADA';
            say('    ** terminada: '||l_proc||'/'||l_total||' chunks PROCESSED.');
          ELSE
            say('    ** NO quedo completa: chunks PROCESSED='||l_proc||'/'||l_total||' CON_ERROR='||l_err||
                ' ASSIGNED='||l_asg||'. La tarea se conserva para revisarla (no se borra nada).');
          END IF;
        END IF;

        IF l_clase = 'CERRADA' THEN
          BEGIN
            l_filas_hechas := NVL(l_filas_tab, 0);
            l_hechas(l_col) := TO_CHAR(l_filas_hechas);
            proc_dm_trace(l_solicitud, p_ejecucion_id, 'MASK', 'APPLY_COL',
              l_esquema||'.'||l_col||' filas='||l_filas_hechas||' (completada al reanudar una tarea interrumpida)');
            DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => t.task_name);
            l_resuelta := TRUE;
            say('    ** registrada como hecha en esta ejecucion y tarea cerrada.');
          EXCEPTION
            WHEN OTHERS THEN
              say('    ** NO se pudo cerrar la tarea: '||SUBSTR(SQLERRM,1,200));
          END;
        END IF;
      END IF;

      IF l_resuelta THEN
        l_n_resuel := l_n_resuel + 1;
      ELSIF l_modo <> 'INFORMAR' THEN
        l_n_sinres := l_n_sinres + 1;
      END IF;
    END LOOP;

    IF l_n_tareas = 0 THEN
      say('  Ninguna: no hay tareas pendientes de este esquema.');
    END IF;

    -- Desde donde se reanudaria: columnas objetivo que aun no estan terminadas.
    say('-----------------------------------------');
    l_k := l_col_hash.FIRST;
    l_visto := 0;
    WHILE l_k IS NOT NULL LOOP
      l_n_cand := l_n_cand + 1;
      IF NOT l_hechas.EXISTS(l_k) THEN
        l_n_pend := l_n_pend + 1;
      END IF;
      l_k := l_col_hash.NEXT(l_k);
    END LOOP;
    IF l_punto IS NOT NULL AND l_modo <> 'DESCARTAR' THEN
      say(CASE WHEN l_modo = 'RECONCILIAR' THEN 'INTERRUMPIDA EN: ' ELSE 'SE REANUDARIA DESDE: ' END||l_punto);
    END IF;
    say('COLUMNAS: '||(l_n_cand - l_n_pend)||' terminadas, '||l_n_pend||' pendientes de '||l_n_cand||' objetivo.');
    l_k := l_col_hash.FIRST;
    WHILE l_k IS NOT NULL AND l_visto < 12 LOOP
      IF NOT l_hechas.EXISTS(l_k) THEN
        l_visto := l_visto + 1;
        say('  pendiente: '||l_esquema||'.'||l_k||
            CASE WHEN l_nota.EXISTS(l_k) THEN '   <- '||l_nota(l_k) END);
      END IF;
      l_k := l_col_hash.NEXT(l_k);
    END LOOP;
    IF l_n_pend > l_visto THEN
      say('  ... y '||(l_n_pend - l_visto)||' mas.');
    END IF;
    say('=========================================');

    IF l_modo = 'INFORMAR' THEN
      IF l_diag IN ('EN_CURSO','ATENCION') THEN
        say('SIGUIENTE PASO: ninguno, sigue corriendo. Siga el avance con @dm_monitor '||p_ejecucion_id||
            '. No lance reanudar ni cancelar salvo que la vea colgada.');
      ELSIF l_diag = 'HUERFANA' OR l_n_tareas > 0 OR (UPPER(NVL(l_estado,'?')) <> 'FINALIZADO' AND l_n_pend > 0) THEN
        say('SIGUIENTE PASO: @dm_enmascara_reanudar '||p_ejecucion_id||
            '  (revisa y limpia sesiones/jobs/chunks/tareas y continua sin reprocesar lo ya cifrado)');
        say('               o @dm_enmascara_cancel '||p_ejecucion_id||
            ' CONFIRMAR  (si prefiere abortar toda la ejecucion).');
      ELSE
        say('SIGUIENTE PASO: ninguno, no hay nada pendiente.');
      END IF;
    ELSIF l_modo = 'RECONCILIAR' THEN
      IF l_n_sinres > 0 THEN
        RAISE_APPLICATION_ERROR(-20343,
          l_n_sinres||' tarea(s) NO se pudieron resolver (ver detalle arriba). No se reanuda: relanzar esas '||
          'columnas podria cifrar dos veces filas ya cifradas.');
      END IF;
      say('Reconciliacion completada: '||l_n_resuel||' tarea(s) cerrada(s).');
    ELSIF l_modo = 'DESCARTAR' THEN
      say('Tareas descartadas: '||l_n_resuel||'.');
    END IF;
  END proc_dm_gestiona_tareas;

  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_tareas_de_ejecucion
  -- PROPOSITO    : Decir que tareas DBMS_PARALLEL_EXECUTE pertenecen a una ejecucion, con el mismo
  --                criterio que proc_dm_gestiona_tareas (id literal en el SQL del chunk).
  -- ENTRADAS     : p_ejecucion_id.
  -- SALIDA       : nombres separados por coma (maximo ~4000 caracteres) o NULL.
  -- LEE          : USER_PARALLEL_EXECUTE_TASKS (esquema del motor: corre con derechos del definidor).
  -- LLAMADO DESDE: dm_enmascara_reanudar.sql (revision previa).
  -- NOTA         : SQL_STMT se lee dinamicamente por portabilidad, igual que en proc_dm_gestiona_tareas.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_tareas_de_ejecucion(
    p_ejecucion_id IN NUMBER
  ) RETURN VARCHAR2 IS
    l_lista VARCHAR2(4000);
    l_stmt  CLOB;
    l_ej    NUMBER;
  BEGIN
    FOR t IN (
      SELECT task_name
        FROM user_parallel_execute_tasks
       WHERE task_name LIKE 'TDM\_%' ESCAPE '\'
       ORDER BY task_name
    ) LOOP
      l_stmt := NULL; l_ej := NULL;
      BEGIN
        EXECUTE IMMEDIATE 'SELECT sql_stmt FROM user_parallel_execute_tasks WHERE task_name = :1'
          INTO l_stmt USING t.task_name;
        l_ej := TO_NUMBER(REGEXP_SUBSTR(DBMS_LOB.SUBSTR(l_stmt, 1000, 1),
                  'proc_dm_set_ejecucion\(([0-9]+)\)', 1, 1, 'i', 1));
      EXCEPTION
        WHEN OTHERS THEN l_ej := NULL;
      END;
      IF l_ej = p_ejecucion_id THEN
        EXIT WHEN LENGTH(NVL(l_lista, ' ')) + LENGTH(t.task_name) + 1 > 3990;
        l_lista := CASE WHEN l_lista IS NULL THEN t.task_name ELSE l_lista||','||t.task_name END;
      END IF;
    END LOOP;
    RETURN l_lista;
  END func_dm_tareas_de_ejecucion;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_reanudar
  -- PROPOSITO    : Reanuda un enmascarado interrumpido sobre la misma ejecucion_id, tras verificar
  --                fase correcta y sesion original muerta, saltando las columnas ya confirmadas.
  -- ENTRADAS     : p_ejecucion_id; p_commit_lote (solo se reenvia).
  -- LEE          : TDM_EJECUCION (SELECT FOR UPDATE); TDM_MASK_SOLICITUD; GV$SESSION (via
  --                pkg_dm_trazabilidad.func_dm_sesion_viva)
  -- ESCRIBE      : variable de paquete g_resume_base_solicitud;
  --                todo lo que escribe proc_dm_enmascaramiento (llamada con p_reproceso = N)
  -- ERRORES      : ORA-20058 la fase_proceso no es ENMASCARAMIENTO.; ORA-20017 la sesion original
  --                sigue viva en gv$session.; NO_DATA_FOUND (ORA-01403) si la ejecucion no existe.
  -- LLAMADO DESDE: Externo/script: dm_enmascara_reanudar.sql.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_reanudar(
    p_ejecucion_id IN NUMBER,
    p_commit_lote  IN NUMBER DEFAULT 1000
  ) IS
    l_prev_solicitud NUMBER;
    l_estado         tdm_ejecucion.estado%TYPE;
    l_fase           tdm_ejecucion.fase_proceso%TYPE;
    l_sid            tdm_ejecucion.sesion_sid%TYPE;
    l_serial         tdm_ejecucion.sesion_serial%TYPE;
    l_inst_id        tdm_ejecucion.sesion_inst_id%TYPE;
    l_ejecutado_por  tdm_ejecucion.ora_usuario%TYPE;
  BEGIN
    -- FIX 2026-10-06 (contraparte del incidente real de
    -- pkg_dm_descubrimiento.proc_dm_reanudar -- ver su comentario del mismo
    -- dia en 04 -- con @dm_descubre_reanudar corrido por error sobre una fila
    -- que en realidad estaba en ENMASCARAMIENTO): la misma clase de error
    -- humano es posible en este sentido inverso, corriendo
    -- @dm_enmascara_reanudar sobre una ejecucion_id que en realidad sigue en
    -- fase DESCUBRIMIENTO (p.ej. abortada antes de llegar siquiera a
    -- arrancar el enmascarado). Nada de lo que hay aqui debajo lo detectaba:
    -- se llama directo a proc_dm_enmascaramiento, que reclama la fila y le
    -- pisa fase_proceso='ENMASCARAMIENTO'/estado='EJECUTANDO' sin mirar en
    -- que fase estaba antes. Se corta aqui, antes de tocar nada, con un
    -- mensaje que apunta al driver correcto. (Chequeo fundido en el mismo
    -- SELECT...FOR UPDATE de mas abajo -- que ya trae estado/sesion -- en
    -- vez de una segunda lectura suelta de la misma fila.)
    --
    -- 2026-10-04 FIX CRITICO (incidente real ejecucion_id=5, 7 constraints
    -- deshabilitadas): antes de este fix, proc_dm_reanudar NUNCA comprobaba
    -- si la sesion Oracle que registro esta ejecucion_id seguia realmente
    -- viva -- dependia por completo de que proc_dm_enmascaramiento ->
    -- proc_dm_validar_concurrencia encontrara la fila en ESTADO='EJECUTANDO'.
    -- Un DBA puede liberar esa fila manualmente con
    -- dm_liberar_ejecucion_activa.sql, que SOLO cambia ESTADO a ABORTADA y
    -- NUNCA toca sesion_sid/sesion_serial/sesion_inst_id/sesion_audsid -- si
    -- en ese momento la sesion original seguia viva de verdad (p.ej.
    -- bloqueada dentro de un chunk largo de DBMS_PARALLEL_EXECUTE sobre una
    -- columna de millones de filas), la guarda de ESTADO ya no la detecta, y
    -- proc_dm_reanudar lanzaba una SEGUNDA ejecucion en paralelo sobre el
    -- mismo esquema. Esto ocurrio de verdad en produccion (ejecucion_id=5,
    -- 2026-10-04): la sesion original (solicitud_id=1) siguio corriendo
    -- APPLY_COL sobre TBL_CUENTA_VOL.CUENTA_CCC al mismo tiempo que la
    -- reanudacion manual (solicitud_id=2), cruzando ambas ejecuciones y
    -- dejando 7 constraints deshabilitadas al final.
    --
    -- La comprobacion de abajo es INCONDICIONAL -- no mira ESTADO en
    -- absoluto, solo si gv$session confirma una sesion viva para los datos
    -- de sesion grabados en TDM_EJECUCION. Mismo mecanismo que ya usa
    -- pkg_dm_descubrimiento.proc_dm_reanudar (04) via
    -- pkg_dm_trazabilidad.func_dm_sesion_viva (03b), pero SIN el "IF
    -- estado='EJECUTANDO'" que alli mismo deja la misma brecha si alguien
    -- cambia el estado por fuera (p.ej. con un UPDATE manual) mientras la
    -- sesion original sigue viva.
    SELECT estado, fase_proceso, sesion_sid, sesion_serial, sesion_inst_id, ora_usuario
      INTO l_estado, l_fase, l_sid, l_serial, l_inst_id, l_ejecutado_por
      FROM tdm_ejecucion
     WHERE ejecucion_id = p_ejecucion_id
       FOR UPDATE;

    IF l_fase IS NOT NULL AND UPPER(TRIM(l_fase)) != 'ENMASCARAMIENTO' THEN
      RAISE_APPLICATION_ERROR(-20058,
        'No se reanuda ejecucion_id='||p_ejecucion_id||' con pkg_dm_enmascarar.proc_dm_reanudar: '||
        'su fase_proceso actual es '||l_fase||', no ENMASCARAMIENTO. '||
        CASE WHEN UPPER(TRIM(l_fase)) = 'DESCUBRIMIENTO'
             THEN 'Use @dm_descubre_reanudar '||p_ejecucion_id||' para reanudar el descubrimiento.'
             ELSE 'Revise TDM_EJECUCION.fase_proceso antes de continuar.'
        END);
    END IF;

    IF pkg_dm_trazabilidad.func_dm_sesion_viva(p_ejecucion_id) = 1 THEN
      RAISE_APPLICATION_ERROR(-20017,
        'No se reanuda ejecucion_id='||p_ejecucion_id||': la sesion original '||
        '(sid='||NVL(TO_CHAR(l_sid),'?')||', serial#='||NVL(TO_CHAR(l_serial),'?')||
        ', inst_id='||NVL(TO_CHAR(l_inst_id),'?')||', usuario='||NVL(l_ejecutado_por,'?')||
        ') SIGUE VIVA en gv$session (TDM_EJECUCION.ESTADO actual='||NVL(l_estado,'?')||
        '). No se reanuda para evitar una ejecucion duplicada en paralelo -- '||
        'verifique esa sesion y matela con ALTER SYSTEM KILL SESSION si procede, luego reintente.');
    END IF;

    SELECT MAX(solicitud_id)
      INTO l_prev_solicitud
      FROM tdm_mask_solicitud
     WHERE ejecucion_id = p_ejecucion_id;

    -- La reanudacion queda registrada en la traza con la NUEVA solicitud: ENMASCARAMIENTO.INICIO
    -- (lleva '- REANUDACION desde solicitud_id=N') y ENMASCARAMIENTO.REANUDACION (columnas ya
    -- confirmadas y pendientes, en proc_dm_mask_cat). Antes se escribia aqui MASK.REANUDACION_INICIO
    -- con solicitud_id NULL, antes de crear la solicitud.
    g_resume_base_solicitud := l_prev_solicitud;
    proc_dm_enmascaramiento(p_ejecucion_id => p_ejecucion_id, p_reproceso => 'N', p_commit_lote => p_commit_lote);
    g_resume_base_solicitud := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      g_resume_base_solicitud := NULL;
      RAISE;
  END;

  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_enmascara_tabla
  -- PROPOSITO    : Enmascara de forma selectiva una o varias tablas (o columnas) con un identificador
  --                dado, creando una ejecucion ad hoc con su propio pepper efimero.
  -- ENTRADAS     : p_esquema, p_tabla (CSV), p_identificador, p_columna (CSV opcional, si es nulo usa
  --                todas las columnas de texto), p_commit_lote (sin uso en el cuerpo).
  -- LEE          : DBA_TAB_COLUMNS; TDM_EXCEPCION_COL; SEQ_DM_EJECUCION
  -- ESCRIBE      : TDM_EJECUCION (INSERT de ejecucion ad hoc y cambios de estado);
  --                TDM_MASK_SOLICITUD; TDM_SECRETO (alta y purga del pepper); datos de las tablas
  --                objetivo (via proc_dm_apl_col); TDM_MASK_DEP_ESTADO y DDL de constraints/triggers
  --                (via pre_dep y post_dep)
  -- ERRORES      : Propaga ORA-20097/ORA-20098 de proc_dm_validar_concurrencia y ORA-20050..20054 de
  --                proc_dm_validar_base.; En cualquier fallo marca solicitud y ejecucion en ERROR,
  --                purga el pepper y re-lanza el error.
  -- LLAMADO DESDE: externo/script (sin llamadas en los archivos del motor; solo mencionada en
  --                comentarios y descripciones de eventos).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_enmascara_tabla(
    p_esquema       IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_identificador IN VARCHAR2,
    p_columna       IN VARCHAR2 DEFAULT NULL,
    p_commit_lote   IN NUMBER   DEFAULT 1000
  ) IS
    l_esquema      VARCHAR2(128) := func_dm_norm(p_esquema);
    l_solicitud_id NUMBER;
    l_idx          PLS_INTEGER := 1;
    l_col_idx      PLS_INTEGER;
    l_columna      VARCHAR2(128);
    l_tabla        VARCHAR2(128);
    l_ejecucion_id NUMBER;
    l_err_code     NUMBER;
    l_err_stack    VARCHAR2(1800);
    l_err_bt       VARCHAR2(1800);
  BEGIN
    proc_dm_validar_base;

    -- B-01 (auditoria 2026-09-16): esta rutina creaba la solicitud con
    -- ejecucion_id=-1, un valor que nunca se siembra en tdm_ejecucion. Tanto
    -- fk_tdm_mask_sol_ejec (tdm_mask_solicitud) como fk_tdm_mask_trace_ejec
    -- (tdm_mask_trace) violaban ORA-02291 en la primera llamada real: la
    -- funcion estaba rota de origen, no solo "sin documentar". Ademas, -1 es
    -- un literal fijo, asi que TODAS las invocaciones de proc_dm_enmascara_tabla a lo
    -- largo del tiempo habrian compartido el mismo pepper
    -- (clave='PEPPER_MASK:-1'), nunca purgado: justo el secreto
    -- compartido/no rotado que el diseno de pepper por ejecución busca evitar.
    --
    -- Correccion: se crea una ejecucion real y minima ("ad-hoc"), con su
    -- propia fila en tdm_ejecucion, para que el modo selectivo viva dentro
    -- del mismo modelo de trazabilidad, pepper efimero y purga que una
    -- ejecución completa.
    --
    -- FIX 2026-09-27 (auditoria , Nivel 1 #5): antes de este cambio
    -- proc_dm_enmascara_tabla no tenia NINGUNA guarda de concurrencia -- a diferencia de
    -- proc_dm_enmascaramiento (que llama proc_dm_validar_concurrencia antes de
    -- reclamar su fila), dos llamadas simultaneas a proc_dm_enmascara_tabla sobre el
    -- mismo esquema (o una proc_dm_enmascara_tabla mientras proc_dm_enmascaramiento ya tiene una
    -- ejecución EJECUTANDO sobre ese esquema) podian pisarse: dependencias
    -- deshabilitadas/rehabilitadas de forma entrelazada, dos peppers
    -- efimeros coexistiendo sin relacion entre si. La fila se inserta ahora
    -- en PENDIENTE (no EJECUTANDO) para no dejar un EJECUTANDO huerfano si
    -- la validacion de concurrencia rechaza el arranque; solo tras pasar la
    -- validacion se reclama atomicamente a EJECUTANDO, igual que hace
    -- proc_dm_enmascaramiento.
    l_ejecucion_id := seq_dm_ejecucion.NEXTVAL;
    INSERT INTO tdm_ejecucion(
      ejecucion_id, ora_esquema, ora_usuario, fase_proceso, estado, fecha_inicio
    ) VALUES (
      l_ejecucion_id, l_esquema, USER, 'ENMASCARAMIENTO', 'PENDIENTE', SYSTIMESTAMP
    );
    COMMIT;

    -- proc_dm_validar_concurrencia ya incluye el barrido de huerfanas (mismo
    -- mecanismo que usa proc_dm_enmascaramiento/proc_dm_reanudar) y excluye la propia
    -- fila (ejecucion_id=l_ejecucion_id, aun en PENDIENTE, nunca EJECUTANDO)
    -- de su propia comprobacion.
    proc_dm_validar_concurrencia(l_ejecucion_id, l_esquema);

    UPDATE tdm_ejecucion
       SET estado = 'EJECUTANDO', heartbeat_ts = SYSTIMESTAMP
     WHERE ejecucion_id = l_ejecucion_id;
    COMMIT;   -- visible para los workers paralelos antes de generar el pepper

    proc_dm_pepper_generar(l_ejecucion_id);
    l_solicitud_id := func_dm_crea_sol(l_ejecucion_id,l_esquema,'Enmascaramiento selectivo (proc_dm_enmascara_tabla)');

    -- FIX 2026-09-27 (Nivel 1 #5): se pasa p_tabla para acotar las dependencias
    -- deshabilitadas SOLO a las tablas que esta llamada va a enmascarar (ver
    -- comentario de proc_dm_pre_dep). proc_dm_enmascaramiento sigue sin pasar este
    -- parametro (comportamiento de esquema completo, intacto).
    proc_dm_pre_dep(l_solicitud_id,l_ejecucion_id,l_esquema,p_tabla);

    LOOP
      l_tabla := func_dm_csv_item(p_tabla, l_idx);
      EXIT WHEN l_tabla IS NULL;

      DECLARE
        l_cols_total NUMBER := 0;
        l_cols_excl  NUMBER := 0;
      BEGIN
        SELECT COUNT(*) INTO l_cols_total
          FROM dba_tab_columns
         WHERE owner = l_esquema
           AND table_name = l_tabla
           AND data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2');

        SELECT COUNT(*) INTO l_cols_excl
          FROM tdm_excepcion_col e
         WHERE func_dm_norm(e.ora_owner) = l_esquema
           AND e.table_name = l_tabla
           AND func_dm_norm(e.activa) = 'Y'
           AND func_dm_norm(e.accion) = 'EXCLUDE';

        IF l_cols_total > 0 AND l_cols_excl >= l_cols_total THEN
          proc_dm_trace(
            l_solicitud_id,
            l_ejecucion_id,
            'MASK',
            'SKIP_TABLE_TABMODE',
            l_esquema||'.'||l_tabla||' omitida en proc_dm_enmascara_tabla: todas las columnas tipo texto están EXCLUDE'
          );
          l_idx := l_idx + 1;
          CONTINUE;
        END IF;
      END;

      IF p_columna IS NOT NULL THEN
        l_col_idx := 1;
        LOOP
          l_columna := func_dm_csv_item(p_columna, l_col_idx);
          EXIT WHEN l_columna IS NULL;
          proc_dm_apl_col(l_solicitud_id,l_ejecucion_id,l_esquema,l_esquema,l_tabla,l_columna,p_identificador);
          l_col_idx := l_col_idx + 1;
        END LOOP;
      ELSE
        FOR rc IN (
          SELECT column_name
            FROM dba_tab_columns
           WHERE owner = l_esquema
             AND table_name = l_tabla
             AND data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2')
        ) LOOP
          proc_dm_apl_col(l_solicitud_id,l_ejecucion_id,l_esquema,l_esquema,l_tabla,rc.column_name,p_identificador);
        END LOOP;
      END IF;

      l_idx := l_idx + 1;
    END LOOP;

    proc_dm_post_sync(l_solicitud_id,l_ejecucion_id,l_esquema);
    proc_dm_post_dep(l_solicitud_id,l_ejecucion_id);
    proc_dm_upd_sol(l_solicitud_id,'FINALIZADO','FIN','FINALIZADO','Enmascaramiento selectivo finalizado','Y');
    proc_dm_upd_ejec(l_ejecucion_id,'ENMASCARAMIENTO','FINALIZADO',100,NULL,NULL,NULL,NULL,NULL,'FINALIZADO');

    -- Ejecucion ad-hoc sin fase de export posterior: el pepper no debe
    -- sobrevivir a esta llamada. p_confirma_abandono='Y' porque proc_dm_enmascara_tabla
    -- no tiene equivalente a proc_dm_reanudar (cada llamada crea su propio
    -- ejecucion_id nuevo, no hay nada que reanudar sobre este id despues).
    proc_dm_pepper_purgar(l_ejecucion_id, 'Y');
  EXCEPTION
    WHEN OTHERS THEN
      l_err_code  := SQLCODE;
      l_err_stack := func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_STACK);
      l_err_bt    := func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      BEGIN
        IF l_solicitud_id IS NOT NULL THEN
          proc_dm_upd_sol(l_solicitud_id,'ERROR','ERROR','ERROR',l_err_stack,'Y');
        END IF;
        IF l_ejecucion_id IS NOT NULL THEN
          proc_dm_upd_ejec(l_ejecucion_id,'ENMASCARAMIENTO','ERROR',NULL,NULL,NULL,NULL,NULL,NULL,'ERROR');
        END IF;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
      proc_dm_log_ejec_error(
        p_ejecucion_id => l_ejecucion_id,
        p_owner_name   => l_esquema,
        p_table_name   => l_tabla,
        p_column_name  => NULL,
        p_etapa        => 'P_MASK_TAB',
        p_codigo_error => l_err_code,
        p_mensaje      => l_err_stack,
        p_backtrace    => l_err_bt,
        p_solicitud_id => l_solicitud_id
      );
      -- El pepper se purga tambien en fallo: un secreto de ejecución ad-hoc a
      -- medias no debe persistir indefinidamente en tdm_secreto. Confirmado
      -- (mismo motivo que en el camino de exito, ver arriba): sin resume
      -- posible para un ejecucion_id de proc_dm_enmascara_tabla.
      IF l_ejecucion_id IS NOT NULL THEN
        proc_dm_pepper_purgar(l_ejecucion_id, 'Y');
      END IF;
      RAISE;
  END;

END pkg_dm_enmascarar;
/