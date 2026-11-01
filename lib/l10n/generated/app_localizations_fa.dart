// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get cancel => 'لغو';

  @override
  String get windowMinimize => 'کوچک کردن';

  @override
  String get windowMaximize => 'بزرگ کردن';

  @override
  String get windowRestore => 'بازیابی';

  @override
  String get databaseExplorer => 'کاوشگر پایگاه داده';

  @override
  String get databases => 'پایگاه‌های داده';

  @override
  String get newConnection => 'اتصال جدید';

  @override
  String get filterTree => 'فیلتر اتصال‌ها و اشیا';

  @override
  String get treeFilterScope => 'اشیای بارگذاری‌شدهٔ درخت را فیلتر می‌کند';

  @override
  String get searchObjects => 'جستجوی اشیای پایگاه داده';

  @override
  String get fileMenu => 'پرونده';

  @override
  String get editMenu => 'ویرایش';

  @override
  String get viewMenu => 'نمایش';

  @override
  String get connectionMenu => 'اتصال';

  @override
  String get objectMenu => 'شیء';

  @override
  String get runMenu => 'گزینه‌های اجرا';

  @override
  String get commands => 'فرمان‌ها';

  @override
  String get findCommand => 'جستجوی فرمان';

  @override
  String get newSql => 'پرس‌وجوی جدید';

  @override
  String get openSql => 'باز کردن SQL';

  @override
  String get openSqlFile => 'باز کردن فایل SQL';

  @override
  String get saveSql => 'ذخیره SQL';

  @override
  String get closeTab => 'بستن زبانه';

  @override
  String get openWorkspace => 'باز کردن فضای کار';

  @override
  String get saveWorkspace => 'ذخیره فضای کار';

  @override
  String get settings => 'تنظیمات';

  @override
  String get findText => 'جستجو';

  @override
  String get replaceText => 'جایگزینی';

  @override
  String get formatSql => 'قالب‌بندی SQL';

  @override
  String get lineComments => 'تغییر وضعیت توضیحات خطی';

  @override
  String get snippets => 'قطعه‌های SQL';

  @override
  String get run => 'اجرا';

  @override
  String get runStatement => 'اجرای دستور کنونی';

  @override
  String get runSelection => 'اجرای بخش انتخابی';

  @override
  String get runScript => 'اجرای اسکریپت';

  @override
  String get explain => 'توضیح طرح';

  @override
  String get explainAnalyze => 'توضیح و تحلیل';

  @override
  String get connect => 'اتصال';

  @override
  String get disconnect => 'قطع اتصال';

  @override
  String get sessionDetails => 'جزئیات نشست';

  @override
  String get beginTransaction => 'شروع تراکنش';

  @override
  String get commitTransaction => 'تثبیت تراکنش';

  @override
  String get rollbackTransaction => 'بازگردانی تراکنش';

  @override
  String get enableAutoCommit => 'فعال کردن تثبیت خودکار';

  @override
  String get disableAutoCommit => 'غیرفعال کردن تثبیت خودکار';

  @override
  String get outcomeUnknown => 'نتیجه نامعلوم';

  @override
  String get outcomeUnknownNote =>
      'ممکن است عملیات تکمیل شده باشد. این نشست نمی‌تواند SQL بیشتری اجرا کند. هرگز به‌طور خودکار دوباره تلاش نکنید؛ پیش از شروع کار جدید، نتیجه را بررسی کنید.';

  @override
  String get notConnected => 'قطع‌شده';

  @override
  String get autoCommit => 'تثبیت خودکار';

  @override
  String get manualTransaction => 'تراکنش دستی';

  @override
  String get readOnlyPolicy => 'سیاست فقط‌خواندنی BusyData';

  @override
  String get data => 'داده‌ها';

  @override
  String get structure => 'ساختار';

  @override
  String get results => 'نتایج';

  @override
  String get messages => 'پیام‌ها';

  @override
  String get plan => 'طرح';

  @override
  String get changes => 'تغییرات';

  @override
  String get history => 'تاریخچه';

  @override
  String get jobs => 'کارها';

  @override
  String get retainedResults => 'نتایج نگهداری‌شده';

  @override
  String get recoverEdits => 'بازیابی تغییرات آماده‌شده';

  @override
  String get applyAndCommit => 'اعمال و تثبیت';

  @override
  String get inspectStructure => 'بررسی ساختار';

  @override
  String get openData => 'باز کردن داده‌ها';

  @override
  String get openDefinition => 'باز کردن تعریف';

  @override
  String get copyQualifiedName => 'رونوشت نام کامل';

  @override
  String get refresh => 'بازآوری';

  @override
  String get columns => 'ستون‌ها';

  @override
  String get indexes => 'نمایه‌ها';

  @override
  String get constraints => 'کلیدها و محدودیت‌ها';

  @override
  String get foreignKeys => 'کلیدهای خارجی';

  @override
  String get triggers => 'تریگرها';

  @override
  String get definition => 'تعریف';

  @override
  String get dependencies => 'وابستگی‌ها';

  @override
  String get connectionCapabilities => 'نمای کلی اتصال';

  @override
  String get sessionsAndLocks => 'نشست‌ها و قفل‌ها';

  @override
  String get usersAndRoles => 'کاربران و نقش‌ها';

  @override
  String get saveSnapshot => 'ذخیره تصویر لحظه‌ای طرحواره';

  @override
  String get compareSchemas => 'مقایسه طرحواره‌ها';

  @override
  String get objectDesigner => 'طراح شیء';

  @override
  String get diagram => 'نمودار موجودیت و رابطه';

  @override
  String get backup => 'پشتیبان‌گیری';

  @override
  String get restore => 'بازیابی';

  @override
  String get importData => 'درون‌ریزی داده‌ها';

  @override
  String get exportRetained => 'برون‌ریزی داده‌های نگهداری‌شده';

  @override
  String get exportSql => 'اجرای برون‌ریزی SQL';

  @override
  String get stageInsert => 'درج ردیف';

  @override
  String get stageUpdate => 'ویرایش ردیف';

  @override
  String get stageDelete => 'حذف ردیف';

  @override
  String get discardChanges => 'کنار گذاشتن تغییرات معلق';

  @override
  String get disposeResult => 'آزاد کردن داده‌های نگهداری‌شده';

  @override
  String get currentSchema => 'طرحواره کنونی (برای تغییر)';

  @override
  String get desiredSchema => 'طرحواره مطلوب';

  @override
  String get applyTo => 'اعمال روی';

  @override
  String get loading => 'در حال بارگیری';

  @override
  String get empty => 'شیئی در این محدوده وجود ندارد';

  @override
  String get more => 'بیشتر';

  @override
  String get filter => 'پالایش';

  @override
  String get sort => 'مرتب‌سازی';

  @override
  String get selectTarget => 'انتخاب اتصال';

  @override
  String get requireSql => 'به سند SQL نیاز دارد';

  @override
  String get requireSession => 'به نشست متصل با وضعیت مشخص نیاز دارد';

  @override
  String get requireResult => 'به داده‌های نگهداری‌شده نیاز دارد';

  @override
  String get requireObject => 'به شیء هدف نیاز دارد';

  @override
  String get cancelRequested => 'لغو درخواست شد';

  @override
  String get cancelled => 'لغو شد';

  @override
  String get queued => 'در صف';

  @override
  String get running => 'در حال اجرا';

  @override
  String get completed => 'تکمیل شد';

  @override
  String get failed => 'ناموفق';

  @override
  String get partial => 'جزئی';

  @override
  String get sessionSharing => 'اشتراک نشست موجود (پیشرفته)';

  @override
  String get production => 'عملیاتی';

  @override
  String get staging => 'پیش از عملیات';

  @override
  String get development => 'توسعه';

  @override
  String get executionOptions => 'تنظیمات اجرا';

  @override
  String get resultRowLimit => 'حد ردیف‌های نتیجه (1–1000000)';

  @override
  String get boundedRead => 'خواندن محدود';

  @override
  String get streamingRead => 'خواندن جریانی · مالک تراکنش خواندن';

  @override
  String get stopOnError => 'توقف اسکریپت در خطا';

  @override
  String get continueOnError =>
      'ادامه در خطا · دستورهای پیشین ممکن است تثبیت شده باشند';

  @override
  String get loadMore => 'بارگیری بیشتر';

  @override
  String get favorite => 'تغییر وضعیت علاقه‌مندی';

  @override
  String get connectionGroup => 'گروه اتصال';

  @override
  String get copyRange => 'رونوشت محدوده';

  @override
  String get inspectValue => 'بررسی مقدار';

  @override
  String get editConnection => 'ویرایش اتصال';

  @override
  String get chooseSnapshot => 'انتخاب تصویر لحظه‌ای';

  @override
  String get captureSchema => 'ثبت طرحواره';

  @override
  String get sameSchemaRestriction =>
      'تصاویر لحظه‌ای باید موتور پایگاه داده، نام طرحواره و نسخه یکسان داشته باشند. مقایسه و ذخیره هرگز تغییرات را اعمال نمی‌کنند.';

  @override
  String get restoredTaskState =>
      'مرجع این سند بازیابی شد. شواهد سرور، نشست‌ها و کارهای قبلی در دسترس نیستند. برای بررسی یا آغاز کار تازه، اقدام مشخصی انتخاب کنید؛ بازیابی هرگز متصل نمی‌شود، SQL اجرا نمی‌کند یا تغییرات را دوباره اعمال نمی‌کند.';

  @override
  String get preChangeSnapshot =>
      'تصویر پیش از تغییر · تغییرات تثبیت شدند. برای بررسی ردیف‌های کنونی و مقادیر پیش‌فرض سرور، صریحاً بازآوری کنید.';

  @override
  String get sqlProvenance => 'منشأ SQL';

  @override
  String get assessEditing => 'ارزیابی ویرایش‌پذیری';

  @override
  String get viewDetails => 'نمایش جزئیات';

  @override
  String get gridMenu => 'شبکه داده';

  @override
  String get visibleColumns => 'ستون‌های نمایان';

  @override
  String get hidden => 'پنهان';

  @override
  String get ascending => 'صعودی';

  @override
  String get descending => 'نزولی';

  @override
  String get equals => 'برابر';

  @override
  String get notEqual => 'نابرابر';

  @override
  String get lessThan => 'کمتر از';

  @override
  String get greaterThan => 'بیشتر از';

  @override
  String get isNull => 'NULL است';

  @override
  String get isNotNull => 'NULL نیست';

  @override
  String get exactValue => 'مقدار دقیق';

  @override
  String get sortTable => 'مرتب‌سازی داده جدول';

  @override
  String get filterTable => 'پالایش داده جدول';

  @override
  String get sortRetained => 'مرتب‌سازی تصویر نگهداری‌شده';

  @override
  String get filterRetained => 'پالایش تصویر نگهداری‌شده';

  @override
  String get applyView => 'اعمال';

  @override
  String get rowsLabel => 'ردیف‌ها';

  @override
  String get fetchedRows => 'ردیف‌های دریافت‌شده';

  @override
  String get fixedSnapshot => 'تصویر ثابت ردیف‌های دریافت‌شده';

  @override
  String get limitReached => 'حد مجاز رسید';

  @override
  String get retainedData => 'داده نگهداری‌شده';

  @override
  String get applyRequiresAutoCommit =>
      'اعمال و تثبیت به نشست بیکار با تثبیت خودکار فعال نیاز دارد.';

  @override
  String get connectionProfile => 'پروفایل اتصال';

  @override
  String get basic => 'پایه';

  @override
  String get advanced => 'پیشرفته';

  @override
  String get connectionName => 'نام';

  @override
  String get hostname => 'نام میزبان (برای بررسی TLS هم استفاده می‌شود)';

  @override
  String get port => 'درگاه';

  @override
  String get database => 'پایگاه داده';

  @override
  String get user => 'کاربر';

  @override
  String get password => 'گذرواژه';

  @override
  String get writableProfile => 'پروفایل قابل نوشتن';

  @override
  String get readonlyProfile => 'پروفایل فقط‌خواندنی';

  @override
  String get tlsVerify => 'TLS: بررسی گواهی و نام میزبان';

  @override
  String get tlsInsecure => 'TLS: ناامن، بدون بررسی';

  @override
  String get tlsDisabled => 'TLS: غیرفعال';

  @override
  String get testConnection => 'آزمایش بدون ذخیره';

  @override
  String get saveProfile => 'ذخیره';

  @override
  String get saveConnect => 'ذخیره و اتصال';

  @override
  String get sessionPassword => 'گذرواژه فقط برای این نشست';

  @override
  String get storedPassword => 'ذخیره گذرواژه در فضای امن سیستم عامل';

  @override
  String get chooseFile => 'انتخاب پرونده';

  @override
  String get testRunning => 'در حال آزمایش اتصال…';

  @override
  String get cancelTest => 'لغو آزمایش';

  @override
  String get idle => 'بی‌کار';

  @override
  String get activeTransaction => 'تراکنش باز';

  @override
  String get failedTransaction => 'تراکنش ناموفق';

  @override
  String get inspectionContext => 'نشست بررسی';

  @override
  String get requireTableOrView => 'جدول یا نما را انتخاب کنید';

  @override
  String get operationPending => 'عملیات سند در انتظار تأیید است';

  @override
  String get requirePlan => 'اجرای نگهداری‌شده Explain را انتخاب کنید';

  @override
  String get openPlanDocument => 'باز کردن سند طرح';

  @override
  String get locks => 'قفل‌ها';

  @override
  String get statistics => 'آمار';

  @override
  String get queryStatistics => 'آمار پرس‌وجو';

  @override
  String get indexDiagnostics => 'عیب‌یابی نمایه';

  @override
  String get grants => 'مجوزهای اعطاشده';

  @override
  String get sqlExecution => 'اجرای SQL';

  @override
  String get planReady => 'طرح نگهداری‌شده آماده است؛ SQL دوباره اجرا نشد';

  @override
  String get executionPlan => 'طرح اجرا';

  @override
  String get openOwner => 'باز کردن مالک';

  @override
  String get terminateActivity => 'پایان دادن به فعالیت';

  @override
  String get close => 'بستن';

  @override
  String get previous => 'قبلی';

  @override
  String get next => 'بعدی';

  @override
  String get replaceSelection => 'جایگزینی انتخاب';

  @override
  String get replaceAll => 'جایگزینی همه';

  @override
  String get restartBackend => 'راه‌اندازی مجدد فرایند پشتیبان';

  @override
  String get structuredTree => 'درخت ساختاری';

  @override
  String get rawOutput => 'خروجی خام';

  @override
  String get previousTextPage => 'صفحه متن قبلی';

  @override
  String get nextTextPage => 'صفحه متن بعدی';

  @override
  String get filterChangedObjects => 'فیلتر اشیای تغییرکرده';

  @override
  String get rebindVerifiedEdits => 'پیوند دوباره ویرایش‌های تأییدشده';

  @override
  String get discardRecoveryRecord => 'حذف رکورد بازیابی';

  @override
  String get revertChange => 'بازگردانی تغییر در انتظار';

  @override
  String get chooseSource => 'انتخاب منبع';

  @override
  String get chooseDestination => 'انتخاب مقصد';

  @override
  String get delimiterField => 'جداکننده (یک نویسه)';

  @override
  String get batchRowsField => 'ردیف در هر دسته (1–1000)';

  @override
  String get rejectedLimit => 'حد ردیف‌های ردشده (1–1000)';

  @override
  String get previewSource => 'پیش‌نمایش منبع';

  @override
  String get reviewTransfer => 'بازبینی انتقال';

  @override
  String get startImport => 'شروع واردکردن';

  @override
  String get startRestore => 'شروع بازیابی';

  @override
  String get startExport => 'شروع صادرکردن';

  @override
  String get requestCancel => 'درخواست لغو';

  @override
  String get sourceMapping => 'نگاشت منبع و مقصد';

  @override
  String get nativeTool => 'ابزار بومی';

  @override
  String get defaultOmit => 'حذف / پیش‌فرض پایگاه داده';

  @override
  String get overwriteNever => 'بازنویسی نشود';

  @override
  String get overwriteExisting => 'بازنویسی فایل موجود';

  @override
  String get planDetails => 'جزئیات طرح';

  @override
  String get planMetricsNote =>
      'برآوردها و اندازه‌گیری‌های واقعی از نام فیلدهای سرور استفاده می‌کنند. اندازه‌گیری‌های غایب در دسترس نیستند.';

  @override
  String get connected => 'متصل';

  @override
  String get disconnected => 'قطع‌شده';

  @override
  String get tables => 'جدول‌ها';

  @override
  String get views => 'نماها';

  @override
  String get routines => 'روال‌ها';

  @override
  String get expand => 'گسترش';

  @override
  String get collapse => 'جمع‌کردن';

  @override
  String get databaseWorkbench => 'میز کار پایگاه داده';

  @override
  String get sidebar => 'نوار کناری';

  @override
  String get unchanged => 'بدون تغییر';

  @override
  String get reviewDetails => 'جزئیات بازبینی';

  @override
  String get generatedSql => 'SQL تولیدشده';

  @override
  String get changeReverted =>
      'تغییر معلق برگردانده شد. بازبینی تازه درخواست کنید.';

  @override
  String get unknownBatch =>
      'نتیجه نامشخص است. ممکن است دسته ثبت شده باشد. هرگز خودکار آن را تکرار نکنید؛ نشست و رکورد بازیابی را بررسی کنید.';

  @override
  String get expiredChangeReview =>
      'هدف تغییر کرده یا بازبینی منقضی شده است. بازبینی تازه درخواست کنید.';

  @override
  String get applyCommitExplanation =>
      'اعمال و ثبت، تراکنش مستقل خود را آغاز و ثبت می‌کند. کنسول مبدأ باید بیکار و ثبت خودکار فعال باشد. تراکنش‌های دستی SQL را جداگانه حل کنید.';

  @override
  String get newRow => 'ردیف جدید';

  @override
  String get original => 'اصلی';

  @override
  String get proposed => 'پیشنهادی';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '$inserts درج · $updates به‌روزرسانی · $deletes حذف';
  }

  @override
  String sourceRow(String row) {
    return 'ردیف مبدأ $row';
  }

  @override
  String get refreshing => 'در حال تازه‌سازی…';

  @override
  String get refreshActivities => 'تازه‌سازی فعالیت‌ها';

  @override
  String get explicitRefresh => 'تازه‌سازی صریح';

  @override
  String get pollFiveSeconds => 'پرس‌وجو هر ۵ ثانیه';

  @override
  String get cancelSelectedActivity => 'لغو فعالیت انتخاب‌شده';

  @override
  String get terminateSelectedSession => 'پایان نشست انتخاب‌شده';

  @override
  String get filterActivities => 'فیلتر فعالیت‌های فعلی';

  @override
  String get blockedBy => 'مسدودشده توسط:';

  @override
  String get delete => 'حذف';

  @override
  String get remove => 'برداشتن';

  @override
  String get up => 'بالا';

  @override
  String get search => 'جست‌وجو';

  @override
  String get yes => 'بله';

  @override
  String get no => 'نه';

  @override
  String get clear => 'پاک‌سازی';

  @override
  String get copy => 'رونوشت';

  @override
  String get insert => 'درج';

  @override
  String get update => 'به‌روز رسانی';

  @override
  String get open => 'گشودن';

  @override
  String get migrationEngineMismatch =>
      'اتصال مقصد باید از موتور یکسان با نماهای مقایسه‌شده استفاده کند. مهاجرت بین موتورهای مختلف پشتیبانی نمی‌شود.';

  @override
  String get metadataContextChanged =>
      'زمینهٔ بررسی تغییر کرده است. فراداده را به‌طور صریح تازه‌سازی کنید.';

  @override
  String get newTableName => 'نام جدول جدید';

  @override
  String get routineIdentity => 'هویت دقیق روال';

  @override
  String get objectColumnName => 'نام شیء / ستون';

  @override
  String get builtInType => 'نوع داخلی';

  @override
  String get sqlExpression => 'عبارت SQL (خالی آن را حذف می‌کند)';

  @override
  String get newPropertyValue => 'مقدار جدید ویژگی';

  @override
  String get columnComment => 'توضیح ستون';

  @override
  String get columnCollation =>
      'ترتیب ستون (خالی از پیش‌فرض سرور استفاده می‌کند)';

  @override
  String get addDesignedColumn => 'افزودن ستون به جدول جدید';

  @override
  String get checkExpression => 'عبارت CHECK';

  @override
  String get referencedSchema => 'طرح‌واره / پایگاه دادهٔ ارجاع‌شده';

  @override
  String get generating => 'در حال تولید…';

  @override
  String get generateReviewedDdl => 'تولید DDL برای بازبینی';

  @override
  String get inspectCapturedDefinition => 'بررسی تعریف ثبت‌شده';

  @override
  String get capturedObject => 'شیء ثبت‌شده';

  @override
  String get designReviewNote =>
      'تغییرات برای بازبینی تولید می‌شوند. محتوای پایگاه داده تا اجرای بازبینی‌شده بدون تغییر می‌ماند.';

  @override
  String get columnMetadataUnavailable =>
      'فرادادهٔ ستون در این محدوده در دسترس نیست؛ پیش از طراحی فهرست ستون‌ها، طرح‌وارهٔ انتخاب‌شده را بررسی کنید.';

  @override
  String get ordinaryColumn => 'ستون عادی';

  @override
  String get columnWithDefault => 'ستون با مقدار پیش‌فرض';

  @override
  String get identityColumn => 'هویت / افزایش خودکار';

  @override
  String get generatedColumn => 'ستون تولیدشده';

  @override
  String get columnType => 'نوع ستون';

  @override
  String get nullableNotNull => 'پذیرش NULL / NOT NULL';

  @override
  String get defaultExpression => 'عبارت پیش‌فرض';

  @override
  String get generatedExpression => 'عبارت تولیدشده';

  @override
  String get columnCollationProperty => 'ترتیب ستون';

  @override
  String get loggedUnlogged => 'ثبت‌شده / ثبت‌نشده';

  @override
  String get tableComment => 'توضیح جدول';

  @override
  String get storageEngine => 'موتور ذخیره‌سازی';

  @override
  String get tableCollation => 'ترتیب جدول';

  @override
  String get rowFormat => 'قالب ردیف';

  @override
  String get createOrReplace => 'ایجاد یا جایگزینی';

  @override
  String get dropSelectedObject => 'حذف شیء انتخاب‌شده';

  @override
  String get addColumn => 'افزودن ستون';

  @override
  String get editColumnProperties => 'ویرایش ویژگی‌های ستون';

  @override
  String get tableProperties => 'ویژگی‌های جدول';

  @override
  String get triggerDefinition => 'تعریف تریگر';

  @override
  String get createTable => 'ایجاد جدول';

  @override
  String get viewDefinition => 'تعریف نما';

  @override
  String get routineDefinition => 'تعریف روال';

  @override
  String get chooseExistingObject => 'انتخاب شیء موجود';

  @override
  String get nullable => 'پذیرش NULL';

  @override
  String get removeIdentity => 'حذف هویت';

  @override
  String get generatedAlways => 'همیشه تولیدشده';

  @override
  String get generatedByDefault => 'تولیدشده به‌طور پیش‌فرض / افزایش خودکار';

  @override
  String get loggedTable => 'جدول ثبت‌شده';

  @override
  String get unloggedTable => 'جدول ثبت‌نشده';

  @override
  String get orderedPrimaryKeyColumns => 'ستون‌های کلید اصلی به ترتیب';

  @override
  String get orderedColumns => 'ستون‌های مرتب‌شده';

  @override
  String get ordinaryIndex => 'شاخص عادی';

  @override
  String get uniqueIndex => 'شاخص یکتا';

  @override
  String get primaryKey => 'کلید اصلی';

  @override
  String get uniqueConstraint => 'محدودیت یکتایی';

  @override
  String get foreignKey => 'کلید خارجی';

  @override
  String get checkConstraint => 'محدودیت CHECK';

  @override
  String get immediateChecking => 'بررسی فوری';

  @override
  String get deferrableChecking => 'بررسی قابل تعویق';

  @override
  String get initiallyImmediate => 'ابتدا فوری';

  @override
  String get initiallyDeferred => 'ابتدا به‌تعویق‌افتاده';

  @override
  String get referencedTable => 'جدول ارجاع‌شده';

  @override
  String get orderedReferencedColumns => 'ستون‌های ارجاع‌شده به ترتیب متناظر';

  @override
  String get objectDefinitionEditor => 'ویرایشگر SQL تعریف بومی شیء';

  @override
  String get onDelete => 'هنگام حذف';

  @override
  String get onUpdate => 'هنگام به‌روزرسانی';

  @override
  String get stay => 'ماندن';

  @override
  String get saveSqlClose => 'ذخیرهٔ SQL و بستن';

  @override
  String get discardSqlClose => 'دور انداختن SQL و بستن';

  @override
  String get closeBusyData => 'بستن BusyData';

  @override
  String get saveDraftsClose => 'ذخیرهٔ پیش‌نویس‌ها و بستن';

  @override
  String get closeWithoutRecovery => 'بستن بدون بازیابی';

  @override
  String get recoveryFailed => 'بازیابی ناموفق';

  @override
  String get discardFailedSaveClose => 'دور انداختن ذخیرهٔ ناموفق و بستن';

  @override
  String get closeWithoutSavingRecovery => 'بستن بدون ذخیرهٔ بازیابی';

  @override
  String get disableSqlRecovery => 'غیرفعال‌کردن بازیابی SQL';

  @override
  String get historyPrivacy => 'حریم خصوصی تاریخچه';

  @override
  String get enableSqlRetention => 'فعال‌کردن نگهداری SQL';

  @override
  String get disableSqlRetention => 'غیرفعال‌کردن نگهداری SQL';

  @override
  String get clearHistory => 'پاک‌کردن تاریخچه';

  @override
  String get deleteHistoryEntry => 'حذف ورودی تاریخچه';

  @override
  String get deleteSelected => 'حذف انتخاب‌شده';

  @override
  String get saveRetention => 'ذخیرهٔ نگهداری';

  @override
  String get retentionDays => 'روزهای نگهداری';

  @override
  String get sqlTextRetained => 'متن SQL نگهداری می‌شود';

  @override
  String get sqlTextDisabled => 'متن SQL غیرفعال است';

  @override
  String get openHistoryQuery => 'بازکردن در زبانهٔ جدید SQL';

  @override
  String get caCertificateFile => 'فایل گواهی CA';

  @override
  String get clientCertificateFile => 'فایل گواهی کلاینت';

  @override
  String get clientKeyFile => 'فایل کلید کلاینت';

  @override
  String get directConnection => 'اتصال مستقیم';

  @override
  String get sshTunnel => 'تونل SSH';

  @override
  String get sshHost => 'میزبان SSH';

  @override
  String get sshPort => 'درگاه SSH';

  @override
  String get sshUser => 'کاربر SSH';

  @override
  String get reviewedKnownHosts => 'فایل بررسی‌شدهٔ known_hosts';

  @override
  String get reviewSshKey => 'بررسی کلید میزبان SSH';

  @override
  String get changedSshKey => 'کلید میزبان SSH تغییر کرده';

  @override
  String get verifyFingerprint =>
      'پیش از اعتماد، این اثر انگشت را مستقل بررسی کنید.';

  @override
  String get selectedKeyPassword => 'کلید یا گذرواژهٔ انتخاب‌شده';

  @override
  String get selectedAgentIdentity => 'هویت انتخاب‌شدهٔ عامل SSH';

  @override
  String get selectedAgentSocket =>
      'سوکت عامل Linux / لولهٔ نام‌دار Windows انتخاب‌شده';

  @override
  String get selectedKeyFingerprint => 'اثر انگشت کلید انتخاب‌شده · SHA256:…';

  @override
  String get selectedPrivateKey => 'کلید خصوصی انتخاب‌شده (اختیاری)';

  @override
  String get sshPassword => 'گذرواژهٔ SSH';

  @override
  String get keyPassphrase => 'عبارت عبور کلید';

  @override
  String get connectionTimeout => 'مهلت اتصال · 1–120 ثانیه';

  @override
  String get sqlTimeout => 'مهلت اجرا/واکشی SQL · 1–3600 ثانیه (0 = 60)';

  @override
  String get schemasEquivalent => 'طرح‌واره‌های ثبت‌شده معادل‌اند.';

  @override
  String get migrationComplete =>
      'مهاجرت تفاوت‌های ثبت‌شدهٔ پشتیبانی‌شده را پوشش می‌دهد.';

  @override
  String get migrationPartial =>
      'مهاجرت جزئی؛ تفاوت‌های پشتیبانی‌نشده باقی می‌مانند.';

  @override
  String get differencesLimited =>
      'نمایش تفاوت‌ها محدود است. تصویرهای ذخیره‌شدهٔ کامل و SQL تولیدشده را بررسی کنید.';

  @override
  String get absent => 'وجود ندارد';

  @override
  String get definitionPreviewLimited =>
      'پیش‌نمایش تعریف محدود است؛ شواهد کامل در تصویر اصلی قرار دارد.';

  @override
  String get migrationBatchNote =>
      'SQL یک دسته با ترتیب وابستگی است. انتخاب یک شیء برای بررسی است و عبارت‌های قابل اعمال را انتخاب نمی‌کند.';

  @override
  String get unsupportedLabel => 'پشتیبانی‌نشده';

  @override
  String get differenceAdded => 'افزوده';

  @override
  String get differenceRemoved => 'حذف‌شده';

  @override
  String get differenceChanged => 'تغییریافته';

  @override
  String get selectHistoryEntry => 'یک ورودی تاریخچه انتخاب کنید';

  @override
  String get searchSqlTarget => 'جستجوی SQL یا مقصد';

  @override
  String get closeSqlTab => 'بستن زبانهٔ SQL';

  @override
  String get historyMetadataRetained =>
      'فرادادهٔ وضعیت و مقصد در تاریخچه باقی می‌ماند.';

  @override
  String get historyPreviewNote =>
      'فقط پیش‌نمایش. برای دریافت متن نگهداری‌شده در زبانهٔ جدید SQL باز کنید.';

  @override
  String get selected => 'انتخاب‌شده';

  @override
  String get authReviewNote =>
      'پیش از اعمال، کاربر یا نقش و مقصد دقیق را بررسی کنید. اعتبارنامه‌ها هرگز در اسناد SQL یا تاریخچه قرار نمی‌گیرند. اتصال‌های موجود و گذرواژه‌های ذخیره‌شده جدا می‌مانند.';

  @override
  String get createLogin => 'ایجاد حساب ورود';

  @override
  String get createRole => 'ایجاد نقش بدون ورود';

  @override
  String get setPassword => 'تنظیم گذرواژه';

  @override
  String get preventLogin => 'جلوگیری از ورودهای جدید';

  @override
  String get allowLogin => 'اجازهٔ ورودهای جدید';

  @override
  String get dropPrincipal => 'حذف کاربر یا نقش';

  @override
  String get principalName => 'نام دقیق کاربر یا نقش';

  @override
  String get accountHost =>
      'میزبان دقیق حساب (نویسه‌های عام دامنهٔ ورود را گسترش می‌دهند)';

  @override
  String get newPassword => 'گذرواژهٔ جدید';

  @override
  String get repeatPassword => 'تکرار گذرواژهٔ جدید';

  @override
  String get reviewAccount => 'بررسی عملیات حساب';

  @override
  String get passwordsMismatch =>
      'یک گذرواژهٔ غیرخالی یکسان را دو بار وارد کنید';

  @override
  String get accountSubmitFailed =>
      'عملیات حساب ارسال نشد. مقصد، سیاست احراز هویت و مجوزهای پایگاه داده را بررسی کنید.';

  @override
  String get privilegeReviewNote =>
      'مجوزهای مستقیم را بررسی کنید؛ SQL تولیدشده همچنان نیاز به بررسی اجرا دارد.';

  @override
  String get inspectionLimited =>
      'حداکثر ۵۰۰ ردیف در هر بخش. جستجو را محدود کنید؛ بخش خالی نبود دسترسی مؤثر را ثابت نمی‌کند.';

  @override
  String get findPrincipal => 'یافتن نام کاربر / نقش';

  @override
  String get searchPrincipals => 'جستجوی کاربران و نقش‌ها';

  @override
  String get choosePrincipal => 'انتخاب کاربر یا نقش';

  @override
  String get inspectGrants => 'بررسی مجوزهای انتخاب‌شده';

  @override
  String get tablePrivileges => 'مجوزهای جدول / نما';

  @override
  String get schemaPrivileges => 'مجوزهای طرحواره';

  @override
  String get databasePrivileges => 'مجوزهای پایگاه داده';

  @override
  String get roleMembership => 'عضویت نقش';

  @override
  String get defaultRole => 'فعال‌سازی نقش پیش‌فرض';

  @override
  String get chooseGrantRole => 'انتخاب نقش برای اعطا / لغو';

  @override
  String get tableView => 'جدول / نما';

  @override
  String get explicitPrivileges => 'مجوزهای صریح (جداشده با ویرگول)';

  @override
  String get setDefaultRole => 'تنظیم نقش پیش‌فرض انتخاب‌شده';

  @override
  String get clearDefaultRole => 'پاک کردن نقش پیش‌فرض';

  @override
  String get grantAccess => 'اعطای دسترسی';

  @override
  String get revokeAccess => 'لغو دسترسی';

  @override
  String get withoutDelegation => 'بدون تفویض';

  @override
  String get allowDelegation => 'اجازهٔ اعطا به دیگران برای دریافت‌کننده';

  @override
  String get readonlyChanges =>
      'این نمایه فقط خواندنی است. تغییرات به نشست با اجازهٔ صریح نوشتن نیاز دارند.';

  @override
  String get createPrincipal => 'ایجاد کاربر / نقش';

  @override
  String get manageAuthentication => 'مدیریت احراز هویت انتخاب‌شده';

  @override
  String get openPrivilegeSql => 'باز کردن SQL مجوزها برای بررسی';

  @override
  String get inspectPrincipalFirst =>
      'پیش از تهیهٔ تغییر، کاربر یا نقش انتخاب‌شده را بررسی کنید';

  @override
  String get accountAuthentication => 'احراز هویت حساب';

  @override
  String get schema => 'طرحواره';

  @override
  String get available => 'در دسترس';

  @override
  String get availableEmpty => 'در دسترس · دادهٔ خالی';

  @override
  String get limitedVisibility => 'دید یا دامنهٔ محدود';

  @override
  String get permissionDenied => 'دسترسی رد شد';

  @override
  String get unavailable => 'در دسترس نیست';

  @override
  String get profileDisabled => 'غیرفعال‌شده توسط نمایه';

  @override
  String get unknownState => 'نامشخص';

  @override
  String get inspecting => 'در حال بررسی…';

  @override
  String get refreshCapabilities => 'بازخوانی قابلیت‌ها';

  @override
  String get staleRefresh => 'قدیمی · پس از اتصال بازخوانی کنید';

  @override
  String get staleContext => 'قدیمی · پس از اتصال یا تغییر زمینه بازخوانی کنید';

  @override
  String get partialTreeLimit =>
      'جزئی · حد درخت رسیده؛ جستجوی اشیای پایگاه داده را محدود کنید';

  @override
  String get schemaComparison => 'مقایسهٔ طرحواره‌ها';

  @override
  String get searchTable => 'جستجوی جدول';

  @override
  String get focusObject => 'تمرکز';

  @override
  String get exportSvg => 'صدور SVG';

  @override
  String get exportPng => 'صدور PNG';

  @override
  String get diagramNotes => 'یادداشت‌های نمودار (در SVG گنجانده می‌شوند)';

  @override
  String get openNotes => 'باز کردن یادداشت‌ها';

  @override
  String get saveNotes => 'ذخیرهٔ یادداشت‌ها';

  @override
  String get newSnippet => 'قطعهٔ جدید';

  @override
  String get snippetName => 'نام قطعه';

  @override
  String get saveSnippet => 'ذخیرهٔ قطعه';

  @override
  String get deleteSnippet => 'حذف قطعهٔ ذخیره‌شده';

  @override
  String get insertSnippet => 'درج در سند SQL';

  @override
  String get snippetEditor => 'ویرایشگر قطعهٔ SQL';

  @override
  String get snippetsNote =>
      'SQL محلی ذخیره‌شده را با واگرد در سند انتخاب‌شده درج کنید. اجرا همچنان صریح است.';

  @override
  String get level => 'سطح';

  @override
  String get expanded => 'گسترش‌یافته';

  @override
  String get collapsed => 'جمع‌شده';

  @override
  String get treeLevel => 'سطح';

  @override
  String get retainedView => 'نمای نگه‌داشته‌شده';

  @override
  String get tableQuerySnapshot => 'عکس وضعیت پرس‌وجوی جدول';

  @override
  String get originalResultNote =>
      'نتیجهٔ اصلی نگه‌داشته‌شده؛ صفحه‌بندی و بررسی SQL اجرا نمی‌کنند';

  @override
  String get tableFilterNote =>
      'اعمال، پرس‌وجوی جدید بررسی‌شده می‌فرستد. عکس وضعیت قبلی در دسترس می‌ماند.';

  @override
  String get retainedFilterNote =>
      'همهٔ ردیف‌های واکشی‌شده در یک عکس وضعیت ثابت. SQL دوباره اجرا نمی‌شود. ترتیب می‌تواند با ترتیب پایگاه داده متفاوت باشد.';

  @override
  String get retainedRowNote =>
      'ردیفی از نتیجهٔ قبلاً واکشی‌شده انتخاب کنید. SQL دوباره اجرا نمی‌شود.';

  @override
  String get copyLimitNote =>
      'کپی به ۱۰٬۰۰۰ سلول محدود است؛ برای محدوده‌های بزرگ‌تر دادهٔ نگه‌داشته‌شده را صادر کنید.';

  @override
  String get inlineValueLimit =>
      'ویرایش درون‌سلولی از مقادیر تا 8KiB پشتیبانی می‌کند';

  @override
  String get editContextChanged =>
      'نشست مبدأ یا زمینهٔ ویرایش تغییر کرد؛ پیش از آماده‌سازی تغییرات ارزیابی را بررسی یا بازخوانی کنید';

  @override
  String get editAssessmentUnavailable =>
      'ویرایش در دسترس نیست؛ پس از بی‌کار شدن نشست ارزیابی را بازخوانی کنید';

  @override
  String get rowChangeReverted =>
      'تغییر معلق ردیف برگردانده شد؛ پایگاه داده تغییر نکرد';

  @override
  String get sqlCopyRequiresMetadata =>
      'کپی SQL به فرایند پس‌زمینه و فرادادهٔ نوع نگه‌داشته‌شده نیاز دارد.';

  @override
  String get exportFullValue => 'صدور مقدار کامل نگه‌داشته‌شده';

  @override
  String valueExportReview(String bytes, String path) {
    return '$bytes بایت در $path ذخیره شود؟ محتوای موجود جایگزین می‌شود. SQL دوباره اجرا نمی‌شود.';
  }

  @override
  String get goToRetainedRow => 'رفتن به ردیف نگه‌داشته‌شده';

  @override
  String get row => 'ردیف';

  @override
  String get go => 'برو';

  @override
  String get retryRows => 'تلاش دوباره برای ردیف‌های نگه‌داشته‌شده';

  @override
  String get previousRows => 'ردیف‌های قبلی';

  @override
  String get nextRows => 'ردیف‌های بعدی';

  @override
  String get firstWindow => 'اولین پنجرهٔ نگه‌داشته‌شده';

  @override
  String get lastWindow => 'آخرین پنجرهٔ واکشی‌شده';

  @override
  String get setNull => 'تنظیم NULL';

  @override
  String copyFormat(String format) {
    return 'کپی $format';
  }

  @override
  String get textValue => 'متن';

  @override
  String get sqlValues => 'مقادیر SQL';

  @override
  String get rowSelection => 'انتخاب ردیف';

  @override
  String selectRow(String row) {
    return 'انتخاب ردیف $row';
  }

  @override
  String columnHeader(String column) {
    return 'ستون $column';
  }

  @override
  String get pendingChange => 'تغییر معلق';

  @override
  String get readonlyCell => 'سلول فقط خواندنی';

  @override
  String get editableCell => 'سلول قابل ویرایش';

  @override
  String get loadValueFirst => 'ابتدا این مقدار نگه‌داشته‌شده را بارگذاری کنید';

  @override
  String get editUnavailable => 'ویرایش در دسترس نیست';

  @override
  String get editCell => 'ویرایش سلول';

  @override
  String get unsupportedEditValue =>
      'این مقدار نگه‌داشته‌شده فقط قابل بررسی است';

  @override
  String bytesCount(String bytes) {
    return '$bytes بایت';
  }

  @override
  String get problems => 'مشکلات';

  @override
  String get ownedSessions => 'نشست‌های متعلق به برنامه';

  @override
  String get noProblems => 'مشکلی ثبت نشده است';

  @override
  String get duplicateConnection => 'تکثیر اتصال';

  @override
  String get deleteConnection => 'حذف اتصال';

  @override
  String deleteConnectionReview(String name) {
    return '$name حذف شود؟ نشست‌های فیزیکی موجود تنظیمات اصلی خود را نگه می‌دارند.';
  }

  @override
  String get unresolvedSessions => 'نشست‌های حل‌نشده';

  @override
  String get disconnectSessionNote =>
      'ابتدا کارها و تراکنش‌های فعال را تعیین تکلیف کنید. قطع اتصال بر همهٔ کاربران این نشست فیزیکی اثر دارد؛ تراکنشی را ثبت نمی‌کند و SQL را دوباره اجرا نمی‌کند. نتیجه‌های نامعلوم همچنان نامعلوم می‌مانند.';

  @override
  String get transferSettingsChanged => 'تنظیمات تغییر کرد؛ دوباره بررسی کنید';

  @override
  String get transferReviewReady =>
      'بررسی آماده است؛ مقصد، دامنه، نگاشت و فایل را بررسی کنید';

  @override
  String get sourcePreviewNotice => 'پیش‌نمایش منبع؛ هیچ ردیفی وارد نشده';

  @override
  String get transferRequiresReview => 'ابتدا همین انتقال را بررسی کنید';

  @override
  String get transferSubmittedNotice =>
      'ارسال شد؛ لغو، ثبت‌ها یا فایل‌های منتشرشده را برنمی‌گرداند';

  @override
  String get sqlExportExecutionNote => 'اجرای SQL جدید و بررسی‌شده';

  @override
  String get retainedExportSnapshotNote =>
      'تصویر ردیف‌های دریافت‌شده؛ SQL اجرا نمی‌شود';

  @override
  String get restorePartialCommitNote =>
      'بازیابی ممکن است بخشی را ثبت کند. لغو آن را برنمی‌گرداند.';

  @override
  String get sourcePreviewLimit => 'پیش‌نمایش منبع؛ حداکثر 20 ردیف';

  @override
  String get importBatchSafetyNote =>
      'خطا و لغو ثبت‌های قبلی را حفظ می‌کنند. هش و منبع تغییرناپذیر پیش از ارسال بررسی می‌شوند.';

  @override
  String get nullMarkerLiteralNote =>
      'نشانگر NULL بدون نقل‌قول؛ در نقل‌قول متن عادی است';

  @override
  String immutableSourceHash(String hash) {
    return 'SHA-256 منبع تغییرناپذیر: $hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return 'ستون منبع $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return 'ردیف پیش‌نمایش $row، $column: $value';
  }

  @override
  String get transferCancellationNotice => 'لغو درخواست شد؛ منتظر تأیید باشید';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed پردازش · $committed ثبت · $rejected رد شده';
  }

  @override
  String get importAtomicPolicy => 'همهٔ ردیف‌ها در یک تراکنش';

  @override
  String get importBatchPolicy => 'ثبت دسته‌ها؛ توقف هنگام خطا';

  @override
  String get importSkipPolicy => 'ردیف‌های نامعتبر رد شوند؛ ثبت دسته‌ها';

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
    return 'تأییدها/اتصال‌ها: $operations\nسندهای ذخیره‌نشده: $documents\nذخیره‌های جاری: $saves\nتغییرات معلق: $edits\nکارهای فعال: $jobs\nتراکنش‌های نیازمند پاک‌سازی: $transactions\nنتیجه‌های نامعلوم: $unknown\nنشست‌های نامطمئن: $sessions';
  }

  @override
  String get closeDraftSaved => 'پیش‌نویس SQL محلی ذخیره می‌شود.';

  @override
  String get closeDraftLost =>
      'بازیابی غیرفعال است؛ SQL و طرح‌های ذخیره‌نشده از بین می‌روند.';

  @override
  String get closeDesignRecovery =>
      'طرح‌ها بازیابی خصوصی و محدود دارند. پس از بازکردن، اتصال و بازرسی فراداده را صریح انجام دهید.';

  @override
  String get closeCleanupReview =>
      'بستن آخرین مالک نشست درخواست لغو می‌دهد، تراکنش‌های تأییدشده را برمی‌گرداند و اتصال را قطع می‌کند. نتیجه‌های نامعلوم نامعلوم می‌مانند؛ بستن SQL را ثبت یا تکرار نمی‌کند.';

  @override
  String get closeSharedSession =>
      'دیگر کاربران نشست فیزیکی مشترک را حفظ می‌کنند.';

  @override
  String get closeStagedRecovery =>
      'تغییرات به بازیابی خصوصی تأییدشده، اتصال صریح و بررسی تازه نیاز دارند.';

  @override
  String get closeRecoveryLoss =>
      'سندها و چیدمان ذخیره نشدند. بستن ممکن است SQL و تغییرات را از بین ببرد؛ فایل‌ها و بازیابی قبلی حفظ می‌شوند.';

  @override
  String get closeWaitNotice =>
      'پیش از بستن منتظر تأییدها و پاک‌سازی اتصال بمانید.';

  @override
  String get saveFailedNotice =>
      'ذخیرهٔ SQL ناموفق بود. متن تغییرکرده را حفظ یا صریح حذف کنید.';

  @override
  String get closeCleanupFailed =>
      'پاک‌سازی پردازش پشتی ناموفق بود؛ BusyData باز می‌ماند.';

  @override
  String get closeBackendUnverified =>
      'وضعیت پردازش پشتی تأیید نشده؛ شاید کاری معلق باشد.';

  @override
  String historyRetainSqlReview(String days) {
    return 'SQL ممکن است راز داشته باشد. متن برای $days روز ذخیره شود؟';
  }

  @override
  String get historyStopSqlReview =>
      'ذخیرهٔ SQL متوقف و از تاریخچهٔ قبلی حذف شود؟';

  @override
  String get historyClearReview =>
      'همهٔ تاریخچه حذف شود؟ کارهای فعال می‌توانند در پایان نتیجه را ثبت کنند.';

  @override
  String get historyDeleteReview => 'ورودی انتخاب‌شدهٔ تاریخچه حذف شود؟';

  @override
  String get historyRetentionRange => 'نگهداری باید 1–3650 روز باشد';

  @override
  String get enableSqlHistory => 'فعال‌کردن تاریخچهٔ SQL';

  @override
  String get stopSqlHistory => 'توقف نگهداری SQL';

  @override
  String get recoveryDiscardReview =>
      'رکورد بازیابی حذف شود؟ ابتدا نتیجه‌های نامعلوم را تعیین کنید؛ حذف، تغییرات ثبت‌شده را برنمی‌گرداند.';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return 'SQL ذخیره‌نشده: $unsaved\nتغییرات معلق: $edits\nکارهای فعال: $jobs';
  }

  @override
  String get recoveryStayOpen =>
      'بازیابی ناموفق بود. BusyData باز می‌ماند؛ کار ذخیره‌نشده حفظ می‌شود.';

  @override
  String get commitUncertaintyNote =>
      'خطای شبکه می‌تواند نتیجهٔ ثبت را نامعلوم کند. هرگز خودکار تکرار نکنید.';

  @override
  String get closeObjectDesignDiscard =>
      'فیلدهای طرح ذخیره‌نشده حذف می‌شوند. برای حفظ طرح ابتدا SQL تولید و ذخیره کنید.';

  @override
  String get savePrivateDrafts => 'ذخیرهٔ پیش‌نویس بازیابی خصوصی';

  @override
  String get noPrivateDrafts => 'ذخیره‌نکردن پیش‌نویس بازیابی';

  @override
  String shortcutField(String command) {
    return 'میانبر $command';
  }

  @override
  String get shortcutInvalid =>
      'میان‌بر معتبر و آزاد انتخاب کنید. F6 وShift+F6 رزرو شده‌اند.';

  @override
  String get disableRecoveryReview =>
      'بازیابی محلی SQL، طرح و تغییرات حذف شود؟ کار ذخیره‌نشده باز می‌ماند؛ خرابی می‌تواند آن را از بین ببرد. ابتدا نتیجه‌های نامعلوم را تعیین کنید.';

  @override
  String get preferencesSaved => 'تنظیمات ذخیره شد';

  @override
  String get sharingSessionReview =>
      'این پرس‌وجو نشست فیزیکی نام‌برده، تراکنش، اشیای موقت و تنظیمات را با کاربران فهرست‌شده شریک می‌شود. بستن یک کاربر دیگران را حفظ می‌کند.';

  @override
  String get recoveryReconcileFirst =>
      'پیش از غیرفعال‌کردن بازیابی، تغییرات جاری یا نامعلوم را تعیین کنید. حذف رکورد بازیابی فقط از بررسی صریح آن انجام شود.';

  @override
  String get enterSearchText => 'متن جست‌وجو را وارد کنید';

  @override
  String get noSearchMatches => 'تطابقی نیست';

  @override
  String searchMatchCount(String position, String total) {
    return 'تطابق $position از $total';
  }

  @override
  String get formatSqlChanged =>
      'SQL یا هدف تغییر کرد. SQL اصلی حفظ شد؛ پیش‌نمایش قالب‌بندی تازه بخواهید.';

  @override
  String get formatSqlUnavailable =>
      'قالب‌بندی برای نحو ناقص یا پشتیبانی‌نشده یا محدودیت تحلیل ممکن نیست. SQL اصلی حفظ شد.';

  @override
  String get stageChange => 'آماده‌کردن تغییر';

  @override
  String pendingChangesCount(String count) {
    return '$count تغییر معلق؛ پایگاه داده تا اعمال بازبینی‌شده تغییر نمی‌کند.';
  }

  @override
  String discardChangesCount(String count) {
    return '$count تغییر معلق کنار گذاشته شود؟ عملیاتی به پایگاه داده ارسال نمی‌شود.';
  }

  @override
  String get recoveryNoExecution =>
      'بازیابی متصل نمی‌شود، SQL منبع را اجرا نمی‌کند، تراکنش را ادامه نمی‌دهد و تغییر را تکرار نمی‌کند. رکوردهای نامعلوم یا قطعی دوباره اعمال نمی‌شوند.';

  @override
  String get recoveredDesign =>
      'طرح بازیابی شد. پیش از بازبینی تازه صریحاً متصل شوید و فرادادهٔ فعلی را بررسی کنید. بازیابی SQL یا فراداده دریافت نکرد.';

  @override
  String get retainedUnavailable =>
      'دادهٔ نگهداری‌شده در دسترس نیست. SQL ذخیره‌شده و بازیابی خصوصی محلی می‌مانند.';

  @override
  String get activityFingerprintNote =>
      'اثر انگشت فعالیت منتخب پیش از ارسال بازبینی می‌شود. نتیجهٔ نوشتن ممکن است نامعلوم باشد.';

  @override
  String replaceFileReview(String path) {
    return 'فایل بازبینی‌شده در $path جایگزین شود؟ مقصد تغییریافته بازبینی تازه می‌خواهد.';
  }

  @override
  String get diagramPngSaved =>
      'PNG نمودار ذخیره شد. یادداشت‌های بلند تا شش خط نشان می‌دهند.';

  @override
  String get editTargetChanged =>
      'هدف ویرایش تغییر کرد. پیش از آماده‌کردن، ویرایشگر ردیف را دوباره باز کنید.';

  @override
  String affectedRowCount(String count) {
    return 'ردیف‌های تحت تأثیر: $count';
  }

  @override
  String get zoomIn => 'بزرگ‌نمایی';

  @override
  String get zoomOut => 'کوچک‌نمایی';

  @override
  String get resetView => 'بازنشانی نما';

  @override
  String get diagramKeys =>
      'پیکان‌ها جابه‌جا می‌کنند؛ + و - بزرگ‌نمایی را تغییر می‌دهند؛ Home نما را بازنشانی می‌کند.';

  @override
  String get explorerConnected => 'کاوشگر متصل است';

  @override
  String get explorerDisconnected => 'کاوشگر متصل نیست';

  @override
  String querySessionCount(String count) {
    return 'نشست‌های پرس‌وجو $count';
  }

  @override
  String get metadataColumn => 'ستون';

  @override
  String get metadataPosition => 'موقعیت';

  @override
  String get metadataUnique => 'یکتا';

  @override
  String get metadataJdbcType => 'نوع JDBC';

  @override
  String get metadataAutoIncrement => 'افزایش خودکار';

  @override
  String get metadataReferencedColumn => 'ستون ارجاع‌شده';

  @override
  String get metadataComment => 'توضیح';

  @override
  String get metadataType => 'نوع';

  @override
  String get metadataEvent => 'رویداد';

  @override
  String get metadataSpecificName => 'شناسهٔ بومی مشخص';

  @override
  String get metadataOptions => 'گزینه‌ها';

  @override
  String get metadataInheritance => 'وراثت';

  @override
  String get metadataDefinitionCaptured => 'تعریف بومی ثبت‌شده';

  @override
  String get metadataDefinitionUnavailable =>
      'تعریف در فرادادهٔ ثبت‌شده در دسترس نیست';

  @override
  String get metadataDefinitionUnsupported =>
      'شیء ثبت‌شده تعریف بومی پشتیبانی‌شده ندارد';

  @override
  String get connections => 'اتصال‌ها';

  @override
  String get noConnections => 'هنوز اتصالی وجود ندارد';

  @override
  String get startTitle => 'اتصال به پایگاه داده';

  @override
  String get startDescription =>
      'برای مرور اشیا، مدیریت داده‌ها و اجرای پرس‌وجوها به PostgreSQL، MySQL یا MariaDB متصل شوید.';

  @override
  String get savedStartTitle => 'انتخاب اتصال';

  @override
  String get savedStartDescription =>
      'برای مرور اشیا و اجرای پرس‌وجوها به یک اتصال ذخیره‌شده در مرورگر پایگاه داده متصل شوید.';

  @override
  String get noConnection => 'بدون اتصال';

  @override
  String queryTitle(int number) {
    return 'پرس‌وجوی $number';
  }

  @override
  String get sessionMenu => 'نشست';

  @override
  String get noFilterMatches => 'اتصال یا شیء بارگذاری‌شدهٔ مطابقی وجود ندارد';

  @override
  String get activityState => 'وضعیت';

  @override
  String get activityWait => 'انتظار';

  @override
  String get generalSettings => 'عمومی';

  @override
  String get optionsSettings => 'گزینه‌ها';

  @override
  String get host => 'میزبان';

  @override
  String get databaseSystem => 'سامانهٔ پایگاه داده';

  @override
  String get passwordStorage => 'ذخیرهٔ گذرواژه';

  @override
  String get environmentLabel => 'محیط';

  @override
  String get readOnlySettings => 'سیاست فقط‌خواندنی';

  @override
  String get tlsPolicy => 'سیاست TLS';

  @override
  String get sshConnection => 'اتصال SSH';

  @override
  String get sshAuthentication => 'احراز هویت SSH';

  @override
  String get connectionTestAction => 'آزمودن اتصال';

  @override
  String get details => 'جزئیات';

  @override
  String get copyDetails => 'رونوشت جزئیات';

  @override
  String get retry => 'تلاش دوباره';

  @override
  String get filterCellValue => 'فیلتر با این مقدار';

  @override
  String get connectsWhenRun => 'اتصال هنگام اجرا';

  @override
  String get connectionSaving => 'ذخیره…';

  @override
  String get connectionConnecting => 'اتصال…';

  @override
  String get connectionCancelling => 'لغو…';

  @override
  String get connectionSettingsChanged =>
      'تنظیمات تغییر کرد. این نسخه را دوباره بیازمایید.';

  @override
  String get connectionTestChanged =>
      'تنظیمات تغییر کرد. این نسخه را دوباره بیازمایید.';

  @override
  String get connectionRequired => 'الزامی';

  @override
  String get connectionCorrectFields => 'تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionHostname => 'میزبان · تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionSshHostname =>
      'SSH · میزبان · تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionMaxLength => 'نام ≤ 256';

  @override
  String get connectionTlsHelp =>
      'TLS · میزبان · SSH/SSL. تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionTlsReview =>
      'TLS · میزبان · SSH/SSL. تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionStorageUnavailable =>
      'ذخیرهٔ گذرواژه: در دسترس نیست. گذرواژه · هرگز.';

  @override
  String get connectionHostReviewed =>
      'میزبان · اعتماد فقط برای همین نمایه و مقصد دقیق اعمال می‌شود.';

  @override
  String get connectionSshReviewing => 'SSH · بررسی کلید میزبان SSH…';

  @override
  String get connectionFailureAuthentication =>
      'ناموفق · احراز هویت · عمومی. تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionFailureTls =>
      'ناموفق · TLS · SSH/SSL. تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionFailureSshKey =>
      'ناموفق · بررسی کلید میزبان SSH. تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionFailureEndpoint =>
      'ناموفق · میزبان · درگاه. تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionFailureCancelled => 'لغو شد';

  @override
  String get connectionFailureSettings =>
      'ناموفق · عمومی. تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionFailureAccess =>
      'ناموفق · مجوزهای جدول / نما. تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionFailureUnavailable =>
      'ناموفق · میزبان · TLS · SSH. تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionFailureTimeout =>
      'ناموفق · مهلت اتصال · 1–120 ثانیه. تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String get connectionFailureUnknown =>
      'ناموفق · عمومی · TLS · SSH. تنظیمات مشخص‌شده را بررسی کنید.';

  @override
  String connectionNumber(int min, int max) {
    return 'یک عدد صحیح از $min تا $max وارد کنید';
  }

  @override
  String connectionSavedFailure(String name) {
    return 'اتصال ذخیره شد: $name. تلاش برای اتصال ناموفق بود. ';
  }

  @override
  String get backendBusy =>
      'سرویس مشغول است. منتظر درخواست فعلی بمانید و دوباره تلاش کنید.';

  @override
  String rpcRequestUnconfirmed(String code) {
    return 'درخواست تأیید نشد (RPC $code).';
  }

  @override
  String get operationUnconfirmed => 'عملیات کامل نشد.';

  @override
  String get connectionFailureTlsMaterial =>
      'مواد TLS در دسترس نیست یا نامعتبر است. منابع اعتماد و کلید کارخواه را در SSH/SSL بررسی کنید.';

  @override
  String get managerTitle => 'منابع داده و راه‌اندازها';

  @override
  String get sourceListTitle => 'منابع داده';

  @override
  String get driverLabel => 'راه‌انداز';

  @override
  String get connectionTypeLabel => 'نوع اتصال';

  @override
  String get defaultTcp => 'پیش‌فرض (TCP)';

  @override
  String get authenticationLabel => 'احراز هویت';

  @override
  String get userPasswordAuth => 'کاربر و گذرواژه';

  @override
  String get neverStorage => 'هرگز';

  @override
  String get initialDatabaseLabel => 'پایگاه داده اولیه';

  @override
  String get useSshTunnel => 'استفاده از تونل SSH';

  @override
  String get sshConfigurationLabel => 'پیکربندی SSH';

  @override
  String get createSshConfig => '<ایجاد پیکربندی>';

  @override
  String get copySshSettings => 'کپی تنظیمات SSH';

  @override
  String get localPortLabel => 'درگاه محلی';

  @override
  String get dynamicPortLabel => '<پویا>';

  @override
  String get useSsl => 'استفاده از SSL';

  @override
  String get useTruststore => 'استفاده از مخزن اعتماد';

  @override
  String get clientKeyPasswordLabel => 'گذرواژه کلید کارخواه';

  @override
  String get modeLabel => 'حالت';

  @override
  String get requireTls => 'الزامی';

  @override
  String get verifyCa => 'بررسی CA';

  @override
  String get fullVerification => 'بررسی کامل';

  @override
  String get connectionSection => 'اتصال';

  @override
  String get configurationApplied => 'پیکربندی اعمال شد';

  @override
  String get noOtherSshConfig => 'هیچ منبع دیگری پیکربندی SSH ندارد.';

  @override
  String get generatedUrlHelp => 'نشانی JDBC تولیدشده و فقط‌خواندنی.';

  @override
  String get tlsDriverDefaultHelp =>
      'SSL پیکربندی نشده است؛ راه‌انداز همراه از پیش‌فرض خود استفاده می‌کند.';

  @override
  String get tlsClientKeyHelp =>
      'کلیدهای PEM: ‏PKCS#8 یا OpenSSL؛ رمزگذاری‌شده یا بدون رمزگذاری.';

  @override
  String get legacyMariaTrustHelp =>
      'بررسی فعلی راه‌انداز حفظ می‌شود. برای تعیین ریشه‌ها، منابع اعتماد را انتخاب کنید.';

  @override
  String get metadataStartValue => 'مقدار آغازین';

  @override
  String get metadataMinimumValue => 'کمینه مقدار';

  @override
  String get metadataMaximumValue => 'بیشینه مقدار';

  @override
  String get metadataIncrement => 'گام افزایش';

  @override
  String get metadataCycle => 'چرخه‌ای';

  @override
  String get metadataCacheSize => 'اندازه حافظه نهان';

  @override
  String get metadataLastValue => 'آخرین مقدار';

  @override
  String get sequences => 'دنباله‌ها';

  @override
  String get namespaceSelection => 'انتخاب فضای نام';

  @override
  String get namespaceSelectionNotice =>
      'انتخاب، بررسی ساختار را کنترل می‌کند. کنسول‌های پرس‌وجو زمینه اجرای خود را حفظ می‌کنند.';

  @override
  String get allNamespaces => 'همه فضاهای نام';

  @override
  String get defaultNamespace => 'پیش‌فرض';

  @override
  String get namespacePattern => 'الگوی نام (عبارت منظم)';

  @override
  String namespaceCount(int selected, int known) {
    return '$selected از $known';
  }

  @override
  String get previousPage => 'صفحه قبل';

  @override
  String get patternRejected =>
      'الگو نامعتبر است یا از محدودیت کار عبور می‌کند. انتخاب قبلی حفظ می‌شود.';

  @override
  String get namespaceNotSelected =>
      'فضای نام برای بررسی ساختار انتخاب نشده است';

  @override
  String get newMenu => 'جدید';

  @override
  String get queryConsoles => 'کنسول‌های پرس‌وجو';

  @override
  String get viewOptions => 'گزینه‌های نمایش';

  @override
  String get quickDocumentation => 'مستندات سریع';

  @override
  String get showEmptyGroups => 'نمایش گروه‌های خالی';

  @override
  String get speedSearch => 'جست‌وجوی سریع';

  @override
  String get speedSearchScope => 'فقط گره‌های باز و بارگذاری‌شده.';

  @override
  String get newSourceFolder => 'پوشهٔ منبع جدید';

  @override
  String get renameSourceFolder => 'تغییر نام پوشه';

  @override
  String get moveToFolder => 'انتقال به پوشه';

  @override
  String get moveUp => 'انتقال به بالا';

  @override
  String get moveDown => 'انتقال به پایین';

  @override
  String get folderMustBeEmpty =>
      'پیش از حذف این پوشه، منابع و پوشه‌های درون آن را منتقل کنید.';

  @override
  String get newVirtualView => 'نمای مجازی جدید';

  @override
  String get editVirtualDefinition => 'ویرایش تعریف محلی';

  @override
  String get unboundVirtualView => 'نماهای مجازی بدون اتصال';

  @override
  String get localVirtualViewNotice =>
      'تعریف محلی SQL. ذخیره کردن SQL را اجرا نمی‌کند و نمای سرور نمی‌سازد. اجرا از بررسی معمول SQL و کنسول مستقل استفاده می‌کند.';

  @override
  String get rebindVirtualView => 'اتصال تعریف محلی به اینجا';

  @override
  String get sourceFolderName => 'نام پوشه';

  @override
  String get sourceFolderPathNotice =>
      'برای ایجاد پوشه‌های تو در تو از / استفاده کنید.';

  @override
  String get topLevel => 'سطح بالا';

  @override
  String get virtualViewName => 'نام نمای مجازی';

  @override
  String get virtualViewSql => 'تعریف SQL نمای مجازی';

  @override
  String get virtualViews => 'نماهای مجازی';

  @override
  String get revealInExplorer => 'نمایش در کاوشگر پایگاه داده';

  @override
  String get objectNotFound =>
      'شیء در این فضای نام یافت نشد. فراداده را تازه کنید یا مجوزها را بررسی کنید.';

  @override
  String get objectHiddenByFilter => 'شیء با فیلتر نمای فعلی پنهان است.';

  @override
  String get revealFilterNotice =>
      'جست‌وجوی شیء این صفحه را محدود کرده است؛ تعداد کل گروه نمایش داده نمی‌شود.';

  @override
  String get clearObjectFilter => 'پاک کردن جست‌وجوی شیء';

  @override
  String get compareStructure => 'مقایسهٔ ساختار';

  @override
  String get selectTwoCompatibleObjects =>
      'با Ctrl و کلیک دو جدول سازگار را انتخاب کنید.';

  @override
  String get scopedComparisonRestriction =>
      'مقایسه به جدول‌های عادی با نام بومی، شِما و موتور یکسان نیاز دارد. انواع دیگر و تطبیق تغییر نام موجود نیست.';

  @override
  String get groupNamespaces => 'گروه‌بندی پایگاه‌های داده و شِماها';

  @override
  String get groupSchemaObjects => 'گروه‌بندی اشیای شِما';

  @override
  String get groupTableElements => 'گروه‌بندی عناصر جدول';

  @override
  String get sortAlphabetically => 'مرتب‌سازی الفبایی';

  @override
  String get showVirtualObjects => 'نمایش اشیای مجازی';

  @override
  String get showObjectComments => 'نمایش توضیحات اشیا';

  @override
  String get objectTypeFilter => 'فیلتر نوع شیء';

  @override
  String get partitionedTable => 'جدول پارتیشن‌بندی‌شده';

  @override
  String get foreignTable => 'جدول خارجی';

  @override
  String get materializedView => 'نمای مادی‌شده';

  @override
  String get functionObject => 'تابع';

  @override
  String get procedureObject => 'رویه';

  @override
  String get sqlSymbolUnavailable =>
      'شیء ماندگار در مکان‌نما با اطمینان مشخص نشد. این کنسول را متصل کنید و ارجاع جدول یا نما را بیرون از رشته‌ها و توضیحات به کار ببرید.';

  @override
  String get sqlSymbolAmbiguous =>
      'ارجاع شیء SQL مبهم است. فضای نام را مشخص کنید یا شیء دقیق پایگاه داده را انتخاب کنید.';

  @override
  String get deactivateSource => 'غیرفعال کردن منبع';

  @override
  String get functions => 'تابع‌ها';

  @override
  String get procedures => 'رویه‌ها';

  @override
  String get separateProceduresFunctions => 'جدا کردن رویه‌ها و تابع‌ها';

  @override
  String get renameVirtualView => 'تغییر نام نمای مجازی';

  @override
  String get metadataPersistentScope =>
      'فقط اشیای پایدار؛ اشیای موقت یا محلی نشست در پیمایش کنسول باقی می‌مانند.';

  @override
  String get metadataSessionScope =>
      'فقط اشیای پایدار؛ اشیای محلی کنسول را پس از اجرا تازه‌سازی کنید.';

  @override
  String get metadataLimitScope =>
      'به حد فراداده رسیدید. دامنهٔ اشیا را محدود کنید.';

  @override
  String get completeColumnMetadataRequired =>
      'پیش از واردکردن داده یا آماده‌سازی تغییرات، فرادادهٔ کامل ستون‌ها لازم است.';

  @override
  String resizeColumn(String name) {
    return 'تغییر عرض ستون $name';
  }

  @override
  String get keyboardShortcutsHeading => 'میان‌برهای صفحه‌کلید';

  @override
  String sqlEditorLabel(String title) {
    return 'ویرایشگر SQL ‏$title';
  }

  @override
  String get editorResultsDivider => 'جداکنندهٔ ویرایشگر و نتایج';

  @override
  String editorExtent(String percent) {
    return '$percent درصد برای ویرایشگر';
  }

  @override
  String get largerEditor => 'بزرگ‌تر کردن ویرایشگر';

  @override
  String get smallerEditor => 'کوچک‌تر کردن ویرایشگر';

  @override
  String get explorerWidthDivider => 'جداکنندهٔ عرض کاوشگر';

  @override
  String get widerExplorer => 'عریض‌تر کردن کاوشگر';

  @override
  String get narrowerExplorer => 'باریک‌تر کردن کاوشگر';

  @override
  String explorerExtent(String width) {
    return 'عرض $width پیکسل';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '$start–$end از $total واحد UTF-16';
  }

  @override
  String get dropDesignedColumn => 'حذف ستون';

  @override
  String get liveCatalogLabel => 'کاتالوگ جاری';

  @override
  String get liveSchemaLabel => 'طرحوارهٔ جاری';

  @override
  String get searchPathLabel => 'مسیر جست‌وجو';

  @override
  String get physicalSessionLabel => 'نشست فیزیکی';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return 'مهلت: $seconds ثانیه · سقف ردیف‌ها: $rows';
  }

  @override
  String get saveFailedCloseTitle => 'ذخیرهٔ SQL ناموفق بود · بستن BusyData';

  @override
  String get createSection => 'ایجاد';

  @override
  String get newConnectionDescription => 'پیکربندی اتصال پایگاه داده';

  @override
  String get newQueryDescription => 'نوشتن SQL در پرس‌وجوی جدید';

  @override
  String get openSqlDescription => 'باز کردن سند SQL موجود';

  @override
  String get searchNoResults => 'کنش منطبقی یافت نشد';

  @override
  String get actionsCategory => 'کنش‌ها';

  @override
  String get privateRecoveryCategory => 'بازیابی خصوصی';

  @override
  String get shortcutRecordHelp =>
      'میان‌بر را فشار دهید. Escape لغو می‌کند. F6 وShift+F6 برای پیمایش پنل‌ها رزرو شده‌اند.';

  @override
  String get rowLimitInvalid => 'محدودیت ردیف را از ۱ تا ۱٬۰۰۰٬۰۰۰ وارد کنید.';

  @override
  String get errorPolicy => 'هنگام خطای اجرا';

  @override
  String get tlsEncrypted => 'رمزشده';

  @override
  String get tlsUnencrypted => 'رمزنشده';

  @override
  String get tlsUnobserved => 'مشاهده‌نشده';

  @override
  String get encryptionVerificationNote =>
      'رمزنگاری، تأیید گواهی یا نام میزبان را اثبات نمی‌کند.';

  @override
  String get uniqueDesignedColumnName =>
      'نام ستون یکتا باشد؛ جدول‌های جدید تا ۱۲۸ ستون را پشتیبانی می‌کنند';

  @override
  String activityBlockerUnavailable(String id) {
    return 'مسدودکنندهٔ $id دیگر دیده نمی‌شود؛ تازه‌سازی کرده و مجوزهای پایگاه داده را بررسی کنید';
  }

  @override
  String get sshChangedKeyReview =>
      'پیش از جایگزینی پیوند این نمایه، کلید تغییرکرده را مستقل بررسی کنید.';

  @override
  String get sshProfileTrustBinding =>
      'اعتماد فقط برای همین نمایه و مقصد دقیق اعمال می‌شود.';

  @override
  String get databaseTlsEvidence => 'TLS · سامانهٔ پایگاه داده';

  @override
  String get sshAlgorithmLabel => 'SSH · نوع';

  @override
  String get sshFingerprintLabel => 'SHA-256';

  @override
  String get sshPreviousFingerprintLabel => 'قبلی · SHA-256';

  @override
  String get sshReviewedLabel => 'بررسی کلید میزبان SSH';

  @override
  String get shortcutRecordAction => 'ضبط میان‌بر';

  @override
  String get fileFormatLabel => 'قالب پرونده';

  @override
  String get encodingLabel => 'رمزگذاری';

  @override
  String get importPolicyLabel => 'سیاست ورود';

  @override
  String get mainMenu => 'منوی اصلی';

  @override
  String get activityReplyTooLarge => 'پاسخ فعالیت از محدودیت بازرس فراتر است.';

  @override
  String get activityListLimited =>
      'فهرست محدود است؛ هدف محدودتری را با SQL صریح بررسی کنید.';

  @override
  String get activitySelectionChanged =>
      'فعالیت انتخاب‌شده پایان یافته یا تغییر کرده است. پیش از بازبینی اقدام، هویت فعلی آن را انتخاب کنید.';

  @override
  String connectionSavedDraftChanged(String name) {
    return 'فیلدهای اتصال هنگام ذخیره‌سازی تغییر کردند؛ پیکربندی ذخیره شد: $name. پیش از اتصال، مقادیر کنونی را بررسی کنید.';
  }

  @override
  String get sshReviewTargetChanged =>
      'مقصد بررسی SSH تغییر کرد؛ دوباره بررسی کنید';

  @override
  String get appearance => 'ظاهر';

  @override
  String get theme => 'پوسته';

  @override
  String get systemTheme => 'سیستم';

  @override
  String get lightTheme => 'روشن';

  @override
  String get darkTheme => 'تیره';

  @override
  String get appLanguage => 'زبان';

  @override
  String get systemLanguage => 'سیستم';

  @override
  String get cut => 'برش';

  @override
  String get paste => 'جای‌گذاری';

  @override
  String get selectAll => 'انتخاب همه';

  @override
  String get noSelection => 'متنی موجود نیست';

  @override
  String get clipboardEmpty => 'کلیپ‌بورد متنی ندارد';

  @override
  String get settingsDraftNotice =>
      'تغییرات اجرا و بازیابی خصوصی ذخیره نشده‌اند.';

  @override
  String get documentsMenu => 'سندها';

  @override
  String get currentSql => 'SQL کنونی';

  @override
  String get searchActionsHint => 'جستجوی کنش‌ها…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => 'ویژگی‌ها';

  @override
  String get metadataSelectionUnavailable =>
      'برای بررسی ویژگی‌های ثبت‌شده، یک مورد را انتخاب کنید. انتخاب قبلی در دسترس نیست.';

  @override
  String get secureStorage => 'فضای ذخیره‌سازی امن سیستم‌عامل';

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
      'حافظهٔ نهان ذخیره نشد. فرادادهٔ فعلی همچنان در دسترس است.';

  @override
  String get metadataCacheRebuiltVersion => 'برای نسخهٔ فعلی بازسازی شد';

  @override
  String get metadataCacheRebuiltCorrupt => 'پس از خطای حافظهٔ نهان بازسازی شد';

  @override
  String get editSessionBusy =>
      'این نشست مشغول است. منتظر بمانید تا کار جاری آن تمام شود، سپس ارزیابی تازه‌ای برای امکان ویرایش درخواست کنید.';

  @override
  String get editIdentityRequired =>
      'پیش از ویرایش، یک کلید اصلی کامل یا شناسهٔ یکتایی که NULL را نمی‌پذیرد انتخاب کنید.';

  @override
  String get editColumnsReadOnly =>
      'همهٔ ستون‌های انتخاب‌شده تولیدشده یا فقط‌خواندنی هستند.';

  @override
  String get editResultNotReady =>
      'پیش از درخواست ارزیابی تازه برای امکان ویرایش، منتظر تکمیل این نتیجهٔ نگهداری‌شده بمانید.';

  @override
  String get editProjectionUnsupported =>
      'ویرایش به یک SELECT مستقیم از یک جدول پایه نیاز دارد که هر ستون پایه را فقط یک بار انتخاب کند.';

  @override
  String get sqlInspectionDuplicateUsingColumn => 'ستون تکراری در JOIN USING';

  @override
  String get sqlInspectionUnresolvedUsingColumn =>
      'ستون JOIN USING در یکی از عملوندها وجود ندارد';

  @override
  String get sqlInspectionAmbiguousUsingColumn => 'ستون مشترک مبهم در JOIN';

  @override
  String get sqlInspectionOutputColumnCount =>
      'تعداد ستون‌های خروجی اعلام‌شده مطابقت ندارد';

  @override
  String get sqlInspectionAmbiguousOverload => 'سربارگذاری مبهم روال';

  @override
  String get sqlInspectionBooleanType => 'نوع نامعتبر عبارت منطقی';

  @override
  String get sqlInspectionOperatorTypes => 'نوع‌های ناسازگار عملوندهای عملگر';

  @override
  String get sqlInspectionArrayTypes => 'نوع‌های ناسازگار عناصر آرایه';

  @override
  String get sqlInspectionCaseConditionType => 'نوع ناسازگار شرط CASE';

  @override
  String get sqlInspectionCaseResultTypes => 'نوع‌های ناسازگار نتیجه CASE';

  @override
  String get sqlInspectionCoalesceTypes =>
      'نوع‌های ناسازگار آرگومان‌های COALESCE';

  @override
  String get sqlInspectionSetColumnCount =>
      'تعداد ستون‌های عملیات مجموعه مطابقت ندارد';

  @override
  String get sqlInspectionSetTypes => 'نوع‌های ناسازگار نتیجه عملیات مجموعه';

  @override
  String get sqlInspectionRecursiveCteType => 'نوع CTE بازگشتی مطابقت ندارد';
}
