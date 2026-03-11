whenever sqlerror exit;
set verify off echo off feedback off heading off autoprint off serveroutput on;
accept spa_trial prompt 'Introduzca Y para ejecutar SQL Performance Analyzer para comparar los planes de ejecución SQL antes y después del enmascaramiento:' default 'N';
prompt Introduzca 1 para crear un nuevo tablespace para los objetos intermitentes, o bien
prompt Introduzca 2 para utilizar el tablespace existente para asignar las tablas, o bien
prompt Introduzca 3 para utilizar el tablespace existente para todos los objetos intermitentes
accept tbps_opt prompt 'Introduzca su selección. Deje en blanco si desea utilizar el tablespace por defecto:' default 0;
variable tbps_opt varchar2(3);
execute :tbps_opt := '&tbps_opt';
SPOOL temp.sql;
SET ESCAPE ON;
variable spa_trial varchar2(3);
execute :spa_trial := '&spa_trial';
SELECT DECODE (UPPER('&spa_trial'),'N', rpad('variable sts_name varchar2(128);',80)||rpad('execute :sts_name := null;',80)||rpad('variable sts_owner varchar2(128);',80)||rpad('execute :sts_owner := null;',80)||rpad('variable task_name varchar2(30);',80)||rpad('execute :task_name := null;',80)||rpad('variable report_dir varchar2(30);',80)||rpad('execute :report_dir := null;',80),'Y', 'accept sts_owner prompt ''Introduzca el propietario de juego de ajustes SQL:'' default null 
accept sts_name prompt ''Introduzca el nombre de juego de ajustes SQL:'' default null 
accept task_name prompt ''Introduzca un nombre de tarea:'' default null 
accept report_dir prompt ''Introduzca un directorio de informe:'' default -1 
'||rpad('variable sts_owner varchar2(128);',80)||rpad('execute :sts_owner := ''\&sts_owner'';',80)||rpad('variable sts_name varchar2(128);',80)||rpad('execute :sts_name := ''\&sts_name'';',80)||rpad('variable task_name varchar2(30);',80)||rpad('execute :task_name := ''\&task_name'';',80)||rpad('variable report_dir varchar2(30);',80)||rpad('execute :report_dir := ''\&report_dir'';',80 ) )from  DUAL;
Select decode ('&tbps_opt','2', 'accept cst_tbs_n prompt ''Enter the name of existing tablespace :'' default null
'||rpad('variable cst_tbs_n varchar2(130);',80)||rpad('execute :cst_tbs_n := ''\&cst_tbs_n'';',80),'2', 'accept cst_tbs_n prompt ''Enter the name of existing tablespace :'' default null
'||rpad('variable cst_tbs_n varchar2(130);',80)||rpad('execute :cst_tbs_n := ''\&cst_tbs_n'';',80), '3','accept cst_tbs_n prompt ''Enter the name of existing tablespace :'' default null
'||rpad('variable cst_tbs_n varchar2(130);',80)||rpad('execute :cst_tbs_n := ''\&cst_tbs_n'';',80),rpad('variable cst_tbs_n varchar2(130);',80)||rpad('execute :cst_tbs_n :=null;',80))from  DUAL;
SET ESCAPE OFF;
SPOOL OFF;
START temp.sql;
variable count number;
begin
  execute immediate 'select count(*) from dba_advisor_tasks where advisor_name = ''SQL Performance Analyzer'' and task_name = :1 and owner = user' into :count using :task_name;
  if (:count != 0) then
    dbms_standard.raise_application_error(-20003, 'El nombre de la tarea ya existe. Especifique otro nombre de tarea.');
end if;
end;
/
undefine screate_omf ;
variable create_omf varchar2(3);
column value new_value screate_omf;
select count(value) value from v$parameter  where name = 'db_create_file_dest' and value is not null;
begin
  if &screate_omf = 0 then
    :create_omf:=null;
  else
    :create_omf:='Y';
  end if;
end;
/
whenever sqlerror continue;
set feedback off
set serveroutput on
set pagesize 0
set ver off
set echo off
set timing off

spool masking800.log

set escape \
-- Script Header Section
-- ==============================================

-- functions and procedures

CREATE OR REPLACE PROCEDURE mgmt$mask_sendMsg (msg IN VARCHAR2) IS
    msg1 VARCHAR2(1020);
    len INTEGER := length(msg);
    i INTEGER := 1;
BEGIN
    dbms_output.enable (1000000);

    LOOP
      msg1 := SUBSTR (msg, i, 255);
      dbms_output.put_line (msg1);
      len := len - 255;
      i := i + 255;
    EXIT WHEN len <= 0;
    END LOOP;
END mgmt$mask_sendMsg;
/

CREATE OR REPLACE PROCEDURE mgmt$mask_errorExit (msg IN VARCHAR2) IS
BEGIN
    mgmt$mask_sendMsg (msg);
    mgmt$mask_sendMsg ('errorExit'||'!');
END mgmt$mask_errorExit;
/

CREATE OR REPLACE PROCEDURE mgmt$mask_errorExitOraError (msg IN VARCHAR2, errMsg IN VARCHAR2) IS
BEGIN
    mgmt$mask_sendMsg (msg);
    mgmt$mask_sendMsg (errMsg);
    mgmt$mask_sendMsg ('errorExitOraError'||'!');
END mgmt$mask_errorExitOraError;
/

CREATE OR REPLACE PROCEDURE mgmt$mask_checkDBAPrivs 
AUTHID CURRENT_USER IS
    granted_role REAL := 0;
    user_name user_users.username%type;
BEGIN
SELECT USERNAME INTO user_name FROM USER_USERS;
    EXECUTE IMMEDIATE 'SELECT 1 FROM SYS.DBA_ROLE_PRIVS WHERE GRANTED_ROLE = ''DBA'' AND GRANTEE = :1'
      INTO granted_role       USING user_name;
EXCEPTION
    WHEN OTHERS THEN
       IF SQLCODE = -01403 OR SQLCODE = -00942  THEN
      mgmt$mask_sendMsg ( 'WARNING checking privileges... User Name: ' || user_name);
      mgmt$mask_sendMsg ( 'User does not have DBA privs. ' );
      mgmt$mask_errorExitOraError ( 'The script will fail if it tries to perform operations for which the user lacks the appropriate privilege. ',' ' );
      END IF;
END mgmt$mask_checkDBAPrivs;
/

CREATE OR REPLACE PROCEDURE mgmt$mask_setUpJobTable (script_id IN INTEGER, job_table IN VARCHAR2, step_num OUT INTEGER)
AUTHID CURRENT_USER IS
    ctsql_text VARCHAR2(200) := 'CREATE TABLE ' || job_table || '(SCRIPT_ID NUMBER, LAST_STEP NUMBER, unique (SCRIPT_ID))';
    itsql_text VARCHAR2(200) := 'INSERT INTO ' || job_table || ' (SCRIPT_ID, LAST_STEP) values (:1, :2)';
    stsql_text VARCHAR2(200) := 'SELECT last_step FROM ' || job_table || ' WHERE script_id = :1';

    TYPE CurTyp IS REF CURSOR;  -- define weak REF CURSOR type
    stsql_cur CurTyp;  -- declare cursor variable

BEGIN
    step_num := 0;
    BEGIN
      EXECUTE IMMEDIATE ctsql_text;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;

    BEGIN
      OPEN stsql_cur FOR  -- open cursor variable
        stsql_text USING  script_id;
      FETCH stsql_cur INTO step_num;
      IF stsql_cur%FOUND THEN
        NULL;
      ELSE
        EXECUTE IMMEDIATE itsql_text USING script_id, step_num;
        COMMIT;
        step_num := 1;
      END IF;
      CLOSE stsql_cur;
    EXCEPTION
      WHEN OTHERS THEN
        mgmt$mask_errorExit ('ERROR selecting or inserting from table: ' || job_table);
        return;
    END;

    return;

EXCEPTION
      WHEN OTHERS THEN
        mgmt$mask_errorExit ('ERROR accessing table: ' || job_table);
        return;
END mgmt$mask_setUpJobTable;
/

CREATE OR REPLACE PROCEDURE mgmt$mask_deleteJobTableEntry(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN INTEGER, highest_step IN INTEGER)
AUTHID CURRENT_USER IS
    delete_text VARCHAR2(200) := 'DELETE FROM ' || job_table || ' WHERE SCRIPT_ID = :1';
BEGIN

    IF step_num <= highest_step THEN
      return;
    END IF;

    BEGIN
      EXECUTE IMMEDIATE delete_text USING script_id;
      IF SQL%NOTFOUND THEN
        mgmt$mask_errorExit ('ERROR deleting entry from table: ' || job_table);
        return;
      END IF;
    EXCEPTION
        WHEN OTHERS THEN
          mgmt$mask_errorExit ('ERROR deleting entry from table: ' || job_table);
          return;
    END;

    COMMIT;
END mgmt$mask_deleteJobTableEntry;
/

CREATE OR REPLACE PROCEDURE mgmt$mask_setStep (script_id IN INTEGER, job_table IN VARCHAR2, step_num IN INTEGER)
AUTHID CURRENT_USER IS
    update_text VARCHAR2(200) := 'UPDATE ' || job_table || ' SET last_step = :1 WHERE script_id = :2';
BEGIN
    -- update job table
    EXECUTE IMMEDIATE update_text USING step_num, script_id;
    IF SQL%NOTFOUND THEN
      mgmt$mask_sendMsg ('NOTFOUND EXCEPTION of sql_text: ' || update_text);
      mgmt$mask_errorExit ('ERROR accessing table: ' || job_table);
      return;
    END IF;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
      mgmt$mask_errorExit ('ERROR accessing table: ' || job_table);
      return;
END mgmt$mask_setStep;
/

create or replace type mgmt_dm_formatmap as table of varchar2(4000);
/
create or replace package mgmt$mask_util authid current_user is

    procedure set_dir_obj( d varchar2 );
    function get_dir_obj return varchar2;
    function isWorkloadMasking return boolean;
    procedure set_sts_mask( s varchar2);
    function get_sts_mask return varchar2;
    function isSTSMasking return boolean;
    procedure set_sts_name( s varchar2);
    function get_sts_name return varchar2;
    procedure set_sts_owner( s varchar2);
    function get_sts_owner return varchar2;
    procedure set_task_name( s varchar2);
    function get_task_name return varchar2;
    procedure set_spa_trial(s varchar2);
    function get_spa_trial return varchar2;
    function isSPATrialRequired return boolean;
    procedure set_report_dir( d varchar2 );
    function get_report_dir return varchar2;
    procedure create_xml_report (clob_pointer CLOB);
    function get_control_xml return xmltype ;
    function strval (len number) return varchar2 parallel_enable;
    function numval (low number, high number) return number parallel_enable;
    function replaceregexpclob (col CLOB, column_id NUMBER) RETURN CLOB; 
    function replaceregexpchar (col VARCHAR2, column_id NUMBER) RETURN VARCHAR2; 
    function randomencode (i_input VARCHAR2, pad_length NUMBER) RETURN VARCHAR2 deterministic parallel_enable; 
    procedure distribute_nos(low number, high number, numd number); 
    function fetchnum(idx number ,low number, high number, numd number) return number; 
    function get_package_version return varchar2; 
    function encrypt( orig_value varchar2, 
                      fmt mgmt_dm_formatmap,
                      max_value number, 
                      inpsd number) return varchar2 
                      deterministic parallel_enable; 
 
    function decrypt( orig_value varchar2, 
                      fmt mgmt_dm_formatmap,
                      max_value number, 
                      inpsd number) return varchar2 
                      deterministic parallel_enable; 
    function encrypt( orig_date Date, 
                      start_date Date, 
                      end_date Date,
                      inpsd number) return Date 
                      deterministic parallel_enable; 
 
    function decrypt( mask_date Date, 
                      start_date Date, 
                      end_date Date,
                      inpsd number) return Date 
                      deterministic parallel_enable; 
 
    procedure set_tbps_option(tbps_option varchar2, 
                              cust_tbps_name varchar2, 
                              create_omf varchar2); 
 
    procedure create_new_tablespace; 
 
    function  isNewTbpsCreated return boolean; 
 
    function get_tbps_name return varchar2; 
 
    function get_tbps_clause return varchar2; 
 
    function get_tbps_clause_dmask return varchar2; 
 
    function get_tbps_clause_stage return varchar2; 
 
    function get_tbps_clause_temp return varchar2; 
 
    procedure drop_tablespace; 
 
    function is_move_dmask return boolean; 

end mgmt$mask_util;
/
create or replace package body mgmt$mask_util is

    dirobj    varchar2(128) := null;
    reportdir varchar2(30) := null;
    stsname   varchar2(128) := null;
    stsowner  varchar2(128) := null;
    stsmask   varchar2(3) := null;
    spatrial  varchar2(3) := null;
    taskname  varchar2(30) := null;
    tbps_name varchar2(128) := null;
    create_new_tbps     boolean := false;
    tbps_data_file_name varchar2(128) := null;
    new_tbps_created    boolean := false;
    move_dmask          boolean := false;
    -- Global Collection for Regular Expression format
    TYPE strarr IS TABLE OF VARCHAR2(4000) INDEX BY PLS_INTEGER;
    TYPE twod_strarr IS TABLE OF strarr INDEX BY PLS_INTEGER;
    regexp_val_arr twod_strarr;
    exp_val_arr    twod_strarr;
 TYPE numarr IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
 permuarr numarr;
 populatearr number := 0;

  dm_package_version varchar2(10) := 'em_version';

FUNCTION encode_format_to_number (orig_value VARCHAR2, orig_format mgmt_dm_formatmap) RETURN NUMBER IS
  ret NUMBER := NULL;                  /* orig val encoded as number */
  flen NUMBER := orig_format.count;    /* length of format */
  len NUMBER := length(orig_value);    /* num iterations */
  i NUMBER := 0;                       /* current digit number being encoded */
  c VARCHAR2(10);                       /* current char being encoded */
  digit number;                        /* numeric representation of char */
  base number;                         /* current chars base for encoding */
  maxval number:=1;
BEGIN

    if (orig_value is null) then
        return orig_value;
    end if;

    ret := 0; /* Initialize */

    --dbms_output.put_line('orig='||orig_value);

    len := least(flen, len);
    FOR i IN 0 .. len-1
    LOOP
        c := substr(orig_value, len-i, 1);
        -- dbms_output.put_line('fmt='||orig_format(len-i));
        digit := instr(orig_format(len-i), c) - 1;
        base := length(orig_format(len-i));
        -- dbms_output.put_line('i='||i||', c='||c||', dig='||digit||', base='||base);

        if (digit < 0) then 
            return ret; -- invalid format
        end if;

        ret := ret + digit*maxval;
        maxval := maxval * base;

    END LOOP;

    -- dbms_output.put_line('encoded value is='||ret);
    return ret;
END;


FUNCTION decode_number_to_format (num_value NUMBER, orig_format mgmt_dm_formatmap) RETURN VARCHAR2 IS
  ret VARCHAR2(4000) := NULL;          /* num val decoded as string */
  num NUMBER;
  flen NUMBER := orig_format.count;    /* max length of format */
  len NUMBER := length(num_value);    /* num iterations */
  i NUMBER := 0;                       /* current digit number being decoded */
  c VARCHAR2(10);                       /* current char being encoded */
  digit number;                        /* numeric representation of char */
  base number;                         /* current chars base for encoding */
BEGIN
    if (num_value is null) then
        return ret;
    end if;

    -- dbms_output.put_line('orig='||num_value);

    num := num_value; /* Initialize */
    ret := null;

    FOR i IN 0 .. flen-1
    LOOP
        base := length(orig_format(flen-i));
        if (num > 0) then
            digit := mod(num, base);
            num := (num - digit)/base; /* reminder */
        else
            digit := 0;
        end if;
        -- dbms_output.put_line('i='||i||', num='||num||', dig='||digit||', base='||base);

        if (digit+1 > length(orig_format(flen-i))) then
            -- dbms_output.put_line('invalid digit='||digit+1||', len='||length(orig_format(flen-i)));
            digit := 0; /* invalid decoded value */
        end if;

        c := substr(orig_format(flen-i), digit+1, 1);
        ret := c || ret;

    END LOOP;

    -- dbms_output.put_line('decoded value is='||ret);
    return ret;
END;

--- TO BINARY
function to_binary(p_in number, h_many in number := 64) return varchar2 is
  v_result varchar2(64);
  v_temp number := p_in;
  large_power_2 number := 0;
begin
  for i in 1 .. h_many loop       -- must match number of bits
    large_power_2 := power(2,64-i); 
    if v_temp >= large_power_2 then
      v_result := v_result || '1';
      v_temp := v_temp - large_power_2;
    else
      v_result := v_result || '0';
    end if;
  end loop;
  return v_result;
end;

-- function get max_bits for the given number
procedure get_max_bits (max_number in number,
                        max_b_value out varchar2,
                        max_b_bits  out number)
is
begin
    max_b_value := to_binary(max_number);
    max_b_bits := 64 - (instr(max_b_value, '1') - 1);
    if MOD(max_b_bits,2) = 1 then
      max_b_bits := max_b_bits + 1;
    end if;
end get_max_bits;


--- BIT OR
function bitor(x in number, y in number)
return number deterministic parallel_enable
is
begin
    Return x + y - bitand(x, y);
end bitor;

--- BIT XOR
function bitxor(x in number, y in number)
return number deterministic parallel_enable
is
begin
    Return bitor(x, y) - bitand(x, y);
end bitxor;

-- bv bit  xor
function bv_bitxor(x in varchar2, y in varchar2)
return varchar deterministic parallel_enable
is
  bv_length number := LENGTH(x);
  output_bv varchar2(64);
begin
  -- ASSUMPTION: both x and y are of the same length
  -- can be improved later
  for i in 1 .. bv_length
  loop
    if substr(x, i, 1) = substr(y, i, 1)  then
      output_bv := output_bv || '0';
    else
      output_bv := output_bv || '1';
    end if;
  end loop;
  return output_bv;
end bv_bitxor;

--- FROM BINARY
function from_binary(p_in varchar2) return number is
  v_result number := 0;
  power_2 number := 1;
  j       number := 64;
begin
  for i in reverse 1 .. length(p_in) loop
    if substr(p_in,i,1) = '1' then
      v_result := v_result  + power(2,64-j);
    end if;
    j := j-1;
  end loop;
  return v_result;
end;

--- From BIN2HEX
function from_bin_2_hex( bin_input varchar2)
return varchar2
is
  hex_output varchar2(16);
  i          number := 0;
begin
  --dbms_output.put_line('hex_input: ' || hex_input);
  -- TBD for now it works only on 64 bit input blocks
  --dbms_output.put_line('b2h: ' || bin_input);
  --dbms_output.put_line('b2h len: ' || LENGTH(bin_input));
  for i in 1..16
  loop
    case
    when substr(bin_input, 4*(i-1)+1, 4) = '0000' then 
      hex_output := hex_output || '0';
    when substr(bin_input, 4*(i-1)+1, 4) = '0001' then 
      hex_output := hex_output || '1';
    when substr(bin_input, 4*(i-1)+1, 4) = '0010' then 
      hex_output := hex_output || '2';
    when substr(bin_input, 4*(i-1)+1, 4) = '0011' then 
      hex_output := hex_output || '3';
    when substr(bin_input, 4*(i-1)+1, 4) = '0100' then 
      hex_output := hex_output || '4';
    when substr(bin_input, 4*(i-1)+1, 4) = '0101' then 
      hex_output := hex_output || '5';
    when substr(bin_input, 4*(i-1)+1, 4) = '0110' then 
      hex_output := hex_output || '6';
    when substr(bin_input, 4*(i-1)+1, 4) = '0111' then 
      hex_output := hex_output || '7';
    when substr(bin_input, 4*(i-1)+1, 4) = '1000' then 
      hex_output := hex_output || '8';
    when substr(bin_input, 4*(i-1)+1, 4) = '1001' then 
      hex_output := hex_output || '9';
    when substr(bin_input, 4*(i-1)+1, 4) = '1010' then 
      hex_output := hex_output || 'A';
    when substr(bin_input, 4*(i-1)+1, 4) = '1011' then 
      hex_output := hex_output || 'B';
    when substr(bin_input, 4*(i-1)+1, 4) = '1100' then 
      hex_output := hex_output || 'C';
    when substr(bin_input, 4*(i-1)+1, 4) = '1101' then 
      hex_output := hex_output || 'D';
    when substr(bin_input, 4*(i-1)+1, 4) = '1110' then 
      hex_output := hex_output || 'E';
    when substr(bin_input, 4*(i-1)+1, 4) = '1111' then 
      hex_output := hex_output || 'F';
    else
      dbms_output.put_line ('Invalid INPUT: b2h');
    end case;
    --dbms_output.put_line ('hex_output: ' || hex_output);
  end loop;

  return hex_output;
end from_bin_2_hex;

--- FROM HEX2BIN
function from_hex_2_bin( hex_input varchar2)
return varchar2
is
  bin_output varchar2(64);
  i          number := 0;
begin
  --dbms_output.put_line('hex_input: ' || hex_input);
  for i in 1..LENGTH(hex_input)
  loop
    case
    when substr(hex_input, i, 1) = '0' then 
      bin_output := bin_output || '0000';
    when substr(hex_input, i, 1) = '1' then 
      bin_output := bin_output || '0001';
    when substr(hex_input, i, 1) = '2' then 
      bin_output := bin_output || '0010';
    when substr(hex_input, i, 1) = '3' then 
      bin_output := bin_output || '0011';
    when substr(hex_input, i, 1) = '4' then 
      bin_output := bin_output || '0100';
    when substr(hex_input, i, 1) = '5' then 
      bin_output := bin_output || '0101';
    when substr(hex_input, i, 1) = '6' then 
      bin_output := bin_output || '0110';
    when substr(hex_input, i, 1) = '7' then 
      bin_output := bin_output || '0111';
    when substr(hex_input, i, 1) = '8' then
      bin_output := bin_output || '1000';
    when substr(hex_input, i, 1) = '9' then 
      bin_output := bin_output || '1001';
    when substr(hex_input, i, 1) = 'A' then 
      bin_output := bin_output || '1010';
    when substr(hex_input, i, 1) = 'B' then 
      bin_output := bin_output || '1011';
    when substr(hex_input, i, 1) = 'C' then 
      bin_output := bin_output || '1100';
    when substr(hex_input, i, 1) = 'D' then 
      bin_output := bin_output || '1101';
    when substr(hex_input, i, 1) = 'E' then 
      bin_output := bin_output || '1110';
    when substr(hex_input, i, 1) = 'F' then 
      bin_output := bin_output || '1111';
    else
      dbms_output.put_line ('Invalid INPUT: h2b');
    end case;
  end loop;

  return bin_output;
end from_hex_2_bin;

-- key is in hex form
function new_mk_prf( orig_b_value varchar2,
                     key_value    varchar2,
                     twk_b_value  varchar2,
                     encrypt      number)
return varchar2
is
  inp_h_value    varchar2(16);
  inp_n_value    number;
  enc_h_value    varchar2(16);
  enc_n_value    number;
  inp_b_value    varchar2(64) := null;
  enc_b_value    varchar2(64) := null;
  --twk_b_value    varchar2(8) := to_binary(tweak, 8);
  num_zeros      number := 0;
  orig_b_length  number := 0;
  l_mod          number := dbms_crypto.ENCRYPT_3DES + dbms_crypto.CHAIN_ECB + 
                         dbms_crypto.PAD_ZERO;
  zero_b_value   varchar2(64) := '0000000000000000000000000000000000000000000000000000000000000000';
  dm_enc_use_ora_hash boolean := FALSE;
begin
  -- form the 64 bit input
  --dbms_output.put_line('mk_prf: ' || orig_b_value);
  orig_b_length := LENGTH(orig_b_value);

  --dbms_output.put_line('mk_prf: o_b_l: ' || orig_b_length);

  if dm_enc_use_ora_hash = TRUE then
    inp_b_value := orig_b_value;
    inp_n_value := from_binary(inp_b_value);
    --enc_n_value := ora_hash(inp_n_value, 4294967295, key_value);
    select ora_hash(inp_n_value, 4294967295, key_value) 
    into enc_n_value
    from dual;
    --dbms_output.put_line('enc_n_value: ' || enc_n_value);
    enc_b_value := to_binary(enc_n_value,32);
    --dbms_output.put_line('enc_b_value: ' || enc_b_value);
  else
    inp_b_value := orig_b_value || substr(zero_b_value, 1, 56 - orig_b_length) ||
                 twk_b_value;
    inp_h_value := from_bin_2_hex(inp_b_value);
    enc_h_value := dbms_crypto.encrypt(inp_h_value, l_mod, key_value);
    enc_b_value := from_hex_2_bin(enc_h_value); 
  end if;

  --dbms_output.put_line('mk_prf: inp_h: ' || inp_h_value);


  --enc_h_value := substr(dbms_crypto.mac(inp_h_value, dbms_crypto.HMAC_SH1 , key_value),
  --                      1, 16);
  --dbms_output.put_line('mk_prf: outp_h: ' || enc_h_value);
  
  --dbms_output.put_line('mk_prf: outp_bin: ' || enc_b_value);
  --dbms_output.put_line('enc ret: ' || substr(enc_b_value, 64-orig_b_length+1,orig_b_length));

  return substr(enc_b_value, 1,orig_b_length);
end new_mk_prf;

function new_mk_round( orig_b_value varchar2,
                       inp_length   number,
                       key_value    varchar2,
                       twk_b_value  varchar,
                       encrypt      number)
return varchar2
is
  inp_br_value    varchar2(64) := null;
  out_b_value     varchar2(64) := null;
  nr_b_value      varchar2(64) := null;
  nl_b_value      varchar2(64) := null;
  nr_value        number := 0;
  nl_value        number := 0;
  inp_bl_value    varchar2(64) := null;
  prf_b_value     varchar2(64) := null;
  num_zeros       number := 0;
begin

  --dbms_output.put_line(' new_mk_round: ' || inp_length);
  --dbms_output.put_line(' new_mk_round: flr' || FLOOR((inp_length/2)));
  --dbms_output.put_line('round b in value: ' || orig_b_value);
  if encrypt = 1 then
    inp_br_value := substr(orig_b_value, FLOOR((inp_length/2))+1, FLOOR(inp_length/2));
    inp_bl_value := substr(orig_b_value, 1, FLOOR((inp_length/2)));

    --dbms_output.put_line('prf input: ' || inp_br_value);
    --dbms_output.put_line('key_value input: ' || key_value);
    --dbms_output.put_line('tweak input: ' || tweak);
    nl_b_value := inp_br_value;
    prf_b_value  := new_mk_prf(inp_br_value, key_value, twk_b_value, encrypt);
    nr_b_value := bv_bitxor(inp_bl_value, prf_b_value);
    out_b_value := nl_b_value || nr_b_value;
  else
    inp_br_value := substr(orig_b_value, FLOOR((inp_length/2))+1, FLOOR(inp_length/2));
    inp_bl_value := substr(orig_b_value, 1, FLOOR((inp_length/2)));

    nr_b_value := inp_bl_value;
    prf_b_value  := new_mk_prf(inp_bl_value, key_value, twk_b_value, encrypt);
    nl_b_value := bv_bitxor(inp_br_value, prf_b_value); 
    out_b_value := nl_b_value || nr_b_value;
  end if;
    
  --dbms_output.put_line('round b out value: ' || out_b_value);
  return out_b_value;
end new_mk_round;

----- ENCRYPT
function new_mk_encrypt( orig_value number,
                         key_value  varchar2 := 'abce12345678234',
                         max_value  number := '999999999999' )
return varchar2
is
  inp_b_value     varchar2(64);
  max_o_bits      number := 0;
  max_b_value     varchar2(64);
  mapped          boolean := FALSE;
  inp_n_value     number := 0;
  DM_ENC_ROUNDS   number := 6;
  TYPE twk_table_array is TABLE of varchar2(8);
  twk_table twk_table_array := twk_table_array('00000001',
                                               '00000010',
                                               '00000011',
                                               '00000100',
                                               '00000101',
                                               '00000110',
                                               '00000111',
                                               '00001000');
begin

  --dbms_output.put_line('LENGTH: ' || LENGTH(to_binary(orig_value)));
  inp_n_value := orig_value;
  if inp_n_value > max_value then
    dbms_standard.raise_application_error(-20001, 
                     ' input is bigger than max permissble vale: cannot encrypt');
  end if;
  -- get max bits need for the max_number and the b value 
  get_max_bits(max_value, max_b_value, max_o_bits);
  --dbms_output.put_line('max_o_bits : ' || max_o_bits);
  inp_b_value := substr(to_binary(orig_value), 64-max_o_bits+1, max_o_bits);
  --dbms_output.put_line('original source: ' || inp_b_value);

  loop
    for j in 1..DM_ENC_ROUNDS
    loop
      inp_b_value := new_mk_round(inp_b_value, LENGTH(inp_b_value), key_value, 
                                  twk_table(j), 1);
      --dbms_output.put_line('round value: ' || from_binary(inp_b_value));
    end loop;
    
    if from_binary(inp_b_value) < max_value then
      mapped := TRUE;
    end if;
    
    /* for i in 1..LENGTH(inp_b_value)
    loop
      if substr(inp_b_value, i, 1) != substr(max_b_value, i, 1) then
        if substr(inp_b_value, i, 1) = '1' then
          mapped := TRUE;
        else
          mapped := FALSE;
        end if;
        exit;
      end if;
    end loop; */
    exit when mapped = TRUE;
  end loop;

  return from_binary(inp_b_value);
end new_mk_encrypt; 

-- DECRYPT
function new_mk_decrypt( orig_value number,
                         key_value  varchar2 := 'abce12345678234',
                         max_value  number := '999999999999' )
return varchar2
is
  inp_b_value     varchar2(64);
  max_b_value     varchar2(64);
  max_o_bits      number := 0;
  mapped          boolean := FALSE;
  inp_n_value     number := 0;
  DM_ENC_ROUNDS   number := 6;
  TYPE twk_table_array is TABLE of varchar2(8);
  twk_table twk_table_array := twk_table_array('00000001',
                                               '00000010',
                                               '00000011',
                                               '00000100',
                                               '00000101',
                                               '00000110',
                                               '00000111',
                                               '00001000');
begin

  inp_n_value := orig_value;
  if inp_n_value > max_value then
    dbms_standard.raise_application_error(-20002, 
                      ' input is bigger than max permissble vale: cannot decrypt');
  end if;
  get_max_bits(max_value, max_b_value, max_o_bits);
  --dbms_output.put_line('max_o_bits : ' || max_o_bits);
  inp_b_value := substr(to_binary(orig_value), 64-max_o_bits+1, max_o_bits);
  --dbms_output.put_line('original source: ' || inp_b_value);

  loop
    for j in 1..DM_ENC_ROUNDS
    loop
      inp_b_value := new_mk_round(inp_b_value, LENGTH(inp_b_value), key_value, 
                                  twk_table(DM_ENC_ROUNDS-j+1), 0);
      --dbms_output.put_line('round value: ' || from_binary(inp_b_value));
    end loop;
    
    if from_binary(inp_b_value) < max_value then
      mapped := TRUE;
    end if;
    
    /* for i in 1..LENGTH(inp_b_value)
    loop
      if substr(inp_b_value, i, 1) != substr(max_b_value, i, 1) then
        if substr(inp_b_value, i, 1) = '1' then
          mapped := TRUE;
        else
          mapped := FALSE;
        end if;
        exit;
      end if;
    end loop; */ 
    exit when mapped = TRUE;
  end loop;

  --if mapped = 0 then
  --  dbms_output.put_line('could not map in 10k iterations');
  --end if;
  --dbms_output.put_line('original out: ' || inp_b_value);
  return from_binary(inp_b_value);
end new_mk_decrypt; 

 function encrypt( orig_value varchar2,  
                    fmt mgmt_dm_formatmap,
                    max_value number,
                    inpsd number) return varchar2 
                    deterministic parallel_enable 
 is 
    num NUMBER; 
    encr NUMBER; 
  begin 
    if (orig_value is null) then
        return orig_value;
    end if;
    num := encode_format_to_number(orig_value, fmt); 
    encr := new_mk_encrypt(num, lpad(inpsd, 47, 9), max_value); 
    return decode_number_to_format(to_number(encr), fmt); 
  end;  
  
  function decrypt( orig_value varchar2,  
                    fmt mgmt_dm_formatmap,
                    max_value number,
                    inpsd number) return varchar2 
                    deterministic parallel_enable 
  is 
    num NUMBER; 
    encr NUMBER; 
  begin 
    if (orig_value is null) then
        return orig_value;
    end if;
    num := encode_format_to_number(orig_value, fmt); 
    encr := new_mk_decrypt(num, lpad(inpsd, 47, 9), max_value); 
    return decode_number_to_format(to_number(encr), fmt); 
  end;  

 /* Date encrypt/decrypt functions */  function encrypt( orig_date Date,  
                    start_date Date,
                    end_date Date, 
                    inpsd NUMBER) return Date 
                    deterministic parallel_enable 
 is 
    num NUMBER; 
    max_value NUMBER; 
    encr NUMBER; 
  begin 
    if (orig_date is null) then
        return orig_date;
    end if;
    if (orig_date < start_date) then
        return start_date;
    end if;
    if (orig_date > end_date) then
        return end_date;
    end if;
    num := round((orig_date - start_date)*86400);
    max_value := round((end_date - start_date)*86400);
    encr := new_mk_encrypt(num, lpad(inpsd, 47, 9), max_value); 
    return start_date + numtodsinterval(encr, 'SECOND'); 
  end;  
  
 function decrypt( mask_date Date,  
                    start_date Date,
                    end_date Date,
                    inpsd NUMBER) return Date 
                    deterministic parallel_enable 
 is 
    num NUMBER; 
    max_value NUMBER; 
    encr NUMBER; 
  begin 
    if (mask_date is null) then
        return mask_date;
    end if;
    if (mask_date < start_date) then
        return start_date;
    end if;
    if (mask_date > end_date) then
        return end_date;
    end if;
    encr := round((mask_date - start_date)*86400);
    max_value := round((end_date - start_date)*86400);
    num := new_mk_decrypt(encr, lpad(inpsd, 47, 9), max_value); 
    return start_date + numtodsinterval(num, 'SECOND'); 
  end;  

    procedure set_task_name(s varchar2) is
    begin
        taskname := s;
    end;

    function get_task_name return varchar2 is
    begin
        return taskname;
    end;

    procedure set_spa_trial(s varchar2) is
    begin
        spatrial := s;
    end;

    function get_spa_trial return varchar2 is
    begin
        return spatrial;
    end;

    function isSPATrialRequired return boolean is
    begin
        if (spatrial IS NULL OR spatrial = 'N' OR spatrial = '-1') then 
            return false;
        else
            return true;
        end if;
    end;

    procedure set_dir_obj(d varchar2) is
    begin
        dirobj := d;
    end;

    function get_dir_obj return varchar2 is
    begin
        return dirobj;
    end;

    procedure set_report_dir(d varchar2) is
    begin
        reportdir := d;
    end;

    function get_report_dir return varchar2 is
    begin
        return reportdir;
    end;

    function isWorkloadMasking return boolean is
    begin
        if (dirobj IS NULL OR dirobj = '-1') then 
            return false;
        else
            return true;
        end if;
    end;

    procedure set_sts_owner(s varchar2) is
    begin
        stsowner := s;
    end;

    function get_sts_owner return varchar2 is
    begin
        return stsowner;
    end;

    function get_sts_name return varchar2 is
    begin
        return stsname;
    end;

    procedure set_sts_name(s varchar2) is
    pos number;
    begin
      pos := instr(s,'.');
      if(pos > 0) then
         stsname := trim(both '"' from substr(s,pos+1));
         set_sts_owner(substr(s,0,pos-1));
      else
        stsname := s;
      end if;
    end;

    procedure set_sts_mask(s varchar2) is
    begin
        stsmask := s;
    end;

    function get_sts_mask return varchar2 is
    begin
        return stsmask;
    end;

    function isSTSMasking return boolean is
    begin
        if (stsmask IS NULL OR stsmask = '-1' OR stsmask = 'N') then 
            return false;
        else
            return true;
        end if;
    end;

    procedure create_xml_report (clob_pointer clob) is
      v_buf varchar2(1000);
      amount binary_integer :=1000;
      position integer :=1;
      fp utl_file.file_type;
      sqlerr_msg varchar2(1000);
      path varchar2(4000);
      dir_name varchar2(30);
    begin
    if (reportdir is NULL or  reportdir = '-1' or reportdir = '') then 
      return;  
    else  
      begin
      dir_name := reportdir;
      execute immediate 'select directory_path FROM dba_directories WHERE directory_name = :1' into path USING dir_name; 
       fp :=utl_file.fopen(dir_name,'DM_RAT_800_impact.html','w');
       loop
        begin
         dbms_lob.read (clob_pointer,amount,position,v_buf);
         utl_file.put_line(fp,v_buf,true);
         position :=position +amount;
        exception
         when no_data_found then
         exit;
        end;
       end loop;
       utl_file.fclose(fp);
       dbms_output.put_line('SQL Performance analyzer : Impact report generated at ' ||path||'\DM_RAT_800_impact.html');
       exception
         when others then
          sqlerr_msg := substr(sqlerrm, 1, 100);
          dbms_output.put_line ('Error in writing xml report :' || sqlerr_msg);
       end;
        end if;
       end;

    function get_control_xml return xmltype is
      xmlstring varchar2(4000);
      controlxml XMLTYPE;
    begin
       xmlstring := '<CONTROL_PARAMS>';
       if isWorkloadMasking then 
         xmlString :=  xmlString || '<WORKLOAD>' ||  get_dir_obj() || '</WORKLOAD>';
        else
         xmlString :=  xmlString || '<WORKLOAD></WORKLOAD>';
        end if;
        if isSTSMasking then
         xmlString :=  xmlString || '<STS>Y</STS>';
        else
         xmlString :=  xmlString || '<STS>N</STS>';
        end if;
        xmlString := xmlString || '</CONTROL_PARAMS>';
        controlxml := XMLTYPE(xmlString);
        return controlxml;
    end;

    function strval (len number) return varchar2 parallel_enable is
    begin
        return dbms_random.string('l', len);
    end;

    function numval (low number, high number) return number parallel_enable is
    begin
        return dbms_random.value(low,high);
    end;


    FUNCTION  replaceregexpclob (col CLOB, column_id NUMBER) RETURN CLOB IS
        TYPE cur_typ IS REF CURSOR;
        c cur_typ;
        idx NUMBER:=0;
        temp CLOB :=  col;
        query_str VARCHAR2(200) := 'SELECT  REGEX, EXPR FROM mgmt_dm_rule_'||column_id;
        regex VARCHAR2(4000);
        expr VARCHAR2(4000);
        BEGIN
        IF NOT(regexp_val_arr.EXISTS(column_id))
        THEN
          OPEN c FOR query_str;
          LOOP
            FETCH c INTO regex, expr;
            EXIT WHEN c%NOTFOUND;

            regexp_val_arr(column_id)(idx) := regex;
            exp_val_arr(column_id)(idx) := expr;
            idx := idx+1;
          END LOOP;
        END IF;

        FOR i IN regexp_val_arr(column_id).FIRST .. regexp_val_arr(column_id).LAST
        LOOP
          temp := regexp_replace(temp,
                                 regexp_val_arr(column_id)(i),
                                 exp_val_arr(column_id)(i));
        END LOOP;

        RETURN temp;
    end;

    FUNCTION  replaceregexpchar (col VARCHAR2, column_id NUMBER) RETURN VARCHAR2 IS
        TYPE cur_typ IS REF CURSOR;
        c cur_typ;
        idx NUMBER:=0;
        temp varchar2(4000) :=  col;
        query_str VARCHAR2(200) := 'SELECT  REGEX, EXPR FROM mgmt_dm_rule_'||column_id;
        regex VARCHAR2(4000);
        expr VARCHAR2(4000);
        BEGIN
        IF NOT(regexp_val_arr.EXISTS(column_id))
        THEN
          OPEN c FOR query_str;
          LOOP
            FETCH c INTO regex, expr;
            EXIT WHEN c%NOTFOUND;

            regexp_val_arr(column_id)(idx) := regex;
            exp_val_arr(column_id)(idx) := expr;
            idx := idx+1;
          END LOOP;
        END IF;

        FOR i IN regexp_val_arr(column_id).FIRST .. regexp_val_arr(column_id).LAST
        LOOP
          temp := substrb(regexp_replace(temp,
                                 regexp_val_arr(column_id)(i),
                                 exp_val_arr(column_id)(i)), 1, 4000);
        END LOOP;

        RETURN temp;
    end;

 procedure distribute_nos(low number,high number,numd number)
 is
   maparr numarr;
   randmax number := 0;
   randidx number := 0;
 begin
   for i in low..high loop
     maparr(i) := i;
   end loop;

   randmax := high;

   for i in 1..numd loop
     randidx := trunc(dbms_random.value(low, randmax));
     permuarr(i) := maparr(randidx);
     maparr(randidx) := maparr(randmax);
     randmax := randmax - 1;

     if randmax <= 0 OR randmax < low then
       randmax := high;
     end if;
   end loop;

 end distribute_nos;

 function fetchnum(idx number,low number,high number,numd number)
 return number
 is
 retval number := 0; 
 begin

   if populatearr = 0 then
     permuarr.delete();
     distribute_nos(low, high, numd);
     populatearr := 1;
   end if; 

   retval := permuarr(idx); 

   if idx = numd then 
     populatearr := 0; 
     permuarr.delete(); 
   end if; 

   return retval;
 end fetchnum;

    FUNCTION randomencode (i_input VARCHAR2, pad_length NUMBER) RETURN VARCHAR2 deterministic parallel_enable IS
        TYPE charmap IS TABLE OF VARCHAR2(1) INDEX BY BINARY_INTEGER;
        l_input NUMBER;
        l_mod NUMBER;
        l_retCode VARCHAR2(100);
        l_map charmap;
        l_base number := 25;
        BEGIN
        if (i_input is null) then
            return lpad('a',pad_length,'a');
        end if;

        l_map(0)  := 'a';
        l_map(1)  := 'b';
        l_map(2)  := 'c';
        l_map(3)  := 'd';
        l_map(4)  := 'e';
        l_map(5)  := 'f';
        l_map(6)  := 'g';
        l_map(7)  := 'h';
        l_map(8)  := 'i';
        l_map(9)  := 'j';
        l_map(10) := 'k';
        l_map(11) := 'l';
        l_map(12) := 'm';
        l_map(13) := 'n';
        l_map(14) := 'o';
        l_map(15) := 'p';
        l_map(16) := 'q';
        l_map(17) := 'r';
        l_map(18) := 's';
        l_map(19) := 't';
        l_map(20) := 'u';
        l_map(21) := 'v';
        l_map(22) := 'w';
        l_map(23) := 'x';
        l_map(24) := 'y';
        l_map(25) := 'z';

        l_input := i_input;
        l_retCode := '';

        LOOP 
    	   -- skip 'a' for padding
            l_mod := l_input mod l_base + 1; 
            l_retCode := l_retCode || l_map(l_mod) ;
            IF (l_input >= l_base) THEN
                l_input := round(l_input / l_base);
            ELSE 
                l_input := 0;
            END IF;
            -- dbms_output.put_line('left ' || l_input || ' mod ' || l_mod );
            EXIT WHEN l_input = 0;
        END LOOP;
        return lpad(l_retCode, pad_length, 'a');
    END ;

function get_package_version return varchar2 is
begin
   return dm_package_version;
end;
procedure set_tbps_option(tbps_option varchar2, 
                          cust_tbps_name varchar2, 
                          create_omf varchar2) is 
begin
  if tbps_option = '0' then
    tbps_name := null;
    tbps_data_file_name := null;
  elsif tbps_option = '1' then
    tbps_name := 'ORA_DMASK_'|| DBMS_SESSION.UNIQUE_SESSION_ID ||'_TBPS';
    tbps_name := tbps_name ||dbms_random.string('U', 30 - lengthb(tbps_name));
    tbps_name := SYS.DBMS_ASSERT.enquote_name(tbps_name);
    create_new_tbps := true; 
    if create_omf = 'Y' then 
      tbps_data_file_name := null;
    else
      tbps_data_file_name := 'ORA_DMASK_'||
         DBMS_SESSION.UNIQUE_SESSION_ID||'_TBPSDATAFILE';
      tbps_data_file_name := SYS.DBMS_ASSERT.enquote_name(tbps_data_file_name);
      tbps_data_file_name := tbps_data_file_name||'.dbf';
    end if;
  elsif (tbps_option = '2' or tbps_option = '3') and cust_tbps_name is not null then
    tbps_name := SYS.DBMS_ASSERT.enquote_name(cust_tbps_name);
    tbps_data_file_name := null;
    if tbps_option = '3' then
      move_dmask := true;
    end if;
  else
    tbps_name := null;
    tbps_data_file_name := null;
  end if;
end set_tbps_option;
procedure create_new_tablespace as 
begin
 if create_new_tbps then 
  if tbps_data_file_name is not null then
    -- drop tables if exists
    drop_tablespace;
    begin
      execute immediate 'create tablespace '||tbps_name||
       ' datafile '||''''||tbps_data_file_name
         ||''''||' SIZE 100M AUTOEXTEND ON NEXT 
         100M NOLOGGING DEFAULT COMPRESS 
         ONLINE EXTENT MANAGEMENT LOCAL AUTOALLOCATE 
         SEGMENT SPACE MANAGEMENT AUTO ';
      new_tbps_created := true;
    exception
      when others then
        new_tbps_created:=false;
        null;
    end;
  else 
     -- drop tables if exists
    drop_tablespace;
    begin
      execute immediate 'create tablespace       '||tbps_name||' NOLOGGING DEFAULT COMPRESS BASIC';
      new_tbps_created := true;
    exception
      when others then
        new_tbps_created:=false;
        null;
    end;
  end if;
  if new_tbps_created then
    move_dmask := true;
  else 
    -- failed to create tablespace
    -- we will fall back to default option
    move_dmask := false;
    tbps_name := null;
    create_new_tbps := false;
  end if;
 end if;
end create_new_tablespace;
function get_tbps_name return varchar2 is
begin
  return tbps_name;
end get_tbps_name;
function get_tbps_clause return varchar2 is
 tbps_clause varchar2(150) := null;
begin
  if get_tbps_name is not null then
    tbps_clause := ' TABLESPACE '||get_tbps_name;
  end if;
  if isNewTbpsCreated = false then
    tbps_clause := tbps_clause||' COMPRESS BASIC';
  end if;
  return tbps_clause;
end get_tbps_clause;
function get_tbps_clause_dmask return varchar2 is
 tbps_clause varchar2(150) := null;
begin
  if get_tbps_name is not null then
   tbps_clause := ' TABLESPACE '||get_tbps_name; 
   tbps_clause := tbps_clause||' COMPRESS ';
  end if;
  return tbps_clause;
end get_tbps_clause_dmask;
function get_tbps_clause_stage return varchar2 is
  tbps_clause varchar2(150) := null;
begin
  if get_tbps_name is not null then
     tbps_clause := ' TABLESPACE '||get_tbps_name; 
  end if;
  if create_new_tbps then
    tbps_clause := tbps_clause||' NOCOMPRESS ';
  end if;
  tbps_clause := tbps_clause||' PCTFREE 0';
  return tbps_clause;
end get_tbps_clause_stage;
function get_tbps_clause_temp return varchar2 is
 tbps_clause varchar2(150) := null;
begin
  if get_tbps_name is not null then
    tbps_clause := ' TABLESPACE '||get_tbps_name;
  end if;
  if isNewTbpsCreated = false then
    tbps_clause := tbps_clause||' COMPRESS BASIC';
  end if;
  return tbps_clause;
end get_tbps_clause_temp;
procedure drop_tablespace as
begin
  if create_new_tbps then 
    execute immediate 'drop tablespace '    ||tbps_name||' including contents and     datafiles';
  end if;
exception
  when others then
    null;
end drop_tablespace;
function is_move_dmask return boolean is
begin
  return move_dmask;
end is_move_dmask;
function isNewTbpsCreated return boolean is 
begin
  return new_tbps_created;
end isNewTbpsCreated;
END mgmt$mask_util;
/

create or replace type mgmt$mask_array_list as table of varchar2(128)
/
begin mgmt$mask_util.set_tbps_option(:tbps_opt, :cst_tbs_n, :create_omf); end;
/
begin mgmt$mask_util.create_new_tablespace; end;
/
begin mgmt$mask_util.set_spa_trial(:spa_trial); end;
/
begin mgmt$mask_util.set_sts_owner(:sts_owner); end;
/
begin mgmt$mask_util.set_sts_name(:sts_name); end;
/
begin mgmt$mask_util.set_task_name(:task_name); end;
/
begin mgmt$mask_util.set_report_dir(:report_dir); end;
/
CREATE OR REPLACE PROCEDURE mgmt$mask_setUpMappingTable (sid VARCHAR2, sourcecol VARCHAR2, sourcetab VARCHAR2)
AUTHID CURRENT_USER IS
    ctsql_text VARCHAR2(400) := 'CREATE TABLE MGMT_DM_TT_' || sid || 
      '(ORIG_VAL, NEW_VAL) ' ||
      ' AS (SELECT '|| sourcecol || ',' || sourcecol ||
      ' FROM ' || sourcetab || ' WHERE ROWNUM<1) ';
    itsql_text VARCHAR2(400) := 'INSERT INTO  MGMT_DM_TT_' || sid || 
      ' SELECT ' || sourcecol || ', dm_seq.nextval FROM ' ||
      '( SELECT DISTINCT ' || sourcecol || ' FROM ' ||  sourcetab || ')';
    dlsql_text VARCHAR2(400) := 'DELETE FROM  MGMT_DM_TT_' || sid  ;
BEGIN
    BEGIN
      EXECUTE IMMEDIATE ctsql_text;
    EXCEPTION
      WHEN OTHERS THEN
        EXECUTE IMMEDIATE dlsql_text;
    END;
EXCEPTION
      WHEN OTHERS THEN
        mgmt$mask_errorExit ('ERROR accessing table: MGMT_DM_TT_' || sid);
END mgmt$mask_setUpMappingTable;
/

CREATE OR REPLACE PROCEDURE mgmt$step_1_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 1 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF NOT mgmt$mask_util.isSPATrialRequired THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('BEGIN mgmt$mask_util.set_task_name (DBMS_SQLPA.create_analysis_task(sqlset_name=>mgmt$mask_util.get_sts_name ,task_name=>mgmt$mask_util.get_task_name , sqlset_owner=>mgmt$mask_util.get_sts_owner)); END; 
');
      EXECUTE IMMEDIATE 'BEGIN mgmt$mask_util.set_task_name (DBMS_SQLPA.create_analysis_task(sqlset_name=>mgmt$mask_util.get_sts_name ,task_name=>mgmt$mask_util.get_task_name , sqlset_owner=>mgmt$mask_util.get_sts_owner)); END; 
';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_1_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_2_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 2 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF NOT mgmt$mask_util.isSPATrialRequired THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('BEGIN DBMS_SQLPA.execute_analysis_task(task_name => mgmt$mask_util.get_task_name, execution_type  => ''explain plan'', execution_name  => ''pre-mask_DM_RAT_800''); END; 
');
      EXECUTE IMMEDIATE 'BEGIN DBMS_SQLPA.execute_analysis_task(task_name => mgmt$mask_util.get_task_name, execution_type  => ''explain plan'', execution_name  => ''pre-mask_DM_RAT_800''); END; 
';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_2_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_3_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 3 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DECLARE 
  CURSOR fk_sql IS select refr.owner, refr.table_name, refr.constraint_name 
     from dba_constraints refd, dba_constraints refr 
     where        refd.owner = ''DM_PCSS_OWN'' and 
             refd.table_name = ''PCSS_SOL_TITULAR'' and 
        refr.constraint_type = ''R'' 
        and refr.r_owner = refd.owner and 
      refr.r_constraint_name = refd.constraint_name;
BEGIN 
  FOR fk IN fk_sql 
  LOOP 
    EXECUTE IMMEDIATE ''ALTER TABLE "'' || fk.owner || ''"."'' || 
      fk.table_name || ''" DROP CONSTRAINT "'' || fk.constraint_name || ''"''; 
  END LOOP;
END;');
      EXECUTE IMMEDIATE 'DECLARE 
  CURSOR fk_sql IS select refr.owner, refr.table_name, refr.constraint_name 
     from dba_constraints refd, dba_constraints refr 
     where        refd.owner = ''DM_PCSS_OWN'' and 
             refd.table_name = ''PCSS_SOL_TITULAR'' and 
        refr.constraint_type = ''R'' 
        and refr.r_owner = refd.owner and 
      refr.r_constraint_name = refd.constraint_name;
BEGIN 
  FOR fk IN fk_sql 
  LOOP 
    EXECUTE IMMEDIATE ''ALTER TABLE "'' || fk.owner || ''"."'' || 
      fk.table_name || ''" DROP CONSTRAINT "'' || fk.constraint_name || ''"''; 
  END LOOP;
END;';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_3_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_4_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 4 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE DELETE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE DELETE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_4_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_5_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 5 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE INSERT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE INSERT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_5_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_6_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 6 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_6_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_7_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 7 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE UPDATE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE UPDATE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_7_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_8_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 8 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE DELETE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE DELETE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_8_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_9_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 9 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE INSERT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE INSERT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_9_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_10_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 10 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_10_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_11_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 11 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE UPDATE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE UPDATE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_11_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_12_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 12 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE REFERENCES ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "SISS_OWN"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE REFERENCES ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "SISS_OWN"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_12_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_13_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 13 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "SISS_OWN"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "SISS_OWN"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_13_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_14_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 14 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "SISS_REP_USER"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' REVOKE SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" FROM "SISS_REP_USER"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_14_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_15_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 15 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DECLARE 
  CURSOR c_sql IS select owner, table_name, constraint_name, 
    constraint_type, generated, index_name from dba_constraints 
  where        owner = ''DM_PCSS_OWN'' and 
          table_name = ''PCSS_SOL_TITULAR'' 
  and (constraint_type NOT IN (''S'',''C'') OR 
                (constraint_type = ''C'' 
                 AND generated != ''GENERATED NAME'' 
                  OR deferrable != ''NOT DEFERRABLE'' 
                  OR validated != ''VALIDATED'' 
                  OR status != ''ENABLED'')); 
BEGIN 
  FOR c IN c_sql 
  LOOP 
      EXECUTE IMMEDIATE ''ALTER TABLE "'' || c.owner || ''"."'' || 
        c.table_name || ''" DROP CONSTRAINT "'' || c.constraint_name || ''"'';
  END LOOP;
END;');
      EXECUTE IMMEDIATE 'DECLARE 
  CURSOR c_sql IS select owner, table_name, constraint_name, 
    constraint_type, generated, index_name from dba_constraints 
  where        owner = ''DM_PCSS_OWN'' and 
          table_name = ''PCSS_SOL_TITULAR'' 
  and (constraint_type NOT IN (''S'',''C'') OR 
                (constraint_type = ''C'' 
                 AND generated != ''GENERATED NAME'' 
                  OR deferrable != ''NOT DEFERRABLE'' 
                  OR validated != ''VALIDATED'' 
                  OR status != ''ENABLED'')); 
BEGIN 
  FOR c IN c_sql 
  LOOP 
      EXECUTE IMMEDIATE ''ALTER TABLE "'' || c.owner || ''"."'' || 
        c.table_name || ''" DROP CONSTRAINT "'' || c.constraint_name || ''"'';
  END LOOP;
END;';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_15_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_16_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 16 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP INDEX "DM_PCSS_OWN"."PK_PCSS_SOL_TITULAR"');
      EXECUTE IMMEDIATE 'DROP INDEX "DM_PCSS_OWN"."PK_PCSS_SOL_TITULAR"';
    EXCEPTION
      WHEN OTHERS THEN
      IF SQLCODE = -1418 THEN 
        mgmt$mask_sendMsg ( 'Index already dropped, continuing' );
      ELSIF SQLCODE = -942 THEN
        mgmt$mask_sendMsg ( 'Table or view already dropped, continuing' );
      ELSIF SQLCODE = -24344 THEN
        mgmt$mask_sendMsg ( 'Compiled with errors, continuing' );
      ELSE
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
      END IF;
    END;
END mgmt$step_16_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_17_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 17 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR$DMASK" PURGE');
      EXECUTE IMMEDIATE 'DROP TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR$DMASK" PURGE';
    EXCEPTION
      WHEN OTHERS THEN
      IF SQLCODE = -1418 THEN 
        mgmt$mask_sendMsg ( 'Index already dropped, continuing' );
      ELSIF SQLCODE = -942 THEN
        mgmt$mask_sendMsg ( 'Table or view already dropped, continuing' );
      ELSIF SQLCODE = -24344 THEN
        mgmt$mask_sendMsg ( 'Compiled with errors, continuing' );
      ELSE
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
      END IF;
    END;
END mgmt$step_17_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_18_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 18 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" RENAME TO "PCSS_SOL_TITULAR$DMASK"');
      EXECUTE IMMEDIATE 'ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" RENAME TO "PCSS_SOL_TITULAR$DMASK"';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_18_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_19_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 19 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg (' begin 
  if mgmt$mask_util.is_move_dmask then 
    EXECUTE IMMEDIATE ''ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR$DMASK" MOVE  ''||mgmt$mask_util.get_tbps_clause_dmask||''''; 
  end if;
 end;
');
      EXECUTE IMMEDIATE ' begin 
  if mgmt$mask_util.is_move_dmask then 
    EXECUTE IMMEDIATE ''ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR$DMASK" MOVE  ''||mgmt$mask_util.get_tbps_clause_dmask||''''; 
  end if;
 end;
';
    EXCEPTION
      WHEN OTHERS THEN
           sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
           mgmt$mask_sendMsg ( 'Could not move table to custom tablespace, continuing' );
           mgmt$mask_sendMsg (sqlerr_msg);
    END;
END mgmt$step_19_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_20_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 20 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('  CREATE TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR"
    SEGMENT CREATION IMMEDIATE
  PCTFREE 10 PCTUSED 40 INITRANS 1 NOCOMPRESS NOLOGGING
  STORAGE( INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "PCSS_DAT"
  PARALLEL  AS SELECT s."ID_SOL", CAST(astsysadmin.func_dm_enmascara_nombre(s."NOMBRE") as VARCHAR2(60 CHAR)) "NOMBRE", CAST(astsysadmin.func_dm_enmascara_nombre(s."APE1") as VARCHAR2(40 CHAR)) "APE1", CAST(astsysadmin.func_dm_enmascara_nombre(s."APE2") as VARCHAR2(40 CHAR)) "APE2", s."TIPOID", CAST(astsysadmin.func_dm_enmascara_nif(s."NIFNIE") as VARCHAR2(20 CHAR)) "NIFNIE", s."CIAS", s."NACIONALIDAD", s."FECNAC", s."SEXO", s."TIPOVIA", CAST(astsysadmin.func_dm_enmascara_nombre(s."DOMICILIO") as VARCHAR2(150 CHAR)) "DOMICILIO", s."NUMERO", s."KM", s."BLOQUE", s."PORTAL", s."ESCALERA", s."PLANTA", s."PUERTA", s."LOCAL", s."PROV", s."CP", s."ANIOSRESI", s."IBAN", s."ENTIDAD", s."SUCURSAL", s."DC", CAST(astsysadmin.func_dm_enmascara_iban(s."CUENTA") as VARCHAR2(10 CHAR)) "CUENTA", CAST(astsysadmin.func_dm_enmascara_telefono(s."TELEF1") as VARCHAR2(20 CHAR)) "TELEF1", CAST(astsysadmin.func_dm_enmascara_telefono(s."TELEF2") as VARCHAR2(20 CHAR)) "TELEF2", s."EMAIL", s."CUENTA_TITU_NIF", s."CUENTA_TITU_NOM", s."EST_CIVIL", s."CUENTA_TITU_APE1", s."CUENTA_TITU_APE2" FROM "DM_PCSS_OWN"."PCSS_SOL_TITULAR$DMASK"  s ');
      EXECUTE IMMEDIATE '  CREATE TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR"
    SEGMENT CREATION IMMEDIATE
  PCTFREE 10 PCTUSED 40 INITRANS 1 NOCOMPRESS NOLOGGING
  STORAGE( INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "PCSS_DAT"
  PARALLEL  AS SELECT s."ID_SOL", CAST(astsysadmin.func_dm_enmascara_nombre(s."NOMBRE") as VARCHAR2(60 CHAR)) "NOMBRE", CAST(astsysadmin.func_dm_enmascara_nombre(s."APE1") as VARCHAR2(40 CHAR)) "APE1", CAST(astsysadmin.func_dm_enmascara_nombre(s."APE2") as VARCHAR2(40 CHAR)) "APE2", s."TIPOID", CAST(astsysadmin.func_dm_enmascara_nif(s."NIFNIE") as VARCHAR2(20 CHAR)) "NIFNIE", s."CIAS", s."NACIONALIDAD", s."FECNAC", s."SEXO", s."TIPOVIA", CAST(astsysadmin.func_dm_enmascara_nombre(s."DOMICILIO") as VARCHAR2(150 CHAR)) "DOMICILIO", s."NUMERO", s."KM", s."BLOQUE", s."PORTAL", s."ESCALERA", s."PLANTA", s."PUERTA", s."LOCAL", s."PROV", s."CP", s."ANIOSRESI", s."IBAN", s."ENTIDAD", s."SUCURSAL", s."DC", CAST(astsysadmin.func_dm_enmascara_iban(s."CUENTA") as VARCHAR2(10 CHAR)) "CUENTA", CAST(astsysadmin.func_dm_enmascara_telefono(s."TELEF1") as VARCHAR2(20 CHAR)) "TELEF1", CAST(astsysadmin.func_dm_enmascara_telefono(s."TELEF2") as VARCHAR2(20 CHAR)) "TELEF2", s."EMAIL", s."CUENTA_TITU_NIF", s."CUENTA_TITU_NOM", s."EST_CIVIL", s."CUENTA_TITU_APE1", s."CUENTA_TITU_APE2" FROM "DM_PCSS_OWN"."PCSS_SOL_TITULAR$DMASK"  s ';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_20_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_21_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 21 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" LOGGING  NOPARALLEL ');
      EXECUTE IMMEDIATE 'ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" LOGGING  NOPARALLEL ';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_21_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_22_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 22 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR$DMASK" PURGE');
      EXECUTE IMMEDIATE 'DROP TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR$DMASK" PURGE';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_22_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_23_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 23 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('  CREATE UNIQUE INDEX "DM_PCSS_OWN"."PK_PCSS_SOL_TITULAR" ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ("ID_SOL")
  PCTFREE 10 INITRANS 2 LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645 
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "PCSS_DAT" ');
      EXECUTE IMMEDIATE '  CREATE UNIQUE INDEX "DM_PCSS_OWN"."PK_PCSS_SOL_TITULAR" ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ("ID_SOL")
  PCTFREE 10 INITRANS 2 LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645 
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1 BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "PCSS_DAT" ';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_23_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_24_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 24 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('ALTER INDEX "DM_PCSS_OWN"."PK_PCSS_SOL_TITULAR" PARALLEL 1');
      EXECUTE IMMEDIATE 'ALTER INDEX "DM_PCSS_OWN"."PK_PCSS_SOL_TITULAR" PARALLEL 1';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_24_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_25_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 25 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ADD (CONSTRAINT "PK_PCSS_SOL_TITULAR" PRIMARY KEY ("ID_SOL")  )');
      EXECUTE IMMEDIATE 'ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ADD (CONSTRAINT "PK_PCSS_SOL_TITULAR" PRIMARY KEY ("ID_SOL")  )';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_25_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_26_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 26 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ADD (CONSTRAINT "FK_PCSS_SOLTITULAR_SOL" FOREIGN KEY ("ID_SOL") REFERENCES "DM_PCSS_OWN"."PCSS_SOLICITUD" ("ID_SOL")  ENABLE NOVALIDATE )');
      EXECUTE IMMEDIATE 'ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ADD (CONSTRAINT "FK_PCSS_SOLTITULAR_SOL" FOREIGN KEY ("ID_SOL") REFERENCES "DM_PCSS_OWN"."PCSS_SOLICITUD" ("ID_SOL")  ENABLE NOVALIDATE )';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_26_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_27_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 27 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" MODIFY CONSTRAINT "FK_PCSS_SOLTITULAR_SOL" VALIDATE');
      EXECUTE IMMEDIATE 'ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" MODIFY CONSTRAINT "FK_PCSS_SOLTITULAR_SOL" VALIDATE';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_27_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_28_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 28 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ADD (CONSTRAINT "FK_PCSS_SOLTITU_TIPOID" FOREIGN KEY ("TIPOID") REFERENCES "DM_PCSS_OWN"."PCSS_TIPOID" ("TIID_CODIGO")  ENABLE NOVALIDATE )');
      EXECUTE IMMEDIATE 'ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ADD (CONSTRAINT "FK_PCSS_SOLTITU_TIPOID" FOREIGN KEY ("TIPOID") REFERENCES "DM_PCSS_OWN"."PCSS_TIPOID" ("TIID_CODIGO")  ENABLE NOVALIDATE )';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_28_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_29_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 29 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" MODIFY CONSTRAINT "FK_PCSS_SOLTITU_TIPOID" VALIDATE');
      EXECUTE IMMEDIATE 'ALTER TABLE "DM_PCSS_OWN"."PCSS_SOL_TITULAR" MODIFY CONSTRAINT "FK_PCSS_SOLTITU_TIPOID" VALIDATE';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_29_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_30_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 30 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT DELETE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT DELETE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_30_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_31_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 31 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT INSERT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT INSERT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_31_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_32_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 32 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_32_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_33_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 33 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT UPDATE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT UPDATE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_EXPLOTACION_PCSS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_33_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_34_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 34 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT DELETE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT DELETE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_34_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_35_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 35 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT INSERT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT INSERT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_35_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_36_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 36 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_36_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_37_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 37 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT UPDATE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT UPDATE ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "ROL_TECNICOS_SISS"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_37_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_38_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 38 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT REFERENCES ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "SISS_OWN" WITH GRANT OPTION'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT REFERENCES ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "SISS_OWN" WITH GRANT OPTION'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_38_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_39_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 39 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "SISS_OWN" WITH GRANT OPTION'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "SISS_OWN" WITH GRANT OPTION'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_39_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_40_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 40 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
    mgmt$mask_sendMsg ('Processing grants on object using: ');
    mgmt$mask_sendMsg ('CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "SISS_REP_USER"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END;  ');
    mgmt$mask_sendMsg ('BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END;  ');
    mgmt$mask_sendMsg ('DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 ');
    EXECUTE IMMEDIATE 'CREATE OR REPLACE procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800 AS 
                grant_cur INTEGER; 
                BEGIN 
                  grant_cur := DBMS_SQL.OPEN_CURSOR; 
                  DBMS_SQL.PARSE (grant_cur, '' GRANT SELECT ON "DM_PCSS_OWN"."PCSS_SOL_TITULAR" TO "SISS_REP_USER"'', DBMS_SQL.NATIVE); 
                  DBMS_SQL.CLOSE_CURSOR (grant_cur); 
                END; ';
    EXECUTE IMMEDIATE 'BEGIN "DM_PCSS_OWN".MGMT$MASK_GRANT_800; END; ';
    EXECUTE IMMEDIATE 'DROP procedure "DM_PCSS_OWN".MGMT$MASK_GRANT_800';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_40_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_41_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 41 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."ANIOSRESI"  IS ''Años de residencia efectiva en Aragón''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."ANIOSRESI"  IS ''Años de residencia efectiva en Aragón''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_41_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_42_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 42 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."APE1"  IS ''Primer Apellido''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."APE1"  IS ''Primer Apellido''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_42_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_43_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 43 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."APE2"  IS ''Segundo Apellido''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."APE2"  IS ''Segundo Apellido''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_43_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_44_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 44 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."BLOQUE"  IS ''Bloque de dirección''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."BLOQUE"  IS ''Bloque de dirección''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_44_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_45_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 45 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."CIAS"  IS ''Cias''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."CIAS"  IS ''Cias''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_45_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_46_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 46 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."CP"  IS ''Código Postal''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."CP"  IS ''Código Postal''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_46_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_47_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 47 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."CUENTA"  IS ''Cuenta bancaria''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."CUENTA"  IS ''Cuenta bancaria''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_47_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_48_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 48 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."CUENTA_TITU_NIF"  IS ''Nif del titular de la cuenta de banco''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."CUENTA_TITU_NIF"  IS ''Nif del titular de la cuenta de banco''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_48_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_49_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 49 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."CUENTA_TITU_NOM"  IS ''Nombre y apellidos del titular de la cuenta del banco''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."CUENTA_TITU_NOM"  IS ''Nombre y apellidos del titular de la cuenta del banco''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_49_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_50_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 50 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."DC"  IS ''Digito Control cuenta bancaria''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."DC"  IS ''Digito Control cuenta bancaria''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_50_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_51_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 51 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."DOMICILIO"  IS ''Domicilio''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."DOMICILIO"  IS ''Domicilio''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_51_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_52_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 52 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."EMAIL"  IS ''Email''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."EMAIL"  IS ''Email''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_52_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_53_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 53 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."ENTIDAD"  IS ''Entidad cuenta bancaria''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."ENTIDAD"  IS ''Entidad cuenta bancaria''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_53_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_54_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 54 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."ESCALERA"  IS ''Escalera de dirección''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."ESCALERA"  IS ''Escalera de dirección''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_54_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_55_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 55 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."EST_CIVIL"  IS ''Estado civil del titular''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."EST_CIVIL"  IS ''Estado civil del titular''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_55_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_56_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 56 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."FECNAC"  IS ''Fecha de Nacimiento''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."FECNAC"  IS ''Fecha de Nacimiento''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_56_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_57_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 57 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."IBAN"  IS ''Iban cuenta bancaria''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."IBAN"  IS ''Iban cuenta bancaria''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_57_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_58_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 58 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."ID_SOL"  IS ''Identificador de la solicitud''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."ID_SOL"  IS ''Identificador de la solicitud''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_58_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_59_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 59 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."KM"  IS ''KM de dirección''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."KM"  IS ''KM de dirección''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_59_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_60_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 60 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."LOCAL"  IS ''Localidad''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."LOCAL"  IS ''Localidad''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_60_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_61_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 61 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."NACIONALIDAD"  IS ''Nacionalidad''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."NACIONALIDAD"  IS ''Nacionalidad''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_61_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_62_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 62 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."NIFNIE"  IS ''Nif Nie''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."NIFNIE"  IS ''Nif Nie''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_62_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_63_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 63 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."NOMBRE"  IS ''Nombre''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."NOMBRE"  IS ''Nombre''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_63_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_64_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 64 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."NUMERO"  IS ''Número de dirección''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."NUMERO"  IS ''Número de dirección''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_64_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_65_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 65 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."PLANTA"  IS ''Planta de dirección''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."PLANTA"  IS ''Planta de dirección''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_65_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_66_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 66 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."PORTAL"  IS ''Portal de dirección''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."PORTAL"  IS ''Portal de dirección''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_66_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_67_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 67 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."PROV"  IS ''Provincia''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."PROV"  IS ''Provincia''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_67_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_68_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 68 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."PUERTA"  IS ''Puerta de dirección''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."PUERTA"  IS ''Puerta de dirección''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_68_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_69_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 69 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."SEXO"  IS ''Sexo S\/N''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."SEXO"  IS ''Sexo S\/N''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_69_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_70_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 70 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."SUCURSAL"  IS ''Sucursal cuenta bancaria''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."SUCURSAL"  IS ''Sucursal cuenta bancaria''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_70_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_71_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 71 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."TELEF1"  IS ''Teléfono 1''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."TELEF1"  IS ''Teléfono 1''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_71_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_72_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 72 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."TELEF2"  IS ''Teléfono 2''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."TELEF2"  IS ''Teléfono 2''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_72_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_73_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 73 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."TIPOID"  IS ''Tipo de Identificación''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."TIPOID"  IS ''Tipo de Identificación''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_73_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_74_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 74 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."TIPOVIA"  IS ''Tipo de Vía''');
      EXECUTE IMMEDIATE 'COMMENT ON COLUMN "DM_PCSS_OWN"."PCSS_SOL_TITULAR"."TIPOVIA"  IS ''Tipo de Vía''';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_74_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_75_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 75 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('BEGIN DBMS_STATS.GATHER_TABLE_STATS(''"DM_PCSS_OWN"'', ''"PCSS_SOL_TITULAR"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE, cascade=>TRUE); END;');
      EXECUTE IMMEDIATE 'BEGIN DBMS_STATS.GATHER_TABLE_STATS(''"DM_PCSS_OWN"'', ''"PCSS_SOL_TITULAR"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE, cascade=>TRUE); END;';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_75_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_76_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 76 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF NOT mgmt$mask_util.isSPATrialRequired THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('BEGIN DBMS_SQLPA.execute_analysis_task(task_name => mgmt$mask_util.get_task_name, execution_type  => ''explain plan'', execution_name  => ''post-mask_DM_RAT_800''); END; 
');
      EXECUTE IMMEDIATE 'BEGIN DBMS_SQLPA.execute_analysis_task(task_name => mgmt$mask_util.get_task_name, execution_type  => ''explain plan'', execution_name  => ''post-mask_DM_RAT_800''); END; 
';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_76_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_77_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 77 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF NOT mgmt$mask_util.isSPATrialRequired THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('BEGIN DBMS_SQLPA.execute_analysis_task(task_name => mgmt$mask_util.get_task_name, execution_type  => ''compare'', execution_name  => ''compare-mask_DM_RAT_800''); END; 
');
      EXECUTE IMMEDIATE 'BEGIN DBMS_SQLPA.execute_analysis_task(task_name => mgmt$mask_util.get_task_name, execution_type  => ''compare'', execution_name  => ''compare-mask_DM_RAT_800''); END; 
';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_77_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_78_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 78 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF NOT mgmt$mask_util.isSPATrialRequired THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('begin mgmt$mask_util.create_xml_report(DBMS_SQLPA.report_analysis_task(task_name => mgmt$mask_util.get_task_name,type => ''html'') );  END; 
');
      EXECUTE IMMEDIATE 'begin mgmt$mask_util.create_xml_report(DBMS_SQLPA.report_analysis_task(task_name => mgmt$mask_util.get_task_name,type => ''html'') );  END; 
';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_78_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_79_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 79 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF NOT mgmt$mask_util.isSPATrialRequired THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('declare 
 l_task_id number ;
 begin 
  select task_id  into l_task_id from dba_advisor_tasks where task_name = mgmt$mask_util.get_task_name and owner = user;
   dbms_rat_mask.remove_spa_peeked_binds(l_task_id);
 end; 
');
      EXECUTE IMMEDIATE 'declare 
 l_task_id number ;
 begin 
  select task_id  into l_task_id from dba_advisor_tasks where task_name = mgmt$mask_util.get_task_name and owner = user;
   dbms_rat_mask.remove_spa_peeked_binds(l_task_id);
 end; 
';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_79_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_80_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 80 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('alter system flush shared_pool');
      EXECUTE IMMEDIATE 'alter system flush shared_pool';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_80_800;
/

CREATE OR REPLACE PROCEDURE mgmt$step_81_800(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 81 THEN
      return;
    END IF;

    mgmt$mask_setStep (800, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('alter system checkpoint');
      EXECUTE IMMEDIATE 'alter system checkpoint';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_81_800;
/

CREATE OR REPLACE PROCEDURE mgmt$mask_cleanup_800 (script_id IN INTEGER, job_table IN VARCHAR2, step_num IN INTEGER, highest_step IN INTEGER)
AUTHID CURRENT_USER IS
BEGIN
    IF step_num <= highest_step THEN
      return;
    END IF;

    mgmt$mask_sendMsg ('Starting cleanup of recovery tables');

    mgmt$mask_deleteJobTableEntry(script_id, job_table, step_num, highest_step);
    mgmt$mask_util.drop_tablespace;
    mgmt$mask_sendMsg ('Completed cleanup of recovery tables');
END mgmt$mask_cleanup_800;
/

CREATE OR REPLACE PROCEDURE mgmt$mask_commentheader_800 IS
BEGIN
     mgmt$mask_sendMsg ('--   Target database:	presocsa.aragon.local');
     mgmt$mask_sendMsg ('--   Script generated at:	19-JAN-2026   13:58');
END mgmt$mask_commentheader_800;
/

-- Script Execution Controller
-- ==============================================

ALTER SESSION ENABLE PARALLEL DML;
ALTER SESSION SET QUERY_REWRITE_ENABLED = FALSE; 
ALTER SESSION FORCE PARALLEL DDL; 
ALTER SESSION FORCE PARALLEL QUERY; 
variable step_num number;
exec mgmt$mask_commentheader_800;
exec mgmt$mask_sendMsg ('Starting Data Masking');
show user;
exec mgmt$mask_checkDBAPrivs;
exec mgmt$mask_setupJobTable (800, 'MGMT$MASK_CHECKPOINT', :step_num);

exec mgmt$step_1_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_2_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_3_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_4_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_5_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_6_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_7_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_8_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_9_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_10_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_11_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_12_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_13_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_14_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_15_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_16_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_17_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_18_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_19_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_20_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_21_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_22_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_23_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_24_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_25_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_26_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_27_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_28_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_29_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_30_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_31_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_32_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_33_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_34_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_35_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_36_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_37_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_38_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_39_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_40_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_41_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_42_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_43_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_44_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_45_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_46_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_47_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_48_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_49_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_50_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_51_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_52_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_53_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_54_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_55_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_56_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_57_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_58_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_59_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_60_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_61_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_62_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_63_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_64_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_65_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_66_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_67_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_68_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_69_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_70_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_71_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_72_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_73_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_74_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_75_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_76_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_77_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_78_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_79_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_80_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_81_800(800, 'MGMT$MASK_CHECKPOINT', :step_num);

exec mgmt$mask_sendMsg ('Completed Data Masking. Starting cleanup phase.');

exec mgmt$mask_cleanup_800 (800, 'MGMT$MASK_CHECKPOINT', :step_num, 81);

exec mgmt$mask_sendMsg ('Starting cleanup of generated procedures');

DROP PROCEDURE mgmt$step_1_800;
DROP PROCEDURE mgmt$step_2_800;
DROP PROCEDURE mgmt$step_3_800;
DROP PROCEDURE mgmt$step_4_800;
DROP PROCEDURE mgmt$step_5_800;
DROP PROCEDURE mgmt$step_6_800;
DROP PROCEDURE mgmt$step_7_800;
DROP PROCEDURE mgmt$step_8_800;
DROP PROCEDURE mgmt$step_9_800;
DROP PROCEDURE mgmt$step_10_800;
DROP PROCEDURE mgmt$step_11_800;
DROP PROCEDURE mgmt$step_12_800;
DROP PROCEDURE mgmt$step_13_800;
DROP PROCEDURE mgmt$step_14_800;
DROP PROCEDURE mgmt$step_15_800;
DROP PROCEDURE mgmt$step_16_800;
DROP PROCEDURE mgmt$step_17_800;
DROP PROCEDURE mgmt$step_18_800;
DROP PROCEDURE mgmt$step_19_800;
DROP PROCEDURE mgmt$step_20_800;
DROP PROCEDURE mgmt$step_21_800;
DROP PROCEDURE mgmt$step_22_800;
DROP PROCEDURE mgmt$step_23_800;
DROP PROCEDURE mgmt$step_24_800;
DROP PROCEDURE mgmt$step_25_800;
DROP PROCEDURE mgmt$step_26_800;
DROP PROCEDURE mgmt$step_27_800;
DROP PROCEDURE mgmt$step_28_800;
DROP PROCEDURE mgmt$step_29_800;
DROP PROCEDURE mgmt$step_30_800;
DROP PROCEDURE mgmt$step_31_800;
DROP PROCEDURE mgmt$step_32_800;
DROP PROCEDURE mgmt$step_33_800;
DROP PROCEDURE mgmt$step_34_800;
DROP PROCEDURE mgmt$step_35_800;
DROP PROCEDURE mgmt$step_36_800;
DROP PROCEDURE mgmt$step_37_800;
DROP PROCEDURE mgmt$step_38_800;
DROP PROCEDURE mgmt$step_39_800;
DROP PROCEDURE mgmt$step_40_800;
DROP PROCEDURE mgmt$step_41_800;
DROP PROCEDURE mgmt$step_42_800;
DROP PROCEDURE mgmt$step_43_800;
DROP PROCEDURE mgmt$step_44_800;
DROP PROCEDURE mgmt$step_45_800;
DROP PROCEDURE mgmt$step_46_800;
DROP PROCEDURE mgmt$step_47_800;
DROP PROCEDURE mgmt$step_48_800;
DROP PROCEDURE mgmt$step_49_800;
DROP PROCEDURE mgmt$step_50_800;
DROP PROCEDURE mgmt$step_51_800;
DROP PROCEDURE mgmt$step_52_800;
DROP PROCEDURE mgmt$step_53_800;
DROP PROCEDURE mgmt$step_54_800;
DROP PROCEDURE mgmt$step_55_800;
DROP PROCEDURE mgmt$step_56_800;
DROP PROCEDURE mgmt$step_57_800;
DROP PROCEDURE mgmt$step_58_800;
DROP PROCEDURE mgmt$step_59_800;
DROP PROCEDURE mgmt$step_60_800;
DROP PROCEDURE mgmt$step_61_800;
DROP PROCEDURE mgmt$step_62_800;
DROP PROCEDURE mgmt$step_63_800;
DROP PROCEDURE mgmt$step_64_800;
DROP PROCEDURE mgmt$step_65_800;
DROP PROCEDURE mgmt$step_66_800;
DROP PROCEDURE mgmt$step_67_800;
DROP PROCEDURE mgmt$step_68_800;
DROP PROCEDURE mgmt$step_69_800;
DROP PROCEDURE mgmt$step_70_800;
DROP PROCEDURE mgmt$step_71_800;
DROP PROCEDURE mgmt$step_72_800;
DROP PROCEDURE mgmt$step_73_800;
DROP PROCEDURE mgmt$step_74_800;
DROP PROCEDURE mgmt$step_75_800;
DROP PROCEDURE mgmt$step_76_800;
DROP PROCEDURE mgmt$step_77_800;
DROP PROCEDURE mgmt$step_78_800;
DROP PROCEDURE mgmt$step_79_800;
DROP PROCEDURE mgmt$step_80_800;
DROP PROCEDURE mgmt$step_81_800;

DROP PROCEDURE mgmt$mask_cleanup_800;
DROP PROCEDURE mgmt$mask_commentheader_800;

exec mgmt$mask_sendMsg ('Completed cleanup of generated procedures');

whenever sqlerror exit;
begin
if :step_num <> 82 then
dbms_standard.raise_application_error(-20001, 'ERROR executing steps ');
end if;
end;
/
whenever sqlerror continue;

exec mgmt$mask_sendMsg ('Script execution complete');


spool off
set pagesize 24
set serveroutput off
set feedback on
set echo on
set ver on
