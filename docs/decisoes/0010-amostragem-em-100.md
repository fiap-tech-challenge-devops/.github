# 0010 — Amostragem de traces em 100%

**Status:** aceita · **Domínio:** Observabilidade · **Data:** 08/10/2026 · **Fase:** 4

## Contexto

A recomendação oficial para produção é amostrar: guardar uma fração dos traces, porque guardar todos custa armazenamento, banda e cota do fornecedor.

## Decisão

`OTEL_TRACES_SAMPLER=parentbased_traceidratio` com `OTEL_TRACES_SAMPLER_ARG=1.0` — ou seja, **todos os traces**.

É um desvio consciente da recomendação, registrado como tal.

## Alternativas descartadas

**Amostragem por taxa fixa**, de 10% por exemplo. Correta para produção real, mas num ambiente de demonstração significa que o trace que você acabou de gerar para mostrar provavelmente não existe.

**Tail sampling no Collector**, que decide depois de ver o trace inteiro e permite guardar todos os que tiveram erro. É o caminho certo em volume, e seria a evolução natural — mas acrescenta um processor com estado e memória.

## Consequências

- Qualquer requisição feita na demonstração tem trace garantido
- Em volume real, isso não se sustenta: o custo cresce com o tráfego
- **O `parentbased` importa:** a decisão de amostrar é tomada na raiz e respeitada pelos serviços seguintes. Sem isso, metade de um trace poderia ser descartada e a árvore chegaria quebrada ao backend
- Quando houver volume, o caminho é tail sampling, não baixar a taxa

## Onde aprofundar

[Guia de observabilidade](../observabilidade/guia.md), Parte 4
