set define off

Rem ================================================================================
Rem pkg_dm_mask_worker  --  34_dm_pkg_mask_worker.sql
Rem ================================================================================
Rem Tareas DBMS_PARALLEL_EXECUTE: nombre/texto de tarea, UPDATE de una columna (directo o por chunks), reconciliacion de tareas huerfanas.
Rem
Rem Modularizacion 2026-10-10 (R2-R9): rutinas MOVIDAS desde pkg_dm_enmascarar sin cambiar su
Rem logica. Lo unico distinto es el prefijo de paquete en las llamadas a rutinas que viven en
Rem otro paquete. Las firmas y los textos de traza/error no cambian.
Rem ================================================================================

create or replace PACKAGE pkg_dm_mask_worker AS

  FUNCTION func_dm_nombre_tarea(p_owner IN VARCHAR2, p_tabla IN VARCHAR2, p_columna IN VARCHAR2)
    RETURN VARCHAR2;

  FUNCTION func_dm_chunk_sql(p_ejecucion_id IN NUMBER, p_sql_base IN VARCHAR2) RETURN VARCHAR2;

  FUNCTION func_dm_ejecucion_de_sql(p_stmt IN CLOB) RETURN NUMBER;

  FUNCTION func_dm_tabla_tiene_trig_upd(
    p_owner IN VARCHAR2,
    p_tabla IN VARCHAR2
  ) RETURN VARCHAR2;

  PROCEDURE proc_dm_ejecuta_update_seguro(
    p_owner    IN VARCHAR2,
    p_tabla    IN VARCHAR2,
    p_columna  IN VARCHAR2,
    p_sql_base IN VARCHAR2,
    p_ejecucion_id IN NUMBER,
    p_rows_out OUT NUMBER,
    p_ruta_out OUT VARCHAR2
  );

  PROCEDURE proc_dm_gestiona_tareas(
    p_ejecucion_id IN NUMBER,
    p_modo         IN VARCHAR2 DEFAULT 'INFORMAR'
  );

  FUNCTION func_dm_tareas_de_ejecucion(
    p_ejecucion_id IN NUMBER
  ) RETURN VARCHAR2;

  -- R13a: PRE-FLIGHT de tareas huerfanas (extraido de proc_dm_enmascaramiento).
  PROCEDURE proc_dm_preflight_tareas(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_reproceso    IN VARCHAR2
  );

END pkg_dm_mask_worker;
/

create or replace PACKAGE BODY pkg_dm_mask_worker AS


  ------------------------------------------------------------------------------
  -- [DOC] contrato de tarea paralela (nombre y texto), R1c 2026-10-10
  -- PROPOSITO    : Un solo lugar para el nombre determinista de la tarea de una columna y para el
  --                texto SQL que ejecuta cada worker. Antes estaba repetido en 5 sitios (hash) y en
  --                3 (texto del chunk y las dos lecturas con REGEXP).
  --                func_dm_nombre_tarea : 'TDM_'||hash de OWNER.TABLA.COLUMNA (mismo valor que antes).
  --                func_dm_chunk_sql    : texto del chunk; antepone proc_dm_set_ejecucion(<id>).
  --                func_dm_ejecucion_de_sql: lee de vuelta el <id> de ese texto. Las dos ultimas
  --                deben cambiarse JUNTAS: el reconocimiento de tareas vivas de otra ejecucion
  --                depende del formato 'proc_dm_set_ejecucion(<id>)'.
  -- LLAMADO DESDE: Interno: proc_dm_ejecuta_update_seguro, proc_dm_enmascaramiento,
  --                proc_dm_gestiona_tareas, func_dm_tareas_de_ejecucion.
  ------------------------------------------------------------------------------
  FUNCTION func_dm_nombre_tarea(p_owner IN VARCHAR2, p_tabla IN VARCHAR2, p_columna IN VARCHAR2)
    RETURN VARCHAR2 IS
  BEGIN
    RETURN 'TDM_'||TO_CHAR(DBMS_UTILITY.GET_HASH_VALUE(
             UPPER(p_owner)||'.'||UPPER(p_tabla)||'.'||UPPER(p_columna),
             1, 1000000000));
  END;

  FUNCTION func_dm_chunk_sql(p_ejecucion_id IN NUMBER, p_sql_base IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN 'BEGIN pkg_dm_mask_ff1.proc_dm_set_ejecucion('||
           CASE WHEN p_ejecucion_id IS NULL THEN 'NULL' ELSE TO_CHAR(p_ejecucion_id) END||
           '); '||p_sql_base||' AND rowid BETWEEN :start_id AND :end_id; END;';
  END;

  FUNCTION func_dm_ejecucion_de_sql(p_stmt IN CLOB) RETURN NUMBER IS
  BEGIN
    RETURN TO_NUMBER(REGEXP_SUBSTR(DBMS_LOB.SUBSTR(p_stmt, 1000, 1),
             'proc_dm_set_ejecucion\(([0-9]+)\)', 1, 1, 'i', 1));
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
     WHERE table_owner = pkg_dm_sql_seguro.func_dm_norm(p_owner)
       AND table_name  = pkg_dm_sql_seguro.func_dm_norm(p_tabla)
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
  --                p_ejecucion_id (se inyecta a cada worker paralelo para leer su pepper);
  --                p_rows_out OUT (filas, aproximado en ruta paralela);
  --                p_ruta_out OUT (texto de la ruta elegida, para la traza APPLY_COL).
  -- LEE          : DBA_TABLES; DBA_TRIGGERS (via func_dm_tabla_tiene_trig_upd);
  --                USER_PARALLEL_EXECUTE_CHUNKS; DBA_SCHEDULER_JOB_CLASSES; tabla objetivo (COUNT(*)
  --                solo si faltan estadisticas)
  -- ESCRIBE      : UPDATE sobre la tabla/columna objetivo (directo o por chunks de rowid);
  --                DBMS_PARALLEL_EXECUTE: CREATE_TASK, CREATE_CHUNKS_BY_ROWID, RUN_TASK, RESUME_TASK,
  --                DROP_TASK (tarea TDM_<hash>); devuelve la ruta elegida en p_ruta_out
  -- ERRORES      : ORA-20332 p_ejecucion_id nulo (R15, falla cerrado).; ORA-20330 tarea paralela huerfana (ORA-29497 en CREATE_TASK): no reanuda
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
    p_ejecucion_id IN NUMBER,
    p_rows_out OUT NUMBER,
    p_ruta_out OUT VARCHAR2
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
    p_ruta_out := NULL;
    -- R15 (A2 de la revision de Codex): falla cerrado. Sin ejecucion no hay pepper de sesion, y
    -- func_dm_chunk_sql habria emitido proc_dm_set_ejecucion(NULL) en cada chunk.
    IF p_ejecucion_id IS NULL THEN
      RAISE_APPLICATION_ERROR(-20332,
        'proc_dm_ejecuta_update_seguro exige p_ejecucion_id (sin ejecucion no hay semilla de sesion).');
    END IF;
    -- 1. Obtener número aproximado de filas e iot_type de la tabla
    l_stmt_check := 'SELECT num_rows, iot_type FROM dba_tables WHERE owner = :1 AND table_name = :2';
    BEGIN
      EXECUTE IMMEDIATE l_stmt_check INTO l_row_count, l_iot_type USING pkg_dm_sql_seguro.func_dm_norm(p_owner), pkg_dm_sql_seguro.func_dm_norm(p_tabla);
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
        EXECUTE IMMEDIATE 'SELECT /*+ PARALLEL(4) */ COUNT(*) FROM '||pkg_dm_sql_seguro.func_dm_qname(p_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(p_tabla) INTO l_row_count;
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
      l_task_name := func_dm_nombre_tarea(p_owner, p_tabla, p_columna);

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
        table_owner => pkg_dm_sql_seguro.func_dm_norm(p_owner),
        table_name  => pkg_dm_sql_seguro.func_dm_norm(p_tabla),
        by_row      => FALSE,
        chunk_size  => l_chunk_blocks
      );

      -- Construir sentencia SQL para el chunk
      -- Cada worker es una sesion propia: fija su ejecucion_id ANTES del UPDATE
      -- para leer el pepper de la ejecución correcta (el ejec es un literal numerico).
      l_sql_chunk := func_dm_chunk_sql(p_ejecucion_id, p_sql_base);

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
      p_ruta_out := 'CHUNKS [> 100k filas] - filas_estimadas='||l_row_count||', bloques_por_chunk='||l_chunk_blocks||
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
      p_ruta_out := CASE WHEN l_iot_type IS NOT NULL THEN 'UPDATE [tabla IOT: sin chunks]' ELSE 'UPDATE [max 100000 filas]' END||
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

    -- Ejecutores vivos de una tarea: jobs en ejecucion que figuran en sus chunks y cuya sesion
    -- existe y no esta KILLED (mismo criterio que dm_enmascara_cancel / dm_enmascara_reanudar).
    FUNCTION jobs_vivos(p_task IN VARCHAR2) RETURN NUMBER IS
      l_n NUMBER;
    BEGIN
      SELECT COUNT(*) INTO l_n
        FROM dba_scheduler_running_jobs r, gv$session s
       WHERE s.inst_id = r.running_instance
         AND s.sid     = r.session_id
         AND s.status <> 'KILLED'
         AND r.job_name IN (SELECT c.job_name FROM user_parallel_execute_chunks c
                             WHERE c.task_name = p_task AND c.job_name IS NOT NULL);
      RETURN l_n;
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
      l_k   := func_dm_nombre_tarea(l_esquema, f.table_name, f.column_name);
      l_hash_col(l_k) := l_col;
      l_col_hash(l_col) := l_k;
    END LOOP;
    FOR fx IN (
      SELECT pkg_dm_sql_seguro.func_dm_norm(e.table_name)  AS table_name,
             pkg_dm_sql_seguro.func_dm_norm(e.column_name) AS column_name
        FROM tdm_excepcion_col e
       WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = l_esquema
         AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
         AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'FORCE'
         AND e.identificador_forz IS NOT NULL
    ) LOOP
      l_col := fx.table_name||'.'||fx.column_name;
      l_k   := func_dm_nombre_tarea(l_esquema, fx.table_name, fx.column_name);
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
      -- Un job cuya sesion ya esta KILLED sigue unos segundos en dba_scheduler_running_jobs:
      -- no es un ejecutor vivo. En RECONCILIAR sin sesion principal se espera (max. 30 s) a que
      -- los jobs que aun trabajan terminen o desaparezcan antes de clasificar la tarea.
      l_jobs := jobs_vivos(t.task_name);
      IF l_jobs > 0 AND l_modo = 'RECONCILIAR' AND l_viva = 0 THEN
        l_i := 0;
        WHILE l_jobs > 0 AND l_i < 15 LOOP
          espera(2);
          l_i := l_i + 1;
          l_jobs := jobs_vivos(t.task_name);
        END LOOP;
      END IF;

      -- Ejecucion a la que pertenece la tarea: el SQL del chunk lleva el id como literal
      -- (proc_dm_set_ejecucion(<id>)) y con el sale el pepper con el que se cifro.
      l_stmt := NULL; l_lang := NULL; l_ej_tarea := NULL;
      BEGIN
        EXECUTE IMMEDIATE 'SELECT sql_stmt, language_flag FROM user_parallel_execute_tasks WHERE task_name = :1'
          INTO l_stmt, l_lang USING t.task_name;
        l_ej_tarea := func_dm_ejecucion_de_sql(l_stmt);
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
          pkg_dm_trazabilidad.proc_dm_trace(l_solicitud, p_ejecucion_id, 'MASK', 'TAREA_DESCARTADA',
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
            pkg_dm_trazabilidad.proc_dm_trace(l_solicitud, p_ejecucion_id, 'MASK', 'APPLY_COL',
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
        l_ej := func_dm_ejecucion_de_sql(l_stmt);
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
  -- PROCEDIMIENTO: proc_dm_preflight_tareas
  -- PROPOSITO    : Abortar cerrado, ANTES de tocar datos, si existe una tarea
  --                DBMS_PARALLEL_EXECUTE huerfana de una columna que este run enmascararia.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_esquema (esquema objetivo),
  --                p_reproceso ('Y' = reproceso completo; 'N' = se omiten columnas ya confirmadas).
  -- SALIDA       : ninguna; ORA-20331 si hay tareas que bloquean; traza PREFLIGHT_*.
  -- LLAMADO DESDE: pkg_dm_enmascarar.proc_dm_enmascaramiento (antes de proc_dm_pre_dep).
  -- NOTA         : cuerpo movido sin cambios desde proc_dm_enmascaramiento (R13a);
  --                solo cambia proc_dm_trace -> pkg_dm_trazabilidad.proc_dm_trace.
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
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_preflight_tareas(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_reproceso    IN VARCHAR2
  ) IS
    l_solicitud_id NUMBER       := p_solicitud_id;
    l_esquema      VARCHAR2(128) := p_esquema;
    l_reproceso    VARCHAR2(1)   := p_reproceso;
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
        l_mapa(pkg_dm_mask_worker.func_dm_nombre_tarea(l_esquema, f.table_name, f.column_name)) := f.table_name||'.'||f.column_name;
      END LOOP;

      FOR fx IN (
        SELECT pkg_dm_sql_seguro.func_dm_norm(e.table_name)  AS table_name,
               pkg_dm_sql_seguro.func_dm_norm(e.column_name) AS column_name
          FROM tdm_excepcion_col e
         WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = l_esquema
           AND pkg_dm_sql_seguro.func_dm_norm(e.activa)  = 'Y'
           AND pkg_dm_sql_seguro.func_dm_norm(e.accion)  = 'FORCE'
           AND e.identificador_forz IS NOT NULL
      ) LOOP
        l_mapa(pkg_dm_mask_worker.func_dm_nombre_tarea(l_esquema, fx.table_name, fx.column_name)) := fx.table_name||'.'||fx.column_name;
      END LOOP;

      FOR t IN (
        SELECT task_name, status
          FROM user_parallel_execute_tasks
         WHERE task_name LIKE 'TDM\_%' ESCAPE '\'
         ORDER BY task_name
      ) LOOP
        IF NOT l_mapa.EXISTS(t.task_name) THEN
          l_n_info := l_n_info + 1;
          pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PREFLIGHT_INFO',
            'Tarea '||t.task_name||' (estado='||t.status||') no corresponde a ninguna columna objetivo de '||
            l_esquema||' (nombre antiguo o columna fuera de alcance): NO bloquea este run.');
        ELSE
          l_col := l_mapa(t.task_name);

          SELECT COUNT(*) INTO l_n_excl
            FROM tdm_excepcion_col e
           WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = l_esquema
             AND pkg_dm_sql_seguro.func_dm_norm(e.table_name)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.column_name) = l_col
             AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
             AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'EXCLUDE';

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
            pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PREFLIGHT_INFO',
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
            pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PREFLIGHT_ORFANA', l_linea);

            IF LENGTH(l_lineas) IS NULL OR LENGTH(l_lineas) + LENGTH(l_linea) + 4 <= 800 THEN
              l_lineas := l_lineas||CHR(10)||'  - '||l_linea;
            END IF;
          END IF;
        END IF;
      END LOOP;

      IF l_n_bloq > 0 THEN
        pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PREFLIGHT_ABORT',
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

      pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id, p_ejecucion_id, 'MASK', 'PREFLIGHT_OK',
        'Sin tareas huerfanas que bloqueen (informativas: '||(l_n_info + l_n_omit)||').');
  END proc_dm_preflight_tareas;

END pkg_dm_mask_worker;
/
