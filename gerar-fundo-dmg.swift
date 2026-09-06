import Foundation
import AppKit

func cor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a).cgColor
}

let L: CGFloat = 660
let A: CGFloat = 420

func desenhar(_ escala: CGFloat) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    ctx.scaleBy(x: escala, y: escala)

    let espaco = CGColorSpaceCreateDeviceRGB()

    let fundo = CGGradient(colorsSpace: espaco,
                           colors: [cor(31, 33, 45), cor(14, 15, 22)] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(fundo,
                           start: CGPoint(x: 0, y: A),
                           end: CGPoint(x: L, y: 0),
                           options: [])

    ctx.saveGState()
    ctx.setBlendMode(.plusLighter)
    let brilho = CGGradient(colorsSpace: espaco,
                            colors: [cor(129, 132, 255, 0.16), cor(129, 132, 255, 0)] as CFArray,
                            locations: [0, 1])!
    ctx.drawRadialGradient(brilho,
                           startCenter: CGPoint(x: L * 0.22, y: A * 0.72), startRadius: 0,
                           endCenter: CGPoint(x: L * 0.22, y: A * 0.72), endRadius: L * 0.5,
                           options: [])
    ctx.restoreGState()

    let marcaX: CGFloat = 42
    let marcaY: CGFloat = A - 62
    let lado: CGFloat = 26
    let vao: CGFloat = 3

    func quad(_ r: CGRect, _ c1: CGColor, _ c2: CGColor) {
        let p = CGPath(roundedRect: r, cornerWidth: 3, cornerHeight: 3, transform: nil)
        ctx.saveGState(); ctx.addPath(p); ctx.clip()
        let g = CGGradient(colorsSpace: espaco, colors: [c1, c2] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: r.minX, y: r.maxY),
                               end: CGPoint(x: r.maxX, y: r.minY), options: [])
        ctx.restoreGState()
    }

    let lg = lado * 0.55
    quad(CGRect(x: marcaX, y: marcaY, width: lg, height: lado),
         cor(129, 132, 255), cor(88, 92, 232))
    quad(CGRect(x: marcaX + lg + vao, y: marcaY + lado * 0.42,
                width: lado - lg - vao, height: lado * 0.58),
         cor(126, 205, 226), cor(88, 168, 196))

    let vazio = CGRect(x: marcaX + lg + vao, y: marcaY,
                       width: lado - lg - vao, height: lado * 0.42 - vao)
    let pv = CGPath(roundedRect: vazio, cornerWidth: 2, cornerHeight: 2, transform: nil)
    ctx.addPath(pv)
    ctx.setStrokeColor(cor(255, 255, 255, 0.32))
    ctx.setLineWidth(1)
    ctx.strokePath()

    func escrever(_ texto: String, _ x: CGFloat, _ y: CGFloat,
                  _ tamanho: CGFloat, _ peso: NSFont.Weight, _ c: NSColor) {
        let fonte = NSFont.systemFont(ofSize: tamanho, weight: peso)
        let attrs: [NSAttributedString.Key: Any] = [.font: fonte, .foregroundColor: c]
        NSString(string: texto).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }

    escrever("Espaço", marcaX + lado + 14, marcaY + 3, 22, .semibold,
             NSColor(srgbRed: 0.93, green: 0.94, blue: 0.97, alpha: 1))

    escrever("Arraste para a pasta Aplicativos", marcaX, marcaY - 30, 14, .regular,
             NSColor(srgbRed: 0.62, green: 0.64, blue: 0.72, alpha: 1))

    let seta = CGMutablePath()
    let y = A * 0.46
    seta.move(to: CGPoint(x: L * 0.40, y: y))
    seta.addLine(to: CGPoint(x: L * 0.585, y: y))
    ctx.addPath(seta)
    ctx.setStrokeColor(cor(255, 255, 255, 0.22))
    ctx.setLineWidth(2)
    ctx.setLineDash(phase: 0, lengths: [6, 6])
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])

    let ponta = CGMutablePath()
    ponta.move(to: CGPoint(x: L * 0.585 + 9, y: y))
    ponta.addLine(to: CGPoint(x: L * 0.585 - 3, y: y + 6))
    ponta.addLine(to: CGPoint(x: L * 0.585 - 3, y: y - 6))
    ponta.closeSubpath()
    ctx.addPath(ponta)
    ctx.setFillColor(cor(255, 255, 255, 0.30))
    ctx.fillPath()

    escrever("diaselegaletalvez.github.io/espaco", marcaX, 26, 11, .regular,
             NSColor(srgbRed: 0.42, green: 0.44, blue: 0.52, alpha: 1))
}

func exportar(_ escala: CGFloat, _ caminho: String) {
    let px = Int(L * escala)
    let py = Int(A * escala)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: px, pixelsHigh: py,
                                     bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { return }
    rep.size = NSSize(width: L, height: A)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    desenhar(escala)
    NSGraphicsContext.restoreGraphicsState()

    guard let dados = rep.representation(using: .png, properties: [:]) else { return }
    try? dados.write(to: URL(fileURLWithPath: caminho))
    print("  \(px)x\(py) -> \(caminho)")
}

let destino = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist"
try? FileManager.default.createDirectory(atPath: destino, withIntermediateDirectories: true)

print("gerando fundo do dmg")
exportar(1, "\(destino)/fundo-dmg.png")
exportar(2, "\(destino)/fundo-dmg@2x.png")
