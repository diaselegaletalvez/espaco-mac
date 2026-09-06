import SwiftUI
import AppKit

struct ManualView: View {
    @Environment(AppState.self) private var state
    var comoJanela = false
    var fechar: (() -> Void)?

    @State private var copiado: String?
    @State private var busca = ""

    private var fonte: [ComandoManual] {
        state.manual.isEmpty ? Automation.manual : state.manual
    }

    private var filtrados: [ComandoManual] {
        guard !busca.isEmpty else { return fonte }
        let t = busca.lowercased()
        return fonte.filter {
            $0.titulo.lowercased().contains(t)
            || $0.porque.lowercased().contains(t)
            || $0.comando.lowercased().contains(t)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if comoJanela {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manual")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                        Text(state.perfilMaquina.levantadoEm == nil
                             ? "Tudo que o Espaço faz por botão, aqui em comando de terminal."
                             : state.perfilMaquina.descricao)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Fechar") { fechar?() }
                        .keyboardShortcut(.cancelAction)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 14)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField("Procurar comando", text: $busca)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 7))
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

                Divider()
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manual")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text(state.perfilMaquina.levantadoEm == nil
                         ? "O que o app faz por botão, aqui está por comando."
                         : "\(state.perfilMaquina.descricao) Os blocos abaixo foram montados com os caminhos e tamanhos reais desta máquina — o que não existe aqui não aparece.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 14)
            }

            if state.montandoManual {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    Text("Medindo esta máquina pra montar o manual…")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .padding(comoJanela ? 24 : 0)
                .padding(.bottom, 8)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(filtrados) { c in
                        CartaoComando(comando: c, copiado: copiado == c.id) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(c.comando, forType: .string)
                            copiado = c.id
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                if copiado == c.id { copiado = nil }
                            }
                        }
                    }

                    if filtrados.isEmpty {
                        Text("Nenhum comando com \"\(busca)\".")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                }
                .padding(comoJanela ? 24 : 0)
            }
        }
        .frame(minWidth: comoJanela ? 620 : nil,
               minHeight: comoJanela ? 520 : nil)
        .task { if state.manual.isEmpty { await state.montarManual() } }
    }
}
