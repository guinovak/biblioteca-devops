# Documentação de Planejamento: Fase 1

Disciplina DevOps na Prática (PUCRS). Fase 1: Configuração e Automação Inicial.

---

## 1. Descrição do projeto, objetivos e requisitos

### Descrição

A **API da Biblioteca** é um serviço REST para cadastrar livros e controlar empréstimos e devoluções. A aplicação é intencionalmente pequena: ela é o veículo para aplicar as práticas DevOps da disciplina, ou seja, integração contínua com testes automatizados, empacotamento em container e infraestrutura descrita como código.

Tecnologias: Node.js 24, Express 5, Jest e Supertest (testes), ESLint (análise estática), Docker (empacotamento), GitHub Actions (CI) e Terraform com provedor AWS (infraestrutura como código).

### Objetivos

1. **Automatizar a verificação de qualidade**: toda alteração enviada ao repositório passa por lint, testes automatizados e build sem intervenção manual.
2. **Dar feedback rápido**: quem fez a alteração sabe em poucos minutos se ela quebrou algo, direto no commit ou no pull request.
3. **Empacotar a aplicação em container**: a mesma imagem Docker roda no pipeline, na máquina do desenvolvedor e na nuvem.
4. **Descrever a infraestrutura como código**: a rede, o registro de imagens, o load balancer e o serviço de containers na AWS são criados e destruídos por scripts Terraform versionados, de forma reproduzível.
5. **Preparar a entrega contínua**: deixar a base pronta para as próximas fases publicarem a imagem e implantarem automaticamente.

### Requisitos funcionais

| Código | Requisito | Endpoint |
|---|---|---|
| RF01 | Cadastrar livro com título e autor obrigatórios e ano opcional (entre 1450 e o ano atual) | `POST /livros` |
| RF02 | Listar livros, com filtro opcional por disponibilidade | `GET /livros?disponivel=true\|false` |
| RF03 | Consultar um livro pelo identificador | `GET /livros/:id` |
| RF04 | Atualizar os dados de um livro, preservando o empréstimo em andamento | `PUT /livros/:id` |
| RF05 | Remover livro, exceto se estiver emprestado | `DELETE /livros/:id` |
| RF06 | Emprestar livro a um leitor; um livro emprestado não pode ser emprestado de novo | `POST /livros/:id/emprestimo` |
| RF07 | Registrar a devolução de um livro emprestado | `POST /livros/:id/devolucao` |
| RF08 | Informar se o serviço está saudável e qual versão está rodando | `GET /health` |

### Requisitos não funcionais

| Código | Requisito |
|---|---|
| RNF01 | Todo push e pull request para a `main` dispara o pipeline de CI automaticamente |
| RNF02 | Testes automatizados (unitários, de integração e de fumaça) com cobertura mínima de 80%; abaixo disso o pipeline falha |
| RNF03 | O pipeline completo termina em menos de 10 minutos |
| RNF04 | A aplicação roda em container, com usuário sem privilégios de root e health check |
| RNF05 | A infraestrutura é criada exclusivamente por Terraform, sem configuração manual no console |
| RNF06 | Nenhum segredo (chave, senha, token) fica no repositório |
| RNF07 | O custo da infraestrutura cabe no crédito de US$ 50 do AWS Academy |
| RNF08 | Logs da aplicação centralizados no CloudWatch |
| RNF09 | Erros devolvem status HTTP coerente (400, 404, 409, 500) e mensagem em JSON, sem expor detalhes internos |

---

## 2. Plano de integração contínua

### Ferramenta

**GitHub Actions**, pelos motivos vistos na aula 2: é integrado ao repositório (o código e o pipeline ficam no mesmo lugar), o workflow é um arquivo YAML versionado junto com o código, roda em máquinas hospedadas pelo GitHub sem servidor próprio e é gratuito para repositório público.

Arquivo do pipeline: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

### Fluxo de trabalho no repositório

1. A branch `main` é sempre estável e pronta para entrega.
2. Cada mudança é feita numa branch curta (`feat/...`, `fix/...`), com commits pequenos e frequentes.
3. A mudança volta para a `main` por **pull request**. O pipeline roda no PR, e o merge só é permitido com todas as etapas verdes (proteção de branch).
4. Depois do merge, o pipeline roda de novo na `main`, confirmando o resultado integrado.

### Gatilhos

| Evento | Quando |
|---|---|
| `push` | a cada envio para a `main` |
| `pull_request` | a cada PR aberto ou atualizado contra a `main` |
| `workflow_dispatch` | execução manual pela aba Actions |

Um push novo na mesma branch cancela a execução anterior, que ficou desatualizada.

### Etapas do pipeline

```
push / pull request
        │
        ├──► qualidade (Node 24 e Node 26, em paralelo)
        │      npm ci → lint (ESLint) → testes + cobertura ≥ 80% → relatório de cobertura
        │           │
        │           ▼ (só se passar)
        │    imagem
        │      build da imagem Docker → sobe o container → teste de fumaça (/health, cadastro, listagem)
        │
        └──► infraestrutura (em paralelo)
               terraform fmt -check → terraform init → terraform validate
```

| Etapa | O que verifica | Falha quando |
|---|---|---|
| Lint | Estilo e erros comuns de código (ESLint) | Há variável não usada, comparação frouxa etc. |
| Testes unitários | Regras de negócio do serviço de livros | Uma regra se comporta diferente do esperado |
| Testes de integração | A API HTTP de ponta a ponta, com Supertest | Um endpoint devolve status ou corpo errado |
| Cobertura | Quanto do código os testes exercitam | Fica abaixo de 80% em linhas, funções, ramos ou comandos |
| Build da imagem | O Dockerfile gera uma imagem válida | O build quebra |
| Teste de fumaça | O container sobe e responde de verdade | `/health` não responde ou o cadastro falha |
| Terraform | Os scripts de infraestrutura estão formatados e válidos | Erro de sintaxe, referência inválida ou formatação fora do padrão |

### Como o plano aplica as práticas de CI da aula 2

| Prática | Onde acontece |
|---|---|
| Commit frequente | Branches curtas e PRs pequenos; o pipeline roda a cada push |
| Build automatizado | `npm ci` com versões travadas e build da imagem Docker em todo pipeline |
| Testes automatizados | 35 testes unitários e de integração e o teste de fumaça no container |
| Feedback imediato | Status ✔/✘ no commit e no PR, e-mail do GitHub em caso de falha, badge no README e relatório de cobertura como artefato |
| Controle de versão | Git e GitHub; o próprio pipeline e a infraestrutura também são versionados |

### Critério de aprovação

Uma mudança só entra na `main` com as três etapas verdes. Se a `main` quebrar, a correção é prioridade sobre qualquer trabalho novo.

### Métricas acompanhadas

- Tempo total do pipeline (meta: menos de 10 minutos)
- Taxa de execuções com sucesso na `main`
- Cobertura de testes (mínimo 80%)

### Próximos passos: entrega contínua (aula 3)

A Fase 1 entrega a integração contínua. Nas próximas fases, o mesmo pipeline ganha a entrega contínua:

1. Publicar a imagem no Amazon ECR com a tag do commit (SHA), depois da etapa de imagem.
2. Rodar `terraform plan` no pull request e `terraform apply` na `main`, com aprovação manual num *environment* do GitHub.
3. Atualizar o serviço no ECS com a nova imagem. O *circuit breaker* do ECS já está configurado para voltar sozinho à versão anterior se a nova não ficar saudável (rollback automático).
4. Separar ambientes de *staging* e produção.

---

## 3. Especificação da infraestrutura

### Visão geral

A API roda em containers no **Amazon ECS com AWS Fargate**, atrás de um **Application Load Balancer**, dentro de uma VPC própria. A imagem Docker fica no **Amazon ECR** e os logs vão para o **CloudWatch**. Tudo é descrito em Terraform, na pasta [`infra/`](../infra/).

- **Provedor:** AWS, conta do AWS Academy Learner Lab, região `us-east-1`
- **Ferramenta:** Terraform 1.17 com o provider `hashicorp/aws` 6.x

```
Internet
   │ HTTP :80
   ▼
VPC 10.0.0.0/16
├── Internet Gateway
├── Sub-redes públicas: 10.0.0.0/24 (us-east-1a) e 10.0.1.0/24 (us-east-1b)
│
│   Application Load Balancer    ← SG alb: aceita TCP 80 da internet
│            │ :3000
│            ▼
│   Tarefa Fargate da API (ECS)  ← SG api: aceita TCP 3000 só do ALB
│        │              │
└────────┼──────────────┼──────────
         ▼              ▼
    Amazon ECR     CloudWatch Logs
    (imagem)       (logs, 7 dias)
```

### Recursos

| Recurso | Terraform | Configuração |
|---|---|---|
| VPC | `aws_vpc.principal` | `10.0.0.0/16`, DNS habilitado |
| Sub-redes públicas | `aws_subnet.publica` (2) | `/24` em duas zonas de disponibilidade |
| Internet Gateway e rotas | `aws_internet_gateway`, `aws_route_table` | Saída para a internet pelas sub-redes públicas |
| Grupo de segurança do ALB | `aws_security_group.alb` | Entrada: TCP 80 de qualquer origem. Saída: só para a API, porta 3000 |
| Grupo de segurança da API | `aws_security_group.api` | Entrada: TCP 3000 **somente do ALB**. Saída liberada (ECR e CloudWatch) |
| Registro de imagens | `aws_ecr_repository.api` | Varredura de vulnerabilidades a cada envio; mantém as 10 imagens mais recentes |
| Load balancer | `aws_lb.api` + target group + listener | HTTP 80, health check em `/health` a cada 15 s |
| Cluster ECS | `aws_ecs_cluster.principal` | Fargate, Container Insights desligado (custo) |
| Definição de tarefa | `aws_ecs_task_definition.api` | 0,25 vCPU, 512 MiB, Linux x86_64, health check do container, logs no CloudWatch |
| Serviço ECS | `aws_ecs_service.api` | 1 tarefa; deploy sem queda (100% / 200%); circuit breaker com rollback automático |
| Logs | `aws_cloudwatch_log_group.api` | Retenção de 7 dias |
| Permissões | `data.aws_iam_role.lab` | Usa o `LabRole` existente (o Learner Lab não permite criar papéis no IAM) |

Todos os recursos recebem as etiquetas `Projeto`, `Disciplina` e `GerenciadoPor = terraform`.

### Decisões e justificativas

- **Fargate em vez de EC2:** sem servidor para administrar, cobrança só pelo tempo da tarefa (aula 4).
- **ECS em vez de EKS:** o EKS tem custo fixo do plano de controle, alto para o crédito do laboratório (aula 4).
- **Load balancer:** a tarefa Fargate ganha IP novo a cada deploy; o ALB dá um endereço fixo e só envia tráfego para tarefa saudável.
- **Sem NAT Gateway:** ele é cobrado por hora. As tarefas ficam em sub-rede pública com IP público, mas o grupo de segurança bloqueia qualquer acesso que não venha do ALB.
- **VPC própria:** isola o projeto da rede padrão da conta e deixa a rede descrita no código.
- **Estado local do Terraform:** suficiente para a Fase 1, com uma pessoa aplicando. Na entrega contínua, o estado passa para um bucket S3 com lock, para o pipeline poder aplicar.

### Segurança

- Nenhuma credencial no repositório: as chaves temporárias do Learner Lab entram como variáveis de ambiente na hora de rodar o Terraform.
- Container sem root e imagem mínima (`node:24-alpine`), só com as dependências de produção.
- Varredura de vulnerabilidades no ECR a cada imagem enviada.
- Tráfego até a aplicação só pelo load balancer.

### Custo estimado

Valores aproximados de `us-east-1`, a conferir na calculadora da AWS:

| Item | Por hora |
|---|---|
| Tarefa Fargate (0,25 vCPU + 0,5 GB) | ~US$ 0,012 |
| Application Load Balancer | ~US$ 0,03 |
| IPs públicos (2 do ALB + 1 da tarefa) | ~US$ 0,015 |
| **Total** | **~US$ 0,06 por hora (~US$ 1,40 por dia)** |

Ligada o mês inteiro, a infraestrutura consumiria quase todo o crédito de US$ 50. Por isso o roteiro é **criar, demonstrar e destruir** (`terraform destroy`), e a variável `quantidade_tarefas = 0` desliga a API sem apagar o resto.

### Como provisionar

Passo a passo em [`infra/README.md`](../infra/README.md).
