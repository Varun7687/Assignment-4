resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id

  tags = {
    Name = "${local.name}-db-subnet-group"
  }
}

resource "aws_db_parameter_group" "mysql" {
  name        = "${local.name}-mysql"
  family      = "mysql8.0"
  description = "Read-only baseline parameter group for ${local.name}."

  tags = {
    Name = "${local.name}-mysql"
  }
}

resource "aws_db_instance" "inventory" {
  identifier = "${local.name}-mysql"

  engine         = "mysql"
  engine_version = var.mysql_engine_version == "" ? null : var.mysql_engine_version
  instance_class = var.rds_instance_class
  db_name        = "inventory"

  username                    = var.rds_master_username
  manage_master_user_password = true

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false
  parameter_group_name   = aws_db_parameter_group.mysql.name

  backup_retention_period = var.backup_retention_days
  backup_window            = "03:00-04:00"
  maintenance_window       = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot    = true

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  apply_immediately   = var.apply_immediately

  tags = {
    Name = "${local.name}-mysql"
  }
}
