#!/usr/bin/env bash

#Script to check if the infrstructure is ready to perform a migrtion
# with ZDM for given Database


#11.03.2024 v1.0. rr
#
echo " "
if [ ! -f ../premigration.env ]; then
        echo "wrong startdirectory... please run from <premig-root>/scripts dir ... exiting"
        exit 1
fi

source ../premigration.env


#------------------------------------

function xsleep() {

# Dauer des Sleep in Sekunden (kann angepasst werden)
local SLEEP_TIME=$1


echo "Starte Countdown für ${SLEEP_TIME} Sekunden..."
for ((i=SLEEP_TIME; i>0; i--)); do
    echo -ne "Noch $i Sekunden verbleibend...\r"
    sleep 1
done

echo -e "\n Zeit abgelaufen!"


}



function dbg() {

        local lnr=$1
	local msg=$2

	if [[ "X$debugOn" != "X" ]]; then
		echo "ln=$lnr msg=$msg"
	fi
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

 if [[ "$run_silent" != "true" ]]; then
   if [ "${lact}" == "L" ]; then
    echo ${ldat}"** =========================================================="
    echo ${ldat}"** ${inftxt} ${lmsg}"
    echo ${ldat}"** =========================================================="
    echo " "
   else
    echo ${ldat}"** ${inftxt} ${lmsg}"
   fi
 fi

 if [[ -f $LGfile  ]]; then
 {
  if [ "${lact}" == "L" ]; then
    echo ${ldat}"** =========================================================="
    echo ${ldat}"** ${inftxt} ${lmsg}"
    echo ${ldat}"** =========================================================="
    echo " "
  else
    echo ${ldat}"** ${inftxt} ${lmsg}"
  fi
 } >> $LGfile
 fi
}

function write_on_screen() {

     local disp_command=$1
     if [[ "$run_silent" != "true" ]]; then
         eval $disp_command
     fi

}


function exitFileExists() {
	   dbg "$LINENR" "in exitFileExists"
           local fn=$1
           if [[ -f ${fn} ]]; then
                msg N E "file ${fn} exists !! "
                exit 1
           fi
}

function exitFileNotExists() {
	   dbg "$LINENR" "in exitFileNotExists"
           local fn=$1
           if [[ ! -f ${fn} ]]; then
                msg N E "file ${fn} not exists !! "
                exit 1
           fi
}

function exitDirExists() {
	   dbg "$LINENR" "in exitDirExists"
           local fn=$1
           if [[ -d ${fn} ]]; then
                msg N E "dir ${fn} exists !! "
                exit 1
           fi
}

function exitDirNotExists() {
	   dbg "$LINENR" "in exitDirNotExists"
           local fn=$1
           if [[ ! -d ${fn} ]]; then
                msg N E "dir ${fn} not exists !! "
                exit 1
           fi
}

function checkValue() {
	   dbg "$LINENR" "in checkValue"
           local fn=$1
	   local txt=$2
           if [[ "X${fn}" == "X"  ]]; then
                msg N E "value for  ${txt} not exists !! "
                exit 1
           fi
}

function crDirNoExists() {
	   dbg "$LINENR" "in crDirNoExists"

local Dir=$1

 if [[  "X${Dir}" == "X" ]]; then
   msg N E "no directory given"
   exit 2
 fi
 sdat=$(date  +"%Y%m%d-%H%M%S")
 if [[ -d ${Dir} ]]; then
   mv ${Dir} ${Dir}.${sdat}
   if [[ $? -ne 0 ]]; then
      msg N E "$DGir  not moveable !! "
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


function pre_checks() {
	
    checkValue $rootDir "root dir not set"

    currentDir=$(pwd)
    FName=$(basename "$currentDir")
    DName=$(dirname "$currentDir")
    PName=$(basename "$DName")


    if [[ "${PName}/${FName}" != "premigration/scripts" ]]; then
	msg N E "wrong sstart directory ${PName}/${FName}... exit"
	exit 1
    fi

    if [[ -z $tufin_reqnr ]]; then
	msg N E "missing tufin req  input par 1... exit"
	exit 1
    fi

    for subDir in configfiles/tufin tmp results/tufin
    do
	         if [[ ! -d ${rootDir}/${subDir} ]]; then
                     msg N E "Missing sub directory ${subDir}"
		     exit
		 fi
    done

    scriptsDir="${rootDir}/scripts"     
    configDir="${rootDir}/configfiles"
    reqSrcFile="${rootDir}/configfiles/tufin/$tufin_reqnr/source.txt"
    reqTgtFile="${rootDir}/configfiles/tufin/$tufin_reqnr/target.txt"

    if [[ "$reverse_input" == "reverse" ]]; then
	    msg N I "Reverse mode: target to source!!!"
            reqTgtFile="${rootDir}/configfiles/tufin/$tufin_reqnr/source.txt"
            reqSrcFile="${rootDir}/configfiles/tufin/$tufin_reqnr/target.txt"
    fi


    reqConFile="${rootDir}/configfiles/tufin/$tufin_reqnr/connect.txt"
    vmSrvFile="${rootDir}/configfiles/host_services.env"
    subnetDeligationFile="${rootDir}/configfiles/subnet_vms.env"
    resultDir="${rootDir}/results/tufin/$tufin_reqnr"
    remDir=/tmp/modernex_premig_checks

    crDirNoExists "${resultDir}"
    LGfile="${resultDir}/${tufin_reqnr}.log"

    exitFileNotExists $scriptsDir/ssh_connect.sh
    exitFileNotExists $scriptsDir/manage_ssh_config.sh
    exitFileNotExists $scriptsDir/run_precheck.sh
    exitFileNotExists $configDir/zdmhosts.env
    exitFileNotExists $configDir/known_users
    exitFileNotExists $reqSrcFile
    exitFileNotExists $reqTgtFile
    exitFileNotExists $reqConFile
    exitFileNotExists $subnetDeligationFile
    exitFileNotExists $vmSrvFile
    
    
    tmp_dir=${rootDir}/tmp/tmpfiles_${tufin_reqnr}_$$
    crDirNoExists $tmp_dir

    zdm_hosts=$(cat $configDir/zdmhosts.env) 	
    zdm_hosts=$(echo $zdm_hosts | tr -d " ")
    zdm_hosts="${zdm_hosts%,}"
    #search f.oracle 
    
    curHost=$(hostname)
    if [[ -f ${configDir}/${curHost}.env ]]; then
         source ${configDir}/${curHost}.env
    fi

    nrSourceEntries=$(cat $reqSrcFile | wc -l)
    nrTargetEntries=$(cat $reqTgtFile | wc -l)
    nrConnectEntries=$(cat $reqConFile | wc -l)
    let nrOfTests=${nrSourceEntries}*${nrTargetEntries}*${nrConnectEntries}
}

function replace_sn_with_vms() {
	   
	local file_to_read=$1
	local file_to_write=$2

	replacements=0
	touch $file_to_write
	rm  $file_to_write

 	while IFS='/' read -r ip nm; do
	     ip_type="O"
	     final_ip=""	
             if [[ "X$nm" == "X" ]]; then
		     msg N I "skiped $ip due to missing NM"
             else
		   if [[ "$nm" == "32" ]]; then
			   final_ip=$ip
	           else
			   final_ip=$(cat $subnetDeligationFile | grep "$ip/$nm" | head -1 | cut -d";" -f2)
                           if [[ "X$final_ip" != "X" ]]; then
	                      ip_type="R"
			      let replacements=${replacements}+1
			   fi
		  fi
            fi

            if [[ "X$nm" != "X" ]]; then
		    echo "${ip_type};${final_ip};${ip}/${nm}" >> $file_to_write
	    fi

	done < "$file_to_read"

}



function getUser() {

	local vm=$1

	cuser=$(cat $configDir/known_users | grep "$vm" | cut -d ";" -f2)
        if [[ -z $cuser  ]]; then
		cuser="oracle"
 	fi
}


function test_ssh() {
	

local inputfile=$1
	
cnt=1
sshfail=0

touch $tmp_dir/$$.skip
touch $tmp_dir/$$.keep

# Process the file
while IFS=';' read -r source_type source_ip2 source_orig_cidr; do
    # Clean up source_ip
    source_ip=$(echo "$source_ip2" | tr -d " ")
    write_on_screen "printf \"%-5s %-5s %-30s %-2s\" \">>>\" \"$cnt\" \"Processing $source_ip\" \": \""
    
    getUser "$source_ip2" $cuser < /dev/null

    cnt=$((cnt + 1))
    check="OK"

    timeout 2 ssh $ssh_options "${source_ip}" "pwd" < /dev/null &>> /dev/null
    if [[ $? -ne 0 ]]; then
       #$scriptsDir/ssh_connect.sh -n "$source_ip" -i "$source_ip" -u "$cuser" -x no  < /dev/null &>> /dev/null
       #ssh $ssh_options "${source_ip}" "pwd" < /dev/null &>> /dev/null
       #if [[ $? -ne 0 ]]; then
            sshfail=$((sshfail + 1))
            check="iNOk"
       #fi
    fi
        
    # Success or failure handling
    if [[ "$check" == "OK" ]]; then
        write_on_screen "echo \"success\""
        echo "${source_type};${source_ip};${source_orig_cidr};${cuser}" >> "$tmp_dir/$$.keep"
    else
        write_on_screen "echo \"FAILED - skipped\""
        echo "${source_type};${source_ip};${source_orig_cidr};${cuser}" >> "$tmp_dir/$$.skip"
    fi
        
done < "$inputfile"

mv $tmp_dir/$$.keep ${reqSrcFileReplaced}
mv $tmp_dir/$$.skip ${reqSrcFileReplaced}.skipped

msg L I "Tested ssh to src hosts................."
msg N I "Nr. of hosts added......$sshadded        "
msg N I "Nr. of hosts skipped....$sshfail        "
msg N I "logfile skipped hosts...${reqSrcFileReplaced}.skipped"

#xsleep 3

}

function create_remote_testdir(){

	local rhost=$1
	local rdir=$2

        #cat << EOF >$tmp_dir/crd.sh
  #         ssh $rhost << EOF 
      {
       echo "     cd /tmp"
       echo "     if [[ ! -d  $rdir ]]; then"
       echo "        mkdir $rdir"
       echo "        if [[ \$? -ne 0 ]]; then"
       echo "		     echo \"ERROR\""
       echo "        else"
       echo "            sudo chmod 777 $rdir"
       echo "            if [[ -f /etc/oratab ]]; then "
       echo "                ORACLE_HOME=\$(cat /etc/oratab | tail -1 | awk -F\":\" '{print \$2}')"
       echo "		     echo \"export ORACLE_HOME=\$ORACLE_HOME\" > $rdir/ora.env"
       echo "                echo \"export PATH=\$PATH:\$ORACLE_HOME/bin\" >> $rdir/ora.env"
       echo "                echo \"export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$ORACLE_HOME/lib\" >> $rdir/ora.env "
       echo "		     chmod +x $rdir/ora.env"
       echo "	         fi"
       echo "        fi"
       echo "     fi"
       } > $tmp_dir/crdir.sh
   
       chmod +x $tmp_dir/crdir.sh

       scp $tmp_dir/crdir.sh $rhost:/tmp &>/dev/null
       ssh $rhost "chmod +x /tmp/crdir.sh"
       retc=$(ssh $rhost "/tmp/crdir.sh")


}


function add_tcpudp() {

     local sip=$1
     local tip=$2
     local tprot=$3
     local tport=$4


    udp_flag=""
    if [[ "$tprot" == "udp" ]];then
       udp_flag="-u"
    fi

    cmd=$(echo "nc -zv -w 2 $udp_flag  $tip $tport")
    pcmd1=$(echo "nc -zv -w 2 $udp_flag")
    pcmd2=$(echo "$tip $tport")

   {
    echo "#-----------------------------------"
    echo "{"
    echo "return=\$($cmd) "
    echo "} &>/dev/null"
    echo "ret=\$? "
    echo "if [[ \$ret -eq 0 ]];then"
    echo "          printf \"%-25s %-19s %-22s %-12s\n\" \"[RESULT] $sip\" \"--> $pcmd1\" \"$pcmd2\" \" **SUCCESS**\""
    echo "else"
    echo "          printf \"%-25s %-19s %-22s %-12s\n\" \"[RESULT] $sip\" \"--> $pcmd1\" \"$pcmd2\" \" **FAILED*** retcode: \$ret\""
    echo "fi"
   }     >> $configDir/tufin/$tufin_reqnr/commandFile_$sip


}


function add_tnsping() {

     local sip=$1
     local tip=$2
     local tprot=$3
     local tport=$4

   pcmd="${tip}:$tport"

   {
    echo "#-----------------------------------"
    echo "cd ${remDir}"
    echo "source ./ora.env"
    echo "return=\$(timeout 2 tnsping ${tip}:$tport)"
    echo "if [[ \$? -eq 0 ]];then"
    echo "          printf \"%-25s %-19s %-22s %-12s\n\" \"[RESULT] $sip\" \"--> tnsping\" \"$pcmd\" \" **SUCCESS**\""
    echo "else"
    echo "          printf \"%-25s %-19s %-22s %-12s\n\" \"[RESULT] $sip\" \"--> tnsping\" \"$pcmd\" \" **FAILED***\""
    echo "fi"
   }     >> $configDir/tufin/$tufin_reqnr/commandFile_$sip



}

function add_test() {

     local sip=$1
     local tip=$2
     local tprot2=$3
     local tport=$4


     #check caapabillity of target

     tprot=$(echo $tprot2 | tr '[:upper:]' '[:lower:]')
     searchstring="${tip};${tprot};${tport}"
     can_do=$(cat $vmSrvFile | grep -i $searchstring | wc -l)
     
     can_do=100
     if [[ $can_do -gt 0 ]]; then

       case  $tprot in

	     tcp) add_tcpudp $sip $tip $tprot $tport ;;
	     udp) add_tcpudp $sip $tip $tprot $tport ;;
         tnsping) add_tnsping $sip $tip $tprot $tport ;;
	      *)  msg N I "wrong test .... $tprot" ;;
      esac

    else
	   echo ">>>Rejected Testcase; Target $tip not capabel of ${tprot}:${tport}" >> $LGfile
	   skipped_tgt_tests=$((skipped_tgt_tests + 1 ))
    fi

}

function transfer_run_analyse() {

 	local cmdf=$2
	local sip=$1

        # check tnsping
        create_remote_testdir "$sip" "$remDir" 
##set -x
        codesum=0
	retries=0
        while true
	do
           #scp "$cmdf" "$sip:${remDir}/tufincheck_${tufin_reqnr}.sh" &>/dev/null 
           scp  "$cmdf" "$sip:${remDir}/tufincheck_${tufin_reqnr}.sh" 
           rc1=$?
	   ssh  "$sip"  "chmod +x ${remDir}/tufincheck_${tufin_reqnr}.sh" &>/dev/null
           rc2=$?
  	   ssh  "$sip"  "${remDir}/tufincheck_${tufin_reqnr}.sh"
           rc3=$?

           retries=$((retries + 1))
	   codesum=$((rc1 + rc2 + rc3))

	   if [[ $codesum -eq 0 ]]; then
		   break
	   fi
	   if [[ $retries -gt 3 ]]; then
		   break
	   fi
              
	   sleep 5

	   ssh "$sip" "pwd"
        done
#set +x
	scp "$sip:${remDir}/tufintests.results" ${resultDir}/test_result_${sip}.log &>/dev/null
	cat  ${resultDir}/test_result_${sip}.log | grep "[RESULT]" >> $LGfile
        
	if [[ "$run_silent" != "true" ]]; then
           cat ${resultDir}/test_result_${sip}.log	
        fi
	
	rcnt=$(cat ${resultDir}/test_result_${sip}.log | grep "[RESULT]" | wc -l)
	rcnts=$(cat ${resultDir}/test_result_${sip}.log | grep "[RESULT]" | grep "**SUCCESS**" | wc -l)
	rcntf=$(cat ${resultDir}/test_result_${sip}.log | grep "[RESULT]" | grep "**FAILED**" | wc -l)
        msg N I "Host $sip - Nr Tests: $rcnt Súccess: $rcnts Failed: $rcntf "
	echo "${sip};${rcnt};${rcnts};${rcntf}" >> ${resultDir}/summary.log
       # sleep 300
}


#------------------------------------------------------------------------
##
function run_tests() { 
          write_on_screen "clear"
	  msg L I "Starting tufin test for req=${tufin_reqnr}"
	  msg N I "Tufin Request info:  "
          msg N I "root directory .........$rootDir        "
          msg N I "configuration dir.......$configDir      "
          msg N I "result dir..............$resultDir      "
          msg N I "from sourcefile.........$reqSrcFile     "
          msg N I "to targetfile...........$reqTgtFile     "
          msg N I "connection def-file.....$reqConFile     "
          msg N I " "
          msg N I "Nr. of source lines.....$nrSourceEntries"
          msg N I "Nr. of target lines.....$nrTargetEntries"
          msg N I "Nr. of connect options..$nrConnectEntries"
          msg N I " "
	  msg N I "I will run >>> $nrOfTests <<< tests in total"
          msg N I " "

	  msg N I "Replace source SN with deligated VMs"
	  reqSrcFileReplaced=${reqSrcFile}.repl
	  replace_sn_with_vms $reqSrcFile $reqSrcFileReplaced
	  msg N I "Nr. Replacements.....$replacements  "

	  msg N I "Replace target SN with deligated VMs"
	  reqTgtFileReplaced=${reqTgtFile}.repl
	  replace_sn_with_vms $reqTgtFile $reqTgtFileReplaced
	  msg N I "Nr. Replacements.....$replacements  "
   
 	  xsleep 5
          msg N I " "
          msg N I "Test ssh to src nodes "
	  test_ssh  $reqSrcFileReplaced

          runnr=0; cnt_ok=0; cnt_failed=0
          while IFS=';' read -r source_type source_ip source_orig_cidr; do
	      skipped_tgt_tests=0
              echo "{" > $configDir/tufin/$tufin_reqnr/commandFile_$source_ip           
	      while IFS=';' read -r target_type target_ip target_orig_cidr; do
		  while IFS=' ' read -r con_prot con_port; do
                      runnr=$((runnr + 1))
                      if [[ "$run_silent" != "true" ]]; then
                         echo -ne ">>> procesing test nr: $runnr  $source_ip -> $target_ip  ${con_prot}:${con_port} \r" 
	              fi
		      add_test "$source_ip" "$target_ip" "${con_prot}" "${con_port}" "${LGfile}" < /dev/null
                  done < "${reqConFile}"
              done < "${reqTgtFileReplaced}"
	      echo "} > $remDir/tufintests.results" >> $configDir/tufin/$tufin_reqnr/commandFile_$source_ip
              #echo " "
	      msg N I "Skipped non-capable target tests=$skipped_tgt_tests"
              transfer_run_analyse "$source_ip" "$configDir/tufin/$tufin_reqnr/commandFile_$source_ip"  < /dev/null
          done < "${reqSrcFileReplaced}"



  
  
 }

 function usage() {

  echo "usage $0 <tufincode> [ -r -s ] "

  
}

################################################################# 
############  M A I N   P R O C################################## 
################################################################# 

ssh_options="-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=3"
run_silent=""
reverse_input=""
tufin_reqnr=$1
shift

while getopts "r:s:" opt; do
    case $opt in
        s) run_silent="true" ;;
        r) reverse_input="reverse" ;;
        *) usage ;;
    esac
done

pre_checks
run_tests


msg L I "finished pre migration tufintests for req-nr: $tufin_reqnr"

