import SwiftUI
import AppKit

struct ExplorerView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            barra
            Divider()

            if state.varrendo {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Varrendo a sua pasta pessoal…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Primeira vez demora um pouco. Depois fica em cache.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let atual = state.noAtual, !atual.filhos.isEmpty {
                TreemapView(raiz: atual) { state.entrar($0) }
                    .padding(10)
                Divider()
                legenda

            } else {
                VStack(spacing: 14) {
                    Text("Mapa do disco")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("Uma varredura mostra onde os gigabytes realmente estão,\nincluindo o que nenhuma lista de categorias prevê.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Varrer minha pasta pessoal") {
                        Task { await state.varrer() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var barra: some View {
        HStack(spacing: 8) {
            Button {
                state.subir()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(state.pilha.count <= 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(state.pilha.enumerated()), id: \.offset) { i, n in
                        Button(n.nome.isEmpty ? "início" : n.nome) {
                            state.irPara(indice: i)
                        }
                        .buttonStyle(.link)
                        .font(.callout.weight(i == state.pilha.count - 1 ? .semibold : .regular))

                        if i < state.pilha.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Spacer(minLength: 12)

            if let n = state.noAtual {
                Text(Fmt.bytes(n.tamanho))
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .monospacedDigit()

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([n.url])
                } label: {
                    Image(systemName: "folder")
                }
                .help("Revelar no Finder")
            }

            Button {
                Task { await state.varrer() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(state.varrendo)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var legenda: some View {
        HStack(spacing: 14) {
            ForEach(Categoria.allCases, id: \.self) { c in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(c.cor.opacity(0.8))
                        .frame(width: 9, height: 9)
                    Text(c.rotulo)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
