import SwiftUI

struct Tile: Identifiable {
    let id: UUID
    let node: Node
    let rect: CGRect
}

enum Squarify {
    static func layout(_ nodes: [Node], in bounds: CGRect) -> [Tile] {
        let total = nodes.reduce(Int64(0)) { $0 + $1.tamanho }
        guard total > 0, !nodes.isEmpty else { return [] }

        var tiles: [Tile] = []
        var restantes = nodes
        var area = bounds
        let escala = Double(area.width * area.height) / Double(total)

        while !restantes.isEmpty {
            let horizontal = area.width >= area.height
            let lado = horizontal ? area.height : area.width
            guard lado > 1 else { break }

            var fila: [Node] = []
            var melhor = Double.greatestFiniteMagnitude

            for n in restantes {
                let tentativa = fila + [n]
                let r = pior(tentativa, lado: Double(lado), escala: escala)
                if r > melhor { break }
                melhor = r
                fila = tentativa
            }

            if fila.isEmpty { fila = [restantes[0]] }

            let somaFila = fila.reduce(Int64(0)) { $0 + $1.tamanho }
            let espessura = (Double(somaFila) * escala) / Double(lado)

            var offset: CGFloat = horizontal ? area.minY : area.minX

            for n in fila {
                let fracao = Double(n.tamanho) / Double(somaFila)
                let comprimento = Double(lado) * fracao
                let r: CGRect = horizontal
                    ? CGRect(x: area.minX, y: offset, width: espessura, height: comprimento)
                    : CGRect(x: offset, y: area.minY, width: comprimento, height: espessura)
                tiles.append(Tile(id: n.id, node: n, rect: r))
                offset += comprimento
            }

            if horizontal {
                area = CGRect(x: area.minX + espessura, y: area.minY,
                              width: max(0, area.width - espessura), height: area.height)
            } else {
                area = CGRect(x: area.minX, y: area.minY + espessura,
                              width: area.width, height: max(0, area.height - espessura))
            }

            restantes.removeFirst(fila.count)
        }
        return tiles
    }

    private static func pior(_ fila: [Node], lado: Double, escala: Double) -> Double {
        let areas = fila.map { Double($0.tamanho) * escala }
        guard let mn = areas.min(), let mx = areas.max() else { return .greatestFiniteMagnitude }
        let soma = areas.reduce(0, +)
        guard soma > 0, mn > 0 else { return .greatestFiniteMagnitude }
        let l2 = lado * lado
        let s2 = soma * soma
        return max(l2 * mx / s2, s2 / (l2 * mn))
    }
}

extension Categoria {
    var cor: Color {
        switch self {
        case .codigo:    return Color(red: 0.36, green: 0.62, blue: 0.92)
        case .midia:     return Color(red: 0.85, green: 0.44, blue: 0.55)
        case .cache:     return Color(red: 0.95, green: 0.68, blue: 0.30)
        case .app:       return Color(red: 0.47, green: 0.78, blue: 0.55)
        case .sistema:   return Color(red: 0.58, green: 0.55, blue: 0.85)
        case .documento: return Color(red: 0.40, green: 0.76, blue: 0.79)
        case .arquivo:   return Color(red: 0.90, green: 0.55, blue: 0.38)
        case .outro:     return Color(red: 0.55, green: 0.58, blue: 0.62)
        }
    }
}

struct TreemapView: View {
    let raiz: Node
    let aoEntrar: (Node) -> Void
    @State private var hover: UUID?

    var body: some View {
        GeometryReader { geo in
            let tiles = Squarify.layout(raiz.filhos,
                                        in: CGRect(origin: .zero, size: geo.size))
            ZStack(alignment: .topLeading) {
                ForEach(tiles) { t in
                    let ativo = hover == t.id
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(t.node.categoria.cor.opacity(ativo ? 0.95 : 0.72))

                        if t.rect.width > 62 && t.rect.height > 30 {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t.node.nome)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                                Text(Fmt.bytes(t.node.tamanho))
                                    .font(.system(size: 10, design: .rounded))
                                    .monospacedDigit()
                                    .opacity(0.85)
                            }
                            .foregroundStyle(.black.opacity(0.78))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 5)
                        }
                    }
                    .frame(width: max(0, t.rect.width - 2),
                           height: max(0, t.rect.height - 2))
                    .offset(x: t.rect.minX + 1, y: t.rect.minY + 1)
                    .overlay(alignment: .topLeading) {
                        if ativo {
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(.white.opacity(0.9), lineWidth: 1.5)
                                .frame(width: max(0, t.rect.width - 2),
                                       height: max(0, t.rect.height - 2))
                                .offset(x: t.rect.minX + 1, y: t.rect.minY + 1)
                        }
                    }
                    .onHover { hover = $0 ? t.id : nil }
                    .onTapGesture {
                        if t.node.ehPasta && !t.node.filhos.isEmpty { aoEntrar(t.node) }
                    }
                    .help("\(t.node.nome) · \(Fmt.bytes(t.node.tamanho))")
                }
            }
        }
    }
}
