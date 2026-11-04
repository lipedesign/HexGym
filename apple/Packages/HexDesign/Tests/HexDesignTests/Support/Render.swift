// O que os testes do HexDesign usam para desenhar e medir as views sem tela, com o ImageRenderer do
// SwiftUI. Os testes de print usam @Test(.enabled(if: printsEnabled)): gravam PNGs na pasta de
// HEXDESIGN_PRINTS e ficam pulados sem ela.
//
//   HEXDESIGN_PRINTS=$PWD/docs/hexgym/prints/<issue> DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) \
//     swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) --package-path apple/Packages/HexDesign \
//     --filter <teste de print>
//
// Todo desenho passa pelo picture(_:scale:space:): o ImageRenderer entrega os comandos de desenho, e o
// CoreGraphics pinta num bitmap nosso. O cgImage do ImageRenderer pinta por outro caminho, que muda até
// 1 nível em alguns pixels de borda de uma rodada para outra (os prints da Task 5 variavam assim); o
// CoreGraphics dá os mesmos bytes toda vez, e o print sai igual byte a byte entre duas gerações.

import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers

// A pasta dos prints: o HEXDESIGN_PRINTS do ambiente, quando ele existe e não é vazio.
let printsFolder: String? = {
  let path = ProcessInfo.processInfo.environment["HEXDESIGN_PRINTS"] ?? ""
  return path.isEmpty ? nil : path
}()

// Liga os testes de print.
let printsEnabled = printsFolder != nil

// A escala dos prints.
let printScale: CGFloat = 2

// A view no palco dos testes: no esquema escuro e com fundo preto, como o app do primeiro TestFlight.
@MainActor func staged(_ view: some View) -> some View {
  view.environment(\.colorScheme, .dark).background(Color.black)
}

// A view, no palco, pintada pelo CoreGraphics num bitmap de 8 bits no espaço de cor pedido, sem alfa,
// na escala pedida. Cada chamada usa um ImageRenderer novo. Nil quando o ImageRenderer não desenha.
@MainActor func picture(_ view: some View, scale: CGFloat, space name: CFString = CGColorSpace.displayP3) -> CGImage? {
  var picture: CGImage?
  ImageRenderer(content: staged(view)).render(rasterizationScale: scale) { size, draw in
    guard let space = CGColorSpace(name: name),
          let context = CGContext(
            data: nil, width: Int((size.width * scale).rounded(.up)), height: Int((size.height * scale).rounded(.up)),
            bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { return }
    context.scaleBy(x: scale, y: scale)
    draw(context)
    picture = context.makeImage()
  }
  return picture
}

// A view desenhada em escala 1, no palco, em sRGB de 8 bits. Nil quando o ImageRenderer não consegue
// desenhar.
@MainActor func image(_ view: some View) -> CGImage? {
  picture(view, scale: 1, space: CGColorSpace.sRGB)
}

// O tamanho ideal da view, em pontos, medido com .fixedSize(): o que o ImageRenderer entrega ao
// desenhar, sem arredondar para o pixel.
@MainActor func size(_ view: some View) -> CGSize {
  var measured = CGSize.zero
  ImageRenderer(content: view.fixedSize()).render { size, _ in measured = size }
  return measured
}

// A largura ideal da view, em pontos.
@MainActor func width(_ view: some View) -> CGFloat {
  size(view).width
}

// A média de luz do quinto da esquerda e do quinto da direita da imagem da view, de 0 (preto) a 1
// (branco), pela luminância dos componentes em sRGB. Zero nos dois lados quando a view não desenha.
@MainActor func brightness(_ view: some View) -> (left: Double, right: Double) {
  guard let image = image(view), let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return (0, 0) }
  let (width, height, row, step) = (image.width, image.height, image.bytesPerRow, image.bitsPerPixel / 8)
  let fifth = max(width / 5, 1)
  func light(_ columns: Range<Int>) -> Double {
    var total = 0.0
    for y in 0..<height {
      for x in columns {
        let pixel = bytes + y * row + x * step
        total += (0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])) / 255
      }
    }
    return total / Double(max(columns.count * height, 1))
  }
  return (light(0..<fifth), light((width - fifth)..<width))
}

// Um estado da folha de um print: a view, no palco, desenhada num ImageRenderer só dela, em Display P3
// e na escala do print, devolvida como imagem para a folha.
@MainActor func still(_ view: some View) throws -> Image {
  Image(decorative: try #require(picture(view, scale: printScale), "o ImageRenderer não desenhou um estado"), scale: printScale)
}

// Grava a view, no palco, como <name>.png na pasta de HEXDESIGN_PRINTS, na escala do print, e cria a
// pasta quando ela falta. O PNG leva o perfil Display P3 do bitmap: um desenho em sRGB cortaria o P3
// vivo do brilho.
@MainActor func writePrint(_ view: some View, named name: String) throws {
  let path = try #require(printsFolder, "HEXDESIGN_PRINTS não está no ambiente")
  try #require(path.hasPrefix("/"), "HEXDESIGN_PRINTS precisa ser uma pasta absoluta, e veio \(path)")
  let image = try #require(picture(view, scale: printScale), "o ImageRenderer não desenhou \(name).png")
  let folder = URL(fileURLWithPath: path, isDirectory: true)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let file = folder.appending(path: "\(name).png")
  let destination = try #require(CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil))
  CGImageDestinationAddImage(destination, image, nil)
  try #require(CGImageDestinationFinalize(destination), "não deu para gravar \(file.path)")
}
