set define off

Rem ================================================================================
Rem pkg_dm_mask_columna  --  35_dm_pkg_mask_columna.sql
Rem ================================================================================
Rem Decidir la funcion de enmascarado de una columna y aplicarla (checkpoint APPLY_COL).
Rem
Rem Modularizacion 2026-10-10 (R2-R9): rutinas MOVIDAS desde pkg_dm_enmascarar sin cambiar su
Rem logica. Lo unico distinto es el prefijo de paquete en las llamadas a rutinas que viven en
Rem otro paquete. Las firmas y los textos de traza/error no cambian.
Rem
Rem 2026-10-10 (auditoria industrial G9): func_dm_expr_gen_sql y func_dm_min_len_identificador
Rem dejan de tener su propia tabla de identificadores y usan
Rem pkg_dm_mask_ff1.func_dm_clase_identificador. Sin cambio de resultado para los siete
Rem identificadores de las reglas.
Rem otro paquete. Las firmas y los textos de traza/error no cambian.
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

  -- R13b: avance de un run de enmascarado (contadores que comparten proc_dm_mask_cat y proc_dm_mask_una_col).
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
    -- 2026-10-10 (auditoria industrial G9): la correspondencia identificador -> clase vive
    -- ahora en un solo sitio, pkg_dm_mask_ff1.func_dm_clase_identificador. Las siete clases
    -- exactas de las reglas (PERSONAL, NOMBRE, DIRECCION, TELEFONO, EMAIL, IDENTIDAD y
    -- BANCARIO) generan la misma expresion que antes.
    l_cls VARCHAR2(20) := pkg_dm_mask_ff1.func_dm_clase_identificador(p_identificador);
  BEGIN
    CASE l_cls
      WHEN 'NOMBRE'    THEN RETURN 'pkg_dm_mask_ff1.func_dm_nombre('||p_col_expr||')';
      WHEN 'DIRECCION' THEN RETURN 'pkg_dm_mask_ff1.func_dm_direccion('||p_col_expr||')';
      WHEN 'TELEFONO'  THEN RETURN 'pkg_dm_mask_ff1.func_dm_telefono('||p_col_expr||')';
      WHEN 'EMAIL'     THEN RETURN 'pkg_dm_mask_ff1.func_dm_email('||p_col_expr||')';
      WHEN 'IDENTIDAD' THEN RETURN 'pkg_dm_mask_ff1.func_dm_nif('||p_col_expr||')';
      WHEN 'BANCARIO'  THEN
        RETURN 'CASE WHEN REGEXP_LIKE(UPPER(TRIM('||p_col_expr||')), ''^ES[0-9]{22}$'') '||
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
      -- M-7: Envolver en SUBSTR con longitud de fallback prudente ante fallo de consulta de metadatos
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
      -- C-01: NO truncar. func_dm_especial_iban_continuo devuelve 24 chars exactos;
      -- si la columna fuera mas corta, ORA-12899 (fallo cerrado) mejor que corromper.
      l_sql := 'UPDATE '||pkg_dm_sql_seguro.func_dm_qname(p_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(p_tabla)||
               ' SET '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' = pkg_dm_mask_ff1.func_dm_especial_iban_continuo('||pkg_dm_sql_seguro.func_dm_qname(p_columna)||')' ||
               ' WHERE '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' IS NOT NULL';
      pkg_dm_mask_worker.proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, p_ejecucion_id, l_rows, l_ruta);

    ELSE
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
        pkg_dm_trazabilidad.proc_dm_trace(
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
        pkg_dm_trazabilidad.proc_dm_trace(
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
            l_expr := 'SUBSTR(pkg_dm_mask_ff1.func_dm_generico('''||
                      REPLACE(l_ident_final,'''','''''')||''','||pkg_dm_sql_seguro.func_dm_qname(p_columna)||'),1,'||TO_CHAR(l_char_len)||')';
            l_sql := 'UPDATE '||pkg_dm_sql_seguro.func_dm_qname(p_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(p_tabla)||
                     ' SET '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' = '||l_expr||
                     ' WHERE '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' IS NOT NULL';
            BEGIN
              pkg_dm_mask_worker.proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, p_ejecucion_id, l_rows_retry, l_ruta);
            EXCEPTION
              WHEN OTHERS THEN
                -- Segundo fallback: expresión SQL ultra-segura por tipo de identificador
                IF l_ident_final IN ('IDENTIFICADOR_PERSONAL','IDENTIFICADOR_NOMBRE') THEN
                  l_expr := 'SUBSTR(TRANSLATE(UPPER('||pkg_dm_sql_seguro.func_dm_qname(p_columna)||'),'||
                            '''ABCDEFGHIJKLMNOPQRSTUVWXYZ'','||
                            '''QWERTYUIOPASDFGHJKLZXCVBNM''),1,'||TO_CHAR(l_char_len)||')';
                ELSIF l_ident_final = 'IDENTIFICADOR_DIRECCION' THEN
                  l_expr := 'SUBSTR(''Calle Ficticia N ''||TO_CHAR(MOD(ORA_HASH('||pkg_dm_sql_seguro.func_dm_qname(p_columna)||'),999))||'', Zaragoza'',1,'||TO_CHAR(l_char_len)||')';
                ELSIF l_ident_final = 'IDENTIFICADOR_EMAIL' THEN
                  l_expr := 'SUBSTR(''usuario''||TO_CHAR(MOD(ORA_HASH('||pkg_dm_sql_seguro.func_dm_qname(p_columna)||'),1000000))||''@correo.com'',1,'||TO_CHAR(l_char_len)||')';
                ELSIF l_ident_final = 'IDENTIFICADOR_TELEFONO' THEN
                  l_expr := 'SUBSTR(''6''||LPAD(TO_CHAR(MOD(ORA_HASH('||pkg_dm_sql_seguro.func_dm_qname(p_columna)||'),100000000)),8,''0''),1,'||TO_CHAR(l_char_len)||')';
                ELSE
                  l_expr := 'SUBSTR(TRANSLATE(UPPER('||pkg_dm_sql_seguro.func_dm_qname(p_columna)||'),'||
                            '''ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'','||
                            '''QWERTYUIOPASDFGHJKLZXCVBNM9876543210''),1,'||TO_CHAR(l_char_len)||')';
                END IF;
                l_sql := 'UPDATE '||pkg_dm_sql_seguro.func_dm_qname(p_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(p_tabla)||
                         ' SET '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' = '||l_expr||
                         ' WHERE '||pkg_dm_sql_seguro.func_dm_qname(p_columna)||' IS NOT NULL';
                pkg_dm_mask_worker.proc_dm_ejecuta_update_seguro(p_owner, p_tabla, p_columna, l_sql, p_ejecucion_id, l_rows_retry, l_ruta);
            END;
            COMMIT;
            pkg_dm_trazabilidad.proc_dm_trace(
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
  -- NOTA         : consultas movidas sin cambios (R13b); conservan el workaround
  --                /*+ MATERIALIZE */ del ORA-07445 [qctcopn_internal].
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
                AND t.detalle LIKE pkg_dm_sql_seguro.func_dm_norm(e.ora_owner)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.table_name)||'.'||pkg_dm_sql_seguro.func_dm_norm(e.column_name)||' filas=%'
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
  -- NOTA         : consulta movida sin cambios (R13b).
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_traza_tablas_omitidas(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  ) IS
    l_esquema VARCHAR2(128) := p_esquema;
  BEGIN
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
  -- PROCEDIMIENTO: proc_dm_mask_una_col
  -- PROPOSITO    : Aplicar UNA columna del objetivo y llevar el avance del run: cancelacion,
  --                conteo de tablas/columnas, error de columna (no avanza el progreso) y
  --                actualizacion de TDM_MASK_SOLICITUD / TDM_EJECUCION.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_esquema, columna (p_ora_owner, p_table_name,
  --                p_column_name, p_identificador).
  -- SALIDA       : p_av (IN OUT) con contadores, ultima tabla y errores acumulados.
  -- LLAMADO DESDE: pkg_dm_enmascarar.proc_dm_mask_cat (una vez por columna).
  -- NOTA         : cuerpo movido sin cambios (R13b); estaba duplicado en las dos ramas de
  --                proc_dm_mask_cat. El CONTINUE del bucle pasa a RETURN.
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

        -- FIX 2026-10-07 (Fase 1, incidente real ejecucion_id=1 DM_DUMMY: CUENTA_CCC
        -- fallo con ORA-20330 y aun asi se contaba como "procesada"): una columna
        -- cuyo proc_dm_apl_col lanzo excepcion NO esta enmascarada (o lo esta solo
        -- a medias). Antes, el contador p_av.proc_cols, el porcentaje, columnas_procesadas
        -- y ULTIMO_OBJETO avanzaban igual que en una columna exitosa -- el monitor
        -- mostraba progreso falso y ULTIMO_OBJETO apuntaba a una columna que seguia
        -- en claro. Ahora una columna fallida NO avanza el progreso: solo se
        -- refresca el latido y la ultima tabla/columna intentada; el error ya
        -- quedo en TDM_EJECUCION_ERROR y en TDM_MASK_TRACE (ERROR_COL), y
        -- p_av.errores>0 garantiza estado final ERROR/CON_ERRORES (nunca FINALIZADO,
        -- sin purga de pepper ni export). No cambia que columnas se reintentan al
        -- reanudar: eso depende solo de los APPLY_COL en TDM_MASK_TRACE.
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
