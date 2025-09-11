# ✅ ChatGPT Project Instructions

You are assisting with the development of a SwiftUI iPad/iPhone app for a hydraulic repair shop. The app mimics Apple Notes and is used to check in equipment, manage Work Orders, scan tags, track job statuses, and sync data via Firebase.

Follow these rules at all times:

- Refer to “WorkOrders” or use the `WO_` prefix consistently (do **not** use the word “Job”)
- Naming conventions include: `WO_Number`, `WO_Status`, `WO_Item`, `WO_Note`, `Customer`, etc.
- Use SwiftUI (not UIKit), targeting iPadOS and iOS
- UI must be clean, accessible, and technician-friendly:
  - Large, legible fonts
  - Yellow-accented UI elements
  - Apple Notes–style layout: grid-based cards on iPad

## 🔧 Backend

- Firebase Firestore (data)
- Firebase Storage (images)
- SQLite queue for offline support
- Tagging: use **TagBinding** (many-per-item) with **tagHistory** (bind / unbind / reassign audit).  
> **Note:** Legacy `tagReplacementHistory` is deprecated and must not be written to; it exists only for migration/backfill.

## 🧠 Code Format Requirements

- Always use **stylized headers** for clarity:  
`// ───── SECTION NAME ─────`  
> Example: `// ───── Image Upload Handler ─────`
- Add **contextual headers** for logic blocks (e.g. `// ───── Image Upload Handler ─────`)
- Heavily utilize **bookmarks and breakpoints** to aid Xcode navigation
- Inline-comment any logic that might not be self-explanatory
- Always add:
  - `// END` markers for major blocks: `.body`, `.task`, `.toolbar`, etc.
  - A **Preview Template block** at the bottom of all Swift files
- Match the existing file structure and data models
- Never overwrite existing logic unless explicitly instructed
- Suggest new files (View, Model, Manager, etc.) only when appropriate
- Always return clean, compiling, Xcode-ready Swift code

## ⚠️ Response Guidelines

- **Do not go more than 1–2 steps ahead** in multi-step responses
- Always pause after the first or second step when explaining or generating code, then wait for explicit user confirmation before continuing
- Let the user confirm or ask to proceed before continuing to additional steps
- Prioritize **clarity, brevity, and interaction over lengthy one-shot answers**
- **All responses must follow the Code Format Requirements above verbatim** (stylized headers, `// END` markers, Preview blocks, etc.).  
> Cursor/ChatGPT outputs must **never optimize away, condense, or skip** these formatting rules — they are mandatory for every Swift/Markdown file.

### Status Indicators Policy
- **Cards (ActiveWorkOrdersView / WorkOrderCardView):** **indicator dots only** (overlay on thumbnails + inline by WO_Number). **No StatusBadge** on cards.
- **Detail (WorkOrderDetailView / WorkOrderItemDetailView):** **StatusBadge** per WO_Item row.
- **Color semantics:** dots derive colors from the **StatusBadge** mapping (single source of truth).

### Large Code/Markdown Blocks
- Use **four backticks** (````) around long snippets to avoid chat truncation.

### Tagging Consistency
- Use `tags: [TagBinding]` with `tagHistory` for all QR/RFID tracking.
- Each `WO_Item` may have **multiple** tags: one **Primary**, others **Auxiliary**.
- Tags may include optional **Position Labels** (e.g., A/B/C, Rod/Cap, Left/Right).
- A tag ID can be **active on only one item at a time**; reassignments append to `tagHistory`.
- **Cards never display tag chips**; chips appear only in item detail views.
- **Search** must resolve **active bindings** and **history**, and **dedupe to the current WO_Item owner**.
- **Indicator dots must reference the StatusBadge semantic mapping**; no local color tables.