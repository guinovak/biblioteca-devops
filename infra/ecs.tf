# O Learner Lab não deixa criar papéis no IAM, então usamos o LabRole
data "aws_iam_role" "lab" {
  name = var.papel_lab
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.projeto}-api"
  retention_in_days = var.dias_retencao_logs
}

resource "aws_ecs_cluster" "principal" {
  name = "${var.projeto}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.projeto}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memoria
  execution_role_arn       = data.aws_iam_role.lab.arn
  task_role_arn            = data.aws_iam_role.lab.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "api"
    image     = "${aws_ecr_repository.api.repository_url}:${var.tag_imagem}"
    essential = true

    portMappings = [{
      containerPort = var.porta_container
      protocol      = "tcp"
    }]

    environment = [
      { name = "PORT", value = tostring(var.porta_container) },
      { name = "NODE_ENV", value = "production" },
    ]

    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:${var.porta_container}/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.api.name
        awslogs-region        = var.regiao
        awslogs-stream-prefix = "api"
      }
    }
  }])
}

resource "aws_ecs_service" "api" {
  name            = "${var.projeto}-api"
  cluster         = aws_ecs_cluster.principal.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.quantidade_tarefas
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # volta para a versão anterior se a nova não subir
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = aws_subnet.publica[*].id
    security_groups  = [aws_security_group.api.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = var.porta_container
  }

  health_check_grace_period_seconds = 30

  # a revisão da task definition em uso é trocada pelo pipeline de CD
  # (scripts/deploy-ecs.sh); o Terraform não deve desfazer esse deploy
  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener.http]
}
