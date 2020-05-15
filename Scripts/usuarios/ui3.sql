col instance_name format a20 word_wrapped
col host_name format a30
col Fecha format a30
set line 600
set serveroutput on
set long 10000000
declare
  cursor c1 is
  select username, 'DBA', 'Interbank', (select host_name || '/' || instance_name from v$instance) hostname
    from dba_users
   where username in ('TIVOLI','MDDATA','GSMCATUSER','SYSMAN','CMKAT','ORADBA','IBM_DBA','DIP','ORACLE_OCM','OPEIBM','XS$NULL','IBM','DBSNMP','SI_INFORMTN_SCHEMA','ORDPLUGINS','XDB','ANONYMOUS','ORDDATA','APPQOSSYS','WMSYS','EXFSYS','ORDSYS','MDSYS','SYSTEM','SYS','MGMT_VIEW','OUTLN','ANONYMOUS', 'DBSNMP', 'OUTLN','XDB','SYS','SYSTEM', 'OLAPSYS', 'WKSYS', 'CTXSYS', 'RMAN', 'ODM','WMSYS','IBM_DBA','MDSYS', 'QS', 'QS_ES', 'QS_OS', 'QS_WS', 'ODM_MTR', 'QS_CBADM', 'QS_CS', 'ORDSYS', 'XDB', 'SCOTT', 'OUTLN', 'OE','MGMT_VIEW', 'TIVOLI','OPS$DEVADM','OPS$ORADEV','OPS$SAPSERVICEDEV','SAPSR3','OPS$ORAQAS','OPS$QASADM','OPS$SAPSERVICEQAS','OPS$ORASOL','OPS$SAPSERVICESOL','OPS$SOLADM','SAPSR3DB','TEMPORAL','OPS$ORAPRD','OPS$PRDADM','OPS$SAPSERVICEPRD','SAPSR3','SYSKM','OJVMSYS','SCOTT','LBACSYS','DVSYS','GSMADMIN_INTERNAL','APEX_040200','DVF','SYSBACKUP','SYSDG','APEX_PUBLIC_USER','GSM_USER')
   order by 1;

  cursor c2 is
  select username, 'INTERBANK', 'CLIENTE', (select host_name || '/' || instance_name from v$instance) hostname
    from dba_users
   where username not in ('TIVOLI','MDDATA','GSMCATUSER','SYSMAN','CMKAT','ORADBA','IBM_DBA','DIP','ORACLE_OCM','OPEIBM','XS$NULL','IBM','DBSNMP','SI_INFORMTN_SCHEMA','ORDPLUGINS','XDB','ANONYMOUS','ORDDATA','APPQOSSYS','WMSYS','EXFSYS','ORDSYS','MDSYS','SYSTEM','SYS','MGMT_VIEW','OUTLN','ANONYMOUS', 'DBSNMP', 'OUTLN','XDB','SYS','SYSTEM', 'OLAPSYS', 'WKSYS', 'CTXSYS', 'RMAN', 'ODM','WMSYS','IBM_DBA','MDSYS', 'QS', 'QS_ES', 'QS_OS', 'QS_WS', 'ODM_MTR', 'QS_CBADM', 'QS_CS', 'ORDSYS', 'XDB', 'SCOTT', 'OUTLN', 'OE','MGMT_VIEW', 'TIVOLI','OPS$DEVADM','OPS$ORADEV','OPS$SAPSERVICEDEV','SAPSR3','OPS$ORAQAS','OPS$QASADM','OPS$SAPSERVICEQAS','OPS$ORASOL','OPS$SAPSERVICESOL','OPS$SOLADM','SAPSR3DB','TEMPORAL','OPS$ORAPRD','OPS$PRDADM','OPS$SAPSERVICEPRD','SAPSR3','SYSKM','OJVMSYS','SCOTT','LBACSYS','DVSYS','GSMADMIN_INTERNAL','APEX_040200','DVF','SYSBACKUP','SYSDG','APEX_PUBLIC_USER','GSM_USER') and account_status = 'OPEN'
   order by 1;

  cursor c3 (p_user IN VARCHAR2) is
  select granted_role
    from dba_role_privs
   where grantee = p_user
     and rownum < 5;

  w_cadena  VARCHAR2(4000) := null;

begin

	dbms_output.enable(1000000);
  for p1 in c1 loop
    w_cadena := null;
    for p3 in c3 (p1.username) loop
      if w_cadena is null then
        w_cadena := w_cadena || p3.granted_role;
      else
        w_cadena := w_cadena || ', ' || p3.granted_role;
      end if;
    end loop;
    w_cadena := rpad(p1.username,30)||' ORACLE    '||' IBM    '||rpad(p1.hostname,30)||' '||rpad(w_cadena,185);
    dbms_output.put_line (substr(w_cadena,1,255));
  end loop;

  for p2 in c2 loop
    w_cadena := null;
    for p3 in c3 (p2.username) loop
      if w_cadena is null then
        w_cadena := w_cadena || p3.granted_role;
      else
        w_cadena := w_cadena || ', ' || p3.granted_role;
      end if;
    end loop;
    w_cadena := rpad(p2.username,30)||' CORTE INGLES'||' CLIENTE '||rpad(p2.hostname,30)||' '||rpad(w_cadena,178);
    dbms_output.put_line (substr(w_cadena,1,255));
  end loop;

end;
/
