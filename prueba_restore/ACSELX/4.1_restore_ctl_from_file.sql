run {
allocate channel c1 type 'SBT_TAPE';
send 'NSR_ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=xx.com.pe)';
set until time "to_date('2020-01-26 06:00:00', 'yyyy-mm-dd hh24:mi:ss')";
restore controlfile from 'c-4210056700-20200126-03';
release channel c1;
}
