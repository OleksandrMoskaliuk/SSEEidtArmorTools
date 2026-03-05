---

# 📜 ClarityForge: Preparation & Usage Guide

To ensure the script functions correctly files must follow a specific naming convention. The script uses the filename to determine material types, skill requirements, and character progression gating.

---

## 🏷️ The NameCode System (Filename Convention)

The script identifies valid files by scanning for the `CF_` tag. Your filename determines the entire balance profile of the mod.

**Pattern:** `[InternalName]_CF_[MaterialCode][SmithingLevel].esp`

**Example:** `NordicPlate_CF_Ey80.esp` (Ebony Material, Level 80 Smithing)

### **Material Codes**

| Type | Codes |
| --- | --- |
| **Light** | **Lr** (Leather), **Sd** (Scaled), **En** (Elven), **Gs** (Glass), **De** (Dragonscale) |
| **Heavy** | **In** (Iron), **Sl** (Steel), **Dn** (Dwarven), **Se** (SteelPlate), **Oh** (Orcish), **Ey** (Ebony), **Dc** (Daedric), **Dp** (Dragonplate) |

### **Automated Level Gating**

The script now enforces two layers of progression gating:

1. **Skill Gating:** The `SmithingLevel` (e.g., 80) is required to craft the item.
2. **Character Gating:** The script calculates the **Character Level Requirement** using the formula:
`GlobalPlayerLevelReq := Round(SmithingLevel * PLAYER_LEVEL_REQUIREMENT)`

*Example: With `PLAYER_LEVEL_REQUIREMENT = 0.75`, a Level 80 Ebony set will require the player to be **Character Level 60** to craft.*

---

## 🛠 Mandatory Record Preparation

Before running the script, you **MUST** perform these steps in xEdit:

1. **Set First Person Flags (BOD2):** Define which body parts the item covers. This is the primary data used to distinguish between **Gameplay** and **Visual** slots.
2. **Naming Convention:** Ensure the `.esp` or `.esl` is named using the **NameCode** system above.

* **Keyword Management:** The script now utilizes a **High-Speed FormID Cache** to automatically purge conflicting material and type keywords and inject the correct ones. This ensures your patch overrides are "clean" and free of legacy metadata.

---

## 📖 The Crafting Manual System

ClarityForge automatically generates a **Unique Crafting Manual** for every outfit mod processed.

* **Forge Protection:** All original recipes are overridden and nullified (Level 999 requirement) to prevent menu clutter.
* **Unlock Requirement:** To see and craft the outfit, the player **must** have the generated manual in their inventory.
* **Manual Stats:** Weight is set to **0.01** and Price = `REQUIRED_SMITHING_SKILL * CRAFTING_MANUAL_PRICE_MULTIPLIER`.
* **Dynamic Naming:** The book is named based on the detected material and skill requirements (e.g., `[Manual] Chaos Sorcerer Scaled Lv 25`).

---

## ⚙️ Global Configuration Variables

### 1. Crafting & Progression

* **`REQUIRED_SMITHING_SKILL`** (Detected from Filename)
* **`PLAYER_LEVEL_REQUIREMENT`** (Default: 0.75) - The ratio of Player Level to Smithing Level required to craft.
* **Forge Logic:** Recipes require both levels to appear in the crafting menu.
* **Armor Bonus:** Base protection increases dynamically. Current formula: `BaseAR + (SmithingLevel / 15)`.
* **`FOR_FEMALE_ONLY`** (Default: True)
* Injects a gender check (`GetIsSex`) into the recipe for female-only outfits.

### 2. Balance & Difficulty

* **`ADVANCED_ENCHANTMENT_PROTECTION`** (Default: True)
* Injects a **Dummy Enchantment** into Visual Slots. This fills the `EITM` slot, preventing mods like **Enchantment Swapper** from adding "free" enchantments to accessory slots.


* **`BACKPACK_SLOT_ENCHANTABLE`** (Default: False)
* Determines if **Slot 47** (Backpacks/Utility) is a gameplay or visual slot. Setting this to `False` prevents power-creep.


* **`FOREARMS_DEBUFF_MULTIPLIER`** (Default: 2.5)
* Applies a debuff to **Slot 34** if used as primary protection. Discourages "slot-stacking" with vanilla gauntlets.



---

## 🏛 Internal Logic Documentation

### Visual Slot Finalization

* **Definition:** Any item not occupying a primary combat slot (Head, Body, Hands, Feet, Shield).
* **Stats:** Set to **Weight = 0.1 **, **Armor Rating = 0**, and **Price = (25 + SmithingReq)**.

### Weapon Balancing

* **Base Stats:** Synchronized with **UESP Wiki** values based on Material and Type.
* **Lethality Bonus:** Damage scales based on `REQUIRED_SMITHING_SKILL`.
* **Vendor Integration:** Automatically assigns `VendorItemWeapon` if missing.

---

## 🚫 Critical Warnings

* **One BOD2 (First Person Flag) Rule:** Each record **MUST** have exactly **ONE** `BOD2` flag set to be identified correctly as a specific part (Helmet, Cuirass, etc.).
* **Filename Dependency:** If the `CF_` tag or material code is missing/incorrect, the script will skip the file entirely for safety.

---