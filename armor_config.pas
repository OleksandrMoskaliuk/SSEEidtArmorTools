unit armor_config;
uses SK_UtilsRemake;
{========================================================}
{ GLOBAL VARS                                             }
{========================================================}
const
	DEFAULT_SMITHING = 5;
var
	m_SmithingReq: Integer;
	m_ArmorBonus: Float;
	GlobalHasHands: Boolean;
	GlobalHasHandsWasExecuted: Boolean;
{========================================================}
{ INITIALIZE                                             }
{========================================================}
function Initialize: Integer;
begin
	Result := 0;
	m_SmithingReq := DEFAULT_SMITHING;
	m_ArmorBonus := m_SmithingReq / 10;
	GlobalHasHands := false;
	GlobalHasHandsWasExecuted := false;
  
	AddMessage('Smithing requirement set to: ' + IntToStr(m_SmithingReq));
	AddMessage('Armor bonus: ' + FloatToStr(m_ArmorBonus));

	if (m_SmithingReq < 0) or (m_SmithingReq > 100) then begin
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
	currentFile: IwbFile;
begin
	m_ArmorRating := 0;
	m_ArmorValue := 0;
	m_ArmorWeight := 0;
	m_recordSignature := Signature(selectedRecord);
	
	// Filter selected records, which are not valid
	if not (m_recordSignature = 'ARMO') then exit;
	
	if not(GlobalHasHandsWasExecuted) then begin
	currentFile := GetFile(selectedRecord);
	OutfitHasHands(currentFile);
	end;

	m_ArmorRating := GetElementEditValues(selectedRecord, 'DNAM');  
		AddMessage('Armor Rating: ' + FloatToStr(m_ArmorRating));
	m_ArmorValue := GetElementEditValues(selectedRecord, 'DATA\Value');
		AddMessage('Armor Value: ' + IntToStr(m_ArmorValue));
	m_ArmorWeight := GetElementEditValues(selectedRecord, 'DATA\Weight');
		AddMessage('Armor Weight: ' + FloatToStr(m_ArmorWeight));
	
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
	
	
	//AddMessage(GetArmorBipedSlots(selectedRecord));
	//GetArmorBipedSlot(selectedRecord);
	{if(IsVisualSlot(GetArmorBipedSlot(selectedRecord))) then begin
		AddMessage('Is Visual Slot !!!')
	end else begin
		AddMessage('Is Armor Slot !!!')
	end;}
	
	
	{AddMessage('Armor Rating = ' + 
	FloatToStr(
		GetVanillaAR(
			selectedRecord,GetArmorBipedSlot(selectedRecord)))); 
	}
	
	Result := 0;
end;
{========================================================}
{ SLOT LOGIC                                             }
{========================================================}
function GetArmorBipedSlot(armorRecord: IInterface): string;
var
	bipedFlagsElement: IInterface;
	bipedFlags: Cardinal;
begin
	bipedFlagsElement := ElementByPath(armorRecord, 'BOD2');
	bipedFlags := GetElementNativeValues(bipedFlagsElement, 'First Person Flags');
	AddMessage('Slot = ' + IntToHex(bipedFlags, 8));
	// Get BOD2\Biped Flags
	
    // Check for slots
	Result := '';
	if (bipedFlags and $00000001) <> 0 then Result := Result + 'Head ';
	if (bipedFlags and $00000004) <> 0 then Result := Result + 'Body ';
	if (bipedFlags and $00000008) <> 0 then Result := Result + 'Hands ';
	if (bipedFlags and $00000010) <> 0 then Result := Result + 'Forearms ';
	if (bipedFlags and $00000080) <> 0 then Result := Result + 'Feet ';
	if (bipedFlags and $00000200) <> 0 then Result := Result + 'Shield ';
	if (bipedFlags and $00001000) <> 0 then Result := Result + 'Circlet ';
	AddMessage('Slot = ' + Result);
	
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
	if (GlobalHasHandsWasExecuted) then exit;
	for i := 0 to Pred(RecordCount(file)) do begin
		rec := RecordByIndex(file, i);
		if Signature(rec) = 'ARMO' then begin
			if Pos('Hands', GetArmorBipedSlot(rec)) > 0 then begin
				GlobalHasHands  := True;
				Exit;
			end;
		end;
	end;
	GlobalHasHandsWasExecuted := true;
end;
{========================================================}
{ VANILLA ARMOR RATINGS WITH FOREARMS LOGIC              }
{========================================================}
function GetVanillaAR(e: IInterface; Slots: string; hasHands: Boolean): Float;
begin
	Result := 0;

	{==================== HEAVY ====================}
	if HasKeyword(e,'ArmorMaterialIron') then begin
		if Pos('Body ', Slots) > 0 then Result := 28;
		if Pos('Head ', Slots) > 0 then Result := 15;
		if Pos('Hands ', Slots) > 0 then Result := 10;
		if Pos('Feet ', Slots) > 0 then Result := 10;
		if Pos('Circlet ', Slots) > 0 then Result := 15;
		if Pos('Forearms ', Slots) > 0 then begin
			if hasHands then Result := 0
			else Result := 10 / 2.5;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialSteel') then begin
		if Pos('Body ', Slots) > 0 then Result := 31;
		if Pos('Head ', Slots) > 0 then Result := 17;
		if Pos('Hands ', Slots) > 0 then Result := 12;
		if Pos('Feet ', Slots) > 0 then Result := 12;
		if Pos('Circlet ', Slots) > 0 then Result := 17;
		if Pos('Forearms ', Slots) > 0 then begin
			if hasHands then Result := 0
			else Result := 12 / 2.5;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialDwarven') then begin
		if Pos('Body ', Slots) > 0 then Result := 34;
		if Pos('Head ', Slots) > 0 then Result := 19;
		if Pos('Hands ', Slots) > 0 then Result := 13;
		if Pos('Feet ', Slots) > 0 then Result := 13;
		if Pos('Circlet ', Slots) > 0 then Result := 19;
		if Pos('Forearms ', Slots) > 0 then begin
			if hasHands then Result := 0
			else Result := 13 / 2.5;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialOrcish') then begin
		if Pos('Body ', Slots) > 0 then Result := 37;
		if Pos('Head ', Slots) > 0 then Result := 20;
		if Pos('Hands ', Slots) > 0 then Result := 15;
		if Pos('Feet ', Slots) > 0 then Result := 15;
		if Pos('Circlet ', Slots) > 0 then Result := 20;
		if Pos('Forearms ', Slots) > 0 then begin
			if hasHands then Result := 0
			else Result := 15 / 2.5;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialEbony') then begin
		if Pos('Body ', Slots) > 0 then Result := 43;
		if Pos('Head ', Slots) > 0 then Result := 23;
		if Pos('Hands ', Slots) > 0 then Result := 17;
		if Pos('Feet ', Slots) > 0 then Result := 17;
		if Pos('Circlet ', Slots) > 0 then Result := 23;
		if Pos('Forearms ', Slots) > 0 then begin
			if hasHands then Result := 0
			else Result := 17 / 2.5;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialDaedric') or HasKeyword(e,'ArmorMaterialDragonplate') then begin
		if Pos('Body ', Slots) > 0 then Result := 49;
		if Pos('Head ', Slots) > 0 then Result := 25;
		if Pos('Hands ', Slots) > 0 then Result := 18;
		if Pos('Feet ', Slots) > 0 then Result := 18;
		if Pos('Circlet ', Slots) > 0 then Result := 25;
		if Pos('Forearms ', Slots) > 0 then begin
			if hasHands then Result := 0
			else Result := 18 / 2.5;
		end;
		Exit;
	end;

	{==================== LIGHT ====================}

	if HasKeyword(e,'ArmorMaterialLeather') then begin
		if Pos('Body ', Slots) > 0 then Result := 23;
		if Pos('Head ', Slots) > 0 then Result := 12;
		if Pos('Hands ', Slots) > 0 then Result := 7;
		if Pos('Feet ', Slots) > 0 then Result := 7;
		if Pos('Circlet ', Slots) > 0 then Result := 12;
		if Pos('Forearms ', Slots) > 0 then begin
			if hasHands then Result := 0
			else Result := 7 / 2.5;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialScaled') then begin
		if Pos('Body ', Slots) > 0 then Result := 32;
		if Pos('Head ', Slots) > 0 then Result := 16;
		if Pos('Hands ', Slots) > 0 then Result := 9;
		if Pos('Feet ', Slots) > 0 then Result := 9;
		if Pos('Circlet ', Slots) > 0 then Result := 16;
		if Pos('Forearms ', Slots) > 0 then begin
			if hasHands then Result := 0
			else Result := 9 / 2.5;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialElven') then begin
		if Pos('Body ', Slots) > 0 then Result := 29;
		if Pos('Head ', Slots) > 0 then Result := 15;
		if Pos('Hands ', Slots) > 0 then Result := 8;
		if Pos('Feet ', Slots) > 0 then Result := 8;
		if Pos('Circlet ', Slots) > 0 then Result := 15;
		if Pos('Forearms ', Slots) > 0 then begin
			if hasHands then Result := 0
			else Result := 8 / 2.5;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialGlass') then begin
		if Pos('Body ', Slots) > 0 then Result := 38;
		if Pos('Head ', Slots) > 0 then Result := 18;
		if Pos('Hands ', Slots) > 0 then Result := 11;
		if Pos('Feet ', Slots) > 0 then Result := 11;
		if Pos('Circlet ', Slots) > 0 then Result := 18;
		if Pos('Forearms ', Slots) > 0 then begin
			if hasHands then Result := 0
			else Result := 11 / 2.5;
		end;
		Exit;
	end;

	if HasKeyword(e,'ArmorMaterialDragonscale') then begin
		if Pos('Body ', Slots) > 0 then Result := 41;
		if Pos('Head ', Slots) > 0 then Result := 19;
		if Pos('Hands ', Slots) > 0 then Result := 12;
		if Pos('Feet ', Slots) > 0 then Result := 12;
		if Pos('Circlet ', Slots) > 0 then Result := 19;
		if Pos('Forearms ', Slots) > 0 then begin
			if hasHands then Result := 0
			else Result := 12 / 2.5;
		end;
		Exit;
	end;
end;
{========================================================}
{ END                                                    }
{========================================================}
function Finalize: integer;
begin
  AddMessage('---Armor Config Process Ended---'); 
  Result := 0;
end;
end.
