# Documentação de Planejamento: Fase 1

DevOps na Prática (PUCRS). Fase 1: Configuração e Automação Inicial.

## 1. Descrição do projeto, objetivos e requisitos

### Descrição

API REST de uma biblioteca, para cadastrar livros e registrar empréstimos e devoluções. O foco do projeto não é a aplicação em si, mas aplicar nela as práticas de DevOps: integração contínua, testes automatizados, container e infraestrutura como código.

Tecnologias: Node.js, Express, Jest, ESLint, Docker, GitHub Actions e Terraform (AWS).

### Objetivos

- Rodar lint e testes automaticamente a cada alteração no código
- Empacotar a aplicação em uma imagem Docker
- Descrever a infraestrutura da AWS com Terraform

### Requisitos funcionais

- Cadastrar, listar, consultar, atualizar e remover livros
- Emprestar um livro para um leitor (um livro emprestado não pode ser emprestado de novo)
- Registrar a devolução
- Endpoint `/health` para saber se a API está no ar

### Requisitos não funcionais

- O pipeline roda a cada push e pull request na `main`
- Cobertura de testes de pelo menos 80%
- Nenhuma senha ou chave no repositório
- A infraestrutura é criada só pelo Terraform, sem configuração manual no console

## 2. Plano de integração contínua

A ferramenta é o **GitHub Actions**, porque já fica no próprio repositório e o pipeline é um arquivo YAML versionado junto com o código ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml)).

**Quando roda:** a cada push na `main` e a cada pull request para a `main`. As mudanças são feitas em branches e entram na `main` por pull request, que só pode ser aceito com o pipeline verde.

**Etapas:**

1. **Lint e testes:** instala as dependências, roda o ESLint e os testes unitários e de integração (Jest e Supertest). Se a cobertura ficar abaixo de 80%, falha.
2. **Imagem Docker:** se os testes passarem, faz o build da imagem, sobe o container e testa se a API responde.
3. **Terraform:** confere a formatação e valida os arquivos da pasta `infra/`.

Se alguma etapa falhar, o GitHub marca o commit ou o pull request com erro e avisa por e-mail.

**Próximas fases:** adicionar a entrega contínua, publicando a imagem no ECR e fazendo o deploy no ECS pelo próprio pipeline.

## 3. Especificação da infraestrutura

A infraestrutura fica na AWS (AWS Academy, região us-east-1) e é criada com Terraform, na pasta [`infra/`](../infra/).

```
Internet → Load Balancer → Container da API (ECS Fargate)
                                 │
                       imagem no ECR, logs no CloudWatch
```

| Recurso | Para que serve |
|---|---|
| VPC com duas sub-redes públicas | Rede do projeto |
| Grupos de segurança | O load balancer aceita a porta 80; a API só aceita conexões vindas do load balancer |
| ECR | Guarda a imagem Docker da API |
| Application Load Balancer | Endereço público da API, com health check em `/health` |
| ECS com Fargate | Roda o container sem precisar administrar servidor (0,25 vCPU e 512 MB) |
| CloudWatch Logs | Logs da aplicação |

Como o AWS Academy não permite criar papéis no IAM, o ECS usa o papel `LabRole`, que já existe no laboratório.

Para não gastar o crédito do laboratório, a ideia é criar a infraestrutura só para testar e depois apagar com `terraform destroy`.
