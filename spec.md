# アプリケーション開発仕様書：SAGA

## 1. アプリケーション概要

* **アプリケーション名:** SAGA (Swift AVIF Graphic Assistant)
* **目的:** macOS 13 Ventura以降のネイティブ機能（ImageIO / SwiftUI）を最大限に活用し、ローカルフォルダ内のAVIF形式の画像ファイルを、コミック閲覧に最適化されたレイアウト（見開き・右開き対応）で高速にブラウジングする軽量デスクトップアプリケーション。

## 2. 確信度と不確実な要素

* **確信度：極めて高**
* macOSのシステムAPIに完全に準拠するため、外部の画像デコードライブラリが不要であり、アプリ自体のファイルサイズを数MB程度に抑えつつ、最高峰の描画パフォーマンスを発揮できます。
* 要求されている「右開き時のカーソル逆転ロジック」や「1枚ずらし」は、SwiftUIの宣言的データバインディングとシンプルな配列演算のみで美しく実装可能です。


* **不確実な要素：**
* ユーザーが選択したフォルダ内に、数千枚におよぶ大量の画像が存在する場合、メインスレッドでファイル一覧を取得すると一時的にUIがフリーズする恐れがあります。これに対応するため、ファイルスキャン処理はBackground（非同期）スレッドで行う設計としています。



---

## 3. 機能要件

### 3.1 フォルダ選択とファイルインデックス化

1. **ターゲット指定:** ユーザーが選択した任意のローカルフォルダ（パス）を監視。
2. **フォーマット限定:** 拡張子が `.avif`（大文字・小文字を区別しない）のファイルのみを抽出。
3. **自然順ソート:** 抽出したファイル名を `localizedStandardCompare(_:)` を用いて自然順（例: `2.avif` が `10.avif` より前に来る）でソートし、不変の配列 `sourceList` を構築する。

### 3.2 画面表示・レイアウト制御（オプション機能）

1. **表示枚数（`displayCount`）:** 「1枚表示」または「2枚表示（見開き）」を動的に切り替え可能。
2. **並べる（進む）方向（`pageDirection`）:** * `右開き (RTL)`: 日本の漫画スタイル。2枚表示時、インデックスが若い画像が「右側」に配置される。
* `左開き (LTR)`: 洋書スタイル。2枚表示時、インデックスが若い画像が「左側」に配置される。


3. **1枚ずらし（`isShifted`）:** * `有効 (True)`: 配列の最初（インデックス0）を「表紙」とみなし、1枚だけで表示。次のページから2枚並べる。
* `無効 (False)`: 最初のページから強制的に2枚並べる。



### 3.3 キーボードナビゲーション（カーソルキー）

進む方向の設定（RTL/LTR）に応じて、ページ遷移のキー挙動を動的に反転させる。

| ページ方向 | 押下キー | 内部ポインタの挙動 | ユーザーから見た効果 |
| --- | --- | --- | --- |
| **右開き (RTL)** | `左矢印キー (←)` | ポインタを増加させる (`+step`) | **左に進む（次ページへ）** |
|  | `右矢印キー (→)` | ポインタを減少させる (`-step`) | 右に戻る（前ページへ） |
| **左開き (LTR)** | `右矢印キー (→)` | ポインタを増加させる (`+step`) | **右に進む（次ページへ）** |
|  | `左矢印キー (←)` | ポインタを減少させる (`-step`) | 左に戻る（前ページへ） |

---

## 4. UI・画面構造設計

アプリ全体の画面構成とコンポーネントの関係性です。

```mermaid
graph TD
    subgraph "SAGA アプリケーションウィンドウ"
        A["\"コントロールパネル（上部）\""] --> B["\"フォルダ選択 [Path]\""]
        A --> C["\"表示枚数 [1枚 / 2枚]\""]
        A --> D["\"進む方向 [右開き(左進) / 左開き(右進)]\""]
        A --> E["\"見開き調整 [1枚ずらす ON/OFF]\""]
        
        F["\"メインステージ（中央画像表示エリア）\""] --> G["\"左ビュー（Left View）\""]
        F --> H["\"右ビュー（Right View）\""]
        
        I["\"ステータスバー（下部）\""] --> J["\"現在のポインタ / 総ページ数\""]
    end

```

---

## 5. データ構造と状態管理

SwiftUIでの実装を想定した、リアクティブな状態管理オブジェクトの定義。

```swift
class SagaViewerState: ObservableObject {
    @Published var sourceImages: [URL] = []      // ソート済みのAVIFファイルURL配列
    @Published var pointer: Int = 0               // 現在の表示基準インデックス
    
    // オプション設定
    @Published var displayCount: Int = 2          // 1 または 2
    @Published var pageDirection: Direction = .rtl // .rtl (右開き) または .ltr (左開き)
    @Published var isShifted: Bool = false         // 1枚ずらしフラグ
    
    enum Direction {
        case rtl, ltr
    }
    
    var maxIndex: Int { sourceImages.count - 1 }
}

```

---

## 6. コアアルゴリズム

### 6.1 画像マッピング・ロジック

現在の `pointer` を元に、左右の画面に描画すべき画像のインデックスを決定する。

```swift
func calculateDisplayIndices(state: SagaViewerState) -> (left: Int?, right: Int?) {
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

```

### 6.2 ページ遷移（ステップ数）計算ロジック

「1枚ずらし」が有効な場合、表紙（ポインタ0）から進む時と、表紙に戻る時だけステップ数が `1` になる例外処理を挟む。

```swift
func getStepSize(state: SagaViewerState, isMovingForward: Bool) -> Int {
    if state.displayCount == 1 { return 1 }
    
    if state.isShifted {
        if isMovingForward && state.pointer == 0 { return 1 }
        if !isMovingForward && state.pointer == 1 { return 1 }
    }
    
    return state.displayCount // 通常は 2 ページずつ移動
}

// ユーザーのアクション処理
func movePage(state: SagaViewerState, forward: Bool) {
    let step = getStepSize(state: state, isMovingForward: forward)
    
    if forward {
        let nextPointer = state.pointer + step
        if nextPointer <= state.maxIndex { state.pointer = nextPointer }
    } else {
        let prevPointer = state.pointer - step
        if prevPointer >= 0 { state.pointer = prevPointer }
    }
}

```

---

## 7. テクノロジー実装のヒント（SwiftUIコードスケッチ）

キーボードのイベント処理と、AVIF画像を左右に並べるビューのレイアウトは以下のように非常にシンプルに記述できます。

```swift
struct ContentView: View {
    @StateObject var state = SagaViewerState()

    var body: some View {
        VStack {
            // コントロールパネルのUIをここに配置
            
            // メイン画像ステージ
            HStack(spacing: 0) {
                let indices = calculateDisplayIndices(state: state)
                
                // 左側エリア
                if let leftIdx = indices.left {
                    Image(nsImage: NSImage(contentsOf: state.sourceImages[leftIdx])!)
                        .resizable()
                        .scaledToFit()
                } else {
                    Spacer() // 空白表示
                }
                
                // 右側エリア
                if let rightIdx = indices.right {
                    Image(nsImage: NSImage(contentsOf: state.sourceImages[rightIdx])!)
                        .resizable()
                        .scaledToFit()
                } else {
                    Spacer() // 空白表示
                }
            }
            .background(Color.black) // 漫画が見やすいよう背景は黒
        }
        // キーボードショートカットの監視
        .background(NSViewKeyMonitor(state: state)) 
    }
}

```
