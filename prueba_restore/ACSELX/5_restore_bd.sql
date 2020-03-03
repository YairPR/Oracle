run
{
allocate channel c1 type 'SBT_TAPE';
allocate channel c2 type 'SBT_TAPE';
allocate channel c3 type 'SBT_TAPE';
allocate channel c4 type 'SBT_TAPE';
allocate channel c5 type 'SBT_TAPE';
allocate channel c6 type 'SBT_TAPE';
send 'NSR_ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=minerva.rimac.com.pe)';
set until time "to_date('2020-01-26 06:00:00', 'yyyy-mm-dd hh24:mi:ss')";
restore database;
recover database;
}
exit;
