// Os planos prontos do openGym (Task 12 do plano da fase 2, issue #99, escolha 10 do plano): os quatro
// do lib/starter.js, com os nomes e as descrições do PLAN_COPY do sheets.jsx no catálogo do app, cada um
// com os dias que ocupa.
//
// O StarterPlansView é a tela vazia da aba Rotinas (sem rotinas): "Monte a sua primeira rotina", o botão
// principal "Nova rotina" e, embaixo, "Ou comece com um plano pronto" com os quatro planos. Escolher um
// aplica o plan.starter (loadStarterPlan) e a aba mostra a semana montada. Sem rotinas não há dia para
// trocar, então o plano entra no primeiro toque.
//
// O StarterPlansSheet é o item "Planos prontos" do menu da barra, quando já há rotinas: a mesma lista,
// numa tela que sobe. Quando o plano troca um dia que tinha rotina, o aviso da Apple
// (confirmationDialog) diz quais antes de aplicar ("Este plano troca segunda, quarta e sexta."), e as
// rotinas de antes ficam. Sem dia para trocar, o plano entra no primeiro toque, como no openGym.
//
// Depois de carregar, o VoiceOver anuncia o plano carregado, como a mensagem do openGym.
//
// A regra da #71 vale aqui: o texto fica em branco e nos cinzas do sistema; a cor do tema só aparece no
// ícone do plano, sobre o cartão do sistema, e no botão principal.
//
// Escolha recomendada, com a delegação do Lipe de 03/11/2026: o ícone da prancheta em cada plano, como o
// openGym; o título no estilo de título do HexDesign e uma linha sobre o que é uma rotina embaixo dele;
// no aviso, o "Carregar plano" e a frase de que as rotinas de antes ficam.
import HexDesign
import HexEngine
import SwiftUI

struct StarterPlansView: View {
  let screen: WeekPlanScreen
  let create: () -> Void
  // Depois de um plano carregado, para a aba ler as rotinas de novo.
  let loaded: () async -> Void

  @State private var loading: String?

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: HexSpacing.s) {
          Text("Build your first routine")
            .hexFont(.title)
            .foregroundStyle(Color.white)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
          Text("Pick the exercises, the sets and the load, your way.")
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: HexSpacing.m, leading: 0, bottom: HexSpacing.s, trailing: 0))
        .listRowSeparator(.hidden)
        Button(action: create) {
          Text("New routine")
        }
        .buttonStyle(.hexPrimary)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
      }
      if let model = screen.model, !model.plans.isEmpty {
        Section {
          ForEach(model.plans) { plan in
            StarterPlanButton(plan: plan, busy: loading == plan.id) { choose(plan) }
              .disabled(loading != nil)
          }
        } header: {
          SettingsHeader("Or start with a starter plan")
        }
      }
    }
    .scrollContentBackground(.hidden)
  }

  private func choose(_ plan: StarterPlanRow) {
    guard loading == nil else { return }
    loading = plan.id
    Task {
      if await screen.loadPlan(plan.id) { StarterPlanAnnouncement.post(screen.text, plan) }
      await loaded()
      loading = nil
    }
  }
}

// Os planos prontos do menu da barra, quando já há rotinas.
struct StarterPlansSheet: View {
  let screen: WeekPlanScreen
  let loaded: () async -> Void

  // O plano escolhido que troca dias, enquanto o aviso aparece.
  @State private var confirming: StarterPlanRow?
  @State private var loading: String?
  @State private var ranLaunch = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        if let model = screen.model {
          Section {
            ForEach(model.plans) { plan in
              StarterPlanButton(plan: plan, busy: loading == plan.id) { choose(plan) }
                .disabled(loading != nil)
            }
          } footer: {
            Text("Your routines stay. Only the plan's days of the week change.")
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .navigationTitle("Starter plans")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .confirmationDialog(confirmTitle, isPresented: confirmingShown, titleVisibility: .visible, presenting: confirming) { plan in
        Button("Load plan") { load(plan) }
        Button("Cancel", role: .cancel) {}
      } message: { plan in
        Text(verbatim: [screen.model?.warning(forPlan: plan.id) ?? "", AppText.text("Your routines stay.", locale: screen.text.locale)]
          .joined(separator: " "))
      }
      .task { await appear() }
    }
  }

  private var confirmTitle: Text {
    guard let confirming else { return Text(verbatim: "") }
    return Text("Load \(confirming.name)?")
  }

  private var confirmingShown: Binding<Bool> {
    Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } })
  }

  // Com dias para trocar, o aviso; sem, o plano entra no primeiro toque.
  private func choose(_ plan: StarterPlanRow) {
    guard loading == nil else { return }
    if screen.model?.warning(forPlan: plan.id) != nil {
      confirming = plan
    } else {
      load(plan)
    }
  }

  private func load(_ plan: StarterPlanRow) {
    loading = plan.id
    Task {
      let done = await screen.loadPlan(plan.id)
      await loaded()
      loading = nil
      if done {
        StarterPlanAnnouncement.post(screen.text, plan)
        dismiss()
      }
    }
  }

  // Na primeira vez, o plano que o -HexGymPlans pede, pelo mesmo caminho do toque.
  private func appear() async {
    guard !ranLaunch else { return }
    ranLaunch = true
    guard let id = WeekPlanLaunch.plans, id != "open" else { return }
    try? await Task.sleep(for: .seconds(0.8))
    if let plan = screen.model?.plans.first(where: { $0.id == id }) { choose(plan) }
  }
}

// Uma linha de plano: o ícone na cor do tema, o nome, os dias e a descrição. O próprio Button é o elemento
// do VoiceOver, com o rótulo inteiro ("Empurrar, puxar, pernas, 3 dias por semana, Segunda-feira,
// Quarta-feira e Sexta-feira, ..."). Nos tamanhos de acessibilidade, o ícone fica em cima do texto.
struct StarterPlanButton: View {
  let plan: StarterPlanRow
  let busy: Bool
  let action: () -> Void

  @Environment(\.hexPalette) private var palette
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .title3) private var iconWidth: CGFloat = 32

  var body: some View {
    Button(action: action) {
      let layout = typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: HexSpacing.xs))
        : AnyLayout(HStackLayout(spacing: HexSpacing.s))
      layout {
        Image(systemName: "list.bullet.clipboard")
          .font(.title3)
          .foregroundStyle(Color(palette.accent))
          .frame(width: typeSize.isAccessibilitySize ? nil : iconWidth)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: HexSpacing.xxs) {
          Text(verbatim: plan.name)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .fixedSize(horizontal: false, vertical: true)
          Text(verbatim: plan.detail)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text(verbatim: plan.about)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if busy { ProgressView() }
      }
      .frame(minHeight: HexTarget.minimum)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(verbatim: plan.spoken))
  }
}

// "Empurrar, puxar, pernas carregado", para o VoiceOver, como a mensagem do openGym.
enum StarterPlanAnnouncement {
  @MainActor static func post(_ text: WeekPlanText, _ plan: StarterPlanRow) {
    let format = AppText.text("%@ loaded", locale: text.locale)
    AccessibilityNotification.Announcement(String(format: format, locale: text.locale, plan.name)).post()
  }
}
