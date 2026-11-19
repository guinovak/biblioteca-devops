# API da Biblioteca

[![CI](https://github.com/guinovak/biblioteca-devops/actions/workflows/ci.yml/badge.svg)](https://github.com/guinovak/biblioteca-devops/actions/workflows/ci.yml)

Projeto da disciplina DevOps na Prática (PUCRS). API para cadastrar livros e controlar empréstimos, com pipeline de CI no GitHub Actions e infraestrutura na AWS com Terraform.

- Planejamento: [`docs/planejamento.md`](docs/planejamento.md)
- Pipeline: [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
- Terraform: [`infra/`](infra/)
- Testes: [`tests/`](tests/)

## Como rodar

```bash
npm ci
npm start       # http://localhost:3000
npm test
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
| GET | `/health` | Status da API |
| GET | `/livros` | Lista os livros (`?disponivel=true` filtra) |
| GET | `/livros/:id` | Busca um livro |
| POST | `/livros` | Cadastra um livro (`titulo`, `autor`, `ano`) |
| PUT | `/livros/:id` | Atualiza um livro |
| DELETE | `/livros/:id` | Remove um livro |
| POST | `/livros/:id/emprestimo` | Empresta (`leitor`) |
| POST | `/livros/:id/devolucao` | Devolve |

Os dados ficam em memória, então somem quando a API reinicia.
