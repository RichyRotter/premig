#!/bin/bash
#
#------------------------------#
source ../premigration.env

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

function getpw() {

 {
           p_pw=y
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


function process_cdb() {
	cdb_id=$1
	msg N "Processing PDB:         $cdb_id        "

	edb_detail=$(oci db database get --database-id $cdb_id)

	CDB_IP_DEFAULT=$(echo "$edb_detail" | jq -r '.data["connection-strings"]["all-connection-strings"]["cdbIpDefault"] // ""')
	DB_NAME=$(echo "$edb_detail" | jq -r '.data["db-name"] // ""')
	DB_UNIQUE_NAME=$(echo "$edb_detail" | jq -r '.data["db-unique-name"] // ""')
	LIFECYCLE_STATE=$(echo "$edb_detail" | jq -r '.data["lifecycle-state"] // ""')

	echo "cdb.............: $DB_NAME"
	echo "cdb_connect.....: $CDB_IP_DEFAULT"

	cdb_tns_alias="${DB_NAME}"
	echo

	echo "test connect...."

	{
		timeout 3 tnsping $CDB_IP_DEFAULT
	} >/tmp/tnstest$$

	{
		timeout 3 sqlplus -s /@${cdb_tns_alias}_system <<EOF
                                         select * from dual;
                                         select * from dual;
                                         select * from dual;
                                         exit;
EOF
		ret=$?
	} >/dev/null

	echo "1"
	if [ $ret -ne 5 ]; then
	echo "2"

		tnsok=$(cat /tmp/tnstest$$ | grep "msec" | grep "^OK" | wc -l)
		cat /tmp/tnstest$$
		echo $tnsok
		rm /tmp/tnstest$$

		if [ $tnsok -eq 1 ]; then
	echo "3"

			if [ -f $TNS_ADMIN/tnsnames.ora ]; then
	echo "4"

				echo "connection ok"
				cp $TNS_ADMIN/tnsnames.ora $TNS_ADMIN/tnsnames.ora.sav

				tnsalines=$(cat $TNS_ADMIN/tnsnames.ora | wc -l)
				cat $TNS_ADMIN/tnsnames.ora | grep -v "^$cdb_tns_alias" >/tmp/tnsnames$$
				mv /tmp/tnsnames$$ $TNS_ADMIN/tnsnames.ora
				echo "$cdb_tns_alias=$CDB_IP_DEFAULT" | tr -d " " >>$TNS_ADMIN/tnsnames.ora
				tnsalines2=$(cat $TNS_ADMIN/tnsnames.ora | wc -l)
				echo "tnsnames lines before: $tnsalines now $tnsalines2"

	echo "5"

				./add_seps_cred_batch.sh -a "$cdb_tns_alias" -u sys -p y -b cloud
	echo "6"
				getpw
	echo "7"

				#{
					timeout 5 sqlplus  /@${cdb_tns_alias}_sys as sysdba <<EOF
                                             alter user system identified by "$systemexad" container=all;
                                             alter user system account unlock;
                                             select * from dual;
                                             exit;
EOF
					ret=$?
				#} >/tmp/altersystem$$.log

				if [ $ret -eq 0 ]; then
					cdbstatus="successfull"
				fi

			else
				echo "missing tnsnames.ora...."
			fi
		else
			echo "connct NOK"
		fi

	else
		echo "connect to ${cdb_tns_alias}_system succsful"
		cdbstatus="successfull"
	fi

}

###########################
# main
##########################

{
	cdbstatus="FAILED"

	cdb_ocid=$1
	process_cdb $cdb_ocid
} >/tmp/crtnscdb$$.log

msg I "Add EXADB CDB to $cdb_tns_alias was $cdbstatus"

exit 0
