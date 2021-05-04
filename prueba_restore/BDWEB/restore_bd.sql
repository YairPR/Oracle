allocate channel for maintenance type disk;
allocate channel for maintenance device type 'sbt_tape' parms 'ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=rsdcpdbbdweb01.rimac.com.pe)';
run {
allocate channel c1 type 'SBT_TAPE';
set DBID=1099557380
send 'NSR_ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=rsdcpdbbdweb01.rimac.com.pe)';
set until time "to_date('2021-03-28 18:05:38', 'yyyy-mm-dd hh24:mi:ss')";
restore controlfile;
sql 'ALTER DATABASE MOUNT';
restore database;
recover database;
release channel c1;
}
