***************************
ENMASCARAR SIGAD DES-PRE
***************************

Solicitud cliente:
--------------------
1. Registros y leyenda de colores en la EXCEL.
--------------------------------------------------------------------------------------------------------------------------------------
2. Tratamiento de NIF/NIE/Pasaporte.
Se debe aplicar un tratamiento diferente en las tablas TSKPCRUNIFICARALUMNOS y TSKPCRUNIFICARFAMILIARES y el resto de tablas que contienen documentos.
En las tablas TSKPCRUNIFICARALUMNOS y TSKPCRUNIFICARFAMILIARES se aplicará un tratamiento similar al propuesto, pero en lugar de mantener el último 
carácter (la letra en un NIF) se mantendrán el primero y el último (dado que en un NIE el primer carácter también es una letra que lo caracteriza como NIE).
En el resto de tablas, junto a la columna NDOCUMENTO que contiene el valor del documento hay otra columna numérica que contiene el identificador del tipo de 
documento (IDTIPODOCUMENTO).

Como tipos de documentos se utilizan los siguientes valores: 1-NIF, 3-NIE y el resto de posibles valores que serán tratados como Pasaporte.

En función de este tipo, el tratamiento a realizar será diferente:
    • NIF: Se generará un número aleatorio de 8 cifras y se calculará la letra que corresponda según la validación de los NIF.
    • NIE: Se generará un número aleatorio de 8 cifras, cuya primera cifra sólo pueda ser 0, 1 o 2, se calculará la letra que corresponda según la validación de 
	los NIF y se sustituirá el primer dígito por X, Y o Z según éste sea 0, 1 o 2.
    • Pasaporte: Se sustituirá cada dígito del valor original por uno aleatorio, manteniendo igual los caracteres que no sean dígitos.
--------------------------------------------------------------------------------------------------------------------------------------
3. Tratamiento de cuentas bancarias.
La única columna que contiene una cuenta bancaria es la columna NUMEROCUENTA de la tabla CENCUENTABANCO.
Esta columna incluye un IBAN, pero no con el formato indicado en el tratamiento propuesto en el que se agrupan los caracteres en bloque de 4 separados por 
espacios, sino que contiene los 24 caracteres (2 letras mayúsculas y 22 dígitos) de forma consecutiva. Por lo tanto, los nuevos valores generados deberán seguir 
ese mismo formato continuo.

Además, los nuevos valores generados deberán mantener la coherencia de los dígitos de control del formato IBAN, es decir, deberán estar compuestos por 2 
letras mayúsculas (siempre ES), los dos dígitos de control (calculados en base al resto del valor) y los 22 dígitos de la cuenta (estos sí que pueden ser 
aleatorios).

En el caso del ejemplo del tratamiento (ES9112345678901234567890) no debería empezar por ES91, sino por ES98.

-----------------------------------------------------------------------------------------------------------------------------------------

4. Coherencia de e-mail entre profesores respecto a sus usuarios.
Debe mantenerse coherencia entre el e-mail de la tabla de usuarios (SEGUSUARIO) respecto a la de profesores (PERPROFESOR) para todos los registros de la primera 
que tengan un registro ligado de la segunda a través de la columna IDUSUARIO.

Para realizar el tratamiento se propone hacer el tratamiento general en ambas tablas sin tener en cuenta la coherencia entre ambas y posteriormente recorrer la 
tabla SEGUSUARIO y modificar los registros de PERPROFESOR asociados, copiando el e-mail de SEGUSUARIO sobre PERPROFESOR.

-----------------------------------------------------------------------------------------------------------------------------------------------

5. Coherencia de nombre, apellidos y documento de identidad entre alumnos, familiares y profesores respecto a sus usuarios.
Debe mantenerse coherencia entre nombres, apellidos y documentos de identidad de la tabla de usuarios (SEGUSUARIO) respecto a las de alumnos (CENALUMNO), 
de familiares (CENFAMILIAR) y de profesores (PERPROFESOR) para todos los registros de la primera que tengan un registro ligado de las segundas a través de la 
columna IDUSUARIO.

Para realizar el tratamiento se propone hacer el tratamiento general en las cuatro tablas sin tener en cuenta la coherencia entre ellas y posteriormente recorrer 
la tabla SEGUSUARIO y modificar los registros de CENALUMNO, CENFAMILIAR y PERPROFESOR asociados, copiando el nombre, los apellidos y el documento de identidad de 
SEGUSUARIO sobre CENALUMNO, CENFAMILIAR y PERPROFESOR según corresponda. 

***********************************************************************************************************************************************************
Tablas implicadas en SIGAD:

    • TSKPCRUNIFICARALUMNOS 
    • MOLPREMATRICULA 
    • DESTINATARIOS 
    • SEGUSUARIO 
    • CENALUMNO 
    • TSKPCRUNIFICARFAMILIARES 
    • CENFAMILIAR 
    • PERDOMICILIO 
    • MOLPREMATRICULAFAMILIAR 
    • CENCURSOEVALUACION 
    • OFECENTRO 
    • CENACTIVIDADPROGRAMA 
    • PERPROFESOR 
    • TERVIA 
    • PERTERCERO 
    • OTROSDATOSDOC 
    • OFECENTRORELACIONCOMUNIDAD 
    • CENCUENTABANCO 
    • ALUNOTIFICACIONDSP 

Primero revisar dependencias en SIGAD_ACAD_OWN

############################
EJECUCION ENMASCARAMIENTO  #
############################

Paso 1: Ejecutar descubrimiento:

@dm_descubre SIGAD_ACAD_OWN

Ejemplo salida => @dm_descubre SIGAD_ACAD_OWN Y
=========================================
Ejecucion DM Descubrimiento
Esquema   : SIGAD_ACAD_OWN
Parametro : Y
=========================================
Modo: FORZAR FULL
=========================================
Resumen de la ejecucion
Ejecucion_id           : 2
Estado                 : FINALIZADO
Fecha inicio           : 20-04-2026 16:25:06
Fecha fin              : 20-04-2026 16:28:08
Progreso %             : 100
Ultimo paso            : FINALIZADO
Ultimo objeto          : SIGAD_ACAD_OWN.USOLISLISTADO.PARAMETROS
Columnas descubiertas  : 515
Con enmascarar = Y     : 142
=========================================

--------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------
Paso 2:

Poner inactivas todas las columnas en TDM_COLUMNA_FINAL y en TDM_COLUMNA_HIST

UPDATE tdm_columna_final f SET f.enmascarar = 'N' WHERE f.owner_name = 'SIGAD_ACAD_OWN';
UPDATE tdm_columna_hist h  SET h.enmascarar = 'N' WHERE h.owner_name = 'SIGAD_ACAD_OWN'   AND h.vigente = 'Y';
COMMI;

Solo nos quedamos con la data de TDM_DEPENDENCIA_FINAL

--------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------

Paso 3:
Insertamos las exclusiones en TDM_EXEPCION_COL

-- Revisar que no haya reglas:
SELECT COUNT(*) AS total_force
  FROM tdm_excepcion_col
 WHERE owner_name = 'SIGAD_ACAD_OWN'
   AND activa = 'Y'
   AND accion = 'FORCE';
 
-- inserta reglas
@sigad_set_reglas_sync_include.sql


-- Validaciones:

-- Total de exepciones, reglas especiales vs tdm_columna_final
SELECT 'EXCEPCION_FORCE_ACTIVA' tipo, COUNT(*) total
  FROM tdm_excepcion_col
 WHERE owner_name='SIGAD_ACAD_OWN'
   AND activa='Y'
   AND accion='FORCE'
UNION ALL
SELECT 'FINAL_ENMASCARAR_Y', COUNT(*)
  FROM tdm_columna_final
 WHERE owner_name='SIGAD_ACAD_OWN'
   AND enmascarar='Y'
UNION ALL
SELECT 'REGLA_ACTIVA_SIGAD', COUNT(*)
  FROM tdm_mask_regla_esp
 WHERE esquema_objetivo='SIGAD_ACAD_OWN'
   AND activa='Y'
UNION ALL
SELECT 'SYNC_ACTIVA_SIGAD', COUNT(*)
  FROM tdm_mask_relacion_sync
 WHERE esquema_objetivo='SIGAD_ACAD_OWN'
   AND activa='Y';

-- Cantidad de reglas insertadas de acuerdo a la cantidad de columnas
select count(*)
from tdm_excepcion_col
where owner_name='SIGAD_ACAD_OWN'
  and activa='Y'
  and accion='FORCE';

-- Si hay alguna columna en Y en tdm_columna_final
select identificador, count(*)
from tdm_columna_final
where owner_name='SIGAD_ACAD_OWN'
  and enmascarar='Y'
group by identificador
order by 1;

-- Validacion de las reglas insertadas
select *
from tdm_mask_regla_esp
where esquema_objetivo='SIGAD_ACAD_OWN'
  and activa='Y'
order by table_name, column_name, tipo_regla;

select *
from tdm_mask_relacion_sync
where esquema_objetivo='SIGAD_ACAD_OWN'
  and activa='Y'
order by prioridad;


-- Verificar que todas las tablas incluidas existan: Si sale alguna que no existe hay que reportarla y sacarla de tdm_exclusion_col
    SELECT e.owner_name, e.table_name, e.column_name
      FROM tdm_excepcion_col e
      LEFT JOIN dba_tab_columns c
        ON c.owner = e.owner_name
       AND c.table_name = e.table_name
       AND c.column_name = e.column_name
     WHERE e.owner_name='SIGAD_ACAD_OWN'
       AND e.activa='Y'
       AND e.accion='FORCE'
       AND c.column_name IS NULL
     ORDER BY e.table_name, e.column_name;

--------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------


Paso 4: Enmascaramiento

@dm_enmascara 2

Ejemplo salida:
=========================================
Ejecucion DM Enmascaramiento
Ejecucion_id : 2
Parametro    : Y
=========================================
ADVERTENCIA: la ejecucion venia previamente en estado ERROR.
Se intentara una nueva ejecucion con los parametros indicados.
-----------------------------------------
Modo: FORZAR / REPROCESO
=========================================
Resumen final
Esquema                : SIGAD_ACAD_OWN
Columnas candidatas    : 92
Estado previo          : ERROR
Estado actual          : FINALIZADO
Inicio ejecucion       : 21-04-2026 10:25:06
Fin ejecucion          : 21-04-2026 10:33:15
Progreso %             : 100
Ultimo paso            : FINALIZADO
Ultimo objeto          : SIGAD_ACAD_OWN.TSKPCRUNIFICARFAMILIARES.NOMBREMANTENER
=========================================


--------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------

Paso 5 : Validaciones post

Validacion en TDM_MASK_TRACE:
ejecucion_id --> TDM_EJECUCION
solicitud_id --> TDM_MASK_SOLICITUD

select * from TDM_MASK_TRACE 
where ejecucion_id=<ejecucion_id> 
and solicitud_id = <solicitud_id> 
order by 2,8

-- Para validar que se esta cumpliendo con lo solicitado por el cliente
-- de acuerdo a los puntos 2,3,4,5
@mask_rpt_funcional.sql