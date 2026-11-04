// O ícone do HexGym (Task 12 do plano da fase 1, issue #66), no lugar do provisório da fase 0: fundo
// preto, um hexágono de topo reto só no contorno, em #8B7BFF, inclinado 18° como os segmentos, e atrás
// dele o brilho do Ultravioleta. Grava os quatro PNGs:
//   - no AppIcon do iPhone, o AppIcon.png (o normal), o AppIcon-dark.png (igual ao normal, porque o
//     ícone já é escuro) e o AppIcon-tinted.png (em tons de cinza, o hexágono branco no preto e sem
//     brilho, para o sistema tingir);
//   - no AppIcon do Watch, o AppIcon.png, igual ao normal.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) swift scripts/hexgym/app-icon.swift \
//     apple/HexGym/Assets.xcassets/AppIcon.appiconset apple/HexGymWatch/Assets.xcassets/AppIcon.appiconset
//
// Todos têm 1024 × 1024 e nenhum canal alfa (o App Store Connect recusa ícone com transparência):
// cada um é desenhado num CGContext em Display P3 com noneSkipLast e gravado em PNG pelo ImageIO.
// O desenho não depende de fonte nem de hora, então duas rodadas gravam os mesmos bytes.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o ícone desta Task, que é o "ícone de
// verdade" que a Task 9 da fase 0 deixou para a fase 1.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("app-icon: \(message)\n".utf8))
  exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
  FileHandle.standardError.write(Data("uso: swift scripts/hexgym/app-icon.swift <AppIcon do iPhone> <AppIcon do Watch>\n".utf8))
  exit(2)
}

// As cores do Ultravioleta, copiadas do HexDesign (HexPalette.swift, Task 1), porque um script swift
// solto não importa o pacote. Quem mudar uma delas lá muda aqui também.
// O accent do app no escuro, em sRGB; vai para o mesmo ponto do Display P3 como no HexRGB.displayP3.
let accent: UInt32 = 0x8B7BFF
// O brilho, já em Display P3, com a opacidade.
let glow: (red: CGFloat, green: CGFloat, blue: CGFloat, opacity: CGFloat) = (0.4221, 0.3535, 0.9822, 0.85)

// As medidas, em fração do lado do ícone.
let side = 1024
let across = 0.58  // o hexágono de ponta a ponta, na linha do meio do traço
let stroke = 0.10  // a espessura do traço
let slant = 18.0  // a inclinação, em graus, como a dos segmentos: o alto puxa para a direita
let reach = 0.6  // o raio do brilho, como o alcance do BreathingGlow

// Do sRGB para o Display P3, como o HexRGB.displayP3 do pacote: tira a curva do sRGB, passa do sRGB
// linear para o Display P3 linear (os dois com o branco D65) e põe de volta a mesma curva.
func displayP3(_ hex: UInt32) -> [CGFloat] {
  let srgb = [Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255]
  let linear = srgb.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
  let matrix: [[Double]] = [
    [0.8224621, 0.1775380, 0],
    [0.0331941, 0.9668058, 0],
    [0.0170827, 0.0723974, 0.9105199],
  ]
  return matrix.map { row in
    let light = row[0] * linear[0] + row[1] * linear[1] + row[2] * linear[2]
    let component = light <= 0.0031308 ? light * 12.92 : 1.055 * pow(light, 1 / 2.4) - 0.055
    return CGFloat(min(max(component, 0), 1))
  }
}

guard let space = CGColorSpace(name: CGColorSpace.displayP3) else { fail("não deu para abrir o Display P3") }

func color(_ components: [CGFloat], _ opacity: CGFloat = 1) -> CGColor {
  guard let made = CGColor(colorSpace: space, components: components + [opacity]) else { fail("não deu para criar a cor") }
  return made
}

// O hexágono de topo reto, com o centro no meio do ícone: as seis pontas no círculo de raio
// across / 2, a primeira na direita. Depois, a inclinação: cada ponto anda para a direita
// tan(18°) vezes a altura dele em relação ao centro, como um paralelogramo dos segmentos. As pontas
// da esquerda e da direita ficam na altura do centro e não andam, então a medida de ponta a ponta
// continua a mesma, e o topo e a base continuam retos.
func hexagon() -> CGPath {
  let center = CGFloat(side) / 2, radius = CGFloat(across) * CGFloat(side) / 2
  let shear = CGFloat(tan(slant * .pi / 180))
  let path = CGMutablePath()
  for corner in 0..<6 {
    let angle = CGFloat(corner) * .pi / 3
    let x = radius * cos(angle), y = radius * sin(angle)
    let point = CGPoint(x: center + x + shear * y, y: center + y)
    if corner == 0 { path.move(to: point) } else { path.addLine(to: point) }
  }
  path.closeSubpath()
  return path
}

// Um ícone: o fundo preto, o brilho (quando há) e o contorno do hexágono, com cantos vivos como os
// dos segmentos.
func draw(line: CGColor, withGlow: Bool) -> CGImage {
  guard
    let context = CGContext(
      data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
  else { fail("não deu para criar o CGContext sem alfa") }
  let full = CGRect(x: 0, y: 0, width: side, height: side)
  context.setFillColor(color([0, 0, 0]))
  context.fill(full)

  // O brilho atrás do hexágono: um gradiente radial do meio do ícone, da cor do brilho, na opacidade
  // dele, até zero, com raio de reach do lado.
  if withGlow {
    let rgb = [glow.red, glow.green, glow.blue]
    guard
      let gradient = CGGradient(
        colorsSpace: space, colors: [color(rgb, glow.opacity), color(rgb, 0)] as CFArray, locations: [0, 1])
    else { fail("não deu para criar o gradiente do brilho") }
    let center = CGPoint(x: full.midX, y: full.midY)
    context.drawRadialGradient(
      gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: CGFloat(reach) * CGFloat(side), options: [])
  }

  context.setShouldAntialias(true)
  context.setStrokeColor(line)
  context.setLineWidth(CGFloat(stroke) * CGFloat(side))
  context.setLineJoin(.miter)
  context.addPath(hexagon())
  context.strokePath()
  guard let image = context.makeImage() else { fail("não deu para tirar a imagem do CGContext") }
  return image
}

func write(_ image: CGImage, to folder: String, _ name: String) {
  let url = URL(fileURLWithPath: folder).appendingPathComponent(name)
  guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fail("não deu para gravar em \(url.path)")
  }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else { fail("não deu para gravar o PNG em \(url.path)") }
  print("ícone gravado em \(url.path)")
}

let (phone, watch) = (arguments[1], arguments[2])
for folder in [phone, watch] {
  var isFolder: ObjCBool = false
  guard FileManager.default.fileExists(atPath: folder, isDirectory: &isFolder), isFolder.boolValue else {
    fail("a pasta \(folder) não existe")
  }
}

let normal = draw(line: color(displayP3(accent)), withGlow: true)
let tinted = draw(line: color([1, 1, 1]), withGlow: false)
write(normal, to: phone, "AppIcon.png")
write(normal, to: phone, "AppIcon-dark.png")
write(tinted, to: phone, "AppIcon-tinted.png")
write(normal, to: watch, "AppIcon.png")
