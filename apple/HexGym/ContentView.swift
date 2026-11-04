// A tela provisória do iPhone: a marca no centro, em fundo preto.
import SwiftUI

struct ContentView: View {
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      Wordmark()
    }
  }
}
