# 0027 — O stage `datadog` sobe com o ambiente e é destruído primeiro

**Status:** aceita · **Domínio:** IaC · CI/CD · Observabilidade · **Data:** 16/10/2026 · **Fase:** 4

> Estende a [0024](0024-encaixe-do-stage-datadog-na-esteira.md) no apply e **supera a [0023](0023-datadog-como-codigo.md) no ponto do destroy**. As duas seguem válidas no resto.

## Contexto

A 0024 definiu que o apply do stage `datadog` fica numa esteira própria, filtrada por `datadog/**`, e registrou que `iac-apply.yml` e `iac-destroy.yml` **ficariam intocados**.

Isso deixou um buraco prático: **"matar e subir tudo" não subia o Datadog.** Depois de um ciclo de destroy e apply, era preciso lembrar de disparar uma segunda esteira — e esquecer disso é silencioso.

E a 0023 havia mantido o `datadog` fora do destroy, com o argumento de preservar o histórico de disparo dos monitores. Esse argumento não sobrevive ao exame neste projeto.

## Decisão

**No apply:** o job `datadog` entra no `iac-apply.yml`, **sem** acrescentar `datadog/**` aos paths dele.

| Push toca | `iac-apply.yml` | `datadog-apply.yml` |
|---|---|---|
| `infra/**` ou `addons/**` | dispara: infra → addons → **datadog** | não |
| `datadog/**` | **não dispara** | dispara: só datadog |

Um dispatch sobe tudo. Mudança de dashboard continua cirúrgica.

**No destroy:** o `datadog` **entra na cadeia**, e é o **primeiro**:

```
datadog → addons → infra
```

E **não bloqueia** os jobs de AWS.

## Por que o argumento da 0023 estava errado

"Preservar o histórico de disparo do monitor" é prática genérica de SRE, aplicada sem olhar o contexto. **Num ambiente destruído toda noite, o histórico de um monitor tem algumas horas.** Não vale a configuração extra que exigiria.

E há um argumento **a favor** de destruir que a 0023 não viu:

**Monitor que sobrevive ao destroy fica observando um ambiente morto.** O cluster cai, o monitor vê ausência de dado, e com `notify_no_data` ligado — que é o padrão razoável para um monitor de 5xx, porque silêncio pode significar queda — ele **dispara todas as noites** e aciona o PagerDuty.

Evitar isso com os monitores sobrevivendo exigiria `notify_no_data = false`, perdendo a detecção de queda, ou um *downtime* agendado cobrindo a janela. Configuração permanente, mantida em troca de nada.

Destruindo junto, o problema não existe.

## Por que primeiro na ordem, e não por último

Os monitores precisam morrer **antes** do ambiente que observam. Por último, haveria alguns minutos de `addons` e `infra` em demolição com monitores ainda ativos — disparando por no-data ou por erro real durante a destruição.

## Por que não pode bloquear a cadeia

**Este é o risco que a decisão introduz, e a precaução é obrigatória.**

A conta é um trial. Se ela expirar, o destroy do `datadog` falha com credencial inválida — e, estando na cadeia com `needs:`, **bloquearia o destroy de `addons` e `infra`**. Resultado: a conta do Datadog morre e o ambiente AWS não consegue mais ser destruído, continuando a custar.

É o mesmo modo de falha do destroy de 15/10, quando uma variável sem valor deixou o `addons` destruído e o `infra` de pé a noite inteira — e aconteceria no pior momento possível.

Então o job do Datadog roda com `continue-on-error`, ou fora da corrente de `needs:`. **A falha dele nunca pode segurar a destruição do que custa.**

## Alternativas descartadas

**Acrescentar `datadog/**` aos paths do `iac-apply.yml`.** Uma esteira só, nenhuma duplicação. Descartada pelo mesmo motivo da 0024: `on.paths` filtra o workflow inteiro, então uma mudança de dashboard dispararia apply de `infra` e `addons` — e com o ambiente destruído a maior parte do tempo, reconstruiria VPC, EKS e três bancos por causa de um widget.

**Manter só a esteira própria.** Zero duplicação e separação mais limpa. Descartada porque "subir tudo" passaria a ser dois dispatches, e o segundo é o que se esquece depois de um rebuild.

**Manter o `datadog` fora do destroy, com um `datadog-destroy.yml` manual.** Preservaria histórico no dia a dia e permitiria o slate limpo quando desejado — útil também para limpar uma conta de trial velha. Descartada por não comprar nada que importe aqui, e por deixar o problema do no-data de pé.

## Consequências

- **~8 linhas de YAML repetidas** entre `iac-apply.yml` e `datadog-apply.yml`, chamando o mesmo workflow da biblioteca. É menos que a maquinaria de condicionais por job que a 0024 descartou
- O state continua próprio: `togglemaster/datadog.tfstate`, no bucket que o `bootstrap` cria e que sobrevive ao destroy
- Depois de cada ciclo, monitor e dashboard são **recriados a partir do Git**. Isso exercita o caminho que a 0023 queria garantir — reconstruir a conta por apply — todos os dias, em vez de só quando o trial morrer
- Monitor recriado tem ID novo. Qualquer coisa que referencie um monitor por ID de fora do Terraform quebra a cada ciclo — e isso inclui um link de dashboard para monitor, se algum dia houver
- Como a [0026](0026-sem-dashboard-no-datadog.md) descartou dashboard no Datadog, o stage tem **só fluxo de direção única**: nada é autorado na UI, então recriar por apply não disputa com edição humana em lugar nenhum

## Onde aprofundar

Hubs de [IaC](../iac/README.md) e [CI/CD](../ci-cd/README.md)
