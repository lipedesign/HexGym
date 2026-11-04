// swift-tools-version: 6.2
// O documento de dados do HexGym no App Group (seção 8.3 do design doc): o mesmo documento do openGym,
// gravado como JSON, com a cópia anterior e a base de sincronização ao lado. Sem dependências e sem o
// motor, para a gravação ter testes próprios. Ao contrário do HexEngine, vale também no watchOS,
// porque não usa JavaScript.
import PackageDescription

let package = Package(
  name: "HexStore",
  platforms: [.iOS(.v26), .macOS(.v26), .watchOS(.v26)],
  products: [.library(name: "HexStore", targets: ["HexStore"])],
  targets: [
    .target(name: "HexStore"),
    .testTarget(name: "HexStoreTests", dependencies: ["HexStore"]),
  ]
)
