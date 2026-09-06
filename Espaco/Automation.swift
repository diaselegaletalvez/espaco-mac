import Foundation
import AppKit

struct ComandoManual: Identifiable, Sendable {
    let id: String
    let numero: Int
    let titulo: String
    let porque: String
    let comando: String
    let risco: Risk
    let ganhoTipico: String
    var precisaSudo = false
    var soLista = false

    var rotuloNumero: String { "\(numero)" }
}

struct SaidaComando: Identifiable, Sendable {
    let id = UUID()
    let texto: String
    let sucesso: Bool
}

struct EstadoAgenda: Sendable {
    var scriptExiste = false
    var agenteExiste = false
    var agenteCarregado = false
    var hora = 0
    var minuto = 0
    var ultimoRelatorio: Date?
    var totalRelatorios = 0

    var tudoCerto: Bool { scriptExiste && agenteExiste && agenteCarregado }

    var horarioTexto: String {
        String(format: "%02d:%02d", hora, minuto)
    }
}

enum Automation {

    static let rotulo = "com.diasinc.macreport"

    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    static var script: URL { home.appending(path: "bin/mac-report.sh") }
    static var plist: URL { home.appending(path: "Library/LaunchAgents/\(rotulo).plist") }
    static var relatorios: URL { home.appending(path: "Relatorios") }

    @discardableResult
    static func shell(_ caminho: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: caminho)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return "" }
        let dados = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        p.waitUntilExit()
        return String(data: dados, encoding: .utf8) ?? ""
    }

    static func estado() -> EstadoAgenda {
        var e = EstadoAgenda()
        let fm = FileManager.default

        e.scriptExiste = fm.isExecutableFile(atPath: script.path)
        e.agenteExiste = fm.fileExists(atPath: plist.path)

        if e.agenteExiste,
           let dados = try? Data(contentsOf: plist),
           let raiz = try? PropertyListSerialization.propertyList(from: dados, format: nil)
                as? [String: Any],
           let quando = raiz["StartCalendarInterval"] as? [String: Any] {
            e.hora = quando["Hour"] as? Int ?? 0
            e.minuto = quando["Minute"] as? Int ?? 0
        }

        let lista = shell("/bin/launchctl", ["list"])
        e.agenteCarregado = lista.contains(rotulo)

        let arquivos = History.reports()
        e.totalRelatorios = arquivos.count
        e.ultimoRelatorio = arquivos.first?.date

        return e
    }

    static func plistTexto(hora: Int, minuto: Int) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(rotulo)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/bash</string>
                <string>-lc</string>
                <string>\(script.path)</string>
            </array>
            <key>StartCalendarInterval</key>
            <dict>
                <key>Hour</key><integer>\(hora)</integer>
                <key>Minute</key><integer>\(minuto)</integer>
            </dict>
            <key>RunAtLoad</key>
            <false/>
            <key>StandardOutPath</key>
            <string>\(relatorios.path)/logs/out.log</string>
            <key>StandardErrorPath</key>
            <string>\(relatorios.path)/logs/err.log</string>
            <key>ProcessType</key>
            <string>Background</string>
        </dict>
        </plist>
        """
    }

    static func salvarHorario(hora: Int, minuto: Int) -> Bool {
        let fm = FileManager.default
        try? fm.createDirectory(at: plist.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
        try? fm.createDirectory(at: relatorios.appending(path: "logs"),
                                withIntermediateDirectories: true)

        guard (try? plistTexto(hora: hora, minuto: minuto)
                .write(to: plist, atomically: true, encoding: .utf8)) != nil else { return false }

        let uid = getuid()
        shell("/bin/launchctl", ["bootout", "gui/\(uid)/\(rotulo)"])
        shell("/bin/launchctl", ["bootstrap", "gui/\(uid)", plist.path])
        shell("/bin/launchctl", ["enable", "gui/\(uid)/\(rotulo)"])
        return true
    }

    static func desativar() {
        let uid = getuid()
        shell("/bin/launchctl", ["bootout", "gui/\(uid)/\(rotulo)"])
    }

    static func rodarAgora() {
        let uid = getuid()
        shell("/bin/launchctl", ["kickstart", "-p", "gui/\(uid)/\(rotulo)"])
    }

    static func executar(_ c: ComandoManual) -> SaidaComando {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", "setopt rm_star_silent 2>/dev/null; " + c.comando]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe

        guard (try? p.run()) != nil else {
            return SaidaComando(texto: "Não consegui iniciar o shell.", sucesso: false)
        }
        let dados = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        p.waitUntilExit()

        let texto = String(data: dados, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return SaidaComando(texto: texto.isEmpty ? "Feito, sem saída." : texto,
                            sucesso: p.terminationStatus == 0)
    }

    static func abrirNoTerminal(_ c: ComandoManual) {
        let escapado = c.comando
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escapado)"
        end tell
        """
        if let a = NSAppleScript(source: script) {
            var erro: NSDictionary?
            a.executeAndReturnError(&erro)
        }
    }

    static let manual: [ComandoManual] = [

        ComandoManual(
            id: "b0",
            numero: 0,
            titulo: "Preparar o terminal",
            porque: "Roda uma vez por janela do terminal. Desliga os prompts \"sure you want to delete\" do zsh e guarda a senha do sudo pros blocos seguintes.",
            comando: """
            setopt rm_star_silent
            sudo -v
            """,
            risco: .zero,
            ganhoTipico: "—",
            precisaSudo: true),

        ComandoManual(
            id: "b1",
            numero: 1,
            titulo: "Resto do Xcode",
            porque: "Caches de simulador que o sistema guarda fora da sua pasta, e simuladores órfãos de versões antigas do Xcode.",
            comando: """
            sudo rm -rf /Library/Developer/CoreSimulator/Caches
            xcrun simctl delete unavailable
            df -h /System/Volumes/Data | tail -1
            """,
            risco: .zero,
            ganhoTipico: "3–11 GB",
            precisaSudo: true),

        ComandoManual(
            id: "b2",
            numero: 2,
            titulo: "Runtimes tvOS, watchOS e xrOS",
            porque: "Se você não faz app pra Apple TV, Watch ou Vision Pro, esses runtimes só ocupam espaço. O iOS fica intacto. O erase all demora 1 a 2 minutos.",
            comando: """
            for id in $(xcrun simctl runtime list | grep -E '^(tvOS|watchOS|xrOS)' | sed -E 's/.* - ([A-F0-9-]{36}) .*/\\1/'); do
              xcrun simctl runtime delete "$id"
            done
            xcrun simctl runtime delete unusable
            xcrun simctl erase all
            df -h /System/Volumes/Data | tail -1
            """,
            risco: .zero,
            ganhoTipico: "15–45 GB"),

        ComandoManual(
            id: "b3",
            numero: 3,
            titulo: "Caches de dev",
            porque: "CocoaPods, npm, Homebrew, Expo, Electron, Yarn, pnpm, gradle. Tudo volta com um install. Só o próximo build fica mais lento.",
            comando: """
            rm -rf ~/Library/Caches/CocoaPods
            rm -rf ~/Library/Caches/com.microsoft.VSCode.ShipIt
            rm -rf ~/Library/Caches/dotslash
            rm -rf ~/Library/Caches/ReactNative
            rm -rf ~/Library/Caches/electron
            rm -rf ~/Library/Caches/electron-builder
            rm -rf ~/Library/Caches/node-gyp
            rm -rf ~/Library/Caches/Yarn
            rm -rf ~/Library/Caches/pnpm
            rm -rf ~/Library/Caches/Homebrew
            rm -rf ~/.npm/_cacache
            rm -rf ~/.expo
            rm -rf ~/.gradle/caches
            rm -rf ~/.cocoapods/repos/trunk
            brew cleanup --prune=all -s
            df -h /System/Volumes/Data | tail -1
            """,
            risco: .zero,
            ganhoTipico: "3–8 GB"),

        ComandoManual(
            id: "b4",
            numero: 4,
            titulo: "Claude, Chrome e Cursor",
            porque: "Fecha os apps primeiro, senão o cache se regenera na hora. Login e abas do Chrome ficam intactos — só o cache vai embora.",
            comando: """
            osascript -e 'quit app "Google Chrome"'
            osascript -e 'quit app "Cursor"'
            sleep 3
            rm -rf ~/Library/Application\\ Support/Claude/Cache
            rm -rf ~/Library/Application\\ Support/Claude/Code\\ Cache
            rm -rf ~/Library/Application\\ Support/Claude/GPUCache
            rm -rf ~/Library/Application\\ Support/Claude/DawnGraphiteCache
            rm -rf ~/Library/Application\\ Support/Claude/DawnWebGPUCache
            rm -rf ~/Library/Application\\ Support/Claude/logs
            rm -rf ~/Library/Application\\ Support/Claude/Service\\ Worker/CacheStorage
            rm -rf ~/Library/Application\\ Support/Google/Chrome/*/Cache
            rm -rf ~/Library/Application\\ Support/Google/Chrome/*/Code\\ Cache
            rm -rf ~/Library/Application\\ Support/Google/Chrome/*/GPUCache
            rm -rf ~/Library/Application\\ Support/Google/Chrome/*/Service\\ Worker/CacheStorage
            rm -rf ~/Library/Caches/Google
            rm -rf ~/Library/Application\\ Support/Cursor/Cache
            rm -rf ~/Library/Application\\ Support/Cursor/CachedData
            rm -rf ~/Library/Application\\ Support/Cursor/Code\\ Cache
            rm -rf ~/Library/Application\\ Support/Cursor/GPUCache
            df -h /System/Volumes/Data | tail -1
            """,
            risco: .zero,
            ganhoTipico: "5–15 GB"),

        ComandoManual(
            id: "b5",
            numero: 5,
            titulo: "Sistema, logs e Lixeira",
            porque: "Pede senha. Reinicie o Mac em algum momento depois — parte do que é limpo aqui é temporário de app em execução.",
            comando: """
            sudo rm -rf /Library/Caches/*
            sudo rm -rf /private/var/log/*.gz
            sudo rm -rf /private/var/log/asl/*.asl
            sudo rm -rf /private/var/folders/*/*/C/*
            sudo rm -rf /private/var/db/diagnostics/*
            rm -rf ~/Library/Logs/*
            rm -rf ~/.Trash/*
            sudo periodic daily weekly monthly
            df -h /System/Volumes/Data | tail -1
            """,
            risco: .zero,
            ganhoTipico: "1–4 GB",
            precisaSudo: true),

        ComandoManual(
            id: "b6",
            numero: 6,
            titulo: "node_modules, Pods e builds",
            porque: "Reinstala com npm install ou pod install quando for mexer em cada projeto. Não toca no código, só nas dependências baixadas.",
            comando: """
            rm -rf ~/projetos/*/node_modules
            rm -rf ~/projetos/*/*/node_modules
            rm -rf ~/projetos/*/ios/Pods
            rm -rf ~/projetos/*/*/ios/Pods
            rm -rf ~/projetos/*/.next
            rm -rf ~/projetos/*/*/.next
            rm -rf ~/projetos/*/.expo
            rm -rf ~/projetos/*/*/.expo
            df -h /System/Volumes/Data | tail -1
            """,
            risco: .medio,
            ganhoTipico: "3–10 GB"),

        ComandoManual(
            id: "b7",
            numero: 7,
            titulo: "Archives do Xcode",
            porque: "São os dSYMs dos builds que você publicou. Sem eles, um crash report de versão já na loja não é mais simbolizado. Só rode se topar perder isso.",
            comando: """
            rm -rf ~/Library/Developer/Xcode/Archives/*
            df -h /System/Volumes/Data | tail -1
            """,
            risco: .alto,
            ganhoTipico: "1–3 GB"),

        ComandoManual(
            id: "b8",
            numero: 8,
            titulo: "Instaladores e jogos",
            porque: "Os .dmg já foram usados pra instalar. Modrinth e Minecraft só saem se você não joga mais — os mundos salvos vão junto.",
            comando: """
            rm -rf ~/Downloads/*.dmg
            rm -rf ~/Library/Application\\ Support/ModrinthApp
            rm -rf ~/Library/Application\\ Support/minecraft
            rm -rf ~/Library/Caches/ModrinthApp
            rm -rf ~/Library/Application\\ Support/Any\\ Video\\ Converter
            df -h /System/Volumes/Data | tail -1
            """,
            risco: .alto,
            ganhoTipico: "3–8 GB"),

        ComandoManual(
            id: "b9",
            numero: 9,
            titulo: "Caçar o que sobrou",
            porque: "Não apaga nada. É o comando pra rodar quando o disco encher e você não souber por quê — ele mostra o peso fora da sua pasta pessoal, que nenhuma limpeza de usuário alcança.",
            comando: """
            echo "=== FORA DA HOME ==="
            sudo du -sh -x /Applications /Library /usr/local /opt /private/var 2>/dev/null | sort -rh
            echo
            echo "=== APPS MAIORES ==="
            du -sh /Applications/* 2>/dev/null | sort -rh | head -20
            echo
            echo "=== ESPACO PURGAVEL ==="
            diskutil info /System/Volumes/Data | grep -i -E "free|purge|used"
            """,
            risco: .zero,
            ganhoTipico: "—",
            precisaSudo: true,
            soLista: true)
    ]
}
