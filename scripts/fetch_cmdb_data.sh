#!/usr/bin/bash

#-- -----------------------------------------------------------------------------------------
#-- Script:        fetch_cmdb_data
#-- Created by:    Richard Rotter
#-- Date:          06.05.2025
#-- Description:   downloads data from cmdb into flat config files
#--
#-- Changelog:     Date        Who           What
#-- ------------   ----------  ------------  ------------------------------------------------
#--  v1.0          06.05.2025  Rotter        Creation
#--
#-- -----------------------------------------------------------------------------------------

#-------------------------------------------------

#if [ ! -f $rootDir/premigration.env ]; then
#    echo "wrong startdirectory... please run from <premig-root>/scripts dir ... exiting"
#    exit 1
#fi

#source $rootDir/premigration.env onprem

#if [ $? -ne 0 ]; then
#    echo "error loading env vars ... exitimg"
#    exit 1
#fi

trap cleanup EXIT INT TERM

function cleanup() {

    exit 0
}

function msg() {
    # write a mssg to std out and logdir
    # par 1 - action "L"=Large, "N" normal
    # par 2 - msg
    #
    lmsg="${3}"
    lact=${1}
    ldat=$(date +"%Y%m%d-%H%M%S")
    ltype=${2}

    case $ltype in
        E) inftxt="[ERROR]" ;;
        I) inftxt="[INFO]" ;;
        *) inftxt="[UNKKOWN:$ltype]" ;;
    esac

    if [ "${lact}" == "L" ]; then
        echo ${ldat}"** =========================================================="
        echo ${ldat}"** ${inftxt} ${lmsg}"
        echo ${ldat}"** =========================================================="
        echo " "
    else
        echo ${ldat}"** ${inftxt} ${lmsg}"
    fi
}

function exitFileExists() {
    local fn=$1
    if [[ -f ${fn} ]]; then
        msg N E "file ${fn} exists !! "
        exit 1
    fi
}

function exitFileNotExists() {
    local fn=$1
    if [[ ! -f ${fn} ]]; then
        msg N E "file ${fn} not exists !! "
        exit 1
    fi
}

function exitDirExists() {
    local fn=$1
    if [[ -d ${fn} ]]; then
        msg N E "dir ${fn} exists !! "
        exit 1
    fi
}

function exitDirNotExists() {
    local fn=$1
    local mg=$2
    if [[ ! -d ${fn} ]]; then
        msg N E "${mg}"
        exit 1
    fi
}

function checkErr() {
    local errc=$1
    local txt=$2

    if [[ $errc -ne 0 ]]; then
        msg N E "$txt ... exit"
        exit 1
    fi
}

function checkValue() {
    local fn=$1
    local txt=$2
    if [[ "X${fn}" == "X" ]]; then
        msg N E "value for  ${txt} not exists !! "
        exit 1
    fi
}

function usage() {

    echo "usage: $0 -i <install-dir> -s <software location>"
    exit 0

}

function select_data() {

    statement=$1
    resultfile=$2
    connect=$3

    if [ "X$connect" == "X" ]; then
        connect="$cconnect_to_cmdb"
    fi

    {
        sqlplus -s $connect <<EOF

          SET HEAD OFF VERIFY OFF ECHO OFF  FEEDBACK OFF
          SET TRIMSPOOL ON
          set pagesize 0
        --  SET TERMOUT OFF
          set lines 132
          set linesize 3205
          @$statement
	  exit;
EOF
    } >$resultfile
    checkErr $? "select $statement"
    rm $statement
}

function select_srctns() {

    cat <<EOF >${tmpDir}/sel$pid.sql
              SELECT lower(oracledb)||'=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(Host='||ip_address||
                     ')(PORT='||port_number||'))(CONNECT_DATA=(SERVICE_NAME='||oracle_osn||')))'
              FROM mig_database;

EOF
    select_data ${tmpDir}/sel$pid.sql ${configDir}/src_tnsnames.ora

}


function select_adbinfos_name() {

        local adbname="$1"
    local output_file="$2"

{
    sqlplus -s "/@mondbp_mig" <<EOF
SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET ECHO OFF
SET TERMOUT OFF
SET TRIMSPOOL ON
SET LINESIZE 10000

-- header row
SELECT
    'Primkey'||','||
    'db_name'||','||
    'Used_tbs'||','||
    'Alloc_tbs'||','||
    'apex_version'||','||
    'ords_version'||','||
    'maint_sched_type'||','||
    'ad'||','||
    'bkp_ret_days'||','||
    'char_set'||','||
    'ecpu'||','||
    'comp_model'||','||
    'core_count'||','||
    'size_gbs'||','||
    'adb_ed'||','||
    'db_version'||','||
    'display_name'||','||
    'scaling_enabled'||','||
    'DG_enabled'||','||
    'adb_priv_ep'||','||
    'ep_ip'||','||
    'created'||','||
    'backup_gbs'||','||
    'id'||','||
    'cl_placeid'||','||
    'apex_url'||','||
    'sqldev_url'
FROM dual;
SELECT
    to_char(adb_primkey)||','||
    adb_db_name||','||
    to_char(adb_actual_used_data_storage_size_in_tbs)||','||
    to_char(adb_allocated_storage_size_in_tbs)||','||
    adb_apex_version||','||
    adb_ords_version||','||
    adb_autonomous_maintenance_schedule_type||','||
    adb_availability_domain||','||
    to_char(adb_backup_retention_period_in_days)||','||
    adb_character_set||','||
    to_char(adb_compute_count)||','||
    adb_compute_model||','||
    to_char(adb_cpu_core_count)||','||
    to_char(adb_data_storage_size_in_gbs)||','||
    adb_database_edition||','||
    adb_db_version||','||
    adb_display_name||','||
    adb_is_auto_scaling_enabled||','||
    adb_is_data_guard_enabled||','||
    adb_private_endpoint||','||
    adb_private_endpoint_ip||','||
    substr(adb_time_created,1,10)||'_'||substr(adb_time_created,12,8)||','|| 
    to_char(adb_total_backup_storage_size_in_gbs)||','||
    adb_id||','||
    adb_cluster_placement_group_id||','||
    adb_apex_url||','||
    adb_sql_dev_web_url
FROM
    mig_infran_deployed_adb
    where lower(adb_db_name) = lower('$adbname')
    fetch first row only;

EXIT
EOF
} >$output_file
}

function select_adbinfos() {
                  
	local resultfile="$1"
	local hdrfile="${1}.hdr"

       echo "Nr,PK,ADBame,Appl,Env,OnPrem" >"$hdrfile"


    cat <<EOF >${tmpDir}/sel$pid.sql
  SELECT
    ROW_NUMBER() OVER (ORDER BY migration.mig_infran_deployed_adb.adb_db_name) || '|' ||
    migration.mig_infran_deployed_adb.adb_primkey || '|' ||
    migration.mig_infran_deployed_adb.adb_db_name || '|' ||
    NVL(replace(migration.mig_database_migration_params_v2.dbmp_app_name, ' ', '_'), '---') || '|' ||
    NVL(migration.mig_database_migration_params_v2.dbmp_env_orig, '---') || '|' ||
    NVL(migration.mig_database_migration_params_v2.dbmp_oracle_db, '---') AS csv
FROM
    migration.mig_infran_deployed_adb
LEFT JOIN
    migration.mig_database_migration_params_v2
    ON migration.mig_infran_deployed_adb.adb_db_name = migration.mig_database_migration_params_v2.dbmp_target_name
ORDER BY
    migration.mig_infran_deployed_adb.adb_db_name;
EOF
    select_data "${tmpDir}/sel$pid.sql" "$resultfile"

}




function select_zdmhosts() {

        cat << EOF >${tmpDir}/sel$pid.sql
            SELECT LISTAGG(zdm_ip_adresse, ',')
              WITHIN GROUP (ORDER BY zdm_ip_adresse)
            FROM mig_infran_deployed_zdm_server
            where ZDM_HOST_ACTIVE='Y'
;

EOF
        select_data ${tmpDir}/sel$pid.sql ${configDir}/zdmhosts.env

}


function select_zdmhosts_detail() {

    cat <<EOF >${tmpDir}/sel$pid.sql
set linesize 300
SELECT
    zdm_primkey  || '|' ||
    zdm_ip_adresse  || '|' ||
    zdm_hostname  || '|' ||
            zdm_homedir  || '|' ||
            zdm_env || '|' ||
            zdm_base || '|' ||
            zdm_zdmcli  || '|' ||
            ZDM_LAST_ANALYSED_JOBNR
        FROM
            mig_infran_deployed_zdm_server
            where ZDM_HOST_ACTIVE='Y'
;
EOF
    select_data ${tmpDir}/sel$pid.sql ${configDir}/zdmhosts_detail.env

}

function src_schemas() {

    local srcdb=$1
    local connect=$2

    cat <<EOF >${tmpDir}/sel$pid.sql

SELECT username
FROM dba_users
WHERE account_status = 'OPEN'
  AND default_tablespace NOT IN ('SYSTEM','SYSAUX',
    'SYS', 'SYSTEM', 'DBSNMP', 'OUTLN', 'ORDDATA', 'ORDSYS',
    'CTXSYS', 'XDB', 'WMSYS', 'MDSYS', 'ORDPLUGINS', 'SI_INFORMTN_SCHEMA',
    'OLAPSYS', 'EXFSYS', 'DIP', 'TSMSYS', 'FLOWS_FILES', 'APEX_PUBLIC_USER',
    'ANONYMOUS', 'XS\$NULL', 'AUDSYS', 'GSMADMIN_INTERNAL', 'GGSYS',
    'REMOTE_SCHEDULER_AGENT', 'ORACLE_OCM', 'OJVMSYS', 'SYSBACKUP',
    'SYSDG', 'SYSKM', 'LBACSYS', 'APPQOSSYS'
  )
ORDER BY username;

EOF
    select_data ${tmpDir}/sel$pid.sql ${configDir}/dbinfos/${srcdb}_schemas.env $connect

}

function test_select() {

    cat <<EOF >${tmpDir}/sel$pid.sql
          select 'cmdb-ok' from dual;
EOF
    select_data ${tmpDir}/sel$pid.sql ${tmpDir}/sel$pid.out

    if [ "$(cat ${tmpDir}/sel$pid.out)" == "cmdb-ok" ]; then
        msg N I "cmdb test OK"
    else
        msg N I "cmdb test NO-OK"
    fi
    rm ${tmpDir}/sel$pid.out
}

function select_migcluster() {
    local cl=$1
    resultFile="${configDir}/migcluster.env"

    cat <<'EOF' >"${tmpDir}/sel$pid.sql"
SET PAGESIZE 0
SET LINESIZE 1000
SET TRIMSPOOL ON
SET HEADING OFF
SET FEEDBACK OFF

WITH C AS (
  SELECT
    CASE
      WHEN CAST(TRIM(mc."MODERNEX Migration Cluster") AS VARCHAR2(100)) = 'Pilot' THEN 'Cluster 0'
      ELSE CAST(TRIM(mc."MODERNEX Migration Cluster") AS VARCHAR2(100))
    END AS CLUSTER_NAME,
    MIN(mc."MODERNEX Migration Cluster Start Date") AS START_D,
    MIN(mc."MODERNEX Migration Cluster End Date")   AS END_D,
    CASE
      WHEN CAST(TRIM(mc."MODERNEX Migration Cluster") AS VARCHAR2(100)) = 'Pilot' THEN NULL
      ELSE TO_NUMBER(REGEXP_SUBSTR(CAST(TRIM(mc."MODERNEX Migration Cluster") AS VARCHAR2(100)), '\d+'))
    END AS CL_NUM,
    CASE
      WHEN CAST(TRIM(mc."MODERNEX Migration Cluster") AS VARCHAR2(100)) = 'Pilot' THEN 1
      ELSE 0
    END AS IS_PILOT
  FROM masterdata.modernex_mig_cluster mc
  WHERE CAST(TRIM(mc."MODERNEX Migration Cluster") AS VARCHAR2(100)) LIKE 'Cl%'
     OR CAST(TRIM(mc."MODERNEX Migration Cluster") AS VARCHAR2(100)) = 'Pilot'
  GROUP BY
    CASE
      WHEN CAST(TRIM(mc."MODERNEX Migration Cluster") AS VARCHAR2(100)) = 'Pilot' THEN 'Cluster 0'
      ELSE CAST(TRIM(mc."MODERNEX Migration Cluster") AS VARCHAR2(100))
    END,
    CASE
      WHEN CAST(TRIM(mc."MODERNEX Migration Cluster") AS VARCHAR2(100)) = 'Pilot' THEN NULL
      ELSE TO_NUMBER(REGEXP_SUBSTR(CAST(TRIM(mc."MODERNEX Migration Cluster") AS VARCHAR2(100)), '\d+'))
    END,
    CASE
      WHEN CAST(TRIM(mc."MODERNEX Migration Cluster") AS VARCHAR2(100)) = 'Pilot' THEN 1
      ELSE 0
    END
),
A AS (
  SELECT
    TO_NUMBER(REGEXP_SUBSTR(TO_CHAR(dbmp_mig_cluster), '\d+')) AS CL_NUM,
    CASE WHEN TO_CHAR(dbmp_mig_cluster) = 'Pilot' THEN 1 ELSE 0 END AS IS_PILOT,
    COUNT(DISTINCT d.dbmp_primkey) AS APP_CNT
  FROM MIG_DATABASE_MIGRATION_PARAMS_v2 d
  GROUP BY
    TO_NUMBER(REGEXP_SUBSTR(TO_CHAR(dbmp_mig_cluster), '\d+')),
    CASE WHEN TO_CHAR(dbmp_mig_cluster) = 'Pilot' THEN 1 ELSE 0 END
)
SELECT
  LPAD(substr(c.CLUSTER_NAME,9,2), 2, '0')
  || '|' || c.CLUSTER_NAME
  || '|' || TO_CHAR(c.START_D, 'YYYY-MM-DD')
  || '|' || TO_CHAR(c.END_D,   'YYYY-MM-DD')
  || '|' || NVL(a.APP_CNT, 0) AS LINE
FROM C c
LEFT JOIN A a
  ON (   c.IS_PILOT = 1 AND a.IS_PILOT = 1
      OR c.IS_PILOT = 0 AND a.CL_NUM = c.CL_NUM )
ORDER BY c.IS_PILOT DESC, c.CL_NUM;

EXIT;
EOF

    select_data "${tmpDir}/sel$pid.sql" "${resultFile}"
}

function select_cpatinfos2() {

    local cl="$1"
    local resultFile="$2"

    cat <<EOF >${tmpDir}/sel$pid.sql
     SELECT distinct
      dbmp_mig_cluster || '|' ||
      dbmp_oracle_db  || '|' ||
      ip_address || '|' ||
      db_primkey || '|' ||
      oracle_sid  as cvs
     FROM
       MIG_DATABASE,
       MIG_DATABASE_MIGRATION_PARAMS_v2
       where lower(oracledb) = lower(dbmp_oracle_db)
       and dbmp_mig_cluster is not null
       and dbmp_mig_cluster = 'Cluster $cl'
;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function select_tgtociids() {

    local cl=$1
    local resultFile="$2"
    local headerFile="${resultFile}.hdr"

    # Header schreiben
    echo "ROWNUM,CLUSTER,PRIMARY_KEY,TGT_PF,TARGET_NAME,COMP-ID,ID" >"$headerFile"

    cat <<EOF >${tmpDir}/sel$pid.sql
    SELECT 
    ROW_NUMBER() OVER (ORDER BY dbmp_app_name ASC, DBMP_ENV_ORIG ASC) || '|' ||
    REPLACE(dbmp_mig_cluster, ' ', '_') || '|' ||
    dbmp_primkey || '|' ||
    dbmp_target_platform || '|' ||
    dbmp_target_name || '|' ||
    compartment_id || '|' ||
    id AS csv
FROM (
    ( SELECT 
        dbmp_app_name,
        dbmp_mig_cluster,
        dbmp_primkey,
        dbmp_target_platform,
        dbmp_target_name,
        ADB_COMPARTMENT_ID AS compartment_id,
        adb_id AS id,
        DBMP_ENV_ORIG
    FROM 
        MIG_DATABASE_MIGRATION_PARAMS_v2 dpmp
        JOIN MIG_INFRAN_DEPLOYED_ADB adb
            ON LOWER(dpmp.dbmp_target_name) = LOWER(adb.adb_db_name)
    WHERE 
        dpmp.dbmp_app_name IS NOT NULL
        AND dpmp.dbmp_mig_cluster IS NOT NULL
        AND dpmp.dpmp_target_migr_methode IS NOT NULL
        AND dpmp.dbmp_vnet IS NOT NULL
        AND dpmp.dbmp_mig_cluster = 'Cluster $cl'
	AND dpmp.dbmp_target_platform = 'ADB-S')
    UNION ALL
   ( SELECT 
        dbmp_app_name,
        dbmp_mig_cluster,
        dbmp_primkey,
        dbmp_target_platform,
        dbmp_target_name,
        COMPARTMENT_ID AS compartment_id,
        pdb.id AS id,
        DBMP_ENV_ORIG
    FROM 
        MIG_DATABASE_MIGRATION_PARAMS_v2 dpmp
        JOIN MIG_INFRAN_DEPLOYED_PDBS pdb
            ON LOWER(dpmp.dbmp_target_name) = LOWER(pdb.pdb_lnk_name)
    WHERE 
        dpmp.dbmp_app_name IS NOT NULL
        AND dpmp.dbmp_mig_cluster IS NOT NULL
        AND dpmp.dpmp_target_migr_methode IS NOT NULL
        AND dpmp.dbmp_vnet IS NOT NULL
        AND dpmp.dbmp_mig_cluster = 'Cluster $cl'
        AND dpmp.dbmp_target_platform = 'ExaDB'
        AND pdb.LIFECYCLE_STATE = 'AVAILABLE'
	AND pdb.open_mode = 'READ_WRITE')
) final_data
ORDER BY dbmp_app_name ASC, DBMP_ENV_ORIG ASC; 
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}







function select_appinfos_sel() {

    local cl=$1
    local resultFile="$2"
    local headerFile="${resultFile}.hdr"

    # Header schreiben
    echo "ROWNUM,CLUSTER,PRIMARY_KEY,APP_NAME,ENV_ORIG,ORACLE_DB,MIGRATION_METHOD,TARGET_PLATFORM,TARGET_NAME,DATACLASS,SHARED,NFS_IP,IP_ADDRESS,SHARED_RAW" >"$headerFile"

    cat <<EOF >${tmpDir}/sel$pid.sql
     SELECT
      ROW_NUMBER() OVER (ORDER BY dbmp_app_name ) || '|' ||
      replace(dbmp_mig_cluster, ' ', '_') || '|' ||
      dbmp_primkey  || '|' ||
      replace(substr(dbmp_app_name,1,20), ' ', '_') || '|' ||
      replace(DBMP_ENV_ORIG, ' ', '_') || '|' ||
      dbmp_oracle_db  || '|' ||
      replace(dpmp_target_migr_methode, ' ', '_') || '|' ||
      dbmp_target_platform || '|' ||
      dbmp_target_name || '|' ||
      replace(dbmp_dataclass, ' ', '_')  || '|' ||
      replace(substr(nvl(DBMP_SHARED,'---'),1,8), ' ', '_')  || '|' ||
      nvl(dbmp_nfs_ip, '---') || '|' ||
      IP_ADDRESS || '|' ||
      ORACLE_SID  as csv  
     FROM
       MIG_DATABASE,
       MIG_DATABASE_MIGRATION_PARAMS_v2
       where lower(oracledb) = lower(dbmp_oracle_db)
       and dbmp_app_name is not null
       and dbmp_mig_cluster is not null
       and dpmp_target_migr_methode is not null
       and dbmp_vnet is not null
       and dbmp_mig_cluster = 'Cluster $cl'
     order by dbmp_app_name asc, DBMP_ENV_ORIG asc
     ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function select_appinfos_selforcpat() {

    local cl=$1
    local resultFile="$2"
    local headerFile="${resultFile}.hdr"

    # Header schreiben
    echo "NUM,PRIMARY_KEY,APP_NAME,ENV_ORIG,ORACLE_DB,MIG_METH,TGT_PLAT,TGET" >"$headerFile"

    cat <<EOF >${tmpDir}/sel$pid.sql
     SELECT
      ROW_NUMBER() OVER (ORDER BY dbmp_app_name ) || '|' ||
      dbmp_primkey  || '|' ||
      replace(substr(dbmp_app_name,1,20), ' ', '_') || '|' ||
      replace(DBMP_ENV_ORIG, ' ', '_') || '|' ||
      dbmp_oracle_db  || '|' ||
      replace(dpmp_target_migr_methode, ' ', '_') || '|' ||
      dbmp_target_platform || '|' ||
      dbmp_target_name as cva 
     FROM
       MIG_DATABASE,
       MIG_DATABASE_MIGRATION_PARAMS_v2
       where lower(oracledb) = lower(dbmp_oracle_db)
       and dbmp_app_name is not null
       and dbmp_mig_cluster is not null
       and dpmp_target_migr_methode is not null
       and dbmp_vnet is not null
       and dbmp_mig_cluster = 'Cluster $cl'
     order by dbmp_app_name asc, DBMP_ENV_ORIG asc
     ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function select_appinfos2() {

    local cl=$1

    resultFile="${configDir}/appinfos2.env"

    resultHeaderFile="${configDir}/appinfos2.env.hdr"

    echo "ROWNUM,CLUSTER,PRIMARY_KEY,APP_NAME,ENV_ORIG,ORACLE_DB,MIGRATION_METHOD,TARGET_PLATFORM,TARGET_NAME,DATACLASS,SHARED,NFS_IP,IP_ADDRESS,SHARED_RAW" >"$resultHeaderFile"

    cat <<EOF >${tmpDir}/sel$pid.sql
     SELECT
      ROW_NUMBER() OVER (ORDER BY dbmp_app_name ) || '|' ||
      substr(dbmp_mig_cluster,9,2) || '|' ||
      dbmp_primkey  || '|' ||
      dbmp_app_name || '|' ||
      DBMP_ENV_ORIG || '|' ||
      dbmp_oracle_db  || '|' ||
      substr(dpmp_target_migr_methode,1,3)||'_'||substr(dpmp_target_migr_methode,instr(dpmp_target_migr_methode,' ')+1,3) || '|' ||
      dbmp_target_platform || '|' ||
      dbmp_target_name || '|' ||
      dbmp_dataclass  || '|' ||
      substr(nvl(DBMP_SHARED,'---'),1,8)  || '|' ||
      nvl(dbmp_nfs_ip, '---') || '|' ||
      IP_ADDRESS || '|' ||
      DBMP_SHARED  as csv
     FROM
       MIG_DATABASE,
       MIG_DATABASE_MIGRATION_PARAMS_v2
       where lower(oracledb) = lower(dbmp_oracle_db)
       and dbmp_app_name is not null
       and dbmp_mig_cluster is not null
       and dpmp_target_migr_methode is not null
       and dbmp_vnet is not null
       and dbmp_mig_cluster = 'Cluster $cl'
     order by dbmp_app_name asc, DBMP_ENV_ORIG asc
     ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}
function select_cpatschematas() {

    local resultFile="$1"

    resultHeaderFile="${configDir}/appinfos2.env.hdr"

    echo "PRIMARY_KEY,SCHEMA" >"$resultHeaderFile"

    cat <<EOF >${tmpDir}/sel$pid.sql
     SELECT
      dbmp_primkey  || '|' ||
      DBMP_SHARED  as csv
     FROM
       MIG_DATABASE,
       MIG_DATABASE_MIGRATION_PARAMS_v2
       where lower(oracledb) = lower(dbmp_oracle_db)
       and dbmp_shared is not null
     ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}
function select_ociinfos() {

    local resultFile=$1
    local headerFile="${resultFile}.hdr"

    echo "Typ,CompID,DbID,CDBid,DBName,CDBName" >"$headerFile"

    cat <<EOF >${tmpDir}/sel$pid.sql
SELECT
    'PDB'
     ||'|'||migration.mig_infran_deployed_pdbs.compartment_id 
     ||'|'||migration.mig_infran_deployed_pdbs.id            
     ||'|'||migration.mig_infran_deployed_pdbs.container_database_id 
     ||'|'||migration.mig_infran_deployed_pdbs.pdb_name 
     ||'|'||migration.mig_infran_deployed_exadb.db_name 
     ||'|'||migration.mig_infran_deployed_exadb.db_name 
     ||'_'||migration.mig_infran_deployed_pdbs.pdb_name as csv
FROM     migration.mig_infran_deployed_exadb,
         migration.mig_infran_deployed_pdbs
where  migration.mig_infran_deployed_pdbs.lifecycle_state = 'AVAILABLE'
and    migration.mig_infran_deployed_exadb.db_id = migration.mig_infran_deployed_pdbs.container_database_id
UNION
SELECT
    'ADB'
     ||'|'||adb_compartment_id 
     ||'|'||adb_id 
     ||'|----'
     ||'|'||adb_db_name  
     ||'|----' 
     ||'|'||adb_db_name  as csv
FROM
    mig_infran_deployed_adb;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}
}



function select_appinfos_all() {

    local resultFile=$1
    local headerFile="${resultFile}.hdr"

    echo "CLUSTER_ID,PRIMARY_KEY,CLUSTER,APP_NAME,ENV_ORIG,ORACLE_DB,MIGRATION_METHOD,TARGET_PLATFORM,TARGET_NAME,DATACLASS,SHARED,NFS_IP,IP_ADDRESS,SHARED_RAW" >"$headerFile"

    cat <<EOF >${tmpDir}/sel$pid.sql
    SELECT
      'CL_'|| lpad(substr(dbmp_mig_cluster, 9, 2),2,'0') || '|' ||
      dbmp_primkey  || '|' ||
      replace(dbmp_mig_cluster, ' ', '_') || '|' ||
      replace(substr(dbmp_app_name,1,20), ' ', '_') || '|' ||
      replace(DBMP_ENV_ORIG, ' ', '_') || '|' ||
      dbmp_oracle_db  || '|' ||
      replace(dpmp_target_migr_methode, ' ', '_') || '|' ||
      dbmp_target_platform || '|' ||
      dbmp_target_name || '|' ||
      replace(dbmp_dataclass, ' ', '_')  || '|' ||
      replace(substr(nvl(DBMP_SHARED,'---'),1,8), ' ', '_')  || '|' ||
      nvl(dbmp_nfs_ip, '---') || '|' ||
      IP_ADDRESS || '|' ||
      ORACLE_SID  as csv
     FROM
       MIG_DATABASE,
       MIG_DATABASE_MIGRATION_PARAMS_v2
       where lower(oracledb) = lower(dbmp_oracle_db)
       and dbmp_app_name is not null
       and dbmp_mig_cluster is not null
       and dpmp_target_migr_methode is not null
       and dbmp_vnet is not null
       and dbmp_mig_cluster like 'Cluster%'
     order by lpad(substr(dbmp_mig_cluster, 9, 2),2,'0'),dbmp_app_name asc, DBMP_ENV_ORIG asc
     ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}
}

function select_appinfos_pk() {

    local pk=$1
    local resultFile=$2
    local headerFile="${resultFile}.hdr"

    echo "TPLAT,TNAME,MMETH,TALIS,ODB,ENV,CLASS,VNET,APP,ORIG,SHR,TALIS2,CLUST,PRIMK,TENV,NFSIP,NFSNM,NFSSH,NFSMP,DNS,IP" >"$headerFile"

    cat <<EOF >${tmpDir}/sel$pid.sql
     SELECT
      dbmp_target_platform || '|' ||
      dbmp_target_name || '|' ||
      dpmp_target_migr_methode || '|' ||
      dbmp_test_tns_alias || '|' ||
      dbmp_oracle_db  || '|' ||
      dbmp_env  || '|' ||
      dbmp_dataclass  || '|' ||
      dbmp_vnet  || '|' ||
      dbmp_app_name || '|' ||
      DBMP_ENV_ORIG || '|' ||
      DBMP_SHARED || '|' ||
      dbmp_target_tns_alias || '|' ||
      dbmp_mig_cluster || '|' ||
      dbmp_primkey  || '|' ||
      dbmp_target_env  || '|' ||
      dbmp_nfs_ip  || '|' ||
      dbmp_nfs_name  || '|' ||
      dbmp_nfs_share  || '|' ||
      DBMP_NFS_MP  || '|' ||
      DNS_NAME  || '|' ||
      IP_ADDRESS AS csv_output
     FROM
       MIG_DATABASE,
       MIG_DATABASE_MIGRATION_PARAMS_v2
      where lower(oracledb) = lower(dbmp_oracle_db)
       and dbmp_primkey = $1
       FETCH FIRST ROW ONLY;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function select_appinfos() {

    resultFile="${configDir}/appinfos.env"
    headerFile="${resultFile}.hdr"

    echo "TPLAT,TNAME,MMETH,TALIS,ODB,ENV,CLASS,VNET,APP,ORIG,SHR,TALS2,CLUST,PRIMK,TENV,NFSIP,NFSNM,NFSSH,NFSMP,DNS,IP" >"$headerFile"

    cat <<EOF >${tmpDir}/sel$pid.sql
     SELECT
      dbmp_target_platform || '|' ||
      dbmp_target_name || '|' ||
      dpmp_target_migr_methode || '|' ||
      dbmp_test_tns_alias || '|' ||
      dbmp_oracle_db  || '|' ||
      dbmp_env  || '|' ||
      dbmp_dataclass  || '|' ||
      dbmp_vnet  || '|' ||
      dbmp_app_name || '|' ||
      DBMP_ENV_ORIG || '|' ||
      DBMP_SHARED || '|' ||
      dbmp_target_tns_alias || '|' ||
      dbmp_mig_cluster || '|' ||
      dbmp_primkey  || '|' ||
      dbmp_target_env  || '|' ||
      dbmp_nfs_ip  || '|' ||
      dbmp_nfs_name  || '|' ||
      dbmp_nfs_share  || '|' ||
      DBMP_NFS_MP  || '|' ||
      DNS_NAME  || '|' ||
      IP_ADDRESS AS csv_output
     FROM
       MIG_DATABASE,
       MIG_DATABASE_MIGRATION_PARAMS_v2
       where lower(oracledb) = lower(dbmp_oracle_db)
       and dbmp_app_name is not null
       and dbmp_mig_cluster is not null
       and dpmp_target_migr_methode is not null
       and dbmp_vnet is not null
     order by dbmp_app_name asc, DBMP_ENV_ORIG asc
     ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function select_cpatinfos() {

    resultFile="${configDir}/cpat_infos.csv"

    cat <<EOF >${tmpDir}/sel$pid.sql

        SELECT
          IP_ADDRESS||','
          ||port_number||','
          ||oracle_osn||','
          ||oracledb||','
          ||db_primkey
       FROM
       mig_database
       where dns_name is not null
        and cpat_flag = 'Y'
       ;

EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}
}

function select_nfs() {

    resultFile="${configDir}/deployed_nfs.env"

    cat <<EOF >${tmpDir}/sel$pid.sql
   SELECT 
    LPAD(TO_CHAR(nfs_primkey), 2, '0') || ',' ||
    nfs_name || ',' ||
    nfs_art || ',' ||
    nfs_for_platform || ',' ||
    nfs_for_environment || ',' ||
    nfs_for_confidential || ',' ||
    nfs_export_name || ',' ||
    nfs_ip_adr AS csv_output
FROM
    mig_infran_deployed_nfs
order by 1;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}
}


function select_nfs2() {

    resultFile="${configDir}/deployed_nfs2.env"


    echo "Name,Pltf,Exp,Ip" > "${resultFile}.hdr"

    cat <<EOF >${tmpDir}/sel$pid.sql
   SELECT distinct
    nfs_name || ',' ||
    nfs_for_platform || ',' ||
    nfs_export_name || ',' ||
    nfs_ip_adr AS csv_output
FROM
    mig_infran_deployed_nfs
order by 1;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}
}


function select_miginfos() {

    local sdb=$1
    local adb=$2

    resultFile="${configDir}/dbinfos/${sdb}_${adb}.env"

    cat <<EOF >${tmpDir}/sel$pid.sql
    SELECT
      DBMP_TARGET_PLATFORM  || ',' ||
      DBMP_TARGET_NAME  || ',' ||
      DPMP_TARGET_MIGR_METHODE  || ',' ||
      DBMP_TEST_DNS_ALIAS AS csv_output
    FROM
       MIG_DATABASE_MIGRATION_PARAMS_v2
    where DBMP_TARGET_NAME = '$adb'
    and   DBMP_ORACLE_DB   = '$sdb'
    ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function select_zdmmiginfo_phases() {

    local hst=$1
    local jnr=$2

    resultFile="${configDir}/zdmmiginfos_ph.env"
    headerFile="${resultFile}.hdr"

    echo "HOST,JOBNR,LFNR,PHASE,RTSEC,RTFMT,STAT" >"$headerFile"

    cat <<EOF >${tmpDir}/sel$pid.sql

SELECT
    zdm_host || '|' ||
    zdm_job_nr || '|' ||
    zdm_lfnr_job || '|' ||
    zdm_phase || '|' ||
    zdm_phase_rt_sec || '|' ||
    zdm_phase_rt_fmt || '|' ||
    zdm_phase_status  AS csv_line
FROM
    mig_zdm_run_phase
    where zdm_host = '$hst'
    and zdm_job_nr = '$jnr' 
order by
    zdm_host,
    zdm_job_nr,
    lpad(zdm_lfnr_job, 3,'0')  asc
;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}
}

function select_zdmmiginfo_phases_chk() {

    local hst=$1
    local jnr=$2

    resultFile="${configDir}/zdmmiginfos_ph_chk.env"
    headerFile="${resultFile}.hdr"

    echo "HOST,JOBNR,LFNR,PHASE,RTSEC,RTFMT,STAT" >"$headerFile"

    cat <<EOF >${tmpDir}/sel$pid.sql

SELECT
    zdm_host || '|' ||
    zdm_job_nr || '|' ||
    zdm_lfnr_job || '|' ||
    zdm_phase || '|' ||
    zdm_phase_rt_sec || '|' ||
    zdm_phase_rt_fmt || '|' ||
    zdm_phase_status  AS csv_line
FROM
    mig_zdm_run_phase
    where zdm_phase_status like 'TDB%'
order by
    zdm_host,
    zdm_job_nr,
    lpad(zdm_lfnr_job, 3,'0')  asc
;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}
}

function select_zdmmiginfo2() {

    local tgtdb=$1
    local wherecl="1=1"

    if [ "X$tgtdb" != "X" ]; then
	    wherecl=$(echo "zdm_tgt_dbname like &%${tgtdb}%&"| tr "&" "'")
    fi

    resultFile="${configDir}/zdmmiginfos2.env"

    headerFile="${resultFile}.hdr"

    echo "START,HOST,JOBNR,SRCDB,TYPE,STAT,ENDE,RUN,TRGDB" >"$headerFile"

    cat <<EOF >${tmpDir}/sel$pid.sql

SELECT
    zdm_job_start || '|' ||
    zdm_host || '|' ||
    zdm_job_nr || '|' ||
    zdm_source_db || '|' ||
    zdm_job_type || '|' ||
    zdm_job_status || '|' ||
    zdm_job_ende || '|' ||
    zdm_job_runtime || '|' ||
    substr(zdm_tgt_dbname,instr(zdm_tgt_dbname,'_')+1,20)  AS csv_line
   FROM mig_zdm_run
   where ${wherecl}
ORDER BY
    zdm_job_start desc,
    zdm_host desc,
    zdm_job_nr DESC
    fetch first 120 rows only
    ;
EOF

    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function select_zdmmiginfo() {

    local db=$1

    resultFile="${configDir}/zdmmiginfos.env"

    headerFile="${resultFile}.hdr"

    echo "START,HOST,JOBNR,SRCDB,TYPE,STAT,ENDE,RUN,ODB,SID,NODE,MART,MKIND,SHOST,SDB,TRGDB" >"$headerFile"

    cat <<EOF >${tmpDir}/sel$pid.sql

SELECT
    zdm_job_start || '|' ||
    zdm_host || '|' ||
    zdm_job_nr || '|' ||
    zdm_source_db || '|' ||
    zdm_job_type || '|' ||
    zdm_job_status || '|' ||
    zdm_job_ende || '|' ||
    zdm_job_runtime || '|' ||
    zdm_oracledb || '|' ||
    zdm_src_sid || '|' ||
    zdm_src_node || '|' ||
    zdm_migration_art || '|' ||
    zdm_migration_kind || '|' ||
    zdm_src_host || '|' ||
    zdm_src_dbname || '|' ||
    substr(zdm_tgt_dbname,instr(zdm_tgt_dbname,'_')+1,20)  AS csv_line
   FROM mig_zdm_run
ORDER BY
    zdm_job_start desc,
    zdm_host desc,
    zdm_job_nr DESC
    fetch first 120 rows only 
    ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function select_dbinfos() {

    local db=$1

    whereclause="where 1=1"
    resultFile="${configDir}/dbinfos.env"
    if [ "X$db" != "X" ]; then
        whereclause=$(echo "where lower(oracledb) = lower(%$db%)" | tr "%" "'")
        resultFile="${configDir}/dbinfos/${db}.env"
    fi

    headerFile="${resultFile}.hdr"
    echo "ODBID,VNID,CLUST,VNSDD,CONF,DNS,IP,PORT,OSN,OSNAL,DBACC,DBUSR,SCAT,PRIMK,PILOT,AZSUB,AZSBN,AZNW,AZNAM,NRIP,CLID,DBVER,SGA,PGA,ALLOC,CORES,ECPUS,CHAR" >"$headerFile"

    cat <<EOF >${tmpDir}/sel$pid.sql
SELECT
    oracledb || ',' ||
    vn_id || ',' ||
    cluster_name || ',' ||
    vn_sdd_vname || ',' ||
    confidential || ',' ||
    dns_name || ',' ||
    ip_address || ',' ||
    port_number || ',' ||
    oracle_osn || ',' ||
    oracle_osn_alias || ',' ||
    dbaccess || ',' ||
    dbuser || ',' ||
    service_category || ',' ||
    db_primkey || ',' ||
    in_pilot || ',' ||
    vn_az_subscr || ',' ||
    vn_az_subn || ',' ||
    vn_az_nw || ',' ||
    vn_az_name || ',' ||
    vn_nr_ips || ',' ||
    cl_id || ',' ||
    db_version || ',' ||
    sga_gb || ',' ||
    pga_gb || ',' ||
    alloc_gb || ',' ||
    anz_cores || ',' ||
    anz_ecpus || ',' ||
    ora_charset AS csv_output
FROM
    v_mig_premigration_infos
    $whereclause
    fetch first row only
    ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function select_srchostinfos() {

    resultFile="${configDir}/srchostinfos.env"

    cat <<EOF >${tmpDir}/sel$pid.sql
SELECT
    distinct dns_name || ',' ||
    ip_address AS csv_output
FROM
    v_mig_premigration_infos
    where dns_name is not null
    ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

    resultFile="${configDir}/srchostip.env"

    cat <<EOF >${tmpDir}/sel$pid.sql
SELECT
    distinct
    ip_address||'/32' AS csv_output
FROM
    v_mig_premigration_infos
    where ip_address is not null
    ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function select_srcdbnames() {

    resultFile="${configDir}/srcdbnames.env"

    cat <<EOF >${tmpDir}/sel$pid.sql
SELECT
    distinct
    lower(oracledb ) AS csv_output
FROM
    mig_database
    order by lower(oracledb)
    ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function select_testcases() {

    resultFile="${configDir}/testcases.csv"

    cat <<EOF >${tmpDir}/sel$pid.sql
     SELECT NR||':'||code||':'||text||':'||log_off||':'||log_on||':'||phy_off||':'||phy_on
     FROM MIG_PREMIG_TESTCASES
     order by nr ;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

#---------------------------------------------------

function update_miginfo() {

    local primkey=$1
    local migcluster="$2"

    resultFile="/tmp/$(whoami)_update.log"

    cat <<EOF >${tmpDir}/sel$pid.sql

     update mig_database_migration_params_v2
     set dbmp_mig_cluster = '$migcluster'
     where dbmp_primkey = $primkey;
     commit;

EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}
}

function update_cpat() {

    local primkey=$1
    local schemas="$2"

    resultFile="/tmp/$(whoami)_update.log"

    cat <<EOF >${tmpDir}/sel$pid.sql

     update mig_database_migration_params_v2
     set dbmp_shared = '$schemas'
     where dbmp_primkey = $primkey;
     commit;
     exit;
EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}
}

function update_nfs() {

    local primkey=$1
    local nfskey=$2

    resultFile="/tmp/$(whoami)_updatenfs.log"

    cat <<EOF >${tmpDir}/sel$pid.sql
     
     set serveroutput on;
     declare
       v_nfsrec  MIG_INFRAN_DEPLOYED_NFS%rowtype;
     begin

            dbms_output.put_line ('$primkey');
            dbms_output.put_line ('$nfskey');
        
         if '$nfskey' = '0' then
                
            update mig_database_migration_params_v2
            set 
               DBMP_NFS_IP    = NULL,
               DBMP_NFS_NAME  = NULL,
               DBMP_NFS_SHARE = NULL,
	       DBMP_NFS_MP    = NULL
               where dbmp_primkey = $primkey;

	 else 
            select * into v_nfsrec
            from MIG_INFRAN_DEPLOYED_NFS
            where nfs_primkey = $nfskey;
             
            update mig_database_migration_params_v2
            set 
               DBMP_NFS_IP    = v_nfsrec.NFS_IP_ADR,
               DBMP_NFS_NAME  = v_nfsrec.NFS_NAME,
               DBMP_NFS_SHARE = v_nfsrec.NFS_EXPORT_NAME,
	       DBMP_NFS_MP    = substr(v_nfsrec.NFS_NAME,1,instr(v_nfsrec.NFS_NAME,'.'))
               where dbmp_primkey = $primkey;
         end if;
         commit;
         dbms_output.put_line ('DONE');
    exception
        when others then
            dbms_output.put_line ('ERROR');
            dbms_output.put_line (SQLERRM);
    end;
    /
    exit;

EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}
}

function refresh_mig() {

    resultFile="/tmp/miginfo_refresh.log"

    cat <<EOF >${tmpDir}/sel$pid.sql
     set serveroutput on;
     select 'Start:'||TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') AS current_time  from dual;
     exec P_UPDATE_MIGINFOS;
     select 'finish:|'||TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') AS current_time from dual;
     commit;

EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function insert_testresult() {

    local oraledb=$1
    local testnr=$2
    local result=$3
    local info=$4

    resultFile="/tmp/$(whoami)_insert.log"

    cat <<EOF >${tmpDir}/sel$pid.sql

     INSERT INTO MIG_PREMIG_TESTCASES_LOG 
	 VALUES (s1.nextval, systimestamp, '$oraledb', '$testnr', '$result', '$info','$(whoami)');
     commit;

EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

function insert_nfs_server() {

    local ip=$1
    local name=$2
    local platform=$3
    local share=$4

    resultFile="/tmp/$(whoami)_insert.log"

    cat <<EOF >${tmpDir}/sel$pid.sql

     delete from mig_infran_deployed_nfs where nfs_ip_adr='$ip';

     INSERT INTO mig_infran_deployed_nfs
         VALUES (s1.nextval, '$name', 'NFS', '$platform', 'X', 'X', '$share','$ip');
     commit;

EOF
    select_data ${tmpDir}/sel$pid.sql ${resultFile}

}

######################################################
# main
######################################################

# --- Default values for optional flags ---

connect_to="V1"   # for -c

# --- Parse optional named arguments using getopts ---
while getopts "c:" opt; do
    case "$opt" in
        c) connect_to="$OPTARG" ;;
        *) echo "Invalid option"; exit 1 ;;
    esac
done

case $connect_to in
	V2) cconnect_to_cmdb="/@mondbp_migv2" ;;
 	 *) cconnect_to_cmdb="/@mondbp_mig"   ;;
esac 

shift $((OPTIND - 1))

scmd=$1
par2=$2
par3=$3
par4=$4
par5=$5
es="-s"

#echo "conn=$cconnect_to_cmdb pcmd=$scmd p=$par2 $par3 $par4 $par5"



if [ ! -z $6 ]; then
    es=""
fi

case $scmd in

    testcmdb) 			test_select ;;
    testcases) 			select_testcases ;;
    zdmhosts) 			select_zdmhosts ;;
    zdmhosts_detail) 		select_zdmhosts_detail ;;
    srctns)	 		select_srctns ;;
    storeres) 			insert_testresult "$par2" "$par3" "$par4" "$par5" ;;
    update_miginfo)		update_miginfo "$par2" "$par3" ;;
    update_cpat)	 	update_cpat "$par2" "$par3" ;;
    update_nfs) 		update_nfs "$par2" "$par3" ;;
    dbinfos) 			select_dbinfos $par2 ;;
    cpatschematas)	 	select_cpatschematas $par2 ;;
    migdbinfos) 		select_zdmmiginfo $par2 ;;
    migdbinfos2) 		select_zdmmiginfo2 $par2 $par3 ;;
    migdbinfos_ph_chk)	 	select_zdmmiginfo_phases_chk ;;
    migdbinfos_ph) 		select_zdmmiginfo_phases $par2 $par3 ;;
    cpatinfos) 			select_cpatinfos ;;
    miginfos) 			select_miginfos $par2 $par3 ;;
    migcluster) 		select_migcluster ;;
    appinfos) 			select_appinfos ;;
    appinfos_pk) 		select_appinfos_pk "$par2" "$par3" ;;
    appinfos2) 			select_appinfos2 "$par2" ;;
    ociinfos) 			select_ociinfos "$par2" ;;
    appinfos_selforcpat) 	select_appinfos_selforcpat "$par2" "$par3" ;;
    appinfos_sel) 		select_appinfos_sel "$par2" "$par3" ;;
    tgtociids)   		select_tgtociids "$par2" "$par3" ;;
    appinfos_all)	 	select_appinfos_all "$par2" ;;
    adbinfos)  			select_adbinfos "$par2" ;;
    adbinfos_name)		select_adbinfos_name "$par2" "$par3" ;;
    cpatinfos2) 		select_cpatinfos2 "$par2" "$par3" ;;
    srcdbnames) 		select_srcdbnames ;;
    srchostinfos) 		select_srchostinfos ;;
    src_schemas) 		src_schemas $par2 $par3 ;;
    refresh_mig) 		refresh_mig ;;
    select_nfs) 		select_nfs ;;
    select_nfs2) 		select_nfs2 ;;
    store_nfs) 			insert_nfs_server "$par2" "$par3" "$par4" "$par5" ;;
    *) echo "$scmd not implemented " ;;
esac
exit
