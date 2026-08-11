import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: LocalDataStore

    var body: some View {
        ZStack {
            PremiumBackground()

            if store.profile == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: LocalDataStore
    @State private var showQuickActions = false
    @State private var statusMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch appState.selectedTab {
                case .home:
                    DashboardView()
                case .nutrition:
                    NutritionView()
                case .profile:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PremiumTabBar(selected: $appState.selectedTab) {
                showQuickActions = true
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showQuickActions) {
            QuickAddSheet(
                onSaveMeal: { draft in
                    store.addMeal(MealEntry(title: draft.title, calories: draft.calories, protein: draft.protein, fat: draft.fat, carbs: draft.carbs, source: draft.source))
                    statusMessage = "\(draft.title) добавлено"
                },
                onAddWater: { liters in
                    store.addWater(liters: liters)
                    statusMessage = "Вода добавлена"
                },
                onRecordWeight: { weight in
                    store.recordWeight(weight)
                    statusMessage = "Вес сохранен"
                }
            )
            .environmentObject(store)
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Готово", isPresented: Binding(get: { !statusMessage.isEmpty }, set: { if !$0 { statusMessage = "" } })) {
            Button("OK") { statusMessage = "" }
        } message: {
            Text(statusMessage)
        }
    }
}

private struct QuickAddSheet: View {
    let onSaveMeal: (MealDraft) -> Void
    let onAddWater: (Double) -> Void
    let onRecordWeight: (Double) -> Void
    @State private var activeSheet: NutritionSheet?
    @State private var water = "0.25"
    @State private var weight = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PremiumBackground()
            VStack(alignment: .leading, spacing: 16) {
                Text("Быстро добавить")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 10)], spacing: 10) {
                    quickAction("Фото еды", icon: "camera", tint: AppColors.green) { activeSheet = .photo }
                    quickAction("Добавить вручную", icon: "pencil", tint: AppColors.blue) { activeSheet = .manual }
                    quickAction("Найти продукт", icon: "magnifyingglass", tint: AppColors.orange) { activeSheet = .search }
                }

                PremiumCard(padding: 14, radius: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Вода")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        HStack {
                            PremiumTextField(placeholder: "Литры", text: $water, keyboard: .decimalPad)
                            PremiumButton(title: "Добавить", icon: "drop.fill", tint: AppColors.blue) {
                                onAddWater(number(water))
                                dismiss()
                            }
                        }
                    }
                }

                PremiumCard(padding: 14, radius: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Вес")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        HStack {
                            PremiumTextField(placeholder: "кг", text: $weight, keyboard: .decimalPad)
                            PremiumButton(title: "Сохранить", icon: "scalemass", tint: AppColors.purple) {
                                onRecordWeight(number(weight))
                                dismiss()
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(22)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .photo:
                PhotoFoodSheet { draft in
                    onSaveMeal(draft)
                    activeSheet = nil
                    dismiss()
                }
            case .manual:
                ManualFoodSheet { draft in
                    onSaveMeal(draft)
                    activeSheet = nil
                    dismiss()
                }
            case .search:
                SearchFoodSheet { draft in
                    onSaveMeal(draft)
                    activeSheet = nil
                    dismiss()
                }
            case .details, .allMeals:
                EmptyView()
            }
        }
    }

    private func quickAction(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                IconBadge(systemName: icon, tint: tint, size: 46)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.060))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func number(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}
