# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Terraform module for deploying a secure SSH bastion host on AWS. The bastion provides audited SSH access to private instances via an Auto Scaling Group behind a Network Load Balancer.

**Key Architecture:**
- Users managed via SSH public keys stored in S3 (`/public-keys/` path, named `username.pub`)
- All SSH sessions logged and synced to S3 (`/logs/` path) for compliance
- Auto Scaling Group ensures bastion availability
- Network Load Balancer provides consistent endpoint
- Sessions wrapped in `script` command for recording
- AWS Systems Manager (SSM) support for additional access

## Requirements

- Terraform ~> 1.0
- AWS Provider ~> 4.0

## Development Commands

### Terraform Operations
```bash
terraform init          # Initialize the module
terraform plan          # Preview changes
terraform apply         # Apply infrastructure changes
terraform validate      # Validate configuration syntax
terraform fmt           # Format .tf files
```

### Testing Module Changes
The module is used by declaring it in Terraform configuration. Test by creating a test configuration that calls this module with appropriate variables.

## File Structure

- `main.tf` - Primary resources: IAM roles/policies, security groups, launch template, ASG, NLB, Route53
- `buckets.tf` - S3 bucket for logs and public keys, with KMS encryption
- `user_data.sh` - Bash script provisioning the bastion: SSH recording, user sync, security hardening
- `variables.tf` - Module input variables
- `outputs.tf` - Module outputs
- `locals.tf` - Local values and computed variables
- `data.tf` - Data sources (AMI lookups, subnet info)
- `providers.tf` - Provider version constraints

## Critical Implementation Details

### User Management (`user_data.sh`)
- `sync_users` script runs via cron every 5 minutes
- Fetches public keys from S3 `public-keys/` prefix
- Creates/removes Linux user accounts dynamically
- Usernames must match pattern `^[a-z][-a-z0-9]*$`

### SSH Session Logging
- ForceCommand in sshd_config wraps all sessions in `/usr/bin/bastion/shell`
- Sessions logged with `script` command to `/var/log/bastion/`
- Logs synced to S3 every 5 minutes (if `enable_logs_s3_sync = true`)
- Random suffixes prevent log file name prediction/tampering
- Process listing hidden via `hidepid=2` on /proc

### Security Hardening
- Modern SSH ciphers based on Mozilla OpenSSH guidelines + Amazon Linux 2023
- Public key authentication only (password auth disabled)
- X11 forwarding disabled
- Remote commands blocked by default (unless `allow_ssh_commands = true`)
- Automatic security updates via daily cron job

### Conditional Resource Creation
- Load balancer optional via `create_elb` variable
- Security groups optional via `create_security_groups` variable
- DNS record optional via `create_dns_record` variable
- Multiple count-based conditionals throughout - be careful with indexing

### IAM Configuration
- Bastion role assumes from both `ec2.amazonaws.com` and `ssm.amazonaws.com`
- Policy grants S3 access (read public-keys, write logs) and KMS encrypt/decrypt
- SSM policy (`AmazonSSMManagedInstanceCore`) attached for Systems Manager access

### Instance Metadata
- Configurable IMDSv2 enforcement via `use_imds_v2`
- Default hop limit of 1 (increase for container workloads)

## Common Modification Patterns

### Adding new user_data customization
Use the `extra_user_data_content` variable - content is appended at end of `user_data.sh`

### Changing SSH configuration
Modify the heredocs in `user_data.sh` that write to `/etc/ssh/sshd_config` or `/etc/crypto-policies/back-ends/opensshserver.config`

### Adjusting IAM permissions
Edit the policy document in `data.aws_iam_policy_document.bastion_host_policy_document` in `main.tf:107-147`

### Modifying log retention
Adjust `log_standard_ia_days`, `log_glacier_days`, `log_expiry_days` variables and ensure `log_auto_clean = true`
