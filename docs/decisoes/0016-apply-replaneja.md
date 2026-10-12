# 0016 — O `apply` replaneja em vez de consumir um plano salvo

**Status:** aceita · **Domínio:** IaC · CI/CD · **Data:** Fase 3 · **Fase:** 3

> Registro retroativo, escrito na Fase 4 a partir do código da esteira.

## Contexto

O padrão mais difundido de esteira Terraform é: o job de `plan` grava o `tfplan` como artefato, e o job de `apply` baixa esse artefato e o aplica. A promessa é que **o que foi revisado é exatamente o que será aplicado**.

## Decisão

O `apply` **roda `plan` e `apply` no mesmo job**, contra o state real. Nenhum plano atravessa a fronteira entre execuções.

O `plan` da esteira de PR serve para **revisão humana**, não como insumo do apply.

## Alternativas descartadas

**Passar o `tfplan` como artefato entre jobs.** A promessa de "aplicar exatamente o que foi revisado" é mais frágil do que parece:

- O plano **expira contra o state**. Se qualquer coisa mudou entre o plan e o apply — outro apply, uma alteração manual no console —, o Terraform recusa o plano salvo, e o resultado é uma esteira que falha num momento em que já não há o que revisar
- O `tfplan` é um arquivo binário que **contém valores resolvidos**, inclusive de atributos sensíveis. Guardá-lo como artefato de CI significa guardar isso num lugar com controle de acesso diferente do state
- Ele não é legível no PR de todo modo — o que a pessoa revisa é a saída em texto, que a esteira já publica como comentário

## Consequências

- O `apply` pode divergir do plano comentado no PR. **Isso é a verdade, não um defeito:** se divergiu, é porque o mundo mudou, e aplicar o plano velho seria pior
- O gate é o **GitHub Environment**, não o artefato: quando `environment` é preenchido pelo caller, o apply para e espera aprovação com o plano fresco à vista
- Como o `plan` de PR não precisa ser preservado, ele roda com `-lock=false`, e um PR aberto não bloqueia o state de ninguém
- A ordem entre stages fica no caller, com `needs:` — uma `matrix` roda em paralelo e não encadearia a dependência entre `infra` e `addons`

## Onde aprofundar

[`reusable-workflows/.github/workflows/terraform-apply.yml`](https://github.com/fiap-tech-challenge-devops/reusable-workflows/blob/main/.github/workflows/terraform-apply.yml) e `docs/terraform-apply/` no mesmo repositório
