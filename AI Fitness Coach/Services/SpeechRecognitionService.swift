import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechRecognitionService: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() async {
        errorMessage = nil
        transcript = ""

        guard await requestPermissions() else { return }
        stop()

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        request = recognitionRequest

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak recognitionRequest] buffer, _ in
                recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            task = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    if let result {
                        self?.transcript = result.bestTranscription.formattedString
                    }
                    if let error {
                        self?.errorMessage = error.localizedDescription
                        self?.stop()
                    } else if result?.isFinal == true {
                        self?.stop()
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            stop()
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestPermissions() async -> Bool {
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechAllowed else {
            errorMessage = "Разрешите распознавание речи в Настройках iOS."
            return false
        }

        let micAllowed = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
        guard micAllowed else {
            errorMessage = "Разрешите доступ к микрофону в Настройках iOS."
            return false
        }

        guard recognizer?.isAvailable == true else {
            errorMessage = "Распознавание речи сейчас недоступно."
            return false
        }

        return true
    }
}
