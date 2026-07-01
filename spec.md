# Application Development Specification: SAGA

## 1. Application Overview

* **Application Name:** SAGA (Swift AVIF Graphic Assistant)
* **Goal:** A lightweight desktop application that leverages native macOS 13 Ventura and later system APIs (ImageIO / SwiftUI) to browse AVIF image files in local folders, utilizing a layout (spread and RTL page flow) optimized for reading comics.

## 2. Confidence and Uncertainties

* **Confidence: Extremely High**
  - Since it strictly complies with native macOS system APIs, no external image decoding libraries are required. This keeps the application size to a few megabytes while achieving peak rendering performance.
  - The requested page flow logic (reversed key navigation for RTL) and cover-page display logic can be cleanly implemented using SwiftUI's declarative data binding and simple array offset calculations.

* **Uncertainties:**
  - If a user selects a folder containing thousands of images, retrieving the file list on the main thread may temporarily freeze the UI. To prevent this, the folder scanning process is designed to run asynchronously on a background thread.

---

## 3. Functional Requirements

### 3.1 Folder Selection and File Indexing

1. **Target Directory:** Watch any local folder path selected by the user.
2. **Format Constraint:** Extract only files with the `.avif` extension (case-insensitive).
3. **Natural Sorting:** Sort the extracted filenames using `localizedStandardCompare(_:)` in natural order (e.g., `2.avif` comes before `10.avif`) to build an immutable array `sourceList`.

### 3.2 Layout & View Settings

1. **Layout (`displayCount`):** Dynamically switch between "Single Page" and "Two Pages" (spread).
2. **Page Flow (`pageDirection`):**
   - `Right to Left (RTL)`: Japanese manga style. In Two Pages mode, the lower-indexed image is placed on the "right" side.
   - `Left to Right (LTR)`: Western book style. In Two Pages mode, the lower-indexed image is placed on the "left" side.
3. **Show Cover Page (`showsCoverPage`):**
   - `Enabled (True)`: Treats the first item (index 0) in the array as the "cover" and displays it alone. Spreads subsequent pages in pairs of two.
   - `Disabled (False)`: Forces all pages, including the first page, to display in spreads of two.

### 3.3 Keyboard Navigation (Arrow Keys)

Reverses the navigation direction of the keys dynamically based on the page flow setting (RTL/LTR).

| Reading Direction | Press Key | Pointer Adjustment | Visual Effect |
| --- | --- | --- | --- |
| **Right to Left (RTL)** | `Left Arrow (←)` | Increase pointer (`+step`) | **Advance to next page (left)** |
|  | `Right Arrow (→)` | Decrease pointer (`-step`) | Return to previous page (right) |
| **Left to Right (LTR)** | `Right Arrow (→)` | Increase pointer (`+step`) | **Advance to next page (right)** |
|  | `Left Arrow (←)` | Decrease pointer (`-step`) | Return to previous page (left) |

---

## 4. UI & Layout Design

The overall window layout and relationship between UI components:

```mermaid
graph TD
    subgraph "SAGA Application Window"
        A["\"Control Panel (Top)\""] --> B["\"Folder Selection [Path]\""]
        A --> C["\"Layout [Single / Two Pages]\""]
        A --> D["\"Direction [RTL / LTR]\""]
        A --> E["\"Show Cover ON/OFF\""]
        
        F["\"Main Stage (Center Image Area)\""] --> G["\"Left View\""]
        F --> H["\"Right View\""]
        
        I["\"Status Bar (Bottom)\""] --> J["\"Current Index / Total Files\""]
    end
```

---

## 5. Data Structures and State Management

Definition of the reactive state management object for the SwiftUI implementation:

```swift
class SagaViewerState: ObservableObject {
    @Published var sourceImages: [URL] = []      // Sorted array of AVIF file URLs
    @Published var pointer: Int = 0               // Current base display index
    
    // Configurable Settings
    @Published var displayCount: Int = 2          // 1 or 2
    @Published var pageDirection: Direction = .rtl // .rtl or .ltr
    @Published var showsCoverPage: Bool = false    // Cover page flag
    
    enum Direction {
        case rtl, ltr
    }
    
    var maxIndex: Int { sourceImages.count - 1 }
}
```

---

## 6. Core Algorithms

### 6.1 Image Mapping Logic

Determines which image index should be shown on the left/right screen based on the current `pointer`.

```swift
func calculateDisplayIndices(state: SagaViewerState) -> (left: Int?, right: Int?) {
    guard !state.sourceImages.isEmpty else { return (nil, nil) }
    
    // 1. Single Page Mode
    if state.displayCount == 1 {
        return state.pageDirection == .ltr ? (state.pointer, nil) : (nil, state.pointer)
    }
    
    // 2. Two Pages Mode with Cover Page ON at the Start
    if state.showsCoverPage && state.pointer == 0 {
        return state.pageDirection == .ltr ? (0, nil) : (nil, 0)
    }
    
    // 3. Standard Two Pages Mapping
    let first = state.pointer
    let second = (first + 1 <= state.maxIndex) ? (first + 1) : nil
    
    // Flip left/right allocation based on page flow direction
    if state.pageDirection == .rtl {
        return (left: second, right: first) // RTL: lower index on the right
    } else {
        return (left: first, right: second) // LTR: lower index on the left
    }
}
```

### 6.2 Navigation (Step Size) Calculation Logic

When cover page support is enabled, step size changes to `1` when transitioning to or from the cover page (index 0).

```swift
func getStepSize(state: SagaViewerState, isMovingForward: Bool) -> Int {
    if state.displayCount == 1 { return 1 }
    
    if state.showsCoverPage {
        if isMovingForward && state.pointer == 0 { return 1 }
        if !isMovingForward && state.pointer == 1 { return 1 }
    }
    
    return state.displayCount // Normally advances by 2 pages
}

// Visual navigation handler
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

## 7. Implementation Details (SwiftUI Code Sketch)

The implementation details for handling keyboard events and organizing the dual image display layouts:

```swift
struct ContentView: View {
    @StateObject var state = SagaViewerState()

    var body: some View {
        VStack {
            // Control panel UI goes here
            
            // Main image stage
            HStack(spacing: 0) {
                let indices = calculateDisplayIndices(state: state)
                
                // Left view
                if let leftIdx = indices.left {
                    Image(nsImage: NSImage(contentsOf: state.sourceImages[leftIdx])!)
                        .resizable()
                        .scaledToFit()
                } else {
                    Spacer() // Empty margin
                }
                
                // Right view
                if let rightIdx = indices.right {
                    Image(nsImage: NSImage(contentsOf: state.sourceImages[rightIdx])!)
                        .resizable()
                        .scaledToFit()
                } else {
                    Spacer() // Empty margin
                }
            }
            .background(Color.black) // Dark background for optimal reading
        }
        // Monitor keyboard shortcuts
        .background(NSViewKeyMonitor(state: state)) 
    }
}
```
