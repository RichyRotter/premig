#!/usr/bin/env bash

# utils.sh: Utility functions for zdm_premigration.sh
# Version: 1.0, Date: 2025-05-16

# Note: Other functions (msg, cleanup, checkValue, etc.) assumed to exist above

# Manage ERR trap to catch non-zero exit statuses

manage_error_trap() {
	return;
  local action="$1"
  local error_func="${2:-}"
  if [ "X${action}" == "Xon" ]; then
    if [ "X${error_func}" == "X" ]; then
      echo "Error: No error-handling function specified" >&2
      exit 1
    fi
    if ! command -v "${error_func}" >/dev/null 2>&1; then
      echo "Error: Function '${error_func}' not found" >&2
      exit 1
    fi
#    set -o errtrace
#   trap "${error_func} \$?" ERR
  elif [ "X${action}" == "Xoff" ]; then
    trap - ERR
    set +o errtrace
  else
    echo "Error: Invalid action '${action}' (use 'on' or 'off')" >&2
    exit 1
  fi
}

# Handle errors caught by ERR trap
handle_error() {
  local exit_status="$1"
  local failed_cmd="${BASH_COMMAND}"
  local line_no="${BASH_LINENO[0]}"
  msg N E "Failed: '${failed_cmd}' (status ${exit_status}, line ${line_no})"
  # Log to CMDB (assumes srcdb is set, optional)
  if [ "X${srcdb:-}" != "X" ] && command -v fetch_cmdb_data.sh >/dev/null 2>&1; then
    "${scriptsDir}/fetch_cmdb_data.sh" storeres "${srcdb}" "999" "--FAILED---" "Failed: ${failed_cmd}" </dev/null &>/dev/null
  fi

  # Call write_resultsfile if active script is run_precheck.sh
  if [ "$generate_resultfile_on_error" == "YES" ]; then
    write_resultsfile 1 0 "internal error: value for ${txt:-unknown} not exists"
  fi

  # Call cleanup (avoid duplicates with EXIT trap)
  if command -v cleanup >/dev/null 2>&1; then
    cleanup
  fi
  # Exit to respect set -e (comment out to continue)
  exit ${exit_status}
}

function msg() {
 # write a mssg to std out and logdir
 # par 1 - action "L"=Large, "N" normal
 # par 2 - msg
 #
lmsg="${3}"
lact=${1}
ldat=`date  +"%Y%m%d-%H%M%S"`
ltype=${2}

 case $ltype in
   E) inftxt="[ERROR]" ;;
   I) inftxt="[INFO]" ;;
   *) inftxt="[UNKKOWN:$ltype]" ;;
 esac

 if [[ -f $LGfile  ]]; then
 {
  if [ "${lact}" == "L" ]; then
    echo -e ${ldat}"** =========================================================="
    echo -e ${ldat}"** ${inftxt} ${lmsg}"
    echo -e ${ldat}"** =========================================================="
    echo " "
  else
    echo -e ${ldat}"** ${inftxt} ${lmsg}"
  fi
 } >> $LGfile
 else
    if [ "${lact}" == "L" ]; then
     echo -e ${ldat}"** =========================================================="
     echo -e ${ldat}"** ${inftxt} ${lmsg}"
     echo -e ${ldat}"** =========================================================="
     echo " "
   else
      echo -e ${ldat}"** ${inftxt} ${lmsg}"
   fi

 fi
}

#--------------------------------------------------------------------------------------------


function cleanup() {
 i=0
}

#--------------------------------------------------------------------------------------------


function exitFileExists() {
           local fn=$1
           if [[ -f ${fn} ]]; then
                msg N E "file ${fn} exists !! "
		 # Call write_resultsfile if active script is run_precheck.sh
                  if [ "$generate_resultfile_on_error" == "YES" ]; then
                       write_resultsfile 1 0 "internal error: value for ${txt:-unknown} not exists"
                  fi
                  exit 1
           fi
}

#--------------------------------------------------------------------------------------------


function exitFileNotExists() {
           local fn=$1
           if [[ ! -f ${fn} ]]; then
                msg N E "file ${fn} not exists !! "
		 # Call write_resultsfile if active script is run_precheck.sh
                  if [ "$generate_resultfile_on_error" == "YES" ]; then
                       write_resultsfile 1 0 "internal error: value for ${txt:-unknown} not exists"
                  fi
                exit 1
           fi
}

#--------------------------------------------------------------------------------------------


function exitDirExists() {
           local fn=$1
           if [[ -d ${fn} ]]; then
                msg N E "dir ${fn} exists !! "
		 # Call write_resultsfile if active script is run_precheck.sh
                  if [ "$generate_resultfile_on_error" == "YES" ]; then
                       write_resultsfile 1 0 "internal error: value for ${txt:-unknown} not exists"
                       lmsg N E "internal error: value for ${txt:-unknown} not exists"
                  fi
                exit 1
           fi
}

#--------------------------------------------------------------------------------------------


function exitDirNotExists() {
           local fn=$1
           if [[ ! -d ${fn} ]]; then
                msg N E "dir ${fn} not exists !! "
		 # Call write_resultsfile if active script is run_precheck.sh
                  if [ "$generate_resultfile_on_error" == "YES" ]; then
                       write_resultsfile 1 0 "internal error: value for ${txt:-unknown} not exists"
                       lmsg N E  "internal error: value for ${txt:-unknown} not exists"
                  fi
                exit 1
           fi
}


#--------------------------------------------------------------------------------------------


function checkErr() {
        local errc=$1
        local txt=$2

        if [[ $errc -ne 0 ]]; then
                echo "error $txt ... exit"
		 # Call write_resultsfile if active script is run_precheck.sh
                  if [ "$generate_resultfile_on_error" == "YES" ]; then
                       write_resultsfile 1 0 "internal error: value for ${txt:-unknown} not exists"
                       lmsg N E  "internal error: value for ${txt:-unknown} not exists"
		       echo " "
		       echo "internal error $txt"
                  fi
		   # ACHTUNG: exit beendet alles, return bleibt im Script
      exit 1    # standalone aufgerufen → normal beenden
        fi
}




#--------------------------------------------------------------------------------------------


function checkValue() {
           local fn=$1
	   local txt=$2
           if [[ "${fn}" == "X"  ]]; then
                msg N E "value for  ${txt} not exists !! "
		 # Call write_resultsfile if active script is run_precheck.sh
                  if [ "$generate_resultfile_on_error" == "YES" ]; then
                       write_resultsfile 1 0 "internal error: value for ${txt:-unknown} not exists"
                       lmsg N E  "internal error: value for ${txt:-unknown} not exists"
                  fi
                exit 1
           fi
}


#--------------------------------------------------------------------------------------------

function crDirNoExists() {

local Dir=$1

 if [[  "X${Dir}" == "X" ]]; then
   msg N E "no directory given"
   exit 2
 fi
 sdat=$(date  +"%Y%m%d-%H%M%S")
 if [[ -d ${Dir} ]]; then
   basedir=$(dirname ${Dir})
   basefile=$(basename ${Dir})
   mkdir -p $basedir/tmp 
   mv ${Dir} $basedir/tmp/${basefile}.${sdat}
   if [[ $? -ne 0 ]]; then
      msg N E "$DGir  not moveable to $basedir/tmp/${basefile}.${sdat}!! "
      exit 4
   fi
 fi
 mkdir -p ${Dir}

 touch ${Dir}/ftest
 if [[ $? -ne 0 ]]; then
    ´msg N E "$Dir  not accessble !! "
    exit 3
 else
  rm ${Dir}/ftest
 fi
}


#--------------------------------------------------------------------------------------------
function send_mail() {
    local to="$1"
    local subject="$2"
    local body="$3"
    local attachment="$4"

    sudo touch /tmp/sm.log
    sudo rm /tmp/sm.log

    {
    set -x 
    if [[ -z "$to" || -z "$subject" || -z "$body" ]]; then
        return 1
    fi

    if [[ ! -f "$body" ]]; then
	bodymessage="echo \"$body\""
    else
        bodymessage="cat $body"
    fi

    att=""
    if [[ ! -z "$attachment" ]]; then
	for af in $attachment
	do
	   if [ -f $af ]; then
        	att="$att -a \"$af\""
	   fi
        done
    fi

    echo "set smtp=smtp://smtpout.basf.net:25" >$HOME/.mailrc
    echo "set from=\"premig@basf.com\"" >>$HOME/.mailrc

    mcmd="$bodymessage | mailx -s \"$subject\" $att \"$to\"" 
    eval $mcmd
    #{echo "Please find the attached file." | mailx -s "$subject" -a "$attachment" "$to"
    set +x
    } &>/tmp/sm.log
}



#--------------------------------------------------------------------------------------------

function write_driver_file() {


        {
          echo "export source_sid=$source_sid"                    ; echo "export source_user=oracle"
          echo "export zdm_user=\"zdmuser\""                      ; echo "export source_host=$source_host"
          echo "export source_keyfile=$source_keyfile"            ; echo "export source_ip=$source_ip"
          echo "export target_platform=$target_platform"          ; echo "export target_ip=$target_ip"
          echo "export zdm_hosts=$zdm_hosts"                      ; echo "export LGfile=$LGfile"
          echo "export dbResultDir=$dbResultDir"                  ; echo "export srcdb_connectstring=\"$srcdb_connectstring\""
          echo "export rootDir=$rootDir"                          ; echo "export test_conectstring=\"$test_conectstring\""
          echo "export exaclnodes=$exaclnodes"                    ; echo "export runlog=$dialogDir/runlog.txt"
          echo "export configDir=$configDir"                      ; echo "export nfs_server=$nfs_server"
          echo "export resultDir=$resultDir"                      ; echo "export sqlDir=$sqlDir"
          echo "export tmp_dir=$tmp_dir"                          ; echo "export mig_methode=$mig_methode"
          echo "export remDir=$remDir"                            ; echo "export db_home=$DB_HOME"
          echo "export nfs_ip=$nfs_ip"                            ; echo "export adbname=$adbname"
          echo "export nfs_share=$nfs_share"                      ; echo "export adb_conectstring=\"$adb_connect\""
          echo "export nfs_mountp=$nfs_mountp"                    ; echo "export nfs_adb_dir=$nfs_adb_dir"
          echo "export nfs_version=$nfs_version"                  ; echo "export scriptsDir=$scriptsDir"
          echo "export nfs_mountopt=$nfs_mountopt"                ; echo "export ORACLE_HOME=$ORACLE_HOME"
          echo "export execute_mount_tgt=$execute_mount_tgt"      ; echo "export TNS_ADMIN=$TNS_ADMIN"
          echo "export execute_mount_src=$execute_mount_src"      ; echo "export target_db_name=$target_db_name"
          echo "export ogg_vm=$ogg_vm"                            ; echo "export target_tns_alias=$target_tns_alias"
          echo "export tf_oraenv=$tf_oraenv"                      ; echo "export az_vnet=$az_vnet"
          echo "export skipzdm=$skipzdm"                          ; echo "export test_tns_alias=$test_tns_alias"
          echo "export cpat_dir=$cpat_dir"                        ; echo "export srcdb=$srcdb"
          echo "export cpatResultDir=$cpatResultDir"              ; echo "export cpat_schematas=$cpat_schematas"
	  echo "export mail_to=$mail_to"
        } > $driver_file

}


#--------------------------------------------------------------------------------------------

function init_control_files() {




        checkValue "X"$DB_UNIQUE_NAME "DB_UNIQUE_NAME"
        checkValue "X"$DB_NAME "DB_NAME"

        #clear
          {
          echo "Source:"                                         ; echo "-----------------------------------------------"
          echo "Database............... $oracledb"               ; echo "DB Name................ $oracle_osn"
          echo "Hostbame............... $source_host"            ; echo "IP adresse............. $source_ip"
          echo "Database Version....... $src_db_version"         ; echo "confidential........... $confidential"
          echo "Environement........... $environment"            ; echo "Data Classification.... $data_classification"
          echo "Cores.................. $src_db_cores"           ; echo "SGA.................... $src_db_sga"
          echo "PGA.................... $src_db_pga"             ; echo "Alloc.GB............... $src_db_allocgb"
          echo "Used GB................ $src_db_usedgb"          ; echo "Charset................ $src_db_charset"
          echo " " ; echo " " ; echo " " ; echo " "

          } > $dialogDir/sourcedb.txt

          {
          echo "TARGET:"                                        ; echo "---------------------------------------------------------------"
          echo "AZ Subscription....... $vn_az_subscr"           ; echo "Targetname............ $tgt_name"
          echo "Platform.............. ${target_platform}"      ; echo "Target DB Name........ ${target_db_name}"
          echo "Netzwerk...............$az_vnet"                ; echo "cluster/ADB Name...... $cluster_name$adbname"
          echo "cluster_nodes......... $exaclnodes"             ; echo "Environment........... ${xenv}"
          echo "Confidential.......... ${xconf}"                ; echo "Migration Methode..... ${mig_methode}"
          echo " "                                              ; echo "nfs sever............. $nfs_ip"
          echo "nfs sever name........ $nfs_server"             ; echo "nfs mountpoint........ $nfs_mountp"
          echo "nfs share............. $nfs_share"              ; echo "ogg hub............... $ogg_vm"
          echo "Terraform code........ $tf_oraenv"              ; echo "test connect tgt...... $test_tns_alias"

          } > $dialogDir/targetdb.txt

}


#----------------------------------------------------------
# help functions
#----------------------------------------------------------

function getUser() {

        local vm=$1

        cuser=$(cat $configDir/known_users | grep "$vm" | cut -d ";" -f2)
        if [[ -z $cuser  ]]; then
                cuser="oracle"
        fi
}


function lmsg() {
 # par 1 - action "L"=Large, "N" normal
 # par 2 - msg
 #
set +x
lmsg="${3}"
lact=${1}
ldat=`date  +"%Y%m%d-%H%M%S"`
ltype=${2}

 case $ltype in
   E) inftxt="[ERROR]" ;;
   I) inftxt="[INFO]" ;;
   *) inftxt="[UNKKOWN:$ltype]" ;;
 esac


  if [ "${lact}" == "L" ]; then
    echo ${ldat}"** =========================================================="    >> ${dbResultDir}/${log_file_number}_${test_to_run}_msg.txt
    echo ${ldat}"** ${inftxt} ${lmsg}"                                             >> ${dbResultDir}/${log_file_number}_${test_to_run}_msg.txt
    echo ${ldat}"** =========================================================="    >> ${dbResultDir}/${log_file_number}_${test_to_run}_msg.txt
    echo " "
 else
    echo ${ldat}"** ${inftxt} ${lmsg}" >> ${dbResultDir}/${log_file_number}_${test_to_run}_msg.txt
  fi
set -x
}


#---------------------------------------------------------

function write_resultsfile() {
	
	local testnr=$log_file_number    ; local testresult=""
	local add_comment=$3             ; local nr_tests=$1
	local nr_ok=$2                   ; local nr_fails=$((nr_tests - nr_ok))
        local lcom=$add_comment          ; local testok="PASSED"
        local testpartly="EXCEPTION"     ; local testfail="--FAILED---"

        testresult="$testok"

	lmsg N I "write result params: $1 - $2 - $3"
	if [ $nr_tests -gt 0 ]; then 
		lcom="Nr.Tested=$nr_tests OK=$nr_ok NOK=$nr_fails $add_comment"

                testresult="$testpartly"
                if [ $nr_tests -eq $nr_ok ]; then
                   testresult="$testok"
      	        fi
                if [ $nr_ok -eq 0 ]; then
                  testresult="$testfail"
                fi
        fi

        echo "${testnr};${testresult};${lcom}" > ${dbResultDir}/${testnr}_${test_to_run}.result
	lmsg N I "Test=${testnr} Result=${testresult} comment=${lcom}"
	

}

