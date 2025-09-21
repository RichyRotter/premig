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

function process_pdb() {
	pdb_id=$1
	msg N "Processing PDB:         $pdb_id        "

	res_detail=$(oci db pluggable-database get --pluggable-database-id $pdb_id)

	# Extract values from JSON stored in res_detail
	compartment_id=$(echo "$res_detail" | jq -r '.data["compartment-id"]')
	container_database_id=$(echo "$res_detail" | jq -r '.data["container-database-id"]')
	lifecycle_details=$(echo "$res_detail" | jq -r '.data["lifecycle-details"]')
	lifecycle_state=$(echo "$res_detail" | jq -r '.data["lifecycle-state"]')
	open_mode=$(echo "$res_detail" | jq -r '.data["open-mode"]')
	pdb_name=$(echo "$res_detail" | jq -r '.data["pdb-name"]')
	pdb_ip_default=$(echo "$res_detail" | jq -r '.data["connection-strings"]["all-connection-strings"]["pdbIpDefault"]')

	edb_detail=$(oci db database get --database-id $container_database_id)

	CDB_IP_DEFAULT=$(echo "$edb_detail" | jq -r '.data["connection-strings"]["all-connection-strings"]["cdbIpDefault"] // ""')
	DB_NAME=$(echo "$edb_detail" | jq -r '.data["db-name"] // ""')
	DB_UNIQUE_NAME=$(echo "$edb_detail" | jq -r '.data["db-unique-name"] // ""')
	LIFECYCLE_STATE=$(echo "$edb_detail" | jq -r '.data["lifecycle-state"] // ""')

	echo "cdb.............: $DB_NAME"
	echo "cdb_connect.....: $CDB_IP_DEFAULT"

	pdb_tns_alias="${DB_NAME}_$pdb_name"
	echo "pdb............: $pdb_name"
	echo "pdb_state......: $lifecycle_state"
	echo "pdb_connect....: $pdb_ip_default"
	echo "pdb_tns_alias..: $pdb_tns_alias"
	echo

	echo "test connect...."

	{
		timeout 3 tnsping $pdb_ip_default
	} >/tmp/tnstest$$

	{
		timeout 3 sqlplus -s /@${pdb_tns_alias}_system <<EOF
                                         select * from dual;
                                         select * from dual;
                                         select * from dual;
                                         exit;
EOF
		ret=$?
	} >/dev/null

	if [ $ret -ne 0 ]; then

		tnsok=$(cat /tmp/tnstest$$ | grep "msec" | grep "^OK" | wc -l)
		cat /tmp/tnstest$$
		echo $tnsok
		rm /tmp/tnstest$$

		if [ $tnsok -eq 1 ]; then

			if [ -f $TNS_ADMIN/tnsnames.ora ]; then

				echo "connection ok"
				cp $TNS_ADMIN/tnsnames.ora $TNS_ADMIN/tnsnames.ora.sav

				tnsalines=$(cat $TNS_ADMIN/tnsnames.ora | wc -l)
				cat $TNS_ADMIN/tnsnames.ora | grep -v "^$pdb_tns_alias" >/tmp/tnsnames$$
				mv /tmp/tnsnames$$ $TNS_ADMIN/tnsnames.ora
				echo "$pdb_tns_alias=$pdb_ip_default" | tr -d " " >>$TNS_ADMIN/tnsnames.ora
				tnsalines2=$(cat $TNS_ADMIN/tnsnames.ora | wc -l)
				echo "tnsnames lines before: $tnsalines now $tnsalines2"

				./add_seps_cred_batch.sh -a "$pdb_tns_alias" -u system -p y -b cloud

				{
					timeout 3 sqlplus -s /@${pdb_tns_alias}_system <<EOF
                                             select * from dual;
                                             select * from dual;
                                             select * from dual;
                                             exit;
EOF
					ret=$?
				} >/dev/null

				if [ $ret -eq 0 ]; then
					pdbstatus="successfull"
				fi

			else
				echo "missing tnsnames.ora...."
			fi
		else
			echo "connct NOK"
		fi

	else
		echo "connect to ${pdb_tns_alias}_system succsful"
		pdbstatus="successfull"
	fi

}

###########################
# main
##########################

sudo chmod 777 /tmp/conpdb.log
{
	pdbstatus="FAILED"

	pdb_ocid=$1
	process_pdb $pdb_ocid
} > /tmp/conpdb.log

msg I "Add EXADB PDB to $pdb_tns_alias was $pdbstatus"

exit 0
