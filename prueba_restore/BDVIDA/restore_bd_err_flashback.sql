run {
allocate channel c1 type 'SBT_TAPE';
allocate channel c2 type 'SBT_TAPE';
allocate channel c3 type 'SBT_TAPE';
allocate channel c4 type 'SBT_TAPE';
allocate channel c5 type 'SBT_TAPE';
allocate channel c6 type 'SBT_TAPE';
send 'NSR_ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=rsdpedbadm01.rimac.com.pe)';
set until time "to_date('2020-09-30 12:36:32', 'yyyy-mm-dd hh24:mi:ss')";
recover database;
release channel c1;
release channel c2;
release channel c3;
release channel c4;
release channel c5;
release channel c6;
}
