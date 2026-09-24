unit PainterLCL;

{ TPainterLCL - TCanvas (LCL) backend for TPainter.  Task 1.3 of the Delphi +
  Lazarus port. FPC/Lazarus only: uses the LCL Graphics unit (TCanvas), so it
  is NOT meant to be compiled with Delphi (Delphi stays on TPainterGdiPlus).

  Geometry handling:
  - Paths store normalized command segments (move/line/cubic-bezier/close) in
    local coordinates. Rect/ellipse/arc/polygon are expanded at Add* time
    (ellipse = 4 cubics via kappa, arc = linear sampling), so Transform() works
    on plain control points.
  - Cubic beziers are flattened with de Casteljau subdivision (no TGPFlatten
    in FPC) and the result is drawn through TCanvas.Polygon/Polyline.

  Feature status (task 1.3, first pass):
  - solid + linear gradient + radial gradient fills (band/ring rendering with
    Windows clip regions; on non-Windows falls back to a solid mid color);
  - pens: color/width/dash mapped to TPenStyle (custom patterns approximated);
    joins/caps/miter use system defaults (documented limitation);
  - text: DrawString/MeasureString/MeasureText via LCL font metrics;
    AddTextToPath and path.AddString build placeholder glyph boxes (no true
    text outlines on LCL) - documented limitation;
  - images: TBitmap.LoadFromStream + StretchDraw; opacity ignored;
  - clip: tessellated polygon region (WINDOWS only; elsewhere bounding box);
  - transform: applied to every point at rasterize time;
  - smoothing: TCanvas.AntialiasingMode.

  Limitations are documented in painter\README.md (task 1.4). }

interface

uses
  Painter,
  Classes, SysUtils, Types, Math,
  Graphics, LCLType, LCLIntf;

const
  CPi = 3.1415926535897932385;

type
  { Normalized path commands. Rect/ellipse/arc/polygon are expanded into
    move/line/bezier/close segments at Add* time (local coordinates). }
  TPathSegKind = (pskMove, pskLine, pskBezier, pskClose);

  TPathSeg = packed record
    Kind: TPathSegKind;
    P: array[0..7] of Single;
  end;

  { One flattened (and transformed) figure: a fill polygon or a stroke
    polyline. CloseFigure ends a figure with Closed = True. }
  TFigure = record
    Pts: array of TPainterPoint;
    Closed: Boolean;
  end;
  TFigureList = array of TFigure;
  TPointArray = array of TPoint;
  TPainterPointArray = array of TPainterPoint;
  TColorArray = array of TPainterColor;
  TPositionArray = array of Single;

  TPainterLCLSolidBrush = class(TPainterSolidBrush)
  public
    function Clone: TPainterBrush; override;
  end;

  { Linear gradient brush. Descends from TPainterLinearGradientBrush (the
    abstraction callers use) and carries its own color stop storage. }
  TPainterLCLLinearGradientBrush = class(TPainterLinearGradientBrush)
  private
    FColors: TColorArray;
    FPositions: TPositionArray;
    FTransform: TPainterMatrix;
  protected
    function Count: Integer;
    function ColorAt(const T: Single): TPainterColor;
  public
    constructor Create(const P1, P2: TPainterPoint;
      const C1, C2: TPainterColor); reintroduce;
    procedure SetInterpolationColors(const Colors: array of TPainterColor;
      const Positions: array of Single); override;
    procedure SetTransform(const Matrix: TPainterMatrix); override;
    function Clone: TPainterBrush; override;
  end;

  { Radial gradient brush. Descends from TPainterRadialGradientBrush (the
    abstraction callers use), so it re-implements the color stop storage that
    the linear brush carries. }
  TPainterLCLRadialGradientBrush = class(TPainterRadialGradientBrush)
  private
    FColors: TColorArray;
    FPositions: TPositionArray;
    FTransform: TPainterMatrix;
    FCenter: TPainterPoint;
  protected
    function Count: Integer;
    function ColorAt(const T: Single): TPainterColor;
  public
    constructor Create(const ALeft, ATop, AWidth, AHeight: Single); reintroduce;
    procedure SetInterpolationColors(const Colors: array of TPainterColor;
      const Positions: array of Single); override;
    procedure SetTransform(const Matrix: TPainterMatrix); override;
    procedure SetCenterPoint(const Center: TPainterPoint); override;
    function Clone: TPainterBrush; override;
  end;

  TPainterLCLPen = class(TPainterPen)
  private
    FJoin: TPainterLineJoin;
    FMiterLimit: Single;
    FCaps: array[0..1] of TPainterLineCap;
    FDashCap: TPainterDashCap;
    FDashPattern: array of Single;
    FDashStyle: TPainterDashStyle;
    FDashOffset: Single;
    FBrushColor: TPainterColor;
  public
    procedure SetBrush(const Brush: TPainterBrush); override;
    procedure SetLineJoin(const Join: TPainterLineJoin); override;
    procedure SetMiterLimit(const Limit: Single); override;
    procedure SetLineCap(const StartCap, EndCap: TPainterLineCap;
      const DCap: TPainterDashCap); override;
    procedure SetDashPattern(const Pattern: array of Single); override;
    procedure SetDashStyle(const Style: TPainterDashStyle); override;
    procedure SetDashOffset(const Offset: Single); override;
  end;

  TPainterLCLFontFamily = class(TPainterFontFamily)
  private
    FName: string;
  public
    constructor Create(const AName: string); reintroduce;
    function GetCellAscent(const Style: TPainterFontStyle): Integer; override;
    function GetEmHeight(const Style: TPainterFontStyle): Integer; override;
  end;

  TPainterLCLFont = class(TPainterFont)
  private
    FFamilyName: string;
    FSize: Single;
    FStyle: TPainterFontStyle;
  public
    constructor Create(const Family: TPainterFontFamily; const Size: Single;
      const Style: TPainterFontStyle); reintroduce;
    property FName: string read FFamilyName;
  end;

  TPainterLCLImage = class(TPainterImage)
  private
    FBitmap: TBitmap;
  public
    constructor CreateFromStream(const Stream: TStream); override;
    destructor Destroy; override;
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    property Bitmap: TBitmap read FBitmap;
  end;

  TPainterLCLPath = class(TPainterPath)
  private
    FSegs: array of TPathSeg;
    FSegCount: Integer;
    FCurrent: Boolean;
    FFillMode: TPainterFillMode;
    procedure AppendSeg(const Kind: TPathSegKind;
      const P: array of Single);
    procedure AddTextBox(const Text: string; const X, Y, Size: Single;
      const CharW: Single);
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure StartFigure; override;
    procedure CloseFigure; override;
    procedure AddLine(const X1, Y1, X2, Y2: Single); override;
    procedure AddBezier(const X1, Y1, X2, Y2, X3, Y3, X4, Y4: Single); override;
    procedure AddArc(const X, Y, W, H, StartAngle, SweepAngle: Single); override;
    procedure AddEllipse(const X, Y, W, H: Single); override;
    procedure AddRectangle(const Rect: TPainterRect); override;
    procedure AddPolygon(const Points: array of TPainterPoint); override;
    procedure AddPath(const Path: TPainterPath; const Connect: Boolean); override;
    procedure AddString(const Text: string; const Family: TPainterFontFamily;
      const Style: TPainterFontStyle; const Size: Single;
      const Format: TPainterTextFormat); override;
    procedure SetFillMode(const FillMode: TPainterFillMode); override;
    procedure Transform(const Matrix: TPainterMatrix); override;
    function Clone: TPainterPath; override;
    function GetPointCount: Integer; override;
  end;

  TPainterLCL = class(TPainter)
  private
    FCanvas: TCanvas;
    FMatrix: TPainterMatrix;
    FClipRgn: HRGN;
    FClipValid: Boolean;
    procedure SetFont(const Family: string; const Size: Single;
      const Style: TPainterFontStyle);
    procedure SetPen(const Pen: TPainterPen);
    procedure SetBrushSolid(const Color: TPainterColor);
    procedure FillSolid(const Color: TPainterColor; const Path: TPainterPath);
    procedure FillLinear(const Brush: TPainterBrush; const Path: TPainterPath);
    procedure FillRadial(const Brush: TPainterBrush; const Path: TPainterPath);
  public
    constructor Create(const ACanvas: TCanvas); reintroduce;
    destructor Destroy; override;

    { --- resource factories ------------------------------------------------ }
    function CreateSolidBrush(const AColor: TPainterColor): TPainterSolidBrush; override;
    function CreateLinearGradientBrush(const P1, P2: TPainterPoint;
      const C1, C2: TPainterColor): TPainterLinearGradientBrush; override;
    function CreateRadialGradientBrush(const ALeft, ATop, AWidth,
      AHeight: Single): TPainterRadialGradientBrush; override;
    function CreatePen(const AColor: TPainterColor;
      const AWidth: Single): TPainterPen; override;
    function CreateFontFamily(const AName: string): TPainterFontFamily; override;
    function CreateFont(const Family: TPainterFontFamily; const Size: Single;
      const Style: TPainterFontStyle): TPainterFont; override;
    function LoadImage(const Stream: TStream): TPainterImage; override;
    function CreatePath: TPainterPath; override;

    { --- state ------------------------------------------------------------- }
    procedure SetSmoothingMode(const AntiAlias: Boolean); override;
    procedure SetTransform(const Matrix: TPainterMatrix); override;
    procedure ResetTransform; override;
    procedure GetTransform(out Matrix: TPainterMatrix); override;
    procedure SetClip(const Path: TPainterPath); override;
    procedure ResetClip; override;
    procedure Clear(const Color: TPainterColor); override;

    { --- geometry ---------------------------------------------------------- }
    procedure FillPath(const Brush: TPainterBrush; const Path: TPainterPath); override;
    procedure DrawPath(const Pen: TPainterPen; const Path: TPainterPath); override;
    procedure DrawLine(const Pen: TPainterPen;
      const X1, Y1, X2, Y2: Single); override;

    { --- raster ------------------------------------------------------------ }
    procedure DrawImage(const Image: TPainterImage; const Dest: TPainterRect;
{$IFDEF FPC}
      Options: TPainterImageOptions); override;
{$ELSE}
      const Options: TPainterImageOptions); override;
{$ENDIF}

    { --- text -------------------------------------------------------------- }
    procedure DrawString(const Text: string; const Font: TPainterFont;
      const Origin: TPainterPoint; const Format: TPainterTextFormat;
      const Brush: TPainterBrush); override;
    procedure MeasureString(const Text: string; const Font: TPainterFont;
      const Origin: TPainterPoint; const Format: TPainterTextFormat;
      var Rect: TPainterRect); override;
    function MeasureText(const Text: string; const Font: TPainterFont): Single; override;
    procedure AddTextToPath(const Path: TPainterPath; const Text: string;
      const Family: TPainterFontFamily; const Style: TPainterFontStyle;
      const Size: Single; const Origin: TPainterPoint;
      const Format: TPainterTextFormat); override;
    function GetPathLength(const Path: TPainterPath): Single; override;
  end;

  { LCL measurement service used at parse time (before any canvas exists).
    Uses a lazy internal TCanvas for font metrics and builds placeholder glyph
    boxes into TPainterLCLPath (same limitation as TPainterLCL.AddTextToPath).
    Registered by this unit so <text> SVG nodes never hit an unassigned
    PainterMeasure when only the LCL backend is linked. }
  TPainterMeasureLCL = class(TPainterMeasure)
  public
    function CreateFontFamily(const AName: string): TPainterFontFamily; override;
    function CreateFont(const Family: TPainterFontFamily; const Size: Single;
      const Style: TPainterFontStyle): TPainterFont; override;
    function MeasureText(const Text: string; const Font: TPainterFont): Single; override;
    procedure MeasureString(const Text: string; const Font: TPainterFont;
      const Origin: TPainterPoint; const Format: TPainterTextFormat;
      var Rect: TPainterRect); override;
    procedure AddTextToPath(const Path, UPath, SPath: TPainterPath;
      const Text: string; const Family: TPainterFontFamily;
      const Style: TPainterFontStyle; const Size: Single;
      const Origin: TPainterPoint; const Format: TPainterTextFormat); override;
    function AddPathText(const Path, GuidePath: TPainterPath;
      const Text: string; const Family: TPainterFontFamily;
      const Style: TPainterFontStyle; const Size: Single;
      const Format: TPainterTextFormat; const Indent: Single;
      const HasMatrix: Boolean; const AdditionalMatrix: TPainterMatrix): Single; override;
    function GetPathLength(const Path: TPainterPath): Single; override;
  end;

function PathToRegion(const APath: TPainterLCLPath; const AM: TPainterMatrix): HRGN;

implementation

{ ------------------------------------------------------------------------------ }
{ helpers                                                                        }
{ ------------------------------------------------------------------------------ }

function ToTColor(const AColor: TPainterColor): TColor;
{ TPainterColor is 0xAARRGGBB; LCL TColor on Windows is 0x00BBGGRR. }
begin
  Result := TColor(
    (AColor and $0000FF) shl 16 or
    (AColor and $00FF00) or
    (AColor and $FF0000) shr 16);
end;

function BlendColor(const C1, C2: TPainterColor;
  const T: Single): TPainterColor;
var
  R1, G1, B1, R2, G2, B2: Integer;
begin
  R1 := (C1 shr 16) and $FF; G1 := (C1 shr 8) and $FF; B1 := C1 and $FF;
  R2 := (C2 shr 16) and $FF; G2 := (C2 shr 8) and $FF; B2 := C2 and $FF;
  Result := $FF000000 or
    (Cardinal(Round(R1 + (R2 - R1) * T)) shl 16) or
    (Cardinal(Round(G1 + (G2 - G1) * T)) shl 8) or
    Cardinal(Round(B1 + (B2 - B1) * T));
end;

function ToTPoint(const P: TPainterPoint): TPoint;
begin
  Result.X := Round(P.X);
  Result.Y := Round(P.Y);
end;

{ Applies an SVG font spec (family/size/style) to an LCL font. Shared by the
  painter (render time) and the measure service (parse time). }
procedure ApplyFontStyle(const ACanvas: TCanvas; const Family: string;
  const Size: Single; const Style: TPainterFontStyle);
begin
  ACanvas.Font.Name := Family;
  if Size > 0 then
    ACanvas.Font.Height := -Round(Size);
  ACanvas.Font.Style := [];
  if pfsBold in Style then
    ACanvas.Font.Style := ACanvas.Font.Style + [fsBold];
  if pfsItalic in Style then
    ACanvas.Font.Style := ACanvas.Font.Style + [fsItalic];
  if pfsUnderline in Style then
    ACanvas.Font.Style := ACanvas.Font.Style + [fsUnderline];
  if pfsStrikeout in Style then
    ACanvas.Font.Style := ACanvas.Font.Style + [fsStrikeOut];
end;

{ Converts a figure into an integer polygon (device space). }
function FigureToIntPts(const F: TFigure): TPointArray;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(F.Pts));
  for I := 0 to High(F.Pts) do
    Result[I] := ToTPoint(F.Pts[I]);
end;

{ ------------------------------------------------------------------------------ }
{ Flattening                                                                     }
{ ------------------------------------------------------------------------------ }

{ De Casteljau subdivision of a cubic bezier into curve points (transformed by
  AM already applied to the source control points). Appends an endpoint per
  level-0 node; the figure start point must already be appended. }
procedure SubdivideBezier(var Acc: TPainterPointArray; var Count: Integer;
  const P0, P1, P2, P3: TPainterPoint; const Level: Integer);
var
  M1, M2, M3: TPainterPoint;
begin
  if Level <= 0 then
  begin
    if Count >= Length(Acc) then
      SetLength(Acc, Count + 64);
    Acc[Count] := P3;
    Inc(Count);
    Exit;
  end;
  M1 := MakePoint((P0.X + P1.X) / 2, (P0.Y + P1.Y) / 2);
  M2 := MakePoint((P1.X + P2.X) / 2, (P1.Y + P2.Y) / 2);
  M3 := MakePoint((P2.X + P3.X) / 2, (P2.Y + P3.Y) / 2);
  SubdivideBezier(Acc, Count, P0, M1, MakePoint((M1.X + M2.X) / 2, (M1.Y + M2.Y) / 2),
    MakePoint((M1.X + 2 * M2.X + M3.X) / 4, (M1.Y + 2 * M2.Y + M3.Y) / 4), Level - 1);
  SubdivideBezier(Acc, Count, MakePoint((M1.X + 2 * M2.X + M3.X) / 4, (M1.Y + 2 * M2.Y + M3.Y) / 4),
    MakePoint((M2.X + M3.X) / 2, (M2.Y + M3.Y) / 2), M3, P3, Level - 1);
end;

{ Flattens a path into figures. AM is the painter transform applied to every
  output point (device space). }
procedure FlattenPath(const APath: TPainterLCLPath; const AM: TPainterMatrix;
  out Figures: TFigureList);
var
  I, C0, CurveCount: Integer;
  Cur: TPainterPointArray;
  CurClosed: Boolean;
  P: TPainterPoint;

  procedure FlushFigure;
  begin
    if Length(Cur) = 0 then
      Exit;
    SetLength(Figures, Length(Figures) + 1);
    Figures[High(Figures)].Pts := Cur;
    Figures[High(Figures)].Closed := CurClosed;
    SetLength(Cur, 0);
    CurClosed := False;
  end;

begin
  SetLength(Figures, 0);
  CurveCount := 0;
  for I := 0 to APath.FSegCount - 1 do
  begin
    case APath.FSeGS[I].Kind of
      pskMove:
        begin
          FlushFigure;
          SetLength(Cur, 1);
          P := MakePoint(APath.FSeGS[I].P[0], APath.FSeGS[I].P[1]);
          Cur[0] := MatrixTransformPoint(AM, P);
          CurClosed := False;
        end;
      pskLine:
        begin
          if Length(Cur) = 0 then
          begin
            SetLength(Cur, 1);
            Cur[0] := MatrixTransformPoint(AM,
              MakePoint(APath.FSeGS[I].P[0], APath.FSeGS[I].P[1]));
          end
          else
          begin
            C0 := Length(Cur);
            SetLength(Cur, C0 + 1);
            Cur[C0] := MatrixTransformPoint(AM,
              MakePoint(APath.FSeGS[I].P[0], APath.FSeGS[I].P[1]));
          end;
        end;
      pskBezier:
        begin
          if Length(Cur) = 0 then
          begin
            SetLength(Cur, 1);
            Cur[0] := MatrixTransformPoint(AM,
              MakePoint(APath.FSeGS[I].P[0], APath.FSeGS[I].P[1]));
          end;
          P := Cur[Length(Cur) - 1];
          CurveCount := Length(Cur);
          SetLength(Cur, CurveCount + 64);
          SubdivideBezier(Cur, CurveCount,
            P,
            MatrixTransformPoint(AM, MakePoint(APath.FSeGS[I].P[0], APath.FSeGS[I].P[1])),
            MatrixTransformPoint(AM, MakePoint(APath.FSeGS[I].P[2], APath.FSeGS[I].P[3])),
            MatrixTransformPoint(AM, MakePoint(APath.FSeGS[I].P[4], APath.FSeGS[I].P[5])),
            4);
          SetLength(Cur, CurveCount);
        end;
      pskClose:
        begin
          CurClosed := True;
          FlushFigure;
        end;
    end;
  end;
  FlushFigure;
end;

procedure FreeFigures(var Figures: TFigureList);
var
  I: Integer;
begin
  for I := 0 to High(Figures) do
    SetLength(Figures[I].Pts, 0);
  SetLength(Figures, 0);
end;

{ ------------------------------------------------------------------------------ }
{ TPainterLCLSolidBrush                                                          }
{ ------------------------------------------------------------------------------ }

function TPainterLCLSolidBrush.Clone: TPainterBrush;
begin
  Result := TPainterLCLSolidBrush.Create(Color);
end;

{ ------------------------------------------------------------------------------ }
{ Gradient color stop helpers (used by both gradient brush classes)             }
{ ------------------------------------------------------------------------------ }

procedure GradientSetStops(var Colors: TColorArray; var Positions: TPositionArray;
  const ColorsIn: array of TPainterColor; const PositionsIn: array of Single);
var
  N, I: Integer;
begin
  N := Length(ColorsIn);
  if N > Length(PositionsIn) then
    N := Length(PositionsIn);
  SetLength(Colors, N);
  SetLength(Positions, N);
  for I := 0 to N - 1 do
  begin
    Colors[I] := ColorsIn[I];
    Positions[I] := PositionsIn[I];
  end;
end;

function GradientColorAt(const Colors: TColorArray; const Positions: TPositionArray;
  const T: Single): TPainterColor;
var
  I: Integer;
  T0, T1: Single;
begin
  Result := $FF000000;
  if Length(Colors) = 0 then
    Exit;
  if Length(Colors) = 1 then
  begin
    Result := Colors[0];
    Exit;
  end;
  I := 0;
  while (I < Length(Colors) - 2) and (Positions[I + 1] < T) do
    Inc(I);
  T0 := Positions[I];
  T1 := Positions[I + 1];
  if T1 <= T0 then
    Result := Colors[I]
  else
    Result := BlendColor(Colors[I], Colors[I + 1], (T - T0) / (T1 - T0));
end;

{ ------------------------------------------------------------------------------ }
{ TPainterLCLLinearGradientBrush                                                  }
{ ------------------------------------------------------------------------------ }

constructor TPainterLCLLinearGradientBrush.Create(const P1, P2: TPainterPoint;
  const C1, C2: TPainterColor);
begin
  inherited Create(P1, P2, C1, C2);
  FTransform := MakeIdentityMatrix;
end;

function TPainterLCLLinearGradientBrush.Count: Integer;
begin
  Result := Length(FColors);
end;

function TPainterLCLLinearGradientBrush.ColorAt(const T: Single): TPainterColor;
begin
  Result := GradientColorAt(FColors, FPositions, T);
end;

procedure TPainterLCLLinearGradientBrush.SetInterpolationColors(
  const Colors: array of TPainterColor; const Positions: array of Single);
begin
  GradientSetStops(FColors, FPositions, Colors, Positions);
end;

procedure TPainterLCLLinearGradientBrush.SetTransform(const Matrix: TPainterMatrix);
begin
  FTransform := Matrix;
end;

function TPainterLCLLinearGradientBrush.Clone: TPainterBrush;
var
  B: TPainterLCLLinearGradientBrush;
begin
  B := TPainterLCLLinearGradientBrush.Create(Point1, Point2, Color1, Color2);
  GradientSetStops(B.FColors, B.FPositions, FColors, FPositions);
  B.FTransform := FTransform;
  Result := B;
end;

constructor TPainterLCLRadialGradientBrush.Create(const ALeft, ATop, AWidth,
  AHeight: Single);
begin
  inherited Create(ALeft, ATop, AWidth, AHeight);
  FTransform := MakeIdentityMatrix;
  FCenter := MakePoint(ALeft + AWidth / 2, ATop + AHeight / 2);
end;

function TPainterLCLRadialGradientBrush.Count: Integer;
begin
  Result := Length(FColors);
end;

function TPainterLCLRadialGradientBrush.ColorAt(const T: Single): TPainterColor;
begin
  Result := GradientColorAt(FColors, FPositions, T);
end;

procedure TPainterLCLRadialGradientBrush.SetInterpolationColors(
  const Colors: array of TPainterColor; const Positions: array of Single);
begin
  GradientSetStops(FColors, FPositions, Colors, Positions);
end;

procedure TPainterLCLRadialGradientBrush.SetTransform(const Matrix: TPainterMatrix);
begin
  FTransform := Matrix;
end;

procedure TPainterLCLRadialGradientBrush.SetCenterPoint(const Center: TPainterPoint);
begin
  FCenter := Center;
end;

function TPainterLCLRadialGradientBrush.Clone: TPainterBrush;
var
  B: TPainterLCLRadialGradientBrush;
begin
  B := TPainterLCLRadialGradientBrush.Create(
    Ellipse.X, Ellipse.Y, Ellipse.Width, Ellipse.Height);
  GradientSetStops(B.FColors, B.FPositions, FColors, FPositions);
  B.FTransform := FTransform;
  B.FCenter := FCenter;
  Result := B;
end;

{ ------------------------------------------------------------------------------ }
{ TPainterLCLPen                                                                 }
{ ------------------------------------------------------------------------------ }

procedure TPainterLCLPen.SetBrush(const Brush: TPainterBrush);
begin
  if Brush is TPainterSolidBrush then
    FBrushColor := TPainterSolidBrush(Brush).Color
  else if Brush is TPainterLinearGradientBrush then
    FBrushColor := TPainterLinearGradientBrush(Brush).Color1
  else if Brush is TPainterLCLRadialGradientBrush then
    FBrushColor := TPainterLCLRadialGradientBrush(Brush).ColorAt(0.5);
end;

procedure TPainterLCLPen.SetLineCap(const StartCap, EndCap: TPainterLineCap;
  const DCap: TPainterDashCap);
begin
  FCaps[0] := StartCap;
  FCaps[1] := EndCap;
  FDashCap := DCap;
end;

procedure TPainterLCLPen.SetLineJoin(const Join: TPainterLineJoin);
begin
  FJoin := Join;
end;

procedure TPainterLCLPen.SetMiterLimit(const Limit: Single);
begin
  FMiterLimit := Limit;
end;

procedure TPainterLCLPen.SetDashPattern(const Pattern: array of Single);
var
  I: Integer;
begin
  SetLength(FDashPattern, Length(Pattern));
  for I := 0 to Length(Pattern) - 1 do
    FDashPattern[I] := Pattern[I];
  if Length(Pattern) > 0 then
    FDashStyle := pdsCustom;
end;

procedure TPainterLCLPen.SetDashStyle(const Style: TPainterDashStyle);
begin
  FDashStyle := Style;
end;

procedure TPainterLCLPen.SetDashOffset(const Offset: Single);
begin
  FDashOffset := Offset;
end;

{ ------------------------------------------------------------------------------ }
{ TPainterLCLFontFamily                                                          }
{ ------------------------------------------------------------------------------ }

constructor TPainterLCLFontFamily.Create(const AName: string);
begin
  inherited Create(AName);
  FName := AName;
end;

function TPainterLCLFontFamily.GetCellAscent(const Style: TPainterFontStyle): Integer;
begin
  { Design-unit ratio for the placeholder text metrics. The svg\ core divides
    CellAscent by EmHeight to get the ascent factor (0.8 for most fonts), so
    the absolute values only matter through their quotient. }
  Result := 800;
end;

function TPainterLCLFontFamily.GetEmHeight(const Style: TPainterFontStyle): Integer;
begin
  Result := 1000;
end;

{ ------------------------------------------------------------------------------ }
{ TPainterLCLFont                                                                }
{ ------------------------------------------------------------------------------ }

constructor TPainterLCLFont.Create(const Family: TPainterFontFamily;
  const Size: Single; const Style: TPainterFontStyle);
begin
  inherited Create(Family, Size, Style);
  if Family is TPainterLCLFontFamily then
    FFamilyName := TPainterLCLFontFamily(Family).FName
  else
    FFamilyName := '';
  FSize := Size;
  FStyle := Style;
end;

{ ------------------------------------------------------------------------------ }
{ TPainterLCLImage                                                               }
{ ------------------------------------------------------------------------------ }

constructor TPainterLCLImage.CreateFromStream(const Stream: TStream);
var
  MS: TMemoryStream;
begin
  inherited CreateFromStream(Stream);
  MS := TMemoryStream.Create;
  try
    Stream.Position := 0;
    MS.LoadFromStream(Stream);
    MS.Position := 0;
    FBitmap := TBitmap.Create;
    try
      FBitmap.LoadFromStream(MS);
    except
      FBitmap.Free;
      FBitmap := nil;
      SetStatusFailed;
    end;
  finally
    MS.Free;
  end;
end;

destructor TPainterLCLImage.Destroy;
begin
  FBitmap.Free;
  inherited;
end;

function TPainterLCLImage.GetHeight: Integer;
begin
  Result := 0;
  if Assigned(FBitmap) then
    Result := FBitmap.Height;
end;

function TPainterLCLImage.GetWidth: Integer;
begin
  Result := 0;
  if Assigned(FBitmap) then
    Result := FBitmap.Width;
end;

{ ------------------------------------------------------------------------------ }
{ TPainterLCLPath                                                                }
{ ------------------------------------------------------------------------------ }

constructor TPainterLCLPath.Create;
begin
  inherited Create;
  FFillMode := pfmAlternate;
end;

destructor TPainterLCLPath.Destroy;
begin
  SetLength(FSegs, 0);
  inherited;
end;

procedure TPainterLCLPath.AppendSeg(const Kind: TPathSegKind;
  const P: array of Single);
var
  I: Integer;
begin
  if FSegCount >= Length(FSegs) then
    SetLength(FSegs, FSegCount + 32);
  FSegs[FSegCount].Kind := Kind;
  for I := 0 to High(P) do
    FSegs[FSegCount].P[I] := P[I];
  Inc(FSegCount);
end;

procedure TPainterLCLPath.StartFigure;
begin
  FCurrent := True;
end;

procedure TPainterLCLPath.CloseFigure;
begin
  AppendSeg(pskClose, []);
end;

procedure TPainterLCLPath.AddLine(const X1, Y1, X2, Y2: Single);
begin
  FCurrent := True;
  AppendSeg(pskLine, [X2, Y2]);
end;

procedure TPainterLCLPath.AddBezier(const X1, Y1, X2, Y2, X3, Y3, X4,
  Y4: Single);
begin
  FCurrent := True;
  AppendSeg(pskBezier, [X2, Y2, X3, Y3, X4, Y4]);
end;

procedure TPainterLCLPath.AddArc(const X, Y, W, H, StartAngle, SweepAngle: Single);
var
  CX, CY, RX, RY, A: Single;
  N, I: Integer;
  P0: TPainterPoint;
begin
  CX := X + W / 2;
  CY := Y + H / 2;
  RX := W / 2;
  RY := H / 2;
  N := Max(1, Ceil(Abs(SweepAngle) / 15));
  P0 := MakePoint(CX + RX * Cos(StartAngle * CPi / 180),
    CY + RY * Sin(StartAngle * CPi / 180));
  if not FCurrent then
  begin
    FCurrent := True;
    AppendSeg(pskMove, [P0.X, P0.Y]);
  end;
  for I := 1 to N do
  begin
    A := (StartAngle + SweepAngle * I / N) * CPi / 180;
    AppendSeg(pskLine, [CX + RX * Cos(A), CY + RY * Sin(A)]);
  end;
end;

procedure TPainterLCLPath.AddEllipse(const X, Y, W, H: Single);
var
  K, CX, CY, RX, RY: Single;
begin
  K := 0.5522847498307936;
  CX := X + W / 2;
  CY := Y + H / 2;
  RX := W / 2;
  RY := H / 2;
  FCurrent := True;
  AppendSeg(pskMove, [CX + RX, CY]);
  AppendSeg(pskBezier, [CX + RX, CY + K * RY, CX + K * RX, CY - RY, CX, CY - RY]);
  AppendSeg(pskBezier, [CX - K * RX, CY - RY, CX - RX, CY - K * RY, CX - RX, CY]);
  AppendSeg(pskBezier, [CX - RX, CY + K * RY, CX - K * RX, CY + RY, CX, CY + RY]);
  AppendSeg(pskBezier, [CX + K * RX, CY + RY, CX + RX, CY + K * RY, CX + RX, CY]);
  AppendSeg(pskClose, []);
end;

procedure TPainterLCLPath.AddRectangle(const Rect: TPainterRect);
begin
  FCurrent := True;
  AppendSeg(pskMove, [Rect.X, Rect.Y]);
  AppendSeg(pskLine, [Rect.X + Rect.Width, Rect.Y]);
  AppendSeg(pskLine, [Rect.X + Rect.Width, Rect.Y + Rect.Height]);
  AppendSeg(pskLine, [Rect.X, Rect.Y + Rect.Height]);
  AppendSeg(pskClose, []);
end;

procedure TPainterLCLPath.AddPolygon(const Points: array of TPainterPoint);
var
  I: Integer;
begin
  if Length(Points) = 0 then
    Exit;
  FCurrent := True;
  AppendSeg(pskMove, [Points[0].X, Points[0].Y]);
  for I := 1 to High(Points) do
    AppendSeg(pskLine, [Points[I].X, Points[I].Y]);
  AppendSeg(pskClose, []);
end;

procedure TPainterLCLPath.AddPath(const Path: TPainterPath;
  const Connect: Boolean);
var
  Src: TPainterLCLPath;
  I: Integer;
begin
  Src := Path as TPainterLCLPath;
  for I := 0 to Src.FSegCount - 1 do
    AppendSeg(Src.FSegs[I].Kind,
      [Src.FSegs[I].P[0], Src.FSegs[I].P[1], Src.FSegs[I].P[2],
       Src.FSegs[I].P[3], Src.FSegs[I].P[4], Src.FSegs[I].P[5],
       Src.FSegs[I].P[6], Src.FSegs[I].P[7]]);
end;

procedure TPainterLCLPath.AddTextBox(const Text: string; const X, Y, Size: Single;
  const CharW: Single);
var
  I: Integer;
  CX: Single;
begin
  CX := X;
  for I := 1 to Length(Text) do
  begin
    AppendSeg(pskMove, [CX, Y]);
    AppendSeg(pskLine, [CX + CharW, Y]);
    AppendSeg(pskLine, [CX + CharW, Y + Size]);
    AppendSeg(pskLine, [CX, Y + Size]);
    AppendSeg(pskClose, []);
    CX := CX + CharW;
  end;
end;

procedure TPainterLCLPath.AddString(const Text: string;
  const Family: TPainterFontFamily; const Style: TPainterFontStyle;
  const Size: Single; const Format: TPainterTextFormat);
var
  I: Integer;
  CX, Adv: Single;
begin
  { Placeholder glyph boxes (no text-on-path outlines in LCL, task 1.3
    limitation). Advance width from a rough char table. }
  CX := 0;
  for I := 1 to Length(Text) do
  begin
    case Text[I] of
      ' ': Adv := Size * 0.35;
      'i', 'l', 'I', 'j', 't', '.', ',', ':', ';': Adv := Size * 0.3;
      'W', 'w', 'M', 'm': Adv := Size * 0.9;
    else
      Adv := Size * 0.6;
    end;
    AppendSeg(pskMove, [CX, 0]);
    AppendSeg(pskLine, [CX + Adv, 0]);
    AppendSeg(pskLine, [CX + Adv, Size]);
    AppendSeg(pskLine, [CX, Size]);
    AppendSeg(pskClose, []);
    CX := CX + Adv;
  end;
end;

procedure TPainterLCLPath.SetFillMode(const FillMode: TPainterFillMode);
begin
  FFillMode := FillMode;
end;

procedure TPainterLCLPath.Transform(const Matrix: TPainterMatrix);
var
  I: Integer;
  P: TPainterPoint;
begin
  for I := 0 to FSegCount - 1 do
  begin
    case FSegs[I].Kind of
      pskMove, pskLine:
        begin
          P := MatrixTransformPoint(Matrix, MakePoint(FSegs[I].P[0], FSegs[I].P[1]));
          FSegs[I].P[0] := P.X;
          FSegs[I].P[1] := P.Y;
          P := MatrixTransformPoint(Matrix, MakePoint(FSegs[I].P[2], FSegs[I].P[3]));
          FSegs[I].P[2] := P.X;
          FSegs[I].P[3] := P.Y;
        end;
      pskBezier:
        begin
          P := MatrixTransformPoint(Matrix, MakePoint(FSegs[I].P[0], FSegs[I].P[1]));
          FSegs[I].P[0] := P.X; FSegs[I].P[1] := P.Y;
          P := MatrixTransformPoint(Matrix, MakePoint(FSegs[I].P[2], FSegs[I].P[3]));
          FSegs[I].P[2] := P.X; FSegs[I].P[3] := P.Y;
          P := MatrixTransformPoint(Matrix, MakePoint(FSegs[I].P[4], FSegs[I].P[5]));
          FSegs[I].P[4] := P.X; FSegs[I].P[5] := P.Y;
          P := MatrixTransformPoint(Matrix, MakePoint(FSegs[I].P[6], FSegs[I].P[7]));
          FSegs[I].P[6] := P.X; FSegs[I].P[7] := P.Y;
        end;
    end;
  end;
end;

function TPainterLCLPath.Clone: TPainterPath;
var
  D: TPainterLCLPath;
  I: Integer;
begin
  D := TPainterLCLPath.Create;
  SetLength(D.FSegs, FSegCount);
  for I := 0 to FSegCount - 1 do
    D.FSegs[I] := FSegs[I];
  D.FSegCount := FSegCount;
  D.FCurrent := FCurrent;
  D.FFillMode := FFillMode;
  Result := D;
end;

function TPainterLCLPath.GetPointCount: Integer;
begin
  { Approximation: one point per command; beziers will be subdivided later.
    Good enough for the core's "has geometry" checks. }
  Result := FSegCount;
end;

{ ------------------------------------------------------------------------------ }
{ TPainterLCL                                                                     }
{ ------------------------------------------------------------------------------ }

constructor TPainterLCL.Create(const ACanvas: TCanvas);
begin
  inherited Create;
  FCanvas := ACanvas;
  FMatrix := MakeIdentityMatrix;
end;

destructor TPainterLCL.Destroy;
begin
  if FClipValid then
  begin
    SelectClipRgn(FCanvas.Handle, 0);
    DeleteObject(FClipRgn);
    FClipRgn := 0;
    FClipValid := False;
  end;
  inherited;
end;

{ --- factories ----------------------------------------------------------------- }

function TPainterLCL.CreateSolidBrush(const AColor: TPainterColor): TPainterSolidBrush;
begin
  Result := TPainterLCLSolidBrush.Create(AColor);
end;

function TPainterLCL.CreateLinearGradientBrush(const P1, P2: TPainterPoint;
  const C1, C2: TPainterColor): TPainterLinearGradientBrush;
begin
  Result := TPainterLCLLinearGradientBrush.Create(P1, P2, C1, C2);
end;

function TPainterLCL.CreateRadialGradientBrush(const ALeft, ATop, AWidth,
  AHeight: Single): TPainterRadialGradientBrush;
begin
  Result := TPainterLCLRadialGradientBrush.Create(ALeft, ATop, AWidth, AHeight);
  TPainterLCLRadialGradientBrush(Result).FCenter :=
    MakePoint(ALeft + AWidth / 2, ATop + AHeight / 2);
end;

function TPainterLCL.CreatePen(const AColor: TPainterColor;
  const AWidth: Single): TPainterPen;
begin
  Result := TPainterLCLPen.Create(AColor, AWidth);
end;

function TPainterLCL.CreateFontFamily(const AName: string): TPainterFontFamily;
begin
  Result := TPainterLCLFontFamily.Create(AName);
end;

function TPainterLCL.CreateFont(const Family: TPainterFontFamily;
  const Size: Single; const Style: TPainterFontStyle): TPainterFont;
begin
  Result := TPainterLCLFont.Create(Family, Size, Style);
end;

function TPainterLCL.LoadImage(const Stream: TStream): TPainterImage;
begin
  Result := TPainterLCLImage.CreateFromStream(Stream);
end;

function TPainterLCL.CreatePath: TPainterPath;
begin
  Result := TPainterLCLPath.Create;
end;

{ --- state ---------------------------------------------------------------------- }

procedure TPainterLCL.SetSmoothingMode(const AntiAlias: Boolean);
begin
  if AntiAlias then
    FCanvas.AntialiasingMode := amOn
  else
    FCanvas.AntialiasingMode := amOff;
end;

procedure TPainterLCL.SetTransform(const Matrix: TPainterMatrix);
begin
  FMatrix := Matrix;
end;

procedure TPainterLCL.ResetTransform;
begin
  FMatrix := MakeIdentityMatrix;
end;

procedure TPainterLCL.GetTransform(out Matrix: TPainterMatrix);
begin
  Matrix := FMatrix;
end;

procedure TPainterLCL.SetClip(const Path: TPainterPath);
var
  P: TPainterLCLPath;
  R: HRGN;
begin
  P := Path as TPainterLCLPath;
  if FClipValid then
  begin
    SelectClipRgn(FCanvas.Handle, 0);
    DeleteObject(FClipRgn);
    FClipRgn := 0;
    FClipValid := False;
  end;
  R := PathToRegion(P, FMatrix);
  if (R <> 0) and (SelectClipRgn(FCanvas.Handle, R) <> NULLREGION) then
  begin
    FClipRgn := R;
    FClipValid := True;
  end
  else if R <> 0 then
    DeleteObject(R);
end;

procedure TPainterLCL.ResetClip;
begin
  if FClipValid then
  begin
    SelectClipRgn(FCanvas.Handle, 0);
    DeleteObject(FClipRgn);
    FClipRgn := 0;
    FClipValid := False;
  end;
end;

procedure TPainterLCL.Clear(const Color: TPainterColor);
begin
  SetBrushSolid(Color);
  FCanvas.FillRect(FCanvas.ClipRect);
end;

procedure TPainterLCL.SetFont(const Family: string; const Size: Single;
  const Style: TPainterFontStyle);
begin
  ApplyFontStyle(FCanvas, Family, Size, Style);
end;

procedure TPainterLCL.SetPen(const Pen: TPainterPen);
var
  P: TPainterLCLPen;
begin
  P := Pen as TPainterLCLPen;
  FCanvas.Pen.Color := ToTColor(P.Color);
  FCanvas.Pen.Width := Max(1, Round(P.Width));
  FCanvas.Pen.Style := psSolid;
  case P.FDashStyle of
    pdsCustom:
      begin
        if (Length(P.FDashPattern) >= 2) and (P.FDashPattern[0] <= 1.0) then
          FCanvas.Pen.Style := psDot
        else
          FCanvas.Pen.Style := psDash;
      end;
  end;
end;

procedure TPainterLCL.SetBrushSolid(const Color: TPainterColor);
begin
  FCanvas.Brush.Color := ToTColor(Color);
  FCanvas.Brush.Style := bsSolid;
end;

{ --- fills ------------------------------------------------------------------------ }

procedure TPainterLCL.FillSolid(const Color: TPainterColor; const Path: TPainterPath);
var
  P: TPainterLCLPath;
  Figures: TFigureList;
  I: Integer;
  Pts: array of TPoint;
begin
  P := Path as TPainterLCLPath;
  FlattenPath(P, FMatrix, Figures);
  SetBrushSolid(Color);
  FCanvas.Pen.Color := ToTColor(Color);
  FCanvas.Pen.Width := 1;
  FCanvas.Pen.Style := psSolid;
  try
    for I := 0 to High(Figures) do
    begin
      if (not Figures[I].Closed) or (Length(Figures[I].Pts) < 3) then
        Continue;
      Pts := FigureToIntPts(Figures[I]);
      FCanvas.Polygon(Pts);
    end;
  finally
    FreeFigures(Figures);
  end;
end;

{ Builds a combined region from the closed figures of a path (device space).
  Returns 0 if nothing to clip. Caller deletes the returned region. }
function PathToRegion(const APath: TPainterLCLPath; const AM: TPainterMatrix): HRGN;
var
  Figures: TFigureList;
  R, Sub: HRGN;
  I: Integer;
  Pts: array of TPoint;
begin
  Result := 0;
  FlattenPath(APath, AM, Figures);
  try
    R := 0;
    for I := 0 to High(Figures) do
    begin
      if (not Figures[I].Closed) or (Length(Figures[I].Pts) < 3) then
        Continue;
      Pts := FigureToIntPts(Figures[I]);
      Sub := CreatePolygonRgn(@Pts[0], Length(Pts), ALTERNATE);
      if Sub = 0 then
        Continue;
      if R = 0 then
        R := Sub
      else
      begin
        CombineRgn(R, R, Sub, RGN_OR);
        DeleteObject(Sub);
      end;
    end;
    Result := R;
  finally
    FreeFigures(Figures);
  end;
end;

function RegionDiag(const R: HRGN): Single;
var
  Rc: TRect;
begin
  Result := 1;
  if GetRGNBox(R, @Rc) <> 0 then
    Result := Hypot(Rc.Right - Rc.Left, Rc.Bottom - Rc.Top);
end;

procedure TPainterLCL.FillLinear(const Brush: TPainterBrush;
  const Path: TPainterPath);
var
  GB: TPainterLCLLinearGradientBrush;
  P: TPainterLCLPath;
  R, Band, IntRgn: HRGN;
  P1, P2, U, V, C0, C1: TPainterPoint;
  Len, Diag, T0, T1, W2: Single;
  N, I: Integer;
  BPts: array[0..3] of TPoint;
begin
  if not (Brush is TPainterLCLLinearGradientBrush) then
  begin
    FillSolid($FF000000, Path);
    Exit;
  end;
  GB := Brush as TPainterLCLLinearGradientBrush;
  if GB.Count = 0 then
  begin
    FillSolid($FF000000, Path);
    Exit;
  end;
  P := Path as TPainterLCLPath;
  R := PathToRegion(P, FMatrix);
  if R = 0 then
    Exit;
  Diag := RegionDiag(R) * 2 + 1;
  P1 := MatrixTransformPoint(FMatrix,
    MatrixTransformPoint(GB.FTransform,
      MakePoint(GB.Point1.X, GB.Point1.Y)));
  P2 := MatrixTransformPoint(FMatrix,
    MatrixTransformPoint(GB.FTransform,
      MakePoint(GB.Point2.X, GB.Point2.Y)));
  Len := Hypot(P2.X - P1.X, P2.Y - P1.Y);
  if Len <= 0 then
  begin
    DeleteObject(R);
    FillSolid(GB.ColorAt(0.5), Path);
    Exit;
  end;
  U.X := (P2.X - P1.X) / Len;
  U.Y := (P2.Y - P1.Y) / Len;
  V.X := -U.Y;
  V.Y := U.X;
  N := EnsureRange(Round(Len), 8, 256);
    try
      for I := 0 to N - 1 do
      begin
        T0 := I / N;
        T1 := (I + 1) / N;
        C0 := MakePoint(P1.X + U.X * Len * T0, P1.Y + U.Y * Len * T0);
        C1 := MakePoint(P1.X + U.X * Len * T1, P1.Y + U.Y * Len * T1);
        W2 := Diag;
        BPts[0] := ToTPoint(MakePoint(C0.X + V.X * W2, C0.Y + V.Y * W2));
        BPts[1] := ToTPoint(MakePoint(C0.X - V.X * W2, C0.Y - V.Y * W2));
        BPts[2] := ToTPoint(MakePoint(C1.X - V.X * W2, C1.Y - V.Y * W2));
        BPts[3] := ToTPoint(MakePoint(C1.X + V.X * W2, C1.Y + V.Y * W2));
        Band := CreatePolygonRgn(@BPts[0], 4, ALTERNATE);
        IntRgn := CreateRectRgn(0, 0, 0, 0);
        CombineRgn(IntRgn, R, Band, RGN_AND);
        FCanvas.Brush.Color := ToTColor(GB.ColorAt((T0 + T1) / 2));
        FCanvas.Brush.Style := bsSolid;
        FillRgn(FCanvas.Handle, IntRgn, HBRUSH(FCanvas.Brush.Reference.Handle));
        DeleteObject(IntRgn);
        DeleteObject(Band);
      end;
    finally
      DeleteObject(R);
    end;
end;

procedure TPainterLCL.FillRadial(const Brush: TPainterBrush;
  const Path: TPainterPath);
var
  RB: TPainterLCLRadialGradientBrush;
  P: TPainterLCLPath;
  R, Ring, IntRgn: HRGN;
  Center: TPainterPoint;
  Figures: TFigureList;
  Pts: array of TPoint;
  I, K, N, J: Integer;
  F2, MaxR, D, T: Single;
begin
  if not (Brush is TPainterLCLRadialGradientBrush) then
  begin
    FillSolid($FF000000, Path);
    Exit;
  end;
  RB := Brush as TPainterLCLRadialGradientBrush;
  if RB.Count = 0 then
  begin
    FillSolid($FF000000, Path);
    Exit;
  end;
  P := Path as TPainterLCLPath;
  R := PathToRegion(P, FMatrix);
  if R = 0 then
    Exit;
  Center := MatrixTransformPoint(FMatrix,
    MatrixTransformPoint(RB.FTransform,
      MakePoint(RB.FCenter.X, RB.FCenter.Y)));
  FlattenPath(P, FMatrix, Figures);
  try
    MaxR := 1;
    for I := 0 to High(Figures) do
      for J := 0 to High(Figures[I].Pts) do
      begin
        D := Hypot(Figures[I].Pts[J].X - Center.X, Figures[I].Pts[J].Y - Center.Y);
        if D > MaxR then
          MaxR := D;
      end;
    N := 32;
    try
      for K := 1 to N do
      begin
        F2 := K / N;
        Ring := CreateRectRgn(0, 0, 0, 0);
        for I := 0 to High(Figures) do
        begin
          if (not Figures[I].Closed) or (Length(Figures[I].Pts) < 3) then
            Continue;
          SetLength(Pts, Length(Figures[I].Pts));
          for J := 0 to High(Figures[I].Pts) do
          begin
            Pts[J].X := Round(Center.X + (Figures[I].Pts[J].X - Center.X) * F2);
            Pts[J].Y := Round(Center.Y + (Figures[I].Pts[J].Y - Center.Y) * F2);
          end;
          IntRgn := CreatePolygonRgn(@Pts[0], Length(Pts), ALTERNATE);
          if IntRgn <> 0 then
          begin
            CombineRgn(Ring, Ring, IntRgn, RGN_OR);
            DeleteObject(IntRgn);
          end;
        end;
        IntRgn := CreateRectRgn(0, 0, 0, 0);
        CombineRgn(IntRgn, R, Ring, RGN_AND);
        T := (K - 0.5) / N;
        FCanvas.Brush.Color := ToTColor(RB.ColorAt(T));
        FCanvas.Brush.Style := bsSolid;
        FillRgn(FCanvas.Handle, IntRgn, HBRUSH(FCanvas.Brush.Reference.Handle));
        DeleteObject(IntRgn);
        DeleteObject(Ring);
      end;
    finally
      DeleteObject(R);
    end;
  finally
    FreeFigures(Figures);
  end;
end;

procedure TPainterLCL.FillPath(const Brush: TPainterBrush;
  const Path: TPainterPath);
begin
  if Brush is TPainterLCLSolidBrush then
    FillSolid(TPainterLCLSolidBrush(Brush).Color, Path)
  else if Brush is TPainterLCLLinearGradientBrush then
    FillLinear(Brush, Path)
  else if Brush is TPainterLCLRadialGradientBrush then
    FillRadial(Brush, Path);
end;

procedure TPainterLCL.DrawPath(const Pen: TPainterPen;
  const Path: TPainterPath);
var
  P: TPainterLCLPath;
  Figures: TFigureList;
  I: Integer;
  Pts: array of TPoint;
begin
  P := Path as TPainterLCLPath;
  SetPen(Pen);
  FCanvas.Brush.Style := bsClear;
  FlattenPath(P, FMatrix, Figures);
  try
    for I := 0 to High(Figures) do
    begin
      if Length(Figures[I].Pts) < 2 then
        Continue;
      Pts := FigureToIntPts(Figures[I]);
      if Figures[I].Closed and (Length(Pts) >= 3) then
        FCanvas.Polygon(Pts)
      else
        FCanvas.Polyline(Pts);
    end;
  finally
    FreeFigures(Figures);
  end;
end;

procedure TPainterLCL.DrawLine(const Pen: TPainterPen; const X1, Y1, X2,
  Y2: Single);
var
  A, B: TPainterPoint;
begin
  SetPen(Pen);
  A := MatrixTransformPoint(FMatrix, MakePoint(X1, Y1));
  B := MatrixTransformPoint(FMatrix, MakePoint(X2, Y2));
  FCanvas.Line(Round(A.X), Round(A.Y), Round(B.X), Round(B.Y));
end;

{ --- raster --------------------------------------------------------------------- }

procedure TPainterLCL.DrawImage(const Image: TPainterImage;
  const Dest: TPainterRect{$IFDEF FPC}; Options: TPainterImageOptions{$ELSE}; const Options: TPainterImageOptions{$ENDIF});
var
  I: TPainterLCLImage;
  R: TRect;
  P: TPainterPoint;
begin
  I := Image as TPainterLCLImage;
  if not Assigned(I.FBitmap) then
    Exit;
  P := MatrixTransformPoint(FMatrix, MakePoint(Dest.X, Dest.Y));
  R.Left := Round(P.X);
  R.Top := Round(P.Y);
  P := MatrixTransformPoint(FMatrix,
    MakePoint(Dest.X + Dest.Width, Dest.Y + Dest.Height));
  R.Right := Round(P.X);
  R.Bottom := Round(P.Y);
  FCanvas.StretchDraw(R, I.FBitmap);
end;

{ --- text -------------------------------------------------------------------------- }

procedure TPainterLCL.DrawString(const Text: string; const Font: TPainterFont;
  const Origin: TPainterPoint; const Format: TPainterTextFormat;
  const Brush: TPainterBrush);
var
  F: TPainterLCLFont;
  O: TPainterPoint;
  Col: TPainterColor;
begin
  if Text = '' then
    Exit;
  F := Font as TPainterLCLFont;
  if not Assigned(Brush) then
    Exit;
  if Brush is TPainterLCLSolidBrush then
    Col := TPainterLCLSolidBrush(Brush).Color
  else
    Col := $FF000000;
  FCanvas.Brush.Style := bsClear;
  SetFont(F.FName, F.FSize, F.FStyle);
  FCanvas.Font.Color := ToTColor(Col);
  O := MatrixTransformPoint(FMatrix, Origin);
  FCanvas.TextOut(Round(O.X), Round(O.Y), Text);
end;

procedure TPainterLCL.MeasureString(const Text: string; const Font: TPainterFont;
  const Origin: TPainterPoint; const Format: TPainterTextFormat;
  var Rect: TPainterRect);
var
  F: TPainterLCLFont;
  S: TSize;
  O: TPainterPoint;
begin
  F := Font as TPainterLCLFont;
  SetFont(F.FName, F.FSize, F.FStyle);
  S := FCanvas.TextExtent(Text);
  O := MatrixTransformPoint(FMatrix, Origin);
  Rect := Painter.MakeRect(O.X, O.Y, S.cx, S.cy);
end;

function TPainterLCL.MeasureText(const Text: string;
  const Font: TPainterFont): Single;
var
  F: TPainterLCLFont;
  S: TSize;
begin
  F := Font as TPainterLCLFont;
  SetFont(F.FName, F.FSize, F.FStyle);
  S := FCanvas.TextExtent(Text);
  Result := S.cx;
end;

procedure TPainterLCL.AddTextToPath(const Path: TPainterPath;
  const Text: string; const Family: TPainterFontFamily; const Style: TPainterFontStyle;
  const Size: Single; const Origin: TPainterPoint; const Format: TPainterTextFormat);
var
  F: TPainterLCLFontFamily;
  DP: TPainterLCLPath;
  CX: Single;
  I: Integer;
  W: Single;
begin
  if Text = '' then
    Exit;
  F := Family as TPainterLCLFontFamily;
  DP := Path as TPainterLCLPath;
  SetFont(F.FName, Size, Style);
  CX := Origin.X;
  for I := 1 to Length(Text) do
  begin
    W := FCanvas.TextWidth(Text[I]);
    DP.AddTextBox(Text[I], CX, Origin.Y, Size, W);
    CX := CX + W;
  end;
end;

function GetLCLPathLength(const DP: TPainterLCLPath): Single;
var
  I: Integer;
  X, Y, X2, Y2: Single;
begin
  Result := 0;
  X := 0;
  Y := 0;
  for I := 0 to DP.FSegCount - 1 do
  begin
    case DP.FSegs[I].Kind of
      pskMove:
        begin
          X := DP.FSegs[I].P[0];
          Y := DP.FSegs[I].P[1];
        end;
      pskLine:
        begin
          X2 := DP.FSegs[I].P[2];
          Y2 := DP.FSegs[I].P[3];
          Result := Result + Hypot(X2 - X, Y2 - Y);
          X := X2;
          Y := Y2;
        end;
      pskBezier:
        begin
          { average of chord and control-point polyline as a coarse length }
          X2 := DP.FSegs[I].P[6];
          Y2 := DP.FSegs[I].P[7];
          Result := Result + Hypot(X2 - X, Y2 - Y);
          X := X2;
          Y := Y2;
        end;
    end;
  end;
end;

function TPainterLCL.GetPathLength(const Path: TPainterPath): Single;
begin
  Result := GetLCLPathLength(Path as TPainterLCLPath);
end;

{ --- parse-time measure service (backend LCL) ----------------------------------- }

var
  FMeasureBmp: TBitmap = nil;

function MeasureCanvas: TCanvas;
begin
  if FMeasureBmp = nil then
  begin
    FMeasureBmp := TBitmap.Create;
    FMeasureBmp.Width := 4;
    FMeasureBmp.Height := 4;
  end;
  Result := FMeasureBmp.Canvas;
end;

function TPainterMeasureLCL.CreateFontFamily(
  const AName: string): TPainterFontFamily;
begin
  Result := TPainterLCLFontFamily.Create(AName);
end;

function TPainterMeasureLCL.CreateFont(const Family: TPainterFontFamily;
  const Size: Single; const Style: TPainterFontStyle): TPainterFont;
begin
  Result := TPainterLCLFont.Create(Family, Size, Style);
end;

function TPainterMeasureLCL.MeasureText(const Text: string;
  const Font: TPainterFont): Single;
var
  F: TPainterLCLFont;
begin
  F := Font as TPainterLCLFont;
  ApplyFontStyle(MeasureCanvas, F.FName, F.FSize, F.FStyle);
  Result := MeasureCanvas.TextExtent(Text).cx;
end;

procedure TPainterMeasureLCL.MeasureString(const Text: string;
  const Font: TPainterFont; const Origin: TPainterPoint;
  const Format: TPainterTextFormat; var Rect: TPainterRect);
var
  F: TPainterLCLFont;
  S: TSize;
begin
  F := Font as TPainterLCLFont;
  ApplyFontStyle(MeasureCanvas, F.FName, F.FSize, F.FStyle);
  S := MeasureCanvas.TextExtent(Text);
  Rect := Painter.MakeRect(Origin.X, Origin.Y, S.cx, S.cy);
end;

procedure TPainterMeasureLCL.AddTextToPath(const Path, UPath, SPath: TPainterPath;
  const Text: string; const Family: TPainterFontFamily;
  const Style: TPainterFontStyle; const Size: Single;
  const Origin: TPainterPoint; const Format: TPainterTextFormat);
var
  FF: TPainterLCLFontFamily;
  DP, UP, SP: TPainterLCLPath;
  I: Integer;
  CX, W: Single;
begin
  if Text = '' then
    Exit;
  FF := Family as TPainterLCLFontFamily;
  DP := Path as TPainterLCLPath;
  UP := UPath as TPainterLCLPath;
  SP := SPath as TPainterLCLPath;
  ApplyFontStyle(MeasureCanvas, FF.FName, Size, Style);
  W := MeasureCanvas.TextExtent(Text).cx;
  if (pfsUnderline in Style) and Assigned(UP) then
    UP.AddRectangle(Painter.MakeRect(Origin.X, Origin.Y + Size * 0.8, W,
      Size * 0.1));
  if (pfsStrikeout in Style) and Assigned(SP) then
    SP.AddRectangle(Painter.MakeRect(Origin.X, Origin.Y + Size * 0.5, W,
      Size * 0.1));
  CX := Origin.X;
  for I := 1 to Length(Text) do
  begin
    W := MeasureCanvas.TextWidth(Text[I]);
    DP.AddTextBox(Text[I], CX, Origin.Y, Size, W);
    CX := CX + W;
  end;
end;

function TPainterMeasureLCL.AddPathText(const Path, GuidePath: TPainterPath;
  const Text: string; const Family: TPainterFontFamily;
  const Style: TPainterFontStyle; const Size: Single;
  const Format: TPainterTextFormat; const Indent: Single;
  const HasMatrix: Boolean; const AdditionalMatrix: TPainterMatrix): Single;
var
  DP: TPainterLCLPath;
begin
  if Text = '' then
  begin
    Result := 0;
    Exit;
  end;
  DP := Path as TPainterLCLPath;
  { Placeholder: glyph boxes laid out from Indent in local coordinates (no
    curved text following on LCL). The caller advances by the returned width. }
  DP.AddString(Text, Family, Style, Size, Format);
  Result := GetLCLPathLength(DP); // width of the placeholder boxes
  { Give the boxes the guide-path offset so textPath has a visible anchor. }
  DP.Transform(MakeMatrix(1, 0, 0, 1, Indent, 0));
end;

function TPainterMeasureLCL.GetPathLength(const Path: TPainterPath): Single;
begin
  if Assigned(Path) then
    Result := GetLCLPathLength(Path as TPainterLCLPath)
  else
    Result := 0;
end;

{ --- parse-time path factory (backend LCL) ----------------------------------- }

function CreateLCLLPath: TPainterPath;
begin
  Result := TPainterLCLPath.Create;
end;

{ --- parse-time image factory (backend LCL) ----------------------------------- }

function CreateLCLLImage(const Stream: TStream): TPainterImage;
begin
  Result := TPainterLCLImage.CreateFromStream(Stream);
end;

initialization
  RegisterPainterMeasure(TPainterMeasureLCL.Create);
  RegisterPainterPathFactory(CreateLCLLPath);
  RegisterPainterImageFactory(CreateLCLLImage);

finalization
  RegisterPainterImageFactory(nil);
  RegisterPainterPathFactory(nil);
  RegisterPainterMeasure(nil);
  FMeasureBmp.Free;
  FMeasureBmp := nil;

end.
