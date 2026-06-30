import Cocoa
import SwiftUI
import SagaCore

// GUIアプリとしての初期化（ドックアイコンやメニューバーの表示を有効化）
let app = NSApplication.shared
app.setActivationPolicy(.regular)

struct SagaApp: App {
    @StateObject private var state = SagaViewerState()
    
    var body: some Scene {
        WindowGroup("SAGA (Swift AVIF Graphic Assistant)") {
            ContentView(state: state)
        }
    }
}

// アプリケーションループの開始
SagaApp.main()
