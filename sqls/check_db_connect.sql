
SET SERVEROUTPUT ON
SET VERIFY OFF
SET FEEDBACK OFF

DECLARE
    v_silent_flag     VARCHAR2(10)  := UPPER(TRIM('NO'));

    -- Actual values from session
    v_actual_user     VARCHAR2(128);
    v_actual_db       VARCHAR2(128);
    v_silent          BOOLEAN := FALSE;

    -- Additional system/session info
    v_host            VARCHAR2(128);
    v_ip              VARCHAR2(64);
    v_sid             NUMBER;
    v_serial          NUMBER;
    v_terminal        VARCHAR2(64);
    v_time            VARCHAR2(64);
    v_version         VARCHAR2(64);
    v_container       VARCHAR2(64);
    v_edition         VARCHAR2(64);
BEGIN
    -- Determine silent mode
    IF v_silent_flag IN ('Y', 'YES', 'JA') THEN
        v_silent := TRUE;
    END IF;

    -- Get actual connection context
    SELECT user INTO v_actual_user FROM dual;
    SELECT name INTO v_actual_db FROM v$database;

    -- Only proceed if connection is valid and not silent
    IF NOT v_silent THEN
        -- Gather additional session/system details
        SELECT host_name, version INTO v_host, v_version FROM v$instance;
        SELECT sys_context('USERENV','IP_ADDRESS') INTO v_ip FROM dual;
        SELECT sid, serial#, terminal
          INTO v_sid, v_serial, v_terminal
          FROM v$session WHERE audsid = sys_context('USERENV','SESSIONID');
        SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') INTO v_time FROM dual;

        BEGIN
            SELECT sys_context('USERENV','CON_NAME') INTO v_container FROM dual;
        EXCEPTION WHEN OTHERS THEN
            v_container := 'n/a';
        END;

        BEGIN
            SELECT sys_context('USERENV','SESSION_EDITION_NAME') INTO v_edition FROM dual;
        EXCEPTION WHEN OTHERS THEN
            v_edition := 'n/a';
        END;

        -- Output session information
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('         ORACLE SESSION INFORMATION                         ');
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Database Name   : ' || v_actual_db);
        DBMS_OUTPUT.PUT_LINE('Host            : ' || v_host);
        DBMS_OUTPUT.PUT_LINE('User            : ' || v_actual_user);
        DBMS_OUTPUT.PUT_LINE('IP Address      : ' || v_ip);
        DBMS_OUTPUT.PUT_LINE('SID / Serial    : ' || v_sid || ' / ' || v_serial);
        DBMS_OUTPUT.PUT_LINE('Terminal        : ' || v_terminal);
        DBMS_OUTPUT.PUT_LINE('PDB/Container   : ' || v_container);
        DBMS_OUTPUT.PUT_LINE('Edition         : ' || v_edition);
        DBMS_OUTPUT.PUT_LINE('Oracle Version  : ' || v_version);
        DBMS_OUTPUT.PUT_LINE('Login Time      : ' || v_time);
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('-');
    END IF;
END;
/	

COLUMN myprompt NEW_VALUE prompt

set termout off;
SELECT
  SYS_CONTEXT('USERENV', 'DB_NAME')         AS myprompt
FROM dual;
ser termout on;

SET SQLPROMPT '&prompt> '
