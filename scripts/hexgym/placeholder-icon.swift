// O ícone provisório do HexGym: um PNG de 1024 × 1024, fundo preto e HEX branco, em peso heavy e
// largura condensada, centralizado. O ícone de verdade é decisão do founder, na fase 1.
// O App Store Connect recusa ícone com transparência, então a imagem do ImageRenderer é redesenhada
// num CGContext sem canal alfa (noneSkipLast) antes de virar PNG.
//
//   DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs) swift scripts/hexgym/placeholder-icon.swift \
//     apple/HexGym/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
// O mesmo PNG vai no AppIcon do Watch, copiado.
import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("placeholder-icon: \(message)\n".utf8))
  exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
  FileHandle.standardError.write(Data("uso: swift scripts/hexgym/placeholder-icon.swift <saída.png>\n".utf8))
  exit(2)
}

let side = 1024

// O ImageRenderer é do ator principal. O código do topo do script roda na thread principal, então
// o assumeIsolated só confirma isso.
let rendered: CGImage? = MainActor.assumeIsolated {
  let icon = ZStack {
    Color.black
    Text(verbatim: "HEX")
      .font(.system(size: 400, weight: .heavy))
      .fontWidth(.condensed)
      .foregroundStyle(.white)
  }
  .frame(width: CGFloat(side), height: CGFloat(side))
  let renderer = ImageRenderer(content: icon)
  renderer.scale = 1
  return renderer.cgImage
}
guard let drawn = rendered else { fail("o ImageRenderer não desenhou a imagem") }

guard
  let space = CGColorSpace(name: CGColorSpace.sRGB),
  let context = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fail("não deu para criar o CGContext sem alfa") }
context.draw(drawn, in: CGRect(x: 0, y: 0, width: side, height: side))
guard let opaque = context.makeImage() else { fail("não deu para tirar a imagem do CGContext") }

let url = URL(fileURLWithPath: arguments[1])
guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
  fail("não deu para gravar em \(url.path)")
}
CGImageDestinationAddImage(destination, opaque, nil)
guard CGImageDestinationFinalize(destination) else { fail("não deu para gravar o PNG em \(url.path)") }
print("ícone gravado em \(url.path)")
