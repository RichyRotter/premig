/*
 * File: func.sql
 * Purpose: Standardized spacing only (tabs→spaces, normalized EOLs, trimmed trailing whitespace, collapsed blank lines).
 * Note: NO code changes, only whitespace.
 * Generated: 2025-09-29 10:54:49 -0300
 * Author: ChatGPT (assistant)
 */

--------------------------------------------------------
--  Datei erstellt -Montag-September-29-2025
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Function F_ADJUST_CONFIG
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_ADJUST_CONFIG"
(
  TARGET_PLATFORM IN VARCHAR2
, P_role IN VARCHAR2
, P_HA_ID IN VARCHAR2
, P_CPU_target IN NUMBER
, P_CPU_instance IN OUT NUMBER
, P_SGA IN OUT NUMBER
, P_PGA IN OUT NUMBER
, P_USED_GB IN OUT NUMBER
, P_AlLOC_GB IN OUT NUMBER
, P_WRITE_IOPS IN OUT NUMBER
, P_READ_IOPS IN OUT NUMBER
, P_DESC IN OUT VARCHAR2
) RETURN NUMBER AS
BEGIN
  RETURN NULL;
END F_ADJUST_CONFIG;

/
--------------------------------------------------------
--  DDL for Function F_APPLY_ADB_RULES
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_APPLY_ADB_RULES"
(
  P_ADB IN OUT mig_infran_adb_instance%ROWTYPE
, P_ADB_RULES IN mig_infran_param_technical_limits%ROWTYPE
, p_CPU_ADJUSTMENT IN OUT number
, p_storage_adjustment in out number
) RETURN NUMBER AS

  v_val1 number;
  v_mem_mult number;

BEGIN

   p_CPU_ADJUSTMENT := 0;
   p_storage_ADJUSTMENT := 0;

  -- check mem cpu ratio
  if ((nvl(p_adb.pga_gb,0) + p_adb.sga_gb) / p_adb.anz_ecpus) > P_ADB_RULES.gb_mem_per_ECPU
     and f_is_rule_active(20) =  1
  then
     -- need to raise cpu
     p_adb.description := p_adb.description||' !! Memory Rule mem='||to_char(nvl(round(p_adb.pga_gb,2) + p_adb.sga_gb,3));
     p_adb.description := p_adb.description||' ecpu from='||to_char(p_adb.anz_ecpus)||' to ';
     p_adb.anz_ecpus   := round((nvl(p_adb.pga_gb,0) + p_adb.sga_gb)/ P_ADB_RULES.gb_mem_per_ECPU, 2);
     p_adb.description := p_adb.description||to_char(p_adb.anz_ecpus);
     p_CPU_ADJUSTMENT := 1;
  end if;

  -- check session cpu ratio
  if (p_adb.max_sessions / p_adb.anz_ecpus) > P_ADB_RULES.sessions_per_ECPU
     and f_is_rule_active(21) =  1
  then
     -- need to raise cpu
     p_adb.description := p_adb.description||' !! Session Rule #session='||to_char(p_adb.max_sessions);
     p_adb.description := p_adb.description||' ecpu from='||to_char(p_adb.anz_ecpus)||' to ';
     p_adb.anz_ecpus   := round(p_adb.max_sessions / P_ADB_RULES.sessions_per_ECPU,2);
     p_adb.description := p_adb.description||to_char(p_adb.anz_ecpus);
     p_CPU_ADJUSTMENT := 1;
  end if;

   -- check min cores
  if  p_adb.anz_ecpus < P_ADB_RULES.min_ECPU
       and f_is_rule_active(22) =  1
  then
     -- need to raise cpu
     p_adb.description := p_adb.description||' !! min ecpu #ecpu='||to_char(p_adb.anz_ecpus);
     p_adb.description := p_adb.description||' ecpu from='||to_char(p_adb.anz_ecpus)||' to ';
     p_adb.anz_ecpus   := P_ADB_RULES.min_ecpu;
     p_adb.description := p_adb.description||to_char(p_adb.anz_ecpus);
     p_CPU_ADJUSTMENT := 1;
  end if;

  -- check read iops : GB ratio
  if (p_adb.avg_read_iops / p_adb.alloc_GB) > P_ADB_RULES.read_iops_per_gb
       and f_is_rule_active(23) =  1
  then
     -- need< to raise GB
     dbms_output.put_line ('read-rule');
     p_adb.description := p_adb.description||' !! read iops Rule #read iops='||to_char(p_adb.avg_read_iops);
     p_adb.description := p_adb.description||' alloc GB from='||to_char(p_adb.alloc_gb)||' to ';
     p_adb.alloc_gb    := round(p_adb.avg_read_iops / P_ADB_RULES.read_iops_per_GB, 3);
     p_adb.description := p_adb.description||to_char(p_adb.alloc_gb);
     p_storage_ADJUSTMENT := 1;
  end if;

  -- check write iops : GB ratio
  if (p_adb.avg_wr_iops / p_adb.alloc_GB) > P_ADB_RULES.write_iops_per_gb
       and f_is_rule_active(24) =  1
  then
     -- need< to raise GB
     p_adb.description := p_adb.description||' !! wr iops Rule #wr iops='||to_char(p_adb.avg_wr_iops);
     p_adb.description := p_adb.description||' alloc GB from='||to_char(p_adb.alloc_gb)||' to ';
     p_adb.alloc_gb    := round(p_adb.avg_wr_iops / P_ADB_RULES.write_iops_per_GB, 3);
     p_adb.description := p_adb.description||to_char(p_adb.alloc_gb);
     p_storage_ADJUSTMENT := 1;
  end if;

-- check min storage
  if  p_adb.alloc_gb < P_ADB_RULES.min_STORAGE_gb
       and f_is_rule_active(25) =  1
 then
     -- need to raise gb
     p_adb.description := p_adb.description||' !! min storage #alloc.GB='||to_char(p_adb.alloc_gb);
     p_adb.description := p_adb.description||' gb from='||to_char(p_adb.alloc_gb)||' to ';
     p_adb.alloc_gb   := P_ADB_RULES.min_storage_gb;
     p_adb.description := p_adb.description||to_char(p_adb.alloc_gb);
     p_storage_ADJUSTMENT := 1;
  end if;

  --p_adb.description := p_adb.description||' **roundup cpu '||to_char(p_adb.anz_ecpus);
  select round(p_adb.anz_ecpus,3) into p_adb.anz_ecpus from dual ;
  --p_adb.description := p_adb.description||' to '||to_char(p_adb.anz_ecpus);

  -- check again  cpu to mem ratio
  if (p_adb.anz_ecpus * P_ADB_RULES.gb_mem_per_ECPU) > (nvl(p_adb.pga_gb,0) + p_adb.sga_gb)
     and f_is_rule_active(26) =  1
  then
     -- need to raise mem -- calc faktor
     v_mem_mult := (p_adb.anz_ecpus * P_ADB_RULES.gb_mem_per_ECPU) / (nvl(p_adb.pga_gb,0) + p_adb.sga_gb);
     p_adb.description := p_adb.description||' !! final Memory adjustment from='||to_char(nvl(p_adb.pga_gb,0) + p_adb.sga_gb);
     p_adb.description := p_adb.description||' to ';
     p_adb.pga_gb   := nvl(p_adb.pga_gb,0) * v_mem_mult;
     p_adb.sga_gb   := nvl(p_adb.sga_gb,0) * v_mem_mult;
     p_adb. description := p_adb.description||to_char(round(nvl(p_adb.pga_gb,0) + p_adb.sga_gb,3))||' by multiply with '||to_char(round(v_mem_mult,3));

  end if;

     --dbms_output.put_line('in rules for '||p_adb.instance_name||' '||to_char(p_adb.anz_ecpus));

  return 0;
-- roundup

END F_APPLY_ADB_RULES;

/
--------------------------------------------------------
--  DDL for Function F_CALCULATE_CLUSTER_SIZES
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_CALCULATE_CLUSTER_SIZES" RETURN NUMBER AS

    v_step_marker                 NUMBER := 0;
    v_cl_id                       NUMBER := 0;
    v_cl_proc                     NUMBER := 0;
    v_created_clusters            NUMBER := 0;
    v_cpu_in_use                  NUMBER := 0;
    v_memgb_in_use                NUMBER := 0;
    v_storage_in_use              NUMBER := 0;
    v_nr_cdbs                     NUMBER := 0;
    v_core_per_cl                 NUMBER := 0;
    v_mem_per_cl                     NUMBER := 0;

    CURSOR c_clusters IS
      SELECT
          azure_dc,
          target_platform,
          cluster_name,
          environments,
          service_category,
          data_classification
     FROM
       mig_infran_param_clusters
     WHERE target_platform = 'EXAD';

BEGIN
    p_log('mig', 'Start Calculate Clusters');
    COMMIT;

    -- Clear previous data
    DELETE FROM mig_infran_exa_cluster_vm;
    DELETE FROM mig_infran_exa_cluster;
    COMMIT;

     SELECT
        nvl(cores_per_cluster,0),    nvl(mem_per_cluster,0)
        into v_core_per_cl, v_mem_per_cl
    FROM
    mig_infran_param_technical_limits
    where target_config = 'EXAD';

    v_step_marker := 3;

    FOR xcl IN c_clusters LOOP
        v_cl_id := s1.NEXTVAL;

        -- Update the mig_infran_cdb table
        UPDATE mig_infran_cdb
        SET exa_cl_id = v_cl_id,
            azure_dc = xcl.azure_dc,
            description = description || '/ Clu-assign=' || TO_CHAR(v_cl_id)
        WHERE f_check_in_list(mig_infran_cdb.service_category, xcl.service_category) = 1
          AND f_check_in_list(mig_infran_cdb.environment, xcl.environments) = 1
          and F_CHECK_DATA_CLASSIFICATION(mig_infran_cdb.data_classification, xcl.data_classification) = 1
         -- and mig_infran_cdb.azure_dc = xcl.azure_dc
        ;

        v_nr_cdbs := SQL%ROWCOUNT;
    /*
        SELECT
            COALESCE(SUM(b.pga_gb + b.sga_GB), 0),
            COALESCE(SUM(b.anz_ocpus), 0),
            COALESCE(SUM(a.alloc_gb), 0)
        INTO v_memgb_in_use, v_cpu_in_use, v_storage_in_use
        FROM mig_infran_cdb_instance b
        JOIN mig_infran_cdb a ON b.cdb_id = a.cdb_id
         WHERE f_check_in_list(a.service_category, xcl.service_category) = 1
          AND f_check_in_list(a.environment, xcl.environments) = 1
          and F_CHECK_DATA_CLASSIFICATION(a.data_classification, xcl.data_classification) = 1
          and a.azure_dc = xcl.azure_dc;
      */

        -- Insert into mig_infran_exa_cluster
        INSERT INTO mig_infran_exa_cluster
            (exa_cl_id, exa_rackid, exa_cl_name,
             exa_environments, exa_service_category, exa_cl_location,
             sum_cores, sum_mem, sum_alloc_storage, anz_cdbs, data_classification)
        VALUES (v_cl_id, NULL, xcl.cluster_name,
                xcl.environments, xcl.service_category, xcl.azure_dc,
                v_cpu_in_use, v_memgb_in_use, v_storage_in_use, v_nr_cdbs, xcl.data_classification);

        -- Log cluster statistics
        p_log('mig', '# Cluster Statistics:');
        p_log('mig', '# Cluster Name: ' || xcl.cluster_name);
        p_log('mig', '# number cdbs : ' || TO_CHAR(round(v_nr_cdbs,3  )));
       -- p_log('mig', '# number ocpus: ' || TO_CHAR(round(v_cpu_in_use,3)));
      --  p_log('mig', '# number memGB: ' || TO_CHAR(round(v_memgb_in_use,3)));
      --  p_log('mig', '# Allocated TB: ' || TO_CHAR(round(v_storage_in_use / 1024,3)));

        v_cl_proc := v_cl_proc + 1;
    END LOOP;

update mig_infran_exa_cluster
set ( sum_cores, sum_mem, sum_alloc_storage, anz_cdbs) =
(SELECT
    v_core_per_cl + sum(a.anz_ocpus), v_mem_per_cl+ sum(sga_gb + pga_gb), sum(alloc_gb), count(*)
FROM  mig_infran_cdb a
where mig_infran_exa_cluster.exa_cl_id = a.exa_cl_id)
;

    p_log('mig', '# Cluster processed: ' || TO_CHAR(v_cl_proc));
    p_log('mig', 'End Calculate Clusters');
    COMMIT;

    RETURN 0;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_log('mig', 'Provisioning CDB EXAD Database: An error occurred: ' ||
            TO_CHAR(v_step_marker) || ' ' || SQLERRM);
        COMMIT;
        RETURN 1;
END F_CALCULATE_CLUSTER_SIZES;

/
--------------------------------------------------------
--  DDL for Function F_CHECK_DATA_CLASSIFICATION
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_CHECK_DATA_CLASSIFICATION"
(
  P_DB_CLASS IN VARCHAR2
, P_CLUSTER_CLASS IN VARCHAR2
) RETURN NUMBER AS

  v_db number := 0;
  v_cl number := 0;
  v_ret number := 0;

BEGIN

  select instr(p_db_class, 'Confidential') into v_db
  from dual;

  select instr(p_cluster_class, 'Confidential') into v_cl
  from dual;

  v_ret := 1;
  if v_db + v_cl = 1
  then
    v_ret := 0;
  end if;

  RETURN v_ret;
END F_CHECK_DATA_CLASSIFICATION;

/
--------------------------------------------------------
--  DDL for Function F_CHECK_IN_LIST
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_CHECK_IN_LIST" (par1 IN VARCHAR2, par2 IN VARCHAR2)
RETURN NUMBER
IS
BEGIN
    -- Check if par1 is in par2
    IF ',' || par2 || ',' LIKE '%,' || par1 || ',%' THEN
        RETURN 1;  -- par1 is in par2
    ELSE
        RETURN 0;  -- par1 is not in par2
    END IF;
END;

/
--------------------------------------------------------
--  DDL for Function F_CHECK_MINVAL
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_CHECK_MINVAL"
(
  P_NUMBER IN NUMBER
, P_MINIMUM IN NUMBER
) RETURN NUMBER AS
BEGIN
  IF P_NUMBER < p_minimum then
    return p_minimum;
  else
    return p_number;
  end if;
END F_CHECK_MINVAL;

/
--------------------------------------------------------
--  DDL for Function F_CREATE_ADB_INST
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_CREATE_ADB_INST"
(
    p_adb in mig_infran_adb_instance%ROWTYPE,
    p_adb_limits in mig_infran_param_technical_limits%ROWTYPE,
    p_role in varchar2,
    p_anz_inst_created in out number

) RETURN NUMBER AS

    v_az_dc1                      mig_infran_param_azure_location.azure_dc%TYPE;
    v_az_dc2                      mig_infran_param_azure_location.azure_dc%TYPE;

    v_ha  mig_infran_ha_concepts%ROWTYPE;
    v_adb mig_infran_adb_instance%ROWTYPE;
    v_mem number;
    v_id  number;
    v_anz_inst number := 1;
    v_anz_inst_created number := 0;
    v_rac_core_adj number;
    v_loop number := 0;
begin

   select azure_dc into v_az_dc1
   from mig_infran_param_azure_location
   where target_platform = 'ATPS'
   and dc_nr = 1;

   select azure_dc into v_az_dc2
   from mig_infran_param_azure_location
   where target_platform = 'ATPS'
   and dc_nr = 2;

    v_adb := p_adb;
    p_anz_inst_created := 0;

    if p_role = 'stdby' then

       SELECT * into v_ha
       FROM mig_infran_ha_concepts
       where con_id = p_adb.ha_id;

       -- create stdby out of primary and update primary
       v_adb.anz_ecpus := p_adb.anz_ecpus * v_ha.adj_cores;
       if v_adb.anz_ecpus < p_adb_limits.min_ecpu then
           v_adb.anz_ecpus := p_adb_limits.min_ecpu;
       end if;

       v_mem :=  v_adb.anz_ecpus * p_adb_limits.gb_mem_per_ecpu;
       v_adb.sga_gb := v_mem * 0.8;
       v_adb.pga_gb := v_mem * 0.2;

       v_id := s1.nextval;

       v_adb.instance_id  := v_id;
       v_adb.inst_nr      := p_adb.inst_nr;
       v_adb.dg_type      := 'StandBy';
       v_adb.dg_remote_id := p_adb.instance_id;
       v_adb.dg_remote_nr := p_adb.inst_nr;
       v_adb.instance_name := 'STBY_'||p_adb.instance_name;

       if v_adb.azure_dc  = v_az_dc1 then
            v_adb.azure_dc := v_az_dc2;
       else
            v_adb.azure_dc := v_az_dc1;
       end if;

       -- update primary
       update mig_infran_adb_instance
              set dg_type = 'Primary',
                  dg_remote_id = v_id,
                  dg_remote_nr = v_adb.dg_remote_nr
       where instance_id = p_adb.instance_id and
             inst_nr     = p_adb.inst_nr;

    end if;

    v_anz_inst := 1;
    if v_adb.anz_ecpus > p_adb_limits.adb_core_per_instance then
       v_adb.split_instance := 'Y';

       -- select RAC limits
       select adj_cores into v_rac_core_adj
       from mig_infran_ha_concepts
       where con_id = 'RAC';

       v_adb.anz_ecpus := ROUND(v_adb.anz_ecpus * v_rac_core_adj,3);
       v_anz_inst := ROUND(v_adb.anz_ecpus/p_adb_limits.adb_core_per_instance,3);
       v_adb.anz_ecpus := ROUND(v_adb.anz_ecpus / v_anz_inst,3);
       v_adb.description := v_adb.description||' !! RAC Split !!';

    end if;

    for v_loop in 1..v_anz_inst loop

    p_anz_inst_created := p_anz_inst_created + 1;
    v_adb.inst_nr := v_loop;

    --dbms_output.put_line (v_adb.instance_name||' !!!SGA='||to_char(v_adb.sga_gb));

    insert into mig_infran_adb_instance
    values v_adb;

    end loop;
    RETURN 0;
exception
      when others then
             p_log('mig', 'Provisioning ADB instances: An error occurred: '  || SQLERRM);
             COMMIT;
             return 1;

END F_CREATE_ADB_INST;

/
--------------------------------------------------------
--  DDL for Function F_DB_METRICS
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_DB_METRICS" (
/*
v1.0 sept24
-reads and returns db metric from em local table
*/
    p_target_guid IN VARCHAR2,
    p_metric      IN VARCHAR2,
    p_metric_min  OUT NUMBER,
    p_metric_avg  OUT NUMBER,
    p_metric_max  OUT NUMBER,
    p_cat_value   out NUMBER,
    p_metric_cat  out varchar2

) RETURN NUMBER AS
BEGIN
    SELECT minimum, average, maximum, average, cat
    into p_metric_min, p_metric_avg, p_metric_max,p_cat_value,p_metric_cat
    FROM  mig_calc_metrics_ranges_db
    where metric_column = p_metric
    and target_guid = p_target_guid;

if p_metric_cat = 'HIGH' then
  p_cat_value := p_metric_max;
end if;

    --if p_target_guid = '13646A68A0EF1C67E0636B205D0AA4DB' then
    --  dbms_output.put_line(p_metric||': funct min='||to_char(p_metric_min)||'avg='||to_char(p_metric_avg)||'max='||to_char(p_metric_max));
    --end if;

    return 0;
exception
  WHEN OTHERS THEN
     -- try long route
     begin
        SELECT min(minimum) xmin, max(maximum) xmax, avg(average) xavg, avg(average) xcatv, '???' xct
           into p_metric_min, p_metric_max, p_metric_avg, p_cat_value, p_metric_cat
        FROM  mig_em_metric_db_hrs
        where metric_column = p_metric
        and   target_guid = p_target_guid;
        return 1;
    exception
      when others then
              p_metric_min := null;
              p_metric_avg := null;
              p_metric_max := null;
              return 2;
    end;
END f_db_metrics;

/
--------------------------------------------------------
--  DDL for Function F_EM_LOAD_CPU_DAILY_DATA
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_EM_LOAD_CPU_DAILY_DATA" RETURN NUMBER AS
/*
v1.0 sept24
-loads db metric from em repo into local table
*/

   v_rows number;
BEGIN
    p_log('mig', 'mig_em_db_cpu_daily');

    execute IMMEDIATE ('truncate table mig_em_db_cpu_daily');
      commit;

      begin
        insert into mig_em_db_cpu_daily
        value (
         SELECT "LifeCycle_Status", "RAC_Database", "Instance",
                "Day", "Total_Max_CPU", "Total_Percentile_99", "Total_Percentile_90"
         FROM v_em_P_db_cpu_daily);
         commit;
        insert into mig_em_db_cpu_daily
        value (
         SELECT "LifeCycle_Status", "RAC_Database", "Instance",
                "Day", "Total_Max_CPU", "Total_Percentile_99", "Total_Percentile_90"
         FROM v_em_q_db_cpu_daily);
         commit;

         select count(*) into v_rows from mig_em_db_cpu_daily;
         p_log('mig', 'mig_em_db_cpu_daily '||to_char(v_rows,'999,999,990'));
         return 0;

     exception
        when others then
           rollback;
           p_log ('mig','faild: ' || SQLERRM);
           commit;
           return sqlerrm;
      end;

END F_EM_LOAD_CPU_DAILY_DATA;

/
--------------------------------------------------------
--  DDL for Function F_EM_LOAD_DB_METRIC
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_EM_LOAD_DB_METRIC" RETURN VARCHAR2 AS
/*
v1.0 sept24
-loads db metric from em repo into local table
*/

      v_rows number;
BEGIN

      p_log('mig', 'load db data ');

     execute IMMEDIATE ('truncate table mig_em_metric_db_hrs');
      commit;

      begin
        insert into mig_em_metric_db_hrs
        value (
         SELECT target_guid, target_name, target_type, metric_label,
                column_label, metric_name, metric_column, rollup_timestamp_utc,
                minimum, maximum, average, standard_deviation, sample_count,
                to_timestamp(rollup_timestamp_utc, 'YYYY-MM-DD HH24:MI:SS')
         FROM
         v_em_p_metric_db_hrs);
         commit;

        insert into mig_em_metric_db_hrs
        value (
         SELECT target_guid, target_name, target_type, metric_label,
                column_label, metric_name, metric_column, rollup_timestamp_utc,
                minimum, maximum, average, standard_deviation, sample_count,
                to_timestamp(rollup_timestamp_utc, 'YYYY-MM-DD HH24:MI:SS')
         FROM
         v_em_q_metric_db_hrs);
         commit;

         select count(*) into v_rows from mig_em_metric_db_hrs;
         p_log('mig', 'load db data hrs - rows '||to_char(v_rows,'999,999,990'));

      exception
        when others then
           rollback;
           p_log ('mig','faild: ' || SQLERRM);
           return SQLERRM;
           commit;
      end;

      p_log('mig', 'load db data daily');

      delete from mig_em_metric_db_daily;
      commit;

      begin
        insert into mig_em_metric_db_daily
        value (
         SELECT target_guid, target_name, target_type, metric_label,
                column_label, metric_name, metric_column, rollup_timestamp_utc,
                minimum, maximum, average, standard_deviation, sample_count
         FROM
         v_em_p_metric_db_daily);

        insert into mig_em_metric_db_daily
        value (
         SELECT target_guid, target_name, target_type, metric_label,
                column_label, metric_name, metric_column, rollup_timestamp_utc,
                minimum, maximum, average, standard_deviation, sample_count
         FROM
         v_em_q_metric_db_daily);

         select count(*) into v_rows from mig_em_metric_db_daily;
         p_log('mig', 'load db data daily - rows '||to_char(v_rows,'999,999,990'));

         RETURN 0;

     exception
        when others then
           rollback;
           p_log ('mig','faild: ' || SQLERRM);
           return SQLERRM;
           commit;
      end;

END F_EM_LOAD_DB_METRIC;

/
--------------------------------------------------------
--  DDL for Function F_EM_LOAD_DB_SIZE
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_EM_LOAD_DB_SIZE" RETURN NUMBER AS
/*
v1.0 sept24
-loads db metric from em repo into local table
*/

   v_rows number;

BEGIN
       p_log('mig', 'load  mig_em_db_size');

      delete from mig_em_db_size;
      commit;

      begin
        insert into mig_em_db_size
        value (
         SELECT target_guid, database, month_date, used_size_gb,
         allocated_size_gb
        FROM v_em_p_db_size);

         insert into mig_em_db_size
        value (
         SELECT target_guid, database, month_date, used_size_gb,
         allocated_size_gb
        FROM v_em_q_db_size);
         select count(*) into v_rows from mig_em_db_size;
         p_log('mig', 'load  mig_em_db_size - rows '||to_char(v_rows,'999,999,990'));
        commit;
        return 0;
      exception
        when others then
           rollback;
           p_log ('mig','faild: ' || SQLERRM);
           commit;
           return sqlerrm;
      end;

END F_EM_LOAD_DB_SIZE;

/
--------------------------------------------------------
--  DDL for Function F_EM_LOAD_DB_STRUCTURE_DATA
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_EM_LOAD_DB_STRUCTURE_DATA" RETURN NUMBER AS
      v_rows number;
BEGIN
       p_log('mig', 'mig_em_sizing_structure_db');

      delete from mig_em_sizing_structure_db;
      commit;

      begin
        insert into mig_em_sizing_structure_db
        value (
         SELECT extract_version, dbmachine, dbmachine_type_version, dbmachine_type, dbmachine_owner,
                cluster_name, cluster_owner, cluster_status, cluster_last_load_time_utc, clustered,
                cdb, cdb_type_version, cdb_type, cdb_owner, cdb_stand_by_type, cdb_status,
                cdb_last_load_time_utc, db, db_type_version, db_type, db_owner, db_stand_by_type,
                db_status, db_last_load_time_utc, host, host_type_version, host_status, host_last_load_time_utc,
                physical_cpu_count, total_cpu_cores, logical_cpu_count, mem_gb, freq, ma, system_config,
                vendor_name, dist_version, dup_rac_cluster_flag, dup_host_dbmachine_flag, dbmachine_target_guid,
                cluster_target_guid, cdb_target_guid, db_target_guid, host_target_guid, cdb_num, cdb_inst_rn,
                cdb_instance_count, db_num, host_num, host_inst_rn, host_instance_count, dup_host_cluster_flag,
                extract_dttm_utc
        FROM v_em_sizing_structure_db);
        commit;
         select count(*) into v_rows from mig_em_sizing_structure_db;
         p_log('mig', 'load F_EM_LOAD_DB_STRUCTURE_DATA - rows '||to_char(v_rows,'999,999,990'));
         return 0;

     exception
        when others then
           rollback;
           p_log ('mig','faild: ' || SQLERRM);
           commit;
           return SQLERRM;
      end;

END F_EM_LOAD_DB_STRUCTURE_DATA;

/
--------------------------------------------------------
--  DDL for Function F_EM_LOAD_HOST_METRIC
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_EM_LOAD_HOST_METRIC" RETURN NUMBER AS
      v_rows number;
BEGIN
       -- LOAD HOST DATA
      p_log('mig', '01 load host data ');

      execute IMMEDIATE ('truncate table mig_em_metric_host_hrs');
      commit;

      begin
         insert into mig_em_metric_host_hrs
         value (
              select target_guid, target_name, target_type,
                 metric_label, column_label, metric_name,
                 metric_column, rollup_timestamp_utc, minimum,
                 maximum, average, standard_deviation, sample_count,
                 to_timestamp(rollup_timestamp_utc, 'YYYY-MM-DD HH24:MI:SS')
              FROM v_em_p_metric_host_hrs)
              ;
          insert into mig_em_metric_host_hrs
         value (
              select target_guid, target_name, target_type,
                 metric_label, column_label, metric_name,
                 metric_column, rollup_timestamp_utc, minimum,
                 maximum, average, standard_deviation, sample_count,
                 to_timestamp(rollup_timestamp_utc, 'YYYY-MM-DD HH24:MI:SS')
              FROM v_em_q_metric_host_hrs)
              ;
         commit;
         select count(*) into v_rows from mig_em_metric_host_hrs;
         p_log('mig', '01 load host data - rows '||to_char(v_rows,'999,999,990'));
         return 0;
      exception
        when others then
           rollback;
           p_log ('mig','faild: ' || SQLERRM);
           commit;
           return SQLERRM;
      end;

END F_EM_LOAD_HOST_METRIC;

/
--------------------------------------------------------
--  DDL for Function F_EM_LOAD_HOST_PROP
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_EM_LOAD_HOST_PROP" RETURN NUMBER AS
     v_rows number;
BEGIN

  p_log ('mig','Start F_LOAD_EM_HOST_PROP');

    delete from mig_em_hosts_props;
delete from mig_EM_HOST_PROPS_HW;
commit;

insert into mig_EM_HOST_PROPs_HW
value (
SELECT
    target_name,
    target_guid,
    start_timestamp,
    last_collection_timestamp,
    cpu_count,
    physical_cpu_count,
    logical_cpu_count,
    total_cpu_cores
FROM
    v_em_p_host_props_hw
     where last_collection_timestamp > sysdate -7)
;

insert into mig_EM_HOST_PROPs_HW
value (
SELECT
    target_name,
    target_guid,
    start_timestamp,
    last_collection_timestamp,
    cpu_count,
    physical_cpu_count,
    logical_cpu_count,
    total_cpu_cores
FROM
    v_em_q_host_props_hw
     where last_collection_timestamp > sysdate -7)
;

insert into mig_em_hosts_props value (
SELECT RAWTOHEX(h.target_guid) AS target_guid
      ,h.target_name
      ,p.source
      ,p.name
      ,p.value
      ,SYSTIMESTAMP EXTRACT_DTTM_UTC
FROM   sysman.cm$mgmt_ecm_os_property@OEM134P_SYSMAN p
      ,sysman.mgmt$target@OEM134P_SYSMAN               h
WHERE  h.target_guid = p.cm_target_guid
AND    h.target_type = 'host'
AND    p.source       = '/sbin/sysctl'
AND    p.name        IN (
                         'vm.nr_hugepages'
                        )
AND    h.target_name IN (
                         SELECT host_name
                         FROM   sysman.mgmt$target@OEM134P_SYSMAN
                         WHERE  target_type = 'oracle_database'
                         UNION
                         SELECT member_target_name
                         FROM   sysman.mgmt$target_flat_members@OEM134P_SYSMAN
                         WHERE  member_target_type    = 'host'
                         AND    aggregate_target_type IN ('oracle_exadata_cloud_service', 'oracle_dbmachine')
                        )
)
;

-- Q OEM
insert into mig_em_hosts_props value (
SELECT RAWTOHEX(h.target_guid) AS target_guid
      ,h.target_name
      ,p.source
      ,p.name
      ,p.value
      ,SYSTIMESTAMP EXTRACT_DTTM_UTC
FROM   sysman.cm$mgmt_ecm_os_property@OEM134Q_SYSMAN p
      ,sysman.mgmt$target@OEM134Q_SYSMAN               h
WHERE  h.target_guid = p.cm_target_guid
AND    h.target_type = 'host'
AND    p.source       = '/sbin/sysctl'
AND    p.name        IN (
                         'vm.nr_hugepages'
                        )
AND    h.target_name IN (
                         SELECT host_name
                         FROM   sysman.mgmt$target@OEM134Q_SYSMAN
                         WHERE  target_type = 'oracle_database'
                         UNION
                         SELECT member_target_name
                         FROM   sysman.mgmt$target_flat_members@OEM134Q_SYSMAN
                         WHERE  member_target_type    = 'host'
                         AND    aggregate_target_type IN ('oracle_exadata_cloud_service', 'oracle_dbmachine')
                        )
)
;

         commit;
         select count(*) into v_rows from mig_em_hosts_props;
         p_log('mig', 'F_LOAD_EM_HOST_PROP - rows '||to_char(v_rows,'999,999,990'));
         return 0;

EXCEPTION
    WHEN OTHERS THEN
       rollback;
       p_log ('mig','error function F_LOAD_EM_HOST_PROP : ' || SQLERRM);
       commit;
       return SQLERRM;
END F_em_LOAD_HOST_PROP;

/
--------------------------------------------------------
--  DDL for Function F_FETCH_HOST_CORES
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_FETCH_HOST_CORES"
(
  P_TARGET_GUID IN VARCHAR2
, P_TARGET_TYPE IN VARCHAR2
) RETURN NUMBER AS

/*
v1.0 sept24
-try to return # of cores t a given date
*/
   v_host_guid varchar2(40);
   v_date      date;
   v_cores     number := null;

BEGIN

  if P_TARGET_TYPE = 'host' then
     v_host_guid := P_TARGET_GUID;
  else
     select host_target_guid into v_host_guid
     from mig_database
     where db_target_guid = P_TARGET_GUID;
 end if;

  select total_cpu_cores into v_cores
  from mig_xt_SERVERS
  where host_target_guid = v_host_guid;

  return v_cores;
exception
  when others then
    RETURN null;
END F_FETCH_HOST_CORES;

/
--------------------------------------------------------
--  DDL for Function F_FETCH_VLAN_ID
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_FETCH_VLAN_ID" (ip_address VARCHAR2) RETURN NUMBER IS
  v_vlan_id NUMBER;
BEGIN
  BEGIN
    -- Query to fetch the corresponding vlan_id based on the given IP address
    SELECT vn_id
    INTO v_vlan_id
    FROM mig_infran_deployed_vnets
    WHERE f_ip_to_number(ip_address) BETWEEN f_ip_to_number(vn_ip_from) AND f_ip_to_number(vn_ip_to)
    FETCH FIRST 1 ROWS ONLY; -- Ensures only one row is fetched in case of overlapping ranges
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      -- Handle case where no matching vlan_id is found
      v_vlan_id := NULL;
  END;

  RETURN v_vlan_id;
END f_fetch_vlan_id;

/
--------------------------------------------------------
--  DDL for Function F_IP_TO_NUMBER
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_IP_TO_NUMBER" (ip VARCHAR2) RETURN NUMBER IS
   part1 NUMBER;
   part2 NUMBER;
   part3 NUMBER;
   part4 NUMBER;
   ip_number NUMBER := 0;
BEGIN
   -- Extract each part of the IP address
   part1 := TO_NUMBER(REGEXP_SUBSTR(ip, '[^\.]+', 1, 1));
   part2 := TO_NUMBER(REGEXP_SUBSTR(ip, '[^\.]+', 1, 2));
   part3 := TO_NUMBER(REGEXP_SUBSTR(ip, '[^\.]+', 1, 3));
   part4 := TO_NUMBER(REGEXP_SUBSTR(ip, '[^\.]+', 1, 4));

   -- Calculate the numeric representation
   ip_number := (part1 * POWER(256, 3)) +
                (part2 * POWER(256, 2)) +
                (part3 * POWER(256, 1)) +
                part4;

   RETURN ip_number;
END;

/
--------------------------------------------------------
--  DDL for Function F_IS_RULE_ACTIVE
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_IS_RULE_ACTIVE"
(
  P_RULE_NR IN NUMBER
) RETURN NUMBER AS
v_ret number;
BEGIN

  select 1 inito into v_ret
  from mig_infran_param_rules
  where rule_nr = p_rule_nr
  and rule_active = 'Y';
  return v_ret;
EXCEPTION
    WHEN OTHERS THEN
     RETURN 0;
END F_IS_RULE_ACTIVE;

/
--------------------------------------------------------
--  DDL for Function F_LOG_TO_DBMS_OUT
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_LOG_TO_DBMS_OUT" RETURN NUMBER AS

cursor c_log is
   select dbr, wer, was
   from mig_LOG
   order by lnr asc;

BEGIN

  --execute IMMEDIATE ('set serveroutput on;');
  --execute IMMEDIATE ('set pagesize 1000;');
  --execute IMMEDIATE ('set linesize 2000;');

  for xl in c_log loop
     dbms_output.put_line(to_char(xl.dbr,'YYYY-MM-DD HH24:MI:SS')||' '||xl.was);
  end loop;

  RETURN 0;
END F_LOG_TO_DBMS_OUT;

/
--------------------------------------------------------
--  DDL for Function F_NUMBER_TO_IP
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_NUMBER_TO_IP" (ip_number NUMBER) RETURN VARCHAR2 IS
   ip VARCHAR2(15);
BEGIN
   ip := FLOOR(ip_number / POWER(256, 3)) || '.' ||
         FLOOR(MOD(ip_number, POWER(256, 3)) / POWER(256, 2)) || '.' ||
         FLOOR(MOD(ip_number, POWER(256, 2)) / POWER(256, 1)) || '.' ||
         MOD(ip_number, 256);
   RETURN ip;
END;

/
--------------------------------------------------------
--  DDL for Function F_PROV_CDB
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_PROV_CDB" RETURN NUMBER AS

   -- PROVISION NEW cdbs and cddb instances
    quit_db EXCEPTION;
    endless_loop EXCEPTION;
    V_DG_id                       VARCHAR2(10) := 'DG';
    db_placement_dc               mig_infran_param_azure_location.azure_dc%TYPE;
    v_az_dc1                      mig_infran_param_azure_location.azure_dc%TYPE;
    v_az_dc2                      mig_infran_param_azure_location.azure_dc%TYPE;
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
    new_cdb_id                    NUMBER := 0;
    current_cdb_id                NUMBER := 0;
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
    total_ocpus                   NUMBER := 0;
    ocpu_per_instance             NUMBER := 0;
    primary_data_center           VARCHAR2(20);
    standby_data_center           VARCHAR2(20);
    v_gb_mem_per_ocpu             NUMBER := 0;
    v_sessions_per_ocpu           NUMBER := 0;
    v_sessions_per_phys_core      NUMBER := 0;
    v_read_iops_per_gb            NUMBER := 0;
    v_write_iops_per_gb           NUMBER := 0;
    v_min_ocpu                    NUMBER := 0;
    v_min_storage_gb              NUMBER := 0;
    v_rac                         NUMBER := 0;
    v_description                 VARCHAR2(250);
    v_pga                         NUMBER := 0;
    v_sga                         NUMBER := 0;
    v_used_gb                     NUMBER := 0;
    v_dg_rac                      NUMBER := 0;
    v_pr_rac                      NUMBER := 0;
    v_ocpu_instance               NUMBER := 0;
    v_alloc_gb                    NUMBER := 0;
    v_write_iops                  NUMBER := 0;
    v_read_iops                   NUMBER := 0;
    v_ocpu_target                 NUMBER := 0;
    v_ret                         NUMBER := 0;
    v_db_quits                    NUMBER := 0;
    v_split                       char(1);
    v_rac_cl_id                   NUMBER := 0;
    v_occa_metric                 NUMBER := 0;
    v_divisor                     NUMBER := 0;
    v_dg_rule                     char(1) := 'N';
    v_exa_mem_bonus               NUMBER := 1;
    v_exa_cpu_bonus               NUMBER := 1;

    v_ha_rac          mig_infran_ha_concepts%ROWTYPE;
    v_ha_dg           mig_infran_ha_concepts%ROWTYPE;
    v_xt_db_stat      mig_xt_db_stat%ROWTYPE;
    v_active_scenario mig_infran_param_scenarios%ROWTYPE;

    v_cdb                         mig_infran_cdb%ROWTYPE;
    v_stdby_cdb                   mig_infran_cdb%ROWTYPE;
    v_cdb_limits                  mig_infran_param_technical_limits%ROWTYPE;
    -- Record type for metrics
    TYPE metric_record IS RECORD (
        id          NUMBER,
        min_value   NUMBER,
        avg_value   NUMBER,
        max_value   NUMBER,
        cat_value   NUMBER,
        metric_cat  varchar2(10),
        metric_name VARCHAR2(60)
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
        anz_cores
        used_gb,
        anz_db_links,
        ha_id,
        target_platform,
        data_classification,
        prov_rac
    FROM
        mig_database
    WHERE
        target_platform = 'EXAD'
       ;

    -- Function to calculate core counts
    FUNCTION get_core_count (
        data_center VARCHAR2
    ) RETURN NUMBER IS
        core_count NUMBER := 0;
    BEGIN
        SELECT
            nvl(SUM(anz_ocpus),0)
        INTO core_count
        FROM
            mig_infran_cdb
        WHERE
            azure_dc = data_center;
        RETURN core_count;
    EXCEPTION
        WHEN no_data_found THEN
        RETURN 0;
    END get_core_count;

BEGIN

    p_log('mig', 'Start provisioning EXAD instances');
    COMMIT;

    SELECT   rule_active into v_dg_rule
    FROM   mig_infran_param_rules
    where  rule_nr = 7; --DG Rule

    select * into v_active_scenario
    FROM mig_infran_param_scenarios
    where active = 'Y';

   select azure_dc into v_az_dc1
   from mig_infran_param_azure_location
   where target_platform = 'EXAD'
   and dc_nr = 1;

   select azure_dc into v_az_dc2
   from mig_infran_param_azure_location
   where target_platform = 'EXAD'
   and dc_nr = 2;

   step_marker :=2;
   SELECT * into v_ha_dg
   FROM mig_infran_ha_concepts
   where con_id = 'DG';
   step_marker :=21;

      p_log('mig', '***Use EM Metric');
      metrics(1) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.session_metric);
      metrics(2) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.write_io_metric);
      metrics(3) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.read_io_metric);
      metrics(4) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.cpu_metric);
      metrics(5) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.sga_metric);
      metrics(6) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.pga_metric);
      metrics(7) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.storage_metric);
      metrics(8) := metric_record(0, 0, 0, 0, 0, ' ',  v_active_scenario.used_storage_metric);

    step_marker :=3;
    -- read limits
    select * into v_cdb_limits
    FROM    mig_infran_param_technical_limits
    where   target_config = 'EXAD';

    -- exa advontages
    select (100 - exa_cpu_bonus_pct)/100,
           (100 - exa_mem_bonus_pct)/100 into
           v_exa_cpu_bonus,
           v_exa_mem_bonus
    from mig_infran_param_exa_specs
    where active = 'Y';

    p_log('mig', '***apply cpu/mem adv. for exa '||to_char(v_exa_cpu_bonus)||'/'||to_char(v_exa_mem_bonus));

    -- clear table
    step_marker :=4;
    DELETE FROM mig_infran_cdb_instance;
    DELETE FROM mig_infran_cdb;
    delete from mig_infran_rac_cluster;

    -- Loop through each database
    FOR db_record IN database_cursor LOOP
    begin
        step_marker := 5;

        total_databases_processed := total_databases_processed + 1;

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
      step_marker := 6;

  -- Change placement if needed depending on # of cores
        db_placement_dc := v_az_dc1;

        IF get_core_count(v_az_dc1) > get_core_count(v_az_dc2) THEN
            db_placement_dc := v_az_dc2;
            total_placement_changes := total_placement_changes + 1;
        END IF;

        step_marker := 7;

      -- decide rac adjustments
       if nvl(db_record.prov_rac,'NORAC') != 'NORAC'
       then
         -- read rac adjustments#

         SELECT * into v_ha_rac
           FROM mig_infran_ha_concepts
          where con_id = db_record.prov_rac;

         -- no split by RACONE
         if db_record.prov_rac = 'RAC'
         then
            v_split               := 'Y';
         else
            v_split               := 'N';
         end if;
         v_rac_cl_id := s1.nextval;
         insert into mig_infran_rac_cluster
           values (v_rac_cl_id, db_record.prov_rac );

       else
         -- set all adjustmensts to factor 1 = no adjustments
           v_ha_rac.adj_cores    := 1;
           v_ha_rac.adj_sga      := 1;
           v_ha_rac.adj_pga      := 1;
           v_ha_rac.adj_used_gb  := 1;
           v_ha_rac.adj_alloc_gb := 1;
           v_ha_rac.adj_iops     := 1;
           v_ha_rac.adj_session  := 1;
           v_split               := 'N';
           v_rac_cl_id           := null;
       end if;

      -- create cdb
      v_cdb.cdb_name            := db_record.oracledb;
      v_cdb.old_target_guid     := db_record.db_target_guid;
      v_cdb.environment         := db_record.environment;
      v_cdb.data_classification := db_record.data_classification;
      v_cdb.service_category    := db_record.service_category;

      if v_active_scenario.use_maximum_metrics = 'Y'
      then
         v_cdb.alloc_gb            := round(metrics(7).max_value,3);
         v_cdb.pga_gb              := round(metrics(6).max_value * v_exa_mem_bonus,3);
         v_cdb.sga_gb              := round(metrics(5).max_value * v_exa_mem_bonus,3);
         v_cdb.anz_ocpus           := round(metrics(4).max_value * v_exa_cpu_bonus,3); -- possible to burst

      else
         v_cdb.alloc_gb            := round(metrics(7).avg_value,3);
         v_cdb.pga_gb              := round(metrics(6).avg_value * v_exa_mem_bonus,3);
         v_cdb.sga_gb              := round(metrics(5).avg_value * v_exa_mem_bonus,3);
         v_cdb.anz_ocpus           := round(metrics(4).avg_value * v_exa_cpu_bonus,3); -- possible to burst
      end if;

      v_cdb.avg_used_ocpus      := round(metrics(4).avg_value * v_exa_cpu_bonus,3);
      v_cdb.max_used_ocpus      := round(metrics(4).max_value * v_exa_cpu_bonus,3);
      v_cdb.used_gb             := round(metrics(8).max_value,3);
      v_cdb.avg_sessions        := round(metrics(1).avg_value,3);
      v_cdb.max_sessions        := round(metrics(1).max_value,3);
      v_cdb.avg_wr_iops         := round(metrics(2).avg_value,3);
      v_cdb.max_wr_iops         := round(metrics(2).max_value,3);
      v_cdb.avg_read_iops       := round(metrics(3).avg_value,3);
      v_cdb.max_read_iops       := round(metrics(3).max_value,3);
      v_cdb.cdb_id          := s1.nextval;
      v_cdb.dg_type             := NULL;
      v_cdb.dg_remote_id        := NULL;
      v_cdb.azure_dc            := db_placement_dc;
      v_cdb.anz_db_links        := db_record.anz_db_links;
      v_cdb.description         := null;
      v_cdb.ha_id               := db_record.ha_id;
      v_cdb.split_instance      := v_split;
      v_cdb.dg_remote_nr        := null;
      v_cdb.RAC_TYPE            := db_record.prov_rac;
      step_marker := 8;

       if nvl(db_record.prov_rac,'NORAC') != 'NORAC'
       then

--   rac adjustments
         v_cdb.description         := v_cdb.description||' adj. RAC (cores/pga/sga) from :';
         v_cdb.description         := v_cdb.description||to_char(v_cdb.anz_ocpus)||'/'||to_char(v_cdb.pga_gb)||'/'||to_char(v_cdb.sga_gb);
         v_cdb.pga_gb              := round(v_cdb.pga_gb * v_ha_rac.adj_pga,3);
         v_cdb.sga_gb              := round(v_cdb.sga_gb  * v_ha_rac.adj_sga,3);
         v_cdb.anz_ocpus           := round(v_cdb.anz_ocpus *  v_ha_rac.adj_cores,3);
         v_cdb.description         := v_cdb.description||' to: '||to_char(v_cdb.anz_ocpus)||'/'||to_char(v_cdb.pga_gb)||'/'||to_char(v_cdb.sga_gb);
         total_adjustments_cpu     := total_adjustments_cpu + 1;
         step_marker := 9;
       end if;

      insert into mig_infran_cdb values (v_cdb.cdb_name,v_cdb.old_target_guid,v_cdb.environment,v_cdb.service_category,
                                         v_cdb.alloc_gb,v_cdb.pga_gb,v_cdb.sga_gb,v_cdb.anz_ocpus,v_cdb.avg_used_ocpus,v_cdb.max_used_ocpus,
                                         v_cdb.used_gb,v_cdb.avg_sessions,v_cdb.max_sessions,v_cdb.avg_wr_iops,v_cdb.max_wr_iops,
                                         v_cdb.avg_read_iops,v_cdb.max_read_iops,v_cdb.cdb_id,v_cdb.dg_type,v_cdb.dg_remote_id,
                                         v_cdb.exa_cl_id,v_cdb.anz_db_links,v_cdb.description,v_cdb.ha_id,v_cdb.split_instance,
                                         v_cdb.dg_remote_nr,v_cdb.azure_dc,v_cdb.RAC_TYPE,v_cdb.data_classification, v_rac_cl_id);
      total_instances := total_instances + 1;
      step_marker := 10;

      -- check DG
      if (v_cdb.ha_id = 'DG' and v_dg_rule = 'Y')
      then
         step_marker := 11;

       -- create stdby out of primary and update primary
       v_stdby_cdb            := v_cdb;

       v_stdby_cdb.anz_ocpus := round(v_cdb.anz_ocpus * v_ha_dg.adj_cores,3);
       if v_stdby_cdb.anz_ocpus < v_cdb_limits.min_cores then
           v_stdby_cdb.anz_ocpus := v_cdb_limits.min_cores;
       end if;
       step_marker := 12;

       v_stdby_cdb.sga_gb := round(v_stdby_cdb.sga_gb * v_ha_dg.adj_sga,3);
       v_stdby_cdb.pga_gb := round(v_stdby_cdb.pga_gb * v_ha_dg.adj_pga,3);

       v_stdby_cdb.cdb_id   := s1.nextval;
       v_stdby_cdb.dg_type       := 'StandBy';
       v_stdby_cdb.dg_remote_id  := v_cdb.cdb_id;
       v_stdby_cdb.cdb_name := 'STBY_'||v_cdb.cdb_name;
       v_stdby_cdb.environment := 'DG-'||v_cdb.environment;
         step_marker := 13;

       if v_cdb.azure_dc  = v_az_dc1 then
            v_stdby_cdb.azure_dc := v_az_dc2;
       else
            v_stdby_cdb.azure_dc := v_az_dc1;
       end if;
         step_marker := 14;

       -- update primary
       update mig_infran_cdb
              set dg_type = 'Primary',
                  dg_remote_id = v_stdby_cdb.cdb_id
       where cdb_id = v_cdb.cdb_id;
         step_marker := 15;

       -- creaze new rac cl if primary is rac
       v_rac_cl_id := null;
       if v_cdb.rac_cluster_id is not null
       then
         v_rac_cl_id := s1.nextval;
         insert into mig_infran_rac_cluster
           values (v_rac_cl_id, v_cdb.rac_type );
       end if;

       insert into mig_infran_cdb values (v_stdby_cdb.cdb_name,v_stdby_cdb.old_target_guid,v_stdby_cdb.environment,v_stdby_cdb.service_category,
                                          v_stdby_cdb.alloc_gb,v_stdby_cdb.pga_gb,v_stdby_cdb.sga_gb,v_stdby_cdb.anz_ocpus,v_stdby_cdb.avg_used_ocpus,v_stdby_cdb.max_used_ocpus,
                                          v_stdby_cdb.used_gb,v_stdby_cdb.avg_sessions,v_stdby_cdb.max_sessions,v_stdby_cdb.avg_wr_iops,v_stdby_cdb.max_wr_iops,
                                          v_stdby_cdb.avg_read_iops,v_stdby_cdb.max_read_iops,v_stdby_cdb.cdb_id,v_stdby_cdb.dg_type,v_stdby_cdb.dg_remote_id,
                                          v_stdby_cdb.exa_cl_id,v_stdby_cdb.anz_db_links,v_stdby_cdb.description,v_stdby_cdb.ha_id,v_stdby_cdb.split_instance,
                                          v_stdby_cdb.dg_remote_nr,v_stdby_cdb.azure_dc,v_stdby_cdb.RAC_TYPE,v_stdby_cdb.data_classification, v_rac_cl_id);
         total_dg_instances := total_dg_instances + 1;
         step_marker := 16;

      end if;
      commit;
   exception
     when others then
          rollback;
          total_db_quits := total_db_quits + 1;
            p_log('mig', 'Provisioning CDB Database: An error occurred: last step:'||to_char(step_marker)||' msg='|| sqlerrm);
            COMMIT;
   END;
 END LOOP;
    -- Detailed statistics
    COMMIT;
    p_log('mig', '# Databases processed:          ' || TO_CHAR(total_databases_processed));
    p_log('mig', '# CDBs provisiodned:            ' || TO_CHAR(total_instances));
    p_log('mig', '# CDBs-DG  provisiodned:        ' || TO_CHAR(total_DG_instances));
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
    return 0;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
             p_log('mig', 'Provisioning CDB EXAD Database: An error occurred: ' || TO_CHAR(step_marker) || ' ' || SQLERRM);
            COMMIT;
            return 1;
END F_PROV_CDB;

/
--------------------------------------------------------
--  DDL for Function F_PROV_CDB_INSTANCE
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_PROV_CDB_INSTANCE" RETURN NUMBER AS
 -- for dedbug infos
 v_step_marker number := 0;
 v_procedure   varchar2(20) := 'F_PROV_CDB_INSTANCE';
 quit_procedure exception;

    cursor c_cdb is
      SELECT
    cdb_name,
    old_target_guid,
    environment,
    service_category,
    alloc_gb,
    pga_gb,
    sga_gb,
    anz_ocpus,
    avg_used_ocpus,
    max_used_ocpus,
    used_gb,
    avg_sessions,
    max_sessions,
    avg_wr_iops,
    max_wr_iops,
    avg_read_iops,
    max_read_iops,
    cdb_id,
    dg_type,
    dg_remote_id,
    exa_cl_id,
    anz_db_links,
    description,
    ha_id,
    split_instance,
    dg_remote_nr,
    azure_dc,
    rac_type,
    data_classification,
    rac_cluster_id
   FROM
    mig_infran_cdb
    --fetch first 10 rows only
    ;

       v_cdbi     mig_infran_cdb_instance%ROWTYPE;
       v_ret      number := 0;
       v_divisor  number := 0;
       v_inst_nr  number := 0;
       v_max_inst number := 0;
       V_PR_RAC   number := 0;
       total_databases_processed number := 0;

BEGIN
   p_log('mig', 'Start F_PROV_CDB_INSTANCE');
   COMMIT;
   v_step_marker := 1;
   -- read rac adjustments#

   delete from mig_infran_cdb_instance;
   commit;

   for xcdb in c_cdb loop

       total_databases_processed := total_databases_processed + 1;
       v_max_inst := 1;
       v_divisor  := 1;
       if xcdb.rac_type = 'RAC' then
           v_max_inst := 2;
           v_divisor  := 2;
       end if;

      -- DBMS_OUTPUT.PUT_LINE('cdb_sga '||xcdb.sga_gb||' div='||v_divisor);

       for v_ins_nr in 1..v_max_inst loop

          V_PR_RAC              := V_PR_RAC + 1;
          v_cdbi.pga_gb         := round(xcdb.pga_gb,3);
          v_cdbi.sga_gb         := round(xcdb.sga_gb,3);
          v_cdbi.anz_ocpus      := round(xcdb.anz_ocpus/v_divisor,3);
          v_cdbi.avg_used_ocpus := round(xcdb.avg_used_ocpus/v_divisor,3);
          v_cdbi.max_used_ocpus := round(xcdb.max_used_ocpus/v_divisor,3);
          v_cdbi.avg_sessions   := round(xcdb.avg_sessions/v_divisor,3);
          v_cdbi.max_sessions   := round(xcdb.max_sessions/v_divisor,3);
          v_cdbi.avg_wr_iops    := round(xcdb.avg_wr_iops/v_divisor,3);
          v_cdbi.max_wr_iops    := round(xcdb.max_wr_iops/v_divisor,3);
          v_cdbi.avg_read_iops  := round(xcdb.avg_read_iops/v_divisor,3);
          v_cdbi.max_read_iops  := round(xcdb.max_read_iops/v_divisor,3);
          v_cdbi.instance_id    := v_ins_nr;
          v_cdbi.exa_rack_id    := null;
          v_cdbi.exa_cl_id      := null;
          v_cdbi.exa_vm_id      := null;
          v_cdbi.cdb_id         := xcdb.cdb_id;
          v_cdbi.instance_name  := xcdb.cdb_name||'-I'||to_char(v_ins_nr);
          v_cdbi.rac_cluster_id := xcdb.rac_cluster_id;

        --  DBMS_OUTPUT.PUT_LINE('cdbi_sga '||v_cdbi.sga_gb);

          insert into mig_infran_cdb_instance
              values (
                  v_cdbi.pga_gb,
                  v_cdbi.sga_gb,
                  v_cdbi.anz_ocpus,
                  v_cdbi.avg_used_ocpus,
                  v_cdbi.max_used_ocpus,
                  v_cdbi.avg_sessions,
                  v_cdbi.max_sessions,
                  v_cdbi.avg_wr_iops,
                  v_cdbi.max_wr_iops,
                  v_cdbi.avg_read_iops,
                  v_cdbi.max_read_iops,
                  v_cdbi.instance_id,
                  v_cdbi.exa_rack_id,
                  v_cdbi.exa_cl_id,
                  v_cdbi.exa_vm_id,
                  v_cdbi.cdb_id,
                  v_cdbi.instance_name,
                  v_cdbi.rac_cluster_id);
       end loop;
   end loop;

      COMMIT;
    p_log('mig', '# Databases processed:          ' || TO_CHAR(total_databases_processed));
    p_log('mig', '# RAC instances provisioned:    ' || TO_CHAR(V_PR_RAC));
    p_log('mig', 'End F_PROV_CDB_INSTANCE');
    COMMIT;
    return 0;
 EXCEPTION
    WHEN quit_procedure THEN
        ROLLBACK;
        p_log('mig', 'ERROR: '||v_procedure||' last Step='|| TO_CHAR(v_step_marker));
        p_log('mig', 'msg=' || SQLERRM);
        --v_ret := f_log_to_dbms_out;
        COMMIT;
        return 1;
    WHEN OTHERS THEN
        ROLLBACK;
        p_log('mig', 'ERROR: '||v_procedure||' last Step='|| TO_CHAR(v_step_marker));
        p_log('mig', 'msg=' || SQLERRM);
       -- v_ret := f_log_to_dbms_out;
        COMMIT;
        return 1;
END F_PROV_CDB_INSTANCE;

/
--------------------------------------------------------
--  DDL for Function F_PROV_EXA_INFRA
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_PROV_EXA_INFRA" (
  p_exa_generation     IN  varchar2
, p_ANZ_DB_SERVER      IN  number
, p_anz_storage_cells  IN  number
, P_location           in  varchar2
, p_description        in  varchar2
, p_anz_racks          in  number
, p_trunc_before       in  char
, p_exa_rack_ids       out varchar2
) return number AS

 v_exa_specs mig_infran_param_exa_specs%ROWTYPE;
 v_step_marker    integer := 0;
 lc               integer := 0;
 lc2              integer := 0;
 v_prov_racks     integer := 0;
 v_prov_dbsrv     integer := 0;
 v_prov_cells     integer := 0;
 v_prov_ocpus     integer := 0;
 v_prov_gbmem     integer := 0;
 v_prov_gbstg     integer := 0;
 v_delimiter      char    := '';

 v_cell      mig_infran_exa_storage_cell%ROWTYPE;
 v_dbsrv     mig_infran_exa_dbserver%ROWTYPE;
 v_exa_rack  mig_infran_exaracks%ROWTYPE;

BEGIN
   p_log ('mig','Start provisioning EXA-D Infra');
   commit;
   p_exa_rack_ids := '';
   -- load specs
   v_step_marker := 1;
   select * into v_exa_specs
   from mig_infran_param_exa_specs
   where generation = p_exa_generation;

   if p_trunc_before = 'Y' then
      v_step_marker := 2;

      update mig_infran_cdb_instance
          set exa_vm_id = null, exa_cl_id = null, exa_rack_id = NULL;

      update mig_infran_cdb
          set exa_cl_id = null;

      delete FROM mig_infran_exa_cluster_vm;
      delete FROM mig_infran_exa_cluster;
      delete FROM mig_infran_exa_storage_cell;
      delete FROM mig_infran_exa_dbserver;
      delete FROM mig_infran_exaracks;
   end if;

   -- Generating
   v_step_marker := 3;

   for lc in 1..p_anz_racks loop

       v_step_marker := 4;
       v_prov_racks := v_prov_racks + 1;
       v_exa_rack.exa_rackid := s1.nextval;
       v_exa_rack.exa_location := p_location;
       v_exa_rack.exa_desc := p_description;
       p_exa_rack_ids  := p_exa_rack_ids||v_delimiter||to_char(v_exa_rack.exa_rackid);
       v_delimiter := ',';

       insert into mig_infran_exaracks values v_exa_rack;
       -- prov db_server
       for lc2 in 1..p_anz_db_server loop
           v_step_marker := 4;
           v_prov_dbsrv  := v_prov_dbsrv + 1;
           v_prov_ocpus  := v_prov_ocpus + v_exa_specs.dbsrv_cpu_cores * v_exa_specs.dbsrv_sockets ;
           v_prov_gbmem  := v_prov_gbmem + v_exa_specs.dbsrv_main_memory_gb;

           v_dbsrv.exa_rackid      := v_exa_rack.exa_rackid;
           v_dbsrv.exa_generation  := v_exa_specs.generation;
           v_dbsrv.anz_cores       := v_exa_specs.dbsrv_cpu_cores;
           v_dbsrv.anz_sockets     := v_exa_specs.dbsrv_sockets;
           v_dbsrv.anz_vcpus       := v_exa_specs.dbsrv_cpu_cores * v_exa_specs.dbsrv_sockets * 2;
           v_dbsrv.main_mem        := v_exa_specs.dbsrv_main_memory_gb;
           v_dbsrv.max_vms         := v_exa_specs.dbsrv_max_vms;
           v_dbsrv.inst_vms        := 99999;
           v_dbsrv.exa_dbsrv_id    := s1.nextval;

           insert into mig_infran_exa_dbserver values v_dbsrv;

       end loop;

        -- prov cell_server
       for lc2 in 1..p_anz_storage_cells loop
           v_step_marker := 5;
           v_prov_cells  := v_prov_cells + 1;
           v_prov_gbstg  := v_prov_gbstg + v_exa_specs.cellsrv_disk_storage_tb * 1024;

           v_cell.exa_rackid      := v_exa_rack.exa_rackid;
           v_cell.exa_generation  := v_exa_specs.generation;
           v_cell.gb_for_db       :=  v_exa_specs.cellsrv_disk_storage_tb * 1024;
           v_cell.free_gb         :=  v_exa_specs.cellsrv_disk_storage_tb * 1024;
           v_cell.exa_cellsrv_id    := s1.nextval;

           insert into mig_infran_exa_storage_cell values v_cell;

       end loop;

   end loop;
    -- Detailed statistics
    COMMIT;
    p_log('mig', '# Exa RACKs provisioned:        ' || TO_CHAR(v_prov_racks));
    p_log('mig', '# DB Server provisiodned:       ' || TO_CHAR(v_prov_dbsrv));
    p_log('mig', '#              ocpus:           ' || TO_CHAR(v_prov_ocpus));
    p_log('mig', '#     GB Main Memory:           ' || TO_CHAR(v_prov_gbmem));
    p_log('mig', '# CELL Server providioned       ' || TO_CHAR(v_prov_cells));
    p_log('mig', '#     GB Usable Storage:        ' || TO_CHAR(v_prov_gbstg));
    p_log('mig', 'End provision ADB instances');
    COMMIT;

   p_log ('mig','Ende provisioning EXA-D Infra');
   return 0;
   commit;
EXCEPTION
    WHEN OTHERS THEN
        rollback;
        p_log ('mig','Failure Exa Infra Prov: last step='||to_char(v_step_marker)||' error='|| SQLERRM);
        commit;
        return 1;
END F_PROV_EXA_INFRA;

/
--------------------------------------------------------
--  DDL for Function F_ROLLOUT_CLUSTERS
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_ROLLOUT_CLUSTERS" RETURN NUMBER AS

    v_az_dc1                      mig_infran_param_azure_location.azure_dc%TYPE;
    v_az_dc2                      mig_infran_param_azure_location.azure_dc%TYPE;
    v_step_marker                 NUMBER := 0;
    v_cl_id                       NUMBER := 0;
    v_vm_id                       NUMBER := 0;
    v_created_clusters            NUMBER := 0;
    v_srv_num                     NUMBER := 0;
    v_created_vms                 NUMBER := 0;
    v_cl_proc                     NUMBER := 0;
    v_no_cluster_found            NUMBER := 0;
    v_cluster_found               NUMBER := 0;
    v_exa_rackid                  NUMBER := 0;
    v_cpu_in_use                  number := 0;
    v_memgb_in_use                number := 0;
    v_storage_in_use              number := 0;

    cursor c_clusters is
      SELECT
          azure_dc,
          target_platform,
          cluster_name,
          environments,
          service_category
     FROM
       mig_infran_param_clusters
     where target_platform = 'EXAD';

   cursor c_exaracks(p_az_dc varchar2)  is
            SELECT
                exa_rackid
           FROM
              mig_infran_exaracks
           where exa_location = p_az_dc;

   cursor c_exasrv(p_exa_rackid number)  is
            SELECT
                exa_dbsrv_id
           FROM
              mig_infran_exa_dbserver
           where  inst_vms < max_vms
           and    exa_rackid = p_exa_rackid;

   cursor c_cdbi is
             SELECT
               b.azure_dc,
               b.environment,
               b.service_category,
               a.instance_id,
               b.cdb_id
             FROM mig_infran_cdb b,
                  mig_infran_cdb_instance a
             where b.cdb_id = a.cdb_id;

BEGIN

    p_log('mig', 'Start Rollout Clusters');
    COMMIT;

      delete FROM mig_infran_exa_cluster_vm;
      delete FROM mig_infran_exa_cluster;

      update mig_infran_cdb_instance
            set exa_cl_id = null, exa_vm_id = null, exa_RACK_ID = null;
      update mig_infran_cdb
            set exa_cl_id = null;

      update mig_infran_exa_dbserver
         set inst_vms = 0;

      commit;
      v_step_marker := 3;

      for xcl in c_clusters loop
        for  erack in c_exaracks(xcl.azure_dc) loop
            v_step_marker := 4;
            v_cl_id := s1.nextval;

            insert into mig_infran_exa_cluster
                (exa_cl_id, exa_rackid, exa_cl_name,
                 exa_environments, exa_service_category, exa_cl_location)
            values (v_cl_id, erack.exa_rackid, xcl.cluster_name,
                     xcl.environments, xcl.service_category, xcl.azure_dc);
            v_created_clusters := v_created_clusters + 1;
            v_step_marker := 5;

            v_srv_num := 1;
            for dbsrv in c_exasrv(erack.exa_rackid) loop
                v_step_marker := 5;

                insert into mig_infran_exa_cluster_vm ( exa_cl_id,
                               exa_dbsrv_id, exa_cl_name, exa_cl_vmnr)
                values (v_cl_id, dbsrv.exa_dbsrv_id, xcl.cluster_name, v_srv_num);
                v_srv_num := v_srv_num + 1;

                update mig_infran_exa_dbserver
                      set inst_vms = inst_vms  + 1
                where exa_rackid = erack.exa_rackid
                and   exa_dbsrv_id = dbsrv.exa_dbsrv_id;

                v_step_marker := 6;

                v_created_vms := v_created_vms +1;
            end loop;
        end loop;
        v_cl_proc := v_cl_proc + 1;
      end loop;

   -- assign instances to cluster vms

     for cdbi in c_cdbi loop
       begin
         select a.exa_cl_id, a.exa_rackid, ocpu_in_use, memgb_in_use
           into v_cl_id, v_exa_rackid, v_cpu_in_use, v_memgb_in_use
         from  mig_infran_exa_dbserver c,
               mig_infran_exa_cluster_VM b,
               mig_infran_exa_cluster a
         where c.exa_dbsrv_id = b.exa_dbsrv_id
         and   b.exa_cl_vmnr = cdbi.instance_id
         and   b. exa_cl_id = a.exa_cl_id
         and   f_check_in_list(cdbi.service_category, a.exa_service_category) = 1
         and   f_check_in_list(cdbi.environment, a.exa_environments) = 1
         and   a.exa_cl_location = cdbi.azure_dc;

          v_step_marker := 7;

         update mig_infran_cdb_instance
            set exa_cl_id = v_cl_id, exa_vm_id = cdbi.instance_id,
                exa_rack_id = v_exa_rackid
         where instance_id = cdbi.instance_id
         and   cdb_id = cdbi.cdb_id;

         update mig_infran_cdb
            set exa_cl_id = v_cl_id
         where cdb_id = cdbi.cdb_id;
         v_step_marker := 2;

         v_cluster_found := v_cluster_found + 1;
      exception
        when others then
          v_no_cluster_found := v_no_cluster_found + 1;
      end;
    end loop;
    -- Detailed statistics
    COMMIT;

    p_log('mig', '# Cluster processed:            ' || TO_CHAR(v_cl_proc));
    p_log('mig', '# Cluster processed:            ' || TO_CHAR(v_created_clusters));
    p_log('mig', '# Created VMs:                  ' || TO_CHAR(v_created_vms));
    p_log('mig', '# Instance assigmnet:           ' || TO_CHAR(v_cluster_found));
    p_log('mig', '# Failed assigment:             ' || TO_CHAR(v_no_cluster_found));
    p_log('mig', 'End Rollout Clusters');
    COMMIT;

    return 0;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
             p_log('mig', 'Provisioning CDB EXAD Database: An error occurred: ' || TO_CHAR(v_step_marker) || ' ' || SQLERRM);
            COMMIT;
            return 1;
END F_rollout_clusters;

/
--------------------------------------------------------
--  DDL for Function F_SET_STATUS
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_SET_STATUS"
(
  P_NR IN number
, P_STATUS IN VARCHAR2
) RETURN NUMBER AS

    v_status varchar2(30) := NULL;

BEGIN

  begin
    select status  into v_status
    from mig_control
    where nr = p_nr;
  EXCEPTION
    when others then
      v_status := 'XXnull';
  end;

  if v_status = 'XXnull' then
    insert into mig_control VALUES (
        p_nr, '***unknown***',null,p_status);
  else
     update mig_control set status = p_status
              where nr = p_nr;
  end if;
  COMMIT;
  return 0;
END F_SET_STATUS;

/
--------------------------------------------------------
--  DDL for Function F_TIMESTAMP_NUMBR
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_TIMESTAMP_NUMBR"
(
  PAR_TS IN varchar2
) RETURN NUMBER AS

  v_ret number := 0;

BEGIN

--   p_log('mig', 'f');
--  v_ret :=         to_number(substr(to_char(par_ts, 'YYYY-MM-DD HH24:MI:SS'),1,4)) * 365 * 24 * 60 * 60;         --xear to sec
--   p_log('mig', 'f');
-- v_ret := v_ret + to_number(substr(to_char(par_ts, 'YYYY-MM-DD HH24:MI:SS'),6,2)) * 12 * 24 * 60 * 60;  --mon to sec
--   p_log('mig', 'f');
--  v_  ret := v_ret + to_number(substr(to_char(par_ts, 'YYYY-MM-DD HH24:MI:SS'),9,2)) * 31 * 24 * 60 * 60;  --day to sec
--  p_log('mig', 'f');
--  v_ret := v_ret + to_number(substr(to_char(par_ts, 'YYYY-MM-DD HH24:MI:SS'),12,2)) * 60 * 60;            --hrs to sec
--   p_log('mig', 'f');
--  v_ret := v_ret + to_number(substr(to_char(par_ts, 'YYYY-MM-DD HH24:MI:SS'),15,2)) * 60;                --min to sec
--   p_log('mig', 'f');
--  v_ret := v_ret + to_number(substr(to_char(par_ts, 'YYYY-MM-DD HH24:MI:SS'),18,2));                     --min to sec
--   p_log('mig', 'f');
  v_ret :=         to_number(substr(par_ts,1,4)) * 365 * 24 * 60 * 60;         --xear to sec
  v_ret := v_ret + to_number(substr(par_ts,6,2)) * 12 * 24 * 60 * 60;  --mon to sec
  v_ret := v_ret + to_number(substr(par_ts,9,2)) * 31 * 24 * 60 * 60;  --day to sec
  v_ret := v_ret + to_number(substr(par_ts,12,2)) * 60 * 60;            --hrs to sec
  v_ret := v_ret + to_number(substr(par_ts,15,2)) * 60;                --min to sec
  v_ret := v_ret + to_number(substr(par_ts,18,2));                     --min to sec

  RETURN v_ret;
END F_TIMESTAMP_NUMBR;

/
--------------------------------------------------------
--  DDL for Function F_WIPE_OUT_EXA
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."F_WIPE_OUT_EXA" RETURN NUMBER AS
 -- for dedbug infos
 v_step_marker number := 0;
 v_procedure   varchar2(20) := 'F_WIPE_OUT_EXA';

BEGIN
  p_log ('mig','Start wipe out exa-d');
  commit;

      v_step_marker := 1;

      delete from mig_infran_cdb_instance;
      delete from mig_infran_cdb;

      v_step_marker := 2;

      delete FROM mig_infran_exa_cluster_vm;
      delete FROM mig_infran_exa_cluster;
      delete FROM mig_infran_exa_storage_cell;
      delete FROM mig_infran_exa_dbserver;
      delete FROM mig_infran_exaracks;

  p_log ('mig','End wipe out exa-d');
  commit;
  RETURN 0;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
             p_log('mig', 'ERROR: '||v_procedure||' last Step='|| TO_CHAR(v_step_marker));
             p_log('mig', 'msg=' || SQLERRM);
            COMMIT;
END F_WIPE_OUT_EXA;

/
--------------------------------------------------------
--  DDL for Function P_EM_LOAD_DB_SIZE
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE FUNCTION "MIGRATIONV2"."P_EM_LOAD_DB_SIZE" RETURN NUMBER AS
/*
v1.0 sept24
-loads db metric from em repo into local table
*/

   v_rows number;

BEGIN
       p_log('mig', 'load  mig_em_db_size');

      delete from mig_em_db_size;
      commit;

      begin
        insert into mig_em_db_size
        value (
         SELECT target_guid, database, month_date, used_size_gb,
         allocated_size_gb
        FROM v_em_p_db_size);

         insert into mig_em_db_size
        value (
         SELECT target_guid, database, month_date, used_size_gb,
         allocated_size_gb
        FROM v_em_q_db_size);
         select count(*) into v_rows from mig_em_db_size;
         p_log('mig', 'load  mig_em_db_size - rows '||to_char(v_rows,'999,999,990'));
        commit;
        return 0;
      exception
        when others then
           rollback;
           p_log ('mig','faild: ' || SQLERRM);
           commit;
           return sqlerrm;
      end;

END P_EM_LOAD_DB_SIZE;

/
