# 📑 Layout Spec — ActiveWorkOrdersView & WorkOrderCardView

This merged spec consolidates the PRD, Workflow Narratives, Component Breakdown, and LayoutSpec template.  
It ensures **indicator dots are explicitly included** (overlay + inline), with no ambiguity.

---

## View / Component
- **Name:** ActiveWorkOrdersView (Grid)
- **File:** Views/Main/ActiveWorkOrdersView.swift
- **Related models:** WorkOrder (uses first images from WO_Items)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Display an Apple Notes–style grid of **active** WorkOrders with big, tappable cards.  
Cards show thumbnails, indicator dots, customer info, phone, timestamp, WO_Number, and flag.

## Wireframe (ASCII, not code)
```text
— Flagged (section header) —
┌──────────────────────────────────────────────┐
│ [Thumb Grid 2×2 max — 1:1 squares]           │
│  ●   ●                                       │ (overlay dots: top-right per image)
│                                              │
│ WO_Number    ● ● ● ●                time     │ (inline dots: 1 per WO_Item, up to 4)
│ [🔧] Customer Name                           │
│ (tap) Phone Number                           │
└──────────────────────────────────────────────┘
— All Active (section header) —
[ Card ] [ Card ] …
```

## Grid & Sizing Rules
- **iPad:** adaptive grid, min 260pt, ideal 300–340pt, spacing H=16pt / V=16pt.
- **iPhone:** 1 column, card max width = safe area width.
- **Thumbnails:** up to 4 (first image of up to 4 WO_Items). 1:1 crop, 2×2 layout.
- **Sort:** Flagged first (oldest→newest within flagged), then unflagged oldest→newest.

## Visual Style (Theme-driven)
- Card background: `cards.background`
- Radius: `cards.cornerRadius`
- Shadow: `cards.shadowOpacity`
- Text: `textPrimary` / `textSecondary`
- Tap highlights: `linkColor`
- **Indicator dots:**  
  - **Overlay** — one per thumbnail, top-right.  
  - **Inline** — summary row, max 4, aligned with WO_Number.  
  - Colors derive from central **StatusBadge** mapping; **no hex literals** [oai_citation:0‡HWOA_Cross-Doc_Acceptance_Checklist_09082025.md](file-service://file-P9JaZQdNnExbLBn3wM1KmX).
- **No StatusBadge** on cards; badges appear only in detail views [oai_citation:1‡HWOA_Cross-Doc_Acceptance_Checklist_09082025.md](file-service://file-P9JaZQdNnExbLBn3wM1KmX).

## Behaviors
- **Tap card →** WorkOrderDetailView
- **Tap phone →** call/text intent
- **Flagged:** shows small flag icon on card
- **Completed:** not shown here (Active only)

## Data Binding
- Source: WorkOrders where `!isCompleted && !isClosed && !isDeleted`
- Thumbnails: `items[*].imageUrls[0]` in item create order
- Fallback: `workOrders.imageURL` only if no items exist [oai_citation:2‡HWOA_Data_Schema_Map_09052025.md](file-service://file-32xhTEcARJMmUhGo8nnGqq)
- Overlay dots: 1 per rendered item image (status color)
- Inline dots: up to 4, one per WO_Item
- Emoji: if `customer.emojiTag` exists, show before Customer Name [oai_citation:3‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)

## Accessibility
- Card: `accessibilityLabel("<Customer>, Work Order <WO_Number>")`
- Dots are decorative only
- All hit targets ≥ 44×44pt

## Breakpoints
- **iPad landscape:** expect 3–4 columns
- **iPad portrait:** 2–3 columns
- **iPhone:** 1 column

## Acceptance Checklist
- [ ] Grid adapts by width, cards ≥ 260pt wide
- [ ] Card shows up to 4 thumbs, overlay dots, inline dots, WO_Number, Customer, Phone, Timestamp, Flag
- [ ] No StatusBadge on cards; dots only
- [ ] Flagged items sectioned at top, re-sort live on toggle [oai_citation:4‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)
- [ ] Uses theme tokens (no hardcoded hex)
- [ ] Dot colors follow StatusBadge semantic mapping [oai_citation:5‡HWOA_Cross-Doc_Acceptance_Checklist_09082025.md](file-service://file-P9JaZQdNnExbLBn3wM1KmX)
- [ ] Emoji renders if present; spacing collapses if not [oai_citation:6‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)

---

## View / Component
- **Name:** WorkOrderCardView
- **File:** Views/Components/WorkOrderCardView.swift
- **Related models:** WorkOrder, WO_Item
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Reusable card for ActiveWorkOrdersView. Shows thumbnails, indicator dots, customer, phone, WO_Number, timestamp, flag.

## Wireframe (ASCII, not code)
```text
┌──────────────────────────────────────────────┐
│ [Thumb Grid 2×2 max — 1:1 squares]           │
│  ●   ●                                       │ (overlay dots)
│                                              │
│ WO_Number    ● ● ● ●                time     │ (inline dots, up to 4)
│ [🔧] Customer Name                 [▲ Flag]  │
│ (tap) Phone Number                           │
└──────────────────────────────────────────────┘
```

## Grid & Sizing Rules
- Thumbs: 1–4, square, 6–8pt spacing
- Inline dots: same line as WO_Number
- Compact mode (<280pt width): collapse thumbs into single column, text stack on right [oai_citation:7‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)

## Visual Style (Theme-driven)
- Card: `cards.background`, `cards.cornerRadius`, `cards.shadowOpacity`
- Text: `textPrimary`, `textSecondary`
- Phone: `linkColor`
- Dots: reference StatusBadge colors [oai_citation:8‡HWOA_Cross-Doc_Acceptance_Checklist_09082025.md](file-service://file-P9JaZQdNnExbLBn3wM1KmX)

## Behaviors
- Tap card → WorkOrderDetailView
- Tap phone → call/text intent
- Flag icon if `isFlagged == true`

## Data Binding
- Customer name (with optional emoji)
- Thumbnails from WO_Items
- Inline & overlay dots from WO_Item statuses
- Timestamp from `workOrder.timestamp`

## Accessibility
- Card: “Work Order <WO_Number> for <Customer>”
- Dots are decorative

## Acceptance Checklist
- [ ] Up to 4 thumbnails render; fallback to workOrder.imageURL if none [oai_citation:9‡HWOA_Data_Schema_Map_09052025.md](file-service://file-32xhTEcARJMmUhGo8nnGqq)
- [ ] Overlay dots (per image) and inline dots (summary row) render
- [ ] Dot colors from StatusBadge mapping (no hex)
- [ ] Phone button triggers dialer/SMS
- [ ] Emoji bubble before name if present [oai_citation:10‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)
- [ ] Compact mode fallback works