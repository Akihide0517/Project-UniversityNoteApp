//
//  settingViewController.swift
//  rokuon-test
//
//  Created by 吉田成秀 on 2025/05/28.
//

import UIKit

class SettingViewController: UIViewController {
    
    @IBOutlet weak var silenceDB: UITextField!
    @IBOutlet weak var silenceTime: UITextField!
    
    @IBAction func succesButton(_ sender: Any) {
        guard let thresholdText = silenceDB.text,
              let timeoutText = silenceTime.text,
              let threshold = Float(thresholdText),
              let timeout = Double(timeoutText) else {
            print("無効な入力値")
            return
        }

        silenceThreshold = threshold
        silenceTimeout = timeout
        let defaults = UserDefaults.standard
        defaults.set(threshold, forKey: "silenceThreshold")
        defaults.set(timeout, forKey: "silenceTimeout")
        defaults.synchronize()

        print("設定を保存しました")
    }
    
    func addDoneButtonOnKeyboard() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "完了", style: .done, target: self, action: #selector(doneButtonAction))
        toolbar.items = [flexSpace, doneButton]

        silenceDB.inputAccessoryView = toolbar
        silenceTime.inputAccessoryView = toolbar
    }

    @objc func doneButtonAction() {
        view.endEditing(true)
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        let threshold = defaults.float(forKey: "silenceThreshold")
        let timeout = defaults.double(forKey: "silenceTimeout")
        
        if threshold != 0 {
            silenceThreshold = threshold
            silenceDB.text = String(format: "%.1f", threshold)
        }
        if timeout != 0 {
            silenceTimeout = timeout
            silenceTime.text = String(format: "%.1f", timeout)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addDoneButtonOnKeyboard()
        loadSettings()
    }
}
