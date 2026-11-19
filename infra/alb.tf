# Application Load Balancer: endereço público fixo da API.
# As tarefas do Fargate ganham IP novo a cada deploy; o ALB esconde isso
# e só manda tráfego para tarefa que passou no health check.

resource "aws_lb" "api" {
  name               = "${var.projeto}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.publica[*].id
}

resource "aws_lb_target_group" "api" {
  name        = "${var.projeto}-tg"
  port        = var.porta_container
  protocol    = "HTTP"
  target_type = "ip" # obrigatório para Fargate (rede awsvpc)
  vpc_id      = aws_vpc.principal.id

  # Tempo para terminar requisições em andamento antes de tirar a tarefa
  deregistration_delay = 30

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}
