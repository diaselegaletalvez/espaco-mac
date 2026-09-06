import SwiftUI
import AppKit

struct AutomationView: View {
    @Environment(AppState.self) private var state
    @State private var hora = 0
    @State private var minuto = 0
    @State private var salvando = false
    @State private var copiado: String?

    private var e: EstadoAgenda { state.agenda }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                cabecalho
                agendamento
                aparencia
                Divider().padding(.vertical, 4)
                manual
            }
            .padding(28)
        }
        .task {
            await state.carregarAgenda()
            hora = state.agenda.hora
            minuto = state.agenda.minuto
        }
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Automação")
                .font(T.numero(30))
            Text("O relatório diário roda sozinho, mede tudo, limpa o que é risco zero e guarda um histórico em ~/Relatorios.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var agendamento: some View {
        Cartao(titulo: "Relatório diário") {
            HStack(spacing: 10) {
                Image(systemName: e.tudoCerto ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(e.tudoCerto ? T.ok : T.atencao)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(e.tudoCerto ? "Ativo, roda às \(e.horarioTexto)" : "Não está ativo")
                        .font(.body.weight(.medium))
                    Text(descricaoEstado)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Text("Horário")
                    .font(T.rotulo)
                    .foregroundStyle(.secondary)

                Picker("", selection: $hora) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .labelsHidden()
                .frame(width: 64)

                Text(":")

                Picker("", selection: $minuto) {
                    ForEach([0, 15, 30, 45], id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .labelsHidden()
                .frame(width: 64)

                Button(e.agenteCarregado ? "Atualizar" : "Ativar") {
                    salvando = true
                    Task {
                        await state.salvarAgenda(hora: hora, minuto: minuto)
                        salvando = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(salvando || !e.scriptExiste)

                if e.agenteCarregado {
                    Button("Desativar") {
                        Task { await state.desativarAgenda() }
                    }
                }

                Spacer()
            }
            .padding(.top, 4)

            HStack(spacing: 12) {
                Button("Rodar agora") {
                    Task { await state.rodarAgendaAgora() }
                }
                .disabled(!e.tudoCerto)

                Button("Abrir pasta dos relatórios") {
                    NSWorkspace.shared.open(Automation.relatorios)
                }

                Spacer()
            }

            if !e.scriptExiste {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "info.circle").foregroundStyle(T.atencao)
                    Text("O script ~/bin/mac-report.sh não está instalado. Sem ele o agendamento não tem o que rodar.")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(11)
                .background(T.atencao.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            }
        }
    }

    private var descricaoEstado: String {
        var partes: [String] = []
        partes.append(e.scriptExiste ? "script instalado" : "script ausente")
        partes.append(e.agenteCarregado ? "agendamento carregado" : "agendamento parado")
        if e.totalRelatorios > 0 {
            partes.append("\(e.totalRelatorios) relatórios guardados")
        }
        return partes.joined(separator: " · ")
    }

    private var aparencia: some View {
        Cartao(titulo: "Aparência") {
            HStack {
                SeletorTema()
                Spacer()
            }
            PainelLayout()
                .padding(.top, 6)
        }
    }

    private var manual: some View {
        ManualView()
    }
}

struct CartaoComando: View {
    let comando: ComandoManual
    let copiado: Bool
    let copiar: () -> Void

    @State private var aberto = false
    @State private var rodando = false
    @State private var saida: SaidaComando?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Text(comando.rotuloNumero)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(T.corRisco(comando.risco))
                    .frame(width: 22, height: 22)
                    .background(T.corRisco(comando.risco).opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(comando.titulo)
                        .font(.body.weight(.medium))
                    Text(comando.porque)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(aberto ? nil : 1)
                        .fixedSize(horizontal: false, vertical: aberto)
                }

                Spacer(minLength: 10)

                if comando.ganhoTipico != "\u{2014}" {
                    Text(comando.ganhoTipico)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Image(systemName: aberto ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .contentShape(Rectangle())
            .onTapGesture { aberto.toggle() }

            if aberto {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(comando.comando)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(11)
                    }
                    .background(Color.black.opacity(0.28),
                                in: RoundedRectangle(cornerRadius: 6))

                    HStack(spacing: 8) {
                        if comando.precisaSudo {
                            Button {
                                Automation.abrirNoTerminal(comando)
                            } label: {
                                Label("Abrir no Terminal", systemImage: "terminal")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        } else {
                            Button {
                                rodando = true
                                saida = nil
                                let c = comando
                                Task {
                                    let r = await Task.detached(priority: .userInitiated) {
                                        Automation.executar(c)
                                    }.value
                                    saida = r
                                    rodando = false
                                }
                            } label: {
                                if rodando {
                                    HStack(spacing: 6) {
                                        ProgressView().controlSize(.small)
                                        Text("Rodando...")
                                    }
                                } else {
                                    Label(comando.soLista ? "Rodar diagn\u{00F3}stico" : "Rodar agora",
                                          systemImage: "play.fill")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(rodando)

                            Button {
                                Automation.abrirNoTerminal(comando)
                            } label: {
                                Image(systemName: "terminal")
                            }
                            .controlSize(.small)
                            .help("Abrir no Terminal em vez de rodar aqui")
                        }

                        Button {
                            copiar()
                        } label: {
                            Label(copiado ? "Copiado" : "Copiar",
                                  systemImage: copiado ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        Text(comando.risco.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(T.corRisco(comando.risco).opacity(0.18), in: Capsule())
                            .foregroundStyle(T.corRisco(comando.risco))
                    }

                    if comando.precisaSudo {
                        Text("Precisa de senha de administrador, ent\u{00E3}o roda no Terminal e n\u{00E3}o aqui dentro.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if let s = saida {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Image(systemName: s.sucesso ? "checkmark.circle.fill"
                                                            : "exclamationmark.triangle.fill")
                                    .foregroundStyle(s.sucesso ? T.ok : T.atencao)
                                Text(s.sucesso ? "Conclu\u{00ED}do" : "Terminou com erro")
                                    .font(.caption.weight(.medium))
                                Spacer()
                                Button("Ocultar") { saida = nil }
                                    .buttonStyle(.link)
                                    .font(.caption)
                            }
                            ScrollView {
                                Text(s.texto)
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(9)
                            }
                            .frame(maxHeight: 190)
                            .background(Color.black.opacity(0.28),
                                        in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(.horizontal, 13)
                .padding(.bottom, 13)
            }
        }
        .background(Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: T.cartao))
    }
}
