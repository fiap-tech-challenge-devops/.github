# Documentação do ToggleMaster

Porta de entrada da documentação. Ela vive em dois lugares, e cada um tem um trabalho.

| Onde | O quê |
|---|---|
| **Aqui** | O que atravessa repositórios: visão por domínio, guias transversais e o registro de decisões |
| `<repositório>/docs/` | A narrativa de cada problema resolvido, colada no código que descreve |

**A regra:** se o documento descreve algo que vive num repositório só, ele mora lá — é atualizado no mesmo PR que muda o código. Se vincula vários, vem para cá.

---

## Por domínio

| Domínio | O quê |
|---|---|
| [**IaC**](iac/) | Terraform em três stages, OIDC sem chave estática, módulos por tag |
| [**CI/CD**](ci-cd/) | Esteiras por linguagem, gate de CRITICAL, a fronteira entre CI e CD |
| [**Kubernetes**](kubernetes/) | EKS, Karpenter, KEDA e Ingress; Argo CD e a estrutura do GitOps |
| [**Observabilidade**](observabilidade/) | OpenTelemetry, instrumentação, Collector e backends |

Cada hub diz o que o domínio cobre, quais decisões se aplicam a ele, e aponta para a documentação detalhada nos repositórios.

## Decisões

Registro das escolhas que vinculam mais de um repositório: o que foi decidido, **o que foi descartado** e por quê.

→ [**Índice de decisões**](decisoes/) · 29 registros

O número é a ordem em que a decisão foi **registrada**, não em que foi tomada: as da Fase 3 foram escritas retroativamente, durante a Fase 4, e por isso levaram os números altos.

## Guias

| Guia | Domínio |
|---|---|
| [Como o dado flui e como consumi-lo](observabilidade/guia.md) | Observabilidade |
| [Instrumentação: Python e Go](observabilidade/instrumentacao.md) | Observabilidade |
| [Roteiro de incidente](observabilidade/roteiro-de-incidente.md) | Observabilidade |

---

## Mapa dos repositórios

### Plataforma

| Repositório | Papel |
|---|---|
| [`terraform-aws-modules`](https://github.com/fiap-tech-challenge-devops/terraform-aws-modules) | Biblioteca de módulos Terraform, consumidos por tag |
| [`togglemaster-iac`](https://github.com/fiap-tech-challenge-devops/togglemaster-iac) | Infraestrutura AWS |
| [`togglemaster-gitops`](https://github.com/fiap-tech-challenge-devops/togglemaster-gitops) | Manifests sincronizados pelo Argo CD |
| [`reusable-workflows`](https://github.com/fiap-tech-challenge-devops/reusable-workflows) | Esteiras de CI/CD compartilhadas |

### Microsserviços

| Repositório | Stack | Documentos em `docs/desafios/` |
|---|---|---|
| [`auth-service`](https://github.com/fiap-tech-challenge-devops/auth-service) | Go | containerização · errcheck · CVE no `x/crypto` · instrumentação |
| [`evaluation-service`](https://github.com/fiap-tech-challenge-devops/evaluation-service) | Go | containerização · errcheck · CVEs no `x/net` · instrumentação |
| [`flag-service`](https://github.com/fiap-tech-challenge-devops/flag-service) | Python | containerização · ruff · CVEs em dependências · instrumentação |
| [`targeting-service`](https://github.com/fiap-tech-challenge-devops/targeting-service) | Python | idem |
| [`analytics-service`](https://github.com/fiap-tech-challenge-devops/analytics-service) | Python | idem |

### Apoio

| Repositório | Papel |
|---|---|
| [`togglemaster-platform-legacy`](https://github.com/fiap-tech-challenge-devops/togglemaster-platform-legacy) | Ambiente local de testes. Foi o ponto de entrada das Fases 1 e 2 |
| [`.github`](https://github.com/fiap-tech-challenge-devops/.github) | Perfil da organização e esta documentação |

---

## Por fase

A numeração dos documentos em `docs/desafios/` acompanha a fase do Tech Challenge, e cada decisão registra a sua. Para montar o relatório de uma fase:

| Fase | Entrega | Onde olhar |
|---|---|---|
| 1 e 2 | Containerização e deploy em Kubernetes | `*/docs/desafios/01` e `02` |
| 3 | IaC, CI/CD com DevSecOps e GitOps | `*/docs/desafios/03` e `04` · [`iac/`](iac/) · [`ci-cd/`](ci-cd/) · [`kubernetes/`](kubernetes/) · [decisões 0012–0020](decisoes/#fase-3--iac-devsecops-e-gitops) |
| 4 | Observabilidade | `*/docs/desafios/05` · [`observabilidade/`](observabilidade/) · [decisões 0001–0011](decisoes/#fase-4--observabilidade) |

---

## Onde escrever o que

| Situação | Vai para |
|---|---|
| Resolvi um problema em um repositório | `<aquele repositório>/docs/desafios/NN-assunto.md` |
| Decidi algo que vincula mais de um repositório | [`decisoes/`](decisoes/), próximo número da série |
| Escrevi um guia que atravessa repositórios | A pasta do domínio, aqui |
| Expliquei como usar um repositório | O `README.md` dele |
