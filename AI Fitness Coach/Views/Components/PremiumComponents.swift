import SwiftUI

struct GlassPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.11), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 16)
            )
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let target: String
    let progress: Double
    let tint: Color

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))

                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                + Text(" / \(target)")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.58))

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.08))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.75), tint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, proxy.size.width * min(progress, 1.18)))
                    }
                }
                .frame(height: 7)

                Text("\(Int((progress * 100).rounded()))%")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

struct PremiumTabBar: View {
    @Binding var selected: CoachTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CoachTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: tab == .coach ? 24 : 20, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(selected == tab ? Color.purpleAccent : .white.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.black.opacity(0.38))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                .ignoresSafeArea(edges: .bottom)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

extension Color {
    static let purpleAccent = Color(red: 0.65, green: 0.45, blue: 1.0)
    static let greenAccent = Color(red: 0.28, green: 0.92, blue: 0.45)
    static let yellowAccent = Color(red: 1.0, green: 0.82, blue: 0.24)
    static let blueAccent = Color(red: 0.22, green: 0.56, blue: 1.0)
}
