select text from dba_source
where upper(name)=upper('&3') and
owner = upper('&1') AND
type=UPPER('&2')
order by line
/
