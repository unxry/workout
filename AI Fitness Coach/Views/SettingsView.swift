import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var apiKey = ""
    @State private var notificationStatus = ""
    @State private var healthStatus = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Профиль")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("AI API")
                            .font(.headline)
                            .foregroundStyle(.white)
                        SecureField("OpenAI API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                        Button("Сохранить в Keychain") {
                            appState.saveOpenAIKey(apiKey)
                            apiKey = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.purpleAccent)

                        Text(appState.apiKeyStatus == .configured ? "Ключ сохранен локально на iPhone." : "Без ключа AI работает в fallback-режиме.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HealthKit")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Шаги, активная энергия, вес, сон и рост могут подтягиваться из Apple Health после разрешения.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                        Button("Запросить доступ") {
                            Task {
                                do {
                                    try await appState.healthKit.requestAuthorization()
                                    healthStatus = "Доступ запрошен"
                                } catch {
                                    healthStatus = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.greenAccent)
                        if !healthStatus.isEmpty {
                            Text(healthStatus)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Уведомления")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Ежедневный AI-check-in будет напоминать сверить питание, шаги и восстановление.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                        Button("Включить ежедневный check-in") {
                            Task {
                                do {
                                    let allowed = try await appState.notifications.requestAuthorization()
                                    if allowed {
                                        await appState.notifications.scheduleDailyCoachCheckIn()
                                        notificationStatus = "Включено"
                                    } else {
                                        notificationStatus = "Разрешение не выдано"
                                    }
                                } catch {
                                    notificationStatus = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.yellowAccent)
                        if !notificationStatus.isEmpty {
                            Text(notificationStatus)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 110)
        }
    }
}
