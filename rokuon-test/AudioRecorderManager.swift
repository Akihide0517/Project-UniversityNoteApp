import AVFoundation
import Accelerate
import Speech

//グローバルはクソなのはわかってるZE☆
var fileIndex = 0
var silenceThreshold: Float = -50  // dB
var silenceTimeout: TimeInterval = 5.0 // s


class AudioRecorderManager {
    private let engine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    private let ioQueue = DispatchQueue(label: "com.example.AudioIO")
    private let fileQueue = DispatchQueue(label: "com.example.FileWrite")
    private var currentFile: AVAudioFile?
    private var isRecording = false
    private var viewController: ViewController?
    public var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var silenceStartTime: TimeInterval?
    
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
        
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
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
        
        // 最後のセグメントも文字起こし→追記
        if let lastURL = currentFile?.url {
            transcribeAndAppend(from: lastURL)
        }
        
        print("Recording stopped")
    }
    
    private func process(buffer: AVAudioPCMBuffer) {
        detectSilence(in: buffer)
        guard let file = currentFile else { return }
        
        let copy = buffer.copy() as! AVAudioPCMBuffer
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
    
    // MARK: – 文字起こし
    private func rotateFile() {
        let previousURL = currentFile?.url
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = String(format: "segment_%03d.caf", fileIndex)
        let url = docs.appendingPathComponent(filename)
        fileIndex += 1
        
        let format = engine.inputNode.outputFormat(forBus: 0)
        currentFile = try? AVAudioFile(forWriting: url, settings: format.settings)
        
        DispatchQueue.main.async {
            print("New file:", filename)
        }
        
        if let prev = previousURL {
            transcribeAndAppend(from: prev)
        }
    }
    
    // MARK: – transcript.txt に追記
    private func transcribeAndAppend(from audioURL: URL) {
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let str = result?.bestTranscription.formattedString, result?.isFinal == true {
                //self.append(text: "\n––– \(audioURL.lastPathComponent) –––\n")
                self.append(text: "\n" + str + "\n")
                viewController?.sttText.text = (viewController?.sttText.text)! + str
            }
            if let e = error {
                print("Transcribe error:", e)
            }
        }
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
    
    func clearAllFiles() {
            let fm = FileManager.default
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            
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
                
                let transcriptURL = docs.appendingPathComponent("transcript.txt")
                
                fm.createFile(atPath: transcriptURL.path, contents: nil, attributes: nil)
                print("Cleared transcript.txt and recreated empty file")
            } catch {
                print("Failed to clear files:", error)
            }
        }
}
