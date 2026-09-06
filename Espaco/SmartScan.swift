import Foundation

enum AcaoAchado: Sendable {
    case categoria(Target)
    case residuos(InstalledApp)
    case arquivos([BigFile])
    case projeto(ProjectInfo)
    case duplicados([DupGroup])
}

struct Achado: Identifiable, Sendable {
    let id: String
    let titulo: String
    let detalhe: String
    let tamanho: Int64
    let risco: Risk
    let icone: String
    let acao: AcaoAchado
}

enum SmartScan {

    static func montar(targets: [Target],
                       apps: [InstalledApp],
                       grandes: [BigFile],
                       projetos: [ProjectInfo],
                       duplicados: [DupGroup]) -> [Achado] {

        var out: [Achado] = []

        for t in targets where t.size > 20_000_000 {
            out.append(Achado(id: "cat-\(t.id)",
                              titulo: t.name,
                              detalhe: t.loss,
                              tamanho: t.size,
                              risco: t.risk,
                              icone: t.risk == .zero ? "trash" : "archivebox",
                              acao: .categoria(t)))
        }

        for a in apps where !a.daSystem && a.tamanhoResiduos > 50_000_000 {
            out.append(Achado(id: "res-\(a.id)",
                              titulo: "Resíduos de \(a.nome)",
                              detalhe: "\(a.residuos.count) pastas espalhadas no Library · \(a.descricaoUso)",
                              tamanho: a.tamanhoResiduos,
                              risco: a.esquecido ? .zero : .medio,
                              icone: "square.stack.3d.up.slash",
                              acao: .residuos(a)))
        }

        let instaladores = grandes.filter { $0.instalador && $0.esquecido }
        if !instaladores.isEmpty {
            let soma = instaladores.reduce(Int64(0)) { $0 + $1.tamanho }
            out.append(Achado(id: "instaladores",
                              titulo: "\(instaladores.count) instaladores já usados",
                              detalhe: instaladores.prefix(3).map(\.nome).joined(separator: ", "),
                              tamanho: soma,
                              risco: .zero,
                              icone: "shippingbox",
                              acao: .arquivos(instaladores)))
        }

        for p in projetos where p.dormente {
            out.append(Achado(id: "proj-\(p.id)",
                              titulo: "\(p.nome): dependências",
                              detalhe: "\(p.descricaoTempo) · volta com npm install",
                              tamanho: p.peso,
                              risco: .medio,
                              icone: "folder.badge.minus",
                              acao: .projeto(p)))
        }

        let dupsRelevantes = duplicados.filter { $0.desperdicio > 10_000_000 }
        if !dupsRelevantes.isEmpty {
            let soma = dupsRelevantes.reduce(Int64(0)) { $0 + $1.desperdicio }
            out.append(Achado(id: "duplicados",
                              titulo: "\(dupsRelevantes.count) grupos de arquivos idênticos",
                              detalhe: "Mantém o primeiro de cada grupo, remove as cópias",
                              tamanho: soma,
                              risco: .medio,
                              icone: "doc.on.doc",
                              acao: .duplicados(dupsRelevantes)))
        }

        return out.sorted { $0.tamanho > $1.tamanho }
    }
}
