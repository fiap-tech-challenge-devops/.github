# 0018 — Gate em CRITICAL; lint e SAST reportam sem bloquear

**Status:** aceita · **Domínio:** CI/CD · **Data:** Fase 3 · **Fase:** 3

> Registro retroativo, escrito na Fase 4 a partir do código da esteira.

## Contexto

A esteira dos microsserviços tem cinco verificações de natureza diferente: testes, lint, segredo vazado, SAST e vulnerabilidade de dependência e de imagem. Tratar todas como bloqueantes é o reflexo inicial — e o caminho mais curto para uma esteira que ninguém respeita.

## Decisão

Cada verificação bloqueia conforme **o que um achado dela significa**:

| Verificação | Bloqueia? | Por quê |
|---|---|---|
| Build e testes | **Sim** | Código que não compila ou não passa não é candidato a nada |
| Gitleaks (segredo) | **Sim** | Um segredo no histórico é irreversível; `--redact` evita imprimi-lo no log ao reprovar |
| Trivy `fs` e imagem, `severity: CRITICAL` | **Sim** | Severidade máxima, com CVE publicada |
| `golangci-lint` / `ruff` | Não (`continue-on-error`) | Estilo e idioma; o achado é verdadeiro mas não é risco |
| `gosec` / `bandit` (SAST) | Não (`continue-on-error`) | Taxa de falso positivo alta o bastante para transformar o gate em ruído |

Os três stages de IaC são o oposto: lá o misconfig **bloqueia** — ver [0017](0017-trivy-e-checkov.md).

## Alternativas descartadas

**Bloquear em HIGH também.** Dependência transitiva com HIGH sem correção publicada é comum. O gate passaria a reprovar builds que ninguém pode consertar, e a reação previsível seria desligá-lo ou encher o `.trivyignore` — perdendo também o sinal de CRITICAL.

**Bloquear no SAST.** O `gosec` roda com `-severity high` e ainda assim aponta padrões que, lidos em contexto, não são exploráveis. Um gate que a pessoa aprende a contornar é pior que nenhum.

**O Horusec como SAST unificado.** Agregaria vários motores atrás de uma ferramenta só, mas a agregação traz junto a soma dos falsos positivos de todos eles — e o projeto está arquivado.

**O Gitleaks pela action oficial.** Trocado por download do binário em versão fixa: a action exige licença para uso em organização, e o binário dá controle direto sobre a versão, pelo mesmo motivo de [0006](0006-fixar-versao-das-ferramentas.md).

## Consequências

- A diferença entre "reprovou" e "reportou" é visível no PR: a verificação não bloqueante aparece com aviso, não com erro
- **A assimetria é deliberada:** misconfig de IaC é configuração que se corrige escrevendo uma linha; CVE em dependência transitiva depende de terceiro publicar a correção
- Achado HIGH não desaparece — ele fica no log, e já houve caso de ser tratado por decisão explícita em vez de pelo gate. Os 3 HIGH do `auth-service` na Fase 4 foram conscientemente postergados, com registro

## Onde aprofundar

[`reusable-workflows/README.md`](https://github.com/fiap-tech-challenge-devops/reusable-workflows) e os workflows `go-ci.yml` e `python-ci.yml`
