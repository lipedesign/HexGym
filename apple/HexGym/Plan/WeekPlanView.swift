// A semana no topo da aba Rotinas (Task 12 do plano da fase 2, issue #99): sete linhas na ordem da
// semana do perfil, cada uma com o dia e as rotinas dele, ou "Descanso". Um toque num dia abre a escolha
// das rotinas daquele dia, uma lista com marca em que mais de uma rotina é permitida, como o DayAssign
// do openGym: "Dia de descanso" primeiro, que esvazia o dia e fecha, e depois as rotinas, que marcam e
// desmarcam a cada toque. Cada toque muda a tela na hora e manda o dia inteiro ao motor (week.set), com
// os ids das rotinas.
//
// A regra da #71 vale aqui: o texto fica em branco e nos cinzas do sistema; a cor do tema só aparece no
// rótulo do dia, no ícone da rotina e na marca de escolhida, sobre o cartão do sistema.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o título "Plano da semana" na seção; o
// rótulo curto do dia na cor do tema, numa coluna, e as rotinas ao lado; nos tamanhos de acessibilidade,
// o dia em cima das rotinas; a escolha numa tela que sobe, com o nome do dia por extenso no título e o
// "Pronto" à direita, como os filtros da biblioteca.
import HexDesign
import HexEngine
import SwiftUI

// O dia aberto na escolha das rotinas, pelo getDay() (0 é o domingo).
struct WeekDaySelection: Identifiable, Hashable {
  let day: Int
  var id: Int { day }
}

// A seção da semana, dentro da List da aba Rotinas.
struct WeekPlanSection: View {
  let model: WeekPlanModel
  let open: (Int) -> Void

  var body: some View {
    Section {
      ForEach(model.days) { row in
        Button { open(row.day) } label: {
          WeekDayLine(row: row)
        }
        // O próprio Button é o elemento, com o rótulo por cima: "Segunda-feira, Peito e Costas". O toque
        // do VoiceOver, do Controle por Botão e do teclado abre a escolha do dia.
        .accessibilityLabel(Text(verbatim: row.spoken))
        .accessibilityHint(Text("Choose the routines for this day"))
      }
    } header: {
      SettingsHeader("Weekly plan")
    }
  }
}

// Uma linha da semana: o dia curto na cor do tema e as rotinas, que quebram a linha. Nos tamanhos de
// acessibilidade, o dia fica em cima, para as rotinas terem a largura inteira.
private struct WeekDayLine: View {
  let row: WeekDayRow

  @Environment(\.hexPalette) private var palette
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .body) private var dayWidth: CGFloat = 48

  var body: some View {
    let layout = typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: HexSpacing.xxs))
      : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: HexSpacing.s))
    layout {
      Text(verbatim: row.short)
        .font(.body.weight(.semibold))
        .foregroundStyle(Color(palette.accent))
        .frame(width: typeSize.isAccessibilitySize ? nil : dayWidth, alignment: .leading)
      Text(verbatim: row.routines)
        .font(.body)
        .foregroundStyle(row.isRest ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.white))
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(minHeight: HexTarget.minimum)
    .contentShape(Rectangle())
  }
}

// A escolha das rotinas de um dia, na tela que sobe.
struct DayRoutinesSheet: View {
  let screen: WeekPlanScreen
  let day: Int

  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    NavigationStack {
      List {
        if let model = screen.model, let row = model.day(day) {
          Section {
            DayChoiceRow(name: screen.text.restDay, symbol: "moon", detail: nil, isOn: row.isRest,
                         spoken: screen.text.restDay) {
              screen.rest(day)
              dismiss()
            }
            ForEach(model.choices(for: day)) { choice in
              DayChoiceRow(name: choice.name, symbol: choice.symbol, detail: choice.detail, isOn: choice.isOn,
                           spoken: choice.spoken) {
                screen.toggle(choice.id, on: day)
              }
            }
          } header: {
            Text("Pick one routine, or more to train them together.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .textCase(nil)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .navigationTitle(Text(verbatim: screen.model?.day(day)?.full ?? ""))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    // Nos tamanhos de acessibilidade, a tela inteira, para as rotinas aparecerem sem rolar a meia altura.
    .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
  }
}

// Uma opção da escolha do dia: o ícone na cor do tema, o nome, a contagem e a marca, com pelo menos 44 pt
// de altura. O próprio Button é o elemento do VoiceOver, com o nome, a contagem e o traço de escolhido
// (QA do PR #111), para o VoiceOver dizer qual rotina está marcada.
private struct DayChoiceRow: View {
  let name: String
  let symbol: String
  let detail: String?
  let isOn: Bool
  let spoken: String
  let action: () -> Void

  @Environment(\.hexPalette) private var palette
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .title3) private var iconWidth: CGFloat = 32

  var body: some View {
    Button(action: action) {
      HStack(spacing: HexSpacing.s) {
        if !typeSize.isAccessibilitySize {
          Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(Color(palette.accent))
            .frame(width: iconWidth)
            .accessibilityHidden(true)
        }
        VStack(alignment: .leading, spacing: HexSpacing.xxs) {
          Text(verbatim: name)
            .font(.body)
            .foregroundStyle(Color.white)
            .fixedSize(horizontal: false, vertical: true)
          if let detail {
            Text(verbatim: detail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "checkmark")
          .font(.body.weight(.semibold))
          .foregroundStyle(Color(palette.accent))
          .opacity(isOn ? 1 : 0)
          .accessibilityHidden(true)
      }
      .frame(minHeight: HexTarget.minimum)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(verbatim: spoken))
    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
  }
}

// Os argumentos de início do plano da semana, como os das rotinas (RoutinesLaunch), do domínio dos
// argumentos dos UserDefaults padrão, que não fica gravado, para os prints e o vídeo do PR saírem do
// simulador sem tocar na tela. Com -HexGymTab rotinas e -HexGymSkipOnboarding YES junto:
//   -HexGymWeekDay 1               abre a escolha das rotinas desse dia (o getDay(): 0 é o domingo)
//   -HexGymPlans open              abre os planos prontos do menu da barra (com rotinas)
//   -HexGymPlans ppl               abre os planos prontos e escolhe esse plano, pelo mesmo caminho do
//                                  toque: com dias para trocar, aparece o aviso; sem, o plano entra
//                                  (grava no documento do simulador)
//   -HexGymRoutinesScript week     o roteiro do vídeo: na tela vazia, escolhe o "Empurrar, puxar,
//                                  pernas" e, na semana montada, põe o "Push Day" também no sábado,
//                                  pelos caminhos dos toques (grava no documento do simulador)
enum WeekPlanLaunch {
  private static var defaults: UserDefaults { .standard }

  static var day: Int? { value("HexGymWeekDay").flatMap(Int.init).flatMap { (0...6).contains($0) ? $0 : nil } }
  static var plans: String? { value("HexGymPlans") }

  private static func value(_ key: String) -> String? {
    defaults.string(forKey: key).map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : $0 }
  }
}
