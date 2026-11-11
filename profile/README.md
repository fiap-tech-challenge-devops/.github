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
![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-traces·métricas·logs-425CC7?logo=opentelemetry&logoColor=white)
![Datadog](https://img.shields.io/badge/Datadog-APM-632CA6?logo=datadog&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-Prometheus·Loki-F46800?logo=grafana&logoColor=white)

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
| **Infraestrutura como código** | Terraform em módulos versionados e reutilizáveis, estado remoto em S3, cinco stages com ciclos de vida independentes |
| **CI com DevSecOps** | Build, testes, lint, SAST, SCA e varredura de segredos em toda alteração, com vulnerabilidade crítica reprovando a esteira |
| **Entrega contínua por GitOps** | Argo CD sincronizando o cluster a partir de um repositório de manifests, sem `kubectl` manual |
| **Kubernetes em produção** | Amazon EKS com escalabilidade automática de pods (HPA e KEDA) e de nós (Karpenter, com preferência por Spot) |
| **Segurança** | Autenticação por OIDC sem chaves estáticas, segredos no Secrets Manager entregues via External Secrets, imagens com tag imutável e rastreáveis até o commit |
| **Governança de custo** | Teto de vCPU no provisionamento de nós, esteira de destroy sob demanda e estimativa de custo documentada |
| **Observabilidade** | Os cinco serviços instrumentados com OpenTelemetry, um Collector no cluster distribuindo traces, métricas e logs para três backends, oito monitores declarados em Terraform e remediação automática disparada por alerta |

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

Terraform dividido em cinco stages com estados independentes, separados pelo ciclo de vida dos recursos.

| Stage | Provisiona |
|---|---|
| `bootstrap` | Bucket S3 do estado, cinco repositórios ECR e a role de CI. Sobrevive aos destroys |
| `infra` | VPC, EKS, três RDS PostgreSQL, ElastiCache, DynamoDB, SQS, KMS, Secrets Manager e roles IRSA |
| `addons` | Argo CD, External Secrets, KEDA, Karpenter, AWS Load Balancer Controller e metrics-server |
| `datadog` | Monitores, alertas e o webhook que dispara a remediação |
| `pagerduty` | Serviço de plantão, política de escalonamento e as duas pontas da integração com o Datadog |

Os stages se comunicam por parâmetros no SSM Parameter Store, não por acoplamento de estados. Nenhum segredo de longa duração da AWS existe nos repositórios: as esteiras autenticam por OIDC, assumindo uma role com trust policy restrita por repositório.

Os dois últimos stages não falam com a AWS — só com a API do SaaS. Isso lhes dá uma propriedade útil: o `plan` deles funciona com o ambiente destruído, que é o estado normal fora do horário de uso.

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

## Observabilidade

Os cinco serviços emitem **traces, métricas e logs** por OpenTelemetry. Nenhum deles conhece o backend: todos falam OTLP com um **Collector** no cluster, e é o Collector que decide para onde cada sinal vai.

```
cinco serviços ──OTLP──▶  Collector  ──┬──▶ Datadog                 APM, Service Map, monitores
                                       ├──▶ Prometheus (scrape) ──┐
                                       └──▶ Loki (OTLP) ──────────┴──▶ Grafana
```

Somar ou trocar um backend é mudar a configuração do Collector, não as aplicações — é a razão de ele existir. As métricas de aplicação chegam ao Prometheus por um `ServiceMonitor` no próprio Collector, e os logs chegam ao Loki por OTLP; o dashboard do grupo **lê das duas fontes na mesma tela** — requisições HTTP por serviço e uso dos nós vindo do Prometheus, logs ao vivo dos microsserviços vindo do Loki.

A propagação de contexto atravessa as duas linguagens e também a fila: uma avaliação de flag vira **um trace só**, do `evaluation-service` em Go até o `analytics-service` em Python, ligados por *span link* através do SQS.

Cada peça entra pelo caminho do seu ciclo de vida:

| Peça | Mora em | Chega por |
|---|---|---|
| Instrumentação | nos cinco serviços | a própria imagem |
| Collector, Prometheus, Grafana e Loki | `togglemaster-gitops` | Helm chart sincronizado pelo Argo CD |
| Monitores, alertas e webhook | `togglemaster-iac`, stage `datadog` | `terraform apply` |
| Serviço e plantão do PagerDuty | `togglemaster-iac`, stage `pagerduty` | `terraform apply` |

Nada de alerta ou de plantão é clicado no painel. **A regra vale também para o SaaS.**

### Alertas

Oito monitores: **dois golden signals** por serviço — taxa de erro e latência p95 —, com limiar de latência definido pelo papel de cada um, de 500ms no `auth-service` a 2s no `evaluation-service`, que faz fan-out para quatro dependências.

A taxa de erro tem dois patamares, e o que os separa não é gravidade percebida: é **quem responde**.

| Patamar | O que dispara |
|---|---|
| **aviso**, 5% | mensagem no canal do Slack. É para olhar os traces antes de virar incidente |
| **crítico**, 10% | abre incidente no PagerDuty **e** autoriza a remediação automática |

### Self-healing

No patamar crítico, o Datadog chama um `repository_dispatch` no GitHub e uma Action assume. Ela **não sai remediando** — primeiro investiga:

```
alerta crítico
  → filtro de transição e disjuntor: no máximo 2 tentativas por ciclo de alerta
  → sondas de HTTP, pods, nós e RDS, para identificar a causa
  → se a causa for credencial, espera 90s re-sondando para confirmar que persiste
  → remediação: reverte a versão do segredo e recicla os pods
  → verificação, relatório no Job Summary e aviso no Slack
```

As sondas existem para que a automação saiba o que está consertando: se a causa não for a que ela sabe tratar, ela **reporta e não age**. A espera de 90 segundos está ali pelo mesmo motivo — não remediar uma falha que já passou sozinha.

Notificar e agir correm **em paralelo**, nunca em série. Se o Slack cair, o incidente abre e a remediação roda; se o PagerDuty cair, o Slack avisa e a remediação roda. Nenhum dos caminhos é pré-requisito do outro, porque um canal de notificação quebrado não deveria impedir o conserto.

---

## As fases do desafio

| Fase | Entrega |
|---|---|
| **1** | Os cinco microsserviços containerizados, orquestrados localmente com Docker Compose |
| **2** | Deploy em Kubernetes na AWS (EKS), com escalabilidade automática, gestão de segredos e recursos gerenciados |
| **3** | Infraestrutura como código, esteiras de CI com DevSecOps e entrega contínua por GitOps com Argo CD |
| **4** | Observabilidade de ponta a ponta: traces, métricas e logs por OpenTelemetry, APM comercial e stack opensource, alertas, ChatOps no Slack, plantão no PagerDuty e remediação automática |

---

## Documentação

**[Índice da documentação](https://github.com/fiap-tech-challenge-devops/.github/tree/main/docs)** — guias transversais e o registro de decisões, com o mapa de tudo que está documentado nos outros repositórios.

Cada repositório traz, em `docs/`, o registro dos problemas reais enfrentados e como foram resolvidos — de um CVE crítico em dependência indireta do Go até a ordem correta de destruição do cluster. É a parte do trabalho que não aparece no código final.

E o [registro de decisões](https://github.com/fiap-tech-challenge-devops/.github/tree/main/docs/decisoes) guarda o outro lado: o que foi escolhido, o que foi descartado e por quê.

A observabilidade é o único domínio cuja documentação é **transversal** — atravessa os cinco serviços, o GitOps e o Terraform, e por isso não cabe em nenhum repositório sozinho. Ela tem [hub próprio](https://github.com/fiap-tech-challenge-devops/.github/tree/main/docs/observabilidade), com o guia de como o dado flui, a instrumentação em Python e Go lado a lado, e o roteiro para encenar uma falha e ver a cadeia inteira reagir.
