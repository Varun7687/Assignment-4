data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.name}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${local.name}-app-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name}-app-profile"
  role = aws_iam_role.app.name

  tags = {
    Name = "${local.name}-app-profile"
  }
}


data "aws_iam_policy_document" "app_secrets" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.app_db.arn,
      aws_db_instance.inventory.master_user_secret[0].secret_arn,
    ]
  }
}

resource "aws_iam_role_policy" "app_secrets" {
  name   = "${local.name}-app-secrets"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_secrets.json
}
