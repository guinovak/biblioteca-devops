# Documentação de Planejamento: Fase 1

DevOps na Prática (PUCRS). Fase 1: Configuração e Automação Inicial.

## 1. Descrição do projeto, objetivos e requisitos

### Descrição

API REST de uma biblioteca, para cadastrar livros e registrar empréstimos e devoluções. O foco do projeto não é a aplicação em si, mas aplicar nela as práticas de DevOps: integração contínua, testes automatizados, container e infraestrutura como código.

Tecnologias: Node.js 24, Express 5, Jest e Supertest (testes), ESLint (lint), Docker, GitHub Actions e Terraform (AWS).

### Objetivos

1. **Integração contínua:** toda alteração enviada para a `main` passa automaticamente por lint, testes e build, sem nenhum passo manual.
2. **Qualidade:** manter a cobertura de testes em pelo menos 80%; abaixo disso o pipeline falha.
3. **Container:** gerar no pipeline uma imagem Docker da API e testar se ela sobe e responde.
4. **Infraestrutura como código:** descrever em Terraform toda a infraestrutura da AWS necessária para rodar a API, sem configuração manual no console.

### Requisitos funcionais

| Código | Requisito | Regras |
|---|---|---|
| RF01 | Cadastrar livro (`POST /livros`) | Título e autor obrigatórios. Ano opcional, inteiro entre 1450 e o ano atual. Dados inválidos retornam 400. |
| RF02 | Listar livros (`GET /livros`) | Filtro opcional `?disponivel=true` ou `false`. Outro valor retorna 400. |
| RF03 | Consultar livro (`GET /livros/:id`) | Livro inexistente retorna 404. |
| RF04 | Atualizar livro (`PUT /livros/:id`) | Mesmas validações do cadastro. Um empréstimo em andamento é mantido. |
| RF05 | Remover livro (`DELETE /livros/:id`) | Livro emprestado não pode ser removido (409). |
| RF06 | Emprestar livro (`POST /livros/:id/emprestimo`) | Nome do leitor obrigatório. Livro já emprestado retorna 409. Registra a data do empréstimo. |
| RF07 | Devolver livro (`POST /livros/:id/devolucao`) | Livro que não está emprestado retorna 409. |
| RF08 | Verificar a saúde da API (`GET /health`) | Retorna `status: ok` e a versão. Usado pelo Docker e pelo load balancer. |

### Requisitos não funcionais

| Código | Requisito |
|---|---|
| RNF01 | O pipeline roda a cada push e pull request na `main` |
| RNF02 | Cobertura de testes mínima de 80% |
| RNF03 | Erros retornam JSON com o campo `erro` e o status HTTP correto (400, 404, 409 ou 500) |
| RNF04 | O container roda sem usuário root e tem health check |
| RNF05 | Nenhuma senha ou chave de acesso no repositório |
| RNF06 | A infraestrutura é criada só pelo Terraform |
| RNF07 | Os dados ficam em memória nesta fase (sem banco de dados) |

## 2. Plano de integração contínua

**Ferramenta:** GitHub Actions. Fica no próprio repositório, e o pipeline é um arquivo YAML versionado junto com o código: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

**Quando roda:** a cada push na `main`, a cada pull request para a `main` e manualmente pela aba Actions.

**Fluxo de trabalho:** as mudanças são feitas em branches e entram na `main` por pull request. A `main` é protegida: o pull request só pode ser aceito com todas as etapas do pipeline aprovadas.

**Etapas:**

| Etapa | O que faz | Falha quando |
|---|---|---|
| 1. Lint e testes (Node 24 e 26, em paralelo) | `npm ci`, ESLint, 35 testes unitários e de integração (Jest e Supertest) com relatório de cobertura | Erro de lint, teste quebrado ou cobertura abaixo de 80% |
| 2. Build e teste da imagem Docker (só roda se a etapa 1 passar) | Build da imagem, sobe o container e testa `/health`, cadastro e listagem | Build quebra ou a API não responde no container |
| 3. Validação do Terraform (em paralelo) | `terraform fmt -check`, `init` e `validate` na pasta `infra/` | Arquivo mal formatado ou configuração inválida |

**Feedback:** o resultado aparece no commit e no pull request, e o GitHub avisa por e-mail quando falha. O relatório de cobertura fica salvo como artefato da execução.

**Próximas fases:** adicionar a entrega contínua, publicando a imagem no ECR e fazendo o deploy no ECS pelo próprio pipeline.

## 3. Especificação da infraestrutura

AWS, conta do AWS Academy (Learner Lab), região `us-east-1`. Criada com Terraform 1.17 e o provider AWS 6, na pasta [`infra/`](../infra/).

```
Internet → Load Balancer (porta 80) → Container da API (porta 3000, ECS Fargate)
                                              │
                                imagem no ECR, logs no CloudWatch
```

| Recurso | Configuração |
|---|---|
| VPC | `10.0.0.0/16` |
| Sub-redes públicas | `10.0.0.0/24` e `10.0.1.0/24`, em duas zonas de disponibilidade (exigência do load balancer) |
| Internet Gateway | Saída para a internet das sub-redes públicas |
| Grupo de segurança do load balancer | Entrada: porta 80 de qualquer origem |
| Grupo de segurança da API | Entrada: porta 3000, só a partir do load balancer |
| ECR | Repositório `biblioteca-api`, com varredura de vulnerabilidades e as 10 imagens mais recentes |
| Application Load Balancer | Porta 80, health check em `/health` a cada 15 segundos |
| Cluster ECS | `biblioteca-cluster`, com Fargate |
| Tarefa ECS | 0,25 vCPU, 512 MB de memória, Linux x86_64, porta 3000 |
| Serviço ECS | 1 tarefa; volta para a versão anterior se uma nova não ficar saudável |
| CloudWatch Logs | Grupo `/ecs/biblioteca-api`, logs guardados por 7 dias |
| IAM | Usa o papel `LabRole`, porque o Learner Lab não permite criar papéis |

Não há NAT Gateway, porque ele é cobrado por hora. A tarefa fica na sub-rede pública com IP público, mas só recebe conexões do load balancer.

Para não gastar o crédito do laboratório, a infraestrutura é criada só para testar e depois apagada com `terraform destroy`.
