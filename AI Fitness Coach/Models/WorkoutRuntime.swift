import Foundation

enum WorkoutPhase: Equatable {
    case runningExercise
    case resting
    case paused
    case completed
}

struct WorkoutFlowEngine: Equatable {
    var exerciseIndex: Int = 0
    var setIndex: Int = 1
    var setsPerExercise: Int = 4
    var exerciseCount: Int
    var phase: WorkoutPhase = .runningExercise
    var elapsedBeforePause: TimeInterval = 0
    var startedAt: Date = .now
    var pausedAt: Date?

    var elapsed: TimeInterval {
        if let pausedAt {
            return elapsedBeforePause + pausedAt.timeIntervalSince(startedAt)
        }
        return elapsedBeforePause + Date().timeIntervalSince(startedAt)
    }

    mutating func pause(now: Date = .now) {
        guard phase == .runningExercise || phase == .resting else { return }
        pausedAt = now
        phase = .paused
    }

    mutating func resume(previousPhase: WorkoutPhase = .runningExercise, now: Date = .now) {
        guard phase == .paused else { return }
        if let pausedAt {
            elapsedBeforePause += pausedAt.timeIntervalSince(startedAt)
        }
        startedAt = now
        pausedAt = nil
        phase = previousPhase == .paused ? .runningExercise : previousPhase
    }

    mutating func finishSet() {
        guard phase == .runningExercise else { return }
        if setIndex < setsPerExercise {
            setIndex += 1
            phase = .resting
        } else if exerciseIndex < exerciseCount - 1 {
            exerciseIndex += 1
            setIndex = 1
            phase = .resting
        } else {
            phase = .completed
        }
    }

    mutating func skipRest() {
        guard phase == .resting else { return }
        phase = .runningExercise
    }
}

struct RestCountdown: Equatable {
    var duration: TimeInterval
    var endDate: Date
    var pausedRemaining: TimeInterval?

    init(duration: TimeInterval = 90, now: Date = .now) {
        self.duration = duration
        self.endDate = now.addingTimeInterval(duration)
    }

    var isPaused: Bool { pausedRemaining != nil }

    func remaining(now: Date = .now) -> TimeInterval {
        max(0, pausedRemaining ?? endDate.timeIntervalSince(now))
    }

    mutating func add(_ seconds: TimeInterval, now: Date = .now) {
        if let pausedRemaining {
            self.pausedRemaining = pausedRemaining + seconds
        } else {
            endDate = endDate.addingTimeInterval(seconds)
        }
        duration += seconds
    }

    mutating func pause(now: Date = .now) {
        pausedRemaining = remaining(now: now)
    }

    mutating func resume(now: Date = .now) {
        guard let pausedRemaining else { return }
        endDate = now.addingTimeInterval(pausedRemaining)
        self.pausedRemaining = nil
    }
}
