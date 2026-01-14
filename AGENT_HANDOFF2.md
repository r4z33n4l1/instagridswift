# Agent Handoff: iOS Photos-Style Grid Drag & Drop

## Current Status

**Working:**
- Scroll works with native `.onDrag()` / `.onDrop()`
- Gap animation works in `AnimatedReorderableGrid`
- Context menu removed (was conflicting with drag)
- Drop sometimes completes successfully

**Broken:**
- Drag is unreliable - starts multiple times, often doesn't complete
- No floating drag preview (native system handles it, but poorly)
- The smooth, responsive feel from custom gestures is lost

## Core Files

| File | Purpose |
|------|---------|
| `Views/PlanEditorView.swift` | Main grid view, drop handling via `GridDropDelegate` |
| `Views/Components/PhotoGridCell.swift` | Individual cell with `.onDrag()` |
| `Views/Components/AnimatedReorderableGrid.swift` | Custom grid with gap animation |

## The Fundamental Problem

**SwiftUI gesture conflicts:**
1. `ScrollView` uses pan gesture for scrolling
2. Our drag needs to capture touches for reordering
3. These compete - only one can win

**Two approaches tried, both have issues:**

### Approach A: Custom Gestures (Smooth Drag, No Scroll)
```swift
LongPressGesture(minimumDuration: 0.3)
    .sequenced(before: DragGesture())
    .updating($dragState) { ... }
```
- ✅ Drag is smooth and responsive
- ✅ Cell visually lifts and follows finger
- ✅ Gap animation works perfectly
- ❌ Completely blocks ScrollView

### Approach B: Native Drag/Drop (Scroll Works, Drag Broken)
```swift
.onDrag { NSItemProvider(object: id as NSString) }
.onDrop(of: [UTType.plainText], delegate: DropDelegate)
```
- ✅ Scroll works (iOS handles gesture disambiguation)
- ❌ Drag restarts multiple times during gesture
- ❌ `performDrop` often not called
- ❌ No custom drag preview control

## What We Tried

| Attempt | Result |
|---------|--------|
| `.gesture()` with custom LongPress+Drag | Blocks scroll completely |
| `.simultaneousGesture()` | Still blocks scroll |
| `.highPriorityGesture()` | Still blocks scroll |
| Native `.onDrag()` + `.onDrop()` | Scroll works, drag unreliable |
| `.contextMenu` + `.onDrag()` together | Context menu prevents drop completion |
| Background `Color.clear` as drop target | Slight improvement, still unreliable |
| `isAnyDragging` flag to prevent restarts | Didn't prevent the issue |

## Why Native Drag/Drop is Unreliable

From logs:
```
🚀 DRAG started: index=0
🚀 DRAG started: index=0      // Restarts!
🚀 DRAG started: index=1      // Different cell triggered!
🎯 DROP: ...                   // Sometimes works
```

The issue: When using `.onDrag()`, iOS creates a drag session. But:
1. The drag preview appearance triggers our `onDragStarted` callback
2. Moving over other cells can trigger THEIR `.onDrag()`
3. The drop delegate's `performDrop` is often not called - the session just ends

## The Smooth Approach That Worked (But Blocked Scroll)

In `PhotoGridCell`, this gave smooth dragging:
```swift
@GestureState private var dragState = DragState.inactive

enum DragState {
    case inactive
    case pressing
    case dragging(translation: CGSize)
}

var longPressDrag: some Gesture {
    LongPressGesture(minimumDuration: 0.3)
        .sequenced(before: DragGesture(minimumDistance: 0))
        .updating($dragState) { value, state, _ in
            switch value {
            case .first(true):
                state = .pressing
            case .second(true, let drag):
                state = .dragging(translation: drag?.translation ?? .zero)
            default:
                state = .inactive
            }
        }
}

// Then apply offset directly to the cell:
.offset(currentTranslation)
.scaleEffect(isCurrentlyDragging ? 1.05 : 1.0)
.shadow(...)
.zIndex(isCurrentlyDragging ? 100 : 0)
```

This was smooth because:
- Direct `@GestureState` updates are immediate
- No intermediate state management
- Cell physically moves with finger
- Gap animation responds to `proposedDropIndex`

## Potential Solutions to Explore

### 1. UIKit Integration
Use `UIViewRepresentable` with proper `UIGestureRecognizerDelegate`:
- `UIPanGestureRecognizer` for drag with `shouldRecognizeSimultaneouslyWith`
- Can configure gesture priorities properly
- More control over when gestures activate

### 2. Delayed Gesture Recognition
Custom gesture that:
- Lets initial touch through to ScrollView
- Only activates after 0.3s of minimal movement
- Uses timer-based activation instead of `LongPressGesture`

### 3. Scroll View Wrapper
Create custom scrolling with `DragGesture`:
- Don't use SwiftUI's `ScrollView`
- Implement scroll with `offset()`
- Full control over gesture handling

### 4. Different UX Pattern
- Don't use long-press-to-drag
- Use explicit "Edit Mode" with drag handles
- Or tap-to-select, then drag selected items

## Current Code State

**PhotoGridCell** - Using native `.onDrag()`:
```swift
.onDrag {
    if !isAnyDragging {
        HapticService.impact(.medium)
        onDragStarted()
    }
    return NSItemProvider(object: image.id.uuidString as NSString)
}
```

**PlanEditorView** - Using `.onDrop()` with delegate:
```swift
.background(
    GeometryReader { geo in
        Color.clear
            .contentShape(Rectangle())
            .onDrop(of: [UTType.plainText], delegate: GridDropDelegate(...))
    }
)
```

**GridDropDelegate** - Handles drop:
```swift
func performDrop(info: DropInfo) -> Bool {
    guard let sourceIndex = draggedSourceIndex,
          let targetIndex = proposedDropIndex else {
        resetState()
        return false
    }
    onDrop(sourceIndex, targetIndex)
    return true
}
```

## Key Insight

The iOS Photos app likely uses UIKit with custom gesture recognizers that have proper priority configuration. SwiftUI's gesture system doesn't provide the fine-grained control needed for this interaction pattern.

The best path forward is probably:
1. **UIKit wrapper** for the drag gesture recognition
2. Keep SwiftUI for the view rendering
3. Use `UIGestureRecognizerDelegate` methods to allow scroll to work alongside drag

Or accept a UX compromise:
- Use an explicit "Reorder Mode" button
- In reorder mode, disable scroll and enable drag
- Exit reorder mode to scroll again
