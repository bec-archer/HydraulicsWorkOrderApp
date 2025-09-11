
# 🔽 WO_Item Dropdown & Checkbox Configuration

> Managed by **DropdownManagerView**; Admin/SuperAdmin can add/reorder; updates should bump `dropdownSchemaVersion`.

This file defines the dropdown and checkbox field options used in `NewWorkOrderView` and `AddWOItemFormView`.
> **Note (QR Position Labels):** Admins may optionally define a small preset list for QR **Position Labels** (e.g., A/B/C, Left/Right, Rod/Cap). The UI must still allow free-text entry when a preset doesn’t apply.
---

## 🧩 Dropdown Fields

List each dropdown field as a section, followed by its available options.

### type
- Cylinder
- Pump
- Hose
- Valve
- Other

### size (ONLY VISIBLE IF TYPE = CYLINDER)
- < 24"
- 24" - 36"
- > 36"

### color (display **name + hex**; “Other” opens a color picker)
- Black|#000000
- Red|#FF0000
- Yellow|#FFC500
- White|#FFFFFF
- Gray|#808080
- Orange|#F7941D
- Other (opens color picker)

### machineType
- Forklift
- Skid Steer
- Excavator
- Tractor
- Other

### machineBrand
- Bobcat
- Case
- Caterpillar
- Doosan
- Hyundai
- JCB
- John Deere
- Komatsu
- Kubota
- New Holland
- Takeuchi
- Terex
- Vermeer
- Other

### waitTime
- 8 hrs
- 24 hrs
- 48 hrs
- 72 hrs
- 7 days
- TBD

---

## ☑️ Checkbox Group: reasonsForService

This field supports **multi-select**. List all options here.

### reasonsForService
- Replace Seals
- Rod Damage
- Barrel Damage
- Check Valves
- Thread Damage
- Bushings
- Bent Rod
- Fittings - Repair
- Fittings - Replace
- Hard Lines - Repair
- Hard Lines - Replace
- Other (**requires** `reasonNotes` — saved in the item’s dedicated reasonNotes field)
