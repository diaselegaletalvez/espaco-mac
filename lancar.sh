#!/bin/bash
#
#  lancar.sh  --  build, notariza, publica o site e cria o release. Tudo.
#  Dias Inc.
#
#  uso:
#     ./lancar.sh              versao do Info.plist
#     ./lancar.sh 1.1          define a versao antes de compilar
#     ./lancar.sh 1.1 --ensaio faz tudo menos publicar
#

set -e

G=$'\033[0;32m'; A=$'\033[1;33m'; V=$'\033[0;31m'; B=$'\033[0;36m'; C=$'\033[0;90m'; N=$'\033[0m'

APP_DIR="$HOME/projetos/Espaco"
SITE_DIR="$HOME/projetos/espaco-site"
REPO="diaselegaletalvez/espaco"

VERSAO_NOVA=""
ENSAIO=0
for arg in "$@"; do
  case "$arg" in
    --ensaio) ENSAIO=1 ;;
    *) [ -z "$VERSAO_NOVA" ] && VERSAO_NOVA="$arg" ;;
  esac
done

etapa() { echo; echo "${B}━━━ $1${N}"; }
ok()    { echo "  ${G}✓${N} $1"; }
erro()  { echo "  ${V}✗${N} $1"; exit 1; }
aviso() { echo "  ${A}!${N} $1"; }

echo
echo "${G}╔══════════════════════════════════════════════╗${N}"
echo "${G}║   Lançando o Espaço                          ║${N}"
echo "${G}╚══════════════════════════════════════════════╝${N}"

etapa "Conferindo o terreno"

command -v gh >/dev/null 2>&1 || erro "o gh não está instalado. Rode: brew install gh"
gh auth status >/dev/null 2>&1 || erro "o gh não está autenticado. Rode: gh auth login"
ok "gh pronto"

[ -d "$APP_DIR" ] || erro "não achei $APP_DIR"
[ -d "$SITE_DIR" ] || erro "não achei $SITE_DIR"
ok "pastas no lugar"

cd "$APP_DIR"

if [ -n "$VERSAO_NOVA" ]; then
  etapa "Marcando a versão $VERSAO_NOVA"
  /usr/bin/sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $VERSAO_NOVA;/g" \
    Espaco.xcodeproj/project.pbxproj
  BUILD_ATUAL=$(date +%Y%m%d%H%M)
  /usr/bin/sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $BUILD_ATUAL;/g" \
    Espaco.xcodeproj/project.pbxproj
  ok "versão $VERSAO_NOVA, build $BUILD_ATUAL"
fi

etapa "Compilando, assinando e notarizando"
./distribuir.sh || erro "o distribuir.sh falhou"

DMG="$APP_DIR/dist/Espaco.dmg"
[ -f "$DMG" ] || erro "não achei o $DMG"

VERSAO=$(defaults read "$APP_DIR/dist/exportado/Espaco.app/Contents/Info.plist" \
         CFBundleShortVersionString 2>/dev/null || echo "1.0")
TAMANHO=$(du -h "$DMG" | cut -f1 | xargs)
ok "Espaço $VERSAO · $TAMANHO"

if [ "$ENSAIO" = "1" ]; then
  echo
  aviso "modo ensaio: parei antes de publicar"
  echo "  o .dmg está em $DMG"
  exit 0
fi

etapa "Publicando o site"
cd "$SITE_DIR"
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -q -m "Site: Espaço $VERSAO"
  ok "commit feito"
else
  ok "site já estava em dia"
fi

git push -q -u origin main 2>/dev/null || git push -q origin main
ok "site no ar"

etapa "Guardando o código do app"
cd "$APP_DIR"
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -q -m "Espaço $VERSAO"
  ok "commit feito"
fi

if git remote | grep -q origin; then
  git push -q origin HEAD 2>/dev/null && ok "código enviado" || aviso "não consegui enviar o código"
else
  aviso "o app não tem repositório remoto — só o site foi publicado"
fi

etapa "Criando o release v$VERSAO"

NOTAS="/tmp/notas-espaco-$VERSAO.md"
cat > "$NOTAS" <<FIMNOTAS
## O que o Espaço faz

**Limpar** — Revisão (um botão, cinco varreduras, uma lista), Mapa do disco em treemap navegável, Apps com seus resíduos, arquivos Esquecidos, dependências de Projetos parados, e Duplicados por SHA-256.

**Cuidar** — Proteção com seis checagens de segurança, Saúde (memória, CPU, bateria real) e Meu Mac.

**Acompanhar** — relatório diário em markdown com trinta dias de histórico, e Automação com o manual de comandos.

## Como ele decide o que apagar

- **Risco zero** (cache, DerivedData, símbolos de debug) — apagado direto, o espaço volta na hora
- **Risco médio e alto** (node_modules, Pods, Archives) — vai pra Lixeira, dá pra voltar atrás

Nada some sem a categoria dizer, em português, o que você perde.

## Proteção

Seis checagens verificáveis: certificados raiz personalizados, compartilhamento e acesso remoto ligados, apps com permissão de Acessibilidade, DNS e proxy alterados, XProtect desatualizado, contas de administrador extras. Mais uma leitura de rede que diz se você tem VPN ativa.

Não é antivírus e não compara arquivos com listas de malware — e o app fala isso na própria tela.

## Vigilância e atualização

Com o app aberto, ele observa LaunchAgents, LaunchDaemons e a pasta Aplicativos, e avisa na hora quando algo novo passa a rodar no boot. Checa versão nova uma vez por dia e, antes de instalar, confere se o download foi assinado pelo mesmo desenvolvedor do app em execução.

## O manual se adapta

Os comandos de terminal não são fixos: o app mede a sua máquina e monta os blocos com os seus caminhos e tamanhos. Sem Xcode instalado, o bloco de Xcode não aparece.

## Instalação

Abra o .dmg e arraste pra pasta Aplicativos. Assinado com Developer ID e notarizado pela Apple.

Recomendado dar **Acesso Total ao Disco** em Ajustes → Privacidade e Segurança. Sem isso o app não mede o Library de outros apps e os totais saem menores que a realidade.

Requer macOS 14 ou mais novo.
FIMNOTAS

if gh release view "v$VERSAO" --repo "$REPO" >/dev/null 2>&1; then
  aviso "o release v$VERSAO já existe — substituindo o .dmg"
  gh release upload "v$VERSAO" "$DMG" --repo "$REPO" --clobber
else
  gh release create "v$VERSAO" "$DMG" \
    --repo "$REPO" \
    --title "Espaço $VERSAO" \
    --notes-file "$NOTAS"
fi
ok "release publicado"

etapa "Conferindo"
sleep 3
LINK="https://github.com/$REPO/releases/latest/download/Espaco.dmg"
CODIGO=$(curl -o /dev/null -s -w "%{http_code}" -L "$LINK")
if [ "$CODIGO" = "200" ]; then
  ok "o link de download do site responde"
else
  aviso "o link respondeu $CODIGO — pode levar um minuto pra propagar"
fi

rm -f "$NOTAS"

echo
echo "${G}╔══════════════════════════════════════════════╗${N}"
echo "${G}║   No ar                                      ║${N}"
echo "${G}╚══════════════════════════════════════════════╝${N}"
echo
echo "  release:  ${C}https://github.com/$REPO/releases/tag/v$VERSAO${N}"
echo "  site:     ${C}https://diaselegaletalvez.github.io/espaco${N}"
echo "  download: ${C}$LINK${N}"
echo
echo "  ${A}Se o site ainda não abrir, ative o Pages uma vez:${N}"
echo "  ${C}Settings → Pages → Source: GitHub Actions${N}"
echo

open "https://github.com/$REPO/releases/tag/v$VERSAO" 2>/dev/null || true
