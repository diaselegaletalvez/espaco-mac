import SwiftUI

@main
struct EspacoApp: App {
    @State private var state = AppState()

    var body: some Scene {
        Window("Espaço", id: "principal") {
            RootView()
                .environment(state)
                .frame(minWidth: 860, idealWidth: 1020, minHeight: 560, idealHeight: 700)
                .task {
                    Notifier.pedirPermissao()
                    Aparencia.shared.aplicar()
                    Vigia.shared.ligar(state)
                    ServidorLocal.shared.conectar(state)
                    if !Pareamento.shared.dispositivos.isEmpty {
                        ServidorLocal.shared.ligar()
                    }
                    await Updater.shared.checarSePassouODia()
                    await state.scan()
                }
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarView()
                .environment(state)
        } label: {
            Text(state.disk.total > 0 ? Fmt.bytes(state.disk.available) : "—")
        }
        .menuBarExtraStyle(.window)
    }
}
