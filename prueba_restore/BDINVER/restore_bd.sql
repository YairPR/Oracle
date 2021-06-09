run {
allocate channel c1 type 'SBT_TAPE';
send 'NSR_ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=rssibdinver01.rimac.com.pe)';
set until time "to_date('2021-05-28 02:59', 'yyyy-mm-dd hh24:mi:ss')";
restore controlfile;
sql "ALTER DATABASE MOUNT";
restore database;
recover database;
release channel c1;
}
