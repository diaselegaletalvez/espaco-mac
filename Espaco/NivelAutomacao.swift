import Foundation
import Observation

enum NivelLimpeza: String, CaseIterable, Identifiable, Sendable {
    case zero, medio

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .zero:  return "Só risco zero"
        case .medio: return "Risco zero e médio"
        }
    }

    var resumo: String {
        switch self {
        case .zero:
            return "Caches, DerivedData e símbolos de debug. Tudo se regenera sozinho — o espaço volta na hora e você não perde nada."
        case .medio:
            return "Além dos caches, manda pra Lixeira as dependências de projetos parados. Voltam com um npm install, e nada some de vez até você esvaziar a Lixeira."
        }
    }

    var riscosIncluidos: [Risk] {
        switch self {
        case .zero:  return [.zero]
        case .medio: return [.zero, .medio]
        }
    }
}

@MainActor
@Observable
final class Config {
    static let shared = Config()

    private let chaveNivel = "espaco.nivelAutomacao"
    private let chaveDias = "espaco.diasDormente"

    var nivel: NivelLimpeza {
        didSet {
            UserDefaults.standard.set(nivel.rawValue, forKey: chaveNivel)
            escreverParaScript()
        }
    }

    var diasParaDormente: Int {
        didSet {
            UserDefaults.standard.set(diasParaDormente, forKey: chaveDias)
            escreverParaScript()
        }
    }

    private init() {
        let salvo = UserDefaults.standard.string(forKey: chaveNivel) ?? NivelLimpeza.zero.rawValue
        nivel = NivelLimpeza(rawValue: salvo) ?? .zero
        let dias = UserDefaults.standard.integer(forKey: chaveDias)
        diasParaDormente = dias > 0 ? dias : 60
        escreverParaScript()
    }

    var pastaConfig: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".espaco")
    }

    func escreverParaScript() {
        let fm = FileManager.default
        try? fm.createDirectory(at: pastaConfig, withIntermediateDirectories: true)
        let conteudo = "nivel=\(nivel.rawValue)\ndias_dormente=\(diasParaDormente)\n"
        try? conteudo.write(to: pastaConfig.appending(path: "config"),
                            atomically: true, encoding: .utf8)
    }
}

extension AppState {
    var alvosDoNivel: [Target] {
        let riscos = Config.shared.nivel.riscosIncluidos
        return targets.filter { riscos.contains($0.risk) && $0.size > 0 }
    }

    var projetosDormentesDoNivel: [ProjectInfo] {
        guard Config.shared.nivel == .medio else { return [] }
        let dias = Config.shared.diasParaDormente
        return projetos.filter { $0.diasParado >= dias && $0.peso > 50_000_000 }
    }

    func limpezaAutomatica() async {
        guard !cleaning else { return }
        cleaning = true
        var total = CleanResult()

        for t in alvosDoNivel {
            cleaningLabel = t.name
            let r = await Task.detached(priority: .utility) { Cleaner.clean(t) }.value
            total.freed += r.freed
            total.itemsRemoved += r.itemsRemoved
            total.itemsTrashed += r.itemsTrashed
        }

        if Config.shared.nivel == .medio {
            if projetos.isEmpty { await scanProjetos() }
            for p in projetosDormentesDoNivel {
                cleaningLabel = p.nome
                let r = await Task.detached(priority: .utility) { Projects.limpar(p) }.value
                total.freed += r.freed
                total.itemsTrashed += r.itemsTrashed
            }
        }

        cleaningLabel = ""
        lastResult = total
        cleaning = false
        await scan()

        if total.freed > 0 {
            Notifier.avisar("Limpeza automática",
                            "Liberou \(Fmt.bytes(total.freed))"
                            + (total.itemsTrashed > 0 ? " · \(total.itemsTrashed) na Lixeira" : ""))
        }
    }
}
