PROMPT =========================================================
PROMPT Reporte de cumplimiento de objetivo de enmascaramiento
PROMPT Esquema: &&P_ESQUEMA
PROMPT Ejecucion: &&P_EJECUCION_ID
PROMPT Solicitud ID: &&P_SOLICITUD_ID
PROMPT =========================================================

SET VERIFY OFF
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 220

COLUMN metrica FORMAT A45
COLUMN valor FORMAT A40

WITH base AS (
  SELECT t.fase,
         t.paso,
         t.detalle,
         t.fecha_evento,
         REGEXP_SUBSTR(t.detalle,'^[^.]+\.[^.]+\.[^ ]+') AS col_full,
         TO_NUMBER(NULLIF(REGEXP_SUBSTR(t.detalle,'filas=([0-9]+)',1,1,NULL,1),'')) AS filas
    FROM tdm_mask_trace t
   WHERE t.ejecucion_id = &&P_EJECUCION_ID AND SOLICITUD_ID=&&P_SOLICITUD_ID
),
aplicadas AS (
  SELECT DISTINCT col_full
    FROM base
   WHERE fase = 'MASK'
     AND paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
     AND col_full IS NOT NULL
),
omitidas AS (
  SELECT DISTINCT col_full
    FROM base
   WHERE fase = 'MASK'
     AND paso LIKE 'SKIP%'
     AND col_full IS NOT NULL
),
agg AS (
  SELECT (SELECT COUNT(*) FROM aplicadas) applied_cols,
         (SELECT COUNT(*) FROM omitidas) skipped_cols,
         (SELECT NVL(SUM(filas),0)
            FROM base
           WHERE fase = 'MASK'
             AND paso IN ('APPLY_COL','APPLY_COL_COLLISION','APPLY_COL_SAFE_FALLBACK')
         ) rows_affected,
         (SELECT COUNT(*)
            FROM base
           WHERE fase = 'POST_SYNC'
             AND paso IN ('WARN_SYNC_LEN','WARN_SYNC','WARN_SYNC_CHECK')
         ) post_sync_warns
    FROM dual
)
SELECT 'Esquema' AS metrica, '&&P_ESQUEMA' AS valor FROM dual
UNION ALL
SELECT 'Ejecucion ID', TO_CHAR(&&P_EJECUCION_ID) FROM dual
UNION ALL
SELECT 'Columnas aplicadas (MASK APPLY*)', TO_CHAR(applied_cols) FROM agg
UNION ALL
SELECT 'Columnas omitidas (MASK SKIP*)', TO_CHAR(skipped_cols) FROM agg
UNION ALL
SELECT 'Registros afectados (suma filas=)', TO_CHAR(rows_affected) FROM agg
UNION ALL
SELECT 'Warnings post-sync', TO_CHAR(post_sync_warns) FROM agg
UNION ALL
SELECT 'Cumplimiento (%)',
       CASE
         WHEN applied_cols + skipped_cols = 0 THEN '0'
         ELSE TO_CHAR(ROUND((applied_cols * 100) / (applied_cols + skipped_cols), 2))
       END
  FROM agg;

PROMPT
PROMPT --- Motivos de no aplicacion (resumen por paso) ---

COLUMN paso FORMAT A35
SELECT paso, COUNT(*) AS eventos
  FROM tdm_mask_trace
 WHERE ejecucion_id = &&P_EJECUCION_ID AND SOLICITUD_ID=&&P_SOLICITUD_ID
   AND fase = 'MASK'
   AND paso LIKE 'SKIP%'
 GROUP BY paso
 ORDER BY COUNT(*) DESC, paso;

PROMPT
PROMPT --- Columnas omitidas (detalle) ---

COLUMN columna FORMAT A90
SELECT DISTINCT REGEXP_SUBSTR(detalle,'^[^.]+\.[^.]+\.[^ ]+') AS columna,
       paso,
       detalle
  FROM tdm_mask_trace
 WHERE ejecucion_id = &&P_EJECUCION_ID AND SOLICITUD_ID=&&P_SOLICITUD_ID
   AND fase = 'MASK'
   AND paso LIKE 'SKIP%'
 ORDER BY columna, paso;

PROMPT
PROMPT --- Warnings de sincronizacion (si existen) ---

SELECT fase, paso, detalle, fecha_evento
  FROM tdm_mask_trace
 WHERE ejecucion_id = &&P_EJECUCION_ID AND SOLICITUD_ID=&&P_SOLICITUD_ID
   AND fase = 'POST_SYNC'
   AND paso IN ('WARN_SYNC_LEN','WARN_SYNC','WARN_SYNC_CHECK')
 ORDER BY fecha_evento;

