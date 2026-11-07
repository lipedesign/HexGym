// As licenças (Task 6 do plano da fase 2): o aviso de que o HexGym é um fork não oficial do openGym
// e o crédito do que vem de outros, cada um com o texto inteiro da licença numa tela própria:
//   - o openGym, sob a AGPL-3.0-or-later, com o endereço do código dele e do código do HexGym (o
//     texto é o LICENSE da raiz do repositório, copiado para Licenses/LICENSE-openGym.txt);
//   - a Barlow Condensed, sob a SIL OFL 1.1, com o OFL.txt que vai junto com a fonte no HexDesign;
//   - o MuscleMap, de Melih Colpan, sob a MIT, de onde vem o mapa dos músculos (o texto é o
//     scripts/hexbody/musclemap/LICENSE-MuscleMap, copiado para Licenses/LICENSE-MuscleMap.txt).
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: uma seção por obra, com o texto da
// licença numa tela que abre, e o texto inteiro também da AGPL, que pede uma cópia junto com o app.
import HexDesign
import SwiftUI

struct LicensesView: View {
  var body: some View {
    List {
      Section {
        Text("HexGym is an unofficial fork of openGym, not made or endorsed by its author. Its code is public, under the same license.")
      }
      LicenseSection(
        work: "openGym", license: "AGPL-3.0-or-later", holder: "© 2026 Duarte Santos",
        purpose: "The rules of the app: exercises, routines and progression.", text: .bundle("LICENSE-openGym")
      ) {
        Link("openGym source code", destination: URL(string: "https://github.com/DuarteSantos8/openGym")!)
        Link("HexGym source code", destination: URL(string: "https://github.com/lipedesign/HexGym")!)
      }
      LicenseSection(
        work: "Barlow Condensed", license: "SIL Open Font License 1.1", holder: "© 2017 The Barlow Project Authors",
        purpose: "The typeface of numbers and titles.", text: .url(HexFonts.licenseURL))
      LicenseSection(
        work: "MuscleMap", license: "MIT", holder: "© 2026 Melih Colpan",
        purpose: "The muscle map of the body.", text: .bundle("LICENSE-MuscleMap"))
    }
    .scrollContentBackground(.hidden)
    .navigationTitle("Licenses")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(for: LicenseText.self) { LicenseTextView(text: $0) }
    .containerBackground(.clear, for: .navigation)
  }
}

// O texto de uma licença: um .txt do app ou um arquivo de um pacote.
struct LicenseText: Hashable {
  let title: String
  let url: URL?

  enum Source { case bundle(String), url(URL?) }

  init(title: String, source: Source) {
    self.title = title
    switch source {
    case .bundle(let name): url = Bundle.main.url(forResource: name, withExtension: "txt")
    case .url(let url): self.url = url
    }
  }

  // O texto com os parágrafos juntados: os arquivos quebram a linha em 72 colunas, e na largura do
  // iPhone, com Dynamic Type, essas quebras cortariam as frases no meio. Uma linha em branco separa
  // os parágrafos, e uma linha só de traços fica sozinha.
  func paragraphs() -> [String] {
    guard let url, let raw = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    var result: [String] = [], current: [String] = []
    func close() {
      if !current.isEmpty { result.append(current.joined(separator: " ")) }
      current = []
    }
    for line in raw.components(separatedBy: .newlines).map({ $0.trimmingCharacters(in: .whitespaces) }) {
      if line.isEmpty { close(); continue }
      if line.allSatisfy({ $0 == "-" || $0 == "=" }) { close(); continue }
      current.append(line)
    }
    close()
    return result
  }
}

// Uma obra: o nome, a licença, quem tem os direitos, o que ela faz no HexGym, os links e o texto.
private struct LicenseSection<Links: View>: View {
  let work: String
  let license: String
  let holder: String
  let purpose: LocalizedStringKey
  let text: LicenseText.Source
  @ViewBuilder let links: Links

  init(
    work: String, license: String, holder: String, purpose: LocalizedStringKey, text: LicenseText.Source,
    @ViewBuilder links: () -> Links = { EmptyView() }
  ) {
    self.work = work
    self.license = license
    self.holder = holder
    self.purpose = purpose
    self.text = text
    self.links = links()
  }

  var body: some View {
    Section {
      WholePointHeight {
        VStack(alignment: .leading, spacing: HexSpacing.xxs) {
          Text(verbatim: license).foregroundStyle(Color.white)
          Text(verbatim: holder).font(.subheadline).foregroundStyle(.secondary)
          Text(purpose).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, HexSpacing.xxs)
      }
      .accessibilityElement(children: .combine)
      links
      NavigationLink(value: LicenseText(title: work, source: text)) { Text("License text") }
    } header: {
      SettingsHeader(verbatim: work)
    }
  }
}

// O texto inteiro de uma licença, para ler e copiar.
private struct LicenseTextView: View {
  let text: LicenseText
  // Lido uma vez, quando a tela abre, e não a cada body.
  @State private var paragraphs: [String] = []

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: HexSpacing.s) {
        ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
          Text(verbatim: paragraph)
            .font(.footnote)
            .foregroundStyle(Color.white)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .textSelection(.enabled)
      .padding(.horizontal, HexSpacing.m)
      .padding(.vertical, HexSpacing.l)
    }
    .navigationTitle(Text(verbatim: text.title))
    .navigationBarTitleDisplayMode(.inline)
    .containerBackground(.clear, for: .navigation)
    .task { paragraphs = text.paragraphs() }
  }
}
