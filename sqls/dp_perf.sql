-- Make output visible
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET TIMING ON

PROMPT === Step 1: Drop and Create Test Table ===

BEGIN
  BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE big_table PURGE';
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  DBMS_OUTPUT.PUT_LINE('Creating test table BIG_TABLE with 1000 rows...');
  EXECUTE IMMEDIATE '
    CREATE TABLE big_table NOLOGGING AS
    SELECT ROWNUM AS id, RPAD(''x'', 1000, ''x'') AS payload
    FROM dual CONNECT BY LEVEL <= 1000';

  DBMS_OUTPUT.PUT_LINE('Table created.');
END;
/

PROMPT === Step 2: Export Table Using DBMS_DATAPUMP ===

DECLARE
  h1     NUMBER;
  v_log  VARCHAR2(100) := 'big_table_exp.log';
  v_file VARCHAR2(100) := 'big_table.dmp';
BEGIN
  DBMS_OUTPUT.PUT_LINE('Starting export...');

  -- Open export job
  h1 := DBMS_DATAPUMP.OPEN(operation => 'EXPORT', job_mode => 'TABLE');

  IF h1 IS NULL THEN
    RAISE_APPLICATION_ERROR(-20001, 'Failed to open datapump export job.');
  END IF;

  -- Add dump and log files
  DBMS_DATAPUMP.ADD_FILE(h1, v_file, 'ZDM_DIR_3008009', DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE);
  DBMS_DATAPUMP.ADD_FILE(h1, v_log, 'ZDM_DIR_3008009', DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE);

  -- Export only BIG_TABLE
  DBMS_DATAPUMP.METADATA_FILTER(h1, 'NAME_LIST', '''BIG_TABLE''');

  -- Start and detach
  DBMS_DATAPUMP.START_JOB(h1);
  DBMS_DATAPUMP.DETACH(h1);

  DBMS_OUTPUT.PUT_LINE('Export complete.');
END;
/

PROMPT === Step 3: Drop Table Before Import ===

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE big_table PURGE';
  DBMS_OUTPUT.PUT_LINE('BIG_TABLE dropped before import.');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Could not drop BIG_TABLE: ' || SQLERRM);
END;
/

PROMPT === Step 4: Import Table Using DBMS_DATAPUMP ===

DECLARE
  h1     NUMBER;
  v_log  VARCHAR2(100) := 'big_table_imp.log';
  v_file VARCHAR2(100) := 'big_table.dmp';
BEGIN
  DBMS_OUTPUT.PUT_LINE('Starting import...');

  -- Open import job
  h1 := DBMS_DATAPUMP.OPEN(operation => 'IMPORT', job_mode => 'TABLE');

  IF h1 IS NULL THEN
    RAISE_APPLICATION_ERROR(-20002, 'Failed to open datapump import job.');
  END IF;

  -- Add dump and log files
  DBMS_DATAPUMP.ADD_FILE(h1, v_file, 'ZDM_DIR_3008009', DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE);
  DBMS_DATAPUMP.ADD_FILE(h1, v_log, 'ZDM_DIR_3008009', DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE);

  -- Remap schema to current user (if needed)
  DBMS_DATAPUMP.METADATA_REMAP(h1, 'REMAP_SCHEMA', USER, USER);

  -- Start and detach
  DBMS_DATAPUMP.START_JOB(h1);
  DBMS_DATAPUMP.DETACH(h1);

  DBMS_OUTPUT.PUT_LINE('Import complete.');
END;
/

PROMPT === Step 5: Verify Row Count ===

SELECT COUNT(*) AS row_count FROM big_table;

