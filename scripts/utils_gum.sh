#!/usr/bin/env bash

# Utility functions for gum
# Version: 1.0, Date: 2025-08-09

bfg="" # Border foreground (hellgrau)
bbg="" # Border background (schwarz)

cfg="" # Cell foreground (weiß)
cbg="" # Cell background (schwarz)

hfg="2" # Header foreground (schwarz)
hbg="4" # Header background (hellgelb)

sfg="0"   # Selected foreground (schwarz)
sbg="255" # Selected background (hellcyan)

lines_per_page=30
confirm_params="--selected.background=248 --selected.foreground=0  --prompt.foreground=3"

function select_hmenu() {

	local CSV_FILE="$1"
	local DELIM="|"
	local plines=$(cat $CSV_FILE | wc -l)
	let plines=${plines}+2

	# Anzeige-Kopf & welche CSV-Spalten (1-basiert) in welcher Reihenfolge gezeigt werden
	local HEADERS="Sel,Name"
	local SOURCECOLS="1,2"
	local WIDTHS="4,40"
	local READ_ONLY="N"
	local START_AT_PAGE="1"

	# Verhalten
	local HOTKEY_COL="1" # 1-basiert, bezieht sich auf CSV-Originalspalten
	local RETURN_COL="1" # 1-basiert: welche CSV-Spalte zurückgegeben wird
	local ROWS_PER_PAGE="$plines"
	local XPOS="30" # linke obere Ecke (Spalte)
	local YPOS="8"  # linke obere Ecke (Zeile)

	# Farben (Namen: default, black, red, green, yellow, blue, magenta, cyan, white)
	local NORMAL_FG="white"
	local NORMAL_BG="default"
	local SELECTED_FG="black"
	local SELECTED_BG="white"

	# Header-Steuerung
	local HEADER_FLAG="--header=on"
	local HEADER_BG="black"
	local HEADER_FG="yellow"

	# Auswahlmodus & Joiner für multiple
	local SELECTION_FLAG="--selection=single" # oder: --selection=multiple
	local JOIN_FLAG="--join=,"                # bei multiple: Ausgabe-Delimiter
	local RESULT_FILE="/tmp/migcluster_result$$"

	# --- Aufruf ---
	# Now you can capture stdout while still seeing the UI
	python3 ./premig_csv_tool.py \
		"$SELECTION_FLAG" "$JOIN_FLAG" \
		"$HEADER_FLAG" --header-fg="$HEADER_FG" --header-bg="$HEADER_BG" \
		--result-file="$RESULT_FILE" --read-only="${READ_ONLY}" \
		--start-at-page=$START_AT_PAGE \
		"$CSV_FILE" "$DELIM" \
		"$HEADERS" "$SOURCECOLS" "$WIDTHS" \
		"$HOTKEY_COL" "$XPOS" "$YPOS" "$RETURN_COL" "$ROWS_PER_PAGE" \
		"$NORMAL_FG" "$NORMAL_BG" "$SELECTED_FG" "$SELECTED_BG"

	# read result
	if [[ -s "$RESULT_FILE" ]]; then
		export input
		input="$(<"$RESULT_FILE")"
		rm -f "$RESULT_FILE"
		return 0
		lse
		rm -f "$RESULT_FILE"
		return 1
	fi
}

function select_migcluster() {

	clear

	gum style --foreground=$AC_RED --background=$AC_BLACK \
		--border rounded --margin "1 2" --padding "1 3" \
		--align center --width 100 --bold \
		"Select a Modernex Migration Cluster"
	./fetch_cmdb_data.sh migcluster

	# --- Eingaben/Defaults ---
	local CSV_FILE="$rootDir/configfiles/migcluster.env"
	local DELIM="|"
	local plines=$(cat $CSV_FILE | wc -l)
	let plines=${plines}+2

	# Anzeige-Kopf & welche CSV-Spalten (1-basiert) in welcher Reihenfolge gezeigt werden
	local HEADERS="Cnr,Cname,Start,End,AnzApps"
	local SOURCECOLS="1,2,3,4,5"
	local WIDTHS="3,15,15,11,8"
	local READ_ONLY="N"
	local START_AT_PAGE="1"

	# Verhalten
	local HOTKEY_COL="1" # 1-basiert, bezieht sich auf CSV-Originalspalten
	local RETURN_COL="1" # 1-basiert: welche CSV-Spalte zurückgegeben wird
	local ROWS_PER_PAGE="$plines"
	local XPOS="23" # linke obere Ecke (Spalte)
	local YPOS="8"  # linke obere Ecke (Zeile)

	# Farben (Namen: default, black, red, green, yellow, blue, magenta, cyan, white)
	local NORMAL_FG="white"
	local NORMAL_BG="default"
	local SELECTED_FG="black"
	local SELECTED_BG="white"
	# Header-Steuerung
	local HEADER_FLAG="--header=on"
	local HEADER_BG="black"
	local HEADER_FG="yellow"
	# Auswahlmodus & Joiner für multiple
	local SELECTION_FLAG="--selection=single" # oder: --selection=multiple
	local JOIN_FLAG="--join=,"                # bei multiple: Ausgabe-Delimiter
	local RESULT_FILE="/tmp/migcluster_result$$"

	> $RESULT_FILE
	show_screen "$CSV_FILE" "$RESULT_FILE" "$HEADERS" "$WIDTHS" "SEL" "$SOURCECOLS" "|" "--limit=1" 1 30 "N"

#	python3 ./premig_csv_tool.py \
#		"$SELECTION_FLAG" "$JOIN_FLAG" \
#		"$HEADER_FLAG" --header-fg="$HEADER_FG" --header-bg="$HEADER_BG" \
#		--result-file="$RESULT_FILE" --read-only="${READ_ONLY}" \
#		--start-at-page=$START_AT_PAGE \
#		"$CSV_FILE" "$DELIM" \
#		"$HEADERS" "$SOURCECOLS" "$WIDTHS" \
#		"$HOTKEY_COL" "$XPOS" "$YPOS" "$RETURN_COL" "$ROWS_PER_PAGE" \
#		"$NORMAL_FG" "$NORMAL_BG" "$SELECTED_FG" "$SELECTED_BG"

	# read result
	if [[ -s "$RESULT_FILE" ]]; then
		mig_cluster_num1=$(cat $RESULT_FILE | awk '{print $1}')
		mig_cluster_num=$((10#$mig_cluster_num1))
		export mig_cluster_num
		rm -f "$RESULT_FILE"
		return 0
	else
		rm -f "$RESULT_FILE"
		return 1
	fi
}

function select_migcluster_inline() {

	local posx=$1
	local posy=$2

	./fetch_cmdb_data.sh migcluster

	# --- Eingaben/Defaults ---
	local CSV_FILE="$rootDir/configfiles/migcluster.env"
	local DELIM="|"
	local plines=$(cat $CSV_FILE | wc -l)
	let plines=${plines}+2

	# Anzeige-Kopf & welche CSV-Spalten (1-basiert) in welcher Reihenfolge gezeigt werden
	local HEADERS="Cnr,Cname,Start,End"
	local SOURCECOLS="1,2,3,4"
	local WIDTHS="3,15,15,9"
	local READ_ONLY="N"
	local START_AT_PAGE="1"

	# Verhalten
	local HOTKEY_COL="1" # 1-basiert, bezieht sich auf CSV-Originalspalten
	local RETURN_COL="1" # 1-basiert: welche CSV-Spalte zurückgegeben wird
	local ROWS_PER_PAGE="$plines"
	local XPOS="$posx" # linke obere Ecke (Spalte)
	local YPOS="$posy" # linke obere Ecke (Zeile)

	# Farben (Namen: default, black, red, green, yellow, blue, magenta, cyan, white)
	local NORMAL_FG="white"
	local NORMAL_BG="default"
	local SELECTED_FG="black"
	local SELECTED_BG="white"

	# Header-Steuerung
	local HEADER_FLAG="--header=on"
	local HEADER_BG="black"
	local HEADER_FG="yellow"

	# Auswahlmodus & Joiner für multiple
	local SELECTION_FLAG="--selection=single" # oder: --selection=multiple
	local JOIN_FLAG="--join=,"                # bei multiple: Ausgabe-Delimiter
	local RESULT_FILE="/tmp/migcluster_result$$"

	# --- Aufruf ---
	# Now you can capture stdout while still seeing the UI

	python3 ./premig_csv_tool.py \
		"$SELECTION_FLAG" "$JOIN_FLAG" \
		"$HEADER_FLAG" --header-fg="$HEADER_FG" --header-bg="$HEADER_BG" \
		--result-file="$RESULT_FILE" --read-only="${READ_ONLY}" \
		--start-at-page=$START_AT_PAGE \
		"$CSV_FILE" "$DELIM" \
		"$HEADERS" "$SOURCECOLS" "$WIDTHS" \
		"$HOTKEY_COL" "$XPOS" "$YPOS" "$RETURN_COL" "$ROWS_PER_PAGE" \
		"$NORMAL_FG" "$NORMAL_BG" "$SELECTED_FG" "$SELECTED_BG"

	# read result
	if [[ -s "$RESULT_FILE" ]]; then
		mig_cluster_num2="$(<"$RESULT_FILE")"
		mig_cluster_num=$((10#$mig_cluster_num2))
		export mig_cluster_num
		rm -f "$RESULT_FILE"
		return 0
	else
		rm -f "$RESULT_FILE"
		return 1
	fi
}

function select_one_appinfo2() {

	local cluster_num="$1"
	local appl_primkey="$2"
	local read_data="$3"
	local display_only="Y"
	local start_pg="1"
	local cluster="Cluster ${cluster_num}"
	local rows_per_page=30
	local file="/tmp/appsingle$$"
	local file2="$rootDir/configfiles/appinfos2.env"

	cat $file2 | grep $appl_primkey >$file

	if [ $(cat $file | wc -l) -ne 1 ]; then
		echo "internal error findig app data; key: $appl_primkey cl: $cluster_num"
		sleep 5
		return
	fi

	if [ ! -f $file ] || [ "X$read_data" == "XY" ]; then
		./fetch_cmdb_data.sh appinfos2 $cluster_num
		local total_lines=$(cat $file | wc -l)
		let pnr=${total_lines}/$rows_per_page
		let coveredl=${pnr}*$rows_per_page
		let restl=${total_lines}-$coveredl
		if [ $restl -gt 0 ]; then
			let pnr=${pnr}+1
		fi

		local maxpg=$(((total_lines + rows_per_page - 1) / rows_per_page))
		export mig_app_max_page=$maxpg
	fi

	clear
	# --- Eingaben/Defaults ---
	local CSV_FILE="$file"
	local DELIM="|"

	# Anzeige-Kopf & welche CSV-Spalten (1-basiert) in welcher Reihenfolge gezeigt werden
	local HEADERS="Nr,Primkey,MigCl,App_Name,Env_Orig,Oracle_DB,Migration,Platform,Target_Name,DataCl,cpat,NFS_Server"
	local SOURCECOLS="1,2,3,4,5,6,7,8,9,10,11,12)"
	local WIDTHS="3,10,10,30,8,25,10,5,15,15,8,12"

	# Verhalten
	local HOTKEY_COL="1" # 1-basiert, bezieht sich auf CSV-Originalspalten
	local READ_ONLY=$display_only
	local START_AT_PAGE=$start_pg
	local RETURN_COL="1" # 1-basiert: welche CSV-Spalte zurückgegeben wird
	local ROWS_PER_PAGE=$rows_per_page
	local XPOS="8" # linke obere Ecke (Spalte)
	local YPOS="8" # linke obere Ecke (Zeile)

	# Farben (Namen: default, black, red, green, yellow, blue, magenta, cyan, white)
	local NORMAL_FG="white"
	local NORMAL_BG="default"
	local SELECTED_FG="black"
	local SELECTED_BG="white"

	# Header-Steuerung
	local HEADER_FLAG="--header=on"
	local HEADER_BG="black"
	local HEADER_FG="yellow"

	# Auswahlmodus & Joiner für multiple
	local SELECTION_FLAG="--selection=single" # oder: --selection=multiple
	local JOIN_FLAG="--join=,"                # bei multiple: Ausgabe-Delimiter
	local RESULT_FILE="/tmp/app_result$$"

	# --- Aufruf ---
	# Now you can capture stdout while still seeing the UI
	python3 ./premig_csv_tool.py \
		"$SELECTION_FLAG" "$JOIN_FLAG" \
		"$HEADER_FLAG" --header-fg="$HEADER_FG" --header-bg="$HEADER_BG" \
		--result-file="$RESULT_FILE" --read-only="${READ_ONLY}" \
		--start-at-page=$START_AT_PAGE \
		"$CSV_FILE" "$DELIM" \
		"$HEADERS" "$SOURCECOLS" "$WIDTHS" \
		"$HOTKEY_COL" "$XPOS" "$YPOS" "$RETURN_COL" "$ROWS_PER_PAGE" \
		"$NORMAL_FG" "$NORMAL_BG" "$SELECTED_FG" "$SELECTED_BG"

	rm -f $file
}

function select_cpatinfos2() {

	local cluster_num="$1"
	local display_only="$2"
	local read_data="$3"
	local start_pg="$4"
	local rows_per_page=25
	local file="$rootDir/configfiles/cpatinfos2.env"

	if [ ! -f $file ] || [ "X$read_data" == "XY" ]; then
		./fetch_cmdb_data.sh cpatinfos2 "$cluster_num" "$file"
		local total_lines=$(cat $file | wc -l)
		let pnr=${total_lines}/$rows_per_page
		let coveredl=${pnr}*$rows_per_page
		let restl=${total_lines}-$coveredl
		if [ $restl -gt 0 ]; then
			let pnr=${pnr}+1
		fi

		local maxpg=$(((total_lines + rows_per_page - 1) / rows_per_page))
		export mig_cpat_max_page=$maxpg
	fi

	#   clear

	#   gum style --foreground=$AC_RED --background=$AC_BLACK \
	#             --border rounded --margin "1 2" --padding "1 3" \
	#             --align center --width 100 --bold \
	#         "Select Databases for cpat"

	# --- Eingaben/Defaults ---
	local CSV_FILE="$file"
	local DELIM="|"

	# Anzeige-Kopf & welche CSV-Spalten (1-basiert) in welcher Reihenfolge gezeigt werden
	local HEADERS="MigCl,PKey,DB,Hip"
	local SOURCECOLS="1,4,2,3"
	local WIDTHS="10,10,25,10"

	# Verhalten
	local HOTKEY_COL="1" # 1-basiert, bezieht sich auf CSV-Originalspalten
	local READ_ONLY=$display_only
	local START_AT_PAGE=$start_pg
	local RETURN_COL="5" # 1-basiert: welche CSV-Spalte zurückgegeben wird
	local ROWS_PER_PAGE=$rows_per_page
	local XPOS="3" # linke obere Ecke (Spalte)
	local YPOS="8" # linke obere Ecke (Zeile)

	# Farben (Namen: default, black, red, green, yellow, blue, magenta, cyan, white)
	local NORMAL_FG="white"
	local NORMAL_BG="default"
	local SELECTED_FG="black"
	local SELECTED_BG="white"

	# Header-Steuerung
	local HEADER_FLAG="--header=on"
	local HEADER_BG="black"
	local HEADER_FG="yellow"

	# Auswahlmodus & Joiner für multiple
	local SELECTION_FLAG="--selection=multiple" # oder: --selection=multiple
	local JOIN_FLAG="--join=,"                  # bei multiple: Ausgabe-Delimiter
	local RESULT_FILE="/tmp/app_result$$"

	# --- Aufruf ---
	# Now you can capture stdout while still seeing the UI
	python3 ./premig_csv_tool.py \
		"$SELECTION_FLAG" "$JOIN_FLAG" \
		"$HEADER_FLAG" --header-fg="$HEADER_FG" --header-bg="$HEADER_BG" \
		--result-file="$RESULT_FILE" --read-only="${READ_ONLY}" \
		--start-at-page=$START_AT_PAGE \
		"$CSV_FILE" "$DELIM" \
		"$HEADERS" "$SOURCECOLS" "$WIDTHS" \
		"$HOTKEY_COL" "$XPOS" "$YPOS" "$RETURN_COL" "$ROWS_PER_PAGE" \
		"$NORMAL_FG" "$NORMAL_BG" "$SELECTED_FG" "$SELECTED_BG"

	# read result
	if [[ -s "$RESULT_FILE" ]]; then
		export mig_cpat_dbnrs
		mig_cpat_dbnrs="$(<"$RESULT_FILE")"
		rm -f "$RESULT_FILE"
		return 0
	else
		rm -f "$RESULT_FILE"
		return 1
	fi
}

function select_adbinfo() {

	local display_only="$1"
	local read_data="$2"
	local start_pg="$3"
	local select_multi="$4"
	local input_file="$5"
	local output_file="$6"
	local max_rows_per_page=30
	local rows_per_page=$max_rows_per_page

	if [ ! -f $input_file ]; then
		if [ ! -f $input_file ] || [ "X$read_data" == "XY" ]; then
			./fetch_cmdb_data.sh adbinfos $input_file
		fi
	fi
	local CSV_FILE="$input_file"

	local total_lines=$(wc -l <$CSV_FILE)

	if [ $total_lines -lt $max_rows_per_page ]; then

		maxpg=1
		rows_per_page=$total_lines
		let rows_per_page=${rows_per_page}+1
		start_pg=1

	else

		let pnr=${total_lines}/$rows_per_page
		let coveredl=${pnr}*$rows_per_page
		let restl=${total_lines}-$coveredl
		if [ $restl -gt 0 ]; then
			let pnr=${pnr}+1
		fi
		local maxpg=$(((total_lines + rows_per_page - 1) / rows_per_page))
	fi
	export mig_app_max_page=$maxpg

	local DELIM="|"

	local HEADERS="Nr,Pk,Name,Application,Env,OnPremDB"
	local SOURCECOLS="1,2,3,4,5,6"
	local WIDTHS="4,7,15,25,12,30"

	local READ_ONLY=$display_only
	local START_AT_PAGE=$start_pg
	local RETURN_COL="1" # 1-basiert: welche CSV-Spalte zurückgegeben wird
	local ROWS_PER_PAGE=$rows_per_page
	local XPOS="5" # linke obere Ecke (Spalte)
	local YPOS="8" # linke obere Ecke (Zeile)

	local NORMAL_FG="white"
	local NORMAL_BG="black"

	local CURSOR_FG="gray"
	local CURSOR_BG=$NORMAL_BG

	DO="DO"
	if [ "$display_only" == "N" ]; then
		local DO="SEL"
		local XPOS="0" # linke obere Ecke (Spalte)
		local YPOS="8" # linke obere Ecke (Zeile)
		local CURSOR_FG="black"
		local CURSOR_BG="white"
	fi

	local SELECTED_FG="black"
	local SELECTED_BG="magenta"

	# Header-Steuerung
	local HEADER_FLAG="--header=on"
	local HEADER_BG="black"
	local HEADER_FG="yellow"

	# Auswahlmodus & Joiner für multiple

	local SELECTION_FLAG="--selection=multiple" # oder: --selection=multiple
	local LIMIT="--no-limit"
	if [ "$select_multi" == "N" ]; then
		local LIMIT="--limit=1"
		local SELECTION_FLAG="--selection=single" # oder: --selection=multiple
	fi
	local JOIN_FLAG="--join=|" # bei multiple: Ausgabe-Delimiter
	local RESULT_FILE="$output_file"

	>$RESULT_FILE
	show_screen "$CSV_FILE" "$RESULT_FILE" "$HEADERS" "$WIDTHS" "$DO" "$SOURCECOLS" "|" "$LIMIT" $start_pg $rows_per_page "N"
}

function select_appinfo2() {

	local cluster_num="$1"
	local display_only="$2"
	local read_data="$3"
	local start_pg="$4"
	local select_multi="$5"
	local input_file="$6"
	local output_file="$7"
	local cluster="Cluster ${cluster_num}"
	local max_rows_per_page=30
	local rows_per_page=$max_rows_per_page
	local file="$rootDir/configfiles/appinfos2.env"

	if [ -f $input_file ]; then

		local CSV_FILE="$input_file"
	else
		if [ ! -f $file ] || [ "X$read_data" == "XY" ]; then
			./fetch_cmdb_data.sh appinfos2 $cluster_num
		fi
		local CSV_FILE="$file"
	fi

	local total_lines=$(wc -l <$CSV_FILE)

	if [ $total_lines -lt $max_rows_per_page ]; then

		maxpg=1
		rows_per_page=$total_lines
		let rows_per_page=${rows_per_page}+1
		start_pg=1

	else

		let pnr=${total_lines}/$rows_per_page
		let coveredl=${pnr}*$rows_per_page
		let restl=${total_lines}-$coveredl
		if [ $restl -gt 0 ]; then
			let pnr=${pnr}+1
		fi
		local maxpg=$(((total_lines + rows_per_page - 1) / rows_per_page))
	fi
	export mig_app_max_page=$maxpg

	local DELIM="|"

	local HEADERS="Nr,MCl,App_Name,Env,Oracle_DB,Migration,Platform,Target_Name,DCl,cpa,Nfs"
	local SOURCECOLS="1,2,4,5,6,7,8,9,10,11,12"
	local WIDTHS="3,3,22,5,23,8,6,22,4,9,15"

	local READ_ONLY=$display_only
	local START_AT_PAGE=$start_pg
	local RETURN_COL="1" # 1-basiert: welche CSV-Spalte zurückgegeben wird
	local ROWS_PER_PAGE=$rows_per_page
	local XPOS="5" # linke obere Ecke (Spalte)
	local YPOS="8" # linke obere Ecke (Zeile)

	local NORMAL_FG="white"
	local NORMAL_BG="black"

	local CURSOR_FG="gray"
	local CURSOR_BG=$NORMAL_BG

	DO="DO"
	if [ "$display_only" == "N" ]; then
		local DO="SEL"
		local XPOS="5" # linke obere Ecke (Spalte)
		local YPOS="8" # linke obere Ecke (Zeile)
		local CURSOR_FG="black"
		local CURSOR_BG="white"
	fi

	local SELECTED_FG="black"
	local SELECTED_BG="magenta"

	# Header-Steuerung
	local HEADER_FLAG="--header=on"
	local HEADER_BG="black"
	local HEADER_FG="yellow"

	# Auswahlmodus & Joiner für multiple

	local SELECTION_FLAG="--selection=multiple" # oder: --selection=multipleA
	local LIMIT="--no-limit"
	if [ "$select_multi" == "N" ]; then
		local LIMIT="--limit=1"
		local SELECTION_FLAG="--selection=single" # oder: --selection=multiple
	fi
	local JOIN_FLAG="--join=|" # bei multiple: Ausgabe-Delimiter
	local RESULT_FILE="$output_file"

	show_screen "$CSV_FILE" "$output_file" "$HEADERS" "$WIDTHS" "$DO" "$SOURCECOLS" "|" "$LIMIT" $start_pg $rows_per_page "Y"

}

function select_testcases() {
	local RESULT_FILE="$1"

	local output_file="$1"
	local CSV_FILE="$rootDir/configfiles/testcases.csv"

	$rootDir/scripts/fetch_cmdb_data.sh testcases >/dev/null

	local DELIM=":"

	# --- Eingaben/Defaults ---
	local plines=$(cat $CSV_FILE | wc -l)
	let plines=${plines}+2

	# Anzeige-Kopf & welche CSV-Spalten (1-basiert) in welcher Reihenfolge gezeigt werden
	local HEADERS="Nr,Code,Text,loff,lon,poff,pon"
	local SOURCECOLS="1,2,3,4,5,6,7"
	local WIDTHS="3,15,39,4,4,4,4"
	local READ_ONLY="N"
	local START_AT_PAGE="1"

	# Verhalten
	local HOTKEY_COL="1" # 1-basiert, bezieht sich auf CSV-Originalspalten
	local RETURN_COL="1" # 1-basiert: welche CSV-Spalte zurückgegeben wird
	local ROWS_PER_PAGE="$plines"
	local XPOS="10" # linke obere Ecke (Spalte)
	local YPOS="8"  # linke obere Ecke (Zeile)

	# Farben (Namen: default, black, red, green, yellow, blue, magenta, cyan, white)
	# Farben (Namen: default, black, red, green, yellow, blue, magenta, cyan, white)
	local NORMAL_FG="white"
	local NORMAL_BG="black"

	local CURSOR_FG="black"
	local CURSOR_BG="white"

	local SELECTED_FG="black"
	local SELECTED_BG="magenta"

	# Header-Steuerung
	local HEADER_FLAG="--header=on"
	local HEADER_BG="black"
	local HEADER_FG="yellow"

	# Auswahlmodus & Joiner für multiple
	local SELECTION_FLAG="--selection=multiple" #der: --selection=multiple
	local JOIN_FLAG="--join=,"                  # bei multiple: Ausgabe-Delimiter

	sed -i 's/:/,/g' "$CSV_FILE"
	show_screen "$CSV_FILE" "$output_file" "$HEADERS" "$WIDTHS" "SEL" "$SOURCECOLS" "," "--no-limit" 1 30 "Y"
	cat $output_file
}

function select_cpatfiles() {
	local CSV_FILE="$1"
	local RESULT_FILE="$2"

	local output_file="$2"

	local DELIM="|"

	# --- Eingaben/Defaults ---
	local plines=$(cat $CSV_FILE | wc -l)
	let plines=${plines}+2

	# Anzeige-Kopf & welche CSV-Spalten (1-basiert) in welcher Reihenfolge gezeigt werden
	local HEADERS="Tag,Jahr,File"
	local SOURCECOLS="1,2,3"
	local WIDTHS="7,7,80"
	local READ_ONLY="N"
	local START_AT_PAGE="1"

	# Verhalten
	local HOTKEY_COL="1" # 1-basiert, bezieht sich auf CSV-Originalspalten
	local RETURN_COL="1" # 1-basiert: welche CSV-Spalte zurückgegeben wird
	local ROWS_PER_PAGE="$plines"
	local XPOS="5" # linke obere Ecke (Spalte)
	local YPOS="8" # linke obere Ecke (Zeile)

	# Farben (Namen: default, black, red, green, yellow, blue, magenta, cyan, white)
	# Farben (Namen: default, black, red, green, yellow, blue, magenta, cyan, white)
	local NORMAL_FG="white"
	local NORMAL_BG="black"

	local CURSOR_FG="black"
	local CURSOR_BG="white"

	local SELECTED_FG="black"
	local SELECTED_BG="magenta"

	# Header-Steuerung
	local HEADER_FLAG="--header=on"
	local HEADER_BG="black"
	local HEADER_FG="yellow"

	# Auswahlmodus & Joiner für multiple
	local SELECTION_FLAG="--selection=multiple" #der: --selection=multiple
	local JOIN_FLAG="--join=,"                  # bei multiple: Ausgabe-Delimiter
 
	show_screen "$CSV_FILE" "$RESULT_FILE" "$HEADERS" "$WIDTHS" "SEL" "$SOURCECOLS" "|" "--no-limit" 1 30 "N"

}

#    show one cluster, pick a row with gum, then keep something visible
function show_app_style() {

	# nice title
	gum style --foreground="$AC_RED" --background="$AC_BLACK" \
		--border rounded --margin "1 2" --padding "1 3" \
		--align center --width 170 --bold \
		"Select a Modernex Application (${cluster})"

}

# show one cluster, pick a row with gum, then keep something visible
function show_app_select() {
	local cluster_num="$1"
	local cluster="Cluster ${cluster_num}"
	local file="$2"
	local return_line=""

	# --- Eingaben/Defaults ---
	local CSV_FILE="$rootDir/configfiles/migcluster.env"
	local DELIM="|"
	local plines=$(cat $CSV_FILE | wc -l)
	let plines=${plines}+2

	# Anzeige-Kopf & welche CSV-Spalten (1-basiert) in welcher Reihenfolge gezeigt werden
	local HEADERS="Cnr,Cname,Start,End"
	local SOURCECOLS="1,2,3,4"
	local WIDTHS="3,15,15,15"

	# Verhalten
	local HOTKEY_COL="1" # 1-basiert, bezieht sich auf CSV-Originalspalten
	local RETURN_COL="1" # 1-basiert: welche CSV-Spalte zurückgegeben wird
	local ROWS_PER_PAGE="$plines"
	local XPOS="20" # linke obere Ecke (Spalte)
	local YPOS="20" # linke obere Ecke (Zeile)

	# Farben (Namen: default, black, red, green, yellow, blue, magenta, cyan, white)
	local NORMAL_FG="white"
	local NORMAL_BG="default"
	local SELECTED_FG="black"
	local SELECTED_BG="blue"

	# Header-Steuerung
	local HEADER_FLAG="--header=on"
	local HEADER_FG="yellow"
	local HEADER_BG="black"

	# Auswahlmodus & Joiner für multiple
	local SELECTION_FLAG="--selection=single" # oder: --selection=multiple
	local JOIN_FLAG="--join=,"                # bei multiple: Ausgabe-Delimiter
	local RESULT_FILE="/tmp/migcluster_result$$"

	# --- Aufruf ---
	# Now you can capture stdout while still seeing the UI
	python3 ./premig_csv_tool.py \
		"$SELECTION_FLAG" "$JOIN_FLAG" \
		"$HEADER_FLAG" --header-fg="$HEADER_FG" --header-bg="$HEADER_BG" \
		--result-file="$RESULT_FILE" \
		"$CSV_FILE" "$DELIM" \
		"$HEADERS" "$SOURCECOLS" "$WIDTHS" \
		"$HOTKEY_COL" "$XPOS" "$YPOS" "$RETURN_COL" "$ROWS_PER_PAGE" \
		"$NORMAL_FG" "$NORMAL_BG" "$SELECTED_FG" "$SELECTED_BG"

	# read result
	if [[ -s "$RESULT_FILE" ]]; then
		export mig_cluster_num
		mig_cluster_num="$(<"$RESULT_FILE")"
		rm -f "$RESULT_FILE"
		echo "selected: $mig_cluster_num"
		return 0
	else
		rm -f "$RESULT_FILE"
		return 1
	fi

	# INTERACTIVE TABLE (this will clear on exit — that's fine)
	selected_line_nr="$(
		gum table -s "|" --height=30 \
			--columns="Nr","MigCl","App_Name","Env_Orig","Oracle_DB","Migration","Platform","Target_Name","cpat","NFS_Server" \
			--return-column=1 \
			--selected.foreground="${sfg}" \
			--selected.background="${sbg}" \
			--header.foreground="${hfg}" \
			--header.background="${hbg}" \
			--timeout=0s \
			--file="$file"
	)" || return 1

}

function hmenu() {

	local menubar="$1"

	printf "\e[?25l"; printf "\r\n"
	
	# Call your standalone Python (no curses, no clear)
	sel=$(python3 ./premig_horizontal_menu.py "$menubar")
	export input=$(echo "$sel" | tr -d " ")
	printf "\e[?25h"
}

create_tmux_server() {
	local user_name="$1"
	local ws_number="$2"
	export TMUX_SOCKNAME="tmux_${user_name}_${ws_number}"

	# Only start if not already running
	if ! tmux -L "$TMUX_SOCKNAME" has-session 2>/dev/null; then
		echo "Starting tmux server: $TMUX_SOCKNAME"
		tmux -L "$TMUX_SOCKNAME" kill-server 2>/dev/null || true
		tmux -L "$TMUX_SOCKNAME" has-session -t keepalive 2>/dev/null ||
			tmux -L "$TMUX_SOCKNAME" new-session -d -s keepalive -n shell
		tmux -L "$TMUX_SOCKNAME" attach -t keepalive

		#tmux -L "$ddTMUX_SOCKNAME" new-session -d -s keepalive -n shell

	fi
}

shutdown_tmux_server() {
	local user_name="$1"
	local ws_number="$2"
	local sock_name="tmux_${user_name}_${ws_number}"

	echo "Stopping tmux server: $sock_name"
	tmux -L "$sock_name" kill-server 2>/dev/null || true
}

function format_csv_for_choose() {

	local file_to_format="$1"
	local ouput_file="$2"
	local delimiter="$3"

	if [ "X$delimiter" == "X" ]; then
		delimiter="|"
	fi

	gum table -s "$delimiter" -p <$file_to_format >$rootDir/tmp/fmt1.$$
	sed '1d;3d;$d;s/│//g' $rootDir/tmp/fmt1.$$ >$rootDir/tmp/fmt2.$$
	sed -r 's/\x1B\[[0-9;]*[A-Za-z]//g' $rootDir/tmp/fmt2.$$ >$ouput_file
	rm -f $rootDir/tmp/fmt1.$$ $rootDir/tmp/fmt2.$$

}

replace_ascii_table_row() {
	local table_file="$1"
	local csv_file="$2"
	local py_script="$rootDir/scripts/premig_replace_row.py"

	# 🔧 Standardwerte
	cp $table_file "ascii_table.txt"
	cp $csv_file "values.csv"
	# Dateien

	python3 "$py_script" "$table_file" "$csv_file" &>/dev/null

	cp "ascii_table.txt" $table_file
	return $?
}

function gchoose() {

	local file_to_format="$1"
	local ouput_file="$2"
	local delimiter="$3"
	local sel_mode="$4"
	local hdrfile="${file_to_format}.hdr"
	local PF_YELLOW=$'\033[0;33m' # gelb für EX
	local PF_NC=$'\033[0m'        # zurücksetzen

	if [ ! -f $hdrfile ]; then
		echo "k1,k2,k3,k4,k5,k,k,k8,k9,k10" >$hdrfile
	fi

	local glimit="--limit=1"
	if [ "$sel_mode" == "multi" ]; then
		glimit="--no-limit"
	fi

	gum table -s "$delimiter" -p <$file_to_format >$rootDir/tmp/fmt1.$$

	# format header
	awk 'NR <= 3' $rootDir/tmp/fmt1.$$ | sed 's/^/  /g' >$rootDir/tmp/fmtH.$$
	replace_ascii_table_row "$rootDir/tmp/fmtH.$$" "$hdrfile"
	awk 'NR == 2' $rootDir/tmp/fmtH.$$ | sed 's/│//g' >$rootDir/tmp/fmtH2.$$

	#body
	sed '1d;3d;$d;s/│//g' $rootDir/tmp/fmt1.$$ >$rootDir/tmp/fmt2.$$
	sed -r 's/\x1B\[[0-9;]*[A-Za-z]//g' $rootDir/tmp/fmt2.$$ >$rootDir/tmp/fmt1.$$
	echo "--- Select $glimit --->" >$rootDir/tmp/fmt2.$$
	cat $rootDir/tmp/fmt1.$$ >>$rootDir/tmp/fmt2.$$

	#print header
	printf "%s" "$PF_YELLOW"
	cat $rootDir/tmp/fmtH2.$$
	printf "%s" "$PF_NC"

	cat $rootDir/tmp/fmt2.$$ | gum filter $glimit --height=25 \
		--indicator="" \
		--selected="XXX" \
		--show-help \
		--selected-prefix=">>>" \
		--unselected-prefix="   " \
		--header="" \
		--placeholder="Filter..." \
		--prompt="> " \
		--width=0 \
		--value="" \
		--reverse=false \
		--fuzzy=true \
		--fuzzy-sort=true \
		--timeout=0s \
		--input-delimiter=$'\n' \
		--output-delimiter=$'\n' \
		--strip-ansi=true \
		\
		--indicator.foreground="212" \
		--indicator.background="" \
		--selected-indicator.foreground="0" \
		--selected-indicator.background="212" \
		--unselected-prefix.foreground="240" \
		--unselected-prefix.background="" \
		--header.foreground="99" \
		--header.background="" \
		--text.foreground="" \
		--text.background="" \
		--cursor-text.foreground="0" \
		--cursor-text.background="245" \
		--match.foreground="212" \
		--match.background="" \
		--prompt.foreground="240" \
		--prompt.background="" \
		--placeholder.foreground="240" \
		--placeholder.background="" \
		\
		--strict=true \
		--select-if-one=false >$rootDir/tmp/fmt1.$$

	cat $rootDir/tmp/fmt1.$$ | grep -v "\-\-\- Select " >$ouput_file

	#cat $rootDir/tmp/fmt1.$$ | sed "s/⠠/ /g" > $ouput_file

	rm -f $rootDir/tmp/fmt1.$$ $rootDir/tmp/fmt2.$$ $rootDir/tmp/fmtH.$$ $rootDir/tmp/fmtH2.$$

}


parse_columns() {
    local line="$1"

    read -r SOURCECOLS WIDTHS < <(
        python3 <<EOF
line = '''$line'''.strip('│')
parts = [p.strip() for p in line.split('│')]
widths = [len(p) for p in parts]
sourcecols = ",".join(str(i + 1) for i in range(len(parts)))
widths_str = ",".join(str(w) for w in widths)
print(f"{sourcecols} {widths_str}")
EOF
    )
}




function gchoose_simple() {

	local file_to_format="$1"
	local ouput_file="$2"
	local delimiter="$3"
	local sel_mode="$4"
	local hdrfile="${file_to_format}.hdr"
	local PF_YELLOW=$'\033[0;33m' # gelb für EX
	local PF_NC=$'\033[0m'        # zurücksetzen

	if [ ! -f $hdrfile ]; then
		echo "k1,k2,k3,k4,k5,k,k,k8,k9,k10" >$hdrfile
	fi

	local glimit="--limit=1"
	if [ "$sel_mode" == "multi" ]; then
		glimit="--no-limit"
	fi


	gum table -s "$delimiter" -p <$file_to_format >$rootDir/tmp/fmt1.$$
	
 	HEADERS=$(cat $hdrfile | head -1)
 	tline=$(awk 'NR == 2' $rootDir/tmp/fmt1.$$)
         parse_columns "$tline"

 	show_screen "$file_to_format" "$ouput_file" "$HEADERS" "$WIDTHS" "sel" "$SOURCECOLS" "$delimiter" "$glimit" 1 25 "N"
  	return


	# format header
	awk 'NR <= 3' $rootDir/tmp/fmt1.$$ | sed 's/^/  /g' >$rootDir/tmp/fmtH.$$
	replace_ascii_table_row "$rootDir/tmp/fmtH.$$" "$hdrfile"
	awk 'NR == 2' $rootDir/tmp/fmtH.$$ | sed 's/│//g' >$rootDir/tmp/fmtH2.$$

	#body
	sed '1d;3d;$d;s/│//g' $rootDir/tmp/fmt1.$$ >$rootDir/tmp/fmt2.$$
	sed -r 's/\x1B\[[0-9;]*[A-Za-z]//g' $rootDir/tmp/fmt2.$$ >$rootDir/tmp/fmt1.$$
	echo "--- Select $glimit --->" >$rootDir/tmp/fmt2.$$
	cat $rootDir/tmp/fmt1.$$ >>$rootDir/tmp/fmt2.$$

	#print header
	printf "%s" "$PF_YELLOW"
	cat $rootDir/tmp/fmtH2.$$
	printf "%s" "$PF_NC"

	cat $rootDir/tmp/fmt2.$$ | gum choose --no-limit --cursor="" \
		--cursor-prefix="  " \
		--selected.background=252 \
		--height=25 \
		$glimit \
		--selected.foreground=0 \
		--cursor.background=212 \
		--cursor.foreground=0 >$rootDir/tmp/fmt1.$$

	cat $rootDir/tmp/fmt1.$$ | grep -v "\-\-\- Select " >$ouput_file

	#cat $rootDir/tmp/fmt1.$$ | sed "s/⠠/ /g" > $ouput_file

	rm -f $rootDir/tmp/fmt1.$$ $rootDir/tmp/fmt2.$$ $rootDir/tmp/fmtH.$$ $rootDir/tmp/fmtH2.$$

}

function printh() {

	csv_file="$1"
	delimiter="$2"
	column_num="$3"
	values_per_line="$4"

	# Validate inputs
	if [[ -z "$csv_file" || -z "$delimiter" || -z "$column_num" || -z "$values_per_line" ]]; then
		echo "Usage: $0 <csv_file> <delimiter> <column_number> <values_per_line>"
		exit 1
	fi

	# Read target column values from the CSV
	values=()
	while IFS="$delimiter" read -r -a fields; do
		value="${fields[$((column_num - 1))]}"
		values+=("$value")
	done <"$csv_file"

	# Find the maximum value length (with numbering prefix)
	max_len=0
	sp=".."
	for i in "${!values[@]}"; do
		if ((${#numbered} > 9)); then
			sp="."
		fi
		numbered="$((i + 1)).${sp}${values[$i]}"
		if ((${#numbered} > max_len)); then
			max_len=${#numbered}
		fi
	done

	# Output formatted values
	for i in "${!values[@]}"; do
		index=$((i + 1))
		printf "%-${max_len}s  " "$index.${values[$i]}"
		if (((index) % values_per_line == 0)); then
			echo
		fi
	done

	# Final newline if needed
	if ((${#values[@]} % values_per_line != 0)); then
		echo
	fi
}

function show_screen() {

	local infile=$1
	local resultf=$2
	local hdrs=$3
	local colwidth=$4
	local selmode=$5
	local srccol=$6
	local delimiter=$7
	local glimit="$8"
	local pagenr=$9
	local lines_per_page=${10}
	local return_csv=${11}

	local anz_columns=$(($(grep -o "," <<<"$srccol" | wc -l)))
	local anz_colwidth=$(($(grep -o "," <<<"$colwidth" | wc -l)))
	local anz_hdrs=$(($(grep -o "," <<<"$hdrs" | wc -l)))
	local line_start=$((pagenr * lines_per_page))
	local line_start=$((line_start - lines_per_page + 1))
	local line_end=$((line_start + lines_per_page - 1))

	if [ "$selmode" != "DO" ]; then
                line_start=1
		pagenr=1
		line_end=$(wc -l < $infile)
        fi


	if [[ "$anz_hdrs" -eq "$anz_colwidth" ]]; then
		echo "OK" >/dev/null
	else
		echo "utils_gum internal error: gum001"
		return
	fi

	IFS=',' read -ra hdr_ar <<<"$hdrs"
	IFS=',' read -ra srccol_ar <<<"$srccol"
	IFS=',' read -ra colwidth_ar <<<"$colwidth"
	IFS=',' read -ra colfmt_ar <<<"$colfmt"

	fmtdesc=""
	fmthdr="%-2s"
	hdrline="\"   \""
	hdrline2=""
	for ((i = 0; i <= anz_columns; i++)); do
		nextel=${hdr_ar[$i]}
		nextln=${colwidth_ar[$i]}
		fmtdesc=$(echo "${fmtdesc}%-${nextln}s ")
		fmthdr=$(echo "${fmthdr}%-${nextln}s ")
		hdrline=$(echo "${hdrline} \"${nextel:0:${nextln}}\" ")

		hdrel2=$(printf '%*s' "$nextln" '' | tr ' ' '-')
		hdrline2=$(echo "${hdrline2}$hdrel2 ")

	done

	cmd="printf \"${fmthdr}\n\" $hdrline"
	eval $cmd
	echo "  $hdrline2"

	local tmpdisp=$rootDir/tmp/disp_$gpid
	local tmpout=$rootDir/tmp/out_$gpid

	srcline=""
	>$tmpdisp
	cnt=0
	while IFS= read -r srcline || [[ -n $srcline ]]; do
		let cnt=${cnt}+1

		if ((cnt >= line_start && cnt <= line_end)); then

			displine=""
			for ((i = 0; i <= anz_columns; i++)); do
				nextel=$(echo $srcline | cut -d "$delimiter" -f ${srccol_ar[$i]})
				nextln=${colwidth_ar[$i]}
				displine=$(echo "${displine} \"${nextel:0:${nextln}}\" ")
			done
			cmd="printf \"${fmtdesc}\n\" $displine"
			eval $cmd >>$tmpdisp
		fi
	done <"$infile"

	if [ "$selmode" == "DO" ]; then
		sed -i 's/^/  /' $tmpdisp
		cat $tmpdisp
	else
		while true; do

			bg_curcol=202
			fg_curcol=0
			if [ "$glimit" = "--limit=1" ]; then
				bg_curcol=202
				fg_curcol=0
		                sed -i 's/^/➤ /' $tmpdisp
			fi
			>$tmpout
			cat $tmpdisp | gum choose --cursor="" \
				--cursor-prefix="  " \
				--selected.background=252 \
				--height=25 \
			        $glimit \
				--selected.foreground=0 \
				--cursor.background=$bg_curcol \
				--cursor.foreground=$fg_curcol >$tmpout

			if [ "$glimit" = "--limit=1" ]; then
		                sed -i 's/^➤ //' $tmpout
			fi
			if [ "$glimit" = "--limit=1" ] && [ $(wc -l < $tmpout  ) -gt 1 ] && [ "$selmode" != "DO" ]; then
				echo "Please select only one line"
				sleep 3
				clear
				mhead "Select again"
			else
				break
			fi

		done

		>$resultf
		if [ "$return_csv" == "Y" ]; then
      		    for selnr in $(cat $tmpout | awk '{print $1}'); do
	#		awk "NR == $selnr" $infile >>$resultf
			cat $infile | grep "^${selnr}${delimiter}" >>$resultf
		    done
	       else
		    cat $tmpout| sed 's/^ //' > $resultf
	       fi
	fi

}

#show_screen "../configfiles/migcluster.env" "./x"  "Nr,ClNr,start,end,anzapp" "3,15,15,15,5" "DO" "1,2,3,4,5" "|" "--no-limit
#select_adbinfo N Y 1 N /home/mig/9654180/premigration/tmp/adbinfo.1926816 /home/mig/9654180/premigration/tmp/adbinfo_sel.1926816


#select_appinfo2 3 N N 1 Y /home/mig/9654180/premigration/tmp/selcpat1.2269893 /home/mig/9654180/premigration/tmp/selcpat2.2269893
