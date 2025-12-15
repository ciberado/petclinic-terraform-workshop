# Getting Started with Terraform on AWS

## Introduction

Terraform is an Infrastructure as Code (IaC) tool that allows you to define and provision cloud infrastructure using declarative configuration files. Instead of manually clicking through the AWS console to create resources, you describe what you want in code, and Terraform handles the creation, modification, and deletion of those resources automatically.

This guide will walk you through installing Terraform, understanding basic workflows, and implementing security best practices with automated compliance checking.

## Installing Terraform with tfenv

Terraform releases new versions regularly, and different projects may require different versions. Installing Terraform directly can lead to version conflicts when working on multiple projects. You need a way to manage multiple Terraform versions seamlessly.

**tfenv** is a version manager for Terraform, similar to how nvm manages Node.js versions or rbenv manages Ruby versions. It allows you to install and switch between different Terraform versions easily.

```bash
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
mkdir ~/bin
ln -s ~/.tfenv/bin/* ~/bin/
PATH=$PATH:~/bin/
tfenv install 
tfenv use latest
terraform --version
```

This sequence clones the tfenv repository into your home directory, creates a personal bin folder, and links the tfenv executables so they're available in your PATH. The `tfenv install` command reads the project's version requirements (if specified) or installs a default version, while `tfenv use latest` switches to the most recent stable version. Finally, you verify the installation by checking the Terraform version.

## Setting Up a Sample Project

### Getting the Workshop Materials

To learn Terraform effectively, we'll use a practical example: infrastructure for the Spring PetClinic application.

```bash
git clone https://github.com/ciberado/petclinic-terraform-workshop/
cd petclinic-terraform-workshop/20-declarative
```

## Understanding Terraform Configuration Blocks

Before diving into the workflow, it's helpful to understand the basic building blocks of Terraform configurations. Each Terraform file is composed of different types of blocks that serve specific purposes:

### Resource Blocks
```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
}
```
Resources are the core components of your infrastructure - actual cloud services like EC2 instances, S3 buckets, or security groups. Each resource has a type (like `aws_instance`) and a name (like `web`) that you choose.

### Data Blocks
```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
}
```
Data blocks query existing infrastructure or fetch information from your cloud provider. They don't create anything new - they just retrieve data you can use elsewhere in your configuration.

### Variable Blocks
```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}
```
Variables make your configurations flexible and reusable. They define inputs that can be customized when running Terraform commands. In most languages, the equivalent is called *parameter* instead of *variable*.

### Module Blocks
```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "my-vpc"
  cidr   = "10.0.0.0/16"
}
```
Modules are reusable packages of Terraform configuration. They can be your own code or community-maintained modules from the Terraform Registry.

### Provider Blocks
```hcl
provider "aws" {
  region = "us-west-2"
}
```
Providers are plugins that allow Terraform to interact with different cloud platforms, SaaS providers, and APIs. Each provider offers a set of resource types.

### Output Blocks
```hcl
output "instance_ip" {
  value = aws_instance.web.public_ip
}
```
Outputs display important information after Terraform runs, such as IP addresses or resource IDs that you might need for other tools or configurations.

## Basic Terraform Workflow

### Understanding the Plan Phase

You never want to apply infrastructure changes blindly. You need to preview what Terraform will create, modify, or destroy before making actual changes to your cloud environment.

The `terraform plan` command performs a dry-run that shows you exactly what changes Terraform intends to make.

```bash
terraform plan
```

This command compares your Terraform configuration files with the current state of your infrastructure (if any exists) and produces an execution plan. It shows additions (+), changes (~), and deletions (-) without actually modifying anything. However, this basic command assumes all variables have default values defined in your configuration.

### Providing Variables

Real-world infrastructure needs to be customizable. You'll want to deploy the same configuration across different environments (dev, staging, production) or tag resources with ownership information for cost tracking and accountability.

```bash
terraform plan -var environment=dev -var owner=$USER
```

This variation passes specific values for variables directly through the command line. The `-var` flag allows you to override default values or provide required inputs. In this example, we're specifying that we want a development environment and tagging resources with the current user's name.

### Applying Changes

Once you've reviewed the plan and verified it matches your intentions, you need to actually create or modify the infrastructure.

The `terraform apply` command executes the changes.

```bash
terraform apply -var environment=dev -var owner=$USER
```

This command performs the same planning process as before but then prompts for confirmation before proceeding to actually create or modify resources in AWS. Terraform will provision EC2 instances, security groups, load balancers, or whatever resources your configuration defines. The command tracks the state of your infrastructure in a state file, which Terraform uses to understand what currently exists and what needs to change on subsequent runs.

### Destroying Infrastructure

Cloud resources cost money, and development or testing infrastructure should be torn down when not in use. Manual deletion is error-prone and time-consuming.

Terraform can destroy all managed resources in the correct order, respecting dependencies.

```bash
terraform apply -destroy -var environment=dev -var owner=$USER
```

This command (alternatively `terraform destroy`) removes all infrastructure defined in your configuration. Terraform analyzes the dependency graph in reverse order, ensuring that dependent resources are deleted before the resources they depend on. This is particularly important when dealing with networking components, databases, and compute instances that have complex relationships.

## Security and Compliance with Checkov

Infrastructure as Code can inadvertently introduce security vulnerabilities: publicly accessible S3 buckets, unencrypted databases, overly permissive security groups, or missing backup configurations. Manually reviewing Terraform files for security issues is tedious and error-prone, especially in large projects or when multiple team members contribute code.

**Checkov** is an open-source static code analysis tool that scans infrastructure code for security and compliance issues. It checks your Terraform files against hundreds of predefined policies covering AWS best practices, CIS benchmarks, and common security misconfigurations—all before you deploy anything to the cloud.

### Installing Checkov

Checkov is a Python-based tool that can be installed via pip:

```bash
pip install checkov
```

Alternatively, if you prefer isolated environments:

```bash
pip install --user checkov
```

### Running Checkov

Once installed, running Checkov is straightforward. Navigate to your Terraform project directory and execute:

```bash
checkov -d .
```

The `-d` flag specifies the directory to scan (`.` means current directory). Checkov will recursively scan all Terraform files and output a detailed report.

### Understanding Checkov Output

Checkov's output is organized into sections:

- **Passed checks**: Security policies your code complies with (shown in green)
- **Failed checks**: Security issues detected (shown in red)
- **Skipped checks**: Policies you've explicitly chosen to ignore

For each failed check, Checkov provides:
- The specific file and resource with the issue
- A description of the security problem
- The policy ID for reference
- Often, a link to remediation guidance

### Example Output Interpretation

If Checkov reports "Ensure S3 bucket has encryption enabled," it's flagging that one of your S3 bucket resources lacks server-side encryption configuration. You would then update your Terraform code to add the appropriate encryption block before applying the configuration.

### Integrating Checkov into Your Workflow

For best results, run Checkov:
1. **Before committing code** to catch issues early
2. **In CI/CD pipelines** to prevent vulnerable infrastructure from being deployed
3. **Regularly on existing infrastructure** to ensure ongoing compliance

You can suppress specific checks when you have a valid reason using inline comments in your Terraform files, but always document why a security check is being skipped.

## Next Steps

You now have the foundational knowledge to:
- Manage Terraform versions with tfenv
- Preview infrastructure changes safely with `plan`
- Deploy infrastructure with `apply`
- Clean up resources with `destroy`
- Validate security compliance with Checkov


As you progress, explore Terraform modules for code reusability, remote state backends for team collaboration, and workspaces for managing multiple environments. Always remember: infrastructure as code is powerful, but with that power comes the responsibility to implement security best practices from the start.
