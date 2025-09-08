# ✅ QA / Developer Test Scenarios – Hydraulics Work Order App

*Ensure each feature behaves as expected*

---

## 🧪 WorkOrder Creation

* [ ] Can create a new WorkOrder
* [ ] WorkOrderNumber follows format `YYMMDD-001`
* [ ] Creation supports 2+ WO_Items
* [ ] Each WO_Item accepts image, dropdowns, reason for service
* [ ] Customer modal autofills phone or name correctly
* [ ] Modal returns selected customer to WorkOrder

---

## 🧪 Validation (Schema-aligned)

* [ ] If **Reasons for Service = Other**, saving the WO_Item requires **`reasonNotes` non-empty**; attempt to save without notes must be blocked with a clear message  <!-- enforced by schema & UI rule --> 
* [ ] **Color = Other** opens a Color Picker; saved value persists as **name + #HEX** and renders as “Name — #HEX”  <!-- display rule --> 

---

## 🧪 Status + Test Handling

* [ ] Tech can mark In Progress
* [ ] Tech can mark WO_Item Done
* [ ] Tech can mark Tested: PASS
* [ ] On PASS: parts/hours/cost inputs accepted
* [ ] Tech can mark WorkOrder as Completed (card grays out)
* [ ] Tech can mark WorkOrder as Closed
* [ ] First FAIL logs, no alert
* [ ] Second FAIL triggers PROBLEM CHILD flag
* [ ] Previous updater gets notified if not same as tech

---

## 🧪 Tag Scan & Binding

* [ ] Tag(s) can be scanned and bound to a WO_Item
* [ ] Bypass prompt appears if scan skipped
* [ ] Admin/Manager can manage tag bindings (add, unbind, reassign)
* [ ] All changes append to `tagHistory` (events: bound, unbound, reassigned)
* [ ] One tag may be marked as Primary; additional tags default to Auxiliary
* [ ] Position Labels can be set or edited (e.g., A/B/C, Rod/Cap)
* [ ] Searching an **old tag** (historical binding) resolves to the current WO_Item (via tagHistory)  <!-- resolves via tagHistory per Nav/Search spec -->
* [ ] Searching a **previous tag ID** anywhere in the app resolves and **dedupes** to the current WO_Item owner  <!-- dedupe rule -->
 
---

## 🧪 Notes & Status Log

* [ ] WO_Status recorded for each dropdown status change
* [ ] WO_Note saved from freeform input
* [ ] Notes + statuses shown in timeline (NotesTimelineView)
* [ ] All notes/statuses timestamped and show user

---

## 🧪 Sync + Offline Behavior

* [ ] Data saves when offline
* [ ] SyncManager queues changes
* [ ] Data uploaded on reconnect
* [ ] Firebase image uploads complete
* [ ] Local backup to SQLite works

---

## 🧪 Developer Tools

* [ ] Can toggle login screen on/off
* [ ] Can disable tag scan enforcement
* [ ] Can reload sample data
* [ ] WO_Number rolls over correctly across midnight
* [ ] Tag search resolves via `tags` (active bindings) and `tagHistory` (old IDs → current item)

---

## 🧪 UI / UX Checks

* [ ] Apple Notes layout loads correctly
* [ ] Card view shows images (up to 4 item thumbnails), **indicator dots** (overlay + inline), customer, date, WO_Number; **no StatusBadge** on cards
* [ ] Completed WorkOrders appear gray
* [ ] Flag icon shown for flagged WO
* [ ] Tappable phone numbers initiate call or text
* [ ] Customer **emojiTag** appears next to the customer name on cards and detail; absent emoji yields no extra spacing

---

## 🧪 Search

* [ ] Searching a **previous tag ID** returns the current WO_Item (via tagHistory) and shows a small “matched via history” hint