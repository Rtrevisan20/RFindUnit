unit FindUnit.FormMessage;

interface

uses
  Vcl.Forms, System.Classes, Vcl.ExtCtrls, Vcl.Controls, System.Types, Vcl.StdCtrls;

type
  TfrmMessage = class(TForm)
    tmrClose: TTimer;
    pnMsg: TPanel;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure tmrCloseTimer(Sender: TObject);
  private
    procedure PrintOnCanvas;
    procedure ConfigMsg;
  protected
    class var CurTop: integer;
    FTexto: string;
    procedure CreateParams(var Params: TCreateParams); override;

    function GetPosition: TRect;
    function GetTextWidth: tagSIZE;

    procedure SetPosition;
  public
    procedure DisplayMessage(const Text: string);

    class procedure ShowInfoToUser(const Text: string);
  end;

implementation

uses
  Log4Pascal,

  FindUnit.DelphiVlcWrapper, Winapi.Windows, TransparentCanvas, Vcl.Graphics,
  System.SysUtils;

const
  MARGIN_PADING   = 5;
  COORNER_MARGIN  = 10;
  FONT_NAME       = 'Courier New';
  FONT_SIZE       = 13;
  FONT_COLOR      = $000146A5;
  BRUSH_COLOR     = $00CCE6FF;

{$R *.dfm}

procedure TfrmMessage.Button1Click(Sender: TObject);
begin
  PrintOnCanvas;
end;

procedure TfrmMessage.ConfigMsg;
var
  TextSize: tagSIZE;
begin
  TextSize          := GetTextWidth;
  pnMsg.Width       := TextSize.cx + COORNER_MARGIN * 2 + MARGIN_PADING;
  pnMsg.Color       := BRUSH_COLOR;
  pnMsg.Caption     := FTexto;
  pnMsg.Font.Name   := FONT_NAME;
  pnMsg.Font.Size   := FONT_SIZE;
  pnMsg.Font.Color  := FONT_COLOR;
end;

procedure TfrmMessage.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := WS_EX_TRANSPARENT or WS_EX_TOPMOST or WS_EX_NOACTIVATE;
end;

procedure TfrmMessage.SetPosition;
var
  OpenRect: TRect;
  TextSize: tagSIZE;
begin
  OpenRect  := GetPosition;
  TextSize  := GetTextWidth;
  Top       := OpenRect.Top + CurTop;
  CurTop    := CurTop + 30;
  if OpenRect.Left <> OpenRect.Right then
   begin
    Width := TextSize.cx + COORNER_MARGIN * 2 + MARGIN_PADING;
    Left := OpenRect.Right - Width - COORNER_MARGIN * 2;
    Top := Top + COORNER_MARGIN;
   end else
    Left := OpenRect.Left;

  BringToFront;
end;

class procedure TfrmMessage.ShowInfoToUser(const Text: string);
var
  MsgForm: TfrmMessage;
begin
  MsgForm := TfrmMessage.Create(nil);
  MsgForm.DisplayMessage(Text);
end;

procedure TfrmMessage.DisplayMessage(const Text: string);
begin
  FTexto    := Text;
  SetPosition;
  ConfigMsg;
  ShowWindow(Handle, SW_SHOWNOACTIVATE);
  Visible          := True;
  tmrClose.Enabled := True;
end;

procedure TfrmMessage.tmrCloseTimer(Sender: TObject);
begin
  Close;
end;

procedure TfrmMessage.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  CurTop := CurTop - 30;
end;

procedure TfrmMessage.FormCreate(Sender: TObject);
begin
  Brush.Style := bsClear;
  BorderStyle := bsNone;
end;

function TfrmMessage.GetPosition: TRect;
begin
  Result := TDelphiVLCWrapper.GetEditorRect;
end;

function TfrmMessage.GetTextWidth: tagSIZE;
var
  GlassCanvas: TTransparentCanvas;
begin
  GlassCanvas := TTransparentCanvas.Create(ClientWidth, ClientHeight);
  try
    GlassCanvas.Font.Name  := FONT_NAME;
    GlassCanvas.Font.Size  := FONT_SIZE;
    GlassCanvas.Font.Color := FONT_COLOR;

    Result := GlassCanvas.TextExtent(FTexto);
  finally
    GlassCanvas.Free;
  end;
end;

procedure TfrmMessage.PrintOnCanvas;
var
  TextSize: tagSIZE;
  GlassCanvas: TTransparentCanvas;
begin
  try
    GlassCanvas := TTransparentCanvas.Create(ClientWidth, ClientHeight);
    try
      GlassCanvas.Font.Name  := FONT_NAME;
      GlassCanvas.Font.Size  := FONT_SIZE;
      GlassCanvas.Font.Color := FONT_COLOR;

      TextSize := GlassCanvas.TextExtent(FTexto);

      GlassCanvas.Pen.Width   := 1;
      GlassCanvas.Pen.Color   := $004080FF;
      GlassCanvas.Brush.Color := $00CCE6FF;
      GlassCanvas.Rectangle(COORNER_MARGIN, 0,
          TextSize.cx + COORNER_MARGIN + MARGIN_PADING + MARGIN_PADING, 30, 240);

      GlassCanvas.GlowTextOutBackColor(COORNER_MARGIN + MARGIN_PADING, MARGIN_PADING, 0,
            FTexto, clBlack, taLeftJustify, 10, 255);

      GlassCanvas.DrawToGlass(0, 0, Canvas.Handle);
    finally
      GlassCanvas.Free;
    end;
  except
    on e: exception do
    begin
      Logger.Error('TfrmMessage.PrintOnCanvas: %s', [E.Message]);
      {$IFDEF RAISEMAD} raise; {$ENDIF}
    end;
  end;
end;

end.
