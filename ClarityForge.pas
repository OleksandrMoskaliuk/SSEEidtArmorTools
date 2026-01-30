{
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
{========================================================}
{ GLOBAL VARS                                            }
{========================================================}
const
	DEFAULT_SMITHING = 5;
	FOREARMS_DEBUFF_MULTIPLIER = 2.5;
var
	GlobalSmithingReq: Integer;
	GlobalArmorBonus: Float;
	GlobalHasHands: Boolean;
	GlobalHasHandsWasExecuted: Boolean;
	GlobalProcessedRecords: Integer;
	GlobalForearmsDebuffMultiplier: Float;
{========================================================}
{ INITIALIZE                                             }
{========================================================}
function Initialize: Integer;
begin
	Result := 0;
	GlobalSmithingReq := DEFAULT_SMITHING;
	GlobalArmorBonus := GlobalSmithingReq / 10;
	GlobalHasHands := false;
	GlobalHasHandsWasExecuted := false;
	GlobalProcessedRecords := 0;
	GlobalForearmsDebuffMultiplier := FOREARMS_DEBUFF_MULTIPLIER;
	AddMessage('---ARMOR CONFIGURATOR STARTED---');
	AddMessage('SMITHING REQUIREMENT = ' + IntToStr(DEFAULT_SMITHING));
	AddMessage('ARMOR BONUS = ' + FloatToStr(GlobalArmorBonus));

	if (GlobalSmithingReq < 0) or (GlobalSmithingReq > 100) then begin
		AddMessage('ERROR: Smithing value must be between 0 and 100.');
		Result := 1;
		exit;
	end;  
end;
{========================================================}
{ PROCESS "Runs for every record selected in xEdit"      }
{========================================================}
function Process(selectedRecord: IInterface): integer;
var
	m_recordSignature: string;
	m_ArmorRating: Float;
	m_ArmorPrice: Integer;
	m_ArmorWeight: Float;
	m_currentFile: IwbFile;
	m_Slots: string;
begin
	m_ArmorRating := 0;
	m_ArmorPrice := 0;
	m_ArmorWeight := 0.0;
	m_recordSignature := Signature(selectedRecord);
	
	GlobalProcessedRecords := GlobalProcessedRecords + 1;

	{ 1. Filter: Skip records that are not Armor (ARMO) }
	if not (m_recordSignature = 'ARMO') then Exit;
	
	m_Slots := GetFirstPersonFlags(selectedRecord);

	{ 2. Initialization: Scan the file for 'Hands' slot once per session }
	{ This determines if 'Forearms' should be treated as functional armor or decoration }
	if not GlobalHasHandsWasExecuted then begin
		m_currentFile := GetFile(selectedRecord);
		OutfitHasHands(m_currentFile);
	end;

	{ 3. Cleanup: Remove keywords that do not belong to the item's specific slots }
	{ Example: 'ArmorCuirass' keyword is removed from 'Head' or 'Hands' slots }
	RemoveRedundantKeywords(selectedRecord, m_Slots);
	
	{ 4. Classification: Add vital armor keywords (Cuirass, Helmet, etc.) }
	{ Based on the First Person Flags (Biped Slots) }
	AddVitalKeywords(selectedRecord, m_Slots);
	
	{ 5. Material Logic: Set Armor Type (Heavy/Light/Clothing) based on materials }
	SetArmorType(selectedRecord);
	
	{ 6. Stat Balancing: Apply vanilla-aligned base values }
	m_ArmorRating := GetVanillaAR(selectedRecord, m_Slots);  
	SetElementEditValues(selectedRecord, 'DNAM - Armor Rating', m_ArmorRating);
	
	m_ArmorWeight := GetVanillaAWeight(selectedRecord, m_Slots); 
	SetElementEditValues(selectedRecord, 'DATA\Weight', m_ArmorWeight);
	
	m_ArmorPrice := GetVanillaAPrice(selectedRecord, m_Slots); 
	SetElementEditValues(selectedRecord, 'DATA\Value', m_ArmorPrice);
	
	{ 7. Finalization: Handle 'Visual Slots' (0 weight/value/AR + Enchanting Block) }
	FinalizeVisualSlot(selectedRecord);
	
	{ 8. Crafting: Generate recipes based on the finalized keywords and stats }
	{ Visual slots receive a 'token cost' recipe (e.g., 1 Gold) }
	MakeCraftableV2(selectedRecord);
	
	{ 9. Tempering: Add improvement recipes only for functional armor pieces }
	if not IsVisualSlot(m_Slots) then begin
		{ Supports tempering for both enchanted and non-enchanted items }
		makeTemperable(selectedRecord);
	end;
	
	Result := 0;
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
	if (bipedFlags and $00000001) <> 0 then Result := Result + 'Head ';
	if (bipedFlags and $00000004) <> 0 then Result := Result + 'Body ';
	if (bipedFlags and $00000008) <> 0 then Result := Result + 'Hands ';
	if (bipedFlags and $00000010) <> 0 then Result := Result + 'Forearms ';
	if (bipedFlags and $00000080) <> 0 then Result := Result + 'Feet ';
	if (bipedFlags and $00000200) <> 0 then Result := Result + 'Shield ';
	if (bipedFlags and $00001000) <> 0 then Result := Result + 'Circlet ';
	if (bipedFlags and $00000020) <> 0 then Result := Result + 'Amulet ';
	if (bipedFlags and $00010000) <> 0 then Result := Result + 'Ring ';
	AddMessage('Slot = ' + IntToHex(bipedFlags, 8) + ' ' + Result);
end;

function IsVisualSlot(armor: string): Boolean;
var
	slots: TStringList;
	i: Integer;
	slotName: string;
begin
	Result := False;
	// Empty slot string = visual-only item
	if Trim(armor) = '' then begin
		Result := True;
		Exit;
	end;
	slots := TStringList.Create;
	try
		slots.StrictDelimiter := True;
		slots.Delimiter := ' ';
		slots.DelimitedText := Trim(armor);
	for i := 0 to slots.Count - 1 do begin
		slotName := slots[i];
		// Allowed gameplay slots ONLY
		if not (
		(slotName = 'Head') or
		(slotName = 'Body') or
		(slotName = 'Hands') or
		((slotName = 'Forearms') and not GlobalHasHands) or
		(slotName = 'Feet') or
		(slotName = 'Circlet') or
		(slotName = 'Shield'))
		then begin
			Result := True; // any unknown slot → visual
			Exit;
		end;
    end;
	finally
		slots.Free;
	end;
end;

procedure FinalizeVisualSlot(e: IInterface);
var
	kw: IInterface;
	existingDesc: string;
	visualNote: string;
	isAccessory: Boolean;
begin
	if not IsVisualSlot(GetFirstPersonFlags(e)) then Exit;
	visualNote := 'Visual Slot: This item is for appearance only. It provides no protection and cannot be enchanted.';
	{ Check if it's an enchantable accessory }
	isAccessory := (Pos('Amulet ', GetFirstPersonFlags(e)) > 0) or (Pos('Ring ', GetFirstPersonFlags(e)) > 0);
	
	if not isAccessory then begin
	
		{ 1. Add MagicDisallowEnchanting safely }
		{ We use the EditorID check since it is a standard vanilla keyword }
		if not HasKeyword(e, 'MagicDisallowEnchanting') then begin
			kw := GetKeywordByEditorID('MagicDisallowEnchanting');
			if Assigned(kw) then 
				addKeyword(e, kw);
		end;

		{ 2. Handle Description (Clean & Update) }
		{ If DESC exists, we check if our note is already there to avoid duplicates }
		existingDesc := GetElementEditValues(e, 'DESC');
		
		if Pos(visualNote, existingDesc) = 0 then begin
			{ If there is old text, we decide to overwrite it or append }
			{ For Visual Slots, overwriting is cleaner for your balance philosophy }
			if not Assigned(ElementBySignature(e, 'DESC')) then
				Add(e, 'DESC', True);
				
			SetElementEditValues(e, 'DESC', visualNote);
		end;
	end;
	{ 3. Apply Balance Stats }
	SetElementEditValues(e, 'DNAM - Armor Rating', '0');
	SetElementEditValues(e, 'DATA\Weight', '0.0');
	SetElementEditValues(e, 'DATA\Value', '0');
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
	kwLight, kwHeavy, kwCloth: IInterface;
begin
	armorTypeField := ElementByPath(e, 'BOD2\Armor Type');
	if not Assigned(armorTypeField) then Exit;

	{ 1. Identify Armor Type and Keywords }
	if IsHeavyArmorMaterial(e) then begin
		SetEditValue(armorTypeField, 'Heavy Armor');
		
		{ Ensure correct keyword and remove others }
		removeKeyword(e, 'ArmorLight');
		removeKeyword(e, 'ArmorClothing');
		addKeyword(e, GetKeywordByEditorID('ArmorHeavy'));
		AddMessage('Set to Heavy Armor + Keyword: ' + Name(e));
	end
	
	else if IsLightArmorMaterial(e) then begin
		SetEditValue(armorTypeField, 'Light Armor');
		
		{ Ensure correct keyword and remove others }
		removeKeyword(e, 'ArmorHeavy');
		removeKeyword(e, 'ArmorClothing');
		addKeyword(e, GetKeywordByEditorID('ArmorLight'));
		AddMessage('Set to Light Armor + Keyword: ' + Name(e));
	end
	
	else begin
		{ Default for Visual Slots / Clothing }
		SetEditValue(armorTypeField, 'Clothing');
		
		{ Ensure correct keyword and remove others }
		removeKeyword(e, 'ArmorHeavy');
		removeKeyword(e, 'ArmorLight');
		addKeyword(e, GetKeywordByEditorID('ArmorClothing'));
		AddMessage('Set to Clothing + Keyword: ' + Name(e));
	end;
end;
{========================================================}
{ ADD VITAL ARMOR KEYWORDS                               }
{========================================================}
procedure AddVitalKeywords(e: IInterface; Slots: string;);
var
	kw: IInterface;
begin
	if (IsVisualSlot(Slots) = False) then begin

		{==================== BODY ====================}
		if Pos('Body ', Slots) > 0 then begin
			if HasKeyword(e, 'ArmorHelmet') then removeKeyword(e, 'ArmorHelmet');
			if HasKeyword(e, 'ArmorGauntlets') then removeKeyword(e, 'ArmorGauntlets');
			if HasKeyword(e, 'ArmorBoots') then removeKeyword(e, 'ArmorBoots');
			if not HasKeyword(e, 'ArmorCuirass') then 
			begin
				kw := GetKeywordByEditorID('ArmorCuirass');
				if Assigned(kw) then
				addKeyword(e, kw);
			end;
		end;

		{==================== HEAD ====================}
		if Pos('Head ', Slots) > 0 then begin
			if HasKeyword(e, 'ArmorCuirass') then removeKeyword(e, 'ArmorCuirass');
			if HasKeyword(e, 'ArmorGauntlets') then removeKeyword(e, 'ArmorGauntlets');
			if HasKeyword(e, 'ArmorBoots') then removeKeyword(e, 'ArmorBoots');
			if not HasKeyword(e, 'ArmorHelmet') then
			begin
				kw := GetKeywordByEditorID('ArmorHelmet');
				if Assigned(kw) then
				addKeyword(e, kw);
			end;
		end;

		{==================== HANDS ====================}
		if Pos('Hands ', Slots) > 0 then begin
			if HasKeyword(e, 'ArmorHelmet') then removeKeyword(e, 'ArmorHelmet');
			if HasKeyword(e, 'ArmorCuirass') then removeKeyword(e, 'ArmorCuirass');
			if HasKeyword(e, 'ArmorBoots') then removeKeyword(e, 'ArmorBoots');
			if not HasKeyword(e, 'ArmorGauntlets') then
			begin
				kw := GetKeywordByEditorID('ArmorGauntlets');
				if Assigned(kw) then
				addKeyword(e, kw);
			end;
		end;

		{==================== FEET ====================}
		if Pos('Feet ', Slots) > 0 then begin
			if HasKeyword(e, 'ArmorHelmet') then removeKeyword(e, 'ArmorHelmet');
			if HasKeyword(e, 'ArmorCuirass') then removeKeyword(e, 'ArmorCuirass');
			if HasKeyword(e, 'ArmorGauntlets') then removeKeyword(e, 'ArmorGauntlets');
			if not HasKeyword(e, 'ArmorBoots') then
			begin
				kw := GetKeywordByEditorID('ArmorBoots');
				if Assigned(kw) then
				addKeyword(e, kw);
			end;
		end;

		{==================== CIRCLET ====================}
		if Pos('Circlet ', Slots) > 0 then begin
			if HasKeyword(e, 'ArmorCuirass') then removeKeyword(e, 'ArmorCuirass');
			if HasKeyword(e, 'ArmorGauntlets') then removeKeyword(e, 'ArmorGauntlets');
			if HasKeyword(e, 'ArmorBoots') then removeKeyword(e, 'ArmorBoots');
			if not HasKeyword(e, 'ArmorHelmet') then
			begin
				kw := GetKeywordByEditorID('ArmorHelmet');
				if Assigned(kw) then
				addKeyword(e, kw);
			end;
		end;

		{==================== FOREARMS ====================}
		if Pos('Forearms ', Slots) > 0 then begin
			if HasKeyword(e, 'ArmorHelmet') then removeKeyword(e, 'ArmorHelmet');
			if HasKeyword(e, 'ArmorCuirass') then removeKeyword(e, 'ArmorCuirass');
			if HasKeyword(e, 'ArmorBoots') then removeKeyword(e, 'ArmorBoots');
			// If real Hands armor exists in outfit → forearms are VISUAL ONLY
			if GlobalHasHands then begin
				if HasKeyword(e, 'ArmorGauntlets') then
					removeKeyword(e, 'ArmorGauntlets');
			end
			// Otherwise forearms act as gauntlets
			else begin
				if not HasKeyword(e, 'ArmorGauntlets') then
				begin
					kw := GetKeywordByEditorID('ArmorGauntlets');
					if Assigned(kw) then
					addKeyword(e, kw);
				end;
			end;
		end;
		
		AddFistKeywords(e);
		
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
{ REMOVE REDUNDANT KEYWORD                               }
{========================================================}
procedure RemoveRedundantKeywords(e: IInterface; Slots: string;);
begin
	// Visual slot only for appearence 
	// Requiem will increse armor rating drasticly if one of this keys is present
	if (IsVisualSlot(Slots)) then begin
		if HasKeyword(e, 'ArmorHelmet') then begin
			removeKeyword(e, 'ArmorHelmet');
			AddMessage('ArmorHelmet removed');
		end;
		if HasKeyword(e, 'ArmorCuirass') then begin
			removeKeyword(e, 'ArmorCuirass');
			AddMessage('ArmorCuirass removed from Visula Slot');
		end;
		if HasKeyword(e, 'ArmorGauntlets') then begin
			removeKeyword(e, 'ArmorGauntlets');
			AddMessage('ArmorGauntlets removed from Visula Slot');
		end;
		if HasKeyword(e, 'ArmorBoots') then begin
			removeKeyword(e, 'ArmorBoots');
			AddMessage('ArmorBoots removed from Visula Slot');
		end;
	end;
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
{ VANILLA ARMOR RATINGS WITH FOREARMS LOGIC              }
{========================================================}
function GetVanillaAR(e: IInterface; Slots: string;): Float;
begin
	Result := 0;

	{==================== HEAVY ====================}
	if HasKeyword(e,'ArmorMaterialIron') then begin
		if Pos('Body ', Slots) > 0 then Result := 25 + GlobalArmorBonus;
		if Pos('Head ', Slots) > 0 then Result := 15 + GlobalArmorBonus;
		if Pos('Hands ', Slots) > 0 then Result := 10 + GlobalArmorBonus;
		if Pos('Feet ', Slots) > 0 then Result := 10 + GlobalArmorBonus;
		if Pos('Circlet ', Slots) > 0 then Result := 15 + GlobalArmorBonus;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 10 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialSteel') then begin
		if Pos('Body ', Slots) > 0 then Result := 31 + GlobalArmorBonus;
		if Pos('Head ', Slots) > 0 then Result := 17 + GlobalArmorBonus;
		if Pos('Hands ', Slots) > 0 then Result := 12 + GlobalArmorBonus;
		if Pos('Feet ', Slots) > 0 then Result := 12 + GlobalArmorBonus;
		if Pos('Circlet ', Slots) > 0 then Result := 17 + GlobalArmorBonus;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 12 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialDwarven') then begin
		if Pos('Body ', Slots) > 0 then Result := 34 + GlobalArmorBonus;
		if Pos('Head ', Slots) > 0 then Result := 18 + GlobalArmorBonus;
		if Pos('Hands ', Slots) > 0 then Result := 13 + GlobalArmorBonus;
		if Pos('Feet ', Slots) > 0 then Result := 13 + GlobalArmorBonus;
		if Pos('Circlet ', Slots) > 0 then Result := 18 + GlobalArmorBonus;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 13 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialOrcish') then begin
		if Pos('Body ', Slots) > 0 then Result := 40 + GlobalArmorBonus;
		if Pos('Head ', Slots) > 0 then Result := 20 + GlobalArmorBonus;
		if Pos('Hands ', Slots) > 0 then Result := 15 + GlobalArmorBonus;
		if Pos('Feet ', Slots) > 0 then Result := 15 + GlobalArmorBonus;
		if Pos('Circlet ', Slots) > 0 then Result := 20 + GlobalArmorBonus;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 15 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
		end;
		Exit;
	end;
	
	if HasKeyword(e,'ArmorMaterialSteelPlate') then begin
		if Pos('Body ', Slots) > 0 then Result := 40 + GlobalArmorBonus;
		if Pos('Head ', Slots) > 0 then Result := 19 + GlobalArmorBonus;
		if Pos('Hands ', Slots) > 0 then Result := 14 + GlobalArmorBonus;
		if Pos('Feet ', Slots) > 0 then Result := 14 + GlobalArmorBonus;
		if Pos('Circlet ', Slots) > 0 then Result := 19 + GlobalArmorBonus;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 14 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialEbony') then begin
		if Pos('Body ', Slots) > 0 then Result := 43 + GlobalArmorBonus;
		if Pos('Head ', Slots) > 0 then Result := 21 + GlobalArmorBonus;
		if Pos('Hands ', Slots) > 0 then Result := 16 + GlobalArmorBonus;
		if Pos('Feet ', Slots) > 0 then Result := 16 + GlobalArmorBonus;
		if Pos('Circlet ', Slots) > 0 then Result := 21 + GlobalArmorBonus;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 16 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialDaedric') or HasKeyword(e,'ArmorMaterialDragonplate') then begin
		if Pos('Body ', Slots) > 0 then Result := 49 + GlobalArmorBonus;
		if Pos('Head ', Slots) > 0 then Result := 23 + GlobalArmorBonus;
		if Pos('Hands ', Slots) > 0 then Result := 18 + GlobalArmorBonus;
		if Pos('Feet ', Slots) > 0 then Result := 18 + GlobalArmorBonus;
		if Pos('Circlet ', Slots) > 0 then Result := 23 + GlobalArmorBonus;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 18 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
		end;
		Exit;
	end;

	{==================== LIGHT ====================}

	if HasKeyword(e,'ArmorMaterialLeather') then begin
		if Pos('Body ', Slots) > 0 then Result := 26 + GlobalArmorBonus;
		if Pos('Head ', Slots) > 0 then Result := 12 + GlobalArmorBonus;
		if Pos('Hands ', Slots) > 0 then Result := 7 + GlobalArmorBonus;
		if Pos('Feet ', Slots) > 0 then Result := 7 + GlobalArmorBonus;
		if Pos('Circlet ', Slots) > 0 then Result := 12 + GlobalArmorBonus;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 7 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialScaled') then begin
		if Pos('Body ', Slots) > 0 then Result := 32 + GlobalArmorBonus;
		if Pos('Head ', Slots) > 0 then Result := 14 + GlobalArmorBonus;
		if Pos('Hands ', Slots) > 0 then Result := 9 + GlobalArmorBonus;
		if Pos('Feet ', Slots) > 0 then Result := 9 + GlobalArmorBonus;
		if Pos('Circlet ', Slots) > 0 then Result := 14 + GlobalArmorBonus;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 9 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialElven') then begin
		if Pos('Body ', Slots) > 0 then Result := 29 + GlobalArmorBonus;
		if Pos('Head ', Slots) > 0 then Result := 13 + GlobalArmorBonus;
		if Pos('Hands ', Slots) > 0 then Result := 8 + GlobalArmorBonus;
		if Pos('Feet ', Slots) > 0 then Result := 8 + GlobalArmorBonus;
		if Pos('Circlet ', Slots) > 0 then Result := 13 + GlobalArmorBonus;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 8 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialGlass') then begin
		if Pos('Body ', Slots) > 0 then Result := 38 + GlobalArmorBonus;
		if Pos('Head ', Slots) > 0 then Result := 16 + GlobalArmorBonus;
		if Pos('Hands ', Slots) > 0 then Result := 11 + GlobalArmorBonus;
		if Pos('Feet ', Slots) > 0 then Result := 11 + GlobalArmorBonus;
		if Pos('Circlet ', Slots) > 0 then Result := 16 + GlobalArmorBonus;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0;
			else Result := 11 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialDragonscale') then begin
		if Pos('Body ', Slots) > 0 then Result := 41 + GlobalArmorBonus;
		if Pos('Head ', Slots) > 0 then Result := 17 + GlobalArmorBonus;
		if Pos('Hands ', Slots) > 0 then Result := 12 + GlobalArmorBonus;
		if Pos('Feet ', Slots) > 0 then Result := 12 + GlobalArmorBonus;
		if Pos('Circlet ', Slots) > 0 then Result := 17 + GlobalArmorBonus;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 12 / GlobalForearmsDebuffMultiplier + GlobalArmorBonus;
		end;
		Exit;
	end;
end;
{========================================================}
{ GET VANILLA ARMOR WEIGHT (ENCUMBRANCE)                  }
{========================================================}
function GetVanillaAWeight(e: IInterface; Slots: string): Float;
var
	m_WeightReduceHeavy: Float;
begin
	Result := 0.0;
	m_WeightReduceHeavy := 12; 
	{==================== HEAVY ====================}
	if HasKeyword(e,'ArmorMaterialIron') then begin
		if Pos('Body ', Slots) > 0 then Result := 30 - m_WeightReduceHeavy;
		if Pos('Head ', Slots) > 0 then Result := 6;
		if Pos('Hands ', Slots) > 0 then Result := 5;
		if Pos('Feet ', Slots) > 0 then Result := 5;
		if Pos('Circlet ', Slots) > 0 then Result := 5;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 5 / GlobalForearmsDebuffMultiplier;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialSteel') then begin
		if Pos('Body ', Slots) > 0 then Result := 35 - m_WeightReduceHeavy;
		if Pos('Head ', Slots) > 0 then Result := 5;
		if Pos('Hands ', Slots) > 0 then Result := 4;
		if Pos('Feet ', Slots) > 0 then Result := 4;
		if Pos('Circlet ', Slots) > 0 then Result := 4;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 4 / GlobalForearmsDebuffMultiplier;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialDwarven') then begin
		if Pos('Body ', Slots) > 0 then Result := 45 - m_WeightReduceHeavy;
		if Pos('Head ', Slots) > 0 then Result := 12;
		if Pos('Hands ', Slots) > 0 then Result := 8;
		if Pos('Feet ', Slots) > 0 then Result := 8;
		if Pos('Circlet ', Slots) > 0 then Result := 8;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 8 / GlobalForearmsDebuffMultiplier;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialOrcish') then begin
		if Pos('Body ', Slots) > 0 then Result := 35 - m_WeightReduceHeavy;
		if Pos('Head ', Slots) > 0 then Result := 8;
		if Pos('Hands ', Slots) > 0 then Result := 7;
		if Pos('Feet ', Slots) > 0 then Result := 7;
		if Pos('Circlet ', Slots) > 0 then Result := 7;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 7 / GlobalForearmsDebuffMultiplier;
		end;
		Exit;
	end;
	
	if HasKeyword(e,'ArmorMaterialSteelPlate') then begin
		if Pos('Body ', Slots) > 0 then Result := 38 - m_WeightReduceHeavy;
		if Pos('Head ', Slots) > 0 then Result := 9;
		if Pos('Hands ', Slots) > 0 then Result := 6;
		if Pos('Feet ', Slots) > 0 then Result := 6;
		if Pos('Circlet ', Slots) > 0 then Result := 6;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 6 / GlobalForearmsDebuffMultiplier;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialEbony') then begin
		if Pos('Body ', Slots) > 0 then Result := 38 - m_WeightReduceHeavy;
		if Pos('Head ', Slots) > 0 then Result := 10;
		if Pos('Hands ', Slots) > 0 then Result := 7;
		if Pos('Feet ', Slots) > 0 then Result := 7;
		if Pos('Circlet ', Slots) > 0 then Result := 7;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 7 / GlobalForearmsDebuffMultiplier;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialDaedric') then begin
		if Pos('Body ', Slots) > 0 then Result := 50 - m_WeightReduceHeavy;
		if Pos('Head ', Slots) > 0 then Result := 10;
		if Pos('Hands ', Slots) > 0 then Result := 6;
		if Pos('Feet ', Slots) > 0 then Result := 6;
		if Pos('Circlet ', Slots) > 0 then Result := 6;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 6 / GlobalForearmsDebuffMultiplier;
		end;
		Exit;
	end;

	{==================== LIGHT ====================}
	if HasKeyword(e,'ArmorMaterialLeather') then begin
		if Pos('Body ', Slots) > 0 then Result := 6;
		if Pos('Head ', Slots) > 0 then Result := 2;
		if Pos('Hands ', Slots) > 0 then Result := 2;
		if Pos('Feet ', Slots) > 0 then Result := 2;
		if Pos('Circlet ', Slots) > 0 then Result := 2;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 2 / GlobalForearmsDebuffMultiplier;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialScaled') then begin
		if Pos('Body ', Slots) > 0 then Result := 6;
		if Pos('Head ', Slots) > 0 then Result := 2;
		if Pos('Hands ', Slots) > 0 then Result := 2;
		if Pos('Feet ', Slots) > 0 then Result := 2;
		if Pos('Circlet ', Slots) > 0 then Result := 2;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 2 / GlobalForearmsDebuffMultiplier;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialElven') then begin
		if Pos('Body ', Slots) > 0 then Result := 4;
		if Pos('Head ', Slots) > 0 then Result := 1;
		if Pos('Hands ', Slots) > 0 then Result := 1;
		if Pos('Feet ', Slots) > 0 then Result := 1;
		if Pos('Circlet ', Slots) > 0 then Result := 1;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 1 / GlobalForearmsDebuffMultiplier;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialGlass') then begin
		if Pos('Body ', Slots) > 0 then Result := 7;
		if Pos('Head ', Slots) > 0 then Result := 2;
		if Pos('Hands ', Slots) > 0 then Result := 2;
		if Pos('Feet ', Slots) > 0 then Result := 2;
		if Pos('Circlet ', Slots) > 0 then Result := 2;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 2 / GlobalForearmsDebuffMultiplier;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialDragonscale') then begin
		if Pos('Body ', Slots) > 0 then Result := 10;
		if Pos('Head ', Slots) > 0 then Result := 4;
		if Pos('Hands ', Slots) > 0 then Result := 3;
		if Pos('Feet ', Slots) > 0 then Result := 3;
		if Pos('Circlet ', Slots) > 0 then Result := 3;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 3  / GlobalForearmsDebuffMultiplier;
		end;
		Exit;
	end;
end;
{========================================================}
{ GET VANILLA ARMOR PRICE (GOLD VALUE)                   }
{========================================================}
function GetVanillaAPrice(e: IInterface; Slots: string): Float;
begin
	Result := 0.0;

	{==================== HEAVY ====================}
	if HasKeyword(e,'ArmorMaterialIron') then begin
		if Pos('Body ', Slots) > 0 then Result := 125;
		if Pos('Head ', Slots) > 0 then Result := 60;
		if Pos('Hands ', Slots) > 0 then Result := 25;
		if Pos('Feet ', Slots) > 0 then Result := 25;
		if Pos('Circlet ', Slots) > 0 then Result := 60;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 25;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialSteel') then begin
		if Pos('Body ', Slots) > 0 then Result := 275;
		if Pos('Head ', Slots) > 0 then Result := 125;
		if Pos('Hands ', Slots) > 0 then Result := 55;
		if Pos('Feet ', Slots) > 0 then Result := 55;
		if Pos('Circlet ', Slots) > 0 then Result := 125;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 55;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialDwarven') then begin
		if Pos('Body ', Slots) > 0 then Result := 400;
		if Pos('Head ', Slots) > 0 then Result := 200;
		if Pos('Hands ', Slots) > 0 then Result := 85;
		if Pos('Feet ', Slots) > 0 then Result := 85;
		if Pos('Circlet ', Slots) > 0 then Result := 200;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 85;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialOrcish') then begin
		if Pos('Body ', Slots) > 0 then Result := 1000;
		if Pos('Head ', Slots) > 0 then Result := 500;
		if Pos('Hands ', Slots) > 0 then Result := 200;
		if Pos('Feet ', Slots) > 0 then Result := 200;
		if Pos('Circlet ', Slots) > 0 then Result := 500;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 200;
		end;
		Exit;
	end;
	
	if HasKeyword(e,'ArmorMaterialSteelPlate') then begin
		if Pos('Body ', Slots) > 0 then Result := 625;
		if Pos('Head ', Slots) > 0 then Result := 300;
		if Pos('Hands ', Slots) > 0 then Result := 125;
		if Pos('Feet ', Slots) > 0 then Result := 125;
		if Pos('Circlet ', Slots) > 0 then Result := 300;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 125;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialEbony') then begin
		if Pos('Body ', Slots) > 0 then Result := 1500;
		if Pos('Head ', Slots) > 0 then Result := 750;
		if Pos('Hands ', Slots) > 0 then Result := 275;
		if Pos('Feet ', Slots) > 0 then Result := 275;
		if Pos('Circlet ', Slots) > 0 then Result := 750;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 275;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialDaedric') then begin
		if Pos('Body ', Slots) > 0 then Result := 3200;
		if Pos('Head ', Slots) > 0 then Result := 1600;
		if Pos('Hands ', Slots) > 0 then Result := 625;
		if Pos('Feet ', Slots) > 0 then Result := 625;
		if Pos('Circlet ', Slots) > 0 then Result := 1600;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 625;
		end;
		Exit;
	end;

	{==================== LIGHT ====================}
	if HasKeyword(e,'ArmorMaterialLeather') then begin
		if Pos('Body ', Slots) > 0 then Result := 125;
		if Pos('Head ', Slots) > 0 then Result := 60;
		if Pos('Hands ', Slots) > 0 then Result := 25;
		if Pos('Feet ', Slots) > 0 then Result := 25;
		if Pos('Circlet ', Slots) > 0 then Result := 60;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 25;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialScaled') then begin
		if Pos('Body ', Slots) > 0 then Result := 350;
		if Pos('Head ', Slots) > 0 then Result := 175;
		if Pos('Hands ', Slots) > 0 then Result := 70;
		if Pos('Feet ', Slots) > 0 then Result := 70;
		if Pos('Circlet ', Slots) > 0 then Result := 175;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 70;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialElven') then begin
		if Pos('Body ', Slots) > 0 then Result := 225;
		if Pos('Head ', Slots) > 0 then Result := 110;
		if Pos('Hands ', Slots) > 0 then Result := 45;
		if Pos('Feet ', Slots) > 0 then Result := 45;
		if Pos('Circlet ', Slots) > 0 then Result := 110;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 45;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialGlass') then begin
		if Pos('Body ', Slots) > 0 then Result := 900;
		if Pos('Head ', Slots) > 0 then Result := 450;
		if Pos('Hands ', Slots) > 0 then Result := 190;
		if Pos('Feet ', Slots) > 0 then Result := 190;
		if Pos('Circlet ', Slots) > 0 then Result := 450;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 190;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialDragonscale') then begin
		if Pos('Body ', Slots) > 0 then Result := 1500;
		if Pos('Head ', Slots) > 0 then Result := 750;
		if Pos('Hands ', Slots) > 0 then Result := 300;
		if Pos('Feet ', Slots) > 0 then Result := 300;
		if Pos('Circlet ', Slots) > 0 then Result := 750;
		if Pos('Forearms ', Slots) > 0 then begin
			if GlobalHasHands then Result := 0
			else Result := 300;
		end;
		Exit;
	end;
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
	else if aName = 'IngotCorundum' then fID := '0005AD93' { <--- Added Corundum }
	else if aName = 'IngotDwarven' then fID := '000DB611'
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
	
	Result := getRecordByFormID(fID);
	
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
{ CREATE CRAFTING RECIPE (COBJ)                          }
{========================================================}
function MakeCraftableV2(itemRecord: IInterface): IInterface;
var
	recipeCraft, recipeItems, tmpKeywordsCollection, tmp: IInterface;
	itemSignature, currentKeywordEDID: string;
	amountOfMainComponent, amountOfAdditionalComponent, amountOfLeatherComponent, i: integer;
begin
	itemSignature := Signature(itemRecord);

	{ 1. Filter: Only allow Weapons or Armor }
	if not ((itemSignature = 'WEAP') or (itemSignature = 'ARMO')) then
		Exit;

	{ 2. Create the base COBJ record }
	recipeCraft := createRecipe(itemRecord);
	if not Assigned(recipeCraft) then Exit;

	{ 3. Initialize Required Items list }
	Add(recipeCraft, 'items', True);
	recipeItems := ElementByPath(recipeCraft, 'items');
	
	{ 4. Process Material Keywords for Perk requirements }
	tmpKeywordsCollection := ElementBySignature(itemRecord, 'KWDA');

	{ --- WEAPON LOGIC --- }
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
	end;
	
	{ --- ARMOR LOGIC --- }
	if (itemSignature = 'ARMO') then begin
	{ Set Recipe Identity }
		SetElementEditValues(recipeCraft, 'EDID', 'RecipeArmor' + GetElementEditValues(itemRecord, 'EDID'));
		SetElementEditValues(recipeCraft, 'BNAM', GetEditValue(getRecordByFormID(ARMOR_CRAFTING_WORKBENCH_FORM_ID)));
	end;
	
	{ Add your global skill requirement condition (e.g. Smithing 25) }
	if GlobalSmithingReq > 0 then begin
		addSkillCondition(recipeCraft, GlobalSmithingReq);
	end;
	
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
	
	// Check if "Visual Armor Slot"
	if IsVisualSlot(GetFirstPersonFlags(itemRecord)) then begin
		addItemV2(recipeItems, GetMaterial('Gold001'), 1);
		// Cleanup and Validation
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
