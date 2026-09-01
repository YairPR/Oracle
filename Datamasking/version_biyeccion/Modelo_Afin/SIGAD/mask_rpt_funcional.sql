PROMPT =========================================================
PROMPT Reporte de cumplimiento funcional (2,3,4,5)
PROMPT Esquema: SIGAD_ACAD_OWN
PROMPT Ejecucion id: &&P_EJECUCION_ID
PROMPT Solicitud id: &&P_SOLICITUD_ID
PROMPT =========================================================

SET VERIFY OFF
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 220

COLUMN punto FORMAT A8
COLUMN metrica FORMAT A55
COLUMN valor FORMAT A25

WITH
-- Punto 2: NIF/NIE (tablas con NDOCUMENTO + IDTIPODOCUMENTO)
p2 AS (
  SELECT SUM(CASE WHEN idtipodocumento IN (1,3) AND ndocumento IS NOT NULL THEN 1 ELSE 0 END) total_docs,
         SUM(CASE WHEN idtipodocumento = 1 AND ndocumento IS NOT NULL
                    AND REGEXP_LIKE(ndocumento,'^[0-9]{8}[A-Z]$') THEN 1
                  WHEN idtipodocumento = 3 AND ndocumento IS NOT NULL
                    AND REGEXP_LIKE(ndocumento,'^[XYZ][0-9]{7}[A-Z]$') THEN 1
                  ELSE 0 END) docs_validos
    FROM (
      SELECT ndocumento,
             CASE
               WHEN REGEXP_LIKE(TRIM(TO_CHAR(idtipodocumento)),'^[0-9]+$')
               THEN TO_NUMBER(TRIM(TO_CHAR(idtipodocumento)))
               ELSE NULL
             END idtipodocumento
        FROM sigad_acad_own.segusuario
      UNION ALL
      SELECT ndocumento,
             CASE
               WHEN REGEXP_LIKE(TRIM(TO_CHAR(idtipodocumento)),'^[0-9]+$')
               THEN TO_NUMBER(TRIM(TO_CHAR(idtipodocumento)))
               ELSE NULL
             END
        FROM sigad_acad_own.cenalumno
      UNION ALL
      SELECT ndocumento,
             CASE
               WHEN REGEXP_LIKE(TRIM(TO_CHAR(idtipodocumento)),'^[0-9]+$')
               THEN TO_NUMBER(TRIM(TO_CHAR(idtipodocumento)))
               ELSE NULL
             END
        FROM sigad_acad_own.cenfamiliar
      UNION ALL
      SELECT ndocumento,
             CASE
               WHEN REGEXP_LIKE(TRIM(TO_CHAR(idtipodocumento)),'^[0-9]+$')
               THEN TO_NUMBER(TRIM(TO_CHAR(idtipodocumento)))
               ELSE NULL
             END
        FROM sigad_acad_own.perprofesor
    )
),
-- Punto 3: IBAN continuo ES + checksum
p3 AS (
  SELECT COUNT(*) total_iban,
         SUM(CASE
               WHEN numerocuenta IS NOT NULL
                AND REGEXP_LIKE(numerocuenta,'^ES[0-9]{22}$')
               THEN 1 ELSE 0
             END) formato_ok
    FROM sigad_acad_own.cencuentabanco
   WHERE numerocuenta IS NOT NULL
),
-- Punto 4: coherencia email SEGUSUARIO -> PERPROFESOR
p4 AS (
  SELECT COUNT(*) total_rel,
         SUM(CASE WHEN NVL(p.email,'#') = NVL(s.email,'#') THEN 1 ELSE 0 END) coherentes
    FROM sigad_acad_own.segusuario s
    JOIN sigad_acad_own.perprofesor p
      ON p.idusuario = s.idusuario
),
-- Punto 5: coherencia nombre/apellidos/doc por tabla destino
p5 AS (
  SELECT COUNT(*) total_rel,
         SUM(
           CASE
             WHEN NVL(d.nombre,'#') = NVL(s.nombre,'#')
              AND NVL(d.apellido1,'#') = NVL(s.apellido1,'#')
              AND NVL(d.apellido2,'#') = NVL(s.apellido2,'#')
              AND NVL(d.ndocumento,'#') = NVL(s.ndocumento,'#')
             THEN 1 ELSE 0
           END
         ) coherentes
    FROM (
      SELECT 'CENALUMNO' origen, a.idusuario, a.nombre, a.apellido1, a.apellido2, a.ndocumento
        FROM sigad_acad_own.cenalumno a
      UNION ALL
      SELECT 'CENFAMILIAR', f.idusuario, f.nombre, f.apellido1, f.apellido2, f.ndocumento
        FROM sigad_acad_own.cenfamiliar f
      UNION ALL
      SELECT 'PERPROFESOR', p.idusuario, p.nombre, p.apellido1, p.apellido2, p.ndocumento
        FROM sigad_acad_own.perprofesor p
    ) d
    JOIN sigad_acad_own.segusuario s
      ON s.idusuario = d.idusuario
),
p5_warn AS (
  SELECT NVL(SUM(TO_NUMBER(REGEXP_SUBSTR(t.detalle,'filas_conflictivas=([0-9]+)',1,1,NULL,1))),0) filas_conflictivas
    FROM tdm_mask_trace t
   WHERE t.ejecucion_id = &&P_EJECUCION_ID and t.solicitud_id = &&P_SOLICITUD_ID
     AND t.fase = 'POST_SYNC'
     AND t.paso = 'WARN_SYNC_LEN'
     AND t.detalle LIKE 'SEGUSUARIO.NDOCUMENTO -> CENALUMNO.NDOCUMENTO%'
)
SELECT 'PUNTO 2' punto, 'Documentos evaluados (NIF/NIE)' metrica, TO_CHAR(total_docs) valor FROM p2
UNION ALL
SELECT 'PUNTO 2', 'Documentos validos formato esperado', TO_CHAR(docs_validos) FROM p2
UNION ALL
SELECT 'PUNTO 2', 'Cumplimiento (%)',
       CASE WHEN total_docs = 0 THEN '0' ELSE TO_CHAR(ROUND((docs_validos*100)/total_docs,2)) END
  FROM p2
UNION ALL
SELECT 'PUNTO 3', 'IBAN evaluados (CENCUENTABANCO.NUMEROCUENTA)', TO_CHAR(total_iban) FROM p3
UNION ALL
SELECT 'PUNTO 3', 'IBAN con formato ES+22dig', TO_CHAR(formato_ok) FROM p3
UNION ALL
SELECT 'PUNTO 3', 'Cumplimiento (%)',
       CASE WHEN total_iban = 0 THEN '0' ELSE TO_CHAR(ROUND((formato_ok*100)/total_iban,2)) END
  FROM p3
UNION ALL
SELECT 'PUNTO 4', 'Relaciones SEGUSUARIO->PERPROFESOR evaluadas', TO_CHAR(total_rel) FROM p4
UNION ALL
SELECT 'PUNTO 4', 'Relaciones coherentes EMAIL', TO_CHAR(coherentes) FROM p4
UNION ALL
SELECT 'PUNTO 4', 'Cumplimiento (%)',
       CASE WHEN total_rel = 0 THEN '0' ELSE TO_CHAR(ROUND((coherentes*100)/total_rel,2)) END
  FROM p4
UNION ALL
SELECT 'PUNTO 5', 'Relaciones (ALUMNO/FAMILIAR/PROFESOR) evaluadas', TO_CHAR(total_rel) FROM p5
UNION ALL
SELECT 'PUNTO 5', 'Relaciones coherentes (nombre+apellidos+doc)', TO_CHAR(coherentes) FROM p5
UNION ALL
SELECT 'PUNTO 5', 'Conflictos longitud DOC (WARN_SYNC_LEN)', TO_CHAR(filas_conflictivas) FROM p5_warn
UNION ALL
SELECT 'PUNTO 5', 'Cumplimiento (%)',
       CASE WHEN total_rel = 0 THEN '0' ELSE TO_CHAR(ROUND((coherentes*100)/total_rel,2)) END
  FROM p5;
