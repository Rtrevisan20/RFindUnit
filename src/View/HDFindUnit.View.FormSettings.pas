unit HDFindUnit.View.FormSettings;

interface

uses
  ToolsAPI,
  Data.DB,
  Datasnap.DBClient,
  HDFindUnit.Controller.OTAUtils,
  HDFindUnit.Model.Settings,
  HDFindUnit.Model.Translation,
  HDFindUnit.Model.Interf.Translation,
  System.Classes,
  System.IniFiles,
  System.SyncObjs,
  System.SysUtils,
  Vcl.Buttons,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.DBCtrls,
  Vcl.DBGrids,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Grids,
  Vcl.Mask,
  Vcl.StdCtrls,
  Winapi.ShellAPI;

type
  TfrmSettings = class(TForm)
    pgcMain: TPageControl;
    tsAutoImport: TTabSheet;
    chkAutoEnabled: TCheckBox;
    grdAutoImport: TDBGrid;
    dtsAutoImport: TDataSource;
    grpAutoSettings: TGroupBox;
    nvgAutoImport: TDBNavigator;
    tsGeneral: TTabSheet;
    grpGeneralSettings: TGroupBox;
    btn1: TButton;
    grpSearchAlgorithm: TRadioGroup;
    grpShotCuts: TGroupBox;
    chkMemorize: TCheckBox;
    chkOrganizeUses: TCheckBox;
    grpUsesOrganization: TGroupBox;
    chkAlwaysImportToInterfaceSection: TCheckBox;
    chkSortAfterAdding: TCheckBox;
    chkBreakline: TCheckBox;
    chkBlankLineBtwNamespace: TCheckBox;
    lblLink: TLabel;
    chbOrganizeUsesAfterInsertingNewUsesUnit: TCheckBox;
    medtBreakUsesLineAtPosition: TMaskEdit;
    lblBreakLineAt: TLabel;
    chbGroupNonNameSpaceUnits: TCheckBox;
    cdsAutoImport: TClientDataSet;
    cdsAutoImportIDENTIFIER: TStringField;
    cdsAutoImportUNIT: TStringField;
    btnCreateProjectConfiguration: TButton;
    tsUnusedUses: TTabSheet;
    mmoIgnoreUses: TMemo;
    chbFeatureUnusedUses: TCheckBox;
    chbDontBreakLineForNonNameSpaceUnits: TCheckBox;
    chkSortUsesByLevel: TCheckBox;
    shpUnused: TShape;
    Shape2: TShape;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    chbEnableHighlight: TCheckBox;
    lblLanguage: TLabel;
    cbbLanguage: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btn1Click(Sender: TObject);
    procedure chkBreaklineClick(Sender: TObject);
    procedure chkSortAfterAddingClick(Sender: TObject);
    procedure lblLinkClick(Sender: TObject);
    procedure pgcMainChange(Sender: TObject);
    procedure btnCreateProjectConfigurationClick(Sender: TObject);
    procedure cbbLanguageChange(Sender: TObject);
  private
    FSettings: TSettings;
    FMemorizedOpened: Boolean;

    procedure InsertAutoImportInDataSet;
    procedure InsertDataSetInAutoImport;
    procedure CreateIniFile;

    procedure SaveSettings;

    procedure ConfigureAutoImportPage;
    procedure ConfigurePages;
    procedure ToggleEnableItems;
  end;

implementation

uses
  Vcl.Dialogs,
  Winapi.Windows;

{$R *.dfm}

procedure TfrmSettings.SaveSettings;
begin
  FSettings.AutoImportEnabled := chkAutoEnabled.Checked;
  FSettings.AlwaysUseInterfaceSection := chkAlwaysImportToInterfaceSection.Checked;
  FSettings.OrganizeUses := chkOrganizeUses.Checked;
  FSettings.StoreChoices := chkMemorize.Checked;
  FSettings.BreakLine := chkBreakline.Checked;
  FSettings.SortUsesAfterAdding := chkSortAfterAdding.Checked;
  FSettings.SortUsesByLevel := chkSortUsesByLevel.Checked;
  FSettings.BlankLineBtwNameScapes := chkBlankLineBtwNamespace.Checked;
  FSettings.UseDefaultSearchMatch := grpSearchAlgorithm.ItemIndex = 0;
  FSettings.OrganizeUsesAfterAddingNewUsesUnit := chbOrganizeUsesAfterInsertingNewUsesUnit.Checked;
  FSettings.BreakUsesLineAtPosition := StrToInt(Trim(medtBreakUsesLineAtPosition.Text));
  FSettings.GroupNonNamespaceUnits := chbGroupNonNameSpaceUnits.Checked;
  FSettings.IgnoreUsesUnused := mmoIgnoreUses.Lines.CommaText;
  FSettings.EnableExperimentalFindUnusedUses := chbFeatureUnusedUses.Checked;
  FSettings.EnableUnusedUsesHighlight := chbEnableHighlight.Checked;
  FSettings.BreakLineForNonDomainUses := not chbDontBreakLineForNonNameSpaceUnits.Checked;
  FSettings.Language := cbbLanguage.ItemIndex;

  InsertDataSetInAutoImport;
end;

procedure TfrmSettings.btn1Click(Sender: TObject);
begin
  ShellExecute(Handle, nil, PChar(TSettings.SettingsFilePath), nil, nil, SW_SHOWNORMAL)
end;

procedure TfrmSettings.btnCreateProjectConfigurationClick(Sender: TObject);
begin
  ShowMessage(GetCurrentProject.FileName);
end;

procedure TfrmSettings.cbbLanguageChange(Sender: TObject);
begin
  CreateTranslation(cbbLanguage.ItemIndex);
end;

procedure TfrmSettings.chkBreaklineClick(Sender: TObject);
begin
  ToggleEnableItems;
end;

procedure TfrmSettings.chkSortAfterAddingClick(Sender: TObject);
begin
  ToggleEnableItems;
end;

procedure TfrmSettings.ToggleEnableItems;
begin
  chkBlankLineBtwNamespace.Enabled := chkBreakline.Checked and chkSortAfterAdding.Checked;
  chbGroupNonNameSpaceUnits.Enabled := chkBreakline.Checked and chkSortAfterAdding.Checked;
  chkSortUsesByLevel.Enabled := chkSortAfterAdding.Checked;
end;

procedure TfrmSettings.ConfigureAutoImportPage;
begin
  chkAutoEnabled.Checked := FSettings.AutoImportEnabled;
  chkAlwaysImportToInterfaceSection.Checked := FSettings.AlwaysUseInterfaceSection;
  chkMemorize.Checked := FSettings.StoreChoices;
  chkBreakline.Checked := FSettings.BreakLine;
  chkSortAfterAdding.Checked := FSettings.SortUsesAfterAdding;
  chkSortUsesByLevel.Checked := FSettings.SortUsesByLevel;
  chkBlankLineBtwNamespace.Checked := FSettings.BlankLineBtwNameScapes;
  chkOrganizeUses.Checked := FSettings.OrganizeUses;
  medtBreakUsesLineAtPosition.Text := IntToStr(FSettings.BreakUsesLineAtPosition);
  chbOrganizeUsesAfterInsertingNewUsesUnit.Checked := FSettings.OrganizeUsesAfterAddingNewUsesUnit;
  chbGroupNonNameSpaceUnits.Checked := FSettings.GroupNonNamespaceUnits;
  mmoIgnoreUses.Lines.CommaText := FSettings.IgnoreUsesUnused;
  chbFeatureUnusedUses.Checked := FSettings.EnableExperimentalFindUnusedUses;
  chbEnableHighlight.Checked := FSettings.EnableUnusedUsesHighlight;
  chbDontBreakLineForNonNameSpaceUnits.Checked := not FSettings.BreakLineForNonDomainUses;
  cbbLanguage.ItemIndex := FSettings.Language;

  if FSettings.UseDefaultSearchMatch then
    grpSearchAlgorithm.ItemIndex := 0
  else
    grpSearchAlgorithm.ItemIndex := 1;

  ToggleEnableItems;
end;

procedure TfrmSettings.ConfigurePages;
begin
  ConfigureAutoImportPage;
end;

procedure TfrmSettings.CreateIniFile;
begin
  FSettings := TSettings.Create;
end;

procedure TfrmSettings.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

procedure TfrmSettings.FormCreate(Sender: TObject);
begin
  cbbLanguage.Items.Add('Portugues (BR)');
  cbbLanguage.Items.Add('English');
  CreateIniFile;

  CreateTranslation(FSettings.Language);

  Caption := Translation.GetSettingsTitle;
  grpGeneralSettings.Caption := Translation.GetSettingsTitle;
  grpAutoSettings.Caption := Translation.GetSettingsTitle;
  tsGeneral.Caption := Translation.GetSettingsGeneral;
  tsAutoImport.Caption := Translation.GetSettingsAutoImport;
  tsUnusedUses.Caption := Translation.GetSettingsUnusedUses;
  grpShotCuts.Caption := Translation.GetSettingsShortcuts;
  grpUsesOrganization.Caption := Translation.GetSettingsSortHint;
  lblLanguage.Caption := Translation.GetSettingsLanguage + ':';
  chkAutoEnabled.Caption := Translation.GetSettingsEnabled;
  btn1.Caption := Translation.GetSettingsOpenConfigFile;
  chkAlwaysImportToInterfaceSection.Caption := Translation.GetSettingsAlwaysInterface;
  chkSortUsesByLevel.Caption := Translation.GetSettingsSortByLevel;
  chkSortUsesByLevel.Hint := Translation.GetSettingsSortByLevelHint;
  chkSortAfterAdding.Caption := Translation.GetSettingsSortAlphabetic;
  chkBreakline.Caption := Translation.GetSettingsBreakLine;
  chkBlankLineBtwNamespace.Caption := Translation.GetSettingsBlankLineNamespace;
  chkBlankLineBtwNamespace.Hint := Translation.GetSettingsBlankLineNamespaceHint;
  chbOrganizeUsesAfterInsertingNewUsesUnit.Caption := Translation.GetSettingsOrganizeAfterInsert;
  chbGroupNonNameSpaceUnits.Caption := Translation.GetSettingsGroupNonNamespace;
  chbGroupNonNameSpaceUnits.Hint := Translation.GetSettingsGroupNonNamespaceHint;
  chbDontBreakLineForNonNameSpaceUnits.Caption := Translation.GetSettingsDontBreakNonNamespace;
  chbDontBreakLineForNonNameSpaceUnits.Hint := Translation.GetSettingsDontBreakNonNamespaceHint;
  lblBreakLineAt.Caption := Translation.GetSettingsBreakLineAt;
  btnCreateProjectConfiguration.Caption := Translation.GetSettingsCreateProjectConfig;
  chbFeatureUnusedUses.Caption := Translation.GetSettingsExperimentalUnused;
  chbEnableHighlight.Caption := Translation.GetSettingsEnableHighlight;
  Label3.Caption := Translation.GetSettingsUnderlineMeaning;
  Label2.Caption := Translation.GetSettingsImportNotUsed;
  Label4.Caption := Translation.GetSettingsDCUNoAccess;
  grpSearchAlgorithm.Caption := Translation.GetSettingsMatchAlgorithm;
  chkMemorize.Caption := Translation.GetSettingsRememberChoices;
  chkOrganizeUses.Caption := Translation.GetSettingsOrganizeUses;

  ConfigurePages;
end;

procedure TfrmSettings.FormDestroy(Sender: TObject);
begin
  SaveSettings;
  TSettings.ReloadSettings;
  CreateTranslation(GlobalSettings.Language);
  FSettings.Free;
end;

procedure TfrmSettings.InsertAutoImportInDataSet;
var
  Values: TStrings;
  I: Integer;
begin
  FMemorizedOpened := True;
  Values := FSettings.AutoImportValue;
  try
    if Values = nil then
      Exit;

    if not cdsAutoImport.Active then
      cdsAutoImport.CreateDataSet;

    for I := 0 to Values.Count - 1 do begin
      cdsAutoImport.Append;
      cdsAutoImportIDENTIFIER.AsString := Values.Names[i];
      cdsAutoImportUNIT.AsString := Values.ValueFromIndex[i];
      cdsAutoImport.Post;
    end;

    with cdsAutoImport.IndexDefs.AddIndexDef do begin
      Name := cdsAutoImportIDENTIFIER.FieldName + 'Idx';
      Fields := cdsAutoImportIDENTIFIER.FieldName;
      Options := [ixCaseInsensitive];
    end;
    cdsAutoImport.IndexName := cdsAutoImportIDENTIFIER.FieldName + 'Idx';
  finally
    Values.Free;
  end;
end;

procedure TfrmSettings.InsertDataSetInAutoImport;
var
  Values: TStrings;
begin
  if not FMemorizedOpened then
    Exit;

  Values := TStringList.Create;
  cdsAutoImport.DisableControls;
  try
    cdsAutoImport.First;
    while not cdsAutoImport.Eof do begin
      Values.Values[UpperCase(cdsAutoImportIDENTIFIER.AsString)] := cdsAutoImportUNIT.AsString;
      cdsAutoImport.Next;
    end;
    FSettings.AutoImportValue := Values;
  finally
    Values.Free;
  end;
end;

procedure TfrmSettings.lblLinkClick(Sender: TObject);
var
  Link: string;
begin
  Link := 'https://github.com/rfrezino/RFindUnit';
  ShellExecute(Application.Handle, PChar('open'), PChar(Link), nil, nil, SW_SHOW);
end;

procedure TfrmSettings.pgcMainChange(Sender: TObject);
begin
  if not FMemorizedOpened then
    InsertAutoImportInDataSet;
end;

end.
