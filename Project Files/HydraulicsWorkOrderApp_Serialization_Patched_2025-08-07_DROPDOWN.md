# 🔐 Data Serialization Expectations – Hydraulics Work Order App

*Updated: August 7, 2025*

---

## 📦 Primary Model: `WorkOrder` (Work Order)

```swift
struct WorkOrder: Identifiable, Codable, Equatable {
    let id: UUID
    var createdBy: String    // 👤 User who created the WorkOrder (for filtering & auditing)
    var phoneNumber: String
    var WO_Type: String
    var imageURL: String?
    var timestamp: Date
    var status: String
    var WO_Number: String
    var flagged: Bool
    var tagId: String?
    var estimatedCost: String?
    var finalCost: String?
    var dropdowns: [String: String]
    var dropdownSchemaVersion: Int // 🔖 Snapshot of dropdown set used when WO was created
    var lastModified: Date
    var lastModifiedBy: String
    var notes: [WO_Note]
    var items: [WO_Item]
    var tagBypassReason: String?
    var isDeleted: Bool
}
```

---

## 🔩 WO\_Item

Each `WorkOrder` contains 1 or more `WO_Item` entries:

```swift
struct WO_Item: Identifiable, Codable {
    let id: UUID
    var tagId: String?
    var imageUrls: [String]
    var type: String
    var dropdowns: [String: String]
    var dropdownSchemaVersion: Int // 🔖 Snapshot of dropdown set used when WO was created
    var reasonsForService: [String]
    var reasonNotes: String?
    var statusHistory: [WO_Status]
    var testResult: String? // pass / fail / nil
    var partsUsed: String?
    var hoursWorked: String?
    var cost: String?
    var assignedTo: String
    var isFlagged: Bool
    var tagReplacementHistory: [TagReplacement]? // 🆕 Track tag reassignments
}
```

---

## 🕒 WO\_Status (Update History)

```swift
struct WO_Status: Codable {
    let status: String
    let user: String
    let timestamp: Date
    let notes: String?
}
```

---

## 🗒 WO\_Note (Freeform Notes)

```swift
struct WO_Note: Identifiable, Codable {
    let id: UUID
    var user: String
    var text: String
    var timestamp: Date
}
```

---

## 👤 Customer Model

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

* Phone number is unique key
* Customer lookup uses `name` or `phone` (partial match allowed)
* Stored in Firebase and local cache

---

## 🔁 TagReplacement Model

```swift
struct TagReplacement: Codable {
    let oldTagId: String
    let newTagId: String
    let replacedBy: String
    let timestamp: Date
    let reason: String?
}
```

* Stored per `WO_Item` in `tagReplacementHistory: [TagReplacement]?`
* Enables rollback, audit trail, and old tag search

---

## 🧩 Dropdown Schema Versioning

* Each `WorkOrder` includes a `dropdownSchemaVersion` (Int)
* This value is frozen at creation using the global constant:

```swift
struct DropdownSchema {
    static let currentVersion = 1 // ⬅️ Increment only when dropdown sets change
}
```

* In the UI, compare `workOrder.dropdownSchemaVersion` with `DropdownSchema.currentVersion`
* If mismatched:

  * Show warning label: "⚠️ This Work Order uses an outdated dropdown set"
  * (Optional) Disable editing for dropdowns

---

## 🧾 Serialization Rules

### ✅ Do This

* ✅ Use **named parameters** when creating `WorkOrder`
* ✅ Store each `WO_Item` with its full dropdown state at time of creation
* ✅ Keep consistent order across:

  * Codable init
  * Firebase schema
  * SQLite table binding
  * JSON export

### 🚫 Don’t Do This

* ❌ Do not use positional params like `WorkOrder(UUID(), "123", "Pump", ...)`
* ❌ Do not shuffle the order of fields without syncing the database schema
* ❌ Do not reference undefined dropdown values (freeze them at entry)

---

## 🔄 Firebase Encoding

* WorkOrder is stored as a Firestore document
* Each WO\_Item is stored as a subcollection or embedded array
* Image URLs stored as strings
* Optional fields skipped if `nil`

---

## 💾 SQLite Binding

* All fields bound by **name** or using matching `fieldOrder`
* Use helpers like `fromRow`, `toRow` for safety

---

## 📋 Debug Tips

* Print `JSONEncoder().encode(WorkOrder)` for structure preview
* Log `fromRow()` decoding if data fails to display
* Keep sample test workOrders in development

---

## 🔐 Data Integrity

| Area        | Rule                                                      |
| ----------- | --------------------------------------------------------- |
| Timestamps  | Always UTC, ISO 8601 format                               |
| Users       | Always attach `userName` to each status update or note    |
| Fail Alerts | On second test failure of WO\_Item, mark as PROBLEM CHILD |
| Tech Alert  | Notify previous updater if not same as failing tech       |
