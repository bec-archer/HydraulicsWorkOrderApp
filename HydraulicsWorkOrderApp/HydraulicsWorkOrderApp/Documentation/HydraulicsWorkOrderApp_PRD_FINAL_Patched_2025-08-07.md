# 🧾 Product Requirements Document

**Project:** Hydraulics Equipment Check-In iPad App
**Author:** Bec Archer
**Last Updated:** September 2nd, 2025
**Platform:** iPad & iPhone (SwiftUI frontend)
**Backend:** Firebase Firestore (primary), Firebase Storage for images, self-hosted backup

---

## 🧭 Purpose

Replace manual Apple Notes workflow with a shared, role-based app for checking in hydraulic equipment, tracking repairs, and managing records. Designed for field technicians with large fonts, minimal UI, and gallery-based work order views.

---

## 🎨 User Interface Style

The entire app will visually mimic the Apple Notes UI for user familiarity:

* Grid layout on iPad (like Notes cards)
* Clean sans-serif fonts
* Large tap targets for buttons and fields
* Yellow-accented highlights and buttons via `AppleNotesYellow.json` theme

## 🎯 Key Goals

* Technician-first workflow with idiot-proof intake
* Reliable offline use + automatic background sync
* Role-based access (Tech, Manager, Admin, Super Admin)
* Equipment tracking via QR code / RFID tag
* Support for multi-equipment check-ins
* Work Order notes and status updates with timestamps and author attribution
* Future Android compatibility

---

## 👥 User Roles & Login

### 🔐 Login System

* PIN-based login (4–8 digits), mapped to individual users
* Each user has:

  * `name`: Display name
  * `passcode`: 4–8 digit PIN
  * `role`: One of `tech`, `manager`, `admin`, or `superadmin`
* Multiple users supported per role; only one Super Admin can be active at a time
* All actions are logged with name and timestamp

### 🔒 Role Capabilities

| **Feature**                       | **Tech** | **Manager** | **Admin** | **Super Admin** |
| --------------------------------- | :------: | :---------: | :-------: | :-------------: |
| Add/Edit WorkOrders               |     ✅    |      ✅      |     ✅     |        ✅        |
| View WorkOrders                   |     ✅    |      ✅      |     ✅     |        ✅        |
| Mark WorkOrders Completed         |     ✅    |      ✅      |     ✅     |        ✅        |
| Mark WorkOrders Closed            |     ✅    |      ✅      |     ✅     |        ✅        |
| Restore/Delete WorkOrders         |     ❌    |      ✅      |     ✅     |        ✅        |
| Override Hours/Parts              |     ❌    |      ✅      |     ✅     |        ✅        |
| Add/Edit Tags                     |     ❌    |      ✅      |     ✅     |        ✅        |
| Receive Failed Test Notifications |     ❌    | ⚠️ 2nd FAIL |     ❌     |        ✅        |
| Unlock/Edit Completed WorkOrders  |     ❌    |      ✅      |     ✅     |        ✅        |
| Edit Dropdowns                    |     ❌    |      ❌      |     ✅     |        ✅        |
| Add/Delete Users                  |     ❌    |      ❌      |     ✅     |        ✅        |
| Developer Tools / Scan Toggle     |     ❌    |      ❌      |     ❌     |        ✅        |

---

## 🏠 Active WorkOrders View

* iPad: grid layout (like Apple Notes)
* iPhone: list layout
* Each Work Order Card shows:

  * Customer Name (tappable)
  * Phone number (tap-to-call/text)
  * First image as thumbnail
  * Timestamp
  * Current Status (color-coded)
  * Flag icon
  * Work Order number: `YYMMDD-001`

**Sort Order:** Flagged first, then oldest to newest

---

## 👤 Customer Lookup & Creation

* The **very first field** in NewWO\_View is a **customer lookup**.
* As the tech types a name or phone number:

  * The app checks existing customers for matches (by name or phone)
  * If no match found: a **“+ Add New Customer”** button appears
* Tapping it opens `NewCustomerModalView`:

  * Autofills the field already typed (name or phone)
  * Remaining fields: Company Name, Email, Tax Exempt (toggle)
* Once saved:

  * New customer is added to Firebase
  * Modal closes and returns to NewWO\_View form with customer attached
* Ensures no duplicate records and fast intake

---

## ➕ New Work Order Workflow

1. Tech taps “+ New Work Order”
2. Lookup or add Customer
3. For each equipment:

   * Attach + scan QR code (or select reason for bypass)
   * Take at least one photo
   * Select dropdowns (type, color, size, brand, etc.)
   * Select reason(s) for service
   * Add optional notes
   * Save → becomes a `WorkOrderItem`
4. When all equipment is entered, tap **Check In Work Order**

✅ Status is auto-marked "Checked In"
✅ WorkOrder appears in active list with first photo as card thumbnail

---

## 🧑‍🔧 Tech Workflow + Status Handling

* Scan QR → opens WorkOrderItem
* Update status:

  * In Progress
  * Work Order Item Done

### ✅ If PASS:

* Enter:

  * Parts Used
  * Hours Worked
  * WO\_Item Cost
* Tap **Mark Work Order as Completed**
* WO now appears **gray** (status: Completed)

### ❌ If FAIL:

* Enter Failure Reason
* If tech entering FAIL ≠ last updater:

  * Last updater receives alert on next login
* If second failure:

  * Item flagged as **“PROBLEM CHILD”**
  * Push alert sent to Managers

---

## 📋 Notes & History Tracking

* Each `WorkOrder` stores both:

  * `WO_Status`: Status changes with timestamp + user + optional note
  * `WO_Note`: Freeform notes with user + timestamp
* Displayed together in a timeline under `NotesTimelineView`
* Used for visibility and auditing in WorkOrderDetailView
* Notes and statuses are timestamped and attributed

---

## 👨‍💼 Manager Review

* Can view/edit parts/hours/notes
* Can optionally mark WO as completed
* Required to address 2nd-fail "PROBLEM CHILD" flags

---

## ✅ Work Order Closing

* After customer pickup/payment:

  * Any role may tap **Mark as Closed**
  * WO status changes to **Closed**
  * Closed WOs hidden from active list
  * Only Managers/Admins can view/reopen/edit

---

## 🔁 Status Log Example

```
Checked In by Maria @ 7:05 AM
Marked In Progress by Joe @ 8:12 AM
Seals Replaced by Joe @ 9:14 AM
Tested: PASS by Joe @ 9:25 AM
Parts/Hours/Cost entered by Joe @ 9:26 AM
Marked Completed by Joe @ 9:30 AM
Marked Closed by Maria @ 5:10 PM
```

---

## 🔎 Search

* Fuzzy search supports:

  * Customer name
  * Phone number
  * WO number
  * Tag ID
  * Status

---

## 🔐 Completed vs Closed

| Status    | Who Sets It        | Visible To         | Behavior                          |
| --------- | ------------------ | ------------------ | --------------------------------- |
| Completed | Tech/Manager/Admin | All roles          | WO turns gray in active view      |
| Closed    | Any role           | Admin/Manager only | Hidden from Active list, archived |

---

## 🧩 Backend & Storage

* Primary: Firebase Firestore
* Image Hosting: Firebase Storage
* Backups: Self-hosted export to `/sqlite_backups`
* Offline support: local queue with retry

---

## 🔄 Sync & Dev Tools

* Super Admin can:

  * Disable login or tag scan logic
  * Access dev panel & sync monitor
* Dev mode allows:

  * Testing WO\_Number rollover at midnight
  * Reloading sample data on cold start
  * Verifying tag reassignment searchability (old + new IDs)

---

## ♻️ Tag Replacement Workflow

If a tag (QR or RFID) is damaged, missing, or reassigned:

* Manager/Admin can replace the `tagId` of a `WorkOrderItem`
* App prompts for:

  * **Old Tag ID** (autofilled)
  * **New Tag ID**
  * **Replacement Reason**
* Replacement is recorded to `tagReplacementHistory`
* Old tags remain searchable
* Role Required: Manager, Admin, or Super Admin

### 🔎 Tag Search Behavior

Searching by:

* ✅ Current tag → shows current WO\_Item
* ✅ Previous tag → also resolves to current WO\_Item (via tag history)
