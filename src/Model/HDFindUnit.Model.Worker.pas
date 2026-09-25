unit HDFindUnit.Model.Worker;

interface

uses
  Log4Pascal,
{$IFNDEF FPC}
  HDFindUnit.Model.DcuDecompiler,
{$ENDIF}
  HDFindUnit.Model.FileCache,
  HDFindUnit.Model.Header,
  HDFindUnit.Model.IncluderHandlerInc,
  HDFindUnit.Model.PasParser,
  HDFindUnit.Utils,
  SimpleParser.Lexer.Types,
  Classes,
  DateUtils,
  Generics.Collections,
  SysUtils,
{$IFNDEF FPC}
  System.Threading;
{$ELSE}
  SyncObjs;
{$ENDIF}

type
  TOnFinished = procedure(FindUnits: TUnits) of object;

  TParserWorker = class(TObject)
  private
    FDirectoriesPath: TStringList;
    FPasFiles: TDictionary<string, TFileInfo>;
    FFindUnits: TUnits;
    FIncluder: IIncludeHandler;
    FParsedItems: Integer;
    FCacheFiles: TUnits;

    FDcuFiles: TStringList;
    FParseDcuFile: Boolean;
    FCallBack: TOnFinished;

    procedure ListPasFiles;
    procedure ListDcuFiles;

    procedure ListPasFilesFromDir(const Index: Integer; const ResultList: TThreadList<TFileInfo>);
    procedure ParseFileFromList(const Index: Integer; const ItemsToParser: TList<TFileInfo>; const ResultList: TThreadList<TPasFile>);

    procedure RemoveDcuFromExistingPasFiles;
    procedure GeneratePasFromDcus;
    procedure ParseFilesParallel;
    function GetItemsToParse: Integer;
    procedure RunTasks;
    procedure FreeGeneratedPas;

    function MustContinue: Boolean;
  public
    constructor Create(var DirectoriesPath: TStringList; var Files: TDictionary<string, TFileInfo>; Chache: TUnits);
    destructor Destroy; override;

    procedure Start(CallBack: TOnFinished); overload;
    function Start: TUnits; overload;

    property ItemsToParse: Integer read GetItemsToParse;
    property ParsedItems: Integer read FParsedItems;

    property ParseDcuFile: Boolean read FParseDcuFile write FParseDcuFile;

    procedure RemoveCallBack;
  end;

implementation

uses
{$IFNDEF FPC}
  Winapi.Windows;
{$ELSE}
  Windows;
{$ENDIF}

{ TParserWorker }

constructor TParserWorker.Create(
    var DirectoriesPath: TStringList;
    var Files: TDictionary<string, TFileInfo>;
    Chache: TUnits
);
var
  InfoFiles: TFileInfo;
begin
  FCacheFiles := Chache;
  FDirectoriesPath := TStringList.Create;
  if DirectoriesPath <> nil then
    FDirectoriesPath.Text := TPathConverter.ConvertPathsToFullPath(DirectoriesPath.Text);
  FreeAndNil(DirectoriesPath);

  FPasFiles := TDictionary<string, TFileInfo>.Create;
  if Files <> nil then
    for InfoFiles in Files.Values do
      FPasFiles.Add(InfoFiles.Path, InfoFiles);
  Files.Free;

  FDcuFiles := TStringList.Create;
  FDcuFiles.Sorted := True;
  FDcuFiles.Duplicates := dupIgnore;

  FFindUnits := TUnits.Create;

  FIncluder := TIncludeHandlerInc.Create(FDirectoriesPath.Text) as IIncludeHandler;
end;

destructor TParserWorker.Destroy;
var
  Step: string;
  Files: TObject;
begin
  try
    Step := 'FPasFiles';
    FPasFiles.Free;
    Step := 'FDirectoriesPath';
    FDirectoriesPath.Free;
    Step := 'FOldItems';

    if Assigned(FCacheFiles) then
      for Files in FCacheFiles.Values do
        Files.Free;

    FCacheFiles.Free;
    Step := 'FDcuFiles';
    //  FIncluder.Free; //Weak reference
    FDcuFiles.Free;
  except
    on E: exception do begin
      Logger.Error('TParserWorker.Destroy ' + Step);
    end;
  end;
  inherited;
end;

procedure TParserWorker.FreeGeneratedPas;
var
  Files: TPasFile;
begin
  if Assigned(FFindUnits) then
    for Files in FFindUnits.Values do
      Files.Free;
end;

function TParserWorker.GetItemsToParse: Integer;
begin
  Result := 0;
  if (FPasFiles <> nil) then
    Result := FPasFiles.Count;
end;

procedure TParserWorker.GeneratePasFromDcus;
{$IFDEF FPC}
begin
  // DCU decompilation is not available on Lazarus (no .dcu files)
end;
{$ELSE}
var
  DcuDecompiler: TDcuDecompiler;
begin
  if not FParseDcuFile then
    Exit;

  DcuDecompiler := TDcuDecompiler.Create;
  try
    DcuDecompiler.ProcessFiles(FDcuFiles);
  finally
    DcuDecompiler.Free;
  end;
end;
{$ENDIF}

procedure TParserWorker.ListDcuFiles;
{$IFDEF FPC}
begin
  // DCU decompilation is not available on Lazarus (no .dcu files)
end;
{$ELSE}
var
  ResultList: TThreadList<string>;
  DcuFile: string;
begin
  if not FParseDcuFile then
    Exit;

  FDirectoriesPath.Add(DirRealeaseWin32);
  ResultList := TThreadList<string>.Create;

  TParallel.&For(
      0,
      FDirectoriesPath.Count - 1,
      procedure(index: Integer)
      var
        DcuFiles: TDictionary<string, TFileInfo>;
        DcuFile: TFileInfo;
      begin
        try
          DcuFiles := GetAllDcuFilesFromPath(FDirectoriesPath[index]);
          try
            for DcuFile in DcuFiles.Values do
              ResultList.Add(Trim(DcuFile.Path));
          finally
            DcuFiles.Free;
          end;
        except
          on E: exception do begin
            Logger.Error('TParserWorker.ListDcuFiles: ' + e.Message);
{$IFDEF RAISEMAD}
            raise;
{$ENDIF}
          end;
        end;
      end
  );

  for DcuFile in ResultList.LockList do
    FDcuFiles.Add(DcuFile);

  ResultList.Free;
end;
{$ENDIF}

procedure TParserWorker.ListPasFilesFromDir(const Index: Integer;
    const ResultList: TThreadList<TFileInfo>);
var
  PasFiles: TDictionary<string, TFileInfo>;
  PasFile: TFileInfo;
begin
  try
    if not DirectoryExists(FDirectoriesPath[Index]) then
      Exit;

    PasFiles := GetAllPasFilesFromPath(FDirectoriesPath[Index]);
    try
      for PasFile in PasFiles.Values do
        ResultList.Add(PasFile);
    finally
      PasFiles.Free;
    end;
  except
    on E: exception do begin
      Logger.Error('TParserWorker.ListPasFiles: ' + e.Message);
{$IFDEF RAISEMAD}
      raise;
{$ENDIF}
    end;
  end;
end;

procedure TParserWorker.ListPasFiles;
var
  ResultList: TThreadList<TFileInfo>;
  PasValue: TFileInfo;
{$IFDEF FPC}
  I: Integer;
{$ENDIF}
begin
  if FPasFiles.Count > 0 then
    Exit;

  ResultList := TThreadList<TFileInfo>.Create;

{$IFDEF FPC}
  for I := 0 to FDirectoriesPath.Count - 1 do
    ListPasFilesFromDir(I, ResultList);
{$ELSE}
  TParallel.&For(
      0,
      FDirectoriesPath.Count - 1,
      procedure(index: Integer)
      begin
        ListPasFilesFromDir(index, ResultList);
      end
  );
{$ENDIF}

  for PasValue in ResultList.LockList do
    FPasFiles.AddOrSetValue(PasValue.Path, PasValue);
  ResultList.Free;

  Logger.Debug('TParserWorker.ListPasFiles: %d .pas files found in %d paths', [FPasFiles.Count, FDirectoriesPath.Count]);
end;

function TParserWorker.MustContinue: Boolean;
begin
  Result := Assigned(FCallBack);
end;

procedure TParserWorker.ParseFileFromList(const Index: Integer;
    const ItemsToParser: TList<TFileInfo>; const ResultList: TThreadList<TPasFile>);
var
  Parser: TPasFileParser;
  Item: TPasFile;
  Step: string;
begin
  try
    if (not vSystemRunning) or (not MustContinue) then
      Exit;

    Step := 'InterlockedIncrement(FParsedItems);';
    InterlockedIncrement(FParsedItems);
    Step := 'Create';
    Parser := TPasFileParser.Create(ItemsToParser[Index].Path);
    try
      Step := 'Parser.SetIncluder(FIncluder)';
      Parser.SetIncluder(FIncluder);
      Step := 'Parser.Process';
      Item := Parser.Process;
    finally
      Parser.Free;
    end;

    if Item <> nil then begin
      Item.LastModification := ItemsToParser[Index].LastAccess;
      Item.FilePath := ItemsToParser[Index].Path;
      ResultList.Add(Item);
    end;
  except
    on e: exception do begin
      Logger.Error('TParserWorker.ParseFiles[%s]: %s', [Step, e.Message]);
{$IFDEF RAISEMAD}
      raise;
{$ENDIF}
    end;
  end;
end;

procedure TParserWorker.ParseFilesParallel;
var
  ResultList: TThreadList<TPasFile>;
  PasValue: TPasFile;
  ItemsToParser: TList<TFileInfo>;
  CurFileInfo: TFileInfo;
  MilliBtw: Int64;
  OldParsedFile: TPasFile;
  Item: TPasFile;
{$IFDEF FPC}
  I: Integer;
{$ENDIF}
begin
  ResultList := TThreadList<TPasFile>.Create;
  FParsedItems := 0;

  Logger.Debug('TParserWorker.ParseFiles: Starting parseing files.');

  if FCacheFiles = nil then
    Logger.Debug('TParserWorker.ParseFiles: no cache files')
  else
    Logger.Debug('TParserWorker.ParseFiles: found cache files');

  ItemsToParser := TList<TFileInfo>.Create;
  try
    if FCacheFiles <> nil then begin
      for CurFileInfo in FPasFiles.Values do begin

        if FCacheFiles.TryGetValue(CurFileInfo.Path, OldParsedFile) then begin
          MilliBtw := MilliSecondsBetween(CurFileInfo.LastAccess, OldParsedFile.LastModification);
          if MilliBtw <= 1000 then begin
            InterlockedIncrement(FParsedItems);
            Item := FCacheFiles.ExtractPair(CurFileInfo.Path).Value;
            FFindUnits.Add(Item.FilePath, Item);
            Continue;
          end
          else begin
            Logger.Debug('TParserWorker.ParseFiles[Out of date]: %d millis btw | %s', [MilliBtw, CurFileInfo.Path]);
            ItemsToParser.Add(CurFileInfo);
          end;
        end
        else begin
          Logger.Debug('TParserWorker.ParseFiles[New file]: %s', [CurFileInfo.Path]);
          ItemsToParser.Add(CurFileInfo);
        end;
      end;
    end
    else begin
      for CurFileInfo in FPasFiles.Values do
        ItemsToParser.Add(CurFileInfo);
    end;

    {$IFDEF FPC}
    for I := 0 to ItemsToParser.Count - 1 do
      ParseFileFromList(I, ItemsToParser, ResultList);
{$ELSE}
    TParallel.&For(
        0,
        ItemsToParser.Count - 1,
        procedure(index: Integer)
        begin
          ParseFileFromList(index, ItemsToParser, ResultList);
        end
    );
{$ENDIF}

    Logger.Debug('TParserWorker.ParseFiles: Put results together.');
    for PasValue in ResultList.LockList do begin
      FFindUnits.Add(PasValue.FilePath, PasValue);
    end;

    Logger.Debug('TParserWorker.ParseFiles: Finished.');

    ResultList.Free;
  finally
    ItemsToParser.Free;
  end;
end;

procedure TParserWorker.RemoveCallBack;
begin
  FCallBack := nil;
end;

procedure TParserWorker.RemoveDcuFromExistingPasFiles;
var
  PasFilesName: TStringList;
  I: Integer;
  PasFile: string;
  DcuFile: string;
  PasFileIn: TFileInfo;
begin
  if FDcuFiles.Count = 0 then
    Exit;

  PasFilesName := TStringList.Create;
  PasFilesName.Sorted := True;
  PasFilesName.Duplicates := dupIgnore;
  try
    for PasFileIn in FPasFiles.Values do begin
      PasFile := PasFileIn.Path;
      PasFile := UpperCase(ExtractFileName(PasFile));
      PasFile := StringReplace(PasFile, '.PAS', '', [rfReplaceAll]);
      PasFilesName.Add(PasFile);
    end;

    for I := FDcuFiles.Count - 1 downto 0 do begin
      DcuFile := FDcuFiles[i];
      DcuFile := UpperCase(ExtractFileName(DcuFile));
      DcuFile := StringReplace(DcuFile, '.DCU', '', [rfReplaceAll]);

      if PasFilesName.IndexOf(DcuFile) > -1 then
        FDcuFiles.Delete(I);
    end;
  finally
    PasFilesName.Free;
  end;
end;

function TParserWorker.Start: TUnits;
begin
  RunTasks;
  Result := FFindUnits;
end;

procedure TParserWorker.RunTasks;
var
  Step: string;

  procedure OutPutStep(CurStep: string);
  begin
    Step := CurStep;
    Logger.Debug('TParserWorker.RunTasks: ' + CurStep);
  end;
begin
  try
OutPutStep('FIncluder.Process');
    FIncluder.Process;
    OutPutStep('ListPasFiles');
    ListPasFiles;
    OutPutStep('ListDcuFiles');
    ListDcuFiles;
    OutPutStep('RemoveDcuFromExistingPasFiles');
    RemoveDcuFromExistingPasFiles;
    OutPutStep('GeneratePasFromDcus');
    GeneratePasFromDcus;
    OutPutStep('ParseFiles');
    ParseFilesParallel;
    OutPutStep('Finished');
  except
    on E: exception do begin
      Logger.Error('TParserWorker.RunTasks[%s]: %s ', [Step, e.Message]);
{$IFDEF RAISEMAD}
      raise;
{$ENDIF}
    end;
  end;
end;

procedure TParserWorker.Start(CallBack: TOnFinished);
begin
  FCallBack := CallBack;
  RunTasks;

  //Must check because of threads
  if Assigned(FCallBack) then
    FCallBack(FFindUnits)
  else
    FreeGeneratedPas;

end;

end.
