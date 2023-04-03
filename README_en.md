### HDCluster integrates several distributed computing systems and databases, packages them into a single image, and provides scripts for automatically creating related clusters. The scripts provided can quickly build container based distributed system clusters.

###### HDCluster includes the following systems: Apache Hadoop,Apache HBase,Apache Spark,Apache Hive,Apache ZooKeeper.

## **HDCluster This image is a beta version and is only used for learning and testing**

# How to use this image

[Download HDCluster related scripts](https://github.com/caiziale/hdcluster)

Base image: FROM ubuntu:22.04

Time zone within the image: ENV TZ=Asia/Shanghai

---

##### **Docker Version**

* docker Server Version: `20.10.18`
* Creating an HDCluster cluster system

```
$ ./create_HDCluster.sh
```

> The script will automatically generate a 'mysql' password and print it to the screen. You can also use your own password instead.
>
> ```
> $ cat ./create_HDCluster.sh
> ...
> MYSQL_PASSWORD=${RANDOMTMP}
> ...
> ```

This script creates the following containers:

| Container Name                                              | Description                                                                 | Default container number |
| ----------------------------------------------------------- | --------------------------------------------------------------------------- | ------------------------ |
| site -0                                                     | A data volume container that holds configuration files for multiple systems | 1                        |
| mysql-cs                                                    | Apache Hive metadata                                                       | 1                        |
| zk-0,zk-1,zk-2                                              | HA support for several systems                                              | 3                        |
| journal-0,journal-1,journal-2                               | Apache Hadoop nodes,Support for HDFS HA                                     | 3                        |
| namenode-0,namenode-1,namenode-2                            | Apache Hadoop nodes,Support for HDFS HA                                     | 3                        |
| resourcemanager-0,resourcemanager-1,resourcemanager-2       | Apache Hadoop nodes,Support for YARN's ResourceManager HA                   | 3                        |
| jobhistory-0                                                | Apache Hadoop nodes                                                         | 1                        |
| datanode-0,datanode-1,datanode-2                            | Apache Hadoop nodes,With NodeManager                                        | 3                        |
| hbasemaster-0                                               | HMaster node of Apache HBase                                                | 1                        |
| hbasebkmaster-0,hbasebkmaster-1,hbasebkmaster-2             | Backup HMaster node of Apache HBase                                        | 3                        |
| hbaseregionserver-0,hbaseregionserver-1,hbaseregionserver-2 | HRegionServer node of Apache HBase                                          | 3                        |
| hive-0,hive-1                                               | Apache Hive nodes                                                           | 2                        |

> A total of 27 containers have been created. Note, If the host computer(Server running docker) does not have enough memory, the container creation may not succeed or the container may restart.
>
> It is recommended that the host(Server running docker) memory be greater than 18G.

* Stop the HDCluster clustered system

```
$ ./stop_HDCluster.sh
```

* Starting the HDCluster cluster system

```
$ ./start_HDCluster.sh
```

* View HDCluster container cluster IP

```
$ ./check_HDCluster_ip.sh
```

* Related container http port

| Service name     | Protocol | Port  | Container Name      |
| ---------------- | -------- | ----- | ------------------- |
| NameNode         | http     | 9870  | namenode-0          |
| ResourceManager  | http     | 8088  | resourcemanager-0   |
| JobHistoryServer | http     | 19888 | jobhistory-0        |
| NodeManager      | http     | 8042  | datanode-0          |
| DataNode         | http     | 9864  | datanode-0          |
| HMaster          | http     | 16010 | hbasemaster-0       |
| HMaster          | http     | 16010 | hbasebkmaster-0     |
| HRegionServer    | http     | 16030 | hbaseregionserver-0 |
| hiveserver2      | http     | 10002 | hive-0              |

* mysql client connection

```
$ docker run -it --rm --net hadoop mysql:8.0.31 mysql -hmysql-cs -uroot -p
```

##### Kubernetes version

* k8s Server Version `1.25.2` (docker Server Version `20.10.21`)
* Storage Classes

[Kubernetes doesn&#39;t include an internal NFS provisioner. You need to use an external provisioner to create a StorageClass for NFS.](https://kubernetes.io/docs/concepts/storage/storage-classes/#nfs "NFS Storage Classes")

[NFS subdir external provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)

```
$ cd nfs-subdir-external-provisioner/deploy/
$ cat kustomization.yaml

resources:
  - class.yaml
  - rbac.yaml
  - deployment.yaml

```

> First, you need to have the connection information for the ***NFS server***
>
> **Modify deployment.yaml** `<YOUR_NFS_SERVER_IP>` and `<YOUR_NFS_SERVER_SHARE>`, [Please refer to README.md (Step 1 and Step 4) for NFS subdir](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner#with-kustomize)

Please execute in sequence

```
$ kubectl apply -f ./class.yaml
$ kubectl apply -f ./rbac.yaml
$ kubectl apply -f ./deployment.yaml
```

* Download Image

```
docker pull caiziale/hdcluster:1.0.0.Beta
```

> Please download the image on the "node" where the service needs to be deployed in advance(size: 3.05GB).

* Create an HDCluster cluster system

```
$ ./create_HDCluster_k8s.sh     #Execute on the control plane node (master node)
```

> 1. You can modify the script before executing it, for example:
>
>    1.1 modify `sleep 90`为 `sleep 60`
>
>    1.2 `cat hnamenode.yaml |grep -E 'startupProbe|livenessProbe|periodSeconds|failureThreshold'`  #Modify test time, etc
>
>    1.3 `cat hdatanode.yaml |grep -E 'storage'`    #Modify persistent volume size
>
>    1.4 The total storage size of the `persistent volume (pv)` of all containers in the HDCluster cluster is `16.4Gi`

> 2. The script will automatically generate a 'mysql' password and print it to the screen. You can also use your own password instead.
>
> ```
> $ cat ./create_HDCluster_k8s.sh
> ...
> export MYSQL_PASSWORD=${RANDOMTMP}
> ...
> ```

This script creates the following containers:

| Container Name                                        | Description                                                                 | Default container number | pv size | pv number |
| ----------------------------------------------------- | --------------------------------------------------------------------------- | ------------------------ | ------- | --------- |
| site-0                                                | A data volume container that holds configuration files for multiple systems | 1                        | 500Mi   | 1         |
| mysql-0                                               | Apache Hive metadata                                                       | 1                        | 5Gi     | 1         |
| zk-0,zk-1,zk-2                                        | HA support for several systems                                              | 3                        | 100Mi   | 3         |
| journal-0,journal-1,journal-2                         | Apache Hadoop nodes,Support for HDFS HA                                     | 3                        | 100Mi   | 3         |
| namenode-0,namenode-1,namenode-2                      | Apache Hadoop nodes,Support for HDFS HA                                     | 3                        | 100Mi   | 3         |
| resourcemanager-0,resourcemanager-1,resourcemanager-2 | Apache Hadoop nodes,Support for YARN's ResourceManager HA                   | 3                        |         |           |
| jobhistory-0                                          | Apache Hadoop nodes                                                         | 1                        |         |           |
| datanode-0,datanode-1                                 | Apache Hadoop nodes,With NodeManager                                       | 2                        | 5Gi     | 2         |
| hbasemaster-0                                         | HMaster node of Apache HBase                                                | 1                        |         |           |
| hbasebkmaster-0,hbasebkmaster-1,hbasebkmaster-2       | Backup HMaster node of Apache HBase                                        | 3                        |         |           |
| hbaseregionserver-0,hbaseregionserver-1               | HRegionServer node of Apache HBase                                          | 2                        |         |           |
| hive-0,hive-1                                         | Apache Hive nodes                                                           | 2                        |         |           |

> Note, memory of the K8S node. If the node memory is insufficient, container creation may fail or container restart may occur.

* Stop the HDCluster clustered system

```
$ ./stop_HDCluster_k8s.sh      #Execute on the control plane node (master node)
```

* Starting the HDCluster cluster system

```
$ ./start_HDCluster_k8s.sh     #Execute on the control plane node (master node)
```

> You can also modify the script before executing it.
>
> Example: Modify `sleep 90`为 `sleep 60`

* View HDCluster container cluster ip

```
$ ./check_HDCluster_ip_k8s.sh     #Execute on the control plane node (master node)
```

* Port of the relevant container

```
$ kubectl get svc     #Execute on the control plane node (master node)
```

* View container logs

```
$ kubectl logs -f pods/datanode-0
```

* MySQL client connection

```
$ kubectl exec -it mysql-0 -- mysql -hmysql-cs -uroot -p
```

> Set the number of mysql connections. 
>
> Note, the number of connections set will become invalid after restarting the mysql-0 container.

```
$ kubectl exec -it mysql-0 -- mysql -hmysql-cs -uroot -p -e "set global max_connections=1000;set global max_user_connections=300;"
$ kubectl exec -it mysql-0 -- mysql -hmysql-cs -uroot -p -e "show variables like '%connections%'"
```

---

##### Test code:

* HBase

```
$ docker exec -it datanode-0 /bin/bash
$ hbase shell
$ hbase:001:0> list
$ hbase:002:0> create 'test', 'cf'
$ hbase:003:0> put 'test', 'row1', 'cf:a', 'value1'
$ hbase:004:0> scan 'test'
$ hbase:005:0> get 'test', 'row1'
$ hbase:006:0> quit
```

* Spark

```
$ docker exec -it datanode-0 /bin/bash
$ cd /opt/software/spark-3.3.1-bin-hadoop3/
$ ./bin/spark-submit --class org.apache.spark.examples.SparkPi \
    --master yarn \
    --deploy-mode cluster \
    --queue root.yarn \
    ./examples/jars/spark-examples*.jar \
    3
```

```
$ docker exec -it datanode-0 /bin/bash
$ cd /opt/software/spark-3.3.1-bin-hadoop3/
$ hdfs dfs -put ./README.md /user/root
$ hdfs dfs -put ./examples/src/main/resources/people.json /user/root
$ hdfs dfs -put ./examples/src/main/resources/people.txt /user/root
$ ./bin/spark-shell --queue root.yarn --driver-class-path ${HIVE_HOME}/lib/mysql-connector-j-8.0.31.jar
$ scala>
$ scala> import org.apache.spark.sql.SparkSession
$ scala> val spark = SparkSession.builder().appName("Spark SQL basic example").config("spark.some.config.option", "some-value").getOrCreate()
$ scala> val df = spark.read.json("people.json")
$ scala> df.show()
$ scala> 
$ scala> import spark.implicits._
$ scala> df.printSchema()
$ scala> df.select("name").show()
$ scala> 
$ scala> df.createOrReplaceTempView("people")
$ scala> val sqlDF = spark.sql("SELECT * FROM people")
$ scala> sqlDF.show()
```

```
$ scala> //#Spark SQL also supports reading and writing data stored in Apache Hive (Hive Tables)
$ scala> import java.io.File
$ scala> import org.apache.spark.sql.{Row, SaveMode, SparkSession}
$ scala> case class Record(key: Int, value: String)
$ scala> // warehouseLocation points to the default location for managed databases and tables
$ scala> val warehouseLocation = new File("spark-warehouse").getAbsolutePath
$ scala> val spark = SparkSession.builder().appName("Spark Hive Example").config("spark.sql.warehouse.dir", warehouseLocation).enableHiveSupport().getOrCreate()
$ scala> import spark.implicits._
$ scala> import spark.sql
$ scala> sql("CREATE TABLE IF NOT EXISTS src (key INT, value STRING) USING hive")
$ scala> sql("LOAD DATA LOCAL INPATH 'examples/src/main/resources/kv1.txt' INTO TABLE src")
$ scala> // Queries are expressed in HiveQL
$ scala> sql("SELECT * FROM src").show()
$ scala> sql("SELECT COUNT(*) FROM src").show()
$ scala> :quit
```

> Please view the `'src'` table in `Hive`

* Hive

```
$ docker exec -it datanode-0 /bin/bash
$ $HIVE_HOME/bin/beeline
$ beeline> !connect jdbc:hive2://zk-0:2181,zk-1:2181,zk-2:2181/;serviceDiscoveryMode=zooKeeper;zooKeeperNamespace=hiveserver2?mapreduce.job.queuename=root.yarn
$ Enter username for jdbc:hive2://zk-0:2181,zk-1:2181,zk-2:2181/:root
$ Enter password for jdbc:hive2://zk-0:2181,zk-1:2181,zk-2:2181/:
$ 0: jdbc:hive2://zk-0:2181,zk-1:2181,zk-2:2181> CREATE TABLE pokes2 (foo INT, bar STRING);
$ 0: jdbc:hive2://zk-0:2181,zk-1:2181,zk-2:2181> LOAD DATA LOCAL INPATH '/opt/software/apache-hive-3.1.3-bin/examples/files/kv1.txt' OVERWRITE INTO TABLE pokes2;
$ 0: jdbc:hive2://zk-0:2181,zk-1:2181,zk-2:2181> select * from pokes2;
$ 0: jdbc:hive2://zk-0:2181,zk-1:2181,zk-2:2181>
$ 0: jdbc:hive2://zk-0:2181,zk-1:2181,zk-2:2181> select * from src;
```

* Hive HBase Integration

```
$ 0: jdbc:hive2://zk-0:2181,zk-1:2181,zk-2:2181> CREATE TABLE hbase_table_1(key int, value1 string, value2 int, value3 int) 
STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
WITH SERDEPROPERTIES (
"hbase.columns.mapping" = ":key,a:b,a:c,d:e"
);

$ 0: jdbc:hive2://zk-0:2181,zk-1:2181,zk-2:2181> INSERT OVERWRITE TABLE hbase_table_1 SELECT foo, bar, foo+1, foo+2 FROM pokes2 WHERE foo=98 OR foo=100;
$ 0: jdbc:hive2://zk-0:2181,zk-1:2181,zk-2:2181> show tables;
$ 0: jdbc:hive2://zk-0:2181,zk-1:2181,zk-2:2181> !quit
```

```
$ hbase shell
$ hbase:001:0> list
$ hbase:002:0> describe "hbase_table_1"
$ hbase:003:0> scan "hbase_table_1"
$ hbase:004:0> quit
```

> Kubernetes version, Replace `"zk-0:2181,zk-1:2181,zk-2:2181"` with `"zk-cs:2181"`

###### Note:

`In the hive test environment, username is root and password is empty.`

`hive.execution.engine=mr`

```
yarn-site.xml #The attributes describing each queue in the file
...
<property>
  <name>yarn.scheduler.fair.allocation.file</name>
...

```

---

###### Shared location of system configuration files related to Hadoop, HBase, Spark, and Hive:

```
$ docker exec -it site-0 /bin/bash
$ cd /mnt
$ ls -la
```

These four directories `hadoop, hbase_ conf,hive_ conf,spark_ Conf` contains the configuration file for the relevant system.

