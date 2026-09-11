unit HDFindUnit.Model.FileCache;

interface

uses
  HDFindUnit.Model.PasParser,
  HDFindUnit.Model.SearchStringCache,

  HDFindUnit.Model.Interf.SearchStringCache,

  Classes,
  Generics.Collections,
  SyncObjs;

type
  TUnits = class(TObject)
  strict private
    FUnitsPath: TDictionary<string, TPasFile>;
    FUniqueUnitNames: TDictionary<string, string>;
  private
    function GetItem(const Key: string): TPasFile;
    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    function ExtractPair(const Key: string): TPair<string, TPasFile>;
    function TryGetValue(const Key: string; out Value: TPasFile): Boolean;
    function Values: TDictionary<string,TPasFile>.TValueCollection;

    procedure Add(const Key: string; const Value: TPasFile);
    function FileExists(Key: string): Boolean;
    function ContainsPath(const Path: string): Boolean;

    property Items[const Key: string]: TPasFile read GetItem; default;
    property Count: Integer read GetCount;
  end;

  TUnitsController = class(TObject)
  private
    FFullMatchSearchCache: ISearchStringCache;
    FMatchSearchCache: ISearchStringCache;

    FUnits: TUnits;

    FElementIndex: TDictionary<string, TStringList>;
    FReady: Boolean;
    FRc: TCriticalSection;

    procedure SetUnits(const Value: TUnits);
    procedure BuildElementIndex;
  public
    constructor Create;
    destructor Destroy; override;

    function GetFindInfo(const SearchString: string): TStringList;
    function GetFindInfoFullMatch(const SearchString: string): TStringList;
    function GetElementMatches(const ElementName: string): TStringList;

    function GetPasFile(FilePath: string): TPasFile;
    function ExtractPasFile(FilePath: string): TPasFile;
    function ContainsFilePath(FilePath: string): Boolean;

    property Units: TUnits read FUnits write SetUnits;
    property Ready: Boolean read FReady write FReady;
  end;

implementation

uses
  HDFindUnit.Model.SearchString,
  HDFindUnit.Model.Header,
  Log4Pascal,
  SysUtils,
  StrUtils
  {$IFDEF FPC}, Windows{$ELSE}, System.Diagnostics{$ENDIF};

{$IFDEF FPC}
type
  TStopwatch = record
  strict private
    FElapsed: Int64;
  public
    class function StartNew: TStopwatch; static;
    class function GetTickCount64Safe: Int64; static;
    function ElapsedMilliseconds: Int64;
  end;

class function TStopwatch.GetTickCount64Safe: Int64;
begin
  Result := GetTickCount64;
end;

class function TStopwatch.StartNew: TStopwatch;
begin
  Result.FElapsed := GetTickCount64Safe;
end;

function TStopwatch.ElapsedMilliseconds: Int64;
begin
  Result := GetTickCount64Safe - FElapsed;
end;
{$ENDIF}

{ TUnitUpdateController }
constructor TUnitsController.Create;
begin
  FFullMatchSearchCache := TSearchStringCache.Create;
  FElementIndex := TDictionary<string, TStringList>.Create;
  FRc := SyncObjs.TCriticalSection.Create;
  inherited;
end;

destructor TUnitsController.Destroy;
var
  Bucket: TStringList;
begin
  for Bucket in FElementIndex.Values do
    Bucket.Free;
  FElementIndex.Free;
  FRc.Free;
  FUnits.Free;
  inherited;
end;

function TUnitsController.ExtractPasFile(FilePath: string): TPasFile;
var
  Item: TPair<string, TPasFile>;
begin
  FRc.Acquire;
  try
    Item := FUnits.ExtractPair(FilePath);
    Result := Item.Value;
  finally
    FRc.Release;
  end;
end;

function TUnitsController.GetFindInfo(const SearchString: string): TStringList;
var
  Search: TSearchString;
begin
  Search := TSearchString.Create(FUnits);
  try
    Search.MatchCache := FMatchSearchCache;
    Result := Search.GetMatch(SearchString);
  finally
    Search.Free;
  end;
end;

function TUnitsController.GetFindInfoFullMatch(const SearchString: string): TStringList;
var
  Search: TSearchString;
begin
  Search := TSearchString.Create(FUnits);
  try
    Search.FullMatchCache := FFullMatchSearchCache;
    Result := Search.GetFullMatch(SearchString);
  finally
    Search.Free;
  end;
end;

function TUnitsController.GetElementMatches(const ElementName: string): TStringList;
var
  Bucket: TStringList;
begin
  Result := TStringList.Create;
  FRc.Acquire;
  try
    if FElementIndex.TryGetValue(UpperCase(ElementName), Bucket) then
      Result.AddStrings(Bucket);
  finally
    FRc.Release;
  end;
end;

procedure TUnitsController.BuildElementIndex;
var
  Stopwatch: TStopwatch;
  Item: TPasFile;
  ListType: TListType;
  List: TStringList;
  Entry: string;
  Key: string;
  Bucket: TStringList;
  MatchText: string;
  PathPart: string;
  ElementName: string;
  DashPos: Integer;
  DotPos: Integer;
  IndexedItems: Integer;
begin
  IndexedItems := 0;
  Stopwatch := TStopwatch.StartNew;

  FRc.Acquire;
  try
    for Bucket in FElementIndex.Values do
      Bucket.Free;
    FElementIndex.Clear;

    if FUnits = nil then
      Exit;

    for Item in FUnits.Values do
      for ListType := Low(TListType) to High(TListType) do
      begin
        List := Item.GetListFromType(ListType);
        if List = nil then
          Continue;

        for Entry in List do
        begin
          MatchText := Item.OriginUnitName + '.' + Entry + strListTypeDescription[ListType];

          PathPart := MatchText;
          DashPos := Pos(' -', PathPart);
          if DashPos > 0 then
            PathPart := Copy(PathPart, 1, DashPos - 1);
          PathPart := StringReplace(PathPart, '.*', '', [rfReplaceAll]);

          // Index only the ELEMENT NAME (last path segment). The consumer
          // (GetFullMatchsForUses) only accepts matches whose element name
          // exactly equals the search type, so mid-path segments are always
          // filtered out - indexing them only wastes memory (~4x).
          DotPos := Pos('.', ReverseString(PathPart));
          if DotPos > 0 then
            ElementName := ReverseString(Copy(ReverseString(PathPart), 1, DotPos - 1))
          else
            ElementName := PathPart;

          if ElementName = '' then
            Continue;

          Key := UpperCase(ElementName);
          if not FElementIndex.TryGetValue(Key, Bucket) then
          begin
            Bucket := TStringList.Create;
            FElementIndex.Add(Key, Bucket);
          end;
          Bucket.Add(MatchText);
          Inc(IndexedItems);
        end;
      end;
  finally
    FRc.Release;
  end;

  Logger.Debug('BuildElementIndex: %d element names indexed in %d keys in %d ms',
    [IndexedItems, FElementIndex.Count, Stopwatch.ElapsedMilliseconds]);
end;

function TUnitsController.GetPasFile(FilePath: string): TPasFile;
begin
  FRc.Acquire;
  try
    FUnits.TryGetValue(FilePath, Result);
  finally
    FRc.Release;
  end;
end;

function TUnitsController.ContainsFilePath(FilePath: string): Boolean;
begin
  FRc.Acquire;
  try
    Result := (FUnits <> nil) and FUnits.ContainsPath(FilePath);
  finally
    FRc.Release;
  end;
end;

procedure TUnitsController.SetUnits(const Value: TUnits);
begin
  FUnits := Value;
  FMatchSearchCache := TSearchStringCache.Create;
  FFullMatchSearchCache := TSearchStringCache.Create;
  BuildElementIndex;
end;

{ TUnits }

procedure TUnits.Add(const Key: string; const Value: TPasFile);
var
  CurUnitName: string;
begin
  FUnitsPath.AddOrSetValue(Key, Value);
  CurUnitName := UpperCase(ExtractFileName(Key));
  FUniqueUnitNames.AddOrSetValue(CurUnitName, Key);
end;

constructor TUnits.Create;
begin
  FUnitsPath := TDictionary<string, TPasFile>.Create;
  FUniqueUnitNames := TDictionary<string, string>.Create;
end;

destructor TUnits.Destroy;
begin

  inherited;
end;

function TUnits.ExtractPair(const Key: string): TPair<string, TPasFile>;
var
  CurUnitName: string;
begin
  Result := FUnitsPath.ExtractPair(Key);
  CurUnitName := UpperCase(ExtractFileName(Key));
  FUniqueUnitNames.Remove(CurUnitName);
end;

function TUnits.FileExists(Key: string): Boolean;
var
  CurUnitName: string;
  ShortName: string;
  DotPos: Integer;
  OutputValue: string;
begin
  CurUnitName := UpperCase(ExtractFileName(Key));
  Result := FUniqueUnitNames.TryGetValue(CurUnitName, OutputValue);
  if not Result then
  begin
    DotPos := Pos('.', CurUnitName);
    if DotPos > 0 then
    begin
      ShortName := Copy(CurUnitName, DotPos + 1, MaxInt);
      Result := FUniqueUnitNames.TryGetValue(ShortName, OutputValue);
    end;
  end;
end;

function TUnits.GetCount: Integer;
begin
  Result := FUnitsPath.Count;
end;

function TUnits.ContainsPath(const Path: string): Boolean;
var
  UpPath: string;
  Pair: TPair<string, TPasFile>;
begin
  UpPath := UpperCase(Path);
  for Pair in FUnitsPath do
    if UpperCase(Pair.Key) = UpPath then
      Exit(True);
  Result := False;
end;

function TUnits.GetItem(const Key: string): TPasFile;
begin
  Result := FUnitsPath.Items[Key];
end;

function TUnits.TryGetValue(const Key: string; out Value: TPasFile): Boolean;
begin
  Result := FUnitsPath.TryGetValue(Key, Value);
end;

function TUnits.Values: TDictionary<string,TPasFile>.TValueCollection;
begin
  Result := FUnitsPath.Values;
end;

end.
