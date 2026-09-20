import Foundation
import Security
import CryptoKit
import Observation

struct DispositivoPareado: Identifiable, Codable, Sendable {
    let id: String
    var nome: String
    var modelo: String
    var pareadoEm: Date
    var ultimoAcesso: Date?
    var confiavel: Bool
    var revogado: Bool

    var descricaoAcesso: String {
        guard let u = ultimoAcesso else { return "nunca usado" }
        let m = Int(Date().timeIntervalSince(u) / 60)
        if m < 1 { return "agora" }
        if m < 60 { return "há \(m) min" }
        let h = m / 60
        if h < 24 { return "há \(h)h" }
        return "há \(h / 24) dias"
    }
}

enum Chaveiro {
    private static let servico = "com.diaselegaletalvez.Espaco.pareamento"

    static func guardar(_ token: String, para id: String) {
        apagar(id)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: id,
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func ler(_ id: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: id,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let dados = item as? Data else { return nil }
        return String(data: dados, encoding: .utf8)
    }

    static func apagar(_ id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: id
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
@Observable
final class Pareamento {
    static let shared = Pareamento()

    private let chaveDispositivos = "espaco.dispositivos"

    var dispositivos: [DispositivoPareado] = []
    var modoPareamento = false
    var codigoAtual: String?
    var segundosRestantes = 0
    var pedidoPendente: PedidoConfirmacao?

    private var relogio: Timer?

    struct PedidoConfirmacao: Identifiable, Sendable {
        let id = UUID()
        let dispositivo: String
        let acao: String
        let detalhe: String
        let continuar: @Sendable (Bool) -> Void
    }

    private init() {
        carregar()
    }

    private func carregar() {
        guard let dados = UserDefaults.standard.data(forKey: chaveDispositivos),
              let lista = try? JSONDecoder().decode([DispositivoPareado].self, from: dados)
        else { return }
        dispositivos = lista.filter { !$0.revogado }
    }

    private func salvar() {
        guard let dados = try? JSONEncoder().encode(dispositivos) else { return }
        UserDefaults.standard.set(dados, forKey: chaveDispositivos)
    }

    static func novoToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func novoCodigo() -> String {
        var bytes = [UInt8](repeating: 0, count: 4)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let n = bytes.reduce(0) { ($0 << 8) | Int($1) } % 1_000_000
        return String(format: "%06d", abs(n))
    }

    func abrirPareamento() {
        codigoAtual = Pareamento.novoCodigo()
        modoPareamento = true
        segundosRestantes = 120

        relogio?.invalidate()
        relogio = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.segundosRestantes -= 1
                if self.segundosRestantes <= 0 { self.fecharPareamento() }
            }
        }
        ServidorLocal.shared.ligar()
    }

    func fecharPareamento() {
        relogio?.invalidate()
        relogio = nil
        modoPareamento = false
        codigoAtual = nil
        segundosRestantes = 0
        if dispositivos.isEmpty { ServidorLocal.shared.desligar() }
    }

    func aceitar(codigo: String, nome: String, modelo: String) -> String? {
        guard modoPareamento, let esperado = codigoAtual else { return nil }
        guard constantesIguais(codigo, esperado) else { return nil }

        let id = UUID().uuidString
        let token = Pareamento.novoToken()
        Chaveiro.guardar(token, para: id)

        dispositivos.append(DispositivoPareado(id: id, nome: nome, modelo: modelo,
                                               pareadoEm: Date(), ultimoAcesso: nil,
                                               confiavel: false, revogado: false))
        salvar()
        fecharPareamento()

        Notifier.avisar("Celular pareado", "\(nome) agora consegue ver e controlar o Espaço.")
        return "\(id).\(token)"
    }

    func validar(_ credencial: String) -> DispositivoPareado? {
        let partes = credencial.split(separator: ".", maxSplits: 1).map(String.init)
        guard partes.count == 2 else { return nil }
        let (id, token) = (partes[0], partes[1])

        guard let guardado = Chaveiro.ler(id),
              constantesIguais(token, guardado),
              let indice = dispositivos.firstIndex(where: { $0.id == id && !$0.revogado })
        else { return nil }

        dispositivos[indice].ultimoAcesso = Date()
        salvar()
        return dispositivos[indice]
    }

    func revogar(_ id: String) {
        Chaveiro.apagar(id)
        dispositivos.removeAll { $0.id == id }
        salvar()
        if dispositivos.isEmpty { ServidorLocal.shared.desligar() }
    }

    func alternarConfianca(_ id: String) {
        guard let i = dispositivos.firstIndex(where: { $0.id == id }) else { return }
        dispositivos[i].confiavel.toggle()
        salvar()
    }

    func pedirConfirmacao(dispositivo: String, acao: String, detalhe: String) async -> Bool {
        await withCheckedContinuation { cont in
            let pedido = PedidoConfirmacao(dispositivo: dispositivo, acao: acao,
                                           detalhe: detalhe) { resposta in
                cont.resume(returning: resposta)
            }
            self.pedidoPendente = pedido
            Notifier.avisar("\(dispositivo) pediu: \(acao)",
                            "Abra o Espaço pra confirmar. Nada acontece até você aprovar.")
        }
    }

    func responder(_ aprovado: Bool) {
        guard let p = pedidoPendente else { return }
        pedidoPendente = nil
        p.continuar(aprovado)
    }

    private func constantesIguais(_ a: String, _ b: String) -> Bool {
        let da = Array(a.utf8), db = Array(b.utf8)
        guard da.count == db.count else { return false }
        var diferenca: UInt8 = 0
        for i in 0..<da.count { diferenca |= da[i] ^ db[i] }
        return diferenca == 0
    }
}
