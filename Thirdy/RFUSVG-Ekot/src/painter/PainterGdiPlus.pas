unit PainterGdiPlus;

{ TPainterGdiPlus - GDI+ backend for TPainter.  Task 1.2 of the Delphi + Lazarus
  port. Implements the portable TPainter contract on top of the Windows GDI+ API
  (Winapi.GDIPAPI / Winapi.GDIPOBJ plus the repo's gdip\ helpers GDIPOBJ2,
  GDIPKerning, GDIPPathText).

  Delphi: compiles as-is.  Lazarus/Windows: the same code runs after task 3.5
  provides FPC ports of GDIPAPI/GDIPOBJ (and the gdip\ helpers are FPC-clean).
  The unit is already split by an FPC conditional so only the unit names change
  here.

  Known limitation (GDI+ itself): radial gradients are rendered as path
  gradient brushes, which are elliptical by nature - SVG focal offsets are
  approximated. Cross-platform code should use TPainterLCL. }

interface

{$IFDEF FPC}{$MODE Delphi}{$ENDIF}

uses
  Painter,
{$IFDEF FPC}
  Classes, SysUtils, Windows, GDIPAPI, GDIPOBJ, GDIPOBJ2, GDIPKerning,
  GDIPPathText;
{$ELSE}
  System.Classes, System.SysUtils, Winapi.Windows,
  Winapi.GDIPAPI, Winapi.GDIPOBJ, GDIPOBJ2, GDIPKerning, GDIPPathText;
{$ENDIF}

type
  { --- brush / pen / font / image / path GDI+ mappings --------------------- }
  TPainterGdiPlusSolidBrush = class(TPainterSolidBrush)
  private
    FGP: TGPSolidBrush;
  public
    constructor Create(const AColor: TPainterColor); reintroduce;
    destructor Destroy; override;
    { Takes ownership of an existing GDI+ solid brush (used during task 2.1 to
      bridge SVGPaint gradient/solid brushes into the painter model; task 2.2
      builds native TPainter resources instead). }
    class function Adopt(const ABrush: TGPSolidBrush): TPainterGdiPlusSolidBrush;
    function Clone: TPainterBrush; override;
    property GPBrush: TGPSolidBrush read FGP;
  end;

  TPainterGdiPlusLinearGradientBrush = class(TPainterLinearGradientBrush)
  private
    FGP: TGPLinearGradientBrush;
  public
    constructor Create(const P1, P2: TPainterPoint;
      const C1, C2: TPainterColor); reintroduce;
    destructor Destroy; override;
    class function Adopt(const ABrush: TGPLinearGradientBrush):
      TPainterGdiPlusLinearGradientBrush;
    procedure SetInterpolationColors(const Colors: array of TPainterColor;
      const Positions: array of Single); override;
    procedure SetTransform(const Matrix: TPainterMatrix); override;
    function Clone: TPainterBrush; override;
    property GPBrush: TGPLinearGradientBrush read FGP;
  end;

  TPainterGdiPlusRadialGradientBrush = class(TPainterRadialGradientBrush)
  private
    FGP: TGPPathGradientBrush;
  public
    constructor Create(const ALeft, ATop, AWidth, AHeight: Single); reintroduce;
    destructor Destroy; override;
    class function Adopt(const ABrush: TGPPathGradientBrush):
      TPainterGdiPlusRadialGradientBrush;
    procedure SetCenterPoint(const Center: TPainterPoint); override;
    procedure SetInterpolationColors(const Colors: array of TPainterColor;
      const Positions: array of Single); override;
    procedure SetTransform(const Matrix: TPainterMatrix); override;
    function Clone: TPainterBrush; override;
    property GPBrush: TGPPathGradientBrush read FGP;
  end;

  TPainterGdiPlusPen = class(TPainterPen)
  private
    FGP: TGPPen;
  public
    constructor Create(const AColor: TPainterColor;
      const AWidth: Single); reintroduce;
    destructor Destroy; override;
    procedure SetBrush(const Brush: TPainterBrush); override;
    procedure SetLineJoin(const Join: TPainterLineJoin); override;
    procedure SetMiterLimit(const Limit: Single); override;
    procedure SetLineCap(const StartCap, EndCap: TPainterLineCap;
      const DCap: TPainterDashCap); override;
    procedure SetDashPattern(const Pattern: array of Single); override;
    procedure SetDashStyle(const Style: TPainterDashStyle); override;
    procedure SetDashOffset(const Offset: Single); override;
    property GPPen: TGPPen read FGP;
  end;

  TPainterGdiPlusFontFamily = class(TPainterFontFamily)
  private
    FGP: TGPFontFamily;
  public
    constructor Create(const AName: string); reintroduce;
    destructor Destroy; override;
    function GetCellAscent(const Style: TPainterFontStyle): Integer; override;
    function GetEmHeight(const Style: TPainterFontStyle): Integer; override;
    property GPFontFamily: TGPFontFamily read FGP;
  end;

  TPainterGdiPlusFont = class(TPainterFont)
  private
    FGP: TGPFont;
  public
    constructor Create(const Family: TPainterFontFamily; const Size: Single;
      const Style: TPainterFontStyle); reintroduce;
    destructor Destroy; override;
    property GPFont: TGPFont read FGP;
  end;

  TPainterGdiPlusImage = class(TPainterImage)
  private
    FGP: TGPImage;
    FStream: TMemoryStream; // keeps source bytes alive while image is alive
  public
    constructor CreateFromStream(const Stream: TStream); override;
    destructor Destroy; override;
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    property GPImage: TGPImage read FGP;
  end;

  TPainterGdiPlusPath = class(TPainterPath)
  private
    FGP: TGPGraphicsPath2;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure StartFigure; override;
    procedure CloseFigure; override;
    procedure AddLine(const X1, Y1, X2, Y2: Single); override;
    procedure AddBezier(const X1, Y1, X2, Y2, X3, Y3, X4,
      Y4: Single); override;
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
    property GPPath: TGPGraphicsPath2 read FGP;
  end;

  { --- the painter --------------------------------------------------------- }
  TPainterGdiPlus = class(TPainter)
  private
    FGraphics: TGPGraphics;
  public
    { Factory that wraps an existing GDI+ graphics object (see agents.md:
      the contract's TPainter has no HDC constructor; backends provide
      their own factories). The caller keeps ownership of AGraphics. }
    constructor Create(const AGraphics: TGPGraphics); reintroduce;

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

    property Graphics: TGPGraphics read FGraphics;
  end;

  { GDI+ implementation of the parse-time measurement service (task 2.4).
    Registered on startup by this unit; the svg\ core uses it to measure text
    and build glyph paths before any rendering canvas exists. }
  TPainterMeasureGdiPlus = class(TPainterMeasure)
  private
    function GetGpStringFormat(const Format: TPainterTextFormat): TGPStringFormat;
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

  { Wraps an existing GDI+ brush (taking ownership) into a TPainterBrush so the
    svg\ core can keep using SVGPaint's GDI+ gradient factories during task 2.1.
    Returns nil (freeing ABrush) for unsupported brush types. }
function GdiPlusBrushToPainter(const ABrush: TGPBrush): TPainterBrush;

{ Returns the concrete GDI+ brush handle for a painter brush (nil if not a
  GDI+ backed brush). }
function GpBrushOf(const Brush: TPainterBrush): TGPBrush;

{ Bridge for legacy GDI+ entry points (TSVG.RenderToBitmap/Icon, VCL
  components) that still take/own GDI+ rects: converts between the portable
  TPainterRect and the GDI+ rect type. }
function ToGPRectF(const R: TPainterRect): TGPRectF;
function ToPainterRect(const R: TGPRectF): TPainterRect;

implementation

{ --- local helpers --------------------------------------------------------- }
function MakeGpPointF(const P: TPainterPoint): TGPPointF;
begin
  Result.X := P.X;
  Result.Y := P.Y;
end;

function MakeGpRectF(const R: TPainterRect): TGPRectF;
begin
  Result.X := R.X;
  Result.Y := R.Y;
  Result.Width := R.Width;
  Result.Height := R.Height;
end;

function MakeGpMatrix(const M: TPainterMatrix): TGPMatrix;
begin
  Result := TGPMatrix.Create(M.m11, M.m12, M.m21, M.m22, M.m31, M.m32);
end;

{ Builds the same GDI+ string format the svg\ core uses today: generic
  typographic layout, optionally measuring trailing spaces. }
function MakeGdiStringFormat(const Format: TPainterTextFormat): TGPStringFormat;
begin
  Result := TGPStringFormat.Create(TGPStringFormat.GenericTypographic);
  if Format.MeasureTrailingSpaces then
    Result.SetFormatFlags(StringFormatFlagsMeasureTrailingSpaces);
end;

const
  FillModeMap: array[TPainterFillMode] of TFillMode = (
    FillModeAlternate, FillModeWinding);

function ToGdipLineCap(const Cap: TPainterLineCap): TLineCap;
begin
  case Cap of
    plcFlat:   Result := LineCapFlat;
    plcRound:  Result := LineCapRound;
    plcSquare: Result := LineCapSquare;
  else
    Result := LineCapFlat;
  end;
end;

function ToGdipDashCap(const Cap: TPainterDashCap): TDashCap;
begin
  case Cap of
    pdcFlat:  Result := DashCapFlat;
    pdcRound: Result := DashCapRound;
  else
    Result := DashCapFlat;
  end;
end;

function ToGdipLineJoin(const Join: TPainterLineJoin): TLineJoin;
begin
  case Join of
    pljMiter:        Result := LineJoinMiter;
    pljRound:        Result := LineJoinRound;
    pljBevel:        Result := LineJoinBevel;
    pljMiterClipped: Result := LineJoinMiterClipped;
  else
    Result := LineJoinMiter;
  end;
end;

function ToGdipDashStyle(const Style: TPainterDashStyle): TDashStyle;
begin
  case Style of
    pdsSolid:  Result := DashStyleSolid;
    pdsCustom: Result := DashStyleCustom;
  else
    Result := DashStyleSolid;
  end;
end;

function FontStyleToGdiPlus(const Style: TPainterFontStyle): Integer;
begin
  Result := FontStyleRegular;
  if pfsBold in Style then
    Result := Result or FontStyleBold;
  if pfsItalic in Style then
    Result := Result or FontStyleItalic;
  if pfsUnderline in Style then
    Result := Result or FontStyleUnderline;
  if pfsStrikeout in Style then
    Result := Result or FontStyleStrikeout;
end;

{ Returns the concrete GDI+ brush handle for a painter brush (nil if not a
  GDI+ backed brush). }
function GpBrushOf(const Brush: TPainterBrush): TGPBrush;
begin
  Result := nil;
  if Brush is TPainterGdiPlusSolidBrush then
    Result := TPainterGdiPlusSolidBrush(Brush).GPBrush
  else if Brush is TPainterGdiPlusLinearGradientBrush then
    Result := TPainterGdiPlusLinearGradientBrush(Brush).GPBrush
  else if Brush is TPainterGdiPlusRadialGradientBrush then
    Result := TPainterGdiPlusRadialGradientBrush(Brush).GPBrush;
end;

function GdiPlusBrushToPainter(const ABrush: TGPBrush): TPainterBrush;
begin
  Result := nil;
  if ABrush is TGPLinearGradientBrush then
    Result := TPainterGdiPlusLinearGradientBrush.Adopt(TGPLinearGradientBrush(ABrush))
  else if ABrush is TGPSolidBrush then
    Result := TPainterGdiPlusSolidBrush.Adopt(TGPSolidBrush(ABrush))
  else if ABrush is TGPPathGradientBrush then
    Result := TPainterGdiPlusRadialGradientBrush.Adopt(TGPPathGradientBrush(ABrush))
  else
    ABrush.Free;
end;

{ --- TPainterGdiPlusSolidBrush ---------------------------------------------- }
constructor TPainterGdiPlusSolidBrush.Create(const AColor: TPainterColor);
begin
  inherited Create(AColor);
  FGP := TGPSolidBrush.Create(AColor);
  if FGP.GetLastStatus <> OK then
    SetStatusFailed;
end;

class function TPainterGdiPlusSolidBrush.Adopt(
  const ABrush: TGPSolidBrush): TPainterGdiPlusSolidBrush;
begin
  Result := TPainterGdiPlusSolidBrush.Create($FF000000);
  Result.FGP.Free;
  Result.FGP := ABrush;
  Result.SetStatusOK;
end;

destructor TPainterGdiPlusSolidBrush.Destroy;
begin
  FGP.Free;
  inherited;
end;

function TPainterGdiPlusSolidBrush.Clone: TPainterBrush;
begin
  Result := TPainterGdiPlusSolidBrush.Create(Color);
end;

{ --- TPainterGdiPlusLinearGradientBrush ------------------------------------- }
constructor TPainterGdiPlusLinearGradientBrush.Create(const P1, P2: TPainterPoint;
  const C1, C2: TPainterColor);
begin
  inherited Create(P1, P2, C1, C2);
  FGP := TGPLinearGradientBrush.Create(MakeGpPointF(P1), MakeGpPointF(P2), C1, C2);
  if FGP.GetLastStatus <> OK then
    SetStatusFailed;
end;

destructor TPainterGdiPlusLinearGradientBrush.Destroy;
begin
  FGP.Free;
  inherited;
end;

class function TPainterGdiPlusLinearGradientBrush.Adopt(
  const ABrush: TGPLinearGradientBrush): TPainterGdiPlusLinearGradientBrush;
begin
  Result := TPainterGdiPlusLinearGradientBrush.Create(
    Painter.MakePoint(0, 0), Painter.MakePoint(1, 1), $FF000000, $FF000000);
  Result.FGP.Free;
  Result.FGP := ABrush;
  Result.SetStatusOK;
end;

procedure TPainterGdiPlusLinearGradientBrush.SetInterpolationColors(
  const Colors: array of TPainterColor; const Positions: array of Single);
begin
  if Length(Colors) = 0 then
    Exit;
  FGP.SetInterpolationColors(PGPColor(@Colors[0]), PSingle(@Positions[0]),
    Length(Colors));
end;

procedure TPainterGdiPlusLinearGradientBrush.SetTransform(
  const Matrix: TPainterMatrix);
var
  M: TGPMatrix;
begin
  M := MakeGpMatrix(Matrix);
  try
    FGP.SetTransform(M);
  finally
    M.Free;
  end;
end;

function TPainterGdiPlusLinearGradientBrush.Clone: TPainterBrush;
begin
  Result := TPainterGdiPlusLinearGradientBrush.Create(Point1, Point2, Color1, Color2);
end;

{ --- TPainterGdiPlusRadialGradientBrush ------------------------------------- }
constructor TPainterGdiPlusRadialGradientBrush.Create(const ALeft, ATop, AWidth,
  AHeight: Single);
var
  Path: TGPGraphicsPath;
begin
  inherited Create(ALeft, ATop, AWidth, AHeight);
  Path := TGPGraphicsPath.Create;
  try
    Path.AddEllipse(ALeft, ATop, AWidth, AHeight);
    FGP := TGPPathGradientBrush.Create(Path);
  finally
    Path.Free;
  end;
  if FGP.GetLastStatus <> OK then
    SetStatusFailed;
end;

destructor TPainterGdiPlusRadialGradientBrush.Destroy;
begin
  FGP.Free;
  inherited;
end;

class function TPainterGdiPlusRadialGradientBrush.Adopt(
  const ABrush: TGPPathGradientBrush): TPainterGdiPlusRadialGradientBrush;
begin
  Result := TPainterGdiPlusRadialGradientBrush.Create(0, 0, 1, 1);
  Result.FGP.Free;
  Result.FGP := ABrush;
  Result.SetStatusOK;
end;

procedure TPainterGdiPlusRadialGradientBrush.SetCenterPoint(
  const Center: TPainterPoint);
begin
  FGP.SetCenterPoint(MakeGpPointF(Center));
end;

procedure TPainterGdiPlusRadialGradientBrush.SetInterpolationColors(
  const Colors: array of TPainterColor; const Positions: array of Single);
begin
  if Length(Colors) = 0 then
    Exit;
  FGP.SetInterpolationColors(PARGB(@Colors[0]), PSingle(@Positions[0]),
    Length(Colors));
end;

procedure TPainterGdiPlusRadialGradientBrush.SetTransform(
  const Matrix: TPainterMatrix);
var
  M: TGPMatrix;
begin
  M := MakeGpMatrix(Matrix);
  try
    FGP.SetTransform(M);
  finally
    M.Free;
  end;
end;

function TPainterGdiPlusRadialGradientBrush.Clone: TPainterBrush;
begin
  Result := TPainterGdiPlusRadialGradientBrush.Create(
    Ellipse.X, Ellipse.Y, Ellipse.Width, Ellipse.Height);
end;

{ --- TPainterGdiPlusPen ----------------------------------------------------- }
constructor TPainterGdiPlusPen.Create(const AColor: TPainterColor;
  const AWidth: Single);
begin
  inherited Create(AColor, AWidth);
  FGP := TGPPen.Create(AColor, AWidth);
  if FGP.GetLastStatus <> OK then
    SetStatusFailed;
end;

destructor TPainterGdiPlusPen.Destroy;
begin
  FGP.Free;
  inherited;
end;

procedure TPainterGdiPlusPen.SetBrush(const Brush: TPainterBrush);
begin
  if Assigned(Brush) then
    FGP.SetBrush(GpBrushOf(Brush))
  else
    FGP.SetBrush(nil);
end;

procedure TPainterGdiPlusPen.SetDashOffset(const Offset: Single);
begin
  FGP.SetDashOffset(Offset);
end;

procedure TPainterGdiPlusPen.SetDashPattern(const Pattern: array of Single);
begin
  if Length(Pattern) = 0 then
    Exit;
  FGP.SetDashPattern(PSingle(@Pattern[0]), Length(Pattern));
end;

procedure TPainterGdiPlusPen.SetDashStyle(const Style: TPainterDashStyle);
begin
  FGP.SetDashStyle(ToGdipDashStyle(Style));
end;

procedure TPainterGdiPlusPen.SetLineCap(const StartCap, EndCap: TPainterLineCap;
  const DCap: TPainterDashCap);
begin
  FGP.SetLineCap(ToGdipLineCap(StartCap), ToGdipLineCap(EndCap),
    ToGdipDashCap(DCap));
end;

procedure TPainterGdiPlusPen.SetLineJoin(const Join: TPainterLineJoin);
begin
  FGP.SetLineJoin(ToGdipLineJoin(Join));
end;

procedure TPainterGdiPlusPen.SetMiterLimit(const Limit: Single);
begin
  FGP.SetMiterLimit(Limit);
end;

{ --- TPainterGdiPlusFontFamily ----------------------------------------------- }
constructor TPainterGdiPlusFontFamily.Create(const AName: string);
begin
  inherited Create(AName);
  FGP := TGPFontFamily.Create(AName);
  if FGP.GetLastStatus <> OK then
    SetStatusFailed;
end;

destructor TPainterGdiPlusFontFamily.Destroy;
begin
  FGP.Free;
  inherited;
end;

function TPainterGdiPlusFontFamily.GetCellAscent(
  const Style: TPainterFontStyle): Integer;
begin
  Result := FGP.GetCellAscent(FontStyleToGdiPlus(Style));
end;

function TPainterGdiPlusFontFamily.GetEmHeight(
  const Style: TPainterFontStyle): Integer;
begin
  Result := FGP.GetEmHeight(FontStyleToGdiPlus(Style));
end;

{ --- TPainterGdiPlusFont ----------------------------------------------------- }
constructor TPainterGdiPlusFont.Create(const Family: TPainterFontFamily;
  const Size: Single; const Style: TPainterFontStyle);
begin
  inherited Create(Family, Size, Style);
  FGP := TGPFont.Create(TPainterGdiPlusFontFamily(Family).GPFontFamily, Size,
    FontStyleToGdiPlus(Style), UnitPixel);
  if FGP.GetLastStatus <> OK then
    SetStatusFailed;
end;

destructor TPainterGdiPlusFont.Destroy;
begin
  FGP.Free;
  inherited;
end;

{ --- TPainterGdiPlusImage ----------------------------------------------------- }
constructor TPainterGdiPlusImage.CreateFromStream(const Stream: TStream);
var
  SA: TStreamAdapter;
  MS: TMemoryStream;
begin
  inherited CreateFromStream(Stream);
  MS := TMemoryStream.Create;
  try
    Stream.Position := 0;
    MS.LoadFromStream(Stream);
    MS.Position := 0;
    SA := TStreamAdapter.Create(MS, soReference);
    FGP := TGPImage.Create(SA);
    if FGP.GetLastStatus <> OK then
      SetStatusFailed;
    FStream := MS;  // keep source bytes alive while GDI+ uses them
    MS := nil;
  finally
    MS.Free;
  end;
end;

destructor TPainterGdiPlusImage.Destroy;
begin
  FGP.Free;
  FStream.Free;
  inherited;
end;

function TPainterGdiPlusImage.GetHeight: Integer;
begin
  Result := FGP.GetHeight;
end;

function TPainterGdiPlusImage.GetWidth: Integer;
begin
  Result := FGP.GetWidth;
end;

{ --- TPainterGdiPlusPath ------------------------------------------------------- }
constructor TPainterGdiPlusPath.Create;
begin
  inherited Create;
  FGP := TGPGraphicsPath2.Create;
  if FGP.GetLastStatus <> OK then
    SetStatusFailed;
end;

destructor TPainterGdiPlusPath.Destroy;
begin
  FGP.Free;
  inherited;
end;

procedure TPainterGdiPlusPath.AddArc(const X, Y, W, H, StartAngle,
  SweepAngle: Single);
begin
  FGP.AddArc(X, Y, W, H, StartAngle, SweepAngle);
end;

procedure TPainterGdiPlusPath.AddBezier(const X1, Y1, X2, Y2, X3, Y3, X4,
  Y4: Single);
begin
  FGP.AddBezier(X1, Y1, X2, Y2, X3, Y3, X4, Y4);
end;

procedure TPainterGdiPlusPath.AddEllipse(const X, Y, W, H: Single);
begin
  FGP.AddEllipse(X, Y, W, H);
end;

procedure TPainterGdiPlusPath.AddLine(const X1, Y1, X2, Y2: Single);
begin
  FGP.AddLine(X1, Y1, X2, Y2);
end;

procedure TPainterGdiPlusPath.AddPath(const Path: TPainterPath;
  const Connect: Boolean);
begin
  FGP.AddPath(TPainterGdiPlusPath(Path).GPPath, Connect);
end;

procedure TPainterGdiPlusPath.AddPolygon(const Points: array of TPainterPoint);
var
  Pts: array of TGPPointF;
  C: Integer;
begin
  SetLength(Pts, Length(Points));
  for C := 0 to Length(Pts) - 1 do
  begin
    Pts[C].X := Points[C].X;
    Pts[C].Y := Points[C].Y;
  end;
  if Length(Pts) > 0 then
    FGP.AddPolygon(PGPPointF(@Pts[0]), Length(Pts));
end;

procedure TPainterGdiPlusPath.AddRectangle(const Rect: TPainterRect);
begin
  FGP.AddRectangle(MakeGpRectF(Rect));
end;

procedure TPainterGdiPlusPath.AddString(const Text: string;
  const Family: TPainterFontFamily; const Style: TPainterFontStyle;
  const Size: Single; const Format: TPainterTextFormat);
var
  FF: TPainterGdiPlusFontFamily;
  SF: TGPStringFormat;
begin
  FF := Family as TPainterGdiPlusFontFamily;
  SF := MakeGdiStringFormat(Format);
  try
    FGP.AddString(Text, -1, FF.GPFontFamily, FontStyleToGdiPlus(Style), Size,
      MakeGpPointF(Painter.MakePoint(0, 0)), SF);
  finally
    SF.Free;
  end;
end;

function TPainterGdiPlusPath.Clone: TPainterPath;
begin
  Result := TPainterGdiPlusPath.Create;
  TPainterGdiPlusPath(Result).FGP.Free;
  TPainterGdiPlusPath(Result).FGP := FGP.Clone;
end;

procedure TPainterGdiPlusPath.CloseFigure;
begin
  FGP.CloseFigure;
end;

function TPainterGdiPlusPath.GetPointCount: Integer;
begin
  Result := FGP.GetPointCount;
end;

procedure TPainterGdiPlusPath.SetFillMode(const FillMode: TPainterFillMode);
begin
  FGP.SetFillMode(FillModeMap[FillMode]);
end;

procedure TPainterGdiPlusPath.StartFigure;
begin
  FGP.StartFigure;
end;

procedure TPainterGdiPlusPath.Transform(const Matrix: TPainterMatrix);
var
  M: TGPMatrix;
begin
  M := MakeGpMatrix(Matrix);
  try
    FGP.Transform(M);
  finally
    M.Free;
  end;
end;

{ --- TPainterGdiPlus ----------------------------------------------------------- }
constructor TPainterGdiPlus.Create(const AGraphics: TGPGraphics);
begin
  inherited Create;
  FGraphics := AGraphics;
end;

function TPainterGdiPlus.CreateFont(const Family: TPainterFontFamily;
  const Size: Single; const Style: TPainterFontStyle): TPainterFont;
begin
  Result := TPainterGdiPlusFont.Create(Family, Size, Style);
end;

function TPainterGdiPlus.CreateFontFamily(const AName: string): TPainterFontFamily;
begin
  Result := TPainterGdiPlusFontFamily.Create(AName);
end;

function TPainterGdiPlus.CreateLinearGradientBrush(const P1, P2: TPainterPoint;
  const C1, C2: TPainterColor): TPainterLinearGradientBrush;
begin
  Result := TPainterGdiPlusLinearGradientBrush.Create(P1, P2, C1, C2);
end;

function TPainterGdiPlus.CreatePath: TPainterPath;
begin
  Result := TPainterGdiPlusPath.Create;
end;

function TPainterGdiPlus.CreatePen(const AColor: TPainterColor;
  const AWidth: Single): TPainterPen;
begin
  Result := TPainterGdiPlusPen.Create(AColor, AWidth);
end;

function TPainterGdiPlus.CreateRadialGradientBrush(const ALeft, ATop, AWidth,
  AHeight: Single): TPainterRadialGradientBrush;
begin
  Result := TPainterGdiPlusRadialGradientBrush.Create(ALeft, ATop, AWidth, AHeight);
end;

function TPainterGdiPlus.CreateSolidBrush(
  const AColor: TPainterColor): TPainterSolidBrush;
begin
  Result := TPainterGdiPlusSolidBrush.Create(AColor);
end;

function TPainterGdiPlus.LoadImage(const Stream: TStream): TPainterImage;
begin
  Result := TPainterGdiPlusImage.CreateFromStream(Stream);
end;

procedure TPainterGdiPlus.Clear(const Color: TPainterColor);
begin
  FGraphics.Clear(Color);
end;

procedure TPainterGdiPlus.DrawImage(const Image: TPainterImage;
  const Dest: TPainterRect{$IFDEF FPC}; Options: TPainterImageOptions{$ELSE}; const Options: TPainterImageOptions{$ENDIF});
var
  I: TPainterGdiPlusImage;
  ImAtt: TGPImageAttributes;
  CM: TColorMatrix;
  Opacity: Single;
begin
  I := Image as TPainterGdiPlusImage;
  Opacity := Options.Opacity;
  if Opacity < 0 then
    Opacity := 0;
  if Opacity > 1 then
    Opacity := 1;
  FillChar(CM, SizeOf(CM), 0);
  CM[0, 0] := 1;
  CM[1, 1] := 1;
  CM[2, 2] := 1;
  CM[3, 3] := Opacity;
  CM[4, 4] := 1;
  ImAtt := TGPImageAttributes.Create;
  try
    ImAtt.SetColorMatrix(CM, ColorMatrixFlagsDefault, ColorAdjustTypeDefault);
    FGraphics.DrawImage(I.GPImage, MakeGpRectF(Dest), 0, 0,
      I.GPImage.GetWidth, I.GPImage.GetHeight, UnitPixel, ImAtt);
  finally
    ImAtt.Free;
  end;
end;

procedure TPainterGdiPlus.DrawLine(const Pen: TPainterPen;
  const X1, Y1, X2, Y2: Single);
begin
  FGraphics.DrawLine(TPainterGdiPlusPen(Pen).GPPen, X1, Y1, X2, Y2);
end;

procedure TPainterGdiPlus.DrawPath(const Pen: TPainterPen;
  const Path: TPainterPath);
begin
  FGraphics.DrawPath(TPainterGdiPlusPen(Pen).GPPen,
    TPainterGdiPlusPath(Path).GPPath);
end;

procedure TPainterGdiPlus.FillPath(const Brush: TPainterBrush;
  const Path: TPainterPath);
begin
  FGraphics.FillPath(GpBrushOf(Brush), TPainterGdiPlusPath(Path).GPPath);
end;

procedure TPainterGdiPlus.GetTransform(out Matrix: TPainterMatrix);
var
  M: TGPMatrix;
  E: TMatrixArray;
begin
  M := TGPMatrix.Create;
  try
    FGraphics.GetTransform(M);
    M.GetElements(E);
    Matrix := MakeMatrix(E[0], E[1], E[2], E[3], E[4], E[5]);
  finally
    M.Free;
  end;
end;

procedure TPainterGdiPlus.ResetClip;
begin
  FGraphics.ResetClip;
end;

procedure TPainterGdiPlus.ResetTransform;
begin
  FGraphics.ResetTransform;
end;

procedure TPainterGdiPlus.SetClip(const Path: TPainterPath);
begin
  FGraphics.SetClip(TPainterGdiPlusPath(Path).GPPath);
end;

procedure TPainterGdiPlus.SetSmoothingMode(const AntiAlias: Boolean);
begin
  if AntiAlias then
    FGraphics.SetSmoothingMode(SmoothingModeAntiAlias)
  else
    FGraphics.SetSmoothingMode(SmoothingModeNone);
end;

procedure TPainterGdiPlus.SetTransform(const Matrix: TPainterMatrix);
var
  M: TGPMatrix;
begin
  M := MakeGpMatrix(Matrix);
  try
    FGraphics.SetTransform(M);
  finally
    M.Free;
  end;
end;

procedure TPainterGdiPlus.DrawString(const Text: string; const Font: TPainterFont;
  const Origin: TPainterPoint; const Format: TPainterTextFormat;
  const Brush: TPainterBrush);
var
  SF: TGPStringFormat;
  F: TPainterGdiPlusFont;
begin
  if Text = '' then
    Exit;
  F := Font as TPainterGdiPlusFont;
  if not Assigned(Brush) then
    Exit;
  SF := MakeGdiStringFormat(Format);
  try
    KerningText.AddToGraphics(FGraphics, Text, F.GPFont, MakeGpPointF(Origin),
      SF, GpBrushOf(Brush));
  finally
    SF.Free;
  end;
end;

procedure TPainterGdiPlus.MeasureString(const Text: string; const Font: TPainterFont;
  const Origin: TPainterPoint; const Format: TPainterTextFormat;
  var Rect: TPainterRect);
var
  SF: TGPStringFormat;
  R: TGPRectF;
  F: TPainterGdiPlusFont;
begin
  F := Font as TPainterGdiPlusFont;
  SF := MakeGdiStringFormat(Format);
  try
    FGraphics.MeasureString(Text, -1, F.GPFont, MakeGpPointF(Origin), SF, R);
    Rect := Painter.MakeRect(R.X, R.Y, R.Width, R.Height);
  finally
    SF.Free;
  end;
end;

function TPainterGdiPlus.MeasureText(const Text: string;
  const Font: TPainterFont): Single;
begin
  Result := KerningText.MeasureText(Text, TPainterGdiPlusFont(Font).GPFont);
end;

procedure TPainterGdiPlus.AddTextToPath(const Path: TPainterPath;
  const Text: string; const Family: TPainterFontFamily;
  const Style: TPainterFontStyle; const Size: Single; const Origin: TPainterPoint;
  const Format: TPainterTextFormat);
var
  FF: TPainterGdiPlusFontFamily;
  P: TPainterGdiPlusPath;
  SF: TGPStringFormat;
begin
  if Text = '' then
    Exit;
  FF := Family as TPainterGdiPlusFontFamily;
  P := Path as TPainterGdiPlusPath;
  SF := MakeGdiStringFormat(Format);
  try
    KerningText.AddToPath(P.GPPath, Text, FF.GPFontFamily,
      FontStyleToGdiPlus(Style), Size, MakeGpPointF(Origin), SF);
  finally
    SF.Free;
  end;
end;

function TPainterGdiPlus.GetPathLength(const Path: TPainterPath): Single;
begin
  Result := TGPPathText.GetPathLength(TPainterGdiPlusPath(Path).GPPath);
end;

{ --- TPainterMeasureGdiPlus --------------------------------------------------- }

function TPainterMeasureGdiPlus.GetGpStringFormat(
  const Format: TPainterTextFormat): TGPStringFormat;
begin
  Result := MakeGdiStringFormat(Format);
end;

function TPainterMeasureGdiPlus.CreateFontFamily(
  const AName: string): TPainterFontFamily;
begin
  Result := TPainterGdiPlusFontFamily.Create(AName);
end;

function TPainterMeasureGdiPlus.CreateFont(const Family: TPainterFontFamily;
  const Size: Single; const Style: TPainterFontStyle): TPainterFont;
begin
  Result := TPainterGdiPlusFont.Create(Family, Size, Style);
end;

function TPainterMeasureGdiPlus.MeasureText(const Text: string;
  const Font: TPainterFont): Single;
begin
  Result := KerningText.MeasureText(Text, TPainterGdiPlusFont(Font).GPFont);
end;

procedure TPainterMeasureGdiPlus.MeasureString(const Text: string;
  const Font: TPainterFont; const Origin: TPainterPoint;
  const Format: TPainterTextFormat; var Rect: TPainterRect);
var
  DC: HDC;
  G: TGPGraphics;
  SF: TGPStringFormat;
  R: TGPRectF;
begin
  DC := GetDC(0);
  try
    G := TGPGraphics.Create(DC);
    try
      SF := GetGpStringFormat(Format);
      try
        G.MeasureString(Text, -1, TPainterGdiPlusFont(Font).GPFont,
          MakeGpPointF(Origin), SF, R);
      finally
        SF.Free;
      end;
    finally
      G.Free;
    end;
  finally
    ReleaseDC(0, DC);
  end;
  Rect := Painter.MakeRect(R.X, R.Y, R.Width, R.Height);
end;

procedure TPainterMeasureGdiPlus.AddTextToPath(const Path, UPath,
  SPath: TPainterPath; const Text: string; const Family: TPainterFontFamily;
  const Style: TPainterFontStyle; const Size: Single;
  const Origin: TPainterPoint; const Format: TPainterTextFormat);

  function PathOf(const P: TPainterPath): TGPGraphicsPath;
  begin
    if Assigned(P) then
      Result := TPainterGdiPlusPath(P).GPPath
    else
      Result := nil;
  end;

var
  SF: TGPStringFormat;
begin
  if Text = '' then
    Exit;
  SF := GetGpStringFormat(Format);
  try
    KerningText.AddToPath(TPainterGdiPlusPath(Path).GPPath,
      PathOf(UPath), PathOf(SPath), Text, TPainterGdiPlusFontFamily(Family).GPFontFamily,
      FontStyleToGdiPlus(Style), Size, MakeGpPointF(Origin), SF);
  finally
    SF.Free;
  end;
end;

function TPainterMeasureGdiPlus.AddPathText(const Path, GuidePath: TPainterPath;
  const Text: string; const Family: TPainterFontFamily;
  const Style: TPainterFontStyle; const Size: Single;
  const Format: TPainterTextFormat; const Indent: Single;
  const HasMatrix: Boolean; const AdditionalMatrix: TPainterMatrix): Single;
var
  PT: TGPPathText;
  M: TGPMatrix;
  SF: TGPStringFormat;
begin
  if Text = '' then
  begin
    Result := 0;
    Exit;
  end;
  PT := TGPPathText.Create(TPainterGdiPlusPath(GuidePath).GPPath);
  try
    M := nil;
    if HasMatrix then
      M := MakeGpMatrix(AdditionalMatrix);
    PT.AdditionalMatrix := M;
    SF := GetGpStringFormat(Format);
    try
      Result := PT.AddPathText(TPainterGdiPlusPath(Path).GPPath, Text, Indent,
        TPainterGdiPlusFontFamily(Family).GPFontFamily,
        FontStyleToGdiPlus(Style), Size, SF);
    finally
      SF.Free;
    end;
    M.Free;
  finally
    PT.Free;
  end;
end;

function TPainterMeasureGdiPlus.GetPathLength(const Path: TPainterPath): Single;
begin
  Result := TGPPathText.GetPathLength(TPainterGdiPlusPath(Path).GPPath);
end;

function ToGPRectF(const R: TPainterRect): TGPRectF;
begin
  Result.X := R.X;
  Result.Y := R.Y;
  Result.Width := R.Width;
  Result.Height := R.Height;
end;

function ToPainterRect(const R: TGPRectF): TPainterRect;
begin
  Result.X := R.X;
  Result.Y := R.Y;
  Result.Width := R.Width;
  Result.Height := R.Height;
end;

{ --- parse-time factory registrations (task 2.5) ----------------------------- }

function CreateGdiPlusPath: TPainterPath;
begin
  Result := TPainterGdiPlusPath.Create;
  if not Result.GetLastStatus then
  begin
    Result.Free;
    Result := nil;
  end;
end;

function CreateGdiPlusImage(const Stream: TStream): TPainterImage;
begin
  Result := TPainterGdiPlusImage.CreateFromStream(Stream);
end;

initialization
  RegisterPainterMeasure(TPainterMeasureGdiPlus.Create);
  RegisterPainterPathFactory(CreateGdiPlusPath);
  RegisterPainterImageFactory(CreateGdiPlusImage);

finalization
  RegisterPainterMeasure(nil);

end.