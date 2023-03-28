#/bin/bash

# HDCluster
#
# Copyright 2023 the author.
# @author caizi

echo "****** Stop the containers cluster ******"

#--hive
echo "------ Stop Hive containers..."
for i in {0..1}; do docker stop hive-"${i}"; done

#--hbasemaster
echo "------ Stop Hbasemaster container..."
docker stop hbasemaster-0
#--hbasebkmaster
echo "------ Stop Hbasebkmaster containers..."
for i in {0..2}; do docker stop hbasebkmaster-"${i}"; done
#--hbaseregionserver
echo "------ Stop Hbaseregionserver containers..."
for i in {0..2}; do docker stop hbaseregionserver-"${i}"; done

#--datanode
echo "------ Stop Datanode containers..."
for i in {0..2}; do docker stop datanode-"${i}"; done

#--namenode
echo "------ Stop Namenode  containers..."
for i in {0..2}; do docker stop namenode-"$i"; done

#--yarn(resourcemanager)
echo "------ Stop Resourcemanager containers..."
for i in {0..2}; do docker stop resourcemanager-"$i"; done

#--journal
echo "------ Stop Journal containers..."
for i in {0..2}; do docker stop journal-"$i"; done

#--jobhistory
echo "------ Stop Jobhistory container..."
docker stop jobhistory-0

#--mysql
echo "------ Stop Mysql container..."
docker stop mysql-cs

#--zk
echo "------ Stop ZK containers..."
for i in {0..2}; do docker stop zk-"${i}"; done

#-- site
echo "------ Stop Site container..."
docker stop site-0

