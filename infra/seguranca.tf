# Dois grupos de segurança em cadeia:
#   internet --80--> ALB --3000--> tarefas da API
# As tarefas não aceitam nada que não venha do load balancer.

resource "aws_security_group" "alb" {
  name        = "${var.projeto}-alb"
  description = "Entrada HTTP publica no load balancer"
  vpc_id      = aws_vpc.principal.id

  tags = { Name = "${var.projeto}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP vindo da internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_para_api" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Encaminha para as tarefas da API"
  referenced_security_group_id = aws_security_group.api.id
  ip_protocol                  = "tcp"
  from_port                    = var.porta_container
  to_port                      = var.porta_container
}

resource "aws_security_group" "api" {
  name        = "${var.projeto}-api"
  description = "Tarefas da API: so recebem do ALB"
  vpc_id      = aws_vpc.principal.id

  tags = { Name = "${var.projeto}-api" }
}

resource "aws_vpc_security_group_ingress_rule" "api_do_alb" {
  security_group_id            = aws_security_group.api.id
  description                  = "Trafego vindo do load balancer"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.porta_container
  to_port                      = var.porta_container
}

# Saída liberada: a tarefa precisa baixar a imagem do ECR e mandar logs ao CloudWatch
resource "aws_vpc_security_group_egress_rule" "api_saida" {
  security_group_id = aws_security_group.api.id
  description       = "Saida para ECR e CloudWatch"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
