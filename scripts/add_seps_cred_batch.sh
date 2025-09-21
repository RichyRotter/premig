#!/bin/bash
#
###set -e
#------------------------------------
function msg() {
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


  if [ "${lact}" == "L" ]; then
    echo ${ldat}"** ==========================================================" 
    echo ${ldat}"** ${inftxt} ${lmsg}"                                          
    echo ${ldat}"** =========================================================="  
    echo " "
 else
    echo ${ldat}"** ${inftxt} ${lmsg}"
  fi
}


#---------------------------------------------------------

function checkValue() {
           local fn=$1
           local txt=$2
           if [[ "${fn}" == "X"  ]]; then
  #         if [[ -z ${fn}  ]]; then

                msg N E " ${txt} "
                exit 1
           fi
}

#---------------------------------------------------------

function checkErr() {
        local errc=$1
        local txt=$2

        if [[ $errc -ne 0 ]]; then
                msg N E "error $txt ... exit"
                   exit 1
        fi
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
	 } &> /dev/null

	   let retg=${ret1}+${ret2}+${ret3}
	   if [ $retg  -ne 0 ]; then
		   msg N E "failed decrypt secrets ... exit"
		   exit 1
	   fi

}

	function find_pw_value() {

	local pkeys=$1
	local talias=$2
	timeout 3 tnsping $talias
        checkErr $? "tnsping  $talias failed"

	for pkey in $(echo $pkeys); do
         
           pwcmd="echo \$"$pkey
           pw_value=$(eval $pwcmd)


	   >/tmp/sqlout

     	   {
        sqlplus -s $p_user/$pw_value@$talias $assysdba << EOF

          SET HEAD OFF VERIFY OFF ECHO OFF  FEEDBACK OFF
          SET TRIMSPOOL ON
          set pagesize 0
        --  SET TERMOUT OFF
          set lines 132
          set linesize 3205
           select 'db-ok' from dual;
          exit;
EOF
       } > /tmp/sqlout 

       if [ "$(cat /tmp/sqlout)" == "db-ok" ]; then
		     break
	     else
		     pw_value=""
	     fi

       done 
       checkValue "$pw_value" "no pw for user $p_user"	  

}

function do_it() {

   
   db_alias=$(cat $TNS_ADMIN/tnsnames.ora | grep -i "^${p_alias}=" | head -n 1)
   checkValue "X$db_alias" "no alias found"

   pw_value=""
   pw_keys="" 
   assysdba=""

   case $p_user in

	   sys)     pw_keys="sysbasf sysgsp sysexad" 
		    assysdba=" as sysdba "
		    ;;

	   system)  pw_keys="systembasf systemgsp systemexad" ;;
	   admin)   pw_keys="adbadmin" ;;
	       *)   echo "wrong key"; exit ;;

   esac

   checkValue "X$pw_keys" "key for pw"


   dbalv1=$(echo $db_alias | cut -d "=" -f1)

   dbalv3="${dbalv1}_tp"
   if [ "$p_user" != "admin" ]; then
     dbalv3="${dbalv1}_$p_user"
   fi
   
   echo "Standard tns alias: $dbalv1"
   echo "New seps tns alias: $dbalv3"

# Remove -yi and fix sed to process piped input
   db_alias_neu=$(echo $db_alias | sed "s/^$dbalv1/$dbalv3/g")

   find_pw_value "$pw_keys" "$dbalv1"
   checkValue "X$pw_value" "no pw"


   if [ ! -d ${walletdir}/backup ]; then
	   mkdir ${walletdir}/backup
   fi

   ldat=`date  +"%Y%m%d-%H%M%S"`
   mkdir ${walletdir}/backup/$ldat
   cp ${walletdir}/cw*   ${walletdir}/backup/$ldat
   cp ${walletdir}/ew*   ${walletdir}/backup/$ldat
   cp ${walletdir}/*.ora ${walletdir}/backup/$ldat
   cp ${TNS_ADMIN}/tnsnames.ora ${walletdir}/backup/$ldat//tnsnames.ora.$p_env

   cat $TNS_ADMIN/tnsnames.ora | grep -v "${dbalv3}=(" > /tmp/tns$$
   mv  /tmp/tns$$ $TNS_ADMIN/tnsnames.ora
   echo $db_alias_neu >> $TNS_ADMIN/tnsnames.ora

   
  {
   orapki secretstore delete_credential -wallet $walletdir -pwd "$walletpw" -connect_string "$dbalv3"
   orapki secretstore create_credential -wallet $walletdir -pwd "$walletpw" -connect_string "$dbalv3"  -username "$p_user" -password "$pw_value"
   ret=$?
  } &> /dev/null
  checkErr $ret "add cred entry"

  #final check
  echo "timeout 3 sqlplus -s /@$dbalv3 $assysdba"
  timeout 3 sqlplus -s /@$dbalv3 $assysdba << EOF
                   select * from dual;
                   select * from dual;
                   select * from dual;
                exit;
EOF

            msg N I "-------------------------------------------------------"
            if [ $? -eq 0 ]; then
                     echo "success!"
             else
                     echo "FAIL!"
		     exit 1
             fi

}



function usage() {

   echo "usage: $0 -a <db_tns_alias> \ "
   echo "          -u) <db_user> \ "
   echo "          -p) <decrypt pw> \ "
   echo "          -b) <onpem>|<cloud> \ "
   echo "          -c) <cred pw key value>"	 

   exit 0

}




#############################################################################
# MAIN
############################################################################

while getopts "a:u:p:b:c:" opt; do
    case $opt in
        a) p_alias="$OPTARG" ;;
        u) p_user="$OPTARG" ;;
        p) p_pw="$OPTARG" ;;
        b) p_env="$OPTARG" ;;
        *) usage ;;
    esac
done

checkValue "X$p_alias" "missing aliasi -a"
checkValue "X$p_user"  "missing user -u"
checkValue "X$p_pw"    "missing encrypt pw -p"
checkValue "X$p_env"   "missing env -b "


case $p_env in
           cloud|onprem) echo "ok" > /dev/null ;;
                      *) echo "-b must be <cloud|onprem>"; exit 1 ;;
esac

case "${p_env}:${p_user}" in
	"cloud:admin") echo "ok" > /dev/null ;;
	"cloud:system") echo "ok" > /dev/null ;;
	"cloud:sys") echo "ok" > /dev/null ;;
 	 "onprem:sys") echo "ok" > /dev/null ;;
      "onprem:system") echo "ok" > /dev/null ;;
   "onprem:migration") echo "ok" > /dev/null ;;
                    *) echo "user/env wrong-b"; exit 1 ;;
esac



echo " "
if [ ! -f ../premigration.env ]; then
	echo "wrong startdirectory... please run from <premig-root>/scripts dir ... exiting"
	exit 1
fi

source ../premigration.env $p_env
checkValue "X$rootDir" "rootdir"


if [ $? -ne 0 ]; then
	echo "error loading env vars ... exitimg"
	exit 1
fi

getpw 

do_it
