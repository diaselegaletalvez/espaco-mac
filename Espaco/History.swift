import Foundation

struct DayPoint: Identifiable, Codable, Sendable {
    var data: String
    var total: Int64
    var usado: Int64
    var livre: Int64
    var liberou: Int64

    var id: String { data }
    var date: Date { History.iso.date(from: data) ?? .distantPast }
}

struct ReportFile: Identifiable, Sendable, Hashable {
    var id: String { stem }
    let stem: String
    let url: URL
    let date: Date

    var titulo: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "d 'de' MMMM"
        return f.string(from: date)
    }

    var diaSemana: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEEE"
        return f.string(from: date).capitalized
    }
}

enum History {
    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Relatorios")
    }

    static var exists: Bool {
        FileManager.default.fileExists(atPath: folder.path)
    }

    static func points() -> [DayPoint] {
        let url = folder.appending(path: "historico.json")
        guard let d = try? Data(contentsOf: url),
              let arr = try? JSONDecoder().decode([DayPoint].self, from: d) else { return [] }
        return arr.sorted { $0.data < $1.data }
    }

    static func reports() -> [ReportFile] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: folder,
                                                      includingPropertiesForKeys: nil,
                                                      options: [.skipsHiddenFiles]) else { return [] }
        return items
            .filter { $0.lastPathComponent.hasPrefix("mac-") && $0.pathExtension == "md" }
            .compactMap { u -> ReportFile? in
                let stem = u.deletingPathExtension().lastPathComponent
                    .replacingOccurrences(of: "mac-", with: "")
                guard let d = iso.date(from: stem) else { return nil }
                return ReportFile(stem: stem, url: u, date: d)
            }
            .sorted { $0.date > $1.date }
    }

    static func text(of report: ReportFile) -> String {
        (try? String(contentsOf: report.url, encoding: .utf8))
            ?? "Não consegui ler esse relatório."
    }
}
