#!/bin/bash

export ws_user=$1
export mail_to=$2
export ws_nr=$3

export currrent_user=$(whoami)
export rootDir="${HOME}/${ws_nr}/premigration"

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
NC="\033[0m"

cleanup() {

	printf "\e[?25h"

	echo
	#clear
	if [ "$current_user" == "premig" ]; then

		if [ "$trace_actions" == "true" ]; then

			echo "menu logout-----------------------------------" >>$trace_file
			echo $(date) >>$trace_file
			echo $SSH_CONNECTION >>$trace_file

		fi
	fi
	exit
}

get_perf_data() {

	local dbname="$1"
	local dbtns="$2"
	local resultf="$3"
	local show_data="$4"

	cok=$(check_tns_connect "$dbtns")

	if [ "$cok" != "OK" ]; then
		echo "cannot connect to db $dbname"
		sleep 2
		return
	fi

	{

sqlplus -s "/@${dbtns}" <<EOF
SET heading OFF
SET feedback OFF
SET pagesize 0
SET verify OFF
SET linesize 32767
SET trims ON
SET termout ON

SELECT
  d.name || '|' ||
  NVL(SYS_CONTEXT('USERENV', 'CON_NAME'), '---') || '|' ||
  TO_CHAR(ROUND((SELECT MAX(value) FROM v\$pgastat WHERE name = 'maximum PGA allocated') / 1024 / 1024 / 1024, 2), 'FM9990.00') || '|' ||
  TO_CHAR(ROUND((SELECT value FROM v\$parameter WHERE name = 'sga_max_size') / 1024 / 1024 / 1024, 2), 'FM9990.00') || '|' ||
  TO_CHAR(ROUND((SELECT SUM(bytes) FROM dba_data_files) / 1024 / 1024 / 1024, 2), 'FM9990.00') || '|' ||
  TO_CHAR(ROUND((SELECT SUM(bytes) FROM dba_segments) / 1024 / 1024 / 1024, 2), 'FM9990.00') || '|' ||
  TO_CHAR(ROUND(( SELECT MAX(average) FROM dba_hist_sysmetric_summary m WHERE m.metric_name = 'CPU Usage Per Sec' AND m.dbid = (SELECT dbid FROM v\$database) AND m.instance_number = (SELECT instance_number FROM v\$instance) AND m.begin_time >= SYSDATE - 1), 2), 'FM9990.00')  AS csv_output 
 FROM v\$database d;
EOF

	} >$rootDir/tmp/perf221

	{
		sqlplus -s "/@${dbtns}" <<EOF

                   set pagesize 2000
                  COLUMN snapshot_start FORMAT A16
                  COLUMN snapshot_end FORMAT A16
                  COLUMN num_cpus FORMAT 999
                  COLUMN avg_cpu_usage_per_sec FORMAT 9999.99
                  COLUMN avg_cpu_percent FORMAT 999.99
                  
                  WITH cpu_per_snapshot AS (
                    SELECT
                      m.snap_id,
                      m.begin_time AS begin_interval_time,
                      m.end_time AS end_interval_time,
                      m.average AS cpu_usage_per_sec
                    FROM
                      dba_hist_sysmetric_summary m
                    WHERE
                      m.metric_name = 'CPU Usage Per Sec'
                      AND m.dbid = (SELECT dbid FROM v\$database)
                      AND m.instance_number = (SELECT instance_number FROM v\$instance)
                      AND m.begin_time >= SYSDATE - 1
                  ),
                  cpu_count AS (
                    SELECT value AS num_cpus FROM v\$osstat WHERE stat_name = 'NUM_CPUS'
                  )
                  SELECT
                    TO_CHAR(begin_interval_time, 'YYYY-MM-DD HH24:MI') AS snapshot_start,
                    TO_CHAR(end_interval_time, 'YYYY-MM-DD HH24:MI') AS snapshot_end,
                    cpu_count.num_cpus,
                    ROUND(AVG(cpu_usage_per_sec), 2) AS avg_cpu_usage_per_sec,
                    ROUND(AVG(cpu_usage_per_sec) / cpu_count.num_cpus * 100, 2) AS avg_cpu_percent
                  FROM cpu_per_snapshot,
                       cpu_count
                  GROUP BY snap_id, begin_interval_time, end_interval_time, cpu_count.num_cpus
                  ORDER BY snap_id;
EOF
	} >$rootDir/tmp/perf222

	if [ "$show_data" != "Y" ]; then
		return
	fi

	mhead "Perfdata $dbname"
	show_screen "$rootDir/tmp/perf221" "$rootDir/tmp/perf221out" "DBNAME,PDBNAME,PGA_SIZE,SGA_SIZE,ALLOC_GB,USED_GB,MAX_CPU" "20,20,9,9,9,9,9" "DO" "1,2,3,4,5,6,7" "|" "--limit=1" 1 25 "Y"
	sed -i 's/^/  /' $rootDir/tmp/perf222
	cat $rootDir/tmp/perf222

	read -p "<--press return-->" xx

}

check_terminal_size() {
	local MIN_COLS=150
	local MIN_LINES=40
	local cols lines

	while true; do
		cols=$(tput cols)
		lines=$(tput lines)

		if ((cols >= MIN_COLS && lines >= MIN_LINES)); then
			return 0
		else
			echo "⚠️ Terminal size too small: ${cols}x${lines} (need at least ${MIN_COLS}x${MIN_LINES})"
			echo "🔁 Please resize your terminal window and press [Enter] to re-check."
			echo "💡 Or press [Enter] without resizing to continue anyway (not recommended)."

			read -rp "Press [Enter] to check again or 'c' for continue" antw

			if [ "$antw" == "c" ]; then
				break
			fi
		fi
	done
}

run_sqlplus() {
	local sqlc="$1"
	local sqlf="$2"
	export sqlres=""

	sqlerr=0
	sqlres=$(
		sqlplus -s /@mondbp_mig <<EOF
     set heading off feedback off pagesize 0 
     set verify off linesize 32767 trims on termout on
     sta $sqlf;
     commit;
     exit;
EOF
	)
	if [ $(echo $sqlres | grep -i "ora-" | wc -l) -gt 0 ]; then
		sqlerr=1
		echo "sqlerr ... please verf code $sqlc"
		sleep 3
	fi
}

function askDau() {
	local menubar=$1

	local cdr=$($pwd)
	cd $rootDir/scripts
	echo
	hmenu "${menubar}"

	dauResponse=$input
	export $dauResponse
	cd $cdr
}

function set_current_cluster() {

	local sqlf="$rootDir/tmp/curcl.$$"

	cat <<EOF >$sqlf
	SELECT
    to_number(substr("MODERNEX Migration Cluster",9,2)) as cl
FROM (
    SELECT
        "MODERNEX Migration Cluster",
        "MODERNEX Migration Cluster Start Date"
    FROM
        masterdata.modernex_mig_cluster
    WHERE
        "MODERNEX Migration Cluster" LIKE 'Cl%'
        AND SYSDATE BETWEEN "MODERNEX Migration Cluster Start Date" AND "MODERNEX Migration Cluster End Date"
    ORDER BY
        "MODERNEX Migration Cluster Start Date" DESC
)
WHERE ROWNUM = 1;
EOF

	run_sqlplus "set_cluster" $sqlf

	export run_cluster=$(echo $sqlres | tr -d " ")

	echo
	echo "Set cluster to Cluster $run_cluster"
	sleep 2

}

function check_ws() {

	local rdir=$1
	local wsnr=$2
	local d1 cwsnr
	d1=$(dirname $rdir)
	cwsnr=$(basename $d1)

	if [ ! -d $rdir ] || [ $cwsnr -ne $wsnr ]; then
		echo "internal eror - wong ws assigment - exiting!"
		sleep 5
		exit 2
	fi
}

create_new_workspace() {

	local ws_user=$1
	local ws_nr=$2

	ws_error() {
		local ret=$1
		local etxt=$2

		if [ $ret -ne 0 ]; then
			echo "ws creation int. error: ${etxt}"
			sleep 5
			cleanup
		fi
	}

	mkdir -p ${HOME}/${ws_nr}/premigration
	ws_error $? "mkdir"
	cd ${HOME}/${ws_nr}/premigration
	cp ${HOME}/latest/premigration.env .
	ws_error $? "migenv"

	for d in tmp/tmp results/tufin results/tmp mailbox/tosend mailbox/tmp mailbox/sent dialog/tmp cpat/tmp cpat/instant_runs configfiles/tufin configfiles/tmp configfiles/seps_wallet configfiles/psrcnfs configfiles/poggsrc configfiles/ocinfs configfiles/dbinfos; do
		mkdir -p ./$d
		ws_error $? "mkdir $d"
	done

	find ${HOME}/latest/configfiles -maxdepth 1 -type f -exec cp -t ./configfiles {} +
	ws_error $? "conf"

	for l in oracle scripts sqls cpat25.2; do
		ln -s ${HOME}/latest/$l ./$l
		ws_error $? "lnk $l"
	done

	cd ${HOME}/${ws_nr}/premigration/scripts
	ws_error $? "goto new env"

	$rootDir/premigration.env
	echo "ws created	..."
	sleep 3
}

assign_cpat_selection() {
	local dbprimkey="$1"
	local schemafile="$2" # adjust if needed
	local DMP_SHARED_SELECTED=""
	local input

	if [[ ! -f "$schemafile" ]]; then
		echo "Schema file not found: $schemafile"
		sleep 2
		return
	fi

	while true; do

		askDau "[q]quit,[a]assignCpat,[r]removeCurrent"

		case $input in
		quit)
			echo -e "\nAborted. No changes made."
			sleep 2
			return
			;;
		assignCpat)
			echo
			echo "Available Schemas:"
			echo "------------------"

			DMP_SHARED_SELECTED=$(gum choose --output-delimiter=" " --no-limit --height=15 <$schemafile)

			echo
			echo "Selected schemas: $DMP_SHARED_SELECTED"

			gum confirm $confirm_params \
				"confirm? " || break

			echo "Storing in CMDB..."
			cd $rootDir/scripts
			./fetch_cmdb_data.sh update_cpat "$dbprimkey" "$DMP_SHARED_SELECTED"
			./fetch_cmdb_data.sh appinfos
			break
			;;
		removeCurrent)
			echo "Storing in CMDB..."
			cd $rootDir/scripts
			./fetch_cmdb_data.sh update_cpat "$dbprimkey" ""
			./fetch_cmdb_data.sh appinfos
			break
			;;
		esac
	done

}

load_app_data() {
	local pk="$1"

	$rootDir/scripts/fetch_cmdb_data.sh appinfos_pk $pk $rootDir/tmp/${pk}_app_data.csv

	if [ $(cat $rootDir/tmp/${pk}_app_data.csv | grep $pk | wc -l) -ne 1 ]; then
		echo "Error loading app data for pk=$pk"
		exit 1
	fi

	dbmp_app_name=""
	selected_line=$(cat $rootDir/tmp/${pk}_app_data.csv | grep $pk)
	if [[ -z "$selected_line" ]]; then
		echo "Error loading app data for pk=$pk - line rror"
		sleep 3
		return
	else
		IFS='|' read -r \
			dbmp_target_platform dbmp_target_name dpmp_target_migr_methode \
			dbmp_test_tns_alias dbmp_oracle_db dbmp_env dbmp_dataclass dbmp_vnet \
			dbmp_app_name DBMP_ENV_ORIG DBMP_SHARED dbmp_target_tns_alias dbmp_migcluster \
			dbmp_primkey dbmp_target_env dbmp_nfs_ip dbmp_nfs_name dbmp_nfs_share BMP_NFS_MP dns_name src_ip AS csv_output <<<"$selected_line"

	fi
}

change_assign_nc() {
	#############
	local dbpk=$1
	local whattodo=$2

	load_app_data $dbpk

	if [ "X$dbmp_app_name" != "X" ]; then

		clear
		mhead "Change $whattodo assignment"
		f1=$(printf "%-30s" "${dbmp_app_name}")
		f2=$(printf "%-25s" "$dbmp_oracle_db")
		f3=$(printf "%-10s" "$dbmp_env")
		f4=$(printf "%-15s" "$src_ip")
		f5=$(printf "%-20s" "$dbmp_target_name")

		printf "%-30s %-25s %-10s %-15s %-20s\n" "  Appl" "  srcDB" "  env" "  srcip" "  tgtdb"
		echo "  ------------------------------------------------------------------------------------------------"
		echo -e "  ${CYAN}$f1 $f2 $f3 $f4 $f5 $EC_NC"
		echo
		echo " "

		case $whattodo in
		nfs) echo "Current nfs server assigned: ${dbmp_nfs_ip:-<none>}" ;;
		cpat) echo "Current cpat schemas assigned: ${DBMP_SHARED:-<none>}" ;;
		esac

		gum confirm $confirm_params \
			"go ahead and cheange?" || return

		case $whattodo in
		nfs) fetch_nfs "SEL" $dbmp_primkey "$dbmp_nfs_ip" ;;
		cpat) update_cpat_selection $dbmp_primkey "$dbmp_oracle_db" ;;
		esac

	fi
}

change_cpat_schemas() {

	local cluster="$1"

	clear
	gum style --foreground=$AC_RED --background=$AC_BLACK \
		--border rounded --margin "1 2" --padding "1 3" \
		--align center --width 100 --bold \
		"Change CPAT Schemas to be analyzed for $appln"

	gum style --foreground=$AC_YELLOW --background=$AC_BLACK \
		--align left --width 150 --bold \
		--margin "1 2" --padding "1 3" \
		"currently assigned: $cpatinfo"
	#    select_one_appinfo2 $run_cluster $dbprimkey "N"

	update_cpat_selection "$dbprimkey" "$oracledb"
}

function fetch_nfs() {

	local selectnfs=$1
	local appkey=$2
	local currnfs=$3
	local nfskey=""
	local showf1="$rootDiir/tmp/nfsf1.$gpid"
	local showf2="$rootDiir/tmp/nfsf2.$gpid"

	./fetch_cmdb_data.sh select_nfs
	local inputFile="$rootDir/configfiles/deployed_nfs.env"
	local -A seen_ips # Assoziatives Array zum Verfolgen der bereits gesehenen IPs

	>$showf1
	while IFS=',' read -r id name art platform _env _conf export ip; do
		if [[ -z "${seen_ips[$ip]}" ]]; then
			seen_ips["$ip"]=1

			# Port 2049 prüfen – Timeout 1 Sekunde
			if nc -z -w 1 "$ip" 2049 2>/dev/null; then
				reachable="yes"
			else
				reachable="no"
			fi

			echo "$id|$name|$art|$platform|$export|$ip|$reachable" >>$showf1
			total=$id
		fi
	done <"$inputFile"

	>$showf2
	if [ "X$selectnfs" != "XSEL" ]; then
		show_screen "$showf1" "$showf2" "ID,Name,Art,Plattf,Export,IP,Reachable" "2,40,5,6,25,15,10" "DO" "1,2,3,4,5,6,7" "|" "--limit=1" 1 25 "Y"
		return
	else
		while true; do

			askDau "[q]quit,[a]assignNfs,[r]removeCurrent"

			case $input in
			quit)
				echo -e "\nAborted. No changes made."
				sleep 2
				return
				;;
			assignNfs)
				>$showf2
				show_screen "$showf1" "$showf2" "ID,Name,Art,Plattf,Export,IP,Reachable" \
					"2,40,5,6,25,15,10" "SEL" "1,2,3,4,5,6,7" "|" "--limit=1" 1 25 "Y"

				if [ -s $showf2 ]; then
					sel_server=$(cat $showf2 | cut -d"|" -f6)
					nfskey=$(cat $showf2 | cut -d"|" -f1)
				else
					echo "no selection"
				fi

				break
				;;
			removeCurrent)
				echo "server will be removed"
				nfskey=0
				sleep 2
				break
				;;
			esac
		done

		if [ "X$nfskey" != "X" ]; then
			echo "Storing in CMDB..."
			cd $rootDir/scripts
			./fetch_cmdb_data.sh update_nfs "$appkey" "$nfskey"
			./fetch_cmdb_data.sh appinfos
		fi
	fi
}

update_cpat_selection() {
	local primkey="$1"
	local srcdb="$2"
	local dbinfoDir="$rootDir/configfiles/dbinfos"
	local src_tns="${2}_system"
	local src_connect="/@$src_tns"
	local schema_file="$rootDir/configfiles/dbinfos/${srcdb}_schemas.env"

	cd $rootDir/scripts
	./fetch_cmdb_data.sh "src_schemas" "$srcdb" "$src_connect"

	if [ ! -s $schema_file ]; then
		echo "read dbinfos has errors - schemafile "
		sleep 2
		return
	fi

	assign_cpat_selection $primkey $schema_file

}

function select_schematas() {

	local app_in_scope=$1
	local cpfile=$2

	echo "not implemented yet..use func in main menu instead"
	read -p "<---Press return-->" xx
	return

}

run_cpat() {
	local clnr="$!"
	local selectedf="$rootDir/tmp/selcpat1.$$"
	local selectedf2="$rootDir/tmp/selcpat2.$$"
	local seldbs=""
	local anz_dbs=0
	local sqlf=$rootDir/tmp/sql_for_cpat.$$
	local dispf=$rootDir/tmp/choose.$$
	local cpatsw="$rootDir/configfiles/cpatsw.tar"
	local ldat=$(date +"%Y%m%d-%H%M%S")
	local running_cpats="$rootDir/configfiles/running_cpats.$ldat"
	local line=""
	local schematas_file="$rootDir/tmp/schematas.$$"
	local fcolor=$'\033[0;31m' # rot für FAIL
	local ecolor=$'\033[0;36m' # gelb für EX
	local ocolor=$'\033[0;32m' # grün für OK
	local reset=$'\033[0m'     # zurücksetzen

	clear
	mhead "select apps for cpatt..."
	select_appinfo2 $run_cluster $read_only_N $read_cmdb_N $page $sel_multi_Y "noinput" "$selectedf"

	if [ $(wc -c <"$selectedf") -lt 10 ]; then
		#echo "no dbs selected..."
		return
	fi

	anz_dbs=$(cat $selectedf | wc -l)
	if [ $anz_dbs -eq 0 ]; then
		#echo "no DBs selected..."
		return
	fi

	clear
	mhead
	select_appinfo2 $run_cluster $read_only_Y $read_cmdb_N 1 $sel_multi_Y "$selectedf" "$selectedf2"

	echo
	gum confirm $confirm_params \
		"Run cpat for $anz_dbs dbs?" || return

	echo " "
	schematas="Y"
	gum confirm $confirm_params \
		"would you like to select schematas for some dbs?" || schematas="N"

	if [ "$schematas" == "Y" ]; then

		clear
		mhead
		select_appinfo2 $run_cluster $read_only_N $read_cmdb_N 1 $sel_multi_Y "$selectedf" "$selectedf2"

		for dbmp in $(cat $selectedf2 | cut -d "|" -f3); do
			odb=$(cat $selectedf2 | grep $dbmp | cut -d "|" -f6)
			echo "--------------------------------------"
			echo "select for $dbmp $odb"
			update_cpat_selection $dbmp "$odb"
		done

	fi

	$rootDir/scripts/fetch_cmdb_data.sh cpatschematas $schematas_file
	dblinks="Y"

	gum confirm $confirm_params \
		"Want to create DB-link template as well?" || dblinks="N"

	clear
	mhead
	echo

	echo -e "$EC_YELLOW  ---------------------------Started cpat runs - pleas be patient ---------------------------$NC"
	sleep 2

	for indx in $(seq 1 $anz_dbs); do
		#awhile read -r _nr _cluster odb  sip _odbpk  osid _rest; do

		line=$(awk "NR == $indx" $selectedf)
		odb=$(echo $line | cut -d "|" -f6)
		odp=$(echo $line | cut -d "|" -f3)

		srcdb="$odb"
		cpat_dir="$rootDir/cpat25.2"
		cpatResultDir="$rootDir/cpat/tmp/cpat$$"
		cpatFinalResultDir="$rootDir/cpat/results/cluster_${run_cluster}"

		mkdir -p $cpatResultDir $cpatFinalResultDir &>/dev/null

		cpatschemas=""
		schematas=$(cat $schematas_file | grep "^$odp" | head -1 | cut -d "|" -f2)

		if [ "X$schematas" != "X" ]; then
			cpatschemas="--schema $schematas"
		fi

		offstat="EERROR"
		onstat="EERROR"
		onc="$fcolor"
		offc="$fcolor"
		dblc="$fcolor"

		cat <<EOF >$rootDir/tmp/cpat.sh
		        {
                         cd $rootDir/scripts
                         source ../premigration.env
	                 export JAVA_TOOL_OPTIONS="-Doracle.net.wallet_location=(SOURCE=(METHOD=FILE)(METHOD_DATA=(DIRECTORY=$HOME/.orawallet)))"
                  	 export JAVA_TOOL_OPTIONS="\$JAVA_TOOL_OPTIONS -Doracle.net.tns_admin=$TNS_ADMIN"
             
                         gg=""
                         for stat in offline online; do
			    ${cpat_dir}/premigration.sh \\
				--connectstring "jdbc:oracle:thin:@${srcdb}_system" \\
				--targetcloud ATPS $cpatschemas \\
				--outfileprefix ${srcdb}_\$stat \\
				--analysisprops "${cpat_dir}/properties/premigration_advisor_analysis.properties" \\
				--reportformat html \\
				--migrationmethod DATAPUMP \$gg \\
				--outdir "$cpatResultDir" 
			    gg="GOLDENGATE"
		        done  
		        } &>$rootDir/tmp/cpat.out
EOF
		chmod +x $rootDir/tmp/cpat.sh
		$rootDir/tmp/cpat.sh &
		prcid=$!
		laufzeit=0
		while kill -0 $prcid 2>/dev/null; do
			sleep 5
			laufzeit=$((laufzeit + 5))
			printf "\r  %s  cpat for %-22s lz: %4d sec %s" \
				"$ecolor" "${odb:0:20}" "$laufzeit" "$reset"
		done

		{

			if [ -f "$cpatResultDir/${srcdb}_online_premigration_advisor_report.html" ]; then
				mv "$cpatResultDir/${srcdb}_online_premigration_advisor_report.html" $cpatFinalResultDir
				mv "$cpatResultDir/${srcdb}_online_premigration_*.log" $cpatFinalResultDir
				onstat="OK"
				onc="$ocolor"
			fi

			if [ -f "$cpatResultDir/${srcdb}_offline_premigration_advisor_report.html" ]; then
				mv "$cpatResultDir/${srcdb}_offline_premigration_advisor_report.html" $cpatFinalResultDir
				mv "$cpatResultDir/${srcdb}_offline_premigration_*.log" $cpatFinalResultDir
				offstat="OK"
				offc="$ocolor"
			fi

			dblstat="NOT REQ."
			if [ "$dblinks" == "Y" ]; then
				dblstat="ERROR"

				{
					sqlplus -s /@${srcdb}_system <<EOF
      set heading off feedback off pagesize 0
     set verify off linesize 32767 trims on termout on
 
       sta $rootDir/sqls/create_dblinks_template.sql
      
       exit;
EOF
				} >"$cpatResultDir/${srcdb}_dblink_template.txt"

				if [ -f "$cpatResultDir/${srcdb}_dblink_template.txt" ]; then
					mv "$cpatResultDir/${srcdb}_dblink_template.txt" $cpatFinalResultDir
					dblstat="OK"
					dblc="$ocolor"
				fi
			fi

			if [[ "$(dirname "$cpatResultDir")" == "$rootDir/tmp" && -d "$cpatResultDir" ]]; then
				rm -rf "$cpatResultDir"
			fi
		} &>$rootDir/tmp/cpat.out

		mv $rootDir/tmp/cpat.out $cpatFinalResultDir/zz${ldat}_cpatrun.log

		printf "\r  %s  cpat for %-22s lz: %4d sec%s; Status OFF: %s%-6s%s ON: %s%-6s%s DBL: %s%-6s%s \n" \
			"$ecolor" "${odb:0:20}" "$laufzeit" "$reset" "$offc" "$offstat" "$reset" "$onc" "$onstat" "$reset" "$dblc" "$dblstat" "$reset"
		cd $rootDir/scripts

	done

	echo -e "$EC_YELLOW  ------------------------------------FINISHED-----------------------------------------------$NC"
	echo -e "$EC_GREEN   generated files could be send via $NC'[x]SendCpats' ${EC_GREEN}on main menu $NC"
	read -p "  <-Press enter->" cmd

}

function show_app_migs() {
	local applfile="$1"
	local cnt=0
	local appanz=$(wc -l <$applfile)
	local fcolor=$'\033[0;31m' # rot für FAIL
	local ecolor=$'\033[0;36m' # gelb für EX
	local ocolor=$'\033[0;32m' # grün für OK
	local reset=$'\033[0m'     # zurücksetzen

	for appl_pk in $(cat $applfile | cut -d "|" -f3); do
		let cnt=${cnt}+1

		app_name=$(cat $applfile | grep $appl_pk | cut -d "|" -f4 | tr " " "_")
		app_env=$(cat $applfile | grep $appl_pk | cut -d "|" -f5)
		srcdb=$(cat $applfile | grep $appl_pk | cut -d "|" -f6)
		srcip=$(cat $applfile | grep $appl_pk | cut -d "|" -f13)
		tgtdb=$(cat $applfile | grep $appl_pk | cut -d "|" -f9)

		f1=$(printf "%-30s" "${app_name}")
		f2=$(printf "%-25s" "$srcdb")
		f3=$(printf "%-10s" "$app_env")
		f4=$(printf "%-15s" "$srcip")
		f5=$(printf "%-20s" "$tgtdb")

		printf "%-30s %-25s %-10s %-15s %-20s\n" "  Appl" "  srcDB" "  env" "  srcip" "  tgtdb"
		echo "  ------------------------------------------------------------------------------------------------"
		echo -e "  ${CYAN}$f1 $f2 $f3 $f4 $f5"
		echo

		fetch_migdata "$tgtdb"

		askDau "[q]ReturnToMain,[s]NextApp"
		if [ "$dauResponse" == "ReturnToMain" ]; then
			break
		fi
		clear
		mhead "show migrations...."

	done
}

function show_srcmounts() {

	local applfile="$1"
	local cnt=0
	local appanz=$(wc -l <$applfile)
	local fcolor=$'\033[0;31m' # rot für FAIL
	local ecolor=$'\033[0;36m' # gelb für EX
	local ocolor=$'\033[0;32m' # grün für OK
	local reset=$'\033[0m'     # zurücksetzen

	clear
	mhead "show mounts on src db srv...."

	for appl_pk in $(cat $applfile | cut -d "|" -f3); do
		let cnt=${cnt}+1

		app_name=$(cat $applfile | grep $appl_pk | cut -d "|" -f4 | tr " " "_")
		app_env=$(cat $applfile | grep $appl_pk | cut -d "|" -f5)
		srcdb=$(cat $applfile | grep $appl_pk | cut -d "|" -f6)
		srcip=$(cat $applfile | grep $appl_pk | cut -d "|" -f13)

		senv="DTQC"
		if [ "$app_env" == "Production" ]; then
			senv="Prod"
		fi

		cd "$rootDir/scripts"
		printf "%-22s %-6s %-22s %-14s\n" "${app_name:0:20}" "$senv" "${srcdb:0:20}" "$srcip"

		timeout 3 ssh "$srcip" "mount | grep -i \" type nfs\"" >$rootDir/tmp/mounts1.$gpid </dev/null
		anz_lines=$(wc -l <$rootDir/tmp/mounts1.$gpid)
		>$rootDir/tmp/mounts2.$gpid
		for i in $(seq 1 "$anz_lines"); do
			line=$(awk -v lineno="$i" 'NR == lineno {print $0}' "$rootDir/tmp/mounts1.$gpid")
			share=$(echo $line | awk '{print $1}')
			mp=$(echo $line | awk '{print $3}')
			opt=$(echo $line | awk '{print $6}')
			echo "${share:0:30}|${mp:0:30}|${opt:0:50}" | tr -d " " >>$rootDir/tmp/mounts2.$gpid
		done

		show_screen "$rootDir/tmp/mounts2.$gpid" "./out" "Share,Mountp,Options" "32,32,52" "DO" "1,2,3" "|" "--no-limit" 1 55 "N"

		echo
		menubar="[n]nextApp,[q]quit"
		hmenu "${menubar}"

		case $input in

		nextApp) continue ;;
		*) break ;;

		esac

	done
}

function run_tests() {

	local applfile="$1"
	local testcases="$2"
	local jnr=$(date +"%Y%m%d%H%M%S")
	local cnt=0
	local appanz=$(wc -l <$applfile)
	local runlogDir="$rootDir/tmp/$jnr"

	# Farben definieren
	local fcolor=$'\033[0;31m' # rot für FAIL
	local ecolor=$'\033[0;36m' # gelb für EX
	local ocolor=$'\033[0;32m' # grün für OK
	local reset=$'\033[0m'     # zurücksetzen

	clear
	mhead "selected apps to test...."

	select_appinfo2 $run_cluster "Y" "N" 1 "N" "$applfile" "$rootDir/tmp/nix"
	echo
	echo "Runing this Tests"
	cat $testcases
	echo
	gum confirm $confirm_params \
		"confirm?" || return

	tests_to_run=$(cat $testcases | cut -d',' -f1 | paste -sd' ' -)
	clear
	mhead "Running test for job $jnr in background ... please be patient"

	mkdir $runlogDir
	for appl_pk in $(cat $applfile | cut -d "|" -f3); do
		let cnt=${cnt}+1

		app_name=$(cat $applfile | grep $appl_pk | cut -d "|" -f4 | tr " " "_")
		app_env=$(cat $applfile | grep $appl_pk | cut -d "|" -f5)

		senv="DTQC"
		if [ "$app_env" == "Production" ]; then
			senv="Prod"
		fi

		cd "$rootDir/scripts"
		printf "%-22s %-6s" "${app_name:0:20}" "$senv"

		"$rootDir/scripts/zdm_premigrationv2.sh" -l "$cnt" -j "$jnr" -r "$run_cluster" -n m -b "$appl_pk" -m "$mail_to" -t "$tests_to_run" -o "${runlogDir}/${app_name}_zdmpremig.log" &>"${runlogDir}/${app_name}.log" &
		prcid=$!

		laufzeit=0
		remove_runlog=1

		printf "\e[?25l"

		while kill -0 $prcid 2>/dev/null; do
			sleep 5
			laufzeit=$((laufzeit + 5))
			printf "\r%-22s %-6s job activ,    lz: %4d sec   " "${app_name:0:20}" "$senv" "$laufzeit"

			#	printf "\033[1A\033[1G"
			#	printf "\r%-30s %-10s" "$app_name" "$senv"
			#        } > $rootDir/tmp/$app_name.zdmout

			cd $rootDir/results/${jnr}_${app_name}.${senv} &>/dev/null
			if [ $? -ne 0 ]; then
				echo "no Results - no resultdir ${jnr}_${app_name}.${senv}"
				continue
			fi

			{
				results=$(ls -1 *.result 2>/dev/null)
				ret=$?
			} &>/dev/null

			if [ $ret -eq 0 ]; then
				for rfile in $results; do
					rnum=$(cut -d ";" -f 1 "$rfile" | tr -d " ")
					stat=$(cut -d ";" -f 2 "$rfile" | tr -d " ")
					#    echo "$rnum"

					no_results=""
					case "$stat" in
					"PASSED")
						color="$ocolor"
						label="OK"
						;;
					"EXCEPTION")
						remove_runlog=0
						color="$fcolor"
						color="$ecolor"
						label="EX"
						;;
					"--FAILED---")
						remove_runlog=0
						color="$fcolor"
						label="FAIL"
						;;
					*)
						remove_runlog=0
						color="$fcolor"
						color="$reset"
						label="$stat"
						;;
					esac

					printf "%s%-10s%s" "$color" "${rnum}:$label" "$reset"
				done
			else
				remove_runlog=0
				no_results="--NR--"
			fi
		done

		printf "\r%-22s %-6s job finished, lz: %4d sec  %s " "${app_name:0:20}" "$senv" "$laufzeit" "$no_results"
		printf "\e[?25h"

		echo ""
		#üü		if [ $remove_runlog -eq 1 ]; then
		#			curDir=$(pwd)
		#			cd $runlogDir
		#ü			rm -f ${app_name}.log
		#			cd $curDir
		#		fi
	done

	#if [ $(find . -type f -name "*.log" -size +0c | wc -l) -gt 0 ]; then

	see_logs=1
	gum confirm $confirm_params \
		"Do you want to check logfiles of failed runs?" || see_logs=0

	if [ "$see_logs" == "1" ]; then

		>$rootDir/tmp/brdir.${gpid}
		cd $rootDir/results
		for logd in $(ls -l | awk '{print $9}' | grep "^$jnr"); do

			echo "$rootDir/results/$logd" >>$rootDir/tmp/brdir.${gpid}
		done

		browse_files "$rootDir/tmp/brdir.${gpid}"
	fi
	#	fi
	cd $rootDir/scripts

	#	read -p "<--press return-->"
}

function browse_files() {

	local brdir=$1
	local sc1="$rootDir/tmp/screen1.$gpid"
	local sc2="$rootDir/tmp/screen2.$gpid"
	local sc3="$rootDir/tmp/screen3.$gpid"
	cat $brdir

	curdir=$(pwd)

	clear
	mhead "Browse Results"
	>$sc1
	show_screen "$brdir" "$sc1" "Dir" "92" "sel" "1" "|" "--no-limit" 1 25 "N"
	for dir in $(cat $sc1); do
		cd $dir
		ls -l  | awk '{print $9}' >$sc2
		while true; do
			cd $dir
			show_screen "$sc2" "$sc3" "File" "92" "sel" "1" "|" "--no-limit" 1 25 "N"

			for file in $(cat $sc3); do

				cat $file
				read -p "<--press return-->"
			done

			cdr=$($pwd)
			cd $rootDir/scripts
			echo
			menubar="[q]quit,[s]selectAgain"
			hmenu "${menubar}"

			case $input in

			selectAgain)
				cd $cdr
				clear
				mhead "Select Files"
				continue
				;;
			*) break ;;

			esac
		done
	done

	cd $curdir
}

list_jobresults() {

	fcolor=$'\033[0;33m'
	ecolor=$'\033[0;36m'
	reset=$'\033[0m'

	resultDir=${rootDir}/results

	if [[ -z "$resultDir" ]]; then
		echo "Error: resultdir (parameter 1) must be specified."
		echo "Usage: list_jobresults <resultdir>"
		return 1
	fi

	if [[ ! -d "$resultDir" ]]; then
		echo "Error: Directory '$resultDir' does not exist or is not a directory."
		return 1
	fi

	echo "Searching for job numbers in: $resultDir"

	# Find directory names starting with 20*, extract job numbers
	mapfile -t jobdirs < <(find "$resultDir" -maxdepth 1 -type d -printf "%f\n" | grep '^20' | cut -d_ -f1 | sort -ur)

	if [[ ${#jobdirs[@]} -eq 0 ]]; then
		echo "No job numbers found."
		return 0
	fi

	echo ""
	echo "Found job numbers:"

	echo "" >$rootDir/tmp/brf$$
	{
		for i in "${!jobdirs[@]}"; do

			printf "%s\n" "${jobdirs[$i]}"
		done
	} >>$rootDir/tmp/brf$$

	echo ""

	selected_job=$(gum choose --output-delimiter=" " --height=15 <$rootDir/tmp/brf$$ | tr -d " ")

	echo "Selected job number: $selected_job"

	echo ""
	echo "Results:"
	resf="/tmp/result_$$"
	nrf="/tmp/nrf_$$"
	>$resf
	>$nrf

	curdir=$(pwd)

	# Farben definieren
	fcolor=$'\033[0;31m' # rot für FAIL
	ecolor=$'\033[0;36m' # gelb für EX
	ocolor=$'\033[0;32m' # grün für OK
	reset=$'\033[0m'     # zurücksetzen

	# Schleife für Result-Ordner
	local brdir="$rootDir/tmp/browsedirs$$.log"
	>$brdir
	for rdir in $(find "$resultDir" -maxdepth 1 -type d -name "${selected_job}_*"); do
		app_name=$(basename "$rdir")
		printf "%-60s" "$app_name" >>"$resf"
		cd "$rdir" || continue

		{
			results=$(ls -1 *.result 2>/dev/null)
			ret=$?
		} &>/dev/null

		if [ $ret -eq 0 ]; then
			for rfile in $results; do
				rnum=$(cut -d ";" -f 1 "$rfile" | tr -d " ")
				stat=$(cut -d ";" -f 2 "$rfile" | tr -d " ")
				echo "$rnum" >>"$nrf"

				case "$stat" in
				"PASSED")
					color="$ocolor"
					label="OK"
					;;
				"EXCEPTION")
					color="$ecolor"
					label="EX"
					;;
				"--FAILED---")
					color="$fcolor"
					label="FAIL"
					;;
				*)
					color="$reset"
					label="$stat"
					;;
				esac
				printf "%s%-10s%s" "$color" "${rnum}:$label" "$reset" >>"$resf"
			done
			echo "$rdir" >>"$brdir"
		else
			printf "%-25s" "No Results found" >>"$resf"
		fi

		echo "" >>"$resf"
	done

	cd $curdir
	cat $nrf | sort -u >nr$$
	mv nr$$ $nrf
	./fetch_cmdb_data.sh testcases

	echo " " >>$resf
	echo "Legend:" >>$resf
	for tnr in $(cat $nrf); do
		txt=$(cat $rootDir/configfiles/testcases.csv | grep "$tnr" | cut -d ":" -f 3)
		echo "$tnr ... $txt" >>$resf
	done
	cat $resf

	if [ -s "$brdir" ]; then

		echo
		brf=1
		gum confirm $confirm_params \
			"DO you want to browse logfiles? " || brf=0
		if [ "$brf" == "1" ]; then
			browse_files "$brdir"
		fi
	fi
}

disp_nfs() {

	local inputFile="$rootDir/configfiles/deployed_nfs.env"
	declare -A seen_ips

	if [ $cnt2 -gt 0 ]; then

		for i in $(seq 1 "$cnt2"); do
			printf "\033[1A\033[1G"
			cnt2=0
		done
		printf "\r"

	fi
	printf "%-3s %-35s %-5s %-6s %-20s %-15s %-10s %8s %10s %12s %12s\n" \
		"ID" "Name" "Art" "Plattf" "Export" "IP" "Reachable" "CPU%" "TPS" "KB read/s" "KB wr/s"

	printf "%s\n" "-----------------------------------------------------------------------------------------------------------------------------------------------------"

	#  printf "%-3s %-35s %-5s %-6s %-25s %-15s %-10s %-10s %-10s %-10s %-10s\n" \
	#      "ID" "Name" "Art" "Plattf" "Export" "IP" "Reachable" "cpu%" "TPS" "KB read/s" "KB wr/s"
	#  printf "%s\n" "--------------------------------------------------------------------------------------------------------------------------------------------------"

	local cnt=2
	while IFS=',' read -r id name art platform _env _conf export ip || [ -n "$id" ]; do
		ipsh=$ip$exprt
		[[ -z "${seen_ips[$ipsh]}" ]] || continue
		seen_ips["$ipsh"]=1

		mp="/mnt/nfs"
		[[ "$platform" == "ATPS" ]] && mp="/sa4zdmfs"

		if nc -z -w 1 "$ip" 2049 2>/dev/null; then
			reachable="yes"

			nuser="nfs"
			#      clname=$(echo $name | cut -d "-"  -f1)
			if [ "$(echo $name | cut -d'-' -f1)" == "clu1" ]; then
				nuser="opc"
			fi

			get_remote_stats "$ip" "$nuser" "$HOME/.ssh/oci_rsa" </dev/null
		else
			reachable="no"
			REMO
			TE_CPU_USAGE="n/a"
			REMOTE_TPS="n/a"
			REMOTE_RKBP="n/a"
			REMOTE_WKBP="n/a"
		fi

		# Function to format a value as MB if > 10000

		printf "%-3s %-35s %-5s %-6s %-20s %-15s %-10s %8s %10s %12s %12s\n" \
			"$id" "$name" "$art" "$platform" "$export" "$ip" "$reachable" \
			"$REMOTE_CPU_USAGE" "$REMOTE_TPS" "$REMOTE_RKBP" "$REMOTE_WKBP"

		#   printf "%-3s %-35s %-5s %-6s %-25s %-15s %-10s %-10s %-10s %-10s %-10s\n" \
		#      "$id" "$name" "$art" "$platform" "$export" "$ip" "$reachable" "$REMOTE_CPU_USAGE" "$REMOTE_TPS" "$REMOTE_RKBP" "$REMOTE_WKBP"
		((cnt++))
	done <"$inputFile"
	cnt2=$cnt
}

show_migdata_phase() {

	local fil=$1
	local log=$2

	dlne=$(cat $file2)
	hst=$(echo $dlne | awk '{print $3}')
	jnr=$(echo $dlne | awk '{print $4}')

	local file="$rootDir/configfiles/zdmmiginfos_ph.env"
	local file2="$rootDir/tmp/zdmmiginfos_ph.$$"

	./fetch_cmdb_data.sh migdbinfos_ph $hst $jnr

	mhead "Mig Phasen"
	cat $fil
	echo

	show_screen "$file" "$file2" \
		"HOST,JOBNR,LFNR,PHASE,RTSEC,RTFMT,STAT" \
		"15,7,5,38,4,10,22" \
		"DO" "1,2,3,4,5,6,7" "|" "--limit=1" 1 25 "N"

}

check_tns_connect() {

	local tns=$1
	dbconn=$(
		sqlplus -s "/@${tns}" <<'EOF'
                 set heading off feedback off pagesize 0
                                       select 'OK' from dual;
                                        exit;

EOF
	)
	echo $dbconn
}

fetch_migdata() {

	local tgtdb="$1"
	local file="$rootDir/configfiles/zdmmiginfos2.env"
	local file2="$rootDir/tmp/zdmmiginfos.$$"

	cd $rootDir/scripts
	./fetch_cmdb_data.sh migdbinfos2 "$tgtdb"

	if [ ! -s $file ]; then
		echo "no migdata available"
		sleep 2
		return
	fi

	while true; do

		if [ -z $tgtdb ]; then
			clear
			mhead "Select a Migratioin"
		fi

		show_screen "$file" "$file2" "START,HOST,JOBNR,SRCDB,TYPE,STAT,ENDE,RUN,TRGDB" "22,15,6,15,5,5,22,7,15" \
			"SEL" "1,2,3,4,5,6,7,8,9" "|" "--limit=1" 1 25 "N"
		if [ -s $file2 ]; then
			show_migdata_phase $file2 $cmd
		fi
		askDau "[q]ReturnToMain,[s]SelectNewMig"
		if [ "$dauResponse" == "ReturnToMain" ]; then
			break
		fi
		if [ $tgtdb ]; then
			clear
			mhead "Select a Migratioin"
		fi
	done
}
dline() {

	f1=$(printf "%-3s" "$cnt")
	f2=$(printf "%-3s" "$run_cluster")
	f3=$(printf "%-30s" "${dbmp_app_name:0:28}")
	f4=$(printf "%-25s" "$dbmp_oracle_db")
	f5=$(printf "%-15s" "$dbmp_ip")
	f6=$(printf "%-10s" "$ssh_to_src")
	f7=$(printf "%-10s" "$sftp_to_src")
	f8=$(printf "%-10s" "$tns_to_src")
	f9=$(printf "%-14s" "${dbmp_target_name#*_}")
	f10=$(printf "%-10s" "$tns_to_tgt")
	echo -e "${CYAN}$f1 $f2 $f3 $f4 $f5 ${c1}$f6 ${c2}$f7 ${c3}$f8$NC $f9 ${c4}$f10$NC"
	#printf "\033[1A\033[1G"
	#printf "                                                                                                           	"
	#printf "\033[1A\033[1G"
}

fetch_srchost() {
	local cluster_num="$1"
	local appfile=$2
	local cluster="Cluster ${cluster_num}"
	local lines_per_page=30
	local file="$rootDir/configfiles/appinfos.env"
	local failsrcip="$rootDir/tmp/failsrcip.$gpid"
	local failsrcsftp="$rootDir/tmp/failsrcsftpip.$gpid"
	local failsrctns="$rootDir/tmp/failsrctns.$gpid"
	local failtgttns="$rootDir/tmp/failtgttns.$gpid"

	>$failsrcip
	>$failsrcsftp
	>$failsrctns
	>$failtgttns
	>$rootDir/tmp/ssh_to_check.txt
	# Header formatting
	local header_fmt="%-3s %-10s %-35s %-14s %-24s %-30s %-10s %-22s %-20s\n"
	local row_fmt="%-3s %-10s %-28s %-15s %-24s %-15s\n"
	clear

	local row_fmt="%-3s %-10s %-35s %-25s %-15s %-10s %-10s %-10s %-19s ${c4}%-10s$NC"
	local hdr_fmt="%-3s %-3s %-30s %-25s %-15s %-10s %-10s %-10s %-14s %-10s"

	echo -e $YELLOW
	# echo "Total Apps: $total_lines  in Cluster: $cluster_num"
	printf "${hdr_fmt}\n" "Nr" "MC" "App_Name" "Oracle_DB" "IP Address" "ssh?" "sftp?" "tns?" "TargetDb" "t-tns"
	echo -e "-------------------------------------------------------------------------------------------------------------------------------------- $NC "

	local start=$((page * lines_per_page))
	local end=$((start + lines_per_page - 1))
	((end >= total_lines)) && end=$((total_lines - 1))
	local cnt=0
	local cntpg=0

	while IFS='|' read -r \
		dbmp_nr dbmp_migcl dbmp_primkey dbmp_app_name DBMP_ENV_ORIGD dbmp_oracle_db dpmp_target_migr_methode \
		dbmp_target_platform dbmp_target_name dbmp_dataclass DBMP_SHARED dbmp_nfs dbmp_ip; do

		dbmp_target_tns_alias="${dbmp_target_name}_system"
		if [ "$dbmp_target_platform" == "ADB-S" ]; then
			dbmp_target_tns_alias="${dbmp_target_name}_tp"
		fi

		#	1|Cluster 3|9661881|BASF DOCs Report|Development|saportd_lin8985705|log_OFF|ADB-S|ADBSAPORTD|Confidential|---|---|10.3.120.208|
		#       2|Cluster 3|9661884|BASF DOCs Report|Production|saportp_lin8727711|log_ONl|ADB-S|ADBSAPORTP|Confidential|---|---|10.3.120.34|

		let cnt=${cnt}+1
		let cntpg=${cntpg}+1

		ssh_to_src="---"
		c1=$CYAN
		tns_to_src="---"
		c2=$CYAN
		sftp_to_src="---"
		c3=$CYAN
		tns_to_tgt="---"
		c4=$CYAN

		dline
		printf "\033[1A\033[1G"
		#printf "\r${row_fmt}" "$cnt" "$cluster" "$dbmp_app_name" "$dbm_oracle_db" "$dbmp_ip" "$ssh_to_src" "$sftp_to_src" "$tns_to_src" "$dbmp_target_name" "$tns_to_tgt"

		ssh_to_src="ssh_OK "
		c1=$GREEN
		timeout 2 ssh "$dbmp_ip" "pwd" </dev/null &>/dev/null
		if [ $? -ne 0 ]; then
			ssh_to_src="--xx-- "
			echo "$dbmp_ip" >>$failsrcip
			c1=$RED
			echo "$dbmp_ip" >>$rootDir/tmp/ssh_to_check.txt
		fi

		dline
		printf "\033[1A\033[1G"
		#printf "\r${row_fmt}" "$cnt" "$cluster" "$dbmp_app_name" "$dbm_oracle_db" "$dbmp_ip" "$ssh_to_src" "$sftp_to_src" "$tns_to_src" "$dbmp_target_name" "$tns_to_tgt"

		sftp_to_src="sftp_OK "
		c2=$GREEN
		timeout 2 sftp "$dbmp_ip" <<EOF &>/dev/null
quit
EOF
		if [ $? -ne 0 ]; then
			echo "$dbmp_oracle_db" >>$failsrcsftp
			sftp_to_src="--xx-- "
			c2=$RED
		fi
		dline
		printf "\033[1A\033[1G"
		#printf "\r${row_fmt}" "$cnt" "$cluster" "$dbmp_app_name" "$dbm_oracle_db" "$dbmp_ip" "$ssh_to_src" "$sftp_to_src" "$tns_to_src" "$dbmp_target_name" "$tns_to_tgt"

		tns_to_src="tns_OK"
		c3=$GREEN
		timeout 2 tnsping "${dbmp_oracle_db}_system" </dev/null &>/dev/null
		if [ $? -ne 0 ]; then
			echo "$dbmp_oracle_db" >>$failsrctns
			tns_to_src="--xx-- "
			c3=$RED
		fi

		dline
		printf "\033[1A\033[1G"
		#printf "\r${row_fmt}" "$cnt" "$cluster" "$dbmp_app_name" "$dbm_oracle_db" "$dbmp_ip" "$ssh_to_src" "$sftp_to_src" "$tns_to_src" "$dbmp_target_name" "$tns_to_tgt"

		tns_to_tgt="tns_OK"
		c4=$GREEN
		timeout 2 tnsping "${dbmp_target_tns_alias}" </dev/null &>/dev/null
		if [ $? -ne 0 ]; then
			echo "$dbmp_target_name" >>$failtgttns
			tns_to_tgt="--xx-- "
			c4=$RED
		fi

		dline
		#printf "\r${row_fmt}\n" "$cnt" "$cluster" "$dbmp_app_name" "$dbm_oracle_db" "$dbmp_ip" "$ssh_to_src" "$sftp_to_src" "$tns_to_src" "$dbmp_target_name" "$tns_to_tgt"

	done <"$appfile"

	fcnt=0
	for fails in $(echo "$failsrcip" "$failsrcsftp" "$failsrctns" "$failtgttns"); do
		let fcnt=${fcnt}+1

		if [ -s $fails ]; then

			echo
			case $fcnt in
			1) echo "Should i try to fix ssh connection Issue?" ;;
			2) echo "Would you like to fix  sftp issue?" ;;
			3) echo "Should i try to fix onprem tns connection Issue?" ;;
			4) echo "Should i try to fix target tns connection Issue?" ;;
			esac

			askDau "[n]doNotFix,[y]FixIssue"
			if [ "$dauResponse" == "FixIssue" ]; then

				case $fcnt in
				1)
					echo "OK, lets try..."
					for sip in $(cat $failsrcip); do
						$rootDir/scripts/check_ssh_connect.sh -n "$sip" -i "$sip" -u oracle -x no
					done
					;;
				2)
					echo "I only can provide you list:"
					echo -e "$EC_YELLLOW"
					cat "$failsrcsftp"
					echo -e "$EC_NC"
					echo "Please raise a change request"
					;;
				3)
					echo "OK, lets try..."
					cd $rootDir/scripts
					for srcdb in $(cat $failsrctns); do
						$rootDir/scripts/add_seps_cred_batch.sh -a "$srcdb" -b onprem -u system -p y
					done
					;;
				4)
					echo "OK, lets try..."
					local ocif="$rootDir/tmp/ociinfos.${gpid}"
					cd $rootDir/scripts
					$rootDir/scripts/fetch_cmdb_data.sh ociinfos $ocif
					for tgtdb in $(cat $failtgttns); do

						dbtyp=$(cat $ocif | grep -i $tgtdb | head -1 | cut -d"|" -f1)
						dbid=$(cat $ocif | grep -i $tgtdb | head -1 | cut -d"|" -f3)

						if [ ! -z $dbid ]; then
							if [ "$dbtyp" == "PDB" ]; then
								$rootDir/scripts/get_exapdbs.sh $dbid
							else
								$rootDir/scripts/get_tnsadbs.sh $dbid
							fi
						else
							echo "sorry, didn't found oci id"
							sleep 1
						fi
					done
					;;
				esac

			fi
		fi
	done
	echo
	read -rp "press <return> " cmd

}

###########################################
###########################################
# main
###########################################
###########################################

if [ "X$ws_user" == "X" ] ||
	[ "X$ws_nr" == "X" ] ||
	[ "X$mail_to" == "X" ]; then

	echo "u:$ws_user n:$ws_nr e:$mail_to"
	echo -e "$EC_RED Upps ... something went wrong ... internal error @ init $EC_NC"
	sleep 3
	exit 1
fi

if [ "$current_user" != "mig" ]; then
	trap cleanup EXIT INT TERM
fi
if [ ! -d $rootDir ]; then
	create_new_workspace $ws_user $ws_nr
	ws_status="created"
else
	check_ws $rootDir $ws_nr
	ws_status="re-assigned"
fi

cd $rootDir/scripts
source $rootDir/premigration.env
source ${rootDir}/scripts/utils_gum.sh
source ${rootDir}/scripts/utils_adb.sh
source $rootDir/scripts/utils_main_menu.sh
source $rootDir/scripts/utils_mail_cpats.sh

caller_ip=$(echo $SSH_CONNECTION | awk '{ print $1 }')
trace_actions="false"
current_user=$(whoami)
dayfile=$(date +"%Y%m%d")
trace_file="/tmp/premig_traces/${dayfile}_actions.txt"
trace_dir="/tmp/premig_traces"

trace_actions="false"
if [ "$current_user" == "premig" ]; then

	if [ $(echo $SSH_CONNECTION | grep "10.127.123.203" | wc -l) -eq 0 ]; then

		if [ ! -d $trace_dir ]; then
			mkdir $trace_dir
			chmod 777 $trace_dir
		fi

		echo "menu login------------------------------------" >>$trace_file
		echo $(date) >>$trace_file
		echo $SSH_CONNECTION >>$trace_file
		trace_actions="true"

	fi
fi

last_cmdb_refresh=$(
	sqlplus -s /@mondbp_mig <<EOF
     set heading off feedback off pagesize 0
     set verify off linesize 32767 trims on termout on
     SELECT
        TO_CHAR(last_refresh, 'YYYY-MM-DD HH24:MI:SS') AS last_check_datetime
     FROM
        mig_cmdb_refresh
        fetch first row only;
     exit;
EOF
)

export last_cmdb_refresh

#select_migcluster
#export run_cluster=$mig_cluster_num
check_terminal_size
set_current_cluster
show_main_menu
exit 0
