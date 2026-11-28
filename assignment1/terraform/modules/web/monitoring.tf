# Task 7: alarm on a real metric of the deployed instance. CPU is reported
# even when the server is idle, so the alarm leaves INSUFFICIENT_DATA.
resource "aws_cloudwatch_metric_alarm" "web_cpu_high" {
  alarm_name          = "${local.name}-web-cpu-high"
  alarm_description   = "Average CPU of the ${var.environment} web server above ${var.cpu_alarm_threshold}%"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.cpu_alarm_threshold
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = merge(local.common_tags, { Name = "${local.name}-web-cpu-high" })
}
