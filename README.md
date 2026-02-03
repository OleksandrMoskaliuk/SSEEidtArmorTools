# 📜 ClarityForge: Preparation & Usage Guide

To ensure the script functions correctly and follows your **Game Balance Philosophy**, records must be prepared manually before execution. The script relies on your precise input to maintain a "Solid" gear system.

## 🛠 Mandatory Record Preparation

Before running the script, you **MUST** perform these two steps in xEdit:

1. **Set First Person Flags (BOD2):** Define which body parts the item covers (Body, Head, Hands, Feet, etc.). This is the primary data used to distinguish between **Mechanical** and **Visual** slots.
2. **Assign Armor Material Keyword:** Add exactly **ONE** material keyword (e.g., `ArmorMaterialEbony`). This serves as the "Master Instruction" for calculating Armor Rating, Weight, Price, and crafting recipes.

> [!NOTE]
> The script currently does not support Clothing-only crafting (Linen/Silk). It is designed for Armor-grade materials requiring a forge.

---

## 🔑 Required Keywords

For correct price and protection calculations, the record must have one of these vanilla keywords:

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
* Injects a gender check into the recipe. If enabled, female-only "fancy" outfits will not appear in the forge for male characters.



### 2. Balance & Difficulty

* **`ADVANCED_ENCHANTMENT_PROTECTION` (Default: True)**
* Injects a **Dummy Enchantment** into Visual Slots. This prevents players from using "free" accessory slots to stack extra enchantments, preserving intended game difficulty.


* **`BACKPACK_SLOT_ENCHANTABLE` (Default: False)**
* Determines if **Slot 47** is a gameplay or visual slot. Setting this to `False` prevents power-creep from items that share space with standard armor.


* **`FOREARMS_DEBUFF_MULTIPLIER` (Default: 2.5)**
* Applies to **Slot 34**. If an outfit has no Hands (Gauntlets) slot, Forearms provide protection but are debuffed by this factor to discourage "slot-stacking" with vanilla heavy gauntlets.



---

## 🏛 Internal Logic Documentation

### The Smithing/Armor Rating Curve

The script provides a quality-based protection boost. A high-tier masterwork (Skill 100) coaxes more protection out of the material than a crude initiate-level forging.

* **Calculation:** 


### Visual Slot Finalization

* **Definition:** Any item not occupying a primary combat slot (Head, Body, Hands, Feet, Shield) is treated as **Visual**.
* **Stats:** Visual items are set to **1.0 Weight**, **0 Armor Rating**, and **0 Gold Value**.
* **Enchanting Block:** Receives the `MagicDisallowEnchanting` keyword.
* **Accessory Exception:** Amulets (Slot 35) and Rings (Slot 42) are treated as Visual (0 stats) but remain **Enchantable**.

---

## 🚫 Critical Warnings

### 🔴 Main Slot Conflicts (ARMO Records)

**Avoid combining: Body [32], Hands [33], Feet [37], or Head [30/31] in one record.**

* **Logic Conflict:** Records with multiple primary slots trigger result overrides, leading to unpredictable AR and Weight.
* **Inventory Issues:** If one item occupies Body and Hands, the player cannot wear separate gauntlets; equipping gloves will unequip the entire suit.
* **Visual Bugs:** Combining slots often forces the ARMA to hide multiple body parts, causing gaping holes in character models.
* **Recommendation:** Always split "Suits" into modular pieces (Cuirass, Boots, Gauntlets) via xEdit.

### ⚠️ Multiple Material Keywords

**Each record MUST have exactly ONE ArmorMaterial keyword.**

* **Logic Conflict:** The script scans the `KWDA` array and prioritizes the first material it finds. Multiple keywords cause incorrect stat calculations.
* **Perk Incompatibility:** Vanilla perks (Matching Set/Well Fitted) only calculate bonuses based on a single material type.
* **Recommendation:** Use the xEdit Record Header view to remove redundant material keywords before execution.

### ⚠️ Visual Slots & Requiem

Visual slots are intentionally stripped of `ArmorMaterial` keywords. This ensures cosmetic items do not trigger **Requiem's** tier-based perk buffs, keeping them strictly aesthetic.

---

**Would you like me to generate a "Quick Start" summary block you can place at the very top of the README?**