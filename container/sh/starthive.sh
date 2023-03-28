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

#--hive
HIVE_WAREHOUSE_DIR="/user/hive/warehouse"
HIVE_TMP_DIR="/tmp"

source ${pdir}/lnsite.sh

function InitHiveDfs() {
    ${HADOOP_HOME}/bin/hadoop fs -mkdir  -p   ${HIVE_TMP_DIR}
    ${HADOOP_HOME}/bin/hadoop fs -mkdir  -p   ${HIVE_WAREHOUSE_DIR}
    printf "Creating directory [\033[0;33;40m%s\033[0m]...\033[0;35;40m%s\033[0m\n" ${HIVE_WAREHOUSE_DIR} ${DATETIME}
    printf "Creating directory [\033[0;33;40m%s\033[0m]...\033[0;35;40m%s\033[0m\n" ${HIVE_TMP_DIR} ${DATETIME}

    ${HADOOP_HOME}/bin/hadoop fs -chmod g+w   ${HIVE_WAREHOUSE_DIR}
    ${HADOOP_HOME}/bin/hadoop fs -chmod 777   ${HIVE_WAREHOUSE_DIR}
    ${HADOOP_HOME}/bin/hadoop fs -chmod g+w   ${HIVE_TMP_DIR}
    ${HADOOP_HOME}/bin/hadoop fs -chmod 777   ${HIVE_TMP_DIR}
    printf "Setting writeable group rights for directory [\033[0;33;40m%s\033[0m]...\033[0;35;40m%s\033[0m\n" ${HIVE_WAREHOUSE_DIR} ${DATETIME}
    printf "Setting writeable group rights for directory [\033[0;33;40m%s\033[0m]...\033[0;35;40m%s\033[0m\n" ${HIVE_TMP_DIR} ${DATETIME}
}

function startService() {

    ${HADOOP_HOME}/bin/hadoop fs -test -d ${HIVE_WAREHOUSE_DIR}
    if [ $? -ne 0 ]; then
        InitHiveDfs        
    fi

    ${HIVE_HOME}/bin/schematool -dbType mysql -info|grep -E 'completed'
    if [ $? -ne 0 ]; then
        ${HIVE_HOME}/bin/schematool -dbType mysql -initSchema --verbose
        printf "Hive initSchema...\033[0;35;40m%s\033[0m\n" ${DATETIME}
    fi

    sleep 5
    ${pdir}/hivemetastore_s start
    sleep 10
    ${pdir}/hiveserver2_s start

    printf "Sleep for 30s...\033[0;35;40m%s\033[0m\n" ${DATETIME}
    sleep 30

    printf "...... ps -ef ......\033[0;35;40m%s\033[0m\n" ${DATETIME}
    ps -ef|grep java

    printf "...... tail -f log ......\033[0;35;40m%s\033[0m\n" ${DATETIME}
    find ${HIVE_HOME}/logs -type f -name "hive.log"|xargs tail -f

    #while true;do echo "start hbase all nodes ..." > /dev/null 2>&1;sleep 60;done
}

ln_site && startService
