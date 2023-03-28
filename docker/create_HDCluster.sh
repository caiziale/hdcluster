#/bin/bash

# HDCluster
#
# Copyright 2023 the author.
# @author caizi

#Checking commands required by script...
  function isCmdExist() {
    cmd=$1
    type ${cmd} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      printf "This script requires the \033[0;35;40m%s\033[0m command, but it is not installed. Aborting...\n" ${cmd}
      exit 1
    fi
  }

isCmdExist md5sum


export DB_BASE_DIR="/hdclusterdb"

function print_usage() {
echo "\
Usage: create_HDCluster.sh [OPTIONS]
Starts container cluster based on the supplied options.
    --d                 The data volumes home directory of the container cluster.
                        The default value is /hdclusterdb.
"
}

optspec=":hv-:"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
	    	d=*)
                    DB_BASE_DIR=${OPTARG##*=}
                    ;;
                *)
                    echo "Unknown option --${OPTARG}" >&2
                    exit 1
                    ;;
            esac;;
        h|help)
            print_usage
            exit
            ;;
        v)
            echo "Parsing option: '-${optchar}'" >&2
	    exit 0
            ;;
        *)
            if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
            fi
	    exit 1
            ;;
    esac
done

printf ".......... Starts creating the data volumes home directory \033[0;35;40m%s\033[0m for the containers cluster ..........\n" "${DB_BASE_DIR}"

mkdir -p ${DB_BASE_DIR}
if [ $? -ne 0 ]; then
    echo "An error was reported when creating the data volume home directory."
    exit 1
fi

export DOCKER_TMP_DIR1="${DB_BASE_DIR}/data1"
export DOCKER_TMP_DIR2="${DB_BASE_DIR}/data2"
export DOCKER_TMP_DIR3="${DB_BASE_DIR}/data3"

echo "-------- MySQL parameter initialization --------"
UUID=`cat /proc/sys/kernel/random/uuid`
TIMESTAMP=`date +%s%N`
RANDOMTMP=`echo ${UUID}${TIMESTAMP}|md5sum|head -c 12`

MYSQL_PASSWORD=${RANDOMTMP}

printf ".......... Mysql username:\033[0;35;40m%s\033[0m\n" "root"
printf ".......... Mysql password:\033[0;35;40m%s\033[0m\n" ${MYSQL_PASSWORD}


echo "****** Create a new container's data volume directory. ******"

mkdir -p ${DOCKER_TMP_DIR1}/mysql
mkdir -p ${DOCKER_TMP_DIR2}/site0
mkdir -p ${DOCKER_TMP_DIR2}/zk0
mkdir -p ${DOCKER_TMP_DIR2}/zk1
mkdir -p ${DOCKER_TMP_DIR2}/zk2
mkdir -p ${DOCKER_TMP_DIR2}/jn0
mkdir -p ${DOCKER_TMP_DIR2}/jn1
mkdir -p ${DOCKER_TMP_DIR2}/jn2
mkdir -p ${DOCKER_TMP_DIR2}/nn0
mkdir -p ${DOCKER_TMP_DIR2}/nn1
mkdir -p ${DOCKER_TMP_DIR2}/nn2
mkdir -p ${DOCKER_TMP_DIR3}/dn0
mkdir -p ${DOCKER_TMP_DIR3}/dn1
mkdir -p ${DOCKER_TMP_DIR3}/dn2


echo "****** Starts to create container cluster. ******"
echo ""

#--site
echo "------ Starts site container..."
docker run -itd -v ${DOCKER_TMP_DIR2}/site0:/mnt --net hadoop -h site-0 --name site-0 caiziale/hdcluster:1.0.0.Beta /bin/bash -c "create_site_docker.sh --servers=3 --mysqlpassword=${MYSQL_PASSWORD}"


#--mysql
echo "------ Starts mysql container..."
docker run -itd --net hadoop -v ${DOCKER_TMP_DIR1}/mysql:/var/lib/mysql -h mysql-cs --name mysql-cs -e MYSQL_ROOT_PASSWORD=${MYSQL_PASSWORD} mysql:8.0.31

#--zk
echo "------ Starts ZK container..."
for i in {0..2}; do docker run -itd -v ${DOCKER_TMP_DIR2}/zk"${i}":/data/zookeeper --net hadoop -h zk-"${i}" --name zk-"${i}" caiziale/hdcluster:1.0.0.Beta /bin/bash -c "startzookeeper_docker.sh --servers=3"; sleep 5; done
for i in {0..2}; do echo "zk-${i}..."; docker exec -it zk-"${i}" /bin/bash -c "netstat -ant"; sleep 1; done
sleep 10

#--journal
echo "------ Starts Journal container..."
for i in {0..2}; do docker run -itd --volumes-from site-0 -v ${DOCKER_TMP_DIR2}/jn"$i":/data --net hadoop -h journal-"$i" --name journal-"$i" caiziale/hdcluster:1.0.0.Beta /bin/bash -c "startjournal.sh"; sleep 10; done
for i in {0..2}; do echo "journal-${i}..."; docker exec -it journal-"$i" /bin/bash -c "netstat -ant"; sleep 1; done
sleep 5

#--namenode
echo "------ Starts Namenode  container..."
for i in {0..2}; 
do 
    docker run -itd --volumes-from site-0 -v ${DOCKER_TMP_DIR2}/nn"$i":/data --net hadoop -h namenode-"$i" --name namenode-"$i" caiziale/hdcluster:1.0.0.Beta /bin/bash -c "startnamenode.sh";
    if (( "${i}" == 0 )); then
        while true;
        do  
	    docker exec -it namenode-0 /bin/bash -c "source /etc/profile && hdfs haadmin -getAllServiceState|grep -E \"active\""
            if [ $? -eq 0 ]; then
                break;
            fi
            sleep 10;
	    echo "Waiting for namenode-0 startup to complete..."
        done 
    fi
done
sleep 30
docker exec -it namenode-0 /bin/bash -c "source /etc/profile && hdfs haadmin -getAllServiceState"


#--yarn(resourcemanager)
echo "------ Starts Resourcemanager container..."
for i in {0..2}; do docker run -itd --volumes-from site-0 --net hadoop -h resourcemanager-"${i}" --name resourcemanager-"${i}" caiziale/hdcluster:1.0.0.Beta /bin/bash -c "startyarn.sh"; sleep 15; done
docker exec -it resourcemanager-0 /bin/bash -c "source /etc/profile && yarn rmadmin -getAllServiceState"

#--jobhistory
echo "------ Starts Jobhistory container..."
docker run -itd --volumes-from site-0 --net hadoop -h jobhistory-0 --name jobhistory-0 caiziale/hdcluster:1.0.0.Beta /bin/bash -c "startjobhistory.sh"
sleep 5
echo "jobhistory-0..."
docker exec -it jobhistory-0 /bin/bash -c "netstat -ant"

#--datanode
echo "------ Starts Datanode container..."
for i in {0..2}; do docker run -itd --volumes-from site-0 -v ${DOCKER_TMP_DIR3}/dn"${i}":/data --net hadoop -h datanode-"${i}" --name datanode-"${i}" caiziale/hdcluster:1.0.0.Beta /bin/bash -c "startdatanode.sh"; sleep 2; done
for i in {0..2}; do echo "datanode-${i}..."; docker exec -it datanode-"${i}" /opt/software/java-se-8u42-ri/bin/jps|grep -v Jps;done



#--hbasemaster
echo "------ Starts Hbasemaster container..."
docker run -itd --volumes-from site-0 --net hadoop -h hbasemaster-0 --name hbasemaster-0 caiziale/hdcluster:1.0.0.Beta /bin/bash -c "starthbasemaster.sh"
#--hbasebkmaster
echo "------ Starts Hbasebkmaster container..."
for i in {0..2}; do docker run -itd --volumes-from site-0 --net hadoop -h hbasebkmaster-"${i}" --name hbasebkmaster-"${i}" caiziale/hdcluster:1.0.0.Beta /bin/bash -c "starthbasebkmaster.sh";sleep 10;done
#--hbaseregionserver
echo "------ Starts Hbaseregionserver container..."
for i in {0..2}; do docker run -itd --volumes-from site-0 --net hadoop -h hbaseregionserver-"${i}" --name hbaseregionserver-"${i}" caiziale/hdcluster:1.0.0.Beta /bin/bash -c "starthbaseregionserver.sh";sleep 10;done

sleep 5
echo "hbasemaster-0..."
docker exec -it hbasemaster-0 /opt/software/java-se-8u42-ri/bin/jps|grep -v Jps
for i in {0..2}; do echo "hbasebkmaster-${i}..."; docker exec -it hbasebkmaster-"${i}" /opt/software/java-se-8u42-ri/bin/jps|grep -v Jps;done
for i in {0..2}; do echo "hbaseregionserver-${i}..."; docker exec -it hbaseregionserver-"${i}" /opt/software/java-se-8u42-ri/bin/jps|grep -v Jps;done

#--hive
echo "------ Starts Hive container..."
for i in {0..1}; do docker run -itd --volumes-from site-0 --net hadoop -h hive-"${i}" --name hive-"${i}" caiziale/hdcluster:1.0.0.Beta /bin/bash -c "starthive.sh";sleep 90;done
#for i in {0..1}; do echo "hive-${i}..."; docker exec -it hive-"${i}" /opt/software/java-se-8u42-ri/bin/jps|grep -v Jps;done
for i in {0..1}; do echo "hive-${i}..."; docker exec -it hive-"${i}" /bin/bash -c "netstat -ant|grep -E '9083|10000|10002'"; sleep 5; done



