import AVFoundation
import Accelerate
import Speech

// グローバル変数はあまり良くないのは承知済み…☆
var fileIndex = 0
var silenceThreshold: Float = -50  // dB
var silenceTimeout: TimeInterval = 5.0 // s
var gain: Float = 0.1

class AudioRecorderManager {
    private let engine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    private let ioQueue = DispatchQueue(label: "com.example.AudioIO")
    private let fileQueue = DispatchQueue(label: "com.example.FileWrite")
    private var currentFile: AVAudioFile?
    private var isRecording = false
    private var viewController: ViewController?  // 必要に応じて変更
    public var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var silenceStartTime: TimeInterval?
    private var previousSamples: [Float] = []
    private var previousGain: Float = 1.0  // ゲインのスムージング用

    // 追加: シリアルな STT キュー
    private let sttQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.example.STTQueue"
        q.maxConcurrentOperationCount = 1
        return q
    }()

    private lazy var transcriptURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("transcript.txt")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
        }
        return url
    }()

    init() throws {
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
        SFSpeechRecognizer.requestAuthorization { _ in }
    }

    // MARK: – 録音開始
    func startRecording() throws {
        guard !isRecording else { return }

        isRecording = true
        try session.setActive(true)
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 4056, format: format) { [weak self] buf, _ in
            self?.ioQueue.async { self?.process(buffer: buf) }
        }
        engine.prepare()
        try engine.start()

        rotateFile()
        print("Recording started")
    }

    // MARK: – 録音停止
    func stopRecording() {
        guard isRecording else { return }

        isRecording = false

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])

        // 最後のセグメントもシリアルキューに投入
        if let lastURL = currentFile?.url {
            sttQueue.addOperation {
                self.transcribeAndAppendAndDelete(from: lastURL)
            }
        }

        print("Recording stopped")
    }

    private func process(buffer: AVAudioPCMBuffer) {
        detectSilence(in: buffer)
        guard let file = currentFile else { return }

        let copy = buffer.copy() as! AVAudioPCMBuffer

        // --- 高周波ノイズ除去（ローパスフィルタ） ---
        if let channelData = copy.floatChannelData {
            let frameLength = Int(copy.frameLength)
            let sampleRate = Float(copy.format.sampleRate)
            let cutoffFreq: Float = 5000.0

            let dt = 1.0 / sampleRate
            let rc = 1.0 / (2 * Float.pi * cutoffFreq)
            let alpha = dt / (rc + dt)

            let channelCount = Int(copy.format.channelCount)

            // previousSamples 初期化（初回のみ）
            if previousSamples.count != channelCount {
                previousSamples = Array(repeating: 0.0, count: channelCount)
            }

            for channel in 0..<channelCount {
                var prev = previousSamples[channel]
                for i in 0..<frameLength {
                    let input = channelData[channel][i]
                    prev = prev + alpha * (input - prev)
                    channelData[channel][i] = prev
                }
                previousSamples[channel] = prev  // 次回に持ち越す
            }
        }

        // --- 無制限ゲイン補正開始（スムージングあり） ---
        if let channelData = copy.floatChannelData {
            let frameLength = Int(copy.frameLength)
            let channelCount = Int(copy.format.channelCount)
            var maxAmplitude: Float = 0

            for channel in 0..<channelCount {
                var localMax: Float = 1
                vDSP_maxmgv(channelData[channel], 1, &localMax, vDSP_Length(frameLength))
                maxAmplitude = max(maxAmplitude, localMax)
            }

            if maxAmplitude > 0.001 {
                var targetGain: Float = (gain * 5) / maxAmplitude
                targetGain = min(targetGain, 10.0)  // 最大10倍まで制限
                let smoothedGain = 0.1 * targetGain + 0.9 * previousGain
                previousGain = smoothedGain  // 保存

                for channel in 0..<channelCount {
                    vDSP_vsmul(channelData[channel], 1, [smoothedGain], channelData[channel], 1, vDSP_Length(frameLength))
                }
            }
        }
        // --- 無制限ゲイン補正終了 ---

        fileQueue.async {
            try? file.write(from: copy)
        }
    }


    // MARK: – 無音検知
    private func detectSilence(in buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }

        let length = vDSP_Length(buffer.frameLength)
        var ms: Float = 0
        vDSP_measqv(data, 1, &ms, length)
        let rmsDB = 10 * log10(ms)
        let now = CACurrentMediaTime()

        if rmsDB < silenceThreshold {
            if silenceStartTime == nil {
                silenceStartTime = now
            } else if now - silenceStartTime! >= silenceTimeout {
                silenceStartTime = now
                rotateFile()
            }
        } else {
            silenceStartTime = nil
        }
    }

    // MARK: – ファイルを切り替え（回転）して、前ファイルを STT キューに投入
    private func rotateFile() {
        // もし currentFile が nil でないなら、一旦前ファイルの URL を取っておく
        let previousURL = currentFile?.url

        // 新しいファイルを作る
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = String(format: "segment_%03d.caf", fileIndex)
        let url = docs.appendingPathComponent(filename)
        fileIndex += 1

        let format = engine.inputNode.outputFormat(forBus: 0)
        currentFile = try? AVAudioFile(forWriting: url, settings: format.settings)

        DispatchQueue.main.async {
            print("New file:", filename)
        }

        // --- 前ファイルを STT キューに載せる前に「ファイル長チェック」を入れる ---
        if let prev = previousURL {
            // ファイルが存在してサイズや録音時間が短すぎないかチェック
            if let attr = try? FileManager.default.attributesOfItem(atPath: prev.path),
               let fileSize = attr[.size] as? UInt64,
               fileSize > 1024 * 1  // 10KB より小さければ録音がほとんどないとみなす、など
            {
                sttQueue.addOperation {
                    self.transcribeAndAppendAndDelete(from: prev)
                }
            } else {
                // サイズが小さすぎるセグメントは STT せずに直接削除
                try? FileManager.default.removeItem(at: prev)
                print("Skipped tiny segment:", prev.lastPathComponent)
            }
        }
    }
    
    // MARK: – 文字起こし＋リトライ＋完了後にファイル削除
    private func transcribeAndAppendAndDelete(from audioURL: URL, retryCount: Int = 0) {
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = false

        guard speechRecognizer.isAvailable else {
            print("Speech recognizer is not available. Deleting file:", audioURL.lastPathComponent)
            try? FileManager.default.removeItem(at: audioURL)
            return
        }

        speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result, result.isFinal {
                let str = result.bestTranscription.formattedString
                // transcript.txt に追記
                self.append(text: "\n" + str + "\n")
                DispatchQueue.main.async {
                    self.viewController?.sttText.text += self.transText(text: str)
                }
                // 正常終了 → ファイル削除
                try? FileManager.default.removeItem(at: audioURL)
                print("Deleted file after STT:", audioURL.lastPathComponent)
            }
            else if let error = error {
                print("Transcribe error:", error.localizedDescription, "for", audioURL.lastPathComponent)
                // リトライ上限未満なら、少し待って再投入
                if retryCount < 1 {
                    let nextRetry = retryCount + 1
                    print("Retry STT (\(nextRetry)) for", audioURL.lastPathComponent)
                    // 少し遅延を入れて同じファイルで再試行
                    DispatchQueue.global().asyncAfter(deadline: .now()+1) {//+1
                        self.transcribeAndAppendAndDelete(from: audioURL, retryCount: nextRetry)
                    }
                } else {
                    // リトライ上限に達したらあきらめて削除
                    print("Giving up STT for", audioURL.lastPathComponent)
                    try? FileManager.default.removeItem(at: audioURL)
                }
            }
        }
    }

    private func transText(text: String) -> String {
        return text
    }

    private func append(text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            let handle = try FileHandle(forWritingTo: transcriptURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            print("Append error:", error)
        }
    }

    // MARK: – 全ファイル削除 + transcript.txt の初期化
    func clearAllFiles() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dt = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"

        do {
            let items = try fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)
            for url in items {
                let name = url.lastPathComponent
                if name.hasPrefix("segment_") && name.hasSuffix(".caf")
                   || name == "transcript.txt" {
                    try fm.removeItem(at: url)
                    print("Removed:", name)
                }
            }

            fm.createFile(atPath: transcriptURL.path, contents: nil, attributes: nil)
            append(text: dateFormatter.string(from: dt) + "\n")
            print("Cleared transcript.txt and recreated empty file")
        } catch {
            print("Failed to clear files:", error)
        }
    }
}
