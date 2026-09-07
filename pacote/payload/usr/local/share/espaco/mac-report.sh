#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
shopt -s nullglob

DIR="$HOME/Relatorios"
EST="$DIR/.estado"
mkdir -p "$DIR"
DATA=$(date '+%Y-%m-%d')
OUT="$DIR/mac-$DATA.md"

LK(){ df -k /System/Volumes/Data | tail -1 | awk '{print $4}'; }
GB(){ awk -v k="${1:-0}" 'BEGIN{printf "%.1f GB", k/1048576}'; }
DL(){ awk -v k="${1:-0}" 'BEGIN{s=(k<0)?"":"+"; printf "%s%.1f GB", s, k/1048576}'; }
TAM(){ [ -e "$1" ] && du -sh "$1" 2>/dev/null | awk '{print $1}' || echo "0B"; }

ANTES=$(LK)
ONTEM=$(cat "$EST" 2>/dev/null || echo "$ANTES")

GORDURA=""
for p in "$HOME/Library/Developer/Xcode/DerivedData" \
         "$HOME/Library/Developer/Xcode/iOS DeviceSupport" \
         "$HOME/Library/Developer/Xcode/Archives" \
         "$HOME/Library/Caches/CocoaPods" \
         "$HOME/.npm/_cacache" \
         "$HOME/Library/Caches/Homebrew"; do
  [ -e "$p" ] && GORDURA="$GORDURA\n| ${p/#$HOME/~} | $(TAM "$p") |"
done

NM_TOTAL=0; NM_LISTA=""
for nm in "$HOME"/projetos/*/node_modules "$HOME"/projetos/*/*/node_modules; do
  [ -d "$nm" ] || continue
  kb=$(du -sk "$nm" 2>/dev/null | awk '{print $1}')
  NM_TOTAL=$((NM_TOTAL + kb))
  proj=$(basename "$(dirname "$nm")")
  NM_LISTA="$NM_LISTA\n| $proj | $(du -sh "$nm" 2>/dev/null | awk '{print $1}') |"
done

rm -rf "$HOME"/Library/Developer/Xcode/DerivedData/* 2>/dev/null
rm -rf "$HOME"/Library/Developer/Xcode/DeviceLogs/* 2>/dev/null
rm -rf "$HOME"/Library/Developer/Xcode/Products/* 2>/dev/null
rm -rf "$HOME"/Library/Caches/ReactNative 2>/dev/null
rm -rf "$HOME"/Library/Caches/node-gyp 2>/dev/null
rm -rf "$HOME"/Library/Caches/electron-builder 2>/dev/null
rm -rf "$HOME"/Library/Caches/com.microsoft.VSCode.ShipIt 2>/dev/null
rm -rf "$HOME"/.npm/_cacache 2>/dev/null
rm -rf "$HOME"/Library/Logs/* 2>/dev/null
rm -rf "$HOME"/.Trash/* 2>/dev/null
command -v brew >/dev/null 2>&1 && brew cleanup --prune=all -s >/dev/null 2>&1
xcrun simctl delete unavailable >/dev/null 2>&1

DEPOIS=$(LK)
LIBEROU=$((DEPOIS - ANTES))
DELTA=$((DEPOIS - ONTEM))
echo "$DEPOIS" > "$EST"

USADO=$(df -h /System/Volumes/Data | tail -1 | awk '{print $3}')
LIVRE=$(df -h /System/Volumes/Data | tail -1 | awk '{print $4}')
PCT=$(df -h /System/Volumes/Data | tail -1 | awk '{print $5}' | tr -d '%')

if   [ "$PCT" -ge 90 ]; then STATUS="CRITICO"; SINAL="[!!]"
elif [ "$PCT" -ge 80 ]; then STATUS="ATENCAO"; SINAL="[!]"
else                        STATUS="OK";      SINAL="[ok]"; fi

UP=$(uptime | sed -E 's/.*up ([^,]*,[^,]*),.*/\1/' | xargs)
BAT=$(pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%' | head -1)
CICLOS=$(system_profiler SPPowerDataType 2>/dev/null | awk -F': ' '/Cycle Count/{print $2; exit}')
COND=$(system_profiler SPPowerDataType 2>/dev/null | awk -F': ' '/Condition/{print $2; exit}')
SAUDE=$(system_profiler SPPowerDataType 2>/dev/null | awk -F': ' '/Maximum Capacity/{print $2; exit}')
MEM=$(memory_pressure 2>/dev/null | tail -1 | grep -Eo '[0-9]+%' | head -1)
[ -z "$MEM" ] && MEM="n/d"

TOPCPU=$(ps -Ao pcpu,comm -r 2>/dev/null | sed -n '2,6p' | awk '{n=$2; sub(/.*\//,"",n); printf "| %s | %s%% |\n", n, $1}')
TOPMEM=$(ps -Ao pmem,comm -m 2>/dev/null | sed -n '2,6p' | awk '{n=$2; sub(/.*\//,"",n); printf "| %s | %s%% |\n", n, $1}')

TMPUP="/tmp/.macreport-updates.$$"
( softwareupdate -l 2>&1 | grep -E '^[[:space:]]*\* Label:' | sed 's/^[[:space:]]*\* Label: /- /' > "$TMPUP" ) &
UPPID=$!
ESPERA=0
while kill -0 "$UPPID" 2>/dev/null && [ "$ESPERA" -lt 90 ]; do sleep 2; ESPERA=$((ESPERA+2)); done
kill "$UPPID" 2>/dev/null
UPDATES=$(cat "$TMPUP" 2>/dev/null); rm -f "$TMPUP"
[ -z "$UPDATES" ] && UPDATES="- nenhuma atualizacao pendente"

TOPLIB=$(du -sh "$HOME"/Library/* 2>/dev/null | sort -rh | head -8 | awk -F'\t' '{printf "| %s | %s |\n", $2, $1}' | sed "s|$HOME|~|g")
TOPAPP=$(du -sh "$HOME"/Library/Application\ Support/* 2>/dev/null | sort -rh | head -8 | awk -F'\t' '{printf "| %s | %s |\n", $2, $1}' | sed "s|$HOME|~|g")

{
echo "# Relatorio do Mac - $DATA"
echo
echo "\`$(date '+%d/%m/%Y as %H:%M')\` - Gabriels-Laptop"
echo
echo "## $SINAL Disco: $STATUS"
echo
echo "| | |"
echo "|---|---|"
echo "| Usado | $USADO ($PCT%) |"
echo "| Livre | $LIVRE |"
echo "| Desde ontem | $(DL $DELTA) |"
echo "| Limpeza automatica de hoje | $(DL $LIBEROU) |"
echo
if [ "$PCT" -ge 85 ]; then
  echo "> **Alerta:** disco em $PCT%. Rode a limpeza pesada."
  echo
fi
echo "## Gordura de dev"
echo
echo "| Pasta | Tamanho antes da limpeza |"
echo "|---|---|"
printf "%b\n" "$GORDURA" | grep -v '^$'
echo
if [ -n "$NM_LISTA" ]; then
  echo "### node_modules em ~/projetos ($(GB $NM_TOTAL) no total)"
  echo
  echo "| Projeto | Tamanho |"
  echo "|---|---|"
  printf "%b\n" "$NM_LISTA" | grep -v '^$'
  echo
fi
echo "## Saude do Mac"
echo
echo "| | |"
echo "|---|---|"
echo "| Ligado ha | ${UP:-n/d} |"
echo "| Bateria | ${BAT:-n/d} |"
echo "| Capacidade maxima | ${SAUDE:-n/d} |"
echo "| Ciclos | ${CICLOS:-n/d} |"
echo "| Condicao | ${COND:-n/d} |"
echo "| Memoria livre | ${MEM} |"
echo
echo "### Mais consomem CPU"
echo
echo "| Processo | CPU |"
echo "|---|---|"
echo "$TOPCPU"
echo
echo "### Mais consomem RAM"
echo
echo "| Processo | RAM |"
echo "|---|---|"
echo "$TOPMEM"
echo
echo "## Atualizacoes pendentes"
echo
echo "$UPDATES"
echo
echo "## Maiores pastas"
echo
echo "### ~/Library"
echo
echo "| Pasta | Tamanho |"
echo "|---|---|"
echo "$TOPLIB"
echo
echo "### ~/Library/Application Support"
echo
echo "| Pasta | Tamanho |"
echo "|---|---|"
echo "$TOPAPP"
echo
echo "---"
echo
echo "_gerado por mac-report.sh_"
} > "$OUT"

ls -t "$DIR"/mac-*.md 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null
cp "$OUT" "$DIR/ultimo.md"
osascript -e "display notification \"Disco $PCT% - liberou $(DL $LIBEROU)\" with title \"Relatorio do Mac\" sound name \"Glass\"" 2>/dev/null
echo "relatorio salvo em $OUT"

TOTAL_KB=$(df -k /System/Volumes/Data | tail -1 | awk '{print $2}')
USADO_KB=$(df -k /System/Volumes/Data | tail -1 | awk '{print $3}')
LIVRE_KB=$(df -k /System/Volumes/Data | tail -1 | awk '{print $4}')

python3 - "$DIR/historico.json" "$DATA" "$TOTAL_KB" "$USADO_KB" "$LIVRE_KB" "$LIBEROU" <<'PYFIM'
import json, sys, os
caminho, data, total, usado, livre, liberou = sys.argv[1:7]
dados = []
if os.path.exists(caminho):
    try:
        dados = json.load(open(caminho))
    except Exception:
        dados = []
dados = [d for d in dados if d.get("data") != data]
dados.append({
    "data": data,
    "total": int(total) * 1024,
    "usado": int(usado) * 1024,
    "livre": int(livre) * 1024,
    "liberou": int(liberou) * 1024,
})
dados.sort(key=lambda d: d["data"])
json.dump(dados[-90:], open(caminho, "w"), indent=1)
PYFIM
