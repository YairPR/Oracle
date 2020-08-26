run {
allocate channel c1 type 'SBT_TAPE';
allocate channel c2 type 'SBT_TAPE';
allocate channel c3 type 'SBT_TAPE';
allocate channel c4 type 'SBT_TAPE';
send 'NSR_ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=rsdcpdbconta01.rimac.com.pe)';
set until time "to_date('2020-07-26 21:31:00', 'yyyy-mm-dd hh24:mi:ss')";
restore controlfile;
sql 'ALTER DATABASE MOUNT';
restore database;
recover database;
release channel c1;
release channel c2;
release channel c3;
release channel c4;
}
