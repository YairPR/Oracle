#!/bin/bash
echo INICIO > /oracle/scripts/elimina_arcauds.txt
find /oracle/dbbase/admin/BDREPOS/adump/* -name "*.aud" -type f -exec rm {} \;
echo FIN >> /oracle/scripts/elimina_arcauds.txt
