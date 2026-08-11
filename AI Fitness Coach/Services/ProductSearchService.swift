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
        let trimmed = ProductSearchService.searchableQuery(query)
        guard !trimmed.isEmpty else {
            return products
                .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
                .prefix(12)
                .map { result(for: $0, confidence: 0.68) }
        }

        let scored = products.map { product in
            (product: product, score: ProductSearchService.relevanceScore(for: product, query: trimmed))
        }
        let relevant = scored.filter { $0.score >= ProductSearchService.minimumLocalRelevanceScore }
        let sorted = relevant.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            let lhsDate = lhs.product.lastUsedAt ?? Date.distantPast
            let rhsDate = rhs.product.lastUsedAt ?? Date.distantPast
            return lhsDate > rhsDate
        }
        return sorted.prefix(12).map { item in
            result(for: item.product, confidence: min(0.95, Double(item.score) / 100))
        }
    }

    private func result(for product: FoodProduct, confidence: Double) -> ProductSearchResult {
        ProductSearchResult(
            product: product,
            source: product.source,
            hasConfirmedNutrition: true,
            notice: ProductSearchService.isAverageEstimate(product) ? "Использована средняя оценка. Проверь граммовку и состав перед сохранением." : nil,
            sourceQuality: ProductSearchService.isAverageEstimate(product) ? .genericEstimate : .nutritionDatabase,
            confidence: ProductSearchService.isAverageEstimate(product) ? min(confidence, 0.58) : confidence,
            isAverageEstimate: ProductSearchService.isAverageEstimate(product)
        )
    }
}

struct OpenFoodFactsSearchProvider: ProductSearchProvider {
    let name = "Open Food Facts"
    private let session: URLSession
    private let endpoints: [Endpoint] = [
        Endpoint(baseURL: "https://world.openfoodfacts.net/cgi/search.pl", apiVersion: .cgi),
        Endpoint(baseURL: "https://world.openfoodfacts.org/api/v2/search", apiVersion: .v2),
        Endpoint(baseURL: "https://world.openfoodfacts.org/cgi/search.pl", apiVersion: .cgi)
    ]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async throws -> [ProductSearchResult] {
        var lastError: Error?
        for candidate in queryVariants(for: query) {
            for endpoint in endpoints {
                do {
                    let results = try await search(candidate, endpoint: endpoint)
                    if !results.isEmpty {
                        return results
                    }
                } catch {
                    lastError = error
                    continue
                }
            }
        }
        if let lastError {
            throw lastError
        }
        return []
    }

    private func search(_ query: String, endpoint: Endpoint) async throws -> [ProductSearchResult] {
        guard var components = URLComponents(string: endpoint.baseURL) else { return [] }
        switch endpoint.apiVersion {
        case .cgi:
            components.queryItems = [
                URLQueryItem(name: "search_terms", value: query),
                URLQueryItem(name: "search_simple", value: "1"),
                URLQueryItem(name: "action", value: "process"),
                URLQueryItem(name: "json", value: "1"),
                URLQueryItem(name: "page_size", value: "16"),
                URLQueryItem(name: "fields", value: "code,product_name,brands,quantity,nutriments,url")
            ]
        case .v2:
            components.queryItems = [
                URLQueryItem(name: "search_terms", value: query),
                URLQueryItem(name: "page_size", value: "16"),
                URLQueryItem(name: "fields", value: "code,product_name,brands,quantity,nutriments,url")
            ]
        }
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("work0ut iOS - internet-first product search", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 400 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OpenFoodFactsSearchResponse.self, from: data)
        return decoded.products.compactMap(mapProduct)
    }

    private func queryVariants(for query: String) -> [String] {
        let normalized = ProductSearchService.searchableQuery(query)
        let tokens = Set(normalized.split(separator: " ").map(String.init))
        var variants = [normalized].filter { !$0.isEmpty }
        let translated = tokens.compactMap { Self.translation[$0] }
        if !translated.isEmpty {
            variants.append(translated.joined(separator: " "))
        }
        if tokens.contains("оливье") {
            variants.append("olivier salad")
        }
        if tokens.contains("творог") {
            variants.append("cottage cheese")
            variants.append("quark")
        }
        return Array(NSOrderedSet(array: variants)) as? [String] ?? variants
    }

    private static let translation: [String: String] = [
        "банан": "banana",
        "молоко": "milk lait",
        "яйцо": "egg",
        "яйца": "eggs",
        "рис": "rice",
        "курица": "chicken",
        "грудка": "breast",
        "овсянка": "oatmeal",
        "гречка": "buckwheat",
        "лосось": "salmon",
        "семга": "salmon",
        "говядина": "beef",
        "йогурт": "yogurt",
        "сыр": "cheese",
        "хлеб": "bread",
        "картофель": "potato",
        "картошка": "potato",
        "макароны": "pasta",
        "творог": "cottage cheese"
    ]

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
                sourceURL: item.safeURL
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
            sourceURL: item.safeURL
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
    static let minimumLocalRelevanceScore = 35
    static let minimumRemoteRelevanceScore = 25

    init(remoteProvider: ProductSearchProvider = OpenFoodFactsSearchProvider()) {
        self.remoteProvider = remoteProvider
    }

    func search(query: String, localProducts: [FoodProduct], includeInternet: Bool = true) async -> ProductSearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchable = Self.searchableQuery(trimmed)
        let displayQuery = searchable.isEmpty ? trimmed : searchable
        guard !searchable.isEmpty else {
            let localResults = await relevantLocalResults(query: searchable, localProducts: localProducts)
            let message = trimmed.isEmpty ? nil : "Введите название продукта без служебных слов вроде «БЖУ» или «100 г»."
            return ProductSearchOutcome(results: Array(localResults.prefix(12)), usedInternet: false, message: message)
        }

        guard includeInternet else {
            let localResults = await relevantLocalResults(query: searchable, localProducts: localProducts)
            let message = localResults.isEmpty
                ? "Нет точного совпадения в сохраненных продуктах."
                : "Показаны релевантные сохраненные данные. Нажми поиск, чтобы проверить интернет-источник."
            return ProductSearchOutcome(results: localResults, usedInternet: false, message: message)
        }

        do {
            let remoteResults = try await remoteProvider.search(query: searchable)
                .filter { result in
                    Self.relevanceScore(for: result.product, query: searchable) >= Self.minimumRemoteRelevanceScore
                }
            let localResults = await relevantLocalResults(query: searchable, localProducts: localProducts)
            let merged = rank(merge(remoteResults + localResults, preferInternet: !remoteResults.isEmpty), query: searchable, preferInternet: !remoteResults.isEmpty)
            let message: String?
            if merged.isEmpty {
                message = "Не удалось найти данные для «\(displayQuery)»."
            } else if remoteResults.isEmpty {
                message = "В интернете нет точного совпадения. Показаны только релевантные сохраненные данные."
            } else {
                message = nil
            }
            return ProductSearchOutcome(results: merged, usedInternet: true, message: message)
        } catch {
            let localResults = await relevantLocalResults(query: searchable, localProducts: localProducts)
            return ProductSearchOutcome(results: localResults, usedInternet: false, message: message(for: error, query: displayQuery, hasLocalResults: !localResults.isEmpty))
        }
    }

    private func relevantLocalResults(query: String, localProducts: [FoodProduct]) async -> [ProductSearchResult] {
        ((try? await LocalProductSearchProvider(products: localProducts).search(query: query)) ?? [])
            .filter(\.hasConfirmedNutrition)
    }

    private func message(for error: Error, query: String, hasLocalResults: Bool) -> String {
        let fallback: String
        if hasLocalResults {
            fallback = "Показаны только точные сохраненные совпадения."
        } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fallback = "Не удалось найти данные. Проверь подключение или повтори позже."
        } else {
            fallback = "Не удалось найти данные для «\(query)». Проверь подключение или повтори позже."
        }

        guard let urlError = error as? URLError else {
            return "Не удалось выполнить интернет-поиск. \(fallback)"
        }

        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return "Интернет недоступен. \(fallback)"
        case .timedOut:
            return "Интернет-поиск не успел ответить. \(fallback)"
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Источник продуктов сейчас недоступен. \(fallback)"
        case .badServerResponse:
            return "Не удалось выполнить интернет-поиск. \(fallback)"
        default:
            return "Не удалось выполнить интернет-поиск. \(fallback)"
        }
    }

    private func merge(_ results: [ProductSearchResult], preferInternet: Bool = false) -> [ProductSearchResult] {
        var bestByKey: [String: ProductSearchResult] = [:]
        for result in results {
            let key = result.product.barcode ?? result.product.name.lowercased()
            if let current = bestByKey[key] {
                bestByKey[key] = better(current, result, preferInternet: preferInternet)
            } else {
                bestByKey[key] = result
            }
        }
        return bestByKey.values.sorted {
            if preferInternet {
                let lhsRemote = $0.source != "Локальная база"
                let rhsRemote = $1.source != "Локальная база"
                if lhsRemote != rhsRemote {
                    return lhsRemote
                }
            }
            if $0.sourceQuality.rank != $1.sourceQuality.rank {
                return $0.sourceQuality.rank > $1.sourceQuality.rank
            }
            return $0.confidence > $1.confidence
        }
    }

    private func rank(_ results: [ProductSearchResult], query: String, preferInternet: Bool) -> [ProductSearchResult] {
        results.sorted { lhs, rhs in
            let lhsScore = Self.relevanceScore(for: lhs.product, query: query)
            let rhsScore = Self.relevanceScore(for: rhs.product, query: query)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            let lhsRemote = lhs.source != "Локальная база"
            let rhsRemote = rhs.source != "Локальная база"
            if preferInternet, lhsRemote != rhsRemote {
                return lhsRemote
            }
            if lhs.sourceQuality.rank != rhs.sourceQuality.rank {
                return lhs.sourceQuality.rank > rhs.sourceQuality.rank
            }
            return lhs.confidence > rhs.confidence
        }
    }

    private func better(_ lhs: ProductSearchResult, _ rhs: ProductSearchResult, preferInternet: Bool = false) -> ProductSearchResult {
        if preferInternet {
            let lhsRemote = lhs.source != "Локальная база"
            let rhsRemote = rhs.source != "Локальная база"
            if lhsRemote != rhsRemote {
                return lhsRemote ? lhs : rhs
            }
        }
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

    static func searchableQuery(_ query: String) -> String {
        normalizedFoodTokens(query)
            .filter { !lookupStopWords.contains($0) }
            .joined(separator: " ")
    }

    static func relevanceScore(for product: FoodProduct, query: String) -> Int {
        let baseTokens = normalizedFoodTokens(query).filter { !lookupStopWords.contains($0) }
        let queryTokens = Array(Set(baseTokens + baseTokens.compactMap { translatedFoodTokens[$0] }))
        guard !queryTokens.isEmpty else { return 0 }

        let nameTokens = normalizedFoodTokens(product.name)
        let aliasTokens = product.aliases.flatMap(normalizedFoodTokens)
        let brandTokens = normalizedFoodTokens(product.brand ?? "")
        let categoryTokens = normalizedFoodTokens(product.category)
        let decisiveGroups = baseTokens
            .filter { !genericOnlyWords.contains($0) }
            .map { token -> Set<String> in
                var group: Set<String> = [token]
                if let translated = translatedFoodTokens[token] {
                    group.formUnion(normalizedFoodTokens(translated))
                }
                return group
            }
        var matchedAny = Set<String>()
        var score = 0

        for token in queryTokens {
            let isDecisive = !genericOnlyWords.contains(token)
            if nameTokens.contains(token) {
                score += isDecisive ? 80 : 20
                matchedAny.insert(token)
            } else if aliasTokens.contains(token) {
                score += isDecisive ? 70 : 15
                matchedAny.insert(token)
            } else if brandTokens.contains(token) {
                score += isDecisive ? 45 : 10
                matchedAny.insert(token)
            } else if nameTokens.contains(where: { Self.isPrefixMatch($0, token) }) {
                score += isDecisive ? 42 : 12
                matchedAny.insert(token)
            } else if aliasTokens.contains(where: { Self.isPrefixMatch($0, token) }) {
                score += isDecisive ? 38 : 10
                matchedAny.insert(token)
            } else if categoryTokens.contains(token), queryTokens.count == 1 {
                score += isDecisive ? 24 : 6
                matchedAny.insert(token)
            }
        }

        let matchedDecisiveGroups = decisiveGroups.filter { group in
            !group.isDisjoint(with: matchedAny)
        }.count
        if !decisiveGroups.isEmpty, matchedDecisiveGroups == 0 {
            return 0
        }
        if decisiveGroups.isEmpty, score < minimumLocalRelevanceScore {
            return 0
        }
        return matchedAny.isEmpty ? 0 : score
    }

    private static func normalizedFoodTokens(_ text: String) -> [String] {
        text
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 }
    }

    private static func isPrefixMatch(_ lhs: String, _ rhs: String) -> Bool {
        guard lhs.count >= 4, rhs.count >= 4 else { return false }
        return lhs.hasPrefix(rhs) || rhs.hasPrefix(lhs)
    }

    private static let lookupStopWords: Set<String> = [
        "бжу", "кбжу", "ккал", "калории", "калорийность", "питание", "пищевые",
        "значения", "на", "по", "для", "100", "г", "гр", "грамм", "граммов",
        "порция", "порции", "примерно", "около"
    ]

    private static let genericOnlyWords: Set<String> = [
        "салат", "еда", "блюдо", "продукт", "продукты"
    ]

    private static let translatedFoodTokens: [String: String] = [
        "банан": "banana",
        "молоко": "milk",
        "яйцо": "egg",
        "яйца": "eggs",
        "рис": "rice",
        "курица": "chicken",
        "грудка": "breast",
        "овсянка": "oatmeal",
        "гречка": "buckwheat",
        "лосось": "salmon",
        "семга": "salmon",
        "говядина": "beef",
        "йогурт": "yogurt",
        "сыр": "cheese",
        "хлеб": "bread",
        "картофель": "potato",
        "картошка": "potato",
        "макароны": "pasta",
        "творог": "cottage",
        "оливье": "olivier"
    ]
}

struct ProductSearchOutcome: Equatable {
    var results: [ProductSearchResult]
    var usedInternet: Bool
    var message: String?
}

private struct OpenFoodFactsSearchResponse: Decodable {
    var products: [OpenFoodFactsProduct]
}

private struct Endpoint {
    var baseURL: String
    var apiVersion: OpenFoodFactsAPIVersion
}

private enum OpenFoodFactsAPIVersion {
    case cgi
    case v2
}

private struct OpenFoodFactsProduct: Decodable {
    var code: String?
    var productName: String?
    var brands: String?
    var quantity: String?
    var nutriments: OpenFoodFactsNutriments
    private var rawURL: String?

    var safeURL: URL? {
        guard let rawURL, !rawURL.isEmpty else { return nil }
        if let url = URL(string: rawURL) {
            return url
        }
        return rawURL
            .addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
            .flatMap(URL.init(string:))
    }

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case quantity
        case nutriments
        case rawURL = "url"
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
