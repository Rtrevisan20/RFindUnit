unit HDFindUnit.Model.IncluderHandlerInc;

interface

uses
  Classes,

  Generics.Collections,

  SimpleParser.Lexer.Types;

type
  TIncItem = record
    Loaded: Boolean;
    Content: string;
    FilePath: string;
  end;

  TIncludeHandlerInc = class(TInterfacedObject, IIncludeHandler)
  private
    FIncList: TObjectDictionary<string, TIncItem>;
    FPossiblePaths: TStringList;

    procedure GenerateIncList;
  public
    constructor Create(const PossiblePaths: string);
    destructor Destroy; override;

    procedure Process;

    function GetIncludeFileContent(const ParentFileName, IncludeName: string;
      out Content: string; out FileName: string): Boolean;
  end;


implementation

uses
  Log4Pascal,
  SysUtils,

  HDFindUnit.Utils;

{ TIncludeHandlerInc }

constructor TIncludeHandlerInc.Create(const PossiblePaths: string);
begin
  FIncList := TObjectDictionary<string, TIncItem>.Create{([doOwnsValues])};
  FPossiblePaths := TStringList.Create;
  FPossiblePaths.Text := PossiblePaths;
end;

destructor TIncludeHandlerInc.Destroy;
begin
  FPossiblePaths.Free;
  FIncList.Free;
  inherited;
end;

procedure TIncludeHandlerInc.GenerateIncList;
var
  I: Integer;
  ItemPath: string;
  Return: TDictionary<string, TFileInfo>;
  iRet: TFileInfo;
  FileName: string;
  FilePath: string;
  IncItem: TIncItem;
begin
  for I := 0 to FPossiblePaths.Count -1 do
  begin
    ItemPath := IncludeTrailingPathDelimiter(FPossiblePaths[i]);
    try
      if not DirectoryExists(ItemPath) then
        Continue;

      Return := GetAllFilesFromPath(ItemPath, '*.inc');
      for iRet in Return.Values do
      begin
        FilePath := iRet.Path;
        FileName := UpperCase(ExtractFileName(FilePath));

        IncItem.Loaded := False;
        IncItem.Content := '';
        IncItem.FilePath := FilePath;

        FIncList.AddOrSetValue(FileName, IncItem);
      end;
      Return.Free
    except
      on e: exception do
      begin
        Logger.Error('TIncludeHandlerInc.GenerateIncList[%s]: %s', [ItemPath, e.Message]);
        {$IFDEF RAISEMAD} raise; {$ENDIF}
      end;
    end;
  end;
end;

function TIncludeHandlerInc.GetIncludeFileContent(const ParentFileName, IncludeName: string;
  out Content: string; out FileName: string): Boolean;
var
  ItemInc: TIncItem;
  FileInc: TStringList;
begin
  Content := '';
  FileName := '';
  Result := False;

  if not FIncList.TryGetValue(UpperCase(IncludeName), ItemInc) then
    Exit;

  if ItemInc.Loaded then
  begin
    Content := ItemInc.Content;
    FileName := ItemInc.FilePath;
    Result := True;
    Exit;
  end;

  FileInc := TStringList.Create;
  try
    try
      FileInc.LoadFromFile(ItemInc.FilePath);
      ItemInc.Content := FileInc.Text;
      ItemInc.Loaded := True;
      FIncList.AddOrSetValue(UpperCase(IncludeName), ItemInc);
    except
      Exit;
    end;
    Content := ItemInc.Content;
    FileName := ItemInc.FilePath;
    Result := True;
  finally
    FileInc.Free;
  end;
end;

procedure TIncludeHandlerInc.Process;
begin
  GenerateIncList;
end;

end.
