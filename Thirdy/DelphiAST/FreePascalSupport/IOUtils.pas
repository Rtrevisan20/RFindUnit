// Dummy implementation of IOUtils in order to be able to compile Delphi AST with FPC
unit IOUtils;

interface

uses
  SysUtils;
  
type 
  TPath = class
  public
    class function Combine(const Path1, Path2: string): string; inline; static;
  end;

function IsRelativePath(const Path: string): Boolean;

implementation

function IsRelativePath(const Path: string): Boolean;
begin
  Result := (Length(Path) = 0) or
    not (((Length(Path) >= 2) and (Path[2] = ':'))
      or ((Length(Path) >= 1) and (Path[1] = PathDelim)));
end;

class function TPath.Combine(const Path1, Path2: string): string; 
begin
  Result := ConcatPaths([Path1, Path2]);	
end;
 	
end.