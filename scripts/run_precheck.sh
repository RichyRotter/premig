#!/usr/bin/env bash
# set -x

# 22.08.2024 v1.0. rr
# ZDM Vorprüfungsskript

# Eingabeparameter
log_file_number=$1
test_to_run=$2
driver_file=$3

# Konfigurationsdateien einbinden
source ./init_variables.sh </dev/null
source ../premigration.env cloud </dev/null
source "${rootDir}/scripts/utils.sh" </dev/null
source "$driver_file" </dev/null

# Fehlerbehandlung deaktivieren
manage_error_trap off

# Globale Variablen
remote_dir=/tmp/modernex_premig_checks
ssh_options="-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=2"
scp_options="-o TCPKeepAlive=yes -o ServerAliveInterval=3 -o ServerAliveCountMax=3"
test_ok="PASSED"
test_partly="EXCEPTION"
test_fail="--FAILED---"
export generate_resultfile_on_error="YES"

#-------------------------------------
# Temporäre SEPS-Datei erstellen
function create_temp_seps() {
	local tns_alias=$1
	local origin=$2
	local tar_file=$3

	checkValue "X${tns_alias}" "seps 1"
	checkValue "X${origin}" "seps 2"
	cr_tmp_seps=9

	touch "$tar_file"
	if [[ $? -ne 0 ]]; then
		cr_tmp_seps=8
		return
	fi

	current_dir=$(pwd)
	source ../premigration.env "$origin"
	mkdir "$tmpDir/seps"
	cat "$TNS_ADMIN/tnsnames.ora" | grep "$tns_alias" >"$tmpDir/seps/tnsnames.ora"

	sql_ret="db-ok"
	if [[ "$sql_ret" == "db-ok" ]]; then
		cd "$tmpDir"
		tar -cvf "$tar_file" ./seps
		if [[ $? -ne 0 ]]; then
			cr_tmp_seps=8
			rm "$tar_file"
		else
			cr_tmp_seps=0
		fi
		cd "$current_dir"
	else
		cr_tmp_seps=7
	fi

	cd "$tmpDir"
	rm -rf ./seps
	cd "$current_dir"
}

#-------------------------------------
# Remote Testverzeichnis erstellen
function create_remote_testdir() {
	local remote_host=$1
	local remote_dir=$2

	{
		echo "cd /tmp"
		echo "if [[ ! -d $remote_dir ]]; then"
		echo "    mkdir $remote_dir"
		echo "    if [[ \$? -ne 0 ]]; then"
		echo "        echo \"ERROR\""
		echo "    else"
		echo "        if [[ -f /etc/oratab ]]; then"
		echo "            ORACLE_HOME=\$(cat /etc/oratab | tail -1 | awk -F\":\" '{print \$2}')"
		echo "            echo \"export ORACLE_HOME=\$ORACLE_HOME\" > $remote_dir/ora.env"
		echo "            echo \"export PATH=\$PATH:\$ORACLE_HOME/bin\" >> $remote_dir/ora.env"
		echo "            echo \"export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$ORACLE_HOME/lib\" >> $remote_dir/ora.env"
		echo "            chmod +x $remote_dir/ora.env"
		echo "        fi"
		echo "    fi"
		echo "fi"
	} >"$tmp_dir/crdir.sh"

	chmod +x "$tmp_dir/crdir.sh"
	scp "$tmp_dir/crdir.sh" "$remote_host:/tmp" &>/dev/null
	ssh "$remote_host" "chmod +x /tmp/crdir.sh"
	ret_code=$(ssh "$remote_host" "/tmp/crdir.sh")
}

#-------------------------------------
# SSH-Verbindung zu ZDM-Server prüfen
function check_ssh_to_zdmsv() {
	set -x
	co=""
	stat=""
	tested_zdmhosts=""

	if [[ "$skipzdm" == "YES" ]]; then
		tested_zdmhosts=${zdm_hosts}
		lmsg N I "Step1-connect to zdm: STATUS=SKIPPED"
		lmsg N I "Tested and OK zdmsrv $tested_zdmhosts"
		echo "export tested_zdmhosts=$tested_zdmhosts" >>"$driver_file"
		write_resultsfile 0 0 "skipped"
		return
	fi

	ssh_command="pwd"
	ok_server=0
	server=0

	for ip2 in $(echo $zdm_hosts | tr "," " "); do
		ip=$(echo "$ip2" | tr -d " ")
		let server=${server}+1

		getUser "$ip"
		zdm_user=$cuser

		lmsg N I "Test vm $ip"
		echo "Test vm $ip" >>"$runlog"

		timeout 3 ssh "$ip" &>/tmp/sshlog$$
		ret=$?

		if [[ $ret -eq 0 ]]; then
			tested_zdmhosts=$(echo "${tested_zdmhosts}${co}${ip}")
			co=","
			lmsg N I "Test vm $ip... OK"
			let ok_server=${ok_server}+1
		else
			lmsg N I "Test vm $ip... fails with retcode=$ret"
			lmsg N I "Erromsg=$(cat /tmp/sshlog$$)"
		fi
		rm /tmp/sshlog$$
	done
	lmsg N I "Step1-connect to zdm hosts: Anz Hosts=$server Aktiv=$ok_server: STATUS=$stat"
	lmsg N I "Tested and OK zdmsrv $tested_zdmhosts"
	echo "export tested_zdmhosts=$tested_zdmhosts" >>"$driver_file"

	write_resultsfile "$server" "$ok_server"
}

#-------------------------------------
# TNS-Verbindung von Ziel zu Quelle prüfen
function check_tns_tgt_to_src() {
	if [[ "$target_platform" == "EXAD" ]]; then
		checkValue "X${exaclnodes}" "tns 14"
		lmsg N I "checking tnsping from exa nodes ${exaclnodes} to source $source_ip"
		check_port "$exaclnodes" "$source_ip" "tnsping 1521"
		write_resultsfile "$cnt" "$cnts"
	else
		if [[ "$target_platform" == "ATPS" ]]; then
			lmsg N I "tnssping on adb not possible"
			write_resultsfile 0 0 "tnssping on adb not possible"
		fi
	fi

	lmsg N I "tns tests finished; tests=$cnt success=$cnts fails=$cntf"
}

#-------------------------------------
# Sudo-Berechtigungen auf Ziel prüfen
function check_sudo_tgt() {
	lmsg N I "in check_sudo_tgt 1"
	if [[ "$target_platform" == "EXAD" ]]; then
		checkValue "X${exaclnodes}" "nfs 14"
		lmsg N I "checking sudo on exa nodes ${exaclnodes}"

		cnt_nodes=0
		cnt_err=0
		populate_ip_array "$exaclnodes"

		for clnode in "${ip_array[@]}"; do
			check_sudo "$clnode"
			cnt_nodes=$((cnt_nodes + 1))
			cnt_err=$((cnt_err + sudo_error))
		done

		write_resultsfile "$cnt_nodes" $((cnt_nodes - cnt_err))
	else
		if [[ "$target_platform" == "ATPS" ]]; then
			lmsg N I "sudo on adb not possible"
			write_resultsfile 0 0 "sudo on adb not possible"
		else
			write_resultsfile 0 0 "internal error inv.platform"
		fi
	fi
}

#-------------------------------------
# Sudo-Berechtigungen auf Quelle prüfen
function check_sudo_src() {
	checkValue "X${source_ip}" "sudo-1"
	lmsg N I "check sudo on source db ${source_ip}"
	check_sudo "$source_ip"
	write_resultsfile 1 $((1 - sudo_error))
}

#-------------------------------------
# Sudo-Berechtigung prüfen
function check_sudo() {
	local check_ip=$1

	sudo_error=1
	timeout 4 ssh "${check_ip}" "/usr/bin/sudo -n -l"
	if [[ $? -eq 0 ]]; then
		sudo_error=0
		lmsg N I "sudo on ${check_ip} is OK"
	else
		lmsg N I "sudo on ${check_ip} FAILED"
	fi
}

#-------------------------------------
# SFTP-Verbindung von ZDM zu Quelle prüfen
function check_zdmvm_sftp_to_source() {
	checkValue "X${source_ip}" "sftp-3"

	ok_server=0
	sftp "$source_ip" <<EOF
quit
EOF
	if [[ $? -eq 0 ]]; then
		stat="$test_ok"
		ok_server=1
		lmsg N I "sftp to ${source_ip} is OK"
	else
		lmsg N I "sftp to ${source_ip} FAILED"
		stat="$test_fail"
	fi
	result=$(echo "$stat")
	write_resultsfile 1 "$ok_server"
}

#-------------------------------------
# SSH-Verbindung von ZDM zu Quelle prüfen
function check_zdmvm_to_source() {

	result=$(echo "$stat - Hosts=$server Aktiv=$ok_server")
	stat="FAIL"
	ok_server=0
	server=0

	#for zdmvm in "${ip_array[@]}"; do
	for zdmvm in $(echo $tested_zdmhosts | tr "," " "); do
		let server=${server}+1
		lmsg N I "checking $zdmvm to source host $source_hosts/$source_ip"

		ssh $ssh_options "$zdmvm" "ls -l ~/.ssh/${source_sid}.key"
		if [[ $? -ne 0 ]]; then
			lmsg N I "checking $zdmvm keyfile not in .ssh, backup + transfer"
			cmd=$(echo "scp $source_keyfile $zdmvm:~/.ssh/${source_sid}.key &> /dev/null")
			eval "$cmd"
		fi

		ssh $ssh_options "$zdmvm" "ls -l ~/.ssh/${source_sid}.key"
		if [[ $? -eq 0 ]]; then
			lmsg N I "try to connect....zdm to src"
			cmd=$(echo "-i ~/.ssh/${source_sid}.key $ssh_options $source_user@$source_ip")

			ssh_ret=$(timeout 3 ssh $ssh_options "$zdmvm" "ssh $cmd \"pwd\" &> /dev/null; echo $?")
			if [ $ssh_ret -eq 0 ]; then
				rpwd=$(ssh $ssh_options "$zdmvm" "ssh $ssh_options $cmd \"pwd\"")
				lmsg N I "return of pwd=$rpwd"
				if [ "X$rpwd" != "X" ]; then
					let ok_server=${ok_server}+1
					stat="COMPLETED"
					lmsg N I "trying;ssh $cmd \"pwd\"....succeeded"
				else
					lmsg N I "trying;ssh $cmd \"pwd\"....failed"
				fi
			else
				lmsg N I "trying;ssh $cmd \"pwd\"....failed"
			fi

		fi
	done
	lmsg N I "connect zdm to src hosts: Anz Hosts=$server Aktiv=$ok_server: STATUS=$stat"
	result=$(echo "$stat - Hosts=$server Aktiv=$ok_server")
	write_resultsfile "$server" "$ok_server"
}

#-------------------------------------------------------------------
function getpw() {

	{
		openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in ~/.ssh/vault.enc -out ~/.ssh/vault2 -pass pass:$p_pw
		ret1=$?
		source ~/.ssh/vault2

		ret2=$?
		rm ~/.ssh/vault2
		ret3=$?
	} &>/dev/null

}

#-------------------------------------
# Template-Prüfung (nicht implementiert)
function check_tmpl() {
	local mount_on=$1
	local mount_from=$2
	local nfs_version=$3

	lmsg N I "Function not implemented yet"
	result=$(echo "Unknown")
}

#-------------------------------------
# NFS-Mount-Befehlsdatei erstellen
function mount_nfs_cmdfile() {
	local nfs_file=$1
	local nip=${2}
	local nmp="${nfs_mountp}"

	checkValue "X${nip}" "nfs 12"
	checkValue "X${nfs_share}" "nfs 13"
	checkValue "X${nmp}" "nfs 14"
	checkValue "X${nfs_mountopt}" "nfs 15"
	checkValue "X${remote_dir}" "nfs 16"

	mnt=$(echo "${nip}:${nfs_share}")
	lmsg N I "preparing to mount ${nip}:${nfs_share} on mp $nmp"
	{
		echo "# mount zdm mount share"
		echo "#{"
		echo "    if [[ ! -d $nmp ]]; then"
		echo "        sudo mkdir -p $nmp"
		echo "    else"
		echo "        sudo umount -l $nmp &>$remote_dir/umount.log"
		echo "    fi"
		echo "    mount_aktiv=\$(df -kh | grep \"${nmp} \" | wc -l)"
		echo "    if [[ \$mount_aktiv -eq 0 ]]; then"
		echo "        timeout 5 sudo mount -t nfs $mnt $nmp -o $nfs_mountopt"
		echo "        if [[ \$? -ne 0 ]]; then"
		echo "            echo \"*** mount error\""
		echo "            exit 1"
		echo "        else"
		echo "            echo \"*** mount OK\""
		echo "        fi"
		echo "    else"
		echo "        echo \"*** mount OK\""
		echo "    fi"
		echo "    sudo chmod 777 $nmp"
		echo "    exit 0"
		echo "#} &> $remote_dir/mount_nfs.log"
	} >"$nfs_file"
	lmsg N I "generated NFS mount cmd file $nfs_file"
}

#-------------------------------------
# NFS auf Quelle mounten
function mount_nfs_on_src() {
	echo "in mount"
	local nfs_server=$1
	checkValue "X${source_ip}" "nfs 16"
	checkValue "X${remote_dir}" "nfs 17"
	checkValue "X${execute_mount_src}" "nfs 18"

	if [[ "$execute_mount_src" != "YES" ]]; then
		lmsg N I "Mount on source is disabled--> no MOUNT"
		write_resultsfile 0 0 "Mount on source is disabled--> use -n option to enable"
		return
	fi

	nfs_file="$tmp_dir/src_nfsmount$$.sh"
	mount_nfs_cmdfile "$nfs_file" $nfs_server
	checkErr $? "CR nfs cmd file"
	create_remote_testdir "$source_ip" "$remote_dir"
	checkErr $? "CR remote dir"

	lmsg N I "transfering nfs command file to $source_ip:$remote_dir/nfs_mount.sh"
	scp "$nfs_file" "$source_ip:$remote_dir/nfs_mount.sh"
	checkErr $? "scp srcmount"
	ssh "$source_ip" "chmod +x $remote_dir/nfs_mount.sh"
	checkErr $? "+x srcmount"
	timeout 5 ssh "$source_ip" "$remote_dir/nfs_mount.sh" &> $rootDir/tmp/nfs.log
	#checkErr $? "mount srcmount"

        # scp "$source_ip:$remote_dir/mount_nfs.log" $rootDir/tmp/nfs.log


	mount_result=$(cat $rootDir/tmp/nfs.log | grep "*** mount" | head -1)

	if [ "$mount_result" == "*** mount OK" ]; then
		write_resultsfile 1 1 "Mount on source done"
		lmsg N I "successfully mounted nfs-share on source $source_ip"
	else
		lmsg N I "Source Mount not possible - mount mot ok"
		write_resultsfile 1 0 "Mount on source failed - mount manual"
	fi
}

#-------------------------------------
# NFS auf EXAD mounten
function mount_nfs_on_EXAD() {
	local nfs_server=$1
	checkValue "X${exaclnodes}" "nfs 14"
	checkValue "X${remote_dir}" "nfs 15"

	lmsg N I ",ount nfs on exa-d nodes ${exaclnodes}"
	nfs_file="$tmp_dir/exad_nfsmount$$.sh"
	mount_nfs_cmdfile "$nfs_file" $nfs_server
	checkErr $? "CR nfs cmd file"

	IFS=',' read -r -a ip_array <<<"${exaclnodes}"
	if [[ ${#ip_array[@]} -eq 0 ]]; then
		ip_array=("${exaclnodes}")
	fi

	echo "" >/tmp/nfs
	mnt_ok=0
	mnt_srv=0
	for clnode in "${ip_array[@]}"; do
		lmsg N I "mount on $clnode"
		mnt_srv=$((mnt_ok + 1))
		create_remote_testdir "$clnode" "$remote_dir"
		checkErr $? "CR remote dir"

		scp "$nfs_file" "$clnode:$remote_dir/nfs_mount.sh"
		checkErr $? "scp examount"
		ssh "$clnode" "chmod +x $remote_dir/nfs_mount.sh"
		checkErr $? "+x examount"
		ssh "$clnode" "$remote_dir/nfs_mount.sh" &> $rootDir/tmp/nfs.log
		checkErr $? "mount examount"
		#scp "$clnode:$remote_dir/mount_nfs.log" $rootDir/tmp/nfs.log
		#checkErr $? "scp examount"

		mnt_stat=$(cat  $rootDir/tmp/nfs.log | grep "*** mount OK" | wc -l)
		if [[ $mnt_stat -gt 0 ]]; then
			lmsg N I "mount on $clnode done"
			mnt_ok=$((mnt_ok + 1))
		else
			lmsg N I "mount on $clnode done failed"
		fi
	done
	write_resultsfile "$mnt_srv" "$mnt_ok"
}

#-------------------------------------

function show_adb_mp() {

	checkValue "X${adbname}" "nfs 34"
	checkValue "X${TNS_ADMIN}" "nfs 31"
	checkValue "X${ORACLE_HOME}" "nfs 32"

	lmsg N I "mount=${nfs_server}:${nfs_share}"
	sqlpb=$(echo "timeout 30 sqlplus  /@${adbname}_tp")

	lmsg N I "mount=$nfs_share"

	eval "$sqlpa" <<EOF
        set serveroutput on;
        set linesize 300;
        set linesize 3000
        set pagesize 202
        set heading off


      column FILE_SYSTEM_NAME      format A15
      column FILE_SYSTEM_LOCATION  format A30
      column DIRECTORY_NAME        format A30
      column DIRECTORY_PATH        format A30
      column NFS_VERSION           format A7

      spool ${dbResultDir}/${test_to_run}_adbmounts_msg.txt"


       SELECT FILE_SYSTEM_NAME,
               FILE_SYSTEM_LOCATION,
               DIRECTORY_NAME,
               DIRECTORY_PATH,
               NFS_VERSION
        FROM dba_cloud_file_systems;

        spool off;
        exit;
EOF

	write_resultsfile 1 1 "nfs mount adb listed"
	lmsg N I "list done"

}

# NFS auf ADB mounten
function mount_nfs_on_adb() {
	if [[ "X${adbname}" == "X" ]]; then
		write_resultsfile 0 0 "nfs mount adb - no ADB target given"
		return
	fi

	checkValue "X${adbname}" "nfs 34"
	checkValue "X${nfs_server}" "nfs 37"
	checkValue "X${nfs_share}" "nfs 38"
	checkValue "X${sqlDir}" "nfs 33"
	checkValue "X${TNS_ADMIN}" "nfs 31"
	checkValue "X${ORACLE_HOME}" "nfs 32"

	dirname="ZDM_DIR_$$"
	fsname="FS_ZDM_$$"

	lmsg N I "mount=${nfs_server}:${nfs_share}"
	sqlpa=$(echo "timeout 30 sqlplus /@${adbname}_tp")
	sqlpb=$(echo "timeout 30 sqlplus -s /@${adbname}_tp")

	local port=2049

	lmsg N I "ADB-S mount:"
	lmsg N I "server=$nfs_server"
	lmsg N I "mount=$nfs_share"

	eval "$sqlpa" <<EOF
        set serveroutput on;
        set linesize 300;
        sta ${sqlDir}/procedure_nfs_share.sql;
        /
        set linesize 3000
        set pagesize 202
        set heading off

      /*
        exec FS_SHARE ( 'UNALL', '$dirname', '$fsname', '$nfs_server', '$nfs_share', '$nfs_mountp', 'test access');
        SELECT 'exec DBMS_CLOUD_ADMIN.DETACH_FILE_SYSTEM ( file_system_name => '''||FILE_SYSTEM_NAME||''');' FROM dba_cloud_file_systems;

        declare
            cursor all_fs is
                SELECT * FROM dba_cloud_file_systems;
        BEGIN
            DBMS_OUTPUT.PUT_LINE('dropdone');
            for cfs in all_fs loop
                begin
                    DBMS_OUTPUT.PUT_LINE('drop '||cfs.FILE_SYSTEM_NAME||' dir='||cfs.directory_name);
                    DBMS_CLOUD_ADMIN.DETACH_FILE_SYSTEM ( file_system_name => cfs.FILE_SYSTEM_NAME );
                    EXECUTE IMMEDIATE 'DROP DIRECTORY '||cfs.directory_name;
                    commit;
                    DBMS_OUTPUT.PUT_LINE('drop done');
                exception
                    when others then
                        DBMS_OUTPUT.PUT_LINE(sqlerrm);
                        null;
                end;
            end loop;
        end;
        /
*/
        SELECT * FROM dba_cloud_file_systems;
        SELECT * FROM all_directories;
        commit;
        select user from dual;
        select object_name from user_objects;
        exit;
EOF

	lmsg N I "exec FS_SHARE ( 'MOUNT', $dirname, $fsname, $nfs_server, $nfs_share, '$nfs_mountp', 'test access');"
	mount_ret=$(
		eval "$sqlpb" <<EOF
        set serveroutput on;
        set linesize 300;
        set feedback off;
        exec FS_SHARE ( 'MOUNT', '$dirname', '$fsname', '$nfs_server', '$nfs_share', '$nfs_mountp', 'test access');
        exit;
EOF
	)

	nfs_test=$(
		eval "$sqlpb" <<EOF
        set serveroutput on;
        set linesize 300;
        set feedback off;

        declare
            l_file UTL_FILE.file_type;
            l_line varchar2(100);
            l_filename VARCHAR2(100) := '${adbname}_adbmount.test';
        begin
            l_file := UTL_FILE.fopen('$dirname', l_filename, 'w');
            UTL_FILE.PUT(l_file, 'SUCCSESS');
            UTL_FILE.fclose(l_file);
            l_file := UTL_FILE.fopen('$dirname', l_filename, 'r');
            utl_file.get_line(l_file, l_line);
            UTL_FILE.fclose(l_file);
            DBMS_OUTPUT.PUT_LINE('1');
        exception
            when others then
                DBMS_OUTPUT.PUT_LINE(sqlerrm);
                null;
        end;
        /
        exit;
EOF
	)

	if [[ "$mount_ret" == "1" && "$nfs_test" == "1" ]]; then
		write_resultsfile 2 2 "nfs mount adb $adbname dir=$dirname"
	else
		write_resultsfile 1 0 "nfs mount adb $adbname failed"
	fi
}

function mount_nfs_on_adb2() {
	if [[ "X${adbname}" == "X" ]]; then
		write_resultsfile 0 0 "nfs mount adb - no ADB target given"
		return
	fi
	local nfs_server="nfs212.internal.cloudapp.net.nfs"

	checkValue "X${adbname}" "nfs 34"
	checkValue "X${nfs_server}" "nfs 37"
	checkValue "X${nfs_share}" "nfs 38"
	checkValue "X${sqlDir}" "nfs 33"
	checkValue "X${TNS_ADMIN}" "nfs 31"
	checkValue "X${ORACLE_HOME}" "nfs 32"

	dirname="ZDM_DIRADB2_$$"
	fsname="FS_ZDMADB2_$$"

	lmsg N I "mount=${nfs_server}:${nfs_share}"
	sqlpa=$(echo "timeout 30 sqlplus /@${adbname}_tp")
	sqlpb=$(echo "timeout 30 sqlplus -s /@${adbname}_tp")

	local port=2049

	lmsg N I "ADB-S mount:"
	lmsg N I "server=$nfs_server"
	lmsg N I "mount=$nfs_share"

	lmsg N I "exec FS_SHARE ( 'MOUNT', $dirname, $fsname, $nfs_server, $nfs_share, '$nfs_mountp', 'test access');"
	mount_ret=$(
		eval "$sqlpb" <<EOF
        set serveroutput on;
        set linesize 300;
        set feedback off;
        exec FS_SHARE ( 'MOUNT', '$dirname', '$fsname', '$nfs_server', '$nfs_share', '$nfs_mountp', 'test access');
        exit;
EOF
	)

	nfs_test=$(
		eval "$sqlpb" <<EOF
        set serveroutput on;
        set linesize 300;
        set feedback off;

        declare
            l_file UTL_FILE.file_type;
            l_line varchar2(100);
            l_filename VARCHAR2(100) := '${adbname}_adbmount.test';
        begin
            l_file := UTL_FILE.fopen('$dirname', l_filename, 'w');
            UTL_FILE.PUT(l_file, 'SUCCSESS');
            UTL_FILE.fclose(l_file);
            l_file := UTL_FILE.fopen('$dirname', l_filename, 'r');
            utl_file.get_line(l_file, l_line);
            UTL_FILE.fclose(l_file);
            DBMS_OUTPUT.PUT_LINE('1');
        exception
            when others then
                DBMS_OUTPUT.PUT_LINE(sqlerrm);
                null;
        end;
        /
        exit;
EOF
	)

	if [[ "$mount_ret" == "1" && "$nfs_test" == "1" ]]; then
		write_resultsfile 2 2 "nfs mount adb $adbname dir=$dirname"
	else
		write_resultsfile 1 0 "nfs mount adb $adbname failed"
	fi
}

#-------------------------------------
# NFS auf Ziel mounten
function mount_nfs_on_tgt() {
	set -x
	checkValue "X${target_platform}" "nfs 90"

	if [[ "$execute_mount_tgt" != "YES" ]]; then
		lmsg N I "Mount on target is disabled--> no MOUNT"
		write_resultsfile 0 0 "Mount on target is disabled--> use -n option to enable"
		return
	fi

	case $target_platform in
	ATPS) mount_nfs_on_adb ;;
	EXAD) mount_nfs_on_EXAD "$nfs_ip" ;;
	*) checkError 1 "internal error tgt platform unknown >> $target_platform" ;;
	esac
}

# NFS auf Ziel mounten
function mount_nfs_on_tgt2() {
	set -x
	checkValue "X${target_platform}" "nfs 90"

	if [[ "$execute_mount_tgt" != "YES" ]]; then
		lmsg N I "Mount on target is disabled--> no MOUNT"
		write_resultsfile 0 0 "Mount on target is disabled--> use -n option to enable"
		return
	fi

	case $target_platform in
	ATPS) mount_nfs_on_adb2 ;;
	*) checkError 1 "this share (2nd adb) is not supported on >> $target_platform" ;;
	esac
}

#-------------------------------------
# NFS auf ADB prüfen
function check_nfs_adb() {
	checkValue "X${test_tns_alias}" "nfs 24"
	checkValue "X${nfs_server}" "nfs 27"
	checkValue "X${nfs_share}" "nfs 28"
	checkValue "X${sqlDir}" "nfs 24"

	dirname="dir$$"
	fsname="fs$$"

	lmsg N I "mount=${nfs_server}:${nfs_share}"
	local port=2049

	sqlpa=$(echo "timeout 30 sqlplus -s /@$test_tns_alias")
	sqlpb=$(echo "timeout 30 sqlplus -s /@$test_tns_alias @${rootDir}/sqls/check_db_connect.sql")

	lmsg N I "ADB-S mount:"
	lmsg N I "server=$nfs_server"
	lmsg N I "mount=$nfs_share"
	lmsg N I "sqla=$sqlpa"
	lmsg N I "sqlb=$sqlpb"

	eval "$sqlpb" <<EOF
        set serveroutput on;
        set linesize 300;
        set feedback off;
        set pagesize 0;
        sta ${sqlDir}/procedure_nfs_share.sql;
        /
        SELECT * FROM dba_cloud_file_systems;
        SELECT * FROM all_directories;
        commit;
        exit;
EOF

	lmsg N I "exec FS_SHARE ( 'MOUNT', $dirname, $fsname, $nfs_server, $nfs_share, '$nfs_mountp', 'test access');"
	mount_ret=$(
		eval "$sqlpa" <<EOF
        set serveroutput on;
        set linesize 300;
        set feedback off;
        exec FS_SHARE ( 'MOUNT', '$dirname', '$fsname', '$nfs_server', '$nfs_share', '$nfs_mountp', 'test access');
        exit;
EOF
	)

	unmount_ret=$(
		eval "$sqlpa" <<EOF
        set serveroutput on;
        set linesize 300;
        set feedback off;
        exec FS_SHARE ( 'UNMOUNT', '$dirname', '$fsname', '$nfs_server', '$nfs_share', '$nfs_mountp', 'test access');
        exit;
EOF
	)

	echo "mnt=$mount_ret"
	echo "mnt=$mount_ret"
	echo "unmnt=$unmount_ret"

	cnt=0
	if [[ "$mount_ret" == "1" ]]; then
		adbnfs_stat="ADB-MOUNT success"
	else
		adbnfs_stat="ADB-MOUNT FAILED"
		cnt=1
	fi
	if [[ "$unmount_ret" == "1" ]]; then
		adbnfs_stat="$adbnfs_stat - ADB-UNMOUNT success"
	else
		adbnfs_stat="$adbnfs_stat - ADB-UNMOUNT FAILED"
		cnt=1
	fi

	write_resultsfile "$cnt" 0 "$adbnfs_stat"
	lmsg N I "nfs tests finished; result $result"
}

#-------------------------------------
# NFS auf Ziel prüfen
function check_nfs_tgt() {
	local mount_on=$1
	local mount_from=$2
	local nfs_version=$3

	if [[ "$target_platform" == "EXAD" ]]; then
		check_nfs "$mount_on" "$mount_from" "$nfs_version"
	else
		if [[ "$target_platform" == "ATPS" ]]; then
			check_nfs_adb
		else
			lmsg N I "Function not implemented yet"
			result=$(echo "Unknown")
			write_resultsfile 0 0 "unknown"
		fi
	fi
}

#-------------------------------------
# NFS-Verbindung prüfen
function check_nfs() {
	local mount_on=$1
	local mount_from=$2
	local nfs_version=$3

	lmsg N I "check nfs ports to mount $mount_from on $mount_on with nfs version $nfs_version via tufin check"
	ret_code=0
	req_number="genNFS$$"
	mkdir "$configDir/tufin/$req_number"
	echo "${mount_on}/32" >"$configDir/tufin/$req_number/source.txt"
	echo "${mount_from}/32" >"$configDir/tufin/$req_number/target.txt"

	case $nfs_version in
	3) echo "TCP 2048" >"$configDir/tufin/$req_number/connect.txt" ;;
	4) echo "TCP 2049" >"$configDir/tufin/$req_number/connect.txt" ;;
	34)
		echo "TCP 2048" >"$configDir/tufin/$req_number/connect.txt"
		echo "TCP 2049" >>"$configDir/tufin/$req_number/connect.txt"
		echo "TCP 111" >>"$configDir/tufin/$req_number/connect.txt"
		;;
	*) ret_code=99 ;;
	esac

	lmsg N I "Start tufin check $req_number"
	"$scriptsDir/tufin_request_check.sh" "$req_number"

	if [[ -f "$resultDir/tufin/$req_number/summary.log" ]]; then
		cnt=0
		cnt_success=0
		cnt_fail=0
		for line in $(cat "$resultDir/tufin/$req_number/summary.log"); do
			let cnt=${cnt}+$(echo "$line" | cut -d ";" -f2)
			let cnt_success=${cnt_success}+$(echo "$line" | cut -d ";" -f3)
			let cnt_fail=${cnt_fail}+$(echo "$line" | cut -d ";" -f4)
		done

		stat="COMPLETED - no errors"
		if [[ $cnt_fail -gt 0 ]]; then
			stat="FAILED test=$cnt errors=$cnt_fail req=$req_number"
		fi
		mv "$configDir/tufin/$req_number" "$dbResultDir"
		mv "$resultDir/tufin/$req_number" "$dbResultDir/$req_number/summary"
	else
		stat="FAILED TUFIN $req_number"
	fi

	lmsg N I "nfs tests finished; tests=$cnt success=$cnt_success fails=$cnt_fail"
	result=$(echo "$stat")
	write_resultsfile "$cnt" "$cnt_success"
}

#-------------------------------------
# CPAT-Tool ausführen
function run_cpat_tool() {
	cnt_success=0
	local run_on=$1
	local gg=""
	local pref="${srcdb}_cpat_offline"

	lmsg N I "create cpad for $run_on"
	source ../premigration.env onprem
	cp "$TNS_ADMIN/tnsnames.ora" "$walletdir/tnsnames.ora"
	getpw
	set -x
	psa=$systemgsp
	lc=1
	status=""

	while true; do

		touch ${dbResultDir}/${pref}_premigration_advisor_report.json
		rm ${dbResultDir}/${pref}_premigration_advisor_report.json

		schemas=""
		if [ "X$cpat_schematas" != "X" ]; then

			schemas="--schema "

			for schema in $(echo $cpat_schematas | tr "," " "); do
				schemas="$schemas $schema"
			done
		fi

		#echo $schemas >>/tmp/schemas
		${cpat_dir}/premigration.sh \
			--connectstring "jdbc:oracle:thin:@${srcdb}?TNS_ADMIN=$walletdir" \
			--user system \
			--targetcloud ATPS \
			--outfileprefix $pref $schemas \
			--analysisprops "${cpat_dir}/properties/premigration_advisor_analysis.properties" \
			--reportformat text json html \
			--migrationmethod DATAPUMP $gg \
			--outdir "$cpatResultDir" <<EOF
$psa
EOF

		ok=0
		if [ -f ${cpatResultDir}/${pref}_premigration_advisor_report.json ]; then

			gg="GOLDENGATE"
			pref="${srcdb}_cpat_online"

			${cpat_dir}/premigration.sh \
				--connectstring "jdbc:oracle:thin:@${srcdb}?TNS_ADMIN=$walletdir" \
				--user system \
				--targetcloud ATPS \
				--outfileprefix $pref $schemas \
				--analysisprops "${cpat_dir}/properties/premigration_advisor_analysis.properties" \
				--reportformat text json html \
				--migrationmethod DATAPUMP $gg \
				--outdir "$cpatResultDir" <<EOF
$psa
EOF

			ok=1
			break
		fi
		psa=$systembasf
		let lc=${lc}+1

		if [ $lc -gt 2 ]; then
			status="cpat failed"
			ok=0
			break
		fi

	done
	lmsg N I "cpat status: $status"
	write_resultsfile 1 $ok "$status"
}

function run_dblk_tool() {

	source ../premigration.env onprem
	cp "$TNS_ADMIN/tnsnames.ora" "$walletdir/tnsnames.ora"

	status="dbl templat failed"
	ok=0

	sqlpb="timeout 30 sqlplus -s /@${srcdb}_system"
	{
		eval "$sqlpb" <<EOF
        set serveroutput on;
        set linesize 300;
        set feedback off;
        set pagesize 0;
        sta ${sqlDir}/create_dblinks_template.sql
        exit;
EOF

	} >$cpatResultDir/${srcdb}_dblinks.template.txt
	if [ -f $cpatResultDir/${srcdb}_dblinks.template.txt ]; then
		if [ $(cat $cpatResultDir/${srcdb}_dblinks.template.txt | grep -i "ORA-" | wc -l) -eq 0 ]; then
			tail -n +14 $cpatResultDir/${srcdb}_dblinks.template.txt >/tmp/$$temp && mv /tmp/$$temp $cpatResultDir/${srcdb}_dblinks.template.txt
			sed -i "s/^,/   ,/" $cpatResultDir/${srcdb}_dblinks.template.txt
			status="dbl template created"
			ok=1
		fi
	fi
	psa=$systembasf
	let lc=${lc}+1
	lmsg N I "dblink status: $status"
	write_resultsfile 1 $ok "$statua"
}

#-------------------------------------
# SQLPlus-Verbindung zu Ziel prüfen
function check_tnsping_to_tgt() {

	cnt_success=0
	local run_on=$1
	local tns=$2

	lmsg N I "check sqlconnect $run_on to $tns"

	if [ -z $TNS_ADMIN ]; then
		source $rootDir/premigration.env
	fi

	cat $TNS_ADMIN/tnsnames.ora | grep -i "^$tns" >$rootDir/tmp/tns$$.ora
	#cmd1="cat $TNS_ADMIN/tnsnames.ora | grep -i \"^$tns\" | sed 's/^"
	#cmd2="${cmd}=//' | head -1"
	#cmd="${cmd1}${tns}${cmd2}"

	#connecstr=$(eval "$cmd")
	echo "$connecstr"

	stat="FAILED"
	if [ ! -s $rootDir/tmp/tns$$.ora ]; then
		lmsg N E "connectstring for $tns not in tnsnames.ora"
	else
		lmsg N E "connectstring for $tns found"
		create_remote_testdir "$run_on" "$remote_dir"
		checkErr $? "remdir sql"
		ssh "$run_on" "cd $remote_dir"
		checkErr $? "cd remdir"
		#cmd1="cat ${scriptsDir}/sql_connectiontest.sh | sed  's/STRINGTOREPLACE/"
		#cmd2="/' > $rootDir/tmp/tns$$.sh"
		#cmd="${cmd1}${connecstr}${cmd2}"
		#eval $cmd

		scp "${scriptsDir}/sql_connectiontest.sh" "$run_on:$remote_dir/tns_tgt.sh"
		checkErr $? "scp ssh001"
		scp "$rootDir/tmp/tns$$.ora" "$run_on:$remote_dir/tnsnames.ora"
		checkErr $? "scp ssh002"

		ssh "$run_on" "chmod +x $remote_dir/tns_tgt.sh"
		ssh "$run_on" "bash $remote_dir/tns_tgt.sh $tns"
		ret=$?
		scp "$run_on:$remote_dir/sqlcon.log" "$dbResultDir/${log_file_number}_sqlout.log"
		checkErr $? "scp sql"

		if [[ $ret -eq 0 ]]; then
			cnt_success=$(cat "$dbResultDir/${log_file_number}_sqlout.log" | grep "TNSPINGOK" | wc -l)
			if [ $cnt_success -eq 1 ]; then
				stat="COMPLETED - SUCCESS"
			fi
		fi
	fi
	lmsg N I "source to target sqltest completed with status $stat"
	result=$(echo "$stat")
	write_resultsfile 1 "$cnt_success"
}

#-------------------------------------
# IP-Array füllen
function populate_ip_array() {
	local ip_string=$1
	checkValue "X${ip_string}" "ip 01"

	IFS=',' read -r -a ip_array <<<"${ip_string}"
	if [[ ${#ip_array[@]} -eq 0 ]]; then
		ip_array=("${ip_string}")
	fi

	for ip in "${ip_array[@]}"; do
		echo "${ip}/32"
	done

	ls -l
}

#-------------------------------------
# IPs in Datei schreiben
function write_ips_to_file() {
	local ip_array=$1
	local write_file=$2

	touch "$write_file"
	rm "$write_file"

	for ip in "${ip_array[@]}"; do
		echo "${ip}/32" >>"$write_file"
	done
}

#-------------------------------------
# OGG-Hub prüfen
function check_ogg_hub() {
	local ogg_ips=$1

	stat="FAIL"
	ok_server=0
	server=0
	result=$(echo "$stat - Hosts=$server Aktiv=$ok_server")

	checkValue "X${ogg_ips}" "ogghub 001"

	populate_ip_array "$ogg_ips"

	for hubvm in "${ip_array[@]}"; do
		let server=${server}+1
		lmsg N I "checking ogg vm $hubvm"

		cmd="curl --insecure -u oggadmin:3456 -H \"Content-Type: application/json\" -H \"Accept: application/json\" -X GET \"https://$hubvm/services/v2/deployments/Local\""
		{
			eval "$cmd"
		} &>"$tmp_dir/curl$$.out"
		cat "$tmp_dir/curl$$.out"

		if [[ $(cat "$tmp_dir/curl$$.out" | grep "OGG-12062" | wc -l) -gt 0 ]]; then
			lmsg N I "connection works OGG-12062!!"
			let ok_server=${ok_server}+1
			stat="COMPLETED"
		fi
	done
	lmsg N I "connect to ogg vm:  #OGG VMs:=$server Aktiv=$ok_server: STATUS=$stat"
	result=$(echo "$stat - Hosts=$server Aktiv=$ok_server")
	write_resultsfile "$server" "$ok_server"
}

#-------------------------------------
# Port-Verbindung prüfen
function check_port() {
	local from_ip=$1
	local to_ip=$2
	local tcpudp_port=$3

	checkValue $from_ip "chp port from"
	checkValue $to_ip "chp port to"
	checkValue $tcpudp_port "chp port"

	lmsg N I "check fw ports"
	lmsg N I "ip from $from_ip"
	lmsg N I "ip to $to_ip"
	lmsg N I "ports $tcpudp_port"

	ret_code=0
	req_number="genCON$$"
	mkdir "$configDir/tufin/$req_number"
	oratab_msg=""

	#   populate_ip_array "$from_ip"

	#   for ip in "${ip_array[@]}"; do
	for ip in $(echo $from_ip | tr "," " "); do
		echo "${ip}/32" >>"$configDir/tufin/$req_number/source.txt"
	done

	pwd

	#populate_ip_array "$to_ip"

	#for ip in "${ip_array[@]}"; do
	for ip in $(echo $to_ip | tr "," " "); do
		echo "${ip}/32" >>"$configDir/tufin/$req_number/target.txt"
	done

	echo "$tcpudp_port" >"$configDir/tufin/$req_number/connect.txt"

	cnts=$(wc -l $configDir/tufin/$req_number/source.txt)
	cntt=$(wc -l $configDir/tufin/$req_number/target.txt)
	cntc=$(wc -l $configDir/tufin/$req_number/connct.txt)
	let cnt=$cnts*$cbtt*$cntc

	lmsg N I "start tufin check with reqnr $req_number"
	lmsg N I "tufinfilles: $resultDir/tufin/$req_number"
	lmsg N I "tufinfilles to run: $cnt"

	"$scriptsDir/tufin_request_check.sh" "$req_number" </dev/null
	checkErr $? "tufin req"
	if [[ -f "$resultDir/tufin/$req_number/summary.log" ]]; then
		cnt_success=0
		for line in $(cat "$resultDir/tufin/$req_number/summary.log"); do
			let cnt_success=${cnt_success}+$(echo "$line" | cut -d ";" -f3)
		done

		let cnt_fail=${cnt}-${cnt_success}
		stat="COMPLETED - #test=$cnt errors=$cnt_fail req=$req_number"
		if [[ $cnt_fail -gt 0 ]]; then
			stat="FAILED - #test=$cnt errors=$cnt_fail req=$req_number"
		fi
		lmsg N I "move tufinfiles"
		mv "$configDir/tufin/$req_number" "$dbResultDir"
		mv "$resultDir/tufin/$req_number" "$dbResultDir/tufin/$req_number/summary"
	else
		stat="FAILED - TUFIN $req_number"
	fi
	lmsg N I "fw port tests finished; tests=$cnt success=$cnt_success fails=$cnt_fail"
	result=$(echo "$stat")
	write_resultsfile "$cnt" "$cnt_success"
}

#-------------------------------------
# Hauptlogik
{
	lmsg L I "Start test $test_to_run"
	#    lmsg N I "logf=${dbResultDir}/${log_file_number}_${test_to_run}.log"

	p_pw="y"
	set -x

	if [[ "X${adbname}" == "X" ]]; then
		adbname=$target_db_name
	fi

	case $test_to_run in
	sshToZdmVm) check_ssh_to_zdmsv ;;
	sshToSrc) check_zdmvm_to_source ;;
	sftpToSrc) check_zdmvm_sftp_to_source ;;
	checkSudoSrc) check_sudo_src "$source_ip" ;;
	checkSudoTgt) check_sudo_tgt ;;
	nfsTgt) check_nfs_tgt "$source_ip" "$nfs_ip" "$nfs_version" ;;
	nfsSrc) check_nfs "$source_ip" "$nfs_ip" "$nfs_version" ;;
	tnsTgt) check_tns_tgt_to_src ;;
	zdmToGGvm22) check_port "$tested_zdmhosts" "$ogg_vm" "tcp 22" ;;
	zdmToGGvm443) check_port "$tested_zdmhosts" "$ogg_vm" "tcp 443" ;;
	tnsZdmSrc) check_port "$tested_zdmhosts" "$source_ip" "tcp 1521" ;;
	tnsZdmTgt) check_port "$tested_zdmhosts" "$target_ip" "tcp 1521" ;;
	mntNfsSrc) mount_nfs_on_src "$nfs_ip" ;;
	src2nfs) mount_nfs_on_src "10.127.123.212" ;;
	mntNfsTgt) mount_nfs_on_tgt ;;
	adb2nfs) mount_nfs_on_tgt2 ;;
	tnsSrc) check_tnsping_to_tgt "$source_ip" "$target_tns_alias" ;;
	oggTgt) check_tnsping_to_tgt "$ogg_vm" "$target_tns_alias" ;;
	oggSrc) check_port "$ogg_vm" "$source_ip" "tnsping 1521" ;;
	oggHub) check_ogg_hub "$ogg_vm" ;;
	runCpat) run_cpat_tool ;;
	runDBlk) run_dblk_tool ;;
	showAdbmp) show_adb_mp ;;
	*) result="NONE,        not implemenetet yet" ;;
	esac
	set +x
	echo "$result" >"${tmp_dir}/${log_file_number}_${test_to_run}_status"
	lmsg L I "finished $test_to_run"
} &>"${dbResultDir}/${log_file_number}_${test_to_run}.log"

exit 0
