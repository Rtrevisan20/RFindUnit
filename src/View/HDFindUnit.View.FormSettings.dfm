object frmSettings: TfrmSettings
  Left = 0
  Top = 0
  BorderStyle = bsSizeToolWin
  Caption = 'Configura'#231#245'es'
  ClientHeight = 437
  ClientWidth = 691
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poOwnerFormCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 13
  object pgcMain: TPageControl
    Left = 0
    Top = 0
    Width = 691
    Height = 437
    ActivePage = tsGeneral
    Align = alClient
    TabOrder = 0
    StyleName = 'Windows'
    OnChange = pgcMainChange
    object tsGeneral: TTabSheet
      Caption = 'Geral'
      ImageIndex = 1
      object grpGeneralSettings: TGroupBox
        Left = 0
        Top = 0
        Width = 683
        Height = 409
        Align = alClient
        Caption = 'Configura'#231#245'es'
        TabOrder = 0
        object lblLink: TLabel
          Left = 242
          Top = 387
          Width = 181
          Height = 13
          Cursor = crHandPoint
          Caption = 'https://github.com/rfrezino/RFindUnit'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clBlue
          Font.Height = -11
          Font.Name = 'Tahoma'
          Font.Style = [fsItalic, fsUnderline]
          ParentFont = False
          OnClick = lblLinkClick
        end
        object shpUnused: TShape
          Left = 368
          Top = 190
          Width = 23
          Height = 17
          Brush.Color = 33023
        end
        object Shape2: TShape
          Left = 368
          Top = 213
          Width = 23
          Height = 17
          Brush.Color = clSilver
        end
        object Label2: TLabel
          Left = 397
          Top = 192
          Width = 118
          Height = 13
          Caption = 'Importa'#231#227'o n'#227'o utilizada'
        end
        object Label3: TLabel
          Left = 357
          Top = 172
          Width = 173
          Height = 13
          Caption = 'Significado das cores do sublinhado:'
        end
        object lblLanguage: TLabel
          Left = 335
          Top = 300
          Width = 36
          Height = 13
          Caption = 'Idioma:'
        end
        object Label4: TLabel
          Left = 397
          Top = 215
          Width = 276
          Height = 65
          Caption = 
            'Sem acesso ao pas, provavelmente '#233' um arquivo dcu que'#10'foi adicio' +
            'nado no caminho da biblioteca.'#10'Para corrigi-lo, clique no bot'#227'o'#10 +
            '"Processar arquivos DCUs do caminho da biblioteca"'#10'Na tela de pe' +
            'squisa'
        end
        object cbbLanguage: TComboBox
          Left = 335
          Top = 319
          Width = 145
          Height = 21
          Style = csDropDownList
          TabOrder = 6
          OnChange = cbbLanguageChange
        end
        object grpSearchAlgorithm: TRadioGroup
          Left = 335
          Top = 20
          Width = 297
          Height = 81
          Caption = 'Algoritmo de busca por correspond'#234'ncia'
          Items.Strings = (
            'Default'
            'Levenshtein')
          TabOrder = 1
        end
        object grpShotCuts: TGroupBox
          Left = 15
          Top = 20
          Width = 297
          Height = 77
          Caption = 'Atalhos'
          TabOrder = 0
          object chkMemorize: TCheckBox
            Left = 12
            Top = 13
            Width = 274
            Height = 28
            Caption = 
              'Armazene op'#231#245'es para usar na importa'#231#227'o autom'#225'tica (Ctrl + Shift' +
              ' + I)'
            Checked = True
            State = cbChecked
            TabOrder = 0
            WordWrap = True
          end
          object chkOrganizeUses: TCheckBox
            Left = 12
            Top = 46
            Width = 194
            Height = 17
            Caption = 'Organizar uses (Ctrl + Shift + U)'
            TabOrder = 1
          end
        end
        object grpUsesOrganization: TGroupBox
          Left = 15
          Top = 108
          Width = 297
          Height = 261
          Caption = 'Organiza'#231#227'o das Uses'
          TabOrder = 2
          object lblBreakLineAt: TLabel
            Left = 15
            Top = 199
            Width = 130
            Height = 13
            Caption = 'Quebra de linha na posi'#231#227'o'
          end
          object chkAlwaysImportToInterfaceSection: TCheckBox
            Left = 15
            Top = 42
            Width = 229
            Height = 17
            Caption = 'Sempre importar para a se'#231#227'o de interface'
            TabOrder = 1
          end
          object chkSortAfterAdding: TCheckBox
            Left = 15
            Top = 64
            Width = 210
            Height = 17
            Caption = 'Classificar Uses por ordem alfab'#233'tica'
            TabOrder = 2
            OnClick = chkSortAfterAddingClick
          end
          object chkBreakline: TCheckBox
            Left = 15
            Top = 104
            Width = 210
            Height = 17
            Caption = 'Quebre a linha a cada nova entrada Uses'
            TabOrder = 3
            OnClick = chkBreaklineClick
          end
          object chkBlankLineBtwNamespace: TCheckBox
            Left = 32
            Top = 126
            Width = 193
            Height = 17
            Hint = 
              'Classifique e quebre linha devem estar marcados para usar esta o' +
              'p'#231#227'o'
            Caption = 'Linha em branco entre namespaces'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 4
          end
          object chbOrganizeUsesAfterInsertingNewUsesUnit: TCheckBox
            Left = 15
            Top = 21
            Width = 279
            Height = 17
            Caption = 'Organize os Uses ap'#243's inserir uma nova unit no Uses'
            TabOrder = 0
          end
          object medtBreakUsesLineAtPosition: TMaskEdit
            Left = 155
            Top = 196
            Width = 34
            Height = 21
            EditMask = '!9!9!9;1; '
            MaxLength = 3
            TabOrder = 7
            Text = '120'
          end
          object chbGroupNonNameSpaceUnits: TCheckBox
            Left = 32
            Top = 148
            Width = 193
            Height = 17
            Hint = 
              'Classifique e quebre linha devem estar marcados para usar esta o' +
              'p'#231#227'o'
            Caption = 'Agrupar units sem namespace'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 5
          end
          object chbDontBreakLineForNonNameSpaceUnits: TCheckBox
            Left = 32
            Top = 171
            Width = 249
            Height = 17
            Hint = 
              'Classifique e quebre linha devem estar marcados para usar esta o' +
              'p'#231#227'o'
            Caption = 'N'#227'o quebre a linha para units sem namespace'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 6
          end
          object chkSortUsesByLevel: TCheckBox
            Left = 15
            Top = 84
            Width = 274
            Height = 17
            Hint = 'Classifique por n'#237'vel: RTL, VCL, Third-party, Projeto'
            Caption = 'Classificar uses por n'#237'vel (RTL > VCL > Third-party)'
            ParentShowHint = False
            ShowHint = True
            TabOrder = 8
          end
        end
        object btnCreateProjectConfiguration: TButton
          Left = 481
          Top = 353
          Width = 192
          Height = 25
          Caption = 'Criar configura'#231#227'o para este projeto'
          TabOrder = 4
          Visible = False
          OnClick = btnCreateProjectConfigurationClick
        end
        object chbFeatureUnusedUses: TCheckBox
          Left = 335
          Top = 129
          Width = 297
          Height = 17
          Caption = 'Ativar recurso experimental: encontre uses n'#227'o utilizados'
          TabOrder = 3
        end
        object chbEnableHighlight: TCheckBox
          Left = 335
          Top = 150
          Width = 350
          Height = 17
          Caption = 'Habilitar destaque de units n'#227'o utilizadas (underline no c'#243'digo)'
          TabOrder = 5
        end
      end
    end
    object tsAutoImport: TTabSheet
      Caption = 'Importa'#231#227'o Autom'#225'tica'
      object grdAutoImport: TDBGrid
        Left = 0
        Top = 48
        Width = 683
        Height = 336
        Align = alClient
        DataSource = dtsAutoImport
        Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgTabs, dgTitleClick, dgTitleHotTrack]
        TabOrder = 1
        TitleFont.Charset = DEFAULT_CHARSET
        TitleFont.Color = clWindowText
        TitleFont.Height = -11
        TitleFont.Name = 'Tahoma'
        TitleFont.Style = []
        Columns = <
          item
            Expanded = False
            FieldName = 'IDENTIFIER'
            Width = 300
            Visible = True
          end
          item
            Expanded = False
            FieldName = 'UNIT'
            Width = 300
            Visible = True
          end>
      end
      object grpAutoSettings: TGroupBox
        Left = 0
        Top = 0
        Width = 683
        Height = 48
        Align = alTop
        Caption = 'Configura'#231#245'es'
        TabOrder = 0
        object chkAutoEnabled: TCheckBox
          Left = 16
          Top = 18
          Width = 65
          Height = 21
          Caption = 'Habilitado'
          TabOrder = 1
        end
        object btn1: TButton
          Left = 480
          Top = 14
          Width = 157
          Height = 25
          Caption = 'Abrir arquivo de configura'#231#245'es'
          TabOrder = 0
          OnClick = btn1Click
        end
      end
      object nvgAutoImport: TDBNavigator
        Left = 0
        Top = 384
        Width = 683
        Height = 25
        DataSource = dtsAutoImport
        Align = alBottom
        ConfirmDelete = False
        TabOrder = 2
      end
    end
    object tsUnusedUses: TTabSheet
      Caption = 'Uses n'#227'o utilizados'
      ImageIndex = 2
      object mmoIgnoreUses: TMemo
        Left = 0
        Top = 43
        Width = 683
        Height = 366
        Align = alBottom
        Lines.Strings = (
          'mmoIgnoreUses')
        ScrollBars = ssHorizontal
        TabOrder = 0
      end
    end
  end
  object dtsAutoImport: TDataSource
    DataSet = cdsAutoImport
    Left = 582
    Top = 80
  end
  object cdsAutoImport: TClientDataSet
    Aggregates = <>
    Params = <>
    Left = 487
    Top = 81
    object cdsAutoImportIDENTIFIER: TStringField
      FieldName = 'IDENTIFIER'
      Size = 200
    end
    object cdsAutoImportUNIT: TStringField
      FieldName = 'UNIT'
      Size = 200
    end
  end
end
