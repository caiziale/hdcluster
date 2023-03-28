#!/bin/bash

# HDCluster
#
# Copyright 2023 the author.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# @author caizi

function ln_site() {
    mv "${HADOOP_CONF_DIR}" "${HADOOP_CONF_DIR}_bk"
    ln -s /mnt/hadoop "${HADOOP_CONF_DIR}"

    mv "${HBASE_CONF_DIR}" "${HBASE_CONF_DIR}_bk"
    ln -s /mnt/hbase_conf "${HBASE_CONF_DIR}"

    mv "${SPARK_CONF_DIR}" "${SPARK_CONF_DIR}_bk"
    ln -s /mnt/spark_conf "${SPARK_CONF_DIR}"

    mv "${HIVE_CONF_DIR}" "${HIVE_CONF_DIR}_bk"
    ln -s /mnt/hive_conf "${HIVE_CONF_DIR}" 
    
}
