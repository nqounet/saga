import Foundation
import Combine

@MainActor
public class SagaViewerState: ObservableObject {
    @Published public var sourceImages: [URL] = [] {
        didSet {
            validatePointer()
        }
    }
    @Published public var pointer: Int = 0 {
        didSet {
            validatePointer()
        }
    }
    
    @Published public var displayCount: Int = 2 {
        didSet {
            validatePointer()
        }
    }
    @Published public var pageDirection: Direction = .rtl
    @Published public var showsCoverPage: Bool = false {
        didSet {
            validatePointer()
        }
    }
    @Published public var showStatusBar: Bool = true
    @Published public var showControlPanel: Bool = true
    
    public enum Direction {
        case rtl
        case ltr
    }
    
    public var maxIndex: Int {
        return max(0, sourceImages.count - 1)
    }
    
    // サポートする拡張子リスト（将来の拡張のために定義）
    public var supportedExtensions: Set<String> = ["avif"]
    
    public init() {}
    
    public func scanFolder(at directoryURL: URL) async {
        let supported = self.supportedExtensions // ローカルにコピーしてバックグラウンドへ安全にキャプチャ
        
        let sortedFiles = await Task.detached(priority: .userInitiated) { () -> [URL] in
            let fileManager = FileManager.default
            guard let files = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
                return []
            }
            
            // 拡張子フィルタリング
            let filteredFiles = files.filter { url in
                let ext = url.pathExtension.lowercased()
                return supported.contains(ext)
            }
            
            // 自然順でソート
            return filteredFiles.sorted { url1, url2 in
                let name1 = url1.lastPathComponent
                let name2 = url2.lastPathComponent
                return name1.localizedStandardCompare(name2) == .orderedAscending
            }
        }.value
        
        self.sourceImages = sortedFiles
        self.pointer = 0
    }
    
    private func validatePointer() {
        guard !sourceImages.isEmpty else {
            if pointer != 0 { pointer = 0 }
            return
        }
        
        var target = pointer
        // 範囲制限
        if target < 0 {
            target = 0
        } else if target > maxIndex {
            target = maxIndex
        }
        
        // 2枚表示モードの場合の偶奇調整
        if displayCount == 2 {
            if showsCoverPage {
                if target > 0 && target % 2 == 0 {
                    // 0より大きい偶数の場合は奇数にする
                    if target + 1 <= maxIndex {
                        target += 1
                    } else {
                        target -= 1
                    }
                }
            } else {
                // 偽のときは偶数にする
                if target % 2 == 1 {
                    target -= 1
                }
            }
        }
        
        if pointer != target {
            pointer = target
        }
    }
}

@MainActor
public func calculateDisplayIndices(state: SagaViewerState) -> (left: Int?, right: Int?) {
    guard !state.sourceImages.isEmpty else { return (nil, nil) }
    
    // 1. 1枚表示モードの場合
    if state.displayCount == 1 {
        return state.pageDirection == .ltr ? (state.pointer, nil) : (nil, state.pointer)
    }
    
    // 2. 2枚表示マッピング
    // 表紙を表示する設定かつ最初のページの場合、1枚表示にする
    if state.showsCoverPage && state.pointer == 0 {
        return state.pageDirection == .ltr ? (state.pointer, nil) : (nil, state.pointer)
    }
    
    let first = state.pointer
    let second = (first + 1 <= state.maxIndex) ? (first + 1) : nil
    
    // ページ方向に応じて左右の割り当てを反転
    if state.pageDirection == .rtl {
        return (left: second, right: first) // 右開き：若いインデックスが右
    } else {
        return (left: first, right: second) // 左開き：若いインデックスが左
    }
}

@MainActor
public func getStepSize(state: SagaViewerState, isMovingForward: Bool) -> Int {
    if state.displayCount == 1 { return 1 }
    
    if state.showsCoverPage {
        if isMovingForward {
            if state.pointer == 0 {
                return 1
            }
        } else {
            if state.pointer == 1 {
                return 1
            }
        }
    }
    
    return state.displayCount // 通常は 2 ページずつ移動
}

@MainActor
public func movePage(state: SagaViewerState, forward: Bool) {
    let step = getStepSize(state: state, isMovingForward: forward)
    
    if forward {
        let nextPointer = state.pointer + step
        if nextPointer <= state.maxIndex { state.pointer = nextPointer }
    } else {
        let prevPointer = state.pointer - step
        if prevPointer >= 0 { state.pointer = prevPointer }
    }
}
