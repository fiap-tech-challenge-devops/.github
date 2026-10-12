<div align="center">

# ToggleMaster

**Uma plataforma de feature flags em microsserviços — e a esteira DevOps/SRE completa que a sustenta, da infraestrutura como código à observabilidade.**

![AWS](https://img.shields.io/badge/AWS-EKS·RDS·DynamoDB-FF9900?logo=amazonwebservices&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-modular-7B42BC?logo=terraform&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.34-326CE5?logo=kubernetes&logoColor=white)
![Argo CD](https://img.shields.io/badge/Argo%20CD-GitOps-EF7B4D?logo=argo&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-DevSecOps-2088FF?logo=githubactions&logoColor=white)
![Go](https://img.shields.io/badge/Go-1.25-00ADD8?logo=go&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)

</div>

---

## Quem somos

| Participante | LinkedIn |
|---|---|
| **Vitor Fontes do Prado** | [in/vitor-prado-889046172](https://www.linkedin.com/in/vitor-prado-889046172) |
| **Clayton Lima** | [in/clayton-lima-b1a8b7178](https://www.linkedin.com/in/clayton-lima-b1a8b7178/) |
| **Felipe Lima da Silva** | [in/felipelima285](https://www.linkedin.com/in/felipelima285/) |
| **Lucas Rodrigues** | [in/lucas-rodrigues-6278a855](https://www.linkedin.com/in/lucas-rodrigues-6278a855/) |
| **Thiago Saraiva** | [in/saraivathiago](https://www.linkedin.com/in/saraivathiago/) |

---

## Sobre o projeto

O ToggleMaster nasceu como trabalho do **Tech Challenge da pós-graduação em DevOps/SRE (POSTECH FIAP)**, mas não parou na entrega acadêmica. Ele segue ativo e continuará sendo atualizado como **portfólio do grupo** — um ambiente real onde novas práticas, ferramentas e decisões de arquitetura são implementadas, documentadas e discutidas.

A aplicação é uma **plataforma de feature flags**: liga e desliga funcionalidades em tempo de execução, direciona recursos para públicos específicos e coleta métricas de cada avaliação, sem exigir um novo deploy. São cinco microsserviços em Go e Python, cada um dono do próprio banco, comunicando-se de forma síncrona por HTTP e assíncrona por fila.

Mas a aplicação é o meio, não o fim. **O que este projeto demonstra é o ciclo de vida completo de um sistema em produção**, construído inteiramente por código:

| Área | O que está implementado |
|---|---|
| **Infraestrutura como código** | Terraform em módulos versionados e reutilizáveis, estado remoto em S3, três stages com ciclos de vida independentes |
| **CI com DevSecOps** | Build, testes, lint, SAST, SCA e varredura de segredos em toda alteração, com vulnerabilidade crítica reprovando a esteira |
| **Entrega contínua por GitOps** | Argo CD sincronizando o cluster a partir de um repositório de manifests, sem `kubectl` manual |
| **Kubernetes em produção** | Amazon EKS com escalabilidade automática de pods (HPA e KEDA) e de nós (Karpenter, com preferência por Spot) |
| **Segurança** | Autenticação por OIDC sem chaves estáticas, segredos no Secrets Manager entregues via External Secrets, imagens com tag imutável e rastreáveis até o commit |
| **Governança de custo** | Teto de vCPU no provisionamento de nós, esteira de destroy sob demanda e estimativa de custo documentada |
| **Observabilidade** | Stack de métricas preparada no cluster e ligada sob demanda — é a frente em evolução no momento |

A regra que organiza tudo isso é a mesma do primeiro dia: **se não está no código, não existe.** Nada é aplicado à mão, nem na AWS nem no cluster.

---

## A aplicação

| Serviço | Stack | Estado | Responsabilidade |
|---|---|---|---|
| `auth-service` | Go | PostgreSQL | Emite e valida as API keys. É a raiz de confiança |
| `flag-service` | Python | PostgreSQL | CRUD e leitura das feature flags |
| `targeting-service` | Python | PostgreSQL | Regras de segmentação e direcionamento |
| `evaluation-service` | Go | Redis | Avalia uma flag para um usuário, orquestrando os dois anteriores |
| `analytics-service` | Python | SQS + DynamoDB | Consome os eventos de avaliação e persiste as métricas |

O `evaluation-service` é o caminho de leitura: recebe a requisição, consulta flag e targeting, responde com cache em Redis e publica um evento na fila. O `analytics-service` consome essa fila de forma assíncrona e grava as métricas no DynamoDB.

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

Cada serviço tem um arquivo de poucas linhas que chama o workflow compartilhado da sua linguagem.

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

**[Índice da documentação](https://github.com/fiap-tech-challenge-devops/.github/tree/main/docs)** — guias transversais e o registro de decisões, com o mapa de tudo que está documentado nos outros repositórios.

Cada repositório traz, em `docs/`, o registro dos problemas reais enfrentados e como foram resolvidos — de um CVE crítico em dependência indireta do Go até a ordem correta de destruição do cluster. É a parte do trabalho que não aparece no código final.

E o [registro de decisões](https://github.com/fiap-tech-challenge-devops/.github/tree/main/docs/decisoes) guarda o outro lado: o que foi escolhido, o que foi descartado e por quê.
