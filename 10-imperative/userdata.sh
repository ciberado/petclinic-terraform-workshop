#!/bin/bash

apt update
apt install jq awscli openjdk-17-jdk -y

FILE=spring-petclinic-4.0.0-SNAPSHOT.jar
wget https://github.com/ciberado/petclinic-terraform-workshop/releases/download/binary-4.0/$FILE

java -Dserver.port=80  -jar $FILE
