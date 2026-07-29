unit HDFindUnit.Utils;

interface

uses
  SimpleParser.Lexer.Types,
  System.Generics.Collections,
  System.StrUtils;

type
  TFileInfo = record
    Path: string;
    LastAccess: TDateTime;
  end;

  TIncludeHandler = class(TInterfacedObject, IIncludeHandler)
  private
    FPath: string;
  public
    constructor Create(const Path: string);
    function GetIncludeFileContent(const FileName: string): string;
  end;

  TPathConverter = class(TObject)
  private
    const
      VAR_INIT = '$(';
      VAR_END = ')';
  public
    class function ConvertPathsToFullPath(Paths: string): string;
  end;

function GetAllFilesFromPath(const Path, Filter: string): TDictionary<string, TFileInfo>;
function GetAllFilesFromPathRecursive(const Path, Filter: string): TDictionary<string, TFileInfo>;
function GetAllPasFilesFromPath(const Path: string): TDictionary<string, TFileInfo>;
function GetAllPasFilesFromPathRecursive(const Path: string): TDictionary<string, TFileInfo>;
function GetAllDcuFilesFromPath(const Path: string): TDictionary<string, TFileInfo>;

function Fetch(
    var AInput: string;
    const ADelim: string = '';
    const ADelete: Boolean = True;
    const ACaseSensitive: Boolean = False
): string; inline;

function IsProcessRunning(const AExeFileName: string): Boolean;
function GetHashCodeFromStr(Str: PChar): Integer;
function TextExists(SubStr, Str: string; CaseSensitive: Boolean = true): Boolean; inline;

procedure GetUnitFromSearchSelection(SearchSelection: string; out UnitName, ClassName: string);

function DictionaryToString(Dir: TDictionary<string, string>): string;

function RemoveDelphiComments(const Line: string): string;

function FindSemicolonExcludingComments(const Line: string): Integer;

function UncommentLine(const Line: string): string;

var
  FindUnitDir: string;
  FindUnitDirLogger: string;
  FindUnitDcuDir: string;
  DirRealeaseWin32: string;

implementation

uses
  Log4Pascal,
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  System.Types,
  Winapi.TlHelp32,
  Winapi.Windows;

function DictionaryToString(Dir: TDictionary<string, string>): string;
var
  Value: string;
begin
  Result := '';

  if Dir = nil then
    Exit;

  for Value in Dir.Values do
    Result := Result + Value + ',';
end;

procedure GetUnitFromSearchSelection(SearchSelection: string; out UnitName, ClassName: string);
var
  IsSetEnumItem: Boolean;
  CleanSelection: string;
  DotPos: Integer;
begin
  IsSetEnumItem := SearchSelection.EndsWith(' item');
  ClassName := '';

  CleanSelection := SearchSelection;
  if Pos('.*', CleanSelection) > 0 then
    CleanSelection := Trim(Fetch(CleanSelection, '.*'))
  else
    CleanSelection := Trim(Fetch(CleanSelection, '-'));

  DotPos := Pos('.', ReverseString(CleanSelection));

  if DotPos > 0 then
  begin
    ClassName := ReverseString(Copy(ReverseString(CleanSelection), 1, DotPos - 1));
    UnitName := ReverseString(Copy(ReverseString(CleanSelection), DotPos + 1, MaxInt));
  end
  else
    UnitName := CleanSelection;

  if IsSetEnumItem then
  begin
    DotPos := Pos('.', ReverseString(UnitName));
    if DotPos > 0 then
    begin
      ClassName := ReverseString(Copy(ReverseString(UnitName), 1, DotPos - 1));
      UnitName := ReverseString(Copy(ReverseString(UnitName), DotPos + 1, MaxInt));
    end;
  end;
end;

function TextExists(SubStr, Str: string; CaseSensitive: Boolean): Boolean;
begin
  if CaseSensitive then
    Result := Pos(SubStr, Str) > 0
  else
    Result := Pos(UpperCase(SubStr), UpperCase(Str)) > 0
end;

function GetHashCodeFromStr(Str: PChar): Integer;
var
  Off, Len, Skip, I: Integer;
begin
  Result := 0;
  Off := 1;
  Len := StrLen(Str);
  if Len < 16 then
    for I := (Len - 1) downto 0 do begin
      Result := (Result * 37) + Ord(Str[Off]);
      Inc(Off);
    end
  else begin
    { Only sample some characters }
    Skip := Len div 8;
    I := Len - 1;
    while I >= 0 do begin
      Result := (Result * 39) + Ord(Str[Off]);
      Dec(I, Skip);
      Inc(Off, Skip);
    end;
  end;
end;

function IsProcessRunning(const AExeFileName: string): Boolean;
var
  Continuar: BOOL;
  SnapshotHandle: THandle;
  Entry: TProcessEntry32;
begin
  Result := False;
  try
    SnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    Entry.dwSize := SizeOf(Entry);
    Continuar := Process32First(SnapshotHandle, Entry);
    while Integer(Continuar) <> 0 do begin
      if ((UpperCase(ExtractFileName(Entry.szExeFile)) = UpperCase(AExeFileName))
          or (UpperCase(Entry.szExeFile) = UpperCase(AExeFileName))) then
      begin
        Result := True;
      end;
      Continuar := Process32Next(SnapshotHandle, Entry);
    end;
    CloseHandle(SnapshotHandle);
  except
    Result := False;
  end;
end;

function FetchCaseInsensitive(var AInput: string; const ADelim: string; const ADelete: Boolean): string; inline;
var
  LPos: Integer;
begin
  if ADelim = #0 then begin
    LPos := Pos(ADelim, AInput);
  end
  else begin
    LPos := Pos(UpperCase(ADelim), UpperCase(AInput));
  end;
  if LPos = 0 then begin
    Result := AInput;
    if ADelete then begin
      AInput := '';
    end;
  end
  else begin
    Result := Copy(AInput, 1, LPos - 1);
    if ADelete then
      AInput := Copy(AInput, LPos + Length(ADelim), MaxInt);
  end;
end;

function Fetch(
    var AInput: string;
    const ADelim: string = '';
    const ADelete: Boolean = True;
    const ACaseSensitive: Boolean = False
): string; inline;
var
  LPos: Integer;
begin
  if ACaseSensitive then begin
    LPos := Pos(ADelim, AInput);
    if LPos = 0 then begin
      Result := AInput;
      if ADelete then
        AInput := '';
    end
    else begin
      Result := Copy(AInput, 1, LPos - 1);
      if ADelete then begin
        // slower Delete(AInput, 1, LPos + Length(ADelim) - 1); because the
        // remaining part is larger than the deleted
        AInput := Copy(AInput, LPos + Length(ADelim), MaxInt);
      end;
    end;
  end
  else begin
    Result := FetchCaseInsensitive(AInput, ADelim, ADelete);
  end;
end;

function GetAllFilesFromPath(const Path, Filter: string): TDictionary<string, TFileInfo>;
var
  Files: TStringDynArray;
  FilePath: string;
  FileInfo: TFileInfo;
begin
  Files := System.IOUtils.TDirectory.GetFiles(Path, Filter, TSearchOption.soTopDirectoryOnly);

  Result := TDictionary<string, TFileInfo>.Create;
  for FilePath in Files do begin
    FileInfo.Path := Trim(FilePath);
    if FileExists(FilePath) then
      FileInfo.LastAccess := System.IOUtils.TFile.GetLastWriteTime(FilePath)
    else
      FileInfo.LastAccess := 0;

    Result.Add(FileInfo.Path, FileInfo);
  end;
end;

function GetAllFilesFromPathRecursive(const Path, Filter: string): TDictionary<string, TFileInfo>;
var
  Files: TStringDynArray;
  FilePath: string;
  FileInfo: TFileInfo;
begin
  Files := System.IOUtils.TDirectory.GetFiles(Path, Filter, TSearchOption.soAllDirectories);

  Result := TDictionary<string, TFileInfo>.Create;
  for FilePath in Files do begin
    FileInfo.Path := Trim(FilePath);
    if FileExists(FilePath) then
      FileInfo.LastAccess := System.IOUtils.TFile.GetLastWriteTime(FilePath)
    else
      FileInfo.LastAccess := 0;

    Result.Add(FileInfo.Path, FileInfo);
  end;
end;

function GetAllDcuFilesFromPath(const Path: string): TDictionary<string, TFileInfo>;
begin
  Result := GetAllFilesFromPath(Path, '*.dcu');
end;

function GetAllPasFilesFromPath(const Path: string): TDictionary<string, TFileInfo>;
begin
  Result := GetAllFilesFromPath(Path, '*.pas');
end;

function GetAllPasFilesFromPathRecursive(const Path: string): TDictionary<string, TFileInfo>;
begin
  Result := GetAllFilesFromPathRecursive(Path, '*.pas');
end;

{ TIncludeHandler }

constructor TIncludeHandler.Create(const Path: string);
begin
  inherited Create;
  FPath := Path;
end;

function TIncludeHandler.GetIncludeFileContent(const FileName: string): string;
var
  FileContent: TStringList;
begin
  FileContent := TStringList.Create;
  try
    FileContent.LoadFromFile(TPath.Combine(FPath, FileName));
    Result := FileContent.Text;
  finally
    FileContent.Free;
  end;
end;

procedure CarregarPaths;
begin
  FindUnitDir := GetEnvironmentVariable('APPDATA') + '\DelphiFindUnit\';
  FindUnitDirLogger := FindUnitDir + 'Logger\';
  FindUnitDcuDir := FindUnitDir + IntToStr(GetHashCodeFromStr(PChar(ParamStr(0)))) + '\';
  FindUnitDcuDir := FindUnitDcuDir + 'DecompiledDcus\';

  ForceDirectories(FindUnitDir);
  ForceDirectories(FindUnitDcuDir);
  ForceDirectories(FindUnitDirLogger);

  DirRealeaseWin32 := ExtractFilePath(ParamStr(0));
  DirRealeaseWin32 := StringReplace(DirRealeaseWin32, '\bin', '\lib\win32\release', [rfReplaceAll, rfIgnoreCase]);
end;

{ TPathConverter }

class function TPathConverter.ConvertPathsToFullPath(Paths: string): string;
var
  CurVariable: string;
  CurPaths: string;
  FullPath: string;
begin
  while Pos(VAR_INIT, Paths) > 0 do begin
    CurPaths := Paths;
    Fetch(CurPaths, VAR_INIT);
    CurVariable := Fetch(CurPaths, VAR_END, False);

    Logger.Debug('TPathConverter.ConvertPathsToFullPath: %s', [CurVariable]);

    FullPath := GetEnvironmentVariable(CurVariable);

    Paths := StringReplace(Paths, VAR_INIT + CurVariable + VAR_END, FullPath, [rfReplaceAll]);
  end;

  Result := Paths;
end;

function RemoveDelphiComments(const Line: string): string;
var
  I: Integer;
begin
  Result := Line;
  I := 1;
  while I <= Length(Result) do
  begin
    if Result[I] = '/' then
    begin
      if (I < Length(Result)) and (Result[I + 1] = '/') then
      begin
        Result := Copy(Result, 1, I - 1);
        Exit;
      end;
      Inc(I);
    end
    else if Result[I] = '{' then
    begin
      Result := Copy(Result, 1, I - 1);
      Exit;
    end
    else if Result[I] = '(' then
    begin
      if (I < Length(Result)) and (Result[I + 1] = '*') then
      begin
        Result := Copy(Result, 1, I - 1);
        Exit;
      end;
      Inc(I);
    end
    else
      Inc(I);
  end;
end;

function FindSemicolonExcludingComments(const Line: string): Integer;
var
  I: Integer;
  InBraceComment: Boolean;
  InParenComment: Boolean;
begin
  Result := 0;
  I := 1;
  InBraceComment := False;
  InParenComment := False;

  while I <= Length(Line) do
  begin
    if InBraceComment then
    begin
      if Line[I] = '}' then
        InBraceComment := False;
    end
    else if InParenComment then
    begin
      if (Line[I] = '*') and (I < Length(Line)) and (Line[I + 1] = ')') then
      begin
        InParenComment := False;
        Inc(I);
      end;
    end
    else
    begin
      if Line[I] = ';' then
      begin
        Result := I;
        Exit;
      end
      else if Line[I] = '{' then
        InBraceComment := True
      else if (Line[I] = '(') and (I < Length(Line)) and (Line[I + 1] = '*') then
      begin
        InParenComment := True;
        Inc(I);
      end
      else if (Line[I] = '/') and (I < Length(Line)) and (Line[I + 1] = '/') then
        Exit;
    end;
    Inc(I);
  end;
end;

function UncommentLine(const Line: string): string;
var
  I: Integer;
  InBrace, InParen, InSlash: Boolean;
  StartPos: Integer;
  Before, Between, After: string;
begin
  Result := Line;
  I := 1;
  InBrace := False;
  InParen := False;
  InSlash := False;
  StartPos := 0;

  while I <= Length(Result) do
  begin
    if InBrace then
    begin
      if Result[I] = '}' then
      begin
        Before := Copy(Result, 1, StartPos - 1);
        Between := Copy(Result, StartPos + 1, I - StartPos - 1);
        After := Copy(Result, I + 1, MaxInt);
        Exit(Trim(Before + Between + After));
      end;
    end
    else if InParen then
    begin
      if (Result[I] = '*') and (I < Length(Result)) and (Result[I + 1] = ')') then
      begin
        Before := Copy(Result, 1, StartPos - 1);
        Between := Copy(Result, StartPos + 2, I - StartPos - 2);
        After := Copy(Result, I + 2, MaxInt);
        Exit(Trim(Before + Between + After));
      end;
    end
    else if InSlash then
    begin
      Before := Copy(Result, 1, StartPos - 1);
      After := Copy(Result, StartPos + 2, MaxInt);
      Exit(Trim(Before + After));
    end
    else
    begin
      if Result[I] = '{' then
      begin
        InBrace := True;
        StartPos := I;
      end
      else if (I < Length(Result)) and (Result[I] = '(') and (Result[I + 1] = '*') then
      begin
        InParen := True;
        StartPos := I;
      end
      else if (I < Length(Result)) and (Result[I] = '/') and (Result[I + 1] = '/') then
      begin
        InSlash := True;
        StartPos := I;
      end;
    end;
    Inc(I);
  end;
end;

initialization

  CarregarPaths;

end.
