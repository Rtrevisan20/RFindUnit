unit HDFindUnit.View.FormSearch;

interface

uses
  HDFindUnit.Controller.EnvironmentController,
  HDFindUnit.Model.FileEditor,
  HDFindUnit.Model.Header,
  HDFindUnit.Model.Interf.Translation,
  HDFindUnit.Model.Translation,
{$IFNDEF FPC}
  HDFindUnit.View.FormSettings,
{$ENDIF}
  Classes,
  Buttons,
  Controls,
  ExtCtrls,
  Forms,
  StdCtrls
{$IFDEF FPC}
  ,LCLType
{$ELSE}
  ,Vcl.AppEvnts
  ,Vcl.ImgList
  ,Winapi.Windows, System.ImageList
{$ENDIF};

type
  TFuncBoolean = function: Boolean of object;
  TFuncString = function: string of object;

  TfrmFindUnit = class(TForm)
    grpOptions: TGroupBox;
    chkSearchLibraryPath: TCheckBox;
    chkSearchProjectFiles: TCheckBox;
    grpResult: TGroupBox;
    lstResult: TListBox;
    grpSearch: TGroupBox;
    edtSearch: TEdit;
    lblWhere: TLabel;
    rbInterface: TRadioButton;
    rbImplementation: TRadioButton;
{$IFNDEF FPC}
    aevKeys: TApplicationEvents;
{$ENDIF}
    tmrLoadedItens: TTimer;
    lblProjectUnitsStatus: TLabel;
    lblLibraryUnitsStatus: TLabel;
    btnRefreshProject: TSpeedButton;
    btnRefreshLibraryPath: TSpeedButton;
    btnAdd: TButton;
{$IFNDEF FPC}
    btnProcessDCUs: TSpeedButton;
{$ENDIF}
    pnlMsg: TPanel;
    lblMessage: TLabel;
{$IFNDEF FPC}
    btnConfig: TButton;
    ilImages: TImageList;
    lblWarnDcuDecompi: TLabel;
{$ENDIF}
    procedure FormShow(Sender: TObject);
    procedure edtSearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnAddClick(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure lstResultDblClick(Sender: TObject);
    procedure edtSearchClick(Sender: TObject);
{$IFDEF FPC}
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
{$ELSE}
    procedure aevKeysMessage(var Msg: tagMSG; var Handled: Boolean);
{$ENDIF}
    procedure tmrLoadedItensTimer(Sender: TObject);
    procedure chkSearchProjectFilesClick(Sender: TObject);
    procedure chkSearchLibraryPathClick(Sender: TObject);
    procedure btnRefreshProjectClick(Sender: TObject);
    procedure btnRefreshLibraryPathClick(Sender: TObject);
{$IFNDEF FPC}
    procedure btnProcessDCUsClick(Sender: TObject);
{$ENDIF}
    procedure FormCreate(Sender: TObject);
{$IFNDEF FPC}
    procedure btnConfigClick(Sender: TObject);
{$ENDIF}
    procedure lstResultClick(Sender: TObject);
  private
    FEnvControl: TEnvironmentController;
    FFileEditor: TSourceFileEditor;
{$IFNDEF FPC}
    FfrmConfig: TfrmSettings;
{$ENDIF}

    procedure AddUnit;

{$IFDEF FPC}
    procedure ProcessKeyCommand(Key: Word; Shift: TShiftState; var Handled: Boolean);
    procedure CreateFormControls;
{$ELSE}
    procedure ProcessKeyCommand(var Msg: tagMSG; var Handled: Boolean);
{$ENDIF}

    procedure CheckLoadingStatus(
        Func: TFuncBoolean;
        FuncStatus: TFuncString;
        LabelDesc: TLabel;
        RefreshButton: TSpeedButton;
        var BecameReady: Boolean
    );
    procedure CheckLibraryStatus;
    procedure FilterItemFromSearchString;

    procedure SaveConfigs;
    procedure LoadConfigs;

    procedure SelectTheMostSelectableItem;
{$IFNDEF FPC}
    procedure ProcessDCUFiles;
    function CanProcessDCUFiles: Boolean;
{$ENDIF}
    procedure DisplayMessageToMuchResults(Show: Boolean);

    procedure LoadCurrentFile;
    procedure GetSelectedItem(out UnitName, ClassName: string);
    procedure SaveFormSettings;
    procedure ConfigureForm;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetEnvControl(EnvControl: TEnvironmentController);
    procedure SetSearch(Filter: TStringPosition);

    procedure FilterItem(const SearchString: string);

    procedure ShowTextOnScreen(Text: string);
  end;

var
  frmFindUnit: TfrmFindUnit;

implementation

uses
  HDFindUnit.Controller.OTAUtils,
  HDFindUnit.Model.ResultsImportanceCalculator,
  HDFindUnit.Model.Settings,
  HDFindUnit.Utils,
  HDFindUnit.View.FormMessage,
  Dialogs,
  Graphics,
  SysUtils
{$IFNDEF FPC}
  ,HDFindUnit.Model.DcuDecompiler
  ,ToolsAPI
  ,Winapi.Messages
  ,Winapi.ShellAPI
{$ENDIF};

{$IFNDEF FPC}
{$R *.dfm}
{$ENDIF}

const
  IDCONT = '1';

var
  CONFIG_SearchOnProjectUnits: Boolean;
  CONFIG_SearchOnLibraryPath: Boolean;

procedure TfrmFindUnit.SaveFormSettings;
var
  Settings: TSettings;
begin
  Settings := TSettings.Create;
  try
    Settings.SettingFormWidth := Self.Width;
    Settings.SettingFormHeight := Self.Height;
    Settings.SettingFormStartPosX := Self.Left;
    Settings.SettingFormStartPosY := Self.Top;
  finally
    Settings.Free;
  end;
end;

procedure TfrmFindUnit.ConfigureForm;
var
  Settings: TSettings;
begin
  Settings := TSettings.Create;
  try
    if Settings.SettingFormWidth > 0 then
      Self.Width := Settings.SettingFormWidth;

    if Settings.SettingFormHeight > 0 then
      Self.Height := Settings.SettingFormHeight;

    if Settings.SettingFormStartPosX > 0 then
      Self.Left := Settings.SettingFormStartPosX;

    if Settings.SettingFormStartPosY > 0 then
      Self.Top := Settings.SettingFormStartPosY;

{$IFNDEF FPC}
    lblWarnDcuDecompi.Visible := not Settings.RanOnceDcuDecompiler;
{$ENDIF}
  finally
    Settings.Free;
  end;
end;

procedure TfrmFindUnit.ShowTextOnScreen(Text: string);
var
  aText: string;
begin
  if rbInterface.Checked then
    aText := Translation.GetUnitAddedToInterface(Text)
  else
    aText := Translation.GetUnitAddedToImplementation(Text);
  TfrmMessage.ShowInfoToUser(aText);
  SetFocus;
end;

procedure TfrmFindUnit.AddUnit;
var
  SelectedUnit: string;
  SelectedClass: string;
begin
  GetSelectedItem(SelectedUnit, SelectedClass);
  if SelectedUnit = '' then
    Exit;

  ShowTextOnScreen(SelectedUnit);

  if rbInterface.Checked then
    FFileEditor.AddUsesToInterface(SelectedUnit)
  else
    FFileEditor.AddUsesToImplementation(SelectedUnit);

  if GlobalSettings.StoreChoices then
    FEnvControl.AutoImport.SetMemorizedUnit(SelectedClass, SelectedUnit);

  Close;
end;

{$IFDEF FPC}
procedure TfrmFindUnit.ProcessKeyCommand(Key: Word; Shift: TShiftState; var Handled: Boolean);
begin
  Handled := False;

  if Key = VK_RETURN then
  begin
    AddUnit;
    Handled := True;
  end
  else if Key = VK_ESCAPE then
  begin
    Close;
    Handled := True;
  end
  else if (Key in [VK_UP, VK_DOWN]) then
  begin
    lstResult.SetFocus;
    Handled := True;
  end
  else if (ssCtrl in Shift) and (Key = Ord('A')) then
  begin
    edtSearch.SelectAll;
    Handled := True;
  end;
end;

procedure TfrmFindUnit.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Handled: Boolean;
begin
  ProcessKeyCommand(Key, Shift, Handled);
  if Handled then
    Key := 0;
end;
{$ELSE}
procedure TfrmFindUnit.aevKeysMessage(var Msg: tagMSG; var Handled: Boolean);
begin
  if Msg.message = WM_KEYDOWN then
    ProcessKeyCommand(Msg, Handled);
end;

procedure TfrmFindUnit.ProcessKeyCommand(var Msg: tagMSG; var Handled: Boolean);
const
  MOVE_COMMANDS = [VK_UP, VK_DOWN];

  function IsCtrlA: Boolean;
  begin
    Result := (GetKeyState(VK_CONTROL) < 0) and (Char(Msg.wParam) = 'A');
  end;
begin
  if FfrmConfig <> nil then begin
    Handled := False;
    Exit;
  end;

  if (Msg.wParam in MOVE_COMMANDS) then begin
    Msg.hwnd := lstResult.Handle;
    lstResult.SetFocus;
  end
  else begin
    Msg.hwnd := edtSearch.Handle;
    edtSearch.SetFocus;

    if IsCtrlA then
      edtSearch.SelectAll;
  end;
end;
{$ENDIF}

procedure TfrmFindUnit.btnAddClick(Sender: TObject);
begin
  AddUnit;
end;

{$IFNDEF FPC}
procedure TfrmFindUnit.btnConfigClick(Sender: TObject);
begin
  FfrmConfig := TfrmSettings.Create(Self);
  FfrmConfig.ShowModal;
  FfrmConfig := nil;
end;

procedure TfrmFindUnit.btnProcessDCUsClick(Sender: TObject);
begin
  if CanProcessDCUFiles then
    ProcessDCUFiles;
end;

function TfrmFindUnit.CanProcessDCUFiles: Boolean;
const
  MESGEM =
      'O dcu32int.exe n'#227'o foi encontrado. Deve estar em %s . Se voc'#234' baixar o fonte do projeto voc'#234' vai '
          + 'encontre-o em {PATH}\RFindUnit\Thirdy\Dcu32Int\dcu32int.exe . Copie o execut'#225'vel e cole no %s, e '
          + 'tente executar este comando novamente. Se voc'#234' n'#227'o sabe onde encontrar este execut'#225'vel posso te enviar '
          + 'para a p'#225'gina do projeto, voc'#234' quer que eu abra para voc'#234' ?';
var
  ForMessage: string;
  MesDlg: TForm;
begin
  Result := True;
  if Dcu32IntExecutableExists then
    Exit;

  Result := False;

  ForMessage := GetDcu32ExecutablePath;
  ForMessage := Format(MESGEM, [ForMessage, ForMessage]);

  MesDlg := CreateMessageDialog(ForMessage, mtError, [mbCancel, mbYes]);
  try
    MesDlg.Width := 900;
    MesDlg.Position := poScreenCenter;
    MesDlg.ShowModal;

    if MesDlg.ModalResult <> mrYes then
      Exit;

  finally
    MesDlg.Free;
  end;

  ShellExecute(0, 'open', PChar('https://github.com/rfrezino/RFindUnit/'), nil, nil, SW_SHOWNORMAL);
end;

procedure TfrmFindUnit.ProcessDCUFiles;
var
  Settings: TSettings;
begin
  if MessageDlg(Translation.GetDCUConfirmMessage, mtWarning, [mbCancel, mbYes], 0) <> mrYes then
    Exit;

  btnProcessDCUs.Enabled := False;
  FEnvControl.ProcessDCUFiles;

  Settings := TSettings.Create;
  try
    Settings.RanOnceDcuDecompiler := True;
  finally
    Settings.Free;
  end;
  ConfigureForm;
end;
{$ENDIF}

procedure TfrmFindUnit.btnRefreshLibraryPathClick(Sender: TObject);
begin
  try
    FEnvControl.LoadLibraryPath;
    tmrLoadedItens.Enabled := True;
    CheckLibraryStatus;
  except
    on E: exception do begin
      MessageDlg(Translation.GetErrorRefreshLibraryPath(e.Message), mtError, [mbOK], 0);
{$IFDEF RAISEMAD}
      raise;
{$ENDIF}
    end;
  end;
end;

procedure TfrmFindUnit.btnRefreshProjectClick(Sender: TObject);
begin
  try
    FEnvControl.LoadProjectPath;
    tmrLoadedItens.Enabled := True;
    CheckLibraryStatus;
  except
    on E: exception do begin
      MessageDlg(Translation.GetErrorRefreshProject(e.Message), mtError, [mbOK], 0);
{$IFDEF RAISEMAD}
      raise;
{$ENDIF}
    end;
  end;
end;

procedure TfrmFindUnit.CheckLoadingStatus(
    Func: TFuncBoolean;
    FuncStatus: TFuncString;
    LabelDesc: TLabel;
    RefreshButton: TSpeedButton;
    var BecameReady: Boolean
);
var
  NewCaption: string;
begin
  NewCaption := '';
  if Func then begin
    if LabelDesc.Visible then
      BecameReady := True;
    RefreshButton.Visible := True;
    LabelDesc.Visible := False;
  end
  else begin
    RefreshButton.Visible := False;
    LabelDesc.Visible := True;
    NewCaption := FuncStatus;
    LabelDesc.Font.Color := $000069D2;
    LabelDesc.Font.Style := [fsItalic];
  end;

  LabelDesc.Caption := NewCaption;
end;

procedure TfrmFindUnit.chkSearchLibraryPathClick(Sender: TObject);
begin
  FilterItemFromSearchString;
end;

procedure TfrmFindUnit.chkSearchProjectFilesClick(Sender: TObject);
begin
  FilterItemFromSearchString;
end;

constructor TfrmFindUnit.Create(AOwner: TComponent);
begin
  inherited;
{$IFDEF FPC}
  CreateFormControls;
  FormCreate(Self);
{$ENDIF}
  LoadCurrentFile;
end;

{$IFDEF FPC}
procedure TfrmFindUnit.CreateFormControls;
begin
  Left := 0;
  Top := 0;
  Width := 580;
  Height := 501;
  BorderStyle := bsSizeToolWin;
  Position := poMainFormCenter;
  KeyPreview := True;
  OnKeyDown := FormKeyDown;

  grpSearch := TGroupBox.Create(Self);
  grpSearch.Parent := Self;
  grpSearch.Align := alTop;
  grpSearch.Height := 73;

  edtSearch := TEdit.Create(Self);
  edtSearch.Parent := grpSearch;
  edtSearch.Left := 16;
  edtSearch.Top := 18;
  edtSearch.Width := 330;
  edtSearch.OnChange := edtSearchChange;
  edtSearch.OnClick := edtSearchClick;
  edtSearch.OnKeyDown := edtSearchKeyDown;

  rbInterface := TRadioButton.Create(Self);
  rbInterface.Parent := grpSearch;
  rbInterface.Left := 84;
  rbInterface.Top := 45;
  rbInterface.Checked := True;

  rbImplementation := TRadioButton.Create(Self);
  rbImplementation.Parent := grpSearch;
  rbImplementation.Left := 203;
  rbImplementation.Top := 45;

  lblWhere := TLabel.Create(Self);
  lblWhere.Parent := grpSearch;
  lblWhere.Left := 16;
  lblWhere.Top := 46;

  btnAdd := TButton.Create(Self);
  btnAdd.Parent := grpSearch;
  btnAdd.Left := 482;
  btnAdd.Top := 16;
  btnAdd.Width := 85;
  btnAdd.Height := 25;
  btnAdd.Anchors := [akTop, akRight];
  btnAdd.OnClick := btnAddClick;

  grpResult := TGroupBox.Create(Self);
  grpResult.Parent := Self;
  grpResult.Align := alClient;

  lstResult := TListBox.Create(Self);
  lstResult.Parent := grpResult;
  lstResult.Align := alClient;
  lstResult.OnClick := lstResultClick;
  lstResult.OnDblClick := lstResultDblClick;

  pnlMsg := TPanel.Create(Self);
  pnlMsg.Parent := grpResult;
  pnlMsg.Align := alBottom;
  pnlMsg.Height := 47;
  pnlMsg.Visible := False;

  lblMessage := TLabel.Create(Self);
  lblMessage.Parent := pnlMsg;
  lblMessage.Align := alClient;
  lblMessage.WordWrap := True;
  lblMessage.Layout := tlCenter;
  lblMessage.Font.Color := 19174;
  lblMessage.Font.Style := [fsItalic];

  grpOptions := TGroupBox.Create(Self);
  grpOptions.Parent := Self;
  grpOptions.Align := alBottom;
  grpOptions.Height := 109;

  chkSearchProjectFiles := TCheckBox.Create(Self);
  chkSearchProjectFiles.Parent := grpOptions;
  chkSearchProjectFiles.Left := 19;
  chkSearchProjectFiles.Top := 22;
  chkSearchProjectFiles.Checked := True;
  chkSearchProjectFiles.OnClick := chkSearchProjectFilesClick;

  chkSearchLibraryPath := TCheckBox.Create(Self);
  chkSearchLibraryPath.Parent := grpOptions;
  chkSearchLibraryPath.Left := 19;
  chkSearchLibraryPath.Top := 45;
  chkSearchLibraryPath.Width := 163;
  chkSearchLibraryPath.Checked := True;
  chkSearchLibraryPath.OnClick := chkSearchLibraryPathClick;

  lblProjectUnitsStatus := TLabel.Create(Self);
  lblProjectUnitsStatus.Parent := grpOptions;
  lblProjectUnitsStatus.Left := 194;
  lblProjectUnitsStatus.Top := 23;

  lblLibraryUnitsStatus := TLabel.Create(Self);
  lblLibraryUnitsStatus.Parent := grpOptions;
  lblLibraryUnitsStatus.Left := 194;
  lblLibraryUnitsStatus.Top := 46;

  btnRefreshProject := TSpeedButton.Create(Self);
  btnRefreshProject.Parent := grpOptions;
  btnRefreshProject.Left := 188;
  btnRefreshProject.Top := 18;
  btnRefreshProject.Width := 54;
  btnRefreshProject.Height := 22;
  btnRefreshProject.Flat := True;
  btnRefreshProject.Visible := False;
  btnRefreshProject.OnClick := btnRefreshProjectClick;

  btnRefreshLibraryPath := TSpeedButton.Create(Self);
  btnRefreshLibraryPath.Parent := grpOptions;
  btnRefreshLibraryPath.Left := 188;
  btnRefreshLibraryPath.Top := 42;
  btnRefreshLibraryPath.Width := 54;
  btnRefreshLibraryPath.Height := 22;
  btnRefreshLibraryPath.Flat := True;
  btnRefreshLibraryPath.OnClick := btnRefreshLibraryPathClick;

  tmrLoadedItens := TTimer.Create(Self);
  tmrLoadedItens.Interval := 100;
  tmrLoadedItens.OnTimer := tmrLoadedItensTimer;

  OnClose := FormClose;
  OnShow := FormShow;
end;
{$ENDIF}

destructor TfrmFindUnit.Destroy;
begin
  FFileEditor.Free;
  inherited;
end;

procedure TfrmFindUnit.edtSearchChange(Sender: TObject);
begin
  FilterItemFromSearchString;
end;

procedure TfrmFindUnit.edtSearchClick(Sender: TObject);
begin
  if edtSearch.Text = Translation.GetFormSearchSearchHint then
    edtSearch.SelectAll;
end;

procedure TfrmFindUnit.edtSearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) then
    AddUnit
  else if (Key = VK_ESCAPE) then
    Close;
end;

procedure TfrmFindUnit.DisplayMessageToMuchResults(Show: Boolean);
begin
  pnlMsg.Visible := Show;
  lblMessage.Caption :=
' ' + Translation.GetFormSearchTooManyResults + #13#10
+ Translation.GetFormSearchTooManyResultsHint;
end;

procedure TfrmFindUnit.FilterItem(const SearchString: string);
var
  Return: TStringList;
  ResultSearch: TStringList;
  ToMuchResults: Boolean;

  procedure IsThereToMuchResults;
  begin
    if Return.Count >= MAX_RETURN_ITEMS then
      ToMuchResults := True;
  end;
begin
  ToMuchResults := False;
  lstResult.Items.BeginUpdate;
  ResultSearch := TStringList.Create;
  try
    lstResult.Clear;
    if (SearchString = '') or (FEnvControl = nil) or (SearchString = Translation.GetFormSearchSearchHint) then
      Exit;

    if chkSearchProjectFiles.Checked then begin
      Return := FEnvControl.GetProjectUnits(SearchString);
      ResultSearch.Text := ResultSearch.Text + Return.Text;
      IsThereToMuchResults;
      Return.Free;
    end;

    if chkSearchLibraryPath.Checked then begin
      Return := FEnvControl.GetLibraryPathUnits(SearchString);
      ResultSearch.Text := ResultSearch.Text + Return.Text;
      IsThereToMuchResults;
      Return.Free;
    end;

    ResultSearch.Sorted := True;
    lstResult.Items.Text := ResultSearch.Text;

    SelectTheMostSelectableItem;
    DisplayMessageToMuchResults(ToMuchResults);
  finally
    ResultSearch.Free;
    lstResult.Items.EndUpdate;
  end;
end;

procedure TfrmFindUnit.FilterItemFromSearchString;
begin
  try
    FilterItem(edtSearch.Text);
  except
    raise
  end;
end;

procedure TfrmFindUnit.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SaveFormSettings;
  SaveConfigs;
  Action := caFree;
  frmFindUnit := nil;
end;

procedure TfrmFindUnit.FormCreate(Sender: TObject);
begin
  Caption := Translation.GetFormSearchTitle + ' - ' + VERSION_STR;
  grpOptions.Caption := Translation.GetFormSearchOptions;
  grpResult.Caption := Translation.GetFormSearchResult;
  grpSearch.Caption := Translation.GetFormSearchSearch;
  lblWhere.Caption := Translation.GetFormSearchAddTo + ':';
  edtSearch.Text := Translation.GetFormSearchSearchHint;
  btnAdd.Caption := Translation.GetFormSearchAdd;
  btnRefreshProject.Caption := Translation.GetFormSearchRefresh;
  btnRefreshLibraryPath.Caption := Translation.GetFormSearchRefresh;
{$IFNDEF FPC}
  btnProcessDCUs.Caption := Translation.GetFormSearchProcessDCU;
  lblWarnDcuDecompi.Caption := Translation.GetFormSearchDCUWarning;
{$ENDIF}
  chkSearchLibraryPath.Caption := Translation.GetFormSearchSearchLibraryPath;
  chkSearchProjectFiles.Caption := Translation.GetFormSearchSearchProject;
  ConfigureForm;
end;

procedure TfrmFindUnit.FormShow(Sender: TObject);
begin
  edtSearch.SelectAll;
  edtSearch.SetFocus;
  LoadConfigs;

  if FEnvControl <> nil then
  begin
    CheckLibraryStatus;
  end;
end;

procedure TfrmFindUnit.GetSelectedItem(out UnitName, ClassName: string);
var
  I: Integer;
begin
  UnitName := '';
  if lstResult.Count = 0 then
    Exit;

  for I := 0 to lstResult.Items.Count - 1 do begin
    if lstResult.Selected[I] then begin
      GetUnitFromSearchSelection(lstResult.Items[I], UnitName, ClassName);
      Exit;
    end;
  end;

  GetUnitFromSearchSelection(lstResult.Items[0], UnitName, ClassName);
end;

procedure TfrmFindUnit.LoadConfigs;
begin
  chkSearchLibraryPath.Checked := CONFIG_SearchOnLibraryPath;
  chkSearchProjectFiles.Checked := CONFIG_SearchOnProjectUnits;
end;

procedure TfrmFindUnit.LoadCurrentFile;
var
  CurEditor: IOTASourceEditor;
begin
  CurEditor := OtaGetCurrentSourceEditor;
  FFileEditor := TSourceFileEditor.Create(CurEditor);
  FFileEditor.Prepare;
end;

procedure TfrmFindUnit.lstResultClick(Sender: TObject);
begin
{$IFDEF DEBUG}
{$ENDIF}
end;

procedure TfrmFindUnit.lstResultDblClick(Sender: TObject);
begin
  AddUnit;
  Close;
end;

procedure TfrmFindUnit.SaveConfigs;
begin
  CONFIG_SearchOnProjectUnits := chkSearchProjectFiles.Checked;
  CONFIG_SearchOnLibraryPath := chkSearchLibraryPath.Checked;
end;

procedure TfrmFindUnit.SelectTheMostSelectableItem;
var
  Calculator: TResultImportanceCalculator;
begin
  Calculator := TResultImportanceCalculator.Create;
  try
    Calculator.Config(lstResult.Items, Trim(edtSearch.Text));
    Calculator.Process;

    if Calculator.MostRelevantIdx > -1 then
      lstResult.Selected[Calculator.MostRelevantIdx] := True;
  finally
    Calculator.Free;
  end;
end;

procedure TfrmFindUnit.SetEnvControl(EnvControl: TEnvironmentController);
begin
  FEnvControl := EnvControl;
  CheckLibraryStatus;
end;

procedure TfrmFindUnit.SetSearch(Filter: TStringPosition);
begin
  if GlobalSettings.AlwaysUseInterfaceSection then begin
    rbImplementation.Checked := False;
    rbInterface.Checked := True;
  end
  else begin
    rbInterface.Checked := not FFileEditor.IsLineOnImplementationSection(Filter.Line);
    rbImplementation.Checked := FFileEditor.IsLineOnImplementationSection(Filter.Line);
  end;

  if (Filter.Value = '') or (Pos(#13#10, Filter.Value) > 0) then
    Exit;

  edtSearch.Text := Filter.Value;
end;

procedure TfrmFindUnit.CheckLibraryStatus;
var
  BecameReady: Boolean;
begin
  BecameReady := False;
{$IFNDEF FPC}
  btnProcessDCUs.Enabled := not FEnvControl.ProcessingDCU;
{$ENDIF}
  CheckLoadingStatus(
      FEnvControl.IsProjectsUnitReady,
      FEnvControl.GetProjectPathStatus,
      lblProjectUnitsStatus,
      btnRefreshProject,
      BecameReady
  );
  CheckLoadingStatus(
      FEnvControl.IsLibraryPathsUnitReady,
      FEnvControl.GetLibraryPathStatus,
      lblLibraryUnitsStatus,
      btnRefreshLibraryPath,
      BecameReady
  );

  if FEnvControl.IsProjectsUnitReady and FEnvControl.IsLibraryPathsUnitReady then
    tmrLoadedItens.Enabled := False
  else
    tmrLoadedItens.Enabled := True;

  if BecameReady then
    FilterItemFromSearchString;
end;

procedure TfrmFindUnit.tmrLoadedItensTimer(Sender: TObject);
begin
  CheckLibraryStatus;
end;

procedure LoadInitialConfigs;
begin
  CONFIG_SearchOnProjectUnits := True;
  CONFIG_SearchOnLibraryPath := True;
end;

initialization
  LoadInitialConfigs;

end.