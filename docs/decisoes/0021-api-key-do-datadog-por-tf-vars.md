# 0021 — A API key do Datadog entra por `tf-vars`, e o `plan` passa a aceitar o mesmo input

**Status:** aceita · **Domínio:** IaC · CI/CD · Observabilidade · **Data:** 14/10/2026 · **Fase:** 4

## Contexto

A API key do Datadog é o **primeiro segredo do projeto cujo valor vem de fora**. Todos os outros são gerados pelo próprio Terraform com `random_password` — senha de RDS, `MASTER_KEY`, `SERVICE_API_KEY`. Essa diferença é a origem do problema: um valor gerado não precisa entrar, e este precisa.

Duas perguntas em sequência: **em qual stage o segredo mora**, e **como o valor chega lá**.

## Decisão

**O segredo fica no stage `infra`**, criado pelo módulo `secrets-manager` já consumido pelos segredos de RDS, com a mesma KMS key.

**O valor entra por `tf-vars`**, o secret que o `terraform-apply.yml` já expõe: uma linha `datadog_api_key=<valor>` que vira `TF_VAR_datadog_api_key`, mascarada com `::add-mask::` antes de existir no ambiente do job.

**E o `terraform-plan.yml` ganha o mesmo input**, que não tinha. Sem isso, uma variável obrigatória sem default reprova o `terraform plan` de todo pull request.

A variável da key fica **sem default**, de propósito.

**E o segredo carrega a conta inteira, não só a key** — `DD_API_KEY` e `DD_SITE`, por isso ele se chama `togglemaster/datadog/account`. A conta é um trial: quando expirar, outra será criada, e conta nova não cai necessariamente no mesmo site. Os dois valores **têm que trocar juntos**; separados, a troca tem uma janela em que a key é da conta nova e o site ainda aponta para a antiga, e o sintoma é `403` em toda exportação, que não diz o que está errado.

`datadog_site` **tem** default (`datadoghq.com`), porque não é segredo e só precisa ser informado quando a conta nova mudar de região.

## Alternativas descartadas

**O segredo no `bootstrap`.** O argumento da [0013](0013-ecr-no-bootstrap.md) parecia aplicável — credencial de vida longa, emitida uma vez, deveria sobreviver ao `destroy`. Mas a durabilidade do valor vem de **onde ele está guardado**, não do recurso: ele vive no GitHub Secrets e é reinjetado a cada apply, então recriar o segredo toda noite é invisível e gratuito.

E o custo do `bootstrap` é concreto: a KMS key cuja policy autoriza o role do External Secrets vive no `infra` (`infra/secrets.tf:49-59`), e o role também. Um segredo no `bootstrap` precisaria de key própria e de uma forma de autorizar um role que ainda não existe quando ele é criado — plumbing nova entre stages, para resolver um problema que não existe.

**`default = ""` com guarda de `count`.** Manteria o plan verde sem tocar na biblioteca compartilhada, e foi a alternativa mais tentadora. Descartada porque **esconderia da revisão o recurso que depende da variável**: sem valor, o `count` resolve para zero e o plan do PR não mostra nada. Isso contraria diretamente a premissa da [0016](0016-apply-replaneja.md), de que o plan da esteira de PR existe para revisão humana. Pior: um apply sem a variável criaria coisa nenhuma, e a falha só apareceria depois, no Collector autenticando contra o Datadog — longe da causa.

**Criar o segredo à mão, fora do Terraform.** Há precedente legítimo: o provedor OIDC e a role de CI são pré-requisitos manuais documentados ([0015](0015-oidc-sem-chave-estatica.md)), e o External Secrets só precisa que o segredo exista, já que a policy do IRSA cobre `togglemaster/*`. A key nunca entraria no `tfstate` e sobreviveria a todo `destroy`.

Descartada por dois motivos: o Checkov deixaria de ver o recurso, então a criptografia por CMK sairia da auditoria do gate; e os pré-requisitos manuais da 0015 existem por **circularidade** — não há como a esteira criar a role que ela precisa assumir. Aqui não há circularidade nenhuma, só conveniência.

## Consequências

- **A biblioteca compartilhada ganhou versão nova** (`v2.3.0`) por causa de um consumidor. É o fluxo que a [0014](0014-referencias-fixadas-por-tag.md) prevê: PR, tag, bump — mais passos, de propósito
- O `tf-vars` do plan **vale para todos os stages da matriz**. Não é problema: `TF_VAR_` de variável não declarada é ignorado pelo Terraform, ao contrário de `-var`, que reclama
- Plan e apply ficam simétricos. Antes, só o apply recebia variáveis sensíveis, e isso era uma assimetria esperando por este caso
- **A key fica em texto no `tfstate`.** É o mesmo patamar dos segredos existentes, que são `random_password` e já estão lá, e o bucket tem KMS key própria desde a correção do `AWS-0132` na Fase 3 ([0017](0017-trivy-e-checkov.md)). Não é uma regressão, mas é um fato que merece estar escrito
- O secret `TF_VARS_INFRA` precisa existir no repositório antes do primeiro PR que referencie a variável, ou o plan reprova
- **Trocar de conta Datadog é alterar um secret e rodar o apply do `infra`.** Nenhum PR no repositório GitOps, nenhuma imagem reconstruída — o Collector lê site e key do ambiente, por `${env:}`
- Como as duas propriedades vêm do mesmo segredo remoto, o External Secrets as sincroniza junto. Isso corta pela metade: **se uma delas faltar no segredo, o ESO falha o Secret inteiro** em vez de entregar metade — o que é o comportamento desejável aqui
- Isto cobre a **conta**, não o que é construído nela. Monitor, integrações e dashboards vivem no painel e morrem com o trial — resolvido pela [0023](0023-datadog-como-codigo.md), que os coloca num stage de Terraform próprio

## Onde aprofundar

[`reusable-workflows/docs/terraform-plan/`](https://github.com/fiap-tech-challenge-devops/reusable-workflows/tree/main/docs/terraform-plan), seção "Variáveis sensíveis", e o hub de [IaC](../iac/README.md)
