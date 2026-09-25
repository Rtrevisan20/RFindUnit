{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit HDFindUnit.Lazarus.SVG;

{$warn 5023 off : no warning about unused units}
interface

uses
  SVG, SVGColor, SVGCommon, SVGPaint, SVGParse, SVGPath, SVGProperties, 
  SVGStyle, SVGTypes, SVGXML, Painter, PainterGdiPlus, PainterLCL, GDIPAPI, 
  GDIPOBJ, GDIPOBJ2, GDIPKerning, GDIPPathText, DirectDraw, RFUNetEncoding, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('HDFindUnit.Lazarus.SVG', @Register);
end.
