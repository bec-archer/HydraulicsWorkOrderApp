# 🗃️ Data Schema Map – Hydraulics Work Order App

*Describes Firebase + SQLite + local storage shape*

---

## 📁 Firebase Firestore Structure

```
/workOrders/{workOrderId}
  - createdBy: String
  - phoneNumber: String
  - WO_Type: String
  - imageURL: String?
  - timestamp: Date
  - status: String
  - WO_Number: String
  - flagged: Bool
  - tagId: String?
  - estimatedCost: String?
  - finalCost: String?
  - dropdowns: [String: String]
  - dropdownSchemaVersion: Int
  - lastModified: Date
  - lastModifiedBy: String
  - tagBypassReason: String?
  - isDeleted: Bool
  - notes: [WO_Note]
  - items: Subcollection → /workOrders/{id}/items/{itemId}
```

### 🔩 `/items/{itemId}` (WO\_Item)

```
  - tagId: String?
  - imageUrls: [String]
  - type: String
  - dropdowns: [String: String]
  - dropdownSchemaVersion: Int
  - reasonsForService: [String]
  - reasonNotes: String?
  - statusHistory: [WO_Status]
  - testResult: String?
  - partsUsed: String?
  - hoursWorked: String?
  - cost: String?
  - assignedTo: String
  - isFlagged: Bool
  - tagReplacementHistory: [TagReplacement]?
```

### 🗒 `notes` (WO\_Note)

```
  - id: UUID
  - user: String
  - text: String
  - timestamp: Date
```

### 🕒 `statusHistory` (WO\_Status)

```
  - status: String
  - user: String
  - timestamp: Date
  - notes: String?
```

### 🔁 `tagReplacementHistory`

```
  - oldTagId: String
  - newTagId: String
  - replacedBy: String
  - timestamp: Date
  - reason: String?
```

---

## 💾 SQLite Mirror Structure

(For offline sync/local backup)

* WorkOrders → `work_orders.db`
* Customers → `customers.db`
* WO\_Items → `wo_items.db`
* Notes & Statuses → can be embedded JSON columns or separate tables

💡 Suggestion: use matching column names as Firestore for easier syncing.

---

## 👥 Customer Record

```swift
struct Customer: Identifiable, Codable {
	let id: UUID
	var name: String
	var phone: String
	var company: String?
	var email: String?
	var taxExempt: Bool
}
```

Stored in both Firebase and local cache. Uniquely indexed by phone number.
