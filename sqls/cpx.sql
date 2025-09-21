
SET FEEDBACK OFF
SET ECHO OFF
SET VERIFY OFF

set linesize 200;
SET SERVEROUTPUT ON;

DECLARE
    -- Variables to store metrics
    v_db_name            VARCHAR2(50) := '';
    v_db_size_gb          NUMBER := 0;
    v_schema_count        NUMBER := 0;
    v_object_count        NUMBER := 0;
    v_feature_usage       VARCHAR2(50) := 'NOF';
    v_external_links      NUMBER := 0;
    v_rac_enabled         VARCHAR2(5) := '';
    v_rac_instances       NUMBER := 0;
    v_anz_dir             NUMBER := 0;
    v_anz_dir_sys         NUMBER := 0;
    v_backup_complexity   NUMBER := 0;
    v_security_complexity NUMBER := 0;
    v_version             VARCHAR2(50) := '';
    v_apex_usage          VARCHAR2(50) := '';
    v_line                varchar2(200) := '';
    -- Complexity level
    v_complexity_level    NUMBER := 0;
    v_category            VARCHAR2(15) := '';

BEGIN
    -- 1. Get Database Name
    SELECT name
    INTO v_db_name
    FROM v$database;

    -- 2. Check Database Size
    SELECT ROUND(SUM(bytes)/1024/1024/1024, 0)
    INTO v_db_size_gb
    FROM dba_data_files;

    -- 3. Count Schemas
    SELECT COUNT(*)
    INTO v_schema_count
    FROM dba_users
    WHERE account_status = 'OPEN';

    -- 4. Count Objects
    SELECT COUNT(*)
    INTO v_object_count
    FROM dba_objects;


    -- 6. Count External Database Links
    SELECT COUNT(*)
    INTO v_external_links
    FROM dba_db_links;

    -- 7. Check RAC Configuration
    v_rac_enabled := 'NORAC';
        v_rac_instances := 0;

    -- 8. Check Backup Complexity
    SELECT COUNT(*)
    INTO v_backup_complexity
    FROM v$rman_configuration;

    -- 9. Check Security Complexity (Wallet, TDE, Custom Profiles)
    SELECT COUNT(*)
    INTO v_security_complexity
    FROM dba_users
    WHERE profile <> 'DEFAULT';

    -- 10. Check Database Version
    SELECT version
    INTO v_version
    FROM v$instance;

    -- 11. Check APEX Usage
    BEGIN
        DECLARE
            v_table_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_table_count FROM dba_tables WHERE table_name  like 'APEX%';
            IF v_table_count > 0 THEN
                v_apex_usage := 'APEX';
            ELSE
                v_apex_usage := 'noAPEX';
            END IF;
        END;
    EXCEPTION
        WHEN OTHERS THEN
            v_apex_usage := 'ERROR';
    END;

    -- 12. directories

    SELECT count(*) into v_anz_dir
    FROM dba_directories
    where owner not in ('SYS', 'SYSTEM');

    SELECT count(*) into v_anz_dir_sys
    FROM dba_directories
    where owner in ('SYS', 'SYSTEM');


    -- Calculate Complexity Level
    v_complexity_level := 0;

    -- Add complexity based on database size
    IF v_db_size_gb >= 1000 THEN
        v_complexity_level := v_complexity_level + 2;
    ELSIF v_db_size_gb >= 500 THEN
        v_complexity_level := v_complexity_level + 1;
    END IF;

    -- Add complexity based on feature usage
    IF v_feature_usage IN ('Partitioning', 'Advanced Queuing', 'XML DB') THEN
        v_complexity_level := v_complexity_level + 2;
    ELSIF v_feature_usage IS NOT NULL THEN
        v_complexity_level := v_complexity_level + 1;
    END IF;

    -- Add complexity based on schemas and objects
    IF v_schema_count > 50 OR v_object_count > 10000 THEN
        v_complexity_level := v_complexity_level + 2;
    ELSIF v_schema_count > 10 OR v_object_count > 1000 THEN
        v_complexity_level := v_complexity_level + 1;
    END IF;

    -- Add complexity based on external links
    IF v_external_links > 10 THEN
        v_complexity_level := v_complexity_level + 2;
    ELSIF v_external_links > 0 THEN
        v_complexity_level := v_complexity_level + 1;
    END IF;

    -- Add complexity based on external links
    IF v_anz_dir > 3 THEN
        v_complexity_level := v_complexity_level + 2;
    ELSIF v_anz_dir > 0 THEN
        v_complexity_level := v_complexity_level + 1;
    END IF;

    -- Add complexity based on RAC setup
    IF v_rac_instances > 1 THEN
        v_complexity_level := v_complexity_level + 2;
    ELSIF v_rac_enabled = 'TRUE' THEN
        v_complexity_level := v_complexity_level + 1;
    END IF;

    -- Add complexity based on backup and security configuration
    IF v_backup_complexity > 2 OR v_security_complexity > 5 THEN
        v_complexity_level := v_complexity_level + 2;
    ELSIF v_backup_complexity > 0 OR v_security_complexity > 0 THEN
        v_complexity_level := v_complexity_level + 1;
    END IF;

    -- Add complexity based on database version
    IF v_version < '19.0.0.0' THEN
        v_complexity_level := v_complexity_level + 2;
    END IF;

    -- Assign Category
    CASE 
        WHEN v_complexity_level = 0 THEN v_category := 'easy';
        WHEN v_complexity_level = 1 THEN v_category := 'medium';
        WHEN v_complexity_level = 2 THEN v_category := 'difficult';
        ELSE v_category := 'very complex';
    END CASE;

    -- Print Results as a single semicolon-separated line

      -- Print Results as a single semicolon-separated line
      v_line := trim('${db_coni};' || TRIM(v_db_name) || ';' || TRIM(v_db_size_gb) || ';' || TRIM(v_schema_count) || ';' || TRIM(v_object_count) || ';' || TRIM(NVL(v_feature_usage, 'None')) || ';' || TRIM(v_external_links) || ';' || TRIM(v_rac_enabled) || ';' || TRIM(v_rac_instances) || ';' || TRIM(v_backup_complexity) || ';' || TRIM(v_security_complexity) || ';' || TRIM(v_version) || ';' || TRIM(v_apex_usage) || ';' || TRIM(v_anz_dir) || ';' ||  TRIM(v_anz_dir_sys) || ';' || TRIM(v_complexity_level));


    DBMS_OUTPUT.PUT_LINE(TRIM(v_line));
END;
/
