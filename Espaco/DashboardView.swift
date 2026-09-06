import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.bytes(state.disk.available))
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("livres")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            Task { await state.scan() }
                        } label: {
                            Label("Medir de novo", systemImage: "arrow.clockwise")
                        }
                        .disabled(state.scanning || state.cleaning)
                    }

                    DiskBar(fraction: state.disk.usedFraction)
                        .frame(height: 12)

                    HStack {
                        Text("\(Fmt.bytes(state.disk.used)) usados de \(Fmt.bytes(state.disk.totalExibido))")
                        Spacer()
                        Text(Fmt.pct(state.disk.usedFraction))
                    }
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                }

                TrendChart(points: state.history)
                    .padding(.top, 4)

                if state.scanning || state.cleaning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(state.cleaning
                             ? "Limpando \(state.cleaningLabel)…"
                             : "Medindo as pastas…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                if let r = state.lastResult, !r.isEmpty {
                    ResultBanner(result: r)
                }

                HStack(spacing: 10) {
                    Text("Categorias")
                        .font(.headline)
                    Spacer()
                    Button("Marcar risco zero") { state.selectSafeOnly() }
                        .buttonStyle(.link)
                        .disabled(state.scanning || state.cleaning)
                }

                VStack(spacing: 8) {
                    ForEach(state.targets) { t in
                        TargetRow(
                            target: t,
                            selected: state.selection.contains(t.id),
                            enabled: t.size > 0 && !state.cleaning && !state.scanning
                        ) {
                            state.toggle(t.id)
                        }
                    }
                }

                if let d = state.lastScan {
                    Text("Última medição: \(d.formatted(date: .omitted, time: .standard))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(28)
            .padding(.bottom, 70)
        }
        .safeAreaInset(edge: .bottom) {
            CleanBar()
        }
        .alert("Limpar \(Fmt.bytes(state.selectedSize))?", isPresented: $state.showConfirm) {
            Button("Cancelar", role: .cancel) { }
            Button("Limpar", role: .destructive) {
                Task { await state.cleanSelected() }
            }
        } message: {
            Text(confirmMessage)
        }
    }

    private var confirmMessage: String {
        switch state.selectedRiskiest {
        case .zero:
            return "Tudo que você marcou é cache e se regenera sozinho. Vai ser apagado direto."
        case .medio:
            return "Tem item de risco médio na seleção. Esses vão pra Lixeira, dá pra voltar atrás até você esvaziá-la."
        case .alto:
            return "Tem item de risco ALTO na seleção — Archives têm os dSYMs dos builds publicados. Vai tudo pra Lixeira, mas confira antes de esvaziar."
        }
    }
}

struct CleanBar: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        HStack(spacing: 14) {
            if state.selection.isEmpty {
                Text(state.reclaimable > 0
                     ? "\(Fmt.bytes(state.reclaimable)) de risco zero disponíveis"
                     : "Nada pra limpar por enquanto")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(state.selection.count) selecionados")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(Fmt.bytes(state.selectedSize))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
            }

            Spacer()

            Button {
                state.showConfirm = true
            } label: {
                Text("Limpar selecionados")
                    .frame(minWidth: 140)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!state.canClean)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

struct ResultBanner: View {
    let result: CleanResult

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                Text("Liberou \(Fmt.bytes(result.freed))")
                    .font(.body.weight(.medium))

                var detail: String {
                    var parts: [String] = []
                    if result.itemsRemoved > 0 { parts.append("\(result.itemsRemoved) apagados") }
                    if result.itemsTrashed > 0 { parts.append("\(result.itemsTrashed) na Lixeira") }
                    if !result.failures.isEmpty { parts.append("\(result.failures.count) sem permissão") }
                    return parts.joined(separator: " · ")
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
    }
}

struct TargetRow: View {
    let target: Target
    let selected: Bool
    let enabled: Bool
    let onTap: () -> Void

    private var color: Color {
        switch target.risk {
        case .zero:  return .green
        case .medio: return .orange
        case .alto:  return .red
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.5))

            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(target.name)
                    .font(.body.weight(.medium))
                Text(target.loss)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(target.measured ? Fmt.bytes(target.size) : "—")
                .font(.body.monospacedDigit())
                .foregroundStyle(target.size > 0 ? .primary : .secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(selected ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { if enabled { onTap() } }
        .opacity(enabled ? 1 : 0.45)
    }
}
