output "vpc_id" {
  description = "ID of the isolated Assignment 4 VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by the ALB."
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "Private app subnet IDs used by the Auto Scaling group."
  value       = aws_subnet.app[*].id
}

output "db_subnet_ids" {
  description = "Private database subnet IDs in the DB subnet group."
  value       = aws_subnet.db[*].id
}

output "alb_dns_name" {
  description = "Open this DNS name after the app user data is ready."
  value       = aws_lb.app.dns_name
}

output "target_group_name" {
  description = "ALB target group name."
  value       = aws_lb_target_group.app.name
}

output "autoscaling_group_name" {
  description = "Private app Auto Scaling group name."
  value       = aws_autoscaling_group.app.name
}

output "rds_identifier" {
  description = "RDS MySQL instance identifier."
  value       = aws_db_instance.inventory.identifier
}

output "rds_endpoint" {
  description = "Private RDS endpoint; do not expose it publicly."
  value       = aws_db_instance.inventory.address
}

output "rds_port" {
  description = "RDS MySQL port."
  value       = aws_db_instance.inventory.port
}

output "rds_master_user_secret_arn" {
  description = "Secrets Manager ARN managed by RDS for the master password."
  value       = try(aws_db_instance.inventory.master_user_secret[0].secret_arn, null)
  sensitive   = true
}

output "alb_security_group_id" {
  description = "ALB security group ID."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Private app security group ID."
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Private RDS security group ID."
  value       = aws_security_group.db.id
}

output "rds_sns_topic_arn" {
  description = "SNS topic receiving RDS events. Confirm the email subscription manually."
  value       = aws_sns_topic.rds_events.arn
}
