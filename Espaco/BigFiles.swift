import Foundation

struct BigFile: Identifiable, Sendable {
    let id: String
    let url: URL
    let nome: String
    let tamanho: Int64
    let modificado: Date
    let acessado: Date?

    var dias: Int {
        let ref = acessado ?? modificado
        return max(0, Calendar.current.dateComponents([.day], from: ref, to: Date()).day ?? 0)
    }

    var descricaoIdade: String {
        let d = dias
        if d < 30 { return "há \(d) dias" }
        let m = d / 30
        return m == 1 ? "há 1 mês" : "há \(m) meses"
    }

    var instalador: Bool {
        ["dmg", "pkg", "iso", "xip"].contains(url.pathExtension.lowercased())
    }

    var esquecido: Bool { dias >= 30 }
}

enum BigFiles {
    static let minimo: Int64 = 80_000_000

    static func varrer() -> [BigFile] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let alvos = ["Downloads", "Desktop", "Documents", "Movies", "Music", "Pictures"]
            .map { home.appending(path: $0) }
            .filter { fm.fileExists(atPath: $0.path) }

        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
                                         .isRegularFileKey, .contentModificationDateKey,
                                         .contentAccessDateKey]

        var out: [BigFile] = []

        for raiz in alvos {
            guard let en = fm.enumerator(at: raiz,
                                         includingPropertiesForKeys: Array(keys),
                                         options: [.skipsHiddenFiles],
                                         errorHandler: { _, _ in true }) else { continue }
            for case let u as URL in en {
                guard let v = try? u.resourceValues(forKeys: keys),
                      v.isRegularFile == true else { continue }
                let s = Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
                guard s >= minimo else { continue }
                out.append(BigFile(id: u.path,
                                   url: u,
                                   nome: u.lastPathComponent,
                                   tamanho: s,
                                   modificado: v.contentModificationDate ?? .distantPast,
                                   acessado: v.contentAccessDate))
            }
        }

        return out.sorted { $0.tamanho > $1.tamanho }
    }

    static func paraLixeira(_ arquivos: [BigFile]) -> CleanResult {
        var r = CleanResult()
        let fm = FileManager.default
        for a in arquivos {
            do {
                var out: NSURL?
                try fm.trashItem(at: a.url, resultingItemURL: &out)
                r.itemsTrashed += 1
                r.freed += a.tamanho
            } catch {
                r.failures.append(a.nome)
            }
        }
        return r
    }
}
