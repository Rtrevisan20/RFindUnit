unit HDFindUnit.Model.Translation;

interface

uses
  HDFindUnit.Model.Interf.Translation;

function CreateTranslation(const LangIndex: Integer): IRFUTranslation;
function Translation: IRFUTranslation;

implementation

uses
  SysUtils;

type
  TTranslationBase = class(TInterfacedObject, IRFUTranslation)
  protected
    function GetName: string; virtual; abstract;

    function GetUnusedUsesIndexing: string; virtual; abstract;
    function GetUnusedUsesAnalyzing: string; virtual; abstract;
    function GetUnusedUsesAllUsed: string; virtual; abstract;
    function GetUnusedUsesUnused(const Units: string): string; virtual; abstract;
    function GetUnusedUsesError(const Msg: string): string; virtual; abstract;
    function GetUnusedUsesNotIndexed: string; virtual; abstract;

    function GetOrganizeUsesDone: string; virtual; abstract;
    function GetOrganizeUsesWarning: string; virtual; abstract;

    function GetUnitAddedToInterface(const UnitName: string): string; virtual; abstract;
    function GetUnitAddedToImplementation(const UnitName: string): string; virtual; abstract;

    function GetDCUConfirmProcess: string; virtual; abstract;
    function GetDCUConfirmMessage: string; virtual; abstract;

    function GetStatusReady: string; virtual; abstract;
    function GetStatusPreparing: string; virtual; abstract;
    function GetStatusProcessing(const Current, Total: Integer): string; virtual; abstract;
    function GetStatusFilesProcessed(const Current, Total: Integer): string; virtual; abstract;

    function GetErrorRefreshLibraryPath(const Msg: string): string; virtual; abstract;
    function GetErrorRefreshProject(const Msg: string): string; virtual; abstract;

    function GetSettingsTitle: string; virtual; abstract;
    function GetSettingsGeneral: string; virtual; abstract;
    function GetSettingsShortcuts: string; virtual; abstract;
    function GetSettingsAutoImport: string; virtual; abstract;
    function GetSettingsUnusedUses: string; virtual; abstract;
    function GetSettingsLanguage: string; virtual; abstract;
    function GetSettingsEnabled: string; virtual; abstract;
    function GetSettingsOpenConfigFile: string; virtual; abstract;
    function GetSettingsAlwaysInterface: string; virtual; abstract;
    function GetSettingsSortByLevel: string; virtual; abstract;
    function GetSettingsSortByLevelHint: string; virtual; abstract;
    function GetSettingsSortAlphabetic: string; virtual; abstract;
    function GetSettingsBreakLine: string; virtual; abstract;
    function GetSettingsBlankLineNamespace: string; virtual; abstract;
    function GetSettingsBlankLineNamespaceHint: string; virtual; abstract;
    function GetSettingsOrganizeAfterInsert: string; virtual; abstract;
    function GetSettingsGroupNonNamespace: string; virtual; abstract;
    function GetSettingsGroupNonNamespaceHint: string; virtual; abstract;
    function GetSettingsDontBreakNonNamespace: string; virtual; abstract;
    function GetSettingsDontBreakNonNamespaceHint: string; virtual; abstract;
    function GetSettingsBreakLineAt: string; virtual; abstract;
    function GetSettingsSortHint: string; virtual; abstract;
    function GetSettingsCreateProjectConfig: string; virtual; abstract;
    function GetSettingsExperimentalUnused: string; virtual; abstract;
    function GetSettingsEnableHighlight: string; virtual; abstract;
    function GetSettingsUnderlineMeaning: string; virtual; abstract;
    function GetSettingsImportNotUsed: string; virtual; abstract;
    function GetSettingsDCUNoAccess: string; virtual; abstract;
function GetSettingsDCPDistributed: string; virtual; abstract;
    function GetSettingsMatchAlgorithm: string; virtual; abstract;
    function GetSettingsRememberChoices: string; virtual; abstract;
    function GetSettingsOrganizeUses: string; virtual; abstract;

    function GetFormSearchTitle: string; virtual; abstract;
    function GetFormSearchOptions: string; virtual; abstract;
    function GetFormSearchResult: string; virtual; abstract;
    function GetFormSearchSearch: string; virtual; abstract;
    function GetFormSearchAddTo: string; virtual; abstract;
    function GetFormSearchInterface: string; virtual; abstract;
    function GetFormSearchImplementation: string; virtual; abstract;
    function GetFormSearchAdd: string; virtual; abstract;
    function GetFormSearchSearchHint: string; virtual; abstract;
    function GetFormSearchRefresh: string; virtual; abstract;
    function GetFormSearchProcessDCU: string; virtual; abstract;
    function GetFormSearchDCUWarning: string; virtual; abstract;
    function GetFormSearchSearchLibraryPath: string; virtual; abstract;
    function GetFormSearchSearchProject: string; virtual; abstract;
    function GetFormSearchConfigure: string; virtual; abstract;
    function GetFormSearchTooManyResults: string; virtual; abstract;
    function GetFormSearchTooManyResultsHint: string; virtual; abstract;

    function GetAutoImportNoUnitsToImport: string; virtual; abstract;

    function GetMenuTitle: string; virtual; abstract;
    function GetMenuForceRegister: string; virtual; abstract;
  end;

  TTranslationPTBR = class(TTranslationBase)
  protected
    function GetName: string; override;

    function GetUnusedUsesIndexing: string; override;
    function GetUnusedUsesAnalyzing: string; override;
    function GetUnusedUsesAllUsed: string; override;
    function GetUnusedUsesUnused(const Units: string): string; override;
    function GetUnusedUsesError(const Msg: string): string; override;
    function GetUnusedUsesNotIndexed: string; override;

    function GetOrganizeUsesDone: string; override;
    function GetOrganizeUsesWarning: string; override;

    function GetUnitAddedToInterface(const UnitName: string): string; override;
    function GetUnitAddedToImplementation(const UnitName: string): string; override;

    function GetDCUConfirmProcess: string; override;
    function GetDCUConfirmMessage: string; override;

    function GetStatusReady: string; override;
    function GetStatusPreparing: string; override;
    function GetStatusProcessing(const Current, Total: Integer): string; override;
    function GetStatusFilesProcessed(const Current, Total: Integer): string; override;

    function GetErrorRefreshLibraryPath(const Msg: string): string; override;
    function GetErrorRefreshProject(const Msg: string): string; override;

    function GetSettingsTitle: string; override;
    function GetSettingsGeneral: string; override;
    function GetSettingsShortcuts: string; override;
    function GetSettingsAutoImport: string; override;
    function GetSettingsUnusedUses: string; override;
    function GetSettingsLanguage: string; override;
    function GetSettingsEnabled: string; override;
    function GetSettingsOpenConfigFile: string; override;
    function GetSettingsAlwaysInterface: string; override;
    function GetSettingsSortByLevel: string; override;
    function GetSettingsSortByLevelHint: string; override;
    function GetSettingsSortAlphabetic: string; override;
    function GetSettingsBreakLine: string; override;
    function GetSettingsBlankLineNamespace: string; override;
    function GetSettingsBlankLineNamespaceHint: string; override;
    function GetSettingsOrganizeAfterInsert: string; override;
    function GetSettingsGroupNonNamespace: string; override;
    function GetSettingsGroupNonNamespaceHint: string; override;
    function GetSettingsDontBreakNonNamespace: string; override;
    function GetSettingsDontBreakNonNamespaceHint: string; override;
    function GetSettingsBreakLineAt: string; override;
    function GetSettingsSortHint: string; override;
    function GetSettingsCreateProjectConfig: string; override;
    function GetSettingsExperimentalUnused: string; override;
    function GetSettingsEnableHighlight: string; override;
    function GetSettingsUnderlineMeaning: string; override;
    function GetSettingsImportNotUsed: string; override;
    function GetSettingsDCUNoAccess: string; override;
    function GetSettingsDCPDistributed: string; override;
    function GetSettingsMatchAlgorithm: string; override;
    function GetSettingsRememberChoices: string; override;
    function GetSettingsOrganizeUses: string; override;

    function GetFormSearchTitle: string; override;
    function GetFormSearchOptions: string; override;
    function GetFormSearchResult: string; override;
    function GetFormSearchSearch: string; override;
    function GetFormSearchAddTo: string; override;
    function GetFormSearchInterface: string; override;
    function GetFormSearchImplementation: string; override;
    function GetFormSearchAdd: string; override;
    function GetFormSearchSearchHint: string; override;
    function GetFormSearchRefresh: string; override;
    function GetFormSearchProcessDCU: string; override;
    function GetFormSearchDCUWarning: string; override;
    function GetFormSearchSearchLibraryPath: string; override;
    function GetFormSearchSearchProject: string; override;
    function GetFormSearchConfigure: string; override;
    function GetFormSearchTooManyResults: string; override;
    function GetFormSearchTooManyResultsHint: string; override;

    function GetAutoImportNoUnitsToImport: string; override;

    function GetMenuTitle: string; override;
    function GetMenuForceRegister: string; override;
  end;

  TTranslationEN = class(TTranslationBase)
  protected
    function GetName: string; override;

    function GetUnusedUsesIndexing: string; override;
    function GetUnusedUsesAnalyzing: string; override;
    function GetUnusedUsesAllUsed: string; override;
    function GetUnusedUsesUnused(const Units: string): string; override;
    function GetUnusedUsesError(const Msg: string): string; override;
    function GetUnusedUsesNotIndexed: string; override;

    function GetOrganizeUsesDone: string; override;
    function GetOrganizeUsesWarning: string; override;

    function GetUnitAddedToInterface(const UnitName: string): string; override;
    function GetUnitAddedToImplementation(const UnitName: string): string; override;

    function GetDCUConfirmProcess: string; override;
    function GetDCUConfirmMessage: string; override;

    function GetStatusReady: string; override;
    function GetStatusPreparing: string; override;
    function GetStatusProcessing(const Current, Total: Integer): string; override;
    function GetStatusFilesProcessed(const Current, Total: Integer): string; override;

    function GetErrorRefreshLibraryPath(const Msg: string): string; override;
    function GetErrorRefreshProject(const Msg: string): string; override;

    function GetSettingsTitle: string; override;
    function GetSettingsGeneral: string; override;
    function GetSettingsShortcuts: string; override;
    function GetSettingsAutoImport: string; override;
    function GetSettingsUnusedUses: string; override;
    function GetSettingsLanguage: string; override;
    function GetSettingsEnabled: string; override;
    function GetSettingsOpenConfigFile: string; override;
    function GetSettingsAlwaysInterface: string; override;
    function GetSettingsSortByLevel: string; override;
    function GetSettingsSortByLevelHint: string; override;
    function GetSettingsSortAlphabetic: string; override;
    function GetSettingsBreakLine: string; override;
    function GetSettingsBlankLineNamespace: string; override;
    function GetSettingsBlankLineNamespaceHint: string; override;
    function GetSettingsOrganizeAfterInsert: string; override;
    function GetSettingsGroupNonNamespace: string; override;
    function GetSettingsGroupNonNamespaceHint: string; override;
    function GetSettingsDontBreakNonNamespace: string; override;
    function GetSettingsDontBreakNonNamespaceHint: string; override;
    function GetSettingsBreakLineAt: string; override;
    function GetSettingsSortHint: string; override;
    function GetSettingsCreateProjectConfig: string; override;
    function GetSettingsExperimentalUnused: string; override;
    function GetSettingsEnableHighlight: string; override;
    function GetSettingsUnderlineMeaning: string; override;
    function GetSettingsImportNotUsed: string; override;
    function GetSettingsDCUNoAccess: string; override;
    function GetSettingsDCPDistributed: string; override;
    function GetSettingsMatchAlgorithm: string; override;
    function GetSettingsRememberChoices: string; override;
    function GetSettingsOrganizeUses: string; override;

    function GetFormSearchTitle: string; override;
    function GetFormSearchOptions: string; override;
    function GetFormSearchResult: string; override;
    function GetFormSearchSearch: string; override;
    function GetFormSearchAddTo: string; override;
    function GetFormSearchInterface: string; override;
    function GetFormSearchImplementation: string; override;
    function GetFormSearchAdd: string; override;
    function GetFormSearchSearchHint: string; override;
    function GetFormSearchRefresh: string; override;
    function GetFormSearchProcessDCU: string; override;
    function GetFormSearchDCUWarning: string; override;
    function GetFormSearchSearchLibraryPath: string; override;
    function GetFormSearchSearchProject: string; override;
    function GetFormSearchConfigure: string; override;
    function GetFormSearchTooManyResults: string; override;
    function GetFormSearchTooManyResultsHint: string; override;

    function GetAutoImportNoUnitsToImport: string; override;

    function GetMenuTitle: string; override;
    function GetMenuForceRegister: string; override;
  end;

var
  FCurrentTranslation: IRFUTranslation;

function CreateTranslation(const LangIndex: Integer): IRFUTranslation;
begin
  case LangIndex of
    1: Result := TTranslationEN.Create;
  else
    Result := TTranslationPTBR.Create;
  end;
  FCurrentTranslation := Result;
end;

function Translation: IRFUTranslation;
begin
  if FCurrentTranslation = nil then
    FCurrentTranslation := TTranslationPTBR.Create;
  Result := FCurrentTranslation;
end;

{ TTranslationPTBR }

function TTranslationPTBR.GetName: string;
begin
  Result := 'Português (BR)';
end;

function TTranslationPTBR.GetUnusedUsesIndexing: string;
begin
  Result := 'Indexação do projeto ainda em andamento. Aguarde alguns segundos e tente novamente.';
end;

function TTranslationPTBR.GetUnusedUsesAnalyzing: string;
begin
  Result := 'Analisando units não utilizadas...';
end;

function TTranslationPTBR.GetUnusedUsesAllUsed: string;
begin
  Result := 'Todas as units estão sendo utilizadas.';
end;

function TTranslationPTBR.GetUnusedUsesUnused(const Units: string): string;
begin
  Result := 'Units não utilizadas: ' + Units;
end;

function TTranslationPTBR.GetUnusedUsesError(const Msg: string): string;
begin
  Result := 'Erro ao analisar units: ' + Msg;
end;

function TTranslationPTBR.GetUnusedUsesNotIndexed: string;
begin
  Result := 'O arquivo atual não pertence ao projeto ou biblioteca indexados. Abra o projeto correto (ou aguarde a indexação terminar) e tente novamente.';
end;

function TTranslationPTBR.GetOrganizeUsesDone: string;
begin
  Result := 'Uses organizadas.';
end;

function TTranslationPTBR.GetOrganizeUsesWarning: string;
begin
  Result := 'Se as Uses contiverem comentários ou IFDEF, não serão organizadas.';
end;

function TTranslationPTBR.GetUnitAddedToInterface(const UnitName: string): string;
begin
  Result := 'Unit ' + UnitName + ' adicionada às uses de interface.';
end;

function TTranslationPTBR.GetUnitAddedToImplementation(const UnitName: string): string;
begin
  Result := 'Unit ' + UnitName + ' adicionada às uses de implementation.';
end;

function TTranslationPTBR.GetDCUConfirmProcess: string;
begin
  Result := 'Este comando irá listar todos os arquivos DCUs/PAS que você não tem acesso '
      + 'e processá-los para torná-los disponíveis para pesquisa. '
      + 'Este processo deixará seu computador lento e pode levar alguns minutos (~2). '
      + 'Tem certeza que deseja executá-lo agora?';
end;

function TTranslationPTBR.GetDCUConfirmMessage: string;
begin
  Result := GetDCUConfirmProcess;
end;

function TTranslationPTBR.GetStatusReady: string;
begin
  Result := 'Pronto';
end;

function TTranslationPTBR.GetStatusPreparing: string;
begin
  Result := 'Preparando...';
end;

function TTranslationPTBR.GetStatusProcessing(const Current, Total: Integer): string;
begin
  Result := Format('%d/%d Processando...', [Current, Total]);
end;

function TTranslationPTBR.GetStatusFilesProcessed(const Current, Total: Integer): string;
begin
  Result := Format('%d/%d Arquivos processados...', [Current, Total]);
end;

function TTranslationPTBR.GetErrorRefreshLibraryPath(const Msg: string): string;
begin
  Result := 'Erro ao atualizar Library Path: ' + Msg;
end;

function TTranslationPTBR.GetErrorRefreshProject(const Msg: string): string;
begin
  Result := 'Erro ao atualizar projeto: ' + Msg;
end;

function TTranslationPTBR.GetSettingsTitle: string;
begin
  Result := 'Configurações';
end;

function TTranslationPTBR.GetSettingsGeneral: string;
begin
  Result := 'Geral';
end;

function TTranslationPTBR.GetSettingsShortcuts: string;
begin
  Result := 'Atalhos';
end;

function TTranslationPTBR.GetSettingsAutoImport: string;
begin
  Result := 'Importação Automática';
end;

function TTranslationPTBR.GetSettingsUnusedUses: string;
begin
  Result := 'Uses não utilizados';
end;

function TTranslationPTBR.GetSettingsLanguage: string;
begin
  Result := 'Idioma';
end;

function TTranslationPTBR.GetSettingsEnabled: string;
begin
  Result := 'Habilitado';
end;

function TTranslationPTBR.GetSettingsOpenConfigFile: string;
begin
  Result := 'Abrir arquivo de configurações';
end;

function TTranslationPTBR.GetSettingsAlwaysInterface: string;
begin
  Result := 'Sempre importar para a seção de interface';
end;

function TTranslationPTBR.GetSettingsSortByLevel: string;
begin
  Result := 'Classificar uses por nível (RTL > VCL > Third-party)';
end;

function TTranslationPTBR.GetSettingsSortByLevelHint: string;
begin
  Result := 'Classifique por nível: RTL, VCL, Third-party, Projeto';
end;

function TTranslationPTBR.GetSettingsSortAlphabetic: string;
begin
  Result := 'Classificar Uses por ordem alfabética';
end;

function TTranslationPTBR.GetSettingsBreakLine: string;
begin
  Result := 'Quebre a linha a cada nova entrada Uses';
end;

function TTranslationPTBR.GetSettingsBlankLineNamespace: string;
begin
  Result := 'Linha em branco entre namespaces';
end;

function TTranslationPTBR.GetSettingsBlankLineNamespaceHint: string;
begin
  Result := 'Classifique e quebre linha devem estar marcados para usar esta opção';
end;

function TTranslationPTBR.GetSettingsOrganizeAfterInsert: string;
begin
  Result := 'Organize os Uses após inserir uma nova unit no Uses';
end;

function TTranslationPTBR.GetSettingsGroupNonNamespace: string;
begin
  Result := 'Agrupar units sem namespace';
end;

function TTranslationPTBR.GetSettingsGroupNonNamespaceHint: string;
begin
  Result := 'Classifique e quebre linha devem estar marcados para usar esta opção';
end;

function TTranslationPTBR.GetSettingsDontBreakNonNamespace: string;
begin
  Result := 'Não quebre a linha para units sem namespace';
end;

function TTranslationPTBR.GetSettingsDontBreakNonNamespaceHint: string;
begin
  Result := 'Classifique e quebre linha devem estar marcados para usar esta opção';
end;

function TTranslationPTBR.GetSettingsBreakLineAt: string;
begin
  Result := 'Quebra de linha na posição';
end;

function TTranslationPTBR.GetSettingsSortHint: string;
begin
  Result := 'Organização das Uses';
end;

function TTranslationPTBR.GetSettingsCreateProjectConfig: string;
begin
  Result := 'Criar configuração para este projeto';
end;

function TTranslationPTBR.GetSettingsExperimentalUnused: string;
begin
  Result := 'Ativar recurso experimental: encontre uses não utilizados';
end;

function TTranslationPTBR.GetSettingsEnableHighlight: string;
begin
  Result := 'Habilitar destaque de units não utilizadas (underline no código)';
end;

function TTranslationPTBR.GetSettingsUnderlineMeaning: string;
begin
  Result := 'Significado das cores do sublinhado:';
end;

function TTranslationPTBR.GetSettingsImportNotUsed: string;
begin
  Result := 'Importação não utilizada';
end;

function TTranslationPTBR.GetSettingsDCUNoAccess: string;
begin
  Result := 'Sem acesso ao pas, provavelmente é um arquivo dcu que'
      + #10'foi adicionado no caminho da biblioteca.'
      + #10'Para corrigi-lo, clique no botão'
      + #10'"Processar arquivos DCUs do caminho da biblioteca"'
      + #10'Na tela de pesquisa';
end;

function TTranslationPTBR.GetSettingsDCPDistributed: string;
begin
  Result := 'Unit distribuída apenas via .dcp da IDE (ex: DockForm, DeskUtil)';
end;

function TTranslationPTBR.GetSettingsMatchAlgorithm: string;
begin
  Result := 'Algoritmo de busca por correspondência';
end;

function TTranslationPTBR.GetSettingsRememberChoices: string;
begin
  Result := 'Armazene opções para usar na importação automática (Ctrl + Shift + I)';
end;

function TTranslationPTBR.GetSettingsOrganizeUses: string;
begin
  Result := 'Organizar uses (Ctrl + Shift + U)';
end;

function TTranslationPTBR.GetFormSearchTitle: string;
begin
  Result := 'Pesquisar Units';
end;

function TTranslationPTBR.GetFormSearchOptions: string;
begin
  Result := 'Opções';
end;

function TTranslationPTBR.GetFormSearchResult: string;
begin
  Result := 'Resultado';
end;

function TTranslationPTBR.GetFormSearchSearch: string;
begin
  Result := 'Pesquisar';
end;

function TTranslationPTBR.GetFormSearchAddTo: string;
begin
  Result := 'Adicionar à:';
end;

function TTranslationPTBR.GetFormSearchInterface: string;
begin
  Result := '&Interface';
end;

function TTranslationPTBR.GetFormSearchImplementation: string;
begin
  Result := 'Im&plementation';
end;

function TTranslationPTBR.GetFormSearchAdd: string;
begin
  Result := '&Adicionar';
end;

function TTranslationPTBR.GetFormSearchSearchHint: string;
begin
  Result := 'Digite sua pesquisa...';
end;

function TTranslationPTBR.GetFormSearchRefresh: string;
begin
  Result := '&Atualizar';
end;

function TTranslationPTBR.GetFormSearchProcessDCU: string;
begin
  Result := 'Processar arquivos DCUs do Library Path';
end;

function TTranslationPTBR.GetFormSearchDCUWarning: string;
begin
  Result := '<-- É altamente recomendável executar este processo';
end;

function TTranslationPTBR.GetFormSearchSearchLibraryPath: string;
begin
  Result := 'Procurar nas Units do Library Path';
end;

function TTranslationPTBR.GetFormSearchSearchProject: string;
begin
  Result := 'Pesquisar nas Units do Projeto';
end;

function TTranslationPTBR.GetFormSearchConfigure: string;
begin
  Result := 'Configurações';
end;

function TTranslationPTBR.GetFormSearchTooManyResults: string;
begin
  Result := 'Existem muitos resultados em sua pesquisa, não estou mostrando tudo. Digite uma busca maior.';
end;

function TTranslationPTBR.GetFormSearchTooManyResultsHint: string;
begin
  Result := 'Lembre-se que você pode criar buscas incrementais como: "string replace", ou procurar os argumentos separadamente.';
end;

function TTranslationPTBR.GetMenuTitle: string;
begin
  Result := 'RFindUnit';
end;

function TTranslationPTBR.GetMenuForceRegister: string;
begin
  Result := 'Forçar registro de atalhos';
end;

function TTranslationPTBR.GetAutoImportNoUnitsToImport: string;
begin
  Result := 'Não há uses disponíveis para importação.';
end;

{ TTranslationEN }

function TTranslationEN.GetName: string;
begin
  Result := 'English';
end;

function TTranslationEN.GetUnusedUsesIndexing: string;
begin
  Result := 'Project indexing still in progress. Please wait a few seconds and try again.';
end;

function TTranslationEN.GetUnusedUsesAnalyzing: string;
begin
  Result := 'Analyzing unused units...';
end;

function TTranslationEN.GetUnusedUsesAllUsed: string;
begin
  Result := 'All units are being used.';
end;

function TTranslationEN.GetUnusedUsesUnused(const Units: string): string;
begin
  Result := 'Unused units: ' + Units;
end;

function TTranslationEN.GetUnusedUsesError(const Msg: string): string;
begin
  Result := 'Error analyzing units: ' + Msg;
end;

function TTranslationEN.GetUnusedUsesNotIndexed: string;
begin
  Result := 'The current file is not part of the indexed project or library. Open the correct project (or wait for indexing to finish) and try again.';
end;

function TTranslationEN.GetOrganizeUsesDone: string;
begin
  Result := 'Uses organized.';
end;

function TTranslationEN.GetOrganizeUsesWarning: string;
begin
  Result := 'If Uses contain comments or IFDEF, they will not be organized.';
end;

function TTranslationEN.GetUnitAddedToInterface(const UnitName: string): string;
begin
  Result := 'Unit ' + UnitName + ' added to interface uses.';
end;

function TTranslationEN.GetUnitAddedToImplementation(const UnitName: string): string;
begin
  Result := 'Unit ' + UnitName + ' added to implementation uses.';
end;

function TTranslationEN.GetDCUConfirmProcess: string;
begin
  Result := 'This command will list all DCU/PAS files you do not have access to '
      + 'and process them to make them available for search. '
      + 'This process will slow down your computer and may take a few minutes (~2). '
      + 'Are you sure you want to run it now?';
end;

function TTranslationEN.GetDCUConfirmMessage: string;
begin
  Result := GetDCUConfirmProcess;
end;

function TTranslationEN.GetStatusReady: string;
begin
  Result := 'Ready';
end;

function TTranslationEN.GetStatusPreparing: string;
begin
  Result := 'Preparing...';
end;

function TTranslationEN.GetStatusProcessing(const Current, Total: Integer): string;
begin
  Result := Format('%d/%d Processing...', [Current, Total]);
end;

function TTranslationEN.GetStatusFilesProcessed(const Current, Total: Integer): string;
begin
  Result := Format('%d/%d Files processed...', [Current, Total]);
end;

function TTranslationEN.GetErrorRefreshLibraryPath(const Msg: string): string;
begin
  Result := 'Error refreshing Library Path: ' + Msg;
end;

function TTranslationEN.GetErrorRefreshProject(const Msg: string): string;
begin
  Result := 'Error refreshing project: ' + Msg;
end;

function TTranslationEN.GetSettingsTitle: string;
begin
  Result := 'Settings';
end;

function TTranslationEN.GetSettingsGeneral: string;
begin
  Result := 'General';
end;

function TTranslationEN.GetSettingsShortcuts: string;
begin
  Result := 'Shortcuts';
end;

function TTranslationEN.GetSettingsAutoImport: string;
begin
  Result := 'Auto Import';
end;

function TTranslationEN.GetSettingsUnusedUses: string;
begin
  Result := 'Unused Uses';
end;

function TTranslationEN.GetSettingsLanguage: string;
begin
  Result := 'Language';
end;

function TTranslationEN.GetSettingsEnabled: string;
begin
  Result := 'Enabled';
end;

function TTranslationEN.GetSettingsOpenConfigFile: string;
begin
  Result := 'Open configuration file';
end;

function TTranslationEN.GetSettingsAlwaysInterface: string;
begin
  Result := 'Always import to interface section';
end;

function TTranslationEN.GetSettingsSortByLevel: string;
begin
  Result := 'Sort uses by level (RTL > VCL > Third-party)';
end;

function TTranslationEN.GetSettingsSortByLevelHint: string;
begin
  Result := 'Sort by level: RTL, VCL, Third-party, Project';
end;

function TTranslationEN.GetSettingsSortAlphabetic: string;
begin
  Result := 'Sort uses alphabetically';
end;

function TTranslationEN.GetSettingsBreakLine: string;
begin
  Result := 'Break line at each new Uses entry';
end;

function TTranslationEN.GetSettingsBlankLineNamespace: string;
begin
  Result := 'Blank line between namespaces';
end;

function TTranslationEN.GetSettingsBlankLineNamespaceHint: string;
begin
  Result := 'Sort and Break line should be checked in order to use this option';
end;

function TTranslationEN.GetSettingsOrganizeAfterInsert: string;
begin
  Result := 'Organize Uses after inserting a new unit';
end;

function TTranslationEN.GetSettingsGroupNonNamespace: string;
begin
  Result := 'Group units without namespace';
end;

function TTranslationEN.GetSettingsGroupNonNamespaceHint: string;
begin
  Result := 'Sort and Break line should be checked in order to use this option';
end;

function TTranslationEN.GetSettingsDontBreakNonNamespace: string;
begin
  Result := 'Do not break line for units without namespace';
end;

function TTranslationEN.GetSettingsDontBreakNonNamespaceHint: string;
begin
  Result := 'Sort and Break line should be checked in order to use this option';
end;

function TTranslationEN.GetSettingsBreakLineAt: string;
begin
  Result := 'Break line at position';
end;

function TTranslationEN.GetSettingsSortHint: string;
begin
  Result := 'Uses Organization';
end;

function TTranslationEN.GetSettingsCreateProjectConfig: string;
begin
  Result := 'Create configuration for this project';
end;

function TTranslationEN.GetSettingsExperimentalUnused: string;
begin
  Result := 'Enable experimental feature: find unused uses';
end;

function TTranslationEN.GetSettingsEnableHighlight: string;
begin
  Result := 'Enable unused units highlight (underline in code)';
end;

function TTranslationEN.GetSettingsUnderlineMeaning: string;
begin
  Result := 'Underline color meaning:';
end;

function TTranslationEN.GetSettingsImportNotUsed: string;
begin
  Result := 'Unused import';
end;

function TTranslationEN.GetSettingsDCUNoAccess: string;
begin
  Result := 'No access to pas, probably a dcu file that'
      + #10'was added to the library path.'
      + #10'To fix it, click the button'
      + #10'"Process DCU files from library path"'
      + #10'On the search screen';
end;

function TTranslationEN.GetSettingsDCPDistributed: string;
begin
  Result := 'Unit distributed only via IDE .dcp (e.g.: DockForm, DeskUtil)';
end;

function TTranslationEN.GetSettingsMatchAlgorithm: string;
begin
  Result := 'Match search algorithm';
end;

function TTranslationEN.GetSettingsRememberChoices: string;
begin
  Result := 'Remember choices for auto import (Ctrl + Shift + I)';
end;

function TTranslationEN.GetSettingsOrganizeUses: string;
begin
  Result := 'Organize uses (Ctrl + Shift + U)';
end;

function TTranslationEN.GetFormSearchTitle: string;
begin
  Result := 'Find Units';
end;

function TTranslationEN.GetFormSearchOptions: string;
begin
  Result := 'Options';
end;

function TTranslationEN.GetFormSearchResult: string;
begin
  Result := 'Result';
end;

function TTranslationEN.GetFormSearchSearch: string;
begin
  Result := 'Search';
end;

function TTranslationEN.GetFormSearchAddTo: string;
begin
  Result := 'Add to:';
end;

function TTranslationEN.GetFormSearchInterface: string;
begin
  Result := '&Interface';
end;

function TTranslationEN.GetFormSearchImplementation: string;
begin
  Result := 'Im&plementation';
end;

function TTranslationEN.GetFormSearchAdd: string;
begin
  Result := '&Add';
end;

function TTranslationEN.GetFormSearchSearchHint: string;
begin
  Result := 'Type your search...';
end;

function TTranslationEN.GetFormSearchRefresh: string;
begin
  Result := '&Refresh';
end;

function TTranslationEN.GetFormSearchProcessDCU: string;
begin
  Result := 'Process DCU files from Library Path';
end;

function TTranslationEN.GetFormSearchDCUWarning: string;
begin
  Result := '<-- It is highly recommended to run this process';
end;

function TTranslationEN.GetFormSearchSearchLibraryPath: string;
begin
  Result := 'Search Library Path units';
end;

function TTranslationEN.GetFormSearchSearchProject: string;
begin
  Result := 'Search Project units';
end;

function TTranslationEN.GetFormSearchConfigure: string;
begin
  Result := 'Settings';
end;

function TTranslationEN.GetFormSearchTooManyResults: string;
begin
  Result := 'There are too many results, not showing everything. Type a bigger search.';
end;

function TTranslationEN.GetFormSearchTooManyResultsHint: string;
begin
  Result := 'Remember you can create incremental searches like: "string replace", or search for arguments separately.';
end;

function TTranslationEN.GetMenuTitle: string;
begin
  Result := 'RFindUnit';
end;

function TTranslationEN.GetMenuForceRegister: string;
begin
  Result := 'Force register shortcuts';
end;

function TTranslationEN.GetAutoImportNoUnitsToImport: string;
begin
  Result := 'No uses available for auto-importation.';
end;

initialization

finalization
  FCurrentTranslation := nil;

end.
