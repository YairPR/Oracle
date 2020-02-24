run {
allocate channel c1 type 'SBT_TAPE';
allocate channel c2 type 'SBT_TAPE';
allocate channel c3 type 'SBT_TAPE';
allocate channel c4 type 'SBT_TAPE';
set until time "to_date('2019-11-26 07:05:00', 'yyyy-mm-dd hh24:mi:ss')";
send 'NSR_ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=rsdpedbadm03.rimac.com.pe)';
recover database;
release channel c1;
release channel c2;
release channel c3;
release channel c4;
}

