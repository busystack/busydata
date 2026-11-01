// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get cancel => 'Anuluj';

  @override
  String get windowMinimize => 'Minimalizuj';

  @override
  String get windowMaximize => 'Maksymalizuj';

  @override
  String get windowRestore => 'Przywróć';

  @override
  String get databaseExplorer => 'Eksplorator baz danych';

  @override
  String get databases => 'Bazy danych';

  @override
  String get newConnection => 'Nowe połączenie';

  @override
  String get filterTree => 'Filtruj połączenia i obiekty';

  @override
  String get treeFilterScope => 'Filtruje wczytane obiekty drzewa';

  @override
  String get searchObjects => 'Szukaj obiektów bazy danych';

  @override
  String get fileMenu => 'Plik';

  @override
  String get editMenu => 'Edycja';

  @override
  String get viewMenu => 'Widok';

  @override
  String get connectionMenu => 'Połączenie';

  @override
  String get objectMenu => 'Obiekt';

  @override
  String get runMenu => 'Opcje wykonania';

  @override
  String get commands => 'Polecenia';

  @override
  String get findCommand => 'Szukaj polecenia';

  @override
  String get newSql => 'Nowe zapytanie';

  @override
  String get openSql => 'Otwórz SQL';

  @override
  String get openSqlFile => 'Otwórz plik SQL';

  @override
  String get saveSql => 'Zapisz SQL';

  @override
  String get closeTab => 'Zamknij kartę';

  @override
  String get openWorkspace => 'Otwórz obszar roboczy';

  @override
  String get saveWorkspace => 'Zapisz obszar roboczy';

  @override
  String get settings => 'Ustawienia';

  @override
  String get findText => 'Znajdź';

  @override
  String get replaceText => 'Zamień';

  @override
  String get formatSql => 'Formatuj SQL';

  @override
  String get lineComments => 'Przełącz komentarze wierszy';

  @override
  String get snippets => 'Fragmenty SQL';

  @override
  String get run => 'Wykonaj';

  @override
  String get runStatement => 'Wykonaj bieżącą instrukcję';

  @override
  String get runSelection => 'Wykonaj zaznaczenie';

  @override
  String get runScript => 'Wykonaj skrypt';

  @override
  String get explain => 'Plan wykonania';

  @override
  String get explainAnalyze => 'Plan z wykonaniem';

  @override
  String get connect => 'Połącz';

  @override
  String get disconnect => 'Rozłącz';

  @override
  String get sessionDetails => 'Szczegóły sesji';

  @override
  String get beginTransaction => 'Rozpocznij transakcję';

  @override
  String get commitTransaction => 'Zatwierdź transakcję';

  @override
  String get rollbackTransaction => 'Wycofaj transakcję';

  @override
  String get enableAutoCommit => 'Włącz automatyczne zatwierdzanie';

  @override
  String get disableAutoCommit => 'Wyłącz automatyczne zatwierdzanie';

  @override
  String get outcomeUnknown => 'Nieznany wynik';

  @override
  String get outcomeUnknownNote =>
      'Operacja mogła się zakończyć. Ta sesja nie może wykonywać dalszego SQL. Nigdy nie ponawiaj automatycznie; ustal wynik przed rozpoczęciem nowej pracy.';

  @override
  String get notConnected => 'Rozłączono';

  @override
  String get autoCommit => 'Automatyczne zatwierdzanie';

  @override
  String get manualTransaction => 'Transakcja ręczna';

  @override
  String get readOnlyPolicy => 'Zasada tylko do odczytu BusyData';

  @override
  String get data => 'Dane';

  @override
  String get structure => 'Struktura';

  @override
  String get results => 'Wyniki';

  @override
  String get messages => 'Komunikaty';

  @override
  String get plan => 'Plan';

  @override
  String get changes => 'Zmiany';

  @override
  String get history => 'Historia';

  @override
  String get jobs => 'Zadania';

  @override
  String get retainedResults => 'Zachowane wyniki';

  @override
  String get recoverEdits => 'Odzyskaj przygotowane zmiany';

  @override
  String get applyAndCommit => 'Zastosuj i zatwierdź';

  @override
  String get inspectStructure => 'Sprawdź strukturę';

  @override
  String get openData => 'Otwórz dane';

  @override
  String get openDefinition => 'Otwórz definicję';

  @override
  String get copyQualifiedName => 'Kopiuj kwalifikowaną nazwę';

  @override
  String get refresh => 'Odśwież';

  @override
  String get columns => 'Kolumny';

  @override
  String get indexes => 'Indeksy';

  @override
  String get constraints => 'Klucze i ograniczenia';

  @override
  String get foreignKeys => 'Klucze obce';

  @override
  String get triggers => 'Wyzwalacze';

  @override
  String get definition => 'Definicja';

  @override
  String get dependencies => 'Zależności';

  @override
  String get connectionCapabilities => 'Przegląd połączenia';

  @override
  String get sessionsAndLocks => 'Sesje i blokady';

  @override
  String get usersAndRoles => 'Użytkownicy i role';

  @override
  String get saveSnapshot => 'Zapisz migawkę schematu';

  @override
  String get compareSchemas => 'Porównaj schematy';

  @override
  String get objectDesigner => 'Projektant obiektów';

  @override
  String get diagram => 'Diagram ER';

  @override
  String get backup => 'Kopia zapasowa';

  @override
  String get restore => 'Przywróć';

  @override
  String get importData => 'Importuj dane';

  @override
  String get exportRetained => 'Eksportuj zachowane dane';

  @override
  String get exportSql => 'Wykonaj eksport SQL';

  @override
  String get stageInsert => 'Wstaw wiersz';

  @override
  String get stageUpdate => 'Edytuj wiersz';

  @override
  String get stageDelete => 'Usuń wiersz';

  @override
  String get discardChanges => 'Odrzuć oczekujące zmiany';

  @override
  String get disposeResult => 'Zwolnij zachowane dane';

  @override
  String get currentSchema => 'Bieżący schemat (do zmiany)';

  @override
  String get desiredSchema => 'Docelowy schemat';

  @override
  String get applyTo => 'Zastosuj do';

  @override
  String get loading => 'Ładowanie';

  @override
  String get empty => 'Brak obiektów w tym zakresie';

  @override
  String get more => 'Więcej';

  @override
  String get filter => 'Filtruj';

  @override
  String get sort => 'Sortuj';

  @override
  String get selectTarget => 'Wybierz połączenie';

  @override
  String get requireSql => 'Wymaga dokumentu SQL';

  @override
  String get requireSession => 'Wymaga połączonej sesji o znanym stanie';

  @override
  String get requireResult => 'Wymaga zachowanych danych';

  @override
  String get requireObject => 'Wymaga obiektu docelowego';

  @override
  String get cancelRequested => 'Zażądano anulowania';

  @override
  String get cancelled => 'Anulowano';

  @override
  String get queued => 'W kolejce';

  @override
  String get running => 'W trakcie';

  @override
  String get completed => 'Zakończono';

  @override
  String get failed => 'Niepowodzenie';

  @override
  String get partial => 'Częściowy';

  @override
  String get sessionSharing => 'Udostępnij istniejącą sesję (zaawansowane)';

  @override
  String get production => 'Produkcja';

  @override
  String get staging => 'Środowisko testowe';

  @override
  String get development => 'Programowanie';

  @override
  String get executionOptions => 'Opcje wykonania';

  @override
  String get resultRowLimit => 'Limit wierszy wyniku (1–1000000)';

  @override
  String get boundedRead => 'Odczyt ograniczony';

  @override
  String get streamingRead =>
      'Odczyt strumieniowy · posiada transakcję odczytu';

  @override
  String get stopOnError => 'Zatrzymaj skrypt przy błędzie';

  @override
  String get continueOnError =>
      'Kontynuuj przy błędzie · poprzednie instrukcje mogły zostać zatwierdzone';

  @override
  String get loadMore => 'Załaduj więcej';

  @override
  String get favorite => 'Przełącz ulubione';

  @override
  String get connectionGroup => 'Grupa połączeń';

  @override
  String get copyRange => 'Kopiuj zakres';

  @override
  String get inspectValue => 'Sprawdź wartość';

  @override
  String get editConnection => 'Edytuj połączenie';

  @override
  String get chooseSnapshot => 'Wybierz migawkę';

  @override
  String get captureSchema => 'Zapisz stan schematu';

  @override
  String get sameSchemaRestriction =>
      'Migawki muszą mieć ten sam silnik, nazwę schematu i wersję. Porównanie i zapis nigdy nie stosują zmian.';

  @override
  String get restoredTaskState =>
      'Przywrócono odwołanie do dokumentu. Poprzednie dane backendu, sesje i zadania są niedostępne. Wybierz jawną akcję rozpoczęcia nowej pracy; przywracanie nie łączy, nie wykonuje SQL ani nie powtarza zmian.';

  @override
  String get preChangeSnapshot =>
      'Migawka sprzed zmian · zmiany zatwierdzone. Odśwież jawnie, aby sprawdzić bieżące wiersze i wartości domyślne serwera.';

  @override
  String get sqlProvenance => 'Pochodzenie SQL';

  @override
  String get assessEditing => 'Oceń możliwość edycji';

  @override
  String get viewDetails => 'Pokaż szczegóły';

  @override
  String get gridMenu => 'Siatka danych';

  @override
  String get visibleColumns => 'Widoczne kolumny';

  @override
  String get hidden => 'Ukryta';

  @override
  String get ascending => 'Rosnąco';

  @override
  String get descending => 'Malejąco';

  @override
  String get equals => 'Równe';

  @override
  String get notEqual => 'Różne od';

  @override
  String get lessThan => 'Mniejsze niż';

  @override
  String get greaterThan => 'Większe niż';

  @override
  String get isNull => 'Jest NULL';

  @override
  String get isNotNull => 'Nie jest NULL';

  @override
  String get exactValue => 'Dokładna wartość';

  @override
  String get sortTable => 'Sortuj dane tabeli';

  @override
  String get filterTable => 'Filtruj dane tabeli';

  @override
  String get sortRetained => 'Sortuj zachowaną migawkę';

  @override
  String get filterRetained => 'Filtruj zachowaną migawkę';

  @override
  String get applyView => 'Zastosuj';

  @override
  String get rowsLabel => 'Wiersze';

  @override
  String get fetchedRows => 'Pobrane wiersze';

  @override
  String get fixedSnapshot => 'Stała migawka pobranych wierszy';

  @override
  String get limitReached => 'Osiągnięto limit';

  @override
  String get retainedData => 'Zachowane dane';

  @override
  String get applyRequiresAutoCommit =>
      'Zastosowanie i zatwierdzenie wymaga bezczynnej sesji z automatycznym zatwierdzaniem.';

  @override
  String get connectionProfile => 'Profil połączenia';

  @override
  String get basic => 'Podstawowe';

  @override
  String get advanced => 'Zaawansowane';

  @override
  String get connectionName => 'Nazwa';

  @override
  String get hostname => 'Nazwa hosta (również do weryfikacji TLS)';

  @override
  String get port => 'Port';

  @override
  String get database => 'Baza danych';

  @override
  String get user => 'Użytkownik';

  @override
  String get password => 'Hasło';

  @override
  String get writableProfile => 'Profil z zapisem';

  @override
  String get readonlyProfile => 'Profil tylko do odczytu';

  @override
  String get tlsVerify => 'TLS: weryfikuj certyfikat i nazwę hosta';

  @override
  String get tlsInsecure => 'TLS: NIEBEZPIECZNE, bez weryfikacji';

  @override
  String get tlsDisabled => 'TLS: WYŁĄCZONE';

  @override
  String get testConnection => 'Testuj bez zapisywania';

  @override
  String get saveProfile => 'Zapisz';

  @override
  String get saveConnect => 'Zapisz i połącz';

  @override
  String get sessionPassword => 'Hasło tylko dla tej sesji';

  @override
  String get storedPassword =>
      'Przechowuj hasło w bezpiecznym magazynie systemu';

  @override
  String get chooseFile => 'Wybierz plik';

  @override
  String get testRunning => 'Testowanie połączenia…';

  @override
  String get cancelTest => 'Anuluj test';

  @override
  String get idle => 'Bezczynna';

  @override
  String get activeTransaction => 'Otwarta transakcja';

  @override
  String get failedTransaction => 'Nieudana transakcja';

  @override
  String get inspectionContext => 'Sesja inspekcji';

  @override
  String get requireTableOrView => 'Wybierz tabelę lub widok';

  @override
  String get operationPending => 'Operacja dokumentu oczekuje na potwierdzenie';

  @override
  String get requirePlan => 'Wybierz zachowane wykonanie Explain';

  @override
  String get openPlanDocument => 'Otwórz dokument planu';

  @override
  String get locks => 'Blokady';

  @override
  String get statistics => 'Statystyki';

  @override
  String get queryStatistics => 'Statystyki zapytań';

  @override
  String get indexDiagnostics => 'Diagnostyka indeksów';

  @override
  String get grants => 'Nadane uprawnienia';

  @override
  String get sqlExecution => 'Wykonanie SQL';

  @override
  String get planReady =>
      'Zachowany plan jest gotowy; SQL nie wykonano ponownie';

  @override
  String get executionPlan => 'Plan wykonania';

  @override
  String get openOwner => 'Otwórz właściciela';

  @override
  String get terminateActivity => 'Zakończ aktywność';

  @override
  String get close => 'Zamknij';

  @override
  String get previous => 'Poprzedni';

  @override
  String get next => 'Następny';

  @override
  String get replaceSelection => 'Zastąp zaznaczenie';

  @override
  String get replaceAll => 'Zastąp wszystko';

  @override
  String get restartBackend => 'Uruchom backend ponownie';

  @override
  String get structuredTree => 'Drzewo struktury';

  @override
  String get rawOutput => 'Surowy wynik';

  @override
  String get previousTextPage => 'Poprzednia strona tekstu';

  @override
  String get nextTextPage => 'Następna strona tekstu';

  @override
  String get filterChangedObjects => 'Filtruj zmienione obiekty';

  @override
  String get rebindVerifiedEdits => 'Przypisz ponownie zweryfikowane zmiany';

  @override
  String get discardRecoveryRecord => 'Odrzuć zapis odzyskiwania';

  @override
  String get revertChange => 'Cofnij oczekującą zmianę';

  @override
  String get chooseSource => 'Wybierz źródło';

  @override
  String get chooseDestination => 'Wybierz cel';

  @override
  String get delimiterField => 'Separator (jeden znak)';

  @override
  String get batchRowsField => 'Wiersze na partię (1–1000)';

  @override
  String get rejectedLimit => 'Limit odrzuconych wierszy (1–1000)';

  @override
  String get previewSource => 'Podgląd źródła';

  @override
  String get reviewTransfer => 'Przejrzyj transfer';

  @override
  String get startImport => 'Rozpocznij import';

  @override
  String get startRestore => 'Rozpocznij przywracanie';

  @override
  String get startExport => 'Rozpocznij eksport';

  @override
  String get requestCancel => 'Zażądaj anulowania';

  @override
  String get sourceMapping => 'Mapowanie źródła i celu';

  @override
  String get nativeTool => 'Narzędzie natywne';

  @override
  String get defaultOmit => 'Pomiń / domyślna wartość bazy';

  @override
  String get overwriteNever => 'Nie nadpisuj';

  @override
  String get overwriteExisting => 'Nadpisz istniejący plik';

  @override
  String get planDetails => 'Szczegóły planu';

  @override
  String get planMetricsNote =>
      'Szacunki i rzeczywiste pomiary używają nazw pól serwera. Brakujące pomiary są niedostępne.';

  @override
  String get connected => 'Połączono';

  @override
  String get disconnected => 'Rozłączono';

  @override
  String get tables => 'Tabele';

  @override
  String get views => 'Widoki';

  @override
  String get routines => 'Procedury';

  @override
  String get expand => 'Rozwiń';

  @override
  String get collapse => 'Zwiń';

  @override
  String get databaseWorkbench => 'Obszar pracy bazy danych';

  @override
  String get sidebar => 'Panel boczny';

  @override
  String get unchanged => 'Bez zmian';

  @override
  String get reviewDetails => 'Szczegóły przeglądu';

  @override
  String get generatedSql => 'Wygenerowany SQL';

  @override
  String get changeReverted => 'Cofnięto zmianę. Poproś o nowy przegląd.';

  @override
  String get unknownBatch =>
      'Wynik nieznany. Partia mogła zostać zatwierdzona. Nigdy nie powtarzaj jej automatycznie; sprawdź sesję i zapis odzyskiwania.';

  @override
  String get expiredChangeReview =>
      'Cel zmienił się lub przegląd wygasł. Poproś o nowy przegląd.';

  @override
  String get applyCommitExplanation =>
      'Zastosuj i zatwierdź rozpoczyna i zatwierdza własną transakcję. Konsola źródłowa musi być bezczynna z włączonym automatycznym zatwierdzaniem. Ręczne transakcje SQL rozwiąż osobno.';

  @override
  String get newRow => 'Nowy wiersz';

  @override
  String get original => 'Oryginał';

  @override
  String get proposed => 'Propozycja';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '$inserts wstawień · $updates aktualizacji · $deletes usunięć';
  }

  @override
  String sourceRow(String row) {
    return 'Wiersz źródłowy $row';
  }

  @override
  String get refreshing => 'Odświeżanie…';

  @override
  String get refreshActivities => 'Odśwież działania';

  @override
  String get explicitRefresh => 'Jawne odświeżanie';

  @override
  String get pollFiveSeconds => 'Odpytywanie co 5 sekund';

  @override
  String get cancelSelectedActivity => 'Anuluj wybrane działanie';

  @override
  String get terminateSelectedSession => 'Zakończ wybraną sesję';

  @override
  String get filterActivities => 'Filtruj bieżące działania';

  @override
  String get blockedBy => 'Blokowane przez:';

  @override
  String get delete => 'Usuń';

  @override
  String get remove => 'Usuń';

  @override
  String get up => 'Góra';

  @override
  String get search => 'Wyszukaj';

  @override
  String get yes => 'Tak';

  @override
  String get no => 'Nie';

  @override
  String get clear => 'Wyczyść';

  @override
  String get copy => 'Skopiuj';

  @override
  String get insert => 'Wstaw';

  @override
  String get update => 'Aktualizuj';

  @override
  String get open => 'Otwórz';

  @override
  String get migrationEngineMismatch =>
      'Połączenie docelowe musi używać tego samego silnika co porównywane migawki. Migracja między silnikami nie jest obsługiwana.';

  @override
  String get metadataContextChanged =>
      'Kontekst inspekcji uległ zmianie. Jawnie odśwież metadane.';

  @override
  String get newTableName => 'Nazwa nowej tabeli';

  @override
  String get routineIdentity => 'Dokładna tożsamość procedury';

  @override
  String get objectColumnName => 'Nazwa obiektu / kolumny';

  @override
  String get builtInType => 'Typ wbudowany';

  @override
  String get sqlExpression => 'Wyrażenie SQL (puste usuwa je)';

  @override
  String get newPropertyValue => 'Nowa wartość właściwości';

  @override
  String get columnComment => 'Komentarz kolumny';

  @override
  String get columnCollation =>
      'Porządek kolumny (pusty używa ustawienia serwera)';

  @override
  String get addDesignedColumn => 'Dodaj kolumnę do nowej tabeli';

  @override
  String get checkExpression => 'Wyrażenie CHECK';

  @override
  String get referencedSchema => 'Wskazany schemat / baza danych';

  @override
  String get generating => 'Generowanie…';

  @override
  String get generateReviewedDdl => 'Wygeneruj DDL do przeglądu';

  @override
  String get inspectCapturedDefinition => 'Sprawdź zapisane definicje';

  @override
  String get capturedObject => 'Zapisany obiekt';

  @override
  String get designReviewNote =>
      'Zmiany są generowane do przeglądu. Zawartość bazy nie zmienia się do zatwierdzonego wykonania.';

  @override
  String get columnMetadataUnavailable =>
      'Metadane kolumn nie są dostępne w tym zakresie; sprawdź wybrany schemat przed utworzeniem listy kolumn.';

  @override
  String get ordinaryColumn => 'Zwykła kolumna';

  @override
  String get columnWithDefault => 'Kolumna z wartością domyślną';

  @override
  String get identityColumn => 'Tożsamość / autoinkrementacja';

  @override
  String get generatedColumn => 'Kolumna generowana';

  @override
  String get columnType => 'Typ kolumny';

  @override
  String get nullableNotNull => 'Dopuszcza NULL / NOT NULL';

  @override
  String get defaultExpression => 'Wyrażenie domyślne';

  @override
  String get generatedExpression => 'Wyrażenie generowane';

  @override
  String get columnCollationProperty => 'Porządek kolumny';

  @override
  String get loggedUnlogged => 'Rejestrowana / nierejestrowana';

  @override
  String get tableComment => 'Komentarz tabeli';

  @override
  String get storageEngine => 'Silnik przechowywania';

  @override
  String get tableCollation => 'Porządek tabeli';

  @override
  String get rowFormat => 'Format wiersza';

  @override
  String get createOrReplace => 'Utwórz lub zastąp';

  @override
  String get dropSelectedObject => 'Usuń wybrany obiekt';

  @override
  String get addColumn => 'Dodaj kolumnę';

  @override
  String get editColumnProperties => 'Edytuj właściwości kolumny';

  @override
  String get tableProperties => 'Właściwości tabeli';

  @override
  String get triggerDefinition => 'Definicja wyzwalacza';

  @override
  String get createTable => 'Utwórz tabelę';

  @override
  String get viewDefinition => 'Definicja widoku';

  @override
  String get routineDefinition => 'Definicja procedury';

  @override
  String get chooseExistingObject => 'Wybierz istniejący obiekt';

  @override
  String get nullable => 'Dopuszcza NULL';

  @override
  String get removeIdentity => 'Usuń tożsamość';

  @override
  String get generatedAlways => 'Generowane zawsze';

  @override
  String get generatedByDefault => 'Generowane domyślnie / autoinkrementacja';

  @override
  String get loggedTable => 'Tabela rejestrowana';

  @override
  String get unloggedTable => 'Tabela nierejestrowana';

  @override
  String get orderedPrimaryKeyColumns =>
      'Uporządkowane kolumny klucza głównego';

  @override
  String get orderedColumns => 'Uporządkowane kolumny';

  @override
  String get ordinaryIndex => 'Zwykły indeks';

  @override
  String get uniqueIndex => 'Indeks unikalny';

  @override
  String get primaryKey => 'Klucz główny';

  @override
  String get uniqueConstraint => 'Ograniczenie unikalności';

  @override
  String get foreignKey => 'Klucz obcy';

  @override
  String get checkConstraint => 'Ograniczenie CHECK';

  @override
  String get immediateChecking => 'Sprawdzanie natychmiastowe';

  @override
  String get deferrableChecking => 'Sprawdzanie odraczalne';

  @override
  String get initiallyImmediate => 'Początkowo natychmiastowe';

  @override
  String get initiallyDeferred => 'Początkowo odroczone';

  @override
  String get referencedTable => 'Wskazana tabela';

  @override
  String get orderedReferencedColumns =>
      'Wskazane kolumny w odpowiadającej kolejności';

  @override
  String get objectDefinitionEditor => 'Edytor SQL natywnej definicji obiektu';

  @override
  String get onDelete => 'Przy usuwaniu';

  @override
  String get onUpdate => 'Przy aktualizacji';

  @override
  String get stay => 'Zostań';

  @override
  String get saveSqlClose => 'Zapisz SQL i zamknij';

  @override
  String get discardSqlClose => 'Odrzuć SQL i zamknij';

  @override
  String get closeBusyData => 'Zamknij BusyData';

  @override
  String get saveDraftsClose => 'Zapisz szkice i zamknij';

  @override
  String get closeWithoutRecovery => 'Zamknij bez odzyskiwania';

  @override
  String get recoveryFailed => 'Odzyskiwanie nie powiodło się';

  @override
  String get discardFailedSaveClose => 'Odrzuć nieudany zapis i zamknij';

  @override
  String get closeWithoutSavingRecovery =>
      'Zamknij bez zapisywania odzyskiwania';

  @override
  String get disableSqlRecovery => 'Wyłącz odzyskiwanie SQL';

  @override
  String get historyPrivacy => 'Prywatność historii';

  @override
  String get enableSqlRetention => 'Włącz przechowywanie SQL';

  @override
  String get disableSqlRetention => 'Wyłącz przechowywanie SQL';

  @override
  String get clearHistory => 'Wyczyść historię';

  @override
  String get deleteHistoryEntry => 'Usuń wpis historii';

  @override
  String get deleteSelected => 'Usuń zaznaczone';

  @override
  String get saveRetention => 'Zapisz przechowywanie';

  @override
  String get retentionDays => 'Dni przechowywania';

  @override
  String get sqlTextRetained => 'Tekst SQL przechowywany';

  @override
  String get sqlTextDisabled => 'Tekst SQL wyłączony';

  @override
  String get openHistoryQuery => 'Otwórz w nowej karcie SQL';

  @override
  String get caCertificateFile => 'Plik certyfikatu CA';

  @override
  String get clientCertificateFile => 'Plik certyfikatu klienta';

  @override
  String get clientKeyFile => 'Plik klucza klienta';

  @override
  String get directConnection => 'Połączenie bezpośrednie';

  @override
  String get sshTunnel => 'Tunel SSH';

  @override
  String get sshHost => 'Host SSH';

  @override
  String get sshPort => 'Port SSH';

  @override
  String get sshUser => 'Użytkownik SSH';

  @override
  String get reviewedKnownHosts => 'Zweryfikowany plik known_hosts';

  @override
  String get reviewSshKey => 'Sprawdź klucz hosta SSH';

  @override
  String get changedSshKey => 'Zmieniony klucz hosta SSH';

  @override
  String get verifyFingerprint =>
      'Zweryfikuj ten odcisk niezależnie, zanim mu zaufasz.';

  @override
  String get selectedKeyPassword => 'Wybrany klucz lub hasło';

  @override
  String get selectedAgentIdentity => 'Wybrana tożsamość agenta SSH';

  @override
  String get selectedAgentSocket =>
      'Wybrane gniazdo agenta Linux / nazwany potok Windows';

  @override
  String get selectedKeyFingerprint => 'Odcisk wybranego klucza · SHA256:…';

  @override
  String get selectedPrivateKey => 'Wybrany klucz prywatny (opcjonalnie)';

  @override
  String get sshPassword => 'Hasło SSH';

  @override
  String get keyPassphrase => 'Hasło klucza';

  @override
  String get connectionTimeout => 'Limit czasu połączenia · 1–120 sekund';

  @override
  String get sqlTimeout =>
      'Limit wykonania/odczytu SQL · 1–3600 sekund (0 = 60)';

  @override
  String get schemasEquivalent => 'Zarejestrowane schematy są równoważne.';

  @override
  String get migrationComplete =>
      'Migracja obejmuje obsługiwane różnice migawek.';

  @override
  String get migrationPartial =>
      'Migracja częściowa; pozostają nieobsługiwane różnice.';

  @override
  String get differencesLimited =>
      'Prezentacja różnic jest ograniczona. Sprawdź pełne zapisane migawki i wygenerowany SQL.';

  @override
  String get absent => 'Brak';

  @override
  String get definitionPreviewLimited =>
      'Podgląd definicji jest ograniczony; pełne dane zawiera oryginalna migawka.';

  @override
  String get migrationBatchNote =>
      'SQL to jeden pakiet uporządkowany według zależności. Wybór obiektu służy do inspekcji i nie wybiera instrukcji do zastosowania.';

  @override
  String get unsupportedLabel => 'Nieobsługiwane';

  @override
  String get differenceAdded => 'Dodano';

  @override
  String get differenceRemoved => 'Usunięto';

  @override
  String get differenceChanged => 'Zmieniono';

  @override
  String get selectHistoryEntry => 'Wybierz wpis historii';

  @override
  String get searchSqlTarget => 'Szukaj SQL lub celu';

  @override
  String get closeSqlTab => 'Zamknij kartę SQL';

  @override
  String get historyMetadataRetained =>
      'Metadane stanu i celu pozostają w historii.';

  @override
  String get historyPreviewNote =>
      'Tylko podgląd. Otwórz w nowej karcie SQL, aby pobrać zachowany tekst.';

  @override
  String get selected => 'Wybrane';

  @override
  String get authReviewNote =>
      'Przed zastosowaniem sprawdź dokładnego użytkownika lub rolę i cel. Dane logowania nigdy nie trafiają do dokumentów SQL ani historii. Istniejące połączenia i zapisane hasła pozostają oddzielne.';

  @override
  String get createLogin => 'Utwórz konto logowania';

  @override
  String get createRole => 'Utwórz rolę bez logowania';

  @override
  String get setPassword => 'Ustaw hasło';

  @override
  String get preventLogin => 'Zablokuj nowe logowania';

  @override
  String get allowLogin => 'Zezwól na nowe logowania';

  @override
  String get dropPrincipal => 'Usuń użytkownika lub rolę';

  @override
  String get principalName => 'Dokładna nazwa użytkownika lub roli';

  @override
  String get accountHost =>
      'Dokładny host konta (symbole wieloznaczne rozszerzają logowanie)';

  @override
  String get newPassword => 'Nowe hasło';

  @override
  String get repeatPassword => 'Powtórz nowe hasło';

  @override
  String get reviewAccount => 'Sprawdź operację konta';

  @override
  String get passwordsMismatch => 'Wpisz dwukrotnie to samo niepuste hasło';

  @override
  String get accountSubmitFailed =>
      'Nie można wysłać operacji konta. Sprawdź cel, zasady uwierzytelniania i uprawnienia bazy danych.';

  @override
  String get privilegeReviewNote =>
      'Sprawdź bezpośrednie uprawnienia; wygenerowany SQL nadal wymaga przeglądu wykonania.';

  @override
  String get inspectionLimited =>
      'Limit 500 wierszy na sekcję. Zawęź wyszukiwanie; pusta sekcja nie dowodzi braku skutecznego dostępu.';

  @override
  String get findPrincipal => 'Znajdź nazwę użytkownika / roli';

  @override
  String get searchPrincipals => 'Szukaj użytkowników i ról';

  @override
  String get choosePrincipal => 'Wybierz użytkownika lub rolę';

  @override
  String get inspectGrants => 'Sprawdź wybrane uprawnienia';

  @override
  String get tablePrivileges => 'Uprawnienia tabeli / widoku';

  @override
  String get schemaPrivileges => 'Uprawnienia schematu';

  @override
  String get databasePrivileges => 'Uprawnienia bazy danych';

  @override
  String get roleMembership => 'Członkostwo w roli';

  @override
  String get defaultRole => 'Aktywacja domyślnej roli';

  @override
  String get chooseGrantRole => 'Wybierz rolę do nadania / odebrania';

  @override
  String get tableView => 'Tabela / widok';

  @override
  String get explicitPrivileges =>
      'Jawne uprawnienia (rozdzielone przecinkami)';

  @override
  String get setDefaultRole => 'Ustaw wybraną rolę domyślną';

  @override
  String get clearDefaultRole => 'Usuń rolę domyślną';

  @override
  String get grantAccess => 'Przyznaj dostęp';

  @override
  String get revokeAccess => 'Odbierz dostęp';

  @override
  String get withoutDelegation => 'Bez delegowania';

  @override
  String get allowDelegation => 'Zezwól odbiorcy nadawać prawa innym';

  @override
  String get readonlyChanges =>
      'Ten profil jest tylko do odczytu. Zmiany wymagają sesji z wyraźnym zezwoleniem na zapis.';

  @override
  String get createPrincipal => 'Utwórz użytkownika / rolę';

  @override
  String get manageAuthentication => 'Zarządzaj wybranym uwierzytelnianiem';

  @override
  String get openPrivilegeSql => 'Otwórz SQL uprawnień do przeglądu';

  @override
  String get inspectPrincipalFirst =>
      'Sprawdź wybranego użytkownika lub rolę przed przygotowaniem zmiany';

  @override
  String get accountAuthentication => 'Uwierzytelnianie konta';

  @override
  String get schema => 'Schemat';

  @override
  String get available => 'Dostępne';

  @override
  String get availableEmpty => 'Dostępne · puste dane';

  @override
  String get limitedVisibility => 'Ograniczona widoczność lub zakres';

  @override
  String get permissionDenied => 'Brak uprawnień';

  @override
  String get unavailable => 'Niedostępne';

  @override
  String get profileDisabled => 'Wyłączone przez profil';

  @override
  String get unknownState => 'Nieznane';

  @override
  String get inspecting => 'Sprawdzanie…';

  @override
  String get refreshCapabilities => 'Odśwież możliwości';

  @override
  String get staleRefresh => 'Nieaktualne · odśwież po połączeniu';

  @override
  String get staleContext =>
      'Nieaktualne · odśwież po połączeniu lub zmianie kontekstu';

  @override
  String get partialTreeLimit =>
      'Częściowe · osiągnięto limit drzewa; zawęź przez wyszukiwanie obiektów';

  @override
  String get schemaComparison => 'Porównanie schematów';

  @override
  String get searchTable => 'Szukaj tabeli';

  @override
  String get focusObject => 'Ustaw fokus';

  @override
  String get exportSvg => 'Eksportuj SVG';

  @override
  String get exportPng => 'Eksportuj PNG';

  @override
  String get diagramNotes => 'Notatki diagramu (zawarte w SVG)';

  @override
  String get openNotes => 'Otwórz notatki';

  @override
  String get saveNotes => 'Zapisz notatki';

  @override
  String get newSnippet => 'Nowy fragment';

  @override
  String get snippetName => 'Nazwa fragmentu';

  @override
  String get saveSnippet => 'Zapisz fragment';

  @override
  String get deleteSnippet => 'Usuń zapisany fragment';

  @override
  String get insertSnippet => 'Wstaw do dokumentu SQL';

  @override
  String get snippetEditor => 'Edytor fragmentów SQL';

  @override
  String get snippetsNote =>
      'Wstaw zapisany lokalny SQL do wskazanego dokumentu z cofaniem. Wykonanie pozostaje jawne.';

  @override
  String get level => 'Poziom';

  @override
  String get expanded => 'rozwinięte';

  @override
  String get collapsed => 'zwinięte';

  @override
  String get treeLevel => 'Poziom';

  @override
  String get retainedView => 'Zachowany widok';

  @override
  String get tableQuerySnapshot => 'Migawka zapytania tabeli';

  @override
  String get originalResultNote =>
      'Oryginalny zachowany wynik; stronicowanie i inspekcja nie wykonują SQL';

  @override
  String get tableFilterNote =>
      'Zastosowanie wysyła nowe sprawdzone zapytanie. Poprzednia migawka pozostaje dostępna.';

  @override
  String get retainedFilterNote =>
      'Wszystkie pobrane wiersze w stałej migawce. SQL nie jest ponawiany. Kolejność może różnić się od sortowania bazy.';

  @override
  String get retainedRowNote =>
      'Wybierz wiersz już pobranego wyniku. SQL nie jest ponawiany.';

  @override
  String get copyLimitNote =>
      'Kopiowanie ograniczone do 10 000 komórek; większe zakresy eksportuj jako zachowane dane.';

  @override
  String get inlineValueLimit => 'Edycja w komórce obsługuje wartości do 8KiB';

  @override
  String get editContextChanged =>
      'Sesja źródłowa lub kontekst edycji zmienił się; sprawdź lub odśwież ocenę przed przygotowaniem zmian';

  @override
  String get editAssessmentUnavailable =>
      'Edycja niedostępna; odśwież ocenę po przejściu sesji w stan bezczynny';

  @override
  String get rowChangeReverted =>
      'Cofnięto oczekującą zmianę wiersza; baza bez zmian';

  @override
  String get sqlCopyRequiresMetadata =>
      'Kopia SQL wymaga backendu i zachowanych metadanych typów.';

  @override
  String get exportFullValue => 'Eksportuj pełną zachowaną wartość';

  @override
  String valueExportReview(String bytes, String path) {
    return 'Zapisać $bytes bajtów do $path? Istniejąca zawartość zostanie zastąpiona. SQL nie jest ponawiany.';
  }

  @override
  String get goToRetainedRow => 'Przejdź do zachowanego wiersza';

  @override
  String get row => 'Wiersz';

  @override
  String get go => 'Przejdź';

  @override
  String get retryRows => 'Ponów zachowane wiersze';

  @override
  String get previousRows => 'Poprzednie wiersze';

  @override
  String get nextRows => 'Następne wiersze';

  @override
  String get firstWindow => 'Pierwsze zachowane okno';

  @override
  String get lastWindow => 'Ostatnie pobrane okno';

  @override
  String get setNull => 'Ustaw NULL';

  @override
  String copyFormat(String format) {
    return 'Kopiuj $format';
  }

  @override
  String get textValue => 'Tekst';

  @override
  String get sqlValues => 'Wartości SQL';

  @override
  String get rowSelection => 'Wybór wierszy';

  @override
  String selectRow(String row) {
    return 'Wybierz wiersz $row';
  }

  @override
  String columnHeader(String column) {
    return 'Kolumna $column';
  }

  @override
  String get pendingChange => 'oczekująca zmiana';

  @override
  String get readonlyCell => 'Komórka tylko do odczytu';

  @override
  String get editableCell => 'Komórka edytowalna';

  @override
  String get loadValueFirst => 'Najpierw wczytaj tę zachowaną wartość';

  @override
  String get editUnavailable => 'Edycja niedostępna';

  @override
  String get editCell => 'Edytuj komórkę';

  @override
  String get unsupportedEditValue =>
      'Ta zachowana wartość pozwala tylko na inspekcję';

  @override
  String bytesCount(String bytes) {
    return '$bytes bajtów';
  }

  @override
  String get problems => 'Problemy';

  @override
  String get ownedSessions => 'Własne sesje';

  @override
  String get noProblems => 'Brak zarejestrowanych problemów';

  @override
  String get duplicateConnection => 'Powiel połączenie';

  @override
  String get deleteConnection => 'Usuń połączenie';

  @override
  String deleteConnectionReview(String name) {
    return 'Usunąć $name? Istniejące fizyczne sesje zachowają pierwotne ustawienia.';
  }

  @override
  String get unresolvedSessions => 'Nierozwiązane sesje';

  @override
  String get disconnectSessionNote =>
      'Najpierw rozwiąż aktywne zadania i transakcje. Rozłączenie dotyczy wszystkich klientów tej fizycznej sesji; nie zatwierdza ani nie ponawia SQL. Nieznane wyniki pozostają nieznane.';

  @override
  String get transferSettingsChanged =>
      'Zmieniono ustawienia; sprawdź ponownie';

  @override
  String get transferReviewReady =>
      'Przegląd gotowy · sprawdź cel, zakres, mapowanie i plik';

  @override
  String get sourcePreviewNotice =>
      'Podgląd źródła · nie zaimportowano wierszy';

  @override
  String get transferRequiresReview =>
      'Najpierw przejrzyj dokładnie ten transfer';

  @override
  String get transferSubmittedNotice =>
      'Wysłano · anulowanie nie cofa zatwierdzeń ani opublikowanych plików';

  @override
  String get sqlExportExecutionNote => 'Nowe sprawdzone wykonanie SQL';

  @override
  String get retainedExportSnapshotNote =>
      'Pobrana migawka; SQL nie jest wykonywany';

  @override
  String get restorePartialCommitNote =>
      'Przywracanie może częściowo zatwierdzić. Anulowanie go nie cofa.';

  @override
  String get sourcePreviewLimit => 'Podgląd źródła · do 20 wierszy';

  @override
  String get importBatchSafetyNote =>
      'Błędy i anulowanie zachowują wcześniejsze zatwierdzenia. Skróty i niezmienne źródło są sprawdzane przed wysłaniem.';

  @override
  String get nullMarkerLiteralNote =>
      'Znacznik NULL bez cudzysłowu; w cudzysłowie to dosłowny tekst';

  @override
  String immutableSourceHash(String hash) {
    return 'SHA-256 niezmiennego źródła: $hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return 'Kolumna źródłowa $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return 'Wiersz podglądu $row, $column: $value';
  }

  @override
  String get transferCancellationNotice =>
      'Zażądano anulowania · oczekuj potwierdzenia';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed przetworzonych · $committed zatwierdzonych · $rejected odrzuconych';
  }

  @override
  String get importAtomicPolicy => 'Wszystkie wiersze w jednej transakcji';

  @override
  String get importBatchPolicy => 'Zatwierdzaj partie; zatrzymaj przy błędzie';

  @override
  String get importSkipPolicy =>
      'Pomijaj nieprawidłowe wiersze; zatwierdzaj partie';

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
    return 'Potwierdzenia/połączenia: $operations\nNiezapisane dokumenty: $documents\nZapisy w toku: $saves\nZmiany w kolejce: $edits\nAktywne zadania: $jobs\nTransakcje do rozwiązania: $transactions\nNieznane wyniki: $unknown\nNiepewne sesje: $sessions';
  }

  @override
  String get closeDraftSaved => 'Szkice SQL zostaną zapisane lokalnie.';

  @override
  String get closeDraftLost =>
      'Odzyskiwanie wyłączone; niezapisane SQL i projekty obiektów zostaną utracone.';

  @override
  String get closeDesignRecovery =>
      'Projekty używają prywatnego ograniczonego odzyskiwania. Po otwarciu jawnie połącz i sprawdź metadane.';

  @override
  String get closeCleanupReview =>
      'Zamknięcie ostatniego właściciela żąda anulowania, wycofuje potwierdzone transakcje i rozłącza. Nieznane wyniki pozostają nieznane; SQL nie jest zatwierdzany ani ponawiany.';

  @override
  String get closeSharedSession =>
      'Inni klienci zachowują współdzieloną sesję fizyczną.';

  @override
  String get closeStagedRecovery =>
      'Zmiany wymagają potwierdzonego prywatnego odzyskiwania, jawnego połączenia i nowego przeglądu.';

  @override
  String get closeRecoveryLoss =>
      'Dokumenty i układ niezapisane. Zamknięcie może utracić SQL i zmiany; istniejące pliki i odzyskiwanie pozostają.';

  @override
  String get closeWaitNotice =>
      'Przed zamknięciem poczekaj na potwierdzenia i czyszczenie połączeń.';

  @override
  String get saveFailedNotice =>
      'Zapis SQL nie powiódł się. Zachowaj zmieniony tekst lub jawnie go odrzuć.';

  @override
  String get closeCleanupFailed =>
      'Czyszczenie backendu nie powiodło się; BusyData pozostaje otwarty.';

  @override
  String get closeBackendUnverified =>
      'Stan backendu niezweryfikowany; zadania mogą nadal trwać.';

  @override
  String historyRetainSqlReview(String days) {
    return 'SQL może zawierać sekrety. Przechowywać tekst przez $days dni?';
  }

  @override
  String get historyStopSqlReview =>
      'Zatrzymać przechowywanie SQL i usunąć go z wcześniejszej historii?';

  @override
  String get historyClearReview =>
      'Usunąć całą historię? Aktywne zadania mogą zapisać wynik po zakończeniu.';

  @override
  String get historyDeleteReview => 'Usunąć wybrany wpis?';

  @override
  String get historyRetentionRange => 'Przechowywanie musi wynosić 1–3650 dni';

  @override
  String get enableSqlHistory => 'Włącz historię SQL';

  @override
  String get stopSqlHistory => 'Zatrzymaj przechowywanie SQL';

  @override
  String get recoveryDiscardReview =>
      'Odrzucić odzyskiwanie? Najpierw rozwiąż nieznane wyniki; odrzucenie nie cofa zatwierdzeń.';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return 'Niezapisane SQL: $unsaved\nZmiany: $edits\nAktywne zadania: $jobs';
  }

  @override
  String get recoveryStayOpen =>
      'Odzyskiwanie nie powiodło się. BusyData pozostaje otwarty; niezapisana praca jest zachowana.';

  @override
  String get commitUncertaintyNote =>
      'Błąd sieci może pozostawić wynik zatwierdzenia nieznany. Nigdy nie ponawiaj automatycznie.';

  @override
  String get closeObjectDesignDiscard =>
      'Niezapisane pola projektu zostaną odrzucone. Najpierw wygeneruj i zapisz SQL, aby zachować projekt.';

  @override
  String get savePrivateDrafts => 'Zapisuj prywatne szkice odzyskiwania';

  @override
  String get noPrivateDrafts => 'Nie zapisuj szkiców odzyskiwania';

  @override
  String shortcutField(String command) {
    return 'Skrót $command';
  }

  @override
  String get shortcutInvalid =>
      'Użyj poprawnego skrótu nieprzypisanego do innej akcji. F6 i Shift+F6 są zarezerwowane.';

  @override
  String get disableRecoveryReview =>
      'Usunąć lokalne odzyskiwanie SQL, projektów i zmian? Niezapisana praca pozostaje otwarta; awaria może ją utracić. Najpierw rozwiąż nieznane wyniki.';

  @override
  String get preferencesSaved => 'Ustawienia zapisane';

  @override
  String get sharingSessionReview =>
      'Zapytanie dzieli nazwaną fizyczną sesję, transakcję, obiekty tymczasowe i ustawienia z wymienionymi klientami. Zamknięcie jednego zachowuje pozostałych.';

  @override
  String get recoveryReconcileFirst =>
      'Rozwiąż trwające lub nieznane zmiany przed wyłączeniem odzyskiwania. Odrzucaj rekordy wyłącznie po ich jawnym przeglądzie.';

  @override
  String get enterSearchText => 'Wpisz tekst wyszukiwania';

  @override
  String get noSearchMatches => 'Brak dopasowań';

  @override
  String searchMatchCount(String position, String total) {
    return 'Dopasowanie $position z $total';
  }

  @override
  String get formatSqlChanged =>
      'SQL lub cel zmienił się. Oryginalny SQL zachowany; poproś o nowy podgląd formatowania.';

  @override
  String get formatSqlUnavailable =>
      'Formatowanie niedostępne dla niepełnej lub nieobsługiwanej składni albo limitów analizy. Oryginalny SQL zachowany.';

  @override
  String get stageChange => 'Przygotuj zmianę';

  @override
  String pendingChangesCount(String count) {
    return '$count oczekujących zmian; baza bez zmian do sprawdzonego zastosowania.';
  }

  @override
  String discardChangesCount(String count) {
    return 'Odrzucić $count oczekujących zmian? Nie jest wysyłana operacja bazy danych.';
  }

  @override
  String get recoveryNoExecution =>
      'Odzyskiwanie nie łączy, nie wykonuje źródłowego SQL, nie wznawia transakcji i nie powtarza zmian. Nie można ponownie stosować rekordów nieznanych lub zatwierdzonych.';

  @override
  String get recoveredDesign =>
      'Projekt odzyskany. Jawnie połącz i sprawdź bieżące metadane przed nową weryfikacją. Przywracanie nie pobrało SQL ani metadanych.';

  @override
  String get retainedUnavailable =>
      'Zachowane dane niedostępne. Zapisany SQL i prywatne odzyskiwanie pozostają lokalnie.';

  @override
  String get activityFingerprintNote =>
      'Odcisk wybranej aktywności jest ponownie sprawdzany przed wysłaniem. Wynik zapisu może być nieznany.';

  @override
  String replaceFileReview(String path) {
    return 'Zastąpić sprawdzony plik w $path? Zmieniony cel wymaga nowej weryfikacji.';
  }

  @override
  String get diagramPngSaved =>
      'PNG diagramu zapisany. Długie notatki pokazują do sześciu wierszy.';

  @override
  String get editTargetChanged =>
      'Cel edycji zmienił się. Otwórz ponownie edytor wiersza przed przygotowaniem.';

  @override
  String affectedRowCount(String count) {
    return 'Zmienione wiersze: $count';
  }

  @override
  String get zoomIn => 'Powiększ';

  @override
  String get zoomOut => 'Pomniejsz';

  @override
  String get resetView => 'Resetuj widok';

  @override
  String get diagramKeys =>
      'Strzałki przesuwają; + i - zmieniają powiększenie; Home resetuje widok.';

  @override
  String get explorerConnected => 'Eksplorator połączony';

  @override
  String get explorerDisconnected => 'Eksplorator rozłączony';

  @override
  String querySessionCount(String count) {
    return 'Sesje zapytań $count';
  }

  @override
  String get metadataColumn => 'Kolumna';

  @override
  String get metadataPosition => 'Pozycja';

  @override
  String get metadataUnique => 'Unikatowy';

  @override
  String get metadataJdbcType => 'Typ JDBC';

  @override
  String get metadataAutoIncrement => 'Automatyczne zwiększanie';

  @override
  String get metadataReferencedColumn => 'Kolumna wskazywana';

  @override
  String get metadataComment => 'Komentarz';

  @override
  String get metadataType => 'Typ';

  @override
  String get metadataEvent => 'Zdarzenie';

  @override
  String get metadataSpecificName => 'Natywny identyfikator szczegółowy';

  @override
  String get metadataOptions => 'Opcje';

  @override
  String get metadataInheritance => 'Dziedziczenie';

  @override
  String get metadataDefinitionCaptured => 'Zapisana definicja natywna';

  @override
  String get metadataDefinitionUnavailable =>
      'Definicja niedostępna w zapisanych metadanych';

  @override
  String get metadataDefinitionUnsupported =>
      'Zapisany obiekt nie ma obsługiwanej definicji natywnej';

  @override
  String get connections => 'Połączenia';

  @override
  String get noConnections => 'Brak połączeń';

  @override
  String get startTitle => 'Połącz z bazą danych';

  @override
  String get startDescription =>
      'Połącz z PostgreSQL, MySQL lub MariaDB, aby przeglądać obiekty, zarządzać danymi i wykonywać zapytania.';

  @override
  String get savedStartTitle => 'Wybierz połączenie';

  @override
  String get savedStartDescription =>
      'Połącz z zapisanym połączeniem w eksploratorze, aby przeglądać obiekty i wykonywać zapytania.';

  @override
  String get noConnection => 'Brak połączenia';

  @override
  String queryTitle(int number) {
    return 'Zapytanie $number';
  }

  @override
  String get sessionMenu => 'Sesja';

  @override
  String get noFilterMatches =>
      'Brak pasujących połączeń lub załadowanych obiektów';

  @override
  String get activityState => 'Stan';

  @override
  String get activityWait => 'Oczekiwanie';

  @override
  String get generalSettings => 'Ogólne';

  @override
  String get optionsSettings => 'Opcje';

  @override
  String get host => 'Host';

  @override
  String get databaseSystem => 'System bazy danych';

  @override
  String get passwordStorage => 'Przechowywanie hasła';

  @override
  String get environmentLabel => 'Środowisko';

  @override
  String get readOnlySettings => 'Zasady tylko do odczytu';

  @override
  String get tlsPolicy => 'Zasady TLS';

  @override
  String get sshConnection => 'Połączenie SSH';

  @override
  String get sshAuthentication => 'Uwierzytelnianie SSH';

  @override
  String get connectionTestAction => 'Testuj połączenie';

  @override
  String get details => 'Szczegóły';

  @override
  String get copyDetails => 'Kopiuj szczegóły';

  @override
  String get retry => 'Ponów';

  @override
  String get filterCellValue => 'Filtruj według tej wartości';

  @override
  String get connectsWhenRun => 'Łączy przy wykonaniu';

  @override
  String get connectionSaving => 'Zapisz…';

  @override
  String get connectionConnecting => 'Połącz…';

  @override
  String get connectionCancelling => 'Anuluj…';

  @override
  String get connectionSettingsChanged =>
      'Ustawienia zmieniono. Przetestuj tę wersję ponownie.';

  @override
  String get connectionTestChanged =>
      'Ustawienia zmieniono. Przetestuj tę wersję ponownie.';

  @override
  String get connectionRequired => 'Wymagane';

  @override
  String get connectionCorrectFields => 'Sprawdź wskazane ustawienia.';

  @override
  String get connectionHostname => 'Host · Sprawdź wskazane ustawienia.';

  @override
  String get connectionSshHostname =>
      'SSH · Host · Sprawdź wskazane ustawienia.';

  @override
  String get connectionMaxLength => 'Nazwa ≤ 256';

  @override
  String get connectionTlsHelp =>
      'TLS · Host · SSH/SSL. Sprawdź wskazane ustawienia.';

  @override
  String get connectionTlsReview =>
      'TLS · Host · SSH/SSL. Sprawdź wskazane ustawienia.';

  @override
  String get connectionStorageUnavailable =>
      'Przechowywanie hasła: Niedostępne. Hasło · Nigdy.';

  @override
  String get connectionHostReviewed =>
      'Host · Zaufanie dotyczy tylko tego profilu i dokładnego punktu docelowego.';

  @override
  String get connectionSshReviewing => 'SSH · Sprawdź klucz hosta SSH…';

  @override
  String get connectionFailureAuthentication =>
      'Niepowodzenie · Uwierzytelnianie · Ogólne. Sprawdź wskazane ustawienia.';

  @override
  String get connectionFailureTls =>
      'Niepowodzenie · TLS · SSH/SSL. Sprawdź wskazane ustawienia.';

  @override
  String get connectionFailureSshKey =>
      'Niepowodzenie · Sprawdź klucz hosta SSH. Sprawdź wskazane ustawienia.';

  @override
  String get connectionFailureEndpoint =>
      'Niepowodzenie · Host · Port. Sprawdź wskazane ustawienia.';

  @override
  String get connectionFailureCancelled => 'Anulowano';

  @override
  String get connectionFailureSettings =>
      'Niepowodzenie · Ogólne. Sprawdź wskazane ustawienia.';

  @override
  String get connectionFailureAccess =>
      'Niepowodzenie · Uprawnienia tabeli / widoku. Sprawdź wskazane ustawienia.';

  @override
  String get connectionFailureUnavailable =>
      'Niepowodzenie · Host · TLS · SSH. Sprawdź wskazane ustawienia.';

  @override
  String get connectionFailureTimeout =>
      'Niepowodzenie · Limit czasu połączenia · 1–120 sekund. Sprawdź wskazane ustawienia.';

  @override
  String get connectionFailureUnknown =>
      'Niepowodzenie · Ogólne · TLS · SSH. Sprawdź wskazane ustawienia.';

  @override
  String connectionNumber(int min, int max) {
    return 'Wprowadź liczbę całkowitą od $min do $max';
  }

  @override
  String connectionSavedFailure(String name) {
    return 'Połączenie zapisane: $name. Próba połączenia nie powiodła się. ';
  }

  @override
  String get backendBusy =>
      'Usługa jest zajęta. Poczekaj na bieżące żądanie i spróbuj ponownie.';

  @override
  String rpcRequestUnconfirmed(String code) {
    return 'Żądanie nie zostało potwierdzone (RPC $code).';
  }

  @override
  String get operationUnconfirmed => 'Nie udało się ukończyć operacji.';

  @override
  String get connectionFailureTlsMaterial =>
      'Materiał TLS jest niedostępny lub nieprawidłowy. Sprawdź źródła zaufania i klucz klienta w SSH/SSL.';

  @override
  String get managerTitle => 'Źródła danych i sterowniki';

  @override
  String get sourceListTitle => 'Źródła danych';

  @override
  String get driverLabel => 'Sterownik';

  @override
  String get connectionTypeLabel => 'Typ połączenia';

  @override
  String get defaultTcp => 'Domyślny (TCP)';

  @override
  String get authenticationLabel => 'Uwierzytelnianie';

  @override
  String get userPasswordAuth => 'Użytkownik i hasło';

  @override
  String get neverStorage => 'Nigdy';

  @override
  String get initialDatabaseLabel => 'Początkowa baza danych';

  @override
  String get useSshTunnel => 'Użyj tunelu SSH';

  @override
  String get sshConfigurationLabel => 'Konfiguracja SSH';

  @override
  String get createSshConfig => '<utwórz konfigurację>';

  @override
  String get copySshSettings => 'Kopiuj ustawienia SSH';

  @override
  String get localPortLabel => 'Port lokalny';

  @override
  String get dynamicPortLabel => '<Dynamiczny>';

  @override
  String get useSsl => 'Użyj SSL';

  @override
  String get useTruststore => 'Użyj magazynu zaufania';

  @override
  String get clientKeyPasswordLabel => 'Hasło klucza klienta';

  @override
  String get modeLabel => 'Tryb';

  @override
  String get requireTls => 'Wymagaj';

  @override
  String get verifyCa => 'Weryfikuj CA';

  @override
  String get fullVerification => 'Pełna weryfikacja';

  @override
  String get connectionSection => 'Połączenie';

  @override
  String get configurationApplied => 'Konfiguracja zastosowana';

  @override
  String get noOtherSshConfig => 'Inne źródła nie mają konfiguracji SSH.';

  @override
  String get generatedUrlHelp => 'Wygenerowany adres JDBC tylko do odczytu.';

  @override
  String get tlsDriverDefaultHelp =>
      'SSL nie jest skonfigurowany; dołączony sterownik używa wartości domyślnej.';

  @override
  String get tlsClientKeyHelp =>
      'Klucze PEM: PKCS#8 lub OpenSSL; zaszyfrowane lub niezaszyfrowane.';

  @override
  String get legacyMariaTrustHelp =>
      'Istniejąca weryfikacja sterownika jest zachowana. Wybierz źródła zaufania, aby określić certyfikaty główne.';

  @override
  String get metadataStartValue => 'Wartość początkowa';

  @override
  String get metadataMinimumValue => 'Wartość minimalna';

  @override
  String get metadataMaximumValue => 'Wartość maksymalna';

  @override
  String get metadataIncrement => 'Przyrost';

  @override
  String get metadataCycle => 'Cykliczna';

  @override
  String get metadataCacheSize => 'Rozmiar pamięci podręcznej';

  @override
  String get metadataLastValue => 'Ostatnia wartość';

  @override
  String get sequences => 'Sekwencje';

  @override
  String get namespaceSelection => 'Wybierz przestrzenie nazw';

  @override
  String get namespaceSelectionNotice =>
      'Wybór steruje introspekcją. Konsole zachowują swój kontekst wykonania.';

  @override
  String get allNamespaces => 'Wszystkie przestrzenie nazw';

  @override
  String get defaultNamespace => 'Domyślne';

  @override
  String get namespacePattern => 'Wzorzec nazwy (wyrażenie regularne)';

  @override
  String namespaceCount(int selected, int known) {
    return '$selected z $known';
  }

  @override
  String get previousPage => 'Poprzednia strona';

  @override
  String get patternRejected =>
      'Wzorzec jest nieprawidłowy lub przekracza limit pracy. Poprzedni wybór zostaje zachowany.';

  @override
  String get namespaceNotSelected =>
      'Przestrzeń nazw nie została wybrana do introspekcji';

  @override
  String get newMenu => 'Nowy';

  @override
  String get queryConsoles => 'Konsole zapytań';

  @override
  String get viewOptions => 'Opcje widoku';

  @override
  String get quickDocumentation => 'Szybka dokumentacja';

  @override
  String get showEmptyGroups => 'Pokaż puste grupy';

  @override
  String get speedSearch => 'Szybkie wyszukiwanie';

  @override
  String get speedSearchScope => 'Tylko rozwinięte, załadowane węzły.';

  @override
  String get newSourceFolder => 'Nowy folder źródeł';

  @override
  String get renameSourceFolder => 'Zmień nazwę folderu';

  @override
  String get moveToFolder => 'Przenieś do folderu';

  @override
  String get moveUp => 'Przenieś w górę';

  @override
  String get moveDown => 'Przenieś w dół';

  @override
  String get folderMustBeEmpty =>
      'Przenieś zawarte źródła i foldery przed usunięciem tego folderu.';

  @override
  String get newVirtualView => 'Nowy widok wirtualny';

  @override
  String get editVirtualDefinition => 'Edytuj lokalną definicję';

  @override
  String get unboundVirtualView => 'Niepowiązane widoki wirtualne';

  @override
  String get localVirtualViewNotice =>
      'Lokalna definicja SQL. Zapis nie wykonuje SQL ani nie tworzy widoku na serwerze. Uruchomienie używa zwykłej kontroli SQL i niezależnej konsoli.';

  @override
  String get rebindVirtualView => 'Powiąż tutaj lokalną definicję';

  @override
  String get sourceFolderName => 'Nazwa folderu';

  @override
  String get sourceFolderPathNotice =>
      'Użyj /, aby utworzyć zagnieżdżone foldery.';

  @override
  String get topLevel => 'Poziom główny';

  @override
  String get virtualViewName => 'Nazwa widoku wirtualnego';

  @override
  String get virtualViewSql => 'Definicja SQL widoku wirtualnego';

  @override
  String get virtualViews => 'Widoki wirtualne';

  @override
  String get revealInExplorer => 'Pokaż w eksploratorze baz';

  @override
  String get objectNotFound =>
      'Nie znaleziono obiektu w tej przestrzeni nazw. Odśwież metadane lub sprawdź uprawnienia.';

  @override
  String get objectHiddenByFilter =>
      'Obiekt jest ukryty przez bieżący filtr widoku.';

  @override
  String get revealFilterNotice =>
      'Wyszukiwanie zawęża tę stronę; pełna liczba obiektów kategorii jest pominięta.';

  @override
  String get clearObjectFilter => 'Wyczyść wyszukiwanie obiektu';

  @override
  String get compareStructure => 'Porównaj struktury';

  @override
  String get selectTwoCompatibleObjects =>
      'Wybierz dwie zgodne tabele za pomocą Ctrl-kliknięcia.';

  @override
  String get scopedComparisonRestriction =>
      'Porównanie wymaga zwykłych tabel z tą samą nazwą natywną, schematem i silnikiem. Inne typy i dopasowanie zmian nazw są niedostępne.';

  @override
  String get groupNamespaces => 'Grupuj bazy i schematy';

  @override
  String get groupSchemaObjects => 'Grupuj obiekty schematu';

  @override
  String get groupTableElements => 'Grupuj elementy tabeli';

  @override
  String get sortAlphabetically => 'Sortuj alfabetycznie';

  @override
  String get showVirtualObjects => 'Pokaż obiekty wirtualne';

  @override
  String get showObjectComments => 'Pokaż komentarze obiektów';

  @override
  String get objectTypeFilter => 'Filtr typu obiektu';

  @override
  String get partitionedTable => 'Tabela partycjonowana';

  @override
  String get foreignTable => 'Tabela obca';

  @override
  String get materializedView => 'Widok zmaterializowany';

  @override
  String get functionObject => 'Funkcja';

  @override
  String get procedureObject => 'Procedura';

  @override
  String get sqlSymbolUnavailable =>
      'Nie rozpoznano bezpiecznie trwałego obiektu pod kursorem. Połącz tę konsolę i użyj odwołania do tabeli lub widoku poza literałami i komentarzami.';

  @override
  String get sqlSymbolAmbiguous =>
      'Niejednoznaczne odwołanie SQL. Określ przestrzeń nazw lub wybierz dokładny obiekt bazy.';

  @override
  String get deactivateSource => 'Dezaktywuj źródło';

  @override
  String get functions => 'Funkcje';

  @override
  String get procedures => 'Procedury';

  @override
  String get separateProceduresFunctions => 'Oddziel procedury i funkcje';

  @override
  String get renameVirtualView => 'Zmień nazwę widoku wirtualnego';

  @override
  String get metadataPersistentScope =>
      'Tylko obiekty trwałe; obiekty tymczasowe i lokalne dla sesji pozostają w nawigacji konsoli.';

  @override
  String get metadataSessionScope =>
      'Tylko obiekty trwałe; odśwież obiekty lokalne konsoli po wykonaniu.';

  @override
  String get metadataLimitScope =>
      'Osiągnięto limit metadanych. Zawęź zakres obiektów.';

  @override
  String get completeColumnMetadataRequired =>
      'Przed importem lub przygotowaniem zmian wymagane są kompletne metadane kolumn.';

  @override
  String resizeColumn(String name) {
    return 'Zmień szerokość kolumny $name';
  }

  @override
  String get keyboardShortcutsHeading => 'Skróty klawiszowe';

  @override
  String sqlEditorLabel(String title) {
    return 'Edytor SQL $title';
  }

  @override
  String get editorResultsDivider => 'Separator edytora i wyników';

  @override
  String editorExtent(String percent) {
    return 'Edytor: $percent procent';
  }

  @override
  String get largerEditor => 'Powiększ edytor';

  @override
  String get smallerEditor => 'Pomniejsz edytor';

  @override
  String get explorerWidthDivider => 'Separator szerokości eksploratora';

  @override
  String get widerExplorer => 'Poszerz eksplorator';

  @override
  String get narrowerExplorer => 'Zwęź eksplorator';

  @override
  String explorerExtent(String width) {
    return 'Szerokość: $width pikseli';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '$start–$end z $total jednostek UTF-16';
  }

  @override
  String get dropDesignedColumn => 'Usuń kolumnę';

  @override
  String get liveCatalogLabel => 'Bieżący katalog';

  @override
  String get liveSchemaLabel => 'Bieżący schemat';

  @override
  String get searchPathLabel => 'Ścieżka wyszukiwania';

  @override
  String get physicalSessionLabel => 'Sesja fizyczna';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return 'Limit czasu: $seconds s · Limit wierszy: $rows';
  }

  @override
  String get saveFailedCloseTitle =>
      'Nie udało się zapisać SQL · Zamknij BusyData';

  @override
  String get createSection => 'Utwórz';

  @override
  String get newConnectionDescription => 'Skonfiguruj połączenie z bazą danych';

  @override
  String get newQueryDescription => 'Napisz SQL w nowym zapytaniu';

  @override
  String get openSqlDescription => 'Otwórz istniejący dokument SQL';

  @override
  String get searchNoResults => 'Brak pasujących działań';

  @override
  String get actionsCategory => 'Działania';

  @override
  String get privateRecoveryCategory => 'Prywatne odzyskiwanie';

  @override
  String get shortcutRecordHelp =>
      'Naciśnij skrót. Escape anuluje. F6 i Shift+F6 są zarezerwowane do nawigacji między panelami.';

  @override
  String get rowLimitInvalid => 'Wprowadź limit od 1 do 1 000 000 wierszy.';

  @override
  String get errorPolicy => 'Przy błędzie wykonania';

  @override
  String get tlsEncrypted => 'szyfrowane';

  @override
  String get tlsUnencrypted => 'nieszyfrowane';

  @override
  String get tlsUnobserved => 'niezaobserwowane';

  @override
  String get encryptionVerificationNote =>
      'Szyfrowanie nie potwierdza weryfikacji certyfikatu ani nazwy hosta.';

  @override
  String get uniqueDesignedColumnName =>
      'Użyj unikalnej nazwy kolumny; nowe tabele obsługują do 128 kolumn';

  @override
  String activityBlockerUnavailable(String id) {
    return 'Blokująca sesja $id nie jest już widoczna; odśwież i sprawdź uprawnienia bazy danych';
  }

  @override
  String get sshChangedKeyReview =>
      'Niezależnie zweryfikuj zmieniony klucz przed zastąpieniem powiązania z profilem.';

  @override
  String get sshProfileTrustBinding =>
      'Zaufanie dotyczy tylko tego profilu i dokładnego punktu docelowego.';

  @override
  String get databaseTlsEvidence => 'TLS · System bazy danych';

  @override
  String get sshAlgorithmLabel => 'SSH · Typ';

  @override
  String get sshFingerprintLabel => 'SHA-256';

  @override
  String get sshPreviousFingerprintLabel => 'Poprzedni · SHA-256';

  @override
  String get sshReviewedLabel => 'Sprawdź klucz hosta SSH';

  @override
  String get shortcutRecordAction => 'Nagraj skrót';

  @override
  String get fileFormatLabel => 'Format pliku';

  @override
  String get encodingLabel => 'Kodowanie';

  @override
  String get importPolicyLabel => 'Zasady importu';

  @override
  String get mainMenu => 'Menu główne';

  @override
  String get activityReplyTooLarge =>
      'Odpowiedź aktywności przekracza limit inspektora.';

  @override
  String get activityListLimited =>
      'Lista jest ograniczona; sprawdź węższy cel za pomocą jawnego SQL.';

  @override
  String get activitySelectionChanged =>
      'Wybrana aktywność zakończyła się lub zmieniła. Przed przeglądem działania wybierz jej bieżącą tożsamość.';

  @override
  String connectionSavedDraftChanged(String name) {
    return 'Pola połączenia zmieniły się podczas zapisywania; konfiguracja została zapisana: $name. Sprawdź bieżące wartości przed połączeniem.';
  }

  @override
  String get sshReviewTargetChanged =>
      'Cel weryfikacji SSH zmienił się; sprawdź ponownie';

  @override
  String get appearance => 'Wygląd';

  @override
  String get theme => 'Motyw';

  @override
  String get systemTheme => 'Systemowy';

  @override
  String get lightTheme => 'Jasny';

  @override
  String get darkTheme => 'Ciemny';

  @override
  String get appLanguage => 'Język aplikacji';

  @override
  String get systemLanguage => 'Systemowy';

  @override
  String get cut => 'Wytnij';

  @override
  String get paste => 'Wklej';

  @override
  String get selectAll => 'Zaznacz wszystko';

  @override
  String get noSelection => 'Brak dostępnego tekstu';

  @override
  String get clipboardEmpty => 'Schowek nie zawiera tekstu';

  @override
  String get settingsDraftNotice =>
      'Zmiany wykonania i prywatnego odzyskiwania nie zostały zapisane.';

  @override
  String get documentsMenu => 'Dokumenty';

  @override
  String get currentSql => 'Bieżący SQL';

  @override
  String get searchActionsHint => 'Szukaj działań…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => 'Atrybuty';

  @override
  String get metadataSelectionUnavailable =>
      'Wybierz element, aby sprawdzić jego przechwycone właściwości. Poprzedni wybór jest niedostępny.';

  @override
  String get secureStorage => 'Bezpieczny magazyn systemu';

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
      'Nie można zapisać pamięci podręcznej. Bieżące metadane pozostają dostępne.';

  @override
  String get metadataCacheRebuiltVersion => 'Odbudowana dla bieżącej wersji';

  @override
  String get metadataCacheRebuiltCorrupt =>
      'Odbudowana po błędzie pamięci podręcznej';

  @override
  String get editSessionBusy =>
      'Ta sesja jest zajęta. Poczekaj na zakończenie jej bieżącej pracy, a następnie zażądaj nowej oceny możliwości edycji.';

  @override
  String get editIdentityRequired =>
      'Przed edycją wybierz pełny klucz główny lub unikatowy identyfikator, który nie dopuszcza wartości NULL.';

  @override
  String get editColumnsReadOnly =>
      'Wszystkie kolumny projekcji są generowane lub tylko do odczytu.';

  @override
  String get editResultNotReady =>
      'Poczekaj na ukończenie tego zachowanego wyniku przed zażądaniem nowej oceny możliwości edycji.';

  @override
  String get editProjectionUnsupported =>
      'Edycja wymaga bezpośredniego SELECT z jednej tabeli bazowej, w którym każda kolumna bazowa jest wybrana tylko raz.';

  @override
  String get sqlInspectionDuplicateUsingColumn =>
      'Powtórzona kolumna JOIN USING';

  @override
  String get sqlInspectionUnresolvedUsingColumn =>
      'Brak kolumny JOIN USING w jednym operandzie';

  @override
  String get sqlInspectionAmbiguousUsingColumn =>
      'Niejednoznaczna wspólna kolumna JOIN';

  @override
  String get sqlInspectionOutputColumnCount =>
      'Niezgodna liczba zadeklarowanych kolumn wyjściowych';

  @override
  String get sqlInspectionAmbiguousOverload =>
      'Niejednoznaczne przeciążenie procedury';

  @override
  String get sqlInspectionBooleanType =>
      'Nieprawidłowy typ wyrażenia logicznego';

  @override
  String get sqlInspectionOperatorTypes => 'Niezgodne typy operandów operatora';

  @override
  String get sqlInspectionArrayTypes => 'Niezgodne typy elementów tablicy';

  @override
  String get sqlInspectionCaseConditionType => 'Niezgodny typ warunku CASE';

  @override
  String get sqlInspectionCaseResultTypes => 'Niezgodne typy wyników CASE';

  @override
  String get sqlInspectionCoalesceTypes => 'Niezgodne typy argumentów COALESCE';

  @override
  String get sqlInspectionSetColumnCount =>
      'Niezgodna liczba kolumn operacji na zbiorach';

  @override
  String get sqlInspectionSetTypes =>
      'Niezgodne typy wyników operacji na zbiorach';

  @override
  String get sqlInspectionRecursiveCteType =>
      'Niezgodny typ rekurencyjnego CTE';
}
