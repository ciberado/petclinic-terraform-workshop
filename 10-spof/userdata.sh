#!/bin/bash

apt update
apt install jq awscli openjdk-17-jdk -y

cd
git clone https://github.com/spring-projects/spring-petclinic
cd spring-petclinic
./mvnw -Dmaven.test.skip package

FILE=$(ls target/*.jar)


java \
  -Dserver.port=80 \
  -jar $FILE

# Run with MySQL profile:

REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

MYSQL_ENDPOINT=$(aws ssm get-parameter \
  --with-decryption \
  --name "/__PREFIX__/__ENVIRONMENT__/databases/endpoint" \
  --query Parameter.Value \
  --output text \
  --region $REGION)
MYSQL_URL=jdbc:mysql://$MYSQL_ENDPOINT/petclinic
MYSQL_USER=admin
MYSQL_PASS=$(aws ssm get-parameter \
  --name "/__PREFIX__/__ENVIRONMENT__/databases/password/master" \
  --with-decryption \
  --query Parameter.Value \
  --output text \
  --region $REGION)

java \
  -Dspring.profiles.active=mysql \
  -Dserver.port=80 \
  -DMYSQL_USER=$MYSQL_USER \
  -DMYSQL_URL=$MYSQL_URL \
  -DMYSQL_PASS="$MYSQL_PASS" \
  -jar $FILE
