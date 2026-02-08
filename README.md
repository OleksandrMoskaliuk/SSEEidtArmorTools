# 📜 ClarityForge: Preparation & Usage Guide

To ensure the script functions correctly and follows your **Game Balance Philosophy**, records must be prepared manually before execution. The script relies on your precise input to maintain a "Solid" gear system.

---

## 🛠 Mandatory Record Preparation

Before running the script, you **MUST** perform these two steps in xEdit:

1. **Set First Person Flags (BOD2):** Define which body parts the item covers. This is the primary data used to distinguish between **Gameplay** and **Visual** slots.
2. **Assign Armor Material Keyword:** Add exactly **ONE** material keyword (e.g., `ArmorMaterialEbony`). The script uses **Smart Detection** to scan your `.esp` and identify the dominant material to generate the correct Crafting Manual.

---

## 📖 The Crafting Manual System

ClarityForge automatically generates a **Unique Crafting Manual** for every outfit mod processed. 

* **Forge Protection:** All armor recipes are hidden by default to prevent menu clutter.
* **Unlock Requirement:** To see and craft the outfit, the player **must** have the generated manual in their inventory.
* **Manual Stats:** Weight is set to **0.1** and Value to **50 Gold**. It is classified as a non-skill book (reading it provides no free levels).
* **Dynamic Naming:** The book is named based on the mod filename and the detected material (e.g., `[COCO] Chaos Sorcerer Scaled Lv 25`).

---

## ⚙️ Global Configuration Variables

### 1. Crafting & Progression
* **`REQUIRED_SMITHING_SKILL`** (Default: 25)
    * **Forge Logic:** Recipes require this base skill level to appear (even with the book).
    * **Armor Bonus:** Base protection increases by `Skill / 10.0`.
    * **Price Bonus:** Market value increases by `Round(Skill / 10.0)`.
* **`FOR_FEMALE_ONLY`** (Default: True)
    * Injects a gender check (`GetIsSex`) into the recipe. Fancy outfits designed for female meshes will not appear for male characters.

### 2. Balance & Difficulty
* **`ADVANCED_ENCHANTMENT_PROTECTION`** (Default: True)
    * Injects a **Dummy Enchantment** into Visual Slots. This fills the `EITM` slot, preventing mods like **Enchantment Swapper** from adding "free" enchantments to accessory slots.
* **`BACKPACK_SLOT_ENCHANTABLE`** (Default: False)
    * Determines if **Slot 47** (Backpacks/Utility) is a gameplay or visual slot. Setting this to `False` prevents power-creep.
* **`FOREARMS_DEBUFF_MULTIPLIER`** (Default: 2.5)
    * Applies a debuff to **Slot 34** if used as primary protection. Discourages "slot-stacking" with vanilla gauntlets.

---

## ⚖️ Dynamic Slot Balancing

### **The Hair + Circlet Logic**
* **The Problem:** Many mods merge **Hair** and **Circlets**, losing one enchantment slot.
* **The Solution:** The script detects this and "promotes" the **Forearms** to a Gameplay Slot to compensate, keeping the "Total Enchantment Budget" balanced.

### **The Forearms Logic**
* **Standard Case:** If **Hands** exist, **Forearms** are decoration (0 AR).
* **Failover:** If no Hands slot is found, Forearms are enabled as primary protection but debuffed by the `FOREARMS_DEBUFF_MULTIPLIER`.

---

## 🏛 Internal Logic Documentation

### Visual Slot Finalization
* **Definition:** Any item not occupying a primary combat slot (Head, Body, Hands, Feet, Shield).
* **Stats:** Set to **1.0 Weight**, **0 Armor Rating**, and **(25 + SmithingReq) Gold Value**.
* **Protection:** Automatically receives the **Advanced Enchantment Protection** to block enchanting exploits.

### Weapon Balancing
* **Base Stats:** Synchronized with **UESP Wiki** values based on Material and Type.
* **Lethality Bonus:** Damage scales based on `REQUIRED_SMITHING_SKILL`.
* **Vendor Integration:** Automatically assigns `VendorItemWeapon` if missing.

---

## 🚫 Critical Warnings

* **One Material Rule:** Each record **MUST** have exactly **ONE** `ArmorMaterial` or `WeaponMaterial` keyword.
* **Patching Required:** Always run this script into a **New Patch ESP**. Do not modify Master files (`.esm`) directly, as the script needs to create new Book and Enchantment records.
