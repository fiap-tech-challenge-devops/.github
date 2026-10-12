# 0011 — Migrar o `go-redis` da v8 para a v9

**Status:** aceita · **Domínio:** Serviços · Observabilidade · **Data:** 10/10/2026 · **Fase:** 4

## Contexto

O `evaluation-service` usava `github.com/go-redis/redis/v8`. Para instrumentar o cache, havia três caminhos, e dois estavam bloqueados:

| Caminho | Situação |
|---|---|
| `redisotel/v8 v8.11.5` | Última versão. Congelada na API do OTel **v1.5.0**, de 2022, e sem manutenção desde o fim de vida do v8 |
| `redisotel/v9 v9.23.0` | Atual, mas exige **Go 1.26** — ver [0007](0007-permanecer-em-go-1-25.md) |
| `redisotel/v9 v9.22.0` | Exige Go 1.25 |

A migração do v8 para o v9 já estava registrada como pendência no documento de CVEs do serviço, adiada por ser "troca de versão maior, com mudança de API, e sem relação com os CVEs".

## Decisão

Subir para `github.com/redis/go-redis/v9` na **v9.22.0**, com `redisotel` da mesma versão.

## Alternativas descartadas

**Ficar no v8 com o `redisotel` antigo.** Funcionaria — Go resolve para a versão maior do OTel —, mas significaria depender de instrumentação congelada há três anos, numa linha do cliente que já saiu de manutenção.

**Não instrumentar o Redis.** O cache é o centro da história do `evaluation-service`: a diferença entre um *hit* e um *miss* é a diferença entre 2 e 19 spans. Deixá-lo fora tiraria justamente o que a instrumentação tem de mais eloquente ali.

## Consequências

- Para o uso deste serviço — `ParseURL`, `NewClient`, `Get`, `Set`, `Ping` —, a mudança de API foi **o caminho de import**; as assinaturas são as mesmas
- Sai uma dependência em fim de vida, que também era a origem de parte do grafo transitivo de teste
- Uma pendência antiga foi fechada por ter finalmente um motivo

## Onde aprofundar

`evaluation-service/docs/desafios/05-instrumentacao-otel.md`
