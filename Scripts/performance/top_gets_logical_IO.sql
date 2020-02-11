set serverout on size 1000000

declare
top5 number;
text1 varchar2(4000);
x number;
len1 number;
Cursor c1 is
select buffer_gets,substr(sql_text,1,4000)
from v$sqlarea
order by buffer_gets desc;
begin
dbms_output.put_line('Reads'||'  '||'                          Text');
dbms_output.put_line ('-----'||'  '||'---------------------------------------------------');
dbms_output.put_line('      ');
open c1;
for i in 1 .. 5 loop
fetch c1 into top5, text1;
dbms_output.put_line(rpad(to_char(top5),9)|| ' '||substr(text1,1,66));
len1 :=length(text1);
x := 66;
while len1 > x-1 loop
dbms_output.put_line('"         '||substr(text1,x,64));
x := x+64;
end loop;
end loop;
end;
/
