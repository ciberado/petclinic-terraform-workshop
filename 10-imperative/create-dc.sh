#!/bin/bash
set -e

# Default values
PREFIX="petclinic"
ENVIRONMENT="dev"
OWNER="anonymous"
REGION="us-east-1"
VPC_ADDR_PREFIX="10.0"
APP_INSTANCE_TYPE="t3.micro"
RDS_INSTANCE_TYPE="db.t3.micro"

# Parse command line arguments
while getopts "p:e:o:r:v:a:d:h" opt; do
  case $opt in
    p) PREFIX="$OPTARG" ;;
    e) ENVIRONMENT="$OPTARG" ;;
    o) OWNER="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    v) VPC_ADDR_PREFIX="$OPTARG" ;;
    a) APP_INSTANCE_TYPE="$OPTARG" ;;
    d) RDS_INSTANCE_TYPE="$OPTARG" ;;
    h)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -p PREFIX             Application prefix (default: petclinic)"
      echo "  -e ENVIRONMENT        Environment (default: dev)"
      echo "  -o OWNER              Owner name (default: anonymous)"
      echo "  -r REGION             AWS region (default: us-east-1)"
      echo "  -v VPC_ADDR_PREFIX    VPC address prefix (default: 10.0)"
      echo "  -a APP_INSTANCE_TYPE  App instance type (default: t3.micro)"
      echo "  -d RDS_INSTANCE_TYPE  RDS instance type (default: db.t3.micro)"
      echo "  -h                    Show this help message"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

echo "Creating AWS infrastructure..."

# 1. CREATE VPC
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "${VPC_ADDR_PREFIX}.0.0/16" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PREFIX}-vpc},{Key=Layer,Value=network fabric}]" \
  --query 'Vpc.VpcId' \
  --output text \
  --region ${REGION})

echo "VPC created: ${VPC_ID}"

# Enable DNS hostnames and support
aws ec2 modify-vpc-attribute \
  --vpc-id ${VPC_ID} \
  --enable-dns-hostnames \
  --region ${REGION}

aws ec2 modify-vpc-attribute \
  --vpc-id ${VPC_ID} \
  --enable-dns-support \
  --region ${REGION}

# 2. CREATE INTERNET GATEWAY
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PREFIX}-igw}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text \
  --region ${REGION})

echo "Internet Gateway created: ${IGW_ID}"

# Attach IGW to VPC
aws ec2 attach-internet-gateway \
  --vpc-id ${VPC_ID} \
  --internet-gateway-id ${IGW_ID} \
  --region ${REGION}

# 3. CREATE SUBNETS
echo "Creating subnets..."

# Public Subnet 1
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id ${VPC_ID} \
  --cidr-block "${VPC_ADDR_PREFIX}.100.0/24" \
  --availability-zone "${REGION}a" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PREFIX}-public-1},{Key=Layer,Value=network fabric}]" \
  --query 'Subnet.SubnetId' \
  --output text \
  --region ${REGION})

# Public Subnet 2
PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id ${VPC_ID} \
  --cidr-block "${VPC_ADDR_PREFIX}.101.0/24" \
  --availability-zone "${REGION}b" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PREFIX}-public-2},{Key=Layer,Value=network fabric}]" \
  --query 'Subnet.SubnetId' \
  --output text \
  --region ${REGION})

# Private Subnet 1
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id ${VPC_ID} \
  --cidr-block "${VPC_ADDR_PREFIX}.200.0/24" \
  --availability-zone "${REGION}a" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PREFIX}-private-1},{Key=Layer,Value=network fabric}]" \
  --query 'Subnet.SubnetId' \
  --output text \
  --region ${REGION})

# Private Subnet 2
PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id ${VPC_ID} \
  --cidr-block "${VPC_ADDR_PREFIX}.201.0/24" \
  --availability-zone "${REGION}b" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PREFIX}-private-2},{Key=Layer,Value=network fabric}]" \
  --query 'Subnet.SubnetId' \
  --output text \
  --region ${REGION})

echo "Subnets created"

# 4. CREATE ROUTE TABLES
echo "Creating route tables..."

# Public Route Table
PUBLIC_RT=$(aws ec2 create-route-table \
  --vpc-id ${VPC_ID} \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PREFIX}-public-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text \
  --region ${REGION})

# Add route to IGW
aws ec2 create-route \
  --route-table-id ${PUBLIC_RT} \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id ${IGW_ID} \
  --region ${REGION}

# Associate public subnets with public route table
aws ec2 associate-route-table \
  --subnet-id ${PUBLIC_SUBNET_1} \
  --route-table-id ${PUBLIC_RT} \
  --region ${REGION}

aws ec2 associate-route-table \
  --subnet-id ${PUBLIC_SUBNET_2} \
  --route-table-id ${PUBLIC_RT} \
  --region ${REGION}

echo "Route tables configured"

# 5. CREATE SECURITY GROUPS
echo "Creating security groups..."

# App Security Group
APP_SG_ID=$(aws ec2 create-security-group \
  --group-name "${PREFIX}_app_sg" \
  --description "Petclinic security group" \
  --vpc-id ${VPC_ID} \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Layer,Value=network fabric}]" \
  --query 'GroupId' \
  --output text \
  --region ${REGION})

# Add ingress rules to App SG
aws ec2 authorize-security-group-ingress \
  --group-id ${APP_SG_ID} \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region ${REGION}

aws ec2 authorize-security-group-ingress \
  --group-id ${APP_SG_ID} \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --region ${REGION}

echo "App Security Group created: ${APP_SG_ID}"

# RDS Security Group
RDS_SG_ID=$(aws ec2 create-security-group \
  --group-name "${PREFIX}_rds_mysql_sg" \
  --description "Database security group for mysql" \
  --vpc-id ${VPC_ID} \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Layer,Value=database}]" \
  --query 'GroupId' \
  --output text \
  --region ${REGION})

# Add ingress rule to RDS SG (from App SG)
aws ec2 authorize-security-group-ingress \
  --group-id ${RDS_SG_ID} \
  --protocol tcp \
  --port 3306 \
  --source-group ${APP_SG_ID} \
  --region ${REGION}

echo "RDS Security Group created: ${RDS_SG_ID}"

# 6. GENERATE DATABASE PASSWORD
echo "Generating database password..."
DB_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-10)

# Store password in SSM Parameter Store
aws ssm put-parameter \
  --name "/${PREFIX}/${ENVIRONMENT}/databases/password/master" \
  --description "Initial password for the database" \
  --type "SecureString" \
  --value "${DB_PASSWORD}" \
  --overwrite \
  --region ${REGION}

echo "Database password stored in SSM Parameter Store"

# 7. CREATE DB SUBNET GROUP
echo "Creating DB subnet group..."
aws rds create-db-subnet-group \
  --db-subnet-group-name "${PREFIX,,}databasesubnetgroup" \
  --db-subnet-group-description "Database subnet group" \
  --subnet-ids ${PRIVATE_SUBNET_1} ${PRIVATE_SUBNET_2} \
  --tags "Key=Layer,Value=computing" \
  --region ${REGION}

echo "DB subnet group created"

# 8. CREATE RDS INSTANCE
echo "Creating RDS MySQL instance (this will take several minutes)..."
aws rds create-db-instance \
  --db-instance-identifier "${PREFIX,,}db" \
  --db-instance-class ${RDS_INSTANCE_TYPE} \
  --engine mysql \
  --engine-version 5.7 \
  --master-username admin \
  --master-user-password "${DB_PASSWORD}" \
  --allocated-storage 20 \
  --max-allocated-storage 100 \
  --db-name petclinic \
  --vpc-security-group-ids ${RDS_SG_ID} \
  --db-subnet-group-name "${PREFIX,,}databasesubnetgroup" \
  --no-multi-az \
  --port 3306 \
  --no-publicly-accessible \
  --tags "Key=Layer,Value=database" \
  --region ${REGION}

echo "Waiting for RDS instance to be available..."
aws rds wait db-instance-available \
  --db-instance-identifier "${PREFIX,,}db" \
  --region ${REGION}

# Get RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "${PREFIX,,}db" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text \
  --region ${REGION})

RDS_ENDPOINT_FULL="${RDS_ENDPOINT}:3306"

# Store RDS endpoint in SSM
aws ssm put-parameter \
  --name "/${PREFIX}/${ENVIRONMENT}/databases/endpoint" \
  --description "RDS endpoint" \
  --type "String" \
  --value "${RDS_ENDPOINT_FULL}" \
  --overwrite \
  --region ${REGION}

echo "RDS instance created: ${RDS_ENDPOINT_FULL}"

# 9. GET LATEST UBUNTU AMI
echo "Finding latest Ubuntu 22.04 AMI..."
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region ${REGION})

echo "Using AMI: ${AMI_ID}"

# 10. CREATE EC2 INSTANCE
echo "Creating EC2 instance..."

# Note: You need to create userdata.sh file and replace __PREFIX__ and __ENVIRONMENT__
# For this script, assuming userdata.sh exists in the current directory
if [ -f "userdata.sh" ]; then
  USER_DATA=$(sed "s/__PREFIX__/${PREFIX}/g; s/__ENVIRONMENT__/${ENVIRONMENT}/g" userdata.sh | base64 -w 0)
else
  echo "Warning: userdata.sh not found, creating instance without user data"
  USER_DATA=""
fi

if [ -n "$USER_DATA" ]; then
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id ${AMI_ID} \
    --instance-type ${APP_INSTANCE_TYPE} \
    --subnet-id ${PUBLIC_SUBNET_1} \
    --security-group-ids ${APP_SG_ID} \
    --associate-public-ip-address \
    --iam-instance-profile Name=LabInstanceProfile \
    --user-data "${USER_DATA}" \
    --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":8,"VolumeType":"gp3"}}]' \
    --metadata-options "HttpEndpoint=enabled,InstanceMetadataTags=enabled" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PREFIX}-${OWNER,,}},{Key=Layer,Value=computing}]" "ResourceType=volume,Tags=[{Key=Name,Value=${PREFIX}-${OWNER,,}}]" \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region ${REGION})
else
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id ${AMI_ID} \
    --instance-type ${APP_INSTANCE_TYPE} \
    --subnet-id ${PUBLIC_SUBNET_1} \
    --security-group-ids ${APP_SG_ID} \
    --associate-public-ip-address \
    --iam-instance-profile Name=LabInstanceProfile \
    --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":8,"VolumeType":"gp3"}}]' \
    --metadata-options "HttpEndpoint=enabled,InstanceMetadataTags=enabled" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PREFIX}-${OWNER,,}},{Key=Layer,Value=computing}]" "ResourceType=volume,Tags=[{Key=Name,Value=${PREFIX}-${OWNER,,}}]" \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region ${REGION})
fi

echo "EC2 instance created: ${INSTANCE_ID}"

# Wait for instance to be running
echo "Waiting for instance to be running..."
aws ec2 wait instance-running \
  --instance-ids ${INSTANCE_ID} \
  --region ${REGION}

# Get instance public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids ${INSTANCE_ID} \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --region ${REGION})

echo ""
echo "==================================="
echo "Infrastructure creation completed!"
echo "==================================="
echo "VPC ID: ${VPC_ID}"
echo "Public Subnets: ${PUBLIC_SUBNET_1}, ${PUBLIC_SUBNET_2}"
echo "Private Subnets: ${PRIVATE_SUBNET_1}, ${PRIVATE_SUBNET_2}"
echo "App Security Group: ${APP_SG_ID}"
echo "RDS Security Group: ${RDS_SG_ID}"
echo "EC2 Instance ID: ${INSTANCE_ID}"
echo "EC2 Public IP: ${PUBLIC_IP}"
echo "RDS Endpoint: ${RDS_ENDPOINT_FULL}"
echo "Database Name: petclinic"
echo "Database Username: admin"
echo "Database Password: Stored in SSM Parameter Store at /${PREFIX}/${ENVIRONMENT}/databases/password/master"
echo "==================================="