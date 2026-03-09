{
	unit ClarityForge;

	License: Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)
	https://creativecommons.org

	Copyright (c) 2024 Oleksandr Moskaliuk (Dru9Dealer)
	Repository: https://github.com/OleksandrMoskaliuk/SSEEidtArmorTools

	You are free to:
	- Share: copy and redistribute the material in any medium or format.
	- Adapt: remix, transform, and build upon the material.

	Under the following terms:
	- Attribution: You must give appropriate credit and provide a link to the license.
	- NonCommercial: You may not use the material for commercial purposes.

================================================================================
UNIT: ClarityForge
PURPOSE: Advanced Armor Sanitization and Balancing for Requiem / Skyrim AE.

FILE NAMING CONVENTION (NameCode):
Files must follow the pattern: [Name]_CF_[MaterialCode][SmithingLevel].esp
Example: "NordicPlate_CF_Eb80.esp"

MATERIAL CODES:
- Light: Lr (Leather), Sd (Scaled), En (Elven), Gs (Glass), De (Dragonscale)
- Heavy: In (Iron), Sl (Steel), Dn (Dwarven), Se (SteelPlate), Oh (Orcish), 
         Ey (Ebony), Dc (Daedric), Dp (Dragonplate)

REQUIREMENT SCALING:
- Smithing Req: Defined by filename (e.g., 80).
- Player Level Req: Calculated as (Smithing + 20) / 2.

CORE PHILOSOPHY:
- Modular Outfits: Distinguishes between Functional (AR-bearing) and Visual (Cosmetic) pieces.
- Requirement Scaling: Armor Rating increases based on the Smithing Skill requirement.
- Requiem Ready: Automatically manages ArmorType (Heavy/Light/Clothing) and Fists perks.
================================================================================
}
unit ClarityForge;
uses SK_UtilsRemake;

const
	{========================================================}
	{                     CONFIGURATION                      }
	{========================================================}
	FOR_FEMALE_ONLY = True;
	BACKPACK_SLOT_ENCHANTABLE = True;
	ADVANCED_ENCHANTMENT_PROTECTION = True;
	FOREARMS_SLOT_ALWAYS_ENCHANTABLE = True; // If True Forearms will be always enchantable.
	FOREARMS_DEBUFF_MULTIPLIER = 2.5; // Forearms Armor Rating debuff.  Set to 1 to disable.
	CRAFTING_MANUAL_PRICE_MULTIPLIER = 50; // Book value = GlobalSmithingReq * CRAFTING_MANUAL_PRICE_MULTIPLIER
	VISUAL_SLOT_WEIGHT = 0.1;
	IS_PERK_REQUIRED = False;
	sScriptVersion = '1.1.4';
	sRepoUrl = 'https://github.com/OleksandrMoskaliuk/SSEEidtArmorTools';	

var
	GlobalSmithingReq: Integer;
	GlobalPlayerLevelReq: Integer;
	GlobalArmorBonus: Float;
	GlobalDisableForearmsARBonus: Boolean;
	GlobalDoOnce: Boolean;
	GlobalProcessedRecords: Integer;
	GlobalForearmsDebuffMultiplier: Float;
	GlobalWeaponDamageBonus: integer;
	GlobalWeaponPriceBonus: integer;
	GlobalArmorPriceBonus: integer;
	GlobalWeaponWeightBonus: Float;
	GlobalFileName: string;
	GlobalCraftingManual: IInterface;
	GlobalOutfitMaterial: string;
	GlobalVarFileName: string;
	GlobalPatchFile: IInterface;

{========================================================}
{                   INITIALIZE                           }
{========================================================}
function Initialize: Integer;
begin
	AddMessage('--- SSEEidtArmorTools v' + sScriptVersion + ' by Dru9Dealer ---');
	AddMessage('License: CC BY-NC 4.0');
	AddMessage('Project Home: ' + sRepoUrl);
	
	{ Initialize Result }
	Result := 0;

	{ Set Global Values }
	GlobalSmithingReq := 5; // Smithing Skill Level 0 - 100;
	GlobalPlayerLevelReq := 0;
	GlobalArmorBonus := GlobalSmithingReq / 15.0; // Too much ArmorRating will cause Requiem script to fail
	GlobalFileName := '';
	GlobalOutfitMaterial := '';

	{ Note: Result of division is Float, so we Round for Integer bonuses }
	GlobalWeaponDamageBonus := Round(GlobalSmithingReq / 40.0);
	GlobalWeaponPriceBonus := GlobalSmithingReq;
	GlobalArmorPriceBonus := Round(GlobalSmithingReq / 10.0);
	
	GlobalWeaponWeightBonus := GlobalSmithingReq / 20.0;
	GlobalForearmsDebuffMultiplier := FOREARMS_DEBUFF_MULTIPLIER;
	
	{ Reset Tracking Booleans }
	GlobalDoOnce := False;
	GlobalProcessedRecords := 0;
	GlobalDisableForearmsARBonus := False; // Always Enabled
	
	{ Logging Configuration }
	AddMessage('--- ARMOR CONFIGURATOR STARTED ---');
	AddMessage('SMITHING REQUIREMENT = ' + IntToStr(GlobalSmithingReq));
	
	// Creating Patch file
	GlobalVarFileName := 'ClarityForge_Patch.esp';
	
	GlobalPatchFile := fAddNewFile(GlobalVarFileName, true);
	
	// Exit if initialization failed
	if not Assigned(GlobalPatchFile) then begin
		Result := 1;
		Exit;
	end;
	
	ScanFiles();
	
end;

procedure ScanFiles;
var
	i: Integer;
	f: IInterface;
	sFileName: string;
begin
	for i := 0 to FileCount - 1 do begin
		f := FileByIndex(i);
		sFileName := GetFileName(f);
		AddMessage('Initialization: Working with ' + sFileName);
		if fIsClarityForgeApplicable(sFileName) then begin
			AddMessage('>>> Valid File Found: ' + sFileName);
			fProcessArmorRecords(f);
			fProcessWeaponRecords(f);
			fNullifyOriginalRecipes(f, GlobalPatchFile);
		end;
	end;
end;

{========================================================}
{              CREATE DUMMY ENCHANTMENT                  }
{========================================================}
function CreateDummyEnchantment(f: IInterface): IInterface;
var
	mgefGroup, enchGroup, mgef, ench, effects, entry: IInterface;
begin
	{ 1. Check if the ENCH already exists in the load order }
	Result := MainRecordByEditorID(GroupBySignature(f, 'ENCH'), 'aaaDummyProtectionENCH');
	
	{ If found, we stop here and return the existing record }
	if Assigned(Result) then Exit;

	{ 2. If NOT found, proceed with creation as before }
	mgefGroup := GroupBySignature(f, 'MGEF');
	if not Assigned(mgefGroup) then mgefGroup := Add(f, 'MGEF', True);
	
	enchGroup := GroupBySignature(f, 'ENCH');
	if not Assigned(enchGroup) then enchGroup := Add(f, 'ENCH', True);

	{ Create MGEF }
	mgef := Add(mgefGroup, 'MGEF', True);
	SetElementEditValues(mgef, 'EDID', 'aaaDummyProtectionMGEF');
	SetElementEditValues(mgef, 'FULL', 'Internal Protection');
	SetElementEditValues(mgef, 'Magic Item Data\Flags', 'Hide in UI, No Duration, No Magnitude');
	
	{ Create ENCH }
	ench := Add(enchGroup, 'ENCH', True);
	SetElementEditValues(ench, 'EDID', 'aaaDummyProtectionENCH');
	SetElementEditValues(ench, 'FULL', 'Protected Item');
	
	{ Link them }
	effects := Add(ench, 'Effects', True); 
	entry := ElementByIndex(effects, 0);
	SetNativeValue(ElementByPath(entry, 'EFID'), FixedFormID(mgef)); 
	
	SetElementEditValues(entry, 'EFIT\Magnitude', '0');
	
	Result := ench;
end;

{========================================================}
{             CLARITY FORGE FILE DETECTION               }
{========================================================}
function fIsClarityForgeApplicable(m_sFileName: string): Boolean;
var
	sBase, sSuffix, sMat: string;
	p, iTempLevel: Integer;
begin
	Result := False;

	sBase := ChangeFileExt(m_sFileName, '');
	p := Pos('CF_', sBase);
	if p = 0 then Exit;
	
	// Clean GlobalFileName: Trim handles spaces, then check for trailing underscore
	GlobalFileName := Trim(Copy(sBase, 1, p - 1));
	if (Length(GlobalFileName) > 0) and (GlobalFileName[Length(GlobalFileName)] = '_') then
		GlobalFileName := Trim(Copy(GlobalFileName, 1, Length(GlobalFileName) - 1));

	sSuffix := Copy(sBase, p, Length(sBase));
	if Length(sSuffix) < 6 then Exit;

	sMat := Copy(sSuffix, 4, 2); 

	// Validation and Assignment
	if fAssignGlobalMaterial(sMat) then begin
		iTempLevel := StrToIntDef(Copy(sSuffix, 6, Length(sSuffix)), -1);

		if (iTempLevel >= 5) and (iTempLevel <= 100) then begin
			GlobalSmithingReq  := iTempLevel;
			// Final calculation for Character Level
			GlobalPlayerLevelReq := fGetCurvedPlayerLevel(GlobalSmithingReq);
			
			AddMessage('   Detected: ' + GlobalFileName + ' [' + GlobalOutfitMaterial + ']');
			Result := True;
		end;
	end;
end;

{========================================================}
{            PROCESS ARMOR RECORDS IN FILE               }
{========================================================}
procedure fProcessArmorRecords(m_f: IInterface);
var
	GroupARMO, CurrentRecord: IInterface;
	i: Integer;
	m_NewRecord: IInterface;
	m_Slots: string;
	//Enchant for ENCHANTMENT_PROTECTION
	m_DummyEnch: IInterface;
	// Check duplicates for tempering recipes
	currentKeywordEDID: string;
	recipeCraft: IInterface;
	// Armors
	m_ArmorRating: Float;
	m_ArmorPrice: Integer;
	m_ArmorWeight: Float;
begin
	// 1. Locate the ARMO (Armor) category in this specific file
	GroupARMO := GroupBySignature(m_f, 'ARMO');

	if Assigned(GroupARMO) then begin
		AddMessage('   -> Scanning ' + IntToStr(ElementCount(GroupARMO)) + ' Armor records...');
		
		GlobalCraftingManual := CopyBookAsNewRecord(GlobalPatchFile, '0001AFCF', (GlobalFileName + ' ' +  StringReplace(GlobalOutfitMaterial, 'ArmorMaterial', '', [rfReplaceAll, rfIgnoreCase]) + ' Lv ' + IntToStr(GlobalSmithingReq) + ' Book'));
		MakeCraftableV2(GlobalCraftingManual);
		
			
		if not Assigned(m_DummyEnch) then begin
			m_DummyEnch := CreateDummyEnchantment(GlobalPatchFile);
		end;

		
		// 2. Loop through every individual record in the group
		for i := 0 to ElementCount(GroupARMO) - 1 do begin
			CurrentRecord := ElementByIndex(GroupARMO, i);
			GlobalProcessedRecords := GlobalProcessedRecords + 1;
			AddMessage('      Processing: ' + EditorID(CurrentRecord));
			
			m_NewRecord := fOverrideRecordToPatch(CurrentRecord, GlobalPatchFile, (StringReplace(GlobalOutfitMaterial, 'ArmorMaterial', '', [rfReplaceAll, rfIgnoreCase]) + ' Lv ' + IntToStr(GlobalSmithingReq) + ' '));
			
			// In Skyrim, if a modder leaves slot 34 (Forearms) active on a Cuirass (slot 32),
			// the game engine treats it as "occupying" the forearm slot, which causes those annoying conflicts with dedicated gauntlets or bracers.
			fRemoveCombinedFlags(m_NewRecord);
			
			m_Slots := GetFirstPersonFlags(m_NewRecord);
			
			// Classification & Cleanup
			fKeywordsSetUp(m_NewRecord, m_Slots);

			// Material Logic: Heavy/Light/Clothing
			SetArmorType(m_NewRecord);
			
			// Stat Balancing
			m_ArmorRating := GetVanillaAR(m_NewRecord, m_Slots);  
			SetElementEditValues(m_NewRecord, 'DNAM - Armor Rating', FloatToStr(m_ArmorRating));
			
			m_ArmorWeight := GetVanillaAWeight(m_NewRecord, m_Slots); 
			SetElementEditValues(m_NewRecord, 'DATA\Weight', FloatToStr(m_ArmorWeight));
			
			m_ArmorPrice := Round(GetVanillaAPrice(m_NewRecord, m_Slots)); 
			SetElementEditValues(m_NewRecord, 'DATA\Value', IntToStr(m_ArmorPrice));
			
			// Finalization
			fAddEnchProtection(m_NewRecord, m_DummyEnch);
			
			// Crafting
			MakeCraftableV2(m_NewRecord);
			
			// Tempering: Block Clothing, Jewelry and Visual Slots
			if (IsVisualSlot(m_Slots) = False) then begin
				fMakeTemperable(m_NewRecord);
			end;
			
		end;
		
	end else begin
		AddMessage('   -> No ARMO records found in this file.');
	end;
end;

{========================================================}
{             PROCESS WEAPON RECORDS IN FILE             }
{========================================================}
procedure fProcessWeaponRecords(m_f: IInterface);
var
	GroupWEAP, CurrentRecord: IInterface;
	i: Integer;
	m_NewRecord: IInterface;
	// Weapons
	m_WeaponDamage: integer;
	m_WeaponPrice: Integer;
	m_WeaponWeight: Double; // Weights should be Double/Float
begin
	// 1. Locate the WEAP (Weapon) category in this specific file
	GroupWEAP := GroupBySignature(m_f, 'WEAP');

	if Assigned(GroupWEAP) then begin
		AddMessage('   -> Scanning ' + IntToStr(ElementCount(GroupWEAP)) + ' Weapon records...');

		// 2. Loop through every individual record in the group
		for i := 0 to ElementCount(GroupWEAP) - 1 do begin
			CurrentRecord := ElementByIndex(GroupWEAP, i);

			// 3. Logic Application
			AddMessage('      Processing Weapon: ' + EditorID(CurrentRecord));
			
			m_NewRecord := fOverrideRecordToPatch(CurrentRecord, GlobalPatchFile, ('Weapon Lv ' + IntToStr(GlobalSmithingReq) + ' '));
			
			//Standardize Weapon Keywords (VendorItemWeapon, etc.)
			fKeywordsSetUp(m_NewRecord, '');
			
			m_WeaponDamage := GetVanillaWDamage(m_NewRecord);
			SetElementEditValues(m_NewRecord, 'DATA\Damage', IntToStr(m_WeaponDamage));
			//AddMessage(Name(selectedRecord) + ' TOTAL DAMAGE = ' + FloatToStr(GetVanillaWDamage(selectedRecord)));
			
			m_WeaponPrice := GetVanillaWPrice(m_NewRecord);
			SetElementEditValues(m_NewRecord, 'DATA\Value', IntToStr(m_WeaponPrice));

			m_WeaponWeight := GetVanillaWWeight(m_NewRecord);
			SetElementEditValues(m_NewRecord, 'DATA\Weight', FloatToStr(m_WeaponWeight));
				
			MakeCraftableV2(m_NewRecord);
			fMakeTemperable(m_NewRecord);	
				
		end;
	end else begin
		AddMessage('   -> No WEAP records found in this file.');
	end;
end;

{========================================================}
{            NULLIFY CLUTTER CRAFTING RECIPES            }
{========================================================}
procedure fNullifyOriginalRecipes(m_fSource: IInterface; m_fPatch: IInterface);
var
	m_gCOBJ, m_eCurrent, m_eOverride: IInterface;
	i: Integer;
begin
	m_gCOBJ := GroupBySignature(m_fSource, 'COBJ');
	if not Assigned(m_gCOBJ) then Exit;

	AddMessage('   -> Neutralizing all original recipes (Crafting & Tempering)...');

	for i := 0 to ElementCount(m_gCOBJ) - 1 do begin
		m_eCurrent := ElementByIndex(m_gCOBJ, i);
		
		// 1. Create the override
		m_eOverride := wbCopyElementToFile(m_eCurrent, m_fPatch, False, True);
		
		if Assigned(m_eOverride) then begin
			{ 
			  THE CLEAN KILL: 
			  Removing the BNAM (Workbench) makes the recipe "homeless".
			  It won't show up in the Forge, the Grindstone, OR the Armor Table.
			}
			SetElementEditValues(m_eOverride, 'BNAM', '');
			
			// 2. Clear conditions to ensure no background script checks trigger
			if ElementExists(m_eOverride, 'Conditions') then
				RemoveElement(m_eOverride, 'Conditions');

			AddMessage('      [Disabled] ' + EditorID(m_eCurrent));
		end;
	end;
end;

{========================================================}
{              ASSIGN GLOBAL OUTFIT MATERIAL             }
{========================================================}
function fAssignGlobalMaterial(m_sMatCode: string): Boolean;
begin
	Result := True;
	GlobalOutfitMaterial := '';
	
	// LIGHT ARMORS
	if (m_sMatCode = 'Lr') then begin GlobalOutfitMaterial := 'ArmorMaterialLeather'; Exit; end;
	if (m_sMatCode = 'Sd') then begin GlobalOutfitMaterial := 'ArmorMaterialScaled'; Exit; end;
	if (m_sMatCode = 'En') then begin GlobalOutfitMaterial := 'ArmorMaterialElven'; Exit; end;
	if (m_sMatCode = 'Gs') then begin GlobalOutfitMaterial := 'ArmorMaterialGlass'; Exit; end;
	if (m_sMatCode = 'De') then begin GlobalOutfitMaterial := 'ArmorMaterialDragonscale'; Exit; end;

	// HEAVY ARMORS
	if (m_sMatCode = 'In') then begin GlobalOutfitMaterial := 'ArmorMaterialIron'; Exit; end;
	if (m_sMatCode = 'Sl') then begin GlobalOutfitMaterial := 'ArmorMaterialSteel'; Exit; end;
	if (m_sMatCode = 'Dn') then begin GlobalOutfitMaterial := 'ArmorMaterialDwarven'; Exit; end;
	if (m_sMatCode = 'Se') then begin GlobalOutfitMaterial := 'ArmorMaterialSteelPlate'; Exit; end;
	if (m_sMatCode = 'Oh') then begin GlobalOutfitMaterial := 'ArmorMaterialOrcish'; Exit; end;
	if (m_sMatCode = 'Ey') then begin GlobalOutfitMaterial := 'ArmorMaterialEbony'; Exit; end;
	if (m_sMatCode = 'Dc') then begin GlobalOutfitMaterial := 'ArmorMaterialDaedric'; Exit; end;
	if (m_sMatCode = 'Dp') then begin GlobalOutfitMaterial := 'ArmorMaterialDragonplate'; Exit; end;
	
	// If the code reaches this point, no match was found
	Result := False;
	GlobalOutfitMaterial := ''; // Safety reset
	AddMessage('   ERROR: Unknown Material Code: ' + m_sMatCode);
end;

{========================================================}
{ SLOT LOGIC                                             }
{========================================================}
function GetFirstPersonFlags(armorRecord: IInterface): string;
var
	bipedFlagsElement: IInterface;
	bipedFlags: Cardinal;
begin
	bipedFlagsElement := ElementByPath(armorRecord, 'BOD2');
	bipedFlags := GetElementNativeValues(bipedFlagsElement, 'First Person Flags');
    // Check for slots
	Result := '';
	{ CORE SLOTS }
	if (bipedFlags and $00000001) <> 0 then Result := Result + 'Head ';      { 30 }
	if (bipedFlags and $00000002) <> 0 then Result := Result + 'Hair ';      { 31 }
	if (bipedFlags and $00000004) <> 0 then Result := Result + 'Body ';      { 32 }
	if (bipedFlags and $00000008) <> 0 then Result := Result + 'Hands ';     { 33 }
	if (bipedFlags and $00000010) <> 0 then Result := Result + 'Forearms ';  { 34 }
	if (bipedFlags and $00000020) <> 0 then Result := Result + 'Amulet ';    { 35 }
	if (bipedFlags and $00000040) <> 0 then Result := Result + 'Ring ';      { 36 }
	if (bipedFlags and $00000080) <> 0 then Result := Result + 'Feet ';      { 37 }
	if (bipedFlags and $00000100) <> 0 then Result := Result + 'Calves ';    { 38 }
	if (bipedFlags and $00000200) <> 0 then Result := Result + 'Shield ';    { 39 }

	{ MODDER SLOTS (Standard Community Usage) }
	if (bipedFlags and $00000400) <> 0 then Result := Result + 'Tail ';      { 40 }
	if (bipedFlags and $00000800) <> 0 then Result := Result + 'LongHair ';  { 41 }
	if (bipedFlags and $00001000) <> 0 then Result := Result + 'Circlet ';   { 42 }
	if (bipedFlags and $00002000) <> 0 then Result := Result + 'Ears ';      { 43 }
	if (bipedFlags and $00004000) <> 0 then Result := Result + 'Cape ';      { 44 }
	if (bipedFlags and $00008000) <> 0 then Result := Result + 'Misc45 ';    { 45 }
	if (bipedFlags and $00010000) <> 0 then Result := Result + 'Misc46 ';    { 46 }
	if (bipedFlags and $00020000) <> 0 then Result := Result + 'Backpack ';  { 47 }
	if (bipedFlags and $00040000) <> 0 then Result := Result + 'Misc48 ';    { 48 }
	if (bipedFlags and $00080000) <> 0 then Result := Result + 'Misc49 ';    { 49 }
	if (bipedFlags and $00100000) <> 0 then Result := Result + 'Misc50 ';    { 50 }
	if (bipedFlags and $00200000) <> 0 then Result := Result + 'Misc51 ';    { 51 }
	if (bipedFlags and $00400000) <> 0 then Result := Result + 'Misc52 ';    { 52 }
	if (bipedFlags and $00800000) <> 0 then Result := Result + 'Misc53 ';    { 53 }
	if (bipedFlags and $01000000) <> 0 then Result := Result + 'Misc54 ';    { 54 }
	if (bipedFlags and $02000000) <> 0 then Result := Result + 'Misc55 ';    { 55 }
	if (bipedFlags and $04000000) <> 0 then Result := Result + 'Misc56 ';    { 56 }
	if (bipedFlags and $08000000) <> 0 then Result := Result + 'Misc57 ';    { 57 }
	if (bipedFlags and $10000000) <> 0 then Result := Result + 'Misc58 ';    { 58 }
	if (bipedFlags and $20000000) <> 0 then Result := Result + 'Misc59 ';    { 59 }
	if (bipedFlags and $40000000) <> 0 then Result := Result + 'Misc60 ';    { 60 }
	if (bipedFlags and $80000000) <> 0 then Result := Result + 'Misc61 ';    { 61 }
		
	//AddMessage('Slot = ' + IntToHex(bipedFlags, 8) + ' ' + Result);
	
end;

procedure fRemoveCombinedFlags(armorRecord: IInterface);
var
	bipedFlagsElement: IInterface;
	bipedFlags: Cardinal;
	modified: Boolean;
begin
	bipedFlagsElement := ElementByPath(armorRecord, 'BOD2');
	if not Assigned(bipedFlagsElement) then Exit;

	bipedFlags := GetElementNativeValues(bipedFlagsElement, 'First Person Flags');
	modified := False;

	{ Check if it is a Body piece (Slot 32 / $4) }
	if (bipedFlags and $00000004) <> 0 then begin
		
		{ Remove Forearms (Slot 34 / $10) }
		if (bipedFlags and $00000010) <> 0 then begin
			bipedFlags := bipedFlags and (not $00000010);
			modified := True;
		end;

		{ Remove Amulet (Slot 35 / $20) }
		if (bipedFlags and $00000020) <> 0 then begin
			bipedFlags := bipedFlags and (not $00000020);
			modified := True;
		end;

		{ Remove Ring (Slot 36 / $40) }
		if (bipedFlags and $00000040) <> 0 then begin
			bipedFlags := bipedFlags and (not $00000040);
			modified := True;
		end;
	end;

	{ If Feet (Slot 37 / $80) is present, remove Calves (Slot 38 / $100) }
	if ((bipedFlags and $00000080) <> 0) and ((bipedFlags and $00000100) <> 0) then begin
		bipedFlags := bipedFlags and (not $00000100);
		modified := True;
	end;

	if modified then begin
		AddMessage('Stripped conflicting accessory/sub-slots from: ' + Name(armorRecord));
		SetElementNativeValues(bipedFlagsElement, 'First Person Flags', bipedFlags);
	end;
end;

function IsVisualSlot(armor: string): Boolean;
var
	slots: TStringList;
	i: Integer;
	slotName: string;
	hasGameplaySlot: Boolean;
begin
	Result := True;					// assume visual by default
	hasGameplaySlot := False;

	// Empty slot string = visual-only item
	if Trim(armor) = '' then
		Exit;

	slots := TStringList.Create;
	try
		slots.StrictDelimiter := True;
		slots.Delimiter := ' ';
		slots.DelimitedText := Trim(armor);

		for i := 0 to slots.Count - 1 do begin
			slotName := slots[i];

			// Gameplay-relevant slots
			if (slotName = 'Head')
			or (slotName = 'Body')
			or (slotName = 'Hands')
			or (slotName = 'Feet')
			or (slotName = 'Shield')
			or (slotName = 'Hair')
			or (slotName = 'Circlet')
			or ((slotName = 'Backpack') and BACKPACK_SLOT_ENCHANTABLE)
			or (slotName = 'Amulet')
			or (slotName = 'Ring')
			or (slotName = 'Ears')
			or (slotName = 'Forearms')
			then begin
				hasGameplaySlot := True;
				Break;				// one is enough
			end;
		end;
	finally
		slots.Free;
	end;

	// If at least one gameplay slot exists → NOT visual
	Result := not hasGameplaySlot;
end;

{========================================================}
{              PROTECTION FROM ENCHANTMENTS              }
{========================================================}
procedure fAddEnchProtection(e: IInterface; enc: IInterface);
var
	kw: IInterface;
	existingDesc: string;
	visualNote: string;
begin
	if not IsVisualSlot(GetFirstPersonFlags(e)) then Exit;
	
	if (FOREARMS_SLOT_ALWAYS_ENCHANTABLE and Pos(GetFirstPersonFlags(e),'Forearms ') > 0) then Exit;
	
	visualNote := 'Visual Slot: This item is for appearance only. It provides no protection and cannot be enchanted.';
	
	{ 1. Add MagicDisallowEnchanting safely }
	if not HasKeyword(e, 'MagicDisallowEnchanting') then begin
		kw := GetKeywordByEditorID('MagicDisallowEnchanting');
		if Assigned(kw) then 
			addKeyword(e, kw);
	end;

	{ 2. Handle Description }
	existingDesc := GetElementEditValues(e, 'DESC');
	if Pos(visualNote, existingDesc) = 0 then begin
		if not Assigned(ElementByPath(e, 'DESC')) then
			Add(e, 'DESC', True);
		SetElementEditValues(e, 'DESC', visualNote);
	end;

	{ 3. Enchantment Swapper Protection }
	if ADVANCED_ENCHANTMENT_PROTECTION then begin
		if Assigned(enc) then begin
			{ Check if Object Effect is missing or set to [00000000] }
			if (not Assigned(ElementByPath(e, 'EITM'))) or (FixedFormID(ElementByPath(e, 'EITM')) = 0) then begin
				
				{ Ensure the EITM field exists }
				if not Assigned(ElementByPath(e, 'EITM')) then
					Add(e, 'EITM', True);
				
				{ Set the dummy enchantment }
				SetNativeValue(ElementByPath(e, 'EITM'), FixedFormID(enc));
				
				{ Ensure EAMT exists and set to 0 }
				if not Assigned(ElementByPath(e, 'EAMT')) then
					Add(e, 'EAMT', True);
				SetElementEditValues(e, 'EAMT', '0');
			end;
		end else begin
			AddMessage('Warning: m_DummyEnch cache is empty for ' + Name(e));
		end;
	end;
end;

{========================================================}
{               MATERIAL CHECKS                          }
{========================================================}
function fIsLightArmorMaterial: Boolean;
begin
	{
	  Light materials are: 
	  Leather, Elven, Glass, Scaled, Dragonscale
	}
	Result := 
		(GlobalOutfitMaterial = 'ArmorMaterialLeather') or
		(GlobalOutfitMaterial = 'ArmorMaterialElven') or
		(GlobalOutfitMaterial = 'ArmorMaterialGlass') or
		(GlobalOutfitMaterial = 'ArmorMaterialScaled') or
		(GlobalOutfitMaterial = 'ArmorMaterialDragonscale');
end;
function fIsHeavyArmorMaterial: Boolean;
begin
	{ 
	  We check our Global variable. In Skyrim, Heavy materials are:
	  Iron, Steel, Dwarven, Orcish, Ebony, Daedric, Dragonplate, SteelPlate
	}
	Result := 
		(GlobalOutfitMaterial = 'ArmorMaterialIron') or
		(GlobalOutfitMaterial = 'ArmorMaterialSteel') or
		(GlobalOutfitMaterial = 'ArmorMaterialDwarven') or
		(GlobalOutfitMaterial = 'ArmorMaterialOrcish') or
		(GlobalOutfitMaterial = 'ArmorMaterialEbony') or
		(GlobalOutfitMaterial = 'ArmorMaterialDaedric') or
		(GlobalOutfitMaterial = 'ArmorMaterialDragonplate') or
		(GlobalOutfitMaterial = 'ArmorMaterialSteelPlate');
end;

{========================================================}
{               SET ARMOR TYPE                           }
{========================================================}
procedure SetArmorType(e: IInterface);
var
	armorTypeField: IInterface;
	Slots: string;
	bisClothing: Boolean;
	m_bIsJewelry: Boolean;
begin
	armorTypeField := ElementByPath(e, 'BOD2\Armor Type');
	Slots := GetFirstPersonFlags(e);

	{ Accessory / Visual / Jewelry Identification }
	m_bIsJewelry := (Pos('Ring ', Slots) > 0)
		or (Pos('Amulet ', Slots) > 0)
		or (Pos('Ears ', Slots) > 0);
			
	if m_bIsJewelry then begin
		SetEditValue(armorTypeField, 'Clothing');
		addKeyword(e, GetKeywordByEditorID('VendorItemJewelry'));
		addKeyword(e, GetKeywordByEditorID('ArmorJewelry'));
		addKeyword(e, GetKeywordByEditorID('JewelryExpensive'));
		Exit;
	end;

	bisClothing := (IsVisualSlot(Slots)) or (Pos('Backpack ', Slots) > 0);
		
	if bisClothing then begin
		SetEditValue(armorTypeField, 'Clothing');
		addKeyword(e, GetKeywordByEditorID('ArmorClothing'));
		addKeyword(e, GetKeywordByEditorID('VendorItemClothing'));
		Exit;
	end;
	
	if fIsHeavyArmorMaterial() then begin
		SetEditValue(armorTypeField, 'Heavy Armor');
		addKeyword(e, GetKeywordByEditorID('ArmorHeavy'));
		addKeyword(e, GetKeywordByEditorID('VendorItemArmor'));			
		Exit;
	end;
	
	if fIsLightArmorMaterial() then begin
		SetEditValue(armorTypeField, 'Light Armor');
		addKeyword(e, GetKeywordByEditorID('ArmorLight'));
		addKeyword(e, GetKeywordByEditorID('VendorItemArmor'));
		Exit;
	end;
	
end;

{========================================================}
{            PURGE ALL POTENTIAL MATERIAL TAGS           }
{========================================================}
procedure fPurgeAllMaterialKeywords(e: IInterface);
begin

	{ Initial Cleanup }
		removeKeywordV2(e, 'ArmorHelmet');
		removeKeywordV2(e, 'ArmorCuirass');
		removeKeywordV2(e, 'ArmorGauntlets');
		removeKeywordV2(e, 'ArmorBoots');
		removeKeywordV2(e, 'ArmorShield');
		removeKeywordV2(e, 'ArmorHeavy');
		removeKeywordV2(e, 'ArmorLight');
		removeKeywordV2(e, 'ArmorClothing');
		
	{ Vanilla & Common Materials }
	removeKeywordV2(e, 'ArmorMaterialLeather');
	removeKeywordV2(e, 'ArmorMaterialScaled');
	removeKeywordV2(e, 'ArmorMaterialElven');
	removeKeywordV2(e, 'ArmorMaterialElvenGilded');
	removeKeywordV2(e, 'ArmorMaterialGlass');
	removeKeywordV2(e, 'ArmorMaterialDragonscale');
	removeKeywordV2(e, 'ArmorMaterialIron');
	removeKeywordV2(e, 'ArmorMaterialIronBanded');
	removeKeywordV2(e, 'ArmorMaterialSteel');
	removeKeywordV2(e, 'ArmorMaterialDwarven');
	removeKeywordV2(e, 'ArmorMaterialSteelPlate');
	removeKeywordV2(e, 'ArmorMaterialOrcish');
	removeKeywordV2(e, 'ArmorMaterialEbony');
	removeKeywordV2(e, 'ArmorMaterialDragonplate');
	removeKeywordV2(e, 'ArmorMaterialDaedric');
	
	{ DLC / Special Materials }
	{ removeKeywordV2(e, 'ArmorMaterialImperialLight'); }
	{ removeKeywordV2(e, 'ArmorMaterialImperialStudded'); }
	{ removeKeywordV2(e, 'ArmorMaterialImperialHeavy'); }
	{ removeKeywordV2(e, 'ArmorMaterialStormcloak'); }
	{ removeKeywordV2(e, 'DLC2ArmorMaterialBonemoldLight'); }
	{ removeKeywordV2(e, 'DLC2ArmorMaterialChitinLight'); }
	{ removeKeywordV2(e, 'DLC2ArmorMaterialChitinHeavy'); }
	{ removeKeywordV2(e, 'DLC2ArmorMaterialStalhrimLight'); }
	{ removeKeywordV2(e, 'DLC2ArmorMaterialStalhrimHeavy'); }
	{ removeKeywordV2(e, 'DLC2ArmorMaterialNordicHeavy'); }
	
	{ Faction / Unique Materials }
	{ removeKeywordV2(e, 'ArmorMaterialBlades'); }
	{ removeKeywordV2(e, 'ArmorMaterialThievesGuild'); }
	{ removeKeywordV2(e, 'ArmorMaterialThievesGuildLeader'); }
	{ removeKeywordV2(e, 'DLC1ArmorMaterialDawnguard'); }

	{ Safety: Ensure the global material is also removed before re-adding }
	if GlobalOutfitMaterial <> '' then
		removeKeywordV2(e, GlobalOutfitMaterial);
end;

{========================================================}
{                    KEYWORDS                            }
{========================================================}
procedure fKeywordsSetUp(e: IInterface; m_sSlots: string);
var
	kw: IInterface;
	m_sSig: string;
	m_bIsJewelry, m_bIsClothing: Boolean;
begin
	m_sSig := Signature(e);

	{ 1. WEAPON LOGIC }
	if m_sSig = 'WEAP' then begin
		if not HasKeyword(e, 'VendorItemWeapon') then begin
			kw := GetKeywordByEditorID('VendorItemWeapon');
			if Assigned(kw) then addKeyword(e, kw);
		end;
		Exit;
	end;

	{ 2. ARMOR LOGIC }
	if m_sSig = 'ARMO' then begin
		
		// Clean record from common Keywords
		fPurgeAllMaterialKeywords(e);

		{ Inject the one true material defined by the file name }
		kw := GetKeywordByEditorID(GlobalOutfitMaterial);
		if  Assigned(kw) then begin
			if not IsVisualSlot(GetFirstPersonFlags(e)) then begin
				addKeyword(e, kw);
				kw := null;
			end;
		end;

		{ SHIELD (Slot 39) }
		if Pos('Shield ', m_sSlots) > 0 then begin
			kw := GetKeywordByEditorID('ArmorShield');
			if Assigned(kw) then addKeyword(e, kw);
			Exit;
		end;

		{ BODY }
		if Pos('Body ', m_sSlots) > 0 then begin
			kw := GetKeywordByEditorID('ArmorCuirass');
			if Assigned(kw) then addKeyword(e, kw);
			Exit;
		end;

		{ HEAD / HAIR / CIRCLET }
		if (Pos('Head ', m_sSlots) > 0) or (Pos('Hair ', m_sSlots) > 0) or (Pos('Circlet ', m_sSlots) > 0) then begin
			kw := GetKeywordByEditorID('ArmorHelmet');
			if Assigned(kw) then addKeyword(e, kw);
			Exit;
		end;

		{ HANDS / FOREARMS }
		if (Pos('Hands ', m_sSlots) > 0) or ((Pos('Forearms ', m_sSlots) > 0)) then begin
			kw := GetKeywordByEditorID('ArmorGauntlets');
			if Assigned(kw) then addKeyword(e, kw);
			AddFistKeywords(e);
			Exit;
		end;

		{ FEET }
		if Pos('Feet ', m_sSlots) > 0 then begin
			kw := GetKeywordByEditorID('ArmorBoots');
			if Assigned(kw) then addKeyword(e, kw);
			Exit;
		end;
	end;
end;
{========================================================}
{               ADD FIST KEYWORDS                        }
{========================================================}
procedure AddFistKeywords(e: IInterface);
var
	kwName: string;
begin
	{ Only apply to items that act as real Gauntlets }
	if not HasKeyword(e, 'ArmorGauntlets') then Exit;

	kwName := '';
	if HasKeyword(e, 'ArmorMaterialSteel') or HasKeyword(e, 'ArmorMaterialSteelPlate') then
		kwName := 'PerkFistsSteel'
	else if HasKeyword(e, 'ArmorMaterialDwarven') then
		kwName := 'PerkFistsDwarven'
	else if HasKeyword(e, 'ArmorMaterialOrcish') then
		kwName := 'PerkFistsOrcish'
	else if HasKeyword(e, 'ArmorMaterialEbony') then
		kwName := 'PerkFistsEbony'
	else if HasKeyword(e, 'ArmorMaterialDaedric') then
		kwName := 'PerkFistsDaedric'
	else if HasKeyword(e, 'ArmorMaterialDragonplate') then
		kwName := 'PerkFistsDragonplate';

	if kwName <> '' then
		addKeyword(e, GetKeywordByEditorID(kwName));
end;

{========================================================}
{            GET VANILLA WEAPON DAMAGE                   }
{========================================================}
function GetVanillaWDamage(e: IInterface): Integer;
var
	template: IInterface;
	isDagger, isSword, isWarAxe, isMace, isGreatsword, isBattleaxe, isWarhammer, isBow: Boolean;
begin
	Result := 0;

	{ 1. Follow Template (CNAM) for AE records }
	template := LinksTo(ElementBySignature(e, 'CNAM'));
	if Assigned(template) then begin
		e := template;
	end;

	{ 2. Pre-cache Weapon Types for cleaner logic }
	isDagger     := HasKeyword(e, 'WeapTypeDagger');
	isSword      := HasKeyword(e, 'WeapTypeSword');
	isWarAxe     := HasKeyword(e, 'WeapTypeWarAxe');
	isMace       := HasKeyword(e, 'WeapTypeMace');
	isGreatsword := HasKeyword(e, 'WeapTypeGreatsword');
	isBattleaxe  := HasKeyword(e, 'WeapTypeBattleaxe');
	isWarhammer  := HasKeyword(e, 'WeapTypeWarhammer');
	isBow        := HasKeyword(e, 'WeapTypeBow');

	{ 3. Steel Logic }
	if HasKeyword(e, 'WeapMaterialSteel') then begin
		if isDagger     then Result := 5;
		if isSword      then Result := 8;
		if isWarAxe     then Result := 9;
		if isMace       then Result := 10;
		if isGreatsword then Result := 17;
		if isBattleaxe  then Result := 18;
		if isWarhammer  then Result := 20;
		if isBow        then Result := 7;
	end;

	{ 4. Dwarven Logic }
	if HasKeyword(e, 'WeapMaterialDwarven') then begin
		if isDagger     then Result := 7;
		if isSword      then Result := 10;
		if isWarAxe     then Result := 11;
		if isMace       then Result := 12;
		if isGreatsword then Result := 19;
		if isBattleaxe  then Result := 20;
		if isWarhammer  then Result := 22;
		if isBow        then Result := 12;
	end;

	{ 5. Elven Logic }
	if HasKeyword(e, 'WeapMaterialElven') then begin
		if isDagger     then Result := 8;
		if isSword      then Result := 11;
		if isWarAxe     then Result := 12;
		if isMace       then Result := 13;
		if isGreatsword then Result := 20;
		if isBattleaxe  then Result := 21;
		if isWarhammer  then Result := 23;
		if isBow        then Result := 13;
	end;

	{ 6. Orcish Logic }
	if HasKeyword(e, 'WeapMaterialOrcish') then begin
		if isDagger     then Result := 6;
		if isSword      then Result := 9;
		if isWarAxe     then Result := 10;
		if isMace       then Result := 11;
		if isGreatsword then Result := 18;
		if isBattleaxe  then Result := 19;
		if isWarhammer  then Result := 21;
		if isBow        then Result := 10;
	end;

	{ 7. Glass Logic }
	if HasKeyword(e, 'WeapMaterialGlass') then begin
		if isDagger     then Result := 9;
		if isSword      then Result := 12;
		if isWarAxe     then Result := 13;
		if isMace       then Result := 14;
		if isGreatsword then Result := 21;
		if isBattleaxe  then Result := 22;
		if isWarhammer  then Result := 24;
		if isBow        then Result := 15;
	end;

	{ 8. Ebony Logic }
	if HasKeyword(e, 'WeapMaterialEbony') then begin
		if isDagger     then Result := 10;
		if isSword      then Result := 13;
		if isWarAxe     then Result := 14;
		if isMace       then Result := 15;
		if isGreatsword then Result := 22;
		if isBattleaxe  then Result := 23;
		if isWarhammer  then Result := 25;
		if isBow        then Result := 17;
	end;

	{ 9. Daedric Logic }
	if HasKeyword(e, 'WeapMaterialDaedric') then begin
		if isDagger     then Result := 11;
		if isSword      then Result := 14;
		if isWarAxe     then Result := 15;
		if isMace       then Result := 16;
		if isGreatsword then Result := 24;
		if isBattleaxe  then Result := 25;
		if isWarhammer  then Result := 27;
		if isBow        then Result := 19;
	end;

	{ 10. Apply Final Bonus }
	if Result > 0 then begin
		Result := Result + GlobalWeaponDamageBonus;
	end;
end;
{========================================================}
{ GET VANILLA WEAPON WEIGHT                              }
{========================================================}
function GetVanillaWWeight(e: IInterface): Double;
var
	template: IInterface;
	isDagger, isSword, isWarAxe, isMace, isGreatsword, isBattleaxe, isWarhammer, isBow: Boolean;
begin
	Result := 0.0;

	{ 1. Follow Template (CNAM) for AE compatibility }
	template := LinksTo(ElementBySignature(e, 'CNAM'));
	if Assigned(template) then begin
		e := template;
	end;

	{ 2. Pre-cache Weapon Types }
	isDagger     := HasKeyword(e, 'WeapTypeDagger');
	isSword      := HasKeyword(e, 'WeapTypeSword');
	isWarAxe     := HasKeyword(e, 'WeapTypeWarAxe');
	isMace       := HasKeyword(e, 'WeapTypeMace');
	isGreatsword := HasKeyword(e, 'WeapTypeGreatsword');
	isBattleaxe  := HasKeyword(e, 'WeapTypeBattleaxe');
	isWarhammer  := HasKeyword(e, 'WeapTypeWarhammer');
	isBow        := HasKeyword(e, 'WeapTypeBow');

	{ 3. STEEL }
	if HasKeyword(e, 'WeapMaterialSteel') then begin
		if isDagger     then Result := 2.5;
		if isSword      then Result := 10.0;
		if isWarAxe     then Result := 11.0;
		if isMace       then Result := 13.0;
		if isGreatsword then Result := 17.0;
		if isBattleaxe  then Result := 21.0;
		if isWarhammer  then Result := 25.0;
		if isBow        then Result := 8.0;
	end;

	{ 4. DWARVEN }
	if HasKeyword(e, 'WeapMaterialDwarven') then begin
		if isDagger     then Result := 3.5;
		if isSword      then Result := 12.0;
		if isWarAxe     then Result := 14.0;
		if isMace       then Result := 16.0;
		if isGreatsword then Result := 19.0;
		if isBattleaxe  then Result := 23.0;
		if isWarhammer  then Result := 27.0;
		if isBow        then Result := 10.0;
	end;

	{ 5. ELVEN }
	if HasKeyword(e, 'WeapMaterialElven') then begin
		if isDagger     then Result := 4.0;
		if isSword      then Result := 9.0;
		if isWarAxe     then Result := 10.0;
		if isMace       then Result := 12.0;
		if isGreatsword then Result := 16.0;
		if isBattleaxe  then Result := 20.0;
		if isWarhammer  then Result := 23.0;
		if isBow        then Result := 12.0;
	end;

	{ 6. ORCISH }
	if HasKeyword(e, 'WeapMaterialOrcish') then begin
		if isDagger     then Result := 3.0;
		if isSword      then Result := 11.0;
		if isWarAxe     then Result := 12.0;
		if isMace       then Result := 14.0;
		if isGreatsword then Result := 18.0;
		if isBattleaxe  then Result := 22.0;
		if isWarhammer  then Result := 26.0;
		if isBow        then Result := 9.0;
	end;

	{ 7. GLASS }
	if HasKeyword(e, 'WeapMaterialGlass') then begin
		if isDagger     then Result := 4.5;
		if isSword      then Result := 12.0;
		if isWarAxe     then Result := 13.0;
		if isMace       then Result := 15.0;
		if isGreatsword then Result := 19.0;
		if isBattleaxe  then Result := 22.0;
		if isWarhammer  then Result := 25.0;
		if isBow        then Result := 14.0;
	end;

	{ 8. EBONY }
	if HasKeyword(e, 'WeapMaterialEbony') then begin
		if isDagger     then Result := 5.0;
		if isSword      then Result := 15.0;
		if isWarAxe     then Result := 16.0;
		if isMace       then Result := 19.0;
		if isGreatsword then Result := 22.0;
		if isBattleaxe  then Result := 25.0;
		if isWarhammer  then Result := 28.0;
		if isBow        then Result := 16.0;
	end;

	{ 9. DAEDRIC }
	if HasKeyword(e, 'WeapMaterialDaedric') then begin
		if isDagger     then Result := 6.0;
		if isSword      then Result := 16.0;
		if isWarAxe     then Result := 18.0;
		if isMace       then Result := 20.0;
		if isGreatsword then Result := 23.0;
		if isBattleaxe  then Result := 27.0;
		if isWarhammer  then Result := 31.0;
		if isBow        then Result := 18.0;
	end;
	
	{ 10. Apply Final Bonus }
	if (Result > GlobalWeaponWeightBonus + 1.0) and (GlobalWeaponWeightBonus > 0.0) then begin
		Result := Result - GlobalWeaponWeightBonus;
	end;
end;
{========================================================}
{ GET VANILLA WEAPON PRICE                               }
{========================================================}
function GetVanillaWPrice(e: IInterface): Integer;
var
	template: IInterface;
	isDagger, isSword, isWarAxe, isMace, isGreatsword, isBattleaxe, isWarhammer, isBow: Boolean;
begin
	Result := 0;

	{ 1. Follow Template (CNAM) for AE compatibility }
	template := LinksTo(ElementBySignature(e, 'CNAM'));
	if Assigned(template) then begin
		e := template;
	end;

	{ 2. Pre-cache Weapon Types }
	isDagger     := HasKeyword(e, 'WeapTypeDagger');
	isSword      := HasKeyword(e, 'WeapTypeSword');
	isWarAxe     := HasKeyword(e, 'WeapTypeWarAxe');
	isMace       := HasKeyword(e, 'WeapTypeMace');
	isGreatsword := HasKeyword(e, 'WeapTypeGreatsword');
	isBattleaxe  := HasKeyword(e, 'WeapTypeBattleaxe');
	isWarhammer  := HasKeyword(e, 'WeapTypeWarhammer');
	isBow        := HasKeyword(e, 'WeapTypeBow');

	{ 3. STEEL }
	if HasKeyword(e, 'WeapMaterialSteel') then begin
		if isDagger     then Result := 15;
		if isSword      then Result := 45;
		if isWarAxe     then Result := 55;
		if isMace       then Result := 65;
		if isGreatsword then Result := 90;
		if isBattleaxe  then Result := 100;
		if isWarhammer  then Result := 110;
		if isBow        then Result := 45;
	end;

	{ 4. DWARVEN }
	if HasKeyword(e, 'WeapMaterialDwarven') then begin
		if isDagger     then Result := 85;
		if isSword      then Result := 270;
		if isWarAxe     then Result := 300;
		if isMace       then Result := 350;
		if isGreatsword then Result := 485;
		if isBattleaxe  then Result := 525;
		if isWarhammer  then Result := 600;
		if isBow        then Result := 270;
	end;

	{ 5. ELVEN }
	if HasKeyword(e, 'WeapMaterialElven') then begin
		if isDagger     then Result := 95;
		if isSword      then Result := 235;
		if isWarAxe     then Result := 280;
		if isMace       then Result := 330;
		if isGreatsword then Result := 470;
		if isBattleaxe  then Result := 520;
		if isWarhammer  then Result := 565;
		if isBow        then Result := 470;
	end;

	{ 6. ORCISH }
	if HasKeyword(e, 'WeapMaterialOrcish') then begin
		if isDagger     then Result := 75;
		if isSword      then Result := 150;
		if isWarAxe     then Result := 165;
		if isMace       then Result := 190;
		if isGreatsword then Result := 325;
		if isBattleaxe  then Result := 360;
		if isWarhammer  then Result := 445;
		if isBow        then Result := 150;
	end;

	{ 7. GLASS }
	if HasKeyword(e, 'WeapMaterialGlass') then begin
		if isDagger     then Result := 410;
		if isSword      then Result := 900;
		if isWarAxe     then Result := 980;
		if isMace       then Result := 1050;
		if isGreatsword then Result := 1435;
		if isBattleaxe  then Result := 1570;
		if isWarhammer  then Result := 1840;
		if isBow        then Result := 820;
	end;

	{ 8. EBONY }
	if HasKeyword(e, 'WeapMaterialEbony') then begin
		if isDagger     then Result := 290;
		if isSword      then Result := 725;
		if isWarAxe     then Result := 800;
		if isMace       then Result := 865;
		if isGreatsword then Result := 1150;
		if isBattleaxe  then Result := 1585;
		if isWarhammer  then Result := 1725;
		if isBow        then Result := 1440;
	end;

	{ 9. DAEDRIC }
	if HasKeyword(e, 'WeapMaterialDaedric') then begin
		if isDagger     then Result := 800;
		if isSword      then Result := 1250;
		if isWarAxe     then Result := 1500;
		if isMace       then Result := 1750;
		if isGreatsword then Result := 2500;
		if isBattleaxe  then Result := 2750;
		if isWarhammer  then Result := 4000;
		if isBow        then Result := 2500;
	end;

	{ 10. Apply Final Bonus }
	if (Result > 0) and (GlobalWeaponPriceBonus <> 0) then begin
		Result := Result + GlobalWeaponPriceBonus;
	end;
end;
{========================================================}
{ VANILLA ARMOR RATINGS WITH FOREARMS LOGIC              }
{========================================================}
function GetVanillaAR(e: IInterface; Slots: string): Float;
begin
	Result := 0;
	if HasKeyword(e, 'ArmorClothing') then Exit;

	{==================== HEAVY ====================}
	if HasKeyword(e, 'ArmorMaterialIron') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 25 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 20 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 15 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 10 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 10 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 10 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialSteel') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 31 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 24 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 17 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 12 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 12 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 12 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialDwarven') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 34 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 26 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 18 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 13 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 13 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 13 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialOrcish') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 40 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 30 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 20 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 15 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 15 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 15 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;
	
	if HasKeyword(e, 'ArmorMaterialSteelPlate') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 40 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 28 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 19 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 14 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 14 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 14 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialEbony') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 43 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 32 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 21 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 16 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 16 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 16 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialDaedric') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 49 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 36 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 23 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 18 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 18 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 18 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;
	
	if HasKeyword(e, 'ArmorMaterialDragonplate') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 46 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 34 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 22 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 17 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 17 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 17 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;

	{==================== LIGHT ====================}

	if HasKeyword(e, 'ArmorMaterialLeather') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 26 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 18 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 12 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 7 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 7 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 7 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialScaled') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 32 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 20 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 14 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 9 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 9 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 9 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialElven') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 29 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 21 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 13 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 8 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 8 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 8 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialGlass') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 38 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 27 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 16 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 11 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 11 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 11 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialDragonscale') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 41 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 29 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 17 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 12 + GlobalArmorBonus; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 12 + GlobalArmorBonus; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0
			else Result := 12 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			Exit;
		end;
		Exit;
	end;
end;
{========================================================}
{ GET VANILLA ARMOR WEIGHT (ENCUMBRANCE)                 }
{========================================================}
function GetVanillaAWeight(e: IInterface; Slots: string): Float;
var
	m_WeightReduceHeavy: Float;
begin
	Result := VISUAL_SLOT_WEIGHT;
	m_WeightReduceHeavy := 9; 
	if HasKeyword(e, 'ArmorClothing') then Exit;

	{==================== HEAVY ====================}
	if HasKeyword(e, 'ArmorMaterialIron') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 30 - m_WeightReduceHeavy; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 12; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 6; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 5; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 5; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 5 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialSteel') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 35 - m_WeightReduceHeavy; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 12; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 5; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 4; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 4; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 4 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialDwarven') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 45 - m_WeightReduceHeavy; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 15; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 12; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 8; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 8; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 8 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialOrcish') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 35 - m_WeightReduceHeavy; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 14; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 8; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 7; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 7; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 7 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialSteelPlate') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 38 - m_WeightReduceHeavy; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 12; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 9; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 6; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 6; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 6 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialEbony') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 38 - m_WeightReduceHeavy; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 14; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 10; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 7; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 7; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 7 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialDaedric') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 50 - m_WeightReduceHeavy; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 15; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 10; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 6; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 6; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 6 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialDragonplate') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 40 - m_WeightReduceHeavy; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 12; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 8; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 8; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 8; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 8 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;

	{==================== LIGHT ====================}
	if HasKeyword(e, 'ArmorMaterialLeather') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 6; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 4; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 2; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 2; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 2; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 2 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialScaled') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 6; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 6; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 2; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 2; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 2; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 2 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialElven') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 4; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 4; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 1; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 1; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 1; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 1 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialGlass') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 7; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 6; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 2; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 2; Exit; end; { Fixed from 11 to 2 }
		if HasKeyword(e, 'ArmorBoots') then begin Result := 2; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 2 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialDragonscale') then begin
		if HasKeyword(e, 'ArmorCuirass') then begin Result := 10; Exit; end;
		if HasKeyword(e, 'ArmorShield') then begin Result := 6; Exit; end;
		if HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin Result := 4; Exit; end;
		if HasKeyword(e, 'ArmorGauntlets') then begin Result := 3; Exit; end;
		if HasKeyword(e, 'ArmorBoots') then begin Result := 3; Exit; end;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 3 / GlobalForearmsDebuffMultiplier;
			Exit;
		end;
		Exit;
	end;
	
end;

function GetVanillaAPrice(e: IInterface; Slots: string): Float;
begin
	Result := 0.0;
	if HasKeyword(e, 'ArmorClothing') then begin
		Result := 25 + GlobalArmorPriceBonus;
		Exit;
	end;

	{==================== HEAVY ====================}
	if HasKeyword(e, 'ArmorMaterialIron') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 125;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 60;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 60;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 25;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 25;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 25;
		end;
		
		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialSteel') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 275;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 150;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 125;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 55;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 55;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 55;
		end;

		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialDwarven') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 400;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 225;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 200;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 85;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 85;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 85;
		end;

		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialOrcish') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 1000;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 500;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 500;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 200;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 200;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 200;
		end;

		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialSteelPlate') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 625;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 150;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 300;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 125;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 125;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 125;
		end;

		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialEbony') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 1500;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 750;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 750;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 275;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 275;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 275;
		end;

		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialDaedric') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 3200;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 1600;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 1600;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 625;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 625;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 625;
		end;

		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialDragonplate') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 2125;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 1050;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 1050;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 425;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 425;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 425;
		end;

		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;

	{==================== LIGHT ====================}
	if HasKeyword(e, 'ArmorMaterialLeather') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 125;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 40;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 60;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 25;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 25;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 25;
		end;

		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialScaled') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 350;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 175;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 175;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 70;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 70;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 70;
		end;

		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialElven') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 225;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 115;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 110;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 45;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 45;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 45;
		end;

		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialGlass') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 900;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 450;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 450;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 190;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 190;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 190;
		end;

		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;

	if HasKeyword(e, 'ArmorMaterialDragonscale') then begin
		if HasKeyword(e, 'ArmorCuirass') then Result := 1500;
		if (Result = 0) and HasKeyword(e, 'ArmorShield') then Result := 750;
		if (Result = 0) and (HasKeyword(e, 'ArmorHelmet') or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0)) then Result := 750;
		if (Result = 0) and HasKeyword(e, 'ArmorGauntlets') then Result := 300;
		if (Result = 0) and HasKeyword(e, 'ArmorBoots') then Result := 300;
		if (Result = 0) and (Pos('Forearms ', Slots) > 0) then begin
			if GlobalDisableForearmsARBonus then Result := 0 else Result := 300;
		end;

		if Result > 0 then Result := Result + GlobalArmorPriceBonus;
		Exit;
	end;
end;

{========================================================}
{            ADD SMITHING SKILL CONDITION                }
{========================================================}
procedure addSkillCondition(recipe: IInterface; skillLevel: Integer);
var
	conditions, cond: IInterface;
begin
	if skillLevel <= 0 then Exit;

	{ 1. Get or create the Conditions list }
	conditions := ElementByPath(recipe, 'Conditions');
	if not Assigned(conditions) then begin
		conditions := Add(recipe, 'Conditions', True);
		{ When Add creates a collection, it usually creates the first item [0] automatically }
		cond := ElementByIndex(conditions, 0);
	end else begin
		{ If Conditions already existed (e.g. from a Perk check), add a new one }
		cond := ElementAssign(conditions, HighInteger, nil, False);
	end;

	{ 2. Set the Logic: Greater than or Equal to }
	{ Note: 00000000 is usually GE. 11000000 is Equal + Run on Subject }
	SetElementEditValues(cond, 'CTDA\Type', '11000000'); 
	
	{ 3. Set the Skill Value }
	SetElementEditValues(cond, 'CTDA\Comparison Value', FloatToStr(skillLevel));
	
	{ 4. Set the Function }
	SetElementEditValues(cond, 'CTDA\Function', 'GetBaseActorValue');
	
	{ 5. Set the Parameter }
	SetElementEditValues(cond, 'CTDA\Parameter #1', 'Smithing');
end;

{========================================================}
{            ADD PLAYER LEVEL RECIPE CONDITION           }
{========================================================}
procedure fAddPlayerLevelCondition(m_recipe: IInterface; m_iLevel: Integer);
var
	conditions, cond: IInterface;
begin
	if m_iLevel <= 0 then Exit;

	// 1. Get or create the Conditions list
	conditions := ElementByPath(m_recipe, 'Conditions');
	
	if not Assigned(conditions) then begin
		// Create the list and the first entry [0]
		Add(m_recipe, 'Conditions', True);
		conditions := ElementByPath(m_recipe, 'Conditions');
		cond := ElementByIndex(conditions, 0);
	end else begin
		// Append a new condition to the existing list
		cond := ElementAssign(conditions, HighInteger, nil, False);
	end;

	// 2. Set the Logic: Greater than or Equal to (GE)
	// '11000000' = Comparison: GE / Flags: Run on Subject
	SetElementEditValues(cond, 'CTDA\Type', '11000000'); 
	
	// 3. Set the Level Value
	SetElementEditValues(cond, 'CTDA\Comparison Value', IntToStr(m_iLevel));
	
	// 4. Set the Function to GetLevel
	SetElementEditValues(cond, 'CTDA\Function', 'GetLevel');
	
	// 5. Parameter #1 is not needed for GetLevel, so we ensure it is empty/null
	SetElementEditValues(cond, 'CTDA\Parameter #1', '00 00 00 00');
end;

procedure addFemaleCondition(recipe: IInterface);
var
	conditions, cond: IInterface;
begin
	if FOR_FEMALE_ONLY then begin
		{ 1. Get or create the Conditions list }
		conditions := ElementByPath(recipe, 'Conditions');
		if not Assigned(conditions) then begin
			conditions := Add(recipe, 'Conditions', True);
			cond := ElementByIndex(conditions, 0);
		end else begin
			cond := ElementAssign(conditions, HighInteger, nil, False);
		end;

		{ 2. Set Logic: Equal + Run on Subject }
		{ 11000000 = Equal, Subject }
		SetElementEditValues(cond, 'CTDA\Type', '11000000');

		{ 3. Comparison Value: Female }
		SetElementEditValues(cond, 'CTDA\Comparison Value', '1');

		{ 4. Function }
		SetElementEditValues(cond, 'CTDA\Function', 'GetIsSex');

		{ 5. Parameter #1: 1 = Female }
		SetElementEditValues(cond, 'CTDA\Parameter #1', '1');
	end;
end;

function CopyBookAsNewRecord(destFile: IInterface; sourceFormID: string; newEditorID: string): IInterface;
var
	sourceBook, newBook: IInterface;
	mgefGroup: IInterface;
	m_BookName, m_BookDesc, m_ArmorMaterial: string;
begin
	Result := nil;
	
	{ 1. Check if the book already exists in the destination file to avoid duplicates }
	Result := MainRecordByEditorID(GroupBySignature(destFile, 'BOOK'), newEditorID);
	if Assigned(Result) then Exit;

	{ 2. Resolve source (Skyrim.esm) }
	sourceBook := RecordByFormID(FileByIndex(0), StrToInt64('$' + sourceFormID), True);
	
	if not Assigned(sourceBook) then begin
		AddMessage('ERROR: Source Book ' + sourceFormID + ' not found in Skyrim.esm');
		Exit;
	end;

	{ 3. Copy as NEW Record }
	{ Parameter 3: True = asNew (This generates a NEW FormID in your ESP) }
	{ Parameter 4: True = copyValues (Copies all text/data from the source) }
	m_ArmorMaterial := StringReplace(GlobalOutfitMaterial, 'ArmorMaterial', '', [rfReplaceAll, rfIgnoreCase]);
	newBook := wbCopyElementToFile(sourceBook, destFile, True, True);
	
	if Assigned(newBook) then begin
		{ 4. Set the internal EditorID (Technical Name) }
		SetElementEditValues(newBook, 'EDID', newEditorID);
		
		m_BookName := newEditorID;
		{ 5. Set the Display Name (Name seen by Player) }
		SetElementEditValues(newBook, 'FULL', m_BookName);
		SetElementEditValues(newBook, 'DATA\Weight', '0.01');
		SetElementEditValues(newBook, 'DATA\Value', IntToStr(GlobalSmithingReq * CRAFTING_MANUAL_PRICE_MULTIPLIER));
		
		{ 6. Set Skill to NONE (Prevents accidental skill ups) }
		{ In the DATA sub-record, 255 represents 'None' }
		SetElementEditValues(newBook, 'DATA\Skill', 'None'); 
		
		{ This text will explain the mechanic to the player }
		m_BookDesc := 'A technical guide for crafting ' + GlobalFileName + ' ' + m_ArmorMaterial + ' outfit. ' + #13#10 + #13#10 +
		              'Keep this manual in your inventory to enable its recipes at the forge.';
		
		SetElementEditValues(newBook, 'DESC', m_BookDesc);
		
		AddMessage('Successfully created new book: ' + m_BookName);
		Result := newBook;
	end;
end;

// Creates a condition that checks if the player has exactly 1 or more of the manual in their inventory
procedure AddManualCondition(recipe: IInterface; manual: IInterface);
var
	conditions, cond: IInterface;
begin
	if not Assigned(manual) then Exit;

	conditions := ElementByPath(recipe, 'Conditions');
	if not Assigned(conditions) then
		conditions := Add(recipe, 'Conditions', True);

	{ Create new condition entry }
	cond := ElementAssign(conditions, HighInteger, nil, False);
	
	{ GetItemCount(Manual) >= 1 }
	SetElementEditValues(cond, 'CTDA\Type', '11000000'); { Equal to / Or Greater Than }
	SetElementEditValues(cond, 'CTDA\Comparison Value', '1.000000');
	SetElementEditValues(cond, 'CTDA\Function', 'GetItemCount');
	SetNativeValue(ElementByPath(cond, 'CTDA\Inventory Object'), FixedFormID(manual));
	SetElementEditValues(cond, 'CTDA\Run On', 'Subject');
end;

{ Creates a condition to hide the recipe if the player already owns the manual }
procedure AddMissingManualCondition(recipe: IInterface; manual: IInterface);
var
	conditions, cond: IInterface;
begin
	if not Assigned(manual) then Exit;

	conditions := ElementByPath(recipe, 'Conditions');
	if not Assigned(conditions) then
		conditions := Add(recipe, 'Conditions', True);

	{ Create new condition entry }
	cond := ElementAssign(conditions, HighInteger, nil, False);
	
	{ GetItemCount(Manual) == 0 }
	SetElementEditValues(cond, 'CTDA\Type', '10000000'); { Equal to }
	SetElementEditValues(cond, 'CTDA\Comparison Value', '0.000000');
	SetElementEditValues(cond, 'CTDA\Function', 'GetItemCount');
	SetNativeValue(ElementByPath(cond, 'CTDA\Inventory Object'), FixedFormID(manual));
	SetElementEditValues(cond, 'CTDA\Run On', 'Subject');
end;


// adds item record reference to the list
function addItemV2(list: IInterface; item: IInterface; amount: integer): IInterface;
var
	newItem: IInterface;
	listName: string;
begin
	Result := nil;
	
	if not Assigned(item) then begin
		AddMessage('Warning: addItem skipped because material is NULL');
		Exit;
	end;
	
	listName := Name(list);

	{ Check if index 0 is empty/null to avoid the [00000000] error }
	if (ElementCount(list) = 1) and (GetElementEditValues(ElementByIndex(list, 0), 'CNTO - Item\Item') = '') then
		newItem := ElementByIndex(list, 0)
	else
		newItem := ElementAssign(list, HighInteger, nil, False);

	{ COBJ Logic }
	if listName = 'Items' then begin
		SetElementEditValues(newItem, 'CNTO - Item\Item', IntToHex(FixedFormID(item), 8));
		SetElementEditValues(newItem, 'CNTO - Item\Count', IntToStr(amount));
	end 
	{ LVLI Logic }
	else if listName = 'Leveled List Entries' then begin
		SetElementEditValues(newItem, 'LVLO\Reference', IntToHex(FixedFormID(item), 8));
		SetElementEditValues(newItem, 'LVLO\Count', IntToStr(amount));
	end;
	
	Result := newItem;
end;

{========================================================}
{ ADD VANILLA ENCHANTMENT TO ARMOR                       }
{ EnchArmorFortifyCarry01 (0007A109)                     }
{========================================================}
procedure AddVanillaCarryWeightEnchantment(e: IInterface);
var
	enchantment: IInterface;
begin
	{ Only apply to Armor records }
	if Signature(e) <> 'ARMO' then
		Exit;

	{ Do not overwrite existing enchantment }
	if Assigned(ElementByPath(e, 'EITM')) then
		Exit;

	{ Resolve vanilla enchantment by FormID }
	enchantment := GetRecordByFormID('0007A109'); // EnchArmorFortifyCarry01
	if not Assigned(enchantment) then begin
		AddMessage('ERROR: Enchantment 0007A109 not found');
		Exit;
	end;

	{ Assign enchantment }
	SetElementEditValues(e, 'EITM', Name(enchantment));

	{ Enchantment charge / amount (vanilla = 1) }
	SetElementEditValues(e, 'EAMT', '1');
end;
{========================================================}
{ CREATE CRAFTING RECIPE (COBJ)                          }
{========================================================}
function MakeCraftableV2(itemRecord: IInterface): IInterface;
var
	recipeCraft, recipeItems, tmpKeywordsCollection, tmp: IInterface;
	itemSignature, currentKeywordEDID: string;
	amountOfMainComponent, amountOfAdditionalComponent, amountOfLeatherComponent, i: integer;
begin
	itemSignature := Signature(itemRecord);

	{--- CRAFING MANUAL ---}
	if (itemSignature = 'BOOK') then begin
		
		{ 1. Construct the target EditorID }
		currentKeywordEDID := 'RecipeCraftingManual' + GetElementEditValues(itemRecord, 'EDID');
		
		{ 2. Search for the existing recipe in the Patch File }
		{ GroupBySignature ensures we are only looking inside 'COBJ' records }
		recipeCraft := MainRecordByEditorID(GroupBySignature(GlobalPatchFile, 'COBJ'), currentKeywordEDID);
		
		{ 3. If found, skip creation and just return the existing record }
		if Assigned(recipeCraft) then begin
			AddMessage('Record exists, skipping creation: ' + currentKeywordEDID);
			Result := recipeCraft;
			Exit;
		end;
		
		{ 4. Create the base COBJ record }
		recipeCraft := createRecipe(itemRecord);
		if not Assigned(recipeCraft) then Exit;

		{ 5. Initialize Required Items list }
		Add(recipeCraft, 'items', True);
		recipeItems := ElementByPath(recipeCraft, 'items');
		
		{ 6. Process Material Keywords for Perk requirements }
		tmpKeywordsCollection := ElementBySignature(itemRecord, 'KWDA');
		
		{ 7. Add your global skill requirement condition (e.g. Smithing 25) }
		addSkillCondition(recipeCraft, GlobalSmithingReq);
		fAddPlayerLevelCondition(recipeCraft, GlobalPlayerLevelReq);
		addFemaleCondition(recipeCraft);
		AddMissingManualCondition(recipeCraft, GlobalCraftingManual);
		
		
		SetElementEditValues(recipeCraft, 'EDID', 'RecipeCraftingManual' + GetElementEditValues(itemRecord, 'EDID'));
		SetElementEditValues(recipeCraft, 'BNAM', GetEditValue(getRecordByFormID(ARMOR_CRAFTING_WORKBENCH_FORM_ID)));
		
		
		// Materials
		addItemV2(recipeItems, GetMaterial('Leather01'), 1);
		addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
		addItemV2(recipeItems, GetMaterial('Gold001'), GlobalSmithingReq * CRAFTING_MANUAL_PRICE_MULTIPLIER);
		
		if (IS_PERK_REQUIRED) then begin
			{ Loop keywords to assign Perks }
			for i := 0 to ElementCount(tmpKeywordsCollection) - 1 do begin
				currentKeywordEDID := GlobalOutfitMaterial;
				
				{ Requiem: Leather and Steel both require Steel Smithing perk }
				if ((currentKeywordEDID = 'ArmorMaterialSteel') or (currentKeywordEDID = 'ArmorMaterialLeather') or
					(currentKeywordEDID = 'DLC2ArmorMaterialBonemoldLight') or (currentKeywordEDID = 'ArmorMaterialImperialHeavy') or 
					(currentKeywordEDID = 'ArmorMaterialStormcloak') or (currentKeywordEDID = 'DLC1ArmorMaterialDawnguard')) then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB40D')); // Steel Smithing
					Break;

				end else if ((currentKeywordEDID = 'ArmorMaterialScaled') or (currentKeywordEDID = 'ArmorMaterialSteelPlate') or 
					(currentKeywordEDID = 'DLC2ArmorMaterialNordicHeavy')) then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB414')); // Advanced Armors
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialDwarven') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB40E')); // Dwarven Smithing
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialEbony') or (currentKeywordEDID = 'DLC2ArmorMaterialStalhrimHeavy') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB412')); // Ebony Smithing
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialDaedric') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB413')); // Daedric Smithing
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialOrcish') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB410')); // Orcish Smithing
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialGlass') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB411')); // Glass Smithing
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialDragonscale') or (currentKeywordEDID = 'ArmorMaterialDragonplate') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('00052190')); // Dragon Armor
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialElven') or (currentKeywordEDID = 'DLC2ArmorMaterialChitinLight') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB40F')); // Elven Smithing
					Break;
				end;
			end;
		end;
		
		// Cleanup and Validation
		removeInvalidEntries(recipeCraft);
		
		if GetElementEditValues(recipeCraft, 'COCT') = '' then begin
			warn('No item requirements specified for: ' + Name(recipeCraft));
		end;

		Result := recipeCraft;
		Exit;
	end;
	
	{--- WEAPON LOGIC ---}
	if (itemSignature = 'WEAP') then begin
		
		{ 1. Create the base COBJ record }
		recipeCraft := createRecipe(itemRecord);
		if not Assigned(recipeCraft) then Exit;

		{ 2. Initialize Required Items list }
		Add(recipeCraft, 'items', True);
		recipeItems := ElementByPath(recipeCraft, 'items');
		
		{ 3. Process Material Keywords for Perk requirements }
		tmpKeywordsCollection := ElementBySignature(itemRecord, 'KWDA');
		
		{ 4. Add your global skill requirement condition (e.g. Smithing 25) }
		addSkillCondition(recipeCraft, GlobalSmithingReq);
		
		{ 5. Add Player Level  condition }
		fAddPlayerLevelCondition(recipeCraft, GlobalPlayerLevelReq);
		
		SetElementEditValues(recipeCraft, 'EDID', 'RecipeWeapon' + GetElementEditValues(itemRecord, 'EDID'));
		SetElementEditValues(recipeCraft, 'BNAM', GetEditValue(getRecordByFormID(WEAPON_CRAFTING_WORKBENCH_FORM_ID)));
		
		if (IS_PERK_REQUIRED) then begin
			for i := 0 to ElementCount(tmpKeywordsCollection) - 1 do begin
				currentKeywordEDID := GetElementEditValues(LinksTo(ElementByIndex(tmpKeywordsCollection, i)), 'EDID');
				
				if ((currentKeywordEDID = 'WeapMaterialSteel') or (currentKeywordEDID = 'WeapMaterialImperial') or 
					(currentKeywordEDID = 'WeapMaterialDraugr') or (currentKeywordEDID = 'WeapMaterialDraugrHoned')) then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB40D')); // Steel Smithing
					Break;
				end else if (currentKeywordEDID = 'WeapMaterialElven') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB40F')); // Elven Smithing
					Break;
				end else if (currentKeywordEDID = 'DLC2WeaponMaterialNordic') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB414')); // Advanced Armors
					Break;
				end else if (currentKeywordEDID = 'WeapMaterialDwarven') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB40E')); // Dwarven Smithing
					Break;
				end else if (currentKeywordEDID = 'WeapMaterialEbony') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB412')); // Ebony Smithing
					Break;
				end else if (currentKeywordEDID = 'WeapMaterialDaedric') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB413')); // Daedric Smithing
					Break;
				end else if ((currentKeywordEDID = 'WeapMaterialOrcish') or (currentKeywordEDID = 'DLC2WeaponMaterialStalhrim')) then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB410')); // Orcish Smithing
					Break;
				end else if (currentKeywordEDID = 'WeapMaterialGlass') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB411')); // Glass Smithing
					Break;
				end else if (currentKeywordEDID = 'DLC1WeapMaterialDragonbone') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('00052190')); // Dragon Armor
					Break;
				end;
			end;
		end;
		
				{ --- STEEL MATERIAL WEAPONS --- }
		if HasKeyword(itemRecord, 'WeapMaterialSteel') then begin
			if HasKeyword(itemRecord, 'WeapTypeDagger') then begin
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 1);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeSword')) or (HasKeyword(itemRecord, 'WeapTypeWarAxe')) then begin
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end else if HasKeyword(itemRecord, 'WeapTypeMace') then begin
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 3);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeGreatsword')) or (HasKeyword(itemRecord, 'WeapTypeBattleaxe')) or (HasKeyword(itemRecord, 'WeapTypeWarhammer')) then begin
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 4);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end else if HasKeyword(itemRecord, 'WeapTypeBow') then begin
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			end;
		end

		{ --- DWARVEN MATERIAL WEAPONS --- }
		else if HasKeyword(itemRecord, 'WeapMaterialDwarven') then begin
			if HasKeyword(itemRecord, 'WeapTypeDagger') then begin
				addItemV2(recipeItems, GetMaterial('IngotDwarven'), 1);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 1);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeSword')) or (HasKeyword(itemRecord, 'WeapTypeWarAxe')) or (HasKeyword(itemRecord, 'WeapTypeMace')) then begin
				addItemV2(recipeItems, GetMaterial('IngotDwarven'), 1);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 1);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeGreatsword')) or (HasKeyword(itemRecord, 'WeapTypeBattleaxe')) or (HasKeyword(itemRecord, 'WeapTypeWarhammer')) then begin
				addItemV2(recipeItems, GetMaterial('IngotDwarven'), 2);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end else if HasKeyword(itemRecord, 'WeapTypeBow') then begin
				addItemV2(recipeItems, GetMaterial('IngotDwarven'), 2);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 1);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			end;
		end

		{ --- ELVEN MATERIAL WEAPONS --- }
		else if HasKeyword(itemRecord, 'WeapMaterialElven') then begin
			if HasKeyword(itemRecord, 'WeapTypeDagger') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeSword')) or (HasKeyword(itemRecord, 'WeapTypeWarAxe')) or (HasKeyword(itemRecord, 'WeapTypeMace')) then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
				addItemV2(recipeItems, GetMaterial('IngotQuicksilver'), 1);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeGreatsword')) or (HasKeyword(itemRecord, 'WeapTypeBattleaxe')) or (HasKeyword(itemRecord, 'WeapTypeWarhammer')) then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 2);
				addItemV2(recipeItems, GetMaterial('IngotQuicksilver'), 1);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end else if HasKeyword(itemRecord, 'WeapTypeBow') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 2);
				addItemV2(recipeItems, GetMaterial('IngotQuicksilver'), 1);
			end;
		end

		{ --- ORCISH MATERIAL WEAPONS --- }
		else if HasKeyword(itemRecord, 'WeapMaterialOrcish') then begin
			if HasKeyword(itemRecord, 'WeapTypeDagger') then begin
				addItemV2(recipeItems, GetMaterial('IngotOrichalcum'), 1);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeSword')) or (HasKeyword(itemRecord, 'WeapTypeWarAxe')) or (HasKeyword(itemRecord, 'WeapTypeMace')) then begin
				addItemV2(recipeItems, GetMaterial('IngotOrichalcum'), 1);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeGreatsword')) or (HasKeyword(itemRecord, 'WeapTypeBattleaxe')) or (HasKeyword(itemRecord, 'WeapTypeWarhammer')) then begin
				addItemV2(recipeItems, GetMaterial('IngotOrichalcum'), 2);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end else if HasKeyword(itemRecord, 'WeapTypeBow') then begin
				addItemV2(recipeItems, GetMaterial('IngotOrichalcum'), 2);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 1);
			end;
		end

		{ --- GLASS MATERIAL WEAPONS --- }
		else if HasKeyword(itemRecord, 'WeapMaterialGlass') then begin
			if HasKeyword(itemRecord, 'WeapTypeDagger') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMalachite'), 1);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeSword')) or (HasKeyword(itemRecord, 'WeapTypeWarAxe')) or (HasKeyword(itemRecord, 'WeapTypeMace')) then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMalachite'), 1);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeGreatsword')) or (HasKeyword(itemRecord, 'WeapTypeBattleaxe')) or (HasKeyword(itemRecord, 'WeapTypeWarhammer')) then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMalachite'), 2);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end else if HasKeyword(itemRecord, 'WeapTypeBow') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMalachite'), 2);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
			end;
		end

		{ --- EBONY MATERIAL WEAPONS --- }
		else if HasKeyword(itemRecord, 'WeapMaterialEbony') then begin
			if HasKeyword(itemRecord, 'WeapTypeDagger') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeSword')) or (HasKeyword(itemRecord, 'WeapTypeWarAxe')) or (HasKeyword(itemRecord, 'WeapTypeMace')) then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeGreatsword')) or (HasKeyword(itemRecord, 'WeapTypeBattleaxe')) or (HasKeyword(itemRecord, 'WeapTypeWarhammer')) then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 4);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end else if HasKeyword(itemRecord, 'WeapTypeBow') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 3);
			end;
		end

		{ --- DAEDRIC MATERIAL WEAPONS --- }
		else if HasKeyword(itemRecord, 'WeapMaterialDaedric') then begin
			addItemV2(recipeItems, GetMaterial('DaedraHeart'), 1);
			if HasKeyword(itemRecord, 'WeapTypeDagger') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeSword')) or (HasKeyword(itemRecord, 'WeapTypeWarAxe')) or (HasKeyword(itemRecord, 'WeapTypeMace')) then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeGreatsword')) or (HasKeyword(itemRecord, 'WeapTypeBattleaxe')) or (HasKeyword(itemRecord, 'WeapTypeWarhammer')) then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 5);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end else if HasKeyword(itemRecord, 'WeapTypeBow') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 3);
			end;
		end;
		
	end;
	
	{ --- ARMOR LOGIC --- }
	if (itemSignature = 'ARMO') then begin
		
		if IsVisualSlot(GetFirstPersonFlags(itemRecord))then begin
			currentKeywordEDID := 'RecipeVisulaSlot' + GetElementEditValues(itemRecord, 'EDID');
			recipeCraft := MainRecordByEditorID(GroupBySignature(GlobalPatchFile, 'COBJ'), currentKeywordEDID);
			// If found, skip creation and just return the existing record
			if Assigned(recipeCraft) then begin
				AddMessage('Record exists, skipping creation: ' + currentKeywordEDID);
				Result := recipeCraft;
				Exit;
			end;
		end else begin
			currentKeywordEDID := 'CF_RecipeArmor' + GetElementEditValues(itemRecord, 'EDID');
			recipeCraft := MainRecordByEditorID(GroupBySignature(GlobalPatchFile, 'COBJ'), currentKeywordEDID);
			// If found, skip creation and just return the existing record
			if Assigned(recipeCraft) then begin
				AddMessage('Record exists, skipping creation: ' + currentKeywordEDID);
				Result := recipeCraft;
				Exit;
			end;
		end;
		
		{ 1. Create the base COBJ record }
		recipeCraft := createRecipe(itemRecord);
		if not Assigned(recipeCraft) then Exit;

		{ 2. Initialize Required Items list }
		Add(recipeCraft, 'items', True);
		recipeItems := ElementByPath(recipeCraft, 'items');
		
		{ 3. Process Material Keywords for Perk requirements }
		tmpKeywordsCollection := ElementBySignature(itemRecord, 'KWDA');
		
		{ 4. Add your global skill requirement condition (e.g. Smithing 25) }
		if GlobalSmithingReq > 0 then begin
			addSkillCondition(recipeCraft, GlobalSmithingReq);
		end;
		
		{ Set Recipe Identity  For Visual Slot Only}
		if IsVisualSlot(GetFirstPersonFlags(itemRecord))then begin
			SetElementEditValues(recipeCraft, 'EDID', 'CF_RecipeVisulaSlot' + GetElementEditValues(itemRecord, 'EDID'));
			SetElementEditValues(recipeCraft, 'BNAM', GetEditValue(getRecordByFormID(ARMOR_CRAFTING_WORKBENCH_FORM_ID)));
		end else begin
			SetElementEditValues(recipeCraft, 'EDID', 'CF_RecipeArmor' + GetElementEditValues(itemRecord, 'EDID'));
			SetElementEditValues(recipeCraft, 'BNAM', GetEditValue(getRecordByFormID(ARMOR_CRAFTING_WORKBENCH_FORM_ID)));
		end;
		{ If Armor is ony for Female actor }
		addFemaleCondition(recipeCraft);
		AddManualCondition(recipeCraft, GlobalCraftingManual);
		
		if (IS_PERK_REQUIRED) then begin
			{ Loop keywords to assign Perks }
			for i := 0 to ElementCount(tmpKeywordsCollection) - 1 do begin
				currentKeywordEDID := GetElementEditValues(LinksTo(ElementByIndex(tmpKeywordsCollection, i)), 'EDID');

				{ Requiem: Leather and Steel both require Steel Smithing perk }
				if ((currentKeywordEDID = 'ArmorMaterialSteel') or (currentKeywordEDID = 'ArmorMaterialLeather') or
					(currentKeywordEDID = 'DLC2ArmorMaterialBonemoldLight') or (currentKeywordEDID = 'ArmorMaterialImperialHeavy') or 
					(currentKeywordEDID = 'ArmorMaterialStormcloak') or (currentKeywordEDID = 'DLC1ArmorMaterialDawnguard')) then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB40D')); // Steel Smithing
					Break;

				end else if ((currentKeywordEDID = 'ArmorMaterialScaled') or (currentKeywordEDID = 'ArmorMaterialSteelPlate') or 
					(currentKeywordEDID = 'DLC2ArmorMaterialNordicHeavy')) then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB414')); // Advanced Armors
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialDwarven') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB40E')); // Dwarven Smithing
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialEbony') or (currentKeywordEDID = 'DLC2ArmorMaterialStalhrimHeavy') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB412')); // Ebony Smithing
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialDaedric') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB413')); // Daedric Smithing
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialOrcish') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB410')); // Orcish Smithing
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialGlass') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB411')); // Glass Smithing
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialDragonscale') or (currentKeywordEDID = 'ArmorMaterialDragonplate') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('00052190')); // Dragon Armor
					Break;

				end else if (currentKeywordEDID = 'ArmorMaterialElven') or (currentKeywordEDID = 'DLC2ArmorMaterialChitinLight') then begin
					addPerkCondition(recipeCraft, getRecordByFormID('000CB40F')); // Elven Smithing
					Break;
				end;
			end;
		end;
		
		{ Check if armor considered as "Visual Armor Slot" }
		if IsVisualSlot(GetFirstPersonFlags(itemRecord))then begin
			addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			
			{ Cleanup and Validation }
			removeInvalidEntries(recipeCraft);
			if GetElementEditValues(recipeCraft, 'COCT') = '' then begin
				warn('No item requirements specified for: ' + Name(recipeCraft));
			end;
			Result := recipeCraft;
			Exit;
		end;
		

		{========================================================}
		{ LIGHT ARMOR SETS                                       }
		{========================================================}

		{ --- LEATHER ARMOR --- }
		if HasKeyword(itemRecord, 'ArmorMaterialLeather') then begin
			addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			if HasKeyword(itemRecord, 'ArmorCuirass') then begin
				addItemV2(recipeItems, GetMaterial('Leather01'), 4);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end;
			if HasKeyword(itemRecord, 'ArmorHelmet') then begin
				addItemV2(recipeItems, GetMaterial('Leather01'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end; 
			if HasKeyword(itemRecord, 'ArmorBoots') then begin
				addItemV2(recipeItems, GetMaterial('Leather01'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorGauntlets') then begin
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorShield') then begin
				addItemV2(recipeItems, GetMaterial('Leather01'), 4);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
		end;
		
		{ --- SCALED ARMOR --- }
		if HasKeyword(itemRecord, 'ArmorMaterialScaled') then begin
			if HasKeyword(itemRecord, 'ArmorCuirass') then begin
				addItemV2(recipeItems, GetMaterial('Leather01'), 4);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
				addItemV2(recipeItems, GetMaterial('IngotCorundum'), 2);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 3);
			end;
			if HasKeyword(itemRecord, 'ArmorHelmet') then begin
				addItemV2(recipeItems, GetMaterial('Leather01'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
				addItemV2(recipeItems, GetMaterial('IngotCorundum'), 1);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorBoots') then begin
				addItemV2(recipeItems, GetMaterial('Leather01'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
				addItemV2(recipeItems, GetMaterial('IngotCorundum'), 1);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
			end; 
			if HasKeyword(itemRecord, 'ArmorGauntlets') then begin
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
				addItemV2(recipeItems, GetMaterial('IngotCorundum'), 1);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 1);
			end;
			{ Scaled Shield - Custom or Mod-specific as Scaled doesn't have a vanilla shield }
			if HasKeyword(itemRecord, 'ArmorShield') then begin
				addItemV2(recipeItems, GetMaterial('Leather01'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
				addItemV2(recipeItems, GetMaterial('IngotCorundum'), 2);
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 3);
			end;
		end;

		{ --- ELVEN ARMOR --- }
		if HasKeyword(itemRecord, 'ArmorMaterialElven') then begin
			addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			if HasKeyword(itemRecord, 'ArmorCuirass') then begin
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 4);
			end;
			if HasKeyword(itemRecord, 'ArmorHelmet') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end;
			if HasKeyword(itemRecord, 'ArmorBoots') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorGauntlets') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorShield') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 4);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;		
		end;

		{ --- GLASS ARMOR --- }
		if HasKeyword(itemRecord, 'ArmorMaterialGlass') then begin
			addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			if HasKeyword(itemRecord, 'ArmorCuirass') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMalachite'), 4);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorHelmet') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMalachite'), 2);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end; 
			if HasKeyword(itemRecord, 'ArmorBoots') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMalachite'), 2);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorGauntlets') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMalachite'), 1);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorShield') then begin
				addItemV2(recipeItems, GetMaterial('IngotRefinedMalachite'), 4);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
		end;
		
		{ --- DRAGONSCALE ARMOR --- }
		if HasKeyword(itemRecord, 'ArmorMaterialDragonscale') then begin
			addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			if HasKeyword(itemRecord, 'ArmorCuirass') then begin
				addItemV2(recipeItems, GetMaterial('DragonScales'), 4);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end;
			if HasKeyword(itemRecord, 'ArmorHelmet') then begin
				addItemV2(recipeItems, GetMaterial('DragonScales'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorBoots') then begin
				addItemV2(recipeItems, GetMaterial('DragonScales'), 3);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorGauntlets') then begin
				addItemV2(recipeItems, GetMaterial('DragonScales'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorShield') then begin
				addItemV2(recipeItems, GetMaterial('DragonScales'), 4);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
		end;

		{========================================================}
		{ HEAVY ARMOR SETS                                       }
		{========================================================}

		{ --- STEEL ARMOR --- }
		if HasKeyword(itemRecord, 'ArmorMaterialSteel') then begin
			addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			if HasKeyword(itemRecord, 'ArmorCuirass') then 
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 3);
			if HasKeyword(itemRecord, 'ArmorHelmet') then 
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
			if HasKeyword(itemRecord, 'ArmorBoots') then 
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
			if HasKeyword(itemRecord, 'ArmorGauntlets') then 
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
			if HasKeyword(itemRecord, 'ArmorShield') then 
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
		end;

		{ --- DWARVEN ARMOR --- }
		if HasKeyword(itemRecord, 'ArmorMaterialDwarven') then begin
			addItemV2(recipeItems, GetMaterial('IngotSteel'), 1);
			addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			if HasKeyword(itemRecord, 'ArmorCuirass') then begin
				addItemV2(recipeItems, GetMaterial('IngotDwarven'), 4);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end;	
			if HasKeyword(itemRecord, 'ArmorHelmet') then begin
				addItemV2(recipeItems, GetMaterial('IngotDwarven'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorBoots') then begin
				addItemV2(recipeItems, GetMaterial('IngotDwarven'), 3);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorGauntlets') then begin
				addItemV2(recipeItems, GetMaterial('IngotDwarven'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorShield') then begin
				addItemV2(recipeItems, GetMaterial('IngotDwarven'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end;
		end;
		
		{ --- ORCISH ARMOR --- }
		if HasKeyword(itemRecord, 'ArmorMaterialOrcish') then begin
			addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			if HasKeyword(itemRecord, 'ArmorCuirass') then begin
				addItemV2(recipeItems, GetMaterial('IngotOrichalcum'), 3);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
				addItemV2(recipeItems, GetMaterial('Leather01'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorHelmet') then begin
				addItemV2(recipeItems, GetMaterial('IngotOrichalcum'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			end;
			if HasKeyword(itemRecord, 'ArmorBoots') then begin
				addItemV2(recipeItems, GetMaterial('IngotOrichalcum'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			end;
			if HasKeyword(itemRecord, 'ArmorGauntlets') then begin
				addItemV2(recipeItems, GetMaterial('IngotOrichalcum'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			end;
			if HasKeyword(itemRecord, 'ArmorShield') then begin
				addItemV2(recipeItems, GetMaterial('IngotOrichalcum'), 4);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			end;
		end;

		{ --- STEEL PLATE ARMOR --- }
		if HasKeyword(itemRecord, 'ArmorMaterialSteelPlate') then begin
			addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			if HasKeyword(itemRecord, 'ArmorCuirass') then begin
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 4);
				addItemV2(recipeItems, GetMaterial('IngotCorundum'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end;
			if HasKeyword(itemRecord, 'ArmorHelmet') then begin
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
				addItemV2(recipeItems, GetMaterial('IngotCorundum'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end;
			if HasKeyword(itemRecord, 'ArmorBoots') then begin
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 3);
				addItemV2(recipeItems, GetMaterial('IngotCorundum'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorGauntlets') then begin
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
				addItemV2(recipeItems, GetMaterial('IngotCorundum'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			{ Steel Plate uses the standard Steel Shield recipe }
			if HasKeyword(itemRecord, 'ArmorShield') then begin
				addItemV2(recipeItems, GetMaterial('IngotSteel'), 2);
				addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			end;
		end;

		{ --- EBONY ARMOR --- }
		if HasKeyword(itemRecord, 'ArmorMaterialEbony') then begin
			addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			if HasKeyword(itemRecord, 'ArmorCuirass') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 4);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end;
			if HasKeyword(itemRecord, 'ArmorHelmet') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorBoots') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorGauntlets') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorShield') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 2);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end;
		end;

		{ --- DAEDRIC ARMOR --- }
		if HasKeyword(itemRecord, 'ArmorMaterialDaedric') then begin
			addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			addItemV2(recipeItems, GetMaterial('DaedraHeart'), 1);
			addItemV2(recipeItems, GetMaterial('IngotSteel'), 1);
			if HasKeyword(itemRecord, 'ArmorCuirass') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 4);
				addItemV2(recipeItems, GetMaterial('Leather01'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorHelmet') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 2);
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			end;
			if HasKeyword(itemRecord, 'ArmorBoots') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 2);
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			end;
			if HasKeyword(itemRecord, 'ArmorGauntlets') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 2);
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			end;
			if HasKeyword(itemRecord, 'ArmorShield') then begin
				addItemV2(recipeItems, GetMaterial('IngotEbony'), 2);
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			end;
		end;

		{ --- DRAGONPLATE ARMOR --- }
		if HasKeyword(itemRecord, 'ArmorMaterialDragonplate') then begin
			addItemV2(recipeItems, GetMaterial('LeatherStrips'), 2);
			addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			if HasKeyword(itemRecord, 'ArmorCuirass') then begin
				addItemV2(recipeItems, GetMaterial('DragonBone'), 3);
				addItemV2(recipeItems, GetMaterial('DragonScales'), 2);
				addItemV2(recipeItems, GetMaterial('Leather01'), 2);
			end;
			if HasKeyword(itemRecord, 'ArmorHelmet') then begin
				addItemV2(recipeItems, GetMaterial('DragonBone'), 1);
				addItemV2(recipeItems, GetMaterial('DragonScales'), 2);
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			end;
			if HasKeyword(itemRecord, 'ArmorBoots') then begin
				addItemV2(recipeItems, GetMaterial('DragonBone'), 1);
				addItemV2(recipeItems, GetMaterial('DragonScales'), 3);
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			end;
			if HasKeyword(itemRecord, 'ArmorGauntlets') then begin
				addItemV2(recipeItems, GetMaterial('DragonBone'), 1);
				addItemV2(recipeItems, GetMaterial('DragonScales'), 2);
				addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			end;
			if HasKeyword(itemRecord, 'ArmorShield') then begin
				addItemV2(recipeItems, GetMaterial('DragonBone'), 1);
				addItemV2(recipeItems, GetMaterial('DragonScales'), 1);
			end;
		end;
		
	end;
	// Cleanup and Validation
	removeInvalidEntries(recipeCraft);

	if GetElementEditValues(recipeCraft, 'COCT') = '' then begin
		warn('No item requirements specified for: ' + Name(recipeCraft));
	end;

	Result := recipeCraft;
end;

{========================================================}
{ CREATE TEMPERING RECIPE                                }
{========================================================}
function fMakeTemperable(itemRecord: IInterface): IInterface;
var
	recipeTemper, recipeCondition, recipeConditions, recipeItem, recipeItems : IInterface;
begin
	recipeTemper := createRecipe(itemRecord);

	if IS_PERK_REQUIRED then begin
	
		// add new condition list
		Add(recipeTemper, 'Conditions', true);
		// get reference to condition list inside recipe
		recipeConditions := ElementByPath(recipeTemper, 'Conditions');

		// add IsEnchanted condition
		// get new condition from list
		recipeCondition := ElementByIndex(recipeConditions, 0);
		// set type to 'Not equal to / Or'
		SetElementEditValues(recipeCondition, 'CTDA - CTDA\Type', '10010000');
		// set some needed properties
		SetElementEditValues(recipeCondition, 'CTDA - CTDA\Comparison Value', '0');
		SetElementEditValues(recipeCondition, 'CTDA - CTDA\Function', 'EPTemperingItemIsEnchanted');
		SetElementEditValues(recipeCondition, 'CTDA - CTDA\Run On', 'Subject');
		// don't know what is this, but it should be equal to -1, if Function Runs On Subject
		SetElementEditValues(recipeCondition, 'CTDA - CTDA\Parameter #3', '-1');

		// add second condition, for perk ArcaneBlacksmith check
		addPerkCondition(recipeConditions, getRecordByFormID('0005218E')); // ArcaneBlacksmith
	end;
	
	// add required items list
	Add(recipeTemper, 'items', true);
	// get reference to required items list inside recipe
	recipeItems := ElementByPath(recipeTemper, 'items');

	if Signature(itemRecord) = 'WEAP' then begin
		// set EditorID for recipe
		SetElementEditValues(recipeTemper, 'EDID', 'CF_TemperWeapon' + GetElementEditValues(itemRecord, 'EDID'));
		// add reference to the workbench keyword
		SetElementEditValues(recipeTemper, 'BNAM', GetEditValue(
		getRecordByFormID(WEAPON_TEMPERING_WORKBENCH_FORM_ID)));
	end;
	
	if Signature(itemRecord) = 'ARMO' then begin
		// set EditorID for recipe
		SetElementEditValues(recipeTemper, 'EDID', 'CF_TemperArmor' + GetElementEditValues(itemRecord, 'EDID'));

		// add reference to the workbench keyword
		SetElementEditValues(recipeTemper, 'BNAM', GetEditValue(
		getRecordByFormID(ARMOR_TEMPERING_WORKBENCH_FORM_ID)));
	end;

    // figure out required component...
	addItem(recipeItems, getMainMaterial(itemRecord), 1);

    // remove nil record in items requirements, if any
	removeInvalidEntries(recipeTemper);

if GetElementEditValues(recipeTemper, 'COCT') = '' then begin
warn('no item requirements was specified for - ' + Name(recipeTemper));
end;

    // return created tempering recipe, just in case
Result := recipeTemper;
end;

{========================================================}
{                       UTILITY                          }
{========================================================}
function addKeyword(itemRecord: IInterface; keyword: IInterface): Integer;
var
    kwCollection, newEntry: IInterface;
begin
    Result := 0;
    if not Assigned(itemRecord) or not Assigned(keyword) then Exit;

    { 1. Check if the item already has this keyword using the Keyword's actual EditorID }
    if HasKeyword(itemRecord, EditorID(keyword)) then Exit;

    { 2. Get the KWDA block (Keywords array) }
    kwCollection := ElementBySignature(itemRecord, 'KWDA');
    if not Assigned(kwCollection) then
        kwCollection := Add(itemRecord, 'KWDA', True);

    { 3. Add the keyword }
    if Assigned(kwCollection) then begin
        newEntry := ElementAssign(kwCollection, HighInteger, nil, False);
        SetEditValue(newEntry, IntToHex(FixedFormID(keyword), 8));
        Result := 1;
    end;
end;

function GetKeywordByEditorID(aEditorID: string): IInterface;
var
    i, j: Integer;
    currFile, kwGroup, rec: IInterface;
begin
    Result := nil;
    for i := 0 to FileCount - 1 do begin
        currFile := FileByIndex(i);
        
        { Find the Keyword group in this file }
        kwGroup := GroupBySignature(currFile, 'KYWD');
        if not Assigned(kwGroup) then continue;

        { Iterate through every keyword in the group }
        for j := 0 to ElementCount(kwGroup) - 1 do begin
            rec := ElementByIndex(kwGroup, j);
            if EditorID(rec) = aEditorID then begin
                Result := rec;
                Exit;
            end;
        end;
    end;
    AddMessage('Critical Warning: ' + aEditorID + ' not found even in deep search!');
end;

function GetMaterial(aName: string): IInterface;
var
	fID: string;
begin
	Result := nil;
	fID := '';
	
	{ Map common names to hardcoded vanilla FormIDs }
	if aName = 'IngotIron' then fID := '0005ACE4'
	else if aName = 'Gold001' then fID := '0000000F'
	else if aName = 'IngotSteel' then fID := '0005ACE5'
	else if aName = 'IngotCorundum' then fID := '0005AD93'
	else if aName = 'IngotDwarven' then fID := '000DB8A2' { Corrected to Ingot }
	else if aName = 'IngotRefinedMoonstone' then fID := '0005AD9F'
	else if aName = 'IngotRefinedMalachite' then fID := '0005ADA1'
	else if aName = 'IngotEbony' then fID := '0005AD9D'
	else if aName = 'IngotOrichalcum' then fID := '0005AD99'
	else if aName = 'IngotQuicksilver' then fID := '0005ADA0'
	else if aName = 'Leather01' then fID := '000DB5D2'
	else if aName = 'LeatherStrips' then fID := '000800E4'
	else if aName = 'DragonScales' then fID := '0003ADA3'
	else if aName = 'DragonBone' then fID := '0003ADA4'
	else if aName = 'DaedraHeart' then fID := '0003AD5B'
	else if aName = 'GoldIngot' then fID := '0005AD9E';
	
	{ Direct lookup via the internal xEdit helper }
	//Result := getRecordByFormID(fID);
	Result := RecordByFormID(FileByIndex(0), fID, True);
	
	{ 3. Strict NULL and Zero-Reference Check }
	if not Assigned(Result) or (FixedFormID(Result) = 0) then begin
		AddMessage('CRITICAL: Material "' + aName + '" is NULL or 00000000. Check Load Order.');
		Result := nil;
	end;
end;

{ Helper to safely get FormID without "Deep Search" hanging }
function fGetSafeID(m_sEditorID: string): Cardinal;
var
	m_eKw: IInterface;
begin
	m_eKw := GetKeywordByEditorID(m_sEditorID);
	if Assigned(m_eKw) then
		Result := FixedFormID(m_eKw)
	else
		Result := 0;
end;

procedure removeKeywordV2(e: IInterface; m_sKeywordEditorID: string);
var
	m_eKeywords, m_eEntry, m_eTargetKw: IInterface;
	m_iTargetFormID: Cardinal;
	m_iFoundID: Cardinal;
	i: Integer;
begin
	// 1. Get the FormID of the keyword we want to remove
	m_eTargetKw := GetKeywordByEditorID(m_sKeywordEditorID);
	if not Assigned(m_eTargetKw) then Exit; 
	
	m_iTargetFormID := FixedFormID(m_eTargetKw);

	// 2. Locate the Keyword Array (KWDA)
	m_eKeywords := ElementBySignature(e, 'KWDA');
	if not Assigned(m_eKeywords) then Exit;

	// 3. Loop BACKWARDS to safely remove elements
	for i := ElementCount(m_eKeywords) - 1 downto 0 do begin
		m_eEntry := ElementByIndex(m_eKeywords, i);
		
		// 4. Get the native FormID value from the entry
		// This bypasses EditorID/LinksTo naming issues
		m_iFoundID := GetNativeValue(m_eEntry);
		
		if m_iFoundID = m_iTargetFormID then begin
			RemoveElement(m_eKeywords, i);
		end;
	end;
end;

function fGetCurvedPlayerLevel(m_iSmithing: Integer): Integer;
var
	m_fProgress: Double;
begin
	// If skill is 0 or negative, default to Level 1
	if m_iSmithing <= 0 then begin
		Result := 1;
		Exit;
	end;

	// 1. Normalize smithing to a 0.0 -> 1.0 range
	m_fProgress := m_iSmithing / 100.0;

	// 2. Quadratic Curve Formula: 1 + (59 * Progress^2)
	// We use (m_fProgress * m_fProgress) for a clean squared result
	Result := Round(1 + (59.0 * (m_fProgress * m_fProgress)));

	// 3. Final safety clamp to your specified range (1 to 60)
	if Result < 1 then Result := 1;
	if Result > 60 then Result := 60;
end;

function fFunctionCopyArmorToNewFile(SourceRecord: IInterface; TargetFile: IInterface; sPrefix: string): IInterface;
var
	NewEditorID, NewName, CurrentName: string;
	SourceFile: IInterface;
	ExistingRecord: IInterface;
begin
	Result := nil;
	
	// 1. Prepare the new EditorID
	NewEditorID := sPrefix + EditorID(SourceRecord);
	
	// 2. Duplicate Check
	ExistingRecord := MainRecordByEditorID(GroupBySignature(TargetFile, 'ARMO'), NewEditorID);
	if Assigned(ExistingRecord) then
	begin
		AddMessage('Skipping: ' + NewEditorID + ' already exists.');
		Exit;
	end;

	// 3. Master Handling
	SourceFile := GetFile(SourceRecord);
	AddMasterIfMissing(TargetFile, 'Skyrim.esm');
	if not Equals(SourceFile, TargetFile) then
		AddMasterIfMissing(TargetFile, GetFileName(SourceFile));

	// 4. Copy as New
	Result := wbCopyElementToFile(SourceRecord, TargetFile, True, True);
	
	if Assigned(Result) then
	begin
		// 5. Update EditorID
		SetElementEditValues(Result, 'EDID', NewEditorID);
		
		// 6. Update Display Name (FULL) with Brackets
		// Example: [T20] Iron Armor
		CurrentName := GetElementEditValues(SourceRecord, 'FULL');
		if CurrentName = '' then CurrentName := EditorID(SourceRecord);
		
		NewName := '[' + sPrefix + '] ' + CurrentName;
		// Clean up the prefix for the display name (remove the CF_ and trailing underscores)
		StringReplace(NewName, 'CF_', '', [rfReplaceAll]);
		StringReplace(NewName, '_', '', [rfReplaceAll]);
		
		SetElementEditValues(Result, 'FULL', NewName);
		
		AddMessage('Created: ' + NewEditorID + ' (' + NewName + ')');
	end;
end;

function fOverrideRecordToPatch(m_SourceRecord: IInterface; m_TargetFile: IInterface; m_sPrefix: string): IInterface;
var
	sNewName, sCurrentName: string;
	fSourceFile: IInterface;
begin
	Result := nil;

	// 1. Master Handling
	fSourceFile := GetFile(m_SourceRecord);
	AddMasterIfMissing(m_TargetFile, 'Skyrim.esm');
	
	// Ensure the source file is a master of our patch
	if not Equals(fSourceFile, m_TargetFile) then
		AddMasterIfMissing(m_TargetFile, GetFileName(fSourceFile));

	// 2. Copy as Override
	// Third parameter 'False' = Override (Maintains link to original FormID/EditorID)
	Result := wbCopyElementToFile(m_SourceRecord, m_TargetFile, False, True);
	
	if Assigned(Result) then begin
		// 3. Update Display Name (FULL)
		sCurrentName := GetElementEditValues(m_SourceRecord, 'FULL');
		
		// Fallback to EditorID if the name is empty
		if sCurrentName = '' then sCurrentName := EditorID(m_SourceRecord);
		
		// Create the [Tag] prefix (e.g., [Ey80])
		sNewName := '[' + m_sPrefix + '] ' + sCurrentName;
		
		// Clean the tag for the display name display
		sNewName := StringReplace(sNewName, 'CF_', '', [rfReplaceAll]);
		sNewName := StringReplace(sNewName, '_', '', [rfReplaceAll]);
		
		SetElementEditValues(Result, 'FULL', sNewName);
		
		AddMessage('   [' + Signature(Result) + ' Override] ' + EditorID(Result) + ' -> ' + sNewName);
	end else begin
		AddMessage('   [Error] Failed to override ' + Signature(m_SourceRecord) + ': ' + EditorID(m_SourceRecord));
	end;
end;

function fAddNewFile(m_sFileName: string; m_bIsESL: boolean): IInterface;
var
	m_FileHandle: IInterface;
begin
	Result := nil;

	// Check 1: Empty String
	if Trim(m_sFileName) = '' then begin
		AddMessage('Error: Filename is empty.');
		Exit;
	end;

	// Check 2: Protected Names
	if SameText(m_sFileName, 'Skyrim.esm') or SameText(m_sFileName, 'Update.esm') then begin
		AddMessage('Error: Cannot use protected master names.');
		Exit;
	end;

	// Check 3: Get existing file handle or create new one
	m_FileHandle := FileByName(m_sFileName);
	if not Assigned(m_FileHandle) then
		m_FileHandle := AddNewFileName(m_sFileName, m_bIsESL);

	// Check 4: Final Validation and Master Assignment
	if Assigned(m_FileHandle) then begin
		// Add necessary base masters
		AddMasterIfMissing(m_FileHandle, 'Skyrim.esm');
		AddMasterIfMissing(m_FileHandle, 'Update.esm');
		
		AddMessage('Success: ' + m_sFileName + ' initialized with base masters.');
		Result := m_FileHandle;
	end else begin
		AddMessage('Critical: Failed to create ' + m_sFileName);
	end;
end;

{========================================================}
{ END                                                    }
{========================================================}
function Finalize: integer;
begin
	AddMessage('--- SCRIPT PROCESSED ' + IntToStr(GlobalProcessedRecords) + ' RECORDS ---');
	Result := 0;
end;

end.
