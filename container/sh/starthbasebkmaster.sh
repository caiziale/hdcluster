#!/bin/bash

# HDCluster
#
# Copyright 2023 the author.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# @author caizi

source /etc/profile

#--pwd dir
pdir=`dirname "$0"`
pdir=`cd "$pdir">/dev/null; pwd`

DATETIME=`date "+%Y-%m-%d-%H:%M:%S"`
HOSTNAME=`hostname -s`
DOMAIN=`hostname -d`

#--hbase
HBASE_SITE_FILE="${HBASE_CONF_DIR}/hbase-site.xml"
HBASE_BACKUP_MASTER_FILE=${HBASE_CONF_DIR}/backup-masters
HBASE_REGION_SERVERS_FILE=${HBASE_CONF_DIR}/regionservers

source ${pdir}/lnsite.sh

function startService() {
   ${HBASE_HOME}/bin/hbase-daemon.sh start master --backup

    printf "Sleep for 30s...\033[0;35;40m%s\033[0m\n" ${DATETIME}
    sleep 30

    printf "...... ps -ef ......\033[0;35;40m%s\033[0m\n" ${DATETIME}
    ps -ef|grep java

    printf "...... tail -f log ......\033[0;35;40m%s\033[0m\n" ${DATETIME}
    find ${HBASE_HOME}/logs -type f -name "*hbasebkmaster*.log"|xargs tail -f


   #while true;do echo "start hbase all nodes ..." > /dev/null 2>&1;sleep 60;done
}

ln_site && startService
