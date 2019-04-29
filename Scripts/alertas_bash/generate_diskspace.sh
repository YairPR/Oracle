#!/bin/sh
set -x

##########################################################################
#@Author: E. Yair Purisaca Rivera
#@Email: eddiepurisaca@gmail.com
#@Version: 1.0
#@Descripcion: Creacion de formato HTML a partir del archivo plano
##########################################################################

path=/home/oracle/scripts/monitor

cd $path

truncate diskspace_alert.html --size 0

awk 'BEGIN{
    print "<html>\n<head>\n<style>\ntable,th,td\n{\n border:2px solid black\n}\n</style>\n</head>\n<Body>Información del Servidor de Producción<br>\n<br>ATENCION!!\n<br> El Filesystem se encuentra con mas del 90% de uso.<br><br>\n<table align="center">\n<tr><th>Directorio</th><th>% Usado</th>\n<th>Espacio Libre</th>\n</tr>"
    } 
    {print "<tr>"
    for(i=1;i<=NF;i++)
        print "<td>" $i"</td>"
    print "</tr>"
    }
    END {
    print "\n</table>\n<br>\n Saludos,<br>\nE. Yair Purisaca Rivera<br>\nAdministrador de Base de Datos\n</Body>\n</html>\n" 
    }' alert.lst >> diskspace_alert.html
