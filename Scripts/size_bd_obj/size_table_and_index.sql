WITH tables AS (
  SELECT 
    segment_name AS tname, 
    TO_CHAR(bytes / 1024 / 1024, '999,999.99') AS table_size
  FROM 
    user_segments
  WHERE 
    segment_type = 'TABLE'
    AND segment_name NOT LIKE 'BIN%'
),
indexes AS (
  SELECT 
    ic.table_name, 
    ic.index_name, 
    LISTAGG(ic.column_name, ', ') WITHIN GROUP (ORDER BY ic.column_position) AS scbp,
    ROW_NUMBER() OVER (PARTITION BY ic.table_name ORDER BY ic.index_name) AS rn,
    TO_CHAR(s.bytes / 1024 / 1024, '999,999.99') AS index_size
  FROM 
    user_ind_columns ic
    LEFT JOIN user_segments s 
      ON ic.index_name = s.segment_name 
      AND s.segment_type = 'INDEX'
  GROUP BY 
    ic.table_name, ic.index_name, s.bytes
)
SELECT 
  CASE WHEN NVL(rn, 1) = 1 THEN t.tname ELSE NULL END AS tname,
  CASE WHEN NVL(rn, 1) = 1 THEN t.table_size ELSE NULL END AS table_size,
  rn AS "INDEX#",
  i.scbp AS columns_in_index,
  i.index_name,
  i.index_size
FROM 
  tables t
  LEFT JOIN indexes i
    ON t.tname = i.table_name
WHERE 
  t.tname = UPPER('&1')
ORDER BY 
  t.tname, i.rn;

