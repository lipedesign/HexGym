// swift-tools-version: 6.2
// O motor do openGym no JavaScriptCore (seção 8.2 do design doc): o script do motor num JSContext
// só, dentro de um ator. Sem watchOS, porque o Watch não roda JavaScript. A pasta JS/, com o que o
// script leva além do lib e os testes dele em Node, fica fora dos alvos.
import PackageDescription

let package = Package(
  name: "HexEngine",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [.library(name: "HexEngine", targets: ["HexEngine"])],
  targets: [
    .target(
      name: "HexEngine",
      resources: [
        .copy("Resources/hexengine.js.deflate"),
        .copy("Resources/hexengine.js.sha256"),
        .copy("Resources/host.js"),
        // Os pacotes de idioma (scripts/build-hexgym-langs.mjs) e o index.json deles.
        .copy("Resources/langs"),
      ]
    ),
    .testTarget(name: "HexEngineTests", dependencies: ["HexEngine"], resources: [.copy("Cases")]),
  ]
)
