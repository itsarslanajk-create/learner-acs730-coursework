# Task 6: the app secret lives in SSM Parameter Store. It is created once,
# out of band, with aws ssm put-parameter (see REPORT.md). Terraform only
# READS it -- a resource that also created it would be circular and would
# fail on a fresh environment where the parameter does not exist yet.
data "aws_ssm_parameter" "app_secret" {
  name            = var.ssm_parameter_name
  with_decryption = true
}
