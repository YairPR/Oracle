============
REVISION 2 =
============
           
Buscar sesiones de bloqueo: las sesiones de
bloqueo ocurren cuando una sesión mantiene un bloqueo exclusivo en un objeto y no lo libera antes de que otras
sesiones quieran actualizar los mismos datos. Esto bloqueará el segundo hasta que el primero haya hecho su trabajo.
Desde el punto de vista del usuario, parecerá que la aplicación se cuelga por completo mientras espera que la primera sesión libere
su bloqueo. A menudo, tendrá que identificar estas sesiones para mejorar su aplicación y evitar tantas
sesiones de bloqueo como sea posible.

-- Bloqueos StandAlone
           
select
   blocking_session,
   sid,
   serial#,
   wait_class,
   seconds_in_wait,
   event
from
   v$session
where
   blocking_session is not NULL
order by
   blocking_session;

SELECT s1.username || '@' || s1.machine
    || ' ( SID=' || s1.sid || ' )  is blocking '
    || s2.username || '@' || s2.machine || ' ( SID=' || s2.sid || ' ) ' AS blocking_status
    FROM v$lock l1, v$session s1, v$lock l2, v$session s2
    WHERE s1.sid=l1.sid AND s2.sid=l2.sid
    AND l1.BLOCK=1 AND l2.request > 0
    AND l1.id1 = l2.id1
    AND l1.id2 = l2.id2;


Identificación de objetos bloqueados:
la vista v$lock que ya usamos en las consultas anteriores expone aún más información. Hay diferentes tipos de bloqueos:

Consulte este sitio para obtener una lista completa:
Si encuentra un bloqueo de TM, significa que dos sesiones están intentando modificar algunos datos pero bloqueándose entre sí. A menos que
termine una sesión (confirmar o deshacer), nunca tendrá que esperar para siempre.
Las siguientes consultas le muestran todos los bloqueos de TM:

SELECT sid, id1 FROM v$lock WHERE TYPE='TM';
Ejemplo:
SID ID1
92 20127
51 20127
           
El ID que obtiene de esta consulta se refiere al objeto de base de datos real que puede ayudarlo a identificar el problema, mire la
siguiente consulta:

SELECT object_name FROM dba_objects WHERE object_id=20127;

===================================================================================
La consulta más simple para determinar el estado de la base de datos En cuanto al rendimiento, sería este:

SQL> select event, state, count(*) from v$session_wait group by event, state order by 3 desc;

EVENT                                                            STATE                 COUNT(*)
---------------------------------------------------------------- ------------------- ----------
rdbms ipc message                                                WAITING                      9
SQL*Net message from client                                      WAITING                      8
log file sync                                                    WAITING                      6
gcs remote message                                               WAITING                      2
PL/SQL lock timer                                                WAITING                      2
PL/SQL lock timer                                                WAITED KNOWN TIME

 select
    count(*),
    CASE WHEN state != 'WAITING' THEN 'WORKING'
      ELSE 'WAITING'
    END AS state,
    CASE WHEN state != 'WAITING' THEN 'On CPU / runqueue'
      ELSE event
    END AS sw_event
 FROM v$session
 WHERE type = 'USER'
 AND status = 'ACTIVE'
 GROUP BY 
     CASE WHEN state != 'WAITING' THEN 'WORKING'
      ELSE 'WAITING'
   END,
   CASE WHEN state != 'WAITING' THEN 'On CPU / runqueue'
      ELSE event
   END
   ORDER BY
   1 DESC, 2 DESC
  /

  COUNT(*) STATE   EVENT
---------- ------- ----------------------------------------
         6 WAITING PL/SQL lock timer
         4 WORKING On CPU / runqueue
         3 WAITING db file sequential read
         1 WAITING read by other session
         1 WAITING Streams AQ: waiting for messages in the
         1 WAITING jobq slave wait

6 rows selected.

===========================================================================
Por cierto, los scripts anteriores informan datos bastante similares de lo que ASH está usando realmente (especialmente el rendimiento de la instancia
gráfico que muestra el resumen de espera de la instancia). ASH también pone muy bien el recuento de CPU del servidor en el gráfico (que
podría poner en perspectiva el número de sesiones "En CPU"), por lo que otro comando útil para ejecutar después de este script
es "show parameter cpu_count" o mejor aún, verifique a nivel de sistema operativo para estar seguro :)
Tenga en cuenta que puede usar una técnica similar para ver fácilmente la actividad de la instancia desde otras perspectivas/dimensiones, como
qué SQL se está ejecutando:

select sql_hash_value, count(*) from v$session
where status = 'ACTIVE' group by sql_hash_value order by 2 desc;

SQL_HASH_VALUE   COUNT(*)
-------------- ----------
             0         20
     966758382          8
    2346103937          2
    3393152264          1
    3349907142          1
    2863564559          1
    4030344732          1
    1631089791          1

8 rows selected.

select sql_text,users_executing from v$sql where hash_value = 966758382;

SQL_TEXT                                                     USERS_EXECUTING
------------------------------------------------------------ ---------------
BEGIN :1 := orderentry.neworder(:2,:3,:4); END;                           10

======================================================
Find the blocking session detail from history table:
======================================================
--- Bloquos de los ultimos 7 dias
set pagesize 2000
set linesize 200
col sql_id format a15
col inst_id format '9'
col sql_text format a50
col module format a40

SELECT  distinct a.sql_id ,
     -----to_char(a.sample_time, 'dd/mm/yyyy hh24:mi') as fecha,  
     a.inst_id,
     a.blocking_session bloqueante,
     a.user_id,
     ------s.sql_text,
     a.module
FROM  GV$ACTIVE_SESSION_HISTORY a  ,gv$sql s
where a.sql_id=s.sql_id
and blocking_session is not null
and a.user_id <> 0 
and a.sample_time > sysdate-7
/

-- query para ver bloqueos historicos 
set pagesize 2000
set line 1000
col username for a15
col fecha for a20
col event for a30
select u.username,
to_char(a.sample_time, 'dd/mm/yyyy hh24:mi') as fecha,
a.session_id,
a.event,
a.session_state,
a.event,
a.sql_id,
a.blocking_session,
a.blocking_session_status,
CURRENT_OBJ#
from v$active_session_history a,
dba_users u
where u.user_id = a.user_id
and a.blocking_session is not null
and a.user_id <> 0
and a.sample_time between to_date('04/05/2021 15:00', 'dd/mm/yyyy hh24:mi')
and to_date('04/05/2021 15:30', 'dd/mm/yyyy hh24:mi')
and session_id=846;
---and a.blocking_session=513;
---and a.user_id = 44;
---and u.username = 'DT_BI_DWR';

Nota: si no se encuentra en v$active_session_history se debe buscar en dba_hist_active_sess_history:
-- Saber que estaba ejecutando la sesion por SID, se puede validar del query de arriba el nlocking_session u session_id
set pagesize 2000
set line 1000
col username for a15
col sample_time for a20
SELECT DISTINCT ash.session_id,
 u.username,
ash.SESSION_SERIAL#,
ash.sql_id,
st.PIECE line_no,
st.sql_text Blocking_SQL_TEXT,
ash.sample_time,
ash.session_state,
ash.BLOCKING_SESSION,
ash.BLOCKING_SESSION_status,
ash.event_id,
ash.program,
ash.module
FROM dba_hist_active_sess_history ash,dba_users u, v$SQLTEXT st
WHERE  u.user_id = ash.user_id
AND ash.SQL_ID = st.sql_id
and ash.snap_id BETWEEN 90273 AND 90274
AND session_id =3413
ORDER BY  4
/

SELECT DISTINCT  ash.session_id,
ash.sql_id,
ash.sample_time,
ash.session_state,
ash.BLOCKING_SESSION
FROM dba_hist_active_sess_history ash, v$SQLTEXT st
WHERE ash.snap_id BETWEEN 90273 AND 90274
-----AND session_id =846
AND ash.SQL_ID = st.sql_id
ORDER BY 3
/


--- Ver Snap_ID
select SNAP_ID  from dba_hist_active_sess_history a
where a.sample_time between to_date('04/05/2021 15:00', 'dd/mm/yyyy hh24:mi')
and to_date('04/05/2021 15:30', 'dd/mm/yyyy hh24:mi')
     /

--- identificando objeto:
SELECT object_name FROM dba_objects WHERE object_id=&obj_nro;


-- Historial de sesiones para un sql_id
set line 1000
set pagesize 500
set feedback on
col username for a15
col program for a30
col module for a30
col fecha for a20
----- col sql_text for 100
SELECT
   to_char(h.sample_time, 'dd/mm/yyyy hh24:mi') as fecha,
   u.username,
   h.program,
   h.module
   -----,s.sql_text
FROM
   DBA_HIST_ACTIVE_SESS_HISTORY h,
   DBA_USERS u,
   DBA_HIST_SQLTEXT s
WHERE  sample_time  between to_date('04/05/2021 01:30', 'dd/mm/yyyy hh24:mi')
and to_date('04/05/2021 02:30', 'dd/mm/yyyy hh24:mi')
   AND h.user_id=u.user_id
   AND h.sql_id = s.sql_iD
and s.SQL_ID= '7d9twcc56kjjz'
---and rownum < 5
ORDER BY 1 desc
/


==============================================
Procedure for finding the dynamic script for kill blocking session
==============================================
this script to detect and kill RAC blocking sessions, using gv$session and gv$lock:

CREATE OR REPLACE PROCEDURE kill_blocker
AS
   sqlstmt   VARCHAR2 (1000);
BEGIN
   FOR x IN (SELECT gvh.SID sessid, gvs.serial# serial,
                    gvh.inst_id instance_id
               FROM gv$lock gvh, gv$lock gvw, gv$session gvs
              WHERE (gvh.id1, gvh.id2) IN (SELECT id1, id2
                                             FROM gv$lock
                                            WHERE request = 0
                                           INTERSECT
                                           SELECT id1, id2
                                             FROM gv$lock
                                            WHERE lmode = 0)
                AND gvh.id1 = gvw.id1
                AND gvh.id2 = gvw.id2
                AND gvh.request = 0
                AND gvw.lmode = 0
                AND gvh.SID = gvs.SID
                AND gvh.inst_id = gvs.inst_id)
   LOOP
      sqlstmt :=
            'ALTER SYSTEM KILL SESSION "'
         || x.sessid
         || ','
         || x.serial
         || ',@'
         || x.instance_id
         || "";
      DBMS_OUTPUT.put_line (sqlstmt);

      EXECUTE IMMEDIATE sqlstmt;
   END kill_blovk;
END TEST;
/        

When you run this script it will generate the alter system kill session syntax for the RAC blocking session:
SQL> set serveroutput on
SQL> exec kill_blocker;

ALTER SYSTEM KILL SESSION '115,9779,@1â€²

PL/SQL procedure successfully completed.  

Also see these related notes on Oracle blocking sessions:

SELECT DECODE (l.BLOCK, 0, 'Waiting', 'Blocking ->') user_status
,CHR (39) || s.SID || ',' || s.serial# || CHR (39) sid_serial
,(SELECT instance_name FROM gv$instance WHERE inst_id = l.inst_id)
conn_instance
,s.SID
,s.PROGRAM
,s.osuser
,s.machine
,DECODE (l.TYPE,'RT', 'Redo Log Buffer','TD', 'Dictionary'
,'TM', 'DML','TS', 'Temp Segments','TX', 'Transaction'
,'UL', 'User','RW', 'Row Wait',l.TYPE) lock_type
--,id1
--,id2
,DECODE (l.lmode,0, 'None',1, 'Null',2, 'Row Share',3, 'Row Excl.'
,4, 'Share',5, 'S/Row Excl.',6, 'Exclusive'
,LTRIM (TO_CHAR (lmode, '990'))) lock_mode
,ctime
--,DECODE(l.BLOCK, 0, 'Not Blocking', 1, 'Blocking', 2, 'Global') lock_status
,object_name
FROM
   gv$lock l
JOIN
   gv$session s
ON (l.inst_id = s.inst_id
AND l.SID = s.SID)
JOIN gv$locked_object o
ON (o.inst_id = s.inst_id
AND s.SID = o.session_id)
JOIN dba_objects d
ON (d.object_id = o.object_id)
WHERE (l.id1, l.id2, l.TYPE) IN (SELECT id1, id2, TYPE
FROM gv$lock
WHERE request > 0)
ORDER BY id1, id2, ctime DESC;
