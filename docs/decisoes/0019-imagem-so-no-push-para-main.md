# 0019 — A imagem é construída no PR, mas só publicada no push para `main`

**Status:** aceita · **Domínio:** CI/CD · **Data:** Fase 3 · **Fase:** 3

> Registro retroativo, escrito na Fase 4 a partir do código da esteira.

## Contexto

O job de imagem precisa decidir duas coisas separadas: **se constrói** e **se publica**. É tentador juntar as duas e só rodar o job depois do merge.

E há um detalhe do GitHub que decide a questão: em evento de `pull_request`, o `github.sha` **não é o commit do branch** — é o SHA de um merge efêmero que o GitHub cria para testar a integração. Esse commit não existe no histórico de ninguém depois que o PR fecha.

## Decisão

O job **sempre** constrói a imagem e **sempre** a escaneia. O push para o ECR é condicional:

```yaml
- name: Push to Amazon ECR
  if: github.event_name == 'push'
  run: docker push ${{ steps.img.outputs.uri }}
```

No PR a imagem é carregada no daemon local (`load: true`, `push: false`), escaneada e descartada com o runner.

## Alternativas descartadas

**Rodar o job de imagem só depois do merge.** O `Dockerfile` deixaria de ser verificado no PR. Um erro de build ou uma CVE CRITICAL na imagem só apareceria já em `main` — justamente onde é mais caro.

**Publicar no PR com uma tag diferente, tipo `pr-123`.** Enche o ECR de imagens que ninguém vai consumir, exige política de ciclo de vida para limpar, e conflita com os repositórios serem `IMMUTABLE` — ver [0020](0020-tag-da-imagem-e-o-sha.md).

## Consequências

- O gate de vulnerabilidade da imagem atua no PR, que é onde há revisão acontecendo
- Toda imagem no ECR corresponde a um commit que existe em `main` — não há tag órfã
- O job de imagem assume a role AWS mesmo em PR, porque precisa do `ecr-login` para montar a URI completa; a publicação é o que fica de fora, não a autenticação

## Onde aprofundar

`go-ci.yml` e `python-ci.yml` em [`reusable-workflows`](https://github.com/fiap-tech-challenge-devops/reusable-workflows/tree/main/.github/workflows)
