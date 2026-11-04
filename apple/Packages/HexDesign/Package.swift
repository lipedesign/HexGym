// swift-tools-version: 6.2
// O design system do HexGym (seção 6 do design doc): as cores dos quatro temas, e depois a
// tipografia, o espaçamento, o movimento, os hápticos e os componentes. Um pacote local (seção 8.7)
// que só usa SwiftUI, CoreText e Foundation, para o iPhone e o Watch. O macOS está aqui só para o
// swift test rodar no Mac.
import PackageDescription

let package = Package(
  name: "HexDesign",
  defaultLocalization: "en",
  platforms: [.iOS(.v26), .macOS(.v26), .watchOS(.v26)],
  products: [.library(name: "HexDesign", targets: ["HexDesign"])],
  targets: [
    .target(name: "HexDesign", resources: [.copy("Resources/Fonts"), .process("Resources/Strings")]),
    .testTarget(name: "HexDesignTests", dependencies: ["HexDesign"]),
  ]
)
