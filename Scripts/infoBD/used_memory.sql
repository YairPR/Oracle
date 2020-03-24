select decode( grouping(nm), 1, 'total', nm ) nm, round(sum(val/1024/1024)) mb
from
(
select 'sga' nm, sum(value) val
from v$sga
union all
select 'pga', sum(a.value)
from v$sesstat a, v$statname b
where b.name = 'session pga memory'
and a.statistic# = b.statistic#
)
group by rollup(nm);
