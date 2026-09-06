import SwiftUI

enum Secao: String, CaseIterable, Identifiable, Hashable {
    case revisao = "Revisão"
    case painel = "Painel"
    case mapa = "Mapa"

    case apps = "Apps"
    case esquecidos = "Esquecidos"
    case projetos = "Projetos"
    case duplicados = "Duplicados"

    case protecao = "Proteção"
    case saude = "Saúde"
    case meumac = "Meu Mac"

    case relatorios = "Relatórios"
    case automacao = "Automação"

    var id: String { rawValue }

    var icone: String {
        switch self {
        case .revisao:    return "sparkles"
        case .painel:     return "internaldrive"
        case .mapa:       return "square.grid.3x3.fill"
        case .apps:       return "square.stack.3d.up"
        case .esquecidos: return "clock.badge.exclamationmark"
        case .projetos:   return "folder"
        case .duplicados: return "doc.on.doc"
        case .protecao:   return "shield.lefthalf.filled"
        case .saude:      return "heart.text.square"
        case .meumac:     return "laptopcomputer"
        case .relatorios: return "calendar"
        case .automacao:  return "gearshape.2"
        }
    }
}

enum Grupo: String, CaseIterable, Identifiable {
    case comecar = "Começar"
    case limpar = "Limpar"
    case cuidar = "Cuidar"
    case acompanhar = "Acompanhar"

    var id: String { rawValue }

    var secoes: [Secao] {
        switch self {
        case .comecar:    return [.revisao, .painel, .mapa]
        case .limpar:     return [.apps, .esquecidos, .projetos, .duplicados]
        case .cuidar:     return [.protecao, .saude, .meumac]
        case .acompanhar: return [.relatorios, .automacao]
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var state
    @State private var secao: Secao = .revisao
    @State private var mostrarManual = false

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $secao) {
                    ForEach(Grupo.allCases) { g in
                        Section(g.rawValue) {
                            ForEach(g.secoes) { s in
                                Label {
                                    HStack(spacing: 6) {
                                        Text(s.rawValue)
                                        if s == .protecao, state.seguranca.gravidadeGeral != .ok,
                                           state.seguranca.analisadoEm != nil {
                                            Circle()
                                                .fill(state.seguranca.gravidadeGeral == .alerta
                                                      ? T.critico : T.atencao)
                                                .frame(width: 6, height: 6)
                                        }
                                    }
                                } icon: {
                                    Image(systemName: s.icone)
                                }
                                .tag(s)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)

                Divider()

                HStack(spacing: 4) {
                    SeletorTemaCompacto()

                    Button {
                        mostrarManual = true
                    } label: {
                        Image(systemName: "book")
                    }
                    .buttonStyle(.borderless)
                    .help("Manual de comandos (⌘⇧M)")
                    .keyboardShortcut("m", modifiers: [.command, .shift])

                    Spacer()

                    Text("Espaço")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .navigationSplitViewColumnWidth(min: 172, ideal: 188, max: 230)
        } detail: {
            switch secao {
            case .revisao:    ReviewView()
            case .painel:     DashboardView()
            case .mapa:       ExplorerView()
            case .apps:       AppsView()
            case .esquecidos: ForgottenView()
            case .projetos:   ProjectsView()
            case .duplicados: DuplicatesView()
            case .protecao:   ProtectionView()
            case .saude:      HealthView()
            case .meumac:     MyMacView()
            case .relatorios: ReportsView()
            case .automacao:  AutomationView()
            }
        }
        .sheet(isPresented: $mostrarManual) {
            ManualView(comoJanela: true) { mostrarManual = false }
        }
    }
}
