import Foundation
import Darwin

struct EstadoRede: Sendable {
    var vpnAtiva = false
    var interfacesVPN: [String] = []
    var ssid: String?
    var wifiAberto: Bool?
    var ipLocal = ""
    var ipPublico: String?
    var paisIP: String?
    var provedorIP: String?
    var dnsUsados: [String] = []
    var consultadoEm: Date?

    var arriscado: Bool {
        (wifiAberto == true) && !vpnAtiva
    }

    var resumo: String {
        if arriscado {
            return "Você está numa rede Wi-Fi sem senha e sem VPN. Qualquer pessoa na mesma rede consegue ver para onde você navega."
        }
        if vpnAtiva {
            return "VPN ativa. Seu tráfego sai criptografado por ela."
        }
        if wifiAberto == false {
            return "Rede Wi-Fi com senha e sem VPN. Para uso em casa está de bom tamanho."
        }
        return "Sem VPN ativa. Em redes públicas, vale ligar uma antes de acessar banco ou e-mail."
    }
}

enum Network {

    static func interfacesVPN() -> [String] {
        var achadas: [String] = []
        var ptr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ptr) == 0, let inicio = ptr else { return [] }
        defer { freeifaddrs(ptr) }

        var atual: UnsafeMutablePointer<ifaddrs>? = inicio
        while let i = atual {
            let nome = String(cString: i.pointee.ifa_name)
            let flags = Int32(i.pointee.ifa_flags)
            if (nome.hasPrefix("utun") || nome.hasPrefix("ipsec") || nome.hasPrefix("ppp")),
               flags & IFF_UP != 0,
               let addr = i.pointee.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_INET) {
                if !achadas.contains(nome) { achadas.append(nome) }
            }
            atual = i.pointee.ifa_next
        }
        return achadas
    }

    static func vpnPorConfiguracao() -> Bool {
        let saida = Security.shell("/usr/sbin/scutil", ["--nc", "list"])
        return saida.components(separatedBy: .newlines)
            .contains { $0.contains("Connected") }
    }

    static func redeWifi() -> (ssid: String?, aberto: Bool?) {
        let saida = Security.shell("/usr/sbin/networksetup", ["-getairportnetwork", "en0"])
        guard let faixa = saida.range(of: ": ") else { return (nil, nil) }
        let nome = String(saida[faixa.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nome.isEmpty, !nome.lowercased().contains("not associated") else { return (nil, nil) }

        let lista = Security.shell("/usr/sbin/networksetup", ["-listpreferredwirelessnetworks", "en0"])
        _ = lista

        let seguranca = Security.shell("/usr/bin/security",
                                       ["find-generic-password", "-ga", nome])
        let temSenha = seguranca.contains("password:") && !seguranca.contains("could not be found")

        return (nome, temSenha ? false : nil)
    }

    static func dnsAtivos() -> [String] {
        let saida = Security.shell("/usr/sbin/scutil", ["--dns"])
        var out: [String] = []
        for linha in saida.components(separatedBy: .newlines) {
            let l = linha.trimmingCharacters(in: .whitespaces)
            guard l.hasPrefix("nameserver["), let faixa = l.range(of: ": ") else { continue }
            let ip = String(l[faixa.upperBound...])
            if !out.contains(ip) { out.append(ip) }
        }
        return out
    }

    static func local() -> EstadoRede {
        var r = EstadoRede()
        r.interfacesVPN = interfacesVPN()
        r.vpnAtiva = !r.interfacesVPN.isEmpty || vpnPorConfiguracao()

        let wifi = redeWifi()
        r.ssid = wifi.ssid
        r.wifiAberto = wifi.aberto

        r.ipLocal = SystemInfo.ip()
        r.dnsUsados = dnsAtivos()
        return r
    }

    static func consultarIPPublico() async -> (ip: String, pais: String?, provedor: String?)? {
        guard let url = URL(string: "https://ipinfo.io/json") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (dados, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: dados) as? [String: Any],
              let ip = json["ip"] as? String else { return nil }

        return (ip, json["country"] as? String, json["org"] as? String)
    }
}
