unit HDFindUnit.Model.UnusedUses;

interface

uses
  DelphiAST,
  Log4Pascal,
  DelphiAST.Classes,
  DelphiAST.Writer,
  HDFindUnit.Model.DelphiReservedWords,
  HDFindUnit.Model.PasParser,
  HDFindUnit.Utils,
  SimpleParser.Lexer.Types,
  System.Character,
  System.Classes,
  System.Diagnostics,
  System.Generics.Collections,
  System.StrUtils,
  System.SysUtils,
  HDFindUnit.Model.Settings,
  HDFindUnit.Controller.Interf.EnvironmentController;

type
  TUnusedErrorType = (uetUnused, uetNoPasFile, uetDcp);

  TUsesUnit = record
    Line: Integer;
    Collumn: Integer;
    Name: string;
    UnusedType: TUnusedErrorType;
  end;

  TUnsedUsesProcessor = class(TObject)
  private
    FFilePath: string;
    FIncluder: IIncludeHandler;
    FUnitNode: TSyntaxNode;
    FEnvControl: IRFUEnvironmentController;

    FUses: TDictionary<string, TUsesUnit>;
    FUsedTypes: TDictionary<string, string>;
    FIgnoredTypes: TDictionary<string, string>;
    FIgnoredUses: TDictionary<string, string>;
    FMatches: TDictionary<string, string>;
    FUnusedUses: TDictionary<string, TUsesUnit>;
    FImplicitUsedUnits: TDictionary<string, string>;

    FOptionalUsesPrefix: TStringList;
    FUsesStartLine: Integer;

    function GetUsedTypes: TDictionary<string, string>;
    procedure FallbackAddTypesFromSource(Result: TDictionary<string, string>);
    procedure FallbackAddImplicitDeps;
    function GetUnitSpecifiedOnUses: TDictionary<string, TUsesUnit>;
    function GetNotIndexedUnusedType(UnitName: string): TUnusedErrorType;
    function GetFullMatchsForUses: TDictionary<string, string>;
    function GetIgnoredTypes: TDictionary<string, string>;
    function GetIgnoredUses: TDictionary<string, string>;
    function GetUnusedUses: TDictionary<string, TUsesUnit>;
    function GetOptionalUsesPrefix: TStringList;
  public
    constructor Create(AFilePath: string);
    destructor Destroy; override;

    procedure Process;

    procedure SetIncluder(Includer: IIncludeHandler);
    procedure SetEnvControl(EnvControl: IRFUEnvironmentController);

    function GetUnusedUsesAsString: string;
    function HasUnusedUses: Boolean;

    property UnusedUses: TDictionary<string, TUsesUnit> read FUnusedUses;
    property UsesStartLine: Integer read FUsesStartLine write FUsesStartLine;
  end;

implementation

uses
  System.IOUtils,
  System.SyncObjs,
  Winapi.Windows,
  HDFindUnit.Model.Header;

var
  GNotIndexedCache: TDictionary<string, TUnusedErrorType>;
  GIdesourcePasNames: TDictionary<string, Boolean>;
  GIdesourceScanDone: Boolean;
  GNotIndexedCacheLock: TCriticalSection;

type
  TCodeScanState = (csCode, csBraceComment, csParenComment);

const
  CommonNonTypeWords: array[0..81] of string = (
    'CREATE', 'DESTROY', 'FREE', 'GET', 'SET', 'ADD', 'REMOVE', 'CLEAR',
    'ASSIGN', 'COPY', 'MOVE', 'SETLENGTH',
    'OPEN', 'CLOSE', 'SHOW', 'SHOWMODAL', 'HIDE', 'EXECUTE', 'UPDATE',
    'INSERT', 'DELETE', 'READ', 'WRITE', 'SEEK', 'LOAD', 'SAVE', 'REFRESH',
    'START', 'STOP', 'PAUSE', 'RESUME', 'INIT', 'REGISTER', 'DRAW', 'PAINT',
    'CLICK', 'SETFOCUS', 'BRINGTOFRONT', 'SENDTOBACK', 'INVALIDATE', 'REPAINT',
    'CLASSNAME', 'TOSTRING', 'EQUALS', 'GETHASHCODE', 'GETTYPE', 'INHERITED',
    'CAPTION', 'TEXT', 'WIDTH', 'HEIGHT', 'TOP', 'LEFT', 'COLOR', 'FONT',
    'PARENT', 'OWNER', 'NAME', 'ENABLED', 'VISIBLE', 'READONLY', 'CHECKED',
    'ITEMS', 'COUNT', 'POSITION', 'SIZE', 'VALUE', 'TAG', 'HINT', 'ALIGN',
    'ALIGNMENT', 'ANCHORS', 'AUTOSIZE', 'TITLE', 'DATA', 'KEY', 'INDEX',
    'NEXT', 'PREVIOUS', 'FIRST', 'LAST', 'FIND'
  );

  // Namespaces of units managed by the IDE form designer. Forms (.dfm/.fmx)
  // stream their controls and live bindings at runtime; the units that
  // provide the streamed property types (e.g. Data.DB T*Field), the
  // presentation layer, the LiveBindings engine and the FireDAC runtime are
  // injected and re-added by the IDE whenever the form is saved. They are
  // rarely referenced by type in the .pas, so they must be protected for
  // form units. All entries are uppercase to match the FUses keys.
  FormInfraPrefixes: array[0..12] of string = (
    'FMX.',
    'FIREDAC.',
    'DATA.BIND.',
    'SYSTEM.BINDINGS.',
    'SYSTEM.RTTI',
    'SYSTEM.SKIA',
    'SYSTEM.UITYPES',
    'SYSTEM.ACTIONS',
    'SYSTEM.IMAGELIST',
    'DATA.DB',
    'DATA.WIN.',
    'VCL.',
    'WINAPI.'
  );

function IsCommonNonTypeWord(const Word: string): Boolean;
var
  I: Integer;
  UpperWord: string;
begin
  Result := False;
  UpperWord := UpperCase(Word);
  for I := Low(CommonNonTypeWords) to High(CommonNonTypeWords) do
    if CommonNonTypeWords[I] = UpperWord then
      Exit(True);
end;

function IsFormInfraUnit(const UpperUnitName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(FormInfraPrefixes) to High(FormInfraPrefixes) do
    if UpperUnitName.StartsWith(FormInfraPrefixes[I]) then
      Exit(True);
end;

function CleanPascalCodeLine(const Line: string; var State: TCodeScanState): string;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(Line) do
  begin
    case State of
      csBraceComment:
        if Line[I] = '}' then
          State := csCode;

      csParenComment:
        if (Line[I] = '*') and (I < Length(Line)) and (Line[I + 1] = ')') then
        begin
          State := csCode;
          Inc(I);
        end;

      csCode:
        begin
          if Line[I] = '''' then
          begin
            repeat
              Inc(I);
              if I > Length(Line) then
                Break;
              if Line[I] = '''' then
              begin
                if (I < Length(Line)) and (Line[I + 1] = '''') then
                  Inc(I)
                else
                  Break;
              end;
            until False;
          end
          else if Line[I] = '{' then
            State := csBraceComment
          else if (Line[I] = '(') and (I < Length(Line)) and (Line[I + 1] = '*') then
          begin
            State := csParenComment;
            Inc(I);
          end
          else if (Line[I] = '/') and (I < Length(Line)) and (Line[I + 1] = '/') then
            Exit
          else
            Result := Result + Line[I];
        end;
    end;
    Inc(I);
  end;
end;

{ TUnsedUsesProcessor }

constructor TUnsedUsesProcessor.Create(AFilePath: string);
begin
  FUnusedUses := TDictionary<string, TUsesUnit>.Create;
  FImplicitUsedUnits := TDictionary<string, string>.Create;
  FFilePath := AFilePath;
  FUsesStartLine := -1;
end;

destructor TUnsedUsesProcessor.Destroy;
begin
  FUses.Free;
  FUsedTypes.Free;
  FIgnoredTypes.Free;
  FIgnoredUses.Free;
  FMatches.Free;
  FUnusedUses.Free;
  FOptionalUsesPrefix.Free;
  FImplicitUsedUnits.Free;
  inherited;
end;

function TUnsedUsesProcessor.GetFullMatchsForUses: TDictionary<string, string>;
var
  SearchType: string;
  Matches: TStringList;
  NewItem: string;
  UnitNameEx: string;
  ClassNameEx: string;
  EnumValue: string;
  DotPos: Integer;
  Skipped: Integer;
  Stopwatch: TStopwatch;
begin
  Result := TDictionary<string, string>.Create;
  Skipped := 0;

  if FEnvControl = nil then
    Exit;

  Stopwatch := TStopwatch.StartNew;

  for SearchType in FUsedTypes.Values do begin
    // Skip common methods/properties that are clearly not type references
    // (e.g. Create, Get, Open). Avoids a dictionary lookup for words that
    // can never be a type/declaration name.
    if IsCommonNonTypeWord(SearchType) then
    begin
      Inc(Skipped);
      Continue;
    end;

    Matches := FEnvControl.GetElementMatches(SearchType);
    for NewItem in Matches do
    begin
      // Filter out unit-only matches - unit name segments are not type references
      if Pos('.* - Unit', NewItem) > 0 then
        Continue;

      // Exact element name check: the element name (last segment before " - Type")
      // must match SearchType to avoid substring false positives
      // e.g. "Configuracao" should not match "aConfiguracao - Variable"
      HDFindUnit.Utils.GetUnitFromSearchSelection(NewItem, UnitNameEx, ClassNameEx);
      if AnsiCompareText(Trim(ClassNameEx), Trim(SearchType)) <> 0 then
      begin
        // Enum items (e.g. "IdSSLOpenSSL.TIdSSLVersion.sslvSSLv2 - Enum item")
        // report the enum TYPE as ClassNameEx; compare against the VALUE instead
        if not NewItem.EndsWith(' item') then
          Continue;

        EnumValue := NewItem;
        EnumValue := Trim(Fetch(EnumValue, '-'));
        DotPos := Pos('.', ReverseString(EnumValue));
        if DotPos > 0 then
          EnumValue := Copy(EnumValue, Length(EnumValue) - DotPos + 2, MaxInt);

        if AnsiCompareText(EnumValue, Trim(SearchType)) <> 0 then
          Continue;
      end;

      Result.AddOrSetValue(NewItem.ToUpper, NewItem);
    end;
    Matches.Free;
  end;

  Logger.Debug('GetFullMatchsForUses: %d types searched, %d skipped (common non-type), %d ms',
    [FUsedTypes.Count - Skipped, Skipped, Stopwatch.ElapsedMilliseconds]);
end;

function TUnsedUsesProcessor.GetIgnoredTypes: TDictionary<string, string>;
var
  ReservedWords: TStringList;
  Rword: string;
begin
  Result := TDictionary<string, string>.Create;
  ReservedWords := TDelphiReservedWords.GetReservedWords;
  for Rword in ReservedWords do
    Result.Add(UpperCase(Rword), Rword);
  ReservedWords.Free;
end;

function TUnsedUsesProcessor.GetIgnoredUses: TDictionary<string, string>;
var
  IgnoredUses: TStringList;
  IgnoreUse: string;
begin
  Result := TDictionary<string, string>.Create;
  IgnoredUses := TStringList.Create;
  IgnoredUses.CommaText := GlobalSettings.IgnoreUsesUnused;
  for IgnoreUse in IgnoredUses do
    Result.Add(UpperCase(IgnoreUse), IgnoreUse);
  IgnoredUses.Free;
end;

function TUnsedUsesProcessor.GetUnusedUses: TDictionary<string, TUsesUnit>;
var
  Matches: string;
  UseFound: TPair<string, TUsesUnit>;
  UnitNameEx: string;
  ClassNameEx: string;
  OptionalUses: string;
  AllPossibleMatches: TDictionary<string, string>;
  UpMatchs: string;
  PrefixVariation: string;
  MatchKey: string;
  FoundNamespace: Boolean;
begin
  Result := TDictionary<string, TUsesUnit>.Create;
  AllPossibleMatches := TDictionary<string, string>.Create;

  for Matches in FMatches.Values do begin
    if not vSystemRunning then
      Exit;

    HDFindUnit.Utils.GetUnitFromSearchSelection(Matches, UnitNameEx, ClassNameEx);

    UpMatchs := UnitNameEx.ToUpper;
    AllPossibleMatches.AddOrSetValue(UpMatchs, UnitNameEx);

    for OptionalUses in FOptionalUsesPrefix do begin
      AllPossibleMatches.AddOrSetValue(OptionalUses + UpMatchs, Matches);

      PrefixVariation := UpMatchs.Replace(OptionalUses, '');
      AllPossibleMatches.AddOrSetValue(PrefixVariation, UnitNameEx);
    end;
  end;

  for UseFound in FUses do
    if not FIgnoredUses.ContainsKey(UseFound.Key) then
      if not AllPossibleMatches.ContainsKey(UseFound.Key) then
      begin
        if FImplicitUsedUnits.ContainsKey(UseFound.Key) then
        begin
          Logger.Debug('GetUnusedUses: skipping implicit used %s', [UseFound.Key]);
          Continue;
        end;

        FoundNamespace := False;
        for MatchKey in AllPossibleMatches.Keys do
          if MatchKey.StartsWith(UseFound.Key + '.') then
          begin
            FoundNamespace := True;
            Break;
          end;

        if not FoundNamespace then
        begin
          if not FEnvControl.PasExists(UseFound.Key + '.pas') then
            Logger.Debug('GetUnusedUses: not indexed %s (usage cannot be verified)', [UseFound.Key]);

          Result.Add(UseFound.Key, UseFound.Value);
        end;
      end;

  AllPossibleMatches.Free;
end;

function TUnsedUsesProcessor.GetUnusedUsesAsString: string;
var
  Value: TUsesUnit;
begin
  Result := '';

  if FUnusedUses = nil then
    Exit;

  for Value in FUnusedUses.Values do
    if Value.UnusedType = uetUnused then
      Result := Result + Value.Name + ',';
end;

function TUnsedUsesProcessor.HasUnusedUses: Boolean;
var
  Value: TUsesUnit;
begin
  Result := False;

  if FUnusedUses = nil then
    Exit;

  for Value in FUnusedUses.Values do
    if Value.UnusedType = uetUnused then
      Exit(True);
end;

function TUnsedUsesProcessor.GetUsedTypes: TDictionary<string, string>;
var
  XmlFile: TStringList;
  Line: string;
  FetchType: string;
  I: Integer;
begin
  Result := TDictionary<string, string>.Create;

  if FUnitNode = nil then
    Exit;

  XmlFile := TStringList.Create;
  XmlFile.Text := TSyntaxTreeWriter.ToXML(FUnitNode, True);

  for I := 0 to XmlFile.Count - 1 do begin
    Line := XmlFile[I];

    if (Pos('<TYPE', Line) = 0) and (Pos('<NAME', Line) = 0) and (Pos('<IDENTIFIER', Line) = 0) then
      Continue;

    if Pos('name="', Line) > 0 then
    begin
      FetchType := Fetch(Line, 'name="');
      FetchType := Fetch(Line, '"');
    end
    else if Pos('value="', Line) > 0 then
    begin
      FetchType := Fetch(Line, 'value="');
      FetchType := Fetch(Line, '"');
    end
    else
      Continue;

    if FetchType.Length <= 2 then
      Continue;

    if FIgnoredTypes.ContainsKey(FetchType.ToUpper) then
      Continue;

    if not FetchType.IsEmpty then
      Result.AddOrSetValue(FetchType.ToUpper, FetchType);
  end;

  Logger.Debug('GetUsedTypes: %d types found from AST', [Result.Count]);

  FallbackAddTypesFromSource(Result);

  Logger.Debug('GetUsedTypes: %d types total after source fallback', [Result.Count]);
  XmlFile.Free;
end;

procedure TUnsedUsesProcessor.FallbackAddTypesFromSource(Result: TDictionary<string, string>);
var
  SourceLines: TStringList;
  LineText: string;
  TrimmedLine: string;
  FirstWord: string;
  SpacePos: Integer;
  I, J, K: Integer;
  Word: string;
  WordUpper: string;
  InUsesSection: Boolean;
  HasUpper: Boolean;
  ScanState: TCodeScanState;
begin
  if not FileExists(FFilePath) then
    Exit;

  InUsesSection := False;
  ScanState := csCode;
  SourceLines := TStringList.Create;
  try
    SourceLines.LoadFromFile(FFilePath);
    for I := 0 to SourceLines.Count - 1 do
    begin
      LineText := CleanPascalCodeLine(SourceLines[I], ScanState);
      TrimmedLine := Trim(LineText);

      if TrimmedLine.IsEmpty then
        Continue;

      if not InUsesSection then
      begin
        SpacePos := Pos(' ', TrimmedLine + ' ');
        FirstWord := Copy(TrimmedLine, 1, SpacePos - 1);

        if SameText(FirstWord, 'uses') then
        begin
          InUsesSection := Pos(';', TrimmedLine) = 0;
          Continue;
        end;

        if SameText(FirstWord, 'unit') then
          Continue;
      end
      else
      begin
        if Pos(';', TrimmedLine) > 0 then
          InUsesSection := False;
        Continue;
      end;

      J := 1;
      while J <= Length(LineText) do
      begin
        Word := '';
        while (J <= Length(LineText)) and CharInSet(LineText[J], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
        begin
          Word := Word + LineText[J];
          Inc(J);
        end;

        if (Length(Word) > 2) then
        begin
          HasUpper := False;
          for K := 2 to Length(Word) do
            if CharInSet(Word[K], ['A'..'Z']) then
            begin
              HasUpper := True;
              Break;
            end;

          if CharInSet(Word[1], ['A'..'Z']) // any Pascal identifier (functions, types, constants, etc.)
            or ((Word[1] = 'a') and (Length(Word) > 3) and CharInSet(Word[2], ['A'..'Z'])) // global vars like aConfiguracao
            or (CharInSet(Word[1], ['a'..'z']) and (Length(Word) > 3) and HasUpper) // camelCase: enum values (sslvSSLv2), interfaces (iControllerHorse)
          then
          begin
            WordUpper := UpperCase(Word);
            if not FIgnoredTypes.ContainsKey(WordUpper) then
              if not IsCommonNonTypeWord(WordUpper) then
              begin
                if not Result.ContainsKey(WordUpper) then
                begin
                  Result.Add(WordUpper, Word);
                  Logger.Debug('GetUsedTypes fallback: added %s', [Word]);
                end;
              end;
          end;
        end;

        if (J <= Length(LineText)) and not CharInSet(LineText[J], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
          Inc(J);
      end;
    end;
  finally
    SourceLines.Free;
  end;
end;

function TUnsedUsesProcessor.GetUnitSpecifiedOnUses: TDictionary<string, TUsesUnit>;
var
  XmlFile: TStringList;
  Line: string;
  I: Integer;
  UsesUnit: TUsesUnit;
  Column: string;
  UsesLine: string;
  UsesName: string;
  IsHeader: Boolean;
begin
  IsHeader := True;
  Result := TDictionary<string, TUsesUnit>.Create;

  if FUnitNode = nil then
    Exit;

  XmlFile := TStringList.Create;
  XmlFile.Text := TSyntaxTreeWriter.ToXML(FUnitNode, True);

  for I := 0 to XmlFile.Count - 1 do begin
    Line := XmlFile[I];

    if Line.Contains('<USES') then begin
      Fetch(Line, 'begin_line="');
      UsesLine := Fetch(Line, '"');
      if FUsesStartLine = -1 then
        FUsesStartLine := StrToInt(UsesLine);
      Continue;
    end;

    if Pos('<UNIT', Line) = 0 then
      Continue;

    if IsHeader then begin
      IsHeader := False;
      Continue;
    end;

    UsesLine := Line;
    Column := Line;
    UsesName := Line;

    Fetch(UsesLine, 'line="');
    UsesLine := Fetch(UsesLine, '"');

    Fetch(Column, 'col="');
    Column := Fetch(Column, '"');

    Fetch(UsesName, 'name="');
    UsesName := Fetch(UsesName, '"');

    UsesUnit.Line := StrToInt(UsesLine);
    UsesUnit.Collumn := StrToInt(Column);
    UsesUnit.Name := UsesName;

    if FEnvControl.PasExists(UsesUnit.Name.ToUpper + '.pas') then
      UsesUnit.UnusedType := uetUnused
    else
      UsesUnit.UnusedType := GetNotIndexedUnusedType(UsesUnit.Name);

    Result.AddOrSetValue(UsesUnit.Name.ToUpper, UsesUnit);
  end;
  XmlFile.Free;
end;

function TUnsedUsesProcessor.GetNotIndexedUnusedType(UnitName: string): TUnusedErrorType;
var
  UpperName: string;
  BDSDir: string;
  DcuDir: string;
  SourceFile: string;
begin
  UpperName := UnitName.ToUpper;

  GNotIndexedCacheLock.Acquire;
  try
    if GNotIndexedCache.TryGetValue(UpperName, Result) then
      Exit;
  finally
    GNotIndexedCacheLock.Release;
  end;

  Result := uetDcp;
  BDSDir := GetEnvironmentVariable('BDS');
  if BDSDir = '' then
  begin
    GNotIndexedCacheLock.Acquire;
    try
      GNotIndexedCache.AddOrSetValue(UpperName, Result);
    finally
      GNotIndexedCacheLock.Release;
    end;
    Exit;
  end;

  for DcuDir in [BDSDir + '\lib\win32\release', BDSDir + '\lib\win32\debug'] do
    if FileExists(DcuDir + '\' + UpperName + '.dcu') then
    begin
      Result := uetNoPasFile;
      Break;
    end;

  if (Result = uetDcp) and TDirectory.Exists(BDSDir + '\source') then
  begin
    GNotIndexedCacheLock.Acquire;
    try
      if not GIdesourceScanDone then
      begin
        for SourceFile in TDirectory.GetFiles(BDSDir + '\source', '*.pas', TSearchOption.soAllDirectories) do
          GIdesourcePasNames.AddOrSetValue(ExtractFileName(SourceFile).ToUpper, True);
        GIdesourceScanDone := True;
        Logger.Debug('GetNotIndexedUnusedType: IDE source scanned, %d files', [GIdesourcePasNames.Count]);
      end;
      if GIdesourcePasNames.ContainsKey(UpperName + '.PAS') then
        Result := uetNoPasFile;
    finally
      GNotIndexedCacheLock.Release;
    end;
  end;

  GNotIndexedCacheLock.Acquire;
  try
    GNotIndexedCache.AddOrSetValue(UpperName, Result);
  finally
    GNotIndexedCacheLock.Release;
  end;
end;

function TUnsedUsesProcessor.GetOptionalUsesPrefix: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('WINDOWS.');
  Result.Add('MESSAGES.');
  Result.Add('SYSUTILS.');
  Result.Add('VARIANTS.');
  Result.Add('CLASSES.');
  Result.Add('GRAPHICS.');
  Result.Add('CONTROLS.');
  Result.Add('FORMS.');
  Result.Add('DIALOGS.');
  Result.Add('TYPES.');
  Result.Add('WINAPI.');
  Result.Add('WINAPI.WINDOWS.');
  Result.Add('WINAPI.MESSAGES.');
  Result.Add('SYSTEM.');
  Result.Add('SYSTEM.SYSUTILS.');
  Result.Add('SYSTEM.VARIANTS.');
  Result.Add('SYSTEM.CLASSES.');
  Result.Add('SYSTEM.TYPES.');
  Result.Add('VCL.');
  Result.Add('VCL.GRAPHICS.');
  Result.Add('VCL.CONTROLS.');
  Result.Add('VCL.FORMS.');
  Result.Add('VCL.DIALOGS.');
  Result.Add('FMX.');
  Result.Add('FMX.TYPES.');
  Result.Add('FMX.CONTROLS.');
  Result.Add('FMX.FORMS.');
  Result.Add('FMX.DIALOGS.');
  Result.Add('QTYPES.');
  Result.Add('QGRAPHICS.');
  Result.Add('QCONTROLS.');
  Result.Add('QFORMS.');
  Result.Add('QDIALOGS.');
  Result.Add('QSTDCTRLS.');
  Result.Add('DATASNAP.');
  Result.Add('DATA.WIN.');
end;

procedure TUnsedUsesProcessor.Process;
var
  Step: string;
  WaitCount: Integer;
  Stopwatch: TStopwatch;
  StepWatch: TStopwatch;
begin
  if not FEnvControl.AreDependenciasReady then begin
    FEnvControl.ForceRunDependencies;
    WaitCount := 0;
    while not FEnvControl.AreDependenciasReady do
    begin
      Sleep(200);
      Inc(WaitCount);
      if WaitCount >= 50 then
        Exit;
    end;
  end;

  FUnitNode := nil;
  if not FileExists(FFilePath) then begin
    Logger.Debug('TFindUnitParser.Process: File do not exists %s', [FFilePath]);
    Exit;
  end;

  Stopwatch := TStopwatch.StartNew;
  try
    try
      Step := 'build syntax tree';
      StepWatch := TStopwatch.StartNew;
      FUnitNode := TPasSyntaxTreeBuilder.Run(FFilePath, False, nil);
      Logger.Debug('Process: syntax tree built in %d ms', [StepWatch.ElapsedMilliseconds]);
    except
      on E: ESyntaxTreeException do begin
        FUnitNode := E.SyntaxTree;
        E.SyntaxTree := nil;
      end;
    end;

    if FUnitNode = nil then begin
      Exit;
    end;

    Step := 'get ignored types/uses';
    FIgnoredTypes := GetIgnoredTypes;
    FIgnoredUses := GetIgnoredUses;
    FUses := GetUnitSpecifiedOnUses;

    Step := 'get used types';
    StepWatch := TStopwatch.StartNew;
    FUsedTypes := GetUsedTypes;
    Logger.Debug('Process: GetUsedTypes in %d ms', [StepWatch.ElapsedMilliseconds]);

    Step := 'get full matches';
    StepWatch := TStopwatch.StartNew;
    FMatches := GetFullMatchsForUses;
    Logger.Debug('Process: GetFullMatchsForUses in %d ms', [StepWatch.ElapsedMilliseconds]);

    Step := 'add implicit deps';
    StepWatch := TStopwatch.StartNew;
    FallbackAddImplicitDeps;
    Logger.Debug('Process: FallbackAddImplicitDeps in %d ms', [StepWatch.ElapsedMilliseconds]);

    FOptionalUsesPrefix := GetOptionalUsesPrefix;

    FUnusedUses.Free;
    Step := 'get unused uses';
    StepWatch := TStopwatch.StartNew;
    FUnusedUses := GetUnusedUses;
    Logger.Debug('Process: GetUnusedUses in %d ms', [StepWatch.ElapsedMilliseconds]);

    Logger.Debug('Process: total %d ms', [Stopwatch.ElapsedMilliseconds]);
    Logger.Debug('GetUnusedUses:' + GetUnusedUsesAsString);
  except
    on E: Exception do begin
      Logger.Error('TFindUnitParser.Process: Trying to parse %s. Msg: %s | Step: %s', [FFilePath, E.Message, Step]);
{$IFDEF RAISEMAD}
      raise;
{$ENDIF}
    end;
  end;
end;

procedure TUnsedUsesProcessor.FallbackAddImplicitDeps;
var
  SourceLines: TStringList;
  CleanLines: TStringList;
  FullText: string;
  UpperText: string;
  I: Integer;
  ScanState: TCodeScanState;
  Match: string;
  UnitNameEx: string;
  ClassNameEx: string;
  UpUnit: string;
  DriverUnit: string;
  IsFormUnit: Boolean;
  IsFMX: Boolean;
  UsePair: TPair<string, TUsesUnit>;
begin
  if not FileExists(FFilePath) then
    Exit;

  FImplicitUsedUnits.Clear;

  SourceLines := TStringList.Create;
  CleanLines := TStringList.Create;
  try
    SourceLines.LoadFromFile(FFilePath);
    ScanState := csCode;
    for I := 0 to SourceLines.Count - 1 do
      CleanLines.Add(CleanPascalCodeLine(SourceLines[I], ScanState));
    FullText := CleanLines.Text;
  finally
    CleanLines.Free;
    SourceLines.Free;
  end;

  UpperText := UpperCase(FullText);

  if (Pos('.TOJSONARRAY', UpperText) > 0) or (Pos('.TOJSONOBJECT', UpperText) > 0) then
  begin
    Logger.Debug('FallbackImplicit: added DataSet.Serialize via .ToJSONObject/Array');
    FImplicitUsedUnits.Add('DATASET.SERIALIZE', 'DataSet.Serialize');
  end;

  if Pos('PARAMBYNAME', UpperText) > 0 then
  begin
    if (Pos('.ASSTRING', UpperText) > 0) or
       (Pos('.ASBOOLEAN', UpperText) > 0) or
       (Pos('.ASLARGEINT', UpperText) > 0) then
    begin
      Logger.Debug('FallbackImplicit: added FireDAC.Stan.Param via ParamByName+AsXxx');
      FImplicitUsedUnits.Add('FIREDAC.STAN.PARAM', 'FireDAC.Stan.Param');
    end;
  end;

  // FireDAC driver pattern: when a FireDAC.Phys.<X>Def unit is referenced
  // (e.g. TFDPhysPGConnectionDefParams in FireDAC.Phys.PGDef), the driver
  // unit FireDAC.Phys.<X> (e.g. FireDAC.Phys.PG) is also required at runtime
  // to register the driver with FDManager - the only difference between the
  // two unit names is the "Def" suffix. Protect the driver unit so it is
  // not reported as unused.
  if FMatches <> nil then
  begin
    for Match in FMatches.Values do
    begin
      HDFindUnit.Utils.GetUnitFromSearchSelection(Match, UnitNameEx, ClassNameEx);
      UpUnit := UpperCase(UnitNameEx);
      if UpUnit.StartsWith('FIREDAC.PHYS.') and UpUnit.EndsWith('DEF') then
      begin
        DriverUnit := Copy(UnitNameEx, 1, Length(UnitNameEx) - Length('Def'));
        if not FImplicitUsedUnits.ContainsKey(UpperCase(DriverUnit)) then
        begin
          Logger.Debug('FallbackImplicit: added %s via %s driver def', [DriverUnit, UnitNameEx]);
          FImplicitUsedUnits.Add(UpperCase(DriverUnit), DriverUnit);
        end;
      end;
    end;
  end;

  // Form infrastructure pattern: dfm/fmx resources stream controls whose
  // property types and presentation classes live in units the .pas never
  // references by type. System.Actions provides the base action classes
  // (TBasicAction/TCustomAction) needed to load the "Action = ..." properties
  // in the form file; FMX.Controls.Presentation is the styled control layer.
  // Beyond those, the whole IDE-managed infrastructure (FireDAC runtime,
  // LiveBindings engine, Data.DB streaming classes, FMX presentation units,
  // System.Rtti/Skia/UITypes) is injected and re-added by the form designer.
  // Protect them for form units.
  IsFormUnit := FileExists(ChangeFileExt(FFilePath, '.dfm'));
  IsFMX := FileExists(ChangeFileExt(FFilePath, '.fmx'));
  if IsFormUnit or IsFMX then
  begin
    if not FImplicitUsedUnits.ContainsKey('SYSTEM.ACTIONS') then
    begin
      Logger.Debug('FallbackImplicit: added System.Actions via form resource');
      FImplicitUsedUnits.Add('SYSTEM.ACTIONS', 'System.Actions');
    end;

    if IsFMX and not FImplicitUsedUnits.ContainsKey('FMX.CONTROLS.PRESENTATION') then
    begin
      Logger.Debug('FallbackImplicit: added FMX.Controls.Presentation via fmx presentation layer');
      FImplicitUsedUnits.Add('FMX.CONTROLS.PRESENTATION', 'FMX.Controls.Presentation');
    end;

    for UsePair in FUses do
      if (not FImplicitUsedUnits.ContainsKey(UsePair.Key)) and IsFormInfraUnit(UsePair.Key) then
      begin
        Logger.Debug('FallbackImplicit: added %s via form infra namespace', [UsePair.Value.Name]);
        FImplicitUsedUnits.Add(UsePair.Key, UsePair.Value.Name);
      end;
  end;
end;

procedure TUnsedUsesProcessor.SetEnvControl(EnvControl: IRFUEnvironmentController);
begin
  FEnvControl := EnvControl;
end;

procedure TUnsedUsesProcessor.SetIncluder(Includer: IIncludeHandler);
begin
  FIncluder := Includer;
end;

initialization
  GNotIndexedCacheLock := TCriticalSection.Create;
  GNotIndexedCache := TDictionary<string, TUnusedErrorType>.Create;
  GIdesourcePasNames := TDictionary<string, Boolean>.Create;
  GIdesourceScanDone := False;

finalization
  GNotIndexedCache.Free;
  GIdesourcePasNames.Free;
  GNotIndexedCacheLock.Free;

end.
