# Registro das imagens Docker da API (o "Docker Hub privado" da AWS, aula 4)

resource "aws_ecr_repository" "api" {
  name                 = "${var.projeto}-api"
  image_tag_mutability = "MUTABLE" # permite mover a tag "latest"
  force_delete         = true      # terraform destroy apaga mesmo com imagens dentro

  # Procura vulnerabilidades conhecidas em cada imagem enviada
  image_scanning_configuration {
    scan_on_push = true
  }
}

# Guarda só as 10 imagens mais recentes: o armazenamento do ECR é cobrado
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Manter as 10 imagens mais recentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
