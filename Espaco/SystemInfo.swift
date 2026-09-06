import Foundation
import Darwin
import IOKit
import AppKit

struct InfoMac: Sendable {
    var modeloID = ""
    var modeloNome = ""
    var chip = ""
    var nucleos = 0
    var nucleosDesempenho = 0
    var nucleosEficiencia = 0
    var gpuNucleos: Int?
    var ram: Int64 = 0
    var macOSVersao = ""
    var macOSNome = ""
    var macOSBuild = ""
    var serial = ""
    var hostname = ""
    var ipLocal = ""
    var discoTotal: Int64 = 0
    var discoLivre: Int64 = 0
    var arquitetura = ""
    var ligadoDesde = Date()

    var serialMascarado: String {
        guard serial.count > 4 else { return "—" }
        return String(repeating: "•", count: serial.count - 4) + serial.suffix(4)
    }

    var resumoNucleos: String {
        if nucleosDesempenho > 0 && nucleosEficiencia > 0 {
            return "\(nucleos) núcleos · \(nucleosDesempenho) desempenho + \(nucleosEficiencia) eficiência"
        }
        return "\(nucleos) núcleos"
    }
}

enum SystemInfo {

    static func texto(_ chave: String) -> String {
        var tamanho = 0
        guard sysctlbyname(chave, nil, &tamanho, nil, 0) == 0, tamanho > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: tamanho)
        guard sysctlbyname(chave, &buffer, &tamanho, nil, 0) == 0 else { return "" }
        return String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func inteiro(_ chave: String) -> Int {
        var valor: Int = 0
        var tamanho = MemoryLayout<Int>.size
        guard sysctlbyname(chave, &valor, &tamanho, nil, 0) == 0 else { return 0 }
        return valor
    }

    static func ioRegistry(_ chave: String) -> String? {
        let servico = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("IOPlatformExpertDevice"))
        guard servico != 0 else { return nil }
        defer { IOObjectRelease(servico) }
        guard let v = IORegistryEntryCreateCFProperty(servico, chave as CFString,
                                                      kCFAllocatorDefault, 0)?
                .takeRetainedValue() else { return nil }
        if let s = v as? String { return s }
        if let d = v as? Data { return String(data: d, encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) }
        return nil
    }

    static func nomeComercial() -> String {
        let servico = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("IOPlatformDevice"))
        if servico != 0 {
            defer { IOObjectRelease(servico) }
            if let d = IORegistryEntryCreateCFProperty(servico, "product-name" as CFString,
                                                       kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Data,
               let s = String(data: d, encoding: .utf8)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0")), !s.isEmpty {
                return s
            }
        }
        return ""
    }

    static func nomeDoSistema(_ maior: Int) -> String {
        switch maior {
        case 26: return "Tahoe"
        case 15: return "Sequoia"
        case 14: return "Sonoma"
        case 13: return "Ventura"
        case 12: return "Monterey"
        case 11: return "Big Sur"
        default: return "macOS"
        }
    }

    static func ip() -> String {
        var ptr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ptr) == 0, let inicio = ptr else { return "" }
        defer { freeifaddrs(ptr) }

        var resultado = ""
        var atual: UnsafeMutablePointer<ifaddrs>? = inicio
        while let i = atual {
            let flags = Int32(i.pointee.ifa_flags)
            let nome = String(cString: i.pointee.ifa_name)
            if let endereco = i.pointee.ifa_addr,
               endereco.pointee.sa_family == UInt8(AF_INET),
               flags & IFF_LOOPBACK == 0,
               flags & IFF_UP != 0,
               nome.hasPrefix("en") {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(endereco, socklen_t(endereco.pointee.sa_len),
                               &host, socklen_t(host.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    let s = String(cString: host)
                    if !s.isEmpty && resultado.isEmpty { resultado = s }
                }
            }
            atual = i.pointee.ifa_next
        }
        return resultado
    }

    static func coletar() -> InfoMac {
        var i = InfoMac()

        i.modeloID = texto("hw.model")
        i.modeloNome = nomeComercial()
        if i.modeloNome.isEmpty { i.modeloNome = i.modeloID }

        i.chip = texto("machdep.cpu.brand_string")
        i.arquitetura = texto("hw.machine")
        i.nucleos = inteiro("hw.logicalcpu")
        i.nucleosDesempenho = inteiro("hw.perflevel0.logicalcpu")
        i.nucleosEficiencia = inteiro("hw.perflevel1.logicalcpu")
        i.ram = Int64(ProcessInfo.processInfo.physicalMemory)

        let v = ProcessInfo.processInfo.operatingSystemVersion
        i.macOSVersao = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        i.macOSNome = nomeDoSistema(v.majorVersion)
        i.macOSBuild = texto("kern.osversion")

        i.serial = ioRegistry("IOPlatformSerialNumber") ?? ""
        i.hostname = ProcessInfo.processInfo.hostName
            .replacingOccurrences(of: ".local", with: "")
        i.ipLocal = ip()

        let d = Scanner.disk()
        i.discoTotal = d.total
        i.discoLivre = d.available
        i.ligadoDesde = Date().addingTimeInterval(-Health.uptime())

        return i
    }
}
