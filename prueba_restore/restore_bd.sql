run {
allocate channel c1 type 'SBT_TAPE';
send 'NSR_ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=rssbbdbpm02.rimac.com.pe)';
set until time "to_date('2019-11-22 19:15:00', 'yyyy-mm-dd hh24:mi:ss')";
restore controlfile;
sql 'ALTER DATABASE MOUNT';
restore database;
switch datafile all;
recover database;
release channel c1;
}

