# HDInsights Kafka Cluster

This project shows how to create a HDInsights Kafka cluster in order to ingest FAA SWIM Data.

It creates the following resources:

* A new Resource Group.
* An HDInsights Kafka Cluster inside a VNet.
* An Edge node for Kafka management using an ARM Template.
* A Storage Account.
* A VNet.
* 4 subnets to host the Kafka Cluster, head nodes, worker nodes and zookeeper nodes.
* 2 subnets public and private dedicated to DataBricks Cluster.
* A Network Security Group with SSH, HTTP and RDP access.
* A Network Security Group dedicated to the DataBricks Cluster.
* A DataBricks Workspace with VNet injection using an ARM template since Azure provider does not support that yet, but it shows how easy is to integrate terraform with ARM Templates. More information about VNet injection canbe found [here.](https://docs.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/vnet-inject)

## Project Structure

This project has the following files which make them easy to reuse, add or remove.

```ssh
.
├── LICENSE
├── README.md
├── clustervariables.tf
├── edgenode.json
├── edgenode.tf
├── hdinsight.tf
├── main.tf
├── networking.tf
├── outputs.tf
├── security.tf
├── storage.tf
├── variables.tf
├── workspace.json
└── workspace.tf
```

Most common paremeters are exposed as variables in _`variables.tf`_ and the cluster specific variables are in `clustervariables.tf`.

## Pre-requisites

It is assumed that you have azure CLI and Terraform installed and configured.
More information on this topic [here](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/terraform-install-configure). I recommend using a Service Principal with a certificate.

### SWIM Access

This project also assumes that you have access to SWIM Data from FAA. If you do not have access you can request it using these links:

* https://data.faa.gov/
* https://scds.swim.faa.gov

This code shows sample code to ingest these subscriptions:

* TFMS - Traffic Flow Management System.
* STDDS - SWIM Terminal Data Distribution Systems.
* TBFM - Time Based Flow Management.

### Versions

* Terraform =>0.12.17
* Azure provider 1.37.0
* Azure CLI 2.0.77

## Authentication

The cluster uses key based authentication and it assumes you already have a key and you can configure the path using the _sshKeyPath_ variable in _`clustervariables.tf`_

You can create one using this command:

```ssh
ssh-keygen -t rsa -b 4096 -m PEM -C vm@mydomain.com -f ~/.ssh/vm_ssh
```

For ambari/web access you can set the _webAdminPassword_ variable in _`clustervariables.tf`_, but it is recommended to use environment variables instead.

```ssh
export TF_VAR_webAdminPassword={{SECRET_PASSWORD}}
```

More information about environment variables can be found [here.](https://www.terraform.io/docs/configuration/variables.html#environment-variables)

## Usage

Just run these commands to initialize terraform, get a plan and approve it to apply it.

```ssh
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
```

I also recommend using a remote state instead of a local one. You can change this configuration in _`main.tf`_
You can create a free Terraform Cloud account [here](https://app.terraform.io).

## Getting the Edge node ready

### Installing the Solace Connector and Depedencies

ssh into edge node

```ssh
ssh acctestusrvm@new-edgenode.swim-hdicluster-ssh.azurehdinsight.net -i ~/.ssh/vm_ssh
```

make sure default java is 1.8

```ssh
$ which java
/usr/bin/java

$ java -version
openjdk version "1.8.0_222"
OpenJDK Runtime Environment (Zulu 8.40.0.25-linux64)-Microsoft-Azure-restricted (build 1.8.0_222-b10)
OpenJDK 64-Bit Server VM (Zulu 8.40.0.25-linux64)-Microsoft-Azure-restricted (build 25.222-b10, mixed mode)
```

or set it manually

```ssh
#For example:
export JAVA_HOME='C:\Program Files\Java\jdk-11.0.3'
export PATH=$JAVA_HOME/bin:$PATH

$ java -version
java version "1.8.0_231"
Java(TM) SE Runtime Environment (build 1.8.0_231-b11)
Java HotSpot(TM) 64-Bit Server VM (build 25.231-b11, mixed mode)

```

## Build and Copy Solace connector using Gradle and its Dependencies

Clone Solace connector source code from GitHub

```ssh
cd
git clone https://github.com/SolaceLabs/pubsubplus-connector-kafka-source.git
```

Check and Build Solace Connector

```ssh
# check gradle build
cd pubsubplus-connector-kafka-source
./gradlew clean check

# create new Solace Connector gradle build
./gradlew clean jar
```

copy Solace Connector to ~/kafka_2.12-2.3.0/libs/

```ssh
cp -v build/libs/*.jar /opt/kafka/libs/
```

get the Java Solace depedencies

```ssh
cd ..
wget -q https://products.solace.com/download/JAVA_API -O sol-connector.zip
```

or from maven central

```ssh
wget https://repo1.maven.org/maven2/com/solacesystems/sol-jcsmp/10.6.3/sol-jcsmp-10.6.3.jar
```

unpack and copy dependencies to ~/kafka_2.12-2.3.0/libs/

```ssh
unzip sol-connector.zip
cp -v sol-jcsmp-*/lib/*.jar /opt/kafka/libs/
```

## Get the Apache Zookeeper and Broker host information

Install `jq` so it is easy to parse JSON documents.

```ssh
sudo apt -y install jq
```

Set portal `password`. This is the password you set in _webAdminPassword_ variable in _`clustervariables.tf`_

```ssh
export password='{{WEB_ADMIN_PASSWORD}}'
```

Get cluster name and store it in `clusterName`.

```ssh
export clusterName=$(curl -u admin:$password -sS -G "http://headnodehost:8080/api/v1/clusters" | jq -r '.items[].Clusters.cluster_name')

echo $clusterName
```

Set Zookeeper host information and host it into `KAFKAZKHOSTS`

```ssh
export KAFKAZKHOSTS=$(curl -sS -u admin:$password -G https://$clusterName.azurehdinsight.net/api/v1/clusters/$clusterName/services/ZOOKEEPER/components/ZOOKEEPER_SERVER | jq -r '["\(.host_components[].HostRoles.host_name):2181"] | join(",")' | cut -d',' -f1,2);

echo $KAFKAZKHOSTS
```

Get Apache Kafka broker hosts information and storing it into `KAFKABROKERS`

```ssh
export KAFKABROKERS=$(curl -sS -u admin:$password -G https://$clusterName.azurehdinsight.net/api/v1/clusters/$clusterName/services/KAFKA/components/KAFKA_BROKER | jq -r '["\(.host_components[].HostRoles.host_name):9092"] | join(",")' | cut -d',' -f1,2);

echo $KAFKABROKERS
```

## Add kafka tools to path

```ssh
export KAFKA_HOME=/usr/hdp/current/kafka-broker
export PATH=$KAFKA_HOME/bin:$PATH
```

## Manage Apache Kafka topics

Create a topic

```ssh
# stdds
kafka-topics.sh --create --replication-factor 3 --partitions 1 --topic stdds --zookeeper $KAFKAZKHOSTS

#tfms
kafka-topics.sh --create --replication-factor 3 --partitions 1 --topic tfms --zookeeper $KAFKAZKHOSTS
```

List topics

```ssh
kafka-topics.sh --list --zookeeper $KAFKAZKHOSTS
```

Delete topics

```ssh
# stdds
kafka-topics.sh --delete --topic stdds --zookeeper $KAFKAZKHOSTS

# tfms
kafka-topics.sh --delete --topic tfms --zookeeper $KAFKAZKHOSTS
```

Describe topics

```ssh
kafka-topics.sh --describe --topic stdds --zookeeper $KAFKAZKHOSTS
```

### Configure Solace Connector to connect to SWIM Data Source

Update `/usr/hdp/current/kafka-broker/config/connect-standalone.properties` and set `bootstrap.servers=` to _$KAFKABROKERS_
, `key.converter=org.apache.kafka.connect.storage.StringConverter` and `value.converter=org.apache.kafka.connect.storage.StringConverter`

```ssh
sudo vi /usr/hdp/current/kafka-broker/config/connect-standalone.properties
```

This is the final content of the file using sample data

```ssh
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# These are defaults. This file just demonstrates how to override some settings.
bootstrap.servers=wn0-swim-h.xpxjeerrpwmuppw3xr4cib4fjh.bx.internal.cloudapp.net:9092,wn1-swim-h.xpxjeerrpwmuppw3xr4cib4fjh.bx.internal.cloudapp.net:9092

# The converters specify the format of data in Kafka and how to translate it into Connect data. Every Connect user will
# need to configure these based on the format they want their data in when loaded from or stored into Kafka
key.converter=org.apache.kafka.connect.storage.StringConverter
value.converter=org.apache.kafka.connect.storage.StringConverter
# Converter-specific settings can be passed in by prefixing the Converter's setting with the converter we want to apply
# it to
key.converter.schemas.enable=true
value.converter.schemas.enable=true

offset.storage.file.filename=/tmp/connect.offsets
# Flush much faster than normal, which is useful for testing/debugging
offset.flush.interval.ms=10000

# Set to a list of filesystem paths separated by commas (,) to enable class loading isolation for plugins
# (connectors, converters, transformations). The list should consist of top level directories that include
# any combination of:
# a) directories immediately containing jars with plugins and their dependencies
# b) uber-jars with plugins and their dependencies
# c) directories immediately containing the package directory structure of classes of plugins and their dependencies
# Note: symlinks will be followed to discover dependencies or plugins.
# Examples:
# plugin.path=/usr/local/share/java,/usr/local/share/kafka/plugins,/opt/connectors,
#plugin.path=
```

Create stdds and/or tfms config connectors

```ssh
# stdds
sudo vi /usr/hdp/current/kafka-broker/config/connect-solace-stdds-source.properties

# tfms
sudo vi /usr/hdp/current/kafka-broker/config/connect-solace-tfms-source.properties
```

> These values are mandatory and you need provide them:

```vi
name
kafka.topic
sol.host
sol.username
sol.password
sol.vpn_name
sol.queue
```

This is the final content of the file

```ssh
name={{connectoName}}
connector.class=com.solace.source.connector.SolaceSourceConnector
tasks.max=2
kafka.topic={{kafkaTopic}}
sol.host={{SWIMEndpoint:Port}}
sol.username={{SWIMUserNaMe}}
sol.password={{Password}}
sol.vpn_name={{SWIMVPN}}
sol.topics=soltest
sol.queue={{SWIMQueue}}
sol.message_callback_on_reactor=false
sol.message_processor_class=com.solace.source.connector.msgprocessors.SolaceSampleKeyedMessageProcessor
#sol.message_processor_class=com.solace.source.connector.msgprocessors.SolSampleSimpleMessageProcessor
sol.generate_send_timestamps=false
sol.generate_rcv_timestamps=false
sol.sub_ack_window_size=255
sol.generate_sequence_numbers=true
sol.calculate_message_expiration=true
sol.subscriber_dto_override=false
sol.channel_properties.connect_retries=-1
sol.channel_properties.reconnect_retries=-1
sol.kafka_message_key=DESTINATION
sol.ssl_validate_certificate=false
#sol.ssl_validate_certicate_date=false
#sol.ssl_connection_downgrade_to=PLAIN_TEXT
sol.ssl_trust_store=/opt/PKI/skeltonCA/heinz1.ts
sol.ssl_trust_store_pasword=sasquatch
sol.ssl_trust_store_format=JKS
#sol.ssl_trusted_command_name_list
sol.ssl_key_store=/opt/PKI/skeltonCA/heinz1.ks
sol.ssl_key_store_password=sasquatch
sol.ssl_key_store_format=JKS
sol.ssl_key_store_normalized_format=JKS
sol.ssl_private_key_alias=heinz1
sol.ssl_private_key_password=sasquatch
#sol.authentication_scheme=AUTHENTICATION_SCHEME_CLIENT_CERTIFICATE
key.converter.schemas.enable=true
value.converter.schemas.enable=true
#key.converter=org.apache.kafka.connect.converters.ByteArrayConverter
value.converter=org.apache.kafka.connect.converters.ByteArrayConverter
#key.converter=org.apache.kafka.connect.json.JsonConverter
#value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter=org.apache.kafka.connect.storage.StringConverter
#value.converter=org.apache.kafka.connect.storage.StringConverter
```

restart kafka service

```ssh
sudo systemctl restart kafka.service
```

Start standalone connection

```ssh
# stdds
connect-standalone.sh /usr/hdp/current/kafka-broker/config/connect-standalone.properties /usr/hdp/current/kafka-broker/config/connect-solace-stdds-source.properties

# tfms
connect-standalone.sh /usr/hdp/current/kafka-broker/config/connect-standalone.properties /usr/hdp/current/kafka-broker/config/connect-solace-tfms-source.properties
```

Check incoming messages. This command will display all the messages from the beginning and might take some time if you have lots of messages.

```ssh
# stdds
kafka-console-consumer.sh --bootstrap-server $KAFKABROKERS --topic stdds --from-beginning

# tfms
kafka-console-consumer.sh --bootstrap-server $KAFKABROKERS --topic tfms --from-beginning
```

If you just want to check specific messages and not display all of them, you can use the `--max-messages` option.
The following comand will display the first message.

```ssh
# stdds
kafka-console-consumer.sh --from-beginning --max-messages 1 --topic stdds --bootstrap-server $KAFKABROKERS

# tfms
kafka-console-consumer.sh --from-beginning --max-messages 1 --topic tfms --bootstrap-server $KAFKABROKERS
```

if you want to see all available options, just run the `kafka-console-consumer.sh` without any options

```ssh
kafka-console-consumer.sh
```

## Clean resources

It will destroy everything that was created.

```ssh
terraform destroy --force
```

## Caution

Be aware that by running this script your account might get billed.

## Authors

* Marcelo Zambrana
