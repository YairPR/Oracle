run
{
allocate channel c1 type 'SBT_TAPE';
send 'NSR_ENV=(NSR_SERVER=legato.rimac.com.pe,NSR_CLIENT=minerva.rimac.com.pe)';
restore controlfile;
alter database mount;
}
exit;
