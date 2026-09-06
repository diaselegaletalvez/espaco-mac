import Foundation

struct Achadura: Identifiable, Sendable {
    let id: String
    let titulo: String
    let estado: String
    let gravidade: Gravidade
    let porqueImporta: String
    let detalhes: [String]
    let comoResolver: String?
}

struct RaioX: Sendable {
    var achados: [Achadura] = []
    var feitoEm: Date?

    var criticos: [Achadura] { achados.filter { $0.gravidade == .alerta } }
    var avisos: [Achadura] { achados.filter { $0.gravidade == .atencao } }
    var limpos: [Achadura] { achados.filter { $0.gravidade == .ok } }

    var nota: Int {
        guard !achados.isEmpty else { return 100 }
        let perda = criticos.count * 22 + avisos.count * 8
        return max(0, 100 - perda)
    }
}

enum SecurityDeep {

    static func sh(_ caminho: String, _ args: [String]) -> String {
        Security.shell(caminho, args)
    }

    static func certificadosRaiz() -> Achadura {
        let saida = sh("/usr/bin/security", ["dump-trust-settings", "-d"])
        let nenhum = saida.contains("No Trust Settings") || saida.isEmpty

        var nomes: [String] = []
        for linha in saida.components(separatedBy: .newlines) {
            let l = linha.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("Cert ") , let faixa = l.range(of: ": ") {
                nomes.append(String(l[faixa.upperBound...]))
            }
        }

        return Achadura(
            id: "certs",
            titulo: "Certificados raiz personalizados",
            estado: nenhum ? "Nenhum" : "\(max(nomes.count, 1)) instalado(s)",
            gravidade: nenhum ? .ok : .alerta,
            porqueImporta: "Um certificado raiz confiável permite que quem o instalou leia todo o seu tráfego HTTPS — senhas, mensagens, banco — sem que o navegador reclame. É a checagem mais séria desta lista.",
            detalhes: nomes,
            comoResolver: nenhum ? nil : "Abra o Acesso às Chaves, vá em Sistema → Certificados e remova o que você não reconhecer. Se foi a TI da sua escola ou empresa que instalou, é esperado."
        )
    }

    static func compartilhamento() -> Achadura {
        let portas = sh("/usr/sbin/netstat", ["-an", "-p", "tcp"])

        let servicos: [(String, String, String)] = [
            ("22", "SSH", "Acesso Remoto por terminal"),
            ("5900", "VNC", "Compartilhamento de Tela"),
            ("445", "SMB", "Compartilhamento de Arquivos"),
            ("548", "AFP", "Compartilhamento de Arquivos antigo"),
            ("3283", "ARD", "Gerenciamento Remoto")
        ]

        var ligados: [String] = []
        for linha in portas.components(separatedBy: .newlines) where linha.contains("LISTEN") {
            for (porta, sigla, nome) in servicos {
                if linha.contains("*.\(porta) ") || linha.contains(".\(porta) ") {
                    let texto = "\(nome) (\(sigla), porta \(porta))"
                    if !ligados.contains(texto) { ligados.append(texto) }
                }
            }
        }

        return Achadura(
            id: "compartilhamento",
            titulo: "Compartilhamento e acesso remoto",
            estado: ligados.isEmpty ? "Tudo desligado" : "\(ligados.count) ligado(s)",
            gravidade: ligados.isEmpty ? .ok : .atencao,
            porqueImporta: "Serviço de compartilhamento ligado é uma porta aberta pra rede. Em Wi-Fi de café ou faculdade, qualquer um na mesma rede pode tentar entrar.",
            detalhes: ligados,
            comoResolver: ligados.isEmpty ? nil : "Ajustes → Geral → Compartilhamento. Desligue o que você não usa hoje."
        )
    }

    static func acessibilidade() -> Achadura {
        let db = "/Library/Application Support/com.apple.TCC/TCC.db"
        let consulta = "SELECT client FROM access WHERE service='kTCCServiceAccessibility' AND auth_value=2;"
        let saida = sh("/usr/bin/sqlite3", [db, consulta])

        if saida.isEmpty || saida.lowercased().contains("unable to open") ||
           saida.lowercased().contains("authorization denied") {
            return Achadura(
                id: "acessibilidade",
                titulo: "Apps que controlam seu Mac",
                estado: "Não consegui ler",
                gravidade: .atencao,
                porqueImporta: "Acessibilidade é a permissão mais poderosa do macOS: quem tem ela lê tudo que aparece na sua tela e digita no seu lugar.",
                detalhes: [],
                comoResolver: "Dê Acesso Total ao Disco ao Espaço em Ajustes → Privacidade e Segurança, ou confira você mesmo em Privacidade e Segurança → Acessibilidade."
            )
        }

        let apps = saida.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { id -> String in
                id.components(separatedBy: ".").last.map { $0.capitalized } ?? id
            }

        return Achadura(
            id: "acessibilidade",
            titulo: "Apps que controlam seu Mac",
            estado: apps.isEmpty ? "Nenhum" : "\(apps.count) com permissão",
            gravidade: apps.isEmpty ? .ok : (apps.count > 4 ? .atencao : .ok),
            porqueImporta: "Acessibilidade é a permissão mais poderosa do macOS: quem tem ela lê tudo que aparece na sua tela e digita no seu lugar. Automatizadores e gravadores de tela precisam dela legitimamente — o problema é o que você não reconhece.",
            detalhes: apps,
            comoResolver: apps.isEmpty ? nil : "Ajustes → Privacidade e Segurança → Acessibilidade. Tire o que você não usa mais."
        )
    }

    static func dnsEProxy() -> Achadura {
        let dns = sh("/usr/sbin/scutil", ["--dns"])
        let proxy = sh("/usr/sbin/scutil", ["--proxy"])

        var servidores: [String] = []
        for linha in dns.components(separatedBy: .newlines) {
            let l = linha.trimmingCharacters(in: .whitespaces)
            guard l.hasPrefix("nameserver[") , let faixa = l.range(of: ": ") else { continue }
            let ip = String(l[faixa.upperBound...])
            if !servidores.contains(ip) { servidores.append(ip) }
        }

        let conhecidos = ["1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4",
                          "9.9.9.9", "149.112.112.112", "208.67.222.222", "208.67.220.220"]

        let suspeitos = servidores.filter { ip in
            !conhecidos.contains(ip) &&
            !ip.hasPrefix("192.168.") && !ip.hasPrefix("10.") &&
            !ip.hasPrefix("172.") && !ip.hasPrefix("fe80") && ip != "::1" && ip != "127.0.0.1"
        }

        let proxyLigado = proxy.contains("HTTPEnable : 1") || proxy.contains("HTTPSEnable : 1")
                       || proxy.contains("ProxyAutoConfigEnable : 1")

        var detalhes = servidores.map { "DNS \($0)" }
        if proxyLigado { detalhes.append("Proxy HTTP configurado") }

        let hosts = (try? String(contentsOfFile: "/etc/hosts", encoding: .utf8)) ?? ""
        let linhasHosts = hosts.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .filter { !$0.contains("localhost") && !$0.contains("broadcasthost") && !$0.hasPrefix("::1") }

        if !linhasHosts.isEmpty {
            detalhes.append("\(linhasHosts.count) redirecionamento(s) no arquivo hosts")
        }

        let problema = !suspeitos.isEmpty || proxyLigado || linhasHosts.count > 5

        return Achadura(
            id: "rede",
            titulo: "DNS, proxy e redirecionamentos",
            estado: problema ? "Configuração incomum" : "Normal",
            gravidade: problema ? .atencao : .ok,
            porqueImporta: "Trocar seu DNS ou proxy é o jeito mais silencioso de mandar você pra sites falsos sem mudar nada no navegador. O arquivo hosts faz o mesmo, arquivo por arquivo.",
            detalhes: detalhes,
            comoResolver: problema ? "Ajustes → Rede → detalhes da sua conexão → DNS e Proxies. Se você não configurou nada disso, volte pro automático." : nil
        )
    }

    static func xprotect() -> Achadura {
        let caminhos = [
            "/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist",
            "/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist"
        ]

        var versao = "?"
        var atualizado: Date?

        for c in caminhos where FileManager.default.fileExists(atPath: c) {
            versao = sh("/usr/bin/defaults", ["read", c.replacingOccurrences(of: ".plist", with: ""),
                                              "CFBundleShortVersionString"])
            if let attrs = try? FileManager.default.attributesOfItem(atPath: c) {
                atualizado = attrs[.modificationDate] as? Date
            }
            break
        }

        let dias = atualizado.map {
            Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 999
        } ?? 999

        var detalhes: [String] = []
        if versao != "?" && !versao.isEmpty { detalhes.append("Versão das definições: \(versao)") }
        if let a = atualizado {
            detalhes.append("Atualizadas em \(a.formatted(date: .abbreviated, time: .omitted)) · há \(dias) dias")
        }

        return Achadura(
            id: "xprotect",
            titulo: "Antimalware da Apple (XProtect)",
            estado: dias <= 30 ? "Em dia" : (dias <= 90 ? "Atrasado" : "Muito atrasado"),
            gravidade: dias <= 30 ? .ok : (dias <= 90 ? .atencao : .alerta),
            porqueImporta: "O macOS já tem antimalware embutido e a Apple atualiza as definições sozinha, em silêncio. Se elas estão paradas há meses, alguma coisa está bloqueando as atualizações — e aí você está desprotegido contra o que apareceu depois.",
            detalhes: detalhes,
            comoResolver: dias <= 30 ? nil : "Ajustes → Geral → Atualização de Software. Garanta que atualizações automáticas de segurança estejam ligadas."
        )
    }

    static func administradores() -> Achadura {
        let grupo = sh("/usr/bin/dscl", [".", "-read", "/Groups/admin", "GroupMembership"])
        let usuarioAtual = NSUserName()

        var admins = grupo
            .replacingOccurrences(of: "GroupMembership:", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0 != "root" }

        let ocultos = sh("/usr/bin/dscl", [".", "-list", "/Users"])
            .components(separatedBy: .newlines)
            .filter { $0.hasPrefix("_") == false && $0.hasPrefix("daemon") == false
                      && !$0.isEmpty && $0 != "root" && $0 != "nobody" }

        admins = admins.filter { ocultos.contains($0) || $0 == usuarioAtual }

        let outros = admins.filter { $0 != usuarioAtual }

        return Achadura(
            id: "admins",
            titulo: "Contas de administrador",
            estado: outros.isEmpty ? "Só você" : "\(admins.count) contas",
            gravidade: outros.isEmpty ? .ok : .atencao,
            porqueImporta: "Toda conta de administrador pode instalar qualquer coisa no seu Mac. Uma conta que você não criou é acesso permanente pra outra pessoa.",
            detalhes: admins.map { $0 == usuarioAtual ? "\($0) (você)" : $0 },
            comoResolver: outros.isEmpty ? nil : "Ajustes → Usuários e Grupos. Se não reconhecer alguma, remova ou tire o privilégio de administrador."
        )
    }

    static func raioX() -> RaioX {
        var r = RaioX()
        r.achados = [
            certificadosRaiz(),
            compartilhamento(),
            acessibilidade(),
            dnsEProxy(),
            xprotect(),
            administradores()
        ].sorted { $0.gravidade > $1.gravidade }
        r.feitoEm = Date()
        return r
    }
}
