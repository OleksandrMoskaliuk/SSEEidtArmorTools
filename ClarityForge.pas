{
	unit ClarityForge;

	License: Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)
	https://creativecommons.org

	Copyright (c) 2024 Oleksandr Moskaliuk (Dru9Dealer)
	Repository: https://github.com

	You are free to:
	- Share: copy and redistribute the material in any medium or format.
	- Adapt: remix, transform, and build upon the material.

	Under the following terms:
	- Attribution: You must give appropriate credit and provide a link to the license.
	- NonCommercial: You may not use the material for commercial purposes.

================================================================================
UNIT: ClarityForge
PURPOSE: Advanced Armor Sanitization and Balancing for Requiem / Skyrim AE.

PRE-REQUISITES FOR USE:
1. Records must have 'First Person Flags' (BOD2) defined.
2. Records must have at least one 'ArmorMaterial' Keyword assigned.

CORE PHILOSOPHY:
- Modular Outfits: Distinguishes between Functional (AR-bearing) and Visual (Cosmetic) pieces.
- Requirement Scaling: Armor Rating increases based on the Smithing Skill requirement.
- Economic Balance: Visual slots are free to craft (1 Gold) and have 0 resale value.
- Requiem Ready: Automatically manages ArmorType (Heavy/Light/Clothing) and Fists perks.
================================================================================
}
unit ClarityForge;
uses SK_UtilsRemake;

const
	{========================================================}
	{ GLOBAL VARS CONFIGURATION                              }
	{========================================================}
	REQUIRED_SMITHING_SKILL = 5;
	FOR_FEMALE_ONLY = True;
	FOREARMS_DEBUFF_MULTIPLIER = 2.5;
	BACKPACK_SLOT_ENCHANTABLE = False;
	ADVANCED_ENCHANTMENT_PROTECTION = True;

	sScriptVersion = '1.0.0';
	sRepoUrl = 'https://github.com/OleksandrMoskaliuk/SSEEidtArmorTools';	

var
	GlobalSmithingReq: Integer;
	GlobalArmorBonus: Float;
	GlobalHasHands: Boolean;
	GlobalHasHandsWasExecuted: Boolean;
	GlobalProcessedRecords: Integer;
	GlobalForearmsDebuffMultiplier: Float;
	GlobalWeaponDamageBonus: integer;
	GlobalWeaponPriceBonus: integer;
	GlobalArmorPriceBonus: integer;
	GlobalWeaponWeightBonus: Float;

{========================================================}
{ INITIALIZE                                             }
{========================================================}
function Initialize: Integer;
begin
	AddMessage('--- SSEEidtArmorTools v' + sScriptVersion + ' by Dru9Dealer ---');
	AddMessage('License: CC BY-NC 4.0');
	AddMessage('Project Home: ' + sRepoUrl);
	
	{ Initialize Result }
	Result := 0;

	{ Set Global Values }
	GlobalSmithingReq := REQUIRED_SMITHING_SKILL ;
	GlobalArmorBonus := GlobalSmithingReq / 10.0;
	
	{ Note: Result of division is Float, so we Round for Integer bonuses }
	GlobalWeaponDamageBonus := Round(GlobalSmithingReq / 20.0);
	GlobalWeaponPriceBonus := GlobalSmithingReq;
	GlobalArmorPriceBonus := Round(GlobalSmithingReq / 10.0);
	
	GlobalWeaponWeightBonus := GlobalSmithingReq / 20.0;
	GlobalForearmsDebuffMultiplier := FOREARMS_DEBUFF_MULTIPLIER;
	
	{ Reset Tracking Booleans }
	GlobalHasHands := False;
	GlobalHasHandsWasExecuted := False;
	GlobalProcessedRecords := 0;
	
	{ Logging Configuration }
	AddMessage('--- ARMOR CONFIGURATOR STARTED ---');
	AddMessage('SMITHING REQUIREMENT = ' + IntToStr(GlobalSmithingReq));

	{ Validation Logic }
	if (GlobalSmithingReq < 0) or (GlobalSmithingReq > 100) then begin
		AddMessage('ERROR: Smithing value must be between 0 and 100.');
		Result := 1;
		Exit;
	end;  
end;
{========================================================}
{ PROCESS "Runs for every record selected in xEdit"      }
{========================================================}
function Process(selectedRecord: IInterface): integer;
var
	// Utility
	m_recordSignature: string;
	m_Slots: string;
	m_currentFile: IwbFile;
	// Armors
	m_ArmorRating: Float;
	m_ArmorPrice: Integer;
	m_ArmorWeight: Float;
	// Weapons
	m_WeaponDamage: integer;
	m_WeaponPrice: Integer;
	m_WeaponWeight: Double; // Weights should be Double/Float
	//Enchant for ENCHANTMENT_PROTECTION
	m_DummyEnch: IInterface;
	
begin
	m_recordSignature := Signature(selectedRecord);
	GlobalProcessedRecords := GlobalProcessedRecords + 1;
	
	{ 1. Filter: Armor (ARMO) }
	if m_recordSignature = 'ARMO' then begin
		m_Slots := GetFirstPersonFlags(selectedRecord);
		
		{ 1.1 Initialization: Scan for Hands once per file }
		if not GlobalHasHandsWasExecuted then begin // Do Once
			AddMessage('ARMOR RATING BONUS FROM SMITHING SKILL = ' + FloatToStr(GlobalArmorBonus));
			m_currentFile := GetFile(selectedRecord);
			OutfitHasHands(m_currentFile);	
		end;
		
		if not Assigned(m_DummyEnch) then begin
			m_currentFile := GetFile(selectedRecord);
			m_DummyEnch := CreateDummyEnchantment(m_currentFile);
			
		end;
		
		{ 1.2 Classification & Cleanup }
		AddVitalKeywords(selectedRecord, m_Slots);
		
		{ 1.3 Material Logic: Heavy/Light/Clothing }
		SetArmorType(selectedRecord);
		
		{ 1.4 Stat Balancing }
		m_ArmorRating := GetVanillaAR(selectedRecord, m_Slots);  
		SetElementEditValues(selectedRecord, 'DNAM - Armor Rating', FloatToStr(m_ArmorRating));
		
		m_ArmorWeight := GetVanillaAWeight(selectedRecord, m_Slots); 
		SetElementEditValues(selectedRecord, 'DATA\Weight', FloatToStr(m_ArmorWeight));
		
		m_ArmorPrice := Round(GetVanillaAPrice(selectedRecord, m_Slots)); 
		SetElementEditValues(selectedRecord, 'DATA\Value', IntToStr(m_ArmorPrice));
		
		{ 1.5 Finalization }
		fAddEnchProtection(selectedRecord, m_DummyEnch);
		
		{ 1.6 Crafting }
		MakeCraftableV2(selectedRecord);
		
		{ 1.7 Tempering: Block Clothing and Visual Slots }
		if (not IsVisualSlot(m_Slots)) and (not HasKeyword(selectedRecord, 'ArmorClothing')) then begin
			makeTemperable(selectedRecord);
		end;
	end;
	
	{ 2. Filter: Weapon (WEAP) }
	if m_recordSignature = 'WEAP' then begin
	
		if not GlobalHasHandsWasExecuted then begin
		AddMessage(Name(selectedRecord) + ' DAMAGE BONUS FROM SMITHING SKILL + ' + FloatToStr(GlobalArmorBonus));
			GlobalHasHandsWasExecuted := true;
		end;

		{ Standardize Weapon Keywords (VendorItemWeapon, etc.) }
		AddVitalKeywords(selectedRecord, '');
		
		m_WeaponDamage := GetVanillaWDamage(selectedRecord);
		SetElementEditValues(selectedRecord, 'DATA\Damage', IntToStr(m_WeaponDamage));
		//AddMessage(Name(selectedRecord) + ' TOTAL DAMAGE = ' + FloatToStr(GetVanillaWDamage(selectedRecord)));
		
		m_WeaponPrice := GetVanillaWPrice(selectedRecord);
		SetElementEditValues(selectedRecord, 'DATA\Value', IntToStr(m_WeaponPrice));

		m_WeaponWeight := GetVanillaWWeight(selectedRecord);
		SetElementEditValues(selectedRecord, 'DATA\Weight', FloatToStr(m_WeaponWeight));
			
		MakeCraftableV2(selectedRecord);
		makeTemperable(selectedRecord);	
	end;
	
	Result := 0;
end;
{========================================================}
{ CREATE DUMMY ENCHANTMENT                               }
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
			or ((slotName = 'Forearms') and not GlobalHasHands)
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
{ PROTECTION FROM ENCHANTMENTS                           }
{========================================================}
procedure fAddEnchProtection(e: IInterface; enc: IInterface);
var
	kw: IInterface;
	existingDesc: string;
	visualNote: string;
begin
	if not IsVisualSlot(GetFirstPersonFlags(e)) then Exit;
	
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
{ MATERIAL CHECKS                                        }
{========================================================}
function IsLightArmorMaterial(selectedRecord: IInterface): Boolean;
begin
    Result :=
    HasKeyword(selectedRecord,'ArmorMaterialLeather') or
    HasKeyword(selectedRecord,'ArmorMaterialScaled') or
    HasKeyword(selectedRecord,'ArmorMaterialElven') or
    HasKeyword(selectedRecord,'ArmorMaterialGlass') or
    HasKeyword(selectedRecord,'ArmorMaterialDragonscale');
end;
function IsHeavyArmorMaterial(selectedRecord: IInterface): Boolean;
begin
    Result :=
    HasKeyword(selectedRecord,'ArmorMaterialSteel') or
    HasKeyword(selectedRecord,'ArmorMaterialDwarven') or
	HasKeyword(selectedRecord,'ArmorMaterialOrcish') or
    HasKeyword(selectedRecord,'ArmorMaterialSteelPlate') or
    HasKeyword(selectedRecord,'ArmorMaterialEbony') or
	HasKeyword(selectedRecord,'ArmorMaterialDragonplate') or
    HasKeyword(selectedRecord,'ArmorMaterialDaedric');
end;
{========================================================}
{ SET ARMOR TYPE                                         }
{========================================================}
procedure SetArmorType(e: IInterface);
var
	armorTypeField: IInterface;
	Slots: string;
	bisClothing: Boolean;
begin
	armorTypeField := ElementByPath(e, 'BOD2\Armor Type');
	Slots := GetFirstPersonFlags(e);

	{ Accessory / Visual / Jewelry Identification }
	bisClothing := IsVisualSlot(Slots) 
		or (Pos('Ring ', Slots) > 0) 
		or (Pos('Amulet ', Slots) > 0) 
		or (Pos('Backpack ', Slots) > 0);

	if bisClothing then begin
		SetEditValue(armorTypeField, 'Clothing');
		Exit;
	end;
	
	if IsHeavyArmorMaterial(e) then 
		SetEditValue(armorTypeField, 'Heavy Armor')
	else 
		SetEditValue(armorTypeField, 'Light Armor');
end;
{========================================================}
{ ADD VITAL ARMOR KEYWORDS                               }
{========================================================}
procedure AddVitalKeywords(e: IInterface; Slots: string);
var
	kw: IInterface;
	m_sig: string;
	isJewelry, isClothing: Boolean;
begin
	m_sig := Signature(e);

	{ 1. WEAPON LOGIC }
	if m_sig = 'WEAP' then begin
		if not HasKeyword(e, 'VendorItemWeapon') then begin
			kw := GetKeywordByEditorID('VendorItemWeapon');
			if Assigned(kw) then addKeyword(e, kw);
		end;
		Exit;
	end;

	{ 2. ARMOR LOGIC }
	if m_sig = 'ARMO' then begin
		{ Initial Cleanup: Remove all conflicting Type and Vital keywords }
		removeKeyword(e, 'ArmorHelmet');
		removeKeyword(e, 'ArmorCuirass');
		removeKeyword(e, 'ArmorGauntlets');
		removeKeyword(e, 'ArmorBoots');
		removeKeyword(e, 'ArmorShield');
		removeKeyword(e, 'ArmorHeavy');
		removeKeyword(e, 'ArmorLight');
		removeKeyword(e, 'ArmorClothing');

		{ Accessory Logic }
		isJewelry := (Pos('Ring ', Slots) > 0) or (Pos('Amulet ', Slots) > 0);
		isClothing := IsVisualSlot(Slots) or isJewelry or (Pos('Backpack ', Slots) > 0);

		if isClothing then begin
			addKeyword(e, GetKeywordByEditorID('ArmorClothing'));
			if isJewelry then begin
				addKeyword(e, GetKeywordByEditorID('VendorItemJewelry'));
				addKeyword(e, GetKeywordByEditorID('ArmorJewelry'));
			end else begin
				addKeyword(e, GetKeywordByEditorID('VendorItemClothing'));
			end;
			Exit;
		end;

		{ Standard Armor Logic }
		if IsHeavyArmorMaterial(e) then begin
			addKeyword(e, GetKeywordByEditorID('ArmorHeavy'));
			addKeyword(e, GetKeywordByEditorID('VendorItemArmor'));
		end else begin
			addKeyword(e, GetKeywordByEditorID('ArmorLight'));
			addKeyword(e, GetKeywordByEditorID('VendorItemArmor'));
		end;

		{ SHIELD (Slot 39) }
		if Pos('Shield ', Slots) > 0 then begin
			kw := GetKeywordByEditorID('ArmorShield');
			if Assigned(kw) then addKeyword(e, kw);
			Exit;
		end;

		{ BODY }
		if Pos('Body ', Slots) > 0 then begin
			kw := GetKeywordByEditorID('ArmorCuirass');
			if Assigned(kw) then addKeyword(e, kw);
			Exit;
		end;

		{ HEAD / HAIR / CIRCLET }
		if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then begin
			kw := GetKeywordByEditorID('ArmorHelmet');
			if Assigned(kw) then addKeyword(e, kw);
			Exit;
		end;

		{ HANDS / FOREARMS }
		if (Pos('Hands ', Slots) > 0) or ((Pos('Forearms ', Slots) > 0) and (not GlobalHasHands)) then begin
			kw := GetKeywordByEditorID('ArmorGauntlets');
			if Assigned(kw) then addKeyword(e, kw);
			AddFistKeywords(e);
			Exit;
		end;

		{ FEET }
		if Pos('Feet ', Slots) > 0 then begin
			kw := GetKeywordByEditorID('ArmorBoots');
			if Assigned(kw) then addKeyword(e, kw);
			Exit;
		end;
	end;
end;
{========================================================}
{ ADD FIST KEYWORDS                                      }
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
{ CHECK IF ANY SELECTED ARMO RECORD HAS HANDS SLOT       }
{========================================================}
procedure OutfitHasHands(file: IwbFile);
var
	i: Integer;
	rec: IInterface;
begin
	if (GlobalHasHandsWasExecuted = true) then Exit;
	for i := 0 to Pred(RecordCount(file)) do begin
		rec := RecordByIndex(file, i);
		if Signature(rec) = 'ARMO' then begin
			if Pos('Hands', GetFirstPersonFlags(rec)) > 0 then begin
				GlobalHasHands  := True;
				AddMessage('FOUND -HANDS- SLOT IN CURRENT OUTFIT !!!');
				AddMessage('ARMOR -FOREARMS- WIL BE CONSIDERED AS -DECORATION-');
				GlobalHasHandsWasExecuted := True;
				Exit;
			end;
		end;
	end;
	
end;
{========================================================}
{ GET VANILLA WEAPON DAMAGE                              }
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
	if not HasKeyword(e, 'ArmorClothing') then begin
		
		{==================== HEAVY ====================}
		if HasKeyword(e, 'ArmorMaterialIron') then begin
			if Pos('Body ', Slots) > 0 then Result := 25 + GlobalArmorBonus;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 15 + GlobalArmorBonus;
			if Pos('Shield ', Slots) > 0 then Result := 20 + GlobalArmorBonus;
			if Pos('Hands ', Slots) > 0 then Result := 10 + GlobalArmorBonus;
			if Pos('Feet ', Slots) > 0 then Result := 10 + GlobalArmorBonus;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 10 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialSteel') then begin
			if Pos('Body ', Slots) > 0 then Result := 31 + GlobalArmorBonus;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 17 + GlobalArmorBonus;
			if Pos('Shield ', Slots) > 0 then Result := 24 + GlobalArmorBonus;
			if Pos('Hands ', Slots) > 0 then Result := 12 + GlobalArmorBonus;
			if Pos('Feet ', Slots) > 0 then Result := 12 + GlobalArmorBonus;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 12 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialDwarven') then begin
			if Pos('Body ', Slots) > 0 then Result := 34 + GlobalArmorBonus;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 18 + GlobalArmorBonus;
			if Pos('Shield ', Slots) > 0 then Result := 26 + GlobalArmorBonus;
			if Pos('Hands ', Slots) > 0 then Result := 13 + GlobalArmorBonus;
			if Pos('Feet ', Slots) > 0 then Result := 13 + GlobalArmorBonus;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 13 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialOrcish') then begin
			if Pos('Body ', Slots) > 0 then Result := 40 + GlobalArmorBonus;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 20 + GlobalArmorBonus;
			if Pos('Shield ', Slots) > 0 then Result := 30 + GlobalArmorBonus;
			if Pos('Hands ', Slots) > 0 then Result := 15 + GlobalArmorBonus;
			if Pos('Feet ', Slots) > 0 then Result := 15 + GlobalArmorBonus;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 15 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			end;
			Exit;
		end;
		
		if HasKeyword(e, 'ArmorMaterialSteelPlate') then begin
			if Pos('Body ', Slots) > 0 then Result := 40 + GlobalArmorBonus;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 19 + GlobalArmorBonus;
			if Pos('Shield ', Slots) > 0 then Result := 28 + GlobalArmorBonus;
			if Pos('Hands ', Slots) > 0 then Result := 14 + GlobalArmorBonus;
			if Pos('Feet ', Slots) > 0 then Result := 14 + GlobalArmorBonus;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 14 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialEbony') then begin
			if Pos('Body ', Slots) > 0 then Result := 43 + GlobalArmorBonus;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 21 + GlobalArmorBonus;
			if Pos('Shield ', Slots) > 0 then Result := 32 + GlobalArmorBonus;
			if Pos('Hands ', Slots) > 0 then Result := 16 + GlobalArmorBonus;
			if Pos('Feet ', Slots) > 0 then Result := 16 + GlobalArmorBonus;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 16 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialDaedric') or HasKeyword(e, 'ArmorMaterialDragonplate') then begin
			if Pos('Body ', Slots) > 0 then Result := 49 + GlobalArmorBonus;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 23 + GlobalArmorBonus;
			if Pos('Shield ', Slots) > 0 then Result := 36 + GlobalArmorBonus;
			if Pos('Hands ', Slots) > 0 then Result := 18 + GlobalArmorBonus;
			if Pos('Feet ', Slots) > 0 then Result := 18 + GlobalArmorBonus;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 18 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			end;
			Exit;
		end;

		{==================== LIGHT ====================}

		if HasKeyword(e, 'ArmorMaterialLeather') then begin
			if Pos('Body ', Slots) > 0 then Result := 26 + GlobalArmorBonus;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 12 + GlobalArmorBonus;
			if Pos('Shield ', Slots) > 0 then Result := 18 + GlobalArmorBonus;
			if Pos('Hands ', Slots) > 0 then Result := 7 + GlobalArmorBonus;
			if Pos('Feet ', Slots) > 0 then Result := 7 + GlobalArmorBonus;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 7 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialScaled') then begin
			if Pos('Body ', Slots) > 0 then Result := 32 + GlobalArmorBonus;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 14 + GlobalArmorBonus;
			if Pos('Shield ', Slots) > 0 then Result := 20 + GlobalArmorBonus;
			if Pos('Hands ', Slots) > 0 then Result := 9 + GlobalArmorBonus;
			if Pos('Feet ', Slots) > 0 then Result := 9 + GlobalArmorBonus;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 9 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialElven') then begin
			if Pos('Body ', Slots) > 0 then Result := 29 + GlobalArmorBonus;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 13 + GlobalArmorBonus;
			if Pos('Shield ', Slots) > 0 then Result := 21 + GlobalArmorBonus;
			if Pos('Hands ', Slots) > 0 then Result := 8 + GlobalArmorBonus;
			if Pos('Feet ', Slots) > 0 then Result := 8 + GlobalArmorBonus;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 8 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialGlass') then begin
			if Pos('Body ', Slots) > 0 then Result := 38 + GlobalArmorBonus;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 16 + GlobalArmorBonus;
			if Pos('Shield ', Slots) > 0 then Result := 27 + GlobalArmorBonus;
			if Pos('Hands ', Slots) > 0 then Result := 11 + GlobalArmorBonus;
			if Pos('Feet ', Slots) > 0 then Result := 11 + GlobalArmorBonus;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 11 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialDragonscale') then begin
			if Pos('Body ', Slots) > 0 then Result := 41 + GlobalArmorBonus;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 17 + GlobalArmorBonus;
			if Pos('Shield ', Slots) > 0 then Result := 29 + GlobalArmorBonus;
			if Pos('Hands ', Slots) > 0 then Result := 12 + GlobalArmorBonus;
			if Pos('Feet ', Slots) > 0 then Result := 12 + GlobalArmorBonus;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 12 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
			end;
			Exit;
		end;	
	end;
end;
{========================================================}
{ GET VANILLA ARMOR WEIGHT (ENCUMBRANCE)                 }
{========================================================}
function GetVanillaAWeight(e: IInterface; Slots: string): Float;
var
	m_WeightReduceHeavy: Float;
begin
	Result := 1.0;
	m_WeightReduceHeavy := 12; 
	if not HasKeyword(e, 'ArmorClothing') then begin
		
		{==================== HEAVY ====================}
		if HasKeyword(e, 'ArmorMaterialIron') then begin
			if Pos('Body ', Slots) > 0 then Result := 30 - m_WeightReduceHeavy;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 6;
			if Pos('Shield ', Slots) > 0 then Result := 12;
			if Pos('Hands ', Slots) > 0 then Result := 5;
			if Pos('Feet ', Slots) > 0 then Result := 5;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 5 / GlobalForearmsDebuffMultiplier;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialSteel') then begin
			if Pos('Body ', Slots) > 0 then Result := 35 - m_WeightReduceHeavy;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 5;
			if Pos('Shield ', Slots) > 0 then Result := 12;
			if Pos('Hands ', Slots) > 0 then Result := 4;
			if Pos('Feet ', Slots) > 0 then Result := 4;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 4 / GlobalForearmsDebuffMultiplier;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialDwarven') then begin
			if Pos('Body ', Slots) > 0 then Result := 45 - m_WeightReduceHeavy;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 12;
			if Pos('Shield ', Slots) > 0 then Result := 15;
			if Pos('Hands ', Slots) > 0 then Result := 8;
			if Pos('Feet ', Slots) > 0 then Result := 8;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 8 / GlobalForearmsDebuffMultiplier;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialOrcish') then begin
			if Pos('Body ', Slots) > 0 then Result := 35 - m_WeightReduceHeavy;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 8;
			if Pos('Shield ', Slots) > 0 then Result := 14;
			if Pos('Hands ', Slots) > 0 then Result := 7;
			if Pos('Feet ', Slots) > 0 then Result := 7;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 7 / GlobalForearmsDebuffMultiplier;
			end;
			Exit;
		end;
		
		if HasKeyword(e, 'ArmorMaterialSteelPlate') then begin
			if Pos('Body ', Slots) > 0 then Result := 38 - m_WeightReduceHeavy;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 9;
			if Pos('Shield ', Slots) > 0 then Result := 12; { Plate sets usually use standard Steel shields }
			if Pos('Hands ', Slots) > 0 then Result := 6;
			if Pos('Feet ', Slots) > 0 then Result := 6;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 6 / GlobalForearmsDebuffMultiplier;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialEbony') then begin
			if Pos('Body ', Slots) > 0 then Result := 38 - m_WeightReduceHeavy;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 10;
			if Pos('Shield ', Slots) > 0 then Result := 14;
			if Pos('Hands ', Slots) > 0 then Result := 7;
			if Pos('Feet ', Slots) > 0 then Result := 7;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 7 / GlobalForearmsDebuffMultiplier;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialDaedric') then begin
			if Pos('Body ', Slots) > 0 then Result := 50 - m_WeightReduceHeavy;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 10;
			if Pos('Shield ', Slots) > 0 then Result := 15;
			if Pos('Hands ', Slots) > 0 then Result := 6;
			if Pos('Feet ', Slots) > 0 then Result := 6;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 6 / GlobalForearmsDebuffMultiplier;
			end;
			Exit;
		end;

		{==================== LIGHT ====================}
		if HasKeyword(e, 'ArmorMaterialLeather') then begin
			if Pos('Body ', Slots) > 0 then Result := 6;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 2;
			if Pos('Shield ', Slots) > 0 then Result := 4;
			if Pos('Hands ', Slots) > 0 then Result := 2;
			if Pos('Feet ', Slots) > 0 then Result := 2;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 2 / GlobalForearmsDebuffMultiplier;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialScaled') then begin
			if Pos('Body ', Slots) > 0 then Result := 6;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 2;
			if Pos('Shield ', Slots) > 0 then Result := 6;
			if Pos('Hands ', Slots) > 0 then Result := 2;
			if Pos('Feet ', Slots) > 0 then Result := 2;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 2 / GlobalForearmsDebuffMultiplier;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialElven') then begin
			if Pos('Body ', Slots) > 0 then Result := 4;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 1;
			if Pos('Shield ', Slots) > 0 then Result := 4;
			if Pos('Hands ', Slots) > 0 then Result := 1;
			if Pos('Feet ', Slots) > 0 then Result := 1;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 1 / GlobalForearmsDebuffMultiplier;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialGlass') then begin
			if Pos('Body ', Slots) > 0 then Result := 7;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 2;
			if Pos('Shield ', Slots) > 0 then Result := 6;
			if Pos('Hands ', Slots) > 0 then Result := 11;
			if Pos('Feet ', Slots) > 0 then Result := 2;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 2 / GlobalForearmsDebuffMultiplier;
			end;
			Exit;
		end;

		if HasKeyword(e, 'ArmorMaterialDragonscale') then begin
			if Pos('Body ', Slots) > 0 then Result := 10;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 4;
			if Pos('Shield ', Slots) > 0 then Result := 6;
			if Pos('Hands ', Slots) > 0 then Result := 3;
			if Pos('Feet ', Slots) > 0 then Result := 3;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 3 / GlobalForearmsDebuffMultiplier;
			end;
			Exit;
		end;
	end;
end;
{========================================================}
{ GET VANILLA ARMOR PRICE (GOLD VALUE)                   }
{========================================================}
function GetVanillaAPrice(e: IInterface; Slots: string): Float;
begin
	Result := 0.0;
	if not HasKeyword(e, 'ArmorClothing') then begin
	
		{==================== HEAVY ====================}
		if HasKeyword(e, 'ArmorMaterialIron') then begin
			if Pos('Body ', Slots) > 0 then Result := 125;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 60;
			if Pos('Hands ', Slots) > 0 then Result := 25;
			if Pos('Feet ', Slots) > 0 then Result := 25;
			if Pos('Shield ', Slots) > 0 then Result := 60;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 25;
			end;
		end

		else if HasKeyword(e, 'ArmorMaterialSteel') then begin
			if Pos('Body ', Slots) > 0 then Result := 275;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 125;
			if Pos('Hands ', Slots) > 0 then Result := 55;
			if Pos('Feet ', Slots) > 0 then Result := 55;
			if Pos('Shield ', Slots) > 0 then Result := 150;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 55;
			end;
		end

		else if HasKeyword(e, 'ArmorMaterialDwarven') then begin
			if Pos('Body ', Slots) > 0 then Result := 400;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 200;
			if Pos('Hands ', Slots) > 0 then Result := 85;
			if Pos('Feet ', Slots) > 0 then Result := 85;
			if Pos('Shield ', Slots) > 0 then Result := 225;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 85;
			end;
		end

		else if HasKeyword(e, 'ArmorMaterialOrcish') then begin
			if Pos('Body ', Slots) > 0 then Result := 1000;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 500;
			if Pos('Hands ', Slots) > 0 then Result := 200;
			if Pos('Feet ', Slots) > 0 then Result := 200;
			if Pos('Shield ', Slots) > 0 then Result := 500;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 200;
			end;
		end
		
		else if HasKeyword(e, 'ArmorMaterialSteelPlate') then begin
			if Pos('Body ', Slots) > 0 then Result := 625;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 300;
			if Pos('Hands ', Slots) > 0 then Result := 125;
			if Pos('Feet ', Slots) > 0 then Result := 125;
			if Pos('Shield ', Slots) > 0 then Result := 150; 
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 125;
			end;
		end

		else if HasKeyword(e, 'ArmorMaterialEbony') then begin
			if Pos('Body ', Slots) > 0 then Result := 1500;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 750;
			if Pos('Hands ', Slots) > 0 then Result := 275;
			if Pos('Feet ', Slots) > 0 then Result := 275;
			if Pos('Shield ', Slots) > 0 then Result := 750;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 275;
			end;
		end

		else if HasKeyword(e, 'ArmorMaterialDaedric') then begin
			if Pos('Body ', Slots) > 0 then Result := 3200;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 1600;
			if Pos('Hands ', Slots) > 0 then Result := 625;
			if Pos('Feet ', Slots) > 0 then Result := 625;
			if Pos('Shield ', Slots) > 0 then Result := 1600;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 625;
			end;
		end

		else if HasKeyword(e, 'ArmorMaterialDragonplate') then begin
			if Pos('Body ', Slots) > 0 then Result := 2125;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 1050;
			if Pos('Hands ', Slots) > 0 then Result := 425;
			if Pos('Feet ', Slots) > 0 then Result := 425;
			if Pos('Shield ', Slots) > 0 then Result := 1050;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 425;
			end;
		end

		{==================== LIGHT ====================}
		else if HasKeyword(e, 'ArmorMaterialLeather') then begin
			if Pos('Body ', Slots) > 0 then Result := 125;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 60;
			if Pos('Hands ', Slots) > 0 then Result := 25;
			if Pos('Feet ', Slots) > 0 then Result := 25;
			if Pos('Shield ', Slots) > 0 then Result := 40;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 25;
			end;
		end

		else if HasKeyword(e, 'ArmorMaterialScaled') then begin
			if Pos('Body ', Slots) > 0 then Result := 350;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 175;
			if Pos('Hands ', Slots) > 0 then Result := 70;
			if Pos('Feet ', Slots) > 0 then Result := 70;
			if Pos('Shield ', Slots) > 0 then Result := 175; 
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 70;
			end;
		end

		else if HasKeyword(e, 'ArmorMaterialElven') then begin
			if Pos('Body ', Slots) > 0 then Result := 225;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 110;
			if Pos('Hands ', Slots) > 0 then Result := 45;
			if Pos('Feet ', Slots) > 0 then Result := 45;
			if Pos('Shield ', Slots) > 0 then Result := 115;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 45;
			end;
		end

		else if HasKeyword(e, 'ArmorMaterialGlass') then begin
			if Pos('Body ', Slots) > 0 then Result := 900;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 450;
			if Pos('Hands ', Slots) > 0 then Result := 190;
			if Pos('Feet ', Slots) > 0 then Result := 190;
			if Pos('Shield ', Slots) > 0 then Result := 450;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 190;
			end;
		end

		else if HasKeyword(e, 'ArmorMaterialDragonscale') then begin
			if Pos('Body ', Slots) > 0 then Result := 1500;
			if (Pos('Head ', Slots) > 0) or (Pos('Hair ', Slots) > 0) or (Pos('Circlet ', Slots) > 0) then Result := 750;
			if Pos('Hands ', Slots) > 0 then Result := 300;
			if Pos('Feet ', Slots) > 0 then Result := 300;
			if Pos('Shield ', Slots) > 0 then Result := 750;
			if Pos('Forearms ', Slots) > 0 then begin
				if GlobalHasHands then Result := 0
				else Result := 300;
			end;
		end;
		
		if Result > 0 then begin
			Result := Result + GlobalArmorPriceBonus;
		end;
		Exit;
	end;
	{ Clothing armor type only }
	Result := 25 + GlobalArmorPriceBonus;	
end;
{========================================================}
{ UTILITY                                                }
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
	
	{--- WEAPON LOGIC ---}
	if (itemSignature = 'WEAP') then begin
		SetElementEditValues(recipeCraft, 'EDID', 'RecipeWeapon' + GetElementEditValues(itemRecord, 'EDID'));
		SetElementEditValues(recipeCraft, 'BNAM', GetEditValue(getRecordByFormID(WEAPON_CRAFTING_WORKBENCH_FORM_ID)));

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
				addItemV2(recipeItems, GetMaterial('RefinedMalachite'), 1);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeSword')) or (HasKeyword(itemRecord, 'WeapTypeWarAxe')) or (HasKeyword(itemRecord, 'WeapTypeMace')) then begin
				addItemV2(recipeItems, GetMaterial('RefinedMalachite'), 1);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			end else if (HasKeyword(itemRecord, 'WeapTypeGreatsword')) or (HasKeyword(itemRecord, 'WeapTypeBattleaxe')) or (HasKeyword(itemRecord, 'WeapTypeWarhammer')) then begin
				addItemV2(recipeItems, GetMaterial('RefinedMalachite'), 2);
				addItemV2(recipeItems, GetMaterial('IngotRefinedMoonstone'), 1);
				addItemV2(recipeItems, GetMaterial('LeatherStrips'), 3);
			end else if HasKeyword(itemRecord, 'WeapTypeBow') then begin
				addItemV2(recipeItems, GetMaterial('RefinedMalachite'), 2);
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
	
		{ Set Recipe Identity  For Visual Slot Only}
		if IsVisualSlot(GetFirstPersonFlags(itemRecord))then begin
			SetElementEditValues(recipeCraft, 'EDID', 'RecipeVisulaSlot' + GetElementEditValues(itemRecord, 'EDID'));
			SetElementEditValues(recipeCraft, 'BNAM', GetEditValue(getRecordByFormID(ARMOR_CRAFTING_WORKBENCH_FORM_ID)));
		end else begin
			SetElementEditValues(recipeCraft, 'EDID', 'RecipeArmor' + GetElementEditValues(itemRecord, 'EDID'));
			SetElementEditValues(recipeCraft, 'BNAM', GetEditValue(getRecordByFormID(ARMOR_CRAFTING_WORKBENCH_FORM_ID)));
		end;
		{ If Armor is ony for Female actor }
		addFemaleCondition(recipeCraft);
		
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
		
		{ Check if armor considered as "Visual Armor Slot" }
		if IsVisualSlot(GetFirstPersonFlags(itemRecord)) then begin
			addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			
			{ Prevents "Phantom Perks" where accessories trigger high-tier armor buffs }
			removeKeyword(itemRecord, 'ArmorMaterialIron');
			removeKeyword(itemRecord, 'ArmorMaterialSteel');
			removeKeyword(itemRecord, 'ArmorMaterialDwarven');
			removeKeyword(itemRecord, 'ArmorMaterialOrcish');
			removeKeyword(itemRecord, 'ArmorMaterialSteelPlate');
			removeKeyword(itemRecord, 'ArmorMaterialEbony');
			removeKeyword(itemRecord, 'ArmorMaterialDaedric');
			removeKeyword(itemRecord, 'ArmorMaterialDragonplate');
			removeKeyword(itemRecord, 'ArmorMaterialLeather');
			removeKeyword(itemRecord, 'ArmorMaterialScaled');
			removeKeyword(itemRecord, 'ArmorMaterialElven');
			removeKeyword(itemRecord, 'ArmorMaterialGlass');
			removeKeyword(itemRecord, 'ArmorMaterialDragonscale');
			
			{ Cleanup and Validation }
			removeInvalidEntries(recipeCraft);
			if GetElementEditValues(recipeCraft, 'COCT') = '' then begin
				warn('No item requirements specified for: ' + Name(recipeCraft));
			end;
			Result := recipeCraft;
			Exit;
		end;
		
		{ Check if armor considered as "Armor Clothing" }
		if HasKeyword(itemRecord, 'ArmorClothing') then begin
			addItemV2(recipeItems, GetMaterial('Leather01'), 1);
			addItemV2(recipeItems, GetMaterial('LeatherStrips'), 1);
			addItemV2(recipeItems, GetMaterial('IngotIron'), 1);
			
			{ Prevents "Phantom Perks" where accessories trigger high-tier armor buffs }
			removeKeyword(itemRecord, 'ArmorMaterialIron');
			removeKeyword(itemRecord, 'ArmorMaterialSteel');
			removeKeyword(itemRecord, 'ArmorMaterialDwarven');
			removeKeyword(itemRecord, 'ArmorMaterialOrcish');
			removeKeyword(itemRecord, 'ArmorMaterialSteelPlate');
			removeKeyword(itemRecord, 'ArmorMaterialEbony');
			removeKeyword(itemRecord, 'ArmorMaterialDaedric');
			removeKeyword(itemRecord, 'ArmorMaterialDragonplate');
			removeKeyword(itemRecord, 'ArmorMaterialLeather');
			removeKeyword(itemRecord, 'ArmorMaterialScaled');
			removeKeyword(itemRecord, 'ArmorMaterialElven');
			removeKeyword(itemRecord, 'ArmorMaterialGlass');
			removeKeyword(itemRecord, 'ArmorMaterialDragonscale');
			
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
{ END                                                    }
{========================================================}
function Finalize: integer;
begin
	AddMessage('--- SCRIPT PROCESSED ' + IntToStr(GlobalProcessedRecords) + ' RECORDS ---');
	Result := 0;
end;

end.
