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
                    appState.openAlice(with: prompt)
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
            VStack(alignment: .leading, spacing: 16) {
                Text("Алиса")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Спроси Алису...", text: $prompt, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.075)))
                    .frame(maxWidth: .infinity, alignment: .leading)

                PremiumButton(title: "Спросить Алису", icon: "paperplane.fill", tint: AppColors.purple) {
                    let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    submit(text)
                }

                openFullChatButton

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Быстрые запросы")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                            quickPrompt("Сфотографировать еду", "Я хочу сфотографировать еду и оценить калории.")
                            quickPrompt("Спросить Алису", "Сколько калорий и белка мне осталось сегодня?")
                            quickPrompt("Разобрать прогресс", "Проанализируй мой вес и прогресс за последнее время.")
                            quickPrompt("Выбрать фото", "Я хочу отправить фото еды и понять, подходит ли оно моей цели.")
                            quickPrompt("Плато веса", "Почему вес может стоять и что изменить без голодовки?")
                            quickPrompt("Белок", "Сколько белка мне осталось и чем его добрать?")
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
            .padding(22)
        }
    }

    private var openFullChatButton: some View {
        Button {
            Haptics.tap()
            openChat()
        } label: {
            HStack(spacing: 12) {
                IconBadge(systemName: "sparkles", tint: AppColors.purple, size: 44)
                Text("Открыть Алису")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.mutedText)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.060)))
        }
        .buttonStyle(.plain)
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
