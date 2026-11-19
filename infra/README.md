# Infraestrutura (Terraform)

Cria na AWS a rede, o ECR, o load balancer e o serviço ECS Fargate que roda a API.

## Validar (sem AWS)

```bash
terraform init -backend=false
terraform validate
```

## Rodar no AWS Academy

1. Inicie o Learner Lab e copie as credenciais em **AWS Details → AWS CLI**.
2. Exporte no terminal:

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

3. Rode:

```bash
terraform init
terraform plan      # mostra o que vai ser criado
terraform apply     # cria (gera custo)
terraform destroy   # apaga tudo
```

Depois do `apply`, a imagem Docker precisa ser enviada para o ECR (endereço no output `repositorio_ecr`) para o serviço subir.

Obs.: o Learner Lab não deixa criar papéis no IAM, por isso o ECS usa o `LabRole`.
