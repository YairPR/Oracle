set define off

Rem ================================================================================
Rem pkg_dm_mask_columna  --  35_dm_pkg_mask_columna.sql
Rem ================================================================================
Rem Decidir la funcion de enmascarado de una columna y aplicarla (checkpoint APPLY_COL).
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    10/10/26 - Rutinas movidas desde pkg_dm_enmascarar sin cambiar su logica
Rem    epurisaca    10/10/26 - La correspondencia identificador -> clase se toma de
Rem                           pkg_dm_mask_ff1.func_dm_clase_identificador
Rem    epurisaca    10/12/26 - Guarda de IBAN sin espacios (REPLACE) como func_dm_iban; aviso UNICIDAD_RIESGO
Rem    epurisaca    10/12/26 - Verifica que el punto de control APPLY_COL quede escrito (reintento y ORA-20215 +
Rem                           CHECKPOINT_PERDIDO): la traza es autonoma y no propaga su fallo
Rem    epurisaca    10/12/26 - Se retira APPLY_COL_COLLISION de las listas de pasos confirmados
Rem ================================================================================

create or replace PACKAGE pkg_dm_mask_columna AS

  FUNCTION func_dm_tiene_regla(
    p_esquema IN VARCHAR2,
    p_owner   IN VARCHAR2,
    p_tabla   IN VARCHAR2,
    p_columna IN VARCHAR2,
    p_tipo    IN VARCHAR2
  ) RETURN NUMBER;

  FUNCTION func_dm_val_regla(
    p_esquema IN VARCHAR2,
    p_owner   IN VARCHAR2,
    p_tabla   IN VARCHAR2,
    p_columna IN VARCHAR2,
    p_tipo    IN VARCHAR2
  ) RETURN VARCHAR2;

  FUNCTION func_dm_expr_gen_sql(
    p_identificador IN VARCHAR2,
    p_col_expr      IN VARCHAR2
  ) RETURN VARCHAR2;

  FUNCTION func_dm_expr_compatible(
    p_owner         IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_columna       IN VARCHAR2,
    p_identificador IN VARCHAR2
  ) RETURN VARCHAR2;

  FUNCTION func_dm_min_len_identificador(p_identificador IN VARCHAR2) RETURN NUMBER DETERMINISTIC;

  PROCEDURE proc_dm_upsert_excepcion_col(
    p_owner         IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_columna       IN VARCHAR2,
    p_accion        IN VARCHAR2,
    p_ident_forz    IN VARCHAR2,
    p_razon         IN VARCHAR2
  );

  PROCEDURE proc_dm_get_excepcion(
    p_owner         IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_columna       IN VARCHAR2,
    p_accion        OUT VARCHAR2,
    p_ident_forzado OUT VARCHAR2
  );

  PROCEDURE proc_dm_apl_col(
    p_solicitud_id  IN NUMBER,
    p_ejecucion_id  IN NUMBER,
    p_esquema       IN VARCHAR2,
    p_owner         IN VARCHAR2,
    p_tabla         IN VARCHAR2,
    p_columna       IN VARCHAR2,
    p_identificador IN VARCHAR2
  );

  -- Avance de un run de enmascarado (contadores que comparten proc_dm_mask_cat y proc_dm_mask_una_col).
  TYPE t_dm_avance IS RECORD (
    total_cols    NUMBER := 0,
    total_tabs    NUMBER := 0,
    proc_cols     NUMBER := 0,
    proc_tabs     NUMBER := 0,
    cols_fallidas NUMBER := 0,
    errores       NUMBER := 0,
    last_tab      VARCHAR2(128)
  );

  PROCEDURE proc_dm_cuenta_pendientes(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_reproceso    IN VARCHAR2,
    o_has_final    OUT NUMBER,
    o_total_cols   OUT NUMBER,
    o_total_tabs   OUT NUMBER
  );

  PROCEDURE proc_dm_traza_tablas_omitidas(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  );

  PROCEDURE proc_dm_mask_una_col(
    p_solicitud_id  IN NUMBER,
    p_ejecucion_id  IN NUMBER,
    p_esquema       IN VARCHAR2,
    p_ora_owner     IN VARCHAR2,
    p_table_name    IN VARCHAR2,
    p_column_name   IN VARCHAR2,
    p_identificador IN VARCHAR2,
    p_av            IN OUT t_dm_avance
  );

  PROCEDURE proc_dm_preflight_tipos(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  );

END pkg_dm_mask_columna;
/

create or replace PACKAGE BODY pkg_dm_mask_columna AS


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
    -- Fail-closed: un COUNT(*) sobre una tabla propia solo falla por un problema real; devolver 0
    -- haria parecer que no hay regla especial y caeria al tratamiento generico sin avisar.
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
  --                enmascarado de pkg_dm_mask_ff1 que le corresponde.
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
    -- La correspondencia identificador -> clase vive en pkg_dm_mask_ff1.func_dm_clase_identificador.
    l_cls VARCHAR2(20) := pkg_dm_mask_ff1.func_dm_clase_identificador(p_identificador);
  BEGIN
    CASE l_cls
      WHEN 'NOMBRE'    THEN RETURN 'pkg_dm_mask_ff1.func_dm_nombre('||p_col_expr||')';
      WHEN 'DIRECCION' THEN RETURN 'pkg_dm_mask_ff1.func_dm_direccion('||p_col_expr||')';
      WHEN 'TELEFONO'  THEN RETURN 'pkg_dm_mask_ff1.func_dm_telefono('||p_col_expr||')';
      WHEN 'EMAIL'     THEN RETURN 'pkg_dm_mask_ff1.func_dm_email('||p_col_expr||')';
      WHEN 'IDENTIDAD' THEN RETURN 'pkg_dm_mask_ff1.func_dm_nif('||p_col_expr||')';
      WHEN 'BANCARIO'  THEN
        RETURN 'CASE WHEN REGEXP_LIKE(REPLACE(UPPER(TRIM('||p_col_expr||')), '' '', ''''), ''^ES[0-9]{22}$'') '||
               'THEN pkg_dm_mask_ff1.func_dm_iban('||p_col_expr||') '||
               'ELSE pkg_dm_mask_ff1.func_dm_cuenta('||p_col_expr||') END';
      ELSE
        RETURN 'pkg_dm_mask_ff1.func_dm_obs('||p_col_expr||')';
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
    l_col       VARCHAR2(4000) := pkg_dm_sql_seguro.func_dm_qname(p_columna);
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
      -- Envolver en SUBSTR con longitud de fallback prudente ante fallo de consulta de metadatos
      RETURN 'SUBSTR('||func_dm_expr_gen_sql(p_identificador, l_col)||',1,4000)';
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
    l_cls VARCHAR2(20) := pkg_dm_mask_ff1.func_dm_clase_identificador(p_identificador);
  BEGIN
    CASE l_cls
      WHEN 'IDENTIDAD' THEN RETURN 8; -- DNI/NIF/NIE mínimo útil
      WHEN 'TELEFONO'  THEN RETURN 7;
      WHEN 'EMAIL'     THEN RETURN 5; -- a@b.c
      WHEN 'BANCARIO'  THEN RETURN 10;
      WHEN 'NOMBRE'    THEN RETURN 2;
      WHEN 'DIRECCION' THEN RETURN 3;
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
  -- Sin EXCEPTION propio: si el MERGE falla el error debe llegar al DBA, no ocultarse.
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
  -- LLAMADO DESDE: Interno: proc_dm_mask_una_col (via proc_dm_mask_cat).
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
    l_ruta     VARCHAR2(400);   -- traza: ruta elegida por proc_dm_ejecuta_update_seguro (antes variable global g_ruta)
    l_owner    VARCHAR2(128) := UPPER(TRIM(p_owner));
    l_tabla    VARCHAR2(128) := UPPER(TRIM(p_tabla));
    l_columna  VARCHAR2(128) := UPPER(TRIM(p_columna));
    l_t0       TIMESTAMP WITH TIME ZONE := SYSTIMESTAMP;   -- traza: duracion de la columna
  BEGIN
    l_target := pkg_dm_sql_seguro.func_dm_norm(p_owner)||'.'||pkg_dm_sql_seguro.func_dm_norm(p_tabla)||'.'||pkg_dm_sql_seguro.func_dm_norm(p_columna);
    l_ident_final := pkg_dm_sql_seguro.func_dm_norm(p_identificador);

    proc_dm_get_excepcion(p_owner,p_tabla,p_columna,l_accion,l_ident_forzado);
    IF l_ident_forzado IS NOT NULL THEN
      l_ident_final := pkg_dm_sql_seguro.func_dm_norm(l_ident_forzado);
      pkg_dm_trazabilidad.proc_dm_trace(
        p_solicitud_id,
        p_ejecucion_id,
        'MASK',
        'EXCEPTION_FORCE',
        l_target||' identificador_forzado='||l_ident_final);
    END IF;

    IF pkg_dm_sql_seguro.func_dm_norm(l_accion) = 'EXCLUDE' THEN
      pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','SKIP_EXCLUDE',l_target||' excluida por tdm_excepcion_col');
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
      -- Un FORCE del negocio no se reescribe como EXCLUDE: solo se auto-excluye (y persiste)
      -- cuando la columna no tenia FORCE explicito.
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
      -- Nivel WARN: dato clasificado como sensible que queda sin enmascarar; debe verse en el resumen.
      pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','SKIP_AUTO_LEN',
        l_target||' SIN ENMASCARAR: longitud columna ('||NVL(l_char_len,0)||') < minimo '||l_min_len||
        ' para '||l_ident_final||CASE WHEN l_ident_forzado IS NOT NULL THEN ' (columna FORZADA por tdm_excepcion_col; la regla se conserva)' ELSE '' END);
      RETURN;
    END IF;

    pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','COL_INICIO',
                  l_target||' identificador='||l_ident_final);

    IF func_dm_tiene_regla(p_esquema,p_owner,p_tabla,p_columna,'DOC_SEGUN_TIPO') > 0 THEN
      l_col_tipo := func_dm_val_regla(p_esquema,p_owner,p_tabla,p_columna,'DOC_SEGUN_TIPO');
      l_sql := 'UPDATE '||pkg_dm_sql_seguro.func_dm_qname(p_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(p_tabla)||
               ' SET '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' = pkg_dm_mask_ff1.func_dm_espec_doc_segun_tipo('||pkg_dm_sql_seguro.func_dm_qname(p_columna)||','||pkg_dm_sql_seguro.func_dm_qname(l_col_tipo)||')' ||
               ' WHERE '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' IS NOT NULL';
      pkg_dm_mask_worker.proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, p_ejecucion_id, l_rows, l_ruta);

    ELSIF func_dm_tiene_regla(p_esquema,p_owner,p_tabla,p_columna,'DOC_UNIFICADO_MANTENER_1_Y_ULTIMO') > 0 THEN
      l_sql := 'UPDATE '||pkg_dm_sql_seguro.func_dm_qname(p_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(p_tabla)||
               ' SET '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' = pkg_dm_mask_ff1.func_dm_especial_doc_keep_ends('||pkg_dm_sql_seguro.func_dm_qname(p_columna)||')' ||
               ' WHERE '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' IS NOT NULL';
      pkg_dm_mask_worker.proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, p_ejecucion_id, l_rows, l_ruta);

    ELSIF func_dm_tiene_regla(p_esquema,p_owner,p_tabla,p_columna,'IBAN_ES_CONTINUO') > 0 THEN
      -- No truncar: func_dm_especial_iban_continuo devuelve 24 caracteres; si la columna es mas
      -- corta es preferible ORA-12899 (fallo cerrado) a corromper el dato.
      l_sql := 'UPDATE '||pkg_dm_sql_seguro.func_dm_qname(p_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(p_tabla)||
               ' SET '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' = pkg_dm_mask_ff1.func_dm_especial_iban_continuo('||pkg_dm_sql_seguro.func_dm_qname(p_columna)||')' ||
               ' WHERE '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' IS NOT NULL';
      pkg_dm_mask_worker.proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, p_ejecucion_id, l_rows, l_ruta);

    ELSE
      -- Aviso previo (no detiene): una columna con indice unico propio enmascarada con una funcion NO
      -- inyectiva (nombre, direccion, telefono, email, observacion) puede dar ORA-00001. Si ocurre, la
      -- columna se auto-excluye (UPDATE atomico: nada cambia) y queda en NO_ENMASCARADA.
      IF pkg_dm_mask_ff1.func_dm_clase_identificador(l_ident_final) IN ('NOMBRE','DIRECCION','TELEFONO','EMAIL','OBS')
         AND pkg_dm_mask_worker.func_dm_col_con_unicidad(p_owner,p_tabla,p_columna) = 'Y' THEN
        pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','UNICIDAD_RIESGO',
          l_target||' tiene indice unico y se enmascara con '||l_ident_final||' (funcion no inyectiva): posible ORA-00001');
      END IF;
      l_expr := func_dm_expr_compatible(p_owner,p_tabla,p_columna,l_ident_final);
      l_sql := 'UPDATE '||pkg_dm_sql_seguro.func_dm_qname(p_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(p_tabla)||
               ' SET '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' = '||l_expr||
               ' WHERE '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' IS NOT NULL';
      pkg_dm_mask_worker.proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, p_ejecucion_id, l_rows, l_ruta);
    END IF;

    COMMIT;

    -- UNA linea por columna: ruta y filas juntas (antes RUTA iba aparte, con la misma hora que APPLY_COL).
    -- La reanudacion lee solo el prefijo 'OWNER.TABLA.COLUMNA filas=N' (punto de control): el texto
    -- de la ruta va DESPUES de filas=N y no puede cambiar ese prefijo.
    pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','APPLY_COL',
      l_target||' filas='||l_rows||CASE WHEN l_ruta IS NOT NULL THEN ' ruta='||l_ruta END,
      pkg_dm_trazabilidad.func_dm_seg_desde(l_t0));
    -- Verificacion del punto de control: proc_dm_trace es autonoma y no propaga su fallo. Si el APPLY_COL
    -- no quedo escrito, la reanudacion creeria la columna pendiente y la volveria a cifrar (FF1 no es
    -- idempotente). Se reintenta una vez; si sigue ausente se aborta la columna con un error explicito.
    DECLARE
      l_ok NUMBER;
    BEGIN
      FOR l_i IN 1..2 LOOP
        SELECT COUNT(*) INTO l_ok
          FROM tdm_mask_trace t
         WHERE t.ejecucion_id = p_ejecucion_id
           AND t.fase = 'MASK'
           AND t.paso = 'APPLY_COL'
           AND INSTR(t.detalle, l_target||' filas=') = 1;
        EXIT WHEN l_ok > 0;
        IF l_i = 1 THEN
          pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','APPLY_COL',
            l_target||' filas='||l_rows||CASE WHEN l_ruta IS NOT NULL THEN ' ruta='||l_ruta END,
            pkg_dm_trazabilidad.func_dm_seg_desde(l_t0));
        END IF;
      END LOOP;
      IF l_ok = 0 THEN
        pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'MASK','CHECKPOINT_PERDIDO',
          l_target||' enmascarada ('||l_rows||' filas) pero SIN punto de control APPLY_COL');
        RAISE_APPLICATION_ERROR(-20215,'Punto de control APPLY_COL no registrado para '||l_target||
          ': la columna YA esta enmascarada. No reanudar ni reprocesar sin revisar (FF1 no es idempotente).');
      END IF;
    END;
    -- La tarea paralela se libera despues del punto de control (ver pkg_dm_mask_worker).
    pkg_dm_mask_worker.proc_dm_cierra_tarea(p_owner, p_tabla, p_columna);
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE IN (-1, -20322) THEN
        -- Colision de unicidad (ORA-00001), directa o via -20322 desde los chunks paralelos. Con FF1
        -- los dominios numericos son biyectivos y no llegan aqui; es una columna de texto unica y
        -- se auto-excluye (un sufijo ORA_HASH rompia la FK).
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
        pkg_dm_trazabilidad.proc_dm_trace(
          p_solicitud_id, p_ejecucion_id, 'MASK', 'SKIP_ORA00001',
          l_target||' auto-excluida tras ORA-00001 (sin sufijo ORA_HASH)', pkg_dm_trazabilidad.func_dm_seg_desde(l_t0));
      ELSIF SQLCODE IN (-12899, -20323) THEN
        -- -20323: el mismo ORA-12899 homogeneizado desde los chunks paralelos.
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
        pkg_dm_trazabilidad.proc_dm_trace(
          p_solicitud_id,
          p_ejecucion_id,
          'MASK',
          'SKIP_ORA12899',
          l_target||' auto-excluida tras ORA-12899', pkg_dm_trazabilidad.func_dm_seg_desde(l_t0));
      ELSIF SQLCODE IN (-6502, -20321) THEN
        -- -20321: ORA-06502 puro detectado en la ruta paralela (>100k filas); activa el fallback de abajo.
        IF l_data_type IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2') AND NVL(l_char_len,0) > 0 THEN
          BEGIN
            -- Unico fallback: reutilizar la libreria oficial de enmascarado (keyed, con pepper)
            l_expr := 'SUBSTR(pkg_dm_mask_ff1.func_dm_generico('''||
                      REPLACE(l_ident_final,'''','''''')||''','||pkg_dm_sql_seguro.func_dm_qname(p_columna)||'),1,'||TO_CHAR(l_char_len)||')';
            l_sql := 'UPDATE '||pkg_dm_sql_seguro.func_dm_qname(p_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(p_tabla)||
                     ' SET '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' = '||l_expr||
                     ' WHERE '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' IS NOT NULL';
            -- Sin segundo fallback (TRANSLATE fijo / ORA_HASH sin pepper): seria una sustitucion
            -- reversible o enumerable marcada como enmascarada. Si func_dm_generico tampoco cabe, la
            -- columna se auto-excluye (SKIP_ORA06502) y el cierre no es FINALIZADO.
            pkg_dm_mask_worker.proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, p_ejecucion_id, l_rows_retry, l_ruta);
            COMMIT;
            pkg_dm_trazabilidad.proc_dm_trace(
              p_solicitud_id,
              p_ejecucion_id,
              'MASK',
              'APPLY_COL_SAFE_FALLBACK',
              l_target||' filas='||l_rows_retry||' (fallback seguro tras ORA-06502)', pkg_dm_trazabilidad.func_dm_seg_desde(l_t0));
            pkg_dm_mask_worker.proc_dm_cierra_tarea(p_owner, p_tabla, p_columna);
          EXCEPTION
            WHEN OTHERS THEN
              proc_dm_upsert_excepcion_col(
                p_owner      => p_owner,
                p_tabla      => p_tabla,
                p_columna    => p_columna,
                p_accion     => 'EXCLUDE',
                p_ident_forz => NULL,
                p_razon      => 'AUTO-EXCLUDE ORA-06502 en enmascaramiento: '||SUBSTR(pkg_dm_sql_seguro.func_dm_safe_err(SQLERRM),1,850)
              );
              UPDATE tdm_columna_final
                 SET enmascarar = 'N'
               WHERE ora_owner = l_owner
                 AND table_name = l_tabla
                 AND column_name = l_columna;
              COMMIT;
              pkg_dm_trazabilidad.proc_dm_trace(
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
            p_razon      => 'AUTO-EXCLUDE ORA-06502 en enmascaramiento: '||SUBSTR(pkg_dm_sql_seguro.func_dm_safe_err(SQLERRM),1,850)
          );
          UPDATE tdm_columna_final
             SET enmascarar = 'N'
           WHERE ora_owner = l_owner
             AND table_name = l_tabla
             AND column_name = l_columna;
          COMMIT;
          pkg_dm_trazabilidad.proc_dm_trace(
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
  -- PROCEDIMIENTO: proc_dm_cuenta_pendientes
  -- PROPOSITO    : Contar las columnas (y tablas) que un run enmascararia: objetivo =
  --                TDM_COLUMNA_FINAL en Y + FORCE vivo, menos EXCLUDE vivo, menos las ya
  --                confirmadas (APPLY_COL*) en la ejecucion salvo reproceso completo.
  -- ENTRADAS     : p_ejecucion_id, p_esquema, p_reproceso ('Y'/'N').
  -- SALIDA       : o_has_final (1 si el esquema tiene columnas en TDM_COLUMNA_FINAL),
  --                o_total_cols, o_total_tabs.
  -- LLAMADO DESDE: pkg_dm_enmascarar.proc_dm_mask_cat.
  -- NOTA         : conservan el workaround /*+ MATERIALIZE */ del ORA-07445 [qctcopn_internal].
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_cuenta_pendientes(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_reproceso    IN VARCHAR2,
    o_has_final    OUT NUMBER,
    o_total_cols   OUT NUMBER,
    o_total_tabs   OUT NUMBER
  ) IS
    l_esquema    VARCHAR2(128) := p_esquema;
    l_reproceso  VARCHAR2(1)   := p_reproceso;
    l_has_final  NUMBER := 0;
    l_total_cols NUMBER;
    l_total_tabs NUMBER;
  BEGIN
    SELECT CASE WHEN EXISTS (
             SELECT 1 FROM tdm_columna_final WHERE ora_owner = l_esquema AND enmascarar = 'Y'
           ) THEN 1 ELSE 0 END
      INTO l_has_final
      FROM dual;

    IF l_has_final = 1 THEN
      -- FORCE cuenta como "vivo" igual que EXCLUDE: la UNION ALL de "objetivo" incorpora las columnas
      -- FORCE aunque sigan en enmascarar='N' en TDM_COLUMNA_FINAL. Si una columna esta en ambas
      -- fuentes gana FORCE (origen=1) para el identificador.
      -- /*+ MATERIALIZE */: evita el ORA-07445 [qctcopn_internal] del optimizador al mezclar este WITH
      -- (UNION ALL + func_dm_norm en un EXISTS correlado) con la consulta externa; no cambia el resultado.
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
      SELECT COUNT(*), COUNT(DISTINCT table_name)
        INTO l_total_cols, l_total_tabs
        FROM objetivo f
       WHERE pkg_dm_mask_estado.func_dm_en_alcance(p_ejecucion_id, f.ora_owner, f.table_name, f.column_name) = 1
         AND (
           l_reproceso = 'Y' OR
           NOT EXISTS (
             SELECT 1 FROM tdm_mask_trace t
              WHERE (
                      -- Se filtra por ejecucion_id (no por solicitud_id): asi un segundo reanudo seguido
                      -- ve el historico completo y no recifra columnas ya confirmadas.
                      t.ejecucion_id = p_ejecucion_id
                    )
                AND t.fase = 'MASK'
                AND t.paso IN ('APPLY_COL','APPLY_COL_SAFE_FALLBACK','SKIP_AUTO_LEN')   -- SKIP_AUTO_LEN: omitida con aviso = resuelta
                AND (t.detalle LIKE REPLACE(REPLACE(f.ora_owner||'.'||f.table_name||'.'||f.column_name,'_','\_'),'%','\%')||' filas=%' ESCAPE '\'
                     OR t.detalle LIKE REPLACE(REPLACE(f.ora_owner||'.'||f.table_name||'.'||f.column_name,'_','\_'),'%','\%')||' SIN ENMASCARAR%' ESCAPE '\')
           )
         )
         AND NOT EXISTS (
           SELECT 1 FROM tdm_excepcion_col e
            WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = f.ora_owner
              AND e.table_name = f.table_name
              AND e.column_name = f.column_name
              AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
              AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'EXCLUDE'
         );
    ELSE
      SELECT COUNT(*), COUNT(DISTINCT table_name)
        INTO l_total_cols, l_total_tabs
        FROM tdm_excepcion_col e
       WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = l_esquema
         AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
         AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'FORCE'
         AND e.identificador_forz IS NOT NULL
         AND pkg_dm_mask_estado.func_dm_en_alcance(p_ejecucion_id, l_esquema, pkg_dm_sql_seguro.func_dm_norm(e.table_name), pkg_dm_sql_seguro.func_dm_norm(e.column_name)) = 1
         AND (
           l_reproceso = 'Y' OR
           NOT EXISTS (
             SELECT 1 FROM tdm_mask_trace t
              WHERE (
                      -- Se filtra por ejecucion_id (no por solicitud_id): asi un segundo reanudo seguido
                      -- ve el historico completo y no recifra columnas ya confirmadas.
                      t.ejecucion_id = p_ejecucion_id
                    )
                AND t.fase = 'MASK'
                AND t.paso IN ('APPLY_COL','APPLY_COL_SAFE_FALLBACK','SKIP_AUTO_LEN')   -- SKIP_AUTO_LEN: omitida con aviso = resuelta
                AND (t.detalle LIKE REPLACE(REPLACE(pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.table_name)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.column_name),'_','\_'),'%','\%')||' filas=%' ESCAPE '\'
                     OR t.detalle LIKE REPLACE(REPLACE(pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.table_name)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.column_name),'_','\_'),'%','\%')||' SIN ENMASCARAR%' ESCAPE '\')
           )
         )
         AND EXISTS (
           SELECT 1 FROM dba_tab_columns c
            WHERE c.owner = pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)
              AND c.table_name = pkg_dm_sql_seguro.func_dm_norm(e.table_name)
              AND c.column_name = pkg_dm_sql_seguro.func_dm_norm(e.column_name)
         );
    END IF;

    o_has_final  := l_has_final;
    o_total_cols := l_total_cols;
    o_total_tabs := l_total_tabs;
  END proc_dm_cuenta_pendientes;

  ------------------------------------------------------------------------------
  -- PROCEDIMIENTO: proc_dm_traza_tablas_omitidas
  -- PROPOSITO    : Trazar SKIP_TABLE por cada tabla del objetivo cuyas columnas estan todas EXCLUDE.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_esquema.
  -- SALIDA       : ninguna (solo traza).
  -- LLAMADO DESDE: pkg_dm_enmascarar.proc_dm_mask_cat (solo si el esquema tiene TDM_COLUMNA_FINAL).
  -- NOTA         : consulta movida sin cambios.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_traza_tablas_omitidas(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  ) IS
    l_esquema VARCHAR2(128) := p_esquema;
  BEGIN
      -- Mismo conjunto "objetivo" (descubrimiento + FORCE vivo) que el conteo de arriba, para no
      -- reportar como omitida una tabla que solo tiene columnas por FORCE.
      FOR tskip IN (
        -- Mismo workaround MATERIALIZE que en el conteo de arriba.
        WITH objetivo AS (
          SELECT /*+ MATERIALIZE */ ora_owner, table_name, column_name
            FROM (
              SELECT f.ora_owner, f.table_name, f.column_name
                FROM tdm_columna_final f
               WHERE f.ora_owner = l_esquema
                 AND f.enmascarar = 'Y'
              UNION ALL
              SELECT pkg_dm_sql_seguro.func_dm_norm(e.ora_owner), pkg_dm_sql_seguro.func_dm_norm(e.table_name), pkg_dm_sql_seguro.func_dm_norm(e.column_name)
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
        SELECT ora_owner, table_name
          FROM objetivo f
         WHERE pkg_dm_mask_estado.func_dm_en_alcance(p_ejecucion_id, f.ora_owner, f.table_name, f.column_name) = 1
         GROUP BY ora_owner, table_name
        HAVING COUNT(*) = SUM(
                 CASE WHEN EXISTS (
                   SELECT 1 FROM tdm_excepcion_col e
                    WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = f.ora_owner
                      AND e.table_name = f.table_name
                      AND e.column_name = f.column_name
                      AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
                      AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'EXCLUDE'
                 ) THEN 1 ELSE 0 END
               )
      ) LOOP
        pkg_dm_trazabilidad.proc_dm_trace(
          p_solicitud_id,
          p_ejecucion_id,
          'MASK',
          'SKIP_TABLE',
          tskip.ora_owner||'.'||tskip.table_name||' omitida: todas las columnas están EXCLUDE'
        );
      END LOOP;
  END proc_dm_traza_tablas_omitidas;

  ------------------------------------------------------------------------------
  -- PROCEDIMIENTO: proc_dm_preflight_tipos
  -- PROPOSITO    : Rechaza ANTES de tocar datos (antes de PRE y del primer UPDATE) las columnas a
  --                enmascarar cuyo tipo no tiene transformador en la ruta generica (todo lo que no sea
  --                CHAR, VARCHAR2, NCHAR o NVARCHAR2: NUMBER, CLOB, DATE...). Sin este control la ruta
  --                generica deja la columna igual (SET col = col) y la anota como enmascarada.
  --                No cuentan las columnas con EXCLUDE activo en tdm_excepcion_col (exclusion aprobada
  --                por el operador) ni las que tienen regla especial activa en tdm_mask_regla_esp.
  -- ENTRADAS     : p_ejecucion_id; p_esquema
  -- LEE          : TDM_COLUMNA_FINAL; TDM_EXCEPCION_COL; TDM_MASK_REGLA_ESP; DBA_TAB_COLUMNS
  -- ESCRIBE      : nada
  -- ERRORES      : ORA-20360 con la lista de columnas sin transformador (no se toca ningun dato).
  -- LLAMADO DESDE: 37_dm_pkg_enmascarar.sql (proc_dm_enmascaramiento_core, antes del pre-flight de tareas)
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_preflight_tipos(
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  ) IS
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_n       NUMBER := 0;
    l_lista   VARCHAR2(1500);
  BEGIN
    FOR r IN (
      SELECT x.ora_owner, x.table_name, x.column_name, c.data_type
        FROM (
              SELECT f.ora_owner, f.table_name, f.column_name
                FROM tdm_columna_final f
               WHERE f.ora_owner = l_esquema
                 AND f.enmascarar = 'Y'
              UNION
              SELECT pkg_dm_sql_seguro.func_dm_norm(e.ora_owner),
                     pkg_dm_sql_seguro.func_dm_norm(e.table_name),
                     pkg_dm_sql_seguro.func_dm_norm(e.column_name)
                FROM tdm_excepcion_col e
               WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner) = l_esquema
                 AND pkg_dm_sql_seguro.func_dm_norm(e.activa) = 'Y'
                 AND pkg_dm_sql_seguro.func_dm_norm(e.accion) = 'FORCE'
                 AND e.identificador_forz IS NOT NULL
             ) x,
             dba_tab_columns c
       WHERE c.owner       = x.ora_owner
         AND c.table_name  = x.table_name
         AND c.column_name = x.column_name
         AND c.data_type NOT IN ('CHAR','VARCHAR2','NCHAR','NVARCHAR2')
         AND pkg_dm_mask_estado.func_dm_en_alcance(p_ejecucion_id, x.ora_owner, x.table_name, x.column_name) = 1
         AND NOT EXISTS (
               SELECT 1 FROM tdm_excepcion_col e
                WHERE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)   = x.ora_owner
                  AND pkg_dm_sql_seguro.func_dm_norm(e.table_name)  = x.table_name
                  AND pkg_dm_sql_seguro.func_dm_norm(e.column_name) = x.column_name
                  AND pkg_dm_sql_seguro.func_dm_norm(e.activa)  = 'Y'
                  AND pkg_dm_sql_seguro.func_dm_norm(e.accion)  = 'EXCLUDE')
         AND NOT EXISTS (
               SELECT 1 FROM tdm_mask_regla_esp g
                WHERE UPPER(TRIM(g.ora_esquema)) = l_esquema
                  AND UPPER(TRIM(g.ora_owner))   = x.ora_owner
                  AND UPPER(TRIM(g.table_name))  = x.table_name
                  AND UPPER(TRIM(g.column_name)) = x.column_name
                  AND g.activa = 'Y')
       ORDER BY x.ora_owner, x.table_name, x.column_name
    ) LOOP
      l_n := l_n + 1;
      IF l_lista IS NULL OR LENGTH(l_lista) < 1300 THEN
        l_lista := l_lista||CASE WHEN l_lista IS NOT NULL THEN ', ' END||
                   r.ora_owner||'.'||r.table_name||'.'||r.column_name||' ('||r.data_type||')';
      END IF;
    END LOOP;

    IF l_n > 0 THEN
      RAISE_APPLICATION_ERROR(-20360,
        'Columnas a enmascarar SIN transformador para su tipo ('||l_n||'): '||l_lista||
        '. No se ha tocado ningun dato. Aprobar su exclusion (tdm_excepcion_col, accion EXCLUDE) o '||
        'implementar el transformador antes de relanzar.');
    END IF;
  END proc_dm_preflight_tipos;

  ------------------------------------------------------------------------------
  -- PROCEDIMIENTO: proc_dm_mask_una_col
  -- PROPOSITO    : Aplicar UNA columna del objetivo y llevar el avance del run: cancelacion,
  --                conteo de tablas/columnas, error de columna (no avanza el progreso) y
  --                actualizacion de TDM_MASK_SOLICITUD / TDM_EJECUCION.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_esquema, columna (p_ora_owner, p_table_name,
  --                p_column_name, p_identificador).
  -- SALIDA       : p_av (IN OUT) con contadores, ultima tabla y errores acumulados.
  -- LLAMADO DESDE: pkg_dm_enmascarar.proc_dm_mask_cat (una vez por columna).
  -- NOTA         : el CONTINUE del bucle original pasa a RETURN.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_mask_una_col(
    p_solicitud_id  IN NUMBER,
    p_ejecucion_id  IN NUMBER,
    p_esquema       IN VARCHAR2,
    p_ora_owner     IN VARCHAR2,
    p_table_name    IN VARCHAR2,
    p_column_name   IN VARCHAR2,
    p_identificador IN VARCHAR2,
    p_av            IN OUT t_dm_avance
  ) IS
    l_pct         NUMBER;
    l_col_fallida BOOLEAN := FALSE;
  BEGIN
        pkg_dm_mask_estado.proc_dm_chk_cancel(p_solicitud_id);

        IF p_av.last_tab IS NULL OR p_av.last_tab <> p_table_name THEN
          p_av.last_tab := p_table_name;
          p_av.proc_tabs := p_av.proc_tabs + 1;
        END IF;

        l_col_fallida := FALSE;
        BEGIN
          pkg_dm_mask_columna.proc_dm_apl_col(p_solicitud_id,p_ejecucion_id,p_esquema,p_ora_owner,p_table_name,p_column_name,p_identificador);
        EXCEPTION
          WHEN OTHERS THEN
            l_col_fallida   := TRUE;
            p_av.cols_fallidas := p_av.cols_fallidas + 1;
            p_av.errores := p_av.errores + 1;
            -- El registro de error deja tambien la linea ERROR.REGISTRADO en la linea de tiempo.
            pkg_dm_trazabilidad.proc_dm_log_ejec_error(p_ejecucion_id, p_ora_owner, p_table_name, p_column_name, 'MASK_APPLY', SQLCODE, SQLERRM, pkg_dm_sql_seguro.func_dm_safe_err(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE), p_solicitud_id);
        END;

        -- Una columna cuyo proc_dm_apl_col lanzo excepcion no esta enmascarada: no avanza el progreso
        -- (solo el latido y la ultima columna intentada). El error queda en TDM_EJECUCION_ERROR y
        -- TDM_MASK_TRACE (ERROR_COL) y p_av.errores>0 impide el estado FINALIZADO.
        IF l_col_fallida THEN
          BEGIN
            UPDATE tdm_mask_solicitud
               SET ultima_tabla   = p_table_name,
                   ultima_columna = p_column_name
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
          RETURN;
        END IF;

        p_av.proc_cols := p_av.proc_cols + 1;
        l_pct := CASE WHEN p_av.total_cols > 0 THEN ROUND((p_av.proc_cols*100)/p_av.total_cols,2) ELSE 0 END;

        pkg_dm_mask_estado.proc_dm_upd_sol(p_solicitud_id,'EN_PROCESO','MASK',p_table_name||'.'||p_column_name,'Aplicando enmascaramiento');
        BEGIN
          UPDATE tdm_mask_solicitud
             SET tablas_procesadas   = p_av.proc_tabs,
                 columnas_procesadas = p_av.proc_cols,
                 ultima_tabla        = p_table_name,
                 ultima_columna      = p_column_name
           WHERE solicitud_id = p_solicitud_id;
          COMMIT;
        EXCEPTION
          WHEN OTHERS THEN NULL;
        END;
        pkg_dm_mask_estado.proc_dm_upd_ejec(p_ejecucion_id,'ENMASCARAMIENTO','EJECUTANDO',l_pct,p_av.total_tabs,p_av.proc_tabs,p_av.total_cols,p_av.proc_cols,
                         p_ora_owner||'.'||p_table_name||'.'||p_column_name,'MASK');
  END proc_dm_mask_una_col;

END pkg_dm_mask_columna;
/
