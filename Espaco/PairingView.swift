import SwiftUI
import CoreImage.CIFilterBuiltins
import AppKit
import Network

struct CartaoPareamento: View {
    @Environment(AppState.self) private var state
    @Bindable private var par = Pareamento.shared
    @Bindable private var servidor = ServidorLocal.shared

    var body: some View {
        Cartao(titulo: "Celular") {
            if par.modoPareamento {
                modoParear
            } else if par.dispositivos.isEmpty {
                convite
            } else {
                lista
            }
        }
        .alert("Pedido do \(par.pedidoPendente?.dispositivo ?? "celular")",
               isPresented: Binding(get: { par.pedidoPendente != nil },
                                    set: { if !$0 { par.responder(false) } })) {
            Button("Recusar", role: .cancel) { par.responder(false) }
            Button("Aprovar", role: .destructive) { par.responder(true) }
        } message: {
            if let p = par.pedidoPendente {
                Text("\(p.acao)\n\n\(p.detalhe)")
            }
        }
    }

    private var convite: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                Image(systemName: "iphone.gen3")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nenhum celular pareado")
                        .font(.body.weight(.medium))
                    Text("Veja o disco, a saúde e a proteção do Mac pelo telefone — e limpe de longe, sem levantar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            HStack {
                Button {
                    par.abrirPareamento()
                } label: {
                    Label("Parear celular", systemImage: "wave.3.right")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Text("funciona no mesmo Wi-Fi")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var modoParear: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 22) {
                if let codigo = par.codigoAtual {
                    Image(nsImage: qr(para: cargaQR(codigo)))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 132, height: 132)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Abra o Espaço no celular e aponte pro código")
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)

                    if let codigo = par.codigoAtual {
                        Text(codigo)
                            .font(.system(size: 30, weight: .semibold, design: .monospaced))
                            .kerning(4)
                            .monospacedDigit()
                    }

                    Text("Ou digite esses seis números no telefone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 7) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("expira em \(par.segundosRestantes)s")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(par.segundosRestantes < 30 ? T.atencao : .secondary)

                    Button("Cancelar") { par.fecharPareamento() }
                        .controlSize(.small)
                        .padding(.top, 2)
                }
                Spacer()
            }

            if let endereco = servidor.enderecoVisivel {
                Text("Este Mac está escutando em \(endereco), só na rede local.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var lista: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(par.dispositivos) { d in
                HStack(spacing: 11) {
                    Image(systemName: "iphone.gen3")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.nome).font(.body.weight(.medium))
                        Text("\(d.modelo) · \(d.descricaoAcesso)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 10)

                    Toggle("Sem perguntar", isOn: Binding(
                        get: { d.confiavel },
                        set: { _ in par.alternarConfianca(d.id) }))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .font(.caption)

                    Button("Desparear") { par.revogar(d.id) }
                        .controlSize(.small)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 11)
                .background(Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 7))
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(servidor.ligado ? T.ok : Color.secondary)
                    .frame(width: 6, height: 6)
                Text(servidor.ligado
                     ? "Escutando em \(servidor.enderecoVisivel ?? "rede local")"
                     : "Servidor parado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Parear outro") { par.abrirPareamento() }
                    .buttonStyle(.link)
                    .font(.caption)
            }

            Text("O celular só alcança este Mac pela rede local, e cada aparelho tem seu próprio acesso — dá pra desparear um sem mexer nos outros. Com \"sem perguntar\" desligado, qualquer limpeza que não seja de cache pede sua confirmação aqui antes de acontecer.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func cargaQR(_ codigo: String) -> String {
        let ip = SystemInfo.ip()
        let nome = Host.current().localizedName ?? "Mac"
        return "espaco://parear?ip=\(ip)&porta=\(servidor.porta.rawValue)&codigo=\(codigo)&mac=\(nome.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Mac")"
    }

    private func qr(para texto: String) -> NSImage {
        let contexto = CIContext()
        let filtro = CIFilter.qrCodeGenerator()
        filtro.message = Data(texto.utf8)
        filtro.correctionLevel = "M"

        guard let saida = filtro.outputImage else { return NSImage() }
        let escala = saida.transformed(by: CGAffineTransform(scaleX: 9, y: 9))
        guard let cg = contexto.createCGImage(escala, from: escala.extent) else { return NSImage() }
        return NSImage(cgImage: cg, size: NSSize(width: escala.extent.width,
                                                 height: escala.extent.height))
    }
}
