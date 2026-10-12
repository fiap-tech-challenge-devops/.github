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

| # | Decisão |
|---|---|
| [0003](../decisoes/0003-observabilidade-no-gitops.md) | A stack de observabilidade **não** entra aqui — vai para o GitOps |

## Pendências conhecidas

**O EBS CSI driver está desligado** (`infra/main.tf`). Sem ele, nenhum PersistentVolumeClaim é atendido — e Prometheus e Loki pedem PVC por padrão. Decisão necessária antes da rodada 2 de observabilidade.

**Capacidade do nó.** O node group fixo é um `t3.large` com `min` e `max` iguais a 1; quem escala é o Karpenter.
