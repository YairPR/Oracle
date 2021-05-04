#!/bin/bash
###If an ASMLIB disk was already deleted, it will not show in /dev/oracleasm/disks. We can check for devices that are (or were) 
###associated with ASM(LIB) with the following shell script:
### Note : The kfed binary should be available in RDBMS home (prior to version 11.2) and in the Grid Infrastructure home (in version 11.2 and later). 
### For the purpose of this post I have assumed Grid Infrastructure version to be 11.2 or higher.
### ./kfed read /dev/dm-7 | grep ORCL
GRID_HOME=`cat /etc/oratab  | grep ^+ASM | awk -F":" '{print $2}'`
for device in `ls /dev/sd*`
  do
    asmdisk=`$GRID_HOME/bin/kfed read $device | grep ORCL | tr -s ' ' | cut -f2 -d' ' | cut -c1-4`
    if [ "$asmdisk" = "ORCL" ]
      then
      echo "Disk device $device may be an ASM disk"
    fi
done
