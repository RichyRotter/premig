set pages 0 feedback off verify off heading off
select
  sys_context('USERENV','INSTANCE_NAME')  as instance_name,
  sys_context('USERENV','DB_NAME')        as db_name,
  sys_context('USERENV','SERVICE_NAME')   as service_name,
  sys_context('USERENV','SERVER_HOST')    as server_host
from dual
/
