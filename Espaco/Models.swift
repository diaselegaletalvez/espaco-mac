import Foundation

struct DiskInfo: Sendable {
    var total: Int64 = 0
    var available: Int64 = 0
    var used: Int64 = 0

    var usedFraction: Double {
        let denom = used + available
        return denom > 0 ? Double(used) / Double(denom) : 0
    }

    var isTight: Bool { usedFraction >= 0.85 }
}

enum Risk: String, Sendable {
    case zero = "risco zero"
    case medio = "risco médio"
    case alto = "risco alto"
}

struct Target: Identifiable, Sendable {
    let id: String
    let name: String
    let paths: [URL]
    let risk: Risk
    let loss: String
    var size: Int64 = 0
    var measured: Bool = false
}

enum Fmt {
    static func bytes(_ v: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB, .useKB]
        f.countStyle = .file
        f.includesUnit = true
        return f.string(fromByteCount: v)
    }

    static func pct(_ v: Double) -> String {
        "\(Int((v * 100).rounded()))%"
    }
}

enum Catalog {
    private static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    private static func h(_ p: String) -> URL { home.appending(path: p) }

    static let all: [Target] = [
        Target(id: "devicesupport",
               name: "iOS DeviceSupport",
               paths: [h("Library/Developer/Xcode/iOS DeviceSupport")],
               risk: .zero,
               loss: "Nada. O Xcode rebaixa ao plugar o iPhone"),

        Target(id: "deriveddata",
               name: "DerivedData",
               paths: [h("Library/Developer/Xcode/DerivedData")],
               risk: .zero,
               loss: "Um build completo em vez de incremental"),

        Target(id: "simcache",
               name: "Caches de simulador",
               paths: [h("Library/Developer/CoreSimulator/Caches"),
                       URL(fileURLWithPath: "/Library/Developer/CoreSimulator/Caches")],
               risk: .zero,
               loss: "Nada. São imagens já instaladas"),

        Target(id: "devcaches",
               name: "Caches de dev",
               paths: [h("Library/Caches/CocoaPods"),
                       h("Library/Caches/Homebrew"),
                       h("Library/Caches/ReactNative"),
                       h("Library/Caches/node-gyp"),
                       h("Library/Caches/electron"),
                       h("Library/Caches/electron-builder"),
                       h(".npm/_cacache"),
                       h(".expo")],
               risk: .zero,
               loss: "Redownload das dependências"),

        Target(id: "appcaches",
               name: "Caches de apps",
               paths: [h("Library/Application Support/Claude/Cache"),
                       h("Library/Application Support/Claude/Code Cache"),
                       h("Library/Application Support/Claude/GPUCache"),
                       h("Library/Caches/Google")],
               risk: .zero,
               loss: "Primeiro carregamento mais lento"),

        Target(id: "logs",
               name: "Logs e Lixeira",
               paths: [h("Library/Logs"), h(".Trash")],
               risk: .zero,
               loss: "Nada"),

        Target(id: "nodemodules",
               name: "node_modules em projetos",
               paths: [h("projetos")],
               risk: .medio,
               loss: "npm install antes de mexer no projeto"),

        Target(id: "archives",
               name: "Archives do Xcode",
               paths: [h("Library/Developer/Xcode/Archives")],
               risk: .alto,
               loss: "dSYMs. Não simboliza mais crash de build publicado")
    ]
}
