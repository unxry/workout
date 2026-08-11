import Foundation
import HealthKit

struct HealthActivitySnapshot: Equatable {
    let steps: Int
    let activeEnergyKcal: Double
}

struct StepHourBucket: Identifiable, Equatable {
    var id: Date { start }
    let start: Date
    let end: Date
    let steps: Int
}

final class HealthKitService {
    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }

        var readTypes = Set<HKObjectType>()
        let identifiers: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .distanceWalkingRunning,
            .bodyMass,
            .height,
            .heartRate,
            .basalEnergyBurned
        ]

        for identifier in identifiers {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                readTypes.insert(type)
            }
        }

        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
        }

        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func todaySteps() async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let sum = try await sumQuantity(type: type, unit: .count(), start: Calendar.current.startOfDay(for: .now), end: .now)
        return Int(sum.rounded())
    }

    func todayActiveEnergy() async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return try await sumQuantity(type: type, unit: .kilocalorie(), start: Calendar.current.startOfDay(for: .now), end: .now)
    }

    func todayActivitySnapshot(calendar: Calendar = .current) async throws -> HealthActivitySnapshot {
        async let steps = todaySteps(calendar: calendar)
        async let energy = todayActiveEnergy(calendar: calendar)
        return try await HealthActivitySnapshot(steps: steps, activeEnergyKcal: energy)
    }

    func todaySteps(calendar: Calendar) async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let start = calendar.startOfDay(for: .now)
        let sum = try await sumQuantity(type: type, unit: .count(), start: start, end: .now)
        return Int(sum.rounded())
    }

    func todayActiveEnergy(calendar: Calendar) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        let start = calendar.startOfDay(for: .now)
        return try await sumQuantity(type: type, unit: .kilocalorie(), start: start, end: .now)
    }

    func hourlySteps(for day: DayContext) async throws -> [StepHourBucket] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        var interval = DateComponents()
        interval.hour = 1

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: day.start, end: day.interval.end),
                options: .cumulativeSum,
                anchorDate: day.start,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var buckets: [StepHourBucket] = []
                collection?.enumerateStatistics(from: day.start, to: min(day.interval.end, .now)) { statistics, _ in
                    let steps = Int((statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0).rounded())
                    if steps > 0 {
                        buckets.append(StepHourBucket(start: statistics.startDate, end: statistics.endDate, steps: steps))
                    }
                }
                continuation.resume(returning: buckets)
            }

            store.execute(query)
        }
    }

    private func sumQuantity(type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }

            store.execute(query)
        }
    }
}
