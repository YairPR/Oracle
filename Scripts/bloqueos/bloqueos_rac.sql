select /*+ RULE */
        'ALERTA BLOQUEOS!, bloqueos en inst. '||l.inst_id ||', SID,serial ' ||l.sid||','||s.serial#||', modulo '||s.module||decode(substr(s.action,1,3),'FRM',', usuario '||substr(s.action,instr( s.action, ':',1,1) + 1, instr( s.action, ':',1,2) - instr( s.action, ':',1,1) - 1),'')  ||', desde '||s.machine||', logon '||to_char(s.LOGON_TIME,'dd/mm/yyyy hh24:mi:ss')||decode(l.lmode,6,', sesion BLOQUEANTE',', sesion EN ESPERA') as mensaje
from   gv$lock l,
       gv$session s
where    ( l.ID1,l.ID2,l.TYPE)  in (select J.ID1,J.ID2,J.TYPE from gv$lock J where J.request>0) and
         (s.inst_id = l.inst_id and
          s.sid = l.sid)
/
--exit
