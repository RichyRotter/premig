#!/bin/bash
#
#------------------------------#

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

function process_pdbid() {

       local pdb_id="$1"
                compartment_id=""
                res_detail=$(oci db pluggable-database get --pluggable-database-id $pdb_id)

                # Extract values from JSON stored in res_detail
                compartment_id=$(echo "$res_detail" | jq -r '.data["compartment-id"]')

                if [ ! -z $compartment_id ]; then
                        container_database_id=$(echo "$res_detail" | jq -r '.data["container-database-id"]')
                        id=$(echo "$res_detail" | jq -r '.data["id"]')
                        lifecycle_state=$(echo "$res_detail" | jq -r '.data["lifecycle-state"]')
                        open_mode=$(echo "$res_detail" | jq -r '.data["open-mode"]')
                        pdb_name=$(echo "$res_detail" | jq -r '.data["pdb-name"]')
                        time_created=$(echo "$res_detail" | jq -r '.data["time-created"]')
                        printf "%-30s" "Processing PDB: $pdb_name"                        


                        #echo "******id=$edb_id"
                        edb_detail=$(oci db database get --database-id $container_database_id)

                        # Extract values using jq and set environment variables
                        DB_NAME=$(echo "$edb_detail" | jq -r '.data["db-name"] // ""')
                        DB_UNIQUE_NAME=$(echo "$edb_detail" | jq -r '.data["db-unique-name"] // ""')
                        DB_ID=$(echo "$edb_detail" | jq -r '.data["id"] // ""')
                        IS_CDB=$(echo "$edb_detail" | jq -r '.data["is-cdb"] // ""')
                        LIFECYCLE_STATE=$(echo "$edb_detail" | jq -r '.data["lifecycle-state"] // ""')
                        TIME_CREATED=$(echo "$edb_detail" | jq -r '.data["time-created"] // ""')
                        CREATED_BY=$(echo "$edb_detail" | jq -r '.data["defined-tags"]["Oracle-Tags"]["CreatedBy"] // ""')

                        status=" "
                        #printf "%-10s %-35s %-10s %-10s %-15s  %-10s  %-10s  %-10s %-20s" \
                        #        "$DB_NAME" "$DB_UNIQUE_NAME" "$LIFECYCLE_STATE" "$IS_CDB" "$pdb_name" "$open_mode" "$lifecycle_state" "$time_created" "$status"

                        if [ "$LIFECYCLE_STATE" == "AVAILABLE" ] && [ "$lifecycle_state" == "AVAILABLE" ] && [ "$open_mode" == "READ_WRITE" ]; then
                                status=">>check conncect "
                         #       printf "\r%-10s %-35s %-10s %-10s %-15s  %-10s  %-10s  %-35s %-20s" \
                          #              "$DB_NAME" "$DB_UNIQUE_NAME" "$LIFECYCLE_STATE" "$IS_CDB" "$pdb_name" "$open_mode" "$lifecycle_state" "$CREATED_BY" "$status"

                                connc=$(./cr_tns_cdb.sh $container_database_id)
                                conn=$(./cr_tns_pdb.sh $pdb_id)
                                connok=$(echo $conn | grep "successfull" | wc -l)

                                echo $conn >>/tmp/conn

                                status="**OK**           "
                                if [ $connok -lt 1 ]; then
                                        status="**FAILED**       "
                                        echo "C: $container_database_id P: $pdb_id" >>/tmp/failed$$
                                fi
                           #     printf "\r%-10s %-35s %-10s %-10s %-15s  %-10s  %-10s  %-35s %-20s" \
                           #             "$DB_NAME" "$DB_UNIQUE_NAME" "$LIFECYCLE_STATE" "$IS_CDB" "$pdb_name" "$open_mode" "$lifecycle_state" "$time_created" "$status"

                        fi

                        printf "\r%-30s %-30s\n" "Processing PDB: $pdb_name" "Status: $status"                       
                else
                        echo "error read"
                fi


}

function process_compartment() {
	compartment_id=$1

	pdbs=$(oci db pluggable-database list --compartment-id "$compartment_id")
	pdb_ids=$(echo "dbn=$pdbs" | grep pluggable | grep ocid | cut -d":" -f2 | tr -d " " | tr -d "," | tr -d '"')

	for pdb_id in $(echo $pdb_ids); do
		compartment_id=""
		res_detail=$(oci db pluggable-database get --pluggable-database-id $pdb_id)

		# Extract values from JSON stored in res_detail
		compartment_id=$(echo "$res_detail" | jq -r '.data["compartment-id"]')

		if [ ! -z $compartment_id ]; then
			container_database_id=$(echo "$res_detail" | jq -r '.data["container-database-id"]')
			id=$(echo "$res_detail" | jq -r '.data["id"]')
			lifecycle_state=$(echo "$res_detail" | jq -r '.data["lifecycle-state"]')
			open_mode=$(echo "$res_detail" | jq -r '.data["open-mode"]')
			pdb_name=$(echo "$res_detail" | jq -r '.data["pdb-name"]')
			time_created=$(echo "$res_detail" | jq -r '.data["time-created"]')

                        printf "%-30s" "Processing PDB: $pdb_name"                        
			#echo "******id=$edb_id"
			edb_detail=$(oci db database get --database-id $container_database_id)

			# Extract values using jq and set environment variables
			export DB_NAME=$(echo "$edb_detail" | jq -r '.data["db-name"] // ""')
			export DB_UNIQUE_NAME=$(echo "$edb_detail" | jq -r '.data["db-unique-name"] // ""')
			export DB_ID=$(echo "$edb_detail" | jq -r '.data["id"] // ""')
			export IS_CDB=$(echo "$edb_detail" | jq -r '.data["is-cdb"] // ""')
			export LIFECYCLE_STATE=$(echo "$edb_detail" | jq -r '.data["lifecycle-state"] // ""')
			export TIME_CREATED=$(echo "$edb_detail" | jq -r '.data["time-created"] // ""')
			export CREATED_BY=$(echo "$edb_detail" | jq -r '.data["defined-tags"]["Oracle-Tags"]["CreatedBy"] // ""')

			status=" "
			#printf "%-10s %-35s %-10s %-10s %-15s  %-10s  %-10s  %-10s %-20s" \
				"$DB_NAME" "$DB_UNIQUE_NAME" "$LIFECYCLE_STATE" "$IS_CDB" "$pdb_name" "$open_mode" "$lifecycle_state" "$time_created" "$status"

			if [ "$LIFECYCLE_STATE" == "AVAILABLE" ] && [ "$lifecycle_state" == "AVAILABLE" ] && [ "$open_mode" == "READ_WRITE" ] && [ "$CREATED_BY" == "default/delia.fritzenschaft@basf.com" ]; then
				status=">>check conncect "
				#printf "\r%-10s %-35s %-10s %-10s %-15s  %-10s  %-10s  %-35s %-20s" \
				#	"$DB_NAME" "$DB_UNIQUE_NAME" "$LIFECYCLE_STATE" "$IS_CDB" "$pdb_name" "$open_mode" "$lifecycle_state" "$CREATED_BY" "$status"

				connc=$(./cr_tns_cdb.sh $container_database_id)
				conn=$(./cr_tns_pdb.sh $pdb_id)
				connok=$(echo $conn | grep "successfull" | wc -l)

				echo $conn >>/tmp/conn

				status="**OK**           "
				if [ $connok -lt 1 ]; then
					status="**FAILED**       "
					echo "C: $container_database_id P: $pdb_id" >>/tmp/failed$$
				fi
				#printf "\r%-10s %-35s %-10s %-10s %-15s  %-10s  %-10s  %-35s %-20s" \
				#	"$DB_NAME" "$DB_UNIQUE_NAME" "$LIFECYCLE_STATE" "$IS_CDB" "$pdb_name" "$open_mode" "$lifecycle_state" "$time_created" "$status"

			fi
                        printf "\r%-30s %-30s\n" "Processing PDB: $pdb_name" "Status: $status"                       
		else
			echo "error read"
		fi

	done

}

###########################
# main
##########################

#msg L "Get a list of ExaPDB"

# Process each compartment
#printf "%-10s %-35s %-10s %-10s %-15s  %-10s  %-10s  %-35s %-20s\n" "DB_NAME" "DB_UNIQUE_NAME" "CDB_STATE" "IS_CDB" "pdb_name" "open_mode" "state" "time_created" "Connect?"
#printf "%-10s %-35s %-10s %-10s %-15s  %-10s  %-10s  %-35s %-20s\n" "-------" "--------------" "---------" "------" "--------" "---------" "-----" "------------" "--------"

pdbid=$1

if [ "X$pdbid" != "X" ]; then
	process_pdbid $pdbid
        exit
fi

# Process each compartment
for COMPARTMENT_ID2 in "${COMPARTMENTS_TO_PROCESS[@]}"; do

	process_compartment $COMPARTMENT_ID2
done

#msg L "Finished"

exit 0
