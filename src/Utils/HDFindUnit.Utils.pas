unit HDFindUnit.Utils;

interface

uses
  SimpleParser.Lexer.Types,
  Generics.Collections,
  StrUtils;

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
    procedure Process;
    function GetIncludeFileContent(const ParentFileName, IncludeName: string;
      out Content: string; out FileName: string): Boolean;
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
  Classes,
  SysUtils,
  Types
  {$IFDEF FPC}, Windows{$ELSE}, System.Masks, System.IOUtils, Winapi.TlHelp32, Winapi.Windows{$ENDIF};

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
  IsSetEnumItem := AnsiEndsStr(' item', SearchSelection);
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
{$IFDEF FPC}
begin
  Result := False;
end;
{$ELSE}
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
{$ENDIF}

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

{$IFDEF FPC}
function MatchesSimpleMask(const Filename, Mask: string): Boolean;
var
  FStart, MStart: Integer;
begin
  Result := False;
  FStart := 1;
  MStart := 1;
  while MStart <= Length(Mask) do
  begin
    if Mask[MStart] = '*' then
    begin
      Inc(MStart);
      if MStart > Length(Mask) then
      begin
        Result := True;
        Exit;
      end;
      while (FStart <= Length(Filename)) and
            (not MatchesSimpleMask(Copy(Filename, FStart, Length(Filename) - FStart + 1), Copy(Mask, MStart, Length(Mask) - MStart + 1))) do
        Inc(FStart);
      Result := FStart <= Length(Filename);
      Exit;
    end
    else if (FStart > Length(Filename)) then
      Exit
    else if (Mask[MStart] = '?') or (AnsiCompareText(Filename[FStart], Mask[MStart]) = 0) then
    begin
      Inc(FStart);
      Inc(MStart);
    end
    else
      Exit;
  end;
  Result := FStart > Length(Filename);
end;
{$ENDIF}

function GetAllFilesFromPath(const Path, Filter: string): TDictionary<string, TFileInfo>;
var
  FilePath: string;
  FileInfo: TFileInfo;
  SR: TSearchRec;
begin
  Result := TDictionary<string, TFileInfo>.Create;
  try
    if SysUtils.FindFirst(IncludeTrailingPathDelimiter(Path) + Filter, faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Attr and faDirectory) = 0 then
        begin
          FilePath := Trim(IncludeTrailingPathDelimiter(Path) + SR.Name);
          FileInfo.Path := FilePath;
          if not FileAge(FilePath, FileInfo.LastAccess) then
            FileInfo.LastAccess := 0;
          Result.Add(FileInfo.Path, FileInfo);
        end;
      until SysUtils.FindNext(SR) <> 0;
    finally
      SysUtils.FindClose(SR);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function GetAllFilesFromPathRecursive(const Path, Filter: string): TDictionary<string, TFileInfo>;
var
  FilePath: string;
  FileInfo: TFileInfo;

  procedure ScanDir(const Dir: string);
  var
    SubPath: string;
    SR: TSearchRec;
  begin
    if SysUtils.FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
        begin
          SubPath := IncludeTrailingPathDelimiter(Dir) + SR.Name;
          if (SR.Attr and faDirectory) <> 0 then
            ScanDir(SubPath)
          else if {$IFDEF FPC}MatchesSimpleMask{$ELSE}MatchesMask{$ENDIF}(SR.Name, Filter) then
          begin
            FilePath := Trim(SubPath);
            FileInfo.Path := FilePath;
            if not FileAge(FilePath, FileInfo.LastAccess) then
              FileInfo.LastAccess := 0;
            Result.Add(FileInfo.Path, FileInfo);
          end;
        end;
      until SysUtils.FindNext(SR) <> 0;
    finally
      SysUtils.FindClose(SR);
    end;
  end;

begin
  Result := TDictionary<string, TFileInfo>.Create;
  try
    ScanDir(Path);
  except
    Result.Free;
    raise;
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

procedure TIncludeHandler.Process;
begin
end;

function TIncludeHandler.GetIncludeFileContent(const ParentFileName, IncludeName: string;
  out Content: string; out FileName: string): Boolean;
var
  FileContent: TStringList;
  FullPath: string;
begin
  Content := '';
  FileName := '';
  Result := False;

  FullPath := IncludeName;
  if not FileExists(FullPath) then
    FullPath := IncludeTrailingPathDelimiter(FPath) + IncludeName;

  if not FileExists(FullPath) then
    Exit;

  FileContent := TStringList.Create;
  try
    FileContent.LoadFromFile(FullPath);
    Content := FileContent.Text;
    FileName := FullPath;
    Result := True;
  finally
    FileContent.Free;
  end;
end;

procedure CarregarPaths;
begin
  {$IFDEF FPC}FindUnitDir := SysUtils.GetEnvironmentVariable('APPDATA') + '\DelphiFindUnit\';{$ELSE}
  FindUnitDir := GetEnvironmentVariable('APPDATA') + '\DelphiFindUnit\';{$ENDIF}
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

    {$IFDEF FPC}FullPath := SysUtils.GetEnvironmentVariable(CurVariable);{$ELSE}
    FullPath := GetEnvironmentVariable(CurVariable);{$ENDIF}

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
