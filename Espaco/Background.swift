import Foundation
import ServiceManagement
import Observation

struct MudancaDetectada: Identifiable, Sendable {
    let id = UUID()
    let pasta: String
    let quando: Date
    let descricao: String
}

@MainActor
@Observable
final class Vigia {
    static let shared = Vigia()

    var abrirNoLogin: Bool {
        didSet { aplicarLogin() }
    }

    var vigilanciaLigada: Bool {
        didSet {
            UserDefaults.standard.set(vigilanciaLigada, forKey: "espaco.vigilancia")
            if vigilanciaLigada { comecar() } else { parar() }
        }
    }

    var mudancas: [MudancaDetectada] = []
    var ultimaMedicao: Date?

    private var fontes: [DispatchSourceFileSystemObject] = []
    private var timer: Timer?
    private var inventario: [String: Set<String>] = [:]

    private weak var app: AppState?

    private let pastasVigiadas: [(String, String)] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            ("\(home)/Library/LaunchAgents", "Inicialização do usuário"),
            ("/Library/LaunchAgents", "Inicialização de todos"),
            ("/Library/LaunchDaemons", "Serviços do sistema"),
            ("/Applications", "Aplicativos")
        ]
    }()

    private init() {
        abrirNoLogin = SMAppService.mainApp.status == .enabled
        vigilanciaLigada = UserDefaults.standard.object(forKey: "espaco.vigilancia") as? Bool ?? true
    }

    func ligar(_ estado: AppState) {
        app = estado
        fotografar()
        if vigilanciaLigada { comecar() }
    }

    private func aplicarLogin() {
        do {
            if abrirNoLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            abrirNoLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func conteudo(_ caminho: String) -> Set<String> {
        let itens = (try? FileManager.default.contentsOfDirectory(atPath: caminho)) ?? []
        return Set(itens.filter { !$0.hasPrefix(".") })
    }

    private func fotografar() {
        for (caminho, _) in pastasVigiadas {
            inventario[caminho] = conteudo(caminho)
        }
    }

    private func comecar() {
        parar()

        for (caminho, rotulo) in pastasVigiadas {
            let fd = open(caminho, O_EVTONLY)
            guard fd >= 0 else { continue }

            let fonte = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .extend, .rename],
                queue: DispatchQueue.global(qos: .utility))

            fonte.setEventHandler { [weak self] in
                Task { @MainActor in
                    self?.avaliar(caminho, rotulo)
                }
            }
            fonte.setCancelHandler { close(fd) }
            fonte.resume()
            fontes.append(fonte)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.medir()
            }
        }
    }

    private func parar() {
        fontes.forEach { $0.cancel() }
        fontes.removeAll()
        timer?.invalidate()
        timer = nil
    }

    private func avaliar(_ caminho: String, _ rotulo: String) {
        let agora = conteudo(caminho)
        let antes = inventario[caminho] ?? agora
        inventario[caminho] = agora

        let novos = agora.subtracting(antes)
        let sumiram = antes.subtracting(agora)

        for item in novos {
            let limpo = item.replacingOccurrences(of: ".plist", with: "")
                            .replacingOccurrences(of: ".app", with: "")
            registrar(pasta: rotulo, descricao: "\(limpo) apareceu")

            if caminho.contains("Launch") {
                Notifier.avisar("Item de inicialização novo",
                                "\(limpo) foi adicionado em \(rotulo). Se você não instalou nada agora, confira na aba Proteção.")
            }
        }

        for item in sumiram {
            let limpo = item.replacingOccurrences(of: ".plist", with: "")
                            .replacingOccurrences(of: ".app", with: "")
            registrar(pasta: rotulo, descricao: "\(limpo) foi removido")
        }

        if !novos.isEmpty, caminho.contains("Launch") {
            Task { await app?.analisarSeguranca() }
        }
    }

    private func registrar(pasta: String, descricao: String) {
        mudancas.insert(MudancaDetectada(pasta: pasta, quando: Date(), descricao: descricao), at: 0)
        if mudancas.count > 40 { mudancas.removeLast(mudancas.count - 40) }
    }

    private func medir() async {
        guard let app else { return }
        app.refreshDiskOnly()
        ultimaMedicao = Date()

        if app.disk.isTight {
            let chave = "espaco.avisoDisco"
            let ultimo = UserDefaults.standard.double(forKey: chave)
            let agora = Date().timeIntervalSince1970
            if agora - ultimo > 21600 {
                UserDefaults.standard.set(agora, forKey: chave)
                Notifier.avisar("Disco quase cheio",
                                "\(Fmt.pct(app.disk.usedFraction)) usado, só \(Fmt.bytes(app.disk.available)) livres. Abra o Espaço pra liberar.")
            }
        }
    }

    func limparHistorico() { mudancas.removeAll() }
}
