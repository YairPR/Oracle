####the od command dumps the files in octal and other formats. -c option is to select ASCII characters or backslash escapes

#!/bin/bash
for device in `ls /dev/sd*`
do
  asmdisk=`od -c $device | head | grep 0000040 | tr -d ' ' | cut -c8-11`
  if [ "$asmdisk" = "ORCL" ]
    then
    echo "Disk device $device may be an ASM disk"
  fi
done
