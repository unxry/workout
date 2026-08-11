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

        tapTab("plus.quickAdd")
        XCTAssertTrue(app.staticTexts["Быстро добавить"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Фото еды"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Т\\nр'")).firstMatch.exists)
        capture("quick-add")
        app.swipeDown()

        tapTab("profile")
        XCTAssertTrue(app.staticTexts["Профиль"].waitForExistence(timeout: 3))
        capture("profile")
    }

    func testOnlineFoodSearchFindsOlivierWithoutUnrelatedFallback() throws {
        try openProductSearch()
        try assertOnlineSearch(query: "салат оливье", expectedText: "оливье")
        XCTAssertFalse(app.staticTexts["Овсянка на воде"].exists)
        XCTAssertFalse(app.staticTexts["Говядина постная"].exists)
    }

    func testOnlineFoodSearchFindsSeveralProductsOnDeviceNetwork() throws {
        try openProductSearch()
        try assertOnlineSearch(query: "творог", expectedText: "творог")
        restartApp()

        try openProductSearch()
        try assertOnlineSearch(query: "банан", expectedText: "банан")
        restartApp()

        try openProductSearch()
        try assertOnlineSearch(query: "салат оливье", expectedText: "оливье")
    }

    private func openProductSearch() throws {
        completeOnboardingIfNeeded()
        tapTab("nutrition")
        XCTAssertTrue(app.staticTexts["Питание"].waitForExistence(timeout: 3))

        let searchCard = app.buttons["nutrition.quick.search"]
        for _ in 0..<4 where !searchCard.exists {
            app.swipeUp()
        }
        XCTAssertTrue(searchCard.waitForExistence(timeout: 3))
        searchCard.tap()
    }

    private func assertOnlineSearch(query: String, expectedText: String) throws {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(query)

        let lookup = app.buttons["nutrition.search.lookupOnline"]
        XCTAssertTrue(lookup.waitForExistence(timeout: 3))
        lookup.tap()

        let result = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", expectedText)).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 20), "Expected online result containing \(expectedText) for \(query)")
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

    private func restartApp() {
        app.terminate()
        app.launch()
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
