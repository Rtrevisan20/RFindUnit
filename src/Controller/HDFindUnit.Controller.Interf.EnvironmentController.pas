unit HDFindUnit.Controller.Interf.EnvironmentController;

interface

uses
  System.Classes;

type
  IRFUEnvironmentController = interface
    ['{A53012B2-303C-4E12-8891-B8B18DAB4487}']
    function GetFullMatch(const SearchString: string): TStringList;
    function GetElementMatches(const ElementName: string): TStringList;
    function PasExists(PasName: string): Boolean;
    function IsFileIndexed(FilePath: string): Boolean;
    function AreDependenciasReady: Boolean;
    procedure ForceRunDependencies;
  end;

implementation

end.
