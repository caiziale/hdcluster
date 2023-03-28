#/bin/bash

# HDCluster
#
# Copyright 2023 the author.
# @author caizi

echo "****** Get containers IP ******"
echo ""
for i in {0..1}; do echo "zk-${i}..."; kubectl exec -it zk-"${i}" -- ifconfig|grep inet|grep -v 127.0.0.1|awk '{print $2}'; sleep 1; done
echo "----------"
for i in {0..2}; do echo "journal-${i}..."; kubectl exec -it journal-"$i" -- ifconfig|grep inet|grep -v 127.0.0.1|awk '{print $2}'; sleep 1; done
echo "----------"
for i in {0..2}; do echo "namenode-${i}..."; kubectl exec -it namenode-"$i" -- ifconfig|grep inet|grep -v 127.0.0.1|awk '{print $2}'; sleep 1; done
echo "----------"
for i in {0..2}; do echo "resourcemanager-${i}..."; kubectl exec -it resourcemanager-"$i" -- ifconfig|grep inet|grep -v 127.0.0.1|awk '{print $2}'; sleep 1; done
echo "----------"
echo "jobhistory-0..."
kubectl exec -it jobhistory-0 -- ifconfig|grep inet|grep -v 127.0.0.1|awk '{print $2}'
echo "----------"
for i in {0..1}; do echo "datanode-${i}..."; kubectl exec -it datanode-"${i}" -- ifconfig|grep inet|grep -v 127.0.0.1|awk '{print $2}'; sleep 1;done
echo "----------"
echo "hbasemaster-0..."
kubectl exec -it hbasemaster-0 -- ifconfig|grep inet|grep -v 127.0.0.1|awk '{print $2}'
for i in {0..2}; do echo "hbasebkmaster-${i}..."; kubectl exec -it hbasebkmaster-"${i}" -- ifconfig|grep inet|grep -v 127.0.0.1|awk '{print $2}';done
for i in {0..1}; do echo "hbaseregionserver-${i}..."; kubectl exec -it hbaseregionserver-"${i}" -- ifconfig|grep inet|grep -v 127.0.0.1|awk '{print $2}';done
echo "----------"
for i in {0..1}; do echo "hive-${i}..."; kubectl exec -it hive-"${i}" -- ifconfig|grep inet|grep -v 127.0.0.1|awk '{print $2}';done

