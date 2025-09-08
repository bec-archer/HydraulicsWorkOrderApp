# 🔐 Data Serialization Expectations – Hydraulics Work Order App

*Updated: August 7, 2025*

---

## 📦 Primary Model: `WorkOrder` (Work Order)

```swift
struct WorkOrder: Identifiable, Codable, Equatable {
    let id: UUID

    // ───── CREATION & OWNER ─────
    var createdBy: String            // legacy
    var createdById: String?         // auth.uid (NEW)
    var createdByName: String?       // denormalized displayName (NEW)

    // ───── CORE FIELDS ─────
    var phoneNumber: String
    var imageURL: String?            // fallback only if no items exist
    var timestamp: Date
    var WO_Number: String
    var isFlagged: Bool
    var isDeleted: Bool

    // ───── STATUS ROLL-UPS ─────
    var isCompleted: Bool
    var completedAt: Date?
    var isClosed: Bool
    var closedAt: Date?

    // ───── COSTS ─────
    var finalCost: Int?              // cents; recomputed roll-up of item.finalCost

    // ───── DROPDOWN SCHEMA ─────
    var dropdownSchemaVersion: Int   // snapshot at creation

    // ───── AUDIT ─────
    var lastModified: Date
    var lastModifiedBy: String
    var lastModifiedByName: String?

    // ───── ITEMS ─────
        // Invariant: WorkOrder MUST contain ≥ 1 WO_Item at all times.
        // Create/Update operations that would result in 0 items must be rejected.
        var items: [WO_Item]
    }
```

---

## 🔩 WO_Item

Each `WorkOrder` contains 1 or more `WO_Item` entries:

```swift
struct WO_Item: Identifiable, Codable {
    let id: UUID
    var tagId: String?
    var imageUrls: [String]
    var type: String
    var dropdowns: [String: String]
    var dropdownSchemaVersion: Int
    var reasonsForService: [String]
    var reasonNotes: String?
    var statusHistory: [WO_Status]
    var status: String?              // optional denormalized current status for fast filters
    var testResult: String?          // pass / fail / nil
    var partsUsed: String?
    var hoursWorked: Double?         // allow decimals (hours)
    var finalCost: Int?              // cents; per-item cost

    // ───── ASSIGNMENT ─────
    var assignedTo: String           // legacy fallback
    var assignedToId: String?        // auth.uid
    var assignedToName: String?      // display name

    var isFlagged: Bool
    var tagBypassReason: String?     // reason captured when tag scan is bypassed (item-level)
    
    // ───── TAGS (multi-binding) ─────
    var tags: [TagBinding]              // NEW: multiple QR codes per item
    var tagHistory: [TagHistory]        // NEW: bound/unbound/reassigned audit trail}
    
    // ───── TagBinding (NEW) ─────
    struct TagBinding: Codable, Equatable {
        var tagId: String               // normalized QR/RFID content (exact key)
        var role: String                // "primary" | "aux"
        var positionLabel: String?      // e.g., "A", "B", "Rod End", "Cap End", "Left", "Right"
        var addedAt: Date
        var addedByUserId: String
        var isActive: Bool              // false when unbound or reassigned away
        var lastSeenAt: Date?           // updated on scans
    }
    
    // ───── TagHistory (NEW) ─────
    struct TagHistory: Codable, Equatable {
        var tagId: String
        var workOrderId: UUID
        var itemId: UUID
        var fromItemId: UUID?           // when reassigned
        var toItemId: UUID?             // when reassigned
        var event: String               // "bound" | "unbound" | "reassigned"
        var reason: String?
        var at: Date
        var byUserId: String
    }
```

---

## 🕒 WO_Status (Update History)

```swift
struct WO_Status: Codable {
    let status: String
    let user: String        // legacy fallback
    let userId: String      // auth.uid
    let userName: String    // display name
    let timestamp: Date
    let notes: String?
}
```

---

## 🗒 WO_Note (Freeform Notes)

```swift
struct WO_Note: Identifiable, Codable {
    let id: UUID
    var user: String        // legacy fallback
    var userId: String      // auth.uid
    var userName: String    // display name
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
    var emojiTag: String?            // ✅ source of truth for UI
}
```

* Phone number is unique key
* Customer lookup uses `name` or `phone` (partial match allowed)
* Stored in Firebase and local cache

---

## 🔁 TagReplacement (LEGACY — deprecated)

> **Do not write new data** to `tagReplacementHistory`. This legacy shape is retained for read-only migration/backfill only.
> All new tagging events (bind/unbind/reassign) MUST use `tags: [TagBinding]` + `tagHistory: [TagHistory]`.

* **Migration note:** When encountered, map legacy replacements into `tagHistory(event:"reassigned")` for the resolved owner; keep the final active binding in `tags` and drop `tagReplacementHistory` post-migration.
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
* ✅ Use `isFlagged` (not `flagged`) on WorkOrders and WO_Items
* ✅ Store WorkOrder `finalCost` as a computed roll-up in **cents** (sum of item costs)
* ✅ Store costs on WO_Items as **Int (cents)**
* ✅ Store notes in subcollections (`/workOrderNotes`, `/itemNotes`), not inline
* ✅ Always include `userId` + `userName` with statuses/notes (legacy `user` fallback only)

### ✅ Non-Empty Items Enforcement (authoritative)

- **On create:** payload MUST include `items` with `items.count >= 1`. Reject `nil`, missing, or empty arrays.
- **On update:** reject any mutation that would set `items.count == 0` (including array transforms).
- **On delete item:** when a WorkOrder has exactly 1 item, block deletion with a clear error; require adding a replacement item first.
- **Reader/writer parity:** UI disables “Remove Item” when only one item remains; Sync/Rules validate the same invariant.

### 🚫 Don’t Do This

* ❌ Do not use positional params like `WorkOrder(UUID(), "123", "Pump", ...)`
* ❌ Do not shuffle the order of fields without syncing the database schema
* ❌ Do not reference undefined dropdown values (freeze them at entry)

### 🔍 Scan / Attach Semantics (NEW)
- Normalize QR to `tagId`, lookup active binding:
  - If active on **this item**: update `lastSeenAt`.
  - If active on **another item**: prompt “Reassign tag?” (show source/target); on confirm follow reassign rules.
  - If not found or inactive: create a new active `TagBinding` (role defaults to "aux"; if no primary exists, offer “Set as Primary”).
- Prompt for **Position Label** (preset or free text) to aid reassembly.

**Note:** Legacy `tagReplacementHistory` is **deprecated**. Use generalized `tagHistory` + `tags` to support many-to-one. Historical tag IDs remain searchable and must resolve/dedupe to the **current** WO_Item owner.


### 🔐 Tag Integrity Rules (NEW)
- A `tagId` may be **active on only one item at a time** (global uniqueness across active bindings).
- `tags[*].role`: at most **one "primary"** per item; others default to "aux".
- On **bind**: create `TagBinding{ isActive=true }` + append `TagHistory(event:"bound")`.
- On **unbound**: set `isActive=false` + append `TagHistory(event:"unbound")`.
- On **reassign**: (a) old binding `isActive=false` + history “reassigned” (from→to), (b) new active `TagBinding` on target item.
---

## 🔄 Firebase Encoding

* WorkOrder is stored as a Firestore document
* Each WO_Item is stored as a subcollection or embedded array
* Image URLs stored as strings
* `WO_Item.status` is an optional **denormalized** convenience field; the **source of truth** remains `statusHistory`.
* Optional fields skipped if `nil`
### Non-Empty Items (redundant guard)
- Persist `items` as present and **non-empty**. Writers must not push an empty `items` array. Readers should treat missing/empty as invalid and surface a repair path (admin tools only).

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
| Fail Alerts | On second test failure of WO_Item, mark as PROBLEM CHILD |
| Tech Alert  | Notify previous updater if not same as failing tech       |

---

### 🔁 Migration (from single tagId + tagReplacementHistory)
- If `tagId != nil`: set `tags = [ TagBinding(tagId: tagId, role:"primary", positionLabel:nil, addedAt:migrationTS, addedByUserId:"system", isActive:true) ]`.
- If `tagReplacementHistory` exists: map to `tagHistory` entries (old→new as `event:"reassigned"`), leaving final owner active. Then drop `tagReplacementHistory`.
```
