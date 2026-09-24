{******************************************************************************}
{ RFUXmlIntf - Dual-IDE XML DOM abstraction (Delphi / FPC)                    }
{                                                                            }
{ Delphi : re-exports Xml.XMLIntf + Xml.XMLDoc (native interfaces).          }
{ FPC    : implements the subset of IXMLDocument/IXMLNode/IXMLNodeList       }
{          used by the RFUSVG-Ekot components on top of fcl-xml DOM.         }
{                                                                            }
{ (c) 2026 HDFindUnit - MIT License                                          }
{******************************************************************************}
unit RFUXmlIntf;

interface

{$IFNDEF FPC}
uses
  Xml.XMLIntf,
  Xml.XMLDoc;
{$ENDIF}

{$IFDEF FPC}

type
  TNodeType = (ntReserved, ntElement, ntText, ntCData, ntEntityRef, ntEntity,
    ntProcessingInstruction, ntComment, ntDocument, ntDocumentType,
    ntDocumentFragment, ntNotation);

  IXMLNodeList = interface;
  IXMLNode = interface;
  IXMLDocument = interface;

  IXMLNodeList = interface(IInterface)
    ['{D3A2B7C4-9E81-4F0A-9C7E-55B2E81C1D01}']
    function GetCount: Integer;
    function GetItem(Index: Integer): IXMLNode;
    procedure Add(const ANode: IXMLNode);
    function FindNode(const ANodeName: string): IXMLNode;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: IXMLNode read GetItem; default;
  end;

  IXMLNode = interface(IInterface)
    ['{9F1B3D5A-7C26-4E8B-BD4F-6A0C31E5F902}']
    function GetNodeName: string;
    function GetNodeValue: string;
    function GetNodeType: TNodeType;
    function GetText: string;
    function GetXML: string;
    function GetChildNodes: IXMLNodeList;
    function GetAttributeNodes: IXMLNodeList;
    function GetAttributes(const AName: string): string;
    function HasAttribute(const AName: string): Boolean;
    function CloneNode(Deep: Boolean): IXMLNode;
    function GetOwnerDocument: IXMLDocument;
    property NodeName: string read GetNodeName;
    property nodeValue: string read GetNodeValue;
    property NodeType: TNodeType read GetNodeType;
    property Text: string read GetText;
    property XML: string read GetXML;
    property ChildNodes: IXMLNodeList read GetChildNodes;
    property AttributeNodes: IXMLNodeList read GetAttributeNodes;
    property Attributes[const AName: string]: string read GetAttributes; default;
    property OwnerDocument: IXMLDocument read GetOwnerDocument;
  end;

  IXMLDocument = interface(IInterface)
    ['{2B7E9F3C-1D48-4A65-8C0D-E7F3912A6B43}']
    function GetDocumentElement: IXMLNode;
    procedure LoadFromXML(const XML: string);
    function CreateElement(const ANodeName, ANamespaceURI: string): IXMLNode;
    property DocumentElement: IXMLNode read GetDocumentElement;
  end;

  TXMLDocument = class(TInterfacedObject, IXMLDocument)
  private
    FDoc: TObject;
  protected
    function GetDocumentElement: IXMLNode;
  public
    constructor Create(AOwner: TObject);
    procedure LoadFromXML(const XML: string);
    function CreateElement(const ANodeName, ANamespaceURI: string): IXMLNode;
    property DocumentElement: IXMLNode read GetDocumentElement;
  end;

{$ENDIF}

implementation

{$IFNDEF FPC}
end.
{$ELSE}

uses
  Classes,
  SysUtils,
  Variants,
  DOM,
  XMLRead,
  XMLWrite;

type
  { Internal access interface to unwrap an IXMLNode back to its TDOMNode. }
  IDOMNodeAccess = interface(IInterface)
    ['{7A4C9E2F-51B3-4D0E-8C17-A8FE5D63B902}']
    function GetDOMNode: TDOMNode;
  end;

  { Private TDOMDocument reference kept inside wrappers. }
  PDocHolder = ^TDOMDocument;

  TXMLNode = class(TInterfacedObject, IXMLNode, IDOMNodeAccess)
  private
    FNode: TDOMNode;
    FOwnerDoc: IXMLDocument;
  protected
    function GetNodeName: string;
    function GetNodeValue: string;
    function GetNodeType: TNodeType;
    function GetText: string;
    function GetXML: string;
    function GetChildNodes: IXMLNodeList;
    function GetAttributeNodes: IXMLNodeList;
    function GetAttributes(const AName: string): string;
    function HasAttribute(const AName: string): Boolean;
    function CloneNode(Deep: Boolean): IXMLNode;
    function GetOwnerDocument: IXMLDocument;
    function GetDOMNode: TDOMNode;
  public
    constructor Create(ANode: TDOMNode; const AOwnerDoc: IXMLDocument);
    destructor Destroy; override;
  end;

  TXMLNodeList = class(TInterfacedObject, IXMLNodeList)
  private
    FNode: TDOMNode;
    FIsAttributes: Boolean;
    FOwnerDoc: IXMLDocument;
  protected
    function GetCount: Integer;
    function GetItem(Index: Integer): IXMLNode;
    procedure Add(const ANode: IXMLNode);
    function FindNode(const ANodeName: string): IXMLNode;
  public
    constructor Create(ANode: TDOMNode; AIsAttributes: Boolean;
      const AOwnerDoc: IXMLDocument);
  end;

function TXMLDocument.GetDocumentElement: IXMLNode;
var
  Elem: TDOMElement;
begin
  if Assigned(FDoc) then
  begin
    Elem := TDOMDocument(FDoc).DocumentElement;
    if Assigned(Elem) then
      Result := TXMLNode.Create(Elem, Self as IXMLDocument)
    else
      Result := nil;
  end
  else
    Result := nil;
end;

constructor TXMLDocument.Create(AOwner: TObject);
begin
  inherited Create;
  FDoc := nil;
end;

procedure TXMLDocument.LoadFromXML(const XML: string);
var
  S: TStringStream;
  D: DOM.TXMLDocument;
begin
  if FDoc <> nil then
    (FDoc as TDOMDocument).Free;

  S := TStringStream.Create(XML);
  try
    ReadXMLFile(D, S);
    FDoc := D;
  finally
    S.Free;
  end;
end;

function TXMLDocument.CreateElement(const ANodeName, ANamespaceURI: string): IXMLNode;
var
  El: TDOMElement;
begin
  Result := nil;
  if FDoc = nil then
    Exit;
  El := TDOMDocument(FDoc).CreateElement(ANodeName);
  Result := TXMLNode.Create(El, Self as IXMLDocument);
end;

function TXMLNode.GetDOMNode: TDOMNode;
begin
  Result := FNode;
end;

constructor TXMLNode.Create(ANode: TDOMNode; const AOwnerDoc: IXMLDocument);
begin
  inherited Create;
  FNode := ANode;
  FOwnerDoc := AOwnerDoc;
end;

destructor TXMLNode.Destroy;
begin
  FNode := nil;
  FOwnerDoc := nil;
  inherited Destroy;
end;

function TXMLNode.GetNodeName: string;
begin
  if Assigned(FNode) then
    Result := FNode.NodeName
  else
    Result := '';
end;

function TXMLNode.GetNodeValue: string;
begin
  if Assigned(FNode) then
    Result := FNode.NodeValue
  else
    Result := '';
end;

function TXMLNode.GetNodeType: TNodeType;
begin
  Result := ntReserved;
  if Assigned(FNode) then
    case FNode.NodeType of
      ELEMENT_NODE: Result := ntElement;
      TEXT_NODE: Result := ntText;
      CDATA_SECTION_NODE: Result := ntCData;
      ATTRIBUTE_NODE: Result := ntElement; { not used by consumers }
    end;
end;

function TXMLNode.GetText: string;
begin
  if Assigned(FNode) then
    Result := FNode.TextContent
  else
    Result := '';
end;

function TXMLNode.GetXML: string;
var
  S: TStringStream;
  W: TStream;
begin
  Result := '';
  if FNode = nil then
    Exit;
  case FNode.NodeType of
    TEXT_NODE, CDATA_SECTION_NODE:
      Result := FNode.NodeValue;
  else
    S := TStringStream.Create('');
    try
      W := S;
      WriteXML(FNode, W);
      Result := S.DataString;
    finally
      S.Free;
    end;
  end;
end;

function TXMLNode.GetChildNodes: IXMLNodeList;
begin
  Result := TXMLNodeList.Create(FNode, False, FOwnerDoc);
end;

function TXMLNode.GetAttributeNodes: IXMLNodeList;
begin
  Result := TXMLNodeList.Create(FNode, True, FOwnerDoc);
end;

function TXMLNode.GetAttributes(const AName: string): string;
begin
  Result := '';
  if (FNode <> nil) and (FNode.Attributes <> nil) then
  begin
    if FNode.Attributes.GetNamedItem(AName) <> nil then
      Result := FNode.Attributes.GetNamedItem(AName).NodeValue;
  end;
end;

function TXMLNode.HasAttribute(const AName: string): Boolean;
begin
  Result := False;
  if (FNode <> nil) and (FNode.Attributes <> nil) then
    Result := FNode.Attributes.GetNamedItem(AName) <> nil;
end;

function TXMLNode.CloneNode(Deep: Boolean): IXMLNode;
var
  Cloned: TDOMNode;
begin
  Result := nil;
  if FNode = nil then
    Exit;
  Cloned := FNode.CloneNode(Deep);
  Result := TXMLNode.Create(Cloned, FOwnerDoc);
end;

function TXMLNode.GetOwnerDocument: IXMLDocument;
begin
  Result := FOwnerDoc;
end;

constructor TXMLNodeList.Create(ANode: TDOMNode; AIsAttributes: Boolean;
  const AOwnerDoc: IXMLDocument);
begin
  inherited Create;
  FNode := ANode;
  FIsAttributes := AIsAttributes;
  FOwnerDoc := AOwnerDoc;
end;

function TXMLNodeList.GetCount: Integer;
begin
  Result := 0;
  if FNode = nil then
    Exit;
  if FIsAttributes then
  begin
    if FNode.Attributes <> nil then
      Result := FNode.Attributes.Length;
  end
  else
    Result := FNode.ChildNodes.Count;
end;

function TXMLNodeList.GetItem(Index: Integer): IXMLNode;
var
  N: TDOMNode;
begin
  Result := nil;
  if FNode = nil then
    Exit;
  if FIsAttributes then
  begin
    if (FNode.Attributes <> nil) and (Index >= 0) and
      (Index < Integer(FNode.Attributes.Length)) then
      N := FNode.Attributes.Item[Index];
  end
  else
  begin
    if (Index >= 0) and (Index < Integer(FNode.ChildNodes.Count)) then
      N := FNode.ChildNodes.Item[Index];
  end;

  if Assigned(N) then
    Result := TXMLNode.Create(N, FOwnerDoc);
end;

procedure TXMLNodeList.Add(const ANode: IXMLNode);
var
  Acc: IDOMNodeAccess;
  NewNode: TDOMNode;
begin
  if (FNode = nil) or (ANode = nil) then
    Exit;
  if Supports(ANode, IDOMNodeAccess, Acc) then
  begin
    NewNode := Acc.GetDOMNode;
    if NewNode <> nil then
      FNode.AppendChild(NewNode);
  end;
end;

function TXMLNodeList.FindNode(const ANodeName: string): IXMLNode;
var
  N: TDOMNode;
  K: Integer;
begin
  Result := nil;
  if FNode = nil then
    Exit;

  if FIsAttributes then
  begin
    if FNode.Attributes <> nil then
    begin
      N := FNode.Attributes.GetNamedItem(ANodeName);
      if Assigned(N) then
        Result := TXMLNode.Create(N, FOwnerDoc);
    end;
  end
  else
  begin
    for K := 0 to FNode.ChildNodes.Count - 1 do
    begin
      N := FNode.ChildNodes.Item[K];
      if N.NodeName = ANodeName then
      begin
        Result := TXMLNode.Create(N, FOwnerDoc);
        Break;
      end;
    end;
  end;
end;

{$ENDIF}

end.