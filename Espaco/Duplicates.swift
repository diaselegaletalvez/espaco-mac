import Foundation
import CryptoKit

struct DupFile: Identifiable, Sendable {
    let id: String
    let url: URL
    let tamanho: Int64
    var nome: String { url.lastPathComponent }
    var pasta: String { url.deletingLastPathComponent().lastPathComponent }
}

struct DupGroup: Identifiable, Sendable {
    let id: String
    let tamanhoUnitario: Int64
    let arquivos: [DupFile]

    var desperdicio: Int64 { tamanhoUnitario * Int64(max(0, arquivos.count - 1)) }
    var original: DupFile? { arquivos.first }
    var copias: [DupFile] { Array(arquivos.dropFirst()) }
}

enum Duplicates {
    static let minimo: Int64 = 2_000_000

    private static let ignorar: Set<String> = [
        "node_modules", "Pods", ".git", "Library", ".Trash", ".expo",
        "DerivedData", ".next", "build", ".gradle", "Applications"
    ]

    static func hash(_ url: URL, limite: Int? = nil) -> String? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        var hasher = SHA256()
        var lidos = 0
        while true {
            guard let chunk = try? fh.read(upToCount: 262_144), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
            lidos += chunk.count
            if let l = limite, lidos >= l { break }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func candidatos() -> [DupFile] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let raizes = ["Downloads", "Desktop", "Documents", "Pictures", "Movies", "Music"]
            .map { home.appending(path: $0) }
            .filter { fm.fileExists(atPath: $0.path) }

        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
                                         .isRegularFileKey]
        var out: [DupFile] = []

        for raiz in raizes {
            guard let en = fm.enumerator(at: raiz,
                                         includingPropertiesForKeys: Array(keys),
                                         options: [.skipsHiddenFiles],
                                         errorHandler: { _, _ in true }) else { continue }
            for case let u as URL in en {
                if u.hasDirectoryPath {
                    if ignorar.contains(u.lastPathComponent) { en.skipDescendants() }
                    continue
                }
                guard let v = try? u.resourceValues(forKeys: keys),
                      v.isRegularFile == true else { continue }
                let s = Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
                guard s >= minimo else { continue }
                out.append(DupFile(id: u.path, url: u, tamanho: s))
            }
        }
        return out
    }

    static func varrer() -> [DupGroup] {
        let todos = candidatos()

        var porTamanho: [Int64: [DupFile]] = [:]
        for f in todos { porTamanho[f.tamanho, default: []].append(f) }
        let suspeitos = porTamanho.filter { $0.value.count > 1 }

        var porPrefixo: [String: [DupFile]] = [:]
        for (tam, arquivos) in suspeitos {
            for f in arquivos {
                guard let h = hash(f.url, limite: 262_144) else { continue }
                porPrefixo["\(tam)-\(h)", default: []].append(f)
            }
        }

        var grupos: [DupGroup] = []
        for (_, arquivos) in porPrefixo where arquivos.count > 1 {
            var porCompleto: [String: [DupFile]] = [:]
            for f in arquivos {
                guard let h = hash(f.url) else { continue }
                porCompleto[h, default: []].append(f)
            }
            for (h, iguais) in porCompleto where iguais.count > 1 {
                let ordenados = iguais.sorted { $0.url.path.count < $1.url.path.count }
                grupos.append(DupGroup(id: h,
                                       tamanhoUnitario: ordenados[0].tamanho,
                                       arquivos: ordenados))
            }
        }

        return grupos.sorted { $0.desperdicio > $1.desperdicio }
    }

    static func removerCopias(_ grupos: [DupGroup]) -> CleanResult {
        var r = CleanResult()
        let fm = FileManager.default
        for g in grupos {
            for c in g.copias {
                do {
                    var out: NSURL?
                    try fm.trashItem(at: c.url, resultingItemURL: &out)
                    r.itemsTrashed += 1
                    r.freed += c.tamanho
                } catch {
                    r.failures.append(c.nome)
                }
            }
        }
        return r
    }
}
