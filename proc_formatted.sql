/*
 * File: proc.sql
 * Purpose: Standardized spacing only (tabs→spaces, normalized EOLs, trimmed trailing whitespace, collapsed blank lines).
 * Note: NO code changes, only whitespace.
 * Generated: 2025-09-29 10:54:49 -0300
 * Author: ChatGPT (assistant)
 */

--------------------------------------------------------
--  Datei erstellt -Montag-September-29-2025
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Procedure LNKTST
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."LNKTST"
(
  linkname IN VARCHAR2
) AS
      status_message VARCHAR2(100);
BEGIN
    -- Attempt to select from DUAL using the database link
    BEGIN
        EXECUTE IMMEDIATE 'SELECT * FROM dual@' || linkname;
        status_message := 'Connection to link ' || linkname || ' succeeded.';
    EXCEPTION
        WHEN OTHERS THEN
            -- Catch any exception and set failure message
            status_message := 'Connection to link ' || linkname || ' failed. Error: ' || SQLERRM;
    END;

    -- Output the result
    DBMS_OUTPUT.PUT_LINE(status_message);

END LNKTST;

/
--------------------------------------------------------
--  DDL for Procedure P_ADD_NEW_ORACLEDB
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_ADD_NEW_ORACLEDB" AS
    ------------------------------------------------------------------------
    -- Procedure: P_ADD_NEW_ORACLEDB
    -- Purpose  : Add missing Oracle DBs from MIG_XADD_ORACLEDBS
    --            using metadata from MASTERDATA.ORACLE_OVERVIEW
    ------------------------------------------------------------------------

    -- Cursor to retrieve list of databases to add
    CURSOR c_newdb IS
        SELECT oracledb FROM mig_xadd_oracledbs;

    CURSOR c_migdb IS
        SELECT oracledb FROM mig_database
        where db_target_guid is null;

    -- Variables
    v_mig_database    mig_database%ROWTYPE;
    v_ma_dbinfo       masterdata.ORACLE_OVERVIEW%ROWTYPE;
    v_step            VARCHAR2(5);
    v_ret             number;

    -- Statistics counters
    v_total_count         PLS_INTEGER := 0;
    v_success_count       PLS_INTEGER := 0;
    v_not_found_count     PLS_INTEGER := 0;
    v_insert_error_count  PLS_INTEGER := 0;

BEGIN
    ------------------------------------------------------------------------
    -- Step 01: Freeze all existing MIG_DATABASE entries
    ------------------------------------------------------------------------
    v_step := '01';

    delete from mig_database where status = 'NEW ADDED';
    UPDATE mig_database SET frozen = 'Y';
    commit;
    ------------------------------------------------------------------------
    -- Step 02: Loop over all new databases
    ------------------------------------------------------------------------
    v_step := '02';

    FOR newdb IN c_newdb LOOP
        v_total_count := v_total_count + 1;

        BEGIN
            ----------------------------------------------------------------
            -- Step 03: Read metadata from ORACLE_OVERVIEW
            ----------------------------------------------------------------
            v_step := '03';

            SELECT *
              INTO v_ma_dbinfo
              FROM masterdata.ORACLE_OVERVIEW
             WHERE LOWER(mw_name) = LOWER(newdb.oracledb)
             FETCH FIRST ROW ONLY;

            ----------------------------------------------------------------
            -- Step 04: Initialize v_mig_database fields
            ----------------------------------------------------------------
            v_step := '04';

            -- Reset all fields
            v_mig_database := NULL;

            -- Defaults
            v_mig_database.frozen         := 'N';
            v_mig_database.cpat_flag      := 'N';

            -- Mapped fields
            v_mig_database.oracledb             := v_ma_dbinfo.mw_name;
            v_mig_database.dns_name             := v_ma_dbinfo.dns_name;
            v_mig_database.ip_address           := v_ma_dbinfo.ip_address;
            v_mig_database.port_number          := v_ma_dbinfo.port_number;
            v_mig_database.oracle_osn           := v_ma_dbinfo.oracle_osn;
            v_mig_database.oracle_osn_alias     := v_ma_dbinfo.oracle_osn_alias;
            v_mig_database.service_category     := v_ma_dbinfo.service_category;
            v_mig_database.ora_charset          := v_ma_dbinfo.ora_charset;
            v_mig_database.sga_gb               := v_ma_dbinfo.sga;
            v_mig_database.dbname               := v_ma_dbinfo.mw_real_sid;
            v_mig_database.confidential         := v_ma_dbinfo.hbi;

            -- Remaining fields not found in source set to NULL/default
            v_mig_database.dbaccess              := NULL;
            v_mig_database.last_run              := NULL;
            v_mig_database.status                := 'NEW ADDED';
            v_mig_database.dbuser                := NULL;
            v_mig_database.con_id                := s1.nextval;
            v_mig_database.info                  := NULL;
            v_mig_database.dbc_tr_id             := NULL;
            v_mig_database.db_target_guid        := NULL;
            v_mig_database.cpat_target           := NULL;
            v_mig_database.cpat_migration        := NULL;
            v_mig_database.db_type               := NULL;
            v_mig_database.cdb_oracledb          := NULL;
            v_mig_database.cdb_target_guid       := NULL;
            v_mig_database.host_target_guid      := NULL;
            v_mig_database.test_flag             := NULL;
            v_mig_database.environment           := v_ma_dbinfo.mw_status;
            v_mig_database.alloc_gb              := NULL;
            v_mig_database.pga_gb                := NULL;
            v_mig_database.anz_cores             := NULL;
            v_mig_database.anz_ecpus             := NULL;
            v_mig_database.target_platform       := NULL;
            v_mig_database.justification         := NULL;
            v_mig_database.avg_used_cores        := NULL;
            v_mig_database.used_gb               := NULL;
            v_mig_database.cpu_count_init_par    := NULL;
            v_mig_database.anz_db_links          := NULL;
            v_mig_database.azure_upload_min      := NULL;
            v_mig_database.cpat_action_pct       := NULL;
            v_mig_database.migration_methode     := NULL;
            v_mig_database.max_downtime_we_hrs   := NULL;
            v_mig_database.max_downtime_wd_hrs   := NULL;
            v_mig_database.ha_id                 := NULL;
            v_mig_database.data_classification   := NULL;
            v_mig_database.scenrio               := NULL;
            v_mig_database.cur_dg_type           := NULL;
            v_mig_database.cur_dg_remote_guid    := NULL;
            v_mig_database.prov_rac              := NULL;
            v_mig_database.businessappl          := NULL;
            v_mig_database.db_primkey            := s1.nextval;
            v_mig_database.ipadr                 := NULL;
            v_mig_database.in_pilot              := NULL;
            v_mig_database.sdd_env               := NULL;
            v_mig_database.sdd_data_class        := NULL;
            v_mig_database.cpat_db_version       := NULL;
            v_mig_database.target_db_name        := NULL;
            v_mig_database.agreed_mig_methode    := NULL;
            v_mig_database.agreed_mig_art        := NULL;
            v_mig_database.target_tns_alias      := NULL;

            ----------------------------------------------------------------
            -- Step 05: Insert into MIG_DATABASE
            ----------------------------------------------------------------
            v_step := '05';
            BEGIN
                INSERT INTO mig_database VALUES v_mig_database;
                v_success_count := v_success_count + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    v_insert_error_count := v_insert_error_count + 1;
                    DBMS_OUTPUT.put_line('[ERROR] Failed to INSERT for "' || newdb.oracledb || '" - ' || SQLERRM);
            END;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_not_found_count := v_not_found_count + 1;
                DBMS_OUTPUT.put_line('[WARN] No match in ORACLE_OVERVIEW for "' || newdb.oracledb || '"');

            WHEN OTHERS THEN
                DBMS_OUTPUT.put_line('[ERROR] Unexpected failure at step ' || v_step || ' for "' || newdb.oracledb || '" - ' || SQLERRM);
        END;
    END LOOP;

    commit;
    v_ret := F_EM_LOAD_DB_STRUCTURE_DATA;

    if v_ret = 0 then

         update mig_database set
             (db_target_guid, host_target_guid) =
               (select em.db_target_guid, em.host_target_guid
                from    mig_em_sizing_structure_db em
                where lower(em.db) = lower(mig_database.oracledb))
        where mig_database.db_target_guid is null;

        p_populate_mig_database;
    else
      null; --raise 20000;
    end if;

    commit;

    ------------------------------------------------------------------------
    -- Step 99: Output summary statistics
    ------------------------------------------------------------------------
    v_step := '99';
    DBMS_OUTPUT.put_line('=== MIGRATION SUMMARY ===');
    DBMS_OUTPUT.put_line('  Total candidates     : ' || v_total_count);
    DBMS_OUTPUT.put_line('  Successfully added   : ' || v_success_count);
    DBMS_OUTPUT.put_line('  Metadata not found   : ' || v_not_found_count);
    DBMS_OUTPUT.put_line('  Insert errors        : ' || v_insert_error_count);
    DBMS_OUTPUT.put_line('=========================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.put_line('[FATAL] Unhandled exception at step ' || v_step || ' - ' || SQLERRM);
END P_ADD_NEW_ORACLEDB;

/
--------------------------------------------------------
--  DDL for Procedure P_CLASSIFY_DBS
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_CLASSIFY_DBS" AS
/*
v1.0 sept24
-decides on rules whats the best target platform for the each <database
*/

  v_count               number :=0;
  v_error               number :=0;
  v_upd                 number :=0;
  v_lim                 number :=0;
  v_exa                 number :=0;
  v_adb                 number :=0;
  v_tbd                 number :=0;
  v_rac                 number :=0;
  v_guid                varchar2(60);
  v_max_value           number := 0;
  v_lim_atps            mig_infran_param_technical_limits%ROWTYPE;

   cursor  c_appv2 is
 SELECT
    "BusinessAppl" as appl,
    "OracleDB"     as prod_db,
    "QA DB"        as qa_db,
    "Dev DB"       as dev_db
FROM
    masterdata.modernex_1st_scope
where     "Environment" = 'Production'
;
   cursor c_migdb (v_prod_db varchar2) is
       select lower(oracledb),
              target_platform
       from mig_database
       where lower(oracledb)=lower(v_prod_db);

  -- limit cursor
  cursor c_adb_ranges is
    SELECT
        metric_column,
        vstart,
        vends,
        active
    FROM
     mig_infran_param_adbs_ranges
    where active= 'Y';

BEGIN
  p_log ('mig','Start classify mig_database');

  update mig_control set status = 'Running'
  where nr = 25;
  commit;

  update mig_database
         set target_platform = 'TBD',
             ha_id = null,
             justification = null
  where frozen ='N';

  commit;

  -- read atps limits
  select * into v_lim_atps
  from  mig_infran_param_technical_limits
  where target_config ='ATPS';

-- rule 27 -- exad-fixstarter

if f_is_rule_active(27) =  1 then
   UPDATE mig_database
  SET
    target_platform = 'EXAD',
    justification = 'Rule27: EXA-D Fixstarter'
  where
    LOWER(mig_database.oracledb) in (
        select lower(a.oracledb)
        from mig_infran_param_exad_fixstarter a);

    p_log('mig', 'Rule 27 upd1: ' || to_char(sql%ROWCOUNT));
ELSE
    p_log('mig', 'Rule 27 DISABLED ');
end if;

-- rule 28 -- ATPS Low fruits

if f_is_rule_active(28) =  1 then
UPDATE MIG_DATABASE
SET
    target_platform = 'ATPS',
    justification = 'Rule28: ATPS Low Fruit'
WHERE
    MIG_DATABASE.DB_PRIMKEY IN (
    SELECT A.DB_PRIMKEY
        FROM  mig_database_migration_classification b,
              MIG_CPAT_LOW_FRUITS A
        WHERE dbc_complexity_group = 1
          and b.dbc_db_primkey = A.DB_PRIMKEY
          and A.ANZ_DB_LINKS = 0
          AND A.ANZ_MEDIA_DATA_TYPES_ADB = 0
          AND A.ANZ_external_TABLES_SERVERLESS = 0
          AND A.ANZ_TABLES_WITH_XMLTYPE_COLUMN = 0
          AND A.ANZ_XMLTYPE_TABLES = 0    )
  AND target_platform = 'TBD'
  ;

    p_log('mig', 'Rule 28 upd: ' || to_char(sql%ROWCOUNT));
ELSE
    p_log('mig', 'Rule 28 DISABLED ');
end if;

-- rule 28 -- compley should go exa

if f_is_rule_active(29) =  1 then

/*
UPDATE MIG_DATABASE
SET
    target_platform = 'EXAD',
    justification = 'Rule29: complex migr'
WHERE
    MIG_DATABASE.DB_PRIMKEY IN (
        SELECT A.DB_PRIMKEY
        FROM MIG_CPAT_LOW_FRUITS A
        WHERE ( A.ANZ_MEDIA_DATA_TYPES_ADB +
                A.ANZ_EXTERNAL_TABLES_SERVERLESS +
                A.ANZ_TABLES_WITH_XMLTYPE_COLUMN +
                A.ANZ_XMLTYPE_TABLES ) > 0
        or      A.ANZ_DB_LINKS > 5
    )
  AND target_platform = 'TBD'
  AND cpat_action_pct > v_lim_atps.MAX_CPAT_ACTION_CPT_ON_ADB;

*/
UPDATE MIG_DATABASE
SET
    target_platform = 'EXAD',
    justification = 'Rule29: complex migr'
WHERE target_platform = 'TBD'
and lower(oracledb) in (
             select lower(db_name)
             from mig_orcl_exad)
and db_primkey in (
             select a.dbc_db_primkey
             from  mig_database_migration_classification a
             where a.dbc_complexity_group  > 2)
;

    p_log('mig', 'Rule 29 upd: ' || to_char(sql%ROWCOUNT));
ELSE
    p_log('mig', 'Rule 29 DISABLED ');
end if;

-- rule1: service category:
if f_is_rule_active(1) =  1 then
   UPDATE mig_database
  SET
    target_platform = 'EXAD',
    justification = 'Rule01: Service-Category Gold'
      where
    service_category like 'GOL%';
    p_log('mig', 'Rule 1 upd: ' || to_char(sql%ROWCOUNT));
ELSE
    p_log('mig', 'Rule 1 DISABLED ');
end if;

-- RULE "2": ADB-S ranges
if f_is_rule_active(2) =  1 then

   for xadbr in c_adb_ranges loop

  UPDATE MIG_DATABASE
  SET target_platform = 'EXAD',
    justification = 'Rule02: EXCEEDS ' || xadbr.metric_column
  WHERE EXISTS (
    SELECT 1
    FROM (
        SELECT target_guid, metric_column, AVG(average) AS avg_value
        FROM MIG_EM_METRIC_DB_HRS
        GROUP BY target_guid, metric_column
    ) metric_data
    WHERE metric_data.target_guid = MIG_DATABASE.db_target_guid
      AND metric_data.avg_value > xadbr.vends
      AND LOWER(metric_data.metric_column) = LOWER(xadbr.metric_column)
  )
  AND MIG_DATABASE.target_platform = 'TBD';

       p_log('mig', 'Rule 02 upd: '||xadbr.metric_column ||'='|| to_char(sql%ROWCOUNT));
   end loop;
ELSE
    p_log('mig', 'Rule 30 DISABLED ');
end if;

if f_is_rule_active(3) =  1 then

   UPDATE mig_database
  SET
    target_platform = 'EXAD',
    justification = 'Rule03: Amount of Storage'
  where
    alloc_gb > v_lim_atps.adb_max_storage
  and target_platform = 'TBD';

     p_log('mig', 'Rule 3 upd1: ' || to_char(sql%ROWCOUNT));

end if;

-- rule4: amount of cpu:
if f_is_rule_active(4) =  1 then

   UPDATE mig_database
  SET
    target_platform = 'EXAD',
    justification = 'Rule04: Amount of CPU'
  where
    anz_ecpus > v_lim_atps.adb_max_ecpu
  and target_platform = 'TBD';

      p_log('mig', 'Rule 4 upd1: ' || to_char(sql%ROWCOUNT));

end if;

-- rule5: infra limits
if f_is_rule_active(5) =  1 then

      update mig_database set
         target_platform = 'EXAD',
         justification = 'Rule05: infra limits'
      where target_platform = 'TBD'
      and mig_database.db_target_guid in ( select distinct a.db_target_guid
                                           FROM  mig_calc_db_exeeds_limit a
                                           where a.target_config = 'ATPS')
    ;

  p_log('mig', 'Rule 5 upd1: ' || to_char(sql%ROWCOUNT));

 end if;

 ---------- atps

     UPDATE mig_database
   SET
      target_platform = 'ATPS',
      justification = 'Rule99: ATPS:    left over for ADB-s'
   WHERE target_platform = 'TBD';

    p_log('mig', 'Rule ATPS upd1: ' || to_char(sql%ROWCOUNT));

if f_is_rule_active(7) =  1 then

   update mig_database set ha_id = 'DG'
       where TARGET_platform='ATPS'
   AND SERVICE_CATEGORY like 'GOLD%'
   and environment like 'P%';

    p_log('mig', 'Rule 7-1 upd1: ' || to_char(sql%ROWCOUNT));

   update mig_database set ha_id = 'DG'
       where TARGET_platform='EXAD'
   AND SERVICE_CATEGORY lIke 'GOLD%'
   and environment like 'P%';

    p_log('mig', 'Rule 7-2 upd1: ' || to_char(sql%ROWCOUNT));

end if;

   UPDATE mig_database
     SET prov_rac = null
   where target_platform = 'EXAD';

   select count(*) into v_RAC
   from mig_database
   where prov_rac is not null
   and target_platform = 'EXAD';

    p_log('mig', 'prov_rac: ' || to_char(V_RAC));

-- rule8 : RAC for all exad
if f_is_rule_active(8) =  1 then
   UPDATE mig_database
     SET prov_rac = 'RAC'
   where target_platform = 'EXAD';

    p_log('mig', 'Rule 8 upd1: ' || to_char(sql%ROWCOUNT));

end if;
   select count(*) into v_RAC
   from mig_database
   where prov_rac is not null
   and target_platform = 'EXAD';

    p_log('mig', 'prov_rac: ' || to_char(V_RAC));

-- rule9 : RAC for prod only
if f_is_rule_active(9) =  1 then
   UPDATE mig_database
     SET prov_rac = 'RAC'
     where target_platform = 'EXAD'
   and instr (environment, 'P') > 0;

      p_log('mig', 'Rule 9 upd1: ' || to_char(sql%ROWCOUNT));

end if;
   select count(*) into v_RAC
   from mig_database
   where prov_rac is not null
   and target_platform = 'EXAD';

    p_log('mig', 'prov_rac!: ' || to_char(V_RAC));

  select count(*) into v_RAC
   from mig_database
   where prov_rac is not null
   and target_platform = 'EXAD';

    p_log('mig', 'prov_rac: ' || to_char(V_RAC));

-- rule application: all db of application which have  db already on exa ---> move as well

select count(*) into v_exa from mig_database where target_platform = 'EXAD';
select count(*) into v_adb from mig_database where target_platform = 'ATPS';
select count(*) into v_tbd from mig_database where target_platform = 'TBD';

p_log ('mig','Anz exa before appl rule: ' || to_char(v_exa));
p_log ('mig','Anz adb before appl rule: ' || to_char(v_adb));
p_log ('mig','Anz tbd before appl rule: : ' || to_char(v_tbd));

if f_is_rule_active(6) =  1 then

    for xapp in c_appv2 loop
      for xdb in c_migdb(xapp.prod_db) loop
           if xapp.qa_db is not null
           then
             begin
                 update mig_database set target_platform = xdb.target_platform,
                                        businessappl =  xapp.appl,
                                        justification = 'Rule06: same plattform as '||xapp.prod_db
                where lower(oracledb)=lower(xapp.qa_db);
             exception
               when others then
                   p_log ('mig','06applerror ' || xapp.prod_db || ' dev qa not found '|| xapp.qa_db);
             end;
           end if;

           if xapp.dev_db is not null
           then
             begin
                update mig_database set target_platform = xdb.target_platform,
                                        businessappl =  xapp.appl,
                                        justification = 'Rule06: same plattform as '||xapp.prod_db
                where lower(oracledb)=lower(xapp.dev_db);
             exception
               when others then
                   p_log ('mig','06applerror ' || xapp.prod_db || ' dev db not found '|| xapp.dev_db);
             end;
           end if;
      end loop;
      update mig_database set businessappl =  xapp.appl
      where lower(oracledb)=lower(xapp.prod_db);
   end loop;
end if;

commit;

select count(*) into v_exa from mig_database where target_platform = 'EXAD';
select count(*) into v_adb from mig_database where target_platform = 'ATPS';
select count(*) into v_tbd from mig_database where target_platform = 'TBD';

p_log ('mig','Anz exa: ' || to_char(v_exa));
p_log ('mig','Anz adb: ' || to_char(v_adb));
p_log ('mig','Anz tbd: ' || to_char(v_tbd));
p_log ('mig','Ende classify db');

  update mig_control set status = 'finished'
  where nr = 25;

commit;
EXCEPTION
    WHEN OTHERS THEN
        rollback;
        p_log ('mig','Ende classify db: An error occurred: ' || SQLERRM);
               update mig_control set status = 'finished with errors'
       where nr  = 25;
        commit;
END P_classify_dbs                  ;

/
--------------------------------------------------------
--  DDL for Procedure P_COMPLETE_DEPLOYMENT
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_COMPLETE_DEPLOYMENT" AS
 v_ret number;
BEGIN

  update mig_control set status = null;
  delete from mig_log;
  commit;
  p_start_calculation;
  p_deploy_infran;
  commit;
  v_ret := F_LOG_TO_DBMS_OUT;
END P_COMPLETE_DEPLOYMENT;

/
--------------------------------------------------------
--  DDL for Procedure P_CPU_P90
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_CPU_P90" AS

    v_count            NUMBER := 0;
    v_cpu              NUMBER := 0;
    v_mem              NUMBER := 0;
    v_io               NUMBER := 0;
    v_nofound          NUMBER := 0;
    v_host_cores       number := 12;

BEGIN
   p_log ('mig', 'Start pop. Mig cpu load ');

    delete from mig_em_metric_db_hrs
    where metric_column = 'DB_cpup90';

 insert into mig_em_metric_db_hrs (
    target_guid,
    target_name,
    target_type,
    metric_label,
    column_label,
    metric_name,
    metric_column,
    rollup_timestamp_utc,
    minimum,
    maximum,
    average,
    standard_deviation,
    sample_count,
    rollup_ts)
(
SELECT
    cdb_target_guid,
    cdb_original,
    'oracle database',
    'metric',
    'metric',
    'metric',
    'DB_cpup90',
    to_char(rollup_timestamp_utc,'YYYY-MM-DD HH24:MI:SS'),
    minimum,
    maximum,
    average,
    standard_deviation,
    sample_count,
    rollup_timestamp_utc
FROM
    mig_xt_metric_db_vcpu
);

p_log('mig', 'p90 Anz cpu: ' || to_char(sql%ROWCOUNT));

END P_CPU_P90;

/
--------------------------------------------------------
--  DDL for Procedure P_CR_CPU_LOAD
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_CR_CPU_LOAD" AS

    v_count            NUMBER := 0;
    v_found            NUMBER := 0;
    v_nofound          NUMBER := 0;
    v_orig_nofound     number := 0;
    v_avg_cores_sec    NUMBER := 0;
    v_host_cores       NUMBER := 12;
    v_pct              NUMBER := 0;
    v_duration_sec     NUMBER := 3600;
    v_avg_active_cores NUMBER := 0;

    CURSOR c_dbload IS
        SELECT
           target_guid,
           target_name,
           target_type,
           metric_column,
           rollup_timestamp_utc,
           minimum,
           maximum,
           average,
           average/100 avg_fraction,
           sample_count,
           rollup_ts
        FROM mig_em_metric_db_hrs
        where metric_column = 'cpu_time_pct'
        --fetch first 100 rows only
        ;

BEGIN
    p_log('mig', 'Start calc cpu load based on: cpu_time_pct');

    delete from mig_em_metric_db_hrs
    where  metric_column = 'dbcpu_from_pct';
    commit;

    -- load

    for xdl in c_dbload loop
          -- load cpu data

          v_count := v_count + 1;

          v_host_cores := f_fetch_host_cores (xdl.target_guid, 'DB');

          if nvl(v_host_cores,0) > 0 then

              v_avg_active_cores := (v_host_cores/100) * xdl.average;

              insert into mig_em_metric_db_hrs (target_guid, target_name,target_type,
                     metric_label, column_label, metric_name, metric_column, rollup_timestamp_utc,
                     minimum,maximum,average,standard_deviation,sample_count,rollup_ts)
              VALUES (xdl.target_guid, xdl.target_name, xdl.target_type,
                      'calculated','calculated','calculated','dbcpu_from_pct',xdl.rollup_timestamp_utc,
                      round(v_avg_active_cores,3),round(v_avg_active_cores,3),round(v_avg_active_cores,3),0,xdl.sample_count,xdl.rollup_ts);

              v_found := v_found + 1;
          else
             v_nofound := v_nofound + 1;
          end if;
    end loop;
    COMMIT;

    v_nofound := v_found - v_count;

    p_log('mig', 'Anz load data:             ' || to_char(v_count));
    p_log('mig', 'Anz gewschriebene cpudata: ' || to_char(v_found));
    p_log('mig', 'nofpund iorig metric data: ' || to_char(v_orig_nofound));
    p_log('mig', 'Start calc cpu load based on: cpu_time_pct');
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        p_log('mig', 'pop. cpu load: An error occurred: ' || sqlerrm);
        COMMIT;
END p_cr_cpu_load;

/
--------------------------------------------------------
--  DDL for Procedure P_CR_CPU_LOAD_V2
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_CR_CPU_LOAD_V2" AS

    v_count            NUMBER := 0;
    v_found            NUMBER := 0;
    v_nofound          NUMBER := 0;
    v_orig_nofound     number := 0;
    v_avg_cores_sec    NUMBER := 0;
    v_host_cores       NUMBER := 12;
    v_pct              NUMBER := 0;
    v_duration_sec     NUMBER := 3600;
    v_avg_active_cores NUMBER := 0;

    cursor c_dbload is
     SELECT
        cdb_cohort,
        cdb_target_guid   target_guid,
        cdb_original      target_name,
        'oracle_database' target_type,
        metric            metric_column,
        average,
        to_char(rollup_timestamp_utc, 'YYYY-MM-DD HH24:MI;SS')  rollup_timestamp_utc,
        rollup_timestamp_utc rollup_ts
    FROM
       mig_xt_metric_db_vcpu
       where metric = 'DB vCPU'
       --fetch first 100 rows only
       ;

BEGIN
    p_log('mig', 'Start calc cpu load based on: cpu_time_pct');

    delete from mig_em_metric_db_hrs
    where  metric_column = 'DB_vCPU';
    commit;

    -- load

    for xdl in c_dbload loop
          -- load cpu data

          v_count := v_count + 1;
              insert into mig_em_metric_db_hrs (target_guid, target_name,target_type,
                     metric_label, column_label, metric_name, metric_column, rollup_timestamp_utc,
                     minimum,maximum,average,standard_deviation,sample_count,rollup_ts)
              VALUES (xdl.target_guid, xdl.target_name, xdl.target_type,
                      'calculated','calculated','calculated','DB_vCPU',xdl.rollup_timestamp_utc,
                      round(xdl.average,3),round(xdl.average,3),round(xdl.average,3),0,1,xdl.rollup_ts);
    end loop;
    COMMIT;

    v_nofound := v_found - v_count;

    p_log('mig', 'Anz load data:             ' || to_char(v_count));
    p_log('mig', 'Anz gewschriebene cpudata: ' || to_char(v_found));
    p_log('mig', 'nofpund iorig metric data: ' || to_char(v_orig_nofound));
    p_log('mig', 'Start calc cpu load based on: cpu_time_pct');
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        p_log('mig', 'pop. cpu load: An error occurred: ' || sqlerrm);
        COMMIT;
END p_cr_cpu_load_v2;

/
--------------------------------------------------------
--  DDL for Procedure P_CR_CPU_LOAD_V3
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_CR_CPU_LOAD_V3" AS

    v_count            NUMBER := 0;
    v_found            NUMBER := 0;
    v_nofound          NUMBER := 0;
    v_host_cores       number := 12;

    CURSOR c_dbload IS
    SELECT
       b.target_guid,
       b.target_name,
       b.target_type,
       b.rollup_timestamp_utc,
       to_timestamp(b.rollup_timestamp_utc, 'YYYY-MM-DD HH24:MI;SS') rollup_ts,
       b.minimum min_totc,
       b.maximum max_totc,
       b.average avg_totc,
       c.minimum min_cpct,
       c.maximum max_cpct,
       c.average avg_cpct
    FROM
        mig_em_metric_db_daily c,
        mig_em_metric_db_daily b,
        mig_database a
    where c.metric_column = 'cpu_time_pct'
     and  c.rollup_timestamp_utc = b.rollup_timestamp_utc
     and  c.target_guid = a.db_target_guid
     and  b.metric_column = 'avg_tot_cpu_usage_ps'
     and  b.target_guid = a.db_target_guid
     and  a.db_target_guid is not null
      fetch first 10 rows only
       ;

BEGIN
    p_log('mig', 'Start pop. Mig cpu load ');

/*
    select count(*) into v_found
        FROM
        mig_em_metric_db_daily b,
        mig_database a
    where b.metric_column = 'avg_tot_cpu_usage_ps'
     and  b.target_guid = a.db_target_guid
     and  a.db_target_guid is not null
          fetch first 10 rows only
     ;
*/
    delete from mig_em_metric_db_hrs
    where metric_column = 'DB_vCPUV3';

    commit;

    for xdl in c_dbload loop
          -- load cpu data
        v_count := v_count + 1;

        v_host_cores := f_fetch_host_cores (xdl.target_guid, 'DB');

        if nvl(v_host_cores,0) > 0 then

              insert into mig_em_metric_db_hrs (target_guid, target_name,target_type,
                     metric_label, column_label, metric_name, metric_column, rollup_timestamp_utc,
                     minimum,maximum,average,standard_deviation,sample_count,rollup_ts)
              VALUES (xdl.target_guid, xdl.target_name, xdl.target_type,
                      'calculated','calculated','calculated','DB_vCPUV3',xdl.rollup_timestamp_utc,
                      round(((xdl.min_totc / 100) * (xdl.min_cpct / 100) * v_host_cores),3),
                      round(((xdl.max_totc / 100) * (xdl.max_cpct / 100) * v_host_cores),3),
                      round(((xdl.avg_totc / 100) * (xdl.avg_cpct / 100) * v_host_cores),3),
                      0,1,xdl.rollup_ts);

              v_found := v_found + 1;
        else
             v_nofound := v_nofound + 1;
        end if;
    end loop;
    COMMIT;

    p_log('mig', 'Anz load data:              ' || to_char(v_count));
    p_log('mig', 'Anz geschriebene cpudata:   ' || to_char(v_found));
    p_log('mig', 'nofpund data:               ' || to_char(v_nofound));
    p_log('mig', 'Ende pop. vcpu data');
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        p_log('mig', 'pop. vcpu load: An error occurred: ' || sqlerrm);
        COMMIT;
END p_cr_cpu_load_v3;

/
--------------------------------------------------------
--  DDL for Procedure P_CR_CPU_LOAD_V4
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_CR_CPU_LOAD_V4" AS

    v_count            NUMBER := 0;
    v_cpu              NUMBER := 0;
    v_mem              NUMBER := 0;
    v_io               NUMBER := 0;
    v_nofound          NUMBER := 0;
    v_host_cores       number := 12;

BEGIN
    p_log('mig', 'Start pop. Mig cpu load ');

    delete from mig_em_metric_db_hrs
    where metric_column in ('DB_cpu_calc','pga_sga_calc','iorequests_calc');

 insert into mig_em_metric_db_hrs (
    target_guid,
    target_name,
    target_type,
    metric_label,
    column_label,
    metric_name,
    metric_column,
    rollup_timestamp_utc,
    minimum,
    maximum,
    average,
    standard_deviation,
    sample_count,
    rollup_ts)
( SELECT
    cdb_target_guid,
    cdb_original,
    'oracle database',
    'metric',
    'metric',
    'metric',
    'DB_cpu_calc',
    to_char(rollup_timestamp_utc,'YYYY-MM-DD HH24:MI:SS'),
    minimum,
    maximum,
    average,
    standard_deviation,
    sample_count,
    rollup_timestamp_utc
FROM
    mig_calc_metric_logical_core_used);

p_log('mig', 'Anz cpu: ' || to_char(sql%ROWCOUNT));

 insert into mig_em_metric_db_hrs (
    target_guid,
    target_name,
    target_type,
    metric_label,
    column_label,
    metric_name,
    metric_column,
    rollup_timestamp_utc,
    minimum,
    maximum,
    average,
    standard_deviation,
    sample_count,
    rollup_ts)
( SELECT
    cdb_target_guid,
    cdb_original,
    'oracle database',
    'metric',
    'metric',
    'metric',
    'pga_sga_calc',
    to_char(rollup_timestamp_utc,'YYYY-MM-DD HH24:MI:SS'),
    minimum / 1024,
    maximum / 1024,
    average / 1024,
    standard_deviation,
    sample_count,
    rollup_timestamp_utc
FROM
        mig_calc_metric_pga_sga_usage);

p_log('mig', 'Anz mem: ' || to_char(sql%ROWCOUNT));

 insert into mig_em_metric_db_hrs (
    target_guid,
    target_name,
    target_type,
    metric_label,
    column_label,
    metric_name,
    metric_column,
    rollup_timestamp_utc,
    minimum,
    maximum,
    average,
    standard_deviation,
    sample_count,
    rollup_ts)
( SELECT
    cdb_target_guid,
    cdb_original,
    'oracle database',
    'metric',
    'metric',
    'metric',
    'iorequests_calc',
    to_char(rollup_timestamp_utc,'YYYY-MM-DD HH24:MI:SS'),
    minimum,
    maximum,
    average,
    standard_deviation,
    sample_count,
    rollup_timestamp_utc
FROM
        mig_calc_metric_iorequests);

p_log('mig', 'Anz io : ' || to_char(sql%ROWCOUNT));

    p_log('mig', 'Ende pop. vcpu data');
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        p_log('mig', 'pop. vcpu load: An error occurred: ' || sqlerrm);
        COMMIT;
END p_cr_cpu_load_v4;

/
--------------------------------------------------------
--  DDL for Procedure P_CREATE_MIGRATION_PARAMS
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_CREATE_MIGRATION_PARAMS" AS

/*
    cursor mw_infos is
     select
       o.mw_name as oracledb,
       nvl(mc.appl, 'XX_' || o.mw_real_sid) as appl,
       nvl(mc.dep,'xXX') dep,
       o.MODERNEX_MIGRATION_CLUSTER as clust,
       CASE
          WHEN db.target_platform = 'ATPS' THEN 'ADB-S'
          ELSE 'ExaDB'
       END AS pltform,
       mc.migsc,
       mc.scat,
       mc.env as env_orig,
       CASE
          WHEN mig_tmp_classign.env = 'Production' THEN 'Prod'
          ELSE 'DTQC'
       END AS env,
       CASE
          WHEN mig_tmp_classign.dataclass = 'Confidential' THEN 'Confidential'
          ELSE 'NONE'
       END AS dataclass,
       mc.shared,
       mc.devdb,
       mc.qadb,
       mc.mtenand
   from
       masterdata.oracle_overview o,
       mig_database db
   left join
       mig_tmp_classign mc
       on lower(mc.oracledb) = lower(o.mw_name)
   where
         lower(db.oracledb) = lower(o.mw_name)
   and   o.MODERNEX_MIGRATION_CLUSTER is not null
   and   o.MODERNEX_MIGRATION_CLUSTER > 2
   ;
*/

    cursor miginfo is
     SELECT
    oracledb,
    appl,
    dep,
    clust,
    pltform,
     migsc,
    scat,
    env as env_orig,
    CASE
        WHEN mig_tmp_classign.env = 'Production' THEN 'Prod'
        ELSE 'DTQC'
    END AS env,
    CASE
        WHEN mig_tmp_classign.dataclass = 'Confidential' THEN 'Confidential'
        ELSE 'NONE'
    END AS dataclass,
    shared,
    devdb,
    qadb,
    mtenand
  FROM
    mig_tmp_classign
  where clust not in (
    'Pilot'
   ,'Cluster 1'
   ,'Cluster 2'
   )
   and oracledb not in (select dbmp_oracle_db
                               from mig_database_migration_params)
   ;

  v_mig_rec  mig_database_migration_params%ROWTYPE;

BEGIN

  -- del target tablle
  -- DELETE FROM mig_database_migration_params;
  -- commit;

  FOR m_rec IN miginfo LOOP
    begin
    v_mig_rec.dbmp_primkey               := s1.nextval;
    v_mig_rec.dbmp_oracle_db             := m_rec.oracledb;
    v_mig_rec.dbmp_target_name           := NULL;
    v_mig_rec.dbmp_target_platform       := m_rec.pltform;
    v_mig_rec.DPMP_TARGET_MIGR_METHODE   := m_rec.migsc;
    v_mig_rec.dbmp_desc                       := NULL;
    v_mig_rec.dbmp_mig_cluster                := m_rec.clust;
    v_mig_rec.dbmp_env                        := m_rec.env;
    v_mig_rec.dbmp_env_orig                   := m_rec.env_orig;
    v_mig_rec.dbmp_dataclass                  := m_rec.dataclass;
    v_mig_rec.dbmp_app_name                  := m_rec.appl;
    v_mig_rec.dbmp_shared                  := m_rec.shared;

 /*
    DBMS_OUTPUT.PUT(m_rec.pltform||' ');
    DBMS_OUTPUT.PUT(m_rec.dataclass||' ');
    DBMS_OUTPUT.PUT_LINE(m_rec.env);
*/
    select vn_sdd_vname into v_mig_rec.dbmp_vnet
    from MIG_INFRAN_DEPLOYED_VNETS
    where vn_platform = m_rec.pltform
    and   VN_DATA_CLASIFICTION = m_rec.dataclass
    and   VN_ENV = m_rec.env;

    v_mig_rec.dbmp_test_tns_alias             := 'ADB'||v_mig_rec.dbmp_vnet||'_tp';

    if m_rec.pltform = 'ExaDB' then
      v_mig_rec.dbmp_test_tns_alias := 'EXAD'||v_mig_rec.dbmp_vnet||'PDBEXAD'||v_mig_rec.dbmp_vnet||'_system';
    end if;

    if    v_mig_rec.dbmp_target_name is NULL then
        v_mig_rec.dbmp_target_name := 'ADB'||v_mig_rec.dbmp_vnet;
        if m_rec.pltform = 'ExaDB' then
             v_mig_rec.dbmp_target_name  := 'EXAD'||v_mig_rec.dbmp_vnet||'_PDBEXAD'||v_mig_rec.dbmp_vnet;
        end if;
    end if;

   v_mig_rec.dbmp_target_tns_alias             := v_mig_rec.dbmp_target_name||'_tp';

    if m_rec.pltform = 'ExaDB' then
       v_mig_rec.dbmp_target_tns_alias             := v_mig_rec.dbmp_target_name||'_system';
    end if;

     --
    exception
       when others then
         v_mig_rec.dbmp_desc := sqlerrm;
    end;

    insert into mig_database_migration_params
      values v_mig_rec;

   END LOOP;

   commit;
END P_CREATE_MIGRATION_PARAMS;

/
--------------------------------------------------------
--  DDL for Procedure P_DEPLOY_EXAD_INFRA
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_DEPLOY_EXAD_INFRA" AS
 -- for dedbug infos
 v_step_marker number := 0;
 v_procedure   varchar2(20) := 'P_deploy_EXAD_INFRA';

  --  START Predure for a complete new deployment of EXA-D
  --  deletes and recretes complete EXA-D environment

  --  constant
   v_active_scenario mig_infran_param_scenarios%ROWTYPE;

   -- variables
   quit_deployment exception;
   v_ret           number := 0;
   v_exa_ids       varchar2(200) := '';

   cursor c_loc is
       SELECT azure_dc
       FROM mig_infran_param_azure_location
       where target_platform ='EXAD';

BEGIN
 --  delete from mig_log;
   p_log('mig', 'Start deployment EXA-D Infra');
   v_step_marker := 100;

      update mig_control set status = 'Running'
    where nr = 30;
    update mig_control set status = null
    where nr > 30 and nr < 40;
    commit;

   v_step_marker := 101;

   select * into v_active_scenario
   from mig_infran_param_scenarios
   where active = 'Y';
   v_step_marker := 102;

   v_ret := f_set_status (31,'Running');
   -- delete existing
   v_step_marker := 1;
   v_ret := f_wipe_out_exa;
   if v_ret <> 0 then  raise quit_deployment; end if;

   p_log('mig', '===================================');

   -- provision cdbs
   v_step_marker := 3;
   v_ret := f_set_status (31,'finished');
   v_ret := f_set_status (32,'Running');
   v_ret := f_prov_cdb;
   if v_ret <> 0 then  raise quit_deployment; end if;
   p_log('mig', '===================================');

   -- provision cdbs_instances
   v_step_marker := 4;
   v_ret := f_set_status (32,'finished');
   v_ret := f_set_status (33,'Running');

   v_ret := f_prov_cdb_instance;
   if v_ret <> 0 then  raise quit_deployment; end if;
   p_log('mig', '===================================');
 -- provision cdbs_instances
   v_step_marker := 5;

    v_ret := f_calculate_cluster_sizes;
   if v_ret <> 0 then  raise quit_deployment; end if;
   p_log('mig', '===================================');

   v_ret := f_set_status (33,'finished');
    v_ret := f_set_status (34,'Running');

/*
   v_ret := f_set_status (34,'finished');
      v_ret := f_set_status (35,'Running');

   -- create one exa QR per location
   v_step_marker := 2;
   for xl in c_loc loop
      v_ret := F_PROV_EXA_INFRA (v_active_scenario.exa_generation,
                                 v_active_scenario.exa_nr_dbserver,
                                 v_active_scenario.exa_nr_cells,
                                 xl.azure_dc, 'EXA@'||xl.azure_dc, 1, 'N', v_exa_ids);
      p_log('mig', '===================================');

      if v_ret <> 0 then  raise quit_deployment; end if;
    end loop;

   v_step_marker := 5;
   v_ret := f_rollout_clusters;
   if v_ret <> 0 then  raise quit_deployment; end if;
   p_log('mig', '===================================');

    */
    p_log('mig', 'End deploy EXA-D Infra');
    COMMIT;
    v_ret := f_log_to_dbms_out;
      update mig_control set status = 'finished'
              where nr = 30;
       COMMIT;

EXCEPTION
    WHEN quit_deployment THEN
        ROLLBACK;
        p_log('mig', 'ERROR: '||v_procedure||' last Step='|| TO_CHAR(v_step_marker));
        p_log('mig', 'msg=' || SQLERRM);
        v_ret := f_log_to_dbms_out;

      update mig_control set status = 'finished ...Quit'
              where nr = 30;
       COMMIT;
    WHEN OTHERS THEN
        ROLLBACK;
        p_log('mig', 'ERROR: '||v_procedure||' last Step='|| TO_CHAR(v_step_marker));
        p_log('mig', 'msg=' || SQLERRM);
        v_ret := f_log_to_dbms_out;

      update mig_control set status = 'finished with error'
            where nr = 30;
        COMMIT;
END P_deploy_EXAD_INFRA;

/
--------------------------------------------------------
--  DDL for Procedure P_DEPLOY_INFRAN
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_DEPLOY_INFRAN" AS
 -- for dedbug infos
 v_step_marker number := 0;
 v_procedure   varchar2(20) := 'P_deploy_EXAD_INFRA';

  --  START Predure for a complete new deployment of EXA-D
  --  deletes and recretes complete EXA-D environment

  --  constant
   v_active_scenario mig_infran_param_scenarios%ROWTYPE;

   -- variables
   quit_deployment exception;
   v_ret           number := 0;
   v_exa_ids       varchar2(200) := '';

   cursor c_loc is
       SELECT azure_dc
       FROM mig_infran_param_azure_location
       where target_platform ='EXAD';

BEGIN
  -- delete from mig_log;
   p_log('mig', 'Start deployment EXA-D Infra');
   v_step_marker := 100;

      update mig_control set status = 'Running'
    where nr = 30;
    update mig_control set status = null
    where nr > 30 and nr < 40;
    commit;

   v_step_marker := 101;

   select * into v_active_scenario
   from mig_infran_param_scenarios
   where active = 'Y';
   v_step_marker := 102;

   v_ret := f_set_status (31,'Running');
   -- delete existing
   v_step_marker := 1;
   v_ret := f_wipe_out_exa;
   if v_ret <> 0 then  raise quit_deployment; end if;

   p_log('mig', '===================================');

   -- provision cdbs
   v_step_marker := 3;
   v_ret := f_set_status (31,'finished');
   v_ret := f_set_status (32,'Running');
   v_ret := f_prov_cdb;
   if v_ret <> 0 then  raise quit_deployment; end if;
   p_log('mig', '===================================');

   -- provision cdbs_instances
   v_step_marker := 4;
   v_ret := f_set_status (32,'finished');
   v_ret := f_set_status (33,'Running');

   v_ret := f_prov_cdb_instance;
   if v_ret <> 0 then  raise quit_deployment; end if;
   p_log('mig', '===================================');
 -- provision cdbs_instances
   v_step_marker := 5;

   v_ret := f_set_status (33,'finished');
    v_ret := f_set_status (34,'Running');

   v_ret := f_calculate_cluster_sizes;
   if v_ret <> 0 then  raise quit_deployment; end if;
   p_log('mig', '===================================');

/*
   v_ret := f_set_status (34,'finished');
      v_ret := f_set_status (35,'Running');

   -- create one exa QR per location
   v_step_marker := 2;
   for xl in c_loc loop
      v_ret := F_PROV_EXA_INFRA (v_active_scenario.exa_generation,
                                 v_active_scenario.exa_nr_dbserver,
                                 v_active_scenario.exa_nr_cells,
                                 xl.azure_dc, 'EXA@'||xl.azure_dc, 1, 'N', v_exa_ids);
      p_log('mig', '===================================');

      if v_ret <> 0 then  raise quit_deployment; end if;
    end loop;

   v_step_marker := 5;
   v_ret := f_rollout_clusters;
   if v_ret <> 0 then  raise quit_deployment; end if;
   p_log('mig', '===================================');

    */
    p_log('mig', 'End deploy EXA-D Infra');
    COMMIT;
    v_ret := f_log_to_dbms_out;
      update mig_control set status = 'finished'
              where nr = 30;
       COMMIT;

EXCEPTION
    WHEN quit_deployment THEN
        ROLLBACK;
        p_log('mig', 'ERROR: '||v_procedure||' last Step='|| TO_CHAR(v_step_marker));
        p_log('mig', 'msg=' || SQLERRM);
        v_ret := f_log_to_dbms_out;

      update mig_control set status = 'finished ...Quit'
              where nr = 30;
       COMMIT;
    WHEN OTHERS THEN
        ROLLBACK;
        p_log('mig', 'ERROR: '||v_procedure||' last Step='|| TO_CHAR(v_step_marker));
        p_log('mig', 'msg=' || SQLERRM);
        v_ret := f_log_to_dbms_out;

      update mig_control set status = 'finished with error'
            where nr = 30;
        COMMIT;
END P_deploy_INFRAN;

/
--------------------------------------------------------
--  DDL for Procedure P_FINE_LOADSTAT
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_FINE_LOADSTAT" AS
BEGIN
    p_log('mig', 'load finestatistik ... start');

    UPDATE mig_control SET status = 'Running' WHERE nr = 22;
    COMMIT;

    -- Reset counts
    UPDATE mig_calc_metrics_ranges_db
    SET
        cnt_all = NULL,
        cnt_low = NULL,
        cnt_med = NULL,
        cnt_high = NULL,
        cat = NULL;

    COMMIT;

    -- Optimized aggregation using single pass
    MERGE INTO mig_calc_metrics_ranges_db t1
    USING (
        SELECT
            t2.target_guid,
            t2.metric_column,
            COUNT(*) AS cnt_all,
            SUM(CASE WHEN t2.maximum BETWEEN r.minimum AND r.low THEN 1 ELSE 0 END) AS cnt_low,
            SUM(CASE WHEN t2.maximum BETWEEN r.low AND r.med THEN 1 ELSE 0 END) AS cnt_med,
            SUM(CASE WHEN t2.maximum > r.med THEN 1 ELSE 0 END) AS cnt_high
        FROM
            mig_em_metric_db_hrs t2
            JOIN mig_calc_metrics_ranges_db r
              ON t2.target_guid = r.target_guid
             AND t2.metric_column = r.metric_column
        GROUP BY
            t2.target_guid,
            t2.metric_column
    ) src
    ON (t1.target_guid = src.target_guid AND t1.metric_column = src.metric_column)
    WHEN MATCHED THEN UPDATE SET
        t1.cnt_all = src.cnt_all,
        t1.cnt_low = src.cnt_low,
        t1.cnt_med = src.cnt_med,
        t1.cnt_high = src.cnt_high;

    COMMIT;

    -- Update CAT based on counts
    UPDATE mig_calc_metrics_ranges_db
    SET
        cat = CASE
            WHEN cnt_high >= cnt_low AND cnt_high >= cnt_med THEN 'high'
            WHEN cnt_med >= cnt_low AND cnt_med >= cnt_high THEN 'med'
            ELSE 'low'
        END;

    -- Rebuild consolidated company-level stats
    DELETE FROM mig_calc_metrics_ranges;

    INSERT INTO mig_calc_metrics_ranges (
        metric_column,
        xmi,
        xav,
        xma,
        cnt_low,
        cnt_med,
        cnt_high,
        cnt_all
    )
    SELECT
        metric_column,
        ROUND(MIN(minimum), 3),
        ROUND(AVG(average), 3),
        ROUND(MAX(maximum), 3),
        SUM(cnt_low),
        SUM(cnt_med),
        SUM(cnt_high),
        SUM(cnt_all)
    FROM
        mig_calc_metrics_ranges_db
    GROUP BY
        metric_column;

    UPDATE mig_calc_metrics_ranges
    SET
        low = ROUND(xmi + ((xma - xmi) * 0.33), 3),
        med = ROUND(xmi + ((xma - xmi) * 0.66), 3);

    COMMIT;

    UPDATE mig_control
    SET status = 'finished'
    WHERE nr = 22;

    p_log('mig', 'load finestatistik ... end');
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        p_log('mig', 'An error occurred: ' || SQLERRM);
        UPDATE mig_control
        SET status = 'finished with errors'
        WHERE nr = 22;
        COMMIT;
END P_FINE_LOADSTAT;

/
--------------------------------------------------------
--  DDL for Procedure P_LOAD_EM_DATA
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_LOAD_EM_DATA" AS
/*
v1.0 sept24
-loads all needed em repo data into local tables
*/

    result NUMBER;
BEGIN
    update mig_control set status = 'Running'
       where nr = 10;

    delete from mig_control where nr = 90;

    insert into mig_control values
      (90,'External extract',null, 'initiated');

       commit;

    p_log('mig', 'Start pop. EM metric Data ');
/*

    result := F_em_LOAD_HOST_PROP;
    IF result != 0 THEN
         p_log('mig', 'Load EM Data - Fehler F_em_LOAD_HOST_PROP');
    END IF;
 */
    update mig_control set status = 'Loading Host Data...'
       where nr = 10;
    COMMIT;
    result := F_EM_LOAD_HOST_METRIC;
    IF result != 0 THEN
         p_log('mig', 'Load EM Data - Fehler F_EM_LOAD_HOST_METRIC');
    END IF;

    update mig_control set status = 'Loading DB Data...'
       where nr = 10;
    COMMIT;

    result := F_EM_LOAD_DB_METRIC;
    IF result != 0 THEN
         p_log('mig', 'Load EM Data - Fehler F_EM_LOAD_DB_METRIC');
    END IF;

    result := F_EM_LOAD_CPU_DAILY_DATA;
    IF result != 0 THEN
         p_log('mig', 'Load EM Data - Fehler F_EM_LOAD_CPU_DAILY_DATA');
    END IF;

    result := F_EM_LOAD_DB_STRUCTURE_DATA;
    IF result != 0 THEN
         p_log('mig', 'Load EM Data - Fehler F_EM_LOAD_DB_STRUCTURE_DATA');
    END IF;

    update mig_control set status = 'Calculatinge Metrics ...'
       where nr = 10;
    COMMIT;

    p_cr_cpu_load;
    p_cr_cpu_load_v2;
    p_cr_cpu_load_v3;

 -- PGA AND SGA FROM MB TO GB

        update mig_em_metric_db_hrs
    set maximum = maximum / 1024,
        average = average / 1024,
        minimum = minimum / 1024
    where metric_column in ('pga_total', 'sga_total', 'opt_sga_size', 'total_memory', 'total_pga_allocated');

    result := f_log_to_dbms_out;

    update mig_control set status = 'finished'
       where nr = 10;
   commit;

EXCEPTION
    WHEN OTHERS THEN
       rollback;
           update mig_control set status = 'finished with errors'
       where nr = 10;
       commit;

     -- Raise the error if function execution fails
        RAISE_APPLICATION_ERROR(-20002, 'Error ' || SQLERRM);
END P_LOAD_EM_DATA;

/
--------------------------------------------------------
--  DDL for Procedure P_LOAD_PARAMS
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_LOAD_PARAMS" AS

/*
loads all paratabels with values
sets a scenario as default

*/

BEGIN

DBMS_OUTPUT.PUT_LINE('lp in');

p_log ('load_params','Start load params');

delete from mig_infran_ha_concepts;
insert into  mig_infran_ha_concepts (
    con_id,
    adj_cores,
    adj_sga,
    adj_pga,
    adj_used_gb,
    adj_alloc_gb,
    adj_iops,
    description,
    adj_session)
values ('RAC', 1.2, 2, 2,1,1,1,'adjust before split to instaces',1);
insert into  mig_infran_ha_concepts
values ('DG', 0.2, 1, 1, 1, 1, 0.2,'just for log apply',0.2);
insert into  mig_infran_ha_concepts
values ('RAC1NODE', 1, 1, 1, 1, 1, 1,'just for log apply',0.2);

DBMS_OUTPUT.PUT_LINE('lp in');

delete from mig_infran_param_scenarios;
insert into mig_infran_param_scenarios (
   scenario_id,
    exa_generation,
    exa_nr_dbserver,
    exa_nr_cells,
    active,
    cpu_metric,
    sga_metric,
    pga_metric,
    storage_metric,
    io_metric,
    used_storage_metric,
    ecpu_multiplicator,
    read_io_metric,
    write_io_metric,
    session_metric,
    use_maximum_metrics
)
Values ( 'Standard', 'X9M', 2, 3, 'N','DB_cpu_calc','pga_sga_calc',null,'ALLOCATED_GB','iorequests_calc','USED_GB', 4, 'physreads_ps', 'physwrites_ps', 'avg_active_sessions', 'N');
insert into mig_infran_param_scenarios
Values ( 'Conservative', 'X9M', 2, 3, 'Y','regular_cpu','sga_total','pga_total','ALLOCATED_GB','iorequests_calc','USED_GB', 4, 'physreads_ps', 'physwrites_ps', 'avg_active_sessions', 'N');
insert into mig_infran_param_scenarios
Values ( 'Experimential', 'X9M', 2, 3, 'N','DB_vCPU','sga_total','pga_total','ALLOCATED_GB','iorequests_calc','USED_GB', 4, 'physreads_ps', 'physwrites_ps', 'avg_active_sessions', 'N');
insert into mig_infran_param_scenarios
Values ( 'Cons.w.max metrics', 'X9M', 2, 3, 'N','regular_cpu','sga_total','pga_total','ALLOCATED_GB','iorequests_calc','USED_GB', 4, 'physreads_ps', 'physwrites_ps', 'avg_active_sessions', 'Y');

DBMS_OUTPUT.PUT_LINE('lp in');

delete from mig_infran_param_adbs_ranges;
delete from mig_infran_param_technical_limits;

insert into mig_infran_param_adbs_ranges values ('iorequests_ps', 0, 5000, 'Y');
insert into mig_infran_param_adbs_ranges values ('ALLOCATED_GB', 0, 1000, 'Y');
insert into mig_infran_param_adbs_ranges values ('pga_total', 0,200, 'Y');
insert into mig_infran_param_adbs_ranges values ('physreads_ps',0,5000, 'Y');
insert into mig_infran_param_adbs_ranges values ('physwrites_ps',0, 2000, 'Y');
insert into mig_infran_param_adbs_ranges values ('iombs_ps',0, 30, 'Y');
insert into mig_infran_param_adbs_ranges values ('sga_total', 0, 100, 'Y');

insert into mig_infran_param_technical_limits (
    target_config,
    min_cores,
    cores_per_cluster,
    mem_per_cluster)
 values
('EXAD',1, 4, 50);

insert into mig_infran_param_technical_limits (
    target_config,
    gb_mem_per_ecpu,
    sessions_per_ecpu,
    sessions_per_phys_core,
    read_iops_per_gb,
    write_iops_per_gb,
    azure_upload_gb_sec,
    min_storage_gb,
    min_ecpu,
    ecpu_core_faktor,
    adb_core_per_instance,
    adb_max_ecpu,
    adb_max_storage,
    adb_max_wr_iops,
    adb_max_read_iops,
    adb_limit_toleranz
    )
 values
('ATPS',2,75,300,25,9,0.25,50,2,4,16,16,2000,5000,11000,1.5);

delete from mig_infran_param_exa_specs;
insert into mig_infran_paraM_exa_specs (
    generation,
    dbsrv_sockets,
    dbsrv_cpu_cores,
    dbsrv_main_memory_gb,
    cellsrv_flash_storage_tb,
    cellsrv_disk_storage_tb,
    cellsrv_network_bandwidth_gb,
    cellsrv_iops,
    dbsrv_max_vms,
    dbsrv_max_inst,
    phys_mem,
    exa_cpu_bonus_pct,
    exa_mem_bonus_pct,
    active)
values
('X9M',2, 63 , 834, 25.6 , 50.6, null, null, 8, 9999, 1390, 20, 15, 'Y');

        delete from mig_infran_param_azure_location;
insert into mig_infran_param_azure_location (
   azure_dc, target_platform, dc_nr)
VALUES ('AD@DC1','ATPS',1);
insert into mig_infran_param_azure_location (
   azure_dc, target_platform, dc_nr)
VALUES ('AD@DC2','ATPS',2);
insert into mig_infran_param_azure_location (
   azure_dc, target_platform, dc_nr)
VALUES ('AD!DC1','EXAD',1);
insert into mig_infran_param_azure_location (
   azure_dc, target_platform, dc_nr)
VALUES ('AD!DC2','EXAD',2);

/*
delete from mig_infran_param_clusters;
insert into mig_infran_param_clusters (
    azure_dc,
    target_platform,
    cluster_name,
    environments,
    service_category,
    data_classification)
values
('AD!DC1','EXAD','ProdConf','P','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','Confidential');
insert into mig_infran_param_clusters values
('AD!DC1','EXAD','Prod','P','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','null');
insert into mig_infran_param_clusters values
('AD!DC1','EXAD','DGProdConf','DG-P','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','Confidential');
insert into mig_infran_param_clusters values
('AD!DC1','EXAD','DGProd','DG-P','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','null');
insert into mig_infran_param_clusters values
('AD!DC1','EXAD','NoneProdConf','I,T,C,D','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','Confidential');
insert into mig_infran_param_clusters values
('AD!DC1','EXAD','NoneProd','I,T,C,D','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','null');
insert into mig_infran_param_clusters values
('AD!DC2','EXAD','ProdConf','P','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','Confidential');
insert into mig_infran_param_clusters values
('AD!DC2','EXAD','Prod','P','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','null');
insert into mig_infran_param_clusters values
('AD!DC2','EXAD','DGProdConf','DG-P','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','Confidential');
insert into mig_infran_param_clusters values
('AD!DC2','EXAD','DGProd','DG-P','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','null');
insert into mig_infran_param_clusters values
('AD!DC2','EXAD','NoneProdConf','I,T,C,D','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','Confidential');
insert into mig_infran_param_clusters values
('AD!DC2','EXAD','NoneProd','I,T,C,D','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','null');
*/

delete from mig_infran_param_clusters;
insert into mig_infran_param_clusters (
    azure_dc,
    target_platform,
    cluster_name,
    environments,
    service_category,
    data_classification)
values
('AD!DC1','EXAD','ProdConf','P','SILVER+,SILVER,BRONZE+,BRONZE','Confidential');
insert into mig_infran_param_clusters values
('AD!DC1','EXAD','ProdConfGold','P','GOLD,GOLD+','Confidential');
insert into mig_infran_param_clusters values
('AD!DC1','EXAD','ProdGold','P','GOLD,GOLD+','null');
insert into mig_infran_param_clusters values
('AD!DC1','EXAD','NonProd','I,T,C,D','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','null');
insert into mig_infran_param_clusters values
('AD!DC2','EXAD','NonProdConf','I,T,C,D','GOLD,SILVER+,SILVER,BRONZE+,BRONZE','Confidential');
insert into mig_infran_param_clusters values
('AD!DC2','EXAD','Prod','P','SILVER+,SILVER,BRONZE+,BRONZE','null');
insert into mig_infran_param_clusters values
('AD!DC2','EXAD','ProdGoldConf','DG-P','GOLD,GOLD+','Confidential');
insert into mig_infran_param_clusters values
('AD!DC2','EXAD','DGProd','DG-P','GOLD,GOLD+','null');

delete from mig_infran_param_rules;
insert into mig_infran_param_rules values
(1, 'Gold(+9 to EXAD', 'Y');
insert into mig_infran_param_rules values
(2, 'high io to EXAD', 'Y');
insert into mig_infran_param_rules values
(3, 'big dbs to EXAD', 'Y');
insert into mig_infran_param_rules values
(4, 'high cpu to EXAD', 'Y');
insert into mig_infran_param_rules values
(5, 'exceeds infra limit', 'Y');
insert into mig_infran_param_rules values
(6, 'application goes exad', 'N');
insert into mig_infran_param_rules values
(7, 'DG for ATPS/EXAD', 'Y');
insert into mig_infran_param_rules values
(8, 'RAC in EXA for ALL', 'N');
insert into mig_infran_param_rules values
(9, 'RAC only Prod', 'Y');
insert into mig_infran_param_rules values
(10, 'application QA;DEV DB', 'Y');
insert into mig_infran_param_rules values
(20, 'ATPS ecpu/memory ratio rule', 'Y');
insert into mig_infran_param_rules values
(21, 'ATPS ecpu/session ratio rule', 'Y');
insert into mig_infran_param_rules values
(22, 'ATPS min ecpu rule', 'Y');
insert into mig_infran_param_rules values
(23, 'ATPS read iops/storage ratio rule', 'Y');
insert into mig_infran_param_rules values
(24, 'ATPS write iops/storage ratio rule', 'Y');
insert into mig_infran_param_rules values
(25, 'ATPS min storage', 'Y');
insert into mig_infran_param_rules values
(26, 'ATPS final ecpu/memory ruöe', 'Y');

DBMS_OUTPUT.PUT_LINE('lp in');
p_log ('load_params','End load params');

commit;

END P_LOAD_PARAMS;

/
--------------------------------------------------------
--  DDL for Procedure P_LOG
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_LOG"
(
  P_WER IN VARCHAR2
, P_WAS IN VARCHAR2
) AS
BEGIN
  insert into mig_log
  values (sysdate, p_wer, p_was, s1.nextval);
  commit;
END P_LOG;

/
--------------------------------------------------------
--  DDL for Procedure P_LOW_MIGRATION_FRUITS
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_LOW_MIGRATION_FRUITS" AS

   v_counter number;
   v_counter2 number;
   v_counter3 number;
   v_primkey number;
   v_migmethode varchar2(20);

   CURSOR cdbs is
         select db_primkey
         from mig_cpat_databases
         where in_scope = 'Y';

BEGIN

    p_log('mig', '====================================');
    p_log('mig', 'Step0: create low fruits');

   DBMS_OUTPUT.PUT_LINE('Start create low fruits');
/*
   begin
      execute IMMEDIATE ('drop table MIG_CPAT_LOW_FRUITS');
   exception
     when others then
       null;
   END;
*/

   update mig_database set cpat_action_pct = 100;
  DBMS_OUTPUT.PUT_LINE('1             ='||SQL%ROWCOUNT);

   update mig_database set migration_methode = 'online', anz_db_links = 0, cpat_action_pct = 100, azure_upload_min = (round(used_gb/100,3))*60;
  DBMS_OUTPUT.PUT_LINE('2             ='||SQL%ROWCOUNT);
   update mig_database set migration_methode = 'offline'
      where (ALLOC_gb/100) < (max_downtime_we_hrs/2);
  DBMS_OUTPUT.PUT_LINE('3             ='||SQL%ROWCOUNT);

   delete from MIG_CPAT_LOW_FRUITS;
  DBMS_OUTPUT.PUT_LINE('4             ='||SQL%ROWCOUNT);

   INSERT INTO MIG_CPAT_LOW_FRUITS
(
  DB_PRIMKEY,
  OS_SYSTYPE,
  OS_NAME,
  OS_TYPE,
  OS_VERSION,
  ORACLEDB,
  ORACLESID,
  ENVIRONEMENT,
  OPERATED_FOR_COMPANY,
  SERVICE_CATEGORY,
  DNS_NAME,
  IP_ADDRESS,
  PORT_NUMBER,
  ORACLE_LISTENER,
  ORACLE_OSN,
  ORACLE_OSN_ALIAS,
  DB_LOCATION,
  DB_COUNTRYCODE,
  DB_PW,
  CONNECT_STATUS,
  CONNECT_STRING,
  IN_SCOPE,
  ANZ_ACTION_REQUIRED,
  ANZ_REVIEW_REQUIRED,
  ANZ_REVIEW_SUGGESTED,
  ANZ_PASSED,
  ANZ_MEDIA_DATA_TYPES_ADB,
  ANZ_EXTERNAL_TABLES_SERVERLESS,
  ANZ_TABLES_WITH_XMLTYPE_COLUMN,
  ANZ_XMLTYPE_TABLES,
  ANZ_BASIC_FILE_LOBS,
  ZUL_DOWNTIME_WE,
  DB_SIZE_GB,
  ANZ_DB_LINKS
)
SELECT
  DB_PRIMKEY,
  OS_SYSTYPE,
  OS_NAME,
  OS_TYPE,
  OS_VERSION,
  ORACLEDB,
  ORACLESID,
  ENVIRONEMENT,
  OPERATED_FOR_COMPANY,
  SERVICE_CATEGORY,
  DNS_NAME,
  IP_ADDRESS,
  PORT_NUMBER,
  ORACLE_LISTENER,
  ORACLE_OSN,
  ORACLE_OSN_ALIAS,
  DB_LOCATION,
  DB_COUNTRYCODE,
  DB_PW,
  CONNECT_STATUS,
  CONNECT_STRING,
  IN_SCOPE,
  ANZ_ACTION_REQUIRED,
  ANZ_REVIEW_REQUIRED,
  NULL AS ANZ_REVIEW_SUGGESTED, -- Default or calculated value
  NULL AS ANZ_PASSED,           -- Adjust as needed
  NULL AS ANZ_MEDIA_DATA_TYPES_ADB,
  NULL AS ANZ_EXTERNAL_TABLES_SERVERLESS,
  NULL AS ANZ_TABLES_WITH_XMLTYPE_COLUMN,
  NULL AS ANZ_XMLTYPE_TABLES,
  NULL AS ANZ_BASIC_FILE_LOBS,
  NULL AS ZUL_DOWNTIME_WE,
  NULL AS DB_SIZE_GB,
  NULL AS ANZ_DB_LINKS
FROM MIG_CPAT_DATABASES
WHERE IN_SCOPE = 'Y';

     DBMS_OUTPUT.PUT_LINE('5             ='||SQL%ROWCOUNT);

   commit;

  /*
   execute IMMEDIATE ('create table MIG_CPAT_LOW_FRUITS as select * from mig_cpat_databases where in_scope = ''Y''');
   execute IMMEDIATE ('ALTER TABLE MIG_CPAT_LOW_FRUITS ADD (anz_review_suggested NUMBER )');
   execute IMMEDIATE ('ALTER TABLE MIG_CPAT_LOW_FRUITS ADD (anz_passed NUMBER )');
   execute IMMEDIATE ('AL1TER TABLE MIG_CPAT_LOW_FRUITS ADD (anz_media_data_types_adb NUMBER )');
   execute IMMEDIATE ('ALTER TABLE MIG_CPAT_LOW_FRUITS ADD (anz_external_tables_serverless NUMBER )');
   execute IMMEDIATE ('ALTER TABLE MIG_CPAT_LOW_FRUITS ADD (anz_tables_with_xmltype_column NUMBER )');
   execute IMMEDIATE ('ALTER TABLE MIG_CPAT_LOW_FRUITS ADD (anz_xmltype_tables NUMBER )');
   execute IMMEDIATE ('ALTER TABLE MIG_CPAT_LOW_FRUITS ADD (anz_basic_file_lobs NUMBER )');
   execute IMMEDIATE ('ALTER TABLE MIG_CPAT_LOW_FRUITS ADD (ZUL_DOWNTIME_WE NUMBER )');
   execute IMMEDIATE ('ALTER TABLE MIG_CPAT_LOW_FRUITS ADD (db_size_GB NUMBER )');
   execute IMMEDIATE ('ALTER TABLE MIG_CPAT_LOW_FRUITS ADD (anz_db_links NUMBER )');
  */

  v_counter  := 0;
  v_counter3 := 0;

  for crec in cdbs loop
      v_counter := v_counter + 1;
      select nvl(max(cdr_cr_primkey),0) into v_primkey
      from mig_cpat_db_runs
      where cdr_db_primkey = crec.db_primkey;

      select migration_methode    into v_migmethode
      from mig_database
      where db_primkey = crec.db_primkey;

      if v_primkey > 0 then

       if v_migmethode = 'online' then

        -- all tests

         update MIG_CPAT_LOW_FRUITS set anz_action_required =
                                  (select count(*)
                                  from mig_cpat_db_run_tests
                                  where cdrt_db_primkey = crec.db_primkey
                                  and   cdrt_cr_primkey = v_primkey
                                  and   cdrt_test_result = 'ActionRequired')
        where MIG_CPAT_LOW_FRUITS.db_primkey = crec.db_primkey;

         update MIG_CPAT_LOW_FRUITS set anz_review_required =
                                  (select count(*)
                                  from mig_cpat_db_run_tests
                                  where cdrt_db_primkey = crec.db_primkey
                                  and   cdrt_cr_primkey = v_primkey
                                  and   cdrt_test_result = 'ReviewRequired')
        where MIG_CPAT_LOW_FRUITS.db_primkey = crec.db_primkey;

      else
        -- exclude gg rules

         update MIG_CPAT_LOW_FRUITS set anz_action_required =
                                  (select count(*)
                                  from mig_cpat_db_run_tests
                                  where cdrt_db_primkey = crec.db_primkey
                                  and   cdrt_cr_primkey = v_primkey
                                  and   cdrt_test_result = 'ActionRequired'
                                  and   cdrt_test_name not like 'gg_%')
        where MIG_CPAT_LOW_FRUITS.db_primkey = crec.db_primkey;

         update MIG_CPAT_LOW_FRUITS set anz_review_required =
                                  (select count(*)
                                  from mig_cpat_db_run_tests
                                  where cdrt_db_primkey = crec.db_primkey
                                  and   cdrt_cr_primkey = v_primkey
                                  and   cdrt_test_result = 'ReviewRequired'
                                  and   cdrt_test_name not like 'gg_%')
        where MIG_CPAT_LOW_FRUITS.db_primkey = crec.db_primkey;

      END If;

         update MIG_CPAT_LOW_FRUITS set anz_review_suggested =
                                  (select count(*)
                                  from mig_cpat_db_run_tests
                                  where cdrt_db_primkey = crec.db_primkey
                                  and   cdrt_cr_primkey = v_primkey
                                  and   cdrt_test_result = 'ReviewSuggested')
        where MIG_CPAT_LOW_FRUITS.db_primkey = crec.db_primkey;

         update MIG_CPAT_LOW_FRUITS set anz_passed =
                                  (select count(*)
                                  from mig_cpat_db_run_tests
                                  where cdrt_db_primkey = crec.db_primkey
                                  and   cdrt_cr_primkey = v_primkey
                                  and   cdrt_test_result = 'Passed')
        where MIG_CPAT_LOW_FRUITS.db_primkey = crec.db_primkey;

         update MIG_CPAT_LOW_FRUITS set anz_basic_file_lobs =
                                  (select count(*)
                                  from mig_cpat_db_run_tests
                                  where cdrt_db_primkey = crec.db_primkey
                                  and   cdrt_cr_primkey = v_primkey
                                  and   cdrt_test_name  = 'has_basic_file_lobs'
                                  and   cdrt_test_result != 'Passed')
        where MIG_CPAT_LOW_FRUITS.db_primkey = crec.db_primkey;

         update MIG_CPAT_LOW_FRUITS set anz_xmltype_tables =
                                  (select count(*)
                                  from mig_cpat_db_run_tests
                                  where cdrt_db_primkey = crec.db_primkey
                                  and   cdrt_cr_primkey = v_primkey
                                  and   cdrt_test_name  = 'has_xmltype_tables'
                                  and   cdrt_test_result != 'Passed')
        where MIG_CPAT_LOW_FRUITS.db_primkey = crec.db_primkey;

         update MIG_CPAT_LOW_FRUITS set anz_tables_with_xmltype_column =
                                  (select count(*)
                                  from mig_cpat_db_run_tests
                                  where cdrt_db_primkey = crec.db_primkey
                                  and   cdrt_cr_primkey = v_primkey
                                  and   cdrt_test_name  = 'has_tables_with_xmltype_column'
                                  and   cdrt_test_result != 'Passed')
        where MIG_CPAT_LOW_FRUITS.db_primkey = crec.db_primkey;

         update MIG_CPAT_LOW_FRUITS set anz_external_tables_serverless =
                                  (select count(*)
                                  from mig_cpat_db_run_tests
                                  where cdrt_db_primkey = crec.db_primkey
                                  and   cdrt_cr_primkey = v_primkey
                                  and   cdrt_test_name  = 'has_external_tables_serverless'
                                  and   cdrt_test_result != 'Passed')
        where MIG_CPAT_LOW_FRUITS.db_primkey = crec.db_primkey;

         update MIG_CPAT_LOW_FRUITS set anz_media_data_types_adb =
                                  (select count(*)
                                  from mig_cpat_db_run_tests
                                  where cdrt_db_primkey = crec.db_primkey
                                  and   cdrt_cr_primkey = v_primkey
                                  and   cdrt_test_name  = 'has_columns_with_media_data_types_adb'
                                  and   cdrt_test_result != 'Passed')
        where MIG_CPAT_LOW_FRUITS.db_primkey = crec.db_primkey;

         update MIG_CPAT_LOW_FRUITS set anz_db_LINKS =
                                  (select count(*)
                                  from mig_cpat_db_links
                                  where dbl_db_primkey = crec.db_primkey)
        where MIG_CPAT_LOW_FRUITS.db_primkey = crec.db_primkey;
       else
        v_counter3 := v_counter3 + 1;
      end if;

  end loop;
UPDATE MIG_DATABASE
SET CPAT_ACTION_PCT = (
    SELECT ROUND(
               ((ANZ_ACTION_REQUIRED + ANZ_REVIEW_REQUIRED) * 100) /
               (ANZ_ACTION_REQUIRED + ANZ_REVIEW_REQUIRED + ANZ_REVIEW_SUGGESTED + ANZ_PASSED),
               3
           )
    FROM MIG_CPAT_LOW_FRUITS
    WHERE MIG_CPAT_LOW_FRUITS.DB_PRIMKEY = MIG_DATABASE.DB_PRIMKEY
      AND (ANZ_ACTION_REQUIRED + ANZ_REVIEW_REQUIRED + ANZ_REVIEW_SUGGESTED + ANZ_PASSED) > 0
)
WHERE EXISTS (
    SELECT 1
    FROM MIG_CPAT_LOW_FRUITS
    WHERE MIG_CPAT_LOW_FRUITS.DB_PRIMKEY = MIG_DATABASE.DB_PRIMKEY
      AND (ANZ_ACTION_REQUIRED + ANZ_REVIEW_REQUIRED + ANZ_REVIEW_SUGGESTED + ANZ_PASSED) > 0
);

    v_counter2 := SQL%ROWCOUNT;

UPDATE MIG_DATABASE
SET ANZ_DB_LINKS = (
    SELECT MIG_CPAT_LOW_FRUITS.ANZ_DB_LINKS
    FROM MIG_CPAT_LOW_FRUITS
    WHERE MIG_CPAT_LOW_FRUITS.DB_PRIMKEY = MIG_DATABASE.DB_PRIMKEY
)
WHERE EXISTS (
    SELECT 1
    FROM MIG_CPAT_LOW_FRUITS
    WHERE MIG_CPAT_LOW_FRUITS.DB_PRIMKEY = MIG_DATABASE.DB_PRIMKEY
);

    v_counter3 := SQL%ROWCOUNT;

  commit;
    p_log('mig', 'Step0: finished create low fruits');

  DBMS_OUTPUT.PUT_LINE('dbs             ='||v_counter);
  DBMS_OUTPUT.PUT_LINE('dbs 2           ='||v_counter2);
  DBMS_OUTPUT.PUT_LINE('dbs 3           ='||v_counter3);
  DBMS_OUTPUT.PUT_LINE('Ende create low fruits');

exception
     when others then
       p_log('mig', 'Step0: finished create low fruits w. error '||sqlerrm);
       DBMS_OUTPUT.PUT_LINE('Ende create low fruits w. error '||sqlerrm);
       null;
END P_LOW_MIGRATION_FRUITS;

/
--------------------------------------------------------
--  DDL for Procedure P_MAIL_SEND_FILES
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_MAIL_SEND_FILES"
           (p_from_mail        VARCHAR2,
            p_to_mail          VARCHAR2,
            p_subject          VARCHAR2,
            p_message          VARCHAR2,
            p_oracle_directory VARCHAR2,
            p_binary_file      VARCHAR2)
IS
v_smtp_server      VARCHAR2(100) := 'smtpout.basf.net';
v_smtp_server_port NUMBER := 25;
v_directory_name   VARCHAR2(100);
v_file_name        VARCHAR2(100);
v_mesg             VARCHAR2(32767);
v_conn             UTL_SMTP.CONNECTION;
PROCEDURE write_mime_header(p_conn  in out nocopy utl_smtp.connection,
                            p_name  in varchar2,
                            p_value in varchar2)
IS
BEGIN
   UTL_SMTP.WRITE_RAW_DATA(
   p_conn,
   UTL_RAW.CAST_TO_RAW( p_name || ': ' || p_value || UTL_TCP.CRLF)
   );
END write_mime_header;
PROCEDURE write_boundary(p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION,
                         p_last IN BOOLEAN DEFAULT false)
IS
BEGIN
  IF (p_last) THEN
    UTL_SMTP.WRITE_DATA(p_conn, '--DMW.Boundary.605592468--'||UTL_TCP.CRLF);
  ELSE
    UTL_SMTP.WRITE_DATA(p_conn, '--DMW.Boundary.605592468'||UTL_TCP.CRLF);
  END IF;
END write_boundary;
PROCEDURE end_attachment(p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION,
                         p_last IN BOOLEAN DEFAULT TRUE)
IS
BEGIN
   UTL_SMTP.WRITE_DATA(p_conn, UTL_TCP.CRLF);
   IF (p_last) THEN
    write_boundary(p_conn, p_last);
   END IF;
END end_attachment;
PROCEDURE begin_attachment(p_conn         IN OUT NOCOPY UTL_SMTP.CONNECTION,
                           p_mime_type    IN VARCHAR2 DEFAULT 'text/plain',
                           p_inline       IN BOOLEAN DEFAULT false,
                           p_filename     IN VARCHAR2 DEFAULT null,
                           p_transfer_enc IN VARCHAR2 DEFAULT null)
IS
BEGIN
   write_boundary(p_conn);
   IF (p_transfer_enc IS NOT NULL) THEN
     write_mime_header(p_conn, 'Content-Transfer-Encoding',p_transfer_enc);
   END IF;
   write_mime_header(p_conn, 'Content-Type', p_mime_type);
   IF (p_filename IS NOT NULL) THEN
      IF (p_inline) THEN
         write_mime_header(p_conn,'Content-Disposition', 'inline; filename="' || p_filename || '"');
      ELSE
         write_mime_header(p_conn,'Content-Disposition', 'attachment; filename="' || p_filename || '"');
      END IF;
   END IF;
   UTL_SMTP.WRITE_DATA(p_conn, UTL_TCP.CRLF);
END begin_attachment;
PROCEDURE binary_attachment(p_conn      IN OUT UTL_SMTP.CONNECTION,
                            p_file_name IN VARCHAR2,
                            p_mime_type in VARCHAR2)
IS
c_max_line_width CONSTANT PLS_INTEGER DEFAULT 54;
v_amt            BINARY_INTEGER := 672 * 3; /* ensures proper format; 2016 */
v_bfile          BFILE;
v_file_length    PLS_INTEGER;
v_buf            RAW(2100);
v_modulo         PLS_INTEGER;
v_pieces         PLS_INTEGER;
v_file_pos       pls_integer := 1;
BEGIN
  begin_attachment(p_conn => p_conn,
                   p_mime_type => p_mime_type,
                   p_inline => TRUE,
                   p_filename => p_file_name,
                   p_transfer_enc => 'base64');
  BEGIN
     v_bfile := BFILENAME(p_oracle_directory, p_file_name);
     -- Get the size of the file to be attached
     v_file_length := DBMS_LOB.GETLENGTH(v_bfile);
     -- Calculate the number of pieces the file will be split up into
     v_pieces := TRUNC(v_file_length / v_amt);
     -- Calculate the remainder after dividing the file into v_amt chunks
     v_modulo := MOD(v_file_length, v_amt);
     IF (v_modulo <> 0) THEN
       -- Since the file does not divide equally
       -- we need to go round the loop an extra time to write the last
       -- few bytes - so add one to the loop counter.
       v_pieces := v_pieces + 1;
     END IF;
     DBMS_LOB.FILEOPEN(v_bfile, DBMS_LOB.FILE_READONLY);

     FOR i IN 1 .. v_pieces LOOP
       -- we can read at the beginning of the loop as we have already calculated
       -- how many iterations we will take and so do not need to check
       -- end of file inside the loop.
       v_buf := NULL;
       DBMS_LOB.READ(v_bfile, v_amt, v_file_pos, v_buf);
       v_file_pos := I * v_amt + 1;
       UTL_SMTP.WRITE_RAW_DATA(p_conn, UTL_ENCODE.BASE64_ENCODE(v_buf));
     END LOOP;
   END;
   DBMS_LOB.FILECLOSE(v_bfile);
   end_attachment(p_conn => p_conn);
EXCEPTION
WHEN NO_DATA_FOUND THEN
    end_attachment(p_conn => p_conn);
    DBMS_LOB.FILECLOSE(v_bfile);
END binary_attachment;
/*** MAIN Routine ***/
BEGIN
   v_conn:= UTL_SMTP.OPEN_CONNECTION( v_smtp_server, v_smtp_server_port );
   UTL_SMTP.HELO( v_conn, v_smtp_server );
   UTL_SMTP.MAIL( v_conn, p_from_mail );
   UTL_SMTP.RCPT( v_conn, p_to_mail );
   UTL_SMTP.OPEN_DATA ( v_conn );
   UTL_SMTP.WRITE_DATA(v_conn, 'Subject: '||p_subject||UTL_TCP.CRLF);
   v_mesg:= 'Content-Transfer-Encoding: 7bit' || UTL_TCP.CRLF ||
   'Content-Type: multipart/mixed;boundary="DMW.Boundary.605592468"' || UTL_TCP.CRLF ||
   'Mime-Version: 1.0' || UTL_TCP.CRLF ||
   '--DMW.Boundary.605592468' || UTL_TCP.CRLF ||
   'Content-Transfer-Encoding: binary'||UTL_TCP.CRLF||
   'Content-Type: text/plain' ||UTL_TCP.CRLF ||
   UTL_TCP.CRLF || p_message || UTL_TCP.CRLF ;
   UTL_SMTP.write_data(v_conn, 'To: ' || p_to_mail || UTL_TCP.crlf);
   UTL_SMTP.WRITE_RAW_DATA ( v_conn, UTL_RAW.CAST_TO_RAW(v_mesg) );
   /*** Add attachment here ***/
   binary_attachment(p_conn => v_conn,
                     p_file_name => p_binary_file,
                     -- Modify the mime type at the beginning of this line depending
                     -- on the type of file being loaded.
                     p_mime_type => 'text/plain; name="'||p_binary_file||'"'
                     );
   /*** Send E-Mail ***/
   UTL_SMTP.CLOSE_DATA( v_conn );
   UTL_SMTP.QUIT( v_conn );
END;

/
--------------------------------------------------------
--  DDL for Procedure P_METRIC_RANGES_DB_HRS
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_METRIC_RANGES_DB_HRS" AS

  v_count               number :=0;
  v_error               number :=0;
  v_upd                 number :=0;

-- Einlesen dbs
  CURSOR c_mdb  IS
      select db_target_guid
      from mig_database;

BEGIN

  p_log ('mig','Start create metric ranges');
      update mig_control set status = 'Running'
       where nr = 21;
    COMMIT;

  -- create ranges
  --

  delete from mig_calc_metrics_ranges_db;

  commit;

  -- metrIc ranges per sb
  insert into mig_calc_metrics_ranges_DB (target_guid, target_name, metric_column, minimum,
                                             average, maximum)
                        (select target_guid, target_name, metric_column,
                             round(min(minimum),3), round(avg(average),3), round(max(maximum),3)
                             from mig_em_metric_db_hrs,
                             mig_database
                             where target_guid = db_target_guid
                             group by target_guid, target_name, metric_column );

  p_log ('mig','Created EM Ranges '||to_char(sql%ROWCOUNT));

        update mig_calc_metrics_ranges_DB set
           low =  round((minimum + ((maximum - minimum)* 0.33)),3),
           med =  round((minimum + ((maximum - minimum)* 0.66)),3);

  commit;

  p_log ('mig','End create metric ranges.');

    update mig_control set status = 'finished'
       where nr = 21;
    commit;

EXCEPTION
    WHEN OTHERS THEN
        rollback;
        p_log ('mig','pop. Mig DB: An error occurred: ' || SQLERRM);
       update mig_control set status = 'finished with errors'
       where nr = 21;
       commit;

END P_METRIC_RANGES_DB_HRS;

/
--------------------------------------------------------
--  DDL for Procedure P_MIGRATION_CLASSIFICATION
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_MIGRATION_CLASSIFICATION" AS
/*

classify dbs in scope:

- on/offline migration
- migration class (easy, medium, complex, very complex)
- atp or exad

*/

   v_migration_gb_per_min   number := 1;
   v_latest_cpat_run        number;
   v_cpat_complex_index     number;
   v_helper1                number;
   v_is_hard_issu           number;
   v_mark_very_complex      number;
   v_mr                     MIG_DATABASE_MIGRATION_CLASSIFICATION%ROWTYPE;
   v_ar                     MIG_DB_SQLRUN_CATEGORY%ROWTYPE;
   v_total_weight           number;
   v_nr_tests               number := 0;
   v_weight                 number := 1;
   v_complex_desc           varchar2(512);

   v_complex_group1        number := 10;
   v_complex_group2        number := 25;
   v_complex_group3        number := 40;

   cursor c_migdb is
       select db_primkey,
              max_downtime_we_hrs * 60 as downtime_we_min,
              max_downtime_wd_hrs * 60 as downtime_overnight_min,
              alloc_gb,
              target_platform
       from mig_database
      -- where db_primkey = 101293
       ;

   cursor c_cpat_tests (p_latest_run NUMBER,
                        p_db_primkey NUMBER) is
     SELECT cdrt_test_result,
       cdrt_test_name,
       -- CASE for CONL
      CASE
           WHEN cdrt_test_result = 'ActionRequired' THEN 3 * conl
           WHEN cdrt_test_result = 'ReviewRequired' THEN 2 * conl
           WHEN cdrt_test_result = 'ReviewSuggested' THEN 1 * conl
           ELSE conl
       END AS conl,
       -- CASE for COFF
       CASE
           WHEN cdrt_test_result = 'ActionRequired' THEN 3 * coff
           WHEN cdrt_test_result = 'ReviewRequired' THEN 2 * coff
           WHEN cdrt_test_result = 'ReviewSuggested' THEN 1 * coff
           ELSE coff
       END AS coff,
       ISSUE_PLATFORM,
       ISSUE_MIGRATION,
       ISSUE_MIGRATION_ART
         FROM   mig_cpat_test_classification,
            mig_cpat_db_run_tests
     where test_name(+) = cdrt_test_name
     and  cdrt_db_primkey = p_db_primkey
     and  cdrt_cr_primkey = p_latest_run
     AND  cdrt_test_result IN (
                                'ActionRequired',
                                'ReviewRequired',
                                'ReviewSuggested');

   procedure adesc (p_mr in out MIG_DATABASE_MIGRATION_CLASSIFICATION%ROWTYPE,
                       p_desc in   varchar)
   as
   begin
      p_mr.dbc_description     := p_mr.dbc_description||p_desc;
   end;

   procedure init_rec (p_mr in out MIG_DATABASE_MIGRATION_CLASSIFICATION%ROWTYPE)
   as
   begin
      p_mr.dbc_db_primkey     := null;
      p_mr.dbc_mig_logical    := 'Y';
      p_mr.dbc_mig_physical   := 'N';
      p_mr.dbc_mig_online     := 'Y';
      p_mr.dbc_mig_offline    := 'N';
      p_mr.dbc_est_mig_duration_min := null;
      p_mr.dbc_mig_overnight  := 'N';
      p_mr.dbc_mig_weekend    := 'N';
      p_mr.DBC_CPAT_FAILED     := 0;
      p_mr.DBC_CPAT_ACTION_REQ := 0;
      p_mr.DBC_CPAT_REVIEW_REQ := 0;
      p_mr.DBC_CPAT_REVIEW_SUG := 0;
      p_mr.DBC_CPAT_PASSED     := 0;
      p_mr.dbc_cpat_action_gew := 0;
      p_mr.dbc_cpat_review_gew := 0;
      p_mr.dbc_cpat_index      := 0;
      p_mr.dbc_marked_complex  := 'N';
      p_mr.dbc_COMPLEXITY_GROUP := null;
      p_mr.dbc_description     := null;
      p_mr.DBC_RECOM_MIGRATION := 'physical';
      p_mr.DBC_RECOM_MIGRATION_ART := 'offline';

   end;

   procedure wr_rec (p_mr in out MIG_DATABASE_MIGRATION_CLASSIFICATION%ROWTYPE)
   as
   begin

     insert into MIG_DATABASE_MIGRATION_CLASSIFICATION
       values (p_mr.dbc_db_primkey
      ,p_mr.dbc_mig_logical
      ,p_mr.dbc_mig_physical
      ,p_mr.dbc_mig_online
      ,p_mr.dbc_mig_offline
      ,p_mr.dbc_est_mig_duration_min
      ,p_mr.dbc_mig_overnight
      ,p_mr.dbc_mig_weekend
      ,p_mr.DBC_CPAT_FAILED
      ,p_mr.DBC_CPAT_ACTION_REQ
      ,p_mr.DBC_CPAT_REVIEW_REQ
      ,p_mr.DBC_CPAT_REVIEW_SUG
      ,p_mr.DBC_CPAT_PASSED
      ,p_mr.dbc_cpat_action_gew
      ,p_mr.dbc_cpat_review_gew
      ,p_mr.dbc_cpat_index
      ,p_mr.dbc_marked_complex
      ,p_mr.dbc_COMPLEXITY_GROUP
      ,p_mr.dbc_description
      ,p_mr.DBC_RECOM_MIGRATION
      ,p_mr.DBC_RECOM_MIGRATION_ART
      );

   end;

BEGIN
  delete from MIG_DATABASE_MIGRATION_CLASSIFICATION;
  commit;

  for mdb in c_migdb loop

      init_rec (v_mr);
      v_mr.dbc_db_primkey := mdb.db_primkey;

      v_mr.dbc_est_mig_duration_min := mdb.alloc_gb / v_migration_gb_per_min;
      -- def onl/offline
      if (mdb.downtime_overnight_min/2) > v_mr.dbc_est_mig_duration_min
      then
        v_mr.dbc_mig_overnight := 'Y';
        v_mr.dbc_mig_offline   := 'Y';
      end if;
      if (mdb.downtime_we_min/2) > v_mr.dbc_est_mig_duration_min
      then
        v_mr.dbc_mig_weekend   := 'Y';
        v_mr.dbc_mig_offline   := 'Y';
      end if;

     if v_mr.dbc_mig_offline = 'Y' then
        v_mr.DBC_RECOM_MIGRATION := 'OFF-line';
     else
        v_mr.DBC_RECOM_MIGRATION     := 'ON-line';
     end if;

    if mdb.target_platform = 'EXAD'
      then
        v_mr.DBC_RECOM_MIGRATION_ART := 'physical';
     else
        v_mr.DBC_RECOM_MIGRATION_ART := 'logical';
     end if;

     -- cpat numbers
     -- read all cpat action tasks and calculate
     -- cpat complexity index

     v_cpat_complex_index := 1;
--c_cpat_tests
     SELECT  max(cdrt_cr_primkey) into v_latest_cpat_run
     FROM mig_cpat_db_run_tests
     where cdrt_db_primkey = mdb.db_primkey;
     adesc(v_mr,'latest crun:'||to_CHAR(v_latest_cpat_run));

     v_mark_very_complex := 0;
     v_weight            := 1;
     v_nr_tests          := 0;
     V_COMPLEX_DESC      :='';

     for tstrec in c_cpat_tests (v_latest_cpat_run, mdb.db_primkey)
     loop
        -- handle hard issues
        if  tstrec.issue_platform is not null then
               v_helper1 := 0;
               if (tstrec.issue_platform = 'all'
                or tstrec.issue_platform = mdb.target_platform) then
                v_helper1 := v_helper1 +  1;
              end if;
              if (tstrec.issue_migration = 'all'
                or tstrec.issue_migration = v_mr.DBC_RECOM_MIGRATION) then
                v_helper1 := v_helper1 +  1;
              end if;
              if (tstrec.issue_migration_art = 'all'
                or tstrec.issue_migration_art = v_mr.DBC_RECOM_MIGRATION_art) then
                v_helper1 := v_helper1 +  1;
              end if;

               if v_helper1 = 3 then
                  v_mr.dbc_marked_complex := 'Y';
                  v_complex_desc := v_complex_desc||','||tstrec.cdrt_test_name;
               end if;
         else
              v_nr_tests := v_nr_tests + 1;
              if v_mr.DBC_RECOM_MIGRATION_ART  = 'OFF-line' then
                  v_cpat_complex_index := v_cpat_complex_index + nvl(tstrec.coff,0);
              else
                  v_cpat_complex_index := v_cpat_complex_index + nvl(tstrec.conl,0);
             end if;
        end if;
     end loop;

     select count(*) into v_mr.dbc_cpat_failed
     FROM mig_cpat_db_run_tests
     where cdrt_db_primkey = mdb.db_primkey
     and cdrt_cr_primkey = v_latest_cpat_run
     and cdrt_test_result = 'Failed';

     select count(*) into v_mr.dbc_cpat_review_sug
     FROM mig_cpat_db_run_tests
     where cdrt_db_primkey = mdb.db_primkey
     and cdrt_cr_primkey = v_latest_cpat_run
     and cdrt_test_result = 'ReviewSuggested';

     select count(*) into v_mr.dbc_cpat_passed
     FROM mig_cpat_db_run_tests
     where cdrt_db_primkey = mdb.db_primkey
     and cdrt_cr_primkey = v_latest_cpat_run
     and cdrt_test_result = 'Passed';

     select count(*) into v_mr.dbc_cpat_action_req
     FROM mig_cpat_db_run_tests
     where cdrt_db_primkey = mdb.db_primkey
     and cdrt_cr_primkey = v_latest_cpat_run
     and cdrt_test_result = 'ActionRequired';

     select count(*) into v_mr.dbc_cpat_review_req
     FROM mig_cpat_db_run_tests
     where cdrt_db_primkey = mdb.db_primkey
     and cdrt_cr_primkey = v_latest_cpat_run
     and cdrt_test_result = 'ReviewRequired';

     select nvl(sum(1 * cpat_test_gew),0) into v_mr.dbc_cpat_review_gew
     FROM  mig_cpat_test_gew,
           mig_cpat_db_run_tests
     where cpat_test_name = cdrt_test_name
     and cdrt_db_primkey = mdb.db_primkey
     and cdrt_cr_primkey = v_latest_cpat_run
     and cdrt_test_result = 'ReviewRequired';

     select nvl(sum(1 * cpat_test_gew),0) into v_mr.dbc_cpat_action_gew
     FROM  mig_cpat_test_gew,
           mig_cpat_db_run_tests
     where cpat_test_name = cdrt_test_name
     and cdrt_db_primkey = mdb.db_primkey
     and cdrt_cr_primkey = v_latest_cpat_run
     and cdrt_test_result = 'ActionRequired';

      -- offline

      if mdb.target_platform = 'EXAD'
      then
          v_mr.dbc_mig_physical   := 'Y';
      end if;

        -- add.difficulties
      begin
         select * into v_ar
         from MIG_DB_SQLRUN_CATEGORY
         where db_primkey = mdb.db_primkey;

         if mdb.target_platform = 'ATPS' and
            nvl(v_ar.schema_count,0) > 30
         then
            v_nr_tests := v_nr_tests + 1;
            v_cpat_complex_index := v_cpat_complex_index +   10;
            --adesc(v_mr,'; schema count >30');
         end if;

         if mdb.target_platform = 'ATPS' and
            nvl(v_ar.apex_usage,'noAPEX') = 'APEX'
         then
            v_nr_tests := v_nr_tests + 1;
            --adesc(v_mr,'; APEX');
            v_cpat_complex_index := v_cpat_complex_index +   10;
         end if;

         if mdb.target_platform = 'ATPS' and
            nvl(v_ar.EXTERNAL_LINKS,0) > 5
         then
            v_nr_tests := v_nr_tests + 1;
            --adesc(v_mr,'; anz Links>5');
            v_cpat_complex_index := v_cpat_complex_index + 15;
         end if;

         if v_mr.DBC_RECOM_MIGRATION  = 'ON-line'
        then
            v_nr_tests := v_nr_tests + 1;
            --adesc(v_mr,'; no off');
            v_cpat_complex_index := v_cpat_complex_index + 10;
         end if;
      exception
         when others then
            dbms_output.put_line (sqlerrm);
      end;

     if v_mr.dbc_marked_complex = 'Y' then
         adesc(v_mr,' Complex:'||v_complex_desc);
         v_mr.dbc_cpat_index := 99;
         v_mr.dbc_complexity_group := 4;
      else
        if nvl(v_nr_tests,0) > 0 then
          v_mr.dbc_cpat_index := round((v_cpat_complex_index/v_nr_tests),3)*10;
        else
          v_mr.dbc_cpat_index := 0;
        end if;
     end if;

      wr_rec (v_mr);
  end loop;

 UPDATE mig_database_migration_classification
    SET dbc_complexity_group = CASE
        when dbc_cpat_index < 34 then 1
        when (dbc_cpat_index BETWEEN 34 and 37) then 2
        when (dbc_cpat_index between 37.001 and 40) then 3
        when dbc_cpat_index > 40 then 4
        else 5
    END
    where dbc_marked_complex != 'Y';

  commit;
END P_MIGRATION_CLASSIFICATION;

/
--------------------------------------------------------
--  DDL for Procedure P_MPACK_CATALOG_EXTRACT
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_MPACK_CATALOG_EXTRACT" AS

   l_file         UTL_FILE.FILE_TYPE;
   l_location     VARCHAR2(100) := 'FSS_DIR99';
   l_filename     VARCHAR2(100) := 'test.csv';
   v_step         varchar2(20);

   mpack_database_catalog CLOB;

   CURSOR mpack_db_target IS
   SELECT dbtarget.target_guid                             AS target_guid,
         dbtarget.target_name                             AS target_name,
         dbtarget.target_type                             AS target_type,
         container.target_guid                            AS cdb_target_guid,
         container.target_name                            AS cdb_target_name,
         container.target_type                            AS cdb_target_type,
         dbtarget.host_name                               AS host_name,
         dbtarget.type_qualifier1                         AS database_version,
         host.type_qualifier1                             AS operating_system,
         nvl(standby_db.role,'NONE')                      AS standby_role,
         nvl(standby_db.db_unique_name,'NONE')            AS standby_unique_db_name,
         nvl(standby_db.prmy_db_unique_name,'NONE')       AS primary_unique_db_name,
         primary_db.target_guid                           AS primary_target_guid
   FROM sysman.mgmt$target@OEM134P_SYSMAN  dbtarget,
         sysman.mgmt$target@OEM134P_SYSMAN  container,
         sysman.mgmt$target@OEM134P_SYSMAN  host,
         sysman.mgmt$target_associations@OEM134P_SYSMAN  db_assoc,
         sysman.mgmt$ha_dg_target_summary@OEM134P_SYSMAN standby_db,
         sysman.mgmt$ha_dg_target_summary@OEM134P_SYSMAN primary_db
   WHERE dbtarget.target_type             IN ('oracle_pdb','oracle_database','rac_database')
      AND dbtarget.target_type             = db_assoc.assoc_target_type  (+)
      AND dbtarget.target_name             = db_assoc.assoc_target_name  (+)
      AND db_assoc.association_type   (+)  = 'contains'
      AND db_assoc.source_target_type (+)  IN ('oracle_database', 'rac_database')
      AND db_assoc.source_target_type      = container.target_type  (+)
      AND db_assoc.source_target_name      = container.target_name  (+)
      AND dbtarget.target_guid             = standby_db.target_guid (+)
      AND standby_db.prmy_db_unique_name   = primary_db.db_unique_name (+)
      AND dbtarget.host_name               = host.host_name
      AND host.target_type                 ='host'
      AND NOT EXISTS ( SELECT 'rac_instance'
                        FROM sysman.mgmt$target_associations@OEM134P_SYSMAN rac_instances
                        WHERE rac_instances.assoc_target_name  =   dbtarget.target_name
                        AND rac_instances.association_type   =   'rac_instance' )
     and lower(dbtarget.target_name) in (select lower(oracledb) from mig_database)
    -- FETCH first 10 rows only
                        ;

   mpack_db_target_row mpack_db_target%rowtype;

   /* ** MPACK_DB_CONTAINER **
   Used to check whether a database with a target_type of 'oracle_database' or 'rac_database' is a container database or non-multitenant
   */
   CURSOR mpack_db_container(v_target_type VARCHAR2, v_dbtarget_name VARCHAR2) IS
   SELECT count(*) pluggable_count
      FROM sysman.mgmt$target_associations@OEM134P_SYSMAN
   WHERE source_target_name=v_dbtarget_name
      AND association_type='contains'
      AND assoc_target_type='oracle_pdb'
      AND source_target_type=v_target_type;

   mpack_db_container_row mpack_db_container%rowtype;

   /* ** MPACK_PLUGGABLE_ON_RAC **
   Used to establish whether a pluggable database is attached to a set of RAC instances or is a single instance database
   */
   CURSOR mpack_pluggable_on_rac(v_insttarget_name VARCHAR2) IS
   SELECT count(*) AS rac_flag
   FROM sysman.mgmt$target_associations@OEM134P_SYSMAN a
   WHERE a.assoc_target_name=v_insttarget_name
      AND a.source_target_type='rac_database'
      AND a.association_type='contains';

   mpack_pluggable_on_rac_row mpack_pluggable_on_rac%rowtype;

   /* ** MPACK_RAC_INSTANCE **
   Used to build a list of host names and instance names for all RAC databases. For RAC databases, the value from this cursor will overwrite the
   host data retrieved via the MPACK_DB_TARGET cursor.
   */
   CURSOR mpack_rac_instance(v_ractarget_guid RAW) IS
   SELECT a.assoc_target_name      AS rac_target_name,
         b.host_name              AS rac_host,
         nvl(c.instance_name,'UNMAPPED')          AS rac_instance_name
   FROM sysman.mgmt$target_associations@OEM134P_SYSMAN a,
         sysman.mgmt$target@OEM134P_SYSMAN b,
         sysman.mgmt$db_dbninstanceinfo@OEM134P_SYSMAN c,
         sysman.mgmt$target@OEM134P_SYSMAN d
   WHERE d.target_guid=v_ractarget_guid
      AND a.source_target_name=d.target_name
      AND a.association_type='rac_instance'
      AND b.target_name=a.assoc_target_name
      AND c.target_name(+)=a.assoc_target_name;

   mpack_rac_instance_row mpack_rac_instance%rowtype;

   /* ** MPACK_DG_STATUS **
   Used to check whether a target database is part of a dataguard configuration and to enable standby databases to 'inherit' primary database details.
   If the target database is a pluggable database the cursor is passed the guid for the container database.
   If the target database is a container or a non-container database, the target database guid is used.
   The resulting data from the cursor (particularly the dg_primary_guid) is used as the driver to the mpack_instance_details cursor to
   retrieve database details such as version, log_mode, characterset etc.
   This is needed because the view sysman.mgmt$db_dbninstanceinfo is not populated for standby databases as OEM cannot read the database
   due to the monitoring user (DBSNMP) not having sysdba priviliges and the standby database being in mount mode.
   */
   CURSOR mpack_dg_status (v_container_guid RAW) IS
      SELECT nvl(standby_db.role,'NONE')                      AS dg_standby_role,
            nvl(standby_db.db_unique_name,'NONE')            AS dg_standby_name,
            nvl(standby_db.prmy_db_unique_name,'NONE')       AS dg_primary_name,
            primary_db.target_guid                           AS dg_primary_guid
      FROM sysman.mgmt$ha_dg_target_summary@OEM134P_SYSMAN standby_db,
            sysman.mgmt$ha_dg_target_summary@OEM134P_SYSMAN primary_db
      WHERE v_container_guid  = standby_db.target_guid (+)
         AND standby_db.prmy_db_unique_name = primary_db.db_unique_name (+);

   mpack_dg_status_row mpack_dg_status%rowtype;

   /* ** MPACK_INSTANCE_DETAILS **
   Used to obtain high level database properties for all database types. Sometimes gets passed the target database guid and sometimes, for standby
   databases, the database guid of the primary database is used.
   */
   CURSOR mpack_instance_detail(v_insttarget_guid RAW) IS
      SELECT a.instance_name                                              AS instance_name,
            a.database_name                                              AS database_name,
            a.global_name                                                AS global_name,
            a.banner                                                     AS dbversion,
            a.log_mode                                                   AS log_mode,
            a.characterset                                               AS characterset,
            a.national_characterset                                      AS national_characterset,
            to_char(a.collection_timestamp,'DD-MON-YYYY hh24:mi:ss')     AS dbinstance_metrics_date
      FROM sysman.mgmt$db_dbninstanceinfo@OEM134P_SYSMAN a
      WHERE target_guid = v_insttarget_guid;

   mpack_instance_detail_row mpack_instance_detail%rowtype;

   /* ** MPACK_INSTANCE_CPU **
   Used to establish high level host cpu properties for all databases
   For RAC databases, only one node will be queried. Careful interpretation of the data is required
   */
   CURSOR mpack_instance_cpu(v_hosttarget_name VARCHAR2) IS
   SELECT a.vendor_name,
         a.freq_in_mhz,
         a.impl,
         a.revision,
         a.instance_count,
         a.num_cores,
         decode(a.is_hyperthread_enabled,0,'NO','YES')                   AS hyperthreading,
         to_char(a.last_collection_timestamp,'DD-MON-YYYY hh24:mi:ss')   AS host_metrics_date
      FROM sysman.mgmt$hw_cpu_details@OEM134P_SYSMAN a
   WHERE target_name = v_hosttarget_name;

   mpack_instance_cpu_row mpack_instance_cpu%rowtype;

   /* ** MPACK_DB_TARGET_CREDS **
   Used to establish whether preferred credentials have been set up for this database for "Normal" Database access.
   This is a pre-requisite of subseqent MPACK Group based extracts.
   The user set up with DBCredsNormal should have SELECT ANY DICTIONARY priviliege (e.g. DBSNMP)
   */
   CURSOR mpack_db_target_creds(db_guid RAW) IS
   SELECT set_name
   FROM sysman.em_target_creds@OEM134P_SYSMAN
   WHERE target_guid=db_guid
      AND set_name in ('DBCredsNormal');

   mpack_db_target_creds_row mpack_db_target_creds%rowtype;

   -- This PL/SQL CLOB contains the output of the database catalog extract
   mpack_db_list CLOB;

   -- v_extract_date_time stores the extract date and time
   v_extract_date_time varchar2(20);

   -- Other Variables
   v_db_creds varchar2(20);
   v_db_type varchar2(30);
   v_pluggable_count number;
   v_host_name varchar2(300);
   v_node_count number;
   v_instance_name varchar2(300);
   v_mpack_record varchar2(32767);

   BEGIN
 /*
  l_file := UTL_FILE.FOPEN(l_location, l_filename, 'w');

  UTL_FILE.PUT(l_file, 'Scott, male, 1000');

  -- Close the file.
  UTL_FILE.FCLOSE(l_file);
*/
   v_step := '1';
   -- Get current data and time
   v_extract_date_time:=to_char(sysdate,'DD-MON-YYYY hh24:mi:ss');

   -- Create the column headers for the report and add to the output CLOB
   mpack_db_list:=
   'MPACK_DB_TARGET'||
   '"'||'DB_TARGET_GUID'||'",'||
   '"'||'DB_TARGET_NAME'||'",'||
   '"'||'DB_TARGET_TYPE'||'",'||
   '"'||'DB_TYPE'||'",'||
   '"'||'PLUGGABLE_COUNT'||'",'||
   '"'||'DB_CONTAINER_TARGET_GUID'||'",'||
   '"'||'DB_CONTAINER_TARGET_NAME'||'",'||
   '"'||'DB_CONTAINER_TARGET_TYPE'||'",'||
   '"'||'DB_NAME'||'",'||
   '"'||'DB_GLOBAL_NAME'||'",'||
   '"'||'DB_VERSION'||'",'||
   '"'||'DB_HOST_NAME'||'",'||
   '"'||'DB_INSTANCE_NAME'||'",'||
   '"'||'DB_LOG_MODE'||'",'||
   '"'||'DB_CHARACTERSET'||'",'||
   '"'||'DB_NATIONAL_CHARACTERSET'||'",'||
   '"'||'DB_STANDBY_ROLE'||'",'||
   '"'||'DB_STANDBY_UNIQUE_NAME'||'",'||
   '"'||'DB_PRIMARY_UNIQUE_NAME'||'",'||
   '"'||'DB_PRIMARY_TARGET_GUID'||'",'||
   '"'||'DB_METRICS_DATE'||'",'||
   '"'||'DB_HOST_OPERATING_SYSTEM'||'",'||
   '"'||'DB_HOST_CPU_VENDOR'||'",'||
   '"'||'DB_HOST_CPU_FREQ'||'",'||
   '"'||'DB_HOST_CPU_IMPLEMENTATION'||'",'||
   '"'||'DB_HOST_CPU_REVISION'||'",'||
   '"'||'DB_HOST_CPU_COUNT'||'",'||
   '"'||'DB_HOST_CPU_CORES'||'",'||
   '"'||'DB_HOST_CPU_HYPERTHREADING'||'",'||
   '"'||'DB_HOST_METRICS_DATE'||'",'||
   '"'||'DB_NORMAL_CREDS'||'"'||
   chr(10);
   v_step := '2';

   dbms_output.put_line(mpack_db_list);

   -- Loop through each database in the OEM Repository
   FOR mpack_db_target_row IN mpack_db_target LOOP

   -- Reset database level variables
      v_pluggable_count:=null;
      v_node_count:=0;
      v_host_name:=null;
      v_db_type:=null;
      v_instance_name:=null;
      v_db_creds := 'MISSING';
      v_mpack_record := null;
      mpack_db_container_row:=null;
      mpack_pluggable_on_rac_row:=null;
      mpack_rac_instance_row:=null;
      mpack_dg_status_row:=null;
      mpack_instance_detail_row:=null;
      mpack_instance_cpu_row:=null;

   -- Ascertain whether this database is container database, pluggable database, or non-multitenant
   -- Also determine whether it is attached to multiple RAC nodes or single instance
      IF (mpack_db_target_row.target_type IN ('oracle_database', 'rac_database') AND mpack_db_target_row.cdb_target_guid IS NULL)
      THEN
         OPEN mpack_db_container(mpack_db_target_row.target_type, mpack_db_target_row.target_name);
         FETCH mpack_db_container INTO mpack_db_container_row;
         CLOSE mpack_db_container;
         IF mpack_db_container_row.pluggable_count>0
         THEN v_pluggable_count:=mpack_db_container_row.pluggable_count;
               CASE mpack_db_target_row.target_type
                  WHEN 'oracle_database' THEN v_db_type:='CONTAINER';
                  ELSE v_db_type:='CONTAINER (RAC)';
               END CASE;
         ELSE CASE mpack_db_target_row.target_type
                  WHEN 'oracle_database' THEN v_db_type:='NON MULTI-TENANT';
                  ELSE v_db_type:='NON MULTI-TENANT (RAC)';
               END CASE;
         END IF;
      ELSE IF mpack_db_target_row.target_type='oracle_pdb'
         THEN
               OPEN mpack_pluggable_on_rac(mpack_db_target_row.target_name);
               FETCH mpack_pluggable_on_rac INTO mpack_pluggable_on_rac_row;
               CLOSE mpack_pluggable_on_rac;
               dbms_output.put_line(mpack_db_target_row.target_name);
               dbms_output.put_line(mpack_pluggable_on_rac_row.rac_flag);
               IF mpack_pluggable_on_rac_row.rac_flag>0
               THEN v_db_type:='PLUGGABLE (RAC)';
               ELSE v_db_type:='PLUGGABLE';
               END IF;
         END IF;
      END IF;

   -- For databases determined to be RAC databases, retrieve a concatenated list of host and instance names
      IF v_db_type IN ('CONTAINER (RAC)', 'NON MULTI-TENANT (RAC)')
      THEN
         v_host_name:=null;
         v_instance_name:=null;
         FOR mpack_rac_instance_row IN mpack_rac_instance(mpack_db_target_row.target_guid) LOOP
               v_instance_name:=v_instance_name||mpack_rac_instance_row.rac_instance_name||',';
               v_host_name:=v_host_name||mpack_rac_instance_row.rac_host||',';
               v_node_count:=v_node_count+1;
         END LOOP;
         v_host_name:=substr(v_host_name,1,length(v_host_name)-1);
         v_instance_name:=substr(v_instance_name,1,length(v_instance_name)-1);
      END IF;

   -- If this is a pluggable database on RAC, inherit the host names from the container

      IF v_db_type = 'PLUGGABLE (RAC)'
      THEN
         v_host_name:=null;
         v_instance_name:=null;
         FOR mpack_rac_instance_row IN mpack_rac_instance(mpack_db_target_row.cdb_target_guid) LOOP
               v_instance_name:=v_instance_name||mpack_rac_instance_row.rac_instance_name||',';
               v_host_name:=v_host_name||mpack_rac_instance_row.rac_host||',';
               v_node_count:=v_node_count+1;
         END LOOP;
         v_host_name:=substr(v_host_name,1,length(v_host_name)-1);
         v_instance_name:=substr(v_instance_name,1,length(v_instance_name)-1);
      END IF;

   -- Retrieve high level instance details for this database.
   -- If this database is a standby database, we will use the details of the primary instead.

      IF mpack_db_target_row.cdb_target_guid IS NOT NULL
      THEN OPEN mpack_dg_status(mpack_db_target_row.cdb_target_guid);
           FETCH mpack_dg_status into mpack_dg_status_row;
           CLOSE mpack_dg_status;
      ELSE OPEN mpack_dg_status(mpack_db_target_row.target_guid);
           FETCH mpack_dg_status into mpack_dg_status_row;
           CLOSE mpack_dg_status;
      END IF;

   -- Get the details of the database. If this database is a pluggable standby database, we will get the details for the primary database defined
   -- at the container level.

      OPEN mpack_instance_detail(nvl(mpack_dg_status_row.dg_primary_guid, mpack_db_target_row.target_guid));
      FETCH mpack_instance_detail INTO mpack_instance_detail_row;
      CLOSE mpack_instance_detail;

      IF mpack_db_target_row.standby_role='PHYSICAL STANDBY'
      OR mpack_dg_status_row.dg_primary_guid IS NOT NULL
      THEN v_db_type:=v_db_type||' STANDBY';
      END IF;

   -- Retrieve high level db host cpu properties for this database

      OPEN mpack_instance_cpu(mpack_db_target_row.host_name);
      FETCH mpack_instance_cpu INTO mpack_instance_cpu_row;
      CLOSE mpack_instance_cpu;

   -- Establish whether OEM Preferred Credentials needed for MPACK Group extracts has been set up for this database
      FOR mpack_db_target_creds_row IN mpack_db_target_creds(mpack_db_target_row.target_guid) LOOP
         IF mpack_db_target_creds_row.set_name = 'DBCredsNormal'
         THEN v_db_creds:='EXISTS';
         END IF;
      END LOOP;

   -- Build the CLOB record for this database by casting the concatenated values to a char
      v_mpack_record:=to_char(
      'MPACK_DB_TARGET'||
      '"'||mpack_db_target_row.target_guid||'",'||
      '"'||mpack_db_target_row.target_name||'",'||
      '"'||mpack_db_target_row.target_type||'",'||
      '"'||v_db_type||'",'||
      '"'||v_pluggable_count||'",'||
      '"'||mpack_db_target_row.cdb_target_guid||'",'||
      '"'||mpack_db_target_row.cdb_target_name||'",'||
      '"'||mpack_db_target_row.cdb_target_type||'",'||
      '"'||case
           when mpack_db_target_row.target_type = 'oracle_pdb'
           then nvl(mpack_instance_detail_row.global_name,'UNMAPPED')
           else nvl(mpack_instance_detail_row.database_name,'UNMAPPED')
           end||'",'||
      '"'||nvl(mpack_instance_detail_row.global_name,'UNMAPPED')||'",'||
      '"'||mpack_db_target_row.database_version||'",'||
      '"'||nvl(v_host_name,mpack_db_target_row.host_name)||'",'||
      '"'||nvl(v_instance_name,mpack_instance_detail_row.instance_name)||'",'||
      '"'||mpack_instance_detail_row.log_mode||'",'||
      '"'||mpack_instance_detail_row.characterset||'",'||
      '"'||mpack_instance_detail_row.national_characterset||'",'||
      '"'||nvl(mpack_dg_status_row.dg_standby_role, mpack_db_target_row.standby_role)||'",'||
      '"'||nvl(mpack_dg_status_row.dg_standby_name, mpack_db_target_row.standby_unique_db_name)||'",'||
      '"'||nvl(mpack_dg_status_row.dg_primary_name, mpack_db_target_row.primary_unique_db_name)||'",'||
      '"'||nvl(mpack_dg_status_row.dg_primary_guid, mpack_db_target_row.primary_target_guid)||'",'||
      '"'||mpack_instance_detail_row.dbinstance_metrics_date||'",'||
      '"'||mpack_db_target_row.operating_system||'",'||
      '"'||mpack_instance_cpu_row.vendor_name||'",'||
      '"'||mpack_instance_cpu_row.freq_in_mhz||'",'||
      '"'||mpack_instance_cpu_row.impl||'",'||
      '"'||mpack_instance_cpu_row.revision||'",'||
      '"'||mpack_instance_cpu_row.instance_count||'",'||
      '"'||mpack_instance_cpu_row.num_cores||'",'||
      '"'||mpack_instance_cpu_row.hyperthreading||'",'||
      '"'||mpack_instance_cpu_row.host_metrics_date||'",'||
      '"'||v_db_creds||'"'||
      chr(10));

   -- Add the char record to the CLOB
     dbms_output.put_line(v_mpack_record);

   -- Finish processing for this database
   END LOOP;

   -- Copy the contents of the PL/SQL CLOB to the SQLPlus CLOB
 exception
   when others then
    dbms_output.put_line('step:'||v_step||' err='||sqlerrm);

END P_MPACK_CATALOG_EXTRACT;

/
--------------------------------------------------------
--  DDL for Procedure P_POPULATE_MIG_DATABASE
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_POPULATE_MIG_DATABASE"
    AUTHID current_user
AS
-- ------------------------------------------------------------------------------------------
/*
v1.0 sept24
-calc and stores values per database

*/
-- ------------------------------------------------------------------------------------------
    v_azure_uoload_sec NUMBER := 0;
    v_count            NUMBER := 0;
    v_error            NUMBER := 0;
    v_upd              NUMBER := 0;
    v_sga              NUMBER := 0;
    v_ecpus            NUMBER := 0;
    v_guid             VARCHAR2(40);
    v_maxrun           TIMESTAMP(6);
    v_active_scenario  mig_infran_param_scenarios%rowtype;
    v_limits_atps      mig_infran_param_technical_limits%rowtype;

BEGIN
    p_log('mig', 'Start pop. mig_database');
    v_count := 0;
    SELECT
        MAX(azure_upload_gb_sec)
    INTO v_azure_uoload_sec
    FROM
        mig_infran_param_technical_limits;

    SELECT
        *
    INTO v_active_scenario
    FROM
        mig_infran_param_scenarios
    WHERE
        active = 'Y';

    SELECT
        *
    INTO v_limits_atps
    FROM
        mig_infran_param_technical_limits
    WHERE
        target_config = 'ATPS';

    UPDATE mig_database
    SET
        sga_gb = NULL,
        pga_gb = NULL,
        alloc_gb = NULL,
        used_gb = NULL,
        anz_ecpus = NULL,
        target_platform = NULL,
        justification = NULL,
        cpu_count_init_par = NULL,
        azure_upload_min = NULL,
        cpat_action_pct = NULL,
        migration_methode = NULL,
        max_downtime_we_hrs = NULL,
        max_downtime_wd_hrs = NULL,
        ha_id = NULL,
        avg_used_cores = NULL
     where frozen = 'N';

    p_log('mig', 'Anz upd1: ' || to_char(SQL%rowcount));
    COMMIT;

    -- set downtime

--    BRONZE            [Mo-Fr 08:00-17:00]       Availability        98.4
--    BRONZE+           [Mo-Fr 08:00-17:00]       Availability        98.4
--    SILVER            [Mo-Fr 06:00-20:00]       Availability        99
--    SILVER+           [Mo-Su 00:00-23:59]       Availability        99.6                  außerhalb von DC Frankfurt / Rüsselsheim, bedeutet eigentlich Hardware-Failover bzw, ein HW- oder VMWare-Cluster ist im gleichen Gebäude aber in über unterschiedliche Räume verteilt
--    GOLD              [Mo-Su 00:00-23:59]       Availability        99.95                nur im DC Frankfurt / Rüsselsheim, ein HW- oder VMWare-Cluster ist über beide RZs verteilt aufgebaut

--    BEGIN
        UPDATE mig_control
        SET
            status = 'Running'
        WHERE
            nr = 23;

        COMMIT;
        UPDATE mig_database
        SET
            max_downtime_wd_hrs = (
                SELECT
                    CASE
                        WHEN service_category = 'BRONZE'  THEN
                            15
                        WHEN service_category = 'BRONZE+' THEN
                            15
                        WHEN service_category = 'SILVER'  THEN
                            10
                        WHEN service_category = 'SILVER+' THEN
                            0
                        ELSE
                            0
                    END AS dts
                FROM
                    dual
            )
            where frozen = 'N';

        p_log('mig', 'Anz upd2: ' || to_char(SQL%rowcount));
        COMMIT;

        UPDATE mig_database
        SET
            max_downtime_we_hrs = (
                SELECT
                    CASE
                        WHEN service_category = 'BRONZE'  THEN
                            63
                        WHEN service_category = 'BRONZE+' THEN
                            63
                        WHEN service_category = 'SILVER'  THEN
                            56
                        WHEN service_category = 'SILVER+' THEN
                            0
                        ELSE
                            0
                    END AS dts
                FROM
                    dual
            )
            where frozen = 'N';

        p_log('mig', 'Anz upd3: ' || to_char(SQL%rowcount));
        COMMIT;

        UPDATE mig_database
        SET alloc_gb = (
            SELECT maximum
            FROM (
                SELECT maximum
                FROM mig_em_metric_db_hrs
                WHERE target_guid = mig_database.db_target_guid
                  AND metric_column = v_active_scenario.storage_metric
                ORDER BY rollup_ts DESC
            ) WHERE ROWNUM = 1
        )
        where frozen = 'N';

/*
        UPDATE mig_database
        SET
            alloc_gb = (
                SELECT
                    maximum
                FROM
                    mig_em_metric_db_hrs
                WHERE
                        target_guid = mig_database.db_target_guid
                    AND metric_column = v_active_scenario.storage_metric
                ORDER BY
                    rollup_ts DESC
                FETCH FIRST ROW ONLY
            );
*/
        p_log('mig', 'Anz upd5: ' || to_char(SQL%rowcount));
        COMMIT;

        UPDATE mig_database
        SET used_gb = (
            SELECT maximum
            FROM (
                SELECT maximum
                FROM mig_em_metric_db_hrs
                WHERE target_guid = mig_database.db_target_guid
                  AND metric_column = v_active_scenario.used_storage_metric
                ORDER BY rollup_ts DESC
            ) WHERE ROWNUM = 1
        )
        where frozen = 'N';

/*
        UPDATE mig_database
        SET
            used_gb = (
                SELECT
                    maximum
                FROM
                    mig_em_metric_db_hrs
                WHERE
                        target_guid = mig_database.db_target_guid
                    AND metric_column = v_active_scenario.used_storage_metric
                ORDER BY
                    rollup_ts DESC
                FETCH FIRST ROW ONLY
            );
*/

        p_log('mig', 'Anz upd6: ' || to_char(SQL%rowcount));
        COMMIT;

        UPDATE mig_database
        SET sga_gb = (
            SELECT average
            FROM mig_em_metric_db_hrs
            WHERE target_guid = mig_database.db_target_guid
              AND metric_column = v_active_scenario.sga_metric
            ORDER BY rollup_ts DESC
            FETCH FIRST ROW ONLY
        )
        where frozen = 'N';

/*
        UPDATE mig_database
        SET
            sga_gb = (
                SELECT
                    average
                FROM
                    mig_em_metric_db_hrs
                WHERE
                        target_guid = mig_database.db_target_guid
                    AND metric_column = v_active_scenario.sga_metric
                ORDER BY
                    rollup_ts DESC
                FETCH FIRST ROW ONLY
            );
*/
        p_log('mig', 'Anz upd7: ' || to_char(SQL%rowcount));
        COMMIT;

        UPDATE mig_database
        SET sga_gb = (
            SELECT average
            FROM (
                SELECT average
                FROM mig_em_metric_db_hrs
                WHERE target_guid = mig_database.db_target_guid
                  AND metric_column = 'sga_total'
                ORDER BY rollup_ts DESC
                FETCH FIRST ROW ONLY
            )
        )
        WHERE sga_gb IS NULL
        and frozen = 'N';

        p_log('mig', 'Anz upd7a: ' || to_char(SQL%rowcount));
        COMMIT;

        UPDATE mig_database
        SET pga_gb = (
                SELECT NVL(average, 0)
                FROM (
                        SELECT average
                        FROM mig_em_metric_db_hrs
                        WHERE target_guid = mig_database.db_target_guid
                          AND metric_column = v_active_scenario.pga_metric
                        FETCH FIRST 1 ROW ONLY
                )
        )
        where frozen = 'N';

     -- Update cpu_count_init_par
    UPDATE mig_database
    SET cpu_count_init_par = (
        SELECT value
        FROM mig_db_init_params
        WHERE target_guid = mig_database.db_target_guid
          AND name = 'cpu_count'
    )
    where frozen = 'N';
    p_log('mig', 'Anz upd8: ' || TO_CHAR(SQL%ROWCOUNT));

    -- Update avg_used_cores
    UPDATE mig_database
    SET avg_used_cores = (
        SELECT AVG(average)
        FROM mig_em_metric_db_hrs
        WHERE target_guid = mig_database.db_target_guid
          AND metric_column = v_active_scenario.cpu_metric
    )
    where frozen = 'N';
    p_log('mig', 'Anz upd9: ' || TO_CHAR(SQL%ROWCOUNT));

    -- Update avg_used_cores if NULL
    UPDATE mig_database
    SET avg_used_cores = (
        SELECT AVG(average)
        FROM mig_em_metric_db_hrs
        WHERE target_guid = mig_database.db_target_guid
          AND metric_column = 'regular_cpu'
    )
    WHERE NVL(avg_used_cores, 0) = 0
    and frozen = 'N';
    p_log('mig', 'Anz upd10: ' || TO_CHAR(SQL%ROWCOUNT));

    -- Update anz_ecpus
    UPDATE mig_database
    SET anz_ecpus = avg_used_cores * v_active_scenario.ecpu_multiplicator
    where frozen = 'N';
    p_log('mig', 'Anz upd11: ' || TO_CHAR(SQL%ROWCOUNT));

    -- Ensure anz_ecpus minimum limit
    UPDATE mig_database
    SET anz_ecpus = v_limits_atps.min_ecpu
    WHERE anz_ecpus < v_limits_atps.min_ecpu
    and  frozen = 'N';
    p_log('mig', 'Anz upd12: ' || TO_CHAR(SQL%ROWCOUNT));

    -- Ensure alloc_gb minimum limit
    UPDATE mig_database
    SET alloc_gb = v_limits_atps.min_storage_gb
    WHERE alloc_gb < v_limits_atps.min_storage_gb
    and frozen = 'N';
    p_log('mig', 'Anz upd13: ' || TO_CHAR(SQL%ROWCOUNT));

    -- Update businessappl from mig_xls_1710_inscope
    UPDATE mig_database
    SET businessappl = (
          SELECT
             distinct a."BusinessAppl"
          FROM
           masterdata.modernex_1st_scope a
          WHERE LOWER(a."OracleDB") = LOWER(mig_database.oracledb)
          AND LOWER(a."OracleDB") NOT LIKE 'dg%'
          fetch first row only
    )
    where frozen = 'N';

    p_log('mig', 'Anz upd14: ' || TO_CHAR(SQL%ROWCOUNT));

--# update from masterdata iif still null

-- 1. Update alloc_gb only if it is NULL
UPDATE mig_database d
SET d.alloc_gb = (
  SELECT o.ts_defined / 1024
  FROM masterdata.oracle_overview_mv o
  WHERE LOWER(d.oracledb) = LOWER(o.mw_name)
)
WHERE d.alloc_gb IS NULL
  and frozen = 'N'
  AND EXISTS (
    SELECT 1 FROM masterdata.oracle_overview_mv o
    WHERE LOWER(d.oracledb) = LOWER(o.mw_name)
  );
    p_log('mig', 'Anz upd15: ' || TO_CHAR(SQL%ROWCOUNT));

-- 2. Update used_gb only if it is NULL
UPDATE mig_database d
SET d.used_gb = (
  SELECT o.ts_used / 1024
  FROM masterdata.oracle_overview_mv o
  WHERE LOWER(d.oracledb) = LOWER(o.mw_name)
)
WHERE d.used_gb IS NULL
  and frozen = 'N'
  AND EXISTS (
    SELECT 1 FROM masterdata.oracle_overview_mv o
    WHERE LOWER(d.oracledb) = LOWER(o.mw_name)
  );
    p_log('mig', 'Anz upd16: ' || TO_CHAR(SQL%ROWCOUNT));

-- 3. Update sga_gb only if it is NULL
UPDATE mig_database d
SET d.sga_gb = (
  SELECT o.sga / 1024
  FROM masterdata.oracle_overview_mv o
  WHERE LOWER(d.oracledb) = LOWER(o.mw_name)
)
WHERE d.sga_gb IS NULL
  and frozen = 'N'
  AND EXISTS (
    SELECT 1 FROM masterdata.oracle_overview_mv o
    WHERE LOWER(d.oracledb) = LOWER(o.mw_name)
  );

    p_log('mig', 'Anz upd17: ' || TO_CHAR(SQL%ROWCOUNT));

    -- Set default for pga_gb if NULL
    UPDATE mig_database
    SET pga_gb = sga_gb * 0.1
    WHERE pga_gb IS NULL
    and frozen = 'N';
    p_log('mig', 'Anz upd18: ' || TO_CHAR(SQL%ROWCOUNT));

    -- Round numeric values
    UPDATE mig_database
    SET sga_gb = ROUND(sga_gb, 3),
        pga_gb = ROUND(pga_gb, 3),
        anz_ecpus = ROUND(anz_ecpus, 3),
        alloc_gb = ROUND(alloc_gb, 3),
        used_gb = ROUND(used_gb, 3),
        azure_upload_min = ROUND(azure_upload_min, 3),
        cpat_action_pct = ROUND(cpat_action_pct, 3),
        avg_used_cores = ROUND(avg_used_cores, 3)
        where frozen = 'N';
    p_log('mig', 'Anz upd19: ' || TO_CHAR(SQL%ROWCOUNT));

   -- Update mig_control status
    UPDATE mig_control
    SET status = 'finished'
    WHERE nr = 23;
    p_log('mig', 'Process completed successfully.');

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_log('mig', 'Error occurred: ' || SQLERRM);
        p_log('mig', 'Error backtrace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);

        UPDATE mig_control
        SET status = 'finished with errors'
        WHERE nr = 23;

        COMMIT;
END;

/
--------------------------------------------------------
--  DDL for Procedure P_PROV_ADB
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_PROV_ADB" AS

/*
v1.0 sept24
-provisions pdb instances for adb-s databases
*/
    quit_db EXCEPTION;

    v_az_dc1                      mig_infran_param_azure_location.azure_dc%TYPE;
    v_az_dc2                      mig_infran_param_azure_location.azure_dc%TYPE;

    V_DG_id                       VARCHAR2(10) := 'DG';
    db_placement_dc               VARCHAR2(10);
    total_databases_processed     NUMBER := 0;
    total_placement_changes       NUMBER := 0;
    total_rac_instances           NUMBER := 0;
    total_instances               NUMBER := 0;
    total_errors                  NUMBER := 0;
    total_db_quits                NUMBER := 0;
    total_dg_instances            NUMBER := 0;
    total_adjustments_cpu         NUMBER := 0;
    total_adjustments_storage     NUMBER := 0;
    helper_cpu                    NUMBER := 0;
    helper_storage                NUMBER := 0;
    loop_counter                  NUMBER := 0;
    adb_min_cores                 NUMBER := 0;
    adb_min_gb                    NUMBER := 0;
    metric_error_count            NUMBER := 0;
    new_instance_id               NUMBER := 0;
    current_instance_id           NUMBER := 0;
    db_target                     VARCHAR2(20);
    quit_reason                   VARCHAR2(200);
    core_adjustment_factor        NUMBER := 0;
    sga_adjustment_factor         NUMBER := 0;
    pga_adjustment_factor         NUMBER := 0;
    used_space_adjustment_factor  NUMBER := 0;
    alloc_space_adjustment_factor NUMBER := 0;
    iops_adjustment_factor        NUMBER := 0;
    session_adjustment_factor     NUMBER := 0;
    step_marker                   NUMBER := 0;
    metric_index                  NUMBER := 0;
    return_value                  NUMBER := 0;
    primary_instance_number       NUMBER := 1;
    standby_instance_number       NUMBER := 1;
    total_ecpus                   NUMBER := 0;
    ecpu_per_instance             NUMBER := 0;
    primary_data_center           VARCHAR2(20);
    standby_data_center           VARCHAR2(20);
    v_gb_mem_per_ecpu             NUMBER := 0;
    v_sessions_per_ecpu           NUMBER := 0;
    v_sessions_per_phys_core      NUMBER := 0;
    v_read_iops_per_gb            NUMBER := 0;
    v_write_iops_per_gb           NUMBER := 0;
    v_min_ecpu                    NUMBER := 0;
    v_min_storage_gb              NUMBER := 0;
    v_rac                         NUMBER := 0;
    v_description                 VARCHAR2(250);
    v_pga                         NUMBER := 0;
    v_sga                         NUMBER := 0;
    v_used_gb                     NUMBER := 0;
    v_dg_rac                      NUMBER := 0;
    v_pr_rac                      NUMBER := 0;
    v_ecpu_instance               NUMBER := 0;
    v_alloc_gb                    NUMBER := 0;
    v_write_iops                  NUMBER := 0;
    v_read_iops                   NUMBER := 0;
    v_ecpu_target                 NUMBER := 0;
    v_ret                         NUMBER := 0;
    v_db_quits                    NUMBER := 0;
    v_occa_metric                 NUMBER := 0;
    v_divisor                     NUMBER := 0;
    v_exa_mem_bonus               NUMBER := 1;
    v_exa_cpu_bonus               NUMBER := 1;
    v_dg_rule                     char(1) := 'N';

    v_adb                         mig_infran_adb_instance%ROWTYPE;
    v_adb_limits                  mig_infran_param_technical_limits%ROWTYPE;
    v_active_scenario mig_infran_param_scenarios%ROWTYPE;

    -- Record type for metrics
    TYPE metric_record IS RECORD (
        id          NUMBER,
        min_value   NUMBER,
        avg_value   NUMBER,
        max_value   NUMBER,
        cat_value   NUMBER,
        metric_cat  varchar2(10),
        metric_name VARCHAR2(40)
    );

    -- Table of metrics
    TYPE metric_table IS
        TABLE OF metric_record INDEX BY PLS_INTEGER;
    metrics                       metric_table;

    -- Cursor for databases
    CURSOR database_cursor IS
    SELECT
        oracledb,
        db_target_guid,
        environment,
        service_category,
        alloc_gb,
        pga_gb,
        sga_gb,
        anz_ecpus,
        avg_used_cores,
        used_gb,
        anz_db_links,
        ha_id,
        target_platform,
        data_classification
    FROM
        mig_database
    WHERE
        target_platform = 'ATPS'
   -- and db_target_guid = '769DE2EC11AC2F0EBCA47A38E38A1FB2'
    ;

    -- Function to calculate core count
    FUNCTION get_core_count (
        data_center VARCHAR2
    ) RETURN NUMBER IS
        core_count NUMBER := 0;
    BEGIN
        SELECT
            nvl(SUM(anz_ecpus),0)
        INTO core_count
        FROM
            mig_infran_adb_instance
        WHERE
            azure_dc = data_center;
        RETURN core_count;
    EXCEPTION
        WHEN no_data_found THEN
        RETURN 0;
    END get_core_count;

BEGIN

    p_log('mig', 'Start provisioning ADB instances');
    COMMIT;

    SELECT   rule_active into v_dg_rule
    FROM   mig_infran_param_rules
    where  rule_nr = 7; --DG Rule

    v_ret := f_set_status (40,'Running');
    update mig_control set status = null
    where nr > 40 and nr < 50;
    commit;

    select * into v_active_scenario
    FROM mig_infran_param_scenarios
    where active = 'Y';

   select azure_dc into v_az_dc1
   from mig_infran_param_azure_location
   where target_platform = 'ATPS'
   and dc_nr = 1;

   select azure_dc into v_az_dc2
   from mig_infran_param_azure_location
   where target_platform = 'ATPS'
   and dc_nr = 2;

    v_ret := f_set_status (41,'Running');

   step_marker :=22;
   -- Initialize metrics
      p_log('mig', '***Use EM Metric');
      metrics(1) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.session_metric);
      metrics(2) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.write_io_metric);
      metrics(3) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.read_io_metric);
      metrics(4) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.cpu_metric);
      metrics(5) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.sga_metric);
      metrics(6) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.pga_metric);
      metrics(7) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.storage_metric);
      metrics(8) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.used_storage_metric);

    v_ret := f_set_status (41,'finished');
    v_ret := f_set_status (42,'Running');
    -- read limits
    select * into v_adb_limits
    FROM    mig_infran_param_technical_limits
    where   target_config = 'ATPS';

    -- clear table
        DELETE FROM mig_infran_adb_instance;

      v_ret := f_set_status (42,'finished');
    v_ret := f_set_status (43,'Running');

    -- Loop through each database
    FOR db_record IN database_cursor LOOP
    begin

        step_marker := 13;
        total_databases_processed := total_databases_processed + 1;

        -- Change placement if needed depending on # of cores
        db_placement_dc := v_az_dc1;
        IF get_core_count(v_az_dc1) > get_core_count(v_az_dc2) THEN
            db_placement_dc := v_az_dc2;
            total_placement_changes := total_placement_changes + 1;
        END IF;
        step_marker := 14;

          FOR metric_index IN 1..metrics.COUNT LOOP
            -- Read metrics
            return_value := f_db_metrics (
                db_record.db_target_guid,
                metrics(metric_index).metric_name,
                metrics(metric_index).min_value,
                metrics(metric_index).avg_value,
                metrics(metric_index).max_value,
                metrics(metric_index).cat_value,
                metrics(metric_index).metric_cat );

            IF return_value <> 0 THEN
                metric_error_count := metric_error_count + 1;
            END IF;
        END LOOP;
        step_marker := 2;

/*
    -- disable for adbs
    -- exa advontages
    select (100 - exa_cpu_bonus_pct)/100,
           (100 - exa_mem_bonus_pct)/100 into
           v_exa_cpu_bonus,
           v_exa_mem_bonus
    from mig_infran_param_exa_specs
    where active = 'Y';
*/
      v_exa_cpu_bonus           := 1;
      v_exa_mem_bonus           := 1;
      v_adb.instance_name       := db_record.oracledb;
      v_adb.data_classification := db_record.data_classification;
      v_adb.old_target_guid     := db_record.db_target_guid;
      v_adb.environment         := db_record.environment;
      v_adb.service_category    := db_record.service_category;

      if v_active_scenario.use_maximum_metrics = 'Y'
      then
         v_adb.anz_ecpus           := (metrics(4).max_value * v_adb_limits.ecpu_core_faktor); -- possible to burst
         v_adb.pga_gb              := round(metrics(6).max_value * v_exa_mem_bonus,3);
         v_adb.sga_gb              := round(metrics(5).max_value * v_exa_mem_bonus,3);
         v_adb.alloc_gb            := round(metrics(7).max_value,3);
         v_adb.avg_used_ecpus      := ((metrics(4).max_value * v_adb_limits.ecpu_core_faktor) * v_exa_cpu_bonus);
      else
         v_adb.anz_ecpus           := (metrics(4).avg_value * v_adb_limits.ecpu_core_faktor); -- possible to burst
         v_adb.pga_gb              := round(metrics(6).avg_value * v_exa_mem_bonus,3);
         v_adb.sga_gb              := round(metrics(5).avg_value * v_exa_mem_bonus,3);
         v_adb.alloc_gb            := round(metrics(7).avg_value,3);
         v_adb.avg_used_ecpus      := ((metrics(4).avg_value * v_adb_limits.ecpu_core_faktor) * v_exa_cpu_bonus);
      end if;

      if v_adb.anz_ecpus < 2 then
         v_adb.anz_ecpus := 2;
       end if;

      v_adb.orig_ecpus          := db_record.anz_ecpus/2; -- possible to burst
      v_adb.orig_alloc_gb       := db_record.alloc_gb;
      v_adb.orig_mem            := db_record.pga_gb + db_record.sga_gb;
  --    v_adb.anz_ecpus           := (db_record.anz_ecpus)* v_exa_cpu_bonus ; -- possible to burst
  --    v_adb.anz_ecpus           := (metrics(4).avg_value * v_adb_limits.ecpu_core_faktor); -- possible to burst
      v_adb.max_used_ecpu       := ((metrics(4).max_value * v_adb_limits.ecpu_core_faktor) * v_exa_cpu_bonus);
      v_adb.used_gb             := round(metrics(8).max_value,3);
      v_adb.avg_sessions        := round(metrics(1).avg_value,3);
      v_adb.max_sessions        := round(metrics(1).max_value,3);
      v_adb.avg_wr_iops         := round(metrics(2).avg_value,3);
      v_adb.max_wr_iops         := round(metrics(2).max_value,3);
      v_adb.avg_read_iops       := round(metrics(3).avg_value,3);
      v_adb.max_read_iops       := round(metrics(3).max_value,3);
      v_adb.instance_id          := s1.nextval;
      v_adb.adb_type            := db_record.target_platform;
      v_adb.dg_type             := NULL;
      v_adb.dg_remote_id        := NULL;
      v_adb.azure_dc            := db_placement_dc;
      v_adb.anz_db_links        := db_record.anz_db_links;
      v_adb.inst_nr             := 1;
      v_adb.description         := null;
      v_adb.ha_id               := db_record.ha_id;
      v_adb.split_instance      := 'N';
      v_adb.dg_remote_nr        := null;

        step_marker := 3;

      --dbms_output.put_line (v_adb.instance_name||' SGA='||to_char(v_adb.sga_gb));
      --dbms_output.put_line (v_adb.instance_name||' cpu='||to_char(v_adb.anz_ecpus));

      -- apply rules
      return_value := f_apply_adb_rules (v_adb, v_adb_limits,
                            helper_cpu, helper_storage);
      if return_value <> 0 then
         quit_reason := 'failure with adjustments on database '||db_record.db_target_guid;
         raise quit_db;
      end if;
        step_marker := 4;

      --dbms_output.put_line (v_adb.instance_name||' SGA='||to_char(v_adb.sga_gb));
      --dbms_output.put_line (v_adb.instance_name||' cpu='||to_char(v_adb.anz_ecpus));

      total_adjustments_cpu      := total_adjustments_cpu + helper_cpu;
      total_adjustments_storage  := total_adjustments_storage + helper_storage ;

      --dbms_output.put_line (v_adb.instance_name||' SGA='||to_char(v_adb.sga_gb));
      --dbms_output.put_line (v_adb.instance_name||' CPU='||to_char(v_adb.anz_ecpus));

      return_value := f_create_adb_inst(v_adb, v_adb_limits, 'NoDG',loop_counter);
       -- p_log('mig', '# RAC instances provisioned:    ' || TO_CHAR(loop_counter));
        step_marker := 5;

      --dbms_output.put_line (v_adb.instance_name||' SGA='||to_char(v_adb.sga_gb));

      IF return_value <> 0 THEN
               quit_reason := 'insert adb_instance for '||db_record.db_target_guid;
               RAISE quit_db;
      END IF;
      if loop_counter > 1 then
         v_pr_rac := v_pr_rac + loop_counter;
      end if;
      total_instances := total_instances + 1;

   update mig_infran_adb_instance
      SET  pga_gb = round(pga_gb,3),
           sga_gb = round(sga_gb,3);

      --- DG Instance ?
      --    dbms_output.put_line (v_adb.instance_name||' DG???????????? '||v_dg_rule);

      if (v_adb.ha_id = v_dg_id and v_dg_rule = 'Y')
      then
          commit;
          return_value := f_create_adb_inst(v_adb, v_adb_limits, 'stdby',loop_counter);
          step_marker := 5;
          IF return_value <> 0 THEN
               quit_reason := 'insert STDBY adb_instance for '||db_record.db_target_guid;
               RAISE quit_db;
          END IF;
          dbms_output.put_line (v_adb.instance_name||' DG???????????? '||v_dg_rule);
          if loop_counter > 1 then
             v_dg_rac := v_dg_rac + loop_counter;
          end if;
          total_DG_instances := total_DG_instances + 1;
      end if;
   exception
     when quit_db then
          rollback;
          total_db_quits := total_db_quits + 1;
            p_log('mig', 'Provisioning ADB instances: An error occurred: ' || quit_reason);
            COMMIT;
   END;

 END LOOP;
       v_ret := f_set_status (43,'finished');

    -- Detailed statistics
    COMMIT;
    p_log('mig', '# Databases processed:          ' || TO_CHAR(total_databases_processed));
    p_log('mig', '# DB instances provisiodned:    ' || TO_CHAR(total_instances));
    p_log('mig', '# DB-DG instances provisiodned: ' || TO_CHAR(total_DG_instances));
    p_log('mig', '# DB adjustments cpu:           ' || TO_CHAR(total_adjustments_cpu));
    p_log('mig', '# DB adjustments storage        ' || TO_CHAR(total_adjustments_storage));
    p_log('mig', '# RAC instances provisioned:    ' || TO_CHAR(V_PR_RAC));
    p_log('mig', '# DG-RAC instances provisioned: ' || TO_CHAR(v_dg_rac));
    p_log('mig', '# Placement changes:            ' || TO_CHAR(total_placement_changes));
    p_log('mig', '# Metric errors:                ' || TO_CHAR(metric_error_count));
    p_log('mig', '# database quits:               ' || TO_CHAR(total_db_quits));
    p_log('mig', '# Other errors:                 ' || TO_CHAR(total_errors));
    p_log('mig', 'End provision ADB instances');
    COMMIT;
    v_ret := f_set_status (40,'Finished');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
             p_log('mig', 'Provisioning ADB instances: An error occurred: ' || TO_CHAR(step_marker) || ' ' || SQLERRM);
             v_ret := f_set_status (40,'Finished with errors');

            COMMIT;

END P_PROV_ADB;

/
--------------------------------------------------------
--  DDL for Procedure P_SEND_MAIL
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_SEND_MAIL" (
  msg_to varchar2,
  msg_subject varchar2,
  msg_text varchar2 )
IS

  mail_conn utl_smtp.connection;
  username varchar2(1000):= 'ocid1.user.oc1.username';
  passwd varchar2(50):= 'password';
  msg_from varchar2(50) := 'adam@example.com';
  mailhost VARCHAR2(50) := 'smtp.us-ashburn-1.oraclecloud.com';

BEGIN
  mail_conn := UTL_smtp.open_connection(mailhost, 587);
  utl_smtp.starttls(mail_conn);

  UTL_SMTP.AUTH(mail_conn, username, passwd, schemes => 'PLAIN');

  utl_smtp.mail(mail_conn, msg_from);
  utl_smtp.rcpt(mail_conn, msg_to);

  UTL_smtp.open_data(mail_conn);

  UTL_SMTP.write_data(mail_conn, 'Date: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || UTL_TCP.crlf);
  UTL_SMTP.write_data(mail_conn, 'To: ' || msg_to || UTL_TCP.crlf);
  UTL_SMTP.write_data(mail_conn, 'From: ' || msg_from || UTL_TCP.crlf);
  UTL_SMTP.write_data(mail_conn, 'Subject: ' || msg_subject || UTL_TCP.crlf);
  UTL_SMTP.write_data(mail_conn, 'Reply-To: ' || msg_to || UTL_TCP.crlf || UTL_TCP.crlf);
  UTL_SMTP.write_data(mail_conn, msg_text || UTL_TCP.crlf || UTL_TCP.crlf);

  UTL_smtp.close_data(mail_conn);
  UTL_smtp.quit(mail_conn);

EXCEPTION
  WHEN UTL_smtp.transient_error OR UTL_smtp.permanent_error THEN
    UTL_smtp.quit(mail_conn);
    dbms_output.put_line(sqlerrm);
  WHEN OTHERS THEN
    UTL_smtp.quit(mail_conn);
    dbms_output.put_line(sqlerrm);
END;

/
--------------------------------------------------------
--  DDL for Procedure P_START_CALCULATION
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_START_CALCULATION" AS
/*
v1.0 sept24
-Main Program for calculate requirements for migration
*/

    v_cnt1 NUMBER := 0;
    v_cnt2 NUMBER := 0;
BEGIN
   -- reset cintrl table
    update mig_control set status = null;
    commit;

    update mig_control set status = 'Running'
    where nr = 20;
    commit;

    delete from mig_log;
    p_log('mig', '---Start calculation---');
    p_log('mig', '=================================');
    p_log('mig', 'Step1: create metric range tabs');

    -- P_LOAD_EM_DATA;
    commit;

    p_metric_ranges_db_hrs;
    SELECT   COUNT(*) INTO v_cnt1
    FROM mig_calc_metrics_ranges_db;

    SELECT COUNT(*) INTO v_cnt2
    FROM mig_calc_metrics_ranges;

    IF v_cnt1 > 5000 AND v_cnt2 > 5
    THEN
         p_log('mig', '====================================');
         p_log('mig', 'Step2: create metric fine statistics');
        commit;
        p_fine_loadstat;

        SELECT COUNT(*) INTO v_cnt1
        FROM mig_calc_metrics_ranges_db
        WHERE cnt_all IS NULL;

        IF v_cnt1 = 0 THEN
            p_log('mig', '=================================');
            p_log('mig', 'Step3: populate mig_db');
            commit;
            p_populate_mig_database;

            P_LOW_MIGRATION_FRUITS;

            SELECT COUNT(*) INTO v_cnt1
            FROM mig_database
            WHERE  sga_gb IS NULL
                OR pga_gb IS NULL
                OR alloc_gb IS NULL
                OR used_gb IS NULL
                OR AVG_USED_CORES IS NULL
                OR anz_ecpus IS NULL;

            IF v_cnt1 < 10 THEN
                p_log('mig', '=================================');
                p_log('mig', 'Step4: create cpu lod mig_db');
                p_cr_cpu_load;
                commit;
                p_log('mig', '=================================');
                p_log('mig', 'Step5: check infra lim mig_db');
                p_test_infra_limits;
                commit;
                p_log('mig', '=================================');
                p_log('mig', 'Step6: classyfy mig_db');
                p_classify_dbs;
                commit;
            ELSE
                p_log('mig', 'Step3: failure');
            END IF;

        ELSE
            p_log('mig', 'Step2: failure');
        END IF;

    ELSE
        p_log('mig', 'Step1: failure');
    END IF;

    p_log('mig', '---End calculation---');
    update mig_control set status = 'finished'
    where nr = 20;
     COMMIT;
     v_cnt1 := f_log_to_dbms_out;
EXCEPTION
    WHEN OTHERS THEN
       rollback;
       p_log ('mig','error calculation ' || SQLERRM);
       update mig_control set status = 'finished with errors'
       where nr = 20;
       COMMIT;

END p_start_calculation;

/
--------------------------------------------------------
--  DDL for Procedure P_TEST_INFRA_LIMITS
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_TEST_INFRA_LIMITS" AS
/*
v1.0 sept24
-checks which db exeeeds adb-s limits, stores result in table
*/
    v_count        NUMBER := 0;
    v_error        NUMBER := 0;
    v_upd          NUMBER := 0;
    v_test         NUMBER := 0;
    v_ret          NUMBER := 0;
    v_sess         NUMBER := 0;
    v_calc_value   NUMBER := 0;
    v_plan_value   NUMBER := 0;
    v_inc_ecpus    NUMBER := 0;
    v_metric_value NUMBER := 0;

-- Einlesen dbs
    v_limit_rec  mig_infran_param_technical_limits%ROWTYPE;
 -- Einlesen dbs
    CURSOR c_mdb IS
    SELECT
        db_target_guid,
        pga_gb,
        sga_gb,
        anz_ecpus,
        alloc_gb
    FROM
        mig_database;

    FUNCTION store_limit (
        p_guid   VARCHAR2,
        p_config VARCHAR2,
        p_desc   VARCHAR2,
        p_value1 NUMBER,
        p_value2 NUMBER,
        p_rulenr number
    ) RETURN NUMBER IS
    BEGIN
        BEGIN
           if f_is_rule_active(p_rulenr) = 1
           then
            INSERT INTO mig_calc_db_exeeds_limit (
                db_target_guid,
                target_config,
                limit_desc,
                tvalue,
                cvalue
            ) VALUES (
                p_guid,
                p_config,
                p_desc,
                round(p_value1,3),
                round(p_value2,3)
            );
           end if;
           RETURN 0;
        EXCEPTION
            WHEN OTHERS THEN
                RETURN 1;
        END;
    END store_limit;

BEGIN
    p_log('mig', 'Start check infra limits');

    update mig_control set status = 'Running'
       where nr = 24;
    COMMIT;

    v_count := 0;
    DELETE FROM mig_CALC_db_exeeds_limit;

    select * into v_limit_rec
    from  mig_infran_param_technical_limits
    where target_config = 'ATPS';

    FOR xdb IN c_mdb LOOP
        commit;
        v_count := v_count + 1;
        v_plan_value := round(xdb.anz_ecpus,3); --planed
        v_calc_value := round(( xdb.sga_gb + xdb.pga_gb ) / v_limit_rec.gb_mem_per_ecpu,3); --needed for mem
        -- cechk
        if v_plan_value < v_calc_value then
            if (v_calc_value/v_plan_value) > v_limit_rec.ATPS_EXEED_TOLERANZ_FACTOR then
               -- too expensive
                v_ret := store_limit(xdb.db_target_guid, 'ATPS', 'ecpu/mem ratio ',v_plan_value,v_calc_value,20);
            else
               -- increase
               v_plan_value := v_calc_value;
           end if;
        end if;

        BEGIN

           SELECT  a.average   INTO v_metric_value
           FROM mig_calc_metrics_ranges_db a
           WHERE a.target_guid = xdb.db_target_guid
           AND a.metric_column = 'avg_active_sessions';

           v_calc_value := round(v_metric_value / v_limit_rec.sessions_per_ecpu,3); --needed for mem

           -- cechk
           if v_plan_value < v_calc_value then
             if (v_calc_value/v_plan_value) > v_limit_rec.ATPS_EXEED_TOLERANZ_FACTOR then
               -- too expensive
                v_ret := store_limit(xdb.db_target_guid, 'ATPS', 'ecpu/mem ratio ',v_plan_value,v_calc_value,21);
             else
                -- increase
                v_plan_value := v_calc_value;
             end if;
          end if;

         If xdb.anz_ecpus < v_plan_value then
                update mig_database
                   set anz_ecpus = v_plan_value
                where mig_database.db_target_guid = xdb.db_target_guid;
                v_inc_ecpus := v_inc_ecpus +1;
         end if;

        EXCEPTION
                WHEN OTHERS THEN
                    p_log('mig', 'EX3 ' ||xdb.db_target_guid||' '|| sqlerrm);
                    COMMIT;
        END;

       -- check read iops
            BEGIN
                SELECT
                    AVG(a.average)
                INTO v_metric_value
                FROM
                    mig_calc_metrics_ranges_db a
                WHERE
                        a.target_guid = xdb.db_target_guid
                    AND a.metric_column = 'physreads_ps';

                v_test := v_metric_value / xdb.alloc_gb;
                IF v_test < v_limit_rec.read_iops_per_gb THEN
                    v_ret := store_limit(xdb.db_target_guid, 'ATPS', 'read iops/gb ratio '
                                                                                 || to_char(v_metric_value)
                                                                                 || '/'
                                                                                 || to_char(xdb.alloc_gb), v_limit_rec.read_iops_per_gb, v_test,23);

                    v_upd := v_upd + 1;
                    v_error := v_error + v_ret;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    p_log('mig', 'EX1 ' ||xdb.db_target_guid||' '|| sqlerrm);
                    COMMIT;
            END;

        -- check write iops

            BEGIN
                SELECT
                    AVG(a.average)
                INTO v_metric_value
                FROM
                    mig_calc_metrics_ranges_db a
                WHERE
                        a.target_guid = xdb.db_target_guid
                    AND a.metric_column = 'physwrites_ps';

                v_test := v_metric_value / xdb.alloc_gb;
                IF v_test > v_limit_rec.write_iops_per_gb THEN
                    v_ret := store_limit(xdb.db_target_guid, v_limit_rec.target_config, 'writes iops/gb ratio '
                                                                                 || to_char(v_metric_value,24)
                                                                                 || '/'
                                                                                 || to_char(xdb.alloc_gb), v_limit_rec.read_iops_per_gb, v_test,24);

                    v_upd := v_upd + 1;
                    v_error := v_error + v_ret;
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    p_log('mig', 'EX2 ' || sqlerrm);
                    COMMIT;
            END;
    end loop;

    delete from mig_calc_db_exeeds_limit
    where (tvalue *  v_limit_rec.ATPS_EXEED_TOLERANZ_FACTOR) >= cvalue;

    COMMIT;

    p_log('mig', 'Ende check infra limits');

    update mig_control set status = 'finished'
       where nr = 24;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        p_log('mig', 'pop. Mig DB: An error occurred: ' || sqlerrm);
               update mig_control set status = 'finished with errors'
       where nr = 24;
       commit;

        COMMIT;
END;

/
--------------------------------------------------------
--  DDL for Procedure P_UPDATE_MIGINFOS
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "MIGRATIONV2"."P_UPDATE_MIGINFOS" AS

  -- Prüfdaten für View v_mig_modernex
  v_rowcount    NUMBER;
  v_checksum    NUMBER;
  v_prev_count  NUMBER := -1;
  v_prev_sum    NUMBER := -1;

  -- Cursor für Hauptverarbeitung
  CURSOR mwinfo IS
SELECT
    "OracleDB"                                  as srcname,
    replaced_by                                 as replaced_by,
    "Proposed Target Platform"                  as mod_target_platform,
    "MODERNEX Proposed Migration Scenario"      as mod_target_migr_methode,
    case "MODERNEX Migration Cluster"
        when 'Pilot'      then 'Cluster 0'
        when 'Cluster 01' then 'Cluster 1'
        when 'Cluster 02' then 'Cluster 2'
        when 'Cluster 03' then 'Cluster 3'
        when 'Cluster 04' then 'Cluster 4'
        when 'Cluster 05' then 'Cluster 5'
        when 'Cluster 06' then 'Cluster 6'
        when 'Cluster 07' then 'Cluster 7'
        when 'Cluster 08' then 'Cluster 8'
        when 'Cluster 09' then 'Cluster 9'
        else "MODERNEX Migration Cluster"
    end                                         as mod_mig_cluster,
    case "Environment"
      when 'Production' then 'Prod'
      else 'DTQC'
    end                                          as MOD_env,
    case "Data Classification"
      when 'Confidential' then 'Confidential'
      else 'NONE'
    end                                         as mod_dataclass,
    "BusinessAppl"                              as mod_app_name,
    "Environment"                               as MOD_env_orig
FROM
        v_md_modernex_1st_scope
    WHERE ("MODERNEX Migration Cluster" like   'Cluster%' or
           "MODERNEX Migration Cluster" = 'Pilot')
    --and  "OracleDB"   = 'hsplandq_lin8532567'
    ;

  -- Variablen für Statistik und Verarbeitung
  v_total_count       NUMBER := 0;
  v_inserted          NUMBER := 0;
  v_updated           NUMBER := 0;
  v_not_found         NUMBER := 0;
  v_vn_not_found      NUMBER := 0;
  v_too_many          NUMBER := 0;
  v_other_errors      NUMBER := 0;
  v_other_errors_pdb  NUMBER := 0;
  v_info_saved        NUMBER := 0;
  v_info_saved_nfs    NUMBER := 0;
  v_unique_violation  NUMBER := 0;
  v_changed_total     NUMBER := 0;
  v_shared            VARCHAR2(120) := NULL;
  v_TARGET_TNS_ALIAS  VARCHAR2(60)  := NULL;
  v_TARGET_NAME       VARCHAR2(60)  := NULL;
  v_CDB_NAME          VARCHAR2(60)  := NULL;
  v_PDB_NAME          VARCHAR2(60)  := NULL;
  v_CLUSTER_NAME      VARCHAR2(60)  := NULL;
  v_tdbn              VARCHAR2(60)  := NULL;
  v_vnet              VARCHAR2(20)  := NULL;
  v_env               VARCHAR2(20)  := NULL;
  v_test_tns_alias    VARCHAR2(60)  := NULL;
  v_tdba              VARCHAR2(60)  := NULL;
  v_replacedby_cloud  VARCHAR2(60)  := NULL;
  v_instr             VARCHAR2(60)  := NULL;
  v_sav               MIG_DATABASE_MIGRATION_PARAMS_v2%rowtype;

BEGIN
  ----------------------------------------------------------------
  -- Hauptverarbeitung
  ----------------------------------------------------------------

-- zustand sichern
      delete from mig_cmdb_refresh;
  insert into mig_cmdb_refresh values (sysdate);

  delete from MIG_DATABASE_MIGRATION_PARAMS_v2_sav;
  insert into MIG_DATABASE_MIGRATION_PARAMS_v2_sav (
  select * from MIG_DATABASE_MIGRATION_PARAMS_v2);

  delete from MIG_DATABASE_MIGRATION_PARAMS_v2;
 commit;

 LOCK TABLE MIG_DATABASE_MIGRATION_PARAMS_v2 IN EXCLUSIVE MODE;

  FOR c_mwinfo IN mwinfo LOOP
    v_total_count := v_total_count + 1;
    v_shared := NULL;
    v_TARGET_TNS_ALIAS := NULL;
    v_TARGET_NAME := NULL;
    v_CDB_NAME := NULL;
    v_PDB_NAME := NULL;
    v_CLUSTER_NAME := NULL;
    v_vnet := NULL;
    v_env := NULL;
    v_test_tns_alias := NULL;

    BEGIN
      SELECT vn_premig_name, VN_TEST_DB_NAME, VN_TEST_tns_alias
        INTO v_vnet, v_tdbn, v_tdba
        FROM mig_infran_deployed_vnets
       WHERE vn_env = c_mwinfo.mod_env
         AND VN_PLATFORM = c_mwinfo.mod_target_platform
         AND VN_DATA_CLASIFICTION = c_mwinfo.mod_dataclass;
    EXCEPTION
      WHEN OTHERS THEN
        v_vn_not_found := v_vn_not_found + 1;
        v_vnet := '*NOF*';
        v_tdbn := '*NOF*';
        v_tdba := '*NOF*';
        v_shared := NULL;
    END;

    -- check if replaceed by is a cloud db
   v_replacedby_cloud := c_mwinfo.replaced_by;
   v_instr := 'ADB';
   if c_mwinfo.mod_target_platform = 'ExaDB' then
      v_instr := 'vmclu';
   end if;

   if c_mwinfo.replaced_by is not null then
      if instr (c_mwinfo.replaced_by, v_instr) = 0 then
           v_replacedby_cloud := NULL;
      end if;
   end if;

   if v_replacedby_cloud is NULL
   then
        v_TARGET_NAME := v_tdbn;

     if c_mwinfo.mod_target_platform = 'ExaDB' then
           v_CDB_NAME := substr (v_TARGET_NAME, 1, instr(v_TARGET_NAME, '_')-1);
           v_pdb_name := substr (v_TARGET_NAME, instr(v_TARGET_NAME, '_')+1, 55);
           v_cluster_name :=  CASE
                                WHEN v_cdb_name = 'EXADVN1' then 'vmclu1-fra-az1-test-vn1'
                                WHEN v_cdb_name = 'EXADVN2' then 'vmclu1-fra-az2-test-conf-vn2'
                                WHEN v_cdb_name = 'EXADVN3' then 'vmclu1-fra-az1-prod-vn3'
                                WHEN v_cdb_name = 'EXADVN4' then 'vmclu2-fra-az1-prod-conf-vn4'
                                WHEN v_cdb_name = 'EXADVN5' then 'vmclu1-fra-az2-prod-dr-vn5'
                                WHEN v_cdb_name = 'EXADVN6' then 'vmclu2-fra-az2-prod-dr-conf-vn6'
                            end;
     end if;

   else
      v_TARGET_NAME := c_mwinfo.replaced_by;
     if c_mwinfo.mod_target_platform = 'ExaDB' then

        BEGIN
             SELECT  ov.mw_real_sid into v_pdb_name
             FROM masterdata.oracle_overview ov
             where  ov.parent_db_name = c_mwinfo.replaced_by;

           v_CDB_NAME := substr (v_TARGET_NAME, 1, instr(v_TARGET_NAME, '_')-1);
           v_CLUSTER_NAME := substr (v_TARGET_NAME, instr(v_TARGET_NAME, '_')+1, 55);

        EXCEPTION
          WHEN OTHERS THEN
           v_CDB_NAME := substr (v_TARGET_NAME, 1, instr(v_TARGET_NAME, '_')-1);
           v_cluster_name := substr (v_TARGET_NAME, instr(v_TARGET_NAME, '_')+1, 55);
           v_PDB_NAME := 'PDB'||v_cdb_name;

           DBMS_OUTPUT.put_line('[PDB_ERROR] ' || SQLERRM || ' ' || c_mwinfo.srcname||' tgt '||v_CDB_NAME||'_'||v_PDB_NAME);
             v_other_errors_pdb := v_other_errors_pdb + 1;
         END;

        v_TARGET_NAME := v_CDB_NAME||'_'||v_PDB_NAME;

      end if ;
   end if;
    v_TARGET_TNS_ALIAS := CASE
                            WHEN c_mwinfo.mod_target_platform = 'ADB-S' THEN v_TARGET_NAME || '_tp'
                            ELSE v_TARGET_NAME || '_system'
                          END;

    BEGIN
      INSERT INTO MIG_DATABASE_MIGRATION_PARAMS_v2  (
          DBMP_PRIMKEY, DBMP_ORACLE_DB, DBMP_TARGET_NAME, DBMP_TARGET_PLATFORM,
          DPMP_TARGET_MIGR_METHODE, DBMP_TEST_TNS_ALIAS, DBMP_DESC, DBMP_MIG_CLUSTER,
          DBMP_ENV, DBMP_DATACLASS, DBMP_VNET, DBMP_APP_NAME, DBMP_ENV_ORIG,
          DBMP_SHARED, DBMP_TARGET_TNS_ALIAS, DBMP_TARGET_PERSID, DBMP_SOURCE_PERSID,
          dbmp_target_env, dbmp_nfs_ip, dbmp_nfs_name, dbmp_nfs_share, dbmp_nfs_mp,
          DBMP_EXA_CLUSTERNAME, DBMP_EXA_CDB_NAME, DBMP_EXA_PDB_NAME)
      VALUES (
          s1.NEXTVAL, c_mwinfo.srcname, v_TARGET_NAME, c_mwinfo.mod_target_platform,
          c_mwinfo.mod_target_migr_methode, v_tdba, NULL, c_mwinfo.mod_mig_cluster,
          c_mwinfo.mod_env, c_mwinfo.mod_dataclass, v_vnet, c_mwinfo.mod_app_name,
          c_mwinfo.mod_env_orig, v_sav.DBMP_SHARED, v_TARGET_TNS_ALIAS, NULL, NULL,
          v_sav.dbmp_target_env, v_sav.dbmp_nfs_ip, v_sav.dbmp_nfs_name, v_sav.dbmp_nfs_share, v_sav.dbmp_nfs_mp,
          v_CLUSTER_NAME,v_cdb_NAME,v_pdb_NAME);

    EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN
        v_unique_violation := v_unique_violation + 1;
        DBMS_OUTPUT.put_line('[UNIQUE_VIOLATION] ' || c_mwinfo.srcname || ' / ' || c_mwinfo.mod_app_name || ' / ' || c_mwinfo.mod_env);
      WHEN OTHERS THEN
        v_other_errors := v_other_errors + 1;
        DBMS_OUTPUT.put_line('[INSERT_ERROR] ' || SQLERRM || ' ' || c_mwinfo.srcname);
    END;
  END LOOP;

UPDATE MIG_DATABASE_MIGRATION_PARAMS_v2 dst
   SET (dst.DBMP_SHARED,
        dst.DBMP_NFS_IP,
        dst.DBMP_NFS_NAME,
        dst.DBMP_NFS_SHARE,
        dst.DBMP_NFS_MP) =
       (SELECT sav.DBMP_SHARED,
               sav.DBMP_NFS_IP,
               sav.DBMP_NFS_NAME,
               sav.DBMP_NFS_SHARE,
               sav.DBMP_NFS_MP
          FROM MIG_DATABASE_MIGRATION_PARAMS_v2_sav sav
         WHERE LOWER(TRIM(sav.DBMP_ORACLE_DB)) = LOWER(TRIM(dst.DBMP_ORACLE_DB))
           AND LOWER(TRIM(sav.DBMP_APP_NAME))  = LOWER(TRIM(dst.DBMP_APP_NAME))
           AND LOWER(TRIM(sav.DBMP_ENV))       = LOWER(TRIM(dst.DBMP_ENV)))
 WHERE EXISTS (
       SELECT 1
         FROM MIG_DATABASE_MIGRATION_PARAMS_v2_sav sav
        WHERE LOWER(TRIM(sav.DBMP_ORACLE_DB)) = LOWER(TRIM(dst.DBMP_ORACLE_DB))
          AND LOWER(TRIM(sav.DBMP_APP_NAME))  = LOWER(TRIM(dst.DBMP_APP_NAME))
          AND LOWER(TRIM(sav.DBMP_ENV))       = LOWER(TRIM(dst.DBMP_ENV))
);

  COMMIT;

  -- Zusammenfassung
  DBMS_OUTPUT.put_line('--- Summary ---');
  DBMS_OUTPUT.put_line('Total processed         : ' || v_total_count);
  DBMS_OUTPUT.put_line('Inserted records        : ' || v_inserted);
  DBMS_OUTPUT.put_line('Updated records         : ' || v_updated);
  DBMS_OUTPUT.put_line('Infos saved             : ' || v_info_saved);
  DBMS_OUTPUT.put_line('Infos saved_nfs         : ' || v_info_saved_nfs);
  DBMS_OUTPUT.put_line('Changed (ins + upd)     : ' || v_changed_total);
  DBMS_OUTPUT.put_line('Not found (? insert)    : ' || v_not_found);
  DBMS_OUTPUT.put_line('Not found (? vnet)      : ' || v_vn_not_found);
  DBMS_OUTPUT.put_line('Too many rows           : ' || v_too_many);
  DBMS_OUTPUT.put_line('Unique constraint errs  : ' || v_unique_violation);
  DBMS_OUTPUT.put_line('Other errors            : ' || v_other_errors);
  DBMS_OUTPUT.put_line('Other errors PDB         : ' || v_other_errors_pdb);
  DBMS_OUTPUT.put_line('-------------------------');

END P_UPDATE_MIGINFOS;

/
