#!/bin/bash

cd /mount/sa4zdmfs/zdmconfig/dev/premigration/scripts 

. ../premigration.env

./fetch_cmdb_data.sh refresh_mig

chmod 777 "/tmp/miginfo_refresh.log"
