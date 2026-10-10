set echo off
set feedback on
set verify off
set serveroutput on size unlimited
set linesize 220
set pagesize 200
set long 50000
set trimspool on
set tab off
Rem FIX 2026-10-05: se fuerza explicitamente (no se asume el default de
Rem SQL*Plus). Sospecha de root cause de todo el incidente de sustitucion
Rem vacia (&&esquemaast/&&tbsast/&v_fecha): un glogin.sql/login.sql del
Rem cliente con "SET DEFINE OFF". El resto del script ya NO depende de
Rem sustitucion para nada que toque la base (esquema/tablespace van por
Rem variable de enlace real, inmune a este SET) -- el UNICO uso que queda
Rem de &var es el nombre de archivo del SPOOL, puramente cosmetico, porque
Rem SPOOL es un comando de SQL*Plus (no SQL) y no acepta variables de
Rem enlace. Forzar DEFINE ON aqui es lo que permite que ese nombre lleve
Rem fecha y hora reales en vez de quedar literal "v_fecha" como paso antes.
set define on

Rem ================================================================================
Rem INSTALACION ORDENADA DATAMASKING - DESCUBRIMIENTO + ENMASCARAMIENTO
Rem VERSION FF1 (NIST SP 800-38G): nucleo numerico con Cifrado que Preserva Formato
Rem                                estandar (AES-128). Solo cambia 06_dm_pkg_func_mask
Rem                                y la generacion del pepper (CSPRNG). El resto igual.
Rem ================================================================================
Rem
Rem Este archivo es una guia para SQL*Plus.
Rem - Los scripts @@ deben estar en la misma ruta de este archivo o ajustar la ruta.
Rem ================================================================================

column v_fecha noprint new_value v_fecha
select to_char(sysdate,'YYYYMMDD_HH24MISS') v_fecha from dual;
Rem FIX 2026-10-05: nombre de spool con fecha/hora reales otra vez (ver el
Rem "set define on" de mas arriba -- ya no se usa &&v_fecha para nada que
Rem toque la base, asi que aunque esta sustitucion fallara, lo unico que se
Rem pierde es el nombre bonito del archivo, nunca la instalacion).
spool install_datamasking_&v_fecha..log
Rem
Rem ----------------------------------------------------------------
Rem 1.0 DETECCION AUTOMATICA DEL ESQUEMA DEL MOTOR (ASTSYSADMIN o
Rem     ACC_ADMIN, segun cual exista -- 2026-10-05, ya no va fijo)
Rem ----------------------------------------------------------------
Rem FIX 2026-10-05 (hallazgo real, confirmado con una ejecucion limpia y
Rem aislada de SOLO este script, sin encadenar con 98_uninstall): en el
Rem cliente SQL*Plus de este entorno la sustitucion &&var en CUALQUIER
Rem contexto SIN comillas (GRANT, ALTER SESSION, TABLESPACE, el nombre de
Rem archivo de SPOOL) resuelve sistematicamente a VACIO -- la propia spool
Rem de una corrida real quedo nombrada "install_datamasking_v_fecha..log"
Rem (literal, sin sustituir) en vez de llevar la fecha real. En quoted
Rem dentro de un bloque PL/SQL si sustituia, lo que apunta a algo en el
Rem perfil de SQL*Plus del cliente (glogin.sql/login.sql, posible SET
Rem DEFINE OFF) que trata distinto cada contexto. En vez de seguir
Rem dependiendo de ese mecanismo (fragil y especifico de cada cliente),
Rem este bloque usa una VARIABLE DE ENLACE real (:g_esquemaast, declarada
Rem con VARIABLE) -- un bind no depende en absoluto de SET DEFINE/SCAN,
Rem y cada GRANT/ALTER SESSION que antes iba con &&esquemaast sin comillas
Rem ahora se arma con EXECUTE IMMEDIATE a partir de ese bind: inmune a como
Rem este configurado SQL*Plus en la maquina donde se ejecute.
Rem La tablespace (antes &&tbsast) ya no se detecta ni se usa: se elimino
Rem la clausula TABLESPACE de todos los CREATE TABLE/INDEX (ver 01_ y 02_)
Rem porque Oracle, sin esa clausula, usa automaticamente el tablespace por
Rem defecto del esquema actual -- exactamente el mismo valor que &&tbsast
Rem calculaba a mano (nvl(default_tablespace,username)), sin depender de
Rem ninguna sustitucion.
variable g_esquemaast varchar2(30)
declare
  l_esquemaast dba_users.username%type;
begin
  select username into l_esquemaast
    from (select username from dba_users
           where username in ('ASTSYSADMIN','ACC_ADMIN')
           order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
   where rownum = 1;
  :g_esquemaast := l_esquemaast;
exception
  when no_data_found then
    raise_application_error(-20001,'No se encontro ni ASTSYSADMIN ni ACC_ADMIN en DBA_USERS -- no se puede determinar el esquema del motor DATAMASKING en esta base.');
end;
/

Rem Diagnostico fiable (PRINT muestra el bind tal cual, no depende de
Rem SET DEFINE/SCAN como el PROMPT con &&var que antes mentia aqui mismo).
prompt
prompt *** ESQUEMA DEL MOTOR DETECTADO (variable de enlace g_esquemaast) ***
print g_esquemaast
prompt *** Si el valor anterior no es el esquema esperado, Ctrl+C ahora. ***
prompt

Rem
Rem ----------------------------------------------------------------
Rem 1.1 PRIVILEGIOS DE SISTEMA PARA EL ESQUEMA DEL MOTOR
Rem ----------------------------------------------------------------

begin
  execute immediate 'grant select any dictionary to '||:g_esquemaast;
  execute immediate 'grant execute on SYS.DBMS_CRYPTO to '||:g_esquemaast;
end;
/

Rem
Rem ----------------------------------------------------------------
Rem 1.1b VERIFICACION (solo informa, no concede nada) DE LOS PRIVILEGIOS
Rem      QUE EL MOTOR NECESITA SOBRE LOS ESQUEMAS A ENMASCARAR
Rem ----------------------------------------------------------------
Rem El paquete corre con derechos del DEFINIDOR (el dueño del motor): sus ROLES
Rem no cuentan, ni siquiera DBA. Incidente 2026-10-09 (DESSIGAD): el descubrimiento
Rem funcionaba y el enmascaramiento fallaba con ORA-01031 en todas las columnas
Rem porque al dueño del motor le faltaba UPDATE sobre CEFCEN_OWN. Cada privilegio
Rem puede estar concedido como sistema (ANY) o, para un alcance mas estricto, como
Rem UPDATE/ALTER directo sobre las tablas del esquema destino; esta comprobacion
Rem solo mira los de sistema y lo dice. La decision de conceder es de seguridad.
declare
  l_n number;
begin
  dbms_output.put_line('Privilegios de sistema CONCEDIDOS DIRECTAMENTE a '||:g_esquemaast||':');
  for r in (select column_value as priv
              from table(sys.odcivarchar2list('SELECT ANY TABLE','UPDATE ANY TABLE',
                                              'ALTER ANY TABLE','ALTER ANY TRIGGER','CREATE JOB'))) loop
    select count(*) into l_n from dba_sys_privs where grantee = :g_esquemaast and privilege = r.priv;
    dbms_output.put_line('  '||rpad(r.priv,20)||case when l_n > 0 then 'concedido'
      else 'NO concedido (valido solo si hay UPDATE/ALTER directo sobre cada tabla destino)' end);
  end loop;
end;
/

Rem
Rem ----------------------------------------------------------------
Rem 1.1c VERIFICACION (solo informa) DE EXECUTE SOBRE PAQUETES DE SYS
Rem ----------------------------------------------------------------
Rem Por la misma razon que 1.1b (el motor compila con derechos del definidor), el
Rem EXECUTE tiene que estar concedido al esquema del motor o a PUBLIC, no por un rol.
Rem DBMS_CRYPTO se concedio arriba; los demas suelen venir en PUBLIC, pero una base
Rem endurecida puede haberlo revocado y entonces 03b..07 compilan con PLS-00201.
declare
  l_n number;
begin
  dbms_output.put_line('EXECUTE sobre paquetes de SYS para '||:g_esquemaast||' o PUBLIC:');
  for r in (select column_value as pkg
              from table(sys.odcivarchar2list('DBMS_CRYPTO','DBMS_PARALLEL_EXECUTE',
                                              'DBMS_SCHEDULER','DBMS_LOCK','DBMS_DATAPUMP'))) loop
    select count(*) into l_n from dba_tab_privs
     where owner = 'SYS' and table_name = r.pkg and privilege = 'EXECUTE'
       and grantee in (:g_esquemaast, 'PUBLIC');
    dbms_output.put_line('  '||rpad(r.pkg,22)||case when l_n > 0 then 'concedido'
      else 'NO concedido: conceder GRANT EXECUTE ON SYS.'||r.pkg||' TO '||:g_esquemaast end);
  end loop;
end;
/

Rem
Rem ----------------------------------------------------------------
Rem 1.2 CREACION DEL ROL
Rem ----------------------------------------------------------------

declare
  e_role_exists exception;
  pragma exception_init(e_role_exists, -1921);
begin
  execute immediate 'create role ROL_DATAMASKING';
exception
  when e_role_exists then
    dbms_output.put_line('ROL_DATAMASKING ya existe, se reutiliza.');
end;
/

Rem
Rem ----------------------------------------------------------------
Rem 1.3 PRIVILEGIO ADMINISTRATIVO PARA LIBERAR TAREAS PARALELAS
Rem     HUERFANAS DE OTRO ESQUEMA (dm_liberar_ejecucion_activa.sql)
Rem ----------------------------------------------------------------
Rem FIX 2026-10-05: dm_liberar_ejecucion_activa.sql lo corre cada DBA
Rem conectado con SU PROPIO usuario (nunca como &&esquemaast -- ver 1.4
Rem mas abajo), y necesita poder detener/eliminar una tarea
Rem DBMS_PARALLEL_EXECUTE huerfana que pertenece a &&esquemaast (no al
Rem DBA) cuando una sesion de enmascarado muere a mitad de un chunk.
Rem DBMS_PARALLEL_EXECUTE autoriza sus rutinas normales (DROP_TASK/
Rem STOP_TASK) solo sobre tareas del CURRENT_USER; para gestionar tareas
Rem de OTRO esquema sin conectarse como ese esquema, Oracle expone desde
Rem 11gR2 las rutinas administrativas ADM_DROP_TASK/ADM_STOP_TASK,
Rem gated por el rol predefinido ADM_PARALLEL_EXECUTE_TASK -- NO viene
Rem incluido en el rol DBA, hay que otorgarlo aparte aunque la cuenta ya
Rem tenga DBA completo. Se otorga UNA sola vez aqui a ROL_DATAMASKING
Rem (no a cada usuario a mano, uno por uno) para que lo tenga
Rem automaticamente cualquier DBA actual o futuro al que mas abajo (3.1)
Rem se le asigne ese rol -- sin administracion de privilegios adicional
Rem cada vez que se incorpore alguien al equipo.
grant ADM_PARALLEL_EXECUTE_TASK to ROL_DATAMASKING;

Rem
Rem ----------------------------------------------------------------
Rem 1.4 SINONIMOS PRIVADOS
Rem ----------------------------------------------------------------
Rem Los sinonimos privados ya NO se crean desde este instalador.
Rem
Rem Cada DBA debe crearlos conectado con su propio usuario:
Rem
Rem   conn <usuario>/<password>@<servicio>
Rem   @crea_sinonimos <USUARIO>
Rem ----------------------------------------------------------------
Rem
Rem ================================================================================
Rem AHORA CONECTAR COMO EL ESQUEMA DEL MOTOR (detectado en el paso 1.0)
Rem ================================================================================

begin
  execute immediate 'ALTER SESSION SET CURRENT_SCHEMA = '||:g_esquemaast;
end;
/
Rem
Rem ----------------------------------------------------------------
Rem 2.1 LIMPIEZA OPCIONAL PREVIA
Rem ----------------------------------------------------------------
Rem Si deseas reinstalar desde cero, ejecuta primero:
Rem   @@98_uninstall.sql
Rem Si no necesitas limpiar, continua con la creacion.
Rem ----------------------------------------------------------------

Rem
Rem ----------------------------------------------------------------
Rem 2.2 CREACION DE OBJETOS DE DESCUBRIMIENTO
Rem ================================================================
@@01_dm_descubrimiento_objetos.sql

Rem
Rem ----------------------------------------------------------------
Rem 2.3 CREACION DE OBJETOS DE ENMASCARAMIENTO
Rem ================================================================
@@02_dm_enmascaramiento_objetos.sql

Rem
Rem ----------------------------------------------------------------
Rem 2.3.1 CARGA DE SEMILLA DE SEGURIDAD (PEPPER)
Rem ----------------------------------------------------------------
Rem NOTA OPERATIVA: El pepper aleatorio hace que cada instalacion genere un pepper
Rem distinto, por lo que los valores enmascarados difieren entre entornos. Si se
Rem necesita reproducir exactamente un dump ya entregado (o que PRE coincida con
Rem otro entorno), generar el pepper una sola vez y replicar la misma fila de
Rem tdm_secreto al resto de entornos - nunca regenerarlo.
Rem NOTA FF1: El pepper ES EFIMERO POR CAMPANA (ejecucion_id). Ya NO se genera en
Rem   la instalacion. Cada campana usa su PROPIA fila clave='PEPPER_MASK:'||ejec,
Rem   de modo que dos esquemas enmascarados a la vez tienen peppers independientes
Rem   (sin carrera de creacion ni purga cruzada).
Rem   pkg_dm_enmascarar.proc_dm_enmascaramiento lo crea al inicio de cada enmascarado
Rem   (RAWTOHEX(DBMS_CRYPTO.RANDOMBYTES(32)), idempotente, COMMIT antes del paralelo).
Rem   Purga por-campana tras el export:
Rem      EXEC pkg_dm_enmascarar.proc_dm_pepper_purgar(<ejecucion_id>);
Rem   Invariante: dos esquemas con FK ENTRE SI deben ir en la MISMA ejecucion.
Rem   Se comparte entre los workers paralelos via tdm_secreto durante la corrida.
Rem   Requisito: GRANT EXECUTE ON SYS.DBMS_CRYPTO (concedido en la fase de SYS).

Rem
Rem ----------------------------------------------------------------
Rem 2.4 CARGA DE REGLAS DE DESCUBRIMIENTO
Rem ================================================================
@@03_dm_descubrimiento_carga_reglas.sql

Rem
Rem ----------------------------------------------------------------
Rem 2.5 CONFIGURACION DE EXCEPCIONES (OPCIONAL)
Rem ----------------------------------------------------------------
Rem Si existe el archivo y deseas cargar excepciones:
Rem   @@97_configurar_excepciones.sql
Rem ----------------------------------------------------------------
Rem ----------------------------------------------------------------
Rem 2.6 CREACION DEL PAQUETE DE TRAZABILIDAD (sin dependencias)
Rem ----------------------------------------------------------------
Rem Debe compilarse ANTES que 04 y 05: ambos lo llaman de forma estatica
Rem para registrar traza/errores (ver cabecera de 03b_dm_pkg_trazabilidad.sql).
@@03b_dm_pkg_trazabilidad.sql
Rem ----------------------------------------------------------------
Rem 2.3 CREACION DEL PAQUETE DE DESCUBRIMIENTO
Rem ================================================================
@@04_dm_pkg_descubrimiento.sql
Rem
Rem ----------------------------------------------------------------
Rem 2.7 CREACION DE PAQUETES DE ENMASCARAMIENTO
Rem ----------------------------------------------------------------
Rem Ajustar estos nombres si tus archivos reales difieren:
@@06_dm_pkg_func_mask.sql
@@05_dm_pkg_enmascarar.sql
@@07_dm_pkg_export.sql
Rem ----------------------------------------------------------------

Rem
Rem ----------------------------------------------------------------
Rem 2.8 COMPILACION Y REVISION DE ERRORES
Rem ----------------------------------------------------------------
Rem FIX 2026-09-23 (industrializacion): pkg_dm_trazabilidad compila en 2.6 pero
Rem no tenia "show errors" aqui - un fallo de compilacion (p.ej. drift de
Rem esquema) quedaba silencioso y 04/05 fallaban con ORA-04063 sin motivo
Rem aparente en el log de instalacion. Se añade para que sea visible.
show errors package pkg_dm_trazabilidad
show errors package body pkg_dm_trazabilidad

show errors package pkg_dm_descubrimiento
show errors package body pkg_dm_descubrimiento

show errors package pkg_dm_func_mask
show errors package body pkg_dm_func_mask

show errors package pkg_dm_enmascarar
show errors package body pkg_dm_enmascarar

show errors package pkg_dm_export
show errors package body pkg_dm_export

Rem
Rem ----------------------------------------------------------------
Rem 2.9 GRANTS SOBRE OBJETOS AL ROL ROL_DATAMASKING
Rem ================================================================
grant execute on pkg_dm_descubrimiento to ROL_DATAMASKING;
grant execute on pkg_dm_func_mask       to ROL_DATAMASKING;
grant execute on pkg_dm_enmascarar      to ROL_DATAMASKING;
grant execute on pkg_dm_export          to ROL_DATAMASKING;
grant execute on pkg_dm_trazabilidad    to ROL_DATAMASKING;

grant select on tdm_ejecucion          to ROL_DATAMASKING;
grant select on tdm_ejecucion_scope    to ROL_DATAMASKING;
grant select on tdm_ejecucion_error    to ROL_DATAMASKING;
grant select on tdm_objeto_ctrl        to ROL_DATAMASKING;
grant select on tdm_regla              to ROL_DATAMASKING;
grant select on tdm_excepcion_col      to ROL_DATAMASKING;
grant select on tdm_parametro          to ROL_DATAMASKING;
grant select on tdm_columna_hist       to ROL_DATAMASKING;
grant select on tdm_dependencia_hist   to ROL_DATAMASKING;
grant select on tdm_columna_final      to ROL_DATAMASKING;
grant select on tdm_dependencia_final  to ROL_DATAMASKING;

grant select, insert, update on tdm_mask_solicitud      to ROL_DATAMASKING;
grant select, insert          on tdm_mask_trace          to ROL_DATAMASKING;
grant select, insert, update  on tdm_mask_dep_estado     to ROL_DATAMASKING;
grant select                  on tdm_mask_regla_esp      to ROL_DATAMASKING;
grant select                  on tdm_mask_relacion_sync  to ROL_DATAMASKING;
Rem tdm_secreto (peppers) NO se concede al rol a proposito: solo el dueño del motor la lee.
Rem tdm_mask_cache no existe: su DDL esta comentada en 02 (sin uso en esta version).

grant select on seq_dm_ejecucion          to ROL_DATAMASKING;
grant select on seq_dm_ejecucion_scope    to ROL_DATAMASKING;
grant select on seq_dm_regla              to ROL_DATAMASKING;
grant select on seq_dm_columna_hist       to ROL_DATAMASKING;
grant select on seq_dm_dependencia_hist   to ROL_DATAMASKING;
grant select on seq_dm_mask_solicitud     to ROL_DATAMASKING;
grant select on seq_dm_mask_trace         to ROL_DATAMASKING;
grant select on seq_dm_mask_regla_esp     to ROL_DATAMASKING;
grant select on seq_dm_mask_relacion_sync to ROL_DATAMASKING;

Rem
Rem ================================================================================
Rem FIN FASE 2
Rem AHORA CONECTAR COMO SYS
Rem ================================================================================
Rem ================================================================================

Rem
Rem ----------------------------------------------------------------
Rem 3.1 ASIGNAR EL ROL A LOS DBA
Rem ----------------------------------------------------------------
Rem R-02 (auditoria, severidad baja, pendiente): estos 8 usuarios estan
Rem   hardcodeados aqui. Mejora futura sugerida: leerlos de una tabla de
Rem   configuracion (p.ej. tdm_dba_autorizado) e iterar con un bloque PL/SQL,
Rem   para no tener que editar este script cada vez que cambia el equipo.
Rem   No se aborda en esta iteracion por ser bajo riesgo y para no tocar mas
Rem   de lo necesario en el script de instalacion.
grant ROL_DATAMASKING to ALOPEZDIAZ;
grant ROL_DATAMASKING to ACASTANGI;
grant ROL_DATAMASKING to DMIRANDA;
grant ROL_DATAMASKING to EYPURISACA;
grant ROL_DATAMASKING to ASANCLEMENTE;
grant ROL_DATAMASKING to CSOETERS;
grant ROL_DATAMASKING to ACAMING;
grant ROL_DATAMASKING to CROSS;


Rem
Rem ================================================================================
Rem FIN FASE 3
Rem VALIDACION FINAL
Rem ================================================================================
Rem Esta validacion puede ejecutarse como SYS o con un usuario con acceso a DBA_*
Rem ================================================================================

column owner          format a20
column object_name    format a30
column object_type    format a20
column status         format a12
column grantee        format a20
column table_name     format a30
column privilege      format a15
column granted_role   format a25
column synonym_name   format a30
column table_owner    format a20
column name           format a30
column type           format a18
Rem
Rem ----------------------------------------------------------------
Rem 4.1 VALIDACION DE OBJETOS DEL MOTOR (esperado contra real)
Rem ----------------------------------------------------------------
Rem La lista esperada es la que crean 01, 02 y los paquetes 03b..07 (17 tablas,
Rem 9 secuencias, 5 paquetes con su cuerpo) y es la misma que borra 98_uninstall.sql.
Rem Si se agrega o se retira un objeto del motor, actualizar las TRES listas a la vez:
Rem   98_uninstall.sql, esta validacion y los GRANT de 2.9.
Rem Solo se imprimen las FALLAS (objeto ausente o INVALID); sin fallas, una linea OK.
declare
  l_esq  varchar2(128) := :g_esquemaast;
  l_tot  number := 0;
  l_mal  number := 0;
  l_est  varchar2(20);

  procedure proc_chequea(p_tipo varchar2, p_lista sys.odcivarchar2list) is
  begin
    for i in 1 .. p_lista.count loop
      l_tot := l_tot + 1;
      begin
        select status into l_est
          from dba_objects
         where owner = l_esq and object_type = p_tipo and object_name = p_lista(i);
      exception
        when no_data_found then l_est := 'FALTA';
      end;
      if l_est <> 'VALID' then
        l_mal := l_mal + 1;
        dbms_output.put_line('  '||rpad(p_tipo,13)||rpad(p_lista(i),28)||l_est);
      end if;
    end loop;
  end;
begin
  dbms_output.put_line('Validacion de objetos del motor en '||l_esq||':');
  proc_chequea('TABLE', sys.odcivarchar2list(
    'TDM_EJECUCION','TDM_EJECUCION_ERROR','TDM_EJECUCION_SCOPE','TDM_OBJETO_CTRL','TDM_REGLA',
    'TDM_EXCEPCION_COL','TDM_COLUMNA_HIST','TDM_DEPENDENCIA_HIST','TDM_COLUMNA_FINAL',
    'TDM_DEPENDENCIA_FINAL','TDM_SECRETO','TDM_PARAMETRO','TDM_MASK_SOLICITUD','TDM_MASK_TRACE',
    'TDM_MASK_DEP_ESTADO','TDM_MASK_REGLA_ESP','TDM_MASK_RELACION_SYNC'));
  proc_chequea('SEQUENCE', sys.odcivarchar2list(
    'SEQ_DM_EJECUCION','SEQ_DM_EJECUCION_SCOPE','SEQ_DM_REGLA','SEQ_DM_COLUMNA_HIST',
    'SEQ_DM_DEPENDENCIA_HIST','SEQ_DM_MASK_SOLICITUD','SEQ_DM_MASK_TRACE','SEQ_DM_MASK_REGLA_ESP',
    'SEQ_DM_MASK_RELACION_SYNC'));
  proc_chequea('PACKAGE', sys.odcivarchar2list(
    'PKG_DM_TRAZABILIDAD','PKG_DM_DESCUBRIMIENTO','PKG_DM_FUNC_MASK','PKG_DM_ENMASCARAR','PKG_DM_EXPORT'));
  proc_chequea('PACKAGE BODY', sys.odcivarchar2list(
    'PKG_DM_TRAZABILIDAD','PKG_DM_DESCUBRIMIENTO','PKG_DM_FUNC_MASK','PKG_DM_ENMASCARAR','PKG_DM_EXPORT'));
  if l_mal = 0 then
    dbms_output.put_line('  OK: '||l_tot||' objetos esperados, todos presentes y VALID.');
  else
    dbms_output.put_line('  ATENCION: '||l_mal||' de '||l_tot||' objetos con falla (ver arriba y 4.6).');
  end if;
end;
/

Rem
Rem ----------------------------------------------------------------
Rem 4.2 OBJETOS DEL ESQUEMA QUE EL MOTOR YA NO USA (sobrantes)
Rem ----------------------------------------------------------------
Rem Vacio en una instalacion limpia. Una fila aqui es un objeto TDM_% / PKG_DM_% /
Rem SEQ_DM_% de una version anterior que 98_uninstall.sql no conoce.
select object_type, object_name, status
  from dba_objects
 where owner = :g_esquemaast
   and object_type in ('TABLE','SEQUENCE','PACKAGE','PACKAGE BODY','VIEW','PROCEDURE','FUNCTION','TRIGGER','TYPE')
   and (object_name like 'TDM\_%' escape '\' or object_name like 'PKG\_DM\_%' escape '\'
        or object_name like 'SEQ\_DM\_%' escape '\')
   and object_name not in (
    'TDM_EJECUCION','TDM_EJECUCION_ERROR','TDM_EJECUCION_SCOPE','TDM_OBJETO_CTRL','TDM_REGLA',
    'TDM_EXCEPCION_COL','TDM_COLUMNA_HIST','TDM_DEPENDENCIA_HIST','TDM_COLUMNA_FINAL',
    'TDM_DEPENDENCIA_FINAL','TDM_SECRETO','TDM_PARAMETRO','TDM_MASK_SOLICITUD','TDM_MASK_TRACE',
    'TDM_MASK_DEP_ESTADO','TDM_MASK_REGLA_ESP','TDM_MASK_RELACION_SYNC',
    'SEQ_DM_EJECUCION','SEQ_DM_EJECUCION_SCOPE','SEQ_DM_REGLA','SEQ_DM_COLUMNA_HIST',
    'SEQ_DM_DEPENDENCIA_HIST','SEQ_DM_MASK_SOLICITUD','SEQ_DM_MASK_TRACE','SEQ_DM_MASK_REGLA_ESP',
    'SEQ_DM_MASK_RELACION_SYNC',
    'PKG_DM_TRAZABILIDAD','PKG_DM_DESCUBRIMIENTO','PKG_DM_FUNC_MASK','PKG_DM_ENMASCARAR','PKG_DM_EXPORT')
 order by object_type, object_name;

Rem
Rem ----------------------------------------------------------------
Rem 4.3 VALIDACION DE GRANTS AL ROL
Rem ----------------------------------------------------------------

select grantee,
       owner,
       table_name,
       privilege
from dba_tab_privs
where owner = :g_esquemaast
  and grantee = 'ROL_DATAMASKING'
order by table_name, privilege;

Rem
Rem ----------------------------------------------------------------
Rem 4.4 VALIDACION DE ASIGNACION DEL ROL A LOS DBA
Rem ----------------------------------------------------------------

select grantee,
       granted_role
from dba_role_privs
where granted_role = 'ROL_DATAMASKING'
  and grantee in (
    'ALOPEZDIAZ',
    'ACASTANGI',
    'DMIRANDA',
    'EYPURISACA',
    'ASANCLEMENTE',
    'CSOETERS',
    'ACAMING',
    'CROSS'  )
order by grantee;

/*
Rem
Rem ----------------------------------------------------------------
Rem 4.5 VALIDACION DE SINONIMOS EN LOS DBA
Rem ----------------------------------------------------------------

	select owner,
		   synonym_name,
		   table_owner,
		   table_name
	from dba_synonyms
	where owner in (    'ALOPEZDIAZ',
		'ACASTANGI',
		'DMIRANDA',
		'EYPURISACA',
		'ASANCLEMENTE',
		'CSOETERS',
		'ACAMING',
		'CROSS')  and table_owner = :g_esquemaast
	order by owner, synonym_name;
*/
Rem
Rem ----------------------------------------------------------------
Rem 4.6 VALIDACION DE ERRORES DE COMPILACION
Rem ----------------------------------------------------------------

select owner,
       name,
       type,
       line,
       position,
       text
from dba_errors
where owner = :g_esquemaast
  and name in (
    'PKG_DM_TRAZABILIDAD',
    'PKG_DM_DESCUBRIMIENTO',
    'PKG_DM_FUNC_MASK',
    'PKG_DM_ENMASCARAR',
    'PKG_DM_EXPORT'
  ) order by name, type, sequence;

spool off
Rem
Rem ================================================================================
Rem FIN DE INSTALACION / VALIDACION
Rem ================================================================================

Rem
Rem ================================================================================
Rem ANEXO (OPCIONAL, NO BLOQUEANTE): SERVICIO RAC + JOB_CLASS JC_DATAMASKING
Rem ================================================================================
Rem FIX 2026-09-23 (industrializacion, hallazgo Antigravity): proc_dm_ejecuta_update_seguro
Rem (05_dm_pkg_enmascarar.sql) ya soporta job_class de forma OPCIONAL: si existe una
Rem job_class llamada JC_DATAMASKING, DBMS_PARALLEL_EXECUTE.RUN_TASK la usa (afinidad de
Rem instancia RAC, menos "gc current block/grant" en AWR); si no existe, el motor sigue
Rem funcionando exactamente igual que hoy, sin job_class. Este anexo documenta como crearla
Rem cuando el DBA decida hacerlo - NO es parte del flujo de instalacion normal, NADA de
Rem esto se ejecuta automaticamente desde este script, y es un requisito RECOMENDADO, no
Rem obligatorio.
Rem
Rem PRERREQUISITO: un servicio RAC dedicado (via Clusterware/srvctl, NUNCA via
Rem DBMS_SERVICE.CREATE_SERVICE - eso rompe el conocimiento de Clusterware sobre el
Rem servicio y su failover/HA). Estos comandos son de SISTEMA OPERATIVO (se ejecutan como
Rem el usuario Oracle/grid, en una shell, NO en SQL*Plus) - se documentan aqui solo como
Rem referencia, no se pueden lanzar desde este script:
Rem
Rem   PASO 1) Crear el servicio (ajustar db_unique_name, nombre de servicio e instancia(s)
Rem           preferida(s)/disponible(s) al entorno real; -P BASIC evita reintentos
Rem           agresivos de reconexion para una carga batch como esta):
Rem     srvctl add service -d <db_unique_name> -s SRV_DATAMASKING -r <instancia_preferida> ^
Rem                        -a <instancias_disponibles_failover> -P BASIC -e NONE
Rem
Rem   PASO 2) Arrancar el servicio:
Rem     srvctl start service -d <db_unique_name> -s SRV_DATAMASKING
Rem
Rem   PASO 3) Verificar estado:
Rem     srvctl status service -d <db_unique_name> -s SRV_DATAMASKING
Rem
Rem Con el servicio SRV_DATAMASKING ya arriba, esto SI es SQL y puede ejecutarse tal cual
Rem (conectado como SYS o un usuario con EXECUTE en DBMS_SCHEDULER a nivel de CREATE_JOB_CLASS,
Rem tipicamente SYS):
Rem
Rem   PASO 4) Crear la job_class ligada al servicio:
Rem     BEGIN
Rem       DBMS_SCHEDULER.CREATE_JOB_CLASS(
Rem         job_class_name => 'JC_DATAMASKING',
Rem         service        => 'SRV_DATAMASKING',
Rem         comments       => 'Afinidad de instancia RAC para el motor de enmascaramiento FF1'
Rem       );
Rem     END;
Rem     /
Rem
Rem   PASO 5) Autorizar al esquema del motor (ASTSYSADMIN o ACC_ADMIN, el que
Rem           exista en este entorno -- se detecta solo al inicio de cada
Rem           script, ver &&esquemaast) a lanzar jobs
Rem           en esa clase (sin este grant, RUN_TASK con job_class fallaria con
Rem           ORA-27478/ORA-27479 al intentar usarla - pero como el motor
Rem           comprueba la EXISTENCIA de la job_class antes de pasarla a
Rem           RUN_TASK, no su uso, conviene completar este grant en el mismo
Rem           momento en que se crea la job_class, para no dejar una ventana
Rem           en la que el motor la detecte pero no pueda usarla):
Rem     GRANT EXECUTE ON SYS.JC_DATAMASKING TO <esquema_del_motor>;
Rem
Rem   PASO 6) Verificacion:
Rem     SELECT job_class_name, service FROM dba_scheduler_job_classes
Rem      WHERE job_class_name = 'JC_DATAMASKING';
Rem
Rem     SELECT grantee, privilege FROM dba_tab_privs
Rem      WHERE table_name = 'JC_DATAMASKING' AND grantee = '<esquema_del_motor>';
Rem
Rem A partir de aqui, la siguiente ejecucion de proc_dm_ejecuta_update_seguro detecta
Rem JC_DATAMASKING sola (SELECT COUNT(*) FROM dba_scheduler_job_classes) y empieza a usarla
Rem sin ningun cambio de codigo ni de configuracion adicional.
Rem
Rem PARA REVERTIR (quitar la afinidad sin tocar el motor, vuelve al comportamiento actual):
Rem     BEGIN DBMS_SCHEDULER.DROP_JOB_CLASS(job_class_name => 'JC_DATAMASKING', force => TRUE); END;
Rem     /
Rem     srvctl stop service  -d <db_unique_name> -s SRV_DATAMASKING
Rem     srvctl remove service -d <db_unique_name> -s SRV_DATAMASKING
Rem ================================================================================

