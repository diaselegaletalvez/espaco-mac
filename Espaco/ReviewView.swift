import SwiftUI

struct ReviewView: View {
    @Environment(AppState.self) private var state
    @State private var marcados: Set<String> = []

    private var total: Int64 {
        state.achados.filter { marcados.contains($0.id) }.reduce(0) { $0 + $1.tamanho }
    }

    private var potencial: Int64 {
        state.achados.reduce(0) { $0 + $1.tamanho }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {

                    cabecalho

                    if state.revisando {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(state.etapas, id: \.self) { e in
                                HStack(spacing: 9) {
                                    if e == state.etapaAtual {
                                        ProgressView().controlSize(.small)
                                    } else if state.etapasFeitas.contains(e) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.tertiary)
                                    }
                                    Text(e)
                                        .font(.callout)
                                        .foregroundStyle(state.etapasFeitas.contains(e) || e == state.etapaAtual
                                                         ? .primary : .secondary)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.secondary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 9))
                    }

                    if let r = state.lastResult, !r.isEmpty, !state.revisando {
                        ResultBanner(result: r)
                    }

                    if !state.achados.isEmpty {
                        HStack {
                            Text("O que dá pra fazer")
                                .font(.headline)
                            Spacer()
                            Button("Marcar tudo de risco zero") {
                                marcados = Set(state.achados.filter { $0.risco == .zero }.map(\.id))
                            }
                            .buttonStyle(.link)
                        }

                        VStack(spacing: 8) {
                            ForEach(state.achados) { a in
                                AchadoRow(achado: a, marcado: marcados.contains(a.id)) {
                                    if marcados.contains(a.id) { marcados.remove(a.id) }
                                    else { marcados.insert(a.id) }
                                }
                            }
                        }
                    } else if !state.revisando && state.jaRevisou {
                        Empty(titulo: "Nada relevante pra limpar",
                              detalhe: "O disco está enxuto. Roda de novo daqui a alguns dias.")
                    }
                }
                .padding(28)
                .padding(.bottom, 60)
            }

            if !marcados.isEmpty {
                HStack(spacing: 14) {
                    Text("\(marcados.count) marcados")
                        .font(.callout).foregroundStyle(.secondary)
                    Text(Fmt.bytes(total))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Spacer()
                    Button("Executar") {
                        let alvo = state.achados.filter { marcados.contains($0.id) }
                        marcados = []
                        Task { await state.executar(alvo) }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(state.cleaning)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
            }
        }
        .task { if !state.jaRevisou { await state.revisar() } }
    }

    private var cabecalho: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(potencial > 0 ? Fmt.bytes(potencial) : Fmt.bytes(state.disk.available))
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(potencial > 0 ? Color.accentColor : Color.primary)

                Text(potencial > 0
                     ? "podem sair do disco agora"
                     : "livres · nada esperando por você")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("\(Fmt.bytes(state.disk.available)) livres de \(Fmt.bytes(state.disk.totalExibido))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                Task { await state.revisar() }
            } label: {
                Label(state.jaRevisou ? "Revisar de novo" : "Revisar", systemImage: "sparkles")
                    .frame(minWidth: 110)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(state.revisando || state.cleaning)
        }
    }
}

struct AchadoRow: View {
    let achado: Achado
    let marcado: Bool
    let alternar: () -> Void

    private var cor: Color {
        switch achado.risco {
        case .zero: return .green
        case .medio: return .orange
        case .alto: return .red
        }
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: marcado ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(marcado ? Color.accentColor : Color.secondary.opacity(0.5))

            Image(systemName: achado.icone)
                .font(.system(size: 15))
                .foregroundStyle(cor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(achado.titulo).font(.body.weight(.medium))
                Text(achado.detalhe)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(achado.risco.rawValue)
                .font(.caption2)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(cor.opacity(0.18), in: Capsule())
                .foregroundStyle(cor)

            Text(Fmt.bytes(achado.tamanho))
                .font(.body.monospacedDigit())
                .frame(minWidth: 74, alignment: .trailing)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .background(marcado ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture(perform: alternar)
    }
}
