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
    ScrollViewReader { proxy in
      list
        .task {
          // -HexGymSection opengym rola até os links do código, para o print em AX5 mostrar as setas.
          guard SettingsLaunch.anchor == SettingsAnchor.opengym else { return }
          try? await Task.sleep(for: .milliseconds(600))
          proxy.scrollTo(SettingsAnchor.opengym, anchor: .top)
        }
    }
  }

  private var list: some View {
    List {
      Section {
        Text("HexGym is an unofficial fork of openGym, not made or endorsed by its author. Its code is public, under the same license.")
      }
      LicenseSection(
        work: "openGym", license: "AGPL-3.0-or-later", holder: "© 2026 Duarte Santos",
        purpose: "The rules of the app: exercises, routines and progression.", text: .bundle("LICENSE-openGym")
      ) {
        SourceLink("openGym source code", destination: URL(string: "https://github.com/DuarteSantos8/openGym")!)
          .id(SettingsAnchor.opengym)
        SourceLink("HexGym source code", destination: URL(string: "https://github.com/lipedesign/HexGym")!)
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

  // Os parágrafos do arquivo (LicenseParagraphs), ou nenhum, se ele não abriu.
  func paragraphs() -> [String] {
    guard let url, let raw = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    return LicenseParagraphs.split(raw)
  }
}

// O texto de uma licença em parágrafos: os arquivos quebram a linha em 72 colunas, e na largura do
// iPhone, com Dynamic Type, essas quebras cortariam as frases no meio. As linhas de um bloco se
// juntam num parágrafo; uma linha em branco ou só de traços separa os blocos; e o título de uma seção
// (o "PREAMBLE" e o "TERMINATION" da OFL, o "TERMS AND CONDITIONS" da AGPL) fica num parágrafo
// próprio, em vez de grudar no texto dele. Testado no SettingsRowsTests.
enum LicenseParagraphs {
  static func split(_ raw: String) -> [String] {
    var result: [String] = [], current: [String] = []
    func close() {
      if !current.isEmpty { result.append(current.joined(separator: " ")) }
      current = []
    }
    for line in raw.components(separatedBy: .newlines).map({ $0.trimmingCharacters(in: .whitespaces) }) {
      if line.isEmpty || line.allSatisfy({ $0 == "-" || $0 == "=" }) { close(); continue }
      if current.isEmpty, isHeading(line) {
        result.append(line)
        continue
      }
      current.append(line)
    }
    close()
    return result
  }

  // Um título: a primeira linha de um bloco, com letras e nenhuma minúscula, curta e sem a vírgula ou
  // o ponto de uma frase. Os avisos de garantia, também em maiúsculas, começam com linhas longas que
  // continuam na seguinte, e ficam inteiros.
  static func isHeading(_ line: String) -> Bool {
    line.count <= 40 && line.contains(where: \.isLetter) && !line.contains(where: \.isLowercase)
      && !line.hasSuffix(",") && !line.hasSuffix(".")
  }
}

// Um link para fora do app, com a seta "arrow.up.right" à direita, no lugar e no cinza da seta de
// navegação da List, para não parecer texto parado. O texto segue o tint branco da raiz.
private struct SourceLink: View {
  let title: LocalizedStringKey
  let destination: URL

  init(_ title: LocalizedStringKey, destination: URL) {
    self.title = title
    self.destination = destination
  }

  var body: some View {
    Link(destination: destination) {
      HStack(spacing: HexSpacing.s) {
        Text(title)
        Spacer(minLength: 0)
        Image(systemName: "arrow.up.right")
          .font(.body.weight(.semibold))
          .imageScale(.small)
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
      }
    }
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
