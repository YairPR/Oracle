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
Rem 2026-10-10 (Modularizacion R1) Costuras antes de cortar el paquete, sin cambio de comportamiento:
Rem                            R1a g_ruta deja de ser variable global: proc_dm_ejecuta_update_seguro la devuelve
Rem                            en p_ruta_out y proc_dm_apl_col la traza. R1b g_ejec_actual eliminada: la
Rem                            ejecucion se pasa como p_ejecucion_id a proc_dm_ejecuta_update_seguro (el worker
Rem                            ya no puede recibir proc_dm_set_ejecucion(NULL)). R1c nombre de tarea y texto del
Rem                            chunk en func_dm_nombre_tarea / func_dm_chunk_sql / func_dm_ejecucion_de_sql (mismo
Rem                            hash y mismo texto que antes). pkg_dm_func_mask pasa a llamarse pkg_dm_mask_ff1.
Rem 2026-10-10 (Resumen) MASK/RESUMEN agrega 'columnas omitidas=N' (conteo de SKIP_AUTO_LEN de la ejecucion).
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

Rem
Rem    epurisaca    10/10/26 - R13: proc_dm_enmascaramiento delega el preflight en
Rem                           pkg_dm_mask_worker.proc_dm_preflight_tareas y el control posterior en
Rem                           pkg_dm_mask_dependencias.proc_dm_post_check; proc_dm_mask_cat delega el
Rem                           conteo, la traza de tablas omitidas y el bucle por columna en
Rem                           pkg_dm_mask_columna. Cuerpos movidos sin cambios.
Rem
Rem    epurisaca    10/10/26 - R15: se retira la variable de paquete g_resume_base_solicitud (estado de
Rem                           sesion). La solicitud previa de una reanudacion viaja como parametro
Rem                           p_base_solicitud_id: proc_dm_reanudar -> proc_dm_enmascaramiento_core ->
Rem                           proc_dm_mask_cat. proc_dm_enmascaramiento (publico) pasa a ser un
Rem                           envoltorio con la misma firma y defaults. Tipos nuevos de R13: t_dm_*.

create or replace PACKAGE pkg_dm_enmascarar AS

  FUNCTION func_dm_norm(
    p_txt IN VARCHAR2
  ) RETURN VARCHAR2 DETERMINISTIC;

-- (reglas especiales muertas eliminadas: se usan pkg_dm_mask_ff1.func_especial_*)

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

END pkg_dm_enmascarar;
/

create or replace PACKAGE BODY pkg_dm_enmascarar AS


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
    p_base_solicitud_id IN NUMBER DEFAULT NULL,   -- R15: solicitud previa si es reanudacion (antes g_resume_base_solicitud)
    p_error_count  OUT NUMBER
  ) IS
    l_total_cols NUMBER;
    l_total_tabs NUMBER;
    l_av         pkg_dm_mask_columna.t_dm_avance;
    l_esquema    VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_reproceso  VARCHAR2(1) := UPPER(TRIM(NVL(p_reproceso,'N')));
    l_msg_noop   VARCHAR2(1900);
    l_total_rows NUMBER := 0;
    l_omitidas   NUMBER := 0;   -- columnas sensibles omitidas por longitud (SKIP_AUTO_LEN)
    l_has_final  NUMBER := 0;
  BEGIN
    p_error_count := 0;

    pkg_dm_mask_columna.proc_dm_cuenta_pendientes(p_ejecucion_id, l_esquema, l_reproceso, l_has_final, l_total_cols, l_total_tabs);
    l_av.total_cols := l_total_cols;
    l_av.total_tabs := l_total_tabs;

    -- Reanudacion visible: una linea en la traza (ligada a la NUEVA solicitud) y la marca en
    -- TDM_EJECUCION (ultimo_paso y detalle), con cuantas columnas se omiten y cuantas quedan.
    IF p_base_solicitud_id IS NOT NULL THEN
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
                 TO_CHAR(p_solicitud_id)||' desde solicitud_id='||TO_CHAR(p_base_solicitud_id)||
                 '): columnas ya confirmadas='||TO_CHAR(l_conf)||', pendientes='||TO_CHAR(l_total_cols);
        pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'ENMASCARAMIENTO','REANUDACION',l_txt);
        pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'REANUDACION',l_txt);
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

      pkg_dm_trazabilidad.proc_dm_trace(
        p_solicitud_id,
        p_ejecucion_id,
        'MASK',
        'NOOP',
        l_msg_noop
      );
      pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','FINALIZADO',100,0,0,0,0,NULL,'NOOP_MASK');
      RETURN;
    END IF;

    IF l_has_final = 1 THEN
      pkg_dm_mask_columna.proc_dm_traza_tablas_omitidas(p_solicitud_id, p_ejecucion_id, l_esquema);
    END IF;

    pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',0,l_total_tabs,0,l_total_cols,0,NULL,'INICIO_MASK');

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
              SELECT pkg_dm_sql_seguro.func_dm_norm(e.ora_owner), pkg_dm_sql_seguro.func_dm_norm(e.table_name), pkg_dm_sql_seguro.func_dm_norm(e.column_name), e.identificador_forz, 1 AS origen
                FROM tdm_excepcion_col e
               WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = l_esquema
                 AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
                 AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'FORCE'
                 AND e.identificador_forz IS NOT NULL
                 AND EXISTS (
                       SELECT 1 FROM dba_tab_columns c
                        WHERE c.owner = pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)
                          AND c.table_name = pkg_dm_sql_seguro.func_dm_norm(e.table_name)
                          AND c.column_name = pkg_dm_sql_seguro.func_dm_norm(e.column_name)
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
              WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = f.ora_owner
                AND e.table_name = f.table_name
                AND e.column_name = f.column_name
                AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
                AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'EXCLUDE'
           )
         ORDER BY ora_owner, table_name, column_name
      ) LOOP
        pkg_dm_mask_columna.proc_dm_mask_una_col(p_solicitud_id, p_ejecucion_id, p_esquema,
          rc.ora_owner, rc.table_name, rc.column_name, rc.identificador, l_av);
      END LOOP;
    ELSE
      FOR rc IN (
        SELECT pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) as ora_owner, pkg_dm_sql_seguro.func_dm_norm(e.table_name) as table_name,
               pkg_dm_sql_seguro.func_dm_norm(e.column_name) as column_name, e.identificador_forz as identificador
          FROM tdm_excepcion_col e
         WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = l_esquema
           AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
           AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'FORCE'
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
                  AND t.detalle LIKE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.table_name)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.column_name)||' filas=%'
             )
           )
           AND EXISTS (
             SELECT 1 FROM dba_tab_columns c
              WHERE c.owner = pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)
                AND c.table_name = pkg_dm_sql_seguro.func_dm_norm(e.table_name)
                AND c.column_name = pkg_dm_sql_seguro.func_dm_norm(e.column_name)
           )
         ORDER BY ora_owner, table_name, column_name
      ) LOOP
        pkg_dm_mask_columna.proc_dm_mask_una_col(p_solicitud_id, p_ejecucion_id, p_esquema,
          rc.ora_owner, rc.table_name, rc.column_name, rc.identificador, l_av);
      END LOOP;
    END IF;

    p_error_count := l_av.errores;

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

    -- Columnas omitidas: apl_col las cuenta como procesadas pero NO las enmascara (columna mas corta
    -- que el minimo del identificador, WARN SKIP_AUTO_LEN). Se cuentan por ejecucion en la traza
    -- para que sumen tambien tras una reanudacion (que abre otra solicitud).
    BEGIN
      SELECT COUNT(*) INTO l_omitidas
        FROM tdm_mask_trace t
       WHERE t.ejecucion_id = p_ejecucion_id
         AND t.fase = 'MASK'
         AND t.paso = 'SKIP_AUTO_LEN';
    EXCEPTION
      WHEN OTHERS THEN
        l_omitidas := 0;
    END;

    pkg_dm_trazabilidad.proc_dm_trace(
      p_solicitud_id,
      p_ejecucion_id,
      'MASK',
      'RESUMEN',
      'Columnas procesadas='||TO_CHAR(l_av.proc_cols)||
      ', columnas omitidas='||TO_CHAR(l_omitidas)||' (SKIP_AUTO_LEN: sin enmascarar, ver WARN)'||
      ', columnas fallidas='||TO_CHAR(l_av.cols_fallidas)||
      ', tablas procesadas='||TO_CHAR(l_av.proc_tabs)||
      ', total_registros_afectados='||TO_CHAR(NVL(l_total_rows,0))
    );

    BEGIN
      UPDATE tdm_mask_solicitud
         SET filas_procesadas     = NVL(l_total_rows,0),
             tablas_procesadas    = l_av.proc_tabs,
             columnas_procesadas  = l_av.proc_cols
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
  -- [DOC] procedure proc_dm_enmascaramiento_core  (privado; antes proc_dm_enmascaramiento)
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
  -- LLAMADO DESDE: Interno: el envoltorio publico proc_dm_enmascaramiento (arranque) y
  --                proc_dm_reanudar (reanudacion, con p_base_solicitud_id).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_enmascaramiento_core(
    p_ejecucion_id IN NUMBER,
    p_reproceso    IN VARCHAR2 DEFAULT 'N',
    p_commit_lote  IN NUMBER DEFAULT 1000,
    p_base_solicitud_id IN NUMBER DEFAULT NULL    -- R15: solicitud previa si es reanudacion (antes g_resume_base_solicitud)
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
  BEGIN
    pkg_dm_mask_validacion.proc_dm_validar_base;
    DBMS_APPLICATION_INFO.SET_MODULE('PKG_DM_ENMASCARAR','P_DM_ENMASCARA');
    pkg_dm_mask_estado.proc_dm_close_sol_open(p_ejecucion_id);
    pkg_dm_trazabilidad.proc_dm_refresca_sesion(p_ejecucion_id);

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

    l_esquema := pkg_dm_mask_estado.func_dm_esquema(p_ejecucion_id);

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
    pkg_dm_mask_validacion.proc_dm_validar_reingreso_mask(p_ejecucion_id,l_esquema,l_reproceso);
    pkg_dm_mask_validacion.proc_dm_validar_concurrencia(p_ejecucion_id,l_esquema);

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
    -- proc_dm_reanudar, p_base_solicitud_id no nulo) de una de arranque
    -- normal -- antes usaba el mismo texto fijo ('Enmascaramiento final;
    -- rollback via import', residuo sin relacion aparente con este flujo)
    -- para ambos casos, asi que TDM_MASK_SOLICITUD.DETALLE tampoco distinguia
    -- una reanudacion de un arranque normal (solo reintento_nro>1 lo insinuaba).
    l_solicitud_id := pkg_dm_mask_estado.func_dm_crea_sol(
      p_ejecucion_id      => p_ejecucion_id,
      p_esquema           => l_esquema,
      p_detalle           => CASE
                                WHEN p_base_solicitud_id IS NOT NULL THEN
                                  'Reanudacion de ejecucion_id='||p_ejecucion_id||
                                  ' desde solicitud_id='||TO_CHAR(p_base_solicitud_id)
                                ELSE
                                  'Enmascaramiento final'
                              END,
      p_forzar_reproceso  => l_reproceso
    );
    -- Sesion Oracle y cancelacion de la corrida viven solo en TDM_EJECUCION
    -- (proc_dm_refresca_sesion y el reset de cancel_requested al arrancar).

    pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,p_ejecucion_id,'ENMASCARAMIENTO','INICIO',
      'Esquema='||l_esquema||
      CASE WHEN p_base_solicitud_id IS NOT NULL
           THEN ' - REANUDACION desde solicitud_id='||TO_CHAR(p_base_solicitud_id) END);
    -- TDM_EJECUCION debe decir desde el primer segundo si esta corrida es una reanudacion
    -- (antes de pre-flight, dependencias y pepper, que pueden tardar). El detalle se reescribe
    -- siempre al arrancar, para que un texto de una reanudacion anterior no quede como si fuera
    -- el modo actual. proc_dm_mask_cat lo completa con las columnas confirmadas y pendientes.
    pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',0,NULL,NULL,NULL,NULL,l_esquema,
      CASE WHEN p_base_solicitud_id IS NOT NULL THEN 'REANUDACION' ELSE 'INICIO' END,
      CASE WHEN p_base_solicitud_id IS NOT NULL
           THEN 'Reanudacion en curso (solicitud_id='||TO_CHAR(l_solicitud_id)||' desde solicitud_id='||
                TO_CHAR(p_base_solicitud_id)||'): calculando columnas pendientes'
           ELSE 'Enmascaramiento en curso (solicitud_id='||TO_CHAR(l_solicitud_id)||')'
      END);

    -- PRE-FLIGHT de tareas huerfanas: ver pkg_dm_mask_worker.proc_dm_preflight_tareas (R13a).
    pkg_dm_mask_worker.proc_dm_preflight_tareas(l_solicitud_id, p_ejecucion_id, l_esquema, l_reproceso);

    pkg_dm_mask_dependencias.proc_dm_pre_dep(l_solicitud_id,p_ejecucion_id,l_esquema);

    -- A.1: Re-propagar dominios referenciales con la validación final del cliente antes de enmascarar
    --
    -- Fail-open corregido (auditoria 2026-09-16): este bloque solo trazaba el
    -- error y dejaba que el flujo siguiera hacia pepper y masking aunque la
    -- propagacion de dominios FK hubiera fallado por completo. La garantia
    -- de integridad referencial es tan  como el pepper (que si hace
    -- RAISE unas lineas mas abajo) - un fallo aqui debe abortar la ejecución,
    -- no continuar en silencio con dominios FK potencialmente inconsistentes.
    BEGIN
      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_START', 'Recalculando dominios FK con la validacion del cliente');
      pkg_dm_dominios.proc_dm_propaga_dominios(l_esquema, l_solicitud_id, p_ejecucion_id);
      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_END', 'Dominios FK propagados con exito');
    EXCEPTION
      WHEN OTHERS THEN
        pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'PROPAGACION', 'PROPAGA_ERR', 'Error en propagacion referencial: '||SQLERRM);
        RAISE;   -- sin propagacion valida no se puede garantizar la integridad FK
    END;

    -- Generar la semilla efimera (pepper) ANTES de enmascarar. Idempotente y con
    -- COMMIT propio para que las sesiones paralelas lean la misma clave AES (FF1).
    BEGIN
      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PEPPER_START', 'Preparando semilla efimera.');
      pkg_dm_pepper.proc_dm_pepper_generar(p_ejecucion_id);
      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PEPPER_END', 'Semilla efimera lista.');
    EXCEPTION
      WHEN OTHERS THEN
        pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PEPPER_ERR', 'Error preparando semilla: '||SQLERRM);
        RAISE;   -- sin pepper no se puede enmascarar de forma segura
    END;

    BEGIN
      proc_dm_mask_cat(l_solicitud_id,p_ejecucion_id,l_esquema,l_reproceso,p_base_solicitud_id,l_mask_errors);
    EXCEPTION
      WHEN OTHERS THEN
        l_mask_errors := l_mask_errors + 1;
        pkg_dm_trazabilidad.proc_dm_log_ejec_error(p_ejecucion_id, l_esquema, NULL, NULL, 'MASK_CAT', SQLCODE, SQLERRM, NULL, l_solicitud_id);
    END;

    BEGIN
      pkg_dm_mask_sync.proc_dm_post_sync(l_solicitud_id,p_ejecucion_id,l_esquema);
    EXCEPTION
      WHEN OTHERS THEN
        l_mask_errors := l_mask_errors + 1;
        pkg_dm_trazabilidad.proc_dm_log_ejec_error(p_ejecucion_id, l_esquema, NULL, NULL, 'POST_SYNC', SQLCODE, SQLERRM, NULL, l_solicitud_id);
    END;

    pkg_dm_mask_dependencias.proc_dm_post_dep(l_solicitud_id,p_ejecucion_id);

    -- B.3: control posterior (constraints, recompilacion, INVALID nuevos, PII sin enmascarar): R13a
    pkg_dm_mask_dependencias.proc_dm_post_check(l_solicitud_id, p_ejecucion_id, l_esquema, l_invalidos_pre, l_mask_errors);

    IF l_mask_errors > 0 THEN
      pkg_dm_mask_estado.proc_dm_upd_sol(l_solicitud_id,'ERROR','FIN','ERROR','Proceso finalizado con '||l_mask_errors||' errores','Y');
      pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','ERROR',100,NULL,NULL,NULL,NULL,NULL,'CON_ERRORES');
      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','ERROR','Enmascaramiento finalizado con '||l_mask_errors||' errores');
    ELSE
      pkg_dm_mask_estado.proc_dm_upd_sol(l_solicitud_id,'FINALIZADO','FIN','FINALIZADO','Proceso finalizado correctamente','Y');
      pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','FINALIZADO',100,NULL,NULL,NULL,NULL,NULL,'FINALIZADO');
      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','OK','Enmascaramiento finalizado');

      -- 2026-09-27: autopurga del pepper efimero SOLO en FINALIZADO sin
      -- errores. Ni la validacion (paso 5 del runbook) ni el export (paso 6,
      -- pkg_dm_export/07, adicional y fuera del flujo critico) leen el
      -- pepper, asi que no hay razon para conservarlo mas alla de este punto
      -- -- ver guarda de estado en proc_dm_pepper_purgar. Best-effort: si la
      -- purga falla no debe tumbar un enmascarado ya finalizado con exito.
      BEGIN
        pkg_dm_pepper.proc_dm_pepper_purgar(p_ejecucion_id);
      EXCEPTION
        WHEN OTHERS THEN
          pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','PEPPER_PURGE_WARN',
            'Enmascaramiento FINALIZADO pero no se pudo autopurgar el pepper: '||SQLERRM||
            ' -- purgar manualmente con proc_dm_pepper_purgar('||p_ejecucion_id||').');
      END;
    END IF;

    DBMS_APPLICATION_INFO.SET_MODULE(NULL,NULL);
  EXCEPTION
    WHEN OTHERS THEN
      l_err_code := SQLCODE;
      l_err_stack := pkg_dm_sql_seguro.func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_STACK);
      l_err_bt    := pkg_dm_sql_seguro.func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      l_err_call  := pkg_dm_sql_seguro.func_dm_safe_err(DBMS_UTILITY.FORMAT_CALL_STACK);
      l_err := '['||TO_CHAR(l_err_code)||'] '||l_err_stack||' | BT='||l_err_bt;
      BEGIN
        IF l_solicitud_id IS NOT NULL THEN
          pkg_dm_mask_dependencias.proc_dm_post_dep(l_solicitud_id,p_ejecucion_id);
          pkg_dm_mask_estado.proc_dm_upd_sol(l_solicitud_id,
                          CASE WHEN l_err_code = -20081 THEN 'CANCELADO' ELSE 'ERROR' END,
                          'ERROR','ERROR',l_err,'Y');
        END IF;
      EXCEPTION WHEN OTHERS THEN
        -- 2026-10-10 (auditoria industrial G8): si el cierre de estado falla, el fallo
        -- ya no queda mudo; se deja en la traza (autonoma) sin ocultar el error original.
        BEGIN
          pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','ESTADO_FINAL_WARN',
            'No se pudo registrar el estado final tras el error: '||SUBSTR(SQLERRM,1,400));
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
      END;

      pkg_dm_trazabilidad.proc_dm_log_ejec_error(
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

      pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO',CASE WHEN l_err_code = -20081 THEN 'CANCELADO' ELSE 'ERROR' END,
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
  -- [DOC] procedure proc_dm_enmascaramiento  (publico; envoltorio del nucleo)
  -- PROPOSITO    : Punto de entrada publico del enmascarado. Conserva firma, defaults y errores;
  --                delega todo en proc_dm_enmascaramiento_core con p_base_solicitud_id nulo (arranque
  --                normal). Solo proc_dm_reanudar llama al nucleo con la solicitud previa.
  -- ENTRADAS     : las del nucleo (ver su [DOC]).
  -- ERRORES      : los del nucleo.
  -- LLAMADO DESDE: Externo/script: dm_enmascara.sql, dm_enmascara_id.sql.
  -- R15          : sustituye a la variable de paquete g_resume_base_solicitud (estado de sesion que
  --                se escribia en proc_dm_reanudar y se leia en el nucleo y en proc_dm_mask_cat).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_enmascaramiento(
    p_ejecucion_id IN NUMBER,
    p_reproceso    IN VARCHAR2 DEFAULT 'N',
    p_commit_lote  IN NUMBER DEFAULT 1000
  ) IS
  BEGIN
    proc_dm_enmascaramiento_core(p_ejecucion_id, p_reproceso, p_commit_lote, NULL);
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
  -- [DOC] procedure proc_dm_reanudar
  -- PROPOSITO    : Reanuda un enmascarado interrumpido sobre la misma ejecucion_id, tras verificar
  --                fase correcta y sesion original muerta, saltando las columnas ya confirmadas.
  -- ENTRADAS     : p_ejecucion_id; p_commit_lote (solo se reenvia).
  -- LEE          : TDM_EJECUCION (SELECT FOR UPDATE); TDM_MASK_SOLICITUD; GV$SESSION (via
  --                pkg_dm_trazabilidad.func_dm_sesion_viva)
  -- ESCRIBE      : nada propio; pasa la solicitud previa como parametro al nucleo (R15, ya no hay
  --                variable de paquete); todo lo que escribe proc_dm_enmascaramiento_core (p_reproceso = N)
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
    -- pkg_dm_trazabilidad.func_dm_sesion_viva (10), pero SIN el "IF
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
    proc_dm_enmascaramiento_core(p_ejecucion_id => p_ejecucion_id, p_reproceso => 'N',
                                 p_commit_lote => p_commit_lote, p_base_solicitud_id => l_prev_solicitud);
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
    l_esquema      VARCHAR2(128) := pkg_dm_sql_seguro.func_dm_norm(p_esquema);
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
    pkg_dm_mask_validacion.proc_dm_validar_base;

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
    pkg_dm_mask_validacion.proc_dm_validar_concurrencia(l_ejecucion_id, l_esquema);

    UPDATE tdm_ejecucion
       SET estado = 'EJECUTANDO', heartbeat_ts = SYSTIMESTAMP
     WHERE ejecucion_id = l_ejecucion_id;
    COMMIT;   -- visible para los workers paralelos antes de generar el pepper

    pkg_dm_pepper.proc_dm_pepper_generar(l_ejecucion_id);
    l_solicitud_id := pkg_dm_mask_estado.func_dm_crea_sol(l_ejecucion_id,l_esquema,'Enmascaramiento selectivo (proc_dm_enmascara_tabla)');

    -- FIX 2026-09-27 (Nivel 1 #5): se pasa p_tabla para acotar las dependencias
    -- deshabilitadas SOLO a las tablas que esta llamada va a enmascarar (ver
    -- comentario de proc_dm_pre_dep). proc_dm_enmascaramiento sigue sin pasar este
    -- parametro (comportamiento de esquema completo, intacto).
    pkg_dm_mask_dependencias.proc_dm_pre_dep(l_solicitud_id,l_ejecucion_id,l_esquema,p_tabla);

    LOOP
      l_tabla := pkg_dm_sql_seguro.func_dm_csv_item(p_tabla, l_idx);
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
         WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = l_esquema
           AND e.table_name = l_tabla
           AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
           AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'EXCLUDE';

        IF l_cols_total > 0 AND l_cols_excl >= l_cols_total THEN
          pkg_dm_trazabilidad.proc_dm_trace(
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
          l_columna := pkg_dm_sql_seguro.func_dm_csv_item(p_columna, l_col_idx);
          EXIT WHEN l_columna IS NULL;
          pkg_dm_mask_columna.proc_dm_apl_col(l_solicitud_id,l_ejecucion_id,l_esquema,l_esquema,l_tabla,l_columna,p_identificador);
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
          pkg_dm_mask_columna.proc_dm_apl_col(l_solicitud_id,l_ejecucion_id,l_esquema,l_esquema,l_tabla,rc.column_name,p_identificador);
        END LOOP;
      END IF;

      l_idx := l_idx + 1;
    END LOOP;

    pkg_dm_mask_sync.proc_dm_post_sync(l_solicitud_id,l_ejecucion_id,l_esquema);
    pkg_dm_mask_dependencias.proc_dm_post_dep(l_solicitud_id,l_ejecucion_id);
    pkg_dm_mask_estado.proc_dm_upd_sol(l_solicitud_id,'FINALIZADO','FIN','FINALIZADO','Enmascaramiento selectivo finalizado','Y');
    pkg_dm_mask_estado.proc_dm_upd_ejec(l_ejecucion_id,'ENMASCARAMIENTO','FINALIZADO',100,NULL,NULL,NULL,NULL,NULL,'FINALIZADO');

    -- Ejecucion ad-hoc sin fase de export posterior: el pepper no debe
    -- sobrevivir a esta llamada. p_confirma_abandono='Y' porque proc_dm_enmascara_tabla
    -- no tiene equivalente a proc_dm_reanudar (cada llamada crea su propio
    -- ejecucion_id nuevo, no hay nada que reanudar sobre este id despues).
    pkg_dm_pepper.proc_dm_pepper_purgar(l_ejecucion_id, 'Y');
  EXCEPTION
    WHEN OTHERS THEN
      l_err_code  := SQLCODE;
      l_err_stack := pkg_dm_sql_seguro.func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_STACK);
      l_err_bt    := pkg_dm_sql_seguro.func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      BEGIN
        IF l_solicitud_id IS NOT NULL THEN
          pkg_dm_mask_estado.proc_dm_upd_sol(l_solicitud_id,'ERROR','ERROR','ERROR',l_err_stack,'Y');
        END IF;
        IF l_ejecucion_id IS NOT NULL THEN
          pkg_dm_mask_estado.proc_dm_upd_ejec(l_ejecucion_id,'ENMASCARAMIENTO','ERROR',NULL,NULL,NULL,NULL,NULL,NULL,'ERROR');
        END IF;
      EXCEPTION WHEN OTHERS THEN
        -- 2026-10-10 (auditoria industrial G8): el fallo al cerrar el estado queda en la traza.
        BEGIN
          pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,l_ejecucion_id,'FIN','ESTADO_FINAL_WARN',
            'No se pudo registrar el estado final tras el error: '||SUBSTR(SQLERRM,1,400));
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
      END;
      pkg_dm_trazabilidad.proc_dm_log_ejec_error(
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
        pkg_dm_pepper.proc_dm_pepper_purgar(l_ejecucion_id, 'Y');
      END IF;
      RAISE;
  END;
  -- Reenvio de compatibilidad (modularizacion 2026-10-10): la logica vive en pkg_dm_sql_seguro.
  FUNCTION func_dm_norm(p_txt IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    RETURN pkg_dm_sql_seguro.func_dm_norm(p_txt);
  END;

  -- Reenvio de compatibilidad (modularizacion 2026-10-10): la logica vive en pkg_dm_pepper.
  PROCEDURE proc_dm_pepper_purgar(
    p_ejecucion_id      IN NUMBER,
    p_confirma_abandono IN VARCHAR2 DEFAULT 'N'
  ) IS
  BEGIN
    pkg_dm_pepper.proc_dm_pepper_purgar(p_ejecucion_id, p_confirma_abandono);
  END;

  -- Reenvio de compatibilidad (modularizacion 2026-10-10): la logica vive en pkg_dm_mask_worker.
  PROCEDURE proc_dm_gestiona_tareas(
    p_ejecucion_id IN NUMBER,
    p_modo         IN VARCHAR2 DEFAULT 'INFORMAR'
  ) IS
  BEGIN
    pkg_dm_mask_worker.proc_dm_gestiona_tareas(p_ejecucion_id, p_modo);
  END;

  -- Reenvio de compatibilidad (modularizacion 2026-10-10): la logica vive en pkg_dm_mask_worker.
  FUNCTION func_dm_tareas_de_ejecucion(
    p_ejecucion_id IN NUMBER
  ) RETURN VARCHAR2 IS
  BEGIN
    RETURN pkg_dm_mask_worker.func_dm_tareas_de_ejecucion(p_ejecucion_id);
  END;


END pkg_dm_enmascarar;
/
