{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit HDFindUnit.Lazarus;

{$warn 5023 off : no warning about unused units}
interface

uses
  HDFindUnit.Model.Header, HDFindUnit.Model.DelphiReservedWords, 
  HDFindUnit.Model.StringPositionList, HDFindUnit.Model.Settings, 
  HDFindUnit.Model.PasParser, HDFindUnit.Model.FileCache, 
  HDFindUnit.Model.Interf.SearchStringCache, 
  HDFindUnit.Model.SearchStringCache, HDFindUnit.Model.SearchString, 
  HDFindUnit.Model.DelphiVlcWrapper, HDFindUnit.View.FormMessage, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('HDFindUnit.Lazarus', @Register);
end.
