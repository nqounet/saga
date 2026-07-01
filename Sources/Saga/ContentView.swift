import SwiftUI
import SagaCore
import UniformTypeIdentifiers

public struct ContentView: View {
    @ObservedObject var state: SagaViewerState
    @State private var keyMonitor: Any? = nil
    
    public init(state: SagaViewerState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. コントロールパネル（上部）
            if state.showControlPanel {
                controlPanel
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
            }
            
            // 2. メインステージ（画像表示エリア）
            mainStage
                .frame(maxHeight: .infinity)
            
            if state.showStatusBar {
                Divider()
                
                // 3. ステータスバー（下部）
                statusBar
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor))
            }
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
                    Text("Select Folder...")
                }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
            
            // Layout (Single / Two Pages)
            Picker("Layout", selection: $state.displayCount) {
                Text("Single Page").tag(1)
                Text("Two Pages").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
            
            Divider()
                .frame(height: 20)
            
            // Reading Direction (RTL / LTR)
            Picker("Reading Direction", selection: $state.pageDirection) {
                Text("Right to Left (RTL)").tag(SagaViewerState.Direction.rtl)
                Text("Left to Right (LTR)").tag(SagaViewerState.Direction.ltr)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
            
            Divider()
                .frame(height: 20)
            
            // Show Cover Page
            Toggle("Show Cover Page", isOn: $state.showsCoverPage)
                .disabled(state.displayCount == 1)
            
            Divider()
                .frame(height: 20)
            
            Button(action: reloadFolder) {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(state.sourceImages.isEmpty)
            .help("Rescan folder")
        }
    }
    
    private var mainStage: some View {
        let indices = calculateDisplayIndices(state: state)
        
        return Group {
            if let leftIdx = indices.left, let rightIdx = indices.right,
               leftIdx < state.sourceImages.count, rightIdx < state.sourceImages.count {
                // 2枚表示（見開き）
                HStack(spacing: 0) {
                    AsyncImageView(url: state.sourceImages[leftIdx], alignment: .trailing)
                    AsyncImageView(url: state.sourceImages[rightIdx], alignment: .leading)
                }
            } else if let singleIdx = indices.left ?? indices.right, singleIdx < state.sourceImages.count {
                // 1枚表示（中央表示）
                AsyncImageView(url: state.sourceImages[singleIdx], alignment: .center)
            } else {
                // Empty margin or blank
                Color.black
                    .overlay(Text(state.sourceImages.isEmpty ? "" : "Margin").foregroundColor(.gray.opacity(0.3)))
            }
        }
        .background(Color.black)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                guard let url = url, url.isFileURL else { return }
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    Task {
                        await self.openFolder(at: url)
                    }
                }
            }
            return true
        }
    }
    
    private var statusBar: some View {
        HStack {
            if state.sourceImages.isEmpty {
                Text("No folder selected.")
                    .foregroundColor(.secondary)
            } else {
                let indices = calculateDisplayIndices(state: state)
                let leftText = indices.left.map { state.sourceImages[$0].lastPathComponent } ?? "-"
                let rightText = indices.right.map { state.sourceImages[$0].lastPathComponent } ?? "-"
                
                HStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                    Text("Showing: [ Left: \(leftText) ]  [ Right: \(rightText) ]")
                        .font(.system(.body, design: .monospaced))
                }
                
                Spacer()
                
                Text("\(state.pointer + 1) / \(state.sourceImages.count) files")
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
        openPanel.title = "SAGA - Select Image Folder"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                Task {
                    await self.openFolder(at: url)
                }
            }
        }
    }
    
    private func reloadFolder() {
        guard let firstURL = state.sourceImages.first else { return }
        let parentFolder = firstURL.deletingLastPathComponent()
        Task {
            await openFolder(at: parentFolder)
        }
    }
    
    private func openFolder(at url: URL) async {
        SagaImageLoader.shared.clearCache()
        await state.scanFolder(at: url)
    }
    
    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // フォーカスがテキストエリアや入力フィールドにある場合は、キー入力を横取りせずそのまま流す
            if let window = NSApp.keyWindow,
               let firstResponder = window.firstResponder {
                let className = String(describing: type(of: firstResponder))
                if className.contains("TextView") || className.contains("TextField") {
                    return event
                }
            }
            
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
    var alignment: Alignment = .center
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
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
                Text("No Image")
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
            self.errorMessage = "Failed to load image"
            self.image = nil
        }
        isLoading = false
    }
}
