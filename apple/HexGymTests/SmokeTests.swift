// Só guarda o lugar do alvo de testes, até a Task 10 trocar este arquivo pelo AppModelTests.swift.
// O alvo roda dentro do app (TEST_HOST) e vê o HexEngine e o HexStore pelo app, sem uma segunda
// cópia deles. Não é checagem do check.mjs.
import Foundation
import HexEngine
import HexStore
import Testing
@testable import HexGym

struct SmokeTests {
  @Test func theTestsRunInsideTheApp() {
    #expect(Bundle.main.bundleIdentifier == "app.hexgym")
  }
}
