set pages 999
col "size MB" format 999,999,999
col "Objects" format 999,999,999
select obj.owner "Owner", obj_cnt "Objects", decode(seg_size, NULL, 0, seg_size) "size MB"
from (select owner, count(*) obj_cnt from dba_objects group by owner) obj
, (select owner, ceil(sum(bytes)/1024/1024) seg_size
from dba_segments group by owner) seg where obj.owner = seg.owner(+)
order by 3 desc ,2 desc, 1;
