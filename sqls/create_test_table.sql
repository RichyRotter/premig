SET SERVEROUTPUT ON
SET VERIFY OFF

DECLARE
  v_rows        NUMBER := &row_count;
  v_table_name  VARCHAR2(30) := 'BIG_TABLE_' || &session_id;
  v_exists      NUMBER;
  v_batch_size  CONSTANT NUMBER := 100000;
BEGIN
  -- Check if table exists
  SELECT COUNT(*) INTO v_exists
  FROM user_tables
  WHERE table_name = UPPER(v_table_name);

  -- Drop if exists
  IF v_exists > 0 THEN
    EXECUTE IMMEDIATE 'DROP TABLE ' || v_table_name || ' PURGE';
  END IF;

  -- Create session-specific table
  EXECUTE IMMEDIATE '
    CREATE TABLE ' || v_table_name || ' (
      id    NUMBER PRIMARY KEY,
      data  VARCHAR2(100)
    )';

  -- Populate table in batches
  FOR i IN 1 .. v_rows LOOP
    EXECUTE IMMEDIATE 'INSERT INTO ' || v_table_name || ' (id, data) VALUES (:1, :2)'
      USING i, 'Data ' || TO_CHAR(i);

    IF MOD(i, v_batch_size) = 0 THEN
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('Committed up to row ' || i);
    END IF;
  END LOOP;

  COMMIT; -- Final commit
  DBMS_OUTPUT.PUT_LINE('Created ' || v_table_name || ' with ' || v_rows || ' rows.');
END;
/

