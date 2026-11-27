output "url_api" {
  description = "Endereço público da API (teste com /health)."
  value       = "http://${aws_lb.api.dns_name}"
}

output "repositorio_ecr" {
  description = "Para onde enviar a imagem Docker (docker push)."
  value       = aws_ecr_repository.api.repository_url
}

output "cluster_ecs" {
  description = "Nome do cluster ECS."
  value       = aws_ecs_cluster.principal.name
}

output "servico_ecs" {
  description = "Nome do serviço ECS (usado para forçar um novo deploy)."
  value       = aws_ecs_service.api.name
}

output "grupo_de_logs" {
  description = "Onde ler os logs da API no CloudWatch."
  value       = aws_cloudwatch_log_group.api.name
}

output "painel_cloudwatch" {
  description = "Painel de monitoramento da API no CloudWatch."
  value       = "https://${var.regiao}.console.aws.amazon.com/cloudwatch/home?region=${var.regiao}#dashboards/dashboard/${aws_cloudwatch_dashboard.api.dashboard_name}"
}
