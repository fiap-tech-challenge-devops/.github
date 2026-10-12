# 0020 — A tag da imagem é o SHA do commit, e o CD escreve essa tag no GitOps

**Status:** aceita · **Domínio:** CI/CD · GitOps · **Data:** Fase 3 · **Fase:** 3

> Registro retroativo, escrito na Fase 4 a partir do código da esteira.

## Contexto

Duas perguntas que costumam ser respondidas juntas e erradas: **como a imagem é identificada** e **como o cluster descobre que existe uma imagem nova**.

## Decisão

**A tag é o SHA completo do commit.** Nada de `latest`, nada de SemVer da aplicação. Os repositórios ECR são `IMMUTABLE`, então uma tag nunca é sobrescrita.

**O CD escreve a tag no repositório GitOps.** Depois do push para o ECR, o workflow `cd.yml` clona o `togglemaster-gitops`, altera `image.repository` e `image.tag` em `apps/<serviço>/values-prod.yaml`, valida o YAML resultante e commita em `main`. O Argo CD sincroniza a partir desse commit.

O workflow é idempotente: se a tag já está no arquivo, ele encerra sem commit.

## Alternativas descartadas

**`latest`, ou qualquer tag móvel.** O pod não sabe qual código está rodando. Dois pods do mesmo Deployment podem carregar imagens diferentes se um reiniciar depois de um push. E torna `IMMUTABLE` impossível.

**SemVer da aplicação.** Exige decidir e versionar a cada entrega. Um serviço com entrega contínua acaba com versões sem significado — e o SHA já é a identidade canônica do código.

**Argo CD Image Updater.** Ele consulta o registry e atualiza o que está rodando. Duas objeções:

- **O Git para de ser a fonte da verdade sobre a versão.** O que define o que roda passa a ser "a imagem mais recente que casa com um padrão no ECR", e o estado desejado deixa de estar inteiro no repositório — que é o ponto do GitOps
- O gatilho fica em *polling* do registry, não no merge. Perde-se a relação direta entre "este PR foi aprovado" e "este código subiu"

Com o CD escrevendo no Git, o histórico do repositório GitOps **é** o histórico de deploys: `git log` em `apps/` responde quando cada versão de cada serviço subiu e quem autorizou.

## Consequências

- A promoção precisa de um token com permissão de escrita no repositório GitOps — o único segredo de longa duração que a esteira usa, já que o resto é OIDC ([0015](0015-oidc-sem-chave-estatica.md))
- Um commit de bot em `main` do GitOps a cada entrega; o ruído é o preço da rastreabilidade
- `values-prod.yaml` é editado por máquina e por pessoa no mesmo arquivo. A edição é por regex no **primeiro** `repository:` e no **primeiro** `tag:` do arquivo, o que impõe uma restrição não escrita: nenhum bloco acrescentado acima de `image:` pode ter uma chave com esses nomes, ou a promoção passa a reescrever a linha errada e ainda assim termina com sucesso
- Rollback é um `git revert` no GitOps, não uma operação no cluster

## Onde aprofundar

[`reusable-workflows/.github/workflows/cd.yml`](https://github.com/fiap-tech-challenge-devops/reusable-workflows/blob/main/.github/workflows/cd.yml) e o hub de [Kubernetes e GitOps](../kubernetes/README.md)
