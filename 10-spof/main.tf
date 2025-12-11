module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.prefix}-vpc"
  cidr = "${var.vpc_addr_prefix}.0.0/16"

  azs = ["${var.region}a", "${var.region}b"]

  public_subnets  = ["${var.vpc_addr_prefix}.100.0/24", "${var.vpc_addr_prefix}.101.0/24"]
  private_subnets = ["${var.vpc_addr_prefix}.200.0/24", "${var.vpc_addr_prefix}.201.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = false

  tags = {
    Layer : "network fabric"
  }
}

resource "aws_security_group" "app_sg" {
  name        = "${var.prefix}_app_sg"
  description = "Petclinic security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from Anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from Anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Layer : "network fabric"
  }
}


// IAM

/*

The Academy lab environment doesn't allow to attach policies or to manage roles, so 
this section is stated for reference only.

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "ssm_params_policy" {
  name        = "systems-manager-params-read-policy"
  description = "A test policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeParameters"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameters"
            ],
            "Resource": "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.prefix}/${var.environment}*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ssm_read_only_policy-attach" {
  role       = "LabRole"
  policy_arn = aws_iam_policy.ssm_params_policy.arn
}

*/


// Computing

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] /* Ubuntu */

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.app_instance_type

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true

  iam_instance_profile = "LabInstanceProfile"

  user_data = replace(
                replace(
                  file("userdata.sh"), "__PREFIX__", "${var.prefix}"),
                       "__ENVIRONMENT__", "${var.environment}")

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }
  volume_tags = {
    Name = "${var.prefix}-${lower(var.owner)}"
  }

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  tags = {
    Name = "${var.prefix}-${lower(var.owner)}"
    Layer : "computing"
  }
}

// Database

resource "random_password" "dbpassword" {
  length  = 10
  special = true
}

resource "aws_ssm_parameter" "rdssecret" {
  name        = "/${var.prefix}/${var.environment}/databases/password/master"
  description = "Initial password for the database"
  type        = "SecureString"
  value       = random_password.dbpassword.result
  overwrite   = true
}

module "rds_mysql_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${var.prefix}_rds_mysql_sg"
  description = "Database security group for mysql"
  vpc_id      = module.vpc.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "Mysql access from within VPC"

      source_security_group_id = aws_security_group.app_sg.id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]
  tags = {
    Layer : "database"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${lower(var.prefix)}databasesubnetgroup"
  subnet_ids = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]

  tags = {
    Layer : "computing"
  }
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "${lower(var.prefix)}db"

  engine               = "mysql"
  engine_version       = "5.7"
  family               = "mysql5.7"
  major_engine_version = "5.7"
  instance_class       = var.rds_instance_type

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name                = "petclinic"
  username               = "admin"
  password               = random_password.dbpassword.result

  port = 3306

  multi_az               = false
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [module.rds_mysql_sg.security_group_id]


  tags = {
    Layer : "database"
  }
}

resource "aws_ssm_parameter" "rdsendpoint" {
  name        = "/${var.prefix}/${var.environment}/databases/endpoint"
  description = "RDS endpoint"
  type        = "String"
  value       = module.db.db_instance_endpoint
  overwrite   = true
}