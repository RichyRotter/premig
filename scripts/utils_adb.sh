#/bin/bash
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
	*)
		inftxt="[UNKKOWN:$ltype]" set -x
		sleep 5
		;;
	esac

	if [[ -f $LGfile ]]; then
		{
			if [ "${lact}" == "L" ]; then
				echo ${ldat}"** =========================================================="
				echo ${ldat}"** ${inftxt} ${lmsg}"
				echo ${ldat}"** =========================================================="
				echo " "
			else
				echo ${ldat}"** ${inftxt} ${lmsg}"
			fi
		} >>$LGfile
	else
		if [ "${lact}" == "L" ]; then
			echo ${ldat}"** =========================================================="
			echo ${ldat}"** ${inftxt} ${lmsg}"
			echo ${ldat}"** =========================================================="
			echo " "
		else
			echo ${ldat}"** ${inftxt} ${lmsg}"
		fi

	fi
}

function checkValue() {
	local fn=$1
	local txt=$2
	if [[ "${fn}" == "X" ]]; then
		msg N E "value for  ${txt} not exists !! "
		exit 1
	fi
}

function checkErr() {
	local errc=$1
	local txt=$2

	if [[ $errc -ne 0 ]]; then
		echo "${idx} error $txt ... exit"
		exit 1
	fi
}

function test_zdm_hosts() {

	./fetch_cmdb_data.sh zdmhosts_detail
	local inputFile="../configfiles/zdmhosts_detail.env"

	lc=0
	printf "%-3s %-15s %-40s %-10s\n" \
		"Nr" "Ip" "Hostname" "Reachable" >/tmp/scr$$
	printf "%s\n" "------------------------------------------------------------------------------------------------------------------------" >>/tmp/scr$$

	while IFS='|' read -r zdmid ip zdmhost zdmhome zdmenv zdmbase; do

		rdir=$(timeout 3 ssh $ip "pwd" </dev/null)
		if [ $? -eq 0 ]; then
			reachable="yes - $rdir"
		else
			reachable="no - $rdir"
		fi

		let lc=${lc}+1
		{
			printf "%-3s %-15s %-40s %-40s\n" \
				"$lc" "$ip" "$zdmhost" "$reachable"
		} >>/tmp/scr$$

		total=$lc
	done <"$inputFile"

	cat /tmp/scr$$
	sleep 3

}

function select_nfs_server() {

	./fetch_cmdb_data.sh select_nfs
	local inputFile2="../configfiles/deployed_nfs.env"
	local inputFile="/tmp/$$_deployed_nfs.env"
	cat $inputFile2 | grep "ATPS" >$inputFile
	local -A seen_ips # Assoziatives Array zum Verfolgen der bereits gesehenen IPs

	lc=0
	printf "%-3s %-40s %-5s %-6s %-25s %-15s %-10s\n" \
		"Nr" "Name" "Art" "Plattf" "Export" "IP" "Reachable" >/tmp/scr$$
	printf "%s\n" "------------------------------------------------------------------------------------------------------------------------" >>/tmp/scr$$

	while IFS=',' read -r id name art platform _env _conf export ip; do
		if [[ -z "${seen_ips[$ip]}" ]]; then
			seen_ips["$ip"]=1

			# Port 2049 prüfen – Timeout 1 Sekunde
			if nc -z -w 1 "$ip" 2049 2>/dev/null; then
				reachable="yes"
			else
				reachable="no"
			fi

			let lc=${lc}+1
			{
				printf "%-3s %-40s %-5s %-6s %-25s %-15s %-10s\n" \
					"$lc" "$name" "$art" "$platform" "$export" "$ip" "$reachable"
			} >>/tmp/scr$$

			total=$lc
		fi
	done <"$inputFile"

	cat /tmp/scr$$

	echo
	while true; do
		# Clear line and print current selection + prompt

		read -p "Select > " num
		if [ $num -ge 1 ] && [ $num -le $total ]; then

			let num=${num}+2
			nfs_server=$(awk "NR==$num" /tmp/scr$$ | awk '{print $2}')
			nfs_mp=$(awk "NR==$num" /tmp/scr$$ | awk '{print $5}')
			nfs_ip=$(awk "NR==$num" /tmp/scr$$ | awk '{print $6}')
			break
		else
			echo -ne "\rInvalid selection: $num                                                    \n"A
		fi
		printf "\033[1A\033[1G"
		printf "                                                                                                                "
		printf "\033[1A\033[1G"
	done
	rm /tmp/scr$$

}

function check_connect() {

	local db=$1
	local adbonly=$3

	tnsalias=""

	if [ "X$adbonly" == "Xadbonly" ]; then
		if [ $(echo $db | grep -i "^ADB" | wc -l) -ne 1 ]; then
			echo "this action is for adb only!"
			sleep 2
			return
		fi
	fi

	tnsalias="${db}_tp"
	if [ $(cat $TNS_ADMIN/tnsnames.ora | grep -i "^$tnsalias" | wc -l) -ne 1 ]; then
		tnsalias="${db}_tp"
		tnsalias="${db}_system"
		if [ $(cat $TNS_ADMIN/tnsnames.ora | grep -i "^$tnsalias" | wc -l) -ne 1 ]; then
			tnsalias=""
			echo "no connect to db $db"
			sleep 2
			return
		fi
	fi

}

function runsql() {

	local db=$1
	local cm=$2
	local adbonly=$3

	check_connect $db $adbonly
	if [ "X$tnsalias" == "X" ]; then
		return
	fi

	echo
	#  echo "---------------------------------"
	#  echo "Executing:"
	#  cat $cm
	echo "---------------------------------"
	echo
	rm -f $rootDir/tmp/runsql.${gpid}
	{
		sqlplus -s "/@${tnsalias}" <<EOF


set serveroutput on;
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 50000
SET LINESIZE 200
--SET TERMOUT OFF
SET VERIFY OFF
--SET SQLPROMPT ''

   sta $cm;
   exit;

EOF
	} >$rootDir/tmp/runsql.${gpid}

	if [ $? -ne 0 ] || [ $(cat $rootDir/tmp/runsql.${gpid} | grep -i "ora-" | wc -l) -gt 0 ]; then
		echo "***SQL-FAIL***"
		echo "--------------SQL-on {$tnsalias}------------------------"
		cat $cm
		echo "--------------ERROR--------------------------------------------"
		cat $rootDir/tmp/runsql.${gpid}
		echo "---------------------------------------------------------------"
		echo
		read -p "<--press return-->"

	else
		if [ $(grep -o '|' $rootDir/tmp/runsql.${gpid} | wc -l) -eq 0 ]; then
			cat $rootDir/tmp/runsql.${gpid}
		fi

	fi
}

function mount_on_os() {

	local mount_where=$1
	local nfs_ip=$2
	local nfs_mp=$3
	local dbdirn=$4
	local pid=$$

	checkValue "X$mount_where" "mnt 1"
	checkValue "X$nfs_ip" "mnt 2"
	checkValue "X$nfs_mp" "mnt 3"

	mnt_option="rw,bg,hard,nointr,rsize=1048576,wsize=1048576,noatime,nodiratime,nconnect=4,tcp,actimeo=0,timeo=600,vers=4.1"
	lmp="/premig/${nfs_ip}${nfs_mp}"
	cat <<EOF >/tmp/mountos$$.sh


	if [ -d $lmp ]; then
               already_mounted=\$(sudo mount | grep "type nfs" | awk '{print \$1 \$3}' | grep "/premig" | grep "$nfs_ip" | wc -l )
               if  [ "\$already_mounted" != "0" ] ; then
		      echo "mount on os ok"
                      return &>/dev/null
                      exit
	       fi	     
	else
	       sudo mkdir -p "$lmp"      
	fi

	sudo mount -t nfs "$nfs_ip":"$nfs_mp" "$lmp" -o $mnt_option
	if [ \$? -eq 0 ]; then
		echo "mount on os ok"
        else
		echo "mount on OS failed"
	fi
EOF

	chmod +x /tmp/mountos$$.sh
	if [ "$mount_where" == "local" ]; then
		/tmp/mountos$$.sh
	else
		scpr22=$(scp -i ~/.ssh/priv_010.key /tmp/mountos$$.sh oracle@10.3.120.254:/tmp/mountos$$.sh)
		sshm22=$(ssh -i ~/.ssh/priv_010.key oracle@10.3.120.254 "timeout 5 /tmp/mountos$$.sh")
		sshr22=$(ssh -i ~/.ssh/priv_010.key oracle@10.3.120.254 "/tmp/mountos$$.sh")

		if [ $(echo $sshm22 | grep "mount on os ok" | wc -l) -eq 1 ]; then
			sqlplus -s /@lin8030411_rene22_system <<EOF

                       CREATE DIRECTORY $dbdirn AS '$lmp';

                       exit;
EOF
		else
			echo "mount on rene22 failed"
			echo $sshm22
			echo "/tmp/mountos$$.sh"
			cat /tmp/mountos$$.sh
		fi
	fi
}

function check_port() {

	local lport=""
	local lserver=""
	local adbonly="adbonly"

	check_connect $db $adbonly
	if [ "X$tnsalias" == "X" ]; then
		return
	fi

	echo

	read -p "Which Host to check? " lserver
	read -p "Which TCP Port to check? " lport

	if [ "X$lserver" == "X" ]; then
		lserver=$nfs_server
		lport=2049
	fi

	echo "Checking $lserver $lport ..."

	sqlplus -s /@${tnsalias} <<EOF

set serveroutput on
set linesize 3000
set heading off

exec DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(host => '${lserver}', ace => xs\$ace_type(privilege_list => xs\$name_list('connect', 'resolve'), principal_name => 'ADMIN', principal_type => xs_acl.ptype_db));


-- check nfs port
DECLARE
  c  utl_tcp.connection;  -- TCP/IP connection to the Web server
  ret_val pls_integer;
BEGIN
  c := utl_tcp.open_connection(remote_host => '${lserver}',
                               remote_port =>  $lport,
                               charset     => 'US7ASCII');  -- open connection
  BEGIN
      dbms_output.put_line('port $lport open on host ${lserver}');
  EXCEPTION
    WHEN utl_tcp.end_of_input THEN
      dbms_output.put_line('port $lport ***NOT*** open on host ${lserver}');
  END;
  utl_tcp.close_connection(c);
END;
/

EOF

}

function mount_share_rene22() {

	local nfs_ip=$1
	local nfs_mp=$2

	if [ "X$nfs_ip" == "X" ]; then
		echo "No nfs server selectd..... please selcct first.."
		sleep 2
		return
	fi

	read -p "Dirname on rene22? >" rene22dir

	echo "------"
	echo "Try to mount on RENE22:"
	echo "S: ${nfs_ip}:${nfs_mp} on dir $rrene22dir"

	echo
	read -p "OK? c=confirm> " antw

	if [ "$antw" != "c" ]; then
		return
	fi

	mount_on_os "rene22" "${nfs_ip}" "${nfs_mp}" "$rene22dir"

}



function create_nfs_drv_file() {

	local adbn="$1"
	local nfs_share="$2"
	local nfs_server="$3"

        local ldat=$(date +"%Y%m%d-%H%M%S")
        mkdir -p $rootDir/results/${ldat}_adb019
        drvfile=$rootDir/results/${ldat}_adb019/nfs.drv

	cat << EOF > $drvfile
export rootDir=$rootDir
export dbResultDir=$rootDir/results/${ldat}_adb019
export LGfile=$dbResultDir/${ldat}_adb019.log
export runlog=/dev/null
export configDir=$rootDir/configfiles
export resultDir=$rootDir/results
export sqlDir=$rootDir/sqls
export scriptsDir=$rootDir/scripts
export ORACLE_HOME=$rootDir/oracle/client
export execute_mount_tgt=YES
export TNS_ADMIN=$rootDir/oracle/client/network/admin/cloud_dbs
export target_db_name=$adbn
export target_tns_alias=${adbn}_tp
export nfs_share=$nfs_share
export nfs_mountp=/mount/zdm/adb7
export nfs_version=4
export nfs_server=$nfs_server
export target_platform="ATPS"
EOF

}




function mount_share() {

	local adbonly="adbonly"

	check_connect $db $adbonly
	if [ "X$tnsalias" == "X" ]; then
		return
	fi

	./fetch_cmdb_data.sh select_nfs2
	local inputFile="$rootDir/configfiles/deployed_nfs2.env"

	while true; do
		show_screen "$rootDir/configfiles/deployed_nfs2.env" \
			    "$rootDir/tmp/nfs_sel.$gpid" \
			    "Name,Pltf,share,ip" "40,6,15,15" "SEL" "1,2,3,4" "," "--limit=1" 1 25 "N"

		if [ -s "$rootDir/tmp/nfs_sel.$gpid" ]; then

			nfs_server=$(cat "$rootDir/tmp/nfs_sel.$gpid" | awk '{print $1}')
			nfs_mp=$(cat "$rootDir/tmp/nfs_sel.$gpid" | awk '{print $3}')
			nfs_platf=$(cat "$rootDir/tmp/nfs_sel.$gpid" | awk '{print $2}')

		else
			return
		fi

		warntxt=""
		if [ "$nfs_platf" != "ATPS" ]; then
			warntxt="Warning: NO ADB Server! - mount on your risk - "
		fi

		echo
		echo -e "Mount share ${EC_CYAN}$nfs_server $nfs_mp $nfs_platf $EC_NC"
		echo
		gum confirm $confirm_params "${warntxt}confirm to mount NFS?" || continue

		break

	done

	if [ "X$nfs_server" == "X" ]; then
		echo "No nfs server selectd..... "
		sleep 2
		return
	fi

	dirnu=$(date +"%H%M%S")
 
	dirname="dir_$dirnu"
	fsname="fs_$dirnu"

	echo "S: ${nfs_server}:${nfs_mp} on dir $dirname"
	echo


        
         #create_nfs_drv_file "$db" "${nfs_mp}" "${nfs_server}"
         #if [ -s $drvfile ]; then
	 #    $rootDir/scripts/run_precheck.sh "019" "mntNfsTgt" "$drvfile"
	 #else
	 #    echo "mnt error"
	 #    read -p "<--press ebter-->" xx
	 #fi
         #return










	mount_ret=$(
		sqlplus -s /@${tnsalias} <<EOF

set serveroutput on
set linesize 3000
set heading off

      set serveroutput on;
        set linesize 300;
        set feedback off;
        set pagesize 0;
        sta ../sqls/procedure_nfs_share.sql;
        /
  
        exec FS_SHARE ( 'MOUNT', '$dirname', '$fsname', '$nfs_server', '$nfs_mp', '$nfs_mp', 'test access');
exit;
EOF
	)
	if [[ "$mount_ret" == "1" ]]; then
		echo "mount SUCCESSFUL"

	else
		echo $mount_ret
		echo "mount FAIL"
	fi

}

function perftest2() {

	local dbs=$1
	local db=$2
	local DIR_NAME=$3
	local DIR_NAMES=$4

	local adbonly="adbonly"

	check_connect $db $adbonly
	if [ "X$tnsalias" == "X" ]; then
		return
	fi

	src_tnsalias="${dbs}_system"

	srcok=$(
		sqlplus -s "/@$src_tnsalias" <<EOF
        set heading off
        set feedback off
        set pagesize 0

            select 'OK' from dual;
            exit
EOF
	)

	if [ "$srcok" != "OK" ]; then
		echo "src connect not working...."
		sleep 2
		return
	fi

	PARALLEL_SESSIONS=$(gum input --header "Number of parallel sessions?" --value "1")
	threads=$(gum input --header "Number threads per session?" --value "4")
	ROW_COUNT=$(gum input --header "Number of rows per table?" --value "10000")

	pid=$$
	DUMP_PREFIX="perftst$$"
	DBNAME=${tnsalias}
	printf "%-30s %-15s\n" "Number of parallel sessions " "$PARALLEL_SESSIONS"
	printf "%-30s %-15s\n" "Number threads per session  " "$threads"
	printf "%-30s %-15s\n" "Rowcount per table          " "$ROW_COUNT"
	printf "%-30s %-15s\n" "source database             " "$dbs"
	printf "%-30s %-15s\n" "source tnsalias             " "$src_tnsalias"
	printf "%-30s %-15s\n" "source directory            " "$DIR_NAMES"
	printf "%-30s %-15s\n" "target database             " "$db"
	printf "%-30s %-15s\n" "target tnsalias             " "$DBNAME"
	printf "%-30s %-15s\n" "target diractory            " "$DIR_NAME"
	printf "%-30s %-15s\n" "filename prefix             " "$DUMP_PREFIX"

	echo
	gum confirm $confirm_params "GO ahead?" || return

	msg N I "DATAPUMP exp/imp test...."
	echo

	if [ $PARALLEL_SESSIONS -gt 3 ]; then
		echo "session max 3!"
		sleep 2
		PARALLEL_SESSIONS=3
	fi

	run_test_session() {
		local idx=$1
		local dump_file="${DUMP_PREFIX}_${idx}_$$.dmp"
		local create_log="create_${idx}.log"
		local export_log="export_${idx}_$$.log"
		local import_log="import_${idx}_$$.log"
		local verify_log="verify_${idx}.log"

		# Create and populate table
		msg N I "[S:$idx] Creating and populating BIG_TABLE..."
		start_create=$(date +%s)
		sqlplus -s "/@${src_tnsalias}" <<EOF >"$create_log" 2>&1
SET DEFINE ON
DEFINE row_count=$ROW_COUNT
DEFINE dir_name='$DIR_NAME'
DEFINE session_id='$idx'
@../sqls/create_test_table.sql
EXIT
EOF
		end_create=$(date +%s)
		create_time=$((end_create - start_create))
		checkErr $? "Create table"
		msg N I "[S:$idx] Table creation done in ${create_time}s. Log: $create_log"

		# Export table
		msg N I "[S:$idx] Starting export to $dump_file..."
		start_export=$(date +%s)

		expdp /@${src_tnsalias} tables=BIG_TABLE_$idx directory=$DIR_NAMES parallel=$threads filesize=4G compression=all \
			dumpfile=$dump_file logfile=$export_log >./exp_$idx.log 2>&1
		end_export=$(date +%s)
		export_time=$((end_export - start_export))
		checkErr $? "Export"
		msg N I "[S:$idx] Export completed in ${export_time}s. Log: $export_log"

		# Drop table
		msg N I "[S:$idx] Dropping BIG_TABLE before import..."
		sqlplus -s "/@${DBNAME}" <<EOF >>"$import_log" 2>&1
                DROP TABLE BIG_TABLE_$idx PURGE;
EXIT
EOF
		msg N I "[S:$idx] Table dropped before import."

		# Import table
		msg N I "[S:$idx] Starting import from $dump_file..."
		start_import=$(date +%s)
		impdp /@${DBNAME} tables=BIG_TABLE_$idx directory=$DIR_NAME parallel=$threads \
			dumpfile=$dump_file logfile=$import_log >./imp_$idx.log 2>&1
		end_import=$(date +%s)
		import_time=$((end_import - start_import))
		checkErr $? "Import"
		msg N I "[S:$idx] Import completed in ${import_time}s. Log: $import_log"

		# Verify row count
		msg N I "[S:$idx] Verifying row count..."
		sqlplus -s "/@${DBNAME}" <<EOF >"$verify_log" 2>&1
SET HEADING OFF FEEDBACK OFF VERIFY OFF PAGESIZE 0
SELECT COUNT(*) FROM BIG_TABLE_$idx;
EXIT
EOF
		checkErr $? "Verify table"
		msg N I "[S:$idx] Verification done. Log: $verify_log"
	}

	msg N I "Launching $PARALLEL_SESSIONS parallel sessions using dbname: $DBNAME ..."
	start_time=$(date +%s)

	for i in $(seq 1 "$PARALLEL_SESSIONS"); do
		run_test_session "$i" &
	done
	wait

	end_time=$(date +%s)
	total_duration=$((end_time - start_time))

	echo
	msg N I "All $PARALLEL_SESSIONS sessions completed in $total_duration seconds."
	msg N I "Summary of sessions:"
	echo

	for i in $(seq 1 "$PARALLEL_SESSIONS"); do
		local create_log="create_${i}.log"
		local export_log="exp_${i}.log"
		local import_log="imp_${i}.log"
		local verify_log="verify_${i}.log"

		echo "-------------------------------------------------------"
		echo "Session $i: Create Table:"
		cat $create_log | grep "Created"
		cat $create_log | grep "ORA-" | grep -v "ORA-39173"
		echo
		echo "-------------------------------------------------------"
		echo "Session $i: Export Table:"
		cat $export_log | grep "BIG_TABLE" | grep -v "Starting"
		cat $export_log | grep "elapsed"
		cat $export_log | grep "ORA-" | grep -v "ORA-39173"
		echo
		echo "-------------------------------------------------------"
		echo "Session $i: Import Table:"
		cat $import_log | grep "BIG_TABLE" | grep -v "Starting"
		cat $export_log | grep "elapsed"
		cat $import_log | grep "ORA-" | grep -v "ORA-39173"

	done

}

function nfs_perftest() {

	local adbonly="adbonly"
	local dirname=$2
	check_connect $db $adbonly
	if [ "X$tnsalias" == "X" ]; then
		return
	fi

	echo
	read -p "db=$db Dir=$dirname  lopp count? " cnt

	sqlplus -s /@${tnsalias} <<EOF

set serveroutput on
set linesize 3000
set heading off

        set feedback off;
        set pagesize 0;
        sta $rootDir/sqls/p_nfs_perftest.sql;
        /
        exec P_NFS_WR_TEST ( '$dirname', '$cnt');
        exit;

exit;
EOF
}

function ask_continue() {

	read -p "${1}  continue (y,n)?" antw
	if [[ "$antw" == "y" ]]; then
		echo "continue..."
	else
		echo "db not reachable..."
		return 1
	fi

}

function display_adb_info_formatted() {
	local input_file="$1"
	local max_lines=20
	local line_count=0
	local read_count=0
	local kcolor=$'\033[0;36m' # gelb für EX
	local vcolor=$'\033[0;32m' # gelb für EX
	local reset=$'\033[0m'     # zurücksetzen
	local col_max=2

	if [[ ! -f "$input_file" ]]; then
		echo "CSV file not found: $input_file"
		return 1
	fi

	# Read headers
	IFS=',' read -r -a headers <"$input_file"

	# Read data rows
	tail -n +2 "$input_file" | while IFS=',' read -r -a fields; do
		local row_output=""
		local col_count=0

		for i in "${!headers[@]}"; do
			local key="${headers[$i]}"
			local value="${fields[$i]}"
			#value="${value:0:25}"  # truncate to 15 characters

			printf -v kv "   %s%-20s:%s %-25s%s" "$kcolor" "$key" "$vcolor" "$value" "$reset"
			row_output+="$kv  "
			((col_count++))

			if [ $line_count -gt 10 ]; then
				col_max=1
			fi

			if ((col_count % col_max == 0)); then
				echo "$row_output"
				row_output=""
				((line_count++))
			fi

		done

		# Print remaining columns if total % 3 != 0
		if [[ -n "$row_output" ]]; then
			echo "$row_output"
			((line_count++))
		fi

		line_count=0
	done
}

function menu() {

	clear
	mhead "selected adb $db"
	#select_adbinfo "Y" "N" 1 "N" "$rootDir/tmp/adbinfo_sel.${gpid}" "$rootDir/tmp/adbinfo_sel2.${gpid}"

	if [ "$formatted_db" != "$db" ]; then
		$rootDir/scripts/fetch_cmdb_data.sh adbinfos_name "$db" "$rootDir/tmp/adbinfo_sel_name.${gpid}"
		formatted_db="$db"
	fi

	echo "---------------------------------------------------------------------------------------------------------------------------------"
	display_adb_info_formatted "$rootDir/tmp/adbinfo_sel_name.${gpid}"
	echo "---------------------------------------------------------------------------------------------------------------------------------"
	echo

	menubar="[q]quit,[1]listDir,[2]listCloudFs,[3]mountNfs,[4]setDB,[5]ChkHostPort,[6]ListSrcDirs,//,"
	menubar="${menubar}[a]RunSql,[b]listACS,[c]listUser,[d]listTS,[e]SimpelPerfTest,[f]listDBL,[g]TestDBL"

	hmenu "${menubar}"
	case $input in
	listDir) act="1" ;; listCloudFs) act="2" ;; mountNfs) act="5" ;; setDB) act="6" ;; PerfTestDP) act="7" ;; ListSrcDirs) act="37" ;;
	SelNfsSrv) act="8" ;; ChkHostPort) act="9" ;; RunSql) act="10" ;; listACS) act="11" ;; listUser) act="12" ;; listTS) act="13" ;; SimpelPerfTest) act="14" ;;
	listDBL) act="19" ;; TestDBL) act="21" ;; quit) act="q" ;;
	esac
}

function menuold() {

	{
		echo
		echo "Current db....: $db "
		echo "Selectet nfs..: $nfs_ip $nfs_server $nfs_mp"
		echo "-----------------------"
		printf "%-25s %-25s %-25s\n" " 1... list diirectories" " 2... list cloudfs" " 3... drop dir"
		printf "%-25s %-25s %-25s\n" " 4... deattach FS" " 5... mount nfs" " 6... set db"
		printf "%-25s %-25s %-25s\n" " 7... perf test datapump" " 8... select nfs srv " " 9... Check host/port"
		printf "%-25s %-25s %-25s\n" "10... Run user sql " "11... list Host ACS" "12... List users"
		printf "%-25s %-25s %-25s\n" "13... List Taglespaces" "14... simple perf test" "15... Mount share on RENE22"
		printf "%-25s %-25s %-25s\n" "16... List DB Dirs RENE22" "17... exp test on RENE22" "18... List zdm hosts"
		echo "DB Links:"
		printf "%-25s %-25s %-25s\n" "19... List DB Links" "20... create db link" "21... Test dblink"
		printf "%-25s %-25s %-25s\n" "22... drop DB Link " "23... list credentials" "24... drop credentials"
		printf "%-25s %-25s %-25s\n" "25... Create credentials" # "23... list credentials"      "24... drop credentials"
		echo " q... exit"
	} >/tmp/scr$$

	clear
	gum style --foreground=$AC_RED --background=$AC_BLACK \
		--border rounded --margin "1 2" --padding "1 3" \
		--align center --width 100 --bold "DBA-TOOLBOX"
	gum style --foreground=$AC_WHITE --background=$AC_BLACK \
		--margin "1 2" --padding "1 3" \
		--align left --width 100 --bold </tmp/scr$$
	rm /tmp/scr$$

	echo
	act=$(gum input --placeholder="number?")
}

function read_dir() {
	local dbl=$1

	>"$rootDir/tmp/runsql_out.${gpid}"
	>"$rootDir/tmp/runsql.${gpid}"
	if [ "${dbl:0:3}" == "ADB" ] || [ "${dbl:0:3}" == "adb" ]; then

		cat <<EOF >$sqlcmd

                           SELECT FILE_SYSTEM_NAME||'|'||
                               DIRECTORY_NAME||'|'||
                               FILE_SYSTEM_LOCATION
                           FROM dba_cloud_file_systems;

EOF
	else
		cat <<EOF >$sqlcmd

         SELECT DIRECTORY_NAME||'|'||DIRECTORY_PATH
         FROM ALL_DIRECTORIES;

EOF

	fi
	runsql $dbl $sqlcmd

	if [ -s $rootDir/tmp/runsql.${gpid} ]; then
		echo "Name,Dir,Location" >"$rootDir/tmp/runsql.${gpid}.hdr"
		clear
		mhead "Select Items"
		echo -e "$EC_YELLOW----> to run perftest please select! $EC_NC"
		gchoose_simple "$rootDir/tmp/runsql.${gpid}" "$rootDir/tmp/runsql_out.${gpid}" "|" "multi"
		if [ -s "$rootDir/tmp/runsql_out.${gpid}" ]; then
			cat "$rootDir/tmp/runsql_out.${gpid}"
			gum confirm $confirm_params "really perftest?" || return
		fi
	fi
}

function adb_toolbox() {
	sqlcmd=$rootDir/tmp/sqlcmd_$gpid.sql
	>"$rootDir/tmp/adbinfo.${gpid}"
	>"$rootDir/tmp/adbinfo.${gpid}.hdr"

	$rootDir/scripts/fetch_cmdb_data.sh adbinfos "$rootDir/tmp/adbinfo.${gpid}"
	act=6
	while true; do

		if [ -z $act ]; then
			menu
		fi

		sqlcmd=$rootDir/tmp/sqlcmd_$gpid.sql
		case $act in
		1)
			cat <<EOF >$sqlcmd
		        --column directory_name format A30
		        --column directory_path format A90	
		        SELECT directory_name||'|'||directory_path
                        FROM all_directories
EOF
			runsql $db $sqlcmd

			if [ -s $rootDir/tmp/runsql.${gpid} ]; then
				echo "Name,Pfad" >"$rootDir/tmp/runsql.${gpid}.hdr"
				clear
				mhead "Select Items"
				echo -e "$EC_YELLOW----> to remove Dir, please select! $EC_NC"
				gchoose_simple "$rootDir/tmp/runsql.${gpid}" "$rootDir/tmp/runsql_out.${gpid}" "|" "multi"
				if [ -s "$rootDir/tmp/runsql_out.${gpid}" ]; then
					cat "$rootDir/tmp/runsql_out.${gpid}"
					echo " "
					menubar="[q]quit,[1]removeDir"
					hmenu "${menubar}"

					case $input in
					removeDir)

						>$sqlcmd
						for dir in $(cat "$rootDir/tmp/runsql_out.${gpid}" | awk '{print $1}'); do
							echo " drop directory $dir;" >>$sqlcmd
						done
						runsql $db $sqlcmd
						;;

					"" | quit)
						return
						;;
					esac

				fi

			fi

			;;
		2)
			>"$rootDir/tmp/runsql_out.${gpid}"
			>"$rootDir/tmp/runsql.${gpid}"
			cat <<EOF >$sqlcmd
                        --column directory_name format A30
                        --column FILE_SYSTEM_NAME format A30
                        --column FILE_SYSTEM_LOCATION format A90

			SELECT FILE_SYSTEM_NAME||'|'||
                               DIRECTORY_NAME||'|'||
                               FILE_SYSTEM_LOCATION
                        FROM dba_cloud_file_systems;
 
EOF
			runsql $db $sqlcmd

			if [ -s $rootDir/tmp/runsql.${gpid} ]; then
				echo "Name,Dir,Location" >"$rootDir/tmp/runsql.${gpid}.hdr"
				clear
				mhead "Select Items"
				echo -e "$EC_YELLOW----> to remove attached FS, please select! $EC_NC"
				gchoose_simple "$rootDir/tmp/runsql.${gpid}" "$rootDir/tmp/runsql_out.${gpid}" "|" "multi"

				if [ -s "$rootDir/tmp/runsql_out.${gpid}" ]; then
					cat "$rootDir/tmp/runsql_out.${gpid}"
					echo " "
					menubar="[q]quit,[1]listCotent,[2]removeCloudFS"
					hmenu "${menubar}"

					case $input in

					listCotent)

						for dir in $(cat $rootDir/tmp/runsql_out.${gpid} | awk '{print $2}'); do

							{

								echo "  COLUMN sizeMB          FORMAT 9999,990.000"
								echo "  COLUMN object_name     FORMAT A70"
								echo "  COLUMN last_modified   FORMAT A36"

								echo "  SELECT object_name, "
								echo "  round((bytes/1024)/1024,3) as sizeMB, "
								echo "         last_modified "
								echo "  FROM DBMS_CLOUD.LIST_FILES('$dir')"
								echo "  order by last_modified asc;"

							} >$sqlcmd

							runsql $db $sqlcmd

							read -p "<--press enter-->"

						done

						;;

					removeCloudFS)

						gum confirm $confirm_params "really drop?" || return

						for fs in $(cat $rootDir/tmp/runsql_out.${gpid} | awk '{print $1}'); do

							{
								echo "  declare"
								echo "    v_dirnam varchar2(100);"
								echo "  begin"
								echo "    select DIRECTORY_NAME into v_dirnam"
								echo "    from dba_cloud_file_systems"
								echo "    where FILE_SYSTEM_NAME = upper('$fs');"
								echo "    DBMS_CLOUD_ADMIN.DETACH_FILE_SYSTEM ( file_system_name => '$fs' );"
								echo "    execute immediate 'drop directory '||v_dirnam;"
								echo "  exception"
								echo "      when others then"
								echo "      dbms_output.put_line (sqlerrm);"
								echo "  end;"
								echo "  /"
							} >$sqlcmd

							runsql $db $sqlcmd

						done

						;;

					"" | quit)
						return
						;;
					esac
				fi

			fi

			;;

		5)
			mount_share
			;;

		6)

			clear
			mhead "Select ADB"

			>"$rootDir/tmp/adbinfo_sel.${gpid}"

			select_adbinfo "N" "Y" 1 "N" "$rootDir/tmp/adbinfo.${gpid}" "$rootDir/tmp/adbinfo_sel.${gpid}"

			if [ -s "$rootDir/tmp/adbinfo_sel.${gpid}" ]; then
				tdb=$(cat "$rootDir/tmp/adbinfo_sel.${gpid}" | awk '{print $3}')
				srcdb=$(cat "$rootDir/tmp/adbinfo_sel.${gpid}" | awk '{print $6}')
				check_connect $tdb
				if [ "X$tnsalias" != "X" ]; then
					db=$tdb
				else
					return
				fi
			else
				return
			fi
			;;

		8)
			select_nfs_server
			;;

		9)
			check_port
			;;
		10)
			read -p "Paste statement here> " user_sql
			echo "${user_sql};" >$sqlcmd
			runsql $db $sqlcmd
			;;

		11)
			cat <<EOF >$sqlcmd

COLUMN HOST            FORMAT A22
COLUMN LOWER_PORT      FORMAT 99999
COLUMN UPPER_PORT      FORMAT 99999
COLUMN PRINCIPAL       FORMAT A20
COLUMN PRIVILEGE       FORMAT A20

SELECT HOST,
       LOWER_PORT,
       UPPER_PORT,
       PRINCIPAL,
       PRIVILEGE
FROM    DBA_HOST_ACES;
EOF
			runsql $db $sqlcmd
			;;

		12)
			cat <<EOF >$sqlcmd
COLUMN owner           FORMAT A22
COLUMN used_mb         FORMAT 99,999,990.99
		SELECT owner, ROUND(SUM(bytes) / 1024 / 1024, 2) as used_mb
FROM dba_segments
GROUP BY
    owner
ORDER BY
   used_mb DESC;
EOF
			runsql $db $sqlcmd

			;;

		13)
			cat <<'EOF' >"$sqlcmd"

SELECT
    df.tablespace_name,
    ROUND(SUM(df.bytes) / 1024 / 1024 / 1024, 2) AS allocated_gb,
    ROUND((SUM(df.bytes) - NVL(free_space.bytes_free, 0)) / 1024 / 1024 / 1024, 2) AS used_gb
FROM
    dba_data_files df
LEFT JOIN
    (SELECT
         tablespace_name,
         SUM(bytes) AS bytes_free
     FROM
         dba_free_space
     GROUP BY
         tablespace_name) free_space
ON df.tablespace_name = free_space.tablespace_name
GROUP BY
    df.tablespace_name,
    free_space.bytes_free
ORDER BY
    allocated_gb DESC;

EOF
			runsql $db $sqlcmd

			;;
		7 | 14 | 17)

			echo " "
			read_dir "${db}"
			cp $rootDir/tmp/runsql_out.${gpid} $rootDir/tmp/runsql_out$db.${gpid}
			for dir in $(cat $rootDir/tmp/runsql_out$db.${gpid} | awk '{print $2}'); do
				if [ "$act" == "14" ]; then
					nfs_perftest $db $dir
				else
					echo " "
					echo "--------------------------------------------------------------------------------------------------- "
					echo -e "${EC_RED}Attention:"
					echo -e "${EC_CYAN}This test will create some test tables on DB ${EC_GREEN}lin8030411_rene22"
					echo -e "${EC_CYAN}This tables are stored as usser ${EC_GREEN}system${EC_CYAN} in the users default TS"
					echo -e "${EC_CYAN}The Name of the tables are beginning with${EC_GREEN} BIG_TABLE...${EC_CYAN} "
					echo -e "${EC_CYAN}At the end, this tables are removed${EC_NC} "
					echo " "
					echo " "
					gum confirm $confirm_params "Do you agree?" || return
					echo " "
					echo " "
					echo "Select Directory on rene22"
					echo " "
					read_dir "lin8030411_rene22"
					echo " "
					perftest2 "lin8030411_rene22" "$db" "$dir" "$(awk 'NR == 1' $rootDir/tmp/runsql_out.${gpid} | awk '{print $1}')"
				fi

			done

			;;
		37)

			src_tnsalias="${srcdb}_system"

			srcok=$(
				sqlplus -s "/@$src_tnsalias" <<EOF
                                       set heading off feedback off pagesize 0
                                       select 'OK' from dual;
                                        exit;
EOF
			)

			if [ "$srcok" == "OK" ]; then
			   {
				sqlplus -s "/@$src_tnsalias" <<EOF
                                       set heading off feedback off pagesize 0

                                       SELECT DIRECTORY_NAME||'|'||DIRECTORY_PATH
                                       FROM ALL_DIRECTORIES;
                                exit;

EOF
                            } > $rootDir/tmp/runsql.${gpid}


				if [ -s $rootDir/tmp/runsql.${gpid} ]; then
					echo "Name,Location" >"$rootDir/tmp/runsql.${gpid}.hdr"
					clear
					mhead "Select Items"
				        show_screen "$rootDir/tmp/runsql.${gpid}" "./out" "Name,Location" "25,45" "DO" "1,2" "|" "--no-limit" 1 25 "N"

				fi
			else
				echo "no src connect ..."
			fi
			echo " "
			read -p "<--press return-->" xx
			;;

		15)
			mount_share_rene22 "$nfs_ip" "$nfs_mp"
			;;
		16)

			cat <<EOF >$sqlcmd
SET LINESIZE 150
SET PAGESIZE 50
COLUMN directory_name FORMAT A30
COLUMN directory_path FORMAT A100

SELECT directory_name,
       directory_path
FROM   dba_directories
ORDER  BY directory_name;

EOF
			runsql "lin8030411_rene22" $sqlcmd

			;;

		18)
			test_zdm_hosts
			;;

		19)

			cat <<EOF >$sqlcmd
SET LINESIZE 150
SET PAGESIZE 50
COLUMN owner          FORMAT A15
COLUMN db_link        FORMAT A20
COLUMN host           FORMAT A110

select owner, db_link, host from DBA_DB_LINKS;

EOF
			runsql $db $sqlcmd

			;;
		20)
			read -p "Link Name?    " dbln
			read -p "Host FDQN?    " dblh
			read -p "Port?         " dblp
			read -p "Service Name? " dbls
			read -p "Credential?   " dblc

			echo "Creating DB Link in $db to service $dbls on Host $dblh?"
			read -p "to confirm, press c " conf

			if [ "X$conf" == "Xc" ]; then

				cat <<EOF >"$sqlcmd"
BEGIN
  DBMS_CLOUD_ADMIN.CREATE_DATABASE_LINK(
    db_link_name      => '$dbln',
    hostname          => '$dblh',
    port              => $dblp,
    service_name      => '$dbls',
    ssl_server_cert_dn => NULL,
    credential_name   => '$dblc',
    directory_name    => NULL,
    private_target    => TRUE
  );
END;
/
EOF

				runsql $db $sqlcmd

			else
				echo "do nothing..."
				sleep 1
			fi
			;;
		21)
			read -p "DB link owner? " dblo
			read -p "DB link name?  " dbls

			cat <<EOF >$sqlcmd
SET LINESIZE 150
SET PAGESIZE 50

select * from dual@${dblo}.${dbls};

EOF
			runsql $db $sqlcmd

			;;
		22)
			read -p "DB link name? " dbls

			cat <<EOF >$sqlcmd
SET LINESIZE 150
SET PAGESIZE 50

begin
   DBMS_CLOUD_ADMIN.drop_DATABASE_LINK (db_link_name => '${dbls}'); 
end;
/

EOF
			runsql $db $sqlcmd

			;;

		23)

			cat <<EOF >$sqlcmd
SET LINESIZE 150
SET PAGESIZE 50
COLUMN owner           FORMAT A25
COLUMN credential_name FORMAT A25
COLUMN username        FORMAT A65


    SELECT owner, credential_name, username
    FROM dba_credentials;

EOF
			runsql $db $sqlcmd

			;;

		24)
			read -p "Credential?   " dbcr

			cat <<EOF >$sqlcmd
SET LINESIZE 150
SET PAGESIZE 50

begin
   DBMS_CLOUD.drop_CREDENTIAL ( credential_name => '${dbcr}');
end;
/

EOF
			runsql $db $sqlcmd

			;;

		25)
			read -p "Credential?   " dbcn
			read -p "User?         " dbcu
			read -p "Password?     " dbcp

			cat <<EOF >$sqlcmd
SET LINESIZE 150
SET PAGESIZE 50

begin
   DBMS_CLOUD.create_CREDENTIAL ( credential_name => '${dbcn}',
                                  username        => '${dbcu}',
                                  password        => '${dbcp}' );
end;
/

EOF
			runsql $db $sqlcmd

			;;

		q)
			break
			;;
		*)
			break
			echo "unknown $act"
			;;
		esac

		case $act in
		6) echo "nix" >/dev/null ;;
		*) read -p "<-Press Return->" ;;
		esac
		act=""
	done

	touch $sqlcmd
	rm $sqlcmd
}
