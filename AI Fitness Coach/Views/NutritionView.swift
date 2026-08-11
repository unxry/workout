import PhotosUI
import SwiftUI
import UIKit

struct NutritionView: View {
    @EnvironmentObject private var store: LocalDataStore

    @State private var activeSheet: NutritionSheet?
    @State private var mealMessage = ""
    @State private var selectedDate = Date()
    @State private var showDatePicker = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                nutritionHeader

                nutritionSummary

                SectionHeader(title: "БЫСТРО ДОБАВИТЬ")
                quickAddGrid

                todayHeader
                mealsList
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 144)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .photo:
                PhotoFoodSheet { saveMeal($0) }
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
        .sheet(isPresented: $showDatePicker) {
            FoodFormShell(title: "Выбрать день") {
                DatePicker("День", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(AppColors.purple)
                PremiumButton(title: "Готово", icon: "checkmark", tint: AppColors.green) {
                    showDatePicker = false
                }
            }
        }
        .alert("Готово", isPresented: Binding(get: { !mealMessage.isEmpty }, set: { if !$0 { mealMessage = "" } })) {
            Button("OK") { mealMessage = "" }
        } message: {
            Text(mealMessage)
        }
    }

    private var profile: UserProfile? { store.profile }

    private var nutritionHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Питание")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Button {
                    Haptics.tap()
                    showDatePicker = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Calendar.current.isDateInToday(selectedDate) ? "Сегодня" : selectedDate.formatted(date: .numeric, time: .omitted))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }
    private var targets: NutritionTargets {
        if let profile { return NutritionCalculator.targets(for: profile) }
        return NutritionTargets(bmr: 1650, tdee: 2600, calories: 2200, protein: 160, fat: 70, carbs: 240, waterLiters: 2.5, weeklyWeightDelta: -0.4, goalDate: .now)
    }

    private var todayMeals: [MealEntry] {
        let day = DayContext(date: selectedDate)
        return store.meals.filter { day.contains($0.date) }
    }

    private var totals: MacroTotals {
        return MacroTotals(
            calories: todayMeals.reduce(0) { $0 + $1.calories },
            protein: todayMeals.reduce(0) { $0 + $1.protein },
            fat: todayMeals.reduce(0) { $0 + $1.fat },
            carbs: todayMeals.reduce(0) { $0 + $1.carbs }
        )
    }

    private var nutritionSummary: some View {
        PremiumCard(padding: 12, radius: 22) {
            ViewThatFits(in: .horizontal) {
                nutritionSummaryWide
                nutritionSummaryStacked
            }
        }
    }

    private var nutritionSummaryWide: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                CircularProgress(progress: totals.calories / targets.calories, tint: AppColors.green, lineWidth: 7, size: 92) {
                    VStack(spacing: 5) {
                        Text("Калории")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                        Text("\(Int(totals.calories))")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.white)
                        Text("/ \(Int(targets.calories)) ккал")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }
                .overlay(alignment: .bottom) {
                    Text("\(Int((totals.calories / targets.calories * 100).rounded()))% нормы")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.green)
                        .offset(y: 30)
                }

                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        MacroMini(title: "Белки", value: "\(Int(totals.protein))", target: "\(Int(targets.protein)) г", progress: totals.protein / targets.protein, tint: AppColors.purple)
                            .frame(width: 70, alignment: .leading)
                        MacroMini(title: "Жиры", value: "\(Int(totals.fat))", target: "\(Int(targets.fat)) г", progress: totals.fat / targets.fat, tint: AppColors.purple)
                            .frame(width: 70, alignment: .leading)
                        MacroMini(title: "Углеводы", value: "\(Int(totals.carbs))", target: "\(Int(targets.carbs)) г", progress: totals.carbs / targets.carbs, tint: AppColors.yellow)
                            .frame(width: 70, alignment: .leading)
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
                        .frame(width: 226)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 226, alignment: .leading)
            }
        }
    }

    private var nutritionSummaryStacked: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 18) {
                CircularProgress(progress: totals.calories / targets.calories, tint: AppColors.green, lineWidth: 8, size: 118) {
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
                    }
                }
                Text("\(Int((totals.calories / targets.calories * 100).rounded()))% дневной нормы")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 12) {
                MacroMini(title: "Белки", value: "\(Int(totals.protein))", target: "\(Int(targets.protein)) г", progress: totals.protein / targets.protein, tint: AppColors.purple)
                MacroMini(title: "Жиры", value: "\(Int(totals.fat))", target: "\(Int(targets.fat)) г", progress: totals.fat / targets.fat, tint: AppColors.purple)
                MacroMini(title: "Углеводы", value: "\(Int(totals.carbs))", target: "\(Int(targets.carbs)) г", progress: totals.carbs / targets.carbs, tint: AppColors.yellow)
            }
            Button {
                Haptics.tap()
                activeSheet = .details
            } label: {
                HStack {
                    Image(systemName: "star")
                        .foregroundStyle(AppColors.purple)
                    Text("Детали и цели")
                        .foregroundStyle(.white.opacity(0.84))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppColors.mutedText)
                }
                .font(.system(size: 17, weight: .medium))
            }
            .buttonStyle(.plain)
        }
    }

    private var quickAddGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
            QuickActionCard(icon: "camera", title: "Фото еды", subtitle: "Локальный анализ\nбез интернета", tint: AppColors.green) { activeSheet = .photo }
            QuickActionCard(icon: "pencil", title: "Вручную", subtitle: "Ввести продукты\nсамому", tint: AppColors.blue) { activeSheet = .manual }
            QuickActionCard(icon: "magnifyingglass", title: "Найти продукт", subtitle: "Локально +\nинтернет", tint: AppColors.orange) { activeSheet = .search }
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
                        store.deleteMeal(meal)
                        mealMessage = "Прием пищи удален"
                    } else {
                        mealMessage = "Демо-прием нельзя удалить, добавь свой прием пищи"
                    }
                })
            }

            if mealRows.isEmpty {
                PremiumCard(padding: 18, radius: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Сегодня еще нет приемов пищи")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Добавь еду по фото, вручную или через поиск продукта.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
        return []
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
        let date = Calendar.current.isDateInToday(selectedDate) ? Date.now : selectedDate
        store.addMeal(MealEntry(date: date, title: draft.title, calories: draft.calories, protein: draft.protein, fat: draft.fat, carbs: draft.carbs, source: draft.source))
        Haptics.success()
        mealMessage = "\(draft.title) добавлено"
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

enum NutritionSheet: String, Identifiable {
    case photo
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .frame(height: 18, alignment: .bottomLeading)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .layoutPriority(1)
                Text("/ \(target)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .lineLimit(1)
            .allowsTightening(true)
            .frame(height: 28, alignment: .bottomLeading)
            GradientProgressBar(progress: progress, tint: tint, height: 7)
                .frame(maxWidth: .infinity)
            Text("\(Int((progress * 100).rounded()))% цели")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

struct ManualFoodSheet: View {
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

struct PhotoFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (MealDraft) -> Void
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var imageData: Data?
    @State private var showCamera = false
    @State private var analysis: FoodPhotoAnalysis?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var title = ""
    @State private var grams = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var carbs = ""

    var body: some View {
        FoodFormShell(title: "Фото еды") {
            Text("Фото анализируется локально. Калории считаются из базы продуктов, а не придумываются моделью.")
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
                Button {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCamera = true
                    } else {
                        errorMessage = "Камера недоступна на этом устройстве."
                    }
                } label: {
                    Label("Камера", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.green)

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Photos", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.green)
            }

            Button {
                Task { await analyze() }
            } label: {
                Label(isAnalyzing ? "Анализирую фото..." : "Анализировать локально", systemImage: "camera.metering.center.weighted")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.purple)
            .disabled(imageData == nil || isAnalyzing)

            HStack(spacing: 10) {
                Button {
                    analysis = nil
                    image = nil
                    imageData = nil
                    errorMessage = nil
                } label: {
                    Label("Очистить", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .tint(AppColors.purple)
            }

            if let errorMessage {
                PremiumCard(padding: 14, radius: 16) {
                    Text(errorMessage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let analysis {
                if analysis.isFood {
                    PremiumCard(padding: 14, radius: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Примерная оценка")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(analysis.items.map { "\($0.name), ~\(Int($0.estimatedGrams)) г" }.joined(separator: "\n"))
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(AppColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            if let total = analysis.total {
                                Text("~\(Int(total.calories)) ккал • Б \(Int(total.protein)) г • Ж \(Int(total.fat)) г • У \(Int(total.carbs)) г")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text("Оценка по фото может отличаться из-за неизвестного веса порции, способа приготовления и ингредиентов.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColors.yellow)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    PremiumTextField(placeholder: "Название", text: $title)
                    PremiumTextField(placeholder: "Вес, г", text: $grams, keyboard: .decimalPad)
                    PremiumTextField(placeholder: "Калории", text: $calories, keyboard: .decimalPad)
                    HStack(spacing: 10) {
                        PremiumTextField(placeholder: "Белок", text: $protein, keyboard: .decimalPad)
                        PremiumTextField(placeholder: "Жиры", text: $fat, keyboard: .decimalPad)
                        PremiumTextField(placeholder: "Углеводы", text: $carbs, keyboard: .decimalPad)
                    }

                    PremiumButton(title: "Подтвердить и сохранить", icon: "checkmark", tint: AppColors.green) {
                        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        onSave(MealDraft(title: title, calories: number(calories), protein: number(protein), fat: number(fat), carbs: number(carbs), source: "photo"))
                        dismiss()
                    }
                } else {
                    PremiumCard(padding: 14, radius: 16) {
                        Text(analysis.message.isEmpty ? "На фотографии не удалось обнаружить еду." : analysis.message)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .onChange(of: pickerItem) { newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) else { return }
                setSelectedImage(uiImage)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { captured in
                setSelectedImage(captured)
                showCamera = false
            } onCancel: {
                showCamera = false
            }
            .ignoresSafeArea()
        }
    }

    private func analyze() async {
        guard imageData != nil else { return }
        guard let image else { return }
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        let result = await FoodPhotoAnalysisService().analyze(image)
        analysis = result
        if result.isFood, let total = result.total {
            title = result.items.map(\.name).joined(separator: ", ")
            grams = "\(Int(result.items.reduce(0) { $0 + $1.estimatedGrams }))"
            calories = "\(Int(total.calories))"
            protein = "\(Int(total.protein))"
            fat = "\(Int(total.fat))"
            carbs = "\(Int(total.carbs))"
        }
    }

    private func setSelectedImage(_ uiImage: UIImage) {
        do {
            let payload = try ImagePreparationService.prepareJPEG(from: uiImage)
            imageData = payload.data
            image = uiImage
            analysis = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SearchFoodSheet: View {
    @EnvironmentObject private var store: LocalDataStore
    @Environment(\.dismiss) private var dismiss
    let onSave: (MealDraft) -> Void
    @State private var query = ""
    @State private var gramsByID: [String: String] = [:]
    @State private var results: [ProductSearchResult] = []
    @State private var message: String?
    @State private var isSearching = false

    var body: some View {
        FoodFormShell(title: "Найти продукт") {
            HStack(spacing: 10) {
                PremiumTextField(placeholder: "Например: творог Простоквашино 5%", text: $query)
                Button {
                    Task { await search(includeInternet: true) }
                } label: {
                    Image(systemName: isSearching ? "hourglass" : "magnifyingglass")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(AppColors.purple.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .disabled(isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let message {
                PremiumCard(padding: 12, radius: 14) {
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(results) { result in
                productRow(result)
            }
        }
        .task {
            await search(includeInternet: false)
        }
    }

    private func productRow(_ result: ProductSearchResult) -> some View {
        let product = result.product
        let gramsText = Binding(
            get: { gramsByID[product.id] ?? String(Int(product.packageGrams ?? 100)) },
            set: { gramsByID[product.id] = $0 }
        )
        let grams = max(number(gramsText.wrappedValue), 0)
        let total = NutritionDatabaseService.nutrition(for: product, grams: grams)

        return PremiumCard(padding: 14, radius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(product.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        if let brand = product.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        Text("Источник: \(result.source)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.purple)
                    }
                    Spacer()
                    Image(systemName: result.hasConfirmedNutrition ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(result.hasConfirmedNutrition ? AppColors.green : AppColors.yellow)
                }

                if result.hasConfirmedNutrition {
                    Text("\(Int(product.kcalPer100g)) ккал / 100 г • Б \(format(product.proteinPer100g)) • Ж \(format(product.fatPer100g)) • У \(format(product.carbsPer100g))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        PremiumTextField(placeholder: "граммы", text: gramsText, keyboard: .decimalPad)
                        Button {
                            store.upsertFoodProduct(product)
                            store.markFoodProductUsed(product.id)
                            onSave(MealDraft(title: "\(product.name) \(Int(grams)) г", calories: total.calories, protein: total.protein, fat: total.fat, carbs: total.carbs, source: "search:\(result.source)"))
                            dismiss()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(AppColors.green)
                                .frame(width: 52, height: 52)
                        }
                        .buttonStyle(.plain)
                        .disabled(grams <= 0)
                    }

                    Text("Итого: \(Int(total.calories)) ккал • Б \(Int(total.protein)) г • Ж \(Int(total.fat)) г • У \(Int(total.carbs)) г")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                } else {
                    Text(result.notice ?? "БЖУ не указаны источником.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func search(includeInternet: Bool) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearching = true
        defer { isSearching = false }
        let outcome = await ProductSearchService().search(query: trimmed, localProducts: store.foodProducts, includeInternet: includeInternet && !trimmed.isEmpty)
        results = outcome.results
        message = outcome.message
    }

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : String(format: "%.1f", value)
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
