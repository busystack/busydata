// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Estonian (`et`).
class AppLocalizationsEt extends AppLocalizations {
  AppLocalizationsEt([String locale = 'et']) : super(locale);

  @override
  String get cancel => 'Tühista';

  @override
  String get windowMinimize => 'Minimeeri';

  @override
  String get windowMaximize => 'Maksimeeri';

  @override
  String get windowRestore => 'Taasta';

  @override
  String get databaseExplorer => 'Andmebaasi sirvija';

  @override
  String get databases => 'Andmebaasid';

  @override
  String get newConnection => 'Uus ühendus';

  @override
  String get filterTree => 'Filtreeri ühendusi ja objekte';

  @override
  String get treeFilterScope => 'Filtreerib laaditud puuobjekte';

  @override
  String get searchObjects => 'Otsi andmebaasi objekte';

  @override
  String get fileMenu => 'Fail';

  @override
  String get editMenu => 'Muuda';

  @override
  String get viewMenu => 'Vaade';

  @override
  String get connectionMenu => 'Ühendus';

  @override
  String get objectMenu => 'Objekt';

  @override
  String get runMenu => 'Käivitamise valikud';

  @override
  String get commands => 'Käsud';

  @override
  String get findCommand => 'Otsi käsku';

  @override
  String get newSql => 'Uus päring';

  @override
  String get openSql => 'Ava SQL';

  @override
  String get openSqlFile => 'Ava SQL-fail';

  @override
  String get saveSql => 'Salvesta SQL';

  @override
  String get closeTab => 'Sulge vahekaart';

  @override
  String get openWorkspace => 'Ava tööruum';

  @override
  String get saveWorkspace => 'Salvesta tööruum';

  @override
  String get settings => 'Seaded';

  @override
  String get findText => 'Otsi';

  @override
  String get replaceText => 'Asenda';

  @override
  String get formatSql => 'Vorminda SQL';

  @override
  String get lineComments => 'Lülita reakommendid';

  @override
  String get snippets => 'SQL-lõigud';

  @override
  String get run => 'Käivita';

  @override
  String get runStatement => 'Käivita praegune lause';

  @override
  String get runSelection => 'Käivita valik';

  @override
  String get runScript => 'Käivita skript';

  @override
  String get explain => 'Selgita plaani';

  @override
  String get explainAnalyze => 'Selgita ja analüüsi';

  @override
  String get connect => 'Ühenda';

  @override
  String get disconnect => 'Katkesta ühendus';

  @override
  String get sessionDetails => 'Seansi üksikasjad';

  @override
  String get beginTransaction => 'Alusta tehingut';

  @override
  String get commitTransaction => 'Kinnita tehing';

  @override
  String get rollbackTransaction => 'Võta tehing tagasi';

  @override
  String get enableAutoCommit => 'Luba automaatne kinnitamine';

  @override
  String get disableAutoCommit => 'Keela automaatne kinnitamine';

  @override
  String get outcomeUnknown => 'Tulemus teadmata';

  @override
  String get outcomeUnknownNote =>
      'Toiming võis lõpule jõuda. See seanss ei saa rohkem SQL-i käivitada. Ärge proovige automaatselt uuesti; selgitage tulemus välja enne uue töö alustamist.';

  @override
  String get notConnected => 'Ühendamata';

  @override
  String get autoCommit => 'Automaatne kinnitamine';

  @override
  String get manualTransaction => 'Käsitsi tehing';

  @override
  String get readOnlyPolicy => 'BusyData kirjutuskaitse reegel';

  @override
  String get data => 'Andmed';

  @override
  String get structure => 'Struktuur';

  @override
  String get results => 'Tulemused';

  @override
  String get messages => 'Teated';

  @override
  String get plan => 'Plaan';

  @override
  String get changes => 'Muudatused';

  @override
  String get history => 'Ajalugu';

  @override
  String get jobs => 'Tööd';

  @override
  String get retainedResults => 'Säilitatud tulemused';

  @override
  String get recoverEdits => 'Taasta ettevalmistatud muudatused';

  @override
  String get applyAndCommit => 'Rakenda ja kinnita';

  @override
  String get inspectStructure => 'Uuri struktuuri';

  @override
  String get openData => 'Ava andmed';

  @override
  String get openDefinition => 'Ava definitsioon';

  @override
  String get copyQualifiedName => 'Kopeeri täielik nimi';

  @override
  String get refresh => 'Värskenda';

  @override
  String get columns => 'Veerud';

  @override
  String get indexes => 'Indeksid';

  @override
  String get constraints => 'Võtmed ja kitsendused';

  @override
  String get foreignKeys => 'Välisvõtmed';

  @override
  String get triggers => 'Päästikud';

  @override
  String get definition => 'Definitsioon';

  @override
  String get dependencies => 'Sõltuvused';

  @override
  String get connectionCapabilities => 'Ühenduse ülevaade';

  @override
  String get sessionsAndLocks => 'Seansid ja lukud';

  @override
  String get usersAndRoles => 'Kasutajad ja rollid';

  @override
  String get saveSnapshot => 'Salvesta skeemi hetktõmmis';

  @override
  String get compareSchemas => 'Võrdle skeeme';

  @override
  String get objectDesigner => 'Objekti kujundaja';

  @override
  String get diagram => 'ER-diagramm';

  @override
  String get backup => 'Varundamine';

  @override
  String get restore => 'Taastamine';

  @override
  String get importData => 'Impordi andmed';

  @override
  String get exportRetained => 'Ekspordi säilitatud andmed';

  @override
  String get exportSql => 'Käivita SQL-eksport';

  @override
  String get stageInsert => 'Lisa rida';

  @override
  String get stageUpdate => 'Muuda rida';

  @override
  String get stageDelete => 'Kustuta rida';

  @override
  String get discardChanges => 'Hülga ootel muudatused';

  @override
  String get disposeResult => 'Vabasta säilitatud andmed';

  @override
  String get currentSchema => 'Praegune skeem (muudetav)';

  @override
  String get desiredSchema => 'Soovitud skeem';

  @override
  String get applyTo => 'Rakenda sihtmärgile';

  @override
  String get loading => 'Laadimine';

  @override
  String get empty => 'Selles ulatuses pole objekte';

  @override
  String get more => 'Veel';

  @override
  String get filter => 'Filtreeri';

  @override
  String get sort => 'Sordi';

  @override
  String get selectTarget => 'Vali ühendus';

  @override
  String get requireSql => 'Vajab SQL-dokumenti';

  @override
  String get requireSession => 'Vajab ühendatud seanssi, mille olek on teada';

  @override
  String get requireResult => 'Vajab säilitatud andmeid';

  @override
  String get requireObject => 'Vajab objekti sihtmärki';

  @override
  String get cancelRequested => 'Tühistamist taotletud';

  @override
  String get cancelled => 'Tühistatud';

  @override
  String get queued => 'Järjekorras';

  @override
  String get running => 'Töötab';

  @override
  String get completed => 'Lõpetatud';

  @override
  String get failed => 'Nurjus';

  @override
  String get partial => 'Osaline';

  @override
  String get sessionSharing => 'Jaga olemasolevat seanssi (täpsem)';

  @override
  String get production => 'Tootmine';

  @override
  String get staging => 'Eeltootmine';

  @override
  String get development => 'Arendus';

  @override
  String get executionOptions => 'Käivitamise seaded';

  @override
  String get resultRowLimit => 'Tulemuse ridade piir (1–1000000)';

  @override
  String get boundedRead => 'Piiratud lugemine';

  @override
  String get streamingRead => 'Vooglugemine · omab lugemistehingut';

  @override
  String get stopOnError => 'Peata skript vea korral';

  @override
  String get continueOnError =>
      'Jätka vea korral · varasemad laused võivad olla kinnitatud';

  @override
  String get loadMore => 'Laadi rohkem';

  @override
  String get favorite => 'Lülita lemmiku olek';

  @override
  String get connectionGroup => 'Ühenduste rühm';

  @override
  String get copyRange => 'Kopeeri vahemik';

  @override
  String get inspectValue => 'Uuri väärtust';

  @override
  String get editConnection => 'Muuda ühendust';

  @override
  String get chooseSnapshot => 'Vali hetktõmmis';

  @override
  String get captureSchema => 'Jäädvusta skeem';

  @override
  String get sameSchemaRestriction =>
      'Hetktõmmistel peab olema sama andmebaasimootor, skeemi nimi ja hetktõmmise versioon. Võrdlemine ja salvestamine ei rakenda kunagi muudatusi.';

  @override
  String get restoredTaskState =>
      'Selle dokumendi viide taastati. Varasemad serveri tõendid, seansid ja tööd pole saadaval. Vali uurimiseks või uue töö alustamiseks eraldi toiming; taastamine ei ühenda kunagi, ei käivita SQL-i ega korda muudatusi.';

  @override
  String get preChangeSnapshot =>
      'Muudatuseelne hetktõmmis · muudatused kinnitatud. Praeguste ridade ja serveri vaikeväärtuste vaatamiseks värskenda eraldi.';

  @override
  String get sqlProvenance => 'SQL-i päritolu';

  @override
  String get assessEditing => 'Hinda muutmisvõimalust';

  @override
  String get viewDetails => 'Vaata üksikasju';

  @override
  String get gridMenu => 'Andmeruudustik';

  @override
  String get visibleColumns => 'Nähtavad veerud';

  @override
  String get hidden => 'Peidetud';

  @override
  String get ascending => 'Kasvav';

  @override
  String get descending => 'Kahanev';

  @override
  String get equals => 'Võrdub';

  @override
  String get notEqual => 'Ei võrdu';

  @override
  String get lessThan => 'Väiksem kui';

  @override
  String get greaterThan => 'Suurem kui';

  @override
  String get isNull => 'On NULL';

  @override
  String get isNotNull => 'Ei ole NULL';

  @override
  String get exactValue => 'Täpne väärtus';

  @override
  String get sortTable => 'Sordi tabeli andmeid';

  @override
  String get filterTable => 'Filtreeri tabeli andmeid';

  @override
  String get sortRetained => 'Sordi säilitatud hetktõmmist';

  @override
  String get filterRetained => 'Filtreeri säilitatud hetktõmmist';

  @override
  String get applyView => 'Rakenda';

  @override
  String get rowsLabel => 'Read';

  @override
  String get fetchedRows => 'Laaditud read';

  @override
  String get fixedSnapshot => 'Laaditud ridade fikseeritud hetktõmmis';

  @override
  String get limitReached => 'Piir saavutatud';

  @override
  String get retainedData => 'Säilitatud andmed';

  @override
  String get applyRequiresAutoCommit =>
      'Rakendamine ja kinnitamine vajab jõude seanssi lubatud automaatse kinnitamisega.';

  @override
  String get connectionProfile => 'Ühendusprofiil';

  @override
  String get basic => 'Põhiline';

  @override
  String get advanced => 'Täpsem';

  @override
  String get connectionName => 'Nimi';

  @override
  String get hostname => 'Hostinimi (ka TLS-i kontrolliks)';

  @override
  String get port => 'Port';

  @override
  String get database => 'Andmebaas';

  @override
  String get user => 'Kasutaja';

  @override
  String get password => 'Parool';

  @override
  String get writableProfile => 'Kirjutatav profiil';

  @override
  String get readonlyProfile => 'Kirjutuskaitstud profiil';

  @override
  String get tlsVerify => 'TLS: kontrolli sertifikaati ja hostinime';

  @override
  String get tlsInsecure => 'TLS: EBATURVALINE, kontrollita';

  @override
  String get tlsDisabled => 'TLS: KEELATUD';

  @override
  String get testConnection => 'Testi salvestamata';

  @override
  String get saveProfile => 'Salvesta';

  @override
  String get saveConnect => 'Salvesta ja ühenda';

  @override
  String get sessionPassword => 'Parool ainult selleks seansiks';

  @override
  String get storedPassword => 'Salvesta parool süsteemi turvalisse hoidlasse';

  @override
  String get chooseFile => 'Vali fail';

  @override
  String get testRunning => 'Ühenduse testimine…';

  @override
  String get cancelTest => 'Tühista test';

  @override
  String get idle => 'Jõude';

  @override
  String get activeTransaction => 'Tehing avatud';

  @override
  String get failedTransaction => 'Tehing nurjus';

  @override
  String get inspectionContext => 'Ülevaatuse seanss';

  @override
  String get requireTableOrView => 'Vali tabel või vaade';

  @override
  String get operationPending => 'Dokumendi toiming ootab kinnitust';

  @override
  String get requirePlan => 'Vali säilitatud Explain-käivitus';

  @override
  String get openPlanDocument => 'Ava plaani dokument';

  @override
  String get locks => 'Lukud';

  @override
  String get statistics => 'Statistika';

  @override
  String get queryStatistics => 'Päringustatistika';

  @override
  String get indexDiagnostics => 'Indeksite diagnostika';

  @override
  String get grants => 'Antud õigused';

  @override
  String get sqlExecution => 'SQL-i käivitus';

  @override
  String get planReady =>
      'Säilitatud plaan on valmis; SQL-i ei käivitatud uuesti';

  @override
  String get executionPlan => 'Käivitusplaan';

  @override
  String get openOwner => 'Ava omanik';

  @override
  String get terminateActivity => 'Lõpeta tegevus';

  @override
  String get close => 'Sulge';

  @override
  String get previous => 'Eelmine';

  @override
  String get next => 'Järgmine';

  @override
  String get replaceSelection => 'Asenda valik';

  @override
  String get replaceAll => 'Asenda kõik';

  @override
  String get restartBackend => 'Taaskäivita taustaprotsess';

  @override
  String get structuredTree => 'Struktureeritud puu';

  @override
  String get rawOutput => 'Töötlemata väljund';

  @override
  String get previousTextPage => 'Eelmine tekstileht';

  @override
  String get nextTextPage => 'Järgmine tekstileht';

  @override
  String get filterChangedObjects => 'Filtreeri muudetud objekte';

  @override
  String get rebindVerifiedEdits => 'Seo kontrollitud muudatused uuesti';

  @override
  String get discardRecoveryRecord => 'Loobu taastekirjest';

  @override
  String get revertChange => 'Võta ootel muudatus tagasi';

  @override
  String get chooseSource => 'Vali allikas';

  @override
  String get chooseDestination => 'Vali sihtkoht';

  @override
  String get delimiterField => 'Eraldaja (üks märk)';

  @override
  String get batchRowsField => 'Ridu partiis (1–1000)';

  @override
  String get rejectedLimit => 'Tagasilükatud ridade piir (1–1000)';

  @override
  String get previewSource => 'Allika eelvaade';

  @override
  String get reviewTransfer => 'Vaata edastus üle';

  @override
  String get startImport => 'Alusta importi';

  @override
  String get startRestore => 'Alusta taastamist';

  @override
  String get startExport => 'Alusta eksporti';

  @override
  String get requestCancel => 'Taotle tühistamist';

  @override
  String get sourceMapping => 'Allika ja sihtkoha vastendus';

  @override
  String get nativeTool => 'Süsteemne tööriist';

  @override
  String get defaultOmit => 'Jäta välja / andmebaasi vaikeväärtus';

  @override
  String get overwriteNever => 'Ära kirjuta üle';

  @override
  String get overwriteExisting => 'Kirjuta olemasolev fail üle';

  @override
  String get planDetails => 'Plaani üksikasjad';

  @override
  String get planMetricsNote =>
      'Hinnangud ja tegelikud mõõtmised kasutavad serveri väljanimesid. Puuduvad mõõtmised pole saadaval.';

  @override
  String get connected => 'Ühendatud';

  @override
  String get disconnected => 'Ühendamata';

  @override
  String get tables => 'Tabelid';

  @override
  String get views => 'Vaated';

  @override
  String get routines => 'Rutiinid';

  @override
  String get expand => 'Laienda';

  @override
  String get collapse => 'Ahenda';

  @override
  String get databaseWorkbench => 'Andmebaasi töölaud';

  @override
  String get sidebar => 'Külgpaneel';

  @override
  String get unchanged => 'Muutmata';

  @override
  String get reviewDetails => 'Ülevaatuse üksikasjad';

  @override
  String get generatedSql => 'Loodud SQL';

  @override
  String get changeReverted =>
      'Ootel muudatus tühistatud. Taotle uut ülevaatust.';

  @override
  String get unknownBatch =>
      'Tulemus teadmata. Pakett võib olla kinnitatud. Ära seda automaatselt korda; kontrolli seanssi ja taastekirjet.';

  @override
  String get expiredChangeReview =>
      'Siht muutus või ülevaatus aegus. Taotle uut ülevaatust.';

  @override
  String get applyCommitExplanation =>
      'Rakenda ja kinnita alustab ning kinnitab oma tehingu. Lähtekonsool peab olema jõude ja automaatne kinnitamine lubatud. Lahenda käsitsi SQL-tehingud eraldi.';

  @override
  String get newRow => 'Uus rida';

  @override
  String get original => 'Algne';

  @override
  String get proposed => 'Pakutud';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '$inserts lisamist · $updates uuendust · $deletes kustutamist';
  }

  @override
  String sourceRow(String row) {
    return 'Lähterida $row';
  }

  @override
  String get refreshing => 'Värskendamine…';

  @override
  String get refreshActivities => 'Värskenda tegevusi';

  @override
  String get explicitRefresh => 'Selgesõnaline värskendamine';

  @override
  String get pollFiveSeconds => 'Küsi iga 5 sekundi järel';

  @override
  String get cancelSelectedActivity => 'Tühista valitud tegevus';

  @override
  String get terminateSelectedSession => 'Lõpeta valitud seanss';

  @override
  String get filterActivities => 'Filtreeri praeguseid tegevusi';

  @override
  String get blockedBy => 'Blokeerib:';

  @override
  String get delete => 'Kustuta';

  @override
  String get remove => 'Eemalda';

  @override
  String get up => 'Üles';

  @override
  String get search => 'Otsi';

  @override
  String get yes => 'Jah';

  @override
  String get no => 'Ei';

  @override
  String get clear => 'Tühjenda';

  @override
  String get copy => 'Kopeeri';

  @override
  String get insert => 'Lisa';

  @override
  String get update => 'Uuenda';

  @override
  String get open => 'Ava';

  @override
  String get migrationEngineMismatch =>
      'Sihtühendus peab kasutama võrreldud hetktõmmistega sama mootorit. Mootoritevahelist migratsiooni ei toetata.';

  @override
  String get metadataContextChanged =>
      'Kontrolli kontekst on muutunud. Värskendage metaandmeid selgesõnaliselt.';

  @override
  String get newTableName => 'Uue tabeli nimi';

  @override
  String get routineIdentity => 'Rutiini täpne identiteet';

  @override
  String get objectColumnName => 'Objekti / veeru nimi';

  @override
  String get builtInType => 'Sisseehitatud tüüp';

  @override
  String get sqlExpression => 'SQL-avaldis (tühi eemaldab selle)';

  @override
  String get newPropertyValue => 'Omaduse uus väärtus';

  @override
  String get columnComment => 'Veeru kommentaar';

  @override
  String get columnCollation =>
      'Veeru järjestus (tühi kasutab serveri vaikeväärtust)';

  @override
  String get addDesignedColumn => 'Lisa veerg uude tabelisse';

  @override
  String get checkExpression => 'CHECK-avaldis';

  @override
  String get referencedSchema => 'Viidatud skeem / andmebaas';

  @override
  String get generating => 'Genereerimine…';

  @override
  String get generateReviewedDdl => 'Genereeri DDL ülevaatuseks';

  @override
  String get inspectCapturedDefinition =>
      'Kontrolli jäädvustatud definitsiooni';

  @override
  String get capturedObject => 'Jäädvustatud objekt';

  @override
  String get designReviewNote =>
      'Muudatused genereeritakse ülevaatuseks. Andmebaasi sisu jääb muutmata kuni üle vaadatud täitmiseni.';

  @override
  String get columnMetadataUnavailable =>
      'Veergude metaandmed pole selles ulatuses saadaval; kontrolli valitud skeemi enne veeruloendi kujundamist.';

  @override
  String get ordinaryColumn => 'Tavaline veerg';

  @override
  String get columnWithDefault => 'Vaikeväärtusega veerg';

  @override
  String get identityColumn => 'Identiteet / automaatne suurendus';

  @override
  String get generatedColumn => 'Genereeritud veerg';

  @override
  String get columnType => 'Veeru tüüp';

  @override
  String get nullableNotNull => 'NULL lubatud / NOT NULL';

  @override
  String get defaultExpression => 'Vaikeavaldis';

  @override
  String get generatedExpression => 'Genereeritud avaldis';

  @override
  String get columnCollationProperty => 'Veeru järjestus';

  @override
  String get loggedUnlogged => 'Logitud / logimata';

  @override
  String get tableComment => 'Tabeli kommentaar';

  @override
  String get storageEngine => 'Salvestusmootor';

  @override
  String get tableCollation => 'Tabeli järjestus';

  @override
  String get rowFormat => 'Rea vorming';

  @override
  String get createOrReplace => 'Loo või asenda';

  @override
  String get dropSelectedObject => 'Kustuta valitud objekt';

  @override
  String get addColumn => 'Lisa veerg';

  @override
  String get editColumnProperties => 'Muuda veeru omadusi';

  @override
  String get tableProperties => 'Tabeli omadused';

  @override
  String get triggerDefinition => 'Päästiku definitsioon';

  @override
  String get createTable => 'Loo tabel';

  @override
  String get viewDefinition => 'Vaate definitsioon';

  @override
  String get routineDefinition => 'Rutiini definitsioon';

  @override
  String get chooseExistingObject => 'Vali olemasolev objekt';

  @override
  String get nullable => 'NULL lubatud';

  @override
  String get removeIdentity => 'Eemalda identiteet';

  @override
  String get generatedAlways => 'Alati genereeritud';

  @override
  String get generatedByDefault =>
      'Vaikimisi genereeritud / automaatne suurendus';

  @override
  String get loggedTable => 'Logitud tabel';

  @override
  String get unloggedTable => 'Logimata tabel';

  @override
  String get orderedPrimaryKeyColumns => 'Järjestatud primaarvõtme veerud';

  @override
  String get orderedColumns => 'Järjestatud veerud';

  @override
  String get ordinaryIndex => 'Tavaline indeks';

  @override
  String get uniqueIndex => 'Unikaalne indeks';

  @override
  String get primaryKey => 'Primaarvõti';

  @override
  String get uniqueConstraint => 'Unikaalsuspiirang';

  @override
  String get foreignKey => 'Võõrvõti';

  @override
  String get checkConstraint => 'CHECK-piirang';

  @override
  String get immediateChecking => 'Kohene kontroll';

  @override
  String get deferrableChecking => 'Edasilükatav kontroll';

  @override
  String get initiallyImmediate => 'Algselt kohene';

  @override
  String get initiallyDeferred => 'Algselt edasi lükatud';

  @override
  String get referencedTable => 'Viidatud tabel';

  @override
  String get orderedReferencedColumns => 'Viidatud veerud vastavas järjestuses';

  @override
  String get objectDefinitionEditor =>
      'Objekti algse definitsiooni SQL-redaktor';

  @override
  String get onDelete => 'Kustutamisel';

  @override
  String get onUpdate => 'Uuendamisel';

  @override
  String get stay => 'Jää';

  @override
  String get saveSqlClose => 'Salvesta SQL ja sulge';

  @override
  String get discardSqlClose => 'Loobu SQL-ist ja sulge';

  @override
  String get closeBusyData => 'Sulge BusyData';

  @override
  String get saveDraftsClose => 'Salvesta mustandid ja sulge';

  @override
  String get closeWithoutRecovery => 'Sulge taastamiseta';

  @override
  String get recoveryFailed => 'Taastamine nurjus';

  @override
  String get discardFailedSaveClose => 'Loobu nurjunud salvestusest ja sulge';

  @override
  String get closeWithoutSavingRecovery => 'Sulge taastamist salvestamata';

  @override
  String get disableSqlRecovery => 'Keela SQL-i taastamine';

  @override
  String get historyPrivacy => 'Ajaloo privaatsus';

  @override
  String get enableSqlRetention => 'Luba SQL-i säilitamine';

  @override
  String get disableSqlRetention => 'Keela SQL-i säilitamine';

  @override
  String get clearHistory => 'Tühjenda ajalugu';

  @override
  String get deleteHistoryEntry => 'Kustuta ajalookirje';

  @override
  String get deleteSelected => 'Kustuta valitud';

  @override
  String get saveRetention => 'Salvesta säilitamine';

  @override
  String get retentionDays => 'Säilitamispäevad';

  @override
  String get sqlTextRetained => 'SQL-tekst säilitatakse';

  @override
  String get sqlTextDisabled => 'SQL-tekst keelatud';

  @override
  String get openHistoryQuery => 'Ava uuel SQL-i vahekaardil';

  @override
  String get caCertificateFile => 'CA-sertifikaadi fail';

  @override
  String get clientCertificateFile => 'Kliendisertifikaadi fail';

  @override
  String get clientKeyFile => 'Kliendivõtme fail';

  @override
  String get directConnection => 'Otseühendus';

  @override
  String get sshTunnel => 'SSH-tunnel';

  @override
  String get sshHost => 'SSH-host';

  @override
  String get sshPort => 'SSH-port';

  @override
  String get sshUser => 'SSH-kasutaja';

  @override
  String get reviewedKnownHosts => 'Ülevaadatud known_hosts-fail';

  @override
  String get reviewSshKey => 'Vaata üle SSH-hosti võti';

  @override
  String get changedSshKey => 'SSH-hosti võti muutus';

  @override
  String get verifyFingerprint =>
      'Kontrolli seda sõrmejälge sõltumatult enne selle usaldamist.';

  @override
  String get selectedKeyPassword => 'Valitud võti või parool';

  @override
  String get selectedAgentIdentity => 'Valitud SSH-agendi identiteet';

  @override
  String get selectedAgentSocket =>
      'Valitud Linuxi agendi sokkel / Windowsi nimega toru';

  @override
  String get selectedKeyFingerprint => 'Valitud võtme sõrmejälg · SHA256:…';

  @override
  String get selectedPrivateKey => 'Valitud privaatvõti (valikuline)';

  @override
  String get sshPassword => 'SSH-parool';

  @override
  String get keyPassphrase => 'Võtme paroolifraas';

  @override
  String get connectionTimeout => 'Ühenduse ajalimiit · 1–120 sekundit';

  @override
  String get sqlTimeout =>
      'SQL-i täitmise/otsingu tähtaeg · 1–3600 sekundit (0 = 60)';

  @override
  String get schemasEquivalent => 'Jäädvustatud skeemid on samaväärsed.';

  @override
  String get migrationComplete =>
      'Migratsioon hõlmab toetatud jäädvustatud erinevusi.';

  @override
  String get migrationPartial =>
      'Osaline migratsioon; toetamata erinevused jäävad.';

  @override
  String get differencesLimited =>
      'Erinevuste esitus on piiratud. Vaata üle täielikud salvestatud hetktõmmised ja loodud SQL.';

  @override
  String get absent => 'Puudub';

  @override
  String get definitionPreviewLimited =>
      'Definitsiooni eelvaade on piiratud; täielikud tõendid on algses hetktõmmises.';

  @override
  String get migrationBatchNote =>
      'SQL on üks sõltuvuste järgi järjestatud pakett. Üksiku objekti valik on vaatlemiseks ega vali rakendatavaid lauseid.';

  @override
  String get unsupportedLabel => 'Toetamata';

  @override
  String get differenceAdded => 'Lisatud';

  @override
  String get differenceRemoved => 'Eemaldatud';

  @override
  String get differenceChanged => 'Muudetud';

  @override
  String get selectHistoryEntry => 'Vali ajalookirje';

  @override
  String get searchSqlTarget => 'Otsi SQL-i või sihtmärki';

  @override
  String get closeSqlTab => 'Sulge SQL-i vahekaart';

  @override
  String get historyMetadataRetained =>
      'Oleku ja sihtmärgi metaandmed jäävad ajalukku.';

  @override
  String get historyPreviewNote =>
      'Ainult eelvaade. Säilitatud teksti hankimiseks ava uuel SQL-i vahekaardil.';

  @override
  String get selected => 'Valitud';

  @override
  String get authReviewNote =>
      'Kontrolli enne rakendamist täpset kasutajat või rolli ja sihtmärki. Volitusi ei lisata kunagi SQL-dokumentidesse ega ajalukku. Olemasolevad ühendused ja salvestatud paroolid jäävad eraldi.';

  @override
  String get createLogin => 'Loo sisselogimiskonto';

  @override
  String get createRole => 'Loo sisselogimiseta roll';

  @override
  String get setPassword => 'Määra parool';

  @override
  String get preventLogin => 'Keela uued sisselogimised';

  @override
  String get allowLogin => 'Luba uued sisselogimised';

  @override
  String get dropPrincipal => 'Kustuta kasutaja või roll';

  @override
  String get principalName => 'Kasutaja või rolli täpne nimi';

  @override
  String get accountHost =>
      'Konto täpne host (metamärgid laiendavad sisselogimise ulatust)';

  @override
  String get newPassword => 'Uus parool';

  @override
  String get repeatPassword => 'Korda uut parooli';

  @override
  String get reviewAccount => 'Vaata konto toiming üle';

  @override
  String get passwordsMismatch => 'Sisesta sama mittetühi parool kaks korda';

  @override
  String get accountSubmitFailed =>
      'Konto toimingut ei saanud saata. Kontrolli sihtmärki, autentimispoliitikat ja andmebaasi õigusi.';

  @override
  String get privilegeReviewNote =>
      'Kontrolli otseseid õigusi; loodud SQL vajab endiselt käivitamise ülevaatust.';

  @override
  String get inspectionLimited =>
      'Kuni 500 rida jaotises. Kitsenda otsingut; tühi jaotis ei tõesta tegeliku ligipääsu puudumist.';

  @override
  String get findPrincipal => 'Leia kasutaja / rolli nimi';

  @override
  String get searchPrincipals => 'Otsi kasutajaid ja rolle';

  @override
  String get choosePrincipal => 'Vali kasutaja või roll';

  @override
  String get inspectGrants => 'Kontrolli valitud õigusi';

  @override
  String get tablePrivileges => 'Tabeli / vaate õigused';

  @override
  String get schemaPrivileges => 'Skeemi õigused';

  @override
  String get databasePrivileges => 'Andmebaasi õigused';

  @override
  String get roleMembership => 'Rolli liikmelisus';

  @override
  String get defaultRole => 'Vaikerolli aktiveerimine';

  @override
  String get chooseGrantRole => 'Vali antav / tühistatav roll';

  @override
  String get tableView => 'Tabel / vaade';

  @override
  String get explicitPrivileges =>
      'Selgesõnalised õigused (komadega eraldatud)';

  @override
  String get setDefaultRole => 'Määra valitud vaikeroll';

  @override
  String get clearDefaultRole => 'Tühjenda vaikeroll';

  @override
  String get grantAccess => 'Anna ligipääs';

  @override
  String get revokeAccess => 'Tühista ligipääs';

  @override
  String get withoutDelegation => 'Ilma delegeerimiseta';

  @override
  String get allowDelegation => 'Luba saajal anda õigusi teistele';

  @override
  String get readonlyChanges =>
      'See profiil on kirjutuskaitstud. Muudatused nõuavad selgesõnaliselt kirjutatavat seanssi.';

  @override
  String get createPrincipal => 'Loo kasutaja / roll';

  @override
  String get manageAuthentication => 'Halda valitud autentimist';

  @override
  String get openPrivilegeSql => 'Ava õiguste SQL ülevaatuseks';

  @override
  String get inspectPrincipalFirst =>
      'Kontrolli valitud kasutajat või rolli enne muudatuse koostamist';

  @override
  String get accountAuthentication => 'Konto autentimine';

  @override
  String get schema => 'Skeem';

  @override
  String get available => 'Saadaval';

  @override
  String get availableEmpty => 'Saadaval · tühjad andmed';

  @override
  String get limitedVisibility => 'Piiratud nähtavus või ulatus';

  @override
  String get permissionDenied => 'Ligipääs keelatud';

  @override
  String get unavailable => 'Pole saadaval';

  @override
  String get profileDisabled => 'Profiili poolt keelatud';

  @override
  String get unknownState => 'Teadmata';

  @override
  String get inspecting => 'Kontrollimine…';

  @override
  String get refreshCapabilities => 'Värskenda võimekusi';

  @override
  String get staleRefresh => 'Aegunud · värskenda pärast ühendamist';

  @override
  String get staleContext =>
      'Aegunud · värskenda pärast ühendamist või konteksti muutmist';

  @override
  String get partialTreeLimit =>
      'Osaline · puu piir saavutatud; kitsenda objektide otsingut';

  @override
  String get schemaComparison => 'Skeemide võrdlus';

  @override
  String get searchTable => 'Otsi tabelit';

  @override
  String get focusObject => 'Fookusta';

  @override
  String get exportSvg => 'Ekspordi SVG';

  @override
  String get exportPng => 'Ekspordi PNG';

  @override
  String get diagramNotes => 'Diagrammi märkmed (kaasatud SVG-sse)';

  @override
  String get openNotes => 'Ava märkmed';

  @override
  String get saveNotes => 'Salvesta märkmed';

  @override
  String get newSnippet => 'Uus lõik';

  @override
  String get snippetName => 'Lõigu nimi';

  @override
  String get saveSnippet => 'Salvesta lõik';

  @override
  String get deleteSnippet => 'Kustuta salvestatud lõik';

  @override
  String get insertSnippet => 'Lisa SQL-dokumenti';

  @override
  String get snippetEditor => 'SQL-lõigu redaktor';

  @override
  String get snippetsNote =>
      'Lisa salvestatud kohalik SQL valitud dokumenti tagasivõtuga. Käivitamine jääb selgesõnaliseks.';

  @override
  String get level => 'Tase';

  @override
  String get expanded => 'laiendatud';

  @override
  String get collapsed => 'ahendatud';

  @override
  String get treeLevel => 'Tase';

  @override
  String get retainedView => 'Säilitatud vaade';

  @override
  String get tableQuerySnapshot => 'Tabelipäringu hetktõmmis';

  @override
  String get originalResultNote =>
      'Algne säilitatud tulemus; lehitsemine ja kontroll ei käivita SQL-i';

  @override
  String get tableFilterNote =>
      'Rakendamine saadab uue ülevaadatud päringu. Eelmine hetktõmmis jääb saadavale.';

  @override
  String get retainedFilterNote =>
      'Kõik hangitud read kindlas hetktõmmises. SQL-i ei käivitata uuesti. Järjestus võib erineda andmebaasi võrdlusjärjestusest.';

  @override
  String get retainedRowNote =>
      'Vali juba hangitud tulemuse rida. SQL-i ei käivitata uuesti.';

  @override
  String get copyLimitNote =>
      'Kopeerimine piirdub 10 000 lahtriga; suuremad vahemikud ekspordi säilitatud andmetena.';

  @override
  String get inlineValueLimit => 'Lahtris muutmine toetab 8KiB väärtusi';

  @override
  String get editContextChanged =>
      'Lähteseanss või muutmiskontekst muutus; kontrolli või värskenda hinnangut enne muudatuste ettevalmistamist';

  @override
  String get editAssessmentUnavailable =>
      'Muutmine pole saadaval; värskenda hinnangut, kui seanss on jõude';

  @override
  String get rowChangeReverted =>
      'Ootel reamuudatus tagasi võetud; andmebaas muutmata';

  @override
  String get sqlCopyRequiresMetadata =>
      'SQL-koopia nõuab taustaprotsessi ja säilitatud tüübimetateavet.';

  @override
  String get exportFullValue => 'Ekspordi kogu säilitatud väärtus';

  @override
  String valueExportReview(String bytes, String path) {
    return 'Kas salvestada $bytes baiti asukohta $path? Olemasolev sisu asendatakse. SQL-i ei käivitata uuesti.';
  }

  @override
  String get goToRetainedRow => 'Mine säilitatud reale';

  @override
  String get row => 'Rida';

  @override
  String get go => 'Mine';

  @override
  String get retryRows => 'Proovi säilitatud ridu uuesti';

  @override
  String get previousRows => 'Eelmised read';

  @override
  String get nextRows => 'Järgmised read';

  @override
  String get firstWindow => 'Esimene säilitatud aken';

  @override
  String get lastWindow => 'Viimane hangitud aken';

  @override
  String get setNull => 'Määra NULL';

  @override
  String copyFormat(String format) {
    return 'Kopeeri $format';
  }

  @override
  String get textValue => 'Tekst';

  @override
  String get sqlValues => 'SQL-väärtused';

  @override
  String get rowSelection => 'Ridade valik';

  @override
  String selectRow(String row) {
    return 'Vali rida $row';
  }

  @override
  String columnHeader(String column) {
    return 'Veerg $column';
  }

  @override
  String get pendingChange => 'ootel muudatus';

  @override
  String get readonlyCell => 'Kirjutuskaitstud lahter';

  @override
  String get editableCell => 'Muudetav lahter';

  @override
  String get loadValueFirst => 'Laadi see säilitatud väärtus esmalt';

  @override
  String get editUnavailable => 'Muutmine pole saadaval';

  @override
  String get editCell => 'Muuda lahtrit';

  @override
  String get unsupportedEditValue =>
      'Seda säilitatud väärtust saab ainult kontrollida';

  @override
  String bytesCount(String bytes) {
    return '$bytes baiti';
  }

  @override
  String get problems => 'Probleemid';

  @override
  String get ownedSessions => 'Oma seansid';

  @override
  String get noProblems => 'Salvestatud probleeme pole';

  @override
  String get duplicateConnection => 'Kopeeri ühendus';

  @override
  String get deleteConnection => 'Kustuta ühendus';

  @override
  String deleteConnectionReview(String name) {
    return 'Kas kustutada $name? Olemasolevad füüsilised seansid säilitavad algsed seaded.';
  }

  @override
  String get unresolvedSessions => 'Lahendamata seansid';

  @override
  String get disconnectSessionNote =>
      'Lahenda esmalt aktiivsed tööd ja tehingud. Ühenduse katkestamine mõjutab kõiki selle füüsilise seansi kliente; see ei kinnita tehinguid ega käivita SQL-i uuesti. Teadmata tulemused jäävad teadmata.';

  @override
  String get transferSettingsChanged => 'Seaded muutusid; vaata uuesti üle';

  @override
  String get transferReviewReady =>
      'Ülevaatus valmis · kontrolli sihti, ulatust, vastendust ja faili';

  @override
  String get sourcePreviewNotice => 'Allika eelvaade · ridu ei imporditud';

  @override
  String get transferRequiresReview => 'Vaata esmalt see täpne ülekanne üle';

  @override
  String get transferSubmittedNotice =>
      'Saadetud · tühistamine ei tühista kinnitatud tehinguid ega avaldatud faile';

  @override
  String get sqlExportExecutionNote => 'Uus ülevaadatud SQL-i käivitus';

  @override
  String get retainedExportSnapshotNote =>
      'Laaditud hetktõmmis; SQL-i ei käivitata';

  @override
  String get restorePartialCommitNote =>
      'Taaste võib osaliselt kinnituda. Tühistamine ei võta taastet tagasi.';

  @override
  String get sourcePreviewLimit => 'Allika eelvaade · kuni 20 rida';

  @override
  String get importBatchSafetyNote =>
      'Vead ja tühistamine säilitavad varasemad kinnitatud partiid. Allika räsi ja muutumatut materjali kontrollitakse enne saatmist.';

  @override
  String get nullMarkerLiteralNote =>
      'Jutumärkideta NULL-märgis; jutumärkides on see tekst';

  @override
  String immutableSourceHash(String hash) {
    return 'Muutumatu allika SHA-256: $hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return 'Allika veerg $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return 'Eelvaate rida $row, $column: $value';
  }

  @override
  String get transferCancellationNotice =>
      'Tühistamine taotletud · oota kinnitust';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed töödeldud · $committed kinnitatud · $rejected tagasi lükatud';
  }

  @override
  String get importAtomicPolicy => 'Kõik read ühes tehingus';

  @override
  String get importBatchPolicy => 'Kinnita partiid; vea korral peatu';

  @override
  String get importSkipPolicy => 'Jäta vigased read vahele; kinnita partiid';

  @override
  String closeWorkCounts(
    String operations,
    String documents,
    String saves,
    String edits,
    String jobs,
    String transactions,
    String unknown,
    String sessions,
  ) {
    return 'Kinnitused/ühendused: $operations\nSalvestamata dokumendid: $documents\nSalvestused pooleli: $saves\nOotel muudatused: $edits\nAktiivsed tööd: $jobs\nLahendatavad tehingud: $transactions\nTeadmata tulemused: $unknown\nEbakindlad seansid: $sessions';
  }

  @override
  String get closeDraftSaved => 'SQL-i mustandid salvestatakse kohapeal.';

  @override
  String get closeDraftLost =>
      'Taaste on keelatud; salvestamata SQL ja objektikavandid lähevad kaotsi.';

  @override
  String get closeDesignRecovery =>
      'Kavandid kasutavad privaatset piiratud taastet. Pärast avamist ühenda ja kontrolli metaandmeid selgesõnaliselt.';

  @override
  String get closeCleanupReview =>
      'Viimase seansiomaniku sulgemine taotleb tühistamist, pöörab kinnitatud tehingud tagasi ja katkestab ühenduse. Teadmata tulemused jäävad teadmata; sulgemine ei kinnita ega korda SQL-i.';

  @override
  String get closeSharedSession =>
      'Teised kliendid säilitavad jagatud füüsilise seansi.';

  @override
  String get closeStagedRecovery =>
      'Muudatused vajavad kinnitatud privaatset taastet, selgesõnalist ühendamist ja uut ülevaatust.';

  @override
  String get closeRecoveryLoss =>
      'Dokumente ja paigutust ei salvestatud. Sulgemine võib kaotada SQL-i ja muudatused; senised failid ja taaste säilivad.';

  @override
  String get closeWaitNotice =>
      'Oota enne sulgemist kinnitusi ja ühenduste puhastust.';

  @override
  String get saveFailedNotice =>
      'SQL-i salvestus ebaõnnestus. Säilita muudetud SQL või loobu sellest selgesõnaliselt.';

  @override
  String get closeCleanupFailed =>
      'Taustaprotsessi puhastus ebaõnnestus; BusyData jääb avatuks.';

  @override
  String get closeBackendUnverified =>
      'Taustaprotsessi olek on kontrollimata; töö võib veel jätkuda.';

  @override
  String historyRetainSqlReview(String days) {
    return 'SQL võib sisaldada saladusi. Kas säilitada teksti $days päeva?';
  }

  @override
  String get historyStopSqlReview =>
      'Kas lõpetada SQL-i säilitamine ja eemaldada see varasemast ajaloost?';

  @override
  String get historyClearReview =>
      'Kas kustutada kogu ajalugu? Aktiivsed tööd võivad lõpetamisel tulemuse salvestada.';

  @override
  String get historyDeleteReview => 'Kas kustutada valitud ajalookirje?';

  @override
  String get historyRetentionRange => 'Säilitusaeg peab olema 1–3650 päeva';

  @override
  String get enableSqlHistory => 'Luba SQL-i ajalugu';

  @override
  String get stopSqlHistory => 'Lõpeta SQL-i säilitamine';

  @override
  String get recoveryDiscardReview =>
      'Kas loobuda taastest? Selgita enne teadmata tulemused; loobumine ei tühista kinnitatud muudatusi.';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return 'Salvestamata SQL: $unsaved\nOotel muudatused: $edits\nAktiivsed tööd: $jobs';
  }

  @override
  String get recoveryStayOpen =>
      'Taaste ebaõnnestus. BusyData jääb avatuks; salvestamata töö säilib.';

  @override
  String get commitUncertaintyNote =>
      'Võrguviga võib jätta kinnitamise tulemuse teadmata. Ära proovi automaatselt uuesti.';

  @override
  String get closeObjectDesignDiscard =>
      'Salvestamata objektikavandi väljad jäetakse kõrvale. Kavandi säilitamiseks genereeri ja salvesta esmalt SQL.';

  @override
  String get savePrivateDrafts => 'Salvesta privaatsed taastemustandid';

  @override
  String get noPrivateDrafts => 'Ära salvesta taastemustandeid';

  @override
  String shortcutField(String command) {
    return '$command otsetee';
  }

  @override
  String get shortcutInvalid =>
      'Kasuta kehtivat, teisele toimingule määramata kiirklahvi. F6 ja Shift+F6 on reserveeritud.';

  @override
  String get disableRecoveryReview =>
      'Kas kustutada kohalik SQL-i, kavandite ja muudatuste taaste? Salvestamata töö jääb avatuks; krahh võib selle kaotada. Selgita teadmata tulemused enne.';

  @override
  String get preferencesSaved => 'Seaded salvestatud';

  @override
  String get sharingSessionReview =>
      'Päring jagab nimetatud füüsilist seanssi, tehingut, ajutisi objekte ja seadeid loetletud klientidega. Ühe kliendi sulgemine säilitab teised.';

  @override
  String get recoveryReconcileFirst =>
      'Lahenda rakendamisel või teadmata muudatused enne taaste keelamist. Loobu taastest ainult selle selgesõnalise ülevaatuse kaudu.';

  @override
  String get enterSearchText => 'Sisesta otsingutekst';

  @override
  String get noSearchMatches => 'Vasteid pole';

  @override
  String searchMatchCount(String position, String total) {
    return 'Vaste $position/$total';
  }

  @override
  String get formatSqlChanged =>
      'SQL või siht muutus. Algne SQL säilib; küsi uus vorminduse eelvaade.';

  @override
  String get formatSqlUnavailable =>
      'Vormindus pole saadaval puuduliku või toetamata süntaksi või analüüsipiiri tõttu. Algne SQL säilib.';

  @override
  String get stageChange => 'Lisa ootel muudatus';

  @override
  String pendingChangesCount(String count) {
    return '$count ootel muudatust; andmebaas muutub alles ülevaadatud rakendamisel.';
  }

  @override
  String discardChangesCount(String count) {
    return 'Loobu $count ootel muudatusest? Andmebaasitoimingut ei saadeta.';
  }

  @override
  String get recoveryNoExecution =>
      'Taaste ei ühendu, käivita lähte-SQL-i, jätka tehinguid ega korda muudatusi. Teadmata ja kinnitatud kirjeid ei saa uuesti rakendada.';

  @override
  String get recoveredDesign =>
      'Kavand taastatud. Ühendu selgesõnaliselt ja uuri praeguseid metaandmeid enne uut ülevaatust. Taastamine ei toonud SQL-i ega metaandmeid.';

  @override
  String get retainedUnavailable =>
      'Säilitatud andmed pole saadaval. Salvestatud SQL ja privaatne taaste jäävad kohalikuks.';

  @override
  String get activityFingerprintNote =>
      'Valitud tegevuse sõrmejälg kontrollitakse enne saatmist. Kirjutamise tulemus võib jääda teadmata.';

  @override
  String replaceFileReview(String path) {
    return 'Asenda ülevaadatud fail asukohas $path? Muutunud siht vajab uut ülevaatust.';
  }

  @override
  String get diagramPngSaved =>
      'Diagrammi PNG salvestatud. Pikad märkmed näitavad kuni kuut rida.';

  @override
  String get editTargetChanged =>
      'Muutmissiht muutus. Ava rearedaktor uuesti enne ootele lisamist.';

  @override
  String affectedRowCount(String count) {
    return 'Mõjutatud read: $count';
  }

  @override
  String get zoomIn => 'Suurenda';

  @override
  String get zoomOut => 'Vähenda';

  @override
  String get resetView => 'Lähtesta vaade';

  @override
  String get diagramKeys =>
      'Nooled nihutavad; + ja - suurendavad või vähendavad; Home lähtestab vaate.';

  @override
  String get explorerConnected => 'Uurija ühendatud';

  @override
  String get explorerDisconnected => 'Uurija ühendamata';

  @override
  String querySessionCount(String count) {
    return 'Päringuseansse $count';
  }

  @override
  String get metadataColumn => 'Veerg';

  @override
  String get metadataPosition => 'Asukoht';

  @override
  String get metadataUnique => 'Unikaalne';

  @override
  String get metadataJdbcType => 'JDBC tüüp';

  @override
  String get metadataAutoIncrement => 'Automaatne suurendamine';

  @override
  String get metadataReferencedColumn => 'Viidatud veerg';

  @override
  String get metadataComment => 'Kommentaar';

  @override
  String get metadataType => 'Tüüp';

  @override
  String get metadataEvent => 'Sündmus';

  @override
  String get metadataSpecificName => 'Algne konkreetne identifikaator';

  @override
  String get metadataOptions => 'Valikud';

  @override
  String get metadataInheritance => 'Pärilus';

  @override
  String get metadataDefinitionCaptured => 'Salvestatud algne definitsioon';

  @override
  String get metadataDefinitionUnavailable =>
      'Definitsioon pole salvestatud metaandmetes saadaval';

  @override
  String get metadataDefinitionUnsupported =>
      'Salvestatud objektil pole toetatud algset definitsiooni';

  @override
  String get connections => 'Ühendused';

  @override
  String get noConnections => 'Ühendusi veel pole';

  @override
  String get startTitle => 'Ühendu andmebaasiga';

  @override
  String get startDescription =>
      'Ühendu PostgreSQL-i, MySQL-i või MariaDB-ga objektide sirvimiseks, andmete haldamiseks ja päringute käivitamiseks.';

  @override
  String get savedStartTitle => 'Vali ühendus';

  @override
  String get savedStartDescription =>
      'Ühendu salvestatud ühendusega andmebaasihalduris objektide sirvimiseks ja päringute käivitamiseks.';

  @override
  String get noConnection => 'Ühendus puudub';

  @override
  String queryTitle(int number) {
    return 'Päring $number';
  }

  @override
  String get sessionMenu => 'Seanss';

  @override
  String get noFilterMatches => 'Sobivaid ühendusi või laaditud objekte pole';

  @override
  String get activityState => 'Olek';

  @override
  String get activityWait => 'Ootamine';

  @override
  String get generalSettings => 'Üldine';

  @override
  String get optionsSettings => 'Valikud';

  @override
  String get host => 'Host';

  @override
  String get databaseSystem => 'Andmebaasisüsteem';

  @override
  String get passwordStorage => 'Parooli salvestamine';

  @override
  String get environmentLabel => 'Keskkond';

  @override
  String get readOnlySettings => 'Kirjutuskaitse';

  @override
  String get tlsPolicy => 'TLS-i reeglid';

  @override
  String get sshConnection => 'SSH-ühendus';

  @override
  String get sshAuthentication => 'SSH autentimine';

  @override
  String get connectionTestAction => 'Testi ühendust';

  @override
  String get details => 'Üksikasjad';

  @override
  String get copyDetails => 'Kopeeri üksikasjad';

  @override
  String get retry => 'Proovi uuesti';

  @override
  String get filterCellValue => 'Filtreeri selle väärtuse järgi';

  @override
  String get connectsWhenRun => 'Ühendub käivitamisel';

  @override
  String get connectionSaving => 'Salvesta…';

  @override
  String get connectionConnecting => 'Ühenda…';

  @override
  String get connectionCancelling => 'Tühista…';

  @override
  String get connectionSettingsChanged =>
      'Seaded muutusid. Testi seda versiooni uuesti.';

  @override
  String get connectionTestChanged =>
      'Seaded muutusid. Testi seda versiooni uuesti.';

  @override
  String get connectionRequired => 'Nõutav';

  @override
  String get connectionCorrectFields => 'Kontrolli näidatud seadeid.';

  @override
  String get connectionHostname => 'Host · Kontrolli näidatud seadeid.';

  @override
  String get connectionSshHostname =>
      'SSH · Host · Kontrolli näidatud seadeid.';

  @override
  String get connectionMaxLength => 'Nimi ≤ 256';

  @override
  String get connectionTlsHelp =>
      'TLS · Host · SSH/SSL. Kontrolli näidatud seadeid.';

  @override
  String get connectionTlsReview =>
      'TLS · Host · SSH/SSL. Kontrolli näidatud seadeid.';

  @override
  String get connectionStorageUnavailable =>
      'Parooli salvestamine: Pole saadaval. Parool · Mitte kunagi.';

  @override
  String get connectionHostReviewed =>
      'Host · Usaldus kehtib ainult sellele profiilile ja täpsele lõpp-punktile.';

  @override
  String get connectionSshReviewing => 'SSH · Vaata üle SSH-hosti võti…';

  @override
  String get connectionFailureAuthentication =>
      'Nurjus · Autentimine · Üldine. Kontrolli näidatud seadeid.';

  @override
  String get connectionFailureTls =>
      'Nurjus · TLS · SSH/SSL. Kontrolli näidatud seadeid.';

  @override
  String get connectionFailureSshKey =>
      'Nurjus · Vaata üle SSH-hosti võti. Kontrolli näidatud seadeid.';

  @override
  String get connectionFailureEndpoint =>
      'Nurjus · Host · Port. Kontrolli näidatud seadeid.';

  @override
  String get connectionFailureCancelled => 'Tühistatud';

  @override
  String get connectionFailureSettings =>
      'Nurjus · Üldine. Kontrolli näidatud seadeid.';

  @override
  String get connectionFailureAccess =>
      'Nurjus · Tabeli / vaate õigused. Kontrolli näidatud seadeid.';

  @override
  String get connectionFailureUnavailable =>
      'Nurjus · Host · TLS · SSH. Kontrolli näidatud seadeid.';

  @override
  String get connectionFailureTimeout =>
      'Nurjus · Ühenduse ajalimiit · 1–120 sekundit. Kontrolli näidatud seadeid.';

  @override
  String get connectionFailureUnknown =>
      'Nurjus · Üldine · TLS · SSH. Kontrolli näidatud seadeid.';

  @override
  String connectionNumber(int min, int max) {
    return 'Sisesta täisarv vahemikus $min kuni $max';
  }

  @override
  String connectionSavedFailure(String name) {
    return 'Ühendus salvestati: $name. Ühendamine ebaõnnestus. ';
  }

  @override
  String get backendBusy =>
      'Taustateenus on hõivatud. Oodake praeguse päringu lõppu ja proovige uuesti.';

  @override
  String rpcRequestUnconfirmed(String code) {
    return 'Päringut ei kinnitatud (RPC $code).';
  }

  @override
  String get operationUnconfirmed => 'Toimingut ei saanud lõpule viia.';

  @override
  String get connectionFailureTlsMaterial =>
      'TLS-i materjal pole saadaval või on vigane. Kontrollige usaldusallikaid ja kliendi võtit lehel SSH/SSL.';

  @override
  String get managerTitle => 'Andmeallikad ja draiverid';

  @override
  String get sourceListTitle => 'Andmeallikad';

  @override
  String get driverLabel => 'Draiver';

  @override
  String get connectionTypeLabel => 'Ühenduse tüüp';

  @override
  String get defaultTcp => 'Vaikimisi (TCP)';

  @override
  String get authenticationLabel => 'Autentimine';

  @override
  String get userPasswordAuth => 'Kasutaja ja parool';

  @override
  String get neverStorage => 'Mitte kunagi';

  @override
  String get initialDatabaseLabel => 'Algne andmebaas';

  @override
  String get useSshTunnel => 'Kasuta SSH tunnelit';

  @override
  String get sshConfigurationLabel => 'SSH seadistus';

  @override
  String get createSshConfig => '<loo seadistus>';

  @override
  String get copySshSettings => 'Kopeeri SSH seaded';

  @override
  String get localPortLabel => 'Kohalik port';

  @override
  String get dynamicPortLabel => '<Dünaamiline>';

  @override
  String get useSsl => 'Kasuta SSL-i';

  @override
  String get useTruststore => 'Kasuta usaldushoidlat';

  @override
  String get clientKeyPasswordLabel => 'Kliendi võtme parool';

  @override
  String get modeLabel => 'Režiim';

  @override
  String get requireTls => 'Nõua';

  @override
  String get verifyCa => 'Kontrolli CA-d';

  @override
  String get fullVerification => 'Täielik kontroll';

  @override
  String get connectionSection => 'Ühendus';

  @override
  String get configurationApplied => 'Seadistus rakendatud';

  @override
  String get noOtherSshConfig => 'Ühelgi teisel allikal pole SSH seadistust.';

  @override
  String get generatedUrlHelp => 'Genereeritud kirjutuskaitstud JDBC-aadress.';

  @override
  String get tlsDriverDefaultHelp =>
      'SSL on seadistamata; komplekti draiver kasutab vaikeväärtust.';

  @override
  String get tlsClientKeyHelp =>
      'PEM-võtmed: PKCS#8 või OpenSSL; krüptitud või krüptimata.';

  @override
  String get legacyMariaTrustHelp =>
      'Olemasolev draiveri kontroll säilib. Valige usaldusallikad, et määrata juursertifikaadid.';

  @override
  String get metadataStartValue => 'Algväärtus';

  @override
  String get metadataMinimumValue => 'Miinimumväärtus';

  @override
  String get metadataMaximumValue => 'Maksimumväärtus';

  @override
  String get metadataIncrement => 'Samm';

  @override
  String get metadataCycle => 'Tsükliline';

  @override
  String get metadataCacheSize => 'Vahemälu suurus';

  @override
  String get metadataLastValue => 'Viimane väärtus';

  @override
  String get sequences => 'Jadad';

  @override
  String get namespaceSelection => 'Vali nimeruumid';

  @override
  String get namespaceSelectionNotice =>
      'Valik juhib introspektsiooni. Päringukonsoolid säilitavad oma täitmiskonteksti.';

  @override
  String get allNamespaces => 'Kõik nimeruumid';

  @override
  String get defaultNamespace => 'Vaikimisi';

  @override
  String get namespacePattern => 'Nimemuster (regulaaravaldis)';

  @override
  String namespaceCount(int selected, int known) {
    return '$selected / $known';
  }

  @override
  String get previousPage => 'Eelmine leht';

  @override
  String get patternRejected =>
      'Muster on vigane või ületab tööpiirangu. Eelmine valik säilitatakse.';

  @override
  String get namespaceNotSelected => 'Nimeruum pole introspektsiooniks valitud';

  @override
  String get newMenu => 'Uus';

  @override
  String get queryConsoles => 'Päringukonsoolid';

  @override
  String get viewOptions => 'Vaate valikud';

  @override
  String get quickDocumentation => 'Kiirdokumentatsioon';

  @override
  String get showEmptyGroups => 'Kuva tühjad rühmad';

  @override
  String get speedSearch => 'Kiirotsing';

  @override
  String get speedSearchScope => 'Ainult laiendatud ja laaditud sõlmed.';

  @override
  String get newSourceFolder => 'Uus allikate kaust';

  @override
  String get renameSourceFolder => 'Nimeta kaust ümber';

  @override
  String get moveToFolder => 'Teisalda kausta';

  @override
  String get moveUp => 'Liiguta üles';

  @override
  String get moveDown => 'Liiguta alla';

  @override
  String get folderMustBeEmpty =>
      'Enne kausta eemaldamist teisalda selles olevad allikad ja kaustad.';

  @override
  String get newVirtualView => 'Uus virtuaalne vaade';

  @override
  String get editVirtualDefinition => 'Muuda kohalikku definitsiooni';

  @override
  String get unboundVirtualView => 'Sidumata virtuaalsed vaated';

  @override
  String get localVirtualViewNotice =>
      'Kohalik SQL-definitsioon. Salvestamine ei käivita SQL-i ega loo serveri vaadet. Käivitamine kasutab tavalist SQL-i ülevaatust ja sõltumatut konsooli.';

  @override
  String get rebindVirtualView => 'Seo kohalik definitsioon siia';

  @override
  String get sourceFolderName => 'Kausta nimi';

  @override
  String get sourceFolderPathNotice =>
      'Pesastatud kaustade loomiseks kasuta märki /.';

  @override
  String get topLevel => 'Ülemine tase';

  @override
  String get virtualViewName => 'Virtuaalse vaate nimi';

  @override
  String get virtualViewSql => 'Virtuaalse vaate SQL-definitsioon';

  @override
  String get virtualViews => 'Virtuaalsed vaated';

  @override
  String get revealInExplorer => 'Näita andmebaasiuurijas';

  @override
  String get objectNotFound =>
      'Objekti ei leitud sellest nimeruumist. Värskenda metaandmeid või kontrolli õigusi.';

  @override
  String get objectHiddenByFilter =>
      'Objekt on praeguse vaatefiltriga peidetud.';

  @override
  String get revealFilterNotice =>
      'Objektiotsing kitsendab seda lehte; kogu kategooria arvu ei näidata.';

  @override
  String get clearObjectFilter => 'Tühjenda objektiotsing';

  @override
  String get compareStructure => 'Võrdle struktuuri';

  @override
  String get selectTwoCompatibleObjects =>
      'Vali Ctrl-klõpsuga kaks ühilduvat tabelit.';

  @override
  String get scopedComparisonRestriction =>
      'Võrdlus nõuab tavalisi tabeleid sama algse nime, skeemi ja mootoriga. Muud tüübid ja ümbernimetamise sobitus pole saadaval.';

  @override
  String get groupNamespaces => 'Rühmita andmebaasid ja skeemid';

  @override
  String get groupSchemaObjects => 'Rühmita skeemiobjektid';

  @override
  String get groupTableElements => 'Rühmita tabelielemendid';

  @override
  String get sortAlphabetically => 'Sordi tähestikuliselt';

  @override
  String get showVirtualObjects => 'Näita virtuaalseid objekte';

  @override
  String get showObjectComments => 'Näita objektide kommentaare';

  @override
  String get objectTypeFilter => 'Objektitüübi filter';

  @override
  String get partitionedTable => 'Sektsioonitud tabel';

  @override
  String get foreignTable => 'Võõrtabel';

  @override
  String get materializedView => 'Materialiseeritud vaade';

  @override
  String get functionObject => 'Funktsioon';

  @override
  String get procedureObject => 'Protseduur';

  @override
  String get sqlSymbolUnavailable =>
      'Kursori juures ei lahendatud püsivat objekti turvaliselt. Ühenda see konsool ja kasuta tabeli või vaate viidet väljaspool literaale ja kommentaare.';

  @override
  String get sqlSymbolAmbiguous =>
      'SQL-objekti viide on mitmetähenduslik. Täpsusta nimeruum või vali täpne andmebaasiobjekt.';

  @override
  String get deactivateSource => 'Inaktiveeri allikas';

  @override
  String get functions => 'Funktsioonid';

  @override
  String get procedures => 'Protseduurid';

  @override
  String get separateProceduresFunctions =>
      'Eralda protseduurid ja funktsioonid';

  @override
  String get renameVirtualView => 'Nimeta virtuaalvaade ümber';

  @override
  String get metadataPersistentScope =>
      'Ainult püsivad objektid; ajutised ja seansikohased objektid jäävad konsooli navigeerimisse.';

  @override
  String get metadataSessionScope =>
      'Ainult püsivad objektid; värskenda konsoolikohaseid objekte pärast käivitamist.';

  @override
  String get metadataLimitScope =>
      'Metaandmete piir on saavutatud. Kitsenda objektide ulatust.';

  @override
  String get completeColumnMetadataRequired =>
      'Enne importimist või muudatuste ettevalmistamist on vaja täielikke veergude metaandmeid.';

  @override
  String resizeColumn(String name) {
    return 'Muuda veeru $name laiust';
  }

  @override
  String get keyboardShortcutsHeading => 'Klaviatuuri otseteed';

  @override
  String sqlEditorLabel(String title) {
    return 'SQL-redaktor $title';
  }

  @override
  String get editorResultsDivider => 'Redaktori ja tulemuste eraldaja';

  @override
  String editorExtent(String percent) {
    return 'Redaktor $percent protsenti';
  }

  @override
  String get largerEditor => 'Suurenda redaktorit';

  @override
  String get smallerEditor => 'Vähenda redaktorit';

  @override
  String get explorerWidthDivider => 'Sirvija laiuse eraldaja';

  @override
  String get widerExplorer => 'Laienda sirvijat';

  @override
  String get narrowerExplorer => 'Kitsenda sirvijat';

  @override
  String explorerExtent(String width) {
    return '$width pikslit lai';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '$start–$end / $total UTF-16 ühikut';
  }

  @override
  String get dropDesignedColumn => 'Kustuta veerg';

  @override
  String get liveCatalogLabel => 'Praegune kataloog';

  @override
  String get liveSchemaLabel => 'Praegune skeem';

  @override
  String get searchPathLabel => 'Otsingutee';

  @override
  String get physicalSessionLabel => 'Füüsiline seanss';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return 'Ajalimiit: $seconds s · Ridade piirang: $rows';
  }

  @override
  String get saveFailedCloseTitle =>
      'SQL-i salvestamine nurjus · Sulge BusyData';

  @override
  String get createSection => 'Loo';

  @override
  String get newConnectionDescription => 'Seadista andmebaasiühendus';

  @override
  String get newQueryDescription => 'Kirjuta SQL uude päringusse';

  @override
  String get openSqlDescription => 'Ava olemasolev SQL-dokument';

  @override
  String get searchNoResults => 'Sobivaid toiminguid pole';

  @override
  String get actionsCategory => 'Toimingud';

  @override
  String get privateRecoveryCategory => 'Privaatne taastamine';

  @override
  String get shortcutRecordHelp =>
      'Vajuta kiirklahvi. Escape tühistab. F6 ja Shift+F6 on reserveeritud paanide vahel liikumiseks.';

  @override
  String get rowLimitInvalid => 'Sisesta ridade piirang vahemikus 1–1 000 000.';

  @override
  String get errorPolicy => 'Käivitusvea korral';

  @override
  String get tlsEncrypted => 'krüptitud';

  @override
  String get tlsUnencrypted => 'krüptimata';

  @override
  String get tlsUnobserved => 'vaatlemata';

  @override
  String get encryptionVerificationNote =>
      'Krüptimine ei kinnita sertifikaadi ega hostinime kontrollimist.';

  @override
  String get uniqueDesignedColumnName =>
      'Kasuta kordumatut veerunime; uued tabelid toetavad kuni 128 veergu';

  @override
  String activityBlockerUnavailable(String id) {
    return 'Blokeerija $id pole enam nähtav; värskenda ja kontrolli andmebaasi õigusi';
  }

  @override
  String get sshChangedKeyReview =>
      'Kontrolli muudetud võtit sõltumatult enne selle profiiliseose asendamist.';

  @override
  String get sshProfileTrustBinding =>
      'Usaldus kehtib ainult sellele profiilile ja täpsele lõpp-punktile.';

  @override
  String get databaseTlsEvidence => 'TLS · Andmebaasisüsteem';

  @override
  String get sshAlgorithmLabel => 'SSH · Tüüp';

  @override
  String get sshFingerprintLabel => 'SHA-256';

  @override
  String get sshPreviousFingerprintLabel => 'Eelmine · SHA-256';

  @override
  String get sshReviewedLabel => 'Vaata üle SSH-hosti võti';

  @override
  String get shortcutRecordAction => 'Salvesta kiirklahv';

  @override
  String get fileFormatLabel => 'Failivorming';

  @override
  String get encodingLabel => 'Kodeering';

  @override
  String get importPolicyLabel => 'Impordipoliitika';

  @override
  String get mainMenu => 'Peamenüü';

  @override
  String get activityReplyTooLarge =>
      'Tegevuse vastus ületab inspektori piiri.';

  @override
  String get activityListLimited =>
      'Loend on piiratud; uurige kitsamat sihtmärki selgesõnalise SQL-iga.';

  @override
  String get activitySelectionChanged =>
      'Valitud tegevus lõppes või muutus. Enne toimingu ülevaatamist valige selle praegune identiteet.';

  @override
  String connectionSavedDraftChanged(String name) {
    return 'Ühenduse väljad muutusid salvestamise ajal; seadistus salvestati: $name. Enne ühendamist vaata praegused väärtused üle.';
  }

  @override
  String get sshReviewTargetChanged =>
      'SSH kontrolli siht muutus; kontrolli uuesti';

  @override
  String get appearance => 'Välimus';

  @override
  String get theme => 'Kujundus';

  @override
  String get systemTheme => 'Süsteem';

  @override
  String get lightTheme => 'Hele';

  @override
  String get darkTheme => 'Tume';

  @override
  String get appLanguage => 'Keel';

  @override
  String get systemLanguage => 'Süsteemi keel';

  @override
  String get cut => 'Lõika';

  @override
  String get paste => 'Aseta';

  @override
  String get selectAll => 'Vali kõik';

  @override
  String get noSelection => 'Tekst pole saadaval';

  @override
  String get clipboardEmpty => 'Lõikelaual pole teksti';

  @override
  String get settingsDraftNotice =>
      'Käivitamise ja privaatse taastamise muudatused on salvestamata.';

  @override
  String get documentsMenu => 'Dokumendid';

  @override
  String get currentSql => 'Praegune SQL';

  @override
  String get searchActionsHint => 'Otsi toiminguid…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => 'Atribuudid';

  @override
  String get metadataSelectionUnavailable =>
      'Valige üksus selle jäädvustatud omaduste vaatamiseks. Eelmine valik pole saadaval.';

  @override
  String get secureStorage => 'Operatsioonisüsteemi turvahoidla';

  @override
  String get resultPresentation => 'View as';

  @override
  String get resultTable => 'Table';

  @override
  String get resultTranspose => 'Transpose';

  @override
  String get resultTree => 'Tree';

  @override
  String get resultText => 'Text';

  @override
  String get recordView => 'Record View';

  @override
  String get valueEditor => 'Value Editor';

  @override
  String get aggregateView => 'Aggregate View';

  @override
  String get relatedRows => 'Related Rows';

  @override
  String get cloneRow => 'Clone Row';

  @override
  String get displayFormat => 'Display format';

  @override
  String get canonicalValue => 'Canonical / raw';

  @override
  String get groupedNumber => 'Numeric grouping';

  @override
  String get jsonPretty => 'JSON formatted text';

  @override
  String get binaryHex => 'Binary hexadecimal';

  @override
  String get binaryBase64 => 'Binary Base64';

  @override
  String get uuidPresentation => 'UUID (16 bytes)';

  @override
  String get wrapText => 'Wrap text';

  @override
  String get selectedCellsScope => 'Selected cells only';

  @override
  String get retainedWindowScope => 'Current retained window only';

  @override
  String get serverDataOperations => 'Server-side table sorting and filtering';

  @override
  String get localDataOperations =>
      'Local sorting and filtering of retained data';

  @override
  String get partialRetainedScope =>
      'Partial retained result; this view does not represent the complete server table.';

  @override
  String get valueComplete => 'Complete retained value';

  @override
  String get valueTruncated =>
      'Truncated preview; the complete value is retained.';

  @override
  String get loadValueChunk => 'Load next 64 KiB';

  @override
  String get resetValueChunks => 'Reset value preview';

  @override
  String get structuredParseError =>
      'Structured interpretation is unavailable; exact raw content remains accessible.';

  @override
  String get structuredValueLimit =>
      'Structured display is limited to 256 KiB, 4,096 nodes and 32 levels.';

  @override
  String valueChunkRange(String start, String end, String total) {
    return 'Bytes $start–$end of $total';
  }

  @override
  String get presentationScopeLimit =>
      'This presentation exceeds its bounded scope. Select fewer cells or use Export.';

  @override
  String get transposeSelectionLimit =>
      'Transpose shows at most 32 selected rows. Narrow the selection to inspect another range.';

  @override
  String get jsonTree => 'JSON tree';

  @override
  String get xmlInterpretation => 'XML interpretation';

  @override
  String get imagePreview => 'Image preview';

  @override
  String get imagePreviewUnavailable =>
      'Image preview requires recognized image bytes within the 1 MiB / 4 megapixel limit.';

  @override
  String get valueDraftLimit =>
      'Value drafts exceed the shared 1 MiB text / 2 MiB complete-value limit. Stage or discard another draft first.';

  @override
  String get valueDraftPreserved =>
      'Value draft preserved; stored value is unchanged.';

  @override
  String get setDefault => 'Set DEFAULT';

  @override
  String get assignmentUnset => 'Unchanged / unset';

  @override
  String get assignmentValue => 'Exact value';

  @override
  String get assignmentNull => 'SQL NULL';

  @override
  String get assignmentDefault => 'Server DEFAULT';

  @override
  String get originalValue => 'Original value';

  @override
  String get stagedValue => 'Staged value';

  @override
  String get noRelatedRows =>
      'No available relationships for this retained row.';

  @override
  String get aggregateSelectedCount => 'Selected count';

  @override
  String get aggregateNonNull => 'Non-NULL count';

  @override
  String get aggregateNull => 'NULL count';

  @override
  String get aggregateDistinct => 'Distinct count';

  @override
  String get aggregateSum => 'Sum';

  @override
  String get aggregateAverage => 'Average';

  @override
  String get aggregateMinimum => 'Minimum';

  @override
  String get aggregateMaximum => 'Maximum';

  @override
  String get aggregateStoredValues =>
      'Aggregates use original retained values; staged edits are excluded.';

  @override
  String get relatedRowsUnavailable =>
      'Related-row navigation requires complete metadata and verified retained provenance.';

  @override
  String get stagedInsertReview =>
      'Clone staged as an insert. Review and edit its assignments before Apply.';

  @override
  String get rawValue => 'Raw value';

  @override
  String get previousRecord => 'Previous record';

  @override
  String get nextRecord => 'Next record';

  @override
  String get binaryInputError =>
      'Enter complete hexadecimal bytes or valid Base64 for the selected binary mode.';

  @override
  String get valueChunkEncoding =>
      'This byte page begins or ends inside a UTF-8 character. Use hexadecimal or export the complete value.';

  @override
  String get copyDisplayedText => 'Copy displayed text';

  @override
  String get requiredColumn => 'NOT NULL';

  @override
  String get editStagedInserts => 'Edit staged inserts';

  @override
  String get metadataSettings => 'Metadata and introspection';

  @override
  String get metadataIncludeCatalogs =>
      'Included databases (one exact name per line; empty uses current database)';

  @override
  String get metadataExcludeCatalogs => 'Excluded databases';

  @override
  String get metadataIncludeSchemas =>
      'Included schemas (empty uses current resolution path)';

  @override
  String get metadataExcludeSchemas => 'Excluded schemas';

  @override
  String get metadataIncludePatterns => 'Included object patterns';

  @override
  String get metadataExcludePatterns => 'Excluded object patterns';

  @override
  String get metadataSystemObjects => 'Include system objects';

  @override
  String get metadataDefaultLevel => 'Default introspection level';

  @override
  String get metadataLevelNames => 'Names and identities';

  @override
  String get metadataLevelStructure => 'Structure';

  @override
  String get metadataLevelSource => 'Structure and source';

  @override
  String get metadataFullRefresh => 'Full refresh';

  @override
  String get metadataIncrementalRefresh => 'Incremental refresh';

  @override
  String get metadataScopeLevels =>
      'Scope levels: catalog / schema / level, one per line';

  @override
  String get metadataCacheState => 'Cache state';

  @override
  String get metadataConfigurationChanged =>
      'Metadata configuration changed; reopen to review current settings';

  @override
  String get metadataAddScope => 'Add scope level';

  @override
  String get metadataAddName => 'Add exact name';

  @override
  String get metadataObjectKinds => 'Object kinds';

  @override
  String get metadataLastRefresh => 'Last successful refresh';

  @override
  String get metadataPatternsNote =>
      'Patterns use * for any characters and ? for one character. Names remain exact database identifiers.';

  @override
  String get sqlLanguage => 'SQL language';

  @override
  String get sqlDialect => 'SQL dialect';

  @override
  String get sqlPostgresql => 'PostgreSQL';

  @override
  String get sqlMysql => 'MySQL';

  @override
  String get sqlMariadb => 'MariaDB';

  @override
  String get sqlPreferenceScope => 'Settings scope';

  @override
  String get sqlDialectDefaults => 'Dialect defaults';

  @override
  String get sqlDialectDefaultsDescription =>
      'Applies to SQL documents using this dialect unless their connection has an override.';

  @override
  String get sqlProfileOverrideDescription =>
      'Applies only to SQL documents owned by the selected connection.';

  @override
  String get sqlUseDialectDefaults =>
      'Use dialect defaults for this connection';

  @override
  String get sqlFormatting => 'SQL formatting';

  @override
  String get sqlKeywordCase => 'Keyword case';

  @override
  String get sqlPreserveCase => 'Preserve case';

  @override
  String get sqlUpperCase => 'Uppercase';

  @override
  String get sqlLowerCase => 'Lowercase';

  @override
  String get sqlIndentationWidth => 'Indentation width';

  @override
  String get sqlContinuationIndent => 'Continuation indentation';

  @override
  String get sqlClauseBreaks => 'Start clauses on new lines';

  @override
  String get sqlJoinLayout => 'JOIN layout';

  @override
  String get sqlNewLine => 'New line';

  @override
  String get sqlSameLine => 'Same line';

  @override
  String get sqlCommaPlacement => 'Comma placement';

  @override
  String get sqlLeading => 'Leading';

  @override
  String get sqlTrailing => 'Trailing';

  @override
  String get sqlLogicalPlacement => 'Logical operator placement';

  @override
  String get sqlWrapLists => 'Wrap field and assignment lists';

  @override
  String get sqlWrapArguments => 'Wrap function arguments';

  @override
  String get sqlIndentSubqueries => 'Indent subqueries';

  @override
  String get sqlCteBreaks => 'Separate common table expressions';

  @override
  String get sqlParenthesisSpacing => 'Space inside parentheses';

  @override
  String get sqlOperatorSpacing => 'Space around operators';

  @override
  String get sqlAlignment => 'Align wrapped assignments';

  @override
  String get sqlMaximumLine => 'Maximum line length';

  @override
  String get sqlPreserveBlankLines => 'Preserve intentional blank lines';

  @override
  String get sqlInspections => 'SQL inspections';

  @override
  String get sqlInspectionDisabled => 'Disabled';

  @override
  String get sqlSeverityError => 'Error';

  @override
  String get sqlSeverityWarning => 'Warning';

  @override
  String get sqlSeverityInformation => 'Information';

  @override
  String get sqlSeverityHint => 'Hint';

  @override
  String get sqlInspectionUpdateWhere => 'UPDATE without WHERE';

  @override
  String get sqlInspectionDeleteWhere => 'DELETE without WHERE';

  @override
  String get sqlInspectionRelation => 'Unresolved relation';

  @override
  String get sqlInspectionColumn => 'Unresolved column';

  @override
  String get sqlInspectionAmbiguous => 'Ambiguous column';

  @override
  String get sqlInspectionDerived => 'Invalid derived-table column';

  @override
  String get sqlInspectionDuplicateAlias => 'Duplicate relation alias';

  @override
  String get sqlInspectionDuplicateCte => 'Duplicate common table expression';

  @override
  String get sqlInspectionDuplicateInsert => 'Duplicate INSERT column';

  @override
  String get sqlInspectionInsertTarget => 'Unknown INSERT target column';

  @override
  String get sqlInspectionUpdateTarget => 'Unknown UPDATE target column';

  @override
  String get sqlInspectionArguments => 'Invalid routine argument count';

  @override
  String get sqlInspectionOverload => 'No matching routine overload';

  @override
  String get sqlInspectionAggregate => 'Invalid aggregate or window expression';

  @override
  String get sqlInspectionComparison => 'Incompatible comparison types';

  @override
  String get sqlInspectionAssignment => 'Incompatible assignment type';

  @override
  String get parameterInformation => 'Parameter information';

  @override
  String activeArgument(int index) {
    return 'Active argument: $index';
  }

  @override
  String get numericScale2 => 'Numeric grouping · 2 decimal places';

  @override
  String get numericScale4 => 'Numeric grouping · 4 decimal places';

  @override
  String get temporalDate => 'Temporal date · yyyy-MM-dd';

  @override
  String get temporalTime => 'Temporal time · ISO';

  @override
  String get temporalUtc => 'Timestamp · UTC (requires explicit offset)';

  @override
  String get temporalLocal =>
      'Timestamp · local timezone (requires explicit offset)';

  @override
  String get formatCurrentStatement => 'Format current statement';

  @override
  String get completionLimited =>
      'More matches are available. Type a longer prefix.';

  @override
  String get parameterInformationLimited =>
      'More overloads exist; parameter information is limited.';

  @override
  String get sqlInspectionSyntax => 'SQL syntax error';

  @override
  String get sqlInspectionDialect =>
      'SQL construct is unavailable for this dialect';

  @override
  String get sqlInspectionUnavailable =>
      'SQL analysis is unavailable for this construct';

  @override
  String get sqlInspectionUnknownFunction => 'Unknown routine';

  @override
  String get sqlInspectionMetadata =>
      'SQL inspection is incomplete because metadata is unavailable';

  @override
  String get sqlDiagnosticsEmpty =>
      'No SQL inspections were reported for this document.';

  @override
  String sqlDiagnosticSpan(int start, int end, String source) {
    return 'UTF-16 $start–$end · $source';
  }

  @override
  String get sqlDiagnosticGo => 'Go to SQL span';

  @override
  String get sqlDiagnosticFix => 'Apply selected correction';

  @override
  String get sqlDiagnosticReplacement => 'Replacement text';

  @override
  String get sqlDiagnosticStale =>
      'SQL inspection context changed. Request inspections again.';

  @override
  String get sqlDiagnosticUnavailable =>
      'SQL inspections are unavailable for the current document.';

  @override
  String sqlDiagnosticCount(int count) {
    return '$count SQL inspections';
  }

  @override
  String get aggregateTextOrder =>
      'Text minimum/maximum use retained UTF-16 ordinal order; database collation is not applied.';

  @override
  String get aggregateMixedTypes =>
      'The selected values have incompatible types. Select values with a common type.';

  @override
  String get aggregateUnsupportedOrder =>
      'Ordering and numeric calculations are unavailable for this value type.';

  @override
  String get relatedKeyNotProjected =>
      'Select all relationship key columns in the source result before navigating.';

  @override
  String get relatedNullKey =>
      'A NULL relationship key has no matching related row.';

  @override
  String get relatedTargetUnavailable =>
      'The relationship target is outside this session’s supported database scope.';

  @override
  String get relatedValueLimited =>
      'The relationship key is truncated or exceeds navigation limits. Browse the target explicitly.';

  @override
  String get temporalCustomPattern => 'Temporal · custom pattern';

  @override
  String get temporalPattern => 'Temporal display pattern';

  @override
  String get temporalSourceZone => 'Original calendar fields';

  @override
  String get temporalZone => 'Display timezone';

  @override
  String get temporalPatternHelp =>
      'Use ICU calendar fields and up to six S digits for exact fractions. UTC/local conversion requires an explicit offset. Unsupported temporal values remain raw.';

  @override
  String get temporalPatternInvalid =>
      'Use a pattern of 1–128 characters with supported calendar fields, balanced quotes, and at most six S digits. Timezone letters z, Z and v are unsupported; choose the display timezone separately.';

  @override
  String get editCompleteValue => 'Edit complete value';

  @override
  String get completeValueEditLimit =>
      'Complete editing requires verified retained ownership, at most 1 MiB across original and new values, and 262,144 text units per value. Larger values remain available for export.';

  @override
  String get completeValueReady =>
      'Complete retained value loaded for editing; changes are staged only.';

  @override
  String get binaryNextEditPage => 'Next 16 KiB';

  @override
  String get binaryPreviousEditPage => 'Previous 16 KiB';

  @override
  String get arrayEditLimit =>
      'Array edits use exact native PostgreSQL text, at most 16 KiB of text, six dimensions and 1,024 scalar values. Java validates the captured element type.';

  @override
  String get valueChangedDuringStage =>
      'The earlier value was staged. Your newer draft is preserved; review it before staging again.';

  @override
  String textValuePage(String current, String total) {
    return 'Text page $current of $total';
  }

  @override
  String get textValuePagesScope =>
      'Only this text page is shown. Copy and export actions keep their stated scope.';

  @override
  String get textValueEditScope => 'Stage change includes every text page.';

  @override
  String get textValuePreviousPage => 'Previous text page';

  @override
  String get textValueNextPage => 'Next text page';

  @override
  String get valuePageEditLimit =>
      'That text is invalid or too large for this page. The previous text was kept.';

  @override
  String get valueAddEditPage => 'Add editing page';

  @override
  String get binaryAppendPageReason =>
      'Finish a valid, full last binary page before adding another page. Bytes are never padded.';

  @override
  String get valueEditorActions => 'Value actions';

  @override
  String get utf8Hex => 'UTF-8 hexadecimal';

  @override
  String get utf8Base64 => 'UTF-8 Base64';

  @override
  String get nativeTextNulUnavailable =>
      'Plain text editing is unavailable for values containing a NUL character. UTF-8 byte views and exact export remain available.';

  @override
  String get textClipboardNulUnavailable =>
      'This text contains a NUL character and cannot be copied exactly. Export the value or choose another extractor.';

  @override
  String sqlVisibleLine(int line, int total, int column) {
    return 'Visible SQL line $line of $total, column $column';
  }

  @override
  String get sqlLinePreviewTruncated => 'Line preview truncated';

  @override
  String sqlActiveCarets(int count) {
    return '$count carets active';
  }

  @override
  String get sqlCompositionActive => 'Input composition active';

  @override
  String get sqlEditorDocumentLimit =>
      'The edit exceeds the 8M UTF-16 document limit. Use a smaller document.';

  @override
  String get sqlEditorLineLimit =>
      'The edit exceeds the 100,000-line document limit. Use a smaller document.';

  @override
  String get sqlEditorCaretLimit =>
      'The editor supports at most 64 carets. Remove extra carets before adding more.';

  @override
  String get sqlEditorFinishComposition =>
      'Finish input composition before changing this selection.';

  @override
  String get sqlEditorClipboardLimit =>
      'The exact selection exceeds the 1 MiB clipboard limit. Save or export the text instead.';

  @override
  String get sqlEditorSelectionUnavailable =>
      'The editor cannot apply this selection. The original SQL is retained.';

  @override
  String get sqlEditorClipboardUnavailable =>
      'The clipboard is unavailable. Your SQL and selection have been kept.';

  @override
  String get metadataCacheWriteUnavailable =>
      'Vahemälu ei saanud salvestada. Praegused metaandmed on endiselt saadaval.';

  @override
  String get metadataCacheRebuiltVersion =>
      'Praeguse versiooni jaoks uuesti loodud';

  @override
  String get metadataCacheRebuiltCorrupt =>
      'Pärast vahemälu viga uuesti loodud';

  @override
  String get editSessionBusy =>
      'See seanss on hõivatud. Oodake käimasoleva töö lõppu ja taotlege seejärel uut muudetavuse hinnangut.';

  @override
  String get editIdentityRequired =>
      'Enne muutmist valige täielik primaarvõti või kordumatu identifikaator, mis ei luba NULL-väärtusi.';

  @override
  String get editColumnsReadOnly =>
      'Kõik projektsiooni veerud on genereeritud või kirjutuskaitstud.';

  @override
  String get editResultNotReady =>
      'Enne uue muudetavuse hinnangu taotlemist oodake selle säilitatud tulemuse valmimist.';

  @override
  String get editProjectionUnsupported =>
      'Muutmine nõuab otsest SELECT-päringut ühest baastabelist, kus iga baasveerg on valitud ühe korra.';

  @override
  String get sqlInspectionDuplicateUsingColumn => 'Korduv JOIN USING veerg';

  @override
  String get sqlInspectionUnresolvedUsingColumn =>
      'JOIN USING veerg puudub ühes operandis';

  @override
  String get sqlInspectionAmbiguousUsingColumn =>
      'Mitmetähenduslik ühine JOIN-veerg';

  @override
  String get sqlInspectionOutputColumnCount =>
      'Deklareeritud väljundveergude arv ei ühti';

  @override
  String get sqlInspectionAmbiguousOverload =>
      'Mitmetähenduslik rutiini ülekoormus';

  @override
  String get sqlInspectionBooleanType => 'Sobimatu tõeväärtusavaldise tüüp';

  @override
  String get sqlInspectionOperatorTypes =>
      'Operaatori operandide ühildumatud tüübid';

  @override
  String get sqlInspectionArrayTypes =>
      'Massiivi elementide ühildumatud tüübid';

  @override
  String get sqlInspectionCaseConditionType => 'CASE-tingimuse ühildumatu tüüp';

  @override
  String get sqlInspectionCaseResultTypes =>
      'CASE-tulemuste ühildumatud tüübid';

  @override
  String get sqlInspectionCoalesceTypes =>
      'COALESCE-argumentide ühildumatud tüübid';

  @override
  String get sqlInspectionSetColumnCount =>
      'Hulgaoperatsiooni veergude arv ei ühti';

  @override
  String get sqlInspectionSetTypes =>
      'Hulgaoperatsiooni tulemuste ühildumatud tüübid';

  @override
  String get sqlInspectionRecursiveCteType => 'Rekursiivse CTE tüübid ei ühti';
}
