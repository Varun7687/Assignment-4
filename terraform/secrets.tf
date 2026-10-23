resource "random_password" "app_db" {
  length           = 32
  special          = false
  override_special = ""
}

resource "aws_secretsmanager_secret" "app_db" {
  name                    = "${local.name}/app-db"
  description             = "Dedicated inventory application database credentials."
  recovery_window_in_days = 0

  tags = {
    Name = "${local.name}-app-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "app_db" {
  secret_id = aws_secretsmanager_secret.app_db.id

  secret_string = jsonencode({
    username = var.app_db_username
    password = random_password.app_db.result
    database = "inventory"
  })
}
