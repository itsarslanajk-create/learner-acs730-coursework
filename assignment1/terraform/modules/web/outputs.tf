output "vpc_id" {
  description = "Id of the VPC this configuration created."
  value       = aws_vpc.main.id
}
output "subnet_ids" {
  description = "Public subnet ids, keyed like var.public_subnets."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}
output "web_public_ip" {
  description = "Public IP of the web server. LocalStack invents one; it does not route."
  value       = aws_instance.web.public_ip
}
output "web_url" {
  description = "URL to curl once the instance has booted. Real AWS only."
  value       = "http://${aws_instance.web.public_ip}/"
}

output "ssm_parameter_read" {
  description = "Which SSM parameter (name and version) Terraform read. The value is never output."
  value       = "${data.aws_ssm_parameter.app_secret.name} (version ${data.aws_ssm_parameter.app_secret.version})"
}

output "cpu_alarm_name" {
  description = "Name of the CloudWatch CPU alarm on the web server."
  value       = aws_cloudwatch_metric_alarm.web_cpu_high.alarm_name
}
