unit HDFindUnit.Model.Interf.Translation;

interface

type
  IRFUTranslation = interface
    ['{B7E3A1F2-4C8D-4E5A-9F6B-2D1A3C5E7F90}']

    function GetName: string;

    function GetUnusedUsesIndexing: string;
    function GetUnusedUsesAnalyzing: string;
    function GetUnusedUsesAllUsed: string;
    function GetUnusedUsesUnused(const Units: string): string;
    function GetUnusedUsesError(const Msg: string): string;
    function GetUnusedUsesNotIndexed: string;

    function GetOrganizeUsesDone: string;
    function GetOrganizeUsesWarning: string;

    function GetUnitAddedToInterface(const UnitName: string): string;
    function GetUnitAddedToImplementation(const UnitName: string): string;

    function GetDCUConfirmProcess: string;
    function GetDCUConfirmMessage: string;

    function GetStatusReady: string;
    function GetStatusPreparing: string;
    function GetStatusProcessing(const Current, Total: Integer): string;
    function GetStatusFilesProcessed(const Current, Total: Integer): string;

    function GetErrorRefreshLibraryPath(const Msg: string): string;
    function GetErrorRefreshProject(const Msg: string): string;

    function GetSettingsTitle: string;
    function GetSettingsGeneral: string;
    function GetSettingsShortcuts: string;
    function GetSettingsAutoImport: string;
    function GetSettingsUnusedUses: string;
    function GetSettingsLanguage: string;
    function GetSettingsEnabled: string;
    function GetSettingsOpenConfigFile: string;
    function GetSettingsAlwaysInterface: string;
    function GetSettingsSortByLevel: string;
    function GetSettingsSortByLevelHint: string;
    function GetSettingsSortAlphabetic: string;
    function GetSettingsBreakLine: string;
    function GetSettingsBlankLineNamespace: string;
    function GetSettingsBlankLineNamespaceHint: string;
    function GetSettingsOrganizeAfterInsert: string;
    function GetSettingsGroupNonNamespace: string;
    function GetSettingsGroupNonNamespaceHint: string;
    function GetSettingsDontBreakNonNamespace: string;
    function GetSettingsDontBreakNonNamespaceHint: string;
    function GetSettingsBreakLineAt: string;
    function GetSettingsSortHint: string;
    function GetSettingsCreateProjectConfig: string;
    function GetSettingsExperimentalUnused: string;
    function GetSettingsEnableHighlight: string;
    function GetSettingsUnderlineMeaning: string;
    function GetSettingsImportNotUsed: string;
    function GetSettingsDCUNoAccess: string;
    function GetSettingsDCPDistributed: string;
    function GetSettingsMatchAlgorithm: string;
    function GetSettingsRememberChoices: string;
    function GetSettingsOrganizeUses: string;

    function GetFormSearchTitle: string;
    function GetFormSearchOptions: string;
    function GetFormSearchResult: string;
    function GetFormSearchSearch: string;
    function GetFormSearchAddTo: string;
    function GetFormSearchInterface: string;
    function GetFormSearchImplementation: string;
    function GetFormSearchAdd: string;
    function GetFormSearchSearchHint: string;
    function GetFormSearchRefresh: string;
    function GetFormSearchProcessDCU: string;
    function GetFormSearchDCUWarning: string;
    function GetFormSearchSearchLibraryPath: string;
    function GetFormSearchSearchProject: string;
    function GetFormSearchConfigure: string;
    function GetFormSearchTooManyResults: string;
    function GetFormSearchTooManyResultsHint: string;

    function GetAutoImportNoUnitsToImport: string;

    function GetMenuTitle: string;
    function GetMenuForceRegister: string;
  end;

implementation

end.
