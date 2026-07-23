import Foundation

final class TimerManager: ObservableObject {
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var isRunning: Bool = false

    private var timer: Timer?

    var elapsedTimeText: String {
        format(seconds: elapsedSeconds)
    }

    func start() {
        guard !isRunning else {
            return
        }

        isRunning = true
        scheduleTimerIfNeeded()
    }

    func pause() {
        guard isRunning else {
            return
        }

        isRunning = false
        invalidateTimer()
    }

    func resume() {
        start()
    }

    func stop() {
        isRunning = false
        invalidateTimer()
    }

    func reset() {
        stop()
        elapsedSeconds = 0
    }

    private func scheduleTimerIfNeeded() {
        guard timer == nil else {
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.isRunning else {
                return
            }

            self.elapsedSeconds += 1
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func format(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}
