import SwiftUI

struct HealthView: View {
    @Environment(AppState.self) private var state

    private var s: SaudeMac { state.saude }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ligado há \(s.uptimeTexto)")
                            .font(T.numero(30))
                        Text(recomendacao)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await state.atualizarSaude() }
                    } label: {
                        Label("Atualizar", systemImage: "arrow.clockwise")
                    }
                }

                HStack(spacing: 14) {
                    Cartao(titulo: "Memória") {
                        Medidor(titulo: "em uso",
                                valor: Fmt.bytes(s.ramUsada),
                                fracao: s.ramFracao,
                                cor: T.corOcupacao(s.ramFracao),
                                nota: "\(Fmt.bytes(s.ramTotal)) no total · \(Fmt.bytes(s.ramComprimida)) comprimidos")
                    }

                    Cartao(titulo: "Processador") {
                        Medidor(titulo: "carga",
                                valor: Fmt.pct(s.cpuUso),
                                fracao: s.cpuUso,
                                cor: T.corOcupacao(s.cpuUso),
                                nota: "\(ProcessInfo.processInfo.activeProcessorCount) núcleos")
                    }
                }

                if let pct = s.bateriaPct {
                    Cartao(titulo: "Bateria") {
                        HStack(spacing: 26) {
                            Medidor(titulo: s.carregando ? "carregando" : "carga",
                                    valor: "\(pct)%",
                                    fracao: Double(pct) / 100,
                                    cor: pct < 20 ? T.critico : T.ok)
                                .frame(maxWidth: 260)

                            if let saude = s.bateriaSaude {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Capacidade máxima").font(T.rotulo).foregroundStyle(.secondary)
                                    Text("\(saude)%")
                                        .font(T.numero(20)).monospacedDigit()
                                        .foregroundStyle(saude < 80 ? T.atencao : .primary)
                                }
                            }

                            if let c = s.bateriaCiclos {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Ciclos").font(T.rotulo).foregroundStyle(.secondary)
                                    Text("\(c)").font(T.numero(20)).monospacedDigit()
                                }
                            }
                            Spacer()
                        }
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    Cartao(titulo: "Mais usam CPU") {
                        listaProcessos(s.topCPU) { "\(String(format: "%.1f", $0.cpu))%" }
                    }
                    Cartao(titulo: "Mais usam memória") {
                        listaProcessos(s.topRAM) { "\(String(format: "%.1f", $0.ram))%" }
                    }
                }
            }
            .padding(28)
        }
        .task { await state.atualizarSaude() }
    }

    private var recomendacao: String {
        if s.ramFracao > 0.90 { return "Memória no limite — fechar abas do Chrome ajuda mais que reiniciar." }
        if s.uptime > 7 * 86400 { return "Uma semana sem reiniciar. Vale um restart pra limpar a memória." }
        if let saude = s.bateriaSaude, saude < 80 { return "Bateria abaixo de 80% de capacidade — troca já é justificável." }
        if s.cpuUso > 0.75 { return "Alguém está comendo CPU. Confere a lista abaixo." }
        return "Tudo dentro do normal."
    }

    private func listaProcessos(_ lista: [Processo],
                                _ valor: @escaping (Processo) -> String) -> some View {
        VStack(spacing: 7) {
            ForEach(lista) { p in
                HStack {
                    Text(p.nome)
                        .font(.callout)
                        .lineLimit(1)
                    Spacer(minLength: 10)
                    Text(valor(p))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if lista.isEmpty {
                Text("—").foregroundStyle(.tertiary)
            }
        }
    }
}
