{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit HDFindUnit.Lazarus;

{$warn 5023 off : no warning about unused units}
interface

uses
  DelphiAST.Consts, DelphiAST.Classes, SimpleParser.Types, SimpleParser.Lexer.Types,
  SimpleParser.Lexer, SimpleParser, DelphiAST, DelphiAST.Writer, StringBuilderUnit,
  Log4Pascal, RegExpr, SVG, SVGColor, SVGCommon, SVGPaint, SVGParse, SVGPath,
  SVGProperties, SVGStyle, SVGTypes, SVGXML, Painter, PainterGdiPlus, PainterLCL,
  GDIPAPI, GDIPOBJ, GDIPOBJ2, GDIPKerning, GDIPPathText, DirectDraw, RFUNetEncoding,
  HDFindUnit.Model.Header, HDFindUnit.Model.DelphiReservedWords,
  HDFindUnit.Model.StringPositionList, HDFindUnit.Model.Settings,
  HDFindUnit.Model.PasParser, HDFindUnit.Model.FileCache,
  HDFindUnit.Model.Interf.SearchStringCache, HDFindUnit.Model.SearchStringCache,
  HDFindUnit.Model.SearchString, HDFindUnit.Model.DelphiVlcWrapper,
  HDFindUnit.View.FormMessage, HDFindUnit.Utils,
  HDFindUnit.Model.Interf.Translation, HDFindUnit.Model.Translation,
  HDFindUnit.Controller.Interf.EnvironmentController,
  HDFindUnit.Model.IncluderHandlerInc,
  HDFindUnit.Model.ResultsImportanceCalculator, HDFindUnit.Model.AutoImport,
  HDFindUnit.Controller.OTAUtils, HDFindUnit.Controller.EnvironmentController,
  HDFindUnit.Model.FileEditor, HDFindUnit.Model.Worker,
  HDFindUnit.View.FormSearch, HDFindUnit.Controller.Lazarus,
  LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('HDFindUnit.Lazarus', @Register);
end.