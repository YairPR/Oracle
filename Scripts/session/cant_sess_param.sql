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
