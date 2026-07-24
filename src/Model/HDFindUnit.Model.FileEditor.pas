unit HDFindUnit.Model.FileEditor;

interface

uses
  ToolsAPI,
  HDFindUnit.Model.Header,
  HDFindUnit.Controller.OTAUtils,
  HDFindUnit.Model.Settings,
  HDFindUnit.Model.Translation,
  HDFindUnit.Utils,
  HDFindUnit.Model.Interf.Translation,
  System.Classes,
  System.SysUtils;

type
  TCharPosition = record
    StartLine: Integer;
    StartPos: Integer;
    EndLine: Integer;
    EndPos: Integer;
  end;

  TFileRegion = class(TObject)
  strict private
    FSource: IOTASourceEditor;
    FUsesNormalized: TStringList;
    FUses: TStringList;
    FUsesPosition: TCharPosition;
    FRegionPosition: TCharPosition;
    FFullFileText: TStringList;

    function RemoveUsesFromList(UsesList: TStrings; ItemToRemove: string): string;
    procedure DeleteInformationFrom(FromLine, ToLine: integer{; var Writer: IOTAEditWriter});
    procedure WriteInformationAtPostion(Line, Position: Integer; const Information: string{; var Writer: IOTAEditWriter});
    function AddUsesInternal(UseUnit: string{; var Writer: IOTAEditWriter}): Boolean; overload;
    function AddUsesInternal(UseUnit: TStringList{; var Writer: IOTAEditWriter}): Boolean; overload;
    function FindCommentedUses(const UnitName: string; out LineIndex: Integer): Boolean;
  public
    constructor Create(SourceEditor: IOTASourceEditor);
    destructor Destroy; override;
    function HaveUses: Boolean;
    property RegionPosition: TCharPosition read FRegionPosition write FRegionPosition;
    property UsesPosition: TCharPosition read FUsesPosition write FUsesPosition;
    procedure SetUsesPosition(NewUsesPosition: TCharPosition);
    procedure GetUsesFromText(FullFileText: TStringList);
    function UsesExists(UseUnit: string): Boolean;
    procedure RemoveUses(UseUnit: string{; var Writer: IOTAEditWriter});
    procedure RemoveAllSection({; var Writer: IOTAEditWriter});
    function AddUses(UseUnit: string{; var Writer: IOTAEditWriter}): Boolean;
    procedure OrganizeUses(var Writer: IOTAEditWriter);
    function GetUsesList: TStringList;
    function AreThereUnparsableCharsInSection: Boolean;
  end;

  TSourceFileEditor = class(TObject)
  private
    FSource: IOTASourceEditor;
    FFileContent: TStringList;
    FInterfaceRegion: TFileRegion;
    FImplementationRegion: TFileRegion;

    procedure ParseInformations;
    function GetInformationsFor(Token: string; SearchForEnd: Boolean; StartLine, EndLine: Integer): TCharPosition;
    procedure GetInfos;

    function AddUsesToRegion(Region: TFileRegion; UseUnit: string{; var Writer: IOTAEditWriter}): Boolean;
  public
    constructor Create(SourceEditor: IOTASourceEditor);
    destructor Destroy; override;

    function Prepare: Boolean;

    function AddUsesToInterface(const UseUnit: string): Boolean;
    function AddUsesToImplementation(const UseUnit: string): Boolean;

    procedure OrganizeUsesInterface;
    procedure OrganizeUsesImplementation;

    procedure RemoveUsesFromInterface(const UseUnit: string);
    procedure RemoveUsesFromImplementation(const UseUnit: string);

    function IsLineOnImplementationSection(Line: Integer): Boolean;

    procedure AddUnit(UnitInfo: TStringPosition; DisplayMessageOnAdd: Boolean = True);
  end;

implementation

uses
  RegExpr,
  HDFindUnit.View.FormMessage,
  System.RegularExpressions;

{ TSourceFileEditor }

procedure TSourceFileEditor.AddUnit(UnitInfo: TStringPosition; DisplayMessageOnAdd: Boolean);
var
  MessageText: string;
begin
  MessageText := '';
  if (not GlobalSettings.AlwaysUseInterfaceSection) and IsLineOnImplementationSection(UnitInfo.Line) then
  begin
    if AddUsesToImplementation(UnitInfo.Value) then
      MessageText := Translation.GetUnitAddedToImplementation(UnitInfo.Value);
  end
  else
  begin
    if AddUsesToInterface(UnitInfo.Value) then
      MessageText := Translation.GetUnitAddedToInterface(UnitInfo.Value);
  end;

  if (MessageText <> '') and DisplayMessageOnAdd then
    TfrmMessage.ShowInfoToUser(MessageText);
end;

function TSourceFileEditor.AddUsesToImplementation(const UseUnit: string): Boolean;
begin
  Prepare;
  Result := AddUsesToRegion(FImplementationRegion, UseUnit);
  FInterfaceRegion.RemoveUses(UseUnit);
end;

function TSourceFileEditor.AddUsesToInterface(const UseUnit: string): Boolean;
begin
  FImplementationRegion.RemoveUses(UseUnit);
  Prepare;
  Result := AddUsesToRegion(FInterfaceRegion, UseUnit);
end;

function TSourceFileEditor.AddUsesToRegion(Region: TFileRegion; UseUnit: string{; var Writer: IOTAEditWriter} ): Boolean;
begin
  Result := Region.AddUses(UseUnit{, Writer});
end;

constructor TSourceFileEditor.Create(SourceEditor: IOTASourceEditor);
begin
  FInterfaceRegion := TFileRegion.Create(SourceEditor);
  FImplementationRegion := TFileRegion.Create(SourceEditor);
  FFileContent := TStringList.Create;
  FSource := SourceEditor;
end;

destructor TSourceFileEditor.Destroy;
begin
  FInterfaceRegion.Destroy;
  FImplementationRegion.Destroy;
  FFileContent.Free;
  inherited;
end;

function TSourceFileEditor.GetInformationsFor(Token: string; SearchForEnd: Boolean; StartLine, EndLine: Integer): TCharPosition;
var
  OutPosition: Integer;
  OutLine: Integer;

  function GetPositionOfString(SearchString: string; iStart, IEnd: Integer; out FoundLine, FoundPosition: Integer): Boolean;
  var
    Line: string;
    Position: Integer;
    BeforeOk: Boolean;
    AfterOk: Boolean;
  begin
    Result := False;
    for iStart := iStart to IEnd do
    begin
      Line := UpperCase(FFileContent[iStart]);

      if SearchString = ';' then
        Position := FindSemicolonExcludingComments(Line)
      else
        Position := Pos(SearchString, Line);

      if Position  = 0 then
        Continue;

      if (SearchString <> ';')
        and (Length(Line) > Length(SearchString))
        and (Line[Length(Line)] = ' ') then
        Continue;

      if SearchString <> ';' then
      begin
        BeforeOk := (Position = 1) or (not CharInSet(Line[Position - 1], ['A'..'Z', '0'..'9', '_']));
        AfterOk := (Position + Length(SearchString) > Length(Line)) or
                   (not CharInSet(Line[Position + Length(SearchString)], ['A'..'Z', '0'..'9', '_']));

        if not (BeforeOk and AfterOk) then
          Continue;
      end;

      FoundLine := iStart;
      FoundPosition := Position;
      Result := True;
      Break;
    end;
  end;
begin
  Result.StartLine := -1;
  Token := UpperCase(Token);
  if not GetPositionOfString(Token, StartLine, EndLine, OutLine, OutPosition) then
    Exit;

  Result.StartLine := OutLine;
  Result.StartPos := OutPosition;

  if SearchForEnd then
  begin
    if GetPositionOfString(';', OutLine, EndLine, OutLine, OutPosition) then
    begin
      Result.EndLine := OutLine;
      Result.EndPos := OutPosition;
    end;
  end;
end;

procedure TSourceFileEditor.GetInfos;
var
  InterfaceEnd: Integer;
begin
  FInterfaceRegion.RegionPosition := GetInformationsFor('interface', False, 0, FFileContent.Count -1);
  FImplementationRegion.RegionPosition := GetInformationsFor('implementation', False, 0, FFileContent.Count -1);

  if FImplementationRegion.RegionPosition.StartLine > -1 then
    InterfaceEnd := FImplementationRegion.RegionPosition.StartLine
  else
    InterfaceEnd := FFileContent.Count -1;

  FInterfaceRegion.UsesPosition := GetInformationsFor('uses', True, FInterfaceRegion.RegionPosition.StartLine, InterfaceEnd);

  if FImplementationRegion.RegionPosition.StartLine > -1 then
    FImplementationRegion.UsesPosition := GetInformationsFor('uses', True, FImplementationRegion.RegionPosition.StartLine, FFileContent.Count -1);

  FImplementationRegion.GetUsesFromText(FFileContent);
  FInterfaceRegion.GetUsesFromText(FFileContent);
end;

function TSourceFileEditor.IsLineOnImplementationSection(Line: Integer): Boolean;
begin
  Result := Line > FImplementationRegion.RegionPosition.StartLine;
end;

procedure TSourceFileEditor.OrganizeUsesImplementation;
var
  Writer: IOTAEditWriter;
begin
  Writer :=  nil;
  FImplementationRegion.OrganizeUses(Writer);
end;

procedure TSourceFileEditor.OrganizeUsesInterface;
var
  Writer: IOTAEditWriter;
begin
  Writer :=  nil;
  FInterfaceRegion.OrganizeUses(Writer);
end;

procedure TSourceFileEditor.ParseInformations;
begin
  GetInfos;
end;

function TSourceFileEditor.Prepare: Boolean;
begin
  try
    Result := True;
    FFileContent.Text := EditorAsString(FSource);
    ParseInformations;
  except
    Result := False;
  end;
end;

procedure TSourceFileEditor.RemoveUsesFromImplementation(const UseUnit: string);
begin
  FImplementationRegion.RemoveUses(UseUnit);
end;

procedure TSourceFileEditor.RemoveUsesFromInterface(const UseUnit: string);
begin
  FInterfaceRegion.RemoveUses(UseUnit);
end;

{ TFileRegion }

procedure TFileRegion.DeleteInformationFrom(FromLine, ToLine: integer{; var Writer: IOTAEditWriter});
var
  StartPosition, EndPosition: TOTACharPos;
  StartPos: Integer;
  EndPos: Integer;
  Writer: IOTAEditWriter;
begin
  Inc(FromLine);
  StartPosition.Line := FromLine;
  StartPosition.CharIndex := 0;

  Inc(ToLine, 2);
  EndPosition.Line := ToLine;
  EndPosition.CharIndex := 0;

  StartPos := FSource.EditViews[0].CharPosToPos(StartPosition);
  EndPos := FSource.EditViews[0].CharPosToPos(EndPosition);

//  if Writer = nil then
    Writer := FSource.CreateUndoableWriter;

  Writer.CopyTo(StartPos);
  Writer.DeleteTo(EndPos);
end;

function TFileRegion.AddUses(UseUnit: string{; var Writer: IOTAEditWriter}): Boolean;
var
  NewUses: TStringList;
  CommentLineIdx: Integer;
  LineText, Uncommented: string;
  Indent: string;
  I: Integer;
  Writer: IOTAEditWriter;
  StartCharPos, EndCharPos: TOTACharPos;
  AbsStart, AbsEnd: Integer;
begin
  Result := False;
  if UsesExists(UseUnit) then
    Exit;

  if FindCommentedUses(UseUnit, CommentLineIdx) then
  begin
    LineText := FFullFileText[CommentLineIdx];

    Indent := '';
    for I := 1 to Length(LineText) do
    begin
      if LineText[I] = ' ' then
        Indent := Indent + ' '
      else
        Break;
    end;

    if (Indent = '') and (CommentLineIdx + 1 <= FUsesPosition.EndLine) then
    begin
      LineText := FFullFileText[CommentLineIdx + 1];
      for I := 1 to Length(LineText) do
      begin
        if LineText[I] = ' ' then
          Indent := Indent + ' '
        else
          Break;
      end;
    end;

    Uncommented := UncommentLine(FFullFileText[CommentLineIdx]);
    if Uncommented <> '' then
    begin
      if (not Uncommented.EndsWith(',')) and (not Uncommented.EndsWith(';')) then
        Uncommented := Uncommented + ',';

      StartCharPos.Line := CommentLineIdx + 1;
      StartCharPos.CharIndex := 0;
      EndCharPos.Line := CommentLineIdx + 2;
      EndCharPos.CharIndex := 0;

      AbsStart := FSource.EditViews[0].CharPosToPos(StartCharPos);
      AbsEnd := FSource.EditViews[0].CharPosToPos(EndCharPos);

      Writer := FSource.CreateUndoableWriter;
      Writer.CopyTo(AbsStart);
      Writer.DeleteTo(AbsEnd);
      Writer.Insert(PAnsiChar(AnsiToUtf8(Indent + Uncommented + #13#10)));
    end;

    Exit(True);
  end;

  if GlobalSettings.OrganizeUsesAfterAddingNewUses and GlobalSettings.SortUsesAfterAdding and (not AreThereUnparsableCharsInSection) then
  begin
    NewUses := GetUsesList;
    try
      RemoveAllSection;
      FFullFileText.Text := EditorAsString(FSource);
      NewUses.Add(UseUnit);
      AddUsesInternal(NewUses);
    finally
      NewUses.Free;
    end;
  end
  else
    AddUsesInternal(UseUnit{Writer});
end;

function TFileRegion.AddUsesInternal(UseUnit: string{; var Writer: IOTAEditWriter}): Boolean;
var
  Line: Integer;
  PosChar: Integer;
  NewUsesPosition: TCharPosition;
  UnitContent: string;
  RegReturn: TMatchCollection;
begin
  Result := True;

  RegReturn := TRegEx.Matches(UseUnit.ToUpper, '\b' + 'USES' + '[^<.>]');

  if (RegReturn.Count > 0) or UseUnit.IsEmpty then
    Exit;

  Line := UsesPosition.EndLine;
  PosChar := UsesPosition.EndPos -1;
  if not HaveUses then
  begin
    Line := RegionPosition.StartLine + 1;
    PosChar := 0;

    UnitContent := '  ' + UseUnit + ';';
    if (RegionPosition.StartLine + 1 < FFullFileText.Count) and (Trim(FFullFileText[RegionPosition.StartLine + 1]) = '') then
      UseUnit := #13#10 + 'uses' + #13#10 + UnitContent + #13#10
    else
      UseUnit := #13#10 + 'uses' + #13#10 + UnitContent + #13#10 + #13#10;

    NewUsesPosition.StartLine := Line;
    NewUsesPosition.StartPos := PosChar;
    NewUsesPosition.EndLine := NewUsesPosition.StartLine + 2;
    NewUsesPosition.EndPos := UnitContent.Length;

    SetUsesPosition(NewUsesPosition);
  end
  else
  begin
    if (PosChar > Integer(GlobalSettings.BreakUsesLineAt)) or (GlobalSettings.BreakLine)  then
      UseUnit := ',' + #13#10 + '  ' + UseUnit
    else
      UseUnit := ', ' + UseUnit;
  end;

  WriteInformationAtPostion(Line, PosChar, UseUnit{, Writer});
end;

function CompareNamespaces(List: TStringList; Index1, Index2: Integer): Integer;
var
  ItemOne: string;
  ItemTwo: string;
  ItemOneHasDot: Boolean;
  ItemTwoHasDot: Boolean;
begin
  ItemOne := List[Index1];
  ItemTwo := List[Index2];

  ItemOneHasDot := Pos('.', ItemOne) > 0;
  ItemTwoHasDot := Pos('.', ItemTwo) > 0;

  if (ItemOneHasDot = ItemTwoHasDot) then
    Result := CompareStr(ItemOne, ItemTwo)
  else if ItemOneHasDot then
    Result := 1
  else
    Result := -1;
end;

function GetUsesLevel(const AUnit: string): Integer;
var
  UnitUpper: string;
begin
  UnitUpper := UpperCase(AUnit);

  // Level 0: RTL (System.*, Data.*, WinApi.*, etc.)
  if (Pos('SYSTEM.', UnitUpper) = 1) or
     (Pos('DATA.', UnitUpper) = 1) or
     (Pos('WINAPI.', UnitUpper) = 1) or
     (UnitUpper = 'CLASSES') or
     (UnitUpper = 'SYSUTILS') or
     (UnitUpper = 'STRUTILS') or
     (UnitUpper = 'TYPES') or
     (UnitUpper = 'VARIANTS') or
     (UnitUpper = 'MATH') or
     (UnitUpper = 'DATEUTILS') or
     (UnitUpper = 'IOUTILS') or
     (UnitUpper = 'REGISTRY') or
     (UnitUpper = 'INIFILES') or
     (UnitUpper = 'REGEX') or
     (UnitUpper = 'TYPINFO') or
     (UnitUpper = 'RTTI') or
     (UnitUpper = 'SYNCObjs') or
     (UnitUpper = 'THREADS') or
     (UnitUpper = 'DIAGNOSTICS') then
    Result := 0
  // Level 1: VCL (Vcl.*)
  else if Pos('VCL.', UnitUpper) = 1 then
    Result := 1
  // Level 2: FMX (FMX.*)
  else if Pos('FMX.', UnitUpper) = 1 then
    Result := 2
  // Level 3: Third-party (has namespace)
  else if Pos('.', UnitUpper) > 0 then
    Result := 3
  // Level 4: Project units (no namespace)
  else
    Result := 4;
end;

function CompareUsesByLevel(List: TStringList; Index1, Index2: Integer): Integer;
var
  Level1: Integer;
  Level2: Integer;
begin
  Level1 := GetUsesLevel(List[Index1]);
  Level2 := GetUsesLevel(List[Index2]);

  if Level1 = Level2 then
    Result := CompareStr(List[Index1], List[Index2])
  else
    Result := Level1 - Level2;
end;

function TFileRegion.AddUsesInternal(UseUnit: TStringList{; var Writer: IOTAEditWriter}): Boolean;
var
  Line: Integer;
  PosChar: Integer;
  NewUsesPosition: TCharPosition;
  NewUses: string;
  UseCur: string;
  CurDomain: string;
  LastDomain: string;
  MustAddBlankLine: Boolean;
  CharCount: Integer;
  UseCurLength: Integer;
  FinalUseCur: string;
  HasNamespace: Boolean;
begin
  MustAddBlankLine := False;
  Result := True;

  if GlobalSettings.SortUsesAfterAdding then
  begin
    if GlobalSettings.SortUsesByLevel then
      UseUnit.CustomSort(CompareUsesByLevel)
    else if GlobalSettings.GroupNonNamespaceUnits then
      UseUnit.CustomSort(CompareNamespaces)
    else
      UseUnit.Sort;
  end;

  LastDomain := '';
  NewUses := '';
  CharCount := 0;
  for UseCur in UseUnit do
  begin
    HasNamespace := Pos('.', UseCur) > 0;
    if (UseCur.Trim.ToUpper = 'USES')
      or (UseCur.Trim.IsEmpty) then
      Continue;

    if NewUses.IsEmpty then
    begin
      NewUses := '  ' + UseCur;

      CharCount := Length(NewUses);

      LastDomain := UseCur;
      LastDomain := Fetch(LastDomain, '.', False);
    end
    else if ((not HasNamespace) and GlobalSettings.BreakLineForNonDomainUses and GlobalSettings.BreakLine)
        or (HasNamespace and GlobalSettings.BreakLine) then
    begin

      if GlobalSettings.BlankLineBtwNamespaces then
      begin
        CurDomain := UseCur;
        CurDomain := Fetch(CurDomain, '.', False);

        if GlobalSettings.GroupNonNamespaceUnits and (not HasNamespace) then
          MustAddBlankLine := False
        else if not LastDomain.IsEmpty  then
          MustAddBlankLine := not CurDomain.Equals(LastDomain);
        LastDomain := CurDomain;
      end;

      if MustAddBlankLine then
        NewUses := NewUses + ',' + #13#10 + #13#10 + '  ' + UseCur
      else
        NewUses := NewUses + ',' + #13#10 + '  ' + UseCur;

      MustAddBlankLine := False;
    end
    else
    begin
      UseCurLength := Length(UseCur);
      if (CharCount + UseCurLength) >= Integer(GlobalSettings.BreakUsesLineAt) then
      begin
        NewUses := NewUses + ',' + #13#10 + '  ' + UseCur;
        CharCount := UseCurLength + 2 {padding};
      end
      else
      begin
        FinalUseCur := ', ' + UseCur;
        NewUses := NewUses + FinalUseCur;
        CharCount := CharCount + Length(FinalUseCur);
      end;
    end;
  end;
  NewUses := NewUses + ';';

  Line := UsesPosition.EndLine;
  PosChar := UsesPosition.EndPos -1;
  if not HaveUses then
  begin
    Line := RegionPosition.StartLine + 1;
    PosChar := 0;

    NewUses := #13#10 + 'uses' + #13#10 + NewUses + #13#10;

    NewUsesPosition.StartLine := Line;
    NewUsesPosition.StartPos := PosChar;
    NewUsesPosition.EndLine := NewUsesPosition.StartLine + 2;
    NewUsesPosition.EndPos := NewUses.Length;

    SetUsesPosition(NewUsesPosition);
  end
  else
    NewUses := #13#10 + 'uses' + #13#10 + NewUses + #13#10;
  WriteInformationAtPostion(Line, PosChar, NewUses{, Writer});
end;

function TFileRegion.AreThereUnparsableCharsInSection: Boolean;
var
  I: Integer;
  UsesText: TStringList;
begin
  Result := False;
  if not HaveUses then
    Exit;

  UsesText := TStringList.Create;
  try
    for I := FUsesPosition.StartLine to FUsesPosition.EndLine do
      UsesText.Add(Trim(FFullFileText[I]));

    Result := (UsesText.Text.IndexOf('/') > 0) or (UsesText.Text.IndexOf('{') > 0);
  finally
    UsesText.Free;
  end;
end;

constructor TFileRegion.Create(SourceEditor: IOTASourceEditor);
begin
  FUsesNormalized := TStringList.Create;
  FUsesNormalized.Duplicates := dupIgnore;
  FUsesNormalized.Sorted := True;

  FUses := TStringList.Create;
  FUses.Duplicates := dupIgnore;
  FUses.Sorted := True;

  FSource := SourceEditor;
end;

destructor TFileRegion.Destroy;
begin
  FUsesNormalized.Free;
  FUses.Free;
  inherited;
end;

procedure TFileRegion.GetUsesFromText(FullFileText: TStringList);
var
  I: Integer;
  LocalUses: TStringList;
  Line: string;
  Item: string;
begin
  FFullFileText := FullFileText;
  if not HaveUses then
    Exit;

  LocalUses := TStringList.Create;
  try
    for I := FUsesPosition.StartLine to FUsesPosition.EndLine do
      LocalUses.Add(Trim(RemoveDelphiComments(FullFileText[I])));

    LocalUses.Text := StringReplace(LocalUses.Text,' ',',', [rfReplaceAll]);
    LocalUses.Text := StringReplace(LocalUses.Text,';',',', [rfReplaceAll]);

    for I := 0 to LocalUses.Count -1 do
    begin
      Line := LocalUses[i];
      while Line <> '' do
      begin
        Item := Fetch(Line, ',');
        FUsesNormalized.Add(UpperCase(Item));
        FUses.Add(Item);
      end;
    end;
  finally
    LocalUses.Free;
  end;
end;

function TFileRegion.GetUsesList: TStringList;
begin
  Result := TStringList.Create;
  Result.Text := FUses.Text;
end;

function TFileRegion.HaveUses: Boolean;
begin
  Result := UsesPosition.StartLine > 0;
end;

procedure TFileRegion.OrganizeUses(var Writer: IOTAEditWriter);
var
  NewUses: TStringList;
  LineText: string;
begin
  if not HaveUses then
    Exit;

  if (FUsesPosition.StartLine >= 1) and (FUsesPosition.StartLine <= FFullFileText.Count) then
  begin
    LineText := UpperCase(Trim(FFullFileText[FUsesPosition.StartLine]));
    if Copy(LineText, 1, 4) <> 'USES' then
      Exit;
    if (Length(LineText) > 4) and CharInSet(LineText[5], ['A'..'Z', '0'..'9']) then
      Exit;
  end;

  if GlobalSettings.SortUsesAfterAdding and (not AreThereUnparsableCharsInSection) then
  begin
    NewUses := GetUsesList;
    try
      RemoveAllSection;
      FFullFileText.Text := EditorAsString(FSource);
      AddUsesInternal(NewUses);
    finally
      NewUses.Free;
    end;
  end;
end;

procedure TFileRegion.RemoveAllSection({; var Writer: IOTAEditWriter});
begin
  if not HaveUses then
    Exit;

  DeleteInformationFrom(FUsesPosition.StartLine - 1, FUsesPosition.EndLine{, Writer});
  FUsesPosition.StartLine := 0;
  FUsesPosition.StartPos := 0;
  FUsesPosition.EndLine := 0;
  FUsesPosition.EndPos := 0;
  FUsesNormalized.Clear;
  FUses.Clear;
end;

procedure TFileRegion.RemoveUses(UseUnit: string{; var Writer: IOTAEditWriter});
var
  I: Integer;
  LocalUses: TStringList;
  SavedStartLine: Integer;
begin

  if not UsesExists(UseUnit) then
    Exit;

  SavedStartLine := FUsesPosition.StartLine;

//  Writer := nil;
  FFullFileText.Text := EditorAsString(ActiveSourceEditor);
  LocalUses := TStringList.Create;
  try
    for I := SavedStartLine to FUsesPosition.EndLine do
      LocalUses.Add(FFullFileText[I]);

    LocalUses.Text := RemoveUsesFromList(LocalUses, UseUnit);
    DeleteInformationFrom(SavedStartLine, FUsesPosition.EndLine{, Writer});
    if UpperCase(Trim(LocalUses.Text)) <> 'USES'  then
      WriteInformationAtPostion(SavedStartLine, 0, LocalUses.Text{, Writer});

    FUsesPosition.StartLine := 0;
    FUsesPosition.StartPos := 0;
    FUsesPosition.EndLine := 0;
    FUsesPosition.EndPos := 0;
    FUsesNormalized.Clear;
    FUses.Clear;
  finally
    LocalUses.Free;
  end;
end;

function TFileRegion.RemoveUsesFromList(UsesList: TStrings; ItemToRemove: string): string;
const
  Mask = '[^a-zA-Z0-9]%s[^a-zA-Z0-9]';
var
  Regex: TRegExpr;
  MaskFilter: string;
begin
  MaskFilter := Format(Mask, [ItemToRemove]);
  Regex := TRegExpr.Create;
  Regex.Expression := MaskFilter;

  Result :=  Trim(Regex.Replace(UsesList.Text, '', True));
  if (Result <> '') and (Result[Length(Result)] = ',') then
  begin
    Delete(Result, Length(Result), 1);
    Result := Result + ';';
  end;
end;

procedure TFileRegion.SetUsesPosition(NewUsesPosition: TCharPosition);
begin
  FUsesPosition := NewUsesPosition;
end;

function TFileRegion.UsesExists(UseUnit: string): Boolean;
begin
  Result := FUsesNormalized.IndexOf(UpperCase(UseUnit)) > -1;
end;

procedure TFileRegion.WriteInformationAtPostion(Line, Position: Integer; const Information: string{; var Writer: IOTAEditWriter});
var
  InfoPosition: TOTACharPos;
  SetPosition: Integer;
  Writer: IOTAEditWriter;
begin
  if Information = '' then
    Exit;

  Line := Line + 1;
  InfoPosition.Line := Line;
  InfoPosition.CharIndex := Position;

  SetPosition := FSource.EditViews[0].CharPosToPos(InfoPosition);

////  NewUsesPosition.StartLine := FUsesPosition.StartLine;
////  NewUsesPosition.StartPos := FUsesPosition.StartPos;
////  NewUsesPosition.EndLine := InfoPosition.Line;
////  NewUsesPosition.EndPos := InfoPosition.CharIndex + Length(Information);
//
//  SetUsesPosition(NewUsesPosition);

//  if Writer = nil then
    Writer := FSource.CreateUndoableWriter;

  Writer.CopyTo(SetPosition);
  Writer.Insert(PAnsiChar(AnsiToUtf8(Information)));
end;

function TFileRegion.FindCommentedUses(const UnitName: string; out LineIndex: Integer): Boolean;
var
  I: Integer;
  LineText, CleanLine: string;
  UpperUnit: string;
begin
  Result := False;
  if not HaveUses then
    Exit;

  UpperUnit := UpperCase(UnitName);

  for I := FUsesPosition.StartLine to FUsesPosition.EndLine do
  begin
    LineText := FFullFileText[I];
    CleanLine := RemoveDelphiComments(LineText);

    if (Pos(UpperUnit, UpperCase(LineText)) > 0) and
       (Pos(UpperUnit, UpperCase(CleanLine)) = 0) then
    begin
      LineIndex := I;
      Exit(True);
    end;
  end;
end;

end.
