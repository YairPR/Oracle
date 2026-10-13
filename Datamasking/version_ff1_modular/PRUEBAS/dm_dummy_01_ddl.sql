Rem =============================================================================
Rem dm_dummy_01_ddl.sql -- ESQUEMA DE PRUEBA DM_DUMMY (DDL UNICO)
Rem
Rem Sustituye a los tres archivos anteriores:
Rem   tests/01_poc_esquema_dummy_ddl.sql
Rem   tests/03_poc_esquema_dummy_cierre_ddl.sql
Rem   (la parte de esquema de poc_esquema_dummy_volumen_dml.sql)
Rem
Rem QUE HACE
Rem   1) PREFLIGHT (no toca nada si falla): exige que exista el tablespace
Rem      DM_DUMMY (mismo nombre que el esquema), permanente y ONLINE, y que
Rem      exista el esquema del motor (ASTSYSADMIN o ACC_ADMIN).
Rem   2) Borra DM_DUMMY si existe (DROP USER CASCADE) y lo crea de nuevo con
Rem      DEFAULT TABLESPACE DM_DUMMY (ninguna tabla lleva clausula TABLESPACE).
Rem   3) Crea las 35 tablas, las 12 FK, los 3 indices de apoyo a FK, 2 indices unicos y el
Rem      trigger TRG_SUCURSAL_RIESGO_UPD. Sin secuencias: la carga asigna los
Rem      identificadores por indice de bucle (ver dm_dummy_02_dml.sql).
Rem   4) Concede SELECT, UPDATE sobre TODAS las tablas de DM_DUMMY al esquema
Rem      del motor, detectado en la base (ASTSYSADMIN y, si no existe,
Rem      ACC_ADMIN). Sin lineas GRANT por tabla ni variables de sustitucion.
Rem   5) Valida: 35 tablas, 12 FK, objetos validos.
Rem
Rem COMO SE EJECUTA
Rem   Conectado como un DBA (SYS, SYSTEM o equivalente), SIN argumentos:
Rem       @dm_dummy_01_ddl
Rem   Despues, la carga:
Rem       @dm_dummy_02_dml 2        (volumen en millones de filas, 0.5 a 60)
Rem
Rem Solo para entornos de PRUEBA. Destruye DM_DUMMY y todo su contenido.
Rem La cuenta DM_DUMMY se crea BLOQUEADA (es solo un contenedor de datos: la
Rem carga y el motor trabajan sin conectarse como ella). Si hiciera falta:
Rem   alter user DM_DUMMY account unlock;
Rem =============================================================================
set serveroutput on size unlimited
set verify off
set feedback on
set define off
set linesize 200
set pagesize 100
set trimspool on
whenever sqlerror exit failure rollback
whenever oserror exit failure rollback

prompt =========================================================================
prompt 1) PREFLIGHT: tablespace DM_DUMMY y esquema del motor
prompt =========================================================================
declare
  l_ts     dba_tablespaces%rowtype;
  l_motor  varchar2(128);
begin
  begin
    select * into l_ts from dba_tablespaces where tablespace_name = 'DM_DUMMY';
  exception
    when no_data_found then
      raise_application_error(-20001,
        'No existe el tablespace DM_DUMMY. Crealo antes (mismo nombre que el esquema) y vuelve a ejecutar. No se ha tocado nada.');
  end;
  if l_ts.contents <> 'PERMANENT' or l_ts.status <> 'ONLINE' then
    raise_application_error(-20002,
      'El tablespace DM_DUMMY debe ser PERMANENT y estar ONLINE (contents=' || l_ts.contents || ', status=' || l_ts.status || '). No se ha tocado nada.');
  end if;
  begin
    select username into l_motor
      from (select username from dba_users
             where username in ('ASTSYSADMIN','ACC_ADMIN')
             order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
     where rownum = 1;
  exception
    when no_data_found then
      raise_application_error(-20003,
        'No se encontro ni ASTSYSADMIN ni ACC_ADMIN en DBA_USERS: no hay esquema del motor al que conceder acceso. No se ha tocado nada.');
  end;
  dbms_output.put_line('Tablespace DM_DUMMY ........ OK (' || l_ts.contents || ', ' || l_ts.status || ')');
  dbms_output.put_line('Esquema del motor .......... ' || l_motor);
end;
/

prompt =========================================================================
prompt 2) ESQUEMA DM_DUMMY (se recrea desde cero)
prompt =========================================================================
declare
  l_n number;
begin
  select count(*) into l_n from dba_users where username = 'DM_DUMMY';
  if l_n > 0 then
    execute immediate 'DROP USER DM_DUMMY CASCADE';
    dbms_output.put_line('DM_DUMMY existia: eliminado con CASCADE.');
  end if;
end;
/

CREATE USER DM_DUMMY IDENTIFIED BY "DummyApp2026#"
  DEFAULT TABLESPACE DM_DUMMY
  QUOTA UNLIMITED ON DM_DUMMY
  ACCOUNT LOCK;

GRANT CREATE SESSION, CREATE TABLE, CREATE TRIGGER TO DM_DUMMY;

prompt =========================================================================
prompt 3A) BLOQUE CORRECTITUD (10 tablas, 110 filas cada una): reglas de
prompt     descubrimiento sobre datos limpios y senuelos
prompt =========================================================================
-- Convencion de las marcas de columna:
--   MASK    = dato personal real: el motor debe marcarla enmascarar=Y
--   NO      = senuelo o dato no personal: NO debe quedar en Y
--   FORCE   = dato real con nombre neutro: requiere excepcion FORCE
--   (el detalle y el identificador esperado estan en README_DM_DUMMY.md)

CREATE TABLE DM_DUMMY.tbl_personas (
    dni                VARCHAR2(20)  NOT NULL,  -- MASK identidad (raiz del dominio de identidad)
    nombre             VARCHAR2(100) NOT NULL,  -- MASK nombre
    apellidos          VARCHAR2(150) NOT NULL,  -- MASK nombre
    direccion          VARCHAR2(200),           -- MASK direccion
    fecha_nacimiento   DATE,                    -- NO   fecha
    telefono           VARCHAR2(20),            -- MASK telefono
    email              VARCHAR2(150),           -- MASK email
    iban               VARCHAR2(30),            -- MASK bancario (IBAN)
    cuenta_ccc         VARCHAR2(30),            -- MASK bancario (CCC)
    nie_cif            VARCHAR2(20),            -- MASK identidad (NIE y CIF mezclados)
    doc_mixto          VARCHAR2(20),            -- MASK identidad (DNI, NIE y CIF fila a fila; solo lo delata el dato)
    cod_dni_falso      VARCHAR2(20),            -- NO   senuelo: nombre de DNI, dato correlativo sin digito de control
    correo_interno     VARCHAR2(50),            -- NO   senuelo: nombre de correo, dato sin arroba
    telefono_ficticio  VARCHAR2(20),            -- NO   senuelo: nombre de telefono, dato no numerico
    referencia_cliente VARCHAR2(20),            -- FORCE nombre neutro, valor = DNI real
    usuario_ad         VARCHAR2(50),            -- NO   login tecnico
    CONSTRAINT pk_tbl_personas PRIMARY KEY (dni)
);

CREATE TABLE DM_DUMMY.tbl_clientes (
    cliente_id   NUMBER        NOT NULL,
    dni_ref      VARCHAR2(20)  NOT NULL,        -- MASK identidad por FK -> personas.dni
    tipo_cliente VARCHAR2(50)  DEFAULT 'ESTANDAR',  -- NO enum
    fecha_alta   DATE,                          -- NO
    score_riesgo NUMBER(5,2),                   -- NO
    CONSTRAINT pk_tbl_clientes PRIMARY KEY (cliente_id),
    CONSTRAINT fk_cli_persona FOREIGN KEY (dni_ref) REFERENCES DM_DUMMY.tbl_personas(dni)
);

CREATE TABLE DM_DUMMY.tbl_empleados (
    empleado_id  NUMBER        NOT NULL,        -- NO   clave subrogada (ancla de la cadena nomina/beneficiarios)
    dni_emp      VARCHAR2(20)  NOT NULL,        -- MASK identidad por FK -> personas.dni
    cargo        VARCHAR2(100) NOT NULL,        -- NO
    salario      NUMBER(10,2),                  -- NO
    usuario_ad   VARCHAR2(50),                  -- NO   mismo senuelo que en personas
    CONSTRAINT pk_tbl_empleados PRIMARY KEY (empleado_id),
    CONSTRAINT fk_emp_persona FOREIGN KEY (dni_emp) REFERENCES DM_DUMMY.tbl_personas(dni)
);

CREATE TABLE DM_DUMMY.tbl_direcciones (
    direccion_id   NUMBER        NOT NULL,
    dni_titular    VARCHAR2(20)  NOT NULL,      -- MASK identidad por FK -> personas.dni
    calle_completa VARCHAR2(200),               -- MASK direccion
    codigo_postal  VARCHAR2(10),                -- NO
    tipo_vivienda  VARCHAR2(30),                -- NO
    CONSTRAINT pk_tbl_direcciones PRIMARY KEY (direccion_id),
    CONSTRAINT fk_dir_persona FOREIGN KEY (dni_titular) REFERENCES DM_DUMMY.tbl_personas(dni)
);

CREATE TABLE DM_DUMMY.tbl_nomina (
    nomina_id    NUMBER        NOT NULL,
    empleado_id  NUMBER        NOT NULL,        -- NO   FK -> empleados (clave subrogada, no es dato personal)
    concepto     VARCHAR2(100),                 -- NO
    importe      NUMBER(10,2),                  -- NO
    iban_abono   VARCHAR2(30),                  -- MASK bancario, sin FK
    fecha_pago   DATE,                          -- NO
    CONSTRAINT pk_tbl_nomina PRIMARY KEY (nomina_id),
    CONSTRAINT fk_nom_empleado FOREIGN KEY (empleado_id) REFERENCES DM_DUMMY.tbl_empleados(empleado_id)
);

CREATE TABLE DM_DUMMY.tbl_beneficiarios (
    beneficiario_id    NUMBER        NOT NULL,
    empleado_id        NUMBER        NOT NULL,  -- NO   FK -> empleados
    dni_beneficiario   VARCHAR2(20),            -- MASK identidad, sin FK (tercero ajeno a personas)
    email_beneficiario VARCHAR2(150),           -- MASK email, sin FK
    parentesco         VARCHAR2(30),            -- NO
    CONSTRAINT pk_tbl_beneficiarios PRIMARY KEY (beneficiario_id),
    CONSTRAINT fk_ben_empleado FOREIGN KEY (empleado_id) REFERENCES DM_DUMMY.tbl_empleados(empleado_id)
);

CREATE TABLE DM_DUMMY.tbl_audit_log (
    log_id          NUMBER        NOT NULL,
    dni_usuario     VARCHAR2(20)  NOT NULL,     -- MASK identidad, sin FK (relacion logica con personas.dni)
    accion          VARCHAR2(250) NOT NULL,     -- NO
    fecha_accion    TIMESTAMP     DEFAULT SYSTIMESTAMP,  -- NO
    ip_origen       VARCHAR2(45),               -- NO   tecnico
    usuario_sistema VARCHAR2(50),               -- NO   cuenta de servicio
    CONSTRAINT pk_tbl_audit_log PRIMARY KEY (log_id)
);

CREATE TABLE DM_DUMMY.tbl_historial_contacto (
    hist_id           NUMBER        NOT NULL,
    dni_referencia    VARCHAR2(20),             -- MASK identidad, sin FK (clave de union logica)
    email_contacto    VARCHAR2(150),            -- MASK email, sin FK
    telefono_contacto VARCHAR2(20),             -- MASK telefono, sin FK
    canal_contacto    VARCHAR2(20),             -- NO   enum
    notes             VARCHAR2(4000),           -- MASK texto libre con datos personales incrustados
    CONSTRAINT pk_tbl_hist_cont PRIMARY KEY (hist_id)
);

CREATE TABLE DM_DUMMY.tbl_documentacion (
    doc_id         NUMBER        NOT NULL,
    dni_owner      VARCHAR2(20)  NOT NULL,      -- MASK identidad por FK -> personas.dni
    nombre_archivo VARCHAR2(250),               -- NO
    observaciones  VARCHAR2(4000),              -- MASK texto libre con datos personales incrustados
    datos_crudos   VARCHAR2(4000),              -- MASK JSON como texto con DNI, email e IBAN (solo lo delata el dato)
    num_paginas    NUMBER,                      -- NO
    CONSTRAINT pk_tbl_documentacion PRIMARY KEY (doc_id),
    CONSTRAINT fk_doc_persona FOREIGN KEY (dni_owner) REFERENCES DM_DUMMY.tbl_personas(dni)
);

CREATE TABLE DM_DUMMY.tbl_referencias_publicas (
    ref_id       NUMBER        NOT NULL,
    dni_publico  VARCHAR2(20)  NOT NULL,        -- NO   DNI valido de un dataset publico (el nombre de la tabla lo descarta)
    descripcion  VARCHAR2(200),                 -- NO
    CONSTRAINT pk_tbl_ref_publicas PRIMARY KEY (ref_id)
);

prompt =========================================================================
prompt 3B) BLOQUE VOLUMEN (12 tablas): cadena nucleo persona -> cuenta ->
prompt     movimiento, cadenas secundarias y satelites. Se escalan de 0.5 a 60
prompt     millones de filas en dm_dummy_02_dml.sql
prompt =========================================================================
-- Las tres tablas gigantes son NOLOGGING PARALLEL 4. Sus FK se deshabilitan
-- durante la carga y se validan al final (ENABLE VALIDATE), ver el DML.

CREATE TABLE DM_DUMMY.tbl_persona_vol (
    persona_id        NUMBER        NOT NULL,
    nif               VARCHAR2(20)  NOT NULL,   -- MASK identidad
    nombre            VARCHAR2(100) NOT NULL,   -- MASK nombre
    apellidos         VARCHAR2(150) NOT NULL,   -- MASK nombre
    direccion         VARCHAR2(200),            -- MASK direccion
    telefono          VARCHAR2(20),             -- MASK telefono
    email             VARCHAR2(150),            -- MASK email
    observaciones     VARCHAR2(500),            -- MASK texto libre (datos personales en 1 de cada 20 filas)
    fecha_nacimiento  DATE,                     -- NO
    fecha_alta        DATE,                     -- NO
    profesion         VARCHAR2(80),             -- NO
    estado_civil      VARCHAR2(20),             -- NO
    pais_residencia   VARCHAR2(60),             -- NO
    tipo_persona      VARCHAR2(20),             -- NO   enum
    canal_captacion   VARCHAR2(30),             -- NO   enum
    score_riesgo      NUMBER(5,2),              -- NO
    activo            CHAR(1)       DEFAULT 'Y',-- NO
    nif_falso_decoy   VARCHAR2(20),             -- NO   senuelo: nombre de NIF, dato correlativo sin digito de control
    CONSTRAINT pk_tbl_persona_vol PRIMARY KEY (persona_id)
) NOLOGGING PARALLEL 4;

CREATE TABLE DM_DUMMY.tbl_cuenta_vol (
    cuenta_id      NUMBER        NOT NULL,
    persona_id     NUMBER        NOT NULL,      -- NO   FK -> persona_vol (clave subrogada)
    iban           VARCHAR2(30)  NOT NULL,      -- MASK bancario
    cuenta_ccc     VARCHAR2(30),                -- MASK bancario
    saldo          NUMBER(14,2),                -- NO
    fecha_apertura DATE,                        -- NO
    tipo_cuenta    VARCHAR2(20),                -- NO   enum
    sucursal       VARCHAR2(10),                -- NO   codigo de oficina
    CONSTRAINT pk_tbl_cuenta_vol PRIMARY KEY (cuenta_id),
    CONSTRAINT fk_cuenta_persona_vol FOREIGN KEY (persona_id) REFERENCES DM_DUMMY.tbl_persona_vol(persona_id)
) NOLOGGING PARALLEL 4;

CREATE TABLE DM_DUMMY.tbl_movimiento_vol (
    movimiento_id  NUMBER        NOT NULL,
    cuenta_id      NUMBER        NOT NULL,      -- NO   FK -> cuenta_vol (segundo salto)
    fecha_mov      DATE          NOT NULL,      -- NO
    importe        NUMBER(12,2)  NOT NULL,      -- NO
    concepto       VARCHAR2(200),               -- limite: texto libre con datos personales en 1 de cada 500 filas
    CONSTRAINT pk_tbl_movimiento_vol PRIMARY KEY (movimiento_id),
    CONSTRAINT fk_movim_cuenta_vol FOREIGN KEY (cuenta_id) REFERENCES DM_DUMMY.tbl_cuenta_vol(cuenta_id)
) NOLOGGING PARALLEL 4;

CREATE TABLE DM_DUMMY.tbl_empresa_vol (
    empresa_id         NUMBER        NOT NULL,
    cif                VARCHAR2(20)  NOT NULL,  -- MASK identidad (CIF)
    razon_social       VARCHAR2(150) NOT NULL,  -- MASK nombre
    direccion_fiscal   VARCHAR2(200),           -- MASK direccion
    iban_pago          VARCHAR2(30),            -- MASK bancario
    telefono_contacto  VARCHAR2(20),            -- MASK telefono
    email_contacto     VARCHAR2(150),           -- MASK email
    sector             VARCHAR2(60),            -- NO
    num_empleados      NUMBER,                  -- NO
    facturacion_anual  NUMBER(14,2),            -- NO
    fecha_constitucion DATE,                    -- NO
    tipo_empresa       VARCHAR2(30),            -- NO   enum
    activa             CHAR(1) DEFAULT 'Y',     -- NO
    codigo_interno_falso VARCHAR2(20),          -- NO   senuelo correlativo
    CONSTRAINT pk_tbl_empresa_vol PRIMARY KEY (empresa_id)
);

CREATE TABLE DM_DUMMY.tbl_factura_vol (
    factura_id      NUMBER        NOT NULL,
    empresa_id      NUMBER        NOT NULL,     -- NO   FK -> empresa_vol
    numero_factura  VARCHAR2(30),               -- NO
    fecha_emision   DATE,                       -- NO
    importe_total   NUMBER(12,2),               -- NO
    estado          VARCHAR2(20),               -- NO   enum
    CONSTRAINT pk_tbl_factura_vol PRIMARY KEY (factura_id),
    CONSTRAINT fk_fact_empresa FOREIGN KEY (empresa_id) REFERENCES DM_DUMMY.tbl_empresa_vol(empresa_id)
);

CREATE TABLE DM_DUMMY.tbl_empleado_vol (
    empleado_id           NUMBER        NOT NULL,
    nif_empleado          VARCHAR2(20)  NOT NULL,  -- MASK identidad, sin FK a persona_vol
    nombre_empleado       VARCHAR2(100) NOT NULL,  -- MASK nombre
    apellidos_empleado    VARCHAR2(150) NOT NULL,  -- MASK nombre
    direccion_empleado    VARCHAR2(200),           -- MASK direccion
    telefono_empleado     VARCHAR2(20),            -- MASK telefono
    email_corporativo     VARCHAR2(150),           -- MASK email
    iban_nomina           VARCHAR2(30),            -- MASK bancario
    departamento          VARCHAR2(60),            -- NO
    puesto                VARCHAR2(80),            -- NO
    fecha_alta_emp        DATE,                    -- NO
    fecha_baja_emp        DATE,                    -- NO
    salario_bruto         NUMBER(10,2),            -- NO
    tipo_contrato         VARCHAR2(30),            -- NO   enum
    jornada               VARCHAR2(20),            -- NO   enum
    centro_coste          VARCHAR2(20),            -- NO
    manager_id            NUMBER,                  -- NO
    nivel                 VARCHAR2(10),            -- NO
    turno                 VARCHAR2(20),            -- NO   enum
    activo_emp            CHAR(1) DEFAULT 'Y',     -- NO
    idioma                VARCHAR2(10),            -- NO
    pais_nacimiento_emp   VARCHAR2(60),            -- NO
    observaciones_rrhh    VARCHAR2(300),           -- NO   texto libre SIN datos personales (control)
    usuario_red           VARCHAR2(50),            -- NO   login tecnico
    codigo_empleado_falso VARCHAR2(20),            -- NO   senuelo correlativo
    CONSTRAINT pk_tbl_empleado_vol PRIMARY KEY (empleado_id)
);

CREATE TABLE DM_DUMMY.tbl_nomina_vol (
    nomina_id      NUMBER        NOT NULL,
    empleado_id    NUMBER        NOT NULL,      -- NO   FK -> empleado_vol
    periodo        VARCHAR2(10),                -- NO
    importe_bruto  NUMBER(10,2),                -- NO
    importe_neto   NUMBER(10,2),                -- NO
    fecha_pago     DATE,                        -- NO
    CONSTRAINT pk_tbl_nomina_vol PRIMARY KEY (nomina_id),
    CONSTRAINT fk_nomv_empleado FOREIGN KEY (empleado_id) REFERENCES DM_DUMMY.tbl_empleado_vol(empleado_id)
);

CREATE TABLE DM_DUMMY.tbl_documento_vol (
    documento_id   NUMBER        NOT NULL,
    persona_id     NUMBER        NOT NULL,      -- NO   FK -> persona_vol
    nombre_archivo VARCHAR2(250),               -- NO
    observaciones  VARCHAR2(500),               -- limite: texto libre con datos personales en 1 de cada 20 filas
    num_paginas    NUMBER,                      -- NO
    CONSTRAINT pk_tbl_documento_vol PRIMARY KEY (documento_id),
    CONSTRAINT fk_doc_persona_vol FOREIGN KEY (persona_id) REFERENCES DM_DUMMY.tbl_persona_vol(persona_id)
);

CREATE TABLE DM_DUMMY.tbl_audit_log_vol (
    log_id          NUMBER        NOT NULL,
    nif_usuario     VARCHAR2(20)  NOT NULL,     -- MASK identidad, sin FK (relacion logica con persona_vol.nif)
    accion          VARCHAR2(250) NOT NULL,     -- NO
    fecha_accion    TIMESTAMP     DEFAULT SYSTIMESTAMP,  -- NO
    ip_origen       VARCHAR2(45),               -- NO   tecnico
    usuario_sistema VARCHAR2(50),               -- NO   cuenta de servicio
    CONSTRAINT pk_tbl_audit_log_vol PRIMARY KEY (log_id)
);

CREATE TABLE DM_DUMMY.tbl_referencia_publica_vol (
    ref_id      NUMBER        NOT NULL,
    nif_publico VARCHAR2(20)  NOT NULL,         -- NO   NIF valido de un dataset publico (el nombre de la tabla lo descarta)
    descripcion VARCHAR2(200),                  -- NO
    CONSTRAINT pk_tbl_ref_publica_vol PRIMARY KEY (ref_id)
);

CREATE TABLE DM_DUMMY.tbl_referencia_inversa_vol (
    ref_inv_id     NUMBER        NOT NULL,
    codigo_interno VARCHAR2(20)  NOT NULL,      -- FORCE nombre neutro, valor = NIF real
    etiqueta       VARCHAR2(100),               -- NO
    CONSTRAINT pk_tbl_ref_inversa_vol PRIMARY KEY (ref_inv_id)
);

CREATE TABLE DM_DUMMY.tbl_config_tecnica_vol (
    config_id              NUMBER        NOT NULL,
    clave                  VARCHAR2(100) NOT NULL,   -- NO
    valor                  VARCHAR2(500),            -- NO
    codigo_cliente_tecnico VARCHAR2(20),             -- NO   "cliente" en el nombre, dato tecnico
    fecha_actualizacion    DATE,                     -- NO
    activo                 CHAR(1) DEFAULT 'Y',      -- NO
    CONSTRAINT pk_tbl_config_tecnica_vol PRIMARY KEY (config_id)
);

-- Indices de apoyo a las FK de las tablas grandes (no unicos). El DML los marca
-- UNUSABLE durante la carga y los reconstruye al final.
CREATE INDEX DM_DUMMY.idx_fk_cuenta_persona ON DM_DUMMY.tbl_cuenta_vol(persona_id);
CREATE INDEX DM_DUMMY.idx_fk_movim_cuenta   ON DM_DUMMY.tbl_movimiento_vol(cuenta_id);
CREATE INDEX DM_DUMMY.idx_fk_doc_persona    ON DM_DUMMY.tbl_documento_vol(persona_id);

prompt =========================================================================
prompt 3C) BLOQUE CIERRE (5 tablas + 1 trigger): casos de la prueba de fuerza
prompt =========================================================================

-- Caso PROMOTOR (valor mixto persona/entidad bajo nombre neutro) y dominio de
-- 4 digitos (por debajo del minimo NIST de 10^6 combinaciones).
CREATE TABLE DM_DUMMY.tbl_gestor_cartera (
    gestor_id        NUMBER        NOT NULL,
    gestor           VARCHAR2(150) NOT NULL,    -- FORCE (persona unas veces, entidad otras): sin FORCE queda sin clasificar
    cod_acceso_corto VARCHAR2(4)   NOT NULL,    -- FORCE dominio de 4 digitos: sin FORCE no entra
    cartera_valor    NUMBER(12,2),              -- NO
    CONSTRAINT pk_tbl_gestor_cartera PRIMARY KEY (gestor_id)
);

-- Topologia del incidente de deadlocks GES: trigger de UPDATE que agrega por
-- clave de negocio (codigo_sucursal), no por rowid.
CREATE TABLE DM_DUMMY.tbl_resumen_sucursal (
    codigo_sucursal        NUMBER        NOT NULL,
    total_actualizaciones  NUMBER        DEFAULT 0,
    fecha_ultima           TIMESTAMP,
    CONSTRAINT pk_tbl_resumen_sucursal PRIMARY KEY (codigo_sucursal)
);

CREATE TABLE DM_DUMMY.tbl_sucursal_riesgo (
    registro_id        NUMBER        NOT NULL,
    codigo_sucursal    NUMBER        NOT NULL,  -- NO   clave de negocio ciclica (MOD), a proposito no correlativa por rowid
    titular_principal  VARCHAR2(150) NOT NULL,  -- MASK nombre (la fila dispara el trigger)
    importe_riesgo     NUMBER(12,2),            -- NO
    CONSTRAINT pk_tbl_sucursal_riesgo PRIMARY KEY (registro_id)
) NOLOGGING PARALLEL 4;

CREATE OR REPLACE TRIGGER DM_DUMMY.trg_sucursal_riesgo_upd
AFTER UPDATE ON DM_DUMMY.tbl_sucursal_riesgo
FOR EACH ROW
BEGIN
  UPDATE DM_DUMMY.tbl_resumen_sucursal
     SET total_actualizaciones = total_actualizaciones + 1,
         fecha_ultima          = SYSTIMESTAMP
   WHERE codigo_sucursal = :NEW.codigo_sucursal;
END;
/

-- Tabla aislada para la prueba de corte de sesion y reanudacion: nadie le hace
-- FK, ella no referencia a nadie, una sola columna a enmascarar.
CREATE TABLE DM_DUMMY.tbl_lote_resume (
    lote_id         NUMBER        NOT NULL,
    nombre_completo VARCHAR2(150) NOT NULL,     -- MASK nombre (unica columna a enmascarar)
    estado_proceso  VARCHAR2(20)  DEFAULT 'PENDIENTE',  -- NO
    CONSTRAINT pk_tbl_lote_resume PRIMARY KEY (lote_id)
) NOLOGGING PARALLEL 4;

-- FK SIN NOMBRE a proposito (Oracle genera un SYS_C...): reproduce el caso
-- SKIP_DEP_NOT_FOUND al hacer DROP + ADD de la constraint a mano.
CREATE TABLE DM_DUMMY.tbl_renovacion_constraint (
    reg_id   NUMBER        NOT NULL,
    dni_ref  VARCHAR2(20)  NOT NULL,            -- MASK identidad por FK (sin nombre) -> personas.dni
    detalle  VARCHAR2(100),                     -- NO
    CONSTRAINT pk_tbl_renov_constraint PRIMARY KEY (reg_id)
);

ALTER TABLE DM_DUMMY.tbl_renovacion_constraint
  ADD FOREIGN KEY (dni_ref) REFERENCES DM_DUMMY.tbl_personas(dni);

prompt =========================================================================
prompt 3D) BLOQUE CASOS ESPECIALES (8 tablas): reglas especiales, sincronizacion,
prompt     unicidad, rutas de UPDATE, formatos y tabla vacia
prompt =========================================================================

-- Reglas especiales (TDM_MASK_REGLA_ESP, las carga el DML): documento segun tipo,
-- documento unificado conservando primer y ultimo caracter, IBAN continuo.
-- TIPO_DOCUMENTO es NUMBER y su nombre lo descarta la regla -300 (no es dato personal).
CREATE TABLE DM_DUMMY.tbl_doc_especial (
    registro_id      NUMBER         NOT NULL,   -- NO   id subrogado
    tipo_documento   NUMBER         NOT NULL,   -- NO   1 DNI, 2 pasaporte, 3 NIE (lo lee la regla DOC_SEGUN_TIPO)
    numero_documento VARCHAR2(30)   NOT NULL,   -- MASK identidad, regla DOC_SEGUN_TIPO (valor_regla = TIPO_DOCUMENTO)
    ndocumento       VARCHAR2(120)  NOT NULL,   -- MASK identidad, regla DOC_UNIFICADO_MANTENER_1_Y_ULTIMO (una fila de 102 caracteres)
    iban_continuo    VARCHAR2(30)   NOT NULL,   -- MASK bancario, regla IBAN_ES_CONTINUO (24 caracteres sin espacios)
    fecha_alta       DATE,                      -- NO
    CONSTRAINT pk_tbl_doc_especial PRIMARY KEY (registro_id)
);

-- Coherencia por join que NO es FK (TDM_MASK_RELACION_SYNC, la carga el DML).
-- El destino guarda una copia del correo bajo un nombre neutro y con otro valor de partida:
-- solo la sincronizacion puede dejarlo igual al correo enmascarado del origen.
CREATE TABLE DM_DUMMY.tbl_sync_origen (
    sync_id        NUMBER         NOT NULL,     -- NO
    correo_cliente VARCHAR2(150)  NOT NULL,     -- MASK email
    CONSTRAINT pk_tbl_sync_origen PRIMARY KEY (sync_id)
);

CREATE TABLE DM_DUMMY.tbl_sync_destino (
    destino_id     NUMBER         NOT NULL,     -- NO
    sync_id        NUMBER         NOT NULL,     -- NO   join logico con tbl_sync_origen (sin FK a proposito)
    copia_contacto VARCHAR2(150)  NOT NULL,     -- NO   nombre neutro; el dato solo puntua 55 (REVISAR); lo rellena la sincronizacion
    CONSTRAINT pk_tbl_sync_destino PRIMARY KEY (destino_id)
);

-- Columnas con indice unico propio y funcion de enmascarado NO inyectiva
-- (nombre, email): el motor debe avisar con UNICIDAD_RIESGO y, con estos datos,
-- no producir colision.
CREATE TABLE DM_DUMMY.tbl_unicidad (
    registro_id     NUMBER         NOT NULL,    -- NO
    nombre_completo VARCHAR2(150)  NOT NULL,    -- MASK nombre, indice unico
    email           VARCHAR2(150)  NOT NULL,    -- MASK email, indice unico
    CONSTRAINT pk_tbl_unicidad PRIMARY KEY (registro_id)
);
CREATE UNIQUE INDEX DM_DUMMY.uq_unicidad_nombre ON DM_DUMMY.tbl_unicidad(nombre_completo);
CREATE UNIQUE INDEX DM_DUMMY.uq_unicidad_email  ON DM_DUMMY.tbl_unicidad(email);

-- Clave primaria que ES el dato personal y mas de 100.000 filas: el motor no puede trocear
-- (chunks) una columna con indice unico propio; debe hacer un solo UPDATE.
CREATE TABLE DM_DUMMY.tbl_dni_pk_vol (
    nif     VARCHAR2(20)  NOT NULL,             -- MASK identidad, PRIMARY KEY (ruta UPDATE sin chunks)
    importe NUMBER(12,2),                       -- NO
    CONSTRAINT pk_tbl_dni_pk_vol PRIMARY KEY (nif)
);

-- Formatos: valores NULL, IBAN con espacios, pasaporte y telefono con prefijo.
CREATE TABLE DM_DUMMY.tbl_formatos (
    fmt_id        NUMBER         NOT NULL,      -- NO
    nif           VARCHAR2(20),                 -- MASK identidad, NULL en 1 de cada 3 filas
    telefono      VARCHAR2(20),                 -- MASK telefono, NULL en 1 de cada 4 filas; 1 de cada 5 con prefijo +34
    iban_espacios VARCHAR2(34),                 -- MASK bancario, formato impreso 'ES91 2100 0418 4502 0005 1332'
    doc_ident     VARCHAR2(30),                 -- MASK identidad, pasaporte (sin letra de control)
    etiqueta      VARCHAR2(30),                 -- NO
    CONSTRAINT pk_tbl_formatos PRIMARY KEY (fmt_id)
);

-- Tabla organizada por indice (IOT): no se trocea; un solo UPDATE.
CREATE TABLE DM_DUMMY.tbl_iot (
    iot_id          NUMBER         NOT NULL,    -- NO
    nombre_completo VARCHAR2(150),              -- MASK nombre
    etiqueta_lote   VARCHAR2(30),               -- NO
    CONSTRAINT pk_tbl_iot PRIMARY KEY (iot_id)
) ORGANIZATION INDEX;

-- Tabla vacia: el descubrimiento la omite (TABLA_OMITIDA_SIN_FILAS / TABLAS_OMITIDAS).
CREATE TABLE DM_DUMMY.tbl_vacia (
    vacia_id NUMBER        NOT NULL,            -- NO
    nif      VARCHAR2(20),                      -- NO   (sin filas no hay dato que evaluar)
    CONSTRAINT pk_tbl_vacia PRIMARY KEY (vacia_id)
);

prompt =========================================================================
prompt 4) ACCESO DEL ESQUEMA DEL MOTOR: SELECT, UPDATE sobre cada tabla
prompt =========================================================================
-- El motor lee (descubrimiento) y actualiza en sitio (enmascarado) con los
-- derechos de su propietario. No se concede INSERT ni DELETE: nunca inserta ni
-- borra filas. La lista de tablas sale del diccionario: no hay un GRANT por
-- tabla que mantener.
declare
  l_motor varchar2(128);
  l_n     pls_integer := 0;
begin
  select username into l_motor
    from (select username from dba_users
           where username in ('ASTSYSADMIN','ACC_ADMIN')
           order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
   where rownum = 1;
  for t in (select table_name from dba_tables where owner = 'DM_DUMMY' order by table_name) loop
    execute immediate 'GRANT SELECT, UPDATE ON DM_DUMMY."' || t.table_name || '" TO "' || l_motor || '"';
    l_n := l_n + 1;
  end loop;
  dbms_output.put_line('GRANT SELECT, UPDATE concedido sobre ' || l_n || ' tablas a ' || l_motor);
end;
/

prompt =========================================================================
prompt 5) VALIDACION DEL ESQUEMA
prompt =========================================================================
declare
  l_tablas number;
  l_fk     number;
  l_inval  number;
  l_trg    number;
begin
  select count(*) into l_tablas from dba_tables      where owner = 'DM_DUMMY';
  select count(*) into l_fk     from dba_constraints where owner = 'DM_DUMMY' and constraint_type = 'R';
  select count(*) into l_inval  from dba_objects     where owner = 'DM_DUMMY' and status <> 'VALID';
  select count(*) into l_trg    from dba_triggers    where owner = 'DM_DUMMY' and status = 'ENABLED';
  dbms_output.put_line('Tablas ............ ' || l_tablas || ' (esperadas 35)');
  dbms_output.put_line('Claves foraneas ... ' || l_fk     || ' (esperadas 12)');
  dbms_output.put_line('Triggers activos .. ' || l_trg    || ' (esperado 1)');
  dbms_output.put_line('Objetos invalidos . ' || l_inval  || ' (esperados 0)');
  if l_tablas <> 35 or l_fk <> 12 or l_trg <> 1 or l_inval <> 0 then
    raise_application_error(-20004, 'El esquema DM_DUMMY no ha quedado como se esperaba: revisa los mensajes anteriores.');
  end if;
  dbms_output.put_line('OK: DM_DUMMY creado y concedido al esquema del motor.');
end;
/

prompt =========================================================================
prompt DDL COMPLETADO. Siguiente paso, la carga (volumen en millones de filas):
prompt     @dm_dummy_02_dml 2
prompt =========================================================================
