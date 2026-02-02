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

⚠️ ATTENTION: VISUAL SLOTS
Visual slots are intentionally stripped of ArmorMaterial keywords. This prevents them from triggering Requiem's tier-based perk buffs, ensuring that cosmetic items remain strictly cosmetic.

Smithing Skill Integration
REQUIRED_SMITHING_SKILL = 25 (Default Example)
Description:
This variable acts as a global multiplier that synchronizes item performance, market value, and crafting accessibility. It ensures that more advanced gear feels tangibly different from basic equipment across all metrics.
Key Impacts:
Combat Performance (Armor Bonus):
The script calculates a defensive bonus based on this value: GlobalArmorBonus = REQUIRED_SMITHING_SKILL / 10.0.
Example: A requirement of 25 adds +2.5 base armor rating to the item. This ensures that gear requiring higher skill provides superior protection.
Economic Scaling (Market Value):
The craftsmanship requirement directly increases the gold value of the item: Price Bonus = Round(REQUIRED_SMITHING_SKILL / 10.0).
This logic applies to all item types, including Visual Slots. Higher skill requirements represent better materials and finer craftsmanship, resulting in a higher market price.
Crafting Requirements (COBJ Conditions):
This value is injected into the Constructible Object (COBJ) record as a mandatory condition.
The player must have a Smithing Skill level greater than or equal to this value to even see the item in the crafting menu.
This works in addition to vanilla Perk requirements, creating a more granular progression system where perks alone aren't enough—you also need the practical experience (skill level).
Summary of Logic:
Visual Slots: Even though they provide 0 base protection, the REQUIRED_SMITHING_SKILL still increases their price, representing the rarity and complexity of the ornament.
Progression: By setting this higher, you move items further into the "mid-to-late game" category, preventing players from crafting high-tier gear too early in their playthrough.

Advanced Enchantment Protection
ADVANCED_ENCHANTMENT_PROTECTION = True
Technical Overview:
This feature implements a "hard-lock" on the enchantment field for items classified as Visual Slots or accessories. It ensures that purely aesthetic items cannot be turned into powerful combat gear.
The "Free Slot" Problem & Anti-Exploit Logic:
Preventing Power Creep: In vanilla Skyrim, player power is strictly limited by the number of available equipment slots. Adding visual accessories (like hip ornaments, capes, or extra jewelry) creates "Free Slots" for enchantments.
Difficulty Preservation: If a player can enchant 5 or 6 additional "Visual" items with effects like Fortify Health or Destruction Cost Reduction, the game's difficulty scaling completely breaks. A player could reach 100% spell cost reduction or infinite health far too early.
The Solution: This script "fills" the hidden enchantment slot of these items with a Dummy Effect. This blocks the player from using the Enchanting Altar on these items and prevents mods like Enchantment Swapper from moving powerful enchantments onto these extra slots.
Visual Slot Standardized Stats:
Protection: 0 Armor Rating (Items provide no defensive advantage).
Weight: 1.0 (Balanced to represent the physical presence of the item without being weightless).
Dynamic Value: Scaled by craftsmanship: 25 + [Smithing Skill Requirement (0-100)].
Double-Layer Security: Combines the MagicDisallowEnchanting keyword with a functional Dummy ENCH record to ensure the item remains "Visual Only" regardless of which crafting mods the player has installed.

Gender-Locked Crafting
FOR_FEMALE_ONLY = True
Description:
This setting ensures that gender-specific "fancy" armors or outfits do not clutter the crafting menu for characters they weren't designed for. When enabled, the script injects a specific visibility condition into the Constructible Object (COBJ) record.
How it works:
Dynamic Forge Filtering: The script adds a Condition to the recipe that checks the player's gender.
Female Character Check: If set to True, the armor will only appear in the Smithing Forge menu if the player character is Female.
Menu Cleanup: This prevents male characters from seeing (and accidentally crafting) outfits that lack a male 3D model or were aesthetically designed exclusively for female characters.
Purpose:
Immersion: Keeps the forge menu relevant to your current character. If an armor set only supports female bodies, it shouldn't distract a player playing a male character.
Avoids "Invisible" Items: Many high-quality "fancy" armors only include female meshes. Without this check, a male player might craft the item only to have it appear invisible or cause visual glitches when equipped.
Compatibility: This is implemented as a standard engine-level condition (GetIsSex), making it 100% compatible with UI mods like SkyUI and Constructible Object Customizer.

Forearms Slot Balancing
FOREARMS_DEBUFF_MULTIPLIER = 2.5
Technical Logic:
The script specifically targets Slot 34 (Forearms) to manage how protection is calculated when an outfit deviates from the standard "Gauntlets" (Hands) slot.
The Implementation:
Automatic Visual Conversion: If the script detects that the outfit already includes a dedicated Hands slot (GlobalHasHands), it sets the Forearm protection to 0. This converts the item into a Visual Slot to prevent stacking armor values on the same limb.
Calculated Protection: If the Forearm piece is the primary source of arm protection, the following formula is used:
Result := (Base Material Value / FOREARMS_DEBUFF_MULTIPLIER) + GlobalArmorBonus
Purpose & Balancing:
The Debuff: The base protection provided by the material is divided by the multiplier. This ensures that a single "Forearm" piece is never as strong as a full set of vanilla "Gauntlets," discouraging players from mixing non-standard slots with heavy armor to exploit the armor cap.
Skill Reward: By adding the GlobalArmorBonus after the division, the script ensures that players with high Smithing Skill still feel the benefit of their expertise. Even a debuffed forearm piece will provide decent protection if the crafter is highly skilled.
Slot Integrity: This logic maintains game difficulty by ensuring that "fancy" or "minimalist" armors remain viable for roleplaying without becoming mathematically superior to the game's original armor sets.

Slot 47 (Backpack) Enchanting Balance
BACKPACK_SLOT_ENCHANTABLE = False
Description:
This variable determines if items utilizing Slot 47 (traditionally the Backpack slot) should be treated as gameplay-relevant armor or purely as visual/utility accessories.
The Balancing Philosophy:
In modded Skyrim, many different types of armor—not just backpacks—can be assigned to Slot 47 depending on the modder's preference. This slot often provides significant built-in utility or stat bonuses.
How the Logic Works:
Preventing "Free" Power: If a player equips an item in Slot 47 alongside standard armor, they are essentially gaining an "extra" enchantment slot that the vanilla game difficulty does not account for. Allowing this slot to be enchanted can break game balance by allowing the player to stack excessive buffs.
The Swap Mechanic: Because many items might share Slot 47, they are mutually exclusive. By setting this variable to False, the script ensures that whatever occupies this slot remains a Visual Slot.
Protection Applied: When set to False, any item using Slot 47 will be automatically protected by the Advanced Enchantment Protection (Dummy ENCH + Keyword). It will retain its modded utility but cannot be used at an Enchanting Altar.
Summary of Setting:
False (Recommended): Preserves game difficulty by treating Slot 47 as a utility/visual-only slot.
True: Treats Slot 47 as a standard "Gameplay Slot," allowing the player to enchant these items. This significantly decreases overall difficulty by providing an additional slot for powerful enchantments.