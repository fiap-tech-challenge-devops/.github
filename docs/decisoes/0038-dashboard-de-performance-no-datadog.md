# 0038 — Um dashboard de performance no Datadog, como JSON exportado

**Status:** aceita · **Domínio:** Observabilidade · IaC · **Validação:** não validada · **Data:** 13/11/2026 · **Fase:** 4

## Contexto

A [0026](0026-sem-dashboard-no-datadog.md) decidiu que **não haveria dashboard customizado no Datadog**, e a [0023](0023-datadog-como-codigo.md) anotou que `datadog_dashboard_json` *"não será usado"*.

Os dois argumentos da 0026 continuam corretos:

- O enunciado pede *"no mínimo 1 dashboard customizado"* com recursos do cluster, taxa de requisições e logs em tempo real. Isso é **Grafana**, e está entregue
- As páginas nativas de APM já mostram requisições por segundo, erro e latência por serviço, alimentadas pelo `datadog/connector`

**Nada disso mudou.** O que mudou foi o propósito.

## O que esta decisão acrescenta

Um dashboard foi construído à mão na interface do Datadog — *ToggleMaster · Microservices Performance* — e ele **não existe para atender requisito**. Existe para a demonstração em vídeo.

A diferença importa. Navegar entre quatro páginas nativas de APM durante uma gravação de 25 minutos custa tempo e atenção; uma tela única com latência, erro, throughput e quebra por endpoint conta a mesma história em segundos. É argumento de **apresentação**, não de observabilidade — e vale dizer isso em voz alta, em vez de inventar uma necessidade técnica que não existe.

São 13 widgets em 5 grupos:

| Grupo | O que mostra |
|---|---|
| Overview | totais, p95, taxa de erro, falha de auth em 401, e uma tabela comparando os serviços |
| Latency | p95 e p99 por serviço |
| Throughput and Errors | throughput por serviço e por status, erro por serviço, erro por status |
| Endpoint Breakdown | tabela por `resource_name` e os dez endpoints mais lentos |
| Messaging | produzido × consumido no SQS, e latência de processamento do consumidor |

O grupo *Messaging* cobre o `analytics-service`, que fica de fora dos oito monitores da [0029](0029-dois-golden-signals.md) por não emitir span de servidor HTTP. É o único lugar do projeto onde o lado assíncrono aparece medido, e não só narrado.

## A decisão

**O dashboard entra no stage `datadog/` como `datadog_dashboard_json`, lendo o export da UI por `file()`.**

```hcl
resource "datadog_dashboard_json" "microservices_performance" {
  dashboard = file("${path.module}/dashboards/microservices-performance.json")
}
```

Isso revoga a decisão da 0026 e torna falsa a nota da 0023. As duas foram marcadas.

## Por que JSON exportado, e não HCL

O recurso `datadog_dashboard` traduziria cada widget para blocos HCL. Diff legível no PR, interpolação completa, revisão de verdade.

Foi descartado porque **perde o caminho de volta**. Com o JSON, o ciclo é: mexer na UI, exportar, substituir o arquivo, abrir PR. Com HCL, cada ajuste visual precisa ser reconciliado à mão entre duas representações que divergem — e dashboard é trabalho visual, que se faz olhando.

Para 13 widgets com fórmulas, `conditional_formats`, `query_table` e `toplist`, seriam algumas centenas de linhas de HCL para proteger um diff que ninguém vai ler widget a widget.

## O preço, que a 0026 já tinha visto

> *"dashboard é trabalho visual, e com ele sob Terraform uma edição na UI é desfeita no próximo apply"*

Continua verdade, e é aceito: **o Git passa a ser a verdade**. Quem editar na UI e não exportar, perde no apply seguinte.

Era por causa desse problema que a 0026 chegou a desenhar uma esteira de captura, normalização de JSON e auto-merge — e foi esse desenho, não o dashboard, que ela matou. A decisão aqui é mais barata: aceitar a direção única, como já acontece com monitor, webhook e integrações.

## Alternativas descartadas

**`templatefile()` em vez de `file()`**, parametrizando `env` e a lista de serviços a partir das variáveis do stage. Resolveria a duplicação — o JSON fixa `env:prod` e os cinco nomes, que já existem em `var.environment` e no `local.servicos`. Descartada porque o projeto tem **um ambiente só**, então o ganho é teórico, e o custo é concreto: o arquivo deixa de ser JSON válido e não pode mais ser colado na UI para comparar.

**Não versionar**, deixando o JSON no repositório só como artefato do relatório. Descartada pelo motivo que criou a [0023](0023-datadog-como-codigo.md): a conta do Datadog é trial e **já morreu uma vez**. O que não está em código não volta por apply.

**Dashboard no Grafana em vez de mais um no Datadog.** O Grafana já tem o dele, e ele atende o requisito. Mas as métricas deste aqui — p99, quebra por `resource_name`, erro por status — vêm do `datadog/connector`, que é APM. Reproduzi-las no Prometheus exigiria instrumentação adicional para resolver um problema de conveniência de gravação.

## Consequências

- **O stage `datadog/` ganha um diretório `dashboards/`.** O arquivo é o export literal da UI, e é assim que deve continuar: reexportar e substituir, nunca editar à mão
- **Um `output` com a URL do dashboard**, para o roteiro da demonstração não depender de alguém procurar na conta
- **A tag `ai:created_with_ai` veio no export e foi removida**, trocando `tags` por lista vazia. É a única edição à mão no arquivo, e ela **se corrige sozinha**: o apply envia `tags: []`, o dashboard na conta perde a tag, e a próxima exportação já sai sem ela. Lista vazia e não a chave removida — omitir o campo deixaria tags existentes intocadas, em vez de limpá-las
- **O `plan` do stage `datadog` continua funcionando com o ambiente destruído**, porque o recurso novo não fala com a AWS. A propriedade que a [0027](0027-ciclo-de-vida-do-stage-datadog.md) protege segue intacta

## O que esta decisão não resolve

**A divergência silenciosa.** Se alguém editar na UI e ninguém rodar apply, o dashboard e o arquivo divergem sem aviso até o próximo apply desfazer tudo. Não há detecção, e a 0026 tinha razão em achar isso incômodo — a diferença é que agora é um incômodo conhecido em vez de um desenho a construir.

**A duplicação da lista de serviços e do `env`.** Estão fixos no JSON e também nas variáveis do stage. Se um ambiente novo aparecer, o `templatefile()` descartado acima volta à mesa.

## Onde aprofundar

[0026](0026-sem-dashboard-no-datadog.md) para por que não havia dashboard, e para o desenho de esteira que foi descartado junto · [0023](0023-datadog-como-codigo.md) para o princípio de SaaS como código · [0022](0022-datadog-connector-desde-o-inicio.md) para de onde vêm as métricas que o dashboard consulta
