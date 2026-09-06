import SwiftUI
import AppKit

struct MyMacView: View {
    @Environment(AppState.self) private var state

    private var i: InfoMac { state.info }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                HStack(spacing: 18) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app"))
                        .resizable()
                        .frame(width: 62, height: 62)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(i.hostname.isEmpty ? "Este Mac" : i.hostname)
                            .font(T.numero(28))
                        Text(i.modeloNome)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("\(i.macOSNome) \(i.macOSVersao) · build \(i.macOSBuild)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Button {
                        copiarResumo()
                    } label: {
                        Label("Copiar resumo", systemImage: "doc.on.doc")
                    }
                }
                .padding(.bottom, 4)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)],
                          spacing: 14) {

                    Cartao(titulo: "Processador") {
                        linha(i.chip.isEmpty ? "—" : i.chip, grande: true)
                        linha(i.resumoNucleos)
                        linha("Arquitetura \(i.arquitetura)")
                    }

                    Cartao(titulo: "Memória") {
                        linha(Fmt.bytes(i.ram), grande: true)
                        linha("\(Fmt.bytes(state.saude.ramUsada)) em uso agora")
                        linha("\(Fmt.bytes(state.saude.ramComprimida)) comprimidos")
                    }

                    Cartao(titulo: "Armazenamento") {
                        linha(Fmt.bytes(i.discoLivre) + " livres", grande: true)
                        linha("de \(Fmt.bytes(i.discoTotal))")
                        Medidor(titulo: "ocupado",
                                valor: Fmt.pct(state.disk.usedFraction),
                                fracao: state.disk.usedFraction,
                                cor: T.corOcupacao(state.disk.usedFraction))
                            .padding(.top, 2)
                    }

                    Cartao(titulo: "Bateria") {
                        if let p = state.saude.bateriaPct {
                            linha("\(p)%", grande: true)
                            if let s = state.saude.bateriaSaude {
                                linha("Capacidade máxima \(s)%")
                            }
                            if let c = state.saude.bateriaCiclos {
                                linha("\(c) ciclos")
                            }
                        } else {
                            linha("Sem bateria", grande: true)
                        }
                    }

                    Cartao(titulo: "Rede") {
                        linha(i.ipLocal.isEmpty ? "Desconectado" : i.ipLocal, grande: true)
                        linha("Nome local: \(i.hostname)")
                    }

                    Cartao(titulo: "Identificação") {
                        linha(i.modeloID, grande: true)
                        linha("Série \(i.serialMascarado)")
                        linha("Ligado desde \(i.ligadoDesde.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
            }
            .padding(28)
        }
        .task {
            await state.carregarInfo()
            await state.atualizarSaude()
        }
    }

    private func linha(_ texto: String, grande: Bool = false) -> some View {
        Text(texto)
            .font(grande ? .system(size: 17, weight: .semibold, design: .rounded)
                         : .callout)
            .foregroundStyle(grande ? .primary : .secondary)
            .monospacedDigit()
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copiarResumo() {
        let texto = """
        \(i.hostname) · \(i.modeloNome) (\(i.modeloID))
        \(i.macOSNome) \(i.macOSVersao) (\(i.macOSBuild))
        \(i.chip) · \(i.resumoNucleos)
        Memória: \(Fmt.bytes(i.ram))
        Disco: \(Fmt.bytes(i.discoLivre)) livres de \(Fmt.bytes(i.discoTotal))
        Bateria: \(state.saude.bateriaPct.map { "\($0)%" } ?? "—")\(state.saude.bateriaSaude.map { " · capacidade \($0)%" } ?? "")\(state.saude.bateriaCiclos.map { " · \($0) ciclos" } ?? "")
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(texto, forType: .string)
    }
}
