# Funktion in eine Datei (z.B. pes_send_zip.lib) legen und per:
# source ./pes_send_zip.lib
# verwenden. Aufruf:
# pes_send_zip "/pfad/zum/verzeichnis" "empfaenger@example.com"

#--------------------------------------------------------------------------------------------
function send_cpatmail() {
    local to="$1"
    local subject="$2"
    local body="$3"
    local attachment="$4"

    sudo touch /tmp/sm.log
    sudo rm /tmp/sm.log

    {
    set -x
    if [[ -z "$to" || -z "$subject" || -z "$body" ]]; then
        return 1
    fi

    if [[ ! -f "$body" ]]; then
        bodymessage="echo \"$body\""
    else
        bodymessage="cat $body"
    fi

    att=""
    if [[ ! -z "$attachment" ]]; then
        for af in $attachment
        do
           if [ -f $af ]; then
                att="$att -a \"$af\""
           fi
        done
    fi

    echo "set smtp=smtp://smtpout.basf.net:25" >$HOME/.mailrc
    echo "set from=\"premig@basf.com\"" >>$HOME/.mailrc

    mcmd="$bodymessage | mailx -s \"$subject\" $att \"$to\""
    eval $mcmd
    #{echo "Please find the attached file." | mailx -s "$subject" -a "$attachment" "$to"
    set +x
    } &>/tmp/sm.log
}





cpat_send_zip() {

  # --- Parameter ---
  local DIR="${1:-}"
  local TO="${2:-}"

  # --- leichte Prüfungen der Eingaben ---
  if [[ -z "$DIR" || -z "$TO" ]]; then
    echo "Usage: pes_send_zip <directory> <email>" >&2
    return 2
  fi
  if [[ ! -d "$DIR" ]]; then
	echo "No cpats availabel for Cluster $run_cluster " >&2
	sleep 3
    return 
  fi

  cd $DIR
  ls -lt *.html | awk '{print  $7"."$6"|"$8"|"$9}' > $rootDir/tmp/cpats.$$ 
  ls -lt *.txt | awk '{print  $7"."$6"|"$8"|"$9}' >> $rootDir/tmp/cpats.$$ 
  cd $rootDir/scripts

  
  while true
  do
  clear; mhead 
  select_cpatfiles  $rootDir/tmp/cpats.$$ $rootDir/tmp/cpats_sel.$$

      if [ -s $rootDir/tmp/cpats_sel.$$ ]; then
	      break
      else
	      echo "No selection made,,,"
	      askDau "[q]QuitAndReturn,[s]NewSellect"
	      if [ "$dauResponse" == "QuitAndReturn" ]; then
		      break
	      fi
      fi
  done

  cat $rootDir/tmp/cpats_sel.$$

  echo
  gum confirm  $confirm_params "Do you want to send those files?" || return


  jobnr=$(date +"%Y%m%d-%H%M%S")


  if [ "X$mail_to" != "X" ]; then

	  mkdir -p $rootDir/mailbox/tosend/${jobnr}
						
          for cpatfile in $(cat $rootDir/tmp/cpats_sel.$$  | awk '{print $3}'); do
		  echo "adding $cpatfile"
		  cp $rootDir/cpat/results/cluster_${run_cluster}/${cpatfile}  $rootDir/mailbox/tosend/${jobnr}
          done		  


                 cd ${rootDir}/mailbox/tosend
                    zip -r cpat_results_${jobnr}.zip ./${jobnr} &>/dev/null
                    if [ $? -eq 0 ]; then

                       cd ${rootDir}/mailbox/tosend/${jobnr}
                       {
                         echo -e " "
                         echo -e "Hello,"
                         echo -e "find attached the selected cpat files"
                         echo -e " "
                         echo -e "BR Premig Test Suite"
                        } > ${rootDir}/mailbox/tosend/${jobnr}/bodyfile


                        mv ${rootDir}/mailbox/tosend/${jobnr} ${rootDir}/mailbox/sent
                        mv ${rootDir}/mailbox/tosend/cpat_results_${jobnr}.zip ${rootDir}/mailbox/sent/${jobnr}
                        send_cpatmail $mail_to "Premigration Test for job ${jobnr}" "${rootDir}/mailbox/sent/${jobnr}/bodyfile" "${rootDir}/mailbox/sent/${jobnr}/cpat_results_${jobnr}.zip"
                        echo
			echo "mail sent to $mail_to"
                    else
                        echo
			echo "mail sent to $mail_to"
                        echo "ERROR creating mail content"
                    fi
                    sleep 1

 fi
  cd $rootDir/scripts
  sleep 1
  return 0
}

