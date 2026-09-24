{******************************************************************}
      { Portable XML façade for the SVG core (task 3.3)                }
      {                                                                  }
      { On Delphi it re-exports Xml.Intf/XmlDoc types as aliases so the }
      { core compiles unchanged and keeps byte-identical rendering.     }
      { On FPC it implements the same surface over fcl-xml (DOM/XMLRead) }
      { keeping the core's counter-interface (IXMLNode & friends).      }
      {                                                                  }
      { This file (c) 2026 DelphiSVG port.                               }
      { *****************************************************************}

unit SVGXML;

interface

{$IFDEF FPC}
uses
  Classes, SysUtils, Variants, DOM, XMLRead;
{$ELSE}
uses
  Xml.XmlIntf, Xml.XmlDoc,
{$IFDEF MSWINDOWS}
  Xml.Win.msxmldom;
{$ELSE}
  ;
{$ENDIF}
{$ENDIF}

type
{$IFDEF FPC}
  TNodeType = (ntReserved, ntElement, ntAttribute, ntText, ntCData,
    ntEntityRef, ntEntity, ntProcessingInstr, ntComment, ntDocument,
    ntDocType, ntDocFragment, ntNotation);

  IXMLNodeList = interface;
  IXMLNode = interface;
  IXMLDocument = interface;

  { IXMLNodeList }

  IXMLNodeList = interface
    ['{395950C1-7E5D-11D4-83DA-00C04F60B2DD}']
    function GetCount: Integer;
    function GetNode(const IndexOrName: OleVariant): IXMLNode;
    function Add(const Node: IXMLNode): Integer;
    function FindNode(NodeName: DOMString): IXMLNode;
    property Count: Integer read GetCount;
    property Nodes[const IndexOrName: OleVariant]: IXMLNode read GetNode; default;
  end;

  { IXMLNode }

  IXMLNode = interface
    ['{395950C0-7E5D-11D4-83DA-00C04F60B2DD}']
    function GetAttribute(const AttrName: DOMString): OleVariant;
    function GetAttributeNodes: IXMLNodeList;
    function GetChildNodes: IXMLNodeList;
    function GetNodeName: DOMString;
    function GetNodeType: TNodeType;
    function GetNodeValue: OleVariant;
    function GetOwnerDocument: IXMLDocument;
    function GetText: DOMString;
    function GetXML: DOMString;
    function HasAttribute(const Name: DOMString): Boolean;
    function CloneNode(Deep: Boolean): IXMLNode;
    property Attributes[const AttrName: DOMString]: OleVariant read GetAttribute;
    property AttributeNodes: IXMLNodeList read GetAttributeNodes;
    property ChildNodes: IXMLNodeList read GetChildNodes;
    property NodeName: DOMString read GetNodeName;
    property NodeType: TNodeType read GetNodeType;
    property NodeValue: OleVariant read GetNodeValue;
    property OwnerDocument: IXMLDocument read GetOwnerDocument;
    property Text: DOMString read GetText;
    property XML: DOMString read GetXML;
  end;

  { IXMLDocument }

  IXMLDocument = interface
    ['{395950C3-7E5D-11D4-83DA-00C04F60B2DD}']
    procedure LoadFromXML(const XML: DOMString);
    function GetDocumentElement: IXMLNode;
    function CreateElement(const TagOrData, NamespaceURI: DOMString): IXMLNode;
    property DocumentElement: IXMLNode read GetDocumentElement;
  end;

  { Creates a document instance honoring the DTD option. The core should
    call this instead of TXmlDocument.Create directly. }

  function CreateSVGXmlDocument: IXMLDocument;

{$ELSE}

  { Re-export the Delphi RTL XML types so the core keeps its interface. }

  IXMLNode = Xml.XmlIntf.IXMLNode;
  IXMLNodeList = Xml.XmlIntf.IXMLNodeList;
  IXMLDocument = Xml.XmlIntf.IXMLDocument;
  TXmlDocument = Xml.XmlDoc.TXmlDocument;
  TNodeType = Xml.XmlIntf.TNodeType;

  function CreateSVGXmlDocument: IXMLDocument;

{$ENDIF}

implementation

{$IFDEF FPC}

type
  { Internal accessor so the node list can append the wrapped DOM node
    without relying on a class cast from the public interface. }
  ISVGXmlNode = interface
    ['{9A214C10-3A7E-4B21-9D4F-56B0C0E2C7E3}']
    function GetDOMNode: TDOMNode;
  end;

  TSVGXmlDocument = class; // forward

  { FPC wrapper around a DOM node. Holds the owner document by interface
    so the underlying TDOMDocument stays alive while a node is referenced. }

  TSVGXmlNode = class(TInterfacedObject, IXMLNode, ISVGXmlNode)
  private
    FNode: TDOMNode;
    FOwnerDocument: IXMLDocument;
    function GetAttribute(const AttrName: DOMString): OleVariant;
    function GetAttributeNodes: IXMLNodeList;
    function GetChildNodes: IXMLNodeList;
    function GetNodeName: DOMString;
    function GetNodeType: TNodeType;
    function GetNodeValue: OleVariant;
    function GetOwnerDocument: IXMLDocument;
    function GetText: DOMString;
    function GetXML: DOMString;
    function HasAttribute(const Name: DOMString): Boolean;
    function CloneNode(Deep: Boolean): IXMLNode;
    function GetDOMNode: TDOMNode;
  public
    constructor Create(ANode: TDOMNode; const ADocument: IXMLDocument);
  end;

  { FPC node list (child nodes or attribute map) over a DOM node. }

  TSVGXmlNodeList = class(TInterfacedObject, IXMLNodeList)
  private
    FParent: TDOMNode;
    FAttributes: Boolean;
    FOwnerDocument: IXMLDocument;
    function GetCount: Integer;
    function GetNode(const IndexOrName: OleVariant): IXMLNode;
    function Add(const Node: IXMLNode): Integer;
    function FindNode(NodeName: DOMString): IXMLNode;
  public
    constructor Create(AParent: TDOMNode; AAttributes: Boolean;
      const ADocument: IXMLDocument);
  end;

  { FPC document wrapper over DOM.TXMLDocument. }

  TSVGXmlDocument = class(TInterfacedObject, IXMLDocument)
  private
    FDoc: DOM.TXMLDocument;
    procedure LoadFromXML(const XML: DOMString);
    function GetDocumentElement: IXMLNode;
    function CreateElement(const TagOrData, NamespaceURI: DOMString): IXMLNode;
  public
    destructor Destroy; override;
  end;

  TXmlDocument = class(TSVGXmlDocument)
  public
    constructor Create(AOwner: TObject = nil);
  end;

  { TXmlDocument }

  constructor TXmlDocument.Create(AOwner: TObject = nil);
  begin
    inherited Create;
  end;

  { TSVGXmlDocument }

  destructor TSVGXmlDocument.Destroy;
  begin
    FDoc.Free;
    inherited Destroy;
  end;

  procedure TSVGXmlDocument.LoadFromXML(const XML: DOMString);
  var
    Stream: TStringStream;
  begin
    FreeAndNil(FDoc);
    Stream := TStringStream.Create(UTF8Encode(XML));
    try
      ReadXMLFile(FDoc, Stream);
    finally
      Stream.Free;
    end;
  end;

  function TSVGXmlDocument.GetDocumentElement: IXMLNode;
  begin
    Result := nil;
    if Assigned(FDoc) and Assigned(FDoc.DocumentElement) then
      Result := TSVGXmlNode.Create(FDoc.DocumentElement, Self as IXMLDocument);
  end;

  function TSVGXmlDocument.CreateElement(const TagOrData,
    NamespaceURI: DOMString): IXMLNode;
  begin
    Result := nil;
    if Assigned(FDoc) then
      Result := TSVGXmlNode.Create(FDoc.CreateElement(TagOrData),
        Self as IXMLDocument);
  end;

  { TSVGXmlNode }

  constructor TSVGXmlNode.Create(ANode: TDOMNode;
    const ADocument: IXMLDocument);
  begin
    inherited Create;
    FNode := ANode;
    FOwnerDocument := ADocument;
  end;

  function TSVGXmlNode.GetAttribute(const AttrName: DOMString): OleVariant;
  begin
    if (FNode <> nil) and (FNode is TDOMElement) then
      Result := TDOMElement(FNode).GetAttribute(AttrName)
    else
      Result := '';
  end;

  function TSVGXmlNode.GetAttributeNodes: IXMLNodeList;
  begin
    Result := TSVGXmlNodeList.Create(FNode, True, FOwnerDocument);
  end;

  function TSVGXmlNode.GetChildNodes: IXMLNodeList;
  begin
    Result := TSVGXmlNodeList.Create(FNode, False, FOwnerDocument);
  end;

  function TSVGXmlNode.GetDOMNode: TDOMNode;
  begin
    Result := FNode;
  end;

  function TSVGXmlNode.GetNodeName: DOMString;
  begin
    if FNode <> nil then
      Result := FNode.NodeName
    else
      Result := '';
  end;

  function TSVGXmlNode.GetNodeType: TNodeType;
  begin
    if FNode <> nil then
      Result := TNodeType(FNode.NodeType)
    else
      Result := TNodeType.ntDocument;
  end;

  function TSVGXmlNode.GetNodeValue: OleVariant;
  begin
    if FNode <> nil then
      Result := FNode.NodeValue
    else
      Result := '';
  end;

  function TSVGXmlNode.GetOwnerDocument: IXMLDocument;
  begin
    Result := FOwnerDocument;
  end;

  function TSVGXmlNode.GetText: DOMString;
  begin
    if FNode = nil then
      Result := ''
    else if FNode is TDOMAttr then
      Result := FNode.NodeValue
    else
      Result := FNode.TextContent;
  end;

  function TSVGXmlNode.GetXML: DOMString;
  begin
    if FNode = nil then
      Result := ''
    else if FNode.NodeType in [TEXT_NODE, CDATA_SECTION_NODE] then
      Result := FNode.NodeValue
    else
      Result := FNode.TextContent;
  end;

  function TSVGXmlNode.CloneNode(Deep: Boolean): IXMLNode;
  begin
    Result := nil;
    if FNode <> nil then
      Result := TSVGXmlNode.Create(FNode.CloneNode(Deep), FOwnerDocument);
  end;

  function TSVGXmlNode.HasAttribute(const Name: DOMString): Boolean;
  begin
    Result := (FNode <> nil) and
      (FNode.Attributes <> nil) and
      (FNode.Attributes.GetNamedItem(Name) <> nil);
  end;

  { TSVGXmlNodeList }

  constructor TSVGXmlNodeList.Create(AParent: TDOMNode;
    AAttributes: Boolean; const ADocument: IXMLDocument);
  begin
    inherited Create;
    FParent := AParent;
    FAttributes := AAttributes;
    FOwnerDocument := ADocument;
  end;

  function TSVGXmlNodeList.GetCount: Integer;
  begin
    Result := 0;
    if FParent = nil then
      Exit;
    if FAttributes then
      Result := Integer(FParent.Attributes.Length)
    else
      Result := Integer(FParent.ChildNodes.Count);
  end;

  function TSVGXmlNodeList.GetNode(const IndexOrName: OleVariant): IXMLNode;
  var
    Node: TDOMNode;
  begin
    Result := nil;
    if FParent = nil then
      Exit;
    if TVarData(IndexOrName).VType in [varInteger, varSmallint, varShortInt,
      varByte, varWord, varLongWord, varInt64, varQWord] then
    begin
      if FAttributes then
        Node := FParent.Attributes.Item[LongWord(Integer(IndexOrName))]
      else
        Node := FParent.ChildNodes.Item[LongWord(Integer(IndexOrName))];
    end
    else if Assigned(FParent.Attributes) then
      Node := FParent.Attributes.GetNamedItem(UnicodeString(VarToStr(IndexOrName)))
    else
      Node := nil;
    if Node <> nil then
      Result := TSVGXmlNode.Create(Node, FOwnerDocument);
  end;

  function TSVGXmlNodeList.Add(const Node: IXMLNode): Integer;
  var
    Typed: ISVGXmlNode;
  begin
    Result := 0;
    if (FParent = nil) or not Assigned(Node) then
      Exit;
    if Supports(Node, ISVGXmlNode, Typed) then
      FParent.AppendChild(Typed.GetDOMNode);
    Result := GetCount;
  end;

  function TSVGXmlNodeList.FindNode(NodeName: DOMString): IXMLNode;
  var
    Node: TDOMNode;
    C: LongWord;
  begin
    Result := nil;
    if FParent = nil then
      Exit;
    if FAttributes then
    begin
      Node := FParent.Attributes.GetNamedItem(NodeName);
      if Node <> nil then
        Result := TSVGXmlNode.Create(Node, FOwnerDocument);
    end
    else
    begin
      for C := 0 to FParent.ChildNodes.Count - 1 do
      begin
        Node := FParent.ChildNodes.Item[C];
        if (Node <> nil) and (Node.NodeName = NodeName) then
        begin
          Result := TSVGXmlNode.Create(Node, FOwnerDocument);
          Break;
        end;
      end;
    end;
  end;

  { CreateSVGXmlDocument }

  function CreateSVGXmlDocument: IXMLDocument;
  begin
    Result := TXmlDocument.Create(nil);
  end;

{$ELSE}

  { CreateSVGXmlDocument — Delphi. Allow DTD before creating the MSXML
    document (same sequence the core used before the port). }

  function CreateSVGXmlDocument: IXMLDocument;
  begin
  {$IFDEF MSWINDOWS}
    TMSXMLDOMDocumentFactory.AddDOMProperty('ProhibitDTD', False, True);
  {$ENDIF}
    Result := TXmlDocument.Create(nil);
  end;

{$ENDIF}

end.