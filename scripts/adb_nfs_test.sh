#!/bin/bash

# 22.08.2024 v1.0. rr
#
#


#----------------------------------------------------------
# help functions
#----------------------------------------------------------

function getUser() {

        local vm=$1

        cuser=$(cat $configDir/known_users | grep "$vm" | cut -d ";" -f2)
        if [[ -z $cuser  ]]; then
                cuser="oracle"
        fi
}


function lmsg() {
 # par 1 - action "L"=Large, "N" normal
 # par 2 - msg
 #
lmsg="${3}"
lact=${1}
ldat=`date  +"%Y%m%d-%H%M%S"`
ltype=${2}

 case $ltype in
   E) inftxt="[ERROR]" ;;
   I) inftxt="[INFO]" ;;
   *) inftxt="[UNKKOWN:$ltype]" ;;
 esac


  if [ "${lact}" == "L" ]; then
    echo ${ldat}"** =========================================================="  #  >> ${dbResultDir}/${lfnr}_${test_to_run}.msg
    echo ${ldat}"** ${inftxt} ${lmsg}"                                           #  >> ${dbResultDir}/${lfnr}_${test_to_run}.msg
    echo ${ldat}"** =========================================================="  #  >> ${dbResultDir}/${lfnr}_${test_to_run}.msg
    echo " "
 else
    echo ${ldat}"** ${inftxt} ${lmsg}" #>> ${dbResultDir}/${lfnr}_${test_to_run}.msg
  fi
}

#---------------------------------------------------------

function checkValue() {
           local fn=$1
           local txt=$2
  #         if [[ "X${fn}" == "X"  ]]; then
           if [[ -z ${fn}  ]]; then

                lmsg N E "value for  ${txt} not exists !! "
                #write_resultsfile 1 0 "internal error: value for  ${txt} not exists "
		exit 1
           else
                lmsg N I "value for  ${txt} = $fn"
           fi
}

#---------------------------------------------------------

function checkErr() {
        local errc=$1
        local txt=$2

        if [[ $errc -ne 0 ]]; then
                lmsg N E "error $txt ... exit"
                write_resultsfile 1 0 "internal error: value for  ${txt} "
                   exit 1
	else
                lmsg N I "no error $txt"
        fi
}

#---------------------------------------------------------

function chk() {

     local retcode=$1
     local action=$2
     local text=$3

     if [[ $retcode -ne 0 ]]; then

          lmsg N $action "retc not null; $text "

	  if [[´"$action" == "E" ]]; then
                  result=$(echo "FAILED - retc=$retcode; $text")
	          echo "exit check..."
		  exit 1
	  fi
      else
          lmsg N I "retc OK $text "
      fi
}


function precheck() {


	nrtasks=1
	holdfile="/tmp/adbhold"

       if [ -z $srcdb ]; then
	       checkErr 1 "missing sourcedb"
       fi


       driver_file=./results/$srcdb/premigration.drv

       if [ -f $driver_file ]; then
              source $driver_file
       else
	      checkErr 1 "missing driverfile from db $srcdb"

       fi

}





#-------------------------------------------------------------------------------------------



function read_file() {

	if [ -z  $adbname ]; then

                   write_resultsfile 0 0 "nfs mount adb - no target"
		   return
        fi


	echo "vaaaaaaaaaaaaaaaaaa"

        source $HOME/ora.env
        adb_pw="qmt_TE22bY_xCd"


        checkValue "$adbname"                  "nfs 34"
        checkValue "$adb_pw"                    "nfs 36"
        checkValue "$TNS_ADMIN"                 "nfs 31"
        checkValue "$ORACLE_HOME"               "nfs 32"
        checkValue "$dirname"                   "nfs 35"
       # checkValue "$filename"                   "nfs 37"
#	cat $configDir/tns_${adbname}.ora >>  /tmp/tns$$
#	mv  /tmp/tns$$ $TNS_ADMIN/tnsnames.ora

        lmsg N I "Running adb NFS READ test on $adbname"
        cuser="admin"
        sqlpa=$(echo "sqlplus -s $cuser/$adb_pw@%${adbname}_high%" | tr -d '"' | tr "%" "'")

        while true
	do

	  if [ ! -f $holdfile ]; then
		  break
	  fi
	  sleep 1
		  
	done

        filename="${adbname}_dp_sim_${nrtassks}.dat"
	
        #nfs_test=$(eval $sqlpb  << EOF


{
        eval $sqlpa  << EOF
            set serveroutput on;
            set linesize 3000;
            set feedback off;
            set heading off;



SELECT directory_name,
       file_system_location
FROM dba_cloud_file_systems
where directory_name = '$dirname';

exit;

EOF

} > /tmp/adb_sh.out



{
        eval $sqlpa  << EOF
            set serveroutput on;	
            set linesize 3000;
            set feedback off;
            set heading off;


DECLARE
  l_file       UTL_FILE.FILE_TYPE;
  l_raw        RAW(32767);
  l_filename   VARCHAR2(100) := '${filename}';
  v_bytes      INTEGER := 0;
  v_target_mb  INTEGER := $countnr; -- MB to write
  v_start      TIMESTAMP;
  v_end        TIMESTAMP;
  v_secs       NUMBER;
  v_mb         NUMBER;
  v_loops      INTEGER;
BEGIN
  l_file := UTL_FILE.FOPEN('$dirname', l_filename, 'wb', 32767);
  l_raw := UTL_RAW.CAST_TO_RAW(RPAD('X', 32767, 'X')); -- 32KB block

  v_loops := (v_target_mb * 1024 * 1024) / 32767;

  v_start := SYSTIMESTAMP;

  FOR i IN 1 .. v_loops LOOP
    UTL_FILE.PUT_RAW(l_file, l_raw);
    v_bytes := v_bytes + LENGTH(l_raw);
  END LOOP;

  UTL_FILE.FCLOSE(l_file);
  v_end := SYSTIMESTAMP;

  v_secs := EXTRACT(SECOND FROM (v_end - v_start)) +
            EXTRACT(MINUTE FROM (v_end - v_start)) * 60 +
            EXTRACT(HOUR FROM (v_end - v_start)) * 3600;
  v_mb := ROUND(v_bytes / (1024 * 1024), 2);

  DBMS_OUTPUT.PUT_LINE('-- WRITE STATS ---');
  DBMS_OUTPUT.PUT_LINE('Share        : $dirname');
  DBMS_OUTPUT.PUT_LINE('MB Written   : ' || v_mb);
  DBMS_OUTPUT.PUT_LINE('Duration     : ' || TO_CHAR(v_end - v_start));
  DBMS_OUTPUT.PUT_LINE('Throughput   : ' || ROUND(v_mb / v_secs, 2) || ' MB/sec');
END;
/
exit;
EOF

} >> /tmp/adb_wr_${nrtasks}.out;

{
        eval $sqlpa  << EOF
            set serveroutput on;
            set linesize 3000;
            set feedback off;
            set heading off;

DECLARE
  l_file        UTL_FILE.FILE_TYPE;
  l_raw         RAW(32767);
  v_total_bytes INTEGER := 0;
  v_start       TIMESTAMP;
  v_end         TIMESTAMP;
  v_secs        NUMBER;
  v_mb          NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- READ STATS ---');

  v_start := SYSTIMESTAMP;

  l_file := UTL_FILE.FOPEN('$dirname', '${filename}', 'rb', 32767);

  LOOP
    BEGIN
      UTL_FILE.GET_RAW(l_file, l_raw, 32767);
      v_total_bytes := v_total_bytes + LENGTHB(l_raw);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        EXIT;
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Read error: ' || SQLERRM);
        EXIT;
    END;
  END LOOP;

  UTL_FILE.FCLOSE(l_file);
  v_end := SYSTIMESTAMP;

  v_secs := EXTRACT(SECOND FROM (v_end - v_start)) +
            EXTRACT(MINUTE FROM (v_end - v_start)) * 60 +
            EXTRACT(HOUR FROM (v_end - v_start)) * 3600;
  v_mb := ROUND(v_total_bytes / (1024 * 1024), 2);

  DBMS_OUTPUT.PUT_LINE('Share        : $dirname');
  DBMS_OUTPUT.PUT_LINE('MB Read      : ' || v_mb);
  DBMS_OUTPUT.PUT_LINE('Duration     : ' || TO_CHAR(v_end - v_start));
  DBMS_OUTPUT.PUT_LINE('Throughput   : ' || ROUND(v_mb / v_secs, 2) || ' MB/sec');
END;
/

EOF
} >> /tmp/adb_read_adb_${nrtasks}.out


sort /tmp/adb_wr*.out
sort /tmp/adb_read*.out


}

function start_bench() {


	touch $holdfile
	nrtasks=0

        source $HOME/ora.env
	cp ./configfiles/wallet_ADBIDARTT_regional.zip $TNS_ADMIN/

	curd=`pwd`
	cd $TNS_ADMIN
        rm $TNS_ADMIN/README
        rm $TNS_ADMIN/cwallet.sso
        rm $TNS_ADMIN/ewallet.pem
        rm $TNS_ADMIN/tnsnames.ora
        rm $TNS_ADMIN/truststore.jks
        rm $TNS_ADMIN/ojdbc.properties
        rm $TNS_ADMIN/sqlnet.ora
        rm $TNS_ADMIN/ewallet.p12
        rm $TNS_ADMIN/keystore.jks
	
	unzip wallet_ADBIDARTT_regional.zip

	cd $curd
        rm /tmp/adb*.out
	while true
	do
            let nrtasks=${nrtasks}+1
	    if [ $nrtasks -gt $tasknr ]; then
		    break
	    fi

	    ./adb_nfs_test.sh -s $srcdb -d $dirname  -a readf -c $countnr -t $nrtasks > /tmp/adbnfsrun_${nrtasks}.out &
	    echo "run >>> ./adb_nfs_test.sh -s $srcdb -d $dirname  -a readf -c $countnr -t $nrtasks "

	done

	sleep 2
	rm $holdfile

	ps -ef | grep adbnfsrun

	echo "waiting on results..."
	wait

        echo " "	
	echo "----------Share:"
	cat /tmp/adb_sh.out
	echo "----------Results:"
        cat /tmp/adb_wr*.out
        cat /tmp/adb_read*.out

}

#=========================================

#------------------------------#

lmsg L I "Start test $test_to_run"
while getopts "s:p:l:a:d:c:t:" opt; do
    case $opt in
        a) action="$OPTARG" ;;
        p) adb_pw="$OPTARG" ;;
        s) srcdb="$OPTARG" ;;
        d) dirname="$OPTARG" ;;
        c) countnr="$OPTARG" ;;
        t) tasknr="$OPTARG" ;;
        *) usage ;;
    esac
done

precheck;

case $action in
        readf) read_file                                               ;;
	 runb) start_bench ;;
	    *) result="NONE,        not implemenetet yet"
esac
echo "$result" > ${tmp_dir}/${nrtasks}_${test_to_run}_status

exit 0
