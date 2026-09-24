      {******************************************************************}
      { SVG types                                                        }
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

unit SVGTypes;

interface

uses
{$IFDEF FPC}
  Math, Types;
{$ELSE}
  System.Math, System.Types, System.UITypes;
{$ENDIF}

const
  INHERIT = -1;

  FontNormal = 0;
  FontItalic = 1;

  MaxTFloat = MaxSingle;

type
{$IFDEF FPC}
  { COLORREF-style color (0x00BBGGRR, low byte = red), same layout as
    System.UITypes.TColor on Delphi. Kept out of LCL units on FPC so the
    SVG core stays widgetset-independent. }
  TColor = LongInt;
{$ELSE}
  TColor = System.UITypes.TColor;
{$ENDIF}

  TFloat = single;

  TListOfPoints = array of TPointF;

  TRectarray = packed array of TRect;
  PRectArray = ^TRectArray;

TTextDecoration = set of (tdInherit, tdUnderLine, tdOverLine, tdStrikeOut);

    TTextPathMethod = (tpmAlign, tpmStretch);

    TTextPathSpacing = (tpsAuto, tpsExact);

    TSVGUnit = (suNone, suPX, suPT, suPC, suMM, suCM, suIN, suEM, suEX, suPercent);

    TGradientUnits = (guObjectBoundingBox, guUserSpaceOnUse);

{ Portable 2D affine matrix (3x3) with the exact same math and row-vector
      convention (P' = P * M) as System.Math.Vectors.TMatrix on Delphi, so the
      SVG core renders pixel-identically on FPC too (Types.TPointF/TRectF are
      used for points/rects; only the matrix needed a portable replacement). }
    TMatrix2D = record
      m11, m12, m13: Single;
      m21, m22, m23: Single;
      m31, m32, m33: Single;
      class function Identity: TMatrix2D; static;
      class function CreateRotation(const AAngle: Single): TMatrix2D; static;
      class function CreateScaling(const AScaleX, AScaleY: Single): TMatrix2D; static;
      class function CreateTranslation(const ADeltaX, ADeltaY: Single): TMatrix2D; static;
      class operator Multiply(const AMatrix1, AMatrix2: TMatrix2D): TMatrix2D;
      class operator Multiply(const APoint: TPointF; const AMatrix: TMatrix2D): TPointF;
    end;

    TBounds = record
      TopLeft: TPointF;
      TopRight: TPointF;
      BottomLeft: TPointF;
      BottomRight: TPointF;
    end;

function Intersect(const Bounds: TBounds; const Rect: TRect): Boolean;

implementation

{ TMatrix2D - math copied from System.Math.Vectors.TMatrix (Delphi RTL) so
  the port is pixel-identical. FPC supports record class operators/statics. }

class function TMatrix2D.Identity: TMatrix2D;
begin
  Result.m11 := 1; Result.m12 := 0; Result.m13 := 0;
  Result.m21 := 0; Result.m22 := 1; Result.m23 := 0;
  Result.m31 := 0; Result.m32 := 0; Result.m33 := 1;
end;

class function TMatrix2D.CreateRotation(const AAngle: Single): TMatrix2D;
var
  Sine, Cosine: Single;
begin
  SinCos(AAngle, Sine, Cosine);
  Result := Identity;
  Result.m11 := Cosine;
  Result.m12 := Sine;
  Result.m21 := -Sine;
  Result.m22 := Cosine;
end;

class function TMatrix2D.CreateScaling(const AScaleX, AScaleY: Single): TMatrix2D;
begin
  Result := Identity;
  Result.m11 := AScaleX;
  Result.m22 := AScaleY;
end;

class function TMatrix2D.CreateTranslation(const ADeltaX, ADeltaY: Single): TMatrix2D;
begin
  Result := Identity;
  Result.m31 := ADeltaX;
  Result.m32 := ADeltaY;
end;

class operator TMatrix2D.Multiply(const AMatrix1, AMatrix2: TMatrix2D): TMatrix2D;
begin
  Result.m11 := AMatrix1.m11 * AMatrix2.m11 + AMatrix1.m12 * AMatrix2.m21 + AMatrix1.m13 * AMatrix2.m31;
  Result.m12 := AMatrix1.m11 * AMatrix2.m12 + AMatrix1.m12 * AMatrix2.m22 + AMatrix1.m13 * AMatrix2.m32;
  Result.m13 := AMatrix1.m11 * AMatrix2.m13 + AMatrix1.m12 * AMatrix2.m23 + AMatrix1.m13 * AMatrix2.m33;
  Result.m21 := AMatrix1.m21 * AMatrix2.m11 + AMatrix1.m22 * AMatrix2.m21 + AMatrix1.m23 * AMatrix2.m31;
  Result.m22 := AMatrix1.m21 * AMatrix2.m12 + AMatrix1.m22 * AMatrix2.m22 + AMatrix1.m23 * AMatrix2.m32;
  Result.m23 := AMatrix1.m21 * AMatrix2.m13 + AMatrix1.m22 * AMatrix2.m23 + AMatrix1.m23 * AMatrix2.m33;
  Result.m31 := AMatrix1.m31 * AMatrix2.m11 + AMatrix1.m32 * AMatrix2.m21 + AMatrix1.m33 * AMatrix2.m31;
  Result.m32 := AMatrix1.m31 * AMatrix2.m12 + AMatrix1.m32 * AMatrix2.m22 + AMatrix1.m33 * AMatrix2.m32;
  Result.m33 := AMatrix1.m31 * AMatrix2.m13 + AMatrix1.m32 * AMatrix2.m23 + AMatrix1.m33 * AMatrix2.m33;
end;

class operator TMatrix2D.Multiply(const APoint: TPointF; const AMatrix: TMatrix2D): TPointF;
begin
  Result.X := APoint.X * AMatrix.m11 + APoint.Y * AMatrix.m21 + AMatrix.m31;
  Result.Y := APoint.X * AMatrix.m12 + APoint.Y * AMatrix.m22 + AMatrix.m32;
end;

{ Polyline/segment helpers used by Intersect below. All integer math, no
  GDI regions, so this unit stays RTL-portable for the Lazarus port. }

function PointInRect(const X, Y: Integer; const Rect: TRect): Boolean;
begin
  Result := (X >= Rect.Left) and (X <= Rect.Right) and
            (Y >= Rect.Top) and (Y <= Rect.Bottom);
end;

function PointInPolygon(const X, Y: Integer;
  const P: array of TPoint): Boolean;
var
  Hits, K, J, N: Integer;
begin
  N := Length(P);
  Hits := 0;
  J := N - 1;
  for K := 0 to N - 1 do
  begin
    if ((P[K].Y > Y) <> (P[J].Y > Y)) then
      if (X * 1.0 < (P[J].X - P[K].X) * (Y - P[K].Y) / (P[J].Y - P[K].Y) + P[K].X) then
        Inc(Hits);
    J := K;
  end;
  Result := Odd(Hits);
end;

function Orientation(const A, B, C: TPoint): Integer;
var
  Val: Int64;
begin
  Val := Int64(B.X - A.X) * (C.Y - A.Y) -
         Int64(B.Y - A.Y) * (C.X - A.X);
  if Val > 0 then
    Result := 1
  else if Val < 0 then
    Result := 2
  else
    Result := 0;
end;

function OnSegment(const A, B, C: TPoint): Boolean;
begin
  Result := (B.X <= Max(A.X, C.X)) and (B.X >= Min(A.X, C.X)) and
            (B.Y <= Max(A.Y, C.Y)) and (B.Y >= Min(A.Y, C.Y));
end;

function SegmentsIntersect(const A1, A2, B1, B2: TPoint): Boolean;
var
  O1, O2, O3, O4: Integer;
begin
  O1 := Orientation(A1, A2, B1);
  O2 := Orientation(A1, A2, B2);
  O3 := Orientation(B1, B2, A1);
  O4 := Orientation(B1, B2, A2);

  if (O1 <> O2) and (O3 <> O4) then
    Result := True
  else if (O1 = 0) and OnSegment(A1, B1, A2) then
    Result := True
  else if (O2 = 0) and OnSegment(A1, B2, A2) then
    Result := True
  else if (O3 = 0) and OnSegment(B1, A1, B2) then
    Result := True
  else if (O4 = 0) and OnSegment(B1, A2, B2) then
    Result := True
  else
    Result := False;
end;

function Intersect(const Bounds: TBounds; const Rect: TRect): Boolean;
var
  P: array[0..3] of TPoint;
  C: Integer;
begin
  P[0].X := Round(Bounds.TopLeft.X);
  P[0].Y := Round(Bounds.TopLeft.Y);

  P[1].X := Round(Bounds.TopRight.X);
  P[1].Y := Round(Bounds.TopRight.Y);

  P[2].X := Round(Bounds.BottomRight.X);
  P[2].Y := Round(Bounds.BottomRight.Y);

  P[3].X := Round(Bounds.BottomLeft.X);
  P[3].Y := Round(Bounds.BottomLeft.Y);

  for C := 0 to 3 do
    if PointInRect(P[C].X, P[C].Y, Rect) then
      Exit(True);

  if PointInPolygon(Rect.Left, Rect.Top, P) or
     PointInPolygon(Rect.Right, Rect.Top, P) or
     PointInPolygon(Rect.Left, Rect.Bottom, P) or
     PointInPolygon(Rect.Right, Rect.Bottom, P) then
    Exit(True);

  for C := 0 to 3 do
  begin
    if SegmentsIntersect(P[C], P[(C + 1) mod 4],
       TPoint.Create(Rect.Left, Rect.Top), TPoint.Create(Rect.Right, Rect.Top)) or
       SegmentsIntersect(P[C], P[(C + 1) mod 4],
       TPoint.Create(Rect.Right, Rect.Top), TPoint.Create(Rect.Right, Rect.Bottom)) or
       SegmentsIntersect(P[C], P[(C + 1) mod 4],
       TPoint.Create(Rect.Right, Rect.Bottom), TPoint.Create(Rect.Left, Rect.Bottom)) or
       SegmentsIntersect(P[C], P[(C + 1) mod 4],
       TPoint.Create(Rect.Left, Rect.Bottom), TPoint.Create(Rect.Left, Rect.Top)) then
      Exit(True);
  end;

  Result := False;
end;

end.
