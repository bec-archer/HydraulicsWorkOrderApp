
# 🔽 WO_Item Dropdown & Checkbox Configuration

This file defines the dropdown and checkbox field options used in `NewWorkOrderView` and `AddWOItemFormView`.

---

## 🧩 Dropdown Fields

> NOTE: All dropdowns in this section are **catalog-managed**. Admins and SuperAdmins can edit/add/remove values. Managers see them read-only and can submit **Request Change** forms. Techs can only select from these lists (or choose "Other" where available).

List each dropdown field as a section, followed by its available options.

### type
- Cylinder
- Pump
- Hose
- Valve
- Other

### size
- Small
- Medium
- Large
- Extra Large
- Other

### color
- Black
- Silver
- Yellow
- Blue
- Red
- Other

### machineType
- Forklift
- Skid Steer
- Excavator
- Tractor
- Other

### machineBrand
- Bobcat
- Deere
- Caterpillar
- Kubota
- Other

---

## ☑️ Checkbox Group: reasonsForService

> NOTE: This list is **catalog-managed**. Admins and SuperAdmins can edit/add/remove values. Managers see it read-only and can submit **Request Change** forms. Techs can only select from this list (or choose "Other," which requires notes).

This field supports **multi-select**. List all options here.

### reasonsForService
- Rebuild
- Leak
- Test
- Check Valves
- Noise
- Other
