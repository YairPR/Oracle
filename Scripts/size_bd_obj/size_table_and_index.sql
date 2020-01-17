with tables
as
(
select segment_name tname, to_char(bytes/1024/1024,'999,999.99') table_size
from user_segments
where segment_type = 'TABLE'
and segment_name not like 'BIN%'
),
indexes
as
(
select table_name, index_name, scbp, rn,
(select to_char(bytes/1024/1024,'999,999.99') from user_segments where segment_name = INDEX_NAME and segment_type = 'INDEX') index_size
from (
select table_name, index_name,
substr( max(sys_connect_by_path( column_name, ', ' )), 3) scbp,
row_number() over (partition by table_name order by index_name) rn
from user_ind_columns
start with column_position = 1
connect by prior table_name = table_name
and prior index_name = index_name
and prior column_position+1 = column_position
group by table_name, index_name
)
)
select decode( nvl(rn,1), 1, tables.tname ) tname,
decode( nvl(rn,1), 1, tables.table_size ) table_size,
rn "INDEX#",
indexes.scbp,
indexes.index_name,
indexes.index_size
from tables, indexes
where tables.tname = indexes.table_name(+)
and tables.tname = '&1'
order by tables.tname, indexes.rn
/
