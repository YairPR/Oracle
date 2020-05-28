set define on
set verify off
SELECT * FROM V$SQLTEXT WHERE Address='&1' AND Hash_Value='&2' Order by Piece;
set verify on
