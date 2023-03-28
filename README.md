### HDCluster整合了几种分布式的计算系统与数据库,将它们打包成一个镜像并且提供了自动创建相关集群的脚本,通过提供的脚本可以快速的搭建以容器为基础的分布式系统集群.

###### HDCluster包括以下几种系统:Apache Hadoop,Apache HBase,Apache Spark,Apache Hive,Apache ZooKeeper.

## **HDCluster此镜像为测试版本,仅用于学习与测试**

# 如何使用此镜像

[下载HDCluster相关脚本](https://github.com/caiziale/hdcluster)

基础镜像: FROM ubuntu:22.04

镜像内的时区: ENV TZ=Asia/Shanghai

---

##### **Docker版本**

* 创建HDCluster集群系统:

```
$ ./create_HDCluster.sh
```

> 脚本会自动生成 `mysql`密码并打印到屏幕上, 您也可以用自己的密码来代替.
>
> ```
> $ cat ./create_HDCluster.sh
> ...
> MYSQL_PASSWORD=${RANDOMTMP}
> ...
> ```

此脚本会创建以下容器:

| 容器名称                                                    | 作用                                                  | 默认创建容器数量 |
| ----------------------------------------------------------- | ----------------------------------------------------- | ---------------- |
| site -0                                                     | 为数据卷容器,保存着多个系统的配置文件                 | 1                |
| mysql-cs                                                    | 为Apache Hive提供元数据支持                           | 1                |
| zk-0,zk-1,zk-2                                              | 为几种系统提供HA支持                                  | 3                |
| journal-0,journal-1,journal-2                               | Apache Hadoop节点,为HDFS HA提供支持                   | 3                |
| namenode-0,namenode-1,namenode-2                            | Apache Hadoop节点,为HDFS HA提供支持                   | 3                |
| resourcemanager-0,resourcemanager-1,resourcemanager-2       | Apache Hadoop节点,为YARN's ResourceManager HA提供支持 | 3                |
| jobhistory-0                                                | Apache Hadoop节点                                     | 1                |
| datanode-0,datanode-1,datanode-2                            | Apache Hadoop节点,含NodeManager                       | 3                |
| hbasemaster-0                                               | Apache HBase的HMaster节点                             | 1                |
| hbasebkmaster-0,hbasebkmaster-1,hbasebkmaster-2             | Apache HBase的Backup HMaster节点                      | 3                |
| hbaseregionserver-0,hbaseregionserver-1,hbaseregionserver-2 | Apache HBase的HRegionServer节点                       | 3                |
| hive-0,hive-1                                               | Apache Hive节点                                       | 2                |

> 总共创建27台容器,请注意宿主机的内存,如果宿主机内存不够可能导致容器创建不成功或造成容器重启.
>
> 推荐宿主机内存大于18G.

* 停止HDCluster集群系统:

```
$ ./stop_HDCluster.sh
```

* 启动HDCluster集群系统:

```
$ ./start_HDCluster.sh
```

* 查看HDCluster容器集群IP

```
$ ./check_HDCluster_ip.sh
```

* 相关容器http端口

| 服务名称         | 协议 | 端口  | 容器名称            |
| ---------------- | ---- | ----- | ------------------- |
| NameNode         | http | 9870  | namenode-0          |
| ResourceManager  | http | 8088  | resourcemanager-0   |
| JobHistoryServer | http | 19888 | jobhistory-0        |
| NodeManager      | http | 8042  | datanode-0          |
| DataNode         | http | 9864  | datanode-0          |
| HMaster          | http | 16010 | hbasemaster-0       |
| HMaster          | http | 16010 | hbasebkmaster-0     |
| HRegionServer    | http | 16030 | hbaseregionserver-0 |
| hiveserver2      | http | 10002 | hive-0              |

* mysql客户端连接

```
$ docker run -it --rm --net hadoop mysql:8.0.31 mysql -hmysql-cs -uroot -p
```

##### Kubernetes版本

* 存储类

[Kubernetes 不包含内部 NFS 驱动,您需要使用外部驱动为 NFS 创建 StorageClass.](https://kubernetes.io/zh-cn/docs/concepts/storage/storage-classes/#nfs "NFS 创建 StorageClass")

[外部NFS驱动(NFS subdir).](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner "NFS subdir 外部驱动")

```
$ cd nfs-subdir-external-provisioner/deploy/
$ cat kustomization.yaml

resources:
  - class.yaml
  - rbac.yaml
  - deployment.yaml

```

> 首先您要有*NFS服务器*的连接信息,
>
> **修改deployment.yaml文件里的** `<YOUR_NFS_SERVER_IP>` and `<YOUR_NFS_SERVER_SHARE>`, [请参考NFS subdir的README.md (Step 1和Step 4)](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner#with-kustomize)

请依次执行

```
$ kubectl apply -f ./class.yaml
$ kubectl apply -f ./rbac.yaml
$ kubectl apply -f ./deployment.yaml
```

* **下载镜像**

```
docker pull caiziale/hdcluster:1.0.0.Beta
```

> 请提前在需要部署服务的"节点"上下载镜像(size: 3.05GB).

* 创建HDCluster集群系统:

```
$ ./create_HDCluster_k8s.sh     #控制平面节点(control-plane node)上执行(主节点)
```

> 1. 可以修改脚本后在执行,例如:
>
>    1.1 修改 `sleep 90`为 `sleep 60`
>
>    1.2 `cat hnamenode.yaml |grep -E 'startupProbe|livenessProbe|periodSeconds|failureThreshold'`  #修改探针检测时间等
>
>    1.3 `cat hdatanode.yaml |grep -E 'storage'`    #修改持久卷大小
>
>    1.4 HDCluster集群所有容器的**持久卷(pv)总存储大小为16.4G**i

> 2. 脚本会自动生成 `mysql`密码并打印到屏幕上, 您也可以用自己的密码来代替.
>
> ```
> $ cat ./create_HDCluster_k8s.sh
> ...
> export MYSQL_PASSWORD=${RANDOMTMP}
> ...
> ```

此脚本会创建以下容器:

| 容器名称                                              | 作用                                                  | 默认创建容器数量 | 持久卷大小 | 数量 |
| ----------------------------------------------------- | ----------------------------------------------------- | ---------------- | ---------- | ---- |
| site-0                                                | 为数据卷容器,保存着多个系统的配置文件                 | 1                | 500Mi      | 1    |
| mysql-0                                               | 为Apache Hive提供元数据支持                           | 1                | 5Gi        | 1    |
| zk-0,zk-1,zk-2                                        | 为几种系统提供HA支持                                  | 3                | 100Mi      | 3    |
| journal-0,journal-1,journal-2                         | Apache Hadoop节点,为HDFS HA提供支持                   | 3                | 100Mi      | 3    |
| namenode-0,namenode-1,namenode-2                      | Apache Hadoop节点,为HDFS HA提供支                     | 3                | 100Mi      | 3    |
| resourcemanager-0,resourcemanager-1,resourcemanager-2 | Apache Hadoop节点,为YARN's ResourceManager HA提供支持 | 3                |            |      |
| jobhistory-0                                          | Apache Hadoop节点                                     | 1                |            |      |
| datanode-0,datanode-1                                 | Apache Hadoop节点,含NodeManager                       | 2                | 5Gi        | 2    |
| hbasemaster-0                                         | Apache HBase的HMaster节点                             | 1                |            |      |
| hbasebkmaster-0,hbasebkmaster-1,hbasebkmaster-2       | Apache HBase的Backup HMaster节点                      | 3                |            |      |
| hbaseregionserver-0,hbaseregionserver-1               | Apache HBase的HRegionServer节点                       | 2                |            |      |
| hive-0,hive-1                                         | Apache Hive节点                                       | 2                |            |      |

> 请注意k8s节点的内存,如果节点内存不够可能导致容器创建不成功或造成容器重启.

* 停止HDCluster集群系统:

```
$ ./stop_HDCluster_k8s.sh     #控制平面节点(control-plane node)上执行(主节点)
```

* 启动HDCluster集群系统:

```
$ ./start_HDCluster_k8s.sh     #控制平面节点(control-plane node)上执行(主节点)
```

> 也可以修改脚本后在执行.
>
> 例如: 修改 `sleep 90`为 `sleep 60`

* 查看HDCluster容器集群ip

```
$ ./check_HDCluster_ip_k8s.sh     #控制平面节点(control-plane node)上执行(主节点)
```

* 相关容器的端口

```
$ kubectl get svc     #控制平面节点(control-plane node)上执行(主节点)
```

* 查看容器日志

```
$ kubectl logs -f pods/datanode-0
```

* mysql客户端连接

```
$ kubectl exec -it mysql-0 -- mysql -hmysql-cs -uroot -p
```

> 设置 mysql连接数, `mysql-0容器重启后设置的连接数会失效`.

```
$ kubectl exec -it mysql-0 -- mysql -hmysql-cs -uroot -p -e "set global max_connections=1000;set global max_user_connections=300;"
$ kubectl exec -it mysql-0 -- mysql -hmysql-cs -uroot -p -e "show variables like '%connections%'"
```

---

##### 测试代码:

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

> 请在 `Hive`里查看 `"src"`表.

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

> Kubernetes版本时将 `"zk-0:2181,zk-1:2181,zk-2:2181"`替换为 `"zk-cs:2181"`

###### 注意:

`In the hive test environment, username is root and password is empty.`

`hive.execution.engine=mr`

```
yarn-site.xml 文件中描述各个队列的属性
...
<property>
  <name>yarn.scheduler.fair.allocation.file</name>
...

```

---

###### Hadoop,HBase,Spark,Hive相关系统配置文件的共享位置:

```
$ docker exec -it site-0 /bin/bash
$ cd /mnt
$ ls -la
```

此四个目录 `hadoop,hbase_conf,hive_conf,spark_conf`含有相关系统的配置文件.
