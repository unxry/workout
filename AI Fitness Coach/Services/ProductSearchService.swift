import Foundation

struct ProductSearchResult: Identifiable, Equatable {
    var id: String { product.id }
    var product: FoodProduct
    var source: String
    var hasConfirmedNutrition: Bool
    var notice: String?
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
            .map { ProductSearchResult(product: $0, source: $0.source, hasConfirmedNutrition: true, notice: nil) }
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
        return ProductSearchResult(product: product, source: self.name, hasConfirmedNutrition: true, notice: nil)
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
        let localResults = (try? await LocalProductSearchProvider(products: localProducts).search(query: query)) ?? []
        guard includeInternet else {
            return ProductSearchOutcome(results: localResults, usedInternet: false, message: "Интернет недоступен - показаны сохраненные продукты.")
        }

        do {
            let remoteResults = try await remoteProvider.search(query: query)
            let merged = merge(localResults + remoteResults)
            return ProductSearchOutcome(results: merged, usedInternet: true, message: remoteResults.isEmpty ? "В интернете не найдено подтвержденных карточек. Показаны локальные продукты." : nil)
        } catch {
            return ProductSearchOutcome(results: localResults, usedInternet: false, message: "Интернет недоступен - показаны сохраненные продукты.")
        }
    }

    private func merge(_ results: [ProductSearchResult]) -> [ProductSearchResult] {
        var seen: Set<String> = []
        return results.filter { result in
            let key = result.product.barcode ?? result.product.name.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
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
