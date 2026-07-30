Rem pkg_dm_func_mask.sql
Rem
Rem Este paquete implementa las funciones deterministas de enmascaramiento
Rem utilizadas por el motor de masking de datos sensibles.
Rem Cada función transforma un valor original en un valor ficticio,
Rem consistente y reutilizable dentro del proceso.
Rem
Rem
Rem    NOMBRE
Rem      pkg_dm_func_mask.sql - Funciones deterministas de enmascaramiento
Rem
Rem    DESCRIPCIÓN
Rem      Este paquete contiene las funciones base de enmascaramiento
Rem      que serán invocadas por pkg_dm_enmascarar para transformar
Rem      valores sensibles en datos ficticios, manteniendo consistencia
Rem      funcional y compatibilidad con el modelo de datos.
Rem
Rem      Las funciones implementadas permiten:
Rem
Rem        - Enmascaramiento de nombres y apellidos
Rem        - Enmascaramiento de direcciones
Rem        - Enmascaramiento de observaciones y textos libres
Rem        - Enmascaramiento de teléfonos
Rem        - Enmascaramiento de correos electrónicos
Rem        - Enmascaramiento de NIF/DNI/NIE/CIF
Rem        - Enmascaramiento de cuentas bancarias
Rem        - Enmascaramiento de IBAN español
Rem        - Resolución genérica por identificador semántico
Rem
Rem    COMPORTAMIENTO DE LAS FUNCIONES
Rem
Rem      func_nombre
Rem        - Mezcla caracteres alfabéticos manteniendo longitud base
Rem        - Conserva estructura general del dato
Rem        - Se usa para nombre, apellido o dato personal textual corto
Rem
Rem      func_direccion
Rem        - Mezcla letras y dígitos manteniendo estructura general
Rem        - Conserva separadores, espacios y signos
Rem        - Se usa para direcciones o textos estructurados de domicilio
Rem
Rem      func_obs
Rem        - Sustituye el contenido por una marca fija de observación enmascarada
Rem        - Se usa para textos libres, observaciones o contenido narrativo
Rem        - Se evita mantener el texto original por riesgo semántico
Rem
Rem      func_telefono
Rem        - Genera un número ficticio consistente
Rem        - Intenta respetar la longitud del valor de entrada
Rem        - Para formatos españoles suele empezar por 6, 7, 8 o 9
Rem
Rem      func_email
Rem        - Genera un correo ficticio con estructura válida
Rem        - Mantiene formato general usuario@dominio
Rem        - Utiliza dominios controlados como correo.com o correo.es
Rem
Rem      func_nif
Rem        - Genera un documento ficticio válido según el patrón detectado
Rem        - Soporta NIF, NIE y CIF
Rem        - Calcula letra o carácter de control cuando aplica
Rem
Rem      func_cuenta
Rem        - Genera una cuenta ficticia numérica
Rem        - Respeta la longitud lógica real del valor de entrada
Rem        - Se usa para número de cuenta o código bancario no IBAN
Rem
Rem      func_iban
Rem        - Genera un IBAN español ficticio
Rem        - Mantiene prefijo ES y recalcula los dígitos de control
Rem        - Produce un valor formalmente válido para pruebas
Rem
Rem      func_generico
Rem        - Resuelve dinámicamente la función a invocar
Rem        - Se basa en el identificador semántico recibido
Rem        - Centraliza el uso desde el paquete de enmascaramiento
Rem
Rem    CORRECCIONES Y AJUSTES RELEVANTES
Rem      - Corrección de ORA-06502 por desbordamiento de buffer en textos
Rem      - Sustitución de concatenaciones inseguras por control explícito
Rem        de longitud en bytes
Rem      - Uso de SUBSTRB y funciones helper para limitar salida
Rem      - Ajuste de tamaños internos para ejecución segura desde SQL
Rem      - Corrección de func_cuenta para respetar longitud real del dato
Rem      - Ajuste de func_iban para no exceder la longitud del destino
Rem
Rem    RELACIÓN CON LA CACHE
Rem      El paquete puede trabajar con o sin tdm_mask_cache.
Rem      La determinística principal depende del valor de entrada.
Rem      La cache solo debe utilizarse de forma opcional en dominios
Rem      muy repetitivos como nombres, apellidos o documentos.
Rem      No debe usarse para observaciones largas, direcciones extensas
Rem      ni textos libres.
Rem
Rem    NOTAS
Rem      - Diseñado para Oracle 11g en adelante
Rem      - Todas las funciones públicas son DETERMINISTIC
Rem      - El resultado depende exclusivamente del valor de entrada
Rem      - Se utiliza DBMS_UTILITY.GET_HASH_VALUE como base de consistencia
Rem      - No realiza cambios sobre metadatos ni altera estructuras
Rem      - Debe respetarse la longitud destino desde pkg_dm_enmascarar
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    07/20/25 - Versión inicial de funciones de masking
Rem                           Basado en mezcla determinista por hash
Rem
Rem    epurisaca    08/18/25 - Se incorpora soporte para email, teléfono
Rem                           y documento de identidad español
Rem
Rem    epurisaca    10/02/25 - Se refuerza consistencia para NIF/NIE/CIF
Rem                           y se incorpora cálculo de control IBAN
Rem
Rem    epurisaca    01/12/26 - Ajustes para proteger textos largos
Rem                           y reducir errores de longitud en SQL
Rem
Rem    epurisaca    03/24/26 - Corrección de ORA-06502 en funciones textuales
Rem                           Uso de SUBSTRB, control por bytes y append seguro
Rem
Rem    epurisaca    03/24/26 - Corrección de longitud en func_cuenta y func_iban
Rem                           Alineado con columnas CUENTA, CCC e IBAN
Rem
Rem    epurisaca    03/24/26 - Revisión funcional completa del paquete
Rem                           Alineado con masking determinista productivo


create or replace PACKAGE pkg_dm_func_mask AUTHID DEFINER AS
  FUNCTION func_nombre(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION func_direccion(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION func_obs(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION func_telefono(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION func_email(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION func_nif(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;      -- DNI/NIE/CIF
  FUNCTION func_cuenta(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;   -- 20
  FUNCTION func_iban(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;     -- ES + 22

  FUNCTION func_generico(
    p_identificador IN VARCHAR2,
    p_valor         IN VARCHAR2
  ) RETURN VARCHAR2 DETERMINISTIC;
END pkg_dm_func_mask;
/

create or replace PACKAGE BODY pkg_dm_func_mask AS

  c_max_txt CONSTANT PLS_INTEGER := 1000;

  FUNCTION f_hash(p_txt VARCHAR2) RETURN NUMBER IS
  BEGIN
    RETURN ABS(DBMS_UTILITY.GET_HASH_VALUE(NVL(p_txt,'~NULL~'),1,2147483646));
  END;

  FUNCTION f_txt_seguro(p_txt VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_txt IS NULL THEN
      RETURN NULL;
    END IF;

    -- Usar semántica de caracteres evita cortar en mitad de un multibyte
    -- (causa frecuente de ORA-06502 en asignaciones posteriores por carácter).
    RETURN SUBSTR(p_txt, 1, c_max_txt);
  END;

  FUNCTION f_mix_alpha(p_txt VARCHAR2, p_seed NUMBER) RETURN VARCHAR2 IS
    l_txt  VARCHAR2(32767) := f_txt_seguro(p_txt);
    l_seed NUMBER := p_seed;
    l_out  VARCHAR2(32767) := '';
    l_ch   VARCHAR2(32 CHAR);
  BEGIN
    IF l_txt IS NULL THEN
      RETURN NULL;
    END IF;

    FOR i IN 1 .. LENGTH(l_txt) LOOP
      l_ch := SUBSTR(l_txt,i,1);

      IF REGEXP_LIKE(l_ch,'[[:alpha:]]') THEN
        l_seed := MOD(l_seed*131+17,26);
        l_out  := l_out || CHR(65+l_seed);
      ELSE
        l_out  := l_out || l_ch;
      END IF;
    END LOOP;

    RETURN SUBSTR(l_out, 1, c_max_txt);
  END;

  FUNCTION func_nombre(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_txt VARCHAR2(32767);
  BEGIN
    IF p_valor IS NULL THEN
      RETURN NULL;
    END IF;

    l_txt := f_txt_seguro(p_valor);
    RETURN f_mix_alpha(l_txt, f_hash('NOMBRE|'||UPPER(l_txt)));
  END;

  FUNCTION func_direccion(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_txt  VARCHAR2(32767);
    l_seed NUMBER;
    l_out  VARCHAR2(32767);
    l_tipo VARCHAR2(20);
    l_nom  VARCHAR2(30);
    l_num  NUMBER;
    l_city VARCHAR2(30);
  BEGIN
    IF p_valor IS NULL THEN
      RETURN NULL;
    END IF;

    l_txt  := f_txt_seguro(p_valor);
    l_seed := f_hash('DIR|'||UPPER(l_txt));
    l_tipo := CASE MOD(l_seed,4)
                WHEN 0 THEN 'Calle'
                WHEN 1 THEN 'Avenida'
                WHEN 2 THEN 'Plaza'
                ELSE 'Camino'
              END;
    l_nom  := CASE MOD(TRUNC(l_seed/4),8)
                WHEN 0 THEN 'Ficticia'
                WHEN 1 THEN 'Mayor'
                WHEN 2 THEN 'Real'
                WHEN 3 THEN 'Sol'
                WHEN 4 THEN 'Luna'
                WHEN 5 THEN 'Paz'
                WHEN 6 THEN 'Olivo'
                ELSE 'Ribera'
              END;
    l_num  := MOD(TRUNC(l_seed/17), 999) + 1;
    l_city := CASE MOD(TRUNC(l_seed/11),8)
                WHEN 0 THEN 'Madrid'
                WHEN 1 THEN 'Barcelona'
                WHEN 2 THEN 'Valencia'
                WHEN 3 THEN 'Sevilla'
                WHEN 4 THEN 'Zaragoza'
                WHEN 5 THEN 'Bilbao'
                WHEN 6 THEN 'Malaga'
                ELSE 'Valladolid'
              END;

    l_out := l_tipo||' '||l_nom||' N '||TO_CHAR(l_num)||', '||l_city;

    RETURN SUBSTR(l_out, 1, c_max_txt);
  END;

  FUNCTION func_obs(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    IF p_valor IS NULL THEN
      RETURN NULL;
    END IF;

    RETURN '***OBSERVACION ENMASCARADA***';
  END;

  FUNCTION func_telefono(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_seed NUMBER;
    l_num  VARCHAR2(9);
    l_pref VARCHAR2(1);
  BEGIN
    IF p_valor IS NULL THEN
      RETURN NULL;
    END IF;

    l_seed := f_hash(REGEXP_REPLACE(p_valor,'[^0-9]',''));
    l_pref := SUBSTR('6789', MOD(l_seed,4)+1,1);
    l_num  := l_pref || LPAD(TO_CHAR(MOD(l_seed*97+13,100000000)),8,'0');

    RETURN l_num;
  END;

  FUNCTION func_email(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_txt   VARCHAR2(32767);
    l_seed  NUMBER;
    l_local VARCHAR2(64) := '';
    l_dom   VARCHAR2(20);
    l_out   VARCHAR2(200);
  BEGIN
    IF p_valor IS NULL THEN
      RETURN NULL;
    END IF;

    l_txt  := LOWER(TRIM(f_txt_seguro(p_valor)));
    l_seed := f_hash(l_txt);

    FOR i IN 1 .. 10 LOOP
      l_seed  := MOD(l_seed*131+17,26);
      l_local := l_local || CHR(97+l_seed);
    END LOOP;

    l_dom := CASE WHEN MOD(l_seed,2)=0 THEN 'correo.com' ELSE 'correo.es' END;
    l_out := l_local || TO_CHAR(MOD(l_seed*31+7,999)) || '@' || l_dom;

    RETURN l_out;
  END;

  FUNCTION f_letra_dni(p_num NUMBER) RETURN CHAR IS
    l_tab CONSTANT VARCHAR2(23) := 'TRWAGMYFPDXBNJZSQVHLCKE';
  BEGIN
    RETURN SUBSTR(l_tab, MOD(p_num,23)+1, 1);
  END;

  FUNCTION f_cif_ctrl(p_tipo CHAR, p_num7 VARCHAR2) RETURN CHAR IS
    s_par NUMBER := 0;
    s_imp NUMBER := 0;
    d     NUMBER;
    x     NUMBER;
    c     NUMBER;
    l_tab CONSTANT VARCHAR2(10) := 'JABCDEFGHI';
  BEGIN
    FOR i IN 1 .. 7 LOOP
      d := TO_NUMBER(SUBSTR(p_num7,i,1));

      IF MOD(i,2)=0 THEN
        s_par := s_par + d;
      ELSE
        x := d*2;
        s_imp := s_imp + TRUNC(x/10) + MOD(x,10);
      END IF;
    END LOOP;

    c := MOD(10 - MOD(s_par+s_imp,10), 10);

    IF p_tipo IN ('K','P','Q','S','N','W') THEN
      RETURN SUBSTR(l_tab,c+1,1);
    ELSIF p_tipo IN ('A','B','E','H') THEN
      RETURN TO_CHAR(c);
    ELSE
      RETURN CASE WHEN MOD(c,2)=0 THEN TO_CHAR(c) ELSE SUBSTR(l_tab,c+1,1) END;
    END IF;
  END;

  FUNCTION func_nif(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_val  VARCHAR2(50) := UPPER(TRIM(SUBSTR(p_valor,1,50)));
    l_seed NUMBER;
    l_out  VARCHAR2(20);
    l_num8 VARCHAR2(8);
    l_num7 VARCHAR2(7);
    l_tipo CHAR(1);
    l_set  CONSTANT VARCHAR2(20) := 'ABCDEFGHJKLMNPQRSUVW';
  BEGIN
    IF l_val IS NULL THEN
      RETURN NULL;
    END IF;

    l_seed := f_hash('NIF|'||l_val);

    IF REGEXP_LIKE(l_val,'^[0-9]{8}[A-Z]$') THEN
      l_num8 := LPAD(TO_CHAR(MOD(l_seed*37+19,100000000)),8,'0');
      l_out  := l_num8 || f_letra_dni(TO_NUMBER(l_num8));

    ELSIF REGEXP_LIKE(l_val,'^[XYZ][0-9]{7}[A-Z]$') THEN
      l_tipo := SUBSTR('XYZ', MOD(l_seed,3)+1, 1);
      l_num7 := LPAD(TO_CHAR(MOD(l_seed*41+23,10000000)),7,'0');
      l_out  := l_tipo || l_num7 ||
                f_letra_dni(TO_NUMBER(CASE l_tipo WHEN 'X' THEN '0' WHEN 'Y' THEN '1' ELSE '2' END || l_num7));
    ELSE
      l_tipo := SUBSTR(l_set, MOD(l_seed, LENGTH(l_set))+1, 1);
      l_num7 := LPAD(TO_CHAR(MOD(l_seed*43+29,10000000)),7,'0');
      l_out  := l_tipo || l_num7 || f_cif_ctrl(l_tipo, l_num7);
    END IF;

    RETURN l_out;
  END;

  FUNCTION func_cuenta(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_seed NUMBER;
    l_out  VARCHAR2(20);
    l_in_len NUMBER;
    l_target_len NUMBER;
  BEGIN
    IF p_valor IS NULL THEN
      RETURN NULL;
    END IF;

    l_in_len := LENGTH(REGEXP_REPLACE(SUBSTR(p_valor,1,200),'[^0-9]',''));
    IF NVL(l_in_len,0) = 0 THEN
      l_in_len := LEAST(LENGTH(SUBSTR(p_valor,1,200)), 20);
    END IF;

    l_target_len := LEAST(GREATEST(l_in_len, 4), 20);

    l_seed := f_hash('CUENTA|'||REGEXP_REPLACE(SUBSTR(p_valor,1,200),'[^0-9]',''));
    l_out  := LPAD(TO_CHAR(MOD(l_seed*131+17,1000000000000)), l_target_len, '0');

    RETURN l_out;
  END;

  FUNCTION f_iban_cc_es(p_bban20 VARCHAR2) RETURN VARCHAR2 IS
    l_txt  VARCHAR2(200) := p_bban20 || '142800';
    l_rem  NUMBER := 0;
    l_part VARCHAR2(20);
  BEGIN
    FOR i IN 1 .. CEIL(LENGTH(l_txt)/7) LOOP
      l_part := TO_CHAR(l_rem) || SUBSTR(l_txt,(i-1)*7+1,7);
      l_rem  := MOD(TO_NUMBER(l_part),97);
    END LOOP;

    RETURN LPAD(TO_CHAR(98-l_rem),2,'0');
  END;

  FUNCTION func_iban(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_seed NUMBER;
    l_bban VARCHAR2(20);
    l_cc   VARCHAR2(2);
    l_out  VARCHAR2(24);
    l_in_len NUMBER;
  BEGIN
    IF p_valor IS NULL THEN
      RETURN NULL;
    END IF;

    l_seed := f_hash('IBAN|'||UPPER(TRIM(SUBSTR(p_valor,1,50))));
    l_bban := LPAD(TO_CHAR(MOD(l_seed*137+31,1000000000000)),20,'0');
    l_cc   := f_iban_cc_es(l_bban);
    l_out  := 'ES'||l_cc||l_bban;
    l_in_len := LENGTH(REPLACE(UPPER(TRIM(SUBSTR(p_valor,1,50))), ' ', ''));
    IF NVL(l_in_len,0) > 0 AND l_in_len < LENGTH(l_out) THEN
      l_out := SUBSTR(l_out, 1, l_in_len);
    END IF;

    RETURN l_out;
  END;

  ------------------------------------------------------------------------------
  -- Reglas especiales (capa semántica para orquestador)
  ------------------------------------------------------------------------------
  FUNCTION func_especial_doc_keep_ends(
    p_valor IN VARCHAR2
  ) RETURN VARCHAR2 DETERMINISTIC IS
    l_val  VARCHAR2(4000) := UPPER(TRIM(p_valor));
    l_seed NUMBER;
    l_mid  VARCHAR2(4000) := '';
    l_ch   VARCHAR2(4 CHAR);
  BEGIN
    IF l_val IS NULL THEN RETURN NULL; END IF;
    IF LENGTH(l_val) <= 2 THEN RETURN l_val; END IF;

    l_seed := f_hash('DOC_KEEP_ENDS|'||l_val);
    FOR i IN 2 .. LENGTH(l_val)-1 LOOP
      l_ch := SUBSTR(l_val,i,1);
      IF REGEXP_LIKE(l_ch,'[0-9]') THEN
        l_seed := MOD(l_seed*29+7,10); l_mid := l_mid || TO_CHAR(l_seed);
      ELSIF REGEXP_LIKE(l_ch,'[[:alpha:]]') THEN
        l_seed := MOD(l_seed*131+17,26); l_mid := l_mid || CHR(65+l_seed);
      ELSE
        l_mid := l_mid || l_ch;
      END IF;
    END LOOP;
    RETURN SUBSTR(l_val,1,1) || l_mid || SUBSTR(l_val,-1,1);
  END;

  FUNCTION func_especial_doc_segun_tipo(
    p_documento       IN VARCHAR2,
    p_idtipodocumento IN NUMBER
  ) RETURN VARCHAR2 DETERMINISTIC IS
    l_val  VARCHAR2(4000) := UPPER(TRIM(p_documento));
    l_seed NUMBER;
    l_num8 VARCHAR2(8);
    l_num7 VARCHAR2(7);
    l_x    VARCHAR2(1);
  BEGIN
    IF l_val IS NULL THEN RETURN NULL; END IF;

    l_seed := f_hash('DOC_TIPO|'||l_val||'|'||TO_CHAR(NVL(p_idtipodocumento,-1)));

    IF p_idtipodocumento = 1 THEN
      l_num8 := LPAD(TO_CHAR(MOD(l_seed*37+19,100000000)),8,'0');
      RETURN l_num8 || f_letra_dni(TO_NUMBER(l_num8));
    ELSIF p_idtipodocumento = 3 THEN
      l_x    := SUBSTR('XYZ', MOD(l_seed,3)+1,1);
      l_num7 := LPAD(TO_CHAR(MOD(l_seed*41+23,10000000)),7,'0');
      RETURN l_x || l_num7 || f_letra_dni(TO_NUMBER(CASE l_x WHEN 'X' THEN '0' WHEN 'Y' THEN '1' ELSE '2' END || l_num7));
    ELSE
      RETURN REGEXP_REPLACE(l_val, '[0-9]', '9');
    END IF;
  END;

  FUNCTION func_especial_iban_continuo(
    p_valor IN VARCHAR2
  ) RETURN VARCHAR2 DETERMINISTIC IS
    l_seed NUMBER;
    l_bban VARCHAR2(20);
    l_txt  VARCHAR2(200);
    l_rem  NUMBER := 0;
    l_part VARCHAR2(20);
    l_cc   VARCHAR2(2);
    l_out  VARCHAR2(24);
    l_in_len NUMBER;
  BEGIN
    IF p_valor IS NULL THEN RETURN NULL; END IF;
    l_seed := f_hash('IBAN_SIGAD|'||UPPER(TRIM(p_valor)));
    l_bban := LPAD(TO_CHAR(MOD(l_seed*137+31,1000000000000)),20,'0');
    l_txt  := l_bban || '142800';
    FOR i IN 1 .. CEIL(LENGTH(l_txt)/7) LOOP
      l_part := TO_CHAR(l_rem) || SUBSTR(l_txt,(i-1)*7+1,7);
      l_rem  := MOD(TO_NUMBER(l_part),97);
    END LOOP;
    l_cc := LPAD(TO_CHAR(98-l_rem),2,'0');
    l_out := 'ES'||l_cc||l_bban;
    l_in_len := LENGTH(REPLACE(UPPER(TRIM(SUBSTR(p_valor,1,50))), ' ', ''));
    IF NVL(l_in_len,0) > 0 AND l_in_len < LENGTH(l_out) THEN
      l_out := SUBSTR(l_out, 1, l_in_len);
    END IF;
    RETURN l_out;
  END;

  FUNCTION func_generico(
    p_identificador IN VARCHAR2,
    p_valor         IN VARCHAR2
  ) RETURN VARCHAR2 DETERMINISTIC IS
    l_id VARCHAR2(100) := UPPER(NVL(TRIM(p_identificador),''));
  BEGIN
    IF p_valor IS NULL THEN
      RETURN NULL;
    END IF;

    CASE l_id
      WHEN 'IDENTIFICADOR_PERSONAL'      THEN RETURN func_nombre(p_valor);
      WHEN 'IDENTIFICADOR_NOMBRE'        THEN RETURN func_nombre(p_valor);
      WHEN 'IDENTIFICADOR_APELLIDO'      THEN RETURN func_nombre(p_valor);
      WHEN 'IDENTIFICADOR_APE1'          THEN RETURN func_nombre(p_valor);
      WHEN 'IDENTIFICADOR_APE2'          THEN RETURN func_nombre(p_valor);
      WHEN 'IDENTIFICADOR_DIRECCION'     THEN RETURN func_direccion(p_valor);
      WHEN 'IDENTIFICADOR_DOMICILIO'     THEN RETURN func_direccion(p_valor);
      WHEN 'IDENTIFICADOR_OBSERVACION'   THEN RETURN func_obs(p_valor);
      WHEN 'IDENTIFICADOR_OBS'           THEN RETURN func_obs(p_valor);
      WHEN 'IDENTIFICADOR_TELEFONO'      THEN RETURN func_telefono(p_valor);
      WHEN 'IDENTIFICADOR_MOVIL'         THEN RETURN func_telefono(p_valor);
      WHEN 'IDENTIFICADOR_EMAIL'         THEN RETURN func_email(p_valor);
      WHEN 'IDENTIFICADOR_IDENTIDAD'     THEN RETURN func_nif(p_valor);
      WHEN 'IDENTIFICADOR_DOCUMENTO'     THEN RETURN func_nif(p_valor);
      WHEN 'IDENTIFICADOR_BANCARIO'      THEN
        IF REGEXP_LIKE(UPPER(TRIM(SUBSTR(p_valor,1,50))), '^ES[0-9]{22}$') THEN
          RETURN func_iban(p_valor);
        ELSE
          RETURN func_cuenta(p_valor);
        END IF;
      ELSE
        IF INSTR(l_id,'NOMBRE') > 0 OR INSTR(l_id,'PERSON') > 0 OR INSTR(l_id,'APELL') > 0 OR INSTR(l_id,'APE1') > 0 OR INSTR(l_id,'APE2') > 0 THEN
          RETURN func_nombre(p_valor);
        ELSIF INSTR(l_id,'DIREC') > 0 OR INSTR(l_id,'DOMIC') > 0 OR INSTR(l_id,'VIA') > 0 THEN
          RETURN func_direccion(p_valor);
        ELSIF INSTR(l_id,'EMAIL') > 0 OR INSTR(l_id,'MAIL') > 0 THEN
          RETURN func_email(p_valor);
        ELSIF INSTR(l_id,'TELEF') > 0 OR INSTR(l_id,'MOVIL') > 0 THEN
          RETURN func_telefono(p_valor);
        ELSIF INSTR(l_id,'NIF') > 0 OR INSTR(l_id,'NIE') > 0 OR INSTR(l_id,'DOC') > 0 OR INSTR(l_id,'IDENT') > 0 THEN
          RETURN func_nif(p_valor);
        ELSIF INSTR(l_id,'IBAN') > 0 OR INSTR(l_id,'CUENTA') > 0 OR INSTR(l_id,'BANC') > 0 THEN
          IF REGEXP_LIKE(UPPER(TRIM(SUBSTR(p_valor,1,50))), '^ES[0-9]{22}$') THEN
            RETURN func_iban(p_valor);
          ELSE
            RETURN func_cuenta(p_valor);
          END IF;
        ELSE
          RETURN func_obs(p_valor);
        END IF;
    END CASE;
  END;

END pkg_dm_func_mask;
/
