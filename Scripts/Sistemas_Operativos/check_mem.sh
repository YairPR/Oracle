#!/usr/bin/ksh
#memory calculator
um=`svmon -G | head -2|tail -1| awk {'print $3'}`
um=`expr $um / 256`
tm=`lsattr -El sys0 -a realmem | awk {'print $2'}`
tm=`expr $tm / 1000`
fm=`expr $tm - $um`
echo "\n\n-----------------------";
echo "System : (`hostname`)";
echo "-----------------------\n\n";

echo "\n\n-----------------------";
echo " Users Login information \n";

for ENTRY in `finger | cut -d " " -f1 | grep -v Login | uniq`
do
echo "`finger -l $ENTRY | head -1 | cut -d \" \" -f14` ---> `finger -l $ENTRY |
awk '{ print $2 }' | tail -2 | head -1`";
#finger -l $ENTRY | awk '{ print $2 }' | tail -2 | head -1;
done
echo "-----------------------\n";

echo "\n----------------------";
echo "Memory Information\n\n";
echo "total memory = $tm MB"
echo "free memory = $fm MB"
echo "used memory = $um MB"
echo "\n\n-----------------------\n";
