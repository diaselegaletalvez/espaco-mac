import SwiftUI
import AppKit

enum Tema: String, CaseIterable, Identifiable {
    case sistema, claro, escuro
    var id: String { rawValue }

    var rotulo: String {
        switch self {
        case .sistema: return "Sistema"
        case .claro:   return "Claro"
        case .escuro:  return "Escuro"
        }
    }

    var icone: String {
        switch self {
        case .sistema: return "circle.lefthalf.filled"
        case .claro:   return "sun.max"
        case .escuro:  return "moon"
        }
    }

    var esquema: ColorScheme? {
        switch self {
        case .sistema: return nil
        case .claro:   return .light
        case .escuro:  return .dark
        }
    }

    var aparenciaNS: NSAppearance? {
        switch self {
        case .sistema: return nil
        case .claro:   return NSAppearance(named: .aqua)
        case .escuro:  return NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
@Observable
final class Aparencia {
    static let shared = Aparencia()

    private let chave = "espaco.tema"

    var tema: Tema {
        didSet {
            UserDefaults.standard.set(tema.rawValue, forKey: chave)
            aplicar()
        }
    }

    private init() {
        let salvo = UserDefaults.standard.string(forKey: chave) ?? Tema.sistema.rawValue
        tema = Tema(rawValue: salvo) ?? .sistema
        aplicar()
    }

    func aplicar() {
        NSApp?.appearance = tema.aparenciaNS
    }
}

struct SeletorTema: View {
    @Bindable var aparencia = Aparencia.shared

    var body: some View {
        Picker("", selection: $aparencia.tema) {
            ForEach(Tema.allCases) { t in
                Label(t.rotulo, systemImage: t.icone).tag(t)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 210)
    }
}

struct SeletorTemaCompacto: View {
    @Bindable var aparencia = Aparencia.shared

    var body: some View {
        Menu {
            ForEach(Tema.allCases) { t in
                Button {
                    aparencia.tema = t
                } label: {
                    Label(t.rotulo, systemImage: t.icone)
                }
            }
        } label: {
            Image(systemName: aparencia.tema.icone)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Aparência: \(aparencia.tema.rotulo)")
    }
}
