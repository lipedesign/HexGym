// A tela provisória do iPhone: a marca no centro, sobre o brilho da raiz, as linhas do que aconteceu
// ao abrir (a tabela da Task 10 do plano da fase 0) e, embaixo delas, o botão que abre a galeria do
// design system. O detalhe de um erro vai para o log, nunca para a tela.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o botão principal "Galeria do design
// system" embaixo da linha de estado, num NavigationStack.
import HexDesign
import SwiftUI

struct ContentView: View {
  let model: AppModel
  // A galeria já aberta quando o app começa com -HexGymGallery YES (os prints e o vídeo do PR).
  @State private var path = NavigationPath(GalleryLaunch.opensGallery ? [GalleryRoute.gallery] : [])

  var body: some View {
    NavigationStack(path: $path) {
      VStack(spacing: HexSpacing.l) {
        HexWordmark()
        StatusLines(state: model.state)
        NavigationLink(value: GalleryRoute.gallery) {
          Text("Design system gallery")
        }
        .buttonStyle(.hexPrimary)
      }
      .padding(HexSpacing.m)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      // O fundo da pilha fica transparente, para o brilho da raiz aparecer atrás.
      .containerBackground(.clear, for: .navigation)
      .navigationDestination(for: GalleryRoute.self) { _ in GalleryView(path: $path) }
    }
  }
}

// Para onde a tela provisória leva.
enum GalleryRoute: Hashable {
  case gallery
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
