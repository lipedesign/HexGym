// A tela provisória do iPhone: a marca no centro, em fundo preto, e embaixo dela as linhas do que
// aconteceu ao abrir (a tabela da Task 10 do plano da fase 0). O detalhe de um erro vai para o log,
// nunca para a tela.
import SwiftUI

struct ContentView: View {
  let model: AppModel

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      VStack(spacing: 24) {
        Wordmark()
        StatusLines(state: model.state)
      }
      .padding()
    }
  }
}

// Uma linha por estado: abrindo; o motor e a origem do documento; ou o erro.
private struct StatusLines: View {
  let state: AppModel.State

  var body: some View {
    VStack(spacing: 6) {
      switch state {
      case .starting:
        Text("Opening…")
      case .ready(let status):
        Text("Engine loaded · \(status.exercises) exercises")
        switch status.origin {
        case .created: Text("Document created")
        case .opened: Text("Document opened")
        case .recovered: Text("Document restored from the previous copy")
        }
      case .failed:
        Text("Couldn't open your data.")
      }
    }
    .font(.callout)
    .foregroundStyle(.secondary)
    .multilineTextAlignment(.center)
    .accessibilityElement(children: .combine)
  }
}
