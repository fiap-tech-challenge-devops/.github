# 0012 — Três stages de Terraform com estados independentes

**Status:** aceita · **Domínio:** IaC · **Data:** Fase 3 · **Fase:** 3

> Registro retroativo, escrito na Fase 4 a partir da documentação existente.

## Contexto

A infraestrutura poderia ser um único `terraform apply`. Três coisas impediam isso, e cada uma é de natureza diferente.

**Ovo e galinha do estado.** O bucket S3 que guarda o `tfstate` não pode guardar o state que o cria.

**Dependência de provider.** Os componentes que rodam dentro do cluster precisam dos providers `helm` e `kubernetes` apontando para um cluster que só existe depois do apply. O Terraform **não permite que a configuração de um provider dependa de recursos do mesmo apply**.

**Ciclo de vida diferente.** Alguns recursos devem sobreviver a um `destroy` do ambiente; outros não.

## Decisão

Três stages, cada um com sua própria chave de state:

| Stage | Provisiona | Ciclo de vida |
|---|---|---|
| `bootstrap` | Bucket S3 do state, cinco repositórios ECR, role de CI | Criado uma vez; sobrevive aos destroys |
| `infra` | VPC, EKS, RDS, ElastiCache, DynamoDB, SQS, KMS, Secrets Manager, IRSA | Sobe e desce conforme a necessidade |
| `addons` | Componentes dentro do cluster, incluindo o Argo CD | Depende do `infra` |

O `bootstrap` roda com state local na primeira execução e depois **migra o próprio state** para o bucket que acabou de criar.

A comunicação entre stages é por **parâmetros no SSM**, não por acoplamento de estados: o `infra` publica nome do cluster, ARN do provedor OIDC e ARNs das roles IRSA; o `addons` lê por data source.

## Alternativas descartadas

**Um apply único.** Impossível pela restrição de provider — e mesmo que fosse possível, misturaria recursos de ciclo de vida incompatível no mesmo state.

**Acoplar os stages por `terraform_remote_state`.** Funcionaria, mas cria dependência direta entre states: o `addons` passaria a precisar de permissão de leitura no state do `infra`, e uma mudança de estrutura ali quebraria aqui. O SSM desacopla com nomes determinísticos.

## Consequências

- Um `destroy` do ambiente não leva o bucket de state nem as imagens no ECR
- A ordem importa: `infra` antes de `addons`, e o inverso no destroy
- Cada stage tem sua própria execução na esteira, com o `apply` encadeado por `needs:`
- Recursos customizados de CRDs instaladas no mesmo apply exigiram charts Helm locais — o `kubernetes_manifest` falha no `plan`, porque valida contra uma API que ainda não tem a CRD

## Onde aprofundar

[`togglemaster-iac/README.md`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac) e [`docs/esteira/`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/tree/main/docs/esteira)
