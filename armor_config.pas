unit armor_config;
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
	m_ArmorValue: Integer;
	m_ArmorWeight: Float;
	// Check if Outfit Has Hands Slot if Not Forearms will have additional armmor rating
	m_currentFile: IwbFile;
begin
	m_ArmorRating := 0;
	m_ArmorValue := 0;
	m_ArmorWeight := 0;
	m_recordSignature := Signature(selectedRecord);
	GlobalProcessedRecords := GlobalProcessedRecords + 1;
	// Filter selected records, which are not valid
	if not (m_recordSignature = 'ARMO') then exit;
	
	if (GlobalHasHandsWasExecuted = false) then begin
	m_currentFile := GetFile(selectedRecord);
	OutfitHasHands(m_currentFile);
	end;
    
	{
	m_ArmorRating := GetElementEditValues(selectedRecord, 'DNAM');  
		AddMessage('Armor Rating: ' + FloatToStr(m_ArmorRating));
	m_ArmorValue := GetElementEditValues(selectedRecord, 'DATA\Value');
		AddMessage('Armor Value: ' + IntToStr(m_ArmorValue));
	m_ArmorWeight := GetElementEditValues(selectedRecord, 'DATA\Weight');
		AddMessage('Armor Weight: ' + FloatToStr(m_ArmorWeight));
	}
	// hasKeyword(selectedRecord, 'ArmorJewelry');
	{if (IsLightArmorMaterial(selectedRecord)) then 
	begin
		AddMessage('Is Light MATERIAL!!!');
		AddMessage('Is Light MATERIAL!!!');
	end else begin
		AddMessage('Is Heavy MATERIAL!!!');
		AddMessage('Is Heavy MATERIAL!!!');
	end;}
	
	// Set the new value for the Item
	//SetElementNativeValues(selectedRecord, 'DATA\Value', itemValue);
	
	
	//AddMessage(GetFirstPersonFlagss(selectedRecord));
	//GetFirstPersonFlags(selectedRecord);
	{if(IsVisualSlot(GetFirstPersonFlags(selectedRecord))) then begin
		AddMessage('Is Visual Slot !!!')
	end else begin
		AddMessage('Is Armor Slot !!!')
	end;}
	
	{	// GetFirstPersonFlags Test  
	AddMessage('Armor Rating = ' + 
		FloatToStr(selectedRecord,GetFirstPersonFlags(selectedRecord))); 
	}
	
	// GET AR TEST
	// GetVanillaAR(e: IInterface; Slots: string; hasHands: Boolean): Float;
	AddMessage('AWeight = ' + FloatToStr(
		GetVanillaAWeight(selectedRecord, GetFirstPersonFlags(selectedRecord))));
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
	//AddMessage('Slot = ' + IntToHex(bipedFlags, 8) + ' ' + Result);
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
        (slotName = 'Forearms') or
        (slotName = 'Feet') or
		(slotName = 'Circlet') or
        (slotName = 'Shield')
      ) then begin
        Result := True; // any unknown slot → visual
        Exit;
      end;
    end;

  finally
    slots.Free;
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
    HasKeyword(selectedRecord,'ArmorMaterialSteelPlate') or
    HasKeyword(selectedRecord,'ArmorMaterialEbony') or
	HasKeyword(selectedRecord,'ArmorMaterialDragonplate') or
    HasKeyword(selectedRecord,'ArmorMaterialDaedric');
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
{ END                                                    }
{========================================================}
function Finalize: integer;
begin
	AddMessage('SCRIPT PROCESSED ' + IntToStr(GlobalProcessedRecords) + ' RECORDS');
	Result := 0;
end;
end.
