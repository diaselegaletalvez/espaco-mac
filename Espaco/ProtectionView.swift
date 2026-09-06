import SwiftUI
import AppKit

struct ProtectionView: View {
    @Environment(AppState.self) private var state

    private var r: RelatorioSeguranca { state.seguranca }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                cabecalho

                notaSeguranca
                raioX
                cartaoRede

                if state.analisandoSeguranca {
                    HStack(spacing: 9) {
                        ProgressView().controlSize(.small)
                        Text("Conferindo defesas, itens de inicialização e assinaturas…")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.secondary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: T.cartao))
                }

                defesas
                inicializacao
                if !r.appsSuspeitos.isEmpty { apps }
                if !r.perfis.isEmpty { perfis }
                if !r.travamentos.isEmpty { travamentos }

                rodape
            }
            .padding(28)
        }
        .task { if r.analisadoEm == nil { await state.analisarSeguranca() } }
    }

    private var corGeral: Color {
        switch r.gravidadeGeral {
        case .ok: return T.ok
        case .atencao: return T.atencao
        case .alerta: return T.critico
        }
    }

    private var cabecalho: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: r.gravidadeGeral == .ok ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                .font(.system(size: 34))
                .foregroundStyle(corGeral)

            VStack(alignment: .leading, spacing: 5) {
                Text(r.analisadoEm == nil ? "Proteção" :
                        (r.gravidadeGeral == .ok ? "Tudo em ordem" : "Tem coisa pra olhar"))
                    .font(T.numero(28))

                Text(r.analisadoEm == nil
                     ? "Confere as defesas do sistema, o que roda no boot e a assinatura dos seus apps."
                     : r.resumo)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                Task { await state.analisarSeguranca() }
            } label: {
                Label("Analisar", systemImage: "shield")
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.analisandoSeguranca)
        }
    }

    private var defesas: some View {
        Cartao(titulo: "Defesas do sistema") {
            ForEach(r.defesas) { d in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 9) {
                        Image(systemName: d.ligada ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(d.ligada ? T.ok : T.atencao)
                        Text(d.nome).font(.body.weight(.medium))
                        Spacer()
                        Text(d.estado)
                            .font(.caption)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background((d.ligada ? T.ok : T.atencao).opacity(0.16), in: Capsule())
                            .foregroundStyle(d.ligada ? T.ok : T.atencao)
                    }
                    Text(d.explicacao)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let arrumar = d.comoArrumar {
                        Text(arrumar)
                            .font(.caption)
                            .foregroundStyle(T.atencao)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 5)
                if d.id != r.defesas.last?.id { Divider().opacity(0.5) }
            }
        }
    }

    private var inicializacao: some View {
        Cartao(titulo: "Roda quando o Mac liga") {
            if r.inicializacao.isEmpty {
                Text("Nada além do que veio com o sistema.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                if !r.inicializacaoDuvidosa.isEmpty {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(T.critico)
                        Text("\(r.inicializacaoDuvidosa.count) item\(r.inicializacaoDuvidosa.count == 1 ? "" : "s") sem assinatura válida. É aqui que adware costuma se instalar — confira se você reconhece cada um.")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(11)
                    .background(T.critico.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                    .padding(.bottom, 4)
                }

                ForEach(r.inicializacao) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(item.confiavel ? T.ok : T.critico)
                            .frame(width: 7, height: 7)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.nome)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            Text("\(item.escopo) · \(item.assinadoPor ?? "sem assinatura")")
                                .font(.caption)
                                .foregroundStyle(item.confiavel ? .secondary : Color(T.critico))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 10)

                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([item.caminho])
                        } label: {
                            Image(systemName: "folder").font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help(item.programa)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var apps: some View {
        Cartao(titulo: "Apps com problema de assinatura") {
            ForEach(r.appsSuspeitos) { a in
                HStack(spacing: 11) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: a.caminho.path))
                        .resizable().frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.nome).font(.callout.weight(.medium))
                        Text(a.motivo).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 10)
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([a.caminho])
                    } label: {
                        Image(systemName: "folder").font(.caption)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Text("Assinatura ausente ou quebrada não prova que o app é malicioso — muita ferramenta de desenvolvedor e app antigo caem aqui. Mas app modificado depois de assinado merece uma olhada.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    private var perfis: some View {
        Cartao(titulo: "Perfis de configuração") {
            Text("Perfis podem mudar DNS, proxy e página inicial do navegador sem aviso. Se você não instalou nenhum de propósito, remova em Ajustes → Geral → Gerenciamento de Dispositivos.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(r.perfis) { p in
                HStack(spacing: 9) {
                    Image(systemName: "doc.badge.gearshape").foregroundStyle(T.atencao)
                    Text(p.nome).font(.callout)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var travamentos: some View {
        Cartao(titulo: "Apps que travaram nos últimos 30 dias") {
            ForEach(r.travamentos.prefix(8)) { t in
                HStack(spacing: 10) {
                    Circle()
                        .fill(t.vezes >= 5 ? T.critico : (t.vezes >= 2 ? T.atencao : Color.secondary))
                        .frame(width: 7, height: 7)
                    Text(t.app).font(.callout)
                    Spacer(minLength: 10)
                    Text(t.descricaoQuando)
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(t.vezes)×")
                        .font(.callout.monospacedDigit())
                        .frame(minWidth: 34, alignment: .trailing)
                }
                .padding(.vertical, 5)
            }

            if r.travamentos.contains(where: { $0.vezes >= 5 }) {
                Text("Um app travando cinco vezes ou mais costuma ser bug de versão. Vale procurar atualização antes de culpar o Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }


    private var notaSeguranca: some View {
        let rx = state.raioX
        return Group {
            if rx.feitoEm != nil {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(rx.nota)")
                            .font(.system(size: 44, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(rx.nota >= 85 ? T.ok : (rx.nota >= 60 ? T.atencao : T.critico))
                        Text("de 100")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 14) {
                            selo("\(rx.criticos.count)", "críticos", T.critico)
                            selo("\(rx.avisos.count)", "avisos", T.atencao)
                            selo("\(rx.limpos.count)", "em ordem", T.ok)
                        }
                        Text(rx.criticos.isEmpty
                             ? "Nenhuma brecha crítica nas seis checagens principais."
                             : "Comece pelos críticos — eles dão acesso ao que você digita e navega.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: T.cartao))
            }
        }
    }

    private func selo(_ numero: String, _ rotulo: String, _ cor: Color) -> some View {
        HStack(spacing: 5) {
            Text(numero)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(cor)
            Text(rotulo)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var raioX: some View {
        VStack(alignment: .leading, spacing: 9) {
            if state.raioX.feitoEm != nil {
                Text("As seis checagens que mais importam")
                    .font(.headline)

                ForEach(state.raioX.achados) { a in
                    LinhaAchadura(achadura: a)
                }
            }
        }
    }

    private var cartaoRede: some View {
        let r = state.rede
        return Cartao(titulo: "Rede e VPN") {
            HStack(spacing: 11) {
                Image(systemName: r.vpnAtiva ? "lock.shield.fill"
                                             : (r.arriscado ? "wifi.exclamationmark" : "wifi"))
                    .font(.title3)
                    .foregroundStyle(r.vpnAtiva ? T.ok : (r.arriscado ? T.critico : .secondary))

                VStack(alignment: .leading, spacing: 2) {
                    Text(r.vpnAtiva ? "VPN ativa" : (r.ssid ?? "Sem Wi-Fi"))
                        .font(.body.weight(.medium))
                    Text(r.resumo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Divider().padding(.vertical, 2)

            linhaRede("Endereço local", r.ipLocal.isEmpty ? "—" : r.ipLocal)
            if !r.interfacesVPN.isEmpty {
                linhaRede("Túnel VPN", r.interfacesVPN.joined(separator: ", "))
            }
            if !r.dnsUsados.isEmpty {
                linhaRede("DNS", r.dnsUsados.prefix(3).joined(separator: ", "))
            }

            if let ip = r.ipPublico {
                linhaRede("Endereço público", ip + (r.paisIP.map { " · \($0)" } ?? ""))
                if let prov = r.provedorIP {
                    linhaRede("Sai pela", prov)
                }
            } else {
                HStack {
                    Button("Descobrir meu IP público") {
                        Task { await state.consultarIPPublico() }
                    }
                    .controlSize(.small)
                    Text("consulta o ipinfo.io")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
    }

    private func linhaRede(_ rotulo: String, _ valor: String) -> some View {
        HStack {
            Text(rotulo).font(.callout).foregroundStyle(.secondary)
            Spacer()
            Text(valor)
                .font(.callout.monospacedDigit())
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }

    private var rodape: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle")
                .foregroundStyle(.tertiary)
            Text("O Espaço não é antivírus e não compara arquivos com listas de malware conhecido. Ele checa o que dá pra verificar com certeza: se as defesas do macOS estão ligadas, se o que roda no boot é assinado, e se algum app foi alterado depois de assinado — que é onde problema de verdade aparece primeiro.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.top, 6)
    }
}


struct LinhaAchadura: View {
    let achadura: Achadura
    @State private var aberto = false

    private var cor: Color {
        switch achadura.gravidade {
        case .ok: return T.ok
        case .atencao: return T.atencao
        case .alerta: return T.critico
        }
    }

    private var icone: String {
        switch achadura.gravidade {
        case .ok: return "checkmark.circle.fill"
        case .atencao: return "exclamationmark.circle.fill"
        case .alerta: return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: icone)
                    .foregroundStyle(cor)
                    .font(.system(size: 15))

                VStack(alignment: .leading, spacing: 2) {
                    Text(achadura.titulo).font(.body.weight(.medium))
                    Text(achadura.estado)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                Image(systemName: aberto ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .contentShape(Rectangle())
            .onTapGesture { aberto.toggle() }

            if aberto {
                VStack(alignment: .leading, spacing: 9) {
                    Text(achadura.porqueImporta)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !achadura.detalhes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(achadura.detalhes, id: \.self) { d in
                                HStack(spacing: 7) {
                                    Circle().fill(cor.opacity(0.6)).frame(width: 4, height: 4)
                                    Text(d)
                                        .font(.callout.monospacedDigit())
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.18),
                                    in: RoundedRectangle(cornerRadius: 6))
                    }

                    if let resolver = achadura.comoResolver {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.caption)
                                .foregroundStyle(cor)
                            Text(resolver)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(11)
                        .background(cor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                    }
                }
                .padding(.horizontal, 13)
                .padding(.bottom, 13)
            }
        }
        .background(achadura.gravidade == .ok ? Color.secondary.opacity(0.08) : cor.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: T.cartao))
    }
}
