run {
allocate channel c1 type 'SBT_TAPE';
allocate channel c2 type 'SBT_TAPE';
allocate channel c3 type 'SBT_TAPE';
allocate channel c4 type 'SBT_TAPE';
set DBID=3980960829
SET NEWNAME FOR DATABASE TO '+DATA';
send 'NSR_ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=rsdpedbadm03.rimac.com.pe)';
set until time "to_date('2021-03-29 04:20:08', 'yyyy-mm-dd hh24:mi:ss')";
restore controlfile;
sql 'ALTER DATABASE MOUNT';
restore database;
switch datafile all;
sql 'ALTER DATABASE FLASHBACK OFF';
recover database;
release channel c1;
release channel c2;
release channel c3;
release channel c4;
}
