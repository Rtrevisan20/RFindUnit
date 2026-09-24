      {******************************************************************}
      { SVG fill classes                                                 }
      {                                                                  }
      { home page : http://www.mwcs.de                                   }
      { email     : martin.walter@mwcs.de                                }
      {                                                                  }
      { date      : 05-04-2008                                           }
      {                                                                  }
      { Use of this file is permitted for commercial and non-commercial  }
      { use, as long as the author is credited.                          }
      { This file (c) 2005, 2008 Martin Walter                           }
      {                                                                  }
      { This Software is distributed on an "AS IS" basis, WITHOUT        }
      { WARRANTY OF ANY KIND, either express or implied.                 }
      {                                                                  }
      { *****************************************************************}

unit SVGPaint;

interface

uses
{$IFDEF FPC}
  Classes,
  SVGXML,
  Painter,
  SVGTypes, SVG;
{$ELSE}
  System.Classes,
  SVGXML,
  Painter,
  SVGTypes, SVG;
{$ENDIF}

type
  TColors = record
    Colors: packed array of TPainterColor;
    Positions: packed array of Single;
    Count: Integer;
  end;

  TSVGStop = class(TSVGObject)
  strict private
    FStop: TFloat;
    FStopColor: TColor;
    FOpacity: TFloat;

  protected
    function New(Parent: TSVGObject): TSVGObject; override;
    procedure AssignTo(Dest: TPersistent); override;
  public
    procedure ReadIn(const Node: IXMLNode); override;
    procedure PaintToGraphics(Graphics: TPainter); override;
    procedure PaintToPath(Path: TPainterPath); override;

    property Stop: TFloat read FStop write FStop;
    property StopColor: TColor read FStopColor write FStopColor;

    property Opacity: TFloat read FOpacity write FOpacity;
  end;

  TSVGFiller = class(TSVGMatrix)
  private
  protected
    function New(Parent: TSVGObject): TSVGObject; override;
  public
    procedure ReadIn(const Node: IXMLNode); override;
    function GetBrush(Alpha: Byte; const DestObject: TSVGBasic;
      const P: TPainter): TPainterBrush; virtual; abstract;
    procedure PaintToGraphics(Graphics: TPainter); override;
    procedure PaintToPath(Path: TPainterPath); override;
  end;

  TSVGGradient = class(TSVGFiller)
  private
    FURI: string;
    FGradientUnits: TGradientUnits;
  protected
    function GetColors(Alpha: Byte): TColors; virtual;
  public
    procedure ReadIn(const Node: IXMLNode); override;
  end;

  TSVGLinearGradient = class(TSVGGradient)
  private
    FX1: TFloat;
    FY1: TFloat;
    FX2: TFloat;
    FY2: TFloat;
  protected
    function New(Parent: TSVGObject): TSVGObject; override;
    procedure AssignTo(Dest: TPersistent); override;
  public
    procedure ReadIn(const Node: IXMLNode); override;
    function GetBrush(Alpha: Byte; const DestObject: TSVGBasic;
      const P: TPainter): TPainterBrush; override;

    property X1: TFloat read FX1 write FX1;
    property Y1: TFloat read FY1 write FY1;
    property X2: TFloat read FX2 write FX2;
    property Y2: TFloat read FY2 write FY2;
  end;

  TSVGRadialGradient = class(TSVGGradient)
  private
    FCX: TFloat;
    FCY: TFloat;
    FR: TFloat;
    FFX: TFloat;
    FFY: TFloat;
  protected
    function New(Parent: TSVGObject): TSVGObject; override;
    procedure AssignTo(Dest: TPersistent); override;
  public
    procedure Clear; override;
    procedure ReadIn(const Node: IXMLNode); override;
    function GetBrush(Alpha: Byte; const DestObject: TSVGBasic;
      const P: TPainter): TPainterBrush; override;

    property CX: TFloat read FCX write FCX;
    property CY: TFloat read FCY write FCY;
    property R: TFloat read FR write FR;
    property FX: TFloat read FFX write FFX;
    property FY: TFloat read FFY write FFY;
  end;


implementation

uses
{$IFDEF FPC}
  SysUtils,
  SVGParse, SVGStyle, SVGProperties, SVGColor;
{$ELSE}
  System.SysUtils,
  SVGParse, SVGStyle, SVGProperties, SVGColor;
{$ENDIF}

{ Maps the core's System.Math.Vectors TMatrix2D to the painter matrix model
  (m33 is implied = 1), the same convention SVG.pas' ToPainterMatrix uses. }
function MatrixToPainter(const M: TMatrix2D): TPainterMatrix;
begin
  Result.m11 := M.m11;
  Result.m12 := M.m12;
  Result.m21 := M.m21;
  Result.m22 := M.m22;
  Result.m31 := M.m31;
  Result.m32 := M.m32;
end;

// TSVGStop

procedure TSVGStop.PaintToPath(Path: TPainterPath);
begin
end;

procedure TSVGStop.ReadIn(const Node: IXMLNode);
var
  S: string;
begin
  inherited;
  LoadPercent(Node, 'offset', FStop);

  LoadString(Node, 'stop-color', S);
  FStopColor := GetColor(S);

  if FStopColor = INHERIT then
  begin
    S := Style['stop-color'];
    FStopColor := GetColor(S);
  end;

  S := Style['stop-opacity'];
  if (S <> '') then
    FOpacity := ParsePercent(S)
  else
    FOpacity := 1;

  if (FOpacity < 0) then
    FOpacity := 0;

  if (FOpacity > 1) then
    FOpacity := 1;
end;

procedure TSVGStop.AssignTo(Dest: TPersistent);
begin
  inherited;
  if Dest is TSVGStop then
  begin
    TSVGStop(Dest).FStop := FStop;
    TSVGStop(Dest).FStopColor := FStopColor;
  end;
end;

function TSVGStop.New(Parent: TSVGObject): TSVGObject;
begin
  Result := TSVGStop.Create(Parent);
end;

procedure TSVGStop.PaintToGraphics(Graphics: TPainter);
begin
end;

// TSVGFiller

procedure TSVGFiller.PaintToPath(Path: TPainterPath);
begin
end;           

procedure TSVGFiller.ReadIn(const Node: IXMLNode);
begin
  inherited;
  Display := 0;
end;

function TSVGFiller.New(Parent: TSVGObject): TSVGObject;
begin
  Result := nil;
end;

procedure TSVGFiller.PaintToGraphics(Graphics: TPainter);
begin
end;

// TSVGGradient

procedure TSVGGradient.ReadIn(const Node: IXMLNode);
var
  C: Integer;
  Stop: TSVGStop;
begin
  inherited;

  LoadGradientUnits(Node, FGradientUnits);

  for C := 0 to Node.childNodes.count - 1 do
   if Node.childNodes[C].nodeName = 'stop' then
   begin
     Stop := TSVGStop.Create(Self);
     Stop.ReadIn(Node.childNodes[C]);
   end;

  FURI := Style['xlink:href'];
  if FURI <> '' then
  begin
    FURI := Trim(FURI);
    if (FURI <> '') and (FURI[1] = '#') then
      FURI := Copy(FURI, 2, MaxInt);
  end;
end;

// TSVGLinearGradient

function TSVGLinearGradient.New(Parent: TSVGObject): TSVGObject;
begin
  Result := TSVGLinearGradient.Create(Parent);
end;

procedure TSVGLinearGradient.ReadIn(const Node: IXMLNode);
var
  Matrix: TMatrix2D;
begin
  inherited;
  LoadLength(Node, 'x1', FX1);
  LoadLength(Node, 'y1', FY1);
  LoadLength(Node, 'x2', FX2);
  LoadLength(Node, 'y2', FY2);

  FillChar(Matrix, SizeOf(Matrix), 0);
  LoadTransform(Node, 'gradientTransform', Matrix);
  PureMatrix := Matrix;
end;

procedure TSVGLinearGradient.AssignTo(Dest: TPersistent);
begin
  inherited;
  if Dest is TSVGLinearGradient then
  begin
    TSVGLinearGradient(Dest).FX1 := FX1;
    TSVGLinearGradient(Dest).FY1 := FY1;
    TSVGLinearGradient(Dest).FX2 := FX2;
    TSVGLinearGradient(Dest).FY2 := FY2;
  end;
end;

function TSVGLinearGradient.GetBrush(Alpha: Byte; const DestObject: TSVGBasic;
  const P: TPainter): TPainterBrush;
var
  Brush: TPainterLinearGradientBrush;
  Colors: TColors;
begin
  if Assigned(DestObject) and (FGradientUnits = guObjectBoundingBox) then
    Brush := P.CreateLinearGradientBrush(
      Painter.MakePoint(DestObject.X, DestObject.Y),
      Painter.MakePoint(DestObject.X + DestObject.Width,
        DestObject.Y + DestObject.Height), $FF000000, $FF000000)
  else
    Brush := P.CreateLinearGradientBrush(
      Painter.MakePoint(FX1, FY1), Painter.MakePoint(FX2, FY2),
      $FF000000, $FF000000);

  Colors := GetColors(Alpha);

  Brush.SetInterpolationColors(Colors.Colors, Colors.Positions);

  Finalize(Colors);

  if PureMatrix.m33 = 1 then
    Brush.SetTransform(MatrixToPainter(PureMatrix));

  Result := Brush;
end;

// TSVGRadialGradient

procedure TSVGRadialGradient.AssignTo(Dest: TPersistent);
begin
  inherited;
  if Dest is TSVGRadialGradient then
  begin
    TSVGRadialGradient(Dest).FCX := FCX;
    TSVGRadialGradient(Dest).FCY := FCY;
    TSVGRadialGradient(Dest).FFX := FFX;
    TSVGRadialGradient(Dest).FFY := FFY;
    TSVGRadialGradient(Dest).FR := FR;
  end;
end;

procedure TSVGRadialGradient.Clear;
begin
  inherited;

  FCX := 0.5;
  FCY := 0.5;
  FR := 0.5;
  FFX := FCX;
  FFY := FCY;
end;

procedure TSVGRadialGradient.ReadIn(const Node: IXMLNode);
begin
  inherited;

  LoadLength(Node, 'cx', FCX);
  LoadLength(Node, 'cy', FCY);
  LoadLength(Node, 'r', FR);
  LoadLength(Node, 'fx', FFX);
  LoadLength(Node, 'fy', FFY);
end;

function TSVGRadialGradient.GetBrush(Alpha: Byte; const DestObject: TSVGBasic;
  const P: TPainter): TPainterBrush;
var
  Brush: TPainterRadialGradientBrush;
  Colors: TColors;
begin
  if Assigned(DestObject) and (FGradientUnits = guObjectBoundingBox) then
    Brush := P.CreateRadialGradientBrush(DestObject.X, DestObject.Y,
      DestObject.Width, DestObject.Height)
  else
    Brush := P.CreateRadialGradientBrush(FCX - FR, FCY - FR, 2 * FR, 2 * FR);

  Colors := GetColors(Alpha);
  Brush.SetInterpolationColors(Colors.Colors, Colors.Positions);

  Finalize(Colors);

  Brush.SetCenterPoint(Painter.MakePoint(FFX, FFY));

  if PureMatrix.m33 = 1 then
    Brush.SetTransform(MatrixToPainter(PureMatrix));

  Result := Brush;
end;

function TSVGRadialGradient.New(Parent: TSVGObject): TSVGObject;
begin
  Result := TSVGRadialGradient.Create(Parent);
end;

function TSVGGradient.GetColors(Alpha: Byte): TColors;
var
  C, Start, ColorCount: Integer;
  Stop: TSVGStop;
  Item: TSVGGradient;
begin
  Result.Count := 0;
  if FURI = '' then
    Item := Self
  else
  begin
    Item := TSVGGradient(GetRoot.FindByID(FURI));
    if not (Item is TSVGGradient) then
      Exit;
  end;

  Start := 0;
  ColorCount := Item.Count;

  if Item.Count = 0 then
    Exit;

  if TSVGStop(Item.Items[ColorCount - 1]).Stop < 1 then
    Inc(ColorCount);

  if TSVGStop(Item.Items[0]).Stop > 0 then
  begin
    Inc(ColorCount);
    Inc(Start);
  end;

  SetLength(Result.Colors, ColorCount);
  SetLength(Result.Positions, ColorCount);

  if Start > 0 then
  begin
    Stop := TSVGStop(Item.Items[0]);
    Result.Colors[0] := ConvertColor(Stop.StopColor, Round(Alpha * Stop.Opacity));
    Result.Positions[0] := 0;
  end;

  for C := 0 to Item.Count - 1 do
  begin
    Stop := TSVGStop(Item.Items[C]);
    Result.Colors[C + Start] := ConvertColor(Stop.StopColor, Round(Alpha * Stop.Opacity));
    Result.Positions[C + Start] := Stop.Stop;
  end;

  if (ColorCount - Start) > Item.Count then
  begin
    Stop := TSVGStop(Item.Items[Item.Count - 1]);
    Result.Colors[ColorCount - 1] := ConvertColor(Stop.StopColor, Round(Alpha * Stop.Opacity));
    Result.Positions[ColorCount - 1] := 1;
  end;

  Result.Count := ColorCount;
end;

end.
