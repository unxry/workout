import SwiftData
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    var body: some View {
        ZStack {
            PremiumBackground()

            if profiles.first == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showQuickActions = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch appState.selectedTab {
                case .home:
                    DashboardView()
                case .nutrition:
                    NutritionView()
                case .coach:
                    CoachView()
                case .progress:
                    ProgressDashboardView()
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
            AIQuickComposerSheet(
                submit: { prompt in
                    showQuickActions = false
                    appState.openCoach(with: prompt)
                },
                openChat: {
                    showQuickActions = false
                    appState.selectedTab = .coach
                }
            )
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct AIQuickComposerSheet: View {
    let submit: (String) -> Void
    let openChat: () -> Void
    @State private var prompt = ""

    var body: some View {
        ZStack {
            PremiumBackground()
            VStack(alignment: .leading, spacing: 18) {
                Text("Задать вопрос ИИ")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                TextField("Напиши вопрос тренеру...", text: $prompt, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.075)))

                PremiumButton(title: "Спросить ИИ", icon: "paperplane.fill", tint: AppColors.purple) {
                    let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    submit(text)
                }

                Text("Быстрые запросы")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 10)], spacing: 10) {
                    quickPrompt("Спросить про питание", "Что мне лучше съесть сегодня вечером?")
                    quickPrompt("Спросить про тренировку", "Какую тренировку сделать сегодня с учетом моего прогресса?")
                    quickPrompt("Разобрать прогресс", "Проанализируй мой вес и прогресс за последнее время.")
                    quickPrompt("Оценить фото", "Я хочу отправить фото еды и оценить калории.")
                    quickPrompt("Плато веса", "Почему вес может стоять и что изменить без голодовки?")
                    quickPrompt("Белок", "Сколько белка мне осталось и чем его добрать?")
                }

                Button {
                    Haptics.tap()
                    openChat()
                } label: {
                    HStack {
                        IconBadge(systemName: "robot", tint: AppColors.purple, size: 44)
                        Text("Открыть полный чат")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppColors.mutedText)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.060)))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(22)
        }
    }

    private func quickPrompt(_ title: String, _ text: String) -> some View {
        Button {
            Haptics.tap()
            submit(text)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "sparkles")
                    .foregroundStyle(AppColors.purple)
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.060))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
