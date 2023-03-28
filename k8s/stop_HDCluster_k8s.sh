#/bin/bash

# HDCluster
#
# Copyright 2023 the author.
# @author caizi

echo "****** Stop the containers cluster ******"
kubectl scale --replicas=0 statefulset hive
kubectl scale --replicas=0 statefulset hbaseregionserver
kubectl scale --replicas=0 statefulset hbasebkmaster
kubectl scale --replicas=0 statefulset hbasemaster

kubectl scale --replicas=0 statefulset datanode
kubectl scale --replicas=0 statefulset jobhistory

kubectl scale --replicas=0 statefulset namenode
kubectl scale --replicas=0 statefulset resourcemanager

kubectl scale --replicas=0 statefulset journal

kubectl scale --replicas=0 statefulset zk
kubectl scale --replicas=0 statefulset mysql

kubectl scale --replicas=0 statefulset site



