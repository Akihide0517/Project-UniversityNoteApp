//
//  settingViewController.swift
//  rokuon-test
//
//  Created by 吉田成秀 on 2025/05/28.
//

import UIKit

var transMode = true

class SettingViewController: UIViewController {
    
    @IBOutlet weak var silenceDB: UITextField!
    @IBOutlet weak var silenceTime: UITextField!
    @IBOutlet weak var targetGain: UITextField!
    @IBOutlet weak var selectTrans: UISwitch!
    
    @IBAction func succesButton(_ sender: Any) {
        guard let thresholdText = silenceDB.text,
              let timeoutText = silenceTime.text,
              let gainText = targetGain.text,
              let threshold = Float(thresholdText),
              let AudioGain = Float(gainText),
              let timeout = Double(timeoutText) else {
            print("無効な入力値")
            return
        }

        silenceThreshold = threshold
        silenceTimeout = timeout
        gain = AudioGain
        let defaults = UserDefaults.standard
        defaults.set(threshold, forKey: "silenceThreshold")
        defaults.set(timeout, forKey: "silenceTimeout")
        defaults.set(AudioGain, forKey: "targetGain")
        defaults.synchronize()
        
        if(selectTrans.isOn){
            transMode = true
            print("ON")
            defaults.set(transMode, forKey: "transMode")
        }else{
            transMode = false
            print("OFF")
            defaults.set(transMode, forKey: "transMode")
        }

        print("設定を保存しました")
    }
    
    private func addDoneButtonOnKeyboard() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "完了", style: .done, target: self, action: #selector(doneButtonAction))
        toolbar.items = [flexSpace, doneButton]

        silenceDB.inputAccessoryView = toolbar
        silenceTime.inputAccessoryView = toolbar
        targetGain.inputAccessoryView = toolbar
    }

    @objc func doneButtonAction() {
        view.endEditing(true)
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        let threshold = defaults.float(forKey: "silenceThreshold")
        let timeout = defaults.double(forKey: "silenceTimeout")
        let AudioGain = defaults.float(forKey: "targetGain")
        let trans = defaults.bool(forKey: "transMode")
        
        if threshold != 0.0 {
            silenceThreshold = threshold
            silenceDB.text = String(format: "%.1f", threshold)
        }
        if timeout != 0.0 {
            silenceTimeout = timeout
            silenceTime.text = String(format: "%.1f", timeout)
        }
        if AudioGain != 0.0 {
            gain = AudioGain
            targetGain.text = String(format: "%.1f", AudioGain)
        }
        
        selectTrans.setOn(trans, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addDoneButtonOnKeyboard()
        loadSettings()
    }
}
