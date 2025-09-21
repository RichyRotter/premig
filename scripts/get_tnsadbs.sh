#!/bin/bash
#
#------------------------------#

# List of specific compartments to process
COMPARTMENTS_TO_PROCESS=(
	"ocid1.compartment.oc1..aaaaaaaaueltojv7bgpmgtvzvwxxdlvsl6cedwbtvwsvwing6clg4o5cuquq"
	"ocid1.compartment.oc1..aaaaaaaa7ptvflundl2vqwcl4yucstnls7fx3ctnlw26gfwmyckqzuuxpbza"
	"ocid1.compartment.oc1..aaaaaaaarrb6ikdpg7fbhbeqziehqcde4h4dugpmk7hjzfxd3sywrou7hnlq"
	"ocid1.compartment.oc1..aaaaaaaa7ybosg2uiitghvyprgy65ecnh2xnksxb4wh6k3je7zwhh52omsla"
)

function process_compartment() {
        compartment_id=$1
        echo "Processing Compartment: $compartment_id"

        res_list=$(oci db autonomous-database list --compartment-id "$compartment_id")
        if [ $? -eq 0 ]; then
                adb_ids=$(echo "$res_list" | grep '"id":' | grep ocid | cut -d":" -f2 | tr -d " " | tr -d "," | tr -d '"')
        else
                echo "error on comp."
                adb_ids=""
        fi

        for adb_id in $(echo $adb_ids); do
                data_db_name=""
                {
                adb_detail=$(oci db autonomous-database get --autonomous-database-id $adb_id)
                } &>/dev/null
                data_db_name=$(echo "$adb_detail" | jq -r '.data["db-name"]')
                if [ ! -z ${data_db_name} ]; then

                        data_db_name=$(echo "$adb_detail" | jq -r '.data["db-name"]')
                        data_display_name=$(echo "$adb_detail" | jq -r '.data["display-name"]')
                        printf "%-30s" "Processing ADB: $data_db_name"

                        {
                                timeout 3 sqlplus -s /@${data_db_name}_tp <<EOF
                                       select * from dual;
                                       select * from dual;
                                       select * from dual;
                                       exit;
EOF
                                ret=$?
                        } &>/dev/null
                        if [ $ret -ne 0 ]; then
                                printf "%-30s" "Adding TNS for $data_db_name"
                                ret2=$(./cr_tns_adb.sh $adb_id)
                                printf "%-30s" "$ret2"
                        else
                                printf "%-20s %-20s" "skip $data_db_name" "connect ok...."
                        fi
                        printf "%-1s\n" " "
                else
                        echo "error adb $adb_id - ret $?"
                fi
        done
}

function process_adbid() {

        local	adb_id="$1"

		data_db_name=""
		{
		adb_detail=$(oci db autonomous-database get --autonomous-database-id $adb_id)
	        } &>/dev/null
	        data_db_name=$(echo "$adb_detail" | jq -r '.data["db-name"]')
		if [ ! -z ${data_db_name} ]; then

		        data_db_name=$(echo "$adb_detail" | jq -r '.data["db-name"]')
			data_display_name=$(echo "$adb_detail" | jq -r '.data["display-name"]')
			printf "%-30s" "Processing ADB: $data_db_name"

			{
				timeout 3 sqlplus -s /@${data_db_name}_tp <<EOF
                                       select * from dual;
                                       select * from dual;
                                       select * from dual;
                                       exit;
EOF
				ret=$?
			} &>/dev/null
			if [ $ret -ne 0 ]; then
				printf "%-30s" "Adding TNS for $data_db_name"
				ret2=$(./cr_tns_adb.sh $adb_id)
				printf "%-30s" "$ret2"
			else
				printf "%-20s %-20s" "skip $data_db_name" "connect ok...."
			fi
			printf "%-1s\n" " "
		else
			echo "error adb $adb_id - ret $?"
		fi
}

##########################
# main
##########################

source ../premigration.env

adbid=$1

if [ "X$adbid" != "X" ]; then
        process_adbid $adbid
        exit
fi

# Process each compartment
for COMPARTMENT_ID2 in "${COMPARTMENTS_TO_PROCESS[@]}"; do

	process_compartment $COMPARTMENT_ID2
done
exit 0

s
exit 0
