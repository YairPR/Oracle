--Para ver los bloqueos

set line 200
col Tipo_lock format A11;
col user_b format A12;
col osuser format A12;
col status format A9;
col user_w format A12;
col Objeto_Bloq format A35;
col User_SO_Wait format A12;
set trims on;


PROMPT

PROMPT BLOQUEOS (VISTA POR INSTANCIA) (IZQUIERDA -> USUARIOS QUE BLOQUEAN | DERECHA -> USUARIOS BLOQUEADOS)

PROMPT -------------------------------------------------------------------------------


select decode(bl.lmode , 0, 'None', 1, 'Null', 2, 'Row Share ' ,
                         3, 'Row Excl.', 4, 'Share', 5, 'S/Row Excl' ,
                         6, 'Exclusive', LTRIM(TO_CHAR(bl.lmode,'990'))) as "Tipo_Lock",
to_char(bs.sid,'99999') sid_b, to_char(bs.serial#,'9999999') serial#, bs.username user_b, rpad(bs.osuser,17,' ') OSUSER ,
/*bs.program,*/ bs.status, b.owner||'.'||b.object_name Objeto_Bloq, round(bl.CTIME/60,1) min,
       '|',
       decode(wl.request,0, 'None', 1, 'Null', 2, 'Row Share ' ,
                         3, 'Row Excl.', 4, 'Share', 5, 'S/Row Excl' ,
                         6, 'Exclusive', LTRIM(TO_CHAR(bl.lmode,'990'))) as " w_request",
to_char(wl.sid,'99999') sid_w, ws.username User_W, ws.osuser User_SO_Wait,
/*ws.program,*/ ws.STATUS
from v$lock bl, v$lock wl, v$session bs, v$session ws, sys.v_$locked_object a, sys.all_objects b
where wl.type = bl.type and wl.id1 = bl.id1
      and wl.id2 = bl.id2 and bl.request = 0
      and wl.request != 0 and bl.lmode != 0
      and wl.lmode = 0 and bl.sid = bs.sid (+)
      and wl.sid = ws.sid (+)
      and bs.SID=a.SESSION_ID
      and a.object_id=b.object_id;

PROMPT Consulta a la dba_blockers y en el caso de rac muestra solo a los bloqueantes que esten en la misma instancia (nodo) :

PROMPT

select holding_session as SESIONES_QUE_BLOQUEAN from dba_blockers;


PROMPT Lista de sesiones a matar kill
select 'kill -9 '||a.spid kill
from v$session b, v$process a
where b.paddr = a.addr
and sid in (select  holding_session as SESIONES_QUE_BLOQUEAN from dba_blockers)
/
