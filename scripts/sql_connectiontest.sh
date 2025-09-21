  # chck exa
tns="$1"

function find_oraenv() {


      if [[ -d /acsf01/acfs ]]; then
	      # exadaata
	      export ORACLE_HOME=$(sudo dbaascli dbHome getDetails --oracleHomeName "OraHome1" | grep "homePath" | awk -F":" '{print $2}' | tr -d '"'  | tr -d " " | tr -d ",")
              export PATH=$PATH:$ORACLE_HOME/bin
              export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME/lib

      elif [[ -f ~/ora.env ]]; then
              source ~/ora.env y
      elif [[ -f ~/zdm.env ]]; then
              source ~/zdm.env
      elif [[ -f /etc/oratab ]]; then
               ORACLE_HOME=$(cat /etc/oratab | tr -d " " | grep -v "^#" | tail -n 1 | cut -d":" -f2)
	       if [ ! -z $ORACLE_HOME ]; then
		       export ORACLE_HOME=$ORACLE_HOME
                       export PATH=$PATH:$ORACLE_HOME/bin
                       export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME/lib
	       fi
      fi

}

#########################################################
# m<in
#########################################################

 {

  if [ ! -d "/tmp/modernex_premig_checks" ]; then
        echo "wrong workdir"
	exit 1
  fi

  cd /tmp/modernex_premig_checks
  find_oraenv

  oracle_env=$(which tnsping)
  if [[ $? -ne 0 ]]; then
        echo "no tnsping "
         exit 2
  fi
  mkdir admin
  mv ./tnsnames.ora  ./admin
  cp $ORACLE_HOME/network/admin/sqlnet.ora admin

  
  TNS_ADMIN=/tmp/modernex_premig_checks/admin
  export TNS_ADMIN

  tnsping "$tns" 
  if [[ $? -ne 0 ]]; then
        echo "error  tnsping "
         exit 3
  fi

  echo "TNSPINGOK"
  exit 0


} &> /tmp/modernex_premig_checks/sqlcon.log

