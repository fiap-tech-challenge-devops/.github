# 0003 — Stack de observabilidade no GitOps, não no Terraform

**Status:** aceita · **Domínio:** GitOps · Observabilidade · **Data:** 08/10/2026 · **Fase:** 4

## Contexto

Na Fase 3, a fronteira adotada foi: o Terraform é dono dos controllers de plataforma — External Secrets, KEDA, Karpenter, Load Balancer Controller — e o Argo CD é dono das aplicações.

O `kube-prometheus-stack` já existia no stage `addons` do Terraform, desligado por `enable_kube_prometheus_stack = false`. O enunciado da Fase 4 pede os charts de observabilidade no repositório GitOps.

## Decisão

A stack de observabilidade — Collector, Prometheus, Loki, Grafana — vai para o **GitOps**. O `helm_release` desligado sai do Terraform.

O plano AWS que esses componentes precisarem continua no Terraform: bucket S3 e IRSA do Loki, se usarem S3, e o segredo da API key do Datadog no Secrets Manager.

## Alternativas descartadas

**Manter no Terraform**, pela coerência com a fronteira da Fase 3. Descartada porque o critério da fronteira nunca foi "tudo que roda no cluster é do Terraform" — foi **ciclo de vida**. Dashboard, regra de alerta e pipeline do Collector mudam toda semana; o cluster não.

Além disso, o `helm_release` não reconcilia drift: uma edição manual só é percebida no próximo apply. O Argo percebe em 30 segundos e, com `selfHeal`, desfaz.

## Consequências

- Cada ajuste de dashboard ou alerta vira commit e sync em segundos, em vez de PR, plan e apply
- A esteira de `destroy` fica mais pesada: mais componentes a limpar antes do `terraform destroy`
- A justificativa precisa estar escrita no relatório, porque a mudança pode ser lida como inconsistência com a Fase 3
- **Nunca ter dois donos do mesmo release** — é o que faz Terraform e Argo se reverterem a cada reconcile

## Onde aprofundar

`togglemaster-gitops/docs/desafios/08-otel-collector-e-charts-de-terceiros.md`
