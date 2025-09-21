create or replace procedure FS_SHARE
(
  P_ACTION in VARCHAR2
, P_DIRECTORY_NAME IN VARCHAR2
, P_FILE_SYSTEM_NAME IN VARCHAR2
, P_NFS_SERVER IN VARCHAR2
, P_MOUNTPOINT IN VARCHAR2
, P_MOUNTSRC VARCHAR2
, P_DESCRIPTION IN VARCHAR2
) AS

/*---------------------------------------------------------
v1.0 R.Rotter - mount+test, unmount  nfs share on adb-s
----------------------------------------------------------*/

     cursor all_fs is
       SELECT file_system_name,
              file_system_location,
              directory_name
              FROM dba_cloud_file_systems
	      where lower(file_system_name) = 'fs_zdm';


     fs_location varchar2(90):= P_NFS_SERVER||':'||P_MOUNTPOINT;
     v_step varchar2(30);
     l_file         UTL_FILE.file_type;
     l_line         varchar2(100);
     l_filename     VARCHAR2(100) := 'testaccess.csv';

BEGIN

  if p_action = 'UNALL' then
       for cfs in all_fs loop
         begin
          DBMS_OUTPUT.PUT_LINE('drop '||cfs.FILE_SYSTEM_NAME||' dir='||cfs.directory_name);
          DBMS_CLOUD_ADMIN.DETACH_FILE_SYSTEM ( file_system_name => cfs.FILE_SYSTEM_NAME );
          EXECUTE IMMEDIATE 'DROP DIRECTORY '||cfs.directory_name;
          commit;
          DBMS_OUTPUT.PUT_LINE('drop done');
         exception
            when others then
              DBMS_OUTPUT.PUT_LINE(sqlerrm);
              null;
         end;
       end loop;

  else
    if p_action = 'MOUNT' then
       v_step := '001';
       EXECUTE IMMEDIATE 'CREATE DIRECTORY '||P_DIRECTORY_NAME||' AS ''X'||P_DIRECTORY_NAME||'''';
       v_step := '002';
       EXECUTE IMMEDIATE 'ALTER DATABASE PROPERTY SET ROUTE_OUTBOUND_CONNECTIONS = ''PRIVATE_ENDPOINT''';

       v_step := '003';
 --      DBMS_OUTPUT.PUT_LINE(P_NFS_SERVER);
       DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
                   host => P_NFS_SERVER,
                   ace => xs$ace_type(privilege_list => xs$name_list('connect', 'resolve'),
                   principal_name => 'ADMIN',
                   principal_type =>xs_acl.ptype_db));

       v_step := '004';
       DBMS_CLOUD_ADMIN.ATTACH_FILE_SYSTEM(
                        file_system_name => P_FILE_SYSTEM_NAME,
                        file_system_location => fs_location,
                        directory_name => P_DIRECTORY_NAME,
                        description => P_DESCRIPTION,
                        params => JSON_OBJECT('nfs_version' value 4)
                        );
       DBMS_OUTPUT.PUT_LINE('1');
    else
      if p_action = 'UNMOUNT' then
         v_step := '007';
         DBMS_CLOUD_ADMIN.DETACH_FILE_SYSTEM ( file_system_name => P_FILE_SYSTEM_NAME );
         EXECUTE IMMEDIATE 'DROP DIRECTORY '||P_DIRECTORY_NAME;
         DBMS_OUTPUT.PUT_LINE('1');
       else
         DBMS_OUTPUT.PUT_LINE('ERROR= unkown action');
      end if;
   end if;
  end if;

EXCEPTION
  WHEN OTHERS THEN
           EXECUTE IMMEDIATE 'DROP DIRECTORY '||P_DIRECTORY_NAME;
    DBMS_OUTPUT.PUT_LINE(V_STEP||' ERROR='||sqlerrm);
END FS_SHARE;
