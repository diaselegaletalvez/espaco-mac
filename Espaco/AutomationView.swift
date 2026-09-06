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
                CartaoAtualizacao()
                CartaoVigilancia()
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


struct CartaoAtualizacao: View {
    @Bindable private var up = Updater.shared

    var body: some View {
        Cartao(titulo: "Atualizações") {
            HStack(spacing: 11) {
                Image(systemName: icone)
                    .font(.title3)
                    .foregroundStyle(cor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo).font(.body.weight(.medium))
                    Text(detalhe)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                acao
            }

            if case .baixando(let p) = up.estado {
                ProgressView(value: p).progressViewStyle(.linear)
            }

            Toggle("Checar automaticamente uma vez por dia", isOn: $up.checarAutomaticamente)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.callout)
                .padding(.top, 2)

            if let v = up.disponivel, !v.notas.isEmpty {
                DisclosureGroup("O que mudou na \(v.versao)") {
                    Text(v.notas)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
                .font(.callout)
            }
        }
    }

    private var icone: String {
        switch up.estado {
        case .atualizado: return "checkmark.circle.fill"
        case .disponivel: return "arrow.down.circle.fill"
        case .erro:       return "exclamationmark.triangle.fill"
        case .pronto:     return "checkmark.circle.fill"
        default:          return "arrow.triangle.2.circlepath"
        }
    }

    private var cor: Color {
        switch up.estado {
        case .atualizado, .pronto: return T.ok
        case .disponivel:          return Color.accentColor
        case .erro:                return T.atencao
        default:                   return .secondary
        }
    }

    private var titulo: String {
        switch up.estado {
        case .ocioso:      return "Espaço \(up.versaoAtual)"
        case .checando:    return "Procurando versão nova…"
        case .atualizado:  return "Você está na versão mais recente"
        case .disponivel(let v): return "Espaço \(v) disponível"
        case .baixando:    return "Baixando…"
        case .instalando:  return "Instalando…"
        case .pronto:      return "Atualizado. Reiniciando o app…"
        case .erro(let e): return "Não deu pra checar"
        }
    }

    private var detalhe: String {
        switch up.estado {
        case .disponivel:
            if let v = up.disponivel {
                return "Você está na \(up.versaoAtual) · download de \(v.descricaoTamanho)"
            }
            return ""
        case .erro(let e): return e
        case .instalando:  return "Conferindo a assinatura antes de substituir o app"
        default:           return "Instalado em Aplicativos"
        }
    }

    @ViewBuilder
    private var acao: some View {
        switch up.estado {
        case .disponivel:
            Button("Atualizar agora") {
                Task { await up.baixarEInstalar() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        case .checando, .baixando, .instalando:
            ProgressView().controlSize(.small)
        default:
            Button("Procurar agora") {
                Task { await up.checar() }
            }
            .controlSize(.small)
        }
    }
}

struct CartaoVigilancia: View {
    @Bindable private var vigia = Vigia.shared

    var body: some View {
        Cartao(titulo: "Vigilância em segundo plano") {
            Toggle("Abrir o Espaço quando eu ligar o Mac", isOn: $vigia.abrirNoLogin)
                .toggleStyle(.switch)
                .controlSize(.small)

            Toggle("Avisar quando algo novo passar a rodar no boot", isOn: $vigia.vigilanciaLigada)
                .toggleStyle(.switch)
                .controlSize(.small)

            Text("Com a vigilância ligada, o app observa LaunchAgents, LaunchDaemons e a pasta Aplicativos. Se aparecer algo novo, você recebe uma notificação na hora — é assim que adware é pego cedo. Os números do disco também se atualizam sozinhos a cada 15 minutos.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !vigia.mudancas.isEmpty {
                Divider().padding(.vertical, 2)

                HStack {
                    Text("Mudanças recentes")
                        .font(T.rotulo)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Limpar") { vigia.limparHistorico() }
                        .buttonStyle(.link)
                        .font(.caption)
                }

                ForEach(vigia.mudancas.prefix(8)) { m in
                    HStack(spacing: 9) {
                        Circle().fill(Color.secondary.opacity(0.5))
                            .frame(width: 5, height: 5)
                        Text(m.descricao).font(.callout)
                        Spacer(minLength: 8)
                        Text(m.pasta).font(.caption2).foregroundStyle(.tertiary)
                        Text(m.quando.formatted(date: .omitted, time: .shortened))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }
}
