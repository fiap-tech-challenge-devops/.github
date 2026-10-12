# 0009 — Log por OTLP no local, stdout mais `filelog` em produção

**Status:** aceita · **Domínio:** Observabilidade · **Data:** 10/10/2026 · **Fase:** 4

## Contexto

Log tem dois caminhos possíveis para chegar ao Collector, e os dois são oficiais:

- **Pelo SDK**, como registro OTLP, com o contexto de trace preso ao registro
- **Pelo stdout**, coletado do disco do nó pelo receiver `filelog`

A decisão de mandar log também para o Datadog, e não só para o Loki, tornou a escolha relevante: o Datadog só correlaciona log e trace se o registro carregar `trace_id` e `span_id`.

## Decisão

**Produção:** stdout, coletado pelo agent com `filelog`.
**Ambiente local:** OTLP, direto do SDK.

E, nos dois casos, **log em JSON com `trace_id` e `span_id`** — no caminho do `filelog`, é o que permite promover os ids a campos do registro.

## Alternativas descartadas

**Só OTLP, também em produção.** Mais simples, mas perde o log de crash: se o processo morre no boot, o SDK nem chegou a inicializar, enquanto o stdout foi capturado. Também é desigual entre linguagens — em Python é configuração, em Go exigiria mais trabalho.

**Só stdout, também no local.** Reproduzir o `filelog` no compose exigiria montar o diretório de logs do Docker, o que no Docker Desktop em Windows é especialmente desagradável.

## Consequências

- São **dois caminhos diferentes** entre local e produção, e isso precisa estar claro para quem depurar
- O formatter JSON no stdout ainda não foi feito — entra junto com o `filelog`, na rodada do Loki
- Em Go, a migração de `log` para `slog` já foi feita e cobre os dois caminhos: `JSONHandler` no stdout e a ponte `otelslog` para OTLP
- Em Python, os ids chegam como atributos (`otelTraceID`); em Go, ocupam os campos nativos `Trace ID` e `Span ID` do registro OTLP

## Onde aprofundar

[Guia de observabilidade](../observabilidade/guia.md), Parte 1, seção de logs
