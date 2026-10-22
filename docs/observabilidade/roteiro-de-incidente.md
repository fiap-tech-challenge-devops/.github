# Roteiro de incidente — rotação de credencial

Como encenar uma falha, ver o alerta disparar e recuperar. Serve para validar a cadeia de observabilidade e para gravar a demonstração da Fase 4.

**A falha é encenada, e isso está assumido.** O que precisa ser real é o **par falha → remédio**: a classe de falha acontece em produção, e a remediação é a que um plantonista executaria.

## A classe de falha

**Rotação de credencial que não chegou aos processos.**

O valor correto está no Secrets Manager, o External Secrets o propaga para o Secret do Kubernetes — e os pods continuam com o antigo, porque **variável de ambiente é lida uma vez, no boot**.

Nenhum controlador fecha essa lacuna:

| Controlador | Por que não cura |
|---|---|
| Kubernetes | o pod está `Running` e a sonda passa — `/health` devolve JSON fixo, sem tocar dependência |
| External Secrets | reconcilia o **objeto** Secret; não toca em pod |
| Argo CD | o Secret é do ExternalSecret, não do Git — fora do `selfHeal` |
| Chart base | tem `checksum/config` do ConfigMap, mas **não pode ter** do Secret: o valor não existe no Git na hora de renderizar |

O resultado é o estado mais confuso possível para quem depura: **a configuração está correta em todo lugar, e o sistema continua quebrado.**

## Pré-requisitos

- Ambiente de pé: `IaC — Apply`
- `aws eks update-kubeconfig --name eks-togglemaster --region us-east-1`
- Os oito monitores aplicados — stage `datadog` do `togglemaster-iac`
- **Não rodar `IaC — Apply` entre quebrar e curar.** O `SERVICE_API_KEY` é gerado por `random_password`, então o Terraform restauraria o valor antes da sua remediação

---

## 1. Linha de base

Deixe o tráfego rodando numa aba, e **não pare até o fim**. Os monitores avaliam janelas móveis: sem requisição não há denominador.

```bash
cd togglemaster-iac/scripts/demo
./gerar-trafego.sh
```

Espere ~2 minutos de `200` antes de quebrar. É o que dá o degrau visível no gráfico.

Confirme que os monitores estão em `OK`, não em `NO DATA`.

## 2. A quebra

```bash
export AWS_PROFILE=VitaoAWS AWS_REGION=us-east-1

# 1. Corrompe na origem — simula a rotação que deu errado
aws secretsmanager put-secret-value \
  --secret-id togglemaster/app/evaluation \
  --secret-string '{"SERVICE_API_KEY":"tm_key_rotacao_incorreta"}'

# 2. Propaga, em vez de esperar o refresh de 1h
kubectl -n togglemaster annotate externalsecret evaluation-service-app \
  force-sync=$(date +%s) --overwrite

# 3. Os pods recarregam o ambiente
kubectl -n togglemaster delete pod -l app=evaluation-service
```

**Corromper na origem, e não só o Secret do Kubernetes**, é o que torna a falha honesta: o ESO propaga fielmente o valor errado, e **não há para onde voltar sozinho**.

`delete pod`, e não `rollout restart`: o segundo anota o pod template, o que é drift em relação ao Git, e o Argo com `selfHeal` reverteria provocando um segundo rollout.

## 3. O que observar

O tráfego vira **`502`** em segundos. E então:

```bash
kubectl -n togglemaster get pods -l app=evaluation-service
# 2/2  Running  Ready
```

**Esta é a cena que importa.** Os pods estão saudáveis para o Kubernetes. A liveness passa, a readiness passa, nada reinicia. Só a observabilidade enxerga.

### A assinatura

| Serviço | Resposta | Erro | Latência |
|---|---|---|---|
| **`evaluation-service`** | **502** | **dispara** | plana |
| `flag-service` | 401 | não | plana |
| `targeting-service` | 401 | não | plana |
| `auth-service` | 401 | não | plana |

**Um monitor dispara. Os outros sete seguem verdes.**

`4xx` não marca span de servidor como erro — é convenção do OpenTelemetry que o Datadog respeita. Num span de servidor, `4xx` significa que o **cliente** errou, e o serviço funcionou ao recusar. Então `flag`, `targeting` e `auth` estão fazendo o trabalho deles corretamente, e os números dizem isso.

**O que distingue esta falha de uma cascata** é a latência plana. Se o `flag` estivesse sofrendo — estrangulado, sobrecarregado —, a latência dele subiria. Aqui ele está bem: o problema está **na chamada**, não em quem a recebe.

Essa leitura só é possível porque há monitor em todos os serviços. Com monitor apenas no `auth-service`, **nenhum dos dois cenários dispararia nada**.

### Efeito colateral invisível

O `evaluation` envia o evento ao SQS só depois de decidir a flag, e com o 502 ele retorna antes. **A fila para de receber**, e o `analytics-service` fica escalado a zero pelo KEDA.

Fila silenciosa seria um bom sinal de incidente — e não há monitor para ela. É a lacuna de saturação registrada na [0029](../decisoes/0029-dois-golden-signals.md), e este cenário mostra por que ela importa.

### Quando esperar o alerta

Cerca de **3 a 4 minutos**: janela de `last_5m` mais `evaluation_delay` de 60s. Não conclua que falhou antes disso.

A taxa vai a **100%**, não a 6% — toda chamada falha. Não há risco de oscilar na borda do limiar.

## 4. A remediação

O Secrets Manager guarda a versão anterior no estágio `AWSPREVIOUS`. **Reverter rotação ruim é exatamente o que esse versionamento existe para resolver.**

```bash
# Descobre a versão boa
ANTERIOR=$(aws secretsmanager list-secret-version-ids \
  --secret-id togglemaster/app/evaluation \
  --query "Versions[?contains(VersionStages, 'AWSPREVIOUS')].VersionId" --output text)

# 1. Reverte a rotação
aws secretsmanager update-secret-version-stage \
  --secret-id togglemaster/app/evaluation \
  --version-stage AWSCURRENT \
  --move-to-version-id "$ANTERIOR"

# 2. Propaga
kubectl -n togglemaster annotate externalsecret evaluation-service-app \
  force-sync=$(date +%s) --overwrite

# 3. Recicla
kubectl -n togglemaster delete pod -l app=evaluation-service
```

**Os três passos têm papéis diferentes**, e vale dizer isso em voz alta na gravação:

O primeiro corrige a **causa**. O segundo é **conveniência** — o ESO faria em até 1h. O terceiro é **insubstituível**: é a lacuna que nenhum controlador do cluster fecha.

## 5. A recuperação

O tráfego volta a `200` assim que os pods novos sobem. O monitor volta a `OK` na avaliação seguinte, com o mesmo atraso de 3 a 4 minutos.

**A recuperação é tão importante quanto o disparo.** Alerta que dispara e não limpa é alerta que a equipe aprende a ignorar.

---

## O que este roteiro ainda não cobre

| Peça | Situação |
|---|---|
| Monitor disparando | pronto |
| Incidente no PagerDuty | falta conectar |
| Notificação no Slack | falta OAuth no workspace |
| Automação executando a remediação | falta construir |

Os três passos da seção 4 são o que a automação vai executar. Rodá-los à mão agora é o ensaio — e a prova de que a sequência funciona antes de automatizá-la.

Quando a automação existir, ela precisa das salvaguardas que a prática recomenda: **diagnosticar antes de remediar**, parar depois de N tentativas no mesmo incidente, e escalar em vez de insistir. Automação que reinicia dez vezes por dia não conserta — mascara.

## Armadilhas conhecidas

**Não quebre o `DATABASE_URL` de nenhum serviço.** O pod morre no boot — o `flag-service` faz `sys.exit(1)` e o `auth` aborta no `db.Ping()`. Sem pod não há span, a razão fica sem denominador, e o monitor vai para no-data em vez de alerta. Com `notify_no_data = false`, ele **se cala** — e no vídeo pareceria que o problema se resolveu sozinho.

**Não pare o gerador de tráfego.** Tudo volta a `NO DATA` em cinco minutos.

**Não rode `IaC — Apply` no meio.** O Terraform restaura o segredo e cura antes da sua automação.

**`kubectl logs -l` assume `--tail=10`.** Use `--tail` explícito ou `deploy/`, ou vai concluir que não chega nada.
