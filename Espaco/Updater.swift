import Foundation
import AppKit
import Observation

struct VersaoDisponivel: Sendable {
    let tag: String
    let versao: String
    let notas: String
    let url: URL
    let tamanho: Int64
    let publicadaEm: Date?

    var descricaoTamanho: String { Fmt.bytes(tamanho) }
}

enum EstadoUpdate: Equatable, Sendable {
    case ocioso
    case checando
    case atualizado
    case disponivel(String)
    case baixando(Double)
    case instalando
    case pronto
    case erro(String)
}

@MainActor
@Observable
final class Updater {
    static let shared = Updater()

    private let repo = "diaselegaletalvez/espaco"
    private let chaveAuto = "espaco.autoUpdate"
    private let chaveUltima = "espaco.ultimaChecagem"

    var estado: EstadoUpdate = .ocioso
    var disponivel: VersaoDisponivel?

    var checarAutomaticamente: Bool {
        didSet { UserDefaults.standard.set(checarAutomaticamente, forKey: chaveAuto) }
    }

    var versaoAtual: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private init() {
        checarAutomaticamente = UserDefaults.standard.object(forKey: chaveAuto) as? Bool ?? true
    }

    static func compara(_ a: String, _ b: String) -> ComparisonResult {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    func checarSePassouODia() async {
        guard checarAutomaticamente else { return }
        let ultima = UserDefaults.standard.double(forKey: chaveUltima)
        let agora = Date().timeIntervalSince1970
        guard agora - ultima > 86400 else { return }
        UserDefaults.standard.set(agora, forKey: chaveUltima)
        await checar(silencioso: true)
    }

    func checar(silencioso: Bool = false) async {
        if !silencioso { estado = .checando }

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            estado = .erro("endereço inválido")
            return
        }

        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15

        do {
            let (dados, resposta) = try await URLSession.shared.data(for: req)
            guard let http = resposta as? HTTPURLResponse, http.statusCode == 200 else {
                if !silencioso { estado = .erro("o GitHub não respondeu") }
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: dados) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                if !silencioso { estado = .erro("resposta inesperada") }
                return
            }

            let versao = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let notas = json["body"] as? String ?? ""

            var quando: Date?
            if let iso = json["published_at"] as? String {
                quando = ISO8601DateFormatter().date(from: iso)
            }

            let assets = json["assets"] as? [[String: Any]] ?? []
            guard let dmg = assets.first(where: {
                ($0["name"] as? String)?.lowercased().hasSuffix(".dmg") == true
            }),
                  let link = dmg["browser_download_url"] as? String,
                  let baixar = URL(string: link) else {
                if !silencioso { estado = .erro("o release não tem .dmg") }
                return
            }

            let tamanho = Int64(dmg["size"] as? Int ?? 0)

            if Updater.compara(versaoAtual, versao) == .orderedAscending {
                let v = VersaoDisponivel(tag: tag, versao: versao, notas: notas,
                                         url: baixar, tamanho: tamanho, publicadaEm: quando)
                disponivel = v
                estado = .disponivel(versao)
                if silencioso {
                    Notifier.avisar("Espaço \(versao) disponível",
                                    "Você está na \(versaoAtual). Abra o app pra atualizar.")
                }
            } else {
                disponivel = nil
                estado = .atualizado
            }
        } catch {
            if !silencioso { estado = .erro("sem conexão") }
        }
    }

    func baixarEInstalar() async {
        guard let v = disponivel else { return }
        estado = .baixando(0)

        do {
            let (arquivo, _) = try await URLSession.shared.download(from: v.url)
            let destino = FileManager.default.temporaryDirectory
                .appending(path: "Espaco-\(v.versao).dmg")
            try? FileManager.default.removeItem(at: destino)
            try FileManager.default.moveItem(at: arquivo, to: destino)

            estado = .instalando
            try await instalar(dmg: destino, versao: v.versao)
            estado = .pronto
        } catch {
            estado = .erro(error.localizedDescription)
        }
    }

    private func instalar(dmg: URL, versao: String) async throws {
        let montagem = try rodar("/usr/bin/hdiutil",
                                 ["attach", dmg.path, "-nobrowse", "-noverify", "-noautoopen"])

        guard let linha = montagem.components(separatedBy: .newlines)
                .last(where: { $0.contains("/Volumes/") }),
              let faixa = linha.range(of: "/Volumes/") else {
            throw NSError(domain: "Espaco", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "não consegui montar o .dmg"])
        }

        let volume = String(linha[faixa.lowerBound...]).trimmingCharacters(in: .whitespaces)
        defer { _ = try? rodar("/usr/bin/hdiutil", ["detach", volume, "-quiet"]) }

        let fm = FileManager.default
        guard let itens = try? fm.contentsOfDirectory(atPath: volume),
              let nomeApp = itens.first(where: { $0.hasSuffix(".app") }) else {
            throw NSError(domain: "Espaco", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "não achei o app dentro do .dmg"])
        }

        let novo = URL(fileURLWithPath: volume).appending(path: nomeApp)

        guard Security.assinaturaValida(novo),
              let assinante = Security.quemAssinou(novo) else {
            throw NSError(domain: "Espaco", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "a assinatura do download não confere — atualização cancelada"])
        }

        let assinanteAtual = Security.quemAssinou(Bundle.main.bundleURL)
        if let atual = assinanteAtual, atual != assinante {
            throw NSError(domain: "Espaco", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "o download foi assinado por outro desenvolvedor — atualização cancelada"])
        }

        let atual = Bundle.main.bundleURL
        let backup = fm.temporaryDirectory.appending(path: "Espaco-anterior-\(UUID().uuidString).app")

        try fm.moveItem(at: atual, to: backup)
        do {
            try fm.copyItem(at: novo, to: atual)
        } catch {
            try? fm.moveItem(at: backup, to: atual)
            throw error
        }
        try? fm.removeItem(at: backup)

        reiniciar(em: atual)
    }

    private func reiniciar(em url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                NSApplication.shared.terminate(nil)
            }
        }
    }

    @discardableResult
    private func rodar(_ caminho: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: caminho)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        try p.run()
        let d = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        p.waitUntilExit()
        return String(data: d, encoding: .utf8) ?? ""
    }
}
