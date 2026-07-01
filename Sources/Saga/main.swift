import Cocoa
import SwiftUI
import SagaCore

// GUIアプリとしての初期化（ドックアイコンやメニューバーの表示を有効化）
let app = NSApplication.shared
app.setActivationPolicy(.regular)

// アプリアイコンの設定
if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
   let iconImage = NSImage(contentsOf: iconURL) {
    app.applicationIconImage = iconImage
}

struct SagaApp: App {
    @StateObject private var state = SagaViewerState()
    
    var body: some Scene {
        WindowGroup("SAGA (Swift AVIF Graphic Assistant)") {
            ContentView(state: state)
        }
        .commands {
            CommandMenu("表示") {
                Button(state.showControlPanel ? "ツールバーを非表示にする" : "ツールバーを表示する") {
                    state.showControlPanel.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command, .option])
                
                Divider()
                
                Button(state.showStatusBar ? "ステータスバーを非表示にする" : "ステータスバーを表示する") {
                    state.showStatusBar.toggle()
                }
                .keyboardShortcut("/", modifiers: [.command])
            }
        }
    }
}

// アプリケーションループの開始
SagaApp.main()
