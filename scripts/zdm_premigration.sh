#!/usr/bin/env bash

# zdm_premigration.sh: Checks infrastructure readiness for ZDM database migration
# Usage: ./zdm_premigration.sh -d <oracledb-name> [-t <testnr> -a <adbname> -z <skipzdm> -c <skipconf> -n <mountnfs>]
# Version: 2.2, Date: 2025-05-16

#set -e -u -o pipefail

#^source ./init_variables.sh
source ../premigration.env cloud
source "${rootDir}/scripts/utils.sh"

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
NC="\033[0m"


manage_error_trap off

get_input_data() {
	local file="$1"
	local page_size=40
	local offset=0
	local clfilter="Cluster 1"
	local filter=""
	local total_lines
	local selected_line
	local filtered_data

	if [ "X$runcluster" != "X" ]; then

		case $runcluster in
		p | P) clfilter="Pilot" ;;
		1 | 2 | 3) clfilter="Cluster $runcluster" ;;
		*)
			echo "cluster $runcluster not yet defined"
			exit 1
			;;
		esac

	fi

	if [[ ! -f "$file" ]]; then
		echo "File not found: $file"
		return 1
	fi

	while true; do
		# Apply optional filter

		if [ "X$appnr" != "X" ] && [ -n "$clfilter" ]; then
                        cmd=$(echo "awk -F'|' -v cl=\"$clfilter\" 'BEGIN{IGNORECASE=1} \$13 == cl' \"$file\"")
                        eval $cmd >/tmp/temp$$
                        filtered_data=$(awk "NR == $appnr" /tmp/temp$$)
                else
			filtered_data=$(cat "$file")

			if [[ -n "$filter" ]]; then
				#filtered_data=$(grep -i "$filter" "$file")
				cmd=$(echo "cat \"$file\" | awk -F'|' 'BEGIN{IGNORECASE=1} \$9 ~ /$filter/'")
				filtered_data=$(eval $cmd)
			fi

			if [[ -n "$clfilter" ]]; then
                               filtered_data=$(awk -F'|' -v cl="$clfilter" 'BEGIN { IGNORECASE = 1 } $13 == cl' "$file")
                        fi

		fi

		total_lines=$(echo "$filtered_data" | wc -l)

		# Show current page
		clear
		echo
		echo "Testcases in scope: $tests_in_scope"
		echo
		printf "%-5s %-15s %-40s %-15s %-30s %-25s %-10s %-15s\n" \
			"Nr" "MigCl" "App_Name" "Env_Orig" "Oracle_DB" "Shared" "Platform" "Target_Name"
		echo "---------------------------------------------------------------------------------------------------------------------------------------------------------"

		echo "$filtered_data" | sed -n "$((offset + 1)),$((offset + page_size))p" |
			awk -F'|' -v start=$((offset + 1)) '{
      printf "%-5s %15-s %-40s %-15s %-30s %-25s %-10s %-15s\n", NR + start - 1, $13, $9, $10, $5, $11, $1, $2
    }'

		echo
		if [ "X$appnr" != "X" ]; then
			action=1
			echo "will use this src db/App"
			sleep 2
		else
			echo "Actions: [f]orward | [b]ack | [t]estcases set | [r]un tests | [nr] select row | [q]uit"
			printf "Enter action: "
			read -r action </dev/tty
		fi

		case "$action" in
		f)
			if ((offset + page_size < total_lines)); then
				offset=$((offset + page_size))
			else
				echo "Already at end of data."
			fi
			;;
		b)
			if ((offset - page_size >= 0)); then
				offset=$((offset - page_size))
			else
				offset=0
				echo "Already at beginning."
			fi
			;;
		t)
			select_testcases
			;;
		[0-9]*)
			selected_line=$(echo "$filtered_data" | sed -n "${action}p")
			if [[ -z "$selected_line" ]]; then
				echo "Invalid line number."
			else
				IFS='|' read -r \
					dbmp_target_platform dbmp_target_name dpmp_target_migr_methode \
					dbmp_test_tns_alias dbmp_oracle_db dbmp_env dbmp_dataclass dbmp_vnet \
					dbmp_app_name DBMP_ENV_ORIG DBMP_SHARED dbmp_target_tns_alias dbmp_migcluster \
				        dbmp_primkey dbmp_target_env dbmp_nfs_ip dbmp_nfs_name dbmp_nfs_share  BMP_NFS_MP  AS csv_output <<<"$selected_line"

				export dbmp_target_platform
				export dbmp_target_name
				export dpmp_target_migr_methode
				export dbmp_test_tns_alias
				export dbmp_target_tns_alias
				export dbmp_oracle_db
				export dbmp_env
				export dbmp_dataclass
				export dbmp_vnet
				export dbmp_app_name
				export DBMP_ENV_ORIG
				export DBMP_SHARED
				export dbmp_migcluster
				export srcdb=$dbmp_oracle_db
				export tgtdb=$dbmp_target_name
				export app_result_dir=$(echo $dbmp_app_name | tr " " "_")
				break
			fi
			;;
		r)
			break
			;;
		q)
			echo "Exiting."
			exit
			;;
		*)
			echo "Unknown action: $action"
			;;
		esac
		sleep 1
	done
}

# Pre-migration checks
pre_checks() {
	clear
	if [ ! -f ../premigration.env ]; then
		echo "wrong startdirectory... please run from <premig-root>/scripts dir ... exiting"
		exit 1
	fi

	for subDir in configfiles tmp results sqls dialog tmp/tmp results/tmp scripts; do
		exitDirNotExists "${rootDir}/${subDir}"
	done

	dialogDir="${rootDir}/dialog/dia$dialogNr"
	crDirNoExists "${dialogDir}"
	mailToSend="${rootDir}/mailbox/tosend"
	if [ ! -d $mailToSent ]; then 
		mkdir -p $mailSent
	fi
	mailSent="${rootDir}/mailbox/sent"
	if [ ! -d $mailSent ]; then 
		mkdir -p $mailSent
	fi

	checkErr $? "loading env vars"

	configDir="${rootDir}/configfiles"
	scriptsDir="${rootDir}/scripts"

	if [ "X${srcdb}" == "X" ]; then
		${scriptsDir}/fetch_cmdb_data.sh appinfos
		get_input_data $configDir/appinfos.env
		if [ "X${srcdb}" == "X" ]; then
			msg N I "no application selected ... exit"
			exit 1
		fi
	fi

	dbResultDir="${rootDir}/results/${jobnr}_${app_result_dir}.${dbmp_env}"
	dbResultDirOhneJnr="${rootDir}/results/${app_result_dir}.${dbmp_env}"
	#cpatResultDir="${rootDir}/cpat/${app_result_dir}.${dbmp_env}"
	cpatResultDir="${rootDir}/cpat/${jobnr}_${app_result_dir}.${dbmp_env}"
	resultDir="${rootDir}/results"
	sqlDir="${rootDir}/sqls"
	dbinfoDir=${configDir}/dbinfos

	# mv app resuk
	#find "$resultDir" -maxdepth 1 | grep "$dbResultDirOhneJnr" | while read -r appdir; do
	#	mv "$appdir" "$resultDir/tmp"
	#done

	crDirNoExists "${dbinfoDir}"
	crDirNoExists "${dbResultDir}"
	crDirNoExists "${cpatResultDir}"
	LGfile="${dbResultDir}/${srcdb}.log"

	"${scriptsDir}/fetch_cmdb_data.sh" testcases
	exitFileNotExists "$scriptsDir/ssh_connect.sh"
	exitFileNotExists "$scriptsDir/manage_ssh_config.sh"
	exitFileNotExists "$scriptsDir/run_precheck.sh"
	exitFileNotExists "$scriptsDir/fetch_cmdb_data.sh"
	exitFileNotExists "$walletdir/sqlnet.ora"

	if [ "X${skipconf}" == "XYES" ] && [ -f "$configDir/zdmhosts.env" ]; then
		msg N I "skipping download zdmhosts"
	else
		"${scriptsDir}/fetch_cmdb_data.sh" zdmhosts
	fi
	exitFileNotExists "$configDir/zdmhosts.env"
	exitFileNotExists "$configDir/dialogrc"
	exitFileNotExists "$configDir/testcases.csv"
	exitFileNotExists "$sqlDir/procedure_nfs_share.sql"
	cp "$configDir/dialogrc" ~/.dialogrc

	driver_dir=${dbResultDir}
	tmp_dir=${rootDir}/tmp/$[jobnr]_tmpfiles
	crDirNoExists "$tmp_dir"
	zdm_hosts=$(cat "$configDir/zdmhosts.env")
	zdm_hosts=$(echo "$zdm_hosts" | tr -d " ")
	zdm_hosts="${zdm_hosts%,}"
	cpat_dir=${rootDir}/cpat25.2

	curHost=$(hostname)
	if [ -f "${configDir}/${curHost}.env" ]; then
		source "${configDir}/${curHost}.env"
	fi

	source_sid=$(echo "$srcdb" | cut -d "_" -f1)

	if [ "X${tgtdb}" == "X" ]; then
		tgtdb=$(echo "$srcdb" | cut -d "_" -f1)
		if [ "X${tgtdb}" == "X" ]; then
			msg N E "missing target db as input par 2... exit"
			exit 1
		fi
	fi

	tgt_name=$tgtdb
	ldat=$(date +"%Y%m%d-%H%M%S")

	driver_file=$driver_dir/premigration.drv
	touch "$driver_file"
	rm "$driver_file"

	trap cleanup EXIT INT TERM
}

# Check database connectivity
check_db() {
	${scriptsDir}/fetch_cmdb_data.sh dbinfos "$srcdb"
	exitFileNotExists "$dbinfoDir/${srcdb}.env"
	if [ $(cat $dbinfoDir/${srcdb}.env | grep -i "ora-" | wc -l) -ne 0 ]; then
		msg N E "read dbinfos has errors"
		cat $dbinfoDir/${srcdb}.env
		exit 1
	fi

	dbinfo=$(cat "$dbinfoDir/${srcdb}.env" | tr -d " ")

	oracledb=$(echo "$dbinfo" | cut -d "," -f1)
	vn_id=$(echo "$dbinfo" | cut -d "," -f2)
	cluster_name=$(echo "$dbinfo" | cut -d "," -f3)
	vn_sdd_vname=$(echo "$dbinfo" | cut -d "," -f4)
	confidential=$(echo "$dbinfo" | cut -d "," -f5)
	dns_name=$(echo "$dbinfo" | cut -d "," -f6)
	source_ip=$(echo "$dbinfo" | cut -d "," -f7 | tr -d " ")
	port_number=$(echo "$dbinfo" | cut -d "," -f8)
	oracle_osn=$(echo "$dbinfo" | cut -d "," -f9)
	oracle_osn_alias=$(echo "$dbinfo" | cut -d "," -f10)
	dbaccess=$(echo "$dbinfo" | cut -d "," -f11)
	dbuser=$(echo "$dbinfo" | cut -d "," -f12)
	service_category=$(echo "$dbinfo" | cut -d "," -f13)
	db_primkey=$(echo "$dbinfo" | cut -d "," -f14)
	in_pilot=$(echo "$dbinfo" | cut -d "," -f15)
	vn_az_subscr=$(echo "$dbinfo" | cut -d "," -f16)
	vn_az_subn=$(echo "$dbinfo" | cut -d "," -f17)
	vn_az_nw=$(echo "$dbinfo" | cut -d "," -f19)
	vn_az_name=$(echo "$dbinfo" | cut -d "," -f20)
	# vn_nr_ips=$(echo "$dbinfo" | cut -d "," -f21)
	cluster_id=$(echo "$dbinfo" | cut -d "," -f21)
	src_db_version=$(echo "$dbinfo" | cut -d "," -f22)
	src_db_sga=$(echo "$dbinfo" | cut -d "," -f23)
	src_db_pga=$(echo "$dbinfo" | cut -d "," -f24)
	src_db_allocgb=$(echo "$dbinfo" | cut -d "," -f25)
	src_db_cores=$(echo "$dbinfo" | cut -d "," -f26)
	src_db_ecpus=$(echo "$dbinfo" | cut -d "," -f27)
	src_db_charset=$(echo "$dbinfo" | cut -d "," -f28)

	test_tns_alias=$dbmp_test_tns_alias
	target_tns_alias=$dbmp_target_tns_alias

	target_platform="ATPS"
	if [ "$dbmp_target_platform" == "ExaDB" ]; then
		target_platform="EXAD"
	fi

	target_db_name=$dbmp_target_name
	mig1="Physical"
	if [ $(echo "$dpmp_target_migr_methode" | grep -i "log" | wc -l) -gt 0 ]; then
		mig1="Logical"
	fi
	mig2="OFFline"
	if [ $(echo "$dpmp_target_migr_methode" | grep -i "onl" | wc -l) -gt 0 ]; then
		mig2="Online"
	fi
	agreed_mig_methode="$mig1/$mig2"
	environment="T"
	if [ $(echo "$dbmp_env" | grep -i "prod" | wc -l) -gt 0 ]; then
		environment="P"
	fi
	data_classification=$dbmp_dataclass
	vn_id=$dbmp_vnet

	source_ip=$(echo $source_ip | tr -d " ")
	

	if [ "$skip_source_connectiontest" == "NO" ]; then
	   if [ "$cpatonly" == "NO" ]; then
		source_host=$(timeout 5 ssh $ssh_options "$source_ip" "hostname")
		if [ $? -ne 0 ]; then
			#"$scriptsDir/ssh_connect.sh" -n "$source_ip" -i "$source_ip" -u "${cuser:-oracle}" -x no </dev/null &>>/dev/null
			#source_host=$(timeout 5 ssh "$source_ip" "hostname")
			#if [ $? -ne 0 ]; then
			msg N E "source host $source_ip not reachable"
			"${scriptsDir}/fetch_cmdb_data.sh" storeres "$srcdb" "901" "--FAILED---" "source host not reachable" </dev/null &>/dev/null
			exit 1
		#fi
		fi

		source_keyfile=$("$scriptsDir/manage_ssh_config.sh" get -h "$source_ip" -u oracle | grep IdentityFile | awk '{print $2}')
		checkValue "X$source_keyfile" "src keyfile"
	  fi

	  export TNS_ADMIN=$ORACLE_HOME/network/admin/onprem_dbs
	  srcdb_reachable=$(timeout 3 tnsping "$oracledb" | tail -n 1 | grep "^OK" | cut -d " " -f1)
	  if [ "X${srcdb_reachable}" != "XOK" ]; then
		"${scriptsDir}/fetch_cmdb_data.sh" storeres "$srcdb" "902" "--FAILED---" "source db not reachable" </dev/null &>/dev/null
		msg N E "srcdb $oracledb not reachable"
		exit 1
	  fi

	  srcdb_connectstring=$(grep -i "^$oracledb=" "$TNS_ADMIN/tnsnames.ora" | head -n 1 | sed "s/^${oracledb}=//")
	  checkValue "X$srcdb_connectstring" "no srcdb connectstr"
	  checkValue "X$ssh_options" "no ssh options"
  	  checkValue "X$scp_options" "no scp options"

	  srcdb_connectstring_system=$(grep -i "^${oracledb}_system=" "$TNS_ADMIN/tnsnames.ora" | head -n 1)
	  if [ "X$srcdb_connectstring_system" == "X" ]; then
		msg N I "add src tns seps alias"
		${scriptsDir}/add_seps_cred_batch.sh -a ${oracledb} -u system -p y -b onprem &>/dev/null
		srcdb_connectstring_system=$(grep -i "^${oracledb}_system=" "$TNS_ADMIN/tnsnames.ora" | head -n 1)
		checkValue "X$srcdb_connectstring_system" "no srcdb system connectstr"
	  fi
        fi

	if [ "$skip_target_connectiontest" == "NO" ]; then
	  if [ "X${target_tns_alias}" != "X" ] && [ "$cpatonly" == "NO" ]; then
		if [ "$(cat "$TNS_ADMIN_ROOT/cloud_dbs/tnsnames.ora" | grep -i "^$target_tns_alias" | wc -l)" -eq 0 ]; then
			msg N I "add tgt tns seps alias"
			tgt_uname="admin"
			if [ "$target_platform" == "EXAD" ]; then
				tgt_uname="system"
			fi

			echo "${scriptsDir}/add_seps_cred_batch.sh -a ${target_db_name} -u  $tgt_uname -p y -b cloud"
			${scriptsDir}/add_seps_cred_batch.sh -a ${target_db_name} -u $tgt_uname -p y -b cloud &>/dev/null
		fi
		if [ "$(cat "$TNS_ADMIN_ROOT/cloud_dbs/tnsnames.ora" | grep -i "^$target_tns_alias" | wc -l)" -eq 0 ]; then
			msg N E "target db tns unknown: $target_tns_alias in $TNS_ADMIN_ROOT/cloud_dbs/tnsnames.ora"
			exit 1
		fi
	  fi
	fi

	cpat_schematas=$DBMP_SHARED
}

# Print basis screen
print_basis_screen() {
	clear
	printf "%-99s\n" " "
	printf "%-120s\n" "================================================================================================================================="
	printf "%-120s\n" "=                         START pre-Migration Infrastructure Readiness test - Jobnr: $jobnr                             ="
	printf "%-120s\n" "================================================================================================================================="
	printf "%-99s\n" " "

	paste "$dialogDir/sourcedb.txt" "$dialogDir/targetdb.txt" | while IFS=$'\t' read -r src tgt; do
		printf "%-65s %s\n" "$src" "$tgt"
	done

	echo "---------------------------------------------------------------------------------------------------------------------------------"
	if [ "X${xenv}" == "XP" ] || [ "X${xconf}" == "XY" ]; then
		msg N I " "
		msg N I "${RED}>>> Pay Attention: Prod and/or confidential environment <<< $NC"
		msg N I "  "
	fi

	echo " "
}

# Print driver file
print_driverfile() {
	xenv=$environment
	mig_methode="$agreed_mig_methode"
	xconf="N"
	if [ "X${data_classification}" == "XConfidential" ]; then
		xconf="Y"
	fi

	configinfo=$(
		sqlplus -S /@mondbp_mig <<EOF
SET PAGESIZE 0
SET LINESIZE 200
SELECT AZ_VNET || ';' || TARGET_IP || ';' || EXA_CL_NODES || ';' || OGG_VM || ';' || ORAENV_TAG || ';' ||
   TNS_ALIAS || ';' || NFS_NAME || ';' || NFS_IP || ';' || NFS_EXPORT_NAME || ';' || NFS_MOUNTPOINT AS CONFIG_INFO
FROM MIG_INFRAN_CONFIG
WHERE PLATFORM = '${target_platform}' AND ENVIRONMENT = '${xenv}' AND CONFIDENTIAL = '${xconf}';
EOF
	)
	checkErr $? "select config"

	az_vnet=$(echo "$configinfo" | cut -d ';' -f 1)
	target_ip=$(echo "$configinfo" | cut -d ';' -f 2)
	exaclnodes=$(echo "$configinfo" | cut -d ';' -f 3)
	ogg_vm=$(echo "$configinfo" | cut -d ';' -f 4)
	tf_oraenv=$(echo "$configinfo" | cut -d ';' -f 5)
	test_tns_alias=$(echo "$configinfo" | cut -d ';' -f 6)
	nfs_server=$(echo "$configinfo" | cut -d ';' -f 7)
	nfs_ip=$(echo "$configinfo" | cut -d ';' -f 8)
	nfs_share=$(echo "$configinfo" | cut -d ';' -f 9)
	nfs_mountp=$(echo "$configinfo" | cut -d ';' -f 10)

	export TNS_ADMIN=$ORACLE_HOME/network/admin/cloud_dbs
	test_conectstring=$(cat "$TNS_ADMIN/tnsnames.ora" | grep "^$test_tns_alias" | head -n 1 | sed "s/^${test_tns_alias}=//")
	checkValue "X$test_conectstring" "no test connectstr"

	nfs_version="4"
	nfs_mountopt="rw,relatime,vers=4.1,rsize=1048576,wsize=1048576,namlen=255,hard,proto=tcp,nconnect=4,timeo=600,retrans=2,sec=sys,local_lock=none"

	if [ "X${target_tns_alias}" == "X" ]; then
		target_tns_alias="$test_tns_alias"
	fi

	#if app mginfos has an nfs server assignet, will takke this server

	if [ "X$dbmp_nfs_ip" != "X" ]; then
             
	    nfs_ip=$dbmp_nfs_ip
	    nfs_server=$dbmp_nfs_name
	    nfs_mountp=$dbmp_nfs_mp
	    nfs_share=$dbmp_nfs_share
          
	fi

	write_driver_file
}

# Initialize control files
init_control_files() {
	#checkValue "X$DB_UNIQUE_NAME" "DB_UNIQUE_NAME"
	#checkValue "X$DB_NAME" "DB_NAME"

	{

                echo -e "${GREEN}RunNr: $runnr"
		echo -e "${GREEN}Source:"
		echo -e "${GREEN}---------------------------------------------------------------"
		echo -e "${GREEN}Migration Cluster...... $dbmp_migcluster"
		echo -e "${GREEN}Application ........... $dbmp_app_name"
		echo -e "${GREEN}Database............... $oracledb"
		echo -e "${GREEN}DB Name................ $oracle_osn"
		echo -e "${GREEN}Hostname............... $source_host"
		echo -e "${GREEN}IP adresse............. $source_ip"
		echo -e "${GREEN}Database Version....... $src_db_version"
		echo -e "${GREEN}Environement........... $environment"
		echo -e "${GREEN}Data Classification.... $data_classification"
		echo -e "${GREEN}SGA.................... $src_db_sga"
		echo -e "${GREEN}PGA.................... $src_db_pga"
		echo -e "${GREEN}Alloc.GB............... $src_db_allocgb"
		echo -e "${GREEN}Used GB................ ${src_db_usedgb:-N/A}"
		echo -e "${GREEN}Charset................ $src_db_charset"
		echo -e "${GREEN}Send Mail.............. $mail_to "
		echo -e "${GREEN}                     $NC          "
		echo -e "${GREEN}                     $NC          "
	} >"$dialogDir/sourcedb.txt"

	{
		echo -e " "
		echo -e "${YELLOW}TARGET:"
		echo -e "${YELLOW}---------------------------------------------------------------"
		echo -e "${YELLOW}AZ Subscription....... $vn_az_subscr"
		echo -e "${YELLOW}Targetname............ $tgt_name"
		echo -e "${YELLOW}Platform.............. ${target_platform:-N/A}"
		echo -e "${YELLOW}Target DB Name........ ${target_db_name:-N/A}"
		echo -e "${YELLOW}Netzwerk.............. ${az_vnet:-N/A}"
		echo -e "${YELLOW}cluster/ADB Name...... ${cluster_name:-}${adbname:-}"
		echo -e "${YELLOW}cluster_nodes......... ${exaclnodes:-N/A}"
		echo -e "${YELLOW}Environment........... ${xenv:-N/A}"
		echo -e "${YELLOW}Confidential.......... ${xconf:-N/A}"
		echo -e "${YELLOW}Migration Methode..... ${mig_methode:-N/A}"
		echo -e " "
		echo -e "${YELLOW}nfs sever............. ${nfs_ip:-N/A}"
		echo -e "${YELLOW}nfs sever name........ ${nfs_server:-N/A}"
		echo -e "${YELLOW}nfs mountpoint........ ${nfs_mountp:-N/A}"
		echo -e "${YELLOW}nfs share............. ${nfs_share:-N/A}"
		echo -e "    ${YELLOW}ogg hub............... ${ogg_vm:-N/A} $NC"
		#    echo "Terraform code........ ${tf_oraenv:-N/A}"; echo "test connect tgt...... ${test_tns_alias:-N/A}"
	} >"$dialogDir/targetdb.txt"
}

function select_testcases() {

	FILE="$configDir/testcases.csv"
	${scriptsDir}/fetch_cmdb_data.sh testcases

	sort $FILE >/tmp/temp$$
	mv /tmp/temp$$ $FILE

	clear
	# Show the CSV file in a formatted table
	echo -e "\nAvailable Test Cases:\n"
	echo -e "Nr   Code          Desc                               LOn Lf PO PF"
	echo -e "-------------------------------------------------------------------"
	column -t -s ':' "$FILE"

	# Extract valid test case numbers from the file (first column)
	valid_ids=$(cut -d':' -f1 "$FILE")

	# Prompt user input
	read -rp $'\nEnter space-separated test case numbers: ' -a input_array </dev/tty

	# Validate and process input
	tests_in_Scope="001 "
	for num in "${input_array[@]}"; do
		# Check if it's a number
		if ! [[ "$num" =~ ^[0-9]+$ ]]; then
			echo "Invalid input: '$num' is not a number."
			exit 1
		fi

		# Pad with leading zeros
		padded=$(printf "%03d" "$num")

		# Check if it exists in the file
		if echo "$valid_ids" | grep -q "^$padded$"; then
			tests_in_scope=$(echo "$tests_in_scope $padded")
		else
			echo "Invalid test number: '$padded' not found in testcases."
			exit 1
		fi
	done

}

# Determine tests to run
function what_tests_to_run() {
	local methode
	methode=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d "/")
	checkValue "$methode" "methode"

	if [ "X${runTest}" == "X" ]; then
		tests_in_scope=""
		case $methode in
		logicaloffline) column="LOG_OFF" ;;
		logicalonline) column="LOG_ON" ;;
		physicaloffline) column="PHY_OFF" ;;
		physicalonline) column="PHY_ON" ;;
		*)
			echo "Unknown methode: $methode, using default tests"
			tests_in_scope="001 002 003 004 005 006 007 008 009 010 011 012 013 014 015 016 017"
			return
			;;
		esac

		testsselect="SELECT LISTAGG(NR, ' ') WITHIN GROUP (ORDER BY NR) FROM MIG_PREMIG_TESTCASES WHERE $column = 'Y';"
		tests_in_scope=$(
			sqlplus -S /@mondbp_mig <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
$testsselect
EOF
		)
	else
		mig_methode="manual assigned tasks "
		tests_in_scope="001 $runTest"
	fi

        #check doubles
	tests_in_scope_tmp=""
	for num in $tests_in_scope; do
          if [[ ! " $tests_in_scope_tmp " =~ " $num " ]]; then
            tests_in_scope_tmp+="$num "
          fi
        done
	tests_in_scope=$tests_in_scope_tmp

}

# Run pre-migration checks
run_checks() {
	print_basis_screen
	generate_report_head
	msg N I "Start pre migration Infracheck"

	# check which tests ti run

	if [ "$dryrun" == "NO" ]; then
		if [ "X${tests_in_scope}" == "X" ]; then
			what_tests_to_run "$mig_methode"
		fi
		msg N I "Running tests for $mig_methode - $tests_in_scope"
	else
		msg N I "Dryrun tests for $mig_methode - $tests_in_scope"
		tests_in_scope=""
	fi

	manage_error_trap off
	echo " "
	attachments=""
	for test_nr in $tests_in_scope; do
		test_to_run=$(grep "^$test_nr:" "$configDir/testcases.csv" | cut -d ":" -f2 | tr -d " ")
		test_desc=$(grep "^$test_nr:" "$configDir/testcases.csv" | cut -d ":" -f3)
		printf "\r%-2s %-13s %-40s" " $test_nr" "$test_to_run" "$test_desc"

		#    echo "$scriptsDir/run_precheck.sh \"$test_nr\" \"$test_to_run\" \"$driver_file\" </dev/null &>/dev/null"
		$scriptsDir/run_precheck.sh "$test_nr" "$test_to_run" "$driver_file" </dev/null &>/dev/null

		if [ -f "${dbResultDir}/${test_nr}_${test_to_run}.result" ]; then
			completedStatus=$(cut -d ";" -f2 "${dbResultDir}/${test_nr}_${test_to_run}.result")
			completedComment=$(cut -d ";" -f3 "${dbResultDir}/${test_nr}_${test_to_run}.result")
		else
			completedStatus="***FAILED***"
			completedComment="Testrun incomplete - no result"
		fi

		printf "\r%-3s %-13s %-40s %-15s %-30s\n" " $test_nr" "$test_to_run" "$test_desc" " - $completedStatus" "$completedComment"
		"${scriptsDir}/fetch_cmdb_data.sh" storeres "$srcdb" "$test_nr" "$completedStatus" "$completedComment" </dev/null &>/dev/null
		printf "%-3s %-15s %-40s" "$test_nr" "$test_to_run" "$test_desc" >>"$reportfile"
		printf "%-15s %-30s\n" " - $completedStatus" "$completedComment" >>"$reportfile"

		case $test_nr in
		017) attachments="$attachments $test_nr" ;;
		020) attachments="$attachments $test_nr" ;;
		*) echo "no attachment" >/dev/null ;;
		esac

	done

	echo " "
}

# Generate report footer
generate_report_foot() {
	{
		printf "%-80s\n" " "
		printf "%-120s\n" "================================================================================================================================="
		printf "%-120s\n" "=                           END Pre-Migration Infrastructure Readiness Report - PMIRR                                           ="
		printf "%-120s\n" "================================================================================================================================="
		printf "%-80s\n" " "
	} >>"$reportfile"
	####  msg N I "Report erstellt: ../results/${app_result_dir}.${dbmp_env}/${dbmp_app_name}_premig_infrachecks_report.txt"

	if [ "X$mail_to" != "X" ]; then

                if [ ! -d "${mailToSend}/${jobnr}/${app_result_dir}.${dbmp_env}.logs" ]; then
			mkdir -p "${mailToSend}/${jobnr}/${app_result_dir}.${dbmp_env}.logs"
		fi

		cp -u ${dbResultDir}/0*.txt ${mailToSend}/${jobnr}/${app_result_dir}.${dbmp_env}.logs
		cp -u $reportfile  ${mailToSend}/$jobnr
		for test_nr in $attachments; do
			case $test_nr in
			020)
				if [ -f ${cpatResultDir}/${srcdb}_cpat_online_premigration_advisor_report.html ]; then
					 attf="$attf ${cpatResultDir}/${srcdb}_cpat_online_premigration_advisor_report.html"
					 cp -u ${cpatResultDir}/${srcdb}_cpat_online_premigration_advisor_report.html ${mailToSend}/$jobnr
				fi
				if [ -f ${cpatResultDir}/${srcdb}_cpat_offline_premigration_advisor_report.html ]; then
					attf="$attf ${cpatResultDir}/${srcdb}_cpat_offline_premigration_advisor_report.html"
					cp -u ${cpatResultDir}/${srcdb}_cpat_offline_premigration_advisor_report.html ${mailToSend}/$jobnr
				fi
				;;
			017)
				if [ -f ${cpatResultDir}/${srcdb}_dblinks.template.txt ]; then
					attf="$attf ${cpatResultDir}/${srcdb}_dblinks.template.txt"
					cp -u ${cpatResultDir}/${srcdb}_dblinks.template.txt ${mailToSend}/$jobnr
				fi
				;;
			*) echo "no attachment" >/dev/null ;;
			esac
		done

		 #d_mail $mail_to "Premigration Test for ${app_result_dir}.${dbmp_env}" "$reportfile" "${attf}"
	fi

}

# Generate report header
generate_report_head() {

	reportfile=$(echo "$dbResultDir/${dbmp_app_name}_${dbmp_env}_premig_infrachecks_report.txt" | tr " " "_")
	{
		printf "%-80s\n" " "
		printf "%-120s\n" "================================================================================================================================="
		printf "%-120s\n" "=                         START Pre-Migration Infrastructure Readiness Report - PMIRR                                           ="
		printf "%-120s\n" "================================================================================================================================="
		printf "%-80s\n" " "

		paste "$dialogDir/sourcedb.txt" "$dialogDir/targetdb.txt" | while IFS=$'\t' read -r src tgt; do
			printf "%-65s %s\n" "$src" "$tgt"
		done

		echo "---------------------------------------------------------------------------------------------------------"
		if [ "X${xenv}" == "XP" ] || [ "X${xconf}" == "XY" ]; then
			msg N I " "
			msg N I ">>> Pay Attention: Prod and/or confidential environment <<<"
			msg N I " "
		fi

		echo " "
	} >"$reportfile"

}

# Usage information
usage() {
	echo "usage: $0 -d <oracledb-name> [ -t <testnr> -a <adbname> -z <skipzdm> -c <skipconf> -n <mountnfs> ]"
	exit 0
}

# Initialize variables dynamically
init_variables_dynamic() {
	for var in $(cat ./vars); do
		eval "if [[ -z \${$var+x} ]]; then $var=\"\"; fi"
	done
}

# Main
init_variables_dynamic

skipzdm="NO"
skipconf="NO"
dryrun="NO"
execute_mount_src="NO"
execute_mount_tgt="NO"
cpatonly="NO"
infoonly="NO"
skip_target_connectiontest="NO"
skip_source_connectiontest="NO"

while getopts "j:d:t:a:z:c:n:i:r:m:x:p:l:" opt; do
	case $opt in
	d) srcdb="$OPTARG" ;;
	t) runTest="$OPTARG" ;;
	a) appnr="$OPTARG" ;;
	z) xskipzdm="$OPTARG" ;;
	c) xskipconf="$OPTARG" ;;
	i) xinteractiv="$OPTARG" ;;
	r) runcluster="$OPTARG" ;;
	n) xmntnfs="$OPTARG" ;;
	m) mail_to="$OPTARG" ;;
	x) xdryrun="$OPTARG" ;;
	p) xcpatonly="$OPTARG" ;;
	l) runnr="$OPTARG" ;;
	j) jobnr="$OPTARG" ;;
	*) usage ;;
	esac
done

if [ "X${runTest}" == "X000" ]; then
        infoonly="YES"
        skip_target_connectiontest="YES"
        skip_source_connectiontest="YES"
fi


if [ "X${runnr}" == "X" ]; then
	runnr="1/1"
fi
if [ "X${jobnr}" == "X" ]; then
	jobnr=$(date +"%Y%m%d%H%M%S")
fi
if [ "X${xskipzdm}" != "X" ]; then
	skipzdm="YES"
fi
if [ "X${xcpatonly}" != "X" ]; then
	cpatonly="YES"
	runTest="017 020"
	skipzdm="YES"
fi
if [ "X${xdryrun}" != "X" ]; then
	dryrun="YES"
fi
if [ "X${xskipconf}" != "X" ]; then
	skipconf="YES"
fi
if [ "X${xinteractiv}" != "X" ]; then
	interactiv="YES"
fi
if [ "X${xmntnfs}" != "X" ]; then
	execute_mount_src="YES"
	execute_mount_tgt="YES"
fi

remDir=/tmp/modernex_premig_checks
dialogNr=$$
pre_checks
check_db
print_driverfile
init_control_files

if [ "$infoonly" == "YES" ]; then

	print_basis_screen
	read -rp "press <return>..." antw  </dev/tty
else
        run_checks
        generate_report_foot
fi
echo "---------------------------------------------------------------------------------------------------------------------------------"
msg N I "finished pre migration Infracheck"
echo "---------------------------------------------------------------------------------------------------------------------------------"

exit 0
