import SwiftUI

struct MDBlock: Identifiable {
    enum Kind {
        case h1(String), h2(String), h3(String)
        case para(String), bullet(String), quote(String)
        case table(header: [String], rows: [[String]])
        case rule
    }
    let id: Int
    let kind: Kind
}

enum MD {
    static func parse(_ text: String) -> [MDBlock] {
        var out: [MDBlock] = []
        var n = 0
        var buffer: [[String]] = []

        func flushTable() {
            guard !buffer.isEmpty else { return }
            let header = buffer[0]
            let rows = Array(buffer.dropFirst())
            out.append(MDBlock(id: n, kind: .table(header: header, rows: rows)))
            n += 1
            buffer = []
        }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("|") && line.hasSuffix("|") {
                let cells = line
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .dropFirst()
                    .dropLast()
                let arr = Array(cells)
                let isSeparator = arr.allSatisfy { c in
                    !c.isEmpty && c.allSatisfy { $0 == "-" || $0 == ":" }
                }
                if !isSeparator { buffer.append(arr) }
                continue
            }

            flushTable()
            if line.isEmpty { continue }

            if line == "---" {
                out.append(MDBlock(id: n, kind: .rule)); n += 1
            } else if line.hasPrefix("### ") {
                out.append(MDBlock(id: n, kind: .h3(String(line.dropFirst(4))))); n += 1
            } else if line.hasPrefix("## ") {
                out.append(MDBlock(id: n, kind: .h2(String(line.dropFirst(3))))); n += 1
            } else if line.hasPrefix("# ") {
                out.append(MDBlock(id: n, kind: .h1(String(line.dropFirst(2))))); n += 1
            } else if line.hasPrefix("> ") {
                out.append(MDBlock(id: n, kind: .quote(String(line.dropFirst(2))))); n += 1
            } else if line.hasPrefix("- ") {
                out.append(MDBlock(id: n, kind: .bullet(String(line.dropFirst(2))))); n += 1
            } else {
                out.append(MDBlock(id: n, kind: .para(line))); n += 1
            }
        }
        flushTable()
        return out
    }

    static func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }
}

struct MarkdownView: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(MD.parse(source)) { block in
                switch block.kind {
                case .h1(let t):
                    Text(t)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .padding(.bottom, 2)

                case .h2(let t):
                    Text(t)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .padding(.top, 10)

                case .h3(let t):
                    Text(t)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.top, 6)

                case .para(let t):
                    Text(MD.inline(t))
                        .font(.callout)
                        .foregroundStyle(.secondary)

                case .bullet(let t):
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(.tertiary)
                        Text(MD.inline(t)).font(.callout)
                    }

                case .quote(let t):
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle().fill(.orange).frame(width: 3)
                        Text(MD.inline(t)).font(.callout)
                    }
                    .padding(12)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                case .rule:
                    Divider().padding(.vertical, 4)

                case .table(let header, let rows):
                    MDTable(header: header, rows: rows)
                }
            }
        }
    }
}

struct MDTable: View {
    let header: [String]
    let rows: [[String]]

    private var hasHeader: Bool {
        header.contains { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            if hasHeader {
                row(header, bold: true)
                Divider()
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                row(r, bold: false)
                if i < rows.count - 1 { Divider().opacity(0.4) }
            }
        }
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ cells: [String], bold: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, c in
                Text(MD.inline(c))
                    .font(bold ? .caption.weight(.semibold) : .callout)
                    .foregroundStyle(bold ? .secondary : .primary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity,
                           alignment: i == 0 ? .leading : (cells.count > 2 ? .leading : .trailing))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}
