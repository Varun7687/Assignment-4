variable "aws_region" {
  description = "AWS region for the Assignment 4 stack."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used in resource names and tags."
  type        = string
  default     = "northwind-assignment-4"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name may contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_cidr" {
  description = "CIDR for the new isolated Assignment 4 VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "availability_zones" {
  description = "Exactly two AZs for the public, app, and database subnet tiers."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Provide exactly two availability zones."
  }
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs, in the same order as availability_zones."
  type        = list(string)
  default     = ["10.40.1.0/24", "10.40.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Provide exactly two public subnet CIDRs."
  }
}

variable "app_subnet_cidrs" {
  description = "Two private application subnet CIDRs, in AZ order."
  type        = list(string)
  default     = ["10.40.11.0/24", "10.40.12.0/24"]

  validation {
    condition     = length(var.app_subnet_cidrs) == 2
    error_message = "Provide exactly two app subnet CIDRs."
  }
}

variable "db_subnet_cidrs" {
  description = "Two private database subnet CIDRs, in AZ order."
  type        = list(string)
  default     = ["10.40.21.0/24", "10.40.22.0/24"]

  validation {
    condition     = length(var.db_subnet_cidrs) == 2
    error_message = "Provide exactly two database subnet CIDRs."
  }
}

variable "enable_nat_gateway" {
  description = "Create NAT Gateway egress for private app instances."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway to reduce cost. Set false for one NAT per AZ."
  type        = bool
  default     = true
}

variable "app_instance_type" {
  description = "EC2 instance type for the app Auto Scaling group."
  type        = string
  default     = "t3.micro"
}

variable "app_min_size" {
  description = "Minimum number of private app instances."
  type        = number
  default     = 2
}

variable "app_desired_capacity" {
  description = "Initial desired number of private app instances."
  type        = number
  default     = 2
}

variable "app_max_size" {
  description = "Maximum number of private app instances."
  type        = number
  default     = 4
}

variable "app_port" {
  description = "Port on which the app instance listens for ALB traffic."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "HTTP path that the deployed app serves with HTTP 200."
  type        = string
  default     = "/health"
}

variable "github_repo_url" {
  description = "Public GitHub repository containing the root-level app.py, requirements.txt, and templates/ files."
  type        = string
  default     = "https://github.com/Varun7687/Assignment-4.git"

  validation {
    condition     = can(regex("^https://github\\.com/", var.github_repo_url))
    error_message = "github_repo_url must be an HTTPS GitHub URL."
  }
}

variable "github_branch" {
  description = "GitHub branch cloned by the EC2 application bootstrap."
  type        = string
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.github_branch))
    error_message = "github_branch contains invalid characters."
  }
}

variable "app_user_data" {
  description = "Optional base64-free user-data script for the app image. Empty deploys the bundled Flask app and initializes MySQL."
  type        = string
  default     = ""
  sensitive   = true
}

variable "mysql_engine_version" {
  description = "Optional MySQL engine version. Empty lets AWS select the current default."
  type        = string
  default     = ""
}

variable "rds_instance_class" {
  description = "RDS instance class required by the assignment."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_master_username" {
  description = "RDS master username. The password is managed by RDS Secrets Manager."
  type        = string
  default     = "northwind_admin"
}

variable "app_db_username" {
  description = "Dedicated least-privilege MySQL username used by Flask."
  type        = string
  default     = "inventory_app"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_]+$", var.app_db_username))
    error_message = "app_db_username may contain only letters, numbers, and underscores."
  }
}

variable "backup_retention_days" {
  description = "Automated backup retention in days."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 7
    error_message = "backup_retention_days must be between 1 and 7."
  }
}

variable "notification_email" {
  description = "Email for the RDS SNS subscription. Leave empty to create the topic without an email subscription."
  type        = string
  default     = ""
}

variable "rds_event_categories" {
  description = "RDS event categories sent to the SNS topic."
  type        = list(string)
  default = [
    "availability",
    "backup",
    "configuration change",
    "failure",
    "low storage",
    "maintenance",
    "notification",
    "recovery",
    "restoration",
  ]
}

variable "deletion_protection" {
  description = "Keep false for the assignment cleanup exercise."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. Keep true only for a disposable lab stack."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply RDS changes immediately instead of during the maintenance window."
  type        = bool
  default     = false
}
