# VPC com duas sub-redes públicas (o load balancer precisa de duas zonas)

data "aws_availability_zones" "disponiveis" {
  state = "available"
}

locals {
  zonas = slice(data.aws_availability_zones.disponiveis.names, 0, 2)
}

resource "aws_vpc" "principal" {
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.projeto}-vpc" }
}

resource "aws_internet_gateway" "principal" {
  vpc_id = aws_vpc.principal.id

  tags = { Name = "${var.projeto}-igw" }
}

resource "aws_subnet" "publica" {
  count = length(local.zonas)

  vpc_id                  = aws_vpc.principal.id
  availability_zone       = local.zonas[count.index]
  cidr_block              = cidrsubnet(var.cidr_vpc, 8, count.index)
  map_public_ip_on_launch = true

  tags = { Name = "${var.projeto}-publica-${local.zonas[count.index]}" }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.principal.id
  }

  tags = { Name = "${var.projeto}-rotas-publicas" }
}

resource "aws_route_table_association" "publica" {
  count = length(aws_subnet.publica)

  subnet_id      = aws_subnet.publica[count.index].id
  route_table_id = aws_route_table.publica.id
}
