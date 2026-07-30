
select * from tdm_ejecucion order by 1

select * from DM_SIGAD_ACAD.OFECENTRO;

select EMAIL from DM_SIGAD_ACAD.SEGUSUARIO WHERE IDUSUARIO=20230
select EMAIL from DM_SIGAD_ACAD.PERPROFESOR WHERE IDUSUARIO=20230

select * from tdm_dependencia_final

select  * from tdm_columna_final where enmascarar = 'Y'

select * from tdm_excepcion_col 

select * from TDM_MASK_TRACE 
 
BEGIN
  pkg_dm_enmascarar.p_dm_enmascara(3,'Y');
END;
/


SELECT e.owner_name, e.table_name, e.column_name
  FROM tdm_excepcion_col e
  LEFT JOIN all_tab_columns c
    ON c.owner = e.owner_name
   AND c.table_name = e.table_name
   AND c.column_name = e.column_name
 WHERE e.owner_name='DM_SIGAD_ACAD'
   AND e.activa='Y'
   AND e.accion='FORCE'
   AND c.column_name IS NULL
 ORDER BY e.table_name, e.column_name;


SELECT e.owner_name, e.table_name, e.column_name, e.identificador_forz
  FROM tdm_excepcion_col e
 WHERE e.owner_name='SIGAD_ACAD_OWN'
   AND e.activa='Y'
   AND e.accion='FORCE'
MINUS
SELECT f.owner_name, f.table_name, f.column_name, f.identificador
  FROM tdm_columna_final f
 WHERE f.owner_name='SIGAD_ACAD_OWN'
   AND f.enmascarar='Y'
ORDER BY 2,3;

delete from tdm_excepcion_col where column_name in ('NOMBRE_PRESIDENTE_APA1','NOMBRE_PRESIDENTE_APA2')

select distinct table_name  from tdm_columna_final where owner_name='DM_SIGAD_ACAD'
select * from dba_objects where object_name in ('DR$IDX_NOMBRE_OTTC','IDX_NOMBRE_OT')






