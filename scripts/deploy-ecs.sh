#!/usr/bin/env bash
# Deploy da API no ECS Fargate usando a imagem Docker já testada no pipeline.
#
# O que o script faz, em ordem:
#   1. Copia a imagem do registro do GitHub (GHCR) para o ECR, com a tag do commit.
#      A imagem que vai para produção é exatamente a que passou nos testes
#      (constrói uma vez, implanta a mesma em todo lugar).
#   2. Cria uma nova revisão da task definition do ECS apontando para essa tag.
#   3. Atualiza o serviço do ECS com a nova revisão (rolling update).
#   4. Espera o serviço estabilizar. Se a nova versão não passar no health check,
#      o circuit breaker do ECS volta sozinho para a revisão anterior (rollback).
#   5. Faz um teste de fumaça no endereço público do load balancer.
#
# Uso (no pipeline ou no terminal, com as credenciais da AWS já configuradas):
#   IMAGEM_ORIGEM=ghcr.io/guinovak/biblioteca-devops:<commit> TAG=<commit> ./scripts/deploy-ecs.sh
#
# Variáveis (com os nomes criados pelo Terraform em infra/):
#   IMAGEM_ORIGEM  imagem testada no CI (obrigatória)
#   TAG            tag usada no ECR (obrigatória, normalmente o SHA do commit)
#   REGIAO         padrão us-east-1
#   REPOSITORIO    padrão biblioteca-api
#   CLUSTER        padrão biblioteca-cluster
#   SERVICO        padrão biblioteca-api
#   ALB            padrão biblioteca-alb
#
# Requer: aws CLI v2, docker e jq.

set -euo pipefail

: "${IMAGEM_ORIGEM:?informe IMAGEM_ORIGEM}"
: "${TAG:?informe TAG}"
REGIAO="${REGIAO:-us-east-1}"
REPOSITORIO="${REPOSITORIO:-biblioteca-api}"
CLUSTER="${CLUSTER:-biblioteca-cluster}"
SERVICO="${SERVICO:-biblioteca-api}"
ALB="${ALB:-biblioteca-alb}"

passo() { printf '\n==> %s\n' "$*"; }

passo "1/5 Copiando a imagem testada para o ECR"
CONTA=$(aws sts get-caller-identity --query Account --output text)
REGISTRO="${CONTA}.dkr.ecr.${REGIAO}.amazonaws.com"
IMAGEM_DESTINO="${REGISTRO}/${REPOSITORIO}:${TAG}"

aws ecr get-login-password --region "$REGIAO" \
  | docker login --username AWS --password-stdin "$REGISTRO"
docker pull "$IMAGEM_ORIGEM"
docker tag "$IMAGEM_ORIGEM" "$IMAGEM_DESTINO"
docker tag "$IMAGEM_ORIGEM" "${REGISTRO}/${REPOSITORIO}:latest"
docker push "$IMAGEM_DESTINO"
docker push "${REGISTRO}/${REPOSITORIO}:latest"

passo "2/5 Registrando nova revisão da task definition"
FAMILIA=$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICO" \
  --region "$REGIAO" --query 'services[0].taskDefinition' --output text)

# Copia a revisão atual trocando só a imagem; remove os campos que a AWS
# devolve na leitura mas não aceita no registro
aws ecs describe-task-definition --task-definition "$FAMILIA" --region "$REGIAO" \
  --query taskDefinition \
  | jq --arg img "$IMAGEM_DESTINO" '
      .containerDefinitions[0].image = $img
      | del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
            .compatibilities, .registeredAt, .registeredBy)' \
  > /tmp/task-definition.json

NOVA_REVISAO=$(aws ecs register-task-definition --region "$REGIAO" \
  --cli-input-json file:///tmp/task-definition.json \
  --query 'taskDefinition.taskDefinitionArn' --output text)
echo "Nova revisão: $NOVA_REVISAO"

passo "3/5 Atualizando o serviço do ECS"
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICO" \
  --task-definition "$NOVA_REVISAO" --region "$REGIAO" \
  --query 'service.deployments[0].status' --output text

passo "4/5 Esperando o serviço estabilizar (até 10 minutos)"
aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICO" --region "$REGIAO"

EM_USO=$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICO" \
  --region "$REGIAO" --query 'services[0].taskDefinition' --output text)
if [ "$EM_USO" != "$NOVA_REVISAO" ]; then
  echo "O ECS fez rollback para $EM_USO: a nova versão não passou no health check." >&2
  exit 1
fi

passo "5/5 Teste de fumaça no load balancer"
URL="http://$(aws elbv2 describe-load-balancers --names "$ALB" --region "$REGIAO" \
  --query 'LoadBalancers[0].DNSName' --output text)"

for _ in $(seq 1 20); do
  if curl -sf "$URL/health" | grep -q "\"commit\":\"${TAG}\""; then
    echo "No ar: $URL/health"
    curl -s "$URL/health"; echo
    [ -n "${GITHUB_OUTPUT:-}" ] && echo "url=$URL" >> "$GITHUB_OUTPUT"
    exit 0
  fi
  sleep 6
done

echo "A API não respondeu com o commit $TAG em $URL/health" >&2
exit 1
