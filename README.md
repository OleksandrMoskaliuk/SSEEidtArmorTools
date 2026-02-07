# 📜 ClarityForge: Preparation & Usage Guide

To ensure the script functions correctly and follows your **Game Balance Philosophy**, records must be prepared manually before execution. The script relies on your precise input to maintain a "Solid" gear system.

## 🛠 Mandatory Record Preparation

Before running the script, you **MUST** perform these two steps in xEdit:

1. **Set First Person Flags (BOD2):** Define which body parts the item covers (Body, Head, Hands, Feet, etc.). This is the primary data used to distinguish between **Mechanical** and **Visual** slots.
2. **Assign Armor Material Keyword:** Add exactly **ONE** material keyword (e.g., `ArmorMaterialEbony`). This serves as the "Master Instruction" for calculating stats and recipes.

> [!NOTE]
> The script currently does not support Clothing-only crafting (Linen/Silk). It is designed for Armor-grade materials requiring a forge.

---

## 🔑 Required Keywords

### Armor Materials

| Heavy Armor Sets | Light Armor Sets |
| --- | --- |
| `ArmorMaterialIron` | `ArmorMaterialLeather` |
| `ArmorMaterialSteel` | `ArmorMaterialScaled` |
| `ArmorMaterialSteelPlate` | `ArmorMaterialElven` |
| `ArmorMaterialDwarven` | `ArmorMaterialGlass` |
| `ArmorMaterialOrcish` | `ArmorMaterialDragonscale` |
| `ArmorMaterialEbony` |  |
| `ArmorMaterialDaedric` |  |
| `ArmorMaterialDragonplate` |  |

### Weapons

* **Materials:** Iron, Steel, Dwarven, Orcish, Elven, Glass, Ebony, Daedric, Dragonbone.
* **Types:** Daggers, Swords, War Axes, Maces, Greatswords, Battleaxes, Warhammers, Bows.

---

## ⚙️ Global Configuration Variables

### 1. Crafting & Progression

* **`REQUIRED_SMITHING_SKILL` (Default: 25)**
* Adds a mandatory Smithing level condition to the forge recipe.
* **Armor Bonus:** Base protection increases by `Skill / 10.0`.
* **Price Bonus:** Market value increases by `Round(Skill / 10.0)`.


* **`FOR_FEMALE_ONLY` (Default: True)**
* Injects a gender check into the recipe to keep crafting menus clean.



### 2. Balance & Difficulty

* **`ADVANCED_ENCHANTMENT_PROTECTION` (Default: True)**
* Injects a **Dummy Enchantment** into Visual Slots to prevent "enchantment stacking" exploits.


* **`BACKPACK_SLOT_ENCHANTABLE` (Default: False)**
* Determines if **Slot 47** is a gameplay or visual slot.


* **`FOREARMS_DEBUFF_MULTIPLIER` (Default: 2.5)**
* Applies a debuff to Slot 34 if used as the primary arm protection to discourage "slot-stacking."



---

## ⚖️ Dynamic Slot Balancing (The "Enchantment Budget" Rule)

ClarityForge features a unique balancing system that automatically adjusts based on how "merged" your armor pieces are.

### **The Hair + Circlet Logic**

* **The Problem:** Many mods merge **Hair [31]** and **Circlets [42]** into one item, causing the player to lose one full enchantment slot.
* **The Solution:** If the script detects a **Hair + Circlet** merged record, it automatically "promotes" the **Forearms [34]** slot to a Gameplay Slot.
* **The Result:** The Forearms remain protective and enchantable to compensate for the lost headwear slot, keeping your "Total Enchantment Budget" balanced.

### **The Forearms Logic**

* **Standard Case:** If you have **Hands [33]**, the **Forearms [34]** are treated as decoration (0 AR).
* **Automatic Failover:** If no Hands slot is found, the script enables Forearms as primary protection.
* **Manual Override:** Set `FOREARMS_SLOT_ALWAYS_ENABLED = True` to always keep modular forearms gameplay-relevant.

> [!TIP]
> **Dynamic Detection:** The script performs a pre-scan of your `.esp` to identify slot overlaps. This ensures that "Modular" and "All-in-One" mods are balanced differently to maintain a consistent power level.

---

## 🏛 Internal Logic Documentation

### The Smithing/Armor Rating Curve

The script provides a quality-based protection boost based on your expertise [Smithing Skill]


### Visual Slot Finalization

* **Definition:** Any item not occupying a primary combat slot (Head, Body, Hands, Feet, Shield).
* **Stats:** Set to **1.0 Weight**, **0 Armor Rating**, and **(25 + [Smithing Skill]) Gold Value**.
* **Accessory Exception:** Amulets (Slot 35) and Rings (Slot 42) remain **Enchantable** but have 0 stats.

---

## 🚫 Critical Warnings

### 🔴 Main Slot Conflicts (ARMO Records)

**Avoid combining: Body [32], Hands [33], Feet [37], or Head [30/31] in one record.**

### ⚠️ Multiple Material Keywords

**Each record MUST have exactly ONE ArmorMaterial keyword.**

* **Logic Conflict:** The script will only recognize the first keyword found, potentially leading to incorrect stats.
* **Perk Incompatibility:** Vanilla and Requiem perks require a single material type to function.