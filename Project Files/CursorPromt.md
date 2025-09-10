You’re editing **`Views/Components/WorkOrderCardView.swift`**.  
Make the following **surgical edits** (find → replace), preserving all other behavior, colors, and names.

### 1) Grid density + sizes
**Find (in `WorkOrderCardThumbnailGrid`):**
```swift
private let singleHeight: CGFloat = 140      // 1 item — full-width rect
private let doubleHeight: CGFloat = 100      // 2 items — stacked rects  
private let gridCell: CGFloat = 84           // 3–4 items — grid squares
private let spacing: CGFloat = 8
```
**Replace with:**
```swift
private let singleHeight: CGFloat = 140      // unchanged (square path uses SquareThumb)
private let doubleHeight: CGFloat = 112      // +12pt for better 2-up presence
private let gridCell: CGFloat = 82           // slightly denser collage
private let spacing: CGFloat = 6             // tighter gutters per Notes style
```

**Find (end of the VStack in `WorkOrderCardThumbnailGrid`):**
```swift
.padding(.horizontal, 16)
.padding(.top, 12)
```
**Replace with:**
```swift
.padding(.horizontal, 16)
.padding(.top, 8)     // tighter top margin
```

### 2) Thumb corner radius slightly smaller than card
For **`SquareThumb`**, **`FullWidthThumb`**, and **`GridThumb`**:

**Find:**
```swift
.cornerRadius(ThemeManager.shared.cardCornerRadius)
```
**Replace with:**
```swift
.cornerRadius(ThemeManager.shared.cardCornerRadius - 2)
```

### 3) Inline dots — baseline alignment + tighter spacing
In **`WorkOrderCardContent`** inside the **WO_Number** HStack:

**Find:**
```swift
HStack {
	Text(workOrder.workOrderNumber)
		.font(ThemeManager.shared.labelFont)
		.foregroundColor(ThemeManager.shared.textPrimary)
	
	// Inline dots (up to 4, one per WO_Item)
	HStack(spacing: 4) {
		ForEach(Array(StatusMapping.itemStatusesWithColor(for: workOrder).enumerated()), id: \.offset) { _, itemStatus in
			IndicatorDot(color: itemStatus.color, size: 6)
		}
	}
	
	Spacer()
	
	// Timestamp
	Text(timeAgoString)
		.font(.caption)
		.foregroundColor(ThemeManager.shared.textSecondary)
}
```

**Replace with:**
```swift
HStack(alignment: .firstTextBaseline, spacing: 8) {
	Text(workOrder.workOrderNumber)
		.font(ThemeManager.shared.labelFont)
		.foregroundColor(ThemeManager.shared.textPrimary)
	
	// Inline dots (baseline-aligned, tighter spacing)
	HStack(spacing: 3) {
		ForEach(Array(StatusMapping.itemStatusesWithColor(for: workOrder).enumerated()), id: \.offset) { _, itemStatus in
			IndicatorDot(color: itemStatus.color, size: 6)
		}
	}
	
	Spacer()
	
	// Timestamp
	Text(timeAgoString)
		.font(.caption)
		.foregroundColor(ThemeManager.shared.textSecondary)
}
```

### 4) Add Type × Qty summary line under phone
**A.** Add this helper inside **`WorkOrderCardContent`**:
```swift
private var itemSummaryLine: String {
	// First 3–4 items, "Type × Qty", joined with " • "
	let parts = workOrder.items.prefix(4).map { item in
		let t = item.type.isEmpty ? "Item" : item.type
		let q = 1  // schema currently lacks quantity; default to 1
		return "\(t) × \(q)"
	}
	return parts.joined(separator: " • ")
}
```

**B.** After the **phone button** in `WorkOrderCardContent`, insert this block:
```swift
// Type × Qty summary (muted, single line)
if !itemSummaryLine.isEmpty {
	Text(itemSummaryLine)
		.font(.caption2)
		.foregroundColor(ThemeManager.shared.textSecondary)
		.lineLimit(1)
		.truncationMode(.tail)
}
```

**C.** Optionally tighten body padding a touch:

**Find:**
```swift
.padding(.horizontal, 16)
.padding(.vertical, 12)
```
**Replace with:**
```swift
.padding(.horizontal, 16)
.padding(.vertical, 10)   // slightly denser body
```

### 5) Keep “first image” rule (confirm, no change required)
`firstImageURL(for:)` already returns **index 0** from `thumbUrls` then `imageUrls`. Leave as-is.

---

### Validation (quick manual)
- 1 item → one **square** image, rounded, dot inside TR, concise padding.
- 2 items → two **112pt** stacked rectangles; less white space.
- 3–4 items → tighter **2×2** (cell ≈ 82pt; spacing 6).
- Inline dots sit nicely on WO# baseline, spacing 3.
- Thumb corners appear **slightly** smaller than the card.
- A muted single-line **Type × Qty** summary appears below the phone.
- No colors or hex added; all tokens unchanged.

> If any selector text differs in your file, match the nearest surrounding lines and apply the same replacements in place.