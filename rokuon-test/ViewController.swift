//
//  ViewController.swift
//  rokuon-test
//
//  Created by 吉田成秀 on 2025/05/28.
//

import UIKit
import Speech

var message: String = ""

class ViewController: UIViewController {
    
    @IBOutlet weak var recodeText: UILabel!
    private var recorder: AudioRecorderManager?
    var timer = Timer()
    var mode: Bool = false

    @IBOutlet weak var sttText: UITextView!
    @IBOutlet weak var selectLang: UISwitch!
    @IBOutlet weak var nowIndex: UILabel!
        
    @IBAction func recodeButton(_ sender: Any) {
        mode = true
        
        if(selectLang.isOn){
            recorder?.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
            print("ON")
        }else{
            recorder?.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
            print("OFF")
        }
        
        guard let recorder = recorder else { return }
        do{
            recodeText.text = "録音中!"
            try recorder.startRecording()
            recodeText.text = "録音中"
        }catch{
            
        }
    }
    
    @IBAction func stopButton(_ sender: Any) {
        mode = false
        recorder?.stopRecording()
        do {
            recorder = try AudioRecorderManager()
            recodeText.text = ""
        } catch {
            print("Recorder init failed: \(error)")
        }
        
        // transcript.txt を読み込んで UITextView に反映
        let fm = FileManager.default
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let transcriptURL = docs.appendingPathComponent("transcript.txt")
                do {
                    let text = try String(contentsOf: transcriptURL, encoding: .utf8)
                    sttText.text = text
                } catch {
                    print("Failed to read transcript.txt:", error)
                    sttText.text = "読み込みに失敗しました。端末をシェイクしてリセットしてからもう一度録音し直してみて下さい。"
                }
            }
        message = sttText.text
    }
    
    // MARK: — シェイク検知
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
            
        let alert = UIAlertController(
            title: "ファイルをクリアしますか？",
            message: "録音ファイルと文字起こしをすべて削除します。",
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "キャンセル", style: .cancel, handler: nil))
        alert.addAction(.init(title: "OK", style: .destructive) { [weak self] _ in
            self?.recorder?.clearAllFiles()
            self?.sttText.text = "初期化しました！"
            self?.nowIndex.text = ""
            fileIndex = 0 // 最初から録音できるようにする
        })
        present(alert, animated: true, completion: nil)
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        let threshold = defaults.float(forKey: "silenceThreshold")
        let timeout = defaults.double(forKey: "silenceTimeout")
        
        if threshold != 0 {
            silenceThreshold = threshold
        }
        if timeout != 0 {
            silenceTimeout = timeout
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadSettings()
        recodeText.text = ""
        
        let defaults = UserDefaults.standard
        let trans = defaults.bool(forKey: "transMode")
        transMode = trans
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("音声認識が許可されました")
            default:
                print("音声認識が許可されていません: \(authStatus)")
            }
        }
        
        do{
            recorder = try AudioRecorderManager()
        }catch{
            
        }
        
        // 1秒毎に処理を実行する
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
            // 一定時間ごとに実行したい処理を記載する
            self.nowIndex.text = String(fileIndex)
            
            if(self.mode){
                // transcript.txt を読み込んで UITextView に反映
                let fm = FileManager.default
                if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let transcriptURL = docs.appendingPathComponent("transcript.txt")
                    do {
                        let text = try String(contentsOf: transcriptURL, encoding: .utf8)
                        self.sttText.text = text
                    } catch {
                        print("Failed to read transcript.txt:", error)
                        self.sttText.text = "読み込みに失敗しました。端末をシェイクしてリセットしてからもう一度録音し直してみて下さい。"
                    }
                }
            }else{
                if(self.selectLang.isOn){
                    self.recorder?.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
                }else{
                    self.recorder?.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
                }
            }
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.recorder?.clearAllFiles()
    }

}
