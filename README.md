📜 ClarityForge: Preparation & Usage Guide
To ensure the script functions correctly and follows your Game Balance Philosophy, the records must be prepared manually before execution. 
The script will not guess the material or the slots; it relies on your input to stay "Solid."

Mandatory Record Preparation
Before running the script, the user MUST perform two steps in SSEdit:
Set First Person Flags (BOD2): You must define which parts of the body the item covers (Body, Head, Hands, Feet, etc.). 
This is the primary data the script uses to distinguish between Mechanical and Visual slots.
Assign Armor Material Keyword: You must add a single material keyword to the outfit (e.g., ArmorMaterialEbony).
This serves as the Master Instruction for the script to calculate Armor Rating, Weight, Price, and the crafting recipe.

Note: The script currently has no logic for Clothing-only crafting (Linen/Silk). It is designed for Armor-grade materials that require a forge.

🏛 Internal Logic Documentation
The Smithing/Armor Rating Curve
GlobalSmithingReq: Set via DEFAULT_SMITHING (0–100). This represents the skill level required to craft the set.
GlobalArmorBonus: This is an Integer derived from the skill requirement.
Calculation: GlobalArmorBonus := GlobalSmithingReq / 10.
Purpose: This provides a quality-based protection boost.
A high-tier masterwork (Skill 100) coaxes more protection out of the material than a crude initiate-level forging.
Forearms Balancing (The 2.5x Rule)
Multiplier: FOREARMS_DEBUFF_MULTIPLIER = 2.5.
Purpose: Many modern outfits split gauntlets into separate Left and Right forearm pieces.
To prevent the player from having double the intended gauntlet armor, the script applies this debuff to any item using only the Forearms slot.

Visual Slot Finalization
Definition: Any slot not in the "Allowed" list (e.g., pauldrons, pouches, capes).
The "Zero" Rule: These items are set to 0 Weight, 0 Armor Rating, and 0 Gold Value.
Enchanting Block: True Visual Slots receive the MagicDisallowEnchanting keyword.
Accessory Exception: Amulets (Slot 35) and Rings (Slot 42) are treated as Visual Slots (0 stats) but remain Enchantable and receive no warning description.
