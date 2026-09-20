#!/bin/bash
#
#  criar-pacote.sh  --  monta o .pkg das automações do Espaço
#  Dias Inc.
#
#  uso:
#     ./criar-pacote.sh              assinado e notarizado
#     ./criar-pacote.sh --sem-notar  só monta, pra testar
#

set -e

G=$'\033[0;32m'; A=$'\033[1;33m'; V=$'\033[0;31m'; B=$'\033[0;36m'; C=$'\033[0;90m'; N=$'\033[0m'

cd "$(dirname "$0")"

ID="com.diaselegaletalvez.espaco.automacoes"
NOME="Espaco-Automacoes"
PERFIL="espaco-notarizacao"
SAIDA="$PWD/dist"
VERSAO=$(defaults read "$PWD/dist/exportado/Espaco.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "2.2")

NOTARIZAR=1
NIVEL="zero"
for arg in "$@"; do
  case "$arg" in
    --sem-notar) NOTARIZAR=0 ;;
    --medio) NIVEL="medio" ;;
  esac
done

if [ "$NIVEL" = "medio" ]; then
  NOME="Espaco-Automacoes-Medio"
  TITULO="Automações do Espaço · risco médio"
else
  NOME="Espaco-Automacoes"
  TITULO="Automações do Espaço"
fi

passo() { echo; echo "${B}==>${N} $1"; }
ok()    { echo "  ${G}✓${N} $1"; }
erro()  { echo "  ${V}✗${N} $1"; exit 1; }
aviso() { echo "  ${A}!${N} $1"; }

passo "Preparando o conteúdo · nível $NIVEL"

mkdir -p "$SAIDA"
[ -f "$HOME/bin/mac-report.sh" ] || erro "não achei ~/bin/mac-report.sh — é ele que vai dentro do pacote"
cp "$HOME/bin/mac-report.sh" pacote/payload/usr/local/share/espaco/mac-report.sh
chmod +x pacote/payload/usr/local/share/espaco/mac-report.sh
chmod +x pacote/payload/usr/local/bin/espaco

PALCO=$(mktemp -d)
trap 'rm -rf "$PALCO"' EXIT
mkdir -p "$PALCO/scripts" "$PALCO/recursos"
cp -R pacote/scripts/. "$PALCO/scripts/"
cp -R pacote/recursos/. "$PALCO/recursos/"
chmod +x "$PALCO/scripts/postinstall"

python3 - "$NIVEL" "$PALCO/scripts/postinstall" <<'PYNIVEL'
import sys, pathlib, re
nivel = sys.argv[1]
p = pathlib.Path(sys.argv[2])
s = p.read_text()
s = re.sub(r'NIVEL="\$\{ESPACO_NIVEL:-\w+\}"',
           f'NIVEL="${{ESPACO_NIVEL:-{nivel}}}"', s, count=1)
p.write_text(s)
PYNIVEL

if [ "$NIVEL" = "medio" ]; then
  python3 - "$PALCO/recursos/welcome.html" <<'PYWELCOME'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
s = s.replace("<h2>Automações do Espaço</h2>",
              "<h2>Automações do Espaço · risco médio</h2>")
s = s.replace("<li>Uma <b>primeira limpeza de risco zero</b> roda agora: caches do Xcode, npm, Homebrew, Chrome e afins</li>",
              "<li>Uma <b>primeira limpeza</b> roda agora: os caches de sempre, <b>mais as dependências de projetos parados há mais de 60 dias</b></li>")
s = s.replace("<b>O que este pacote não faz.</b> Ele não apaga nada que exija decisão sua — node_modules, Pods, Archives do Xcode, apps ou arquivos pessoais ficam intactos. Isso é trabalho do app Espaço, onde você vê cada item e marca antes de confirmar.",
              "<b>Sobre o risco médio.</b> As dependências de projetos parados (<code>node_modules</code>, <code>Pods</code>, <code>.next</code>) vão para a <b>Lixeira</b>, não são apagadas — dá pra voltar atrás até você esvaziá-la. Elas voltam com um <code>npm install</code>. Seu código, seus apps e seus arquivos pessoais não são tocados. Archives do Xcode também não.")
p.write_text(s)
PYWELCOME
  ok "textos do palco ajustados pro risco médio"
fi

ok "CLI e script de relatório no lugar"

passo "Procurando certificado de instalador"
INSTALADOR=$(security find-identity -v 2>/dev/null | grep "Developer ID Installer" | head -1 | sed -E 's/.*"(.*)"/\1/')

if [ -z "$INSTALADOR" ]; then
  aviso "sem certificado 'Developer ID Installer' no chaveiro"
  echo "     Crie em: Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Installer"
  echo "     Vou montar sem assinar — funciona na sua máquina, o Gatekeeper bloqueia em outras."
  ASSINAR=0
else
  ok "$INSTALADOR"
  ASSINAR=1
fi

passo "Montando o componente"
COMPONENTE="$SAIDA/componente.pkg"
pkgbuild \
  --root pacote/payload \
  --scripts "$PALCO/scripts" \
  --identifier "$ID" \
  --version "$VERSAO" \
  --install-location / \
  "$COMPONENTE" >/dev/null
ok "$(du -h "$COMPONENTE" | cut -f1) em componente.pkg"

passo "Escrevendo a distribuição"
cat > "$SAIDA/distribuicao.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>$TITULO</title>
    <organization>com.diaselegaletalvez</organization>
    <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
    <options customize="never" require-scripts="true" hostArchitectures="arm64,x86_64"/>
    <welcome file="welcome.html" mime-type="text/html"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>
    <pkg-ref id="$ID"/>
    <choices-outline>
        <line choice="default"><line choice="$ID"/></line>
    </choices-outline>
    <choice id="default"/>
    <choice id="$ID" visible="false">
        <pkg-ref id="$ID"/>
    </choice>
    <pkg-ref id="$ID" version="$VERSAO" onConclusion="none">componente.pkg</pkg-ref>
</installer-gui-script>
XML
ok "distribuicao.xml"

passo "Montando o instalador"
PKG="$SAIDA/$NOME.pkg"
PKG_ESTAVEL="$SAIDA/$NOME.pkg"
rm -f "$PKG" "$PKG_ESTAVEL"

if [ "$ASSINAR" = "1" ]; then
  productbuild \
    --distribution "$SAIDA/distribuicao.xml" \
    --resources "$PALCO/recursos" \
    --package-path "$SAIDA" \
    --sign "$INSTALADOR" \
    --timestamp \
    "$PKG" >/dev/null
else
  productbuild \
    --distribution "$SAIDA/distribuicao.xml" \
    --resources "$PALCO/recursos" \
    --package-path "$SAIDA" \
    "$PKG" >/dev/null
fi

rm -f "$COMPONENTE" "$SAIDA/distribuicao.xml"
ok "$(du -h "$PKG" | cut -f1) em $(basename "$PKG")"

if [ "$ASSINAR" = "0" ] || [ "$NOTARIZAR" = "0" ]; then
  echo
  aviso "não notarizado"
  echo "  $PKG"
  exit 0
fi

passo "Notarizando"
if ! xcrun notarytool history --keychain-profile "$PERFIL" >/dev/null 2>&1; then
  aviso "o perfil '$PERFIL' não existe. Rode o distribuir.sh primeiro pra criá-lo."
  exit 1
fi

echo "  ${C}1 a 5 minutos...${N}"
xcrun notarytool submit "$PKG" --keychain-profile "$PERFIL" --wait || erro "a notarização falhou"
xcrun stapler staple "$PKG"
ok "selo grampeado"

passo "Conferindo"
spctl --assess --type install -v "$PKG" 2>&1 | tail -2

echo
echo "${G}================================================${N}"
echo "${G} Pacote pronto${N}"
echo "${G}================================================${N}"
echo
echo "  $PKG"
echo "  $(du -h "$PKG" | cut -f1) · versão $VERSAO"
echo
