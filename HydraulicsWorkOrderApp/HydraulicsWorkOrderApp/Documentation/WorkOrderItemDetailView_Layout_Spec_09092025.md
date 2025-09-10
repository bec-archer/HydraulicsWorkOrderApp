# 📑 Layout Spec — WorkOrderItemDetailView

Single-item operations: status updates, test PASS/FAIL, parts/hours/cost, photos, and tag management.  
Key principle: **Detail uses StatusBadge**; **indicator dots never appear here** (dots are card-only) [oai_citation:0‡HWOA_Cross-Doc_Acceptance_Checklist_09082025.md](file-service://file-P9JaZQdNnExbLBn3wM1KmX) [oai_citation:1‡HWOA_Component_Breakdown_09052025.md](file-service://file-4BMNS7KwQARr54Yb7ULxyq).

---

## View / Component
- **Name:** WorkOrderItemDetailView
- **File:** Views/Main/WorkOrderItemDetailView.swift
- **Related models:** WO_Item, WO_Status, TagBinding, TagHistory
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json) [oai_citation:2‡AppleNotesYellow.json](file-service://file-L6G4fsxLcq6FuS1hWMAmtk)

## Purpose
Operate on a **single WO_Item**: view/edit photos, update status (In Progress / Done / Tested PASS/FAIL), enter parts/hours/cost, and manage multiple QR tags (Primary/Aux, Position Label) [oai_citation:3‡HWOA_Component_Breakdown_09052025.md](file-service://file-4BMNS7KwQARr54Yb7ULxyq) [oai_citation:4‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC).

---

## Wireframe (ASCII, not code)
```text
[ Back ]  <Type>   •   Tags: <PrimaryShortID> (+N)     [ Flag toggle ]
[ Primary Image (1:1, large) ]
[ Thumbnail Grid (2-column 1:1 squares) ]

— Status —
[ In Progress ]   [ Done ]     [ Test: PASS ]   [ Test: FAIL ]

— Details —
Parts Used
[ multiline text … ]
Hours Worked               Cost
[ 1.25 ]  hrs              [ 125.00 ]  USD

— Actions —
[ Save ]        [ Mark Work Order Completed ]   (role-gated behavior)

— QR Codes —
[TAG-A123  • Primary • Rod End]   [ … ]  → (Set Primary | Edit Label | Unbind)
[+ Add QR]  (scanner; reassign flow if already active elsewhere)
```

---

## Grid & Sizing Rules
- **Primary axis:** vertical
- **Primary image:** full-width square (1:1), rounded; max content width ~600–700pt on iPad
- **Thumb grid:** 2 columns of 1:1 squares, spacing 8pt; grid width equals primary image width [oai_citation:5‡HWOA_LayoutSpec_Template_09042025.md](file-service://file-REaYr2HQThr7MDMe2WXvWS)
- **Status row:** segmented/buttons in two rows on compact if needed; single row on wide
- **Form fields:** two-up for Hours/Cost on wide; stacked on compact
- **Section spacing:** 12–16pt between groups

---

## Visual Style (Theme-driven)
- Background: `background`; text: `textPrimary` / `textSecondary`
- Buttons: `buttonBackground` / `buttonText`
- Dividers & subtle borders: `border`
- **StatusBadge** styles derive from the central semantic mapping; **no hardcoded hex** [oai_citation:6‡HWOA_LayoutSpec_Template_09042025.md](file-service://file-REaYr2HQThr7MDMe2WXvWS)

---

## Behaviors
- **Photos**
  - Tap any thumb → Fullscreen viewer overlay (pinch-zoom, dim scrim); zIndex above content [oai_citation:7‡HWOA_LayoutSpec_Template_09042025.md](file-service://file-REaYr2HQThr7MDMe2WXvWS)
  - “Set as Primary” moves image URL to index 0
- **Status**
  - **In Progress / Done** write WO_Status entries with user+timestamp
  - **Test: PASS** opens a small sheet requiring **Parts / Hours / Cost** before saving (“Save PASS” disabled until valid) [oai_citation:8‡HWOA_LayoutSpec_Template_09042025.md](file-service://file-REaYr2HQThr7MDMe2WXvWS)
  - **Test: FAIL** shows confirm alert; on confirm, writes status; 2nd FAIL flags **PROBLEM CHILD** and surfaces to Manager flows [oai_citation:9‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)
- **Mark Work Order Completed** (button)
  - Requires PASS preconditions (parts/hours/cost) as applicable; sets roll-up on WorkOrder via parent flow [oai_citation:10‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)
- **QR Codes (multi-binding)**
  - Chips show short tag, Primary badge (if set), and optional Position Label
  - Per-chip menu: **Set Primary • Edit Label • Unbind**
  - **+ Add QR** opens scanner: if scanned tag is active on another item → **Tag Reassignment** approval path (deactivate old, create new binding, append `tagHistory(event:"reassigned")`) [oai_citation:11‡HWOA_Component_Breakdown_09052025.md](file-service://file-4BMNS7KwQARr54Yb7ULxyq) [oai_citation:12‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)
  - Position Labels may use preset list or free text (admin-managed presets) [oai_citation:13‡WO_Item_Dropdown_Checkbox_Template_09052025.md](file-service://file-BnAiYba5tCGrm1XwZjw7Vq)

---

## Data Binding
- **Images:** `woItem.imageUrls: [String]` (Storage URLs) [oai_citation:14‡HWOA_Serialization_09052025.md](file-service://file-Y8YRLZFfhTbH1Z1k3TTnNz)
- **Status state:** `woItem.statusHistory: [WO_Status]` and optional denormalized `status` for fast filters [oai_citation:15‡HWOA_Serialization_09052025.md](file-service://file-Y8YRLZFfhTbH1Z1k3TTnNz)
- **Metrics inputs:** `partsUsed: String?`, `hoursWorked: Double?`, `finalCost: Int? (cents)` [oai_citation:16‡HWOA_Serialization_09052025.md](file-service://file-Y8YRLZFfhTbH1Z1k3TTnNz)
- **Tags:** `woItem.tags: [TagBinding]` (role, isActive, positionLabel) + `woItem.tagHistory: [TagHistory]` (bound/unbound/reassigned) [oai_citation:17‡HWOA_Serialization_09052025.md](file-service://file-Y8YRLZFfhTbH1Z1k3TTnNz)
- **Flags:** `woItem.isFlagged: Bool` (local per-item flag if used)

---

## Accessibility
- Images labeled (“Primary image for <type>”, “Photo X of Y”)
- Buttons labeled with full action phrases (“Set status In Progress”, “Save PASS”)
- Inputs have hints (“Hours, decimal up to two places”)
- Hit targets ≥ 44×44pt; PASS sheet announces required fields

---

## States
- **Loading:** spinner/skeleton for primary image & thumbs
- **No photos:** show “No photos yet” (secondary text)
- **Validation errors:** inline helper text; disable Save actions until valid
- **Scanner/Reassign:** success/failure toasts; reassign updates chip list immediately

---

## Acceptance Checklist
- [ ] Primary image 1:1 plus 2-column thumbnail grid; fullscreen viewer overlays above content [oai_citation:18‡HWOA_LayoutSpec_Template_09042025.md](file-service://file-REaYr2HQThr7MDMe2WXvWS)  
- [ ] Status buttons write WO_Status entries with user+time; PASS requires parts/hours/cost; FAIL confirm; 2nd FAIL → PROBLEM CHILD [oai_citation:19‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)  
- [ ] “Mark Work Order Completed” respects PASS prerequisites and updates the WorkOrder roll-up via parent flow [oai_citation:20‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)  
- [ ] QR Codes: chips render (shortId • Primary • Position); Add QR supports reassign; actions update `tags` and append `tagHistory` [oai_citation:21‡HWOA_Component_Breakdown_09052025.md](file-service://file-4BMNS7KwQARr54Yb7ULxyq) [oai_citation:22‡HWOA_PRD_09052025.md](file-service://file-AHGLM9kubSGHsgewbTGjzC)  
- [ ] Detail uses **StatusBadge** only; **no indicator dots** appear anywhere in this view [oai_citation:23‡HWOA_Cross-Doc_Acceptance_Checklist_09082025.md](file-service://file-P9JaZQdNnExbLBn3wM1KmX)  
- [ ] Theme tokens only; no hardcoded hex; all controls ≥ 44×44pt; accessible labels present [oai_citation:24‡AppleNotesYellow.json](file-service://file-L6G4fsxLcq6FuS1hWMAmtk) [oai_citation:25‡HWOA_LayoutSpec_Template_09042025.md](file-service://file-REaYr2HQThr7MDMe2WXvWS)

---