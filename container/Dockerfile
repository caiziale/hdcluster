# HDCluster
# @author caizi

FROM ubuntu:22.04
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt update && apt-get update && apt-get -y install tzdata
RUN apt-get -y install wget curl vim inetutils-ping net-tools
RUN mkdir -p /opt && mkdir -p /sh
RUN mkdir -p /data/zookeeper
RUN mkdir -p /mnt
COPY ./sh /sh
COPY ./sh/profile /etc
COPY ./software /opt/software
COPY ./netcat /usr/local/netcat

RUN echo "source /etc/profile" >> /root/.bashrc

RUN ln -snf /sh/create_docker.sh /usr/bin/create_docker.sh
RUN ln -snf /sh/create_site.sh /usr/bin/create_site.sh
RUN ln -snf /sh/create_site_docker.sh /usr/bin/create_site_docker.sh
RUN ln -snf /sh/hivemetastore_s /usr/bin/hivemetastore_s
RUN ln -snf /sh/hiveserver2_s /usr/bin/hiveserver2_s
RUN ln -snf /sh/lnsite.sh /usr/bin/lnsite.sh
RUN ln -snf /sh/site-ready /usr/bin/site-ready
RUN ln -snf /sh/startdatanode.sh /usr/bin/startdatanode.sh
RUN ln -snf /sh/starthbasebkmaster.sh /usr/bin/starthbasebkmaster.sh
RUN ln -snf /sh/starthbasemaster.sh /usr/bin/starthbasemaster.sh
RUN ln -snf /sh/starthbaseregionserver.sh /usr/bin/starthbaseregionserver.sh
RUN ln -snf /sh/starthive.sh /usr/bin/starthive.sh
RUN ln -snf /sh/startjobhistory.sh /usr/bin/startjobhistory.sh
RUN ln -snf /sh/startjournal.sh /usr/bin/startjournal.sh
RUN ln -snf /sh/startnamenode.sh /usr/bin/startnamenode.sh
RUN ln -snf /sh/startyarn.sh /usr/bin/startyarn.sh
RUN ln -snf /sh/startzookeeper.sh /usr/bin/startzookeeper.sh
RUN ln -snf /sh/startzookeeper_docker.sh /usr/bin/startzookeeper_docker.sh

RUN ln -snf /usr/local/netcat/bin/netcat /usr/bin/nc

RUN ln -snf /opt/software/hadoop-3.3.4/bin/datanode-ready /usr/bin/datanode-ready

RUN ln -snf /opt/software/hadoop-3.3.4/bin/hadoop /usr/bin/hadoop
RUN ln -snf /opt/software/hadoop-3.3.4/bin/hdfs /usr/bin/hdfs
RUN ln -snf /opt/software/hadoop-3.3.4/bin/mapred /usr/bin/mapred
RUN ln -snf /opt/software/hadoop-3.3.4/bin/yarn /usr/bin/yarn

RUN ln -snf /opt/software/apache-zookeeper-3.8.0-bin/bin/zookeeper-ready /usr/bin/zookeeper-ready
RUN ln -snf /opt/software/apache-zookeeper-3.8.0-bin/bin/zkCleanup.sh /usr/bin/zkCleanup.sh
RUN ln -snf /opt/software/apache-zookeeper-3.8.0-bin/bin/zkCli.sh /usr/bin/zkCli.sh
RUN ln -snf /opt/software/apache-zookeeper-3.8.0-bin/bin/zkEnv.sh /usr/bin/zkEnv.sh
RUN ln -snf /opt/software/apache-zookeeper-3.8.0-bin/bin/zkServer-initialize.sh /usr/bin/zkServer-initialize.sh
RUN ln -snf /opt/software/apache-zookeeper-3.8.0-bin/bin/zkServer.sh /usr/bin/zkServer.sh
RUN ln -snf /opt/software/apache-zookeeper-3.8.0-bin/bin/zkSnapShotToolkit.sh /usr/bin/zkSnapShotToolkit.sh
RUN ln -snf /opt/software/apache-zookeeper-3.8.0-bin/bin/zkSnapshotComparer.sh /usr/bin/zkSnapshotComparer.sh
RUN ln -snf /opt/software/apache-zookeeper-3.8.0-bin/bin/zkTxnLogToolkit.sh /usr/bin/zkTxnLogToolkit.sh





