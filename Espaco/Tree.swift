import Foundation

final class Node: Identifiable, @unchecked Sendable {
    let id = UUID()
    let url: URL
    let nome: String
    let ehPasta: Bool
    var tamanho: Int64
    var filhos: [Node]
    weak var pai: Node?

    init(url: URL, nome: String, ehPasta: Bool, tamanho: Int64, filhos: [Node] = []) {
        self.url = url
        self.nome = nome
        self.ehPasta = ehPasta
        self.tamanho = tamanho
        self.filhos = filhos
    }

    var caminho: [Node] {
        var out: [Node] = [self]
        var atual = pai
        while let n = atual { out.append(n); atual = n.pai }
        return out.reversed()
    }

    var categoria: Categoria { Categoria.de(self) }
}

enum Categoria: String, CaseIterable {
    case codigo, midia, cache, app, sistema, documento, arquivo, outro

    var rotulo: String {
        switch self {
        case .codigo: return "Código"
        case .midia: return "Mídia"
        case .cache: return "Cache"
        case .app: return "Apps"
        case .sistema: return "Sistema"
        case .documento: return "Documentos"
        case .arquivo: return "Compactados"
        case .outro: return "Outros"
        }
    }

    static func de(_ n: Node) -> Categoria {
        let p = n.url.path.lowercased()
        let nome = n.nome.lowercased()
        let ext = n.url.pathExtension.lowercased()

        if nome == "node_modules" || nome == "pods" || nome == ".git"
            || p.contains("/deriveddata") || nome == ".next" || nome == ".expo" {
            return .codigo
        }
        if nome.contains("cache") || p.contains("/caches/") || nome == "logs"
            || p.contains("/tmp/") || nome == "deriveddata" {
            return .cache
        }
        if ext == "app" || p.hasPrefix("/applications") { return .app }
        if p.hasPrefix("/system") || p.hasPrefix("/library")
            || p.contains("/coresimulator") || p.contains("/developer") { return .sistema }

        switch ext {
        case "mp4", "mov", "avi", "mkv", "mp3", "wav", "aiff", "png", "jpg",
             "jpeg", "heic", "gif", "psd", "raw", "webm":
            return .midia
        case "zip", "dmg", "pkg", "tar", "gz", "7z", "rar", "ipa", "xip":
            return .arquivo
        case "pdf", "docx", "pptx", "xlsx", "md", "txt", "pages", "numbers", "key":
            return .documento
        case "swift", "js", "ts", "tsx", "jsx", "py", "rb", "go", "rs", "json", "yml":
            return .codigo
        default:
            return .outro
        }
    }
}

enum Tree {

    nonisolated(unsafe) static var cancelado = false

    static func medir(_ url: URL) -> Int64 {
        Scanner.size(of: url)
    }

    static func construir(_ url: URL, profundidade: Int, minimo: Int64) -> Node {
        let fm = FileManager.default
        let nome = url.lastPathComponent

        var ehPasta: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &ehPasta) else {
            return Node(url: url, nome: nome, ehPasta: false, tamanho: 0)
        }

        if !ehPasta.boolValue {
            let v = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            let s = Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
            return Node(url: url, nome: nome, ehPasta: false, tamanho: s)
        }

        guard profundidade > 0, !cancelado else {
            return Node(url: url, nome: nome, ehPasta: true, tamanho: medir(url))
        }

        let itens = (try? fm.contentsOfDirectory(at: url,
                                                 includingPropertiesForKeys: [.isDirectoryKey],
                                                 options: [])) ?? []

        var filhos: [Node] = []
        filhos.reserveCapacity(itens.count)

        for item in itens {
            if cancelado { break }
            let filho = construir(item, profundidade: profundidade - 1, minimo: minimo)
            if filho.tamanho > 0 { filhos.append(filho) }
        }

        filhos.sort { $0.tamanho > $1.tamanho }
        let total = filhos.reduce(Int64(0)) { $0 + $1.tamanho }

        let grandes = filhos.filter { $0.tamanho >= minimo }
        let pequenos = filhos.filter { $0.tamanho < minimo }

        var finais = grandes
        if pequenos.count > 1 {
            let resto = pequenos.reduce(Int64(0)) { $0 + $1.tamanho }
            if resto > 0 {
                finais.append(Node(url: url, nome: "\(pequenos.count) itens menores",
                                   ehPasta: false, tamanho: resto))
            }
        } else {
            finais.append(contentsOf: pequenos)
        }

        let no = Node(url: url, nome: nome, ehPasta: true, tamanho: total, filhos: finais)
        for f in finais { f.pai = no }
        return no
    }

    static func varrerHome(profundidade: Int = 5) -> Node {
        cancelado = false
        let home = FileManager.default.homeDirectoryForCurrentUser
        let raiz = construir(home, profundidade: profundidade, minimo: 20_000_000)
        return raiz
    }
}
