#!/usr/bin/env bash
#
# Confere o índice do README.md contra os arquivos de ADR.
#
# As tabelas por domínio são escritas à mão de propósito: a descrição de cada
# linha diz por que aquela decisão importa PARA aquele domínio, e isso não sai
# do título. A 0032 é o exemplo — em Observabilidade ela é "o Datadog notifica,
# a Action tria e reporta"; em CI/CD é "filtro de transição, disjuntor e report
# no Job Summary". Gerar as tabelas achataria as duas no mesmo texto.
#
# O preço de escrever à mão é a deriva: a 0027 ficou fora de ordem na tabela de
# Observabilidade e ninguém viu. Este script é o que cobra o preço.
#
#   ./verificar.sh
#
# Sai 1 em qualquer divergência, para poder entrar numa esteira.

set -uo pipefail
cd "$(dirname "$0")" || exit 1

falhas=0
erro() { echo "  ✘ $1"; falhas=$(( falhas + 1 )); }

# O cabeçalho usa "Kubernetes · GitOps"; a tabela chama a seção de
# "Kubernetes e GitOps". É a única divergência de nome, e mora aqui.
secao_de() {
  case "$1" in
    Kubernetes | GitOps) echo "Kubernetes e GitOps" ;;
    *) echo "$1" ;;
  esac
}

campo() {  # $1 = arquivo, $2 = nome do campo -> valor, ou vazio
  sed -n '3p' "$1" \
    | sed -n "s/.*\*\*$2:\*\* //p" \
    | sed -E 's/ · \*\*.*//'
}

arquivos=$(ls [0-9][0-9][0-9][0-9]-*.md 2>/dev/null)
[ -n "$arquivos" ] || { echo "Nenhuma ADR encontrada."; exit 1; }

# --- 1. as tabelas por domínio batem com o campo Domínio? ------------------
echo "1 · Campo Domínio x tabelas por domínio"

# "<seção>\t<número>", na ordem em que aparecem no README
indice=$(awk '
  /^## Por domínio/ { dentro = 1; next }
  /^## Por fase/    { dentro = 0 }
  dentro && /^### /                        { secao = substr($0, 5); next }
  dentro && /^\| \[[0-9][0-9][0-9][0-9]\]/ {
    match($0, /[0-9][0-9][0-9][0-9]/)
    print secao "\t" substr($0, RSTART, 4)
  }
' README.md)

for f in $arquivos; do
  n=${f:0:4}
  dominios=$(campo "$f" "Domínio")

  if [ -z "$dominios" ]; then
    erro "$n: sem campo Domínio na linha 3"
    continue
  fi

  # O separador é "·", de dois bytes em UTF-8 — o IFS do bash separa por byte
  # e não o enxerga. Troca por um delimitador de um byte antes de dividir.
  esperadas=""
  IFS='|' read -ra partes <<< "$(echo "$dominios" | sed 's/ *· */|/g')"
  for p in "${partes[@]}"; do
    p=$(echo "$p" | sed 's/^ *//; s/ *$//')
    [ -n "$p" ] || continue
    s=$(secao_de "$p")
    case "$esperadas" in *"|$s|"*) continue ;; esac
    esperadas="$esperadas|$s|"
    grep -qxF "$(printf '%s\t%s' "$s" "$n")" <<< "$indice" \
      || erro "$n declara '$p' mas não está na tabela '$s'"
  done

  # E o contrário: linha na tabela que o campo não declara.
  while IFS=$'\t' read -r s num; do
    [ "$num" = "$n" ] || continue
    case "$esperadas" in
      *"|$s|"*) ;;
      *) erro "$n está na tabela '$s' mas não declara esse domínio" ;;
    esac
  done <<< "$indice"
done

# --- 2. ordem numérica dentro de cada tabela -------------------------------
echo "2 · Ordem numérica nas tabelas"

while IFS=$'\t' read -r secao nums; do
  # Apara antes de comparar: com espaço sobrando, o sort joga a linha vazia
  # para o início e toda tabela em ordem parecia fora de ordem.
  atual=$(echo "$nums" | tr -s ' ' | sed 's/^ *//; s/ *$//')
  ordenado=$(echo "$atual" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ *$//')
  [ "$atual" = "$ordenado" ] || erro "tabela '$secao' fora de ordem: $atual"
done <<< "$(awk -F'\t' '
  { if ($1 != atual) { if (atual != "") print atual "\t" lista; atual = $1; lista = "" }
    lista = lista $2 " " }
  END { if (atual != "") print atual "\t" lista }
' <<< "$indice")"

# --- 3. toda ADR aparece em alguma tabela, e em exatamente uma fase --------
echo "3 · Cobertura do índice"

for f in $arquivos; do
  n=${f:0:4}
  grep -qF "	$n" <<< "$indice" || erro "$n não aparece em nenhuma tabela por domínio"

  vezes=$(awk -v n="$n" '
    /^## Por fase/ { dentro = 1 }
    dentro && $0 ~ "^\\| \\[" n "\\]" { c++ }
    END { print c + 0 }
  ' README.md)
  [ "$vezes" -eq 1 ] || erro "$n aparece $vezes vez(es) nas tabelas por fase, esperado 1"
done

# --- 4. vocabulário de Status e Validação ----------------------------------
echo "4 · Vocabulário de Status e Validação"

for f in $arquivos; do
  n=${f:0:4}

  status=$(campo "$f" "Status")
  case "$status" in
    aceita | revertida | \
    "superada por "* | \
    "aceita, "*exceto*superad* | \
    "aceita, "*estendida*) ;;
    "") erro "$n: sem campo Status na linha 3" ;;
    *)  erro "$n: Status fora do vocabulário — '$status'" ;;
  esac

  # Validação é opcional: só existe quando a decisão afirma algo que a
  # execução pode desmentir. Ausente não é erro.
  validacao=$(campo "$f" "Validação")
  case "$validacao" in
    "" | "em execução" | "não validada" | parcial) ;;
    *) erro "$n: Validação fora do vocabulário — '$validacao'" ;;
  esac

  # Status não deve carregar validação: são eixos diferentes.
  case "$status" in
    *validada*) erro "$n: Status carrega validação — use o campo Validação" ;;
  esac
done

# --- 5. os links do índice apontam para arquivos que existem ---------------
echo "5 · Links do índice"

# Here-string e não pipe: num pipeline o while roda em subshell e os
# incrementos de `falhas` se perdem — o erro saía na tela e o script
# terminava com sucesso. Medido.
while read -r alvo; do
  [ -n "$alvo" ] || continue
  [ -f "$alvo" ] || erro "link quebrado no README: $alvo"
done <<< "$(grep -o '](\([0-9][0-9][0-9][0-9]-[^)]*\.md\))' README.md \
  | sed 's/](//; s/)$//' | sort -u)"

# --- resultado -------------------------------------------------------------
echo
total=$(echo "$arquivos" | wc -l | tr -d ' ')
if [ "$falhas" -eq 0 ]; then
  echo "✔ $total ADRs, índice consistente."
else
  echo "✘ $falhas divergência(s) em $total ADRs."
  exit 1
fi
