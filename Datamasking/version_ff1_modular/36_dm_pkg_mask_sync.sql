set define off

Rem ================================================================================
Rem pkg_dm_mask_sync  --  36_dm_pkg_mask_sync.sql
Rem ================================================================================
Rem Coherencia entre tablas sin FK (TDM_MASK_RELACION_SYNC) tras el enmascarado.
Rem
Rem Modularizacion 2026-10-10 (R2-R9): rutinas MOVIDAS desde pkg_dm_enmascarar sin cambiar su
Rem logica. Lo unico distinto es el prefijo de paquete en las llamadas a rutinas que viven en
Rem otro paquete. Las firmas y los textos de traza/error no cambian.
Rem ================================================================================

create or replace PACKAGE pkg_dm_mask_sync AS

  PROCEDURE proc_dm_post_sync(
    p_solicitud_id IN NUMBER,
    p_ejecucion_id IN NUMBER,
    p_esquema      IN VARCHAR2
  );

END pkg_dm_mask_sync;
/

create or replace PACKAGE BODY pkg_dm_mask_sync AS


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
    l_ruta_sync VARCHAR2(400);   -- ruta devuelta por proc_dm_ejecuta_update_seguro (no se traza en POST_SYNC)
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
            'SELECT COUNT(*), NVL(MAX(LENGTH(TO_CHAR(s.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_origen)||'))),0) '||
            '  FROM '||pkg_dm_sql_seguro.func_dm_qname(p_esquema)||'.'||pkg_dm_sql_seguro.func_dm_qname(rc.tabla_destino)||' d '||
            '  JOIN '||pkg_dm_sql_seguro.func_dm_qname(p_esquema)||'.'||pkg_dm_sql_seguro.func_dm_qname(rc.tabla_origen)||' s '||
            '    ON s.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_join_origen)||' = d.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_join_destino)||' '||
            ' WHERE s.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_origen)||' IS NOT NULL '||
            '   AND LENGTH(TO_CHAR(s.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_origen)||')) > '||TO_CHAR(l_dest_len);
          EXECUTE IMMEDIATE l_sql INTO l_len_conflicts, l_max_src_len;

          IF NVL(l_len_conflicts,0) > 0 THEN
            pkg_dm_trazabilidad.proc_dm_trace(
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
          'UPDATE '||pkg_dm_sql_seguro.func_dm_qname(p_esquema)||'.'||pkg_dm_sql_seguro.func_dm_qname(rc.tabla_destino)||' d '||
          'SET '||pkg_dm_sql_seguro.func_dm_qname(rc.columna_destino)||' = ('||
          '  SELECT s.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_origen)||' FROM '||pkg_dm_sql_seguro.func_dm_qname(p_esquema)||'.'||pkg_dm_sql_seguro.func_dm_qname(rc.tabla_origen)||' s '||
          '   WHERE s.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_join_origen)||' = d.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_join_destino)||' ) '||
          'WHERE EXISTS (SELECT 1 FROM '||pkg_dm_sql_seguro.func_dm_qname(p_esquema)||'.'||pkg_dm_sql_seguro.func_dm_qname(rc.tabla_origen)||' s '||
          '               WHERE s.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_join_origen)||' = d.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_join_destino)||')';
        pkg_dm_mask_worker.proc_dm_ejecuta_update_seguro(p_esquema, rc.tabla_destino, rc.columna_destino, l_sql, p_ejecucion_id, l_rows, l_ruta_sync);
        COMMIT;
        pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST_SYNC','SYNC',
                      rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' filas='||l_rows);
      EXCEPTION
        WHEN OTHERS THEN
          pkg_dm_trazabilidad.proc_dm_trace(
            p_solicitud_id,p_ejecucion_id,'POST_SYNC','WARN_SYNC',
            rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' => '||pkg_dm_sql_seguro.func_dm_safe_err(SQLERRM)
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
          'SELECT /*+ PARALLEL(d,4) PARALLEL(s,4) */ COUNT(*) FROM '||pkg_dm_sql_seguro.func_dm_qname(p_esquema)||'.'||pkg_dm_sql_seguro.func_dm_qname(rc.tabla_destino)||' d '||
          'JOIN '||pkg_dm_sql_seguro.func_dm_qname(p_esquema)||'.'||pkg_dm_sql_seguro.func_dm_qname(rc.tabla_origen)||' s '||
          '  ON s.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_join_origen)||' = d.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_join_destino)||' '||
          'WHERE NVL(TO_CHAR(d.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_destino)||'),''#NULL#'') '||
          '   <> NVL(TO_CHAR(s.'||pkg_dm_sql_seguro.func_dm_qname(rc.columna_origen)||'),''#NULL#'')';
        EXECUTE IMMEDIATE l_sql INTO l_diff;
        IF NVL(l_diff,0) = 0 THEN
          pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST_SYNC','SYNC_OK',
                        rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' diferencias=0');
        ELSE
          pkg_dm_trazabilidad.proc_dm_trace(p_solicitud_id,p_ejecucion_id,'POST_SYNC','SYNC_MISMATCH',
                        rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' diferencias='||l_diff);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          pkg_dm_trazabilidad.proc_dm_trace(
            p_solicitud_id,p_ejecucion_id,'POST_SYNC','WARN_SYNC_CHECK',
            rc.tabla_origen||'.'||rc.columna_origen||' -> '||rc.tabla_destino||'.'||rc.columna_destino||' => '||pkg_dm_sql_seguro.func_dm_safe_err(SQLERRM)
          );
      END;
    END LOOP;
  END;

END pkg_dm_mask_sync;
/
