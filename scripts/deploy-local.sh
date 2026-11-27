#!/usr/bin/env bash
# Sobe a API num container local com Docker Compose e confere se ela responde.
# É o mesmo teste de fumaça que o pipeline roda no ambiente de staging.
#
# Uso:
#   ./scripts/deploy-local.sh            # constrói a imagem a partir do código
#   IMAGEM=ghcr.io/guinovak/biblioteca-devops:latest ./scripts/deploy-local.sh
#                                        # usa a imagem publicada pelo pipeline
#   docker compose down                  # derruba
#
# Requer: Docker com o plugin compose e curl.

set -euo pipefail

URL="http://localhost:${PORTA:-3000}"

if [ -n "${IMAGEM:-}" ]; then
  echo "==> Usando a imagem publicada: $IMAGEM"
  docker compose pull api
  docker compose up -d --no-build api
else
  echo "==> Construindo a imagem a partir do código"
  docker compose up -d --build api
fi

echo "==> Esperando a API responder em $URL/health"
for _ in $(seq 1 30); do
  curl -sf "$URL/health" >/dev/null && break
  sleep 1
done
curl -sf "$URL/health"; echo

echo "==> Teste de fumaça: cadastrar e listar um livro"
curl -sf -X POST "$URL/livros" -H 'Content-Type: application/json' \
  -d '{"titulo":"Dom Casmurro","autor":"Machado de Assis","ano":1899}' >/dev/null
curl -sf "$URL/livros" | grep -q 'Dom Casmurro'
echo "API no ar em $URL"
