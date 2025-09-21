                create or replace PROCEDURE P_NFS_WR_TEST 
                (
                  P_DIR IN VARCHAR2 
                , P_COUNT IN NUMBER 
                ) AS 
                  l_file       UTL_FILE.FILE_TYPE;
                  l_raw        RAW(32767);
                  l_filename   VARCHAR2(100) := 'adbvn7_testfile.txt';
                  v_bytes      INTEGER := 0;
                  v_target_mb  INTEGER := p_count; -- MB to write
                  v_start      TIMESTAMP;
                  v_end        TIMESTAMP;
                  v_secs       NUMBER;
                  v_nr         NUMBER;
                  v_mb         NUMBER;
                  v_loops      INTEGER;
                  v_filesys    varchar2(300);
                  
                  v_total_bytes INTEGER := 0;
                
                  
                BEGIN
                  DBMS_OUTPUT.PUT_LINE(' ');
                  DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------- ');
                  DBMS_OUTPUT.PUT_LINE(' ');
		  v_nr      := DBMS_RANDOM.VALUE(100, 200);
	          l_filename:='nfs_test'||to_char(v_nr)||'.txt';
                  l_file := UTL_FILE.FOPEN(p_dir, l_filename, 'wb', 32767);
                  l_raw := UTL_RAW.CAST_TO_RAW(RPAD('X', 32767, 'X')); -- 32KB block
                
                  SELECT file_system_location into v_filesys
                  FROM dba_cloud_file_systems
                  where directory_name = P_DIR
                 ;
                
                
                
                  v_loops := (v_target_mb * 1024 * 1024) / 32767;
                
                  v_start := SYSTIMESTAMP;
                
                  FOR i IN 1 .. v_loops LOOP
                    UTL_FILE.PUT_RAW(l_file, l_raw);
                    v_bytes := v_bytes + LENGTH(l_raw);
                  END LOOP;
                
                  UTL_FILE.FCLOSE(l_file);
                  v_end := SYSTIMESTAMP;
                
                  v_secs := EXTRACT(SECOND FROM (v_end - v_start)) +
                            EXTRACT(MINUTE FROM (v_end - v_start)) * 60 +
                            EXTRACT(HOUR FROM (v_end - v_start)) * 3600;
                  v_mb := ROUND(v_bytes / (1024 * 1024), 2);
                
                  DBMS_OUTPUT.PUT_LINE('Start        : ' || TO_CHAR(v_start));
                  DBMS_OUTPUT.PUT_LINE('-- WRITE STATS ---');
                  DBMS_OUTPUT.PUT_LINE('Share        : ' || v_filesys);
                  DBMS_OUTPUT.PUT_LINE('MB Written   : ' || v_mb);
                  DBMS_OUTPUT.PUT_LINE('Duration     : ' || TO_CHAR(v_end - v_start));
                  DBMS_OUTPUT.PUT_LINE('Throughput   : ' || ROUND(v_mb / v_secs, 2) || ' MB/sec');
                  
                  
                    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- READ STATS ---');
                
                  v_start := SYSTIMESTAMP;
                
                  l_file := UTL_FILE.FOPEN(p_dir, l_filename, 'rb', 32767);
                
                  LOOP
                    BEGIN
                      UTL_FILE.GET_RAW(l_file, l_raw, 32767);
                      v_total_bytes := v_total_bytes + LENGTHB(l_raw);
                    EXCEPTION
                      WHEN NO_DATA_FOUND THEN
                        EXIT;
                      WHEN OTHERS THEN
                        DBMS_OUTPUT.PUT_LINE('Read error: ' || SQLERRM);
                        EXIT;
                    END;
                  END LOOP;
                
                  UTL_FILE.FCLOSE(l_file);
                  v_end := SYSTIMESTAMP;
                
                  v_secs := EXTRACT(SECOND FROM (v_end - v_start)) +
                            EXTRACT(MINUTE FROM (v_end - v_start)) * 60 +
                            EXTRACT(HOUR FROM (v_end - v_start)) * 3600;
                  v_mb := ROUND(v_total_bytes / (1024 * 1024), 2);
                
                  DBMS_OUTPUT.PUT_LINE('Share        : ' || v_filesys);
                  DBMS_OUTPUT.PUT_LINE('MB Read      : ' || v_mb);
                  DBMS_OUTPUT.PUT_LINE('Duration     : ' || TO_CHAR(v_end - v_start));
                  DBMS_OUTPUT.PUT_LINE('Throughput   : ' || ROUND(v_mb / v_secs, 2) || ' MB/sec');
                  DBMS_OUTPUT.PUT_LINE('End          : ' || TO_CHAR(v_end));
                  DBMS_OUTPUT.PUT_LINE(' ');
                  DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------- ');
                  DBMS_OUTPUT.PUT_LINE(' ');
                
                
                END P_NFS_WR_TEST;

