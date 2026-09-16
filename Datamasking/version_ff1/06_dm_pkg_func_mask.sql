Rem pkg_dm_func_mask.sql  (VERSION FF1 - NIST SP 800-38G)
Rem
Rem    NOMBRE
Rem      pkg_dm_func_mask.sql - Funciones deterministas de enmascaramiento
Rem
Rem    DESCRIPCION
Rem      Funciones base de enmascaramiento invocadas por pkg_dm_enmascarar.
Rem      Transforman valores sensibles en datos ficticios preservando formato,
Rem      consistencia funcional e integridad referencial.
Rem
Rem      NUCLEO CRIPTOGRAFICO (cambio de esta version):
Rem        Los dominios NUMERICOS de longitud fija (DNI, NIE, CIF, cuenta, BBAN
Rem        del IBAN) se cifran ahora con FF1, el modo de Cifrado que Preserva
Rem        Formato (FPE) estandar del NIST (SP 800-38G), construido sobre AES-128.
Rem        Sustituye a la red Feistel propia de 4 rondas con HMAC-SHA1 truncado.
Rem
Rem      PROPIEDADES QUE APORTA FF1
Rem        - Biyectivo por construccion  -> 0 colisiones dentro de (longitud, ajuste)
Rem        - Determinista                -> mismo valor + misma clave = mismo cifrado
Rem        - Irreversible en la practica -> sin la clave AES (derivada del pepper)
Rem        - Ajuste (tweak) por DOMINIO  -> separa dominios sin romper la
Rem                                         propagacion por clave ajena (FK)
Rem        - Algoritmo certificado NIST  -> auditable y defendible ante el cliente
Rem
Rem    INVARIANTE DE INTEGRIDAD REFERENCIAL (FK)
Rem      El ajuste FF1 depende SOLO del identificador semantico (no de tabla,
Rem      columna, ROWID ni ID de fila). Dos columnas unidas por una FK que
Rem      comparten identificador reciben el mismo ajuste y la misma longitud,
Rem      luego el mismo valor original produce el mismo valor enmascarado en
Rem      padre e hija. Un ajuste por fila ROMPERIA la propagacion: NO usar.
Rem
Rem    RESTRICCION OPERATIVA (A-02): estas funciones son DETERMINISTIC solo DENTRO
Rem      de una campana (dependen del pepper de tdm_secreto y de set_ejecucion). NO
Rem      crear indices basados en funcion (FBI) ni vistas materializadas sobre ellas.
Rem
Rem    COMPATIBILIDAD
Rem      - Oracle 11g en adelante (AES-128 y HMAC/HASH SHA-1 de DBMS_CRYPTO son 11g)
Rem      - No requiere wallet ni TDE. Requiere GRANT EXECUTE ON SYS.DBMS_CRYPTO.
Rem      - Firmas PUBLICAS identicas a la version anterior: pkg_dm_enmascarar y
Rem        pkg_dm_descubrimiento NO necesitan cambios.
Rem
Rem    MODIFICADO   (MM/DD/YY)
Rem    epurisaca    ...      - Versiones previas (hash, biyeccion afin, Feistel propio)
Rem    epurisaca    06/06/26 - Migracion del nucleo numerico a FF1 (NIST SP 800-38G).
Rem                            CIF y doc_segun_tipo pasan a ser biyectivos (FF1).
Rem                            Semilla de dominios de texto elevada a 60 bits (HMAC-SHA1).

create or replace PACKAGE pkg_dm_func_mask AS

  FUNCTION func_nombre(   p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION func_direccion(p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION func_telefono( p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION func_email(    p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION func_nif(      p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION func_iban(     p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION func_cuenta(   p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION func_obs(      p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;

  FUNCTION func_generico(
    p_identificador IN VARCHAR2,
    p_valor         IN VARCHAR2
  ) RETURN VARCHAR2 DETERMINISTIC;

  FUNCTION func_especial_doc_segun_tipo(
    p_documento       IN VARCHAR2,
    p_idtipodocumento IN NUMBER
  ) RETURN VARCHAR2 DETERMINISTIC;

  FUNCTION func_especial_doc_keep_ends(
    p_valor IN VARCHAR2
  ) RETURN VARCHAR2 DETERMINISTIC;

  FUNCTION func_especial_iban_continuo(
    p_valor IN VARCHAR2
  ) RETURN VARCHAR2 DETERMINISTIC;

  -- Fija la campana activa (ejecucion_id) de la sesion. La invoca el orquestador
  -- en el coordinador y CADA worker paralelo, para leer el pepper de su campana.
  PROCEDURE set_ejecucion(p_ejecucion_id IN NUMBER);

  -- Primitivo FF1 de CIFRADO (radix 10) con clave y tweak EXPLICITOS. Fuente unica
  -- de verdad del algoritmo; el motor lo usa via f_ff1_cifra con la clave del pepper.
  -- Expuesto para validar contra los vectores oficiales del NIST. Solo CIFRA.
  FUNCTION f_ff1_cifrar_raw(p_digitos IN VARCHAR2, p_clave IN RAW, p_ajuste IN RAW) RETURN VARCHAR2;

END pkg_dm_func_mask;
/

create or replace PACKAGE BODY pkg_dm_func_mask AS

  c_max_txt CONSTANT PLS_INTEGER := 1000;

  -- ============================================================================
  -- ESTADO DE SESION (secretos cacheados). Bajo DBMS_PARALLEL_EXECUTE cada worker
  -- es una sesion distinta pero LEE el mismo pepper de tdm_secreto -> deriva la
  -- MISMA clave AES -> resultado determinista y coherente entre chunks y tablas.
  -- ============================================================================
  g_pepper      VARCHAR2(128);
  g_ejecucion_id NUMBER;        -- campana activa; NULL = clave legacy fija
  g_clave_aes   RAW(16);
  c_iv_cero     CONSTANT RAW(16) := HEXTORAW('00000000000000000000000000000000');

  -- ----------------------------------------------------------------------------
  -- Secreto base: pepper. Sin pepper se aborta (enmascarar sin secreto es inseguro).
  -- ----------------------------------------------------------------------------
  -- Fija la campana activa; si cambia, invalida la clave/pepper cacheados.
  PROCEDURE set_ejecucion(p_ejecucion_id IN NUMBER) IS
  BEGIN
    IF NVL(g_ejecucion_id, -999999999) <> NVL(p_ejecucion_id, -999999999) THEN
      g_ejecucion_id := p_ejecucion_id;
      g_pepper       := NULL;   -- invalidar cache al cambiar de campana
      g_clave_aes    := NULL;
    END IF;
  END;

  FUNCTION f_get_pepper RETURN VARCHAR2 IS
    l_clave VARCHAR2(64);
  BEGIN
    IF g_pepper IS NULL THEN
      -- Pepper por campana: clave = 'PEPPER_MASK:'||ejecucion_id (aisla campanas
      -- concurrentes). Sin ejecucion fijada usa la clave legacy 'PEPPER_MASK'.
      l_clave := 'PEPPER_MASK' ||
                 CASE WHEN g_ejecucion_id IS NULL THEN '' ELSE ':'||TO_CHAR(g_ejecucion_id) END;
      SELECT valor INTO g_pepper FROM tdm_secreto WHERE clave = l_clave;
    END IF;
    RETURN g_pepper;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20210,
        'Pepper no registrado (clave='||l_clave||'). Abortado: enmascarar sin pepper es inseguro.');
  END;

  -- ----------------------------------------------------------------------------
  -- Clave AES-128 para FF1: primeros 16 bytes de SHA-1(pepper). Cacheada por sesion.
  -- ----------------------------------------------------------------------------
  FUNCTION f_clave_aes RETURN RAW IS
  BEGIN
    IF g_clave_aes IS NULL THEN
      g_clave_aes := UTL_RAW.SUBSTR(
                       DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW(f_get_pepper), DBMS_CRYPTO.HASH_SH1),
                       1, 16);
    END IF;
    RETURN g_clave_aes;
  END;

  -- ----------------------------------------------------------------------------
  -- Semilla determinista de 60 bits para dominios de TEXTO (nombre, direccion,
  -- email, telefono). HMAC-SHA1(pepper, texto). Sube de 31 a 60 bits la entropia
  -- de la semilla -> reduce drasticamente colisiones de texto a gran volumen.
  -- ----------------------------------------------------------------------------
  FUNCTION f_hash(p_txt VARCHAR2) RETURN NUMBER IS
    l_mac RAW(20);
  BEGIN
l_mac := DBMS_CRYPTO.MAC(
               UTL_I18N.STRING_TO_RAW(NVL(p_txt,'~NULL~'), 'AL32UTF8'),  -- M-03: UTF-8 fijo, no depende del NLS
               DBMS_CRYPTO.HMAC_SH1,
               UTL_RAW.CAST_TO_RAW(f_get_pepper));
    -- 14 hex = 56 bits: entra exacto en NUMBER y en las aritmeticas MOD posteriores
    RETURN TO_NUMBER(SUBSTR(RAWTOHEX(l_mac), 1, 14), 'XXXXXXXXXXXXXX');
  END;

  -- ============================================================================
  -- NUCLEO FF1 (NIST SP 800-38G) sobre radix 10
  -- ============================================================================

  -- Entero -> cadena hex big-endian de p_bytes bytes (relleno a la izquierda con 0).
  FUNCTION f_num_hex(p_num IN NUMBER, p_bytes IN PLS_INTEGER) RETURN VARCHAR2 IS
    l_n   NUMBER := NVL(p_num,0);
    l_hex VARCHAR2(64) := '';
  BEGIN
    FOR i IN 1 .. p_bytes LOOP
      l_hex := LPAD(TRIM(TO_CHAR(MOD(l_n,256),'XX')),2,'0') || l_hex;  -- prepende byte bajo
      l_n   := TRUNC(l_n/256);
    END LOOP;
    RETURN l_hex;
  END;

  -- Ajuste (tweak) por DOMINIO: 8 bytes de SHA-1('DOMINIO:'||identificador).
  -- Depende SOLO del identificador -> mismo dominio, mismo ajuste (invariante FK).
  FUNCTION f_ajuste_dominio(p_dominio IN VARCHAR2) RETURN RAW IS
  BEGIN
    RETURN UTL_RAW.SUBSTR(
             DBMS_CRYPTO.HASH(
               UTL_RAW.CAST_TO_RAW('DOMINIO:'||UPPER(NVL(TRIM(p_dominio),'GEN'))),
               DBMS_CRYPTO.HASH_SH1),
             1, 8);
  END;

  -- Cifra una cadena de p_digitos DIGITOS (radix 10) devolviendo otra de igual
  -- longitud. Implementa FF1.Encrypt (Algoritmo 7 del NIST SP 800-38G).
  FUNCTION f_ff1_cifrar_raw(p_digitos IN VARCHAR2, p_clave IN RAW, p_ajuste IN RAW) RETURN VARCHAR2 IS
    c_radix   CONSTANT PLS_INTEGER := 10;
    l_n       PLS_INTEGER := LENGTH(p_digitos);
    l_t       PLS_INTEGER := NVL(UTL_RAW.LENGTH(p_ajuste),0);
    l_u       PLS_INTEGER;
    l_v       PLS_INTEGER;
    l_a       VARCHAR2(64);
    l_b       VARCHAR2(64);
    l_bnum    PLS_INTEGER;      -- 'b': bytes para NUM_radix(B)
    l_d       PLS_INTEGER;      -- 'd': bytes de S
    l_hex_p   VARCHAR2(64);
    l_hex_q   VARCHAR2(512);
    l_pad     PLS_INTEGER;
    l_cifr    RAW(64);
    l_r       RAW(16);
    l_s       RAW(64);
    l_cont    PLS_INTEGER;
    l_m       PLS_INTEGER;
    l_mod_m   NUMBER;
    l_y       NUMBER;
    l_c       NUMBER;
    l_hex_s   VARCHAR2(160);
    l_byte    PLS_INTEGER;
  BEGIN
    -- FF1 no esta definido para dominios de 1 digito: se devuelve tal cual.
    IF l_n < 2 THEN RETURN p_digitos; END IF;

    -- Paso 1: partir en dos mitades A (izquierda) y B (derecha)
    l_u := TRUNC(l_n/2);
    l_v := l_n - l_u;
    l_a := SUBSTR(p_digitos, 1, l_u);
    l_b := SUBSTR(p_digitos, l_u+1);

    -- Paso 2: tamanos b y d (log2(10) = 3.32192809488736)
    l_bnum := CEIL(CEIL(l_v * 3.32192809488736) / 8);
    l_d    := 4*CEIL(l_bnum/4) + 4;

    -- Paso 3: bloque fijo P (16 bytes) = 01 02 01 | radix(3) | 0A | u(1) | n(4) | t(4)
    l_hex_p := '010201'
             || f_num_hex(c_radix, 3)
             || '0A'
             || f_num_hex(MOD(l_u,256), 1)
             || f_num_hex(l_n, 4)
             || f_num_hex(l_t, 4);

    -- Paso 4: 10 rondas Feistel de FF1
    FOR i IN 0 .. 9 LOOP
      -- 4a: bloque variable Q = ajuste | ceros(pad) | ronda(1) | NUM_radix(B) en b bytes
      l_pad   := MOD(16 - MOD(l_t + l_bnum + 1, 16), 16);
      l_hex_q := NVL(RAWTOHEX(p_ajuste),'')
               || CASE WHEN l_pad > 0 THEN RPAD('0', l_pad*2, '0') END  -- ceros; '' -> NULL en RPAD
               || f_num_hex(i, 1)
               || f_num_hex(TO_NUMBER(l_b), l_bnum);

      -- 4b: PRF = CBC-MAC AES-128 sobre P||Q con IV=0 -> ultimo bloque de 16 bytes
      l_cifr := DBMS_CRYPTO.ENCRYPT(
                  HEXTORAW(l_hex_p||l_hex_q),
                  DBMS_CRYPTO.ENCRYPT_AES128 + DBMS_CRYPTO.CHAIN_CBC + DBMS_CRYPTO.PAD_NONE,
                  p_clave, c_iv_cero);
      l_r := UTL_RAW.SUBSTR(l_cifr, UTL_RAW.LENGTH(l_cifr)-15, 16);

      -- 4c: expandir a d bytes (solo si d>16; en estos dominios d<=16 y no entra al bucle)
      l_s    := l_r;
      l_cont := 1;
      WHILE UTL_RAW.LENGTH(l_s) < l_d LOOP
        l_s := UTL_RAW.CONCAT(
                 l_s,
                 DBMS_CRYPTO.ENCRYPT(
                   UTL_RAW.BIT_XOR(l_r, HEXTORAW(f_num_hex(l_cont,16))),
                   DBMS_CRYPTO.ENCRYPT_AES128 + DBMS_CRYPTO.CHAIN_ECB + DBMS_CRYPTO.PAD_NONE,
                   p_clave, c_iv_cero));
        l_cont := l_cont + 1;
      END LOOP;
      l_hex_s := SUBSTR(RAWTOHEX(l_s), 1, l_d*2);

      -- 4d: y = NUM(S) mod 10^m por metodo de Horner (exacto en NUMBER, sin desbordar)
      l_m     := CASE WHEN MOD(i,2)=0 THEN l_u ELSE l_v END;
      l_mod_m := POWER(10, l_m);
      l_y     := 0;
      FOR k IN 1 .. l_d LOOP
        l_byte := TO_NUMBER(SUBSTR(l_hex_s,(k-1)*2+1,2),'XX');
        l_y    := MOD(l_y*256 + l_byte, l_mod_m);
      END LOOP;

      -- 4e: c = (NUM(A) + y) mod 10^m ; C = c en m digitos ; intercambio A<-B, B<-C
      l_c := MOD(TO_NUMBER(l_a) + l_y, l_mod_m);
      l_a := l_b;
      l_b := LPAD(TO_CHAR(l_c), l_m, '0');
    END LOOP;

    -- Paso 5: resultado = A || B
    RETURN l_a || l_b;
  END;

  -- Cifrado FPE numerico de proposito general con cycle-walking.
  -- Si p_modulo = 10^n (dominio potencia de 10) FF1 acierta a la primera.
  -- Si no, camina hasta caer en [0, p_modulo) conservando la biyeccion.
  -- Wrapper de PRODUCCION: cifra con la clave AES derivada del pepper de la campana.
  FUNCTION f_ff1_cifra(p_digitos IN VARCHAR2, p_ajuste IN RAW) RETURN VARCHAR2 IS
  BEGIN
    RETURN f_ff1_cifrar_raw(p_digitos, f_clave_aes, p_ajuste);
  END;

  FUNCTION f_fpe_num(p_valor IN NUMBER, p_modulo IN NUMBER, p_ajuste IN RAW) RETURN NUMBER IS
    l_n PLS_INTEGER;
    l_x NUMBER;
  BEGIN
    IF p_valor IS NULL OR p_modulo IS NULL OR p_modulo <= 1 THEN
      RETURN p_valor;
    END IF;
    l_n := LENGTH(TO_CHAR(p_modulo - 1));          -- digitos para representar [0, modulo)
    l_x := MOD(ABS(p_valor), p_modulo);            -- normalizar al rango
    IF l_n < 2 THEN RETURN l_x; END IF;            -- dominio < 2 digitos: no aplica FF1

    LOOP
      l_x := TO_NUMBER(f_ff1_cifra(LPAD(TO_CHAR(l_x), l_n, '0'), p_ajuste));
      EXIT WHEN l_x < p_modulo;                    -- cycle-walking sobre [0, modulo)
    END LOOP;
    RETURN l_x;
  END;

  -- ============================================================================
  -- HELPERS DE TEXTO
  -- ============================================================================
  FUNCTION f_txt_seguro(p_txt VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    IF p_txt IS NULL THEN RETURN NULL; END IF;
    -- Semantica de caracteres: evita cortar un multibyte (fuente de ORA-06502)
    RETURN SUBSTR(p_txt, 1, c_max_txt);
  END;

  FUNCTION f_mix_alpha(p_txt VARCHAR2, p_seed NUMBER) RETURN VARCHAR2 IS
    l_txt  VARCHAR2(32767) := f_txt_seguro(p_txt);
    l_seed NUMBER := p_seed;
    l_out  VARCHAR2(32767) := '';
    l_ch   VARCHAR2(32 CHAR);
  BEGIN
    IF l_txt IS NULL THEN RETURN NULL; END IF;
    FOR i IN 1 .. LENGTH(l_txt) LOOP
      l_ch := SUBSTR(l_txt,i,1);
      IF REGEXP_LIKE(l_ch,'[[:alpha:]]') THEN
        l_seed := MOD(l_seed*131+17, 4294967291);
        l_out  := l_out || CHR(65 + MOD(l_seed,26));
      ELSE
        l_out  := l_out || l_ch;
      END IF;
    END LOOP;
    RETURN SUBSTR(l_out, 1, c_max_txt);
  END;

  -- ============================================================================
  -- FUNCIONES DE FORMATO (dominios de TEXTO: no biyectivas por naturaleza)
  -- ============================================================================
  FUNCTION func_nombre(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_txt VARCHAR2(32767);
  BEGIN
    IF p_valor IS NULL THEN RETURN NULL; END IF;
    l_txt := f_txt_seguro(p_valor);
    RETURN f_mix_alpha(l_txt, f_hash('NOMBRE|'||UPPER(l_txt)));
  END;

  FUNCTION func_direccion(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_txt  VARCHAR2(32767);
    l_seed NUMBER;
    l_tipo VARCHAR2(20);
    l_nom  VARCHAR2(30);
    l_num  NUMBER;
    l_city VARCHAR2(30);
    l_out  VARCHAR2(32767);
  BEGIN
    IF p_valor IS NULL THEN RETURN NULL; END IF;
    l_txt  := f_txt_seguro(p_valor);
    l_seed := f_hash('DIR|'||UPPER(l_txt));
    l_tipo := CASE MOD(l_seed,4) WHEN 0 THEN 'Calle' WHEN 1 THEN 'Avenida' WHEN 2 THEN 'Plaza' ELSE 'Camino' END;
    l_nom  := CASE MOD(TRUNC(l_seed/4),8)
                WHEN 0 THEN 'Ficticia' WHEN 1 THEN 'Mayor' WHEN 2 THEN 'Real' WHEN 3 THEN 'Sol'
                WHEN 4 THEN 'Luna' WHEN 5 THEN 'Paz' WHEN 6 THEN 'Olivo' ELSE 'Ribera' END;
    l_num  := MOD(TRUNC(l_seed/17), 999) + 1;
    l_city := CASE MOD(TRUNC(l_seed/11),8)
                WHEN 0 THEN 'Madrid' WHEN 1 THEN 'Barcelona' WHEN 2 THEN 'Valencia' WHEN 3 THEN 'Sevilla'
                WHEN 4 THEN 'Zaragoza' WHEN 5 THEN 'Bilbao' WHEN 6 THEN 'Malaga' ELSE 'Valladolid' END;
    l_out := l_tipo||' '||l_nom||' N '||TO_CHAR(l_num)||', '||l_city;
    RETURN SUBSTR(l_out, 1, c_max_txt);
  END;

  FUNCTION func_obs(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    IF p_valor IS NULL THEN RETURN NULL; END IF;
    RETURN '***OBSERVACION ENMASCARADA***';
  END;

  FUNCTION func_telefono(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_seed NUMBER;
    l_pref VARCHAR2(1);
    l_num  VARCHAR2(9);
  BEGIN
    IF p_valor IS NULL THEN RETURN NULL; END IF;
    l_seed := f_hash(REGEXP_REPLACE(p_valor,'[^0-9]',''));
    l_pref := SUBSTR('6789', MOD(l_seed,4)+1, 1);
    l_num  := l_pref || LPAD(TO_CHAR(MOD(l_seed*97+13, 100000000)), 8, '0');
    RETURN l_num;
  END;

  FUNCTION func_email(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_txt   VARCHAR2(32767);
    l_seed  NUMBER;
    l_local VARCHAR2(64) := '';
    l_dom   VARCHAR2(20);
    l_out   VARCHAR2(200);
  BEGIN
    IF p_valor IS NULL THEN RETURN NULL; END IF;
    l_txt  := LOWER(TRIM(f_txt_seguro(p_valor)));
    l_seed := f_hash(l_txt);
    FOR i IN 1 .. 10 LOOP
      l_seed  := MOD(l_seed*131+17, 4294967291);
      l_local := l_local || CHR(97 + MOD(l_seed,26));
    END LOOP;
    l_dom := CASE WHEN MOD(l_seed,2)=0 THEN 'correo.com' ELSE 'correo.es' END;
    l_out := l_local || TO_CHAR(MOD(l_seed*31+7,999)) || '@' || l_dom;
    RETURN l_out;
  END;

  -- ============================================================================
  -- FUNCIONES DE FORMATO (dominios NUMERICOS: biyectivos via FF1)
  -- ============================================================================

  -- Letra de control del DNI/NIE (algoritmo oficial modulo 23).
  FUNCTION f_letra_dni(p_num NUMBER) RETURN CHAR IS
    l_tab CONSTANT VARCHAR2(23) := 'TRWAGMYFPDXBNJZSQVHLCKE';
  BEGIN
    RETURN SUBSTR(l_tab, MOD(p_num,23)+1, 1);
  END;

  -- Digito/letra de control del CIF (segun tipo de organizacion).
  FUNCTION f_cif_ctrl(p_tipo CHAR, p_num7 VARCHAR2) RETURN CHAR IS
    s_par NUMBER := 0; s_imp NUMBER := 0; d NUMBER; x NUMBER; c NUMBER;
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

  -- NIF / DNI / NIE / CIF. La parte numerica se cifra con FF1 (biyectivo);
  -- la letra/digito de control se recalcula sobre el numero ya enmascarado.
  -- Enmascara un NIE de forma DETERMINISTA y COHERENTE entre rutas: el prefijo
  -- X/Y/Z se deriva del numero generado (no de la entrada), asi el mismo NIE da
  -- igual resultado por func_nif y por func_especial_doc_segun_tipo.
  FUNCTION f_enmascara_nie(p_num_original IN NUMBER, p_ajuste IN RAW) RETURN VARCHAR2 IS
    l_num7      VARCHAR2(7);
    l_idx_pref  PLS_INTEGER;
    l_prefijo   CHAR(1);
  BEGIN
    l_num7     := LPAD(TO_CHAR(f_fpe_num(p_num_original, 10000000, p_ajuste)), 7, '0');
    l_idx_pref := MOD(TO_NUMBER(SUBSTR(l_num7,1,1)), 3);       -- 0->X, 1->Y, 2->Z
    l_prefijo  := SUBSTR('XYZ', l_idx_pref+1, 1);
    RETURN l_prefijo || l_num7 || f_letra_dni(TO_NUMBER(TO_CHAR(l_idx_pref) || l_num7));
  END;

  -- Sustituye cada DIGITO de un texto por otro (FF1 conjunto sobre los digitos)
  -- manteniendo intactos los caracteres no numericos. Uso: Pasaporte.
  FUNCTION f_cifra_digitos_en_texto(p_texto IN VARCHAR2, p_ajuste IN RAW) RETURN VARCHAR2 IS
    l_solo_digitos VARCHAR2(200);
    l_cifrados     VARCHAR2(200);
    l_resultado    VARCHAR2(4000) := '';
    l_pos_digito   PLS_INTEGER := 1;
    l_caracter     VARCHAR2(1 CHAR);
  BEGIN
    IF p_texto IS NULL THEN RETURN NULL; END IF;
    l_solo_digitos := REGEXP_REPLACE(p_texto, '[^0-9]', '');
    IF LENGTH(l_solo_digitos) >= 2 THEN
      l_cifrados := LPAD(f_ff1_cifra(l_solo_digitos, p_ajuste), LENGTH(l_solo_digitos), '0');
    ELSE
      l_cifrados := l_solo_digitos;                            -- 0 o 1 digito: FF1 no aplica
    END IF;
    FOR i IN 1 .. LENGTH(p_texto) LOOP
      l_caracter := SUBSTR(p_texto, i, 1);
      IF l_caracter BETWEEN '0' AND '9' THEN
        l_resultado  := l_resultado || SUBSTR(l_cifrados, l_pos_digito, 1);
        l_pos_digito := l_pos_digito + 1;
      ELSE
        l_resultado  := l_resultado || l_caracter;
      END IF;
    END LOOP;
    RETURN l_resultado;
  END;

  FUNCTION func_nif(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_val   VARCHAR2(50) := UPPER(TRIM(SUBSTR(p_valor,1,50)));
    l_seed  NUMBER;
    l_out   VARCHAR2(20);
    l_num8  VARCHAR2(8);
    l_num7  VARCHAR2(7);
    l_tipo  CHAR(1);
    l_set   CONSTANT VARCHAR2(20) := 'ABCDEFGHJKLMNPQRSUVW';
    l_ajuste RAW(8) := f_ajuste_dominio('IDENTIDAD');   -- mismo dominio para todo documento
    l_new   NUMBER;
  BEGIN
    IF l_val IS NULL THEN RETURN NULL; END IF;

    -- DNI: 8 digitos + letra
    IF REGEXP_LIKE(l_val,'^[0-9]{8}[A-Z]$') THEN
      l_new  := f_fpe_num(TO_NUMBER(SUBSTR(l_val,1,8)), 100000000, l_ajuste);
      l_num8 := LPAD(TO_CHAR(l_new), 8, '0');
      l_out  := l_num8 || f_letra_dni(l_new);

    -- NIE: prefijo derivado del numero generado (coherente con doc_segun_tipo)
    ELSIF REGEXP_LIKE(l_val,'^[XYZ][0-9]{7}[A-Z]$') THEN
      l_out := f_enmascara_nie(TO_NUMBER(SUBSTR(l_val,2,7)), l_ajuste);

    -- CIF: letra + 7 digitos + control (ahora tambien biyectivo via FF1)
    ELSE
      l_tipo := SUBSTR(l_val,1,1);
      IF INSTR(l_set,l_tipo) > 0 AND REGEXP_LIKE(SUBSTR(l_val,2),'^[0-9]{7}[A-Z0-9]$') THEN
        l_new  := f_fpe_num(TO_NUMBER(SUBSTR(l_val,2,7)), 10000000, l_ajuste);
        l_num7 := LPAD(TO_CHAR(l_new), 7, '0');
        l_out  := l_tipo || l_num7 || f_cif_ctrl(l_tipo, l_num7);
      ELSE
        -- Formato no reconocido (p.ej. Pasaporte): cifra los digitos manteniendo
        -- letras y separadores. Biyectivo por (longitud, patron no numerico).
        RETURN f_cifra_digitos_en_texto(l_val, l_ajuste);
      END IF;
    END IF;

    RETURN l_out;
  END;

  -- Cuenta bancaria (no IBAN): parte numerica cifrada con FF1, longitud conservada.
  FUNCTION func_cuenta(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_out        VARCHAR2(20);
    l_digitos    VARCHAR2(200);
    l_in_len     NUMBER;
    l_target_len NUMBER;
    l_ajuste     RAW(8) := f_ajuste_dominio('CUENTA');
    l_new        NUMBER;
  BEGIN
    IF p_valor IS NULL THEN RETURN NULL; END IF;
    l_digitos := REGEXP_REPLACE(SUBSTR(p_valor,1,200),'[^0-9]','');
    l_in_len  := LENGTH(l_digitos);
    IF NVL(l_in_len,0) = 0 THEN
      RETURN p_valor;                          -- sin digitos: nada que cifrar
    END IF;
    l_target_len := LEAST(GREATEST(l_in_len, 4), 20);
    -- Acotar a target_len (<=20) para que TO_NUMBER NUNCA desborde: FF1 siempre
    -- aplica y es biyectivo. Sin fallback a hash (que rompia la biyeccion).
    l_new := f_fpe_num(
               TO_NUMBER(SUBSTR(l_digitos, GREATEST(l_in_len - l_target_len + 1, 1))),
               POWER(10, l_target_len),
               l_ajuste);
    l_out := LPAD(TO_CHAR(l_new), l_target_len, '0');
    RETURN l_out;
  END;

  -- Digito de control (modulo 97) de un IBAN espanol para un BBAN de 20 digitos.
  FUNCTION f_iban_cc_es(p_bban20 VARCHAR2) RETURN VARCHAR2 IS
    l_txt  VARCHAR2(200) := p_bban20 || '142800';   -- 'ES'->1428, '00' pendiente
    l_rem  NUMBER := 0;
    l_part VARCHAR2(20);
  BEGIN
    FOR i IN 1 .. CEIL(LENGTH(l_txt)/7) LOOP
      l_part := TO_CHAR(l_rem) || SUBSTR(l_txt,(i-1)*7+1,7);
      l_rem  := MOD(TO_NUMBER(l_part),97);
    END LOOP;
    RETURN LPAD(TO_CHAR(98-l_rem),2,'0');
  END;

  -- IBAN espanol: BBAN (20 digitos) cifrado con FF1 y control recalculado.
  FUNCTION func_iban(p_valor VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_val    VARCHAR2(100);
    l_bban   VARCHAR2(20);
    l_cc     VARCHAR2(2);
    l_out    VARCHAR2(24);
    l_ajuste RAW(8) := f_ajuste_dominio('IBAN');
    l_seed   NUMBER;
    l_new    NUMBER;
  BEGIN
    IF p_valor IS NULL THEN RETURN NULL; END IF;

    l_val := REPLACE(UPPER(TRIM(SUBSTR(p_valor,1,50))), ' ', '');
    IF REGEXP_LIKE(l_val, '^ES[0-9]{22}$') THEN
      l_new  := f_fpe_num(TO_NUMBER(SUBSTR(l_val,5,20)), 100000000000000000000, l_ajuste);
      l_bban := LPAD(TO_CHAR(l_new), 20, '0');
      l_cc   := f_iban_cc_es(l_bban);
      l_out  := 'ES'||l_cc||l_bban;
    ELSE
      -- Formato no estandar: semilla + control (poco frecuente)
      l_seed := f_hash('IBAN|'||UPPER(TRIM(SUBSTR(p_valor,1,50))));
      l_bban := LPAD(TO_CHAR(MOD(l_seed*137+31, 100000000000000000000)), 20, '0');
      l_cc   := f_iban_cc_es(l_bban);
      l_out  := 'ES'||l_cc||l_bban;   -- 24 chars exactos, sin truncar (C-01)
    END IF;
    RETURN l_out;
  END;

  -- ============================================================================
  -- REGLAS ESPECIALES (capa semantica para el orquestador)
  -- ============================================================================

  -- Documento manteniendo primer y ultimo caracter. Si el interior es todo
  -- digitos, se cifra con FF1 (biyectivo dentro de misma longitud+extremos);
  -- si mezcla letras, se usa la mezcla determinista por semilla.
  FUNCTION func_especial_doc_keep_ends(p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_val    VARCHAR2(4000) := UPPER(TRIM(p_valor));
    l_len    PLS_INTEGER;
    l_medio  VARCHAR2(4000);
    l_seed   NUMBER;
    l_ch     VARCHAR2(4 CHAR);
    l_out    VARCHAR2(4000) := '';
    l_ajuste RAW(8) := f_ajuste_dominio('IDENTIDAD');
  BEGIN
    IF l_val IS NULL THEN RETURN NULL; END IF;
    l_len := LENGTH(l_val);
    IF l_len <= 2 THEN RETURN l_val; END IF;

    l_medio := SUBSTR(l_val, 2, l_len-2);

    -- Interior 100% numerico -> FF1 (colision imposible para igual extremos+longitud)
    IF REGEXP_LIKE(l_medio, '^[0-9]+$') THEN
      l_out := LPAD(f_ff1_cifra(l_medio, l_ajuste), LENGTH(l_medio), '0');
      RETURN SUBSTR(l_val,1,1) || l_out || SUBSTR(l_val,-1,1);
    END IF;

    -- Interior mixto -> mezcla determinista por semilla (no biyectivo)
    l_seed := f_hash('DOC_KEEP_ENDS|'||l_val);
    FOR i IN 1 .. LENGTH(l_medio) LOOP
      l_ch := SUBSTR(l_medio,i,1);
      IF REGEXP_LIKE(l_ch,'[0-9]') THEN
        l_seed := MOD(l_seed*29+7, 4294967291);
        l_out  := l_out || TO_CHAR(MOD(l_seed,10));
      ELSIF REGEXP_LIKE(l_ch,'[[:alpha:]]') THEN
        l_seed := MOD(l_seed*131+17, 4294967291);
        l_out  := l_out || CHR(65 + MOD(l_seed,26));
      ELSE
        l_out := l_out || l_ch;
      END IF;
    END LOOP;
    RETURN SUBSTR(l_val,1,1) || l_out || SUBSTR(l_val,-1,1);
  END;

  -- Documento segun tipo (1=DNI, 3=NIE). Parte numerica biyectiva via FF1 y
  -- MISMO ajuste 'IDENTIDAD' que func_nif -> un mismo DNI enmascara igual por
  -- ambas rutas (coherencia padre/hija aunque usen reglas distintas).
  FUNCTION func_especial_doc_segun_tipo(
    p_documento       IN VARCHAR2,
    p_idtipodocumento IN NUMBER
  ) RETURN VARCHAR2 DETERMINISTIC IS
    l_val      VARCHAR2(4000) := UPPER(TRIM(p_documento));
    l_ajuste   RAW(8) := f_ajuste_dominio('IDENTIDAD');
    l_digitos  VARCHAR2(200);
    l_new      NUMBER;
    l_num8     VARCHAR2(8);
  BEGIN
    IF l_val IS NULL THEN RETURN NULL; END IF;
    l_digitos := REGEXP_REPLACE(l_val,'[^0-9]','');

    IF p_idtipodocumento = 1 AND l_digitos IS NOT NULL THEN    -- DNI
      l_new  := f_fpe_num(TO_NUMBER(l_digitos), 100000000, l_ajuste);
      l_num8 := LPAD(TO_CHAR(l_new), 8, '0');
      RETURN l_num8 || f_letra_dni(l_new);

    ELSIF p_idtipodocumento = 3 AND l_digitos IS NOT NULL THEN -- NIE (misma logica que func_nif)
      RETURN f_enmascara_nie(TO_NUMBER(l_digitos), l_ajuste);

    ELSE                                                       -- Pasaporte (o sin digitos)
      RETURN f_cifra_digitos_en_texto(l_val, l_ajuste);
    END IF;
  END;

  -- IBAN "continuo" (sin separadores, 24 caracteres): BBAN cifrado con FF1 y
  -- control modulo 97. NUNCA se trunca (C-01): siempre devuelve ES + cc + 20.
  FUNCTION func_especial_iban_continuo(p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    l_digitos VARCHAR2(20);
    l_bban    VARCHAR2(20);
    l_txt     VARCHAR2(200);
    l_rem     NUMBER := 0;
    l_part    VARCHAR2(20);
    l_cc      VARCHAR2(2);
    l_out     VARCHAR2(24);
    l_ajuste  RAW(8) := f_ajuste_dominio('IBAN');
    l_solonum VARCHAR2(50);
  BEGIN
    IF p_valor IS NULL THEN RETURN NULL; END IF;

    -- Toma hasta 20 digitos del origen y los cifra con FF1 (biyectivo)
    l_solonum := REGEXP_REPLACE(UPPER(TRIM(p_valor)),'[^0-9]','');
    l_digitos := LPAD(SUBSTR(l_solonum,1,20), 20, '0');
    l_bban    := LPAD(f_ff1_cifra(l_digitos, l_ajuste), 20, '0');

    l_txt := l_bban || '142800';
    FOR i IN 1 .. CEIL(LENGTH(l_txt)/7) LOOP
      l_part := TO_CHAR(l_rem) || SUBSTR(l_txt,(i-1)*7+1,7);
      l_rem  := MOD(TO_NUMBER(l_part),97);
    END LOOP;
    l_cc  := LPAD(TO_CHAR(98-l_rem),2,'0');
    l_out := 'ES'||l_cc||l_bban;   -- 24 caracteres exactos, sin truncar
    RETURN l_out;
  END;

  -- ============================================================================
  -- RESOLUTOR GENERICO (enruta por identificador semantico)
  -- ============================================================================
  FUNCTION func_generico(
    p_identificador IN VARCHAR2,
    p_valor         IN VARCHAR2
  ) RETURN VARCHAR2 DETERMINISTIC IS
    l_id VARCHAR2(100) := UPPER(NVL(TRIM(p_identificador),''));
  BEGIN
    IF p_valor IS NULL THEN RETURN NULL; END IF;

    CASE l_id
      WHEN 'IDENTIFICADOR_PERSONAL'    THEN RETURN func_nombre(p_valor);
      WHEN 'IDENTIFICADOR_NOMBRE'      THEN RETURN func_nombre(p_valor);
      WHEN 'IDENTIFICADOR_APELLIDO'    THEN RETURN func_nombre(p_valor);
      WHEN 'IDENTIFICADOR_APE1'        THEN RETURN func_nombre(p_valor);
      WHEN 'IDENTIFICADOR_APE2'        THEN RETURN func_nombre(p_valor);
      WHEN 'IDENTIFICADOR_DIRECCION'   THEN RETURN func_direccion(p_valor);
      WHEN 'IDENTIFICADOR_DOMICILIO'   THEN RETURN func_direccion(p_valor);
      WHEN 'IDENTIFICADOR_OBSERVACION' THEN RETURN func_obs(p_valor);
      WHEN 'IDENTIFICADOR_OBS'         THEN RETURN func_obs(p_valor);
      WHEN 'IDENTIFICADOR_TELEFONO'    THEN RETURN func_telefono(p_valor);
      WHEN 'IDENTIFICADOR_MOVIL'       THEN RETURN func_telefono(p_valor);
      WHEN 'IDENTIFICADOR_EMAIL'       THEN RETURN func_email(p_valor);
      WHEN 'IDENTIFICADOR_IDENTIDAD'   THEN RETURN func_nif(p_valor);
      WHEN 'IDENTIFICADOR_DOCUMENTO'   THEN RETURN func_nif(p_valor);
      WHEN 'IDENTIFICADOR_BANCARIO'    THEN
        IF REGEXP_LIKE(UPPER(TRIM(SUBSTR(p_valor,1,50))), '^ES[0-9]{22}$') THEN
          RETURN func_iban(p_valor);
        ELSE
          RETURN func_cuenta(p_valor);
        END IF;
      ELSE
        -- Enrutado por palabras clave si el identificador no es exacto
        IF    INSTR(l_id,'NOMBRE')>0 OR INSTR(l_id,'PERSON')>0 OR INSTR(l_id,'APELL')>0
           OR INSTR(l_id,'APE1')>0   OR INSTR(l_id,'APE2')>0 THEN
          RETURN func_nombre(p_valor);
        ELSIF INSTR(l_id,'DIREC')>0 OR INSTR(l_id,'DOMIC')>0 OR INSTR(l_id,'VIA')>0 THEN
          RETURN func_direccion(p_valor);
        ELSIF INSTR(l_id,'EMAIL')>0 OR INSTR(l_id,'MAIL')>0 THEN
          RETURN func_email(p_valor);
        ELSIF INSTR(l_id,'TELEF')>0 OR INSTR(l_id,'MOVIL')>0 THEN
          RETURN func_telefono(p_valor);
        ELSIF INSTR(l_id,'NIF')>0 OR INSTR(l_id,'NIE')>0 OR INSTR(l_id,'DOC')>0 OR INSTR(l_id,'IDENT')>0 THEN
          RETURN func_nif(p_valor);
        ELSIF INSTR(l_id,'IBAN')>0 OR INSTR(l_id,'CUENTA')>0 OR INSTR(l_id,'BANC')>0 THEN
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
