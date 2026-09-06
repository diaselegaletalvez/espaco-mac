import SwiftUI
import AppKit

struct DuplicatesView: View {
    @Environment(AppState.self) private var state
    @State private var marcados: Set<String> = []

    private var grupos: [DupGroup] { state.duplicados }

    private var desperdicioTotal: Int64 {
        grupos.reduce(0) { $0 + $1.desperdicio }
    }

    private var marcadoTotal: Int64 {
        grupos.filter { marcados.contains($0.id) }.reduce(0) { $0 + $1.desperdicio }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Fmt.bytes(desperdicioTotal))
                                .font(T.numero(34))
                                .monospacedDigit()
                            Text(grupos.isEmpty
                                 ? "Nenhum arquivo repetido encontrado"
                                 : "em cópias idênticas · \(grupos.count) grupos")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task { await state.scanDuplicados() }
                        } label: {
                            Label("Procurar", systemImage: "arrow.clockwise")
                        }
                        .disabled(state.scanningDuplicados)
                    }

                    if state.scanningDuplicados {
                        HStack(spacing: 9) {
                            ProgressView().controlSize(.small)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Comparando arquivos…")
                                    .font(.callout)
                                Text("Agrupa por tamanho, compara os primeiros 256 KB, e só então calcula o SHA-256 completo. Pode levar alguns minutos.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .background(Color.secondary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: T.cartao))
                    }

                    if grupos.isEmpty && !state.scanningDuplicados && state.duplicadosVarridos {
                        Empty(titulo: "Nenhuma cópia",
                              detalhe: "Nada acima de 2 MB aparece duplicado nas suas pastas.")
                    }

                    ForEach(grupos) { g in
                        GrupoDuplicado(grupo: g,
                                       marcado: marcados.contains(g.id)) {
                            if marcados.contains(g.id) { marcados.remove(g.id) }
                            else { marcados.insert(g.id) }
                        }
                    }
                }
                .padding(28)
                .padding(.bottom, 60)
            }

            if !marcados.isEmpty {
                HStack(spacing: 14) {
                    Text("\(marcados.count) grupos marcados")
                        .font(.callout).foregroundStyle(.secondary)
                    Text(Fmt.bytes(marcadoTotal))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Spacer()
                    Text("Mantém o original de cada grupo")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Button("Cópias pra Lixeira") {
                        let alvo = grupos.filter { marcados.contains($0.id) }
                        marcados = []
                        Task { await state.limparDuplicados(alvo) }
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
            }
        }
        .task { if !state.duplicadosVarridos { await state.scanDuplicados() } }
    }
}

struct GrupoDuplicado: View {
    let grupo: DupGroup
    let marcado: Bool
    let alternar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: marcado ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(marcado ? Color.accentColor : Color.secondary.opacity(0.5))

                Image(nsImage: NSWorkspace.shared.icon(forFile: grupo.arquivos[0].url.path))
                    .resizable().frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(grupo.arquivos[0].nome)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text("\(grupo.arquivos.count) cópias · \(Fmt.bytes(grupo.tamanhoUnitario)) cada")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(Fmt.bytes(grupo.desperdicio))
                        .font(.body.monospacedDigit())
                    Text("desperdiçados")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .contentShape(Rectangle())
            .onTapGesture(perform: alternar)

            VStack(spacing: 4) {
                ForEach(Array(grupo.arquivos.enumerated()), id: \.element.id) { i, f in
                    HStack(spacing: 8) {
                        Text(i == 0 ? "mantém" : "remove")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background((i == 0 ? T.ok : T.atencao).opacity(0.16), in: Capsule())
                            .foregroundStyle(i == 0 ? T.ok : T.atencao)
                            .frame(width: 58)

                        Text(f.url.deletingLastPathComponent().path
                                .replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer(minLength: 8)

                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([f.url])
                        } label: {
                            Image(systemName: "folder").font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .background(marcado ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: T.cartao))
    }
}
