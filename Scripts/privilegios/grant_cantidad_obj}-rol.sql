-- ===================================================
-- &role_name will be "enter value for 'role_name'".
-- sample code:   define role_name=&role_name
-- sample code:   where role like '%&&role_name%'
-- Cantidad de objetos relacionadas al role
-- ===================================================


define role_name=&role_name

select * from ROLE_ROLE_PRIVS where ROLE = '&&role_name';
select * from ROLE_SYS_PRIVS  where ROLE = '&&role_name';


select role, privilege,count(*)
 from ROLE_TAB_PRIVS
where ROLE = '&&role_name'
group by role, privilege
order by role, privilege asc
;
