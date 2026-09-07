import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Espaço")
                    .font(.headline)
                Spacer()
                if state.scanning {
                    ProgressView().controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(Fmt.bytes(state.disk.available))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.disk.isTight ? .red : .primary)

                Text("livres de \(Fmt.bytes(state.disk.totalExibido)) · \(Fmt.pct(state.disk.usedFraction)) usado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DiskBar(fraction: state.disk.usedFraction)
                .frame(height: 8)

            if state.reclaimable > 0 {
                Text("\(Fmt.bytes(state.reclaimable)) de risco zero disponíveis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button {
                Task { await state.limpezaAutomatica() }
            } label: {
                Label("Turbo · \(Config.shared.nivel.titulo.lowercased())", systemImage: "bolt.fill")
            }
            .disabled(state.cleaning || state.scanning || state.reclaimable == 0)

            Divider()

            Button {
                openWindow(id: "principal")
                Task { await state.revisar() }
            } label: {
                Label("Revisar agora", systemImage: "sparkles")
            }
            .disabled(state.revisando || state.cleaning)

            Button("Abrir painel") { openWindow(id: "principal") }
            Button("Medir de novo") { Task { await state.scan() } }
                .disabled(state.scanning)
            Button("Sair") { NSApplication.shared.terminate(nil) }
        }
        .padding(16)
        .frame(width: 260)
    }
}

struct DiskBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: 4)
                    .fill(fraction >= 0.85 ? Color.red : Color.accentColor)
                    .frame(width: max(2, geo.size.width * min(1, fraction)))
            }
        }
    }
}
