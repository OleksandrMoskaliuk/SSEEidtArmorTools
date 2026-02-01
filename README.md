📜 ClarityForge: Preparation & Usage Guide
To ensure the script functions correctly and follows your Game Balance Philosophy, the records must be prepared manually before execution. The script will not guess the material or the slots; it relies on your input to stay "Solid."

Mandatory Record Preparation
Before running the script, the user MUST perform two steps in SSEdit:
Set First Person Flags (BOD2): You must define which parts of the body the item covers (Body, Head, Hands, Feet, etc.). This is the primary data the script uses to distinguish between Mechanical and Visual slots.
Assign Armor Material Keyword: You must add a single material keyword to the outfit (e.g., ArmorMaterialEbony). This serves as the Master Instruction for the script to calculate Armor Rating, Weight, Price, and the crafting recipe.
Note: The script currently has no logic for Clothing-only crafting (Linen/Silk). It is designed for Armor-grade materials that require a forge.

🏛 Internal Logic Documentation
The Smithing/Armor Rating Curve
GlobalSmithingReq: Set via DEFAULT_SMITHING (0–100). This represents the skill level required to craft the set.
GlobalArmorBonus: This is an Integer derived from the skill requirement.
Calculation: GlobalArmorBonus := GlobalSmithingReq / 10.
Purpose: This provides a quality-based protection boost. A high-tier masterwork (Skill 100) coaxes more protection out of the material than a crude initiate-level forging.
Forearms Balancing (The 2.5x Rule)
Multiplier: FOREARMS_DEBUFF_MULTIPLIER = 2.5.
Purpose: Many modern outfits split gauntlets into separate Left and Right forearm pieces. To prevent the player from having double the intended gauntlet armor, the script applies this debuff to any item using only the Forearms slot.
Visual Slot Finalization
Definition: Any slot not in the "Allowed" list (e.g., pauldrons, pouches, capes).
The "Zero" Rule: These items are set to 0 Weight, 0 Armor Rating, and 0 Gold Value.
Enchanting Block: True Visual Slots receive the MagicDisallowEnchanting keyword.
Accessory Exception: Amulets (Slot 35) and Rings (Slot 42) are treated as Visual Slots (0 stats) but remain Enchantable and receive no warning description.

🔴 CRITICAL: MAIN SLOT CONFLICTS (ARMO RECORDS)
Avoid combining: Body [32], Hands [33], Feet [37], or Head [30/31] in one record.
Script Math Conflict: Since the script uses if Pos(...) > 0 checks, a record containing both Body and Hands will trigger multiple result overrides. This leads to unpredictable Armor Rating and Weight calculations.
Inventory Issues: If a single item occupies Body and Hands, the player cannot wear separate gauntlets. If they try to equip gloves, the entire suit will unequip, leaving the player naked except for the gloves.
Visual Bugs: Combining major slots often forces the ARMA (Armor Addon) to hide multiple body parts. If the mesh isn't perfectly modeled to cover all those areas, you will see gaping holes in the character model.
Enchanting Limitations: A multi-slot item only accepts one set of enchantments. By merging slots, the player loses 2–3 potential enchantment slots, severely weakening them in the late game.
RECOMMENDATION: Always split "Suits" into modular pieces (Cuirass, Boots, Gauntlets) via sseEdit for maximum compatibility with this script and the vanilla game balance.

⚠️ ATTENTION: MULTIPLE MATERIAL KEYWORDS
Each record MUST have exactly ONE ArmorMaterial keyword.
Logic Conflict: The script identifies an item's tier by scanning for keywords like ArmorMaterialSteel, ArmorMaterialEbony, etc. If a record contains multiple material keywords, the script will prioritize the first one it finds in the KWDA array. This may result in incorrect Armor Rating, Weight, and Price values.
Perk Incompatibility: Skyrim’s engine (and perks like Matching Set or Well Fitted) only calculates bonuses based on a single material type. Multiple keywords can break these bonuses and cause the item to scale incorrectly with the player's Smithing skill.
Recipe Generation: The MakeCraftableV2 function relies on a single material to determine which perk is required for crafting. Multiple materials will result in a recipe that might require the wrong perk or provide the wrong experience gain.
RECOMMENDATION: Before running the script, ensure each item has only one material keyword. Use the sseEdit Record Header view to remove any redundant or conflicting ArmorMaterial keywords.