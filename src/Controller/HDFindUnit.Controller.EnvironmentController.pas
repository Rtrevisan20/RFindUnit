unit HDFindUnit.Controller.EnvironmentController;

interface

uses
  Log4Pascal,
{$IFNDEF FPC}
  ToolsAPI,
  Xml.XMLIntf,
{$ENDIF}
  HDFindUnit.Model.AutoImport,
  HDFindUnit.Model.FileCache,
  HDFindUnit.Model.FileEditor,
  HDFindUnit.View.FormMessage,
  HDFindUnit.Model.Header,
  HDFindUnit.Controller.OTAUtils,
  HDFindUnit.Model.PasParser,
  HDFindUnit.Model.StringPositionList,
  HDFindUnit.Model.Translation,
  HDFindUnit.Utils,
  HDFindUnit.Model.Worker,
  HDFindUnit.Controller.Interf.EnvironmentController,
  HDFindUnit.Model.Interf.Translation,
  Classes,
  Generics.Collections,
  SysUtils
{$IFNDEF FPC}
  ,
  Winapi.ActiveX,
  Winapi.Windows
{$ENDIF}
  ;

type
  TEnvironmentController = class(TInterfacedObject,
{$IFNDEF FPC}
    IOTAProjectFileStorageNotifier,
{$ENDIF}
    IRFUEnvironmentController)
  private
    FProcessingDCU: Boolean;
    FAutoImport: TAutoImport;

    FProjectUnits: TUnitsController;
    FLibraryPath: TUnitsController;

    FProjectPathWorker: TParserWorker;
    FLibraryPathWorker: TParserWorker;

    FLibraryPathLoading: Boolean;
    FProjectPathLoading: Boolean;

{$IFNDEF FPC}
    function CreateBackgroundThread(const AProc: TThreadProcedure): TThread;
{$ENDIF}

    procedure CreateLibraryPathUnits(OldItems: TUnits);
    procedure OnFinishedLibraryPathScan(FindUnits: TUnits);

    procedure CreateProjectPathUnits(NewFiles: TDictionary<string, TFileInfo>; OldFiles: TUnits);
    procedure AddFilesFromProjectSearchPaths(Files: TDictionary<string, TFileInfo>; SearchPaths: TStringList);
    procedure OnFinishedProjectPathScan(FindUnits: TUnits);

{$IFNDEF FPC}
    procedure CreatingProject(const ProjectOrGroup: IOTAModule);
    //Dummy
    procedure ProjectLoaded(const ProjectOrGroup: IOTAModule; const Node: IXMLNode);
    procedure ProjectSaving(const ProjectOrGroup: IOTAModule; const Node: IXMLNode);
    procedure ProjectClosing(const ProjectOrGroup: IOTAModule);
{$ENDIF}

    {$IFNDEF FPC}
    procedure CallProcessDcuFiles;
{$ENDIF}
  public
    function GetName: string;

    constructor Create;
    destructor Destroy; override;

    procedure ForceRunDependencies;

    procedure LoadLibraryPath;
    procedure LoadProjectPath(AWaitForProject: Boolean = False);
    procedure ForceLoadProjectPath;

    function GetProjectUnits(const SearchString: string): TStringList;
    function GetLibraryPathUnits(const SearchString: string): TStringList;

    function PasExists(PasName: string): Boolean;
    function IsFileIndexed(FilePath: string): Boolean;

    function GetFullMatch(const SearchString: string): TStringList;
    function GetElementMatches(const ElementName: string): TStringList;

    function IsProjectsUnitReady: Boolean;
    function IsLibraryPathsUnitReady: Boolean;

    function GetLibraryPathStatus: string;
    function GetProjectPathStatus: string;

    procedure ProcessDCUFiles;

    property ProcessingDCU: Boolean read FProcessingDCU;
    property AutoImport: TAutoImport read FAutoImport;

    procedure ImportMissingUnits(ShowNoImport: Boolean = true);
    procedure OrganizeUses;

    function AreDependenciasReady: Boolean;
  end;

implementation
{ TEnvUpdateControl }

{$IFDEF FPC}
uses
  Windows;
{$ENDIF}

{$IFNDEF FPC}
type
  TAnonymousThreadMethod = class(TThread)
  private
    FProc: TThreadProcedure;
  protected
    procedure Execute; override;
  public
    constructor Create(const AProc: TThreadProcedure);
  end;

constructor TAnonymousThreadMethod.Create(const AProc: TThreadProcedure);
begin
  FProc := AProc;
  inherited Create(True);
end;

procedure TAnonymousThreadMethod.Execute;
begin
  if Assigned(FProc) then
    FProc;
end;

function TEnvironmentController.CreateBackgroundThread(const AProc: TThreadProcedure): TThread;
begin
  Result := TAnonymousThreadMethod.Create(AProc);
end;
{$ENDIF}

constructor TEnvironmentController.Create;
begin
  FAutoImport := TAutoImport.Create(FindUnitDir + AUTO_IMPORT_FILE);
  FAutoImport.Load;
  LoadLibraryPath;
  LoadProjectPath;
end;

procedure TEnvironmentController.CreateLibraryPathUnits(OldItems: TUnits);
var
  Paths: TStringList;
  Files: TDictionary<string, TFileInfo>;
  WaitCount: Integer;
begin
  try
    FreeAndNil(FLibraryPathWorker);
  except
    on e: exception do
    begin
      Logger.Error('TEnvironmentController.CreateLibraryPathUnits: ' + e.Message);
      {$IFDEF RAISEMAD} raise; {$ENDIF}
    end;
  end;

{$IFDEF FPC}
  // On Lazarus the library paths come from the FPC/LCL installation
  // (GetLibraryPath, see OTAUtils). There is no IDE services wait loop.
  try
    Files := nil;
    Paths := TStringList.Create;
    Paths.Delimiter := ';';
    Paths.StrictDelimiter := True;
    Paths.Duplicates := dupIgnore;

    GetLibraryPath(Paths, '');

    if FLibraryPath = nil then
      FLibraryPath := TUnitsController.Create;
    FLibraryPathWorker := TParserWorker.Create(Paths, Files, OldItems);
    FLibraryPathWorker.Start(OnFinishedLibraryPathScan);
  except
    on E: exception do
    begin
      Logger.Error('TEnvironmentController.CreateLibraryPathUnits: %s', [e.Message]);
      {$IFDEF RAISEMAD} raise; {$ENDIF}
    end;
  end;
{$ELSE}
  WaitCount := 0;
  while (BorlandIDEServices as IOTAServices) = nil do
  begin
    Logger.Debug('TEnvironmentController.CreateLibraryPathUnits: waiting for IOTAServices');
    Sleep(1000);
    Inc(WaitCount);
    if WaitCount >= 30 then
    begin
      Logger.Error('TEnvironmentController.CreateLibraryPathUnits: IOTAServices not available after 30s');
      Exit;
    end;
  end;

  try
    Files := nil;
    Paths := TStringList.Create;
    Paths.Delimiter := ';';
    Paths.StrictDelimiter := True;
    Paths.Duplicates := dupIgnore;

    GetLibraryPath(Paths, 'Win32');
    Paths.Add('$(BDS)\source\rtl\win');

    if FLibraryPath = nil then
      FLibraryPath := TUnitsController.Create;
    FLibraryPathWorker := TParserWorker.Create(Paths, Files, OldItems);
    FLibraryPathWorker.Start(OnFinishedLibraryPathScan);
  except
    on E: exception do
    begin
      Logger.Error('TEnvironmentController.CreateLibraryPathUnits: %s', [e.Message]);
      {$IFDEF RAISEMAD} raise; {$ENDIF}
    end;
  end;
{$ENDIF}
end;

procedure TEnvironmentController.CreateProjectPathUnits(NewFiles: TDictionary<string, TFileInfo>;
 OldFiles: TUnits);
var
  Paths: TStringList;
begin
  try
    FreeAndNil(FProjectPathWorker);
  except
    on E: exception do
    begin
      Logger.Debug('TEnvironmentController.CreateProjectPathUnits: Error removing object');
      {$IFDEF RAISEMAD} raise; {$ENDIF}
    end;
  end;

  if not {$IFDEF FPC}IsProjectOpened{$ELSE}(GetCurrentProject <> nil){$ENDIF} then
    Exit;

  Paths := nil;

  if FProjectUnits = nil then
    FProjectUnits := TUnitsController.Create;
  FProjectPathWorker  := TParserWorker.Create(Paths, NewFiles, OldFiles);
  FProjectPathWorker.Start(OnFinishedProjectPathScan);
end;

{$IFNDEF FPC}
procedure TEnvironmentController.CreatingProject(const ProjectOrGroup: IOTAModule);
begin
  LoadProjectPath(True);
end;
{$ENDIF}

destructor TEnvironmentController.Destroy;
begin
  if FProjectPathWorker <> nil then FProjectPathWorker.RemoveCallBack;
  if FLibraryPathWorker <> nil then FLibraryPathWorker.RemoveCallBack;

  FAutoImport.Free;
  FProjectUnits.Free;
  FLibraryPath.Free;
  inherited;
end;

procedure TEnvironmentController.ForceLoadProjectPath;
begin
  LoadProjectPath;
end;

procedure TEnvironmentController.ForceRunDependencies;
begin
  LoadLibraryPath;
  LoadProjectPath;
end;

function TEnvironmentController.GetFullMatch(const SearchString: string): TStringList;
var
  ProjectUnits: TStringList;
  LibraryUnits: TStringList;
begin
  ProjectUnits := nil;
  LibraryUnits := nil;
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;

  try
    if IsProjectsUnitReady then
    begin
      ProjectUnits := FProjectUnits.GetFindInfoFullMatch(SearchString);
      Result.AddStrings(ProjectUnits);
    end;

    if IsLibraryPathsUnitReady then
    begin
      LibraryUnits := FLibraryPath.GetFindInfoFullMatch(SearchString);
      Result.AddStrings(LibraryUnits);
    end;
  finally
    LibraryUnits.Free;
    ProjectUnits.Free;
  end;
end;

function TEnvironmentController.GetElementMatches(const ElementName: string): TStringList;
var
  ProjectUnits: TStringList;
  LibraryUnits: TStringList;
begin
  ProjectUnits := nil;
  LibraryUnits := nil;
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;

  try
    if IsProjectsUnitReady then
    begin
      ProjectUnits := FProjectUnits.GetElementMatches(ElementName);
      Result.AddStrings(ProjectUnits);
    end;

    if IsLibraryPathsUnitReady then
    begin
      LibraryUnits := FLibraryPath.GetElementMatches(ElementName);
      Result.AddStrings(LibraryUnits);
    end;
  finally
    LibraryUnits.Free;
    ProjectUnits.Free;
  end;
end;

function TEnvironmentController.GetLibraryPathStatus: string;
begin
  Result := Translation.GetStatusReady;
  if FLibraryPathWorker <> nil then
    Result := Translation.GetStatusProcessing(FLibraryPathWorker.ParsedItems, FLibraryPathWorker.ItemsToParse);
end;

function TEnvironmentController.GetLibraryPathUnits(const SearchString: string): TStringList;
begin
  if IsLibraryPathsUnitReady then
    Result := FLibraryPath.GetFindInfo(SearchString)
  else
    Result := TStringList.Create;
end;

function TEnvironmentController.GetName: string;
begin
  Result := 'RfUtils - Replace FindUnit';
end;

function TEnvironmentController.GetProjectPathStatus: string;
begin
  Result := Translation.GetStatusPreparing;
  if FProjectPathWorker <> nil then
    Result := Translation.GetStatusFilesProcessed(FProjectPathWorker.ParsedItems, FProjectPathWorker.ItemsToParse);
end;

function TEnvironmentController.GetProjectUnits(const SearchString: string): TStringList;
begin
  if IsProjectsUnitReady then
    Result := FProjectUnits.GetFindInfo(SearchString)
  else
    Result := TStringList.Create;
end;

procedure TEnvironmentController.ImportMissingUnits(ShowNoImport: Boolean);
var
  CurEditor: IOTASourceEditor;
  FileEditor: TSourceFileEditor;
  ListToImport: TStringPositionList;
  Item: TStringPosition;
{$IFDEF FPC}
  OldFocus: HWND;
{$ELSE}
  OldFocus: Cardinal;
{$ENDIF}
begin
  if FAutoImport = nil then
    Exit;

  CurEditor := OtaGetCurrentSourceEditor;
  if CurEditor = nil then
    Exit;

  OldFocus := {$IFDEF FPC}Windows.{$ENDIF}GetFocus;

  ListToImport := FAutoImport.LoadUnitListToImport;

  if ListToImport.Count = 0 then
  begin
    if ShowNoImport then
      TfrmMessage.ShowInfoToUser(Translation.GetAutoImportNoUnitsToImport);
    ListToImport.Free;
    {$IFDEF FPC}Windows.{$ENDIF}SetFocus(OldFocus);
    Exit;
  end;

  FileEditor := TSourceFileEditor.Create(CurEditor);
  try
    FileEditor.Prepare;
    for Item in ListToImport do
      FileEditor.AddUnit(Item);
  finally
    FileEditor.Free;
  end;
  ListToImport.Free;
  {$IFDEF FPC}Windows.{$ENDIF}SetFocus(OldFocus);
end;

function TEnvironmentController.IsLibraryPathsUnitReady: Boolean;
begin
  Result := (FLibraryPath <> nil) and (FLibraryPath.Ready);
end;

function TEnvironmentController.IsProjectsUnitReady: Boolean;
begin
  Result := (FProjectUnits <> nil) and (FProjectUnits.Ready);
end;

procedure TEnvironmentController.LoadLibraryPath;
var
  LocalThread: TThread;
  OldLibraryPath: TUnits;
begin
  Logger.Debug('TEnvironmentController.LoadLibraryPath');
  if FLibraryPathLoading then
  begin
    Logger.Debug('TEnvironmentController.LoadLibraryPath: already loading');
    Exit;
  end;
  if (FLibraryPath <> nil) and (not FLibraryPath.Ready) then
  begin
    Logger.Debug('TEnvironmentController.LoadLibraryPath: no');
    Exit;
  end;
  Logger.Debug('TEnvironmentController.LoadLibraryPath: yes');

  FLibraryPathLoading := True;

  OldLibraryPath := nil;
  if FLibraryPath <> nil then
  begin
    OldLibraryPath := FLibraryPath.Units;
    FLibraryPath.Units := nil;
    FLibraryPath.Ready := False;
  end;

{$IFDEF FPC}
  // FPC port: closures (anonymous functions) are not supported by FPC 3.2.2,
  // so the library scan runs synchronously. The worker itself is sequential.
  try
    CreateLibraryPathUnits(OldLibraryPath);
  finally
    FLibraryPathLoading := False;
  end;
{$ELSE}
  LocalThread := CreateBackgroundThread(
    procedure
    begin
      try
        CreateLibraryPathUnits(OldLibraryPath);
      finally
        FLibraryPathLoading := False;
      end;
    end
    );
  LocalThread.FreeOnTerminate := True;
  LocalThread.Start;
{$ENDIF}
end;

procedure TEnvironmentController.AddFilesFromProjectSearchPaths(
  Files: TDictionary<string, TFileInfo>;
  SearchPaths: TStringList
);
var
  I: Integer;
  DirFiles: TDictionary<string, TFileInfo>;
  FileInfo: TFileInfo;
begin
  try
    for I := 0 to SearchPaths.Count - 1 do
    begin
      if not DirectoryExists(SearchPaths[I]) then
        Continue;

      DirFiles := GetAllPasFilesFromPathRecursive(SearchPaths[I]);
      try
        for FileInfo in DirFiles.Values do
          Files.AddOrSetValue(FileInfo.Path, FileInfo);
      finally
        DirFiles.Free;
      end;
    end;
  except
    on E: Exception do
      Logger.Error('TEnvironmentController.AddFilesFromProjectSearchPaths: ' + E.Message);
  end;
end;

procedure TEnvironmentController.LoadProjectPath(AWaitForProject: Boolean);
var
  LocalThread: TThread;
  OldFiles: TUnits;
  Files: TDictionary<string, TFileInfo>;
  DprojPaths: TStringList;
  WaitCount: Integer;
begin
  Logger.Debug('TEnvironmentController.LoadProjectPath');
  if FProjectPathLoading then
  begin
    Logger.Debug('TEnvironmentController.LoadProjectPath: already loading');
    Exit;
  end;

  if {$IFDEF FPC}not IsProjectOpened{$ELSE}GetCurrentProject = nil{$ENDIF} then
  begin
    if AWaitForProject then
    begin
      WaitCount := 0;
      while ({$IFDEF FPC}not IsProjectOpened{$ELSE}GetCurrentProject = nil{$ENDIF}) and (WaitCount < 20) do
      begin
        Sleep(100);
        Inc(WaitCount);
      end;
    end;
    if {$IFDEF FPC}not IsProjectOpened{$ELSE}GetCurrentProject = nil{$ENDIF} then
      Exit;
  end;

  Logger.Debug('TEnvironmentController.LoadProjectPath: yes');

  FProjectPathLoading := True;

  OldFiles := nil;
  if FProjectUnits <> nil then
  begin
    OldFiles := FProjectUnits.Units;
    FProjectUnits.Units := nil;
    FProjectUnits.Ready := False;
  end;

  Files := GetAllFilesFromProjectGroup;
  DprojPaths := GetProjectSearchPathsFromDproj;

{$IFDEF FPC}
  // FPC port: closures are not supported, so the project scan runs
  // synchronously (the worker itself is sequential).
  try
    AddFilesFromProjectSearchPaths(Files, DprojPaths);
    CreateProjectPathUnits(Files, OldFiles);
  finally
    DprojPaths.Free;
    FProjectPathLoading := False;
  end;
{$ELSE}
  LocalThread := CreateBackgroundThread(
    procedure
    begin
      CoInitialize(nil);
      try
        AddFilesFromProjectSearchPaths(Files, DprojPaths);
        CreateProjectPathUnits(Files, OldFiles);
      finally
        DprojPaths.Free;
        CoUninitialize;
        FProjectPathLoading := False;
      end;
    end
    );
  LocalThread.FreeOnTerminate := True;
  LocalThread.Start;
{$ENDIF}
end;

procedure TEnvironmentController.OnFinishedLibraryPathScan(FindUnits: TUnits);
begin
  FLibraryPath.Units := FindUnits;
  FLibraryPath.Ready := True;
end;

procedure TEnvironmentController.OnFinishedProjectPathScan(FindUnits: TUnits);
begin
  if FProjectUnits = nil then
  begin
    Exit;
  end;

  FProjectUnits.Units := FindUnits;
  FProjectUnits.Ready := True;
end;

procedure TEnvironmentController.OrganizeUses;
var
  FileEditor: TSourceFileEditor;
  CurEditor: IOTASourceEditor;
begin
  CurEditor := OtaGetCurrentSourceEditor;
  if CurEditor = nil then Exit;

  FileEditor := TSourceFileEditor.Create(CurEditor);
  try
    FileEditor.Prepare;
    FileEditor.OrganizeUsesImplementation;
    FileEditor.Prepare;
    FileEditor.OrganizeUsesInterface;
  finally
    FileEditor.Free;
  end;
end;

function TEnvironmentController.PasExists(PasName: string): Boolean;
begin
  Result := False;
  if Assigned(FProjectUnits) and (FProjectUnits.Ready) then
    if FProjectUnits.Units.FileExists(PasName) then
      Exit(True);

  if Assigned(FLibraryPath) and (FLibraryPath.Ready) then
    if FLibraryPath.Units.FileExists(PasName) then
      Exit(True);
end;

function TEnvironmentController.IsFileIndexed(FilePath: string): Boolean;
begin
  Result := False;
  if Assigned(FProjectUnits) and FProjectUnits.Ready then
    if FProjectUnits.ContainsFilePath(FilePath) then
      Exit(True);

  if Assigned(FLibraryPath) and FLibraryPath.Ready then
    if FLibraryPath.ContainsFilePath(FilePath) then
      Exit(True);
end;

procedure TEnvironmentController.ProcessDCUFiles;
var
  LocalThread: TThread;
begin
{$IFDEF FPC}
  // There are no DCU files in Lazarus (only .ppu). Nothing to process.
  FProcessingDCU := False;
{$ELSE}
  LocalThread := CreateBackgroundThread(
    procedure
    begin
      CallProcessDcuFiles;
    end
    );
  LocalThread.FreeOnTerminate := True;
  LocalThread.Start;
{$ENDIF}
end;

function TEnvironmentController.AreDependenciasReady: Boolean;
begin
  Result := IsProjectsUnitReady and IsLibraryPathsUnitReady;
end;

{$IFNDEF FPC}
procedure TEnvironmentController.CallProcessDcuFiles;
var
  Paths: TStringList;
  Files: TDictionary<string, TFileInfo>;
  EnvironmentOptions: IOTAEnvironmentOptions;
  DcuProcess: TParserWorker;
  Items: TObject;
  WaitCount: Integer;
begin
  FProcessingDCU := True;

  WaitCount := 0;
  while (BorlandIDEServices as IOTAServices) = nil do
  begin
    Sleep(1000);
    Inc(WaitCount);
    if WaitCount >= 30 then
    begin
      Logger.Error('TEnvironmentController.CallProcessDcuFiles: IOTAServices not available after 30s');
      FProcessingDCU := False;
      Exit;
    end;
  end;

  Paths := TStringList.Create;
  Paths.Delimiter := ';';
  Paths.StrictDelimiter := True;
  EnvironmentOptions := (BorlandIDEServices as IOTAServices).GetEnvironmentOptions;
  Paths.DelimitedText := EnvironmentOptions.Values['LibraryPath'] + ';' + EnvironmentOptions.Values['BrowsingPath'];

  Files := nil;
  DcuProcess := TParserWorker.Create(Paths, Files, nil);
  DcuProcess.ParseDcuFile := True;
  Items := DcuProcess.Start;
  DcuProcess.Free;
  Items.Free;
  FProcessingDCU := False;
end;
{$ENDIF}

{$IFNDEF FPC}
procedure TEnvironmentController.ProjectClosing(const ProjectOrGroup: IOTAModule);
begin
  Logger.Debug('TEnvironmentController.ProjectClosing');
  if FProjectUnits <> nil then
  begin
    FProjectUnits.Ready := False;
    FProjectUnits.Units := nil;
  end;
end;

procedure TEnvironmentController.ProjectLoaded(const ProjectOrGroup: IOTAModule; const Node: IXMLNode);
begin
  Logger.Debug('TEnvironmentController.ProjectLoaded');
  if FProjectUnits = nil then
    Exit;
  if not FProjectUnits.Ready then
    LoadProjectPath;
end;

procedure TEnvironmentController.ProjectSaving(const ProjectOrGroup: IOTAModule; const Node: IXMLNode);
begin
  Logger.Debug('TEnvironmentController.ProjectSaving');
end;
{$ENDIF}

end.

