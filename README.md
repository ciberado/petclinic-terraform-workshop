# PetClinic Terraform Workshop

A hands-on workshop comparing imperative and declarative approaches to Infrastructure as Code (IaC) using AWS and the Spring PetClinic application.

## Overview

This workshop demonstrates two fundamental approaches to cloud infrastructure provisioning:

1. **Imperative Approach** - Direct commands using AWS CLI and shell scripting
2. **Declarative Approach** - Infrastructure as Code using Terraform

Both approaches create identical AWS infrastructure to host the Spring PetClinic application, but they differ significantly in methodology, maintenance, and scalability.

## Architecture

The workshop provisions a complete datacenter infrastructure on AWS:

```
┌─────────────────────────────────────────────────────┐
│                     VPC                             │
│  ┌─────────────────┐    ┌─────────────────────────┐ │
│  │ Public Subnet 1 │    │ Public Subnet 2         │ │
│  │                 │    │                         │ │
│  │ [EC2 Instance]  │    │                         │ │
│  │ PetClinic App   │    │                         │ │
│  └─────────────────┘    └─────────────────────────┘ │
│  ┌─────────────────┐    ┌─────────────────────────┐ │
│  │Private Subnet 1 │    │ Private Subnet 2        │ │
│  │                 │    │                         │ │
│  │                 │    │ [RDS MySQL]             │ │
│  │                 │    │ Database                │ │
│  └─────────────────┘    └─────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### Infrastructure Components

- **VPC** with public and private subnets across 2 availability zones
- **EC2 Instance** running the PetClinic Java application
- **RDS MySQL Database** for application data
- **Security Groups** for network access control
- **Internet Gateway** for public subnet connectivity
- **Application Load Balancer** (optional, in advanced scenarios)

## Prerequisites

Before starting the workshop, ensure you have:

- AWS CLI installed and configured with appropriate permissions
- An AWS account with programmatic access
- Basic understanding of cloud computing concepts
- Familiarity with command line interfaces

### Required AWS Permissions

Your AWS credentials should have permissions for:
- EC2 (instances, security groups, key pairs)
- VPC (networks, subnets, gateways, routes)
- RDS (databases, subnet groups)
- IAM (roles, policies) - for advanced scenarios

## Workshop Structure

### [10-imperative/](10-imperative/) - Shell Script Approach

Learn how infrastructure was provisioned before IaC tools existed:

- **Direct AWS CLI commands** for resource creation
- **Manual dependency management** and resource ordering
- **Error handling** and rollback strategies
- **Resource cleanup** and state management challenges

**Key Learning Outcomes:**
- Understand the complexity of imperative infrastructure management
- Experience manual resource orchestration
- Appreciate the challenges that led to IaC development

### [20-declarative/](20-declarative/) - Terraform Approach

Discover modern Infrastructure as Code practices:

- **Declarative configuration** with HCL (HashiCorp Configuration Language)
- **State management** and change planning
- **Module reusability** and best practices
- **Automated compliance** and security scanning

**Key Learning Outcomes:**
- Master Terraform fundamentals and workflow
- Implement infrastructure best practices
- Understand state management and team collaboration

## Getting Started

### Quick Start Options

#### Option 1: Imperative Approach First
```bash
cd 10-imperative
./create-dc.sh -p myapp -e dev -o yourname -r us-west-2
```

#### Option 2: Declarative Approach First
```bash
cd 20-declarative
terraform init
terraform plan -var="prefix=myapp" -var="owner=yourname"
terraform apply
```

### Workshop Progression

We recommend following the workshop in order:

1. **Start with imperative** to understand the challenges
2. **Move to declarative** to see how Terraform solves them
3. **Compare and contrast** both approaches
4. **Explore advanced Terraform features** for production scenarios

## Cost Considerations

This workshop creates real AWS resources that incur costs:

- **EC2 t3.micro instances** - ~$8-10/month if left running
- **RDS db.t3.micro** - ~$15-20/month
- **VPC and networking** - Minimal costs
- **Data transfer** - Varies based on usage

💰 **Cost Management Tips:**
- Use `terraform destroy` or cleanup scripts when finished
- Set up AWS billing alerts
- Use `spot instances` for development environments
- Consider using AWS Free Tier eligible resources

## Learning Resources

### Terraform Documentation
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [HCL Configuration Language](https://www.terraform.io/docs/language/index.html)

### AWS Resources
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [AWS RDS Documentation](https://docs.aws.amazon.com/rds/)

