# 0006 — Fixar a versão das ferramentas de lint e SAST na esteira

**Status:** aceita · **Domínio:** CI/CD · **Data:** 10/10/2026 · **Fase:** 4

## Contexto

Um pull request de instrumentação reprovou no job `Linter` sem que o código tivesse problema:

```
ruff failed
  Cause: Required version `>=0.16, <0.17` does not match the running version `0.17.0`
```

A esteira rodava `pip install ruff`, **sem fixar versão**. Quando a 0.17.0 saiu, o `required-version` dos serviços passou a recusar a própria ferramenta que a esteira instalava. O lint morreu ao carregar a configuração, sem analisar uma linha.

Qualquer PR nos três serviços Python quebraria igual naquele dia.

## Decisão

Fixar a versão de tudo que é instalado por gerenciador de pacote nos workflows reutilizáveis:

| Ferramenta | Versão |
|---|---|
| `ruff` | `0.17.0` |
| `bandit` | `1.9.4` |
| `pytest` | `9.1.1` |
| `golangci-lint` | `v2.14.0` |

Publicado na `v2.2.5` do `reusable-workflows`.

## Alternativas descartadas

**Só ampliar o `required-version` no `ruff.toml`.** Desbloqueia o PR, mas adia o problema para a 0.18 — e não resolve o `golangci-lint`, que rodava em `latest` e era a próxima ocorrência esperada, com agravante: ali o lint *analisa* o código, então uma versão nova traz regras novas e o mesmo commit passa hoje e reprova amanhã.

## Consequências

- O mesmo commit produz o mesmo resultado hoje e daqui a seis meses
- Subir uma ferramenta passa a ser decisão explícita, com PR e tag
- **Rodar a ferramenta local em versão diferente dá resultado diferente do CI** — as versões estão no workflow
- O critério fica coerente com o resto do projeto, que já fixa actions, módulos Terraform e os próprios workflows por tag

## Onde aprofundar

`reusable-workflows`, release `v2.2.5`
