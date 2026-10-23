data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${local.name}-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.app_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(
    var.app_user_data == ""
    ? templatefile("${path.module}/user-data-app.sh.tftpl", {
        aws_region            = var.aws_region
        github_repo_url       = var.github_repo_url
        github_branch         = var.github_branch
        rds_master_secret_arn = aws_db_instance.inventory.master_user_secret[0].secret_arn
        app_db_secret_arn     = aws_secretsmanager_secret.app_db.arn
        rds_host              = aws_db_instance.inventory.address
        rds_port              = aws_db_instance.inventory.port
        schema_b64            = filebase64("${path.module}/../sql/schema.sql")
        seed_b64              = filebase64("${path.module}/../sql/seed.sql")
      })
    : var.app_user_data
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${local.name}-app"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${local.name}-app-volume"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${local.name}-asg"
  min_size            = var.app_min_size
  desired_capacity    = var.app_desired_capacity
  max_size            = var.app_max_size
  vpc_zone_identifier = aws_subnet.app[*].id
  target_group_arns    = [aws_lb_target_group.app.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300
  force_delete               = false

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${local.name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50
  }
}
