# ESCOPO — Espaço 2.2

Fonte da verdade desta release. Se não está aqui, não entra.

## 1. Versão e status

- Versão: **2.2** (o Xcode ainda está em `MARKETING_VERSION = 2.1`, build `202609071013`)
- Status: **rascunho** — o Dias precisa aprovar antes do Rex implementar

## 2. O que já enviou (2.1)

Commit `372391e` (2026-09-07): "Espaço 2.1: nível de risco, pareamento e pacotes de automação". Release público `v2.1` em [diaselegaletalvez/espaco](https://github.com/diaselegaletalvez/espaco/releases/tag/v2.1), com `Espaco.dmg` e vários `.pkg`. Entrou pareamento local (HTTP `:8787`), níveis de risco (zero padrão; médio opcional, vai pra Lixeira), CLI `espaco nivel` / `espaco limpar medio`, e dois consertos do pareamento (`import Network` faltando e avisos de concorrência no servidor). A 2.0 já tinha proteção, vigilância em segundo plano, auto-update, rede/VPN, manual adaptativo, tela de duplicados e Meu Mac.

## 3. Fora desta release

- **Não mudar regras de limpeza** (o que some, o que vai pra Lixeira, pastas, cortes) sem aprovação explícita do Dias. Qualquer proposta assim vai marcada "precisa da aprovação do Dias".
- **Não expandir o risco automático.** Zero continua o padrão. Pacote médio e `espaco limpar medio` já existem — não criar um terceiro nível nem ligar médio por padrão.
- **Não mexer em notarização, assinatura, identidade de signing, credenciais nem no feed de update.**
- App de celular é outro repo (`espaco-mobile`). Daqui, só o lado Mac.
- Site (`diaselegaletalvez/espaco`) é outro repo — não editar daqui.

## 4. O que entra na 2.2

Só higiene e alinhamento do que já está sujo ou pela metade. Sem feature nova.

1. **Este arquivo** vira a fonte da verdade da release.

2. **Nomes dos `.pkg` e artefatos do release.** Confirmado o emaranhado:
   - `notas/2.1.md` fala em três downloads: `Espaco.dmg`, `Espaco-Automacoes.pkg`, `Espaco-Automacoes-Medio.pkg`
   - `criar-pacote.sh` / `lancar.sh` geram `Espaco-Automacoes-riskzero.pkg` e `Espaco-Automacoes-riskmedio.pkg`
   - o release `v2.1` no GitHub tem os quatro `.pkg` ao mesmo tempo (os nomes das notas **e** os `risk*`)
   - `criar-pacote.sh --medio` reescreve no lugar `pacote/scripts/postinstall` e `pacote/recursos/welcome.html` e **não desfaz**: o `welcome.html` commitado está no texto de risco médio, e o default do postinstall ficou `NIVEL=medio`
   - o CLI `espaco` ainda imprime `VERSAO="2.0"`
   
   Escolher **um** esquema de nome (o das notas ou o `risk*`), fazer script, notas e próximo release baterem, e parar de deixar o payload sujo depois do `--medio`. Não muda o que a limpeza apaga.

3. **Link do app de celular.** `notas/2.1.md` aponta pra [espacoapp](https://github.com/diaselegaletalvez/espacoapp), que **não existe**. O repo certo é [diaselegaletalvez/espaco-mobile](https://github.com/diaselegaletalvez/espaco-mobile). Corrigir o link nas notas (e na `notas/2.2.md`, quando existir). `diaselegaletalvez/espaco-app` é cópia velha **deste** repo de Mac (parou no commit `f5b6fd0`) — não tratar como app de celular.

4. **Site (follow-up, outro repo).** O README de `diaselegaletalvez/espaco` ainda diz "sem assinatura" e "nome provisório". O `index.html` mistura "Grátis e sem assinatura" no `og:description` com o parágrafo de notarizado. Não editar daqui; anotar pro Dias no repo do site.

5. **Pareamento no Mac, só o que está pela metade.** Sem feature nova, sem mexer no protocolo nem no app Expo.
   - `enum Escopo` em `Pairing.swift` (`ler` / `limparSeguro` / `limparTudo`) não é usado em lugar nenhum — o servidor fala em string `"seguro"`.
   - As notas da 2.1 dizem que o servidor só existe com aparelho pareado; `fecharPareamento()` não chama `desligar()`, então um QR que expira deixa a porta 8787 aberta.
   
   Arrumar isso. Nada além.

`ContentView.swift` ainda é o "Hello, world!" do template e não entra em tela nenhuma — pode sair na mesma faxina, sem ser item próprio.

## 5. Critério de pronto / como o Dias lança

Este agente **não compila Swift**. Build, assinatura, notarização e release só no Mac do Dias.

Pronto quando:

- [ ] Dias aprovou este ESCOPO
- [ ] Nomes de `.pkg`, notas e `lancar.sh` falam a mesma língua
- [ ] `criar-pacote.sh` não deixa `welcome.html` / `postinstall` sujos
- [ ] CLI `espaco` mostra a versão certa
- [ ] Link do celular aponta pra `espaco-mobile`
- [ ] `notas/2.2.md` escrita (o `lancar.sh` usa `notas/$VERSAO.md`)
- [ ] Zero continua o padrão; nenhuma regra nova de delete

Lançar, no Mac, a partir de `espaco-mac`:

```
./lancar.sh 2.2
```

`--ensaio` faz tudo menos publicar. O script compila via `distribuir.sh`, monta os dois `.pkg`, commita, publica o site em `~/projetos/espaco-site` e cria o release `v2.2` em `diaselegaletalvez/espaco`.

## 6. Aprovações que param o Rex

Sem o Dias, o Rex **não**:

- apaga arquivo do disco do usuário, nem muda o que a limpeza apaga ou manda pra Lixeira
- muda regra de limpeza, lista de alvos, corte de projeto parado, ou o padrão (zero)
- publica release, sobe asset, ou mexe no feed / GitHub Releases
- mexe em notarização, assinatura ou credencial
- gasta dinheiro (conta Apple, domínio, loja, anúncio)

Qualquer item assim no meio do caminho: para, marca "precisa da aprovação do Dias", espera.
