# ToggleMaster

Plataforma de **feature flags** construída como microsserviços, desenvolvida para o **Tech Challenge da FIAP (POSTECH)**.

Feature flags ligam e desligam funcionalidades em tempo de execução, direcionam recursos para públicos específicos e coletam métricas de cada avaliação — tudo sem um novo deploy. A aplicação é real, mas o objetivo do projeto é o que está em volta dela: infraestrutura como código, esteiras de segurança e entrega contínua por GitOps.

O lema da fase atual resume a regra que organiza tudo aqui: **se não está no código, não existe.** Nada é aplicado à mão, nem na AWS nem no cluster.

---

## A aplicação

Cinco microsserviços, cada um dono do próprio banco de dados.

| Serviço | Stack | Estado | Responsabilidade |
|---|---|---|---|
| `auth-service` | Go | PostgreSQL | Emite e valida as API keys. É a raiz de confiança |
| `flag-service` | Python | PostgreSQL | CRUD e leitura das feature flags |
| `targeting-service` | Python | PostgreSQL | Regras de segmentação e direcionamento |
| `evaluation-service` | Go | Redis | Avalia uma flag para um usuário, orquestrando os dois anteriores |
| `analytics-service` | Python | SQS + DynamoDB | Consome os eventos de avaliação e persiste as métricas |

O `evaluation-service` é o caminho de leitura: recebe a requisição, consulta flag e targeting, responde com cache em Redis e publica um evento na fila. O `analytics-service` consome essa fila de forma assíncrona. A comunicação entre os serviços é síncrona por HTTP; a de métricas, assíncrona por SQS.

---

## Os repositórios

**Plataforma**

| Repositório | Papel |
|---|---|
| [`terraform-aws-modules`](https://github.com/fiap-tech-challenge-devops/terraform-aws-modules) | Biblioteca de módulos Terraform reutilizáveis, consumidos por tag |
| [`togglemaster-iac`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac) | Provisiona a infraestrutura AWS |
| [`togglemaster-gitops`](https://github.com/fiap-tech-challenge-devops/togglemaster-gitops) | Manifests e Helm charts que o Argo CD sincroniza com o cluster |
| [`reusable-workflows`](https://github.com/fiap-tech-challenge-devops/reusable-workflows) | Workflows de CI/CD compartilhados pelos cinco serviços e pela IaC |

**Microsserviços**

[`auth-service`](https://github.com/fiap-tech-challenge-devops/auth-service) · [`flag-service`](https://github.com/fiap-tech-challenge-devops/flag-service) · [`targeting-service`](https://github.com/fiap-tech-challenge-devops/targeting-service) · [`evaluation-service`](https://github.com/fiap-tech-challenge-devops/evaluation-service) · [`analytics-service`](https://github.com/fiap-tech-challenge-devops/analytics-service)

---

## Infraestrutura

Terraform dividido em três stages com estados independentes, separados pelo ciclo de vida dos recursos.

| Stage | Provisiona |
|---|---|
| `bootstrap` | Bucket S3 do estado, cinco repositórios ECR e a role de CI. Sobrevive aos destroys |
| `infra` | VPC, EKS, três RDS PostgreSQL, ElastiCache, DynamoDB, SQS, KMS, Secrets Manager e roles IRSA |
| `addons` | Argo CD, External Secrets, KEDA, Karpenter, AWS Load Balancer Controller e metrics-server |

Os stages se comunicam por parâmetros no SSM Parameter Store, não por acoplamento de estados. Nenhum segredo de longa duração da AWS existe nos repositórios: as esteiras autenticam por OIDC, assumindo uma role com trust policy restrita por repositório.

---

## Esteiras

Cada serviço tem um arquivo de poucas linhas que chama o workflow compartilhado correspondente à sua linguagem.

| Estágio | Go | Python |
|---|---|---|
| Build e teste | `go build`, `go test` | `compileall`, `pytest` |
| Lint | `golangci-lint` | `ruff` |
| Segurança | `gitleaks`, `gosec`, `trivy fs` | `gitleaks`, `bandit`, `trivy fs` |
| Imagem | build, `trivy image` e push para o ECR, na mesma execução | idem |

**Vulnerabilidade CRITICAL reprova o pipeline imediatamente**, e não há aprovação manual que contorne: sem esteira verde, nenhuma imagem chega ao ECR. A imagem é marcada com o SHA completo do commit, em repositório ECR com tag imutável — a imagem auditada é exatamente a que roda no cluster.

---

## Entrega

```
merge na main do microsserviço
  → CI publica a imagem no ECR
  → CD atualiza a tag da imagem no repositório GitOps
  → Argo CD detecta a diferença
  → sync automático
  → nova versão no cluster
```

Nenhuma etapa envolve alguém rodando `kubectl` na própria máquina. O commit no repositório GitOps é o registro auditável do que foi promovido, quando e por qual build.

---

## As fases do desafio

| Fase | Entrega |
|---|---|
| **1** | Os cinco microsserviços containerizados, orquestrados localmente com Docker Compose |
| **2** | Deploy em Kubernetes na AWS (EKS), com escalabilidade automática, gestão de segredos e recursos gerenciados |
| **3** | Infraestrutura como código, esteiras de CI com DevSecOps e entrega contínua por GitOps com Argo CD |

---

## Documentação

Cada repositório traz, em `docs/`, o registro dos problemas reais enfrentados e como foram resolvidos — de um CVE crítico em dependência indireta do Go até a ordem correta de destruição do cluster. É a parte do trabalho que não aparece no código final.
