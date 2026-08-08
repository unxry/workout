import SwiftData
import SwiftUI

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]

    @State private var title = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var carbs = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Питание")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                GlassPanel {
                    VStack(spacing: 12) {
                        TextField("Например: омлет и овсянка", text: $title)
                        HStack {
                            TextField("Ккал", text: $calories)
                                .keyboardType(.decimalPad)
                            TextField("Б", text: $protein)
                                .keyboardType(.decimalPad)
                            TextField("Ж", text: $fat)
                                .keyboardType(.decimalPad)
                            TextField("У", text: $carbs)
                                .keyboardType(.decimalPad)
                        }

                        Button("Добавить прием пищи") {
                            addMeal()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.greenAccent)
                    }
                    .textFieldStyle(.roundedBorder)
                }

                ForEach(meals) { meal in
                    GlassPanel {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(meal.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(Int(meal.protein)) Б / \(Int(meal.fat)) Ж / \(Int(meal.carbs)) У")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.58))
                            }
                            Spacer()
                            Text("\(Int(meal.calories))")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.greenAccent)
                        }
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 110)
        }
    }

    private func addMeal() {
        guard !title.isEmpty else { return }
        let entry = MealEntry(
            title: title,
            calories: Double(calories.replacingOccurrences(of: ",", with: ".")) ?? 0,
            protein: Double(protein.replacingOccurrences(of: ",", with: ".")) ?? 0,
            fat: Double(fat.replacingOccurrences(of: ",", with: ".")) ?? 0,
            carbs: Double(carbs.replacingOccurrences(of: ",", with: ".")) ?? 0
        )
        modelContext.insert(entry)
        try? modelContext.save()
        title = ""
        calories = ""
        protein = ""
        fat = ""
        carbs = ""
    }
}
