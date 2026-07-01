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
            CommandGroup(after: .toolbar) {
                Button(state.showControlPanel ? "Hide Toolbar" : "Show Toolbar") {
                    state.showControlPanel.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command, .option])
                
                Button(state.showStatusBar ? "Hide Status Bar" : "Show Status Bar") {
                    state.showStatusBar.toggle()
                }
                .keyboardShortcut("/", modifiers: [.command])
            }
        }
    }
}

// アプリケーションループの開始
SagaApp.main()
