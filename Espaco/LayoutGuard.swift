import SwiftUI

struct AvisoLayout: Identifiable, Hashable {
    let id: String
    let onde: String
    let problema: String
    let detalhe: String
}

@MainActor
@Observable
final class LayoutGuard {
    static let shared = LayoutGuard()
    private init() {}

    var avisos: [AvisoLayout] = []
    var ativo = false

    func registrar(_ aviso: AvisoLayout) {
        guard ativo else { return }
        if !avisos.contains(where: { $0.id == aviso.id }) {
            avisos.append(aviso)
        }
    }

    func limpar() { avisos.removeAll() }

    func alternar() {
        ativo.toggle()
        if !ativo { limpar() }
    }
}

private struct MedidaTexto: ViewModifier {
    let onde: String
    let conteudo: String
    @State private var real: CGSize = .zero
    @State private var ideal: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { real = g.size; avaliar() }
                        .onChange(of: g.size) { _, nova in real = nova; avaliar() }
                }
            )
            .background(
                Text(conteudo)
                    .fixedSize()
                    .hidden()
                    .background(
                        GeometryReader { g in
                            Color.clear
                                .onAppear { ideal = g.size; avaliar() }
                        }
                    )
                    .allowsHitTesting(false)
            )
            .overlay {
                if LayoutGuard.shared.ativo && truncando {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(.red.opacity(0.85), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
    }

    private var truncando: Bool {
        ideal.width > 0 && real.width > 0 && ideal.width > real.width + 1
    }

    private func avaliar() {
        guard truncando else { return }
        LayoutGuard.shared.registrar(
            AvisoLayout(id: "\(onde)-\(conteudo.prefix(30))",
                        onde: onde,
                        problema: "Texto cortado",
                        detalhe: "\"\(conteudo.prefix(46))\" precisa de \(Int(ideal.width))pt e tem \(Int(real.width))pt")
        )
    }
}

private struct MedidaCaixa: ViewModifier {
    let onde: String
    let minimo: CGSize

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { g in
                Color.clear
                    .onAppear { checar(g.size) }
                    .onChange(of: g.size) { _, nova in checar(nova) }
            }
        )
    }

    private func checar(_ s: CGSize) {
        var faltas: [String] = []
        if minimo.width > 0 && s.width < minimo.width {
            faltas.append("largura \(Int(s.width))pt < \(Int(minimo.width))pt")
        }
        if minimo.height > 0 && s.height < minimo.height {
            faltas.append("altura \(Int(s.height))pt < \(Int(minimo.height))pt")
        }
        guard !faltas.isEmpty else { return }
        LayoutGuard.shared.registrar(
            AvisoLayout(id: "caixa-\(onde)",
                        onde: onde,
                        problema: "Espaço insuficiente",
                        detalhe: faltas.joined(separator: " · "))
        )
    }
}

extension View {
    func vigiaTexto(_ onde: String, _ conteudo: String) -> some View {
        modifier(MedidaTexto(onde: onde, conteudo: conteudo))
    }

    func vigiaCaixa(_ onde: String, minimo: CGSize) -> some View {
        modifier(MedidaCaixa(onde: onde, minimo: minimo))
    }
}

struct PainelLayout: View {
    @Bindable var guarda = LayoutGuard.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Guarda de layout", systemImage: "ruler")
                    .font(.headline)
                Spacer()
                Toggle("Ativo", isOn: Binding(get: { guarda.ativo },
                                              set: { _ in guarda.alternar() }))
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            Text("Com a guarda ligada, o app marca em vermelho todo texto que está sendo cortado e lista os problemas aqui. Redimensione a janela pra caçar os pontos que quebram.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if guarda.ativo {
                if guarda.avisos.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(T.ok)
                        Text("Nenhum problema nas telas que você visitou até agora.")
                            .font(.callout)
                    }
                    .padding(.top, 2)
                } else {
                    ForEach(guarda.avisos) { a in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(T.atencao)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(a.onde) · \(a.problema)")
                                    .font(.callout.weight(.medium))
                                Text(a.detalhe)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(T.atencao.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 7))
                    }

                    Button("Limpar lista") { guarda.limpar() }
                        .buttonStyle(.link)
                }
            }
        }
    }
}
