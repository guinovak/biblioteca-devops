# Monitoramento no CloudWatch: alarmes e painel da API.
# Métricas das aulas 6 e 7: utilização de recursos, taxa de erro,
# disponibilidade e tempo de resposta.

locals {
  alb_dimensao = aws_lb.api.arn_suffix
  tg_dimensao  = aws_lb_target_group.api.arn_suffix
}

# Utilização de recursos: CPU média do serviço acima de 80% por 10 minutos
resource "aws_cloudwatch_metric_alarm" "cpu_alta" {
  alarm_name          = "${var.projeto}-api-cpu-alta"
  alarm_description   = "CPU média do serviço ECS acima de 80% por 10 minutos"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.principal.name
    ServiceName = aws_ecs_service.api.name
  }
}

# Taxa de erro: respostas 5xx da API
resource "aws_cloudwatch_metric_alarm" "erros_5xx" {
  alarm_name          = "${var.projeto}-api-erros-5xx"
  alarm_description   = "Mais de 5 respostas 5xx da API em 5 minutos"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = local.alb_dimensao
  }
}

# Disponibilidade: nenhuma tarefa saudável atrás do load balancer
resource "aws_cloudwatch_metric_alarm" "sem_tarefa_saudavel" {
  alarm_name          = "${var.projeto}-api-indisponivel"
  alarm_description   = "Nenhuma tarefa saudável no target group por 2 minutos"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = local.alb_dimensao
    TargetGroup  = local.tg_dimensao
  }
}

resource "aws_cloudwatch_dashboard" "api" {
  dashboard_name = "${var.projeto}-api"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "CPU e memória do serviço (%)"
          region = var.regiao
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.principal.name, "ServiceName", aws_ecs_service.api.name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.principal.name, "ServiceName", aws_ecs_service.api.name],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Tempo de resposta (s)"
          region = var.regiao
          stat   = "p95"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_dimensao],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "Requisições e erros"
          region = var.regiao
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_dimensao],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", local.alb_dimensao],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.alb_dimensao],
          ]
        }
      },
      {
        type = "log", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "Últimos logs da API"
          region = var.regiao
          query  = "SOURCE '${aws_cloudwatch_log_group.api.name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          view   = "table"
        }
      },
    ]
  })
}
