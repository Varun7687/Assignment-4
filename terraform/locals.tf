locals {
  name = var.project_name

  common_tags = {
    Project     = var.project_name
    Assignment  = "4"
    ManagedBy   = "Terraform"
    Environment = "lab"
  }

  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
}
