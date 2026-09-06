#!/bin/bash
#
#  distribuir.sh  --  build, assina, notariza e empacota o Espaco num .dmg
#  Dias Inc.
#
#  uso:
#     ./distribuir.sh              build completo + notarizacao
#     ./distribuir.sh --sem-notar  so build e dmg, sem mandar pra Apple
#

set -e

G=$'\033[0;32m'; A=$'\033[1;33m'; V=$'\033[0;31m'; C=$'\033[0;90m'; N=$'\033[0m'

PROJETO="Espaco.xcodeproj"
ESQUEMA="Espaco"
APP="Espaco"
PERFIL="espaco-notarizacao"
SAIDA="$PWD/dist"
ARCHIVE="$SAIDA/$APP.xcarchive"
EXPORTADO="$SAIDA/exportado"

NOTARIZAR=1
[ "$1" = "--sem-notar" ] && NOTARIZAR=0

passo() { echo; echo "${G}==>${N} $1"; }
erro()  { echo "${V}erro:${N} $1"; exit 1; }
aviso() { echo "${A}!${N} $1"; }

cd "$(dirname "$0")"
[ -d "$PROJETO" ] || erro "não achei $PROJETO nesta pasta"

passo "Procurando certificado Developer ID"
IDENTIDADE=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')

if [ -z "$IDENTIDADE" ]; then
  echo
  erro "nenhum certificado 'Developer ID Application' no chaveiro.

  Crie assim:
    Xcode > Settings > Accounts > sua conta > Manage Certificates
    botão + > Developer ID Application

  Depois rode este script de novo."
fi

TEAM=$(echo "$IDENTIDADE" | sed -E 's/.*\(([A-Z0-9]+)\)$/\1/')
echo "  identidade: $IDENTIDADE"
echo "  time:       $TEAM"

passo "Limpando saída anterior"
rm -rf "$SAIDA"
mkdir -p "$SAIDA"

cat > "$SAIDA/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
PLIST

passo "Compilando em Release (pode levar 1-2 min)"
xcodebuild archive \
  -project "$PROJETO" \
  -scheme "$ESQUEMA" \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -destination "generic/platform=macOS" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM" \
  INFOPLIST_KEY_CFBundleDisplayName="Espaço" \
  -quiet || erro "o build falhou. Abra o Xcode e rode ⌘B pra ver o motivo."

passo "Exportando o .app assinado"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORTADO" \
  -exportOptionsPlist "$SAIDA/ExportOptions.plist" \
  -quiet || erro "a exportação falhou"

BUNDLE="$EXPORTADO/$APP.app"
[ -d "$BUNDLE" ] || erro "não achei o $APP.app exportado"

VERSAO=$(defaults read "$BUNDLE/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
BUILD=$(defaults read "$BUNDLE/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "1")
DMG="$SAIDA/Espaco.dmg"
DMG_VERSAO="$SAIDA/Espaco-$VERSAO.dmg"

echo "  versão $VERSAO (build $BUILD)"

passo "Conferindo a assinatura"
codesign --verify --deep --strict --verbose=1 "$BUNDLE" 2>&1 | tail -2

passo "Desenhando o fundo do instalador"
swift gerar-fundo-dmg.swift "$SAIDA" >/dev/null || aviso "não consegui gerar o fundo, o dmg vai sair simples"

passo "Montando o .dmg"
PALCO="$SAIDA/palco"
VOLUME="Espaço"
TEMP="$SAIDA/temp.dmg"

rm -rf "$PALCO" "$TEMP"
mkdir -p "$PALCO/.fundo"

cp -R "$BUNDLE" "$PALCO/Espaço.app"
ln -s /Applications "$PALCO/Applications"

[ -f "$SAIDA/fundo-dmg.png" ] && cp "$SAIDA/fundo-dmg.png" "$PALCO/.fundo/fundo.png"
[ -f "$SAIDA/fundo-dmg@2x.png" ] && cp "$SAIDA/fundo-dmg@2x.png" "$PALCO/.fundo/fundo@2x.png"

hdiutil create \
  -volname "$VOLUME" \
  -srcfolder "$PALCO" \
  -ov -format UDRW \
  -quiet \
  "$TEMP"

passo "Arrumando a janela do instalador"
DISPOSITIVO=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP" | egrep '^/dev/' | head -1 | awk '{print $1}')
sleep 2

osascript <<APPLESCRIPT >/dev/null 2>&1
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 140, 860, 560}

        set opcoes to the icon view options of container window
        set arrangement of opcoes to not arranged
        set icon size of opcoes to 108
        set text size of opcoes to 12
        set background picture of opcoes to file ".fundo:fundo.png"

        set position of item "Espaço.app" of container window to {172, 232}
        set position of item "Applications" of container window to {488, 232}

        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

chmod -Rf go-w "/Volumes/$VOLUME" 2>/dev/null || true
sync
hdiutil detach "$DISPOSITIVO" -quiet
sleep 1

passo "Comprimindo"
rm -f "$DMG"
hdiutil convert "$TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG" -quiet
rm -f "$TEMP"
rm -rf "$PALCO"

echo "  $(du -h "$DMG" | cut -f1) em $DMG"

passo "Assinando o .dmg"
codesign --force --sign "$IDENTIDADE" --timestamp "$DMG"

if [ "$NOTARIZAR" = "0" ]; then
  echo
  echo "${A}Pulando a notarização (--sem-notar).${N}"
  echo "Esse .dmg funciona na sua máquina, mas o Gatekeeper vai bloquear em outras."
  echo
  echo "${G}Pronto:${N} $DMG"
  exit 0
fi

passo "Enviando pra Apple notarizar"

if ! xcrun notarytool history --keychain-profile "$PERFIL" >/dev/null 2>&1; then
  echo
  aviso "o perfil '$PERFIL' ainda não existe no chaveiro."
  echo
  echo "Crie uma vez só, com uma senha de app gerada em appleid.apple.com:"
  echo
  echo "  ${C}xcrun notarytool store-credentials \"$PERFIL\" \\"
  echo "    --apple-id \"gd665742@gmail.com\" \\"
  echo "    --team-id \"$TEAM\" \\"
  echo "    --password \"xxxx-xxxx-xxxx-xxxx\"${N}"
  echo
  echo "Depois rode este script de novo. O .dmg sem notarizar está em:"
  echo "  $DMG"
  exit 1
fi

echo "  isso costuma levar de 1 a 5 minutos..."
xcrun notarytool submit "$DMG" \
  --keychain-profile "$PERFIL" \
  --wait || erro "a notarização falhou. Rode 'xcrun notarytool log <id> --keychain-profile $PERFIL' pra ver o motivo."

passo "Grampeando o selo no .dmg"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

passo "Verificação final"
spctl --assess --type open --context context:primary-signature -v "$DMG" 2>&1 | tail -2

echo
echo "${G}================================================${N}"
echo "${G} Pronto pra distribuir${N}"
echo "${G}================================================${N}"
echo
echo "  arquivo:  $DMG"
echo "  tamanho:  $(du -h "$DMG" | cut -f1)"
echo "  versão:   $VERSAO (build $BUILD)"
echo
echo "Publicar no GitHub:"
echo
cp "$DMG" "$DMG_VERSAO"
echo "  ${C}gh release create v$VERSAO \"$DMG\" \\"
echo "    --repo diaselegaletalvez/espaco \\"
echo "    --title \"Espaço $VERSAO\" \\"
echo "    --notes \"Primeira versão pública.\"${N}"
echo
echo "  ${C}O arquivo se chama Espaco.dmg de propósito: o site aponta pra"
echo "  /releases/latest/download/Espaco.dmg, que só funciona com nome fixo.${N}"
echo
