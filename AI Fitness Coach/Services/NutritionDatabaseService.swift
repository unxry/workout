import Foundation

struct NutritionDatabaseService {
    private var products: [FoodProduct]

    init(products: [FoodProduct] = NutritionDatabaseService.defaultProducts, mergeDefaults: Bool = true) {
        self.products = mergeDefaults ? NutritionDatabaseService.mergedProducts(local: products) : products
    }

    func search(_ query: String, limit: Int = 20) -> [FoodProduct] {
        let tokens = normalizedTokens(query)
        guard !tokens.isEmpty else {
            return Array(products.prefix(limit))
        }

        return products
            .map { product in (product, score(product, tokens: tokens)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    func product(id: String) -> FoodProduct? {
        products.first { $0.id == id }
    }

    static func mergedProducts(local: [FoodProduct]) -> [FoodProduct] {
        var byID = Dictionary(uniqueKeysWithValues: defaultProducts.map { ($0.id, $0) })
        for product in local {
            byID[product.id] = product
        }
        return Array(byID.values)
    }

    static func nutrition(for product: FoodProduct, grams: Double) -> NutritionEstimateTotal {
        let factor = grams / 100
        return NutritionEstimateTotal(
            calories: product.kcalPer100g * factor,
            protein: product.proteinPer100g * factor,
            fat: product.fatPer100g * factor,
            carbs: product.carbsPer100g * factor
        )
    }

    private func score(_ product: FoodProduct, tokens: [String]) -> Int {
        let haystack = ([product.name, product.category, product.brand ?? ""] + product.aliases).joined(separator: " ").lowercased()
        return tokens.reduce(0) { total, token in
            total + (haystack.contains(token) ? token.count : 0)
        }
    }

    private func normalizedTokens(_ query: String) -> [String] {
        query
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 }
    }

    static let defaultProducts: [FoodProduct] = [
        FoodProduct(id: "egg", name: "Яйцо куриное", aliases: ["egg", "яйца", "омлет"], category: "Белок", kcalPer100g: 157, proteinPer100g: 12.7, fatPer100g: 10.9, carbsPer100g: 0.7),
        FoodProduct(id: "rice-cooked", name: "Рис вареный", aliases: ["rice", "рис", "белый рис"], category: "Крупы", kcalPer100g: 130, proteinPer100g: 2.7, fatPer100g: 0.3, carbsPer100g: 28.2),
        FoodProduct(id: "buckwheat-cooked", name: "Гречка вареная", aliases: ["buckwheat", "греча", "гречка"], category: "Крупы", kcalPer100g: 110, proteinPer100g: 3.6, fatPer100g: 1.1, carbsPer100g: 21.3),
        FoodProduct(id: "oatmeal-cooked", name: "Овсянка на воде", aliases: ["oatmeal", "porridge", "овсяная каша"], category: "Крупы", kcalPer100g: 88, proteinPer100g: 3.0, fatPer100g: 1.7, carbsPer100g: 15.0),
        FoodProduct(id: "chicken-breast", name: "Куриная грудка", aliases: ["chicken", "курица", "куриная грудь"], category: "Мясо", kcalPer100g: 165, proteinPer100g: 31, fatPer100g: 3.6, carbsPer100g: 0),
        FoodProduct(id: "turkey", name: "Индейка", aliases: ["turkey", "индейка"], category: "Мясо", kcalPer100g: 135, proteinPer100g: 29, fatPer100g: 1.7, carbsPer100g: 0),
        FoodProduct(id: "beef-lean", name: "Говядина постная", aliases: ["beef", "говядина"], category: "Мясо", kcalPer100g: 187, proteinPer100g: 20.2, fatPer100g: 11.2, carbsPer100g: 0),
        FoodProduct(id: "salmon", name: "Лосось", aliases: ["salmon", "семга", "лосось", "рыба"], category: "Рыба", kcalPer100g: 208, proteinPer100g: 20, fatPer100g: 13, carbsPer100g: 0),
        FoodProduct(id: "white-fish", name: "Белая рыба", aliases: ["fish", "рыба", "треска", "минтай"], category: "Рыба", kcalPer100g: 90, proteinPer100g: 19, fatPer100g: 1.2, carbsPer100g: 0),
        FoodProduct(id: "potato-boiled", name: "Картофель вареный", aliases: ["potato", "картошка", "картофель"], category: "Овощи", kcalPer100g: 82, proteinPer100g: 2, fatPer100g: 0.4, carbsPer100g: 16.7),
        FoodProduct(id: "pasta-cooked", name: "Макароны вареные", aliases: ["pasta", "макароны", "спагетти"], category: "Крупы", kcalPer100g: 155, proteinPer100g: 5.8, fatPer100g: 0.9, carbsPer100g: 30.9),
        FoodProduct(id: "cottage-cheese-5", name: "Творог 5%", aliases: ["cottage cheese", "творог", "простоквашино"], category: "Молочные", kcalPer100g: 121, proteinPer100g: 17, fatPer100g: 5, carbsPer100g: 1.8),
        FoodProduct(id: "greek-yogurt", name: "Греческий йогурт", aliases: ["yogurt", "йогурт"], category: "Молочные", kcalPer100g: 66, proteinPer100g: 5, fatPer100g: 3.2, carbsPer100g: 3.5),
        FoodProduct(id: "cheese-light", name: "Сыр light", aliases: ["cheese", "сыр"], category: "Молочные", kcalPer100g: 250, proteinPer100g: 29, fatPer100g: 15, carbsPer100g: 0),
        FoodProduct(id: "bread", name: "Хлеб", aliases: ["bread", "хлеб"], category: "Выпечка", kcalPer100g: 250, proteinPer100g: 8, fatPer100g: 3, carbsPer100g: 49),
        FoodProduct(id: "banana", name: "Банан", aliases: ["banana", "банан"], category: "Фрукты", kcalPer100g: 89, proteinPer100g: 1.1, fatPer100g: 0.3, carbsPer100g: 23),
        FoodProduct(id: "apple", name: "Яблоко", aliases: ["apple", "яблоко"], category: "Фрукты", kcalPer100g: 52, proteinPer100g: 0.3, fatPer100g: 0.2, carbsPer100g: 14),
        FoodProduct(id: "vegetables", name: "Овощи", aliases: ["vegetable", "salad", "салат", "овощи", "огурец", "помидор"], category: "Овощи", kcalPer100g: 30, proteinPer100g: 1.3, fatPer100g: 0.2, carbsPer100g: 5)
    ]
}
