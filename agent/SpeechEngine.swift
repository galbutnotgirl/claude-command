import Speech
import AVFoundation

enum DictationMode { case insert, addToClaudeChat }

final class SpeechEngine: NSObject, SFSpeechRecognizerDelegate {
    static let shared = SpeechEngine()

    var onPartialResult: ((String) -> Void)?
    var onFinalResult: ((String, DictationMode) -> Void)?
    var onError: ((String) -> Void)?

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: DispatchSourceTimer?
    private var currentMode: DictationMode = .insert
    private var lastTranscript: String = ""
    private var _isRecording = false
    private var audioFile: AVAudioFile?
    var lastAudioFile: URL?

    var isRecording: Bool { _isRecording }

    private override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        recognizer?.delegate = self
    }

    func start(mode: DictationMode) {
        guard !_isRecording else { return }
        currentMode = mode
        lastTranscript = ""

        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard authStatus == .authorized else {
                DispatchQueue.main.async {
                    self?.onError?("Speech recognition not authorized.")
                }
                return
            }
            if #available(macOS 14.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    if granted {
                        DispatchQueue.main.async { self?.startEngine() }
                    } else {
                        DispatchQueue.main.async {
                            self?.onError?("Microphone access denied.")
                        }
                    }
                }
            } else {
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    if granted {
                        DispatchQueue.main.async { self?.startEngine() }
                    } else {
                        DispatchQueue.main.async {
                            self?.onError?("Microphone access denied.")
                        }
                    }
                }
            }
        }
    }

    private func startEngine() {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            onError?("Speech recognizer unavailable.")
            return
        }

        let engine = AVAudioEngine()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true

        let vocab = loadVocab()
        if !vocab.isEmpty {
            req.contextualStrings = Array(vocab.prefix(100))
        }

        let inputNode = engine.inputNode
        let fmt = inputNode.outputFormat(forBus: 0)

        // Open a WAV file alongside SFSpeechRecognizer so whisper can post-process.
        let wavPath = NSTemporaryDirectory() + "dictation_\(Date().timeIntervalSince1970).wav"
        let wavURL = URL(fileURLWithPath: wavPath)
        let wavFile = try? AVAudioFile(forWriting: wavURL, settings: fmt.settings)
        audioFile = wavFile
        lastAudioFile = wavFile != nil ? wavURL : nil

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            self?.request?.append(buf)
            try? self?.audioFile?.write(from: buf)
        }

        do {
            try engine.start()
        } catch {
            onError?("Mic tap failed: \(error.localizedDescription)")
            return
        }

        audioEngine = engine
        request = req
        _isRecording = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                self.lastTranscript = text
                DispatchQueue.main.async {
                    self.onPartialResult?(text)
                }
                self.resetSilenceTimer()

                if result.isFinal {
                    self.finalize(text: text)
                }
            }

            if let error = error {
                // Code 216: recognition session ended normally (stop was called). Code 203: no speech detected.
                let nsErr = error as NSError
                if nsErr.code == 216 || nsErr.code == 203 { return }
                DispatchQueue.main.async {
                    self.onError?(error.localizedDescription)
                }
                self.tearDown()
            }
        }

        resetSilenceTimer()
    }

    func stop() {
        guard _isRecording else { return }
        cancelSilenceTimer()
        // Signal end of audio — recognizer will deliver a final result asynchronously.
        request?.endAudio()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        _isRecording = false

        // Flush whatever we have if the recognizer doesn't deliver isFinal in time.
        let captured = lastTranscript
        let mode = currentMode
        DispatchQueue.main.asyncAfter(deadline: .now() + readDictationSilenceTimeout()) { [weak self] in
            guard let self = self, self.task != nil else { return }
            self.task?.cancel()
            self.task = nil
            if !captured.isEmpty {
                self.onFinalResult?(captured, mode)
            }
        }
    }

    func cancel() {
        cancelSilenceTimer()
        task?.cancel()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request = nil
        task = nil
        audioEngine = nil
        audioFile = nil
        _isRecording = false
        lastTranscript = ""
        // Don't leave a partial recording for whisper to pick up.
        if let url = lastAudioFile { try? FileManager.default.removeItem(at: url) }
        lastAudioFile = nil
    }

    // MARK: - Silence detection

    private func resetSilenceTimer() {
        cancelSilenceTimer()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + readDictationSilenceTimeout())
        t.setEventHandler { [weak self] in
            guard let self = self, self._isRecording else { return }
            let text = self.lastTranscript
            let mode = self.currentMode
            self.tearDown()
            if !text.isEmpty {
                self.onFinalResult?(text, mode)
            }
        }
        t.resume()
        silenceTimer = t
    }

    private func cancelSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = nil
    }

    // MARK: - Internal

    private func finalize(text: String) {
        let mode = currentMode
        tearDown()
        guard !text.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onFinalResult?(text, mode)
        }
    }

    private func tearDown() {
        cancelSilenceTimer()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        task?.cancel()
        audioEngine = nil
        request = nil
        task = nil
        _isRecording = false
        // AVAudioFile closes and finalizes on dealloc — nil-ing flushes the WAV header.
        audioFile = nil
    }

    private func loadVocab() -> [String] {
        let path = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".claude/state/dictation-vocab.json")
        guard let data = FileManager.default.contents(atPath: path),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String]
        else { return [] }
        return arr
    }

    // MARK: - SFSpeechRecognizerDelegate

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer,
                          availabilityDidChange available: Bool) {
        if !available && _isRecording {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("Speech recognizer became unavailable.")
            }
            tearDown()
        }
    }
}
