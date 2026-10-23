resource "aws_sns_topic" "rds_events" {
  name = "${local.name}-rds-events"

  tags = {
    Name = "${local.name}-rds-events"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count = var.notification_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.rds_events.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_db_event_subscription" "rds" {
  name             = "${local.name}-rds-events"
  sns_topic        = aws_sns_topic.rds_events.arn
  source_type      = "db-instance"
  source_ids       = [aws_db_instance.inventory.identifier]
  event_categories = var.rds_event_categories
  enabled          = true

  tags = {
    Name = "${local.name}-rds-event-subscription"
  }
}
