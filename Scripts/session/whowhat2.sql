SELECT SQL_TEXT FROM V$SQLAREA WHERE (ADDRESS, HASH_VALUE) IN
(SELECT SQL_ADDRESS, SQL_HASH_VALUE FROM V$SESSION WHERE SID = &amp;sid_number);