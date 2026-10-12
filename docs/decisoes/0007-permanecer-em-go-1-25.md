# 0007 — Permanecer em Go 1.25 e OTel 1.46

**Status:** aceita · **Domínio:** Serviços · Observabilidade · **Data:** 10/10/2026 · **Fase:** 4

## Contexto

Ao instrumentar o `auth-service`, a instalação das dependências do OpenTelemetry parou no build:

```
go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp@v0.72.0
    requires go >= 1.26.0 (running go 1.25.14)
```

Não era um pacote isolado: **toda a linha 1.47 do OTel exige Go 1.26**. O mesmo vale para o `redisotel/v9 v9.23.0`.

## Decisão

Ficar na linha imediatamente anterior, que roda em Go 1.25:

| Pacote | Versão |
|---|---|
| `go.opentelemetry.io/otel` e SDK | `v1.46.0` |
| `otelhttp` | `v0.71.0` |
| `otelslog` | `v0.20.0` |
| `otlploggrpc`, `sdk/log` | `v0.22.0` |
| `redisotel/v9` | `v9.22.0` |

## Alternativas descartadas

**Subir o toolchain para Go 1.26.** Tocaria `go.mod`, `Dockerfile` e o workflow de CI dos dois serviços em Go, além do ambiente de todo mundo. Na Fase 3 esse esforço foi feito — de 1.21 para 1.25 —, mas lá havia motivo: um CVE **crítico** reprovando a esteira. Aqui seria apenas uma versão menor mais nova, sem ganho funcional.

## Consequências

- A subida fica para quando houver razão, e será deliberada
- Dependências novas precisam ser verificadas contra o Go exigido antes de entrar
- A API e o SDK de **logs** do OTel saltaram de `v0.22.0` direto para `v1.47.0` ao se estabilizarem: **não existe `v1.46.0` deles**

## Onde aprofundar

`auth-service/docs/desafios/05-instrumentacao-otel.md` e, para o precedente do CVE, `auth-service/docs/desafios/04-cve-x-crypto.md`
