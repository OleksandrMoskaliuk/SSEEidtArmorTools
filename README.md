
---

# 📜 ClarityForge: Preparation & Usage Guide

**ClarityForge** is a metadata-driven balancing and sanitization engine for Skyrim SE/AE. It allows for a cleaner load order by using **MO2 Metadata** to determine material types, skill requirements, and character progression.

---

## 🏷️ The NameCode System (MO2 Metadata)

The script identifies valid files by scanning the **Notes** field in your Mod Organizer 2 entries (stored in `meta.ini`).

### **How to Tag a Mod:**

Add the specific NameCode to your mod's **Notes** in the MO2 UI.
**Pattern:** `[Any Text] CF_[MaterialCode][SmithingLevel]`
**Example:** `H2135 Halloween Outfit CF_En68`

### **Material Codes**

| Type | Codes |
| --- | --- |
| **Light** | **Lr** (Leather), **Sd** (Scaled), **En** (Elven), **Gs** (Glass), **De** (Dragonscale) |
| **Heavy** | **In** (Iron), **Sl** (Steel), **Dn** (Dwarven), **Se** (SteelPlate), **Oh** (Orcish), **Ey** (Ebony), **Dc** (Daedric), **Dp** (Dragonplate) |

---

## ⚖️ Non-Linear Progression Scaling

ClarityForge calculates the **Character Level Requirement** using a **Quadratic Curve**. This ensures early-game gear is accessible quickly, while high-tier gear (Ebony/Daedric) requires a significant investment.

**The Level Formula:** 

$$PlayerLevel = 1 + (59 \times (\frac{SmithingSkill}{100})^2)$$

### **Progression Table Examples:**

| Smithing Req | Material Example | Character Level Req |
| --- | --- | --- |
| **20** | Iron / Leather | **Level 3** |
| **40** | Steel / Scaled | **Level 10** |
| **60** | Elven / Dwarven | **Level 22** |
| **80** | Ebony / Glass | **Level 39** |
| **100** | Daedric / Dragon | **Level 60** |

---

## 🛠️ Mandatory Script Setup

Before running the script, you **must** configure your physical environment in the `ClarityForge.pas` file:

1. **Global Path Configuration:**
Set your physical MO2 mods directory at the top of the script:
`const MO2_MODS_DIR = 'D:\GAMES\Honediem\mods\';`
2. **Record Preparation (BOD2 Flags):**
In xEdit, ensure your armor records have the correct **First Person Flags**. This data is used to distinguish between **Gameplay Slots** (Cuirass, Boots, etc.) and **Visual Slots** (Capes, Accessories).

---

## 📖 The Crafting Manual System

ClarityForge generates a **Unique Crafting Manual** for every mod folder processed to keep the forge menu clean.

* **Unlock Requirement:** The player **must** have the generated manual in their inventory to see or craft the items.
* **Forge Cleanup:** Original recipes are "Nullified" (Level 999 requirement) to prevent menu clutter.
* **Dynamic Naming:** Manuals are named based on the folder name and material (e.g., `[Manual] H2135 Halloween Elven Lv 68 Book`).

---

## ⚙️ Internal Logic & Safety

### **Visual Slot Finalization**

* **Advanced Protection:** Injects **Dummy Enchantments** into accessory slots to prevent "Enchantment Swapper" exploits.
* **Normalized Stats:** Visual items are set to **Weight 0.1**, **Armor Rating 0**, and a balanced price based on tier.

### **Armor & Weapon Balancing**

* **Armor Rating:** Increases dynamically: $BaseAR + (SmithingLevel / 15.0)$.
* **Weapon Damage:** Scales based on: $BaseDamage + (SmithingLevel / 40.0)$.
* **Keywords:** Automatically purges conflicting material keywords and injects correct ones for the detected tier.

---

## 🚫 Critical Warnings

* **Metadata Dependency:** If the `CF_` tag is missing from the MO2 Note, the script will skip the file.
* **One BOD2 Flag Rule:** Each record **must** have exactly **one** primary `BOD2` flag set for proper classification (Helmet, Hands, etc.).

---