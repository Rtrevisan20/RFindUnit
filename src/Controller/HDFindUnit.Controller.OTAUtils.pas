unit HDFindUnit.Controller.OTAUtils;

interface

uses
  HDFindUnit.Model.Header,
  HDFindUnit.Utils,
  Generics.Collections,
  Classes,
{$IFDEF FPC}
  SysUtils,
  SrcEditorIntf,
  LazIDEIntf,
  ProjectIntf;
{$ELSE}
  ToolsAPI,
  Winapi.ActiveX,
  Winapi.ShellAPI,
  Winapi.ShlObj;
{$ENDIF}

{$IFDEF FPC}
type
  // On Lazarus there is no IOTASourceEditor (ToolsAPI). TSourceEditorInterface
  // (SrcEditorIntf) is the closest match and is used as a drop-in alias.
  IOTASourceEditor = TSourceEditorInterface;
  // IOTAEditWriter / TOTACharPos are only declared (not used) in the FPC port:
  // all write operations go through TSourceEditorInterface.Lines/ReplaceLines.
  IOTAEditWriter = TObject;
  TOTACharPos = record
    CharIndex: Integer;
    Line: Integer;
  end;
{$ENDIF}

function GetVolumeLabel(const DriveChar: string): string;
function BrowseURL(const URL: string): boolean;
{$IFNDEF FPC}
function GetEditView(var ASourceEditor: IOTASourceEditor; var AEditView: IOTAEditView): boolean;
{$ENDIF}
function EditorAsString(SourceEditor: IOTASourceEditor): string;
function ActiveSourceEditor: IOTASourceEditor;
{$IFNDEF FPC}
function SourceEditor(Module: IOTAMOdule): IOTASourceEditor;
{$ENDIF}

// GeExperts
{$IFNDEF FPC}
function GxOtaGetCurrentModule: IOTAMOdule;
function GxOtaGetFileEditorForModule(Module: IOTAMOdule; Index: Integer): IOTAEditor;
function GxOtaGetSourceEditorFromModule(Module: IOTAMOdule; const FileName: string = ''): IOTASourceEditor;
function GetCurrentProject: IOTAProject;
function GetSelectedTextFromContext(Context: IOTAKeyContext): TStringPosition;
function GetErrorListFromActiveModule: TOTAErrors;
{$ENDIF}
function OtaGetCurrentSourceEditor: IOTASourceEditor;
procedure GetLibraryPath(Paths: TStrings; PlatformName: string);

function GetAllFilesFromProjectGroup: TDictionary<string, TFileInfo>;
function GetProjectSearchPathsFromDproj: TStringList;

function GetWordAtCursor(DeltaCharPosition: Integer = 0): TStringPosition;

{$IFDEF FPC}
function IsProjectOpened: Boolean;
{$ENDIF}

var
  PathUserDir: string;

implementation

uses
{$IFDEF FPC}
  Windows,
  Types,
  LCLIntf,
  Log4Pascal;
{$ELSE}
  System.SysUtils,
  System.IOUtils,
  System.Variants,
  System.Win.Registry,
  Winapi.Windows,
  Xml.XMLDoc,
  Xml.XMLIntf,
  Log4Pascal;
{$ENDIF}

{$IFNDEF FPC}
function SourceEditor(Module: IOTAMOdule): IOTASourceEditor;
var
  iFileCount: Integer;
  i: Integer;
begin
  Result := nil;
  if Module = nil then
    Exit;
  with Module do begin
    iFileCount := GetModuleFileCount;
    for i := 0 To iFileCount - 1 do
      if GetModuleFileEditor(i).QueryInterface(IOTASourceEditor, Result) = S_OK then
        Break;
  end;
end;
{$ENDIF}

{$IFNDEF FPC}
function ActiveSourceEditor: IOTASourceEditor;
var
  CM: IOTAMOdule;
begin
  Result := Nil;
  if BorlandIDEServices = nil then
    Exit;
  CM := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
  Result := SourceEditor(CM);
end;
{$ELSE}
function ActiveSourceEditor: IOTASourceEditor;
begin
  Result := nil;
  if SourceEditorManagerIntf <> nil then
    Result := SourceEditorManagerIntf.ActiveEditor;
end;
{$ENDIF}

{$IFNDEF FPC}
function GetErrorListFromActiveModule: TOTAErrors;
var
  ModuleErrors: IOTAModuleErrors;
  CurModule: IOTAModule;
  ActiveEditor: IOTASourceEditor;
begin
  Result := nil;
  try
    ActiveEditor := ActiveSourceEditor;
    if ActiveEditor = nil then
      Exit;

    CurModule := GxOtaGetCurrentModule;
    if CurModule = nil then
      Exit;

    if not Supports(CurModule, IOTAModuleErrors, ModuleErrors) then
      Exit;

    Result := ModuleErrors.GetErrors(ActiveEditor.FileName);
  except
    on E: Exception do
      Result := nil;
  end;
end;
{$ENDIF}

{$IFNDEF FPC}
function GetAllFilesFromProjectGroup: TDictionary<string, TFileInfo>;
var
  ModServices: IOTAModuleServices;
  Module: IOTAMOdule;
  ProjectGroup: IOTAProjectGroup;
  iMod: Integer;
  FileDesc: string;
  iProj: Integer;
  CurProject: IOTAProject;
  iFile: Integer;
  FileInfo: TFileInfo;
begin
  Result := TDictionary<string, TFileInfo>.Create;

  ModServices := BorlandIDEServices as IOTAModuleServices;

  if ModServices = nil then
    Exit;
  if ModServices.ModuleCount = 0 then
    Exit;

  for iMod := 0 to ModServices.ModuleCount - 1 do begin
    Module := ModServices.Modules[iMod];
    if Supports(Module, IOTAProjectGroup, ProjectGroup) then begin
      for iProj := 0 to ProjectGroup.ProjectCount - 1 do begin
        CurProject := ProjectGroup.Projects[iProj];
        for iFile := 0 to CurProject.GetModuleCount - 1 do begin
          FileDesc := CurProject.GetModule(iFile).FileName;
          if FileDesc = '' then
            Continue;

          FileInfo.Path := FileDesc;
          if FileExists(FileDesc) then
            FileInfo.LastAccess := System.IOUtils.TFile.GetLastWriteTime(FileDesc)
          else
            FileInfo.LastAccess := 0;
          Result.AddOrSetValue(FileInfo.Path, FileInfo);
        end;
      end;
    end;
  end;
end;
{$ELSE}
function GetAllFilesFromProjectGroup: TDictionary<string, TFileInfo>;
var
  CurProject: TLazProject;
  iFile: Integer;
  FileName: string;
  FileInfo: TFileInfo;
begin
  Result := TDictionary<string, TFileInfo>.Create;
  if LazarusIDE = nil then
    Exit;
  CurProject := LazarusIDE.ActiveProject;
  if CurProject = nil then
    Exit;
  for iFile := 0 to CurProject.FileCount - 1 do begin
    if CurProject.Files[iFile] = nil then
      Continue;
    FileName := CurProject.Files[iFile].Filename;
    if FileName = '' then
      Continue;

    FileInfo.Path := FileName;
    if FileExists(FileName) then
      FileInfo.LastAccess := FileAge(FileName)
    else
      FileInfo.LastAccess := 0;
    Result.AddOrSetValue(FileInfo.Path, FileInfo);
  end;
end;
{$ENDIF}

{$IFNDEF FPC}
function GetProjectSearchPathsFromDproj: TStringList;
var
  Project: IOTAProject;
  DprojFile: string;
  ProjDir: string;
  XMLDoc: IXMLDocument;
  Node: IXMLNode;
  SearchPath: string;
  I: Integer;
  PathValue: string;
begin
  Result := TStringList.Create;
  Result.Delimiter := ';';
  Result.StrictDelimiter := True;
  Result.Duplicates := dupIgnore;

  Project := GetCurrentProject;
  if Project = nil then
    Exit;

  DprojFile := Project.FileName;
  if not FileExists(DprojFile) then
    Exit;

  ProjDir := ExtractFilePath(DprojFile);

  try
    XMLDoc := LoadXMLDocument(DprojFile);
    Node := XMLDoc.DocumentElement;
    if Node = nil then
      Exit;

    Node := Node.ChildNodes.First;
    while Node <> nil do
    begin
      if SameText(Node.NodeName, 'PropertyGroup') then
      begin
        SearchPath := '';
        if Node.ChildNodes.FindNode('DCC_UnitSearchPath') <> nil then
          SearchPath := VarToStr(Node.ChildNodes.FindNode('DCC_UnitSearchPath').NodeValue);

        if SearchPath <> '' then
        begin
          Result.DelimitedText := SearchPath;
          for I := Result.Count - 1 downto 0 do
          begin
            PathValue := Trim(Result[I]);
            if PathValue = '' then
              Result.Delete(I)
            else if Pos('$(DCC_UnitSearchPath)', PathValue) = 1 then
              Result.Delete(I)
            else
            begin
              PathValue := TPathConverter.ConvertPathsToFullPath(PathValue);

              if not TPath.IsPathRooted(PathValue) then
                PathValue := TPath.Combine(ProjDir, PathValue);

              PathValue := TPath.GetFullPath(PathValue);

              if DirectoryExists(PathValue) then
                Result[I] := PathValue
              else
                Result.Delete(I);
            end;
          end;
          Break;
        end;
      end;
      Node := Node.NextSibling;
    end;
  except
    on E: Exception do
      Logger.Error('GetProjectSearchPathsFromDproj: ' + E.Message);
  end;
end;
{$ELSE}
function GetProjectSearchPathsFromDproj: TStringList;
begin
  // Lazarus uses .lpk/.lpi, not .dproj. Parsing project search paths is a
  // later stage; for now return an empty list.
  Result := TStringList.Create;
  Result.Delimiter := ';';
  Result.StrictDelimiter := True;
  Result.Duplicates := dupIgnore;
end;
{$ENDIF}

{$IFNDEF FPC}
procedure GetLibraryPath(Paths: TStrings; PlatformName: string);
var
  Svcs: IOTAServices;
  Options: IOTAEnvironmentOptions;
  Text: string;
  List: TStrings;
  ValueCompiler: string;
  RegRead: TRegistry;
begin
  Svcs := BorlandIDEServices as IOTAServices;
  if not Assigned(Svcs) then
    Exit;
  Options := Svcs.GetEnvironmentOptions;
  if not Assigned(Options) then
    Exit;

  ValueCompiler := Svcs.GetBaseRegistryKey;

  RegRead := TRegistry.Create;
  List := TStringList.Create;
  try
    if PlatformName = '' then
      Text := Options.GetOptionValue('LibraryPath')
    else begin
      RegRead.RootKey := HKEY_CURRENT_USER;
      RegRead.OpenKey(ValueCompiler + '\Library\' + PlatformName, False);
      Text := RegRead.GetDataAsString('Search Path');
    end;

    List.Text := StringReplace(Text, ';', #13#10, [rfReplaceAll]);
    Paths.AddStrings(List);

    if PlatformName = '' then
      Text := Options.GetOptionValue('BrowsingPath')
    else begin
      RegRead.RootKey := HKEY_CURRENT_USER;
      RegRead.OpenKey(ValueCompiler + '\Library\' + PlatformName, False);
      Text := RegRead.GetDataAsString('Browsing Path');
    end;

    List.Text := StringReplace(Text, ';', #13#10, [rfReplaceAll]);
    Paths.AddStrings(List);
  finally
    RegRead.Free;
    List.Free;
  end;
end;
{$ELSE}
procedure GetLibraryPath(Paths: TStrings; PlatformName: string);
const
  Candidates: array[0..2] of string = (
    'C:\lazarus\lcl',
    'C:\lazarus\fpc\3.2.2\source\rtl',
    'C:\lazarus\fpc\3.2.2\source\packages'
  );
var
  I: Integer;
begin
  for I := Low(Candidates) to High(Candidates) do
    if DirectoryExists(Candidates[I]) then
      Paths.Add(Candidates[I]);
end;
{$ENDIF}

{$IFNDEF FPC}
function GetWordAtCursor(DeltaCharPosition: Integer): TStringPosition;
const
  strIdentChars = ['a'..'z', 'A'..'Z', '_', '0'..'9'];
var
  SourceEditor: IOTASourceEditor;
  EditPos: TOTAEditPos;
  iPosition: Integer;
  Content: TStringList;
  ContentTxt: string;
begin
  try
    ContentTxt := '';
    SourceEditor := ActiveSourceEditor;
    EditPos := SourceEditor.EditViews[0].CursorPos;
    Content := TStringList.Create;
    try
      Content.Text := EditorAsString(SourceEditor);
      ContentTxt := Content[Pred(EditPos.Line)];
      iPosition := EditPos.Col + DeltaCharPosition;
      if (iPosition > 0) And (Length(ContentTxt) >= iPosition) and CharInSet(ContentTxt[iPosition], strIdentChars) then
      begin
        while (iPosition > 1) And (CharInSet(ContentTxt[Pred(iPosition)], strIdentChars)) do
          Dec(iPosition);
        Delete(ContentTxt, 1, Pred(iPosition));
        iPosition := 1;
        while CharInSet(ContentTxt[iPosition], strIdentChars) do
          Inc(iPosition);
        Delete(ContentTxt, iPosition, Length(ContentTxt) - iPosition + 1);
        if CharInSet(ContentTxt[1], ['0'..'9']) then
          ContentTxt := '';
      end
      else
        ContentTxt := '';

      Result.Value := ContentTxt;
      Result.Line := EditPos.Line;
    finally
      Content.Free;
    end;
  except
    on E: exception do begin
      Result.Value := '';
      Result.Line := -1;
    end;
  end;

  if (DeltaCharPosition = 0) and (Result.Value = '') then
    Result := GetWordAtCursor(-1);
end;
{$ELSE}
function GetWordAtCursor(DeltaCharPosition: Integer): TStringPosition;
const
  strIdentChars = ['a'..'z', 'A'..'Z', '_', '0'..'9'];
var
  SourceEditor: IOTASourceEditor;
  CurPos: TPoint;
  iPosition: Integer;
  ContentTxt: string;
begin
  Result.Value := '';
  Result.Line := -1;
  try
    SourceEditor := ActiveSourceEditor;
    if SourceEditor = nil then
      Exit;
    CurPos := SourceEditor.CursorTextXY;
    if (CurPos.Y < 1) or (CurPos.Y > SourceEditor.Lines.Count) then
      Exit;
    ContentTxt := SourceEditor.Lines[CurPos.Y - 1];
    Result.Line := CurPos.Y;
    iPosition := CurPos.X + DeltaCharPosition;
    if (iPosition > 0) and (Length(ContentTxt) >= iPosition) and CharInSet(ContentTxt[iPosition], strIdentChars) then
    begin
      while (iPosition > 1) and (CharInSet(ContentTxt[Pred(iPosition)], strIdentChars)) do
        Dec(iPosition);
      Delete(ContentTxt, 1, Pred(iPosition));
      iPosition := 1;
      while (iPosition <= Length(ContentTxt)) and (CharInSet(ContentTxt[iPosition], strIdentChars)) do
        Inc(iPosition);
      Delete(ContentTxt, iPosition, Length(ContentTxt) - iPosition + 1);
      if CharInSet(ContentTxt[1], ['0'..'9']) then
        ContentTxt := '';
    end
    else
      ContentTxt := '';

    Result.Value := ContentTxt;
  except
    on E: exception do begin
      Result.Value := '';
      Result.Line := -1;
    end;
  end;

  if (DeltaCharPosition = 0) and (Result.Value = '') then
    Result := GetWordAtCursor(-1);
end;
{$ENDIF}

{$IFNDEF FPC}
function GetSelectedTextFromContext(Context: IOTAKeyContext): TStringPosition;
var
  Editor: IOTAEditBuffer;
  CurSourceEditor: IOTASourceEditor;
begin
  CurSourceEditor := ActiveSourceEditor;
  Result.Line := CurSourceEditor.EditViews[0].CursorPos.Line;
  Result.Value := '';
  if Context = nil then
    Exit;

  Editor := Context.EditBuffer;
  if Editor = nil then
    Exit;

  Result.Value := Trim(Editor.EditBlock.Text);
end;
{$ENDIF}

{$IFNDEF FPC}
function GetCurrentProject: IOTAProject;
var
  ModServices: IOTAModuleServices;
  Module: IOTAMOdule;
  Project: IOTAProject;
  ProjectGroup: IOTAProjectGroup;
  i: Integer;
begin
  Result := nil;
  ModServices := BorlandIDEServices as IOTAModuleServices;
  for i := 0 to ModServices.ModuleCount - 1 do begin
    Module := ModServices.Modules[i];
    if Supports(Module, IOTAProjectGroup, ProjectGroup) then begin
      Result := ProjectGroup.ActiveProject;
      Exit;
    end
    else if Supports(Module, IOTAProject, Project) then begin // In the case of unbound packages, return the 1st
      if Result = nil then
        Result := Project;
    end;
  end;
end;

// Credits to GXExperts
function GxOtaGetCurrentModule: IOTAMOdule;
var
  ModuleServices: IOTAModuleServices;
begin
  ModuleServices := BorlandIDEServices as IOTAModuleServices;
  Assert(Assigned(ModuleServices));
  Result := ModuleServices.CurrentModule;
end;

// Credits to GXExperts
function GxOtaGetFileEditorForModule(Module: IOTAMOdule; Index: Integer): IOTAEditor;
begin
  Assert(Assigned(Module));
  Result := Module.GetModuleFileEditor(Index);
end;

// Credits to GXExperts
function GxOtaGetSourceEditorFromModule(Module: IOTAMOdule; const FileName: string = ''): IOTASourceEditor;
var
  i: Integer;
  IEditor: IOTAEditor;
  ISourceEditor: IOTASourceEditor;
begin
  Result := nil;
  if not Assigned(Module) then
    Exit;

  for i := 0 to Module.GetModuleFileCount - 1 do begin
    IEditor := GxOtaGetFileEditorForModule(Module, i);

    if Supports(IEditor, IOTASourceEditor, ISourceEditor) then begin
      if Assigned(ISourceEditor) then begin
        if (FileName = '') or SameFileName(ISourceEditor.FileName, FileName) then begin
          Result := ISourceEditor;
          Break;
        end;
      end;
    end;
  end;
end;
{$ENDIF}

{$IFNDEF FPC}
function OtaGetCurrentSourceEditor: IOTASourceEditor;
var
  LEditorServices: IOTAEditorServices;
  LEditBuffer: IOTAEditBuffer;
begin
  Result := nil;

  LEditorServices := (BorlandIDEServices as IOTAEditorServices);
  LEditBuffer := LEditorServices.TopBuffer;

  if Assigned(LEditBuffer) and (LEditBuffer.FileName <> '') then
    Result := GxOtaGetSourceEditorFromModule(GxOtaGetCurrentModule, LEditBuffer.FileName);

  if Result = nil then
    Result := GxOtaGetSourceEditorFromModule(GxOtaGetCurrentModule);

end;
{$ELSE}
function OtaGetCurrentSourceEditor: IOTASourceEditor;
begin
  Result := nil;
  if SourceEditorManagerIntf <> nil then
    Result := SourceEditorManagerIntf.ActiveEditor;
end;
{$ENDIF}

{$IFNDEF FPC}
function GetEditView(var ASourceEditor: IOTASourceEditor; var AEditView: IOTAEditView): boolean;
begin
  Result := False;
  ASourceEditor := OtaGetCurrentSourceEditor;
  if not Assigned(ASourceEditor) then
    Exit;
  AEditView := ASourceEditor.GetEditView(0);
  Result := Assigned(AEditView);
end;
{$ENDIF}

{$IFDEF FPC}
function IsProjectOpened: Boolean;
begin
  Result := (LazarusIDE <> nil) and (LazarusIDE.ActiveProject <> nil);
end;
{$ENDIF}

{$IFNDEF FPC}
type
  TBrowserInformation = record
    Name: String;
    Path: String;
    Version: String;
  end;

function GetDefaultBrowser: TBrowserInformation;
var
  tmp: PChar;
  res: PChar;

begin
  tmp := StrAlloc(255);
  res := StrAlloc(255);
  try
    GetTempPath(255, tmp);
    FileCreate(tmp + 'htmpl.htm');
    FindExecutable('htmpl.htm', tmp, res);
    Result.Name := ExtractFileName(res);
    Result.Path := ExtractFilePath(res);
    System.SysUtils.DeleteFile(tmp + 'htmpl.htm');
  finally
    StrDispose(tmp);
    StrDispose(res);
  end;
end;
{$ENDIF}

{$IFNDEF FPC}
function EditorAsString(SourceEditor: IOTASourceEditor): string;
const
  iBufferSize: Integer = 1024;
Var
  Reader: IOTAEditReader;
  iRead: Integer;
  iPosition: Integer;
  strBuffer: AnsiString;
begin
  Result := '';

  Reader := SourceEditor.CreateReader;
  try
    iPosition := 0;
    repeat
      SetLength(strBuffer, iBufferSize);
      iRead := Reader.GetText(iPosition, PAnsiChar(strBuffer), iBufferSize);
      SetLength(strBuffer, iRead);
      Result := Result + String(strBuffer);
      Inc(iPosition, iRead);
    until iRead < iBufferSize;
  finally
    Reader := Nil;
  end;
end;
{$ELSE}
function EditorAsString(SourceEditor: IOTASourceEditor): string;
begin
  if SourceEditor = nil then
    Result := ''
  else
    Result := SourceEditor.Lines.Text;
end;
{$ENDIF}

{$IFNDEF FPC}
function LongPathName(const ShortPathName: string): string;
var
  PIDL: PItemIDList;
  Desktop: IShellFolder;
  WidePathName: WideString;
  PathBuffer: string;
begin
  Result := ShortPathName;
  if Succeeded(SHGetDesktopFolder(Desktop)) then begin
    WidePathName := ShortPathName;
    if Succeeded(Desktop.ParseDisplayName(0, nil, PWideChar(WidePathName), ULONG(nil^), PIDL, ULONG(nil^))) then

      try
        SetLength(PathBuffer, MAX_PATH);
        SHGetPathFromIDList(PIDL, PChar(PathBuffer));
        Result := PChar(PathBuffer);

      finally
        CoTaskMemFree(PIDL);
      end;
  end;
end;
{$ENDIF}

function GetEnvVarValue(const AVarName: string): string;
var
  LBufSize: Integer;
begin
  LBufSize := GetEnvironmentVariable(PChar(AVarName), nil, 0);
  if LBufSize > 0 then begin
    SetLength(Result, LBufSize - 1);
    GetEnvironmentVariable(PChar(AVarName), PChar(Result), LBufSize);
  end
  else
    Result := '';
end;

function GetVolumeLabel(const DriveChar: string): string;
var
  NotUsed: DWORD;
  VolumeFlags: DWORD;
  VolumeSerialNumber: DWORD;
  Buf: array[0..MAX_PATH] of Char;
begin
  GetVolumeInformation(PChar(DriveChar), Buf, MAX_PATH, @VolumeSerialNumber, NotUsed, VolumeFlags, nil, 0);

  SetString(Result, Buf, StrLen(Buf)); { Set return result }
  Result := AnsiUpperCase(Result);
end;

{$IFDEF FPC}
function BrowseURL(const URL: string): boolean;
begin
  OpenURL(URL);
  Result := True;
end;
{$ELSE}
function BrowseURL(const URL: string): boolean;
var
  LBrowserInformation: TBrowserInformation;
begin
  LBrowserInformation := GetDefaultBrowser;
  Result :=
      ShellExecute(0, 'open', PChar(LBrowserInformation.Path + LBrowserInformation.Name), PChar(URL), nil, SW_SHOW)
          > 32;
end;
{$ENDIF}

initialization

  PathUserDir := GetEnvVarValue('APPDATA') + '\RfUtils';
  CreateDir(PathUserDir);

end.