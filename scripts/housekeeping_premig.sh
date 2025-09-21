#!/bin/bash

if [ ! -f ../premigration.env ]; then
	echo "wrong startdir!"
	exit 1
fi

source ../premigration.env cloud

# generate file

cat << EOF >/tmp/${current_user}_checkdirs.txt
${rootDir}/tmp
${rootDir}/dialog
${rootDir}/cpat
${rootDir}/results
${rootDir}/mailbox/sent
${rootDir}/configfiles/tmp
${rootDir}/configfiles/tufin
EOF


set -euo pipefail

LIST_FILE="/tmp/${current_user}_checkdirs.txt"
DAYS="7"
DATE=$(date +%F)
LOGFILE="/tmp/housekeeping_${current_user}_${DATE}.log"
DELETE_SCRIPT="/tmp/${current_user}_files_to_delete.sh"

if [[ ! -f "$LIST_FILE" ]]; then
  echo "Error: File '$LIST_FILE' not found."
  exit 2
fi

if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  echo "Error: Second parameter must be a number (days to keep)"
  exit 3
fi

echo "#!/bin/bash" > "$DELETE_SCRIPT"
chmod +x "$DELETE_SCRIPT"

echo "### Housekeeping simulation on $DATE (files older than $DAYS days)" > "$LOGFILE"
echo "Generating delete script: $DELETE_SCRIPT" >> "$LOGFILE"
echo "Logfile: $LOGFILE" >> "$LOGFILE"
echo >> "$LOGFILE"

while IFS= read -r DIR || [[ -n "$DIR" ]]; do
  
  cnt=0
  dcnt=0
  lc=0
  printf "%-10s %-55s %-25s %-15s" "working on" "$DIR" "found files $cnt" "dirs $dcnt"

  [[ -z "$DIR" ]] && continue
  if [[ ! -d "$DIR" ]]; then
    echo "[$(date +%T)] WARNING: '$DIR' is not a valid directory." >> "$LOGFILE"
    continue
  fi

  echo "[$(date +%T)] Scanning directory: $DIR" >> "$LOGFILE"

  # Dateien zum Löschen sammeln
  while IFS= read -r FILE; do

    let cnt=${cnt}+1
    let lc=${lc}+1

    if [ $lc -gt 99 ]; then
	    lc=0
            printf "\r%-10s %-55s %-25s %-15s" "working on" "$DIR" "found files $cnt" "dirs $dcnt"
    fi

    echo "rm -f \"$FILE\"" >> "$DELETE_SCRIPT"
    echo "  FILE: $FILE" >> "$LOGFILE"
  done < <(find "$DIR" -type f -mtime +"$DAYS")

  lc=0
  # Leere Verzeichnisse sammeln
  while IFS= read -r EMPTYDIR; do
    let dcnt=${dcnt}+1
    let lc=${lc}+1

    if [ $lc -gt 99 ]; then
	    lc=0
            printf "\r%-10s %-55s %-25s %-15s" "working on" "$DIR" "found files $cnt" "dirs $dcnt"
    fi

    echo "rm -f \"$FILE\"" >> "$DELETE_SCRIPT"
    echo "rmdir \"$EMPTYDIR\"" >> "$DELETE_SCRIPT"
    echo "  EMPTY DIR: $EMPTYDIR" >> "$LOGFILE"
  done < <(find "$DIR" -type d -empty  -mtime +"$DAYS")

  printf "\r%-10s %-55s %-25s %-15s" "working on" "$DIR" "found files $cnt" "dirs $dcnt"
  printf "\n"

done < "$LIST_FILE"

echo >> "$LOGFILE"
echo "### Script generated at: $(date +%T)" >> "$LOGFILE"
echo "Run the script manually: $DELETE_SCRIPT"

