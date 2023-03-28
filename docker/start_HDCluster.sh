#/bin/bash

# HDCluster
#
# Copyright 2023 the author.
# @author caizi

echo "****** Start the container cluster ******"
#-- site
echo "------ Start Site container..."
docker start site-0

#--mysql
echo "------ Start Mysql container..."
docker start mysql-cs

#--zk
echo "------ Start ZK containers..."
for i in {0..2}; do docker start zk-"${i}"; done
sleep 10

#--journal
echo "------ Start Journal containers..."
for i in {0..2}; do docker start journal-"$i"; done
sleep 20

#--namenode
echo "------ Start Namenode  containers..."
for i in {0..2}; do docker start namenode-"$i";sleep 30; done

#--yarn(resourcemanager)
echo "------ Start Resourcemanager containers..."
for i in {0..2}; do docker start resourcemanager-"$i";sleep 30; done

#--jobhistory
echo "------ Start Jobhistory container..."
docker start jobhistory-0
sleep 10

#--datanode
echo "------ Start Datanode containers..."
for i in {0..2}; do docker start datanode-"${i}"; done
sleep 30

#--hbasemaster
echo "------ Start Hbasemaster container..."
docker start hbasemaster-0
sleep 10
#--hbasebkmaster
echo "------ Start Hbasebkmaster containers..."
for i in {0..2}; do docker start hbasebkmaster-"${i}"; done
sleep 10
#--hbaseregionserver
echo "------ Start Hbaseregionserver containers..."
for i in {0..2}; do docker start hbaseregionserver-"${i}"; done
sleep 10

#--hive
echo "------ Start Hive containers..."
for i in {0..1}; do docker start hive-"${i}"; sleep 60; done

