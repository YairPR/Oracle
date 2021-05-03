set pages 999
col "size MB" format 999,999,999
col "Objects" format 999,999,999
select obj.owner "Owner", obj_cnt "Objects", decode(seg_size, NULL, 0, seg_size) "size MB"
from (select owner, count(*) obj_cnt from dba_objects group by owner) obj
, (select owner, ceil(sum(bytes)/1024/1024) seg_size
from dba_segments group by owner) seg where obj.owner = seg.owner(+)
order by 3 desc ,2 desc, 1;


Owner                               Objects      size MB
------------------------------ ------------ ------------
ACSELX                               13,953   24,067,632
SYS                                  38,609      826,161
SIGTEC                                   62      514,670
APP_EMISION                           1,104      157,499
APP_INTERFACE                           263       40,355
MANTENIMIENTO                           292       31,496
MIGRA                                   455       23,717
APP_CONFVEH                             454       17,390
APP_LIMPER                               65       14,622
APP_COMERCIAL                            54       14,208
APP_EMISOAT                             125       13,288
SYSTEM                                  629        7,887
ORA_AUDIT                               101        3,069
APP_TRADUCTOR                            77        2,556
APP_RESTORE                               9        1,980
APP_MIG_CLIPPER                          88        1,219
APP_QUEST                               224          717
