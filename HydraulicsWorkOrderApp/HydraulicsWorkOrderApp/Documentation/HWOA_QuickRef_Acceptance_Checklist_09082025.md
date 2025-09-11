# 🧾 Hydraulics Work Order App — Developer Quick Reference  
*(Acceptance Checklist Condensed)*  
**Date:** Sept 8, 2025

---

## 🔄 Tagging
- Use `tags: [TagBinding]` + `tagHistory` for all QR/RFID.  
- One Primary per item; others Auxiliary.  
- Optional Position Labels (preset/free text).  
- A tag ID can only be active on **one WO_Item** at a time.  
- All bind/unbind/reassign events → `tagHistory(event: …)`.  
- **Legacy `tagReplacementHistory` deprecated**.  
- Search = active + history; dedupe → current owner; show “matched via history” hint.

---

## 🖼 Status Indicators
- **Cards:** dots only (overlay + inline).  
- **Detail:** StatusBadge per WO_Item.  
- Dot colors reference StatusBadge mapping (no local hex).  

---

## 👤 Customer
- First field = lookup (name/phone).  
- + Add New Customer → modal (prefilled typed value).  
- `emojiTag` optional (single grapheme).  
- Emoji shows on card, detail header, lookup, search filter.  
- Absent emoji → no gap.

---

## 🧩 Work Order Intake
- **Header (WorkOrder):** Customer, Flag, WO_Number.  
- **Items (WO_Item):**  
  - At least one image.  
  - Dropdowns: type, size (if Cylinder), color (name+hex, “Other” → picker), brand, waitTime.  
  - Reasons: multi-select; “Other” → requires non-empty `reasonNotes`.  
  - Notes/images inline.  
- Status auto = Checked In.

---

## 🧑‍🔧 Status & Tests
- Flow: New → Checked In → In Progress → Done → Tested → Completed → Closed.  
- PASS = requires Parts/Hours/Cost before completion.  
- FAIL:  
  - 1st = log only.  
  - 2nd = PROBLEM CHILD (flag + push to Managers).  
  - Notify previous updater if different tech.

---

## 👨‍💼 Manager/Admin
- **PendingApprovalView:** PROBLEM CHILD + pending tag reassignments.  
- **ManagerReviewView:** approve/deny, override parts/hours/cost.  
  - Tag reassignment = deactivate old, activate new, append `tagHistory(event:"reassigned")`.  
- **AuditLogView:** tag reassignments, deletions, schema bumps; export CSV.  

---

## 📝 Notes & History
- WorkOrder-level notes: `/workOrders/{woId}/workOrderNotes`.  
- Item-level notes: `/items/{itemId}/itemNotes`.  
- Timeline merges notes + statusHistory; shows day headers.  
- Tag events may appear in timeline.

---

## 🔎 Search
- Inputs: name, phone, WO_Number, tag ID (active + history), status, emoji.  
- Scope toggles: Active / Completed / Closed.  
- Status Pills: multi-select.  
- Dedupes to current owner; “matched via history” hint for old tags.

---

## 🗃 Sync & Storage
- Firebase Firestore + Storage primary.  
- SQLite: offline queue + backup.  
- SyncManager: retry, conflict resolution (last-write-wins + toast).  
- WorkOrder.finalCost = computed sum of item.finalCost (UI never writes directly).  
- Indexes: My Work Items, tag lookups, cost sorting.

---

## 📋 Dev/Response Guidelines
- **Swift files must include:**  
  - Stylized headers (`// ───── SECTION NAME ─────`)  
  - Inline comments, bookmarks  
  - `// END` markers for `.body`, `.task`, `.toolbar`  
  - Preview block at bottom  
- Responses: pause after 1–2 steps, wait for user confirmation.  
- **Never optimize away formatting rules** (Cursor/ChatGPT must preserve them).

---

## ✅ Quick Acceptance
- Terminology unified: **Tag Reassignment** everywhere.  
- “Other” → explicit `reasonNotes`.  
- Indicator dots vs StatusBadge enforced.  
- Legacy fields deprecated but noted.  
- All docs + build plan aligned; implementation-ready.