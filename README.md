# Multi-AZ AWS Web Infrastructure

This project demonstrates how to provision a production-style AWS application architecture using Terraform.

The infrastructure deploys a highly available web application across multiple Availability Zones using an Application Load Balancer, Auto Scaling Group and Amazon RDS.

---

# Architecture Overview

The system consists of the following components:

- **VPC** with public and private subnets across two Availability Zones
- **Application Load Balancer (ALB)** for distributing incoming HTTP traffic
- **Auto Scaling Group (ASG)** running EC2 instances in private subnets
- **Amazon RDS PostgreSQL** database deployed with Multi-AZ failover
- **AWS Systems Manager Parameter Store** for storing database configuration
- **CloudWatch alarms and SNS notifications** for infrastructure monitoring

Application instances retrieve database configuration from SSM Parameter Store during startup and connect to the RDS instance.

---

# Architecture Diagram

![Architecture Diagram](diagram.png)

# Terraform Structure

The Terraform code is organised into reusable modules.

modules/
vpc
alb
compute
rds

Each module is responsible for a specific infrastructure component.

| Module   | Purpose                                            |
|----------|----------------------------------------------------|
| VPC      | Networking, subnets, routing, NAT gateway          |
| ALB      | Application Load Balancer and target groups        |
| Compute  | Launch template, Auto Scaling Group, EC2 instances |
| RDS      | PostgreSQL database deployment                     |

---

# Application

A simple Python HTTP server runs on each EC2 instance.

Endpoints include:

| Endpoint | Description                                       |
|----------|---------------------------------------------------|
| /health  | Used by the ALB health check                      |
| /db      | Executes a test query against PostgreSQL          |
| /az      | Returns the Availability Zone serving the request |

---

# Design Decisions

### Private Subnets for Compute

EC2 instances are deployed in private subnets to prevent direct internet access.

Outbound internet connectivity is provided via a NAT Gateway.

---

### Application Load Balancer

The ALB distributes incoming traffic across EC2 instances in multiple Availability Zones, providing high availability.

---

### Auto Scaling Group

An ASG ensures that multiple application instances are always running and can scale based on demand.

---

### RDS Multi-AZ Deployment

RDS is configured with Multi-AZ failover to provide database redundancy and automatic failover in case of an AZ outage.

---

### SSM Parameter Store

Database credentials and connection details are stored in SSM Parameter Store rather than hardcoded into the application.

EC2 instances retrieve these values securely during startup.

---

### CloudWatch Monitoring

CloudWatch alarms monitor CPU utilisation and ALB 5xx errors and publish alerts to SNS topics.

---

# How to Deploy

terraform init
terraform plan
terraform apply

After deployment, the application can be accessed via the ALB DNS name.

---

# Example

curl http://ALB-DNS/health
curl http://ALB-DNS/db
curl http://ALB-DNS/az

---

# Cleanup

terraform destroy

---

# Technologies Used

- AWS
- Terraform
- Python
- Amazon Linux 2023
- PostgreSQL
