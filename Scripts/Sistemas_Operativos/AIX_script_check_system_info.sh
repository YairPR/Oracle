--[AIX] System Information collection Script

#! /bin/ksh
# Make by. chhan

DATEC=$(date +%Y%m%d-%H%M)
IdChk=`id | grep root | wc -l`
OutFile="`hostname`_"$DATEC".txt"

#Checking ROOT 
if [ $IdChk -eq 0 ]; then
   echo
   echo "You must login root... Try again..."
   echo
   exit
 fi

echo " * * * * * Check AIX System Information * * * * * " 
echo " " 
echo " This Check Output File "
echo " View ./"$OutFile
echo " Date : " $(date)
echo " "
echo " # Gethering Information . . . . . "

prtconf > /tmp/prtconf-$DATEC.txt
sleep 1

cputype=$(cat /tmp/prtconf-$DATEC.txt | grep "Processor Type" | awk -F ":" '{print $2}')
kerneltype=$(cat /tmp/prtconf-$DATEC.txt | grep "Kernel Type" | awk -F ":" '{print $2}')
sizemem=$(cat /tmp/prtconf-$DATEC.txt | grep "^Memory Size" | awk -F ":" '{print $2}')
cpucore=$(cat /tmp/prtconf-$DATEC.txt | grep "Number Of Processors" | awk -F ":" '{print $2}')
ipaddr=$(cat /tmp/prtconf-$DATEC.txt | grep "IP Address:" | awk -F ":" '{print $2}')
subnet=$(cat /tmp/prtconf-$DATEC.txt | grep "Sub Netmask:" | awk -F ":" '{print $2}')
gateway=$(cat /tmp/prtconf-$DATEC.txt | grep "Gateway:" | awk -F ":" '{print $2}')
totalps=$(cat /tmp/prtconf-$DATEC.txt | grep "Total Paging Space:" | awk -F ":" '{print $2}')

echo " # Print & Save Information"
echo "-------------------------------------------"| tee -a $OutFile
echo "            System Infomation              "| tee -a $OutFile
echo "-------------------------------------------"| tee -a $OutFile
echo " Host Name :" $(hostname)| tee -a $OutFile
echo " Vender :" $(uname -M | awk -F "," '{print $1}')| tee -a $OutFile
echo " CPU Type :" $cputype| tee -a $OutFile
#echo " Kernel Type :" $kerneltype| tee -a $OutFile
echo " Kernel Bit :" $(getconf KERNEL_BITMODE)"-bit"| tee -a $OutFile
echo " OS Version :" $(oslevel -s)| tee -a $OutFile
echo " Number Of Processors :" $cpucore| tee -a $OutFile
echo " Memory :"  $sizemem | tee -a $OutFile
echo " " | tee -a $OutFile
echo " IP Address :" $ipaddr" /"$subnet| tee -a $OutFile
echo " Gateway IP: " $gateway| tee -a $OutFile
echo " " | tee -a $OutFile
echo " Total Page Space Size :" $totalps| tee -a $OutFile
echo " Detail Page Space :"| tee -a $OutFile
lsps -a| tee -a $OutFile
echo " " | tee -a $OutFile
echo " LVM Information :"| tee -a $OutFile
lsvg -l rootvg| tee -a $OutFile
echo " " | tee -a $OutFile
echo " Total df Size :" | tee -a $OutFile
df -gt| tee -a $OutFile
echo " "| tee -a $OutFile
echo " rootvg Filesystem Size : "| tee -a $OutFile
df -gt | grep "Mounted"| tee -a $OutFile
lsvg -l rootvg | grep "/" | grep -v "N/A" | awk '{print "df -gt "$7}' | sh | grep -v Mounted| tee -a $OutFile
