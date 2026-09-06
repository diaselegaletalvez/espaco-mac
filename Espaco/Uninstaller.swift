import Foundation
import CoreServices

struct Residuo: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let tamanho: Int64
    let tipo: String
}

struct InstalledApp: Identifiable, Sendable {
    let id: String
    let nome: String
    let url: URL
    let bundleID: String
    let tamanhoApp: Int64
    let residuos: [Residuo]
    let ultimoUso: Date?
    let daSystem: Bool

    var tamanhoResiduos: Int64 { residuos.reduce(0) { $0 + $1.tamanho } }
    var total: Int64 { tamanhoApp + tamanhoResiduos }

    var descricaoUso: String {
        guard let u = ultimoUso else { return "nunca aberto por aqui" }
        let dias = Calendar.current.dateComponents([.day], from: u, to: Date()).day ?? 0
        if dias <= 1 { return "usado hoje" }
        if dias < 30 { return "usado há \(dias) dias" }
        let m = dias / 30
        return m == 1 ? "usado há 1 mês" : "usado há \(m) meses"
    }

    var esquecido: Bool {
        guard let u = ultimoUso else { return total > 100_000_000 }
        let dias = Calendar.current.dateComponents([.day], from: u, to: Date()).day ?? 0
        return dias >= 90 && total > 50_000_000
    }
}

enum Uninstaller {

    static func ultimoUso(_ url: URL) -> Date? {
        guard let item = MDItemCreate(nil, url.path as CFString) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }

    static func bundleID(_ url: URL) -> String? {
        Bundle(url: url)?.bundleIdentifier
    }

    private static var lib: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library")
    }

    static func residuos(bundleID: String, nome: String) -> [Residuo] {
        let fm = FileManager.default
        var achados: [Residuo] = []

        let exatos: [(String, String)] = [
            ("Application Support/\(bundleID)", "Dados"),
            ("Application Support/\(nome)", "Dados"),
            ("Caches/\(bundleID)", "Cache"),
            ("Caches/\(nome)", "Cache"),
            ("Preferences/\(bundleID).plist", "Preferências"),
            ("Containers/\(bundleID)", "Container"),
            ("HTTPStorages/\(bundleID)", "Cookies"),
            ("HTTPStorages/\(bundleID).binarycookies", "Cookies"),
            ("Saved Application State/\(bundleID).savedState", "Estado"),
            ("WebKit/\(bundleID)", "WebKit"),
            ("Logs/\(nome)", "Logs"),
            ("Logs/\(bundleID)", "Logs")
        ]

        for (rel, tipo) in exatos {
            let u = lib.appending(path: rel)
            guard fm.fileExists(atPath: u.path) else { continue }
            let s = Scanner.size(of: u)
            if s > 0 { achados.append(Residuo(url: u, tamanho: s, tipo: tipo)) }
        }

        let porPrefixo: [(String, String)] = [
            ("Group Containers", "Group container"),
            ("LaunchAgents", "Inicialização")
        ]

        for (pasta, tipo) in porPrefixo {
            let dir = lib.appending(path: pasta)
            guard let itens = try? fm.contentsOfDirectory(at: dir,
                                                          includingPropertiesForKeys: nil,
                                                          options: []) else { continue }
            for item in itens where item.lastPathComponent.contains(bundleID) {
                let s = Scanner.size(of: item)
                achados.append(Residuo(url: item, tamanho: max(s, 1), tipo: tipo))
            }
        }

        return achados.sorted { $0.tamanho > $1.tamanho }
    }

    static func listar() -> [InstalledApp] {
        let fm = FileManager.default
        var pastas = [URL(fileURLWithPath: "/Applications")]
        let userApps = fm.homeDirectoryForCurrentUser.appending(path: "Applications")
        if fm.fileExists(atPath: userApps.path) { pastas.append(userApps) }

        var apps: [InstalledApp] = []

        for pasta in pastas {
            guard let itens = try? fm.contentsOfDirectory(at: pasta,
                                                          includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles]) else { continue }
            for u in itens where u.pathExtension == "app" {
                let nome = u.deletingPathExtension().lastPathComponent
                guard let bid = bundleID(u) else { continue }
                let sistema = bid.hasPrefix("com.apple.")
                let tam = Scanner.size(of: u)
                let res = residuos(bundleID: bid, nome: nome)
                apps.append(InstalledApp(id: u.path,
                                         nome: nome,
                                         url: u,
                                         bundleID: bid,
                                         tamanhoApp: tam,
                                         residuos: res,
                                         ultimoUso: ultimoUso(u),
                                         daSystem: sistema))
            }
        }

        return apps.sorted { $0.total > $1.total }
    }

    static func remover(_ app: InstalledApp, incluirApp: Bool) -> CleanResult {
        var r = CleanResult()
        let fm = FileManager.default

        for res in app.residuos {
            do {
                var out: NSURL?
                try fm.trashItem(at: res.url, resultingItemURL: &out)
                r.itemsTrashed += 1
                r.freed += res.tamanho
            } catch {
                r.failures.append(res.url.lastPathComponent)
            }
        }

        if incluirApp {
            do {
                var out: NSURL?
                try fm.trashItem(at: app.url, resultingItemURL: &out)
                r.itemsTrashed += 1
                r.freed += app.tamanhoApp
            } catch {
                r.failures.append("\(app.nome).app (feche o app antes)")
            }
        }
        return r
    }
}
