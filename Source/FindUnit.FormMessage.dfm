object frmMessage: TfrmMessage
  Left = 0
  Top = 0
  BorderIcons = []
  BorderStyle = bsNone
  Caption = 'Message'
  ClientHeight = 30
  ClientWidth = 629
  Color = clWhite
  TransparentColor = True
  TransparentColorValue = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OnClose = FormClose
  OnCreate = FormCreate
  TextHeight = 13
  object pnMsg: TPanel
    Left = 0
    Top = 0
    Width = 629
    Height = 30
    Align = alClient
    BevelOuter = bvNone
    Caption = 'MSG'
    Color = 13428479
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 83621
    Font.Height = -17
    Font.Name = 'Courier New'
    Font.Style = []
    ParentBackground = False
    ParentFont = False
    TabOrder = 0
    StyleName = 'Windows'
    ExplicitHeight = 50
  end
  object tmrClose: TTimer
    Enabled = False
    Interval = 2500
    OnTimer = tmrCloseTimer
    Left = 546
    Top = 65535
  end
end
