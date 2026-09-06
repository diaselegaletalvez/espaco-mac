import SwiftUI
import AppKit

struct ProtectionView: View {
    @Environment(AppState.self) private var state

    private var r: RelatorioSeguranca { state.seguranca }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                cabecalho

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
