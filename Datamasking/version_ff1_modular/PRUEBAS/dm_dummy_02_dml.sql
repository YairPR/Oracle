Rem =============================================================================
Rem dm_dummy_02_dml.sql -- CARGA DE DATOS DE DM_DUMMY, PARAMETRIZADA POR VOLUMEN
Rem
Rem Sustituye a poc_esquema_dummy_volumen_dml.sql y a las cargas de correctitud y
Rem cierre y casos especiales. Una sola ejecucion carga las 35 tablas.
Rem
Rem USO (conectado como DBA, el mismo que ejecuto dm_dummy_01_ddl.sql):
Rem     @dm_dummy_02_dml <millones>
Rem   <millones> = millones de filas de las 12 tablas de VOLUMEN, de 0.5 a 60.
Rem   Sin argumento carga 2. Ejemplos:
Rem     @dm_dummy_02_dml 0.5      ~0,5 M filas de volumen: minutos
Rem     @dm_dummy_02_dml 10       ~10 M
Rem     @dm_dummy_02_dml 60       ~60 M: horas, lanzalo en segundo plano
Rem   Las tablas de CORRECTITUD (10 x 110 filas) y de CIERRE (150.000 filas en
Rem   TBL_SUCURSAL_RIESGO y en TBL_LOTE_RESUME, 1.000 en TBL_GESTOR_CARTERA, 50 y
Rem   50 en las otras dos) NO escalan: las pruebas dependen de esos tamanos.
Rem
Rem QUE HACE
Rem   1) Valida el parametro, comprueba que el DDL esta cargado (35 tablas) y
Rem      avisa si el espacio del tablespace parece corto.
Rem   2) LIMPIA: deshabilita las FK, trunca las 35 tablas y marca UNUSABLE los
Rem      indices no unicos. Se puede repetir con otro volumen sin recrear el
Rem      esquema.
Rem   3) Carga correctitud, volumen, cierre y casos especiales (8 tablas de tamano
Rem      fijo: documentos especiales, sincronizacion, unicidad, PK de 150.000 filas,
Rem      formatos, IOT de 120.000 filas y tabla vacia). Los identificadores son el indice
Rem      del bucle (rango contiguo 1..N) y toda tabla hija recalcula el valor
Rem      del padre por formula: la integridad referencial y la propagacion
Rem      del enmascarado se cumplen por construccion.
Rem   4) Reconstruye los indices, valida las FK (ENABLE VALIDATE) y calcula
Rem      estadisticas. Sin estadisticas el motor no elige bien entre UPDATE
Rem      directo y troceado (decide por NUM_ROWS de DBA_TABLES).
Rem
Rem PROGRESO durante la carga larga (otra sesion):
Rem   select target_desc, sofar, totalwork, round(sofar/totalwork*100,1) pct
Rem     from v$session_longops where opname = 'DM_DUMMY carga' order by start_time desc;
Rem
Rem 5) Carga en el esquema del motor lo que la prueba necesita fuera de DM_DUMMY:
Rem    8 excepciones en TDM_EXCEPCION_COL (7 FORCE y 1 EXCLUDE), 3 reglas especiales
Rem    en TDM_MASK_REGLA_ESP y 1 relacion en TDM_MASK_RELACION_SYNC (siempre con
Rem    ora_esquema DM_DUMMY; se borran y reinsertan, se puede repetir). Es lo unico que
Rem    escribe fuera de DM_DUMMY; si el motor no esta instalado lo avisa y sigue.
Rem
Rem Solo para entornos de PRUEBA. No usa secuencias.
Rem =============================================================================
undefine V_ARG1

set serveroutput on size unlimited
set verify off
set feedback off
set define on
set linesize 200
set pagesize 100
set trimspool on
set tab off
whenever sqlerror exit failure rollback

set termout off
column "1" new_value 1 noprint
select null as "1" from dual where 1=2;
column final_p1 new_value V_ARG1 noprint
select nvl(trim('&1'),'2') final_p1 from dual;
set termout on

variable g_m number

prompt =========================================================================
prompt 1) VALIDACION Y LIMPIEZA
prompt =========================================================================
declare
  l_txt    varchar2(100) := trim('&V_ARG1');
  l_m      number;
  l_n      number;
  l_libre  number;
  l_usado  number;
  l_nec    number;
begin
  begin
    l_m := to_number(replace(l_txt, ',', '.'), '99990D999999', 'NLS_NUMERIC_CHARACTERS=''.,''');
  exception
    when others then
      raise_application_error(-20401, 'Parametro no numerico: "' || l_txt || '". Uso: @dm_dummy_02_dml <millones, de 0.5 a 60>. '||
        'Sin parametro se usa 2, salvo que la sesion SQL*Plus conserve un &1 de un script anterior: pasa el valor explicito.');
  end;
  if l_m < 0.5 or l_m > 60 then
    raise_application_error(-20402, 'Volumen fuera de rango: ' || l_m || '. Permitido de 0.5 a 60 (millones de filas de volumen).');
  end if;
  :g_m := l_m;

  select count(*) into l_n from dba_tables where owner = 'DM_DUMMY';
  if l_n <> 35 then
    raise_application_error(-20403, 'DM_DUMMY tiene ' || l_n || ' tablas y se esperan 35. Ejecuta antes @dm_dummy_01_ddl.');
  end if;

  dbms_output.put_line('Volumen pedido: ' || rtrim(to_char(l_m, 'FM9999990D99999','NLS_NUMERIC_CHARACTERS=''.,'''),'.') || ' millones de filas en las 12 tablas de volumen');

  -- Aviso de espacio (orientativo: ~130 MB por millon de filas entre tablas e indices).
  begin
    select nvl(sum(bytes),0) into l_libre from dba_free_space where tablespace_name = 'DM_DUMMY';
    select nvl(sum(bytes),0) into l_usado from dba_segments where owner = 'DM_DUMMY';
    select l_libre + l_usado + nvl(sum(greatest(maxbytes - bytes, 0)),0) into l_libre
      from dba_data_files where tablespace_name = 'DM_DUMMY' and autoextensible = 'YES';
    l_nec := l_m * 130 * 1024 * 1024;
    dbms_output.put_line('Espacio orientativo: necesario ' || rtrim(to_char(round(l_nec/1024/1024/1024,1), 'FM9999990D9', 'NLS_NUMERIC_CHARACTERS=''.,'''),'.') ||
                         ' GB, disponible (libre + autoextend + lo que se libera al truncar) ' || round(l_libre/1024/1024/1024,1) || ' GB');
    if l_libre < l_nec then
      dbms_output.put_line('AVISO: el tablespace DM_DUMMY parece corto para este volumen. Amplialo antes de seguir (ORA-01653 a mitad de carga).');
    end if;
  exception
    when others then
      dbms_output.put_line('Aviso: no se pudo estimar el espacio (' || sqlerrm || ').');
  end;

  -- Limpieza: FK fuera, tablas vacias, indices no unicos sin mantener.
  for c in (select table_name, constraint_name from dba_constraints
             where owner = 'DM_DUMMY' and constraint_type = 'R' and status = 'ENABLED') loop
    execute immediate 'alter table DM_DUMMY."' || c.table_name || '" disable constraint "' || c.constraint_name || '"';
  end loop;
  for t in (select table_name from dba_tables where owner = 'DM_DUMMY') loop
    execute immediate 'truncate table DM_DUMMY."' || t.table_name || '"';
  end loop;
  for i in (select index_name from dba_indexes
             where owner = 'DM_DUMMY' and index_type = 'NORMAL' and uniqueness = 'NONUNIQUE') loop
    execute immediate 'alter index DM_DUMMY."' || i.index_name || '" unusable';
  end loop;
  dbms_output.put_line('Limpieza hecha: FK deshabilitadas, 35 tablas vacias, indices de FK sin mantener.');
end;
/

prompt =========================================================================
prompt 2) CARGA (correctitud, volumen, cierre y casos especiales)
prompt =========================================================================
prompt El detalle de filas sale al terminar la carga. Progreso en vivo, desde otra sesion:
prompt   select message from v$session_longops where opname like 'DM_DUMMY%' and sofar < totalwork;
declare
  c_lote    CONSTANT PLS_INTEGER := 50000;
  l_escala  NUMBER := :g_m / 60;

  -- Objetivos base a 60 M: la suma de las 12 tablas de volumen es 60.000.000
  l_n_persona   PLS_INTEGER := GREATEST(100, ROUND( 5000000 * l_escala));
  l_n_cuenta    PLS_INTEGER := GREATEST(200, ROUND(18000000 * l_escala));
  l_n_movim     PLS_INTEGER := GREATEST(300, ROUND(26900000 * l_escala));
  l_n_empresa   PLS_INTEGER := GREATEST(50,  ROUND(  150000 * l_escala));
  l_n_factura   PLS_INTEGER := GREATEST(100, ROUND( 3000000 * l_escala));
  l_n_empleado  PLS_INTEGER := GREATEST(100, ROUND(  300000 * l_escala));
  l_n_nomina    PLS_INTEGER := GREATEST(200, ROUND( 4000000 * l_escala));
  l_n_documento PLS_INTEGER := GREATEST(100, ROUND(  800000 * l_escala));
  l_n_audit     PLS_INTEGER := GREATEST(100, ROUND( 1500000 * l_escala));
  l_n_refpub    PLS_INTEGER := GREATEST(50,  ROUND(   50000 * l_escala));
  l_n_refinv    PLS_INTEGER := GREATEST(50,  ROUND(  100000 * l_escala));
  l_n_config    PLS_INTEGER := GREATEST(50,  ROUND(  200000 * l_escala));

  l_t0      TIMESTAMP;
  l_rindex  PLS_INTEGER;
  l_slno    PLS_INTEGER;

  c_letras CONSTANT VARCHAR2(23) := 'TRWAGMYFPDXBNJZSQVHLCKE';
  c_noms   CONSTANT VARCHAR2(200) := 'JUAN,MARIA,CARLOS,ANA,PEDRO,LAURA,JAVIER,ELENA,MIGUEL,CARMEN';
  c_ape1   CONSTANT VARCHAR2(200) := 'GOMEZ,LOPEZ,PULIDO,SANCHEZ,SANZ,ROMERO,NAVARRO,TORRES,DOMINGUEZ,VAZQUEZ,RAMOS';
  c_ape2   CONSTANT VARCHAR2(200) := 'FERNANDEZ,DIAZ,MARTIN,PEREZ,GIL,SERRANO,BLANCO,MORENO,SUAREZ';
  c_ents   CONSTANT VARCHAR2(400) := 'AYUNTAMIENTO DE UTEBO|FUNDACION SAN VALERO|CONSTRUCCIONES ARAGON S.L.|ASOCIACION VECINAL DELICIAS|MINISTERIO DE HACIENDA|UNIVERSIDAD DE ZARAGOZA|COOPERATIVA AGRICOLA DEL EBRO|PROMOCIONES PILAR S.A.';

  -----------------------------------------------------------------------
  -- Seguimiento: v$session_longops y salida por pantalla (nunca debe romper la carga)
  -----------------------------------------------------------------------
  PROCEDURE p_prog_ini IS
  BEGIN
    l_rindex := DBMS_APPLICATION_INFO.set_session_longops_nohint;
  END;

  PROCEDURE p_prog(p_tabla IN VARCHAR2, p_hecho IN NUMBER, p_total IN NUMBER) IS
  BEGIN
    DBMS_APPLICATION_INFO.SET_SESSION_LONGOPS(rindex => l_rindex, slno => l_slno, op_name => 'DM_DUMMY carga',
      target_desc => p_tabla, sofar => p_hecho, totalwork => p_total, units => 'filas');
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

  -----------------------------------------------------------------------
  -- Generadores deterministas: el mismo numero da siempre el mismo valor, asi
  -- una tabla hija recalcula el NIF o el nombre del padre sin consultarlo.
  -----------------------------------------------------------------------
  FUNCTION f_gen_nif(p_num IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN TO_CHAR(p_num) || SUBSTR(c_letras, MOD(p_num,23)+1, 1);
  END;

  FUNCTION f_gen_nie(p_num IN NUMBER, p_pref IN NUMBER) RETURN VARCHAR2 IS
    l_n7 VARCHAR2(7) := LPAD(TO_CHAR(p_num), 7, '0');
  BEGIN
    -- prefijo X/Y/Z = 0/1/2; letra: mod 23 del numero (prefijo en cifras + 7 digitos)
    RETURN SUBSTR('XYZ', p_pref+1, 1) || l_n7 || SUBSTR(c_letras, MOD(TO_NUMBER(TO_CHAR(p_pref) || l_n7), 23)+1, 1);
  END;

  FUNCTION f_gen_nombre(p_num IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE MOD(p_num,5) WHEN 0 THEN 'JUAN' WHEN 1 THEN 'MARIA'
             WHEN 2 THEN 'CARLOS' WHEN 3 THEN 'ANA' ELSE 'PEDRO' END || '_' || p_num;
  END;

  FUNCTION f_gen_apellidos(p_num IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE MOD(p_num,5) WHEN 0 THEN 'GOMEZ' WHEN 1 THEN 'LOPEZ'
             WHEN 2 THEN 'PULIDO' WHEN 3 THEN 'SANCHEZ' ELSE 'SANZ' END || ' ' ||
           CASE MOD(p_num,4) WHEN 0 THEN 'FERNANDEZ' WHEN 1 THEN 'DIAZ'
             WHEN 2 THEN 'MARTIN' ELSE 'PEREZ' END;
  END;

  FUNCTION f_gen_iban(p_banco IN VARCHAR2, p_num IN NUMBER) RETURN VARCHAR2 IS
    l_bban VARCHAR2(20);
    l_txt  VARCHAR2(40);
    l_rem  NUMBER := 0;
    l_part VARCHAR2(20);
    l_cc   VARCHAR2(2);
  BEGIN
    l_bban := p_banco || LPAD(TO_CHAR(p_num), 12, '0');
    l_txt  := l_bban || '142800';
    FOR j IN 1 .. CEIL(LENGTH(l_txt)/7) LOOP
      l_part := TO_CHAR(l_rem) || SUBSTR(l_txt,(j-1)*7+1,7);
      l_rem  := MOD(TO_NUMBER(l_part),97);
    END LOOP;
    l_cc := LPAD(TO_CHAR(98-l_rem),2,'0');
    RETURN 'ES' || l_cc || l_bban;
  END;

  FUNCTION f_gen_cif(p_num IN NUMBER) RETURN VARCHAR2 IS
    l_char CHAR(1) := CASE MOD(p_num,4) WHEN 0 THEN 'A' WHEN 1 THEN 'B' WHEN 2 THEN 'E' ELSE 'H' END;
    l_num  VARCHAR2(7) := LPAD(TO_CHAR(1000000 + p_num), 7, '0');
    s_par NUMBER := 0; s_imp NUMBER := 0; d NUMBER; x NUMBER; c NUMBER;
  BEGIN
    FOR k IN 1 .. 7 LOOP
      d := TO_NUMBER(SUBSTR(l_num,k,1));
      IF MOD(k,2)=0 THEN
        s_par := s_par + d;
      ELSE
        x := d*2;
        s_imp := s_imp + TRUNC(x/10) + MOD(x,10);
      END IF;
    END LOOP;
    c := MOD(10 - MOD(s_par+s_imp,10), 10);
    RETURN l_char || l_num || TO_CHAR(c);
  END;

  -----------------------------------------------------------------------
  -- A) CORRECTITUD: 10 tablas x 110 filas. Fila i de cada tabla cuelga de la
  --    persona i. Valores con digito de control real (NIF, NIE, CIF, IBAN).
  -----------------------------------------------------------------------
  PROCEDURE p_carga_correctitud IS
    l_dni  VARCHAR2(20);  l_nom VARCHAR2(100); l_ap1 VARCHAR2(50); l_ap2 VARCHAR2(50);
    l_ape  VARCHAR2(150); l_dir VARCHAR2(200);  l_tel VARCHAR2(20); l_mail VARCHAR2(150);
    l_iban VARCHAR2(30);  l_ccc VARCHAR2(30);   l_niecif VARCHAR2(20); l_mixto VARCHAR2(20);
    l_usr  VARCHAR2(50);
    l_refcli VARCHAR2(20); l_ibannom VARCHAR2(30); l_nifben VARCHAR2(20); l_nifpub VARCHAR2(20);
  BEGIN
    FOR i IN 1 .. 110 LOOP
      l_dni  := f_gen_nif(30000000 + i);
      l_nom  := REGEXP_SUBSTR(c_noms, '[^,]+', 1, MOD(i,10)+1);
      l_ap1  := REGEXP_SUBSTR(c_ape1, '[^,]+', 1, MOD(i,11)+1);
      l_ap2  := REGEXP_SUBSTR(c_ape2, '[^,]+', 1, MOD(i,9)+1);
      l_ape  := l_ap1 || ' ' || l_ap2;
      l_dir  := CASE MOD(i,4) WHEN 0 THEN 'CALLE' WHEN 1 THEN 'AVDA' WHEN 2 THEN 'PLAZA' ELSE 'PASEO' END
                || ' MAYOR ' || i || ', ' || (MOD(i,5)+1) || ' PISO, 500' || LPAD(TO_CHAR(MOD(i,99)),2,'0') || ' ZARAGOZA';
      l_tel  := '6' || LPAD(TO_CHAR(MOD(i*131071, 100000000)), 8, '0');
      l_mail := LOWER(l_nom || '.' || l_ap1 || i) || '@correo.com';
      l_iban := f_gen_iban('21000418', i);
      l_ccc  := '2100041800' || LPAD(TO_CHAR(i), 10, '0');
      -- nie_cif: dos tercios NIE (X, Y, Z), un tercio CIF
      l_niecif := CASE WHEN MOD(i,3) = 0 THEN f_gen_cif(500 + i)
                       ELSE f_gen_nie(1000000 + i*37, MOD(TRUNC(i/3),3)) END;
      -- doc_mixto: DNI, NIE y CIF alternados fila a fila
      l_mixto := CASE MOD(i,3) WHEN 0 THEN f_gen_nif(40000000 + i)
                               WHEN 1 THEN f_gen_nie(2000000 + i*41, MOD(TRUNC(i/3),3))
                               ELSE f_gen_cif(900 + i) END;
      l_usr  := LOWER(SUBSTR(l_nom,1,1) || l_ap1);
      -- una funcion local no puede ir dentro de una sentencia SQL (PLS-00231 en 11g): se calcula antes
      l_refcli := f_gen_nif(50000000 + i);
      l_ibannom := f_gen_iban('01820001', 800000000 + i);
      l_nifben := f_gen_nif(70000000 + i);
      l_nifpub := f_gen_nif(60000000 + i);

      INSERT INTO DM_DUMMY.tbl_personas (dni, nombre, apellidos, direccion, fecha_nacimiento, telefono, email,
        iban, cuenta_ccc, nie_cif, doc_mixto, cod_dni_falso, correo_interno, telefono_ficticio,
        referencia_cliente, usuario_ad)
      VALUES (l_dni, l_nom, l_ape, l_dir, DATE '1960-01-01' + MOD(i*397, 15000), l_tel, l_mail,
        l_iban, l_ccc, l_niecif, l_mixto, TO_CHAR(90000000 + i), 'srv' || LPAD(TO_CHAR(i),4,'0') || '.interno',
        'EXT-' || LPAD(TO_CHAR(i),4,'0'), l_refcli, l_usr);

      INSERT INTO DM_DUMMY.tbl_clientes (cliente_id, dni_ref, tipo_cliente, fecha_alta, score_riesgo)
      VALUES (i, l_dni, CASE MOD(i,3) WHEN 0 THEN 'VIP' WHEN 1 THEN 'PREMIUM' ELSE 'ESTANDAR' END,
              SYSDATE - MOD(i,3000), ROUND(MOD(i*37,10000)/100, 2));

      INSERT INTO DM_DUMMY.tbl_empleados (empleado_id, dni_emp, cargo, salario, usuario_ad)
      VALUES (i, l_dni, 'CARGO_' || LPAD(TO_CHAR(MOD(i,12)),2,'0'), 1200 + MOD(i*17,4000), l_usr);

      INSERT INTO DM_DUMMY.tbl_direcciones (direccion_id, dni_titular, calle_completa, codigo_postal, tipo_vivienda)
      VALUES (i, l_dni, 'CALLE DEL CARMEN ' || i || ', ZARAGOZA', '500' || LPAD(TO_CHAR(MOD(i,99)),2,'0'),
              CASE MOD(i,3) WHEN 0 THEN 'PISO' WHEN 1 THEN 'CASA' ELSE 'ATICO' END);

      INSERT INTO DM_DUMMY.tbl_nomina (nomina_id, empleado_id, concepto, importe, iban_abono, fecha_pago)
      VALUES (i, i, 'NOMINA ' || TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE,'MM'), -MOD(i,12)), 'YYYY-MM'),
              1500 + MOD(i*13,2500), l_ibannom, TRUNC(SYSDATE) - MOD(i,300));

      INSERT INTO DM_DUMMY.tbl_beneficiarios (beneficiario_id, empleado_id, dni_beneficiario, email_beneficiario, parentesco)
      VALUES (i, i, l_nifben, 'benef' || i || '@familia.com',
              CASE MOD(i,3) WHEN 0 THEN 'CONYUGE' WHEN 1 THEN 'HIJO' ELSE 'PADRE' END);

      INSERT INTO DM_DUMMY.tbl_audit_log (log_id, dni_usuario, accion, ip_origen, usuario_sistema)
      VALUES (i, l_dni, 'ACCESO_EXPEDIENTE_' || i, '10.1.' || MOD(i,255) || '.' || MOD(i*7,255), 'SVC_BATCH_' || MOD(i,5));

      INSERT INTO DM_DUMMY.tbl_historial_contacto (hist_id, dni_referencia, email_contacto, telefono_contacto, canal_contacto, notes)
      VALUES (i, l_dni, l_mail, l_tel, CASE MOD(i,3) WHEN 0 THEN 'EMAIL' WHEN 1 THEN 'TELEFONO' ELSE 'CHAT' END,
              CASE WHEN MOD(i,2) = 0
                   THEN 'Contacto con ' || l_nom || ' ' || l_ape || ' (' || l_dni || '), telefono ' || l_tel
                   ELSE 'Sin novedad en la gestion ' || i END);

      INSERT INTO DM_DUMMY.tbl_documentacion (doc_id, dni_owner, nombre_archivo, observaciones, datos_crudos, num_paginas)
      VALUES (i, l_dni, 'expediente_' || i || '.pdf',
              'Titular ' || l_nom || ' ' || l_ape || ', DNI ' || l_dni || ', contacto ' || l_mail,
              '{"dni":"' || l_dni || '","email":"' || l_mail || '","iban":"' || l_iban || '"}',
              1 + MOD(i,30));

      INSERT INTO DM_DUMMY.tbl_referencias_publicas (ref_id, dni_publico, descripcion)
      VALUES (i, l_nifpub, 'Dataset publico de prueba ' || i);
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('  correctitud: 10 tablas x 110 filas');
  END p_carga_correctitud;

  -----------------------------------------------------------------------
  -- B) VOLUMEN
  -----------------------------------------------------------------------
  -- B1) tbl_persona_vol -- raiz de identidad. ID = indice del bucle.
  PROCEDURE p_carga_persona IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_str IS TABLE OF VARCHAR2(500) INDEX BY PLS_INTEGER;
    TYPE t_dat IS TABLE OF DATE INDEX BY PLS_INTEGER;
    a_id t_num; a_nif t_str; a_nombre t_str; a_apellidos t_str; a_dir t_str;
    a_tel t_str; a_email t_str; a_obs t_str; a_fnac t_dat; a_falta t_dat;
    a_prof t_str; a_estciv t_str; a_pais t_str; a_tipo t_str; a_canal t_str;
    a_score t_num; a_activo t_str; a_niffalso t_str;
    j PLS_INTEGER := 0;
    l_lotes PLS_INTEGER := 0;
  BEGIN
    p_prog_ini;
    FOR i IN 1 .. l_n_persona LOOP
      j := j + 1;
      a_id(j)        := i;
      a_nif(j)       := f_gen_nif(10000000 + i);
      a_nombre(j)    := f_gen_nombre(i);
      a_apellidos(j) := f_gen_apellidos(i);
      a_dir(j)       := CASE MOD(i,4) WHEN 0 THEN 'CALLE' WHEN 1 THEN 'AVDA' WHEN 2 THEN 'PLAZA' ELSE 'PASEO' END
                         || ' MAYOR ' || i || ', ' || (MOD(i,5)+1) || ' PISO, 500' || LPAD(TO_CHAR(MOD(i,99)),2,'0') || ' ZARAGOZA';
      a_tel(j)       := '6' || LPAD(TO_CHAR(MOD(i,99999999)), 8, '0');
      a_email(j)     := LOWER(SUBSTR(a_nombre(j),1,3) || '.' || REPLACE(a_apellidos(j),' ','.')) || '@correo.com';
      -- datos personales incrustados solo en 1 de cada 20 filas
      a_obs(j)       := CASE WHEN MOD(i,20) = 0
                           THEN 'Contacto verificado para ' || a_nombre(j) || ' ' || a_apellidos(j) || ', NIF ' || a_nif(j)
                           ELSE 'Sin incidencias registradas (ref ' || i || ')'
                         END;
      a_fnac(j)      := DATE '1970-01-01' + MOD(i*137, 18000);
      a_falta(j)     := SYSDATE - MOD(i,3650);
      a_prof(j)      := CASE MOD(i,6) WHEN 0 THEN 'INGENIERO' WHEN 1 THEN 'ADMINISTRATIVO' WHEN 2 THEN 'COMERCIAL'
                            WHEN 3 THEN 'DOCENTE' WHEN 4 THEN 'SANITARIO' ELSE 'AUTONOMO' END;
      a_estciv(j)    := CASE MOD(i,3) WHEN 0 THEN 'SOLTERO' WHEN 1 THEN 'CASADO' ELSE 'DIVORCIADO' END;
      a_pais(j)      := 'ESPANA';
      a_tipo(j)      := CASE MOD(i,3) WHEN 0 THEN 'VIP' WHEN 1 THEN 'PREMIUM' ELSE 'ESTANDAR' END;
      a_canal(j)     := CASE MOD(i,4) WHEN 0 THEN 'ONLINE' WHEN 1 THEN 'OFICINA' WHEN 2 THEN 'TELEFONO' ELSE 'REFERIDO' END;
      a_score(j)     := ROUND(MOD(i,10000)/100, 2);
      a_activo(j)    := CASE WHEN MOD(i,37) = 0 THEN 'N' ELSE 'Y' END;
      a_niffalso(j)  := TO_CHAR(90000000 + i); -- senuelo: correlativo, sin digito de control

      IF j = c_lote OR i = l_n_persona THEN
        FORALL k IN 1 .. j
          INSERT INTO DM_DUMMY.tbl_persona_vol (persona_id, nif, nombre, apellidos, direccion, telefono, email,
            observaciones, fecha_nacimiento, fecha_alta, profesion, estado_civil, pais_residencia,
            tipo_persona, canal_captacion, score_riesgo, activo, nif_falso_decoy)
          VALUES (a_id(k), a_nif(k), a_nombre(k), a_apellidos(k), a_dir(k), a_tel(k), a_email(k),
            a_obs(k), a_fnac(k), a_falta(k), a_prof(k), a_estciv(k), a_pais(k),
            a_tipo(k), a_canal(k), a_score(k), a_activo(k), a_niffalso(k));
        COMMIT;
        l_lotes := l_lotes + 1;
        p_prog('tbl_persona_vol', i, l_n_persona);
        IF MOD(l_lotes,10) = 0 OR i = l_n_persona THEN
          DBMS_OUTPUT.PUT_LINE('  tbl_persona_vol: ' || i || ' / ' || l_n_persona);
        END IF;
        a_id.DELETE; a_nif.DELETE; a_nombre.DELETE; a_apellidos.DELETE; a_dir.DELETE; a_tel.DELETE;
        a_email.DELETE; a_obs.DELETE; a_fnac.DELETE; a_falta.DELETE; a_prof.DELETE; a_estciv.DELETE;
        a_pais.DELETE; a_tipo.DELETE; a_canal.DELETE; a_score.DELETE; a_activo.DELETE; a_niffalso.DELETE;
        j := 0;
      END IF;
    END LOOP;
  END p_carga_persona;

  -- B2) tbl_cuenta_vol -- FK -> persona_vol (persona_id = MOD ciclico, siempre en 1..l_n_persona)
  PROCEDURE p_carga_cuenta IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_str IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
    TYPE t_dat IS TABLE OF DATE INDEX BY PLS_INTEGER;
    a_id t_num; a_persona t_num; a_iban t_str; a_ccc t_str; a_saldo t_num;
    a_fap t_dat; a_tipo t_str; a_suc t_str;
    j PLS_INTEGER := 0;
    l_lotes PLS_INTEGER := 0;
  BEGIN
    p_prog_ini;
    FOR i IN 1 .. l_n_cuenta LOOP
      j := j + 1;
      a_id(j)      := i;
      a_persona(j) := MOD(i-1, l_n_persona) + 1;
      a_iban(j)    := CASE WHEN MOD(i,2)=0 THEN f_gen_iban('21000418', i) ELSE f_gen_iban('20380400', i) END;
      a_ccc(j)     := '1234567890' || LPAD(TO_CHAR(i), 10, '0');
      a_saldo(j)   := ROUND(MOD(i,500000)/100, 2);
      a_fap(j)     := SYSDATE - MOD(i,3650);
      a_tipo(j)    := CASE MOD(i,3) WHEN 0 THEN 'CORRIENTE' WHEN 1 THEN 'AHORRO' ELSE 'NOMINA' END;
      a_suc(j)     := LPAD(TO_CHAR(MOD(i,999)),4,'0');

      IF j = c_lote OR i = l_n_cuenta THEN
        FORALL k IN 1 .. j
          INSERT INTO DM_DUMMY.tbl_cuenta_vol (cuenta_id, persona_id, iban, cuenta_ccc, saldo, fecha_apertura, tipo_cuenta, sucursal)
          VALUES (a_id(k), a_persona(k), a_iban(k), a_ccc(k), a_saldo(k), a_fap(k), a_tipo(k), a_suc(k));
        COMMIT;
        l_lotes := l_lotes + 1;
        p_prog('tbl_cuenta_vol', i, l_n_cuenta);
        IF MOD(l_lotes,10) = 0 OR i = l_n_cuenta THEN
          DBMS_OUTPUT.PUT_LINE('  tbl_cuenta_vol: ' || i || ' / ' || l_n_cuenta);
        END IF;
        a_id.DELETE; a_persona.DELETE; a_iban.DELETE; a_ccc.DELETE; a_saldo.DELETE; a_fap.DELETE; a_tipo.DELETE; a_suc.DELETE;
        j := 0;
      END IF;
    END LOOP;
  END p_carga_cuenta;

  -- B3) tbl_movimiento_vol -- segundo salto de FK (cuenta_id -> cuenta_vol). La mas grande.
  PROCEDURE p_carga_movimiento IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_str IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
    TYPE t_dat IS TABLE OF DATE INDEX BY PLS_INTEGER;
    a_id t_num; a_cuenta t_num; a_fecha t_dat; a_importe t_num; a_concepto t_str;
    l_cuenta_id  PLS_INTEGER;
    l_persona_id PLS_INTEGER;
    j PLS_INTEGER := 0;
    l_lotes PLS_INTEGER := 0;
  BEGIN
    p_prog_ini;
    FOR i IN 1 .. l_n_movim LOOP
      j := j + 1;
      l_cuenta_id  := MOD(i-1, l_n_cuenta) + 1;
      a_id(j)      := i;
      a_cuenta(j)  := l_cuenta_id;
      a_fecha(j)   := TRUNC(SYSDATE) - MOD(i,1825);
      a_importe(j) := ROUND(MOD(i,200000)/100, 2) * (CASE WHEN MOD(i,7)=0 THEN -1 ELSE 1 END);
      IF MOD(i,500) = 0 THEN
        -- mismo titular que el de la cuenta (persona_id de cuenta_vol = MOD(cuenta-1, personas)+1)
        l_persona_id := MOD(l_cuenta_id-1, l_n_persona) + 1;
        a_concepto(j) := 'Transferencia a favor de ' || f_gen_nombre(l_persona_id) || ' ' ||
                          f_gen_apellidos(l_persona_id) || ', NIF ' || f_gen_nif(10000000 + l_persona_id);
      ELSE
        a_concepto(j) := CASE MOD(i,5) WHEN 0 THEN 'PAGO RECIBO' WHEN 1 THEN 'TRANSFERENCIA'
                            WHEN 2 THEN 'COMPRA TARJETA' WHEN 3 THEN 'NOMINA' ELSE 'AJUSTE CONTABLE' END
                          || ' REF ' || i;
      END IF;

      IF j = c_lote OR i = l_n_movim THEN
        FORALL k IN 1 .. j
          INSERT INTO DM_DUMMY.tbl_movimiento_vol (movimiento_id, cuenta_id, fecha_mov, importe, concepto)
          VALUES (a_id(k), a_cuenta(k), a_fecha(k), a_importe(k), a_concepto(k));
        COMMIT;
        l_lotes := l_lotes + 1;
        p_prog('tbl_movimiento_vol', i, l_n_movim);
        IF MOD(l_lotes,20) = 0 OR i = l_n_movim THEN
          DBMS_OUTPUT.PUT_LINE('  tbl_movimiento_vol: ' || i || ' / ' || l_n_movim);
        END IF;
        a_id.DELETE; a_cuenta.DELETE; a_fecha.DELETE; a_importe.DELETE; a_concepto.DELETE;
        j := 0;
      END IF;
    END LOOP;
  END p_carga_movimiento;

  -- B4) tbl_empresa_vol -- identidad CIF, independiente
  PROCEDURE p_carga_empresa IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_str IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
    TYPE t_dat IS TABLE OF DATE INDEX BY PLS_INTEGER;
    a_id t_num; a_cif t_str; a_rs t_str; a_dir t_str; a_iban t_str; a_tel t_str;
    a_email t_str; a_sector t_str; a_nemp t_num; a_fact t_num; a_fc t_dat;
    a_tipo t_str; a_activa t_str; a_codfalso t_str;
    j PLS_INTEGER := 0;
  BEGIN
    p_prog_ini;
    FOR i IN 1 .. l_n_empresa LOOP
      j := j + 1;
      a_id(j)      := i;
      a_cif(j)     := f_gen_cif(i);
      a_rs(j)      := 'EMPRESA_DUMMY_' || i || ' S.L.';
      a_dir(j)     := 'POLIGONO INDUSTRIAL ' || MOD(i,20) || ', NAVE ' || i || ', ZARAGOZA';
      a_iban(j)    := f_gen_iban('00490001', 500000000 + i);
      a_tel(j)     := '9' || LPAD(TO_CHAR(MOD(i,99999999)), 8, '0');  -- 9 digitos
      a_email(j)   := 'contacto@empresa' || i || '.com';
      a_sector(j)  := CASE MOD(i,5) WHEN 0 THEN 'INDUSTRIA' WHEN 1 THEN 'SERVICIOS' WHEN 2 THEN 'RETAIL'
                        WHEN 3 THEN 'TECNOLOGIA' ELSE 'LOGISTICA' END;
      a_nemp(j)    := MOD(i,500)+1;
      a_fact(j)    := ROUND(MOD(i,9999999)/100,2);
      a_fc(j)      := SYSDATE - MOD(i,7300);
      a_tipo(j)    := CASE MOD(i,3) WHEN 0 THEN 'SL' WHEN 1 THEN 'SA' ELSE 'AUTONOMO' END;
      a_activa(j)  := CASE WHEN MOD(i,41)=0 THEN 'N' ELSE 'Y' END;
      a_codfalso(j):= 'EXP-' || LPAD(TO_CHAR(i),8,'0');

      IF j = c_lote OR i = l_n_empresa THEN
        FORALL k IN 1 .. j
          INSERT INTO DM_DUMMY.tbl_empresa_vol (empresa_id, cif, razon_social, direccion_fiscal, iban_pago, telefono_contacto,
            email_contacto, sector, num_empleados, facturacion_anual, fecha_constitucion, tipo_empresa, activa, codigo_interno_falso)
          VALUES (a_id(k), a_cif(k), a_rs(k), a_dir(k), a_iban(k), a_tel(k),
            a_email(k), a_sector(k), a_nemp(k), a_fact(k), a_fc(k), a_tipo(k), a_activa(k), a_codfalso(k));
        COMMIT;
        p_prog('tbl_empresa_vol', i, l_n_empresa);
        a_id.DELETE; a_cif.DELETE; a_rs.DELETE; a_dir.DELETE; a_iban.DELETE; a_tel.DELETE; a_email.DELETE;
        a_sector.DELETE; a_nemp.DELETE; a_fact.DELETE; a_fc.DELETE; a_tipo.DELETE; a_activa.DELETE; a_codfalso.DELETE;
        j := 0;
      END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('  tbl_empresa_vol: ' || l_n_empresa);
  END p_carga_empresa;

  -- B5) tbl_factura_vol -- FK -> empresa_vol
  PROCEDURE p_carga_factura IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_str IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
    TYPE t_dat IS TABLE OF DATE INDEX BY PLS_INTEGER;
    a_id t_num; a_emp t_num; a_num t_str; a_fecha t_dat; a_imp t_num; a_estado t_str;
    j PLS_INTEGER := 0;
  BEGIN
    p_prog_ini;
    FOR i IN 1 .. l_n_factura LOOP
      j := j + 1;
      a_id(j)     := i;
      a_emp(j)    := MOD(i-1, l_n_empresa) + 1;
      a_num(j)    := 'FRA-' || TO_CHAR(SYSDATE,'YYYY') || '-' || LPAD(TO_CHAR(i),8,'0');
      a_fecha(j)  := TRUNC(SYSDATE) - MOD(i,1825);
      a_imp(j)    := ROUND(MOD(i,50000)/100,2);
      a_estado(j) := CASE MOD(i,4) WHEN 0 THEN 'PAGADA' WHEN 1 THEN 'PENDIENTE' WHEN 2 THEN 'VENCIDA' ELSE 'ANULADA' END;

      IF j = c_lote OR i = l_n_factura THEN
        FORALL k IN 1 .. j
          INSERT INTO DM_DUMMY.tbl_factura_vol (factura_id, empresa_id, numero_factura, fecha_emision, importe_total, estado)
          VALUES (a_id(k), a_emp(k), a_num(k), a_fecha(k), a_imp(k), a_estado(k));
        COMMIT;
        p_prog('tbl_factura_vol', i, l_n_factura);
        a_id.DELETE; a_emp.DELETE; a_num.DELETE; a_fecha.DELETE; a_imp.DELETE; a_estado.DELETE;
        j := 0;
      END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('  tbl_factura_vol: ' || l_n_factura);
  END p_carga_factura;

  -- B6) tbl_empleado_vol -- identidad propia, sin FK a persona_vol
  PROCEDURE p_carga_empleado IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_str IS TABLE OF VARCHAR2(300) INDEX BY PLS_INTEGER;
    TYPE t_dat IS TABLE OF DATE INDEX BY PLS_INTEGER;
    a_id t_num; a_nif t_str; a_nom t_str; a_ape t_str; a_dir t_str; a_tel t_str;
    a_email t_str; a_iban t_str; a_dpto t_str; a_puesto t_str; a_falta t_dat;
    a_fbaja t_dat; a_sal t_num; a_contr t_str; a_jorn t_str; a_cc t_str;
    a_mgr t_num; a_niv t_str; a_turno t_str; a_activo t_str; a_idioma t_str;
    a_pais t_str; a_obs t_str; a_usr t_str; a_codfalso t_str;
    j PLS_INTEGER := 0;
  BEGIN
    p_prog_ini;
    FOR i IN 1 .. l_n_empleado LOOP
      j := j + 1;
      a_id(j)     := i;
      -- rango numerico distinto del de persona_vol: los VALORES nunca coinciden
      a_nif(j)    := f_gen_nif(80000000 + i);
      a_nom(j)    := f_gen_nombre(i + 3);
      a_ape(j)    := f_gen_apellidos(i + 2);
      a_dir(j)    := 'CALLE EMPLEADO ' || i || ', ZARAGOZA';
      a_tel(j)    := '7' || LPAD(TO_CHAR(MOD(i,99999999)), 8, '0');  -- 9 digitos
      a_email(j)  := 'empleado' || i || '@empresadummy.com';
      a_iban(j)   := f_gen_iban('01820001', 700000000 + i);
      a_dpto(j)   := CASE MOD(i,6) WHEN 0 THEN 'IT' WHEN 1 THEN 'RRHH' WHEN 2 THEN 'FINANZAS'
                       WHEN 3 THEN 'OPERACIONES' WHEN 4 THEN 'VENTAS' ELSE 'LOGISTICA' END;
      a_puesto(j) := 'PUESTO_' || MOD(i,40);
      a_falta(j)  := SYSDATE - MOD(i,7300);
      a_fbaja(j)  := CASE WHEN MOD(i,53)=0 THEN SYSDATE - MOD(i,100) ELSE NULL END;
      a_sal(j)    := 1200 + MOD(i,4000);
      a_contr(j)  := CASE MOD(i,3) WHEN 0 THEN 'INDEFINIDO' WHEN 1 THEN 'TEMPORAL' ELSE 'PRACTICAS' END;
      a_jorn(j)   := CASE MOD(i,2) WHEN 0 THEN 'COMPLETA' ELSE 'PARCIAL' END;
      a_cc(j)     := 'CC' || LPAD(TO_CHAR(MOD(i,99)),3,'0');
      a_mgr(j)    := MOD(i,997)+1;
      a_niv(j)    := 'N' || MOD(i,10);
      a_turno(j)  := CASE MOD(i,3) WHEN 0 THEN 'MANANA' WHEN 1 THEN 'TARDE' ELSE 'PARTIDO' END;
      a_activo(j) := CASE WHEN MOD(i,53)=0 THEN 'N' ELSE 'Y' END;
      a_idioma(j) := CASE MOD(i,3) WHEN 0 THEN 'ES' WHEN 1 THEN 'EN' ELSE 'FR' END;
      a_pais(j)   := 'ESPANA';
      a_obs(j)    := 'Empleado sin incidencias, revision periodica ' || MOD(i,12);  -- sin datos personales (control)
      a_usr(j)    := 'emp' || LPAD(TO_CHAR(i),6,'0');
      a_codfalso(j):= 'C-' || LPAD(TO_CHAR(i),6,'0');

      IF j = c_lote OR i = l_n_empleado THEN
        FORALL k IN 1 .. j
          INSERT INTO DM_DUMMY.tbl_empleado_vol (empleado_id, nif_empleado, nombre_empleado, apellidos_empleado,
            direccion_empleado, telefono_empleado, email_corporativo, iban_nomina, departamento, puesto,
            fecha_alta_emp, fecha_baja_emp, salario_bruto, tipo_contrato, jornada, centro_coste, manager_id,
            nivel, turno, activo_emp, idioma, pais_nacimiento_emp, observaciones_rrhh, usuario_red, codigo_empleado_falso)
          VALUES (a_id(k), a_nif(k), a_nom(k), a_ape(k), a_dir(k), a_tel(k), a_email(k), a_iban(k), a_dpto(k),
            a_puesto(k), a_falta(k), a_fbaja(k), a_sal(k), a_contr(k), a_jorn(k), a_cc(k), a_mgr(k), a_niv(k),
            a_turno(k), a_activo(k), a_idioma(k), a_pais(k), a_obs(k), a_usr(k), a_codfalso(k));
        COMMIT;
        p_prog('tbl_empleado_vol', i, l_n_empleado);
        a_id.DELETE; a_nif.DELETE; a_nom.DELETE; a_ape.DELETE; a_dir.DELETE; a_tel.DELETE; a_email.DELETE;
        a_iban.DELETE; a_dpto.DELETE; a_puesto.DELETE; a_falta.DELETE; a_fbaja.DELETE; a_sal.DELETE;
        a_contr.DELETE; a_jorn.DELETE; a_cc.DELETE; a_mgr.DELETE; a_niv.DELETE; a_turno.DELETE;
        a_activo.DELETE; a_idioma.DELETE; a_pais.DELETE; a_obs.DELETE; a_usr.DELETE; a_codfalso.DELETE;
        j := 0;
      END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('  tbl_empleado_vol: ' || l_n_empleado);
  END p_carga_empleado;

  -- B7) tbl_nomina_vol -- FK -> empleado_vol
  PROCEDURE p_carga_nomina IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_str IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
    TYPE t_dat IS TABLE OF DATE INDEX BY PLS_INTEGER;
    a_id t_num; a_emp t_num; a_per t_str; a_bruto t_num; a_neto t_num; a_fpago t_dat;
    j PLS_INTEGER := 0;
  BEGIN
    p_prog_ini;
    FOR i IN 1 .. l_n_nomina LOOP
      j := j + 1;
      a_id(j)    := i;
      a_emp(j)   := MOD(i-1, l_n_empleado) + 1;
      a_per(j)   := TO_CHAR(2024 + MOD(i,3)) || '-' || LPAD(TO_CHAR(MOD(i,12)+1),2,'0');
      a_bruto(j) := 1200 + MOD(i,4000);
      a_neto(j)  := ROUND(a_bruto(j) * 0.78, 2);
      a_fpago(j) := TRUNC(SYSDATE) - MOD(i,900);

      IF j = c_lote OR i = l_n_nomina THEN
        FORALL k IN 1 .. j
          INSERT INTO DM_DUMMY.tbl_nomina_vol (nomina_id, empleado_id, periodo, importe_bruto, importe_neto, fecha_pago)
          VALUES (a_id(k), a_emp(k), a_per(k), a_bruto(k), a_neto(k), a_fpago(k));
        COMMIT;
        p_prog('tbl_nomina_vol', i, l_n_nomina);
        a_id.DELETE; a_emp.DELETE; a_per.DELETE; a_bruto.DELETE; a_neto.DELETE; a_fpago.DELETE;
        j := 0;
      END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('  tbl_nomina_vol: ' || l_n_nomina);
  END p_carga_nomina;

  -- B8) tbl_documento_vol -- FK -> persona_vol; datos personales en 1 de cada 20 filas
  PROCEDURE p_carga_documento IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_str IS TABLE OF VARCHAR2(500) INDEX BY PLS_INTEGER;
    a_id t_num; a_persona t_num; a_archivo t_str; a_obs t_str; a_pags t_num;
    l_persona_id PLS_INTEGER;
    j PLS_INTEGER := 0;
  BEGIN
    p_prog_ini;
    FOR i IN 1 .. l_n_documento LOOP
      j := j + 1;
      l_persona_id := MOD(i-1, l_n_persona) + 1;
      a_id(j)      := i;
      a_persona(j) := l_persona_id;
      a_archivo(j) := 'doc_' || i || '.pdf';
      a_obs(j)     := CASE WHEN MOD(i,20) = 0
                        THEN 'Documento asociado a ' || f_gen_nombre(l_persona_id) || ' ' || f_gen_apellidos(l_persona_id) ||
                             ', NIF ' || f_gen_nif(10000000 + l_persona_id)
                        ELSE 'Documento estandar sin datos personales en el texto ' || i
                      END;
      a_pags(j)    := 1 + MOD(i,40);

      IF j = c_lote OR i = l_n_documento THEN
        FORALL k IN 1 .. j
          INSERT INTO DM_DUMMY.tbl_documento_vol (documento_id, persona_id, nombre_archivo, observaciones, num_paginas)
          VALUES (a_id(k), a_persona(k), a_archivo(k), a_obs(k), a_pags(k));
        COMMIT;
        p_prog('tbl_documento_vol', i, l_n_documento);
        a_id.DELETE; a_persona.DELETE; a_archivo.DELETE; a_obs.DELETE; a_pags.DELETE;
        j := 0;
      END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('  tbl_documento_vol: ' || l_n_documento);
  END p_carga_documento;

  -- B9) tbl_audit_log_vol -- sin FK; nif_usuario recalculado desde un persona_id ciclico
  PROCEDURE p_carga_audit IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_str IS TABLE OF VARCHAR2(300) INDEX BY PLS_INTEGER;
    a_id t_num; a_nif t_str; a_accion t_str; a_ip t_str; a_usr t_str;
    l_persona_id PLS_INTEGER;
    j PLS_INTEGER := 0;
  BEGIN
    p_prog_ini;
    FOR i IN 1 .. l_n_audit LOOP
      j := j + 1;
      l_persona_id := MOD(i-1, l_n_persona) + 1;
      a_id(j)     := i;
      a_nif(j)    := f_gen_nif(10000000 + l_persona_id);
      a_accion(j) := 'ACCESO_REGISTRO_' || i;
      a_ip(j)     := '10.0.' || MOD(i,255) || '.' || MOD(i*7,255);
      a_usr(j)    := 'SVC_BATCH_' || MOD(i,5);

      IF j = c_lote OR i = l_n_audit THEN
        FORALL k IN 1 .. j
          INSERT INTO DM_DUMMY.tbl_audit_log_vol (log_id, nif_usuario, accion, ip_origen, usuario_sistema)
          VALUES (a_id(k), a_nif(k), a_accion(k), a_ip(k), a_usr(k));
        COMMIT;
        p_prog('tbl_audit_log_vol', i, l_n_audit);
        a_id.DELETE; a_nif.DELETE; a_accion.DELETE; a_ip.DELETE; a_usr.DELETE;
        j := 0;
      END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('  tbl_audit_log_vol: ' || l_n_audit);
  END p_carga_audit;

  -- B10) tbl_referencia_publica_vol -- NIF valido de un dataset publico (no personal)
  PROCEDURE p_carga_refpub IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_str IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
    a_id t_num; a_nif t_str; a_desc t_str;
    j PLS_INTEGER := 0;
  BEGIN
    p_prog_ini;
    FOR i IN 1 .. l_n_refpub LOOP
      j := j + 1;
      a_id(j)   := i;
      a_nif(j)  := f_gen_nif(60000000 + i);
      a_desc(j) := 'Registro publico de prueba ' || i;
      IF j = c_lote OR i = l_n_refpub THEN
        FORALL k IN 1 .. j
          INSERT INTO DM_DUMMY.tbl_referencia_publica_vol (ref_id, nif_publico, descripcion)
          VALUES (a_id(k), a_nif(k), a_desc(k));
        COMMIT;
        p_prog('tbl_referencia_publica_vol', i, l_n_refpub);
        a_id.DELETE; a_nif.DELETE; a_desc.DELETE;
        j := 0;
      END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('  tbl_referencia_publica_vol: ' || l_n_refpub);
  END p_carga_refpub;

  -- B11) tbl_referencia_inversa_vol -- nombre neutro, valor = NIF real
  PROCEDURE p_carga_refinv IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_str IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
    a_id t_num; a_cod t_str; a_etq t_str;
    j PLS_INTEGER := 0;
  BEGIN
    p_prog_ini;
    FOR i IN 1 .. l_n_refinv LOOP
      j := j + 1;
      a_id(j)  := i;
      a_cod(j) := f_gen_nif(65000000 + i);
      a_etq(j) := 'REF_INTERNA_' || i;
      IF j = c_lote OR i = l_n_refinv THEN
        FORALL k IN 1 .. j
          INSERT INTO DM_DUMMY.tbl_referencia_inversa_vol (ref_inv_id, codigo_interno, etiqueta)
          VALUES (a_id(k), a_cod(k), a_etq(k));
        COMMIT;
        p_prog('tbl_referencia_inversa_vol', i, l_n_refinv);
        a_id.DELETE; a_cod.DELETE; a_etq.DELETE;
        j := 0;
      END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('  tbl_referencia_inversa_vol: ' || l_n_refinv);
  END p_carga_refinv;

  -- B12) tbl_config_tecnica_vol -- control negativo: ningun dato personal
  PROCEDURE p_carga_config IS
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_str IS TABLE OF VARCHAR2(500) INDEX BY PLS_INTEGER;
    TYPE t_dat IS TABLE OF DATE INDEX BY PLS_INTEGER;
    a_id t_num; a_clave t_str; a_valor t_str; a_codtec t_str; a_fecha t_dat;
    j PLS_INTEGER := 0;
  BEGIN
    p_prog_ini;
    FOR i IN 1 .. l_n_config LOOP
      j := j + 1;
      a_id(j)     := i;
      a_clave(j)  := 'PARAM_' || i;
      a_valor(j)  := 'valor_tecnico_' || i;
      a_codtec(j) := 'TEC-' || LPAD(TO_CHAR(i),8,'0');
      a_fecha(j)  := SYSDATE - MOD(i,365);
      IF j = c_lote OR i = l_n_config THEN
        FORALL k IN 1 .. j
          INSERT INTO DM_DUMMY.tbl_config_tecnica_vol (config_id, clave, valor, codigo_cliente_tecnico, fecha_actualizacion)
          VALUES (a_id(k), a_clave(k), a_valor(k), a_codtec(k), a_fecha(k));
        COMMIT;
        p_prog('tbl_config_tecnica_vol', i, l_n_config);
        a_id.DELETE; a_clave.DELETE; a_valor.DELETE; a_codtec.DELETE; a_fecha.DELETE;
        j := 0;
      END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('  tbl_config_tecnica_vol: ' || l_n_config);
  END p_carga_config;

  -----------------------------------------------------------------------
  -- C) CIERRE: tamanos fijos (las pruebas de fuerza dependen de ellos)
  -----------------------------------------------------------------------
  PROCEDURE p_carga_cierre IS
    l_dni VARCHAR2(20);
  BEGIN
    -- 50 sucursales: lo que actualiza el trigger de TBL_SUCURSAL_RIESGO
    INSERT INTO DM_DUMMY.tbl_resumen_sucursal (codigo_sucursal, total_actualizaciones)
    SELECT LEVEL, 0 FROM dual CONNECT BY LEVEL <= 50;

    -- 1.000 gestores: pares persona fisica, impares entidad (caso PROMOTOR);
    -- cod_acceso_corto de 4 digitos, unico en 1..1000 porque 7 es primo con 10000
    INSERT INTO DM_DUMMY.tbl_gestor_cartera (gestor_id, gestor, cod_acceso_corto, cartera_valor)
    SELECT n,
           CASE MOD(n,2)
             WHEN 0 THEN REGEXP_SUBSTR(c_noms, '[^,]+', 1, MOD(n,10)+1) || ' ' ||
                         REGEXP_SUBSTR(c_ape1, '[^,]+', 1, MOD(n,11)+1) || ' ' ||
                         REGEXP_SUBSTR(c_ape2, '[^,]+', 1, MOD(n,9)+1)
             ELSE REGEXP_SUBSTR(c_ents, '[^|]+', 1, MOD(n,8)+1)
           END,
           LPAD(TO_CHAR(MOD(n*7, 10000)), 4, '0'),
           ROUND(MOD(n*977, 10000000)/100, 2)
      FROM (SELECT LEVEL n FROM dual CONNECT BY LEVEL <= 1000);

    -- 150.000 filas con trigger de UPDATE; codigo_sucursal CICLICO para que
    -- cualquier chunk toque muchas sucursales (mismo patron que el incidente GES)
    INSERT INTO DM_DUMMY.tbl_sucursal_riesgo (registro_id, codigo_sucursal, titular_principal, importe_riesgo)
    SELECT n, MOD(n,50)+1,
           REGEXP_SUBSTR(c_noms, '[^,]+', 1, MOD(n,10)+1) || ' ' ||
           REGEXP_SUBSTR(c_ape1, '[^,]+', 1, MOD(n,11)+1) || ' ' ||
           REGEXP_SUBSTR(c_ape2, '[^,]+', 1, MOD(n,9)+1),
           ROUND(MOD(n*37, 1000000)/100, 2)
      FROM (SELECT LEVEL n FROM dual CONNECT BY LEVEL <= 150000);

    -- 150.000 filas aisladas para la prueba de corte y reanudacion
    INSERT INTO DM_DUMMY.tbl_lote_resume (lote_id, nombre_completo, estado_proceso)
    SELECT n,
           REGEXP_SUBSTR(c_noms, '[^,]+', 1, MOD(n,10)+1) || ' ' ||
           REGEXP_SUBSTR(c_ape1, '[^,]+', 1, MOD(n,11)+1) || ' ' ||
           REGEXP_SUBSTR(c_ape2, '[^,]+', 1, MOD(n,9)+1),
           'PENDIENTE'
      FROM (SELECT LEVEL n FROM dual CONNECT BY LEVEL <= 150000);

    -- 50 filas con la FK sin nombre hacia tbl_personas (mismos DNI que las personas 1..50)
    FOR i IN 1 .. 50 LOOP
      l_dni := f_gen_nif(30000000 + i);
      INSERT INTO DM_DUMMY.tbl_renovacion_constraint (reg_id, dni_ref, detalle)
      VALUES (i, l_dni, 'RENOVACION_' || i);
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('  cierre: gestor 1000, resumen 50, sucursal_riesgo 150000, lote_resume 150000, renovacion 50');
  END p_carga_cierre;

  -----------------------------------------------------------------------
  -- D) CASOS ESPECIALES: tamanos fijos (documentos con regla especial, sincronizacion,
  --    unicidad, PK grande, formatos, IOT y tabla vacia). Ver README_DM_DUMMY.md.
  -----------------------------------------------------------------------
  PROCEDURE p_carga_especial IS
    l_tipo NUMBER;
    l_doc  VARCHAR2(30);
    l_nd   VARCHAR2(120);
    l_iban VARCHAR2(40);
    l_nif  VARCHAR2(20);
    l_tel  VARCHAR2(20);
  BEGIN
    -- 60 filas: tipo 1 DNI, 3 NIE, 2 pasaporte (rotando); ndocumento = primer y ultimo caracter
    -- fijos con interior numerico; la fila 60 es un documento largo de 102 caracteres.
    -- (bucle: las funciones f_gen_* son locales del bloque y no se pueden llamar desde SQL)
    FOR n IN 1 .. 60 LOOP
      l_tipo := CASE MOD(n,3) WHEN 0 THEN 1 WHEN 1 THEN 3 ELSE 2 END;
      l_doc  := CASE l_tipo WHEN 1 THEN f_gen_nif(60000000 + n)
                            WHEN 3 THEN f_gen_nie(n, 0)
                            ELSE 'PA' || LPAD(TO_CHAR(n), 7, '0') END;
      l_nd   := CASE WHEN n = 60 THEN 'A' || RPAD('1', 100, '1') || 'Z'
                     ELSE 'D' || LPAD(TO_CHAR(n), 10, '0') || 'K' END;
      l_iban := f_gen_iban('21000418', 500000000 + n);
      INSERT INTO DM_DUMMY.tbl_doc_especial (registro_id, tipo_documento, numero_documento, ndocumento, iban_continuo, fecha_alta)
      VALUES (n, l_tipo, l_doc, l_nd, l_iban, DATE '2020-01-01' + n);
    END LOOP;

    -- 60 correos de origen y 120 filas destino (2 por origen) con otro valor de partida
    INSERT INTO DM_DUMMY.tbl_sync_origen (sync_id, correo_cliente)
    SELECT n, 'cliente' || n || '@ejemplo.es'
      FROM (SELECT LEVEL n FROM dual CONNECT BY LEVEL <= 60);
    INSERT INTO DM_DUMMY.tbl_sync_destino (destino_id, sync_id, copia_contacto)
    SELECT n, MOD(n,60) + 1, 'contacto' || n || '@copia.ejemplo.es'
      FROM (SELECT LEVEL n FROM dual CONNECT BY LEVEL <= 120);

    -- 110 filas con indice unico en nombre y email. Nombre = nombre + apellido1 + apellido2 con
    -- modulos 10/11/9 (mcm 990): distintos hasta 990 filas.
    INSERT INTO DM_DUMMY.tbl_unicidad (registro_id, nombre_completo, email)
    SELECT n,
           REGEXP_SUBSTR(c_noms, '[^,]+', 1, MOD(n,10)+1) || ' ' ||
           REGEXP_SUBSTR(c_ape1, '[^,]+', 1, MOD(n,11)+1) || ' ' ||
           REGEXP_SUBSTR(c_ape2, '[^,]+', 1, MOD(n,9)+1),
           'usuario' || n || '@ejemplo.es'
      FROM (SELECT LEVEL n FROM dual CONNECT BY LEVEL <= 110);

    -- 150.000 NIF como clave primaria (f_gen_nif es inyectiva: un numero, un NIF)
    INSERT INTO DM_DUMMY.tbl_dni_pk_vol (nif, importe)
    SELECT TO_CHAR(90000000 + n) || SUBSTR(c_letras, MOD(90000000 + n,23)+1, 1),
           ROUND(MOD(n*53, 1000000)/100, 2)
      FROM (SELECT LEVEL n FROM dual CONNECT BY LEVEL <= 150000);

    -- 120 filas de formatos: NULL en nif 1/3 y telefono 1/4; telefono con +34 en 1/5;
    -- IBAN impreso con espacios; pasaporte de 9 caracteres
    FOR n IN 1 .. 120 LOOP
      l_nif  := CASE WHEN MOD(n,3) = 0 THEN NULL ELSE f_gen_nif(70000000 + n) END;
      l_tel  := CASE WHEN MOD(n,4) = 0 THEN NULL
                     WHEN MOD(n,5) = 0 THEN '+34 6' || LPAD(TO_CHAR(MOD(n*7919, 100000000)), 8, '0')
                     ELSE '6' || LPAD(TO_CHAR(MOD(n*7919, 100000000)), 8, '0') END;
      l_iban := RTRIM(REGEXP_REPLACE(f_gen_iban('21000418', 600000000 + n), '(.{4})', '\1 '));
      INSERT INTO DM_DUMMY.tbl_formatos (fmt_id, nif, telefono, iban_espacios, doc_ident, etiqueta)
      VALUES (n, l_nif, l_tel, l_iban,
              'PA' || CHR(65 + MOD(n,26)) || LPAD(TO_CHAR(n), 6, '0'), 'FMT-' || n);
    END LOOP;

    -- 120.000 filas en una tabla organizada por indice
    INSERT INTO DM_DUMMY.tbl_iot (iot_id, nombre_completo, etiqueta_lote)
    SELECT n,
           REGEXP_SUBSTR(c_noms, '[^,]+', 1, MOD(n,10)+1) || ' ' ||
           REGEXP_SUBSTR(c_ape1, '[^,]+', 1, MOD(n,11)+1) || ' ' ||
           REGEXP_SUBSTR(c_ape2, '[^,]+', 1, MOD(n,9)+1),
           'LOTE-' || MOD(n,100)
      FROM (SELECT LEVEL n FROM dual CONNECT BY LEVEL <= 120000);

    -- tbl_vacia: sin filas a proposito
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('  especiales: doc_especial 60, sync_origen 60, sync_destino 120, unicidad 110, dni_pk_vol 150000, formatos 120, iot 120000, vacia 0');
  END p_carga_especial;

BEGIN
  DBMS_OUTPUT.PUT_LINE('Escala ' || rtrim(to_char(ROUND(l_escala,5), 'FM9999990D99999','NLS_NUMERIC_CHARACTERS=''.,'''),'.') || ' (' || rtrim(to_char(:g_m, 'FM9999990D99999','NLS_NUMERIC_CHARACTERS=''.,'''),'.') || ' M). Objetivos de volumen:');
  DBMS_OUTPUT.PUT_LINE('  persona=' || l_n_persona || ' cuenta=' || l_n_cuenta || ' movimiento=' || l_n_movim);
  DBMS_OUTPUT.PUT_LINE('  empresa=' || l_n_empresa || ' factura=' || l_n_factura ||
                       ' empleado=' || l_n_empleado || ' nomina=' || l_n_nomina);
  DBMS_OUTPUT.PUT_LINE('  documento=' || l_n_documento || ' audit=' || l_n_audit ||
                       ' refpub=' || l_n_refpub || ' refinv=' || l_n_refinv || ' config=' || l_n_config);
  DBMS_OUTPUT.PUT_LINE('  TOTAL VOLUMEN = ' ||
    (l_n_persona + l_n_cuenta + l_n_movim + l_n_empresa + l_n_factura + l_n_empleado + l_n_nomina +
     l_n_documento + l_n_audit + l_n_refpub + l_n_refinv + l_n_config));

  l_t0 := SYSTIMESTAMP;
  p_carga_correctitud;
  p_carga_cierre;
  p_carga_especial;
  DBMS_OUTPUT.PUT_LINE('>> correctitud, cierre y especiales OK, ' || (SYSTIMESTAMP - l_t0));

  l_t0 := SYSTIMESTAMP;
  p_carga_persona;
  p_carga_cuenta;
  p_carga_movimiento;
  DBMS_OUTPUT.PUT_LINE('>> cadena persona/cuenta/movimiento OK, ' || (SYSTIMESTAMP - l_t0));

  l_t0 := SYSTIMESTAMP;
  p_carga_empresa;
  p_carga_factura;
  p_carga_empleado;
  p_carga_nomina;
  p_carga_documento;
  p_carga_audit;
  p_carga_refpub;
  p_carga_refinv;
  p_carga_config;
  DBMS_OUTPUT.PUT_LINE('>> resto de volumen OK, ' || (SYSTIMESTAMP - l_t0));
END;
/

prompt =========================================================================
prompt 3) INDICES, FK Y ESTADISTICAS
prompt =========================================================================
declare
  l_t0 timestamp := systimestamp;
begin
  -- indices de apoyo a FK: reconstruidos una sola vez, sin paralelismo residual
  for i in (select index_name from dba_indexes where owner = 'DM_DUMMY' and status = 'UNUSABLE') loop
    execute immediate 'alter index DM_DUMMY."' || i.index_name || '" rebuild nologging parallel 4';
    execute immediate 'alter index DM_DUMMY."' || i.index_name || '" noparallel';
  end loop;
  dbms_output.put_line('Indices reconstruidos, ' || (systimestamp - l_t0));

  -- FK: ENABLE VALIDATE comprueba de verdad que no hay hijos huerfanos
  for c in (select table_name, constraint_name from dba_constraints
             where owner = 'DM_DUMMY' and constraint_type = 'R' and status = 'DISABLED'
             order by table_name) loop
    execute immediate 'alter table DM_DUMMY."' || c.table_name || '" enable validate constraint "' || c.constraint_name || '"';
  end loop;
  dbms_output.put_line('FK validadas, ' || (systimestamp - l_t0));

  -- estadisticas: el motor decide UPDATE directo o troceado con DBA_TABLES.NUM_ROWS
  for t in (select table_name from dba_tables where owner = 'DM_DUMMY' order by table_name) loop
    dbms_stats.gather_table_stats(ownname => 'DM_DUMMY', tabname => t.table_name, degree => 4, cascade => true);
  end loop;
  dbms_output.put_line('Estadisticas calculadas, ' || (systimestamp - l_t0));
end;
/

set feedback on
column table_name format a30
column num_rows   format 999,999,999,999
column blocks     format 999,999,999

prompt =========================================================================
prompt 4) RESULTADO
prompt =========================================================================
prompt Filas insertadas por tabla (conteo exacto, no estadisticas):
declare
  l_n   number;
  l_tot number := 0;
begin
  for t in (select table_name from dba_tables where owner = 'DM_DUMMY' order by table_name) loop
    execute immediate 'select /*+ parallel(4) */ count(*) from DM_DUMMY."' || t.table_name || '"' into l_n;
    l_tot := l_tot + l_n;
    dbms_output.put_line(rpad(t.table_name, 32) || lpad(to_char(l_n, 'FM999,999,999,999'), 16));
  end loop;
  dbms_output.put_line(rpad('TOTAL', 32) || lpad(to_char(l_tot, 'FM999,999,999,999'), 16));
end;
/

select table_name, num_rows, blocks
  from dba_tables
 where owner = 'DM_DUMMY'
 order by num_rows desc nulls last, table_name;

select count(*) fk_validadas from dba_constraints
 where owner = 'DM_DUMMY' and constraint_type = 'R' and status = 'ENABLED' and validated = 'VALIDATED';

select count(*) indices_no_utilizables from dba_indexes
 where owner = 'DM_DUMMY' and status <> 'VALID';

prompt =========================================================================
prompt 5) EXCEPCIONES DE PRUEBA (TDM_EXCEPCION_COL del esquema del motor)
prompt =========================================================================
declare
  l_motor varchar2(128);
  l_n     number;
begin
  begin
    select username into l_motor
      from (select username from dba_users
             where username in ('ASTSYSADMIN','ACC_ADMIN')
             order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
     where rownum = 1;
  exception
    when no_data_found then
      dbms_output.put_line('AVISO: no hay esquema del motor (ASTSYSADMIN/ACC_ADMIN): excepciones NO cargadas.');
      return;
  end;
  select count(*) into l_n from dba_tables where owner = l_motor and table_name = 'TDM_EXCEPCION_COL';
  if l_n = 0 then
    dbms_output.put_line('AVISO: ' || l_motor || '.TDM_EXCEPCION_COL no existe (motor sin instalar): excepciones NO cargadas.');
    return;
  end if;
  execute immediate
    'merge into ' || l_motor || '.tdm_excepcion_col t using (' ||
    ' select ''DM_DUMMY'' ora_owner, ''TBL_GESTOR_CARTERA'' table_name, ''GESTOR'' column_name, ''FORCE'' accion, ''IDENTIFICADOR_PERSONAL'' identificador_forz, ''Dummy: persona o entidad, validado por negocio'' razon, ''Y'' activa from dual union all' ||
    ' select ''DM_DUMMY'', ''TBL_GESTOR_CARTERA'', ''COD_ACCESO_CORTO'', ''FORCE'', ''IDENTIFICADOR_BANCARIO'', ''Dummy: codigo de acceso, dominio corto'', ''Y'' from dual union all' ||
    ' select ''DM_DUMMY'', ''TBL_PERSONAS'', ''REFERENCIA_CLIENTE'', ''FORCE'', ''IDENTIFICADOR_IDENTIDAD'', ''Dummy: nombre neutro, valor DNI real'', ''Y'' from dual union all' ||
    ' select ''DM_DUMMY'', ''TBL_REFERENCIA_INVERSA_VOL'', ''CODIGO_INTERNO'', ''FORCE'', ''IDENTIFICADOR_IDENTIDAD'', ''Dummy: nombre neutro, valor NIF real'', ''Y'' from dual union all' ||
    ' select ''DM_DUMMY'', ''TBL_DOC_ESPECIAL'', ''NDOCUMENTO'', ''FORCE'', ''IDENTIFICADOR_IDENTIDAD'', ''Dummy: formato propio de documento, ningun valor cumple DNI/NIE/CIF'', ''Y'' from dual union all' ||
    ' select ''DM_DUMMY'', ''TBL_FORMATOS'', ''DOC_IDENT'', ''FORCE'', ''IDENTIFICADOR_IDENTIDAD'', ''Dummy: pasaportes, sin formato de DNI/NIE/CIF'', ''Y'' from dual union all' ||
    ' select ''DM_DUMMY'', ''TBL_FORMATOS'', ''IBAN_ESPACIOS'', ''FORCE'', ''IDENTIFICADOR_BANCARIO'', ''Dummy: IBAN impreso con espacios, no cumple el formato continuo'', ''Y'' from dual union all' ||
    ' select ''DM_DUMMY'', ''TBL_BENEFICIARIOS'', ''EMAIL_BENEFICIARIO'', ''EXCLUDE'', null, ''Dummy: correo de tercero que negocio decide no enmascarar'', ''Y'' from dual' ||
    ') s on (t.ora_owner = s.ora_owner and t.table_name = s.table_name and t.column_name = s.column_name)' ||
    ' when matched then update set t.accion = s.accion, t.identificador_forz = s.identificador_forz, t.razon = s.razon, t.activa = s.activa' ||
    ' when not matched then insert (ora_owner, table_name, column_name, accion, identificador_forz, razon, activa)' ||
    ' values (s.ora_owner, s.table_name, s.column_name, s.accion, s.identificador_forz, s.razon, s.activa)';
  commit;
  dbms_output.put_line('Excepciones cargadas en ' || l_motor || '.TDM_EXCEPCION_COL (7 FORCE + 1 EXCLUDE, ora_owner DM_DUMMY).');

  -- Reglas especiales (solo actuan sobre columnas que el descubrimiento deja en Y) y relacion de
  -- sincronizacion. Se borran las de DM_DUMMY y se reinsertan: repetir esta carga no duplica.
  select count(*) into l_n from dba_tables
   where owner = l_motor and table_name in ('TDM_MASK_REGLA_ESP','TDM_MASK_RELACION_SYNC');
  if l_n < 2 then
    dbms_output.put_line('AVISO: faltan TDM_MASK_REGLA_ESP / TDM_MASK_RELACION_SYNC en ' || l_motor || ': reglas especiales y sincronizacion NO cargadas.');
    return;
  end if;
  execute immediate 'delete from ' || l_motor || '.tdm_mask_regla_esp where ora_esquema = ''DM_DUMMY''';
  execute immediate 'delete from ' || l_motor || '.tdm_mask_relacion_sync where ora_esquema = ''DM_DUMMY''';
  execute immediate
    'insert into ' || l_motor || '.tdm_mask_regla_esp (regla_id, ora_esquema, ora_owner, table_name, column_name, tipo_regla, valor_regla, activa, observacion) ' ||
    'select ' || l_motor || '.seq_dm_mask_regla_esp.nextval, ''DM_DUMMY'', ''DM_DUMMY'', t, c, r, v, ''Y'', o from (' ||
    ' select ''TBL_DOC_ESPECIAL'' t, ''NUMERO_DOCUMENTO'' c, ''DOC_SEGUN_TIPO'' r, ''TIPO_DOCUMENTO'' v, ''Dummy: documento segun la columna de tipo (1 DNI, 3 NIE, otro pasaporte)'' o from dual union all' ||
    ' select ''TBL_DOC_ESPECIAL'', ''NDOCUMENTO'', ''DOC_UNIFICADO_MANTENER_1_Y_ULTIMO'', null, ''Dummy: conserva primer y ultimo caracter'' from dual union all' ||
    ' select ''TBL_DOC_ESPECIAL'', ''IBAN_CONTINUO'', ''IBAN_ES_CONTINUO'', null, ''Dummy: IBAN de 24 caracteres sin espacios'' from dual)';
  execute immediate
    'insert into ' || l_motor || '.tdm_mask_relacion_sync (sync_id, ora_esquema, tabla_origen, columna_join_origen, tabla_destino, columna_join_destino, columna_origen, columna_destino, activa, prioridad, observacion) ' ||
    'values (' || l_motor || '.seq_dm_mask_relacion_sync.nextval, ''DM_DUMMY'', ''TBL_SYNC_ORIGEN'', ''SYNC_ID'', ''TBL_SYNC_DESTINO'', ''SYNC_ID'', ''CORREO_CLIENTE'', ''COPIA_CONTACTO'', ''Y'', 1, ''Dummy: copia del correo bajo nombre neutro, join sin FK'')';
  commit;
  dbms_output.put_line('Reglas especiales (3) y relacion de sincronizacion (1) cargadas en ' || l_motor || ' con ora_esquema DM_DUMMY.');
  dbms_output.put_line('Si el descubrimiento de DM_DUMMY ya se ejecuto antes, repetirlo: @dm_descubre DM_DUMMY Y');
end;
/

prompt =========================================================================
prompt CARGA COMPLETADA. Siguiente paso: descubrimiento sobre DM_DUMMY (ver README_DM_DUMMY.md).
prompt =========================================================================
