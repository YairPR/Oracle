Guía de ejecución – instalación del motor de Data Masking

Ruta de trabajo: Ubicarse en la carpeta donde están los scripts.

Archivos principales:

El 99_install_datamasking.sql es una especie de lanzador y configurador que llama entre otras funciones a los sql indicados.

99_install_datamasking.sql
	01_dm_descubrimiento_objetos.sql
	02_dm_enmascaramiento_objetos.sql
	03_dm_descubrimiento_carga_reglas.sql
	04_dm_pkg_descubrimiento.sql
	05_dm_pkg_enmascarar.sql
	06_dm_pkg_func_mask.sql

98_uninstall.sql

----------- INSTALACION -----------------------

Paso 1. Abrir cmder o terminal

Abrir cmder y posicionarse en la ruta donde están los scripts.

Paso 2. Conectarse a la base de datos con usuario con permisos DBA (Nuestro usuario nominal)

Paso 3. Ejecutar instalación principal

@99_install_datamasking.sql

Genera un log: install_datamasking_$fecha.log

-- CREAR SCRIPT PARA QUE CADA USUARIO CREE SUS SINONIMOS
@crea_sinonimos EYPURISACA


------------ FIN INSTALACION --------------------

------------ EJECUCION --------------

------------------------------------------------------------------------------------------
----- FASE 0. VOLCADO DE DATOS -----------------------------------------------------------
------------------------------------------------------------------------------------------

Realizamos un volcado de PRO a PRE tal cual con expdp / impdp

------------------------------------------------------------------------------------------
----- FASE 1. DESCUBRIMIENTO CAMPOS SENSIBLES --------------------------------------------
------------------------------------------------------------------------------------------

ALTER SESSION SET CURRENT_SCHEMA=ASTSYSADMIN; 

--esto no haria falta ya que en el instalador se crean manualmente sinonimos, pero pudiera ser que entrara algun compañero nuev@ y no estuviera actualizado.

-- PASO 1 Ejecución descubrimiento datos sensibles

 begin
   pkg_dm_descubrimiento.p_dm_descubrimiento('<SCHEMA>');
 end;
 /

		Añadiendo el parametro opcional 'Y' forzariamos un recalculo nuevo del esquema.

		 pkg_dm_descubrimiento.p_dm_descubrimiento('<SCHEMA>','Y');

		--- OPT:  Con esta consulta podemos ver que se esta ejecutando el descubrimiento, asi como obtener el <ejecucion_id> por si hace falta cancelarlo (siguiente paso) 

		select * from tdm_ejecucion where ESQUEMA_OBJETIVO = <SCHEMA>;

		--- CANCELACION -----

		-- OPT: La cancelación es por ejecucion_id, no por esquema.
		 begin
		   pkg_dm_descubrimiento.p_dm_cancelar(<ejecucion_id>);
		 end;
		 /

		-- OPT: Reanuda usando el mismo ejecucion_id.
		 begin
		   pkg_dm_descubrimiento.p_dm_reanudar(<ejecucion_id>);
		 end;
		 /

ejecutar por comando (este script debe estar en nuestra maquina o desde donde se llame)

@dm_descubre <SCHEMA>

Validacion del descubrimiento:

El flujo del proceso en:

select * from tdm_ejecucion;

-- historico de ejecuciones

select * from tdm_columna_hist;
select * from tdm_dependencia_hist;

-- exportar para validacion del cliente:
select * from tdm_columna_final where OWNER_NAME = <SCHEMA>;

-- EXPORTAR A CSV
@dm_exportcsv <ruta> <schema>

genera archivo: sid_esquema_fecha_hora.csv -------->  ejemplo: presocsa_DM_PCSS_OWN_DESCUB_20260324_174215.csv

---- SE ENVIA EL CSV a Cliente para que valide campos.

-- esta data es para los pre y post enmascaramiento asi como la sincronizacion de columnas referenciadas.
-- la columna enmascarar=Y de la tabla tdm_dependencia_final indica que esta habilitada para enmascar 

-- Vemos las constraints/triggers dependientes de los campos sensibles.

select * from tdm_dependencia_final where OWNER_NAME = <SCHEMA>;

-- errores en el proceso
select * from tdm_ejecucion_error where OWNER_NAME = <SCHEMA>;

-- exclusiones:tdm_excepcion_col
--en esta tabla se puede registrar exclusiones (EXCLUDE) o forzar la inclusion de una columna (FORCE)
-- para que el proceso de edscubrimiento y enmascaramiento la considere apta o no.
select * from tdm_excepcion_col where OWNER_NAME = <SCHEMA>;


------------------------------------------------------------------------------------------
----- FASE 2. ENMASCARAMIENTO ------------------------------------------------------------
------------------------------------------------------------------------------------------

--- Obtenemos el ejecucion_id

select EJECUCION_ID from tdm_ejecucion where ESQUEMA_OBJETIVO = <SCHEMA>;

-- PASO 1 - EJECUTAR ENMASCARAMIENTO 

--- Ejecutar enmascaramiento por ejecucion_id
BEGIN
  pkg_dm_enmascarar.p_dm_enmascara(<ejecucion_id>);
END;
/

			-- PASOS OPCIONALES

			-- Re ejecutar el enmascaramiento
			BEGIN
			  pkg_dm_enmascarar.p_dm_enmascara(<ejecucion_id>,'Y');
			END;
			/

			--- reanudar el flujo de enmascaramiento 
			--- si la sesion pierde conectividad o por kill
			-- se puede reanudar
			BEGIN
			  pkg_dm_enmascarar.p_mask_reanudar(<ejecucion_id>);
			END;
			 /

PASO 2 - EXPORTAR DATOS ENMASCARADOS (GENERARIA DUMP CIFRADO PARA ENVIAR A CLIENTE)

-- Exportar enmascaramiento:
-- S para exportar solo las tablas con columnas sensibles enmascaradas
-- C para exportar el esquema completo

BEGIN
  pkg_dm_enmascarar.p_export_mask(
    p_esquema       => '<SCHEMA>',
    p_ejecucion_id  => <ejecucion_id>,
    p_directorio    => '<DIRECTORIO>', 
    p_dumpfile      => '<dump_file>.dmp', 
    p_alcance       => 'C',
    p_logfile       => '<log_file>.log' 
  );
END;
/

-------------------------
--Validaciones
select * from tdm_ejecucion
select * from tdm_mask_solicitud
select * from TDM_MASK_TRACE where ejecucion_id=<ejecucion_id> order by 2,8
-- estado de las depenencias pre y post proceso
select * from tdm_mask_dep_estado



------------------------------------------------------------------------------------------
----- REVERSION               ------------------------------------------------------------
------------------------------------------------------------------------------------------
Ejecutar el import que se obtuvo de PRO para restaurar.


