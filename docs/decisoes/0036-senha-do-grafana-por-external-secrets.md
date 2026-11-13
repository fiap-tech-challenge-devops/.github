# 0036 — A senha do admin do Grafana vem do Secrets Manager, não do chart

**Status:** aceita · **Domínio:** Observabilidade · Kubernetes · **Validação:** não validada · **Data:** 13/11/2026 · **Fase:** 4

## Contexto

O Grafana subiu pelo GitOps com o `kube-prometheus-stack` e ficou **inutilizável na prática**: a sessão caía em poucos minutos, os painéis apareciam em `No data` e o navegador mostrava `Failed to fetch`.

O diagnóstico levou a um lugar inesperado. Nada estava errado com o dashboard nem com o dado — as três consultas do painel, rodadas direto contra o Prometheus, devolviam valores, e os alvos de scrape estavam todos `UP`, incluindo o `ServiceMonitor` do Collector com os cinco serviços em `exported_job`.

O que estava errado era a senha. Ela mudava sozinha.

| Momento | Senha |
|---|---|
| leitura inicial | `B426ex…` |
| 25 minutos depois | `9Z2Ol2…` |

E o Deployment acompanhava: três ReplicaSets em duas horas, cada um com uma annotation `checksum/secret` diferente.

## A causa

O `values.yaml` não definia `adminPassword`. Sem valor, o chart do Grafana gera um `randAlphaNum 40`.

Num `helm install` isso não incomoda, porque o chart faz `lookup` do Secret já existente no cluster e reaproveita o valor. **O Argo CD renderiza com `helm template`, que não tem acesso ao cluster**: o `lookup` volta vazio e uma senha nova nasce a cada render.

Daí em diante é mecânico, e o `selfHeal: true` fecha o laço:

```
render do Argo  →  senha nova  →  Secret muda
                                     ↓
         rollout do Deployment  ←  checksum/secret muda
```

Dois efeitos se somam, e o segundo é pior:

**A senha expira em minutos.** Ler o Secret e anotar a senha não serve para nada — ela já mudou quando você termina de digitar.

**A sessão morre junto.** O banco do Grafana é `emptyDir`. Cada rollout traz um pod com banco limpo, então quem estava logado é deslogado, e qualquer port-forward aberto cai.

## A decisão

**A senha vem do AWS Secrets Manager, pelo External Secrets, e o chart apenas a consome por `admin.existingSecret`.**

É o padrão que a [0021](0021-api-key-do-datadog-por-tf-vars.md) já estabeleceu para a API key do Datadog, e não houve o que inventar: o `ClusterSecretStore` existe, o módulo de Secrets Manager existe, e o ExternalSecret é cópia estrutural do que o Collector já usa.

| Camada | O que entra |
|---|---|
| `togglemaster-iac`, stage `infra` | módulo `grafana_secret` cria `togglemaster/grafana/admin`, cifrado pela KMS do sistema |
| `TF_VARS_INFRA` | a variável `grafana_admin_password`, com mínimo de 8 caracteres validado no plano |
| `togglemaster-gitops` | `ExternalSecret` no `templates/` do próprio chart, materializando `grafana-admin` |
| `values.yaml` | `admin.existingSecret`, que **desliga a geração** no chart |

A linha que resolve é a última. Com `existingSecret` definido, o chart deixa de renderizar Secret próprio, a geração aleatória some, o checksum estabiliza e o rollout perpétuo acaba. O resto é entregar o valor sem passá-lo pelo Git.

## Senha escolhida, e não gerada

O `secrets.tf` dizia, em comentário, que o segredo do Datadog era *"o único cujo valor vem de fora; os outros são gerados por `random_password`"*. Esta decisão cria a **segunda exceção**, e o comentário foi corrigido junto — comentário que descreve uma regra que deixou de valer é pior que nenhum.

A exceção se justifica pelo uso: a senha é **digitada ao vivo** na demonstração em vídeo. Uma `random_password` obrigaria a copiar e colar do Secrets Manager no meio da gravação, o que é frágil e, pior, expõe o valor na tela durante a cópia.

O que o projeto precisa aqui não é imprevisibilidade: é **estabilidade**. A ameaça real era a senha mudar sozinha, não alguém adivinhá-la — o Service é `ClusterIP`, não há Ingress, o acesso é só por `port-forward` com credencial da AWS, e o ambiente é destruído toda noite.

## Alternativas descartadas

**`adminPassword` literal no `values.yaml`.** Uma linha, resolveria igual. Descartada por pôr senha em texto claro no Git, contra o princípio que a [0021](0021-api-key-do-datadog-por-tf-vars.md) e a Fase 3 inteira sustentam. O trabalho extra desta decisão é pequeno e o precedente, grande.

**`random_password` no Terraform.** Mais correta em princípio, e foi a primeira ideia por ser a convenção dominante do `secrets.tf`. Descartada pelo motivo da seção acima: o valor existe para ser digitado por uma pessoa.

**Ligar persistência no Grafana** para o banco sobreviver ao rollout. Trataria o sintoma — a sessão cairia menos — e deixaria a causa de pé, além de esbarrar no `enable_ebs_csi_driver = false`, que é o motivo de Prometheus e Loki rodarem efêmeros.

## Consequências

- **`grafana_admin_password` é obrigatória no `TF_VARS_INFRA`.** Sem ela o plano do `infra` reprova com `No value for required variable`, que é o comportamento desejado: falhar no plano é melhor que criar o secret com valor vazio e descobrir no boot do pod
- **O `refreshInterval` é de 1 hora.** Trocar o valor no Secrets Manager não chega ao cluster na hora. É a mesma armadilha do `force-sync` registrada na troca de conta do Datadog, e a saída é a mesma
- **A senha só é aplicada quando o Grafana inicializa o banco dele.** Hoje o storage é efêmero e todo pod novo a aplica. **Se alguém ligar persistência, trocar o valor deixa de ter efeito silenciosamente** — está anotado no `values.yaml`, ao lado da chave
- **`CreateContainerConfigError` logo após o apply é esperado.** O ExternalSecret e o Grafana nascem na mesma sync-wave; se o Secret ainda não existe, o pod reclama e se resolve no retry

## O que esta decisão não resolve

**A rotatividade dos nós.** No mesmo dia apareceu um evento `NodeShutdown` e os dois nós do cluster tinham minutos de vida. Isso derruba `port-forward` exatamente como o rollout derrubava, e é causa independente — consolidação do Karpenter ou interrupção de Spot, ainda não determinado. Quem for gravar precisa saber que a conexão pode cair por esse outro motivo.

**Se o mesmo laço existe em outro chart.** O padrão `randAlphaNum` sem `lookup` funcional sob Argo CD não é exclusividade do Grafana. Nenhum outro chart do repositório foi auditado para isto.

## Onde aprofundar

[0021](0021-api-key-do-datadog-por-tf-vars.md) para o padrão de segredo por tf-vars e External Secrets · [0003](0003-observabilidade-no-gitops.md) para a stack morar no GitOps · [`variaveis-e-segredos.md`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac/blob/main/docs/variaveis-e-segredos.md) para o que vai em cada secret
