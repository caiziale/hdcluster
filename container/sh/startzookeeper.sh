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

#--Zookeeper cluster all nodes
#${ZOOKEEPER_HOME}

DATETIME=`date "+%Y-%m-%d-%H:%M:%S"`
HOSTNAME=`hostname -s`
DOMAIN=`hostname -d`

DATA_DIR="/data/zookeeper"
CONF_DIR="${ZOOKEEPER_HOME}/conf"
MYID_FILE=${DATA_DIR}/myid
CONF_FILE="${CONF_DIR}/zoo.cfg"
CONF_BK_FILE="${CONF_DIR}/zoo.cfg.bk"

SERVERS=1
SERVER_PORT=2888
ELECTION_PORT=3888
CLIENT_PORT=2181
HJMX="true"

optspec=":hv-:"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                servers=*)
                    SERVERS=${OPTARG##*=}
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

if [[ "${HOSTNAME}" =~ (.*)-([0-9]+)$ ]]; then
    NAME=${BASH_REMATCH[1]}
    ORD=${BASH_REMATCH[2]}
else
    echo "Fialed to parse name and ordinal of Pod."
    exit 1
fi
MYID=$((ORD+1))


function print_servers() {
    for (( i=1; i<=$SERVERS; i++ ))
    do
        echo "server.$i=$NAME-$((i-1)).$DOMAIN:$SERVER_PORT:$ELECTION_PORT"
    done
}

function create_config(){
    rm -f ${CONF_FILE}
    cp ${CONF_BK_FILE} ${CONF_FILE}

    #echo "" >> ${CONF_FILE}

    if [ ${SERVERS} -gt 1 ]; then
        print_servers >> ${CONF_FILE}
    fi

    cat ${CONF_FILE}
}

function create_data(){
    if [[ ! (-s ${MYID_FILE}) ]]; then
        if [[ ! (-z ${MYID}) ]]; then
            echo ${MYID} > ${MYID_FILE}
        else
            printf "Please check this file \033[0;33;40m%s\033[0m  \033[0;35;40m%s\033[0m\n" ${MYID_FILE} ${DATETIME}
            exit 1
        fi
    fi

}

function startService(){
    ${ZOOKEEPER_HOME}/bin/zkServer.sh start-foreground
    printf "zk server starting...\033[0;35;40m%s\033[0m\n" ${DATETIME}

    cat /opt/software/apache-zookeeper-3.8.0-bin/logs/*
}


create_config && create_data && startService
