 --ORA-15110: no diskgroups mounted
 
 select group_number, name, total_mb, free_mb, state from v$asm_diskgroup;
 
 alter diskgroup DG_FRA_DWHD mount;
