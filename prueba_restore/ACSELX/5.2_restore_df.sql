run {
allocate channel c1 type 'SBT_TAPE';
allocate channel c2 type 'SBT_TAPE';
allocate channel c3 type 'SBT_TAPE';
allocate channel c4 type 'SBT_TAPE';
allocate channel c5 type 'SBT_TAPE';
allocate channel c6 type 'SBT_TAPE';
send 'NSR_ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=minerva.rimac.com.pe)';
set until time "to_date('2020-01-25 22:00:00', 'yyyy-mm-dd hh24:mi:ss')";
restore datafile '/oracle005/oradata/PROD/data/data_prod_ssd_big_001.dbf', '/oracle001/oradata/PROD/data/data_prod_notrans_big_006.dbf', '/oracle003/oradata/PROD/indx/indx_prod_notrans_med_015.dbf', '/oracle004/oradata/PROD/indx/indx_prod_notrans_med_017.dbf'; 
release channel c1;
release channel c2;
release channel c3;
release channel c4;
release channel c5;
release channel c6;
}
exit;
