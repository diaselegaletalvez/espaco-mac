import Foundation
import Darwin
import IOKit
import IOKit.ps

struct Processo: Identifiable, Sendable {
    let id: Int
    let nome: String
    let cpu: Double
    let ram: Double
}

struct SaudeMac: Sendable {
    var ramTotal: Int64 = 0
    var ramUsada: Int64 = 0
    var ramComprimida: Int64 = 0
    var cpuUso: Double = 0
    var uptime: TimeInterval = 0
    var bateriaPct: Int?
    var bateriaCiclos: Int?
    var bateriaSaude: Int?
    var carregando = false
    var topCPU: [Processo] = []
    var topRAM: [Processo] = []

    var ramFracao: Double { ramTotal > 0 ? Double(ramUsada) / Double(ramTotal) : 0 }

    var uptimeTexto: String {
        let h = Int(uptime) / 3600
        let d = h / 24
        if d >= 1 { return d == 1 ? "1 dia" : "\(d) dias" }
        if h >= 1 { return h == 1 ? "1 hora" : "\(h) horas" }
        return "\(Int(uptime) / 60) min"
    }
}

enum Health {

    static func memoria() -> (usada: Int64, total: Int64, comprimida: Int64) {
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size /
                                           MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return (0, total, 0) }

        let page = Int64(vm_kernel_page_size)
        let ativa = Int64(stats.active_count) * page
        let fixa = Int64(stats.wire_count) * page
        let comprimida = Int64(stats.compressor_page_count) * page
        return (ativa + fixa + comprimida, total, comprimida)
    }

    static func uptime() -> TimeInterval {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &tv, &size, nil, 0) == 0 else { return 0 }
        return Date().timeIntervalSince1970 - Double(tv.tv_sec)
    }

    static func bateria() -> (pct: Int?, carregando: Bool) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let lista = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return (nil, false) }

        for fonte in lista {
            guard let d = IOPSGetPowerSourceDescription(blob, fonte)?
                    .takeUnretainedValue() as? [String: Any] else { continue }
            let atual = d[kIOPSCurrentCapacityKey] as? Int
            let maximo = d[kIOPSMaxCapacityKey] as? Int ?? 100
            let estado = d[kIOPSPowerSourceStateKey] as? String
            if let a = atual {
                return (Int((Double(a) / Double(max(1, maximo))) * 100),
                        estado == kIOPSACPowerValue)
            }
        }
        return (nil, false)
    }

    static func bateriaDetalhe() -> (ciclos: Int?, saude: Int?) {
        let servico = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard servico != 0 else { return (nil, nil) }
        defer { IOObjectRelease(servico) }

        func inteiro(_ chave: String) -> Int? {
            guard let v = IORegistryEntryCreateCFProperty(servico, chave as CFString,
                                                          kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? Int else { return nil }
            return v
        }

        let ciclos = inteiro("CycleCount")
        let projeto = inteiro("DesignCapacity")
        let maximo = inteiro("AppleRawMaxCapacity") ?? inteiro("MaxCapacity")

        var saude: Int?
        if let p = projeto, p > 0, let m = maximo {
            saude = Int((Double(m) / Double(p)) * 100)
        }
        return (ciclos, saude)
    }

    static func processos() -> (cpu: [Processo], ram: [Processo], usoTotal: Double) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-Aco", "pid,pcpu,pmem,comm", "-r"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice

        guard (try? p.run()) != nil,
              let dados = try? pipe.fileHandleForReading.readToEnd(),
              let texto = String(data: dados, encoding: .utf8)
        else { return ([], [], 0) }
        p.waitUntilExit()

        var todos: [Processo] = []
        for linha in texto.components(separatedBy: .newlines).dropFirst() {
            let campos = linha.split(separator: " ", maxSplits: 3,
                                     omittingEmptySubsequences: true)
            guard campos.count >= 4,
                  let pid = Int(campos[0]),
                  let cpu = Double(campos[1]),
                  let ram = Double(campos[2]) else { continue }
            let nome = String(campos[3]).trimmingCharacters(in: .whitespaces)
            todos.append(Processo(id: pid, nome: nome, cpu: cpu, ram: ram))
        }

        let total = todos.reduce(0.0) { $0 + $1.cpu }
        let porCPU = Array(todos.sorted { $0.cpu > $1.cpu }.prefix(5))
        let porRAM = Array(todos.sorted { $0.ram > $1.ram }.prefix(5))
        return (porCPU, porRAM, total)
    }

    static func coletar() -> SaudeMac {
        var s = SaudeMac()
        let m = memoria()
        s.ramUsada = m.usada
        s.ramTotal = m.total
        s.ramComprimida = m.comprimida
        s.uptime = uptime()

        let b = bateria()
        s.bateriaPct = b.pct
        s.carregando = b.carregando

        let d = bateriaDetalhe()
        s.bateriaCiclos = d.ciclos
        s.bateriaSaude = d.saude

        let p = processos()
        s.topCPU = p.cpu
        s.topRAM = p.ram
        let nucleos = Double(ProcessInfo.processInfo.activeProcessorCount)
        s.cpuUso = min(1.0, p.usoTotal / (nucleos * 100))
        return s
    }
}
