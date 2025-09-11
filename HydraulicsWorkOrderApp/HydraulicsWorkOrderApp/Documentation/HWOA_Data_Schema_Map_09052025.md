# 🗃️ Data Schema Map – Hydraulics Work Order App

*Describes Firebase + SQLite + local storage shape*

---

## 📁 Firebase Firestore Structure

### 👤 `/users/{userId}`  (userId == Auth `uid`)
- displayName: String
- phone: String?
- email: String?
- role: "tech" | "manager" | "admin" | "superAdmin"
- active: Bool
- avatarUrl: String?
- initials: String?
- createdAt: Timestamp
- lastSeenAt: Timestamp?

### 📄 `/workOrders/{woId}` (thin, high-level record)
# ───── CREATION & OWNER ─────
- createdBy: String                 # legacy; keep for now
- createdById: String               # auth.uid (NEW)
- createdByName: String             # denorm displayName (NEW)

# ───── CORE FIELDS ─────
- phoneNumber: String
- imageURL: String?                 # optional cached thumb (non-authoritative). UI MUST prefer items[*].imageUrls[0] (up to 4). Only use this if there are **no** WO_Items.
> Card images rule: show up to **4** images, each being the **first image** of a distinct WO_Item (items.imageUrls[0] in create order). If fewer than 4 items, show as many as available.
- timestamp: Date
- WO_Number: String
- isFlagged: Bool
- isDeleted: Bool                   # supports DeletedWorkOrdersView
- dropdownSchemaVersion: Int        # snapshot frozen at WorkOrder creation (matches WO_Item entries)

# ───── STATUS (denormalized for PRD actions) ─────
# explicit booleans with timestamps (preferred for filters/audit):
- isCompleted: Bool
- completedAt: Date?
- isClosed: Bool
- closedAt: Date?

# ───── COST (denormalized, computed) ─────
- finalCost: Int?                   # cents; **computed** sum of `/items/*/finalCost`
> Write-path rule: UI **never** writes this field. Sync logic recomputes after any `items/{itemId}.finalCost` change and persists for fast list sorting/filtering.

# ───── AUDIT ─────
- lastModified: Date
- lastModifiedBy: String            # auth.uid
- lastModifiedByName: String?       # denorm displayName (optional)

# ❌ Remove: notes: [WO_Note]   (use subcollection below)

#### 🔸 WorkOrder-level notes (timeline; multi-author safe)
`/workOrders/{woId}/workOrderNotes/{noteId}`
- id: UUID
- workOrderId: UUID
- userId: String                    # auth.uid
- userName: String                  # denorm
- text: String
- timestamp: Date
# (NotesTimelineView merges: workOrderNotes + items/{itemId}/itemNotes + each item's statusHistory)

### 🔩 `/workOrders/{woId}/items/{itemId}` (WO_Item)
# (No WorkOrder-level dropdowns; dropdowns live on each WO_Item and are snapshotted via `dropdownSchemaVersion` at item creation)
- imageUrls: [String]               # Storage URLs per item (source of truth)
- type: String
+ # ✅ Data integrity: Every WorkOrder must contain ≥ 1 WO_Item. Validation and UI must prevent saving a WorkOrder with zero items.

# ───── CONFIG / DROPDOWNS ─────
- dropdowns: { [String: String] }
- dropdownSchemaVersion: Int

# ───── REASONS ─────
- reasonsForService: [String]
- reasonNotes: String?   # required when "Other" is selected

# ───── STATUS ─────
- status: String                    # denormalized current status (NEW, optional)
- statusHistory: [WO_Status]        # append-only log

# ───── TECHNICAL DETAILS ─────
- testResult: String?
- partsUsed: String?
- hoursWorked: Double?

# ───── ASSIGNMENT ─────
- assignedTo: String                # legacy display name; keep
- assignedToId: String?             # auth.uid
- assignedToName: String?           # denorm displayName
# Filters: "My Work Items" must use assignedToId == currentUser.uid (display uses assignedToName)

# ───── FLAGS & TAGGING ─────
- isFlagged: Bool
- tags: [TagBinding]                 # multi-QR bindings (see Serialization)
- tagHistory: [TagHistory]           # bound/unbound/reassigned audit
- tagBypassReason: String?           # unchanged
+ # ❌ Legacy: tagReplacementHistory is deprecated. Do not write. Read-only during migration/backfill.

- **Tag lookup rule (search):** resolve both **active bindings** (`tags[*].tagId` where `isActive=true`) and any **historical tagIds** in `tagHistory`. Results must dedupe to the **current** WO_Item. Keep `/tagIndex/{tagId}` in sync on bind/unbind/reassign to enable reverse lookups.

# ───── COSTS ─────
- estimatedCost: Int?               # cents (optional)
- finalCost: Int?                   # cents (UI writes per-item; WorkOrder.finalCost is recomputed roll-up)

# ───── AUDIT ─────
- lastModified: Date
- lastModifiedBy: String            # auth.uid
- lastModifiedByName: String?       # denorm

# ───── SOFT DELETE ─────
- isDeleted: Bool

#### 🔸 Item-level notes (timeline; multi-author safe)
`/workOrders/{woId}/items/{itemId}/itemNotes/{noteId}`
- id: UUID
- workOrderId: UUID
- itemId: UUID
- userId: String
- userName: String
- text: String
- timestamp: Date

### 🕒 `statusHistory` (WO_Status)

- status: String
- user: String            // legacy; keep (read-only)
- userId: String          // NEW: auth.uid  (preferred for joins)
- userName: String        // NEW: denormalized displayName (preferred for display)
- timestamp: Date
- notes: String?
- **Authorship preference:** readers must use `userId/userName` when present; fall back to legacy `user` only if needed.


### 🔁 `tagHistory` (supersedes legacy `tagReplacementHistory`)

- Use `tagHistory: [TagHistory]` for all new writes (bind / unbind / reassign audit trail).
- Legacy `tagReplacementHistory` supported only for migration. Do not write new data there.

  - tagId: String
  - workOrderId: String
  - itemId: String
  - fromItemId: String?    # when reassigned
  - toItemId: String?      # when reassigned
  - event: String          # "bound" | "unbound" | "reassigned"
  - reason: String?
  - at: Date
  - byUserId: String


---

## 💾 SQLite Mirror Structure

(For offline sync/local backup)

* WorkOrders → `work_orders.db`
* Customers → `customers.db`
* WO_Items → `wo_items.db`
* Users → `users.db`                  

<!-- NEW -->
* Notes & Statuses → JSON columns or separate tables

**Proposed local tables (optional):**
- `work_order_notes`   (id, workOrderId, userId, userName, text, timestamp)
- `item_notes`         (id, workOrderId, itemId, userId, userName, text, timestamp)

**Users table (local):**
...
**Logical FKs (enforce in code):**
- `WorkOrders.createdById` → `Users.id`
- `WO_Items.assignedToId` → `Users.id`
- `work_order_notes.userId` → `Users.id`
- `item_notes.userId` → `Users.id`

---

## 🔒 Rules (directional)
- `/users/{uid}`: user can read/write self (except `role`, `active`).
- Admins can read all and update `role`/`active` for non-SuperAdmin users.
- Only Super Admin can set or modify users with `role == "superAdmin"` (or change any role to/from "superAdmin").
- In `workOrders/*` and `items/*`: validate that `lastModifiedBy == request.auth.uid` on write (or writer has admin role).

## 🚚 Migration (no downtime)
1. **Dual-write**: start writing new `*_Id`/`*_Name` alongside legacy strings.
2. **Backfill**: script to map legacy names → `/users` docs → set ids/names in all docs (items, notes, statuses, orders).
3. **Readers**: prefer `*_Id`/`*_Name`, fallback to legacy fields.
4. **Cutover**: stop writing legacy fields once coverage is ~100%.
5. **Optional cleanup** later.

---

## 👥 Customer Record

struct Customer: Identifiable, Codable {
	let id: UUID
	var name: String
	var phone: String
	var company: String?
	var email: String?
	var taxExempt: Bool
    var emojiTag: String?   // e.g., "🔧" or "⭐️" (single emoji/grapheme)

}
```

Stored in both Firebase and local cache. Uniquely indexed by phone number.

### 🔎 Tag Index for reverse lookups (UPDATED)
`/tagIndex/{tagId}`
- workOrderId: String
- itemId: String
- current: Bool                      # true for active binding; false for historical
> Write-through on bind/unbind/reassign to keep reverse lookup instant and unique.


## ⚙️ Suggested Indexes (Firestore)
- collection group on `/workOrders/*/items`: `assignedToId ASC, status ASC` (My Work Items by status)
- `workOrders`: `createdById ASC, timestamp DESC` (per-user creation history)
- `users`: `active ASC, role ASC` (admin screens)
- `workOrders`: `finalCost DESC, timestamp DESC` (costly-first sorting)
  •	After any write to /workOrders/{woId}/items/{itemId}.finalCost → recompute and write /workOrders/{woId}.finalCost = sum(items.*.finalCost).
- Collection-group: `items.tags.tagId` WHERE `items.tags.isActive == true` (app-level uniqueness guard + rule check)
- Collection-group: `items.tagHistory.tagId, items.tagHistory.at` (audit queries)
- Per-item composite: (`tags.role`, `tags.isActive`)

---

## Normalization & Status Rules (Cross-cutting)

- **Flags:** Use `isFlagged` at both WorkOrder and WO_Item levels; readers/writers prefer `isFlagged`.
- **WO card status:** Computed from items (see rules); do **not** rely on a WorkOrder `status` string.
- **Timeline:** Merge `/workOrderNotes/*`, `/items/*/itemNotes/*`, and each item’s `statusHistory`; show `userName`, keep `userId`.
- **Costs:** UI writes **item.finalCost** (cents). Never write **workOrder.finalCost** from UI; Sync recomputes sum.
- **Thumbnails:** Use `items[*].imageUrls[0]` (up to 4). Only fallback to `workOrders.imageURL` if no items exist.
- **Tag bypass:** Store reason on **items/{itemId}.tagBypassReason**. Also append a WO_Status entry (“Tag scan bypassed — <reason>”) for audit at the order level.
- **Assignment:** “My Work Items” filters by **`assignedToId == currentUser.uid`**; show `assignedToName`.
- **Lists:** Active = `!isCompleted && !isClosed && !isDeleted`; Completed = `isCompleted && !isClosed && !isDeleted`; Closed = `isClosed && !isDeleted`; Deleted = `isDeleted`.
- **Phones:** Display pretty format; tel/sms actions use normalized digits.
- **Customer emoji:** Source of truth is **Customer.emojiTag**; do not denorm to WorkOrder.
- **Status colors:** `StatusBadge` owns the semantic color mapping for statuses. **Indicator dots reference this mapping**; no local color tables.
+ - **Dropdown schema:** Both WorkOrder and each WO_Item store `dropdownSchemaVersion`. On schema changes, increment globally and freeze version on creation; old WorkOrders remain read-only or warned if mismatched.

---

### 📋 List Membership (derived from flags)
- **Active**: `!isCompleted && !isClosed && !isDeleted`
- **Completed**: `isCompleted && !isClosed && !isDeleted`
- **Closed**: `isClosed && !isDeleted`
- **Deleted**: `isDeleted`