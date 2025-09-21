#!/bin/bash
#
#------------------------------#

#. ./01_load_env.sh
#dbpw=$(./90_get_pw.sh $dbuser $dbconnect)

#mdbuser=${dbuser}
#mdbpw=${dbpw}
#^mdbconnect=${dbconnect}

#  "ocid1.compartment.oc1..aaaaaaaaueltojv7bgpmgtvzvwxxdlvsl6cedwbtvwsvwing6clg4o5cuquq"
#  "ocid1.compartment.oc1..aaaaaaaa7ptvflundl2vqwcl4yucstnls7fx3ctnlw26gfwmyckqzuuxpbza"

source /mount/sa4zdmfs/zdmconfig/premigration/premigration.env

# List of specific compartments to process
#COMPARTMENTS_TO_PROCESS=(
#"ocid1.compartment.oc1..aaaaaaaaueltojv7bgpmgtvzvwxxdlvsl6cedwbtvwsvwing6clg4o5cuquq"
#"ocid1.compartment.oc1..aaaaaaaa7ptvflundl2vqwcl4yucstnls7fx3ctnlw26gfwmyckqzuuxpbza"
#"ocid1.compartment.oc1..aaaaaaaarrb6ikdpg7fbhbeqziehqcde4h4dugpmk7hjzfxd3sywrou7hnlq"
#"ocid1.compartment.oc1..aaaaaaaa7ybosg2uiitghvyprgy65ecnh2xnksxb4wh6k3je7zwhh52omsla"
#)

COMPARTMENTS_TO_PROCESS=(
  "ocid1.compartment.oc1..aaaaaaaa7ybosg2uiitghvyprgy65ecnh2xnksxb4wh6k3je7zwhh52omsla"
)
workdir=/tmp/3005752
#workdir=/tmp/$$
exainfra_dat=$workdir/exainfra.txt
exainfra_ids=$workdir/exainfra.ids
exacluster_dat=$workdir/exacluster.txt
exacluster_ids=$workdir/exacluster.ids
adb_dat=$workdir/adb.txt
adb_ids=$workdir/adb.ids

if [ ! -d $workdir ]; then
  mkdir $workdir
fi

#------------------------------------
function msg() {
  # write a mssg to std out and logdir
  # par 1 - action "L"=Large, "N" normal
  # par 2 - msg
  lmsg=${2}
  lact=${1}
  ldat=$(date +"%Y%m%d-%H%M%S")

  if [ "${lact}" == "L" ]; then
    echo ${ldat}"**  =========================================================="
    echo ${ldat}"**  "${lmsg}
    echo ${ldat}"**  =========================================================="
    echo " "
  else
    echo ${ldat}"** "${lmsg}
  fi
}

function display_adb_detail() {

  adb_id=$1
  data_actual_used_data_storage_size_in_tbs=$(echo "$adb_detail" | jq -r '.data["actual-used-data-storage-size-in-tbs"]')
  data_allocated_storage_size_in_tbs=$(echo "$adb_detail" | jq -r '.data["allocated-storage-size-in-tbs"]')
  data_apex_version=$(echo "$adb_detail" | jq -r '.data["apex-details"]["apex-version"]')
  data_ords_version=$(echo "$adb_detail" | jq -r '.data["apex-details"]["ords-version"]')
  data_are_primary_whitelisted_ips_used=$(echo "$adb_detail" | jq -r '.data["are-primary-whitelisted-ips-used"]')
  data_auto_refresh_frequency_in_seconds=$(echo "$adb_detail" | jq -r '.data["auto-refresh-frequency-in-seconds"]')
  data_auto_refresh_point_lag_in_seconds=$(echo "$adb_detail" | jq -r '.data["auto-refresh-point-lag-in-seconds"]')
  data_autonomous_container_database_id=$(echo "$adb_detail" | jq -r '.data["autonomous-container-database-id"]')
  data_autonomous_maintenance_schedule_type=$(echo "$adb_detail" | jq -r '.data["autonomous-maintenance-schedule-type"]')
  data_availability_domain=$(echo "$adb_detail" | jq -r '.data["availability-domain"]')
  data_backup_retention_period_in_days=$(echo "$adb_detail" | jq -r '.data["backup-retention-period-in-days"]')
  data_character_set=$(echo "$adb_detail" | jq -r '.data["character-set"]')
  data_cluster_placement_group_id=$(echo "$adb_detail" | jq -r '.data["cluster-placement-group-id"]')
  data_compartment_id=$(echo "$adb_detail" | jq -r '.data["compartment-id"]')
  data_compute_count=$(echo "$adb_detail" | jq -r '.data["compute-count"]')
  data_compute_model=$(echo "$adb_detail" | jq -r '.data["compute-model"]')
  data_apex_url=$(echo "$adb_detail" | jq -r '.data["connection-urls"]["apex-url"]')
  data_sql_dev_web_url=$(echo "$adb_detail" | jq -r '.data["connection-urls"]["sql-dev-web-url"]')
  data_cpu_core_count=$(echo "$adb_detail" | jq -r '.data["cpu-core-count"]')
  data_data_safe_status=$(echo "$adb_detail" | jq -r '.data["data-safe-status"]')
  data_data_storage_size_in_gbs=$(echo "$adb_detail" | jq -r '.data["data-storage-size-in-gbs"]')
  data_database_edition=$(echo "$adb_detail" | jq -r '.data["database-edition"]')
  data_db_version=$(echo "$adb_detail" | jq -r '.data["db-version"]')
  data_id=$(echo "$adb_detail" | jq -r '.data["id"]')
  data_is_auto_scaling_enabled=$(echo "$adb_detail" | jq -r '.data["is-auto-scaling-enabled"]')
  data_is_data_guard_enabled=$(echo "$adb_detail" | jq -r '.data["is-data-guard-enabled"]')
  data_subnet_id=$(echo "$adb_detail" | jq -r '.data["subnet-id"]')
  data_private_endpoint=$(echo "$adb_detail" | jq -r '.data["private-endpoint"]')
  data_private_endpoint_ip=$(echo "$adb_detail" | jq -r '.data["private-endpoint-ip"]')
  data_time_created=$(echo "$adb_detail" | jq -r '.data["time-created"]')
  data_total_backup_storage_size_in_gbs=$(echo "$adb_detail" | jq -r '.data["total-backup-storage-size-in-gbs"]')
  data_nsg_id=$(echo "$adb_detail" | jq -r '.data."nsg-ids"[0]')
  data_high_connect=$(echo "$adb_detail" | jq -r '.data["connection-strings"]["profiles"]' | grep 1521 | grep -i high | cut -d":" -f2 | tr -d '"')

  subnet_detail=$(oci network subnet get --subnet-id $data_subnet_id)
  vcn_id=$(echo "$subnet_detail" | jq -r '.data["vcn-id"]')

  res_detail=$(oci network vcn-dns-resolver-association get --vcn-id $vcn_id)
  res_id==$(echo "$res_detail" | jq -r '.data["dns-resolver-id"]')

  COL_WIDTH=45

  printf "%-*s : %s\n" $COL_WIDTH "Display Name" "$data_display_name"
  printf "%-*s : %s\n" $COL_WIDTH "Database ID" "$data_id"
  printf "%-*s : %s\n" $COL_WIDTH "Actual Used Storage (TB)" "$data_actual_used_data_storage_size_in_tbs"
  printf "%-*s : %s\n" $COL_WIDTH "Allocated Storage (TB)" "$data_allocated_storage_size_in_tbs"
  printf "%-*s : %s\n" $COL_WIDTH "APEX Version" "$data_apex_version"
  printf "%-*s : %s\n" $COL_WIDTH "ORDS Version" "$data_ords_version"
  printf "%-*s : %s\n" $COL_WIDTH "Primary Whitelisted IPs Used" "$data_are_primary_whitelisted_ips_used"
  printf "%-*s : %s\n" $COL_WIDTH "Maintenance Schedule Type" "$data_autonomous_maintenance_schedule_type"
  printf "%-*s : %s\n" $COL_WIDTH "Availability Domain" "$data_availability_domain"
  printf "%-*s : %s\n" $COL_WIDTH "Backup Retention Period (days)" "$data_backup_retention_period_in_days"
  printf "%-*s : %s\n" $COL_WIDTH "Character Set" "$data_character_set"
  printf "%-*s : %s\n" $COL_WIDTH "Compartment ID" "$data_compartment_id"
  printf "%-*s : %s\n" $COL_WIDTH "Compute Count" "$data_compute_count"
  printf "%-*s : %s\n" $COL_WIDTH "CPU Core Count" "$data_cpu_core_count"
  printf "%-*s : %s\n" $COL_WIDTH "Data Storage Size (GB)" "$data_data_storage_size_in_gbs"
  printf "%-*s : %s\n" $COL_WIDTH "Database Edition" "$data_database_edition"
  printf "%-*s : %s\n" $COL_WIDTH "Database Name" "$data_db_name"
  printf "%-*s : %s\n" $COL_WIDTH "Database Version" "$data_db_version"
  printf "%-*s : %s\n" $COL_WIDTH "Auto Scaling Enabled" "$data_is_auto_scaling_enabled"
  printf "%-*s : %s\n" $COL_WIDTH "Data Guard Enabled" "$data_is_data_guard_enabled"
  printf "%-*s : %s\n" $COL_WIDTH "Subnet ID" "$data_subnet_id"
  printf "%-*s : %s\n" $COL_WIDTH "vcn    ID" "$vcn_id"
  printf "%-*s : %s\n" $COL_WIDTH "vcnres ID" "$res_id"
  printf "%-*s : %s\n" $COL_WIDTH "Private Endpoint" "$data_private_endpoint"
  printf "%-*s : %s\n" $COL_WIDTH "Private Endpoint IP" "$data_private_endpoint_ip"
  printf "%-*s : %s\n" $COL_WIDTH "Time Created" "$data_time_created"
  printf "%-*s : %s\n" $COL_WIDTH "Total Backup Storage (GB)" "$data_total_backup_storage_size_in_gbs"

  display_nsg_rules $data_nsg_id

  printf "%-30s: %s\n" " " " "
}

function download_wallet() {

  local adb_id=$1

  cat << EOF > /tmp/w.json
{
 "autonomousDatabaseId": "$adb_id",
 "file": "/tmp/wallet_${data_db_name}_regional.zip",
 "generateType": "ALL",
 "isRegional": true,
 "password": "$adbadmin"
}
EOF

  #set -x
  oci db autonomous-database generate-wallet --from-json file:///tmp/w.json

  curdir=$(pwd)
  cd /tmp
  mkdir ${data_db_name}
  cd ${data_db_name}

  unzip /tmp/wallet_${data_db_name}_regional.zip
  data_tp_connect=$(cat ./tnsnames.ora | grep -i "${data_db_name}_tp ")
  cd ..
  rm -rf /tmp/${data_db_name}
  cd $curdir
  mv /tmp/wallet_${data_db_name}_regional.zip ../configfiles

  echo "$data_tp_connect" | tr -d " " > ../configfiles/tns_${data_db_name}.ora
  sed -i "s/$data_private_endpoint/$data_private_endpoint_ip/g" ../configfiles/tns_${data_db_name}.ora
  sed -i "s/_tp//" ../configfiles/tns_${data_db_name}.ora

  #	mkstore -wrl $TNS_ADMIN  -deleteCredential  ${data_db_name}_tP << EOF
  #$walletpw
  #EOF

  #	mkstore -wrl $TNS_ADMIN  -createCredential ${data_db_name}_tP admin << EOF
  #$adbadmin
  #$adbadmin
  #$walletpw
  #EOF

  cat $TNS_ADMIN/tnsnames.ora | grep -v "^${data_db_name}" > /tmp/tns
  mv /tmp/tns $TNS_ADMIN/tnsnames.ora
  cat ../configfiles/tns_${data_db_name}.ora >> $TNS_ADMIN/tnsnames.ora
}

function display_nsg_rules() {

  local nsg_id=$data_nsg_id

  {
    echo "-------- nsg rules ----------------------------------------------------------------"

    oci network nsg rules list --nsg-id "$nsg_id" --output json | tr -d "'" | jq -r '
  ["ID", "Direction", "Protocol", "Source", "Destination", "Description", "TCP Ports"],
  ["--", "---------", "--------", "------", "-----------", "-----------", "----------"],
  (.data[] | [
    .id,
    .direction,
    (if .protocol == "6" then "TCP" elif .protocol == "1" then "ICMP" elif .protocol == "all" then "ALL" else .protocol end),
    (.source // "-"),
    (.destination // "-"),
    (.description // "-"),
    (if .protocol == "6" and .["tcp-options"] then
      (if .["tcp-options"]["destination-port-range"] then
        (.["tcp-options"]["destination-port-range"].min | tostring) + "-" +
        (.["tcp-options"]["destination-port-range"].max | tostring)
      else "Any" end) + " : " +
      (if .["tcp-options"]["source-port-range"] then
        (.["tcp-options"]["source-port-range"].min | tostring) + "-" +
        (.["tcp-options"]["source-port-range"].max | tostring)
      else "Any" end)
    else "N/A" end)
  ]) | @tsv' | column -t -s $'\t'

    echo "-----------------------------------------------------------------------------------"
    echo " "
  } > $workdir/nsg_rule.out
  cat $workdir/nsg_rule.out
}

function set_nsg_rule() {

  local nsg_id=$data_nsg_id
  local rule_srccidr=$1
  local rule_port=$2
  local rule_desc=$3
  local rule_prot=6

  echo "add rule"

  display_nsg_rules $nsg_id

  rule_added=$(cat $workdir/nsg_rule.out | grep "$rule_srccidr" | grep "TCP" | grep "$rule_port" | wc -l)

  if [ $rule_added -eq 0 ]; then

    echo "rule not found - adding"

    {
      echo "["
      echo " {"
      echo "  \"description\": \"${rule_desc}\","
      echo "  \"destination\": null,"
      echo "  \"destinationType\":  null,"
      echo "  \"direction\": \"INGRESS\","
      echo "  \"icmpOptions\": null,"
      echo "  \"isStateless\": false,"
      echo "  \"protocol\": \"${rule_prot}\","
      echo "  \"source\":  \"${rule_srccidr}\","
      echo "  \"sourceType\":  \"CIDR_BLOCK\","
      echo "  \"udpOptions\": null,"
      echo "  \"tcpOptions\": { \"destinationPortRange\": { \"max\": \"${rule_port}\", \"min\": \"${rule_port}\" } }"
      echo " }"
      echo "]"
    } > $workdir/nsg.rule

    cat $workdir/nsg.rule

    oci network nsg rules add --nsg-id $nsg_id --security-rules file://$workdir/nsg.rule
    display_nsg_rules $nsg_id
  else
    echo "rule found - do nothing"

  fi
}

function getpw() {

  openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in ~/.ssh/vault.enc -out ~/.ssh/vault2
  source ~/.ssh/vault2
  rm ~/.ssh/vault2

}

function process_compartment() {
  compartment_id=$1
  msg N "Processing Compartment: $compartment_id"

  # Fetch Autonomous Databases
  #adbs=$(oci db autonomous-database list --compartment-id "$compartment_id")
  #adb_ids=$(echo "dbn=$adbs" | grep autonomousdatabase  | grep ocid | cut -d":" -f2 | tr -d " " | tr -d "," | tr -d '"')

  adb_ids="ocid1.autonomousdatabase.oc1.eu-frankfurt-1.antheljtlatq2xyawkbs7cs7a6rfw2ow5vcs6adz72qu2uzxysgdadduke3a"
  for adb_id in $(echo $adb_ids); do
    echo "Processing ADB: $adb_id"
    adb_detail=$(oci db autonomous-database get --autonomous-database-id $adb_id)
    data_db_name=$(echo "$adb_detail" | jq -r '.data["db-name"]')
    data_display_name=$(echo "$adb_detail" | jq -r '.data["display-name"]')

    if [ ! -f ../configfiles/tns_${data_db_name}.ora ]; then
      display_adb_detail $adb_id
      #       read -p "process?" antw
      antw="y"
      if [ "$antw" == "y" ]; then
        set_nsg_rule "10.0.0.0/8" "1521" "sql-net"
        set_nsg_rule "10.0.0.0/8" "1522" "sql-net"
        download_wallet $adb_id
      fi
    else
      echo "skip...."
    fi

  done
  exit
}

##########################
# main
##########################

adb_id="$1"
getpw
source ../premigration.env

# Process each compartment
for COMPARTMENT_ID2 in "${COMPARTMENTS_TO_PROCESS[@]}"; do

  process_compartment $COMPARTMENT_ID2
done
exit 0

s
exit 0
