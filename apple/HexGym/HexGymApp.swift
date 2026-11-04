// O app do iPhone. Ao abrir, carrega o motor e o documento de dados (AppModel), e a tela provisória
// mostra a marca e o que aconteceu.
import SwiftUI

@main
struct HexGymApp: App {
  @State private var model = AppModel.live()

  var body: some Scene {
    WindowGroup {
      ContentView(model: model)
        .task { await model.start() }
    }
  }
}
