/* 
REM    VERSION INFORMATION 
REM        FEB 17 2025
REM 
REM
REM # This SQL script uses a connect string to the ADB target defined in
REM # V_ADB_CONNECT_STRING
REM # 
REM # The credential name uses the format 
REM # <the current_dblink_owner>_<dblink_name>_CRED 
REM # 
REM # When possible the script detects the hostname, port and service_name
REM # as well if it is an Oracle database gateway dblink and sets the
REM # parameters accordingly. Else please modify the values.
REM # 
REM # Once the SQL file is created, please replace the passwords used to connect to the 
REM # DB Link owning user, the ADMIN account and the passwords for the remote database users
REM # with current values.
REM # 
REM # If you need wallets, please specify the location and/or the DN.
REM # FEB 17 2025: initial
*/




set serveroutput on
set time on
set timing on



declare
    V_ADB_CONNECT_STRING varchar2(4096) :='MYADB_MEDIUM';
    V_ADMIN_PASSWORD varchar2(512) :='<please replace this string with the real ADMIN password>';
    V_OWNER varchar2(512) :=''; 
    V_OWNER_PASSWORD varchar2(512) :=''; 
    V_DBLINK varchar2(1024) :=''; 
    V_USERNAME varchar2(2000) :='';
    V_USERNAME_PASSWORD varchar2(512) :='';  
    V_HOSTNAME varchar2(2000) :='<the hostname of the target db>'; 
    V_SERVICE_NAME varchar2(2000) :='<the service name of the remote DB>';
    V_PORT varchar2(100) := '<the port for the connections to the target database; e.g. 1521>';
    V_SSL_SERVER_CERT_DN varchar2(2000) :='<the DN value found in the server certificate - without a wallet it is null>';
    V_CREDENTIAL_NAME varchar2(2000) := '';
    V_DIRECTORY_NAME varchar2(2000) :='<directory for the cwallet.sso file; default value is data_pump_dir>';
    V_GATEWAY_LINK varchar2(5) :='FALSE';
    V_PUBLIC_LINK  varchar2(5) :='FALSE';
    V_PRIVATE_TARGET varchar2(5) :='FALSE';
    V_GATEWAY_PARAM clob;



    dyn_sql_stmt varchar2(4000);
    cnt number :=0;
    sub_cnt number :=0;    
    counter number :=0;

-- UTL_FILE
    v_path_out  varchar2(100) := 'DBLINK_OUTPUT_DIR';
    v_path_in   varchar2(100) := 'DBLINK_INPUT_DIR';
    input_value varchar2(2000) :='';
    os_dir_path varchar2(2000) :='';

    d_dblnk_owner sys.odcivarchar2list;
    cursor cur_dist_dblink is select distinct OWNER from dba_db_links order by owner;

    dblnk_owner sys.odcivarchar2list;
    dblnk_db_link sys.odcivarchar2list;
    dblnk_username sys.odcivarchar2list;
    dblnk_host sys.odcivarchar2list;
    -- removing spaces and tabs from host and transforming to upper case 
    cursor cur_dblink (input_owner varchar2) is select OWNER,DB_LINK,USERNAME,upper(replace(replace(host,' ',NULL),chr(9),NULL)) as HOST from dba_db_links where owner=input_owner order by owner, db_link;


procedure CREATE_CREDENTIAL (counter in number
                    ,V_USERNAME in varchar2
                    ,V_USERNAME_PASSWORD in varchar2
                    ,V_CREDENTIAL_NAME in varchar2
                    )
is 
begin

    dbms_output.put_line('--  ');
    dbms_output.put_line('--  ');
    dbms_output.put_line('Begin');
    dbms_output.put_line('DBMS_CLOUD.CREATE_CREDENTIAL(');
    dbms_output.put_line(' CREDENTIAL_NAME => '||CHR(39)||V_CREDENTIAL_NAME||chr(39));
    dbms_output.put_line(',USERNAME => '||CHR(39)||V_USERNAME||chr(39));
    dbms_output.put_line(',PASSWORD => '||CHR(39)||V_USERNAME_PASSWORD||chr(39)||');');
    dbms_output.put_line('end;');
    dbms_output.put_line('/');

END CREATE_CREDENTIAL;


procedure CREATE_DATABASE_LINK (counter in number
                    ,V_DBLINK in varchar2
                    ,V_HOSTNAME in varchar2
                    ,V_SERVICE_NAME in varchar2
                    ,V_PORT in varchar2
                    ,V_SSL_SERVER_CERT_DN in varchar2 
                    ,V_CREDENTIAL_NAME in varchar2
                    ,V_DIRECTORY_NAME in varchar2 
                    ,V_GATEWAY_LINK in varchar2 
                    ,V_PUBLIC_LINK  in varchar2 
                    ,V_PRIVATE_TARGET in varchar2 
                    ,V_GATEWAY_PARAM in clob
                    )
is 
begin

    dbms_output.put_line('--  ');
    dbms_output.put_line('Begin');
    dbms_output.put_line('DBMS_CLOUD_ADMIN.CREATE_DATABASE_LINK(');
    dbms_output.put_line(' DB_LINK_NAME => '||CHR(39)||V_DBLINK||chr(39));
    dbms_output.put_line(',HOSTNAME => '||CHR(39)||V_HOSTNAME||chr(39));
    dbms_output.put_line(',PORT => '||V_PORT);
    dbms_output.put_line(',SERVICE_NAME => '||CHR(39)||V_SERVICE_NAME||chr(39));
    --dbms_output.put_line('--,SSL_SERVER_CERT_DN => '||CHR(39)||V_SSL_SERVER_CERT_DN||chr(39));
    dbms_output.put_line(',CREDENTIAL_NAME => '||CHR(39)||V_CREDENTIAL_NAME||chr(39));
    --dbms_output.put_line('--,DIRECTORY_NAME => '||CHR(39)||V_DIRECTORY_NAME||chr(39));
    dbms_output.put_line(',GATEWAY_LINK => ' || V_GATEWAY_LINK );
    dbms_output.put_line(',PRIVATE_TARGET => '||V_PRIVATE_TARGET);
    dbms_output.put_line(',PUBLIC_LINK => '||V_PUBLIC_LINK);
    --dbms_output.put_line('--,V_GATEWAY_PARAM => '||CHR(39)||V_GATEWAY_PARAM||chr(39));
    dbms_output.put_line(');');
    dbms_output.put_line('end;');
    dbms_output.put_line('/');
    dbms_output.put_line('------------------------------------------------------------------------------  ');

END CREATE_DATABASE_LINK;


PROCEDURE WRITE_SQL_FILE_HEADR ( counter in number
                                )
is 
BEGIN
    dbms_output.put_line('set serveroutput on');
    dbms_output.put_line('WHENEVER OSERROR EXIT 2');
    dbms_output.put_line('--  ');
    dbms_output.put_line('spool '||to_char(counter,'fm09999')||'_CREATE_DBLINK.log');
    dbms_output.put_line('set timing on');
    dbms_output.put_line('set time on ');
    dbms_output.put_line('set echo on ');
    dbms_output.put_line('set sqlblanklines on ');
    dbms_output.put_line('SET SQLPROMPT "SQL> " ');
    dbms_output.put_line('--  ');
    dbms_output.put_line('select ''Running on:  '' || host_name, INSTANCE_NAME from V$INSTANCE;');
    dbms_output.put_line('select ''Started at:  '' || TO_CHAR(SYSDATE,''YYYY-MON-DD HH24:MI:SS'') from DUAL;');
    dbms_output.put_line('ALTER SESSION ENABLE RESUMABLE TIMEOUT 86400;');
    dbms_output.put_line('--  ');

END WRITE_SQL_FILE_HEADR;

PROCEDURE WRITE_SQL_FILE_FOOTR
is
begin
    dbms_output.put_line('--  ');
    dbms_output.put_line('exit;');
    dbms_output.put_line('--  ');
end WRITE_SQL_FILE_FOOTR;



/*  
REM ##########################################################
REM ##########################################################
REM ##########################################################
REM        M A I N   P A R T   S T A R T S    H E R E 
REM ##########################################################
REM ##########################################################
REM ##########################################################
*/
BEGIN


/*
REM ########################
REM ###  CREATE DBLINK   ###
REM ########################
*/

cnt :=0;
sub_cnt :=0;

sub_cnt :=sub_cnt +1;
counter := counter +1;

    WRITE_SQL_FILE_HEADR ( counter );
    dbms_output.put_line('--  ');
    
    open cur_dist_dblink;
    fetch cur_dist_dblink bulk collect into d_dblnk_owner;

    for j in d_dblnk_owner.first .. d_dblnk_owner.last loop
        dbms_output.put_line ('Working on DB link owner: '||d_dblnk_owner(j));
        V_OWNER_PASSWORD :='<please replace this string with the real password for the ADB user '||d_dblnk_owner(j)||'>'; 
        
        if d_dblnk_owner(j) in ('PUBLIC','SYS','SYSTEM') then 
            dbms_output.new_line;
            dbms_output.put_line ('INFO MESSAGE: Public and DB links owned by sys and system are created in ADMIN account');
            dbms_output.new_line;
            dbms_output.put_line('connect "'||'ADMIN'||'/'||V_ADMIN_PASSWORD||'"@'||V_ADB_CONNECT_STRING);
        else
            dbms_output.put_line('connect "'||d_dblnk_owner(j)||'/'||V_OWNER_PASSWORD||'"@'||V_ADB_CONNECT_STRING);            
        end if;

        open cur_dblink (d_dblnk_owner(j));
        fetch cur_dblink bulk collect into  dblnk_owner, dblnk_db_link, dblnk_username,  dblnk_host;

        for i in dblnk_db_link.first .. dblnk_db_link.last loop
            V_USERNAME_PASSWORD :='<please replace this string with the real password of the remote DB user '||dblnk_username(i)||'>';  

            if instr(dblnk_db_link(i),'.') >0 then
                V_DBLINK := substr(dblnk_db_link(i),1,instr(dblnk_db_link(i),'.')-1);
            else
                V_DBLINK :=dblnk_db_link(i);
            end if;
            
            V_CREDENTIAL_NAME := dblnk_owner(i)||'_'|| V_DBLINK || '_CRED';

            CREATE_CREDENTIAL (counter
                                , dblnk_username(i)
                                , V_USERNAME_PASSWORD
                                , V_CREDENTIAL_NAME
                              );
            if dblnk_owner(i) ='PUBLIC' then 
                V_PUBLIC_LINK :='TRUE';
            end if;     

-- Detecting GTW Links where possible
--          gateway links use HS= or HS=OK
            if instr(dblnk_host(i),'(HS=') >0 then 
                V_GATEWAY_LINK :='TRUE';
            else 
                V_GATEWAY_LINK :='FALSE';
            end if;

-- Detecting PORTS where possible
--          EZCONNECT port is after : and before /
            if instr(dblnk_host(i),':')>0 and instr(dblnk_host(i),'/')>0 then 
                v_port :=substr(substr( dblnk_host(i), 1,INSTR(dblnk_host(i), '/')-1), INSTR( dblnk_host(i), ':')+1);
--          or an ADDRESS lists port after port= and before )
            elsif instr(dblnk_host(i),'(PORT=') >0 then
                v_port :=substr (substr(dblnk_host(i),instr(dblnk_host(i),'(PORT=')+6),1,instr(substr(dblnk_host(i),instr(dblnk_host(i),'(PORT=')+6),')')-1);
            else
                V_PORT := '<not able to identify the port for the connections to the target database>';
            end if;

-- Detecting HOSTNAMES where possible
--          EZCONNECT hostname is in front and before : 
            if instr(dblnk_host(i),':')>0 and instr(dblnk_host(i),'/') >0 then 
                if REGEXP_INSTR(substr(dblnk_host(i), 1, INSTR( dblnk_host(i), ':')-1), '^(([0-9]{1}|[0-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.){3}([0-9]{1}|[0-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$')      >0 then
                    V_HOSTNAME := '<detected IP address for link '||dblnk_db_link(i)||' but ADB DB link requires a hostname>';
                else
                    V_HOSTNAME :=substr( dblnk_host(i), 1,INSTR(dblnk_host(i), ':')-1);
                end if;

--          or an ADDRESS lists hostname after host= and before )
            elsif instr(dblnk_host(i),'(HOST=') >0 then
                if  REGEXP_INSTR( substr (substr(dblnk_host(i),instr(dblnk_host(i),'(HOST=')+6),1,instr(substr(dblnk_host(i),instr(dblnk_host(i),'(HOST=')+6),')')-1), '^(([0-9]{1}|[0-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.){3}([0-9]{1}|[0-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$') >0 then
                    V_HOSTNAME := '<detected IP address for link '||dblnk_db_link(i)||' but ADB DB link requires a hostname>';  
                else  
                    V_HOSTNAME :=substr (substr(dblnk_host(i),instr(dblnk_host(i),'(HOST=')+6),1,instr(substr(dblnk_host(i),instr(dblnk_host(i),'(HOST=')+6),')')-1);
                end if;
                
            else
                V_HOSTNAME := '<not able to identify the hostname for '||dblnk_db_link(i);
            end if;

-- Detecting service_name
--          EZCONNECT service_name is AFTER /
            if instr(dblnk_host(i),':')>0 and instr(dblnk_host(i),'/') >0 then 
                V_SERVICE_NAME :=substr(dblnk_host(i), INSTR( dblnk_host(i), '/')+1);

--          or an ADDRESS lists service_name after service_name= and before )
            elsif instr(dblnk_host(i),'(SERVICE_NAME=') >0 then
                V_SERVICE_NAME :=substr (substr(dblnk_host(i),instr(dblnk_host(i),'(SERVICE_NAME=')+14),1,instr(substr(dblnk_host(i),instr(dblnk_host(i),'(SERVICE_NAME=')+14),')')-1);

            else
                V_SERVICE_NAME := '<not able to identify the remote DB service name for DB link'||dblnk_db_link(i);
            end if;


            CREATE_DATABASE_LINK (counter
                                    ,V_DBLINK 
                                    ,V_HOSTNAME 
                                    ,v_service_name
                                    ,v_port 
                                    ,v_SSL_SERVER_CERT_DN
                                    ,V_CREDENTIAL_NAME
                                    ,v_DIRECTORY_NAME 
                                    ,V_GATEWAY_LINK
                                    ,V_PUBLIC_LINK 
                                    ,V_PRIVATE_TARGET
                                    ,v_gateway_param
                                );


        end loop;
        close cur_dblink;

    end loop;
    close cur_dist_dblink;
    WRITE_SQL_FILE_FOOTR ;

end;
/


