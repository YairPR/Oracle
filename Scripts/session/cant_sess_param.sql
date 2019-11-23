-- 9i,10g,11g,12c
-- Cantidad de sesiones basandose en el parametro sessions
SELECT
  'Currently, ' 
  || (SELECT COUNT(*) FROM V$SESSION)
  || ' out of ' 
  || VP.VALUE 
  || ' connections are used.' AS USAGE_MESSAGE
FROM 
  V$PARAMETER VP
WHERE VP.NAME = 'sessions';


Result:
--------
USAGE_MESSAGE
--------------------------------------------------------------------------------
Currently, 1034 out of 4185 connections are used.

