
SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET PAGESIZE 100
SET LINESIZE 150
COLUMN TNAME FORMAT A30
COLUMN TABLE_SIZE FORMAT A15
COLUMN "INDEX#" FORMAT 9
COLUMN COLUMNS_IN_INDEX FORMAT A30
COLUMN INDEX_NAME FORMAT A30
COLUMN INDEX_SIZE FORMAT A15

VARIABLE schema_name VARCHAR2(30);
VARIABLE table_name VARCHAR2(30);

BEGIN
  :schema_name := '&schema_name';
  :table_name := '&table_name';
END;
/

WITH tables AS (
  SELECT 
    s.segment_name AS tname, 
    TO_CHAR(s.bytes / 1024 / 1024, '999,999.99') AS table_size
  FROM 
    dba_segments s
  WHERE 
    s.segment_type = 'TABLE'
    AND s.segment_name NOT LIKE 'BIN%'
    AND s.owner = :schema_name
),
indexes AS (
  SELECT 
    ic.table_name, 
    ic.index_name, 
    LISTAGG(ic.column_name, ', ') WITHIN GROUP (ORDER BY ic.column_position) AS scbp,
    ROW_NUMBER() OVER (PARTITION BY ic.table_name ORDER BY ic.index_name) AS rn,
    TO_CHAR(s.bytes / 1024 / 1024, '999,999.99') AS index_size
  FROM 
    dba_ind_columns ic
    LEFT JOIN dba_segments s 
      ON ic.index_name = s.segment_name 
      AND s.segment_type = 'INDEX'
      AND s.owner = :schema_name
  WHERE 
    ic.table_owner = :schema_name
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
  t.tname = :table_name
ORDER BY 
  t.tname, i.rn;
