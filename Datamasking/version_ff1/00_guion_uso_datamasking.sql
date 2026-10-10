Rem ================================================================================
Rem GUION DE USO - DATAMASKING VERSION FF1 (NIST SP 800-38G)
Rem ================================================================================
Rem Usa los scripts @dm_*.sql de esta carpeta.
Rem Reemplaza <ESQUEMA>, <EJEC>, <USUARIO>, <RUTA>, <DIR_ORACLE>, <ARCHIVO>.
Rem
Rem ================================================================================

set serveroutput on size unlimited
set linesize 220
set pagesize 200

Rem 2026-10-05: esquema ya no va fijo -- se detecta solo (ASTSYSADMIN o
Rem ACC_ADMIN, el que exista) y queda disponible como &&esquemaast para los
Rem ejemplos de este guion.
Rem --- Esquema del motor: se detecta solo (ASTSYSADMIN o ACC_ADMIN), sin setear nada a mano ---
define esquemaast = '__NO_DETECTADO__'
define tbsast     = '__NO_DETECTADO__'
column v_esquemaast noprint new_value esquemaast
column v_tbsast      noprint new_value tbsast
select username as v_esquemaast, nvl(default_tablespace,username) as v_tbsast
  from (select username, default_tablespace from dba_users
         where username in ('ASTSYSADMIN','ACC_ADMIN')
         order by decode(username,'ASTSYSADMIN',1,'ACC_ADMIN',2,9))
 where rownum = 1;
declare
begin
  if upper(trim('&&esquemaast')) = '__NO_DETECTADO__' then
    raise_application_error(-20001,'No se encontro ni ASTSYSADMIN ni ACC_ADMIN en DBA_USERS -- no se puede determinar el esquema del motor DATAMASKING en esta base.');
  end if;
end;
/

Rem ================================================================================
Rem 0) INSTALACIóN
Rem ================================================================================
Rem   @@99_install_datamasking.sql
Rem SYS concede dentro de 99: grant execute on SYS.DBMS_CRYPTO al esquema del motor
Rem
Rem Sinonimos privados por cada DBA (conectado con su propio usuario):
Rem   @dm_creasyn <USUARIO>

Rem ================================================================================
Rem 1) DESCUBRIMIENTO  (crea la ejecucion y clasifica columnas PII)
Rem ================================================================================
Rem   @dm_descubre <ESQUEMA>        -> modo default (toma muestra de 500 filas por tabla)
Rem   @dm_descubre <ESQUEMA> Y      -> forzar full  (si se requiere re-ejecutar el descubrimiento)
Rem El script imprime el EJECUCION_ID generado. Anotalo como <EJEC>.
Rem
Rem Descubrimiento dirigido SOLO a las tablas que ya tienen una excepcion
Rem configurada en TDM_EXCEPCION_COL (activa='Y'), en lugar de reclasificar todo
Rem el esquema. Usalo cuando el cliente pide FORZAR o EXCLUIR columnas puntuales
Rem sobre un esquema que ya fue descubierto antes y solo quieres refrescar esas
Rem tablas concretas (mas rapido que un @dm_descubre Y completo):
Rem   @dm_descubre_set <ESQUEMA> <TABLA1,TABLA2,...>
Rem Recuerda: FORZAR/EXCLUIR siempre tiene prioridad sobre la clasificacion Y/N
Rem que produzca esta ejecucion.

Rem --- Si necesitas recuperar el ejecucion_id mas reciente del esquema ---
column ora_esquema format a25
select ejecucion_id, ora_esquema, fase_proceso, estado, fecha_inicio
from   &&esquemaast..tdm_ejecucion
where  ora_esquema = '<ESQUEMA>'
order  by ejecucion_id desc;

Rem --- Si una ejecucion anterior quedo bloqueada en estado EJECUTANDO (por una
Rem caida de sesion, por ejemplo) y no te deja lanzar una nueva sobre el mismo
Rem esquema, revisala y libera la fila atascada (marca la ejecucion como
Rem ABORTADA; no toca el dato ya enmascarado):
Rem   @dm_liberar_ejecucion_activa <ESQUEMA>

Rem ================================================================================
Rem 2) REVISION DE LA CLASIFICACION
Rem ================================================================================
Rem Consolidado por esquema (lo que se enmascarara):
column ora_owner format a18
column table_name format a28
column column_name format a28
column identificador format a26
select ora_owner, table_name, column_name, identificador, enmascarar
from   &&esquemaast..tdm_columna_final
where  ora_owner = '<ESQUEMA>'
order  by table_name, column_name;
Rem (El detalle por ejecucion esta en tdm_columna_hist WHERE ejecucion_id = <EJEC>.)
Rem
Rem Exportar la clasificacion a CSV (usa la data de tdm_columna_final ):
Rem Genera el csv que se debe enviar al usuario para que validen las columnas descubiertas.
Rem Ejecución:
Rem   @dm_exportcsv <RUTA> <ESQUEMA>

Rem ================================================================================
Rem 3) EXCEPCIONES (opcional): forzar/excluir columnas antes de enmascarar
Rem ================================================================================
Rem Para una ejecución directa de campos enviados por el cliente
Rem es necesario ejecutar obligatoriamente el DESCUBRIMIENTO para que se pueda
Rem detectar la integridad referencial.
Rem Luego hay que colocar el campo ENMASCARAR en 'N' de la tabla TDM_COLUMNA_FINAL
Rem   @@97_configurar_excepciones.sql (Scripts de ejemplo)
Rem Luego de tener las dependencias en TDM_DEPENDENCIA_FINAL y en TDM_EXCEPCION_COL
Rem Se puede ejecutar @dm_enmascara.

Rem ================================================================================
Rem 4) ENMASCARAMIENTO
Rem ================================================================================
Rem   @dm_enmascara <EJEC>      -> Ejecuta los parametros por defecto
Rem   @dm_enmascara <EJEC> Y    -> reproceso forzado

Rem Si se requiere enmascarar un grupo de tablas del mismo IDENTIFICADOR
Rem Solo un identificador (opcional):
Rem   @dm_enmascara_id <EJEC> IDENTIFICADOR_BANCARIO %   (% representa todo)
Rem   @dm_enmascara_id <EJEC> IDENTIFICADOR_BANCARIO Y   (Y reproceso)
Rem
Rem Si el enmascaramiento se interrumpio (caida de sesion, timeout, etc.) y la
Rem ejecucion quedo a medio terminar, reanuda SOLO lo pendiente (no repite lo ya
Rem hecho). Si el script devuelve el error -20504, primero libera la ejecucion
Rem con @dm_liberar_ejecucion_activa (ver seccion 1):
Rem   @dm_enmascara_reanudar <EJEC>

Rem ================================================================================
Rem 5) VALIDACION POST-ENMASCARAMIENTO  (evidencia para auditoria)
Rem ================================================================================
Rem Suite de validacion con 8 indicadores (objetos invalidos, restauracion de
Rem constraints/triggers deshabilitados durante el enmascarado, cero errores en
Rem la traza, digitos de control DNI/NIE/CIF e IBAN sobre el dato YA enmascarado,
Rem unicidad en columnas con indice UNIQUE, indice que evita ejecuciones
Rem concurrentes duplicadas, cero huerfanos por FK). Falla con RAISE -20099 si
Rem algun indicador no pasa (apto para pipelines CI/CD). Ejecutar siempre
Rem despues de enmascarar y ANTES de exportar o purgar el pepper:
Rem   @dm_validar_flujo <ESQUEMA> <EJEC>
Rem
Rem Auditoria de consistencia de dominios/integridad referencial (verifica que
Rem las columnas relacionadas por FK dentro del esquema comparten el mismo
Rem IDENTIFICADOR y por tanto se enmascaran de forma consistente). Utilidad de
Rem solo lectura, recomendable antes de una auditoria externa. Nota: las FK que
Rem cruzan a OTRO esquema no entran en la propagacion automatica de dominios y
Rem el script las marca como ATENCION para revision manual:
Rem   @dm_tabref <ESQUEMA>

Rem ================================================================================
Rem 6) EXPORT del dump enmascarado (dato ya enmascarado - OPCIONAL)
Rem ================================================================================
EXEC pkg_dm_export.proc_dm_export_mask(p_esquema => '<ESQUEMA>', p_directorio => '<DIR_ORACLE>', p_dumpfile => '<ARCHIVO>.dmp', p_alcance => 'S', p_logfile => '<ARCHIVO>.log', p_ejecucion_id => <EJEC>);

Rem ================================================================================
Rem 7) PURGA DEL PEPPER  (paso final, IRREVERSIBLE)
Rem ================================================================================
Rem Elimina la semilla efimera de esa campana (tdm_secreto.clave =
Rem 'PEPPER_MASK:'||<EJEC>). Ejecutar como ULTIMO paso, despues de validar
Rem (seccion 5) y exportar (seccion 6). Una vez purgado el pepper el dato
Rem enmascarado de esa ejecucion deja de ser reversible: no hay vuelta atras
Rem salvo reimportar desde PRO. No purgar si todavia se puede necesitar volver
Rem a generar el export o revisar la ejecucion.
Rem   @dm_pepper_purgar <EJEC>

Rem ================================================================================
Rem 8) CANCELAR / REANUDAR / LIBERAR / DESINSTALAR
Rem ================================================================================
Rem Cancelar descubrimiento:          EXEC pkg_dm_descubrimiento.proc_dm_cancelar(<EJEC>);
Rem Cancelar enmascaramiento:         EXEC pkg_dm_enmascarar.proc_dm_cancelar(<EJEC>);
Rem Reanudar enmascaramiento:         @dm_enmascara_reanudar <EJEC>   (ver seccion 4)
Rem Liberar ejecucion activa atascada: @dm_liberar_ejecucion_activa <ESQUEMA>   (ver seccion 1)
Rem
Rem Desinstalar todo:                 @@98_uninstall.sql
