set define off

Rem ================================================================================
Rem pkg_dm_mask_dependencias  --  33_dm_pkg_mask_dependencias.sql
Rem ================================================================================
Rem Deshabilitar (PRE) y rehabilitar (POST) constraints y triggers alrededor del enmascarado.
Rem
Rem Modularizacion 2026-10-10 (R2-R9): rutinas MOVIDAS desde pkg_dm_enmascarar sin cambiar su
Rem logica. Lo unico distinto es el prefijo de paquete en las llamadas a rutinas que viven en
Rem otro paquete. Las firmas y los textos de traza/error no cambian.
Rem ================================================================================

create or replace PACKAGE pkg_dm_mask_dependencias AS

  FUNCTION func_dm_dep_col_exists(
    p_col IN VARCHAR2
  ) RETURN NUMBER;

  PROCEDURE proc_dm_dep_policy(
    p_owner_name      IN VARCHAR2,
    p_table_name      IN VARCHAR2,
    p_dep_owner       IN VARCHAR2,
    p_dep_objeto      IN VARCHAR2,
    p_tipo_dependencia IN VARCHAR2,
    p_categoria_uso   OUT VARCHAR2,
    p_accion_pre      OUT VARCHAR2,
    p_accion_post     OUT VARCHAR2
  );

  FUNCTION func_dm_dep_post_action(
    p_owner_name IN VARCHAR2,
    p_table_name IN VARCHAR2,
    p_dep_owner  IN VARCHAR2,
    p_dep_objeto IN VARCHAR2,
    p_tipo_obj   IN VARCHAR2
  ) RETURN VARCHAR2;

  PROCEDURE proc_dm_pre_dep(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2,
    p_tablas_csv   IN VARCHAR2 DEFAULT NULL
  );

  PROCEDURE proc_dm_post_dep(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER
  );

  -- R13a: control posterior al enmascarado (extraido de proc_dm_enmascaramiento).
  PROCEDURE proc_dm_post_check(
    p_solicitud_id  IN NUMBER,
    p_ejecucion_id  IN NUMBER,
    p_esquema       IN VARCHAR2,
    p_invalidos_pre IN NUMBER,
    p_mask_errors   IN OUT NUMBER
  );

END pkg_dm_mask_dependencias;
/

create or replace PACKAGE BODY pkg_dm_mask_dependencias AS

  g_dep_has_categoria_uso NUMBER;
  g_dep_has_accion_pre_mask NUMBER;
  g_dep_has_accion_post_mask NUMBER;


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
    pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'INICIO', 'Deshabilitando dependencias definidas en TDM_DEPENDENCIA_FINAL'||
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
      pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'FK_JERARQUIA',
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

        IF pkg_dm_sql_seguro.func_dm_norm(rc.tipo_dependencia) IN ('FK','CONSTRAINT','R','FOREIGN KEY','PK_REFERENCIADA','P','PRIMARY KEY','UK_REFERENCIADA','U','UNIQUE') THEN
          IF l_accion_pre <> 'DISABLE' THEN
            pkg_dm_trazabilidad.proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_POLICY',
              'CONSTRAINT '||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_owner)||'.'||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_objeto)||
              ' accion_pre='||pkg_dm_sql_seguro.func_dm_safe_name(l_accion_pre)||' (SOLO_INFORMATIVO=solo traza, sin DDL; SIN_ACCION=no intervenir)'||
              ' categoria='||pkg_dm_sql_seguro.func_dm_safe_name(l_categoria_uso)
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
              'ALTER TABLE '||pkg_dm_sql_seguro.func_dm_qname(rc.dependencia_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(l_tabla_real)||
              ' DISABLE CONSTRAINT '||pkg_dm_sql_seguro.func_dm_qname(rc.dependencia_objeto)||' CASCADE';
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
            pkg_dm_trazabilidad.proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_NOT_FOUND',
              'CONSTRAINT '||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_owner)||'.'||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_objeto)||' no existe'
            );
          END IF;

        ELSIF pkg_dm_sql_seguro.func_dm_norm(rc.tipo_dependencia) = 'TRIGGER' THEN
          IF l_accion_pre <> 'DISABLE' THEN
            pkg_dm_trazabilidad.proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_POLICY',
              'TRIGGER '||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_owner)||'.'||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_objeto)||
              ' accion_pre='||pkg_dm_sql_seguro.func_dm_safe_name(l_accion_pre)||' (SOLO_INFORMATIVO=solo traza, sin DDL; SIN_ACCION=no intervenir)'||
              ' categoria='||pkg_dm_sql_seguro.func_dm_safe_name(l_categoria_uso)
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
            EXECUTE IMMEDIATE 'ALTER TRIGGER '||pkg_dm_sql_seguro.func_dm_qname(rc.dependencia_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(rc.dependencia_objeto)||' DISABLE';
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
            pkg_dm_trazabilidad.proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_NOT_FOUND',
              'TRIGGER '||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_owner)||'.'||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_objeto)||' no existe'
            );
          END IF;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          -- B.2: Registrar error de dependencia PRE en tdm_ejecucion_error (deja tambien
          -- la linea ERROR.REGISTRADO en la linea de tiempo)
          pkg_dm_trazabilidad.proc_dm_log_ejec_error(
            p_ejecucion_id => p_ejecucion_id,
            p_solicitud_id => p_solicitud_id,
            p_owner_name   => rc.dependencia_owner,
            p_table_name   => rc.table_name,
            p_column_name  => NULL,
            p_etapa        => 'PRE_DEP',
            p_codigo_error => SQLCODE,
            p_mensaje      => pkg_dm_sql_seguro.func_dm_safe_name(rc.tipo_dependencia)||' '||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_owner)||'.'||
                              pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_objeto)||' => '||SQLERRM,
            p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
          );
      END;
    END LOOP;

    COMMIT;
    pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'FIN', 'Dependencias deshabilitadas');
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
    pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'POST', 'INICIO', 'Rehabilitando dependencias');

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
        pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST','SKIP_POST_POLICY',
                      'TRIGGER '||pkg_dm_sql_seguro.func_dm_safe_name(l_owner)||'.'||pkg_dm_sql_seguro.func_dm_safe_name(l_objeto)||
                      ' accion_post='||pkg_dm_sql_seguro.func_dm_safe_name(l_accion_post)||
                      ' (REVISAR/SIN_ACCION=requiere revisión manual, no se ejecuta ENABLE)');
        CONTINUE;
      END IF;
      BEGIN
        EXECUTE IMMEDIATE 'ALTER TRIGGER '||pkg_dm_sql_seguro.func_dm_qname(l_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(l_objeto)||' ENABLE';
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
        pkg_dm_trazabilidad.proc_dm_log_ejec_error(
          p_ejecucion_id => p_ejecucion_id,
          p_solicitud_id => p_solicitud_id,
          p_owner_name   => l_owner,
          p_table_name   => NULL,
          p_column_name  => NULL,
          p_etapa        => 'POST_DEP_TRIGGER',
          p_codigo_error => SQLCODE,
          p_mensaje      => 'TRIGGER '||pkg_dm_sql_seguro.func_dm_safe_name(l_owner)||'.'||pkg_dm_sql_seguro.func_dm_safe_name(l_objeto)||' => '||SQLERRM,
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
        pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST','SKIP_POST_POLICY',
                      'CONSTRAINT '||pkg_dm_sql_seguro.func_dm_safe_name(l_owner)||'.'||pkg_dm_sql_seguro.func_dm_safe_name(l_tabla)||'.'||pkg_dm_sql_seguro.func_dm_safe_name(l_objeto)||
                      ' accion_post='||pkg_dm_sql_seguro.func_dm_safe_name(l_accion_post)||
                      ' (REVISAR/SIN_ACCION=requiere revisión manual, no se ejecuta ENABLE)');
        CONTINUE;
      END IF;
      BEGIN
        IF l_accion_post = 'ENABLE_VALIDATE' THEN
          EXECUTE IMMEDIATE 'ALTER TABLE '||pkg_dm_sql_seguro.func_dm_qname(l_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(l_tabla)||
                            ' ENABLE VALIDATE CONSTRAINT '||pkg_dm_sql_seguro.func_dm_qname(l_objeto);
        ELSIF l_accion_post = 'ENABLE' THEN
          EXECUTE IMMEDIATE 'ALTER TABLE '||pkg_dm_sql_seguro.func_dm_qname(l_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(l_tabla)||
                            ' ENABLE CONSTRAINT '||pkg_dm_sql_seguro.func_dm_qname(l_objeto);
        ELSE
          EXECUTE IMMEDIATE 'ALTER TABLE '||pkg_dm_sql_seguro.func_dm_qname(l_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(l_tabla)||
                            ' ENABLE NOVALIDATE CONSTRAINT '||pkg_dm_sql_seguro.func_dm_qname(l_objeto);
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
        pkg_dm_trazabilidad.proc_dm_log_ejec_error(
          p_ejecucion_id => p_ejecucion_id,
          p_solicitud_id => p_solicitud_id,
          p_owner_name   => l_owner,
          p_table_name   => l_tabla,
          p_column_name  => NULL,
          p_etapa        => 'POST_DEP_CONSTRAINT',
          p_codigo_error => SQLCODE,
          p_mensaje      => 'CONSTRAINT '||pkg_dm_sql_seguro.func_dm_safe_name(l_owner)||'.'||pkg_dm_sql_seguro.func_dm_safe_name(l_tabla)||'.'||pkg_dm_sql_seguro.func_dm_safe_name(l_objeto)||' => '||SQLERRM,
          p_backtrace    => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
      END;
    END LOOP;

    COMMIT;
    pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'POST', 'FIN', 'Dependencias rehabilitadas');
  END;

  ------------------------------------------------------------------------------
  -- PROCEDIMIENTO: proc_dm_post_check
  -- PROPOSITO    : Tras rehabilitar dependencias: contar constraints que no volvieron a ENABLED,
  --                recompilar en silencio el esquema objetivo, medir objetos INVALID nuevos contra
  --                la linea base y contar como error las columnas PII auto-excluidas (SKIP_ORA00001).
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_esquema, p_invalidos_pre (INVALID antes de
  --                enmascarar), p_mask_errors (acumulado de errores del run).
  -- SALIDA       : p_mask_errors incrementado con lo hallado; trazas POST_CHECK_INVALID y
  --                PII_SIN_ENMASCARAR; errores POST_CHECK*.
  -- LLAMADO DESDE: pkg_dm_enmascarar.proc_dm_enmascaramiento (despues de proc_dm_post_dep).
  -- NOTA         : cuerpo movido sin cambios (R13a); l_mask_errors -> p_mask_errors y
  --                proc_dm_trace/proc_dm_log_ejec_error -> pkg_dm_trazabilidad.*.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_post_check(
    p_solicitud_id  IN NUMBER,
    p_ejecucion_id  IN NUMBER,
    p_esquema       IN VARCHAR2,
    p_invalidos_pre IN NUMBER,
    p_mask_errors   IN OUT NUMBER
  ) IS
    l_solicitud_id     NUMBER        := p_solicitud_id;
    l_esquema          VARCHAR2(128) := p_esquema;
    l_invalidos_pre    NUMBER        := p_invalidos_pre;
    l_invalidos_post   NUMBER        := 0;
    l_invalidos_nuevos NUMBER        := 0;
    l_cons_mal         NUMBER        := 0;
  BEGIN
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
        pkg_dm_trazabilidad.proc_dm_log_ejec_error(
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
            -- Intencional (auditoria industrial G8, 2026-10-10): intento de recompilacion
            -- por mejor esfuerzo. Lo que no se logre recompilar NO se pierde: el conteo
            -- de INVALID posterior (l_invalidos_nuevos) lo detecta y registra
            -- POST.POST_CHECK_INVALID y el error POST_CHECK (-20203).
            WHEN OTHERS THEN
              NULL;
          END;
        END LOOP;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;   -- idem: el delta de invalidos se vuelve a medir justo debajo
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
        pkg_dm_trazabilidad.proc_dm_log_ejec_error(
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
      p_mask_errors := p_mask_errors + l_invalidos_nuevos + l_cons_mal;
      pkg_dm_trazabilidad.proc_dm_trace(
        l_solicitud_id,
        p_ejecucion_id,
        'POST',
        'POST_CHECK_INVALID',
        'Nuevos objetos INVALID='||l_invalidos_nuevos||' (pre='||l_invalidos_pre||', post='||l_invalidos_post||') ; constraints no ENABLED='||l_cons_mal
      );
      pkg_dm_trazabilidad.proc_dm_log_ejec_error(
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
        p_mask_errors := NVL(p_mask_errors,0) + l_pii_sin_masc;
        pkg_dm_trazabilidad.proc_dm_trace(l_solicitud_id,p_ejecucion_id,'FIN','PII_SIN_ENMASCARAR',
          l_pii_sin_masc||' columna(s) sensible(s) auto-excluida(s) por colision (ORA-00001): '||
          'NO se permite FINALIZADO ni export. Reclasificar a identificador biyectivo y reprocesar.');
      END IF;
    END;
  END proc_dm_post_check;

END pkg_dm_mask_dependencias;
/
