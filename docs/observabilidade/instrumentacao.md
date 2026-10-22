# Instrumentação: Python e Go

Os cinco serviços emitem a mesma telemetria, mas o caminho para chegar lá é **radicalmente diferente** entre as duas linguagens. Este documento explica por quê, o que cada uma exige, e o que a diferença custa na prática.

Para o formato do dado e como plugar backends, ver o [guia](guia.md).

---

## A diferença fundamental

| | Python | Go |
|---|---|---|
| Como a instrumentação entra | Um wrapper no comando | Código escrito à mão |
| O `app.py` / `main.go` muda? | Quase nunca | Sempre |
| Linhas para instrumentar | ~5 no `requirements.txt`, 1 no `Dockerfile` | ~130 de `otel.go`, mais os pontos de ligação |
| Onde está o risco | Ponto cego silencioso | Esquecer uma peça |

A causa é a natureza das linguagens.

**Python é interpretado e tem *monkey patching*.** O agente se instala antes do seu código importar qualquer biblioteca, e substitui funções em tempo de execução. Quando o `app.py` chama `requests.get`, a função que ele encontra já está instrumentada — e nem sabe disso.

```dockerfile
CMD ["opentelemetry-instrument", "gunicorn", "--bind", "0.0.0.0:8002", "app:app"]
```

Esse prefixo é literalmente toda a ativação. O `opentelemetry-instrument` configura o SDK a partir das variáveis `OTEL_*`, aplica os patches e só então entrega o controle ao gunicorn.

**Go é compilado.** As chamadas de função são resolvidas em tempo de compilação; não há como trocar uma implementação depois. Instrumentar significa **escrever código que chama o SDK**.

Existe auto-instrumentação para Go via eBPF, mas exige contêiner privilegiado no cluster e é menos previsível — foi descartada.

---

## Python: o que vem de graça

### Os pacotes

```
opentelemetry-distro[otlp]==0.66b1
opentelemetry-instrumentation-flask==0.66b1
opentelemetry-instrumentation-requests==0.66b1
opentelemetry-instrumentation-psycopg2==0.66b1
opentelemetry-instrumentation-logging==0.66b1
```

Um por biblioteca instrumentada. O `analytics-service` troca `requests` e `psycopg2` por `botocore`, porque não tem banco relacional nem chama outros serviços por HTTP.

> **Por que `0.xxbY` e não `1.x`?** A API e o SDK do OpenTelemetry são `1.x` estáveis; as bibliotecas de **instrumentação** seguem numeração própria. O sufixo `b` é a norma do ecossistema, não um beta instável avulso.

### O que cada uma cobre

| Pacote | Gera |
|---|---|
| `flask` | Span de servidor por requisição, com rota e status |
| `requests` | Span de cliente **e injeção do `traceparent`** no header de saída |
| `psycopg2` | Span por query, com `db.statement` |
| `botocore` | Span por chamada à AWS: SQS, DynamoDB |
| `logging` | Injeta `trace_id` e `span_id` nos registros |

A propagação entre serviços é o item mais valioso dessa lista: o `requests` instrumentado põe o `traceparent` no header **sem ninguém pedir**, e é isso que faz o trace atravessar a fronteira.

### O que não vem

Nada que dependa de **semântica da aplicação**. O exemplo real está no `analytics-service`: a instrumentação do `botocore` sabe que houve um `receive_message`, mas não sabe que aquela mensagem carrega um contexto de trace. Extrair o `traceparent` e criar o span de consumo foram 45 linhas escritas à mão.

---

## Python: o ponto cego que custou caro

A auto-instrumentação **não é mágica**: ela depende de o código usar a biblioteca pelo caminho convencional. Quando o código passa por cima de um ponto de extensão, a instrumentação some — **sem erro, sem aviso**.

O caso real, no `flag-service`:

```python
cur = conn.cursor(cursor_factory=RealDictCursor)
```

O instrumentador do psycopg2 funciona **substituindo o `cursor_factory` da conexão** por uma fábrica própria, que embrulha a original. Passar a fábrica explicitamente na chamada sobrescreve a instrumentada.

Resultado: spans de Flask e de `requests` chegavam normalmente, e **nenhum span de banco**. Nenhuma exceção, nenhum log. O serviço parecia instrumentado.

A correção é mover a fábrica para a conexão:

```python
pool = SimpleConnectionPool(1, 5, dsn=DATABASE_URL, cursor_factory=RealDictCursor)
cur = conn.cursor()
```

**A lição que vale além deste caso:** quando um span esperado não aparece, a primeira hipótese não deve ser "a instrumentação está quebrada", e sim "o código está usando a biblioteca de um jeito que a instrumentação não enxerga".

---

## Go: o que precisa ser escrito

### `otel.go` — a fundação

Uma função que monta os três providers e devolve um `shutdown`:

| Peça | Papel |
|---|---|
| `resource` | Quem está emitindo. `resource.WithFromEnv()` lê as variáveis `OTEL_*` |
| `TracerProvider` | Exporter OTLP com `BatchSpanProcessor` |
| `MeterProvider` | Exporter OTLP com leitor periódico |
| `LoggerProvider` | Exporter OTLP com `BatchProcessor` |
| **Propagador** | `TraceContext` + `Baggage` |

**O propagador é a peça que quebra tudo em silêncio se faltar.** Sem ele, o SDK ignora o `traceparent` recebido e inicia um trace novo a cada requisição. Tudo o mais funciona — os spans aparecem, com nome e duração corretos — e a correlação entre serviços simplesmente não existe.

### Os pontos de ligação

```go
// servidor: nomeia o span pela rota e descarta o /health
otelhttp.NewHandler(mux, "", otelhttp.WithSpanNameFormatter(...), otelhttp.WithFilter(...))

// cliente HTTP: injeta o traceparent nas chamadas de saída
&http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)}

// banco
otelsql.Open("pgx", databaseURL)

// Redis
redisotel.InstrumentTracing(rdb)
```

Em Python, o nome do span por rota e o filtro do `/health` são variáveis de ambiente. Em Go, são código — `WithSpanNameFormatter` e `WithFilter`.

### Graceful shutdown deixa de ser luxo

Os dois serviços usavam `http.ListenAndServe` com `log.Fatal`, o que impede qualquer `defer` de rodar. Com `BatchSpanProcessor`, isso significa **perder os últimos spans a cada encerramento** — justamente os do momento em que algo deu errado.

Passou a ser `http.Server` com captura de `SIGTERM`, e o `shutdown` dá flush nos três providers.

---

## Go: a propagação de contexto é o trabalho de base

Esta é a diferença conceitual mais importante entre as duas linguagens.

Em Python, o contexto viaja num mecanismo implícito do interpretador — você não o vê. Em Go, ele é **um parâmetro explícito** que alguém precisa carregar.

```go
func (a *App) getDecision(ctx context.Context, userID, flagName string) (bool, error)
```

Se uma função no meio do caminho não recebe `ctx`, a cadeia quebra ali — e tudo abaixo dela nasce órfão.

No `auth-service`, que é raso, foram **duas linhas**: `QueryRow` virou `QueryRowContext`. No `evaluation-service`, o `ctx` atravessa **seis funções, duas goroutines paralelas e uma fronteira assíncrona**.

Três casos que apareceram ali:

**O contexto global do Redis tinha que morrer.**

```go
var ctx = context.Background()   // removido
```

Funcionava — o cliente só precisa de um `context.Context` qualquer. Mas significava que nenhuma operação de cache apareceria dentro do trace da requisição.

**As goroutines paralelas capturam o `ctx` do closure**, e é isso que faz as duas chamadas aparecerem como spans irmãos sob a mesma raiz, em vez de dois traces soltos.

**A goroutine que sobrevive à resposta** usa `context.WithoutCancel`:

```go
eventCtx := context.WithoutCancel(ctx)
go a.sendEvaluationEvent(eventCtx, userID, flagName, result)
```

O evento é publicado depois de a resposta ser enviada, e o contexto da requisição é cancelado nesse momento. Passar `ctx` direto abortaria o envio no meio. O `WithoutCancel` preserva o trace e descarta o cancelamento.

---

## Propagação: síncrona e assíncrona

### HTTP — automática nas duas linguagens

O `traceparent` vai no header. Em Python, o `requests` instrumentado o injeta; em Go, o transport do `otelhttp`. Do outro lado, o servidor instrumentado o extrai.

Resultado real, uma requisição atravessando as duas linguagens:

```
flag-service   GET /flags              Server   (Python)
└── flag-service   GET                 Client   (Python)
    └── auth-service   GET /validate   Server   (Go)      ← a fronteira
```

### Fila — manual, e com uma regra diferente

Nenhuma das duas instrumentações sabe que uma mensagem carrega contexto. No `evaluation-service`, o `traceparent` é injetado à mão nos `MessageAttributes`; no `analytics-service`, extraído de lá.

Duas armadilhas:

**O SQS não devolve atributos a menos que você peça.** Sem `MessageAttributeNames=['All']` no `receive_message`, o produtor injeta corretamente e o consumidor nunca recebe — a propagação parece quebrada no lado errado.

**Lote usa _span link_, não parent-child.** Um poll traz até dez mensagens, de traces diferentes. Como **um span tem um pai só**, a convenção de mensageria usa link:

```
Span:  process togglemaster-evaluation-events   Kind: Consumer
Links:
  SpanLink #0 → Trace ID: f8fb10491ccc...      ← o trace do produtor
```

---

## O ponto cego que vale para as duas linguagens

**O span diz onde quebrou. Ele não diz por quê.**

Descoberto em 22/10, durante o ensaio do [roteiro de incidente](roteiro-de-incidente.md). O trace mostrava a cascata inteira — `evaluation` → `flag` → `auth` → `sql.conn.query` —, o span raiz vinha marcado como `502`, e o Datadog estampava:

> *Missing error message and stack trace*

Enquanto o log do mesmo serviço, no mesmo instante, dizia tudo:

```
"Erro ao avaliar flag"  erro: "flag-service retornou status 401"
```

### Por que acontece

A instrumentação automática marca o status do span a partir do **protocolo**: viu `502`, marcou erro. É tudo que ela pode saber.

A frase que explica o incidente nasce no código, camadas acima:

```go
// evaluator.go:130
return nil, fmt.Errorf("flag-service retornou status %d", resp.StatusCode)
```

E morre no `slog`. Nada a entrega ao span.

**Instrumentação automática captura o que o protocolo expõe; o porquê só o domínio sabe.**

### O que preencheria

São duas chamadas, com papéis diferentes:

```go
span.RecordError(err)                      // evento de exceção: tipo, mensagem, stack
span.SetStatus(codes.Error, err.Error())   // descrição no status
```

O Datadog mapeia a primeira para `error.message`, `error.type` e `error.stack` — o trio que ele reclama de não ter.

Em Python, o equivalente é `trace.get_current_span().record_exception(e)` no bloco de exceção.

### O tamanho da lacuna

**14 caminhos que devolvem 5xx nos cinco serviços, e nenhum anexa o erro ao span.**

| Serviço | Caminhos 5xx | Anexa ao span |
|---|---|---|
| `flag-service` | 6 | não |
| `targeting-service` | 5 | não |
| `auth-service` | 2 | não |
| `evaluation-service` | 1 | não |
| `analytics-service` | — | — |

Os dois `RecordError` que existem no `evaluation-service` estão no `sqs.go`, fora do caminho HTTP.

### Onde **não** vale anexar

Span de cliente que recebeu **`4xx`** não está pobre. Um `401` ali **é** a informação completa: a chamada foi recusada, e o serviço chamado funcionou corretamente ao recusar.

Anexar erro de domínio a esses spans marcaria como falha um comportamento correto — o mesmo motivo pelo qual `4xx` não conta como erro de APM.

A lacuna é no **span raiz do serviço que devolve 5xx**, que é onde quem investiga entra.

### Por que não foi corrigido na Fase 4

Escopo. O enunciado pede instrumentação e trace distribuído, e os dois funcionam — mensagem de erro no span é **qualidade, não requisito**.

A correção é pequena em cada ponto, mas espalhada por cinco repositórios e duas linguagens, cada um com PR e esteira. O tempo da rodada vale mais em PagerDuty, Slack e self-healing, que são requisitos.

Fica mapeado: quem for corrigir sabe onde mexer e o que **não** mexer.

---

## Instrumentando um serviço novo: por onde começar

**Se for Python:**

1. Acrescente os pacotes no `requirements.txt`, um por biblioteca usada
2. Prefixe o `CMD` do Dockerfile com `opentelemetry-instrument`
3. Rode e confira **quais escopos emitiram spans** — se faltar algum esperado, procure o ponto de extensão sobrescrito antes de suspeitar da instrumentação
4. Semântica da aplicação, como contexto em mensagem, é sempre código

**Se for Go:**

1. Copie o `otel.go` de um serviço existente — ele é idêntico, só muda o nome
2. Garanta que o **propagador** está configurado
3. Faça o `ctx` atravessar: do handler até as pontas
4. Ligue `otelhttp` no mux e no client, mais o instrumentador do banco ou do cache
5. Troque `ListenAndServe` por `http.Server` com `SIGTERM`

**Nas duas:** rode `trivy fs` antes de abrir o PR. As dependências novas passam pelo gate de CRITICAL. E, onde o serviço devolver **5xx**, anexe o erro ao span — a instrumentação automática não faz isso, e o trace fica sem o porquê.

---

## Uma observação sobre versões

A linha atual do OTel exige **Go 1.26**, e o projeto está em 1.25. As versões em uso estão congeladas uma linha atrás, por decisão registrada em [0007](../decisoes/0007-permanecer-em-go-1-25.md).

Antes de acrescentar qualquer pacote novo do ecossistema OTel em Go, **verifique o `go` declarado no `.mod` dele**. É o erro mais provável de aparecer primeiro.
