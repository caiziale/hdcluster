#/bin/bash

# HDCluster
#
# Copyright 2023 the author.
# @author caizi

echo "****** Show containers info ******"

for i in {0..2}; do echo "zk-${i}..."; kubectl exec "zk-$i" -- sh -c "netstat -ant"; sleep 1; done
for i in {0..2}; do echo "journal-${i}..."; kubectl exec journal-"$i" -- sh -c "netstat -ant"; sleep 1; done

kubectl exec namenode-0 -- sh -c "hdfs haadmin -getAllServiceState"
kubectl exec resourcemanager-0 -- sh -c "yarn rmadmin -getAllServiceState"

echo "jobhistory-0..."
kubectl exec jobhistory-0 -- sh -c "netstat -ant"

for i in {0..1}; do echo "datanode-${i}..."; kubectl exec datanode-"${i}" -- sh -c "/opt/software/java-se-8u42-ri/bin/jps|grep -v Jps"; done

echo "hbasemaster-0..."
kubectl exec -it hbasemaster-0 -- sh -c "/opt/software/java-se-8u42-ri/bin/jps|grep -v Jps"
for i in {0..2}; do echo "hbasebkmaster-${i}..."; kubectl exec -it hbasebkmaster-"${i}" -- sh -c "/opt/software/java-se-8u42-ri/bin/jps|grep -v Jps";done
for i in {0..1}; do echo "hbaseregionserver-${i}..."; kubectl exec -it hbaseregionserver-"${i}" -- sh -c "/opt/software/java-se-8u42-ri/bin/jps|grep -v Jps";done

for i in {0..1}; do echo "hive-${i}..."; kubectl exec -it hive-"${i}" -- sh -c "netstat -ant|grep -E '9083|10000|10002'";done

