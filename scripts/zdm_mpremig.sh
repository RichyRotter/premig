#!/usr/bin/env bash

# zdm_premigration.sh: Checks infrastructure readiness for ZDM database migration
# Usage: ./zdm_premigration.sh -d <oracledb-name> [-t <testnr> -a <adbname> -z <skipzdm> -c <skipconf> -n <mountnfs>]
# Version: 2.2, Date: 2025-05-16

#set -e -u -o pipefail

#^source ./init_variables.sh
source ../premigration.env cloud
source "${rootDir}/scripts/utils.sh"
manage_error_trap off
scriptsDir=${rootDir}/scripts

trap cleanup EXIT INT TERM

function cleanup() {

	cd /tmp
	rm p$$.sh &>/dev/null
	rm temp$$ &>/dev/null
	rm curent_screen_$$ &>/dev/null
        rm /tmp/*$$*  &>/dev/null

	if [ "X$trace_actions" == "Xtrue" ]; then
     
		echo ">>> mpremig check out $session_id ------------------------------------"  >> $trace_file
                echo `date`  >> $trace_file
                echo $SSH_CONNECTION >> $trace_file

	fi
        sleep 1
	exit
}

browse_files() {

	local dir="$1"
#	local dbdir="$2"
#	dir=$(find $rdir -maxdepth 1 | grep "$dbdir")

	# Check if directory exists
	if [[ ! -d "$dir" ]]; then
		echo "Error: '$dir' is not a valid directory."
		return 1
	fi

	# Enable nullglob so unmatched patterns are ignored
	shopt -s nullglob

	# Collect matching files
	local files=("$dir"/*.msg "$dir"/*.txt)

	# Disable nullglob again
	shopt -u nullglob

	if [[ ${#files[@]} -eq 0 ]]; then
		echo "No .log, .msg, or .txt files found in '$dir'."
                sleep 2
		return 0
	fi

	echo "Files in '$dir':"
	for i in "${!files[@]}"; do
		printf "%3d: %s\n" "$((i + 1))" "$(basename "${files[$i]}")"
	done

	while true; do
		read -r -p $'\nEnter a file number to view (q = quit): ' input </dev/tty

		if [[ "$input" == "q" ]]; then
			echo "Exiting."
			break
		elif [[ "$input" =~ ^[0-9]+$ ]]; then
			index=$((input - 1))
			if ((index >= 0 && index < ${#files[@]})); then
				echo
				echo "Content of: $(basename "${files[$index]}")"
				echo "----------------------------------------"
				cat "${files[$index]}"
				echo "----------------------------------------"
			else
				echo "Invalid number."
			fi
		else
			echo "Invalid input. Only a number or 'q' is allowed."
		fi
	done
}

function select_testcases() {
	FILE="$configDir/testcases.csv"
	"${scriptsDir}/fetch_cmdb_data.sh" testcases

	sort "$FILE" >/tmp/temp$$
	mv /tmp/temp$$ "$FILE"

	clear
	echo -e "\nAvailable Test Cases:\n"
	echo -e "Nr   Code          Desc                                Lf Lo Pf Po"
	echo -e "-------------------------------------------------------------------"
	column -t -s ':' "$FILE"

	# Extract valid test case numbers from the file (first column)
	valid_ids=$(cut -d':' -f1 "$FILE")

	# Prompt user input
	read -rp $'\nEnter space-separated test case numbers or q for exit: ' -a input_array </dev/tty

	for num in "${input_array[@]}"; do
		if [[ "$num" == "q" ]]; then
			echo "No test cases stored, returning..."
			sleep 1
			return
		fi
	done

	# Expand inputs (handle ranges like 5-9)
	expanded_numbers=()
	for item in "${input_array[@]}"; do
		if [[ "$item" =~ ^[0-9]+-[0-9]+$ ]]; then
			IFS='-' read -r start end <<<"$item"
			if ((start <= end)); then
				for ((i = start; i <= end; i++)); do
					expanded_numbers+=("$i")
				done
			else
				echo "Invalid range: $item (start > end)"
				return
			fi
		else
			expanded_numbers+=("$item")
		fi
	done

	tests_in_scope="001"
	for num in "${expanded_numbers[@]}"; do
		if ! [[ "$num" =~ ^[0-9]+$ ]]; then
			echo "Invalid input: '$num' is not a number."
			return
		fi

		padded=$(printf "%03d" $((10#$num)))

		if echo "$valid_ids" | grep -q "^$padded$"; then
			tests_in_scope+=" $padded"
		else
			echo "Invalid test number: '$padded' not found in testcases."
			return
		fi
	done

}

function check_mail() {



	    if [ "X$mail_to" != "X" ]; then

                if [ -d ${rootDir}/mailbox/tosend/${jobnr} ]; then

                   
		    cd ${rootDir}/mailbox/tosend
		    zip -r results_${jobnr}.zip ./${jobnr} &>/dev/null
		    if [ $? -eq 0 ]; then

                       cd ${rootDir}/mailbox/tosend/${jobnr}
		       {
	                 echo -e " "
		         echo -e "Hello,"
		         echo -e "find attached the results of premig job ${jobnr}"
	                 echo -e " "
  	  	         echo -e "BR Premig Test Suite"
		        } > ${rootDir}/mailbox/tosend/${jobnr}/bodyfile
		    
                 
		        mv ${rootDir}/mailbox/tosend/${jobnr} ${rootDir}/mailbox/sent
			mv ${rootDir}/mailbox/tosend/results_${jobnr}.zip ${rootDir}/mailbox/sent/${jobnr}
                        send_mail $mail_to "Premigration Test for job ${jobnr}" "${rootDir}/mailbox/sent/${jobnr}/bodyfile" "${rootDir}/mailbox/sent/${jobnr}/results_${jobnr}.zip"
			echo "mail sent to $mail_to"
                    else
			echo "ERROR creating mail content"
                    fi
		    sleep 1
		fi
           fi
           cd $startDir
}



function select_testcases_old() {

	FILE="$configDir/testcases.csv"
	${scriptsDir}/fetch_cmdb_data.sh testcases

	sort $FILE >/tmp/temp$$
	mv /tmp/temp$$ $FILE

	clear
	# Show the CSV file in a formatted table
	echo -e "\nAvailable Test Cases:\n"
	echo -e "Nr   Code          Desc                                Lf Lo Pf Po"
	echo -e "-------------------------------------------------------------------"
	column -t -s ':' "$FILE"

	# Extract valid test case numbers from the file (first column)
	valid_ids=$(cut -d':' -f1 "$FILE")

	# Prompt user input
	read -rp $'\nEnter space-separated test case numbers or q for exit: ' -a input_array </dev/tty
	for num in "${input_array[@]}"; do

		if [[ "$num" == "q" ]]; then
			echo "No test cases stored, returning..."
			sleep 1
			return
		fi
	done

	# Validate and process input
	tests_in_Scope=""
	for num in "${input_array[@]}"; do
		# Check if it's a number
		if ! [[ "$num" =~ ^[0-9]+$ ]]; then
			echo "Invalid input: '$num' is not a number."
			break
		fi

		# Pad with leading zeros
		padded=$(printf "%03d" "$num")

		# Check if it exists in the file
		if echo "$valid_ids" | grep -q "^$padded$"; then
			tests_in_scope=$(echo "$tests_in_scope $padded")
		else
			echo "Invalid test number: '$padded' not found in testcases."
			break
		fi
	done

}

show_mig_data() {

	local file="$1"
	local page_size=30
	local offset=0
	local clfilter="Cluster 1"
	local clnr=$use_cluster
	local filter=""
	local total_lines
	local runnr=0
	local selected_line
	local filtered_data
	local mail_par=""
	local runcluster=$use_cluster
	local dryrun=""
	tests_in_scope="$runTest"

	if [ "X$runcluster" != "X" ]; then
		clfilter="Cluster $runcluster"
	fi

	if [[ ! -f "$file" ]]; then
		echo "File not found: $file"
		return 1
	fi

	echo "#!/usr/bin/bash" >/tmp/p$$.sh
	echo "cd $rootDir/scripts" >>/tmp/p$$.sh
	while true; do
		# Apply optional filter

if [ "X$appnr" != "X" ] && [ -n "$clfilter" ]; then
    awk -F'|' -v cl="$clfilter" 'BEGIN{IGNORECASE=1} $13 == cl' "$file" >/tmp/temp$$
    filtered_data=$(awk "NR == $appnr" /tmp/temp$$)
else
    filtered_data=$(cat "$file")

    if [[ -n "$filter" ]]; then
        filtered_data=$(awk -F'|' -v f="$filter" 'BEGIN{IGNORECASE=1} $9 ~ f' "$file")
    fi

    if [[ -n "$clfilter" ]]; then
        filtered_data=$(awk -F'|' -v cl="$clfilter" 'BEGIN { IGNORECASE = 1 } $13 == cl' "$file")
    fi
fi




		total_lines=$(echo "$filtered_data" | wc -l)

		# Show current page
		mail_to=$(echo $mail_to | tr -d " ")
		clear
		echo
		echo "Total Apps: $total_lines --- mail to: $mail_to --- Cluster: $clnr --- Job-Nr.: $jobnr --- Testcases: $tests_in_scope    $dryrun"
		echo "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
		echo "Run queue:"
		cat /tmp/p$$.sh | grep zdm_premigration
		echo "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
		echo
		printf "%-5s %-15s %-40s %-15s %-23s %-18s %-10s %-28s %-12s\n" \
			"Nr" "MigCl" "App_Name" "Env_Orig" "Oracle_DB" "Migration" "Platform" "Target_Name" "cpat filter"
		echo "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

		{
    echo "$filtered_data" | sed -n "$((offset + 1)),$((offset + page_size))p" |
        awk -F'|' -v start=$((offset + 1)) '{
            shared = ($11 == "") ? "   " : "set";
            printf "%-5s %15s %-40s %-15s %-23s %-18s %-10s %-28s %-12s\n",
                   NR + start - 1, $13, $9, $10, $5, $3, $1, $2, shared
        }'
} > /tmp/current_screen_$$

		cat /tmp/current_screen_$$

		echo
		if [ "X$appnr" != "X" ]; then
			action=1
			echo "will use this src db/App"
			sleep 2
		else
		       echo -e  "[h]elp, [f]orward, [b]ack, [s]earch app, [c]luster, [a]ppl change-cluster, [t]estcases , [r]eset filter, [l]ist results, [m]ail , [nr] select, [x] run, [q]uit ? "
		       read -rp "command? >>"  action </dev/tty
		fi


                if [ "X$trace_actions" == "Xtrue" ]; then
                        echo "mprem; ${jobnr}; $(date); $caller_ip; $session_id; $action" >> $trace_file
                fi

		case "$action" in
		f)
			if ((offset + page_size < total_lines)); then
				offset=$((offset + page_size))
			else
				echo "Already at end of data."
			fi
			;;
		b)
			if ((offset - page_size >= 0)); then
				offset=$((offset - page_size))
			else
				offset=0
				echo "Already at beginning."
			fi
			;;
		i)
                        read -rp "App_Nr? " lnr </dev/tty

			if [ $(cat /tmp/current_screen_$$ | grep "^$lnr" | wc -l) -gt 0 ]  ; then
                               $rootDir/scripts/zdm_premigration.sh -l 1 -j $jobnr -r $clnr  -a $lnr -t "000"
                        else
                               echo "Skipping invalid app-nr: $lnr"
                               sleep 2
                        fi
			;;

		l)
			read -rp "App_Nr? " lnr </dev/tty
			selected_line=$(echo "$filtered_data" | sed -n "${lnr}p")
			if [[ -z "$selected_line" ]]; then
				echo "Invalid line number."
			else
			   	IFS='|' read -r \
			    	dbmp_target_platform dbmp_target_name dpmp_target_migr_methode \
					dbmp_test_tns_alias dbmp_oracle_db dbmp_env dbmp_dataclass dbmp_vnet \
					dbmp_app_name DBMP_ENV_ORIG DBMP_SHARED dbmp_target_tns_alias dbmp_migcluster dbmp_primkey <<<"$selected_line"

				export app_result_dir=$(echo "${dbmp_app_name}" | tr " " "_")

				if [ -d ${rootDir}/results/${jobnr}_${app_result_dir}.$dbmp_env ]; then
  			  	    browse_files ${rootDir}/results/${jobnr}_${app_result_dir}.$dbmp_env
				else
				    echo "no results avaiable"
				    sleep 2
			       fi
			fi
			;;
		a)
			echo " "
	                echo "Move Application to differnt Migration Cluster:"		
			read -rp "Select Applcation with App_Nr from screen (a=abort)? " lnr </dev/tty

			selected_line=$(echo "$filtered_data" | sed -n "${lnr}p")

			if [[ "$lnr" != "a" ]]; then
				echo "do nothing!" >> /dev/null
                          if [[ -z "$selected_line" ]]; then
                                echo "Invalid line number."
                          else
                                

                                IFS='|' read -r \
                                        dbmp_target_platform dbmp_target_name dpmp_target_migr_methode \
                                        dbmp_test_tns_alias dbmp_oracle_db dbmp_env dbmp_dataclass dbmp_vnet \
                                        dbmp_app_name DBMP_ENV_ORIG DBMP_SHARED dbmp_target_tns_alias dbmp_migcluster dbmp_primkey <<<"$selected_line"

                                 
				while true
				do
				   read -p "new cluster nr? " newclnr  </dev/tty
                                   case $newclnr in
					   1|2|3|4|5|6|7|8|9|10|11|12) break ;;
					                   *) echo "Wrong Cluster Nr" ;;
				   esac
				done
					                   

                                echo " "
				if [ "$dbmp_migcluster" != "Cluster $newclnr" ]; then
				    read -p "Move $dbmp_app_name $DBMP_ENV_ORIG from clluster $dbmp_migcluster to $newclnr ? (y=yes) " antw  </dev/tty 
				    if [ "$antw" == "y" ]; then
                                            ${scriptsDir}/fetch_cmdb_data.sh update_miginfo $dbmp_primkey "Cluster $newclnr"
					    ${scriptsDir}/fetch_cmdb_data.sh appinfos
				    else
					    echo "do nothing... skip"
				    fi
			        else 
				   echo "App already in cluster $newclnr ... do nothing... skip"
				fi
                          fi 
                          sleep 2 
			fi
                        ;;

		m)
			check_mail
			source ${scriptsDir}/zdm_setemail.sh select
			if [ "X$mail_to" != "X" ]; then
				mail_par=" -m $mail_to"
			fi
			;;
		t)
			select_testcases
			;;
		r)
			tests_in_scope=""
			clfilter=""
			filter=""
			offset=0
			runnr=0
			>/tmp/p$$.sh
			;;
		s)
			read -rp "Enter search term for app_name: " filter </dev/tty
			offset=0
			;;
		c)
			while true; do
				read -rp "Enter search term for Mig Cluster Nr " clnr </dev/tty
				case $clnr in
				1|2|3|4|5|6|7|8|9|10|11|12) break ;;
				*) echo "Wrong cluster nr" ;;
				esac
			done

			clfilter="Cluster $clnr"
			offset=0
			;;

			#---------------------------SELECT APP
		[0-9]*)
			tests=""
			if [ -n "$tests_in_scope" ]; then
				tests=" -t \"$tests_in_scope\""
			fi

			mail_par=""
			if [ "X$mail_to" != "X" ]; then
				mail_par=" -m $mail_to"
			fi

			# Load valid numbers from column 1 of the file once
			valid_numbers=$(awk '{print $1}' /tmp/current_screen_$$ | sort -n | uniq)

			# Convert to array for easier checking
			valid_array=($valid_numbers)

			is_valid_number() {
				local num="$1"
				for val in "${valid_array[@]}"; do
					if [ "$val" -eq "$num" ] 2>/dev/null; then
						return 0
					fi
				done
				return 1
			}

			# Prepare output script

			for act in $action; do
				# Detect range
				if [[ "$act" =~ ^[0-9]+-[0-9]+$ ]]; then
					apvon="${act%-*}"
					apto="${act#*-}"
					if ! [[ "$apvon" =~ ^[0-9]+$ && "$apto" =~ ^[0-9]+$ && "$apvon" -le "$apto" ]]; then
						echo "Invalid range: $act"
						continue
					fi
				else
					# Not a range, single value
					if ! [[ "$act" =~ ^[0-9]+$ ]]; then
						echo "Invalid number format: $act"
						continue
					fi
					apvon="$act"
					apto="$act"
				fi

				for apnr in $(seq "$apvon" "$apto"); do
					if is_valid_number "$apnr"; then
						let runnr=${runnr}+1
						if [ "X$cpatonly" == "X" ]; then
							echo "$rootDir/scripts/zdm_premigration.sh -l $runnr -j $jobnr $mail_par -r $clnr -n m -a $apnr $dryrun $tests $fix_arguments; sleep 3" >>/tmp/p$$.sh
						else
							echo "$rootDir/scripts/zdm_premigration.sh -l $runnr -j $jobnr $mail_par -r $clnr -n m -a $apnr $dryrun -p cpat; sleep 3" >>/tmp/p$$.sh
						fi
					else
						echo "Skipping invalid app-nr: $apnr"
						sleep 2
					fi
				done
			done

			chmod +x /tmp/p$$.sh
			;;

		#)------------------ Exiting
		q)
		        check_mail
			echo "Exiting."
			cleanup
			break
			;;

		xd)
			if [ "X$dryrun" == "X" ]; then
				dryrun="-x dryrun"
			else
				dryrun=""
			fi
			;;
		#------------------- RUN JOQUEUE
		x)

			total_lines=$(cat "/tmp/p$$.sh" | grep "zdm_premigration.sh" | wc -l)
			sed -E "s/ -l ([0-9]+)/ -l \1\/$total_lines/g" "/tmp/p$$.sh" >/tmp/tmpfile$$ && mv /tmp/tmpfile$$ "/tmp/p$$.sh"
			chmod +x /tmp/p$$.sh
			cat /tmp/p$$.sh														
			echo " "
			read -rp "are you sure (y=start/<any other>=return)? " antw </dev/tty
			if [ "$antw" == "y" ]; then
				cat /tmp/p$$.sh >> $trace_file
				/tmp/p$$.sh
				>/tmp/p$$.sh
				#break
			fi
			;;
	        h)
		        cat ${scriptsDir}/README.sh
			;;
		*)
			echo "Unknown action: $action"
			;;
		esac
		sleep 1
	done

}

# Pre-migration checks
pre_checks() {
	clear
	if [ ! -f ../premigration.env ]; then
		echo "wrong startdirectory... please run from <premig-root>/scripts dir ... exiting"
		exit 1
	fi

	dialogDir="${rootDir}/dialog/dia$dialogNr"
	crDirNoExists "${dialogDir}"
	checkErr $? "loading env vars"

	configDir="${rootDir}/configfiles"
	scriptsDir="${rootDir}/scripts"

	${scriptsDir}/fetch_cmdb_data.sh appinfos
	show_mig_data $configDir/appinfos.env
}

function usage() {
	echo "wrong usage!"
	exit 1
}

#####################################################################
# Main
####################################################################
dialogNr=$$
startDir=$(pwd)
caller_ip=$(echo $SSH_CONNECTION | awk '{ print $1 }')
trace_actions="false"
current_user=$(whoami)
dayfile=$(date +"%Y%m%d")
jobnr=$(date +"%Y%m%d%H%M%S")
trace_file="/tmp/premig_traces/${dayfile}_${jobnr}_actions.txt"


if  [ "$current_user" == "premig" ]; then

  if [ $(echo $SSH_CONNECTION | grep "10.127.123x203" | wc -l) -eq 0 ]; then

     session_id=$$
     echo ">>> mpremig check in $session_id ------------------------------------"  >> $trace_file
     echo `date`  >> $trace_file
     echo $SSH_CONNECTION >> $trace_file
     trace_actions="true"

  fi
else
  trace_actions="false"
fi


while getopts "t:z:r:n:m:p:" opt; do
	case $opt in
	t) runTest="$OPTARG" ;;
	z) xskipzdm="$OPTARG" ;;
	r) use_cluster="$OPTARG" ;;
	n) xmntnfs="$OPTARG" ;;
	m) mail_to="$OPTARG" ;;
	p)
		cpatonly="$OPTARG"
		runTest="017 020"
		;;
	*) usage ;;
	esac
done

fix_arguments=""

if [ ! -z $xskipzdm ]; then fix_arguments="$fix_arguments -z skip01"; fi
if [ ! -z $xmntnfs ]; then fix_arguments="$fix_arguments -n mount-nfs"; fi

pre_checks

exit 0
