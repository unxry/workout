import Foundation
import UIKit
@preconcurrency import Vision

struct VisionClassification: Equatable {
    var identifier: String
    var confidence: Double
}

final class FoodVisionService {
    private let localModel = LocalVisionModelService()

    func classify(_ image: UIImage) async throws -> [VisionClassification] {
        try await localModel.classify(image)
    }
}

final class LocalVisionModelService {
    func classify(_ image: UIImage) async throws -> [VisionClassification] {
        guard let cgImage = image.cgImage else {
            throw FoodPhotoAnalysisError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let classifications = (request.results as? [VNClassificationObservation] ?? [])
                    .prefix(12)
                    .map { VisionClassification(identifier: $0.identifier, confidence: Double($0.confidence)) }
                continuation.resume(returning: classifications)
            }
            request.usesCPUOnly = false

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation), options: [:]).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct FoodCandidateResolver {
    private let database: NutritionDatabaseService

    init(database: NutritionDatabaseService) {
        self.database = database
    }

    func resolve(_ classifications: [VisionClassification]) -> FoodCandidateResolution {
        guard !classifications.isEmpty else {
            return FoodCandidateResolution(status: .uncertain, confidence: 0, products: [], message: "Не удалось уверенно распознать блюдо.")
        }

        let nonFoodConfidence = classifications
            .filter { matches($0.identifier, terms: nonFoodTerms) }
            .map(\.confidence)
            .max() ?? 0

        let candidates = classifications.compactMap { classification -> (FoodProduct, Double)? in
            guard let product = product(for: classification.identifier) else { return nil }
            return (product, classification.confidence)
        }

        if candidates.isEmpty {
            if nonFoodConfidence >= 0.35 {
                return FoodCandidateResolution(status: .notFood, confidence: nonFoodConfidence, products: [], message: "На фотографии не удалось обнаружить еду.")
            }
            return FoodCandidateResolution(status: .uncertain, confidence: classifications.first?.confidence ?? 0, products: [], message: "Не удалось уверенно распознать блюдо.")
        }

        let bestConfidence = candidates.map(\.1).max() ?? 0
        if bestConfidence < 0.18 {
            return FoodCandidateResolution(status: .uncertain, confidence: bestConfidence, products: [], message: "Не удалось уверенно распознать блюдо.")
        }

        if nonFoodConfidence > bestConfidence + 0.18 {
            return FoodCandidateResolution(status: .notFood, confidence: nonFoodConfidence, products: [], message: "На фотографии не удалось обнаружить еду.")
        }

        let unique = Dictionary(grouping: candidates, by: { $0.0.id })
            .compactMap { _, values in values.max { $0.1 < $1.1 } }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map(\.0)

        return FoodCandidateResolution(status: .food, confidence: bestConfidence, products: Array(unique), message: "Еда распознана локально.")
    }

    private func product(for label: String) -> FoodProduct? {
        let normalized = label.lowercased().replacingOccurrences(of: "_", with: " ")
        for (terms, productID) in foodTerms {
            if matches(normalized, terms: terms), let product = database.product(id: productID) {
                return product
            }
        }
        return nil
    }

    private func matches(_ label: String, terms: [String]) -> Bool {
        let normalized = label.lowercased().replacingOccurrences(of: "ё", with: "е")
        return terms.contains { normalized.contains($0) }
    }

    private let nonFoodTerms = [
        "flower", "plant", "person", "human", "face", "phone", "car", "vehicle", "table", "desk", "room", "chair", "sofa", "dog", "cat", "screen"
    ]

    private let foodTerms: [([String], String)] = [
        (["egg", "omelet", "omelette"], "egg"),
        (["rice"], "rice-cooked"),
        (["buckwheat"], "buckwheat-cooked"),
        (["oatmeal", "porridge"], "oatmeal-cooked"),
        (["chicken", "hen"], "chicken-breast"),
        (["turkey"], "turkey"),
        (["beef", "steak"], "beef-lean"),
        (["salmon"], "salmon"),
        (["fish"], "white-fish"),
        (["potato"], "potato-boiled"),
        (["pasta", "spaghetti", "macaroni"], "pasta-cooked"),
        (["cottage cheese"], "cottage-cheese-5"),
        (["yogurt", "yoghurt"], "greek-yogurt"),
        (["cheese"], "cheese-light"),
        (["bread", "toast"], "bread"),
        (["banana"], "banana"),
        (["apple"], "apple"),
        (["salad", "vegetable", "cucumber", "tomato"], "vegetables")
    ]
}

struct FoodCandidateResolution: Equatable {
    var status: FoodRecognitionStatus
    var confidence: Double
    var products: [FoodProduct]
    var message: String
}

struct PortionEstimationService {
    func estimatedGrams(for product: FoodProduct, classificationCount: Int) -> Double {
        switch product.category {
        case "Мясо", "Рыба":
            return 180
        case "Крупы":
            return 150
        case "Овощи", "Фрукты":
            return 120
        case "Молочные":
            return 150
        default:
            return classificationCount > 1 ? 120 : 150
        }
    }
}

final class FoodPhotoAnalysisService {
    private let visionService: FoodVisionService
    private let database: NutritionDatabaseService
    private let portionEstimator: PortionEstimationService

    init(
        visionService: FoodVisionService = FoodVisionService(),
        database: NutritionDatabaseService = NutritionDatabaseService(),
        portionEstimator: PortionEstimationService = PortionEstimationService()
    ) {
        self.visionService = visionService
        self.database = database
        self.portionEstimator = portionEstimator
    }

    func analyze(_ image: UIImage) async -> FoodPhotoAnalysis {
        do {
            let classifications = try await visionService.classify(image)
            return analyze(classifications)
        } catch {
            return FoodPhotoAnalysis(status: .uncertain, confidence: 0, message: "Не удалось обработать фото локально.", items: [], total: nil)
        }
    }

    func analyze(_ classifications: [VisionClassification]) -> FoodPhotoAnalysis {
        let resolution = FoodCandidateResolver(database: database).resolve(classifications)
        guard resolution.status == .food else {
            return FoodPhotoAnalysis(status: resolution.status, confidence: resolution.confidence, message: resolution.message, items: [], total: nil)
        }

        let items = resolution.products.map { product -> FoodEstimateItem in
            let grams = portionEstimator.estimatedGrams(for: product, classificationCount: resolution.products.count)
            let total = NutritionDatabaseService.nutrition(for: product, grams: grams)
            return FoodEstimateItem(
                productID: product.id,
                name: product.name,
                estimatedGrams: grams,
                confidence: resolution.confidence,
                calories: total.calories,
                protein: total.protein,
                fat: total.fat,
                carbs: total.carbs,
                sourceName: product.source,
                sourceURL: product.sourceURL,
                isAverageEstimate: ProductSearchService.isAverageEstimate(product)
            )
        }

        let total = NutritionEstimateTotal(
            calories: items.reduce(0) { $0 + $1.calories },
            protein: items.reduce(0) { $0 + $1.protein },
            fat: items.reduce(0) { $0 + $1.fat },
            carbs: items.reduce(0) { $0 + $1.carbs }
        )

        return FoodPhotoAnalysis(status: .food, confidence: resolution.confidence, message: resolution.message, items: items, total: total)
    }
}

enum FoodPhotoAnalysisError: Error {
    case invalidImage
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
