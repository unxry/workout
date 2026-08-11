import Foundation

struct ProductSearchResult: Identifiable, Equatable {
    var id: String { product.id }
    var product: FoodProduct
    var source: String
    var hasConfirmedNutrition: Bool
    var notice: String?
    var sourceQuality: NutritionSourceQuality = .nutritionDatabase
    var confidence: Double = 0.72
    var isAverageEstimate: Bool = false

    var sourceDescription: String {
        "\(source) • \(sourceQuality.title)"
    }
}

enum NutritionSourceQuality: String, Equatable, CaseIterable {
    case officialManufacturer
    case officialProductCard
    case nutritionDatabase
    case foodDirectory
    case genericEstimate

    var title: String {
        switch self {
        case .officialManufacturer: "производитель"
        case .officialProductCard: "карточка товара"
        case .nutritionDatabase: "база питания"
        case .foodDirectory: "каталог питания"
        case .genericEstimate: "средний вариант"
        }
    }

    var rank: Int {
        switch self {
        case .officialManufacturer: 5
        case .officialProductCard: 4
        case .nutritionDatabase: 3
        case .foodDirectory: 2
        case .genericEstimate: 1
        }
    }
}

protocol ProductSearchProvider {
    var name: String { get }
    func search(query: String) async throws -> [ProductSearchResult]
}

struct LocalProductSearchProvider: ProductSearchProvider {
    let name = "Локальная база"
    var products: [FoodProduct]

    func search(query: String) async throws -> [ProductSearchResult] {
        NutritionDatabaseService(products: products)
            .search(query)
            .map {
                ProductSearchResult(
                    product: $0,
                    source: $0.source,
                    hasConfirmedNutrition: true,
                    notice: ProductSearchService.isAverageEstimate($0) ? "Использована средняя оценка. Проверь граммовку и состав перед сохранением." : nil,
                    sourceQuality: ProductSearchService.isAverageEstimate($0) ? .genericEstimate : .nutritionDatabase,
                    confidence: ProductSearchService.isAverageEstimate($0) ? 0.58 : 0.78,
                    isAverageEstimate: ProductSearchService.isAverageEstimate($0)
                )
            }
    }
}

struct OpenFoodFactsSearchProvider: ProductSearchProvider {
    let name = "Open Food Facts"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async throws -> [ProductSearchResult] {
        guard var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl") else { return [] }
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "12"),
            URLQueryItem(name: "fields", value: "code,product_name,brands,quantity,nutriments,url")
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("work0ut iOS - local-first product search", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 400 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OpenFoodFactsSearchResponse.self, from: data)
        return decoded.products.compactMap(mapProduct)
    }

    private func mapProduct(_ item: OpenFoodFactsProduct) -> ProductSearchResult? {
        let name = item.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }
        let nutriments = item.nutriments
        guard
            let kcal = nutriments.energyKcal100g,
            let protein = nutriments.proteins100g,
            let fat = nutriments.fat100g,
            let carbs = nutriments.carbohydrates100g
        else {
            let product = FoodProduct(
                id: "off-\(item.code ?? UUID().uuidString)",
                name: name,
                aliases: [],
                category: "Интернет",
                kcalPer100g: 0,
                proteinPer100g: 0,
                fatPer100g: 0,
                carbsPer100g: 0,
                barcode: item.code,
                brand: item.brands,
                packageGrams: grams(from: item.quantity),
                source: self.name,
                sourceURL: item.url
            )
            return ProductSearchResult(product: product, source: self.name, hasConfirmedNutrition: false, notice: "БЖУ не указаны источником.")
        }

        let average = ProductSearchService.isAverageEstimate(name: name)
        let product = FoodProduct(
            id: "off-\(item.code ?? UUID().uuidString)",
            name: name,
            aliases: [item.brands].compactMap { $0 },
            category: "Интернет",
            kcalPer100g: kcal,
            proteinPer100g: protein,
            fatPer100g: fat,
            carbsPer100g: carbs,
            barcode: item.code,
            brand: item.brands,
            packageGrams: grams(from: item.quantity),
            source: self.name,
            sourceURL: item.url
        )
        return ProductSearchResult(
            product: product,
            source: self.name,
            hasConfirmedNutrition: true,
            notice: average ? "Найден средний вариант. Рецепт может отличаться, проверь граммовку и БЖУ." : nil,
            sourceQuality: .nutritionDatabase,
            confidence: item.code == nil ? 0.72 : 0.88,
            isAverageEstimate: average
        )
    }

    private func grams(from quantity: String?) -> Double? {
        guard let quantity else { return nil }
        let normalized = quantity.lowercased().replacingOccurrences(of: ",", with: ".")
        guard let match = normalized.range(of: #"([0-9]+(?:\.[0-9]+)?)\s*(g|г|kg|кг)"#, options: .regularExpression) else { return nil }
        let raw = String(normalized[match])
        let number = Double(raw.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()) ?? 0
        if raw.contains("kg") || raw.contains("кг") {
            return number * 1_000
        }
        return number
    }
}

final class ProductSearchService {
    private let remoteProvider: ProductSearchProvider

    init(remoteProvider: ProductSearchProvider = OpenFoodFactsSearchProvider()) {
        self.remoteProvider = remoteProvider
    }

    func search(query: String, localProducts: [FoodProduct], includeInternet: Bool = true) async -> ProductSearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let localResults = (try? await LocalProductSearchProvider(products: localProducts).search(query: trimmed)) ?? []
        guard !trimmed.isEmpty else {
            return ProductSearchOutcome(results: Array(localResults.prefix(12)), usedInternet: false, message: nil)
        }

        guard includeInternet else {
            return ProductSearchOutcome(results: localResults, usedInternet: false, message: "Показаны сохраненные продукты. Нажми поиск, чтобы проверить интернет-источник.")
        }

        do {
            let remoteResults = try await remoteProvider.search(query: trimmed)
            let merged = merge(localResults + remoteResults)
            return ProductSearchOutcome(results: merged, usedInternet: true, message: remoteResults.isEmpty ? "В интернете не найдено подтвержденных карточек. Показаны локальные продукты." : nil)
        } catch {
            return ProductSearchOutcome(results: localResults, usedInternet: false, message: message(for: error))
        }
    }

    private func message(for error: Error) -> String {
        guard let urlError = error as? URLError else {
            return "Не удалось выполнить интернет-поиск. Показаны сохраненные продукты."
        }

        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return "Интернет недоступен - показаны сохраненные продукты."
        case .timedOut:
            return "Интернет-поиск не успел ответить. Показаны сохраненные продукты."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Источник продуктов сейчас недоступен. Показаны сохраненные продукты."
        default:
            return "Не удалось выполнить интернет-поиск (\(urlError.code.rawValue)). Показаны сохраненные продукты."
        }
    }

    private func merge(_ results: [ProductSearchResult]) -> [ProductSearchResult] {
        var bestByKey: [String: ProductSearchResult] = [:]
        for result in results {
            let key = result.product.barcode ?? result.product.name.lowercased()
            if let current = bestByKey[key] {
                bestByKey[key] = better(current, result)
            } else {
                bestByKey[key] = result
            }
        }
        return bestByKey.values.sorted {
            if $0.sourceQuality.rank != $1.sourceQuality.rank {
                return $0.sourceQuality.rank > $1.sourceQuality.rank
            }
            return $0.confidence > $1.confidence
        }
    }

    private func better(_ lhs: ProductSearchResult, _ rhs: ProductSearchResult) -> ProductSearchResult {
        if lhs.sourceQuality.rank != rhs.sourceQuality.rank {
            return lhs.sourceQuality.rank > rhs.sourceQuality.rank ? lhs : rhs
        }
        return lhs.confidence >= rhs.confidence ? lhs : rhs
    }

    static func isAverageEstimate(_ product: FoodProduct) -> Bool {
        isAverageEstimate(name: product.name) || product.category.localizedCaseInsensitiveContains("Овощи") && product.name.localizedCaseInsensitiveContains("Овощи")
    }

    static func isAverageEstimate(name: String) -> Bool {
        let normalized = name.lowercased().replacingOccurrences(of: "ё", with: "е")
        return ["салат", "оливье", "цезарь", "шаурма", "пицца", "суп", "рагу", "паста", "боул", "овощи"].contains { normalized.contains($0) }
    }
}

struct ProductSearchOutcome: Equatable {
    var results: [ProductSearchResult]
    var usedInternet: Bool
    var message: String?
}

private struct OpenFoodFactsSearchResponse: Decodable {
    var products: [OpenFoodFactsProduct]
}

private struct OpenFoodFactsProduct: Decodable {
    var code: String?
    var productName: String?
    var brands: String?
    var quantity: String?
    var nutriments: OpenFoodFactsNutriments
    var url: URL?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case quantity
        case nutriments
        case url
    }
}

private struct OpenFoodFactsNutriments: Decodable {
    var energyKcal100g: Double?
    var proteins100g: Double?
    var fat100g: Double?
    var carbohydrates100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case fat100g = "fat_100g"
        case carbohydrates100g = "carbohydrates_100g"
    }
}
