//
//  CreateViewControler.swift
//  rokuon-test
//
//  Created by 吉田成秀 on 2025/06/03.
//

import UIKit
import GoogleGenerativeAI

class CreateViewController: UIViewController {
    
    @IBOutlet weak var titleText: UITextField!
    
    @IBAction func createButton(_ sender: Any) {
        Task { @MainActor in
            guard let apiKey = UserDefaults.standard.string(forKey: "geminiApiKey"), !apiKey.isEmpty else {
                print("APIキーが未設定です")
                return
            }

            let model = GenerativeModel(name: "gemini-1.5-flash", apiKey: apiKey)

            if message == "" {
                message = "ひたすらにけしからん文章を書いて下さい。"
                self.resultText.text = "生成中..."
            }
            let prompt = ""+"#授業内容の要約を作成してください。要約は、以下の構成要素を含み、読み手が授業の核心を理解し、さらに学びを深められるように記述してください。"+"# 要約に含める要素"+"1. **授業の概要 (Brief Summary)**"+"- この授業の中心的なテーマや問いは何か？"+"- 授業全体の流れ（導入、展開、結論など）はどのようなものだったか？"+"- 講師が最終的に伝えたかったメッセージや到達目標は何か？"+"2. **重要ポイント (Key Takeaways)**"+"- 授業内で特に強調されていた、あるいは繰り返し述べられていた点は何か？（3〜5点程度）"+"- 講師が「重要」「覚えておいてほしい」などと強調した箇所はどこか？"+"3. **キーワード・専門用語 (Keywords & Concepts)**"+"- 授業内容の理解に不可欠なキーワードや専門用語をリストアップしてください。"+"- 各用語について、授業の文脈に沿った簡潔な説明（1〜2文程度）を加えてください。"+"4. **詳細な内容 (Detailed Contents)**"+"- 講師が提示した主要な理論、モデル、フレームワークは何か？"+"- 具体的な事例、データ、エピソード、引用など、主張を裏付けるために用いられたものは何か？"+"- （もし言及されていれば）参考文献や参考資料は何か？"+"5. **考察とネクストステップ (Insights & Next Steps)**"+"- この授業から得られる重要な視点や学びは何か？"+"- 受講者が次に取るべきアクションや、さらに探求すべき問いは何か？"+"- 今後の学習や研究に役立つ、講師からのアドバイスやヒントはあったか？"+"# 出力形式"+"- 各要素が明確に区別できるように、見出しや箇条書きを適切に使用してください。"+"- 専門用語の説明は、専門知識がない人にも理解できるように、平易な言葉で記述してください。"+"- 全体の構成が論理的で、情報が整理されているようにしてください。"+"- 【任意】全体の分量を[例：A4用紙1枚程度、1000字以内]に収めてください。"+"- 【任意】特に[例：〇〇理論]に関する部分を重点的に記述してください。"+"- 【任意】対象読者を[例：授業を受けた自分自身、欠席した友人、後輩]と想定して記述してください。"+"- 【任意】文脈的・単語的に曖昧な文章があれば、事実として存在する情報を使って補完しても良いです。嘘はつかないでください。"+"# 授業内容"+"\(message)"

            do {
                let response = try await model.generateContent(prompt)
                if let text = response.text {
                    print(text)
                    self.resultText.text = text
                }
            } catch {
                print("エラー: \(error)")
            }
        }
    }
    
    @IBOutlet weak var resultText: UITextView!
    
    @IBAction func saveButton(_ sender: Any) {
        let text = resultText.text ?? ""
        
        // 一時ファイルのURLを作成
        let fileTitle = titleText.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = "\(fileTitle?.isEmpty == false ? fileTitle! : "けしからん").txt"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            // テキストを書き込み
            try text.write(to: path, atomically: true, encoding: .utf8)
            
            // UIActivityViewControllerでファイルを共有
            let activityVC = UIActivityViewController(activityItems: [path], applicationActivities: nil)
            
            // iPad対策
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = (sender as! UIView).frame
            }

            self.present(activityVC, animated: true, completion: nil)
        } catch {
            print("ファイルの保存に失敗しました: \(error)")
        }
    }
    
    private func addDoneButtonOnKeyboard() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "完了", style: .done, target: self, action: #selector(doneButtonAction))
        toolbar.items = [flexSpace, doneButton]

        titleText.inputAccessoryView = toolbar
    }

    @objc func doneButtonAction() {
        view.endEditing(true)
    }
    
    func checkAndPromptForApiKey() {
        let hasLaunchedKey = "hasLaunchedBefore"
        let apiKeyKey = "geminiApiKey"

        let hasLaunched = UserDefaults.standard.bool(forKey: hasLaunchedKey)
        let savedApiKey = UserDefaults.standard.string(forKey: apiKeyKey)

        // 初回またはAPIキー未登録の場合はアラートでAPIキーを入力
        if !hasLaunched || savedApiKey == nil {
            let alert = UIAlertController(title: "APIキー入力", message: "Gemini APIキーを入力してください", preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "APIキーを入力"
            }

            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                if let apiKey = alert.textFields?.first?.text, !apiKey.isEmpty {
                    UserDefaults.standard.set(true, forKey: hasLaunchedKey)
                    UserDefaults.standard.set(apiKey, forKey: apiKeyKey)
                } else {
                    // 入力されなかった場合は再度表示
                    self.checkAndPromptForApiKey()
                }
            })

            present(alert, animated: true, completion: nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addDoneButtonOnKeyboard()
    }
    
    var didCheckApiKey = false  // 一度だけチェックするためのフラグ

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !didCheckApiKey {
            didCheckApiKey = true
            checkAndPromptForApiKey()
        }
    }
}
