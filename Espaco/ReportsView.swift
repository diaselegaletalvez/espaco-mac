import SwiftUI
import AppKit

struct ReportsView: View {
    @State private var reports: [ReportFile] = []
    @State private var selected: ReportFile?

    var body: some View {
        HStack(spacing: 0) {

            VStack(spacing: 0) {
                if reports.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Sem relatórios")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(reports) { r in
                                Button {
                                    selected = r
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.titulo)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text(r.diaSemana)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 11)
                                    .background(selected?.id == r.id
                                                ? Color.accentColor.opacity(0.18)
                                                : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 7))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                    }

                    Divider()

                    HStack {
                        Text("\(reports.count) dias")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(History.folder)
                        } label: {
                            Image(systemName: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Abrir ~/Relatorios no Finder")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .frame(width: 190)
            .background(Color.secondary.opacity(0.05))

            Divider()

            Group {
                if let r = selected {
                    ScrollView {
                        MarkdownView(source: History.text(of: r))
                            .frame(maxWidth: 660, alignment: .leading)
                            .padding(28)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if reports.isEmpty {
                    Empty(titulo: "Nenhum relatório ainda",
                          detalhe: "O primeiro chega no horário que você marcou na aba Automação.")
                } else {
                    Empty(titulo: "Escolha um dia",
                          detalhe: "Os relatórios ficam guardados por 30 dias.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            reports = History.reports()
            if selected == nil { selected = reports.first }
        }
    }
}

struct Empty: View {
    let titulo: String
    let detalhe: String

    var body: some View {
        VStack(spacing: 6) {
            Text(titulo)
                .font(.system(size: 16, weight: .medium, design: .rounded))
            Text(detalhe)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
