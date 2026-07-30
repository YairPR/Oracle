/* ejemplos_5_registros_por_punto_funcional_sigad*/

WITH
p2 AS (
  SELECT 'PUNTO 2' punto_funcional,
         'SEGUSUARIO' origen,
         TO_CHAR(s.idusuario) id_ref,
         'IDTIPODOC='||TO_CHAR(s.idtipodocumento)||' NDOC='||s.ndocumento detalle_1,
         CASE
           WHEN s.idtipodocumento = 1 AND REGEXP_LIKE(s.ndocumento,'^[0-9]{8}[A-Z]$') THEN 'OK_NIF'
           WHEN s.idtipodocumento = 3 AND REGEXP_LIKE(s.ndocumento,'^[XYZ][0-9]{7}[A-Z]$') THEN 'OK_NIE'
           WHEN s.idtipodocumento IN (1,3) THEN 'NO_CUMPLE_FORMATO'
           ELSE 'OTRO_TIPO'
         END estado,
         ROW_NUMBER() OVER (ORDER BY s.idusuario) rn
    FROM sigad_acad_own.segusuario s
   WHERE s.idtipodocumento IN (1,3)
     AND s.ndocumento IS NOT NULL
),
p3 AS (
  SELECT 'PUNTO 3' punto_funcional,
         'CENCUENTABANCO' origen,
         TO_CHAR(ROW_NUMBER() OVER (ORDER BY c.numerocuenta)) id_ref,
         'NUMEROCUENTA='||c.numerocuenta detalle_1,
         CASE
           WHEN REGEXP_LIKE(c.numerocuenta,'^ES[0-9]{22}$') THEN 'FORMATO_OK'
           ELSE 'FORMATO_NO_OK'
         END estado,
         ROW_NUMBER() OVER (ORDER BY c.numerocuenta) rn
    FROM sigad_acad_own.cencuentabanco c
   WHERE c.numerocuenta IS NOT NULL
),
p4 AS (
  SELECT 'PUNTO 4' punto_funcional,
         'SEGUSUARIO->PERPROFESOR' origen,
         TO_CHAR(s.idusuario) id_ref,
         'EMAIL_S='||NVL(s.email,'(null)')||' | EMAIL_P='||NVL(p.email,'(null)') detalle_1,
         CASE WHEN NVL(s.email,'#') = NVL(p.email,'#') THEN 'COHERENTE' ELSE 'DIFIERE' END estado,
         ROW_NUMBER() OVER (ORDER BY s.idusuario) rn
    FROM sigad_acad_own.segusuario s
    JOIN sigad_acad_own.perprofesor p
      ON p.idusuario = s.idusuario
),
p5 AS (
  SELECT 'PUNTO 5' punto_funcional,
         d.tabla_destino origen,
         TO_CHAR(s.idusuario) id_ref,
         'S:['||NVL(s.nombre,'(null)')||','||NVL(s.apellido1,'(null)')||','||NVL(s.apellido2,'(null)')||','||NVL(s.ndocumento,'(null)')||
         '] D:['||NVL(d.nombre,'(null)')||','||NVL(d.apellido1,'(null)')||','||NVL(d.apellido2,'(null)')||','||NVL(d.ndocumento,'(null)')||']' detalle_1,
         CASE
           WHEN NVL(s.nombre,'#') = NVL(d.nombre,'#')
            AND NVL(s.apellido1,'#') = NVL(d.apellido1,'#')
            AND NVL(s.apellido2,'#') = NVL(d.apellido2,'#')
            AND NVL(s.ndocumento,'#') = NVL(d.ndocumento,'#')
           THEN 'COHERENTE' ELSE 'DIFIERE'
         END estado,
         ROW_NUMBER() OVER (PARTITION BY d.tabla_destino ORDER BY s.idusuario) rn
    FROM sigad_acad_own.segusuario s
    JOIN (
      SELECT 'CENALUMNO' tabla_destino, idusuario, nombre, apellido1, apellido2, ndocumento
        FROM sigad_acad_own.cenalumno
      UNION ALL
      SELECT 'CENFAMILIAR', idusuario, nombre, apellido1, apellido2, ndocumento
        FROM sigad_acad_own.cenfamiliar
      UNION ALL
      SELECT 'PERPROFESOR', idusuario, nombre, apellido1, apellido2, ndocumento
        FROM sigad_acad_own.perprofesor
    ) d
      ON d.idusuario = s.idusuario
)
SELECT punto_funcional, origen, id_ref, detalle_1, estado
  FROM p2
 WHERE rn <= 5
UNION ALL
SELECT punto_funcional, origen, id_ref, detalle_1, estado
  FROM p3
 WHERE rn <= 5
UNION ALL
SELECT punto_funcional, origen, id_ref, detalle_1, estado
  FROM p4
 WHERE rn <= 5
UNION ALL
SELECT punto_funcional, origen, id_ref, detalle_1, estado
  FROM p5
 WHERE rn <= 5
ORDER BY punto_funcional, origen, id_ref;

