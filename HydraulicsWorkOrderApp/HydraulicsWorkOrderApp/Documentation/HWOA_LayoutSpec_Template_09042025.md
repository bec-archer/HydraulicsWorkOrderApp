**SCOPE GUARDRAILS — DO NOT SKIP**
- Only implement the layout described below inside the specified file/component.
- Do **not** rename files, move folders, or modify unrelated views/components.
- Use the existing theme tokens from `Resources/AppleNotesYellow.json` for all colors, radii, and shadows.
- Keep behavior and navigation exactly as documented in the PRD and Component Breakdown.
- If you’re unsure, halt and ask for clarification — do not invent new UI.

> **Status Indicators Policy**
> - **Cards (ActiveWorkOrdersView / WorkOrderCardView):** use **indicator dots only** (overlay on thumbnails + inline next to WO_Number). **No StatusBadge** on cards.  
> - **Detail (WorkOrderDetailView / WorkOrderItemDetailView):** use **StatusBadge** on each WO_Item row.  
> - **Color semantics:** indicator dot colors are derived from the same semantic mapping as `StatusBadge`. Adding a new status only requires updating the central `StatusBadge` mapping; dots inherit automatically.

# Layout Spec Template

## View / Component
- **Name:** <WorkOrderCardView | WorkOrderDetailView | WorkOrderItemDetailView | etc.>
- **File:** Views/<Section>/<FileName>.swift
- **Related models:** <WorkOrder / WO_Item / WO_Status / WO_Note>
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
One sentence on what this layout does and who uses it.
Example: “Display all images for a WO_Item with a primary image and a 2-col square thumbnail grid.”

## Wireframe (ASCII, not code)
```text
<ASCII BOXES HERE — keep proportions obvious>
```

## Grid & Sizing Rules
- **Primary axis:** <horizontal | vertical>
- **Columns / Rows:** iPad: <N> columns; iPhone: <N> columns
- **Aspect ratios:** <e.g., 1:1 square> (crop, not distort)
- **Min/Max sizes:** <e.g., min 160pt, max 320pt>
- **Container width:** <full width | matches primary image width | fixed>
- **Spacing:** <H: 12pt, V: 12pt> (use UI constants if present)

## Visual Style (Theme-driven)
- **Card/background:** cards.background
- **Radius:** cards.cornerRadius
- **Shadow:** cards.shadowOpacity
- **Buttons/links:** linkColor & buttonBackground
> Use tokens from AppleNotesYellow.json; don’t inline hex values.

## Behaviors
- **Tap:** <what happens on tap>
- **Long-press / context:** <if any>
- **Scroll / paging:** <if any>
- **Overlay / zIndex:** <state name> must render **above** <other> with `zIndex(...)`.
- **Selection state:** <if any>

## Data Binding
- **Inputs:** <source arrays/fields> (e.g., `woItem.imageUrls`)
- **Empty state:** <placeholder / hidden>
- **Loading state:** <skeleton / spinner>
- **Error state:** <inline error label>

## Accessibility
- **Labels:** meaningful `accessibilityLabel` on images/buttons
- **Hit targets:** ≥ 44×44 pt
- **Contrast:** rely on theme tokens for text/background

## Breakpoints
- **iPad (regular):** <rule>
- **iPhone (compact):** <rule>
- **Landscape tweaks:** <rule>

## Acceptance Checklist (Cursor must self-verify)
- [ ] Layout matches ASCII proportions and column count.
- [ ] Uses theme tokens; **no hardcoded hex**.
- [ ] Component/file names unchanged and placed per file tree.
- [ ] Behaviors and overlay z-index verified (overlay on top).
- [ ] Works with existing components without refactors.
- [ ] Matches PRD UI style (Apple Notes grid, large tap targets).
- [ ] Satisfies Developer Checklist items relevant to this screen.

# Example Filled Spec — WorkOrderItemDetailView (Image Section)

## View / Component
- **Name:** WorkOrderItemDetailView (Image Section)
- **File:** Views/Main/WorkOrderItemDetailView.swift
- **Related models:** WO_Item (`imageUrls: [String]`)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Display a primary image (square) and a same-width 2-column grid of square thumbnails for the selected WO_Item.

## Wireframe (ASCII, not code)
```text
┌──────────────────────────────────────────────────────────────┐
│                    CONTAINER FOR IMAGES                      │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                   PRIMARY IMAGE (W × W)                │  │
│  │   • Full-width inside Container 1                      │  │
│  │   • Aspect: 1:1 (square), rounded corners              │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │   CONTAINER 2 — WIDTH == PRIMARY IMAGE WIDTH           │  │
│  │  ┌───────────┬───────────┐                             │  │
│  │  │ THUMB 1   │ THUMB 2   │                             │  │
│  │  ├───────────┼───────────┤                             │  │
│  │  │ THUMB 3   │ THUMB 4   │  ← 2 columns, rows wrap     │  │
│  │  └───────────┴───────────┘                             │  │
│  │  Notes:                                                │  │
│  │  • All thumbnails **cropped to 1:1 (square)**          │  │
│  │  • Grid **width = primary image width**                │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```
## Grid & Sizing Rules
- **Primary image:** aspect **1:1** (crop center), rounded with theme `cards.cornerRadius`; width = readable container width.
- **Thumbnail grid:** **2 columns**, fixed square cells (size derives from primary width ÷ 2 minus spacing); **grid width == primary width** (lock with `.frame(width: primaryWidth)`).
- **Spacing:** H = 8pt, V = 8pt.
- **Max width guard:** cap container around 600–700pt on iPad to avoid over-stretch.

## Visual Style (Theme-driven)
- **Background:** `cards.background`
- **Radius / Shadow:** `cards.cornerRadius`, `cards.shadowOpacity`
- **Accent:** interactions use `linkColor` / `buttonBackground` (no inline hex).

## Behaviors
- **Tap thumbnail →** set `selectedImageURL` and show a full-screen overlay viewer.
- **Overlay viewer:** `.zIndex(10)` (must sit **above** the grid), dim backdrop using theme `highlight`, close button ≥ 44pt.
- **Empty state:** show “No photos yet” (use `textSecondary`).

## Data Binding
- **Inputs:** `woItem.imageUrls` (Firebase Storage URLs).
- **Loading:** show a spinner until first image loads.
- **Error:** display a broken-image placeholder cell on failure.

## Accessibility
- **Primary image:** `accessibilityLabel("Primary image for \(woItem.type)")`
- **Thumbnails:** `accessibilityLabel("Thumbnail \(index + 1) of \(imageUrls.count)")`

## Breakpoints
- **iPad (regular):** 2-column thumbs beneath a large primary image.
- **iPhone (compact):** same stacking; constrain primary to device width minus padding.

## Acceptance Checklist (Cursor must self-verify)
- [ ] All images render as **1:1 squares** (cropped, not distorted).
- [ ] Thumbnail **grid width == primary image width**.
- [ ] Full-screen overlay keeps **higher zIndex** than grid and is tappable.
- [ ] Uses theme tokens from AppleNotesYellow.json (no hardcoded hex).
- [ ] File/component names unchanged; integrated inside `WorkOrderItemDetailView` per component map.
- [ ] Matches Apple Notes style in the PRD (clean cards, big taps).
- [ ] Works with Notes/Status components if present (no refactors).

---

## View / Component
- **Name:** ActiveWorkOrdersView (Grid)
- **File:** Views/Main/ActiveWorkOrdersView.swift
- **Related models:** WorkOrder (uses first images from WO_Item(s))
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json) 

## Purpose
Show an Apple Notes–style grid of **active** WorkOrders with big, tappable cards.

## Wireframe (ASCII, not code)
```text
┌─────────────────────────────────────────────────────────────────────┐
│ [Thumb Grid 2×2 max — squares]                                      │
│                     ● ● ● ●   (one dot per WO_Item, up to 4)        │
│ WO_Number                                               time		  │
│ Customer Name														  │
│ (tap) Phone Number											  	  │
└─────────────────────────────────────────────────────────────────────┘
```

## Grid & Sizing Rules
- **Columns (iPad regular):** adaptive min 260pt, ideal 300–340pt; spacing H=16, V=16.
- **iPhone (compact):** 1 column, card max width = readable content width.
- **Card image area:** up to **2×2** thumbnails (from up to 4 WO_Items). Each thumb square 1:1.
- **Sort:** Flagged first, then oldest→newest (creation timestamp).

## Visual Style (Theme-driven)
- Card background / radius / shadow from `cards.*` tokens; text from `textPrimary/Secondary`; accents from `linkColor`. **No hardcoded hex.**
- **Indicator dots**:
  - **Overlay**: one dot at the **top-right** of each item image (one per WO_Item)
  - **Inline**: a summary row of up to **4 dots** on the same line as the **WO_Number**
- Dot colors derive from the **same semantic mapping as `StatusBadge`** (no hardcoded hex). Adding a new status only updates the central mapping; dots inherit automatically.
## Behaviors
- **Tap card →** WorkOrderDetailView.  
- **Tap phone →** tel:/sms: intent (system sheet).
- **Completed items:** do not appear here; this view is **Active** only.  
- **Flagged:** show a small flag icon in the top-right of the card.

## Data Binding
- **Source:** active WorkOrders (`!isCompleted && !isClosed && !isDeleted`).  
- **Thumbnail source:** take the **first image** from up to four WO_Items (if fewer than 4, layout fills row-wise).  
- **Empty state:** centered label “No active WorkOrders”.

## Accessibility
- Card `accessibilityLabel`: “<Customer>, Work Order <WO_Number>”.
- Dots are **decorative**; do not rely on color alone (status text is available in detail views).

## Breakpoints
- iPad landscape: expect 3–4 columns; iPad portrait: 2–3; iPhone: 1.

## Acceptance Checklist
- [ ] Grid adapts by width; cards stay ≥ 260pt wide.
- [ ] Card shows: up to 4 thumbs (1:1), **overlay status dots** (per-thumbnail), **inline dots** (by WO_Number), Customer, Phone (tappable), timestamp. **No StatusBadge** on cards.
- [ ] Flagged cards surface first; then oldest→newest. 
- [ ] Colors/radii/shadows use theme tokens only. 

---

## View / Component
- **Name:** WorkOrderCardView
- **File:** Views/Components/WorkOrderCardView.swift
- **Related models:** WorkOrder, WO_Item
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json) 

## Purpose
Reusable card that matches Apple Notes card styling and content.

## Wireframe (ASCII, not code)
```text
┌─────────────────────────────────────────────────────────────────────┐
│ [Thumb Grid 2×2 max — squares]                                      │
│                     ● ● ● ●   (one dot per WO_Item, up to 4)        │
│ WO_Number                                               time		  │
│ Customer Name														  │
│ (tap) Phone Number											  	  │
└─────────────────────────────────────────────────────────────────────┘
```

## Grid & Sizing Rules
- **Thumb grid:** 1–4 images from WO_Items, 1:1 squares with 6–8pt spacing.

## Visual Style (Theme-driven)
- Card: `cards.background`, `cards.cornerRadius`, `cards.shadowOpacity`.  
- Text: `textPrimary`/`textSecondary`.  
- Tap affordances use `linkColor`. 
## Behaviors
- Tap card → WorkOrderDetailView.  
- Phone is a button (tel:/sms:).  
- Dot colors derive from the **same semantic mapping as `StatusBadge`** (no hardcoded hex). New statuses only require updating the shared mapping.

## Data Binding
- Customer name from WorkOrder’s customer relation.
- **Thumbs:** `items[*].imageUrls[0]`, up to 4 (item create order). Optional `workOrders.imageURL` is a non-authoritative fallback only when **no** items exist.
- **Overlay dots (per-thumbnail):** one dot per rendered item image, colored by that item’s **current status** (In Progress / Done / PASS / FAIL).
- **Inline dots (WO_Number row):** up to **4** dots (one per WO_Item, item create order), colored by each item’s current status.

## Accessibility
- Card label: “Work Order <WO_Number> for <Customer>”.
- Dots are decorative; per-item status is announced in detail views.

## Acceptance Checklist
- [ ] Renders up to 4 square thumbnails; gracefully handles 0–3.
- [ ] Phone button triggers system dialer/sms.
- [ ] Uses theme tokens only; no inline hex.
- [ ] Shows **overlay status dots** on item thumbnails and **inline summary dots** on the WO_Number row (one per item, up to 4).
- [ ] Dot colors follow the same semantic mapping as item status; **no hardcoded hex**.

---

## View / Component
- **Name:** NewWorkOrderView (Intake)
- **File:** Views/Main/NewWorkOrderView.swift
- **Related models:** Customer, WorkOrder, WO_Item
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json) 

## Purpose
Fast intake: lookup/add customer, then inline add **1+ WO_Item** (not a modal), then Check In.

## Wireframe (ASCII, not code)
```text
Customer Lookup: [ Search by name/phone ...................... ]
				 [ match card(s) v ]   [+ Add New Customer]

[ Selected Customer Summary Card (name • phone • X clear) ]

— WO_Item #1 —
[ Scan Tag ]  [ Upload Photo(s) ]  [ Type ▾ ] [ Size ▾ if Type=Cylinder ]
[ Color ▾ (shows name+hex; “Other” → color picker) ]
[ Machine Type ▾ ] [ Brand ▾ ] [ Wait Time ▾ ]
[ Reasons for Service ☑ multi-select ] [If Other → Notes textfield]

[ + Add Item ]

[  Check In Work Order  ]
```

## Grid & Sizing Rules
- **Form width:** iPad = fixed 720–840pt center column; iPhone = full width with safe-area insets.
- **Inline item forms:** stacked; at least one visible by default.  
- **Dropdowns:** two-per-row when width allows; otherwise stack.

## Visual Style (Theme-driven)
- Primary button background from `buttonBackground`; text from `buttonText`.
- Dividers/labels use `textSecondary` and `border`. 
- **Overlay status dots (per-thumbnail):** 6–8pt circular dots, ~6pt spacing, positioned at the **top-right corner** of each item image. Colors derive from the same semantic mapping used for item states (no hex; theme/semantic roles).
- **Inline summary dots (by WO_Number):** up to **4** dots on the WO_Number row, same size/spacing and color semantics as overlay dots.
- **No WorkOrder StatusBadge on Active cards** (badges are item-level or detail views).

## Behaviors
- **Live search** by name/phone; select to fill summary card.  
- **No match →** “+ Add New Customer” opens `NewCustomerModalView`, prefilled, then returns to form. 
- **Reasons for Service:** multi-select; picking **Other** reveals required notes field.  
- **Color dropdown:** shows color name **and** hex; selecting **Other** opens color picker.  
- **+ Add Item:** appends another inline WO_Item section.  
- **Check In Work Order:** creates WorkOrder with items; default status = “Checked In”. 
- **Tag search via history:** resolve **active bindings** (`tags[*].tagId` where `isActive=true`) and **historical** tag IDs via `tagHistory`. **Deduplicate** results to the **current** WO_Item and show a small hint when matched via history.

## Data Binding
- **Thumbs:** `items[*].imageUrls[0]`, up to 4 (item create order). Optional `workOrders.imageURL` is a non-authoritative fallback only when no items exist.
- **Overlay status dots (per-thumbnail):** for each rendered item image, draw one dot colored by that item’s **current status** (e.g., In Progress, Done, Tested: PASS/FAIL).
- **Inline summary dots (WO_Number row):** up to **4** dots (one per WO_Item, item create order), colored by each item’s current status.
- **No WorkOrder status badge** on the card in the Active grid.

## Accessibility
- All controls ≥ 44×44pt; search field has `accessibilityLabel("Customer search")`.
- Status dots are **decorative**; do not rely on color alone. VoiceOver users rely on accessible text (WO_Number, Customer) and per-item status in detail views.

## Acceptance Checklist
- [ ] One inline WO_Item present by default; “+ Add Item” adds more (stacked). 
- [ ] Customer lookup works as described; add-new flow returns to this view with data. 
- [ ] Color field shows name+hex; “Other” opens color picker.
- [ ] Reasons multi-select; if **“Other”** is selected, saving requires **`reasonNotes` non-empty**.
- [ ] Uses theme tokens only. 

---

## View / Component
- **Name:** WorkOrderDetailView
- **File:** Views/Main/WorkOrderDetailView.swift
- **Related models:** WorkOrder, WO_Item, WO_Note, WO_Status
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Single WorkOrder screen: shows all items, their quick status, and a combined notes/status timeline.

## Wireframe (ASCII, not code)
```text
[ Back ]  <Customer Name>           [ Flag toggle ]   [ ... menu ]
WO_Number • Timestamp

— Items —
[ Item Row ]  [StatusBadge]  [Type • Color]   [ > ]

[ Item Row ]  [StatusBadge]  [Type • Color]   [ > ]

— Notes & Status Timeline —
[ 7:05 AM ]  Checked In • Maria
[ 8:12 AM ]  In Progress • Joe
[ 9:14 AM ]  Note: Seals replaced • Joe
[ 9:25 AM ]  Tested: PASS • Joe
...
```

## Grid & Sizing Rules
- **Layout:** vertical stack with two sections: Items then Timeline.
- **Item Row:** min 56pt height; leading thumbnail if available (1:1, 44–56pt).
- **Timeline:** chronological descending (newest at bottom), or toggle “Newest First”.

## Visual Style (Theme-driven)
- Use `textSecondary` for metadata rows; badges via existing `StatusBadge`.  
- Dividers use `border`. Accent buttons use `linkColor`.

## Behaviors
- Tap Item Row → WorkOrderItemDetailView.  
- Flag toggle updates WorkOrder flagged state.  
- Overflow menu: “Mark Completed”, “Mark Closed” (role-gated per PRD).  
- NotesTimelineView merges WO_Status + WO_Note sorted by timestamp.

## Data Binding
- Items from WorkOrder.items; Timeline from combined arrays.  
- Completed WorkOrder shows a subtle **gray** header indicator (not hidden here).  

## Accessibility
- Each Item Row `accessibilityLabel`: “Item <n>, <type>, status <status>”.

## Acceptance Checklist
- [ ] Items list renders all WO_Items with StatusBadge.  
- [ ] Timeline merges notes + statuses in time order.  
- [ ] Flag toggle and role-gated actions match PRD capabilities.  
- [ ] Theme tokens only; no hardcoded hex.
- [ ] Item rows display **StatusBadge** per WO_Item; **no indicator dots** appear in this view.

---

## View / Component
- **Name:** WorkOrderItemDetailView
- **File:** Views/Main/WorkOrderItemDetailView.swift
- **Related models:** WO_Item, WO_Status
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Operate on a single WO_Item: status updates, test PASS/FAIL, parts/hours/cost, photos.

## Wireframe (ASCII, not code)
```text
[ Back ]  <Type>  •  Tags: <PrimaryID> (+N)    [ Flag toggle ]
[ Primary Image (square) ]
[ Thumbnail Grid 2-col squares ]

— Status —
[ In Progress ]  [ Done ]
[ Test: PASS ]   [ Test: FAIL ]

— Details —
[ Parts Used .......... ]
[ Hours Worked .. ]  [ Cost ......... ]

— Actions —
[ Save ]   [ Mark Work Order Completed ]
```

## Grid & Sizing Rules
- Primary image square; thumbs 2-col grid (as specified in your existing image section).  
- Buttons stacked on iPhone; 2-up on iPad when width permits.

## Visual Style (Theme-driven)
- Buttons use `buttonBackground` / `buttonText`.  
- Status badge reflects current state.

## Behaviors
- Tapping PASS/FAIL writes a WO_Status entry (with user + timestamp).  
- On PASS: parts/hours/cost fields become required before “Mark Completed”.  
- On FAIL: if previous updater is different, queue a notification; second FAIL flags “PROBLEM CHILD” (per PRD).

## Data Binding
- Reads/writes to `statusHistory`, `testResult`, and detail fields.  
- Photos section uses the image container spec you already fixed.

## Accessibility
- Buttons have explicit labels: “Set status In Progress”, etc.

## Acceptance Checklist
- [ ] PASS/FAIL writes status entries with user+time.  
- [ ] Second FAIL triggers PROBLEM CHILD flag logic.  
- [ ] Parts/hours/cost are required on PASS before completion.  
- [ ] Uses theme tokens only.

---

## View / Component
- **Name:** SearchView
- **File:** Views/Main/SearchView.swift
- **Related models:** WorkOrder, WO_Item, Customer
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Find WorkOrders by name, phone, WO_Number, **Tag ID**, or status with quick filters.

## Wireframe (ASCII, not code)
```text
[ Name/Phone ............ ]   [ WO_Number .... ]  [ Tag ID .... ]
[ Status ▾ ]   [ Date ▾ ]                              [ Search ]

— Results —
[ Card (WorkOrderCardView) ]   [ Card ]   [ Card ]
```

## Grid & Sizing Rules
- Filters wrap to next line on narrow widths; results reuse WorkOrderCardView grid rules.

## Visual Style (Theme-driven)
- Filter labels `textSecondary`; active filter pills use `highlight` background.

## Behaviors
- Fuzzy search for name/phone; exact/starts-with for WO_Number and tagId.  
- Status and Date are optional filters that refine results.  
- Results tap through to WorkOrderDetailView.

## Data Binding
- Runs query across Firebase/local cache with debounce (250–400ms).

## Accessibility
- Each filter control has a readable label and hint.

## Acceptance Checklist
- [ ] Fuzzy name/phone search and exact-ish IDs.  
- [ ] Results use WorkOrderCardView; grid adapts by width.  
- [ ] Theme tokens only; no inline hex.

---

## View / Component
- **Name:** DropdownManagerView
- **File:** Views/Admin/DropdownManagerView.swift
- **Related models:** (catalog) Dropdowns + Reasons for Service
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Let Admin/SuperAdmin manage dropdown values and Reasons for Service. Managers get read-only with “Request Change”.

## Wireframe (ASCII, not code)
```text
[ Back ]   Dropdown Manager                    [ Schema v1 ]
[ Type ▾ ] [ Size ▾ ] [ Color ▾ ] [ Machine Type ▾ ] [ Brand ▾ ] [ Wait Time ▾ ]
[ Reasons for Service ▾ ]

— List (for selected catalog) —
[ ⠿ ] Cylinder         [ Edit ] [ Deactivate ]
[ ⠿ ] Pump             [ Edit ] [ Deactivate ]
[ + Add Value ]

— Reasons for Service (special) —
[ ⠿ ] Replace Seals    [ Edit ] [ Deactivate ]
[ ⠿ ] Other (requires notes)  [ Edit ]
[ + Add Reason ]
```

## Grid & Sizing Rules
- Two-row selector bar: wraps on iPhone; single row on wide iPad.
- Catalog list uses row height ≥ 48pt; drag handle ⠿ enables reordering.

## Visual Style (Theme-driven)
- Use `textSecondary` for helper labels; `buttonBackground`/`buttonText` for “+ Add”.
- Soft separators via `border`.

## Behaviors
- **Role gates:**
  - **Admin/SuperAdmin:** full CRUD + reorder (drag and drop).
  - **Manager:** read-only; shows **Request Change** button that spawns a prefilled note (route to Notes/Issue log).
- **Reordering:** persists new order as catalog sequence.
- **Reasons for Service:**
  - “Other” is not deactivatable; editing label allowed, but must keep “requires notes” flag.
- **Schema version:**
  - Display current schema version; on Save changes, prompt to **increment schema** and write `DropdownSchema.currentVersion += 1`.
  - If version increments, warn that older WorkOrders may have outdated sets.

## Data Binding
- Lists are loaded from your catalog store (DropdownManager).
- Save operations update Firebase + local cache.
- Reorder writes back index fields or array order.

## Accessibility
- Drag handles are keyboard and VoiceOver accessible (“Move item up/down”).

## Acceptance Checklist
- [ ] Admin/SuperAdmin can **add/edit/deactivate/reorder** values.
- [ ] Managers see **read-only + Request Change** button (no edits).
- [ ] Reasons “Other” keeps **requires notes** constraint.
- [ ] On catalog changes, flow **offers schema version bump** and persists.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** UserManagerView
- **File:** Views/Admin/UserManagerView.swift
- **Related models:** User (name, passcode, role)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Admin/SuperAdmin manage users and roles; enforce rule that **only SuperAdmin** can manage SuperAdmin accounts.

## Wireframe (ASCII, not code)
```text
[ Back ]  User Manager                       [ + Add User ]

Search: [ ......................... ]

— Users —
[ Maria ]   role: manager     [ Edit ] [ Delete ]
[ Joe   ]   role: tech        [ Edit ] [ Delete ]
[ Sam   ]   role: admin       [ Edit ] [ Delete ]

— Add/Edit User Modal —
Name [...........]   Passcode [ 4–8 digits ]   Role [ tech ▾ ]
[ Save ]  [ Cancel ]
```

## Grid & Sizing Rules
- Search bar full-width; list rows ≥ 52pt with clear role tags.
- Modal form single column; on iPad may present as centered sheet.

## Visual Style (Theme-driven)
- Role chips use `highlight` background and `textSecondary` text.
- Primary actions use `buttonBackground`/`buttonText`.

## Behaviors
- **Role gates:**
  - Admin can **not** create/edit/delete SuperAdmin.
  - Only **SuperAdmin** may manage SuperAdmin user(s).
- **Passcode validation:** enforce 4–8 digits; show inline error.
- **Delete:** confirm dialog; prevent deleting last SuperAdmin.
- **Search:** filters by name/role substring.

## Data Binding
- Reads/writes Users collection; updates local cache.
- Role changes apply immediately to gate UI elsewhere on next app launch/sign-in.

## Accessibility
- Row label: “<name>, role <role>”. Buttons have descriptive labels.

## Acceptance Checklist
- [ ] Create/edit/delete users respecting SuperAdmin restrictions.
- [ ] Passcode length validation with clear errors.
- [ ] Search filters list live.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** SettingsView
- **File:** Views/Admin/SettingsView.swift
- **Related models:** DevSettings, SyncManager
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Central place (Admin/SuperAdmin) for environment controls: login toggle, tag scan enforcement, sample data, sync monitor.

## Wireframe (ASCII, not code)
```text
[ Back ]  Settings

— Access & Auth —
[ ] Require Login Screen (toggle)
[ ] Enforce Tag Scan (toggle)

— Developer —
[ Reload Sample Data ]       [ Test WO_Number Rollover ]
[ Monitor Sync Queue > ]

— About —
Version 1.0 (env: PROD)      Firebase: Connected ▪ Local DB: OK
```

## Grid & Sizing Rules
- Sectioned form; buttons full-width on iPhone, aligned in rows on wider iPad.

## Visual Style (Theme-driven)
- Toggles and buttons use theme tokens; status rows use `textSecondary`.

## Behaviors
- **Require Login Screen:** when off, app bypasses PIN at launch (for demos/lab).
- **Enforce Tag Scan:** when on, WO_Item check-in requires tag; off → show bypass reason dialog.
- **Reload Sample Data:** confirm; wipes local cache + seeds known data set (dev only).
- **Test WO_Number Rollover:** simulates date tick to verify daily counter logic.
- **Monitor Sync Queue:** navigates to SyncStatusView.

## Data Binding
- Toggles persist in DevSettingsManager; actions call into SyncManager/seed helpers.

## Accessibility
- Each toggle has hint text (e.g., “When disabled, app opens directly to Active WorkOrders”).

## Acceptance Checklist
- [ ] Login toggle and Tag Scan toggle persist and take effect on next relevant flow.
- [ ] Sample reload and rollover actions confirm before running.
- [ ] Sync monitor link opens SyncStatusView.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** DeletedWorkOrdersView
- **File:** Views/Admin/DeletedWorkOrdersView.swift
- **Related models:** WorkOrder
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
List soft-deleted WorkOrders for restore or permanent delete (role-gated).

## Wireframe (ASCII, not code)
```text
[ Back ]  Deleted WorkOrders                         [ Search ... ]

[ Card ]  Customer • WO_Number • Deleted @ 2025-09-01  [ Restore ] [ Delete Permanently ]
[ Card ]  Customer • WO_Number • Deleted @ 2025-08-29  [ Restore ] [ Delete Permanently ]
...
```

## Grid & Sizing Rules
- Same card width rules as Active grid; show a simple list on iPhone if needed.
- Each row/card ≥ 64pt; action buttons aligned trailing.

## Visual Style (Theme-driven)
- Cards use `cards.*`; “Deleted @ date” uses `textSecondary`.

## Behaviors
- **Restore**: moves WO back to Active/Completed (whatever its last non-deleted status was).
- **Delete Permanently**: confirm dialog (“Type DELETE”); hard-removes record + images (if policy requires).
- **Search**: by name / WO_Number / phone.

## Data Binding
- Query `isDeleted == true`. Actions update both Firebase + local cache.

## Accessibility
- Button labels: “Restore <WO_Number>”, “Delete <WO_Number> permanently”.

## Acceptance Checklist
- [ ] Lists only deleted records and supports restore/hard delete.
- [ ] Confirm before hard delete; restores reappear in the correct list.
- [ ] Theme tokens only; no inline hex.

---

## View / Component
- **Name:** SyncStatusView
- **File:** Views/Admin/SyncStatusView.swift
- **Related models:** SyncManager (queue items, last errors), connectivity state
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Show upload/download queue, last error per item, and a quick retry/flush panel.

## Wireframe (ASCII, not code)
```text
[ Back ]  Sync Status                    Cloud: Online ▪ Local DB: OK

— Queue —
[ UP ] WO 240904-012  images:2  status: pending     [ Retry ] [ Cancel ]
[ UP ] WO 240904-013  delta:notes status: failed ✕  [ Retry ]
[ DN ] Catalog v2     status: complete ✓

— Actions —
[ Retry All Failed ]   [ Flush Local Queue ]  (confirm)
Last run: 2:41 PM · Next: auto on connectivity
```

## Grid & Sizing Rules
- Two sections: Queue (rows ≥ 48pt), Actions (buttons 2-up on wide screens, stacked on iPhone).
- Status icons/text aligned right; keep consistent padding.

## Visual Style (Theme-driven)
- Health line uses `textSecondary`; success/failed badges rely on existing badge palette or neutral text + glyph.
- Buttons use `buttonBackground` / `buttonText`.

## Behaviors
- **Retry/Retry All**: re-enqueue failed tasks.
- **Flush Local Queue**: confirm; clears queued local ops (dev/admin only).
- **Connectivity**: show online/offline; when offline, disable Retry and show hint.

## Data Binding
- Reads from SyncManager queue snapshot; observes changes via publisher.

## Accessibility
- Rows announce “Upload/Download, target, status”.

## Acceptance Checklist
- [ ] Queue shows direction (UP/DN), target, and status (pending/failed/complete).
- [ ] Retry/Flush actions behave with confirmations and disabled states as needed.
- [ ] Theme tokens only; no inline hex.

---

## View / Component
- **Name:** PendingApprovalView
- **File:** Views/Manager/PendingApprovalView.swift
- **Related models:** WorkOrder, WO_Item (flags, failures)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Surface items needing manager attention (e.g., second FAIL → “PROBLEM CHILD”, tag reassignments, overrides).

## Wireframe (ASCII, not code)
```text
[ Back ]  Pending Approval

[ Card ]  Customer • WO_Number • Item: Cylinder • PROBLEM CHILD
		  Reason: 2nd FAIL — leakage at rod seal
		  [ Review ]  [ Snooze 24h ]
[ Card ]  Customer • WO_Number • Tag Reassignment Requested
		  From TAG-A123 → TAG-B987
		  [ Review ]  [ Deny ]
```

## Grid & Sizing Rules
- List of attention cards in a simple vertical stack; card min height ~88pt.

## Visual Style (Theme-driven)
- Attention labels use regular text with an emoji/glyph (no red hex); rely on theme colors.

## Behaviors
- **Review** → ManagerReviewView with the selected WO_Item context.
- **Snooze/Deny**: records a manager note and hides item until snooze expiry or closes request.

## Acceptance Checklist
- [ ] Only shows items requiring manager action (2nd FAIL, tag reassignment, overrides).
- [ ] Review routes with correct context; actions log notes.
- [ ] Theme tokens only.

---

## View / Component
- **Name:** ManagerReviewView
- **File:** Views/Manager/ManagerReviewView.swift
- **Related models:** WO_Item, WO_Status, TagHistory
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Manager can review failing items, approve tag reassignments, and optionally override parts/hours/cost.

## Wireframe (ASCII, not code)
```text
[ Back ]  Review: WO 240904-012 • Item: Cylinder

Issue
[ 2nd FAIL — leakage at rod seal ]
[ Notes (tech) ............................................. ]

Decision
( ) Approve  ( ) Deny  ( ) Request More Info
[ Manager Notes ............................................ ]
[ Submit ]

Optional Overrides
[ Parts Used .......... ]  [ Hours .... ]  [ Cost ......... ]

Tag Reassignment (if pending)
Old: TAG-A123   New: TAG-B987   Reason: Damaged / unreadable
[ Approve Reassignment ]  [ Deny ]
```

## Grid & Sizing Rules
- Form sections stacked; on iPad, Decision and Overrides can sit side-by-side if width allows.

## Visual Style (Theme-driven)
- Section headers use `label` styling; buttons use theme tokens.

## Behaviors
- **Submit** posts a WO_Status note with decision + manager notes; clears from PendingApprovalView.
- **Overrides** (if filled) write manager-level adjustments to the item and add a status entry.
- **Tag reassignment** actions append a `tagHistory(event:"reassigned")`, deactivate the old binding, and activate the new binding on approve (deny writes a note without changing bindings).

## Acceptance Checklist
- [ ] Decision writes an auditable entry (user + timestamp).
- [ ] Optional overrides persist correctly and are visible in item detail.
- [ ] Tag reassignment approval updates current tag and keeps history.
- [ ] Theme tokens only.

---

### Patch — WorkOrderCardView

## Wireframe (add emoji bubble)
```text
┌───────────────────────────────────────────────┐
│ [Thumb Grid 2×2 max — squares]               │
│                                               │
│ [🔧] Customer Name            [Flag? ▲]       │
│ StatusBadge     •   (tap) Phone Number        │
│ WO_Number      •   Timestamp (short)          │
└───────────────────────────────────────────────┘
```

## Behaviors (add)
- If `customer.emojiTag` exists, render it in a small leading bubble before the name.
- Emoji bubble has min tap target 28–32pt but is **not** interactive here.

## Acceptance Checklist (add)
- [ ] When `emojiTag` is set, it displays before the customer name; otherwise spacing collapses with no gap.

---

### Patch — WorkOrderDetailView

## Wireframe (header)
```text
[ Back ]  [🔧] <Customer Name>        [ Flag toggle ]   [ ... menu ]
WO_Number • Timestamp
```

## Acceptance Checklist (add)
- [ ] If `emojiTag` exists, header shows it before the customer name.

---

### Patch — NewWorkOrderView

## Wireframe (summary card snippet)
```text
[ Selected Customer ]
[🔧] <Customer Name> • <Phone>       [ Edit Emoji ] [ X Clear ]
```

## Behaviors (add)
- **Edit Emoji** presents a tiny sheet:
  - Field with emoji keyboard; **Save** stores to `Customer.emojiTag`, **Remove** clears it.
  - Validate single grapheme; if more entered, keep first grapheme.
- After saving, the summary card updates live and persists to Customer.

## Acceptance Checklist (add)
- [ ] Summary card shows emoji if present, and **Edit Emoji** updates/clears it.

---

### Patch — SearchView (optional filter)

## Wireframe (filters line)
```text
[ Name/Phone ] [ WO_Number ] [ Tag ID ] [ Status ▾ ] [ Emoji 🔎 ]
```

## Behaviors (add)
- If Emoji filter has a value, restrict results to customers whose `emojiTag` matches exactly.

## Acceptance Checklist (add)
- [ ] When an emoji is entered in the Emoji filter, only matching customers’ WorkOrders appear.

---

## View / Component
- **Name:** CustomersView
- **File:** Views/Main/CustomersView.swift
- **Related models:** Customer, WorkOrder (for recent WOs)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Browse/search customers; view detail; start a new WorkOrder with selected customer.

## Wireframe (ASCII, not code)
```text
[ Back ]  Customers                             [ + New Customer ]

Search: [ Name or Phone ......................... ]

— Results (list/grid by width) —
[🔧] Maria Lopez         (239) 555-1234     [ View ] [ New WO ]
[⭐️] Acme Hydraulics     (239) 555-8899     [ View ] [ New WO ]
[   ] John Smith         (239) 555-7777     [ View ] [ New WO ]
```

## Grid & Sizing Rules
- iPad: 2-column grid cards ≥ 320pt; iPhone: single list row ≥ 56pt.
- Emoji tag bubble (if present) sits before the name; reserve 28–32pt.

## Visual Style (Theme-driven)
- Cards/rows use `cards.*` (iPad) or plain list with `border` separators (iPhone).
- Secondary text (phone/recent info) uses `textSecondary`.

## Behaviors
- **Search** filters by name or phone (fuzzy).
- **View** → CustomerDetailView.
- **New WO** → NewWorkOrderView with this customer pre-selected.
- If no results: show “No matching customers”.

## Data Binding
- Loads customers from cache/Firebase; live updates on edits/new entries.

## Accessibility
- Row label: “<name>, phone <number>”; emoji announced if present.

## Acceptance Checklist
- [ ] Search filters by name or phone (fuzzy).
- [ ] Emoji tag renders when set; spacing collapses when not set.
- [ ] “New WO” opens new WorkOrder flow with customer prefilled.
- [ ] Theme tokens only; no inline hex.

---

## View / Component
- **Name:** CustomerLookupRow
- **File:** Views/Components/CustomerLookupRow.swift
- **Related models:** Customer
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Reusable row for search results and autocomplete dropdowns (NewWorkOrderView).

## Wireframe (ASCII, not code)
```text
[🔧]  Maria Lopez
	  (239) 555-1234
					 [ Select ]
```

## Grid & Sizing Rules
- Leading emoji box 28–32pt; name on first line, phone on second.
- Button trailing; row min height 56–60pt.

## Visual Style (Theme-driven)
- Row hover/pressed states use subtle `highlight`.
- Phone uses `textSecondary`.

## Behaviors
- **Select** returns the Customer to the parent (e.g., NewWorkOrderView) and collapses the lookup.

## Acceptance Checklist
- [ ] Emoji shows when present; otherwise left padding collapses.
- [ ] Select passes full Customer object to parent.
- [ ] Theme tokens only.

---

## View / Component
- **Name:** LoginView
- **File:** Views/Authentication/LoginView.swift
- **Related models:** User (name, passcode, role), DevSettings
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Enter numeric passcode to sign in; optional bypass if login disabled in Settings.

## Wireframe (ASCII, not code)
```text
[  Hydraulics Work Orders  ]

Passcode: [ • • • • ]   [  Show  ]
[ Sign In ]
[ Choose User > ]  (opens UserSelectionView)

If login disabled:
[ Continue as Guest ] (role: tech or last used)
```

## Grid & Sizing Rules
- Centered column; iPad width ~420–520pt, iPhone full width with safe insets.

## Visual Style (Theme-driven)
- Primary button uses `buttonBackground`/`buttonText`.
- Helper text uses `textSecondary`.

## Behaviors
- PIN 4–8 digits; invalid shows inline error.
- If DevSettings “Require Login” = off → show “Continue as Guest” (role per setting).

## Acceptance Checklist
- [ ] Valid PIN routes to proper role start (ActiveWorkOrdersView, plus sidebar per role).
- [ ] When login disabled, guest path appears and works.
- [ ] Theme tokens only.

---

## View / Component
- **Name:** UserSelectionView
- **File:** Views/Authentication/UserSelectionView.swift
- **Related models:** User
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Admin-only user picker to test routes or switch identities quickly.

## Wireframe (ASCII, not code)
```text
[ Back ]  Choose User

Filter: [ ............ ]

[ Maria ] manager    [ Sign In ]
[ Joe   ] tech       [ Sign In ]
[ Sam   ] admin      [ Sign In ]
```

## Behaviors
- Filter by name/role; tapping Sign In pre-fills LoginView with that user’s context or directly routes (admin-only mode).

## Acceptance Checklist
- [ ] Admin-only access; non-admins cannot open.
- [ ] Filter works; Sign In routes accordingly.
- [ ] Theme tokens only.

---

## View / Component
- **Name:** FullScreenImageViewer
- **File:** Views/Components/FullScreenImageViewer.swift
- **Related models:** (none) — takes a bound image URL/string + binding isPresented
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Display a single image fullscreen with dimmed backdrop, pinch-zoom, and a close button. Must always sit **above** thumbnail grids.

## Wireframe (ASCII, not code)
```text
╔══════════════════════════════════════════════════════════════╗
║  [ ✕ ]                                           (draggable) ║
║                                                              ║
║                [   Zoomable Image Canvas   ]                 ║
║                                                              ║
║          (dim overlay behind; dismiss on background tap)     ║
╚══════════════════════════════════════════════════════════════╝
```

## Grid & Sizing Rules
- Viewer fills screen; close button ≥ 44×44pt at top-right with safe-area padding.

## Visual Style (Theme-driven)
- Backdrop uses `highlight` at ~60–70% opacity; no hardcoded colors.

## Behaviors
- Presents via `.overlay` on the host view with `.zIndex(1000)`.
- Pinch-zoom & pan (MagnificationGesture + DragGesture). Double-tap to reset zoom.
- Tap backdrop or ✕ closes; swipe-down to dismiss (nice to have).

## Data Binding
- `@Binding var isPresented: Bool`, `let imageURL: String` (or `UIImage`).
- Optional: preload/spinner until first frame available.

## Accessibility
- Close button `accessibilityLabel("Close full screen image")`.
- Image `accessibilityLabel` passes through from parent (“Photo X of Y for <item>”).

## Acceptance Checklist
- [ ] Overlay always appears **above** thumbnail grid (zIndex > 999).
- [ ] Pinch-zoom & pan work; double-tap resets.
- [ ] Backdrop tap and ✕ reliably dismiss viewer.
- [ ] Uses theme tokens; no hex literals.

---

## View / Component
- **Name:** CompletedWorkOrdersView
- **File:** Views/Main/CompletedWorkOrdersView.swift
- **Related models:** WorkOrder
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Browse **completed** (not closed) WorkOrders. Cards appear **grayed** and are read-only, except for actions like “Reopen” (role-gated) or “Mark Closed”.

## Wireframe (ASCII, not code)
```text
[ Back ]  Completed WorkOrders                        [ Search … ]

┌─────────────────────┐ ┌─────────────────────┐
│  [thumbs 2x2] (dim) │ │  [thumbs 2x2] (dim) │
│  Customer • Status  │ │  Customer • Status  │
│  Phone (tappable)   │ │  Phone (tappable)   │
│  WO_Number • time   │ │  WO_Number • time   │
└─────────────────────┘ └─────────────────────┘
```

## Grid & Sizing Rules
- Same grid rules as ActiveWorkOrdersView (adaptive cards).
- Apply a **dim/gray style** to card content (e.g., reduced opacity on image area and secondary text emphasis).

## Visual Style (Theme-driven)
- Use theme tokens only; gray effect achieved by opacity on images + `textSecondary`.

## Behaviors
- Tap card → WorkOrderDetailView (read-only except role-gated actions).
- Optional row actions (role-gated):
  - **Reopen** (returns to Active).
  - **Mark Closed** (moves out of Completed into Closed/Archive).

## Data Binding
- Query: `isCompleted && !isClosed && !isDeleted`.

## Accessibility
- Card announces “Completed” state in `accessibilityLabel`.

## Acceptance Checklist
- [ ] Only Completed WOs appear; not Closed/Deleted.
- [ ] Card visuals clearly indicate completed (dim/gray).
- [ ] Role-gated actions surface as allowed; otherwise read-only.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** CustomerDetailView
- **File:** Views/Main/CustomerDetailView.swift
- **Related models:** Customer, WorkOrder
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
View/edit a customer (name, phone, company, email, tax exempt) and manage the **emoji tag**. Show recent WorkOrders and quick actions.

## Wireframe (ASCII, not code)
```text
[ Back ]  Customer Detail                          [ Save ]

[🔧] Name [....................]     Phone [ (239) 555-1234 ]
Company [.................... ]      Email [ ............. ]
Tax Exempt [ ] toggle

Emoji Tag
[ 🔧 ]  [ Change Emoji ]  [ Remove ]

Recent WorkOrders
[ Card ] [ Card ] [ Card ]

Actions
[ New Work Order ]  [ Call ]  [ Text ]
```

## Grid & Sizing Rules
- Two-column layout on wide iPad (fields split), single column on iPhone.
- Emoji row sits just below base fields.

## Visual Style (Theme-driven)
- Field labels use `textSecondary`; primary actions use `buttonBackground`/`buttonText`.

## Behaviors
- **Change Emoji**: opens small sheet with emoji keyboard. Validate single grapheme; if multiple pasted, keep first grapheme.
- **Remove** clears `emojiTag`.
- **Save** persists all fields (and emoji) to Firebase + local cache.
- **Recent WorkOrders** show most recent 3–6; tapping opens detail.
- **New Work Order** navigates to NewWorkOrderView prefilled with this customer.

## Data Binding
- Bidirectional binding to Customer; emoji stored in `emojiTag: String?`.

## Accessibility
- Emoji change/removal buttons have explicit labels and hints (“Sets one emoji for this customer”).

## Acceptance Checklist
- [ ] Save updates all fields including `emojiTag`.
- [ ] Recent WorkOrders show and open correctly.
- [ ] New Work Order preselects this customer.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** NewCustomerModalView
- **File:** Views/Main/NewCustomerModalView.swift
- **Related models:** Customer
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Create a new customer from a lookup miss. Prefill name or phone based on what the user typed. Return to the originating form with the new Customer selected.

## Wireframe (ASCII, not code)
```text
[ Cancel ]           New Customer                 [ Save ]
Name [ if from name search, prefilled ......... ]
Phone [ if from phone search, prefilled ...... ]
Company [...................]   Email [...............]
Tax Exempt [ ] toggle
Emoji Tag [ 🔧 ] [ Pick Emoji ]
```

## Grid & Sizing Rules
- Modal width ~420–520pt on iPad; full width sheet on iPhone.
- Vertical stack form; actions pinned to top/right or bottom toolbar per platform norms.

## Visual Style (Theme-driven)
- Primary button uses `buttonBackground`/`buttonText`.
- Labels use `textSecondary`.

## Behaviors
- On **Save**:
  - Validate phone or name exists.
  - Create Customer record (emoji optional).
  - Dismiss modal and **return selected Customer** to the parent (e.g., NewWorkOrderView).
- On **Cancel**: dismiss without changes.
- **Pick Emoji**: mini picker as in CustomerDetailView; enforce single grapheme.

## Data Binding
- Prepopulation:
  - If parent search was phone-like → prefill phone field.
  - If parent search was name-like → prefill name field.

## Accessibility
- Announce “New Customer” dialog; all inputs labeled.

## Acceptance Checklist
- [ ] Save creates customer and returns selection to parent form.
- [ ] Prefill logic uses typed search text (name or phone).
- [ ] Optional emoji tag saved when set.
- [ ] Theme tokens only; no inline hex.

---

## View / Component
- **Name:** CustomersView (Empty State & Paging)
- **File:** Views/Main/CustomersView.swift

## Purpose
Handle very large customer lists cleanly: empty states, incremental paging, and fast scroll.

## Empty State
```text
( 🧑‍🔧 )
No customers yet
Tap “+ New Customer” to add your first customer.
```

## Paging & Large Lists
- **Page size:** fetch in chunks of ~50–100.
- **Trigger:** load next page when scroll approaches last 8–10 rows.
- **Search paging:** when a query is active, reset to page 1 and re-page results as needed.
- **Fast scroll:** on iPad, optionally show an **A–Z index** on the right when not searching. On iPhone, use a floating “Jump to top” button after >2 pages.

## Grid & Sizing Rules
- iPad grid cards ≥ 320pt; list rows ≥ 56pt.
- Keep placeholder and skeleton rows consistent height to avoid layout shift.

## Visual Style (Theme-driven)
- Empty-state icon/text use `textSecondary`.
- Skeleton rows use `highlight` with subtle shimmer (if you have it); otherwise static rectangles.

## Behaviors
- **Skeletons:** show while the first page is loading (2–3 cards/rows).
- **Retry:** on failed fetch, show an inline “Retry” button beneath the empty state.
- **A–Z index:** only visible with ≥ 500 customers and no active search.

## Acceptance Checklist
- [ ] Empty state appears only when 0 results and no search text.
- [ ] Infinite scroll fetches the next page as you near the end.
- [ ] Search resets paging; clearing search restores previous paging state.
- [ ] Theme tokens only; no inline hex.

---

## View / Component
- **Name:** TagReassignmentSheet
- **File:** Views/Manager/TagReassignmentSheet.swift
- **Related models:** WO_Item (`tags: [TagBinding]`, `tagHistory: [TagHistory]`)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Manager/Admin approve or deny **reassigning** a scanned tag from one WO_Item to another, recording an auditable history entry and keeping reverse lookups correct.  <!-- Multi-binding model per Schema -->

## Wireframe (ASCII, not code)
```text
[ Close ]              Tag Reassignment

Item: Cylinder • WO 240904-012
Reassign: TAG-A123  →  (to this item)
Reason (tech): Damaged / unreadable

Manager Note
[ ................................................. ]

[ Deny ]                       [ Approve ]
```

## Behaviors
- **Approve:**
  - Deactivate the old active binding on the previous owner (`tags[*].isActive = false`).
  - Create a new **TagBinding** on this item (role defaults to **"aux"** unless no Primary exists; then offer **Set Primary**).
  - Append a **TagHistory** entry with `event: "reassigned"` (include `fromItemId`, `toItemId`, `byUserId`, `reason`, `at`).
  - Update the **/tagIndex** entry to point to the current owner (current: `true`).
  - Close sheet.
- **Deny:** log a manager note/status entry (no binding changes) and close sheet.
- **Validation:** `newTagId` (the scanned tag) must exist and differ from any active binding on this item.

## Data Binding
- Inputs: `oldTagId` (source active binding), `newTagId` (scanned), `fromItemRef?`, `toItemRef`.
- Outputs: `(a)` updated `tags[]` on both items (deactivate old, add new), `(b)` appended **`tagHistory`** on the reassigned tag, `(c)` updated **`/tagIndex`**.

## Accessibility
- Buttons labeled “Approve tag reassignment” / “Deny tag reassignment”.

## Acceptance Checklist
- [ ] Approve deactivates old binding, creates new **TagBinding**, appends **tagHistory(event:"reassigned")**, and updates **/tagIndex**.
- [ ] Deny logs a decision without changing bindings.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** SearchView (Result States)
- **File:** Views/Main/SearchView.swift

## Purpose
Make search outcome states explicit and friendly: Loading, No Results, and Error.

## Wireframe (ASCII, not code)
```text
[ Filters ……… ]                      [ Search ]

— Results —

( ⌛ )
Searching…
( show skeleton cards/rows )

— OR —

( 🧐 )
No results for “A123”
Try different filters or clear some.

— OR —

( ⚠️ )
Couldn’t load results
[ Retry ]
```

## Grid & Sizing Rules
- Skeleton result rows/cards match the size of final cards/rows (avoid layout shift).
- Empty/error panels centered with max width ~520pt.

## Visual Style (Theme-driven)
- Icons/emoji + textSecondary for messages.
- Retry uses `buttonBackground` / `buttonText`.

## Behaviors
- **Loading:** show skeletons immediately (debounced query still running).
- **No results:** appears only after a completed query returns 0.
- **Retry:** re-issues the last query (including all filters) if an error occurred.
- **Preserve filters:** switching tabs or leaving and returning should restore the last query + filters.

## Data Binding
- Keep `lastQuery` and `lastFilters` in a small view model; restore when view appears.

## Accessibility
- Panels have descriptive labels (“No results”, “Could not load”).

## Acceptance Checklist
- [ ] Loading shows skeletons; hides when results arrive or fail.
- [ ] No results panel only after a completed query returns 0.
- [ ] Retry re-runs the exact last query and filters.
- [ ] Theme tokens only; no inline hex.

---

## View / Component
- **Name:** CustomersView (A–Z Directory)
- **File:** Views/Main/CustomersView.swift

## Purpose
Optionally present the customer list as a sectioned A–Z directory with sticky letter headers when **not searching** and the dataset is large.

## When to switch to A–Z
- Total customers ≥ **500** and search text is **empty** → show sectioned A–Z.
- Otherwise fall back to normal grid/list.

## Wireframe (ASCII, not code)
```text
[ Back ]  Customers                               [ + New Customer ]

Search: [ Name or Phone ......................... ]

A
[🔧] Acme Hydraulics       (239) 555-8899    [ View ] [ New WO ]
[   ] Alamo Rentals        (239) 555-0021    [ View ] [ New WO ]

B
[⭐️] Bob Smith             (239) 555-7777    [ View ] [ New WO ]
...

   A   B   C   D   E   F   G   H  …  Z
```

## Grid & Sizing Rules
- Sticky headers (A, B, C…) pin to the top during scroll.
- Right-side A–Z index bar shows on iPad; on iPhone show after >2 pages of content.

## Visual Style (Theme-driven)
- Section headers use `label` font size and `textSecondary`.
- Index bar uses `textSecondary` and larger hit targets (≥ 28×28pt).

## Behaviors
- Tapping an index letter scrolls to that section.
- If an emoji tag exists, render before the name (as elsewhere).
- During active search, hide section headers and index.

## Data Binding
- Precompute sections by first letter of **normalized display name** (fold diacritics, uppercase).

## Accessibility
- Index bar announces “Jump to <Letter>”.

## Acceptance Checklist
- [ ] A–Z mode only when count ≥ 500 and no search text.
- [ ] Sticky headers pin; index jumps work.
- [ ] Emoji tag renders consistently.
- [ ] Theme tokens only; no inline hex.

---

## View / Component
- **Name:** WorkOrderItemDetailView (PASS/FAIL UX)
- **File:** Views/Main/WorkOrderItemDetailView.swift

## Purpose
Make PASS/FAIL flows explicit: lightweight confirmations and required-fields prompts.

## Wireframe (ASCII, not code)
```text
[ Test: PASS ]   [ Test: FAIL ]

If PASS tapped:
( Sheet )
Mark Tested: PASS
Parts Used [........]
Hours [..]   Cost [.....]
[ Cancel ]                  [ Save PASS ]

If FAIL tapped:
( Alert )
Mark Tested: FAIL?
[ Cancel ]  [ Confirm FAIL ]
```

## Behaviors
- **PASS tap →** open a small sheet requiring Parts/Hours/Cost before saving PASS.
  - On Save, write a `WO_Status` (“Tested: PASS”), persist fields, close sheet.
- **FAIL tap →** simple confirm alert.
  - On confirm, write `WO_Status` (“Tested: FAIL”).
  - If previous updater ≠ current user, queue a notification.
  - If `failCount == 2` for this item, flag PROBLEM CHILD and surface to PendingApprovalView.
- **Required fields:** When PASS sheet open, disable “Save PASS” until all required fields are nonempty and valid numbers.

## Visual Style (Theme-driven)
- Sheet buttons use theme tokens; errors use subtle `textSecondary` + inline message.

## Accessibility
- Sheet fields labeled with hints (“Required for PASS”).

## Acceptance Checklist
- [ ] PASS requires Parts/Hours/Cost before saving status.
- [ ] FAIL confirmation writes status and triggers 2nd-fail logic.
- [ ] Current vs previous updater rule followed for notifications.
- [ ] Theme tokens only; no inline hex.

---

## View / Component
- **Name:** NotesTimelineView
- **File:** Views/Components/NotesTimelineView.swift
- **Related models:** WO_Status, WO_Note
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Render a single chronological timeline by merging status updates and freeform notes with clear visual affordances.

## Wireframe (ASCII, not code)
```text
— Today —
09:30  Completed              • Joe
09:26  Parts: seals; Hours:1  • Joe
09:25  Tested: PASS           • Joe
09:14  Note: Seals replaced   • Joe
08:12  In Progress            • Joe
07:05  Checked In             • Maria

— Yesterday —
16:02  Note: Customer called  • Maria
```

## Merge & Grouping Rules
- **Data source:** `[WO_Status] + [WO_Note]` merged by timestamp ascending.
- **Day headers:** insert “Today”, “Yesterday”, or date (MMM d) when day boundary changes.
- **Icons (optional):** status entries may show a small glyph (✓ for Completed, ▶ for In Progress, etc.); notes show a chat bubble glyph.
- **Status detail lines:** include `notes` string if present (e.g., “Tested: FAIL — pressure leak”).
- **Author:** trailing “• <user>”.
- **Long text:** wrap to multiple lines with comfortable spacing.

## Visual Style (Theme-driven)
- Timestamps `textSecondary`; headers larger label weight; rows on `background` with subtle separators via `border`.

## Behaviors
- Deep-link: tapping an entry may reveal related item (optional).
- Lazy loading: if there are > 200 entries, load in batches of ~50 with “Load more” at top.

## Accessibility
- Each row has a combined `accessibilityLabel` including time, type (status/note), summary, and author.

## Acceptance Checklist
- [ ] Statuses + notes merged by timestamp with day headers.
- [ ] Status rows show type + optional note; author appended.
- [ ] Large timelines paginate/load more cleanly.
- [ ] Theme tokens only; no inline hex.

---

## View / Component
- **Name:** SearchView (Saved Filters)
- **File:** Views/Main/SearchView.swift

## Purpose
Allow users to save frequently used filter sets (aka “presets”) and re-apply them quickly.

## Wireframe (ASCII, not code)
```text
[ Name/Phone … ] [ WO_Number … ] [ Tag ID … ] [ Status ▾ ] [ Date ▾ ]    [ Save as Preset ]
Presets: [ My Work Today ▾ ]
		  [ Edit Presets ]

— Results —
[ Cards … ]
```

## Behaviors
- **Save as Preset** captures the current filter set (status/date/name/phone/tag/WO_Number).
- **Presets menu** lists saved presets; selecting one immediately applies filters and runs the search.
- **Edit Presets** lets users rename or delete presets (simple list with [Rename] [Delete]).
- **Scope:** presets are local to the device (no cross-user sync needed unless you want it).

## Data Binding
- Store presets in a small local store (e.g., `UserDefaults` or DevSettings).
- Each preset: `{ id, name, filters: {…}, createdAt }`.

## Visual Style (Theme-driven)
- Preset chips/menu align with theme; buttons use `buttonBackground`/`buttonText`.

## Acceptance Checklist
- [ ] Saving captures all current filters; applying re-runs the query.
- [ ] Preset rename/delete work and update the menu immediately.
- [ ] Presets persist across launches locally.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** WorkOrderNumberBadge
- **File:** Views/Components/WorkOrderNumberBadge.swift
- **Related models:** WorkOrder (WO_Number)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Display `WO_Number` in a compact, readable badge across cards and detail headers.

## Format Rules
- Default format: `YYMMDD-###` (e.g., `250904-012`).
- If suffixes exist (e.g., split/child items): append `-A`, `-B` etc. (`250904-012-A`).
- Truncation: if horizontal space is tight, fade-truncate middle (e.g., `2509…12-A`) before hiding the suffix.

## Wireframe (ASCII, not code)
```text
[ WO 250904-012 ]   (rounded capsule)
```

## Grid & Sizing Rules
- Capsule height 24–28pt; horizontal padding 10–12pt; font ≈ label size.
- In cards, badge sits on the metadata line (left of timestamp) with ≥ 8pt gap.

## Visual Style (Theme-driven)
- Capsule background uses a subtle `highlight`; text uses `textPrimary`.

## Behaviors
- On tap (optional): copies WO_Number to clipboard with a small toast (“Copied”).
- VoiceOver reads: “Work Order number two five zero nine zero four dash zero one two”.

## Acceptance Checklist
- [ ] Badge renders consistently on cards and headers.
- [ ] Long numbers truncate gracefully; suffix remains visible when possible.
- [ ] (Optional) tap-to-copy shows toast and copies number.
- [ ] Theme tokens only; no hex literals.


---

## View / Component
- **Name:** StatusBadge
- **File:** Views/Components/StatusBadge.swift
- **Related models:** WO_Status / WorkOrder status strings
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Consistent, legible badges for key states. Mapping is semantic; **do not hardcode hex** — derive from theme palette or semantic roles.

## States & Semantics
- **Checked In** — neutral/info
- **In Progress** — active/wip
- **Done** — success/ready for test
- **Tested: PASS** — success
- **Tested: FAIL** — attention
- **Completed** — archived/neutral (dim)
- **Closed** — archived/neutral (dimmer)
- **PROBLEM CHILD** — attention/highlight

## Visual Treatment
- Use filled capsules with high-contrast text.
- Completed/Closed use subdued treatment (opacity or secondary text) rather than a specific color.

## Behaviors
- Accessible labels: include state name; avoid color-only communication.
- Optional glyphs: ▶ for In Progress, ✓ for Done/Pass, ! for Fail/Problem.

## Acceptance Checklist
- [ ] Each state has a distinct, theme-derived appearance (no hex).
- [ ] Completed/Closed appear subdued vs active states.
- [ ] Badges are readable (contrast) and accessible (text + glyph, not color only).

- **Source of truth for colors:** All status colors come from `StatusBadge`’s semantic mapping. **Indicator dots must reference this mapping**, not local colors. Extending status types requires updating this mapping only.

---

## View / Component
- **Name:** WOItemPhotoSection
- **File:** Views/Components/WOItemPhotoSection.swift
- **Related models:** WO_Item (`imageUrls: [String]`)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Capture/import photos for a WO_Item, show upload progress, and manage a small gallery (delete/retry).

## Wireframe (ASCII, not code)
```text
Photos
[ + Camera ] [ + Library ]                    (min 1 recommended)

— Upload Queue (only when uploading) —
IMG_1023.jpg      67%  [ Cancel ]
IMG_1024.jpg      12%  [ Cancel ]

— Gallery (tap to preview fullscreen) —
[ ◻︎ ] [ ◻︎ ] [ ◻︎ ] [ + ]     (2-col on compact, 3–4-col on wide)
( long-press )  [ Delete ] [ Set as Primary ]
```

## Grid & Sizing Rules
- Thumbnails are 1:1 squares; spacing 8pt; 2 cols (iPhone), 3–4 cols (iPad).
- “+” tile always last; disabled while queue > 0 if you want to throttle.

## Visual Style (Theme-driven)
- Buttons use `buttonBackground/buttonText`; progress text uses `textSecondary`.
- Queue rows on `highlight` background with subtle corners; no hex literals.

## Behaviors
- **+ Camera** opens camera; **+ Library** opens multi-select picker.
- Each selected asset uploads to Storage (unique path) and, on success, appends URL to `woItem.imageUrls`.
- Show per-item progress (0–100%); allow **Cancel** to remove from queue.
- **Delete** removes URL from `imageUrls` (optionally also delete remote file, behind a confirm).
- **Set as Primary** moves the chosen image URL to index 0 (affects primary display).
- Tap any thumbnail → FullScreenImageViewer overlay (pinch/zoom).

## Data Binding
- Maintain a lightweight `UploadItem { id, localThumb, progress, state }` list while uploading.
- Commit only completed URLs to `woItem.imageUrls` (no partials).

## Accessibility
- Thumbs: “Photo X of Y”; actions have explicit labels.

## Acceptance Checklist
- [ ] Camera/library add images; uploads show progress and append on success.
- [ ] Cancel removes from queue; Delete removes from gallery (with confirm).
- [ ] Set as Primary reorders to index 0 and updates primary display.
- [ ] Theme tokens only; no hardcoded hex.

---

## View / Component
- **Name:** PartsHoursCostForm
- **File:** Views/Components/PartsHoursCostForm.swift
- **Related models:** WO_Item (partsUsed, hoursWorked, cost)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Provide consistent, low-friction numeric entry for PASS flow or manager overrides, with inline validation.

## Wireframe (ASCII, not code)
```text
Parts Used
[ Text area … (bulleted lines optional) ]

Hours Worked          Cost
[ 1.25  ]   hrs      [ 125.00 ]   USD

Notes (optional)
[ ........................................ ]
```

## Input Rules
- **Hours:** decimal ≥ 0, max 2 decimals (1.25 OK), clamp to reasonable max (e.g., 100).
- **Cost:** currency numeric ≥ 0, 2 decimals; auto-format on blur (e.g., 125 → 125.00).
- **Parts Used:** free text; suggest bullets if multiple parts.

## Visual Style (Theme-driven)
- Field labels use `textSecondary`; invalid input shows a subtle helper line in `textSecondary` with an error icon/glyph (no red hex).

## Behaviors
- Live validation; disable **Save/Continue** while invalid.
- On focus-out:
  - Hours and Cost auto-format (trim spaces, fix decimals).
- Optional: quick-add chips (e.g., +0.25 hr, +0.5 hr).

## Accessibility
- Each field labeled with units in hints (“Hours, decimal up to two places”).

## Acceptance Checklist
- [ ] Hours accepts valid decimal, clamps extremes, and formats on blur.
- [ ] Cost formats to currency with 2 decimals; rejects non-numeric.
- [ ] Save/Continue disabled while invalid; helper text shows what to fix.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** SyncConflictToast
- **File:** Views/Components/SyncConflictToast.swift
- **Related models:** WorkOrder (lastModified/lastModifiedBy), SyncManager
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Notify users of server/local conflicts without stopping their flow; offer a “See details” sheet and a one-tap resolution.

## Wireframe (ASCII, not code)
```text
( Toast — bottom )
⚠️ Changes saved with conflicts. Last write wins.
[ Undo ]   [ Details ]

( Details Sheet )
WorkOrder 250904-012 had conflicting edits.
• Local change: partsUsed = “Seals kit”
• Remote change: partsUsed = “Seals + wiper”
Kept: Remote (2:41 PM by Maria)

[ Keep Remote ]  [ Keep Local ]   [ Merge Manually ]
```

## Behaviors
- Toast appears after a conflict is detected/resolved by SyncManager (“last write wins” default).
- **Undo** reverts local mutation if possible (soft undo of last local change).
- **Details** opens a sheet with:
  - key fields in conflict, who changed, and when (times in local timezone).
  - **Keep Remote**: re-fetch and apply remote snapshot.
  - **Keep Local**: re-apply local change and push.
  - **Merge Manually**: navigates to the relevant view/field with both values shown inline for manual pick.

## Visual Style (Theme-driven)
- Toast background uses `highlight`; buttons use `buttonBackground/buttonText`.
- Sheet uses standard sectioned form with `textSecondary` for metadata.

## Data Binding
- SyncManager provides a conflict payload `{ entityId, fields:[{key, local, remote, chosen}] , resolvedBy }`.
- Toast auto-dismiss after ~6–8s if untouched; Details remains until closed.

## Accessibility
- Toast reads “Sync conflict; last write wins; undo or see details”.

## Acceptance Checklist
- [ ] Toast shows only when a conflict occurs and auto-dismisses after a short delay.
- [ ] Details sheet lists field-level diffs with author/timestamps.
- [ ] Keep Remote/Local/Manual actions behave as described and re-sync.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** SearchView (Status Pills)
- **File:** Views/Main/SearchView.swift

## Purpose
Filter results by **multiple** statuses at once using pill chips. Chips display the count of active selections.

## Wireframe (ASCII, not code)
```text
Status:
[ Checked In ] [ In Progress ] [ Done ] [ PASS ] [ FAIL ] [ Completed ] [ Closed ]
( Active: 3 )                                      [ Clear ]
```

## Behaviors
- Tapping a pill toggles it on/off; multiple can be active.
- “Active: N” updates live; **Clear** deselects all pills.
- The results query includes any record whose status matches **any** selected pill.
- Pills persist during the session; optional: save to presets (see Saved Filters spec).

## Grid & Sizing Rules
- Pills wrap across lines; min height 32–36pt with rounded corners; spacing 8pt.
- On compact width, hide the “Active: N” label if space is tight.

## Visual Style (Theme-driven)
- Selected pill uses `highlight` fill with a stronger border; unselected uses subtle outline; text uses theme label color.
- No hex literals.

## Accessibility
- Each pill announces “Status filter: <name>, selected/not selected”.

## Acceptance Checklist
- [ ] Multiple pills can be active; “Active: N” updates correctly.
- [ ] Clear deselects all and re-runs the query.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** ManagerReviewView (Override History)
- **File:** Views/Manager/ManagerReviewView.swift
- **Related models:** WO_Item (partsUsed, hoursWorked, cost), WO_Status

## Purpose
Display a concise history of manager overrides to parts/hours/cost with attribution and timestamps.

## Wireframe (ASCII, not code)
```text
— Override History —
09:45  Parts: “Seals + wiper”  • Maria (manager)
09:46  Hours: 1.25 → 1.50      • Maria
09:46  Cost: 125.00 → 150.00   • Maria
```

## Merge Rules
- Show only fields that changed due to **manager override** actions from this view.
- For numeric fields, show `old → new`. For text, show the new summary (truncate to ~60 chars).
- Entries also emit a WO_Status line so they appear in NotesTimelineView.

## Visual Style (Theme-driven)
- Timestamp `textSecondary`; body text normal; subtle separators via `border`.

## Behaviors
- History collapses when empty.
- Optional “Show all” reveals older entries if list is truncated (>10).

## Accessibility
- Rows announce “Override: <field> changed from <old> to <new> by <user> at <time>”.

## Acceptance Checklist
- [ ] Only manager-driven overrides appear here.
- [ ] Each entry also emits a status line for the global timeline.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** ActiveWorkOrdersView (Flag/Priority Sort)
- **File:** Views/Main/ActiveWorkOrdersView.swift

## Purpose
Refine sorting so **flagged** items appear first, and within that group, apply a sensible priority (e.g., oldest first), then normal items (oldest first).

## Sort Rules
1) **Flagged group (top)**  
   - Primary: `isFlagged == true`  
   - Secondary: `timestamp` ascending (oldest first)  
   - Tertiary (optional): `waitTime` severity or custom priority field if present
2) **Unflagged group (below)**  
   - Primary: `timestamp` ascending (oldest first)

## Wireframe (ASCII, not code)
```text
— Flagged —
[ Card ]  (oldest flagged)
[ Card ]
— All Active —
[ Card ]  (oldest)
[ Card ]
```

## Visual Style (Theme-driven)
- “Flagged” section header uses `label` weight with `textSecondary`.
- Flag icon uses the existing glyph; no special color beyond theme.

## Behaviors
- If there are 0 flagged records, hide the section header.
- Tapping flag on a card immediately re-sorts into/out of the flagged section.

## Acceptance Checklist
- [ ] Flagged items group at top and re-sort live on toggle.
- [ ] Within each group, sorting is oldest→newest.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** WorkOrderCardSkeleton
- **File:** Views/Components/WorkOrderCardSkeleton.swift
- **Related models:** none (placeholder)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Show lightweight placeholders while WorkOrder cards are loading, avoiding layout shift.

## Wireframe (ASCII, not code)
```text
┌───────────────────────────────────────────────┐
│ [ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ ]                         │  (image area, 1:1)
│                                               │
│ ▒▒▒▒▒▒▒▒▒▒▒▒▒▒        ▒▒▒▒                    │  (name + small pill)
│ ▒▒▒▒▒▒▒▒      ▒▒▒▒▒▒▒▒▒▒                     │  (phone line)
│ ▒▒▒▒▒▒  ▒▒▒▒▒▒                                  (WO# + time)
└───────────────────────────────────────────────┘
```

## Grid & Sizing Rules
- Same size as real card: respects the adaptive width rules so the grid doesn’t jump.
- Use 2–4 skeleton cards per “page” load.

## Visual Style (Theme-driven)
- Use `highlight` blocks for skeletons; optional shimmer animation if available.
- No hex literals.

## Behaviors
- Replace skeletons with real cards as data arrives; fade transition 150–250ms.

## Acceptance Checklist
- [ ] Skeletons fill the same grid tracks as real cards (no layout shift).
- [ ] Fade-in transition when real data replaces them.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** NotesTimelineView (Inline Reply / @mention — Placeholder)
- **File:** Views/Components/NotesTimelineView.swift
- **Related models:** WO_Note

## Purpose
Reserve a small UI affordance for future inline replies and `@mentions` without changing current behavior.

## Wireframe (ASCII, not code)
```text
09:14  Note: Seals replaced • Joe        [ Reply ]  (future)
```

## Behaviors (placeholder only)
- Show a subtle **Reply** link on note rows; tapping currently opens the regular “Add Note” composer with an auto-inserted “@Joe: ” prefix (no threading yet).
- `@` typing hint: when user types `@`, pop a small user list (local names only) to insert a mention token into the note text (cosmetic; no notifications yet).

## Visual Style (Theme-driven)
- Links use `linkColor`; hints use `textSecondary`.

## Acceptance Checklist
- [ ] Reply link exists but uses current Add Note flow (no threads).
- [ ] Typing `@` offers names and inserts a token (cosmetic).
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** SearchView (Completed/Closed Filters)
- **File:** Views/Main/SearchView.swift

## Purpose
Allow users to search across **Completed** and **Closed** work orders with explicit toggles.

## Wireframe (ASCII, not code)
```text
Status scope:
[ Active ] [ Completed ] [ Closed ]      (multi-toggle)
```

## Behaviors
- Scope toggles act like independent filters:
  - **Active** → not Completed and not Closed
  - **Completed** → Completed (not Closed)
  - **Closed** → Closed
- Default = **Active** only. Users can enable multiple scopes (e.g., Completed+Closed).
- Works alongside the Status Pills (if both are present, intersect the results sensibly).

## Grid & Sizing Rules
- Toggles sit with other filters; wrap on narrow widths.

## Visual Style (Theme-driven)
- Selected toggle uses `highlight`; text uses normal label color.

## Accessibility
- Each toggle announces “Scope filter: Active/Completed/Closed, selected/not selected”.

## Acceptance Checklist
- [ ] Defaults to Active-only; enabling Completed/Closed modifies query as specified.
- [ ] Plays nicely with other filters (Status pills, Date).
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** WorkOrderCardView (Compact Mode)
- **File:** Views/Components/WorkOrderCardView.swift

## Purpose
Ensure card is readable and tappable on very narrow screens (e.g., iPhone SE) without overflow.

## Trigger
- When card width < **280pt**, switch to compact layout.

## Compact Wireframe (ASCII, not code)
```text
┌──────────────────────────────┐
│ [Thumb 1:1]  Customer Name   │
│ [Thumb]      (tap) Phone     │
│ [Thumb]      WO_Number • time│
│ [Thumb]                      │
└──────────────────────────────┘
```

## Rules
- Collapse 2×2 grid into a **single column** of up to 4 thumbs stacked left (44–56pt).
- Text stack on the right; phone becomes an icon button if needed.
- Keep minimum tap targets (≥ 44pt) for the whole card and the phone action.

## Visual Style (Theme-driven)
- Same tokens as full card; no hex literals.

## Acceptance Checklist
- [ ] No text truncation beyond reasonable ellipsis for name and WO_Number.
- [ ] All taps stay ≥ 44pt; phone remains accessible as icon or text.
- [ ] Theme tokens only.

---

## View / Component
- **Name:** DropdownManagerView (Drag Handle UX)
- **File:** Views/Admin/DropdownManagerView.swift

## Purpose
Make list reordering easy and accessible with clear drag handles and fallback up/down buttons.

## Wireframe (ASCII, not code)
```text
[ ⠿ ]  Cylinder        [ Edit ] [ Deactivate ]      [ ↑ ] [ ↓ ]
[ ⠿ ]  Pump            [ Edit ] [ Deactivate ]      [ ↑ ] [ ↓ ]
```

## Rules
- **Drag handle** (⠿) hit target ≥ 32×32pt; visible on the far-left.
- Provide **↑/↓** buttons as a fallback for keyboard/VoiceOver users.
- While dragging, the row shows a slight elevation and `highlight` background.

## Behaviors
- Dragging updates the in-memory order; **Save** persists to catalog in that order.
- ↑/↓ performs single-step swaps; disabled at boundaries.

## Accessibility
- Drag handle: “Reorder <value>” with rotor support if available.
- ↑/↓ announce “Move <value> up/down”.

## Acceptance Checklist
- [ ] Drag handle works with touch; ↑/↓ work with keyboard/VoiceOver.
- [ ] Save keeps new order reliably.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** TagBypassDialog
- **File:** Views/Components/TagBypassDialog.swift
- **Related models:** WorkOrder, WO_Item (tagBypassReason)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Allow a tech to proceed without scanning a tag by capturing a reason (when enforcement is off or temporarily bypassed).

## Wireframe (ASCII, not code)
```text
( Dialog )
Couldn’t scan a tag. Proceed without tag?

Reason (required):
[ Missing / damaged ]
[ Machine inaccessible ]
[ Customer declined ]
[ Other ............ ]

[ Cancel ]                      [ Continue without tag ]
```

## Behaviors
- Shows when tag enforcement is OFF or user taps “Bypass”.
- **Continue** requires a reason selection or text if “Other”.
- On continue:
  - Do **not** create a `TagBinding` for this item
  - Set `items/{itemId}.tagBypassReason = <reason>`
  - Append a WO_Status note (“Tag scan bypassed — <reason>”) at the order level for audit

## Visual Style (Theme-driven)
- Buttons/toggles use theme tokens; helper text uses `textSecondary`.

## Accessibility
- Dialog reads: “Proceed without tag; reason required”.

## Acceptance Checklist
- [ ] Dialog appears only when enforcement off or bypass chosen.
- [ ] Continue blocked until a reason is present.
- [ ] Bypass writes a status note and stores the reason.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** WorkOrderDetailView (Overflow Actions)
- **File:** Views/Main/WorkOrderDetailView.swift
- **Related models:** WorkOrder, WO_Status
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Offer role-gated actions in the overflow (“…”) menu: **Mark Completed** and **Mark Closed** with confirmations.

## Wireframe (ASCII, not code)
```text
[ ... ]  →  Mark Completed
		   Mark Closed
```

## Behaviors
- **Mark Completed (Tech/Manager/Admin/SuperAdmin):**
  - Confirm: “Mark this WorkOrder Completed? It will move to Completed.”
  - Write WO_Status: “Completed” (user + timestamp).
  - Update list membership (appears in Completed).
- **Mark Closed (Any role, but only visible where allowed per PRD UI):**
  - Confirm: “Mark Closed? It will move out of Active. Only Admin/Manager can view/reopen.”
  - Write WO_Status: “Closed” (user + timestamp).
  - Update list membership (hidden from Active; visible to Admin/Manager sections).

## Visual Style (Theme-driven)
- Confirm dialogs/buttons use theme tokens; no hex literals.

## Acceptance Checklist
- [ ] Completed action available to all listed roles; moves record to Completed.
- [ ] Closed action behavior matches PRD (hidden from Active, Admin/Manager can view). 
- [ ] Both actions write a status entry with user+timestamp.
- [ ] Theme tokens only; no hex literals.
- [ ] Item rows display **StatusBadge** per WO_Item; no indicator dots appear in this view.

---

## View / Component
- **Name:** SyncStatusView (Error Details)
- **File:** Views/Admin/SyncStatusView.swift
- **Related models:** SyncManager queue items
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Let users expand a failed row to see a short error summary, last attempt time, and a suggestion, without leaving the page.

## Wireframe (ASCII, not code)
```text
[ UP ] WO 240904-013  delta:notes  status: failed ✕   [ Retry ]
	   ▼ Details
	   Error: permission-denied
	   When: 2:41 PM
	   Suggestion: Check Firestore rules / user role
```

## Behaviors
- Tap “Details” toggles the row’s expanded area.
- Show **Error**, **When**, and a **Suggestion** string provided by SyncManager (or derived).
- Retry button re-enqueues; if it succeeds, the row collapses automatically.

## Visual Style (Theme-driven)
- Expanded area uses `highlight` background and `textSecondary` for labels.

## Acceptance Checklist
- [ ] Failed rows can expand/collapse to show details.
- [ ] Retry acts from within the row; on success, row updates state and collapses.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** SearchView (Date Range)
- **File:** Views/Main/SearchView.swift

## Purpose
Provide a flexible date-range filter with quick presets and a custom range.

## Wireframe (ASCII, not code)
```text
Date:
[ Today ] [ 7 days ] [ 30 days ] [ This Month ] [ Custom ▾ ]

If Custom:
From [ 2025-09-01 ]  To [ 2025-09-30 ]     [ Apply ]
```

## Behaviors
- Selecting a preset applies immediately and re-runs the query.
- Choosing **Custom** reveals date pickers and an **Apply** button.
- Date filter combines with other filters (Status, scope, etc.).
- Clear the date filter by tapping the active preset again or a small [✕] on the “Date” chip.

## Grid & Sizing Rules
- Presets wrap on narrow widths; custom range appears inline below the presets.

## Visual Style (Theme-driven)
- Active preset uses `highlight`; text uses normal label color.

## Accessibility
- Date pickers labeled; Apply button announces the chosen range.

## Acceptance Checklist
- [ ] Presets apply immediately; Custom requires Apply.
- [ ] Clearing date resets the filter and re-runs the query.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** SearchView (Tag & Tag History)
- **Related models:** WO_Item (`tags: [TagBinding]`, `tagHistory: [TagHistory]`)

## Purpose
Make tag searches resolve both **active bindings** and **previous** tag IDs (via history).

## Behaviors
- When the **Tag ID** filter is filled:
  1. Query **active** bindings where any `tags[*].tagId == input` and `tags[*].isActive == true`.
  2. Also query **history** where any `tagHistory[*].tagId == input`, then resolve to the **current** WO_Item owner.
- Results **deduplicate** by the resolved WO_Item id.
- UI shows a small hint when a match came via history:
  - “Matched via previous tag”

## Visual Style (Theme-driven)
- Hint text uses `textSecondary`; small chain arrow glyph allowed.

## Acceptance Checklist
- [ ] Tag searches include current and historical IDs.
- [ ] Historical matches resolve to the current WO_Item and dedupe.
- [ ] History hint line appears only for historical matches.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** WorkOrderCardView (Long Name Overflow)
- **File:** Views/Components/WorkOrderCardView.swift

## Purpose
Ensure extremely long customer names don’t break the card; use graceful truncation and multi-line fallback.

## Rules
- Default: **single line** with middle-truncation if width is tight.
- If card width ≥ 320pt and name length > ~28–32 chars, allow **two lines** max with end-truncation.
- Keep badge/flag alignment stable; phone line never wraps to more than one line.

## Wireframe (ASCII, not code)
```text
┌───────────────────────────────────────────────┐
│ [Thumbs]  Acme Hydraulic & Pneumatic Supply of Southw…  [▲] │
│           (tap) Phone                                   │
│           WO_Number • time                               │
└──────────────────────────────────────────────────────────┘
```

## Acceptance Checklist
- [ ] Names truncate (middle on 1-line, end on 2-line fallback) without layout break.
- [ ] Phone/status/WO lines remain single-line and aligned.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** NotesTimelineView (Glyph Legend)
- **File:** Views/Components/NotesTimelineView.swift

## Purpose
Provide an optional, collapsible legend explaining status glyphs so techs can learn them quickly.

## Wireframe (ASCII, not code)
```text
[ ? Legend ]  (tap to expand/collapse)

✓  Completed / Pass
▶  In Progress
!  Fail / Problem
💬 Note
```

## Behaviors
- Hidden by default; the `[ ? Legend ]` link toggles the legend panel.
- Persist the collapsed/expanded state locally so users don’t have to reopen it each time.

## Visual Style (Theme-driven)
- Legend text uses `textSecondary`; panel uses subtle `highlight` background.

## Acceptance Checklist
- [ ] Legend panel toggles open/closed and persists state locally.
- [ ] Glyph-to-meaning mapping matches StatusBadge semantics.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** CustomersCSVImport
- **File:** Views/Main/CustomersView.swift (Import flow surfaced here)
- **Related models:** Customer
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Import many customers at once from a CSV with clear validation, preview, and safe upsert rules.

## Entry Point (UI)
- **CustomersView** toolbar: `[ ••• ] → Import CSV…`
- Opens an **Import Wizard** (3 steps): **Upload → Review → Import**

## CSV Format
- **Encoding:** UTF-8 with header row.
- **Delimiter:** comma (`,`). Quote char `"` supported.
- **Header (exact keys, case-insensitive, extra columns ignored):**
  - `name` *(required)*
  - `phone` *(required, unique key; can contain punctuation/spaces)*
  - `company` *(optional)*
  - `email` *(optional)*
  - `taxExempt` *(optional; true/false/1/0/yes/no)*
  - `emojiTag` *(optional; single emoji)*

### Sample CSV
```csv
name,phone,company,email,taxExempt,emojiTag
Maria Lopez,(239) 555-1234,,maria@example.com,yes,🔧
Acme Hydraulics,239-555-8899,Acme Inc.,ops@acme.com,false,⭐️
John Smith,2395557777,,,0,
```

## Normalization Rules
- **phone:** strip all non-digits; keep last 10 digits for US (or your app’s expected length).  
  - If result not 10 digits → **invalid**.
- **email:** lowercase; must match simple email regex → else **invalid** or **empty**.
- **taxExempt:** map `true/1/yes/y` → `true`; `false/0/no/n` → `false`; empty → default `false`.
- **emojiTag:** keep **first grapheme** only; if multi-char, trim to first; if empty → nil.
- **name/company:** trim whitespace; collapse double spaces; name must remain non-empty.

## Keying & Upsert Strategy
- **Primary key:** `phone` (post-normalization).
- **If phone already exists:** **update** existing customer with provided non-empty fields (leave unspecified fields unchanged).
- **If phone new:** **create** a new customer.

## Step 1 — Upload
- File picker (CSV only). Read first ~200 rows to **quick-parse** headers.  
- If headers missing `name` or `phone` → show blocking error.

## Step 2 — Review (Preview Grid)
- Show a table with columns: **Status**, Name, Phone (normalized), Company, Email, TaxExempt, Emoji.
- **Status badges per row:**
  - **Create** (new phone)
  - **Update** (existing phone)
  - **Error** (invalid phone/email/emoji or missing name)
- **Row actions:** Fix inline (edit fields), or **Skip** row.
- **Counters:** “Ready to create: X, ready to update: Y, errors: Z (must fix/skip).”

## Validation Errors (Examples)
- Phone not 10 digits → “Invalid phone”
- Name empty → “Name required”
- Emoji not a single grapheme → “Emoji must be one symbol”
- Email invalid → “Invalid email”
> Rows marked **Error** cannot be imported until fixed or skipped.

## Step 3 — Import (Commit)
- Disable button while **any** Error rows remain.
- Perform in **batches** (e.g., 100 rows per batch):
  - For each row: upsert Customer (Firestore + local cache).
- Show progress bar (rows imported / total).
- **Summary toast/dialog** on completion:
  - “Created: X, Updated: Y, Skipped: Z, Failed: N (Download log)”
- **Download log**: CSV of failed rows with `errorReason` appended.

## Visual Style (Theme-driven)
- Badges/buttons use theme tokens (`buttonBackground`, `buttonText`, `highlight`, `textSecondary`).
- No hex literals.

## Accessibility
- Preview table rows have combined labels: “Create/Update/Error, <name>, phone <digits>”.
- Progress updates are announced politely.

## Acceptance Checklist
- [ ] CSV with required headers loads and previews; missing headers block import.
- [ ] Phone normalization and email validation enforced; emoji trimmed to first grapheme.
- [ ] Upsert by phone: existing → update non-empty fields; new → create.
- [ ] Errors must be fixed or skipped before import proceeds.
- [ ] Progress, final summary, and downloadable error log provided.
- [ ] Theme tokens only; no hardcoded hex.

---

## Snippet — Utilities/String+Phone.swift (helper)

/// Normalizes a phone-like string to US 10 digits (returns nil if impossible).
/// Examples:
///   "(239) 555-1234"  -> "2395551234"
///   "1-239-555-1234"  -> "2395551234"  (drops leading country '1')
///   "239.555.1234"    -> "2395551234"
func normalizeUSPhone(_ raw: String) -> String? {
	let digits = raw.compactMap { $0.isNumber ? $0 : nil }.map(String.init).joined()
	if digits.count == 11, digits.first == "1" { return String(digits.dropFirst()) }
	guard digits.count == 10 else { return nil }
	return digits
}

/// Formats a 10-digit string to "(XXX) XXX-XXXX" for display.
func formatUSPhonePretty(_ tenDigits: String) -> String {
	guard tenDigits.count == 10 else { return tenDigits }
	let a = tenDigits.prefix(3)
	let b = tenDigits.dropFirst(3).prefix(3)
	let c = tenDigits.suffix(4)
	return "(\(a)) \(b)-\(c)"
}

---

## View / Component
- **Name:** SearchView (Phone Parsing)
- **File:** Views/Main/SearchView.swift

## Purpose
Treat phone input flexibly; normalize before querying.

## Behaviors
- When user types into **Name/Phone**:
  - If input looks phone-like (≥ 7 digits mixed with symbols), run `normalizeUSPhone`.
  - If result is 10 digits, search by normalized phone **OR** by pretty format; otherwise treat as name.
- Display phones in results using `formatUSPhonePretty`.

## Acceptance Checklist
- [ ] Phone-like inputs normalize before query; name-like inputs do fuzzy name search.
- [ ] Result list displays pretty-formatted numbers.

---

## View / Component
- **Name:** OfflineBanner
- **File:** Views/Components/OfflineBanner.swift
- **Related models:** SyncManager (connectivity status)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Show a small, non-blocking banner when the device is offline and actions will queue.

## Wireframe (ASCII, not code)
```text
( Banner pinned to top or below nav bar )
You’re offline. Changes will sync when connection returns.   [ Dismiss ]
```

## Behaviors
- Appears when SyncManager says “offline”; hides when back online.
- **Dismiss** hides banner for the session but will reappear after app restart if still offline.
- No blocking; all forms remain usable (queue writes locally).

## Visual Style (Theme-driven)
- Background uses `highlight`; text uses normal label color; small close (×) tap target ≥ 32pt.

## Accessibility
- Banner announces “Offline; changes will sync later”.

## Acceptance Checklist
- [ ] Appears only when offline; hides when online.
- [ ] Dismiss works for session; non-blocking behavior preserved.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** BulkImportView (Customers CSV)
- **File:** Views/Admin/BulkImportView.swift
- **Related models:** Customer
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Admin/SuperAdmin can import many customers from CSV with normalization, preview, and safe upsert.

## Wireframe (ASCII, not code)
```text
Step 1 — Upload
[ Drop CSV here ]  [ Choose File ]           (accept .csv)

Step 2 — Review
[ Status ] [ Name ] [ Phone (normalized) ] [ Company ] [ Email ] [ TaxExempt ] [ Emoji ]
[ Create ]  Maria     2395551234              ...         ...        true         🔧   [ Fix ] [ Skip ]
[ Update ]  Acme      2395558899              ...         ...        false        ⭐️   [ Fix ] [ Skip ]
[ Error ]   John      invalid                  ...         ...        ...          ..   [ Fix ] [ Skip ]

Ready: Create X • Update Y • Errors Z

Step 3 — Import
Progress: [████████░░]  73%     [ Cancel ]
Summary: Created X, Updated Y, Skipped Z, Failed N  [ Download Log ]
```

## Behaviors
- Three-step wizard: **Upload → Review → Import**.
- Review grid supports inline **Fix** (lightweight editors) and **Skip**.
- Import runs in batches; summary displayed with optional failure log download.

## Data Binding
- CSV parsed client-side; normalization (phone/email/emoji) applied before preview.
- Upsert key = normalized phone.

## Acceptance Checklist
- [ ] Upload rejects missing headers; Review blocks import until errors fixed/skipped.
- [ ] Normalization applied consistently; summary & failure log produced.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** NotesTimelineView
- **File:** Views/Components/NotesTimelineView.swift
- **Related models:** WO_Status, WO_Note
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Merge and render status updates + notes in a single, readable timeline.

## Wireframe (ASCII, not code)
```text
— Today —
09:30  ✓ Completed                    • Joe
09:26  Parts: seals; Hours: 1.0       • Joe
09:25  ✓ Tested: PASS                 • Joe
09:14  💬 Note: Seals replaced        • Joe
08:12  ▶ In Progress                  • Joe

— Yesterday —
16:02  💬 Note: Customer called       • Maria
```

## Rules
- Merge `[WO_Status] + [WO_Note]` by timestamp ascending; insert day headers (Today/Yesterday/MMM d).
- Status rows show glyph + label; include `notes` if present.
- Author suffix: `• <user>`; wrap long lines; comfortable vertical spacing.

## Behaviors
- Optional “Load more” on large histories (fetch in pages).
- Optional “Reply” link (future-proof; opens Add Note composer with prefilled `@user`).

## Acceptance Checklist
- [ ] Correct chronological merge with day headers.
- [ ] Status + note rows styled distinctly; author shown.
- [ ] Large lists paginate cleanly; theme tokens only.

---

## View / Component
- **Name:** AuditLogView
- **File:** Views/Admin/AuditLogView.swift
- **Related models:** AuditLog, TagHistory  <!-- supersedes legacy TagReplacement -->
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Admin/Manager visibility into sensitive changes: tag reassignments, deletions, schema bumps.

## Wireframe (ASCII, not code)
```text
[ Back ]  Audit Log                         [ Filter ▾ ] [ Export CSV ]

Time        Actor   Type            Summary
09:52 AM    Maria   Tag Reassign    TAG-A123 → TAG-B987 (WO 250904-012)
09:40 AM    Sam     Schema Bump     Dropdown v1 → v2 (Reasons)
09:18 AM    Joe     Deletion        WO 250903-007 soft-deleted
```

## Behaviors
- Filters by type/date/actor; export visible rows to CSV.
- Selecting a row deep-links to the related WO / catalog page when applicable.

## Acceptance Checklist
- [ ] Lists tag reassignments, deletions, schema bumps with time/actor.
- [ ] Filters and CSV export function correctly.
- [ ] Theme tokens only; no hex literals.

---

## Patch — SyncStatusView (Row States)

## Wireframe (ASCII, not code)
```text
[ UP ] WO 240904-013  payload: notes     status: failed ✕   [ Retry ]
	  ▼ Details
	  Error: permission-denied
	  When: 2:41 PM
	  Suggestion: Check rules/role

[ UP ] WO 240904-012  payload: images(2) status: pending …   [ Cancel ]
[ DN ] Catalog v2     payload: dropdowns status: complete ✓
```

## States
- **pending …** (spinner), **failed ✕** (expandable details), **complete ✓** (dimmed).
- Actions: Retry (failed), Cancel (pending uploads only).

## Acceptance Checklist
- [ ] Visual/state differences are obvious; details expand only for failed.
- [ ] Retry/Cancel wired to the queue; state updates live.
- [ ] Theme tokens only.

---

## View / Component
- **Name:** ClosedWorkOrdersView
- **File:** Views/Main/ClosedWorkOrdersView.swift
- **Related models:** WorkOrder
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Read-only archive of **Closed** WorkOrders (hidden from Active). Managers/Admins can reopen.

## Wireframe (ASCII, not code)
```text
[ Back ]  Closed WorkOrders                      [ Search … ]

[ Card ]  (dim/archived)  Customer • WO_Number • Closed @ time   [ Reopen ]
[ Card ]  (dim/archived)  …
```

## Behaviors
- Cards are non-editable; **Reopen** (role-gated) moves to Active with status set appropriately.
- Search by name/phone/WO_Number.

## Acceptance Checklist
- [ ] Only Closed WOs appear; not Completed or Active.
- [ ] Reopen works for authorized roles; others see read-only.
- [ ] Theme tokens only; no hex literals.

---

## View / Component
- **Name:** EmojiPickerView
- **File:** Views/Components/EmojiPickerView.swift
- **Related models:** Customer (emojiTag)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Lightweight control to set a single emoji as the customer’s tag.

## Wireframe (ASCII, not code)
```text
[ ✕ ]  Pick an Emoji

[ 😀 😎 🔧 ⭐️ 🐝 🏷️ … ]  (grid, large cells)
[ Custom… ] (opens system emoji keyboard)

[ Remove ]          [ Save ]
```

## Rules
- Enforce **single extended grapheme**: if multiple entered, keep first grapheme.
- Large tap targets (≥ 44pt). Recent picks shown first.

## Behaviors
- **Save** returns selected emoji to caller; **Remove** clears tag; **✕** cancels.
- Used by CustomerDetailView and NewWorkOrderView summary card.

## Acceptance Checklist
- [ ] Only a single emoji is persisted; multi-character input trimmed.
- [ ] Remove clears tag; Save returns selected emoji.
- [ ] Theme tokens only; no hex literals.

---

---

## 🔧 Navigation Additions

### Admin Sidebar (additions)
```text
Sidebar (Admin)
├── ActiveWorkOrdersView
├── CompletedWorkOrdersView
├── ClosedWorkOrdersView      ← new
├── CustomersView
├── DeletedWorkOrdersView
├── DropdownManagerView (includes Reasons for Service)
├── UserManagerView
├── AuditLogView              ← new
├── SettingsView
└── SyncStatusView
```

### Manager Sidebar (unchanged)
```text
Sidebar (Manager)
├── ActiveWorkOrdersView
├── PendingApprovalView
├── ManagerReviewView
└── DropdownManagerView (read-only, Request Change)
```

## Acceptance Checklist
- [ ] Admin sidebar includes **ClosedWorkOrdersView** for archived WOs.
- [ ] Admin sidebar includes **AuditLogView** for tag reassignments/schema bumps.
- [ ] Manager sidebar unchanged (no Audit/Closed).
- [ ] Theme tokens only; no hex literals.

---

---

## 📑 Sidebar Wireframes

### Admin Sidebar (full access)

```text
┌──────────────────────────────┐
│   Hydraulics Work Orders      │
│ ──────────────────────────── │
│  Active WorkOrders            │
│  Completed WorkOrders         │
│  Closed WorkOrders   ← new    │
│  Customers                    │
│  Deleted WorkOrders           │
│  Dropdown Manager             │
│  User Manager                 │
│  Audit Log          ← new     │
│  Settings                     │
│  Sync Status                  │
└──────────────────────────────┘
```

### Manager Sidebar (limited)

```text
┌──────────────────────────────┐
│   Hydraulics Work Orders      │
│ ──────────────────────────── │
│  Active WorkOrders            │
│  Pending Approvals            │
│  Manager Review               │
│  Dropdown Manager (read-only) │
└──────────────────────────────┘
```

## Acceptance Checklist
- [ ] Admin sidebar shows **Closed WorkOrders** and **Audit Log** in correct order.
- [ ] Manager sidebar shows only limited items (no Audit Log, no Closed).
- [ ] Both use Apple Notes–style sidebar layout with theme tokens (`background`, `textPrimary`, `highlight`).

---

## View / Component
- **Name:** SidebarDrawerView (Compact Sidebar)
- **File:** Views/Components/SidebarDrawerView.swift
- **Related:** Admin/Manager sidebars (same items, but drawer form)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Provide a slide-in sidebar (hamburger) on compact width devices while preserving the Admin/Manager navigation structure.

## Invocation
- Each primary screen (Active/Completed/Customers/etc.) shows a **hamburger button** (`☰`) on the top-left of its `NavigationBar`.
- Tapping `☰`, swiping **from the left edge**, or invoking keyboard command (⌘\) opens the drawer.

## Dimensions & Layers
- **Width:** min(72% of viewport, 320pt), max 360pt.
- **Edge inset:** align to safe area; full height.
- **Scrim:** full-screen backdrop behind drawer; uses theme `highlight` at ~65% opacity.
- **zIndex:** drawer ≥ 1000; scrim just below (e.g., 999).

## Transitions & Gestures
- **Open/Close animation:** 180–220ms ease-out; translateX from −100% → 0.
- **Dismiss:** tap scrim, press `Esc`, or **drag** drawer ≤ −80pt and release.
- **Edge swipe:** from left bezel opens drawer (UIKit/SwiftUI gesture).

## Keyboard & Accessibility
- **Focus trap:** when open, focus cycles inside drawer; `Esc` closes.
- **VO order:** header → search (optional) → menu items → footer.
- **Labels:** menu items read as “Navigate to <label>”.

## Content (role-based)
- Inject the **same menu items** as the iPad sidebars (order identical). Examples:

**Admin**
```text
Active WorkOrders
Completed WorkOrders
Closed WorkOrders
Customers
Deleted WorkOrders
Dropdown Manager
User Manager
Audit Log
Settings
Sync Status
```

**Manager**
```text
Active WorkOrders
Pending Approvals
Manager Review
Dropdown Manager (read-only)
```

> If the app supports **badge counts** (e.g., Pending Approvals), render a small count pill on the right; use theme tokens.

## Wireframe (ASCII, not code)
```text
╔══════════════════════════════════════════════════════════════╗
║ ▓▓▓▓▓▓▓▓▓▓▓ SCRIM (tap to close) ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  ║
║ ▌┌────────────────────────────────────────────────────────┐  ║
║ ▌│  ☰  Hydraulics Work Orders                            │  ║
║ ▌│ ────────────────────────────────────────────────────  │  ║
║ ▌│  Active WorkOrders                                   │  ║
║ ▌│  Completed WorkOrders                                │  ║
║ ▌│  Closed WorkOrders                                   │  ║
║ ▌│  Customers                                           │  ║
║ ▌│  Deleted WorkOrders                                  │  ║
║ ▌│  Dropdown Manager                                    │  ║
║ ▌│  User Manager                                        │  ║
║ ▌│  Audit Log                                           │  ║
║ ▌│  Settings                                            │  ║
║ ▌│  Sync Status                                         │  ║
║ ▌└────────────────────────────────────────────────────────┘  ║
╚══════════════════════════════════════════════════════════════╝
```

## Visual Style (Theme-driven)
- Drawer background: `background`; section separators: `border`.
- Item text: `textPrimary` (selected item slightly bolder or with subtle `highlight` chip).
- Active row can use a thin left accent bar using `linkColor` (no hex literals).

## Behaviors
- **Navigation:** tapping an item closes the drawer then routes.
- **State restore:** drawer remembers **last selected** section for visual highlight.
- **Deep-link:** if a screen is opened via deep link, highlight matching item.
- **Search (optional):** if you add a search field at top, it filters items client-side.

## Acceptance Checklist
- [ ] Drawer opens via hamburger, edge swipe, and keyboard shortcut; closes via scrim tap, `Esc`, or drag.
- [ ] Width respects min(72% viewport, 320pt) and max 360pt; safe-area compliant.
- [ ] Role-based menus exactly mirror iPad sidebars (same order/items).
- [ ] Focus is trapped while open; `Esc` closes; VO labels are correct.
- [ ] zIndex/scrim ensure drawer sits above content; no interaction leaks through.
- [ ] Theme tokens only; no hardcoded hex.

---

## View / Component
- **Name:** NavBarHamburgerButton
- **File:** Views/Components/NavBarHamburgerButton.swift
- **Related:** SidebarDrawerView (Compact Sidebar)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Provide a consistent left-side navigation trigger on compact width screens.

## Placement & Size
- **Placement:** leading side of the NavigationBar for all primary screens.
- **Icon:** `☰` (or SF Symbol `line.3.horizontal` if preferred).
- **Icon size:** 18–22pt; **tap target:** ≥ 44×44pt with generous insets.

## States
- **Default:** normal.
- **Pressed:** subtle opacity change; no color hex — use theme.
- **Hidden:** when drawer is open, the button can transform into a “Close” (✕) button or remain and do nothing (pick one and stick with it).

## Behaviors
- Tap → toggles SidebarDrawerView open/closed.
- Long-press (optional): show quick nav menu (same items, flat list).
- Keyboard shortcut (optional): **⌘\\** toggles the drawer.

## Accessibility
- `accessibilityLabel("Open sidebar")` or “Close sidebar” when open.
- Hit target remains ≥ 44×44pt even when icon is small.

## Acceptance Checklist
- [ ] Appears on compact width screens; aligned leading in the nav bar.
- [ ] Tap target ≥ 44×44pt; accessibility labels switch correctly.
- [ ] Uses theme tokens for pressed/hover feedback; no hex literals.
- [ ] Taps toggle the SidebarDrawerView reliably without interfering with page content.

---

## View / Component
- **Name:** NavBarSettingsButton
- **File:** Views/Components/NavBarSettingsButton.swift
- **Related:** SettingsView (Admin/SuperAdmin)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Offer a consistent entry to Settings on **regular/wide** size classes without opening the sidebar.

## Placement & Size
- **Placement:** trailing side of the NavigationBar on iPad/wide layouts.
- **Icon:** gear (SF Symbol `gearshape`).
- **Icon size:** 18–22pt; **tap target:** ≥ 44×44pt with insets.

## Visibility
- **Roles:** Admin/SuperAdmin only.
- **Size class:** Regular width only (hide on compact — users use the sidebar drawer there).

## Behaviors
- Tap → navigates to SettingsView.
- Long-press (optional): quick menu for Settings subsections (Dev toggles, Sync).

## Accessibility
- `accessibilityLabel("Open settings")`.

## Acceptance Checklist
- [ ] Appears only for Admin/SuperAdmin on regular width.
- [ ] Tap target ≥ 44×44pt; uses theme tokens for feedback.
- [ ] Routes to SettingsView reliably.

---

## View / Component
- **Name:** NavBarOverflowButton
- **File:** Views/Components/NavBarOverflowButton.swift
- **Related:** Screens with extra actions (e.g., WorkOrderDetailView)
- **Theme:** AppleNotes_Style_YellowTheme (Resources/AppleNotesYellow.json)

## Purpose
Provide a consistent overflow menu (ellipsis) for secondary actions on a screen.

## Placement & Size
- **Placement:** trailing side of the NavigationBar.
- **Icon:** ellipsis (SF Symbol `ellipsis.circle` or `ellipsis` in a Button).
- **Icon size:** 18–22pt; **tap target:** ≥ 44×44pt.

## Behaviors
- Tap → opens a popover or action sheet with screen-specific actions.
- Actions **role-gated** and consistent with PRD (e.g., Mark Completed/Closed on WorkOrderDetailView).
- Dismiss on outside tap, Esc, or action selection.

## Accessibility
- `accessibilityLabel("More actions")`.

## Acceptance Checklist
- [ ] Appears where needed; opens a role-gated action list.
- [ ] Tap target ≥ 44×44pt; uses theme tokens; no hex literals.
- [ ] Dismiss behavior is consistent and reliable.

### List Membership Rules (Completed vs Closed)
- **Active**: `!isCompleted && !isClosed && !isDeleted`
- **Completed**: `isCompleted && !isClosed && !isDeleted` (cards appear grayed)
- **Closed**: `isClosed && !isDeleted` (hidden from Active; shown only in ClosedWorkOrdersView)