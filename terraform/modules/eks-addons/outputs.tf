output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = var.install_aws_load_balancer_controller ? aws_iam_role.alb_controller[0].arn : null
}
