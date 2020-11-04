[oracle@rsdpedbadm03 ~]$ cat bdvidad_arch_clean.sh
. /home/oracle/bdvidad_uat_exa03.env
rman target / <<EOF
run
{
crosscheck archivelog all;
delete noprompt archivelog until time 'SYSDATE-1';
}
exit;
EOF
