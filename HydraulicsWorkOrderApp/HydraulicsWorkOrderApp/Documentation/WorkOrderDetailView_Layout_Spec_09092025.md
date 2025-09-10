# 📑 Layout Spec — WorkOrderDetailView

This spec is reformatted to match the merged ActiveWorkOrdersView/WorkOrderCardView spec style.  
It captures **WorkOrderDetailView** layout, behaviors, bindings, and acceptance rules.  
Key principle: **StatusBadge only in detail; indicator dots only on cards** [oai_citation:0‡HWOA_Cross-Doc_Acceptance_Checklist_09082025.md](file-service://file-P9JaZQdNnExbLBn3wM1KmX) [oai_citation:1‡HWOA_Component_Breakdown_09052025.md](file-service://file-4BMNS7KwQARr54Yb7ULxyq).

---

## View / Component
- **Name:** WorkOrderDetailView
- **File:** Views/Main/WorkOrderDetailView.swift
- **Related models:** WorkOrder, WO_Item, WO_Status, WO_Note
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json) [oai_citation:2‡AppleNotesYellow.json](file-service://file-L6G4fsxLcq6FuS1hWMAmtk)

## Purpose
Show a single WorkOrder with:
- Header (Customer, WO_Number, Timestamp, Flag, Actions)
- List of WO_Items (each with StatusBadge, never dots)
- Merged Notes & Status timeline [oai_citation:3‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)

---

## Wireframe (ASCII, not code)
```text
[ Back ]  [🔧] <Customer Name>       [ Flag toggle ]   [ … ]
WO_Number • Timestamp

— Items —
[ 44–56pt thumb ]  <Type • brief>       [StatusBadge]   [ > ]
[ 44–56pt thumb ]  <Type • brief>       [StatusBadge]   [ > ]
…

— Notes & Status Timeline —
— Today —
09:30  ✓ Completed                     • Joe
09:26  Parts: seals; Hours:1.0         • Joe
09:25  ✓ Tested: PASS                  • Joe
09:14  💬 Note: Seals replaced         • Joe
…
```

---

## Grid & Sizing Rules
- **Layout axis:** vertical
- **Header block:**
  - Line 1: Back button, emoji+Customer Name, Flag toggle, overflow actions
  - Line 2: WO_Number • Timestamp (`textSecondary`)
- **Items section:**
  - Row min height: 56pt
  - Leading thumbnail: 44–56pt, 1:1 square if available
  - Middle: type/brief descriptor
  - Trailing: **StatusBadge** (semantic colors)
- **Timeline:** full-width list, grouped with day headers (“Today”, “Yesterday”, `MMM d`)
- **Spacing:** 12–16pt vertical section spacing; default iOS paddings inside rows

---

## Visual Style (Theme-driven)
- Background: `background`
- Header/labels: `textPrimary`
- Metadata (WO_Number, Timestamp): `textSecondary`
- Flag & overflow buttons: `linkColor`
- Row separators: `border`
- **StatusBadge**: source of truth for semantic colors [oai_citation:4‡HWOA_LayoutSpec_Template_09042025.md](file-service://file-REaYr2HQThr7MDMe2WXvWS)

---

## Behaviors
- **Tap Item Row →** `WorkOrderItemDetailView` [oai_citation:5‡HWOA_Component_Breakdown_09052025.md](file-service://file-4BMNS7KwQARr54Yb7ULxyq)
- **Flag toggle:** updates `workOrder.isFlagged`
- **Overflow menu:**  
  - Mark Completed → set `isCompleted` + timestamp, emit WO_Status, move to Completed list [oai_citation:6‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)  
  - Mark Closed → set `isClosed` + timestamp, emit WO_Status, hide from Active (Manager/Admin only) [oai_citation:7‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)  
- **NotesTimelineView:** merges `/workOrderNotes`, `/itemNotes`, `statusHistory` [oai_citation:8‡HWOA_Data_Schema_Map_09052025.md](file-service://file-32xhTEcARJMmUhGo8nnGqq)
- **No indicator dots** here; dots belong to cards only [oai_citation:9‡HWOA_Cross-Doc_Acceptance_Checklist_09082025.md](file-service://file-P9JaZQdNnExbLBn3wM1KmX)

---

## Data Binding
- **Header:** `workOrder.customer.name`, `customer.emojiTag`, `WO_Number`, `timestamp`, `isFlagged`
- **Items:**  
  - Thumbnail: `item.imageUrls[0]`  
  - Subtitle: `type` (optionally color/brand snippet)  
  - StatusBadge: from `statusHistory` or denormalized `status` [oai_citation:10‡HWOA_Serialization_09052025.md](file-service://file-Y8YRLZFfhTbH1Z1k3TTnNz)
- **Timeline:**  
  - WorkOrder-level notes: `/workOrders/{woId}/workOrderNotes`  
  - Item-level notes: `/items/{itemId}/itemNotes`  
  - Status history: `items[].statusHistory`  
  - Sorted & merged, grouped by day

---

## Accessibility
- **Header VO:** “Work Order <WO_Number> for <Customer>, created <timestamp>”
- **Item row VO:** “Item <n>, <type>, status <status>”
- **Actions:** labeled (“Mark Completed”, “Mark Closed”, “Toggle flag”)
- Minimum tap target: 44×44pt
- Badges include text; never rely on color alone

---

## States
- **Loading:** skeleton rows (items + timeline)
- **Empty items (should not happen):** “No items to display” (admins only repair path)
- **Empty timeline:** “No notes yet” in `textSecondary`
- **Error:** inline error + Retry

---

## Acceptance Checklist
- [ ] Header shows emoji (if set), flag toggle, overflow actions; WO_Number + Timestamp line [oai_citation:11‡HWOA_LayoutSpec_Template_09042025.md](file-service://file-REaYr2HQThr7MDMe2WXvWS)  
- [ ] Items list renders all WO_Items with StatusBadge; trailing chevron navigates to item detail [oai_citation:12‡HWOA_Component_Breakdown_09052025.md](file-service://file-4BMNS7KwQARr54Yb7ULxyq)  
- [ ] Timeline merges notes + statuses with day headers and authorship [oai_citation:13‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)  
- [ ] No indicator dots appear anywhere in this view (cards only) [oai_citation:14‡HWOA_Cross-Doc_Acceptance_Checklist_09082025.md](file-service://file-P9JaZQdNnExbLBn3wM1KmX)  
- [ ] Completed/Closed actions update roll-ups + emit WO_Status, update list membership [oai_citation:15‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)  
- [ ] Theme tokens only; no hardcoded hex [oai_citation:16‡AppleNotesYellow.json](file-service://file-L6G4fsxLcq6FuS1hWMAmtk)  
- [ ] All actions/buttons ≥ 44×44pt and VO-labeled [oai_citation:17‡HWOA_LayoutSpec_Template_09042025.md](file-service://file-REaYr2HQThr7MDMe2WXvWS)

---