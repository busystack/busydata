// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get cancel => 'Отмена';

  @override
  String get windowMinimize => 'Свернуть';

  @override
  String get windowMaximize => 'Развернуть';

  @override
  String get windowRestore => 'Восстановить';

  @override
  String get databaseExplorer => 'Обозреватель баз данных';

  @override
  String get databases => 'Базы данных';

  @override
  String get newConnection => 'Новое подключение';

  @override
  String get filterTree => 'Фильтр подключений и объектов';

  @override
  String get treeFilterScope => 'Фильтрует загруженные объекты дерева';

  @override
  String get searchObjects => 'Поиск объектов базы данных';

  @override
  String get fileMenu => 'Файл';

  @override
  String get editMenu => 'Правка';

  @override
  String get viewMenu => 'Вид';

  @override
  String get connectionMenu => 'Подключение';

  @override
  String get objectMenu => 'Объект';

  @override
  String get runMenu => 'Параметры выполнения';

  @override
  String get commands => 'Команды';

  @override
  String get findCommand => 'Найти команду';

  @override
  String get newSql => 'Новый запрос';

  @override
  String get openSql => 'Открыть SQL';

  @override
  String get openSqlFile => 'Открыть файл SQL';

  @override
  String get saveSql => 'Сохранить SQL';

  @override
  String get closeTab => 'Закрыть вкладку';

  @override
  String get openWorkspace => 'Открыть рабочую область';

  @override
  String get saveWorkspace => 'Сохранить рабочую область';

  @override
  String get settings => 'Настройки';

  @override
  String get findText => 'Найти';

  @override
  String get replaceText => 'Заменить';

  @override
  String get formatSql => 'Форматировать SQL';

  @override
  String get lineComments => 'Переключить комментарии строк';

  @override
  String get snippets => 'Фрагменты SQL';

  @override
  String get run => 'Выполнить';

  @override
  String get runStatement => 'Выполнить текущую инструкцию';

  @override
  String get runSelection => 'Выполнить выделенное';

  @override
  String get runScript => 'Выполнить скрипт';

  @override
  String get explain => 'План выполнения';

  @override
  String get explainAnalyze => 'План с выполнением';

  @override
  String get connect => 'Подключить';

  @override
  String get disconnect => 'Отключить';

  @override
  String get sessionDetails => 'Сведения о сеансе';

  @override
  String get beginTransaction => 'Начать транзакцию';

  @override
  String get commitTransaction => 'Зафиксировать транзакцию';

  @override
  String get rollbackTransaction => 'Откатить транзакцию';

  @override
  String get enableAutoCommit => 'Включить автофиксацию';

  @override
  String get disableAutoCommit => 'Отключить автофиксацию';

  @override
  String get outcomeUnknown => 'Исход неизвестен';

  @override
  String get outcomeUnknownNote =>
      'Операция могла завершиться. В этой сессии нельзя выполнять новый SQL. Никогда не повторяйте автоматически; выясните результат перед началом новой работы.';

  @override
  String get notConnected => 'Отключено';

  @override
  String get autoCommit => 'Автофиксация';

  @override
  String get manualTransaction => 'Ручная транзакция';

  @override
  String get readOnlyPolicy => 'Политика BusyData «только чтение»';

  @override
  String get data => 'Данные';

  @override
  String get structure => 'Структура';

  @override
  String get results => 'Результаты';

  @override
  String get messages => 'Сообщения';

  @override
  String get plan => 'План';

  @override
  String get changes => 'Изменения';

  @override
  String get history => 'История';

  @override
  String get jobs => 'Задания';

  @override
  String get retainedResults => 'Сохранённые результаты';

  @override
  String get recoverEdits => 'Восстановить подготовленные изменения';

  @override
  String get applyAndCommit => 'Применить и зафиксировать';

  @override
  String get inspectStructure => 'Просмотреть структуру';

  @override
  String get openData => 'Открыть данные';

  @override
  String get openDefinition => 'Открыть определение';

  @override
  String get copyQualifiedName => 'Копировать полное имя';

  @override
  String get refresh => 'Обновить';

  @override
  String get columns => 'Столбцы';

  @override
  String get indexes => 'Индексы';

  @override
  String get constraints => 'Ключи и ограничения';

  @override
  String get foreignKeys => 'Внешние ключи';

  @override
  String get triggers => 'Триггеры';

  @override
  String get definition => 'Определение';

  @override
  String get dependencies => 'Зависимости';

  @override
  String get connectionCapabilities => 'Обзор подключения';

  @override
  String get sessionsAndLocks => 'Сеансы и блокировки';

  @override
  String get usersAndRoles => 'Пользователи и роли';

  @override
  String get saveSnapshot => 'Сохранить снимок схемы';

  @override
  String get compareSchemas => 'Сравнить схемы';

  @override
  String get objectDesigner => 'Конструктор объектов';

  @override
  String get diagram => 'ER-диаграмма';

  @override
  String get backup => 'Резервная копия';

  @override
  String get restore => 'Восстановить';

  @override
  String get importData => 'Импортировать данные';

  @override
  String get exportRetained => 'Экспортировать сохранённые данные';

  @override
  String get exportSql => 'Выполнить SQL-экспорт';

  @override
  String get stageInsert => 'Вставить строку';

  @override
  String get stageUpdate => 'Изменить строку';

  @override
  String get stageDelete => 'Удалить строку';

  @override
  String get discardChanges => 'Отбросить ожидающие изменения';

  @override
  String get disposeResult => 'Освободить сохранённые данные';

  @override
  String get currentSchema => 'Текущая схема (будет изменена)';

  @override
  String get desiredSchema => 'Желаемая схема';

  @override
  String get applyTo => 'Применить к';

  @override
  String get loading => 'Загрузка';

  @override
  String get empty => 'Нет объектов в этой области';

  @override
  String get more => 'Ещё';

  @override
  String get filter => 'Фильтр';

  @override
  String get sort => 'Сортировка';

  @override
  String get selectTarget => 'Выбрать подключение';

  @override
  String get requireSql => 'Требуется документ SQL';

  @override
  String get requireSession =>
      'Требуется подключённый сеанс с известным состоянием';

  @override
  String get requireResult => 'Требуются сохранённые данные';

  @override
  String get requireObject => 'Требуется целевой объект';

  @override
  String get cancelRequested => 'Запрошена отмена';

  @override
  String get cancelled => 'Отменено';

  @override
  String get queued => 'В очереди';

  @override
  String get running => 'Выполняется';

  @override
  String get completed => 'Завершено';

  @override
  String get failed => 'Ошибка';

  @override
  String get partial => 'Частично';

  @override
  String get sessionSharing => 'Разделить существующий сеанс (дополнительно)';

  @override
  String get production => 'Рабочая среда';

  @override
  String get staging => 'Подготовительная среда';

  @override
  String get development => 'Разработка';

  @override
  String get executionOptions => 'Параметры выполнения';

  @override
  String get resultRowLimit => 'Лимит строк результата (1–1000000)';

  @override
  String get boundedRead => 'Ограниченное чтение';

  @override
  String get streamingRead => 'Потоковое чтение · владеет транзакцией чтения';

  @override
  String get stopOnError => 'Остановить скрипт при ошибке';

  @override
  String get continueOnError =>
      'Продолжить при ошибке · предыдущие инструкции могли быть зафиксированы';

  @override
  String get loadMore => 'Загрузить ещё';

  @override
  String get favorite => 'Переключить избранное';

  @override
  String get connectionGroup => 'Группа подключений';

  @override
  String get copyRange => 'Копировать диапазон';

  @override
  String get inspectValue => 'Просмотреть значение';

  @override
  String get editConnection => 'Изменить подключение';

  @override
  String get chooseSnapshot => 'Выбрать снимок';

  @override
  String get captureSchema => 'Снять состояние схемы';

  @override
  String get sameSchemaRestriction =>
      'Снимки должны иметь одинаковые движок, имя схемы и версию снимка. Сравнение и сохранение никогда не применяют изменения.';

  @override
  String get restoredTaskState =>
      'Ссылка на документ восстановлена. Прежние данные сервера приложения, сеансы и задания недоступны. Выберите явное действие для новой работы; восстановление не подключается, не выполняет SQL и не повторяет изменения.';

  @override
  String get preChangeSnapshot =>
      'Снимок до изменений · изменения зафиксированы. Обновите явно, чтобы проверить текущие строки и значения сервера по умолчанию.';

  @override
  String get sqlProvenance => 'Происхождение SQL';

  @override
  String get assessEditing => 'Проверить возможность правки';

  @override
  String get viewDetails => 'Показать сведения';

  @override
  String get gridMenu => 'Таблица данных';

  @override
  String get visibleColumns => 'Видимые столбцы';

  @override
  String get hidden => 'Скрыт';

  @override
  String get ascending => 'По возрастанию';

  @override
  String get descending => 'По убыванию';

  @override
  String get equals => 'Равно';

  @override
  String get notEqual => 'Не равно';

  @override
  String get lessThan => 'Меньше';

  @override
  String get greaterThan => 'Больше';

  @override
  String get isNull => 'Равно NULL';

  @override
  String get isNotNull => 'Не равно NULL';

  @override
  String get exactValue => 'Точное значение';

  @override
  String get sortTable => 'Сортировать данные таблицы';

  @override
  String get filterTable => 'Фильтровать данные таблицы';

  @override
  String get sortRetained => 'Сортировать сохранённый снимок';

  @override
  String get filterRetained => 'Фильтровать сохранённый снимок';

  @override
  String get applyView => 'Применить';

  @override
  String get rowsLabel => 'Строки';

  @override
  String get fetchedRows => 'Полученные строки';

  @override
  String get fixedSnapshot => 'Фиксированный снимок полученных строк';

  @override
  String get limitReached => 'Достигнут лимит';

  @override
  String get retainedData => 'Сохранённые данные';

  @override
  String get applyRequiresAutoCommit =>
      'Применение и фиксация требуют свободного сеанса с включённой автофиксацией.';

  @override
  String get connectionProfile => 'Профиль подключения';

  @override
  String get basic => 'Основные';

  @override
  String get advanced => 'Дополнительно';

  @override
  String get connectionName => 'Имя';

  @override
  String get hostname => 'Имя узла (также для проверки TLS)';

  @override
  String get port => 'Порт';

  @override
  String get database => 'База данных';

  @override
  String get user => 'Пользователь';

  @override
  String get password => 'Пароль';

  @override
  String get writableProfile => 'Профиль с записью';

  @override
  String get readonlyProfile => 'Профиль только для чтения';

  @override
  String get tlsVerify => 'TLS: проверять сертификат и имя узла';

  @override
  String get tlsInsecure => 'TLS: НЕБЕЗОПАСНО, без проверки';

  @override
  String get tlsDisabled => 'TLS: ОТКЛЮЧЕНО';

  @override
  String get testConnection => 'Проверить без сохранения';

  @override
  String get saveProfile => 'Сохранить';

  @override
  String get saveConnect => 'Сохранить и подключиться';

  @override
  String get sessionPassword => 'Пароль только для этого сеанса';

  @override
  String get storedPassword => 'Хранить пароль в защищённом хранилище ОС';

  @override
  String get chooseFile => 'Выбрать файл';

  @override
  String get testRunning => 'Проверка подключения…';

  @override
  String get cancelTest => 'Отменить проверку';

  @override
  String get idle => 'Нет операций';

  @override
  String get activeTransaction => 'Транзакция открыта';

  @override
  String get failedTransaction => 'Транзакция завершилась ошибкой';

  @override
  String get inspectionContext => 'Сеанс проверки';

  @override
  String get requireTableOrView => 'Выберите таблицу или представление';

  @override
  String get operationPending => 'Операция документа ожидает подтверждения';

  @override
  String get requirePlan => 'Выберите сохранённое выполнение Explain';

  @override
  String get openPlanDocument => 'Открыть документ плана';

  @override
  String get locks => 'Блокировки';

  @override
  String get statistics => 'Статистика';

  @override
  String get queryStatistics => 'Статистика запросов';

  @override
  String get indexDiagnostics => 'Диагностика индексов';

  @override
  String get grants => 'Выданные права';

  @override
  String get sqlExecution => 'Выполнение SQL';

  @override
  String get planReady => 'Сохранённый план готов; SQL не выполнялся повторно';

  @override
  String get executionPlan => 'План выполнения';

  @override
  String get openOwner => 'Открыть владельца';

  @override
  String get terminateActivity => 'Завершить активность';

  @override
  String get close => 'Закрыть';

  @override
  String get previous => 'Назад';

  @override
  String get next => 'Далее';

  @override
  String get replaceSelection => 'Заменить выделенное';

  @override
  String get replaceAll => 'Заменить всё';

  @override
  String get restartBackend => 'Перезапустить сервер приложения';

  @override
  String get structuredTree => 'Структурированное дерево';

  @override
  String get rawOutput => 'Необработанный вывод';

  @override
  String get previousTextPage => 'Предыдущая страница текста';

  @override
  String get nextTextPage => 'Следующая страница текста';

  @override
  String get filterChangedObjects => 'Фильтр изменённых объектов';

  @override
  String get rebindVerifiedEdits => 'Перепривязать проверенные изменения';

  @override
  String get discardRecoveryRecord => 'Удалить запись восстановления';

  @override
  String get revertChange => 'Отменить ожидающее изменение';

  @override
  String get chooseSource => 'Выбрать источник';

  @override
  String get chooseDestination => 'Выбрать назначение';

  @override
  String get delimiterField => 'Разделитель (один символ)';

  @override
  String get batchRowsField => 'Строк в пакете (1–1000)';

  @override
  String get rejectedLimit => 'Лимит отклонённых строк (1–1000)';

  @override
  String get previewSource => 'Предпросмотр источника';

  @override
  String get reviewTransfer => 'Проверить передачу';

  @override
  String get startImport => 'Начать импорт';

  @override
  String get startRestore => 'Начать восстановление';

  @override
  String get startExport => 'Начать экспорт';

  @override
  String get requestCancel => 'Запросить отмену';

  @override
  String get sourceMapping => 'Сопоставление источника и цели';

  @override
  String get nativeTool => 'Системный инструмент';

  @override
  String get defaultOmit => 'Пропустить / значение базы по умолчанию';

  @override
  String get overwriteNever => 'Не перезаписывать';

  @override
  String get overwriteExisting => 'Перезаписать существующий файл';

  @override
  String get planDetails => 'Сведения о плане';

  @override
  String get planMetricsNote =>
      'Оценки и фактические измерения используют названия полей сервера. Отсутствующие измерения недоступны.';

  @override
  String get connected => 'Подключено';

  @override
  String get disconnected => 'Отключено';

  @override
  String get tables => 'Таблицы';

  @override
  String get views => 'Представления';

  @override
  String get routines => 'Процедуры';

  @override
  String get expand => 'Развернуть';

  @override
  String get collapse => 'Свернуть';

  @override
  String get databaseWorkbench => 'Рабочая среда базы данных';

  @override
  String get sidebar => 'Боковая панель';

  @override
  String get unchanged => 'Без изменений';

  @override
  String get reviewDetails => 'Сведения о проверке';

  @override
  String get generatedSql => 'Созданный SQL';

  @override
  String get changeReverted => 'Изменение отменено. Запросите новую проверку.';

  @override
  String get unknownBatch =>
      'Исход неизвестен. Пакет мог быть зафиксирован. Никогда не повторяйте его автоматически; проверьте сеанс и запись восстановления.';

  @override
  String get expiredChangeReview =>
      'Цель изменилась или срок проверки истёк. Запросите новую проверку.';

  @override
  String get applyCommitExplanation =>
      'Применить и зафиксировать начинает и фиксирует собственную транзакцию. Исходная консоль должна простаивать с включённой автофиксацией. Ручные SQL-транзакции завершайте отдельно.';

  @override
  String get newRow => 'Новая строка';

  @override
  String get original => 'Исходное';

  @override
  String get proposed => 'Предложенное';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '$inserts вставок · $updates обновлений · $deletes удалений';
  }

  @override
  String sourceRow(String row) {
    return 'Исходная строка $row';
  }

  @override
  String get refreshing => 'Обновление…';

  @override
  String get refreshActivities => 'Обновить активность';

  @override
  String get explicitRefresh => 'Явное обновление';

  @override
  String get pollFiveSeconds => 'Опрос каждые 5 секунд';

  @override
  String get cancelSelectedActivity => 'Отменить выбранную операцию';

  @override
  String get terminateSelectedSession => 'Завершить выбранный сеанс';

  @override
  String get filterActivities => 'Фильтр текущей активности';

  @override
  String get blockedBy => 'Заблокировано:';

  @override
  String get delete => 'Удалить';

  @override
  String get remove => 'Удалить';

  @override
  String get up => 'Вверх';

  @override
  String get search => 'Поиск';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get clear => 'Очистить';

  @override
  String get copy => 'Копировать';

  @override
  String get insert => 'Вставлять';

  @override
  String get update => 'Обновить';

  @override
  String get open => 'Открыть';

  @override
  String get migrationEngineMismatch =>
      'Целевое подключение должно использовать тот же движок, что и сравниваемые снимки. Миграция между движками не поддерживается.';

  @override
  String get metadataContextChanged =>
      'Контекст проверки изменился. Обновите метаданные явно.';

  @override
  String get newTableName => 'Имя новой таблицы';

  @override
  String get routineIdentity => 'Точная идентичность процедуры';

  @override
  String get objectColumnName => 'Имя объекта / столбца';

  @override
  String get builtInType => 'Встроенный тип';

  @override
  String get sqlExpression => 'Выражение SQL (пустое удаляет его)';

  @override
  String get newPropertyValue => 'Новое значение свойства';

  @override
  String get columnComment => 'Комментарий столбца';

  @override
  String get columnCollation =>
      'Правило сортировки столбца (пустое использует настройку сервера)';

  @override
  String get addDesignedColumn => 'Добавить столбец в новую таблицу';

  @override
  String get checkExpression => 'Выражение CHECK';

  @override
  String get referencedSchema => 'Схема / база данных по ссылке';

  @override
  String get generating => 'Генерация…';

  @override
  String get generateReviewedDdl => 'Создать DDL для проверки';

  @override
  String get inspectCapturedDefinition => 'Проверить сохранённое определение';

  @override
  String get capturedObject => 'Сохранённый объект';

  @override
  String get designReviewNote =>
      'Изменения создаются для проверки. Содержимое базы не изменяется до проверенного выполнения.';

  @override
  String get columnMetadataUnavailable =>
      'Метаданные столбцов в этой области недоступны; проверьте выбранную схему перед составлением списка столбцов.';

  @override
  String get ordinaryColumn => 'Обычный столбец';

  @override
  String get columnWithDefault => 'Столбец со значением по умолчанию';

  @override
  String get identityColumn => 'Идентичность / автоинкремент';

  @override
  String get generatedColumn => 'Вычисляемый столбец';

  @override
  String get columnType => 'Тип столбца';

  @override
  String get nullableNotNull => 'Допускает NULL / NOT NULL';

  @override
  String get defaultExpression => 'Выражение по умолчанию';

  @override
  String get generatedExpression => 'Вычисляемое выражение';

  @override
  String get columnCollationProperty => 'Правило сортировки столбца';

  @override
  String get loggedUnlogged => 'Журналируемая / нежурналируемая';

  @override
  String get tableComment => 'Комментарий таблицы';

  @override
  String get storageEngine => 'Механизм хранения';

  @override
  String get tableCollation => 'Правило сортировки таблицы';

  @override
  String get rowFormat => 'Формат строки';

  @override
  String get createOrReplace => 'Создать или заменить';

  @override
  String get dropSelectedObject => 'Удалить выбранный объект';

  @override
  String get addColumn => 'Добавить столбец';

  @override
  String get editColumnProperties => 'Изменить свойства столбца';

  @override
  String get tableProperties => 'Свойства таблицы';

  @override
  String get triggerDefinition => 'Определение триггера';

  @override
  String get createTable => 'Создать таблицу';

  @override
  String get viewDefinition => 'Определение представления';

  @override
  String get routineDefinition => 'Определение процедуры';

  @override
  String get chooseExistingObject => 'Выбрать существующий объект';

  @override
  String get nullable => 'Допускает NULL';

  @override
  String get removeIdentity => 'Удалить идентичность';

  @override
  String get generatedAlways => 'Генерируется всегда';

  @override
  String get generatedByDefault => 'Генерируется по умолчанию / автоинкремент';

  @override
  String get loggedTable => 'Журналируемая таблица';

  @override
  String get unloggedTable => 'Нежурналируемая таблица';

  @override
  String get orderedPrimaryKeyColumns => 'Столбцы первичного ключа по порядку';

  @override
  String get orderedColumns => 'Столбцы по порядку';

  @override
  String get ordinaryIndex => 'Обычный индекс';

  @override
  String get uniqueIndex => 'Уникальный индекс';

  @override
  String get primaryKey => 'Первичный ключ';

  @override
  String get uniqueConstraint => 'Ограничение уникальности';

  @override
  String get foreignKey => 'Внешний ключ';

  @override
  String get checkConstraint => 'Ограничение CHECK';

  @override
  String get immediateChecking => 'Немедленная проверка';

  @override
  String get deferrableChecking => 'Откладываемая проверка';

  @override
  String get initiallyImmediate => 'Изначально немедленно';

  @override
  String get initiallyDeferred => 'Изначально отложено';

  @override
  String get referencedTable => 'Таблица по ссылке';

  @override
  String get orderedReferencedColumns =>
      'Столбцы по ссылке в соответствующем порядке';

  @override
  String get objectDefinitionEditor =>
      'SQL-редактор собственного определения объекта';

  @override
  String get onDelete => 'При удалении';

  @override
  String get onUpdate => 'При обновлении';

  @override
  String get stay => 'Остаться';

  @override
  String get saveSqlClose => 'Сохранить SQL и закрыть';

  @override
  String get discardSqlClose => 'Отбросить SQL и закрыть';

  @override
  String get closeBusyData => 'Закрыть BusyData';

  @override
  String get saveDraftsClose => 'Сохранить черновики и закрыть';

  @override
  String get closeWithoutRecovery => 'Закрыть без восстановления';

  @override
  String get recoveryFailed => 'Ошибка восстановления';

  @override
  String get discardFailedSaveClose =>
      'Отбросить неудачное сохранение и закрыть';

  @override
  String get closeWithoutSavingRecovery =>
      'Закрыть без сохранения восстановления';

  @override
  String get disableSqlRecovery => 'Отключить восстановление SQL';

  @override
  String get historyPrivacy => 'Конфиденциальность истории';

  @override
  String get enableSqlRetention => 'Включить хранение SQL';

  @override
  String get disableSqlRetention => 'Отключить хранение SQL';

  @override
  String get clearHistory => 'Очистить историю';

  @override
  String get deleteHistoryEntry => 'Удалить запись истории';

  @override
  String get deleteSelected => 'Удалить выбранное';

  @override
  String get saveRetention => 'Сохранить срок хранения';

  @override
  String get retentionDays => 'Дни хранения';

  @override
  String get sqlTextRetained => 'Текст SQL сохранён';

  @override
  String get sqlTextDisabled => 'Текст SQL отключён';

  @override
  String get openHistoryQuery => 'Открыть в новой вкладке SQL';

  @override
  String get caCertificateFile => 'Файл сертификата CA';

  @override
  String get clientCertificateFile => 'Файл сертификата клиента';

  @override
  String get clientKeyFile => 'Файл ключа клиента';

  @override
  String get directConnection => 'Прямое подключение';

  @override
  String get sshTunnel => 'Туннель SSH';

  @override
  String get sshHost => 'Хост SSH';

  @override
  String get sshPort => 'Порт SSH';

  @override
  String get sshUser => 'Пользователь SSH';

  @override
  String get reviewedKnownHosts => 'Проверенный файл known_hosts';

  @override
  String get reviewSshKey => 'Проверить ключ хоста SSH';

  @override
  String get changedSshKey => 'Ключ хоста SSH изменён';

  @override
  String get verifyFingerprint =>
      'Независимо проверьте этот отпечаток, прежде чем доверять ему.';

  @override
  String get selectedKeyPassword => 'Выбранный ключ или пароль';

  @override
  String get selectedAgentIdentity => 'Выбранная идентичность агента SSH';

  @override
  String get selectedAgentSocket =>
      'Выбранный сокет агента Linux / именованный канал Windows';

  @override
  String get selectedKeyFingerprint => 'Отпечаток выбранного ключа · SHA256:…';

  @override
  String get selectedPrivateKey => 'Выбранный закрытый ключ (необязательно)';

  @override
  String get sshPassword => 'Пароль SSH';

  @override
  String get keyPassphrase => 'Парольная фраза ключа';

  @override
  String get connectionTimeout => 'Тайм-аут подключения · 1–120 секунд';

  @override
  String get sqlTimeout =>
      'Срок выполнения/чтения SQL · 1–3600 секунд (0 = 60)';

  @override
  String get schemasEquivalent => 'Снятые схемы эквивалентны.';

  @override
  String get migrationComplete =>
      'Миграция охватывает поддерживаемые различия снимков.';

  @override
  String get migrationPartial =>
      'Частичная миграция; остаются неподдерживаемые различия.';

  @override
  String get differencesLimited =>
      'Представление различий ограничено. Проверьте полные сохранённые снимки и созданный SQL.';

  @override
  String get absent => 'Отсутствует';

  @override
  String get definitionPreviewLimited =>
      'Просмотр определения ограничен; полные данные находятся в исходном снимке.';

  @override
  String get migrationBatchNote =>
      'SQL составляет один пакет в порядке зависимостей. Выбор объекта служит для просмотра и не выбирает операторы для применения.';

  @override
  String get unsupportedLabel => 'Не поддерживается';

  @override
  String get differenceAdded => 'Добавлено';

  @override
  String get differenceRemoved => 'Удалено';

  @override
  String get differenceChanged => 'Изменено';

  @override
  String get selectHistoryEntry => 'Выберите запись истории';

  @override
  String get searchSqlTarget => 'Поиск SQL или цели';

  @override
  String get closeSqlTab => 'Закрыть вкладку SQL';

  @override
  String get historyMetadataRetained =>
      'Метаданные состояния и цели остаются в истории.';

  @override
  String get historyPreviewNote =>
      'Только предпросмотр. Откройте в новой вкладке SQL для получения сохранённого текста.';

  @override
  String get selected => 'Выбрано';

  @override
  String get authReviewNote =>
      'Проверьте точного субъекта и цель перед применением. Учётные данные никогда не помещаются в SQL-документы или историю. Существующие подключения и сохранённые пароли остаются отдельными.';

  @override
  String get createLogin => 'Создать учётную запись для входа';

  @override
  String get createRole => 'Создать роль без входа';

  @override
  String get setPassword => 'Задать пароль';

  @override
  String get preventLogin => 'Запретить новые входы';

  @override
  String get allowLogin => 'Разрешить новые входы';

  @override
  String get dropPrincipal => 'Удалить субъекта';

  @override
  String get principalName => 'Точное имя субъекта';

  @override
  String get accountHost =>
      'Точный хост учётной записи (шаблоны расширяют область входа)';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get repeatPassword => 'Повторить новый пароль';

  @override
  String get reviewAccount => 'Проверить операцию учётной записи';

  @override
  String get passwordsMismatch => 'Дважды введите одинаковый непустой пароль';

  @override
  String get accountSubmitFailed =>
      'Не удалось отправить операцию учётной записи. Проверьте цель, политику аутентификации и права базы данных.';

  @override
  String get privilegeReviewNote =>
      'Проверьте прямые права; созданный SQL по-прежнему требует проверки перед выполнением.';

  @override
  String get inspectionLimited =>
      'Не более 500 строк в разделе. Уточните поиск; пустой раздел не доказывает отсутствие действующих прав доступа.';

  @override
  String get findPrincipal => 'Найти имя пользователя / роли';

  @override
  String get searchPrincipals => 'Найти субъектов';

  @override
  String get choosePrincipal => 'Выбрать субъекта';

  @override
  String get inspectGrants => 'Проверить выбранные права';

  @override
  String get tablePrivileges => 'Права таблицы / представления';

  @override
  String get schemaPrivileges => 'Права схемы';

  @override
  String get databasePrivileges => 'Права базы данных';

  @override
  String get roleMembership => 'Членство в роли';

  @override
  String get defaultRole => 'Активация роли по умолчанию';

  @override
  String get chooseGrantRole => 'Выбрать роль для выдачи / отзыва';

  @override
  String get tableView => 'Таблица / представление';

  @override
  String get explicitPrivileges => 'Явные права (через запятую)';

  @override
  String get setDefaultRole => 'Задать выбранную роль по умолчанию';

  @override
  String get clearDefaultRole => 'Удалить роль по умолчанию';

  @override
  String get grantAccess => 'Предоставить доступ';

  @override
  String get revokeAccess => 'Отозвать доступ';

  @override
  String get withoutDelegation => 'Без делегирования';

  @override
  String get allowDelegation => 'Разрешить получателю выдавать права другим';

  @override
  String get readonlyChanges =>
      'Этот профиль только для чтения. Изменения требуют явно разрешающего запись сеанса.';

  @override
  String get createPrincipal => 'Создать пользователя / роль';

  @override
  String get manageAuthentication => 'Управлять выбранной аутентификацией';

  @override
  String get openPrivilegeSql => 'Открыть SQL прав для проверки';

  @override
  String get inspectPrincipalFirst =>
      'Проверьте выбранного субъекта перед подготовкой изменения';

  @override
  String get accountAuthentication => 'Аутентификация учётной записи';

  @override
  String get schema => 'Схема';

  @override
  String get available => 'Доступно';

  @override
  String get availableEmpty => 'Доступно · данные пусты';

  @override
  String get limitedVisibility => 'Ограниченная видимость или область';

  @override
  String get permissionDenied => 'Доступ запрещён';

  @override
  String get unavailable => 'Недоступно';

  @override
  String get profileDisabled => 'Отключено профилем';

  @override
  String get unknownState => 'Неизвестно';

  @override
  String get inspecting => 'Проверка…';

  @override
  String get refreshCapabilities => 'Обновить возможности';

  @override
  String get staleRefresh => 'Устарело · обновите после подключения';

  @override
  String get staleContext =>
      'Устарело · обновите после подключения или смены контекста';

  @override
  String get partialTreeLimit =>
      'Частично · предел дерева достигнут; сузьте поиск объектов';

  @override
  String get schemaComparison => 'Сравнение схем';

  @override
  String get searchTable => 'Найти таблицу';

  @override
  String get focusObject => 'Фокус';

  @override
  String get exportSvg => 'Экспорт SVG';

  @override
  String get exportPng => 'Экспорт PNG';

  @override
  String get diagramNotes => 'Заметки диаграммы (включены в SVG)';

  @override
  String get openNotes => 'Открыть заметки';

  @override
  String get saveNotes => 'Сохранить заметки';

  @override
  String get newSnippet => 'Новый фрагмент';

  @override
  String get snippetName => 'Имя фрагмента';

  @override
  String get saveSnippet => 'Сохранить фрагмент';

  @override
  String get deleteSnippet => 'Удалить сохранённый фрагмент';

  @override
  String get insertSnippet => 'Вставить в SQL-документ';

  @override
  String get snippetEditor => 'Редактор фрагментов SQL';

  @override
  String get snippetsNote =>
      'Вставьте сохранённый локальный SQL в исходный документ с отменой. Выполнение остаётся явным.';

  @override
  String get level => 'Уровень';

  @override
  String get expanded => 'развёрнуто';

  @override
  String get collapsed => 'свёрнуто';

  @override
  String get treeLevel => 'Уровень';

  @override
  String get retainedView => 'Сохранённое представление';

  @override
  String get tableQuerySnapshot => 'Снимок запроса таблицы';

  @override
  String get originalResultNote =>
      'Исходный сохранённый результат; просмотр страниц и проверка не выполняют SQL';

  @override
  String get tableFilterNote =>
      'Применение отправляет новый проверенный запрос. Предыдущий снимок остаётся доступным.';

  @override
  String get retainedFilterNote =>
      'Все полученные строки в фиксированном снимке. SQL не выполняется повторно. Порядок может отличаться от сортировки базы данных.';

  @override
  String get retainedRowNote =>
      'Выберите строку уже полученного результата. SQL не выполняется повторно.';

  @override
  String get copyLimitNote =>
      'Копирование ограничено 10 000 ячейками; для больших диапазонов экспортируйте сохранённые данные.';

  @override
  String get inlineValueLimit =>
      'Встроенное редактирование поддерживает значения до 8KiB';

  @override
  String get editContextChanged =>
      'Исходный сеанс или контекст редактирования изменился; проверьте или обновите оценку перед подготовкой изменений';

  @override
  String get editAssessmentUnavailable =>
      'Редактирование недоступно; обновите оценку после освобождения сеанса';

  @override
  String get rowChangeReverted =>
      'Ожидающее изменение строки отменено; база данных не изменена';

  @override
  String get sqlCopyRequiresMetadata =>
      'SQL-копирование требует backend и сохранённых метаданных типов.';

  @override
  String get exportFullValue => 'Экспортировать полное сохранённое значение';

  @override
  String valueExportReview(String bytes, String path) {
    return 'Сохранить $bytes байт в $path? Существующее содержимое будет заменено. SQL не выполняется повторно.';
  }

  @override
  String get goToRetainedRow => 'Перейти к сохранённой строке';

  @override
  String get row => 'Строка';

  @override
  String get go => 'Перейти';

  @override
  String get retryRows => 'Повторить загрузку сохранённых строк';

  @override
  String get previousRows => 'Предыдущие строки';

  @override
  String get nextRows => 'Следующие строки';

  @override
  String get firstWindow => 'Первое сохранённое окно';

  @override
  String get lastWindow => 'Последнее полученное окно';

  @override
  String get setNull => 'Задать NULL';

  @override
  String copyFormat(String format) {
    return 'Копировать $format';
  }

  @override
  String get textValue => 'Текст';

  @override
  String get sqlValues => 'Значения SQL';

  @override
  String get rowSelection => 'Выбор строк';

  @override
  String selectRow(String row) {
    return 'Выбрать строку $row';
  }

  @override
  String columnHeader(String column) {
    return 'Столбец $column';
  }

  @override
  String get pendingChange => 'ожидающее изменение';

  @override
  String get readonlyCell => 'Ячейка только для чтения';

  @override
  String get editableCell => 'Редактируемая ячейка';

  @override
  String get loadValueFirst => 'Сначала загрузите это сохранённое значение';

  @override
  String get editUnavailable => 'Редактирование недоступно';

  @override
  String get editCell => 'Изменить ячейку';

  @override
  String get unsupportedEditValue =>
      'Это сохранённое значение можно только просматривать';

  @override
  String bytesCount(String bytes) {
    return '$bytes байт';
  }

  @override
  String get problems => 'Проблемы';

  @override
  String get ownedSessions => 'Собственные сеансы';

  @override
  String get noProblems => 'Нет зарегистрированных проблем';

  @override
  String get duplicateConnection => 'Дублировать подключение';

  @override
  String get deleteConnection => 'Удалить подключение';

  @override
  String deleteConnectionReview(String name) {
    return 'Удалить $name? Существующие физические сеансы сохранят исходные настройки.';
  }

  @override
  String get unresolvedSessions => 'Неразрешённые сеансы';

  @override
  String get disconnectSessionNote =>
      'Сначала разрешите активные задания и транзакции. Отключение затрагивает всех клиентов этого физического сеанса; оно не фиксирует транзакции и не повторяет SQL. Неизвестные исходы остаются неизвестными.';

  @override
  String get transferSettingsChanged => 'Настройки изменились; проверьте снова';

  @override
  String get transferReviewReady =>
      'Проверка готова · проверьте цель, область, сопоставление и файл';

  @override
  String get sourcePreviewNotice =>
      'Предпросмотр источника · строки не импортированы';

  @override
  String get transferRequiresReview => 'Сначала проверьте именно эту передачу';

  @override
  String get transferSubmittedNotice =>
      'Отправлено · отмена не отменяет фиксации и опубликованные файлы';

  @override
  String get sqlExportExecutionNote => 'Новое проверенное выполнение SQL';

  @override
  String get retainedExportSnapshotNote =>
      'Полученный снимок; SQL не выполняется';

  @override
  String get restorePartialCommitNote =>
      'Восстановление может частично фиксироваться. Отмена не откатывает его.';

  @override
  String get sourcePreviewLimit => 'Предпросмотр источника · до 20 строк';

  @override
  String get importBatchSafetyNote =>
      'Ошибки и отмена сохраняют прежние фиксации. Хеши и неизменный источник проверяются перед отправкой.';

  @override
  String get nullMarkerLiteralNote =>
      'Маркер NULL без кавычек; в кавычках это буквальный текст';

  @override
  String immutableSourceHash(String hash) {
    return 'SHA-256 неизменного источника: $hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return 'Исходный столбец $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return 'Строка предпросмотра $row, $column: $value';
  }

  @override
  String get transferCancellationNotice =>
      'Запрошена отмена · ожидайте подтверждения';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed обработано · $committed зафиксировано · $rejected отклонено';
  }

  @override
  String get importAtomicPolicy => 'Все строки в одной транзакции';

  @override
  String get importBatchPolicy =>
      'Фиксировать пакетами; остановиться при ошибке';

  @override
  String get importSkipPolicy =>
      'Пропускать неверные строки; фиксировать пакетами';

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
    return 'Подтверждения/соединения: $operations\nНесохранённые документы: $documents\nСохранения в процессе: $saves\nОтложенные изменения: $edits\nАктивные задания: $jobs\nТранзакции для очистки: $transactions\nНеизвестные исходы: $unknown\nНеопределённые сеансы: $sessions';
  }

  @override
  String get closeDraftSaved => 'Черновики SQL будут сохранены локально.';

  @override
  String get closeDraftLost =>
      'Восстановление отключено; несохранённые SQL и проекты объектов будут потеряны.';

  @override
  String get closeDesignRecovery =>
      'Проекты используют частное ограниченное восстановление. После открытия явно подключитесь и проверьте метаданные.';

  @override
  String get closeCleanupReview =>
      'Закрытие последнего владельца запрашивает отмену, откатывает подтверждённые транзакции и отключает. Неизвестные исходы остаются неизвестными; SQL не фиксируется и не повторяется.';

  @override
  String get closeSharedSession =>
      'Другие клиенты сохраняют общий физический сеанс.';

  @override
  String get closeStagedRecovery =>
      'Изменения требуют подтверждённого частного восстановления, явного подключения и новой проверки.';

  @override
  String get closeRecoveryLoss =>
      'Документы и раскладка не сохранены. Закрытие может потерять SQL и изменения; прежние файлы и данные восстановления сохраняются.';

  @override
  String get closeWaitNotice =>
      'Перед закрытием дождитесь подтверждений и очистки соединений.';

  @override
  String get saveFailedNotice =>
      'Не удалось сохранить SQL. Сохраните изменённый текст или явно отбросьте.';

  @override
  String get closeCleanupFailed =>
      'Очистка backend не удалась; BusyData остаётся открытым.';

  @override
  String get closeBackendUnverified =>
      'Состояние backend не проверено; задания могут ещё выполняться.';

  @override
  String historyRetainSqlReview(String days) {
    return 'SQL может содержать секреты. Хранить текст $days дней?';
  }

  @override
  String get historyStopSqlReview =>
      'Прекратить хранение SQL и удалить его из прежней истории?';

  @override
  String get historyClearReview =>
      'Удалить всю историю? Активные задания могут записать исход по завершении.';

  @override
  String get historyDeleteReview => 'Удалить выбранную запись?';

  @override
  String get historyRetentionRange => 'Срок хранения должен быть 1–3650 дней';

  @override
  String get enableSqlHistory => 'Включить историю SQL';

  @override
  String get stopSqlHistory => 'Прекратить хранение SQL';

  @override
  String get recoveryDiscardReview =>
      'Отбросить восстановление? Сначала выясните неизвестные исходы; это не отменяет фиксаций.';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return 'Несохранённое SQL: $unsaved\nИзменения: $edits\nАктивные задания: $jobs';
  }

  @override
  String get recoveryStayOpen =>
      'Восстановление не удалось. BusyData остаётся открытым; несохранённая работа сохраняется.';

  @override
  String get commitUncertaintyNote =>
      'Сбой сети может оставить исход фиксации неизвестным. Никогда не повторяйте автоматически.';

  @override
  String get closeObjectDesignDiscard =>
      'Несохранённые поля проекта будут отброшены. Сначала создайте и сохраните SQL, чтобы сохранить проект.';

  @override
  String get savePrivateDrafts => 'Сохранять частные черновики восстановления';

  @override
  String get noPrivateDrafts => 'Не сохранять черновики восстановления';

  @override
  String shortcutField(String command) {
    return 'Клавиши для $command';
  }

  @override
  String get shortcutInvalid =>
      'Используйте допустимое сочетание, не назначенное другому действию. F6 и Shift+F6 зарезервированы.';

  @override
  String get disableRecoveryReview =>
      'Удалить локальное восстановление SQL, проектов и изменений? Несохранённая работа остаётся открытой; сбой может её потерять. Сначала выясните неизвестные исходы.';

  @override
  String get preferencesSaved => 'Настройки сохранены';

  @override
  String get sharingSessionReview =>
      'Запрос разделяет названный физический сеанс, транзакцию, временные объекты и настройки с указанными клиентами. Закрытие одного сохраняет остальных.';

  @override
  String get recoveryReconcileFirst =>
      'Перед отключением восстановления выясните текущие или неизвестные изменения. Отбрасывайте записи только через их явную проверку.';

  @override
  String get enterSearchText => 'Введите текст поиска';

  @override
  String get noSearchMatches => 'Совпадений нет';

  @override
  String searchMatchCount(String position, String total) {
    return 'Совпадение $position из $total';
  }

  @override
  String get formatSqlChanged =>
      'SQL или цель изменились. Исходный SQL сохранён; запросите новый просмотр форматирования.';

  @override
  String get formatSqlUnavailable =>
      'Форматирование недоступно для неполного или неподдерживаемого синтаксиса или при лимитах анализа. Исходный SQL сохранён.';

  @override
  String get stageChange => 'Подготовить изменение';

  @override
  String pendingChangesCount(String count) {
    return 'Ожидающих изменений: $count; база неизменна до проверенного применения.';
  }

  @override
  String discardChangesCount(String count) {
    return 'Отбросить $count ожидающих изменений? Операция базы данных не отправляется.';
  }

  @override
  String get recoveryNoExecution =>
      'Восстановление не подключается, не выполняет исходный SQL, не возобновляет транзакции и не повторяет изменения. Записи с неизвестным или подтверждённым исходом не применяются повторно.';

  @override
  String get recoveredDesign =>
      'Проект восстановлен. Явно подключитесь и проверьте текущие метаданные перед новой проверкой. Восстановление не запрашивало SQL или метаданные.';

  @override
  String get retainedUnavailable =>
      'Сохранённые данные недоступны. Записанный SQL и частное восстановление остаются локально.';

  @override
  String get activityFingerprintNote =>
      'Отпечаток выбранной активности проверяется перед отправкой. Исход записи может быть неизвестным.';

  @override
  String replaceFileReview(String path) {
    return 'Заменить проверенный файл в $path? Изменённая цель требует новой проверки.';
  }

  @override
  String get diagramPngSaved =>
      'PNG диаграммы сохранён. Длинные заметки показывают до шести строк.';

  @override
  String get editTargetChanged =>
      'Цель редактирования изменилась. Откройте редактор строки заново перед подготовкой.';

  @override
  String affectedRowCount(String count) {
    return 'Затронутые строки: $count';
  }

  @override
  String get zoomIn => 'Приблизить';

  @override
  String get zoomOut => 'Отдалить';

  @override
  String get resetView => 'Сбросить вид';

  @override
  String get diagramKeys =>
      'Стрелки перемещают; + и - меняют масштаб; Home сбрасывает вид.';

  @override
  String get explorerConnected => 'Обозреватель подключён';

  @override
  String get explorerDisconnected => 'Обозреватель отключён';

  @override
  String querySessionCount(String count) {
    return 'Сеансы запросов $count';
  }

  @override
  String get metadataColumn => 'Столбец';

  @override
  String get metadataPosition => 'Позиция';

  @override
  String get metadataUnique => 'Уникальный';

  @override
  String get metadataJdbcType => 'Тип JDBC';

  @override
  String get metadataAutoIncrement => 'Автоинкремент';

  @override
  String get metadataReferencedColumn => 'Связанный столбец';

  @override
  String get metadataComment => 'Комментарий';

  @override
  String get metadataType => 'Тип';

  @override
  String get metadataEvent => 'Событие';

  @override
  String get metadataSpecificName => 'Собственный уникальный идентификатор';

  @override
  String get metadataOptions => 'Параметры';

  @override
  String get metadataInheritance => 'Наследование';

  @override
  String get metadataDefinitionCaptured =>
      'Сохранённое собственное определение';

  @override
  String get metadataDefinitionUnavailable =>
      'Определение недоступно в сохранённых метаданных';

  @override
  String get metadataDefinitionUnsupported =>
      'У сохранённого объекта нет поддерживаемого собственного определения';

  @override
  String get connections => 'Подключения';

  @override
  String get noConnections => 'Подключений пока нет';

  @override
  String get startTitle => 'Подключиться к базе данных';

  @override
  String get startDescription =>
      'Подключитесь к PostgreSQL, MySQL или MariaDB для просмотра объектов, управления данными и выполнения запросов.';

  @override
  String get savedStartTitle => 'Выберите подключение';

  @override
  String get savedStartDescription =>
      'Подключитесь к сохранённому подключению в обозревателе для просмотра объектов и выполнения запросов.';

  @override
  String get noConnection => 'Нет подключения';

  @override
  String queryTitle(int number) {
    return 'Запрос $number';
  }

  @override
  String get sessionMenu => 'Сеанс';

  @override
  String get noFilterMatches =>
      'Нет подходящих подключений или загруженных объектов';

  @override
  String get activityState => 'Состояние';

  @override
  String get activityWait => 'Ожидание';

  @override
  String get generalSettings => 'Общие';

  @override
  String get optionsSettings => 'Параметры';

  @override
  String get host => 'Сервер';

  @override
  String get databaseSystem => 'Система базы данных';

  @override
  String get passwordStorage => 'Хранение пароля';

  @override
  String get environmentLabel => 'Среда';

  @override
  String get readOnlySettings => 'Режим только для чтения';

  @override
  String get tlsPolicy => 'Политика TLS';

  @override
  String get sshConnection => 'Подключение SSH';

  @override
  String get sshAuthentication => 'Аутентификация SSH';

  @override
  String get connectionTestAction => 'Проверить подключение';

  @override
  String get details => 'Подробности';

  @override
  String get copyDetails => 'Копировать подробности';

  @override
  String get retry => 'Повторить';

  @override
  String get filterCellValue => 'Фильтровать по этому значению';

  @override
  String get connectsWhenRun => 'Подключение при выполнении';

  @override
  String get connectionSaving => 'Сохранить…';

  @override
  String get connectionConnecting => 'Подключить…';

  @override
  String get connectionCancelling => 'Отмена…';

  @override
  String get connectionSettingsChanged =>
      'Настройки изменены. Проверьте эту версию снова.';

  @override
  String get connectionTestChanged =>
      'Настройки изменены. Проверьте эту версию снова.';

  @override
  String get connectionRequired => 'Обязательно';

  @override
  String get connectionCorrectFields => 'Проверьте указанные настройки.';

  @override
  String get connectionHostname => 'Сервер · Проверьте указанные настройки.';

  @override
  String get connectionSshHostname =>
      'SSH · Сервер · Проверьте указанные настройки.';

  @override
  String get connectionMaxLength => 'Имя ≤ 256';

  @override
  String get connectionTlsHelp =>
      'TLS · Сервер · SSH/SSL. Проверьте указанные настройки.';

  @override
  String get connectionTlsReview =>
      'TLS · Сервер · SSH/SSL. Проверьте указанные настройки.';

  @override
  String get connectionStorageUnavailable =>
      'Хранение пароля: Недоступно. Пароль · Никогда.';

  @override
  String get connectionHostReviewed =>
      'Сервер · Доверие относится только к этому профилю и точному адресу подключения.';

  @override
  String get connectionSshReviewing => 'SSH · Проверить ключ хоста SSH…';

  @override
  String get connectionFailureAuthentication =>
      'Ошибка · Аутентификация · Общие. Проверьте указанные настройки.';

  @override
  String get connectionFailureTls =>
      'Ошибка · TLS · SSH/SSL. Проверьте указанные настройки.';

  @override
  String get connectionFailureSshKey =>
      'Ошибка · Проверить ключ хоста SSH. Проверьте указанные настройки.';

  @override
  String get connectionFailureEndpoint =>
      'Ошибка · Сервер · Порт. Проверьте указанные настройки.';

  @override
  String get connectionFailureCancelled => 'Отменено';

  @override
  String get connectionFailureSettings =>
      'Ошибка · Общие. Проверьте указанные настройки.';

  @override
  String get connectionFailureAccess =>
      'Ошибка · Права таблицы / представления. Проверьте указанные настройки.';

  @override
  String get connectionFailureUnavailable =>
      'Ошибка · Сервер · TLS · SSH. Проверьте указанные настройки.';

  @override
  String get connectionFailureTimeout =>
      'Ошибка · Тайм-аут подключения · 1–120 секунд. Проверьте указанные настройки.';

  @override
  String get connectionFailureUnknown =>
      'Ошибка · Общие · TLS · SSH. Проверьте указанные настройки.';

  @override
  String connectionNumber(int min, int max) {
    return 'Введите целое число от $min до $max';
  }

  @override
  String connectionSavedFailure(String name) {
    return 'Подключение сохранено: $name. Попытка подключения не удалась. ';
  }

  @override
  String get backendBusy =>
      'Сервер занят. Дождитесь завершения текущего запроса и повторите попытку.';

  @override
  String rpcRequestUnconfirmed(String code) {
    return 'Запрос не подтверждён (RPC $code).';
  }

  @override
  String get operationUnconfirmed => 'Не удалось завершить операцию.';

  @override
  String get connectionFailureTlsMaterial =>
      'Материалы TLS недоступны или некорректны. Проверьте источники доверия и ключ клиента в SSH/SSL.';

  @override
  String get managerTitle => 'Источники данных и драйверы';

  @override
  String get sourceListTitle => 'Источники данных';

  @override
  String get driverLabel => 'Драйвер';

  @override
  String get connectionTypeLabel => 'Тип подключения';

  @override
  String get defaultTcp => 'По умолчанию (TCP)';

  @override
  String get authenticationLabel => 'Аутентификация';

  @override
  String get userPasswordAuth => 'Пользователь и пароль';

  @override
  String get neverStorage => 'Никогда';

  @override
  String get initialDatabaseLabel => 'Начальная база данных';

  @override
  String get useSshTunnel => 'Использовать туннель SSH';

  @override
  String get sshConfigurationLabel => 'Конфигурация SSH';

  @override
  String get createSshConfig => '<создать конфигурацию>';

  @override
  String get copySshSettings => 'Копировать настройки SSH';

  @override
  String get localPortLabel => 'Локальный порт';

  @override
  String get dynamicPortLabel => '<Динамический>';

  @override
  String get useSsl => 'Использовать SSL';

  @override
  String get useTruststore => 'Использовать хранилище доверия';

  @override
  String get clientKeyPasswordLabel => 'Пароль ключа клиента';

  @override
  String get modeLabel => 'Режим';

  @override
  String get requireTls => 'Требовать';

  @override
  String get verifyCa => 'Проверять CA';

  @override
  String get fullVerification => 'Полная проверка';

  @override
  String get connectionSection => 'Подключение';

  @override
  String get configurationApplied => 'Конфигурация применена';

  @override
  String get noOtherSshConfig => 'У других источников нет конфигурации SSH.';

  @override
  String get generatedUrlHelp =>
      'Сформированный адрес JDBC, только для чтения.';

  @override
  String get tlsDriverDefaultHelp =>
      'SSL не настроен; встроенный драйвер использует значение по умолчанию.';

  @override
  String get tlsClientKeyHelp =>
      'Ключи PEM: PKCS#8 или OpenSSL; зашифрованные или незашифрованные.';

  @override
  String get legacyMariaTrustHelp =>
      'Существующая проверка драйвера сохраняется. Выберите источники доверия для явной настройки корневых сертификатов.';

  @override
  String get metadataStartValue => 'Начальное значение';

  @override
  String get metadataMinimumValue => 'Минимальное значение';

  @override
  String get metadataMaximumValue => 'Максимальное значение';

  @override
  String get metadataIncrement => 'Шаг';

  @override
  String get metadataCycle => 'Циклическая';

  @override
  String get metadataCacheSize => 'Размер кеша';

  @override
  String get metadataLastValue => 'Последнее значение';

  @override
  String get sequences => 'Последовательности';

  @override
  String get namespaceSelection => 'Выбор пространств имён';

  @override
  String get namespaceSelectionNotice =>
      'Выбор управляет интроспекцией. Консоли сохраняют свой контекст выполнения.';

  @override
  String get allNamespaces => 'Все пространства имён';

  @override
  String get defaultNamespace => 'По умолчанию';

  @override
  String get namespacePattern => 'Шаблон имени (регулярное выражение)';

  @override
  String namespaceCount(int selected, int known) {
    return '$selected из $known';
  }

  @override
  String get previousPage => 'Предыдущая страница';

  @override
  String get patternRejected =>
      'Шаблон недопустим или превышает лимит работы. Предыдущий выбор сохранён.';

  @override
  String get namespaceNotSelected =>
      'Пространство имён не выбрано для интроспекции';

  @override
  String get newMenu => 'Создать';

  @override
  String get queryConsoles => 'Консоли запросов';

  @override
  String get viewOptions => 'Параметры отображения';

  @override
  String get quickDocumentation => 'Быстрая документация';

  @override
  String get showEmptyGroups => 'Показывать пустые группы';

  @override
  String get speedSearch => 'Быстрый поиск';

  @override
  String get speedSearchScope => 'Только раскрытые и загруженные узлы.';

  @override
  String get newSourceFolder => 'Новая папка источников';

  @override
  String get renameSourceFolder => 'Переименовать папку';

  @override
  String get moveToFolder => 'Переместить в папку';

  @override
  String get moveUp => 'Переместить вверх';

  @override
  String get moveDown => 'Переместить вниз';

  @override
  String get folderMustBeEmpty =>
      'Перед удалением папки переместите содержащиеся в ней источники и папки.';

  @override
  String get newVirtualView => 'Новое виртуальное представление';

  @override
  String get editVirtualDefinition => 'Изменить локальное определение';

  @override
  String get unboundVirtualView => 'Непривязанные виртуальные представления';

  @override
  String get localVirtualViewNotice =>
      'Локальное определение SQL. Сохранение не выполняет SQL и не создаёт представление на сервере. Запуск использует обычную проверку SQL и независимую консоль.';

  @override
  String get rebindVirtualView => 'Привязать локальное определение здесь';

  @override
  String get sourceFolderName => 'Имя папки';

  @override
  String get sourceFolderPathNotice =>
      'Используйте / для создания вложенных папок.';

  @override
  String get topLevel => 'Верхний уровень';

  @override
  String get virtualViewName => 'Имя виртуального представления';

  @override
  String get virtualViewSql => 'SQL виртуального представления';

  @override
  String get virtualViews => 'Виртуальные представления';

  @override
  String get revealInExplorer => 'Показать в обозревателе баз данных';

  @override
  String get objectNotFound =>
      'Объект не найден в этом пространстве имён. Обновите метаданные или проверьте права.';

  @override
  String get objectHiddenByFilter =>
      'Объект скрыт текущим фильтром представления.';

  @override
  String get revealFilterNotice =>
      'Поиск сужает эту страницу; общее число объектов категории не показывается.';

  @override
  String get clearObjectFilter => 'Сбросить поиск объекта';

  @override
  String get compareStructure => 'Сравнить структуры';

  @override
  String get selectTwoCompatibleObjects =>
      'Выберите две совместимые таблицы с помощью Ctrl и щелчка.';

  @override
  String get scopedComparisonRestriction =>
      'Для сравнения нужны обычные таблицы с одинаковыми именем, схемой и СУБД. Другие типы и сопоставление переименований недоступны.';

  @override
  String get groupNamespaces => 'Группировать базы и схемы';

  @override
  String get groupSchemaObjects => 'Группировать объекты схемы';

  @override
  String get groupTableElements => 'Группировать элементы таблицы';

  @override
  String get sortAlphabetically => 'Сортировать по алфавиту';

  @override
  String get showVirtualObjects => 'Показывать виртуальные объекты';

  @override
  String get showObjectComments => 'Показывать комментарии объектов';

  @override
  String get objectTypeFilter => 'Фильтр типов объектов';

  @override
  String get partitionedTable => 'Секционированная таблица';

  @override
  String get foreignTable => 'Внешняя таблица';

  @override
  String get materializedView => 'Материализованное представление';

  @override
  String get functionObject => 'Функция';

  @override
  String get procedureObject => 'Процедура';

  @override
  String get sqlSymbolUnavailable =>
      'Не удалось безопасно определить постоянный объект у курсора. Подключите консоль и используйте ссылку на таблицу или представление вне строк и комментариев.';

  @override
  String get sqlSymbolAmbiguous =>
      'Неоднозначная ссылка SQL. Укажите пространство имён или выберите точный объект базы.';

  @override
  String get deactivateSource => 'Деактивировать источник';

  @override
  String get functions => 'Функции';

  @override
  String get procedures => 'Процедуры';

  @override
  String get separateProceduresFunctions => 'Разделять процедуры и функции';

  @override
  String get renameVirtualView => 'Переименовать виртуальное представление';

  @override
  String get metadataPersistentScope =>
      'Только постоянные объекты; временные и локальные объекты сеанса остаются в навигации консоли.';

  @override
  String get metadataSessionScope =>
      'Только постоянные объекты; обновите локальные объекты консоли после выполнения.';

  @override
  String get metadataLimitScope =>
      'Достигнут предел метаданных. Сузьте область объектов.';

  @override
  String get completeColumnMetadataRequired =>
      'Перед импортом или подготовкой изменений требуются полные метаданные столбцов.';

  @override
  String resizeColumn(String name) {
    return 'Изменить ширину столбца $name';
  }

  @override
  String get keyboardShortcutsHeading => 'Сочетания клавиш';

  @override
  String sqlEditorLabel(String title) {
    return 'Редактор SQL $title';
  }

  @override
  String get editorResultsDivider => 'Разделитель редактора и результатов';

  @override
  String editorExtent(String percent) {
    return 'Редактор: $percent процентов';
  }

  @override
  String get largerEditor => 'Увеличить редактор';

  @override
  String get smallerEditor => 'Уменьшить редактор';

  @override
  String get explorerWidthDivider => 'Разделитель ширины обозревателя';

  @override
  String get widerExplorer => 'Расширить обозреватель';

  @override
  String get narrowerExplorer => 'Сузить обозреватель';

  @override
  String explorerExtent(String width) {
    return 'Ширина: $width пикселей';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '$start–$end из $total единиц UTF-16';
  }

  @override
  String get dropDesignedColumn => 'Удалить столбец';

  @override
  String get liveCatalogLabel => 'Текущий каталог';

  @override
  String get liveSchemaLabel => 'Текущая схема';

  @override
  String get searchPathLabel => 'Путь поиска';

  @override
  String get physicalSessionLabel => 'Физический сеанс';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return 'Тайм-аут: $seconds с · Ограничение строк: $rows';
  }

  @override
  String get saveFailedCloseTitle =>
      'Не удалось сохранить SQL · Закрыть BusyData';

  @override
  String get createSection => 'Создать';

  @override
  String get newConnectionDescription => 'Настроить подключение к базе данных';

  @override
  String get newQueryDescription => 'Написать SQL в новом запросе';

  @override
  String get openSqlDescription => 'Открыть существующий документ SQL';

  @override
  String get searchNoResults => 'Подходящие действия не найдены';

  @override
  String get actionsCategory => 'Действия';

  @override
  String get privateRecoveryCategory => 'Частное восстановление';

  @override
  String get shortcutRecordHelp =>
      'Нажмите сочетание клавиш. Escape отменяет. F6 и Shift+F6 зарезервированы для перехода между панелями.';

  @override
  String get rowLimitInvalid => 'Введите ограничение от 1 до 1 000 000 строк.';

  @override
  String get errorPolicy => 'При ошибке выполнения';

  @override
  String get tlsEncrypted => 'зашифровано';

  @override
  String get tlsUnencrypted => 'не зашифровано';

  @override
  String get tlsUnobserved => 'не наблюдалось';

  @override
  String get encryptionVerificationNote =>
      'Шифрование не подтверждает проверку сертификата или имени сервера.';

  @override
  String get uniqueDesignedColumnName =>
      'Используйте уникальное имя столбца; новые таблицы поддерживают до 128 столбцов';

  @override
  String activityBlockerUnavailable(String id) {
    return 'Блокирующая сессия $id больше не видна; обновите и проверьте разрешения базы данных';
  }

  @override
  String get sshChangedKeyReview =>
      'Независимо проверьте изменённый ключ перед заменой его привязки к профилю.';

  @override
  String get sshProfileTrustBinding =>
      'Доверие относится только к этому профилю и точному адресу подключения.';

  @override
  String get databaseTlsEvidence => 'TLS · Система базы данных';

  @override
  String get sshAlgorithmLabel => 'SSH · Тип';

  @override
  String get sshFingerprintLabel => 'SHA-256';

  @override
  String get sshPreviousFingerprintLabel => 'Назад · SHA-256';

  @override
  String get sshReviewedLabel => 'Проверить ключ хоста SSH';

  @override
  String get shortcutRecordAction => 'Записать сочетание';

  @override
  String get fileFormatLabel => 'Формат файла';

  @override
  String get encodingLabel => 'Кодировка';

  @override
  String get importPolicyLabel => 'Политика импорта';

  @override
  String get mainMenu => 'Главное меню';

  @override
  String get activityReplyTooLarge =>
      'Ответ о действиях превышает лимит инспектора.';

  @override
  String get activityListLimited =>
      'Список ограничен; исследуйте более узкую цель с помощью явного SQL.';

  @override
  String get activitySelectionChanged =>
      'Выбранное действие завершилось или изменилось. Перед проверкой операции выберите его текущий идентификатор.';

  @override
  String connectionSavedDraftChanged(String name) {
    return 'Поля подключения изменились при сохранении; конфигурация сохранена: $name. Проверьте текущие значения перед подключением.';
  }

  @override
  String get sshReviewTargetChanged =>
      'Цель проверки SSH изменилась; выполните проверку снова';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get theme => 'Тема оформления';

  @override
  String get systemTheme => 'Как в системе';

  @override
  String get lightTheme => 'Светлая';

  @override
  String get darkTheme => 'Тёмная';

  @override
  String get appLanguage => 'Язык интерфейса';

  @override
  String get systemLanguage => 'Как в системе';

  @override
  String get cut => 'Вырезать';

  @override
  String get paste => 'Вставить';

  @override
  String get selectAll => 'Выделить всё';

  @override
  String get noSelection => 'Нет доступного текста';

  @override
  String get clipboardEmpty => 'В буфере обмена нет текста';

  @override
  String get settingsDraftNotice =>
      'Изменения выполнения и приватного восстановления не сохранены.';

  @override
  String get documentsMenu => 'Документы';

  @override
  String get currentSql => 'Текущий SQL';

  @override
  String get searchActionsHint => 'Поиск действий…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => 'Свойства';

  @override
  String get metadataSelectionUnavailable =>
      'Выберите элемент для просмотра сохранённых свойств. Предыдущий выбор недоступен.';

  @override
  String get secureStorage => 'Защищённое хранилище ОС';

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
      'Не удалось сохранить кэш. Текущие метаданные остаются доступны.';

  @override
  String get metadataCacheRebuiltVersion => 'Перестроен для текущей версии';

  @override
  String get metadataCacheRebuiltCorrupt => 'Перестроен после ошибки кэша';

  @override
  String get editSessionBusy =>
      'Этот сеанс занят. Дождитесь завершения текущей операции, затем запросите новую оценку возможности редактирования.';

  @override
  String get editIdentityRequired =>
      'Перед редактированием выберите полный первичный ключ или уникальный идентификатор, не допускающий значений NULL.';

  @override
  String get editColumnsReadOnly =>
      'Все столбцы проекции являются генерируемыми или доступны только для чтения.';

  @override
  String get editResultNotReady =>
      'Дождитесь завершения этого сохранённого результата, прежде чем запрашивать новую оценку возможности редактирования.';

  @override
  String get editProjectionUnsupported =>
      'Для редактирования нужен прямой SELECT из одной базовой таблицы, в котором каждый базовый столбец выбран только один раз.';

  @override
  String get sqlInspectionDuplicateUsingColumn =>
      'Повторяющийся столбец JOIN USING';

  @override
  String get sqlInspectionUnresolvedUsingColumn =>
      'Столбец JOIN USING отсутствует в одном из операндов';

  @override
  String get sqlInspectionAmbiguousUsingColumn =>
      'Неоднозначный общий столбец JOIN';

  @override
  String get sqlInspectionOutputColumnCount =>
      'Число объявленных выходных столбцов не совпадает';

  @override
  String get sqlInspectionAmbiguousOverload =>
      'Неоднозначная перегрузка подпрограммы';

  @override
  String get sqlInspectionBooleanType =>
      'Недопустимый тип логического выражения';

  @override
  String get sqlInspectionOperatorTypes =>
      'Несовместимые типы операндов оператора';

  @override
  String get sqlInspectionArrayTypes => 'Несовместимые типы элементов массива';

  @override
  String get sqlInspectionCaseConditionType => 'Несовместимый тип условия CASE';

  @override
  String get sqlInspectionCaseResultTypes =>
      'Несовместимые типы результатов CASE';

  @override
  String get sqlInspectionCoalesceTypes =>
      'Несовместимые типы аргументов COALESCE';

  @override
  String get sqlInspectionSetColumnCount =>
      'Число столбцов операции над множествами не совпадает';

  @override
  String get sqlInspectionSetTypes =>
      'Несовместимые типы результатов операции над множествами';

  @override
  String get sqlInspectionRecursiveCteType =>
      'Несовпадение типов рекурсивного CTE';
}
