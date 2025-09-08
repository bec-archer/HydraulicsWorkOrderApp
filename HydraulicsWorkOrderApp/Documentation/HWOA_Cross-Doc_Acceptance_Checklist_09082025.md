# ✅ Final Cross-Doc Acceptance Checklist — Hydraulics Work Order App

This single-page checklist confirms that **all major documents are consistent** (Schema, PRD, LayoutSpec, Workflow Narratives, Navigation Flow, Dev Checklist, Test Cases, Project Instructions, Dropdown Template, Build Plan).

---

## 🔄 Tagging Model
- ✅ Use `tags: [TagBinding]` + `tagHistory` for all QR/RFID tracking.  
- ✅ One Primary tag per item; others Auxiliary.  
- ✅ Optional Position Labels allowed (preset or free text).  
- ✅ A tag ID may be active on only one WO_Item at a time.  
- ✅ All bind/unbind/reassign events append to `tagHistory`.  
- ✅ Legacy `tagReplacementHistory` is **deprecated**, read-only for migration/backfill.  
- ✅ Search resolves active + history, dedupes to current owner, shows “matched via history” hint.

---

## 🖼️ Status Indicators
- ✅ **Cards:** indicator dots only (overlay on thumbnails + inline by WO_Number).  
- ✅ **Detail views:** StatusBadge per WO_Item row; no dots.  
- ✅ Colors derive from the StatusBadge semantic mapping (single source of truth).  
- ✅ No local color tables or hex literals.  

---

## 👤 Customer & Emoji
- ✅ Customer lookup: live search by name/phone, +Add New Customer if none.  
- ✅ Emoji tag (`emojiTag`) optional, single grapheme; editable in CustomerDetailView & NewWorkOrderView summary card.  
- ✅ Emoji appears in Card, Detail header, Lookup results, and Search filter.  
- ✅ Absence collapses spacing (no empty gap).  

---

## 📥 Intake & WO_Item
- ✅ NewWorkOrderView: header has only Customer, Flag, WO_Number.  
- ✅ Inline AddWOItem forms (at least one by default, +Add Item appends).  
- ✅ Dropdowns: type, size (if cylinder), color (name+hex, “Other” → ColorPicker), brand, waitTime.  
- ✅ Reasons for Service: multi-select; “Other” requires non-empty `reasonNotes`.  
- ✅ Each WO_Item must have at least one image.  
- ✅ Status auto-marked “Checked In” on save.  

---

## 🧑‍🔧 Status / Test Logic
- ✅ Status progression: New → Checked In → In Progress → Done → Tested → Completed → Closed.  
- ✅ PASS requires parts/hours/cost before completion.  
- ✅ FAIL: 1st = log only; 2nd = PROBLEM CHILD flag + manager review.  
- ✅ Previous updater notified if FAIL entered by a different tech.  

---

## 👨‍💼 Manager/Admin Flows
- ✅ PendingApprovalView shows PROBLEM CHILD and pending tag reassignments.  
- ✅ ManagerReviewView allows decisions + overrides; tag reassignments append `tagHistory(event:"reassigned")`.  
- ✅ AuditLogView lists tag reassignments, deletions, schema bumps; exportable to CSV.  

---

## 📑 Notes & History
- ✅ WorkOrder-level notes at `/workOrders/{woId}/workOrderNotes`.  
- ✅ Item-level notes at `/items/{itemId}/itemNotes`.  
- ✅ Timeline merges notes + statusHistory; sorted with day headers.  
- ✅ Tag binding/unbinding events may appear in timeline.  

---

## 🔎 Search
- ✅ Inputs: name, phone, WO_Number, tag ID (active + history), status, emoji filter.  
- ✅ Supports Completed/Closed scope toggles and Status Pills.  
- ✅ Dedupes to current owner; historical matches flagged with hint.  

---

## 🗃️ Sync & Storage
- ✅ Firebase Firestore primary; Firebase Storage for images; SQLite offline queue + backup.  
- ✅ SyncManager: retry logic, offline queue, conflict resolution (last-write-wins + toast).  
- ✅ WorkOrder.finalCost = computed roll-up of item.finalCost; never written directly by UI.  
- ✅ Indexes defined for “My Work Items,” cost sorting, tag lookups.  

---

## 📦 Build Plan Alignment
- ✅ All required models, managers, and views are planned and accounted for in the Build Plan phases (models in Phase 2, intake UI in Phase 3, detail/status views in Phase 4, admin/manager tools in Phase 5, QA in Phase 6).  
- ✅ AuditLog.swift and AuditLogView.swift required deliverables.  
- ✅ Phase 6 QA tasks: tag search (active + history, dedupe, hint), offline queue, sync retries.  

---

## 🧾 Developer & Response Guidelines
- ✅ Code Format Requirements: stylized headers, contextual headers, inline comments, // END markers, Preview block in every Swift file.  
- ✅ Response Guidelines: pause after 1–2 steps, wait for user confirmation, do not condense or skip formatting.  
- ✅ Cursor/ChatGPT must follow these rules verbatim; no optimizations.  

---

## ✅ Acceptance
After all patches:
- **Terminology unified**: “Tag Reassignment” everywhere (no “Replacement”).  
- **ReasonNotes explicit**: “Other” reasons always stored in `reasonNotes`.  
- **Indicator dots vs StatusBadge** clarified and enforced.  
- **Legacy fields deprecated** but documented for migration.  
- **All docs now aligned and implementation-ready.**