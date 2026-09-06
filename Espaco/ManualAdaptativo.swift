import Foundation

struct PerfilMaquina: Sendable {
    var temXcode = false
    var temHomebrew = false
    var pastaProjetos: URL?
    var navegadores: [String] = []
    var editores: [String] = []
    var jogos: [String] = []
    var runtimesExtras: [String] = []
    var instaladoresMacOS: [URL] = []
    var tamanhos: [String: Int64] = [:]
    var levantadoEm: Date?

    func tamanho(_ chave: String) -> Int64 { tamanhos[chave] ?? 0 }

    var descricao: String {
        var partes: [String] = []
        if temXcode { partes.append("Xcode") }
        if temHomebrew { partes.append("Homebrew") }
        if pastaProjetos != nil { partes.append("projetos") }
        if !navegadores.isEmpty { partes.append(navegadores.joined(separator: " e ")) }
        return partes.isEmpty ? "Mac sem ferramentas de desenvolvimento"
                              : "Detectei " + partes.joined(separator: ", ") + " nesta máquina."
    }
}

enum Perfilador {
    private static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    private static var fm: FileManager { FileManager.default }

    private static func existe(_ caminho: String) -> Bool {
        fm.fileExists(atPath: caminho)
    }

    private static func h(_ p: String) -> URL { home.appending(path: p) }

    static func acharProjetos() -> URL? {
        let candidatos = ["projetos", "Projetos", "Developer", "Projects",
                          "code", "Code", "dev", "src", "repos"]
        for nome in candidatos {
            let u = h(nome)
            guard fm.fileExists(atPath: u.path) else { continue }
            let temNode = (try? fm.contentsOfDirectory(atPath: u.path))?
                .contains(where: { sub in
                    fm.fileExists(atPath: u.appending(path: "\(sub)/node_modules").path)
                    || fm.fileExists(atPath: u.appending(path: "\(sub)/package.json").path)
                    || fm.fileExists(atPath: u.appending(path: "\(sub)/.git").path)
                }) ?? false
            if temNode { return u }
        }
        return nil
    }

    static func appsInstalados(_ nomes: [String]) -> [String] {
        nomes.filter {
            existe("/Applications/\($0).app") || existe(home.appending(path: "Applications/\($0).app").path)
        }
    }

    static func runtimesExtras() -> [String] {
        let saida = Security.shell("/usr/bin/xcrun", ["simctl", "runtime", "list"])
        var out: [String] = []
        for linha in saida.components(separatedBy: .newlines) {
            let l = linha.trimmingCharacters(in: .whitespaces)
            for plataforma in ["tvOS", "watchOS", "xrOS"] where l.hasPrefix(plataforma) {
                let versao = l.components(separatedBy: " ").dropFirst().first ?? ""
                out.append("\(plataforma) \(versao)")
            }
        }
        return out
    }

    static func instaladoresMacOS() -> [URL] {
        guard let itens = try? fm.contentsOfDirectory(at: URL(fileURLWithPath: "/Applications"),
                                                      includingPropertiesForKeys: nil,
                                                      options: [.skipsHiddenFiles]) else { return [] }
        return itens.filter {
            $0.lastPathComponent.hasPrefix("Install macOS") && $0.pathExtension == "app"
        }
    }

    static func levantar() -> PerfilMaquina {
        var p = PerfilMaquina()

        p.temXcode = existe("/Applications/Xcode.app")
        p.temHomebrew = existe("/opt/homebrew/bin/brew") || existe("/usr/local/bin/brew")
        p.pastaProjetos = acharProjetos()

        p.navegadores = appsInstalados(["Google Chrome", "Arc", "Brave Browser",
                                        "Microsoft Edge", "Firefox", "Vivaldi"])
        p.editores = appsInstalados(["Cursor", "Visual Studio Code", "Zed",
                                     "Sublime Text", "Nova"])
        p.jogos = appsInstalados(["Minecraft", "Modrinth App", "Steam",
                                  "Prism Launcher", "Roblox"])

        if p.temXcode { p.runtimesExtras = runtimesExtras() }
        p.instaladoresMacOS = instaladoresMacOS()

        var t: [String: Int64] = [:]

        func medir(_ chave: String, _ caminhos: [URL]) {
            let soma = caminhos.reduce(Int64(0)) { $0 + Scanner.size(of: $1) }
            if soma > 0 { t[chave] = soma }
        }

        if p.temXcode {
            medir("devicesupport", [h("Library/Developer/Xcode/iOS DeviceSupport")])
            medir("deriveddata", [h("Library/Developer/Xcode/DerivedData")])
            medir("archives", [h("Library/Developer/Xcode/Archives")])
            medir("simcaches", [h("Library/Developer/CoreSimulator/Caches"),
                                URL(fileURLWithPath: "/Library/Developer/CoreSimulator/Caches")])
        }

        medir("devcaches", [h("Library/Caches/CocoaPods"), h("Library/Caches/Homebrew"),
                            h("Library/Caches/ReactNative"), h("Library/Caches/electron"),
                            h("Library/Caches/node-gyp"), h(".npm/_cacache"), h(".expo"),
                            h(".gradle/caches"), h("Library/Caches/Yarn"),
                            h("Library/Caches/pnpm")])

        var caches: [URL] = [h("Library/Caches/Google")]
        for nome in ["Claude", "Cursor", "Code"] {
            for sub in ["Cache", "Code Cache", "GPUCache"] {
                caches.append(h("Library/Application Support/\(nome)/\(sub)"))
            }
        }
        if let perfis = try? fm.contentsOfDirectory(
            at: h("Library/Application Support/Google/Chrome"),
            includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for perfil in perfis where perfil.hasDirectoryPath {
                caches.append(perfil.appending(path: "Cache"))
                caches.append(perfil.appending(path: "Code Cache"))
            }
        }
        medir("appcaches", caches)

        medir("sistema", [h("Library/Logs"), h(".Trash")])

        if let raiz = p.pastaProjetos {
            let nm = Scanner.nodeModules(under: raiz)
            medir("projetos", nm)
        }

        for inst in p.instaladoresMacOS {
            t["instalador", default: 0] += Scanner.size(of: inst)
        }

        var pesoJogos: Int64 = 0
        for jogo in ["minecraft", "ModrinthApp"] {
            pesoJogos += Scanner.size(of: h("Library/Application Support/\(jogo)"))
        }
        if pesoJogos > 0 { t["jogos"] = pesoJogos }

        p.tamanhos = t
        p.levantadoEm = Date()
        return p
    }
}

enum ManualAdaptativo {

    private static func gb(_ v: Int64) -> String {
        v > 0 ? Fmt.bytes(v) : "—"
    }

    static func montar(_ p: PerfilMaquina) -> [ComandoManual] {
        var blocos: [ComandoManual] = []
        var n = 0

        func add(_ id: String, _ titulo: String, _ porque: String,
                 _ comando: String, _ risco: Risk, _ ganho: Int64,
                 sudo: Bool = false, lista: Bool = false) {
            blocos.append(ComandoManual(id: id, numero: n, titulo: titulo,
                                        porque: porque, comando: comando,
                                        risco: risco, ganhoTipico: gb(ganho),
                                        precisaSudo: sudo, soLista: lista))
            n += 1
        }

        add("b0", "Preparar o terminal",
            "Roda uma vez por janela do terminal. Desliga os prompts de confirmação do zsh e guarda a senha do sudo pros blocos seguintes.",
            "setopt rm_star_silent\nsudo -v",
            .zero, 0, sudo: true)

        if p.temXcode {
            if p.tamanho("devicesupport") > 0 || p.tamanho("deriveddata") > 0 || p.tamanho("simcaches") > 0 {
                var linhas: [String] = []
                if p.tamanho("devicesupport") > 0 {
                    linhas.append("rm -rf ~/Library/Developer/Xcode/iOS\\ DeviceSupport/*")
                }
                if p.tamanho("deriveddata") > 0 {
                    linhas.append("rm -rf ~/Library/Developer/Xcode/DerivedData/*")
                }
                linhas.append("rm -rf ~/Library/Developer/Xcode/DeviceLogs/*")
                if p.tamanho("simcaches") > 0 {
                    linhas.append("sudo rm -rf /Library/Developer/CoreSimulator/Caches")
                }
                linhas.append("xcrun simctl delete unavailable")
                linhas.append("df -h /System/Volumes/Data | tail -1")

                let total = p.tamanho("devicesupport") + p.tamanho("deriveddata") + p.tamanho("simcaches")
                add("b1", "Símbolos e caches do Xcode",
                    "Símbolos de debug de cada iPhone que você plugou, mais o DerivedData. Tudo se regenera: o Xcode rebaixa os símbolos e o próximo build reconstrói o resto.",
                    linhas.joined(separator: "\n"), .zero, total,
                    sudo: p.tamanho("simcaches") > 0)
            }

            if !p.runtimesExtras.isEmpty {
                add("b2", "Runtimes de \(p.runtimesExtras.map { $0.components(separatedBy: " ").first ?? "" }.joined(separator: ", "))",
                    "Encontrei \(p.runtimesExtras.joined(separator: ", ")) instalado(s). Se você não faz app pra essas plataformas, são gigabytes parados. O iOS não é tocado.",
                    """
                    for id in $(xcrun simctl runtime list | grep -E '^(tvOS|watchOS|xrOS)' | sed -E 's/.* - ([A-F0-9-]{36}) .*/\\1/'); do
                      xcrun simctl runtime delete "$id"
                    done
                    xcrun simctl runtime delete unusable
                    xcrun simctl erase all
                    df -h /System/Volumes/Data | tail -1
                    """,
                    .zero, 0)
            }
        }

        if p.tamanho("devcaches") > 0 {
            var linhas: [String] = []
            let alvos: [(String, String)] = [
                ("Library/Caches/CocoaPods", "~/Library/Caches/CocoaPods"),
                ("Library/Caches/Homebrew", "~/Library/Caches/Homebrew"),
                ("Library/Caches/ReactNative", "~/Library/Caches/ReactNative"),
                ("Library/Caches/electron", "~/Library/Caches/electron"),
                ("Library/Caches/node-gyp", "~/Library/Caches/node-gyp"),
                ("Library/Caches/Yarn", "~/Library/Caches/Yarn"),
                ("Library/Caches/pnpm", "~/Library/Caches/pnpm"),
                (".npm/_cacache", "~/.npm/_cacache"),
                (".expo", "~/.expo"),
                (".gradle/caches", "~/.gradle/caches")
            ]
            let home = FileManager.default.homeDirectoryForCurrentUser
            for (rel, escrito) in alvos where FileManager.default.fileExists(atPath: home.appending(path: rel).path) {
                linhas.append("rm -rf \(escrito)")
            }
            if p.temHomebrew { linhas.append("brew cleanup --prune=all -s") }
            linhas.append("df -h /System/Volumes/Data | tail -1")

            add("b3", "Caches de dependências",
                "Só os que existem nesta máquina. Tudo volta com um install; o custo é o próximo build ser mais lento.",
                linhas.joined(separator: "\n"), .zero, p.tamanho("devcaches"))
        }

        if p.tamanho("appcaches") > 0 {
            var linhas: [String] = []
            for nav in p.navegadores where nav == "Google Chrome" {
                linhas.append("osascript -e 'quit app \"\(nav)\"'")
            }
            for ed in p.editores {
                linhas.append("osascript -e 'quit app \"\(ed)\"'")
            }
            if !linhas.isEmpty { linhas.append("sleep 3") }

            let home = FileManager.default.homeDirectoryForCurrentUser
            for app in ["Claude", "Cursor", "Code"] {
                let base = home.appending(path: "Library/Application Support/\(app)")
                guard FileManager.default.fileExists(atPath: base.path) else { continue }
                for sub in ["Cache", "Code\\ Cache", "GPUCache"] {
                    linhas.append("rm -rf ~/Library/Application\\ Support/\(app)/\(sub)")
                }
            }
            if p.navegadores.contains("Google Chrome") {
                linhas.append("rm -rf ~/Library/Application\\ Support/Google/Chrome/*/Cache")
                linhas.append("rm -rf ~/Library/Application\\ Support/Google/Chrome/*/Code\\ Cache")
                linhas.append("rm -rf ~/Library/Caches/Google")
            }
            linhas.append("df -h /System/Volumes/Data | tail -1")

            let quais = (p.navegadores + p.editores).prefix(3).joined(separator: ", ")
            add("b4", "Caches de \(quais.isEmpty ? "apps" : quais)",
                "Fecha os apps antes, senão o cache volta na hora. Login, abas e configurações ficam intactos.",
                linhas.joined(separator: "\n"), .zero, p.tamanho("appcaches"))
        }

        add("b5", "Sistema, logs e Lixeira",
            "Pede senha de administrador. Reinicie o Mac em algum momento depois — parte disso é temporário de app em execução.",
            """
            sudo rm -rf /Library/Caches/*
            sudo rm -rf /private/var/log/*.gz
            sudo rm -rf /private/var/folders/*/*/C/*
            rm -rf ~/Library/Logs/*
            rm -rf ~/.Trash/*
            sudo periodic daily weekly monthly
            df -h /System/Volumes/Data | tail -1
            """,
            .zero, p.tamanho("sistema"), sudo: true)

        if let raiz = p.pastaProjetos, p.tamanho("projetos") > 0 {
            let caminho = raiz.path.replacingOccurrences(
                of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
            add("b6", "Dependências dos projetos em \(caminho)",
                "Achei node_modules e Pods nessa pasta. Volta com npm install ou pod install quando você retomar cada projeto. O código não é tocado.",
                """
                rm -rf \(caminho)/*/node_modules
                rm -rf \(caminho)/*/*/node_modules
                rm -rf \(caminho)/*/ios/Pods
                rm -rf \(caminho)/*/.next
                rm -rf \(caminho)/*/.expo
                df -h /System/Volumes/Data | tail -1
                """,
                .medio, p.tamanho("projetos"))
        }

        if p.temXcode, p.tamanho("archives") > 0 {
            add("b7", "Archives do Xcode",
                "São os dSYMs dos builds que você publicou. Sem eles, um crash report de versão já na loja não é mais simbolizado. Só rode se topar perder isso.",
                "rm -rf ~/Library/Developer/Xcode/Archives/*\ndf -h /System/Volumes/Data | tail -1",
                .alto, p.tamanho("archives"))
        }

        if !p.instaladoresMacOS.isEmpty {
            let nomes = p.instaladoresMacOS.map { $0.deletingPathExtension().lastPathComponent }
            add("b8", "Instalador do macOS encostado",
                "Encontrei \(nomes.joined(separator: ", ")) em /Applications. Depois que o sistema já foi instalado, esse app não serve pra mais nada. Confira sua versão com o sw_vers antes.",
                "sw_vers\nsudo rm -rf /Applications/Install\\ macOS\\ *.app\ndf -h /System/Volumes/Data | tail -1",
                .medio, p.tamanho("instalador"), sudo: true)
        }

        if !p.jogos.isEmpty, p.tamanho("jogos") > 0 {
            add("b9", "Dados de \(p.jogos.joined(separator: " e "))",
                "Mundos salvos, mods e recursos baixados vão junto. Só rode se você não joga mais.",
                """
                rm -rf ~/Library/Application\\ Support/minecraft
                rm -rf ~/Library/Application\\ Support/ModrinthApp
                rm -rf ~/Library/Caches/ModrinthApp
                df -h /System/Volumes/Data | tail -1
                """,
                .alto, p.tamanho("jogos"))
        }

        add("b99", "Caçar o que sobrou",
            "Não apaga nada. É o comando pra rodar quando o disco encher e você não souber por quê — mostra o peso fora da sua pasta pessoal, que nenhuma limpeza de usuário alcança.",
            """
            echo "=== FORA DA HOME ==="
            sudo du -sh -x /Applications /Library /usr/local /opt /private/var 2>/dev/null | sort -rh
            echo
            echo "=== APPS MAIORES ==="
            du -sh /Applications/* 2>/dev/null | sort -rh | head -20
            echo
            echo "=== ESPACO PURGAVEL ==="
            diskutil info /System/Volumes/Data | grep -i -E "free|purge|used"
            """,
            .zero, 0, sudo: true, lista: true)

        return blocos
    }
}
