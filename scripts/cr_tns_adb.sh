#!/bin/bash
#
#------------------------------#
source ../premigration.env cloud
workdir="/tmp"
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
	} >$workdir/nsg_rule.out
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
		} >$workdir/nsg.rule

		cat $workdir/nsg.rule

		oci network nsg rules add --nsg-id $nsg_id --security-rules file://$workdir/nsg.rule
	else
		echo "rule found - do nothing"

	fi
	display_nsg_rules $nsg_id
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

}

function getpw() {

	p_pw="y"
	openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in ~/.ssh/vault.enc -out ~/.ssh/vault2 -pass pass:$p_pw
	source ~/.ssh/vault2
	rm ~/.ssh/vault2

}

function download_wallet() {

	local adb_id=$1
	wallet_error=1

	getpw
	cat <<EOF >/tmp/w$$.json
{
 "autonomousDatabaseId": "$adb_id",
 "file": "/tmp/wallet_${data_db_name}_regional.zip",
 "generateType": "ALL",
 "isRegional": true,
 "password": "$adbadmin"
}
EOF

	#set -x
	oci db autonomous-database generate-wallet --from-json file:///tmp/w$$.json
	if [ $? -eq 0 ] || [ -z ${data_db_name} ]; then
		rm /tmp/w$$.json
		curdir=$(pwd)

		cd /tmp
		mkdir ${data_db_name}
		cd ${data_db_name}

		unzip /tmp/wallet_${data_db_name}_regional.zip
		if [ $? -eq 0 ]; then

			data_tp_connect=$(cat ./tnsnames.ora | grep -i "${data_db_name}_tp ")
			cd ..
			rm -rf /tmp/${data_db_name}
			cd $curdir
			mv /tmp/wallet_${data_db_name}_regional.zip ../configfiles
			if [ $? -eq 0 ]; then

				ecnt=0
				echo "$data_tp_connect" | tr -d " " >../configfiles/tns_${data_db_name}.ora
				let ecnt=${ecnt}+$?
				sed -i "s/$data_private_endpoint/$data_private_endpoint_ip/g" ../configfiles/tns_${data_db_name}.ora
				let ecnt=${ecnt}+$?
				sed -i "s/_tp//" ../configfiles/tns_${data_db_name}.ora
				let ecnt=${ecnt}+$?

				cat $TNS_ADMIN/tnsnames.ora | grep -v "^${data_db_name}" >/tmp/tns$$
				let ecnt=${ecnt}+$?
				mv /tmp/tns$$ $TNS_ADMIN/tnsnames.ora
				let ecnt=${ecnt}+$?
				cat ../configfiles/tns_${data_db_name}.ora >>$TNS_ADMIN/tnsnames.ora
				let ecnt=${ecnt}+$?
				if [ $ecnt -eq 0 ]; then
					wallet_error=0
				else
					echo "error tns names"
				fi
			else
				echo "error mv wallet"
			fi
		else
			echo "error unzip"
			cd $curdir
		fi
	else
		echo "error wallet"
	fi
}

function process_adb() {
	adb_id=$1
	msg N "Processing ADB:         $adb_id        "

	data_db_name=""
	{
		adb_detail=$(oci db autonomous-database get --autonomous-database-id $adb_id)
	} >/dev/null
	data_db_name=$(echo "$adb_detail" | jq -r '.data["db-name"]')

	if [ "X$data_db_name" == "X" ]; then
		echo "Error...."
		return
	fi

	data_display_name=$(echo "$adb_detail" | jq -r '.data["display-name"]')

	adb_tns_alias="${data_db_name}_tp"

	{
		timeout 3 sqlplus -s /@$adb_tns_alias <<EOF
                                         select * from dual;
                                         select * from dual;
                                         select * from dual;
                                         exit;
EOF
		ret=$?
	} >/dev/null

	if [ $ret -ne 0 ]; then

		display_adb_detail $adb_id
		#	set_nsg_rule "10.0.0.0/8" "1521" "sql-net"
		#	set_nsg_rule "10.0.0.0/8" "1522" "sql-net"
		download_wallet $adb_id
		if [ $wallet_error -eq 0 ]; then

			{
				timeout 3 tnsping ${data_db_name}
			} >/tmp/tnstest$$

			tnsok=$(cat /tmp/tnstest$$ | grep "msec" | grep "^OK" | wc -l)
			cat /tmp/tnstest$$
			echo $tnsok
			rm /tmp/tnstest$$

			if [ $tnsok -eq 1 ]; then

				if [ -f $TNS_ADMIN/tnsnames.ora ]; then

					echo "connection ok"

					./add_seps_cred_batch.sh -a "$data_db_name" -u admin -p y -b cloud

					{
						timeout 3 sqlplus -s /@${adb_tns_alias} <<EOF
                                             select * from dual;
                                             select * from dual;
                                             select * from dual;
                                             exit;
EOF
						ret=$?
					} >/dev/null

					if [ $ret -eq 0 ]; then
						adbstatus="successfull"
					fi

				else
					echo "missing tnsnames.ora...."
				fi
			else
				echo "connct NOK"
			fi
		fi

	else
		echo "connect to ${adb_tns_alias}_system succsfull"
		adbstatus="successfull"
	fi

}

###########################
# main
##########################

{
	adbstatus="FAILED"

	adb_ocid=$1
	process_adb $adb_ocid
} &>/dev/null

msg I "Add ADB to $adb_tns_alias was $adbstatus"

exit 0
