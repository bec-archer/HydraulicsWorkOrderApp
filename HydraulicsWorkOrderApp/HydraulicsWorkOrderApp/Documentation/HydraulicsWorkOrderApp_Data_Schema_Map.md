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
  - WO_Number: String
  - flagged: Bool
  - cost: Decimal/Double <--should add up finalCosts from associated WO Items
  - notes: [WO_Note] (separate item from Item Notes) 
  - items: Subcollection → /workOrders/{id}/items/{itemId}
```

### 🔩 `/items/{itemId}` (WO\_Item)

```
  - imageUrls: [String]
  - type: String
  - dropdowns: { [String: String] }
  - dropdownSchemaVersion: Int
  - reasonsForService: [String]
  - reasonNotes: String?
  - statusHistory: [WO_Status]
  - testResult: String?
  - partsUsed: String?
  - hoursWorked: String?
  - assignedTo: String
  - isFlagged: Bool
  - tagReplacementHistory: [TagReplacement]?
  - tagId: String?
  - estimatedCost: Decimal/Double
  - finalCost: Decimal/Double
  - dropdowns: [String: String]
  - dropdownSchemaVersion: Int
  - lastModified: Date
  - lastModifiedBy: String
  - tagBypassReason: String?
  - isDeleted: Bool
  - notes: [WO_Note]
```

### 🗒 `notes`

// ───── NOTES (two clear kinds) ─────
struct WO_Note: Identifiable, Codable, Equatable {    // WorkOrder-level
  let id: UUID
  var workOrderId: UUID
  var user: String
  var text: String
  var timestamp: Date
}

struct WO_ItemNote: Identifiable, Codable, Equatable { // Item-level
  let id: UUID
  var workOrderId: UUID
  var itemId: UUID
  var user: String
  var text: String
  var timestamp: Date
}
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
