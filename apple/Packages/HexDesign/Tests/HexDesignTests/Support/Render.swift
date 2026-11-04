// O que os testes do HexDesign usam para desenhar e medir as views sem tela, com o ImageRenderer do
// SwiftUI. Os testes de print usam @Test(.enabled(if: printsEnabled)): gravam PNGs na pasta de
// HEXDESIGN_PRINTS e ficam pulados sem ela.
//
//   HEXDESIGN_PRINTS=$PWD/docs/hexgym/prints/<issue> DEVELOPER_DIR=$(node scripts/hexgym/xcode.mjs --swift) \
//     swift test $(node scripts/hexgym/xcode.mjs --swift-test-flags) --package-path apple/Packages/HexDesign \
//     --filter <teste de print>

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

// A view no palco dos testes: no esquema escuro e com fundo preto, como o app do primeiro TestFlight.
@MainActor func staged(_ view: some View) -> some View {
  view.environment(\.colorScheme, .dark).background(Color.black)
}

// A view desenhada em escala 1, no palco: o cgImage do ImageRenderer, em sRGB de 8 bits. Nil quando
// o ImageRenderer não consegue desenhar.
@MainActor func image(_ view: some View) -> CGImage? {
  let renderer = ImageRenderer(content: staged(view))
  renderer.scale = 1
  return renderer.cgImage
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

// Grava a view, no palco, como <name>.png na pasta de HEXDESIGN_PRINTS, em escala 2, e cria a pasta
// quando ela falta. O desenho vai para um bitmap em Display P3, e o PNG leva esse perfil: o cgImage
// do ImageRenderer sai em sRGB e cortaria o P3 vivo do brilho.
@MainActor func writePrint(_ view: some View, named name: String) throws {
  let path = try #require(printsFolder, "HEXDESIGN_PRINTS não está no ambiente")
  try #require(path.hasPrefix("/"), "HEXDESIGN_PRINTS precisa ser uma pasta absoluta, e veio \(path)")
  let scale: CGFloat = 2
  var picture: CGImage?
  ImageRenderer(content: staged(view)).render(rasterizationScale: scale) { size, draw in
    guard let space = CGColorSpace(name: CGColorSpace.displayP3),
          let context = CGContext(
            data: nil, width: Int((size.width * scale).rounded(.up)), height: Int((size.height * scale).rounded(.up)),
            bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { return }
    context.scaleBy(x: scale, y: scale)
    draw(context)
    picture = context.makeImage()
  }
  let image = try #require(picture, "o ImageRenderer não desenhou \(name).png")
  let folder = URL(fileURLWithPath: path, isDirectory: true)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let file = folder.appending(path: "\(name).png")
  let destination = try #require(CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil))
  CGImageDestinationAddImage(destination, image, nil)
  try #require(CGImageDestinationFinalize(destination), "não deu para gravar \(file.path)")
}
