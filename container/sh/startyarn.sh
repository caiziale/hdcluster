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

#--yarn all nodes
DATETIME=`date "+%Y-%m-%d-%H:%M:%S"`
HOSTNAME=`hostname -s`
DOMAIN=`hostname -d`

HJMX="true"

optspec=":hv-:"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
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

function startService() {

    nohup ${HADOOP_HOME}/bin/yarn --daemon start resourcemanager &
    printf "hadoop resourcemanager starting...\033[0;35;40m%s\033[0m\n" ${DATETIME}

    printf "Sleep for 30s...\033[0;35;40m%s\033[0m\n" ${DATETIME}
    sleep 30

    printf "...... ps -ef ......\033[0;35;40m%s\033[0m\n" ${DATETIME}
    ps -ef|grep java

    printf "...... tail -f log ......\033[0;35;40m%s\033[0m\n" ${DATETIME}
    find ${HADOOP_HOME}/logs -type f -name "*resourcemanager*.log"|xargs tail -f

    #while true;do echo "resourcemanager..." > /dev/null 2>&1;sleep 10;done
}

ln_site && startService
