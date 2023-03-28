#/bin/bash

# HDCluster
#
# Copyright 2023 the author.
# @author caizi

echo "****** Start the containers cluster ******"
#-- site
echo "------ Start Site container..."
kubectl scale --replicas=1 statefulset site
sleep 10 

#--mysql
echo "------ Start Mysql container..."
kubectl scale --replicas=1 statefulset mysql
sleep 10

#--zk
echo "------ Start ZK containers..."
kubectl scale --replicas=3 statefulset zk
sleep 60

#--journal
echo "------ Start Journal containers..."
kubectl scale --replicas=3 statefulset journal
sleep 60

#--yarn(resourcemanager)
echo "------ Start Resourcemanager container..."
kubectl scale --replicas=1 statefulset resourcemanager
sleep 20

#--namenode
echo "------ Start Namenode  container..."
kubectl scale --replicas=1 statefulset namenode
sleep 80

#--yarn(resourcemanager)
echo "------ Start Resourcemanager remaining containers..."
 while true;
 do
   kubectl exec -it resourcemanager-0 -- sh -c "yarn rmadmin -getAllServiceState|grep -E \"active\""
   if [ $? -eq 0 ]; then
      break;
   fi
   sleep 5;
   echo "Waiting for resourcemanager-0 startup to complete..."
 done
kubectl scale --replicas=3 statefulset resourcemanager
sleep 20

#--namenode
echo "------ Start Namenode remaining containers..."
 while true;
 do
   kubectl exec -it namenode-0 -- sh -c "hdfs haadmin -getAllServiceState|grep -E \"active\""
   if [ $? -eq 0 ]; then
      break;
   fi
   sleep 5;
   echo "Waiting for namenode-0 startup to complete..."
 done
kubectl scale --replicas=3 statefulset namenode
sleep 90

#--jobhistory
echo "------ Start Jobhistory container..."
kubectl scale --replicas=1 statefulset jobhistory
sleep 30

#--datanode
echo "------ Start Datanode containers..."
kubectl scale --replicas=2 statefulset datanode
sleep 90

#--hbasemaster
echo "------ Start Hbasemaster container..."
kubectl scale --replicas=1 statefulset hbasemaster
sleep 50

#--hbasebkmaster
echo "------ Start Hbasebkmaster containers..."
kubectl scale --replicas=3 statefulset hbasebkmaster
sleep 60

#--hbaseregionserver
echo "------ Start Hbaseregionserver containers..."
kubectl scale --replicas=2 statefulset hbaseregionserver
sleep 80

#--hive
echo "------ Start Hive containers..."
kubectl scale --replicas=2 statefulset hive
sleep 360

