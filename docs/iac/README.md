# IaC — Infraestrutura como código

Tudo que existe na AWS é criado por Terraform. Nada é clicado no console.

## Como está organizado

Três stages, com estados independentes, separados por **ciclo de vida** — não por tipo de recurso:

| Stage | Provisiona | Vive quanto tempo |
|---|---|---|
| `bootstrap` | Bucket S3 do estado, cinco repositórios ECR, role de CI | Criado uma vez; sobrevive aos destroys |
| `infra` | VPC, EKS, três RDS, ElastiCache, DynamoDB, SQS, KMS, Secrets Manager, IRSA | Sobe e desce conforme a necessidade |
| `addons` | Controllers que rodam dentro do cluster, incluindo o Argo CD | Depende do `infra` |

Os stages se comunicam por **parâmetros no SSM**, não por acoplamento de estados. O `infra` publica nome do cluster, ARN do provedor OIDC e ARNs das roles IRSA; o `addons` lê por data source.

## Dois princípios que valem conhecer antes de mexer

**Nenhuma chave estática da AWS existe nos repositórios.** As esteiras autenticam por OIDC, assumindo uma role com trust policy restrita por repositório.

**Módulos são consumidos por tag, nunca por `main`.** Um commit na biblioteca não pode alterar o plano de ninguém sem uma mudança explícita no consumidor.

## Onde está documentado

| Documento | Assunto |
|---|---|
| [`togglemaster-iac/docs/esteira/`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/tree/main/docs/esteira) | Cinco diagramas: do pull request até a AWS, os quatro repositórios, por que três stages, quem autoriza o quê por OIDC, e a ordem do destroy |
| [`togglemaster-iac/README.md`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac) | Pré-requisitos manuais e a armadilha da claim `sub` customizada do GitHub |
| [`togglemaster-iac/docs/desafios/03`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/tree/main/docs/desafios) | DevSecOps na IaC: Trivy e Checkov antes do plan |
| [`terraform-aws-modules`](https://github.com/fiap-tech-challenge-devops/terraform-aws-modules) | Um README por módulo, com exemplo executável |

## Decisões que afetam este domínio

A estrutura descrita acima não é arbitrária: cada escolha tem um registro com o que foi descartado e por quê.

| # | Decisão |
|---|---|
| [0012](../decisoes/0012-tres-stages-de-terraform.md) | Três stages com estados independentes, e por que um apply único é impossível |
| [0013](../decisoes/0013-ecr-no-bootstrap.md) | Por que o ECR fica no `bootstrap` e não junto do cluster |
| [0014](../decisoes/0014-referencias-fixadas-por-tag.md) | Módulos por tag, nunca `main` |
| [0015](../decisoes/0015-oidc-sem-chave-estatica.md) | OIDC sem chave estática, e a armadilha da claim `sub` |
| [0016](../decisoes/0016-apply-replaneja.md) | Por que o `apply` replaneja em vez de aplicar um `tfplan` salvo |
| [0017](../decisoes/0017-trivy-e-checkov.md) | Trivy e Checkov como dois motores, e por que módulos baixados não são escaneados |
| [0021](../decisoes/0021-api-key-do-datadog-por-tf-vars.md) | O único segredo cujo valor vem de fora, e por que fica no `infra` |
| [0023](../decisoes/0023-datadog-como-codigo.md) | Um quarto stage, `datadog/`, e por que não cabe no `infra` nem no `bootstrap` |
| [0024](../decisoes/0024-encaixe-do-stage-datadog-na-esteira.md) | Como esse stage entra no plan e no apply |
| [0025](../decisoes/0025-baseline-em-spot.md) | Baseline em dois spot, e por que o ganho é capacidade e não custo |
| [0003](../decisoes/0003-observabilidade-no-gitops.md) | A stack de observabilidade **não** entra aqui — vai para o GitOps |

## Pendências conhecidas

**O EBS CSI driver está desligado** (`infra/main.tf`). Sem ele, nenhum PersistentVolumeClaim é atendido — e Prometheus e Loki pedem PVC por padrão. Decisão necessária antes da rodada 2 de observabilidade.

**Capacidade do baseline.** Dois nós **spot**, `min` e `max` iguais a 2, entre cinco tipos de instância de 2 vCPU e 8 GB — ver [0025](../decisoes/0025-baseline-em-spot.md). Quem escala além disso é o Karpenter, que já provisiona `["spot", "on-demand"]`.

**Os pods não se espalham por conta própria.** Medido depois da mudança para dois nós: os 8 pods da aplicação ficaram todos no mesmo nó. O chart base tem `affinity: {}`, sem `topologySpreadConstraints`. A capacidade existe, a resiliência não — perder aquele nó derruba todos os serviços, que recuperam no outro. Postergado por decisão, não por descuido.
