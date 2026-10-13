set define off

Rem ================================================================================
Rem pkg_dm_mask_dependencias  --  33_dm_pkg_mask_dependencias.sql
Rem ================================================================================
Rem Deshabilitar (PRE) y rehabilitar (POST) constraints y triggers alrededor del enmascarado.
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    10/10/26 - Rutinas movidas desde pkg_dm_enmascarar sin cambiar su logica
Rem    epurisaca    10/12/26 - Se elimina la compatibilidad de columnas de TDM_DEPENDENCIA_FINAL (siempre existen)
Rem                           y el parametro p_tablas_csv de proc_dm_pre_dep
Rem ================================================================================

create or replace PACKAGE pkg_dm_mask_dependencias AS

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
    p_esquema      IN VARCHAR2
  );

  PROCEDURE proc_dm_post_dep(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER
  );

  -- Control posterior al enmascarado.
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


  ------------------------------------------------------------------------------
  -- Dependencias PRE/POST
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_dep_policy
  -- PROPOSITO    : Determina la categoria de uso y las acciones pre y post enmascarado de una
  --                dependencia (FK, PK/UK, trigger u otra), con defaults por tipo y sobreescritura
  --                desde TDM_DEPENDENCIA_FINAL.
  -- ENTRADAS     : p_owner_name, p_table_name, p_dep_owner, p_dep_objeto, p_tipo_dependencia; OUT
  --                p_categoria_uso, p_accion_pre, p_accion_post.
  -- LEE          : TDM_DEPENDENCIA_FINAL
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno propio; sin fila en TDM_DEPENDENCIA_FINAL se mantienen los defaults.
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
    l_cat  VARCHAR2(100);
    l_pre  VARCHAR2(100);
    l_post VARCHAR2(100);
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

    -- La politica definida en TDM_DEPENDENCIA_FINAL manda sobre el default por tipo.
    SELECT MAX(UPPER(TRIM(categoria_uso))),
           MAX(UPPER(TRIM(accion_pre_mask))),
           MAX(UPPER(TRIM(accion_post_mask)))
      INTO l_cat, l_pre, l_post
      FROM tdm_dependencia_final
     WHERE ora_owner = UPPER(TRIM(p_owner_name))
       AND table_name = UPPER(TRIM(p_table_name))
       AND UPPER(TRIM(dependencia_owner)) = UPPER(TRIM(p_dep_owner))
       AND UPPER(TRIM(dependencia_objeto)) = UPPER(TRIM(p_dep_objeto))
       AND UPPER(TRIM(tipo_dependencia)) = UPPER(TRIM(p_tipo_dependencia));
    IF l_cat  IS NOT NULL THEN p_categoria_uso := l_cat;  END IF;
    IF l_pre  IS NOT NULL THEN p_accion_pre    := l_pre;  END IF;
    IF l_post IS NOT NULL THEN p_accion_post   := l_post; END IF;
  END;


  ------------------------------------------------------------------------------
  -- [DOC] function func_dm_dep_post_action
  -- PROPOSITO    : Devuelve la accion de rehabilitacion post enmascarado de una dependencia (por
  --                defecto ENABLE para trigger, ENABLE_VALIDATE para el resto).
  -- ENTRADAS     : p_owner_name, p_table_name, p_dep_owner, p_dep_objeto, p_tipo_obj; retorna accion.
  -- LEE          : TDM_DEPENDENCIA_FINAL
  -- ESCRIBE      : ninguno
  -- ERRORES      : ninguno propio; sin fila en TDM_DEPENDENCIA_FINAL devuelve el default.
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

    SELECT MAX(UPPER(TRIM(accion_post_mask)))
      INTO l_val
      FROM tdm_dependencia_final
     WHERE ora_owner = UPPER(TRIM(p_owner_name))
       AND table_name = UPPER(TRIM(p_table_name))
       AND UPPER(TRIM(dependencia_owner)) = UPPER(TRIM(p_dep_owner))
       AND UPPER(TRIM(dependencia_objeto)) = UPPER(TRIM(p_dep_objeto));
    IF l_val IS NOT NULL THEN
      RETURN l_val;
    END IF;

    RETURN l_def;
  END;


  ------------------------------------------------------------------------------
  -- [DOC] procedure proc_dm_pre_dep
  -- PROPOSITO    : Deshabilita (DDL) las FK, claves y triggers definidos en TDM_DEPENDENCIA_FINAL y
  --                deja constancia en TDM_MASK_DEP_ESTADO para poder rehabilitarlos tras enmascarar.
  -- ENTRADAS     : p_solicitud_id, p_ejecucion_id, p_esquema.
  -- LEE          : DBA_CONSTRAINTS; DBA_TRIGGERS; TDM_COLUMNA_FINAL; TDM_DEPENDENCIA_FINAL
  -- ESCRIBE      : TDM_MASK_DEP_ESTADO (INSERT/UPDATE); DDL: ALTER TABLE ... DISABLE CONSTRAINT ...
  --                CASCADE; DDL: ALTER TRIGGER ... DISABLE; COMMIT
  -- ERRORES      : Sin RAISE_APPLICATION_ERROR: el error de cada dependencia se registra con etapa
  --                PRE_DEP y el bucle continua.
  -- LLAMADO DESDE: pkg_dm_enmascarar.proc_dm_enmascaramiento_core.
  ------------------------------------------------------------------------------
  PROCEDURE proc_dm_pre_dep(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  ) IS
    l_tabla_real VARCHAR2(261);
    l_exists NUMBER;
    l_esquema VARCHAR2(128) := UPPER(TRIM(p_esquema));
    l_categoria_uso VARCHAR2(100);
    l_accion_pre    VARCHAR2(100);
    l_accion_post   VARCHAR2(100);
    l_est_previo    VARCHAR2(20);   -- estado REAL previo (ENABLED, ENABLED_NOVAL, DISABLED)
    l_status        VARCHAR2(8);
    l_valid         VARCHAR2(13);
    l_tipo_c        VARCHAR2(1);
    l_ya            NUMBER;
  BEGIN
    pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'INICIO', 'Deshabilitando dependencias definidas en TDM_DEPENDENCIA_FINAL');

    -- Reanudacion tras un corte (kill, caida): lo que una solicitud ANTERIOR de esta ejecucion dejo
    -- deshabilitado y no llego a rehabilitar es del motor, no del cliente. Sin esto, el PRE de la
    -- reanudacion lo leeria DISABLED, lo tomaria por "ya estaba deshabilitado antes del motor" y
    -- nadie lo rehabilitaria nunca (PK/UK, FK hijas y triggers quedarian deshabilitados). Se hereda
    -- con su estado_previo original (la fila mas reciente por objeto) y esta solicitud lo rehabilita
    -- en su POST. Solo se hereda lo que el diccionario muestra hoy DISABLED.
    DECLARE
      l_heredadas NUMBER := 0;
    BEGIN
      INSERT INTO tdm_mask_dep_estado(
        solicitud_id, tipo_objeto, ora_owner, table_name, objeto_name,
        estado_previo, deshabilitado_ok, orden_rehabilitacion, fecha_pre
      )
      SELECT p_solicitud_id, x.tipo_objeto, x.ora_owner, x.table_name, x.objeto_name,
             x.estado_previo, 'Y', x.orden_rehabilitacion, SYSTIMESTAMP
        FROM (SELECT d.tipo_objeto, d.ora_owner, d.table_name, d.objeto_name, d.estado_previo,
                     d.deshabilitado_ok, d.habilitado_ok, d.orden_rehabilitacion,
                     ROW_NUMBER() OVER (PARTITION BY d.tipo_objeto, d.ora_owner, d.table_name, d.objeto_name
                                        ORDER BY d.solicitud_id DESC) rn
                FROM tdm_mask_dep_estado d
                JOIN tdm_mask_solicitud s ON s.solicitud_id = d.solicitud_id
               WHERE s.ejecucion_id = p_ejecucion_id
                 AND d.solicitud_id < p_solicitud_id) x
       WHERE x.rn = 1
         AND x.deshabilitado_ok = 'Y'
         AND NVL(x.habilitado_ok,'N') <> 'Y'
         AND x.estado_previo IN ('ENABLED','ENABLED_NOVAL')
         AND ((x.tipo_objeto = 'CONSTRAINT'
               AND EXISTS (SELECT 1 FROM dba_constraints c
                            WHERE c.owner = x.ora_owner AND c.constraint_name = x.objeto_name
                              AND c.status = 'DISABLED'))
           OR (x.tipo_objeto = 'TRIGGER'
               AND EXISTS (SELECT 1 FROM dba_triggers t
                            WHERE t.owner = x.ora_owner AND t.trigger_name = x.objeto_name
                              AND t.status = 'DISABLED')));
      l_heredadas := SQL%ROWCOUNT;
      IF l_heredadas > 0 THEN
        pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id, p_ejecucion_id, 'PRE', 'HEREDA_DEP',
          l_heredadas||' dependencia(s) quedaron deshabilitadas por una solicitud anterior interrumpida: '||
          'se heredan con su estado original y se rehabilitan en el POST de esta');
      END IF;
    END;

    -- Enumerar y trazar la jerarquía FK (hija -> padre) de las tablas a enmascarar
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
             AND pkg_dm_mask_estado.func_dm_en_alcance(p_ejecucion_id, l_esquema, UPPER(table_name), NULL) = 1
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

          -- Si ya figura (hija FK registrada por el CASCADE de su padre) no se vuelve a leer su
          -- estado: ya estaria DESHABILITADA por el motor y se guardaria un estado falso.
          SELECT COUNT(*) INTO l_ya
            FROM tdm_mask_dep_estado e
           WHERE e.solicitud_id = p_solicitud_id AND e.tipo_objeto = 'CONSTRAINT'
             AND e.ora_owner = UPPER(TRIM(rc.dependencia_owner))
             AND e.table_name = UPPER(TRIM(l_tabla_real))
             AND e.objeto_name = UPPER(TRIM(rc.dependencia_objeto));
          IF l_ya > 0 THEN
            CONTINUE;
          END IF;
          -- Se guarda el estado REAL: una restriccion ya DESHABILITADA se deja como esta; una
          -- ENABLED NOT VALIDATED vuelve como tal.
          l_status := NULL; l_valid := NULL; l_tipo_c := NULL;
          BEGIN
            SELECT c.status, c.validated, c.constraint_type
              INTO l_status, l_valid, l_tipo_c
              FROM dba_constraints c
             WHERE c.owner = UPPER(TRIM(rc.dependencia_owner))
               AND c.constraint_name = UPPER(TRIM(rc.dependencia_objeto))
               AND ROWNUM = 1;
          EXCEPTION
            WHEN OTHERS THEN NULL;
          END;
          l_est_previo := CASE WHEN l_status = 'DISABLED' THEN 'DISABLED'
                               WHEN l_valid = 'NOT VALIDATED' THEN 'ENABLED_NOVAL'
                               ELSE 'ENABLED' END;
          INSERT INTO tdm_mask_dep_estado(
            solicitud_id, tipo_objeto, ora_owner, table_name, objeto_name, estado_previo, fecha_pre
          ) VALUES (
            p_solicitud_id, 'CONSTRAINT', UPPER(TRIM(rc.dependencia_owner)), UPPER(TRIM(l_tabla_real)), UPPER(TRIM(rc.dependencia_objeto)), l_est_previo, SYSTIMESTAMP
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

          IF l_exists > 0 AND l_est_previo = 'DISABLED' THEN
            -- Ya estaba deshabilitada antes del motor: no se toca ni se rehabilita despues.
            UPDATE tdm_mask_dep_estado
               SET deshabilitado_ok = 'N'
             WHERE solicitud_id = p_solicitud_id
               AND tipo_objeto  = 'CONSTRAINT'
               AND ora_owner   = UPPER(TRIM(rc.dependencia_owner))
               AND table_name   = UPPER(TRIM(l_tabla_real))
               AND objeto_name  = UPPER(TRIM(rc.dependencia_objeto));
            pkg_dm_trazabilidad.proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_YA_DESHAB',
              'CONSTRAINT '||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_owner)||'.'||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_objeto)||
              ' ya estaba DESHABILITADA antes del motor: se deja como esta'
            );
          ELSIF l_exists > 0 THEN
            -- El CASCADE deshabilita tambien las FK hijas ENABLED de una PK/UK. Se registran antes
            -- (con su estado real, orden_rehabilitacion=9) para que POST las devuelva a ese estado.
            IF l_tipo_c IN ('P','U') THEN
              INSERT INTO tdm_mask_dep_estado(
                solicitud_id, tipo_objeto, ora_owner, table_name, objeto_name,
                estado_previo, deshabilitado_ok, orden_rehabilitacion, fecha_pre
              )
              SELECT p_solicitud_id, 'CONSTRAINT', h.owner, h.table_name, h.constraint_name,
                     CASE WHEN h.validated = 'NOT VALIDATED' THEN 'ENABLED_NOVAL' ELSE 'ENABLED' END,
                     'N', 9, SYSTIMESTAMP
                FROM dba_constraints h
               WHERE h.constraint_type = 'R'
                 AND h.r_owner = UPPER(TRIM(rc.dependencia_owner))
                 AND h.r_constraint_name = UPPER(TRIM(rc.dependencia_objeto))
                 AND h.status = 'ENABLED'
                 AND NOT EXISTS (SELECT 1 FROM tdm_mask_dep_estado e
                                  WHERE e.solicitud_id = p_solicitud_id AND e.tipo_objeto = 'CONSTRAINT'
                                    AND e.ora_owner = h.owner AND e.table_name = h.table_name
                                    AND e.objeto_name = h.constraint_name);
            END IF;
            -- El DISABLE se ordena por owner/tabla/objeto, no por profundidad FK: una PK con un hijo
            -- que ordena despues daria ORA-02297. CASCADE lo resuelve (es no-op en un hijo sin
            -- dependientes e idempotente si el hijo ya fue deshabilitado).
            EXECUTE IMMEDIATE
              'ALTER TABLE '||pkg_dm_sql_seguro.func_dm_qname(rc.dependencia_owner)||'.'||pkg_dm_sql_seguro.func_dm_qname(l_tabla_real)||
              ' DISABLE CONSTRAINT '||pkg_dm_sql_seguro.func_dm_qname(rc.dependencia_objeto)||' CASCADE';
            -- Las hijas registradas pasan a 'Y' solo si el diccionario las muestra ya DISABLED.
            UPDATE tdm_mask_dep_estado e
               SET e.deshabilitado_ok = 'Y'
             WHERE e.solicitud_id = p_solicitud_id
               AND e.tipo_objeto = 'CONSTRAINT'
               AND e.orden_rehabilitacion = 9
               AND e.deshabilitado_ok = 'N'
               AND EXISTS (SELECT 1 FROM dba_constraints h
                            WHERE h.owner = e.ora_owner AND h.constraint_name = e.objeto_name
                              AND h.status = 'DISABLED');
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
          -- Heredado de una solicitud anterior interrumpida (ver PRE INICIO): ya figura, no se vuelve a leer.
          SELECT COUNT(*) INTO l_ya
            FROM tdm_mask_dep_estado e
           WHERE e.solicitud_id = p_solicitud_id AND e.tipo_objeto = 'TRIGGER'
             AND e.ora_owner = UPPER(TRIM(rc.dependencia_owner))
             AND e.objeto_name = UPPER(TRIM(rc.dependencia_objeto));
          IF l_ya > 0 THEN
            CONTINUE;
          END IF;
          -- Estado REAL del trigger: uno ya DISABLED no se rehabilita.
          l_status := NULL;
          BEGIN
            SELECT t.status INTO l_status
              FROM dba_triggers t
             WHERE t.owner = UPPER(TRIM(rc.dependencia_owner))
               AND t.trigger_name = UPPER(TRIM(rc.dependencia_objeto))
               AND ROWNUM = 1;
          EXCEPTION
            WHEN OTHERS THEN NULL;
          END;
          l_est_previo := CASE WHEN l_status = 'DISABLED' THEN 'DISABLED' ELSE 'ENABLED' END;
          INSERT INTO tdm_mask_dep_estado(
            solicitud_id, tipo_objeto, ora_owner, table_name, objeto_name, estado_previo, fecha_pre
          ) VALUES (
            p_solicitud_id, 'TRIGGER', UPPER(TRIM(rc.dependencia_owner)), UPPER(TRIM(rc.table_name)), UPPER(TRIM(rc.dependencia_objeto)), l_est_previo, SYSTIMESTAMP
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

          IF l_exists > 0 AND l_est_previo = 'DISABLED' THEN
            UPDATE tdm_mask_dep_estado
               SET deshabilitado_ok = 'N'
             WHERE solicitud_id = p_solicitud_id
               AND tipo_objeto  = 'TRIGGER'
               AND ora_owner   = UPPER(TRIM(rc.dependencia_owner))
               AND objeto_name  = UPPER(TRIM(rc.dependencia_objeto));
            pkg_dm_trazabilidad.proc_dm_trace(
              p_solicitud_id, p_ejecucion_id, 'PRE', 'SKIP_DEP_YA_DESHAB',
              'TRIGGER '||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_owner)||'.'||pkg_dm_sql_seguro.func_dm_safe_name(rc.dependencia_objeto)||
              ' ya estaba DESHABILITADO antes del motor: se deja como esta'
            );
          ELSIF l_exists > 0 THEN
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
          -- Registrar error de dependencia PRE en tdm_ejecucion_error (deja tambien
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
  -- LLAMADO DESDE: Interno: proc_dm_enmascaramiento (flujo normal y manejador de error).
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
      SELECT ora_owner, objeto_name, table_name
        FROM tdm_mask_dep_estado
       WHERE solicitud_id = p_solicitud_id
         AND tipo_objeto = 'TRIGGER'
         AND deshabilitado_ok = 'Y'
       ORDER BY ora_owner, objeto_name
    ) LOOP
      l_owner := rc.ora_owner; l_objeto := rc.objeto_name;
      l_accion_post := func_dm_dep_post_action(l_owner, rc.table_name, l_owner, l_objeto, 'TRIGGER');  -- antes table_name NULL
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
        -- Registrar error de dependencia POST en tdm_ejecucion_error (deja tambien
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
      SELECT d.ora_owner, d.table_name, d.objeto_name, d.estado_previo, d.orden_rehabilitacion
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
      -- Una hija FK deshabilitada por el CASCADE (orden 9) no figura en la politica: se restaura
      -- tal como estaba.
      IF rc.orden_rehabilitacion = 9 THEN
        l_accion_post := CASE WHEN rc.estado_previo = 'ENABLED_NOVAL' THEN 'ENABLE_NOVALIDATE' ELSE 'ENABLE' END;
      -- Si estaba ENABLED NOT VALIDATED vuelve como NOVALIDATE aunque la politica pida validar.
      ELSIF rc.estado_previo = 'ENABLED_NOVAL' AND l_accion_post IN ('ENABLE','ENABLE_VALIDATE') THEN
        l_accion_post := 'ENABLE_NOVALIDATE';
      END IF;
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
        -- Registrar error de dependencia POST en tdm_ejecucion_error (deja tambien
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
  -- NOTA         : l_mask_errors pasa a p_mask_errors.
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
    -- Control de dependencias no rehabilitadas e invalidación de objetos (con baseline)
    BEGIN
      SELECT COUNT(*)
        INTO l_cons_mal
        FROM tdm_mask_dep_estado d
        JOIN dba_constraints c
          ON c.owner = d.ora_owner AND c.constraint_name = d.objeto_name
       WHERE d.solicitud_id = l_solicitud_id
         AND d.tipo_objeto  = 'CONSTRAINT'
         AND d.estado_previo IN ('ENABLED','ENABLED_NOVAL')
         AND d.deshabilitado_ok = 'Y'
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
            -- Recompilacion por mejor esfuerzo: lo que no se logre recompilar lo detecta el conteo de
            -- INVALID posterior (POST.POST_CHECK_INVALID y error POST_CHECK -20203).
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
