import Charts
import SwiftData
import SwiftUI

struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \DailyMetric.date) private var metrics: [DailyMetric]

    @State private var newWeight = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Прогресс")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Вес")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Chart(series) { point in
                            LineMark(x: .value("Дата", point.date), y: .value("Вес", point.weight))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Color.greenAccent)
                                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            AreaMark(x: .value("Дата", point.date), y: .value("Вес", point.weight))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Color.greenAccent.opacity(0.14))
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 220)
                    }
                }

                GlassPanel {
                    HStack(spacing: 12) {
                        TextField("Новый вес", text: $newWeight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        Button("Записать") {
                            addWeight()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.greenAccent)
                    }
                }

                ForEach(metrics.reversed()) { metric in
                    GlassPanel {
                        HStack {
                            Text(metric.date, format: .dateTime.day().month().year())
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            Text("\(String(format: "%.1f", metric.weightKg)) кг")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 110)
        }
    }

    private var series: [ProgressPoint] {
        if !metrics.isEmpty {
            return metrics.map { ProgressPoint(date: $0.date, weight: $0.weightKg) }
        }

        guard let profile = profiles.first else { return [] }
        return [ProgressPoint(date: .now, weight: profile.currentWeightKg)]
    }

    private func addWeight() {
        let value = Double(newWeight.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard value > 0 else { return }
        modelContext.insert(DailyMetric(date: .now, weightKg: value))
        if let profile = profiles.first {
            profile.currentWeightKg = value
            profile.updatedAt = .now
        }
        try? modelContext.save()
        newWeight = ""
    }
}

private struct ProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
}
