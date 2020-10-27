run {
allocate channel c1 type 'SBT_TAPE';
allocate channel c2 type 'SBT_TAPE';
allocate channel c3 type 'SBT_TAPE';
allocate channel c4 type 'SBT_TAPE';
set DBID=233382885
SET NEWNAME FOR DATABASE TO '+DATA';
send 'NSR_ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=rsdpedbadm03.rimac.com.pe)';
set until time "to_date('2020-09-30 18:33:20', 'yyyy-mm-dd hh24:mi:ss')";
restore controlfile;
sql 'ALTER DATABASE MOUNT';
restore database;
switch datafile all;
recover database;
release channel c1;
release channel c2;
release channel c3;
release channel c4;
}
