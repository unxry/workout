import XCTest
@testable import AI_Fitness_Coach

final class AI_Fitness_CoachTests: XCTestCase {
    func testWorkoutFlowMovesThroughSetsExercisesAndCompletes() {
        var flow = WorkoutFlowEngine(exerciseCount: 2)

        flow.finishSet()
        XCTAssertEqual(flow.phase, .resting)
        XCTAssertEqual(flow.setIndex, 2)

        flow.skipRest()
        XCTAssertEqual(flow.phase, .runningExercise)

        flow.finishSet()
        flow.skipRest()
        flow.finishSet()
        flow.skipRest()
        flow.finishSet()
        XCTAssertEqual(flow.phase, .resting)
        XCTAssertEqual(flow.exerciseIndex, 1)
        XCTAssertEqual(flow.setIndex, 1)

        flow.skipRest()
        flow.finishSet()
        flow.skipRest()
        flow.finishSet()
        flow.skipRest()
        flow.finishSet()
        flow.skipRest()
        flow.finishSet()
        XCTAssertEqual(flow.phase, .completed)
    }

    func testRestCountdownUsesEndDateAndPauseResume() {
        let start = Date(timeIntervalSince1970: 1_000)
        var timer = RestCountdown(duration: 90, now: start)

        XCTAssertEqual(Int(timer.remaining(now: start.addingTimeInterval(10))), 80)

        timer.pause(now: start.addingTimeInterval(30))
        XCTAssertTrue(timer.isPaused)
        XCTAssertEqual(Int(timer.remaining(now: start.addingTimeInterval(80))), 60)

        timer.add(30, now: start.addingTimeInterval(90))
        XCTAssertEqual(Int(timer.remaining(now: start.addingTimeInterval(120))), 90)

        timer.resume(now: start.addingTimeInterval(120))
        XCTAssertFalse(timer.isPaused)
        XCTAssertEqual(Int(timer.remaining(now: start.addingTimeInterval(150))), 60)
    }

    func testEntryBeforeAndAfterMidnightBelongToDifferentDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        let dayA = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11, hour: 23, minute: 59))!
        let dayB = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 0, minute: 1))!

        let contextA = DayContext(date: dayA, calendar: calendar)
        let contextB = DayContext(date: dayB, calendar: calendar)

        XCTAssertTrue(contextA.contains(dayA))
        XCTAssertFalse(contextA.contains(dayB))
        XCTAssertTrue(contextB.contains(dayB))
        XCTAssertFalse(contextB.contains(dayA))
    }

    func testDashboardNewDayTotalsAreZeroAndYesterdayIsPreserved() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11, hour: 23, minute: 59))!
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 0, minute: 1))!
        let meals = [MealEntry(date: yesterday, title: "Рис и курица", calories: 500, protein: 40, fat: 10, carbs: 55)]

        let todayTotals = DailyTotalsCalculator.macroTotals(for: meals, day: DayContext(date: today, calendar: calendar))
        let yesterdayTotals = DailyTotalsCalculator.macroTotals(for: meals, day: DayContext(date: yesterday, calendar: calendar))

        XCTAssertEqual(todayTotals.calories, 0)
        XCTAssertEqual(todayTotals.protein, 0)
        XCTAssertEqual(yesterdayTotals.calories, 500)
        XCTAssertEqual(yesterdayTotals.protein, 40)
    }

    func testTimezoneChangeCreatesDifferentDayContext() {
        var moscow = Calendar(identifier: .gregorian)
        moscow.timeZone = TimeZone(identifier: "Europe/Moscow")!
        var vladivostok = Calendar(identifier: .gregorian)
        vladivostok.timeZone = TimeZone(identifier: "Asia/Vladivostok")!
        let date = calendarDate(year: 2026, month: 8, day: 11, hour: 22, minute: 30, timeZone: TimeZone(secondsFromGMT: 0)!)

        XCTAssertNotEqual(DayContext(date: date, calendar: moscow).start, DayContext(date: date, calendar: vladivostok).start)
    }

    private func calendarDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testGoalRecalculationProducesMacroTargets() {
        let profile = UserProfile(
            name: "Test",
            birthDate: Calendar.current.date(byAdding: .year, value: -30, to: .now)!,
            sex: .male,
            heightCm: 182,
            currentWeightKg: 85,
            targetWeightKg: 75,
            goal: .fatLoss,
            activityLevel: 1.55,
            trainingDaysPerWeek: 4,
            preferredMealsPerDay: 4,
            sleepTime: .now,
            wakeTime: .now,
            allergies: "",
            excludedFoods: ""
        )

        let targets = NutritionCalculator.targets(for: profile)
        XCTAssertGreaterThan(targets.calories, 1_500)
        XCTAssertGreaterThan(targets.protein, 120)
        XCTAssertGreaterThan(targets.waterLiters, 2)
    }

    func testNutritionLookupAndGramsCalculation() {
        let database = NutritionDatabaseService()
        let product = database.product(id: "chicken-breast")!
        let total = NutritionDatabaseService.nutrition(for: product, grams: 180)

        XCTAssertEqual(Int(total.calories.rounded()), 297)
        XCTAssertEqual(Int(total.protein.rounded()), 56)
        XCTAssertEqual(Int(total.fat.rounded()), 6)
        XCTAssertEqual(Int(total.carbs.rounded()), 0)
    }

    func testLocalFoodPhotoAnalysisRecognizesFoodFromClassifications() {
        let analysis = FoodPhotoAnalysisService().analyze([
            VisionClassification(identifier: "fried chicken, chicken breast", confidence: 0.72)
        ])

        XCTAssertEqual(analysis.status, .food)
        XCTAssertTrue(analysis.isFood)
        XCTAssertEqual(analysis.items.first?.productID, "chicken-breast")
        XCTAssertNotNil(analysis.total)
    }

    func testLocalFoodPhotoAnalysisRejectsNonFood() {
        let analysis = FoodPhotoAnalysisService().analyze([
            VisionClassification(identifier: "flower, daisy", confidence: 0.88)
        ])

        XCTAssertEqual(analysis.status, .notFood)
        XCTAssertFalse(analysis.isFood)
        XCTAssertTrue(analysis.items.isEmpty)
        XCTAssertNil(analysis.total)
    }

    func testLocalFoodPhotoAnalysisCanReturnUncertain() {
        let analysis = FoodPhotoAnalysisService().analyze([
            VisionClassification(identifier: "unknown object", confidence: 0.22)
        ])

        XCTAssertEqual(analysis.status, .uncertain)
        XCTAssertFalse(analysis.isFood)
        XCTAssertNil(analysis.total)
    }

    func testMultipleFoodsAreCalculatedTogether() {
        let analysis = FoodPhotoAnalysisService().analyze([
            VisionClassification(identifier: "chicken", confidence: 0.70),
            VisionClassification(identifier: "rice", confidence: 0.64),
            VisionClassification(identifier: "salad", confidence: 0.51)
        ])

        XCTAssertEqual(analysis.status, .food)
        XCTAssertEqual(analysis.items.count, 3)
        XCTAssertGreaterThan(analysis.total?.calories ?? 0, 400)
    }

    func testProductSearchOfflineCacheMessage() async {
        let outcome = await ProductSearchService(remoteProvider: EmptyProductSearchProvider()).search(
            query: "творог",
            localProducts: NutritionDatabaseService.defaultProducts,
            includeInternet: false
        )

        XCTAssertFalse(outcome.usedInternet)
        XCTAssertTrue(outcome.results.contains { $0.product.id == "cottage-cheese-5" })
        XCTAssertEqual(outcome.message, "Показаны сохраненные продукты. Нажми поиск, чтобы проверить интернет-источник.")
    }

    func testProductSearchEmptyQueryDoesNotClaimInternetIsUnavailable() async {
        let outcome = await ProductSearchService(remoteProvider: EmptyProductSearchProvider()).search(
            query: "",
            localProducts: NutritionDatabaseService.defaultProducts,
            includeInternet: false
        )

        XCTAssertFalse(outcome.usedInternet)
        XCTAssertNil(outcome.message)
        XCTAssertFalse(outcome.results.isEmpty)
    }

    func testProductSearchMergesDuplicateProducts() async {
        let remote = StaticProductSearchProvider(results: [
            ProductSearchResult(product: FoodProduct(id: "remote-cottage", name: "Творог 5%", category: "Интернет", kcalPer100g: 121, proteinPer100g: 17, fatPer100g: 5, carbsPer100g: 2, barcode: "123", source: "Test"), source: "Test", hasConfirmedNutrition: true, notice: nil),
            ProductSearchResult(product: FoodProduct(id: "remote-cottage-duplicate", name: "Творог 5%", category: "Интернет", kcalPer100g: 121, proteinPer100g: 17, fatPer100g: 5, carbsPer100g: 2, barcode: "123", source: "Test"), source: "Test", hasConfirmedNutrition: true, notice: nil)
        ])

        let outcome = await ProductSearchService(remoteProvider: remote).search(query: "творог", localProducts: [], includeInternet: true)

        XCTAssertTrue(outcome.usedInternet)
        XCTAssertEqual(outcome.results.filter { $0.product.barcode == "123" }.count, 1)
    }
}

private struct EmptyProductSearchProvider: ProductSearchProvider {
    let name = "Empty"

    func search(query: String) async throws -> [ProductSearchResult] {
        []
    }
}

private struct StaticProductSearchProvider: ProductSearchProvider {
    let name = "Static"
    let results: [ProductSearchResult]

    func search(query: String) async throws -> [ProductSearchResult] {
        results
    }
}
