import SwiftUI
import AppKit

struct AppsView: View {
    @Environment(AppState.self) private var state
    @State private var expandido: String?
    @State private var confirmar: InstalledApp?

    private var lista: [InstalledApp] {
        state.apps.filter { !$0.daSystem }
    }

    private var esquecidos: [InstalledApp] { lista.filter(\.esquecido) }
    private var resto: [InstalledApp] { lista.filter { !$0.esquecido } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Fmt.bytes(lista.reduce(0) { $0 + $1.total }))
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("\(lista.count) apps, contando os resíduos que eles deixam")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await state.scanApps() }
                    } label: {
                        Label("Reescanear", systemImage: "arrow.clockwise")
                    }
                    .disabled(state.scanningApps)
                }

                if state.scanningApps {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Lendo /Applications e caçando resíduos…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                if !esquecidos.isEmpty {
                    secao("Esquecidos", "sem abrir há 3 meses ou mais", esquecidos, .orange)
                }
                if !resto.isEmpty {
                    secao("Instalados", nil, resto, nil)
                }
            }
            .padding(28)
        }
        .task { if state.apps.isEmpty { await state.scanApps() } }
        .alert("Remover \(confirmar?.nome ?? "")?",
               isPresented: Binding(get: { confirmar != nil },
                                    set: { if !$0 { confirmar = nil } })) {
            Button("Cancelar", role: .cancel) { confirmar = nil }
            Button("Só os resíduos") {
                if let a = confirmar { Task { await state.removerApp(a, incluirApp: false) } }
                confirmar = nil
            }
            Button("App e resíduos", role: .destructive) {
                if let a = confirmar { Task { await state.removerApp(a, incluirApp: true) } }
                confirmar = nil
            }
        } message: {
            if let a = confirmar {
                Text("Tudo vai pra Lixeira: o app tem \(Fmt.bytes(a.tamanhoApp)) e deixou \(Fmt.bytes(a.tamanhoResiduos)) em \(a.residuos.count) lugares. Feche o app antes.")
            }
        }
    }

    private func secao(_ titulo: String, _ sub: String?,
                       _ apps: [InstalledApp], _ cor: Color?) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(titulo).font(.headline)
                if let s = sub {
                    Text(s).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Fmt.bytes(apps.reduce(0) { $0 + $1.total }))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(cor ?? .secondary)
            }

            ForEach(apps) { a in
                AppRow(app: a,
                       destaque: cor != nil,
                       aberto: expandido == a.id,
                       alternar: { expandido = expandido == a.id ? nil : a.id },
                       remover: { confirmar = a })
            }
        }
    }
}

struct AppRow: View {
    let app: InstalledApp
    let destaque: Bool
    let aberto: Bool
    let alternar: () -> Void
    let remover: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                    .resizable()
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.nome).font(.body.weight(.medium))
                    HStack(spacing: 6) {
                        Text(app.descricaoUso)
                        if app.tamanhoResiduos > 0 {
                            Text("·")
                            Text("\(Fmt.bytes(app.tamanhoResiduos)) de resíduo")
                                .foregroundStyle(destaque ? .orange : .secondary)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(Fmt.bytes(app.total))
                    .font(.body.monospacedDigit())

                if !app.residuos.isEmpty {
                    Button {
                        alternar()
                    } label: {
                        Image(systemName: aberto ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Button("Remover", action: remover)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)

            if aberto {
                VStack(spacing: 5) {
                    ForEach(app.residuos) { r in
                        HStack(spacing: 8) {
                            Text(r.tipo)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.15),
                                            in: RoundedRectangle(cornerRadius: 3))
                            Text(r.url.lastPathComponent)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(Fmt.bytes(r.tamanho))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(destaque ? Color.orange.opacity(0.10) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8))
    }
}
