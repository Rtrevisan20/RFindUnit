unit HDFindUnit.Model.DelphiVlcWrapper;

interface

uses
{$IFDEF FPC}
  Classes,
  Types;
{$ELSE}
  Winapi.Windows;
{$ENDIF}

type
  TDelphiVLCWrapper = class(TObject)
  private
{$IFNDEF FPC}
    class procedure FindEditorHandle;
{$ENDIF}
  public
    class function GetEditorRect: TRect;
    class function GetEditorControlHandle: THandle;
  end;

implementation

uses
{$IFDEF FPC}
  Controls,
  SrcEditorIntf;
{$ELSE}
  Winapi.Messages;
{$ENDIF}

{$IFNDEF FPC}
var
  FFound: Boolean;
  FEditHandler: Cardinal;

{ TDelphiVLCWrapper }

function EnumChildProc(AHandle: THandle; Params: integer): BOOL; stdcall;
var
  Buffer: array[0..255] of Char;
  Caption: array[0..255] of Char;
  Item: string;
begin
  if FFound then
    Exit(False);

  Result := True;
  GetClassName(AHandle, Buffer, SizeOf(Buffer)-1);
  SendMessage(AHandle, WM_GETTEXT, 256, Integer(@Caption));

  Item := Buffer;

  if Item = 'TEditControl' then
  begin
    FEditHandler := AHandle;
    FFound := True;
    Exit;
  end;

  EnumChildWindows(AHandle, @EnumChildProc, 0)
end;

class procedure TDelphiVLCWrapper.FindEditorHandle;
var
  DelphiHand: Cardinal;
begin
  FFound := False;
  DelphiHand := FindWindow('TAppBuilder', nil);
  EnumChildWindows(DelphiHand, @EnumChildProc, 0);
  FFound := True;
end;

class function TDelphiVLCWrapper.GetEditorRect: TRect;
begin
  if not FFound then
    FindEditorHandle;
  if not Winapi.Windows.GetWindowRect(FEditHandler, Result) then
  begin
    Result.Left := 20;
    Result.Top := 20;
    Result.Right := 20;
  end;
end;

class function TDelphiVLCWrapper.GetEditorControlHandle: THandle;
begin
  if not FFound then
    FindEditorHandle;
  Result := FEditHandler;
end;
{$ENDIF}

{$IFDEF FPC}
class function TDelphiVLCWrapper.GetEditorRect: TRect;
var
  Editor: TSourceEditorInterface;
  EditorCtl: TWinControl;
begin
  Result := Rect(20, 20, 20, 20);
  if SourceEditorManagerIntf = nil then
    Exit;
  Editor := SourceEditorManagerIntf.ActiveEditor;
  if Editor = nil then
    Exit;
  EditorCtl := Editor.EditorControl;
  if EditorCtl = nil then
    Exit;
  Result.TopLeft := EditorCtl.ClientToScreen(Point(0, 0));
  Result.BottomRight := EditorCtl.ClientToScreen(Point(EditorCtl.ClientWidth, EditorCtl.ClientHeight));
end;

class function TDelphiVLCWrapper.GetEditorControlHandle: THandle;
var
  Editor: TSourceEditorInterface;
begin
  Result := 0;
  if SourceEditorManagerIntf = nil then
    Exit;
  Editor := SourceEditorManagerIntf.ActiveEditor;
  if Editor = nil then
    Exit;
  if Editor.EditorControl = nil then
    Exit;
  Result := Editor.EditorControl.Handle;
end;
{$ENDIF}

end.

