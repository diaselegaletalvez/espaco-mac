import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var disk = DiskInfo()
    var targets: [Target] = Catalog.all
    var selection: Set<String> = []

    var scanning = false
    var cleaning = false
    var cleaningLabel = ""
    var lastScan: Date?
    var history: [DayPoint] = []
    var projetos: [ProjectInfo] = []
    var scanningProjetos = false
    var pilha: [Node] = []
    var varrendo = false
    var apps: [InstalledApp] = []
    var scanningApps = false
    var grandes: [BigFile] = []
    var scanningGrandes = false
    var duplicados: [DupGroup] = []
    var achados: [Achado] = []
    var revisando = false
    var jaRevisou = false
    var saude = SaudeMac()
    var info = InfoMac()
    var agenda = EstadoAgenda()
    var seguranca = RelatorioSeguranca()
    var analisandoSeguranca = false
    var raioX = RaioX()
    var rede = EstadoRede()
    var perfilMaquina = PerfilMaquina()
    var manual: [ComandoManual] = []
    var montandoManual = false
    var scanningDuplicados = false
    var duplicadosVarridos = false
    var etapaAtual = ""
    var etapasFeitas: Set<String> = []
    let etapas = ["Medindo caches e pastas do sistema",
                  "Lendo apps instalados e resíduos",
                  "Procurando arquivos grandes esquecidos",
                  "Conferindo projetos parados",
                  "Comparando arquivos duplicados"]
    var lastResult: CleanResult?
    var showConfirm = false

    var reclaimable: Int64 {
        targets.filter { $0.risk == .zero && $0.measured }.reduce(0) { $0 + $1.size }
    }

    var selectedSize: Int64 {
        targets.filter { selection.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    var selectedRiskiest: Risk {
        let picked = targets.filter { selection.contains($0.id) }
        if picked.contains(where: { $0.risk == .alto })  { return .alto }
        if picked.contains(where: { $0.risk == .medio }) { return .medio }
        return .zero
    }

    var canClean: Bool { !selection.isEmpty && !cleaning && !scanning }

    func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    func selectSafeOnly() {
        selection = Set(targets.filter { $0.risk == .zero && $0.size > 0 }.map(\.id))
    }

    func refreshDiskOnly() {
        disk = Scanner.disk()
    }

    func scan() async {
        guard !scanning else { return }
        scanning = true
        disk = Scanner.disk()

        let snapshot = targets
        let sizes: [String: Int64] = await withTaskGroup(of: (String, Int64).self) { group in
            for t in snapshot {
                group.addTask(priority: .utility) { (t.id, Scanner.measure(t)) }
            }
            var out: [String: Int64] = [:]
            for await (id, size) in group { out[id] = size }
            return out
        }

        for i in targets.indices {
            if let s = sizes[targets[i].id] {
                targets[i].size = s
                targets[i].measured = true
            }
        }

        targets.sort { $0.size > $1.size }
        selection = selection.filter { id in targets.contains { $0.id == id && $0.size > 0 } }
        disk = Scanner.disk()
        history = History.points()
        lastScan = Date()
        scanning = false
    }

    func cleanSelected() async {
        guard !cleaning else { return }
        cleaning = true
        lastResult = nil

        let chosen = targets.filter { selection.contains($0.id) }
        var total = CleanResult()

        for target in chosen {
            cleaningLabel = target.name
            let r = await Task.detached(priority: .userInitiated) {
                Cleaner.clean(target)
            }.value
            total.freed += r.freed
            total.itemsRemoved += r.itemsRemoved
            total.itemsTrashed += r.itemsTrashed
            total.failures.append(contentsOf: r.failures)
        }

        cleaningLabel = ""
        lastResult = total
        selection = []
        cleaning = false

        await scan()
    }

    func scanProjetos() async {
        guard !scanningProjetos else { return }
        scanningProjetos = true
        projetos = await Task.detached(priority: .utility) { Projects.scan() }.value
        scanningProjetos = false
    }

    func limparProjeto(_ p: ProjectInfo) async {
        let r = await Task.detached(priority: .userInitiated) { Projects.limpar(p) }.value
        lastResult = r
        Notifier.avisar("\(p.nome) limpo", "\(Fmt.bytes(r.freed)) foram pra Lixeira")
        await scanProjetos()
        await scan()
    }

    func turbo() async {
        guard !cleaning else { return }
        cleaning = true
        let seguros = targets.filter { $0.risk == .zero && $0.size > 0 }
        var total = CleanResult()
        for t in seguros {
            cleaningLabel = t.name
            let r = await Task.detached(priority: .userInitiated) { Cleaner.clean(t) }.value
            total.freed += r.freed
            total.itemsRemoved += r.itemsRemoved
            total.failures.append(contentsOf: r.failures)
        }
        cleaningLabel = ""
        lastResult = total
        cleaning = false
        await scan()
        Notifier.avisar("Turbo concluído",
                        total.freed > 0 ? "Liberou \(Fmt.bytes(total.freed))" : "Já estava limpo")
    }

    var noAtual: Node? { pilha.last }

    func varrer() async {
        guard !varrendo else { return }
        varrendo = true
        let raiz = await Task.detached(priority: .userInitiated) { Tree.varrerHome() }.value
        pilha = [raiz]
        varrendo = false
    }

    func entrar(_ n: Node) {
        pilha.append(n)
    }

    func subir() {
        if pilha.count > 1 { pilha.removeLast() }
    }

    func irPara(indice: Int) {
        guard indice < pilha.count else { return }
        pilha = Array(pilha.prefix(indice + 1))
    }

    func scanApps() async {
        guard !scanningApps else { return }
        scanningApps = true
        apps = await Task.detached(priority: .utility) { Uninstaller.listar() }.value
        scanningApps = false
    }

    func removerApp(_ app: InstalledApp, incluirApp: Bool) async {
        let r = await Task.detached(priority: .userInitiated) {
            Uninstaller.remover(app, incluirApp: incluirApp)
        }.value
        lastResult = r
        Notifier.avisar(incluirApp ? "\(app.nome) removido" : "Resíduos de \(app.nome) removidos",
                        "\(Fmt.bytes(r.freed)) foram pra Lixeira")
        await scanApps()
        await scan()
    }

    func scanGrandes() async {
        guard !scanningGrandes else { return }
        scanningGrandes = true
        grandes = await Task.detached(priority: .utility) { BigFiles.varrer() }.value
        scanningGrandes = false
    }

    func lixeiraGrandes(_ arquivos: [BigFile]) async {
        let r = await Task.detached(priority: .userInitiated) {
            BigFiles.paraLixeira(arquivos)
        }.value
        lastResult = r
        Notifier.avisar("Arquivos na Lixeira", "\(Fmt.bytes(r.freed)) liberados quando esvaziar")
        await scanGrandes()
        await scan()
    }

    func revisar() async {
        guard !revisando else { return }
        revisando = true
        etapasFeitas = []
        achados = []

        etapaAtual = etapas[0]
        await scan()
        etapasFeitas.insert(etapas[0])

        etapaAtual = etapas[1]
        await scanApps()
        etapasFeitas.insert(etapas[1])

        etapaAtual = etapas[2]
        await scanGrandes()
        etapasFeitas.insert(etapas[2])

        etapaAtual = etapas[3]
        await scanProjetos()
        etapasFeitas.insert(etapas[3])

        etapaAtual = etapas[4]
        duplicados = await Task.detached(priority: .utility) { Duplicates.varrer() }.value
        etapasFeitas.insert(etapas[4])

        etapaAtual = ""
        achados = SmartScan.montar(targets: targets,
                                   apps: apps,
                                   grandes: grandes,
                                   projetos: projetos,
                                   duplicados: duplicados)
        jaRevisou = true
        revisando = false

        let soma = achados.reduce(Int64(0)) { $0 + $1.tamanho }
        if soma > 0 {
            Notifier.avisar("Revisão concluída",
                            "\(Fmt.bytes(soma)) podem sair em \(achados.count) itens")
        }
    }

    func executar(_ lista: [Achado]) async {
        guard !cleaning else { return }
        cleaning = true
        var total = CleanResult()

        for a in lista {
            cleaningLabel = a.titulo
            let r: CleanResult = await Task.detached(priority: .userInitiated) {
                switch a.acao {
                case .categoria(let t):   return Cleaner.clean(t)
                case .residuos(let app):  return Uninstaller.remover(app, incluirApp: false)
                case .arquivos(let fs):   return BigFiles.paraLixeira(fs)
                case .projeto(let p):     return Projects.limpar(p)
                case .duplicados(let gs): return Duplicates.removerCopias(gs)
                }
            }.value
            total.freed += r.freed
            total.itemsRemoved += r.itemsRemoved
            total.itemsTrashed += r.itemsTrashed
            total.failures.append(contentsOf: r.failures)
        }

        cleaningLabel = ""
        lastResult = total
        cleaning = false

        Notifier.avisar("Limpeza concluída", "Liberou \(Fmt.bytes(total.freed))")
        await revisar()
    }

    func atualizarSaude() async {
        saude = await Task.detached(priority: .utility) { Health.coletar() }.value
    }

    func carregarInfo() async {
        info = await Task.detached(priority: .utility) { SystemInfo.coletar() }.value
    }

    func carregarAgenda() async {
        agenda = await Task.detached(priority: .utility) { Automation.estado() }.value
    }

    func salvarAgenda(hora: Int, minuto: Int) async {
        _ = await Task.detached(priority: .userInitiated) {
            Automation.salvarHorario(hora: hora, minuto: minuto)
        }.value
        await carregarAgenda()
    }

    func desativarAgenda() async {
        await Task.detached(priority: .userInitiated) { Automation.desativar() }.value
        await carregarAgenda()
    }

    func rodarAgendaAgora() async {
        await Task.detached(priority: .userInitiated) { Automation.rodarAgora() }.value
        try? await Task.sleep(for: .seconds(4))
        await carregarAgenda()
        history = History.points()
    }

    func analisarSeguranca() async {
        guard !analisandoSeguranca else { return }
        analisandoSeguranca = true
        seguranca = await Task.detached(priority: .utility) { Security.analisar() }.value
        raioX = await Task.detached(priority: .utility) { SecurityDeep.raioX() }.value
        rede = await Task.detached(priority: .utility) { Network.local() }.value
        analisandoSeguranca = false
    }

    func scanDuplicados() async {
        guard !scanningDuplicados else { return }
        scanningDuplicados = true
        duplicados = await Task.detached(priority: .utility) { Duplicates.varrer() }.value
        duplicadosVarridos = true
        scanningDuplicados = false
    }

    func limparDuplicados(_ grupos: [DupGroup]) async {
        let r = await Task.detached(priority: .userInitiated) {
            Duplicates.removerCopias(grupos)
        }.value
        lastResult = r
        Notifier.avisar("Cópias na Lixeira", "\(Fmt.bytes(r.freed)) liberados quando esvaziar")
        await scanDuplicados()
        await scan()
    }

    func consultarIPPublico() async {
        guard let info = await Network.consultarIPPublico() else { return }
        rede.ipPublico = info.ip
        rede.paisIP = info.pais
        rede.provedorIP = info.provedor
        rede.consultadoEm = Date()
    }

    func montarManual() async {
        guard !montandoManual else { return }
        montandoManual = true
        let p = await Task.detached(priority: .utility) { Perfilador.levantar() }.value
        perfilMaquina = p
        manual = ManualAdaptativo.montar(p)
        montandoManual = false
    }
}
