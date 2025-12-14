# Building AWS Infrastructure with Imperative Shell Commands

## Introduction

Before Infrastructure as Code (IaC) tools like Terraform became popular, cloud infrastructure was provisioned using imperative commands—direct API calls that tell the cloud provider exactly what to do, step by step. This approach involves manually orchestrating the creation of each resource in the correct order, handling dependencies, and managing the complex relationships between components.

This guide demonstrates how to build a complete AWS datacenter environment for the Spring PetClinic application using the AWS CLI and shell scripting. You'll learn how imperative infrastructure provisioning works, understand the challenges it presents, and see why declarative tools like Terraform were developed to address these limitations.

The `create-dc.sh` script in this directory creates a full datacenter infrastructure including VPC networking, security groups, EC2 instances, and RDS databases—all using direct AWS CLI commands.

## The create-dc.sh Script Overview

The `create-dc.sh` script creates a complete datacenter infrastructure for hosting the PetClinic application. Here's what it builds:

```
┌─────────────────────────────────────────────────────┐
│                     VPC                             │
│  ┌─────────────────┐    ┌─────────────────────────┐ │
│  │ Public Subnet 1 │    │ Public Subnet 2         │ │
│  │                 │    │                         │ │
│  │                 │    │                         │ │
│  │ [EC2 Instance]  │    │                         │ │
│  │ PetClinic App   │    │                         │ │
│  └─────────────────┘    └─────────────────────────┘ │
│  ┌─────────────────┐    ┌─────────────────────────┐ │
│  │Private Subnet 1 │    │ Private Subnet 2        │ │
│  │                 │    │                         │ │
│  │                 │    │                         │ │
│  │                 │    │ [RDS MySQL]             │ │
│  │                 │    │ Database                │ │
│  └─────────────────┘    └─────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

## Script Configuration and Usage

### Command Line Options

The script accepts several parameters to customize the infrastructure:

```bash
./create-dc.sh [options]
```

Available options:
- `-p PREFIX` - Application prefix (default: petclinic)
- `-e ENVIRONMENT` - Environment name (default: dev)
- `-o OWNER` - Owner name for resource tagging (default: anonymous)
- `-r REGION` - AWS region (default: us-east-1)
- `-v VPC_ADDR_PREFIX` - VPC address prefix (default: 10.0)
- `-a APP_INSTANCE_TYPE` - EC2 instance type (default: t3.micro)
- `-d RDS_INSTANCE_TYPE` - RDS instance type (default: db.t3.micro)
- `-h` - Show help message

### Example Usage

Create infrastructure with custom settings:

```bash
./create-dc.sh -p petclinic -e production -o alice -r us-west-2
```

This creates infrastructure with:
- Resources prefixed with "petclinic"
- Environment tagged as "production"
- Owner tagged as "alice"
- Deployed in the us-west-2 region

## Challenges of Imperative Infrastructure

### Dependency Management

Every resource depends on others being created first. The script must:
- Create the VPC before subnets
- Create subnets before instances
- Create security groups before applying them to instances
- Wait for the database to be ready before storing its endpoint

**Error Handling**: If any step fails, subsequent steps will also fail, often in confusing ways.

### State Tracking

The script uses shell variables to track resource IDs, but this information is lost when the script ends. There's no built-in way to:
- Know what resources were created
- Update existing infrastructure
- Clean up resources later

### Idempotency Issues

Running the script twice will attempt to create duplicate resources, causing errors. The script doesn't check if resources already exist.

### Complexity Growth

As infrastructure grows, imperative scripts become exponentially more complex:
- More error handling needed
- More dependency tracking required
- Harder to maintain and modify
- Difficult to collaborate on

## When to Use Imperative Approaches

Despite the challenges, imperative infrastructure has its place, mostly in automating operations. For example, it is common and useful to write a script that can be run in the case that an instance has been compromised, isolating it by updating its security group and generates a snapshot of the EBS volumes.

## Running the Script

### Prerequisites

Ensure you have:
- AWS CLI installed and configured with appropriate credentials
- Bash shell environment
- Internet connectivity for downloading the PetClinic application

### Install the AWS CLI

To invoke the AWS Api we will use the `aws` tool:

```bash
sudo apt update && sudo apt upgrade -y 
sudo apt install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

```bash
aws --version
```

### Getting the Workshop Materials

To learn Terraform effectively, we'll use a practical example: infrastructure for the Spring PetClinic application.

```bash
git clone https://github.com/ciberado/petclinic-terraform-workshop/
cd petclinic-terraform-workshop/10-imperative
```


### Execution

1. **Make the script executable**:
```bash
chmod +x create-dc.sh
```

2. **Run with default settings**:
```bash
./create-dc.sh
```

3. **Run with custom configuration**:
```bash
./create-dc.sh -p myproject -e staging -o yourname -r us-west-2
```

4. **Monitor the output** for any errors and note the final summary with connection details.

### Expected Output

The script provides detailed progress information and concludes with a summary:

```
===================================
Infrastructure creation completed!
===================================
VPC ID: vpc-0abc123def456
Public Subnets: subnet-0123abc, subnet-0456def
Private Subnets: subnet-0789ghi, subnet-0abc123
App Security Group: sg-0def456abc
RDS Security Group: sg-0ghi789def
EC2 Instance ID: i-0abcdef123456789
EC2 Public IP: 54.123.45.67
RDS Endpoint: petclinicdb.abcd1234.us-east-1.rds.amazonaws.com:3306
Database Name: petclinic
Database Username: admin
Database Password: Stored in SSM Parameter Store
===================================
```

### Accessing the Application

Once the script completes and the instance finishes bootstrapping (2-3 minutes), you can access the PetClinic application by navigating to the public IP address shown in the output.

## Cleanup Considerations

**Important**: The script creates resources but doesn't provide a cleanup mechanism. To avoid ongoing charges, you must manually delete the resources through the AWS console or create a separate cleanup script.

Resources to delete (in order):
1. EC2 instances
2. RDS instances
3. Security groups
4. Subnets
5. Route tables
6. Internet gateways
7. VPC

## Next Steps

After understanding imperative infrastructure:

1. **Compare with declarative approaches** in the `20-declarative` directory
2. **Experiment with modifications** to see how complexity grows
3. **Study Infrastructure as Code tools** like Terraform that solve these challenges
4. **Practice cloud API fundamentals** for better understanding of declarative tools

Understanding imperative infrastructure provides the foundation for appreciating why declarative tools like Terraform were developed and how they solve the challenges you've experienced with this script.

## Step-by-Step Infrastructure Creation

### 1. VPC Creation: The Foundation

The script starts by creating a Virtual Private Cloud (VPC), which provides an isolated network environment:

```bash
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "${VPC_ADDR_PREFIX}.0.0/16" \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PREFIX}-vpc}]" \
  --query 'Vpc.VpcId' \
  --output text \
  --region ${REGION})
```

This creates a VPC with:
- A large IP address space (65,536 addresses)
- Proper tagging for identification
- DNS hostname resolution enabled

**Key Challenge**: The script must capture the VPC ID from the response to use in subsequent commands. This dependency tracking is something you must handle manually in imperative scripts.

### 2. Internet Gateway: External Connectivity

Next, the script creates an Internet Gateway and attaches it to the VPC:

```bash
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PREFIX}-igw}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text \
  --region ${REGION})

aws ec2 attach-internet-gateway \
  --vpc-id ${VPC_ID} \
  --internet-gateway-id ${IGW_ID} \
  --region ${REGION}
```

**Important**: Creating and attaching are separate operations. If the script fails between these steps, you'd have an orphaned Internet Gateway.

### 3. Subnet Architecture: Public and Private Zones

The script creates four subnets across two availability zones:

```bash
# Public Subnet 1 (can reach internet directly)
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id ${VPC_ID} \
  --cidr-block "${VPC_ADDR_PREFIX}.100.0/24" \
  --availability-zone "${REGION}a" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PREFIX}-public-1}]" \
  --query 'Subnet.SubnetId' \
  --output text \
  --region ${REGION})
```

This pattern repeats for:
- **Public subnets** (100.0/24, 101.0/24): For resources that need direct internet access
- **Private subnets** (200.0/24, 201.0/24): For resources that should be isolated

**Design Decision**: Two availability zones provide redundancy. If one AZ goes down, resources in the other can continue operating.

### 4. Routing Configuration: Traffic Direction

The script creates a route table and associates it with public subnets:

```bash
PUBLIC_RT=$(aws ec2 create-route-table \
  --vpc-id ${VPC_ID} \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PREFIX}-public-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text \
  --region ${REGION})

# Route all traffic (0.0.0.0/0) to the Internet Gateway
aws ec2 create-route \
  --route-table-id ${PUBLIC_RT} \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id ${IGW_ID} \
  --region ${REGION}
```

**Critical Relationship**: Each subnet must be explicitly associated with a route table, or it won't know how to route traffic.

### 5. Security Groups: Firewall Rules

Security groups act as virtual firewalls. The script creates two:

**Application Security Group** (allows web traffic):
```bash
APP_SG_ID=$(aws ec2 create-security-group \
  --group-name "${PREFIX}_app_sg" \
  --description "Petclinic security group" \
  --vpc-id ${VPC_ID} \
  --query 'GroupId' \
  --output text \
  --region ${REGION})

# Allow HTTP traffic
aws ec2 authorize-security-group-ingress \
  --group-id ${APP_SG_ID} \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region ${REGION}
```

**Database Security Group** (allows database access only from app servers):
```bash
RDS_SG_ID=$(aws ec2 create-security-group \
  --group-name "${PREFIX}_rds_mysql_sg" \
  --description "Database security group for mysql" \
  --vpc-id ${VPC_ID} \
  --query 'GroupId' \
  --output text \
  --region ${REGION})

# Allow MySQL access only from app security group
aws ec2 authorize-security-group-ingress \
  --group-id ${RDS_SG_ID} \
  --protocol tcp \
  --port 3306 \
  --source-group ${APP_SG_ID} \
  --region ${REGION}
```

**Security Best Practice**: The database only accepts connections from application servers, not from the entire internet.

### 6. Secrets Management: Database Passwords

The script generates a secure random password and stores it in AWS Systems Manager Parameter Store:

```bash
DB_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-10)

aws ssm put-parameter \
  --name "/${PREFIX}/${ENVIRONMENT}/databases/password/master" \
  --description "Initial password for the database" \
  --type "SecureString" \
  --value "${DB_PASSWORD}" \
  --overwrite \
  --region ${REGION}
```

**Why Parameter Store?** Storing passwords in scripts or environment variables is insecure. Parameter Store encrypts secrets and provides audit trails.

### 7. Database Infrastructure

Before creating the RDS instance, the script must create a DB subnet group:

```bash
aws rds create-db-subnet-group \
  --db-subnet-group-name "${PREFIX,,}databasesubnetgroup" \
  --db-subnet-group-description "Database subnet group" \
  --subnet-ids ${PRIVATE_SUBNET_1} ${PRIVATE_SUBNET_2} \
  --region ${REGION}
```

Then it creates the MySQL database:

```bash
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
  --region ${REGION}
```

**Time Consideration**: RDS creation takes 5-10 minutes. The script waits for completion before proceeding.

### 8. Application Server Deployment

The script finds the latest Ubuntu AMI and launches an EC2 instance:

```bash
# Find latest Ubuntu 22.04 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region ${REGION})
```

The instance is launched with user data that automatically installs and starts the PetClinic application:

```bash
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ${AMI_ID} \
  --instance-type ${APP_INSTANCE_TYPE} \
  --subnet-id ${PUBLIC_SUBNET_1} \
  --security-group-ids ${APP_SG_ID} \
  --associate-public-ip-address \
  --iam-instance-profile Name=LabInstanceProfile \
  --user-data "${USER_DATA}" \
  --region ${REGION})
```

## Understanding the User Data Script

The [userdata.sh](userdata.sh) file contains the bootstrap script that runs when the EC2 instance first starts:

```bash
#!/bin/bash
apt update
apt install jq awscli openjdk-17-jdk -y

FILE=spring-petclinic-4.0.0-SNAPSHOT.jar
wget https://github.com/ciberado/petclinic-terraform-workshop/releases/download/binary-4.0/$FILE

java -Dserver.port=80 -jar $FILE
```

This script:
1. **Updates the package manager** to get the latest package information
2. **Installs required software**: JSON processor, AWS CLI, and Java 17
3. **Downloads the PetClinic application** as a pre-built JAR file
4. **Starts the application** on port 80 (HTTP)

**Important**: The application starts automatically when the instance boots, making it immediately available once the infrastructure is ready.
