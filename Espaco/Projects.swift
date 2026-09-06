import Foundation

struct ProjectInfo: Identifiable, Sendable {
    let id: String
    let nome: String
    let url: URL
    let tocadoEm: Date
    let peso: Int64
    let pastas: [URL]

    var diasParado: Int {
        max(0, Calendar.current.dateComponents([.day], from: tocadoEm, to: Date()).day ?? 0)
    }

    var dormente: Bool { diasParado >= 30 && peso > 50_000_000 }

    var descricaoTempo: String {
        let d = diasParado
        if d == 0 { return "mexido hoje" }
        if d == 1 { return "parado há 1 dia" }
        if d < 30 { return "parado há \(d) dias" }
        let meses = d / 30
        return meses == 1 ? "parado há 1 mês" : "parado há \(meses) meses"
    }
}

enum Projects {
    static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "projetos")
    }

    private static let pesados = ["node_modules", "ios/Pods", ".next", ".expo",
                                  "android/build", "android/.gradle", "ios/build", "build"]

    private static let marcadores = [".git/HEAD", ".git/ORIG_HEAD", "package.json",
                                     "Podfile", "app", "src", "lib", "index.html"]

    static func mtime(_ u: URL) -> Date? {
        (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    static func ehProjeto(_ u: URL) -> Bool {
        let fm = FileManager.default
        var dir: ObjCBool = false
        guard fm.fileExists(atPath: u.path, isDirectory: &dir), dir.boolValue else { return false }
        return fm.fileExists(atPath: u.appending(path: "package.json").path)
            || fm.fileExists(atPath: u.appending(path: ".git").path)
            || fm.fileExists(atPath: u.appending(path: "Podfile").path)
    }

    static func tocadoEm(_ u: URL) -> Date {
        let datas = marcadores
            .map { u.appending(path: $0) }
            .compactMap { mtime($0) }
        return datas.max() ?? mtime(u) ?? .distantPast
    }

    static func pastasPesadas(_ u: URL) -> [URL] {
        let fm = FileManager.default
        return pesados
            .map { u.appending(path: $0) }
            .filter { fm.fileExists(atPath: $0.path) }
    }

    static func scan() -> [ProjectInfo] {
        let fm = FileManager.default
        guard let nivel1 = try? fm.contentsOfDirectory(at: root,
                                                       includingPropertiesForKeys: nil,
                                                       options: [.skipsHiddenFiles]) else { return [] }

        var candidatos: [URL] = []
        for u in nivel1 {
            if ehProjeto(u) {
                candidatos.append(u)
            } else if let nivel2 = try? fm.contentsOfDirectory(at: u,
                                                               includingPropertiesForKeys: nil,
                                                               options: [.skipsHiddenFiles]) {
                candidatos.append(contentsOf: nivel2.filter { ehProjeto($0) })
            }
        }

        return candidatos.map { u in
            let pastas = pastasPesadas(u)
            let peso = pastas.reduce(Int64(0)) { $0 + Scanner.size(of: $1) }
            return ProjectInfo(id: u.path,
                               nome: u.lastPathComponent,
                               url: u,
                               tocadoEm: tocadoEm(u),
                               peso: peso,
                               pastas: pastas)
        }
        .filter { $0.peso > 0 }
        .sorted { $0.peso > $1.peso }
    }

    static func limpar(_ p: ProjectInfo) -> CleanResult {
        var r = CleanResult()
        let fm = FileManager.default
        for pasta in p.pastas {
            let antes = Scanner.size(of: pasta)
            do {
                var out: NSURL?
                try fm.trashItem(at: pasta, resultingItemURL: &out)
                r.itemsTrashed += 1
                r.freed += antes
            } catch {
                r.failures.append("\(p.nome)/\(pasta.lastPathComponent)")
            }
        }
        return r
    }
}
