import Foundation
import Network
import Observation

struct Requisicao {
    let metodo: String
    let caminho: String
    let credencial: String?
    let corpo: [String: Any]
}

@MainActor
@Observable
final class ServidorLocal {
    static let shared = ServidorLocal()

    let porta: NWEndpoint.Port = 8787

    var ligado = false
    var enderecoVisivel: String?
    var ultimaChamada: String?

    private var listener: NWListener?
    private weak var app: AppState?

    private init() {}

    func conectar(_ estado: AppState) { app = estado }

    func ligar() {
        guard listener == nil else { return }

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = false

        guard let l = try? NWListener(using: params, on: porta) else { return }

        l.service = NWListener.Service(name: Host.current().localizedName ?? "Espaço",
                                       type: "_espaco._tcp")

        l.newConnectionHandler = { conexao in
            conexao.start(queue: .global(qos: .userInitiated))
            ServidorLocal.receber(conexao)
        }

        let numeroPorta = porta.rawValue

        l.stateUpdateHandler = { estado in
            Task { @MainActor in
                let servidor = ServidorLocal.shared
                switch estado {
                case .ready:
                    servidor.ligado = true
                    servidor.enderecoVisivel = "\(SystemInfo.ip()):\(numeroPorta)"
                case .failed, .cancelled:
                    servidor.ligado = false
                    servidor.enderecoVisivel = nil
                default:
                    break
                }
            }
        }

        l.start(queue: .global(qos: .userInitiated))
        listener = l
    }

    func desligar() {
        listener?.cancel()
        listener = nil
        ligado = false
        enderecoVisivel = nil
    }

    nonisolated static func receber(_ conexao: NWConnection) {
        conexao.receive(minimumIncompleteLength: 1, maximumLength: 65536) { dados, _, fim, _ in
            guard let dados, !dados.isEmpty,
                  let texto = String(data: dados, encoding: .utf8) else {
                conexao.cancel()
                return
            }

            Task { @MainActor in
                let resposta = await ServidorLocal.shared.processar(texto)
                conexao.send(content: Data(resposta.utf8), completion: .contentProcessed { _ in
                    conexao.cancel()
                })
            }
            _ = fim
        }
    }

    private func responder(_ codigo: Int, _ objeto: [String: Any]) -> String {
        let corpo = (try? JSONSerialization.data(withJSONObject: objeto))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let status = codigo == 200 ? "200 OK" : (codigo == 401 ? "401 Unauthorized" : "400 Bad Request")
        return """
        HTTP/1.1 \(status)\r
        Content-Type: application/json; charset=utf-8\r
        Content-Length: \(corpo.utf8.count)\r
        Connection: close\r
        \r
        \(corpo)
        """
    }

    private func interpretar(_ bruto: String) -> Requisicao? {
        let partes = bruto.components(separatedBy: "\r\n\r\n")
        let cabecalho = partes.first ?? ""
        let corpoTexto = partes.count > 1 ? partes[1] : ""

        let linhas = cabecalho.components(separatedBy: "\r\n")
        guard let primeira = linhas.first else { return nil }
        let pedaco = primeira.components(separatedBy: " ")
        guard pedaco.count >= 2 else { return nil }

        var credencial: String?
        for linha in linhas.dropFirst() where linha.lowercased().hasPrefix("authorization:") {
            let valor = linha.dropFirst("authorization:".count).trimmingCharacters(in: .whitespaces)
            credencial = valor.hasPrefix("Bearer ") ? String(valor.dropFirst(7)) : valor
        }

        let corpo = (try? JSONSerialization.jsonObject(with: Data(corpoTexto.utf8)))
            as? [String: Any] ?? [:]

        return Requisicao(metodo: pedaco[0], caminho: pedaco[1],
                          credencial: credencial, corpo: corpo)
    }

    func processar(_ bruto: String) async -> String {
        guard let req = interpretar(bruto) else {
            return responder(400, ["erro": "requisição inválida"])
        }

        ultimaChamada = "\(req.metodo) \(req.caminho)"

        if req.caminho == "/parear", req.metodo == "POST" {
            let codigo = req.corpo["codigo"] as? String ?? ""
            let nome = req.corpo["nome"] as? String ?? "Celular"
            let modelo = req.corpo["modelo"] as? String ?? "iPhone"

            if let credencial = Pareamento.shared.aceitar(codigo: codigo, nome: nome, modelo: modelo) {
                return responder(200, ["credencial": credencial,
                                       "mac": Host.current().localizedName ?? "Mac"])
            }
            return responder(401, ["erro": "código inválido ou expirado"])
        }

        guard let credencial = req.credencial,
              let dispositivo = Pareamento.shared.validar(credencial) else {
            return responder(401, ["erro": "não pareado"])
        }

        guard let app else { return responder(400, ["erro": "app não pronto"]) }

        switch (req.metodo, req.caminho) {

        case ("GET", "/estado"):
            return responder(200, [
                "mac": Host.current().localizedName ?? "Mac",
                "livre": app.disk.available,
                "usado": app.disk.used,
                "total": app.disk.totalExibido,
                "fracao": app.disk.usedFraction,
                "apertado": app.disk.isTight,
                "liberavel": app.reclaimable,
                "nivel": Config.shared.nivel.rawValue,
                "seguranca": [
                    "nota": app.raioX.nota,
                    "criticos": app.raioX.criticos.count,
                    "avisos": app.raioX.avisos.count
                ],
                "saude": [
                    "ram": app.saude.ramFracao,
                    "cpu": app.saude.cpuUso,
                    "bateria": app.saude.bateriaPct ?? -1,
                    "uptime": app.saude.uptimeTexto
                ]
            ])

        case ("GET", "/categorias"):
            let itens = app.targets.filter { $0.size > 0 }.map { t in
                ["id": t.id, "nome": t.name, "tamanho": t.size,
                 "risco": t.risk.rawValue, "perde": t.loss]
            }
            return responder(200, ["categorias": itens])

        case ("POST", "/limpar"):
            let escopo = req.corpo["escopo"] as? String ?? "seguro"

            if escopo == "seguro" {
                await app.limpezaAutomatica()
                return responder(200, ["liberado": app.lastResult?.freed ?? 0,
                                       "livre": app.disk.available])
            }

            let ids = req.corpo["ids"] as? [String] ?? []
            let alvos = app.targets.filter { ids.contains($0.id) }
            guard !alvos.isEmpty else { return responder(400, ["erro": "nada selecionado"]) }

            let peso = alvos.reduce(Int64(0)) { $0 + $1.size }
            let arriscado = alvos.contains { $0.risk != .zero }

            if arriscado && !dispositivo.confiavel {
                let aprovado = await Pareamento.shared.pedirConfirmacao(
                    dispositivo: dispositivo.nome,
                    acao: "limpar \(Fmt.bytes(peso))",
                    detalhe: alvos.map(\.name).joined(separator: ", "))
                guard aprovado else {
                    return responder(401, ["erro": "recusado no Mac"])
                }
            }

            app.selection = Set(alvos.map(\.id))
            await app.cleanSelected()
            return responder(200, ["liberado": app.lastResult?.freed ?? 0,
                                   "naLixeira": app.lastResult?.itemsTrashed ?? 0,
                                   "livre": app.disk.available])

        case ("POST", "/analisar"):
            await app.revisar()
            return responder(200, ["achados": app.achados.count,
                                   "potencial": app.achados.reduce(Int64(0)) { $0 + $1.tamanho }])

        case ("POST", "/seguranca"):
            await app.analisarSeguranca()
            return responder(200, ["nota": app.raioX.nota,
                                   "criticos": app.raioX.criticos.map { $0.titulo }])

        default:
            return responder(400, ["erro": "rota desconhecida"])
        }
    }
}
