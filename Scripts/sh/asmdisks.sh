#!/bin/bash
# Lista discos: ASM disk ASMARCH01 is associated on /dev/sdk1 [8, 161]

ls -lh /dev/oracleasm/disks > /tmp/asmdisks1.txt
for ASMdisk in `cat /tmp/asmdisks1.txt | tail -n +2 | awk '{print $10}'`
do
minor=$(grep -i "$ASMdisk" /tmp/asmdisks1.txt | awk '{print $6}')
major=$(grep -i "$ASMdisk" /tmp/asmdisks1.txt | awk '{print $5}' | cut -d"," -f1)
phy_disk=$(ls -l /dev/* | grep ^b | grep "$major, *$minor" | awk '{print $10}')
echo "ASM disk $ASMdisk is associated on $phy_disk [$major, $minor]"
done
