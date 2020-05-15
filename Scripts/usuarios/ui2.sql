set serveroutput on 
set feedback off 
set verify off 
set pages 0
spool userinfo.txt
declare
     wuser varchar2 (30) := '&amp';
     /* Users */
     cursor cusr is select username, default_tablespace || ' / ' ||
            temporary_tablespace tablespace, profile
     from dba_users where
     username like upper(wuser);
     /* Roles granted */
     cursor crole (u in varchar2) is
     select granted_role, admin_option, default_role
     from dba_role_privs where
     grantee = upper(u)
     order by granted_role;
     /* System privileges granted */
     cursor csys (u in varchar2) is
     select privilege, admin_option
     from dba_sys_privs where
     grantee = upper(u)
     order by privilege;
     /* Object privileges granted */
     cursor cobj (u in varchar2) is
     select (owner ||'.'|| table_name) object, privilege
     from dba_tab_privs where
     grantee = upper(u)
     order by owner, table_name;
     /* Column privileges granted */
     cursor ccol (u in varchar2) is
     select (owner ||'.'|| table_name ||'.'|| column_name) wcolumn, privilege
     from dba_col_privs where
     grantee = upper(u)
     order by  owner, table_name, column_name;
     wcount number := 0;
     wdate varchar2 (25) := to_char(sysdate,'Mon DD, YYYY HH:MI AM');
     w5space char(5) := '. ';
     wdum1 varchar2 (255);
     wdum2 varchar2 (255);
     wdum3 varchar2 (255);
     wdum4 varchar2 (255);
     wdum5 varchar2 (255);
     wdum6 varchar2 (255);
     wdum7 varchar2 (255);
  begin
    dbms_output.enable(100000);
    for rusr in cusr loop
      dbms_output.put_line('********** USER INFORMATION ********** ' || wdate);
      dbms_output.put_line('*------------------------------------------------------------- -------------*');
      dbms_output.put_line('Username Default / Temporary Tablespace Profi le');
      dbms_output.put_line('*------------------------------------------------------------- -------------*');
      wcount := wcount + 1;
      dbms_output.put_line(rpad(rusr.username,17) || rpad(rusr.tablespace,40) || rpad(rusr.profile,20));
      dbms_output.put_line(w5space);
      open crole (rusr.username);
      fetch crole into wdum1, wdum2, wdum3;
      if crole%notfound then
         dbms_output.put_line('********** ' || rusr.username || ' - NO ROLES GRANTED **** *****');
         close crole;
      else
         close crole;
         dbms_output.put_line('********** ' || rusr.username || ' - ROLES GRANTED ******* **');
         dbms_output.put_line(w5space || 'Role name Admin Default');
         dbms_output.put_line(w5space || '*----------------------------------------------- ----------------------*');
         for rrole  in crole (rusr.username) loop
          dbms_output.put_line(w5space || rpad(rrole.granted_role,50) || rpad(rrole.admin_option,10) || rpad(rrole.default_role,10));
         end loop;
         dbms_output.put_line(w5space);
      end if;
      dbms_output.put_line(w5space);
      open csys (rusr.username);
      fetch csys into wdum1, wdum2;
      if csys%notfound then
         dbms_output.put_line('********** ' || rusr.username || ' - NO SYSTEM PRIVILEGES G RANTED *********');
         close csys;
      else
         close csys;
         dbms_output.put_line('********** ' || rusr.username || ' - SYSTEM PRIVILEGES GRAN TED *********');
         dbms_output.put_line(w5space || 'System Privilege Admin');
         dbms_output.put_line(w5space || '*----------------------------------------------- ----------------------*');
         for rsys  in csys (rusr.username) loop
          dbms_output.put_line(w5space || rpad(rsys.privilege,50) || rpad(rsys.admin_option,10));
         end loop;
         dbms_output.put_line(w5space);
      end if;
      dbms_output.put_line(w5space);
      open cobj (rusr.username);
      fetch cobj into wdum1, wdum2;
      if cobj%notfound then
         dbms_output.put_line('********** ' || rusr.username || ' - NO OBJECT PRIVILEGES G RANTED *********');
         close cobj;
      else
         close cobj;
         dbms_output.put_line('********** ' || rusr.username || ' - OBJECT PRIVILEGES GRAN TED *********');
         dbms_output.put_line(w5space || 'Object Name Privileg e');
         dbms_output.put_line(w5space || '*----------------------------------------------- ----------------------*');
         for robj  in cobj (rusr.username) loop
          dbms_output.put_line(w5space || rpad(robj.object,40) || rpad(robj.privilege,30));
         end loop;
         dbms_output.put_line(w5space);
      end if;
      dbms_output.put_line(w5space);
      open ccol (rusr.username);
      fetch ccol into wdum1, wdum2;
      if ccol%notfound then
         dbms_output.put_line('********** ' || rusr.username || ' - NO COLUMN PRIVILEGES G RANTED *********');
         close ccol;
      else
         close ccol;
         dbms_output.put_line('********** ' || rusr.username || ' - COLUMN PRIVILEGES GRAN TED *********');
         dbms_output.put_line(w5space || 'Column Name Privilege');
         dbms_output.put_line(w5space || '*----------------------------------------------- ----------------------*');
         for rcol  in ccol (rusr.username) loop
          dbms_output.put_line(w5space || rpad(rcol.wcolumn,50) || rpad(rcol.privilege,20));
         end loop;
         dbms_output.put_line(w5space);
      end if;
      dbms_output.put_line('*------------------------------------------------------------- -------------*');
    end loop;
    if wcount =0 then
      dbms_output.put_line('******************************************************');
      dbms_output.put_line('* *');
      dbms_output.put_line('* Plese Verify Input Parameters... No Matches Found! *');
      dbms_output.put_line('* *');
      dbms_output.put_line('******************************************************');
    end if;
  end;
/
set serveroutput off 
set feedback on 
set verify on 
set pages 999
spool off
prompt
prompt Output saved at userinfo.txt
