show_main_menu() {

	local read_cmdb_Y="Y"
	local read_cmdb_N="N"
	local read_only_Y="Y"
	local read_only_N="N"
	local sel_multi_Y="Y"
	local sel_multi_N="N"
	local page=1
	local selfile="$rootDir/tmp/appsel.$$"

	last_update="**unknown**"
	if [ -f /tmp/miginfo_refresh.log ]; then
		last_update=$(cat /tmp/miginfo_refresh.log | grep "finish" | cut -d "|" -f2)
	fi

	while true; do

		cd $rootDir/scripts
		check_ws $rootDir $ws_nr
		check_terminal_size

		if [ "X$run_cluster" == "X" ]; then
			exit
		fi

		function mhead() {
			# Bildschirm löschen, Hintergrund schwarz setzen, Text weiß
                        printf "\033[40;37m\033[2J\033[H"

			local txt=$1
			if [ "X$txt" == "X" ]; then
				txt="Select your Appication(s) to work on "
			fi
			clear
			gum style --foreground=$AC_GREEN --background=$AC_BLACK \
				--align center --width 130 --bold \
				"user: $ws_user - $mail_to WS#:${ws_nr}/$ws_status Cl-Nr: $run_cluster rf: $last_cmdb_refresh"

			gum style --foreground=$AC_RED --background=$AC_BLACK \
				--border rounded --margin "1 2" --padding "1 3" \
				--align center --width 130 --bold "$txt"
		}
		$rootDir/scripts/fetch_cmdb_data.sh appinfos_sel $run_cluster $selfile

		touch /tmp/x
		mhead "Select an Action in the menu-bar below"
		select_appinfo2 $run_cluster $read_only_Y $read_cmdb_Y $page $sel_multi_N "noinput" "$selfile"
		local max_page=$mig_app_max_page

		echo
		echo
		echo
		menubar="[q]quit,[1]RunCpt,[2]RunTest,[3]Results,[4]DispMigConf,[5]AdbToolbox,[6]ClConTest,[7]assignNFS,[8]SelectSchemas,//,"
		menubar="${menubar}[F]PageFwd,[B]PageBck,[c]SetCl,[e]ShowAppMig,[n]NFSServ,[m]MigData,[p]SrcPerfData,[x]SendCpats,[y]ShowSrcMounts"
		hmenu "${menubar}"

		local found=0

		mail_param=""
		if [ "X$mail_to" != "X" ]; then
			mail_param="-m $mail_to"
		fi

		cd $rootDir/scripts
		echo
		echo
		case $input in

		SendCpats)
			cpat_send_zip "$rootDir/cpat/results/cluster_$run_cluster" "$mail_to"
			;;

		SelectSchemas | DispMigConf | assignNFS | SrcPerfData)
			mhead
			mig_app_pk=""
			select_appinfo2 $run_cluster $read_only_N $read_cmdb_N $page $sel_multi_Y "noinput" "$selfile"

			if [ -s "$selfile" ]; then
				cnt=0
				anz_apps=$(wc -l <$selfile)
				for pk in $(cat $selfile | cut -d "|" -f3); do
					let cnt=${cnt}+1
					if [ "X$pk" != "X" ]; then

						nfsip=$(cat $selfile | grep $pk | cut -d '|' -f12)
						srcdb=$(cat $selfile | grep $pk | cut -d '|' -f6)

						case $input in
						DispMigConf) $rootDir/scripts/zdm_premigrationv2.sh -b $pk -r $run_cluster -t "000" -x skip; read -p "<--Press Enter-->" ;;
						assignNFS) change_assign_nc $pk "nfs" ;;
						SelectSchemas) change_assign_nc $pk "cpat" ;;
                                                  SrcPerfData) get_perf_data "$srcdb" "${srcdb}_system" "$rootDir/tmp/perf.out" "Y" ;;
						esac
					fi
					echo
					if [ $cnt -lt $anz_apps ]; then
						gum confirm $confirm_params "Continue/process next?" || break
					fi
				done
			else
				echo "nothing selected....."
				sleep 2
			fi

			;;

		PageFwd)
			if ((page < max_page)); then
				((page++))
				#  mhead
				#  select_appinfo2 $cluster_num $read_only_Y $read_cmdb_N $page
			else
				echo "Already on last page."
				sleep 1
			fi
			;;
		PageBck)
			if ((page > 0)); then
				((page--))
				#  mheadaa
				#  select_appinfo2 $cluster_num $read_only_Y $read_cmdb_N $page
			else
				echo "Already on first page."
				sleep 1
			fi
			;;

		RunCpt)
			run_cpat $run_cluster
			;;
		ShowAppMig | ClConTest | RunTest | ShowSrcMounts)
			clear
			mhead
			mig_app_pk=""
			select_appinfo2 $run_cluster $read_only_N $read_cmdb_N $page $sel_multi_Y "noinput" "$rootDir/tmp/appsel"

			if [ -s $rootDir/tmp/appsel ]; then

				case $input in
				RunTest)
					clear
					mhead
					select_testcases "$rootDir/tmp/tests_to_run.$$"
					if [ -s $rootDir/tmp/tests_to_run.$$ ]; then
						run_tests "$rootDir/tmp/appsel" "$rootDir/tmp/tests_to_run.$$"
					fi
					;;
				ShowSrcMounts)
					show_srcmounts "$rootDir/tmp/appsel"
					;;

				ClConTest)
					mhead "Select Applications"
					fetch_srchost $run_cluster "$rootDir/tmp/appsel"
					;;
				ShowAppMig)	
					mhead "Select Applications"
					show_app_migs "$rootDir/tmp/appsel"
					;;
				esac

			fi

			;;
		NFSServ)
			fetch_nfs "NO"
			echo
			read -p "<--Press enter-->"
			;;
		NFSloop)
			cnt=0
			./fetch_cmdb_data.sh select_nfs >/dev/null
			while true; do
				disp_nfs
				sleep 15
			done
			;;

		TgtConn)
			$rootDir/scripts/fetch_cmdb_data.sh tgtociids $run_cluster "$rootDir/tmp/tgtcon.$$"

			if [ -s "$rootDir/tmp/tgtcon.$$" ]; then

				for tgtc in $(cat "$rootDir/tmp/tgtcon.$$"); do

					id=$(echo $tgtc | cut -d"|" -f7)
					pf=$(echo $tgtc | cut -d"|" -f4)

					if [ "$pf" == "ExaDB" ]; then
						$rootDir/scripts/get_exapdbs.sh $id
					else
						$rootDir/scripts/get_tnsadbs.sh $id
					fi
				done

			fi

			;;

		Results)
			list_jobresults
			echo
			read -p "<--Press enter-->"
			;;
		MigToolbox)
			show_cluster_data $run_cluster
			;;
		AdbToolbox)
			adb_toolbox
			;;
		MigData)
			fetch_migdata
			;;
		CpatResult)
			check_cpat_runs
			;;
		SetCl)

			select_migcluster
			export run_cluster=$mig_cluster_num
			;;
		"" | quit)
			cleanup
			;;
		*)
			echo -e "${RED}Invalid selection!${NC}"
			;;
		esac
		input=""
		if [ "X$trace_actions" == "Xtrue" ]; then
			echo "menue; $(date); $callerip; $input" >>$trace_file
		fi
	done
}
