import SwiftUI

struct ProjectsView: View {
    @Environment(AppState.self) private var state

    private var dormentes: [ProjectInfo] { state.projetos.filter(\.dormente) }
    private var ativos: [ProjectInfo] { state.projetos.filter { !$0.dormente } }

    private var pesoDormente: Int64 {
        dormentes.reduce(0) { $0 + $1.peso }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Fmt.bytes(state.projetos.reduce(0) { $0 + $1.peso }))
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("em dependências e builds nos seus projetos")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await state.scanProjetos() }
                    } label: {
                        Label("Reescanear", systemImage: "arrow.clockwise")
                    }
                    .disabled(state.scanningProjetos)
                }

                if state.scanningProjetos {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Lendo ~/projetos…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                if !dormentes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Dormentes")
                                .font(.headline)
                            Text("sem toque há 30 dias ou mais")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Fmt.bytes(pesoDormente))
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.orange)
                        }

                        ForEach(dormentes) { p in
                            ProjectRow(projeto: p, destaque: true) {
                                Task { await state.limparProjeto(p) }
                            }
                        }
                    }
                }

                if !ativos.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Em uso")
                            .font(.headline)
                        ForEach(ativos) { p in
                            ProjectRow(projeto: p, destaque: false) {
                                Task { await state.limparProjeto(p) }
                            }
                        }
                    }
                }

                if state.projetos.isEmpty && !state.scanningProjetos {
                    Empty(titulo: "Nada pesado em ~/projetos",
                          detalhe: "Nenhum node_modules, Pods ou build encontrado.")
                }
            }
            .padding(28)
        }
        .task {
            if state.projetos.isEmpty { await state.scanProjetos() }
        }
    }
}

struct ProjectRow: View {
    let projeto: ProjectInfo
    let destaque: Bool
    let limpar: () -> Void

    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(destaque ? Color.orange : Color.secondary.opacity(0.4))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(projeto.nome)
                    .font(.body.weight(.medium))
                Text("\(projeto.descricaoTempo) · \(projeto.pastas.count) pastas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(Fmt.bytes(projeto.peso))
                .font(.body.monospacedDigit())

            Button("Pra Lixeira", action: limpar)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .opacity(hover ? 1 : 0.35)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(destaque ? Color.orange.opacity(0.10) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8))
        .onHover { hover = $0 }
    }
}
