$ cat script4_3.sh
HA=`date +%y%m%d%H%M%S`
ARCHIVO=04_3_DiagnosticosHospitalizacion
ARCHIVOSPOOL=./${ARCHIVO}.csv
CIERRELOG=./${ARCHIVO}.log

sqlplus -S  / as sysdba << FIN 

set linesize 2000
set termout off
set verify off
set colsep ","
set headsep off
set pagesize 0
set trimspool on

spool '${ARCHIVOSPOOL}'

---------------------------------------------------
--- 04.3) Diagnósticos - Hospitalización TAB_DIAGNO
---------------------------------------------------
select a.actmedpacsecnum+333333            as RELANUM,
       d.redasiscod                        as REDASISCOD,
       t.atenhoscenasicod                  as CENASISCOD,
       t.atenhosactmednum                  as ACTOASISNUM,
       t.atenhosnumsec                     as ACTOASISSECNUM,
       t.diagcod                           as DIAGCOD,
       e.redasismeddes                     as REDASISDES,
       d.cenasides                         as CENASISDES,
       f.diagdes                           as DIAGDES,
       t.atenhosdiagord                    as DIAGORDNUM,
       t.atenhostipodiagcod                as DIAGTIPOCOD,
       null                                as DIAGALTAFLG,
       to_char(b.atenhosfec,'dd/mm/yyyy')  as ATENFEC,
       b.atenhosarehoscod                  as AREAHOSPCOD,
       g.arehosdes                         as AREAHOSPDES,
       b.atenhosservhoscod                 as SERVHOSPCOD,
       h.servhosdes                        as SERVHOSPDES,
       null                                as TOPIEMERCOD,
       null                                as TOPIEMERDES
  from sgss.HTDAH10 t
  left outer join sgss.CMAME10 a on t.atenhosoricenasicod = a.oricenasicod
                                and t.atenhoscenasicod    = a.cenasicod
                                and t.atenhosactmednum    = a.actmednum
  left outer join sgss.HTAHO10 b on t.atenhosoricenasicod = b.atenhosoricenasicod
                                and t.atenhoscenasicod    = b.atenhoscenasicod
                                and t.atenhosactmednum    = b.atenhosactmednum
                                and t.atenhosnumsec       = b.atenhosnumsec         
  left outer join sgss.CMCAS10 d on t.atenhosoricenasicod = d.oricenasicod
                                and t.atenhoscenasicod    = d.cenasicod
  left outer join sgss.CMRAS10 e on d.redasiscod          = e.redasiscod
  left outer join sgss.CMDIA10 f on t.diagcod             = f.diagcod
  left outer join sgss.CMAHO10 g on b.atenhosarehoscod    = g.arehoscod
  left outer join sgss.CMSHO10 h on b.atenhosservhoscod   = h.servhoscod
 where to_char(b.atenhosfec,'yyyymm') >= '201901'
   and to_char(b.atenhosfec,'yyyymm') <= '202105'
/


spool off;

set termout on

FIN
