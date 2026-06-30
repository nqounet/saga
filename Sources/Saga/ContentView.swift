import SwiftUI
import SagaCore

public struct ContentView: View {
    @ObservedObject var state: SagaViewerState
    @State private var keyMonitor: Any? = nil
    
    public init(state: SagaViewerState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. コントロールパネル（上部）
            controlPanel
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 2. メインステージ（画像表示エリア）
            mainStage
                .frame(maxHeight: .infinity)
            
            Divider()
            
            // 3. ステータスバー（下部）
            statusBar
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            setupKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }
    
    // MARK: - Subviews
    
    private var controlPanel: some View {
        HStack(spacing: 16) {
            Button(action: selectFolder) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("フォルダ選択...")
                }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
            
            // 表示枚数
            Picker("表示枚数", selection: $state.displayCount) {
                Text("1枚表示").tag(1)
                Text("2枚表示").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
            
            // ページ方向
            Picker("綴じ方向", selection: $state.pageDirection) {
                Text("右開き (RTL)").tag(SagaViewerState.Direction.rtl)
                Text("左開き (LTR)").tag(SagaViewerState.Direction.ltr)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            // 1枚ずらし
            Toggle("1枚ずらす（表紙）", isOn: $state.isShifted)
                .disabled(state.displayCount == 1)
            
            Button(action: reloadFolder) {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(state.sourceImages.isEmpty)
            .help("フォルダを再スキャン")
        }
    }
    
    private var mainStage: some View {
        let indices = calculateDisplayIndices(state: state)
        
        return HStack(spacing: 0) {
            // 左ビュー
            if let leftIdx = indices.left, leftIdx < state.sourceImages.count {
                AsyncImageView(url: state.sourceImages[leftIdx])
            } else {
                Color.black
                    .overlay(Text(state.sourceImages.isEmpty ? "" : "余白").foregroundColor(.gray.opacity(0.3)))
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // 右ビュー
            if let rightIdx = indices.right, rightIdx < state.sourceImages.count {
                AsyncImageView(url: state.sourceImages[rightIdx])
            } else {
                Color.black
                    .overlay(Text(state.sourceImages.isEmpty ? "" : "余白").foregroundColor(.gray.opacity(0.3)))
            }
        }
        .background(Color.black)
    }
    
    private var statusBar: some View {
        HStack {
            if state.sourceImages.isEmpty {
                Text("フォルダが選択されていません。")
                    .foregroundColor(.secondary)
            } else {
                let indices = calculateDisplayIndices(state: state)
                let leftText = indices.left.map { state.sourceImages[$0].lastPathComponent } ?? "-"
                let rightText = indices.right.map { state.sourceImages[$0].lastPathComponent } ?? "-"
                
                HStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                    Text("表示中: [ 左: \(leftText) ]  [ 右: \(rightText) ]")
                        .font(.system(.body, design: .monospaced))
                }
                
                Spacer()
                
                Text("\(state.pointer + 1) / \(state.sourceImages.count) ファイル")
                    .font(.headline)
            }
        }
    }
    
    // MARK: - Actions
    
    private func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.title = "SAGA - 画像フォルダ選択"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                DispatchQueue.main.async {
                    SagaImageLoader.shared.clearCache()
                    self.state.scanFolder(at: url)
                }
            }
        }
    }
    
    private func reloadFolder() {
        guard let firstURL = state.sourceImages.first else { return }
        let parentFolder = firstURL.deletingLastPathComponent()
        SagaImageLoader.shared.clearCache()
        state.scanFolder(at: parentFolder)
    }
    
    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 123: // 左矢印キー
                handleKeyEvent(isLeftKey: true)
                return nil
            case 124: // 右矢印キー
                handleKeyEvent(isLeftKey: false)
                return nil
            default:
                return event
            }
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    private func handleKeyEvent(isLeftKey: Bool) {
        guard !state.sourceImages.isEmpty else { return }
        
        let forward: Bool
        if state.pageDirection == .rtl {
            forward = isLeftKey // 右開き：左キーで進む
        } else {
            forward = !isLeftKey // 左開き：右キーで進む
        }
        
        movePage(state: state, forward: forward)
    }
}

// MARK: - AsyncImageView

struct AsyncImageView: View {
    let url: URL?
    @State private var image: NSImage? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            Color.black
            
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity.animation(.easeOut(duration: 0.15)))
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                        .font(.title)
                    Text(error)
                        .foregroundColor(.white)
                        .font(.caption)
                }
            } else {
                Text("画像なし")
                    .foregroundColor(.gray)
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = url else {
            image = nil
            isLoading = false
            errorMessage = nil
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let loaded = try await SagaImageLoader.shared.loadImage(at: url)
            self.image = loaded
        } catch {
            self.errorMessage = "画像の読み込みに失敗しました"
            self.image = nil
        }
        isLoading = false
    }
}
