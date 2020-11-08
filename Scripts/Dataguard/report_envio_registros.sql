/*
Si tenemos varios entornos de base de datos en espera física de Data Guard para administrar, el siguiente informe puede ayudarnos rápidamente
identificar el registro transportado y el estado de registro aplicado de las bases de datos primaria y en espera en nuestro entorno y si hay alguna en espera
La base de datos también está rezagada con respecto a la primaria.

La secuencia de comandos también se puede personalizar para enviar por correo electrónico una notificación de alerta si el modo de espera y el principal no están sincronizados por decir 5
archivos de registro. Envíeme un mensaje si necesita ese script de personalización.

Este informe se basa en un script de shell de Unix (check_logship.sh) que a su vez llama a un script de SQL (check_logship.sql).

El script requiere que se cree un MONITOR de usuario en cada base de datos de destino con CONNECT y SELECT ANY DICTIONARY
privilegios. También tenemos un archivo de configuración (en nuestro caso bw_dg.lst) que contendrá la lista de todos los alias TNS del
Bases de datos primarias que necesitamos monitorear.

RESULT:

[PROD] emrep:/u01/oracle/scripts > ./check_logship.sh

#######################################################################################
	Data Guard Log Shipping Summary Report:  Thu Jul 16 14:22:02 WAUST 2009
#######################################################################################

DB_NAME  HOSTNAME     LOG_ARCHIVED LOG_APPLIED APPLIED_TIME  LOG_GAP
-------- ------------ ------------ ----------- ------------  -------

GENPRD   CBDORCA201          16742       16742 16-JUL/14:12       0


CPSPRD   PRDU009N1           11494       11494 16-JUL/14:10       0


LN1P     CBDORCA101          51173       51171 16-JUL/12:25       2


LA1P     CBDORCA105          76971       76970 16-JUL/13:10       1

#######################################################################################

*/

--------------------------------------------------------------------------------------
########################
#   check_logship.sql  #
########################

SET PAGESIZE 124
SET HEAD OFF
COL DB_NAME FORMAT A8
COL HOSTNAME FORMAT A12
COL LOG_ARCHIVED FORMAT 999999
COL LOG_APPLIED FORMAT 999999
COL LOG_GAP FORMAT 9999
COL APPLIED_TIME FORMAT A12
SELECT DB_NAME, HOSTNAME, LOG_ARCHIVED, LOG_APPLIED,APPLIED_TIME,
LOG_ARCHIVED-LOG_APPLIED LOG_GAP
FROM
(
SELECT NAME DB_NAME
FROM V$DATABASE
),
(
SELECT UPPER(SUBSTR(HOST_NAME,1,(DECODE(INSTR(HOST_NAME,'.'),0,LENGTH(HOST_NAME),
(INSTR(HOST_NAME,'.')-1))))) HOSTNAME
FROM V$INSTANCE
),
(
SELECT MAX(SEQUENCE#) LOG_ARCHIVED
FROM V$ARCHIVED_LOG WHERE DEST_ID=1 AND ARCHIVED='YES'
),
(
SELECT MAX(SEQUENCE#) LOG_APPLIED
FROM V$ARCHIVED_LOG WHERE DEST_ID=1 AND APPLIED='YES'
),
(
SELECT TO_CHAR(MAX(COMPLETION_TIME),'DD-MON/HH24:MI') APPLIED_TIME
FROM V$ARCHIVED_LOG WHERE DEST_ID=2 AND APPLIED='YES'
);

--------------------------------------------------------------------------------------------

######################
#  check_logship.sh  #
######################

if [ -f /tmp/dataguard1.out ]
then
rm /tmp/dataguard1.out
fi

if [ -f /tmp/dataguard2.out ]
then
rm /tmp/dataguard2.out
fi

export SCRPT=/u01/app/scripts

for i in `cat $SCRPT/bw_dg.lst`
do
sqlplus -s monitor/xxx@$i <> /tmp/dataguard2.out
@/$SCRPT/check_logship.sql
EOF
echo “#######################################################################################” > /tmp/dataguard1.out
echo ” Data Guard Log Shipping Summary Report: `date ` ” >> /tmp/dataguard1.out
echo “#######################################################################################” >> /tmp/dataguard1.out
echo >> /tmp/dataguard1.out
echo “DB_NAME HOSTNAME LOG_ARCHIVED LOG_APPLIED APPLIED_TIME LOG_GAP” >> /tmp/dataguard1.out
echo “——– ———— ———— ———– ———— ——-” >> /tmp/dataguard1.out
cat /tmp/dataguard2.out >> /tmp/dataguard1.out
done
cat /tmp/dataguard1.out

-------------------------------------------------------------------------------------------

