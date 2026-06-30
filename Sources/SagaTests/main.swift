import Foundation
import SagaCore

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if actual != expected {
        print("❌ Test Failed: Expected \(expected), but got \(actual). \(message) at \(file):\(line)")
        exit(1)
    }
}

@MainActor
func testSagaViewerState_Initialization() {
    print("  - testSagaViewerState_Initialization")
    let state = SagaViewerState()
    assertEqual(state.sourceImages.count, 0, "sourceImages should be empty initially")
    assertEqual(state.pointer, 0, "pointer should be 0 initially")
    assertEqual(state.displayCount, 2, "displayCount should default to 2")
    assertEqual(state.pageDirection, SagaViewerState.Direction.rtl, "pageDirection should default to .rtl")
    assertEqual(state.isShifted, false, "isShifted should default to false")
}

@MainActor
func testSagaViewerState_FileScanningAndSorting() async {
    print("  - testSagaViewerState_FileScanningAndSorting")
    // テンポラリディレクトリを作成してダミーファイルを配置
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
    
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    let files = [
        "10.AVIF",
        "2.avif",
        "1.avif",
        "test.png",
        "03.avif",
        "ignore.txt"
    ]
    
    for file in files {
        let fileURL = tempDir.appendingPathComponent(file)
        try! "dummy content".write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    let state = SagaViewerState()
    await state.scanFolder(at: tempDir)
    
    // 期待される結果は自然順ソートされた .avif / .AVIF のファイル名
    let expectedNames = ["1.avif", "2.avif", "03.avif", "10.AVIF"]
    let actualNames = state.sourceImages.map { $0.lastPathComponent }
    
    assertEqual(actualNames, expectedNames, "Scanned files should be filtered and sorted naturally")
}

@MainActor
func testSagaViewerState_CalculateDisplayIndices() {
    print("  - testSagaViewerState_CalculateDisplayIndices")
    let state = SagaViewerState()
    
    // ヘルパー：ダミーURL配列をセット
    let urls = (0..<5).map { URL(fileURLWithPath: "/path/\($0).avif") }
    
    // 1. 画像なしケース
    state.sourceImages = []
    let (left1, right1) = calculateDisplayIndices(state: state)
    assertEqual(left1, nil, "Empty sourceImages should yield nil left index")
    assertEqual(right1, nil, "Empty sourceImages should yield nil right index")
    
    state.sourceImages = urls
    
    // 2. 1枚表示モード
    state.displayCount = 1
    state.pointer = 2
    state.pageDirection = .ltr
    let (left2, right2) = calculateDisplayIndices(state: state)
    assertEqual(left2, 2, "LTR 1-page display should place image on the left")
    assertEqual(right2, nil, "LTR 1-page display should place nil on the right")
    
    state.pageDirection = .rtl
    let (left3, right3) = calculateDisplayIndices(state: state)
    assertEqual(left3, nil, "RTL 1-page display should place nil on the left")
    assertEqual(right3, 2, "RTL 1-page display should place image on the right")
    
    // 3. 2枚表示 且つ 1枚ずらしON 且つ 先頭ページ（表紙）
    state.displayCount = 2
    state.isShifted = true
    state.pointer = 0
    state.pageDirection = .ltr
    let (left4, right4) = calculateDisplayIndices(state: state)
    assertEqual(left4, 0, "Shifted cover LTR should place image on the left")
    assertEqual(right4, nil, "Shifted cover LTR should place nil on the right")
    
    state.pageDirection = .rtl
    let (left5, right5) = calculateDisplayIndices(state: state)
    assertEqual(left5, nil, "Shifted cover RTL should place nil on the left")
    assertEqual(right5, 0, "Shifted cover RTL should place image on the right")
    
    // 4. 通常の2枚表示
    state.isShifted = false
    state.pointer = 0
    state.pageDirection = .ltr
    let (left6, right6) = calculateDisplayIndices(state: state)
    assertEqual(left6, 0, "Normal LTR 2-page should place pointer on the left")
    assertEqual(right6, 1, "Normal LTR 2-page should place pointer+1 on the right")
    
    state.pageDirection = .rtl
    let (left7, right7) = calculateDisplayIndices(state: state)
    assertEqual(left7, 1, "Normal RTL 2-page should place pointer+1 on the left")
    assertEqual(right7, 0, "Normal RTL 2-page should place pointer on the right")
    
    // 5. 境界条件（最後のページで画像が足りない場合、奇数枚）
    // urls のインデックスは 0..4 (計5枚)。pointer = 4 のとき
    state.pointer = 4
    state.pageDirection = .ltr
    let (left8, right8) = calculateDisplayIndices(state: state)
    assertEqual(left8, 4, "Odd-ended LTR should place last image on the left")
    assertEqual(right8, nil, "Odd-ended LTR should place nil on the right")
    
    state.pageDirection = .rtl
    let (left9, right9) = calculateDisplayIndices(state: state)
    assertEqual(left9, nil, "Odd-ended RTL should place nil on the left")
    assertEqual(right9, 4, "Odd-ended RTL should place last image on the right")
}

@MainActor
func testSagaViewerState_PageTransition() {
    print("  - testSagaViewerState_PageTransition")
    let state = SagaViewerState()
    let urls = (0..<5).map { URL(fileURLWithPath: "/path/\($0).avif") }
    state.sourceImages = urls
    
    // 1. 1枚表示モード
    state.displayCount = 1
    state.pointer = 0
    assertEqual(getStepSize(state: state, isMovingForward: true), 1, "Single-page view forward step should be 1")
    movePage(state: state, forward: true)
    assertEqual(state.pointer, 1, "Moving forward in single-page view should increment pointer by 1")
    
    movePage(state: state, forward: false)
    assertEqual(state.pointer, 0, "Moving backward in single-page view should decrement pointer by 1")
    
    // 境界値チェック (0未満にならない)
    movePage(state: state, forward: false)
    assertEqual(state.pointer, 0, "Moving backward at 0 should stay at 0")
    
    // 2. 2枚表示 且つ 1枚ずらしON
    state.displayCount = 2
    state.isShifted = true
    
    // 表紙（0）から進む時は step=1
    state.pointer = 0
    assertEqual(getStepSize(state: state, isMovingForward: true), 1, "Step forward from cover (0) with shift should be 1")
    movePage(state: state, forward: true)
    assertEqual(state.pointer, 1, "Pointer should go to 1 from 0 with shift")
    
    // 1 から戻る時は step=1
    assertEqual(getStepSize(state: state, isMovingForward: false), 1, "Step backward from 1 with shift should be 1")
    movePage(state: state, forward: false)
    assertEqual(state.pointer, 0, "Pointer should return to 0 from 1 with shift")
    
    // 通常ページ（1）から進む時は step=2
    state.pointer = 1
    assertEqual(getStepSize(state: state, isMovingForward: true), 2, "Step forward from 1 with shift should be 2")
    movePage(state: state, forward: true)
    assertEqual(state.pointer, 3, "Pointer should go to 3 from 1 with shift")
    
    // 3から戻る時は step=2
    assertEqual(getStepSize(state: state, isMovingForward: false), 2, "Step backward from 3 with shift should be 2")
    movePage(state: state, forward: false)
    assertEqual(state.pointer, 1, "Pointer should return to 1 from 3 with shift")
    
    // 3. 境界値チェック (maxIndexを超えない)
    // maxIndex = 4 (urls.count = 5)
    // pointer = 3 から forward すると、step=2 で 5 になるため進めないはず。
    state.pointer = 3
    movePage(state: state, forward: true)
    assertEqual(state.pointer, 3, "Should not advance past maxIndex boundary")
    
    // pointer = 4 (奇数枚の最後)
    state.pointer = 4
    movePage(state: state, forward: true)
    assertEqual(state.pointer, 4, "Should not advance past maxIndex boundary at last element")
}

import AppKit

func createDummyPNGImage(at url: URL) {
    let width = 100
    let height = 100
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else { return }
    context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImage = context.makeImage() else { return }
    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    guard let tiffData = nsImage.tiffRepresentation else { return }
    guard let imageRep = NSBitmapImageRep(data: tiffData) else { return }
    guard let pngData = imageRep.representation(using: .png, properties: [:]) else { return }
    try! pngData.write(to: url)
}

func testSagaImageLoader() {
    print("  - testSagaImageLoader")
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    let imageURL = tempDir.appendingPathComponent("test.png")
    createDummyPNGImage(at: imageURL)
    
    let loader = SagaImageLoader.shared
    
    // 非同期読み込みの検証
    let expectation = DispatchSemaphore(value: 0)
    var loadedImage: NSImage? = nil
    
    Task {
        loadedImage = try? await loader.loadImage(at: imageURL)
        expectation.signal()
    }
    
    _ = expectation.wait(timeout: .now() + 2.0)
    
    assertEqual(loadedImage != nil, true, "Should load image asynchronously")
    if let image = loadedImage {
        assertEqual(image.size.width, 100.0, "Loaded image width should be 100")
        assertEqual(image.size.height, 100.0, "Loaded image height should be 100")
    }
    
    // キャッシュの検証
    let isCached = loader.isCached(url: imageURL)
    assertEqual(isCached, true, "Loaded image should be cached")
}

// トップレベルでのテスト実行 (async化)
Task { @MainActor in
    print("🏃 Running SagaTests...")
    testSagaViewerState_Initialization()
    await testSagaViewerState_FileScanningAndSorting()
    testSagaViewerState_CalculateDisplayIndices()
    testSagaViewerState_PageTransition()
    testSagaImageLoader()
    print("✅ All tests passed!")
    exit(0)
}

// 実行ループを維持して非同期タスクの完了を待つ
RunLoop.main.run()

