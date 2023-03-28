#/bin/bash

# HDCluster
#
# Copyright 2023 the author.
# @author caizi

#--pwd dir
pdir=`dirname "$0"`
pdir=`cd "$pdir">/dev/null; pwd`

YAML_DIR="$pdir/yaml"

echo "Checking commands required by script..."
  function isCmdExist() {
    cmd=$1
    type ${cmd} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      printf "This script requires the \033[0;35;40m%s\033[0m command, but it is not installed. Aborting...\n" ${cmd}
      exit 1
    fi
  }

isCmdExist md5sum
isCmdExist envsubst

#-- generated mysql password --
echo "-------- MySQL parameter initialization --------"
UUID=`cat /proc/sys/kernel/random/uuid`
TIMESTAMP=`date +%s%N`
RANDOMTMP=`echo ${UUID}${TIMESTAMP}|md5sum|head -c 12`

export MYSQL_PASSWORD=${RANDOMTMP}

printf ".......... Mysql username:\033[0;35;40m%s\033[0m\n" "root"
printf ".......... Mysql password:\033[0;35;40m%s\033[0m\n" ${MYSQL_PASSWORD}

echo "****** Create the containers cluster ******"

#--site
echo "------ Create Site container..."
kubectl apply -f ${YAML_DIR}/nfsclaim.yaml
sleep 10
envsubst < ${YAML_DIR}/hsite.yaml| kubectl apply -f -
sleep 30 

#--mysql
echo "------ Create Mysql container..."
envsubst < ${YAML_DIR}/hmysql8.yaml|kubectl apply -f -
sleep 20


#--zk
echo "------ Create ZK containers..."
kubectl apply -f ${YAML_DIR}/hzk.yaml
sleep 60


#--journal
echo "------ Create Journal containers..."
kubectl apply -f ${YAML_DIR}/hjournal.yaml
sleep 90

#--yarn(resourcemanager)
echo "------ Create Resourcemanager container..."
kubectl apply -f ${YAML_DIR}/hyarn.yaml
sleep 30

#--namenode
echo "------ Create Namenode container..."
kubectl apply -f ${YAML_DIR}/hnamenode.yaml
sleep 120

#--yarn(resourcemanager)
echo "------ Create Resourcemanager remaining containers..."
 while true;
 do
   kubectl exec -it resourcemanager-0 -- sh -c "yarn rmadmin -getAllServiceState|grep -E \"active\""
   if [ $? -eq 0 ]; then
      break;
   fi
   echo "Waiting for resourcemanager-0 startup to complete..."
   sleep 5;
 done
kubectl scale --replicas=3 statefulset resourcemanager
sleep 30

#--namenode
echo "------ Create Namenode remaining containers..."
 while true;
 do
   kubectl exec -it namenode-0 -- sh -c "hdfs haadmin -getAllServiceState|grep -E \"active\""
   if [ $? -eq 0 ]; then
      break;
   fi
   echo "Waiting for namenode-0 startup to complete..."
   sleep 5;
 done
kubectl scale --replicas=3 statefulset namenode
sleep 150

#--jobhistory
echo "------ Create Jobhistory container..."
kubectl apply -f ${YAML_DIR}/hjobhistory.yaml
sleep 30

#--datanode
echo "------ Create Datanode containers..."
kubectl apply -f ${YAML_DIR}/hdatanode.yaml
sleep 120

#--hbasemaster
echo "------ Create Hbasemaster container..."
kubectl apply -f ${YAML_DIR}/h_hbasemaster.yaml
sleep 30

#--hbasebkmaster
echo "------ Create Hbasebkmaster containers..."
kubectl apply -f ${YAML_DIR}/h_hbasebkmaster.yaml
sleep 90

#--hbaseregionserver
echo "------ Create Hbaseregionserver containers..."
kubectl apply -f ${YAML_DIR}/h_hbaseregionserver.yaml
sleep 90

#--hive
echo "------ Create Hive containers..."
kubectl apply -f ${YAML_DIR}/h_hive.yaml
sleep 360

