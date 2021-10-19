run
{
allocate channel c1 type 'SBT_TAPE';
send 'NSR_ENV=(NSR_SERVER=legato,NSR_CLIENT= xx.com.pe)';
restore controlfile;
alter database mount;
}
exit;
