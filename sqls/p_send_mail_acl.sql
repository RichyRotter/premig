create or replace PROCEDURE P_MAIL_ACL 
(
   v_dbuser VARCHAR2
)
as
BEGIN
  -- Allow SMTP access for user ADMIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => 'smtpout.basf.net',
    lower_port => 25,
    upper_port => 25,
    ace => xs$ace_type(privilege_list => xs$name_list('SMTP'),
                       principal_name => v_dbuser,
                       principal_type => xs_acl.ptype_db));


END P_MAIL_ACL;
