unit HDFindUnit.Model.ImageRepository;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.UITypes,

  HDFindUnit.Model.SVGConsts,
  RFUSVG,
  Vcl.Imaging.pngimage;

const
  RFUWarningColor: TColor = $0099E9FF;

  cSVGColorDark = '#FFE999';
  cSVGColorLight = '#C77700';

type
  TRfImageType = (girHourGlass,
    girCheckWithWarnings,
    girCheckedAllOk);

  TFindUnitImageRepository = class(TObject)
  private
    class var FRepository: TObjectDictionary<string, TPngImage>;
    class var FSVGWarning: TSVG;
    class var FSVGHourGlass: TSVG;
    class var FSVGDarkTheme: Boolean;
    class var FGDIPlusToken: NativeUInt;
    class var FGDIPlusReady: Boolean;
    class procedure EnsureGDIPlus;
    class function IsDarkTheme: Boolean;
    class function GetSVGColorHex: string;
    class function CreateSVG(const TextBase: string): TSVG;
    class procedure GetGraphicFromText(var Graphic: TPngImage; ImageBaseText: string);

    //Asc sort
    class procedure GetHourGlass(var Target: TPngImage);
    class procedure GetCheckWarnings(var Target: TPngImage);
    class procedure GetCheckAllOk(var Target: TPngImage);
  public
    class function GetImage(ImageType: TRfImageType): TPngImage;
    class function GetCheckWarningsSVG: TSVG;
    class function GetHourGlassSVG: TSVG;
  end;

implementation

uses
  System.SysUtils,
  ToolsAPI,
  Vcl.Graphics,
  Winapi.GDIPAPI,
  Winapi.Windows;

class procedure TFindUnitImageRepository.GetCheckAllOk(var Target: TPngImage);
begin
  GetGraphicFromText(Target,
    '0954506E67496D61676589504E470D0A1A0A0000000D49484452000000100000' +
    '00100803000000282D0F530000000467414D410000B18F0BFC61050000007E50' +
    '4C544500000090DC5A91DC5A91DB5B90DB5A91DC5A91DD5B92DD5A91DC5A91DC' +
    '5A8EDB5990DD5991DC5A91DC5A92DB5897DC5D92DD5891DC5A91DC5A90DA5891' +
    'DC5A91DC5B92DD5A91DC5A91DC5A92DE5C92DC5A90DC5B90DA5A8EDC5C91DC5A' +
    '91DB5992DE5C91DC5A92DD5993DC5B91DC5A93DC5B92DD5992DB5B91DC5A0000' +
    '009BFD98700000002874524E53006CF76B63FEC85BFDEB2B53FCEF31164BFAF2' +
    '378B7644F8F53DD4653E24E8562FF97E3BF649590E45288DE500000001624B47' +
    '440088051D48000000097048597300000DD700000DD70142289B780000000774' +
    '494D4507E1051D112F23D6C0E2ED0000008B4944415478DA7D8F510B82401084' +
    '77400812D2483C480341CCFFFF737A305494483DB2C28703615524BC849AB719' +
    '86DD6F402BE17F8051BA37105EF5608320D31B26FC122F90F59CBD0D5141121C' +
    '47D69377B16F711BEF1E77F42E89FCDE7E70353D3A619B8AECC0EE9DDB992390' +
    '9E42ED15DC7DC042184429AB85346A44C2BD8E7ECE157F6F892FBFD70E626E28' +
    '2474A3DE1C0000002574455874646174653A63726561746500323031372D3035' +
    '2D32395431373A34373A33352B30323A3030ECAA1D3600000025744558746461' +
    '74653A6D6F6469667900323031372D30352D32395431373A34373A33352B3032' +
    '3A30309DF7A58A0000001974455874536F667477617265007777772E696E6B73' +
    '636170652E6F72679BEE3C1A0000000049454E44AE426082'
  );
end;

class procedure TFindUnitImageRepository.GetCheckWarnings(var Target: TPngImage);
begin
  GetGraphicFromText(Target,
    '0954506E67496D61676589504E470D0A1A0A0000000D49484452000000100000' +
    '001008060000001FF3FF610000000467414D410000B18F0BFC61050000000970' +
    '48597300000DD600000DD601906F799C0000000774494D4507E1051D112F32BC' +
    '70C21F0000001974455874536F667477617265007777772E696E6B7363617065' +
    '2E6F72679BEE3C1A000000FA49444154384FD592314EC350104473024A4E4047' +
    '81A82810546950CA4848881251919A920B50233CFF441C801350C06E5C202101' +
    '01C53B689D4DE42C0AA1A1E075FE6FC65EAFDDEBFD4B4C30A2E2DD0417D9ADC5' +
    '0467541815E4B8DC65FF23A638A5A269CB8ADAA4DACE99955031A4621AE56713' +
    'EC2EE4F4F17673299DA06240C567945F9AA76AAF2BAF435C2EB5022AFA544C22' +
    'F3CABA1CE4C07D489AE03CB9C3B634F37E937ED7CF4275D9A24222D4705C8EFD' +
    'DCC7F471E3DCC71FE4EE02936AC71713E10F2AAE3AD7BEB861EE7C8375D9A7E2' +
    '6DFE3AF389FCD3E5EC4AA838EA6CDBFCA7C999B55071D23E5930CAEED74C1E6E' +
    '36F2D99FF1056D83EF9A87DCDA1D0000000049454E44AE426082'
  );
end;

class procedure TFindUnitImageRepository.EnsureGDIPlus;
var
  StartupInput: TGdiplusStartupInput;
begin
  if FGDIPlusReady then
    Exit;

  StartupInput.GdiplusVersion := 1;
  StartupInput.DebugEventCallback := nil;
  StartupInput.SuppressBackgroundThread := False;
  StartupInput.SuppressExternalCodecs := False;
  FGDIPlusReady := GdiplusStartup(FGDIPlusToken, @StartupInput, nil) = Ok;
end;

class function TFindUnitImageRepository.CreateSVG(const TextBase: string): TSVG;
begin
  EnsureGDIPlus;
  Result := TSVG.Create;
  Result.LoadFromText(StringReplace(TextBase, '#FFE999', GetSVGColorHex, [rfReplaceAll]));
end;

class function TFindUnitImageRepository.GetCheckWarningsSVG: TSVG;
var
  Dark: Boolean;
begin
  Dark := IsDarkTheme;
  if (FSVGWarning = nil) or (FSVGDarkTheme <> Dark) then
  begin
    FSVGWarning.Free;
    FSVGWarning := CreateSVG(cSVGCheck);
    FSVGDarkTheme := Dark;
  end;
  Result := FSVGWarning;
end;

class function TFindUnitImageRepository.GetHourGlassSVG: TSVG;
var
  Dark: Boolean;
begin
  Dark := IsDarkTheme;
  if (FSVGHourGlass = nil) or (FSVGDarkTheme <> Dark) then
  begin
    FSVGHourGlass.Free;
    FSVGHourGlass := CreateSVG(cSVGHourGlass);
    FSVGDarkTheme := Dark;
  end;
  Result := FSVGHourGlass;
end;

class function TFindUnitImageRepository.GetSVGColorHex: string;
begin
  if IsDarkTheme then
    Result := cSVGColorDark
  else
    Result := cSVGColorLight;
end;

class function TFindUnitImageRepository.IsDarkTheme: Boolean;
var
  ThemingServices: IOTAIDEThemingServices;
  C: TColor;
begin
  Result := False;
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingServices) and
    ThemingServices.IDEThemingEnabled then
  begin
    C := ThemingServices.StyleServices.GetSystemColor(clWindow);
    Result := (0.299 * GetRValue(C) + 0.587 * GetGValue(C) + 0.114 * GetBValue(C)) < 128;
  end;
end;

class procedure TFindUnitImageRepository.GetGraphicFromText(var Graphic: TPngImage; ImageBaseText: string);
var
  ImageStream: TMemoryStream;
  ImageName: ShortString;
begin
  if Assigned(Graphic) then
    Exit;

  if not FRepository.TryGetValue(ImageBaseText, Graphic) then
  begin
    ImageStream := TMemoryStream.Create;
    ImageStream.Size := Length(ImageBaseText) div 2;
    HexToBin(PChar(ImageBaseText), ImageStream.Memory^, ImageStream.Size);

    ImageStream.Position := 0;
    ImageName := PShortString(ImageStream.Memory)^;
    Graphic := TPngImage.Create;
    ImageStream.Position := 1 + Length(ImageName);
    Graphic.LoadFromStream(ImageStream);
    ImageStream.Free;

    FRepository.Add(ImageBaseText, Graphic);
  end;
end;

class function TFindUnitImageRepository.GetImage(ImageType: TRfImageType): TPngImage;
begin
  Result := nil;
  case ImageType of
    girHourGlass: GetHourGlass(Result);
    girCheckedAllOk: GetCheckAllOk(Result);
    girCheckWithWarnings: GetCheckWarnings(Result);
  end;
end;

class procedure TFindUnitImageRepository.GetHourGlass(var Target: TPngImage);
begin
  GetGraphicFromText(Target,
    '0954506E67496D61676589504E470D0A1A0A0000000D49484452000000100000' +
    '00100804000000B5FA37EA0000000467414D410000B18F0BFC61050000000262' +
    '4B47440000AA8D2332000000097048597300000DD700000DD70142289B780000' +
    '000774494D4507E1051D11071FA4F230C0000000AC4944415478DA636400810B' +
    '0CFA0C98E0228301030323710AD419E631EC64D88424E9C7E0CE90C47013A680' +
    '816107C30A203B1CCA5BC9F09F2182C103C44456C0CE301DCCFFCF90C9F0135D' +
    'C106063E86640669A01206A0F45386B90C9F18029015F032B400EDEC60980064' +
    '17305400DD54C3F0195901081831CC64E001D25F18D219CEC104895640D00A82' +
    '8E24E84D90020D867228AF93E106AA0248502B30244215CC6778801AD494C426' +
    '00C11F3D11DC7AADEC0000002574455874646174653A63726561746500323031' +
    '372D30352D32395431373A30373A33312B30323A3030A83C4AA7000000257445' +
    '5874646174653A6D6F6469667900323031372D30352D32395431373A30373A33' +
    '312B30323A3030D961F21B0000001974455874536F667477617265007777772E' +
    '696E6B73636170652E6F72679BEE3C1A0000000049454E44AE426082');
end;

initialization
  TFindUnitImageRepository.FRepository := TObjectDictionary<string, TPngImage>.Create([doOwnsValues]);

finalization
  TFindUnitImageRepository.FSVGWarning.Free;
  TFindUnitImageRepository.FSVGHourGlass.Free;
  TFindUnitImageRepository.FRepository.Free;
  if TFindUnitImageRepository.FGDIPlusReady then
    GdiplusShutdown(TFindUnitImageRepository.FGDIPlusToken);

end.

