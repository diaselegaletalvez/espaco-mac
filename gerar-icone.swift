import Foundation
import AppKit

func cor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a).cgColor
}

func desenhar(_ s: CGFloat) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }

    ctx.setFillColor(NSColor.clear.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

    let margem = s * 0.086
    let quadro = CGRect(x: margem, y: margem, width: s - 2*margem, height: s - 2*margem)
    let raio = quadro.width * 0.2237
    let squircle = CGPath(roundedRect: quadro, cornerWidth: raio, cornerHeight: raio, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.014),
                  blur: s * 0.038,
                  color: cor(0, 0, 0, 0.5))
    ctx.addPath(squircle)
    ctx.setFillColor(cor(20, 21, 28))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    let espaco = CGColorSpaceCreateDeviceRGB()
    let fundo = CGGradient(colorsSpace: espaco,
                           colors: [cor(41, 43, 58), cor(17, 18, 26)] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(fundo,
                           start: CGPoint(x: quadro.minX, y: quadro.maxY),
                           end: CGPoint(x: quadro.maxX, y: quadro.minY),
                           options: [])

    let recuo = quadro.width * 0.152
    let area = quadro.insetBy(dx: recuo, dy: recuo)
    let vao = area.width * 0.058
    let cantoBloco = area.width * 0.075

    let largEsq = area.width * 0.545
    let blocoA = CGRect(x: area.minX, y: area.minY, width: largEsq, height: area.height)

    let xDir = area.minX + largEsq + vao
    let largDir = area.maxX - xDir
    let altB = area.height * 0.585 - vao/2
    let blocoB = CGRect(x: xDir, y: area.maxY - altB, width: largDir, height: altB)
    let blocoC = CGRect(x: xDir, y: area.minY, width: largDir, height: area.height - altB - vao)

    func bloco(_ r: CGRect, _ c1: CGColor, _ c2: CGColor) {
        let p = CGPath(roundedRect: r, cornerWidth: cantoBloco, cornerHeight: cantoBloco, transform: nil)
        ctx.saveGState()
        ctx.addPath(p)
        ctx.clip()
        let g = CGGradient(colorsSpace: espaco, colors: [c1, c2] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g,
                               start: CGPoint(x: r.minX, y: r.maxY),
                               end: CGPoint(x: r.maxX, y: r.minY),
                               options: [])
        ctx.restoreGState()
    }

    bloco(blocoA, cor(129, 132, 255), cor(88, 92, 232))
    bloco(blocoB, cor(126, 205, 226), cor(88, 168, 196))

    let pc = CGPath(roundedRect: blocoC, cornerWidth: cantoBloco, cornerHeight: cantoBloco, transform: nil)
    ctx.addPath(pc)
    ctx.setFillColor(cor(255, 255, 255, 0.07))
    ctx.fillPath()

    ctx.addPath(pc)
    ctx.setStrokeColor(cor(255, 255, 255, 0.30))
    ctx.setLineWidth(max(1, s * 0.011))
    ctx.strokePath()

    let brilho = CGGradient(colorsSpace: espaco,
                            colors: [cor(255, 255, 255, 0.14), cor(255, 255, 255, 0)] as CFArray,
                            locations: [0, 1])!
    ctx.drawLinearGradient(brilho,
                           start: CGPoint(x: quadro.minX, y: quadro.maxY),
                           end: CGPoint(x: quadro.minX, y: quadro.midY),
                           options: [])

    ctx.restoreGState()
}

func exportar(_ px: Int, _ caminho: String) {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: px, pixelsHigh: px,
                                     bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { return }
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    desenhar(CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()

    guard let dados = rep.representation(using: .png, properties: [:]) else { return }
    try? dados.write(to: URL(fileURLWithPath: caminho))
    print("  \(px)x\(px)")
}

let destino = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Espaco/Assets.xcassets/AppIcon.appiconset"

try? FileManager.default.createDirectory(atPath: destino,
                                         withIntermediateDirectories: true)

let saidas: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

print("gerando em \(destino)")
for (px, nome) in saidas {
    exportar(px, "\(destino)/\(nome)")
}

let contents = """
{
  "images" : [
    {"filename":"icon_16x16.png","idiom":"mac","scale":"1x","size":"16x16"},
    {"filename":"icon_16x16@2x.png","idiom":"mac","scale":"2x","size":"16x16"},
    {"filename":"icon_32x32.png","idiom":"mac","scale":"1x","size":"32x32"},
    {"filename":"icon_32x32@2x.png","idiom":"mac","scale":"2x","size":"32x32"},
    {"filename":"icon_128x128.png","idiom":"mac","scale":"1x","size":"128x128"},
    {"filename":"icon_128x128@2x.png","idiom":"mac","scale":"2x","size":"128x128"},
    {"filename":"icon_256x256.png","idiom":"mac","scale":"1x","size":"256x256"},
    {"filename":"icon_256x256@2x.png","idiom":"mac","scale":"2x","size":"256x256"},
    {"filename":"icon_512x512.png","idiom":"mac","scale":"1x","size":"512x512"},
    {"filename":"icon_512x512@2x.png","idiom":"mac","scale":"2x","size":"512x512"}
  ],
  "info" : {"author":"xcode","version":1}
}
"""
try? contents.write(toFile: "\(destino)/Contents.json", atomically: true, encoding: .utf8)
print("Contents.json escrito")
