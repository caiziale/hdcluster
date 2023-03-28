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

function print_usage() {
echo "\
Usage: create_site.sh [OPTIONS]
Starts containers cluster based on the supplied options.
    --servers           The number of servers in the container cluster. The default 
                        value is 1.
                        Containers included are:journal, namenode, resourcemanager, hbasebkmaster.


    --regionservers     The number of servers in the container cluster. The default 
                        value is 2.
                        Containers included are:hbaseregionserver.               


    --mysqlpassword     MySQL password that provides metadata support for Apache Hive.
                        Please refer to create_HDCluster_k8s.sh script.
                        
"
}

SITE_LOCK_FILE="/mnt/site.lock"

DATETIME=`date "+%Y-%m-%d-%H:%M:%S"`
HOSTNAME=`hostname -s`
DOMAIN=`hostname -d`

if [[ "${HOSTNAME}" =~ (.*)-([0-9]+)$ ]]; then
    NAME=${BASH_REMATCH[1]}
    ORD=${BASH_REMATCH[2]}
else
    echo "Fialed to parse name and ordinal of Pod."
    exit 1
fi


SERVERS=1
REGIONSERVERS=2
#--namenode
NAMENODE_APP="namenode"
NAMESERVICE_ID="mycluster"
NAMENODE_ID="nn"

NAMENODE_RPC_PORT=8020
NAMENODE_HTTP_PORT=9870

HDFS_SITE_FILE="${HADOOP_CONF_DIR}/hdfs-site.xml"
CORE_SITE_FILE="${HADOOP_CONF_DIR}/core-site.xml"
HADOOP_NAMENODE_FORMAT_FILE=${HADOOP_DATA_DIR}/hdfs/namenode/current/VERSION
HADOOP_NAMENODE_FORMAT_DIR=${HADOOP_DATA_DIR}/hdfs/namenode
HADOOP_NAMENODE_ZKNODE_FILE=${HADOOP_DATA_DIR}/hdfs/namenode/current/edits_inprogress_*
SLEEP_S=6

#--journal
JOURNAL_APP="journal"
JOURNAL_SERVER_PORT=8485

#--yarn
YARN_APP="resourcemanager"
RM_CLUSTER_ID="rmcluster1"
RM_ID="rm"
RM_WEBAPP_PORT=8088
YARN_SITE_FILE="${HADOOP_CONF_DIR}/yarn-site.xml"

#--jobhistory
JOBHISTORY_APP="jobhistory"
JOBHISTORY_PORT=10020
JOBHISTORY_WEBAPP_PORT=19888
MAPRED_SITE_FILE="${HADOOP_CONF_DIR}/mapred-site.xml"

#--hbase
HBASE_SITE_FILE="${HBASE_CONF_DIR}/hbase-site.xml"
HBASE_BACKUP_MASTER_FILE=${HBASE_CONF_DIR}/backup-masters
HBASE_REGION_SERVERS_FILE=${HBASE_CONF_DIR}/regionservers

HMASTER_APP="hbasemaster"
HBKMASTER_APP="hbasebkmaster"
HREGIONSERVER_APP="hbaseregionserver"

#--spark
SPARK_CONF_FILE="${SPARK_CONF_DIR}/spark-defaults.conf"

#--hive
HIVE_SITE_FILE="${HIVE_CONF_DIR}/hive-site.xml"
HIVE_APP="hiveserver"
HIVE_SERVER2_PORT=9083

#--mysql
MYSQL_CLIENT="mysql-cs"
MYSQL_PORT=3306
MYSQL_USER="root"

#--zk
ZK_QUORUM="zk-cs"
ZK_CLIENT_PORT=2181

#--default
MNT_BK_DIR="/mnt/bk_${DATETIME}"

HJMX="true"

optspec=":hv-:"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                servers=*)
                    SERVERS=${OPTARG##*=}
                    ;;
                regionservers=*)
                    REGIONSERVERS=${OPTARG##*=}
                    ;;
                mysqlpassword=*)
                    MYSQLPASSWORD=${OPTARG##*=}
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
	    exit 1
            ;;
        *)
            if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
            fi
	    exit 1
            ;;
    esac
done


journaldomain=`echo "${DOMAIN}" | sed "s/^[a-z|A-Z]*/${JOURNAL_APP}/"`
namenodedomain=`echo "${DOMAIN}" | sed "s/^[a-z|A-Z]*/${NAMENODE_APP}/"`
yarndomain=`echo "${DOMAIN}" | sed "s/^[a-z|A-Z]*/${YARN_APP}/"`
jobhistorydomain=`echo "${DOMAIN}" | sed "s/^[a-z|A-Z]*/${JOBHISTORY_APP}/"`

hbasemasterdomain=`echo "${DOMAIN}" | sed "s/^[a-z|A-Z]*/${HMASTER_APP}/"`
hbasebkmasterdomain=`echo "${DOMAIN}" | sed "s/^[a-z|A-Z]*/${HBKMASTER_APP}/"`
hbaseregionserverdomain=`echo "${DOMAIN}" | sed "s/^[a-z|A-Z]*/${HREGIONSERVER_APP}/"`

hiveserverdomain=`echo "${DOMAIN}" | sed "s/^[a-z|A-Z]*/${HIVE_APP}/"`


function startService() {
    while true;do echo "create site xml..." > /dev/null 2>&1;sleep 60;done
}

if [[ -f ${SITE_LOCK_FILE} ]]; then    
    startService
    exit 0
fi

function hdfs_config() {
    cp "${HDFS_SITE_FILE}" "${HDFS_SITE_FILE}_${DATETIME}"
    rm -f "${HDFS_SITE_FILE}"
    cp "${HDFS_SITE_FILE}.bk" "${HDFS_SITE_FILE}"

    cp "${CORE_SITE_FILE}" "${CORE_SITE_FILE}_${DATETIME}"
    rm -f "${CORE_SITE_FILE}"
    cp "${CORE_SITE_FILE}.bk" "${CORE_SITE_FILE}"


    echo "<configuration>" >> ${CORE_SITE_FILE}
    echo "    <property>" >> ${CORE_SITE_FILE}
    echo "      <name>fs.defaultFS</name>" >> ${CORE_SITE_FILE}
    echo "      <value>hdfs://${NAMESERVICE_ID}</value>" >> ${CORE_SITE_FILE}
    echo "    </property>" >> ${CORE_SITE_FILE}
    echo "    <property>" >> ${CORE_SITE_FILE}
    echo "      <name>hadoop.proxyuser.root.hosts</name>" >> ${CORE_SITE_FILE}
    echo "      <value>*</value>" >> ${CORE_SITE_FILE}
    echo "    </property>" >> ${CORE_SITE_FILE}
    echo "    <property>" >> ${CORE_SITE_FILE}
    echo "      <name>hadoop.proxyuser.root.groups</name>" >> ${CORE_SITE_FILE}
    echo "      <value>*</value>" >> ${CORE_SITE_FILE}
    echo "    </property>" >> ${CORE_SITE_FILE}
    echo "</configuration>" >> ${CORE_SITE_FILE}
    

    echo "<configuration>" >> ${HDFS_SITE_FILE}
    echo "    <property>" >> ${HDFS_SITE_FILE}
    echo "        <name>dfs.namenode.name.dir</name>" >> ${HDFS_SITE_FILE}
    echo "        <value>file:///data/hdfs/namenode</value>" >> ${HDFS_SITE_FILE}
    echo "        <description>NameNode directory for namespace and transaction logs storage.</description>" >> ${HDFS_SITE_FILE}
    echo "    </property>" >> ${HDFS_SITE_FILE}
    echo "    <property>" >> ${HDFS_SITE_FILE}
    echo "        <name>dfs.datanode.data.dir</name>" >> ${HDFS_SITE_FILE}
    echo "        <value>file:///data/hdfs/datanode</value>" >> ${HDFS_SITE_FILE}
    echo "        <description>DataNode directory</description>" >> ${HDFS_SITE_FILE}
    echo "    </property>" >> ${HDFS_SITE_FILE}


    echo "    <property>" >> ${HDFS_SITE_FILE}
    echo "      <name>dfs.nameservices</name>" >> ${HDFS_SITE_FILE}
    echo "      <value>${NAMESERVICE_ID}</value>" >> ${HDFS_SITE_FILE}
    echo "    </property>" >> ${HDFS_SITE_FILE}
 
    for (( i=$SERVERS; i>=1; i-- )) 
    do
        namenodeidtmps="$NAMENODE_ID$i,$namenodeidtmps"
        namenodeidtmps=`echo ${namenodeidtmps} | sed "s|,$||g"`        
    done    
    echo "    <property>" >> ${HDFS_SITE_FILE}
    echo "      <name>dfs.ha.namenodes.${NAMESERVICE_ID}</name>" >> ${HDFS_SITE_FILE}
    echo "      <value>${namenodeidtmps}</value>" >> ${HDFS_SITE_FILE}
    echo "    </property>" >> ${HDFS_SITE_FILE}

    for (( i=1; i<=$SERVERS; i++ ))
    do
        namenodeidtmp="$NAMENODE_ID$i"
        nnrpcadresstmp="$NAMENODE_APP-$((i-1)).$namenodedomain:$NAMENODE_RPC_PORT"
        echo "    <property>" >> ${HDFS_SITE_FILE}
        echo "      <name>dfs.namenode.rpc-address.${NAMESERVICE_ID}.${namenodeidtmp}</name>" >> ${HDFS_SITE_FILE}
        echo "      <value>${nnrpcadresstmp}</value>" >> ${HDFS_SITE_FILE}
        echo "    </property>" >> ${HDFS_SITE_FILE}
    done    

    nnrpcadresstmp=""
    namenodeidtmp=""
    for (( i=1; i<=$SERVERS; i++ ))
    do
        namenodeidtmp="$NAMENODE_ID$i"
        nnrpcadresstmp="$NAMENODE_APP-$((i-1)).$namenodedomain:$NAMENODE_HTTP_PORT"
        echo "    <property>" >> ${HDFS_SITE_FILE}
        echo "      <name>dfs.namenode.http-address.${NAMESERVICE_ID}.${namenodeidtmp}</name>" >> ${HDFS_SITE_FILE}
        echo "      <value>${nnrpcadresstmp}</value>" >> ${HDFS_SITE_FILE}
        echo "    </property>" >> ${HDFS_SITE_FILE}
    done    


    #journaldomain=`echo "${DOMAIN}" | sed "s/^[a-z|A-Z]*/${JOURNAL_APP}/"`
    for (( i=1; i<=$SERVERS; i++ ))
    do
        journaltmp="$JOURNAL_APP-$((i-1)).$journaldomain:$JOURNAL_SERVER_PORT;${journaltmp}"
    done    
    journaltmp=`echo ${journaltmp} | sed 's/;$//g'`
    journaltmp=`echo "qjournal://"${journaltmp}"/${NAMESERVICE_ID}"`
    echo "    <property>" >> ${HDFS_SITE_FILE}
    echo "      <name>dfs.namenode.shared.edits.dir</name>" >> ${HDFS_SITE_FILE}
    echo "      <value>${journaltmp}</value>" >> ${HDFS_SITE_FILE}
    echo "    </property>" >> ${HDFS_SITE_FILE}


    echo "    <property>" >> ${HDFS_SITE_FILE}
    echo "      <name>dfs.client.failover.proxy.provider.${NAMESERVICE_ID}</name>" >> ${HDFS_SITE_FILE}
    echo "      <value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>" >> ${HDFS_SITE_FILE}
    echo "    </property>" >> ${HDFS_SITE_FILE}


    echo "    <property>" >> ${HDFS_SITE_FILE}
    echo "      <name>dfs.ha.fencing.methods</name>" >> ${HDFS_SITE_FILE}
    echo "      <value>shell(/bin/true)</value>" >> ${HDFS_SITE_FILE}
    echo "    </property>" >> ${HDFS_SITE_FILE}

    echo "    <property>" >> ${HDFS_SITE_FILE}
    echo "      <name>dfs.journalnode.edits.dir</name>" >> ${HDFS_SITE_FILE}
    echo "      <value>/data/journal/node/data</value>" >> ${HDFS_SITE_FILE}
    echo "    </property>" >> ${HDFS_SITE_FILE}

    echo "    <!-- zk -->" >> ${HDFS_SITE_FILE}
    echo "    <property>" >> ${HDFS_SITE_FILE}
    echo "      <name>dfs.ha.automatic-failover.enabled</name>" >> ${HDFS_SITE_FILE}
    echo "      <value>true</value>" >> ${HDFS_SITE_FILE}
    echo "    </property>" >> ${HDFS_SITE_FILE}
    echo "    <property>" >> ${HDFS_SITE_FILE}
    echo "      <name>ha.zookeeper.quorum</name>" >> ${HDFS_SITE_FILE}
    echo "      <value>${ZK_QUORUM}:${ZK_CLIENT_PORT}</value>" >> ${HDFS_SITE_FILE}
    echo "    </property>" >> ${HDFS_SITE_FILE}

    echo "</configuration>" >> ${HDFS_SITE_FILE}
  
}

function yarn_config() {
    cp "${YARN_SITE_FILE}" "${YARN_SITE_FILE}_${DATETIME}"
    rm -f "${YARN_SITE_FILE}"
    cp "${YARN_SITE_FILE}.bk" "${YARN_SITE_FILE}"

    echo "<configuration>" >> ${YARN_SITE_FILE}
    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "        <name>yarn.resourcemanager.ha.enabled</name>" >> ${YARN_SITE_FILE}
    echo "        <value>true</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}
    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "        <name>yarn.resourcemanager.cluster-id</name>" >> ${YARN_SITE_FILE}
    echo "        <value>${RM_CLUSTER_ID}</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}

    for (( i=$SERVERS; i>=1; i-- ))
    do
        rmidtmps="$RM_ID$i,$rmidtmps"        
    done
    rmidtmps=`echo ${rmidtmps} | sed "s|,$||g"`
    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "        <name>yarn.resourcemanager.ha.rm-ids</name>" >> ${YARN_SITE_FILE}
    echo "        <value>${rmidtmps}</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}

    for (( i=1; i<=$SERVERS; i++ ))
    do        
        echo "    <property>" >> ${YARN_SITE_FILE}
        echo "        <name>yarn.resourcemanager.hostname.$RM_ID$i</name>" >> ${YARN_SITE_FILE}
        echo "        <value>$YARN_APP-$((i-1)).$yarndomain</value>" >> ${YARN_SITE_FILE}
        echo "    </property>" >> ${YARN_SITE_FILE}
    done    

    for (( i=1; i<=$SERVERS; i++ ))
    do        
        webappaddresstmp="$YARN_APP-$((i-1)).$yarndomain:${RM_WEBAPP_PORT}"
        echo "    <property>" >> ${YARN_SITE_FILE}
        echo "        <name>yarn.resourcemanager.webapp.address.$RM_ID$i</name>" >> ${YARN_SITE_FILE}
        echo "        <value>${webappaddresstmp}</value>" >> ${YARN_SITE_FILE}
        echo "    </property>" >> ${YARN_SITE_FILE}
    done    

    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "        <name>hadoop.zk.address</name>" >> ${YARN_SITE_FILE}
    echo "        <value>${ZK_QUORUM}:${ZK_CLIENT_PORT}</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}
    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "        <name>yarn.nodemanager.aux-services</name>" >> ${YARN_SITE_FILE}
    echo "        <value>mapreduce_shuffle</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}

    echo "    <!-- Fair Scheduler -->" >> ${YARN_SITE_FILE}
    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "        <name>yarn.resourcemanager.scheduler.class</name>" >> ${YARN_SITE_FILE}
    echo "        <value>org.apache.hadoop.yarn.server.resourcemanager.scheduler.fair.FairScheduler</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}
    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "        <name>yarn.scheduler.fair.allocation.file</name>" >> ${YARN_SITE_FILE}
    echo "	      <value>${HADOOP_CONF_DIR}/fair-scheduler.xml</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}

    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "        <name>yarn.scheduler.fair.preemption</name>" >> ${YARN_SITE_FILE}
    echo "        <value>true</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}
    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "        <name>yarn.scheduler.fair.user-as-default-queue</name>" >> ${YARN_SITE_FILE}
    echo "        <value>true</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}
    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "        <name>yarn.scheduler.fair.allow-undeclared-pools</name>" >> ${YARN_SITE_FILE}
    echo "        <value>false</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}
  
    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "      <description>" >> ${YARN_SITE_FILE}
    echo "      Flag to enable the ResourceManager reservation system." >> ${YARN_SITE_FILE}
    echo "      </description>" >> ${YARN_SITE_FILE}
    echo "      <name>yarn.resourcemanager.reservation-system.enable</name>" >> ${YARN_SITE_FILE}
    echo "      <value>true</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}

    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "      <description>" >> ${YARN_SITE_FILE}
    echo "      The Java class to use as the ResourceManager reservation system." >> ${YARN_SITE_FILE}
    echo "      By default, is set to" >> ${YARN_SITE_FILE}
    echo "      org.apache.hadoop.yarn.server.resourcemanager.reservation.CapacityReservationSystem" >> ${YARN_SITE_FILE}
    echo "      when using CapacityScheduler and is set to" >> ${YARN_SITE_FILE}
    echo "      org.apache.hadoop.yarn.server.resourcemanager.reservation.FairReservationSystem" >> ${YARN_SITE_FILE}
    echo "      when using FairScheduler." >> ${YARN_SITE_FILE}
    echo "      </description>" >> ${YARN_SITE_FILE}
    echo "      <name>yarn.resourcemanager.reservation-system.class</name>" >> ${YARN_SITE_FILE}
    echo "      <value>org.apache.hadoop.yarn.server.resourcemanager.reservation.FairReservationSystem</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}

    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "      <description>" >> ${YARN_SITE_FILE}
    echo "      The plan follower policy class name to use for the ResourceManager" >> ${YARN_SITE_FILE}
    echo "      reservation system." >> ${YARN_SITE_FILE}
    echo "      By default, is set to" >> ${YARN_SITE_FILE}
    echo "      org.apache.hadoop.yarn.server.resourcemanager.reservation.CapacitySchedulerPlanFollower" >> ${YARN_SITE_FILE}
    echo "      is used when using CapacityScheduler, and is set to" >> ${YARN_SITE_FILE}
    echo "      org.apache.hadoop.yarn.server.resourcemanager.reservation.FairSchedulerPlanFollower" >> ${YARN_SITE_FILE}
    echo "      when using FairScheduler." >> ${YARN_SITE_FILE}
    echo "      </description>" >> ${YARN_SITE_FILE}
    echo "      <name>yarn.resourcemanager.reservation-system.plan.follower</name>" >> ${YARN_SITE_FILE}
    echo "      <value>org.apache.hadoop.yarn.server.resourcemanager.reservation.FairSchedulerPlanFollower</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}

    echo "    <property>" >> ${YARN_SITE_FILE}
    echo "      <description>" >> ${YARN_SITE_FILE}
    echo "      Step size of the reservation system in ms" >> ${YARN_SITE_FILE}
    echo "      </description>" >> ${YARN_SITE_FILE}
    echo "      <name>yarn.resourcemanager.reservation-system.planfollower.time-step</name>" >> ${YARN_SITE_FILE}
    echo "      <value>1000</value>" >> ${YARN_SITE_FILE}
    echo "    </property>" >> ${YARN_SITE_FILE}
    echo "</configuration>" >> ${YARN_SITE_FILE}
}

InitHBNodesFunc() {
    if [[ -f ${HBASE_BACKUP_MASTER_FILE} ]]; then
        cp "${HBASE_BACKUP_MASTER_FILE}" "${HBASE_BACKUP_MASTER_FILE}_${DATETIME}"
        rm -f "${HBASE_BACKUP_MASTER_FILE}"
        cp "${HBASE_BACKUP_MASTER_FILE}.bk" "${HBASE_BACKUP_MASTER_FILE}"
    fi
    if [[ -f ${HBASE_REGION_SERVERS_FILE} ]]; then
        cp "${HBASE_REGION_SERVERS_FILE}" "${HBASE_REGION_SERVERS_FILE}_${DATETIME}"
        rm -f "${HBASE_REGION_SERVERS_FILE}"
        cp "${HBASE_REGION_SERVERS_FILE}.bk" "${HBASE_REGION_SERVERS_FILE}"
    fi

    for (( i=1; i<=$SERVERS; i++ ))
    do
        hbktmp="$HBKMASTER_APP-$((i-1))"
        echo ${hbktmp} >> ${HBASE_BACKUP_MASTER_FILE}
    done    
    for (( i=1; i<=$REGIONSERVERS; i++ ))
    do
        hrstmp="$HREGIONSERVER_APP-$((i-1))"
        echo ${hrstmp} >> ${HBASE_REGION_SERVERS_FILE}
    done
}

function hbase_config() {
    cp "${HBASE_SITE_FILE}" "${HBASE_SITE_FILE}_${DATETIME}"
    rm -f "${HBASE_SITE_FILE}"
    cp "${HBASE_SITE_FILE}.bk" "${HBASE_SITE_FILE}"

    InitHBNodesFunc

    echo "      <property>" >> ${HBASE_SITE_FILE}
    echo "        <name>hbase.cluster.distributed</name>" >> ${HBASE_SITE_FILE}
    echo "        <value>true</value>" >> ${HBASE_SITE_FILE}
    echo "      </property>" >> ${HBASE_SITE_FILE}

    echo "      <property>" >> ${HBASE_SITE_FILE}
    echo "        <name>hbase.rootdir</name>" >> ${HBASE_SITE_FILE}
    echo "        <value>hdfs://${NAMESERVICE_ID}/hbase</value>" >> ${HBASE_SITE_FILE}
    echo "      </property>" >> ${HBASE_SITE_FILE}
    echo "      <property>" >> ${HBASE_SITE_FILE}
    echo "        <name>hbase.zookeeper.quorum</name>" >> ${HBASE_SITE_FILE}
    echo "        <value>${ZK_QUORUM}:${ZK_CLIENT_PORT}</value>" >> ${HBASE_SITE_FILE}
    echo "      </property>" >> ${HBASE_SITE_FILE}

    hbktmp=""
    for (( i=1; i<=$SERVERS; i++ ))
    do
        hbktmp="$HBKMASTER_APP-$((i-1)).$hbasebkmasterdomain,${hbktmp}"        
    done
    hbktmp="${hbktmp}$HMASTER_APP-0.$hbasemasterdomain"

    echo "      <property>" >> ${HBASE_SITE_FILE}
    echo "        <name>hbase.masters</name>" >> ${HBASE_SITE_FILE}
    echo "        <value>${hbktmp}</value>" >> ${HBASE_SITE_FILE}
    echo "        <description>List of master rpc end points for the hbase cluster.</description>" >> ${HBASE_SITE_FILE}
    echo "      </property>" >> ${HBASE_SITE_FILE}
    echo "    </configuration>" >> ${HBASE_SITE_FILE}
       
}

function mapred_config() {
    cp "${MAPRED_SITE_FILE}" "${MAPRED_SITE_FILE}_${DATETIME}"
    rm -f "${MAPRED_SITE_FILE}"
    cp "${MAPRED_SITE_FILE}.bk" "${MAPRED_SITE_FILE}"

    i=1

    echo "<configuration>" >> ${MAPRED_SITE_FILE}
    echo "<property>" >> ${MAPRED_SITE_FILE}
    echo "  <name>yarn.app.mapreduce.am.env</name>" >> ${MAPRED_SITE_FILE}
    echo "  <value>HADOOP_MAPRED_HOME=${HADOOP_HOME}</value>" >> ${MAPRED_SITE_FILE}
    echo "</property>" >> ${MAPRED_SITE_FILE}
    echo "<property>" >> ${MAPRED_SITE_FILE}
    echo "  <name>mapreduce.map.env</name>" >> ${MAPRED_SITE_FILE}
    echo "  <value>HADOOP_MAPRED_HOME=${HADOOP_HOME}</value>" >> ${MAPRED_SITE_FILE}
    echo "</property>" >> ${MAPRED_SITE_FILE}
    echo "<property>" >> ${MAPRED_SITE_FILE}
    echo "  <name>mapreduce.reduce.env</name>" >> ${MAPRED_SITE_FILE}
    echo "  <value>HADOOP_MAPRED_HOME=${HADOOP_HOME}</value>" >> ${MAPRED_SITE_FILE}
    echo "</property>" >> ${MAPRED_SITE_FILE}


    echo "<property>" >> ${MAPRED_SITE_FILE}
    echo "  <name>mapreduce.framework.name</name>" >> ${MAPRED_SITE_FILE}
    echo "  <value>yarn</value>" >> ${MAPRED_SITE_FILE}
    echo "</property>" >> ${MAPRED_SITE_FILE}

    echo "<property>" >> ${MAPRED_SITE_FILE}
    echo "  <name>mapreduce.jobhistory.address</name>" >> ${MAPRED_SITE_FILE}
    echo "  <value>${JOBHISTORY_APP}-$((i-1)).${jobhistorydomain}:${JOBHISTORY_PORT}</value>" >> ${MAPRED_SITE_FILE}
    echo "  <description>MapReduce JobHistory Server IPC host:port</description>" >> ${MAPRED_SITE_FILE}
    echo "</property>" >> ${MAPRED_SITE_FILE}
    echo "<property>" >> ${MAPRED_SITE_FILE}
    echo "  <name>mapreduce.jobhistory.webapp.address</name>" >> ${MAPRED_SITE_FILE}
    echo "  <value>${JOBHISTORY_APP}-$((i-1)).${jobhistorydomain}:${JOBHISTORY_WEBAPP_PORT}</value>" >> ${MAPRED_SITE_FILE}
    echo "  <description>MapReduce JobHistory Server Web UI host:port</description>" >> ${MAPRED_SITE_FILE}
    echo "</property>" >> ${MAPRED_SITE_FILE}
    echo "</configuration>" >> ${MAPRED_SITE_FILE}

}

function spark_conf() {
    cp "${SPARK_CONF_FILE}" "${SPARK_CONF_FILE}_${DATETIME}"
    rm -f "${SPARK_CONF_FILE}"
    cp "${SPARK_CONF_FILE}.bk" "${SPARK_CONF_FILE}"

    echo "spark.master                     yarn" >> ${SPARK_CONF_FILE}
    echo "spark.eventLog.enabled           true" >> ${SPARK_CONF_FILE}
    echo "spark.eventLog.dir               hdfs://${NAMESERVICE_ID}/sparkeventlog" >> ${SPARK_CONF_FILE}
    echo "spark.serializer                 org.apache.spark.serializer.KryoSerializer" >> ${SPARK_CONF_FILE}

}

function hive_conf() {

    cp "${HIVE_SITE_FILE}" "${HIVE_SITE_FILE}_${DATETIME}"
    rm -f "${HIVE_SITE_FILE}"
    cp "${HIVE_SITE_FILE}.bk" "${HIVE_SITE_FILE}"

    echo "    <configuration>" >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.metastore.warehouse.dir</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>/user/hive/warehouse</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>location of default database for the warehouse</description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>datanucleus.schema.autoCreateAll</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>false</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>Auto creates necessary schema on a startup if one doesn't exist. Set this to false, after creating it once.To enable auto create also set hive.metastore.schema.verification=false. Auto creation is not recommended for production use cases, run schematool command instead.</description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.metastore.schema.verification</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>true</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>" >> ${HIVE_SITE_FILE}
    echo "            Enforce metastore schema version consistency." >> ${HIVE_SITE_FILE}
    echo "            True: Verify that version information stored in is compatible with one from Hive jars.  Also disable automatic" >> ${HIVE_SITE_FILE}
    echo "                    schema migration attempt. Users are required to manually migrate schema after Hive upgrade which ensures" >> ${HIVE_SITE_FILE}
    echo "                    proper metastore schema migration. (Default)" >> ${HIVE_SITE_FILE}
    echo "            False: Warn if the version information stored in metastore doesn't match with one from in Hive jars." >> ${HIVE_SITE_FILE}
    echo "            </description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.hmshandler.retry.attempts</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>10</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>The number of times to retry a HMSHandler call if there were a connection error.</description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.hmshandler.retry.interval</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>2000ms</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>" >> ${HIVE_SITE_FILE}
    echo "            Expects a time value with unit (d/day, h/hour, m/min, s/sec, ms/msec, us/usec, ns/nsec), which is msec if not specified." >> ${HIVE_SITE_FILE}
    echo "            The time between HMSHandler retry attempts on failure." >> ${HIVE_SITE_FILE}
    echo "            </description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "       <property>" >> ${HIVE_SITE_FILE}
    echo "           <name>hive.stats.autogather</name>" >> ${HIVE_SITE_FILE}
    echo "           <value>true</value>" >> ${HIVE_SITE_FILE}
    echo "           <description>A flag to gather statistics (only basic) automatically during the INSERT OVERWRITE command.</description>" >> ${HIVE_SITE_FILE}
    echo "       </property>" >> ${HIVE_SITE_FILE}

    echo "       <property>" >> ${HIVE_SITE_FILE}
    echo "           <name>javax.jdo.option.ConnectionURL</name>" >> ${HIVE_SITE_FILE}
    echo "           <value>jdbc:mysql://${MYSQL_CLIENT}:${MYSQL_PORT}/metastore_db?createDatabaseIfNotExist=true&amp;ssl=false</value>" >> ${HIVE_SITE_FILE}
    echo "           <description>" >> ${HIVE_SITE_FILE}
    echo "           JDBC connect string for a JDBC metastore." >> ${HIVE_SITE_FILE}
    echo "           To use SSL to encrypt/authenticate the connection, provide database-specific SSL flag in the connection URL." >> ${HIVE_SITE_FILE}
    echo "           For example, jdbc:postgresql://myhost/db?ssl=true for postgres database." >> ${HIVE_SITE_FILE}
    echo "           </description>" >> ${HIVE_SITE_FILE}
    echo "       </property>" >> ${HIVE_SITE_FILE}
    echo "       <property>" >> ${HIVE_SITE_FILE}
    echo "           <name>javax.jdo.option.ConnectionDriverName</name>" >> ${HIVE_SITE_FILE}
    echo "           <value>com.mysql.jdbc.Driver</value>" >> ${HIVE_SITE_FILE}
    echo "           <description>Driver class name for a JDBC metastore</description>" >> ${HIVE_SITE_FILE}
    echo "       </property>" >> ${HIVE_SITE_FILE}
    echo "       <property>" >> ${HIVE_SITE_FILE}
    echo "           <name>javax.jdo.option.ConnectionUserName</name>" >> ${HIVE_SITE_FILE}
    echo "           <value>${MYSQL_USER}</value>" >> ${HIVE_SITE_FILE}
    echo "           <description>Username to use against metastore database</description>" >> ${HIVE_SITE_FILE}
    echo "       </property>" >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>javax.jdo.option.ConnectionPassword</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>${MYSQLPASSWORD}</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>password to use against metastore database</description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}

    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.zookeeper.quorum</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>${ZK_QUORUM}:${ZK_CLIENT_PORT}</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>" >> ${HIVE_SITE_FILE}
    echo "            List of ZooKeeper servers to talk to. This is needed for:" >> ${HIVE_SITE_FILE}
    echo "            1. Read/write locks - when hive.lock.manager is set to" >> ${HIVE_SITE_FILE}
    echo "            org.apache.hadoop.hive.ql.lockmgr.zookeeper.ZooKeeperHiveLockManager," >> ${HIVE_SITE_FILE}
    echo "            2. When HiveServer2 supports service discovery via Zookeeper." >> ${HIVE_SITE_FILE}
    echo "            3. For delegation token storage if zookeeper store is used, if" >> ${HIVE_SITE_FILE}
    echo "            hive.cluster.delegation.token.store.zookeeper.connectString is not set" >> ${HIVE_SITE_FILE}
    echo "            4. LLAP daemon registry service" >> ${HIVE_SITE_FILE}
    echo "            5. Leader selection for privilege synchronizer" >> ${HIVE_SITE_FILE}
    echo "            </description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.server2.support.dynamic.service.discovery</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>true</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>Whether HiveServer2 supports dynamic service discovery for its clients. To support this, each instance of HiveServer2 currently uses ZooKeeper to register itself, when it is brought up. JDBC/ODBC clients should use the ZooKeeper ensemble: hive.zookeeper.quorum in their connection string.</description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.server2.zookeeper.namespace</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>hiveserver2</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>The parent node in ZooKeeper used by HiveServer2 when supporting dynamic service discovery.</description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.server2.zookeeper.publish.configs</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>true</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>Whether we should publish HiveServer2's configs to ZooKeeper.</description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}

    echo "        <!-- " >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.compactor.initiator.on</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>true</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>" >> ${HIVE_SITE_FILE}
    echo "            Whether to run the initiator and cleaner threads on this metastore instance or not." >> ${HIVE_SITE_FILE}
    echo "            Set this to true on one instance of the Thrift metastore service as part of turning" >> ${HIVE_SITE_FILE}
    echo "            on Hive transactions. For a complete list of parameters required for turning on" >> ${HIVE_SITE_FILE}
    echo "            transactions, see hive.txn.manager." >> ${HIVE_SITE_FILE}
    echo "            </description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        -->" >> ${HIVE_SITE_FILE}

    echo "        <!-- " >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.compactor.worker.threads</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>3</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>" >> ${HIVE_SITE_FILE}
    echo "            How many compactor worker threads to run on this metastore instance. Set this to a" >> ${HIVE_SITE_FILE}
    echo "            positive number on one or more instances of the Thrift metastore service as part of" >> ${HIVE_SITE_FILE}
    echo "            turning on Hive transactions. For a complete list of parameters required for turning" >> ${HIVE_SITE_FILE}
    echo "            on transactions, see hive.txn.manager." >> ${HIVE_SITE_FILE}
    echo "            Worker threads spawn MapReduce jobs to do compactions. They do not do the compactions" >> ${HIVE_SITE_FILE}
    echo "            themselves. Increasing the number of worker threads will decrease the time it takes" >> ${HIVE_SITE_FILE}
    echo "            tables or partitions to be compacted once they are determined to need compaction." >> ${HIVE_SITE_FILE}
    echo "            It will also increase the background load on the Hadoop cluster as more MapReduce jobs" >> ${HIVE_SITE_FILE}
    echo "            will be running in the background." >> ${HIVE_SITE_FILE}
    echo "            </description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        -->" >> ${HIVE_SITE_FILE}    

    echo "        <!-- " >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.execution.engine</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>spark</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>" >> ${HIVE_SITE_FILE}
    echo "            Expects one of [mr, tez, spark]." >> ${HIVE_SITE_FILE}
    echo "            Chooses execution engine. Options are: mr (Map reduce, default), tez, spark. While MR" >> ${HIVE_SITE_FILE}
    echo "            remains the default engine for historical reasons, it is itself a historical engine" >> ${HIVE_SITE_FILE}
    echo "            and is deprecated in Hive 2 line. It may be removed without further warning." >> ${HIVE_SITE_FILE}
    echo "            </description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        -->" >> ${HIVE_SITE_FILE}

    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>spark.yarn.jars</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>hdfs://${NAMESERVICE_ID}/spark-jars/*</value>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}

    echo "    <property>" >> ${HIVE_SITE_FILE}
    echo "        <name>hive.spark.client.connect.timeout</name>" >> ${HIVE_SITE_FILE}
    echo "        <value>30000ms</value>" >> ${HIVE_SITE_FILE}
    echo "        <description>" >> ${HIVE_SITE_FILE}
    echo "        Expects a time value with unit (d/day, h/hour, m/min, s/sec, ms/msec, us/usec, ns/nsec), which is msec if not specified." >> ${HIVE_SITE_FILE}
    echo "        Timeout for remote Spark driver in connecting back to Hive client." >> ${HIVE_SITE_FILE}
    echo "        </description>" >> ${HIVE_SITE_FILE}
    echo "    </property>" >> ${HIVE_SITE_FILE}

    for (( i=1; i<=$SERVERS; i++ ))
    do
        hivetmp="thrift://$HIVE_APP-$((i-1)).$hiveserverdomain:$HIVE_SERVER2_PORT,${hivetmp}"
    done    
    hivetmp=`echo ${hivetmp} | sed 's/,$//g'`

    echo "        <!-- client node -->" >> ${HIVE_SITE_FILE}
    echo "        <!-- " >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.metastore.uris</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>${hivetmp}</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>Thrift URI for the remote metastore. Used by metastore client to connect to remote metastore.</description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        -->" >> ${HIVE_SITE_FILE}

    echo "        <!-- " >> ${HIVE_SITE_FILE}    
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.support.concurrency</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>true</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>" >> ${HIVE_SITE_FILE}
    echo "            Whether Hive supports concurrency control or not." >> ${HIVE_SITE_FILE}
    echo "            A ZooKeeper instance must be up and running when using zookeeper Hive lock manager" >> ${HIVE_SITE_FILE}
    echo "            </description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        -->" >> ${HIVE_SITE_FILE}

    echo "        <!-- " >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.exec.dynamic.partition.mode</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>nonstrict</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>" >> ${HIVE_SITE_FILE}
    echo "            In strict mode, the user must specify at least one static partition" >> ${HIVE_SITE_FILE}
    echo "            in case the user accidentally overwrites all partitions." >> ${HIVE_SITE_FILE}
    echo "            In nonstrict mode all partitions are allowed to be dynamic." >> ${HIVE_SITE_FILE}
    echo "            </description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        -->" >> ${HIVE_SITE_FILE}

    echo "        <!-- " >> ${HIVE_SITE_FILE}
    echo "        <property>" >> ${HIVE_SITE_FILE}
    echo "            <name>hive.txn.manager</name>" >> ${HIVE_SITE_FILE}
    echo "            <value>org.apache.hadoop.hive.ql.lockmgr.DbTxnManager</value>" >> ${HIVE_SITE_FILE}
    echo "            <description>" >> ${HIVE_SITE_FILE}
    echo "            Set to org.apache.hadoop.hive.ql.lockmgr.DbTxnManager as part of turning on Hive" >> ${HIVE_SITE_FILE}
    echo "            transactions, which also requires appropriate settings for hive.compactor.initiator.on," >> ${HIVE_SITE_FILE}
    echo "            hive.compactor.worker.threads, hive.support.concurrency (true)," >> ${HIVE_SITE_FILE}
    echo "            and hive.exec.dynamic.partition.mode (nonstrict)." >> ${HIVE_SITE_FILE}
    echo "            The default DummyTxnManager replicates pre-Hive-0.13 behavior and provides" >> ${HIVE_SITE_FILE}
    echo "            no transactions." >> ${HIVE_SITE_FILE}
    echo "            </description>" >> ${HIVE_SITE_FILE}
    echo "        </property>" >> ${HIVE_SITE_FILE}
    echo "        -->" >> ${HIVE_SITE_FILE}

    echo "    </configuration>" >> ${HIVE_SITE_FILE}

}

function cp_site() {

    mkdir -p ${MNT_BK_DIR}
    mv /mnt/hadoop ${MNT_BK_DIR} 
    mv /mnt/hbase_conf ${MNT_BK_DIR}
    mv /mnt/spark_conf ${MNT_BK_DIR}
    mv /mnt/hive_conf ${MNT_BK_DIR}

    cp -r ${HADOOP_CONF_DIR} /mnt
    cp -r ${HBASE_CONF_DIR} /mnt/hbase_conf
    cp -r ${SPARK_CONF_DIR} /mnt/spark_conf
    cp -r ${HIVE_CONF_DIR} /mnt/hive_conf

    ln -s ${HDFS_SITE_FILE} /mnt/hbase_conf/hdfs-site.xml
    ln -s ${CORE_SITE_FILE} /mnt/hbase_conf/core-site.xml
    ln -s ${YARN_SITE_FILE} /mnt/hbase_conf/yarn-site.xml
    ln -s ${MAPRED_SITE_FILE} /mnt/hbase_conf/mapred-site.xml
    
}

function lock_file () {
  touch "${SITE_LOCK_FILE}"
}

hdfs_config && yarn_config && mapred_config && hbase_config && spark_conf && hive_conf && cp_site && lock_file && startService
