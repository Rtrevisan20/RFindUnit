unit HDFindUnit.Controller.Lazarus;

interface

uses
  Classes,
  IDECommands,
  MenuIntf,
  LCLType,
  SrcEditorIntf,
  SysUtils,
  HDFindUnit.Controller.EnvironmentController,
  HDFindUnit.Controller.OTAUtils,
  HDFindUnit.Model.Header,
  HDFindUnit.Model.Interf.Translation,
  HDFindUnit.Model.Settings,
  HDFindUnit.Model.Translation,
  HDFindUnit.View.FormMessage,
  HDFindUnit.View.FormSearch,
  HDFindUnit.Utils;

procedure RegisterHDFindUnit;

implementation

type
  TRFindUnitLazarusMain = class
  private
    FEnvControl: TEnvironmentController;
    procedure OpenFindUnit(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
  end;

var
  RFindUnitLazarusMain: TRFindUnitLazarusMain = nil;

procedure RegisterHDFindUnit;
var
  Category: TIDECommandCategory;
  Command: TIDECommand;
begin
  RFindUnitLazarusMain := TRFindUnitLazarusMain.Create;

  Category := RegisterIDECommandCategory(nil, 'HDFindUnit', 'RFindUnit');
  Command := RegisterIDECommand(
    Category,
    'HDFindUnit.FindUnit',
    Translation.GetMenuTitle,
    VK_A,
    [ssCtrl, ssShift],
    RFindUnitLazarusMain.OpenFindUnit
  );

  RegisterIDEMenuCommand(itmCustomTools, 'HDFindUnitFindUnit', Translation.GetMenuTitle,
    nil, nil, Command);
end;

constructor TRFindUnitLazarusMain.Create;
begin
  inherited Create;
  FEnvControl := nil;
  TSettings.ReloadSettings;
end;

destructor TRFindUnitLazarusMain.Destroy;
begin
  FEnvControl.Free;
  inherited Destroy;
end;

procedure TRFindUnitLazarusMain.OpenFindUnit(Sender: TObject);
var
  SelectedText: TStringPosition;
  ActiveEdit: TSourceEditorInterface;
begin
  if FEnvControl = nil then
    FEnvControl := TEnvironmentController.Create;

  FEnvControl.ForceLoadProjectPath;

  SelectedText.Value := '';
  SelectedText.Line := -1;
  if SourceEditorManagerIntf <> nil then begin
    ActiveEdit := SourceEditorManagerIntf.ActiveEditor;
    if (ActiveEdit <> nil) and ActiveEdit.SelectionAvailable then
      SelectedText.Value := Trim(ActiveEdit.Selection);
  end;

  if SelectedText.Value = '' then
    SelectedText := GetWordAtCursor;

  if frmFindUnit = nil then begin
    frmFindUnit := TfrmFindUnit.Create(nil);
    frmFindUnit.SetEnvControl(FEnvControl);
    frmFindUnit.SetSearch(SelectedText);
    frmFindUnit.Show;
  end;
end;

end.