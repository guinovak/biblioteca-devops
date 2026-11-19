# API da Biblioteca: DevOps na Prática

[![CI](https://github.com/guinovak/biblioteca-devops/actions/workflows/ci.yml/badge.svg)](https://github.com/guinovak/biblioteca-devops/actions/workflows/ci.yml)

Projeto da disciplina **DevOps na Prática** (PUCRS). Uma API REST de biblioteca (livros, empréstimos e devoluções) usada para aplicar integração contínua, containers e infraestrutura como código.

| Fase 1: Configuração e Automação Inicial | Onde está |
|---|---|
| Documentação de planejamento | [`docs/planejamento.md`](docs/planejamento.md) |
| Pipeline de integração contínua (GitHub Actions) | [`.github/workflows/ci.yml`](.github/workflows/ci.yml) |
| Scripts de infraestrutura como código (Terraform) | [`infra/`](infra/) |
| Testes automatizados | [`tests/`](tests/) |

## Rodar localmente

Requer Node.js 24 ou mais recente.

```bash
npm ci
npm start            # API em http://localhost:3000
npm test             # testes
npm run test:coverage
npm run lint
```

Com Docker:

```bash
docker build -t biblioteca-api .
docker run -p 3000:3000 biblioteca-api
```

## Endpoints

| Método | Rota | Descrição |
|---|---|---|
| `GET` | `/health` | Saúde do serviço e versão |
| `GET` | `/livros` | Lista livros (`?disponivel=true` ou `false` para filtrar) |
| `GET` | `/livros/:id` | Consulta um livro |
| `POST` | `/livros` | Cadastra: `{"titulo": "...", "autor": "...", "ano": 1899}` |
| `PUT` | `/livros/:id` | Atualiza título, autor e ano |
| `DELETE` | `/livros/:id` | Remove (não remove livro emprestado) |
| `POST` | `/livros/:id/emprestimo` | Empresta: `{"leitor": "Ana"}` |
| `POST` | `/livros/:id/devolucao` | Registra a devolução |

Exemplo:

```bash
curl -X POST localhost:3000/livros -H 'Content-Type: application/json' \
  -d '{"titulo":"Dom Casmurro","autor":"Machado de Assis","ano":1899}'
curl -X POST localhost:3000/livros/1/emprestimo -H 'Content-Type: application/json' \
  -d '{"leitor":"Ana"}'
```

Os dados ficam em memória: reiniciar a API apaga tudo. Persistência fica para uma próxima fase.

## Pipeline de CI

A cada push e pull request para a `main`:

1. **Qualidade** (Node 24 e 26 em paralelo): `npm ci`, ESLint, testes unitários e de integração com cobertura mínima de 80%.
2. **Imagem** (só se a qualidade passar): build da imagem Docker, container no ar e teste de fumaça.
3. **Infraestrutura** (em paralelo): `terraform fmt`, `init` e `validate`.

Detalhes e justificativas no [plano de integração contínua](docs/planejamento.md#2-plano-de-integração-contínua).

## Estrutura

```
src/
  app.js              montagem da aplicação Express e tratamento de erros
  server.js           sobe o servidor HTTP
  livros/
    repositorio.js    armazenamento em memória
    servico.js        regras de negócio (cadastro, empréstimo, devolução)
    rotas.js          rotas HTTP
tests/
  unit/               regras de negócio
  integration/        API de ponta a ponta com Supertest
infra/                Terraform: VPC, ALB, ECR, ECS Fargate, CloudWatch
docs/                 documentação de planejamento
Dockerfile            imagem de produção (Node 24 Alpine, sem root)
```
