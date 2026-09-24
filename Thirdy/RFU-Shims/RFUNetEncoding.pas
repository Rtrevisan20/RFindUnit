{
  RFUNetEncoding - Shim dual-IDE para System.NetEncoding (RFUSVG-Ekot port)

  Delphi : re-exporta System.NetEncoding (API original intacta).
  FPC 3.2: implementa TNetEncoding.Base64.Decode(TStream, TStream) sobre o
           base64 nativo do FCL (fcl-base\base64.pp).

  Cobertura limitada ao que o RFUSVG-Ekot consome. Expandir conforme necessário.
}
unit RFUNetEncoding;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  {$IFDEF FPC}
  Classes,
  SysUtils,
  base64
  {$ELSE}
  System.NetEncoding
  {$ENDIF};

{$IFDEF FPC}
type
  TNetEncoding = class
  private
    class var FBase64: TNetEncoding;
    class function GetBase64: TNetEncoding; static;
  public
    class property Base64: TNetEncoding read GetBase64;
    procedure Decode(const Input: TStream; const Dest: TStream);
  end;
{$ENDIF}

implementation

{$IFDEF FPC}
class function TNetEncoding.GetBase64: TNetEncoding;
begin
  if FBase64 = nil then
    FBase64 := TNetEncoding.Create;
  Result := FBase64;
end;

procedure TNetEncoding.Decode(const Input: TStream; const Dest: TStream);
var
  SS: TStringStream;
  S, Decoded: string;
begin
  Input.Position := 0;
  SS := TStringStream.Create('');
  try
    SS.CopyFrom(Input, Input.Size);
    S := SS.DataString;
    Decoded := DecodeStringBase64(S);
    Dest.Size := 0;
    Dest.Position := 0;
    if Length(Decoded) > 0 then
      Dest.WriteBuffer(Pointer(Decoded)^, Length(Decoded));
    Dest.Position := 0;
  finally
    SS.Free;
  end;
end;
{$ENDIF}

end.