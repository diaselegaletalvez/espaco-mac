import Foundation
import AppKit

enum Gravidade: Int, Sendable, Comparable {
    case ok = 0, atencao = 1, alerta = 2

    static func < (a: Gravidade, b: Gravidade) -> Bool { a.rawValue < b.rawValue }

    var rotulo: String {
        switch self {
        case .ok: return "ok"
        case .atencao: return "atenção"
        case .alerta: return "alerta"
        }
    }
}

struct Defesa: Identifiable, Sendable {
    let id: String
    let nome: String
    let estado: String
    let ligada: Bool
    let explicacao: String
    let comoArrumar: String?
}

struct ItemInicializacao: Identifiable, Sendable {
    let id: String
    let nome: String
    let caminho: URL
    let programa: String
    let assinadoPor: String?
    let escopo: String
    let gravidade: Gravidade

    var confiavel: Bool { assinadoPor != nil }
}

struct AppSuspeito: Identifiable, Sendable {
    let id: String
    let nome: String
    let caminho: URL
    let motivo: String
    let gravidade: Gravidade
}

struct PerfilConfig: Identifiable, Sendable {
    let id: String
    let nome: String
    let caminho: URL
}

struct Travamento: Identifiable, Sendable {
    let id: String
    let app: String
    let quando: Date
    let vezes: Int

    var descricaoQuando: String {
        let dias = Calendar.current.dateComponents([.day], from: quando, to: Date()).day ?? 0
        if dias == 0 { return "hoje" }
        if dias == 1 { return "ontem" }
        if dias < 30 { return "há \(dias) dias" }
        return "há mais de um mês"
    }
}

struct RelatorioSeguranca: Sendable {
    var defesas: [Defesa] = []
    var inicializacao: [ItemInicializacao] = []
    var appsSuspeitos: [AppSuspeito] = []
    var perfis: [PerfilConfig] = []
    var travamentos: [Travamento] = []
    var analisadoEm: Date?

    var defesasDesligadas: [Defesa] { defesas.filter { !$0.ligada } }
    var inicializacaoDuvidosa: [ItemInicializacao] { inicializacao.filter { !$0.confiavel } }

    var gravidadeGeral: Gravidade {
        var g = Gravidade.ok
        if !defesasDesligadas.isEmpty { g = max(g, .atencao) }
        if !inicializacaoDuvidosa.isEmpty { g = max(g, .alerta) }
        if appsSuspeitos.contains(where: { $0.gravidade == .alerta }) { g = max(g, .alerta) }
        if !perfis.isEmpty { g = max(g, .atencao) }
        return g
    }

    var resumo: String {
        switch gravidadeGeral {
        case .ok:
            return "Nada fora do lugar. As defesas do sistema estão ligadas e tudo que roda no boot é assinado."
        case .atencao:
            var partes: [String] = []
            if !defesasDesligadas.isEmpty {
                partes.append("\(defesasDesligadas.count) defesa\(defesasDesligadas.count == 1 ? "" : "s") do sistema desligada\(defesasDesligadas.count == 1 ? "" : "s")")
            }
            if !perfis.isEmpty { partes.append("\(perfis.count) perfil de configuração instalado") }
            return "Vale olhar: " + partes.joined(separator: " e ") + "."
        case .alerta:
            return "Tem coisa rodando no seu Mac sem assinatura válida. Não é prova de malware, mas é exatamente onde ele se esconde."
        }
    }
}

enum Security {

    static func shell(_ caminho: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: caminho)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        guard (try? p.run()) != nil else { return "" }
        let d = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        p.waitUntilExit()
        return String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func quemAssinou(_ url: URL) -> String? {
        let saida = shell("/usr/bin/codesign", ["-dv", "--verbose=2", url.path])
        guard saida.contains("Authority=") else { return nil }
        for linha in saida.components(separatedBy: .newlines) where linha.hasPrefix("Authority=") {
            let autoridade = String(linha.dropFirst("Authority=".count))
            if autoridade.contains("Apple") { return "Apple" }
            if let inicio = autoridade.range(of: ": "),
               let fim = autoridade.range(of: " (", options: .backwards) {
                return String(autoridade[inicio.upperBound..<fim.lowerBound])
            }
            return autoridade
        }
        return nil
    }

    static func assinaturaValida(_ url: URL) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        p.arguments = ["--verify", "--strict", url.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    static func defesas() -> [Defesa] {
        var out: [Defesa] = []

        let sip = shell("/usr/bin/csrutil", ["status"])
        let sipLigado = sip.lowercased().contains("enabled") && !sip.lowercased().contains("disabled")
        out.append(Defesa(id: "sip",
                          nome: "Proteção de Integridade do Sistema",
                          estado: sipLigado ? "Ligada" : "Desligada",
                          ligada: sipLigado,
                          explicacao: "Impede que qualquer programa, inclusive com senha de administrador, altere arquivos do sistema.",
                          comoArrumar: sipLigado ? nil : "Reinicie em Recuperação (segure o botão de ligar) e rode csrutil enable no Terminal."))

        let gk = shell("/usr/sbin/spctl", ["--status"])
        let gkLigado = gk.lowercased().contains("assessments enabled")
        out.append(Defesa(id: "gatekeeper",
                          nome: "Gatekeeper",
                          estado: gkLigado ? "Ligado" : "Desligado",
                          ligada: gkLigado,
                          explicacao: "Verifica se um app foi assinado e notarizado antes de deixar você abrir pela primeira vez.",
                          comoArrumar: gkLigado ? nil : "Rode sudo spctl --master-enable no Terminal."))

        let fv = shell("/usr/bin/fdesetup", ["status"])
        let fvLigado = fv.lowercased().contains("filevault is on")
        out.append(Defesa(id: "filevault",
                          nome: "FileVault",
                          estado: fvLigado ? "Ligado" : "Desligado",
                          ligada: fvLigado,
                          explicacao: "Criptografa o disco inteiro. Sem ele, quem tiver o Mac na mão lê seus arquivos.",
                          comoArrumar: fvLigado ? nil : "Ajustes → Privacidade e Segurança → FileVault → Ativar."))

        let alf = shell("/usr/bin/defaults", ["read", "/Library/Preferences/com.apple.alf", "globalstate"])
        let fwLigado = alf == "1" || alf == "2"
        out.append(Defesa(id: "firewall",
                          nome: "Firewall",
                          estado: fwLigado ? "Ligado" : "Desligado",
                          ligada: fwLigado,
                          explicacao: "Bloqueia conexões de entrada que você não pediu.",
                          comoArrumar: fwLigado ? nil : "Ajustes → Rede → Firewall → Ativar."))

        return out
    }

    static func inicializacao() -> [ItemInicializacao] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let pastas: [(URL, String)] = [
            (home.appending(path: "Library/LaunchAgents"), "Só pra você"),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), "Todos os usuários"),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), "Sistema, roda antes do login")
        ]

        var out: [ItemInicializacao] = []

        for (pasta, escopo) in pastas {
            guard let itens = try? fm.contentsOfDirectory(at: pasta,
                                                          includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles]) else { continue }
            for plist in itens where plist.pathExtension == "plist" {
                guard let dados = try? Data(contentsOf: plist),
                      let raiz = try? PropertyListSerialization.propertyList(from: dados, format: nil)
                        as? [String: Any] else { continue }

                let rotulo = raiz["Label"] as? String ?? plist.deletingPathExtension().lastPathComponent

                var programa = ""
                if let p = raiz["Program"] as? String {
                    programa = p
                } else if let args = raiz["ProgramArguments"] as? [String], let primeiro = args.first {
                    programa = primeiro
                }

                let daApple = rotulo.hasPrefix("com.apple.")
                var assinante: String?
                if !programa.isEmpty, fm.fileExists(atPath: programa) {
                    assinante = quemAssinou(URL(fileURLWithPath: programa))
                } else if daApple {
                    assinante = "Apple"
                }

                let g: Gravidade = daApple ? .ok
                    : (assinante == nil ? .alerta : .ok)

                out.append(ItemInicializacao(id: plist.path,
                                             nome: rotulo,
                                             caminho: plist,
                                             programa: programa.isEmpty ? "—" : programa,
                                             assinadoPor: assinante,
                                             escopo: escopo,
                                             gravidade: g))
            }
        }

        return out.sorted { ($0.gravidade, $0.nome) > ($1.gravidade, $1.nome) }
    }

    static func appsSuspeitos() -> [AppSuspeito] {
        let fm = FileManager.default
        var out: [AppSuspeito] = []

        for pasta in [URL(fileURLWithPath: "/Applications"),
                      fm.homeDirectoryForCurrentUser.appending(path: "Applications")] {
            guard let itens = try? fm.contentsOfDirectory(at: pasta,
                                                          includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles]) else { continue }
            for app in itens where app.pathExtension == "app" {
                let nome = app.deletingPathExtension().lastPathComponent
                let assinante = quemAssinou(app)

                if assinante == nil {
                    out.append(AppSuspeito(id: app.path, nome: nome, caminho: app,
                                           motivo: "Sem assinatura de desenvolvedor",
                                           gravidade: .alerta))
                } else if !assinaturaValida(app) {
                    out.append(AppSuspeito(id: app.path, nome: nome, caminho: app,
                                           motivo: "Assinatura quebrada — o app foi alterado depois de assinado",
                                           gravidade: .alerta))
                }
            }
        }
        return out
    }

    static func perfis() -> [PerfilConfig] {
        let fm = FileManager.default
        var out: [PerfilConfig] = []
        for pasta in ["/Library/Managed Preferences", "/Library/ConfigurationProfiles/Settings"] {
            let u = URL(fileURLWithPath: pasta)
            guard let itens = try? fm.contentsOfDirectory(at: u,
                                                          includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles]) else { continue }
            for item in itens where item.pathExtension == "plist" || item.hasDirectoryPath {
                out.append(PerfilConfig(id: item.path,
                                        nome: item.deletingPathExtension().lastPathComponent,
                                        caminho: item))
            }
        }
        return out
    }

    static func travamentos() -> [Travamento] {
        let fm = FileManager.default
        let pasta = fm.homeDirectoryForCurrentUser
            .appending(path: "Library/Logs/DiagnosticReports")

        guard let itens = try? fm.contentsOfDirectory(at: pasta,
                                                      includingPropertiesForKeys: [.contentModificationDateKey],
                                                      options: [.skipsHiddenFiles]) else { return [] }

        let corte = Date().addingTimeInterval(-30 * 86400)
        var porApp: [String: (Date, Int)] = [:]

        for arquivo in itens {
            let ext = arquivo.pathExtension.lowercased()
            guard ext == "ips" || ext == "crash" || ext == "hang" else { continue }
            guard let d = (try? arquivo.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate, d > corte else { continue }

            let nome = arquivo.deletingPathExtension().lastPathComponent
                .components(separatedBy: "-").first ?? "desconhecido"

            if let atual = porApp[nome] {
                porApp[nome] = (max(atual.0, d), atual.1 + 1)
            } else {
                porApp[nome] = (d, 1)
            }
        }

        return porApp
            .map { Travamento(id: $0.key, app: $0.key, quando: $0.value.0, vezes: $0.value.1) }
            .sorted { $0.vezes > $1.vezes }
    }

    static func analisar() -> RelatorioSeguranca {
        var r = RelatorioSeguranca()
        r.defesas = defesas()
        r.inicializacao = inicializacao()
        r.appsSuspeitos = appsSuspeitos()
        r.perfis = perfis()
        r.travamentos = travamentos()
        r.analisadoEm = Date()
        return r
    }
}
