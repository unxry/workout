import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct NutritionView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]

    @State private var activeSheet: NutritionSheet?
    @State private var mealMessage = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Питание", subtitle: "Сегодня⌄") {
                    appState.selectedTab = .coach
                }

                nutritionSummary

                SectionHeader(title: "БЫСТРО ДОБАВИТЬ")
                quickAddGrid

                todayHeader
                mealsList
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 118)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .photo:
                PhotoFoodSheet { saveMeal($0) }
            case .voice:
                VoiceFoodSheet { saveMeal($0) }
            case .manual:
                ManualFoodSheet { saveMeal($0) }
            case .search:
                SearchFoodSheet { saveMeal($0) }
            case .details:
                NutritionDetailsSheet(targets: targets, totals: totals)
            case .allMeals:
                SimpleInfoSheet(title: "Все приемы пищи", rows: mealRows.map { "\($0.type) • \($0.title) • \(Int($0.calories)) ккал" })
            }
        }
        .alert("Готово", isPresented: Binding(get: { !mealMessage.isEmpty }, set: { if !$0 { mealMessage = "" } })) {
            Button("OK") { mealMessage = "" }
        } message: {
            Text(mealMessage)
        }
    }

    private var profile: UserProfile? { profiles.first }
    private var targets: NutritionTargets {
        if let profile { return NutritionCalculator.targets(for: profile) }
        return NutritionTargets(bmr: 1650, tdee: 2600, calories: 2200, protein: 160, fat: 70, carbs: 240, waterLiters: 2.5, weeklyWeightDelta: -0.4, goalDate: .now)
    }

    private var todayMeals: [MealEntry] {
        meals.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var totals: MacroTotals {
        guard !todayMeals.isEmpty else { return MacroTotals(calories: 1850, protein: 135, fat: 62, carbs: 190) }
        return MacroTotals(
            calories: todayMeals.reduce(0) { $0 + $1.calories },
            protein: todayMeals.reduce(0) { $0 + $1.protein },
            fat: todayMeals.reduce(0) { $0 + $1.fat },
            carbs: todayMeals.reduce(0) { $0 + $1.carbs }
        )
    }

    private var nutritionSummary: some View {
        PremiumCard(padding: 16, radius: 22) {
            HStack(spacing: 14) {
                CircularProgress(progress: totals.calories / targets.calories, tint: AppColors.green, lineWidth: 8, size: 124) {
                    VStack(spacing: 5) {
                        Text("Калории")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                        Text("\(Int(totals.calories))")
                            .font(.system(size: 29, weight: .bold))
                            .foregroundStyle(.white)
                        Text("/ \(Int(targets.calories)) ккал")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }

                VStack(spacing: 13) {
                    HStack(spacing: 10) {
                        MacroMini(title: "Белки", value: "\(Int(totals.protein))", target: "\(Int(targets.protein)) г", progress: totals.protein / targets.protein, tint: AppColors.purple)
                        MacroMini(title: "Жиры", value: "\(Int(totals.fat))", target: "\(Int(targets.fat)) г", progress: totals.fat / targets.fat, tint: AppColors.purple)
                        MacroMini(title: "Углеводы", value: "\(Int(totals.carbs))", target: "\(Int(targets.carbs)) г", progress: totals.carbs / targets.carbs, tint: AppColors.yellow)
                    }
                    Divider().background(Color.white.opacity(0.12))
                    Button {
                        Haptics.tap()
                        activeSheet = .details
                    } label: {
                        HStack {
                            Image(systemName: "star")
                                .foregroundStyle(AppColors.purple)
                                .font(.system(size: 21, weight: .semibold))
                            Text("Детали и цели")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.80))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppColors.mutedText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("\(Int((totals.calories / targets.calories * 100).rounded()))%")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.green)
                .padding(.leading, 58)
                .padding(.top, -6)
        }
    }

    private var quickAddGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            QuickActionCard(icon: "camera", title: "Фото еды", subtitle: "ИИ распознает\nблюдо", tint: AppColors.green) { activeSheet = .photo }
            QuickActionCard(icon: "mic", title: "Голосом", subtitle: "Просто скажи,\nчто съел", tint: AppColors.purple) { activeSheet = .voice }
            QuickActionCard(icon: "pencil", title: "Вручную", subtitle: "Ввести продукты\nсамому", tint: AppColors.blue) { activeSheet = .manual }
            QuickActionCard(icon: "magnifyingglass", title: "Найти продукт", subtitle: "Поиск в базе\nпродуктов", tint: AppColors.orange) { activeSheet = .search }
        }
    }

    private var todayHeader: some View {
        HStack {
            SectionHeader(title: "СЕГОДНЯ")
            Spacer()
            Button {
                Haptics.tap()
                activeSheet = .manual
            } label: {
                Text("+ Добавить прием пищи")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.purple)
            }
            .buttonStyle(.plain)
        }
    }

    private var mealsList: some View {
        VStack(spacing: 10) {
            ForEach(mealRows) { row in
                MealDisplayRow(row: row, repeatAction: {
                    saveMeal(MealDraft(title: row.title, calories: row.calories, protein: row.protein, fat: row.fat, carbs: row.carbs, source: "repeat"))
                }, deleteAction: {
                    if let meal = row.entry {
                        modelContext.delete(meal)
                        try? modelContext.save()
                        mealMessage = "Прием пищи удален"
                    } else {
                        mealMessage = "Демо-прием нельзя удалить, добавь свой прием пищи"
                    }
                })
            }

            Button {
                Haptics.tap()
                activeSheet = .allMeals
            } label: {
                PremiumCard(padding: 16, radius: 18) {
                    HStack {
                        Image(systemName: "square.stack.3d.up")
                            .foregroundStyle(AppColors.purple)
                            .font(.system(size: 22, weight: .semibold))
                        Text("Все приемы пищи")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppColors.mutedText)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var mealRows: [MealDisplay] {
        if !todayMeals.isEmpty {
            return todayMeals.enumerated().map { index, meal in
                let meta = mealMeta[index % mealMeta.count]
                return MealDisplay(type: meta.type, time: timeString(meal.date), title: meal.title, calories: meal.calories, protein: meal.protein, fat: meal.fat, carbs: meal.carbs, icon: meta.icon, tint: meta.tint, thumbnail: meta.thumbnail, entry: meal)
            }
        }
        return [
            MealDisplay(type: "Завтрак", time: "08:30", title: "Омлет с овощами", calories: 420, protein: 32, fat: 15, carbs: 38, icon: "sunrise.fill", tint: AppColors.green, thumbnail: "🍳", entry: nil),
            MealDisplay(type: "Обед", time: "13:20", title: "Куриная грудка с рисом", calories: 550, protein: 45, fat: 12, carbs: 55, icon: "sun.max.fill", tint: AppColors.purple, thumbnail: "🍗", entry: nil),
            MealDisplay(type: "Ужин", time: "19:10", title: "Сёмга с овощами", calories: 510, protein: 38, fat: 22, carbs: 18, icon: "sunset.fill", tint: AppColors.orange, thumbnail: "🐟", entry: nil),
            MealDisplay(type: "Перекусы", time: "16:45", title: "Творог с ягодами", calories: 180, protein: 18, fat: 4, carbs: 12, icon: "moon.fill", tint: AppColors.blue, thumbnail: "🫐", entry: nil)
        ]
    }

    private var mealMeta: [(type: String, icon: String, tint: Color, thumbnail: String)] {
        [
            ("Завтрак", "sunrise.fill", AppColors.green, "🍳"),
            ("Обед", "sun.max.fill", AppColors.purple, "🍗"),
            ("Ужин", "sunset.fill", AppColors.orange, "🐟"),
            ("Перекусы", "moon.fill", AppColors.blue, "🫐")
        ]
    }

    private func saveMeal(_ draft: MealDraft) {
        modelContext.insert(MealEntry(title: draft.title, calories: draft.calories, protein: draft.protein, fat: draft.fat, carbs: draft.carbs, source: draft.source))
        try? modelContext.save()
        Haptics.success()
        mealMessage = "\(draft.title) добавлено"
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private enum NutritionSheet: String, Identifiable {
    case photo
    case voice
    case manual
    case search
    case details
    case allMeals
    var id: String { rawValue }
}

struct MealDraft {
    var title: String
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    var source: String
}

private struct MacroMini: View {
    let title: String
    let value: String
    let target: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                Text("/ \(target)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            GradientProgressBar(progress: progress, tint: tint, height: 7)
                .frame(width: 54)
            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(width: 58, alignment: .leading)
    }
}

private struct MealDisplay: Identifiable {
    let id = UUID()
    let type: String
    let time: String
    let title: String
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let icon: String
    let tint: Color
    let thumbnail: String
    let entry: MealEntry?
}

private struct MealDisplayRow: View {
    let row: MealDisplay
    let repeatAction: () -> Void
    let deleteAction: () -> Void
    @State private var favorite = false

    var body: some View {
        PremiumCard(padding: 14, radius: 18) {
            HStack(spacing: 10) {
                IconBadge(systemName: row.icon, tint: row.tint, size: 44)
                VStack(alignment: .leading, spacing: 5) {
                    Text(row.type)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(row.time)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                }
                .frame(width: 70, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text(row.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(Int(row.calories)) ккал • Б \(Int(row.protein)) г • Ж \(Int(row.fat)) г • У \(Int(row.carbs)) г")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer()

                Text(row.thumbnail)
                    .font(.system(size: 28))
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.10)))

                Menu {
                    Button("Редактировать") { repeatAction() }
                    Button(favorite ? "Убрать из избранного" : "Добавить в избранное") { favorite.toggle() }
                    Button("Повторить") { repeatAction() }
                    Button("Удалить", role: .destructive) { deleteAction() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(width: 24, height: 46)
                }
            }
        }
    }
}

private struct ManualFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (MealDraft) -> Void
    @State private var title = ""
    @State private var weight = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var carbs = ""

    var body: some View {
        FoodFormShell(title: "Добавить вручную") {
            PremiumTextField(placeholder: "Название", text: $title)
            PremiumTextField(placeholder: "Вес порции, г", text: $weight, keyboard: .decimalPad)
            PremiumTextField(placeholder: "Калории", text: $calories, keyboard: .decimalPad)
            HStack(spacing: 10) {
                PremiumTextField(placeholder: "Белок", text: $protein, keyboard: .decimalPad)
                PremiumTextField(placeholder: "Жиры", text: $fat, keyboard: .decimalPad)
                PremiumTextField(placeholder: "Углеводы", text: $carbs, keyboard: .decimalPad)
            }
            PremiumButton(title: "Добавить прием пищи", icon: "checkmark", tint: AppColors.green) {
                guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                onSave(MealDraft(title: title, calories: number(calories), protein: number(protein), fat: number(fat), carbs: number(carbs), source: "manual"))
                dismiss()
            }
            .padding(.top, 8)
        }
    }
}

private struct PhotoFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (MealDraft) -> Void
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var analyzed = false

    var body: some View {
        FoodFormShell(title: "Фото еды") {
            Text("Оценка по фотографии может быть неточной.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.yellow)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.075))
                    .frame(height: 220)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(AppColors.green)
                        Text("Сделай фото или выбери из Photos")
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            }

            HStack {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Выбрать фото", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.green)

                Button {
                    analyzed = true
                } label: {
                    Label("Анализировать", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.purple)
            }

            if analyzed {
                PremiumCard(padding: 14, radius: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Найдено: омлет с овощами")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Порция: ~280 г • 420 ккал • Б 32 г • Ж 15 г • У 38 г")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
                PremiumButton(title: "Подтвердить и сохранить", icon: "checkmark", tint: AppColors.green) {
                    onSave(MealDraft(title: "Омлет с овощами", calories: 420, protein: 32, fat: 15, carbs: 38, source: "photo"))
                    dismiss()
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) else { return }
                image = uiImage
                analyzed = false
            }
        }
    }
}

private struct VoiceFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (MealDraft) -> Void
    @State private var transcript = "Я съел 3 яйца, 150 грамм риса и 200 грамм курицы"
    @State private var parsed = false

    var body: some View {
        FoodFormShell(title: "Голосом") {
            ZStack {
                Circle().fill(AppColors.purple.opacity(0.14)).frame(width: 132, height: 132)
                Circle().stroke(AppColors.purple.opacity(0.75), lineWidth: 3).frame(width: 98, height: 98)
                Image(systemName: "mic.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(AppColors.purple)
            }
            .frame(maxWidth: .infinity)

            PremiumTextField(placeholder: "Распознанный текст", text: $transcript)
            Button("Распознать питание") { parsed = true }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.purple)

            if parsed {
                PremiumCard(padding: 14, radius: 16) {
                    Text("Курица с рисом и яйцами • ~865 ккал • Б 83 г • Ж 24 г • У 78 г")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
                PremiumButton(title: "Подтвердить", icon: "checkmark", tint: AppColors.green) {
                    onSave(MealDraft(title: "Курица с рисом и яйцами", calories: 865, protein: 83, fat: 24, carbs: 78, source: "voice"))
                    dismiss()
                }
            }
        }
    }
}

private struct SearchFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (MealDraft) -> Void
    @State private var query = ""

    let products = [
        MealDraft(title: "Куриная грудка 200 г", calories: 330, protein: 62, fat: 7, carbs: 0, source: "search"),
        MealDraft(title: "Творог 5% 150 г", calories: 180, protein: 20, fat: 7, carbs: 5, source: "search"),
        MealDraft(title: "Рис вареный 150 г", calories: 195, protein: 4, fat: 1, carbs: 43, source: "search")
    ]

    var body: some View {
        FoodFormShell(title: "Найти продукт") {
            PremiumTextField(placeholder: "Поиск продукта", text: $query)
            ForEach(products.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }, id: \.title) { product in
                Button {
                    onSave(product)
                    dismiss()
                } label: {
                    PremiumCard(padding: 14, radius: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(product.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("\(Int(product.calories)) ккал • Б \(Int(product.protein)) • Ж \(Int(product.fat)) • У \(Int(product.carbs))")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppColors.green)
                                .font(.title2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct NutritionDetailsSheet: View {
    let targets: NutritionTargets
    let totals: MacroTotals

    var body: some View {
        SimpleInfoSheet(title: "Детали и цели", rows: [
            "Калории: \(Int(totals.calories)) / \(Int(targets.calories)) ккал",
            "Белок: \(Int(totals.protein)) / \(Int(targets.protein)) г",
            "Жиры: \(Int(totals.fat)) / \(Int(targets.fat)) г",
            "Углеводы: \(Int(totals.carbs)) / \(Int(targets.carbs)) г",
            "Вода: \(String(format: "%.1f", targets.waterLiters)) л"
        ])
    }
}

struct FoodFormShell<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ZStack {
            PremiumBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                    content
                }
                .padding(22)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private func number(_ text: String) -> Double {
    Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
}
