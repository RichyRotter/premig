#!/bin/bash
#
#------------------------------#

. ./01_load_env.sh

# List of specific compartments to process
COMPARTMENTS_TO_PROCESS=(
	"ocid1.compartment.oc1..aaaaaaaaueltojv7bgpmgtvzvwxxdlvsl6cedwbtvwsvwing6clg4o5cuquq"
	"ocid1.compartment.oc1..aaaaaaaa7ybosg2uiitghvyprgy65ecnh2xnksxb4wh6k3je7zwhh52omsla"
)

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

function process_compartment() {
	compartment_id=$1
	#msg N "Processing Compartment: $compartment_id"

	# Fetch Databases
	edbs=$(oci db database list --compartment-id "$compartment_id")
	edb_ids=$(echo "dbn=$edbs" | grep "ocid1\.database" | grep ocid | grep -v .databasesoftwareimage | cut -d":" -f2 | tr -d " " | tr -d "," | tr -d '"')

	for edb_id in $(echo $edb_ids); do

		#echo "******id=$edb_id"
		edb_detail=$(oci db database get --database-id $edb_id)

		# Extract values using jq and set environment variables
		export CHARACTER_SET=$(echo "$edb_detail" | jq -r '.data["character-set"] // ""')
		export COMPARTMENT_ID=$(echo "$edb_detail" | jq -r '.data["compartment-id"] // ""')
		export CDB_DEFAULT=$(echo "$edb_detail" | jq -r '.data["connection-strings"]["all-connection-strings"]["cdbDefault"] // ""')
		export CDB_IP_DEFAULT=$(echo "$edb_detail" | jq -r '.data["connection-strings"]["all-connection-strings"]["cdbIpDefault"] // ""')
		export DB_HOME_ID=$(echo "$edb_detail" | jq -r '.data["db-home-id"] // ""')
		export DB_NAME=$(echo "$edb_detail" | jq -r '.data["db-name"] // ""')
		export DB_UNIQUE_NAME=$(echo "$edb_detail" | jq -r '.data["db-unique-name"] // ""')
		export DB_WORKLOAD=$(echo "$edb_detail" | jq -r '.data["db-workload"] // ""')
		export DB_ID=$(echo "$edb_detail" | jq -r '.data["id"] // ""')
		export IS_CDB=$(echo "$edb_detail" | jq -r '.data["is-cdb"] // ""')
		export LIFECYCLE_STATE=$(echo "$edb_detail" | jq -r '.data["lifecycle-state"] // ""')
		export NCHARACTER_SET=$(echo "$edb_detail" | jq -r '.data["ncharacter-set"] // ""')
		export SID_PREFIX=$(echo "$edb_detail" | jq -r '.data["sid-prefix"] // ""')
		export TIME_CREATED=$(echo "$edb_detail" | jq -r '.data["time-created"] // ""')
		export VM_CLUSTER_ID=$(echo "$edb_detail" | jq -r '.data["vm-cluster-id"] // ""')

		printf "%-20s %-35s %-10s %-10s %-20s\n" "$DB_NAME" "$DB_UNIQUE_NAME" "$LIFECYCLE_STATE" "$IS_CDB" "$TIME_CREATED"

	done

}

###########################
# main
##########################

msg L "Get a list of ExaDB"

# Process each compartment
printf "%-20s %-35s %-10s %-10s %-20s\n" "DB_NAME" "DB_UNIQUE_NAME" "STATE" "IS_CDB" "TIME_CREATED"
printf "%-20s %-35s %-10s %-10s %-20s\n" "-------" "--------------" "-----" "------" "------------"
for COMPARTMENT_ID2 in "${COMPARTMENTS_TO_PROCESS[@]}"; do

	process_compartment $COMPARTMENT_ID2
done

msg L "Finised"

exit 0
