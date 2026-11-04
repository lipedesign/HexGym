// O app do Apple Watch. Nesta fase, só a tela provisória com a marca do HexDesign, no centro, em fundo
// preto. O Watch não roda JavaScript: nada de JavaScriptCore nem do HexEngine aqui.
import HexDesign
import SwiftUI

@main
struct HexGymWatchApp: App {
  var body: some Scene {
    WindowGroup {
      ZStack {
        Color.black.ignoresSafeArea()
        HexWordmark(size: 30)
      }
    }
  }
}
