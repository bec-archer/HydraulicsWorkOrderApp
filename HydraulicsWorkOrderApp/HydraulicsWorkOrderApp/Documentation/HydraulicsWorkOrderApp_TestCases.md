# ✅ QA / Developer Test Scenarios – Hydraulics Work Order App

*Ensure each feature behaves as expected*

---

## 🧪 WorkOrder Creation

* [ ] Can create a new WorkOrder
* [ ] WorkOrderNumber follows format `YYMMDD-001`
* [ ] Creation supports 2+ WO\_Items
* [ ] Each WO\_Item accepts image, dropdowns, reason for service
* [ ] Customer modal autofills phone or name correctly
* [ ] Modal returns selected customer to WorkOrder

---

## 🧪 Catalog Management (Dropdowns & Reasons for Service)

* [ ] Admin can add/edit/deactivate dropdown values
* [ ] Admin can add/edit/deactivate **Reasons for Service**
* [ ] SuperAdmin can manage all catalogs including Reasons for Service
* [ ] Manager sees DropdownManagerView in read-only mode
* [ ] Manager can submit a Request Change for catalogs (including Reasons for Service)
* [ ] Tech does not see catalog management UI

---

## 🧪 Status + Test Handling

* [ ] Tech can mark In Progress
* [ ] Tech can mark WO\_Item Done
* [ ] Tech can mark Tested: PASS
* [ ] On PASS: parts/hours/cost inputs accepted
* [ ] Tech can mark WorkOrder as Completed (card grays out)
* [ ] Tech can mark WorkOrder as Closed
* [ ] First FAIL logs, no alert
* [ ] Second FAIL triggers PROBLEM CHILD flag
* [ ] Previous updater gets notified if not same as tech

---

## 🧪 Tag Scan & Replacement

* [ ] Tag ID scanned into WO\_Item
* [ ] Bypass prompt appears if scan skipped
* [ ] Admin/Manager can replace tag ID
* [ ] TagReplacement history logs properly
* [ ] Searching old tag finds new WO\_Item

---

## 🧪 Notes & Status Log

* [ ] WO\_Status recorded for each dropdown status change
* [ ] WO\_Note saved from freeform input
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
* [ ] WO\_Number rolls over correctly across midnight
* [ ] TagReplacement search works for old/new IDs

---

## 🧪 UI / UX Checks

* [ ] Apple Notes layout loads correctly
* [ ] Card view shows image, customer, status, date, WO\_Number
* [ ] Completed WorkOrders appear gray
* [ ] Flag icon shown for flagged WO
* [ ] Tappable phone numbers initiate call or text

* [ ] Managers see read-only DropdownManagerView with Request Change button
* [ ] Admin UI prevents editing/activating/deactivating SuperAdmin accounts
