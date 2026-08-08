import XCTest

final class AI_Fitness_CoachUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testRuntimeSmokeAndScreenshots() throws {
        completeOnboardingIfNeeded()
        capture("dashboard")

        tapTab("nutrition")
        XCTAssertTrue(app.staticTexts["Питание"].waitForExistence(timeout: 3))
        capture("nutrition")

        openCoachFromHeader()
        XCTAssertTrue(app.staticTexts["ИИ-помощник"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Т\\nр'")).firstMatch.exists)
        capture("ai")

        tapTab("plus.ai")
        XCTAssertTrue(app.staticTexts["Задать вопрос ИИ"].waitForExistence(timeout: 3))
        capture("ai-quick-composer")
        if app.buttons["Открыть полный чат"].exists {
            app.buttons["Открыть полный чат"].tap()
        }

        tapTab("progress")
        XCTAssertTrue(app.staticTexts["Тренировки"].waitForExistence(timeout: 3))
        capture("workout")

        let startButton = app.buttons["Начать тренировку"].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        startButton.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Жим'")).firstMatch.waitForExistence(timeout: 3))
        sleep(2)
        capture("active-workout")

        app.buttons["Завершить подход"].tap()
        XCTAssertTrue(app.staticTexts["Rest"].waitForExistence(timeout: 3))
        sleep(2)
        capture("rest-timer")
        if app.buttons["rest.add30"].exists { app.buttons["rest.add30"].tap() }
        if app.buttons["rest.pause"].exists { app.buttons["rest.pause"].tap() }
        if app.buttons["rest.resume"].exists { app.buttons["rest.resume"].tap() }
        if app.buttons["rest.skip"].exists { app.buttons["rest.skip"].tap() }

        if app.buttons["Закрыть"].waitForExistence(timeout: 2) {
            app.buttons["Закрыть"].tap()
        }

        tapTab("profile")
        XCTAssertTrue(app.staticTexts["Профиль"].waitForExistence(timeout: 3))
        capture("profile")
    }

    private func completeOnboardingIfNeeded() {
        guard app.staticTexts["AI Fitness Coach"].waitForExistence(timeout: 2) else { return }
        let button = app.buttons["onboarding.createPlan"]
        for _ in 0..<8 where !button.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        button.tap()
        XCTAssertTrue(app.staticTexts["СВОДКА ЗА ДЕНЬ"].waitForExistence(timeout: 5))
    }

    private func tapTab(_ id: String) {
        let button = app.buttons["tab.\(id)"]
        XCTAssertTrue(button.waitForExistence(timeout: 3), "Missing tab \(id)")
        button.tap()
    }

    private func openCoachFromHeader() {
        let button = app.buttons["ai.helper.ИИ-помощник"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 3), "Missing AI helper button")
        button.tap()
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: "/tmp/aifitness-ui-\(name).png")
        try? screenshot.pngRepresentation.write(to: url)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
