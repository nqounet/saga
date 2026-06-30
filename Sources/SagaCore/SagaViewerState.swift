import Foundation
import Combine

public class SagaViewerState: ObservableObject {
    @Published public var sourceImages: [URL] = []
    @Published public var pointer: Int = 0
    
    @Published public var displayCount: Int = 2
    @Published public var pageDirection: Direction = .rtl
    @Published public var isShifted: Bool = false
    
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
    
    public func scanFolder(at directoryURL: URL) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            self.sourceImages = []
            self.pointer = 0
            return
        }
        
        // 拡張子フィルタリング (supportedExtensions に含まれるか大文字小文字無視で判定)
        let filteredFiles = files.filter { url in
            let ext = url.pathExtension.lowercased()
            return supportedExtensions.contains(ext)
        }
        
        // 自然順（localizedStandardCompare）でソート
        let sortedFiles = filteredFiles.sorted { url1, url2 in
            let name1 = url1.lastPathComponent
            let name2 = url2.lastPathComponent
            return name1.localizedStandardCompare(name2) == .orderedAscending
        }
        
        self.sourceImages = sortedFiles
        self.pointer = 0
    }
}

public func calculateDisplayIndices(state: SagaViewerState) -> (left: Int?, right: Int?) {
    guard !state.sourceImages.isEmpty else { return (nil, nil) }
    
    // 1. 1枚表示モードの場合
    if state.displayCount == 1 {
        return state.pageDirection == .ltr ? (state.pointer, nil) : (nil, state.pointer)
    }
    
    // 2. 2枚表示 且つ 1枚ずらしON 且つ 先頭ページ（表紙）の場合
    if state.isShifted && state.pointer == 0 {
        return state.pageDirection == .ltr ? (0, nil) : (nil, 0)
    }
    
    // 3. 通常の2枚表示マッピング
    let first = state.pointer
    let second = (first + 1 <= state.maxIndex) ? (first + 1) : nil
    
    // ページ方向に応じて左右の割り当てを反転
    if state.pageDirection == .rtl {
        return (left: second, right: first) // 右開き：若いインデックスが右
    } else {
        return (left: first, right: second) // 左開き：若いインデックスが左
    }
}

public func getStepSize(state: SagaViewerState, isMovingForward: Bool) -> Int {
    if state.displayCount == 1 { return 1 }
    
    if state.isShifted {
        if isMovingForward && state.pointer == 0 { return 1 }
        if !isMovingForward && state.pointer == 1 { return 1 }
    }
    
    return state.displayCount // 通常は 2 ページずつ移動
}

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
