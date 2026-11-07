// swift-tools-version: 6.2
// O corpo muscular do HexGym (seção 9 do design doc): as regiões que cada exercício acende, gravadas
// pelo gerador de scripts/hexbody/regions/ (o --app), e os nomes das 36 regiões em português do
// Brasil e em inglês. Depois da issue #10, também os desenhos e a view do corpo. Um pacote local
// (seção 8.7) que só usa Foundation. O macOS está aqui só para o swift test rodar no Mac.
import PackageDescription

let package = Package(
  name: "HexBody",
  defaultLocalization: "en",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [.library(name: "HexBody", targets: ["HexBody"])],
  targets: [
    .target(name: "HexBody", resources: [.copy("Resources/exercise-regions.json"), .process("Resources/Strings")]),
    .testTarget(name: "HexBodyTests", dependencies: ["HexBody"]),
  ]
)
