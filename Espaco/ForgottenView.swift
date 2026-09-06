import SwiftUI
import AppKit

struct ForgottenView: View {
    @Environment(AppState.self) private var state
    @State private var marcados: Set<String> = []

    private var instaladores: [BigFile] { state.grandes.filter { $0.instalador && $0.esquecido } }
    private var antigos: [BigFile] { state.grandes.filter { !$0.instalador && $0.esquecido } }
    private var recentes: [BigFile] { state.grandes.filter { !$0.esquecido } }

    private var pesoMarcado: Int64 {
        state.grandes.filter { marcados.contains($0.id) }.reduce(0) { $0 + $1.tamanho }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Fmt.bytes(state.grandes.reduce(0) { $0 + $1.tamanho }))
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Text("em arquivos acima de 80 MB nas suas pastas")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task { await state.scanGrandes() }
                        } label: {
                            Label("Reescanear", systemImage: "arrow.clockwise")
                        }
                        .disabled(state.scanningGrandes)
                    }

                    if state.scanningGrandes {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Procurando arquivos grandes…")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }

                    if !instaladores.isEmpty {
                        grupo("Instaladores já usados",
                              "DMG e PKG de apps que você já instalou",
                              instaladores, .orange)
                    }
                    if !antigos.isEmpty {
                        grupo("Grandes e parados", "sem abrir há mais de um mês", antigos, nil)
                    }
                    if !recentes.isEmpty {
                        grupo("Grandes e recentes", "mexidos no último mês", recentes, nil)
                    }

                    if state.grandes.isEmpty && !state.scanningGrandes {
                        Empty(titulo: "Nada acima de 80 MB",
                              detalhe: "Suas pastas de usuário estão enxutas.")
                    }
                }
                .padding(28)
                .padding(.bottom, 60)
            }

            if !marcados.isEmpty {
                HStack {
                    Text("\(marcados.count) marcados")
                        .font(.callout).foregroundStyle(.secondary)
                    Text(Fmt.bytes(pesoMarcado))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Spacer()
                    Button("Mandar pra Lixeira") {
                        let alvo = state.grandes.filter { marcados.contains($0.id) }
                        marcados = []
                        Task { await state.lixeiraGrandes(alvo) }
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
            }
        }
        .task { if state.grandes.isEmpty { await state.scanGrandes() } }
    }

    private func grupo(_ titulo: String, _ sub: String,
                       _ arquivos: [BigFile], _ cor: Color?) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(titulo).font(.headline)
                Text(sub).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(Fmt.bytes(arquivos.reduce(0) { $0 + $1.tamanho }))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(cor ?? .secondary)
            }

            ForEach(arquivos) { f in
                HStack(spacing: 12) {
                    Image(systemName: marcados.contains(f.id) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(marcados.contains(f.id) ? Color.accentColor
                                                                 : Color.secondary.opacity(0.5))

                    Image(nsImage: NSWorkspace.shared.icon(forFile: f.url.path))
                        .resizable().frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.nome).font(.body.weight(.medium)).lineLimit(1)
                        Text("\(f.url.deletingLastPathComponent().lastPathComponent) · \(f.descricaoIdade)")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    Text(Fmt.bytes(f.tamanho)).font(.body.monospacedDigit())

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([f.url])
                    } label: {
                        Image(systemName: "folder").font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 9)
                .padding(.horizontal, 12)
                .background(marcados.contains(f.id) ? Color.accentColor.opacity(0.10)
                                                    : (cor ?? Color.secondary).opacity(cor == nil ? 0.08 : 0.10),
                            in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .onTapGesture {
                    if marcados.contains(f.id) { marcados.remove(f.id) } else { marcados.insert(f.id) }
                }
            }
        }
    }
}
