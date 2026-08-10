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

        openAliceFromHeader()
        XCTAssertTrue(app.staticTexts["Алиса"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Т\\nр'")).firstMatch.exists)
        capture("alice")

        tapTab("plus.ai")
        XCTAssertTrue(app.staticTexts["Алиса"].waitForExistence(timeout: 3))
        capture("alice-quick-composer")
        if app.buttons["Открыть Алису"].exists {
            app.buttons["Открыть Алису"].tap()
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

    private func openAliceFromHeader() {
        let button = app.buttons["ai.helper.Алиса AI"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 3), "Missing Alice helper button")
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
