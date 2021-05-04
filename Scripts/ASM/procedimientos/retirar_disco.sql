### Este instructivo que les dejo hace referencia al delete de discos : Linux en VMWare
---Delete de discos, miembros de un diskgroup, de la instancia ASM.
---Delete de discos, miembros de un diskgroup, del sistema operativo tipo unix (En mi caso RHL).

Nota: Al momento de quitar el disco , comenzará el rebalanceo de los datos dentro de los discos que quedaron en el storage. 
      Una vez que finalice el Rebalanceo, el disco desaparecerá por completo.
Previa:
Lista de discos: shells/asmdisks.sh
ASM disk ASMARCH01 is associated on /dev/sdk1 [8, 161]
ASM disk ASMDATA01 is associated on /dev/sdd1 [8, 49]
ASM disk ASMDATA02 is associated on /dev/sde1 [8, 65]
ASM disk ASMDATA03 is associated on /dev/sdf1 [8, 81]
ASM disk ASMDATA04 is associated on /dev/sdg1 [8, 97]
ASM disk ASMDATA08 is associated on /dev/sdh1 [8, 113]
ASM disk ASMDATA09 is associated on /dev/sdi1 [8, 129]
ASM disk ASMDATA10 is associated on /dev/sdp1 [8, 241]
ASM disk ASMDATA12 is associated on /dev/sdj1 [8, 145]
ASM disk ASMDATA13 is associated on /dev/sdl1 [8, 177]
ASM disk ASMDATA15 is associated on /dev/sdn1 [8, 209]
ASM disk ASMDATA16 is associated on /dev/sdm1 [8, 193]
ASM disk ASMDATA17 is associated on /dev/sdo1 [8, 225]
ASM disk ASMDATA18 is associated on /dev/sdr1 [65, 17]
ASM disk ASMDATA19 is associated on /dev/sds1 [65, 33]
ASM disk ASMDATA20 is associated on /dev/sdt1 [65, 49]
ASM disk ASMDATA21 is associated on /dev/sdu1 [65, 65]
ASM disk ASMDATA22 is associated on /dev/sdv1 [65, 81]

Paso 1: consultemos en la instancia que discos son los que están disponibles.
col path format a40 
set line 120 
select name, path, group_number from v$asm_disk;

Paso 2: Quitamos el Disco con la siguinte sentencia , donde colocamos el nombre de nuestro diskgroup y el nombre del disco que vamos a quitar.

SQL> ALTER DISKGROUP OT2D1N_DG1 DROP DISK OT2D1N_DG1_0001;

Diskgroup altered.
----
Para borrarlo, igual que disco raw devices,
ALTER .... DROP 'ETIQUETA'
osea ---> DROP 'ORCL:ASM....'


Paso 3: as despues de quitar del DG
ejemplo:
[root@dbserver ~]# oracleasm querydisk -p DBTEST004
Disk "DBTEST004" is a valid ASM disk
/dev/sdag1: LABEL="DBTEST004" TYPE="oracleasm"
/dev/sdaj1: LABEL="DBTEST004" TYPE="oracleasm"
/dev/mapper/mpath44p1: LABEL="DBTEST004" TYPE="oracleasm"
/dev/mapper/mpath45p1: LABEL="DBTEST004" TYPE="oracleasm"

Paso 4
[root@dbserver ~]# /usr/sbin/oracleasm deletedisk DBTEST004
Clearing disk header: done
Dropping disk: done

Paso 5
/etc/init.d/oracleasm scandisks
/etc/init.d/oracleasm listdisks
