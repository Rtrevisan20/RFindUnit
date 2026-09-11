{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit HDFindUnit.Lazarus.Deps;

{$warn 5023 off : no warning about unused units}
interface

uses
  DelphiAST.Consts, DelphiAST.Classes, SimpleParser.Types, 
  SimpleParser.Lexer.Types, SimpleParser.Lexer, SimpleParser, DelphiAST, 
  DelphiAST.Writer, StringBuilderUnit, Log4Pascal, RegExpr, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('HDFindUnit.Lazarus.Deps', @Register);
end.
