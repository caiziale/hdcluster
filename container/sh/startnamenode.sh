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

#--namenode
HADOOP_NAMENODE_FORMAT_FILE=${HADOOP_DATA_DIR}/hdfs/namenode/current/VERSION
HADOOP_NAMENODE_FORMAT_DIR=${HADOOP_DATA_DIR}/hdfs/namenode
HADOOP_NAMENODE_ZKNODE_FILE=${HADOOP_DATA_DIR}/hdfs/namenode/current/edits_inprogress_*
SLEEP_S=6
NAMENODE_FORMAT_PARAM="nonInteractive"

#HDFS_SITE_FILE="${HADOOP_CONF_DIR}/hdfs-site.xml"
HJMX="true"

optspec=":hv-:"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                nn_format_param=*)
                    NAMENODE_FORMAT_PARAM=${OPTARG##*=}
                    ;;
                hjmx=*)
                    HJMX=${OPTARG##*=}
                    ;;
                *)
                    echo "Unknown option --${OPTARG}" >&2
                    exit 1
                    ;;
            esac;;
        h)
            print_usage
            exit
            ;;
        v)
            echo "Parsing option: '-${optchar}'" >&2
            ;;
        *)
            if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
            fi
            ;;
    esac
done

source ${pdir}/lnsite.sh

function isNcStart() {
    ps -ef|grep nc|grep -v grep
    if [ $? -ne 0 ]; then
        nc -l -p 8019 &
    fi
}


function waitNNstart() {
    nc -l -p 8019 &
    count=0
    allcount=`sed -n 's/:8020//p' $HADOOP_CONF_DIR/hdfs-site.xml|sed -n 's/<value>//p'|sed -n 's/<\/value>//p'|wc -l`
    for i in `sed -n 's/:8020//p' $HADOOP_CONF_DIR/hdfs-site.xml|sed -n 's/<value>//p'|sed -n 's/<\/value>//p'`;
    do
    	while true;
    	do
            echo "${i}";
            ping -c 3 "${i}";
            if [ $? -eq 0 ]; then
                count=$((count+1))
                break;
            else
                sleep 10
                echo "Waiting for the ${i} container node to start..."
            fi

	    isNcStart
    	done

	isNcStart
    done

}

function killnc () {
    if [ $count -eq "$allcount" ]; then
        echo ${count}
        pid=`ps -ef|grep nc|grep -v grep|awk '{ print $2 }'`
        kill -9 "${pid}"
        echo "All NN container nodes are started..."
    else
        echo "NN container node startup failed..."
    fi
}

function startService() {

    ${HADOOP_HOME}/bin/hdfs haadmin -getAllServiceState|grep -E '(active|standby)'
    if [ $? -ne 0 ]; then
        if [[ ! (-f "${HADOOP_NAMENODE_FORMAT_FILE}") ]]; then
            printf "Format the filesystem...\033[0;35;40m%s\033[0m\n" ${DATETIME}
            #[-format [-clusterid cid ] [-force] [-nonInteractive] ]
            ${HADOOP_HOME}/bin/hdfs namenode -format -${NAMENODE_FORMAT_PARAM}
        fi    
    fi

    ${HADOOP_HOME}/bin/hdfs haadmin -getAllServiceState|grep -E '(active)'
    if [ $? -eq 0 ]; then
        printf "Active namenode...\033[0;35;40m%s\033[0m\n" ${DATETIME}
        if [[ ! (-d "${HADOOP_NAMENODE_FORMAT_DIR}") ]]; then
	
	    waitNNstart

            ${HADOOP_HOME}/bin/hdfs namenode -bootstrapStandby
            printf "namenode bootstrapStandby...\033[0;35;40m%s\033[0m\n" ${DATETIME}

	    killnc
        fi        
    fi

    if [[ ! (-d "${HADOOP_NAMENODE_FORMAT_DIR}") ]]; then
        printf "No active namenode,cannot bootstrapStandby...\033[0;35;40m%s\033[0m\n" ${DATETIME}
        printf "Note running this command check...\033[0;35;40m%s\033[0m\n" ${DATETIME}
        printf "\t\033[0;33;40m%s\033[0m\n" "${HADOOP_HOME}/bin/hdfs haadmin -getAllServiceState"
        #exit 1
    fi        

    nohup ${HADOOP_HOME}/bin/hdfs --daemon start namenode &
    printf "Sleep for \033[0;35;40m%s\033[0m and wait for the namenode to start\n" "${SLEEP_S}s"
    sleep ${SLEEP_S}    
    printf "namenode starting...\033[0;35;40m%s\033[0m\n" ${DATETIME} 
    
    ${HADOOP_HOME}/bin/hdfs haadmin -getAllServiceState|grep -E '(active)'
    if [ $? -ne 0 ]; then        
        if ( ! (ls ${HADOOP_NAMENODE_ZKNODE_FILE} >/dev/null 2>&1) ); then
            ${HADOOP_HOME}/bin/hdfs zkfc -formatZK -nonInteractive
            printf "formats the znode aborts if the znode exists,unless -force option is specified. \033[0;35;40m%s\033[0m\n" ${DATETIME}
        fi    
    fi
     
    #8019 
    nohup ${HADOOP_HOME}/bin/hdfs --daemon start zkfc &
    printf "zkfc starting...\033[0;35;40m%s\033[0m\n" ${DATETIME}

    printf "Sleep for 30s...\033[0;35;40m%s\033[0m\n" ${DATETIME}
    sleep 30
   
    printf "...... ps -ef ......\033[0;35;40m%s\033[0m\n" ${DATETIME}
    ps -ef|grep java

    printf "...... tail -f log ......\033[0;35;40m%s\033[0m\n" ${DATETIME}
    find ${HADOOP_HOME}/logs -type f -name "*namenode-namenode*.log"|xargs tail -f

    #while true;do echo "namenode..." > /dev/null 2>&1;sleep 10;done
}


ln_site && startService
