# InstaGridswift - Agent Handoff Document

## Project Overview
InstaGridswift is an iOS SwiftUI app for planning Instagram grid layouts. Users can create plans, add photos, reorder them via drag-and-drop, crop images for different aspect ratios, and preview how their feed will look.

---

## Work Completed

### Phase 1: Drag Reorder Fix (Stability)

**Problem**: Array mutations during `.onChanged` caused choppy animations and SwiftUI rebuilds mid-gesture.

**Solution**: Deferred array mutations to `.onEnded`

**Files Modified**:
- `InstaGridswift/Views/PlanEditorView.swift`
  - Added `@State private var dragSourceIndex: Int?`
  - Added `@State private var dragOffset: CGSize`
  - Added `@State private var dragStartLocation: CGPoint`
  - Modified `handleDrag()` to only update `dragTargetIndex` (no array mutation)
  - Modified `handleDragEnd()` to call `moveImage()` with animation
  - Added `draggedItemOverlay()` function to render dragged item in overlay (always on top)

- `InstaGridswift/Views/Components/DraggableGridItem.swift`
  - Added `isDropTarget: Bool` parameter for visual feedback
  - Changed `onDragStarted` callback to pass `CGPoint` for start location

### Phase 2: Image Caching (Performance)

**Problem**: No image caching - AsyncImage loaded full-resolution images from disk on every render.

**Solution**: Created NSCache-based caching with thumbnail generation.

**Files Created**:
- `InstaGridswift/Services/ImageCache.swift`
  - Singleton `ImageCache.shared`
  - Separate caches for thumbnails (200 items, 50MB) and full images (20 items, 100MB)
  - `generateThumbnail(from:maxDimension:)` - creates 400px thumbnails

- `InstaGridswift/Views/Components/CachedAsyncImage.swift`
  - Checks cache before loading from disk
  - Generates thumbnails on first load
  - Shows placeholder/progress during load

**Files Modified**:
- `InstaGridswift/Views/Components/DraggableGridItem.swift` - Uses `CachedAsyncImage`
- `InstaGridswift/Views/Components/ThumbnailGrid.swift` - Uses `CachedAsyncImage`

### Phase 3: Gesture Handling Fix (ScrollView Compatibility)

**Problem**: Standard SwiftUI gesture modifiers (`LongPressGesture`, `DragGesture`) block ScrollView scrolling.

**Solution**: ButtonStyle-based gesture detection that doesn't interfere with scroll.

**Research Sources**:
- [Daniel Saidi: Complex Gestures in ScrollView](https://danielsaidi.com/blog/2022/11/16/using-complex-gestures-in-a-scroll-view)
- [Hacking with Swift: Delaying Gestures in ScrollView](https://www.hackingwithswift.com/forums/swiftui/a-guide-to-delaying-gestures-in-scrollview/6005)

**Key Insight**: Button styles don't interfere with ScrollView scrolling because `configuration.isPressed` state changes don't block gesture recognition.

**Files Created**:
- `InstaGridswift/Views/Components/ScrollViewGestureButton.swift`
  - `ScrollViewGestureButtonStyle` - detects press via `configuration.isPressed`
  - `ScrollViewGestureButton` - wrapper combining:
    - ButtonStyle for press detection
    - Timer-based long press (0.5s delay)
    - `DragGesture` as `simultaneousGesture` with 20px minimum distance

**Files Modified**:
- `InstaGridswift/Views/Components/DraggableGridItem.swift` - Complete rewrite to use `ScrollViewGestureButton`

### Phase 4: UI Polish

**Files Modified**:
- `InstaGridswift/Views/Components/ImageActionOverlay.swift`
  - Reduced button sizes from 56px to 40px circles
  - Reduced icon font from 24 to 16
  - Reduced spacing

---

## Current Architecture

### Gesture Flow (Normal Mode)
```
User touches image
    ↓
ScrollViewGestureButton detects press via ButtonStyle
    ↓
Timer starts (0.5s for long press)
    ↓
If user scrolls → ScrollView handles it (no interference)
If user holds 0.5s → onLongPress → Show overlay
If user drags 20px+ → onDragStart → Begin reorder
```

### Drag Reorder Flow
```
onDragStart (in DraggableGridItem)
    ↓
PlanEditorView.onDragStarted callback
    - Sets draggedImageID
    - Sets dragSourceIndex
    - Sets dragStartLocation
    ↓
onDragChange (continuous)
    - Updates dragOffset
    - Calls handleDrag() → updates dragTargetIndex only
    ↓
Dragged item rendered in overlay (draggedItemOverlay)
    - Position: dragStartLocation + dragOffset
    - Always on top (separate ZStack layer)
    ↓
onDragEnd
    - Calls handleDragEnd()
    - moveImage() called with animation
    - Resets all drag state
```

---

## Current Interaction Model

| Action | Result |
|--------|--------|
| Scroll (vertical) | ScrollView scrolls normally |
| Long press (0.5s) without moving | Show Hide/Crop overlay |
| Long press + drag (20px+) | Start reorder |
| Tap in edit mode | Select/deselect image |

---

## Known Issues & Improvement Plans

### 1. Overlay Dismissal (HIGH PRIORITY)

**Current Behavior**: When the Hide/Crop overlay is shown, tapping outside the buttons does nothing - it blocks all interactions.

**Expected Behavior**: Tapping anywhere outside the overlay buttons should dismiss the overlay and return to normal state.

**Suggested Fix**:
In `ImageActionOverlay.swift`, the semi-transparent background already has an `onTapGesture` that calls `onDismiss()`:
```swift
Rectangle()
    .fill(Color.black.opacity(0.6))
    .onTapGesture {
        HapticService.impact(.light)
        onDismiss()
    }
```

However, in `DraggableGridItem.swift`, when `isShowingOverlay` is true, the content is rendered without gesture handling:
```swift
} else if isShowingOverlay {
    // Overlay showing - no gestures needed
    normalContent  // ← No tap gesture to dismiss
}
```

**Fix Options**:
1. Add a tap gesture to dismiss when overlay is showing
2. Make the overlay cover the entire grid (not just one cell) so tapping anywhere dismisses
3. Add a "tap to dismiss" area around the overlay content

### 2. Drag & Reorganize Improvements (MEDIUM PRIORITY)

**Current Issues**:
- Drag feedback could be smoother
- Drop target indicator is subtle (just a border)
- No "lift" animation when picking up an item
- Items don't visually shift to show where the drop will occur

**Improvement Ideas**:

#### A. Better Visual Feedback
```swift
// When dragging starts, scale up the dragged item more
.scaleEffect(isDragging ? 1.1 : 1.0)

// Add rotation for "picked up" feel
.rotationEffect(isDragging ? .degrees(2) : .zero)

// Stronger shadow
.shadow(color: .black.opacity(isDragging ? 0.5 : 0), radius: 15, y: 8)
```

#### B. Animate Other Items
When dragging, other items could shift to show where the drop will occur:
```swift
// In LazyVGrid, items could animate their position
.offset(y: shouldShiftDown ? itemHeight : 0)
.animation(.spring(response: 0.3), value: dragTargetIndex)
```

#### C. Drop Zone Preview
Show a "ghost" placeholder where the item will drop:
```swift
// Insert a placeholder view at dragTargetIndex
if index == dragTargetIndex {
    Rectangle()
        .fill(Color.gray.opacity(0.3))
        .frame(width: itemSize.width, height: itemSize.height)
}
```

#### D. Haptic Feedback Enhancement
- Light haptic when crossing into a new drop zone
- Success haptic on drop
- Currently only has haptic on drag start

#### E. Consider iOS Native Drag & Drop
SwiftUI's `onDrag` and `onDrop` modifiers provide native drag-and-drop with system animations:
```swift
.onDrag {
    NSItemProvider(object: image.id.uuidString as NSString)
}
.onDrop(of: [.text], delegate: DropDelegate())
```

This would give native lift animations and drop feedback, but requires more complex `DropDelegate` implementation.

### 3. Performance Optimizations (LOW PRIORITY)

- Generate thumbnails on image import (not on first display)
- Persist thumbnails to disk to survive app restart
- Consider using `LazyVGrid` with `id` modifier for better diffing

### 4. Gesture Timing Adjustments (LOW PRIORITY)

Current values that could be tuned:
- Long press duration: 0.5s (in `ScrollViewGestureButton`)
- Drag minimum distance: 20px (in `ScrollViewGestureButton`)

If long press feels too slow, reduce to 0.4s.
If accidental drags happen, increase minimum distance to 25-30px.

---

## File Structure

```
InstaGridswift/
├── Models/
│   ├── Plan.swift
│   ├── PlanImage.swift
│   ├── AspectRatio.swift
│   └── CropSettings.swift
├── Views/
│   ├── PlansListView.swift
│   ├── PlanEditorView.swift          ← Main grid editor
│   ├── Components/
│   │   ├── DraggableGridItem.swift   ← Grid cell with gestures
│   │   ├── ScrollViewGestureButton.swift  ← NEW: Scroll-compatible gestures
│   │   ├── CachedAsyncImage.swift    ← NEW: Cached image loading
│   │   ├── ImageActionOverlay.swift  ← Hide/Crop overlay
│   │   ├── ThumbnailGrid.swift
│   │   └── ...
│   └── Sheets/
│       ├── ImageCropEditorView.swift
│       ├── HiddenImagesSheet.swift
│       └── ImagePickerView.swift
├── Services/
│   ├── ImageStorageService.swift
│   ├── ImageCache.swift              ← NEW: NSCache-based caching
│   └── HapticService.swift
└── Utilities/
    └── Extensions/
        └── Color+Theme.swift
```

---

## Testing Checklist

- [ ] Scroll grid with 10+ images - should scroll smoothly
- [ ] Long press (0.5s) on image - should show Hide/Crop overlay
- [ ] Tap outside overlay - should dismiss (NEEDS FIX)
- [ ] Long press + drag - should start reorder
- [ ] Dragged image should always be on top
- [ ] Drop on target - should animate reorder
- [ ] Edit mode - tap to select/deselect
- [ ] Memory usage - should stay bounded with many images
