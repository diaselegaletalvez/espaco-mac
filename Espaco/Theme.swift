import SwiftUI

enum T {
    static let acento     = Color(red: 0.42, green: 0.44, blue: 0.96)
    static let acentoSuave = Color(red: 0.42, green: 0.44, blue: 0.96).opacity(0.14)

    static let ok      = Color(red: 0.28, green: 0.74, blue: 0.52)
    static let atencao = Color(red: 0.94, green: 0.66, blue: 0.28)
    static let critico = Color(red: 0.89, green: 0.36, blue: 0.32)

    static func numero(_ tamanho: CGFloat) -> Font {
        .system(size: tamanho, weight: .semibold, design: .rounded)
    }

    static let rotulo = Font.system(size: 11, weight: .medium)
    static let cartao: CGFloat = 10

    static func corRisco(_ r: Risk) -> Color {
        switch r {
        case .zero:  return ok
        case .medio: return atencao
        case .alto:  return critico
        }
    }

    static func corOcupacao(_ f: Double) -> Color {
        if f >= 0.90 { return critico }
        if f >= 0.80 { return atencao }
        return acento
    }
}

struct Cartao<Conteudo: View>: View {
    let titulo: String?
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let t = titulo {
                Text(t)
                    .font(T.rotulo)
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
            }
            conteudo
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: T.cartao))
    }
}

struct Medidor: View {
    let titulo: String
    let valor: String
    let fracao: Double
    let cor: Color
    var nota: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo).font(T.rotulo).foregroundStyle(.secondary)
                Spacer()
                Text(valor)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(cor)
                        .frame(width: max(3, g.size.width * min(1, max(0, fracao))))
                }
            }
            .frame(height: 6)

            if let n = nota {
                Text(n).font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}
