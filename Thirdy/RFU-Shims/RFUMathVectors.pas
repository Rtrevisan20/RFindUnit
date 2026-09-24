{
  RFUMathVectors - Shim dual-IDE para System.Math.Vectors (RFUSVG-Ekot port)

  Delphi  : re-exporta System.Types + System.Math.Vectors (API original intacta).
  FPC 3.2 : re-exporta Types (TPoint/TRect/TSize/TPointF/TRectF) e define TMatrix
            com a SEMÂNTICA IDÊNTICA do Delphi (row-vector, m11..m33).

  Cobertura limitada ao que o RFUSVG-Ekot consome. Expandir conforme necessário.
}
unit RFUMathVectors;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  {$IFDEF FPC}
  Types,
  Math
  {$ELSE}
  System.Types,
  System.Math.Vectors
  {$ENDIF};

{$IFDEF FPC}
type
  TPoint = Types.TPoint;
  TRect = Types.TRect;
  TSize = Types.TSize;
  TPointF = Types.TPointF;
  TRectF = Types.TRectF;

  { TMatrix - row-vector convention (identical to Delphi System.Math.Vectors) }
  TMatrix = record
  public
    class function CreateRotation(const aAngle: Single): TMatrix; static;
    class function CreateScaling(const aScaleX, aScaleY: Single): TMatrix; static;
    class function CreateTranslation(const aDeltaX, aDeltaY: Single): TMatrix; static;
    class function Identity: TMatrix; static;

    class operator *(const aMatrix1, aMatrix2: TMatrix): TMatrix;
    class operator *(const aPoint: TPointF; const aMatrix: TMatrix): TPointF;
  public
    m11, m12, m13: Single;
    m21, m22, m23: Single;
    m31, m32, m33: Single;
  end;
{$ENDIF}

implementation

{$IFDEF FPC}
class function TMatrix.Identity: TMatrix;
begin
  Result.m11 := 1; Result.m12 := 0; Result.m13 := 0;
  Result.m21 := 0; Result.m22 := 1; Result.m23 := 0;
  Result.m31 := 0; Result.m32 := 0; Result.m33 := 1;
end;

class function TMatrix.CreateTranslation(const aDeltaX, aDeltaY: Single): TMatrix;
begin
  Result := TMatrix.Identity;
  Result.m31 := aDeltaX;
  Result.m32 := aDeltaY;
end;

class function TMatrix.CreateRotation(const aAngle: Single): TMatrix;
var
  cA, sA: Single;
begin
  SinCos(aAngle, sA, cA);
  Result := TMatrix.Identity;
  Result.m11 := cA;
  Result.m12 := sA;
  Result.m21 := -sA;
  Result.m22 := cA;
end;

class function TMatrix.CreateScaling(const aScaleX, aScaleY: Single): TMatrix;
begin
  Result := TMatrix.Identity;
  Result.m11 := aScaleX;
  Result.m22 := aScaleY;
end;

class operator TMatrix.*(const aMatrix1, aMatrix2: TMatrix): TMatrix;
var
  M1: TMatrix absolute aMatrix1;
  M2: TMatrix absolute aMatrix2;
  R: TMatrix;
begin
  With R do
  begin
    m11 := M1.m11 * M2.m11 + M1.m12 * M2.m21 + M1.m13 * M2.m31;
    m12 := M1.m11 * M2.m12 + M1.m12 * M2.m22 + M1.m13 * M2.m32;
    m13 := M1.m11 * M2.m13 + M1.m12 * M2.m23 + M1.m13 * M2.m33;

    m21 := M1.m21 * M2.m11 + M1.m22 * M2.m21 + M1.m23 * M2.m31;
    m22 := M1.m21 * M2.m12 + M1.m22 * M2.m22 + M1.m23 * M2.m32;
    m23 := M1.m21 * M2.m13 + M1.m22 * M2.m23 + M1.m23 * M2.m33;

    m31 := M1.m31 * M2.m11 + M1.m32 * M2.m21 + M1.m33 * M2.m31;
    m32 := M1.m31 * M2.m12 + M1.m32 * M2.m22 + M1.m33 * M2.m32;
    m33 := M1.m31 * M2.m13 + M1.m32 * M2.m23 + M1.m33 * M2.m33;
  end;
  Result := R;
end;

class operator TMatrix.*(const aPoint: TPointF; const aMatrix: TMatrix): TPointF;
var
  P: TPointF absolute aPoint;
  N: TMatrix absolute aMatrix;
begin
  Result.X := P.X * N.m11 + P.Y * N.m21 + N.m31;
  Result.Y := P.X * N.m12 + P.Y * N.m22 + N.m32;
end;
{$ENDIF}

end.