-- Muestra el sqltext en ejecución según el valor de HASH y ADDRESS

set define on
set verify off
SELECT * FROM V$SQLTEXT WHERE Address='&address' AND Hash_Value='&hash' Order by Piece;
set verify on


RESULT:
-------

ADDRESS 	 HASH_VALUE SQL_ID	  COMMAND_TYPE	    PIECE         SQL_TEXT
---------------- ---------- ------------- ------------ -----------------------------------------------------
00000000C9A057D0 2094452579 cqj25r1yddmv3	    47		0     Begin PQ_INT_UTIL.P_SYS_ETL_TRANSFERIR_CORE(:1,3784); End;

