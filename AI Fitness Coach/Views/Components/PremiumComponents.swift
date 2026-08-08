import SwiftUI
import UIKit

enum AppColors {
    static let background = Color(red: 0.005, green: 0.007, blue: 0.011)
    static let panel = Color(red: 0.070, green: 0.078, blue: 0.092)
    static let panelDeep = Color(red: 0.035, green: 0.039, blue: 0.048)
    static let stroke = Color.white.opacity(0.105)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.62)
    static let mutedText = Color.white.opacity(0.42)
    static let purple = Color(red: 0.65, green: 0.39, blue: 1.0)
    static let purpleDeep = Color(red: 0.28, green: 0.15, blue: 0.56)
    static let green = Color(red: 0.25, green: 0.88, blue: 0.43)
    static let yellow = Color(red: 1.0, green: 0.80, blue: 0.20)
    static let blue = Color(red: 0.20, green: 0.55, blue: 1.0)
    static let orange = Color(red: 1.0, green: 0.45, blue: 0.22)
}

enum AppRadius {
    static let card: CGFloat = 22
    static let smallCard: CGFloat = 18
    static let pill: CGFloat = 999
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct PremiumBackground: View {
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            RadialGradient(
                colors: [AppColors.purple.opacity(0.13), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 390
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [AppColors.blue.opacity(0.08), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [.white.opacity(0.025), .clear, .black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

struct PremiumCard<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = AppRadius.card
    let content: Content

    init(padding: CGFloat = 18, radius: CGFloat = AppRadius.card, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.080),
                                AppColors.panel.opacity(0.72),
                                Color.white.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(AppColors.stroke, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.48), radius: 28, x: 0, y: 18)
            )
    }
}

typealias GlassPanel = PremiumCard

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(AppColors.secondaryText)
            Spacer()
            if let actionTitle, let action {
                Button {
                    Haptics.tap()
                    action()
                } label: {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PageHeader: View {
    let title: String
    var subtitle: String?
    var aiTitle: String = "ИИ-помощник"
    var aiIcon: String = "robot"
    var aiAction: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            Spacer(minLength: 16)
            AIHelperButton(title: aiTitle, systemImage: aiIcon, action: aiAction)
                .padding(.top, 4)
        }
    }
}

struct AIHelperButton: View {
    let title: String
    var systemImage: String = "robot"
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.purple)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.060))
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let target: String
    let progress: Double
    let tint: Color

    var body: some View {
        PremiumCard(padding: 16, radius: 19) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.secondaryText)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("/ \(target)")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                GradientProgressBar(progress: progress, tint: tint, height: 7)

                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 122)
    }
}

struct GradientProgressBar: View {
    let progress: Double
    let tint: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.075))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.82), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height, proxy.size.width * min(max(progress, 0), 1.18)))
                    .shadow(color: tint.opacity(0.42), radius: 5, x: 0, y: 0)
            }
        }
        .frame(height: height)
    }
}

struct CircularProgress: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 10
    var size: CGFloat = 126
    var center: AnyView

    init<Center: View>(progress: Double, tint: Color, lineWidth: CGFloat = 10, size: CGFloat = 126, @ViewBuilder center: () -> Center) {
        self.progress = progress
        self.tint = tint
        self.lineWidth = lineWidth
        self.size = size
        self.center = AnyView(center())
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.09), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    LinearGradient(colors: [tint.opacity(0.65), tint], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-88))
                .shadow(color: tint.opacity(0.36), radius: 8)
            center
        }
        .frame(width: size, height: size)
    }
}

struct IconBadge: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 54

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(tint.opacity(0.13))
                    .overlay(Circle().stroke(tint.opacity(0.18), lineWidth: 1))
            )
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            PremiumCard(padding: 14, radius: 18) {
                VStack(spacing: 12) {
                    IconBadge(systemName: icon, tint: tint, size: 54)
                    Text(title)
                    .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 124)
            }
        }
        .buttonStyle(.plain)
    }
}

struct PremiumButton: View {
    let title: String
    var icon: String?
    var tint: Color = AppColors.purple
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.88), tint.opacity(0.62)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: tint.opacity(0.35), radius: 16, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PremiumTabBar: View {
    @Binding var selected: CoachTab
    var plusAction: () -> Void

    private var trailingTab: CoachTab {
        selected == .coach ? .coach : .profile
    }

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.nutrition)
            plusButton
            tabButton(.progress)
            tabButton(trailingTab)
        }
        .padding(.horizontal, 18)
        .padding(.top, 13)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.070), Color.black.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.62), radius: 34, x: 0, y: 20)
                .ignoresSafeArea(edges: .bottom)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private var plusButton: some View {
        Button {
            Haptics.tap()
            plusAction()
        } label: {
            ZStack {
                Circle()
                    .stroke(AppColors.purple, lineWidth: 3)
                    .frame(width: 58, height: 58)
                    .shadow(color: AppColors.purple.opacity(0.35), radius: 12)
                Image(systemName: "plus")
                    .font(.system(size: 29, weight: .light))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func tabButton(_ tab: CoachTab) -> some View {
        Button {
            Haptics.tap()
            selected = tab
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 22, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            .foregroundStyle(selected == tab ? AppColors.purple : Color.white.opacity(0.62))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .clipped()
        }
        .buttonStyle(.plain)
    }
}

struct PremiumTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboard)
            .textFieldStyle(.plain)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.075))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
    }
}

extension Color {
    static let purpleAccent = AppColors.purple
    static let greenAccent = AppColors.green
    static let yellowAccent = AppColors.yellow
    static let blueAccent = AppColors.blue
}
