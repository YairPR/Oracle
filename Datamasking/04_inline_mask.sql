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
    procedure compile_serial ; 
    procedure compile_parallel(degree number) ; 
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
       fp :=utl_file.fopen(dir_name,'DM_RAT_855_impact.html','w');
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
       dbms_output.put_line('SQL Performance analyzer : Impact report generated at ' ||path||'\DM_RAT_855_impact.html');
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

  PROCEDURE compile_serial is 
      timeSql VARCHAR2(200) := 'select count(*) nInvalidBefore, to_char(sysdate,''YYYY-MM-DD HH24:MI:SS'') TimeStamp from DBA_OBJECTS where  STATUS = ''INVALID'' ';
      num number := -1;
      etime varchar2(25);
  BEGIN 
   execute immediate timeSql into num , etime ;
   dbms_output.put_line('Number of invalid objects found before 1st recompile at '|| etime ||' is '|| num );
   sys.utl_recomp.recomp_serial();
   execute immediate timeSql into num , etime ;
   dbms_output.put_line('Number of invalid objects found after 1st recompile at '|| etime ||' is '|| num );
   sys.utl_recomp.recomp_serial();
   execute immediate timeSql into num , etime ;
   dbms_output.put_line('Number of invalid objects found after 2nd recompile at '|| etime ||' is '|| num );
  END;
  PROCEDURE compile_parallel(degree number) is 
      timeSql VARCHAR2(200) := 'select count(*) nInvalidBefore, to_char(sysdate,''YYYY-MM-DD HH24:MI:SS'') TimeStamp from DBA_OBJECTS where  STATUS = ''INVALID'' ';
      num number := -1;
      etime varchar2(25);
  BEGIN 
   execute immediate timeSql into num , etime ;
   dbms_output.put_line('Number of invalid objects found before 1st recompile at '|| etime ||' is '|| num );
   if  degree >= 1  then  sys.utl_recomp.recomp_parallel(degree);
   else  sys.utl_recomp.recomp_parallel(); end if; 
   execute immediate timeSql into num , etime ;
   dbms_output.put_line('Number of invalid objects found after 1st recompile at '|| etime ||' is '|| num );
   if  degree >= 1  then  sys.utl_recomp.recomp_parallel(degree);
   else  sys.utl_recomp.recomp_parallel(); end if; 
   execute immediate timeSql into num , etime ;
   dbms_output.put_line('Number of invalid objects found after 2nd recompile at '|| etime ||' is '|| num );
  END;
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

CREATE OR REPLACE PROCEDURE mgmt$step_1_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 1 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP TABLE "MGMT_DM_TT_856" PURGE');
      EXECUTE IMMEDIATE 'DROP TABLE "MGMT_DM_TT_856" PURGE';
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
END mgmt$step_1_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_2_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 2 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF mgmt$mask_util.isWorkloadMasking OR mgmt$mask_util.isSTSMasking THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "APE2" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_856
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(40 CHAR)) orig_val, CAST(null AS VARCHAR2(40 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(40 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "APE2" orig_val, astsysadmin\.func_dm_enmascara_nombre("APE2") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_856"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

');
      EXECUTE IMMEDIATE 'declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "APE2" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_856
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(40 CHAR)) orig_val, CAST(null AS VARCHAR2(40 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(40 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "APE2" orig_val, astsysadmin\.func_dm_enmascara_nombre("APE2") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_856"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_2_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_3_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 3 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP INDEX MGMT_DM_TT_856_IDX');
      EXECUTE IMMEDIATE 'DROP INDEX MGMT_DM_TT_856_IDX';
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
END mgmt$step_3_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_4_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 4 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('CREATE  INDEX MGMT_DM_TT_856_IDX ON MGMT_DM_TT_856(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ');
      EXECUTE IMMEDIATE 'CREATE  INDEX MGMT_DM_TT_856_IDX ON MGMT_DM_TT_856(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_4_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_5_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 5 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP TABLE "MGMT_DM_TT_857" PURGE');
      EXECUTE IMMEDIATE 'DROP TABLE "MGMT_DM_TT_857" PURGE';
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
END mgmt$step_5_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_6_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 6 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF mgmt$mask_util.isWorkloadMasking OR mgmt$mask_util.isSTSMasking THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "APE1" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_857
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(40 CHAR)) orig_val, CAST(null AS VARCHAR2(40 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(40 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "APE1" orig_val, astsysadmin\.func_dm_enmascara_nombre("APE1") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_857"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

');
      EXECUTE IMMEDIATE 'declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "APE1" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_857
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(40 CHAR)) orig_val, CAST(null AS VARCHAR2(40 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(40 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "APE1" orig_val, astsysadmin\.func_dm_enmascara_nombre("APE1") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_857"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_6_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_7_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 7 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP INDEX MGMT_DM_TT_857_IDX');
      EXECUTE IMMEDIATE 'DROP INDEX MGMT_DM_TT_857_IDX';
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
END mgmt$step_7_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_8_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 8 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('CREATE  INDEX MGMT_DM_TT_857_IDX ON MGMT_DM_TT_857(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ');
      EXECUTE IMMEDIATE 'CREATE  INDEX MGMT_DM_TT_857_IDX ON MGMT_DM_TT_857(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_8_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_9_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 9 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP TABLE "MGMT_DM_TT_858" PURGE');
      EXECUTE IMMEDIATE 'DROP TABLE "MGMT_DM_TT_858" PURGE';
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
END mgmt$step_9_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_10_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 10 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF mgmt$mask_util.isWorkloadMasking OR mgmt$mask_util.isSTSMasking THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "DOMICILIO" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_858
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(150 CHAR)) orig_val, CAST(null AS VARCHAR2(150 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(150 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "DOMICILIO" orig_val, astsysadmin\.func_dm_enmascara_nombre("DOMICILIO") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_858"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

');
      EXECUTE IMMEDIATE 'declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "DOMICILIO" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_858
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(150 CHAR)) orig_val, CAST(null AS VARCHAR2(150 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(150 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "DOMICILIO" orig_val, astsysadmin\.func_dm_enmascara_nombre("DOMICILIO") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_858"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_10_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_11_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 11 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP INDEX MGMT_DM_TT_858_IDX');
      EXECUTE IMMEDIATE 'DROP INDEX MGMT_DM_TT_858_IDX';
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
END mgmt$step_11_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_12_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 12 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('CREATE  INDEX MGMT_DM_TT_858_IDX ON MGMT_DM_TT_858(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ');
      EXECUTE IMMEDIATE 'CREATE  INDEX MGMT_DM_TT_858_IDX ON MGMT_DM_TT_858(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_12_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_13_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 13 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP TABLE "MGMT_DM_TT_859" PURGE');
      EXECUTE IMMEDIATE 'DROP TABLE "MGMT_DM_TT_859" PURGE';
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
END mgmt$step_13_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_14_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 14 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF mgmt$mask_util.isWorkloadMasking OR mgmt$mask_util.isSTSMasking THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "CUENTA" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_859
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(10 CHAR)) orig_val, CAST(null AS VARCHAR2(10 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(10 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "CUENTA" orig_val, astsysadmin\.func_dm_enmascara_iban("CUENTA") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_859"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

');
      EXECUTE IMMEDIATE 'declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "CUENTA" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_859
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(10 CHAR)) orig_val, CAST(null AS VARCHAR2(10 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(10 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "CUENTA" orig_val, astsysadmin\.func_dm_enmascara_iban("CUENTA") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_859"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_14_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_15_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 15 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP INDEX MGMT_DM_TT_859_IDX');
      EXECUTE IMMEDIATE 'DROP INDEX MGMT_DM_TT_859_IDX';
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
END mgmt$step_15_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_16_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 16 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('CREATE  INDEX MGMT_DM_TT_859_IDX ON MGMT_DM_TT_859(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ');
      EXECUTE IMMEDIATE 'CREATE  INDEX MGMT_DM_TT_859_IDX ON MGMT_DM_TT_859(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_16_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_17_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 17 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP TABLE "MGMT_DM_TT_860" PURGE');
      EXECUTE IMMEDIATE 'DROP TABLE "MGMT_DM_TT_860" PURGE';
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
END mgmt$step_17_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_18_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 18 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF mgmt$mask_util.isWorkloadMasking OR mgmt$mask_util.isSTSMasking THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "NIFNIE" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_860
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(20 CHAR)) orig_val, CAST(null AS VARCHAR2(20 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(20 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "NIFNIE" orig_val, astsysadmin\.func_dm_enmascara_nif("NIFNIE") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_860"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

');
      EXECUTE IMMEDIATE 'declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "NIFNIE" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_860
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(20 CHAR)) orig_val, CAST(null AS VARCHAR2(20 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(20 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "NIFNIE" orig_val, astsysadmin\.func_dm_enmascara_nif("NIFNIE") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_860"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_18_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_19_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 19 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP INDEX MGMT_DM_TT_860_IDX');
      EXECUTE IMMEDIATE 'DROP INDEX MGMT_DM_TT_860_IDX';
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
END mgmt$step_19_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_20_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 20 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('CREATE  INDEX MGMT_DM_TT_860_IDX ON MGMT_DM_TT_860(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ');
      EXECUTE IMMEDIATE 'CREATE  INDEX MGMT_DM_TT_860_IDX ON MGMT_DM_TT_860(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_20_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_21_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 21 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP TABLE "MGMT_DM_TT_861" PURGE');
      EXECUTE IMMEDIATE 'DROP TABLE "MGMT_DM_TT_861" PURGE';
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
END mgmt$step_21_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_22_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 22 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF mgmt$mask_util.isWorkloadMasking OR mgmt$mask_util.isSTSMasking THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "TELEF2" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 2, 0);
    execute immediate ''create table MGMT_DM_TT_861
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(20 CHAR)) orig_val, CAST(null AS VARCHAR2(20 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(20 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "TELEF2" orig_val, astsysadmin\.func_dm_enmascara_telefono("TELEF2") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_861"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

');
      EXECUTE IMMEDIATE 'declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "TELEF2" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 2, 0);
    execute immediate ''create table MGMT_DM_TT_861
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(20 CHAR)) orig_val, CAST(null AS VARCHAR2(20 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(20 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "TELEF2" orig_val, astsysadmin\.func_dm_enmascara_telefono("TELEF2") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_861"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_22_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_23_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 23 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP INDEX MGMT_DM_TT_861_IDX');
      EXECUTE IMMEDIATE 'DROP INDEX MGMT_DM_TT_861_IDX';
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
END mgmt$step_23_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_24_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 24 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('CREATE  INDEX MGMT_DM_TT_861_IDX ON MGMT_DM_TT_861(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ');
      EXECUTE IMMEDIATE 'CREATE  INDEX MGMT_DM_TT_861_IDX ON MGMT_DM_TT_861(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_24_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_25_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 25 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP TABLE "MGMT_DM_TT_862" PURGE');
      EXECUTE IMMEDIATE 'DROP TABLE "MGMT_DM_TT_862" PURGE';
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
END mgmt$step_25_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_26_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 26 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF mgmt$mask_util.isWorkloadMasking OR mgmt$mask_util.isSTSMasking THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "TELEF1" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_862
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(20 CHAR)) orig_val, CAST(null AS VARCHAR2(20 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(20 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "TELEF1" orig_val, astsysadmin\.func_dm_enmascara_telefono("TELEF1") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_862"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

');
      EXECUTE IMMEDIATE 'declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "TELEF1" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_862
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(20 CHAR)) orig_val, CAST(null AS VARCHAR2(20 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(20 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "TELEF1" orig_val, astsysadmin\.func_dm_enmascara_telefono("TELEF1") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_862"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_26_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_27_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 27 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP INDEX MGMT_DM_TT_862_IDX');
      EXECUTE IMMEDIATE 'DROP INDEX MGMT_DM_TT_862_IDX';
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
END mgmt$step_27_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_28_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 28 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('CREATE  INDEX MGMT_DM_TT_862_IDX ON MGMT_DM_TT_862(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ');
      EXECUTE IMMEDIATE 'CREATE  INDEX MGMT_DM_TT_862_IDX ON MGMT_DM_TT_862(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_28_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_29_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 29 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP TABLE "MGMT_DM_TT_863" PURGE');
      EXECUTE IMMEDIATE 'DROP TABLE "MGMT_DM_TT_863" PURGE';
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
END mgmt$step_29_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_30_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 30 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;

    IF mgmt$mask_util.isWorkloadMasking OR mgmt$mask_util.isSTSMasking THEN
      return; 
    END IF;

    BEGIN
      mgmt$mask_sendMsg ('declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "NOMBRE" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_863
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(60 CHAR)) orig_val, CAST(null AS VARCHAR2(60 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(60 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "NOMBRE" orig_val, astsysadmin\.func_dm_enmascara_nombre("NOMBRE") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_863"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

');
      EXECUTE IMMEDIATE 'declare
    adj number:=0;
    num number:=0;
    numd number:=0;
begin
    select count(*) into adj from (select distinct "NOMBRE" from "DM_PCSS_OWN"."PCSS_SOL_TITULAR");
    numd:= adj;
    num := length(adj-1);
    adj := greatest(num - 3, 0);
    execute immediate ''create table MGMT_DM_TT_863
        (orig_val null, new_val null, delete_val null, row_id null ) NOLOGGING   PARALLEL ''|| mgmt$mask_util.get_tbps_clause ||'' as 
    select CAST(null AS VARCHAR2(60 CHAR)) orig_val, CAST(null AS VARCHAR2(60 CHAR)) new_val, CAST(0 AS NUMBER) delete_val, CAST(null AS ROWID) row_id  from dual union all 
     select s.orig_val,
    case 
        when s.subset = 1 then 
        CAST(
        s.new_val
         AS VARCHAR2(60 CHAR))
    end new_val,

    CAST(0 as NUMBER) delete_val
, CAST(s.rid AS ROWID) row_id 
    from (select orig_val, new_val, min(subset) subset, min(rid) rid             from (select "NOMBRE" orig_val, astsysadmin\.func_dm_enmascara_nombre("NOMBRE") new_val ,rowid  rid, 
        case 
            when 1=1 then 1
        end
  subset
        from "DM_PCSS_OWN"."PCSS_SOL_TITULAR" ) group by orig_val , subset, new_val ) s
 where  1=1 and ( s.orig_val is not null)
'';
    DBMS_STATS.GATHER_TABLE_STATS(NULL, ''"MGMT_DM_TT_863"'', estimate_percent=>DBMS_STATS.AUTO_SAMPLE_SIZE, degree=>DBMS_STATS.DEFAULT_DEGREE);
end; 

';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_30_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_31_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 31 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('DROP INDEX MGMT_DM_TT_863_IDX');
      EXECUTE IMMEDIATE 'DROP INDEX MGMT_DM_TT_863_IDX';
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
END mgmt$step_31_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_32_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 32 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('CREATE  INDEX MGMT_DM_TT_863_IDX ON MGMT_DM_TT_863(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ');
      EXECUTE IMMEDIATE 'CREATE  INDEX MGMT_DM_TT_863_IDX ON MGMT_DM_TT_863(orig_val) NOLOGGING  PARALLEL PCTFREE 0 ';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_32_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_33_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 33 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
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
END mgmt$step_33_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_34_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 34 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
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
END mgmt$step_34_855;
/

CREATE OR REPLACE PROCEDURE mgmt$step_35_855(script_id IN INTEGER, job_table IN VARCHAR2, step_num IN OUT INTEGER)
AUTHID CURRENT_USER IS
    sqlerr_msg VARCHAR2(400);
BEGIN
    IF step_num <> 35 THEN
      return;
    END IF;

    mgmt$mask_setStep (855, 'MGMT$MASK_CHECKPOINT', step_num);
    step_num := step_num + 1;
    BEGIN
      mgmt$mask_sendMsg ('BEGIN SYS.UTL_RECOMP.RECOMP_SERIAL(); END;');
      EXECUTE IMMEDIATE 'BEGIN SYS.UTL_RECOMP.RECOMP_SERIAL(); END;';
    EXCEPTION
      WHEN OTHERS THEN
        sqlerr_msg := SUBSTRB(SQLERRM, 1, 400);
        mgmt$mask_errorExitOraError('ERROR executing steps ',  sqlerr_msg);
        step_num := -1;
        return;
    END;
END mgmt$step_35_855;
/

CREATE OR REPLACE PROCEDURE mgmt$mask_cleanup_855 (script_id IN INTEGER, job_table IN VARCHAR2, step_num IN INTEGER, highest_step IN INTEGER)
AUTHID CURRENT_USER IS
BEGIN
    IF step_num <= highest_step THEN
      return;
    END IF;

    mgmt$mask_sendMsg ('Starting cleanup of recovery tables');

    mgmt$mask_deleteJobTableEntry(script_id, job_table, step_num, highest_step);
    mgmt$mask_sendMsg ('Completed cleanup of recovery tables');
END mgmt$mask_cleanup_855;
/

CREATE OR REPLACE PROCEDURE mgmt$mask_commentheader_855 IS
BEGIN
     mgmt$mask_sendMsg ('-- *** There are WARNINGS in the script. ***');
     mgmt$mask_sendMsg ('-- Review the Impact Report.');
     mgmt$mask_sendMsg ('-- ');
     mgmt$mask_sendMsg ('--   Target database:	presocsa.aragon.local_presocsa2');
     mgmt$mask_sendMsg ('--   Script generated at:	20-JAN-2026   11:38');
END mgmt$mask_commentheader_855;
/

-- Script Execution Controller
-- ==============================================

ALTER SESSION ENABLE PARALLEL DML;
ALTER SESSION SET QUERY_REWRITE_ENABLED = FALSE; 
ALTER SESSION FORCE PARALLEL DDL; 
ALTER SESSION FORCE PARALLEL QUERY; 
variable step_num number;
exec mgmt$mask_commentheader_855;
exec mgmt$mask_sendMsg ('Starting Data Masking');
show user;
exec mgmt$mask_checkDBAPrivs;
exec mgmt$mask_setupJobTable (855, 'MGMT$MASK_CHECKPOINT', :step_num);

exec mgmt$step_1_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_2_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_3_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_4_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_5_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_6_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_7_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_8_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_9_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_10_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_11_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_12_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_13_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_14_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_15_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_16_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_17_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_18_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_19_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_20_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_21_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_22_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_23_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_24_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_25_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_26_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_27_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_28_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_29_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_30_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_31_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_32_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_33_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_34_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);
exec mgmt$step_35_855(855, 'MGMT$MASK_CHECKPOINT', :step_num);

exec mgmt$mask_sendMsg ('Completed Data Masking. Starting cleanup phase.');

exec mgmt$mask_cleanup_855 (855, 'MGMT$MASK_CHECKPOINT', :step_num, 35);

exec mgmt$mask_sendMsg ('Starting cleanup of generated procedures');

DROP PROCEDURE mgmt$step_1_855;
DROP PROCEDURE mgmt$step_2_855;
DROP PROCEDURE mgmt$step_3_855;
DROP PROCEDURE mgmt$step_4_855;
DROP PROCEDURE mgmt$step_5_855;
DROP PROCEDURE mgmt$step_6_855;
DROP PROCEDURE mgmt$step_7_855;
DROP PROCEDURE mgmt$step_8_855;
DROP PROCEDURE mgmt$step_9_855;
DROP PROCEDURE mgmt$step_10_855;
DROP PROCEDURE mgmt$step_11_855;
DROP PROCEDURE mgmt$step_12_855;
DROP PROCEDURE mgmt$step_13_855;
DROP PROCEDURE mgmt$step_14_855;
DROP PROCEDURE mgmt$step_15_855;
DROP PROCEDURE mgmt$step_16_855;
DROP PROCEDURE mgmt$step_17_855;
DROP PROCEDURE mgmt$step_18_855;
DROP PROCEDURE mgmt$step_19_855;
DROP PROCEDURE mgmt$step_20_855;
DROP PROCEDURE mgmt$step_21_855;
DROP PROCEDURE mgmt$step_22_855;
DROP PROCEDURE mgmt$step_23_855;
DROP PROCEDURE mgmt$step_24_855;
DROP PROCEDURE mgmt$step_25_855;
DROP PROCEDURE mgmt$step_26_855;
DROP PROCEDURE mgmt$step_27_855;
DROP PROCEDURE mgmt$step_28_855;
DROP PROCEDURE mgmt$step_29_855;
DROP PROCEDURE mgmt$step_30_855;
DROP PROCEDURE mgmt$step_31_855;
DROP PROCEDURE mgmt$step_32_855;
DROP PROCEDURE mgmt$step_33_855;
DROP PROCEDURE mgmt$step_34_855;
DROP PROCEDURE mgmt$step_35_855;

DROP PROCEDURE mgmt$mask_cleanup_855;
DROP PROCEDURE mgmt$mask_commentheader_855;

exec mgmt$mask_sendMsg ('Completed cleanup of generated procedures');

whenever sqlerror exit;
begin
if :step_num <> 36 then
dbms_standard.raise_application_error(-20001, 'ERROR executing steps ');
end if;
end;
/
whenever sqlerror continue;

exec mgmt$mask_sendMsg ('Script execution complete');

CREATE TABLE DB_DSG_MAP_TABLE (
SCHEMA_NAME VARCHAR(128),
TABLE_NAME VARCHAR2(128), 
COLUMN_NAME VARCHAR2(128), 
MASK_MAP_TABLE_ID NUMBER,
COLUMN_TYPE VARCHAR2(50), 
COLUMN_LENGTH  NUMBER, 
COLUMN_PRECISION NUMBER, 
COLUMN_SCALE NUMBER, 
COLUMN_CHAR_LENGTH NUMBER, 
COLUMN_CHAR_USED VARCHAR2(1), 
RULE_TYPE NUMBER, 
FORMAT_TYPE INTEGER, 
FORMAT_TEXT CLOB, 
IS_DM VARCHAR2(1), 
TRUNCATE_TABLE VARCHAR2(1),
DROP_MAPPING_TABLE VARCHAR2(1),
PASS_RID_IN_REMAP VARCHAR2(1));

INSERT INTO DB_DSG_MAP_TABLE VALUES ('DM_PCSS_OWN', 'PCSS_SOL_TITULAR', 'NOMBRE', 863, 'VARCHAR2', null, null, null, null, null, 1, null, null, 'N', 'N', 'N', 'Y');
INSERT INTO DB_DSG_MAP_TABLE VALUES ('DM_PCSS_OWN', 'PCSS_SOL_TITULAR', 'APE2', 856, 'VARCHAR2', null, null, null, null, null, 1, null, null, 'N', 'N', 'N', 'Y');
INSERT INTO DB_DSG_MAP_TABLE VALUES ('DM_PCSS_OWN', 'PCSS_SOL_TITULAR', 'TELEF2', 861, 'VARCHAR2', null, null, null, null, null, 1, null, null, 'N', 'N', 'N', 'Y');
INSERT INTO DB_DSG_MAP_TABLE VALUES ('DM_PCSS_OWN', 'PCSS_SOL_TITULAR', 'TELEF1', 862, 'VARCHAR2', null, null, null, null, null, 1, null, null, 'N', 'N', 'N', 'Y');
INSERT INTO DB_DSG_MAP_TABLE VALUES ('DM_PCSS_OWN', 'PCSS_SOL_TITULAR', 'CUENTA', 859, 'VARCHAR2', null, null, null, null, null, 1, null, null, 'N', 'N', 'N', 'Y');
INSERT INTO DB_DSG_MAP_TABLE VALUES ('DM_PCSS_OWN', 'PCSS_SOL_TITULAR', 'DOMICILIO', 858, 'VARCHAR2', null, null, null, null, null, 1, null, null, 'N', 'N', 'N', 'Y');
INSERT INTO DB_DSG_MAP_TABLE VALUES ('DM_PCSS_OWN', 'PCSS_SOL_TITULAR', 'NIFNIE', 860, 'VARCHAR2', null, null, null, null, null, 1, null, null, 'N', 'N', 'N', 'Y');
INSERT INTO DB_DSG_MAP_TABLE VALUES ('DM_PCSS_OWN', 'PCSS_SOL_TITULAR', 'APE1', 857, 'VARCHAR2', null, null, null, null, null, 1, null, null, 'N', 'N', 'N', 'Y');

CREATE OR REPLACE PACKAGE DBMS_DSM_DSG_IM
AS
FUNCTION DSG_REMAP_863(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL ) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
FUNCTION DSG_REMAP_856(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL ) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
FUNCTION DSG_REMAP_861(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL ) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
FUNCTION DSG_REMAP_862(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL ) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
FUNCTION DSG_REMAP_859(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL ) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
FUNCTION DSG_REMAP_858(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL ) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
FUNCTION DSG_REMAP_860(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL ) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
FUNCTION DSG_REMAP_857(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL ) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
END DBMS_DSM_DSG_IM;
/


CREATE OR REPLACE PACKAGE BODY DBMS_DSM_DSG_IM
AS
FUNCTION DSG_REMAP_863(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE
IS
new_val VARCHAR2(60 CHAR);
BEGIN
BEGIN 
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM MGMT_DM_TT_863 WHERE orig_val = :old_val and row_id = :rowid_val' INTO new_val USING old_val, rowid_val;
EXCEPTION WHEN no_data_found THEN
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM (SELECT NEW_VAL FROM MGMT_DM_TT_863 WHERE orig_val = :old_val) WHERE rownum = 1' INTO new_val USING old_val;
END; 
RETURN new_val;
END DSG_REMAP_863;
FUNCTION DSG_REMAP_856(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE
IS
new_val VARCHAR2(40 CHAR);
BEGIN
BEGIN 
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM MGMT_DM_TT_856 WHERE orig_val = :old_val and row_id = :rowid_val' INTO new_val USING old_val, rowid_val;
EXCEPTION WHEN no_data_found THEN
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM (SELECT NEW_VAL FROM MGMT_DM_TT_856 WHERE orig_val = :old_val) WHERE rownum = 1' INTO new_val USING old_val;
END; 
RETURN new_val;
END DSG_REMAP_856;
FUNCTION DSG_REMAP_861(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE
IS
new_val VARCHAR2(20 CHAR);
BEGIN
BEGIN 
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM MGMT_DM_TT_861 WHERE orig_val = :old_val and row_id = :rowid_val' INTO new_val USING old_val, rowid_val;
EXCEPTION WHEN no_data_found THEN
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM (SELECT NEW_VAL FROM MGMT_DM_TT_861 WHERE orig_val = :old_val) WHERE rownum = 1' INTO new_val USING old_val;
END; 
RETURN new_val;
END DSG_REMAP_861;
FUNCTION DSG_REMAP_862(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE
IS
new_val VARCHAR2(20 CHAR);
BEGIN
BEGIN 
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM MGMT_DM_TT_862 WHERE orig_val = :old_val and row_id = :rowid_val' INTO new_val USING old_val, rowid_val;
EXCEPTION WHEN no_data_found THEN
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM (SELECT NEW_VAL FROM MGMT_DM_TT_862 WHERE orig_val = :old_val) WHERE rownum = 1' INTO new_val USING old_val;
END; 
RETURN new_val;
END DSG_REMAP_862;
FUNCTION DSG_REMAP_859(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE
IS
new_val VARCHAR2(10 CHAR);
BEGIN
BEGIN 
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM MGMT_DM_TT_859 WHERE orig_val = :old_val and row_id = :rowid_val' INTO new_val USING old_val, rowid_val;
EXCEPTION WHEN no_data_found THEN
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM (SELECT NEW_VAL FROM MGMT_DM_TT_859 WHERE orig_val = :old_val) WHERE rownum = 1' INTO new_val USING old_val;
END; 
RETURN new_val;
END DSG_REMAP_859;
FUNCTION DSG_REMAP_858(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE
IS
new_val VARCHAR2(150 CHAR);
BEGIN
BEGIN 
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM MGMT_DM_TT_858 WHERE orig_val = :old_val and row_id = :rowid_val' INTO new_val USING old_val, rowid_val;
EXCEPTION WHEN no_data_found THEN
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM (SELECT NEW_VAL FROM MGMT_DM_TT_858 WHERE orig_val = :old_val) WHERE rownum = 1' INTO new_val USING old_val;
END; 
RETURN new_val;
END DSG_REMAP_858;
FUNCTION DSG_REMAP_860(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE
IS
new_val VARCHAR2(20 CHAR);
BEGIN
BEGIN 
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM MGMT_DM_TT_860 WHERE orig_val = :old_val and row_id = :rowid_val' INTO new_val USING old_val, rowid_val;
EXCEPTION WHEN no_data_found THEN
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM (SELECT NEW_VAL FROM MGMT_DM_TT_860 WHERE orig_val = :old_val) WHERE rownum = 1' INTO new_val USING old_val;
END; 
RETURN new_val;
END DSG_REMAP_860;
FUNCTION DSG_REMAP_857(old_val IN VARCHAR2, rowid_val IN ROWID DEFAULT NULL) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE
IS
new_val VARCHAR2(40 CHAR);
BEGIN
BEGIN 
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM MGMT_DM_TT_857 WHERE orig_val = :old_val and row_id = :rowid_val' INTO new_val USING old_val, rowid_val;
EXCEPTION WHEN no_data_found THEN
  EXECUTE IMMEDIATE 'SELECT NEW_VAL FROM (SELECT NEW_VAL FROM MGMT_DM_TT_857 WHERE orig_val = :old_val) WHERE rownum = 1' INTO new_val USING old_val;
END; 
RETURN new_val;
END DSG_REMAP_857;
END DBMS_DSM_DSG_IM;
/

