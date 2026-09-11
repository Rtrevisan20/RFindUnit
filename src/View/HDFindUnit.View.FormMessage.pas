unit HDFindUnit.View.FormMessage;

interface

uses
  Classes,
  Types,
  Controls,
  ExtCtrls,
  Forms,
{$IFDEF FPC}
  LCLType,
{$ENDIF}
  StdCtrls;

const
  RFU_WS_EX_NOACTIVATE = $08000000;

type
  TfrmMessage = class(TForm)
    tmrClose: TTimer;
    pnMsg   : TPanel;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure tmrCloseTimer(Sender: TObject);
  private
    procedure PrintOnCanvas(Sender: TObject);
    procedure ConfigMsg;
{$IFDEF FPC}
    procedure CreateFormControls;
{$ENDIF}
  protected
    class var CurTop: integer;
    FTexto: string;
    procedure CreateParams(var Params: TCreateParams); override;

    function GetPosition: TRect;
    function GetTextWidth: TSize;

    procedure SetPosition;
  public
    procedure DisplayMessage(const Text: string);

    class procedure ShowInfoToUser(const Text: string);
  end;

implementation

uses
{$IFDEF FPC}
  Graphics,
{$ELSE}
  TransparentCanvas,
  Vcl.Graphics,
  Winapi.Windows,
{$ENDIF}
  SysUtils,
  HDFindUnit.Model.DelphiVlcWrapper,
  Log4Pascal;

const
  MARGIN_PADING   = 5;
  COORNER_MARGIN  = 10;
  FONT_NAME       = 'Courier New';
  FONT_SIZE       = 13;
  FONT_COLOR      = $000146A5;
  BRUSH_COLOR     = $00CCE6FF;

{$IFNDEF FPC}
{$R *.dfm}
{$ENDIF}

procedure TfrmMessage.Button1Click(Sender: TObject);
begin
  PrintOnCanvas(Sender);
end;

procedure TfrmMessage.ConfigMsg;
var
  TextSize: TSize;
begin
  TextSize          := GetTextWidth;
  pnMsg.Width       := TextSize.cx + COORNER_MARGIN * 2 + MARGIN_PADING;
  pnMsg.Color       := BRUSH_COLOR;
  pnMsg.Font.Name   := FONT_NAME;
  pnMsg.Font.Size   := FONT_SIZE;
  pnMsg.Font.Color  := FONT_COLOR;
{$IFDEF FPC}
  pnMsg.Caption     := '';
{$ELSE}
  pnMsg.Caption     := FTexto;
{$ENDIF}
end;

procedure TfrmMessage.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := WS_EX_TRANSPARENT or WS_EX_TOPMOST or RFU_WS_EX_NOACTIVATE;
end;

procedure TfrmMessage.SetPosition;
var
  OpenRect: TRect;
  TextSize: TSize;
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
  Logger.Info('TfrmMessage.ShowInfoToUser: Criando form para: ' + Copy(Text, 1, 80));
  MsgForm := TfrmMessage.Create(Application);
  MsgForm.DisplayMessage(Text);
  Logger.Info('TfrmMessage.ShowInfoToUser: Form criado e exibido.');
end;

procedure TfrmMessage.DisplayMessage(const Text: string);
begin
  FTexto    := Text;
  SetPosition;
  ConfigMsg;
{$IFDEF FPC}
  Visible   := True;
  BringToFront;
{$ELSE}
  ShowWindow(Handle, SW_SHOWNOACTIVATE);
  Visible   := True;
{$ENDIF}
  Repaint;
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
{$IFDEF FPC}
  CreateFormControls;
  pnMsg.OnPaint := PrintOnCanvas;
{$ENDIF}
  Brush.Style := bsClear;
  BorderStyle := bsNone;
end;

{$IFDEF FPC}
procedure TfrmMessage.CreateFormControls;
begin
  Self.ClientHeight := 30;

  pnMsg := TPanel.Create(Self);
  with pnMsg do begin
    Parent      := Self;
    Left        := 0;
    Top         := 0;
    Width       := 629;
    Height      := 30;
    Align       := alClient;
    BevelOuter  := bvNone;
    Color       := BRUSH_COLOR;
  end;

  tmrClose := TTimer.Create(Self);
  tmrClose.Enabled := False;
  tmrClose.Interval := 2500;
  tmrClose.OnTimer := tmrCloseTimer;
end;
{$ENDIF}

function TfrmMessage.GetPosition: TRect;
begin
  Result := TDelphiVLCWrapper.GetEditorRect;
end;

{$IFDEF FPC}
function TfrmMessage.GetTextWidth: TSize;
begin
  pnMsg.Canvas.Font.Name := FONT_NAME;
  pnMsg.Canvas.Font.Size := FONT_SIZE;
  Result := pnMsg.Canvas.TextExtent(FTexto);
end;
{$ELSE}
function TfrmMessage.GetTextWidth: TSize;
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
{$ENDIF}

{$IFDEF FPC}
procedure TfrmMessage.PrintOnCanvas(Sender: TObject);
var
  C: TCanvas;
begin
  try
    C := pnMsg.Canvas;
    C.Font.Name := FONT_NAME;
    C.Font.Size := FONT_SIZE;
    C.Brush.Style := bsClear;

    C.Pen.Width := 1;
    C.Pen.Color := $004080FF;
    C.Rectangle(0, 0, pnMsg.ClientWidth - 1, pnMsg.ClientHeight - 1);

    C.Font.Color := clBlack;
    C.TextOut(COORNER_MARGIN + MARGIN_PADING + 1, MARGIN_PADING + 1, FTexto);

    C.Font.Color := FONT_COLOR;
    C.TextOut(COORNER_MARGIN + MARGIN_PADING, MARGIN_PADING, FTexto);
  except
    on E: Exception do
    begin
      Logger.Error('TfrmMessage.PrintOnCanvas: %s', [E.Message]);
      {$IFDEF RAISEMAD} raise; {$ENDIF}
    end;
  end;
end;
{$ELSE}
procedure TfrmMessage.PrintOnCanvas(Sender: TObject);
var
  TextSize: TSize;
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
{$ENDIF}

end.