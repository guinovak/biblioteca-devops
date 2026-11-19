# Infraestrutura como código (Terraform)

Scripts que criam, na AWS, tudo o que a API da biblioteca precisa para rodar em containers:

| Arquivo | O que cria |
|---|---|
| `versions.tf` | Versão do Terraform, provider AWS e etiquetas padrão |
| `variables.tf` | Parâmetros (região, tamanho da tarefa, quantidade de tarefas...) |
| `rede.tf` | VPC, duas sub-redes públicas, internet gateway e rotas |
| `seguranca.tf` | Grupos de segurança do load balancer e da API |
| `ecr.tf` | Repositório de imagens Docker com varredura de vulnerabilidades |
| `alb.tf` | Application Load Balancer, target group e listener HTTP |
| `ecs.tf` | Cluster ECS, definição de tarefa Fargate, serviço e grupo de logs |
| `outputs.tf` | Endereço da API, repositório ECR e nomes úteis |

A especificação completa, com diagrama, decisões e custos, está em [`docs/planejamento.md`](../docs/planejamento.md#3-especificação-da-infraestrutura).

## Validar sem a AWS

Não precisa de credencial nem gera custo. É o que o pipeline de CI roda a cada push.

```bash
cd infra
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

## Provisionar no AWS Academy Learner Lab

### 1. Abrir o laboratório e pegar as credenciais

1. Em `awsacademy.instructure.com`, abra o curso → **Módulos** → **Learner Lab** → **Start Lab**. Espere o ícone ao lado de "AWS" ficar verde.
2. Clique em **AWS Details** → **AWS CLI: Show**. Aparecem três valores: `aws_access_key_id`, `aws_secret_access_key` e `aws_session_token`.
3. No terminal, exporte os três (eles mudam a cada sessão do laboratório):

```bash
export AWS_ACCESS_KEY_ID="cole aqui"
export AWS_SECRET_ACCESS_KEY="cole aqui"
export AWS_SESSION_TOKEN="cole aqui"
export AWS_REGION="us-east-1"
```

Nunca coloque esses valores em arquivo do repositório.

### 2. Conferir o plano (sem custo)

```bash
cd infra
terraform init
terraform plan
```

O `plan` consulta a conta de verdade e lista os recursos que seriam criados, sem criar nada. Ele prova que os scripts funcionam contra a AWS do laboratório.

### 3. Criar a infraestrutura (gera custo: ~US$ 0,06 por hora)

```bash
terraform apply
```

Confirme com `yes`. Leva uns 3 a 5 minutos. No fim aparecem os *outputs*, entre eles `url_api` e `repositorio_ecr`.

### 4. Enviar a imagem da API para o ECR

O serviço só fica saudável depois que existe uma imagem no ECR. Numa máquina com Docker e AWS CLI, na raiz do repositório:

```bash
REPO=$(terraform -chdir=infra output -raw repositorio_ecr)
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin "${REPO%%/*}"
docker build --platform linux/amd64 -t "$REPO:latest" .
docker push "$REPO:latest"
aws ecs update-service --cluster biblioteca-cluster --service biblioteca-api --force-new-deployment
```

Em um ou dois minutos, `curl $(terraform -chdir=infra output -raw url_api)/health` responde `{"status":"ok",...}`.

> Na próxima fase, este passo sai da mão e passa para o pipeline (entrega contínua).

### 5. Destruir ao terminar

```bash
terraform destroy
```

O crédito do laboratório é de US$ 50 para o curso inteiro. Destrua sempre que terminar de usar e clique em **End Lab**. Para só desligar a API, mantendo o resto:

```bash
terraform apply -var="quantidade_tarefas=0"
```

## Restrições do Learner Lab que o código já respeita

- **Não é permitido criar papéis no IAM.** Por isso `ecs.tf` usa o `LabRole` existente (`data "aws_iam_role"`) em vez de `aws_iam_role`.
- **As credenciais são temporárias** e incluem `AWS_SESSION_TOKEN`.
- **Região `us-east-1`**, padrão da variável `regiao`.
