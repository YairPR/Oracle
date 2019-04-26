/*
@Author: E. Yair Purisaca R.
@Email: eddiepurisaca@gmail.com
DATABASE SIZE*/

-- Phisical total
SELECT floor(sum(bytes)/1024/1024/1024) AS "Tamaño(GB)" 
FROM dba_data_files;

-- In Using
SELECT floor(sum(bytes)/1024/1024/1024) AS "Tamaño(GB)" 
FROM dba_segments;

-- Size for schema
SELECT owner, floor(sum(bytes)/1024/1024) Size_MB 
FROM dba_segments
WHERE owner IN ('SCHEMA')  
GROUP  BY owner
ORDER BY 2 DESC;
