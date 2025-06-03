# Project-UniversityNoteApp
 
授業を録音してAIに自動でノートを作成してもらう、実にけしからんアプリ。

単一の音声ファイルの容量の増大を防ぐため、無音を感知したら自動でファイルを分けつつ、先に分けたものから自動で文字起こしを行ってます。
 
# IMAGE
![Image](https://github.com/user-attachments/assets/80f41f5a-1ef7-4fcb-8922-a3f46976abc3)
 
# Requirement
 
* Xcode16.2で作成
* iOS17で動作確認
* Speechライブラリを使用
* gemini APIを使用
* クソ汚いコード
 
# Usage
 
xcodeプロジェクト作成時に生成される一番上のファイルの中身をrokuon-testの中身で上書きして下さい。
 
# Note
 
録音中に無音を感知したらファイルに保存を試みます。

n秒間無音なら一旦録音を保存して即座に再開します。保存が終了する前に停止すると保存される前の情報が消えるので注意！

言語選択はアプリ起動時の最初の録音前にして下さい。

### ・データは端末をシェイクすると抹消できますが、本当に全て消すので注意！

### ・ノート生成機能を使うにはgemini APIを使えるようにする必要があります！

導入方法はこの[サイト](https://zenn.dev/oka_yuuji/articles/3eb8c91e50c927)を参考にして下さい。

# プロパティ

Info.plistに以下の許諾説明を追加して下さい。

Privacy - NSSpeechRecognitionUsageDescription: このアプリは音声認識機能を使用します。

Privacy - Microphone Usage Description: このアプリはマイクを使用します。
 
# Author
 
* 作成者：damakatu
   
# License
GPL大好きなのでGPLにしてます。（ただの害悪）
