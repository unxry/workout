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

    func testFoodStructuredResponseDecodesFood() throws {
        let json = """
        {"status":"FOOD","confidence":0.91,"message":"Еда обнаружена","items":[{"name":"куриная грудка","estimated_grams":180,"calories":297,"protein":55,"fat":6,"carbs":0}],"total":{"calories":297,"protein":55,"fat":6,"carbs":0}}
        """
        let analysis = try JSONDecoder().decode(FoodPhotoAnalysis.self, from: Data(json.utf8))
        XCTAssertTrue(analysis.isFood)
        XCTAssertEqual(analysis.items.first?.name, "куриная грудка")
        XCTAssertEqual(analysis.total?.protein, 55)
    }

    func testFoodStructuredResponseDecodesNonFoodWithoutNutrition() throws {
        let json = """
        {"status":"NOT_FOOD","confidence":0.96,"message":"На фото нет еды.","items":[],"total":null}
        """
        let analysis = try JSONDecoder().decode(FoodPhotoAnalysis.self, from: Data(json.utf8))
        XCTAssertFalse(analysis.isFood)
        XCTAssertEqual(analysis.status, .notFood)
        XCTAssertNil(analysis.total)
    }
}
