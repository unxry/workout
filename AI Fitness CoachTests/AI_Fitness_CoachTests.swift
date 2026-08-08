import XCTest
import UIKit
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

    func testFoodStructuredResponseDecodesUncertainWithoutNutrition() throws {
        let json = """
        {"status":"UNCERTAIN","confidence":0.34,"message":"Не удалось уверенно определить блюдо.","items":[],"total":null}
        """
        let analysis = try JSONDecoder().decode(FoodPhotoAnalysis.self, from: Data(json.utf8))
        XCTAssertFalse(analysis.isFood)
        XCTAssertEqual(analysis.status, .uncertain)
        XCTAssertNil(analysis.total)
    }

    func testNonFoodNormalizationDropsHallucinatedNutrition() {
        let hallucinated = FoodPhotoAnalysis(
            status: .notFood,
            confidence: 0.97,
            message: "На фото цветы.",
            items: [FoodEstimateItem(name: "омлет", estimatedGrams: 220, calories: 410, protein: 24, fat: 28, carbs: 8)],
            total: NutritionEstimateTotal(calories: 410, protein: 24, fat: 28, carbs: 8)
        )

        let normalized = FoodAnalysisValidator.normalized(hallucinated)

        XCTAssertEqual(normalized.status, .notFood)
        XCTAssertFalse(normalized.isFood)
        XCTAssertTrue(normalized.items.isEmpty)
        XCTAssertNil(normalized.total)
    }

    func testLowConfidenceFoodBecomesUncertain() {
        let uncertain = FoodPhotoAnalysis(
            status: .food,
            confidence: 0.30,
            message: "",
            items: [FoodEstimateItem(name: "рис", estimatedGrams: 100, calories: 130, protein: 3, fat: 0, carbs: 28)],
            total: NutritionEstimateTotal(calories: 130, protein: 3, fat: 0, carbs: 28)
        )

        let normalized = FoodAnalysisValidator.normalized(uncertain)

        XCTAssertEqual(normalized.status, .uncertain)
        XCTAssertFalse(normalized.isFood)
        XCTAssertTrue(normalized.items.isEmpty)
        XCTAssertNil(normalized.total)
    }

    func testAIImageAttachmentPayloadUsesDataURL() {
        let payload = AIImageAttachmentPayload(imageData: Data([1, 2, 3]), mimeType: "image/jpeg")

        XCTAssertTrue(payload.dataURL.hasPrefix("data:image/jpeg;base64,"))
        XCTAssertTrue(payload.dataURL.contains("AQID"))
    }

    func testImagePreparationResizesAndCompressesJPEG() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2_000, height: 1_000))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2_000, height: 1_000))
        }

        let payload = try ImagePreparationService.prepareJPEG(from: image, maxPixel: 1_280, compression: 0.75)

        XCTAssertEqual(payload.mimeType, "image/jpeg")
        XCTAssertLessThanOrEqual(max(payload.pixelWidth, payload.pixelHeight), 1_280)
        XCTAssertFalse(payload.data.isEmpty)
    }

    func testVoiceTranscriptNormalizesFoodInput() {
        let text = "  Я съел\nтри   яйца, сто грамм риса  "

        XCTAssertEqual(VoiceTranscript.normalizedForFoodParsing(text), "Я съел три яйца, сто грамм риса")
        XCTAssertTrue(VoiceTranscript.isParseable(text))
        XCTAssertFalse(VoiceTranscript.isParseable("   \n "))
    }

    func testAPIKeyState() {
        XCTAssertEqual(APIKeyStatus.fromStoredKey(""), .missing)
        XCTAssertEqual(APIKeyStatus.fromStoredKey("   "), .missing)
        XCTAssertEqual(APIKeyStatus.fromStoredKey("sk-test"), .configured)
        XCTAssertTrue(APIKeyStatus.configured.isConfigured)
    }

    func testOfflineAIErrorMapping() {
        let error = AIClientError.from(URLError(.notConnectedToInternet))

        XCTAssertEqual(error, .noInternet)
        XCTAssertEqual(error.localizedDescription, "Нет подключения к интернету.")
    }
}
