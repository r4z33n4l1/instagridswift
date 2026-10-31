# InstaGridswift - System Analysis & Improvement Plan

## App Overview

**InstaGridswift** is an iOS app for planning Instagram grid layouts. Users can:
- Create multiple "plans" to organize photos for their Instagram feed
- Preview how photos will appear in the grid before posting
- Adjust aspect ratios to match Instagram's various formats
- Reorder photos via drag-and-drop
- Hide/unhide photos temporarily
- Crop and zoom individual photos per aspect ratio

### Supported Aspect Ratios
| Format | Ratio | Dimensions |
|--------|-------|------------|
| Profile Photo | 1:1 | 320×320 |
| Profile Grid | 3:4 | 1012×1350 |
| Feed Portrait | 4:5 | 1080×1350 |
| Reels & Stories | 9:16 | 1080×1920 |
| Feed Landscape | 1.91:1 | 1080×566 |

---

## Current Architecture

### Data Models
- **Plan** - Container for a grid plan (name, aspect ratio, images)
- **PlanImage** - Individual image (file path, dimensions, order, hidden state, crop settings)
- **CropSettings** - Per-aspect-ratio crop/zoom data (offsetX, offsetY, scale)
- **AspectRatio** - Enum defining Instagram formats

### Key Views
- **PlansListView** - List of all plans
- **PlanEditorView** - Main grid editor with drag/drop
- **DraggableGridItem** - Individual grid cell with gestures
- **ImageActionOverlay** - Tap overlay with hide/crop buttons
- **ImageCropEditorView** - Full-screen crop editor
- **HiddenImagesSheet** - Bottom sheet for hidden images

### Services
- **ImageStorageService** - Local file storage for images
- **HapticService** - Haptic feedback

---

## Known Issues & Inefficiencies

### 1. CRITICAL: Crash in Crop/Gesture Handling

**Symptom:** App crashes with `EXC_BREAKPOINT (SIGTRAP)` during gesture interactions

**Crash Location:** Thread 0, during `FullGestureCallbacks.dispatch` in SwiftUI gesture system

**Stack Trace Analysis:**
```
InstaGridswift (gesture callback)
↓
SwiftUICore ChangedCallbacks.dispatch
↓
SwiftUICore withTransaction
↓
SwiftUICore FullGestureCallbacks.dispatch
```

**Likely Causes:**
- Force unwrap of nil optional in gesture callback
- Array index out of bounds when calculating drag position
- Division by zero in offset calculations when `frameSize` is zero
- State mutation during gesture update causing SwiftUI assertion

**Files to investigate:**
- `DraggableGridItem.swift` - drag gesture handlers
- `ImageCropEditorView.swift` - pan/zoom gesture handlers
- `PlanEditorView.swift` - `handleDrag()` function

---

### 2. Tap Gesture Unreliable

**Symptom:** Tapping images to show action overlay (hide/crop buttons) is inconsistent

**Root Cause:** Gesture conflict between:
- Tap gesture (show overlay)
- Long press gesture (initiate drag)
- Drag gesture (reorder)

**Current Implementation Issues:**
```swift
// DraggableGridItem.swift
.gesture(editMode || isShowingOverlay ? nil : dragGesture)
```
- Disabling gestures conditionally can cause SwiftUI gesture state issues
- Long press duration (0.25s) may interfere with tap recognition

**Improvement Needed:**
- Use `.simultaneousGesture()` properly
- Consider using `GestureState` more carefully
- May need to restructure gesture priority

---

### 3. Image Stuck in Extended View

**Symptom:** After cropping, image appears "extended" or improperly scaled in grid

**Root Cause:** Mismatch between how crop settings are saved vs applied

**Current Flow:**
1. **Editor saves:** Normalizes offset as `currentOffset / maxOffset` (range -1 to 1)
2. **Grid applies:** `CropAppliedModifier` calculates offset from normalized value

**Issue:** The `maxOffset` calculation depends on:
- Frame size (different in editor vs grid cell)
- Image dimensions
- Current scale

If any parameter differs between save and display, the offset will be wrong.

**Recent Fix Applied:** Updated `CropAppliedModifier` to calculate proper offsets based on image dimensions, but may need further testing.

---

### 4. Poor Scroll Performance

**Symptom:** Scrolling through grid feels janky/stuttery

**Potential Causes:**
1. **AsyncImage without caching:** Each scroll triggers new image loads
2. **Heavy view body:** `DraggableGridItem` has complex gesture setup
3. **Animations during scroll:** `.animation()` modifiers may trigger during scroll
4. **No image downsampling:** Full-resolution images loaded for thumbnails

**Improvement Needed:**
- Implement proper image caching (NSCache or third-party)
- Downsample images for grid display
- Use `drawingGroup()` for complex views
- Profile with Instruments to identify bottlenecks

---

### 5. Drag Reorder Animation Not Smooth

**Symptom:** When dragging to reorder, animation is choppy/not fluid

**Current Implementation:**
```swift
// PlanEditorView.swift
private func handleDrag(_ image: PlanImage, translation: CGSize, itemSize: CGSize) {
    // Calculates new index based on translation
    // Calls moveImage() which mutates order property
}
```

**Issues:**
1. Direct model mutation triggers full view rebuild
2. `LazyVGrid` recomputes layout on each order change
3. Multiple `HapticService.selection()` calls during single drag

**Improvement Needed:**
- Use `@State` for drag preview position separate from model
- Only commit reorder on drag end
- Debounce haptic feedback
- Consider custom drag preview instead of in-place animation

---

### 6. Crop Editor Pan Constraints

**Symptom:** Cannot pan to show edges of tall/wide images in certain aspect ratios

**Example:** 9:16 image in 4:5 frame - cannot scroll to see footer of image

**Root Cause:** `maxOffset` calculation may not account for all edge cases

**Current Logic:**
```swift
private func maxOffset(for frameSize: CGSize, scale: CGFloat) -> CGSize {
    let displayedSize = displayedImageSize(for: frameSize)
    let scaledWidth = displayedSize.width * scale
    let scaledHeight = displayedSize.height * scale
    let extraWidth = max(0, (scaledWidth - frameSize.width) / 2)
    let extraHeight = max(0, (scaledHeight - frameSize.height) / 2)
    return CGSize(width: extraWidth, height: extraHeight)
}
```

**Potential Issues:**
- `displayedImageSize` calculation may be incorrect for extreme aspect ratios
- `frameSize` timing issue (may be `.zero` when loaded)

---

### 7. Memory Concerns

**Potential Issues:**
- Full-resolution images kept in memory
- No image cache eviction policy
- Multiple `AsyncImage` instances for same file

---

## Recommended Improvements

### Priority 1: Fix Crashes
1. Add nil checks and guards in all gesture callbacks
2. Ensure `frameSize` is valid before calculations
3. Add bounds checking for array access in drag handling
4. Wrap critical sections in `withAnimation` properly

### Priority 2: Improve Gestures
1. Restructure gesture handling to avoid conflicts
2. Use exclusive gesture groups where appropriate
3. Increase tap target size for overlay buttons
4. Add visual feedback for gesture recognition

### Priority 3: Performance
1. Implement image caching layer
2. Generate thumbnails at appropriate sizes
3. Profile with Instruments
4. Reduce view complexity in `DraggableGridItem`

### Priority 4: UX Polish
1. Smooth drag reorder animation
2. Better crop editor feedback
3. Loading states for images
4. Error handling and recovery

---

## Files Requiring Changes

| File | Priority | Issue |
|------|----------|-------|
| `DraggableGridItem.swift` | P1 | Gesture crashes, tap reliability |
| `ImageCropEditorView.swift` | P1 | Crash in pan gesture, constraint issues |
| `PlanEditorView.swift` | P2 | Drag animation, performance |
| `CropAppliedModifier` | P2 | Offset calculation mismatch |
| New: `ImageCache.swift` | P3 | Performance improvement |

---

## Testing Checklist

- [ ] Tap image → overlay appears reliably
- [ ] Tap Hide → image hides, grid reorders
- [ ] Tap Crop → editor opens without crash
- [ ] Pan in crop editor → full range of motion
- [ ] Save crop → displays correctly in grid
- [ ] Change aspect ratio → crop is independent
- [ ] Drag reorder → smooth animation
- [ ] Scroll grid → no jank
- [ ] Restart app → all settings persist
- [ ] Memory usage stays reasonable with many images
