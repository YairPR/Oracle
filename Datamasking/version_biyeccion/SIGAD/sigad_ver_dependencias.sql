set lines 400 pages 200 trimspool on
col child_owner        format a20
col child_table        format a35
col child_column       format a35
col fk_name            format a35
col parent_owner       format a20
col parent_table       format a35
col parent_column      format a35
col parent_constraint  format a35

select
    c.owner                  as child_owner,
    c.table_name             as child_table,
    cc.column_name           as child_column,
    c.constraint_name        as fk_name,
    p.owner                  as parent_owner,
    p.table_name             as parent_table,
    pc.column_name           as parent_column,
    p.constraint_name        as parent_constraint,
    cc.position              as col_pos
from dba_constraints c
join dba_cons_columns cc
  on cc.owner = c.owner
 and cc.constraint_name = c.constraint_name
join dba_constraints p
  on p.owner = c.r_owner
 and p.constraint_name = c.r_constraint_name
join dba_cons_columns pc
  on pc.owner = p.owner
 and pc.constraint_name = p.constraint_name
 and pc.position = cc.position
where c.constraint_type = 'R'
  and c.owner = 'SIGAD_ACAD_OWN'
  and c.table_name in (
        'ALUNOTIFICACIONDSP',
        'CENALUMNO',
        'CENCUENTABANCO',
        'CENCURSOEVALUACION',
        'CENFAMILIAR',
        'DESTINATARIOS',
        'MOLPREMATRICULA',
        'MOLPREMATRICULAFAMILIAR',
        'OFECENTRO',
        'OFECENTRORELACIONCOMUNIDAD',
        'OTROSDATOSDOC',
        'PERDOMICILIO',
        'PERPROFESOR',
        'PERTERCERO',
        'SEGUSUARIO',
        'TERVIA',
        'TSKPCRUNIFICARALUMNOS',
        'TSKPCRUNIFICARFAMILIARES'
      )
order by
    c.table_name,
    c.constraint_name,
    cc.position;
    
  
set lines 300 pages 200 trimspool on
col child_table   format a35
col fk_name       format a35
col parent_table  format a35
col parent_owner  format a20

select distinct
    c.table_name      as child_table,
    c.constraint_name as fk_name,
    p.owner           as parent_owner,
    p.table_name      as parent_table
from dba_constraints c
join dba_constraints p
  on p.owner = c.r_owner
 and p.constraint_name = c.r_constraint_name
where c.constraint_type = 'R'
  and c.owner = 'SIGAD_ACAD_OWN'
  and c.table_name in (
        'ALUNOTIFICACIONDSP',
        'CENALUMNO',
        'CENCUENTABANCO',
        'CENCURSOEVALUACION',
        'CENFAMILIAR',
        'DESTINATARIOS',
        'MOLPREMATRICULA',
        'MOLPREMATRICULAFAMILIAR',
        'OFECENTRO',
        'OFECENTRORELACIONCOMUNIDAD',
        'OTROSDATOSDOC',
        'PERDOMICILIO',
        'PERPROFESOR',
        'PERTERCERO',
        'SEGUSUARIO',
        'TERVIA',
        'TSKPCRUNIFICARALUMNOS',
        'TSKPCRUNIFICARFAMILIARES'
      )
order by child_table, parent_owner, parent_table;